# CLAUDE.md — cachyos-config

Guía para Claude (y para mí) al modificar la configuración del sistema. Leer esto
**antes** de tocar cualquier config de Sway/waybar/sistema.

Doc humana complementaria del desktop: `~/pad/SWAY-SETUP.md`.

---

## 1. Qué es este repo

Configuración de CachyOS + Sway, **compartida entre todos los usuarios** de la
máquina y reproducible en instalaciones nuevas. Repo: `github.com/dhruszecki/cachyos-config`,
clonado en `~/cachyos-config`.

Usuarios de la máquina:
- `daro` = personal
- `daro-m` = trabajo / trabajo

`etc/` y `usr/` son **globales** (todos los usuarios). `home/` es **por-usuario**
(va al home del que corre el instalador).

---

## 2. Modelo de deploy (CLAVE)

**El repo es la fuente de verdad. Editar `/etc/...` directo se PIERDE en el próximo deploy.**

El deploy lo hace `sudo ./install.sh`:
1. Instala paquetes con `pacman -S --needed --noconfirm`.
2. **Copia** (no symlink) los archivos de sistema:
   - `etc/sway/config` → `/etc/sway/config`
   - `etc/xdg/waybar/{config.jsonc,style.css}` → `/etc/xdg/waybar/...`
   - `usr/local/bin/*` → `/usr/local/bin/*` (+ `chmod +x`)
3. Archivos de usuario (`home/`): algunos se **copian** (`install_user`), otros se
   **symlinkean** al repo (`link_user`, ej. foot.ini, brave-flags, Code OSS) — para esos
   un `git pull` actualiza al instante sin reinstalar.

### Flujo para cambiar algo de sistema
```bash
# 1. Editar en el REPO (no en /etc)
$EDITOR ~/cachyos-config/etc/sway/config
# 2. Validar sintaxis ANTES de deployar
sway -C -c ~/cachyos-config/etc/sway/config   # debe salir sin errores
# 3. Deployar
cd ~/cachyos-config && sudo ./install.sh
# 4. Aplicar
swaymsg reload      # o $mod+Shift+c
# 5. Commitear + push
git add -A && git commit -m "..." && git push
```

> ⚠️ `sudo ./install.sh` deploya **todo** el repo (waybar, scripts, home del usuario).
> Si solo querés un archivo, podés hacer `sudo cp` puntual, pero igual editá primero el repo.

---

## 3. Cómo carga Sway su config (la trampa que ya nos mordió)

- Sway usa `~/.config/sway/config` **si existe**; si no, cae a `/etc/sway/config`.
  En esta máquina **no existe** `~/.config/sway/config` → corre **`/etc/sway/config`**.
- `/etc/sway/config` termina con:
  ```
  include /etc/sway/config.d/*          # global, todos los usuarios
  include ~/.config/sway/config.d/*.conf # por-usuario (ej. PWAs de trabajo de daro-m)
  ```
- **Las PWAs de trabajo (Slack/WhatsApp/Meet) son por-usuario**: viven en
  `~/.config/sway/config.d/work-pwa.conf` (solo daro-m). Por eso el segundo include.

### ⚠️ Gotcha histórico
Hubo un período donde `/etc/sway/config` desplegado era una versión **vieja** (PWAs
inline, **sin** el `include ~/.config/...`). El repo ya tenía la versión refactorizada
pero **nunca se había deployado**. Síntoma: editás `~/.config/sway/config.d/*.conf` y
no pasa nada. **Diagnóstico siempre contra la config VIVA, no contra el archivo:**
```bash
export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock | head -1)
swaymsg -t get_config | jq -r .config | grep '<lo que busco>'
```
Si está en el repo pero no en la config viva → falta `sudo ./install.sh` y/o `swaymsg reload`.

---

## 4. `exec` vs `exec_always` (daemons)

- `swaymsg reload` / `$mod+Shift+c` **NO** re-ejecuta líneas `exec` (solo `exec_always`).
- Los daemons singleton (`mako`, `gnome-keyring-daemon`, `evolution-alarm-notify`,
  `autotiling`…) usan `exec` → arrancan **solo al login**.
- Para reiniciar uno en vivo: lanzarlo a mano con el env correcto, ej.:
  ```bash
  XDG_RUNTIME_DIR=/run/user/$(id -u) setsid <daemon> &
  ```
- **No** convertir daemons singleton a `exec_always` (se duplican en cada reload).

---

## 5. GNOME Calendar (cliente de Google Calendar) — global

Decisión: cliente liviano para Google Calendar, más barato que una pestaña de Brave.
Integra vía **GNOME Online Accounts** (no requiere sesión GNOME completa).

Piezas (todas en el repo, globales):
- `usr/local/bin/toggle-calendar` → `/usr/local/bin/toggle-calendar`: muestra/oculta/lanza.
- En `etc/sway/config`:
  - `for_window [app_id="org.gnome.Calendar"] move scratchpad, scratchpad show, resize set 1000 720, move position center`
  - `bindsym $mod+c exec /usr/local/bin/toggle-calendar`  ← **`$mod+c` = abrir/ocultar calendario** (`$mod` = `Mod4`/Super)
  - `exec /usr/lib/evolution-data-server/evolution-alarm-notify` (recordatorios → mako)
- Paquetes en `install.sh`: `gnome-calendar gnome-online-accounts gnome-control-center evolution-data-server gnome-keyring gcr`.

**Comportamiento:** vive escondido en el scratchpad; `$mod+c` lo trae/oculta. No consume
RAM hasta el primer uso (launch-on-demand). Es el equivalente a "minimizar a la barra"
(Wayland/Sway no tiene minimizar a tray real).

### Online Accounts en Sway (requisitos y gotchas no obvios)
Para agregar la cuenta Google hace falta un **Secret Service** corriendo, que en Sway no
arranca solo:
- `gnome-keyring-daemon --start --components=secrets` (autostart en `etc/sway/config`).
  Expone `org.freedesktop.secrets`; verificar con
  `busctl --user list | grep secrets`. Sin esto **el alta de cuenta falla / no levanta**.
- `goa-daemon` (`/usr/lib/goa-daemon`) se activa por D-Bus (`org.gnome.OnlineAccounts`)
  al abrir el panel; es activatable, no hace falta arrancarlo a mano.

**Gotcha 1 — gnome-control-center se niega a correr fuera de GNOME.** v50 chequea
`XDG_CURRENT_DESKTOP` y sale con *"only supported under GNOME and Unity, exiting"*.
Lanzarlo siempre así:
```bash
XDG_CURRENT_DESKTOP=GNOME gnome-control-center online-accounts
```
Agregar la cuenta es de **una sola vez por usuario**; después GNOME Calendar la lee de GOA.

**Gotcha 2 — cuenta de trabajo trabajo bloqueada por política de Workspace.** Agregar
`tu-dominio-corporativo` vía GOA tira `Error 400: access_not_configured` ("Access blocked: admin
needs to review GNOME"). Es política del Workspace de trabajo (apps de terceros no aprobadas),
**no** un bug de config. La cuenta **personal** de Google sí funciona normal. Alternativas
para la cuenta de trabajo:
1. Pedir al admin de trabajo que apruebe la app GNOME (botón "Request Access").
2. **Read-only sin OAuth:** suscribir la URL "Secret address in iCal format" del calendario
   (Google Calendar web → Settings → Integrate calendar) en GNOME Calendar (Add calendar
   from URL). Sirve para *ver*, no crear.
3. **Full read/write bypass:** crear un OAuth client **propio** en un proyecto GCP dentro
   de la org `tu-org-corporativa` con consent **Internal** (no requiere aprobación de admin) y
   usarlo desde un script/CLI (gcalcli o REST API) → permite crear eventos + links de Meet.
   Sujeto a que la org permita crear proyectos GCP.

---

## 6. Notificaciones

- Waybar **no** muestra notificaciones de apps (es una barra). El daemon es **mako**.
- Recordatorios de calendario: `evolution-alarm-notify` → libnotify → **popup de mako**.
- mako no tiene contador en waybar (eso sería swaync). 

---

## 7. Checklist al terminar un cambio
- [ ] Editado en el **repo**, no en `/etc`.
- [ ] `sway -C -c etc/sway/config` sin errores.
- [ ] `bash -n install.sh` si tocaste el instalador.
- [ ] Si agregaste un archivo nuevo en `etc/`/`usr/`, agregá su `install_system ...` en `install.sh`.
- [ ] Deploy (`sudo ./install.sh`) + `swaymsg reload`.
- [ ] Verificado contra la config **viva** (`swaymsg -t get_config`).
- [ ] `git add -A && git commit && git push`.
