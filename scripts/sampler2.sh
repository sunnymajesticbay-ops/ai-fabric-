#!/bin/bash
# Runs on a switch or a server. Every 2 seconds it records port byte counters,
# port drop counters, and CPU time.
# Usage: sampler2.sh <node_name> <seconds> <output_prefix> <port_pattern>
#   <prefix>-ports.csv : elapsed_ms,node,port,rx_bytes,tx_bytes,rx_dropped,tx_dropped
#   <prefix>-cpu.csv   : elapsed_ms,node,cpu_total,cpu_idle,cpu_softirq,cpu_steal
LABEL=$1; SECS=$2; OUT=$3; PAT=$4
start=$(date +%s%3N)
: > "$OUT-ports.csv"; : > "$OUT-cpu.csv"
while :; do
  now=$(( $(date +%s%3N) - start ))
  for d in /sys/class/net/$PAT; do
    s=$d/statistics
    [ -e "$s/rx_bytes" ] || continue
    echo "$now,$LABEL,${d##*/},$(cat $s/rx_bytes),$(cat $s/tx_bytes),$(cat $s/rx_dropped),$(cat $s/tx_dropped)" >> "$OUT-ports.csv"
  done
  read -r _ u n sy id io irq sirq st _ < /proc/stat
  echo "$now,$LABEL,$(( u + n + sy + id + io + irq + sirq + st )),$(( id + io )),$sirq,$st" >> "$OUT-cpu.csv"
  [ "$now" -ge $(( SECS * 1000 )) ] && break
  sleep 2
done
