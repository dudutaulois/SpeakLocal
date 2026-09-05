#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="$ROOT_DIR/Engine"
SUPPORT_DIR="$HOME/Library/Application Support/SpeakLocal"
VENV_DIR="$SUPPORT_DIR/venv"
PYTHON_BIN="${PYTHON_BIN:-}"
echo "SpeakLocal — installing Kokoro TTS engine"
if [[ "$(uname -m)" != "arm64" ]]; then echo "Error: Apple Silicon required." >&2; exit 1; fi
if [[ -z "$PYTHON_BIN" ]]; then for c in python3.12 python3.11 python3.10 python3; do command -v "$c" >/dev/null && PYTHON_BIN="$c" && break; done; fi
[[ -n "$PYTHON_BIN" ]] || { echo "Install Python 3.10-3.12: brew install python@3.12" >&2; exit 1; }
mkdir -p "$SUPPORT_DIR" "$VENV_DIR"
[[ -d "$VENV_DIR/bin" ]] || "$PYTHON_BIN" -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r "$ENGINE_DIR/requirements.txt"
cp "$ENGINE_DIR/speak.py" "$SUPPORT_DIR/speak.py"
chmod +x "$SUPPORT_DIR/speak.py"
python "$SUPPORT_DIR/speak.py" --warmup
echo "Done! Open Package.swift in Xcode and press ⌘R"
