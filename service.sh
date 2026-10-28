#!/system/bin/sh
MODDIR=${0%/*}
export MODDIR HANNIBOMB_MODDIR="$MODDIR"
DATA_DIR=${HANNIBOMB_DATA_DIR:-/data/adb/hannibomb}
CONFIG="$DATA_DIR/config.conf"
mkdir -p "$DATA_DIR" 2>/dev/null
[ -f "$CONFIG" ] || cp "$MODDIR/config.conf" "$CONFIG"
# Wait a bounded time for Android boot completion; no boot-stage writes are made here.
n=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$n" -lt 60 ]; do
  sleep 2
  n=$((n + 1))
done
. "$MODDIR/common.sh"
load_config
log "service started; boot_completed=$(getprop sys.boot_completed 2>/dev/null)"
detect >> "$LOG" 2>&1
apply >> "$LOG" 2>&1
network_advanced_report >> "$LOG" 2>&1
# Reapply only explicitly opted-in network features after reboot. Each adapter verifies support.
load_config
[ "$ENABLE_DSCP" = 1 ] && apply_dscp_profile >> "$LOG" 2>&1
if [ "$ENABLE_TC_SHAPING" = 1 ] && [ -n "$TC_INTERFACE" ]; then
  saved_tc_iface=$(sed -n '1p' "$TC_STATE" 2>/dev/null)
  current_qdisc=$(tc qdisc show dev "$TC_INTERFACE" 2>/dev/null | awk '/ root/ {print; exit}' | tr 'A-Z' 'a-z')
  if [ -f "$TC_STATE" ] && [ "$saved_tc_iface" = "$TC_INTERFACE" ]; then
    case "$current_qdisc" in *"qdisc noqueue "*) rm -f "$TC_STATE"; log "prior TBF qdisc absent after boot; stale state cleared before reapplying configured shaping" ;; esac
  fi
  apply_tc_shaping "$TC_INTERFACE" "$TC_RATE" >> "$LOG" 2>&1
fi
# Low-frequency profile/game watcher (hybrid heuristics; optional foreground game list).
oldpid=$(cat "$DATA_DIR/watcher.pid" 2>/dev/null)
case "$oldpid" in *[!0-9]*|'') oldpid= ;; esac
watcher_alive=0
if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
  oldcmd=$(tr '\000' ' ' < "/proc/$oldpid/cmdline" 2>/dev/null)
  case "$oldcmd" in *"$MODDIR/watcher.sh"*) watcher_alive=1 ;; esac
fi
if [ "$watcher_alive" = 1 ]; then
  log "watcher already running pid=$oldpid"
else
  rm -f "$DATA_DIR/watcher.pid"
  sh "$MODDIR/watcher.sh" </dev/null >/dev/null 2>&1 &
  log "watcher launch requested"
fi

# Optional Rust telemetry sidecar. If the target binary is absent, retain the shell watcher
# as the functional fallback and report that Rust has not been built for this target.
load_config
if [ "$ENABLE_RUST_DAEMON" = 1 ] && [ -x "$MODDIR/bin/hannibombd" ]; then
  oldrpid=$(cat "$DATA_DIR/rust_daemon.pid" 2>/dev/null)
  case "$oldrpid" in *[!0-9]*|'') oldrpid= ;; esac
  rust_alive=0
  if [ -n "$oldrpid" ] && kill -0 "$oldrpid" 2>/dev/null; then
    oldcmd=$(tr '\000' ' ' < "/proc/$oldrpid/cmdline" 2>/dev/null)
    case "$oldcmd" in *hannibombd*) rust_alive=1 ;; esac
  fi
  if [ "$rust_alive" = 0 ]; then
    rm -f "$DATA_DIR/stop_rust_daemon"
    HANNIBOMB_MODDIR="$MODDIR" HANNIBOMB_DATA_DIR="$DATA_DIR" "$MODDIR/bin/hannibombd" </dev/null >/dev/null 2>&1 &
    log "Rust telemetry daemon launch requested"
  fi
else
  if [ "$ENABLE_RUST_DAEMON" = 0 ]; then
    printf 'daemon=disabled\nstate=disabled_by_config\n' > "$DATA_DIR/rust_daemon.status"
  else
    printf 'daemon=shell-fallback\nstate=rust_binary_not_built\n' > "$DATA_DIR/rust_daemon.status"
  fi
  log "Rust daemon binary absent; shell watcher remains active (build daemon/hannibombd.rs for Android ARM64 to enable telemetry sidecar)"
fi
