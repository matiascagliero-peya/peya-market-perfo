const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8085;
const DIR = __dirname;

function resolveTemplate(html) {
  return html.replace(/<\?!=\s*include\(['"]([^'"]+)['"]\);?\s*\?>/g, (match, filename) => {
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
}

const server = http.createServer((req, res) => {
  const filePath = path.join(DIR, 'Index.html');
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
    res.end('Index.html not found');
  }
});

server.listen(PORT, () => {
  console.log(`Local dev server running on http://localhost:${PORT}`);
});
