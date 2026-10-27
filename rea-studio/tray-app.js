const { app, BrowserWindow, Tray, Menu, dialog, nativeImage, shell } = require('electron');
const path = require('path');
const { spawn } = require('child_process');

let mainWindow = null;
let tray = null;
let serverProcess = null;

const PORT = 4321;
const APP_URL = `http://localhost:${PORT}`;

function startServer() {
  serverProcess = spawn('node', ['--max-old-space-size=4096', path.join(__dirname, 'server.js')], {
    cwd: __dirname,
    stdio: 'ignore'
  });
}

function createWindow() {
  if (mainWindow) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
    return;
  }

  const iconPath = path.join(__dirname, 'app-icon.png');

  mainWindow = new BrowserWindow({
    width: 1240,
    height: 840,
    minWidth: 960,
    minHeight: 680,
    title: 'REA — Engenharia Reversa',
    icon: iconPath,
    backgroundColor: '#1e1e1e',
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  mainWindow.loadURL(APP_URL);

  mainWindow.on('close', (event) => {
    if (!app.isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
    return false;
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function createTray() {
  const iconPath = path.join(__dirname, 'app-icon.png');
  const icon = nativeImage.createFromPath(iconPath);
  tray = new Tray(icon);
  tray.setToolTip('REA — Reverse Engineer Anything');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Abrir REA',
      click: () => createWindow()
    },
    { type: 'separator' },
    {
      label: 'Inspecionar arquivo executável...',
      click: async () => {
        const { canceled, filePaths } = await dialog.showOpenDialog({
          properties: ['openFile'],
          title: 'Selecione o binário, APK ou executável'
        });
        if (!canceled && filePaths.length > 0) {
          createWindow();
          mainWindow.loadURL(`${APP_URL}?target=${encodeURIComponent(filePaths[0])}&mode=analyze`);
        }
      }
    },
    {
      label: 'Inspecionar pasta de aplicação (Electron / Node)...',
      click: async () => {
        const { canceled, filePaths } = await dialog.showOpenDialog({
          properties: ['openDirectory'],
          title: 'Selecione a pasta do aplicativo'
        });
        if (!canceled && filePaths.length > 0) {
          createWindow();
          mainWindow.loadURL(`${APP_URL}?target=${encodeURIComponent(filePaths[0])}&mode=javascript`);
        }
      }
    },
    { type: 'separator' },
    {
      label: 'Abrir no Navegador Web',
      click: () => shell.openExternal(APP_URL)
    },
    { type: 'separator' },
    {
      label: 'Sair do REA',
      click: () => {
        app.isQuitting = true;
        if (serverProcess) serverProcess.kill();
        app.quit();
      }
    }
  ]);

  tray.setContextMenu(contextMenu);
  tray.on('click', () => {
    if (mainWindow && mainWindow.isVisible()) {
      mainWindow.hide();
    } else {
      createWindow();
    }
  });
}

// Single instance lock
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    createWindow();
  });

  app.whenReady().then(() => {
    startServer();
    createTray();
    createWindow();
  });
}

app.on('window-all-closed', (e) => {
  e.preventDefault();
});

app.on('before-quit', () => {
  if (serverProcess) serverProcess.kill();
});
