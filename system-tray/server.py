import http.server
import json
import os
import socketserver
import sys
import urllib.parse
from pathlib import Path
import service_manager
import autostart_manager

STATIC_DIR = Path(__file__).parent / "static"

class DevServicesHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC_DIR), **kwargs)

    def log_message(self, format, *args):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        # --- SYSTEMD SERVICES ENDPOINTS ---
        if path == "/api/services":
            services = service_manager.list_all_services()
            self.send_json({"success": True, "services": services, "total": len(services)})
            return

        elif path == "/api/service/details":
            name = query.get("name", [""])[0]
            if not name:
                self.send_json({"success": False, "error": "Nome do serviço não especificado"}, 400)
                return
            details = service_manager.get_service_details(name)
            self.send_json({"success": True, "details": details})
            return

        elif path == "/api/service/logs":
            name = query.get("name", [""])[0]
            lines = int(query.get("lines", [50])[0])
            if not name:
                self.send_json({"success": False, "error": "Nome do serviço não especificado"}, 400)
                return
            logs = service_manager.get_service_logs(name, lines)
            self.send_json({"success": True, "logs": logs})
            return

        elif path == "/api/system/stats":
            services = service_manager.list_all_services()
            active_count = sum(1 for s in services if s["is_active"])
            running_count = sum(1 for s in services if s["is_running"])
            boot_count = sum(1 for s in services if s["is_boot_enabled"])
            dev_count = sum(1 for s in services if s["is_dev"])
            fav_count = sum(1 for s in services if s["is_favorite"])
            
            dev_mem_total = 0
            for s in services:
                if s["is_active"] and (s["is_dev"] or s["is_favorite"]):
                    det = service_manager.get_service_details(s["name"])
                    dev_mem_total += det.get("memory_mb", 0)

            stats = {
                "total_services": len(services),
                "active": active_count,
                "running": running_count,
                "boot_enabled": boot_count,
                "dev_services": dev_count,
                "favorites": fav_count,
                "dev_memory_mb": round(dev_mem_total, 1)
            }
            self.send_json({"success": True, "stats": stats})
            return

        # --- AUTOSTART APPS ENDPOINTS ---
        elif path == "/api/autostart":
            apps = autostart_manager.list_autostart_apps()
            self.send_json({"success": True, "apps": apps, "total": len(apps)})
            return

        elif path == "/api/system/installed-apps":
            apps = autostart_manager.list_installed_system_apps()
            self.send_json({"success": True, "apps": apps, "total": len(apps)})
            return

        return super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        content_len = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_len) if content_len > 0 else b"{}"
        try:
            body = json.loads(post_data.decode("utf-8"))
        except Exception:
            body = {}

        # --- SYSTEMD SERVICE ACTIONS ---
        if path == "/api/service/action":
            service = body.get("service")
            action = body.get("action")
            if not service or not action:
                self.send_json({"success": False, "error": "Parâmetros 'service' e 'action' são obrigatórios"}, 400)
                return
            
            success, msg = service_manager.execute_action(service, action)
            details = service_manager.get_service_details(service)
            self.send_json({"success": success, "message": msg, "details": details})
            return

        elif path == "/api/service/favorite":
            service = body.get("service")
            if not service:
                self.send_json({"success": False, "error": "Parâmetro 'service' obrigatório"}, 400)
                return
            is_fav = service_manager.toggle_favorite(service)
            self.send_json({"success": True, "is_favorite": is_fav})
            return

        # --- AUTOSTART ACTIONS ---
        elif path == "/api/autostart/toggle":
            filename = body.get("filename")
            enabled = bool(body.get("enabled", False))
            if not filename:
                self.send_json({"success": False, "error": "Parâmetro 'filename' obrigatório"}, 400)
                return
            success, msg = autostart_manager.toggle_autostart_app(filename, enabled)
            self.send_json({"success": success, "message": msg})
            return

        elif path == "/api/autostart/delete":
            filename = body.get("filename")
            if not filename:
                self.send_json({"success": False, "error": "Parâmetro 'filename' obrigatório"}, 400)
                return
            success, msg = autostart_manager.delete_autostart_app(filename)
            self.send_json({"success": success, "message": msg})
            return

        elif path == "/api/autostart/add":
            name = body.get("name", "").strip()
            exec_cmd = body.get("exec", "").strip()
            comment = body.get("comment", "").strip()
            icon = body.get("icon", "").strip()
            if not name or not exec_cmd:
                self.send_json({"success": False, "error": "Nome e Comando de Execução são obrigatórios"}, 400)
                return
            success, msg, filename = autostart_manager.add_autostart_app(name, exec_cmd, comment, icon)
            self.send_json({"success": success, "message": msg, "filename": filename})
            return

        self.send_json({"error": "Rota não encontrada"}, 404)

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

def start_server(port=4999):
    server = ThreadedHTTPServer(("127.0.0.1", port), DevServicesHandler)
    return server

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4999
    server = start_server(port)
    print(f"System Tray Server rodando em http://127.0.0.1:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor encerrado.")
