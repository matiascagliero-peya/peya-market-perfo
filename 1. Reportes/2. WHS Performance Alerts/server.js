const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8089;
const DIR = __dirname;

function resolveTemplate(html) {
  let content = html.replace(/<\?!=\s*include\(['"]([^'"]+)['"](?:,\s*\{[^}]*\})?\);?\s*\?>/g, (match, filename) => {
    const candidates = [
      path.join(DIR, filename),
      path.join(DIR, filename + '.html'),
      path.join(DIR, filename + '.gs')
    ];
    for (const file of candidates) {
      if (fs.existsSync(file)) {
        return fs.readFileSync(file, 'utf8');
      }
    }
    return `<!-- Missing include: ${filename} -->`;
  });

  // Reemplazar tags Apps Script simples
  content = content.replace(/<\?=\s*([^?]+)\s*\?>/g, (m, expr) => {
    if (expr.includes('userEmail')) return 'matias.cagliero@pedidosya.com';
    if (expr.includes('isAdmin')) return 'true';
    if (expr.includes('scriptUrl')) return '#';
    return '';
  });

  // Mock de google.script.run para entorno local
  const mockScript = `
  <script>
    if (typeof google === 'undefined') {
      window.google = {};
    }
    if (!google.script) {
      google.script = {
        run: {
          _successHandler: null,
          _failureHandler: null,
          withSuccessHandler: function(fn) {
            this._successHandler = fn;
            return this;
          },
          withFailureHandler: function(fn) {
            this._failureHandler = fn;
            return this;
          },
          getDashboardData: function(force) {
            const self = this;
            setTimeout(() => {
              const whs = [
                'AR_3_Belgrano', 'AR_506_Microcentro_II', 'AR_507_Villa_Crespo', 
                'AR_235_Barrio_Norte', 'AR_531_Villa_del_Parque_I', 'AR_511_Palermo_Soho',
                'AR_512_Caballito_Norte', 'AR_513_Almagro_Sur', 'AR_514_San_Telmo', 
                'AR_515_Recoleta_Pueyrredon', 'AR_516_Villa_Urquiza', 'AR_517_Villa_Devoto',
                'AR_518_Saavedra_Parque', 'AR_519_Flores_Centro', 'AR_520_Mataderos',
                'AR_521_Boedo_Plaza', 'AR_522_Colegiales_Oeste', 'AR_523_Chacarita',
                'AR_524_Barracas_Montes', 'AR_525_Nunez_Libertador', 'AR_526_Coghlan',
                'AR_527_Parque_Chas', 'AR_528_Paternal', 'AR_529_Liniers', 'AR_530_Versalles'
              ];
              const metrics = [
                { label: 'Confirmed Orders' }, { label: 'GMV (EUR)' }, { label: 'New Users' },
                { label: 'WIS %' }, { label: 'WIS UF %' }, { label: 'Seamless Delivery %' },
                { label: 'Avg. Delivery Time' }, { label: 'Assignment Time > 6 min %' },
                { label: 'Weighted Open time %' }, { label: 'Assignment Time' },
                { label: 'Rejected Orders %' }, { label: 'HC Sessions orders %' },
                { label: 'Late Orders %' }, { label: 'Slow Orders %' },
                { label: 'Forced Preorders %' }, { label: 'Modified Orders %' }
              ];
              const alerts = [
                { pais: 'AR_3_Belgrano', fecha: '2026-11-12', metricaLabel: 'Confirmed Orders', valorReal: 820, valorEsperado: 1150, consecutiveDays: 3, detalles: 'Caída > 20% vs L3W', lluvia_mm: 2.4 },
                { pais: 'AR_3_Belgrano', fecha: '2026-11-12', metricaLabel: 'WIS %', valorReal: 0.68, valorEsperado: 0.82, consecutiveDays: 2, detalles: 'Absoluto < 75%', lluvia_mm: 2.4 },
                { pais: 'AR_506_Microcentro_II', fecha: '2026-11-12', metricaLabel: 'Avg. Delivery Time', valorReal: 46.2, valorEsperado: 34.0, consecutiveDays: 1, detalles: 'Aumento > 5 min', lluvia_mm: 0.0 },
                { pais: 'AR_507_Villa_Crespo', fecha: '2026-11-12', metricaLabel: 'Seamless Delivery %', valorReal: 0.71, valorEsperado: 0.80, consecutiveDays: 4, detalles: 'Caída > 5 pp', lluvia_mm: 1.1 },
                { pais: 'AR_235_Barrio_Norte', fecha: '2026-11-12', metricaLabel: 'Rejected Orders %', valorReal: 0.048, valorEsperado: 0.015, consecutiveDays: 2, detalles: 'Absoluto > 3%', lluvia_mm: 0.0 },
                { pais: 'AR_511_Palermo_Soho', fecha: '2026-11-12', metricaLabel: 'Assignment Time > 6 min %', valorReal: 0.38, valorEsperado: 0.18, consecutiveDays: 5, detalles: 'Absoluto > 30%', lluvia_mm: 0.0 }
              ];
              if (self._successHandler) {
                self._successHandler({
                  alerts: alerts,
                  userSub: { paises: ['AR'], metricas: [], activo: true },
                  metricsList: metrics,
                  masterWhs: whs,
                  metricsAvailability: { '2026-11-12': { hasAnyData: true } },
                  whsWeather: { 'AR_3_Belgrano': 2.4, 'AR_507_Villa_Crespo': 1.1 }
                });
              }
            }, 300);
          },
          fetchDeferredWeatherForDate: function(date, whList) {
            const self = this;
            setTimeout(() => {
              if (self._successHandler) self._successHandler({});
            }, 100);
          }
        }
      };
    }
  </script>
  `;

  return content.replace('</head>', mockScript + '</head>');
}

const server = http.createServer((req, res) => {
  const filePath = path.join(DIR, '1_ByCountry.html');
  if (fs.existsSync(filePath)) {
    let content = fs.readFileSync(filePath, 'utf8');
    content = resolveTemplate(content);
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    });
    res.end(content);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('1_ByCountry.html not found');
  }
});

server.listen(PORT, () => {
  console.log(`[Local Server] Running on http://localhost:${PORT}`);
});
