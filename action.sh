#!/system/bin/sh
MODDIR=${0%/*}
export MODDIR
DATA_DIR=${HANNIBOMB_DATA_DIR:-/data/adb/hannibomb}
CONFIG="$DATA_DIR/config.conf"
mkdir -p "$DATA_DIR" 2>/dev/null
[ -f "$CONFIG" ] || cp "$MODDIR/config.conf" "$CONFIG"
. "$MODDIR/common.sh"

color_menu() {
  echo
  echo "=== HanniBomb Color Display ==="
  echo "Available only when this ROM exposes the Android color_display shell command."
  echo "1) Native Android saturation baseline (100)"
  echo "2) Slightly lower saturation (85)"
  echo "3) Low saturation (60)"
  echo "4) Grayscale (0)"
  echo "5) Custom level (0-100)"
  echo "6) Return to menu"
  printf 'Choose [1-6]: '
  read -r c
  case "$c" in
    1) set_color_saturation 100 ;;
    2) set_color_saturation 85 ;;
    3) set_color_saturation 60 ;;
    4) set_color_saturation 0 ;;
    5) printf 'Enter native saturation [0-100]: '; read -r v; set_color_saturation "$v" ;;
    *) echo 'No display change requested.' ;;
  esac
}

network_menu() {
  echo
  echo "=== HanniBomb / PingPimp-inspired TCP presets ==="
  echo "1) Game (low-latency TCP settings)"
  echo "2) Streaming (moderate socket buffers)"
  echo "3) Download (moderate-high socket buffers)"
  echo "4) Browsing"
  echo "5) Outdoor / unstable signal"
  echo "6) Custom TCP algorithm + socket buffer"
  echo "7) Restore original TCP values and disable network tuning"
  echo "8) Return"
  printf 'Choose [1-8]: ' 
  read -r n
  case "$n" in
    1) preset=game ;; 2) preset=streaming ;; 3) preset=download ;; 4) preset=browsing ;; 5) preset=outdoor ;;
    6)
      available=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)
      echo "Kernel TCP algorithms: ${available:-unavailable}"
      printf 'Choose algorithm (auto or exact supported name): '; read -r cc
      printf 'Socket buffer size in bytes [262144-16777216]: '; read -r buf
      set_config NETWORK_CUSTOM_CC "$cc" || { echo 'Invalid algorithm token.'; return; }
      set_config NETWORK_CUSTOM_BUFFER "$buf" || { echo 'Buffer must be 262144-16777216.'; return; }
      preset=custom ;;
    7) restore_network_profile; return ;; *) echo 'No network preset changed.'; return ;;
  esac
  if ! restore_network_profile; then
    echo "Preset not applied: an existing TCP value changed outside HanniBomb. Review the saved backup before retrying."
    return 1
  fi
  set_config NETWORK_PRESET "$preset"
  set_config ENABLE_NETWORK_TWEAKS 1
  apply_network_profile
}

dns_menu() {
  echo
  echo "=== Android Private DNS ==="
  private_dns_status
  echo "1) Automatic / opportunistic DNS"
  echo "2) Disable Android Private DNS"
  echo "3) Set custom Private DNS hostname (any valid provider; no fixed list)"
  echo "4) Return without change"
  printf 'Choose [1-4]: '
  read -r d
  case "$d" in
    1) apply_private_dns opportunistic ;;
    2) apply_private_dns off ;;
    3)
      printf 'Enter Private DNS hostname (Android DNS-over-TLS provider): '
      read -r host
      apply_private_dns hostname "$host"
      ;;
    *) echo 'DNS unchanged.' ;;
  esac
}

toggle_network_tuning() {
  load_config
  if [ "$ENABLE_NETWORK_TWEAKS" = 1 ]; then
    restore_network_profile
    echo "Network TCP tuning disabled and recorded values were restored where still unchanged."
  else
    echo "Network profile writes can be kernel/ROM dependent. DNS is not touched by these presets."
    printf 'Type ENABLE to permit supported TCP settings: '
    read -r confirm
    if [ "$confirm" = ENABLE ]; then
      network_menu
    else
      echo 'Cancelled; remains disabled.'
    fi
  fi
}

toggle_governor_control() {
  load_config
  if [ "$ENABLE_GOVERNOR_CONTROL" = 1 ]; then
    restore_governor_profile
    set_config ENABLE_GOVERNOR_CONTROL 0
    echo "CPU governor writes disabled; only still-matching HanniBomb governor values were restored."
  else
    echo "WARNING: governors are kernel-specific; unavailable values will be skipped, but performance/heat can change."
    printf 'Type ENABLE to opt in: '
    read -r confirm
    if [ "$confirm" = ENABLE ]; then set_config ENABLE_GOVERNOR_CONTROL 1; apply; else echo 'Cancelled; remains disabled.'; fi
  fi
}

while :; do
  echo
  echo "╔════════════════════════════════╗"
  echo "║       HanniBomb v1.4.2         ║"
  echo "║        by Hannhanniii          ║"
  echo "╚════════════════════════════════╝"
  echo "1) Status + AI recommendation"
  echo "2) Full diagnostics report"
  echo "3) Set Balanced profile"
  echo "4) Set Performance profile (manual mode recommended)"
  echo "5) Set Battery profile"
  echo "6) Toggle Hybrid / Manual"
  echo "7) Color display / saturation"
  echo "8) Enable Android Wi-Fi scan throttling (opt-in)"
  echo "9) Restore Wi-Fi throttle value recorded by HanniBomb"
  echo "10) CPU governor control (default OFF)"
  echo "11) Show recent log"
  echo "12) Network presets (PingPimp-inspired)"
  echo "13) Restore original network TCP values"
  echo "14) Android Private DNS (custom hostname; no provider whitelist)"
  echo "15) Restore Private DNS values recorded by HanniBomb"
  echo "16) Enable/disable network TCP tuning"
  echo "17) Advanced network capability report"
  echo "18) Ping/latency diagnostic (4 ICMP packets)"
  echo "19) Android mode-notification preference"
  echo "20) Configure game package list + automatic profile"
  echo "21) Configure DSCP marking by port (opt-in)"
  echo "22) Restore HanniBomb DSCP rules"
  echo "23) Configure tc TBF traffic shaping (only noqueue root)"
  echo "24) Restore HanniBomb tc shaping"
  echo "25) Test Android notification"
  echo "0) Exit"
  printf 'Choose [0-25]: '  
  read -r choice
  case "$choice" in
    1) status ;;
    2) health_report ;;
    3) rm -f "$GAME_OVERRIDE"; set_config MODE manual; set_config PROFILE balanced; apply ;;
    4) rm -f "$GAME_OVERRIDE"; set_config MODE manual; set_config PROFILE performance; apply ;;
    5) rm -f "$GAME_OVERRIDE"; set_config MODE manual; set_config PROFILE battery; apply ;;
    6) toggle_mode; apply ;;
    7) color_menu ;;
    8) set_config ENABLE_WIFI_SCAN_THROTTLE 1; apply_wifi_scan_throttle ;;
    9) restore_wifi_scan_throttle ;;
    10) toggle_governor_control ;;
    11) if [ -f "$LOG" ]; then tail -n 80 "$LOG"; else echo 'No log yet.'; fi ;;
    12) network_menu ;;
    13) restore_network_profile ;;
    14) dns_menu ;;
    15) restore_private_dns ;;
    16) toggle_network_tuning ;;
    17) load_config; network_advanced_report ;;
    18) printf 'Host/IP (default 1.1.1.1): '; read -r target; network_ping_test "${target:-1.1.1.1}" ;;
    19)
      load_config
      if [ "$ENABLE_NOTIFICATIONS" = 1 ]; then set_config ENABLE_NOTIFICATIONS 0; echo "System notification disabled (WebUI toast can still appear while open)."; else set_config ENABLE_NOTIFICATIONS 1; echo "System notification enabled."; fi ;;
    20)
      load_config
      echo "Enter package IDs separated by commas (no spaces). Example: com.example.game,com.other.game"
      printf 'Game packages: '; read -r pkgs
      set_config GAME_PACKAGES "$pkgs" || { echo "Invalid package list."; continue; }
      printf 'Enable auto game profile? [y/N]: '; read -r yn
      case "$yn" in y|Y|yes|YES) [ -n "$pkgs" ] && set_config ENABLE_GAME_AUTO_PROFILE 1 || echo "Package list cannot be empty." ;; *) set_config ENABLE_GAME_AUTO_PROFILE 0; restore_game_override ;; esac ;;
    21)
      printf 'Target TCP/UDP destination port [27015]: '; read -r dp
      printf 'DSCP value 0-63 [46=EF]: '; read -r dv
      printf 'Protocol tcp/udp/both [udp]: '; read -r proto
      dp=${dp:-27015}; dv=${dv:-46}; proto=${proto:-udp}
      case "$dp" in *[!0-9]*|'') echo 'Port must be an integer from 1 to 65535.'; continue ;; esac
      [ "$dp" -ge 1 ] 2>/dev/null && [ "$dp" -le 65535 ] 2>/dev/null || { echo 'Port must be an integer from 1 to 65535.'; continue; }
      case "$dv" in *[!0-9]*|'') echo 'DSCP value must be 0-63.'; continue ;; esac
      [ "$dv" -ge 0 ] 2>/dev/null && [ "$dv" -le 63 ] 2>/dev/null || { echo 'DSCP value must be 0-63.'; continue; }
      case "$proto" in tcp|udp|both) ;; *) echo 'Protocol must be tcp, udp, or both.'; continue ;; esac
      set_config DSCP_PORT "$dp" && set_config DSCP_VALUE "$dv" && set_config DSCP_PROTOCOL "$proto" && set_config ENABLE_DSCP 1 && apply_dscp_profile ;;
    22) restore_dscp_profile ;;
    23)
      iface=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
      printf 'Network interface [%s]: ' "${iface:-wlan0}"; read -r chosen_iface
      printf 'Egress shaping rate Mbit/s [10, valid 2-100]: '; read -r rate
      chosen_iface=${chosen_iface:-${iface:-wlan0}}; rate=${rate:-10}
      if apply_tc_shaping "$chosen_iface" "$rate"; then set_config TC_INTERFACE "$chosen_iface" && set_config TC_RATE "$rate" && set_config ENABLE_TC_SHAPING 1; fi ;;
    24) restore_tc_shaping ;;
    25) if post_android_notification "HanniBomb system notification test"; then echo "Notification request sent."; else echo "Notification service unsupported or blocked by ROM/settings."; fi ;;
    0) break ;;
    *) echo 'Unknown option; no change.' ;;
  esac
done
