#!/usr/bin/env python3
# Live flow watcher for the Boss (2026-10-04). Logs ~2 Hz while a print runs:
# Z, live volumetric flow (live_extruder_velocity x 1.75mm filament area), active
# extruder temp/target/power, and the active tool's encoder. Flags hotend temp sag,
# heater saturation and encoder trips with the flow at that moment.
import json, time, urllib.request, os, math
API = "http://127.0.0.1:7125"
OUT = os.path.expanduser("~/printer_data/config/config_backups/calibration_20261004/flow_watch.log")
AREA = math.pi * (1.75 / 2) ** 2   # mm^2

def q(objs):
    url = API + "/printer/objects/query?" + "&".join(objs)
    return json.load(urllib.request.urlopen(url, timeout=3))["result"]["status"]

def log(msg):
    with open(OUT, "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")

base = q(["toolchanger=tool_number", "print_stats=filename"])
tn = base["toolchanger"]["tool_number"]
ext = "extruder" if tn == 0 else "extruder%d" % tn
enc = "filament_motion_sensor encoder_sensor%d" % tn
log("=== watching %s on T%d (%s, encoder %s)" % (base["print_stats"]["filename"], tn, ext, enc))
sag_n = sat_n = 0
peak = 0.0
last_line = 0
flagged = set()
while True:
    try:
        s = q(["print_stats=state", "gcode_move=gcode_position", "motion_report=live_extruder_velocity",
               "%s=temperature,target,power" % ext, enc.replace(" ", "%20"), "virtual_sdcard=progress"])
    except Exception as e:
        log("query error %s" % e); time.sleep(2); continue
    st = s["print_stats"]["state"]
    if st not in ("printing", "paused"):
        log("=== print state %s -> watcher done. peak flow %.1f mm3/s" % (st, peak)); break
    z = s["gcode_move"]["gcode_position"][2]
    v = s["motion_report"]["live_extruder_velocity"] or 0.0
    flow = max(0.0, v) * AREA
    e = s[ext]; t, tg, pw = e["temperature"], e["target"], e["power"]
    encd = s.get(enc, {}).get("filament_detected")
    prog = s["virtual_sdcard"]["progress"] * 100
    if flow > peak + 0.5:
        peak = flow
        log("new peak flow %.1f mm3/s at Z%.2f (T %.1f/%.0f, power %.2f)" % (flow, z, t, tg, pw))
    sag_n = sag_n + 1 if (tg > 0 and t < tg - 5) else 0
    sat_n = sat_n + 1 if pw >= 0.95 else 0
    if sag_n == 4:
        log("!! TEMP SAG: %.1f/%.0f C at Z%.2f, flow %.1f mm3/s, power %.2f" % (t, tg, z, flow, pw))
    if sat_n == 8:
        log("!! HEATER SATURATED (>=95%% for 4s) at Z%.2f, flow %.1f mm3/s, T %.1f/%.0f" % (z, flow, t, tg))
    if encd is False and "enc" not in flagged:
        flagged.add("enc"); log("!! ENCODER: filament NOT detected at Z%.2f, flow %.1f mm3/s" % (z, flow))
    if time.time() - last_line > 15:
        last_line = time.time()
        log("Z%.2f  flow %5.1f mm3/s  T %.1f/%.0f  power %.2f  encoder %s  %.0f%%" % (z, flow, t, tg, pw, encd, prog))
    time.sleep(0.5)
