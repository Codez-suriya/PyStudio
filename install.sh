#!/usr/bin/env bash
set -Eeuo pipefail

REPO="https://github.com/Codez-suriya/PyStudio.git"
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# If downloaded by itself, clone the complete repository first.
if [[ ! -f "$PROJECT_DIR/app.py" || ! -f "$PROJECT_DIR/requirements.txt" ]]; then
    PROJECT_DIR="$HOME/PyStudio"

    if [[ ! -d "$PROJECT_DIR/.git" ]]; then
        if ! command -v git >/dev/null 2>&1; then
            echo "Git is required. Install it first."
            exit 1
        fi
        git clone "$REPO" "$PROJECT_DIR"
    else
        git -C "$PROJECT_DIR" pull --ff-only
    fi

    exec bash "$PROJECT_DIR/install.sh"
fi

cd "$PROJECT_DIR"

echo "=================================="
echo "       PyStudio Installer"
echo "=================================="

if [[ -n "${PREFIX:-}" && "$PREFIX" == *com.termux* ]]; then
    pkg update
    pkg install -y python
    PYTHON="python"
    "$PYTHON" -m venv .venv
    .venv/bin/python -m pip install --upgrade pip
    .venv/bin/python -m pip install -r requirements.txt
else
    if ! command -v uv >/dev/null 2>&1; then
        if command -v curl >/dev/null 2>&1; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
        else
            echo "Install curl, then rerun this script."
            exit 1
        fi

        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    fi

    uv python install
    uv venv --python 3 .venv
    uv pip install --python .venv/bin/python -r requirements.txt
fi

chmod +x run.sh 2>/dev/null || true

echo
echo "PyStudio installation complete!"
echo "Run it with: cd \"$PROJECT_DIR\" && ./run.sh"
