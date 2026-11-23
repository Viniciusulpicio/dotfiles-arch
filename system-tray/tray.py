import os
import sys
import threading
import webbrowser
import gi

try:
    gi.require_version('Gtk', '3.0')
    try:
        gi.require_version('AyatanaAppIndicator3', '0.1')
        from gi.repository import AyatanaAppIndicator3 as AppIndicator
    except Exception:
        gi.require_version('AppIndicator3', '0.1')
        from gi.repository import AppIndicator3 as AppIndicator
    from gi.repository import Gtk, GLib
    HAS_TRAY = True
except Exception as e:
    HAS_TRAY = False
    print(f"Aviso: Bandeja do sistema (AppIndicator) não disponível: {e}")

import service_manager

class SystemTrayApp:
    def __init__(self, port=4999, open_window_callback=None):
        self.port = port
        self.open_window_callback = open_window_callback
        self.indicator = None
        self.menu = None
        
        if HAS_TRAY:
            static_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "static"))
            
            # Setup indicator with custom icon
            self.indicator = AppIndicator.Indicator.new_with_path(
                "system-tray-gnome",
                "system-tray",
                AppIndicator.IndicatorCategory.APPLICATION_STATUS,
                static_dir
            )
            self.indicator.set_icon_theme_path(static_dir)
            self.indicator.set_title("System Tray")
            self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
            self.update_menu()
            
            # Auto refresh menu every 8 seconds
            GLib.timeout_add_seconds(8, self.update_menu)

    def open_dashboard(self, _widget=None):
        if self.open_window_callback:
            self.open_window_callback()
        else:
            webbrowser.open(f"http://127.0.0.1:{self.port}")

    def toggle_service(self, _widget, service_name, current_active):
        action = "stop" if current_active else "start"
        def _run():
            service_manager.execute_action(service_name, action)
            GLib.idle_add(self.update_menu)
        threading.Thread(target=_run, daemon=True).start()

    def update_menu(self):
        if not HAS_TRAY or not self.indicator:
            return True

        menu = Gtk.Menu()

        # Header Title
        title_item = Gtk.MenuItem(label="System Tray — Serviços")
        title_item.set_sensitive(False)
        menu.append(title_item)
        menu.append(Gtk.SeparatorMenuItem())

        # Quick services (Favorites & Dev services)
        try:
            favs = service_manager.get_favorites()
            all_services = {s["name"]: s for s in service_manager.list_all_services()}
            
            displayed_units = []
            for fav in favs:
                if fav in all_services:
                    displayed_units.append(all_services[fav])
                elif f"{fav}.service" in all_services:
                    displayed_units.append(all_services[f"{fav}.service"])
                    
            if len(displayed_units) < 6:
                for s in all_services.values():
                    if s["is_dev"] and s not in displayed_units:
                        displayed_units.append(s)
                    if len(displayed_units) >= 7:
                        break

            if displayed_units:
                for s in displayed_units:
                    name = s["display_name"]
                    is_active = s["is_active"]
                    status_symbol = "🟢" if is_active else "⚪"
                    action_text = "Parar" if is_active else "Iniciar"
                    
                    label = f"{status_symbol} {name}  [{action_text}]"
                    item = Gtk.MenuItem(label=label)
                    item.connect("activate", self.toggle_service, s["name"], is_active)
                    menu.append(item)
                menu.append(Gtk.SeparatorMenuItem())
        except Exception:
            pass

        # Open Full Dashboard
        dash_item = Gtk.MenuItem(label="🌐 Abrir Painel Completo")
        dash_item.connect("activate", self.open_dashboard)
        menu.append(dash_item)

        # Refresh
        refresh_item = Gtk.MenuItem(label="🔄 Atualizar Status")
        refresh_item.connect("activate", lambda w: self.update_menu())
        menu.append(refresh_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Quit
        quit_item = Gtk.MenuItem(label="❌ Encerrar System Tray")
        quit_item.connect("activate", lambda w: Gtk.main_quit())
        menu.append(quit_item)

        menu.show_all()
        self.indicator.set_menu(menu)
        self.menu = menu
        return True

    def run(self):
        if HAS_TRAY:
            Gtk.main()
