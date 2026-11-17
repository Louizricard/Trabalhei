// Telas, papéis e campos preenchidos usados pelos scripts de captura
// (capture.mjs para a homepage e store.mjs para a Play Store).
import { sleep } from './cdp.mjs';

export const phone = { width: 390, height: 844, scale: 3, mobile: true };
export const desktop = { width: 1280, height: 800, scale: 2, mobile: false };

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
  ['desktop-create-job', 'client', '/jobs/create', desktop, [
    [640, 363, 'App para clínica veterinária'],
    [640, 563, 'Precisamos de um app para os tutores marcarem consultas e banho e tosa, receberem lembretes e acompanharem o histórico de cada pet.'],
  ]],
  ['desktop-apply', 'freelancer', '/jobs/demo-job-1/apply', desktop, [
    [480, 384, '5200'],
    [797, 384, '28'],
    [640, 589, 'Já entreguei dois apps de agendamento em Flutter. Posso começar esta semana e validar o fluxo com a recepção antes da publicação.'],
  ]],
];

// Preenche campos de formulário: [x, y, texto] em pixels CSS da tela.
export async function fill(send, sessionId, fields = []) {
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
