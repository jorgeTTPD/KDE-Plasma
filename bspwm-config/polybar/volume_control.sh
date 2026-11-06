#!/usr/bin/env bash

# Obtener volumen actual
vol=$(pamixer --get-volume)
mute=$(pamixer --get-mute)

if [ "$mute" = "true" ]; then
    msg="Volumen: Muteado"
else
    msg="Volumen actual: $vol%"
fi

# Lanzar Rofi como pequeña interfaz
choice=$(echo -e " Bajar\n󰕾 Subir\n󰝟 Mute/Unmute" | rofi -dmenu -i -p "$msg" -theme-str 'window {width: 200px; location: north east; y-offset: 30px;}')

case "$choice" in
    " Bajar") pamixer -d 5 ;;
    "󰕾 Subir") pamixer -i 5 ;;
    "󰝟 Mute/Unmute") pamixer -t ;;
esac
