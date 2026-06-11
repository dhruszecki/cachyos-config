# Patrones y gotchas de la config de Sway

Referenciado desde `CLAUDE.md`. Reglas aprendidas a fuerza de romper cosas; **seguirlas al
modificar `etc/sway/config`, `etc/sway/config.d/*` o los `~/.config/sway/config.d/*.conf`**.
Vive separado para no inflar CLAUDE.md.

---

## 1. Diagnosticar el swaynag "errors in your config file" al arrancar

La barra amarilla/roja arriba al login es `swaynag` reportando errores de la carga.

- **`sway -C -c /etc/sway/config` valida SOLO sintaxis.** NO detecta errores de *runtime*
  (binarios faltantes, exec mal formado, etc.). Puede salir limpio (exit 0, sin output) y
  aun así haber warnings al boot. **No alcanza para validar estos casos.**
- **Leer el texto del warning sin reiniciar:** `pgrep -a swaynag` muestra el mensaje corto en
  sus args; el detalle (nº de línea + texto, ej. `overwriting binding Mod4+7`) está en la
  barra (botón de toggle de detalles).
- **Reproducir los errores REALES de la carga** (los que `sway -C` no ve): arrancar un sway
  *headless* que recorre la ruta real de carga sin tocar tu pantalla:
  ```bash
  cd /tmp
  timeout 4 env -u WAYLAND_DISPLAY WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
      SWAYSOCK=/tmp/x.sock sway -c /etc/sway/config 2>/tmp/x.log
  grep -E '\[ERROR\] \[sway' /tmp/x.log
  ```
  > ⚠️ **El sway headless EJECUTA las líneas `exec`/`exec_always`.** En la práctica corrió
  > `pkill waybar` y mató la waybar real de la sesión. Reiniciá a mano lo que se haya tocado:
  > `XDG_RUNTIME_DIR=/run/user/$(id -u) setsid waybar >/dev/null 2>&1 &`.

---

## 2. `;` en `exec`/`exec_always` → SIEMPRE comillar el comando de shell

Sway parte los comandos del config en `;` **antes** de despacharlos. Sin comillas, lo que va
después del `;` se interpreta como un comando *de Sway*, no del shell:

```
exec_always --no-startup-id pkill waybar; waybar      # ❌ Sway corre `pkill waybar` y luego
                                                       #    intenta `waybar` como comando suyo
                                                       #    → "Unknown/invalid command 'waybar'"
exec_always --no-startup-id 'pkill waybar; waybar'    # ✅ comillas → el `;` va al shell
```

Aplica a cualquier `exec` con varios comandos encadenados (`;`, y por las dudas envolvé también
si usás `&&`/`||`). Verificable con el truco headless de arriba.

---

## 3. Binds de workspace con tag → un solo definidor (en config.d), nunca duplicar

Cada `bindsym` que **redefine** uno ya existente dispara `overwriting binding Mod4+N` → swaynag.
El config principal cargaba `$mod+1..0` y los config.d los pisaban para nombrarlos con tag.

**Patrón actual (no romperlo):**
- El **config principal** (`etc/sway/config`) define SOLO `$mod+1..5` (+ Shift). **NO** define
  `$mod+6..0`.
- Los workspaces con tag se definen en **config.d, único lugar**:
  - `$mod+7..0` → `etc/sway/config.d/google-apps.conf` (GLOBAL, todos los usuarios)
  - `$mod+6` → `~/.config/sway/config.d/work-pwa.conf` (daro-m, "6:Meet") /
    `~/.config/sway/config.d/personal.conf` (daro, "6" normal)
- **Al agregar un workspace nuevo con tag:** definí su `bindsym $mod+N` SOLO en su config.d (con
  `assign [...] number $ws_x` + `bindsym $mod+N workspace number $ws_x`), y asegurate de que el
  principal no lo bindee. Así queda un único definidor → sin warning.

(El `number` en `assign`/`workspace number` sigue siendo clave por el gotcha del workspace
duplicado; ver CLAUDE.md.)

---

## 4. Dependencias de binarios que solo fallan en runtime

- `output * bg <img> fill` necesita el binario **`swaybg`** instalado (está en `PACKAGES` de
  `install.sh`). Sin él: error al boot + sin wallpaper (no lo agarra `sway -C`).
- Cualquier binario lanzado por `exec`/`for_window`/`bg` debe estar en un paquete de
  `install.sh`, o tirará error de runtime.

### Wallpaper
- Globales ya instalados: `/usr/share/wallpapers/cachyos-wallpapers/`. Actual:
  `Cachy_Topography.jpg` (violeta/malva, va con el theme de terminal **Catppuccin Mocha**,
  `background=1e1e2e` en `foot.ini`).
- Cambio en vivo (sin sudo, no persiste): `swaymsg 'output * bg <ruta> fill'`. Para persistir,
  editar `etc/sway/config:~41` + `sudo ./install.sh`.

---

## 5. Reparto por-usuario (guards en install.sh)

- `~/.config/sway/config.d/work-pwa.conf` → **solo daro-m** (apps de trabajo + `$mod+6` Meet).
- `~/.config/sway/config.d/personal.conf` → **solo daro** (`$mod+6` workspace normal).
- `etc/sway/config.d/google-apps.conf` → **global** (todos).
- Los guards son `if [ "$TARGET_USER" = "..." ]` en `install.sh`. Si agregás config por-usuario,
  metelo en su `config.d` + guard, no en el principal.
