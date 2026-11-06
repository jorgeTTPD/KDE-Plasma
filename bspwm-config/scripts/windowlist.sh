#!/bin/bash
# $1 = "current" or "all"

MODE="${1:-current}"

declare -A WIN_MAP

if [ "$MODE" = "current" ]; then
    DESKS=$(bspc query -D -d)
else
    DESKS=$(bspc query -D)
fi

for d in $DESKS; do
    DNAME=$(bspc query -D -d "$d" --names)
    NODES=$(bspc query -N -d "$d")
    for n in $NODES; do
        NAME=$(xprop -id "$n" _NET_WM_NAME 2>/dev/null | grep -oP '"\K[^"]+')
        [ -z "$NAME" ] && NAME=$(xprop -id "$n" WM_NAME 2>/dev/null | grep -oP '"\K[^"]+')
        [ -z "$NAME" ] && continue
        if [ "$MODE" = "all" ]; then
            LABEL="[$DNAME] $NAME"
        else
            LABEL="$NAME"
        fi
        WIN_MAP["$LABEL"]="$n"
    done
done

[ ${#WIN_MAP[@]} -eq 0 ] && exit 0

ENTRIES=""
for k in "${!WIN_MAP[@]}"; do
    ENTRIES+="${k}\n"
done

PROMPT="Escritorio actual"
[ "$MODE" = "all" ] && PROMPT="Todos"

CHOSEN=$(echo -e "$ENTRIES" | sed '/^$/d' | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 500px;}' -theme-str 'listview {lines: 12;}')

[ -n "$CHOSEN" ] && bspc node "${WIN_MAP[$CHOSEN]}" -f
