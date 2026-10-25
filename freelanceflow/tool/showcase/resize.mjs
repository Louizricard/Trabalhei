// Redimensiona imagens com o canvas de um navegador sem interface (sem pacotes).
//
// BROWSER="caminho do Edge ou Chrome" node tool/showcase/resize.mjs \
//   entrada.png:saida.webp:largura [mais pares...]
//
// O formato sai pela extensão (.webp, .png ou .jpg).
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import { connect, browserSocket } from './cdp.mjs';

const PORT = 9334;
const MIME = { '.webp': 'image/webp', '.png': 'image/png', '.jpg': 'image/jpeg' };

const jobs = process.argv.slice(2).map((arg) => {
  // Caminhos do Windows têm "C:", então separa pela extensão de cada arquivo.
  const [, src, out, width] = arg.match(/^(.+?\.\w+):(.+\.\w+):(\d+)$/) ?? [];
  return { src, out, width: Number(width) };
});
if (!process.env.BROWSER || jobs.length === 0) {
  console.error('Uso: BROWSER=<edge/chrome> node tool/showcase/resize.mjs in:out:largura ...');
  process.exit(1);
}

const browser = spawn(process.env.BROWSER, [
  '--headless=new',
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${mkdtempSync(join(tmpdir(), 'resize-'))}`,
]);
try {
  const { ws, send } = await connect(await browserSocket(PORT));
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  for (const { src, out, width } of jobs) {
    const input = readFileSync(src).toString('base64');
    const type = MIME[extname(out)];
    const { result } = await send('Runtime.evaluate', {
      awaitPromise: true,
      expression: `(async () => {
        const img = new Image();
        img.src = 'data:image/png;base64,${input}';
        await img.decode();
        const c = document.createElement('canvas');
        c.width = ${width};
        c.height = Math.round(img.height * ${width} / img.width);
        const ctx = c.getContext('2d');
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(img, 0, 0, c.width, c.height);
        return c.toDataURL('${type}', 0.88).split(',')[1];
      })()`,
    }, sessionId);
    writeFileSync(out, Buffer.from(result.value, 'base64'));
    console.log(`ok ${out}`);
  }
  ws.close();
} finally {
  browser.kill();
}
