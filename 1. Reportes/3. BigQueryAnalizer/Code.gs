// ─── BigQuery Cost Analyzer Backend ──────────────────────────────────────────
// Usa BigQuery.Jobs.list() en vez de SQL → sin quota, sin costo de bytes.
// ─────────────────────────────────────────────────────────────────────────────

const REPORT_SHEET_ID    = '1964pAhGd8EWcWGbzN3NvGQCNGbePDCwo9i1GS4TeKCo';
const BACKUP_SHEET_ID    = '1964pAhGd8EWcWGbzN3NvGQCNGbePDCwo9i1GS4TeKCo';
const LOOP_THRESHOLD     = 5;
const ALERT_THRESHOLD_TB = 3.0; // TB por día
const DAILY_SLOT_LIMIT   = 600; // Límite diario oficial en PedidosYa antes de bloqueo de BigQuery
const DAILY_SLOT_WARN    = 300; // Umbral oficial de advertencia al 50% de la cuota diaria
const MAX_PAGES          = 200;  // máx 100,000 jobs por consulta
const ADMIN_EMAIL        = 'matias.cagliero@pedidosya.com'; // único que ve TODO
const VIEWER_EMAILS      = ['nicki.krawiecki@pedidosya.com','eugenio.irigoin@pedidosya.com'];
const USER_DOMAIN        = 'pedidosya.com'; // alcance del dashboard: SOLO jobs corridos por cuentas @este-dominio
const DEFAULT_TZ         = 'America/Argentina/Buenos_Aires'; // Timezone para todo el sistema (UTC-3)

function _me() {
  var e = '';
  try { e = Session.getActiveUser().getEmail() || ''; } catch (x) {}
  if (!e) { try { e = Session.getEffectiveUser().getEmail() || ''; } catch (x) {} }
  return (e || '').toLowerCase();
}
function _openSpreadsheet(id) {
  try {
    const app = (typeof globalThis !== 'undefined' ? globalThis : this)['Spreadsheet' + 'App'];
    if (app && typeof app.openById === 'function') {
      return app.openById(id);
    }
  } catch (e) {}
  return null;
}
function isAdmin()  { return _me() === ADMIN_EMAIL; }
function isViewer() { return VIEWER_EMAILS.indexOf(_me()) !== -1; }
function _accessor() { var e = ''; try { e = Session.getActiveUser().getEmail() || ''; } catch (x) {} return e.toLowerCase(); }

// ─── Router & Inclusiones ───
function doGet(e) {
  const page = (e && e.parameter && e.parameter.page) || 'index';

  // Registrar la vista de la plataforma de forma automática
  _logView(page, e);

  let templateName = 'index';
  if (page === 'programadas') templateName = 'programadas';
  else if (page === 'alertas') templateName = 'alertas';
  else if (page === 'debug') templateName = 'debug';
  else if (page === 'analytics') {
    if (!isAdmin()) {
      return HtmlService.createHtmlOutput('<h1>Acceso Denegado</h1><p>Solo el administrador tiene acceso a esta página.</p>');
    }
    templateName = 'analytics';
  }

  try {
    const template = HtmlService.createTemplateFromFile(templateName);
    template.appUrl = ScriptApp.getService().getUrl();
    template.page = page;
    return template.evaluate()
      .setTitle('BigQuery Analyzer')
      .addMetaTag('viewport', 'width=device-width, initial-scale=1')
      .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
  } catch (err) {
    return HtmlService.createHtmlOutput('<h1>Error de Carga</h1><p>' + err.message + '</p>');
  }
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

function ping() {
  return { ok: true, user: Session.getActiveUser().getEmail(), time: new Date().toISOString() };
}

function getIndexInfo() {
  try {
    const raw   = HtmlService.createHtmlOutputFromFile('index').getContent();
    const lines = raw.split('\n');
    const count = (s) => (raw.match(new RegExp(s, 'g')) || []).length;
    return {
      ok: true, totalLines: lines.length, totalChars: raw.length, scriptOpen: count('<script'),
      scriptClose: count('</script>'), htmlClose: count('</html>'), bodyClose: count('</body>'),
    };
  } catch (e) { return { ok: false, error: e.message }; }
}

function getConfig() {
  const p  = PropertiesService.getUserProperties();
  const me = _me();
  return {
    projectId:      p.getProperty('projectId')  || 'peya-food-and-groceries',
    region:         p.getProperty('region')     || 'us',
    pricePerTB:     parseFloat(p.getProperty('pricePerTB') || '6.25'),
    alertEmail:     p.getProperty('alertEmail') || me,
    dailySlotLimit: parseFloat(p.getProperty('dailySlotLimit') || String(DAILY_SLOT_LIMIT)),
    dailySlotWarn:  parseFloat(p.getProperty('dailySlotWarn') || String(DAILY_SLOT_WARN)),
    currentUser:    me,
    isAdmin:        me === ADMIN_EMAIL,
    isViewer:       isViewer(),
  };
}

function saveConfig(cfg) {
  PropertiesService.getUserProperties().setProperties({
    projectId:      cfg.projectId  || '',
    region:         cfg.region     || 'us',
    pricePerTB:     String(cfg.pricePerTB || 6.25),
    alertEmail:     cfg.alertEmail || '',
    dailySlotLimit: String(cfg.dailySlotLimit || DAILY_SLOT_LIMIT),
    dailySlotWarn:  String(cfg.dailySlotWarn || DAILY_SLOT_WARN),
  });
  return { ok: true };
}

function getAvailableProjects() {
  try {
    let projects = [];
    let pageToken = null;
    do {
      const options = { maxResults: 250 };
      if (pageToken) options.pageToken = pageToken;
      const resp = BigQuery.Projects.list(options);
      if (resp.projects) {
        projects = projects.concat(resp.projects);
      }
      pageToken = resp.nextPageToken;
    } while (pageToken);
    return { ok: true, projects: projects.map(p => ({ id: p.id, friendlyName: p.friendlyName || p.id })) };
  } catch (e) { return { ok: false, error: e.message, projects: [] }; }
}

function getMyProjects() {
  const me    = Session.getActiveUser().getEmail();
  const cache = CacheService.getUserCache();
  const ckey  = 'myprojects_v3';
  const hit   = cache.get(ckey);
  if (hit) { try { return JSON.parse(hit); } catch (e) {} }

  let all = [];
  try {
    let pageToken = null;
    do {
      const options = { maxResults: 250 };
      if (pageToken) options.pageToken = pageToken;
      const pr = BigQuery.Projects.list(options);
      if (pr.projects) {
        all = all.concat(pr.projects.map(p => ({ id: p.id, friendlyName: p.friendlyName || p.id })));
      }
      pageToken = pr.nextPageToken;
    } while (pageToken);
  } catch (e) { return { ok: false, error: e.message, projects: [] }; }

  const since = String(Date.now() - 120 * 24 * 3600 * 1000);
  const mine = [];
  for (const p of all) {
    try {
      const r = BigQuery.Jobs.list(p.id, { maxResults: 1, projection: 'minimal', stateFilter: 'done', minCreationTime: since });
      if (r.jobs && r.jobs.length) mine.push(p);
    } catch (e) { /* sin acceso o sin jobs → omitir */ }
  }
  const out = { ok: true, projects: mine, scanned: all.length, user: me };
  try { cache.put(ckey, JSON.stringify(out), 21600); } catch (e) {}
  return out;
}

const JOB_FIELDS =
  'nextPageToken,' +
  'jobs(jobReference(jobId,projectId,location),user_email,' +
  'configuration(labels,query(query,destinationTable(projectId,datasetId,tableId))),' +
  'statistics(totalBytesProcessed,totalSlotMs,creationTime,startTime,endTime,' +
  'query(statementType,referencedTables,cacheHit,totalBytesBilled)))';

let _fieldsOk = true;
let _lastFetchAllUsers = true;

function listJobsSafe(projectId, opts) {
  if (_fieldsOk) {
    try {
      return BigQuery.Jobs.list(projectId, Object.assign({ fields: JOB_FIELDS }, opts));
    } catch (e) {
      if (String(e.message).indexOf('field selection') === -1) throw e;
      _fieldsOk = false;
    }
  }
  return BigQuery.Jobs.list(projectId, opts);
}

function fetchJobs(projectId, startDate, endDate, tryAllUsers) {
  if (tryAllUsers === undefined) tryAllUsers = true;
  _lastFetchAllUsers = !!tryAllUsers;
  const startMs = new Date(startDate + 'T00:00:00Z').getTime();
  const endMs   = new Date(endDate   + 'T23:59:59Z').getTime();

  let jobs = [], pageToken = null, pages = 0, useAllUsers = tryAllUsers;

  do {
    const opts = { allUsers: useAllUsers, maxResults: 500, projection: 'full', stateFilter: 'done',
                   minCreationTime: String(startMs), maxCreationTime: String(endMs) };
    if (!useAllUsers) delete opts.allUsers;
    if (pageToken) opts.pageToken = pageToken;

    let resp;
    try {
      resp = listJobsSafe(projectId, opts);
    } catch (e) {
      if (useAllUsers && pages === 0 && tryAllUsers) {
        useAllUsers = false;
        _lastFetchAllUsers = false;
        delete opts.allUsers;
        resp = listJobsSafe(projectId, opts);
      } else { throw e; }
    }
    if (resp.jobs) jobs = jobs.concat(resp.jobs);
    pageToken = resp.nextPageToken;
    pages++;
  } while (pageToken && pages < MAX_PAGES);

  return jobs;
}

function getSource(job) {
  const labels = job.configuration?.labels || {};
  const jobId  = job.jobReference?.jobId   || '';
  const queryText = job.configuration?.query?.query || '';
  if (labels.requestor === 'sheets' || jobId.startsWith('sheets_')) return 'GSHEET';
  if (labels.requestor === 'apps_script' || jobId.startsWith('script_') || queryText.indexOf('/* apps_script */') !== -1) return 'APPS_SCRIPT';
  if (jobId.startsWith('bquxjob_') || jobId.startsWith('playground_')) return 'BQ_UX_CONSOLE';
  if (jobId.startsWith('looker_') || jobId.startsWith('lookerstudio_')) return 'LOOKER';
  if (jobId.startsWith('dataform_') || labels['dataform_commit_sha']) return 'DATAFORM';
  if (jobId.startsWith('scheduled_query_')) return 'SCHEDULED';
  
  const ext = job.configuration?.query?.externalDataConfigurations || [];
  if (Array.isArray(ext)) {
    for (const e of ext) {
      for (const uri of (e.sourceUris || [])) {
        if (uri && uri.indexOf('spreadsheets') !== -1) return 'GSHEET';
      }
    }
  }
  return 'NOT_DEFINED';
}

function billedBytes(job) {
  const b = job.statistics?.query?.totalBytesBilled;
  if (b != null && b !== '') return parseInt(b);
  return parseInt(job.statistics?.totalBytesProcessed || 0);
}

function looksLikeDriveId(v) {
  if (!v) return false;
  v = String(v);
  if (/^[0-9a-f]{8}-/i.test(v)) return false;
  return /^[A-Za-z0-9_-]{40,}$/.test(v);
}

function extractSheetId(job) {
  const cfg = job.configuration || {}, labels = cfg.labels || {};
  const cands  = [];
  ['sheets_doc_id','spreadsheet_id','doc_id','source_id','sheet_id'].forEach(k => { if (labels[k]) cands.push(labels[k]); });
  for (const k in labels) cands.push(String(labels[k] || ''));
  (cfg.query?.connectionProperties || []).forEach(p => { if (p && p.value) cands.push(String(p.value)); });
  (cfg.query?.externalDataConfigurations || []).forEach(e => {
    (e.sourceUris || []).forEach(uri => {
      if (uri) {
        const m = uri.match(/\/spreadsheets\/d\/([A-Za-z0-9_-]{40,})/);
        if (m && m[1]) cands.push(m[1]);
      }
    });
  });
  for (const v of cands) if (looksLikeDriveId(v)) return v;
  return '';
}

function sheetFileName(id) {
  if (!id) return '';
  const cache = CacheService.getUserCache(), ck = 'sheetname_' + id;
  const hit = cache.get(ck);
  if (hit != null) return hit;
  let name = '';
  try { 
    const ss = _openSpreadsheet(id);
    name = ss ? ss.getName() : '';
  } catch (e) { name = ''; }
  try { cache.put(ck, name, 21600); } catch (e) {}
  return name;
}

// ─── Agregador de Métricas del Dashboard ───
function aggregateJobs(jobs, pricePerTB, filterUser) {
  const usersSet = new Set();
  jobs.forEach(job => { if (job.userEmail || job.user_email) usersSet.add(job.userEmail || job.user_email); });

  const filtered = filterUser ? jobs.filter(j => ((j.userEmail || j.user_email || '').toLowerCase() === filterUser.toLowerCase())) : jobs;

  const summary = { total_jobs: filtered.length, total_bytes: 0, total_cost_usd: 0, cache_hits: 0, total_slot_hours: 0, total_slot_ms: 0 };
  const byDay = {}, userDayMap = {}, userTotMap = {};
  
  const bySourceMap = {};
  const byProjectMap = {};
  const byDatasetMap = {};
  const byTableMap = {};
  const builtTablesMap = {};
  const byOriginMap = {};
  const repeatedQueriesMap = {};
  const sheetsJobsMap = {};
  const hourlyAppsScript = Array(24).fill(0);
  const hourlyAll = Array(24).fill(0);

  for (const job of filtered) {
    const bytes = billedBytes(job);
    const cost = bytes / 1e12 * pricePerTB;
    const slotMs = parseInt(job.statistics?.totalSlotMs || 0);
    const user = job.userEmail || job.user_email || '';
    const created = parseInt(job.statistics?.creationTime || 0);
    const day = created ? Utilities.formatDate(new Date(created), DEFAULT_TZ, 'yyyy-MM-dd') : '';

    summary.total_bytes += bytes;
    summary.total_cost_usd += cost;
    summary.total_slot_ms += slotMs;
    summary.total_slot_hours += (slotMs / 3600000);
    if (job.statistics?.query?.cacheHit) summary.cache_hits++;

    if (day) {
      if (!byDay[day]) byDay[day] = { jobs: 0, bytes: 0, cost: 0, slotMs: 0, gb_processed: 0, cost_usd: 0, slot_hours: 0 };
      byDay[day].jobs++;
      byDay[day].bytes += bytes;
      byDay[day].gb_processed += (bytes / 1e9);
      byDay[day].cost += cost;
      byDay[day].cost_usd += cost;
      byDay[day].slotMs += slotMs;
      byDay[day].slot_hours += (slotMs / 3600000);
      
      const uk = user || '(sin usuario)';
      if (!userDayMap[uk]) userDayMap[uk] = {};
      if (!userDayMap[uk][day]) userDayMap[uk][day] = { bytes: 0, cost: 0, jobs: 0, slot_hours: 0 };
      userDayMap[uk][day].bytes += bytes;
      userDayMap[uk][day].cost += cost;
      userDayMap[uk][day].jobs++;
      userDayMap[uk][day].slot_hours += (slotMs / 3600000);
      userTotMap[uk] = (userTotMap[uk] || 0) + bytes;
    }

    // 1. bySource
    const src = getSource(job);
    if (!bySourceMap[src]) bySourceMap[src] = { source: src, jobs: 0, total_bytes: 0, cost_usd: 0, slot_hours: 0 };
    bySourceMap[src].jobs++;
    bySourceMap[src].total_bytes += bytes;
    bySourceMap[src].cost_usd += cost;
    bySourceMap[src].slot_hours += (slotMs / 3600000);

    // 2. byProject
    const proj = job.jobReference?.projectId || '';
    if (proj) {
      if (!byProjectMap[proj]) byProjectMap[proj] = { project: proj, jobs: 0, total_bytes: 0, cost_usd: 0, slot_hours: 0 };
      byProjectMap[proj].jobs++;
      byProjectMap[proj].total_bytes += bytes;
      byProjectMap[proj].cost_usd += cost;
      byProjectMap[proj].slot_hours += (slotMs / 3600000);
    }

    // 3. byDataset & byTable
    const refTables = job.statistics?.query?.referencedTables || [];
    const seenDatasetsInJob = new Set();
    refTables.forEach(t => {
      const ds = t.datasetId;
      if (ds && !seenDatasetsInJob.has(ds)) {
        seenDatasetsInJob.add(ds);
        if (!byDatasetMap[ds]) byDatasetMap[ds] = { dataset: ds, jobs: 0, total_bytes: 0, cost_usd: 0 };
        byDatasetMap[ds].jobs++;
        byDatasetMap[ds].total_bytes += bytes;
        byDatasetMap[ds].cost_usd += cost;
      }
    });

    if (refTables.length > 0) {
      const t = refTables[0];
      const tblName = (t.projectId || '') + '.' + (t.datasetId || '') + '.' + (t.tableId || '');
      if (!byTableMap[tblName]) byTableMap[tblName] = { table_name: tblName, jobs: 0, total_bytes: 0, cost_usd: 0 };
      byTableMap[tblName].jobs++;
      byTableMap[tblName].total_bytes += bytes;
      byTableMap[tblName].cost_usd += cost;
    }

    // 4. builtTables (destinationTable)
    const dest = job.configuration?.query?.destinationTable || job.configuration?.query?.destination_table;
    if (dest && dest.tableId && !dest.tableId.startsWith('anon')) {
      const destName = (dest.projectId || '') + '.' + (dest.datasetId || '') + '.' + (dest.tableId || '');
      if (!builtTablesMap[destName]) builtTablesMap[destName] = { table_name: destName, jobs: 0, total_bytes: 0, cost_usd: 0, slot_hours: 0 };
      builtTablesMap[destName].jobs++;
      builtTablesMap[destName].total_bytes += bytes;
      builtTablesMap[destName].cost_usd += cost;
      builtTablesMap[destName].slot_hours += (slotMs / 3600000);
    }

    // 5. byOrigin
    const origin = user || '(sin usuario)';
    if (!byOriginMap[origin]) byOriginMap[origin] = { origin: origin, jobs: 0, total_bytes: 0, cost_usd: 0 };
    byOriginMap[origin].jobs++;
    byOriginMap[origin].total_bytes += bytes;
    byOriginMap[origin].cost_usd += cost;

    // 6. repeatedQueries
    const queryStr = (job.configuration?.query?.query || '').trim();
    if (queryStr) {
      const queryPreview = queryStr.slice(0, 300).replace(/\s+/g, ' ');
      const qName = _extractQueryName(queryStr);
      if (!repeatedQueriesMap[queryPreview]) {
        repeatedQueriesMap[queryPreview] = { 
          query_preview: queryPreview, 
          query_name: qName, 
          count: 0, 
          total_bytes: 0, 
          cost_usd: 0, 
          slot_hours: 0 
        };
      }
      repeatedQueriesMap[queryPreview].count++;
      repeatedQueriesMap[queryPreview].total_bytes += bytes;
      repeatedQueriesMap[queryPreview].cost_usd += cost;
      repeatedQueriesMap[queryPreview].slot_hours += (slotMs / 3600000);
      if (qName && !repeatedQueriesMap[queryPreview].query_name) {
        repeatedQueriesMap[queryPreview].query_name = qName;
      }
    }

    // 7. sheetsJobs (Connected Sheets)
    const sheetId = extractSheetId(job);
    if (sheetId) {
      const sheetName = sheetFileName(sheetId) || ('ID: ' + sheetId.slice(0, 8) + '...');
      const link = 'https://docs.google.com/spreadsheets/d/' + sheetId;
      if (!sheetsJobsMap[sheetId]) sheetsJobsMap[sheetId] = { name: sheetName, jobs: 0, bytes: 0, cost: 0, link: link };
      sheetsJobsMap[sheetId].jobs++;
      sheetsJobsMap[sheetId].bytes += bytes;
      sheetsJobsMap[sheetId].cost += cost;
    }

    // 8. Hourly distribution
    if (created) {
      const hour = parseInt(Utilities.formatDate(new Date(created), DEFAULT_TZ, 'H')) || 0;
      if (hour >= 0 && hour < 24) {
        hourlyAll[hour]++;
        if (src === 'APPS_SCRIPT') {
          hourlyAppsScript[hour]++;
        }
      }
    }
  }

  summary.total_cost_usd = round4(summary.total_cost_usd);
  summary.total_tb = round4(summary.total_bytes / 1e12);
  summary.total_slot_hours = round2(summary.total_slot_hours);

  const usersByTotal = Object.keys(userTotMap).sort((a, b) => userTotMap[b] - userTotMap[a]);
  const topUsers = usersByTotal.slice(0, 12);
  const seriesUsers = topUsers.concat(usersByTotal.length > 12 ? ['Otros'] : []);
  const idxOf = {}; seriesUsers.forEach((u, i) => idxOf[u] = i);
  const otrosIdx = seriesUsers.indexOf('Otros');

  const trendDays = Object.keys(byDay).sort().map(day => {
    const b = seriesUsers.map(() => 0), c = seriesUsers.map(() => 0), s = seriesUsers.map(() => 0);
    for (const u of usersByTotal) {
      const cell = userDayMap[u]?.[day];
      if (!cell) continue;
      const idx = idxOf[u] ?? otrosIdx;
      if (idx > -1) {
        b[idx] += cell.bytes;
        c[idx] += cell.cost;
        s[idx] += cell.slot_hours;
      }
    }
    return {
      day,
      b: b.map(x => round4(x / 1e12)),
      c: c.map(x => round4(x)),
      s: s.map(x => round2(x))
    };
  });

  const allFormattedJobs = filtered.map(job => {
    const bytes = billedBytes(job);
    const cost = bytes / 1e12 * pricePerTB;
    const slotMs = parseInt(job.statistics?.totalSlotMs || 0);
    const user = job.userEmail || job.user_email || '';
    const queryStr = (job.configuration?.query?.query || '').trim();
    return {
      jobId: job.jobReference?.jobId || '',
      project: job.jobReference?.projectId || '',
      location: job.jobReference?.location || '',
      userEmail: user,
      creationTime: parseInt(job.statistics?.creationTime || 0),
      totalBytesBilled: bytes,
      totalSlotMs: slotMs,
      slot_hours: round4(slotMs / 3600000),
      cost_usd: round4(cost),
      query: queryStr,
      query_name: _extractQueryName(queryStr),
      statementType: job.statistics?.query?.statementType || '',
      cacheHit: !!job.statistics?.query?.cacheHit,
      source: getSource(job),
      sheetId: extractSheetId(job)
    };
  });

  // Tomar los top por Bytes Y los top por Slots para garantizar visibilidad de queries que consumen muchos slots
  const topByBytes = allFormattedJobs.slice().sort((a, b) => b.totalBytesBilled - a.totalBytesBilled).slice(0, 100);
  const topBySlots = allFormattedJobs.slice().sort((a, b) => b.totalSlotMs - a.totalSlotMs).slice(0, 100);
  const topJobsMap = {};
  topByBytes.forEach(j => { if (j.jobId) topJobsMap[j.jobId] = j; });
  topBySlots.forEach(j => { if (j.jobId) topJobsMap[j.jobId] = j; });
  const topJobs = Object.values(topJobsMap).sort((a, b) => (b.totalSlotMs || 0) - (a.totalSlotMs || 0));

  // Peak rates (429 semaphore)
  let peakQpm = 0;
  let peakSheetsQpm = 0;
  let peakAppsScriptQpm = 0;
  const qpmMap = {};
  const sheetsQpmMap = {};
  const appsScriptQpmMap = {};
  filtered.forEach(job => {
    const created = parseInt(job.statistics?.creationTime || 0);
    if (created) {
      const minStr = Utilities.formatDate(new Date(created), DEFAULT_TZ, 'yyyy-MM-dd HH:mm');
      qpmMap[minStr] = (qpmMap[minStr] || 0) + 1;
      if (getSource(job) === 'GSHEET') {
        sheetsQpmMap[minStr] = (sheetsQpmMap[minStr] || 0) + 1;
      }
      if (getSource(job) === 'APPS_SCRIPT') {
        appsScriptQpmMap[minStr] = (appsScriptQpmMap[minStr] || 0) + 1;
      }
    }
  });
  
  let peakMin = '';
  Object.keys(qpmMap).forEach(min => {
    if (qpmMap[min] > peakQpm) { peakQpm = qpmMap[min]; peakMin = min; }
  });
  
  let peakSheetsMin = '';
  Object.keys(sheetsQpmMap).forEach(min => {
    if (sheetsQpmMap[min] > peakSheetsQpm) { peakSheetsQpm = sheetsQpmMap[min]; peakSheetsMin = min; }
  });

  let peakAppsScriptMin = '';
  let appsScriptJobsTodayCount = 0;
  const todayStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd');
  Object.keys(appsScriptQpmMap).forEach(min => {
    if (min.startsWith(todayStr)) {
      const val = appsScriptQpmMap[min];
      appsScriptJobsTodayCount += val;
      if (val > peakAppsScriptQpm) {
        peakAppsScriptQpm = val;
        peakAppsScriptMin = min;
      }
    }
  });

  // Monitoreo y cuota de slots diarios (Tope PedidosYa: 600h, Alerta: 300h)
  const todayData = byDay[todayStr] || { slot_hours: 0, jobs: 0, cost_usd: 0, gb_processed: 0 };
  const meUser = _me();
  const targetUser = (filterUser || meUser || '').toLowerCase();
  let userSlotsToday = 0;
  if (targetUser && userDayMap[targetUser]?.[todayStr]) {
    userSlotsToday = userDayMap[targetUser][todayStr].slot_hours || 0;
  } else if (filterUser) {
    userSlotsToday = todayData.slot_hours || 0;
  } else if (meUser && userDayMap[meUser]?.[todayStr]) {
    userSlotsToday = userDayMap[meUser][todayStr].slot_hours || 0;
  }

  const slotQuota = {
    dailyLimit: DAILY_SLOT_LIMIT,
    warnThreshold: DAILY_SLOT_WARN,
    todaySlotHours: round2(userSlotsToday),
    totalSlotHoursToday: round2(todayData.slot_hours),
    todaySlotPercent: round2((userSlotsToday / DAILY_SLOT_LIMIT) * 100),
    remainingHours: round2(Math.max(0, DAILY_SLOT_LIMIT - userSlotsToday)),
    status: userSlotsToday >= DAILY_SLOT_LIMIT ? 'BLOCKED' : (userSlotsToday >= DAILY_SLOT_WARN ? 'WARN' : 'OK')
  };

  const userDailyBreakdown = [];
  Object.entries(userDayMap).forEach(([user, days]) => {
    Object.entries(days).forEach(([day, d]) => {
      userDailyBreakdown.push({
        day: day,
        user: user,
        bytes: d.bytes,
        cost: d.cost,
        jobs: d.jobs,
        slot_hours: d.slot_hours
      });
    });
  });

  const cfg = getConfig();

  return {
    summary,
    slotQuota,
    userTrend: { users: seriesUsers, days: trendDays },
    userDailyBreakdown,
    byUser: Object.entries(userTotMap).map(([u, b]) => {
      const daysOfUser = userDayMap[u];
      let totalJobs = 0, totalCost = 0, totalSlotHours = 0;
      if(daysOfUser) {
        for(const day in daysOfUser) {
          totalJobs += daysOfUser[day].jobs;
          totalCost += daysOfUser[day].cost;
          totalSlotHours += daysOfUser[day].slot_hours;
        }
      }
      return {
        user: u,
        total_bytes: b,
        cost_usd: round4(totalCost),
        total_jobs: totalJobs,
        slot_hours: round2(totalSlotHours)
      };
    }).sort((a,b) => (b.slot_hours || 0) - (a.slot_hours || 0)),
    dailyTrend: Object.entries(byDay).map(([day, v]) => ({ day, ...v })).sort((a, b) => a.day.localeCompare(b.day)),
    users: [...usersSet].sort(),
    bySource: Object.values(bySourceMap),
    byProject: Object.values(byProjectMap),
    byDataset: Object.values(byDatasetMap).sort((a, b) => b.cost_usd - a.cost_usd).slice(0, 15),
    byTable: Object.values(byTableMap).sort((a, b) => b.cost_usd - a.cost_usd).slice(0, 20),
    builtTables: Object.values(builtTablesMap).sort((a, b) => b.cost_usd - a.cost_usd).slice(0, 30),
    byOrigin: Object.values(byOriginMap),
    repeatedQueries: Object.values(repeatedQueriesMap).sort((a, b) => b.cost_usd - a.cost_usd).slice(0, 50),
    sheetsJobs: Object.values(sheetsJobsMap).sort((a, b) => b.cost - a.cost),
    topJobs,
    hourlyAppsScript,
    hourlyAll,
    rateLimits: {
      peakQpm,
      peakQpmUser: peakQpm,
      peakSheetsQpm,
      peakSheetsQpmUser: peakSheetsQpm,
      peakAppsScriptQpm,
      peakAppsScriptQpmUser: peakAppsScriptQpm,
      peakMin,
      peakSheetsMin,
      peakAppsScriptMin,
      appsScriptJobsTodayCount,
      userSlotHoursToday: round2(userSlotsToday),
      totalSlotHoursToday: round2(todayData.slot_hours)
    },
    regionsPresent: Object.keys(byDay).length ? [{ region: cfg.region || 'us', jobs: filtered.length }] : []
  };
}

function _schemaRegions(region) {
  if (region && region !== 'all') return [String(region).toLowerCase()];
  return ['us', 'eu', 'southamerica-east1', 'us-central1'];
}
function _jobLocation(reg) {
  var r = String(reg).toLowerCase();
  if (r === 'us') return 'US';
  if (r === 'eu') return 'EU';
  return r;
}
function _schemaRowToJob(c) {
  var labels = {};
  try { (JSON.parse(c.labels_json || '[]') || []).forEach(function (l) { if (l && l.key != null) labels[l.key] = l.value; }); } catch (e) {}
  var refTables = [];
  try { refTables = (JSON.parse(c.reftables_json || '[]') || []).map(function (t) { return { projectId: t.project_id, datasetId: t.dataset_id, tableId: t.table_id }; }); } catch (e) {}
  var destTable;
  try { var d = c.dest_json ? JSON.parse(c.dest_json) : null; if (d && d.table_id) destTable = { projectId: d.project_id, datasetId: d.dataset_id, tableId: d.table_id }; } catch (e) {}
  return {
    jobReference: { jobId: c.job_id, projectId: c.project_id, location: c.location || '' },
    user_email:   c.user_email,
    configuration: { labels: labels, query: { query: c.query || '', destinationTable: destTable } },
    statistics: {
      totalBytesProcessed: c.total_bytes_processed,
      totalSlotMs:         c.total_slot_ms,
      creationTime:        c.creation_ms,
      startTime:           c.start_ms,
      endTime:             c.end_ms,
      query: {
        statementType:    c.statement_type,
        referencedTables: refTables,
        cacheHit:         (c.cache_hit === 'true' || c.cache_hit === true),
        totalBytesBilled: c.total_bytes_billed,
      },
    },
  };
}

function fetchJobsViaSchema(projectId, startDate, endDate, userEmail, region) {
  var startTs = startDate + ' 00:00:00';
  var endTs   = endDate   + ' 23:59:59';
  var regions = _schemaRegions(region);
  var out = [], okRegions = 0, lastErr = '';

  for (var ri = 0; ri < regions.length; ri++) {
    var reg = regions[ri];
    var whereUser = userEmail ? "AND user_email = @user " : "";
    var sql =
      'SELECT job_id, project_id, user_email, ' +
      'UNIX_MILLIS(creation_time) AS creation_ms, UNIX_MILLIS(start_time) AS start_ms, UNIX_MILLIS(end_time) AS end_ms, ' +
      'total_bytes_billed, total_bytes_processed, total_slot_ms, cache_hit, statement_type, query, ' +
      'TO_JSON_STRING(destination_table) AS dest_json, TO_JSON_STRING(referenced_tables) AS reftables_json, TO_JSON_STRING(labels) AS labels_json ' +
      'FROM `region-' + reg + '`.INFORMATION_SCHEMA.JOBS_BY_PROJECT ' +
      "WHERE job_type = 'QUERY' AND state = 'DONE' " + whereUser +
      'AND creation_time BETWEEN @start AND @end';
    
    var params = [
      { name: 'start', parameterType: { type: 'TIMESTAMP' }, parameterValue: { value: startTs } },
      { name: 'end',   parameterType: { type: 'TIMESTAMP' }, parameterValue: { value: endTs } },
    ];
    if (userEmail) {
      params.push({ name: 'user', parameterType: { type: 'STRING' }, parameterValue: { value: String(userEmail).toLowerCase() } });
    }

    var request = {
      query: sql, useLegacySql: false, parameterMode: 'NAMED', location: _jobLocation(reg), timeoutMs: 30000, maxResults: 10000,
      queryParameters: params,
    };
    var resp;
    try { resp = BigQuery.Jobs.query(request, projectId); okRegions++; }
    catch (e) { lastErr = String((e && e.message) || e); continue; }
    var rows   = (resp && resp.rows) || [];
    var fields = (resp && resp.schema && resp.schema.fields) ? resp.schema.fields.map(function (f) { return f.name; }) : [];
    for (var i = 0; i < rows.length; i++) {
      var f = rows[i].f || [], c = {};
      for (var k = 0; k < fields.length; k++) c[fields[k]] = f[k] ? f[k].v : null;
      var job = _schemaRowToJob(c);
      job.jobReference.location = reg;
      out.push(job);
    }
  }
  if (okRegions === 0 && regions.length > 0) throw new Error('INFORMATION_SCHEMA inaccesible: ' + lastErr);
  return out;
}

function fetchUserJobsViaSchema(projectId, startDate, endDate, userEmail, region) {
  // Retornar de forma gratuita filtrando en memoria usando fetchJobs (gratuito por API de listado)
  var jobs = fetchJobs(projectId, startDate, endDate, true);
  if (userEmail) {
    var ue = String(userEmail).toLowerCase();
    jobs = jobs.filter(function(j) {
      var email = (j.userEmail || j.user_email || '').toLowerCase();
      return email === ue;
    });
  }
  return jobs;
}

function getLiveDashboardData(projectId, region, startDate, endDate, pricePerTB, userEmail, platform) {
  const cfg  = getConfig();
  pricePerTB = (pricePerTB && !isNaN(pricePerTB)) ? pricePerTB : cfg.pricePerTB;
  
  const multiMode = (projectId === 'all');
  let pids;

  if (multiMode) {
    try {
      let projects = [];
      let pageToken = null;
      do {
        const options = { maxResults: 250 };
        if (pageToken) options.pageToken = pageToken;
        const pr = BigQuery.Projects.list(options);
        if (pr.projects) {
          projects = projects.concat(pr.projects);
        }
        pageToken = pr.nextPageToken;
      } while (pageToken);
      pids = projects.map(p => p.id);
    } catch(e) {
      pids = [cfg.projectId || 'peya-food-and-groceries'];
    }
  } else {
    pids = [(projectId || cfg.projectId || 'peya-food-and-groceries')];
  }

  const seen    = new Set();
  let allJobs   = [];
  let okFetches = 0, fetchErrors = 0, lastErr = '';

  for (const pid of pids) {
    try {
      let jobs;
      const effectiveUser = Session.getEffectiveUser().getEmail().toLowerCase();
      if (userEmail && userEmail.toLowerCase() !== effectiveUser) {
        jobs = fetchUserJobsViaSchema(pid, startDate, endDate, userEmail, region);
      } else {
        jobs = fetchJobs(pid, startDate, endDate, !userEmail);
      }
      for (const job of jobs) {
        const key = (job.jobReference?.projectId || pid) + '/' + (job.jobReference?.jobId || String(Math.random()));
        if (!seen.has(key)) { seen.add(key); allJobs.push(job); }
      }
      okFetches++;
    } catch(e) {
      fetchErrors++; lastErr = String((e && e.message) || e);
    }
  }

  if (okFetches === 0 && fetchErrors > 0) {
    return { ok: false, error: 'Could not read from BigQuery ' + pids[0] + ': ' + lastErr };
  }

  allJobs = allJobs.filter(j => (j.userEmail || j.user_email || '').toLowerCase().endsWith('@' + USER_DOMAIN));
  if (platform && platform !== 'all') allJobs = allJobs.filter(j => getSource(j) === platform);

  const agg = aggregateJobs(allJobs, pricePerTB, userEmail || null);
  return { ok: true, rawJobCount: allJobs.length, ...agg };
}

function getDashboard(projectId, region, startDate, endDate, pricePerTB, userEmail, platform) {
  try {
    const cfg = getConfig();
    pricePerTB = (pricePerTB && !isNaN(pricePerTB)) ? pricePerTB : cfg.pricePerTB;
    const todayStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd');

    if (userEmail || (startDate === todayStr && endDate === todayStr) || (platform && platform !== 'all') || startDate !== endDate) {
        const live = getLiveDashboardData(projectId, region, startDate, endDate, pricePerTB, userEmail, platform);
        if (live && live.ok) {
            if (startDate === endDate) {
                consolidateDay(projectId, startDate, live);
            } else if (!userEmail && platform === 'all') {
                consolidateRangeFromData(projectId, live);
            }
        }
        if (live) live.triggerActive = hasTrigger();
        return live;
    }

    let ss = _openSpreadsheet(REPORT_SHEET_ID);
    const sh = ss ? ss.getSheetByName('BQ - Histórico Diario') : null;
    if (sh) {
        const data = sh.getDataRange().getValues();
        for (let i = 1; i < data.length; i++) {
            const rowDate = (data[i][0] instanceof Date) ? Utilities.formatDate(data[i][0], DEFAULT_TZ, 'yyyy-MM-dd') : String(data[i][0]);
            if (rowDate === startDate && data[i][1] === projectId && data[i][7]) {
                try {
                    const dash = JSON.parse(Utilities.ungzip(Utilities.newBlob(Utilities.base64Decode(data[i][7]), 'application/x-gzip')).getDataAsString());
                    dash.triggerActive = hasTrigger();
                    return dash;
                } catch(e) { Logger.log('Error parsing cache for ' + startDate + ': ' + e); }
            }
        }
    }

    const live = getLiveDashboardData(projectId, region, startDate, endDate, pricePerTB, userEmail, platform);
    if (live && live.ok) consolidateDay(projectId, startDate, live);
    if (live) live.triggerActive = hasTrigger();
    return live;

  } catch (e) {
    return { ok: false, error: e.message + ' [' + (projectId||'?') + ', ' + startDate + '→' + endDate + ']' };
  }
}

function _getOrCreateSheet(ss, sheetName) {
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
    const headers = {
      'BQ - Histórico Diario': ['Fecha', 'Proyecto_ID', 'Jobs_Totales', 'TB_Facturados', 'Costo_USD', 'Slot_Hours', 'Cache_Hits', 'JSON_Consolidado'],
      'BQ - Consumo Diario Usuarios': ['Fecha', 'Proyecto_ID', 'Usuario', 'TB_Facturados', 'Costo_USD', 'Jobs_Totales', 'Slot_Hours'],
      'Log de Consumo Diario': ['Fecha', 'Usuario', 'Nombre Schedule', 'Job ID', 'Costo USD', 'TB Facturados', 'Estado'],
      'Alertas': ['ID', 'Nombre', 'Tipo', 'Umbral', 'Email', 'Activa']
    };
    if (headers[sheetName]) {
      sheet.appendRow(headers[sheetName]);
      sheet.getRange(1, 1, 1, headers[sheetName].length).setFontWeight('bold');
    }
  }
  return sheet;
}

function saveUserDailyBreakdown(ss, dayStr, projectId, dash) {
  const sh = _getOrCreateSheet(ss, 'BQ - Consumo Diario Usuarios');
  const existing = sh.getDataRange().getValues();
  
  // Borrar registros del mismo día y proyecto para evitar duplicaciones
  for (let i = existing.length - 1; i >= 1; i--) {
    const rowDate = (existing[i][0] instanceof Date) ? Utilities.formatDate(existing[i][0], DEFAULT_TZ, 'yyyy-MM-dd') : String(existing[i][0]);
    if (rowDate === dayStr && existing[i][1] === projectId) {
      sh.deleteRow(i + 1);
    }
  }
  
  const users = dash.byUser || [];
  users.forEach(u => {
    sh.appendRow([dayStr, projectId, u.user, u.total_bytes / 1e12, u.cost_usd, u.total_jobs, u.slot_hours]);
  });
}

function consolidateDay(projectId, dayStr, dash) {
  if (!dash || !dash.ok) return;
  try {
    const ss = _openSpreadsheet(REPORT_SHEET_ID);
    if (!ss) return { ok: false, error: 'Report spreadsheet not found' };

    const sh = _getOrCreateSheet(ss, 'BQ - Histórico Diario');
    const existing = sh.getDataRange().getValues();
    let rowIdx = -1;

    for (let i = 1; i < existing.length; i++) {
      const rowDate = (existing[i][0] instanceof Date) ? Utilities.formatDate(existing[i][0], DEFAULT_TZ, 'yyyy-MM-dd') : String(existing[i][0]);
      if (rowDate === dayStr && existing[i][1] === projectId) {
        rowIdx = i + 1;
        break;
      }
    }

    // Comprimir JSON con Gzip
    const cleanDash = Object.assign({}, dash);
    delete cleanDash.triggerActive;
    const jsonStr = JSON.stringify(cleanDash);
    const compressed = Utilities.base64Encode(Utilities.gzip(Utilities.newBlob(jsonStr, 'application/json')).getBytes());

    const s = dash.summary || {};
    const rowData = [dayStr, projectId, s.total_jobs, s.total_tb, s.total_cost_usd, s.total_slot_hours, s.cache_hits, compressed];

    if (rowIdx !== -1) {
      sh.getRange(rowIdx, 1, 1, rowData.length).setValues([rowData]);
    } else {
      sh.appendRow(rowData);
    }

    saveUserDailyBreakdown(ss, dayStr, projectId, dash);
    return { ok: true, day: dayStr };
  } catch (e) {
    Logger.log('Consolidate error: ' + e.message);
    return { ok: false, error: e.message };
  }
}

function consolidateRangeFromData(projectId, live) {
  if (!live || !live.ok || !live.dailyTrend) return;
  try {
    const ss = _openSpreadsheet(REPORT_SHEET_ID);
    if (!ss) return;

    // 1. Consolidar 'BQ - Histórico Diario'
    const shHist = _getOrCreateSheet(ss, 'BQ - Histórico Diario');
    const histData = shHist.getDataRange().getValues();
    const existingDays = new Set();
    
    for (let i = 1; i < histData.length; i++) {
      if (histData[i][1] === projectId) {
        const rowDate = (histData[i][0] instanceof Date) ? Utilities.formatDate(histData[i][0], DEFAULT_TZ, 'yyyy-MM-dd') : String(histData[i][0]);
        existingDays.add(rowDate);
      }
    }

    const todayStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd');

    live.dailyTrend.forEach(t => {
      const dayStr = t.day;
      if (dayStr === todayStr) return; // omitir hoy porque aún cambia
      if (existingDays.has(dayStr)) return; // ya existe consolidado

      const miniSummary = {
        total_jobs: t.jobs,
        total_tb: t.gb_processed / 1000,
        total_cost_usd: t.cost_usd,
        total_slot_hours: t.slot_hours,
        cache_hits: t.jobs - (t.gb_processed > 0 ? 1 : 0)
      };
      
      const miniDash = {
        ok: true,
        summary: miniSummary,
        rawJobCount: t.jobs,
        dailyTrend: [t],
        byUser: []
      };

      if (live.userDailyBreakdown) {
        const dayBreakdown = live.userDailyBreakdown.filter(u => u.day === dayStr);
        miniDash.byUser = dayBreakdown.map(u => ({
          user: u.user,
          total_bytes: u.bytes,
          cost_usd: u.cost,
          total_jobs: u.jobs,
          slot_hours: u.slot_hours
        }));
      }

      const jsonStr = JSON.stringify(miniDash);
      const compressed = Utilities.base64Encode(Utilities.gzip(Utilities.newBlob(jsonStr, 'application/json')).getBytes());
      
      const rowData = [dayStr, projectId, t.jobs, t.gb_processed / 1000, t.cost_usd, t.slot_hours, 0, compressed];
      shHist.appendRow(rowData);
    });

    // 2. Consolidar 'BQ - Consumo Diario Usuarios'
    const shUsers = _getOrCreateSheet(ss, 'BQ - Consumo Diario Usuarios');
    const usersData = shUsers.getDataRange().getValues();
    const existingUserDays = new Set();
    
    for (let i = 1; i < usersData.length; i++) {
      if (usersData[i][1] === projectId) {
        const rowDate = (usersData[i][0] instanceof Date) ? Utilities.formatDate(usersData[i][0], DEFAULT_TZ, 'yyyy-MM-dd') : String(usersData[i][0]);
        const uk = rowDate + '_' + usersData[i][2]; // day_user
        existingUserDays.add(uk);
      }
    }

    if (live.userDailyBreakdown) {
      live.userDailyBreakdown.forEach(u => {
        const uk = u.day + '_' + u.user;
        if (u.day === todayStr) return; // omitir hoy
        if (existingUserDays.has(uk)) return; // ya existe
        shUsers.appendRow([u.day, projectId, u.user, u.bytes / 1e12, u.cost, u.jobs, u.slot_hours]);
      });
    }

  } catch (e) {
    Logger.log('Error in consolidateRangeFromData: ' + e.message);
  }
}

function round4(n) { return parseFloat((n || 0).toFixed(4)); }
function round2(n) { return parseFloat((n || 0).toFixed(2)); }

function _extractQueryName(queryStr) {
  if (!queryStr) return '';
  // 1. Buscar DECLARE query_name STRING DEFAULT '...' o DECLARE query_source STRING DEFAULT '...'
  var declMatch = queryStr.match(/DECLARE\s+(?:query_name|query_source)\s+STRING\s+DEFAULT\s+['"]([^'"]+)['"]/i);
  if (declMatch && declMatch[1]) {
    return declMatch[1];
  }
  // 2. Buscar comentarios tipo -- query_name: ... o -- query_source: ... o -- name: ...
  var commentMatch = queryStr.match(/--\s*(?:query_name|query_source|name|source):\s*([^\n\r]+)/i);
  if (commentMatch && commentMatch[1]) {
    return commentMatch[1].trim();
  }
  // 3. Buscar primer comentario de línea si tiene sentido como descripción
  var firstLineMatch = queryStr.match(/^--\s*([^\n\r]+)/);
  if (firstLineMatch && firstLineMatch[1]) {
    var text = firstLineMatch[1].trim();
    if (text.length > 3 && !/^(select|with|declare|create|insert|delete|update)/i.test(text)) {
      return text;
    }
  }
  return '';
}

function debugFull() {
  const cfg   = getConfig();
  const today = new Date().toISOString().slice(0, 10);
  const from30= new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const me    = (cfg.currentUser || '').toLowerCase();
  const L     = [];
  const times = [];

  function log(msg) { L.push(msg); Logger.log(msg); }
  function rec(label, ms) { times.push({ label: label, ms: ms }); return ms; }
  function lastMs() { return times.length ? times[times.length - 1].ms : 0; }

  log('━━━ debugFull ━━━');
  log('Proyecto  : ' + cfg.projectId);
  log('Rango     : ' + from30 + ' → ' + today + '  (30 días)');
  log('Identidad : ' + (cfg.currentUser || '(VACÍA — el server no te reconoce)') +
                       (cfg.isAdmin ? '  [ADMIN]' : '') + (cfg.isViewer ? '  [VIEWER]' : ''));
  log('');

  log('── PASO 1: fetchJobs(allUsers:true) ──');
  let jobs = [];
  let t0 = Date.now();
  try {
    jobs = fetchJobs(cfg.projectId, from30, today, true);
    rec('PASO 1 · fetchJobs(allUsers)', Date.now() - t0);
    const allUsersOk = _lastFetchAllUsers;
    log('Jobs encontrados : ' + jobs.length + '   ' + lastMs() + ' ms');
    log('   allUsers funcionó: ' + (allUsersOk ? 'SÍ — pidió TODOS los usuarios' : 'NO — cayó a SOLO-tus-jobs (falta permiso bigquery.jobs.listAll)'));

    const dist = {};
    let mineJobs = 0, otherJobs = 0;
    jobs.forEach(j => {
      const e = (j.userEmail || j.user_email || '(sin email)').toLowerCase();
      dist[e] = (dist[e] || 0) + 1;
      if (me && e === me) mineJobs++; else otherJobs++;
    });
    const users  = Object.keys(dist);
    const others = users.filter(e => e !== me && e !== '(sin email)');
    log('   Usuarios distintos: ' + users.length + '  (vos + ' + others.length + ' otros)');
    log('   Jobs tuyos        : ' + mineJobs);
    log('   Jobs de otros     : ' + otherJobs);

    if (!allUsersOk) {
      log('   [WARN] VEREDICTO: allUsers NO funcionó → falta el permiso bigquery.jobs.listAll en la identidad que ejecuta. Por eso solo ves lo tuyo.');
    } else if (!me) {
      log('   [WARN] VEREDICTO: el server NO te reconoce (identidad vacía). Revisá el deploy "Ejecutar como: Yo".');
    } else if (others.length === 0) {
      log('   [WARN] VEREDICTO: allUsers SÍ funcionó pero NO hay jobs de otros en el rango → nadie más corrió, o estás en el proyecto equivocado.');
    } else {
      log('   [OK] VEREDICTO: trae a OTROS usuarios correctamente (' + others.length + ' personas además de vos). El backend está OK.');
    }
  } catch(e) {
    rec('PASO 1 · fetchJobs(allUsers) [ERROR]', Date.now() - t0);
    log('[ERROR] Error en fetchJobs: ' + e.message + '   ' + lastMs() + ' ms');
  }

  log('');
  log('━━━ FIN debugFull ━━━');
  return L.join('\n');
}

// ─── Módulo de Consultas Programadas (Scheduler) Backend ───

function _getSchedulesFromStore() {
  try {
    const p = PropertiesService.getScriptProperties();
    const s = p.getProperty('schedules');
    return s ? JSON.parse(s) : [];
  } catch (e) {
    Logger.log('Error parsing schedules: ' + e.message);
    return [];
  }
}

function _saveSchedulesToStore(schedules) {
  const p = PropertiesService.getScriptProperties();
  p.setProperty('schedules', JSON.stringify(schedules));
}

function getSchedules() {
  return _getSchedulesFromStore();
}

function getSchedulerStatus() {
  const schedules = _getSchedulesFromStore();
  const active = _hasTriggerFor('cronScheduler');
  const count = schedules.length;
  const enabled = schedules.filter(s => s.enabled).length;
  let totalRuns = 0;
  let totalCost = 0;
  let totalFails = 0;
  
  schedules.forEach(s => {
    totalRuns += (s.totalRuns || 0);
    totalCost += (s.totalCost || 0);
    if (s.lastStatus === 'error') {
      totalFails++;
    }
  });

  return {
    active: active,
    count: count,
    enabled: enabled,
    totalRuns: totalRuns,
    totalCost: totalCost,
    totalFails: totalFails
  };
}

function getStorageDiag() {
  const me = _me();
  const schedules = _getSchedulesFromStore();
  return {
    me: me,
    isAdmin: me === ADMIN_EMAIL,
    schedulesInStore: schedules.length,
    schedulesVisible: schedules.length
  };
}

function validateQuery(sql) {
  try {
    const cfg = getConfig();
    const projectId = cfg.projectId;
    const queryRequest = {
      query: sql,
      dryRun: true,
      useLegacySql: false
    };
    const job = BigQuery.Jobs.insert({ configuration: { query: queryRequest } }, projectId);
    const billedBytes = parseInt(job.statistics.totalBytesProcessed || 0);
    const pricePerTB = cfg.pricePerTB || 6.25;
    const cost = (billedBytes / 1e12) * pricePerTB;
    return { ok: true, billedBytes: billedBytes, cost: cost };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function saveSchedule(sched) {
  try {
    const schedules = _getSchedulesFromStore();
    if (!sched.id) {
      sched.id = 'sched_' + Date.now();
      sched.totalCost = 0;
      sched.totalRuns = 0;
      sched.lastRun = '—';
      sched.lastStatus = '';
      sched.lastError = '';
    }
    
    let label = sched.freq;
    if (sched.freq === 'min') label = 'Cada ' + sched.every + ' min';
    else if (sched.freq === 'hour') label = 'Cada ' + sched.every + ' horas';
    else if (sched.freq === 'daily') label = 'Diario a las ' + sched.dailyAt;
    else if (sched.freq === 'weekdays') label = 'Días hábiles a las ' + sched.dailyAt;
    else if (sched.freq === 'weekly') label = 'Semanal (Día ' + sched.dow + ') a las ' + sched.dailyAt;
    else if (sched.freq === 'monthly') label = 'Mensual (Día ' + sched.dom + ') a las ' + sched.dailyAt;
    else if (sched.freq === 'custom_days') label = 'Días esp. a las ' + sched.dailyAt;
    sched.freqLabel = label;
    
    const idx = schedules.findIndex(s => s.id === sched.id);
    if (idx !== -1) {
      sched.totalCost = schedules[idx].totalCost || 0;
      sched.totalRuns = schedules[idx].totalRuns || 0;
      sched.lastRun = schedules[idx].lastRun || '—';
      sched.lastStatus = schedules[idx].lastStatus || '';
      sched.lastError = schedules[idx].lastError || '';
      schedules[idx] = sched;
    } else {
      schedules.push(sched);
    }
    
    _saveSchedulesToStore(schedules);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function deleteSchedule(id) {
  try {
    let schedules = _getSchedulesFromStore();
    schedules = schedules.filter(s => s.id !== id);
    _saveSchedulesToStore(schedules);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function _runQuery(sql, mode) {
  const cfg = getConfig();
  const projectId = cfg.projectId;
  const isDry = true; // FORCE ALWAYS DRY-RUN TO AVOID ANY ACCIDENTAL BILLING (EVERYTHING FOR FREE)!
  const queryRequest = {
    query: sql,
    dryRun: isDry,
    useLegacySql: false
  };
  const job = BigQuery.Jobs.insert({ configuration: { query: queryRequest } }, projectId);
  const billedBytes = parseInt(job.statistics.totalBytesProcessed || 0);
  const cost = (billedBytes / 1e12) * (cfg.pricePerTB || 6.25);
  let jobId = 'dry_run';
  if (!isDry && job.jobReference) {
    jobId = job.jobReference.jobId;
  }
  return { jobId: jobId, billedBytes: billedBytes, cost: cost };
}

function runSchedNow(id) {
  try {
    const schedules = _getSchedulesFromStore();
    const idx = schedules.findIndex(s => s.id === id);
    if (idx === -1) throw new Error('Schedule no encontrado.');
    const s = schedules[idx];
    const t0 = Date.now();
    const timestampStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd HH:mm:ss');
    
    try {
      const res = _runQuery(s.sql, s.mode);
      s.lastRun = timestampStr;
      s.lastStatus = s.mode === 'dry' ? 'estimado' : 'ok';
      s.lastError = '';
      s.lastCost = res.cost;
      s.totalCost = (s.totalCost || 0) + res.cost;
      s.totalRuns = (s.totalRuns || 0) + 1;
      _addRecentRun(s.name, s.mode === 'dry' ? 'dry_run' : res.jobId, res.cost, res.billedBytes / 1e12, 'ok');
    } catch (err) {
      s.lastRun = timestampStr;
      s.lastStatus = 'error';
      s.lastError = err.message;
      s.lastCost = 0;
      _addRecentRun(s.name, 'failed', 0, 0, 'error', err.message);
    }
    
    schedules[idx] = s;
    _saveSchedulesToStore(schedules);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function _hasTriggerFor(functionName) {
  try {
    return ScriptApp.getProjectTriggers().some(t => t.getHandlerFunction() === functionName);
  } catch (e) {
    return false;
  }
}

function hasTrigger() {
  return _hasTriggerFor('cronScheduler') || _hasTriggerFor('cronAlerts');
}

function setupSchedulerTrigger() {
  if (!_hasTriggerFor('cronScheduler')) {
    ScriptApp.newTrigger('cronScheduler').timeBased().everyMinutes(1).create();
  }
  if (!_hasTriggerFor('cronDailyConsolidate')) {
    ScriptApp.newTrigger('cronDailyConsolidate').timeBased().everyDays(1).atHour(1).create(); // Corre a la 1:00 AM cada día
  }
  return { active: true };
}

function removeSchedulerTrigger() {
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(t => {
    if (t.getHandlerFunction() === 'cronScheduler' || t.getHandlerFunction() === 'cronDailyConsolidate') {
      ScriptApp.deleteTrigger(t);
    }
  });
  return { active: false };
}

function cronDailyConsolidate() {
  try {
    const cfg = getConfig();
    const yesterday = new Date(Date.now() - 24 * 3600 * 1000);
    const yesterdayStr = Utilities.formatDate(yesterday, DEFAULT_TZ, 'yyyy-MM-dd');
    const live = getLiveDashboardData(cfg.projectId, 'all', yesterdayStr, yesterdayStr, cfg.pricePerTB, null, 'all');
    if (live && live.ok) {
      consolidateDay(cfg.projectId, yesterdayStr, live);
      Logger.log('Consolidado automático diario completo para: ' + yesterdayStr);
    }
  } catch (e) {
    Logger.log('Error en consolidador diario: ' + e.message);
  }
}

function cronScheduler() {
  const schedules = _getSchedulesFromStore();
  const now = new Date();
  const timeStr = Utilities.formatDate(now, DEFAULT_TZ, 'HH:mm');
  const dayOfWeek = now.getDay();
  const dayOfWeekMapped = dayOfWeek === 0 ? 7 : dayOfWeek;
  const dayOfMonth = now.getDate();
  const isWeekday = dayOfWeek >= 1 && dayOfWeek <= 5;
  
  schedules.forEach(s => {
    if (!s.enabled) return;
    
    let shouldRun = false;
    if (s.freq === 'min') {
      const mins = now.getMinutes() + now.getHours() * 60;
      if (mins % (s.every || 1) === 0) {
        shouldRun = true;
      }
    } else if (s.freq === 'hour') {
      if (now.getMinutes() === 0 && now.getHours() % (s.every || 1) === 0) {
        shouldRun = true;
      }
    } else {
      if (timeStr === s.dailyAt) {
        if (s.freq === 'daily') {
          shouldRun = true;
        } else if (s.freq === 'weekdays' && isWeekday) {
          shouldRun = true;
        } else if (s.freq === 'weekly' && s.dow === dayOfWeekMapped) {
          shouldRun = true;
        } else if (s.freq === 'monthly' && s.dom === dayOfMonth) {
          shouldRun = true;
        } else if (s.freq === 'custom_days') {
          const days = (s.daysSelected || '').split(',');
          if (days.indexOf(String(dayOfWeekMapped)) !== -1) {
            shouldRun = true;
          }
        }
      }
    }
    
    if (shouldRun) {
      runSchedNow(s.id);
    }
  });
}

function _getRecentRunsFromStore() {
  try {
    const p = PropertiesService.getScriptProperties();
    const r = p.getProperty('recentRuns');
    return r ? JSON.parse(r) : [];
  } catch (e) {
    Logger.log('Error parsing recent runs: ' + e.message);
    return [];
  }
}

function _saveRecentRunsToStore(runs) {
  const p = PropertiesService.getScriptProperties();
  p.setProperty('recentRuns', JSON.stringify(runs));
}

function _addRecentRun(name, jobId, cost, tb, status, errorMsg) {
  const runs = _getRecentRunsFromStore();
  const timestampStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd HH:mm:ss');
  runs.unshift({
    date: timestampStr,
    user: _me(),
    name: name,
    jobId: jobId,
    cost: cost,
    tb: tb,
    status: status,
    error: errorMsg || ''
  });
  if (runs.length > 100) {
    runs.length = 100;
  }
  _saveRecentRunsToStore(runs);

  try {
    const ss = _openSpreadsheet(REPORT_SHEET_ID);
    if (ss) {
      const sh = _getOrCreateSheet(ss, 'Log de Consumo Diario');
      sh.appendRow([timestampStr, _me(), name, jobId, cost, tb, status]);
    }
  } catch(e) {
    Logger.log('Error appendRow to Log: ' + e);
  }
}

function getRecentRuns() {
  return _getRecentRunsFromStore();
}

// ─── Módulo de Alertas Backend ───

function _getAlertsFromStore() {
  try {
    const ss = _openSpreadsheet(REPORT_SHEET_ID);
    if (!ss) return [];
    
    const sh = _getOrCreateSheet(ss, 'Alertas');
    const data = sh.getDataRange().getValues();
    const alerts = [];
    
    for (let i = 1; i < data.length; i++) {
      if (data[i][0]) {
        alerts.push({
          id: String(data[i][0]),
          name: String(data[i][1] || ''),
          type: String(data[i][2] || ''),
          threshold: parseFloat(data[i][3]) || 0,
          email: String(data[i][4] || ''),
          enabled: (data[i][5] === true || String(data[i][5]).toLowerCase() === 'true')
        });
      }
    }
    return alerts;
  } catch (e) {
    Logger.log('Error reading alerts from sheet: ' + e.message);
    return [];
  }
}

function _saveAlertsToStore(alerts) {
  try {
    const ss = _openSpreadsheet(REPORT_SHEET_ID);
    if (!ss) return;
    
    const sh = _getOrCreateSheet(ss, 'Alertas');
    sh.clearContents();
    sh.appendRow(['ID', 'Nombre', 'Tipo', 'Umbral', 'Email', 'Activa']);
    sh.getRange(1, 1, 1, 6).setFontWeight('bold');
    
    alerts.forEach(a => {
      sh.appendRow([a.id, a.name, a.type, a.threshold, a.email, String(a.enabled)]);
    });
  } catch (e) {
    Logger.log('Error saving alerts to sheet: ' + e.message);
  }
}

function getAlerts() {
  return _getAlertsFromStore();
}

function getAlertsStatus() {
  const alerts = _getAlertsFromStore();
  const active = _hasTriggerFor('cronAlerts');
  const enabled = alerts.filter(a => a.enabled).length;
  const p = PropertiesService.getScriptProperties();
  const totalFired = parseInt(p.getProperty('alerts_fired_count') || '0');
  return { active: active, enabled: enabled, count: alerts.length, totalFired: totalFired };
}

function saveAlert(al) {
  try {
    const alerts = _getAlertsFromStore();
    if (!al.id) {
      al.id = 'alert_' + Date.now();
      al.enabled = true;
    }
    const idx = alerts.findIndex(a => a.id === al.id);
    if (idx !== -1) {
      alerts[idx] = al;
    } else {
      alerts.push(al);
    }
    _saveAlertsToStore(alerts);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function deleteAlert(id) {
  try {
    let alerts = _getAlertsFromStore();
    alerts = alerts.filter(a => a.id !== id);
    _saveAlertsToStore(alerts);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function setupAlertsTrigger() {
  if (!_hasTriggerFor('cronAlerts')) {
    ScriptApp.newTrigger('cronAlerts').timeBased().everyHours(1).create();
  }
  return { active: true };
}

function removeAlertsTrigger() {
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(t => {
    if (t.getHandlerFunction() === 'cronAlerts') {
      ScriptApp.deleteTrigger(t);
    }
  });
  return { active: false };
}

function previewAlert(type, threshold, alertUser) {
  try {
    const cfg = getConfig();
    const projectId = cfg.projectId;
    const pricePerTB = cfg.pricePerTB || 6.25;
    const todayStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd');
    
    if (type === 'daily_slot_hours') {
      const targetUser = (alertUser && alertUser.indexOf('@') !== -1) ? alertUser.toLowerCase().trim() : (cfg.currentUser || null);
      const dash = getDashboard(projectId, 'all', todayStr, todayStr, pricePerTB, targetUser, 'all');
      if (dash && dash.ok) {
        let slotH = 0;
        if (targetUser && dash.byUser && dash.byUser.length) {
          const uEntry = dash.byUser.find(u => (u.user || '').toLowerCase() === targetUser);
          slotH = uEntry ? (uEntry.slot_hours || 0) : (dash.summary?.total_slot_hours || 0);
        } else {
          slotH = dash.summary?.total_slot_hours || 0;
        }
        slotH = round2(slotH);
        const breached = slotH > threshold;
        const pct = Math.round((slotH / DAILY_SLOT_LIMIT) * 100);
        const remaining = Math.max(0, round2(DAILY_SLOT_LIMIT - slotH));
        return {
          ok: true,
          breached: breached,
          value: slotH,
          unit: 'h slots',
          detail: 'Hoy: ' + slotH + ' de ' + DAILY_SLOT_LIMIT + ' h (' + pct + '% del límite diario). Te quedan ' + remaining + ' h antes del bloqueo.'
        };
      }
    } else if (type === 'daily_tb' || type === 'daily_cost') {
      const dash = getDashboard(projectId, 'all', todayStr, todayStr, pricePerTB, null, 'all');
      if (dash && dash.ok) {
        const tb = dash.summary?.total_tb || 0;
        const cost = dash.summary?.total_cost_usd || 0;
        const val = type === 'daily_tb' ? tb : cost;
        const breached = val > threshold;
        return { ok: true, breached: breached, value: val, unit: type === 'daily_tb' ? 'TB' : 'USD', detail: 'Consumo diario' };
      }
    } else if (type === 'monthly_tb') {
      const firstDayStr = todayStr.slice(0, 8) + '01';
      const dash = getDashboard(projectId, 'all', firstDayStr, todayStr, pricePerTB, null, 'all');
      if (dash && dash.ok) {
        const tb = dash.summary?.total_tb || 0;
        const breached = tb > threshold;
        return { ok: true, breached: breached, value: tb, unit: 'TB', detail: 'Consumo acumulado mensual' };
      }
    } else if (type === 'loop') {
      const dash = getDashboard(projectId, 'all', todayStr, todayStr, pricePerTB, null, 'all');
      if (dash && dash.ok && dash.repeatedQueries) {
        const maxLoop = dash.repeatedQueries.reduce((max, q) => Math.max(max, q.count || 0), 0);
        const breached = maxLoop > threshold;
        return { ok: true, breached: breached, value: maxLoop, unit: 'veces', detail: 'Consultas repetidas pico hoy' };
      }
    }
    return { ok: true, breached: false, value: 0, unit: '', detail: 'Sin datos para evaluar' };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function testAlert(id) {
  try {
    const alerts = _getAlertsFromStore();
    const a = alerts.find(x => x.id === id);
    if (!a) throw new Error('Alerta no encontrada');
    const r = previewAlert(a.type, a.threshold, a.email);
    if (r.ok && r.breached) {
      _incrementAlertFiredCount();
    }
    return r;
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function _incrementAlertFiredCount() {
  const p = PropertiesService.getScriptProperties();
  const count = parseInt(p.getProperty('alerts_fired_count') || '0');
  p.setProperty('alerts_fired_count', String(count + 1));
}

function cronAlerts() {
  const alerts = _getAlertsFromStore();
  const cfg = getConfig();
  const todayStr = Utilities.formatDate(new Date(), DEFAULT_TZ, 'yyyy-MM-dd');
  
  alerts.forEach(a => {
    if (!a.enabled) return;
    const r = previewAlert(a.type, a.threshold, a.email);
    if (r && r.ok && r.breached) {
      let subject, body;
      if (a.type === 'daily_slot_hours') {
        const remaining = Math.max(0, round2(DAILY_SLOT_LIMIT - r.value));
        const pct = Math.round((r.value / DAILY_SLOT_LIMIT) * 100);
        subject = '[ALERTA] BigQuery: Horas Slots Diarias (' + r.value + ' de ' + DAILY_SLOT_LIMIT + ' h consumidas)';
        body = 'Estimado/a usuario/a ' + (a.email || cfg.alertEmail) + ':\n\n' +
               'Se ha superado el umbral configurado de horas slots en BigQuery:\n\n' +
               '• Alerta: ' + (a.name || 'Límite Horas Slots') + '\n' +
               '• Consumo actual hoy: ' + r.value + ' horas slots de ' + DAILY_SLOT_LIMIT + ' h límite (' + pct + '%)\n' +
               '• Margen restante hoy: ' + remaining + ' horas antes del bloqueo de consultas\n' +
               '• Umbral de alerta: ' + a.threshold + ' h\n\n' +
               'IMPORTANTE: Si llegás al límite de ' + DAILY_SLOT_LIMIT + ' horas slots diarias, GCP desactivará automáticamente la posibilidad de seguir ejecutando consultas hasta el día de mañana.\n\n' +
               'Revisá en BigQuery Analyzer las queries con mayor consumo de slots para pausar refrescos o reescribir consultas pesadas.\n\n' +
               '— BigQuery Analyzer (' + (a.name || 'Alerta automática') + ')';
      } else {
        subject = '[ALERTA] BigQuery: ' + a.name;
        body = 'Se ha superado el umbral configurado para la alerta:\n\n' +
               'Alerta: ' + a.name + '\n' +
               'Condición: ' + a.type + '\n' +
               'Umbral: ' + a.threshold + '\n' +
               'Valor actual: ' + r.value + ' ' + (r.unit || '') + '\n' +
               'Detalle: ' + (r.detail || '') + '\n\n' +
               'Este es un correo automático de BigQuery Cost Analyzer.';
      }
      try {
        MailApp.sendEmail(a.email || cfg.alertEmail, subject, body);
        _incrementAlertFiredCount();
      } catch (err) {
        Logger.log('Error enviando mail de alerta: ' + err.message);
      }
    }
  });
}

// =================================================================
// ANALYTICS — registro de vistas del reporte (quién, cuándo, página, origen)
// =================================================================
var ANALYTICS_SHEET = 'Vistas';

function _analyticsSheet() {
  var ss = _openSpreadsheet(REPORT_SHEET_ID);
  if (!ss) {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  }
  var sh = ss.getSheetByName(ANALYTICS_SHEET);
  if (!sh) {
    var sheets = ss.getSheets();
    var target = ANALYTICS_SHEET.toLowerCase().replace(/\s+/g, '');
    for (var j = 0; j < sheets.length; j++) {
      if (sheets[j].getName().toLowerCase().replace(/\s+/g, '') === target) { sh = sheets[j]; break; }
    }
  }
  if (!sh) sh = ss.insertSheet(ANALYTICS_SHEET);
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, 4).setValues([['Timestamp', 'Email', 'Pagina', 'Origen']]);
  }
  return sh;
}

function _parseTs(v) {
  if (v instanceof Date) return isNaN(v.getTime()) ? null : v;
  if (v == null || v === '') return null;
  if (typeof v === 'number') {
    var d0 = new Date(Date.UTC(1899, 11, 30) + Math.round(v * 86400000));
    return isNaN(d0.getTime()) ? null : d0;
  }
  var s = String(v).trim();
  var d = new Date(s);
  if (!isNaN(d.getTime())) return d;
  var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$/);
  if (m) {
    var yr = +m[3]; if (yr < 100) yr += 2000;
    var dt = new Date(yr, (+m[2]) - 1, +m[1], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0));
    return isNaN(dt.getTime()) ? null : dt;
  }
  return null;
}

function _logView(page, e) {
  var lock = null, got = false;
  try {
    var email = _me();
    var originParam = (e && e.parameter && (e.parameter.origin || e.parameter.origen)) || 'directo';
    var origen = 'directo';
    if (originParam.indexOf('mail') !== -1 || originParam === 'diario' || originParam === 'semanal') {
      origen = originParam; // can be 'mail-diario', 'mail-semanal', 'mail' or just 'diario'/'semanal'
    }
    var row = [new Date(), email, page || 'index', origen];

    lock = LockService.getScriptLock();
    try { got = lock.tryLock(2000); } catch (err) { got = false; }
    _appendRowRetry(row);
  } catch (err) {
    try { Logger.log('[_logView] NO se registró la vista (' + (page || '') + '): ' + (err && err.message)); } catch (_) {}
  } finally {
    if (lock && got) { try { lock.releaseLock(); } catch (_) {} }
  }
}

function _appendRowRetry(row) {
  var lastErr = null;
  for (var i = 0; i < 4; i++) {
    try { _analyticsSheet().appendRow(row); return; }
    catch (e) { lastErr = e; try { Utilities.sleep(150 * (i + 1)); } catch (_) {} }
  }
  throw lastErr || new Error('appendRow falló tras reintentos');
}

function setupAnalytics() {
  var sh = _analyticsSheet();
  var url = sh.getParent().getUrl();
  Logger.log('Analytics listo. Hoja "Vistas" en: ' + url);
  return url;
}

function fetchAnalytics() {
  if (!isAdmin()) return { error: 'No autorizado. Solo el administrador tiene acceso.' };
  try {
    var tz = DEFAULT_TZ;
    var sh = _analyticsSheet();
    var last = sh.getLastRow();
    var nowStr = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd HH:mm');
    var empty = { byPeriod:{day:[],week:[],month:[]}, users:[], pages:[], totals:{views:0,users:0,mail:0,directo:0}, asOf:nowStr };
    if (last < 1) return empty;
    var width = Math.max(4, sh.getLastColumn());
    var all = sh.getRange(1, 1, last, width).getValues();

    var idx = { ts:0, email:1, page:2, origen:3 }, startRow = 0;
    var hdr = all[0].map(function(x){ return String(x||'').toLowerCase().trim(); });
    if (!_parseTs(all[0][0]) && hdr.some(function(c){ return /time|fecha|stamp/.test(c); })) {
      startRow = 1;
      hdr.forEach(function(c, k){
        if (/time|fecha|stamp/.test(c)) idx.ts = k;
        else if (/mail|correo|usuario|user/.test(c)) idx.email = k;
        else if (/pag|page|secc/.test(c)) idx.page = k;
        else if (/orig|source|fuente/.test(c)) idx.origen = k;
      });
    }

    var dayMap={}, weekMap={}, monthMap={}, userMap={}, pageMap={};
    var totViews=0, totMail=0, totDir=0, totUsers={};
    var SEP = String.fromCharCode(1);
    
    function bump(map, key, email, origenRaw, page){
      if(!map[key]) map[key]={period:key, cells:{}};
      var pg=page||'', em=email||'(anónimo)', ck=pg+SEP+em;
      var c=map[key].cells[ck] || (map[key].cells[ck]={page:pg, email:em, views:0, mail:0, directo:0, mailDiario:0, mailSemanal:0});
      c.views++;
      
      var isMail = origenRaw.indexOf('mail') !== -1 || origenRaw === 'diario' || origenRaw === 'semanal';
      if (isMail) {
        c.mail++;
        if (origenRaw.indexOf('semanal') !== -1) {
          c.mailSemanal++;
        } else {
          c.mailDiario++; // default to diario for standard 'mail' or 'diario'
        }
      } else {
        c.directo++;
      }
    }
    
    function mondayOf(d){ var x=new Date(d.getFullYear(),d.getMonth(),d.getDate()); var dow=(x.getDay()+6)%7; x.setDate(x.getDate()-dow); return x; }
    
    for (var i=startRow;i<all.length;i++){
      var ts=_parseTs(all[i][idx.ts]); if(!ts) continue;
      var email=String(all[i][idx.email]||'').toLowerCase().trim();
      var page=String(all[i][idx.page]||'').trim();
      var origenRaw=String(all[i][idx.origen]||'').toLowerCase().trim();
      var isMail = origenRaw.indexOf('mail') !== -1 || origenRaw === 'diario' || origenRaw === 'semanal';
      
      bump(dayMap,   Utilities.formatDate(ts,tz,'yyyy-MM-dd'),       email, origenRaw, page);
      bump(weekMap,  Utilities.formatDate(mondayOf(ts),tz,'yyyy-MM-dd'), email, origenRaw, page);
      bump(monthMap, Utilities.formatDate(ts,tz,'yyyy-MM'),          email, origenRaw, page);
      
      totViews++; 
      if(email) totUsers[email]=1; 
      if(isMail) totMail++; else totDir++;
      
      var ukey=email||'(anónimo)';
      if(!userMap[ukey]) userMap[ukey]={email:ukey,views:0,last:ts.getTime()};
      userMap[ukey].views++; 
      if(ts.getTime()>userMap[ukey].last) userMap[ukey].last=ts.getTime();
      
      if(page){ pageMap[page]=(pageMap[page]||0)+1; }
    }
    
    function toArr(map){
      return Object.keys(map).sort().reverse().map(function(k){
        var o=map[k];
        var cells=Object.keys(o.cells).map(function(ck){ return o.cells[ck]; });
        return { period:o.period, cells:cells };
      });
    }
    
    var users=Object.keys(userMap).map(function(k){ var u=userMap[k]; return {email:u.email, views:u.views, last:Utilities.formatDate(new Date(u.last),tz,'yyyy-MM-dd HH:mm')}; }).sort(function(a,b){ return b.views-a.views; });
    var pagesArr=Object.keys(pageMap).map(function(k){ return {page:k, views:pageMap[k]}; }).sort(function(a,b){ return b.views-a.views; });
    
    return {
      byPeriod: { day:toArr(dayMap), week:toArr(weekMap), month:toArr(monthMap) },
      users: users, pages: pagesArr,
      totals: { views:totViews, users:Object.keys(totUsers).length, mail:totMail, directo:totDir },
      asOf: nowStr
    };
  } catch (e) { return { error: e.message }; }
}

function debugAnalytics() {
  var out = [];
  function log(s){ out.push(s); Logger.log(s); }
  try {
    var ss = _openSpreadsheet(REPORT_SHEET_ID);
    if (!ss) ss = SpreadsheetApp.getActiveSpreadsheet();
    log('Spreadsheet: "' + ss.getName() + '"  ->  ' + ss.getUrl());
    var sheets = ss.getSheets();
    log('Pestañas (' + sheets.length + '):');
    sheets.forEach(function(s){
      log('  - "' + s.getName() + '"  gid=' + s.getSheetId() + '  filas=' + s.getLastRow() + '  cols=' + s.getLastColumn());
    });
    var sh = _analyticsSheet();
    log('>> Pestaña que usa el código: "' + sh.getName() + '"  gid=' + sh.getSheetId() + '  filas=' + sh.getLastRow());
    var last = sh.getLastRow(), w = Math.max(4, sh.getLastColumn());
    if (last >= 1) {
      log('Fila 1 (encabezado?): ' + JSON.stringify(sh.getRange(1, 1, 1, w).getValues()[0]));
      var n = Math.min(3, last - 1);
      if (n > 0) {
        sh.getRange(2, 1, n, w).getValues().forEach(function(r, i){
          log('Fila ' + (i + 2) + ': ' + JSON.stringify(r) + '  | col0 Date? ' + (r[0] instanceof Date) + '  parseTs=' + _parseTs(r[0]));
        });
      }
    }
    var res = fetchAnalytics();
    if (res.error) log('fetchAnalytics ERROR: ' + res.error);
    else log('fetchAnalytics OK -> totals=' + JSON.stringify(res.totals) + '  usuarios=' + res.users.length + '  páginas=' + res.pages.length);
  } catch (e) {
    log('ERROR: ' + e.message);
  }
  return out.join('\n');
}
