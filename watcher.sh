#!/system/bin/sh
# Low-frequency local watcher for hybrid adaptive profiles and optional game detection.
MODDIR=${0%/*}
export MODDIR HANNIBOMB_MODDIR="$MODDIR"
DATA_DIR=${HANNIBOMB_DATA_DIR:-/data/adb/hannibomb}
. "$MODDIR/common.sh"
echo $$ > "$DATA_DIR/watcher.pid"
log "watcher started (5-second game/profile check; no CPU/GPU frequency polling)"

foreground_package() {
  if [ "${HANNIBOMB_TEST_MODE:-0}" = 1 ]; then
    printf '%s\n' "${TEST_FOREGROUND_PACKAGE:-com.example.home}"
    return
  fi
  raw=$(dumpsys activity activities 2>/dev/null | grep -E 'mResumedActivity|topResumedActivity' | tail -n 1)
  printf '%s\n' "$raw" | sed -n -E 's/.*u[0-9]+[[:space:]]+([A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*)\/.*/\1/p'
}

is_configured_game() {
  pkg=$1 packages=$2
  [ -n "$pkg" ] && [ -n "$packages" ] || return 1
  case ",$packages," in *",$pkg,"*) return 0 ;; *) return 1 ;; esac
}

while :; do
  # Stop if the module is removed or disabled; do not leave a hidden daemon running.
  [ -d "$MODDIR" ] || break
  [ -f "$MODDIR/disable" ] && break
  load_config
  if [ "$ENABLE_GAME_AUTO_PROFILE" = 1 ] && [ -n "$GAME_PACKAGES" ]; then
    fg=$(foreground_package)
    if is_configured_game "$fg" "$GAME_PACKAGES"; then
      if [ -f "$GAME_OVERRIDE" ] && game_override_needs_restore; then
        log "Battery Saver guard activated while game is foreground; ending temporary Performance override."
        restore_game_override
      fi
      if [ ! -f "$GAME_OVERRIDE" ]; then
        load_config
        if [ "$MODE" != hybrid ]; then
          log "game $fg detected while MODE=$MODE; explicit manual profile preserved (auto game override requires Hybrid mode)"
        else
          select_profile
          if [ "$SELECTED_PROFILE" = battery ]; then
            log "game $fg detected, but Battery was selected by power/thermal rules; Performance override skipped"
          elif [ "$SELECTED_PROFILE" = performance ]; then
            log "game $fg detected but Performance is already selected; no temporary override needed"
          else
            printf '%s\n%s\n%s\n' "$MODE" "$PROFILE" "$AI_ADAPTIVE" > "$GAME_OVERRIDE"
            log "configured game detected in foreground: $fg; switching temporarily to manual Performance profile"
            set_config MODE manual
            set_config PROFILE performance
            apply
          fi
        fi
      fi
    elif [ -f "$GAME_OVERRIDE" ]; then
      log "configured game left foreground: ${fg:-unknown}"
      restore_game_override
    fi
  elif [ -f "$GAME_OVERRIDE" ]; then
    restore_game_override
  fi

  # Hybrid mode is refreshed at a low frequency. Apply only when selected state changes.
  load_config
  if [ "$MODE" = hybrid ] && [ ! -f "$GAME_OVERRIDE" ]; then
    select_profile
    desired="$MODE|$PROFILE|$SELECTED_PROFILE"
    active=$(cat "$ACTIVE_STATE" 2>/dev/null)
    if [ "$desired" != "$active" ]; then
      log "adaptive watcher detected state change: $active -> $desired"
      apply
    fi
  fi
  # A one-iteration switch exists only for deterministic source-level simulation tests.
  [ "${HANNIBOMB_TEST_ONCE:-0}" = 1 ] && break
  sleep 5
done
rm -f "$DATA_DIR/watcher.pid"
log "watcher stopped"
exit 0
