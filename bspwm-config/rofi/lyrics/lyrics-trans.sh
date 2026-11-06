#!/usr/bin/env bash
# Modo rofi de letras traducidas (super+u). Delega en lyrics.sh con sufijo .es.
export LYRICS_SUFFIX=".es"
export LYRICS_TL="${LYRICS_TL:-es}"
exec "$HOME/.config/rofi/lyrics/lyrics.sh" "$@"
