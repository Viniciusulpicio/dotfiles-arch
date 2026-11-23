const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, screen, globalShortcut } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn, execFileSync } = require('child_process');

// ── Globals ─────────────────────────────────────────────────────────────────
let tray, overlay, dbusMonitor;
let overlayReady = false;
let spawnQueued = false;
let whipActive = false;
let readyTime = 0;
let lastToggleTime = 0;

function getTrayIcon() {
  const file = path.join(__dirname, 'icon', 'tray-linux.png');
  if (fs.existsSync(file)) {
    const img = nativeImage.createFromPath(file);
    if (!img.isEmpty()) return img;
  }
  const fallback = path.join(__dirname, 'icon', 'Template.png');
  return fs.existsSync(fallback) ? nativeImage.createFromPath(fallback) : nativeImage.createEmpty();
}

function buildTrayMenu(active) {
  return Menu.buildFromTemplate([
    {
      label: active ? '💥 Soltar Chicote' : '⚡ Puxar Chicote',
      click: () => triggerToggle(),
    },
    { type: 'separator' },
    { label: 'Sair', click: () => app.quit() },
  ]);
}

function updateTrayState(active) {
  whipActive = active;
  if (!tray) return;
  // Do NOT call tray.setImage() here: in Chromium on Linux, setImage() deletes
  // status_icon_0.png in /tmp while GNOME AppIndicator is reading it, making the icon vanish.
  tray.setToolTip(active ? 'OpenWhip — Clique para soltar o chicote' : 'OpenWhip — Clique para puxar o chicote');
  tray.setContextMenu(buildTrayMenu(active));
}

function triggerToggle() {
  const now = Date.now();
  if (now - lastToggleTime < 350) return;
  lastToggleTime = now;
  toggleOverlay();
}

function waitForStatusNotifierWatcher(maxWaitMs = 10000) {
  const start = Date.now();
  return new Promise((resolve) => {
    const check = () => {
      try {
        const out = execFileSync(
          'gdbus',
          [
            'call', '--session',
            '--dest', 'org.kde.StatusNotifierWatcher',
            '--object-path', '/StatusNotifierWatcher',
            '--method', 'org.freedesktop.DBus.Properties.Get',
            'org.kde.StatusNotifierWatcher', 'IsStatusNotifierHostRegistered',
          ],
          { encoding: 'utf8', timeout: 1000, stdio: ['ignore', 'pipe', 'ignore'] }
        );
        if (out.includes('true')) return resolve(true);
      } catch {}
      if (Date.now() - start >= maxWaitMs) return resolve(false);
      setTimeout(check, 500);
    };
    check();
  });
}

// ── Watch GNOME single-click on top bar tray icon via D-Bus ─────────────────
function startSingleClickMonitor() {
  if (process.platform !== 'linux') return;
  try {
    dbusMonitor = spawn('dbus-monitor', [
      '--session',
      "path='/com/canonical/dbusmenu',interface='com.canonical.dbusmenu',member='Event'",
    ]);
    dbusMonitor.stdout.on('data', (chunk) => {
      const text = chunk.toString();
      if (text.includes('string "opened"')) {
        if (Date.now() - readyTime < 1500) return;
        triggerToggle();
      }
    });
    dbusMonitor.on('error', () => {});
  } catch (e) {
    console.warn('dbus-monitor unavailable:', e?.message || e);
  }
}

// ── Overlay window ──────────────────────────────────────────────────────────
function getActiveBounds() {
  try {
    const pt = screen.getCursorScreenPoint();
    const disp = screen.getDisplayNearestPoint(pt) || screen.getPrimaryDisplay();
    return disp.bounds;
  } catch {
    return screen.getPrimaryDisplay().bounds;
  }
}

function createOverlay() {
  const bounds = getActiveBounds();
  overlay = new BrowserWindow({
    x: bounds.x,
    y: bounds.y,
    width: bounds.width,
    height: bounds.height,
    type: 'toolbar',
    transparent: true,
    frame: false,
    alwaysOnTop: true,
    focusable: false,
    skipTaskbar: true,
    resizable: false,
    hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
    },
  });
  overlay.setAlwaysOnTop(true, 'screen-saver');
  overlayReady = false;
  overlay.loadFile('overlay.html');
  overlay.webContents.on('did-finish-load', () => {
    overlayReady = true;
    if (spawnQueued && overlay && overlay.isVisible()) {
      spawnQueued = false;
      overlay.webContents.send('spawn-whip');
    }
  });
  overlay.on('closed', () => {
    overlay = null;
    overlayReady = false;
    spawnQueued = false;
    updateTrayState(false);
  });
}

function toggleOverlay() {
  if (overlay && overlay.isVisible() && whipActive) {
    overlay.webContents.send('drop-whip');
    updateTrayState(false);
    return;
  }
  if (!overlay) createOverlay();
  const bounds = getActiveBounds();
  overlay.setBounds({ x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height });
  overlay.showInactive();
  updateTrayState(true);
  if (overlayReady) {
    overlay.webContents.send('spawn-whip');
  } else {
    spawnQueued = true;
  }
}

// ── IPC (Visual-only mode: keyboard macro disabled) ─────────────────────────
ipcMain.on('whip-crack', () => {});

ipcMain.on('hide-overlay', () => {
  if (overlay) overlay.hide();
  updateTrayState(false);
});

// ── App lifecycle ───────────────────────────────────────────────────────────
app.whenReady().then(async () => {
  await waitForStatusNotifierWatcher(10000);
  readyTime = Date.now();
  tray = new Tray(getTrayIcon());
  updateTrayState(false);
  tray.on('click', () => triggerToggle());
  startSingleClickMonitor();
  globalShortcut.register('Alt+W', () => triggerToggle());
  const syncOverlayBounds = () => {
    if (overlay) {
      const bounds = getActiveBounds();
      overlay.setBounds({ x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height });
    }
  };
  screen.on('display-metrics-changed', syncOverlayBounds);
  screen.on('display-added', syncOverlayBounds);
  screen.on('display-removed', syncOverlayBounds);
});

app.on('will-quit', () => {
  if (dbusMonitor) {
    try { dbusMonitor.kill(); } catch {}
  }
});

app.on('window-all-closed', e => e.preventDefault());
