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

const BASE = process.env.SHOWCASE_URL ?? 'http://localhost:8091';
const BROWSER = process.env.BROWSER;
const OUT = process.argv[2];
const PORT = 9333;

const phone = { width: 390, height: 844, scale: 3, mobile: true };
const desktop = { width: 1440, height: 900, scale: 2, mobile: false };

export const SHOTS = [
  ['phone-jobs', 'freelancer', '/jobs', phone],
  ['phone-job-detail', 'freelancer', '/jobs/demo-job-1', phone],
  ['phone-apply', 'freelancer', '/jobs/demo-job-1/apply', phone, [
    [114, 449, '5200'],
    [275, 438, '28'],
    [195, 640, 'Já entreguei dois apps de agendamento em Flutter. Posso começar esta semana e validar o fluxo com a recepção antes da publicação.'],
  ]],
  ['phone-create-job', 'client', '/jobs/create', phone, [
    [195, 364, 'App para clínica veterinária'],
    [195, 580, 'Precisamos de um app para os tutores marcarem consultas e banho e tosa, receberem lembretes e acompanharem o histórico de cada pet.'],
  ]],
  ['phone-proposals', 'client', '/jobs/demo-job-1/proposals', phone],
  ['phone-chat', 'client', '/chat/demo-conv-1', phone],
  ['phone-dashboard', 'freelancer', '/dashboard', phone],
  ['phone-plans', 'freelancer', '/plans', phone],
  ['phone-freelancers', 'client', '/freelancers', phone],
  ['desktop-jobs', 'freelancer', '/jobs', desktop],
  ['desktop-chat', 'client', '/chat/demo-conv-1', desktop],
  ['desktop-dashboard', 'freelancer', '/dashboard', desktop],
  ['desktop-proposals', 'client', '/jobs/demo-job-1/proposals', desktop],
];

// Preenche campos de formulário: [x, y, texto] em pixels CSS da tela.
async function fill(send, sessionId, fields = []) {
  for (const [x, y, text] of fields) {
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 }, sessionId);
    }
    await sleep(400);
    await send('Input.insertText', { text }, sessionId);
    await sleep(300);
  }
  if (fields.length) {
    // Clica no título para tirar o foco (sem cursor piscando no print).
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x: 200, y: 24, button: 'left', clickCount: 1 }, sessionId);
    }
    await sleep(800);
  }
}

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
