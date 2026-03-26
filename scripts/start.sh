#!/bin/bash
set -e

echo "============================================="
echo "  SokoloveAI ComfyUI WAN 2.2 Template"
echo "============================================="

# ── Download models if not present ───────────────────────────────────────────
echo "[*] Checking and downloading models..."
/download_models.sh

# ── Symlink workspace loras if available ─────────────────────────────────────
if [ -d "/workspace/loras" ]; then
    echo "[*] Linking loras from /workspace/loras..."
    ln -sf /workspace/loras/* /comfyui/models/loras/ 2>/dev/null || true
fi

# ── Symlink network volume models if available ───────────────────────────────
if [ -d "/runpod-volume/models" ]; then
    echo "[*] Found network volume models, linking..."
    for dir in /runpod-volume/models/*/; do
        dirname=$(basename "$dir")
        if [ -d "/comfyui/models/$dirname" ]; then
            ln -sf "$dir"* "/comfyui/models/$dirname/" 2>/dev/null || true
        fi
    done
fi

# ── Start JupyterLab in background ──────────────────────────────────────────
echo "[*] Starting JupyterLab on port 8889..."
jupyter lab \
    --ip=0.0.0.0 \
    --port=8889 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --notebook-dir=/comfyui \
    &

# ── Start ComfyUI ───────────────────────────────────────────────────────────
echo "[*] Starting ComfyUI on port 8188..."
cd /comfyui

# Read extra args if file exists
EXTRA_ARGS=""
if [ -f "/comfyui/comfyui_args.txt" ]; then
    EXTRA_ARGS=$(cat /comfyui/comfyui_args.txt)
fi

python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --disable-auto-launch \
    $EXTRA_ARGS
