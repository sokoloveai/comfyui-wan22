#!/bin/bash
set -e

echo "============================================="
echo "  SokoloveAI ComfyUI WAN 2.2 Template"
echo "============================================="

# ── Ensure model directories exist ───────────────────────────────────────────
mkdir -p /comfyui/models/{diffusion_models,text_encoders,clip,clip_vision,vae,loras,nsfw,detection}

# ── Link models from Network Volume ─────────────────────────────────────────
echo "[*] Setting up models from Network Volume..."
/download_models.sh

# ── Start JupyterLab in background ──────────────────────────────────────────
echo "[*] Starting JupyterLab on port 8888..."
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.disable_check_xsrf=True \
    --notebook-dir=/comfyui \
    &

# ── Start ComfyUI ───────────────────────────────────────────────────────────
echo "[*] Starting ComfyUI on port 8188..."
cd /comfyui

EXTRA_ARGS=""
if [ -f "/comfyui/comfyui_args.txt" ]; then
    EXTRA_ARGS=$(cat /comfyui/comfyui_args.txt)
fi

python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --disable-auto-launch \
    $EXTRA_ARGS
