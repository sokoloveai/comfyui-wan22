#!/bin/bash
# =============================================================================
# Download WAN 2.2 models if not already present
# Models are downloaded to /comfyui/models/ directories
# =============================================================================

MODELS_DIR="/comfyui/models"

download_if_missing() {
    local url="$1"
    local dest="$2"
    
    if [ -f "$dest" ]; then
        echo "  [OK] $(basename $dest) already exists"
        return 0
    fi
    
    echo "  [DL] Downloading $(basename $dest)..."
    mkdir -p "$(dirname $dest)"
    aria2c -x 16 -s 16 -k 1M --console-log-level=error -o "$dest" "$url" || \
    wget -q --show-progress -O "$dest" "$url"
}

echo "── Diffusion Models (UNET) ──"
mkdir -p "$MODELS_DIR/diffusion_models/Wan2.2"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
    "$MODELS_DIR/diffusion_models/Wan2.2/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

echo "── CLIP / Text Encoder ──"
mkdir -p "$MODELS_DIR/clip"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$MODELS_DIR/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

echo "── VAE ──"
mkdir -p "$MODELS_DIR/vae"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "$MODELS_DIR/vae/wan_2.1_vae.safetensors"

echo "── LoRA (base/public) ──"
mkdir -p "$MODELS_DIR/loras"

download_if_missing \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LOW_4steps-lora-rank64-Seko-V1l.safetensors" \
    "$MODELS_DIR/loras/LOW_4steps-lora-rank64-Seko-V1l.safetensors"

# InstagirlMix LoRA — add URL when available on HuggingFace
# download_if_missing \
#     "URL_HERE" \
#     "$MODELS_DIR/loras/WAN2.2_LowNoise_InstagirlMix_V1.safetensors"

echo "── NudeNet model for NSFW filter ──"
mkdir -p "$MODELS_DIR/nsfw"

download_if_missing \
    "https://huggingface.co/notAI-tech/NudeNet/resolve/main/640m.onnx" \
    "$MODELS_DIR/nsfw/640m.onnx"

echo ""
echo "[✓] Model check complete!"
