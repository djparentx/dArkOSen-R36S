#!/bin/bash
source /usr/local/bin/benchmark_common.sh

BENCH="/usr/local/bin/ram_bench"
SAMPLES="/tmp/ram_benchmark.samples"

if [ ! -x "$BENCH" ]; then
    echo "ram_bench is missing"
    exit 1
fi

DMC_MIN_ORIG=$(cat "$DMC_DEV/min_freq" 2>/dev/null)
SAMPLER_PID=""

cleanup() {
    [ -n "$SAMPLER_PID" ] && kill "$SAMPLER_PID" 2>/dev/null
    [ -n "$DMC_MIN_ORIG" ] && echo "$DMC_MIN_ORIG" > "$DMC_DEV/min_freq" 2>/dev/null
    rm -f "$SAMPLES"
}
trap cleanup EXIT

# Pin DDR to max so devfreq cannot scale down during the run
cat "$DMC_DEV/max_freq" > "$DMC_DEV/min_freq" 2>/dev/null

rm -f "$SAMPLES"
TEMP_START=$(get_temp)
start_sampler "$SAMPLES" get_dmc_mhz

read -r WRITE COPY <<< "$("$BENCH")"

kill "$SAMPLER_PID" 2>/dev/null
SAMPLER_PID=""

read -r TEMP_AVG TEMP_PEAK DMC_MHZ <<< "$(sample_stats "$SAMPLES")"

if [ -z "$WRITE" ] || [ -z "$COPY" ]; then
    echo "RAM BENCHMARK FAILED"
    exit 1
fi

log_score RAM "Write ${WRITE} / Copy ${COPY} MB/s" "$DMC_MHZ" "$TEMP_START" "$TEMP_AVG" "$TEMP_PEAK"

echo "WRITE: $WRITE MB/s"
echo "COPY: $COPY MB/s"
echo "DDR: ${DMC_MHZ} MHz"
echo "TEMP: ${TEMP_START}C -> ${TEMP_AVG}C -> ${TEMP_PEAK}C peak"
