#!/bin/bash
set -e

# Colores
ok="\e[32m✔\e[0m"
info="\e[34m→\e[0m"

# ── Paquetes ──────────────────────────────────────────────────────────────────
PACKAGES=(
    # Compositor y sesion (swaynag viene incluido en el paquete sway)
    sway swaylock swayidle

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

    # Editor (Markdown / Marp)
    code

    # Calendario (Google Calendar vía GNOME Online Accounts)
    # gnome-keyring/gcr: Secret Service para guardar el token de Google.
    gnome-calendar gnome-online-accounts gnome-control-center evolution-data-server
    gnome-keyring gcr

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

# Usuario destino de las configs de ~/ (el que invocó sudo, no root)
TARGET_USER="${SUDO_USER:-root}"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ]; then
    echo "No pude resolver el home de '$TARGET_USER'."
    exit 1
fi

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
install_system usr/local/bin/cachyos-sync
chmod +x /usr/local/bin/cachyos-sync
install_system usr/local/bin/toggle-calendar
chmod +x /usr/local/bin/toggle-calendar
install_system usr/local/bin/toggle-scratch-app
chmod +x /usr/local/bin/toggle-scratch-app

# ── Archivos de usuario ───────────────────────────────────────────────────────
# Copia un archivo de home/ al home del usuario y deja la propiedad correcta
# (se ejecuta como root, así que hay que devolver el ownership a $TARGET_USER).
install_user() {
    local rel="$1"
    local src="$REPO_DIR/home/$rel"
    local dst="$USER_HOME/$rel"
    sudo -u "$TARGET_USER" mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chown "$TARGET_USER:$TARGET_USER" "$dst"
    echo -e "${ok} ~/$rel"
}

# Symlinkea un archivo de home/ al home del usuario apuntando al repo.
# Así un `git pull` en el repo actualiza la config al instante (sin reinstalar).
link_user() {
    local rel="$1"
    local target="$REPO_DIR/home/$rel"
    local dst="$USER_HOME/$rel"
    sudo -u "$TARGET_USER" mkdir -p "$(dirname "$dst")"
    sudo -u "$TARGET_USER" ln -sfn "$target" "$dst"
    echo -e "${ok} ~/$rel -> $target"
}

echo -e "${info} Instalando configs de usuario para $TARGET_USER (${USER_HOME})..."

# sway
install_user .config/sway/show-keybindings.sh
chmod +x "$USER_HOME/.config/sway/show-keybindings.sh"

# Terminal y flags de Brave (compartidos vía symlink → git pull los actualiza)
link_user ".config/foot/foot.ini"
link_user ".config/brave-flags.conf"

# Code OSS (Markdown / Marp) — symlinks al repo para sync vía git pull
link_user ".config/Code - OSS/User/settings.json"
link_user ".config/Code - OSS/User/keybindings.json"
link_user ".config/Code - OSS/User/snippets/markdown.json"

# Extensiones de Code OSS (se instalan en el perfil del usuario)
echo -e "${info} Instalando extensiones de Code OSS..."
for ext in marp-team.marp-vscode yzhang.markdown-all-in-one; do
    if sudo -u "$TARGET_USER" env HOME="$USER_HOME" code --install-extension "$ext" --force >/dev/null 2>&1; then
        echo -e "${ok} ext $ext"
    else
        echo -e "  (no se pudo instalar $ext automáticamente; instalala desde la UI)"
    fi
done

echo ""
echo -e "${ok} Todo listo. Iniciá sway o recargá con \$mod+Shift+c."
echo -e "${info} Code OSS: edición de Markdown/Marp lista (preview ctrl+shift+v, Marp ctrl+shift+m)."
