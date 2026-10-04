#!/usr/bin/env bash
# Mirror the calibration run into persistent storage while it runs (2026-10-04):
# run log every 15s + a timestamped copy of variables.cfg each time it changes.
# Survives an e-stop / host reboot (unlike /tmp). Stops 2 min after the run ends.
OUT=$HOME/printer_data/config/config_backups/calibration_20261004
VAR=$HOME/printer_data/config/variables.cfg
mkdir -p "$OUT"
last=""
done_since=0
while true; do
    for f in /tmp/hot_calibration.log /tmp/hot_calibration.attempt1.log; do
        [ -f "$f" ] && cp "$f" "$OUT/"
    done
    h=$(sha1sum "$VAR" | cut -c1-12)
    if [ "$h" != "$last" ]; then
        cp "$VAR" "$OUT/variables.cfg.$(date +%H%M%S)"
        last=$h
    fi
    if grep -qE "DONE|ERROR|ABORT" /tmp/hot_calibration.log 2>/dev/null; then
        done_since=$((done_since+1))
        [ $done_since -ge 8 ] && break
    fi
    sleep 15
done
