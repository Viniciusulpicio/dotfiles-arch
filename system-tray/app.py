#!/usr/bin/env python3
import argparse
import os
import signal
import socket
import sys
import threading
import time
import webbrowser

import server
import service_manager
import tray

def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('127.0.0.1', port)) == 0

def find_free_port(start_port=4999):
    port = start_port
    while is_port_in_use(port) and port < start_port + 50:
        port += 1
    return port

def open_app_window(url):
    # Try WebKit2 native window if available, else open browser
    try:
        import gi
        gi.require_version('Gtk', '3.0')
        gi.require_version('WebKit2', '4.1')
        from gi.repository import Gtk, WebKit2, GLib

        def _launch_gtk():
            win = Gtk.Window(title="System Tray — Controle de Serviços")
            win.set_default_size(1180, 780)
            win.set_position(Gtk.WindowPosition.CENTER)
            
            webview = WebKit2.WebView()
            webview.load_uri(url)
            win.add(webview)
            win.show_all()
            win.connect("destroy", lambda w: None)

        GLib.idle_add(_launch_gtk)
    except Exception:
        # Fallback to default browser
        webbrowser.open(url)

def main():
    parser = argparse.ArgumentParser(description="System Tray — Gerenciador Dinâmico de Serviços Linux")
    parser.add_argument("--port", type=int, default=4999, help="Porta do servidor web (padrão: 4999)")
    parser.add_argument("--no-browser", action="store_true", help="Não abrir o navegador/janela automaticamente")
    parser.add_argument("--web-only", action="store_true", help="Executar apenas o servidor web sem ícone na bandeja")
    args = parser.parse_args()

    port = args.port
    if is_port_in_use(port):
        print(f"Porta {port} em uso, procurando outra porta livre...")
        port = find_free_port(port)

    url = f"http://127.0.0.1:{port}"
    print("=" * 60)
    print("SYSTEM TRAY — Gerenciador Dinâmico de Serviços")
    print(f"🌐 Servidor Web: {url}")
    print("=" * 60)

    # Start HTTP server in daemon thread
    httpd = server.start_server(port)
    server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    server_thread.start()

    # Open UI unless disabled
    if not args.no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()

    # If web-only mode
    if args.web_only or not tray.HAS_TRAY:
        print("Pressione Ctrl+C para encerrar.")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nEncerrando servidor...")
            httpd.shutdown()
            sys.exit(0)

    # Initialize System Tray
    tray_app = tray.SystemTrayApp(port=port, open_window_callback=lambda: webbrowser.open(url))
    
    # Handle SIGINT cleanly
    signal.signal(signal.SIGINT, lambda sig, frame: sys.exit(0))

    try:
        tray_app.run()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.shutdown()

if __name__ == "__main__":
    main()
