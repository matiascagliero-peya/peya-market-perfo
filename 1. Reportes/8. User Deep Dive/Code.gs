// ==============================================================================
// REPORTE WEB APP: USER DEEP DIVE (CUSTOMER 360° GRANULAR ANALYTICS)
// Proyecto: PeYa Market
// Matías Sebastián Cagliero Lomazzi
// Permite analizar minuciosamente el perfil, ciclo de vida, órdenes y canastas (SKU)
// ==============================================================================

const UDD_CONFIG = {
  name: "Matias Sebastian Cagliero Lomazzi",
  BQ_PROJECT_ID: "peya-food-and-groceries",
  DEFAULT_USER_ID: "22543952",
  ADMIN_EMAILS: [
    "matias.cagliero@pedidosya.com"
  ]
};

function doGet(e) {
  const initialId = (e && e.parameter && (e.parameter.user_id || e.parameter.id || e.parameter.customer_id)) 
    ? String(e.parameter.user_id || e.parameter.id || e.parameter.customer_id).trim() 
    : UDD_CONFIG.DEFAULT_USER_ID;

  const template = HtmlService.createTemplateFromFile("Index");
  template.initialId = initialId;

  return template.evaluate()
    .setTitle("User Deep Dive | PeYa Market Analytics")
    .addMetaTag("viewport", "width=device-width, initial-scale=1.0")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

/**
 * Ejecutor estándar de consultas BigQuery con soporte de paginación,
 * timeout extendido y telemetría de bytes/cómputo.
 */
function ejecutarQueryBigQuery(sql, projectId) {
  if (typeof BigQuery === 'undefined') {
    throw new Error("El servicio avanzado BigQuery no está habilitado en este proyecto de Apps Script.");
  }

  const proj = projectId || UDD_CONFIG.BQ_PROJECT_ID;
  const request = {
    query: sql,
    useLegacySql: false,
    useQueryCache: true,
    timeoutMs: 120000
  };

  const startTime = new Date().getTime();
  let queryResults = BigQuery.Jobs.query(request, proj);
  const jobId = queryResults.jobReference.jobId;

  let sleepMs = 300;
  while (!queryResults.jobComplete) {
    Utilities.sleep(sleepMs);
    sleepMs = Math.min(sleepMs * 2, 3000);
    queryResults = BigQuery.Jobs.getQueryResults(proj, jobId);
  }

  let totalBytes = Number(queryResults.totalBytesProcessed || 0);
  let allRows = queryResults.rows || [];

  while (queryResults.pageToken) {
    queryResults = BigQuery.Jobs.getQueryResults(proj, jobId, {
      pageToken: queryResults.pageToken
    });
    if (queryResults.rows && queryResults.rows.length > 0) {
      allRows = allRows.concat(queryResults.rows);
    }
  }

  const durationMs = new Date().getTime() - startTime;
  const fields = queryResults.schema && queryResults.schema.fields ? queryResults.schema.fields : [];
  const fieldNames = fields.map(f => f.name);

  const mapped = allRows.map(r => {
    const obj = {};
    for (let i = 0; i < fieldNames.length; i++) {
      obj[fieldNames[i]] = (r.f && r.f[i]) ? r.f[i].v : null;
    }
    return obj;
  });

  return {
    rows: mapped,
    bytesProcessed: totalBytes,
    durationMs: durationMs,
    jobId: jobId
  };
}

// Catálogo de Nombres y Apellidos Reales para demostración y testing
const KNOWN_USER_NAMES = {
  '22543952': { firstName: 'Daniela', lastName: 'Morales', fullName: 'Daniela Morales', initials: 'DM', customerId: 'D6qWtjm11m1lrDuInjHhHA' },
  '130034031': { firstName: 'Franco', lastName: 'Mancebo', fullName: 'Franco Mancebo', initials: 'FM', customerId: 'oeFCi1FavPeS30Gypk1iyw' },
  '130278341': { firstName: 'Carla', lastName: 'Benítez', fullName: 'Carla Benítez', initials: 'CB', customerId: 'M_B2bt44zpGo3eeEG8Z0fQ' },
  '130034032': { firstName: 'Rodrigo', lastName: 'García', fullName: 'Rodrigo García', initials: 'RG', customerId: 'LJnQojfyovHKuHXSaiJtQw' }
};

/**
 * Consulta integral para obtener la radiografía completa del usuario.
 * @param {string} rawInput - ID de usuario numérico, customer_id o nombre/apellido.
 */
function getUserDeepDiveData(rawInput) {
  try {
    let input = String(rawInput || UDD_CONFIG.DEFAULT_USER_ID).trim();
    if (!input) {
      return { success: false, error: "Identificador de usuario inválido." };
    }

    // Resolver si el input coincide con un nombre o apellido del catálogo conocido
    const qLower = input.toLowerCase();
    for (const [uid, u] of Object.entries(KNOWN_USER_NAMES)) {
      if (
        u.fullName.toLowerCase().includes(qLower) ||
        u.firstName.toLowerCase().includes(qLower) ||
        u.lastName.toLowerCase().includes(qLower)
      ) {
        input = uid;
        break;
      }
    }

    const isNumeric = /^\d+$/.test(input);
    const safeInput = input.replace(/'/g, "\\'");
    const idCondition = isNumeric 
      ? `(user_id = ${input} OR customer_id = '${safeInput}' OR customer_id_or_user_id = '${safeInput}')`
      : `(customer_id = '${safeInput}' OR customer_id_or_user_id = '${safeInput}' OR LOWER(nickname) LIKE '%${safeInput.toLowerCase()}%' OR LOWER(company_name) LIKE '%${safeInput.toLowerCase()}%')`;

    // --------------------------------------------------------------------------
    // 1. DIM_USER (Perfil demográfico y atributos generales)
    // --------------------------------------------------------------------------
    const sqlDimUser = `
      DECLARE query_name STRING DEFAULT 'UserDeepDive_1_DimUser';

      SELECT
        user_id,
        customer_id,
        customer_id_or_user_id,
        nickname,
        company_name,
        country.country_id AS country_id,
        country.country_code AS country_code,
        country.country_name AS country_name,
        registered_date,
        first_order_date,
        last_order_date,
        order_count,
        segment,
        lifecycle_stage,
        is_plus,
        qc_user,
        dm_user,
        user_birth_date,
        user_gender,
        is_corporate_user,
        application_type,
        user_state,
        online_payment_user,
        first_order_date_id,
        registered_date_id,
        last_updated
      FROM \`peya-bi-tools-pro.il_core.dim_user\`
      WHERE ${idCondition}
      LIMIT 1;
    `;

    const dimRes = ejecutarQueryBigQuery(sqlDimUser);
    if (!dimRes.rows || dimRes.rows.length === 0) {
      return {
        success: false,
        error: `No se encontró ningún usuario con el identificador "${input}" en la dimensión oficial de usuarios (dim_user).`
      };
    }

    const userProfile = dimRes.rows[0];
    const customerId = userProfile.customer_id;
    const userId = userProfile.user_id;
    const countryName = userProfile.country_name || "Argentina";
    const countryId = userProfile.country_id || 3;
    const countryCodeLower = (userProfile.country_code || "ar").toLowerCase();

    // Resolver nombre y apellido real visible
    let cleanDisplayName = "";
    let cleanFullName = "";
    let cleanInitials = "CL";

    const matchedKnown = KNOWN_USER_NAMES[String(userProfile.user_id)];
    if (matchedKnown) {
      cleanFullName = matchedKnown.fullName;
      cleanDisplayName = matchedKnown.fullName;
      cleanInitials = matchedKnown.initials;
    } else {
      const rawNickname = userProfile.nickname ? String(userProfile.nickname).trim() : "";
      const rawCompany = userProfile.company_name ? String(userProfile.company_name).trim() : "";
      if (rawNickname && rawNickname.toLowerCase() !== "null") {
        cleanDisplayName = rawNickname;
        cleanFullName = rawNickname;
      } else if (rawCompany && rawCompany.toLowerCase() !== "null") {
        cleanDisplayName = rawCompany;
        cleanFullName = rawCompany;
      } else {
        cleanDisplayName = `Cliente #${userProfile.user_id}`;
        cleanFullName = `Cliente #${userProfile.user_id}`;
      }
      const nameParts = cleanFullName.split(' ').filter(Boolean);
      cleanInitials = nameParts.map(p => p[0]).slice(0, 2).join('').toUpperCase() || 'CL';
    }

    userProfile.display_name = cleanDisplayName;
    userProfile.full_name = cleanFullName;
    userProfile.initials = cleanInitials;

    // --------------------------------------------------------------------------
    // 2. FRANK USER MONTHLY ACTIVITY & TAXONOMY (Evolución de Ciclo de Vida L1 y L2)
    // --------------------------------------------------------------------------
    const sqlMonthly = `
      DECLARE query_name STRING DEFAULT 'UserDeepDive_2_MonthlyActivityAndType';

      SELECT
        act.month,
        act.country,
        act.is_active_platform,
        act.is_active_food,
        act.is_active_aaa,
        act.is_active_dmart,
        act.orders_platform,
        act.orders_dmart,
        act.orders_uf_dmart,
        act.orders_dy_dmart,
        act.units_sold_dmart,
        ROUND(COALESCE(act.net_sales_dmart_eur, 0), 2) AS net_sales_dmart_eur,
        act.DY_order,
        act.UF_order,
        typ.Platform_Actual_Type,
        typ.Platform_Actual_type_ternure,
        typ.Market_adoption_date,
        typ.Market_user_adoption_tenure,
        typ.Market_previous_type,
        typ.Market_Actual_Type,
        typ.Market_Actual_type_ternure,
        typ.L2_Market_Actual_Type,
        typ.AAA_Actual_Type,
        typ.L2_AAA_Actual_Type
      FROM \`peya-food-and-groceries.automated_tables_reports.frank_user_monthly_activity\` act
      LEFT JOIN \`peya-food-and-groceries.automated_tables_reports.frank_user_type_monthly\` typ
        ON act.customer_id = typ.customer_id
       AND act.country = typ.country
       AND act.month = typ.Mes
      WHERE act.country = '${countryName}'
        AND act.customer_id = '${customerId}'
      ORDER BY act.month DESC;
    `;

    const monthlyRes = ejecutarQueryBigQuery(sqlMonthly);

    // --------------------------------------------------------------------------
    // 3. FACT ORDERS (Registro transaccional de órdenes multi-vertical)
    // --------------------------------------------------------------------------
    const sqlOrders = `
      DECLARE query_name STRING DEFAULT 'UserDeepDive_3_FactOrders';

      SELECT
        registered_date,
        registered_at,
        order_id,
        country.country_name AS country,
        city.city_name AS city,
        restaurant.id AS partner_id,
        restaurant.name AS partner_name,
        business_type.business_type_name AS business_type,
        CONCAT(COALESCE(address.street, ''), ' ', COALESCE(address.doorNumber, '')) AS delivery_address,
        address.area.name AS neighborhood,
        order_status,
        ROUND(COALESCE(confirmed_total_amount, 0), 2) AS confirmed_total_amount,
        ROUND(COALESCE(confirmed_order_shipping_amount, 0), 2) AS shipping_amount,
        delivery_type,
        has_voucher_discount,
        ROUND(COALESCE(voucher_discount_amount, 0), 2) AS voucher_discount_amount,
        has_plus_shipping_cost_discount,
        ROUND(COALESCE(plus_shipping_cost_discount_amount, 0), 2) AS plus_shipping_discount,
        confirmed_order_online_payment,
        fail_rate_owner
      FROM \`peya-bi-tools-pro.il_core.fact_orders\`
      WHERE registered_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 36 MONTH)
        AND country_id = ${countryId}
        AND (customer_id = '${customerId}' OR user.id = ${userId})
      ORDER BY registered_date DESC, registered_at DESC
      LIMIT 150;
    `;

    const ordersRes = ejecutarQueryBigQuery(sqlOrders);

    // --------------------------------------------------------------------------
    // 4. SKU LEVEL DETAILS (Canasta granular en PeYa Market)
    // --------------------------------------------------------------------------
    const sqlSkus = `
      DECLARE query_name STRING DEFAULT 'UserDeepDive_4_MarketSkuDetails';

      SELECT
        order_date,
        order_id,
        store_name,
        warehouse_id,
        sku_id,
        product_name,
        brand_name,
        master_category_parent_english,
        category_local,
        ordered_quantity,
        fulfilled_quantity,
        delivered_quantity,
        is_partial,
        is_returned,
        ROUND(COALESCE(listed_unit_price_lc, 0), 2) AS listed_unit_price_lc,
        ROUND(COALESCE(paid_unit_price_lc, 0), 2) AS paid_unit_price_lc,
        ROUND(COALESCE(total_amount_sold_lc, 0), 2) AS total_amount_sold_lc,
        ROUND(COALESCE(total_amount_net_with_discount_eur, 0), 2) AS total_amount_net_with_discount_eur,
        ROUND(COALESCE(pcm_discount_percentage, 0), 2) AS pcm_discount_percentage,
        ROUND(COALESCE(pcm_discount_amount_lc, 0), 2) AS pcm_discount_amount_lc,
        currency_code,
        CASE WHEN master_category_parent_english IN ('Produce', 'Meat / Seafood', 'Ready To Consume') THEN TRUE ELSE FALSE END AS is_uf
      FROM \`peya-datamarts-pro.dm_dmarts.customer_orders_sku_level\`
      WHERE order_date >= '2025-01-01'
        AND country_code = '${countryCodeLower}'
        AND (customer_id = '${customerId}' OR user_id = ${userId})
        AND state = 'CONFIRMED'
      ORDER BY order_date DESC, order_id DESC;
    `;

    const skusRes = ejecutarQueryBigQuery(sqlSkus);

    // --------------------------------------------------------------------------
    // 5. CÁLCULO DE MÉTRICAS SINTÉTICAS Y HÁBITOS
    // --------------------------------------------------------------------------
    const orders = ordersRes.rows || [];
    const skus = skusRes.rows || [];
    const monthly = monthlyRes.rows || [];

    // Totales de PeYa Market
    let dmartTotalSpendArs = 0;
    let dmartTotalSpendEur = 0;
    let dmartTotalUnits = 0;
    const dmartOrderIds = new Set();
    const dmartStoreMap = {};
    const skuMap = {};
    const catMap = {};

    skus.forEach(s => {
      dmartOrderIds.add(String(s.order_id));
      const amountLc = Number(s.total_amount_sold_lc || 0);
      const amountEur = Number(s.total_amount_net_with_discount_eur || 0);
      const units = Number(s.fulfilled_quantity || 0);

      dmartTotalSpendArs += amountLc;
      dmartTotalSpendEur += amountEur;
      dmartTotalUnits += units;

      // Darkstore
      const store = s.store_name || "Desconocido";
      dmartStoreMap[store] = (dmartStoreMap[store] || 0) + 1;

      // SKU rollup
      const pName = s.product_name || "Sin nombre";
      if (!skuMap[pName]) {
        skuMap[pName] = {
          product_name: pName,
          brand: s.brand_name || "-",
          category: s.master_category_parent_english || "-",
          is_uf: s.is_uf,
          total_units: 0,
          total_spent_lc: 0,
          times_ordered: 0,
          ordersSet: new Set()
        };
      }
      skuMap[pName].total_units += units;
      skuMap[pName].total_spent_lc += amountLc;
      skuMap[pName].ordersSet.add(s.order_id);

      // Category rollup
      const cat = s.master_category_parent_english || "Other";
      if (!catMap[cat]) catMap[cat] = { category: cat, units: 0, spent_lc: 0 };
      catMap[cat].units += units;
      catMap[cat].spent_lc += amountLc;
    });

    Object.keys(skuMap).forEach(k => {
      skuMap[k].times_ordered = skuMap[k].ordersSet.size;
      delete skuMap[k].ordersSet;
    });

    const topSkus = Object.values(skuMap)
      .sort((a, b) => b.total_units - a.total_units || b.total_spent_lc - a.total_spent_lc)
      .slice(0, 25);

    const categoriesBreakdown = Object.values(catMap)
      .sort((a, b) => b.spent_lc - a.spent_lc);

    // Distribución por vertical y días/horarios
    const verticalMap = {};
    const dayOfWeekMap = { "Lunes": 0, "Martes": 0, "Miércoles": 0, "Jueves": 0, "Viernes": 0, "Sábado": 0, "Domingo": 0 };
    const dayNames = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
    const hourMap = {};
    for (let h = 0; h < 24; h++) hourMap[h] = 0;

    const partnerMap = {};

    orders.forEach(o => {
      const v = o.business_type || "Otros";
      verticalMap[v] = (verticalMap[v] || 0) + 1;

      const pName = o.partner_name || "Comercio";
      partnerMap[pName] = (partnerMap[pName] || 0) + 1;

      if (o.registered_at) {
        const d = new Date(o.registered_at);
        if (!isNaN(d.getTime())) {
          const dayName = dayNames[d.getDay()];
          dayOfWeekMap[dayName] = (dayOfWeekMap[dayName] || 0) + 1;
          const hr = d.getHours();
          hourMap[hr] = (hourMap[hr] || 0) + 1;
        }
      }
    });

    const topPartners = Object.keys(partnerMap)
      .map(k => ({ partner_name: k, orders: partnerMap[k] }))
      .sort((a, b) => b.orders - a.orders)
      .slice(0, 15);

    // Cálculos de ahorro y beneficios
    let totalVouchers = 0;
    let totalPlusShipping = 0;
    let totalSpentPlatformArs = 0;

    orders.forEach(o => {
      totalSpentPlatformArs += Number(o.confirmed_total_amount || 0);
      totalVouchers += Number(o.voucher_discount_amount || 0);
      totalPlusShipping += Number(o.plus_shipping_discount || 0);
    });

    let totalPcmDiscountsArs = 0;
    skus.forEach(s => {
      totalPcmDiscountsArs += Number(s.pcm_discount_amount_lc || 0);
    });

    // Serie cronológica para Chart.js (de más antiguo a más reciente)
    const chronologicalMonthly = [...monthly].reverse();
    const monthlySeries = {
      labels: chronologicalMonthly.map(m => m.month || ""),
      ordersPlatform: chronologicalMonthly.map(m => Number(m.orders_platform || 0)),
      ordersDmart: chronologicalMonthly.map(m => Number(m.orders_dmart || 0)),
      salesDmartEur: chronologicalMonthly.map(m => Number(m.net_sales_dmart_eur || 0)),
      unitsDmart: chronologicalMonthly.map(m => Number(m.units_sold_dmart || 0))
    };

    // Ultra Fresh adoption distribution
    let ufCountSolo = 0;
    let ufCountMixto = 0;
    let ufCountNo = 0;

    monthly.forEach(m => {
      if (Number(m.orders_dmart || 0) > 0) {
        if (m.UF_order === 'Solo UF') ufCountSolo++;
        else if (m.UF_order === 'UF y No UF') ufCountMixto++;
        else ufCountNo++;
      }
    });

    // Bloques horarios
    const hourBlocks = {
      "Madrugada (00-06h)": 0,
      "Mañana (06-12h)": 0,
      "Almuerzo (12-15h)": 0,
      "Tarde (15-20h)": 0,
      "Cena (20-24h)": 0
    };

    Object.entries(hourMap).forEach(([h, count]) => {
      const hr = Number(h);
      if (hr < 6) hourBlocks["Madrugada (00-06h)"] += count;
      else if (hr < 12) hourBlocks["Mañana (06-12h)"] += count;
      else if (hr < 15) hourBlocks["Almuerzo (12-15h)"] += count;
      else if (hr < 20) hourBlocks["Tarde (15-20h)"] += count;
      else hourBlocks["Cena (20-24h)"] += count;
    });

    // Recency calculation
    let daysSinceLastOrder = null;
    if (userProfile.last_order_date) {
      const lastDate = new Date(userProfile.last_order_date);
      if (!isNaN(lastDate.getTime())) {
        const diffMs = new Date().getTime() - lastDate.getTime();
        daysSinceLastOrder = Math.max(0, Math.floor(diffMs / (1000 * 60 * 60 * 24)));
      }
    }

    const totalBytesProcessed = dimRes.bytesProcessed + monthlyRes.bytesProcessed + ordersRes.bytesProcessed + skusRes.bytesProcessed;
    const totalQueryDuration = dimRes.durationMs + monthlyRes.durationMs + ordersRes.durationMs + skusRes.durationMs;

    return {
      success: true,
      profile: userProfile,
      monthly: monthly,
      orders: orders,
      skus: skus,
      topSkus: topSkus,
      categoriesBreakdown: categoriesBreakdown,
      metrics: {
        dmartOrdersCount: dmartOrderIds.size,
        dmartTotalSpendArs: dmartTotalSpendArs,
        dmartTotalSpendEur: dmartTotalSpendEur,
        dmartTotalUnits: dmartTotalUnits,
        dmartAvgTicketArs: dmartOrderIds.size > 0 ? (dmartTotalSpendArs / dmartOrderIds.size) : 0,
        dmartAvgBasketUnits: dmartOrderIds.size > 0 ? (dmartTotalUnits / dmartOrderIds.size) : 0,
        verticalShare: verticalMap,
        dayOfWeekDistribution: dayOfWeekMap,
        hourDistribution: hourMap,
        hourBlocks: hourBlocks,
        topStores: dmartStoreMap,
        topPartners: topPartners,
        totalSpentPlatformArs: totalSpentPlatformArs,
        savings: {
          totalVouchers: totalVouchers,
          totalPlusShipping: totalPlusShipping,
          totalPcmDiscountsArs: totalPcmDiscountsArs,
          totalSavings: totalVouchers + totalPlusShipping + totalPcmDiscountsArs
        },
        ufAdoption: {
          soloUf: ufCountSolo,
          mixtoUf: ufCountMixto,
          noUf: ufCountNo
        },
        monthlySeries: monthlySeries,
        daysSinceLastOrder: daysSinceLastOrder
      },
      audit: {
        totalBytesProcessed: totalBytesProcessed,
        totalBytesGb: (totalBytesProcessed / 1024 / 1024 / 1024).toFixed(3),
        totalDurationMs: totalQueryDuration,
        jobs: [dimRes.jobId, monthlyRes.jobId, ordersRes.jobId, skusRes.jobId]
      }
    };

  } catch (err) {
    return {
      success: false,
      error: "Ocurrió un error al procesar el deep dive del usuario: " + err.message,
      stack: err.stack
    };
  }
}
