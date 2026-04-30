# =============================================================================
# SokoloveAI ComfyUI WAN 2.2 Template for RunPod
# Lightweight image: nodes pre-installed, models linked from Network Volume
# =============================================================================
FROM nvidia/cuda:13.0.2-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    git git-lfs wget curl aria2 \
    build-essential cmake \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
    ffmpeg \
    openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

# ── PyTorch + CUDA ───────────────────────────────────────────────────────────
RUN pip install --break-system-packages \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu130

# ── JupyterLab (with terminado for web terminal) ────────────────────────────
RUN pip install --break-system-packages jupyterlab terminado

# ── ComfyUI ──────────────────────────────────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui \
    && cd /comfyui \
    && pip install --break-system-packages -r requirements.txt

WORKDIR /comfyui

# ── Custom Nodes ─────────────────────────────────────────────────────────────
RUN cd /comfyui/custom_nodes && \
    # ComfyUI Manager
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    # ClownSampler (RES4LYF)
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git && \
    # KJNodes
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    # WAS Node Suite
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git was-ns && \
    # Easy Use
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git comfyui-easy-use && \
    # NSFW Filter (nsfw-shorier)
    git clone https://github.com/phyblas/nsfw-shorier_comfyui.git && \
    # Utils Nodes (FilterNsfw backup)
    git clone https://github.com/zhangp365/ComfyUI-utils-nodes.git && \
    # Civicomfy
    git clone https://github.com/civitai/comfy-nodes.git Civicomfy && \
    true

# ── Install all node dependencies ───────────────────────────────────────────
RUN cd /comfyui/custom_nodes && \
    for d in */; do \
        if [ -f "$d/requirements.txt" ]; then \
            echo "Installing requirements for $d" && \
            pip install --break-system-packages -r "$d/requirements.txt" || true; \
        fi; \
    done

# ── SageAttention ────────────────────────────────────────────────────────────
RUN pip install --break-system-packages sageattention

# ── Copy scripts, workflows, and custom nodes ───────────────────────────────
COPY scripts/start.sh /start.sh
COPY scripts/download_models.sh /download_models.sh
COPY workflows/ /comfyui/user/default/workflows/
COPY custom_nodes/loras_refresh /comfyui/custom_nodes/loras_refresh

RUN chmod +x /start.sh /download_models.sh

# ── Expose ports ─────────────────────────────────────────────────────────────
# ComfyUI: 8188, JupyterLab: 8888
EXPOSE 8188 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -sf http://localhost:8188/system_stats || exit 1

CMD ["/start.sh"]
