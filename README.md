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
- **ComfyUI**: port 8188 (за шлюзом авторизации, если задан `COMFY_AUTH_TOKEN`)
- **JupyterLab**: port 8888 (не запускается без `JUPYTER_TOKEN`)

## Авторизация (обязательно к прочтению)

RunPod-прокси (`https://<pod-id>-<port>.proxy.runpod.net`) **публичен и своей
авторизации не имеет** — pod ID это единственное, что отделяет порт от
интернета. Поэтому проверка делается внутри пода.

| Переменная | Назначение |
|---|---|
| `COMFY_AUTH_TOKEN` | Задан → ComfyUI слушает только `127.0.0.1:8189`, а на 8188 стоит Caddy и требует `Authorization: Bearer <токен>`. Пусто → прежнее поведение, ComfyUI открыт на `0.0.0.0:8188` |
| `JUPYTER_TOKEN` (или `JUPYTER_PASSWORD`) | Задан → JupyterLab поднимается с токеном. Пусто → **не поднимается вообще** |
| `COMFY_BASIC_HASH` | Необязательно. Хеш от `caddy hash-password` — включает basic auth как второй способ входа (нужен для браузера: он не умеет сам отправлять Bearer, поэтому веб-интерфейс ComfyUI иначе будет отвечать 401) |
| `COMFY_BASIC_USER` | Логин для basic auth, по умолчанию `comfy` |

Пустые значения оставлены намеренно: образ можно обновить, ничего не меняя в
поведении пода, и включить проверку отдельным шагом — уже после того, как
вызывающий сервис научился слать заголовок. Откат — снять переменную и
перезапустить под.

```bash
# без токена
curl -o /dev/null -w "%{http_code}\n" https://<pod-id>-8188.proxy.runpod.net/system_stats   # 401
# с токеном
curl -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $COMFY_AUTH_TOKEN" \
  https://<pod-id>-8188.proxy.runpod.net/system_stats                                        # 200
```

История: до FREELAPP-111 (август 2026) Jupyter стартовал с
`--NotebookApp.token='' --NotebookApp.password=''` плюс `allow_origin='*'` и
`disable_check_xsrf=True` — любой, кто знал pod ID, получал выполнение кода на
машине с `HUGGINGFACE_TOKEN` и доступом к network volume. ComfyUI при этом
отдавал `/queue` и `/history` со всей историей генераций.

## Deploy on RunPod

1. Create template:
   - **Container Image**: `sokoloveai/comfyui-wan22:latest`
   - **Container Disk**: 20 GB
   - **Volume Disk**: 80 GB (attach network volume with models)
   - **Volume Mount Path**: `/workspace`
   - **Exposed HTTP Ports**: `8188` (8888 добавлять только если реально нужен Jupyter)
   - **Environment**: `COMFY_AUTH_TOKEN`, при необходимости `JUPYTER_TOKEN`
   - **Docker Command**: leave empty (uses default CMD)
2. Deploy on A100/H100
3. Access ComfyUI at port **8188** с заголовком `Authorization: Bearer $COMFY_AUTH_TOKEN`

## Auto-Build

Every push to `main` triggers GitHub Actions → builds image → pushes to GHCR with `latest` + SHA tags.

```bash
docker pull sokoloveai/comfyui-wan22:latest
```

## Custom LoRAs

Place your LoRAs in `/workspace/loras/` — they'll be auto-linked at startup.

## Add Models

Edit `scripts/download_models.sh` to add new model URLs. Push to GitHub — new image builds automatically.

## Add Workflows

Drop `.json` workflow files into `workflows/` folder — they'll appear in ComfyUI.
