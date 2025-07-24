#!/bin/bash
set -e  # Exit immediately on error
set -o pipefail

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
