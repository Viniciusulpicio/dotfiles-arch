#!/bin/sh
# Bloco de Notas Rápido — Flutuante, centralizado e sempre no topo (Super + N)

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hudnote.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -TERM "$OLD_PID" 2>/dev/null
        rm -f "$PID_FILE"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

export GDK_BACKEND=x11

exec python3 - "$@" << 'PYEOF'
import os
import sys
import json
import signal
from datetime import datetime
from pathlib import Path

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkSource", "4")
gi.require_version("GLibUnix", "2.0")
from gi.repository import Gtk, Gdk, GLib, GLibUnix, GtkSource

HOME = Path.home()
MAIN_NOTE = HOME / ".notas_rapidas.txt"
NOTES_DIR = HOME / ".local" / "share" / "zennote"
STATE_FILE = NOTES_DIR / "state.json"
PID_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hudnote.pid"

CSS = b"""
window {
    background-color: transparent;
}

.window-frame {
    background-color: #1e1e1e;
    border: 1px solid #333333;
    border-radius: 8px;
}

.topbar {
    background-color: #252526;
    border-bottom: 1px solid #2d2d2d;
    border-top-left-radius: 8px;
    border-top-right-radius: 8px;
    padding: 4px 8px;
}

.tab-btn {
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    padding: 4px 10px;
    color: #858585;
    font-size: 12px;
    font-weight: 500;
    box-shadow: none;
}

.tab-btn:hover {
    color: #cccccc;
    background-color: rgba(255, 255, 255, 0.04);
}

.tab-btn-active {
    color: #e0e0e0;
    border-bottom: 2px solid #007acc;
}

.icon-btn {
    background: transparent;
    border: none;
    border-radius: 4px;
    padding: 4px 6px;
    color: #858585;
    box-shadow: none;
}

.icon-btn:hover {
    color: #e0e0e0;
    background-color: rgba(255, 255, 255, 0.06);
}

.search-bar {
    background-color: #252526;
    border-bottom: 1px solid #2d2d2d;
    padding: 6px 10px;
}

.search-bar entry {
    background-color: #1e1e1e;
    color: #d4d4d4;
    border: 1px solid #3c3c3c;
    border-radius: 4px;
    padding: 2px 8px;
    min-height: 26px;
}

textview,
textview text {
    background-color: #1e1e1e;
    color: #d4d4d4;
    font-family: "Sans";
    font-size: 13pt;
    caret-color: #007acc;
}

textview text selection {
    background-color: #264f78;
    color: #ffffff;
}

.statusbar {
    background-color: #252526;
    border-top: 1px solid #2d2d2d;
    border-bottom-left-radius: 8px;
    border-bottom-right-radius: 8px;
    padding: 4px 12px;
    color: #858585;
    font-size: 11px;
}

scrollbar {
    background-color: transparent;
    border: none;
}

scrollbar trough {
    background-color: transparent;
}

scrollbar slider {
    background-color: #3f3f46;
    border-radius: 20px;
    min-width: 6px;
    margin: 4px;
}
"""


class HudNote(Gtk.Window):
    def __init__(self):
        super().__init__(title="ZenNote")
        self.save_source_id = None
        self.current_file: Path | None = None
        self.switching_note = False
        self._drag_Possible = False

        NOTES_DIR.mkdir(parents=True, exist_ok=True)
        MAIN_NOTE.touch(exist_ok=True)

        win_w, win_h, pos_x, pos_y = self._detect_monitor_geometry()
        self.set_default_size(win_w, win_h)
        if pos_x is not None and pos_y is not None:
            self.move(pos_x, pos_y)
        else:
            self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_role("quake")

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.set_visual(visual)
            self.set_app_paintable(True)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self._build_ui()
        self._load_initial_note()

        self.connect("key-press-event", self._on_key_press)
        self.connect("delete-event", lambda *_: self.close_and_exit())
        self.connect("focus-out-event", lambda *_: self.save_now())
        self.connect("show", self._on_show)

    def _detect_monitor_geometry(self) -> tuple[int, int, int | None, int | None]:
        try:
            display = Gdk.Display.get_default()
            if display:
                mon = None
                seat = display.get_default_seat()
                if seat and seat.get_pointer():
                    _, cx, cy = seat.get_pointer().get_position()
                    mon = display.get_monitor_at_point(cx, cy)
                if not mon:
                    mon = display.get_primary_monitor() or display.get_monitor(0)
                if mon:
                    wa = mon.get_workarea()
                    w = max(500, min(960, int(wa.width * 0.42)))
                    h = max(340, min(720, int(wa.height * 0.52)))
                    x = wa.x + (wa.width - w) // 2
                    y = wa.y + (wa.height - h) // 2
                    return w, h, x, y
        except Exception:
            pass
        return 680, 460, None, None

    def _build_ui(self):
        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        frame.get_style_context().add_class("window-frame")
        self.add(frame)

        # Barra superior (permite arrastar a janela + abas + ações discretas)
        topbar_event = Gtk.EventBox()
        topbar_event.connect("button-press-event", self._on_topbar_press)
        topbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        topbar.get_style_context().add_class("topbar")
        topbar_event.add(topbar)
        frame.pack_start(topbar_event, False, False, 0)

        self.tabs_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        topbar.pack_start(self.tabs_box, False, False, 0)

        btn_new = self._make_icon_btn("list-add-symbolic", "Nova nota (Ctrl+N)", self.create_new_note)
        topbar.pack_start(btn_new, False, False, 2)

        spacer = Gtk.Box()
        topbar.pack_start(spacer, True, True, 0)

        btn_todo = self._make_icon_btn("object-select-symbolic", "Tarefa [ ] / [x] (Ctrl+Enter)", self.toggle_checkbox)
        topbar.pack_start(btn_todo, False, False, 0)

        btn_time = self._make_icon_btn("document-open-recent-symbolic", "Inserir data/hora (Ctrl+T)", self.insert_timestamp)
        topbar.pack_start(btn_time, False, False, 0)

        btn_search = self._make_icon_btn("system-search-symbolic", "Buscar (Ctrl+F)", self.toggle_search)
        topbar.pack_start(btn_search, False, False, 0)

        btn_copy = self._make_icon_btn("edit-copy-symbolic", "Copiar tudo (Ctrl+Shift+C)", self.copy_all)
        topbar.pack_start(btn_copy, False, False, 0)

        self.btn_del = self._make_icon_btn("user-trash-symbolic", "Excluir nota atual (Ctrl+W)", self.delete_current_note)
        topbar.pack_start(self.btn_del, False, False, 0)

        btn_close = self._make_icon_btn("window-close-symbolic", "Fechar (Esc)", self.close_and_exit)
        topbar.pack_start(btn_close, False, False, 0)

        # Barra de busca recolhível
        self.search_revealer = Gtk.Revealer()
        self.search_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        search_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        search_box.get_style_context().add_class("search-bar")

        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Buscar...")
        self.search_entry.connect("search-changed", self._on_search_changed)
        self.search_entry.connect("activate", lambda *_: self._find_step(forward=True))
        self.search_entry.connect("stop-search", lambda *_: self.toggle_search(force_close=True))
        search_box.pack_start(self.search_entry, True, True, 0)

        btn_prev = self._make_icon_btn("go-up-symbolic", "Anterior", lambda: self._find_step(forward=False))
        btn_next = self._make_icon_btn("go-down-symbolic", "Próximo", lambda: self._find_step(forward=True))
        search_box.pack_start(btn_prev, False, False, 0)
        search_box.pack_start(btn_next, False, False, 0)

        self.search_revealer.add(search_box)
        frame.pack_start(self.search_revealer, False, False, 0)

        # Editor de texto
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        frame.pack_start(scrolled, True, True, 0)

        self.buffer = GtkSource.Buffer()
        self.buffer.set_max_undo_levels(200)
        self.buffer.set_highlight_matching_brackets(False)

        self.search_settings = GtkSource.SearchSettings(wrap_around=True, case_sensitive=False)
        self.search_context = GtkSource.SearchContext.new(self.buffer, self.search_settings)

        self.view = GtkSource.View.new_with_buffer(self.buffer)
        self.view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.view.set_top_margin(24)
        self.view.set_bottom_margin(24)
        self.view.set_left_margin(28)
        self.view.set_right_margin(28)
        self.view.set_indent_on_tab(True)
        self.view.set_tab_width(4)
        scrolled.add(self.view)

        self.buffer.connect("changed", self._on_buffer_changed)

        # Barra de status limpa
        statusbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        statusbar.get_style_context().add_class("statusbar")

        self.status_label = Gtk.Label(label="Salvo")
        self.status_label.set_xalign(0)
        statusbar.pack_start(self.status_label, False, False, 0)

        self.stats_label = Gtk.Label(label="0 linhas  ·  0 palavras")
        self.stats_label.set_xalign(1)
        statusbar.pack_end(self.stats_label, False, False, 0)

        frame.pack_start(statusbar, False, False, 0)

    def _make_icon_btn(self, icon_name: str, tooltip: str, callback) -> Gtk.Button:
        btn = Gtk.Button.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
        btn.set_tooltip_text(tooltip)
        btn.set_can_focus(False)
        btn.get_style_context().add_class("icon-btn")
        btn.connect("clicked", lambda *_: callback())
        return btn

    def _on_topbar_press(self, _widget, event):
        if event.button == 1 and event.type == Gdk.EventType.BUTTON_PRESS:
            self.begin_move_drag(event.button, int(event.x_root), int(event.y_root), event.time)
            return True
        return False

    def _on_show(self, *_args):
        self.set_keep_above(True)
        self.present()
        self.view.grab_focus()

    def _get_all_note_files(self) -> list[Path]:
        extra = sorted(NOTES_DIR.glob("nota_*.md"))
        return [MAIN_NOTE] + extra

    def _load_initial_note(self):
        last_path = MAIN_NOTE
        if STATE_FILE.is_file():
            try:
                data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
                candidate = Path(data.get("last_file", str(MAIN_NOTE)))
                if candidate.is_file():
                    last_path = candidate
            except Exception:
                pass
        self._switch_to_file(last_path)

    def _rebuild_tabs(self):
        for child in self.tabs_box.get_children():
            self.tabs_box.remove(child)

        files = self._get_all_note_files()
        for idx, path in enumerate(files, start=1):
            label = "Notas" if path == MAIN_NOTE else f"Nota {idx}"
            btn = Gtk.Button(label=label)
            btn.set_can_focus(False)
            ctx = btn.get_style_context()
            ctx.add_class("tab-btn")
            if path == self.current_file:
                ctx.add_class("tab-btn-active")
            btn.connect("clicked", lambda _b, p=path: self._switch_to_file(p))
            self.tabs_box.pack_start(btn, False, False, 0)

        self.tabs_box.show_all()
        self.btn_del.set_sensitive(self.current_file != MAIN_NOTE)

    def _switch_to_file(self, path: Path):
        if not self.switching_note and self.current_file:
            self.save_now()
        self.switching_note = True
        self.current_file = path
        try:
            text = path.read_text(encoding="utf-8") if path.is_file() else ""
        except Exception:
            text = ""
        self.buffer.begin_not_undoable_action()
        self.buffer.set_text(text)
        self.buffer.end_not_undoable_action()
        self.switching_note = False
        self._rebuild_tabs()
        self._update_stats()
        self._save_state()
        self.view.grab_focus()

    def _save_state(self):
        try:
            STATE_FILE.write_text(
                json.dumps({"last_file": str(self.current_file)}),
                encoding="utf-8",
            )
        except Exception:
            pass

    def create_new_note(self):
        self.save_now()
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        new_path = NOTES_DIR / f"nota_{ts}.md"
        new_path.write_text("", encoding="utf-8")
        self._switch_to_file(new_path)

    def delete_current_note(self):
        if self.current_file == MAIN_NOTE:
            return
        try:
            self.current_file.unlink(missing_ok=True)
        except Exception:
            pass
        self.current_file = MAIN_NOTE
        self._switch_to_file(MAIN_NOTE)

    def _on_buffer_changed(self, *_args):
        if self.switching_note:
            return
        self.status_label.set_text("Editando...")
        self._update_stats()
        if self.save_source_id is not None:
            GLib.source_remove(self.save_source_id)
        self.save_source_id = GLib.timeout_add(250, self._flush_save)

    def _flush_save(self):
        self.save_source_id = None
        self.save_now()
        return GLib.SOURCE_REMOVE

    def save_now(self):
        if self.switching_note or not self.current_file:
            return
        start, end = self.buffer.get_bounds()
        text = self.buffer.get_text(start, end, False)
        try:
            self.current_file.write_text(text, encoding="utf-8")
            self.status_label.set_text("Salvo")
        except Exception:
            self.status_label.set_text("Erro ao salvar")

    def _update_stats(self):
        start, end = self.buffer.get_bounds()
        text = self.buffer.get_text(start, end, False)
        words = len(text.split()) if text.strip() else 0
        lines = self.buffer.get_line_count()
        self.stats_label.set_text(f"{lines} linhas  ·  {words} palavras  ·  {len(text)} caracteres")

    def toggle_checkbox(self):
        insert_mark = self.buffer.get_insert()
        iter_cur = self.buffer.get_iter_at_mark(insert_mark)
        line_num = iter_cur.get_line()

        line_start = self.buffer.get_iter_at_line(line_num)
        line_end = line_start.copy()
        if not line_end.ends_line():
            line_end.forward_to_line_end()

        line_text = self.buffer.get_text(line_start, line_end, False)
        if line_text.lstrip().startswith("- [ ] "):
            new_line = line_text.replace("- [ ] ", "- [x] ", 1)
        elif line_text.lstrip().startswith("- [x] "):
            new_line = line_text.replace("- [x] ", "- [ ] ", 1)
        else:
            new_line = f"- [ ] {line_text}"

        self.buffer.begin_user_action()
        self.buffer.delete(line_start, line_end)
        self.buffer.insert(line_start, new_line)
        self.buffer.end_user_action()

    def insert_timestamp(self):
        stamp = datetime.now().strftime("%d/%m/%Y %H:%M — ")
        self.buffer.insert_at_cursor(stamp)

    def copy_all(self):
        start, end = self.buffer.get_bounds()
        text = self.buffer.get_text(start, end, False)
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text(text, -1)
        self.status_label.set_text("Copiado")

    def toggle_search(self, force_close: bool = False):
        revealed = self.search_revealer.get_reveal_child()
        if force_close or revealed:
            self.search_revealer.set_reveal_child(False)
            self.search_settings.set_search_text(None)
            self.view.grab_focus()
        else:
            self.search_revealer.set_reveal_child(True)
            self.search_entry.grab_focus()

    def _on_search_changed(self, entry: Gtk.SearchEntry):
        query = entry.get_text()
        self.search_settings.set_search_text(query if query else None)
        if query:
            self._find_step(forward=True, from_start=True)

    def _find_step(self, forward: bool = True, from_start: bool = False):
        insert_mark = self.buffer.get_insert()
        sel_bounds = self.buffer.get_selection_bounds()
        if from_start:
            iter_pos = self.buffer.get_start_iter()
        elif sel_bounds:
            iter_pos = sel_bounds[1] if forward else sel_bounds[0]
        else:
            iter_pos = self.buffer.get_iter_at_mark(insert_mark)

        if forward:
            found, match_start, match_end, _wrapped = self.search_context.forward(iter_pos)
        else:
            found, match_start, match_end, _wrapped = self.search_context.backward(iter_pos)

        if found:
            self.buffer.select_range(match_start, match_end)
            self.view.scroll_to_iter(match_start, 0.15, False, 0.0, 0.5)

    def _on_key_press(self, _widget, event):
        ctrl = bool(event.state & Gdk.ModifierType.CONTROL_MASK)
        shift = bool(event.state & Gdk.ModifierType.SHIFT_MASK)
        alt = bool(event.state & Gdk.ModifierType.MOD1_MASK)

        if event.keyval == Gdk.KEY_Escape:
            if self.search_revealer.get_reveal_child():
                self.toggle_search(force_close=True)
                return True
            self.close_and_exit()
            return True

        if ctrl and not shift and event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self.toggle_checkbox()
            return True

        if ctrl and not shift and event.keyval in (Gdk.KEY_t, Gdk.KEY_T):
            self.insert_timestamp()
            return True

        if ctrl and not shift and event.keyval in (Gdk.KEY_n, Gdk.KEY_N):
            self.create_new_note()
            return True

        if ctrl and not shift and event.keyval in (Gdk.KEY_f, Gdk.KEY_F):
            self.toggle_search()
            return True

        if ctrl and not shift and event.keyval in (Gdk.KEY_s, Gdk.KEY_S):
            self.save_now()
            return True

        if ctrl and not shift and event.keyval in (Gdk.KEY_w, Gdk.KEY_W):
            if self.current_file != MAIN_NOTE:
                self.delete_current_note()
            else:
                self.close_and_exit()
            return True

        if ctrl and shift and event.keyval in (Gdk.KEY_c, Gdk.KEY_C):
            self.copy_all()
            return True

        if alt and Gdk.KEY_1 <= event.keyval <= Gdk.KEY_9:
            idx = event.keyval - Gdk.KEY_1
            files = self._get_all_note_files()
            if idx < len(files):
                self._switch_to_file(files[idx])
                return True

        return False

    def close_and_exit(self):
        if self.save_source_id is not None:
            GLib.source_remove(self.save_source_id)
            self.save_source_id = None
        self.save_now()
        self._save_state()
        PID_FILE.unlink(missing_ok=True)
        Gtk.main_quit()


def main():
    PID_FILE.write_text(str(os.getpid()), encoding="utf-8")
    win = HudNote()

    def on_signal(*_args):
        win.close_and_exit()
        return GLib.SOURCE_REMOVE

    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, on_signal)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, on_signal)

    win.show_all()
    try:
        Gtk.main()
    finally:
        PID_FILE.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
PYEOF
