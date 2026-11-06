#!/bin/bash
# Power menu con Rofi - Estilo Hyprland

dir="~/.config/rofi/powermenu/type-1"
uptime=$(uptime -p | sed -e "s/up //g" | sed -e "s/,//g")

options=(
    " 󰤄  Suspender"
    " 󰜉  Reiniciar"
    " 󰍃  Cerrar sesión"
    " 󰐥  Apagar"
    " 󰅖  Cancelar"
)

selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "⚡ Power" -config "$dir/style-5.rasi" -selected-row 4)

case $selected in
    *"Suspender"*)
        systemctl suspend
        ;;
    *"Reiniciar"*)
        systemctl reboot
        ;;
    *"Cerrar sesión"*)
        bspc quit
        ;;
    *"Apagar"*)
        systemctl poweroff
        ;;
    *"Cancelar"*)
        exit 0
        ;;
esac
