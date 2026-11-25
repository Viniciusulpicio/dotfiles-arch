#!/usr/bin/env python3
"""
render_showcase.py
Renderiza em 1920x1080 real via Google Chrome Headless (CDP) o vídeo MP4 e GIF
demonstrando todos os componentes reais do Arch Linux + GNOME 51 Rice:
1. Dual WezTerm (window_decorations="NONE", 85% opacity) + Fastfetch (john_wuthering.png) + CAVA 60fps + Dual Conky
2. Wofi Wallpaper Picker (Alt+W, 3 colunas, radial-gradient @color1) + Pywal Hook Sync (Cava, Fastfetch, Wlogout) + btop++ Kernel BBR/ZRAM
3. System Tray — Linux Control Panel (XAMPP Edition) com 297 serviços reais, Polkit, Logs journalctl e Autostart
4. REA Studio (Reverse Engineer Anything) analisando binário ELF64 + ZenNote (Super+N, scripts/hudnote.sh)
5. Wlogout Power Menu (Alt+L) com wallpaper borrado e ícones reais
"""

import base64
import hashlib
import json
import os
import shutil
import socket
import struct
import subprocess
import tempfile
import time
import urllib.request
from urllib.parse import urlparse

FPS = 24
TOTAL_FRAMES = 360  # 15 segundos a 24 FPS

class SimpleCDPClient:
    def __init__(self, ws_url):
        parsed = urlparse(ws_url)
        self.sock = socket.create_connection((parsed.hostname, parsed.port), timeout=15)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET {parsed.path} HTTP/1.1\r\n"
            f"Host: {parsed.hostname}:{parsed.port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self.sock.sendall(req.encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            resp += self.sock.recv(4096)
        self.msg_id = 0

    def _send_frame(self, data_bytes):
        header = bytearray([0x81])
        length = len(data_bytes)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", length))
        mask = os.urandom(4)
        header.extend(mask)
        masked = bytearray(length)
        for i in range(length):
            masked[i] = data_bytes[i] ^ mask[i % 4]
        self.sock.sendall(header + masked)

    def _recv_exact(self, n):
        buf = bytearray()
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise EOFError("WebSocket closed")
            buf.extend(chunk)
        return bytes(buf)

    def _recv_frame(self):
        while True:
            b1, b2 = self._recv_exact(2)
            opcode = b1 & 0x0F
            length = b2 & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            if b2 & 0x80:
                mask = self._recv_exact(4)
                payload = bytearray(self._recv_exact(length))
                for i in range(length):
                    payload[i] ^= mask[i % 4]
                payload = bytes(payload)
            else:
                payload = self._recv_exact(length)
            if opcode == 0x8:
                raise EOFError("WebSocket closed")
            if opcode in (0x1, 0x2):
                return payload.decode("utf-8", errors="replace")

    def call(self, method, params=None):
        self.msg_id += 1
        target_id = self.msg_id
        payload = json.dumps({"id": target_id, "method": method, "params": params or {}})
        self._send_frame(payload.encode("utf-8"))
        while True:
            msg = json.loads(self._recv_frame())
            if msg.get("id") == target_id:
                return msg.get("result", {})

    def eval_js(self, expr):
        return self.call("Runtime.evaluate", {"expression": expr, "awaitPromise": False})

    def screenshot_jpg(self):
        res = self.call("Page.captureScreenshot", {"format": "jpeg", "quality": 95})
        return base64.b64decode(res["data"])

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


def drive_choreography(cdp, f, t_sec):
    # Step deterministic CAVA clock every frame
    cdp.eval_js(f"window.__setDemoTime && window.__setDemoTime({t_sec:.4f});")

    # Typing simulation in Zsh during Scene 1
    if f == 12:
        cdp.eval_js("document.getElementById('zsh-input').value = 'w';")
    elif f == 18:
        cdp.eval_js("document.getElementById('zsh-input').value = 'wa';")
    elif f == 24:
        cdp.eval_js("document.getElementById('zsh-input').value = 'wal';")
    elif f == 34:
        cdp.eval_js("document.getElementById('zsh-input').value = ''; window.runTerminalCommand('sysctl');")

    # Scene 2: Open Wofi Wallpaper Picker (Alt + W)
    elif f == 72:
        cdp.eval_js("window.openWofiWallpaper();")
    elif f == 88:
        # Highlight second wallpaper in Wofi
        cdp.eval_js("""
            const entries = document.querySelectorAll('.wofi-wall-entry');
            entries.forEach(e => e.classList.remove('selected'));
            if (entries[1]) entries[1].classList.add('selected');
        """)
    elif f == 102:
        # Select Golden Amber wallpaper -> triggers Pywal + Cava + Fastfetch + GNOME Notification
        cdp.eval_js("window.selectWofiWallpaper(1);")
    elif f == 126:
        # Show btop++ kernel & ZRAM monitor on right terminal
        cdp.eval_js("window.setRightTerminalMode('btop');")

    # Scene 3: System Tray Control Panel (XAMPP Edition)
    elif f == 152:
        cdp.eval_js("window.setRightTerminalMode('cava'); window.toggleWindow('win-xampp');")
    elif f == 178:
        # Open journalctl logs modal inside XAMPP iframe
        cdp.eval_js("""
            const ifr = document.getElementById('iframe-xampp');
            if (ifr && ifr.contentWindow && ifr.contentWindow.openLogsModal) {
                ifr.contentWindow.openLogsModal('docker');
            }
        """)
    elif f == 206:
        # Close logs modal and switch to Autostart Apps tab inside XAMPP iframe
        cdp.eval_js("""
            const ifr = document.getElementById('iframe-xampp');
            if (ifr && ifr.contentWindow) {
                if (ifr.contentWindow.closeLogsModal) ifr.contentWindow.closeLogsModal();
                if (ifr.contentWindow.switchSection) ifr.contentWindow.switchSection('autostart');
            }
        """)

    # Scene 4: REA Studio (Reverse Engineer Anything) & ZenNote (Super + N)
    elif f == 234:
        cdp.eval_js("window.toggleWindow('win-rea');")
    elif f == 242:
        cdp.eval_js("""
            const ifr = document.getElementById('iframe-rea');
            if (ifr && ifr.contentWindow && ifr.contentWindow.applyPreset) {
                ifr.contentWindow.applyPreset('/usr/bin/ls');
            }
        """)
    elif f == 270:
        # Switch back to desktop with Ocean Blue wallpaper + open ZenNote (Super + N)
        cdp.eval_js("""
            window.closeWindow('win-rea');
            window.applyWallpaper(2, false);
            window.openOverlay('hudnote');
        """)

    # Scene 5: Wlogout Power Menu (Alt + L)
    elif f == 304:
        cdp.eval_js("""
            window.closeOverlay('hudnote');
            window.openOverlay('wlogout');
        """)
    elif f == 324:
        # Simulate hover on Lock button in Wlogout
        cdp.eval_js("""
            const btns = document.querySelectorAll('.wlogout-btn');
            if (btns[0]) {
                btns[0].style.backgroundColor = 'rgba(var(--color1-rgb), 0.45)';
                btns[0].style.borderColor = 'var(--color5)';
                btns[0].style.transform = 'scale(1.05)';
            }
        """)
    elif f == 342:
        # Simulate hover on Reboot button in Wlogout
        cdp.eval_js("""
            const btns = document.querySelectorAll('.wlogout-btn');
            if (btns[0]) {
                btns[0].style.backgroundColor = '';
                btns[0].style.borderColor = '';
                btns[0].style.transform = '';
            }
            if (btns[1]) {
                btns[1].style.backgroundColor = 'rgba(var(--color1-rgb), 0.45)';
                btns[1].style.borderColor = 'var(--color5)';
                btns[1].style.transform = 'scale(1.05)';
            }
        """)


def main():
    os.makedirs("demo", exist_ok=True)
    temp_dir = tempfile.mkdtemp(prefix="chrome_rice_frames_")
    index_url = "file://" + os.path.abspath("docs/index.html")

    print("🌐 Iniciando Google Chrome Headless (1920x1080) para captura real...")
    chrome_proc = subprocess.Popen(
        [
            "google-chrome-stable",
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--allow-file-access-from-files",
            "--window-size=1920,1080",
            "--hide-scrollbars",
            "--remote-debugging-port=9321",
            index_url,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    try:
        # Wait for Chrome DevTools endpoint and fonts/iframes to load
        time.sleep(2.5)
        tabs = json.loads(urllib.request.urlopen("http://127.0.0.1:9321/json").read().decode())
        ws_url = [t["webSocketDebuggerUrl"] for t in tabs if t.get("type") == "page"][0]
        cdp = SimpleCDPClient(ws_url)
        cdp.call("Page.enable")
        cdp.call("Runtime.enable")
        cdp.call("Emulation.setDeviceMetricsOverride", {
            "width": 1920,
            "height": 1080,
            "deviceScaleFactor": 1,
            "mobile": False
        })
        time.sleep(0.8)

        print(f"🎬 Capturando {TOTAL_FRAMES} frames em 1920x1080 real ({TOTAL_FRAMES/FPS:.1f}s @ {FPS} FPS)...")
        for f in range(TOTAL_FRAMES):
            t_sec = f / FPS
            drive_choreography(cdp, f, t_sec)
            jpg_bytes = cdp.screenshot_jpg()
            frame_path = os.path.join(temp_dir, f"frame_{f:04d}.jpg")
            with open(frame_path, "wb") as out_f:
                out_f.write(jpg_bytes)
            if f % 36 == 0 or f == TOTAL_FRAMES - 1:
                print(f"  Frame {f+1}/{TOTAL_FRAMES} ({((f+1)/TOTAL_FRAMES)*100:.0f}%)")

        cdp.close()

        mp4_out = "demo/showcase.mp4"
        print("🎥 Codificando MP4 1080p Full HD (H.264)...")
        subprocess.check_call(
            [
                "ffmpeg", "-y", "-framerate", str(FPS),
                "-i", os.path.join(temp_dir, "frame_%04d.jpg"),
                "-vf", "scale=1920:1080",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "fast",
                mp4_out,
            ]
        )

        gif_out = "demo/showcase.gif"
        palette_path = os.path.join(temp_dir, "palette.png")
        print("🎞️ Codificando GIF de alta fidelidade (Lanczos + Palette 2-pass)...")
        subprocess.check_call(
            [
                "ffmpeg", "-y", "-framerate", str(FPS),
                "-i", os.path.join(temp_dir, "frame_%04d.jpg"),
                "-vf", "fps=16,scale=1024:576:flags=lanczos,palettegen=stats_mode=full",
                "-update", "1", "-frames:v", "1",
                palette_path,
            ]
        )
        subprocess.check_call(
            [
                "ffmpeg", "-y", "-framerate", str(FPS),
                "-i", os.path.join(temp_dir, "frame_%04d.jpg"),
                "-i", palette_path,
                "-lavfi", "fps=16,scale=1024:576:flags=lanczos [x]; [x][1:v] paletteuse=dither=sierra2_4a",
                gif_out,
            ]
        )
        print("🎉 Renderização concluída com sucesso!")

    finally:
        chrome_proc.terminate()
        shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
