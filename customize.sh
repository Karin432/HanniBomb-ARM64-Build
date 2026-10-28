#!/system/bin/sh
# HanniBomb installable module installer.
SKIPUNZIP=0
ui_print "- HanniBomb — author Hannhanniii"
ui_print "- Installs HanniBomb files; optional controls remain opt-in."
ui_print "- CPU governor, Wi-Fi scan throttling, and TCP network writes default to OFF."
if [ -n "${API:-}" ] && [ "$API" -lt 29 ]; then
  ui_print "! Android 10+ recommended; installation stopped."
  abort "! Unsupported Android version"
fi
