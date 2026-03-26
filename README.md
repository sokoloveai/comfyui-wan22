# SokoloveAI ComfyUI WAN 2.2 Template

Docker image for RunPod with ComfyUI, WAN 2.2, and all custom nodes pre-installed.

**Lightweight**: nodes baked in, models downloaded at startup.

## What's Inside

### Custom Nodes (pre-installed)
- ComfyUI-Manager
- RES4LYF (ClownSampler)
- ComfyUI-KJNodes
- WAS Node Suite
- ComfyUI-Easy-Use
- nsfw-shorier_comfyui (FilterNsfw)
- ComfyUI-utils-nodes
- Civicomfy

### Models (downloaded at startup)
- **UNET**: `wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors`
- **CLIP**: `umt5_xxl_fp8_e4m3fn_scaled.safetensors`
- **VAE**: `wan_2.1_vae.safetensors`
- **LoRA**: `LOW_4steps-lora-rank64-Seko-V1l.safetensors`
- **NudeNet**: `640m.onnx` (for NSFW filter)

### Services
- **ComfyUI**: port 8188
- **JupyterLab**: port 8889

## Deploy on RunPod

1. Create template with image: `ghcr.io/sokoloveai/comfyui-wan22:latest`
2. Container disk: **20 GB** (nodes only, no models)
3. Volume disk: **80 GB** (for models + loras + outputs)
4. Expose HTTP ports: `8188,8889`
5. Deploy on A100/H100

## Auto-Build

Every push to `main` triggers GitHub Actions → builds image → pushes to GHCR.

```bash
docker pull ghcr.io/sokoloveai/comfyui-wan22:latest
```

## Custom LoRAs

Place your LoRAs in `/workspace/loras/` — they'll be auto-linked at startup.

## Add Models

Edit `scripts/download_models.sh` to add new model URLs. Push to GitHub — new image builds automatically.

## Add Workflows

Drop `.json` workflow files into `workflows/` folder — they'll appear in ComfyUI.
