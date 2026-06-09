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
- `daro-m` = trabajo

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

> ⚠️ **`get_config` NO expande los `include`**: muestra el archivo top-level con las
> líneas `include` literales, no el contenido de `work-pwa.conf` ni de `config.d/*`. Para
> validar binds de archivos incluidos usá `sway -C -c /etc/sway/config` (procesa includes
> y reporta errores) o probá el bind a mano. No concluyas "no está cargado" solo porque no
> aparece en `get_config`.

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

### Reparto personal vs trabajo
- **Personal** → GNOME Calendar nativo (`$mod+c`, liviano). Funciona vía GOA sin restricciones.
- **Trabajo (cuenta corporativa de Google Workspace)** → **PWAs de Brave** (Calendar + Gmail),
  porque el Workspace bloquea GOA (ver Gotcha 2). Las PWAs usan el login first-party de Google
  → sin bloqueo, con creación de eventos + Meet. Más pesadas (Chromium) pero confinadas al scratchpad.

### Toggle genérico en scratchpad (`toggle-scratch-app`)
Helper global `usr/local/bin/toggle-scratch-app <regex_app_id> <comando...>`: visible→oculta
(`move scratchpad`), oculta→muestra (`scratchpad show`), no existe→lanza. Robusto: funciona
aunque la ventana ya estuviera abierta. Combinar con `for_window [app_id="<misma_regex>"]
move scratchpad, scratchpad show, resize ..., move position center` (da flotante/tamaño/centro
al crearse). Usado por las PWAs de trabajo en `~/.config/sway/config.d/work-pwa.conf`
(solo daro-m; versionado en el repo bajo el guard `daro-m` de `install.sh`). Layout actual:
- `$mod+Shift+m` → Slack (scratchpad)      ·  `$mod+Shift+w` → WhatsApp (scratchpad)
- `$mod+Shift+a` → Calendar trabajo (scratchpad)  ·  `$mod+Shift+i` → Gmail trabajo (scratchpad)
- `$mod+Shift+g` → Meet → **workspace 6** (assign, no flotante)
- Launchers en fuzzel: `~/.local/share/applications/{slack,whatsapp,meet,calendar,gmail}-pwa.desktop`

> ⚠️ **GOTCHA Brave/Chromium en Wayland: `--class` se IGNORA.** Todas las ventanas normales
> quedan con app_id `brave-browser`. Las ventanas `--app=URL` reciben un app_id autogenerado
> de la URL: `brave-<host>...-Default` (ej. Slack = `brave-app.slack.com__client_-Default`).
> Por eso **no sirve `[app_id="slack-pwa"]`** — hay que matchear por regex del host:
> `[app_id="^brave-calendar\.google\.com"]`. (Los `assign [app_id="slack-pwa"]` viejos en
> work-pwa.conf están rotos por esto.) Verificar el app_id real con
> `swaymsg -t get_tree | jq -r '..|objects|.app_id?//empty'`.

> Las PWAs abren en el **perfil default de Brave**. Si la cuenta de trabajo no es la default de
> Google en ese perfil, usar `/u/N/` en la URL o un `--profile-directory` dedicado.

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

**Gotcha 2 — cuenta de trabajo corporativa bloqueada por política de Workspace.** Agregar
la cuenta corporativa de Google vía GOA tira `Error 400: access_not_configured` ("Access
blocked: admin needs to review GNOME"). Es política del Workspace corporativo (apps de
terceros no aprobadas), **no** un bug de config. La cuenta **personal** de Google sí
funciona normal. Alternativas para la cuenta de trabajo:
1. Pedir al admin del Workspace que apruebe la app GNOME (botón "Request Access").
2. **Read-only sin OAuth:** suscribir la URL "Secret address in iCal format" del calendario
   (Google Calendar web → Settings → Integrate calendar) en GNOME Calendar (Add calendar
   from URL). Sirve para *ver*, no crear.
3. **Full read/write bypass:** crear un OAuth client **propio** en un proyecto GCP dentro
   de la org corporativa con consent **Internal** (no requiere aprobación de admin) y
   usarlo desde un script/CLI (gcalcli o REST API) → permite crear eventos + links de Meet.
   Sujeto a que la org permita crear proyectos GCP.

### Apps de Google Workspace (Drive/Docs/Sheets/Slides) — globales
A diferencia de las apps de trabajo (por-usuario, scratchpad), estas son **globales**
(todos los usuarios) y viven en `etc/sway/config.d/google-apps.conf` (cargado por
`include /etc/sway/config.d/*`). Usan **toggle por-app** (`toggle-scratch-app`, flotante
y centrado, misma tecla muestra/oculta — sin cycling). Launchers en `usr/share/applications/`.
- `$mod+Shift+d` → Drive · `$mod+Shift+o` → Docs · `$mod+Shift+t` → Sheets · `$mod+Shift+p` → Slides
  (Sheets quedó en `t` porque `$mod+Shift+s` ya es swaylock).
- Cuenta por `/u/0/` en la URL = la default del perfil de Brave de cada usuario.
- Docs/Sheets/Slides comparten host (`docs.google.com`) → se distinguen por el **path**
  del app_id (`__document`, `__spreadsheets`, `__presentation`).
> Slides no editaba en Brave (cartel "Tu navegador no permite editar presentaciones"):
> era la extensión **User-Agent Switcher** (UA no reconocido → solo-lectura). Sin esa
> extensión (o excluyendo `google.com`), Slides edita normal. No es Shields ni cookies.

### Visor de keybindings y etiquetas `# kb:`
`$mod+Shift+/` → `~/.config/sway/show-keybindings.sh` lista todos los binds en fuzzel.
- **NO usa `swaymsg -t get_config`** (no expande includes → se comía los binds de
  `config.d/*` y `work-pwa.conf`). Lee los archivos directo: config principal +
  `/etc/sway/config.d/*` + `~/.config/sway/config.d/*.conf`, y expande las variables
  `set $x` (armado solo desde las líneas `set`).
- **Etiqueta amigable:** una línea `# kb: <texto>` justo **antes** de un `bindsym` se
  muestra como descripción en vez del comando crudo (ej. `# kb: Google Drive`). Sin esa
  línea, muestra el comando. Es seguro: el comentario va en su propia línea, no toca el `exec`.

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
