#!/usr/bin/env bash
# Lanza rofi de letras traducidas (super+u). Delega en launch.sh con sufijo .es.
export LYRICS_SUFFIX=".es"
export LYRICS_TL="${LYRICS_TL:-es}"
exec "$HOME/.config/rofi/lyrics/launch.sh" -show lyrics-trans -modes "lyrics-trans:$HOME/.config/rofi/lyrics/lyrics-trans.sh" -theme "$HOME/.config/rofi/lyrics/lyrics.rasi" "$@"
