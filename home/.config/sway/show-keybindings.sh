#!/bin/sh
# Muestra TODOS los keybindings de sway en un buscador fuzzel.
#
# OJO: NO usamos `swaymsg -t get_config` porque NO expande los `include`
# (mostraria solo el config principal, comiendose los binds de config.d/* y de
# ~/.config/sway/config.d/*.conf, ej. apps de Google y de trabajo). Leemos los
# archivos directamente y replicamos el orden de include de /etc/sway/config:
#   1) config principal (~/.config/sway/config si existe, si no /etc/sway/config)
#   2) includes globales:   /etc/sway/config.d/*
#   3) includes por-usuario: ~/.config/sway/config.d/*.conf
#
# Como leemos crudo, expandimos las variables `set $x valor` (ej. $mod -> Mod4)
# para que las teclas se lean claras. La expansion se arma sola desde las lineas
# `set`, asi no hay que mantener una lista aparte.

main="$HOME/.config/sway/config"
[ -f "$main" ] || main="/etc/sway/config"

cfg=$(cat "$main" /etc/sway/config.d/* "$HOME"/.config/sway/config.d/*.conf 2>/dev/null)

# Programa sed que reemplaza cada $variable por su valor (de las lineas `set`).
# Delimitador '|'; escapamos '$' en el patron y '&|\' en el reemplazo.
varsed=$(printf '%s\n' "$cfg" | awk '
/^[[:space:]]*set[[:space:]]+\$/ {
    name=$2; val=$3
    gsub(/[$]/, "\\$", name)            # $ -> \$ en el patron
    gsub(/[\\&|]/, "\\\\&", val)        # escapa \ & | en el reemplazo
    printf "s|%s\\>|%s|g;", name, val
}')

# Una linea de comentario "# kb: <texto>" justo antes de un bindsym se usa como
# descripcion amigable de ese bind (ej. "Google Drive" en vez del comando entero).
# Expandimos las variables ANTES del awk para que la alineacion en columnas sea
# correcta (el padding se calcula sobre la tecla ya expandida, ej. Mod4+h).
printf '%s\n' "$cfg" | sed "$varsed" | awk '
/^[[:space:]]*#[[:space:]]*kb:/ {
    desc=$0
    sub(/^[[:space:]]*#[[:space:]]*kb:[[:space:]]*/,"",desc)
    next
}
/^[[:space:]]*bindsym/ {
    line=$0
    sub(/^[[:space:]]*bindsym[[:space:]]+(--[a-zA-Z-]+[[:space:]]+)*/,"",line)
    n=index(line," ")
    key=substr(line,1,n-1)
    act=substr(line,n+1)
    if (desc != "") act=desc
    printf "%-24s  %s\n", key, act
    desc=""
    next
}
{ desc="" }' | sort -u | fuzzel --dmenu --prompt "keybind> " --width 90 --lines 30
