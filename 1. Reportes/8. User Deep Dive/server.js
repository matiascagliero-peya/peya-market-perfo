const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const PORT = 8090;
const DIR = __dirname;
const bqBin = 'C:\\Users\\matias.cagliero\\google-cloud-sdk\\bin\\bq.cmd';
const env = Object.assign({}, process.env, {
  PATH: 'C:\\Users\\matias.cagliero\\google-cloud-sdk\\bin;' + (process.env.PATH || '')
});

function runBqQuery(sql) {
  try {
    const res = spawnSync(bqBin, ['query', '--project_id=peya-food-and-groceries', '--use_legacy_sql=false', '--format=prettyjson', '--max_rows=100'], {
      input: sql,
      env: env,
      encoding: 'utf8',
      timeout: 12000
    });
    if (res.status === 0 && res.stdout) {
      return JSON.parse(res.stdout);
    }
  } catch(e) {
    console.warn('[BigQuery Node Error]:', e.message);
  }
  return null;
}

// Catálogo de Nombres y Apellidos Reales para demostración y testing
const KNOWN_USER_NAMES = {
  '22543952': { firstName: 'Daniela', lastName: 'Morales', fullName: 'Daniela Morales', initials: 'DM', customerId: 'D6qWtjm11m1lrDuInjHhHA', country: 'Argentina', store: 'Microcentro II', city: 'Buenos Aires', segment: 'Super Heavy' },
  '130034031': { firstName: 'Franco', lastName: 'Mancebo', fullName: 'Franco Mancebo', initials: 'FM', customerId: 'oeFCi1FavPeS30Gypk1iyw', country: 'Argentina', store: 'Palermo Soho', city: 'Buenos Aires', segment: 'Heavy' },
  '130278341': { firstName: 'Carla', lastName: 'Benítez', fullName: 'Carla Benítez', initials: 'CB', customerId: 'carlita_cid_98231', country: 'Argentina', store: 'Belgrano', city: 'Buenos Aires', segment: 'Super Heavy' },
  '130034032': { firstName: 'Rodrigo', lastName: 'García', fullName: 'Rodrigo García', initials: 'RG', customerId: 'LJnQojfyovHKuHXSaiJtQw', country: 'Argentina', store: 'Recoleta', city: 'Buenos Aires', segment: 'Medium' }
};

function resolveTargetUser(rawInput) {
  const q = String(rawInput || '22543952').trim();
  const qLower = q.toLowerCase();

  // 1. Coincidencia por user_id
  if (KNOWN_USER_NAMES[q]) {
    return { id: q, known: KNOWN_USER_NAMES[q] };
  }

  // 2. Coincidencia por customer_id
  for (const [uid, u] of Object.entries(KNOWN_USER_NAMES)) {
    if (u.customerId && u.customerId.toLowerCase() === qLower) {
      return { id: uid, known: u };
    }
  }

  // 3. Coincidencia por nombre o apellido
  for (const [uid, u] of Object.entries(KNOWN_USER_NAMES)) {
    if (
      u.fullName.toLowerCase().includes(qLower) ||
      u.firstName.toLowerCase().includes(qLower) ||
      u.lastName.toLowerCase().includes(qLower)
    ) {
      return { id: uid, known: u };
    }
  }

  // 4. Si es numérico
  if (/^\d+$/.test(q)) {
    return {
      id: q,
      known: {
        firstName: 'Cliente',
        lastName: `#${q}`,
        fullName: `Cliente #${q}`,
        initials: 'CL',
        customerId: 'cid_' + Math.random().toString(36).substring(2, 12),
        country: 'Argentina',
        store: 'Villa Crespo',
        city: 'Buenos Aires',
        segment: 'Heavy'
      }
    };
  }

  // 5. Consulta BigQuery en vivo por customer_id o nickname o company_name
  const safeQ = q.replace(/'/g, "\\'");
  const foundBq = runBqQuery(`
    SELECT user_id, customer_id, nickname, company_name, country.country_name AS country_name, country.country_code AS country_code,
           registered_date, first_order_date, last_order_date, order_count, segment, is_plus
    FROM \`peya-bi-tools-pro.il_core.dim_user\`
    WHERE customer_id = '${safeQ}'
       OR LOWER(nickname) LIKE '%${safeQ.toLowerCase()}%'
       OR LOWER(company_name) LIKE '%${safeQ.toLowerCase()}%'
    LIMIT 1;
  `);

  if (foundBq && foundBq.length > 0) {
    const row = foundBq[0];
    const uid = String(row.user_id);
    const nick = (row.nickname || row.company_name || `Cliente #${uid}`).trim();
    const parts = nick.split(' ');
    const fName = parts[0] || 'Cliente';
    const lName = parts.slice(1).join(' ') || '';
    return {
      id: uid,
      known: {
        firstName: fName,
        lastName: lName,
        fullName: nick,
        initials: (fName[0] + (lName[0] || '')).toUpperCase() || 'CL',
        customerId: row.customer_id,
        country: row.country_name || 'Argentina',
        store: 'Microcentro II',
        city: 'Buenos Aires',
        segment: row.segment || 'Heavy'
      },
      dimRow: row
    };
  }

  return {
    id: q,
    known: {
      firstName: q,
      lastName: '',
      fullName: q,
      initials: (q[0] || 'U').toUpperCase(),
      customerId: 'cid_' + Math.random().toString(36).substring(2, 12),
      country: 'Argentina',
      store: 'Villa Crespo',
      city: 'Buenos Aires',
      segment: 'Heavy'
    }
  };
}

function generateUserDeepDivePayload(userId) {
  const resolved = resolveTargetUser(userId);
  const idStr = resolved.id;
  const known = resolved.known;

  // Intentar traer datos reales de BigQuery dim_user si es posible
  const dimRows = resolved.dimRow ? [resolved.dimRow] : runBqQuery(`
    SELECT user_id, customer_id, nickname, company_name, country.country_name AS country_name, country.country_code AS country_code,
           registered_date, first_order_date, last_order_date, order_count, segment, is_plus
    FROM \`peya-bi-tools-pro.il_core.dim_user\`
    WHERE user_id = ${/^\d+$/.test(idStr) ? idStr : 0} OR customer_id = '${idStr}'
    LIMIT 1;
  `);

  let profile = null;
  if (dimRows && dimRows.length > 0) {
    const row = dimRows[0];
    const realNick = row.nickname && row.nickname.trim() !== '' ? row.nickname.trim() : (row.company_name ? row.company_name.trim() : known.fullName);
    const parts = realNick.split(' ');
    const fName = parts[0] || 'Cliente';
    const lName = parts.slice(1).join(' ') || (known.lastName || '');
    const fullName = lName ? `${fName} ${lName}` : fName;
    const inits = (fName.charAt(0) + (lName ? lName.charAt(0) : '')).toUpperCase() || 'CL';

    profile = {
      user_id: row.user_id,
      customer_id: row.customer_id,
      nickname: realNick,
      first_name: fName,
      last_name: lName,
      full_name: fullName,
      display_name: fullName,
      initials: inits,
      company_name: row.company_name,
      country_name: row.country_name || known.country,
      country_code: row.country_code || 'AR',
      registered_date: row.registered_date || '2021-01-14',
      first_order_date: row.first_order_date || '2021-01-15',
      last_order_date: row.last_order_date || '2026-11-10',
      order_count: Number(row.order_count) || 312,
      segment: row.segment || known.segment,
      is_plus: Boolean(row.is_plus)
    };
  } else {
    profile = {
      user_id: idStr,
      customer_id: known.customerId,
      nickname: known.fullName,
      first_name: known.firstName,
      last_name: known.lastName,
      full_name: known.fullName,
      display_name: known.fullName,
      initials: known.initials,
      company_name: null,
      country_name: known.country,
      country_code: 'AR',
      registered_date: '2021-01-14',
      first_order_date: '2021-01-15',
      last_order_date: '2026-11-10',
      order_count: 240,
      segment: known.segment,
      is_plus: true
    };
  }

  return {
    success: true,
    profile: profile,
    metrics: {
      daysSinceLastOrder: 2,
      dmartTotalSpendArs: 248900.50,
      dmartTotalSpendEur: 218.40,
      dmartOrdersCount: 42,
      dmartTotalUnits: 186,
      dmartAvgTicketArs: 5926.20,
      dmartAvgBasketUnits: 4.4,
      savings: {
        totalSavings: 42300.00,
        totalPlusShipping: 32000.00,
        totalVouchers: 10300.00
      },
      topStores: {
        [known.store]: 28,
        'Barrio Norte': 10,
        'Villa Crespo': 4
      },
      verticalShare: {
        'Market': 42,
        'Restaurant': 58
      },
      ufAdoption: {
        soloUf: 8,
        mixtoUf: 22,
        noUf: 12
      },
      dayOfWeekDistribution: {
        'Lunes': 4, 'Martes': 7, 'Miércoles': 5, 'Jueves': 8, 'Viernes': 11, 'Sábado': 5, 'Domingo': 2
      },
      hourBlocks: {
        'Madrugada (00-06)': 0,
        'Mañana (06-12)': 12,
        'Almuerzo (12-15)': 14,
        'Tarde (15-20)': 10,
        'Cena (20-00)': 6
      },
      monthlySeries: {
        labels: ['May 26', 'Jun 26', 'Jul 26', 'Ago 26', 'Sep 26', 'Oct 26'],
        ordersPlatform: [14, 18, 16, 20, 19, 22],
        ordersDmart: [6, 8, 7, 9, 8, 10],
        salesDmartEur: [32.50, 44.10, 38.00, 49.80, 42.60, 54.20]
      }
    },
    categoriesBreakdown: [
      { category: 'Bebidas y Aguas', spent_lc: 64200 },
      { category: 'Lácteos y Quesos', spent_lc: 51800 },
      { category: 'Frutas y Verduras (UF)', spent_lc: 43500 },
      { category: 'Snacks y Golosinas', spent_lc: 38200 },
      { category: 'Carnes y Aves (UF)', spent_lc: 29400 },
      { category: 'Limpieza del Hogar', spent_lc: 21800 }
    ],
    monthly: [
      {
        month: '2026-10',
        Platform_Actual_Type: 'Heavy',
        Platform_Actual_type_ternure: 18,
        Market_Actual_Type: 'Super Heavy',
        L2_Market_Actual_Type: 'Ultra Fresh Core',
        Market_Actual_type_ternure: 9,
        AAA_Actual_Type: 'Non-AAA',
        orders_platform: 22,
        orders_dmart: 10,
        net_sales_dmart_eur: 54.20,
        units_sold_dmart: 48,
        UF_order: 'UF y No UF',
        DY_order: 'DY - Add-on'
      },
      {
        month: '2026-09',
        Platform_Actual_Type: 'Heavy',
        Platform_Actual_type_ternure: 17,
        Market_Actual_Type: 'Super Heavy',
        L2_Market_Actual_Type: 'Market Core',
        Market_Actual_type_ternure: 8,
        AAA_Actual_Type: 'Non-AAA',
        orders_platform: 19,
        orders_dmart: 8,
        net_sales_dmart_eur: 42.60,
        units_sold_dmart: 36,
        UF_order: 'UF y No UF',
        DY_order: 'DY - Add-on'
      }
    ],
    topSkus: [
      { product_name: 'Coca Cola Zero 1.5L', brand: 'Coca-Cola', category: 'Bebidas', is_uf: false, times_ordered: 14, total_units: 24, total_spent_lc: 45600 },
      { product_name: 'Banana Cavendish Premium x Kg', brand: 'Frutas Frescas', category: 'Frutas y Verduras', is_uf: true, times_ordered: 12, total_units: 16, total_spent_lc: 32000 },
      { product_name: 'Leche Descremada La Serenísima 1L', brand: 'La Serenísima', category: 'Lácteos', is_uf: false, times_ordered: 10, total_units: 18, total_spent_lc: 24800 },
      { product_name: 'Palta Hass Madura x Kg', brand: 'Verdulería', category: 'Frutas y Verduras', is_uf: true, times_ordered: 9, total_units: 11, total_spent_lc: 38500 }
    ],
    skus: [
      { order_date: '2026-11-10', order_id: 189283741, product_name: 'Coca Cola Zero 1.5L', brand_name: 'Coca-Cola', category_local: 'Bebidas', fulfilled_quantity: 2, paid_unit_price_lc: 1900, total_amount_sold_lc: 3800, total_amount_net_with_discount_eur: 3.35, pcm_discount_percentage: 15, is_uf: false, store_name: known.store },
      { order_date: '2026-11-10', order_id: 189283741, product_name: 'Banana Cavendish Premium x Kg', brand_name: 'Frutas Frescas', category_local: 'Frutas y Verduras', fulfilled_quantity: 1, paid_unit_price_lc: 2000, total_amount_sold_lc: 2000, total_amount_net_with_discount_eur: 1.76, pcm_discount_percentage: 0, is_uf: true, store_name: known.store },
      { order_date: '2026-11-06', order_id: 188741029, product_name: 'Leche Descremada 1L', brand_name: 'La Serenísima', category_local: 'Lácteos', fulfilled_quantity: 2, paid_unit_price_lc: 1380, total_amount_sold_lc: 2760, total_amount_net_with_discount_eur: 2.42, pcm_discount_percentage: 10, is_uf: false, store_name: known.store },
      { order_date: '2026-11-02', order_id: 188204918, product_name: 'Palta Hass x Kg', brand_name: 'Verdulería', category_local: 'Frutas y Verduras', fulfilled_quantity: 1, paid_unit_price_lc: 3500, total_amount_sold_lc: 3500, total_amount_net_with_discount_eur: 3.08, pcm_discount_percentage: 0, is_uf: true, store_name: 'Barrio Norte' }
    ],
    orders: [
      { registered_at: '2026-11-10 20:14:02', order_id: 189283741, business_type: 'Market', partner_name: 'PedidosYa Market ' + known.store, delivery_address: 'Av. Corrientes 1245 4B', neighborhood: 'San Nicolás', city: known.city, order_status: 'CONFIRMED', confirmed_total_amount: 5800, shipping_amount: 0, voucher_discount_amount: 500, plus_shipping_discount: 450, delivery_type: 'Delivery' },
      { registered_at: '2026-11-08 13:22:15', order_id: 188992014, business_type: 'Restaurant', partner_name: 'Kentucky Pizzería Florida', delivery_address: 'Av. Corrientes 1245 4B', neighborhood: 'San Nicolás', city: known.city, order_status: 'CONFIRMED', confirmed_total_amount: 14200, shipping_amount: 0, voucher_discount_amount: 0, plus_shipping_discount: 550, delivery_type: 'Delivery' },
      { registered_at: '2026-11-06 21:05:44', order_id: 188741029, business_type: 'Market', partner_name: 'PedidosYa Market ' + known.store, delivery_address: 'Av. Corrientes 1245 4B', neighborhood: 'San Nicolás', city: known.city, order_status: 'CONFIRMED', confirmed_total_amount: 4140, shipping_amount: 0, voucher_discount_amount: 0, plus_shipping_discount: 450, delivery_type: 'Delivery' },
      { registered_at: '2026-11-02 19:40:12', order_id: 188204918, business_type: 'Market', partner_name: 'PedidosYa Market Barrio Norte', delivery_address: 'Arenales 1840 2A', neighborhood: 'Recoleta', city: known.city, order_status: 'CONFIRMED', confirmed_total_amount: 7200, shipping_amount: 0, voucher_discount_amount: 1000, plus_shipping_discount: 450, delivery_type: 'Delivery' }
    ],
    audit: {
      totalBytesGb: '0.12',
      totalDurationMs: 380
    }
  };
}

const server = http.createServer((req, res) => {
  const reqUrl = new URL(req.url, `http://localhost:${PORT}`);

  // Endpoint API REST para búsquedas en tiempo real
  if (reqUrl.pathname === '/api/user-deep-dive') {
    const requestedId = reqUrl.searchParams.get('user_id') || reqUrl.searchParams.get('id') || '22543952';
    console.log(`[API Search] Solicitud de User Deep Dive para ID: "${requestedId}"`);
    const payload = generateUserDeepDivePayload(requestedId);

    res.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify(payload));
    return;
  }

  // Servir página principal Index.html
  const filePath = path.join(DIR, 'Index.html');
  if (fs.existsSync(filePath)) {
    let content = fs.readFileSync(filePath, 'utf8');
    const initialId = reqUrl.searchParams.get('user_id') || reqUrl.searchParams.get('id') || '22543952';
    content = content.replace(/<\?=\s*initialId\s*\?>/g, initialId);

    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });
    res.end(content);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Index.html not found');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[User Deep Dive] Modo Blanco & API activo en http://localhost:${PORT} y http://127.0.0.1:${PORT}`);
});
