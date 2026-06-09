#!/bin/bash
# bootstrap.sh — configura el repo compartido en /opt para multi-usuario.
#
# Hace (una sola vez por máquina):
#   1. Crea el grupo 'confshare' y mete a los usuarios humanos.
#   2. Clona el repo en /opt/cachyos-config (legible por todos, escribible por el grupo).
#   3. Aplica install.sh para cada usuario existente (paquetes + symlinks + extensiones).
#   4. Deja symlinks de Code OSS en /etc/skel → los usuarios NUEVOS los heredan.
#
# Uso:  sudo bash bootstrap.sh
set -e

ok="\e[32m✔\e[0m"
info="\e[34m→\e[0m"

if [ "$EUID" -ne 0 ]; then
    echo "Ejecutá como root: sudo bash bootstrap.sh"
    exit 1
fi

REPO=/opt/cachyos-config
GROUP=confshare
URL=https://github.com/dhruszecki/cachyos-config.git

# ── 1. Grupo compartido ─────────────────────────────────────────────────────
groupadd -f "$GROUP"
echo -e "${ok} grupo $GROUP"

# ── 2. Clon compartido en /opt ──────────────────────────────────────────────
git config --system --add safe.directory "$REPO" 2>/dev/null || true
if [ -d "$REPO/.git" ]; then
    echo -e "${info} $REPO ya existe, actualizando..."
    git -C "$REPO" pull --ff-only || true
else
    echo -e "${info} Clonando en $REPO ..."
    git clone "$URL" "$REPO"
fi

# ── 3. Permisos: root:confshare, group-writable, setgid, git compartido ──────
git -C "$REPO" config core.sharedRepository group
chown -R root:"$GROUP" "$REPO"
chmod -R g+rwX "$REPO"
find "$REPO" -type d -exec chmod g+s {} +
echo -e "${ok} permisos del repo (root:$GROUP, group-writable, setgid)"

# ── 4. Usuarios humanos existentes → grupo + aplicar config ─────────────────
mapfile -t USERS < <(awk -F: '$3>=1000 && $3<65000 && $6 ~ /^\/home\// {print $1}' /etc/passwd)
for u in "${USERS[@]}"; do
    usermod -aG "$GROUP" "$u"
    echo -e "${ok} $u agregado a $GROUP"
done

for u in "${USERS[@]}"; do
    echo -e "${info} Aplicando install.sh para $u ..."
    SUDO_USER="$u" bash "$REPO/install.sh"
done

# ── 5. /etc/skel → usuarios NUEVOS heredan los symlinks ─────────────────────
SKEL="/etc/skel/.config/Code - OSS/User"
mkdir -p "$SKEL/snippets"
ln -sfn "$REPO/home/.config/Code - OSS/User/settings.json"          "$SKEL/settings.json"
ln -sfn "$REPO/home/.config/Code - OSS/User/keybindings.json"       "$SKEL/keybindings.json"
ln -sfn "$REPO/home/.config/Code - OSS/User/snippets/markdown.json" "$SKEL/snippets/markdown.json"
echo -e "${ok} /etc/skel: symlinks de Code OSS para usuarios nuevos"

# Terminal (foot) y flags de Brave para usuarios nuevos
mkdir -p "/etc/skel/.config/foot"
ln -sfn "$REPO/home/.config/foot/foot.ini"     "/etc/skel/.config/foot/foot.ini"
ln -sfn "$REPO/home/.config/brave-flags.conf"  "/etc/skel/.config/brave-flags.conf"
echo -e "${ok} /etc/skel: symlinks de foot.ini + brave-flags.conf"

echo ""
echo -e "${ok} Bootstrap completo."
echo -e "${info} Usuarios nuevos: para que puedan EDITAR/sincronizar la config compartida,"
echo -e "    agregalos al grupo:  sudo usermod -aG $GROUP <usuario>"
echo -e "${info} Sincronizar en adelante (cualquier usuario del grupo):  cachyos-sync"
