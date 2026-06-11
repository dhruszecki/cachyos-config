# CLAUDE.md — cachyos-config

Guía para Claude (y para mí) al modificar la configuración del sistema. Leer esto
**antes** de tocar cualquier config de Sway/waybar/sistema.

> 📐 **Patrones y gotchas concretos al editar la config de Sway** (cómo diagnosticar el
> swaynag de "errors in your config file", el `;` en `exec`, binds de workspace sin duplicar,
> dependencias de binarios como swaybg, reparto por-usuario): **`docs/sway-patterns.md`** —
> leerlo antes de tocar binds, `exec` o el wallpaper.

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
- `$mod+Shift+g` → Meet → **workspace propio con tag `6:Meet`** (`focus-or-launch-app`, no
  scratchpad; ver más abajo). `$mod+6` también pisa el bind global para nombrar el ws.
- Launchers en fuzzel: `~/.local/share/applications/{slack,whatsapp,meet,calendar,gmail}-pwa.desktop`

### Focus-or-launch en workspace propio (`focus-or-launch-app`)
Contraparte de `toggle-scratch-app` para apps que quieren **workspace propio** (vía `assign`),
no scratchpad. Helper global `usr/local/bin/focus-or-launch-app <regex_app_id> <comando...>`:
si ya existe una ventana → la **enfoca** (salta a su workspace, sin duplicar); si no existe →
la **lanza** (el `assign` la ubica). Usado por Meet (`work-pwa.conf`) y las Google Apps
(`google-apps.conf`). Patrón completo para una app con ws propio nombrado:
```
set $ws_x "N:Nombre"
assign [app_id="<regex>"] number $ws_x      # ← number es CLAVE (ver gotcha abajo)
for_window [app_id="<regex>"] layout tabbed  # varios docs → pestañas
bindsym $mod+N workspace number $ws_x         # pisa el bind numérico global, nombra el ws
bindsym $mod+Shift+X exec /usr/local/bin/focus-or-launch-app '<regex>' <comando>
```

> ⚠️ **GOTCHA workspace duplicado (`N` pelado + `N:Nombre`).** `assign [...] $ws_x` (sin la
> palabra `number`) matchea por **nombre exacto**: si ya existe un workspace `"N"` pelado
> (leftover, o creado por el bind numérico global antes de que cargara el override), sway
> crea un `"N:Nombre"` **aparte** → terminás con dos workspaces num=N. **Fix: `assign [...]
> number $ws_x`** — matchea por número, así entra al `"N"` existente o crea `"N:Nombre"` si
> no hay ninguno. Los binds (`workspace number $ws_x`) ya usan `number`; el que faltaba era
> el `assign`. Mismo principio en `move container to workspace number`.

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
`include /etc/sway/config.d/*`). Modelo: cada app tiene su **workspace propio con tag**
(`assign number` + `focus-or-launch-app` + `layout tabbed`), NO scratchpad (cambió desde
el modelo viejo de toggle). Launchers en `usr/share/applications/`.
- `$mod+Shift+d` → Drive (`7:Drive`) · `$mod+Shift+o` → Docs (`8:Docs`) ·
  `$mod+Shift+t` → Sheets (`9:Sheets`) · `$mod+Shift+p` → Slides (`10:Slides`).
  (Sheets quedó en `t` porque `$mod+Shift+s` ya es swaylock.)
- `$mod+7..0` pisan los binds numéricos globales para **nombrar** los workspaces con su tag
  (se cargan después en `config.d/*`). Mismo patrón `assign number` del helper de arriba.
- Cuenta por `/u/0/` en la URL = la default del perfil de Brave de cada usuario.
- Docs/Sheets/Slides comparten host (`docs.google.com`) → se distinguen por el **path**
  del app_id (`__document`, `__spreadsheets`, `__presentation`).

> ⚠️ **GOTCHA waybar: `{name}` STRIPPEA el prefijo `N:`.** El módulo `sway/workspaces` con
> `"format": "{name}"` muestra solo `Meet`/`Sheets` (sin el número), porque `{name}` se come
> el `N:` que sway usa para numerar. Para que el tag muestre el número usar
> **`"format": "{value}"`** (`{value}` = nombre crudo tal cual, ej. `6:Meet`). En
> `etc/xdg/waybar/config.jsonc`.

> Slides no editaba en Brave (cartel "Tu navegador no permite editar presentaciones"):
> era la extensión **User-Agent Switcher** (UA no reconocido → solo-lectura). Sin esa
> extensión (o excluyendo `google.com`), Slides edita normal. No es Shields ni cookies.

> ⚠️ **LÍMITE Chromium: ctrl+click NO abre el doc en otra ventana PWA.** En la ventana de
> Docs (sea `--app=URL` o PWA instalada con `--app-id`), **click normal** navega el doc en
> la *misma* ventana; **ctrl+click** ("abrir en pestaña nueva") se deriva a una ventana/solapa
> de **Brave normal** (`app_id=brave-browser`) → no cae en `8:Docs`. Causa: una ventana de app
> no puede hospedar pestañas y **Google Docs no declara modo "tabbed"** en su manifest, así que
> el flag `--enable-features=DesktopPWAsTabStrip` **no** le da tira de pestañas. Probado con las
> 3 variantes (`--app=URL`, `--app-id`, `--app-id`+tab-strip): todas igual. **No es config de
> Sway ni arreglable desde acá.** Convivencia: con ctrl+click, si no hay otra ventana de Brave
> abierta el doc cae en una ventana nueva en el workspace enfocado (sirve); si la hay, se va de
> solapa a esa. Para varios docs a la vez, la única vía sería un bind que SIEMPRE lance otra
> ventana de Docs (mismo app_id → Sway la tabea en `8:Docs`), pero abre en el home (un click
> extra). Se descartó: quedó el modelo simple (`--app=URL`, una ventana = un doc por navegación).

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

## 7. Auto-actualización diaria (systemd user timer)

Mecanismo desatendido para mantener la config al día sin acordarse de correr `cachyos-sync`.
Una vez por día chequea `origin`, y **si hay cambios** los baja, los instala, recarga Sway y
**avisa por mako**. Si algo falla, manda una notificación crítica y corta (no deja a medias).

Piezas (todas en el repo):
- `usr/local/bin/config-autoupdate` (global): el worker. Corre **como el usuario** (no root)
  para que `notify-send`/mako funcionen. Flujo: `git fetch` → si `HEAD == @{u}` sale silencioso
  → si hay commits nuevos: `pull --ff-only` + `sudo install.sh` + `swaymsg reload` + notif de
  éxito con el `git log` corto. Cada paso que falla → `notify-send -u critical` + `exit 1`.
- `etc/sudoers.d/config-autoupdate` (global, 0440): NOPASSWD **acotado** al `install.sh` de
  cada clone (`~/cachyos-config`). Es lo que deja al timer instalar sin prompt. **No es
  escalada** (estos usuarios ya tienen sudo); si movés el repo de `~/cachyos-config` hay que
  actualizar el path acá. `install.sh` valida con `visudo -cf` antes de copiar.
- `home/.config/systemd/user/config-autoupdate.{service,timer}` (por-usuario): `OnCalendar=daily`,
  `Persistent=true` (recupera disparos perdidos si la máquina estaba apagada),
  `RandomizedDelaySec=15min`. `install.sh` los copia y hace `systemctl --user enable --now`.

> ⚠️ El service corre **en tu sesión**: la notif necesita una sesión activa con mako. Por eso
> **no** se usa `enable-linger`; si no estás logueado el chequeo no corre, pero `Persistent=true`
> lo dispara tras el próximo login. El script invoca `install.sh` con **ruta absoluta** porque
> el sudoers matchea por path exacto (si no, sudo pediría password y el job fallaría).

Operación / debug:
```bash
systemctl --user list-timers | grep config-autoupdate   # próximo disparo
systemctl --user start config-autoupdate.service         # forzar un chequeo ahora
journalctl --user -u config-autoupdate -e                # ver qué pasó (stdout/stderr)
```
Diferencia con `cachyos-sync`: ese es el equivalente **manual/interactivo** (pide sudo);
`config-autoupdate` es la versión automática diaria con notificación.

---

## 8. Notificaciones

- Waybar **no** muestra notificaciones de apps (es una barra). El daemon es **mako**.
- Recordatorios de calendario: `evolution-alarm-notify` → libnotify → **popup de mako**.
- El auto-update diario (sección 7) también avisa por mako (`notify-send`).
- mako no tiene contador en waybar (eso sería swaync). 

---

## 9. Checklist al terminar un cambio
- [ ] Editado en el **repo**, no en `/etc`.
- [ ] `sway -C -c etc/sway/config` sin errores.
- [ ] `bash -n install.sh` si tocaste el instalador.
- [ ] Si agregaste un archivo nuevo en `etc/`/`usr/`, agregá su `install_system ...` en `install.sh`.
- [ ] Si agregaste una unit de systemd (`home/.config/systemd/user/`) o un sudoers (`etc/sudoers.d/`),
      agregá su `install_user`/`install_system` + el `enable`/`visudo -cf` en `install.sh`.
- [ ] Deploy (`sudo ./install.sh`) + `swaymsg reload`.
- [ ] Verificado contra la config **viva** (`swaymsg -t get_config`).
- [ ] `git add -A && git commit && git push`.
