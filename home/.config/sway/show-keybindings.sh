#!/bin/sh
# Muestra todos los keybindings de sway (config en vivo) en un buscador fuzzel.
# Lee la config cargada, asi incluye binds custom y los de los include.

swaymsg -t get_config | jq -r '.config' | awk '
/^[[:space:]]*bindsym/ {
    line=$0
    sub(/^[[:space:]]*bindsym[[:space:]]+(--[a-zA-Z-]+[[:space:]]+)*/,"",line)
    n=index(line," ")
    key=substr(line,1,n-1)
    act=substr(line,n+1)
    printf "%-22s  %s\n", key, act
}' | sort -u | fuzzel --dmenu --prompt "keybind> " --width 90 --lines 30
