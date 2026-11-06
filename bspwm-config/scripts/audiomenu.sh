#!/bin/bash
set -u
RASI="$HOME/.config/rofi/audiomenu.rasi"
STATE="$HOME/.cache/audiomenu_bridge"
BRIDGE_SINK="MeetMusic"
BRIDGE_SOURCE="MeetMicMix"

menu() { rofi -dmenu -i -p "${2:-Audio}" -theme "$RASI" -selected-row 0 <<<"$1"; }
notify() { notify-send -a "Audio" "$1" "${2:-}" 2>/dev/null || true; }

short_name() {
  case "$1" in
    *usb-Generic*) echo "USB Headset" ;;
    *pci-0000_03_00.6.analog-stereo*) echo "Analógico interno" ;;
    *pci-0000_03_00.1*pro-output*) echo "HDMI" ;;
    *MeetMusic*) echo "Puente Meet" ;;
    *mono-fallback*) echo "Mic USB" ;;
    *.monitor) echo "Monitor $(short_name "${1%.monitor}")" ;;
    *) echo "$1" ;;
  esac
}

pct_of() { pactl "$1" "$2" 2>/dev/null | grep -oP '\d+(?=%|$)' | head -1; }
is_muted() { pactl "$1" "$2" 2>/dev/null | grep -qi 'mute: yes' && echo yes || echo no; }

bridge_on() {
  pactl list short sources 2>/dev/null | grep -q "^.*$BRIDGE_SOURCE" && \
  pactl list short sinks 2>/dev/null | grep -q "$BRIDGE_SINK"
}

bridge_start() {
  bridge_on && return 0
  [ -f "$STATE" ] && bridge_stop >/dev/null 2>&1
  local def_sink real_mic def_src id1 id2 id3 id4
  def_sink="$(pactl get-default-sink)"
  def_src="$(pactl get-default-source 2>/dev/null)"
  real_mic=""
  # Prefiere el micro por defecto si es real (tu 3.5mm pci), no un monitor
  case "$def_src" in
    ""|*.monitor|*MeetMusic*|*MeetMicMix*) ;;
    *) pactl list short sources 2>/dev/null | grep -qF "$def_src" && real_mic="$def_src" ;;
  esac
  [ -z "$real_mic" ] && real_mic="$(pactl list short sources | awk '$2 ~ /^alsa_input/ {print $2; exit}')"
  [ -z "$real_mic" ] && real_mic="$(pactl list short sources | awk '$2 !~ /monitor$/ {print $2; exit}')"
  id1="$(pactl load-module module-null-sink sink_name="$BRIDGE_SINK" sink_properties=device.description="$BRIDGE_SINK")"
  id2="$(pactl load-module module-remap-source master="$BRIDGE_SINK.monitor" source_name="$BRIDGE_SOURCE" source_properties=device.description="$BRIDGE_SOURCE")"
  id3="$(pactl load-module module-loopback source="$real_mic" sink="$BRIDGE_SINK" latency_msec=20)"
  id4="$(pactl load-module module-loopback source="$BRIDGE_SINK.monitor" sink="$def_sink" latency_msec=20)"
  printf '%s\n' "$id1" "$id2" "$id3" "$id4" > "$STATE"
  touch "$HOME/.cache/meet-bridge-want"
  local cmus
  cmus="$(pactl list sink-inputs 2>/dev/null | awk '/^Sink Input #/{id=$3} /application.name = "C\* Music Player"/{print id}' | tr -d '#')"
  [ -n "$cmus" ] && pactl move-sink-input "$cmus" "$BRIDGE_SINK" 2>/dev/null
  notify "Puente Meet ON" "Micro MeetMicMix: $real_mic + cmus. Elige MeetMicMix en Meet."
}

bridge_stop() {
  [ -f "$STATE" ] && while read -r id; do pactl unload-module "$id" 2>/dev/null; done < "$STATE"
  pactl list short modules 2>/dev/null | grep -E "$BRIDGE_SINK|$BRIDGE_SOURCE" | awk '{print $1}' | while read -r id; do pactl unload-module "$id" 2>/dev/null; done
  rm -f "$STATE" "$HOME/.cache/meet-bridge-want"
  notify "Puente Meet OFF" "Módulos virtuales descargados."
}

app_list() {
  pactl list sink-inputs 2>/dev/null | awk '
    /^Sink Input #/{if (id!="") printf "%s | %s%s %s %s\n", id, mute, app, vol, extra; id=$3; sub(/#/,"",id); app=""; vol=""; mute=""; extra=""}
    /application.name =/{gsub(/.*= "|".*/, ""); app=$0}
    /media.name =/{gsub(/.*= "|".*/, ""); if ($0!="playback") extra=$0}
    /media.role =/{gsub(/.*= "|".*/, ""); if (extra=="") extra=$0}
    /Volume:.*%/{match($0, /[0-9]+%/); vol=substr($0, RSTART, RLENGTH)}
    /Mute: yes/{mute="MUTE "}
    END{if (id!="") printf "%s | %s%s %s %s\n", id, mute, app, vol, extra}'
}

pick_app() {
  local list sel id
  list="$(app_list)"
  [ -z "$list" ] && { notify "Audio" "Sin apps reproduciendo."; return 1; }
  sel="$(menu "$list" "App")"
  [ -z "$sel" ] && return 1
  id="$(awk -F' \\| ' '{print $1}' <<<"$sel")"
  app_action "$id" "$sel"
}

app_action() {
  local id="$1" label="$2" op vol
  vol="$(pct_of "get-sink-input-volume" "$id")"
  op="$(menu "🔼 Subir +5% ($vol%)
🔽 Bajar -5% ($vol%)
🔇 Mute toggle
💯 Poner 100%
📢 Poner 150% (boost)
➡ Mover a salida…
⬅ Volver" "App $vol%")"
  case "$op" in
    *Subir*) pactl set-sink-input-volume "$id" +5% ;;
    *Bajar*) pactl set-sink-input-volume "$id" -5% ;;
    *Mute*) pactl set-sink-input-mute "$id" toggle ;;
    *100%*) pactl set-sink-input-volume "$id" 100% ;;
    *150%*) pactl set-sink-input-volume "$id" 150% ;;
    *Mover*) move_app "$id" ;;
    *) return 0 ;;
  esac
  pick_app
}

move_app() {
  local id="$1" sinks sel target
  sinks="$(pactl list short sinks | awk '{print $2}')"
  sel="$(menu "$(while read -r s; do printf '%s (%s)\n' "$(short_name "$s")" "$s"; done <<<"$sinks")" "Mover a")"
  [ -z "$sel" ] && return 0
  target="$(grep -oP '\(.*\)' <<<"$sel" | tr -d '()')"
  pactl move-sink-input "$id" "$target" 2>/dev/null && notify "Audio" "App movida a $(short_name "$target")."
}

sink_menu() {
  local sinks sel target cur
  cur="$(pactl get-default-sink)"
  sinks="$(pactl list short sinks | awk '{print $2}')"
  sel="$(menu "$(while read -r s; do
      v="$(pct_of get-sink-volume "$s")"; m="$(is_muted get-sink-mute "$s")"
      mark=""; [ "$s" = "$cur" ] && mark="● "
      printf '%s%s %s%% %s(%s)\n' "$mark" "$(short_name "$s")" "${v:-?}" "$([ "$m" = yes ] && echo "MUTE " || echo "")" "$s"
    done <<<"$sinks")" "Salida")"
  [ -z "$sel" ] && return 0
  target="$(grep -oP '\(.*\)' <<<"$sel" | tr -d '()')"
  pactl set-default-sink "$target" 2>/dev/null
  for i in $(pactl list short sink-inputs | awk '{print $1}'); do pactl move-sink-input "$i" "$target" 2>/dev/null; done
  notify "Salida" "$(short_name "$target") por defecto."
}

mic_menu() {
  local srcs sel target cur
  cur="$(pactl get-default-source)"
  srcs="$(pactl list short sources | awk '{print $2}' | grep -v '^MeetMusic')"
  sel="$(menu "$(while read -r s; do
      v="$(pct_of get-source-volume "$s")"; m="$(is_muted get-source-mute "$s")"
      mark=""; [ "$s" = "$cur" ] && mark="● "
      printf '%s%s %s%% %s(%s)\n' "$mark" "$(short_name "$s")" "${v:-?}" "$([ "$m" = yes ] && echo "MUTE " || echo "")" "$s"
    done <<<"$srcs")" "Micro")"
  [ -z "$sel" ] && return 0
  target="$(grep -oP '\(.*\)' <<<"$sel" | tr -d '()')"
  pactl set-default-source "$target" 2>/dev/null
  mic_action "$target"
}

mic_action() {
  local t="${1:-$(pactl get-default-source)}" op
  op="$(menu "🔼 Subir mic +5% ($(pct_of get-source-volume "$t")%)
🔽 Bajar mic -5%
🔇 Mute micro toggle
💯 Mic 100%
✔ Usar como defecto
⬅ Volver" "Micro")"
  case "$op" in
    *Subir*) pactl set-source-volume "$t" +5% ;;
    *Bajar*) pactl set-source-volume "$t" -5% ;;
    *Mute*) pactl set-source-mute "$t" toggle ;;
    *100%*) pactl set-source-volume "$t" 100% ;;
    *defecto*) pactl set-default-source "$t" ;;
    *) return 0 ;;
  esac
  mic_action "$t"
}

main() {
  local dsink dsource cmus bridge_label
  dsink="$(short_name "$(pactl get-default-sink)")"
  dsource="$(short_name "$(pactl get-default-source)")"
  cmus="$(pactl list sink-inputs 2>/dev/null | grep -c 'C\* Music Player')"
  bridge_on && bridge_label="🟢 Puente Meet: ON → apagar" || bridge_label="⚫ Puente Meet: OFF → encender (voz+cmus)"
  local sel
  sel="$(menu "🔊 Salida: $dsink ($(pct_of get-sink-volume @DEFAULT_SINK@)%)
🎤 Micro: $dsource ($(pct_of get-source-volume @DEFAULT_SOURCE@)%)
🔇 Mute master toggle
🎚 Volumen por app
🎤 Volumen micro / cambiar micro
$bridge_label" "Audio")"
  case "$sel" in
    *Salida*) sink_menu; main ;;
    *Micro:*) mic_menu; main ;;
    *Mute*master*) pactl set-sink-mute @DEFAULT_SINK@ toggle; main ;;
    *por*app*) pick_app; main ;;
    *micro*) mic_menu; main ;;
    *Puente*) bridge_on && bridge_stop || bridge_start; main ;;
  esac
}

# ensure: recrea el puente si no existe (autostart, sin rofi). No lo apaga nunca.
if [ "${1:-}" = "ensure" ]; then
  bridge_on && exit 0 || bridge_start >/dev/null 2>&1
  exit 0
fi
main
