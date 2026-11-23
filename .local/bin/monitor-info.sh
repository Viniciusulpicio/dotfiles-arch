#!/usr/bin/env bash
# ==============================================================================
# monitor-info.sh — Detecção dinâmica do monitor ativo (Wayland/Mutter, GDK, X11)
# Uso:
#   eval "$(~/.local/bin/monitor-info.sh)"
#   ~/.local/bin/monitor-info.sh --phys-res   # ex: 1920x1080
#   ~/.local/bin/monitor-info.sh --log-res    # ex: 1536x864
# ==============================================================================

detect_monitor() {
    python3 - << 'PYEOF' 2>/dev/null
import sys

phys_w, phys_h = 0, 0
log_w, log_h = 0, 0
mon_x, mon_y = 0, 0
scale = 1.0
connector = "unknown"

# 1. Tentar obter posição do cursor e escala XWayland/GDK para escolher o monitor em uso
cursor_x, cursor_y = None, None
gdk_scale = 1
try:
    import gi
    gi.require_version("Gdk", "3.0")
    from gi.repository import Gdk
    display = Gdk.Display.get_default()
    if display:
        seat = display.get_default_seat()
        if seat and seat.get_pointer():
            _, cx, cy = seat.get_pointer().get_position()
            cursor_x, cursor_y = cx, cy
            mon_at_ptr = display.get_monitor_at_point(cx, cy)
            if mon_at_ptr:
                gdk_scale = mon_at_ptr.get_scale_factor() or 1
        else:
            pmon = display.get_primary_monitor() or display.get_monitor(0)
            if pmon:
                gdk_scale = pmon.get_scale_factor() or 1
except Exception:
    pass

# 2. Consultar GNOME Mutter DisplayConfig via DBus (exato em Wayland + escala fracionária)
try:
    from gi.repository import Gio
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    res = bus.call_sync(
        "org.gnome.Mutter.DisplayConfig",
        "/org/gnome/Mutter/DisplayConfig",
        "org.gnome.Mutter.DisplayConfig",
        "GetCurrentState",
        None,
        None,
        Gio.DBusCallFlags.NONE,
        1500,
        None,
    )
    serial, monitors, logical_monitors, _ = res.unpack()

    # Mapear conector -> (width, height) do modo físico ativo
    active_modes = {}
    for m in monitors:
        spec, modes, _ = m
        conn = spec[0]
        for mode in modes:
            _, w, h, rate, pref_scale, _, mode_props = mode
            if mode_props.get("is-current"):
                active_modes[conn] = (int(w), int(h))
                break

    chosen_lm = None
    primary_lm = None
    for lm in logical_monitors:
        lx, ly, lscale, ltransform, lprimary, linked, _ = lm
        if lprimary:
            primary_lm = lm
        if cursor_x is not None and cursor_y is not None and linked:
            conn = linked[0][0]
            pw, ph = active_modes.get(conn, (1920, 1080))
            lw = int(round(pw / lscale))
            lh = int(round(ph / lscale))
            if lx <= cursor_x < lx + lw and ly <= cursor_y < ly + lh:
                chosen_lm = lm
                break

    target_lm = chosen_lm or primary_lm or (logical_monitors[0] if logical_monitors else None)
    if target_lm:
        lx, ly, lscale, ltransform, lprimary, linked, _ = target_lm
        mon_x, mon_y = int(lx), int(ly)
        scale = float(lscale) if lscale else 1.0
        if linked:
            connector = linked[0][0]
            phys_w, phys_h = active_modes.get(connector, (0, 0))
            if ltransform in (1, 3, 5, 7):  # Rotacionado 90/270 graus
                phys_w, phys_h = phys_h, phys_w
            if phys_w > 0 and phys_h > 0:
                log_w = int(round(phys_w / scale))
                log_h = int(round(phys_h / scale))
except Exception:
    pass

# 3. Fallback GDK se Mutter não respondeu
if phys_w <= 0 or phys_h <= 0:
    try:
        import gi
        gi.require_version("Gdk", "3.0")
        from gi.repository import Gdk
        display = Gdk.Display.get_default()
        if display:
            mon = None
            if cursor_x is not None and cursor_y is not None:
                mon = display.get_monitor_at_point(cursor_x, cursor_y)
            if not mon:
                mon = display.get_primary_monitor() or display.get_monitor(0)
            if mon:
                geom = mon.get_geometry()
                s = mon.get_scale_factor() or 1
                mon_x, mon_y = geom.x, geom.y
                log_w, log_h = geom.width, geom.height
                scale = float(s)
                phys_w, phys_h = int(geom.width * s), int(geom.height * s)
                connector = mon.get_model() or "gdk-0"
    except Exception:
        pass

if phys_w > 0 and phys_h > 0:
    import subprocess
    xft_dpi = 0
    try:
        xr = subprocess.run(["xrdb", "-query"], capture_output=True, text=True, timeout=1)
        for line in xr.stdout.splitlines():
            if line.startswith("Xft.dpi:"):
                xft_dpi = int(float(line.split(":", 1)[1].strip()))
                break
    except Exception:
        pass
    xwayland_scale = max(1, int(gdk_scale)) if gdk_scale > 1 else (max(1, int(round(xft_dpi / 96.0))) if xft_dpi > 0 else max(1, int(round(scale))))
    wine_dpi = xft_dpi if xft_dpi > 0 else int(round(96 * xwayland_scale))
    print(f"MON_CONNECTOR='{connector}'")
    print(f"PHYS_W={phys_w}")
    print(f"PHYS_H={phys_h}")
    print(f"PHYS_RES='{phys_w}x{phys_h}'")
    print(f"LOG_W={log_w}")
    print(f"LOG_H={log_h}")
    print(f"LOG_RES='{log_w}x{log_h}'")
    print(f"MON_X={mon_x}")
    print(f"MON_Y={mon_y}")
    print(f"MON_SCALE={scale}")
    print(f"XWAYLAND_SCALE={xwayland_scale}")
    print(f"WINE_DPI={wine_dpi}")
    print(f"WINE_DPI_HEX='{wine_dpi:08x}'")
PYEOF
}

OUT="$(detect_monitor)"

# Fallback para xrandr / drm se Python/DBus não estiverem disponíveis
if [ -z "$OUT" ]; then
    XR=$(xrandr --current 2>/dev/null | awk '/ connected primary/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+x[0-9]+\+/){print $i; exit}} / connected/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+x[0-9]+\+/){print $i; exit}}' | head -n1)
    if [ -n "$XR" ]; then
        RES_PART="${XR%%+*}"
        PW="${RES_PART%x*}"
        PH="${RES_PART#*x}"
    else
        DRM_RES=$(cat /sys/class/drm/*/modes 2>/dev/null | head -n1)
        PW="${DRM_RES%x*}"
        PH="${DRM_RES#*x}"
    fi
    PW="${PW:-1920}"
    PH="${PH:-1080}"
    OUT="MON_CONNECTOR='default'
PHYS_W=${PW}
PHYS_H=${PH}
PHYS_RES='${PW}x${PH}'
LOG_W=${PW}
LOG_H=${PH}
LOG_RES='${PW}x${PH}'
MON_X=0
MON_Y=0
MON_SCALE=1.0"
fi

eval "$OUT"

case "${1:-}" in
    --phys-res) echo "$PHYS_RES" ;;
    --log-res)  echo "$LOG_RES" ;;
    --phys-w)   echo "$PHYS_W" ;;
    --phys-h)   echo "$PHYS_H" ;;
    --log-w)    echo "$LOG_W" ;;
    --log-h)    echo "$LOG_H" ;;
    --scale)          echo "$MON_SCALE" ;;
    --xwayland-scale) echo "${XWAYLAND_SCALE:-1}" ;;
    --wine-dpi)       echo "${WINE_DPI:-96}" ;;
    --wine-dpi-hex)   echo "${WINE_DPI_HEX:-00000060}" ;;
    *)                echo "$OUT" ;;
esac
