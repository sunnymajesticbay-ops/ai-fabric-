#!/bin/bash
# Runs on a switch. Records every port's byte counters every 2 seconds.
# Usage: sampler.sh <switch_name> <seconds> <output_file>
# Output lines: elapsed_ms,switch,port,rx_bytes,tx_bytes
LABEL=$1; SECS=$2; OUT=$3
start=$(date +%s%3N)
: > "$OUT"
while :; do
  now=$(( $(date +%s%3N) - start ))
  for d in /sys/class/net/swp*; do
    [ -e "$d/statistics/rx_bytes" ] || continue
    echo "$now,$LABEL,${d##*/},$(cat $d/statistics/rx_bytes),$(cat $d/statistics/tx_bytes)" >> "$OUT"
  done
  [ "$now" -ge $(( SECS * 1000 )) ] && break
  sleep 2
done
