#!/system/bin/sh
# HanniBomb shared functions. Source this file; do not execute it as a command.
MODDIR=${HANNIBOMB_MODDIR:-${MODDIR:-${0%/*}}}
DATA_DIR=${HANNIBOMB_DATA_DIR:-/data/adb/hannibomb}
CONFIG="$DATA_DIR/config.conf"
LOG="$DATA_DIR/service.log"
CPU_BACKUP="$DATA_DIR/governor_backup.tsv"
CPU_APPLIED="$DATA_DIR/governor_applied.tsv"
WIFI_BACKUP="$DATA_DIR/wifi_scan_throttle_original"
NETWORK_BACKUP="$DATA_DIR/network_sysctl_backup.tsv"
NETWORK_APPLIED="$DATA_DIR/network_sysctl_applied.tsv"
DNS_BACKUP="$DATA_DIR/private_dns_backup"
DNS_LAST="$DATA_DIR/private_dns_last"
DNS_PENDING="$DATA_DIR/private_dns_pending"
ACTIVE_STATE="$DATA_DIR/active_state"
GAME_OVERRIDE="$DATA_DIR/game_override"
TC_STATE="$DATA_DIR/tc_state"
DSCP_STATE="$DATA_DIR/dscp_state"
mkdir -p "$DATA_DIR" 2>/dev/null
[ -f "$CONFIG" ] || cp "$MODDIR/config.conf" "$CONFIG" 2>/dev/null

load_config() {
  MODE=hybrid PROFILE=balanced AI_ADAPTIVE=1 AI_LOW_BATTERY=20 AI_THERMAL_STATUS_LIMIT=4
  ENABLE_GOVERNOR_CONTROL=0 ENABLE_NOTIFICATIONS=1 ENABLE_GAME_AUTO_PROFILE=0 ENABLE_RUST_DAEMON=1 GAME_PACKAGES=
  ENABLE_DSCP=0 DSCP_PORT=27015 DSCP_VALUE=46 DSCP_PROTOCOL=udp
  ENABLE_TC_SHAPING=0 TC_INTERFACE= TC_RATE=10
  GOVERNOR_BALANCED=schedutil GOVERNOR_PERFORMANCE=performance GOVERNOR_BATTERY=powersave
  ENABLE_WIFI_SCAN_THROTTLE=0 ENABLE_NETWORK_TWEAKS=0 NETWORK_PRESET=game NETWORK_CUSTOM_CC=auto NETWORK_CUSTOM_BUFFER=4194304 NETWORK_PING_TARGET=1.1.1.1 COLOR_SCALE=1.5 LOG_MAX_LINES=300
  while IFS='=' read -r key value; do
    case "$key" in
      MODE) case "$value" in hybrid|manual) MODE=$value ;; esac ;;
      PROFILE) case "$value" in balanced|performance|battery) PROFILE=$value ;; esac ;;
      AI_ADAPTIVE) case "$value" in 0|1) AI_ADAPTIVE=$value ;; esac ;;
      AI_LOW_BATTERY) case "$value" in *[!0-9]*|'') ;; *) [ "$value" -ge 5 ] 2>/dev/null && [ "$value" -le 50 ] 2>/dev/null && AI_LOW_BATTERY=$value ;; esac ;;
      AI_THERMAL_STATUS_LIMIT) case "$value" in 3|4|5|6) AI_THERMAL_STATUS_LIMIT=$value ;; esac ;;
      ENABLE_GOVERNOR_CONTROL) case "$value" in 0|1) ENABLE_GOVERNOR_CONTROL=$value ;; esac ;;
      ENABLE_NOTIFICATIONS) case "$value" in 0|1) ENABLE_NOTIFICATIONS=$value ;; esac ;;
      ENABLE_GAME_AUTO_PROFILE) case "$value" in 0|1) ENABLE_GAME_AUTO_PROFILE=$value ;; esac ;;
      ENABLE_RUST_DAEMON) case "$value" in 0|1) ENABLE_RUST_DAEMON=$value ;; esac ;;
      GAME_PACKAGES) case "$value" in *[!A-Za-z0-9._,]*|,*|*,|*,,*) ;; *) GAME_PACKAGES=$value ;; esac ;;
      ENABLE_DSCP) case "$value" in 0|1) ENABLE_DSCP=$value ;; esac ;;
      DSCP_PORT) case "$value" in *[!0-9]*|'') ;; *) [ "$value" -ge 1 ] 2>/dev/null && [ "$value" -le 65535 ] 2>/dev/null && DSCP_PORT=$value ;; esac ;;
      DSCP_VALUE) case "$value" in *[!0-9]*|'') ;; *) [ "$value" -ge 0 ] 2>/dev/null && [ "$value" -le 63 ] 2>/dev/null && DSCP_VALUE=$value ;; esac ;;
      DSCP_PROTOCOL) case "$value" in tcp|udp|both) DSCP_PROTOCOL=$value ;; esac ;;
      ENABLE_TC_SHAPING) case "$value" in 0|1) ENABLE_TC_SHAPING=$value ;; esac ;;
      TC_INTERFACE) case "$value" in *[!A-Za-z0-9_.:-]*|'') ;; *) TC_INTERFACE=$value ;; esac ;;
      TC_RATE) case "$value" in *[!0-9]*|'') ;; *) [ "$value" -ge 2 ] 2>/dev/null && [ "$value" -le 100 ] 2>/dev/null && TC_RATE=$value ;; esac ;;
      GOVERNOR_BALANCED) GOVERNOR_BALANCED=$value ;;
      GOVERNOR_PERFORMANCE) GOVERNOR_PERFORMANCE=$value ;;
      GOVERNOR_BATTERY) GOVERNOR_BATTERY=$value ;;
      ENABLE_WIFI_SCAN_THROTTLE) case "$value" in 0|1) ENABLE_WIFI_SCAN_THROTTLE=$value ;; esac ;;
      ENABLE_NETWORK_TWEAKS) case "$value" in 0|1) ENABLE_NETWORK_TWEAKS=$value ;; esac ;;
      NETWORK_PRESET) case "$value" in balanced|game|streaming|download|browsing|outdoor|custom) NETWORK_PRESET=$value ;; esac ;;
      NETWORK_CUSTOM_CC) case "$value" in auto|*[!A-Za-z0-9_.-]*|'') ;; *) NETWORK_CUSTOM_CC=$value ;; esac ;;
      NETWORK_CUSTOM_BUFFER) case "$value" in *[!0-9]*|'') ;; *) [ "$value" -ge 262144 ] 2>/dev/null && [ "$value" -le 16777216 ] 2>/dev/null && NETWORK_CUSTOM_BUFFER=$value ;; esac ;;
      NETWORK_PING_TARGET) case "$value" in *[!A-Za-z0-9._:-]*|'') ;; *) NETWORK_PING_TARGET=$value ;; esac ;;
      COLOR_SCALE) case "$value" in 1.0|1.1|1.2|1.3|1.4|1.5|1.6|1.7|1.8|1.9|2.0) COLOR_SCALE=$value ;; esac ;;
      LOG_MAX_LINES) case "$value" in *[!0-9]*|'') ;; *) LOG_MAX_LINES=$value ;; esac ;;
    esac
  done < "$CONFIG"
}

log() {
  mkdir -p "$DATA_DIR" 2>/dev/null
  printf '[%s] %s\n' "$(date '+%F %T' 2>/dev/null)" "$*" >> "$LOG"
  lines=$(wc -l < "$LOG" 2>/dev/null)
  case "$lines" in ''|*[!0-9]*) lines=0 ;; esac
  max=$LOG_MAX_LINES
  case "$max" in ''|*[!0-9]*) max=300 ;; esac
  [ "$max" -ge 50 ] 2>/dev/null || max=50
  if [ "$lines" -gt "$max" ]; then
    tail -n "$max" "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
}

set_config() {
  cfg_key=$1 cfg_value=$2
  case "$cfg_key" in
    MODE) case "$cfg_value" in hybrid|manual) ;; *) return 1 ;; esac ;;
    PROFILE) case "$cfg_value" in balanced|performance|battery) ;; *) return 1 ;; esac ;;
    AI_ADAPTIVE|ENABLE_GOVERNOR_CONTROL|ENABLE_WIFI_SCAN_THROTTLE|ENABLE_NETWORK_TWEAKS|ENABLE_NOTIFICATIONS|ENABLE_GAME_AUTO_PROFILE|ENABLE_RUST_DAEMON|ENABLE_DSCP|ENABLE_TC_SHAPING) case "$cfg_value" in 0|1) ;; *) return 1 ;; esac ;;
    GAME_PACKAGES) case "$cfg_value" in *[!A-Za-z0-9._,]*|,*|*,|*,,*) return 1 ;; esac ;;
    DSCP_PORT) case "$cfg_value" in *[!0-9]*|'') return 1 ;; esac; [ "$cfg_value" -ge 1 ] 2>/dev/null && [ "$cfg_value" -le 65535 ] 2>/dev/null || return 1 ;;
    DSCP_VALUE) case "$cfg_value" in *[!0-9]*|'') return 1 ;; esac; [ "$cfg_value" -ge 0 ] 2>/dev/null && [ "$cfg_value" -le 63 ] 2>/dev/null || return 1 ;;
    DSCP_PROTOCOL) case "$cfg_value" in tcp|udp|both) ;; *) return 1 ;; esac ;;
    TC_INTERFACE) case "$cfg_value" in ''|*[!A-Za-z0-9_.:-]*) return 1 ;; esac ;;
    TC_RATE) case "$cfg_value" in *[!0-9]*|'') return 1 ;; esac; [ "$cfg_value" -ge 2 ] 2>/dev/null && [ "$cfg_value" -le 100 ] 2>/dev/null || return 1 ;;
    NETWORK_PRESET) case "$cfg_value" in balanced|game|streaming|download|browsing|outdoor|custom) ;; *) return 1 ;; esac ;;
    NETWORK_CUSTOM_CC) case "$cfg_value" in auto) ;; ''|*[!A-Za-z0-9_.-]*) return 1 ;; *) ;; esac ;;
    NETWORK_CUSTOM_BUFFER) case "$cfg_value" in *[!0-9]*|'') return 1 ;; esac; [ "$cfg_value" -ge 262144 ] 2>/dev/null && [ "$cfg_value" -le 16777216 ] 2>/dev/null || return 1 ;;
    NETWORK_PING_TARGET) case "$cfg_value" in *[!A-Za-z0-9._:-]*|'') return 1 ;; esac ;;
    COLOR_SCALE) case "$cfg_value" in 1.0|1.1|1.2|1.3|1.4|1.5|1.6|1.7|1.8|1.9|2.0) ;; *) return 1 ;; esac ;;
    AI_LOW_BATTERY) case "$cfg_value" in *[!0-9]*|'') return 1 ;; esac; [ "$cfg_value" -ge 5 ] 2>/dev/null && [ "$cfg_value" -le 50 ] 2>/dev/null || return 1 ;;
    AI_THERMAL_STATUS_LIMIT) case "$cfg_value" in 3|4|5|6) ;; *) return 1 ;; esac ;;
    GOVERNOR_BALANCED|GOVERNOR_PERFORMANCE|GOVERNOR_BATTERY) case "$cfg_value" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac ;;
    *) echo "Rejected unknown configuration key: $cfg_key"; return 1 ;;
  esac
  cfg_tmp="$CONFIG.tmp"
  awk -F= -v k="$cfg_key" -v v="$cfg_value" '$1 != k {print} END {print k "=" v}' "$CONFIG" > "$cfg_tmp" && mv "$cfg_tmp" "$CONFIG"
  log "config changed: $cfg_key=$cfg_value"
}

toggle_mode() {
  load_config
  if [ "$MODE" = hybrid ]; then set_config MODE manual; else set_config MODE hybrid; fi
}

read_signals() {
  if [ "${HANNIBOMB_TEST_MODE:-0}" = 1 ]; then
    LOW_POWER=${TEST_LOW_POWER:-0}
    BATTERY_LEVEL=${TEST_BATTERY_LEVEL:-80}
    BATTERY_STATUS=${TEST_BATTERY_STATUS:-3}
    THERMAL_STATUS=${TEST_THERMAL_STATUS:-0}
    BATTERY_TEMP=${TEST_BATTERY_TEMP:-350}
  else
    LOW_POWER=$(settings get global low_power 2>/dev/null)
    BATTERY_DUMP=$(dumpsys battery 2>/dev/null)
    BATTERY_LEVEL=$(printf '%s\n' "$BATTERY_DUMP" | awk -F: '/^[[:space:]]*level:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}')
    BATTERY_STATUS=$(printf '%s\n' "$BATTERY_DUMP" | awk -F: '/^[[:space:]]*status:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}')
    BATTERY_TEMP=$(printf '%s\n' "$BATTERY_DUMP" | awk -F: '/^[[:space:]]*temperature:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}')
    THERMAL_DUMP=$(dumpsys thermalservice 2>/dev/null)
    THERMAL_STATUS=$(printf '%s\n' "$THERMAL_DUMP" | sed -n -E 's/.*Thermal Status:[[:space:]]*([0-6]).*/\1/p; s/.*mStatus=[[:space:]]*([0-6]).*/\1/p' | head -n 1)
  fi
  case "$LOW_POWER" in 0|1) ;; *) LOW_POWER=unknown ;; esac
  case "$BATTERY_LEVEL" in ''|*[!0-9]*) BATTERY_LEVEL=unknown ;; esac
  case "$BATTERY_STATUS" in ''|*[!0-9]*) BATTERY_STATUS=unknown ;; esac
  case "$BATTERY_TEMP" in ''|*[!0-9]*) BATTERY_TEMP=unknown ;; esac
  case "$THERMAL_STATUS" in 0|1|2|3|4|5|6) ;; *) THERMAL_STATUS=unknown ;; esac
}

select_profile() {
  load_config
  SELECTED_PROFILE=$PROFILE
  AI_REASON="Manual profile: $PROFILE"
  read_signals
  if [ "$MODE" = manual ]; then
    SELECTED_PROFILE=$PROFILE
    AI_REASON="Manual mode selected; sensors are informational only."
    return 0
  fi
  if [ "$AI_ADAPTIVE" != 1 ]; then
    if [ "$LOW_POWER" = 1 ]; then SELECTED_PROFILE=battery; AI_REASON="Battery Saver is enabled."; else SELECTED_PROFILE=balanced; AI_REASON="Adaptive rules disabled; safe balanced fallback."; fi
    return 0
  fi
  if [ "$LOW_POWER" = 1 ]; then
    SELECTED_PROFILE=battery; AI_REASON="Battery Saver is enabled."
  elif [ "$BATTERY_LEVEL" != unknown ] && [ "$BATTERY_LEVEL" -le "$AI_LOW_BATTERY" ]; then
    SELECTED_PROFILE=battery; AI_REASON="Battery is at or below ${AI_LOW_BATTERY}%."
  elif [ "$THERMAL_STATUS" != unknown ] && [ "$THERMAL_STATUS" -ge "$AI_THERMAL_STATUS_LIMIT" ]; then
    SELECTED_PROFILE=battery; AI_REASON="System thermal status is high ($THERMAL_STATUS); choosing conservative profile."
  else
    SELECTED_PROFILE=balanced
    AI_REASON="Signals do not justify power-saving intervention; performance profile is never auto-selected."
  fi
}

cpu_policy_dirs() {
  cpu_root=/sys/devices/system/cpu
  # Alternate roots exist only for deterministic source tests, never normal module operation.
  if [ "${HANNIBOMB_TEST_MODE:-0}" = 1 ] && [ -n "${HB_CPU_SYSFS_ROOT:-}" ]; then cpu_root=$HB_CPU_SYSFS_ROOT; fi
  found_policy=0
  for d in "$cpu_root"/cpufreq/policy*; do
    [ -d "$d" ] || continue
    printf '%s\n' "$d"
    found_policy=1
  done
  # Older kernels expose only cpuN/cpufreq. Prefer policy* when available so a
  # policy symlink is never applied/restored twice through two different paths.
  if [ "$found_policy" = 0 ]; then
    for d in "$cpu_root"/cpu[0-9]*/cpufreq; do
      [ -d "$d" ] || continue
      printf '%s\n' "$d"
    done
  fi
}

list_cpu_policies() {
  found=0
  for d in $(cpu_policy_dirs); do
    [ -r "$d/scaling_available_governors" ] || continue
    echo "$d governors=$(cat "$d/scaling_available_governors" 2>/dev/null) current=$(cat "$d/scaling_governor" 2>/dev/null)"
    found=1
  done
  [ "$found" = 1 ] || echo "No readable CPU governor policies found."
}

detect() {
  echo "=== HanniBomb capability audit ==="
  echo "Android=$(getprop ro.build.version.release 2>/dev/null) API=$(getprop ro.build.version.sdk 2>/dev/null)"
  echo "Kernel=$(uname -r 2>/dev/null)"
  echo "Model=$(getprop ro.product.model 2>/dev/null)"
  echo "Board=$(getprop ro.board.platform 2>/dev/null)"
  echo "Hardware=$(getprop ro.hardware 2>/dev/null)"
  read_signals
  echo "Power-save=$LOW_POWER battery=${BATTERY_LEVEL}% battery_status=$BATTERY_STATUS battery_temp_raw=$BATTERY_TEMP thermal_status=$THERMAL_STATUS"
  echo "CPU policies:"; list_cpu_policies
  echo "Color saturation command: $(color_support_text)"
  echo "Wi-Fi scan throttle setting: $(settings get global wifi_scan_throttle_enabled 2>/dev/null)"
  echo "Available TCP congestion controls: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo unavailable)"
  echo "Current TCP congestion control: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo unavailable)"
  echo "Private DNS mode: $(settings get global private_dns_mode 2>/dev/null); hostname: $(settings get global private_dns_specifier 2>/dev/null)"
  echo "Audit is read-only; network changes require explicit Action menu selection."
}

color_support_text() {
  command -v cmd >/dev/null 2>&1 || { echo unavailable; return; }
  help=$(cmd color_display help 2>&1)
  printf '%s\n' "$help" | grep -q 'set-saturation' && echo supported || echo unavailable_or_blocked
}

apply_surfaceflinger_color() {
  level=$1
  case "$level" in 1.0|1.1|1.2|1.3|1.4|1.5|1.6|1.7|1.8|1.9|2.0) ;; *) echo "SurfaceFlinger scale must be 1.0–2.0 in steps of 0.1."; return 2 ;; esac
  command -v service >/dev/null 2>&1 || { echo "Android service command unavailable; no color change attempted."; return 1; }
  # AyundaRisuColorEnhancer uses SurfaceFlinger transaction 1022 with a float argument.
  # This is vendor/ROM dependent; a zero shell exit is not proof the pixels visibly changed.
  sf_out=$(service call SurfaceFlinger 1022 f "$level" 2>&1); sf_rc=$?
  printf 'SurfaceFlinger reply: %s\n' "${sf_out:-<empty>}"
  [ "$sf_rc" -eq 0 ] || { echo "SurfaceFlinger rejected the request (exit=$sf_rc)."; return 1; }
  set_config COLOR_SCALE "$level" || { echo "Color request was sent but the selected scale could not be saved."; return 1; }
  log "SurfaceFlinger color-enhancer request sent: scale=$level; reply=${sf_out:-empty}"
  echo "COLOR_SCALE_REQUESTED=$level"
  echo "SurfaceFlinger request dispatched. Visual support is ROM-dependent; if AyundaRisuColorEnhancer or another SurfaceFlinger color module is active, the two controls can overwrite each other."
}

set_color_saturation() {
  level=$1
  case "$level" in ''|*[!0-9]*) echo "Level must be an integer from 0 to 100."; return 1 ;; esac
  [ "$level" -ge 0 ] 2>/dev/null && [ "$level" -le 100 ] 2>/dev/null || { echo "Level must be from 0 to 100."; return 1; }
  command -v cmd >/dev/null 2>&1 || { echo "Android cmd service unavailable; skipped."; return 1; }
  help=$(cmd color_display help 2>&1)
  printf '%s\n' "$help" | grep -q 'set-saturation' || { echo "This ROM does not expose cmd color_display set-saturation; no change made."; return 1; }
  if cmd color_display set-saturation "$level"; then
    log "display saturation command accepted: $level"
    echo "Requested display saturation=$level. Level 100 is the normal/full saturation baseline; 0 is grayscale."
  else
    echo "Color service rejected the change (permission/API/ROM limitation); no success claimed."
    return 1
  fi
}

wifi_throttle_status() {
  value=$(settings get global wifi_scan_throttle_enabled 2>/dev/null)
  case "$value" in 1) echo enabled ;; 0) echo disabled ;; *) echo unknown_or_unexposed ;; esac
}

apply_wifi_scan_throttle() {
  load_config
  [ "$ENABLE_WIFI_SCAN_THROTTLE" = 1 ] || { echo "Wi-Fi scan throttling unchanged (opt-in is off)."; return 0; }
  current=$(settings get global wifi_scan_throttle_enabled 2>/dev/null)
  case "$current" in
    1) echo "Wi-Fi scan throttling already enabled; no write needed."; return 0 ;;
    0)
      if [ ! -e "$WIFI_BACKUP" ]; then
        wifi_tmp="$WIFI_BACKUP.tmp"
        if ! printf '0\n' > "$wifi_tmp" 2>/dev/null || ! mv "$wifi_tmp" "$WIFI_BACKUP" 2>/dev/null; then
          rm -f "$wifi_tmp"
          echo "Unable to persist Wi-Fi recovery state; setting was not changed."
          return 1
        fi
      fi
      if [ ! -f "$WIFI_BACKUP" ] || [ ! -r "$WIFI_BACKUP" ]; then
        echo "Wi-Fi recovery path is not a readable regular file; setting was not changed."
        return 1
      fi
      wifi_original=$(cat "$WIFI_BACKUP" 2>/dev/null)
      case "$wifi_original" in 0|1) ;; *) echo "Wi-Fi recovery value invalid; setting was not changed."; return 1 ;; esac
      if [ "$current" != "$wifi_original" ]; then
        echo "Current Wi-Fi value differs from saved original and HanniBomb's applied value; preserving the external state."
        return 1
      fi
      if settings put global wifi_scan_throttle_enabled 1 >/dev/null 2>&1; then
        after=$(settings get global wifi_scan_throttle_enabled 2>/dev/null)
        if [ "$after" = 1 ]; then
          log "enabled Android Wi-Fi scan throttling; previous=$current"
          echo "Wi-Fi scan throttling enabled. Background apps may scan less often; this may affect discovery/location workflows."
        else
          echo "Wi-Fi scan throttle read-back mismatch (actual=$after); backup retained."
          return 1
        fi
      else
        echo "Setting write rejected; backup retained for recovery."
        return 1
      fi
      ;;
    *) echo "Setting is not exposed as 0/1 on this ROM; skipped without writes."; return 1 ;;
  esac
}

restore_wifi_scan_throttle() {
  if [ ! -f "$WIFI_BACKUP" ]; then
    set_config ENABLE_WIFI_SCAN_THROTTLE 0
    echo "No HanniBomb Wi-Fi change recorded; nothing to restore."
    return 0
  fi
  old=$(cat "$WIFI_BACKUP" 2>/dev/null)
  current=$(settings get global wifi_scan_throttle_enabled 2>/dev/null)
  case "$old" in 0|1) ;; *) echo "Invalid Wi-Fi backup; preserving it for manual review."; set_config ENABLE_WIFI_SCAN_THROTTLE 0; return 1 ;; esac

  # A value already equal to the original is restored (or was reset by Android).
  if [ "$current" = "$old" ]; then
    echo "Wi-Fi scan throttle already equals its original value ($old)."
    rm -f "$WIFI_BACKUP"
    set_config ENABLE_WIFI_SCAN_THROTTLE 0
    return 0
  fi

  # Only undo the exact value HanniBomb wrote. Never overwrite a third-party change.
  if [ "$current" = 1 ] && [ "$old" = 0 ]; then
    settings put global wifi_scan_throttle_enabled "$old" >/dev/null 2>&1 || { echo "Restore rejected; backup preserved."; set_config ENABLE_WIFI_SCAN_THROTTLE 0; return 1; }
    after=$(settings get global wifi_scan_throttle_enabled 2>/dev/null)
    if [ "$after" != "$old" ]; then
      echo "Wi-Fi restore read-back mismatch (wanted=$old actual=$after); backup preserved."
      set_config ENABLE_WIFI_SCAN_THROTTLE 0
      return 1
    fi
    echo "Restored Wi-Fi scan throttle value to $old."
    rm -f "$WIFI_BACKUP"
    set_config ENABLE_WIFI_SCAN_THROTTLE 0
    return 0
  fi
  echo "Current Wi-Fi value ($current) differs from HanniBomb's applied value; preserving current value and backup."
  set_config ENABLE_WIFI_SCAN_THROTTLE 0
  return 1
}

# HanniBomb network engine: capability-based TCP tuning inspired by PingPimp v11.0 concepts.
# Only allowlisted procfs nodes are writable. DNS is never altered by network presets.
network_node_path() {
  sysctl_root=/proc/sys
  if [ "${HANNIBOMB_TEST_MODE:-0}" = 1 ] && [ -n "${HB_SYSCTL_ROOT:-}" ]; then sysctl_root=$HB_SYSCTL_ROOT; fi
  case "$1" in
    net.ipv4.tcp_congestion_control) echo "$sysctl_root/net/ipv4/tcp_congestion_control" ;;
    net.ipv4.tcp_sack) echo "$sysctl_root/net/ipv4/tcp_sack" ;;
    net.ipv4.tcp_timestamps) echo "$sysctl_root/net/ipv4/tcp_timestamps" ;;
    net.ipv4.tcp_window_scaling) echo "$sysctl_root/net/ipv4/tcp_window_scaling" ;;
    net.ipv4.tcp_mtu_probing) echo "$sysctl_root/net/ipv4/tcp_mtu_probing" ;;
    net.ipv4.tcp_fastopen) echo "$sysctl_root/net/ipv4/tcp_fastopen" ;;
    net.ipv4.tcp_rmem) echo "$sysctl_root/net/ipv4/tcp_rmem" ;;
    net.ipv4.tcp_wmem) echo "$sysctl_root/net/ipv4/tcp_wmem" ;;
    net.core.rmem_max) echo "$sysctl_root/net/core/rmem_max" ;;
    net.core.wmem_max) echo "$sysctl_root/net/core/wmem_max" ;;
    net.core.netdev_max_backlog) echo "$sysctl_root/net/core/netdev_max_backlog" ;;
    net.ipv4.tcp_ecn) echo "$sysctl_root/net/ipv4/tcp_ecn" ;;
    net.ipv4.tcp_keepalive_time) echo "$sysctl_root/net/ipv4/tcp_keepalive_time" ;;
    net.ipv4.tcp_keepalive_intvl) echo "$sysctl_root/net/ipv4/tcp_keepalive_intvl" ;;
    net.ipv4.tcp_keepalive_probes) echo "$sysctl_root/net/ipv4/tcp_keepalive_probes" ;;
    net.ipv4.tcp_max_syn_backlog) echo "$sysctl_root/net/ipv4/tcp_max_syn_backlog" ;;
    net.ipv4.tcp_fin_timeout) echo "$sysctl_root/net/ipv4/tcp_fin_timeout" ;;
    net.ipv6.conf.all.use_tempaddr) echo "$sysctl_root/net/ipv6/conf/all/use_tempaddr" ;;
    net.ipv6.conf.default.use_tempaddr) echo "$sysctl_root/net/ipv6/conf/default/use_tempaddr" ;;
    *) return 1 ;;
  esac
}

# Recovery files are state, not authority: reject paths not generated by the TCP allowlist.
network_path_is_allowed() {
  candidate=$1
  for key in \
    net.ipv4.tcp_congestion_control net.ipv4.tcp_sack net.ipv4.tcp_timestamps \
    net.ipv4.tcp_window_scaling net.ipv4.tcp_mtu_probing net.ipv4.tcp_fastopen \
    net.ipv4.tcp_rmem net.ipv4.tcp_wmem net.core.rmem_max net.core.wmem_max \
    net.core.netdev_max_backlog net.ipv4.tcp_ecn net.ipv4.tcp_keepalive_time \
    net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes net.ipv4.tcp_max_syn_backlog \
    net.ipv4.tcp_fin_timeout net.ipv6.conf.all.use_tempaddr net.ipv6.conf.default.use_tempaddr; do
    expected_path=$(network_node_path "$key") || continue
    [ "$candidate" = "$expected_path" ] && return 0
  done
  return 1
}

network_record_original() {
  node=$1 current=$2
  if [ ! -e "$NETWORK_BACKUP" ]; then : > "$NETWORK_BACKUP" 2>/dev/null || return 1; fi
  [ -f "$NETWORK_BACKUP" ] && [ -w "$NETWORK_BACKUP" ] || return 1
  if awk -F '\t' -v p="$node" '$1 == p {found=1} END {exit found ? 0 : 1}' "$NETWORK_BACKUP" 2>/dev/null; then
    # Existing original values are immutable across profile changes.
    return 0
  fi
  printf '%s\t%s\n' "$node" "$current" >> "$NETWORK_BACKUP" 2>/dev/null || return 1
  awk -F '\t' -v p="$node" -v v="$current" '$1 == p && $2 == v {found=1} END {exit found ? 0 : 1}' "$NETWORK_BACKUP" 2>/dev/null
}

network_record_applied() {
  node=$1 value=$2
  tmp="$NETWORK_APPLIED.tmp"
  if [ -f "$NETWORK_APPLIED" ]; then
    awk -F '\t' -v p="$node" '$1 != p {print}' "$NETWORK_APPLIED" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  else
    : > "$tmp" 2>/dev/null || return 1
  fi
  printf '%s\t%s\n' "$node" "$value" >> "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$NETWORK_APPLIED" 2>/dev/null || { rm -f "$tmp"; return 1; }
  awk -F '\t' -v p="$node" -v v="$value" '$1 == p {found=1; actual=$2} END {exit found && actual == v ? 0 : 1}' "$NETWORK_APPLIED" 2>/dev/null
}

network_set_node() {
  key=$1 value=$2
  node=$(network_node_path "$key") || { echo "SKIP $key: unsupported key."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 1; }
  [ -r "$node" ] && [ -w "$node" ] || { echo "SKIP $key: node unavailable or read-only."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 0; }
  current=$(cat "$node" 2>/dev/null)
  [ -n "$current" ] || { echo "SKIP $key: current value unreadable."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 0; }
  if [ -f "$NETWORK_BACKUP" ]; then
    original=$(awk -F '\t' -v p="$node" '$1 == p {v=$2; found=1} END {if (found) print v}' "$NETWORK_BACKUP" 2>/dev/null)
    previously_applied=$(awk -F '\t' -v p="$node" '$1 == p {v=$2} END {print v}' "$NETWORK_APPLIED" 2>/dev/null)
    if [ -n "$original" ] && [ "$current" != "$original" ] && { [ -z "$previously_applied" ] || [ "$current" != "$previously_applied" ]; }; then
      echo "PRESERVE $key: current value differs from original and last HanniBomb value; external change detected."
      NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 ))
      return 0
    fi
  elif [ -e "$NETWORK_BACKUP" ]; then
    echo "SKIP $key: recovery path exists but is not a regular backup file; no write performed."
    NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 ))
    return 0
  fi
  if [ "$current" = "$value" ]; then
    network_record_original "$node" "$current" || { echo "SKIP $key: could not persist original state; no write performed."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 0; }
    network_record_applied "$node" "$value" || { echo "SKIP $key: could not persist applied-state record; no write performed."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 0; }
    NETWORK_NODES_CONFIRMED=$(( ${NETWORK_NODES_CONFIRMED:-0} + 1 ))
    echo "OK $key already=$value"
    return 0
  fi
  # Persist both the original and the intended value before writing the sysctl. If the
  # process is killed immediately after the write, recovery can still recognize it.
  network_record_original "$node" "$current" || { echo "SKIP $key: unable to persist original state; no write performed."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 0; }
  network_record_applied "$node" "$value" || { echo "SKIP $key: unable to persist recovery state; no write performed."; NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 )); return 0; }
  if printf '%s\n' "$value" > "$node" 2>/dev/null; then
    after=$(cat "$node" 2>/dev/null)
    if [ "$after" = "$value" ]; then
      NETWORK_NODES_CONFIRMED=$(( ${NETWORK_NODES_CONFIRMED:-0} + 1 ))
      log "network changed $key=$value"
      echo "OK $key=$value"
    elif [ -n "$after" ] && [ "$after" != "$current" ]; then
      # Some kernels normalize/clamp accepted values; track the observed value for restore.
      if network_record_applied "$node" "$after"; then
        NETWORK_NODES_CONFIRMED=$(( ${NETWORK_NODES_CONFIRMED:-0} + 1 ))
        log "network value normalized by kernel $key requested=$value actual=$after"
        echo "NORMALIZED $key requested=$value actual=$after (actual value recorded for restore)."
      else
        NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 ))
        echo "PRESERVE $key: value changed to '$after' but normalized value could not be recorded; recovery backup retained."
      fi
    else
      NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 ))
      echo "SKIP $key: kernel rejected the value; unchanged."
    fi
  else
    NETWORK_NODES_SKIPPED=$(( ${NETWORK_NODES_SKIPPED:-0} + 1 ))
    echo "SKIP $key: write rejected; unchanged."
  fi
}

choose_tcp_congestion() {
  sysctl_root=/proc/sys
  if [ "${HANNIBOMB_TEST_MODE:-0}" = 1 ] && [ -n "${HB_SYSCTL_ROOT:-}" ]; then sysctl_root=$HB_SYSCTL_ROOT; fi
  available=$(cat "$sysctl_root/net/ipv4/tcp_available_congestion_control" 2>/dev/null)
  case " $available " in
    *" bbr "*) echo bbr ;;
    *" cubic "*) echo cubic ;;
    *) echo "" ;;
  esac
}

restore_network_profile() {
  restored=0 skipped=0
  if [ -f "$NETWORK_BACKUP" ]; then
    while IFS="$(printf '\t')" read -r node old; do
      [ -n "$node" ] || continue
      if ! network_path_is_allowed "$node"; then
        echo "PRESERVED $node: recovery path is outside the TCP allowlist."
        skipped=$((skipped + 1))
        continue
      fi
      expected=$(awk -F '\t' -v p="$node" '$1 == p {v=$2} END {print v}' "$NETWORK_APPLIED" 2>/dev/null)
      current=$(cat "$node" 2>/dev/null)
      if [ "$current" = "$old" ]; then
        echo "ALREADY_RESTORED $node=$old"
        restored=$((restored + 1))
      elif [ -n "$expected" ] && [ "$current" = "$expected" ] && [ -w "$node" ]; then
        if printf '%s\n' "$old" > "$node" 2>/dev/null; then
          after=$(cat "$node" 2>/dev/null)
          if [ "$after" = "$old" ]; then
            echo "RESTORED $node=$old"; restored=$((restored + 1))
          else
            echo "PRESERVED $node: restore read-back mismatch (wanted=$old actual=$after)."; skipped=$((skipped + 1))
          fi
        else
          echo "PRESERVED $node: kernel rejected restore."; skipped=$((skipped + 1))
        fi
      else
        echo "PRESERVED $node: unavailable or changed outside HanniBomb."; skipped=$((skipped + 1))
      fi
    done < "$NETWORK_BACKUP"
  else
    echo "No HanniBomb TCP backup exists."
  fi
  if [ "$skipped" -eq 0 ]; then
    rm -f "$NETWORK_BACKUP" "$NETWORK_APPLIED"
  else
    echo "Recovery backup retained at $NETWORK_BACKUP because one or more nodes were preserved."
  fi
  set_config ENABLE_NETWORK_TWEAKS 0
  echo "Network restore finished; restored=$restored preserved=$skipped. DNS was not touched."
  [ "$skipped" -eq 0 ]
}

apply_network_profile() {
  load_config
  [ "$ENABLE_NETWORK_TWEAKS" = 1 ] || { echo "TCP network tuning is OFF (default); no network write performed."; return 0; }
  case "$NETWORK_PRESET" in
    balanced)
      echo "Balanced preset means restore kernel TCP values to recorded originals."
      restore_network_profile
      return $?
      ;;
    game|streaming|download|browsing|outdoor|custom) ;;
    *) echo "Unknown network preset; skipped."; return 1 ;;
  esac
  echo "Applying HanniBomb network preset: $NETWORK_PRESET (supported kernel nodes only)."
  NETWORK_NODES_CONFIRMED=0
  NETWORK_NODES_SKIPPED=0
  cc=$(choose_tcp_congestion)
  if [ "$NETWORK_PRESET" = custom ] && [ "$NETWORK_CUSTOM_CC" != auto ]; then
    sysctl_root=/proc/sys
    if [ "${HANNIBOMB_TEST_MODE:-0}" = 1 ] && [ -n "${HB_SYSCTL_ROOT:-}" ]; then sysctl_root=$HB_SYSCTL_ROOT; fi
    available=$(cat "$sysctl_root/net/ipv4/tcp_available_congestion_control" 2>/dev/null)
    case " $available " in *" $NETWORK_CUSTOM_CC "*) cc=$NETWORK_CUSTOM_CC ;; *) echo "Requested TCP algorithm '$NETWORK_CUSTOM_CC' is not listed by this kernel; no algorithm change."; cc= ;; esac
  fi
  [ -n "$cc" ] && network_set_node net.ipv4.tcp_congestion_control "$cc"
  case "$NETWORK_PRESET" in
    game)
      network_set_node net.ipv4.tcp_sack 1
      network_set_node net.ipv4.tcp_window_scaling 1
      network_set_node net.ipv4.tcp_mtu_probing 1
      network_set_node net.ipv4.tcp_fastopen 3
      ;;
    streaming)
      network_set_node net.ipv4.tcp_sack 1
      network_set_node net.ipv4.tcp_window_scaling 1
      network_set_node net.ipv4.tcp_mtu_probing 1
      network_set_node net.core.rmem_max 4194304
      network_set_node net.core.wmem_max 4194304
      network_set_node net.ipv4.tcp_rmem '4096 131072 4194304'
      network_set_node net.ipv4.tcp_wmem '4096 131072 4194304'
      ;;
    download)
      network_set_node net.ipv4.tcp_sack 1
      network_set_node net.ipv4.tcp_window_scaling 1
      network_set_node net.core.rmem_max 4194304
      network_set_node net.core.wmem_max 4194304
      network_set_node net.ipv4.tcp_rmem '4096 262144 4194304'
      network_set_node net.ipv4.tcp_wmem '4096 262144 4194304'
      ;;
    browsing)
      network_set_node net.ipv4.tcp_sack 1
      network_set_node net.ipv4.tcp_window_scaling 1
      network_set_node net.ipv4.tcp_mtu_probing 1
      network_set_node net.ipv4.tcp_fastopen 3
      ;;
    outdoor)
      network_set_node net.ipv4.tcp_sack 1
      network_set_node net.ipv4.tcp_window_scaling 1
      network_set_node net.ipv4.tcp_mtu_probing 1
      network_set_node net.core.netdev_max_backlog 1000
      ;;
    custom)
      network_set_node net.ipv4.tcp_sack 1
      network_set_node net.ipv4.tcp_window_scaling 1
      network_set_node net.ipv4.tcp_mtu_probing 1
      network_set_node net.core.rmem_max "$NETWORK_CUSTOM_BUFFER"
      network_set_node net.core.wmem_max "$NETWORK_CUSTOM_BUFFER"
      network_set_node net.ipv4.tcp_rmem "4096 262144 $NETWORK_CUSTOM_BUFFER"
      network_set_node net.ipv4.tcp_wmem "4096 262144 $NETWORK_CUSTOM_BUFFER"
      ;;
  esac
  echo "Network preset result: confirmed=$NETWORK_NODES_CONFIRMED skipped=$NETWORK_NODES_SKIPPED."
  echo "DNS, firewall, APN and radio state were not changed. IPv6 controls are diagnostics/opt-in only."
  if [ "$NETWORK_NODES_CONFIRMED" -eq 0 ]; then
    echo "No TCP sysctl write/value could be confirmed on this kernel; check the capability report."
    return 1
  fi
  [ "$NETWORK_NODES_SKIPPED" -eq 0 ] || echo "Partial result: unsupported/externally changed nodes were skipped; review each SKIP/PRESERVE line above."
  return 0
}

private_dns_status() {
  echo "Private DNS mode=$(settings get global private_dns_mode 2>/dev/null) hostname=$(settings get global private_dns_specifier 2>/dev/null)"
}

dns_save_pair() {
  dns_pair_out=$1 dns_pair_mode=$2 dns_pair_host=$3
  # State files are transactional records: reject directories/special files and verify
  # the final file before any associated Android setting is changed.
  if [ -e "$dns_pair_out" ] && [ ! -f "$dns_pair_out" ]; then return 1; fi
  dns_pair_tmp="$dns_pair_out.tmp"
  printf '%s\n%s\n' "$dns_pair_mode" "$dns_pair_host" > "$dns_pair_tmp" 2>/dev/null || { rm -f "$dns_pair_tmp"; return 1; }
  mv "$dns_pair_tmp" "$dns_pair_out" 2>/dev/null || { rm -f "$dns_pair_tmp"; return 1; }
  [ "$(sed -n '1p' "$dns_pair_out" 2>/dev/null)" = "$dns_pair_mode" ] && [ "$(sed -n '2p' "$dns_pair_out" 2>/dev/null)" = "$dns_pair_host" ]
}

dns_set_host_value() {
  value=$1
  case "$value" in null|'') settings delete global private_dns_specifier >/dev/null 2>&1 ;; *) settings put global private_dns_specifier "$value" >/dev/null 2>&1 ;; esac
}

apply_private_dns() {
  mode=$1 host=${2:-}
  case "$mode" in off|opportunistic) ;;
    hostname)
      [ -n "$host" ] || { echo "Custom Private DNS hostname cannot be empty."; return 1; }
      [ "${#host}" -le 253 ] || { echo "Private DNS hostname exceeds 253 characters."; return 1; }
      # Validate DNS label syntax without imposing any provider whitelist.
      printf '%s' "$host" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$' || {
        echo "Invalid Private DNS hostname; use DNS labels without empty labels or leading/trailing hyphens."; return 1;
      }
      ;;
    *) echo "DNS mode not supported by this menu."; return 1 ;;
  esac
  current_mode=$(settings get global private_dns_mode 2>/dev/null)
  current_host=$(settings get global private_dns_specifier 2>/dev/null)
  [ -n "$current_mode" ] && [ -n "$current_host" ] || { echo "Android did not expose the current Private DNS state; no write performed."; return 1; }
  # An interrupted transaction must be restored before another request can replace its journal.
  [ ! -e "$DNS_PENDING" ] || { echo "A pending Private DNS transition exists; restore it before applying another request."; return 1; }
  if [ -e "$DNS_BACKUP" ]; then
    [ -f "$DNS_BACKUP" ] && [ -r "$DNS_BACKUP" ] || { echo "Private DNS backup path is invalid; no write performed."; return 1; }
    existing_original_mode=$(sed -n '1p' "$DNS_BACKUP" 2>/dev/null)
    existing_original_host=$(sed -n '2p' "$DNS_BACKUP" 2>/dev/null)
    [ -n "$existing_original_mode" ] && [ -n "$existing_original_host" ] || { echo "Private DNS backup is incomplete; no write performed."; return 1; }
    if [ "$current_mode" != "$existing_original_mode" ] || [ "$current_host" != "$existing_original_host" ]; then
      last_mode= last_host=
      if [ -f "$DNS_LAST" ] && [ -r "$DNS_LAST" ]; then
        last_mode=$(sed -n '1p' "$DNS_LAST" 2>/dev/null)
        last_host=$(sed -n '2p' "$DNS_LAST" 2>/dev/null)
      fi
      [ -n "$last_mode" ] && [ -n "$last_host" ] && [ "$current_mode" = "$last_mode" ] && [ "$current_host" = "$last_host" ] || {
        echo "Current Private DNS differs from the original and last HanniBomb state; preserving external settings."; return 1;
      }
    fi
  fi
  if [ ! -e "$DNS_BACKUP" ]; then
    dns_save_pair "$DNS_BACKUP" "$current_mode" "$current_host" || { echo "Unable to save Private DNS backup; no Android setting changed."; return 1; }
  fi
  [ -f "$DNS_BACKUP" ] && [ -r "$DNS_BACKUP" ] || { echo "Private DNS backup path is not a readable regular file; no write performed."; return 1; }
  backup_mode=$(sed -n '1p' "$DNS_BACKUP" 2>/dev/null)
  backup_host=$(sed -n '2p' "$DNS_BACKUP" 2>/dev/null)
  [ -n "$backup_mode" ] && [ -n "$backup_host" ] || { echo "Private DNS backup is incomplete; no write performed."; return 1; }
  target_host=$current_host
  [ "$mode" != hostname ] || target_host=$host
  # Pending state is written before mutation. If the service is interrupted between
  # setting the hostname and the mode, restore can recognize the partial transition.
  dns_save_pair "$DNS_PENDING" "$mode" "$target_host" || { echo "Unable to persist pending Private DNS state; no Android setting changed."; return 1; }

  if [ "$mode" = hostname ]; then
    if ! settings put global private_dns_specifier "$host" >/dev/null 2>&1; then
      result_mode=$(settings get global private_dns_mode 2>/dev/null)
      result_host=$(settings get global private_dns_specifier 2>/dev/null)
      if [ "$result_mode" != "$current_mode" ] || [ "$result_host" != "$current_host" ]; then
        if dns_save_pair "$DNS_LAST" "$result_mode" "$result_host"; then
          rm -f "$DNS_PENDING"
          echo "Android reported a hostname write failure after a partial change; recovery state was recorded."
        else
          echo "Android partially changed DNS and the result record could not be saved; pending and original backups retained."
        fi
      else
        rm -f "$DNS_PENDING"
        echo "Android rejected the Private DNS hostname; no setting change was detected."
      fi
      return 1
    fi
  fi
  if ! settings put global private_dns_mode "$mode" >/dev/null 2>&1; then
    result_mode=$(settings get global private_dns_mode 2>/dev/null)
    result_host=$(settings get global private_dns_specifier 2>/dev/null)
    if dns_save_pair "$DNS_LAST" "$result_mode" "$result_host"; then
      rm -f "$DNS_PENDING"
      echo "Android rejected the Private DNS mode; any partial change was recorded for possible restore."
    else
      echo "Android rejected the Private DNS mode and the resulting state could not be saved; pending and original backups retained."
    fi
    return 1
  fi
  result_mode=$(settings get global private_dns_mode 2>/dev/null)
  result_host=$(settings get global private_dns_specifier 2>/dev/null)
  if [ "$result_mode" != "$mode" ] || { [ "$mode" = hostname ] && [ "$result_host" != "$host" ]; }; then
    if dns_save_pair "$DNS_LAST" "$result_mode" "$result_host"; then rm -f "$DNS_PENDING"; fi
    echo "Private DNS read-back does not match the request (mode=$result_mode hostname=$result_host). Check Android Settings; backup was retained for recovery."
    return 1
  fi
  if ! dns_save_pair "$DNS_LAST" "$result_mode" "$result_host"; then
    echo "Private DNS changed but its final recovery record could not be verified; pending and original backups retained."
    return 1
  fi
  rm -f "$DNS_PENDING"
  log "Private DNS mode changed explicitly to $result_mode"
  echo "Private DNS request accepted: mode=$result_mode hostname=$result_host"
  echo "No DNS provider list or whitelist is imposed. Android/device/network support still determines connectivity."
}

restore_private_dns() {
  if [ ! -e "$DNS_BACKUP" ]; then
    [ ! -e "$DNS_PENDING" ] || { echo "Private DNS has a pending record but no original backup; preserving for manual review."; return 1; }
    echo "No HanniBomb Private DNS backup exists."; return 0
  fi
  [ -f "$DNS_BACKUP" ] && [ -r "$DNS_BACKUP" ] || { echo "Private DNS backup path is invalid; preserving current DNS."; return 1; }
  old_mode=$(sed -n '1p' "$DNS_BACKUP")
  old_host=$(sed -n '2p' "$DNS_BACKUP")
  [ -n "$old_mode" ] && [ -n "$old_host" ] || { echo "Private DNS backup is incomplete; preserving current DNS."; return 1; }
  current_mode=$(settings get global private_dns_mode 2>/dev/null)
  current_host=$(settings get global private_dns_specifier 2>/dev/null)
  expected_mode= expected_host= pending_mode= pending_host=
  if [ -f "$DNS_LAST" ]; then
    expected_mode=$(sed -n '1p' "$DNS_LAST" 2>/dev/null)
    expected_host=$(sed -n '2p' "$DNS_LAST" 2>/dev/null)
  fi
  if [ -f "$DNS_PENDING" ]; then
    pending_mode=$(sed -n '1p' "$DNS_PENDING" 2>/dev/null)
    pending_host=$(sed -n '2p' "$DNS_PENDING" 2>/dev/null)
  fi

  if [ "$current_mode" = "$old_mode" ] && [ "$current_host" = "$old_host" ]; then
    echo "Private DNS already equals its original state; clearing stale recovery records."
    rm -f "$DNS_BACKUP" "$DNS_LAST" "$DNS_PENDING"
    return 0
  fi

  owned=0
  if [ -f "$DNS_LAST" ] && [ "$current_mode" = "$expected_mode" ] && [ "$current_host" = "$expected_host" ]; then
    owned=1
  elif [ -f "$DNS_PENDING" ] && [ -n "$pending_mode" ] && [ -n "$pending_host" ]; then
    # Hostname is written before mode. If interrupted mid-transition, each current
    # field must equal an original, target, or previously recorded HanniBomb value.
    mode_known=0 host_known=0
    if [ "$current_mode" = "$old_mode" ] || [ "$current_mode" = "$pending_mode" ] || { [ -n "$expected_mode" ] && [ "$current_mode" = "$expected_mode" ]; }; then mode_known=1; fi
    if [ "$current_host" = "$old_host" ] || [ "$current_host" = "$pending_host" ] || { [ -n "$expected_host" ] && [ "$current_host" = "$expected_host" ]; }; then host_known=1; fi
    [ "$mode_known" = 1 ] && [ "$host_known" = 1 ] && owned=1
  fi
  [ "$owned" = 1 ] || { echo "Private DNS changed outside HanniBomb or current state is unknown; original backup retained and current DNS preserved."; return 1; }

  if ! dns_set_host_value "$old_host"; then echo "Android rejected the Private DNS hostname restore; backup retained."; return 1; fi
  if [ -n "$old_mode" ] && [ "$old_mode" != null ]; then
    settings put global private_dns_mode "$old_mode" >/dev/null 2>&1 || { echo "Android rejected the DNS mode restore; backup retained."; return 1; }
  else
    settings delete global private_dns_mode >/dev/null 2>&1 || { echo "Android rejected the DNS mode reset; backup retained."; return 1; }
  fi
  check_mode=$(settings get global private_dns_mode 2>/dev/null)
  check_host=$(settings get global private_dns_specifier 2>/dev/null)
  if [ "$check_mode" = "$old_mode" ] && [ "$check_host" = "$old_host" ]; then
    echo "Private DNS restored to previous Android settings."
    rm -f "$DNS_BACKUP" "$DNS_LAST" "$DNS_PENDING"
  else
    echo "Private DNS restore could not be verified; backup retained."
    return 1
  fi
}

network_report() {
  echo "=== HanniBomb network diagnostics ==="
  echo "TCP tuning enabled=$ENABLE_NETWORK_TWEAKS preset=$NETWORK_PRESET"
  echo "Wi-Fi scan throttle: $(wifi_throttle_status)"
  echo "Private DNS: $(settings get global private_dns_mode 2>/dev/null) / $(settings get global private_dns_specifier 2>/dev/null) (network presets do not modify DNS)"
  echo "Available TCP congestion controls: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo unavailable)"
  echo "Current TCP congestion control: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo unavailable)"
  echo "Active routes:"
  if command -v ip >/dev/null 2>&1; then ip route 2>/dev/null | head -n 12; else echo "ip utility unavailable."; fi
  echo "Interfaces (short counters):"
  if command -v ip >/dev/null 2>&1; then ip -s link 2>/dev/null | head -n 32; else echo "ip utility unavailable."; fi
  echo "No DNS, IPv6, firewall, APN or radio-state change is automatic."
}

network_advanced_report() {
  echo "=== HanniBomb advanced network capability report ==="
  echo "IPv4 routes:"; ip -4 route show 2>/dev/null || echo unavailable
  echo "IPv6 routes:"; ip -6 route show 2>/dev/null || echo unavailable
  echo "IPv6 addresses:"; ip -6 addr show 2>/dev/null | head -n 40 || echo unavailable
  echo "TCP algorithms: $(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo unavailable)"
  echo "Default qdisc: $(cat /proc/sys/net/core/default_qdisc 2>/dev/null || echo unavailable)"
  echo "Conntrack usage: $(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo unavailable) / $(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo unavailable)"
  echo "tc binary: $(command -v tc 2>/dev/null || echo unavailable)"
  if command -v tc >/dev/null 2>&1; then echo "Current qdisc (read-only):"; tc qdisc show 2>/dev/null | head -n 40; fi
  echo "Socket summary:"
  if command -v ss >/dev/null 2>&1; then ss -s 2>/dev/null; elif command -v netstat >/dev/null 2>&1; then netstat -an 2>/dev/null | head -n 25; else echo "ss/netstat unavailable"; fi
  echo "DNS mode/hostname: $(settings get global private_dns_mode 2>/dev/null) / $(settings get global private_dns_specifier 2>/dev/null)"
  echo "Diagnostics above are read-only. Optional tc shaping and DSCP marking are separate manual opt-ins; neither is enabled by default."
}

network_ping_test() {
  target=${1:-1.1.1.1}
  # Reject option-like input as well as shell metacharacters; target is passed to a privileged ping.
  case "$target" in ''|-*|*[!A-Za-z0-9._:-]*) echo "Invalid host/IP or option-like target."; return 1 ;; esac
  command -v ping >/dev/null 2>&1 || { echo "ping utility unavailable."; return 1; }
  echo "Ping test to $target (4 packets; diagnostic only):"
  ping -c 4 -W 2 "$target" 2>&1
  rc=$?
  echo "ping exit status=$rc (not a guaranteed measure of app/game latency; ICMP may be filtered)."
  return "$rc"
}

# Optional qdisc shaping: only replaces a noqueue root qdisc, because restoring a vendor qdisc
# with unknown parameters would be unsafe. Rate is deliberately bounded to 2–100 Mbit/s.
tc_status() {
  command -v tc >/dev/null 2>&1 || { echo "tc unavailable"; return 1; }
  iface=${1:-}
  if [ -z "$iface" ]; then iface=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'); fi
  case "$iface" in ''|*[!A-Za-z0-9_.:-]*) echo "No valid default interface detected"; return 1 ;; esac
  echo "interface=$iface"
  tc qdisc show dev "$iface" 2>/dev/null | head -n 8
}

apply_tc_shaping() {
  iface=$1 rate=$2
  case "$iface" in ''|*[!A-Za-z0-9_.:-]*) echo "Invalid network interface."; return 1 ;; esac
  case "$rate" in *[!0-9]*|'') echo "Rate must be integer Mbit/s from 2 to 100."; return 1 ;; esac
  [ "$rate" -ge 2 ] 2>/dev/null && [ "$rate" -le 100 ] 2>/dev/null || { echo "Rate must be 2–100 Mbit/s."; return 1; }
  command -v tc >/dev/null 2>&1 || { echo "tc is unavailable; no qdisc change made."; return 1; }
  line=$(tc qdisc show dev "$iface" 2>/dev/null | awk '/ root/ {print; exit}')
  [ -n "$line" ] || { echo "Root qdisc could not be read; no change made."; return 1; }
  if [ -f "$TC_STATE" ]; then
    saved_iface=$(sed -n '1p' "$TC_STATE" 2>/dev/null)
    saved_rate=$(sed -n '2p' "$TC_STATE" 2>/dev/null)
    lowered=$(printf '%s' "$line" | tr 'A-Z' 'a-z')
    if [ "$saved_iface" = "$iface" ] && [ "$saved_rate" = "$rate" ] && printf '%s\n' "$lowered" | grep -q "qdisc tbf 8001: root" && printf '%s\n' "$lowered" | grep -q "rate ${rate}mbit"; then
      echo "Traffic shaping already active and tracked at ${rate} Mbit/s on $iface."; return 0
    fi
    echo "A traffic-shaping recovery record already exists ($saved_iface / ${saved_rate} Mbit/s). Restore or inspect it before applying another qdisc."; return 1
  fi
  case "$line" in
    *"qdisc tbf 8001: root"*)
      echo "A TBF qdisc with HanniBomb's handle exists but no recovery record is present; refusing to assume ownership."; return 1 ;;
  esac
  kind=$(printf '%s\n' "$line" | awk '{print $2}')
  [ "$kind" = noqueue ] || { echo "Safety stop: root qdisc is '$kind', not noqueue. Existing/vendor qdisc will not be replaced."; return 1; }
  # Persist intent before the qdisc mutation. If persistence fails, do not touch networking.
  if [ -e "$TC_STATE" ] && [ ! -f "$TC_STATE" ]; then
    echo "tc recovery path is not a regular file; qdisc was not changed."; return 1
  fi
  tc_tmp="$TC_STATE.tmp"
  if ! printf '%s\n%s\n' "$iface" "$rate" > "$tc_tmp" 2>/dev/null || ! mv "$tc_tmp" "$TC_STATE" 2>/dev/null; then
    rm -f "$tc_tmp"
    echo "Unable to persist tc recovery record; qdisc was not changed."; return 1
  fi
  [ "$(sed -n '1p' "$TC_STATE" 2>/dev/null)" = "$iface" ] && [ "$(sed -n '2p' "$TC_STATE" 2>/dev/null)" = "$rate" ] || {
    echo "tc recovery record failed verification; qdisc was not changed."; return 1;
  }
  if tc qdisc replace dev "$iface" root handle 8001: tbf rate "${rate}mbit" burst 32kbit latency 50ms 2>/dev/null; then
    after=$(tc qdisc show dev "$iface" 2>/dev/null | awk '/ root/ {print; exit}')
    lowered_after=$(printf '%s' "$after" | tr 'A-Z' 'a-z')
    if printf '%s\n' "$lowered_after" | grep -q 'qdisc tbf 8001: root' && printf '%s\n' "$lowered_after" | grep -q "rate ${rate}mbit"; then
      echo "TC_SHAPING=applied interface=$iface rate=${rate}Mbit"
      log "tc TBF shaping applied on $iface at $rate Mbit/s; original root qdisc was noqueue"; return 0
    fi
    echo "tc command returned success but read-back did not verify the requested TBF; recovery record retained for inspection."
    return 1
  fi
  # Some tc wrappers may mutate state and still return an error. Keep the record unless
  # read-back confirms the original noqueue root remained untouched.
  after=$(tc qdisc show dev "$iface" 2>/dev/null | awk '/ root/ {print; exit}' | tr 'A-Z' 'a-z')
  case "$after" in *"qdisc noqueue "*) rm -f "$TC_STATE"; echo "tc rejected the qdisc and no mutation is visible; stale recovery record removed." ;;
    *) echo "tc returned failure and current qdisc differs from noqueue; recovery record retained for inspection." ;; esac
  return 1
}

restore_tc_shaping() {
  [ -f "$TC_STATE" ] || { set_config ENABLE_TC_SHAPING 0; echo "No HanniBomb tc shaping state recorded."; return 0; }
  command -v tc >/dev/null 2>&1 || { echo "tc is unavailable; recovery record retained."; return 1; }
  iface=$(sed -n '1p' "$TC_STATE" 2>/dev/null)
  rate=$(sed -n '2p' "$TC_STATE" 2>/dev/null)
  case "$iface" in ''|*[!A-Za-z0-9_.:-]*) echo "Saved interface invalid; preserving state."; return 1 ;; esac
  case "$rate" in *[!0-9]*|'') echo "Saved tc rate invalid; preserving state."; return 1 ;; esac
  [ "$rate" -ge 2 ] 2>/dev/null && [ "$rate" -le 100 ] 2>/dev/null || { echo "Saved tc rate is outside the HanniBomb range; preserving qdisc and recovery state."; return 1; }
  line=$(tc qdisc show dev "$iface" 2>/dev/null | awk '/ root/ {print; exit}')
  lowered_line=$(printf '%s' "$line" | tr 'A-Z' 'a-z')
  case "$lowered_line" in
    *"qdisc tbf 8001: root"*)
      printf '%s\n' "$lowered_line" | grep -q "rate ${rate}mbit" || { echo "Current TBF rate differs from HanniBomb's record; preserving qdisc and recovery state."; set_config ENABLE_TC_SHAPING 0; return 1; }
      if tc qdisc del dev "$iface" root >/dev/null 2>&1; then
        after=$(tc qdisc show dev "$iface" 2>/dev/null | awk '/ root/ {print; exit}')
        after_lower=$(printf '%s' "$after" | tr 'A-Z' 'a-z')
        case "$after_lower" in *"qdisc noqueue "*)
          rm -f "$TC_STATE"; set_config ENABLE_TC_SHAPING 0
          echo "TC_SHAPING=restored interface=$iface original_qdisc=noqueue"
          log "tc shaping removed from $iface; default noqueue root verified"; return 0 ;;
        esac
        echo "Qdisc deleted but the default root did not read back as noqueue; recovery record retained."
        set_config ENABLE_TC_SHAPING 0
        return 1
      fi
      echo "tc rejected qdisc restore; backup preserved."; set_config ENABLE_TC_SHAPING 0; return 1 ;;
    *"qdisc noqueue "*)
      # After reboot the kernel may already have returned to its original qdisc.
      rm -f "$TC_STATE"; set_config ENABLE_TC_SHAPING 0
      echo "TC_SHAPING=already_restored interface=$iface original_qdisc=noqueue"
      return 0 ;;
    *)
      echo "Current qdisc differs from HanniBomb's TBF; preserving it and keeping recovery record."; set_config ENABLE_TC_SHAPING 0; return 1 ;;
  esac
}

# DSCP rules live in a uniquely named mangle chain and only mark the user-selected port.
# They are opt-in, capability checked, and removed without flushing other firewall chains.
clear_dscp_rules() {
  [ -f "$DSCP_STATE" ] || return 0
  load_config
  failed=0
  tab=$(printf '\t')
  while IFS="$tab" read -r family saved_port saved_value saved_protocol; do
    case "$family" in
      iptables|ip6tables) ;;
      '') failed=1; continue ;;
      *) failed=1; continue ;;
    esac
    if ! command -v "$family" >/dev/null 2>&1; then failed=1; continue; fi

    # v1.4.0 state files only stored the family. Fall back to config for legacy rows.
    case "$saved_port" in ''|*[!0-9]*) saved_port=$DSCP_PORT ;; esac
    case "$saved_value" in ''|*[!0-9]*) saved_value=$DSCP_VALUE ;; esac
    case "$saved_protocol" in tcp|udp|both) ;; *) saved_protocol=$DSCP_PROTOCOL ;; esac
    case "$saved_port" in ''|*[!0-9]*) failed=1; continue ;; esac
    case "$saved_value" in ''|*[!0-9]*) failed=1; continue ;; esac
    [ "$saved_port" -ge 1 ] 2>/dev/null && [ "$saved_port" -le 65535 ] 2>/dev/null || { failed=1; continue; }
    [ "$saved_value" -ge 0 ] 2>/dev/null && [ "$saved_value" -le 63 ] 2>/dev/null || { failed=1; continue; }

    chain_rc=0
    chain_dump=$("$family" -t mangle -S HANNIBOMB_QOS 2>/dev/null) || chain_rc=$?
    output_rc=0
    output_dump=$("$family" -t mangle -S OUTPUT 2>/dev/null) || output_rc=$?
    if [ "$output_rc" -ne 0 ]; then failed=1; continue; fi
    jump_count=$(printf '%s\n' "$output_dump" | grep -Fxc -- '-A OUTPUT -j HANNIBOMB_QOS' 2>/dev/null || :)
    case "$jump_count" in ''|*[!0-9]*) failed=1; continue ;; esac
    if [ "$jump_count" -gt 1 ]; then
      # Duplicate references may have been added by another actor; do not guess ownership.
      failed=1; continue
    fi

    if [ "$chain_rc" -ne 0 ]; then
      # An OUTPUT reference without a verifiable chain is not safe to modify.
      [ "$jump_count" -eq 0 ] || failed=1
      continue
    fi

    expected_tcp="-A HANNIBOMB_QOS -p tcp --dport $saved_port -j DSCP --set-dscp $saved_value"
    expected_tcp_canon="-A HANNIBOMB_QOS -p tcp -m tcp --dport $saved_port -j DSCP --set-dscp $saved_value"
    expected_udp="-A HANNIBOMB_QOS -p udp --dport $saved_port -j DSCP --set-dscp $saved_value"
    expected_udp_canon="-A HANNIBOMB_QOS -p udp -m udp --dport $saved_port -j DSCP --set-dscp $saved_value"
    case "$saved_protocol" in
      tcp) expected_count=1; expected_one=$expected_tcp; expected_two= ;;
      udp) expected_count=1; expected_one=$expected_udp; expected_two= ;;
      both) expected_count=2; expected_one=$expected_tcp; expected_two=$expected_udp ;;
      *) failed=1; continue ;;
    esac
    seen_tcp=0 seen_udp=0 conflict=0 actual_count=0
    while IFS= read -r rule_line; do
      case "$rule_line" in
        '-N HANNIBOMB_QOS') : ;;
        "$expected_tcp"|"$expected_tcp_canon")
          if [ "$saved_protocol" = udp ] || [ "$seen_tcp" -eq 1 ]; then conflict=1
          else seen_tcp=1; actual_count=$((actual_count + 1)); fi ;;
        "$expected_udp"|"$expected_udp_canon")
          if [ "$saved_protocol" = tcp ] || [ "$seen_udp" -eq 1 ]; then conflict=1
          else seen_udp=1; actual_count=$((actual_count + 1)); fi ;;
        '-A HANNIBOMB_QOS '*) conflict=1 ;;
        '') : ;;
        *) conflict=1 ;;
      esac
    done <<EOF
$chain_dump
EOF
    case "$saved_protocol" in
      tcp) seen_one=$seen_tcp; seen_two=0 ;;
      udp) seen_one=$seen_udp; seen_two=0 ;;
      both) seen_one=$seen_tcp; seen_two=$seen_udp ;;
    esac
    # A partial install is recoverable, but unknown/duplicate rules are never deleted.
    if [ "$conflict" -ne 0 ] || [ "$actual_count" -gt "$expected_count" ]; then
      failed=1; continue
    fi

    # Remove only the exact jump after the complete chain has been validated.
    if [ "$jump_count" -eq 1 ]; then
      "$family" -t mangle -D OUTPUT -j HANNIBOMB_QOS >/dev/null 2>&1 || { failed=1; continue; }
    fi
    if [ "$seen_one" -eq 1 ]; then
      case "$expected_one" in
        "$expected_tcp") "$family" -t mangle -D HANNIBOMB_QOS -p tcp --dport "$saved_port" -j DSCP --set-dscp "$saved_value" >/dev/null 2>&1 || { failed=1; continue; } ;;
        "$expected_udp") "$family" -t mangle -D HANNIBOMB_QOS -p udp --dport "$saved_port" -j DSCP --set-dscp "$saved_value" >/dev/null 2>&1 || { failed=1; continue; } ;;
      esac
    fi
    if [ "$seen_two" -eq 1 ]; then
      "$family" -t mangle -D HANNIBOMB_QOS -p udp --dport "$saved_port" -j DSCP --set-dscp "$saved_value" >/dev/null 2>&1 || { failed=1; continue; }
    fi
    "$family" -t mangle -X HANNIBOMB_QOS >/dev/null 2>&1 || { failed=1; continue; }
  done < "$DSCP_STATE"
  if [ "$failed" -eq 0 ]; then rm -f "$DSCP_STATE"; else log "DSCP cleanup incomplete or ownership conflict detected; preserving DSCP state record."; fi
  [ "$failed" -eq 0 ]
}

apply_dscp_profile() {
  load_config
  [ "$ENABLE_DSCP" = 1 ] || { echo "DSCP marking is OFF; no firewall rule change."; return 0; }
  case "$DSCP_PORT" in *[!0-9]*|'') echo "Invalid DSCP port."; return 1 ;; esac
  [ "$DSCP_PORT" -ge 1 ] 2>/dev/null && [ "$DSCP_PORT" -le 65535 ] 2>/dev/null || { echo "DSCP port must be 1–65535."; return 1; }
  case "$DSCP_VALUE" in *[!0-9]*|'') echo "Invalid DSCP value."; return 1 ;; esac
  [ "$DSCP_VALUE" -ge 0 ] 2>/dev/null && [ "$DSCP_VALUE" -le 63 ] 2>/dev/null || { echo "DSCP value must be 0–63."; return 1; }
  case "$DSCP_PROTOCOL" in tcp|udp|both) ;; *) echo "Invalid DSCP protocol."; return 1 ;; esac
  if ! clear_dscp_rules; then
    echo "Existing DSCP cleanup is incomplete; no new rules were installed. Recovery state was preserved."
    return 1
  fi
  families=""
  for family in iptables ip6tables; do
    command -v "$family" >/dev/null 2>&1 || continue
    if "$family" -t mangle -S HANNIBOMB_QOS >/dev/null 2>&1; then
      echo "$family has an existing HANNIBOMB_QOS chain not owned by this run; refusing to alter it."; continue
    fi
    "$family" -t mangle -N HANNIBOMB_QOS >/dev/null 2>&1 || continue
    # Persist ownership before adding rules so interrupted/partial installs are recoverable.
    if ! printf '%s\t%s\t%s\t%s\n' "$family" "$DSCP_PORT" "$DSCP_VALUE" "$DSCP_PROTOCOL" >> "$DSCP_STATE"; then
      "$family" -t mangle -X HANNIBOMB_QOS >/dev/null 2>&1 || :
      echo "$family could not save a recovery record; DSCP setup aborted."
      restore_dscp_profile >/dev/null 2>&1 || :
      return 1
    fi
    ok=1
    for proto in $([ "$DSCP_PROTOCOL" = both ] && echo "tcp udp" || echo "$DSCP_PROTOCOL"); do
      if ! "$family" -t mangle -A HANNIBOMB_QOS -p "$proto" --dport "$DSCP_PORT" -j DSCP --set-dscp "$DSCP_VALUE" >/dev/null 2>&1; then ok=0; break; fi
    done
    if [ "$ok" = 1 ]; then
      if ! "$family" -t mangle -I OUTPUT 1 -j HANNIBOMB_QOS >/dev/null 2>&1; then ok=0; fi
    fi
    # Read back the chain and output jump: never tell the UI success on command exit alone.
    if [ "$ok" = 1 ]; then
      chain_dump=$("$family" -t mangle -S HANNIBOMB_QOS 2>/dev/null) || ok=0
      output_dump=$("$family" -t mangle -S OUTPUT 2>/dev/null) || ok=0
      for proto in $([ "$DSCP_PROTOCOL" = both ] && echo "tcp udp" || echo "$DSCP_PROTOCOL"); do
        expected="-A HANNIBOMB_QOS -p $proto --dport $DSCP_PORT -j DSCP --set-dscp $DSCP_VALUE"
        expected_canon="-A HANNIBOMB_QOS -p $proto -m $proto --dport $DSCP_PORT -j DSCP --set-dscp $DSCP_VALUE"
        if ! printf '%s\n' "$chain_dump" | grep -Fqx -- "$expected" && ! printf '%s\n' "$chain_dump" | grep -Fqx -- "$expected_canon"; then ok=0; fi
      done
      jump_count=$(printf '%s\n' "$output_dump" | grep -Fxc -- '-A OUTPUT -j HANNIBOMB_QOS' 2>/dev/null || :)
      [ "$jump_count" = 1 ] || ok=0
    fi
    if [ "$ok" = 1 ]; then
      families="${families}${family} "
      echo "DSCP rule installed and verified: $family $DSCP_PROTOCOL port $DSCP_PORT -> DSCP $DSCP_VALUE"
    else
      echo "$family DSCP rule install/read-back failed; attempting safe rollback."
      if ! clear_dscp_rules; then
        echo "Partial DSCP setup remains due to an ownership conflict; recovery record retained."
        set_config ENABLE_DSCP 0
        return 1
      fi
      families=""
      break
    fi
  done
  if [ -n "$families" ] && [ -f "$DSCP_STATE" ]; then
    log "DSCP marking enabled: port=$DSCP_PORT protocol=$DSCP_PROTOCOL value=$DSCP_VALUE families=$(tr '\n' ' ' < "$DSCP_STATE")"
    echo "DSCP marking installed and verified only for port $DSCP_PORT. Network QoS may ignore DSCP; no latency improvement is guaranteed."
    return 0
  fi
  [ ! -f "$DSCP_STATE" ] || { echo "DSCP setup did not fully verify; recovery state retained."; set_config ENABLE_DSCP 0; return 1; }
  set_config ENABLE_DSCP 0
  echo "No compatible iptables/ip6tables DSCP target succeeded; DSCP remains disabled."; return 1
}

restore_dscp_profile() {
  # An explicit restore disables future automatic reapply even if a third-party rule
  # forces us to retain the recovery record for manual cleanup.
  set_config ENABLE_DSCP 0
  if [ -f "$DSCP_STATE" ]; then
    clear_dscp_rules
    [ ! -f "$DSCP_STATE" ] || { echo "DSCP state cleanup could not be verified; backup retained and automatic reapply disabled."; return 1; }
  fi
  set_config ENABLE_DSCP 0
  echo "DSCP rules owned by HanniBomb were removed where available. Other firewall chains were not flushed."
}

health_report() {
  echo "===== HanniBomb system snapshot ====="
  detect
  echo
  echo "Memory (read-only):"
  if [ -r /proc/meminfo ]; then head -n 8 /proc/meminfo; else echo "meminfo unavailable."; fi
  echo
  echo "Storage (read-only):"
  if command -v df >/dev/null 2>&1; then df -h /data 2>/dev/null; else echo "df unavailable."; fi
  echo
  network_report
  network_advanced_report
  echo
  select_profile
  echo "AI recommendation=$SELECTED_PROFILE"
  echo "AI reasoning=$AI_REASON"
}

status() {
  load_config
  select_profile
  echo "HanniBomb v1.4.2 — author Hannhanniii"
  echo "Mode=$MODE configured_profile=$PROFILE adaptive_AI=$AI_ADAPTIVE"
  echo "Recommended_profile=$SELECTED_PROFILE"
  echo "Reason=$AI_REASON"
  echo "CPU governor control=$ENABLE_GOVERNOR_CONTROL"
  echo "Wi-Fi scan throttling opt-in=$ENABLE_WIFI_SCAN_THROTTLE current=$(wifi_throttle_status)"
  echo "Network tuning enabled=$ENABLE_NETWORK_TWEAKS preset=$NETWORK_PRESET"
  echo "Private DNS mode=$(settings get global private_dns_mode 2>/dev/null) (never changed by TCP presets)"
  echo "Display saturation control=$(color_support_text) (manual only)"
  echo "Android system notifications=$ENABLE_NOTIFICATIONS"
  echo "Game auto profile=$ENABLE_GAME_AUTO_PROFILE packages=${GAME_PACKAGES:-not_configured}"
  echo "DSCP=$ENABLE_DSCP port=$DSCP_PORT value=$DSCP_VALUE protocol=$DSCP_PROTOCOL"
  echo "TC shaping=$ENABLE_TC_SHAPING interface=${TC_INTERFACE:-not_configured} rate=${TC_RATE}Mbit"
  echo "Log=$LOG"
}

cpu_governor_node_is_current() {
  candidate=$1
  case "$candidate" in */scaling_governor) ;; *) return 1 ;; esac
  for policy_dir in $(cpu_policy_dirs); do
    [ "$candidate" = "$policy_dir/scaling_governor" ] && return 0
  done
  return 1
}

cpu_record_original() {
  cpu_node=$1 cpu_value=$2
  if [ ! -e "$CPU_BACKUP" ]; then : > "$CPU_BACKUP" 2>/dev/null || return 1; fi
  [ -f "$CPU_BACKUP" ] && [ -w "$CPU_BACKUP" ] || return 1
  if awk -F '\t' -v p="$cpu_node" '$1 == p {found=1} END {exit found ? 0 : 1}' "$CPU_BACKUP" 2>/dev/null; then
    return 0
  fi
  printf '%s\t%s\n' "$cpu_node" "$cpu_value" >> "$CPU_BACKUP" 2>/dev/null || return 1
  awk -F '\t' -v p="$cpu_node" -v v="$cpu_value" '$1 == p && $2 == v {found=1} END {exit found ? 0 : 1}' "$CPU_BACKUP" 2>/dev/null
}

cpu_record_applied() {
  cpu_node=$1 cpu_value=$2
  cpu_tmp="$CPU_APPLIED.tmp"
  if [ -f "$CPU_APPLIED" ]; then
    awk -F '\t' -v p="$cpu_node" '$1 != p {print}' "$CPU_APPLIED" > "$cpu_tmp" 2>/dev/null || { rm -f "$cpu_tmp"; return 1; }
  else
    : > "$cpu_tmp" 2>/dev/null || return 1
  fi
  printf '%s\t%s\n' "$cpu_node" "$cpu_value" >> "$cpu_tmp" 2>/dev/null || { rm -f "$cpu_tmp"; return 1; }
  mv "$cpu_tmp" "$CPU_APPLIED" 2>/dev/null || { rm -f "$cpu_tmp"; return 1; }
  awk -F '\t' -v p="$cpu_node" -v v="$cpu_value" '$1 == p {found=1; actual=$2} END {exit found && actual == v ? 0 : 1}' "$CPU_APPLIED" 2>/dev/null
}

apply_governor_profile() {
  chosen=$1
  load_config
  [ "$ENABLE_GOVERNOR_CONTROL" = 1 ] || { echo "Observe-only: CPU governor writes disabled (default)."; return 0; }
  case "$chosen" in
    balanced) requested=$GOVERNOR_BALANCED ;;
    performance) requested=$GOVERNOR_PERFORMANCE ;;
    battery) requested=$GOVERNOR_BATTERY ;;
    *) echo "Unknown profile; skipped."; return 1 ;;
  esac
  case "$requested" in ''|*[!A-Za-z0-9_.-]*) echo "Invalid governor token; skipped."; return 1 ;; esac
  found=0
  for d in $(cpu_policy_dirs); do
    [ -r "$d/scaling_available_governors" ] && [ -w "$d/scaling_governor" ] || continue
    avail=$(cat "$d/scaling_available_governors" 2>/dev/null)
    case " $avail " in *" $requested "*) ;; *) log "skip $d: governor $requested unavailable"; continue ;; esac
    node="$d/scaling_governor"
    old=$(cat "$node" 2>/dev/null)
    [ -n "$old" ] || { log "skip $node: original governor unreadable; no write performed"; continue; }
    if [ -f "$CPU_BACKUP" ]; then
      saved_original=$(awk -F '\t' -v p="$node" '$1 == p {v=$2; found=1} END {if (found) print v}' "$CPU_BACKUP" 2>/dev/null)
      saved_applied=$(awk -F '\t' -v p="$node" '$1 == p {v=$2} END {print v}' "$CPU_APPLIED" 2>/dev/null)
      if [ -n "$saved_original" ] && [ "$old" != "$saved_original" ] && { [ -z "$saved_applied" ] || [ "$old" != "$saved_applied" ]; }; then
        log "preserve $node: current governor changed outside HanniBomb; no write performed"
        continue
      fi
    elif [ -e "$CPU_BACKUP" ]; then
      log "skip $node: recovery path is not a regular file; no write performed"
      continue
    fi
    cpu_record_original "$node" "$old" || { log "skip $node: could not persist original governor; no write performed"; continue; }
    # Write the intended restore marker before the sysfs mutation. If recording fails,
    # do not touch the kernel node.
    cpu_record_applied "$node" "$requested" || { log "skip $node: could not persist governor recovery state; no write performed"; continue; }
    if printf '%s\n' "$requested" > "$node" 2>/dev/null; then
      actual=$(cat "$node" 2>/dev/null)
      if [ "$actual" = "$requested" ]; then
        log "governor changed $node -> $actual"; found=1
      else
        log "governor read-back mismatch $node requested=$requested actual=${actual:-unknown}; recovery marker retained conservatively"
      fi
    else
      log "write failed $node; recovery marker retained"
    fi
  done
  [ "$found" = 1 ] || echo "No compatible writable CPU governor nodes found; skipped."
  [ "$found" = 1 ] && echo "Requested governor applied to compatible CPU policies: $requested"
}

restore_governor_profile() {
  [ -f "$CPU_BACKUP" ] || { echo "No HanniBomb CPU governor backup exists."; return 0; }
  restored=0 preserved=0
  while IFS="$(printf '\t')" read -r node original; do
    [ -n "$node" ] && [ -n "$original" ] || continue
    if ! cpu_governor_node_is_current "$node"; then
      echo "PRESERVED governor $node: recovery path is not a current CPU policy governor node."
      preserved=$((preserved + 1))
      continue
    fi
    expected=$(awk -F '\t' -v p="$node" '$1 == p {v=$2} END {print v}' "$CPU_APPLIED" 2>/dev/null)
    current=$(cat "$node" 2>/dev/null)
    if [ "$current" = "$original" ]; then
      echo "ALREADY_RESTORED governor $node=$original"; restored=$((restored + 1))
    elif [ -n "$expected" ] && [ "$current" = "$expected" ] && [ -w "$node" ]; then
      if printf '%s\n' "$original" > "$node" 2>/dev/null; then
        after=$(cat "$node" 2>/dev/null)
        if [ "$after" = "$original" ]; then
          echo "RESTORED governor $node=$original"; restored=$((restored + 1))
        else echo "PRESERVED governor $node: restore read-back mismatch"; preserved=$((preserved + 1)); fi
      else echo "PRESERVED governor $node: write rejected"; preserved=$((preserved + 1)); fi
    else
      echo "PRESERVED governor $node: current value changed or node unavailable"; preserved=$((preserved + 1))
    fi
  done < "$CPU_BACKUP"
  if [ "$preserved" -eq 0 ]; then rm -f "$CPU_BACKUP" "$CPU_APPLIED"; else echo "CPU backup retained for safe recovery."; fi
  echo "CPU governor restore finished; restored=$restored preserved=$preserved."
  [ "$preserved" -eq 0 ]
}

post_android_notification() {
  message=$1
  command -v cmd >/dev/null 2>&1 || { echo "NOTIFICATION_ERROR=Android cmd utility unavailable"; return 1; }
  # Do not rely on `cmd notification help`: some vendor ROMs omit the command from help output
  # while still accepting it. Attempt the actual operation and report its real result.
  counter_file="$DATA_DIR/notification_counter"
  counter=$(cat "$counter_file" 2>/dev/null)
  case "$counter" in ''|*[!0-9]*) counter=0 ;; esac
  counter=$((counter + 1))
  printf '%s\n' "$counter" > "$counter_file"
  tag="hannibomb-$counter-$(date +%s 2>/dev/null)"
  # Try the documented style-first argument order, then retry without a style for vendor compatibility.
  notif_out=$(cmd notification post -S bigtext -t "HanniBomb" "$tag" "$message" 2>&1); notif_rc=$?
  if [ "$notif_rc" -ne 0 ]; then
    log "Android notification styled post failed: exit=$notif_rc output=${notif_out:-empty}; retrying plain notification"
    fallback_tag="${tag}-plain"
    notif_fallback=$(cmd notification post -t "HanniBomb" "$fallback_tag" "$message" 2>&1); fallback_rc=$?
    if [ "$fallback_rc" -eq 0 ]; then
      echo "NOTIFICATION_FALLBACK=plain"
      [ -n "$notif_fallback" ] && printf 'NOTIFICATION_OUTPUT=%s\n' "$notif_fallback"
      echo "NOTIFICATION_EXIT=0"
      log "Android plain notification command accepted: tag=$fallback_tag"
      return 0
    fi
    printf 'NOTIFICATION_OUTPUT=%s\n' "${notif_fallback:-${notif_out:-<no output>}}"
    printf 'NOTIFICATION_EXIT=%s\n' "$fallback_rc"
    log "Android notification command failed: styled=$notif_rc plain=$fallback_rc output=${notif_fallback:-$notif_out}"
    echo "NOTIFICATION_ERROR=Android/ROM rejected both notification command variants. Check notification permission, system notifications, and the command output above."
    return 1
  fi
  [ -n "$notif_out" ] && printf 'NOTIFICATION_OUTPUT=%s\n' "$notif_out"
  printf 'NOTIFICATION_EXIT=%s\n' "$notif_rc"
  log "Android notification command accepted: tag=$tag"
  return 0
}

notify_mode_transition() {
  load_config
  state="$MODE|$PROFILE|$SELECTED_PROFILE"
  previous=$(cat "$ACTIVE_STATE" 2>/dev/null || :)
  if [ -n "$previous" ] && [ "$previous" != "$state" ]; then
    case "$MODE" in hybrid) mode_label="Hybrid Otomatis" ;; *) mode_label="Manual" ;; esac
    case "$SELECTED_PROFILE" in balanced) profile_label="Balance" ;; performance) profile_label="Performance" ;; battery) profile_label="Battery Saver" ;; *) profile_label="$SELECTED_PROFILE" ;; esac
    governor_label=$([ "$ENABLE_GOVERNOR_CONTROL" = 1 ] && echo ON || echo OFF)
    message="$mode_label: profil $profile_label aktif. Kontrol governor CPU: $governor_label."
    if [ "$ENABLE_NOTIFICATIONS" = 1 ]; then
      if post_android_notification "$message"; then
        echo "MODE_NOTIFICATION=sent"
        log "Android notification posted: $message"
      else
        echo "MODE_NOTIFICATION=unsupported_or_blocked"
        log "Android notification unavailable/blocked; WebUI toast remains available while open."
      fi
    else
      echo "MODE_NOTIFICATION=disabled"
    fi
    log "profile state transition: $previous -> $state; reason=$AI_REASON"
  else
    echo "MODE_NOTIFICATION=not_needed"
  fi
  printf '%s\n' "$state" > "$ACTIVE_STATE"
}

# Returns success only when an automatic game override should yield back to a safe Battery profile.
# Manual user-selected Performance is not overridden by this guard.
game_override_needs_restore() {
  [ -f "$GAME_OVERRIDE" ] || return 1
  saved_mode=$(sed -n '1p' "$GAME_OVERRIDE" 2>/dev/null)
  saved_adaptive=$(sed -n '3p' "$GAME_OVERRIDE" 2>/dev/null)
  [ "$saved_mode" = hybrid ] || return 1
  load_config
  read_signals
  [ "$LOW_POWER" = 1 ] && return 0
  [ "$saved_adaptive" = 1 ] || return 1
  if [ "$BATTERY_LEVEL" != unknown ] && [ "$BATTERY_LEVEL" -le "$AI_LOW_BATTERY" ]; then return 0; fi
  if [ "$THERMAL_STATUS" != unknown ] && [ "$THERMAL_STATUS" -ge "$AI_THERMAL_STATUS_LIMIT" ]; then return 0; fi
  return 1
}

apply() {
  select_profile
  log "selected profile=$SELECTED_PROFILE; mode=$MODE; reason=$AI_REASON"
  echo "HanniBomb selected profile: $SELECTED_PROFILE"
  echo "Reason: $AI_REASON"
  apply_governor_profile "$SELECTED_PROFILE"
  apply_wifi_scan_throttle
  apply_network_profile
  notify_mode_transition
}

restore_game_override() {
  [ -f "$GAME_OVERRIDE" ] || return 0
  old_mode=$(sed -n '1p' "$GAME_OVERRIDE" 2>/dev/null)
  old_profile=$(sed -n '2p' "$GAME_OVERRIDE" 2>/dev/null)
  old_adaptive=$(sed -n '3p' "$GAME_OVERRIDE" 2>/dev/null)
  load_config
  if [ "$MODE" = manual ] && [ "$PROFILE" = performance ]; then
    set_config MODE "${old_mode:-hybrid}"
    set_config PROFILE "${old_profile:-balanced}"
    # AI_ADAPTIVE was not changed by the override; preserve any intentional user change made in-game.
    log "game auto-profile ended; restoring previous mode/profile: ${old_mode:-hybrid}/${old_profile:-balanced}"
    rm -f "$GAME_OVERRIDE"
    apply
  else
    log "game auto-profile marker cleared without overwriting a manually changed profile"
    rm -f "$GAME_OVERRIDE"
  fi
}
