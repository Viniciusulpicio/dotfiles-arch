#!/usr/bin/env python3
import os
import sys
import signal
import socket
import subprocess
import threading
import time
import webbrowser
import gi

gi.require_version('Gtk', '3.0')
try:
    gi.require_version('AyatanaAppIndicator3', '0.1')
    from gi.repository import AyatanaAppIndicator3 as AppIndicator
except Exception:
    gi.require_version('AppIndicator3', '0.1')
    from gi.repository import AppIndicator3 as AppIndicator

from gi.repository import Gtk, Gdk, GLib
try:
    gi.require_version('WebKit2', '4.1')
    from gi.repository import WebKit2
    HAS_WEBKIT = True
except Exception:
    HAS_WEBKIT = False

PORT = 4321
APP_URL = f"http://127.0.0.1:{PORT}"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")

server_proc = None
active_window = None

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) == 0

def start_server():
    global server_proc
    if not is_port_in_use(PORT):
        server_script = os.path.join(BASE_DIR, "server.js")
        server_proc = subprocess.Popen(
            ["node", "--max-old-space-size=4096", server_script],
            cwd=BASE_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        time.sleep(0.5)

def open_app_window(target_url=APP_URL):
    global active_window
    if not HAS_WEBKIT:
        webbrowser.open(target_url)
        return

    def _launch():
        global active_window
        if active_window is not None:
            active_window.present()
            active_window.webview.load_uri(target_url)
            return

        win = Gtk.Window(title="REA — Reverse Engineer Anything")
        win_w, win_h = 1200, 800
        try:
            display = Gdk.Display.get_default()
            if display:
                mon = display.get_primary_monitor() or display.get_monitor(0)
                if mon:
                    wa = mon.get_workarea()
                    win_w = max(900, min(1480, int(wa.width * 0.78)))
                    win_h = max(600, min(960, int(wa.height * 0.82)))
        except Exception:
            pass

        win.set_default_size(win_w, win_h)
        win.set_position(Gtk.WindowPosition.CENTER)

        # Set window icon
        icon_path = os.path.join(STATIC_DIR, "rea-studio-48.png")
        if os.path.exists(icon_path):
            win.set_icon_from_file(icon_path)

        webview = WebKit2.WebView()
        webview.load_uri(target_url)
        win.webview = webview
        win.add(webview)
        win.show_all()

        def on_close(widget, event):
            global active_window
            active_window = None
            return False

        win.connect("delete-event", on_close)
        active_window = win

    GLib.idle_add(_launch)

def pick_file_and_open(_widget=None):
    def _dialog():
        dialog = Gtk.FileChooserDialog(
            title="Selecione o binário ou arquivo executável para o REA",
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        res = dialog.run()
        if res == Gtk.ResponseType.OK:
            filepath = dialog.get_filename()
            dialog.destroy()
            open_app_window(f"{APP_URL}?target={filepath}&mode=analyze")
        else:
            dialog.destroy()
    GLib.idle_add(_dialog)

def pick_folder_and_open(_widget=None):
    def _dialog():
        dialog = Gtk.FileChooserDialog(
            title="Selecione a pasta do aplicativo (Electron / Node)",
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        res = dialog.run()
        if res == Gtk.ResponseType.OK:
            folderpath = dialog.get_filename()
            dialog.destroy()
            open_app_window(f"{APP_URL}?target={folderpath}&mode=javascript")
        else:
            dialog.destroy()
    GLib.idle_add(_dialog)

def quit_app(_widget=None):
    global server_proc
    if server_proc:
        try:
            server_proc.terminate()
        except Exception:
            pass
    Gtk.main_quit()
    sys.exit(0)

class REATrayApp:
    def __init__(self):
        # Exact same indicator initialization as system-tray
        self.indicator = AppIndicator.Indicator.new_with_path(
            "rea-studio-indicator",
            "rea-studio",
            AppIndicator.IndicatorCategory.APPLICATION_STATUS,
            STATIC_DIR
        )
        self.indicator.set_icon_theme_path(STATIC_DIR)
        self.indicator.set_title("REA — Reverse Engineer Anything")
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.build_menu()

    def build_menu(self):
        menu = Gtk.Menu()

        title_item = Gtk.MenuItem(label="REA — Engenharia Reversa")
        title_item.set_sensitive(False)
        menu.append(title_item)
        menu.append(Gtk.SeparatorMenuItem())

        open_item = Gtk.MenuItem(label="🖥️ Abrir Janela do REA")
        open_item.connect("activate", lambda w: open_app_window(APP_URL))
        menu.append(open_item)

        pick_file_item = Gtk.MenuItem(label="📂 Inspecionar Arquivo / Binário...")
        pick_file_item.connect("activate", pick_file_and_open)
        menu.append(pick_file_item)

        pick_folder_item = Gtk.MenuItem(label="📁 Inspecionar Pasta de App (Electron / JS)...")
        pick_folder_item.connect("activate", pick_folder_and_open)
        menu.append(pick_folder_item)

        menu.append(Gtk.SeparatorMenuItem())

        browser_item = Gtk.MenuItem(label="🌐 Abrir no Navegador Web")
        browser_item.connect("activate", lambda w: webbrowser.open(APP_URL))
        menu.append(browser_item)

        menu.append(Gtk.SeparatorMenuItem())

        quit_item = Gtk.MenuItem(label="❌ Encerrar REA")
        quit_item.connect("activate", quit_app)
        menu.append(quit_item)

        menu.show_all()
        self.indicator.set_menu(menu)

def main():
    start_server()
    tray = REATrayApp()

    # Open window on start
    threading.Timer(0.6, lambda: open_app_window(APP_URL)).start()

    signal.signal(signal.SIGINT, lambda sig, frame: quit_app())
    Gtk.main()

if __name__ == "__main__":
    main()
