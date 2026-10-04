Boss (SV08) files that live OUTSIDE printer_data/config, copied here so they reach
GitHub with the config backup. Saved 2026-10-03.

klipper-backup-onstart.sh / klipper-backup-restartwatch.sh -> /home/biqu/
klipper-backup-onstart.service / klipper-backup-restartwatch.service -> /etc/systemd/system/
  Backup to GitHub after every Klipper start/RESTART/FIRMWARE_RESTART; waits for prints,
  aborts if a print starts. Restore: copy, chmod +x the .sh, sudo systemctl daemon-reload,
  sudo systemctl enable --now klipper-backup-restartwatch.service
  (do NOT enable klipper-backup-onstart.service; the watcher starts it).
  The old filewatch service + 4-hourly cron were removed on purpose.
klipper.service.d-priority.conf -> /etc/systemd/system/klipper.service.d/priority.conf
  (Nice=-10, realtime IO for Klipper, from 2026-09-16)

heater_power_distributor.pid-calibrate-fix.diff (+ .patched copy, patch_hpd.py)
  Local fix to ~/klipper-toolchanger/klipper/extras/heater_power_distributor.py:
  after PID_CALIBRATE the distributor locked that heater at ~0% power until restart.
  An update of the klipper-toolchanger repo can drop this. Re-apply with:
  cd ~/klipper-toolchanger && git apply <this .diff>   (or python3 patch_hpd.py <file>)
  then sudo systemctl restart klipper (FIRMWARE_RESTART does not reload .py files).
