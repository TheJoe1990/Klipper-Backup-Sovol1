#!/usr/bin/env bash
# Save a tool's shaper result into SVF by hand (used when a "Timer too close"
# shutdown hit right after the result printed, before TC_SHAPER_CALIBRATE saved it).
# Usage: save_shaper_svf.sh <tool> <xtype> <xfreq> <ytype> <yfreq>   (damp 0.2 = macro default)
t=$1; v="{'x': {'type': '$2', 'freq': $3, 'damp': 0.2}, 'y': {'type': '$4', 'freq': $5, 'damp': 0.2}}"
python3 - "$t" "$v" <<'EOF'
import json, sys, urllib.request
t, v = sys.argv[1], sys.argv[2]
script = 'SAVE_VARIABLE VARIABLE=shapers_t%s VALUE="%s"' % (t, v)
req = urllib.request.Request('http://127.0.0.1:7125/printer/gcode/script',
        data=json.dumps({'script': script}).encode(), headers={'Content-Type': 'application/json'})
print(urllib.request.urlopen(req, timeout=30).read().decode()[:120])
EOF
grep "^shapers_t$t" "$HOME/printer_data/config/variables.cfg"
