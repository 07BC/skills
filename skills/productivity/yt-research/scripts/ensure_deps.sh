#!/usr/bin/env bash
set -euo pipefail

WHISPER_MODEL_DIR="${WHISPER_MODEL_DIR:-$HOME/.cache/whisper-models}"
WHISPER_MODEL_NAME="${WHISPER_MODEL_NAME:-ggml-base.en.bin}"
WHISPER_MODEL_URL="${WHISPER_MODEL_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${WHISPER_MODEL_NAME}}"

check_python_pkg() {
    local package="$1"
    if python3 -c "import $package" 2>/dev/null; then
        return 0
    fi
    echo "Installing $package..."
    python3 -m pip install --quiet "$package"
}

check_bin() {
    local bin="$1"
    local hint="$2"
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ERROR: '$bin' is required but not found on PATH." >&2
        echo "Install hint: $hint" >&2
        exit 1
    fi
}

check_python_pkg yt_dlp

check_bin ffmpeg "brew install ffmpeg"
check_bin whisper-cli "brew install whisper-cpp"

mkdir -p "$WHISPER_MODEL_DIR"
if [[ ! -f "$WHISPER_MODEL_DIR/$WHISPER_MODEL_NAME" ]]; then
    echo "Downloading Whisper model: $WHISPER_MODEL_NAME"
    curl -L -s -o "$WHISPER_MODEL_DIR/$WHISPER_MODEL_NAME" "$WHISPER_MODEL_URL"
fi

echo "Dependencies OK"
echo "Whisper model: $WHISPER_MODEL_DIR/$WHISPER_MODEL_NAME"
