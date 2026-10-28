#!/usr/bin/env bash
set -Eeuo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ ! -x .venv/bin/python ]]; then
    echo "Python environment missing. Run ./install.sh first."
    exit 1
fi

if ! .venv/bin/python -c "import uvicorn" >/dev/null 2>&1; then
    echo "Uvicorn is missing. Run ./install.sh again."
    exit 1
fi

echo "=================================="
echo "          PyStudio"
echo "=================================="
echo

read -r -p "Enter Port [8000]: " PORT
PORT="${PORT:-8000}"

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    echo "Invalid port. Choose a number from 1 to 65535."
    exit 1
fi

read -r -p "Have Domain (Y/n): " HAS_DOMAIN
HAS_DOMAIN="${HAS_DOMAIN:-n}"

if [[ "$HAS_DOMAIN" =~ ^[Yy]$ ]]; then
    read -r -p "Enter Domain: " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo "Domain cannot be empty."
        exit 1
    fi
    DISPLAY_HOST="$DOMAIN"
else
    DISPLAY_HOST="localhost"

    if command -v ip >/dev/null 2>&1; then
        LAN_IP="$(ip route get 1.1.1.1 2>/dev/null |
            awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true)"
        if [[ -n "${LAN_IP:-}" ]]; then
            DISPLAY_HOST="$LAN_IP"
        fi
    fi
fi

echo
echo "Starting PyStudio..."
echo "Open: http://${DISPLAY_HOST}:${PORT}"
echo "Press Ctrl+C to stop."
echo

exec .venv/bin/python -m uvicorn app:asgi_app \
    --host 0.0.0.0 \
    --port "$PORT"
