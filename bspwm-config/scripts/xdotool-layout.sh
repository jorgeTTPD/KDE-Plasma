#!/bin/bash

export DISPLAY=:0
STEP=30

case "$1" in
    # Centrar ventana
    center)
        eval $(xdotool getactivewindow getwindowgeometry --shell)
        SCREEN_W=$(xdotool getdisplaygeometry | awk '{print $1}')
        SCREEN_H=$(xdotool getdisplaygeometry | awk '{print $2}')
        NEW_X=$(( (SCREEN_W - WIDTH) / 2 ))
        NEW_Y=$(( (SCREEN_H - HEIGHT) / 2 ))
        xdotool windowmove $WINDOW $NEW_X $NEW_Y
        ;;
    
    # Centrar ventana pequeña (50%)
    center-small)
        eval $(xdotool getactivewindow getwindowgeometry --shell)
        SCREEN_W=$(xdotool getdisplaygeometry | awk '{print $1}')
        SCREEN_H=$(xdotool getdisplaygeometry | awk '{print $2}')
        NEW_W=$((SCREEN_W / 2))
        NEW_H=$((SCREEN_H / 2))
        NEW_X=$(( (SCREEN_W - NEW_W) / 2 ))
        NEW_Y=$(( (SCREEN_H - NEW_H) / 2 ))
        xdotool windowsize $WINDOW $NEW_W $NEW_H
        xdotool windowmove $WINDOW $NEW_X $NEW_Y
        ;;
    
    # Redimensionar a la derecha
    resize-right)
        eval $(xdotool getactivewindow getwindowgeometry --shell)
        xdotool windowsize --sync $WINDOW $((WIDTH + $STEP)) $HEIGHT
        ;;
    
    # Redimensionar a la izquierda
    resize-left)
        eval $(xdotool getactivewindow getwindowgeometry --shell)
        xdotool windowsize --sync $WINDOW $((WIDTH - $STEP)) $HEIGHT
        ;;
    
    # Redimensionar hacia abajo
    resize-down)
        eval $(xdotool getactivewindow getwindowgeometry --shell)
        xdotool windowsize --sync $WINDOW $WIDTH $((HEIGHT + $STEP))
        ;;
    
    # Redimensionar hacia arriba
    resize-up)
        eval $(xdotool getactivewindow getwindowgeometry --shell)
        xdotool windowsize --sync $WINDOW $WIDTH $((HEIGHT - $STEP))
        ;;
    
    *)
        echo "Uso: $0 {center|center-small|resize-right|resize-left|resize-down|resize-up}"
        ;;
esac
