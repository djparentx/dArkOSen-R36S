#!/bin/bash
source /usr/local/bin/benchmark_common.sh

BENCH="/usr/local/bin/cpu_bench"
SAMPLES="/tmp/cpu_benchmark.samples"
GOV_FILES=(/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor)

if [ ! -x "$BENCH" ]; then
    echo "cpu_bench is missing"
    exit 1
fi

GOV_ORIG=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
SAMPLER_PID=""

cleanup() {
    [ -n "$SAMPLER_PID" ] && kill "$SAMPLER_PID" 2>/dev/null
    if [ -n "$GOV_ORIG" ]; then
        for f in "${GOV_FILES[@]}"; do echo "$GOV_ORIG" > "$f" 2>/dev/null; done
    fi
    rm -f "$SAMPLES"
}
trap cleanup EXIT

for f in "${GOV_FILES[@]}"; do echo performance > "$f" 2>/dev/null; done

rm -f "$SAMPLES"
TEMP_START=$(get_temp)
start_sampler "$SAMPLES" get_cpu_mhz

RAW=$("$BENCH")
SCORE=""
[ -n "$RAW" ] && [ "$RAW" -gt 0 ] 2>/dev/null && SCORE=$(( RAW / 1000000 ))

kill "$SAMPLER_PID" 2>/dev/null
SAMPLER_PID=""

read -r TEMP_AVG TEMP_PEAK CPU_MHZ <<< "$(sample_stats "$SAMPLES")"

if [ -z "$SCORE" ]; then
    echo "CPU BENCHMARK FAILED"
    exit 1
fi

log_score CPU "$SCORE Mops/30s" "$CPU_MHZ" "$TEMP_START" "$TEMP_AVG" "$TEMP_PEAK"

echo "SCORE: $SCORE Mops/30s"
echo "CPU: ${CPU_MHZ} MHz"
echo "TEMP: ${TEMP_START}C -> ${TEMP_AVG}C -> ${TEMP_PEAK}C peak"