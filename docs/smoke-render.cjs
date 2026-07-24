#!/usr/bin/env node
// Smoke de RENDER do portal (headless, WebGL por software). Existe porque o
// smoke de bytes (curl/CSP) NAO pega crash de runtime: o HTML pode ser servido
// certo e o JavaScript quebrar ao rodar (licao do "rnd is not defined", 2026-07-24,
// que deixou o grafo so na tela de erro em producao). Este passo carrega o portal
// num browser DE VERDADE e falha se: houver erro de pagina, a tela de #erro
// aparecer, ou o contador nao montar os nos.
//
// Uso: node docs/smoke-render.cjs   (roda a partir da raiz do repo)
// Requer: playwright + chromium instalados (o CI faz o install; local usa o global).

const http = require('http');
const fs = require('fs');
const path = require('path');

const DOCS = path.resolve(__dirname);
const PORT = 8391;

// MIME minimo — modulos ES exigem text/javascript; a vitrine, application/json.
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.woff2': 'font/woff2', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.ico': 'image/x-icon',
};

function resolvePlaywright() {
  // local: usa o global; CI: usa o node_modules do repo instalado no passo anterior.
  const candidatos = [
    path.join(process.cwd(), 'node_modules', 'playwright'),
    '/opt/node22/lib/node_modules/playwright',
    'playwright',
  ];
  for (const c of candidatos) {
    try { return require(c); } catch (_) { /* tenta o proximo */ }
  }
  throw new Error('playwright nao encontrado — instale antes (npm i playwright).');
}

function servidor() {
  return http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '') || 'index.html';
    const abs = path.join(DOCS, rel);
    if (!abs.startsWith(DOCS)) { res.writeHead(403); return res.end(); } // sem path traversal
    fs.readFile(abs, (err, buf) => {
      if (err) { res.writeHead(404); return res.end('nao encontrado'); }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(abs)] || 'application/octet-stream' });
      res.end(buf);
    });
  });
}

(async () => {
  const { chromium } = resolvePlaywright();
  const srv = servidor();
  await new Promise((r) => srv.listen(PORT, '127.0.0.1', r));

  const browser = await chromium.launch({
    args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 800 } })).newPage();

  const erros = [];
  page.on('pageerror', (e) => erros.push('pageerror: ' + e.message));
  page.on('requestfailed', (r) => {
    // ignora abortos benignos; sinaliza falha de asset do proprio portal
    const u = r.url();
    if (u.includes(`127.0.0.1:${PORT}`)) erros.push('asset falhou: ' + u.split(`:${PORT}/`).pop() + ' :: ' + (r.failure() && r.failure().errorText));
  });

  let estado = {};
  try {
    await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: 'load', timeout: 45000 });
    // aguarda o grafo montar (contador preenchido) OU a tela de erro aparecer
    await page.waitForFunction(() => {
      const c = document.getElementById('contador');
      const e = document.getElementById('erro');
      const erroVisivel = e && getComputedStyle(e).display !== 'none';
      const contadorOk = c && /\d/.test(c.textContent || '');
      return erroVisivel || contadorOk;
    }, { timeout: 30000 });

    estado = await page.evaluate(() => {
      const g = (id) => document.getElementById(id);
      const disp = (id) => { const e = g(id); return e ? getComputedStyle(e).display : 'removido'; };
      return {
        erroDisplay: disp('erro'),
        erroTexto: (g('erro') && g('erro').textContent || '').trim().slice(0, 200),
        contador: (g('contador') && g('contador').textContent || '').trim(),
      };
    });
  } catch (e) {
    erros.push('timeout/goto: ' + e.message);
  }

  await browser.close();
  await new Promise((r) => srv.close(r));

  // Vereditos
  const falhas = [...erros];
  if (estado.erroDisplay && estado.erroDisplay !== 'none' && estado.erroDisplay !== 'removido') {
    falhas.push('tela de #erro visivel: ' + estado.erroTexto);
  }
  const nos = (estado.contador || '').match(/(\d[\d.]*)\s*notas?/);
  if (!nos || parseInt(nos[1].replace(/\D/g, ''), 10) <= 0) {
    falhas.push('contador nao montou os nos (contador="' + (estado.contador || '') + '")');
  }

  if (falhas.length) {
    console.error('SMOKE DE RENDER FALHOU:');
    for (const f of falhas) console.error('  - ' + f);
    process.exit(1);
  }
  console.log(`OK: portal renderiza — contador "${estado.contador}", 0 erro de pagina.`);
})().catch((e) => { console.error('smoke-render erro inesperado:', e); process.exit(1); });
