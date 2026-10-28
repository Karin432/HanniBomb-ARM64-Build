#!/system/bin/sh
# Restore values changed by HanniBomb only when the observed state still matches our last write.
MODDIR=${0%/*}
export MODDIR HANNIBOMB_MODDIR="$MODDIR"
DATA_DIR=${HANNIBOMB_DATA_DIR:-/data/adb/hannibomb}
CPU_BACKUP="$DATA_DIR/governor_backup.tsv"
WIFI_BACKUP="$DATA_DIR/wifi_scan_throttle_original"
. "$MODDIR/common.sh"
restore_governor_profile
restore_wifi_scan_throttle
# If uninstall happens during a temporary game override, restore only the saved
# mode/profile metadata. Do not call restore_game_override here because its normal
# path runs apply() again, which would reapply controls during uninstall.
if [ -f "$DATA_DIR/game_override" ]; then
  saved_mode=$(sed -n '1p' "$DATA_DIR/game_override" 2>/dev/null)
  saved_profile=$(sed -n '2p' "$DATA_DIR/game_override" 2>/dev/null)
  load_config
  if [ "$MODE" = manual ] && [ "$PROFILE" = performance ]; then
    case "$saved_mode" in hybrid|manual) set_config MODE "$saved_mode" ;; esac
    case "$saved_profile" in balanced|performance|battery) set_config PROFILE "$saved_profile" ;; esac
  fi
  rm -f "$DATA_DIR/game_override"
fi
# Ask the optional Rust telemetry sidecar to stop and signal only its recorded PID.
: > "$DATA_DIR/stop_rust_daemon"
rpid=$(cat "$DATA_DIR/rust_daemon.pid" 2>/dev/null)
case "$rpid" in *[!0-9]*|'') rpid= ;; esac
if [ -n "$rpid" ] && kill -0 "$rpid" 2>/dev/null; then
  rcmd=$(tr '\000' ' ' < "/proc/$rpid/cmdline" 2>/dev/null)
  case "$rcmd" in *hannibombd*) kill "$rpid" 2>/dev/null || : ;; *) echo "Rust daemon PID $rpid did not match HanniBomb; it was not signalled." ;; esac
fi
# Stop the optional low-frequency watcher if it is still running.
wpid=$(cat "$DATA_DIR/watcher.pid" 2>/dev/null)
case "$wpid" in *[!0-9]*|'') wpid= ;; esac
if [ -n "$wpid" ] && kill -0 "$wpid" 2>/dev/null; then
  wcmd=$(tr '\000' ' ' < "/proc/$wpid/cmdline" 2>/dev/null)
  case "$wcmd" in *"$MODDIR/watcher.sh"*) kill "$wpid" 2>/dev/null || : ;; *) echo "Watcher PID $wpid is not HanniBomb; it was not signalled." ;; esac
fi
restore_tc_shaping
restore_dscp_profile
restore_network_profile
restore_private_dns
# Keep logs/backups when an external change prevents a safe restore.
rm -f "$DATA_DIR/watcher.pid" "$DATA_DIR/active_state" "$DATA_DIR/game_override" "$DATA_DIR/rust_daemon.pid" "$DATA_DIR/rust_daemon.status" "$DATA_DIR/stop_rust_daemon"
exit 0
