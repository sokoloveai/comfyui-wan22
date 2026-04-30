"""
Live LoRA refresh для ComfyUI.

Эндпоинт POST /api/loras/refresh:
  1. Сканирует исходные папки LoRA на Network Volume и создаёт недостающие
     симлинки в /comfyui/models/loras/ (та же логика, что в download_models.sh,
     но без рестарта pod-а).
  2. Инвалидирует кэш folder_paths по ключу "loras", чтобы ComfyUI
     перечитал содержимое папки при следующем запросе.

Используется внешним lora_sync сервисом, который льёт LoRA из HuggingFace
в Network Volume — после успешной заливки он дёргает этот эндпоинт.
"""

from __future__ import annotations

import logging
import os
from typing import List

from aiohttp import web
import folder_paths
import server


log = logging.getLogger("loras_refresh")

VOLUME_LORA_SOURCES: List[str] = [
    "/workspace/loras",
    "/workspace/ComfyUI/models/loras",
]
COMFYUI_LORAS_DIR = "/comfyui/models/loras"


def _relink_loras() -> List[str]:
    os.makedirs(COMFYUI_LORAS_DIR, exist_ok=True)
    new_links: List[str] = []
    for src_dir in VOLUME_LORA_SOURCES:
        if not os.path.isdir(src_dir):
            continue
        try:
            entries = os.listdir(src_dir)
        except OSError as exc:
            log.warning("listdir %s failed: %s", src_dir, exc)
            continue
        for fname in entries:
            if not fname.endswith(".safetensors"):
                continue
            src = os.path.join(src_dir, fname)
            dst = os.path.join(COMFYUI_LORAS_DIR, fname)
            if os.path.lexists(dst):
                continue
            try:
                os.symlink(src, dst)
                new_links.append(fname)
            except OSError as exc:
                log.warning("symlink %s -> %s failed: %s", src, dst, exc)
    return new_links


def _invalidate_loras_cache() -> bool:
    cache = getattr(folder_paths, "filename_list_cache", None)
    if isinstance(cache, dict):
        cache.pop("loras", None)
        return True
    return False


@server.PromptServer.instance.routes.post("/api/loras/refresh")
async def loras_refresh(_request):
    new_links = _relink_loras()
    invalidated = _invalidate_loras_cache()
    log.info(
        "loras refresh: linked %d new file(s), cache invalidated=%s",
        len(new_links), invalidated,
    )
    return web.json_response({
        "status": "ok",
        "new_links": new_links,
        "linked": len(new_links),
        "cache_invalidated": invalidated,
    })


NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}
