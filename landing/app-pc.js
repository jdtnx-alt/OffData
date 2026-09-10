/**
 * OffData Web - Aplicación de Escritorio y Móvil
 * Integración Bidireccional con Supabase Cloud, Base de Datos, Validación Inteligente y Roles
 */

(function () {
  'use strict';

  // ─── USUARIOS PREDEFINIDOS DEL SISTEMA ────────────────────────
  const USUARIOS = [
    {
      id: 'user-admin-001',
      email: 'admin@offdata.com',
      password: 'OffData2026*',
      nombre: 'Administrador Principal',
      rol: 'admin',
      iniciales: 'AD'
    },
    {
      id: 'user-encuestador-001',
      email: 'encuestador1@offdata.com',
      password: 'Encuestador2026*',
      nombre: 'Carlos Mendoza',
      rol: 'encuestador',
      iniciales: 'CM'
    },
    {
      id: 'user-encuestador-002',
      email: 'encuestador2@offdata.com',
      password: 'Encuestador2026*',
      nombre: 'Ana Gómez',
      rol: 'encuestador',
      iniciales: 'AG'
    }
  ];

  // Configuración Supabase por Defecto (obtenida de .env)
  const DEFAULT_SUPABASE_URL = 'https://jgcodpaztgpoiithqrad.supabase.co';
  const DEFAULT_SUPABASE_KEY = 'sb_publishable_BWNOdxaXJC49mX-ZbQ6cPw_ikVAc4nJ';

  // Claves de Almacenamiento Local
  const STORAGE_KEY_DB = 'offdata_pc_personas_v2';
  const STORAGE_KEY_SESSION = 'offdata_pc_user_session';
  const STORAGE_KEY_NET = 'offdata_pc_is_online';
  const STORAGE_KEY_SUPA_URL = 'offdata_cfg_supabase_url';
  const STORAGE_KEY_SUPA_KEY = 'offdata_cfg_supabase_key';

  // Estado en Memoria
  let currentUser = null;
  let isOnline = true;
  let validationDebounceTimer = null;
  let supabaseClient = null;
  let isCloudConnected = false;
  let realtimeChannel = null;
  let currentRecordFilter = 'mine'; // 'mine' | 'all'

  window.switchRecordFilter = function(filter) {
    currentRecordFilter = filter;
    renderRecords();
  };

  // ─── INICIALIZACIÓN DE SUPABASE CLIENT ─────────────────────────
  function getSupabaseConfig() {
    let key = localStorage.getItem(STORAGE_KEY_SUPA_KEY);
    if (!key || key.includes('BWN0') || key.length < 30) {
      key = DEFAULT_SUPABASE_KEY;
      localStorage.setItem(STORAGE_KEY_SUPA_KEY, DEFAULT_SUPABASE_KEY);
    }
    return {
      url: localStorage.getItem(STORAGE_KEY_SUPA_URL) || DEFAULT_SUPABASE_URL,
      key: key
    };
  }

  function initSupabaseClient() {
    const config = getSupabaseConfig();
    if (window.supabase && config.url && config.key) {
      try {
        supabaseClient = window.supabase.createClient(config.url, config.key);
        initRealtimeSubscription();
      } catch (e) {
        console.warn('No se pudo inicializar el cliente de Supabase:', e);
        supabaseClient = null;
      }
    }
  }

  function initRealtimeSubscription() {
    if (!supabaseClient) return;
    try {
      if (realtimeChannel) {
        supabaseClient.removeChannel(realtimeChannel);
      }
      realtimeChannel = supabaseClient.channel('public-personas-channel')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'personas' }, (payload) => {
          console.log('⚡ Cambio en Supabase recibido en tiempo real:', payload);
          // Recargar datos desde la nube cuando la APK u otro usuario actualice
          syncWithSupabase(false);
        })
        .subscribe();
    } catch (e) {
      console.warn('Error al suscribir a Realtime:', e);
    }
  }

  // ─── SINCRONIZACIÓN NUBE (SUPABASE ↔ PC) ───────────────────────
  async function syncWithSupabase(showNotification = false) {
    if (!isOnline) {
      updateCloudStatusUI(false, 'Fuera de Línea');
      return;
    }

    if (!supabaseClient) {
      initSupabaseClient();
    }

    if (!supabaseClient) {
      updateCloudStatusUI(false, 'Sin Supabase Configurado');
      return;
    }

    const cloudBtn = document.getElementById('btn-open-cloud-config');
    const cloudText = document.getElementById('cloud-status-text');
    if (cloudText) cloudText.textContent = 'Sincronizando...';

    try {
      // 1. Primero, subir cualquier registro local pendiente de sincronización
      const localDb = getLocalDatabase();
      const pendientes = localDb.filter(r => !r.sincronizado);

      if (pendientes.length > 0) {
        for (const item of pendientes) {
          const payload = mapToSupabasePayload(item);
          await supabaseClient.from('personas').upsert(payload);
          item.sincronizado = true;
        }
        saveLocalDatabase(localDb);
      }

      // 2. Descargar todos los registros vigentes de la nube (donde la APK también guarda)
      const { data, error } = await supabaseClient
        .from('personas')
        .select('*')
        .neq('is_deleted', true)
        .order('created_at', { ascending: false });

      if (error) throw error;

      isCloudConnected = true;
      updateCloudStatusUI(true, 'Cloud Conectado (Supabase)');

      // 3. Mapear datos de Supabase a formato local
      const cloudMapped = (data || []).map(row => ({
        id: row.id,
        cedula: row.cedula,
        nombre_completo: row.nombre_completo || 'Sin Nombre',
        primer_nombre: (row.nombre_completo || '').split(' ')[0] || '',
        primer_apellido: (row.nombre_completo || '').split(' ')[1] || '',
        fecha_nacimiento: row.fecha_nacimiento,
        telefono: row.telefono,
        direccion: row.direccion || [row.tipo_via, row.numero_via, row.barrio ? `Brr. ${row.barrio}` : null].filter(Boolean).join(' '),
        ciudad: row.ciudad,
        barrio: row.barrio,
        encuestador_id: row.encuestador_id,
        encuestador_nombre: row.encuestador_nombre,
        sincronizado: true,
        created_at: row.created_at
      }));

      // Guardar en la base de datos local
      saveLocalDatabase(cloudMapped);
      renderRecords();

      if (showNotification) {
        const totalMine = cloudMapped.filter(r => r.encuestador_id === currentUser?.id).length;
        const infoRol = currentUser?.rol === 'admin'
          ? `Total en nube: ${cloudMapped.length} personas (Vista Global Admin).`
          : `Tienes ${totalMine} encuesta(s) a tu nombre. Total registradas en el equipo: ${cloudMapped.length}.`;
        alert(`✅ Sincronización exitosa con Supabase.\n${infoRol}`);
      }
    } catch (e) {
      console.warn('Conexión a Supabase no disponible o pausada:', e);
      isCloudConnected = false;
      updateCloudStatusUI(false, 'Nube Offline (Cache Local)');
      if (showNotification) {
        alert('⚠️ No se pudo conectar con Supabase. Revisa la URL o si tu proyecto está pausado en el panel de Supabase. Los registros se mantendrán guardados localmente.');
      }
    }
  }

  function mapToSupabasePayload(item) {
    const isUUID = item.id && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id);
    return {
      id: isUUID ? item.id : (window.crypto?.randomUUID ? window.crypto.randomUUID() : undefined),
      cedula: item.cedula,
      nombre_completo: item.nombre_completo,
      fecha_nacimiento: item.fecha_nacimiento,
      tipo_via: item.tipo_via || 'Calle',
      numero_via: item.numero_via || '',
      barrio: item.barrio || '',
      ciudad: item.ciudad || 'Bucaramanga',
      telefono: item.telefono || '',
      es_principal: true,
      registro_numero: 1,
      sync_version: 1,
      is_synced: 1,
      created_at: item.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString(),
      device_id: 'web_pc_dashboard',
      is_deleted: false,
      encuestador_id: item.encuestador_id,
      encuestador_nombre: item.encuestador_nombre,
      encuestador_email: item.encuestador_email || '',
      direccion: item.direccion || [item.tipo_via, item.numero_via, item.barrio ? `Brr. ${item.barrio}` : null].filter(Boolean).join(' ')
    };
  }

  function updateCloudStatusUI(connected, label) {
    const btn = document.getElementById('btn-open-cloud-config');
    const text = document.getElementById('cloud-status-text');
    if (btn) {
      btn.className = `btn-cloud-config ${connected ? 'connected' : 'disconnected'}`;
    }
    if (text) {
      text.textContent = label;
    }
  }

  // ─── GESTIÓN DE BASE DE DATOS LOCAL ───────────────────────────
  function getLocalDatabase() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY_DB);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      console.error('Error al leer la base de datos:', e);
      return [];
    }
  }

  function saveLocalDatabase(data) {
    try {
      localStorage.setItem(STORAGE_KEY_DB, JSON.stringify(data));
    } catch (e) {
      console.error('Error al guardar en base de datos:', e);
    }
  }

  // ─── ALGORITMOS DE NORMALIZACIÓN Y LEVENSHTEIN ────────────────
  function normalizarTexto(str) {
    if (!str) return '';
    return str
      .toLowerCase()
      .trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '') // Remover tildes
      .replace(/\s+/g, ' ');           // Normalizar espacios múltiples
  }

  function calcularLevenshtein(a, b) {
    const s1 = String(a || '');
    const s2 = String(b || '');
    const m = s1.length;
    const n = s2.length;

    if (m === 0) return n;
    if (n === 0) return m;

    const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));

    for (let i = 0; i <= m; i++) dp[i][0] = i;
    for (let j = 0; j <= n; j++) dp[0][j] = j;

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        const costo = s1[i - 1] === s2[j - 1] ? 0 : 1;
        dp[i][j] = Math.min(
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + costo
        );
      }
    }
    return dp[m][n];
  }

  /**
   * Valida una persona contra TODA la base de datos global
   */
  function buscarCoincidenciaInteligente(cedulaNueva, nombreNuevo, fechaNacimientoNueva) {
    const db = getLocalDatabase();
    if (!db || db.length === 0) return null;

    const cNueva = String(cedulaNueva || '').trim();
    if (cNueva.length < 5) return null;

    const nomNorm = normalizarTexto(nombreNuevo);
    const fechaNorm = String(fechaNacimientoNueva || '').trim();

    for (const persona of db) {
      const cExistente = String(persona.cedula || '').trim();
      const distancia = calcularLevenshtein(cNueva, cExistente);

      // Si la cédula es idéntica o tiene <= 3 dígitos de diferencia
      if (distancia <= 3) {
        const nomExistente = normalizarTexto(persona.nombre_completo);
        const fechaExistente = String(persona.fecha_nacimiento || '').trim();

        const nombresIguales = nomNorm && nomExistente && (
          nomNorm === nomExistente ||
          nomExistente.includes(nomNorm) ||
          nomNorm.includes(nomExistente)
        );
        const fechasIguales = fechaNorm && fechaExistente && (fechaNorm === fechaExistente);

        // Caso Duplicado Bloqueado: Mismo nombre y misma fecha
        if (nombresIguales && fechasIguales) {
          return {
            tipo: 'DUPLICADO_BLOQUEADO',
            distancia,
            personaCoincidente: persona,
            mensaje: `La persona ya se encuentra registrada en el sistema con el nombre "${persona.nombre_completo}" y cédula ${persona.cedula}. Registrado por: ${persona.encuestador_nombre || 'Otro usuario'}.`
          };
        }

        // Caso Cédula Idéntica exacta
        if (distancia === 0) {
          return {
            tipo: 'CEDULA_IDENTICA',
            distancia: 0,
            personaCoincidente: persona,
            mensaje: `Esta cédula (${persona.cedula}) ya está registrada a nombre de "${persona.nombre_completo}".`
          };
        }

        // Caso Cédula Parecida (Posible error de digitación)
        return {
          tipo: 'CEDULA_PARECIDA',
          distancia,
          personaCoincidente: persona,
          mensaje: `Existe una cédula muy parecida (${persona.cedula}) registrada a nombre de "${persona.nombre_completo}" (difiere en solo ${distancia} dígito${distancia > 1 ? 's' : ''}). Verifica que el documento sea correcto.`
        };
      }
    }

    return null;
  }

  // ─── CONTROL DE SESIÓN ────────────────────────────────────────
  function initSession() {
    try {
      const savedUser = localStorage.getItem(STORAGE_KEY_SESSION);
      if (savedUser) {
        currentUser = JSON.parse(savedUser);
      }
      const savedNet = localStorage.getItem(STORAGE_KEY_NET);
      if (savedNet !== null) {
        isOnline = savedNet === 'true';
      }
    } catch (e) {
      currentUser = null;
    }

    if (currentUser) {
      showAppView();
    } else {
      showLoginView();
    }
  }

  function login(email, password) {
    const cleanEmail = normalizarTexto(email);
    const user = USUARIOS.find(u => u.email.toLowerCase() === cleanEmail && u.password === password);

    if (user) {
      currentUser = user;
      localStorage.setItem(STORAGE_KEY_SESSION, JSON.stringify(user));
      showAppView();
      return true;
    }

    // Mostrar error
    const errorAlert = document.getElementById('login-error-alert');
    const errorText = document.getElementById('login-error-text');
    if (errorAlert && errorText) {
      errorText.textContent = 'Credenciales no válidas. Revisa el correo y la contraseña.';
      errorAlert.style.display = 'flex';
    }
    return false;
  }

  function logout() {
    currentUser = null;
    localStorage.removeItem(STORAGE_KEY_SESSION);
    showLoginView();
  }

  function showLoginView() {
    const viewLogin = document.getElementById('view-login');
    const viewApp = document.getElementById('view-app');
    if (viewLogin) viewLogin.style.display = 'flex';
    if (viewApp) viewApp.style.display = 'none';

    const formLogin = document.getElementById('form-login');
    if (formLogin) formLogin.reset();
    const errorAlert = document.getElementById('login-error-alert');
    if (errorAlert) errorAlert.style.display = 'none';
  }

  function showAppView() {
    const viewLogin = document.getElementById('view-login');
    const viewApp = document.getElementById('view-app');
    if (viewLogin) viewLogin.style.display = 'none';
    if (viewApp) viewApp.style.display = 'block';

    updateUserInterface();
    renderRecords();

    // Iniciar sincronización con Supabase Cloud
    syncWithSupabase(false);
  }

  function updateUserInterface() {
    if (!currentUser) return;

    const avatarEl = document.getElementById('app-user-avatar');
    const nameEl = document.getElementById('app-user-name');
    const roleEl = document.getElementById('app-user-role');

    if (avatarEl) avatarEl.textContent = currentUser.iniciales || 'US';
    if (nameEl) nameEl.textContent = currentUser.nombre;
    if (roleEl) {
      const isAdmin = currentUser.rol === 'admin';
      roleEl.textContent = isAdmin ? 'ADMINISTRADOR' : 'ENCUESTADOR';
      roleEl.className = `user-role-badge ${isAdmin ? 'badge-admin' : 'badge-encuestador'}`;
    }

    const totalLabelEl = document.getElementById('pc-stat-total-label');
    const recordsTitleEl = document.getElementById('pc-records-title');
    const recordsSubtitleEl = document.getElementById('pc-records-subtitle');

    if (currentUser.rol === 'admin') {
      currentRecordFilter = 'all';
      if (totalLabelEl) totalLabelEl.textContent = 'Total en Plataforma';
      if (recordsTitleEl) recordsTitleEl.textContent = 'Personas Encuestadas (Vista Global Admin)';
      if (recordsSubtitleEl) recordsSubtitleEl.textContent = 'Acceso total: visualizando registros de todos los encuestadores y APKs';
    } else {
      currentRecordFilter = 'mine';
      if (totalLabelEl) totalLabelEl.textContent = 'Mis Encuestas';
      if (recordsTitleEl) recordsTitleEl.textContent = 'Mis Registros de Encuesta';
      if (recordsSubtitleEl) recordsSubtitleEl.textContent = `Visualizando encuestas realizadas por ${currentUser.nombre}`;
    }

    updateNetworkUI();
  }

  // ─── CONTROL DE CONECTIVIDAD ──────────────────────────────────
  function toggleNetwork() {
    isOnline = !isOnline;
    localStorage.setItem(STORAGE_KEY_NET, String(isOnline));
    updateNetworkUI();

    if (isOnline) {
      syncWithSupabase(true);
    }
  }

  function updateNetworkUI() {
    const dot = document.getElementById('app-net-dot');
    const text = document.getElementById('app-net-status-text');
    const btn = document.getElementById('app-net-toggle');
    const hint = btn ? btn.querySelector('.net-toggle-hint') : null;

    if (dot && text) {
      if (isOnline) {
        dot.className = 'net-status-indicator online';
        text.textContent = 'En Línea';
        if (hint) hint.textContent = 'Simular Corte';
        if (btn) btn.title = 'Conectado a la nube. Clic para simular modo Fuera de Línea.';
      } else {
        dot.className = 'net-status-indicator offline';
        text.textContent = 'Fuera de Línea';
        if (hint) hint.textContent = 'Reconectar';
        if (btn) btn.title = 'Modo sin internet. Clic para simular recuperación de señal.';
      }
    }
  }

  // ─── RENDERIZADO DE REGISTROS CON FILTRADO POR ROL ────────────
  function renderRecords() {
    const container = document.getElementById('pc-records-container');
    const searchInput = document.getElementById('pc-search-input');
    const searchTerm = searchInput ? normalizarTexto(searchInput.value) : '';

    const allRecords = getLocalDatabase();

    // FILTRADO POR ROL Y PESTAÑA:
    // Admin: SIEMPRE ve todos los registros
    // Encuestador: puede alternar entre 'mine' (sus registros) y 'all' (todo el equipo)
    const myRecords = allRecords.filter(r => r.encuestador_id === currentUser?.id);
    const totalGlobal = allRecords.length;
    const totalMine = myRecords.length;

    // Actualizar tabs de filtrado
    const tabMine = document.getElementById('tab-filter-mine');
    const tabAll = document.getElementById('tab-filter-all');
    if (tabMine) {
      tabMine.textContent = `Mis Encuestas (${totalMine})`;
      tabMine.className = `filter-tab-btn ${currentRecordFilter === 'mine' && currentUser?.rol !== 'admin' ? 'active' : ''}`;
      tabMine.style.display = currentUser?.rol === 'admin' ? 'none' : 'inline-block';
    }
    if (tabAll) {
      tabAll.textContent = currentUser?.rol === 'admin' ? `🌐 Todas las Encuestas (${totalGlobal})` : `🌐 Todo el Equipo (${totalGlobal})`;
      tabAll.className = `filter-tab-btn ${currentRecordFilter === 'all' || currentUser?.rol === 'admin' ? 'active' : ''}`;
    }

    const roleFiltered = (currentUser?.rol === 'admin' || currentRecordFilter === 'all')
      ? allRecords
      : myRecords;

    const displayRecords = roleFiltered.filter(r => {
      if (!searchTerm) return true;
      const haystack = normalizarTexto(`${r.cedula} ${r.nombre_completo} ${r.ciudad || ''} ${r.barrio || ''} ${r.encuestador_nombre || ''}`);
      return haystack.includes(searchTerm);
    });

    const totalCount = roleFiltered.length;
    const pendingCount = roleFiltered.filter(r => !r.sincronizado).length;
    const syncedCount = roleFiltered.filter(r => r.sincronizado).length;

    const statTotal = document.getElementById('pc-stat-total');
    const statPending = document.getElementById('pc-stat-pending');
    const statSynced = document.getElementById('pc-stat-synced');

    if (statTotal) statTotal.textContent = totalCount;
    if (statPending) statPending.textContent = pendingCount;
    if (statSynced) statSynced.textContent = syncedCount;

    if (!container) return;

    if (displayRecords.length === 0) {
      if (currentRecordFilter === 'mine' && totalGlobal > 0 && currentUser?.rol !== 'admin') {
        container.innerHTML = `
          <div class="pc-empty-records">
            <div class="empty-icon">👥</div>
            <h4>No tienes encuestas a tu nombre todavía</h4>
            <p>Se detectaron <strong>${totalGlobal} encuesta(s)</strong> registradas por otros encuestadores o desde la APK móvil.</p>
            <button type="button" class="btn-secondary-pc" style="margin-top: 14px; font-size: 13px;" onclick="window.switchRecordFilter('all')">
              👁️ Ver todas las encuestas del equipo (${totalGlobal})
            </button>
          </div>
        `;
      } else {
        container.innerHTML = `
          <div class="pc-empty-records">
            <div class="empty-icon">📂</div>
            <h4>No hay registros para mostrar</h4>
            <p>${totalCount === 0 
              ? 'No hay personas encuestadas aún. Utiliza el formulario de la izquierda o registra desde la APK para sincronizar.' 
              : 'No se encontraron resultados con el término de búsqueda actual.'}</p>
          </div>
        `;
      }
      return;
    }

    container.innerHTML = displayRecords.map(r => {
      const isSynced = Boolean(r.sincronizado);
      const isAdmin = currentUser?.rol === 'admin';
      const showOwner = isAdmin || currentRecordFilter === 'all';

      return `
        <div class="pc-record-item ${isSynced ? 'synced' : 'offline'}">
          <div class="record-dot ${isSynced ? 'dot-synced' : 'dot-offline'}" title="${isSynced ? 'Sincronizado con Supabase' : 'Pendiente de sincronización local'}"></div>
          <div class="record-main-info">
            <div class="record-row-title">
              <strong class="record-fullname">${escapeHtml(r.nombre_completo)}</strong>
              <span class="record-cedula-tag">C.C. ${escapeHtml(r.cedula)}</span>
              ${showOwner ? `<span class="record-owner-tag">👤 ${escapeHtml(r.encuestador_nombre || 'Encuestador')}</span>` : ''}
            </div>
            <div class="record-details-grid">
              <span>📅 Nacimiento: <strong>${escapeHtml(r.fecha_nacimiento || 'N/A')}</strong></span>
              <span>📞 Teléfono: <strong>${escapeHtml(r.telefono || 'Sin teléfono')}</strong></span>
              <span>📍 Dirección: <strong>${escapeHtml(r.direccion || 'Sin dirección')}</strong></span>
              <span>🏙️ Ciudad: <strong>${escapeHtml(r.ciudad || 'N/A')}</strong></span>
            </div>
          </div>
          <div class="record-status-col">
            <span class="status-badge ${isSynced ? 'badge-synced' : 'badge-offline'}">
              ${isSynced ? '✓ En Nube' : '⏳ En Cola'}
            </span>
          </div>
        </div>
      `;
    }).join('');
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // ─── VALIDACIÓN EN TIEMPO REAL DEL FORMULARIO ─────────────────
  function handleCedulaInput(e) {
    const input = e.target;
    input.value = input.value.replace(/\D/g, '').slice(0, 10);

    const counter = document.getElementById('pc-cedula-counter');
    if (counter) counter.textContent = `${input.value.length}/10`;

    clearTimeout(validationDebounceTimer);
    validationDebounceTimer = setTimeout(() => {
      ejecutarVerificacionInteligente(false);
    }, 350);
  }

  function ejecutarVerificacionInteligente(esSubmit = false) {
    const cedula = (document.getElementById('pc-cedula')?.value || '').trim();
    const pNombre = (document.getElementById('pc-primer-nombre')?.value || '').trim();
    const sNombre = (document.getElementById('pc-segundo-nombre')?.value || '').trim();
    const pApellido = (document.getElementById('pc-primer-apellido')?.value || '').trim();
    const sApellido = (document.getElementById('pc-segundo-apellido')?.value || '').trim();
    const fechaNac = (document.getElementById('pc-fecha-nacimiento')?.value || '').trim();

    const nombreCompleto = [pNombre, sNombre, pApellido, sApellido].filter(Boolean).join(' ');

    const alertBox = document.getElementById('pc-smart-alert');
    const alertTitle = document.getElementById('pc-alert-title');
    const alertDesc = document.getElementById('pc-alert-desc');
    const alertIcon = document.getElementById('pc-alert-icon');
    const cedulaInput = document.getElementById('pc-cedula');

    if (!cedula || cedula.length < 5) {
      if (alertBox) alertBox.style.display = 'none';
      if (cedulaInput) cedulaInput.classList.remove('input-warn', 'input-error');
      return null;
    }

    const coincidencia = buscarCoincidenciaInteligente(cedula, nombreCompleto, fechaNac);

    if (!coincidencia) {
      if (alertBox) alertBox.style.display = 'none';
      if (cedulaInput) {
        cedulaInput.classList.remove('input-warn', 'input-error');
        cedulaInput.classList.add('input-ok');
      }
      return null;
    }

    if (coincidencia.tipo === 'DUPLICADO_BLOQUEADO') {
      if (alertBox) {
        alertBox.style.display = 'flex';
        alertBox.className = 'pc-smart-alert alert-danger';
        alertTitle.textContent = '⛔ Persona Ya Registrada (Bloqueo Automático)';
        alertDesc.textContent = coincidencia.mensaje;
        alertIcon.textContent = '🚫';
      }
      if (cedulaInput) {
        cedulaInput.classList.remove('input-ok', 'input-warn');
        cedulaInput.classList.add('input-error');
      }
      return coincidencia;
    }

    if (coincidencia.tipo === 'CEDULA_IDENTICA') {
      if (alertBox) {
        alertBox.style.display = 'flex';
        alertBox.className = 'pc-smart-alert alert-danger';
        alertTitle.textContent = '⚠️ Cédula Ya Existente';
        alertDesc.textContent = coincidencia.mensaje;
        alertIcon.textContent = '⚠️';
      }
      if (cedulaInput) {
        cedulaInput.classList.remove('input-ok');
        cedulaInput.classList.add('input-warn');
      }
      return coincidencia;
    }

    if (coincidencia.tipo === 'CEDULA_PARECIDA') {
      if (alertBox) {
        alertBox.style.display = 'flex';
        alertBox.className = 'pc-smart-alert alert-warning';
        alertTitle.textContent = `🔍 Cédula Similar Detectada (Difiere en ${coincidencia.distancia} dígito${coincidencia.distancia > 1 ? 's' : ''})`;
        alertDesc.textContent = coincidencia.mensaje;
        alertIcon.textContent = '💡';
      }
      if (cedulaInput) {
        cedulaInput.classList.remove('input-ok');
        cedulaInput.classList.add('input-warn');
      }
      return coincidencia;
    }

    return null;
  }

  // ─── GUARDAR NUEVO REGISTRO (LOCAL + NUBE) ───────────────────
  async function handleFormSubmit(e) {
    e.preventDefault();

    if (!currentUser) {
      alert('Debes iniciar sesión para realizar encuestas.');
      showLoginView();
      return;
    }

    const cedula = (document.getElementById('pc-cedula')?.value || '').trim();
    const pNombre = (document.getElementById('pc-primer-nombre')?.value || '').trim();
    const sNombre = (document.getElementById('pc-segundo-nombre')?.value || '').trim();
    const pApellido = (document.getElementById('pc-primer-apellido')?.value || '').trim();
    const sApellido = (document.getElementById('pc-segundo-apellido')?.value || '').trim();
    const fechaNac = (document.getElementById('pc-fecha-nacimiento')?.value || '').trim();
    const telefono = (document.getElementById('pc-telefono')?.value || '').trim();

    const tipoVia = (document.getElementById('pc-tipo-via')?.value || 'Calle').trim();
    const numVia = (document.getElementById('pc-num-via')?.value || '').trim();
    const barrio = (document.getElementById('pc-barrio')?.value || '').trim();
    const ciudad = (document.getElementById('pc-ciudad')?.value || 'Bucaramanga').trim();

    if (!cedula || cedula.length < 6) {
      alert('Por favor ingresa un número de cédula válido (mínimo 6 dígitos, máximo 10).');
      document.getElementById('pc-cedula')?.focus();
      return;
    }

    if (!pNombre || !pApellido || !fechaNac) {
      alert('Por favor completa los campos obligatorios (*): Primer Nombre, Primer Apellido y Fecha de Nacimiento.');
      return;
    }

    const nombreCompleto = [pNombre, sNombre, pApellido, sApellido].filter(Boolean).join(' ');

    // VALIDACIÓN ESTRICTA DE DUPLICADO
    const coincidencia = ejecutarVerificacionInteligente(true);

    if (coincidencia && coincidencia.tipo === 'DUPLICADO_BLOQUEADO') {
      mostrarModalBloqueado(coincidencia.personaCoincidente, coincidencia.distancia);
      return;
    }

    if (coincidencia && coincidencia.tipo === 'CEDULA_IDENTICA') {
      mostrarModalBloqueado(coincidencia.personaCoincidente, 0);
      return;
    }

    const dirTexto = [tipoVia, numVia, barrio ? `Brr. ${barrio}` : null].filter(Boolean).join(' ');

    const nuevoRegistro = {
      id: 'per_' + Date.now() + '_' + Math.floor(Math.random() * 1000),
      cedula: cedula,
      primer_nombre: pNombre,
      segundo_nombre: sNombre,
      primer_apellido: pApellido,
      segundo_apellido: sApellido,
      nombre_completo: nombreCompleto,
      fecha_nacimiento: fechaNac,
      telefono: telefono,
      tipo_via: tipoVia,
      numero_via: numVia,
      barrio: barrio,
      ciudad: ciudad,
      direccion: dirTexto,
      encuestador_id: currentUser.id,
      encuestador_nombre: currentUser.nombre,
      encuestador_email: currentUser.email,
      sincronizado: false,
      created_at: new Date().toISOString()
    };

    // Intentar guardar en Supabase si hay conexión activa
    let enviadoANube = false;
    if (isOnline && supabaseClient) {
      try {
        const payload = mapToSupabasePayload(nuevoRegistro);
        const { error } = await supabaseClient.from('personas').upsert(payload);
        if (!error) {
          nuevoRegistro.sincronizado = true;
          enviadoANube = true;
        }
      } catch (err) {
        console.warn('No se pudo enviar a Supabase inmediatamente, queda en cola local:', err);
      }
    }

    // Guardar en la base de datos local
    const db = getLocalDatabase();
    db.unshift(nuevoRegistro);
    saveLocalDatabase(db);

    resetSurveyForm();
    renderRecords();

    if (enviadoANube) {
      alert(`✅ Encuesta guardada y enviada a Supabase Cloud con éxito para "${nombreCompleto}". La APK móvil la descargará al sincronizar.`);
    } else {
      alert(`💾 Encuesta guardada localmente (modo sin conexión / en cola). Se sincronizará con Supabase al pulsar "Sincronizar".`);
    }
  }

  function mostrarModalBloqueado(personaExistente, distancia) {
    const modal = document.getElementById('pc-blocked-modal');
    const msgEl = document.getElementById('pc-blocked-message');

    if (msgEl && personaExistente) {
      const encuestadorRegistrador = escapeHtml(personaExistente.encuestador_nombre || 'Otro usuario');
      const esMismoEncuestador = currentUser && personaExistente.encuestador_id === currentUser.id;
      const autorBanner = esMismoEncuestador
        ? `<div class="blocked-author-banner blocked-author-self">
            <span class="blocked-author-icon">📋</span>
            <div>
              <span class="blocked-author-label">Registrado por ti mismo</span>
              <span class="blocked-author-name">${encuestadorRegistrador}</span>
            </div>
          </div>`
        : `<div class="blocked-author-banner blocked-author-other">
            <span class="blocked-author-icon">⚠️</span>
            <div>
              <span class="blocked-author-label">Registrado por OTRO encuestador</span>
              <span class="blocked-author-name">${encuestadorRegistrador}</span>
            </div>
          </div>`;

      msgEl.innerHTML = `
        <p><strong>El sistema detectó que esta persona ya fue encuestada y bloqueó el registro duplicado:</strong></p>
        ${autorBanner}
        <div class="blocked-detail-box">
          <p>👤 <strong>Nombre:</strong> ${escapeHtml(personaExistente.nombre_completo)}</p>
          <p>🆔 <strong>Cédula Registrada:</strong> ${escapeHtml(personaExistente.cedula)}</p>
          <p>📅 <strong>Fecha de Nacimiento:</strong> ${escapeHtml(personaExistente.fecha_nacimiento)}</p>
          ${distancia > 0 ? `<p class="blocked-diff-note">ℹ️ La cédula ingresada difiere en ${distancia} dígito(s), pero el nombre y la fecha de nacimiento son idénticos.</p>` : ''}
        </div>
        <p class="blocked-footnote">${esMismoEncuestador
          ? 'Ya ingresaste esta encuesta anteriormente. Si crees que es un error, contacta al administrador.'
          : `Esta persona ya fue registrada por <strong>${encuestadorRegistrador}</strong>. No se puede registrar dos veces la misma persona.`
        }</p>
      `;
    }

    if (modal) modal.style.display = 'flex';
  }

  function cerrarModalBloqueado() {
    const modal = document.getElementById('pc-blocked-modal');
    if (modal) modal.style.display = 'none';
  }

  function resetSurveyForm() {
    const form = document.getElementById('pc-survey-form');
    if (form) form.reset();

    const counter = document.getElementById('pc-cedula-counter');
    if (counter) counter.textContent = '0/10';

    const alertBox = document.getElementById('pc-smart-alert');
    if (alertBox) alertBox.style.display = 'none';

    const cedulaInput = document.getElementById('pc-cedula');
    if (cedulaInput) cedulaInput.classList.remove('input-ok', 'input-warn', 'input-error');

    const ciudadInput = document.getElementById('pc-ciudad');
    if (ciudadInput) ciudadInput.value = 'Bucaramanga';
  }

  // ─── MODAL DE CONFIGURACIÓN SUPABASE CLOUD ────────────────────
  function abrirModalConfigCloud() {
    const modal = document.getElementById('cloud-config-modal');
    const config = getSupabaseConfig();
    const urlInput = document.getElementById('cfg-supabase-url');
    const keyInput = document.getElementById('cfg-supabase-key');
    const resultBox = document.getElementById('cloud-test-result');

    if (urlInput) urlInput.value = config.url;
    if (keyInput) keyInput.value = config.key;
    if (resultBox) resultBox.style.display = 'none';

    if (modal) modal.style.display = 'flex';
  }

  function cerrarModalConfigCloud() {
    const modal = document.getElementById('cloud-config-modal');
    if (modal) modal.style.display = 'none';
  }

  async function probarConexionCloud() {
    const url = document.getElementById('cfg-supabase-url')?.value.trim();
    const key = document.getElementById('cfg-supabase-key')?.value.trim();
    const resultBox = document.getElementById('cloud-test-result');

    if (!url || !key) {
      if (resultBox) {
        resultBox.style.display = 'block';
        resultBox.className = 'cloud-test-result error';
        resultBox.textContent = 'Debes ingresar tanto la URL como la Anon Key de Supabase.';
      }
      return;
    }

    if (resultBox) {
      resultBox.style.display = 'block';
      resultBox.className = 'cloud-test-result';
      resultBox.textContent = 'Probando conexión con Supabase...';
    }

    try {
      const testClient = window.supabase.createClient(url, key);
      const { data, error } = await testClient.from('personas').select('id').limit(1);

      if (error) throw error;

      if (resultBox) {
        resultBox.className = 'cloud-test-result success';
        resultBox.textContent = '✅ Conexión exitosa. La tabla "personas" en Supabase responde correctamente.';
      }
    } catch (err) {
      if (resultBox) {
        resultBox.className = 'cloud-test-result error';
        resultBox.textContent = `❌ Error al conectar: ${err.message || err}. Verifica la URL o si el proyecto está pausado en el panel de Supabase.`;
      }
    }
  }

  function guardarConfigCloud() {
    const url = document.getElementById('cfg-supabase-url')?.value.trim();
    const key = document.getElementById('cfg-supabase-key')?.value.trim();

    if (url) localStorage.setItem(STORAGE_KEY_SUPA_URL, url);
    if (key) localStorage.setItem(STORAGE_KEY_SUPA_KEY, key);

    initSupabaseClient();
    cerrarModalConfigCloud();
    syncWithSupabase(true);
  }

  // ─── VACIAR BASE DE DATOS LOCAL ───────────────────────────────
  async function handleClearDatabase() {
    if (confirm('¿Estás seguro de que deseas vaciar la base de datos local? Esto dejará la lista con 0 registros en este PC.')) {
      saveLocalDatabase([]);
      renderRecords();
      resetSurveyForm();
      alert('Base de datos local restablecida a 0 registros.');
    }
  }

  // ─── INICIALIZACIÓN DE EVENTOS ────────────────────────────────
  document.addEventListener('DOMContentLoaded', () => {
    initSupabaseClient();
    initSession();

    // Formulario de Login
    const formLogin = document.getElementById('form-login');
    if (formLogin) {
      formLogin.addEventListener('submit', (e) => {
        e.preventDefault();
        const email = document.getElementById('login-email')?.value || '';
        const pass = document.getElementById('login-password')?.value || '';
        login(email, pass);
      });
    }

    // Botones de Acceso Rápido en Login
    document.getElementById('btn-quick-admin')?.addEventListener('click', () => {
      login('admin@offdata.com', 'OffData2026*');
    });

    document.getElementById('btn-quick-enc1')?.addEventListener('click', () => {
      login('encuestador1@offdata.com', 'Encuestador2026*');
    });

    document.getElementById('btn-quick-enc2')?.addEventListener('click', () => {
      login('encuestador2@offdata.com', 'Encuestador2026*');
    });

    // Cerrar Sesión
    document.getElementById('btn-logout')?.addEventListener('click', () => {
      logout();
    });

    // Toggle Conectividad
    document.getElementById('app-net-toggle')?.addEventListener('click', toggleNetwork);

    // Formulario de Captura
    document.getElementById('pc-survey-form')?.addEventListener('submit', handleFormSubmit);
    document.getElementById('btn-pc-reset')?.addEventListener('click', resetSurveyForm);

    // Cédula: restricción a 10 dígitos y verificación en tiempo real
    const cedulaInput = document.getElementById('pc-cedula');
    if (cedulaInput) {
      cedulaInput.addEventListener('input', handleCedulaInput);
    }

    // Re-evaluación al cambiar nombres o fecha de nacimiento
    ['pc-primer-nombre', 'pc-primer-apellido', 'pc-fecha-nacimiento'].forEach(id => {
      document.getElementById(id)?.addEventListener('blur', () => ejecutarVerificacionInteligente(false));
    });

    // Búsqueda y Filtros de Pestaña
    document.getElementById('pc-search-input')?.addEventListener('input', renderRecords);
    document.getElementById('tab-filter-mine')?.addEventListener('click', () => {
      currentRecordFilter = 'mine';
      renderRecords();
    });
    document.getElementById('tab-filter-all')?.addEventListener('click', () => {
      currentRecordFilter = 'all';
      renderRecords();
    });

    // Sincronización manual y vaciado
    document.getElementById('btn-pc-sync-now')?.addEventListener('click', () => syncWithSupabase(true));
    document.getElementById('btn-pc-clear-db')?.addEventListener('click', handleClearDatabase);

    // Modal de Bloqueo
    document.getElementById('btn-close-blocked')?.addEventListener('click', cerrarModalBloqueado);

    // Modal de Configuración Supabase Cloud
    document.getElementById('btn-open-cloud-config')?.addEventListener('click', abrirModalConfigCloud);
    document.getElementById('btn-close-cloud')?.addEventListener('click', cerrarModalConfigCloud);
    document.getElementById('btn-test-cloud')?.addEventListener('click', probarConexionCloud);
    document.getElementById('btn-save-cloud')?.addEventListener('click', guardarConfigCloud);
  });

})();
