#!/bin/bash
# Runs on a server. Starts rate-limited iperf3 flows to other servers.
# Usage: flows.sh <server_id> <pattern> <seconds> <rate>
#   same   : one flow per rail to the next server, staying on the same rail
#   cross1 : one flow per rail to the next server, landing on a different rail
#   cross3 : three flows per rail, to all three other servers, on different rails
S=$1; PATTERN=$2; SECS=$3; RATE=$4
case $PATTERN in
  same)   OFFSETS="0" ;;
  cross1) OFFSETS="1" ;;
  cross3) OFFSETS="1 2 3" ;;
  *) echo "unknown pattern: $PATTERN"; exit 2 ;;
esac
pids=""
for rail in 1 2 3 4 5; do
  for o in $OFFSETS; do
    if [ "$o" = 0 ]; then
      dst_rail=$rail; peer=$(( S % 4 + 1 ))
    else
      dst_rail=$(( (rail + o - 1) % 5 + 1 )); peer=$(( (S + o - 1) % 4 + 1 ))
    fi
    port=$(( 5200 + (S - 1) * 5 + rail ))
    timeout -k 5 $(( SECS + 20 )) iperf3 -c 10.$dst_rail.$peer.2 -B 10.$rail.$S.2 -p $port -b $RATE -t $SECS >/dev/null 2>&1 &
    pids="$pids $!"
  done
done
ok=0; total=0
for p in $pids; do total=$(( total + 1 )); wait $p && ok=$(( ok + 1 )); done
echo "$ok of $total flows completed"
