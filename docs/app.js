// Arch Linux + GNOME 51 Rice — Faithful Interactive Environment (app.js)
(function () {
  'use strict';

  // 1. REAL WALLPAPERS & EXTRACTED PYWAL 16-COLOR PALETTES
  const WALLPAPERS = [
    {
      id: "wallpaper_atual.jpg",
      filename: "wallpaper_atual.jpg",
      url: "assets/wallpapers/wallpaper_atual.jpg",
      logo: "assets/fastfetch/john_wuthering.png",
      special: { background: "#000000", foreground: "#e79fa8", cursor: "#e79fa8" },
      colors: {
        color0: "#000000", color1: "#9F2024", color2: "#D92123", color3: "#D2292E",
        color4: "#A03A46", color5: "#DA3A47", color6: "#A44F5B", color7: "#e79fa8",
        color8: "#a16f75", color9: "#9F2024", color10: "#D92123", color11: "#D2292E",
        color12: "#A03A46", color13: "#DA3A47", color14: "#A44F5B", color15: "#e79fa8"
      }
    },
    {
      id: "pinterest_621356079891537088.jpg",
      filename: "pinterest_621356079891537088.jpg",
      url: "assets/wallpapers/pinterest_621356079891537088.jpg",
      logo: "assets/fastfetch/endfield.png",
      special: { background: "#0c0501", foreground: "#e3cf99", cursor: "#e3cf99" },
      colors: {
        color0: "#0c0501", color1: "#894D03", color2: "#9E6A0C", color3: "#F77601",
        color4: "#BE830D", color5: "#D49B20", color6: "#D9AA36", color7: "#e3cf99",
        color8: "#9e906b", color9: "#894D03", color10: "#9E6A0C", color11: "#F77601",
        color12: "#BE830D", color13: "#D49B20", color14: "#D9AA36", color15: "#e3cf99"
      }
    },
    {
      id: "pinterest_621356079891536790.jpg",
      filename: "pinterest_621356079891536790.jpg",
      url: "assets/wallpapers/pinterest_621356079891536790.jpg",
      logo: "assets/fastfetch/john_starrail.png",
      special: { background: "#030406", foreground: "#acb9c9", cursor: "#acb9c9" },
      colors: {
        color0: "#030406", color1: "#2A4459", color2: "#2D4C69", color3: "#2A5771",
        color4: "#4B576E", color5: "#3A6A85", color6: "#5B6D90", color7: "#acb9c9",
        color8: "#78818c", color9: "#2A4459", color10: "#2D4C69", color11: "#2A5771",
        color12: "#4B576E", color13: "#3A6A85", color14: "#5B6D90", color15: "#acb9c9"
      }
    },
    {
      id: "pinterest_621356079891536786.jpg",
      filename: "pinterest_621356079891536786.jpg",
      url: "assets/wallpapers/pinterest_621356079891536786.jpg",
      logo: "assets/fastfetch/john_arknights.png",
      special: { background: "#0f1010", foreground: "#f4cab2", cursor: "#f4cab2" },
      colors: {
        color0: "#0f1010", color1: "#91473B", color2: "#9F6359", color3: "#D4755E",
        color4: "#BB8270", color5: "#D18771", color6: "#F29173", color7: "#f4cab2",
        color8: "#aa8d7c", color9: "#91473B", color10: "#9F6359", color11: "#D4755E",
        color12: "#BB8270", color13: "#D18771", color14: "#F29173", color15: "#f4cab2"
      }
    },
    {
      id: "pinterest_621356079891536792.jpg",
      filename: "pinterest_621356079891536792.jpg",
      url: "assets/wallpapers/pinterest_621356079891536792.jpg",
      logo: "assets/fastfetch/john_genshin.png",
      special: { background: "#0c120f", foreground: "#efdcc2", cursor: "#efdcc2" },
      colors: {
        color0: "#0c120f", color1: "#768443", color2: "#A78F6B", color3: "#D5AF65",
        color4: "#DCA372", color5: "#B4A68B", color6: "#E3B388", color7: "#efdcc2",
        color8: "#a79a87", color9: "#768443", color10: "#A78F6B", color11: "#D5AF65",
        color12: "#DCA372", color13: "#B4A68B", color14: "#E3B388", color15: "#efdcc2"
      }
    },
    {
      id: "pinterest_621356079891536822.jpg",
      filename: "pinterest_621356079891536822.jpg",
      url: "assets/wallpapers/pinterest_621356079891536822.jpg",
      logo: "assets/fastfetch/john_endfield.png",
      special: { background: "#020409", foreground: "#e4dad4", cursor: "#e4dad4" },
      colors: {
        color0: "#020409", color1: "#A14F64", color2: "#906B72", color3: "#9C7A84",
        color4: "#898080", color5: "#A69494", color6: "#CEACA8", color7: "#e4dad4",
        color8: "#9f9894", color9: "#A14F64", color10: "#906B72", color11: "#9C7A84",
        color12: "#898080", color13: "#A69494", color14: "#CEACA8", color15: "#e4dad4"
      }
    },
    {
      id: "pinterest_621356079891536803.jpg",
      filename: "pinterest_621356079891536803.jpg",
      url: "assets/wallpapers/pinterest_621356079891536803.jpg",
      logo: "assets/fastfetch/john_zenless.png",
      special: { background: "#0A1112", foreground: "#b4b8ab", cursor: "#b4b8ab" },
      colors: {
        color0: "#0A1112", color1: "#54613E", color2: "#393D41", color3: "#3B4D43",
        color4: "#485749", color5: "#556652", color6: "#68735F", color7: "#b4b8ab",
        color8: "#7d8077", color9: "#54613E", color10: "#393D41", color11: "#3B4D43",
        color12: "#485749", color13: "#556652", color14: "#68735F", color15: "#b4b8ab"
      }
    },
    {
      id: "pinterest_621356079891536846.jpg",
      filename: "pinterest_621356079891536846.jpg",
      url: "assets/wallpapers/pinterest_621356079891536846.jpg",
      logo: "assets/fastfetch/wuthering.png",
      special: { background: "#16120f", foreground: "#d7c5a3", cursor: "#d7c5a3" },
      colors: {
        color0: "#16120f", color1: "#7C613C", color2: "#705942", color3: "#705F48",
        color4: "#8B633A", color5: "#90714C", color6: "#A38D63", color7: "#d7c5a3",
        color8: "#968972", color9: "#7C613C", color10: "#705942", color11: "#705F48",
        color12: "#8B633A", color13: "#90714C", color14: "#A38D63", color15: "#d7c5a3"
      }
    },
    {
      id: "pinterest_621356079891537084.jpg",
      filename: "pinterest_621356079891537084.jpg",
      url: "assets/wallpapers/pinterest_621356079891537084.jpg",
      logo: "assets/fastfetch/arknights.png",
      special: { background: "#0E1218", foreground: "#cec8c1", cursor: "#cec8c1" },
      colors: {
        color0: "#0E1218", color1: "#4B525F", color2: "#505765", color3: "#6F7176",
        color4: "#7F7E7F", color5: "#84827E", color6: "#918C86", color7: "#cec8c1",
        color8: "#908c87", color9: "#4B525F", color10: "#505765", color11: "#6F7176",
        color12: "#7F7E7F", color13: "#84827E", color14: "#918C86", color15: "#cec8c1"
      }
    }
  ];

  // Installed Apps for Wofi drun (Alt + F)
  const DRUN_APPS = [
    { name: "System Tray Control Panel (XAMPP Edition)", desc: "Gerenciador de 297 serviços systemd, portas e autostart (Polkit sem senha)", icon: "fa-solid fa-server text-orange-500", action: () => toggleWindow('win-xampp') },
    { name: "REA — Reverse Engineer Anything", desc: "Suite de engenharia reversa ELF/PE (Ghidra Headless + radare2)", icon: "fa-solid fa-microchip text-sky-400", action: () => toggleWindow('win-rea') },
    { name: "WezTerm (GPU Accelerated)", desc: "Emulador de terminal com FiraMono Nerd Font e Pywal 85% opacity (Super+T)", icon: "fa-solid fa-terminal text-amber-400", action: () => focusDualTerminals() },
    { name: "WPGTK / Pywal Wallpaper Switcher", desc: "Seletor Wofi 3 colunas com recalculação automática de 16 cores (Alt+W)", icon: "fa-solid fa-palette text-rose-400", action: () => openWofiWallpaper() },
    { name: "ZenNote (HudNote Quick Notes)", desc: "Bloco de notas flutuante sempre no topo com abas e markdown (Super+N)", icon: "fa-solid fa-note-sticky text-blue-400", action: () => toggleOverlay('hudnote') },
    { name: "btop++ System & Kernel Monitor", desc: "Monitor de CPU, ZRAM 8GB, Dirty I/O 64MB e Google BBR TCP", icon: "fa-solid fa-chart-line text-emerald-400", action: () => { focusDualTerminals(); setRightTerminalMode('btop'); } },
    { name: "CAVA Audio Visualizer", desc: "Visualizador de frequências em tempo real sincronizado via cava-pywalsync.sh", icon: "fa-solid fa-wave-square text-purple-400", action: () => { focusDualTerminals(); setRightTerminalMode('cava'); } },
    { name: "Wlogout Power Session Menu", desc: "Menu de sessão com wallpaper borrado: Lock, Reboot, Shutdown, Suspend (Alt+L)", icon: "fa-solid fa-power-off text-red-400", action: () => openOverlay('wlogout') },
    { name: "OpenWhip Visual Overlay", desc: "Simulação física Verlet de chicote no System Tray", icon: "fa-solid fa-wand-magic-sparkles text-yellow-400", action: () => toggleWhipOverlay() },
    { name: "Rclone Cloud Sync (dev-sync)", desc: "Sincronização GoogleDrive e DriveUnimar com bypass do Tracker3", icon: "fa-solid fa-cloud-arrow-up text-cyan-400", action: () => runTerminalCommand('dev-sync status') }
  ];

  let currentWpIdx = 0;
  let musicPlaying = true;
  let demoClockSec = null; // When non-null, drives deterministic rendering for video capture

  function hexToRgbStr(hex) {
    const clean = hex.replace('#', '');
    const n = parseInt(clean, 16);
    return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
  }

  // 2. APPLY WALLPAPER & PYWAL HOOKS (wallpaper-picker.sh + hooks.sh)
  window.applyWallpaper = function (index, notify = true) {
    currentWpIdx = (index + WALLPAPERS.length) % WALLPAPERS.length;
    const wp = WALLPAPERS[currentWpIdx];

    // Crossfade wallpaper slides
    const currSlide = document.getElementById('wallpaper-bg-curr');
    currSlide.style.backgroundImage = `url('${wp.url}')`;

    // Update Wlogout blurred background (wlogout-pywalsync.sh)
    const wlogoutBg = document.getElementById('wlogout-blur-bg');
    if (wlogoutBg) wlogoutBg.style.backgroundImage = `url('${wp.url}')`;

    // Update CSS root variables (.cache/wal/colors-waybar.css)
    const root = document.documentElement;
    root.style.setProperty('--wal-bg', wp.special.background);
    root.style.setProperty('--wal-bg-rgb', hexToRgbStr(wp.special.background));
    root.style.setProperty('--wal-fg', wp.special.foreground);
    root.style.setProperty('--wal-cursor', wp.special.cursor);
    root.style.setProperty('--color1-rgb', hexToRgbStr(wp.colors.color1));

    for (let i = 0; i <= 8; i++) {
      root.style.setProperty(`--color${i}`, wp.colors[`color${i}`]);
    }

    // Update Fastfetch logo & 16-color chips (fastfetch_auto.sh .reload_flag)
    const ffLogo = document.getElementById('ff-logo-img');
    if (ffLogo) ffLogo.src = wp.logo;

    const ffSquares = document.getElementById('ff-palette-squares');
    if (ffSquares) {
      ffSquares.innerHTML = '';
      for (let i = 1; i <= 8; i++) {
        const chip = document.createElement('span');
        chip.className = 'ff-color-chip';
        chip.style.backgroundColor = wp.colors[`color${i}`];
        chip.title = `color${i}: ${wp.colors[`color${i}`]}`;
        ffSquares.appendChild(chip);
      }
    }

    // Update CAVA gradient indicator (cava-pywalsync.sh)
    const c1Dot = document.getElementById('cava-c1-dot');
    const c5Dot = document.getElementById('cava-c5-dot');
    const gradLabel = document.getElementById('cava-gradient-label');
    if (c1Dot) c1Dot.style.backgroundColor = wp.colors.color1;
    if (c5Dot) c5Dot.style.backgroundColor = wp.colors.color5;
    if (gradLabel) gradLabel.textContent = `${wp.colors.color1} → ${wp.colors.color5}`;

    // Re-render Wofi grid selection if open
    renderWofiWallpapers(document.getElementById('wofi-search')?.value || '');

    if (notify) {
      triggerNotification(
        'Sucesso! (wallpaper-picker.sh)',
        `Wallpaper ${wp.filename} aplicado • Pywal + Cava + Wlogout + Fastfetch sincronizados.`
      );
    }
  };

  // 3. GNOME NOTIFICATION TOAST (notify-send)
  window.triggerNotification = function (title, body) {
    const area = document.getElementById('gnome-notification-area');
    if (!area) return;
    const toast = document.createElement('div');
    toast.className = 'gnome-toast';
    toast.innerHTML = `
      <i class="fa-solid fa-wand-magic-sparkles text-lg" style="color: var(--color5)"></i>
      <div>
        <div style="font-weight: 700; font-size: 12.5px; color: #fff;">${title}</div>
        <div style="font-size: 11.5px; color: rgba(255,255,255,0.78); margin-top: 2px;">${body}</div>
      </div>
    `;
    area.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.25s ease';
      setTimeout(() => toast.remove(), 260);
    }, 3200);
  };

  // 4. WOFI WALLPAPER PICKER (Alt + W) & APP LAUNCHER (Alt + F)
  const wofiBackdrop = document.getElementById('wofi-backdrop');
  const wofiSearch = document.getElementById('wofi-search');
  const wofiWallGrid = document.getElementById('wofi-wall-grid');
  const wofiDrunGrid = document.getElementById('wofi-drun-grid');
  let wofiMode = 'wallpaper';

  function renderWofiWallpapers(query = '') {
    if (!wofiWallGrid) return;
    const q = query.toLowerCase().trim();
    const list = WALLPAPERS.filter(w => !q || w.filename.toLowerCase().includes(q));
    wofiWallGrid.innerHTML = list.map((w) => {
      const idx = WALLPAPERS.indexOf(w);
      const isSel = idx === currentWpIdx;
      return `
        <div class="wofi-wall-entry ${isSel ? 'selected' : ''}" onclick="selectWofiWallpaper(${idx})">
          <div class="wofi-wall-thumb" style="background-image: url('${w.url}')"></div>
          <div class="wofi-wall-meta">
            <span>${w.filename}</span>
            <div class="wofi-wall-dots">
              <span style="background:${w.colors.color1}"></span>
              <span style="background:${w.colors.color3}"></span>
              <span style="background:${w.colors.color5}"></span>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  function renderWofiDrun(query = '') {
    if (!wofiDrunGrid) return;
    const q = query.toLowerCase().trim();
    const list = DRUN_APPS.filter(a => !q || a.name.toLowerCase().includes(q) || a.desc.toLowerCase().includes(q));
    wofiDrunGrid.innerHTML = list.map((a, i) => `
      <div class="wofi-drun-entry" onclick="launchDrunApp(${DRUN_APPS.indexOf(a)})">
        <i class="${a.icon} text-xl w-7 text-center"></i>
        <div>
          <div style="font-weight:700; font-size:13px; color:#fff;">${a.name}</div>
          <div style="font-size:11px; color:rgba(255,255,255,0.65); margin-top:2px;">${a.desc}</div>
        </div>
      </div>
    `).join('');
  }

  window.selectWofiWallpaper = function (idx) {
    applyWallpaper(idx, true);
    closeOverlay('wofi');
  };

  window.launchDrunApp = function (idx) {
    closeOverlay('wofi');
    if (DRUN_APPS[idx] && DRUN_APPS[idx].action) DRUN_APPS[idx].action();
  };

  window.openWofiWallpaper = function () {
    wofiMode = 'wallpaper';
    wofiBackdrop.classList.remove('hidden');
    wofiWallGrid.classList.remove('hidden');
    wofiDrunGrid.classList.add('hidden');
    wofiSearch.placeholder = 'Wallpaper (1920x1080) — 3 colunas (Alt+W)...';
    wofiSearch.value = '';
    renderWofiWallpapers('');
    setTimeout(() => wofiSearch.focus(), 40);
  };

  window.openWofiDrun = function () {
    wofiMode = 'drun';
    wofiBackdrop.classList.remove('hidden');
    wofiDrunGrid.classList.remove('hidden');
    wofiWallGrid.classList.add('hidden');
    wofiSearch.placeholder = 'Pesquisar aplicativos do rice (wofi --show drun)...';
    wofiSearch.value = '';
    renderWofiDrun('');
    setTimeout(() => wofiSearch.focus(), 40);
  };

  if (wofiSearch) {
    wofiSearch.addEventListener('input', (e) => {
      if (wofiMode === 'wallpaper') renderWofiWallpapers(e.target.value);
      else renderWofiDrun(e.target.value);
    });
  }

  // 5. OVERLAYS & WINDOWS MANAGEMENT
  window.openOverlay = function (name) {
    if (name === 'wlogout') {
      document.getElementById('wlogout-overlay').classList.remove('hidden');
      document.getElementById('quick-settings-popover').classList.add('hidden');
    } else if (name === 'hudnote') {
      document.getElementById('win-hudnote').classList.remove('hidden');
    } else if (name === 'wofi') {
      openWofiWallpaper();
    }
  };

  window.closeOverlay = function (name) {
    if (name === 'wlogout') document.getElementById('wlogout-overlay').classList.add('hidden');
    if (name === 'hudnote') document.getElementById('win-hudnote').classList.add('hidden');
    if (name === 'wofi') document.getElementById('wofi-backdrop').classList.add('hidden');
  };

  window.toggleOverlay = function (name) {
    if (name === 'hudnote') {
      document.getElementById('win-hudnote').classList.toggle('hidden');
    } else if (name === 'wlogout') {
      document.getElementById('wlogout-overlay').classList.toggle('hidden');
    }
  };

  window.toggleWindow = function (winId) {
    const el = document.getElementById(winId);
    if (!el) return;
    const isHidden = el.classList.contains('hidden');
    // Close other fullscreen app window if opening one
    ['win-xampp', 'win-rea'].forEach(id => {
      if (id !== winId) document.getElementById(id)?.classList.add('hidden');
    });
    if (isHidden) {
      el.classList.remove('hidden');
      updateWorkspacePillForWindow(winId);
    } else {
      el.classList.add('hidden');
      updateWorkspacePillForWindow(null);
    }
  };

  window.closeWindow = function (winId) {
    document.getElementById(winId)?.classList.add('hidden');
    updateWorkspacePillForWindow(null);
  };

  window.maximizeAppWindow = function (winId) {
    const el = document.getElementById(winId);
    if (!el) return;
    if (el.style.inset === '-8px') {
      el.style.inset = '0';
    } else {
      el.style.inset = '-8px';
    }
  };

  function updateWorkspacePillForWindow(winId) {
    const pills = document.querySelectorAll('.ws-pill');
    pills.forEach(p => p.classList.remove('active'));
    if (winId === 'win-xampp') pills[1]?.classList.add('active');
    else if (winId === 'win-rea') pills[2]?.classList.add('active');
    else pills[0]?.classList.add('active');
  }

  window.switchWorkspace = function (wsNum) {
    document.getElementById('win-xampp')?.classList.add('hidden');
    document.getElementById('win-rea')?.classList.add('hidden');
    if (wsNum === 2) {
      document.getElementById('win-xampp')?.classList.remove('hidden');
      updateWorkspacePillForWindow('win-xampp');
    } else if (wsNum === 3) {
      document.getElementById('win-rea')?.classList.remove('hidden');
      updateWorkspacePillForWindow('win-rea');
    } else {
      updateWorkspacePillForWindow(null);
    }
  };

  window.focusDualTerminals = function () {
    switchWorkspace(1);
    document.getElementById('zsh-input')?.focus();
  };

  window.setRightTerminalMode = function (mode) {
    const vCava = document.getElementById('view-cava');
    const vBtop = document.getElementById('view-btop');
    const bCava = document.getElementById('tab-btn-cava');
    const bBtop = document.getElementById('tab-btn-btop');
    if (mode === 'btop') {
      vCava.classList.remove('active');
      vBtop.classList.add('active');
      bCava.classList.remove('active');
      bBtop.classList.add('active');
    } else {
      vBtop.classList.remove('active');
      vCava.classList.add('active');
      bBtop.classList.remove('active');
      bCava.classList.add('active');
    }
  };

  window.toggleQuickSettings = function () {
    document.getElementById('quick-settings-popover')?.classList.toggle('hidden');
  };

  window.toggleCalendarPopover = function () {
    triggerNotification('GNOME Calendar & Clima (São Paulo)', 'Sexta-feira, 30 de Outubro • 23°C Céu Limpo • Sem eventos pendentes.');
  };

  window.toggleCaffeine = function () {
    const btn = document.getElementById('btn-caffeine');
    btn.classList.toggle('active');
    const on = btn.classList.contains('active');
    triggerNotification('Caffeine / KeepAwake', on ? 'Ativado: suspensão automática e bloqueio de tela desabilitados.' : 'Desativado: gerenciamento padrão de energia.');
  };

  window.retileWindows = function () {
    const grid = document.getElementById('tiling-grid');
    if (!grid) return;
    if (grid.style.gridTemplateColumns === '1fr 1fr') {
      grid.style.gridTemplateColumns = '1.08fr 0.92fr';
      triggerNotification('Tiling Assistant + Pop Shell', 'Layout restaurado: Dual Split Assimétrico (gap=8px)');
    } else {
      grid.style.gridTemplateColumns = '1fr 1fr';
      triggerNotification('Tiling Assistant + Pop Shell', 'Janelas alinhadas 50% / 50% (Super + Left / Right)');
    }
  };

  window.toggleMusicPlay = function () {
    musicPlaying = !musicPlaying;
    const icon = document.getElementById('panel-play-icon');
    const stateEl = document.getElementById('conky-play-state');
    if (icon) icon.className = musicPlaying ? 'fa-solid fa-pause text-[11px]' : 'fa-solid fa-play text-[11px]';
    if (stateEl) stateEl.textContent = musicPlaying ? 'Playing' : 'Paused';
  };

  window.toggleWhipOverlay = function () {
    const whip = document.getElementById('openwhip-iframe');
    if (!whip) return;
    whip.classList.toggle('hidden');
    const active = !whip.classList.contains('hidden');
    triggerNotification('OpenWhip Visual', active ? 'Chicote Verlet ativado! Mova o mouse rápido para estalar (Clique no ícone novamente para guardar).' : 'Chicote recolhido.');
  };

  window.triggerWlogoutAction = function (label, cmd) {
    closeOverlay('wlogout');
    triggerNotification(`Wlogout: ${label}`, `Comando disparado: ${cmd}`);
  };

  // 6. ZENNOTE / HUDNOTE LOGIC (scripts/hudnote.sh)
  const NOTES = {
    'principal': `# ZenNote — Bloco de Notas Rápido (Super + N)\n# Salvo automaticamente em ~/.notas_rapidas.txt\n\n[x] Configurar Pywal + WPGTK + hooks (WezTerm, Cava, Wofi, Wlogout)\n[x] System Tray XAMPP Edition com regra Polkit sem senha\n[x] Otimizar Kernel: vm.dirty_background_bytes = 64MB + TCP BBR + ZRAM\n[x] Configurar Rclone systemd (GoogleDrive + DriveUnimar)\n[ ] Gravar showcase do rice para o repositório GitHub`,
    'atalhos-rice': `# Atalhos Principais do Rice (org-gnome.dconf)\n\n• Alt + W   -> Wallpaper Picker (Wofi 3 colunas + Pywal)\n• Alt + F   -> Wofi App Launcher (drun)\n• Alt + L   -> Wlogout Power Menu\n• Alt + Q   -> GNOME Console (kgx)\n• Super + T -> WezTerm (GPU Accelerated)\n• Super + N -> ZenNote (este bloco flutuante)\n• Super + ←/→ -> Tiling Assistant (divisão de janelas)`
  };
  let activeNoteKey = 'principal';
  const hudEditor = document.getElementById('hudnote-editor');
  const hudStats = document.getElementById('hudnote-stats');
  const hudSaved = document.getElementById('hudnote-saved');

  function updateHudStats() {
    if (!hudEditor) return;
    const text = hudEditor.value;
    NOTES[activeNoteKey] = text;
    const lines = text.split('\n').length;
    const words = text.trim() ? text.trim().split(/\s+/).length : 0;
    const chars = text.length;
    if (hudStats) hudStats.textContent = `Linhas: ${lines}   Palavras: ${words}   Caracteres: ${chars}`;
    const now = new Date().toLocaleTimeString('pt-BR');
    if (hudSaved) hudSaved.textContent = `Salvo ${now} (~/.notas_rapidas.txt)`;
  }

  window.switchHudNote = function (key) {
    activeNoteKey = key;
    document.querySelectorAll('.hudnote-tab').forEach(t => {
      t.classList.toggle('active', t.dataset.note === key);
    });
    if (hudEditor) {
      hudEditor.value = NOTES[key] || '';
      updateHudStats();
    }
  };

  window.createNewHudNote = function () {
    const name = `nota-${Object.keys(NOTES).length + 1}`;
    NOTES[name] = `# ${name}\n\n[ ] Nova anotação rápida...`;
    const tabs = document.getElementById('hudnote-tabs');
    const btn = document.createElement('button');
    btn.className = 'hudnote-tab';
    btn.dataset.note = name;
    btn.textContent = name;
    btn.onclick = () => switchHudNote(name);
    tabs.insertBefore(btn, tabs.lastElementChild);
    switchHudNote(name);
  };

  window.insertHudTodo = function () {
    if (!hudEditor) return;
    hudEditor.value += '\n[ ] Nova tarefa';
    updateHudStats();
  };

  window.insertHudTimestamp = function () {
    if (!hudEditor) return;
    const now = new Date().toLocaleString('pt-BR');
    hudEditor.value += `\n[${now}] `;
    updateHudStats();
  };

  if (hudEditor) {
    hudEditor.value = NOTES['principal'];
    hudEditor.addEventListener('input', updateHudStats);
    updateHudStats();
  }

  // 7. ZSH INTERACTIVE SHELL COMMANDS
  const zshInput = document.getElementById('zsh-input');
  const zshHistory = document.getElementById('zsh-history');

  function appendZshOutput(cmd, html) {
    if (!zshHistory) return;
    const block = document.createElement('div');
    block.style.marginTop = '6px';
    block.innerHTML = `
      <div style="color: #4ade80; font-weight: 700;">❯ <span style="color:#fff;">${cmd}</span></div>
      <div style="color: #d4d4d8; margin-top: 2px; padding-left: 10px; border-left: 2px solid var(--color1);">${html}</div>
    `;
    zshHistory.appendChild(block);
    zshHistory.scrollTop = zshHistory.scrollHeight;
  }

  window.runTerminalCommand = function (rawCmd) {
    const cmd = rawCmd.trim();
    if (!cmd) return;
    const lower = cmd.toLowerCase();

    if (lower === 'help') {
      appendZshOutput(cmd, `
        <b>Comandos reais do Rice disponíveis:</b><br>
        • <code>wal</code> ou <code>alt+w</code> — Abre o seletor Wofi de Wallpapers + Pywal<br>
        • <code>xampp</code> ou <code>tray</code> — Abre o System Tray Control Panel (XAMPP Edition)<br>
        • <code>rea</code> — Abre o REA Studio (Reverse Engineer Anything)<br>
        • <code>hudnote</code> — Abre o bloco de notas rápido ZenNote (Super+N)<br>
        • <code>btop</code> / <code>cava</code> — Alterna o terminal direito entre CAVA e btop++<br>
        • <code>wlogout</code> — Abre o menu de sessão Wlogout (Alt+L)<br>
        • <code>sysctl</code> — Exibe as otimizações de Kernel (/etc/sysctl.d)<br>
        • <code>dev-sync status</code> — Verifica status dos mounts Rclone (GoogleDrive)<br>
        • <code>clear</code> — Limpa o histórico do terminal
      `);
    } else if (lower === 'wal' || lower === 'wpg' || lower === 'wallpaper' || lower === 'alt+w') {
      appendZshOutput(cmd, `Abrindo <code>~/.local/bin/wallpaper-picker.sh</code> (Wofi 3 colunas)...`);
      openWofiWallpaper();
    } else if (lower === 'xampp' || lower === 'tray' || lower === 'services') {
      appendZshOutput(cmd, `Iniciando <code>python3 ~/system-tray/app.py</code> em http://127.0.0.1:4999...`);
      toggleWindow('win-xampp');
    } else if (lower === 'rea' || lower === 'ghidra') {
      appendZshOutput(cmd, `Iniciando <code>python3 ~/rea-studio/app.py</code> em http://127.0.0.1:4321...`);
      toggleWindow('win-rea');
    } else if (lower === 'hudnote' || lower === 'notes') {
      appendZshOutput(cmd, `Abrindo <code>~/scripts/hudnote.sh</code> (ZenNote)...`);
      openOverlay('hudnote');
    } else if (lower === 'wlogout') {
      appendZshOutput(cmd, `Executando <code>wlogout-pywalsync.sh && wlogout</code>...`);
      openOverlay('wlogout');
    } else if (lower === 'wofi') {
      openWofiDrun();
    } else if (lower === 'btop') {
      setRightTerminalMode('btop');
      appendZshOutput(cmd, `Monitor <code>btop++</code> aberto no painel direito.`);
    } else if (lower === 'cava') {
      setRightTerminalMode('cava');
      appendZshOutput(cmd, `Visualizador <code>cava</code> ativo no painel direito.`);
    } else if (lower === 'fastfetch' || lower === 'ffa') {
      applyWallpaper((currentWpIdx + 1) % WALLPAPERS.length, false);
      appendZshOutput(cmd, `Fastfetch recarregado com nova paleta Pywal (${WALLPAPERS[currentWpIdx].filename}).`);
    } else if (lower === 'sysctl') {
      appendZshOutput(cmd, `
        <code>vm.dirty_background_bytes = 67108864 (64 MB)</code><br>
        <code>vm.dirty_bytes = 134217728 (128 MB)</code><br>
        <code>net.ipv4.tcp_congestion_control = bbr</code><br>
        <code>net.core.default_qdisc = fq</code><br>
        <code>zram0: 8.0 GiB (algo: zstd, swappiness: 100)</code>
      `);
    } else if (lower.startsWith('dev-sync') || lower === 'dev-push' || lower === 'dev-pull') {
      appendZshOutput(cmd, `[Rclone Sync] GoogleDrive:dev-workspace ↔ ~/temp • Tudo sincronizado (Tracker3 index bypass ativo).`);
    } else if (lower === 'clear') {
      zshHistory.innerHTML = '';
    } else {
      appendZshOutput(cmd, `zsh: comando executado no ambiente simulado. Digite <code>help</code> para ver os atalhos do rice.`);
    }
  };

  if (zshInput) {
    zshInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const val = zshInput.value;
        zshInput.value = '';
        runTerminalCommand(val);
      }
    });
  }

  // 8. REAL KEYBOARD SHORTCUTS (org-gnome.dconf custom-keybindings)
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      closeOverlay('wofi');
      closeOverlay('wlogout');
      closeOverlay('hudnote');
      document.getElementById('quick-settings-popover')?.classList.add('hidden');
      return;
    }
    if (e.altKey && (e.key === 'w' || e.key === 'W')) {
      e.preventDefault();
      openWofiWallpaper();
    } else if (e.altKey && (e.key === 'f' || e.key === 'F')) {
      e.preventDefault();
      openWofiDrun();
    } else if (e.altKey && (e.key === 'l' || e.key === 'L')) {
      e.preventDefault();
      openOverlay('wlogout');
    } else if (e.altKey && (e.key === 'q' || e.key === 'Q')) {
      e.preventDefault();
      focusDualTerminals();
    }
  });

  // Listen to messages from embedded System Tray iframe
  window.addEventListener('message', (e) => {
    if (e.data && e.data.type === 'TRAY_STATE_CHANGE') {
      const activeCount = e.data.services.filter(s => s.is_active).length;
      const badge = document.getElementById('top-xampp-count');
      if (badge) badge.textContent = activeCount;
    }
  });

  // 9. CAVA 60FPS CANVAS VISUALIZER (.config/cava/config + cava-pywalsync.sh)
  const cavaCanvas = document.getElementById('cava-canvas');
  const cavaCtx = cavaCanvas ? cavaCanvas.getContext('2d') : null;
  const NUM_BARS = 44;
  const barSmooth = new Array(NUM_BARS).fill(0.2);

  function renderCavaFrame(tSec) {
    if (!cavaCanvas || !cavaCtx) return;
    const rect = cavaCanvas.parentElement.getBoundingClientRect();
    if (rect.width > 0 && (cavaCanvas.width !== Math.floor(rect.width - 32) || cavaCanvas.height !== Math.floor(rect.height - 32))) {
      cavaCanvas.width = Math.floor(rect.width - 32);
      cavaCanvas.height = Math.floor(rect.height - 32);
    }

    const W = cavaCanvas.width;
    const H = cavaCanvas.height;
    cavaCtx.clearRect(0, 0, W, H);

    const wp = WALLPAPERS[currentWpIdx];
    const c1 = wp.colors.color1;
    const c5 = wp.colors.color5;

    const gap = 4;
    const barW = Math.max(4, (W - (NUM_BARS - 1) * gap) / NUM_BARS);

    for (let i = 0; i < NUM_BARS; i++) {
      const norm = i / NUM_BARS;
      const bassEnvelope = Math.exp(-norm * 1.8) * 0.45 + 0.35;
      const w1 = Math.sin(tSec * 6.5 + i * 0.32) * 0.5 + 0.5;
      const w2 = Math.cos(tSec * 10.2 - i * 0.48) * 0.5 + 0.5;
      const w3 = Math.sin(tSec * 3.1 + i * 0.15) * 0.5 + 0.5;
      const target = musicPlaying ? Math.min(0.96, Math.max(0.08, (w1 * 0.45 + w2 * 0.35 + w3 * 0.2) * bassEnvelope + 0.12)) : 0.06;

      if (demoClockSec !== null) {
        barSmooth[i] = target;
      } else {
        barSmooth[i] += (target - barSmooth[i]) * 0.28;
      }

      const bh = Math.floor(barSmooth[i] * (H - 8));
      const x = i * (barW + gap);
      const y = H - bh;

      const grad = cavaCtx.createLinearGradient(0, y, 0, H);
      grad.addColorStop(0, c5);
      grad.addColorStop(1, c1);
      cavaCtx.fillStyle = grad;

      // Segmented LED blocks like real CAVA in WezTerm
      const segH = 5;
      const segGap = 2;
      for (let sy = H - segH; sy >= y; sy -= (segH + segGap)) {
        cavaCtx.fillRect(x, sy, barW, segH);
      }
    }
  }

  function animLoop(nowMs) {
    if (demoClockSec === null) {
      renderCavaFrame(nowMs * 0.001);
      requestAnimationFrame(animLoop);
    }
  }

  // Populate BTOP CPU core bars
  const btopCoresEl = document.getElementById('btop-cpu-bars');
  if (btopCoresEl) {
    const usages = [18, 12, 24, 9, 15, 11, 21, 8, 14, 19, 10, 16];
    btopCoresEl.innerHTML = usages.map((u, idx) => `
      <div class="btop-core">
        <span style="color:var(--color5)">C${idx}</span>
        <span>${u}%</span>
      </div>
    `).join('');
  }

  // Live Clock & Conky Metrics Updater
  function updateClocksAndMetrics() {
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, '0');
    const mm = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');

    const conkyTime = document.getElementById('conky-time');
    if (conkyTime) conkyTime.textContent = `${hh}:${mm}`;

    const p10kTime = document.getElementById('p10k-time');
    if (p10kTime) p10kTime.textContent = `${hh}:${mm}:${ss}`;

    const days = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];
    const months = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
    const shortMonths = ['jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'];

    const conkyDate = document.getElementById('conky-date');
    if (conkyDate) conkyDate.textContent = `${days[now.getDay()]}, ${now.getDate()} de ${months[now.getMonth()]}`;

    const panelClock = document.getElementById('panel-clock');
    if (panelClock) panelClock.textContent = `${now.getDate()} de ${shortMonths[now.getMonth()]} ${hh}:${mm}`;
  }
  updateClocksAndMetrics();
  setInterval(updateClocksAndMetrics, 2000);

  // Deterministic hook for Headless Chrome 1080p Video Capture
  window.__setDemoTime = function (tSec) {
    demoClockSec = tSec;
    renderCavaFrame(tSec);
  };

  // Initialize with wallpaper_atual.jpg
  applyWallpaper(0, false);
  requestAnimationFrame(animLoop);
})();
