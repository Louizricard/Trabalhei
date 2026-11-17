// Gera os prints da homepage a partir do app de demonstração (tool/showcase).
//
// 1. flutter build web -t tool/showcase/main.dart -o build/showcase
// 2. Sirva build/showcase (ex.: python -m http.server 8091 --directory build/showcase)
// 3. BROWSER="caminho do Edge ou Chrome" node tool/showcase/capture.mjs <pasta de saída>
//
// Usa só o Node (WebSocket nativo) e o protocolo DevTools do navegador, sem
// pacotes. Cada print sai em WebP direto do canvas do navegador.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { connect, browserSocket, sleep } from './cdp.mjs';
import { SHOTS, fill } from './shots.mjs';

export { SHOTS };

const BASE = process.env.SHOWCASE_URL ?? 'http://localhost:8091';
const BROWSER = process.env.BROWSER;
const OUT = process.argv[2];
const PORT = 9333;

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
  // Converte para WebP no próprio navegador (canvas), sem dependências.
  const { result } = await send('Runtime.evaluate', {
    awaitPromise: true,
    expression: `(async () => {
      const img = new Image();
      img.src = 'data:image/png;base64,${data}';
      await img.decode();
      const c = document.createElement('canvas');
      c.width = img.width; c.height = img.height;
      c.getContext('2d').drawImage(img, 0, 0);
      return c.toDataURL('image/webp', 0.9).split(',')[1];
    })()`,
  }, sessionId);
  writeFileSync(join(OUT, `${name}.png`), Buffer.from(data, 'base64'));
  writeFileSync(join(OUT, `${name}.webp`), Buffer.from(result.value, 'base64'));
  await send('Target.closeTarget', { targetId });
  console.log(`ok ${name}`);
}

if (!BROWSER || !OUT) {
  console.error('Uso: BROWSER=<edge/chrome> node tool/showcase/capture.mjs <saída>');
  process.exit(1);
}
mkdirSync(OUT, { recursive: true });
const profile = mkdtempSync(join(tmpdir(), 'showcase-'));
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
  for (const shot of SHOTS) {
    if (!only || only.includes(shot[0])) await capture(send, shot);
  }
  ws.close();
} finally {
  browser.kill();
}
