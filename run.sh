#!/usr/bin/env bash
set -Eeuo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# ============================================================
#  COLORS
# ============================================================
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_AMBER=$'\033[38;5;214m'
    C_GOLD=$'\033[38;5;220m'
    C_WHITE=$'\033[38;5;255m'
    C_CREAM=$'\033[38;5;253m'
    C_EMBER=$'\033[38;5;166m'
else
    C_RESET='' C_BOLD='' C_AMBER='' C_GOLD='' C_WHITE='' C_CREAM='' C_EMBER=''
fi

# ============================================================
#  PREREQUISITES
# ============================================================
if [[ ! -x .venv/bin/python ]]; then
    printf '  %b[✗]%b %bPython environment missing. Run ./install.sh first.%b\n' "$C_BOLD$C_EMBER" "$C_RESET" "$C_WHITE" "$C_RESET" >&2
    exit 1
fi

if ! .venv/bin/python -c "import uvicorn" >/dev/null 2>&1; then
    printf '  %b[✗]%b %bUvicorn is missing. Run ./install.sh again.%b\n' "$C_BOLD$C_EMBER" "$C_RESET" "$C_WHITE" "$C_RESET" >&2
    exit 1
fi

# ============================================================
#  UI HELPERS
# ============================================================
step() { printf '  %b[*]%b %b%s%b\n' "$C_BOLD$C_AMBER" "$C_RESET" "$C_WHITE" "$*" "$C_RESET"; }
note() { printf '  %b%s%b\n' "$C_CREAM" "$*" "$C_RESET"; }

printf '\n  %bPyStudio launcher%b\n\n' "$C_BOLD$C_AMBER" "$C_RESET"

# ============================================================
#  1. PORT
# ============================================================
printf '  %bPort%b %b[default 8000]%b: ' "$C_BOLD$C_WHITE" "$C_RESET" "$C_CREAM" "$C_RESET"
read -r PORT_INPUT
PORT="${PORT_INPUT:-8000}"

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    printf '  %b[!]%b %bInvalid port. Using 8000.%b\n' "$C_BOLD$C_AMBER" "$C_RESET" "$C_WHITE" "$C_RESET"
    PORT=8000
fi

# ============================================================
#  2. EXPOSURE MODE
# ============================================================
printf '\n  %bHow should PyStudio be exposed?%b\n' "$C_BOLD$C_WHITE" "$C_RESET"
printf '    %b1)%b Have Domain      %b(bind 0.0.0.0, enter domain name)%b\n' "$C_AMBER" "$C_RESET" "$C_CREAM" "$C_RESET"
printf '    %b2)%b Expose Locally   %b(bind 127.0.0.1, this machine only)%b\n' "$C_AMBER" "$C_RESET" "$C_CREAM" "$C_RESET"
printf '    %b3)%b Expose to LAN    %b(bind detected LAN IP)%b\n' "$C_AMBER" "$C_RESET" "$C_CREAM" "$C_RESET"
printf '  %bSelect [1/2/3, default 3]%b: ' "$C_BOLD$C_WHITE" "$C_RESET"
read -r MODE_INPUT
MODE_INPUT="${MODE_INPUT:-3}"

case "$MODE_INPUT" in
    1) MODE="Domain" ;;
    2) MODE="Local" ;;
    3) MODE="Lan" ;;
    *) 
        printf '  %b[!]%b %bInvalid choice. Using LAN.%b\n' "$C_BOLD$C_AMBER" "$C_RESET" "$C_WHITE" "$C_RESET"
        MODE="Lan" 
        ;;
esac

# ============================================================
#  3. DOMAIN NAME (IF SELECTED)
# ============================================================
DOMAIN=""
if [[ "$MODE" == "Domain" ]]; then
    printf '  %bDomain name%b %b(e.g. myapp.local)%b: ' "$C_BOLD$C_WHITE" "$C_RESET" "$C_CREAM" "$C_RESET"
    read -r DOMAIN
    if [[ -z "${DOMAIN:-}" ]]; then
        printf '  %b[!]%b %bNo domain entered. Falling back to LAN mode.%b\n' "$C_BOLD$C_AMBER" "$C_RESET" "$C_WHITE" "$C_RESET"
        MODE="Lan"
    fi
fi

# ============================================================
#  4. DETECT LAN IP (IF NEEDED)
# ============================================================
LAN_IP="127.0.0.1"
if command -v ip >/dev/null 2>&1; then
    DETECTED_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true)"
    if [[ -n "${DETECTED_IP:-}" ]]; then
        LAN_IP="$DETECTED_IP"
    fi
elif command -v ifconfig >/dev/null 2>&1; then
    DETECTED_IP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1 || true)"
    if [[ -n "${DETECTED_IP:-}" ]]; then
        LAN_IP="$DETECTED_IP"
    fi
fi

# ============================================================
#  5. DECIDE BIND HOST & DISPLAY URL
# ============================================================
if [[ "$MODE" == "Domain" ]]; then
    BIND_HOST="0.0.0.0"
    DISPLAY_URL="http://${DOMAIN}:${PORT}"
    LOCAL_URL="http://${LAN_IP}:${PORT}"
elif [[ "$MODE" == "Local" ]]; then
    BIND_HOST="127.0.0.1"
    DISPLAY_URL="http://127.0.0.1:${PORT}"
else
    BIND_HOST="$LAN_IP"
    DISPLAY_URL="http://${LAN_IP}:${PORT}"
fi

# ============================================================
#  6. SUMMARY
# ============================================================
printf '\n'
step "Starting PyStudio from $(pwd -P)"
step "Mode      : $MODE"
step "Bind host : $BIND_HOST"
step "Port      : $PORT"
step "URL       : $DISPLAY_URL"

if [[ "$MODE" == "Domain" ]]; then
    note "If '$DOMAIN' does not resolve, add it to your hosts file or DNS."
    note "Direct LAN URL: $LOCAL_URL"
elif [[ "$MODE" == "Local" ]]; then
    note "Accessible only from this machine."
else
    note "Reachable on your LAN at $DISPLAY_URL"
fi
printf '\n'

# ============================================================
#  7. LAUNCH
# ============================================================
exec .venv/bin/python -m uvicorn app:asgi_app --host "$BIND_HOST" --port "$PORT"