#!/usr/bin/env python3
# Boss toolchange vs heat-up recorder (2026-10-04 night). ~4 Hz while the print runs.
# Raw CSV + console dump + per-toolchange summary at the end. Read-only: sends no gcode.
import json, time, urllib.request, os
API = "http://127.0.0.1:7125"
D = os.path.expanduser("~/printer_data/config/config_backups/calibration_20261004")
CSV = os.path.join(D, "toolchange_watch.csv")
SUM = os.path.join(D, "toolchange_summary.txt")
EXT = ["extruder", "extruder1", "extruder2", "extruder3"]

def q():
    objs = ["print_stats=state,filename", "toolchanger=status,tool_number",
            "motion_report=live_velocity,live_extruder_velocity", "toolhead=position"]
    objs += ["%s=temperature,target" % e for e in EXT]
    return json.load(urllib.request.urlopen(API + "/printer/objects/query?" + "&".join(objs), timeout=3))["result"]["status"]

rows = []
with open(CSV, "w") as f:
    f.write("t,state,tc_status,tool,vel,evel,z," + ",".join("%s_t,%s_tg" % (e, e) for e in EXT) + "\n")
    started = False
    while True:
        try:
            s = q()
        except Exception:
            time.sleep(1); continue
        st = s["print_stats"]["state"]
        if st in ("printing", "paused"):
            started = True
        elif started:
            break
        r = [time.time(), st, s["toolchanger"]["status"], s["toolchanger"]["tool_number"],
             s["motion_report"]["live_velocity"] or 0.0, s["motion_report"]["live_extruder_velocity"] or 0.0,
             s["toolhead"]["position"][2]]
        for e in EXT:
            r += [s[e]["temperature"], s[e]["target"]]
        rows.append(r)
        f.write(",".join(str(round(v, 3)) if isinstance(v, float) else str(v) for v in r) + "\n")
        f.flush()
        time.sleep(0.25)

# console dump
try:
    g = json.load(urllib.request.urlopen(API + "/server/gcode_store?count=3000", timeout=5))["result"]["gcode_store"]
    with open(os.path.join(D, "toolchange_console.log"), "w") as f:
        for m in g:
            f.write(time.strftime("%H:%M:%S", time.localtime(m["time"])) + " " + m["message"].replace("\n", " | ") + "\n")
except Exception as e:
    pass

# per-toolchange summary
out = []
i = 0
n = len(rows)
while i < n:
    if rows[i][2] == "changing":
        j = i
        while j < n and rows[j][2] == "changing":
            j += 1
        if j >= n:
            break
        t0, t1 = rows[i][0], rows[j][0]
        frm, to = rows[i - 1][3] if i else -1, rows[j][3]
        e = EXT[to] if 0 <= to < 4 else None
        ci = 7 + 2 * to if e else None
        temp_end = rows[j][ci] if e else None
        tgt_end = rows[j][ci + 1] if e else None
        # when did the incoming tool first get within 2C of its (final) target?
        t_hot = None
        if e:
            k = i
            while k < n and k < j + 400:
                if rows[k][ci + 1] > 0 and rows[k][ci] >= rows[k][ci + 1] - 2:
                    t_hot = rows[k][0]; break
                k += 1
        # when does extrusion resume after the change?
        k = j
        while k < n and abs(rows[k][5]) < 0.05:
            k += 1
        t_ext = rows[k][0] if k < n else None
        out.append("%s T%s->T%s  change %.1fs | incoming %s at end: %s/%s C | hot(+-2C) %s | extrusion resumes %.1fs after change ends | heat wait beyond change: %s" % (
            time.strftime("%H:%M:%S", time.localtime(t0)), frm, to, t1 - t0, e,
            None if temp_end is None else round(temp_end, 1), tgt_end,
            "n/a" if t_hot is None else ("%+.1fs vs change end" % (t_hot - t1)),
            (t_ext - t1) if t_ext else -1,
            "n/a" if t_hot is None else ("%.1fs" % max(0.0, t_hot - t1))))
        i = j
    i += 1
with open(SUM, "w") as f:
    f.write("Toolchange vs heat-up, %s\n" % time.strftime("%Y-%m-%d %H:%M"))
    f.write("\n".join(out) + "\n")
