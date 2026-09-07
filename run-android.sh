#!/bin/bash
set -euo pipefail

DEVICE_DIR=/data/local/tmp/rkllm-eos-repro
MODEL=smolvlm2-256m-instruct_w8a8_rk3588.rkllm
PROMPT="What is 2+2? Answer with a single number."
MAX_NEW_TOKENS=100

cd "$(dirname "$0")"

if [ ! -d install ]; then
  echo "No install/; run ./build-android.sh first"
  exit 1
fi

adb shell "mkdir -p $DEVICE_DIR"
adb push --sync install/repro-1.3.0 install/repro-1.2.3 "$DEVICE_DIR/"
adb push --sync install/lib-1.3.0 install/lib-1.2.3 "$DEVICE_DIR/"
adb push --sync "model/$MODEL" "$DEVICE_DIR/"
adb shell "chmod 755 $DEVICE_DIR/repro-1.3.0 $DEVICE_DIR/repro-1.2.3"

mkdir -p logs

run() {
  local ver=$1
  echo
  echo "=== $ver ==="
  since=$(adb shell 'date "+%m-%d %H:%M:%S.000"' | tr -d '\r')
  adb shell "cd $DEVICE_DIR && RKLLM_LOG_LEVEL=2 LD_LIBRARY_PATH=./lib-$ver ./repro-$ver $MODEL $MAX_NEW_TOKENS '$PROMPT'" \
    | tee "logs/$ver.log"
  echo "--- runtime logs ---"
  adb logcat -d -t "$since" -s rkllm | tee "logs/$ver.logcat"
}

run 1.2.3
run 1.3.0
