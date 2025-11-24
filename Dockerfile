# Optimized Dockerfile for RTX 5090 with CUDA 12.9 and ComfyUI
# Models are expected to be mounted via Runpod volume, no download needed

ARG BASE_IMAGE=nvidia/cuda:12.9.0-cudnn-runtime-ubuntu24.04
FROM ${BASE_IMAGE} AS base

ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY=12.9
ARG ENABLE_PYTORCH_UPGRADE=true
ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu129

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
ENV PATH="/opt/venv/bin:${PATH}"
ENV PIP_NO_INPUT=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.12 python3.12-venv git wget ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv and create isolated virtual environment
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Install comfy-cli and Python essentials
RUN uv pip install comfy-cli pip setuptools wheel

# Install ComfyUI with CUDA 12.9
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version "${CUDA_VERSION_FOR_COMFY}" --nvidia

# Upgrade PyTorch to match CUDA 12.9
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./
WORKDIR /

# Install runtime dependencies for handler
RUN uv pip install runpod requests websocket-client

# Add main scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

# Add scripts for custom nodes and manager mode
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Install custom nodes from snapshot
COPY snapshot-faceswap.json /snapshot-faceswap.json
COPY src/restore_snapshot.sh /restore_snapshot.sh
RUN chmod +x /restore_snapshot.sh && /restore_snapshot.sh || echo "Warning: Snapshot restoration failed, continuing anyway..."

CMD ["/start.sh"]

# Stage 2: Downloader placeholder (no download needed)
FROM base AS downloader
WORKDIR /comfyui

# Stage 3: Final image
FROM base AS final
COPY --from=downloader /comfyui/models /comfyui/models
