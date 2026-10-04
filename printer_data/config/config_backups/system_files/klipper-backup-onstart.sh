#!/usr/bin/env bash
# Run by klipper-backup-onstart.service (2026-10-03), which the restart watcher
# triggers after every Klipper start / RESTART / FIRMWARE_RESTART.
#
# Never compete with a print:
#  - printing/paused when the backup is due -> wait until the print is over
#  - a print starts DURING the backup        -> stop git at once, clean up the
#    lock it may leave, and redo the backup after the print
# (Test hook: the file /tmp/backup-test-printing counts as "printing".)
REPO="$HOME/config_backup"

busy() {
    [ -e /tmp/backup-test-printing ] && return 0
    local s
    s=$(curl -s -m4 "http://127.0.0.1:7125/printer/objects/query?print_stats=state" \
        | grep -oE "\"state\": *\"[a-z]+\"" | grep -oE "[a-z]+\"$" | tr -d "\"")
    [ "$s" = printing ] || [ "$s" = paused ]
}

while true; do
    if busy; then
        echo "printer busy - backup waiting for the print to finish"
        while busy; do sleep 60; done
    fi
    # own process group so the whole backup (git included) can be stopped at once
    setsid "$HOME/klipper-backup/script.sh" -c "Klipper start backup - $(date +"%x %X")" &
    pid=$!
    aborted=0
    while kill -0 "$pid" 2>/dev/null; do
        if busy; then kill -TERM -- "-$pid" 2>/dev/null; aborted=1; break; fi
        sleep 2
    done
    wait "$pid"; rc=$?
    if [ "$aborted" = 1 ]; then
        rm -f "$REPO/.git/index.lock"
        echo "print started - backup stopped, will redo it after the print"
        continue
    fi
    exit $rc
done
