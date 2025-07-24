# Base image with CUDA 11.6 support (matches PyTorch 1.13.1 + cu116)
FROM nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04

# Prevent interactive prompts during builds
ENV DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    ca-certificates \
    libgl1 \
    python3-pip \
    libglew-dev \
    libassimp-dev \
    libboost-all-dev \
    libgtk-3-dev \
    libopencv-dev \
    libglfw3-dev \
    libavdevice-dev \
    libavcodec-dev \
    libeigen3-dev \
    libxxf86vm-dev \
    libembree-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    bash ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

# Configure conda
RUN conda config --set always_yes yes && \
    conda config --add channels defaults && \
    conda config --add channels https://repo.anaconda.com/pkgs/main && \
    conda config --add channels https://repo.anaconda.com/pkgs/r && \
    conda config --set channel_priority strict && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create conda env with Python 3.7
RUN conda create -n Gaussians4D python=3.7 -y

# Conda shell activation for later layers
SHELL ["conda", "run", "-n", "Gaussians4D", "/bin/bash", "-c"]

ENV TORCH_CUDA_ARCH_LIST="8.6+PTX"

# Clone 4DGaussians repo with submodules
WORKDIR /opt/training
RUN git clone https://github.com/resplatt/dancing-dolphin.git . && \
    git submodule update --init --recursive

COPY sample_data/ sample_data/

# Install project dependencies
RUN cd 4DGaussians && \
    pip install -r requirements.txt && \
    pip install -e submodules/depth-diff-gaussian-rasterization && \
    pip install -e submodules/simple-knn

# Copy training script (replace with your actual entrypoint)
COPY train_gaussian.sh .
RUN chmod +x train_gaussian.sh

# Entrypoint using conda environment
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "Gaussians4D", "./train_gaussian.sh"]



