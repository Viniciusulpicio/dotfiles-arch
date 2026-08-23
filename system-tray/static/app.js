// System Tray - Instant Reactive & Optimistic XAMPP Control Panel Logic

let activeSection = 'services'; // 'services' | 'autostart'
let allServices = [];
let allAutostartApps = [];
let installedAppsList = [];
let currentFilter = 'favorites';
let searchQuery = '';
let selectedServiceForLogs = '';
let isFetching = false;
let detailsCache = {};
let pendingActions = new Set();

// DOM Elements
const searchInput = document.getElementById('search-input');
const searchClear = document.getElementById('search-clear');
const servicesTbody = document.getElementById('services-tbody');
const totalCount = document.getElementById('total-count');
const btnRefresh = document.getElementById('btn-refresh');
const refreshIcon = document.getElementById('refresh-icon');
const btnStopAllDev = document.getElementById('btn-stop-all-dev');
const toastContainer = document.getElementById('toast-container');
const xamppConsole = document.getElementById('xampp-console');

const navBtnServices = document.getElementById('nav-btn-services');
const navBtnAutostart = document.getElementById('nav-btn-autostart');
const sectionServices = document.getElementById('section-services');
const sectionAutostart = document.getElementById('section-autostart');
const badgeAutostartCount = document.getElementById('badge-autostart-count');
const autostartTbody = document.getElementById('autostart-tbody');

// Stats Elements
const statActive = document.getElementById('stat-active');
const statRam = document.getElementById('stat-ram');
const sidebarBoot = document.getElementById('sidebar-boot');
const sidebarRam = document.getElementById('sidebar-ram');

// Modal Elements
const modalLogs = document.getElementById('modal-logs');
const modalServiceName = document.getElementById('modal-service-name');
const modalLogsContent = document.getElementById('modal-logs-content');
const modalLogLines = document.getElementById('modal-log-lines');
const modalLogRefresh = document.getElementById('modal-log-refresh');
const modalLogClose = document.getElementById('modal-log-close');
const modalLogCloseBtn = document.getElementById('modal-log-close-btn');

const modalAddApp = document.getElementById('modal-add-app');
const modalAppSelect = document.getElementById('modal-app-select');
const modalAppName = document.getElementById('modal-app-name');
const modalAppExec = document.getElementById('modal-app-exec');
const modalAppComment = document.getElementById('modal-app-comment');

// --- REAL-TIME XAMPP CONSOLE ---
function logToConsole(tag, message, type = 'info') {
  const time = new Date().toLocaleTimeString('pt-BR');
  const typeColors = {
    info: 'text-slate-300',
    success: 'text-emerald-400',
    error: 'text-rose-400',
    warn: 'text-amber-400',
    system: 'text-sky-400'
  };
  const color = typeColors[type] || 'text-slate-300';
  
  const line = document.createElement('div');
  line.className = 'py-0.5';
  line.innerHTML = `<span class="text-slate-500">${time}</span> <span class="font-bold text-orange-400">[${tag}]</span> <span class="${color}">${message}</span>`;
  
  xamppConsole.appendChild(line);
  xamppConsole.scrollTop = xamppConsole.scrollHeight;
}

function clearConsole() {
  xamppConsole.innerHTML = '';
  logToConsole('main', 'Console limpo.', 'system');
}

// --- TOAST NOTIFICATIONS ---
function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  const borders = {
    success: 'border-emerald-600/50 bg-[#141b16] text-emerald-300',
    error: 'border-rose-600/50 bg-[#221618] text-rose-300',
    info: 'border-[#3b4252] bg-[#181b20] text-slate-200',
    warning: 'border-amber-600/50 bg-[#221d14] text-amber-300'
  };
  const icons = {
    success: '<i class="fa-solid fa-check text-emerald-400"></i>',
    error: '<i class="fa-solid fa-xmark text-rose-400"></i>',
    info: '<i class="fa-solid fa-info text-blue-400"></i>',
    warning: '<i class="fa-solid fa-triangle-exclamation text-amber-400"></i>'
  };

  toast.className = `flex items-center gap-3 p-3 rounded border shadow-xl text-xs font-medium transition-all duration-200 transform translate-y-2 opacity-0 pointer-events-auto ${borders[type] || borders.info}`;
  toast.innerHTML = `
    <div>${icons[type] || icons.info}</div>
    <div class="flex-1 leading-snug">${message}</div>
    <button class="text-slate-400 hover:text-white" onclick="this.parentElement.remove()"><i class="fa-solid fa-xmark"></i></button>
  `;

  toastContainer.appendChild(toast);
  setTimeout(() => toast.classList.remove('translate-y-2', 'opacity-0'), 10);
  setTimeout(() => {
    toast.classList.add('opacity-0', 'translate-y-2');
    setTimeout(() => toast.remove(), 250);
  }, 3500);
}

// --- SECTION SWITCHER ---
function switchSection(section) {
  activeSection = section;
  if (section === 'services') {
    navBtnServices.className = 'px-3.5 py-1.5 rounded bg-[#252a34] text-white border border-[#3b4252] transition flex items-center gap-2';
    navBtnAutostart.className = 'px-3.5 py-1.5 rounded text-slate-400 hover:text-white transition flex items-center gap-2';
    sectionServices.classList.remove('hidden');
    sectionServices.classList.add('flex');
    sectionAutostart.classList.add('hidden');
    sectionAutostart.classList.remove('flex');
    renderServicesTable();
  } else {
    navBtnAutostart.className = 'px-3.5 py-1.5 rounded bg-[#252a34] text-white border border-[#3b4252] transition flex items-center gap-2';
    navBtnServices.className = 'px-3.5 py-1.5 rounded text-slate-400 hover:text-white transition flex items-center gap-2';
    sectionAutostart.classList.remove('hidden');
    sectionAutostart.classList.add('flex');
    sectionServices.classList.add('hidden');
    sectionServices.classList.remove('flex');
    fetchAutostartApps();
  }
}

// --- FETCH DATA (WITH AUTO CACHE REFRESH) ---
async function fetchServices(silent = false) {
  if (isFetching) return;
  isFetching = true;
  if (!silent) refreshIcon.classList.add('animate-spin');

  try {
    const [servicesRes, statsRes, autostartRes] = await Promise.all([
      fetch('/api/services?t=' + Date.now()),
      fetch('/api/system/stats?t=' + Date.now()),
      fetch('/api/autostart?t=' + Date.now())
    ]);

    const servicesData = await servicesRes.json();
    const statsData = await statsRes.json();
    const autostartData = await autostartRes.json();

    if (servicesData.success) {
      allServices = servicesData.services;
      totalCount.innerText = servicesData.total;
      if (activeSection === 'services') renderServicesTable();
    }

    if (statsData.success) {
      const s = statsData.stats;
      statActive.innerText = s.active;
      statRam.innerText = `${s.dev_memory_mb} MB`;
      if (sidebarBoot) sidebarBoot.innerText = s.boot_enabled;
      if (sidebarRam) sidebarRam.innerText = `${s.dev_memory_mb} MB`;
    }

    if (autostartData.success) {
      allAutostartApps = autostartData.apps;
      badgeAutostartCount.innerText = allAutostartApps.filter(a => a.is_enabled).length;
      if (activeSection === 'autostart') renderAutostartTable();
    }
  } catch (err) {
    if (!silent) {
      showToast("Erro ao conectar com o backend local.", "error");
      logToConsole('error', 'Falha ao conectar com o servidor local.', 'error');
    }
  } finally {
    isFetching = false;
    refreshIcon.classList.remove('animate-spin');
  }
}

// Fetch single service details (PID / RAM)
async function fetchServiceDetails(serviceName) {
  try {
    const res = await fetch(`/api/service/details?name=${encodeURIComponent(serviceName)}&t=` + Date.now());
    const data = await res.json();
    if (data.success) {
      detailsCache[serviceName] = data.details;
      
      const pidEl = document.getElementById(`pid-${serviceName}`);
      if (pidEl) {
        pidEl.innerText = data.details.pid > 0 ? data.details.pid : '-';
        if (data.details.pid > 0) pidEl.classList.add('text-emerald-400', 'font-bold');
      }

      const rowEl = document.getElementById(`row-${serviceName}`);
      if (rowEl && data.details.is_running) {
        rowEl.classList.add('bg-emerald-950/10');
      }
    }
  } catch (e) {}
}

// --- FILTER SERVICES ---
function getFilteredServices() {
  let list = allServices;

  if (searchQuery.trim()) {
    const q = searchQuery.toLowerCase().trim();
    list = list.filter(s => 
      s.name.toLowerCase().includes(q) || 
      s.display_name.toLowerCase().includes(q) || 
      s.description.toLowerCase().includes(q) ||
      s.category.toLowerCase().includes(q)
    );
  }

  if (currentFilter === 'favorites') {
    list = list.filter(s => s.is_favorite);
    if (list.length === 0 && !searchQuery.trim()) {
      list = allServices.filter(s => s.is_dev);
    }
  } else if (currentFilter === 'dev') {
    list = list.filter(s => s.is_dev);
  } else if (currentFilter === 'active') {
    list = list.filter(s => s.is_active);
  } else if (currentFilter === 'inactive') {
    list = list.filter(s => !s.is_active);
  }

  return list;
}

// --- RENDER XAMPP SERVICES TABLE ---
function renderServicesTable() {
  const filtered = getFilteredServices();

  if (filtered.length === 0) {
    servicesTbody.innerHTML = `
      <tr>
        <td colspan="7" class="py-10 text-center text-slate-500 font-sans">
          <i class="fa-solid fa-filter text-lg mb-1"></i>
          <p>Nenhum módulo encontrado com esse filtro.</p>
        </td>
      </tr>
    `;
    return;
  }

  servicesTbody.innerHTML = filtered.map(s => {
    const isRunning = s.is_running;
    const isActive = s.is_active;
    const isBoot = s.is_boot_enabled;
    const isFav = s.is_favorite;
    const isPending = pendingActions.has(s.name);
    const cached = detailsCache[s.name] || {};
    const pid = cached.pid || s.pid || (isActive ? '...' : '-');
    const port = s.port || '-';

    return `
      <tr id="row-${s.name}" class="hover:bg-[#202530] transition border-b border-[#2e3440] ${isActive ? 'bg-[#15231c]/40' : ''}">
        
        <!-- Column 1: Module Name -->
        <td class="py-2.5 px-3">
          <div class="flex items-center gap-2">
            <button onclick="handleToggleFavorite('${s.name}')" title="${isFav ? 'Remover dos favoritos' : 'Favoritar módulo'}" class="text-xs ${isFav ? 'text-amber-400' : 'text-slate-600 hover:text-amber-400'}">
              <i class="${isFav ? 'fa-solid' : 'fa-regular'} fa-star"></i>
            </button>
            <div>
              <span class="font-bold text-white text-xs font-mono">${s.display_name}</span>
              ${isActive ? '<span class="inline-block w-2 h-2 rounded-full bg-emerald-500 ml-1.5" title="Rodando"></span>' : ''}
            </div>
          </div>
        </td>

        <!-- Column 2: PID -->
        <td class="py-2.5 px-2 text-center font-mono text-xs text-slate-300">
          <span id="pid-${s.name}" class="${isActive ? 'text-emerald-400 font-bold' : 'text-slate-500'}">${pid}</span>
        </td>

        <!-- Column 3: Port -->
        <td class="py-2.5 px-2 text-center font-mono text-xs">
          <span class="${port !== '-' ? 'text-orange-400 font-bold' : 'text-slate-500'}">${port}</span>
        </td>

        <!-- Column 4: Actions (Start / Stop) -->
        <td class="py-2.5 px-3 text-center">
          <div class="flex items-center justify-center gap-1">
            ${isActive ? `
              <button 
                onclick="handleServiceAction('${s.name}', 'stop')" 
                id="btn-act-${s.name}"
                ${isPending ? 'disabled' : ''}
                class="xampp-btn xampp-btn-stop py-1 px-3 rounded text-xs"
              >
                ${isPending ? '<i class="fa-solid fa-spinner animate-spin"></i>' : '<i class="fa-solid fa-stop text-[10px] mr-1"></i> Stop'}
              </button>
              <button 
                onclick="handleServiceAction('${s.name}', 'restart')" 
                title="Reiniciar módulo"
                class="xampp-btn py-1 px-2 rounded text-xs text-slate-300 hover:text-white"
              >
                <i class="fa-solid fa-rotate text-[10px]"></i>
              </button>
            ` : `
              <button 
                onclick="handleServiceAction('${s.name}', 'start')" 
                id="btn-act-${s.name}"
                ${isPending ? 'disabled' : ''}
                class="xampp-btn xampp-btn-start py-1 px-4 rounded text-xs"
              >
                ${isPending ? '<i class="fa-solid fa-spinner animate-spin"></i>' : '<i class="fa-solid fa-play text-[10px] mr-1"></i> Start'}
              </button>
            `}
          </div>
        </td>

        <!-- Column 5: DEDICATED PROMINENT BOOT BUTTON (Ligar no Boot) -->
        <td class="py-2.5 px-3 text-center">
          <button 
            onclick="handleToggleBoot('${s.name}', ${!isBoot})"
            class="px-2.5 py-1 rounded text-xs font-mono font-bold transition flex items-center justify-center gap-1.5 w-full mx-auto shadow-sm ${
              isBoot 
                ? 'bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 border border-amber-500/40' 
                : 'bg-[#252a34] hover:bg-[#2e3440] text-slate-400 hover:text-white border border-[#3b4252]'
            }"
            title="${isBoot ? 'Inicia ao ligar o computador (Clique para DESATIVAR e economizar RAM)' : 'NÃO inicia ao ligar o PC (Clique para ATIVAR)'}"
          >
            <i class="fa-solid ${isBoot ? 'fa-toggle-on text-amber-400' : 'fa-toggle-off text-slate-500'} text-xs"></i>
            <span>${isBoot ? 'ON (No Boot)' : 'OFF (Desativado)'}</span>
          </button>
        </td>

        <!-- Column 6: Logs -->
        <td class="py-2.5 px-2 text-center">
          <button 
            onclick="openLogsModal('${s.name}')" 
            class="xampp-btn py-1 px-2 rounded text-xs text-slate-300 hover:text-white"
            title="Ver logs do módulo"
          >
            <i class="fa-solid fa-file-lines text-[10px] mr-1"></i> Logs
          </button>
        </td>

        <!-- Column 7: Description in Portuguese -->
        <td class="py-2.5 px-4">
          <p class="text-[12px] text-slate-300 leading-snug" title="${s.description}">
            ${s.description || '-'}
          </p>
        </td>

      </tr>
    `;
  }).join('');

  filtered.forEach(s => {
    if (s.is_active) fetchServiceDetails(s.name);
  });
}

// --- AUTOSTART APPS TABLE ---
async function fetchAutostartApps() {
  try {
    const res = await fetch('/api/autostart?t=' + Date.now());
    const data = await res.json();
    if (data.success) {
      allAutostartApps = data.apps;
      badgeAutostartCount.innerText = allAutostartApps.filter(a => a.is_enabled).length;
      renderAutostartTable();
    }
  } catch (e) {
    showToast('Erro ao carregar aplicativos de inicialização.', 'error');
  }
}

function renderAutostartTable() {
  if (allAutostartApps.length === 0) {
    autostartTbody.innerHTML = `
      <tr>
        <td colspan="6" class="py-10 text-center text-slate-500">
          <i class="fa-solid fa-rocket text-xl text-slate-600 mb-1"></i>
          <p class="font-semibold text-slate-400">Nenhum aplicativo configurado para autostart</p>
        </td>
      </tr>
    `;
    return;
  }

  autostartTbody.innerHTML = allAutostartApps.map(app => {
    const isEnabled = app.is_enabled;
    const isUser = app.is_user;

    return `
      <tr class="hover:bg-[#202530] transition border-b border-[#2e3440]">
        <td class="py-2.5 px-4 text-center">
          <div class="w-7 h-7 rounded bg-[#111317] border border-[#2e3440] flex items-center justify-center text-orange-400 text-xs">
            <i class="fa-solid fa-cube"></i>
          </div>
        </td>
        <td class="py-2.5 px-4">
          <div class="font-bold text-white text-xs">${app.name}</div>
          <p class="text-[11px] text-slate-400">${app.comment || 'Aplicativo de usuário'}</p>
        </td>
        <td class="py-2.5 px-4 font-mono text-[11px] text-slate-300 max-w-xs truncate" title="${app.exec}">
          ${app.exec}
        </td>
        <td class="py-2.5 px-4">
          <span class="px-2 py-0.5 rounded text-[10px] ${isUser ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20' : 'bg-blue-500/10 text-blue-400 border border-blue-500/20'}">
            ${isUser ? 'Usuário' : 'Sistema'}
          </span>
        </td>
        <td class="py-2.5 px-4 text-center">
          <button 
            onclick="handleToggleAutostart('${app.filename}', ${!isEnabled})"
            class="px-2.5 py-1 rounded text-xs font-mono font-bold transition flex items-center justify-center gap-1.5 mx-auto ${
              isEnabled 
                ? 'bg-emerald-500/20 hover:bg-emerald-500/30 text-emerald-300 border border-emerald-500/40' 
                : 'bg-[#252a34] hover:bg-[#2e3440] text-slate-400 hover:text-white border border-[#3b4252]'
            }"
          >
            <span class="w-2 h-2 rounded-full ${isEnabled ? 'bg-emerald-400' : 'bg-slate-500'}"></span>
            <span>${isEnabled ? 'ATIVO NO LOGIN' : 'DESATIVADO'}</span>
          </button>
        </td>
        <td class="py-2.5 px-4 text-right">
          <button onclick="handleDeleteAutostart('${app.filename}', '${app.name}')" title="Remover da inicialização" class="xampp-btn py-1 px-2.5 rounded text-rose-400 hover:text-rose-300">
            <i class="fa-solid fa-trash-can text-xs"></i>
          </button>
        </td>
      </tr>
    `;
  }).join('');
}

// --- OPTIMISTIC & INSTANT ACTIONS ---

// 1. INSTANT FAVORITE TOGGLE (NO F5 NEEDED)
async function handleToggleFavorite(serviceName) {
  const s = allServices.find(x => x.name === serviceName || x.display_name === serviceName);
  if (s) {
    s.is_favorite = !s.is_favorite;
    logToConsole('main', `${s.display_name} ${s.is_favorite ? 'adicionado aos favoritos ⭐' : 'removido dos favoritos'}.`, 'info');
    renderServicesTable(); // Instant UI update!
  }

  try {
    const res = await fetch('/api/service/favorite', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ service: serviceName })
    });
    const data = await res.json();
    if (data.success && s) {
      s.is_favorite = data.is_favorite;
      renderServicesTable();
    }
  } catch (e) {
    if (s) {
      s.is_favorite = !s.is_favorite; // Revert on network failure
      renderServicesTable();
    }
  }
}

// 2. INSTANT BOOT TOGGLE (NO F5 NEEDED)
async function handleToggleBoot(serviceName, shouldEnable) {
  const s = allServices.find(x => x.name === serviceName);
  const prevBoot = s ? s.is_boot_enabled : !shouldEnable;

  // Optimistic instant visual update
  if (s) {
    s.is_boot_enabled = shouldEnable;
    s.boot_state = shouldEnable ? 'enabled' : 'disabled';
    renderServicesTable(); // Update instantly on click!
  }

  const action = shouldEnable ? 'enable' : 'disable';
  logToConsole('boot', `Configurando boot de ${serviceName} para: ${action.toUpperCase()}...`, 'warn');

  try {
    const res = await fetch('/api/service/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ service: serviceName, action: action })
    });
    const data = await res.json();

    if (data.success) {
      const msg = shouldEnable 
        ? `${serviceName} configurado para INICIAR COM O PC (Boot ATIVO).` 
        : `${serviceName} DESATIVADO DO BOOT (Economizando 100% de RAM ao ligar o PC).`;
      logToConsole('boot', msg, 'success');
      showToast(msg, 'success');
      
      if (s && data.details) {
        s.is_boot_enabled = data.details.is_boot_enabled;
        s.boot_state = data.details.boot_state;
        renderServicesTable();
      }
    } else {
      if (s) {
        s.is_boot_enabled = prevBoot;
        s.boot_state = prevBoot ? 'enabled' : 'disabled';
        renderServicesTable();
      }
      logToConsole('error', `Erro ao alterar boot de ${serviceName}: ${data.message}`, 'error');
      showToast(`Erro ao alterar boot: ${data.message}`, 'error');
    }
  } catch (e) {
    if (s) {
      s.is_boot_enabled = prevBoot;
      renderServicesTable();
    }
  }
}

// 3. INSTANT SERVICE START/STOP (NO F5 NEEDED)
async function handleServiceAction(serviceName, action) {
  const s = allServices.find(x => x.name === serviceName);
  const prevActive = s ? s.is_active : false;

  pendingActions.add(serviceName);
  
  // Optimistic immediate visual state update
  if (s) {
    if (action === 'start') {
      s.is_active = true;
      s.is_running = true;
    } else if (action === 'stop') {
      s.is_active = false;
      s.is_running = false;
      s.pid = 0;
      if (detailsCache[serviceName]) detailsCache[serviceName].pid = 0;
    }
  }
  
  logToConsole('action', `Executando comando '${action}' em ${serviceName}...`, 'warn');
  renderServicesTable(); // Instant UI update!

  try {
    const res = await fetch('/api/service/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ service: serviceName, action: action })
    });
    const data = await res.json();

    if (data.success) {
      logToConsole('systemd', `${serviceName}: ${action.toUpperCase()} finalizado com sucesso.`, 'success');
      showToast(`${serviceName}: ${action} executado com sucesso.`, 'success');
      
      if (s && data.details) {
        s.is_active = data.details.is_active;
        s.is_running = data.details.is_running;
        s.pid = data.details.pid;
        detailsCache[serviceName] = data.details;
      }
    } else {
      if (s) {
        s.is_active = prevActive;
        s.is_running = prevActive;
      }
      logToConsole('error', `Falha ao executar ${action} em ${serviceName}: ${data.message || data.error}`, 'error');
      showToast(`Erro ao executar ${action} em ${serviceName}: ${data.message || data.error}`, 'error');
    }
  } catch (err) {
    if (s) s.is_active = prevActive;
    logToConsole('error', `Erro de comunicação na ação '${action}'.`, 'error');
  } finally {
    pendingActions.delete(serviceName);
    renderServicesTable();
    // Refresh stats in background
    fetch('/api/system/stats?t=' + Date.now()).then(r => r.json()).then(st => {
      if (st.success) {
        statActive.innerText = st.stats.active;
        statRam.innerText = `${st.stats.dev_memory_mb} MB`;
        if (sidebarRam) sidebarRam.innerText = `${st.stats.dev_memory_mb} MB`;
      }
    }).catch(()=>{});
  }
}

// 4. INSTANT AUTOSTART TOGGLE (NO F5 NEEDED)
async function handleToggleAutostart(filename, enabled) {
  const app = allAutostartApps.find(x => x.filename === filename);
  if (app) {
    app.is_enabled = enabled;
    badgeAutostartCount.innerText = allAutostartApps.filter(a => a.is_enabled).length;
    renderAutostartTable(); // Instant UI update!
  }

  try {
    const res = await fetch('/api/autostart/toggle', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filename: filename, enabled: enabled })
    });
    const data = await res.json();
    if (data.success) {
      logToConsole('autostart', `Aplicativo ${filename} ${enabled ? 'ativado no login' : 'desativado'}.`, 'success');
      showToast(enabled ? `Aplicativo ativado no autostart.` : `Aplicativo desativado do autostart.`, 'success');
    }
  } catch (e) {}
}

async function handleDeleteAutostart(filename, name) {
  if (!confirm(`Remover "${name}" da inicialização do sistema?`)) return;
  
  // Instant remove from table
  allAutostartApps = allAutostartApps.filter(x => x.filename !== filename);
  badgeAutostartCount.innerText = allAutostartApps.filter(a => a.is_enabled).length;
  renderAutostartTable();

  try {
    const res = await fetch('/api/autostart/delete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filename: filename })
    });
    const data = await res.json();
    if (data.success) {
      logToConsole('autostart', `Aplicativo "${name}" removido da inicialização.`, 'warn');
      showToast(`"${name}" removido com sucesso.`, 'success');
    }
  } catch (e) {}
}

async function startFavoriteServices() {
  const favs = allServices.filter(s => s.is_favorite && !s.is_active);
  if (favs.length === 0) {
    showToast('Todos os módulos favoritos já estão em execução.', 'info');
    return;
  }
  logToConsole('main', `Iniciando ${favs.length} módulos favoritos...`, 'warn');
  for (const s of favs) {
    await handleServiceAction(s.name, 'start');
  }
}

async function stopAllDevServices() {
  const runningDev = allServices.filter(s => s.is_active && (s.is_dev || s.is_favorite));
  if (runningDev.length === 0) {
    showToast('Nenhum módulo de desenvolvimento está em execução.', 'info');
    return;
  }
  const names = runningDev.map(s => s.display_name).join(', ');
  if (!confirm(`Parar ${runningDev.length} módulos de desenvolvimento (${names}) para liberar memória RAM?`)) return;

  logToConsole('main', `Parando ${runningDev.length} módulos para liberar RAM...`, 'warn');
  for (const s of runningDev) {
    await handleServiceAction(s.name, 'stop');
  }
  logToConsole('main', 'Todos os módulos foram parados. Memória RAM liberada.', 'success');
}

// --- LOGS MODAL ---
async function openLogsModal(serviceName) {
  selectedServiceForLogs = serviceName;
  modalServiceName.innerText = serviceName;
  modalLogsContent.innerText = 'Carregando logs do journalctl...';
  modalLogs.classList.remove('hidden');
  modalLogs.classList.add('flex');
  await refreshLogs();
}

async function refreshLogs() {
  if (!selectedServiceForLogs) return;
  const lines = modalLogLines.value || 50;
  try {
    const res = await fetch(`/api/service/logs?name=${encodeURIComponent(selectedServiceForLogs)}&lines=${lines}&t=` + Date.now());
    const data = await res.json();
    if (data.success) {
      modalLogsContent.innerText = data.logs || '(Sem logs recentes registrados)';
      modalLogsContent.scrollTop = modalLogsContent.scrollHeight;
    } else {
      modalLogsContent.innerText = `Erro ao ler logs: ${data.error}`;
    }
  } catch (e) {}
}

function closeLogsModal() {
  modalLogs.classList.add('hidden');
  modalLogs.classList.remove('flex');
  selectedServiceForLogs = '';
}

// --- ADD APP MODAL ---
async function openAddAppModal() {
  modalAddApp.classList.remove('hidden');
  modalAddApp.classList.add('flex');
  modalAppName.value = '';
  modalAppExec.value = '';
  modalAppComment.value = '';

  if (installedAppsList.length === 0) {
    try {
      const res = await fetch('/api/system/installed-apps?t=' + Date.now());
      const data = await res.json();
      if (data.success) {
        installedAppsList = data.apps;
        modalAppSelect.innerHTML = '<option value="">-- Selecione um aplicativo instalado --</option>' +
          installedAppsList.map((a, i) => `<option value="${i}">${a.name} (${a.exec})</option>`).join('');
      }
    } catch (e) {}
  }
}

function handleAppSelectChange(index) {
  if (index === '') return;
  const app = installedAppsList[parseInt(index)];
  if (app) {
    modalAppName.value = app.name;
    modalAppExec.value = app.exec;
    modalAppComment.value = app.comment || `Iniciar ${app.name} automaticamente`;
  }
}

function closeAddAppModal() {
  modalAddApp.classList.add('hidden');
  modalAddApp.classList.remove('flex');
}

async function submitAddApp() {
  const name = modalAppName.value.trim();
  const execCmd = modalAppExec.value.trim();
  const comment = modalAppComment.value.trim();

  if (!name || !execCmd) {
    showToast('Nome e Comando são obrigatórios.', 'warning');
    return;
  }

  try {
    const res = await fetch('/api/autostart/add', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: name, exec: execCmd, comment: comment })
    });
    const data = await res.json();
    if (data.success) {
      logToConsole('autostart', `Aplicativo "${name}" adicionado à inicialização.`, 'success');
      showToast(`"${name}" adicionado com sucesso!`, 'success');
      closeAddAppModal();
      await fetchAutostartApps();
    }
  } catch (e) {}
}

function openNetstatModal() {
  alert("Portas ativas e conexões podem ser visualizadas na coluna 'Porta' de cada serviço.");
}

function openConfigInfoModal() {
  alert("System Tray Control Panel (XAMPP Edition)\n\nGerenciador dinâmico de serviços systemd e autostart de aplicativos para Linux.\nDesenvolvido com foco em alta produtividade e zero consumo de RAM no boot.");
}

// --- INITIALIZATION ---
document.addEventListener('DOMContentLoaded', () => {
  logToConsole('main', 'System Tray Control Panel (XAMPP Edition) inicializado.', 'system');
  logToConsole('systemd', 'Varrendo serviços instalados no computador...', 'info');

  fetchServices().then(() => {
    logToConsole('systemd', `${allServices.length} serviços detectados dinamicamente via systemd.`, 'success');
  });

  setInterval(() => fetchServices(true), 5000);

  searchInput.addEventListener('input', (e) => {
    searchQuery = e.target.value;
    if (searchQuery) searchClear.classList.remove('hidden');
    else searchClear.classList.add('hidden');
    renderServicesTable();
  });

  searchClear.addEventListener('click', () => {
    searchInput.value = '';
    searchQuery = '';
    searchClear.classList.add('hidden');
    renderServicesTable();
  });

  document.querySelectorAll('.filter-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.filter-tab').forEach(t => {
        t.className = 'filter-tab px-3 py-1 rounded font-medium transition text-slate-400 hover:text-white';
      });
      tab.className = 'filter-tab px-3 py-1 rounded font-semibold transition bg-orange-600 text-white';
      currentFilter = tab.getAttribute('data-filter');
      renderServicesTable();
    });
  });

  btnRefresh.addEventListener('click', () => {
    logToConsole('main', 'Atualizando lista de serviços...', 'info');
    fetchServices(false);
  });

  btnStopAllDev.addEventListener('click', stopAllDevServices);

  modalLogClose.addEventListener('click', closeLogsModal);
  modalLogCloseBtn.addEventListener('click', closeLogsModal);
  modalLogRefresh.addEventListener('click', refreshLogs);
  modalLogLines.addEventListener('change', refreshLogs);
  modalLogs.addEventListener('click', (e) => {
    if (e.target === modalLogs) closeLogsModal();
  });

  modalAddApp.addEventListener('click', (e) => {
    if (e.target === modalAddApp) closeAddAppModal();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && document.activeElement !== searchInput && activeSection === 'services') {
      e.preventDefault();
      searchInput.focus();
    } else if (e.key === 'Escape') {
      if (!modalLogs.classList.contains('hidden')) closeLogsModal();
      if (!modalAddApp.classList.contains('hidden')) closeAddAppModal();
    }
  });
});
