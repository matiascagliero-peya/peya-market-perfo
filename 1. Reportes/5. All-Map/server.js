const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8092;
const DIR = __dirname;

// Generador de polígonos GeoJSON rectangulares simples alrededor de cada tienda
function createGeoJsonBox(lat, lng, radiusKm = 1.8) {
  const dLat = radiusKm / 110.574;
  const dLng = radiusKm / (111.320 * Math.cos(lat * Math.PI / 180));
  const coords = [
    [lng - dLng, lat - dLat],
    [lng + dLng, lat - dLat],
    [lng + dLng, lat + dLat],
    [lng - dLng, lat + dLat],
    [lng - dLng, lat - dLat]
  ];
  return {
    type: 'Feature',
    geometry: {
      type: 'Polygon',
      coordinates: [coords]
    },
    properties: {}
  };
}

const MOCK_WAREHOUSES = [
  {
    warehouse_id: 'AR_506_Microcentro_II',
    warehouse_name: 'AR 506 Microcentro II',
    country: 'Argentina',
    country_code: 'AR',
    city: 'Buenos Aires',
    neighborhood: 'Microcentro',
    lat: -34.6037,
    lng: -58.3816,
    orders: 4850,
    peya_users: 28400,
    dmart_users: 2450,
    covered_maus: 21200,
    is_active: true,
    coverage_area_km2: 12.4
  },
  {
    warehouse_id: 'AR_3_Belgrano',
    warehouse_name: 'AR 3 Belgrano',
    country: 'Argentina',
    country_code: 'AR',
    city: 'Buenos Aires',
    neighborhood: 'Belgrano',
    lat: -34.5623,
    lng: -58.4568,
    orders: 6200,
    peya_users: 34100,
    dmart_users: 3120,
    covered_maus: 29800,
    is_active: true,
    coverage_area_km2: 15.8
  },
  {
    warehouse_id: 'AR_511_Palermo_Soho',
    warehouse_name: 'AR 511 Palermo Soho',
    country: 'Argentina',
    country_code: 'AR',
    city: 'Buenos Aires',
    neighborhood: 'Palermo Soho',
    lat: -34.5885,
    lng: -58.4305,
    orders: 5400,
    peya_users: 31000,
    dmart_users: 2890,
    covered_maus: 26500,
    is_active: true,
    coverage_area_km2: 14.2
  },
  {
    warehouse_id: 'AR_512_Caballito_Norte',
    warehouse_name: 'AR 512 Caballito Norte',
    country: 'Argentina',
    country_code: 'AR',
    city: 'Buenos Aires',
    neighborhood: 'Caballito Norte',
    lat: -34.6180,
    lng: -58.4420,
    orders: 4950,
    peya_users: 27500,
    dmart_users: 2350,
    covered_maus: 24100,
    is_active: true,
    coverage_area_km2: 13.5
  },
  {
    warehouse_id: 'AR_515_Recoleta_Pueyrredon',
    warehouse_name: 'AR 515 Recoleta Pueyrredón',
    country: 'Argentina',
    country_code: 'AR',
    city: 'Buenos Aires',
    neighborhood: 'Recoleta',
    lat: -34.5920,
    lng: -58.3970,
    orders: 5800,
    peya_users: 32400,
    dmart_users: 2950,
    covered_maus: 28000,
    is_active: true,
    coverage_area_km2: 14.8
  },
  {
    warehouse_id: 'AR_507_Villa_Crespo',
    warehouse_name: 'AR 507 Villa Crespo',
    country: 'Argentina',
    country_code: 'AR',
    city: 'Buenos Aires',
    neighborhood: 'Villa Crespo',
    lat: -34.5980,
    lng: -58.4410,
    orders: 4100,
    peya_users: 23000,
    dmart_users: 1980,
    covered_maus: 20500,
    is_active: true,
    coverage_area_km2: 11.2
  }
];

const PRELOADED_POLYGONS = MOCK_WAREHOUSES.map(w => ({
  warehouse_id: w.warehouse_id,
  warehouse_name: w.warehouse_name,
  country: w.country,
  lat: w.lat,
  lng: w.lng,
  coverage_area_km2: w.coverage_area_km2,
  geojson: createGeoJsonBox(w.lat, w.lng)
}));

const INITIAL_DATA_PAYLOAD = {
  warehouses: MOCK_WAREHOUSES,
  countries: ['Argentina'],
  cities: ['Buenos Aires'],
  neighborhoods: ['Microcentro', 'Belgrano', 'Palermo Soho', 'Caballito Norte', 'Recoleta', 'Villa Crespo'],
  months: [
    { month_date: '2026-10-01', month_label: 'Octubre 2026' },
    { month_date: '2026-09-01', month_label: 'Septiembre 2026' }
  ],
  defaultMonth: '2026-10-01',
  preloadedPolygons: PRELOADED_POLYGONS,
  monthlyStatus: {}
};

function generateMockKpiMetrics(ids) {
  const storeMetrics = [];
  const targetIds = Array.isArray(ids) ? ids : (ids ? [ids] : []);

  targetIds.forEach((id, idx) => {
    const baseW = MOCK_WAREHOUSES.find(w => w.warehouse_id === id) || {
      warehouse_id: id,
      warehouse_name: id,
      city: 'Buenos Aires',
      country: 'Argentina',
      orders: 4500
    };

    const ord = baseW.orders || 4500;
    const afv = 15.5 + (idx * 1.2);
    const gmv = Math.round(ord * afv);
    const peyaMaus = baseW.peya_users || 28000;
    const dmartMaus = baseW.dmart_users || Math.round(ord * 0.52);

    storeMetrics.push({
      warehouse_id: baseW.warehouse_id,
      warehouse_name: baseW.warehouse_name,
      city: baseW.city,
      country: baseW.country,

      // Bloque 1: Transaccionales
      total_orders: ord,
      total_net_sales: gmv,
      afv_aov_amount: Number(afv.toFixed(2)),
      total_units_sold: Math.round(ord * 4.6),
      basket_size_units: (4.4 + (idx * 0.2)).toFixed(1),
      total_discounts: Math.round(gmv * 0.08),
      discount_intensity_pct: Number((7.8 + (idx * 0.6)).toFixed(1)),
      uf_orders: Math.round(ord * 0.38),
      uf_orders_share_pct: Number((37.5 + (idx * 1.5)).toFixed(1)),

      // Bloque 2: Usuarios & Penetración
      peya_users: peyaMaus,
      covered_maus: Math.round(peyaMaus * 0.82),
      dmart_users: dmartMaus,
      penetration_pct: Number(((dmartMaus / peyaMaus) * 100).toFixed(1)),
      monthly_frequency: Number((1.8 + (idx * 0.15)).toFixed(1)),
      core_users_pct: Number((42.0 + (idx * 1.2)).toFixed(1)),
      high_income_users_pct: Number((31.5 + (idx * 2.1)).toFixed(1)),
      uf_users: Math.round(dmartMaus * 0.44),
      uf_users_penetration_pct: Number((44.0 + (idx * 1.8)).toFixed(1)),

      // Bloque 3: Operaciones & Logística
      seamless_delivery_pct: Number((89.2 - (idx * 1.4)).toFixed(1)),
      fail_rate_pct: Number((1.2 + (idx * 0.2)).toFixed(1)),
      order_late_pct: Number((6.8 + (idx * 1.1)).toFixed(1)),
      pct_late_10: Number((2.1 + (idx * 0.5)).toFixed(1)),
      avg_delivery_time_min: Number((19.5 + (idx * 1.8)).toFixed(1)),
      picking_time: Number((4.8 + (idx * 0.4)).toFixed(1)),
      assignment_time: Number((2.4 + (idx * 0.3)).toFixed(1)),
      inaccuracy_rate_pct: Number((0.6 + (idx * 0.1)).toFixed(1)),
      open_time_pct: Number((99.1 - (idx * 0.3)).toFixed(1)),

      // Bloque 4: Unit Economics
      rider_cpo_dmarts: Number((2.15 + (idx * 0.22)).toFixed(2)),
      cpo_afv_pct: Number((( (2.15 + (idx * 0.22)) / afv ) * 100).toFixed(1))
    });
  });

  return { stores: storeMetrics };
}

function generateMockRings(ids) {
  const ringLabels = ['< 1 KM', '1-2 KM', '2-3 KM', '3-4 KM', '> 4 KM'];
  const res = [];
  const targetIds = Array.isArray(ids) ? ids : [ids];

  targetIds.forEach(id => {
    const w = MOCK_WAREHOUSES.find(item => item.warehouse_id === id) || { warehouse_id: id, warehouse_name: id };
    const totOrders = w.orders || 4500;
    const totMaus = w.peya_users || 28000;

    const shares = [0.38, 0.30, 0.18, 0.10, 0.04];
    ringLabels.forEach((label, idx) => {
      const share = shares[idx];
      const ords = Math.round(totOrders * share);
      const maus = Math.round(totMaus * share);
      const dmartMaus = Math.round(ords * 0.52);
      const dt = (14.5 + idx * 3.2).toFixed(1);

      res.push({
        warehouse_id: w.warehouse_id,
        warehouse_name: w.warehouse_name,
        anillo: label,
        covered_maus: maus,
        dmart_maus_covered: dmartMaus,
        penetration_pct: ((dmartMaus / Math.max(1, maus)) * 100).toFixed(1),
        dmart_orders: ords,
        orders: ords,
        aov: 16.4,
        avg_dt_min: dt,
        avg_dt: dt,
        pct_late: (4.0 + idx * 2.8).toFixed(1),
        frequency: (2.3 - idx * 0.15).toFixed(1),
        rider_cpo_dmarts: (1.20 + (parseFloat(dt) * 0.058)).toFixed(2),
        cpo_afv_pct: (((1.20 + (parseFloat(dt) * 0.058)) / 16.4) * 100).toFixed(1),
        seamless_pct: (94.0 - idx * 3.5).toFixed(1),
        plus_users: Math.round(maus * 0.18)
      });
    });
  });

  return res;
}

const ALL_STORE_METRICS = generateMockKpiMetrics(MOCK_WAREHOUSES.map(w => w.warehouse_id));
const ALL_STORE_RINGS = generateMockRings(MOCK_WAREHOUSES.map(w => w.warehouse_id));

function buildHtml() {
  const htmlPath = path.join(DIR, '1. StoreExplorer.html');
  const stylesPath = path.join(DIR, '1.3 StoreExplorer_styles.html');
  const scriptsPath = path.join(DIR, '1.2 StoreExplorer_scripts.html');
  const navPath = path.join(DIR, '_nav.html');

  let html = fs.readFileSync(htmlPath, 'utf8');
  const styles = fs.existsSync(stylesPath) ? fs.readFileSync(stylesPath, 'utf8') : '';
  const scripts = fs.existsSync(scriptsPath) ? fs.readFileSync(scriptsPath, 'utf8') : '';
  let nav = fs.existsSync(navPath) ? fs.readFileSync(navPath, 'utf8') : '';

  // Evaluar nav
  nav = nav.replace(/<\?=\s*\(typeof scriptUrl[^?]+\?.*:.*""\s*\?>/g, '#');
  nav = nav.replace(/<\?=\s*\(typeof scriptUrl[^?]+\?.*:.*\?page=explorer'\s*\?>/g, '#');
  nav = nav.replace(/<\?=\s*\(typeof scriptUrl[^?]+\?.*:.*\?page=benchmark'\s*\?>/g, '#');
  nav = nav.replace(/<\?=\s*\(typeof scriptUrl[^?]+\?.*:.*\?page=analytics'\s*\?>/g, '#');
  nav = nav.replace(/<\?=\s*activePage\s*===\s*'explorer'\s*\?\s*'active'\s*:\s*''\s*\?>/g, 'active');
  nav = nav.replace(/<\?=\s*activePage\s*===\s*'benchmark'\s*\?\s*'active'\s*:\s*''\s*\?>/g, '');
  nav = nav.replace(/<\?=\s*\(typeof activePage[^?]+\)\s*\?>/g, '');
  nav = nav.replace(/<\?\s*if\s*\([^?]+\)\s*\{\s*\?>/g, '');
  nav = nav.replace(/<\?\s*\}\s*\?>/g, '');

  // IMPORTANTE: Se usa una función de reemplazo () => str para evitar que JavaScript interprete $` o $' como patrones de duplicación
  html = html.replace(/<\?!=\s*include\(['"]1\.3 StoreExplorer_styles['"]\);?\s*\?>/g, () => styles);
  html = html.replace(/<\?!=\s*include\(['"]_nav['"][\s\S]*?\?>/g, () => nav);
  html = html.replace(/<\?!=\s*include\(['"]1\.2 StoreExplorer_scripts['"]\);?\s*\?>/g, () => scripts);
  html = html.replace(/<\?!=\s*preloadedInitialData\s*\|\|\s*'null'\s*\?>/g, () => JSON.stringify(INITIAL_DATA_PAYLOAD));
  html = html.replace(/<\?=\s*\(typeof isDebugMode[^?]+\)\s*\?>/g, () => 'display:none;');

  // Inyectar Mock de google.script.run para que responda instantáneamente en localhost
  const mockScript = `
  <script>
    window.showLoading = window.showLoading || function(m) { console.log('[Loading]', m); };
    window.hideLoading = window.hideLoading || function() {};
    window.showToast = window.showToast || function(m, t) { console.log('[Toast ' + t + ']', m); };

    window.MOCK_ALL_METRICS = ${JSON.stringify(ALL_STORE_METRICS)};
    window.MOCK_ALL_RINGS = ${JSON.stringify(ALL_STORE_RINGS)};
    window.MOCK_ALL_POLYGONS = ${JSON.stringify(PRELOADED_POLYGONS)};
    window.MOCK_INITIAL_PAYLOAD = ${JSON.stringify(INITIAL_DATA_PAYLOAD)};

    if (typeof google === 'undefined') window.google = {};
    if (!google.script) {
      google.script = {
        run: {
          _success: null,
          _failure: null,
          withSuccessHandler: function(fn) {
            const runner = Object.create(this);
            runner._success = fn;
            return runner;
          },
          withFailureHandler: function(fn) {
            const runner = Object.create(this);
            runner._failure = fn;
            return runner;
          },
          getStoreExplorerInitialData: function() {
            const self = this;
            setTimeout(() => {
              if (self._success) self._success(window.MOCK_INITIAL_PAYLOAD);
            }, 10);
          },
          getStoreTotalMetrics: function(ids, month) {
            const self = this;
            setTimeout(() => {
              const idSet = new Set((ids || []).map(id => String(id).trim()));
              const filtered = (window.MOCK_ALL_METRICS && window.MOCK_ALL_METRICS.stores)
                ? window.MOCK_ALL_METRICS.stores.filter(s => idSet.has(String(s.warehouse_id).trim()))
                : [];
              if (self._success) self._success({ stores: filtered });
            }, 20);
          },
          getMultipleStoreRingsData: function(ids, month) {
            const self = this;
            setTimeout(() => {
              const idSet = new Set((ids || []).map(id => String(id).trim()));
              const filtered = (window.MOCK_ALL_RINGS || []).filter(r => idSet.has(String(r.warehouse_id).trim()));
              if (self._success) self._success(filtered);
            }, 20);
          },
          getMultipleStorePolygonsGeoJson: function(ids, month) {
            const self = this;
            setTimeout(() => {
              const idSet = new Set((ids || []).map(id => String(id).trim()));
              const filtered = (window.MOCK_ALL_POLYGONS || []).filter(p => idSet.has(String(p.warehouse_id).trim()));
              if (self._success) self._success(filtered);
            }, 10);
          },
          logMapsterTelemetry: function() {},
          logBatchButtonClicks: function() {},
          fetchDeferredWeatherForDate: function() {
            if (this._success) this._success({});
          }
        }
      };
    }
  </script>
  `;

  html = html.replace('</head>', () => mockScript + '\n</head>');
  return html;
}

const server = http.createServer((req, res) => {
  if (req.url === '/' || req.url.startsWith('/?')) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(buildHtml());
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`[All-Map Dev Server] Servidor local escuchando en http://localhost:${PORT}`);
});
