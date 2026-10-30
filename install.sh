#!/usr/bin/env bash
# ============================================================
#  PyStudio Installer
#  Repository: https://github.com/Codez-suriya/PyStudio
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Terminal colors: warm orange gradient + white (256-color)
# ------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'

    # --- Orange gradient (deep → gold) -----------------------
    C_EMBER=$'\033[38;5;166m'          # deep burnt orange
    C_ORANGE=$'\033[38;5;208m'         # vivid orange
    C_AMBER=$'\033[38;5;214m'          # bright amber
    C_GOLD=$'\033[38;5;220m'           # warm gold
    C_WARM=$'\033[38;5;178m'           # muted warm amber

    # --- Whites ---------------------------------------------
    C_BRIGHT_WHITE=$'\033[1;38;5;231m' # pure bold white
    C_WHITE=$'\033[38;5;255m'          # bright white
    C_CREAM=$'\033[38;5;253m'          # soft cream

    # --- Subdued labels -------------------------------------
    C_DIM_ORANGE=$'\033[38;5;130m'

    # Compatibility aliases (kept so every helper still works)
    C_RED="$C_EMBER"
    C_GREEN="$C_GOLD"
    C_YELLOW="$C_AMBER"
    C_BLUE="$C_ORANGE"
    C_MAGENTA="$C_BRIGHT_WHITE"
    C_CYAN="$C_ORANGE"
    C_BRIGHT_RED="$C_EMBER"
    C_BRIGHT_GREEN="$C_GOLD"
    C_BRIGHT_YELLOW="$C_AMBER"
    C_BRIGHT_BLUE="$C_ORANGE"
    C_BRIGHT_MAGENTA="$C_BRIGHT_WHITE"
    C_BRIGHT_CYAN="$C_AMBER"
    C_PURPLE="$C_BRIGHT_WHITE"
    C_PINK="$C_AMBER"
else
    C_RESET='' C_BOLD='' C_DIM=''
    C_EMBER='' C_ORANGE='' C_AMBER='' C_GOLD='' C_WARM=''
    C_BRIGHT_WHITE='' C_WHITE='' C_CREAM='' C_DIM_ORANGE=''
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
    C_BRIGHT_RED='' C_BRIGHT_GREEN='' C_BRIGHT_YELLOW=''
    C_BRIGHT_BLUE='' C_BRIGHT_MAGENTA='' C_BRIGHT_CYAN=''
    C_PURPLE='' C_PINK=''
fi

# ------------------------------------------------------------
#  Banner
# ------------------------------------------------------------
banner() {
    local O="$C_BOLD$C_AMBER"
    local W="$C_BOLD$C_BRIGHT_WHITE"
    local R="$C_RESET"

    printf '\n'
    printf '  %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b\n' "$O" '████ ' "$R" "$W" '█   █' "$R" "$O" ' ████' "$R" "$W" '█████' "$R" "$O" '█   █' "$R" "$W" '████ ' "$R" "$O" '█████' "$R" "$W" ' ███ ' "$R"
    printf '  %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b\n' "$O" '█   █' "$R" "$W" '█   █' "$R" "$O" '█    ' "$R" "$W" '  █  ' "$R" "$O" '█   █' "$R" "$W" '█   █' "$R" "$O" '  █  ' "$R" "$W" '█   █' "$R"
    printf '  %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b\n' "$O" '████ ' "$R" "$W" ' ███ ' "$R" "$O" ' ███ ' "$R" "$W" '  █  ' "$R" "$O" '█   █' "$R" "$W" '█   █' "$R" "$O" '  █  ' "$R" "$W" '█   █' "$R"
    printf '  %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b\n' "$O" '█    ' "$R" "$W" '  █  ' "$R" "$O" '    █' "$R" "$W" '  █  ' "$R" "$O" '█   █' "$R" "$W" '█   █' "$R" "$O" '  █  ' "$R" "$W" '█   █' "$R"
    printf '  %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b %b%s%b\n\n' "$O" '█    ' "$R" "$W" '  █  ' "$R" "$O" '████ ' "$R" "$W" '  █  ' "$R" "$O" '█████' "$R" "$W" '████ ' "$R" "$O" '█████' "$R" "$W" ' ███ ' "$R"
}

LOG_FILE="$(mktemp -t pystudio-install.XXXXXX.log)"
trap 'rm -f "$LOG_FILE"' EXIT

# ------------------------------------------------------------
#  Status helpers — icon color only, message stays white
# ------------------------------------------------------------
info() {
    printf '  %b[*]%b %b%s%b\n' "$C_BOLD$C_ORANGE" "$C_RESET" "$C_WHITE" "$*" "$C_RESET"
}
ok() {
    printf '  %b[✓]%b %b%s%b\n' "$C_BOLD$C_GOLD" "$C_RESET" "$C_WHITE" "$*" "$C_RESET"
}
warn() {
    printf '  %b[!]%b %b%s%b\n' "$C_BOLD$C_AMBER" "$C_RESET" "$C_CREAM" "$*" "$C_RESET"
}
fail() {
    printf '  %b[✗]%b %b%s%b\n' "$C_BOLD$C_EMBER" "$C_RESET" "$C_CREAM" "$*" "$C_RESET" >&2
}

header() {
    local title="$1"
    local accent="${2:-$C_AMBER}"
    local width=40
    local len=${#title}

    printf '\n%b========================================%b\n' "$accent" "$C_RESET"
    if (( len >= width )); then
        printf '%b%s%b\n' "$C_BOLD$C_BRIGHT_WHITE" "$title" "$C_RESET"
    else
        local pad=$(( (width - len) / 2 ))
        local pad_right=$(( width - len - pad ))
        printf '%*s%b%s%b%*s\n' \
            "$pad" "" \
            "$C_BOLD$C_BRIGHT_WHITE" "$title" "$C_RESET" \
            "$pad_right" ""
    fi
    printf '%b========================================%b\n\n' "$accent" "$C_RESET"
}

die() {
    fail "$*"
    if [[ -s "$LOG_FILE" ]]; then
        printf '\n  %bLog file:%b %b%s%b\n' \
            "$C_DIM" "$C_RESET" "$C_BOLD$C_AMBER" "$LOG_FILE" "$C_RESET" >&2
        printf '  %bLast 30 lines:%b\n' "$C_DIM" "$C_RESET" >&2
        tail -n 30 "$LOG_FILE" | while IFS= read -r line; do
            printf '    %b%s%b\n' "$C_CREAM" "$line" "$C_RESET" >&2
        done
    fi
    exit 1
}

run_quiet() {
    local desc="$1"; shift
    info "$desc"
    "$@" >>"$LOG_FILE" 2>&1 || die "Failed: $desc"
}

# ------------------------------------------------------------
#  Detect installer directory
# ------------------------------------------------------------
SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

# ------------------------------------------------------------
#  Detect package manager
# ------------------------------------------------------------
IS_TERMUX=false
PKG_MGR=""
SUDO=""

if [[ "${PREFIX:-}" == *"com.termux"* ]]; then
    IS_TERMUX=true
    PKG_MGR="pkg"
elif command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt-get"; [[ $EUID -ne 0 ]] && SUDO="sudo"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf";     [[ $EUID -ne 0 ]] && SUDO="sudo"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman";  [[ $EUID -ne 0 ]] && SUDO="sudo"
elif command -v zypper >/dev/null 2>&1; then
    PKG_MGR="zypper";  [[ $EUID -ne 0 ]] && SUDO="sudo"
elif command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk";     [[ $EUID -ne 0 ]] && SUDO="sudo"
else
    die "Unsupported environment: no known package manager found."
fi

pkg_install() {
    local pkgs=("$@")
    case "$PKG_MGR" in
        pkg)     pkg install -y "${pkgs[@]}" ;;
        apt-get) $SUDO apt-get update -qq && $SUDO apt-get install -y -qq "${pkgs[@]}" ;;
        dnf)     $SUDO dnf install -y -q "${pkgs[@]}" ;;
        pacman)  $SUDO pacman -Sy --noconfirm --needed "${pkgs[@]}" ;;
        zypper)  $SUDO zypper --quiet install -y "${pkgs[@]}" ;;
        apk)     $SUDO apk add --no-cache "${pkgs[@]}" ;;
        *)       die "Unknown package manager: $PKG_MGR" ;;
    esac
}

# ------------------------------------------------------------
#  Resolve project location
# ------------------------------------------------------------
is_project_dir() {
    [[ -f "$1/app.py" && -f "$1/requirements.txt" ]]
}

PROJECT_DIR=""
if is_project_dir "$SCRIPT_DIR"; then
    PROJECT_DIR="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/PyStudio" ]]; then
    if is_project_dir "$SCRIPT_DIR/PyStudio"; then
        PROJECT_DIR="$SCRIPT_DIR/PyStudio"
    else
        die "Directory exists but is not a valid PyStudio project: $SCRIPT_DIR/PyStudio"
    fi
else
    PROJECT_DIR="$SCRIPT_DIR/PyStudio"
fi

banner
header "PyStudio Installer" "$C_AMBER"

printf '  %b[*]%b %bProject directory%b %b%s%b\n' \
    "$C_BOLD$C_ORANGE" "$C_RESET" \
    "$C_DIM_ORANGE" "$C_RESET" \
    "$C_BOLD$C_GOLD" "$PROJECT_DIR" "$C_RESET"

# ------------------------------------------------------------
#  Git and Curl
# ------------------------------------------------------------
header "BASIC REQUIREMENTS" "$C_ORANGE"

ensure_command() {
    local cmd="$1" pkg_name="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd is already installed."
        return 0
    fi
    warn "$cmd is not installed."
    info "Installing $cmd..."
    pkg_install "$pkg_name" >>"$LOG_FILE" 2>&1 || die "Could not install $cmd."
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd still missing after installation."
    ok "$cmd installed successfully."
}

ensure_command git git
ensure_command curl curl

# ------------------------------------------------------------
#  Detect or install Python
# ------------------------------------------------------------
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    warn "Python is not installed."
    info "Installing Python..."
    case "$PKG_MGR" in
        apt-get) pkg_install python3 python3-venv python3-pip >>"$LOG_FILE" 2>&1 || die "Python installation failed." ;;
        dnf)     pkg_install python3 python3-pip        >>"$LOG_FILE" 2>&1 || die "Python installation failed." ;;
        pacman)  pkg_install python python-pip          >>"$LOG_FILE" 2>&1 || die "Python installation failed." ;;
        zypper)  pkg_install python3 python3-pip        >>"$LOG_FILE" 2>&1 || die "Python installation failed." ;;
        apk)     pkg_install python3 py3-pip            >>"$LOG_FILE" 2>&1 || die "Python installation failed." ;;
        pkg)     pkg_install python                     >>"$LOG_FILE" 2>&1 || die "Python installation failed." ;;
    esac
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_BIN="python"
    else
        die "Python still missing after installation."
    fi
    ok "Python installed successfully."
fi

PY_VER="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
[[ -n "$PY_VER" ]] || die "Could not determine Python version."
ok "Python $PY_VER detected."

python_compatible() {
    "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null
}

USE_UV=false
UV_BIN=""

if ! python_compatible; then
    warn "Python $PY_VER is older than 3.8. PyStudio requires Python 3.8+."
    info "Trying uv to provide a compatible runtime..."
    if command -v uv >/dev/null 2>&1; then
        UV_BIN="$(command -v uv)"
    else
        info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh >>"$LOG_FILE" 2>&1 || die "uv installation failed."
        if [[ -x "$HOME/.local/bin/uv" ]]; then
            UV_BIN="$HOME/.local/bin/uv"
        elif command -v uv >/dev/null 2>&1; then
            UV_BIN="$(command -v uv)"
        fi
    fi
    [[ -n "$UV_BIN" ]] || die "uv is not available and system Python is too old."
    ok "uv is available: $UV_BIN"
    info "Installing Python 3.12 via uv..."
    "$UV_BIN" python install 3.12 >>"$LOG_FILE" 2>&1 || die "uv could not install Python 3.12."
    USE_UV=true
    ok "Python 3.12 installed via uv."
else
    ok "Python $PY_VER is compatible."
fi

# ------------------------------------------------------------
#  Clone or validate PyStudio
# ------------------------------------------------------------
if ! is_project_dir "$PROJECT_DIR"; then
    if [[ -d "$PROJECT_DIR" ]]; then
        die "Destination exists but is not a valid PyStudio project: $PROJECT_DIR"
    fi


info "Cloning PyStudio into https://github.com/Codez-suriya/PyStudio.git"

if git clone --quiet --depth 1 \
    https://github.com/Codez-suriya/PyStudio.git \
    "$PROJECT_DIR" 2>&1 |
    sed -u 's/^/        /'; then
    ok "Repository cloned."
else
    die "Git clone failed."
fi



else
    ok "Existing PyStudio project detected; reusing."
fi

is_project_dir "$PROJECT_DIR" || die "Project validation failed: app.py or requirements.txt is missing."
cd "$PROJECT_DIR"

printf '  %b[✓]%b %bWorking directory%b %b%s%b\n' \
    "$C_BOLD$C_GOLD" "$C_RESET" \
    "$C_DIM_ORANGE" "$C_RESET" \
    "$C_BOLD$C_AMBER" "$(pwd -P)" "$C_RESET"

# ------------------------------------------------------------
#  Virtual environment
# ------------------------------------------------------------
header "PYTHON ENVIRONMENT" "$C_AMBER"

VENV_DIR="$PROJECT_DIR/.venv"

if [[ -x "$VENV_DIR/bin/python" ]]; then
    if "$VENV_DIR/bin/python" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
        ok "Reusing existing virtual environment."
    else
        warn "Existing virtual environment is incompatible; recreating."
        rm -rf "$VENV_DIR"
    fi
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    if $USE_UV; then
        info "Creating virtual environment with uv..."
        "$UV_BIN" venv --python 3.12 "$VENV_DIR" >>"$LOG_FILE" 2>&1 || die "uv venv failed."
    else
        info "Creating virtual environment..."
        "$PYTHON_BIN" -m venv "$VENV_DIR" >>"$LOG_FILE" 2>&1 || die "python -m venv failed."
    fi
fi

[[ -x "$VENV_DIR/bin/python" ]] || die "Virtual environment Python not found after creation."

# ------------------------------------------------------------
#  Install dependencies
# ------------------------------------------------------------
header "DEPENDENCIES" "$C_GOLD"

if $USE_UV; then
    info "Installing requirements with uv..."
    "$UV_BIN" pip install \
        --python "$VENV_DIR/bin/python" \
        -r "$PROJECT_DIR/requirements.txt" >>"$LOG_FILE" 2>&1 || die "Dependency installation failed."
else
    info "Installing requirements with pip..."
    "$VENV_DIR/bin/python" -m pip install --upgrade pip >>"$LOG_FILE" 2>&1 || die "pip upgrade failed."
    "$VENV_DIR/bin/python" -m pip install \
        -r "$PROJECT_DIR/requirements.txt" >>"$LOG_FILE" 2>&1 || die "Dependency installation failed."
fi

ok "Dependencies installed."
"$VENV_DIR/bin/python" -c 'import flask, uvicorn, asgiref' >>"$LOG_FILE" 2>&1 \
    || die "Essential imports failed (flask/uvicorn/asgiref)."
ok "Flask, Uvicorn, and ASGI bridge verified."

# ------------------------------------------------------------
#  Validate launcher
# ------------------------------------------------------------
header "LAUNCHER" "$C_WARM"

[[ -f "$PROJECT_DIR/run.sh" ]] || die "run.sh is missing from the project."
chmod +x "$PROJECT_DIR/run.sh" 2>/dev/null || true
chmod +x "$PROJECT_DIR/install.sh" 2>/dev/null || true
ok "run.sh is present and executable."

if grep -q 'app:asgi_app' "$PROJECT_DIR/run.sh"; then
    ok "run.sh targets app:asgi_app via Uvicorn."
else
    warn "run.sh does not explicitly reference app:asgi_app. Verify manually."
fi

# ------------------------------------------------------------
#  Final summary
# ------------------------------------------------------------
header "INSTALLATION COMPLETE" "$C_GOLD"

printf '  %bProject directory%b   %b%s%b\n' \
    "$C_DIM_ORANGE" "$C_RESET" "$C_BOLD$C_GOLD" "$PROJECT_DIR" "$C_RESET"
printf '  %bPython runtime%b      %b%s%b\n' \
    "$C_DIM_ORANGE" "$C_RESET" "$C_BOLD$C_AMBER" "$("$VENV_DIR/bin/python" --version 2>&1)" "$C_RESET"
printf '  %bVirtualenv%b          %b%s%b\n' \
    "$C_DIM_ORANGE" "$C_RESET" "$C_ORANGE" "$VENV_DIR" "$C_RESET"
printf '  %bDependencies%b        %bFlask · Uvicorn · asgiref%b\n' \
    "$C_DIM_ORANGE" "$C_RESET" "$C_WARM" "$C_RESET"

printf '\n  %bStart PyStudio%b\n\n' "$C_BOLD$C_BRIGHT_WHITE" "$C_RESET"
printf '    %b$%b %bcd "%s" && ./run.sh%b\n\n' \
    "$C_AMBER" "$C_RESET" "$C_BOLD$C_GOLD" "$PROJECT_DIR" "$C_RESET"

# Completion card
printf '  %b╭%s╮%b\n' \
    "$C_GOLD" "$(printf '─%.0s' {1..46})" "$C_RESET"
printf '  %b│%b        %b✓  PyStudio is ready to launch!%b       %b│%b\n' \
    "$C_GOLD" "$C_RESET" \
    "$C_BOLD$C_GOLD" "$C_RESET" \
    "$C_GOLD" "$C_RESET"
printf '  %b╰%s╯%b\n\n' \
    "$C_GOLD" "$(printf '─%.0s' {1..46})" "$C_RESET"

ok "Installation finished successfully."

printf '\n'
printf '  %bLaunch PyStudio now?%b %b[Y/n]%b ' \
    "$C_BOLD$C_AMBER" "$C_RESET" "$C_BRIGHT_WHITE" "$C_RESET"

if [[ -t 0 ]]; then
    read -r LAUNCH_CHOICE
else
    LAUNCH_CHOICE="n"
    printf 'n\n'
fi

case "${LAUNCH_CHOICE,,}" in
    y|yes)
        printf '\n'
        printf '  %bLaunching PyStudio...%b\n\n' \
            "$C_BOLD$C_AMBER" "$C_RESET"
        ./run.sh
        ;;
    *)
        printf '\n'
        printf '  %bPyStudio is installed and ready whenever you are.%b\n' \
            "$C_BRIGHT_WHITE" "$C_RESET"
        printf '  %bRun it in /PyStudio folder with: ./run.sh%b\n\n' \
            "$C_AMBER" "$C_RESET"
        ;;
esac
