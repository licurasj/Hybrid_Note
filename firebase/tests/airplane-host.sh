#!/bin/sh
# Follows a flutter test log and switches airplane mode on one device when
# the integration test prints "HOST airplane-mode enable|disable".
# Usage: sh firebase/tests/airplane-host.sh <log> <device-serial>
# (Git Bash on Windows; see the runbook for the full emulator suite).
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
tail -n +1 -F "$1" 2>/dev/null | while read -r line; do
  case "$line" in
    *"HOST airplane-mode enable"*) "$ADB" -s "$2" shell cmd connectivity airplane-mode enable; echo "host: airplane on";;
    *"HOST airplane-mode disable"*) "$ADB" -s "$2" shell cmd connectivity airplane-mode disable; echo "host: airplane off";;
    *"All tests passed"*|*"Some tests failed"*) "$ADB" -s "$2" shell cmd connectivity airplane-mode disable; exit 0;;
  esac
done
