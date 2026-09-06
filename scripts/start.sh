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

# ── JupyterLab (FREELAPP-111) ───────────────────────────────────────────────
# Раньше здесь стояли --NotebookApp.token='' --NotebookApp.password='' плюс
# allow_origin='*' и disable_check_xsrf — то есть порт 8888, проброшенный
# наружу через *.proxy.runpod.net, пускал кого угодно без пароля. Прокси
# RunPod своей авторизации не имеет, так что это было анонимное выполнение
# кода на машине с ключами. Теперь без токена Jupyter не поднимается вообще.
JUPYTER_ACCESS_TOKEN="${JUPYTER_TOKEN:-${JUPYTER_PASSWORD:-}}"

if [ -n "$JUPYTER_ACCESS_TOKEN" ]; then
    echo "[*] Starting JupyterLab on port 8888 (token auth)..."
    jupyter lab \
        --ip=0.0.0.0 \
        --port=8888 \
        --no-browser \
        --allow-root \
        --ServerApp.token="$JUPYTER_ACCESS_TOKEN" \
        --notebook-dir=/comfyui \
        &
else
    echo "[!] JupyterLab НЕ запущен: не задан JUPYTER_TOKEN (или JUPYTER_PASSWORD)."
    echo "[!] Это осознанно: порт 8888 публичен, а без токена доступ анонимный."
fi

# ── ComfyUI + шлюз авторизации (FREELAPP-111) ───────────────────────────────
# COMFY_AUTH_TOKEN задан  → ComfyUI слушает только localhost, наружу смотрит
#                           Caddy на 8188 и требует Authorization: Bearer.
# COMFY_AUTH_TOKEN пуст   → прежнее поведение (ComfyUI сам на 0.0.0.0:8188).
# Пустое значение оставлено намеренно: образ можно обновить, ничего не меняя в
# поведении, и включить проверку отдельным шагом — уже после того, как
# вызывающий сервис начал слать заголовок.
COMFY_INTERNAL_PORT=8189

if [ -n "$COMFY_AUTH_TOKEN" ]; then
    echo "[*] Auth gateway enabled: Caddy :8188 → 127.0.0.1:$COMFY_INTERNAL_PORT"

    # Опциональный basic auth — для людей: браузер не умеет сам слать Bearer,
    # поэтому веб-интерфейс ComfyUI доступен только так. Хеш генерируется
    # командой `caddy hash-password` и передаётся в COMFY_BASIC_HASH.
    if [ -n "$COMFY_BASIC_HASH" ]; then
        FALLBACK_HANDLER=$(cat <<BASIC
	handle {
		basic_auth {
			${COMFY_BASIC_USER:-comfy} ${COMFY_BASIC_HASH}
		}
		reverse_proxy 127.0.0.1:${COMFY_INTERNAL_PORT}
	}
BASIC
)
    else
        FALLBACK_HANDLER=$(cat <<DENY
	handle {
		respond "Unauthorized" 401
	}
DENY
)
    fi

    mkdir -p /etc/caddy
    cat > /etc/caddy/Caddyfile <<EOF
{
	admin off
	auto_https off
}

:8188 {
	@authorized header Authorization "Bearer ${COMFY_AUTH_TOKEN}"
	handle @authorized {
		reverse_proxy 127.0.0.1:${COMFY_INTERNAL_PORT}
	}
${FALLBACK_HANDLER}

	log {
		output stdout
		format console
	}
}
EOF

    # Валидируем до запуска ComfyUI: если конфиг битый, лучше упасть сразу и
    # заметно, чем поднять ComfyUI открытым наружу.
    caddy validate --config /etc/caddy/Caddyfile
    caddy start --config /etc/caddy/Caddyfile

    COMFY_LISTEN=127.0.0.1
    COMFY_PORT=$COMFY_INTERNAL_PORT
else
    echo "[!] COMFY_AUTH_TOKEN не задан — ComfyUI слушает 0.0.0.0:8188 без авторизации."
    COMFY_LISTEN=0.0.0.0
    COMFY_PORT=8188
fi

# ── Start ComfyUI ───────────────────────────────────────────────────────────
echo "[*] Starting ComfyUI on ${COMFY_LISTEN}:${COMFY_PORT}..."
cd /comfyui

EXTRA_ARGS=""
if [ -f "/comfyui/comfyui_args.txt" ]; then
    EXTRA_ARGS=$(cat /comfyui/comfyui_args.txt)
fi

python main.py \
    --listen "$COMFY_LISTEN" \
    --port "$COMFY_PORT" \
    --disable-auto-launch \
    $EXTRA_ARGS
