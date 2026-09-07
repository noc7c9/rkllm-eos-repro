#!/bin/bash
set -euo pipefail

VERSIONS=(1.3.0 1.2.3)
RAW="https://raw.githubusercontent.com/airockchip/rknn-llm"
RUNTIME="rkllm-runtime/Android/librkllm_api"

cd "$(dirname "$0")"

: "${ANDROID_NDK_PATH:=$HOME/Library/Android/sdk/ndk/25.2.9519653}"

if [ ! -d "$ANDROID_NDK_PATH" ]; then
  echo "No NDK at $ANDROID_NDK_PATH; set ANDROID_NDK_PATH"
  exit 1
fi

for ver in "${VERSIONS[@]}"; do
  mkdir -p "runtime/$ver"
  for f in include/rkllm.h arm64-v8a/librkllmrt.so arm64-v8a/libomp.so; do
    out="runtime/$ver/$(basename "$f")"
    if [ ! -f "$out" ]; then
      echo "Fetching $ver $(basename "$f")"
      curl -fL --progress-bar -o "$out" "$RAW/release-v$ver/$RUNTIME/$f"
    fi
  done
done

rm -rf build install
cmake -B build -S . \
  -DCMAKE_ANDROID_NDK="$ANDROID_NDK_PATH" \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_SYSTEM_VERSION=23 \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_ANDROID_STL_TYPE=c++_static \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build

echo
find install -type f -exec ls -l {} +
