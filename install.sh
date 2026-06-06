#!/bin/bash
set -e

# Colores
ok="\e[32m✔\e[0m"
info="\e[34m→\e[0m"

# ── Paquetes ──────────────────────────────────────────────────────────────────
PACKAGES=(
    # Compositor y sesion
    sway swaylock swayidle swaynag

    # Barra y notificaciones
    waybar mako

    # Lanzador y utilidades wayland
    fuzzel foot wl-clipboard cliphist wob

    # Audio / brillo / media
    pamixer brightnessctl playerctl

    # Captura de pantalla
    grim slurp

    # Layout y monitor
    autotiling kanshi

    # Bluetooth
    blueman

    # Extras
    jq
)

echo -e "${info} Instalando paquetes..."
pacman -S --needed --noconfirm "${PACKAGES[@]}"
echo -e "${ok} Paquetes instalados."

# ── Archivos de sistema (requieren root) ──────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo "Ejecutá el script como root (sudo ./install.sh)"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

install_system() {
    local src="$REPO_DIR/$1"
    local dst="/$1"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo -e "${ok} /$1"
}

echo -e "${info} Instalando configs de sistema..."
install_system etc/sway/config
install_system etc/xdg/waybar/config.jsonc
install_system etc/xdg/waybar/style.css
install_system usr/local/bin/sway-session-switch
chmod +x /usr/local/bin/sway-session-switch

# ── Archivos de usuario ───────────────────────────────────────────────────────
install_user() {
    local src="$REPO_DIR/home/$1"
    local dst="$HOME/$1"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo -e "${ok} ~/$1"
}

echo -e "${info} Instalando configs de usuario para $SUDO_USER (${HOME})..."
install_user .config/sway/show-keybindings.sh
chmod +x "$HOME/.config/sway/show-keybindings.sh"

echo ""
echo -e "${ok} Todo listo. Iniciá sway o recargá con \$mod+Shift+c."
