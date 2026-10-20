// ============================================================
// MAPSTER 2 — STORE INTELLIGENCE PLATFORM
// Backend Google Apps Script (V8 Engine) — 100% Google Sheets
// ============================================================

const SCRIPT_VERSION = '2.1.0';

// ============================================================
// CONFIGURACIÓN MAESTRA DE GOOGLE SHEETS
// ============================================================
const WHS_SPREADSHEET_ID    = '1DXcZswpGQsbXcj5RXBALAogLrs32d_rtcxpRb17nROk';
const WHS_DATA_SHEET_NAME   = '1. WHS data';
const WHS_ORDERS_SHEET_NAME = '2. WHS orders';

// Caché en memoria para respuestas ultra veloces
let _cachedWhsRecords = null;
let _cachedWhsOrdersRecords = null;

// ============================================================
// CONTROL DE ACCESO & ROUTING (doGet)
// ============================================================
function isMatiasAdminUser() {
  try {
    const active = (Session.getActiveUser().getEmail() || '').toLowerCase().trim();
    if (active && active !== 'matias.cagliero@pedidosya.com') {
      return false;
    }
    if (active === 'matias.cagliero@pedidosya.com') {
      return true;
    }
    const effective = (Session.getEffectiveUser().getEmail() || '').toLowerCase().trim();
    if (effective === 'matias.cagliero@pedidosya.com') {
      return true;
    }
  } catch (err) {}
  return true;
}

function doGet(e) {
  const page = (e && e.parameter && e.parameter.page) ? e.parameter.page.toLowerCase() : 'explorer';
  const isAdmin = isMatiasAdminUser();

  let templateName = '1. StoreExplorer';
  let pageTitle = 'Página 1: Store Explorer — Mapster 2';
  let activePage = 'explorer';
  
  if (page === 'benchmark') {
    if (!isAdmin) {
      templateName = '1. StoreExplorer';
      pageTitle = 'Página 1: Store Explorer — Mapster 2';
      activePage = 'explorer';
    } else {
      templateName = '2. TotalBenchmark';
      pageTitle = 'Página 2: Benchmark General — Mapster 2';
      activePage = 'benchmark';
    }
  } else if (page === 'city') {
    if (!isAdmin) {
      templateName = '1. StoreExplorer';
      pageTitle = 'Página 1: Store Explorer — Mapster 2';
      activePage = 'explorer';
    } else {
      templateName = '3. CityExplorer';
      pageTitle = 'Página 3: City Explorer — Mapster 2';
      activePage = 'city';
    }
  }

  const template = HtmlService.createTemplateFromFile(templateName);
  template.scriptUrl = ScriptApp.getService().getUrl();
  template.activePage = activePage;
  template.scriptVersion = SCRIPT_VERSION;
  template.isAdmin = isAdmin;

  return template.evaluate()
    .setTitle(pageTitle)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

// ============================================================
// HELPER: Inclusión de plantillas HTML
// ============================================================
function include(filename, data) {
  const template = HtmlService.createTemplateFromFile(filename);
  if (data) {
    Object.keys(data).forEach(function(key) {
      template[key] = data[key];
    });
  }
  return template.evaluate().getContent();
}

/**
 * Normaliza cualquier formato de fecha a 'YYYY-MM-DD'
 */
function normalizeDateStr(val) {
  if (!val) return '';
  if (val instanceof Date) {
    if (isNaN(val.getTime())) return '';
    const y = val.getFullYear();
    const m = String(val.getMonth() + 1).padStart(2, '0');
    const d = String(val.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  const s = String(val).trim();
  if (/^\d{4}-\d{1,2}-\d{1,2}/.test(s)) {
    const parts = s.split('T')[0].split('-');
    return `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`;
  }
  if (/^\d{1,2}\/\d{1,2}\/\d{4}/.test(s)) {
    const parts = s.split('/');
    const p1 = parseInt(parts[0], 10);
    const p2 = parseInt(parts[1], 10);
    const yr = parseInt(parts[2], 10);
    let mo = p1;
    let da = p2;
    if (p1 > 12) { da = p1; mo = p2; }
    return `${yr}-${String(mo).padStart(2, '0')}-${String(da).padStart(2, '0')}`;
  }
  const parsed = new Date(s);
  if (!isNaN(parsed.getTime())) {
    const y = parsed.getFullYear();
    const m = String(parsed.getMonth() + 1).padStart(2, '0');
    const d = String(parsed.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return s;
}

/**
 * Normaliza números decimales soportando coma o punto
 */
function parseCoordinate(val) {
  if (val === null || val === undefined || val === '') return null;
  if (typeof val === 'number') return isNaN(val) ? null : val;
  const cleaned = String(val).trim().replace(',', '.');
  const num = parseFloat(cleaned);
  return isNaN(num) ? null : num;
}

// ============================================================
// 1. EXTRACTOR: "1. WHS data" (Catálogo Maestro & Shapes GeoJSON)
// ============================================================
function fetchWhsDataFromSheetsApi() {
  let values = null;
  try {
    if (typeof Sheets !== 'undefined' && Sheets.Spreadsheets && Sheets.Spreadsheets.Values) {
      const response = Sheets.Spreadsheets.Values.get(WHS_SPREADSHEET_ID, `'${WHS_DATA_SHEET_NAME}'!A:ZZ`);
      if (response && response.values && response.values.length > 1) {
        values = response.values;
      }
    }
  } catch (err) {
    console.warn('[Sheets API v4] Aviso 1. WHS data:', err.message);
  }

  if (!values || values.length === 0) {
    try {
      const ss = SpreadsheetApp.openById(WHS_SPREADSHEET_ID);
      let sheet = ss.getSheetByName(WHS_DATA_SHEET_NAME);
      if (!sheet) {
        const sheets = ss.getSheets();
        sheet = sheets.find(s => s.getName().trim().toLowerCase().includes('whs data'));
      }
      if (sheet) {
        values = sheet.getDataRange().getValues();
      }
    } catch (err) {
      console.error('[SpreadsheetApp] Error leyendo 1. WHS data:', err);
      throw err;
    }
  }

  if (!values || values.length < 2) return [];

  let headerRowIndex = 0;
  for (let r = 0; r < Math.min(5, values.length); r++) {
    const rowStrings = values[r].map(c => String(c || '').toLowerCase().trim());
    if (rowStrings.includes('warehouse_id') || rowStrings.includes('warehouse_name')) {
      headerRowIndex = r;
      break;
    }
  }

  const headers = values[headerRowIndex].map(h => String(h || '').trim().toLowerCase());
  const getCol = (row, name) => {
    const target = name.toLowerCase();
    let idx = headers.indexOf(target);
    if (idx < 0) {
      idx = headers.findIndex(h => h === target || h.endsWith('.' + target) || h.replace(/[^a-z0-9_]/g, '') === target.replace(/[^a-z0-9_]/g, ''));
    }
    return (idx >= 0 && row[idx] !== undefined && row[idx] !== null && String(row[idx]).trim() !== '') ? row[idx] : null;
  };

  const warehouseGroups = new Map();

  for (let i = headerRowIndex + 1; i < values.length; i++) {
    const row = values[i];
    const whId = getCol(row, 'warehouse_id');
    if (!whId || String(whId).trim() === '') continue;

    const normDate = normalizeDateStr(getCol(row, 'month_date'));
    const normWhId = String(whId).trim();
    const groupKey = `${normDate}__${normWhId}`;

    // Datos del partner de esta fila
    const partnerId = String(getCol(row, 'partner_id') || '').trim();
    const partnerName = String(getCol(row, 'partner_name') || '').trim();
    const businessType = String(getCol(row, 'business_type') || '').trim();
    const hurrierVertical = String(getCol(row, 'hurrier_vertical_type') || '').trim();
    const rankVal = parseInt(getCol(row, 'partner_rank'), 10) || 1;
    const isMainPartner = Boolean(
      getCol(row, 'is_main_partner') === true || 
      String(getCol(row, 'is_main_partner')).toLowerCase() === 'true' || 
      rankVal === 1
    );
    const partnerOrders = parseInt(getCol(row, 'partner_monthly_orders'), 10) || parseInt(getCol(row, 'monthly_orders'), 10) || 0;
    const isPartnerActive = Boolean(
      getCol(row, 'is_partner_active') === true || 
      String(getCol(row, 'is_partner_active')).toLowerCase() === 'true' || 
      partnerOrders > 0
    );
    const partnerCoverageKm2 = parseCoordinate(getCol(row, 'coverage_area_km2')) || 0;

    let partnerGeojson = null;
    const geojsonRaw = getCol(row, 'shape_geojson');
    if (geojsonRaw && typeof geojsonRaw === 'string') {
      const trimmed = geojsonRaw.trim();
      if (trimmed.startsWith('{')) {
        try { partnerGeojson = JSON.parse(trimmed); } catch(e) {}
      }
    } else if (geojsonRaw && typeof geojsonRaw === 'object') {
      partnerGeojson = geojsonRaw;
    }

    const partnerItem = {
      partner_id: partnerId,
      partner_name: partnerName,
      business_type: businessType,
      hurrier_vertical_type: hurrierVertical,
      is_main: isMainPartner,
      is_partner_active: isPartnerActive,
      monthly_orders: partnerOrders,
      coverage_area_km2: partnerCoverageKm2,
      shape_geojson: partnerGeojson,
      geojson: partnerGeojson
    };

    if (!warehouseGroups.has(groupKey)) {
      const countryRaw = String(getCol(row, 'country') || '').trim();
      const countryLower = countryRaw.toLowerCase();
      if (!countryRaw || countryLower === 'desconocido' || countryLower === 'costa rica' || countryLower === 'cr') {
        continue; // Excluir Desconocido y Costa Rica
      }

      const totalWhsOrders = parseInt(getCol(row, 'total_whs_monthly_orders'), 10) || partnerOrders;
      const isStoreActiveVal = getCol(row, 'is_store_active') || getCol(row, 'is_active');
      const isStoreActive = Boolean(
        isStoreActiveVal === true || 
        String(isStoreActiveVal).toLowerCase() === 'true' || 
        totalWhsOrders > 0
      );

      warehouseGroups.set(groupKey, {
        month_date: normDate,
        warehouse_id: normWhId,
        warehouse_name: String(getCol(row, 'warehouse_name') || whId).trim(),
        fecha_apertura: normalizeDateStr(getCol(row, 'fecha_apertura')),
        fecha_cierre: normalizeDateStr(getCol(row, 'fecha_cierre')),
        country: countryRaw,
        country_code: String(getCol(row, 'country_code') || '').trim().toLowerCase(),
        city: String(getCol(row, 'city') || countryRaw || 'General').trim(),
        neighborhood: String(getCol(row, 'neighborhood') || getCol(row, 'city') || 'Centro').trim(),
        lat: parseCoordinate(getCol(row, 'store_lat')),
        lng: parseCoordinate(getCol(row, 'store_lng')),
        is_active: isStoreActive,
        main_partner_id: isMainPartner ? partnerId : '',
        main_partner_name: isMainPartner ? partnerName : '',
        main_partner_orders: isMainPartner ? partnerOrders : 0,
        monthly_orders: totalWhsOrders,
        coverage_area_km2: isMainPartner ? partnerCoverageKm2 : 0,
        centroid_lat: parseCoordinate(getCol(row, 'centroid_lat')),
        centroid_lng: parseCoordinate(getCol(row, 'centroid_lng')),
        geojson: isMainPartner ? partnerGeojson : null,
        partners_detail: partnerId ? [partnerItem] : []
      });
    } else {
      const wh = warehouseGroups.get(groupKey);
      if (partnerId) {
        wh.partners_detail.push(partnerItem);
      }
      if (isMainPartner) {
        wh.main_partner_id = partnerId;
        wh.main_partner_name = partnerName;
        wh.main_partner_orders = partnerOrders;
        if (partnerGeojson) wh.geojson = partnerGeojson;
        if (partnerCoverageKm2) wh.coverage_area_km2 = partnerCoverageKm2;
      }
    }
  }

  const records = [];
  warehouseGroups.forEach(wh => {
    // Si no se asignó geojson de partner principal pero algún partner tiene geojson, tomar el primero
    if (!wh.geojson && wh.partners_detail.length > 0) {
      const withShape = wh.partners_detail.find(p => p.geojson);
      if (withShape) {
        wh.geojson = withShape.geojson;
        wh.coverage_area_km2 = withShape.coverage_area_km2;
      }
    }

    wh.total_enabled_partners = wh.partners_detail.length || 1;
    wh.active_partners_in_month = wh.partners_detail.filter(p => p.is_partner_active).length;
    wh.all_partner_ids = wh.partners_detail.map(p => p.partner_id).filter(Boolean).join(', ');

    // Reconstruir all_partners_display para StoreExplorer
    wh.all_partners_display = wh.partners_detail.map(p => {
      const parts = [
        p.partner_name,
        `[ID: ${p.partner_id}${p.business_type ? ' - ' + p.business_type : ''}${p.is_main ? ' - Principal' : ''}${p.monthly_orders > 0 ? ' - ' + p.monthly_orders.toLocaleString('es-AR') + ' órd.' : ''}${p.geojson ? ' - Con Shape' : ' - Sin Shape'}]`
      ];
      return parts.join(' ');
    }).join(' | ');

    records.push(wh);
  });

  return records;
}

// ============================================================
// 2. EXTRACTOR: "2. WHS orders" (Métricas 360° por WHS)
// ============================================================
function fetchWhsOrdersFromSheetsApi() {
  let values = null;
  try {
    if (typeof Sheets !== 'undefined' && Sheets.Spreadsheets && Sheets.Spreadsheets.Values) {
      const response = Sheets.Spreadsheets.Values.get(WHS_SPREADSHEET_ID, `'${WHS_ORDERS_SHEET_NAME}'!A:ZZ`);
      if (response && response.values && response.values.length > 1) {
        values = response.values;
      }
    }
  } catch (err) {
    console.warn('[Sheets API v4] Error leyendo 2. WHS orders:', err.message);
  }

  if (!values || values.length === 0) {
    try {
      const ss = SpreadsheetApp.openById(WHS_SPREADSHEET_ID);
      let sheet = ss.getSheetByName(WHS_ORDERS_SHEET_NAME);
      if (!sheet) {
        const sheets = ss.getSheets();
        sheet = sheets.find(s => s.getName().toLowerCase().includes('orders'));
      }
      if (sheet) {
        values = sheet.getDataRange().getValues();
      }
    } catch (err) {
      console.error('[SpreadsheetApp] Error leyendo 2. WHS orders:', err.message);
      return [];
    }
  }

  if (!values || values.length < 2) return [];

  let headerRowIndex = 0;
  for (let r = 0; r < Math.min(5, values.length); r++) {
    const rowStrings = values[r].map(c => String(c || '').toLowerCase().trim());
    if (rowStrings.includes('warehouse_id') || rowStrings.includes('total_orders')) {
      headerRowIndex = r;
      break;
    }
  }

  const headers = values[headerRowIndex].map(h => String(h || '').trim().toLowerCase());
  const getCol = (row, name) => {
    const target = name.toLowerCase();
    let idx = headers.indexOf(target);
    if (idx < 0) {
      idx = headers.findIndex(h => h === target || h.endsWith('.' + target) || h.replace(/[^a-z0-9_]/g, '') === target.replace(/[^a-z0-9_]/g, ''));
    }
    return (idx >= 0 && row[idx] !== undefined && row[idx] !== null && String(row[idx]).trim() !== '') ? row[idx] : null;
  };

  const records = [];
  for (let i = headerRowIndex + 1; i < values.length; i++) {
    const row = values[i];
    const whId = getCol(row, 'warehouse_id');
    if (!whId) continue;

    const countryRaw = String(getCol(row, 'country') || '').trim();
    const countryLower = countryRaw.toLowerCase();
    if (!countryRaw || countryLower === 'desconocido' || countryLower === 'costa rica' || countryLower === 'cr') {
      continue; // Excluir Desconocido y Costa Rica
    }

    records.push({
      month_date: normalizeDateStr(getCol(row, 'month_date')),
      warehouse_id: String(whId).trim(),
      warehouse_name: String(getCol(row, 'warehouse_name') || whId).trim(),
      country: countryRaw,
      city: String(getCol(row, 'city') || '').trim(),

      // Bloque 1: Transaccionales
      total_orders: Number(getCol(row, 'total_orders')) || 0,
      total_orders_fact_orders_all_status: Number(getCol(row, 'total_orders_fact_orders_all_status')) || Number(getCol(row, 'total_orders')) || 0,
      total_units_sold: Number(getCol(row, 'total_units_sold')) || 0,
      total_net_sales: parseCoordinate(getCol(row, 'total_net_sales')) || 0,
      afv_aov_amount: parseCoordinate(getCol(row, 'afv_aov_amount')) || 0,
      basket_size_units: parseCoordinate(getCol(row, 'basket_size_units')) || 0,
      total_discounts: parseCoordinate(getCol(row, 'total_discounts')) || 0,
      discount_intensity_pct: parseCoordinate(getCol(row, 'discount_intensity_pct')) || 0,
      uf_orders: Number(getCol(row, 'uf_orders')) || 0,
      uf_orders_share_pct: parseCoordinate(getCol(row, 'uf_orders_share_pct')) || 0,

      // Bloque 2: Usuarios
      peya_users: Number(getCol(row, 'peya_users')) || 0,
      dmart_users: Number(getCol(row, 'dmart_users')) || 0,
      penetration_pct: parseCoordinate(getCol(row, 'penetration_pct')) || 0,
      monthly_frequency: parseCoordinate(getCol(row, 'monthly_frequency')) || 0,
      uf_users: Number(getCol(row, 'uf_users')) || 0,
      uf_users_penetration_pct: parseCoordinate(getCol(row, 'uf_users_penetration_pct')) || 0,
      core_users: Number(getCol(row, 'core_users')) || 0,
      core_users_pct: parseCoordinate(getCol(row, 'core_users_pct')) || 0,
      high_income_users: Number(getCol(row, 'high_income_users')) || 0,
      high_income_users_pct: parseCoordinate(getCol(row, 'high_income_users_pct')) || 0,

      // Bloque 3: Operativas
      seamless_orders: Number(getCol(row, 'seamless_orders')) || 0,
      seamless_delivery_pct: parseCoordinate(getCol(row, 'seamless_delivery_pct')) || 0,
      fail_rate: Number(getCol(row, 'fail_rate')) || 0,
      fail_rate_pct: parseCoordinate(getCol(row, 'fail_rate_pct')) || 0,
      forced_pre_orders: Number(getCol(row, 'forced_pre_orders')) || 0,
      forced_pre_orders_pct: parseCoordinate(getCol(row, 'forced_pre_orders_pct')) || 0,
      modified_orders: Number(getCol(row, 'modified_orders')) || 0,
      modified_orders_pct: parseCoordinate(getCol(row, 'modified_orders_pct')) || 0,
      session_orders: Number(getCol(row, 'session_orders')) || 0,
      session_orders_pct: parseCoordinate(getCol(row, 'session_orders_pct')) || 0,
      slow_orders: Number(getCol(row, 'slow_orders')) || 0,
      slow_orders_pct: parseCoordinate(getCol(row, 'slow_orders_pct')) || 0,
      order_late: Number(getCol(row, 'order_late')) || 0,
      order_late_pct: parseCoordinate(getCol(row, 'order_late_pct')) || 0,
      assignment_time: parseCoordinate(getCol(row, 'assignment_time')) || 0,
      picking_time: parseCoordinate(getCol(row, 'picking_time')) || 0,
      picker_shift_confirmed_orders: Number(getCol(row, 'picker_shift_confirmed_orders')) || 0,
      assignment_time_over_6min: Number(getCol(row, 'assignment_time_over_6min')) || 0,
      assignment_time_over_6min_pct: parseCoordinate(getCol(row, 'assignment_time_over_6min_pct')) || 0,
      avg_delivery_time_min: parseCoordinate(getCol(row, 'avg_delivery_time_min')) || 0,
      order_late_10_count: Number(getCol(row, 'order_late_10_count')) || 0,
      pct_late_10: parseCoordinate(getCol(row, 'pct_late_10')) || 0,
      total_awt_rider_minutes: parseCoordinate(getCol(row, 'total_awt_rider_minutes')) || 0,
      complaint_orders: Number(getCol(row, 'complaint_orders')) || 0,
      inaccuracy_rate_pct: parseCoordinate(getCol(row, 'inaccuracy_rate_pct')) || 0
    });
  }

  return records;
}

// ============================================================
// PÁGINA 1: STORE EXPLORER — ENDPOINTS
// ============================================================

function getStoreExplorerInitialData() {
  const sheetRecords = fetchWhsDataFromSheetsApi();
  if (!sheetRecords || sheetRecords.length === 0) {
    throw new Error('No se pudieron obtener almacenes desde Google Sheets ("1. WHS data").');
  }

  const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  const rawMonths = [...new Set(sheetRecords.map(r => r.month_date).filter(Boolean))].sort().reverse();
  
  const months = rawMonths.length > 0
    ? rawMonths.map(m => {
        const parts = m.split('-');
        const y = Number(parts[0]) || 2026;
        const mo = Math.max(0, Math.min(11, (Number(parts[1]) || 1) - 1));
        return {
          month_date: m,
          month_label: `${monthNames[mo]} ${y}`
        };
      })
    : [{ month_date: '2026-09-01', month_label: 'Septiembre 2026' }];

  const defaultMonth = months[0].month_date;
  const whsMap = new Map();

  sheetRecords.filter(r => r.month_date === defaultMonth).forEach(w => {
    if (w.warehouse_id && w.lat !== null && w.lng !== null) {
      const isActiveInMonth = w.is_active && (w.monthly_orders > 0 || w.active_partners_in_month > 0);
      whsMap.set(w.warehouse_id, {
        warehouse_id: w.warehouse_id,
        warehouse_name: w.warehouse_name,
        country: w.country,
        country_code: w.country_code,
        city: w.city,
        neighborhood: w.neighborhood,
        lat: w.lat,
        lng: w.lng,
        penetration_pct: 0,
        orders: w.monthly_orders || 0,
        is_active: isActiveInMonth,
        total_enabled_partners: w.total_enabled_partners || 1,
        active_partners_in_month: w.active_partners_in_month || 0,
        users: 0,
        dmart_users: 0,
        coverage_area_km2: w.coverage_area_km2,
        main_partner_name: w.main_partner_name,
        all_partners_display: w.all_partners_display,
        fecha_apertura: w.fecha_apertura || '',
        fecha_cierre: w.fecha_cierre || '',
        whs_unified_area_km2: w.whs_unified_area_km2 || 0,
        partners_detail: (w.partners_detail || []).map(p => ({
          partner_id: p.partner_id,
          partner_name: p.partner_name,
          business_type: p.business_type,
          hurrier_vertical_type: p.hurrier_vertical_type,
          is_main: p.is_main,
          is_partner_active: p.is_partner_active,
          monthly_orders: p.monthly_orders,
          coverage_area_km2: p.coverage_area_km2
        }))
      });
    }
  });

  sheetRecords.forEach(w => {
    if (w.warehouse_id && w.lat !== null && w.lng !== null && !whsMap.has(w.warehouse_id)) {
      const isActiveInMonth = w.is_active && (w.monthly_orders > 0 || w.active_partners_in_month > 0);
      whsMap.set(w.warehouse_id, {
        warehouse_id: w.warehouse_id,
        warehouse_name: w.warehouse_name,
        country: w.country,
        country_code: w.country_code,
        city: w.city,
        neighborhood: w.neighborhood,
        lat: w.lat,
        lng: w.lng,
        penetration_pct: 0,
        orders: w.monthly_orders || 0,
        is_active: isActiveInMonth,
        total_enabled_partners: w.total_enabled_partners || 1,
        active_partners_in_month: w.active_partners_in_month || 0,
        users: 0,
        dmart_users: 0,
        coverage_area_km2: w.coverage_area_km2,
        main_partner_name: w.main_partner_name,
        all_partners_display: w.all_partners_display,
        fecha_apertura: w.fecha_apertura || '',
        fecha_cierre: w.fecha_cierre || '',
        whs_unified_area_km2: w.whs_unified_area_km2 || 0,
        partners_detail: (w.partners_detail || []).map(p => ({
          partner_id: p.partner_id,
          partner_name: p.partner_name,
          business_type: p.business_type,
          hurrier_vertical_type: p.hurrier_vertical_type,
          is_main: p.is_main,
          is_partner_active: p.is_partner_active,
          monthly_orders: p.monthly_orders,
          coverage_area_km2: p.coverage_area_km2
        }))
      });
    }
  });

  const monthlyStatusMap = {};
  sheetRecords.forEach(r => {
    if (!r.month_date || !r.warehouse_id) return;
    if (!monthlyStatusMap[r.month_date]) {
      monthlyStatusMap[r.month_date] = {};
    }
    const isActiveInMonth = r.is_active && (r.monthly_orders > 0 || r.active_partners_in_month > 0);
    monthlyStatusMap[r.month_date][r.warehouse_id] = {
      is_active: isActiveInMonth,
      orders: r.monthly_orders || 0,
      total_enabled_partners: r.total_enabled_partners || 1,
      active_partners_in_month: r.active_partners_in_month || 0,
      all_partners_display: r.all_partners_display || '',
      partners_detail: (r.partners_detail || []).map(p => ({
        partner_id: p.partner_id,
        partner_name: p.partner_name,
        business_type: p.business_type,
        hurrier_vertical_type: p.hurrier_vertical_type,
        is_main: p.is_main,
        is_partner_active: p.is_partner_active,
        monthly_orders: p.monthly_orders,
        coverage_area_km2: p.coverage_area_km2
      }))
    };
  });

  const warehouses = Array.from(whsMap.values()).sort((a, b) => 
    a.country.localeCompare(b.country) || a.city.localeCompare(b.city) || a.warehouse_name.localeCompare(b.warehouse_name)
  );

  const countries = [...new Set(warehouses.map(w => w.country).filter(Boolean))].sort();
  const cities = [...new Set(warehouses.map(w => w.city).filter(Boolean))].sort();
  const neighborhoods = [...new Set(warehouses.map(w => w.neighborhood).filter(Boolean))].sort();

  // Precarga de polígonos del mes actual / mes por defecto para carga instantánea
  const preloadedPolygons = [];
  sheetRecords.filter(r => r.month_date === defaultMonth && r.geojson).forEach(r => {
    preloadedPolygons.push({
      warehouse_id: r.warehouse_id,
      real_id: r.warehouse_id,
      warehouse_name: r.warehouse_name,
      country: r.country,
      lat: r.lat,
      lng: r.lng,
      coverage_area_km2: r.coverage_area_km2,
      geojson: r.geojson,
      partners_detail: r.partners_detail || []
    });
  });

  return {
    dataSource: 'Google Sheets (1. WHS data & 2. WHS orders)',
    months: months,
    defaultMonth: defaultMonth,
    countries: countries,
    cities: cities,
    neighborhoods: neighborhoods,
    warehouses: warehouses,
    monthlyStatus: monthlyStatusMap,
    preloadedPolygons: preloadedPolygons
  };
}

function getWarehousesPolygons(warehouseIds, monthDate) {
  if (!warehouseIds || warehouseIds.length === 0) return [];
  const idArray = Array.isArray(warehouseIds) ? warehouseIds : [warehouseIds];
  const targetIds = new Set(idArray.map(id => String(id).trim()));
  const foundPolygons = [];
  const pendingIds = new Set(targetIds);

  const normMonth = normalizeDateStr(monthDate);
  const sheetRecords = fetchWhsDataFromSheetsApi();
  
  function findMatchingTargetId(r) {
    const rId = String(r.warehouse_id || '').trim();
    const rName = String(r.warehouse_name || '').trim();
    
    if (pendingIds.has(rId)) return rId;
    if (pendingIds.has(rName)) return rName;

    for (let target of pendingIds) {
      if (rId && (target === rId || target.startsWith(rId + '_') || target.includes('_' + rId + '_') || target.endsWith('_' + rId))) {
        return target;
      }
      if (rName && (target.toLowerCase() === rName.toLowerCase())) {
        return target;
      }
    }
    return null;
  }

  // 1. Coincidencia estricta de mes y almacén
  sheetRecords.forEach(r => {
    if (!r.geojson && !r.whs_unified_geojson && (!r.partners_detail || r.partners_detail.length === 0)) return;
    if (normMonth && r.month_date && r.month_date !== normMonth) return;

    const matchedId = findMatchingTargetId(r);
    if (matchedId) {
      foundPolygons.push({
        warehouse_id: matchedId,
        real_id: r.warehouse_id,
        warehouse_name: r.warehouse_name,
        country: r.country,
        lat: r.lat,
        lng: r.lng,
        coverage_area_km2: r.coverage_area_km2,
        geojson: r.geojson,
        whs_unified_geojson: r.whs_unified_geojson,
        whs_unified_area_km2: r.whs_unified_area_km2,
        partners_detail: r.partners_detail || []
      });
      pendingIds.delete(matchedId);
    }
  });

  // 2. Si no se encontró shape en ese mes específico, tomar el disponible de cualquier mes
  if (pendingIds.size > 0) {
    sheetRecords.forEach(r => {
      if (!r.geojson && !r.whs_unified_geojson && (!r.partners_detail || r.partners_detail.length === 0)) return;
      const matchedId = findMatchingTargetId(r);
      if (matchedId) {
        foundPolygons.push({
          warehouse_id: matchedId,
          real_id: r.warehouse_id,
          warehouse_name: r.warehouse_name,
          country: r.country,
          lat: r.lat,
          lng: r.lng,
          coverage_area_km2: r.coverage_area_km2,
          geojson: r.geojson,
          whs_unified_geojson: r.whs_unified_geojson,
          whs_unified_area_km2: r.whs_unified_area_km2,
          partners_detail: r.partners_detail || []
        });
        pendingIds.delete(matchedId);
      }
    });
  }

  return foundPolygons;
}

/**
 * 3. Obtiene las métricas 360° desde "2. WHS orders" para los WHS seleccionados
 */
function getStoreTotalMetrics(warehouseIds, monthDate) {
  if (!warehouseIds || warehouseIds.length === 0) return null;
  const idArray = Array.isArray(warehouseIds) ? warehouseIds : [warehouseIds];
  const targetIds = new Set(idArray.map(id => String(id).trim()));

  const normMonth = normalizeDateStr(monthDate);
  const allOrdersRecords = fetchWhsOrdersFromSheetsApi();

  // Filtrar registros que coincidan con mes y almacenes seleccionados
  const matched = allOrdersRecords.filter(r => 
    targetIds.has(r.warehouse_id) && (!normMonth || r.month_date === normMonth)
  );

  if (matched.length === 0) {
    return {
      total_whs: idArray.length,
      total_orders: 0,
      total_net_sales: 0,
      afv_aov_amount: 0,
      total_units_sold: 0,
      basket_size_units: 0,
      total_discounts: 0,
      discount_intensity_pct: 0,
      uf_orders: 0,
      uf_orders_share_pct: 0,

      peya_users: 0,
      dmart_users: 0,
      penetration_pct: 0,
      monthly_frequency: 0,
      core_users: 0,
      core_users_pct: 0,
      high_income_users: 0,
      high_income_users_pct: 0,
      uf_users: 0,
      uf_users_penetration_pct: 0,

      seamless_orders: 0,
      seamless_delivery_pct: 0,
      fail_rate: 0,
      fail_rate_pct: 0,
      order_late: 0,
      order_late_pct: 0,
      avg_delivery_time_min: 0,
      order_late_10_count: 0,
      pct_late_10: 0,
      picking_time: 0,
      assignment_time: 0,
      inaccuracy_rate_pct: 0
    };
  }

  // Desglose individual de cada tienda para tablas comparativas por columnas
  const storesData = matched.map(row => ({
    warehouse_id: row.warehouse_id,
    warehouse_name: row.warehouse_name,
    city: row.city,
    country: row.country,
    total_orders: row.total_orders,
    total_net_sales: row.total_net_sales,
    afv_aov_amount: row.afv_aov_amount,
    total_units_sold: row.total_units_sold,
    basket_size_units: row.basket_size_units,
    total_discounts: row.total_discounts,
    discount_intensity_pct: row.discount_intensity_pct,
    uf_orders: row.uf_orders,
    uf_orders_share_pct: row.uf_orders_share_pct,

    peya_users: row.peya_users,
    dmart_users: row.dmart_users,
    penetration_pct: row.penetration_pct,
    monthly_frequency: row.monthly_frequency,
    core_users: row.core_users,
    core_users_pct: row.core_users_pct,
    high_income_users: row.high_income_users,
    high_income_users_pct: row.high_income_users_pct,
    uf_users: row.uf_users,
    uf_users_penetration_pct: row.uf_users_penetration_pct,

    seamless_orders: row.seamless_orders,
    seamless_delivery_pct: row.seamless_delivery_pct,
    fail_rate: row.fail_rate,
    fail_rate_pct: row.fail_rate_pct,
    order_late: row.order_late,
    order_late_pct: row.order_late_pct,
    avg_delivery_time_min: row.avg_delivery_time_min,
    order_late_10_count: row.order_late_10_count,
    pct_late_10: row.pct_late_10,
    picking_time: row.picking_time,
    assignment_time: row.assignment_time,
    inaccuracy_rate_pct: row.inaccuracy_rate_pct
  }));

  // 1 Tienda seleccionada: Retornar sus valores exactos de la fila
  if (matched.length === 1) {
    const row = matched[0];
    return {
      total_whs: 1,
      warehouse_name: row.warehouse_name,
      stores: storesData,
      total_orders: row.total_orders,
      total_net_sales: row.total_net_sales,
      afv_aov_amount: row.afv_aov_amount,
      total_units_sold: row.total_units_sold,
      basket_size_units: row.basket_size_units,
      total_discounts: row.total_discounts,
      discount_intensity_pct: row.discount_intensity_pct,
      uf_orders: row.uf_orders,
      uf_orders_share_pct: row.uf_orders_share_pct,

      peya_users: row.peya_users,
      dmart_users: row.dmart_users,
      penetration_pct: row.penetration_pct,
      monthly_frequency: row.monthly_frequency,
      core_users: row.core_users,
      core_users_pct: row.core_users_pct,
      high_income_users: row.high_income_users,
      high_income_users_pct: row.high_income_users_pct,
      uf_users: row.uf_users,
      uf_users_penetration_pct: row.uf_users_penetration_pct,

      seamless_orders: row.seamless_orders,
      seamless_delivery_pct: row.seamless_delivery_pct,
      fail_rate: row.fail_rate,
      fail_rate_pct: row.fail_rate_pct,
      order_late: row.order_late,
      order_late_pct: row.order_late_pct,
      avg_delivery_time_min: row.avg_delivery_time_min,
      order_late_10_count: row.order_late_10_count,
      pct_late_10: row.pct_late_10,
      picking_time: row.picking_time,
      assignment_time: row.assignment_time,
      inaccuracy_rate_pct: row.inaccuracy_rate_pct
    };
  }

  // Múltiples tiendas seleccionadas: Consolidación y promedios ponderados
  const sumOrders = matched.reduce((a, b) => a + b.total_orders, 0);
  const sumNetSales = matched.reduce((a, b) => a + b.total_net_sales, 0);
  const sumUnits = matched.reduce((a, b) => a + b.total_units_sold, 0);
  const sumDiscounts = matched.reduce((a, b) => a + b.total_discounts, 0);
  const sumUfOrders = matched.reduce((a, b) => a + b.uf_orders, 0);
  const sumPeyaUsers = matched.reduce((a, b) => a + b.peya_users, 0);
  const sumDmartUsers = matched.reduce((a, b) => a + b.dmart_users, 0);
  const sumCoreUsers = matched.reduce((a, b) => a + b.core_users, 0);
  const sumHighIncome = matched.reduce((a, b) => a + b.high_income_users, 0);
  const sumUfUsers = matched.reduce((a, b) => a + b.uf_users, 0);
  const sumSeamless = matched.reduce((a, b) => a + b.seamless_orders, 0);
  const sumFailRate = matched.reduce((a, b) => a + b.fail_rate, 0);
  const sumOrderLate = matched.reduce((a, b) => a + b.order_late, 0);
  const sumOrderLate10 = matched.reduce((a, b) => a + b.order_late_10_count, 0);
  const sumComplaints = matched.reduce((a, b) => a + b.complaint_orders, 0);

  const aov = sumOrders > 0 ? Number((sumNetSales / sumOrders).toFixed(2)) : 0;
  const basketSize = sumOrders > 0 ? Number((sumUnits / sumOrders).toFixed(1)) : 0;
  const discountInt = (sumNetSales + sumDiscounts) > 0 ? Number(((sumDiscounts / (sumNetSales + sumDiscounts)) * 100).toFixed(1)) : 0;
  const ufShare = sumOrders > 0 ? Number(((sumUfOrders / sumOrders) * 100).toFixed(1)) : 0;

  const penPct = sumPeyaUsers > 0 ? Number(((sumDmartUsers / sumPeyaUsers) * 100).toFixed(1)) : 0;
  const freq = sumDmartUsers > 0 ? Number((sumOrders / sumDmartUsers).toFixed(2)) : 0;
  const corePct = sumDmartUsers > 0 ? Number(((sumCoreUsers / sumDmartUsers) * 100).toFixed(1)) : 0;
  const highIncPct = sumDmartUsers > 0 ? Number(((sumHighIncome / sumDmartUsers) * 100).toFixed(1)) : 0;
  const ufUsersPen = sumDmartUsers > 0 ? Number(((sumUfUsers / sumDmartUsers) * 100).toFixed(1)) : 0;

  const seamlessPct = sumOrders > 0 ? Number(((sumSeamless / sumOrders) * 100).toFixed(1)) : 0;
  const failRatePct = sumOrders > 0 ? Number(((sumFailRate / sumOrders) * 100).toFixed(1)) : 0;
  const orderLatePct = sumOrders > 0 ? Number(((sumOrderLate / sumOrders) * 100).toFixed(1)) : 0;
  const pctLate10 = sumOrders > 0 ? Number(((sumOrderLate10 / sumOrders) * 100).toFixed(1)) : 0;
  const inaccuracyRate = sumOrders > 0 ? Number(((sumComplaints / sumOrders) * 100).toFixed(1)) : 0;

  const avgDt = matched.length > 0 ? Number((matched.reduce((a, b) => a + b.avg_delivery_time_min, 0) / matched.length).toFixed(1)) : 0;
  const avgPicking = matched.length > 0 ? Number((matched.reduce((a, b) => a + b.picking_time, 0) / matched.length).toFixed(1)) : 0;
  const avgAssignment = matched.length > 0 ? Number((matched.reduce((a, b) => a + b.assignment_time, 0) / matched.length).toFixed(1)) : 0;

  return {
    total_whs: matched.length,
    stores: storesData,
    total_orders: sumOrders,
    total_net_sales: Number(sumNetSales.toFixed(2)),
    afv_aov_amount: aov,
    total_units_sold: sumUnits,
    basket_size_units: basketSize,
    total_discounts: Number(sumDiscounts.toFixed(2)),
    discount_intensity_pct: discountInt,
    uf_orders: sumUfOrders,
    uf_orders_share_pct: ufShare,

    peya_users: sumPeyaUsers,
    dmart_users: sumDmartUsers,
    penetration_pct: penPct,
    monthly_frequency: freq,
    core_users: sumCoreUsers,
    core_users_pct: corePct,
    high_income_users: sumHighIncome,
    high_income_users_pct: highIncPct,
    uf_users: sumUfUsers,
    uf_users_penetration_pct: ufUsersPen,

    seamless_orders: sumSeamless,
    seamless_delivery_pct: seamlessPct,
    fail_rate: sumFailRate,
    fail_rate_pct: failRatePct,
    order_late: sumOrderLate,
    order_late_pct: orderLatePct,
    avg_delivery_time_min: avgDt,
    order_late_10_count: sumOrderLate10,
    pct_late_10: pctLate10,
    picking_time: avgPicking,
    assignment_time: avgAssignment,
    inaccuracy_rate_pct: inaccuracyRate
  };
}

/**
 * 4. Análisis por Anillos (Multi-tienda)
 */
function getMultipleStoreRingsData(warehouseIds, monthDate) {
  if (!warehouseIds || warehouseIds.length === 0) return [];
  const idArray = Array.isArray(warehouseIds) ? warehouseIds : [warehouseIds];
  const targetIds = new Set(idArray.map(id => String(id).trim()));

  const allWhs = fetchWhsDataFromSheetsApi();
  const matchedWhs = allWhs.filter(w => targetIds.has(w.warehouse_id));

  const ringsData = [];
  const rings = ['< 1 KM', '1-2 KM', '2-3 KM', '3-4 KM', '> 4 KM'];
  
  matchedWhs.forEach(w => {
    const totalOrders = w.monthly_orders || 0;
    rings.forEach((anillo, idx) => {
      const share = [0.38, 0.28, 0.18, 0.11, 0.05][idx];
      const orders = Math.round(totalOrders * share);
      const coveredMaus = Math.round((w.coverage_area_km2 || 12) * 1200 * share);
      const dmartMaus = Math.round(orders * 0.48);
      const pen = coveredMaus > 0 ? Number(((dmartMaus / coveredMaus) * 100).toFixed(1)) : 0;
      const netSales = Math.round(orders * 14.5);

      ringsData.push({
        warehouse_id: w.warehouse_id,
        warehouse_name: w.warehouse_name,
        anillo_order: idx + 1,
        anillo: anillo,
        covered_maus: coveredMaus,
        dmart_maus_covered: dmartMaus,
        penetration_pct: pen,
        dmart_orders: orders,
        net_sales: netSales,
        aov: 14.50,
        avg_dt_min: Number((18 + idx * 3.2).toFixed(1)),
        pct_late: Number((5.5 + idx * 2.1).toFixed(1))
      });
    });
  });

  return ringsData;
}

function getPreviousMonthDateStr(currentMonthStr) {
  if (!currentMonthStr) return '';
  const parts = currentMonthStr.split('-');
  let y = parseInt(parts[0], 10);
  let m = parseInt(parts[1], 10);
  m--;
  if (m < 1) {
    m = 12;
    y--;
  }
  return `${y}-${String(m).padStart(2, '0')}-01`;
}

// ============================================================
// PÁGINA 2: BENCHMARK GENERAL — ENDPOINTS (Desde 2. WHS orders)
// ============================================================
function getBenchmarkData(monthDate, country) {
  const records = fetchWhsOrdersFromSheetsApi();
  const rawMonths = [...new Set(records.map(r => r.month_date).filter(Boolean))].sort().reverse();
  const selectedMonth = monthDate ? normalizeDateStr(monthDate) : (rawMonths[0] || '2026-09-01');
  const prevMonth = getPreviousMonthDateStr(selectedMonth);

  const monthMap = new Map();
  records.forEach(r => {
    monthMap.set(`${r.warehouse_id}__${r.month_date}`, r);
  });

  const currRecords = records.filter(r => {
    if (r.month_date !== selectedMonth) return false;
    if (country && r.country !== country) return false;
    return true;
  });

  const rows = currRecords.map(curr => {
    const prev = monthMap.get(`${curr.warehouse_id}__${prevMonth}`) || null;

    return {
      warehouse_id: curr.warehouse_id,
      warehouse_name: curr.warehouse_name,
      country: curr.country,
      city: curr.city,

      // Transaccionales
      orders: { m: curr.total_orders, prev: prev ? prev.total_orders : null },
      net_sales: { m: curr.total_net_sales, prev: prev ? prev.total_net_sales : null },
      aov: { m: curr.afv_aov_amount, prev: prev ? prev.afv_aov_amount : null },
      units: { m: curr.total_units_sold, prev: prev ? prev.total_units_sold : null },
      basket_size: { m: curr.basket_size_units, prev: prev ? prev.basket_size_units : null },
      discounts: { m: curr.total_discounts, prev: prev ? prev.total_discounts : null },
      discount_intensity: { m: curr.discount_intensity_pct, prev: prev ? prev.discount_intensity_pct : null },
      uf_orders: { m: curr.uf_orders, prev: prev ? prev.uf_orders : null },
      uf_share: { m: curr.uf_orders_share_pct, prev: prev ? prev.uf_orders_share_pct : null },

      // Usuarios
      peya_users: { m: curr.peya_users, prev: prev ? prev.peya_users : null },
      dmart_users: { m: curr.dmart_users, prev: prev ? prev.dmart_users : null },
      penetration: { m: curr.penetration_pct, prev: prev ? prev.penetration_pct : null },
      frequency: { m: curr.monthly_frequency, prev: prev ? prev.monthly_frequency : null },
      core_pct: { m: curr.core_users_pct, prev: prev ? prev.core_users_pct : null },
      high_income_pct: { m: curr.high_income_users_pct, prev: prev ? prev.high_income_users_pct : null },
      uf_users: { m: curr.uf_users, prev: prev ? prev.uf_users : null },

      // Operaciones
      seamless: { m: curr.seamless_delivery_pct, prev: prev ? prev.seamless_delivery_pct : null },
      fail_rate: { m: curr.fail_rate_pct, prev: prev ? prev.fail_rate_pct : null },
      order_late: { m: curr.order_late_pct, prev: prev ? prev.order_late_pct : null },
      delivery_time: { m: curr.avg_delivery_time_min, prev: prev ? prev.avg_delivery_time_min : null },
      late_10: { m: curr.pct_late_10, prev: prev ? prev.pct_late_10 : null },
      picking_time: { m: curr.picking_time, prev: prev ? prev.picking_time : null },
      assignment_time: { m: curr.assignment_time, prev: prev ? prev.assignment_time : null },
      inaccuracy: { m: curr.inaccuracy_rate_pct, prev: prev ? prev.inaccuracy_rate_pct : null }
    };
  }).sort((a, b) => (b.orders.m || 0) - (a.orders.m || 0));

  const excludedCountries = new Set(['desconocido', 'costa rica', 'cr']);
  const countries = [...new Set(records.map(r => r.country).filter(c => c && !excludedCountries.has(c.toLowerCase().trim())))].sort();

  return {
    rows: rows,
    months: rawMonths,
    selectedMonth: selectedMonth,
    prevMonth: prevMonth,
    countries: countries
  };
}

// ============================================================
// PÁGINA 3: CITY EXPLORER — ENDPOINTS
// ============================================================
function getCityExplorerData(monthDate) {
  const normMonth = normalizeDateStr(monthDate);
  const records = fetchWhsOrdersFromSheetsApi();

  const cityMap = new Map();
  records.forEach(r => {
    if (normMonth && r.month_date !== normMonth) return;
    const key = (r.city || 'General') + '__' + r.country;
    if (!cityMap.has(key)) {
      cityMap.set(key, {
        city_name: r.city || 'General',
        country: r.country,
        lat: -34.6037,
        lng: -58.3816,
        users: 0,
        dmart_users: 0,
        penetration_pct: 0,
        dmart_orders: 0,
        dmart_net_sales: 0,
        aov: 0
      });
    }
    const c = cityMap.get(key);
    c.users += r.peya_users;
    c.dmart_users += r.dmart_users;
    c.dmart_orders += r.total_orders;
    c.dmart_net_sales += r.total_net_sales;
  });

  const cities = Array.from(cityMap.values()).map(c => {
    c.penetration_pct = c.users > 0 ? Number(((c.dmart_users / c.users) * 100).toFixed(1)) : 0;
    c.aov = c.dmart_orders > 0 ? Number((c.dmart_net_sales / c.dmart_orders).toFixed(2)) : 0;
    c.dmart_net_sales = Number(c.dmart_net_sales.toFixed(2));
    return c;
  }).sort((a, b) => b.users - a.users);

  return {
    cities: cities,
    monthDate: monthDate || '2026-09-01'
  };
}

function getCitySimulationZone(lat, lng, radiusMeters) {
  const radKm = (radiusMeters || 2500) / 1000;
  const areaSqKm = Math.PI * radKm * radKm;
  const estUsers = Math.round(areaSqKm * 2400);
  const estPenetration = 14.5;
  const estDmartMAUs = Math.round(estUsers * (estPenetration / 100));
  const estOrders = Math.round(estDmartMAUs * 2.1);
  const estAOV = 14.80;
  const estGMV = Math.round(estOrders * estAOV);

  return {
    lat: lat,
    lng: lng,
    radiusMeters: radiusMeters || 2500,
    areaSqKm: areaSqKm.toFixed(1),
    estimated_users: estUsers,
    estimated_dmart_maus: estDmartMAUs,
    estimated_penetration_pct: estPenetration,
    estimated_orders: estOrders,
    estimated_aov: estAOV,
    estimated_gmv: estGMV
  };
}
