#!/usr/bin/env bash
# Boss hot calibration, part 6 (axes_map fixed, T1-T3) (2026-10-04): T3 probe z offset + hot shapers T0-T2.
# Bed held at 100C. Logs straight to persistent storage. Stops at the first error
# or the first wrong tool detection.
LOG=$HOME/printer_data/config/config_backups/calibration_20261004/hot_calibration6_axesmap.log
API=http://127.0.0.1:7125
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }
G() {
    local out
    out=$(curl -s -m "${2:-3600}" -X POST "$API/printer/gcode/script" \
          -H "Content-Type: application/json" -d "{\"script\":\"$1\"}")
    case "$out" in *'"result":"ok"'*) return 0;; esac
    log "ERROR on '$1': $(echo "$out" | head -c 300)"; return 1
}
q() { curl -s -m5 "$API/printer/objects/query?$1"; }
expect_tool() {   # stop unless the probes detect exactly tool $1
    G "DETECT_ACTIVE_TOOL_PROBE" 30 || exit 1
    local d
    d=$(q tool_probe_endstop=active_tool_number | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['status']['tool_probe_endstop']['active_tool_number'])")
    log "   detected tool: $d (expected $1)"
    [ "$d" = "$1" ] || { log "ERROR: wrong/no tool detected -> STOP"; exit 1; }
}
grab() {
    curl -s -m5 "$API/server/gcode_store?count=${2:-80}" | python3 -c "
import json,sys,re
for g in json.load(sys.stdin)['result']['gcode_store']:
    m=re.sub('<[^>]+>','',g['message'])
    if re.search(r'$1', m, re.I): print('   ', m[:220])" | tee -a "$LOG"
}
log "=== part 6 (axes_map fixed, T1-T3) start"
case "$(q print_stats=state)" in *printing*|*paused*) log "ABORT: printer busy"; exit 1;; esac
G "SET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=100" 30 || exit 1
G "SET_IDLE_TIMEOUT TIMEOUT=14400" 30
until q heater_bed=temperature | python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin)['result']['status']['heater_bed']['temperature']>=99 else 1)"; do sleep 15; done
log "bed at temp"

G "DETECT_ACTIVE_TOOL_PROBE" 30 || exit 1
T=$(q tool_probe_endstop=active_tool_number | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['status']['tool_probe_endstop']['active_tool_number'])")
log "mounted tool at start: $T"
case "$T" in 0|1|2|3) ;; *) log "ERROR: no real tool mounted -> STOP"; exit 1;; esac
G "M117 Init T$T, home, QGL" 10
G "INITIALIZE_TOOLCHANGER T=$T" 120 || exit 1
expect_tool $T
G "G28" 900 || exit 1
expect_tool $T
G "QUAD_GANTRY_LEVEL" 1200 || exit 1
expect_tool $T
grab 'Retries:.*range' 30

for t in 1 2 3; do
    log "hot input shaper T$t (one tool per command; T0 saved 15:4x)"
    G "M117 Input shaper T$t (hot)" 10
    G "TC_SHAPER_CALIBRATE T=$t" 3600 || { grab "Recommended shaper|shaper_type_|written to" 80; exit 1; }
    grep -E "^shapers_t$t" "$HOME/printer_data/config/variables.cfg" | tee -a "$LOG"
    cp /tmp/calibration_data_*20261004* "$(dirname "$LOG")/" 2>/dev/null
done

G "UNSELECT_TOOL" 300
G "DETECT_ACTIVE_TOOL_PROBE" 30
G "M117 Calibration done" 10
log "=== DONE (bed left at 100C)"
