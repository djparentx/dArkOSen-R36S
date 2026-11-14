#!/bin/bash
# Sourced by gpu_benchmark.sh, cpu_benchmark.sh, ram_benchmark.sh

BENCH_DIR="/home/ark/.benchmark_data"
SCORES_LOG="$BENCH_DIR/scores.log"
CPU_TEMP="/sys/class/thermal/thermal_zone0/temp"
GPU_DEV="/sys/class/devfreq/ff400000.gpu"
DMC_DEV="/sys/class/devfreq/dmc"

get_temp()    { echo $(( $(cat "$CPU_TEMP" 2>/dev/null || echo 0) / 1000 )); }
get_cpu_mhz() { echo $(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0) / 1000 )); }
get_gpu_mhz() { echo $(( $(cat "$GPU_DEV/cur_freq" 2>/dev/null || echo 0) / 1000000 )); }
get_dmc_mhz() { echo $(( $(cat "$DMC_DEV/cur_freq" 2>/dev/null || echo 0) / 1000000 )); }

# start_sampler <file> <freq function> : appends "temp mhz" every second
start_sampler() {
    ( while true; do echo "$(get_temp) $($2)" >> "$1"; sleep 1; done ) &
    SAMPLER_PID=$!
}

# sample_stats <file> : prints "avg_temp peak_temp peak_mhz"
sample_stats() {
    awk '{s+=$1; n++; if($1>t)t=$1; if($2>f)f=$2}
         END{ if(n>0) printf "%d %d %d", s/n, t, f; else printf "0 0 0" }' "$1"
}

# log_score <type> <score> <mhz> <temp start> <temp avg> <temp peak>
log_score() {
    mkdir -p "$BENCH_DIR"
    if [ ! -s "$SCORES_LOG" ]; then
        printf '%-17s %-5s %-26s %-6s %-6s %-6s %-6s\n' DATE TYPE SCORE MHZ START AVG PEAK >> "$SCORES_LOG"
    fi
    printf '%-17s %-5s %-26s %-6s %-6s %-6s %-6s\n' \
        "$(date '+%Y-%m-%d %H:%M')" "$1" "$2" "$3" "$4" "$5" "$6" >> "$SCORES_LOG"
    chown ark:ark "$BENCH_DIR" "$SCORES_LOG" 2>/dev/null
}
