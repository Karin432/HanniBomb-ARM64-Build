#!/system/bin/sh
# Narrow command bridge for the KernelSU WebUI. No arbitrary shell/code execution is exposed.
MODDIR=${0%/*}
export MODDIR HANNIBOMB_MODDIR="$MODDIR"
. "$MODDIR/common.sh"
load_config

err() { echo "ERROR=$*"; return 1; }

print_status() {
  load_config
  select_profile
  model=$(getprop ro.product.model 2>/dev/null)
  android=$(getprop ro.build.version.release 2>/dev/null)
  api=$(getprop ro.build.version.sdk 2>/dev/null)
  kernel=$(uname -r 2>/dev/null)
  board=$(getprop ro.board.platform 2>/dev/null)
  mem_total=$(awk '/MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
  mem_avail=$(awk '/MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
  storage=$(df -k /data 2>/dev/null | awk 'NR==2 {print $4; exit}')
  tcp_available=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)
  tcp_current=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)
  dns_mode=$(settings get global private_dns_mode 2>/dev/null)
  dns_host=$(settings get global private_dns_specifier 2>/dev/null)
  iface=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
  qdisc="unavailable"
  if command -v tc >/dev/null 2>&1 && [ -n "$iface" ]; then qdisc=$(tc qdisc show dev "$iface" 2>/dev/null | awk '/ root/ {print; exit}'); fi
  notif_api=unavailable
  if command -v cmd >/dev/null 2>&1 && cmd notification help 2>&1 | grep -q 'post'; then notif_api=available; fi
  game_running=0; [ -f "$GAME_OVERRIDE" ] && game_running=1
  wifi_state=$(wifi_throttle_status)
  dscp_active=0
  if [ -f "$DSCP_STATE" ]; then
    while IFS="$(printf '\t')" read -r family saved_port saved_value saved_protocol; do
      case "$family" in iptables|ip6tables)
        if command -v "$family" >/dev/null 2>&1 && "$family" -t mangle -S HANNIBOMB_QOS >/dev/null 2>&1 && "$family" -t mangle -S OUTPUT 2>/dev/null | grep -q -- '-j HANNIBOMB_QOS'; then dscp_active=1; fi ;;
      esac
    done < "$DSCP_STATE"
  fi
  tc_active=0
  if [ -f "$TC_STATE" ] && command -v tc >/dev/null 2>&1; then
    saved_tc_iface=$(sed -n '1p' "$TC_STATE" 2>/dev/null)
    saved_tc_rate=$(sed -n '2p' "$TC_STATE" 2>/dev/null)
    case "$saved_tc_iface" in ''|*[!A-Za-z0-9_.:-]*) ;; *)
      saved_tc_line=$(tc qdisc show dev "$saved_tc_iface" 2>/dev/null | awk '/ root/ {print; exit}' | tr 'A-Z' 'a-z')
      case "$saved_tc_line" in *"qdisc tbf 8001: root"*"rate ${saved_tc_rate}mbit"*) tc_active=1 ;; esac ;;
    esac
  fi
  watcher=stopped
  if [ -f "$DATA_DIR/watcher.pid" ]; then
    wpid=$(cat "$DATA_DIR/watcher.pid" 2>/dev/null)
    case "$wpid" in
      *[!0-9]*|'') ;;
      *)
        if kill -0 "$wpid" 2>/dev/null; then
          wcmd=$(tr '\000' ' ' < "/proc/$wpid/cmdline" 2>/dev/null)
          case "$wcmd" in *"$MODDIR/watcher.sh"*) watcher=running ;; esac
        fi
        ;;
    esac
  fi
  active_state=$(cat "$ACTIVE_STATE" 2>/dev/null)
  echo "VERSION=1stabil"
  echo "RUST_DAEMON_STATE=$(sed -n 's/^state=//p' "$DATA_DIR/rust_daemon.status" 2>/dev/null | head -n 1)"
  echo "RUST_DAEMON_KIND=$(sed -n 's/^daemon=//p' "$DATA_DIR/rust_daemon.status" 2>/dev/null | head -n 1)"
  echo "RUST_DAEMON_PID=$(sed -n 's/^pid=//p' "$DATA_DIR/rust_daemon.status" 2>/dev/null | head -n 1)"
  echo "MODE=$MODE"
  echo "PROFILE=$PROFILE"
  echo "SELECTED_PROFILE=$SELECTED_PROFILE"
  echo "AI_ADAPTIVE=$AI_ADAPTIVE"
  echo "AI_REASON=$AI_REASON"
  echo "ENABLE_GOVERNOR_CONTROL=$ENABLE_GOVERNOR_CONTROL"
  echo "ENABLE_NOTIFICATIONS=$ENABLE_NOTIFICATIONS"
  echo "ENABLE_RUST_DAEMON=$ENABLE_RUST_DAEMON"
  echo "ENABLE_WIFI_SCAN_THROTTLE=$ENABLE_WIFI_SCAN_THROTTLE"
  echo "WIFI_THROTTLE_STATE=$wifi_state"
  echo "ENABLE_NETWORK_TWEAKS=$ENABLE_NETWORK_TWEAKS"
  echo "NETWORK_PRESET=$NETWORK_PRESET"
  echo "NETWORK_CUSTOM_CC=$NETWORK_CUSTOM_CC"
  echo "NETWORK_CUSTOM_BUFFER=$NETWORK_CUSTOM_BUFFER"
  echo "ENABLE_GAME_AUTO_PROFILE=$ENABLE_GAME_AUTO_PROFILE"
  echo "GAME_PACKAGES=$GAME_PACKAGES"
  echo "GAME_RUNNING=$game_running"
  echo "ENABLE_DSCP=$ENABLE_DSCP"
  echo "DSCP_ACTIVE=$dscp_active"
  echo "DSCP_PORT=$DSCP_PORT"
  echo "DSCP_VALUE=$DSCP_VALUE"
  echo "DSCP_PROTOCOL=$DSCP_PROTOCOL"
  echo "ENABLE_TC_SHAPING=$ENABLE_TC_SHAPING"
  echo "TC_ACTIVE=$tc_active"
  echo "TC_INTERFACE=$TC_INTERFACE"
  echo "TC_RATE=$TC_RATE"
  echo "MODEL=$model"
  echo "ANDROID=$android"
  echo "API=$api"
  echo "KERNEL=$kernel"
  echo "BOARD=$board"
  echo "LOW_POWER=$LOW_POWER"
  echo "BATTERY_LEVEL=$BATTERY_LEVEL"
  echo "BATTERY_TEMP_RAW=$BATTERY_TEMP"
  echo "THERMAL_STATUS=$THERMAL_STATUS"
  echo "MEM_TOTAL_KB=${mem_total:-unknown}"
  echo "MEM_AVAILABLE_KB=${mem_avail:-unknown}"
  echo "DATA_FREE_KB=${storage:-unknown}"
  echo "TCP_AVAILABLE=$tcp_available"
  echo "TCP_CURRENT=$tcp_current"
  echo "DNS_MODE=$dns_mode"
  echo "DNS_HOST=$dns_host"
  echo "COLOR_SCALE=$COLOR_SCALE"
  echo "DEFAULT_INTERFACE=$iface"
  echo "DEFAULT_QDISC=$qdisc"
  echo "NOTIFICATION_API=$notif_api"
  echo "WATCHER=$watcher"
  echo "ACTIVE_STATE=$active_state"
  echo "LOG_PATH=$LOG"
}

case "${1:-status}" in
  status) print_status ;;
  profile)
    case "${2:-}" in balanced|performance|battery) ;; *) err "profile must be balanced, performance, or battery"; exit 2 ;; esac
    # An explicit profile click is a user decision and must survive game exit.
    rm -f "$GAME_OVERRIDE"
    set_config MODE manual && set_config PROFILE "$2" && apply ;;
  hybrid)
    rm -f "$GAME_OVERRIDE"
    set_config MODE hybrid && apply ;;
  adaptive)
    case "${2:-}" in 0|1) ;; *) err "adaptive expects 0 or 1"; exit 2 ;; esac
    set_config AI_ADAPTIVE "$2" && apply ;;
  governor)
    case "${2:-}" in 0|1) ;; *) err "governor expects 0 or 1"; exit 2 ;; esac
    if [ "$2" = 0 ]; then
      restore_rc=0
      if ! restore_governor_profile; then restore_rc=1; fi
      set_config ENABLE_GOVERNOR_CONTROL 0 && apply || exit 1
      [ "$restore_rc" = 0 ] || exit 1
    else
      set_config ENABLE_GOVERNOR_CONTROL 1 && apply
    fi ;;
  notifications)
    case "${2:-}" in 0|1) ;; *) err "notifications expects 0 or 1"; exit 2 ;; esac
    set_config ENABLE_NOTIFICATIONS "$2" ;;
  wifi-throttle)
    case "${2:-}" in
      1) set_config ENABLE_WIFI_SCAN_THROTTLE 1 && apply_wifi_scan_throttle ;;
      0) restore_wifi_scan_throttle ;;
      *) err "wifi-throttle expects 0 or 1"; exit 2 ;;
    esac ;;
  network-preset)
    case "${2:-}" in game|streaming|download|browsing|outdoor|custom) ;; *) err "invalid network preset"; exit 2 ;; esac
    if [ "$2" = custom ]; then
      case "${3:-auto}" in auto|*[!A-Za-z0-9_.-]*|'') err "invalid TCP algorithm"; exit 2 ;; esac
      case "${4:-4194304}" in *[!0-9]*|'') err "invalid socket buffer size"; exit 2 ;; esac
      [ "${4:-4194304}" -ge 262144 ] 2>/dev/null && [ "${4:-4194304}" -le 16777216 ] 2>/dev/null || { err "socket buffer size must be 262144–16777216"; exit 2; }
    fi
    if ! restore_network_profile >/dev/null 2>&1; then err "TCP restore conflict; no new preset applied. Inspect the saved recovery backup first."; exit 1; fi
    if [ "$2" = custom ]; then
      set_config NETWORK_CUSTOM_CC "${3:-auto}" || exit 2
      set_config NETWORK_CUSTOM_BUFFER "${4:-4194304}" || exit 2
    fi
    set_config NETWORK_PRESET "$2" && set_config ENABLE_NETWORK_TWEAKS 1 && apply_network_profile ;;
  network-restore) restore_network_profile ;;
  network-custom)
    case "${2:-auto}" in auto|*[!A-Za-z0-9_.-]*|'') err "invalid TCP algorithm"; exit 2 ;; esac
    case "${3:-4194304}" in *[!0-9]*|'') err "invalid socket buffer size"; exit 2 ;; esac
    [ "${3:-4194304}" -ge 262144 ] 2>/dev/null && [ "${3:-4194304}" -le 16777216 ] 2>/dev/null || { err "socket buffer size must be 262144–16777216"; exit 2; }
    if ! restore_network_profile >/dev/null 2>&1; then err "TCP restore conflict; no new custom preset applied."; exit 1; fi
    set_config NETWORK_CUSTOM_CC "${2:-auto}" && set_config NETWORK_CUSTOM_BUFFER "${3:-4194304}" && set_config NETWORK_PRESET custom && set_config ENABLE_NETWORK_TWEAKS 1 && apply_network_profile ;;
  dns)
    case "${2:-}" in
      auto) apply_private_dns opportunistic ;;
      off) apply_private_dns off ;;
      hostname)
        host=${3:-}
        apply_private_dns hostname "$host" ;;
      *) err "dns mode must be auto, off, or hostname HOST"; exit 2 ;;
    esac ;;
  dns-restore) restore_private_dns ;;
  color)
    case "${2:-}" in
      ayunda) apply_surfaceflinger_color "${3:-}" ;;
      native)
        case "${3:-}" in *[!0-9]*|'') err "native saturation must be integer 0-100"; exit 2 ;; esac
        [ "$3" -ge 0 ] 2>/dev/null && [ "$3" -le 100 ] 2>/dev/null || { err "native saturation must be 0-100"; exit 2; }
        set_color_saturation "$3" ;;
      *)
        # Backward compatibility: legacy 'color 0..100' means native Android saturation.
        case "${2:-}" in *[!0-9]*|'') err "use color ayunda 1.0..2.0 or color native 0..100"; exit 2 ;; esac
        [ "$2" -ge 0 ] 2>/dev/null && [ "$2" -le 100 ] 2>/dev/null || { err "native saturation must be 0-100"; exit 2; }
        set_color_saturation "$2" ;;
    esac ;;
  apps-list)
    list_mode=${2:-user}
    case "$list_mode" in user) pm list packages -3 2>/dev/null ;; all) pm list packages 2>/dev/null ;; *) err "apps-list expects user or all"; exit 2 ;; esac \
      | sed -n 's/^package://p' | grep -E '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$' | LC_ALL=C sort -u \
      | while IFS= read -r pkg; do
          [ -n "$pkg" ] || continue
          label=$pkg
          apk=$(pm path "$pkg" 2>/dev/null | sed -n '1s/^package://p')
          if command -v aapt >/dev/null 2>&1 && [ -n "$apk" ]; then
            found=$(aapt dump badging "$apk" 2>/dev/null | sed -n "s/^application-label:'\(.*\)'$/\1/p" | head -n 1)
            [ -n "$found" ] && label=$found
          fi
          label=$(printf '%s' "$label" | tr '\t\r\n' '   ' | cut -c1-100)
          printf 'APP|%s|%s\n' "$pkg" "$label"
        done ;;
  game-packages)
    set_config GAME_PACKAGES "${2:-}" || { err "enter package IDs separated by commas, no spaces"; exit 2; }
    echo "Saved game package list. Foreground detection checks about every 5 seconds while the module is active." ;;
  game-auto)
    case "${2:-}" in 0|1) ;; *) err "game-auto expects 0 or 1"; exit 2 ;; esac
    load_config
    if [ "$2" = 1 ] && [ -z "$GAME_PACKAGES" ]; then err "save one or more game package IDs first"; exit 2; fi
    set_config ENABLE_GAME_AUTO_PROFILE "$2" || exit 2
    if [ "$2" = 0 ]; then restore_game_override; else echo "Game auto-profile enabled; the watcher checks about every 5 seconds and still checks battery/thermal safety."; fi ;;
  dscp)
    case "${2:-}" in apply) ;; restore) restore_dscp_profile; exit $? ;; *) err "dscp expects apply or restore"; exit 2 ;; esac
    port=${3:-27015}; value=${4:-46}; proto=${5:-udp}
    case "$port" in *[!0-9]*|'') err "DSCP port must be an integer from 1 to 65535"; exit 2 ;; esac
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null || { err "DSCP port must be an integer from 1 to 65535"; exit 2; }
    case "$value" in *[!0-9]*|'') err "DSCP value must be an integer from 0 to 63"; exit 2 ;; esac
    [ "$value" -ge 0 ] 2>/dev/null && [ "$value" -le 63 ] 2>/dev/null || { err "DSCP value must be an integer from 0 to 63"; exit 2; }
    case "$proto" in tcp|udp|both) ;; *) err "DSCP protocol must be tcp, udp, or both"; exit 2 ;; esac
    set_config DSCP_PORT "$port" && set_config DSCP_VALUE "$value" && set_config DSCP_PROTOCOL "$proto" && set_config ENABLE_DSCP 1 || { err "unable to save DSCP settings"; exit 2; }
    apply_dscp_profile ;;
  tc-status) tc_status "${2:-}" ;;
  tc-apply)
    iface=${2:-}; rate=${3:-10}
    apply_tc_shaping "$iface" "$rate" || exit 1
    set_config TC_INTERFACE "$iface" && set_config TC_RATE "$rate" && set_config ENABLE_TC_SHAPING 1 ;;
  tc-restore) restore_tc_shaping ;;
  ping) network_ping_test "${2:-1.1.1.1}" ;;
  test-notification)
    if post_android_notification "HanniBomb system notification test"; then echo "NOTIFICATION_TEST=sent"; else echo "NOTIFICATION_TEST=unsupported_or_blocked"; exit 1; fi ;;
  report) health_report ;;
  log) tail -n 100 "$LOG" 2>/dev/null || echo "No HanniBomb log yet." ;;
  *) err "unknown action"; exit 2 ;;
esac
