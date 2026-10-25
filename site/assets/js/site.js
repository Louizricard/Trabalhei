// Homepage do Trabalhei: abertura, profundidade no cursor, demonstração guiada
// pela rolagem, transformação entre plataformas, entrada das seções e links de
// download. Sem dependências. Com "reduzir movimento", nada é animado nem
// fixado e as etapas passam a ser escolhidas por botões.

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
/** "desk" (notebook em destaque) ou "phone"; definido no <head>. */
const mode = () => root.dataset.mode ?? 'phone';
const headerHeight = () => document.querySelector('[data-header]').offsetHeight;

/* ---------- Cabeçalho e menu ---------- */
function setupHeader() {
  const header = document.querySelector('[data-header]');
  const menu = document.querySelector('[data-menu]');
  const toggle = document.querySelector('[data-menu-toggle]');
  const hint = document.querySelector('[data-scroll-hint]');
  const onScroll = () => {
    header.classList.toggle('is-scrolled', scrollY > 8);
    hint?.classList.toggle('is-hidden', scrollY > 60);
  };
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
    setTimeout(finish, 3600);
  };
  // No celular a composição fica abaixo do texto: a sequência começa quando
  // ela entra na tela, para o destaque não acontecer fora da vista.
  const whenVisible = () => new Promise((resolve) => {
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) { io.disconnect(); resolve(); }
    }, { threshold: 0.2 });
    io.observe(hero.querySelector('.hero-stage'));
  });
  const front = hero.querySelector(mode() === 'desk' ? '.hero-laptop .layer-base' : '.hero-phone .layer-base');
  // Se a imagem demorar demais, mostra a composição pronta em vez de esperar.
  const fallback = setTimeout(() => !started && (started = true, finish()), 2500);
  front.decode().then(
    () => { clearTimeout(fallback); if (!started) whenVisible().then(play); },
    () => { clearTimeout(fallback); finish(); },
  );
}

/* ---------- Profundidade: a composição acompanha o cursor ---------- */
function setupTilt() {
  const hero = document.querySelector('.hero');
  const stage = hero.querySelector('[data-tilt] .stage-inner');
  if (reduced || !finePointer) return;

  const target = { rx: 0, ry: 0 };
  const current = { rx: 0, ry: 0 };
  let raf = 0;
  const tick = () => {
    current.rx = lerp(current.rx, target.rx, 0.08);
    current.ry = lerp(current.ry, target.ry, 0.08);
    stage.style.setProperty('--rx', `${current.rx.toFixed(2)}deg`);
    stage.style.setProperty('--ry', `${current.ry.toFixed(2)}deg`);
    const moving = Math.abs(current.rx - target.rx) + Math.abs(current.ry - target.ry) > 0.01;
    raf = moving ? requestAnimationFrame(tick) : 0;
  };
  const kick = () => { if (!raf) raf = requestAnimationFrame(tick); };

  hero.addEventListener('pointermove', (e) => {
    const r = hero.getBoundingClientRect();
    target.ry = ((e.clientX - r.left) / r.width - 0.5) * 7;
    target.rx = (0.5 - (e.clientY - r.top) / r.height) * 5;
    kick();
  });
  hero.addEventListener('pointerleave', () => { target.rx = 0; target.ry = 0; kick(); });
}

/* ---------- Entrada das seções ---------- */
function setupReveal() {
  const items = [...document.querySelectorAll('.reveal')];
  const show = (el) => el.classList.add('is-in');
  if (reduced || !('IntersectionObserver' in window)) return items.forEach(show);
  // Itens irmãos entram em sequência.
  items.forEach((el) => {
    const siblings = [...el.parentElement.children].filter((c) => c.classList.contains('reveal'));
    el.style.setProperty('--i', siblings.indexOf(el));
  });
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (e.isIntersecting) { show(e.target); io.unobserve(e.target); }
    }
  }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
  items.forEach((el) => io.observe(el));
}

/* ---------- Cenas presas à rolagem ---------- */
function trackProgress(track) {
  const sticky = track.firstElementChild;
  const total = track.offsetHeight - sticky.offsetHeight;
  if (total <= 0) return 0;
  return clamp((headerHeight() - track.getBoundingClientRect().top) / total);
}

/** Rola até a fração `p` de uma cena (usado pelos botões de etapa). */
function scrollToProgress(track, p) {
  const total = track.offsetHeight - track.firstElementChild.offsetHeight;
  const top = track.getBoundingClientRect().top + scrollY - headerHeight();
  scrollTo({ top: top + total * p, behavior: reduced ? 'auto' : 'smooth' });
}

// Áreas de cada print (em %) que o anel destaca, na ordem de cada etapa.
// Medidas sobre os prints em site/assets/screens; ao trocar um print, confira.
const DEMO_STEPS = {
  phone: [
    [{ x: 9.5, y: 36.5, w: 81, h: 41, note: 'Título, categoria e descrição do projeto' }],
    [
      { x: 4.6, y: 8.6, w: 90.8, h: 8.4, note: 'Propostas grátis restantes no mês' },
      { x: 4.6, y: 37.6, w: 90.8, h: 52.6, note: 'Valor, prazo e carta de apresentação' },
    ],
    [
      { x: 3.8, y: 8.2, w: 92.4, h: 11.8, note: 'Total, menor e maior proposta e prazo médio' },
      { x: 7.6, y: 52.9, w: 85.2, h: 5.6, note: 'Aceitar, negociar ou conversar no chat' },
    ],
    [
      { x: 3.6, y: 7.6, w: 92.8, h: 10.1, note: 'Aviso de entrega recebida no topo do chat' },
      { x: 5.6, y: 61.1, w: 88.8, h: 29.7, note: 'A entrega, com o botão para revisar os arquivos e aprovar' },
    ],
  ],
  desk: [
    [{ x: 24.4, y: 38.6, w: 51.2, h: 43, note: 'Título, categoria e descrição do projeto' }],
    [
      { x: 23.8, y: 9.1, w: 52.4, h: 8.6, note: 'Propostas grátis restantes no mês' },
      { x: 23.8, y: 34.2, w: 52.4, h: 53, note: 'Valor, prazo e carta de apresentação' },
    ],
    [
      { x: 0.8, y: 8.6, w: 98.4, h: 12.6, note: 'Total, menor e maior proposta e prazo médio' },
      { x: 2.2, y: 51.2, w: 95.6, h: 5.2, note: 'Aceitar, negociar ou conversar no chat' },
    ],
    [
      { x: 19.6, y: 8.1, w: 60.8, h: 8.5, note: 'Aviso de entrega recebida no topo do chat' },
      { x: 31.6, y: 60.5, w: 36.7, h: 24.5, note: 'A entrega, com o botão para revisar os arquivos e aprovar' },
    ],
  ],
};
const STEP_COUNT = DEMO_STEPS.phone.length;

function setupDemo() {
  const section = document.querySelector('[data-demo]');
  const track = section.querySelector('[data-track]');
  const devices = [...section.querySelectorAll('.laptop-screen, .phone-screen')].map((el) => ({
    screens: [...el.querySelectorAll('.demo-screen')],
    ring: el.querySelector('[data-ring]'),
  }));
  const steps = [...section.querySelectorAll('.demo-step')];
  const note = section.querySelector('[data-note]');
  const bar = section.querySelector('[data-demo-progress]');
  const hint = section.querySelector('[data-scene-hint]');
  let shown = { step: -1, target: -1, mode: '' };

  const show = (step, target) => {
    const m = mode();
    if (step === shown.step && target === shown.target && m === shown.mode) return;
    if (step !== shown.step) {
      for (const { screens } of devices) {
        screens.forEach((img, i) => {
          img.classList.toggle('is-leaving', i === shown.step);
          img.classList.toggle('is-active', i === step);
        });
      }
      steps.forEach((li, i) => li.classList.toggle('is-active', i === step));
    }
    const t = DEMO_STEPS[m][step][target];
    for (const { ring } of devices) {
      for (const k of ['x', 'y', 'w', 'h']) ring.style.setProperty(`--${k}`, t[k]);
    }
    note.textContent = t.note;
    shown = { step, target, mode: m };
  };

  const update = (p) => {
    const f = Math.min(p * STEP_COUNT, STEP_COUNT - 0.001);
    const step = Math.floor(f);
    const count = DEMO_STEPS.phone[step].length;
    show(step, Math.min(count - 1, Math.floor((f - step) * count)));
    bar.style.setProperty('--p', p.toFixed(4));
    hint.classList.toggle('is-hidden', p > 0.9);
  };

  section.querySelectorAll('[data-step-button]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const i = Number(btn.dataset.stepButton);
      if (reduced) {
        const count = DEMO_STEPS.phone[i].length;
        show(i, shown.step === i ? (shown.target + 1) % count : 0);
        bar.style.setProperty('--p', ((i + 1) / STEP_COUNT).toFixed(3));
      } else {
        scrollToProgress(track, (i + 0.3) / STEP_COUNT);
      }
    });
  });
  addEventListener('trabalhei:mode', () => show(Math.max(shown.step, 0), Math.max(shown.target, 0)));

  show(0, 0);
  return reduced ? null : { track, update };
}

function setupMorph() {
  const section = document.querySelector('[data-morph]');
  const track = section.querySelector('[data-track]');
  const device = section.querySelector('[data-morph-device]');
  const stage = section.querySelector('.morph-stage');
  const tabs = [...section.querySelectorAll('[data-platform-tab]')];
  const panels = [...section.querySelectorAll('[data-platform-panel]')];
  const bar = section.querySelector('[data-morph-progress]');
  const HOLDS = [0.12, 0.52, 0.9];
  let shapes = null;
  let activePanel = -1;
  let last = 0;

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
    shapes = {
      phone: { w: phoneW, h: phoneH, r: 46, bezel: 10, chrome: 0 },
      win: { ...desk(32), r: 10, bezel: 1, chrome: 32 },
      web: { ...desk(74), r: 12, bezel: 1, chrome: 74 },
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
    last = p;
    if (!shapes) measure();
    const t1 = smooth(0.26, 0.44, p);
    const t2 = smooth(0.6, 0.78, p);
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
    bar.style.setProperty('--p', p.toFixed(4));
    setPanel(p < 0.35 ? 0 : p < 0.7 ? 1 : 2);
  };

  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => (reduced ? apply(HOLDS[i]) : scrollToProgress(track, HOLDS[i])));
    tab.addEventListener('keydown', (e) => {
      const dir = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
      if (!dir) return;
      const next = tabs[(i + dir + tabs.length) % tabs.length];
      next.focus();
      next.click();
    });
  });
  addEventListener('resize', () => { shapes = null; apply(last); });

  apply(0);
  return reduced ? null : { track, update: apply };
}

/** Atualiza as cenas com a rolagem suavizada, para não andar aos saltos. */
function setupScenes() {
  const scenes = [setupDemo(), setupMorph()].filter(Boolean).map((s) => ({ ...s, value: 0, target: 0 }));
  if (!scenes.length) return;
  let raf = 0;
  let lastTime = 0;
  const frame = (time) => {
    const dt = lastTime ? Math.min(64, time - lastTime) : 16.7;
    lastTime = time;
    const k = 1 - Math.pow(0.8, dt / 16.7);
    let moving = false;
    for (const s of scenes) {
      s.target = trackProgress(s.track);
      const diff = s.target - s.value;
      s.value = Math.abs(diff) < 0.0004 ? s.target : s.value + diff * k;
      if (s.value !== s.target) moving = true;
      s.update(s.value);
    }
    raf = moving ? requestAnimationFrame(frame) : 0;
    if (!moving) lastTime = 0;
  };
  const queue = () => { if (!raf) raf = requestAnimationFrame(frame); };
  addEventListener('scroll', queue, { passive: true });
  addEventListener('resize', queue);
  // Começa já na posição certa (ex.: página recarregada no meio).
  for (const s of scenes) { s.value = trackProgress(s.track); s.update(s.value); }
}

/* ---------- Downloads: arquivos oficiais do GitHub Releases ---------- */
const formatSize = (bytes) => `${Math.round(bytes / 1048576).toLocaleString('pt-BR')} MB`;

async function latestRelease() {
  try {
    const cached = sessionStorage.getItem('trabalhei-release');
    if (cached) return JSON.parse(cached);
  } catch { /* armazenamento indisponível */ }
  const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
    headers: { Accept: 'application/vnd.github+json' },
  });
  if (!res.ok) throw new Error(`GitHub respondeu ${res.status}`);
  const { tag_name, assets } = await res.json();
  const release = {
    tag: tag_name,
    assets: assets.map(({ name, size, browser_download_url }) => ({ name, size, url: browser_download_url })),
  };
  try { sessionStorage.setItem('trabalhei-release', JSON.stringify(release)); } catch { /* ignora */ }
  return release;
}

const setText = (selector, text) => document.querySelectorAll(selector).forEach((el) => (el.textContent = text));
const setHref = (selector, url) => document.querySelectorAll(selector).forEach((a) => (a.href = url));

async function setupDownloads() {
  let release;
  try {
    release = await latestRelease();
  } catch {
    return; // Mantém os links para a página de versões (sempre válidos).
  }
  const version = release.tag.replace(/^v/, '');
  const find = (re) => release.assets.find((a) => re.test(a.name));

  const apk = find(/\.apk$/i);
  if (apk) {
    setHref('[data-download="android"]', apk.url);
    setText('[data-android-version]', version);
    setText('[data-android-size]', formatSize(apk.size));
  }

  const exe = find(/windows.*\.exe$/i);
  const zip = find(/windows.*\.zip$/i);
  if (exe || zip) {
    setHref('[data-download="windows"]', (exe ?? zip).url);
    setText('[data-windows-version]', version);
    setText('[data-windows-size]', formatSize((exe ?? zip).size));
  }
  if (zip) setHref('[data-download="windows-zip"]', zip.url);
  else document.querySelectorAll('[data-download="windows-zip"]').forEach((a) => a.remove());
}

setupHeader();
setupIntro();
setupTilt();
setupReveal();
setupScenes();
setupDownloads();
// O <head> troca o modo quando a tela muda de proporção.
new MutationObserver(() => dispatchEvent(new Event('trabalhei:mode')))
  .observe(root, { attributes: true, attributeFilter: ['data-mode'] });
document.querySelectorAll('[data-year]').forEach((el) => (el.textContent = new Date().getFullYear()));
