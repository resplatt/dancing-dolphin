#!/bin/bash
set -e  # Exit immediately on error
set -o pipefail


# generate download url from bucket and key
AWS_S3_DOWNLOAD_URL="s3://$S3_BUCKET/$S3_KEY"
AWS_S3_UPLOAD_BUCKET="resplatt-model-outputs"
# extract user_{user_id}/model_{model_id} from S3_KEY
USER_ID=$(echo "$S3_KEY" | sed -n 's|user_\([^/]*\)/.*|\1|p')
MODEL_ID=$(echo "$S3_KEY" | sed -n 's|.*/model_\([^/]*\)/.*|\1|p')


AWS_S3_UPLOAD_URL="s3://$AWS_S3_UPLOAD_BUCKET/user_$USER_ID/model_$MODEL_ID/"

echo "user_id: $USER_ID"
echo "model_id: $MODEL_ID"
echo "AWS S3 Download URL: $AWS_S3_DOWNLOAD_URL"
echo "AWS S3 Upload URL: $AWS_S3_UPLOAD_URL"

# -----------------------------
# 1. Download video from S3
# -----------------------------
echo "📥 Downloading video from S3..."
if [ -z "$AWS_S3_DOWNLOAD_URL" ]; then
  echo "❌ AWS_S3_DOWNLOAD_URL not set."
  exit 1
fi

aws s3 cp "$AWS_S3_DOWNLOAD_URL" input.mp4 || { echo "❌ Failed to download video."; exit 1; }


# 🔑 Activate Conda env
source /opt/conda/etc/profile.d/conda.sh
conda activate Gaussians4D

# -----------------------------
# 2. Extract frames from video
# -----------------------------
VIDEO_PATH="data/video"
NERF_PATH="data/nerf"

echo "🧼 Creating directories..."
mkdir -p "$VIDEO_PATH"

echo "🎞 Extracting frames with ffmpeg..."
ffmpeg -i input.mp4 -qscale:v 2 -vf "fps=10" "$VIDEO_PATH/%08d.png"

# Check if frames were extracted
if [ -z "$(ls -A $VIDEO_PATH)" ]; then
  echo "❌ No frames extracted. ffmpeg failed."
  exit 1
fi

# -----------------------------
# 3. Process frames with COLMAP
# -----------------------------
echo "🧠 Running ns-process-data..."
ns-process-data images --no-gpu --data "$VIDEO_PATH" --output-dir "$NERF_PATH"

# Ensure colmap path exists before copying
mkdir -p "$NERF_PATH/colmap/"
cp -r "$NERF_PATH/images" "$NERF_PATH/colmap/images"

# -----------------------------
# 4. Train NeRF
# -----------------------------
echo "🚀 Starting training..."
cd 4DGaussians

CONFIG_PATH="arguments/dynerf/default.py"
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config file not found at $CONFIG_PATH"
  echo "🔍 Available configs:"
  find arguments/ -name "*.py"
  exit 1
fi

python train.py -s "../$NERF_PATH/colmap" --port 6017 --expname "custom" --configs "$CONFIG_PATH"

# -----------------------------
# 5. upload results to S3
# -----------------------------
echo "📤 Uploading results to S3..."
cd ..

mkdir upload
find 4DGaussians/output/custom -name point_cloud.ply -exec cp {} ./upload/ \;
find 4DGaussians/output/custom -name deformation.pth -exec cp {} ./upload/ \;
find 4DGaussians/output/custom -name deformation_table.pth -exec cp {} ./upload/ \;
find 4DGaussians/output/custom -name deformation_accum.pth -exec cp {} ./upload/ \;

aws s3 cp ./upload "$AWS_S3_UPLOAD_URL" || { echo "❌ Failed to upload results to S3."; exit 1; }
