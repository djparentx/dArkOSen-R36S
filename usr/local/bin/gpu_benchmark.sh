#!/bin/bash
source /usr/local/bin/benchmark_common.sh

BENCH_DIR="/home/ark/.benchmark_data"
GLMARK="/usr/local/bin/glmark2-es2-drm-legacy"
GL_LOG="/tmp/gpu_benchmark.log"
SAMPLES="/tmp/gpu_benchmark.samples"

if [ ! -x "$GLMARK" ] || [ ! -d "$BENCH_DIR/shaders" ]; then
    echo "glmark2 or its data is missing"
    exit 1
fi

EGL=$(readlink -f /usr/lib/aarch64-linux-gnu/libEGL.so.1)
case "$EGL" in
    *[Mm]ali*) ;;
    *) echo "libEGL is not the Mali blob:"; echo "$EGL"; exit 1 ;;
esac

GPU_MIN_ORIG=$(cat "$GPU_DEV/min_freq" 2>/dev/null)
SAMPLER_PID=""

cleanup() {
    [ -n "$SAMPLER_PID" ] && kill "$SAMPLER_PID" 2>/dev/null
    [ -n "$GPU_MIN_ORIG" ] && echo "$GPU_MIN_ORIG" > "$GPU_DEV/min_freq" 2>/dev/null
    rm -f "$SAMPLES"
}
trap cleanup EXIT

# Pin GPU to max so devfreq cannot scale down during the run
cat "$GPU_DEV/max_freq" > "$GPU_DEV/min_freq" 2>/dev/null

rm -f "$GL_LOG" "$SAMPLES"
TEMP_START=$(get_temp)
start_sampler "$SAMPLES" get_gpu_mhz

"$GLMARK" --off-screen --data-path="$BENCH_DIR" --size 320x240 \
    -b build:duration=15 -b texture:duration=15 \
    -b shading:duration=15 -b terrain:duration=15 > "$GL_LOG" 2>&1

kill "$SAMPLER_PID" 2>/dev/null
SAMPLER_PID=""

read -r TEMP_AVG TEMP_PEAK GPU_MHZ <<< "$(sample_stats "$SAMPLES")"
SCORE=$(awk '/glmark2 Score:/ {print $NF}' "$GL_LOG")

if [ -z "$SCORE" ]; then
    echo "GPU BENCHMARK FAILED"
    tail -n 3 "$GL_LOG"
    exit 1
fi

rm -f "$GL_LOG"
log_score GPU "$SCORE" "$GPU_MHZ" "$TEMP_START" "$TEMP_AVG" "$TEMP_PEAK"

echo "SCORE: $SCORE"
echo "GPU: ${GPU_MHZ} MHz"
echo "TEMP: ${TEMP_START}C -> ${TEMP_AVG}C -> ${TEMP_PEAK}C peak"
