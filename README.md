# cachyos-config

Configuración del sistema para CachyOS con sway. Diseñada para ser compartida entre múltiples usuarios en la misma máquina y reproducible en instalaciones nuevas.

## Estructura

```
cachyos-config/
├── etc/
│   ├── sway/config                  → /etc/sway/config
│   └── xdg/waybar/
│       ├── config.jsonc             → /etc/xdg/waybar/config.jsonc
│       └── style.css                → /etc/xdg/waybar/style.css
├── usr/local/bin/
│   └── sway-session-switch          → /usr/local/bin/sway-session-switch
├── home/.config/sway/
│   └── show-keybindings.sh          → ~/.config/sway/show-keybindings.sh
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

## Agregar nueva herramienta al repo

1. Copiar los archivos de config al repo siguiendo la estructura del filesystem:
   - Config en `/etc/` → `etc/...`
   - Config en `~/.config/` → `home/.config/...`
   - Scripts en `/usr/local/bin/` → `usr/local/bin/...`
2. Agregar las líneas de instalación correspondientes en `install.sh`
3. Agregar los paquetes necesarios al array `PACKAGES` en `install.sh`
4. Hacer commit

## Paquetes instalados por `install.sh`

`sway` `swaylock` `swayidle` `swaynag` `waybar` `mako` `fuzzel` `foot` `wl-clipboard` `cliphist` `wob` `pamixer` `brightnessctl` `playerctl` `grim` `slurp` `autotiling` `kanshi` `blueman` `jq`
