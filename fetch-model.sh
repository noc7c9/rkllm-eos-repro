#!/bin/bash
set -euo pipefail

HF_REPO="Qengineering/SmolVLM2-256m-rk3588"
MODEL="smolvlm2-256m-instruct_w8a8_rk3588.rkllm"

URL="https://huggingface.co/$HF_REPO/resolve/main/$MODEL"

cd "$(dirname "$0")"
mkdir -p model

if [ -f "model/$MODEL" ]; then
  echo "$MODEL already present"
  exit 0
fi

echo "Fetching $URL"
curl -fL --progress-bar -o "model/$MODEL" "$URL"
