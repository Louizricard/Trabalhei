// Homepage do Trabalhei: abertura, profundidade no cursor, demonstração guiada
// pela rolagem, transformação entre plataformas e links de download.
// Sem dependências. Com "reduzir movimento", nada é animado nem fixado e as
// etapas passam a ser escolhidas por botões.

const REPO = 'Louizricard/Trabalhei';
const root = document.documentElement;
const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
const finePointer = matchMedia('(hover: hover) and (pointer: fine)').matches;
root.classList.toggle('reduced', reduced);

const clamp = (v, min = 0, max = 1) => Math.min(max, Math.max(min, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (edge0, edge1, x) => {
  const t = clamp((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
};

/* ---------- Cabeçalho e menu ---------- */
function setupHeader() {
  const header = document.querySelector('[data-header]');
  const menu = document.querySelector('[data-menu]');
  const toggle = document.querySelector('[data-menu-toggle]');
  const onScroll = () => header.classList.toggle('is-scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  const setOpen = (open) => {
    menu.classList.toggle('is-open', open);
    toggle.setAttribute('aria-expanded', String(open));
    toggle.querySelector('.sr-only').textContent = open ? 'Fechar menu' : 'Abrir menu';
  };
  toggle.addEventListener('click', () => setOpen(!menu.classList.contains('is-open')));
  menu.addEventListener('click', (e) => e.target.closest('a') && setOpen(false));
  addEventListener('keydown', (e) => e.key === 'Escape' && setOpen(false));
}

/* ---------- Abertura: a tela real se monta em camadas ---------- */
function setupIntro() {
  const hero = document.querySelector('.hero');
  const base = hero.querySelector('.layer-base');
  const finish = () => {
    hero.classList.remove('is-playing');
    hero.classList.add('is-done');
  };
  if (reduced) return finish();

  let started = false;
  const play = () => {
    if (started) return;
    started = true;
    hero.classList.add('is-playing');
    setTimeout(finish, 3700);
  };
  // No celular a composição fica abaixo do texto: a sequência começa quando
  // ela entra na tela, para o destaque não acontecer fora da vista.
  const whenVisible = () => new Promise((resolve) => {
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) { io.disconnect(); resolve(); }
    }, { threshold: 0.2 });
    io.observe(hero.querySelector('.hero-stage'));
  });
  // Se a imagem demorar demais, mostra a composição pronta em vez de esperar.
  const fallback = setTimeout(() => !started && (started = true, finish()), 2500);
  base.decode().then(
    () => { clearTimeout(fallback); if (!started) whenVisible().then(play); },
    () => { clearTimeout(fallback); finish(); },
  );
}

/* ---------- Profundidade: a composição acompanha o cursor ---------- */
function setupTilt() {
  const stage = document.querySelector('[data-tilt] .stage-inner');
  const hero = document.querySelector('.hero');
  if (!stage || reduced || !finePointer) return;

  const target = { rx: 0, ry: 0, lx: 30, ly: 20 };
  const current = { ...target };
  let raf = 0;
  const tick = () => {
    let moving = false;
    for (const key of Object.keys(target)) {
      current[key] = lerp(current[key], target[key], 0.08);
      if (Math.abs(current[key] - target[key]) > 0.01) moving = true;
    }
    stage.style.setProperty('--rx', `${current.rx.toFixed(2)}deg`);
    stage.style.setProperty('--ry', `${current.ry.toFixed(2)}deg`);
    stage.style.setProperty('--lx', `${current.lx.toFixed(1)}%`);
    stage.style.setProperty('--ly', `${current.ly.toFixed(1)}%`);
    raf = moving ? requestAnimationFrame(tick) : 0;
  };
  const kick = () => { if (!raf) raf = requestAnimationFrame(tick); };

  hero.addEventListener('pointermove', (e) => {
    const r = hero.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width;
    const y = (e.clientY - r.top) / r.height;
    target.ry = (x - 0.5) * 9;
    target.rx = (0.5 - y) * 6;
    target.lx = x * 100;
    target.ly = y * 100;
    kick();
  });
  hero.addEventListener('pointerleave', () => {
    Object.assign(target, { rx: 0, ry: 0, lx: 30, ly: 20 });
    kick();
  });
}

/* ---------- Cenas presas à rolagem ---------- */
function sceneProgress(el) {
  const r = el.getBoundingClientRect();
  const total = r.height - innerHeight;
  return total <= 0 ? 0 : clamp(-r.top / total);
}

/** Rola até a fração `p` de uma cena (usado pelos botões de etapa). */
function scrollToProgress(el, p) {
  const top = el.getBoundingClientRect().top + scrollY;
  const total = el.offsetHeight - innerHeight;
  scrollTo({ top: top + total * p, behavior: reduced ? 'auto' : 'smooth' });
}

// Áreas de cada tela (em % do print) que o anel destaca, na ordem da etapa.
const DEMO_STEPS = [
  [{ x: 9.5, y: 36.5, w: 81, h: 41, note: 'Título, categoria e descrição do projeto' }],
  [
    { x: 4.6, y: 8.6, w: 90.8, h: 8.4, note: 'Plano grátis: 5 propostas por mês' },
    { x: 4.6, y: 37.6, w: 90.8, h: 52.6, note: 'Valor, prazo e carta de apresentação' },
  ],
  [
    { x: 4, y: 8.2, w: 92, h: 11.8, note: 'Total, menor e maior proposta e prazo médio' },
    { x: 7.6, y: 52.9, w: 84.8, h: 5.6, note: 'Aceitar, negociar ou conversar no chat' },
  ],
  [
    { x: 4, y: 7.7, w: 92, h: 9.9, note: 'Entrega recebida, pronta para revisar' },
    { x: 6, y: 53, w: 88, h: 29.8, note: 'Aprovar a entrega ou pedir revisão' },
  ],
];

function setupDemo() {
  const section = document.querySelector('[data-demo]');
  const screens = [...section.querySelectorAll('.demo-screen')];
  const steps = [...section.querySelectorAll('.demo-step')];
  const ring = section.querySelector('[data-ring]');
  const note = section.querySelector('[data-note]');
  const bar = section.querySelector('[data-demo-progress]');
  let shown = { step: -1, target: -1 };

  const show = (step, target) => {
    if (step !== shown.step) {
      screens.forEach((img, i) => {
        img.classList.toggle('is-leaving', i === shown.step);
        img.classList.toggle('is-active', i === step);
      });
      steps.forEach((li, i) => li.classList.toggle('is-active', i === step));
    }
    if (step !== shown.step || target !== shown.target) {
      const t = DEMO_STEPS[step][target];
      for (const k of ['x', 'y', 'w', 'h']) ring.style.setProperty(`--${k}`, t[k]);
      note.textContent = t.note;
    }
    shown = { step, target };
  };

  const update = (p) => {
    const f = Math.min(p * DEMO_STEPS.length, DEMO_STEPS.length - 0.001);
    const step = Math.floor(f);
    const targets = DEMO_STEPS[step];
    const target = Math.min(targets.length - 1, Math.floor((f - step) * targets.length));
    show(step, target);
    bar.style.setProperty('--p', p.toFixed(3));
  };

  section.querySelectorAll('[data-step-button]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const i = Number(btn.dataset.stepButton);
      if (reduced) {
        const next = shown.step === i ? (shown.target + 1) % DEMO_STEPS[i].length : 0;
        show(i, next);
        bar.style.setProperty('--p', ((i + 1) / DEMO_STEPS.length).toFixed(3));
      } else {
        scrollToProgress(section, (i + 0.3) / DEMO_STEPS.length);
      }
    });
  });

  show(0, 0);
  return reduced ? null : () => update(sceneProgress(section));
}

function setupMorph() {
  const section = document.querySelector('[data-morph]');
  const device = section.querySelector('[data-morph-device]');
  const stage = section.querySelector('.morph-stage');
  const tabs = [...section.querySelectorAll('[data-platform-tab]')];
  const panels = [...section.querySelectorAll('[data-platform-panel]')];
  const HOLDS = [0.14, 0.52, 0.9];
  let shapes = null;
  let activePanel = -1;

  // Medidas de cada forma a partir do espaço disponível.
  const measure = () => {
    const W = stage.clientWidth;
    const H = stage.clientHeight;
    const phoneH = Math.min(H, 640);
    const phoneW = (phoneH - 20) * (390 / 844) + 20;
    const desk = (chrome) => {
      let w = Math.min(W, 1000);
      let h = (w - 2) / 1.6 + chrome + 2;
      if (h > H) { h = H; w = (h - chrome - 2) * 1.6 + 2; }
      return { w, h };
    };
    const win = desk(32);
    const web = desk(74);
    shapes = {
      phone: { w: phoneW, h: phoneH, r: 46, bezel: 10, chrome: 0 },
      win: { ...win, r: 10, bezel: 1, chrome: 32 },
      web: { ...web, r: 12, bezel: 1, chrome: 74 },
    };
  };

  const setPanel = (i) => {
    if (i === activePanel) return;
    activePanel = i;
    tabs.forEach((t, k) => {
      t.classList.toggle('is-active', k === i);
      t.setAttribute('aria-selected', String(k === i));
      t.tabIndex = k === i ? 0 : -1;
    });
    panels.forEach((p, k) => {
      p.hidden = k !== i;
      p.classList.toggle('is-active', k === i);
    });
  };

  const apply = (p) => {
    if (!shapes) measure();
    const t1 = smooth(0.28, 0.42, p);
    const t2 = smooth(0.62, 0.76, p);
    const { phone, win, web } = shapes;
    const mix = (key) => (p < 0.52 ? lerp(phone[key], win[key], t1) : lerp(win[key], web[key], t2));
    const s = device.style;
    s.setProperty('--w', `${mix('w').toFixed(1)}px`);
    s.setProperty('--h', `${mix('h').toFixed(1)}px`);
    s.setProperty('--r', `${mix('r').toFixed(1)}px`);
    s.setProperty('--bezel', `${mix('bezel').toFixed(2)}px`);
    s.setProperty('--chrome', `${mix('chrome').toFixed(1)}px`);
    s.setProperty('--win', (smooth(0.5, 1, t1) * (1 - t2)).toFixed(3));
    s.setProperty('--web', smooth(0.4, 1, t2).toFixed(3));
    // Troca curta no meio da transformação, sem sobrepor os dois prints.
    s.setProperty('--o-phone', (1 - smooth(0.1, 0.4, t1)).toFixed(3));
    s.setProperty('--o-win', (smooth(0.45, 0.75, t1) * (1 - smooth(0.1, 0.4, t2))).toFixed(3));
    s.setProperty('--o-web', smooth(0.45, 0.75, t2).toFixed(3));
    device.dataset.shape = t1 < 0.5 ? 'phone' : 'desk';
    setPanel(p < 0.35 ? 0 : p < 0.69 ? 1 : 2);
  };

  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => {
      if (reduced) apply(HOLDS[i]);
      else scrollToProgress(section, HOLDS[i]);
    });
    tab.addEventListener('keydown', (e) => {
      const dir = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
      if (!dir) return;
      const next = tabs[(i + dir + tabs.length) % tabs.length];
      next.focus();
      next.click();
    });
  });
  addEventListener('resize', () => { shapes = null; apply(reduced ? HOLDS[activePanel] : sceneProgress(section)); });

  apply(0);
  return reduced ? null : () => apply(sceneProgress(section));
}

function setupScenes() {
  const updates = [setupDemo(), setupMorph()].filter(Boolean);
  if (!updates.length) return;
  let queued = false;
  const frame = () => { queued = false; updates.forEach((u) => u()); };
  const queue = () => { if (!queued) { queued = true; requestAnimationFrame(frame); } };
  addEventListener('scroll', queue, { passive: true });
  addEventListener('resize', queue);
  frame();
}

/* ---------- Downloads: arquivos oficiais do GitHub Releases ---------- */
const formatSize = (bytes) => `${Math.round(bytes / 1048576).toLocaleString('pt-BR')} MB`;
const WINDOWS_FORMATS = { zip: 'ZIP (extrair e abrir)', exe: 'Instalador .exe', msix: 'Pacote MSIX' };

async function latestRelease() {
  try {
    const cached = sessionStorage.getItem('trabalhei-release');
    if (cached) return JSON.parse(cached);
  } catch { /* armazenamento indisponível */ }
  const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
    headers: { Accept: 'application/vnd.github+json' },
  });
  if (!res.ok) throw new Error(`GitHub respondeu ${res.status}`);
  const { tag_name, html_url, assets } = await res.json();
  const release = {
    tag: tag_name,
    url: html_url,
    assets: assets.map(({ name, size, browser_download_url }) => ({ name, size, url: browser_download_url })),
  };
  try { sessionStorage.setItem('trabalhei-release', JSON.stringify(release)); } catch { /* ignora */ }
  return release;
}

const setText = (selector, text) => document.querySelectorAll(selector).forEach((el) => (el.textContent = text));

async function setupDownloads() {
  let release;
  try {
    release = await latestRelease();
  } catch {
    return; // Mantém os links para a página de versões (sempre válidos).
  }
  const version = release.tag.replace(/^v/, '');
  document.querySelectorAll('[data-release-notes]').forEach((a) => (a.href = release.url));

  const apk = release.assets.find((a) => /\.apk$/i.test(a.name));
  if (apk) {
    document.querySelectorAll('[data-download="android"]').forEach((a) => {
      a.href = apk.url;
      a.setAttribute('download', '');
    });
    setText('[data-android-version]', version);
    setText('[data-android-size]', formatSize(apk.size));
  }

  const win = release.assets.find((a) => /windows/i.test(a.name) && /\.(zip|exe|msix)$/i.test(a.name));
  if (win) {
    const ext = win.name.split('.').pop().toLowerCase();
    document.querySelectorAll('[data-download="windows"]').forEach((a) => {
      a.href = win.url;
      a.removeAttribute('aria-disabled');
      a.removeAttribute('title');
      a.classList.remove('is-pending');
    });
    setText('[data-download-label]', 'Baixar para Windows');
    setText('[data-windows-version]', version);
    setText('[data-windows-size]', formatSize(win.size));
    setText('[data-windows-format]', WINDOWS_FORMATS[ext] ?? ext.toUpperCase());
    setText('[data-windows-help]', ext === 'zip'
      ? 'Extraia o arquivo e abra o Trabalhei.exe. Na primeira vez, o Windows pode pedir confirmação.'
      : 'Abra o arquivo baixado e siga as instruções. Na primeira vez, o Windows pode pedir confirmação.');
  }
}

setupHeader();
setupIntro();
setupTilt();
setupScenes();
setupDownloads();
document.querySelectorAll('[data-year]').forEach((el) => (el.textContent = new Date().getFullYear()));
