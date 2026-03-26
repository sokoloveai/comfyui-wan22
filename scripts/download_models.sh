#!/bin/bash
# =============================================================================
# Link models from Network Volume into ComfyUI
# Volume: /workspace/ComfyUI/models/ + /workspace/loras/
# ComfyUI: /comfyui/models/
# Only downloads missing models TO the volume (never to container disk)
# =============================================================================

VOLUME_MODELS="/workspace/ComfyUI/models"
VOLUME_LORAS="/workspace/loras"
COMFYUI_MODELS="/comfyui/models"

# ── Helper: symlink all files from a volume dir into comfyui dir ─────────────
link_dir() {
    local src="$1"
    local dst="$2"

    if [ ! -d "$src" ]; then
        echo "  [SKIP] $src not found on volume"
        return
    fi

    mkdir -p "$dst"

    # Link all files (not dirs) in the source
    for f in "$src"/*; do
        [ -f "$f" ] || continue
        local fname=$(basename "$f")
        if [ ! -e "$dst/$fname" ]; then
            ln -sf "$f" "$dst/$fname"
            echo "  [LN] $fname"
        else
            echo "  [OK] $fname"
        fi
    done

    # Also link files in subdirectories (e.g. diffusion_models/Wan2.2/)
    for d in "$src"/*/; do
        [ -d "$d" ] || continue
        local dname=$(basename "$d")
        [[ "$dname" == .* ]] && continue
        mkdir -p "$dst/$dname"
        for f in "$d"*; do
            [ -f "$f" ] || continue
            local fname=$(basename "$f")
            if [ ! -e "$dst/$dname/$fname" ]; then
                ln -sf "$f" "$dst/$dname/$fname"
                echo "  [LN] $dname/$fname"
            else
                echo "  [OK] $dname/$fname"
            fi
        done
    done
}

# ── Helper: download to volume if missing ────────────────────────────────────
download_to_volume() {
    local url="$1"
    local dest="$2"
    local link="$3"

    if [ -f "$dest" ]; then
        local size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
        if [ "$size" -gt 1000 ]; then
            echo "  [OK] $(basename $dest) ($(numfmt --to=iec $size))"
            [ -n "$link" ] && mkdir -p "$(dirname $link)" && ln -sf "$dest" "$link"
            return 0
        fi
        rm -f "$dest"
    fi

    echo "  [DL] Downloading $(basename $dest) to volume..."
    mkdir -p "$(dirname $dest)"
    aria2c -x 16 -s 16 -k 1M --console-log-level=error -o "$dest" "$url" 2>/dev/null || \
    wget -q --show-progress -O "$dest" "$url" 2>/dev/null

    if [ ! -f "$dest" ] || [ $(stat -c%s "$dest" 2>/dev/null || echo 0) -lt 1000 ]; then
        echo "  [WARN] Failed to download $(basename $dest) — network/DNS issue, skipping"
        rm -f "$dest"
        return 1
    fi

    [ -n "$link" ] && mkdir -p "$(dirname $link)" && ln -sf "$dest" "$link"
}

echo "============================================="
echo "  Setting up models from Network Volume"
echo "============================================="

if [ ! -d "/workspace" ]; then
    echo "[ERR] /workspace not mounted! Attach a Network Volume."
    exit 1
fi

if [ ! -d "$VOLUME_MODELS" ]; then
    echo "[WARN] $VOLUME_MODELS not found — creating structure..."
    mkdir -p "$VOLUME_MODELS"/{vae,diffusion_models,text_encoders,clip_vision,clip,loras,detection}
fi

echo ""
echo "── VAE ──"
link_dir "$VOLUME_MODELS/vae" "$COMFYUI_MODELS/vae"

echo ""
echo "── Diffusion Models (UNET) ──"
link_dir "$VOLUME_MODELS/diffusion_models" "$COMFYUI_MODELS/diffusion_models"

echo ""
echo "── Text Encoders ──"
link_dir "$VOLUME_MODELS/text_encoders" "$COMFYUI_MODELS/text_encoders"

echo ""
echo "── CLIP Vision ──"
link_dir "$VOLUME_MODELS/clip_vision" "$COMFYUI_MODELS/clip_vision"

echo ""
echo "── CLIP ──"
link_dir "$VOLUME_MODELS/clip" "$COMFYUI_MODELS/clip"

echo ""
echo "── Detection models ──"
link_dir "$VOLUME_MODELS/detection" "$COMFYUI_MODELS/detection"

echo ""
echo "── LoRAs (from volume models) ──"
link_dir "$VOLUME_MODELS/loras" "$COMFYUI_MODELS/loras"

echo ""
echo "── LoRAs (from /workspace/loras/) ──"
if [ -d "$VOLUME_LORAS" ]; then
    mkdir -p "$COMFYUI_MODELS/loras"
    for f in "$VOLUME_LORAS"/*.safetensors; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        if [ ! -e "$COMFYUI_MODELS/loras/$fname" ]; then
            ln -sf "$f" "$COMFYUI_MODELS/loras/$fname"
            echo "  [LN] $fname"
        else
            echo "  [OK] $fname"
        fi
    done
else
    echo "  [SKIP] /workspace/loras/ not found"
fi

echo ""
echo "── NudeNet (NSFW filter) ──"
download_to_volume \
    "https://huggingface.co/notAI-tech/NudeNet/resolve/main/640m.onnx" \
    "$VOLUME_MODELS/nsfw/640m.onnx" \
    "$COMFYUI_MODELS/nsfw/640m.onnx"

echo ""
echo "── Output directory ──"
if [ -d "/workspace" ]; then
    mkdir -p /workspace/output
    if [ ! -L /comfyui/output ]; then
        rm -rf /comfyui/output
        ln -sf /workspace/output /comfyui/output
        echo "  [LN] output → /workspace/output"
    else
        echo "  [OK] output → /workspace/output"
    fi
fi

echo ""
echo "[✓] Model setup complete!"
echo ""
echo "── Summary ──"
echo "  VAE files:        $(ls -1 $COMFYUI_MODELS/vae/*.safetensors 2>/dev/null | wc -l)"
echo "  Diffusion models: $(find $COMFYUI_MODELS/diffusion_models -name '*.safetensors' 2>/dev/null | wc -l)"
echo "  Text encoders:    $(ls -1 $COMFYUI_MODELS/text_encoders/*.safetensors 2>/dev/null | wc -l)"
echo "  LoRAs:            $(ls -1 $COMFYUI_MODELS/loras/*.safetensors 2>/dev/null | wc -l)"
echo ""
