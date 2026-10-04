#!/usr/bin/env bash
# 2026-10-03: back up config to GitHub after EVERY Klipper start, including
# FIRMWARE_RESTART / RESTART (that is when config edits take effect).
# Klipper logs "Start printer at ..." on each start; tail -F blocks (no CPU)
# and follows the log across rotation. klipper-backup-onstart.service waits
# 90s then runs at Nice 19 / idle IO, and a start request while it is already
# pending merges into the same run, so back-to-back restarts = one backup.
tail -n0 -F /home/biqu/printer_data/logs/klippy.log 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        "Start printer at"*) systemctl start --no-block klipper-backup-onstart.service ;;
    esac
done
