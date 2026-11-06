#!/usr/bin/env bash

# Definir la ruta
FIFO="/tmp/cava.fifo"

# Asegurar que el FIFO exista y esté limpio
if [ ! -p "$FIFO" ]; then
    mkfifo "$FIFO"
fi

# Iniciar CAVA en segundo plano si no está corriendo
if ! pgrep -x "cava" > /dev/null; then
    cava -p ~/.config/cava/config-polybar > "$FIFO" 2>&1 &
fi

# Leer el FIFO
# Usamos un bucle para mantener la conexión abierta
while read -r line < "$FIFO"; do
    # Mapeo de caracteres
    bars=" ▂▃▄▅▆▇█"
    output=""
    IFS=';' read -ra values <<< "$line"
    for v in "${values[@]}"; do
        if [ "$v" -ge 0 ] && [ "$v" -le 7 ]; then
            output+="${bars:$v:1}"
        else
            output+=" "
        fi
    done
    echo "$output"
done
