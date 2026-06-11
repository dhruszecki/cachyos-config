# cachyos-config

Configuración del sistema para CachyOS con sway. Diseñada para ser compartida entre múltiples usuarios en la misma máquina y reproducible en instalaciones nuevas.

## Estructura

```
cachyos-config/
├── etc/
│   ├── sway/config                  → /etc/sway/config
│   ├── sudoers.d/config-autoupdate  → /etc/sudoers.d/config-autoupdate
│   └── xdg/waybar/
│       ├── config.jsonc             → /etc/xdg/waybar/config.jsonc
│       └── style.css                → /etc/xdg/waybar/style.css
├── usr/local/bin/
│   ├── sway-session-switch          → /usr/local/bin/sway-session-switch
│   ├── cachyos-sync                 → /usr/local/bin/cachyos-sync       (sync manual)
│   └── config-autoupdate            → /usr/local/bin/config-autoupdate  (sync diario automático)
├── bootstrap.sh                     (setup compartido /opt + grupo + /etc/skel)
├── home/.config/systemd/user/
│   ├── config-autoupdate.service    → ~/.config/systemd/user/config-autoupdate.service
│   └── config-autoupdate.timer      → ~/.config/systemd/user/config-autoupdate.timer
├── home/.config/sway/
│   └── show-keybindings.sh          → ~/.config/sway/show-keybindings.sh
├── home/.config/Code - OSS/User/
│   ├── settings.json                → ~/.config/Code - OSS/User/settings.json
│   ├── keybindings.json             → ~/.config/Code - OSS/User/keybindings.json
│   └── snippets/markdown.json       → ~/.config/Code - OSS/User/snippets/markdown.json
└── install.sh
```

Los archivos bajo `etc/` y `usr/` son **globales**: aplican a todos los usuarios del sistema. Los de `home/` van al directorio del usuario que ejecuta el instalador.

## Instalación

```bash
git clone https://github.com/TU_USUARIO/cachyos-config.git
cd cachyos-config
sudo ./install.sh
```

El script instala los paquetes necesarios con `pacman` y copia los archivos a sus destinos.

> **Multi-usuario:** las configs de sistema (`etc/`, `usr/`) son globales. Las de `home/`: las de sway se copian; las de **Code OSS se symlinkean** al clon compartido del repo (ver abajo).

### Setup compartido (multi-usuario + usuarios nuevos)

Para compartir la config entre todos los usuarios de la máquina (y heredarla en usuarios nuevos), se usa un clon compartido en `/opt/cachyos-config` y el script `bootstrap.sh`:

```bash
git clone https://github.com/dhruszecki/cachyos-config.git
cd cachyos-config
sudo bash bootstrap.sh
```

`bootstrap.sh` (una sola vez por máquina):

1. Crea el grupo `confshare` y agrega a los usuarios humanos existentes.
2. Clona el repo en `/opt/cachyos-config` (legible por todos, escribible por el grupo, `git` compartido).
3. Corre `install.sh` para cada usuario existente (paquetes + symlinks de Code OSS + extensiones).
4. Deja symlinks de Code OSS en `/etc/skel/` → **los usuarios nuevos los heredan automáticamente**.

**Usuario nuevo que quiera editar/sincronizar** la config compartida:

```bash
sudo usermod -aG confshare <usuario>
```

(Sólo para leer/usar la config no hace falta: la heredan de `/etc/skel`.)

### Sincronizar cambios

Cualquier usuario del grupo, desde cualquier lado:

```bash
cachyos-sync
```

Hace `git pull` del clon en `/opt` (los symlinks de Code OSS se actualizan solos) y re-aplica las configs de sistema vía `sudo install.sh`.

### Auto-actualización diaria (automática)

Además del `cachyos-sync` manual, hay un **timer de systemd** que una vez por día chequea si hay cambios en el repo, y **si los hay** los baja, los instala, recarga Sway y **avisa por notificación** (mako). Si algo falla, manda una notificación crítica para que intervengas.

Lo instala y habilita el propio `install.sh` (no hay que hacer nada extra). Piezas:

- `usr/local/bin/config-autoupdate` — el worker. Corre **como tu usuario** (no root) para que la notificación llegue a tu mako. Flujo: `git fetch` → si no hay cambios sale en silencio → si los hay: `pull --ff-only` + `sudo install.sh` + `swaymsg reload` + notificación con el changelog.
- `etc/sudoers.d/config-autoupdate` — regla `NOPASSWD` **acotada** al `install.sh` del repo, para que el job desatendido pueda instalar sin pedir contraseña. No es escalada de privilegios (ya tenés `sudo` interactivo); sólo saca el prompt.
- `home/.config/systemd/user/config-autoupdate.{service,timer}` — `OnCalendar=daily`, `Persistent=true` (recupera el chequeo si la máquina estaba apagada) y un jitter aleatorio de 15 min.

> El service corre **en tu sesión**: la notificación necesita una sesión con mako activa. Si no estás logueado el chequeo no corre, pero `Persistent=true` lo dispara tras el próximo login. Por eso **no** se usa `enable-linger`.

**Comandos útiles:**

```bash
# Ver cuándo es el próximo chequeo
systemctl --user list-timers | grep config-autoupdate

# Forzar un chequeo ahora (no espera al horario)
systemctl --user start config-autoupdate.service

# Ver qué hizo / por qué falló
journalctl --user -u config-autoupdate -e

# Pausar / reanudar la auto-actualización
systemctl --user disable --now config-autoupdate.timer
systemctl --user enable  --now config-autoupdate.timer
```

## Sway

### Autostart

| Proceso | Función |
|---|---|
| `swayidle` | Bloquea a los 5 min, apaga pantalla a los 10 min, bloquea antes de suspender |
| `waybar` | Barra de estado (se reinicia en cada reload del config) |
| `mako` | Notificaciones |
| `autotiling` | Alterna split H/V automáticamente según proporción de ventana |
| `kanshi` | Perfiles de monitor automáticos |
| `blueman-applet` | Applet de Bluetooth en el tray |
| `cliphist` | Historial de portapapeles |
| `wob` | Barra visual de volumen y brillo |

### Apariencia

- Gaps internos: 8px / externos: 4px
- `smart_gaps`: se desactivan cuando hay una sola ventana
- `smart_borders`: sin bordes en ventana única
- Borde: 2px

### Layouts de teclado

Dos layouts activos: `us` (inglés) y `latam` (español latinoamericano).

| Shortcut | Acción |
|---|---|
| `Alt+Shift` | Alterna entre layouts |
| `Super+i` | Alterna entre layouts |

### PWA (Brave)

Las apps web corren como PWAs en Brave y se asignan a workspaces fijos.

| App | Workspace | Shortcut |
|---|---|---|
| Slack | 4 | `Super+Shift+m` |
| WhatsApp | 5 | `Super+Shift+w` |
| Google Meet | 6 | `Super+Shift+g` |

Para agregar una nueva PWA:
1. Lanzarla con `brave --app=URL --class=nombre --name=nombre`
2. Agregar `assign [app_id="nombre"] workspace number N` en el config
3. Agregar el `bindsym` correspondiente

### Keybindings

> `$mod` = tecla Super (Windows)

#### Básicos

| Shortcut | Acción |
|---|---|
| `Super+Return` | Terminal (foot) |
| `Super+d` | Lanzador (fuzzel) |
| `Super+Shift+q` | Cerrar ventana |
| `Super+Shift+b` | Navegador (brave) |
| `Super+Shift+v` | Historial de portapapeles |
| `Super+Shift+/` | Ver todos los keybindings |
| `Super+Shift+c` | Recargar config de sway |
| `Super+Shift+e` | Salir de sway (con confirmación) |

#### Foco y movimiento

| Shortcut | Acción |
|---|---|
| `Super+h/j/k/l` | Mover foco (vim-style) |
| `Super+←/↓/↑/→` | Mover foco (flechas) |
| `Super+Shift+h/j/k/l` | Mover ventana |
| `Super+Shift+←/↓/↑/→` | Mover ventana (flechas) |

#### Workspaces

| Shortcut | Acción |
|---|---|
| `Super+1…0` | Ir al workspace N |
| `Super+Shift+1…0` | Mover ventana al workspace N |

#### Layout

| Shortcut | Acción |
|---|---|
| `Super+b` | Split horizontal |
| `Super+v` | Split vertical |
| `Super+s` | Layout stacking |
| `Super+w` | Layout tabbed |
| `Super+e` | Toggle split |
| `Super+f` | Pantalla completa |
| `Super+Shift+Space` | Toggle floating |
| `Super+Space` | Alternar foco tiling/floating |
| `Super+a` | Foco al contenedor padre |
| `Super+r` | Modo resize |
| `Super+Shift+-` | Enviar al scratchpad |
| `Super+-` | Mostrar/ocultar scratchpad |

#### Multimedia y sistema

| Shortcut | Acción |
|---|---|
| `XF86AudioRaiseVolume` | Volumen +5% (con barra visual) |
| `XF86AudioLowerVolume` | Volumen -5% (con barra visual) |
| `XF86AudioMute` | Silenciar/activar audio |
| `XF86AudioMicMute` | Silenciar/activar micrófono |
| `XF86AudioPlay/Pause/Prev/Next/Stop` | Control de reproducción |
| `XF86MonBrightnessUp/Down` | Brillo ±5% (con barra visual) |
| `Print` | Screenshot de región → portapapeles |
| `Shift+Print` | Screenshot completa → ~/Pictures/ |

#### Sesiones (multi-usuario)

| Shortcut | Acción |
|---|---|
| `Super+Shift+s` | Bloquear sesión actual (swaylock) |
| `Super+Ctrl+Shift+s` | Cambiar de sesión (fuzzel) |
| `Super+Ctrl+Shift+e` | Cerrar una sesión activa (fuzzel) |

### Gestión de sesiones multi-usuario

El sistema permite tener múltiples sesiones de sway abiertas en paralelo (una por usuario) y cambiar entre ellas sin cerrar ninguna.

**Cambiar de sesión** (`Super+Ctrl+Shift+s`):
1. Se abre fuzzel mostrando las sesiones activas con usuario, VT y tipo
2. Si hay otra sesión disponible, se bloquea la actual y se salta directamente via `loginctl activate` — sin pasar por el greeter de SDDM, una sola contraseña al volver
3. Si no hay otra sesión, ofrece abrir el greeter de SDDM para iniciar una nueva

**Importante**: para volver a una sesión existente siempre usar `Super+Ctrl+Shift+s`, no iniciar sesión de nuevo desde SDDM (eso crea una sesión nueva y se pierden las ventanas abiertas).

## Waybar

Config en `/etc/xdg/waybar/` — global para todos los usuarios.

**Módulos activos** (de izquierda a derecha):
- Izquierda: workspaces, modo sway
- Centro: título de ventana activa
- Derecha: usuario actual, layout de teclado, bluetooth, audio, red, CPU, memoria, temperatura, tray, reloj

**Click en el nombre de usuario** → abre el switcher de sesiones (`sway-session-switch`).

## Code OSS (Markdown / Marp)

Editor configurado para escribir Markdown y armar presentaciones con [Marp](https://marp.app/).

- **Tema y fuente son globales** (los mismos que para programar). La comodidad de escritura (sin números de línea, word-wrap, line-height 1.8, sin minimapa, padding, etc.) está scopeada a `[markdown]`, así que **sólo afecta archivos `.md`** y no molesta al editar código.
- Para modo distracción-cero: **Zen Mode** con `ctrl+shift+z`.
- Extensiones que instala el script: `marp-team.marp-vscode` y `yzhang.markdown-all-in-one`.

### Keybindings (sólo en `.md` salvo aclaración)

| Shortcut | Acción |
|---|---|
| `ctrl+shift+v` | Preview de Markdown al costado |
| `ctrl+shift+m` | Preview de Marp |
| `ctrl+shift+e` | Exportar con Marp (PDF/PPTX/HTML) |
| `ctrl+shift+t` | Insertar tabla de contenidos |
| `ctrl+shift+c` | Marcar/desmarcar tarea de la lista |
| `ctrl+enter` | Insertar separador de slide (`---`) |
| `ctrl+shift+b` | Mostrar/ocultar sidebar (global) |
| `ctrl+shift+z` | Zen Mode (global) |
| `` ctrl+` `` | Mostrar/ocultar terminal (global) |

### Snippets de Marp

Escribí el prefijo y `Tab`:

| Prefijo | Qué inserta |
|---|---|
| `marp-init` | Frontmatter Marp completo (tema, paginado, header/footer, estilo) + slide de portada |
| `marp-front` | Frontmatter mínimo |
| `slide-lead` | Slide con título centrado (clase `lead`) |
| `slide-2col` | Slide a dos columnas |
| `slide-bg` | Slide con imagen de fondo |
| `slide-split` | Slide imagen + texto (split) |
| `slide-section` | Slide separador de sección |
| `slide-end` | Slide de cierre |
| `marp-img` | Imagen con tamaño (`w:`/`h:`/`fit`) |
| `marp-dir` | Directiva de slide (`_class`, `_backgroundColor`, …) |
| `marp-table` | Tabla simple |

## Agregar nueva herramienta al repo

1. Copiar los archivos de config al repo siguiendo la estructura del filesystem:
   - Config en `/etc/` → `etc/...`
   - Config en `~/.config/` → `home/.config/...`
   - Scripts en `/usr/local/bin/` → `usr/local/bin/...`
2. Agregar las líneas de instalación correspondientes en `install.sh`
3. Agregar los paquetes necesarios al array `PACKAGES` en `install.sh`
4. Hacer commit

## Paquetes instalados por `install.sh`

`sway` `swaylock` `swayidle` `waybar` `mako` `fuzzel` `foot` `wl-clipboard` `cliphist` `wob` `pamixer` `brightnessctl` `playerctl` `grim` `slurp` `autotiling` `kanshi` `blueman` `code` `jq`
