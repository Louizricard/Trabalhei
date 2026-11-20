// Gera as capturas brutas da ficha da Google Play a partir do app de demonstração.
//
// 1. flutter build web -t tool/showcase/main.dart -o build/showcase
// 2. Sirva build/showcase (ex.: python3 -m http.server 8091 --directory build/showcase)
// 3. BROWSER="caminho do Chrome" node tool/showcase/store.mjs [pasta de saída]
//
// Sem pasta, grava em ../store-listing/play/raw (rodando de freelanceflow/).
// Cada tela sai em PNG 1170x2532 (celular de 390x844 com escala 3). As molduras,
// títulos e o gráfico de recursos saem de store-listing/play/generate.py.
// ONLY=phone-jobs,phone-chat captura só as telas indicadas.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { connect, browserSocket, sleep } from './cdp.mjs';
import { SHOTS, phone, fill } from './shots.mjs';

const BASE = process.env.SHOWCASE_URL ?? 'http://localhost:8091';
const BROWSER = process.env.BROWSER;
const OUT = process.argv[2] ?? '../store-listing/play/raw';
const PORT = 9335;

// Na loja, o formulário de vaga sai com título, área e especialidade escolhidos
// (o seletor de área abre uma busca; o clique em y=260 escolhe o resultado).
const STORE_FIELDS = {
  'phone-create-job': [
    [195, 384, 'App para clínica veterinária'],
    [195, 509, 'Mobile'],
    [195, 260, ''],
  ],
};

// Telas de celular da homepage, com os campos da loja quando houver.
const STORE_SHOTS = SHOTS.filter(([, , , vp]) => vp === phone)
  .map(([name, role, route, vp, fields]) => [name, role, route, vp, STORE_FIELDS[name] ?? fields]);

async function capture(send, [name, role, route, vp, fields]) {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  await send('Emulation.setDeviceMetricsOverride', {
    width: vp.width,
    height: vp.height,
    deviceScaleFactor: vp.scale,
    mobile: vp.mobile,
  }, sessionId);
  await send('Page.enable', {}, sessionId);
  await send('Page.navigate', { url: `${BASE}/?role=${role}#${route}` }, sessionId);
  await sleep(9000);
  await fill(send, sessionId, fields);
  const { data } = await send('Page.captureScreenshot', { format: 'png' }, sessionId);
  writeFileSync(join(OUT, `${name}.png`), Buffer.from(data, 'base64'));
  await send('Target.closeTarget', { targetId });
  console.log(`ok ${name}`);
}

if (!BROWSER) {
  console.error('Uso: BROWSER=<chrome> node tool/showcase/store.mjs [saída]');
  process.exit(1);
}
mkdirSync(OUT, { recursive: true });
const profile = mkdtempSync(join(tmpdir(), 'store-'));
const browser = spawn(BROWSER, [
  '--headless=new',
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  '--hide-scrollbars',
  '--no-first-run',
]);
try {
  const { ws, send } = await connect(await browserSocket(PORT));
  const only = process.env.ONLY?.split(',');
  for (const shot of STORE_SHOTS) {
    if (!only || only.includes(shot[0])) await capture(send, shot);
  }
  ws.close();
} finally {
  browser.kill();
}
