#!/usr/bin/env bash
#
# Collect the non-interactive part of the #12 device survey from one Portal over adb.
# Writes everything into ./survey-<device>-<date>/ for attaching to the ticket or copying back.
#
# Usage: research/device-survey/collect.sh [adb-serial-or-host:port] [--reboot]
#   --reboot  also reboot the device and time whether com.portal.receiver comes back on its own.
set -euo pipefail

SERIAL="${1:-}"
REBOOT=0
for a in "$@"; do [ "$a" = "--reboot" ] && REBOOT=1; done
[ "$SERIAL" = "--reboot" ] && SERIAL=""

if [[ "$SERIAL" == *:* ]]; then adb connect "$SERIAL" >/dev/null; fi
ADB=(adb); [ -n "$SERIAL" ] && ADB=(adb -s "$SERIAL")
sh_() { "${ADB[@]}" shell "$@" | tr -d '\r'; }

DEV="$(sh_ getprop ro.product.device)"
OUT="survey-${DEV}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT/codecs"
echo "Collecting from $DEV into $OUT/"

{
  for p in ro.product.device ro.product.name ro.product.model ro.build.version.release ro.build.version.sdk \
           ro.board.platform ro.build.fingerprint ro.product.cpu.abilist; do
    echo "$p=$(sh_ getprop "$p")"
  done
} > "$OUT/props.txt"

# Codec configs: every media_codecs*.xml the vendor and system partitions expose.
for dir in /vendor/etc /system/etc /odm/etc; do
  for f in $(sh_ "ls $dir 2>/dev/null | grep -E '^media_codecs.*\.xml$'" || true); do
    "${ADB[@]}" pull -q "$dir/$f" "$OUT/codecs/${dir//\//_}_$f" 2>/dev/null || true
  done
done

sh_ dumpsys display | grep -E "DisplayModeRecord|mBaseDisplayInfo|mOverrideDisplayInfo" > "$OUT/display.txt" || true
sh_ wm size >> "$OUT/display.txt"
sh_ wm density >> "$OUT/display.txt"
sh_ dumpsys audio | grep -E "STREAM_|Muted|- STREAM|Current:" > "$OUT/audio.txt" || true
sh_ pm list packages > "$OUT/packages.txt"
sh_ dumpsys package com.portal.receiver | grep -E "versionName|versionCode|RECEIVE_BOOT|stopped=" > "$OUT/receiver-package.txt" || true
sh_ dumpsys activity services com.portal.receiver > "$OUT/receiver-services.txt" || true
sh_ "ip -4 addr show wlan0" > "$OUT/network.txt" || true

if [ "$REBOOT" = 1 ]; then
  echo "Rebooting..."
  T0=$(date +%s)
  "${ADB[@]}" reboot
  sleep 5
  if [[ "$SERIAL" == *:* ]]; then
    until adb connect "$SERIAL" 2>/dev/null | grep -q connected; do sleep 3; done
  fi
  "${ADB[@]}" wait-for-device
  until [ "$(sh_ getprop sys.boot_completed)" = 1 ]; do sleep 2; done
  T1=$(date +%s)
  PID=""
  for _ in $(seq 1 24); do PID="$(sh_ pidof com.portal.receiver || true)"; [ -n "$PID" ] && break; sleep 5; done
  T2=$(date +%s)
  {
    echo "boot_completed_after_s=$((T1 - T0))"
    echo "receiver_pid=${PID:-none}"
    echo "receiver_seen_after_boot_s=$((T2 - T1))"
    sh_ logcat -d -b events | grep -E "am_proc_start.*com.portal.receiver" || echo "no am_proc_start for com.portal.receiver"
  } > "$OUT/boot-test.txt"
  cat "$OUT/boot-test.txt"
fi

echo "Done: $OUT/"
