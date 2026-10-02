// =================================================================
// SISTEMA DE ENVÍO DE ALERTAS (Email & Slack) - PeYa Markets
// =================================================================

/**
 * Función heredada por compatibilidad. Redirige a la función oficial única: enviarReporteDiario10AM.
 */
function enviarAlertasDiariasPorEmail() {
  return enviarReporteDiario10AM();
}

/**
 * Genera y envía un correo con un diseño premium y responsive de tarjetas de alerta.
 */
function enviarNewsletterDeAlertas(destinatario, fechaCierre, alertas, sub) {
  var FULL_PAIS_NAMES = {'AR':'Argentina','BO':'Bolivia','CL':'Chile','CH':'Chile','CO':'Colombia','EC':'Ecuador','SV':'El Salvador','GT':'Guatemala','HN':'Honduras','NI':'Nicaragua','PA':'Panamá','PY':'Paraguay','PE':'Perú','UY':'Uruguay','DO':'Rep. Dominicana','RD':'Rep. Dominicana'};

  function getMetricRuleDescriptionMail(mLabel) {
    var mKey = getMetricaKeyByLabel(mLabel);
    switch (mKey) {
      case 'orders': return 'Caída > 20.0% vs L3W';
      case 'gmv': return 'Caída > 20.0% vs L3W';
      case 'new_users': return 'Caída > 25.0% vs L3W';
      case 'wis': return 'Absoluto < 75.0% o Caída > 5.0 pp vs L3W';
      case 'wis_uf': return 'Absoluto < 75.0% o Caída > 5.0 pp vs L3W';
      case 'seamless': return 'Absoluto < 75.0% o Caída > 5.0 pp vs 7D';
      case 'delivery_time': return 'Absoluto > 40.0 min o Aumento > 5.0 min vs L3W';
      case 'assignment_time': return 'Absoluto > 7.0 min o Aumento > 5.0 min vs L3W';
      case 'rejected_orders': return 'Absoluto > 3.0%';
      case 'assignment_time_over_6m': return 'Absoluto > 30.0%';
      case 'forced_preorders': return 'Absoluto > 2.5%';
      case 'modified_orders': return 'Aumento > 3.0 pp vs 7D';
      case 'late_orders': return 'Aumento > 5.0 pp vs 7D';
      case 'slow_orders': return 'Aumento > 5.0 pp vs 7D';
      case 'session_orders': return 'Aumento > 3.0 pp vs 7D';
      case 'open_time': return 'Absoluto < 90.0%';
      default: return 'Desvío fuera de límites pactados';
    }
  }
  
  var scriptUrl = "https://script.google.com/a/pedidosya.com/macros/s/AKfycbzZBZZlqHZpkAigzkZ7lr4Qs6LU3P2TgHL3pzQ1SFLneXhxlQ-h1vKtQl2orO1xtDcBMg/exec";
  var dateParts = fechaCierre.split('-');
  var spanishMonths = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
  var monthName = spanishMonths[parseInt(dateParts[1]) - 1] || "mes";

  var countriesSet = {}, metricsSet = {};
  alertas.forEach(function(a) {
    countriesSet[String(a.pais).split('_')[0].toUpperCase()] = true;
    metricsSet[a.metricaLabel] = true;
  });

  var metricsAvail = _getMetricsAvailability(false);
  var dayAvail = (metricsAvail && fechaCierre) ? metricsAvail[fechaCierre] : null;

  // Normalizar de forma proactiva los países de la suscripción a códigos ISO (ej: 'Rep. Dominicana' -> 'DO')
  if (sub && sub.paises && sub.paises.length > 0) {
    sub.paises = sub.paises.map(function(c) { return getISO(c); });
  }

  var subCountriesSorted = [];
  if (sub && sub.paises && sub.paises.length > 0) {
    var hasTodosOrLatam = sub.paises.indexOf("TODOS") !== -1 || sub.paises.indexOf("LATAM") !== -1;
    if (hasTodosOrLatam) {
      subCountriesSorted = ['AR', 'BO', 'CL', 'DO', 'EC', 'GT', 'HN', 'NI', 'PA', 'PE', 'PY', 'SV', 'UY'];
    } else {
      subCountriesSorted = sub.paises.map(function(c) { 
        var iso = getISO(c);
        if (iso === 'CH') iso = 'CL';
        if (iso === 'RD') iso = 'DO';
        return iso;
      }).sort();
    }
  } else {
    subCountriesSorted = Object.keys(countriesSet).map(function(c) {
      var iso = getISO(c);
      if (iso === 'CH') iso = 'CL';
      if (iso === 'RD') iso = 'DO';
      return iso;
    }).filter(function(item, pos, self) { return self.indexOf(item) === pos; }).sort();
    if (subCountriesSorted.length === 0) {
      subCountriesSorted = ['AR', 'BO', 'CL', 'DO', 'EC', 'GT', 'HN', 'NI', 'PA', 'PE', 'PY', 'SV', 'UY'];
    }
  }

  var countsMap = {}, maxInRowMap = {};
  alertas.forEach(function(a) {
    var rawCc = String(a.pais || '').split('_')[0].toUpperCase();
    var cc = getISO(rawCc);
    if (cc === 'CH') cc = 'CL';
    if (cc === 'RD') cc = 'DO';

    var mKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
    var mLabel = a.metricaLabel;

    if (!countsMap[mKey]) countsMap[mKey] = {};
    if (!countsMap[mKey][cc]) countsMap[mKey][cc] = { baja: 0, debajo: 0, total: 0 };
    if (!countsMap[mLabel]) countsMap[mLabel] = {};
    if (!countsMap[mLabel][cc]) countsMap[mLabel][cc] = { baja: 0, debajo: 0, total: 0 };

    var details = String(a.detalles || '').toLowerCase();
    var isBaja = (mKey === 'orders' && a.valorReal === 0) || details.search(/ca[íi]da|desv[íi]o|aumento/) !== -1;
    var isDebajo = (details.search(/debajo|bajo|cr[ií]tico|arriba|target|absoluto/) !== -1);
    if (!isBaja && !isDebajo) isDebajo = true; // Garantizar que toda alerta detectada contabilice
    
    if (isBaja) {
      countsMap[mKey][cc].baja++;
      countsMap[mLabel][cc].baja++;
    }
    if (isDebajo) {
      countsMap[mKey][cc].debajo++;
      countsMap[mLabel][cc].debajo++;
    }
    countsMap[mKey][cc].total = countsMap[mKey][cc].baja + countsMap[mKey][cc].debajo;
    if (countsMap[mKey][cc].total === 0) countsMap[mKey][cc].total = 1;
    countsMap[mLabel][cc].total = countsMap[mKey][cc].total;

    if (!maxInRowMap[mKey] || countsMap[mKey][cc].total > maxInRowMap[mKey]) maxInRowMap[mKey] = countsMap[mKey][cc].total;
    if (!maxInRowMap[mLabel] || countsMap[mLabel][cc].total > maxInRowMap[mLabel]) maxInRowMap[mLabel] = countsMap[mLabel][cc].total;
  });

  var isRegional = sub && sub.paises && (sub.paises.indexOf("TODOS") !== -1 || sub.paises.indexOf("LATAM") !== -1);
  var summaryHtml = [];

  if (!isRegional) {
    var allowedMetrics = [
      'Confirmed Orders', 'GMV (EUR)', 'New Users', 'WIS %', 'WIS UF %',
      'Seamless Delivery %', 'Avg. Delivery Time', 'Assignment Time > 6 min %',
      'Weighted Open time %',
      'Assignment Time', 'Rejected Orders %',
      'HC Sessions orders %', 'Late Orders %', 'Slow Orders %',
      'Forced Preorders %', 'Modified Orders %'
    ];
    var subMetricsSorted = allowedMetrics.filter(function(m) {
      // 1. Mostrar si la métrica tiene una alerta activa en el lote
      if (metricsSet[m]) return true;
      
      // 2. Mostrar si es una de las métricas principales/obligatorias (Confirmed Orders, Seamless, WIS, Weighted Open time %) para no quedar vacías
      var isCore = (m === 'Confirmed Orders' || m === 'Seamless Delivery %' || m === 'WIS %' || m === 'Weighted Open time %');
      if (isCore) {
        var mKey = getMetricaKeyByLabel(m);
        var metricasSub = (sub && sub.metricas) ? sub.metricas : ['TODAS'];
        if (metricasSub.indexOf("TODAS") !== -1 || metricasSub.indexOf(mKey) !== -1) {
          return true;
        }
      }
      return false;
    });

    // 🟢 NUEVO: Garantizar que si o si haya al menos 5 métricas en el reporte de países
    if (subMetricsSorted.length < 5) {
      for (var i = 0; i < allowedMetrics.length; i++) {
        var m = allowedMetrics[i];
        if (subMetricsSorted.indexOf(m) === -1) {
          subMetricsSorted.push(m);
          if (subMetricsSorted.length >= 5) {
            break;
          }
        }
      }
    }

    // Reordenar las métricas seleccionadas para que sigan el orden oficial de las columnas
    subMetricsSorted.sort(function(a, b) {
      return allowedMetrics.indexOf(a) - allowedMetrics.indexOf(b);
    });
    var subWhsSorted = [];
    if (sub && sub.warehouses && sub.warehouses.length > 0 && sub.warehouses.indexOf('TODOS') === -1) {
      subWhsSorted = sub.warehouses.sort();
    } else {
      var sc = (sub && sub.paises && sub.paises.length > 0) ? sub.paises.filter(function(c) { return c !== 'TODOS' && c !== 'LATAM'; }) : subCountriesSorted;
      var allWarehouses = (_getMasterCountriesAndWarehouses().warehousesList || []);
      sc.forEach(function(cc) {
        var normalizedCc = getISO(cc);
        if (normalizedCc === 'CH') normalizedCc = 'CL';
        if (normalizedCc === 'RD') normalizedCc = 'DO';
        allWarehouses.forEach(function(wh) {
          var prefix = getISO(String(wh).split('_')[0]);
          if (prefix === 'CH') prefix = 'CL';
          if (prefix === 'RD') prefix = 'DO';
          if (prefix === normalizedCc) {
            subWhsSorted.push(wh);
          }
        });
      });

      // Incluir también cualquier warehouse de alertas que pertenezca al país suscrito
      alertas.forEach(function(a) {
        var aWh = String(a.pais || '').trim();
        if (aWh && subWhsSorted.indexOf(aWh) === -1) {
          var aPrefix = getISO(aWh.split('_')[0]);
          if (aPrefix === 'CH') aPrefix = 'CL';
          if (aPrefix === 'RD') aPrefix = 'DO';
          if (sc.some(function(cc) {
            var nCc = getISO(cc);
            if (nCc === 'CH') nCc = 'CL';
            if (nCc === 'RD') nCc = 'DO';
            return nCc === aPrefix;
          })) {
            subWhsSorted.push(aWh);
          }
        }
      });
      subWhsSorted.sort();
    }
    var colWidth = subMetricsSorted.length > 0 ? (70 / subMetricsSorted.length).toFixed(2) + '%' : '70%';
    var headers = ['<th class="th-main" style="width:30%">Warehouse / Local</th>'];
    subMetricsSorted.forEach(function(m) { headers.push('<th class="th-base" style="width:'+colWidth+'">'+m+'</th>'); });
    var rows = [];
    subWhsSorted.forEach(function(wh) {
      var r = ['<tr class="summary-tr"><td class="td-base td-whs" style="width:30%">'+wh+'</td>'];
      subMetricsSorted.forEach(function(m) {
        var mKey = getMetricaKeyByLabel(m);
        var alertObj = alertas.filter(function(a) { 
          var aKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
          return String(a.pais || '').trim().toUpperCase() === String(wh || '').trim().toUpperCase() && (a.metricaLabel === m || aKey === mKey); 
        })[0];
        
        var whCountry = getISO(String(wh).split('_')[0]);
        if (whCountry === 'CH') whCountry = 'CL';
        if (whCountry === 'RD') whCountry = 'DO';

        var unavailCountryList = dayAvail && dayAvail.unavailableByCountry ? (
          dayAvail.unavailableByCountry[whCountry] ||
          (whCountry === 'CL' ? dayAvail.unavailableByCountry['CH'] : null) ||
          (whCountry === 'DO' ? dayAvail.unavailableByCountry['RD'] : null)
        ) : null;

        var isMetricUnavail = dayAvail && (
          !dayAvail.hasAnyData ||
          (unavailCountryList && unavailCountryList.indexOf(mKey) !== -1) ||
          (dayAvail.unavailableGlobal && dayAvail.unavailableGlobal.indexOf(mKey) !== -1)
        );

        if (isMetricUnavail) {
          r.push('<td class="td-base" style="background-color:#090d16; color:#64748b; font-size:10px; width:'+colWidth+'; text-align:center;">—</td>');
          return;
        }

        if (!alertObj) { r.push('<td class="td-base td-ok" style="width:'+colWidth+'">✓</td>'); return; }
        var devText;
        if (alertObj.metricaLabel.toLowerCase().indexOf('%') !== -1) devText = ((alertObj.valorReal-alertObj.valorEsperado)*100).toFixed(1)+' pp';
        else if (alertObj.metricaLabel.toLowerCase().indexOf('time') !== -1) devText = (alertObj.valorReal-alertObj.valorEsperado).toFixed(1)+' min';
        else devText = (alertObj.valorEsperado>0?((alertObj.valorReal-alertObj.valorEsperado)/alertObj.valorEsperado)*100:0).toFixed(1)+'%';
        if (devText.indexOf('+')===-1&&parseFloat(devText)>=0) devText='+'+devText;
        
        var mKey = alertObj.metricaKey || getMetricaKeyByLabel(alertObj.metricaLabel);
        var isAlertClosed = (mKey === 'orders' && alertObj.valorReal === 0);
        if (isAlertClosed) devText = '[CERRADA]';
        
        // Diferenciar entre 'baja' y 'debajo' para los colores de las celdas del país
        var isBaja = isAlertClosed || String(alertObj.detalles).toLowerCase().search(/ca[íi]da|desv[íi]o|aumento/) !== -1;
        var badgeClass = isBaja ? 'badge-baja-country' : 'badge-debajo-country';
        
        // Incluir valores absolutos (Ayer vs Baseline) en la primera línea de la celda
        var absText = '<div style="font-size:10px; color:#334155; font-weight:bold; white-space:nowrap; margin-bottom:2px;">' + 
                      formatValMail(alertObj.valorReal, alertObj.metricaLabel) + 
                      ' <span style="font-size:8px; color:#64748b; font-weight:500;">vs ' + formatValMail(alertObj.valorEsperado, alertObj.metricaLabel) + '</span>' +
                      '</div>';
        
        var variationHtml = '<span class="' + badgeClass + '">' + devText + '</span>';
        
        var consecutiveHtml = '';
        if (alertObj.consecutiveDays && alertObj.consecutiveDays > 1) {
          var rachaLabel = alertObj.consecutiveDays + 'º día';
          if (alertObj.consecutiveDays === 2) rachaLabel = '2do día';
          else if (alertObj.consecutiveDays === 3) rachaLabel = '3er día';
          else if (alertObj.consecutiveDays === 4) rachaLabel = '4to día';
          else if (alertObj.consecutiveDays === 5) rachaLabel = '5to día';
          else if (alertObj.consecutiveDays === 6) rachaLabel = '6to día';
          else if (alertObj.consecutiveDays === 7) rachaLabel = '7mo día';
          else rachaLabel = alertObj.consecutiveDays + ' días';
          consecutiveHtml = '<div style="margin-top:3px;"><span class="badge-consecutive" style="background-color:#fffbeb; color:#b45309; border:1px solid #fde68a; font-size:8.5px; font-weight:700; padding:1px 4px; border-radius:6px; display:inline-block;">' + rachaLabel + '</span></div>';
        }
        
        r.push('<td class="td-base td-alert" style="padding: 6px 2px; vertical-align: middle; width:'+colWidth+'"><div class="alert-cell-content">' + absText + variationHtml + consecutiveHtml + '</div></td>');
      });
      rows.push(r.join('')+'</tr>');
    });
    var paises = (sub.paises||[]).filter(function(c){return c!=='TODOS'&&c!=='LATAM'});
    var titulo = paises.length>1?paises.map(function(c){return FULL_PAIS_NAMES[c]||c}).join(', '):(paises[0]?(FULL_PAIS_NAMES[paises[0]]||paises[0]):'Países Seleccionados');
    
    if (subMetricsSorted.length === 0) {
      summaryHtml.push(
        '<div class="summary-container" style="text-align: center; padding: 24px; background-color: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; margin-bottom: 18px;">' +
          '<div style="font-size: 16px; font-weight: bold; color: #15803d; font-family: sans-serif; margin-bottom: 4px;">[OK] ¡Todo en Orden!</div>' +
          '<div style="font-size: 12.5px; color: #166534; font-family: sans-serif; margin-top: 4px;">' +
            'No se registraron desvíos ni alertas de performance para ' + titulo + '.' +
          '</div>' +
        '</div>'
      );
    } else {
      summaryHtml.push(
        '<div class="summary-container">' +
          '<div class="summary-title-container"><span class="summary-title">Resumen de Desvíos para ' + titulo + '</span></div>' +
          '<div class="legend" style="margin-bottom:12px; font-size:10px; color:#475569; font-family:sans-serif; text-align:left;">' +
            '<span class="legend-item" style="margin-right:12px;"><strong><span class="badge-baja-country" style="margin-top:0; font-size:8.5px; padding:1px 4px; border-radius:3px;">▼ Baja</span>:</strong> Caída o Desvío</span>' +
            '<span><strong><span class="badge-debajo-country" style="margin-top:0; font-size:8.5px; padding:1px 4px; border-radius:3px;">↓ Debajo</span>:</strong> Fuera de límite</span>' +
          '</div>' +
          '<table class="summary-table"><thead><tr>' + headers.join('') + '</tr></thead><tbody>' + rows.join('') + '</tbody></table>' +
        '</div>'
      );
    }
  } else {
    var metricasSub = (sub && sub.metricas) ? sub.metricas : ['TODAS'];
    var allowedMetricsList = METRICS_TO_ALERT.filter(function(m) {
      return metricasSub.indexOf("TODAS") !== -1 || metricasSub.indexOf(m.key) !== -1;
    });
    var metrics = allowedMetricsList.map(function(m){return m.label});
    var colWidth = (72/(subCountriesSorted.length+1)).toFixed(2)+'%';
    var headers = ['<th class="th-main" style="width:28%">Métrica / Criterio</th>'];
    subCountriesSorted.forEach(function(c){headers.push('<th class="th-base" style="width:'+colWidth+'">'+c+'</th>')});
    headers.push('<th class="th-base th-total" style="width:'+colWidth+'">Total</th>');
    var rows = [];
    metrics.forEach(function(m){
      var mKey = getMetricaKeyByLabel(m);
      var isMetricUnavailGlobal = dayAvail && (
        !dayAvail.hasAnyData ||
        (dayAvail.unavailableGlobal && dayAvail.unavailableGlobal.indexOf(mKey) !== -1)
      );

      if (isMetricUnavailGlobal) {
        var r=['<tr class="summary-tr" style="background-color:#0b0f19;"><td class="td-metric-label" style="width:28%; background-color:#0b0f19;"><div class="metric-label-text" style="color:#64748b; text-decoration:line-through;">'+m+'</div><div class="metric-rule-text" style="color:#475569;">'+getMetricRuleDescriptionMail(m)+'</div></td>'];
        r.push('<td colspan="'+(subCountriesSorted.length+1)+'" class="td-base" style="background-color:#090d16; color:#94a3b8; font-size:10px; font-weight:bold; letter-spacing:0.5px; text-transform:uppercase; text-align:center;">MÉTRICA NO DISPONIBLE</td>');
        r.push('</tr>');
        rows.push(r.join(''));
        return;
      }

      var r=['<tr class="summary-tr"><td class="td-metric-label" style="width:28%"><div class="metric-label-text">'+m+'</div><div class="metric-rule-text">'+getMetricRuleDescriptionMail(m)+'</div></td>'];
      var rowTotal=0;
      subCountriesSorted.forEach(function(cc){
        var isCountryUnavail = dayAvail && dayAvail.unavailableByCountry && dayAvail.unavailableByCountry[cc] && dayAvail.unavailableByCountry[cc].indexOf(mKey) !== -1;
        if (isCountryUnavail) {
          r.push('<td class="td-base" style="background-color:#1e293b; color:#64748b; font-size:10px; width:'+colWidth+'; text-align:center;" title="Sin datos">—</td>');
          return;
        }

        var cMap = (countsMap[mKey] && countsMap[mKey][cc]) ? countsMap[mKey][cc] : (countsMap[m] ? countsMap[m][cc] : null);
        if (!cMap || cMap.total === 0) {
          r.push('<td class="td-base td-ok" style="width:'+colWidth+'">✓</td>');
          return;
        }
        rowTotal+=cMap.total;
        var bg='#fee2e2';
        var content=['<div class="alert-cell-content">'];
        if(cMap.baja>0)content.push('<span class="badge-baja">▼ '+cMap.baja+'</span>');
        if(cMap.debajo>0){if(cMap.baja>0)content.push('<br/>');content.push('<span class="badge-debajo">↓ '+cMap.debajo+'</span>')}
        content.push('</div>');
        r.push('<td class="td-base" style="background-color:'+bg+'; width:'+colWidth+'">'+content.join('')+'</td>');
      });
      r.push('<td class="td-base td-total" style="width:'+colWidth+'">'+rowTotal+'</td>');
      rows.push(r.join('')+'</tr>');
    });
    summaryHtml.push(
      '<div class="summary-container">' +
        '<div class="summary-title-container"><span class="summary-title">Resumen de Desvíos por Métrica</span></div>' +
        '<div class="legend" style="margin-bottom:8px; font-size:10px; color:#475569; font-family:sans-serif; text-align:left;">' +
          '<span class="legend-item" style="margin-right:12px;"><strong><span class="legend-icon-baja">▼</span> Baja:</strong> Caída o Desvío</span>' +
          '<span><strong><span class="legend-icon-debajo">↓</span> Debajo:</strong> Fuera de límite</span>' +
        '</div>' +
        '<div style="background-color: #f1f5f9; border-left: 3px solid #e50044; padding: 6px 10px; border-radius: 4px; margin-bottom: 12px; font-size: 10px; color: #475569; line-height: 1.3; font-family: sans-serif; text-align: left;">' +
          '💡 <strong>Nota:</strong> Si un local (WHS) presenta tanto una caída/desvío (<strong>▼ Baja</strong>) como un nivel fuera de límite (<strong>↓ Debajo</strong>), se contabilizará en ambas categorías (1 y 1) reflejando la doble criticidad del desvío sin duplicar el local.' +
        '</div>' +
        '<table class="summary-table"><thead><tr>'+headers.join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table>' +
      '</div>'
    );
  }
  
  var css='<style>body{margin:0;padding:0;background-color:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;color:#0f172a}.main-table{width:600px;border-collapse:collapse;background-color:#fff;border-radius:12px;border:1px solid #e2e8f0;overflow:hidden;box-shadow:0 4px 6px -1px rgba(0,0,0,.05)}.header{padding:20px 24px;background-color:#e50044}.header-brand{color:#fff;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;font-family:sans-serif}.header-title{color:#fff;font-size:20px;font-weight:900;margin-top:2px;font-family:sans-serif;white-space:nowrap}.header-button{background-color:#fff;color:#e50044;padding:8px 16px;border-radius:6px;font-size:11.5px;font-weight:700;text-decoration:none;display:inline-block;font-family:sans-serif;box-shadow:0 2px 4px rgba(0,0,0,.1);white-space:nowrap}.content{padding:24px}.summary-container{margin-bottom:18px;box-sizing:border-box}.summary-title-container{border-bottom:2px solid #cbd5e1;padding-bottom:4px;margin-bottom:12px;text-align:left}.summary-title{font-size:12px;font-weight:700;color:#0f172a;text-transform:uppercase;font-family:sans-serif;letter-spacing:.3px}.summary-table{width:100%;border-collapse:collapse;background-color:#fff;border:1px solid #cbd5e1;border-radius:8px;overflow:hidden;box-shadow:0 1px 2px rgba(0,0,0,.03)}.summary-tr{page-break-inside:avoid}.th-base{padding:10px 4px;text-align:center;font-size:10.5px;font-weight:700;color:#0f172a;border-bottom:2px solid #cbd5e1;font-family:sans-serif;background-color:#f1f5f9}.th-main{padding:10px 12px;text-align:left;font-size:11px;color:#475569}.th-total{background-color:#e2e8f0}.td-base{padding:10px 4px;border-bottom:1px solid #cbd5e1;text-align:center;vertical-align:middle;font-family:sans-serif;font-size:12px}.td-whs{padding:10px 12px;text-align:left;font-size:11.5px;font-weight:700;color:#0f172a}.td-ok{font-weight:700;color:#10b981;background-color:#f0fdf4}.td-alert{padding:6px 2px;background-color:#fee2e2}.alert-cell-content{display:block}.badge-dev{background-color:#fee2e2;color:#dc2626;border:1px solid rgba(220,38,38,.1);padding:3px 7px;border-radius:12px;font-size:9.5px;font-weight:700;display:inline-block;min-width:44px}.badge-consecutive{background-color:#fffbeb;color:#b45309;border:1px solid #fde68a;font-size:9px;font-weight:700;padding:1px 5px;border-radius:6px;display:inline-block}.badge-baja{background-color:#e11d48;color:#fff;font-size:8.5px;line-height:1.1;font-weight:900;padding:2px 5px;border-radius:4px;display:inline-block;width:28px;text-align:center}.badge-debajo{background-color:#b91c1c;color:#fff;font-size:8.5px;line-height:1.1;font-weight:900;padding:2px 5px;border-radius:4px;display:inline-block;width:28px;text-align:center}.legend{margin-top:12px;font-size:10px;color:#475569;font-family:sans-serif;text-align:center}.legend-item{display:inline-block;margin:0 8px}.legend-icon-baja{display:inline-block;width:14px;text-align:center;background-color:#e11d48;color:#fff;font-size:8px;padding:1px;border-radius:3px;margin-right:3px}.legend-icon-debajo{display:inline-block;width:14px;text-align:center;background-color:#b91c1c;color:#fff;font-size:8px;padding:1px;border-radius:3px;margin-right:3px}.pdf-card{margin:24px 0;padding:16px;background-color:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;text-align:center}.pdf-card-title{font-size:12px;font-weight:700;color:#0f172a;display:block}.pdf-card-body{font-size:11px;color:#475569;display:block;margin-top:2px}.cta-container{margin-top:24px;text-align:center}.cta-button{background-color:#e50044;color:#fff;padding:11px 22px;border-radius:6px;font-size:13px;font-weight:700;text-decoration:none;display:inline-block;box-shadow:0 4px 8px rgba(229,0,68,.2)}.sub-card{margin-top:24px;padding:16px;background-color:#f1f5f9;border-radius:8px;text-align:center}.sub-card-title{font-size:11px;font-weight:700;color:#0f172a;text-transform:uppercase;margin:0 0 4px}.sub-card-body{font-size:11px;color:#475569;margin:0 0 12px;padding:0 10%;line-height:1.4}.sub-card-button{background-color:#cbd5e1;color:#1f2937;padding:9px 18px;border-radius:6px;font-size:12px;font-weight:700;text-decoration:none;display:inline-block}.footer{padding:16px;background-color:#f8fafc;border-top:1px solid #e2e8f0;font-size:10px;color:#94a3b8;text-align:center;line-height:1.4}.td-metric-label{padding:10px 12px;border-bottom:1px solid #cbd5e1;text-align:left;vertical-align:middle;font-family:sans-serif}.metric-label-text{font-weight:700;font-size:11.5px;color:#0f172a}.metric-rule-text{font-size:9px;color:#64748b;margin-top:2px;font-style:italic;line-height:1.2}</style>';
  
  // Helper local para obtener el label amigable de una métrica
  function getMetricaLabelByKeyLocal(key) {
    var clean = String(key || '').trim().toLowerCase();
    if (typeof METRICS_TO_ALERT !== 'undefined') {
      for (var i = 0; i < METRICS_TO_ALERT.length; i++) {
        if (METRICS_TO_ALERT[i].key.toLowerCase() === clean) {
          return METRICS_TO_ALERT[i].label;
        }
      }
    }
    return key;
  }

  // Formatear los detalles de suscripción para el pie de página
  var subPaisesArr = (sub && sub.paises && sub.paises.length > 0) ? sub.paises : ['TODOS'];
  var subPaisesText = subPaisesArr.map(function(p) {
    if (p === 'TODOS') return 'Todos';
    if (p === 'LATAM') return 'LATAM';
    return FULL_PAIS_NAMES[p.toUpperCase()] || p.toUpperCase();
  }).join(', ');

  var subWhsArr = (sub && sub.warehouses && sub.warehouses.length > 0) ? sub.warehouses : ['TODOS'];
  var subWhsText = subWhsArr.map(function(w) {
    if (w === 'TODOS') return 'Todos';
    return w;
  }).join(', ');

  var subMetricasArr = (sub && sub.metricas && sub.metricas.length > 0) ? sub.metricas : ['TODAS'];
  var subMetricasText = subMetricasArr.map(function(m) {
    if (m === 'TODAS') return 'Todas';
    return getMetricaLabelByKeyLocal(m);
  }).join(', ');

  var html = [
    '<html><head>'+css+
    '<style>' +
    '  .badge-baja { background-color: #e11d48 !important; color: #ffffff !important; }' +
    '  .legend-icon-baja { background-color: #e11d48 !important; }' +
    '  .badge-debajo { background-color: #000000 !important; color: #ffffff !important; }' +
    '  .legend-icon-debajo { background-color: #000000 !important; }' +
    '  .badge-baja-country { background-color: #fee2e2; color: #dc2626; border: 1px solid #fca5a5; padding: 2px 5px; border-radius: 10px; font-size: 9px; font-weight: 700; display: inline-block; white-space: nowrap; margin-top: 3px; }' +
    '  .badge-debajo-country { background-color: #000000; color: #ffffff; border: 1px solid #000000; padding: 2px 5px; border-radius: 10px; font-size: 9px; font-weight: 700; display: inline-block; white-space: nowrap; margin-top: 3px; }' +
    '</style>' +
    '</head><body>',
    '<table align="center" width="100%" bgcolor="#f8fafc" style="padding:24px 10px"><tr><td align="center">',
    '<table class="main-table">',
    '<tr><td class="header"><table width="100%" border="0" cellpadding="0" cellspacing="0"><tr>',
    '<td width="70%" align="left" style="vertical-align:middle"><div class="header-brand">PeYa Markets</div><div class="header-title">Performance Alerts</div></td>',
    '<td width="30%" align="right" style="vertical-align:middle"><a href="'+scriptUrl+'?page=dashboard&src=alert-mail" style="background-color:#ffffff;color:#e50044;padding:8px 16px;border-radius:6px;font-size:11.5px;font-weight:700;text-decoration:none;display:inline-block;font-family:sans-serif;box-shadow:0 2px 4px rgba(0,0,0,.1);white-space:nowrap;">Entrar al reporte →</a></td>',
    '</tr></table></td></tr>',
    '<tr><td class="content">',
    summaryHtml.join(''),
    '<div class="pdf-card"><span class="pdf-card-title">📂 Detalle Técnico Adjunto (PDF)</span><span class="pdf-card-body">Hemos adjuntado un documento PDF con el desglose completo.</span></div>',
    '<div class="cta-container"><a href="'+scriptUrl+'?page=dashboard&src=alert-mail" style="background-color:#e50044;color:#ffffff;padding:11px 22px;border-radius:6px;font-size:13px;font-weight:700;text-decoration:none;display:inline-block;box-shadow:0 4px 8px rgba(229,0,68,.2);">🔍 Ir al Live Dashboard</a></div>',
    '<div class="sub-card"><h4 class="sub-card-title">⚙️ Preferencias de Suscripción</h4><p class="sub-card-body">Recibes este informe según tus intereses de monitoreo activos. Puedes modificarlos o desuscribirte cuando lo desees.</p><div style="margin-bottom:12px;"><a href="'+scriptUrl+'?page=subscriptions&src=alert-mail" style="background-color:#cbd5e1;color:#1f2937;padding:9px 18px;border-radius:6px;font-size:12px;font-weight:700;text-decoration:none;display:inline-block;">Modificar Mi Suscripción</a></div><div style="margin-top:14px; padding-top:12px; border-top:1px dashed #cbd5e1; font-size:11px; text-align:left; color:#475569; font-family:sans-serif; line-height:1.5;"><strong style="color:#1f2937;">Tu configuración actual:</strong><br/>• <strong>Países:</strong> ' + subPaisesText + '<br/>• <strong>Locales:</strong> ' + subWhsText + '<br/>• <strong>Métricas:</strong> ' + subMetricasText + '</div></div>',
    '</td></tr>',
    '<tr><td class="footer">Este correo es un reporte automático de desvíos críticos de PeYa Markets.</td></tr>',
    '</table></td></tr></table></body></html>'
  ];

  var isArray = Array.isArray(destinatario);
  var mode = getEmailSendingMode(); // 'PRODUCTION', 'TEST', or 'DISABLED'
  Logger.log("🛡️ [EmailSender] Modo de envío de correo detectado: " + mode);

  if (mode === 'DISABLED') {
    Logger.log("🚫 [EmailSender-DISABLED] El envío de correos está DESHABILITADO. Se omite el envío a: " + (isArray ? destinatario.join(', ') : destinatario));
    return;
  }

  var subjectStr = "PedidosYa Market - WHS Perfo. Alert | " + dateParts[2] + " de " + monthName + " de " + dateParts[0];
  
  if (mode === 'TEST') {
    subjectStr = "⚠️ [MODO PRUEBA] " + subjectStr;
    
    var banner = '<div style="background-color:#fee2e2; border:2px solid #ef4444; color:#991b1b; padding:16px; margin:20px auto; font-family:sans-serif; border-radius:8px; font-size:12.5px; max-width:600px; text-align:left; box-shadow:0 2px 4px rgba(0,0,0,0.05);">' +
                 '  <p style="margin:0 0 8px; font-weight:bold; font-size:14px;">⚠️ MODO DE PRUEBA / SEGURIDAD ACTIVO</p>' +
                 '  <p style="margin:0 0 8px; line-height:1.4;">Este es un correo simulado de forma regulada y segura para verificar el diseño y adjunto del reporte sin molestar a los destinatarios reales.</p>' +
                 '  <p style="margin:0; font-size:11px; color:#b91c1c;"><strong>Destinatarios originales en producción:</strong> ' + (isArray ? destinatario.join(', ') : destinatario) + '</p>' +
                 '</div>';
                 
    // Insertar el banner justo dentro de body
    // html[0] es '<html><head>'+css+'<style>...</style></head><body>'
    html.splice(1, 0, banner);
  }

  var pdfBlob = generarPdfDeDetalles(fechaCierre, alertas, FULL_PAIS_NAMES);

  var emailOptions = {
    name: 'PeYa Market Performance - Regional',
    subject: subjectStr,
    htmlBody: html.join(''),
    attachments: [pdfBlob]
  };

  if (mode === 'TEST') {
    // Redirigir el correo únicamente al usuario que ejecuta el script o a los administradores
    var currentUser = Session.getActiveUser().getEmail() || Session.getEffectiveUser().getEmail();
    var finalRecipient = (currentUser && currentUser.indexOf('@') !== -1) ? currentUser : ADMIN_USERS[0];
    
    emailOptions.to = finalRecipient;
    Logger.log("🛡️ [EmailSender-TEST] Correo de prueba desviado de forma segura a: " + finalRecipient);
  } else {
    // Modo PRODUCTION: Envío real
    if (isArray) {
      emailOptions.to = Session.getEffectiveUser().getEmail();
      emailOptions.bcc = destinatario.join(',');
      Logger.log("📬 [EmailSender-PRODUCTION] Enviando lote BCC a: " + emailOptions.bcc);
    } else {
      emailOptions.to = destinatario;
      Logger.log("📬 [EmailSender-PRODUCTION] Enviando correo individual a: " + emailOptions.to);
    }
  }

  MailApp.sendEmail(emailOptions);
}



/**
 * Genera un PDF premium con el reporte detallado de anomalías de performance de cada local.
 */
function generarPdfDeDetalles(fechaCierre, alertas, FULL_PAIS_NAMES, ayerStr, antesAyerStr) {
  var tableRowsHtml = "";
  var rowIdx = 0;
  
  // Helper local para obtener URL de la bandera del país
  function getFlagUrl(cc) {
    var code = String(cc).toLowerCase();
    var map = { 'ch': 'cl', 'rd': 'do' };
    var iso = map[code] || code;
    return 'https://flagcdn.com/w40/' + iso + '.png';
  }
  
  // Agrupar por Warehouse
  var agrupado = {};
  alertas.forEach(function(a) {
    if (!agrupado[a.pais]) agrupado[a.pais] = [];
    agrupado[a.pais].push(a);
  });
  
  // Ordenar de mayor cantidad de alertas a menor cantidad
  var whsListSorted = Object.keys(agrupado).sort(function(a, b) {
    return agrupado[b].length - agrupado[a].length;
  });
  
  whsListSorted.forEach(function(wh) {
    var subCountryCode = String(wh).split('_')[0].toUpperCase();
    var paisName = FULL_PAIS_NAMES[subCountryCode] || subCountryCode;
    var whAlerts = agrupado[wh];
    
    var isClosedWh = whAlerts.some(function(a) {
      var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
      return (metricKey === 'orders' && a.valorReal === 0);
    });
    
    var headerBg = isClosedWh ? 'background-color:#fee2e2;' : 'background-color:#f1f5f9;';
    var leftAccentColor = isClosedWh ? '#ef4444' : '#e50044';
    
    var flagImgHtml = '<img src="' + getFlagUrl(subCountryCode) + '" style="width:14px; height:10px; border-radius:2px; vertical-align:middle; margin-right:6px;" alt="' + subCountryCode + ' flag">';

    var whRain = null;
    for (var k = 0; k < whAlerts.length; k++) {
      if (whAlerts[k].lluvia_mm !== undefined && whAlerts[k].lluvia_mm !== null) {
        whRain = whAlerts[k].lluvia_mm;
        break;
      }
    }
    var rainBadgeHtml = '';
    if (whRain !== null && !isNaN(whRain)) {
      var val = parseFloat(whRain);
      if (val >= 0.1) {
        var rainTxt = (val >= 1.0) ? (Math.round(val * 10) / 10) + 'mm' : val.toFixed(1) + 'mm';
        rainBadgeHtml = '<span style="margin-left:8px; font-weight:bold; font-size:10.5px; color:#0284c7; font-family:sans-serif; vertical-align:middle;">🌧️ Lluvias: ' + rainTxt + '</span>';
      } else {
        rainBadgeHtml = '<span style="margin-left:8px; font-weight:normal; font-size:10px; color:#64748b; font-family:sans-serif; vertical-align:middle;">Lluvias: No</span>';
      }
    } else {
      rainBadgeHtml = '<span style="margin-left:8px; font-weight:normal; font-size:10px; color:#64748b; font-family:sans-serif; vertical-align:middle;">Lluvias: No</span>';
    }

    // Fila cabecera del Warehouse con letra un poco más chica y fondo premium, alineado con la página
    tableRowsHtml +=
      '<tr style="' + headerBg + '">' +
        '<td colspan="7" style="padding:8px 12px; text-align:left; font-weight:bold; border-left:4px solid ' + leftAccentColor + '; border-bottom:1px solid #cbd5e1; border-top:1px solid #cbd5e1; font-family:sans-serif; font-size:11px; color:#0f172a;">' +
          '<div style="display:inline-block; vertical-align:middle;">' +
            (isClosedWh ? '🔒 ' : '') + flagImgHtml + '🏢 ' + wh + ' (' + paisName + ')' +
            rainBadgeHtml +
          '</div>' +
          '<span style="float:right; font-size:9.5px; font-weight:bold; color:#64748b; background-color:#e2e8f0; padding:2px 6px; border-radius:10px; font-family:sans-serif;">' + 
            whAlerts.length + (whAlerts.length === 1 ? ' desvío' : ' desvíos') + 
          '</span>' +
        '</td>' +
      '</tr>';

    whAlerts.forEach(function(a) {
      rowIdx++;
      var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
      var computedDesvio = 0;
      var devText = "";
      var cleanLabel = a.metricaLabel.toLowerCase();

      if (cleanLabel.indexOf('%') !== -1) {
        computedDesvio = (a.valorReal - a.valorEsperado) * 100;
        var devStr = (computedDesvio > 0 ? '+' : '') + computedDesvio.toFixed(1);
        devText = devStr + ' pp';
      } else if (cleanLabel.indexOf('time') !== -1) {
        computedDesvio = a.valorReal - a.valorEsperado;
        var devStr = (computedDesvio > 0 ? '+' : '') + computedDesvio.toFixed(1);
        devText = devStr + ' min';
      } else {
        if (a.valorEsperado > 0) {
          computedDesvio = ((a.valorReal - a.valorEsperado) / a.valorEsperado) * 100;
        }
        var devStr = (computedDesvio > 0 ? '+' : '') + computedDesvio.toFixed(1);
        devText = devStr + '%';
      }

      var compareLabel = "AVG L3W";
      if (metricKey === 'wis' || metricKey === 'wis_uf' || metricKey === 'seamless') {
        compareLabel = "AVG 7D";
      }

      var alertRowBg = isClosedWh ? '#fff5f5' : (rowIdx % 2 === 0 ? '#ffffff' : '#f8fafc');
      
      // Colores de métrica pill exactos de la página
      var pillBg = '#f1f5f9';
      var pillColor = '#475569';
      if (metricKey === 'wis' || metricKey === 'wis_uf') {
        pillBg = '#eff6ff'; pillColor = '#1d4ed8';
      } else if (metricKey === 'orders' || metricKey === 'gmv' || metricKey === 'new_users') {
        pillBg = '#f0fdf4'; pillColor = '#15803d';
      } else if (metricKey === 'seamless') {
        pillBg = '#fdf2f8'; pillColor = '#be185d';
      } else if (metricKey === 'delivery_time' || metricKey === 'assignment_time') {
        pillBg = '#faf5ff'; pillColor = '#7e22ce';
      }
      
      var consecutiveCellHtml = '';
      if (a.consecutiveDays && a.consecutiveDays > 1) {
        var label = a.consecutiveDays + 'º día';
        if (a.consecutiveDays === 2) label = '2do día';
        else if (a.consecutiveDays === 3) label = '3er día';
        else if (a.consecutiveDays === 4) label = '4to día';
        else if (a.consecutiveDays === 5) label = '5to día';
        else if (a.consecutiveDays === 6) label = '6to día';
        else if (a.consecutiveDays === 7) label = '7mo día';
        else label = a.consecutiveDays + ' días';
        consecutiveCellHtml = '<span style="background-color:#fef3c7; color:#b45309; border:1px solid #fde68a; font-size:9.5px; font-weight:bold; padding:2px 6px; border-radius:8px; display:inline-block;">' + label + '</span>';
      } else {
        consecutiveCellHtml = '<span style="color:#64748b; font-size:9.5px; font-weight:600; padding-left:4px;">1er día</span>';
      }

      var isClosed = (metricKey === 'orders' && a.valorReal === 0);
      var devBadgeContent = isClosed ? '🔒 CERRADA' : devText;

      tableRowsHtml +=
        '<tr style="background-color:' + alertRowBg + '; page-break-inside: avoid;">' +
          // Col 1: Flechita de jerarquía
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; text-align:left; font-size:9.5px; color:#64748b; width:18%; font-family:sans-serif;">' +
            '<div style="padding-left:8px;">' +
              '<span style="font-size:11px; color:#e50044; font-weight:bold; margin-right:4px;">↳</span>' +
              'Desvío' +
            '</div>' +
          '</td>' +
          // Col 2: Métrica Pill
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; text-align:left; width:17%; font-family:sans-serif;">' +
            '<span style="background-color:' + pillBg + '; color:' + pillColor + '; font-size:9.5px; font-weight:bold; padding:2px 7px; border-radius:10px; display:inline-block; white-space:nowrap;">' +
              a.metricaLabel +
            '</span>' +
          '</td>' +
          // Col 3: Real
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; text-align:right; font-weight:bold; color:#0f172a; font-family:monospace; font-size:11px; width:11%;">' +
            formatValMail(a.valorReal, a.metricaLabel) +
          '</td>' +
          // Col 4: L3W / 7D
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; text-align:right; font-weight:600; color:#475569; font-family:monospace; font-size:10.5px; width:12%;">' +
            formatValMail(a.valorEsperado, a.metricaLabel) +
            '<span style="font-size:7.5px; color:#94a3b8; font-weight:bold; display:block; margin-top:2px;">' + compareLabel + '</span>' +
          '</td>' +
          // Col 5: Desvío Pill
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; text-align:center; width:11%; font-family:sans-serif;">' +
            '<span style="background-color:#fee2e2; color:#dc2626; border:1px solid rgba(220,38,38,0.1); padding:3px 7px; border-radius:12px; font-size:9.5px; font-weight:bold; display:inline-block; white-space:nowrap;">' +
              devBadgeContent +
            '</span>' +
          '</td>' +
          // Col 6: Consecutivo
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; text-align:center; width:11%; font-family:sans-serif;">' +
            consecutiveCellHtml +
          '</td>' +
          // Col 7: Detalles
          '<td style="padding:8px 12px; border-bottom:1px solid #cbd5e1; color:#475569; font-size:9.5px; line-height:1.3; text-align:left; width:20%; font-family:sans-serif;">' +
            a.detalles +
          '</td>' +
        '</tr>';
    });
  });

  var pdfHtml = 
    '<html>' +
    '<head>' +
      '<style>' +
        '@page { margin: 40px; }' +
        'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; color: #0f172a; margin: 0; padding: 0; }' +
        'table { width: 100%; border-collapse: collapse; margin-top: 15px; }' +
        'th { background-color: #0f172a; color: #ffffff; padding: 8px 12px; font-size: 8.5px; text-transform: uppercase; font-weight: bold; border-bottom: 3px solid #e50044; }' +
      '</style>' +
    '</head>' +
    '<body>' +
      '<div style="border-bottom: 2px solid #e50044; padding-bottom: 10px; margin-bottom: 15px;">' +
        '<div style="color: #e50044; font-size: 10px; font-weight: bold; text-transform: uppercase; letter-spacing: 0.5px; font-family:sans-serif;">Regional Performance Report - PeYa Markets</div>' +
        '<div style="font-size: 18px; font-weight: bold; margin-top: 2px; color: #0f172a; font-family:sans-serif;">Reporte Detallado de Performance por WHS</div>' +
        '<div style="font-size: 10px; color: #64748b; margin-top: 4px; font-family:sans-serif;">Fecha de Cierre de Alertas: <strong>' + fechaCierre + '</strong> | Formato PDF de alta legibilidad</div>' +
      '</div>' +
      
      '<table cellpadding="0" cellspacing="0" border="0">' +
        '<thead>' +
          '<tr>' +
            '<th style="text-align:left; width:18%;">Warehouse / Local</th>' +
            '<th style="text-align:left; width:17%;">Métrica</th>' +
            '<th style="text-align:right; width:11%;">Ayer (Real)</th>' +
            '<th style="text-align:right; width:12%;">L3W / 7D</th>' +
            '<th style="text-align:center; width:11%;">Desvío</th>' +
            '<th style="text-align:center; width:11%;">Consecutivo</th>' +
            '<th style="text-align:left; width:20%;">Detalles / Diagnóstico</th>' +
          '</tr>' +
        '</thead>' +
        '<tbody>' +
          tableRowsHtml +
        '</tbody>' +
      '</table>' +
      
      '<div style="margin-top: 30px; border-top: 1px solid #cbd5e1; padding-top: 10px; text-align: center; font-size: 8px; color: #94a3b8; page-break-inside: avoid; font-family:sans-serif;">' +
        'PedidosYa Markets regional performance alerts engine. Confidencial - Uso interno únicamente.' +
      '</div>' +
    '</body>' +
    '</html>';

  var blob = Utilities.newBlob(pdfHtml, 'text/html', 'Reporte_Detallado_WHS.html');
  return blob.getAs('application/pdf').setName('Reporte_Performance_Detallado_' + fechaCierre + '.pdf');
}


function testSendMyEmail() {
  var miEmail = Session.getActiveUser().getEmail();
  Logger.log("Enviando correo de prueba a: " + miEmail);
  
  // Alertas Mock de respaldo por si no hay desvíos reales ayer
  var alertasMock = [
    {
      pais: 'UY_10_Carrasco Norte',
      metricaKey: 'wis',
      metricaLabel: 'WIS %',
      valorReal: 0.745,
      valorEsperado: 0.818,
      desvio: -7.3,
      fecha: '2026-07-28',
      detalles: 'Caída de -7.3 pp vs baseline móvil de 7 días (WIS crítico < 80%)'
    },
    {
      pais: 'UY_10_Carrasco Norte',
      metricaKey: 'orders',
      metricaLabel: 'Confirmed Orders',
      valorReal: 840,
      valorEsperado: 1012,
      desvio: -17.0,
      fecha: '2026-07-28',
      detalles: 'Caída brusca de volumen de pedidos de -17.0% vs baseline L3W'
    },
    {
      pais: 'AR_15_Palermo Soho',
      metricaKey: 'forced_preorders',
      metricaLabel: 'Forced Preorders %',
      valorReal: 0.035,
      valorEsperado: 0.012,
      desvio: 191.7,
      fecha: '2026-07-28',
      detalles: 'Aumento crítico del ratio de forced preorders > 191.7% vs 7D'
    }
  ];
  
  try {
    // 1. Obtener la suscripción REAL del usuario desde la base de datos
    var realSub = getSubscriptionFromDb(miEmail);
    var subToUse = null;

    if (realSub && realSub.activo && realSub.paises && realSub.paises.length > 0) {
      Logger.log("✅ Usando tu suscripción real de la base de datos para la prueba.");
      subToUse = realSub;
      // Normalizar de forma proactiva los países de la suscripción a códigos ISO (ej: 'Rep. Dominicana' -> 'DO')
      subToUse.paises = subToUse.paises.map(function(c) { return getISO(c); });
    } else {
      Logger.log("ℹ️ No tienes una suscripción configurada o activa. Usando una suscripción simulada regional para la prueba.");
      subToUse = {
        paises: ['TODOS'],
        warehouses: ['TODOS'],
        metricas: ['TODAS'],
        activo: true
      };
    }

    // 2. Intentar calcular las alertas reales del último cierre en vivo
    Logger.log("Calculando alertas reales de ayer para el correo de prueba...");
    var resultadoReal = _analizarAnomaliasDeAyer();
    var alertasFinales = [];
    var fechaCierre = '2026-07-28'; // fecha por defecto

    if (resultadoReal && resultadoReal.alertas && resultadoReal.alertas.length > 0) {
      Logger.log("✅ ¡Se encontraron " + resultadoReal.alertas.length + " alertas reales! Usando datos reales del último cierre.");
      
      // Filtrar las alertas reales según la suscripción (igual que en el envío real)
      var alertasFiltradas = resultadoReal.alertas.filter(function(a) {
        var rawCc = String(a.pais || '').split('_')[0].toUpperCase();
        var subCountryCode = getISO(rawCc);
        if (subCountryCode === 'CH') subCountryCode = 'CL';
        if (subCountryCode === 'RD') subCountryCode = 'DO';
        
        // Comprobar coincidencia de país (si está suscrito a TODOS, a LATAM, o al país de la alerta)
        var paisOk = subToUse.paises.indexOf("TODOS") !== -1 || 
                     subToUse.paises.indexOf("LATAM") !== -1 || 
                     subToUse.paises.indexOf(subCountryCode) !== -1 ||
                     subToUse.paises.indexOf(rawCc) !== -1;

        // Comprobar coincidencia de warehouse (si está suscrito a TODOS, si el array está vacío, o al warehouse específico)
        var whUpper = String(a.pais || '').trim().toUpperCase();
        var warehousesSub = subToUse.warehouses || [];
        var whsOk = warehousesSub.length === 0 || 
                    warehousesSub.indexOf("TODOS") !== -1 || 
                    warehousesSub.some(function(w) { return String(w).trim().toUpperCase() === whUpper; });

        // Comprobar coincidencia de métrica
        var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
        var mKeyLower = String(metricKey || '').toLowerCase();
        var mLabelLower = String(a.metricaLabel || '').toLowerCase();
        var metricasSub = subToUse.metricas || [];
        var metricaOk = metricasSub.indexOf("TODAS") !== -1 || 
                        metricasSub.indexOf(mKeyLower) !== -1 || 
                        metricasSub.indexOf(mLabelLower) !== -1;

        return paisOk && whsOk && metricaOk;
      });

      if (alertasFiltradas.length > 0) {
        Logger.log("✅ ¡Hay " + alertasFiltradas.length + " alertas que coinciden con tus preferencias de suscripción!");
        alertasFinales = calcularYAgregarDiasConsecutivos(alertasFiltradas);
        fechaCierre = resultadoReal.yesterdayYMD;
      } else {
        Logger.log("ℹ️ No hay alertas reales de ayer que coincidan con tu suscripción actual. Usando alertas simuladas (Mock) de respaldo.");
        alertasFinales = alertasMock;
        // Si usamos el mock de respaldo, forzamos la suscripción simulada para que aparezcan
        subToUse = {
          paises: ['UY', 'AR'],
          warehouses: ['TODOS'],
          metricas: ['TODAS'],
          activo: true
        };
      }
    } else {
      Logger.log("ℹ️ No se detectaron alertas reales para ayer (cierre limpio). Usando alertas simuladas (Mock) de respaldo.");
      alertasFinales = alertasMock;
      subToUse = {
        paises: ['UY', 'AR'],
        warehouses: ['TODOS'],
        metricas: ['TODAS'],
        activo: true
      };
    }

    enviarNewsletterDeAlertas(miEmail, fechaCierre, alertasFinales, subToUse);
    Logger.log("✓ ¡Correo de prueba enviado con éxito! Revisa tu bandeja de entrada.");
  } catch(e) {
    Logger.log("❌ Error al enviar correo de prueba: " + (e.message || e));
  }
}

// =================================================================
// 💬 INTEGRACIÓN CON SLACK (Webhooks)
// =================================================================

/**
 * Envía el consolidado de alertas críticas de ayer directamente a un canal de Slack.
 * Requiere que se guarde la URL de Webhook de Slack en las Propiedades del Script bajo el nombre 'SLACK_WEBHOOK_URL'.
 */
function enviarAlertasDiariasASlack() {
  var slackWebhookUrl = "";
  try {
    slackWebhookUrl = PropertiesService.getScriptProperties().getProperty('SLACK_WEBHOOK_URL') || "";
  } catch(e) {}
  
  if (!slackWebhookUrl) {
    Logger.log("Advertencia: No se ha configurado la variable de entorno 'SLACK_WEBHOOK_URL' en Google Sheets.");
    return;
  }
  
  Logger.log("Calculando alertas de performance en vivo para Slack...");
  var res = _analizarAnomaliasDeAyer();
  if (!res || !res.alertas || res.alertas.length === 0) {
    Logger.log("No se encontraron anomalías en el cierre para enviar a Slack.");
    return;
  }
  
  var ultimaFecha = res.yesterdayYMD;
  var alertasHoy = calcularYAgregarDiasConsecutivos(res.alertas);
  
  // Construir bloques formateados estilo Block Kit de Slack
  var blocks = [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "⚠️ Alertas de Performance PeYa Markets — Cierre " + ultimaFecha,
        "emoji": true
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Se han detectado " + alertasHoy.length + " desvíos de rendimiento críticos en locales:* \nInspecciona los casos prioritarios a continuación."
      }
    },
    {
      "type": "divider"
    }
  ];
  
  // Agregar un máximo de 10 desvíos para no saturar Slack (truncar con enlace al live dashboard)
  var maxAlerts = Math.min(alertasHoy.length, 10);
  for (var i = 0; i < maxAlerts; i++) {
    var a = alertasHoy[i];
    var emo = a.desvio > 0 ? "📈" : "📉";
    if (a.metricaLabel.indexOf('WIS') !== -1 || a.metricaLabel.indexOf('Seamless') !== -1) emo = "❌";
    
    var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
    var labelEsperado = (metricKey === 'orders' || metricKey === 'gmv') ? "Esperado" : "Best Estimate";
    
    blocks.push({
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "• *Store:* `" + a.pais + "`\n• *Metrica:* `" + a.metricaLabel + "` (" + a.desvio.toFixed(1) + "%)\n• *Real:* " + formatValMail(a.valorReal, a.metricaLabel) + " | *" + labelEsperado + ":* " + formatValMail(a.valorEsperado, a.metricaLabel) + "\n• _Detalles:_ " + a.detalles
      }
    });
  }
  
  if (alertasHoy.length > 10) {
    blocks.push({
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "➕ _Y otros " + (alertasHoy.length - 10) + " desvíos críticos detectados..._"
      }
    });
  }
  
  var scriptUrl = "https://script.google.com/a/pedidosya.com/macros/s/AKfycbzZBZZlqHZpkAigzkZ7lr4Qs6LU3P2TgHL3pzQ1SFLneXhxlQ-h1vKtQl2orO1xtDcBMg/exec";
  
  if (scriptUrl) {
    blocks.push({
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {
            "type": "plain_text",
            "text": "🔍 Live Dashboard",
            "emoji": true
          },
          "value": "go_to_dashboard",
          "url": scriptUrl,
          "style": "primary"
        }
      ]
    });
  }
  
  var payload = JSON.stringify({ "blocks": blocks });
  
  var options = {
    "method": "post",
    "contentType": "application/json",
    "payload": payload,
    "muteHttpExceptions": true
  };
  
  var response = UrlFetchApp.fetch(slackWebhookUrl, options);
  Logger.log("Respuesta Slack Webhook: " + response.getContentText());
}

/**
 * FUNCIÓN DE PRUEBA DE SLACK:
 * Envía un bloque de demostración a tu canal para validar la integración.
 * ¡Asegúrate de guardar la propiedad 'SLACK_WEBHOOK_URL' antes de correrla!
 */
function testSendSlackAlert() {
  var slackWebhookUrl = "";
  try {
    slackWebhookUrl = PropertiesService.getScriptProperties().getProperty('SLACK_WEBHOOK_URL') || "";
  } catch(e) {}
  
  if (!slackWebhookUrl) {
    Logger.log("❌ Error: No se ha configurado la URL de Webhook de Slack en las Propiedades de Script con la clave 'SLACK_WEBHOOK_URL'.");
    return;
  }
  
  var payload = JSON.stringify({
    "text": "🔔 *Test de Integración exitoso:* El motor de Performance Alerts está conectado correctamente al Workspace de Slack de PeYa Markets."
  });
  
  var options = {
    "method": "post",
    "contentType": "application/json",
    "payload": payload
  };
  
  try {
    UrlFetchApp.fetch(slackWebhookUrl, options);
    Logger.log("✓ ¡Alerta de demostración enviada con éxito a Slack!");
  } catch(e) {
    Logger.log("❌ Error al enviar alerta a Slack: " + (e.message || e));
  }
}

/**
 * 🔒 SISTEMA DE ENVÍO DE ALERTAS POR SLACK PRIVADO (Direct Messages - DM)
 * Busca a cada usuario de la base de datos de suscripciones por email en Slack,
 * filtra los desvíos críticos personalizados de ayer y le envía un DM de forma automatizada.
 */
function enviarAlertasDiariasASlackPrivado() {
  var botToken = "";
  try {
    botToken = PropertiesService.getScriptProperties().getProperty('SLACK_BOT_TOKEN') || "";
  } catch(e) {}
  
  if (!botToken) {
    Logger.log("Error: No se ha configurado la variable de entorno 'SLACK_BOT_TOKEN' en las propiedades del script.");
    return;
  }
  
  Logger.log("Calculando alertas de performance en vivo para DMs privados de Slack...");
  var res = _analizarAnomaliasDeAyer();
  if (!res || !res.alertas || res.alertas.length === 0) {
    Logger.log("No se encontraron anomalías en el cierre para enviar por DM.");
    return;
  }
  
  var ultimaFecha = res.yesterdayYMD;
  var alertasHoy = calcularYAgregarDiasConsecutivos(res.alertas);
  
  var suscripciones = getSubscriptionsFromDb();
  
  suscripciones.forEach(function(sub) {
    if (!sub.activo || !sub.email) return;
    
    // Normalizar de forma proactiva los países de la suscripción a códigos ISO (ej: 'Rep. Dominicana' -> 'DO')
    if (sub.paises && sub.paises.length > 0) {
      sub.paises = sub.paises.map(function(c) { return getISO(c); });
    }
    
    // 1. Filtrar las alertas según la suscripción del usuario
    var subAlertas = alertasHoy.filter(function(a) {
      var rawCc = String(a.pais || '').split('_')[0].toUpperCase();
      var subCountryCode = getISO(rawCc);
      if (subCountryCode === 'CH') subCountryCode = 'CL';
      if (subCountryCode === 'RD') subCountryCode = 'DO';
      var paisCoincide = sub.paises.indexOf('TODOS') !== -1 || 
                         sub.paises.indexOf('LATAM') !== -1 || 
                         sub.paises.indexOf(subCountryCode) !== -1 || 
                         sub.paises.indexOf(rawCc) !== -1 ||
                         sub.paises.indexOf(a.pais) !== -1;
      var metricaCoincide = sub.metricas.indexOf('TODAS') !== -1 || sub.metricas.indexOf(a.metricaKey) !== -1;
      return paisCoincide && metricaCoincide;
    });
    
    if (subAlertas.length === 0) return; // Nada que enviar a este usuario
    
    // 2. Obtener el Slack User ID por Email
    var slackUserId = obtenerSlackUserIdPorEmail(sub.email, botToken);
    if (!slackUserId) {
      Logger.log("No se encontró el Slack ID para el email: " + sub.email);
      return;
    }
    
    // 3. Construir bloques de Slack Block Kit personalizados para el DM privado
    var blocks = [
      {
        "type": "header",
        "text": {
          "type": "plain_text",
          "text": "⚠️ Desvíos Críticos de Performance — Cierre " + ultimaFecha,
          "emoji": true
        }
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "Hola! He detectado * " + subAlertas.length + " desvíos de rendimiento críticos* de acuerdo con tus preferencias de suscripción activa:"
        }
      },
      {
        "type": "divider"
      }
    ];
    
    var maxAlerts = Math.min(subAlertas.length, 10);
    for (var i = 0; i < maxAlerts; i++) {
      var a = subAlertas[i];
      var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
      var labelEsperado = (metricKey === 'orders' || metricKey === 'gmv') ? "Esperado" : "Best Estimate";
      
      blocks.push({
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "• *Store:* `" + a.pais + "`\n• *Metrica:* `" + a.metricaLabel + "` (" + a.desvio.toFixed(1) + "%)\n• *Real:* " + formatValMail(a.valorReal, a.metricaLabel) + " | *Esperado:* " + formatValMail(a.valorEsperado, a.metricaLabel) + "\n• _Detalles:_ " + a.detalles
        }
      });
    }
    
    if (subAlertas.length > 10) {
      blocks.push({
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "➕ _Y otros " + (subAlertas.length - 10) + " desvíos críticos detectados..._"
        }
      });
    }
    
    var scriptUrl = "";
    try { scriptUrl = ScriptApp.getService().getUrl(); } catch(e) {}
    
    if (scriptUrl) {
      blocks.push({
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": "🔍 Live Dashboard",
              "emoji": true
            },
            "url": scriptUrl,
            "style": "primary"
          }
        ]
      });
    }
    
    // 4. Enviar el DM privado por Slack
    enviarMensajeSlackBlockKit(slackUserId, blocks, botToken);
    Logger.log("✓ DM enviado con éxito a: " + sub.email);
  });
}

function obtenerSlackUserIdPorEmail(email, token) {
  var url = "https://slack.com/api/users.lookupByEmail?email=" + encodeURIComponent(email);
  var options = {
    "method": "get",
    "headers": {
      "Authorization": "Bearer " + token
    },
    "muteHttpExceptions": true
  };
  
  try {
    var response = UrlFetchApp.fetch(url, options);
    var res = JSON.parse(response.getContentText());
    if (res.ok && res.user) {
      return res.user.id;
    }
  } catch(e) {
    Logger.log("Error buscando ID de Slack por email (" + email + "): " + e);
  }
  return null;
}

function enviarMensajeSlackBlockKit(channelId, blocks, token) {
  var url = "https://slack.com/api/chat.postMessage";
  var payload = JSON.stringify({
    "channel": channelId,
    "blocks": blocks
  });
  
  var options = {
    "method": "post",
    "contentType": "application/json",
    "headers": {
      "Authorization": "Bearer " + token
    },
    "payload": payload,
    "muteHttpExceptions": true
  };
  
  try {
    var response = UrlFetchApp.fetch(url, options);
    var res = JSON.parse(response.getContentText());
    if (!res.ok) {
      Logger.log("Error enviando mensaje Slack Block Kit: " + res.error);
    }
  } catch(e) {
    Logger.log("Error conectando a chat.postMessage: " + e);
  }
}

// Helpers locales para formatear strings de forma idéntica
function formatValMail(v, label) {
  if (v == null || isNaN(v)) return '—';
  if (label.indexOf('%') !== -1) return (v * 100).toFixed(1) + '%';
  if (label.indexOf('Time') !== -1) return v.toFixed(1) + ' min';
  if (label.indexOf('GMV') !== -1) {
    if (v >= 1000000) return (v / 1000000).toFixed(2) + 'M €';
    if (v >= 1000) return (v / 1000).toFixed(1) + 'k €';
    return v.toFixed(2) + ' €';
  }
  return Math.round(v).toLocaleString('es-AR');
}

/**
 * Helper de servidor para traducir de forma segura etiquetas visibles a claves de programación (metricaKey).
 * Resuelve desajustes cuando los desvíos se cargan desde el historial de Sheets.
 */
function getMetricaKeyByLabel(label) {
  var clean = String(label || '').trim().toLowerCase();
  
  // Buscar en el diccionario maestro global METRICS_TO_ALERT de Code.gs
  if (typeof METRICS_TO_ALERT !== 'undefined') {
    for (var i = 0; i < METRICS_TO_ALERT.length; i++) {
      if (METRICS_TO_ALERT[i].label.toLowerCase() === clean || METRICS_TO_ALERT[i].key.toLowerCase() === clean) {
        return METRICS_TO_ALERT[i].key;
      }
    }
  }
  
  // Fallbacks alternativos
  if (clean.indexOf('wis %') !== -1 || clean === 'wis') return 'wis';
  if (clean.indexOf('wis uf %') !== -1 || clean === 'wis_uf') return 'wis_uf';
  if (clean.indexOf('seamless') !== -1) return 'seamless';
  if (clean.indexOf('confirmed orders') !== -1 || clean === 'orders') return 'orders';
  if (clean.indexOf('gmv') !== -1) return 'gmv';
  if (clean.indexOf('new users') !== -1 || clean === 'new_users') return 'new_users';
  if (clean.indexOf('delivery time') !== -1) return 'delivery_time';
  if (clean.indexOf('6 min') !== -1 || clean.indexOf('saturation') !== -1) return 'assignment_time_over_6m';
  if (clean.indexOf('assignment time') !== -1) return 'assignment_time';
  if (clean.indexOf('rejected') !== -1) return 'rejected_orders';
  if (clean.indexOf('sessions') !== -1) return 'session_orders';
  if (clean.indexOf('late orders') !== -1) return 'late_orders';
  if (clean.indexOf('slow orders') !== -1) return 'slow_orders';
  if (clean.indexOf('forced preorders') !== -1) return 'forced_preorders';
  if (clean.indexOf('modified orders') !== -1) return 'modified_orders';
  if (clean.indexOf('open time') !== -1 || clean.indexOf('open_time') !== -1 || clean.indexOf('wot') !== -1) return 'open_time';
  return '';
}

function buildSingleWarehouseCardHtml(wh, whAlerts, ayerStr, FULL_PAIS_NAMES) {
  var subCountryCode = String(wh).split('_')[0].toUpperCase();
  var paisName = FULL_PAIS_NAMES[subCountryCode] || subCountryCode;
  
  // Detectar si la tienda está cerrada
  var isClosed = false;
  whAlerts.forEach(function(a) {
    var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
    if (metricKey === 'orders' && a.valorReal === 0) {
      isClosed = true;
    }
  });
  
  var borderColors = {
    'AR': '#74acdf', 'UY': '#0038a8', 'CL': '#d52b1e', 'CH': '#d52b1e',
    'BO': '#f43f5e', 'EC': '#eab308', 'PE': '#ef4444', 'DO': '#002f6c', 'RD': '#002f6c'
  };
  var bColor = borderColors[subCountryCode] || '#cbd5e1';
  
  var problemsHtml = "";
  whAlerts.forEach(function(a) {
    // Calcular desvío dinámicamente en base a los valores absolutos
    var computedDesvio = 0;
    var devText = "";
    
    var cleanLabel = a.metricaLabel.toLowerCase();
    if (cleanLabel.indexOf('%') !== -1) {
      computedDesvio = (a.valorReal - a.valorEsperado) * 100;
      var devStr = (computedDesvio > 0 ? '+' : '') + computedDesvio.toFixed(1);
      devText = devStr + ' pp';
    } else if (cleanLabel.indexOf('time') !== -1) {
      computedDesvio = a.valorReal - a.valorEsperado;
      var devStr = (computedDesvio > 0 ? '+' : '') + computedDesvio.toFixed(1);
      devText = devStr + ' min';
    } else {
      if (a.valorEsperado > 0) {
        computedDesvio = ((a.valorReal - a.valorEsperado) / a.valorEsperado) * 100;
      }
      var devStr = (computedDesvio > 0 ? '+' : '') + computedDesvio.toFixed(1);
      devText = devStr + '%';
    }
    
    var metricKey = a.metricaKey || getMetricaKeyByLabel(a.metricaLabel);
    var compareLabel = "AVG 7D";
    if (metricKey === 'orders' || metricKey === 'gmv' || metricKey === 'new_users' || metricKey === 'delivery_time' || metricKey === 'assignment_time') {
      compareLabel = "AVG L3W";
    }
    
    var consecutiveBadge = '';
    if (a.consecutiveDays && a.consecutiveDays > 1) {
      var label = a.consecutiveDays + 'º día';
      if (a.consecutiveDays === 2) label = '2do día';
      else if (a.consecutiveDays === 3) label = '3er día';
      else if (a.consecutiveDays === 4) label = '4to día';
      else if (a.consecutiveDays === 5) label = '5to día';
      else if (a.consecutiveDays === 6) label = '6to día';
      else if (a.consecutiveDays === 7) label = '7mo día';
      else label = a.consecutiveDays + ' días';
      consecutiveBadge = '<span style="background-color:#fef3c7; color:#b45309; border:1px solid #fde68a; font-size:10px; font-weight:bold; padding:2px 6px; border-radius:6px; display:inline-block; margin-left:6px; vertical-align:middle;">' + label + '</span>';
    }
    
    problemsHtml += 
      '<div style="margin-bottom:12px; padding:10px 14px; background-color:#ffffff; border-left:4px solid #e11d48; border-radius:4px; border-bottom:1px solid #f1f5f9; text-align:left;">' +
        '<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">' +
          '<div style="display:flex; align-items:center;">' +
            '<span style="font-size:13px; font-weight:bold; color:#0f172a; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:140px; display:inline-block; vertical-align:middle;">' + a.metricaLabel + '</span>' +
            consecutiveBadge +
          '</div>' +
          '<span style="font-size:11px; font-weight:bold; color:#e11d48; background-color:#fff1f2; padding:2px 8px; border-radius:12px;">' + devText + '</span>' +
        '</div>' +
        
        '<table width="100%" style="border-collapse:collapse; background-color:#f8fafc; border-radius:6px; margin:6px 0 4px; border:1px solid #e2e8f0; font-size:11px;">' +
          '<tr>' +
            '<td style="padding:6px 12px; color:#64748b; font-weight:bold; text-transform:uppercase; font-size:9.5px;">' + ayerStr + ' (Valor de Ayer)</td>' +
            '<td style="padding:6px 12px; font-weight:bold; color:#0f172a; text-align:right;">' + formatValMail(a.valorReal, a.metricaLabel) + '</td>' +
          '</tr>' +
          '<tr style="border-top:1px solid #e2e8f0;">' +
            '<td style="padding:6px 12px; color:#64748b; font-weight:bold; text-transform:uppercase; font-size:9.5px;">Comparación vs ' + compareLabel + '</td>' +
            '<td style="padding:6px 12px; font-weight:bold; color:#475569; text-align:right;">' + formatValMail(a.valorEsperado, a.metricaLabel) + '</td>' +
          '</tr>' +
        '</table>' +
        
        '<div style="font-size:11px; font-style:italic; color:#94a3b8; line-height:1.2; margin-top:4px;">' + a.detalles + '</div>' +
      '</div>';
  });
  
  var whRain = null;
  for (var k = 0; k < whAlerts.length; k++) {
    if (whAlerts[k].lluvia_mm !== undefined && whAlerts[k].lluvia_mm !== null) {
      whRain = whAlerts[k].lluvia_mm;
      break;
    }
  }
  var rainBadgeCardHtml = '';
  if (whRain !== null && !isNaN(whRain) && parseFloat(whRain) >= 0.1) {
    var val = parseFloat(whRain);
    var rainTxt = (val >= 1.0) ? (Math.round(val * 10) / 10) + 'mm' : val.toFixed(1) + 'mm';
    rainBadgeCardHtml = '<span style="margin-left:6px; font-weight:bold; font-size:10px; color:#0284c7; font-family:sans-serif; vertical-align:middle;">🌧️ Lluvias: ' + rainTxt + '</span>';
  } else {
    rainBadgeCardHtml = '<span style="margin-left:6px; font-weight:normal; font-size:10px; color:#64748b; font-family:sans-serif; vertical-align:middle;">Lluvias: No</span>';
  }
  
  return (
    '<div style="background-color:' + (isClosed ? '#fff5f5' : '#ffffff') + '; border:1px solid ' + (isClosed ? '#fca5a5' : '#e2e8f0') + '; border-radius:10px; box-shadow:0 1px 3px rgba(0,0,0,0.05); overflow:hidden; text-align:left; box-sizing:border-box; margin-bottom:12px;">' +
      '<div style="height:6px; background-color:' + bColor + ';"></div>' +
      '<div style="padding:16px;">' +
        '<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">' +
          '<div style="max-width:210px; overflow:hidden;">' +
            '<h3 style="margin:0; font-size:15px; font-weight:800; color:#0f172a; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">' + (isClosed ? '🔒 ' : '') + wh + '</h3>' +
            '<div style="margin-top:2px; display:flex; align-items:center;">' +
              '<span style="font-size:11px; color:#94a3b8; font-weight:bold;">' + paisName + '</span>' +
              rainBadgeCardHtml +
            '</div>' +
          '</div>' +
          '<div style="text-align:right; flex-shrink:0;">' +
            '<span style="font-size:10px; font-weight:bold; background-color:#eff6ff; color:#2563eb; padding:2px 8px; border-radius:4px; border:1px solid #dbeafe; display:inline-block;">' + subCountryCode + '</span>' +
            (isClosed ? '<div style="margin-top:4px;"><span style="font-size:8.5px; font-weight:bold; background-color:#fee2e2; color:#ef4444; border:1px solid #fca5a5; padding:1.5px 5px; border-radius:4px; text-transform:uppercase; letter-spacing:0.3px;">Cerrada</span></div>' : '') +
          '</div>' +
        '</div>' +
        '<div>' + problemsHtml + '</div>' +
      '</div>' +
    '</div>'
  );
}

/**
 * Fuerza la ejecución del envío de correos de forma manual.
 * Esta función se puede ejecutar directamente desde el editor de Apps Script.
 */
function forzarEnvioDeCorreos() {
  Logger.log('Iniciando envío manual forzado de correos...');
  
  var resultado = _analizarAnomaliasDeAyer();
  
  if (!resultado || !resultado.alertas || resultado.alertas.length === 0) {
    Logger.log('No se encontraron anomalías para el día ' + (resultado ? resultado.yesterdayYMD : 'reciente') + '. No se enviarán correos.');
    Browser.msgBox('No se encontraron alertas para enviar por correo.');
    return;
  }
  
  // Es importante calcular los días consecutivos para que la información del correo sea correcta.
  var alertasConConsecutivos = calcularYAgregarDiasConsecutivos(resultado.alertas);
  
  Logger.log('Se encontraron ' + alertasConConsecutivos.length + ' alertas. Guardando en DB y procediendo a enviar correos...');
  saveAlertsToDb(alertasConConsecutivos, resultado.yesterdayYMD);
  
  _enviarCorreosBasadosEnSuscripciones(alertasConConsecutivos, resultado.yesterdayYMD, true);
  
  Logger.log('¡Envío manual de correos completado!');
  Browser.msgBox('Se ha completado el proceso de envío de correos para las ' + alertasConConsecutivos.length + ' alertas del día ' + resultado.yesterdayYMD + '.');
}

// =================================================================
// SENSOR DE TIEMPO / CRON PARA DISPARO DE ALERTAS (1 MINUTO)
// =================================================================
// Este bloque permite ejecutar el envío de alertas con precisión horaria
// usando un activador (trigger) de Google Apps Script que corre cada 1 minuto.
// =================================================================

// ── CONFIGURACIÓN DE HORARIO DE DISPARO (Ajustá esto según tu necesidad) ──
var HORA_DISPARO = 11;       // Hora en la que se debe enviar (formato 24hs, ej: 11 = 11:00 AM)
var MINUTO_INICIO = 0;       // Minuto de inicio del rango (ej: 0 = 11:00 AM)
var MINUTO_FIN = 9;          // Minuto de fin del rango (compatible con trigger de cada 5 minutos)

/**
 * Función principal que debés configurar en tu trigger de Apps Script para que corra cada 1 minuto.
 * Verifica si la hora actual está dentro del rango y si no se ha ejecutado hoy todavía.
 */
function verificarYEjecutarEnvioDiario() {
  var tz = Session.getScriptTimeZone();
  var ahora = new Date();
  
  // Obtener la fecha, hora y minutos actuales formateados según la zona horaria del script (Buenos Aires)
  var fechaHoyStr = Utilities.formatDate(ahora, tz, "yyyy-MM-dd");
  var horaActual = parseInt(Utilities.formatDate(ahora, tz, "H"), 10);
  var minutoActual = parseInt(Utilities.formatDate(ahora, tz, "m"), 10);
  
  Logger.log("[Scheduler] Evaluando trigger de las " + horaActual + ":" + (minutoActual < 10 ? "0" : "") + minutoActual + " (" + fechaHoyStr + ")");
  
  // 1. Verificar si estamos en la hora y el rango de minutos correctos
  var horaCorrecta = (horaActual === HORA_DISPARO);
  var minutosEnRango = (minutoActual >= MINUTO_INICIO && minutoActual <= MINUTO_FIN);
  
  if (!horaCorrecta || !minutosEnRango) {
    Logger.log("[Scheduler] Fuera del rango programado (" + HORA_DISPARO + ":" + MINUTO_INICIO + " a " + HORA_DISPARO + ":" + MINUTO_FIN + "). Omitiendo.");
    return;
  }
  
  // 2. Evitar ejecuciones duplicadas dentro del mismo día
  var properties = PropertiesService.getScriptProperties();
  var ultimaFechaEjecutada = properties.getProperty("LAST_RUN_DATE_TRIGGER");
  
  if (ultimaFechaEjecutada === fechaHoyStr) {
    Logger.log("[Scheduler] Ya se ejecutó y envió el reporte de alertas hoy (" + fechaHoyStr + "). Omitiendo para evitar duplicados.");
    return;
  }
  
  // 3. Validar si la planilla de datos (WHS all Data) ya tiene una fecha nueva no enviada previamente
  var latestDataDate = null;
  try {
    var actSheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_ACTUALS);
    var lastCol = actSheet.getLastColumn();
    var headers = lastCol > 0 ? actSheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];
    var dateColIdx = headers.indexOf('fecha');
    if (dateColIdx === -1) dateColIdx = headers.indexOf('date');
    
    if (dateColIdx !== -1) {
      var rawTopDate = actSheet.getRange(2, dateColIdx + 1, 1, 1).getValue();
      latestDataDate = normalizeDateToYMD(rawTopDate);
      var ultimaFechaEnviada = properties.getProperty("LAST_SENT_DATA_DATE");
      
      if (latestDataDate && latestDataDate === ultimaFechaEnviada) {
        Logger.log("[Scheduler] [INFO] No hay nueva fecha en Sheets. La fecha más reciente en WHS all Data es " + latestDataDate + " y ya fue enviada previamente. Se pospone el envío a la espera de la carga diaria de datos.");
        return;
      }
    }
  } catch(e) {
    Logger.log("[Scheduler] [WARN] No se pudo verificar la última fecha de Sheets: " + e.message + ". Continuando...");
  }
  
  // 4. Ejecutar el envío a través de la función única y canónica
  Logger.log("[Scheduler] ¡Hora, rango y datos válidos! Iniciando proceso a través de enviarReporteDiario10AM...");
  
  try {
    enviarReporteDiario10AM(false);
    if (latestDataDate) {
      properties.setProperty("LAST_SENT_DATA_DATE", latestDataDate);
    }
    Logger.log("[Scheduler] ¡Proceso diario finalizado con éxito para la fecha " + fechaHoyStr + " con datos de " + (latestDataDate || 'ayer') + "!");
  } catch (error) {
    Logger.log("[Scheduler] [ERROR CRÍTICO] durante la ejecución: " + error.toString());
  }
}

/**
 * Función de utilidad para forzar un reinicio del scheduler.
 * Permite volver a disparar el trigger hoy si es necesario para pruebas.
 */
function resetearSchedulerDeHoy() {
  var properties = PropertiesService.getScriptProperties();
  properties.deleteProperty("LAST_RUN_DATE_TRIGGER");
  Logger.log("[Scheduler] Se ha reiniciado la marca de tiempo. El trigger podrá volver a ejecutarse hoy.");
}
