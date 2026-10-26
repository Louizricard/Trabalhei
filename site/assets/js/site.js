// Homepage do Trabalhei: abertura, profundidade no cursor, demonstração guiada
// pela rolagem com recortes ampliados, transformação entre plataformas, entrada
// das seções e links de download. Sem dependências. Com "reduzir movimento", nada é animado
// nem fixado e as etapas passam a ser escolhidas por botões.

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

/* ---------- Demonstração guiada pela rolagem ---------- */
// Áreas de cada print do celular (em %) mostradas no recorte ampliado e
// destacadas pelo anel, na ordem de cada etapa. Medidas sobre os prints em
// site/assets/screens (585 × 1266); ao trocar um print, confira.
const SHOT = { w: 585, h: 1266 };
const DEMO_STEPS = [
  {
    img: '/assets/screens/phone-create-job-sm.webp',
    targets: [
      { x: 5.1, y: 30.2, w: 89.8, h: 26.7, note: 'Título e categoria do projeto' },
      { x: 5.1, y: 58.1, w: 89.8, h: 20.9, note: 'Descrição do que precisa ser feito' },
    ],
  },
  {
    img: '/assets/screens/phone-apply-sm.webp',
    targets: [
      { x: 5.1, y: 8.9, w: 89.8, h: 26.8, note: 'Propostas grátis restantes no mês e a vaga escolhida' },
      { x: 5.1, y: 38.1, w: 89.8, h: 20.2, note: 'Valor total e prazo da proposta' },
      { x: 5.1, y: 60.7, w: 89.8, h: 29.1, note: 'Carta de apresentação para o cliente' },
    ],
  },
  {
    img: '/assets/screens/phone-proposals-sm.webp',
    targets: [
      { x: 4.1, y: 8.5, w: 91.8, h: 11.1, note: 'Total, menor e maior proposta e prazo médio' },
      { x: 4.1, y: 21.6, w: 91.8, h: 38.5, note: 'Cada proposta, com Aceitar, Negociar e Chat' },
    ],
  },
  {
    img: '/assets/screens/phone-chat-sm.webp',
    targets: [
      { x: 4.1, y: 8.1, w: 91.8, h: 9.2, note: 'Aviso de entrega recebida no topo do chat' },
      { x: 4.1, y: 31.4, w: 91.8, h: 27.8, note: 'Prazos e pagamento combinados na conversa' },
      { x: 6.2, y: 61.5, w: 87.7, h: 28.9, note: 'A entrega, com o botão para revisar os arquivos e aprovar' },
    ],
  },
];
// Cada detalhe ocupa um trecho igual da rolagem, na ordem das etapas.
const DEMO_FRAMES = DEMO_STEPS.flatMap((s, step) => s.targets.map((_, target) => ({ step, target })));
const firstFrame = (step) => DEMO_FRAMES.findIndex((f) => f.step === step);

function setupDemo() {
  const section = document.querySelector('[data-demo]');
  const track = section.querySelector('[data-track]');
  const screens = [...section.querySelectorAll('.demo-screen')];
  const ring = section.querySelector('[data-ring]');
  const card = section.querySelector('[data-zoom-card]');
  const view = section.querySelector('[data-zoom]');
  const layers = [...view.querySelectorAll('.zoom-layer')];
  const phone = section.querySelector('.demo-phone');
  const stage = section.querySelector('.demo-stage');
  const steps = [...section.querySelectorAll('.demo-step')];
  const buttons = [...section.querySelectorAll('[data-step-button]')];
  const segments = [...section.querySelectorAll('[data-segment]')];
  const note = section.querySelector('[data-note]');
  const bar = section.querySelector('[data-demo-progress]');
  const hint = section.querySelector('[data-scene-hint]');
  let cur = { step: -1, target: -1 };
  let front = 0;

  // Tamanho do recorte: o maior que cabe ao lado do celular (ou na largura,
  // no celular) sem passar da altura reservada, nunca além do print original.
  const fit = (t) => {
    const phoneSpace = phone.offsetParent ? phone.offsetWidth + 28 : 0;
    const narrow = !phoneSpace;
    const maxW = Math.min(stage.clientWidth - phoneSpace, narrow ? 560 : 460, (SHOT.w * t.w) / 100);
    const maxH = innerHeight * (narrow ? 0.4 : 0.6);
    const ratio = (SHOT.w * t.w) / (SHOT.h * t.h);
    const width = Math.min(maxW, maxH * ratio);
    return { width, height: width / ratio };
  };

  // Posiciona o print na camada para mostrar só a área `t`.
  const paint = (layer, img, t, width) => {
    const bgW = (width * 100) / t.w;
    const bgH = (bgW * SHOT.h) / SHOT.w;
    layer.style.backgroundImage = `url('${img}')`;
    layer.style.backgroundSize = `${bgW.toFixed(1)}px auto`;
    layer.style.backgroundPosition = `${(-t.x / 100 * bgW).toFixed(1)}px ${(-t.y / 100 * bgH).toFixed(1)}px`;
  };

  const layout = (t) => {
    const { width, height } = fit(t);
    card.style.width = `${Math.round(width + 4)}px`;
    view.style.height = `${Math.round(height + 4)}px`;
    return width;
  };

  const show = (step, target) => {
    if (step === cur.step && target === cur.target) return;
    const t = DEMO_STEPS[step].targets[target];
    if (step !== cur.step) {
      screens.forEach((img, i) => {
        img.classList.toggle('is-leaving', i === cur.step);
        img.classList.toggle('is-active', i === step);
      });
      steps.forEach((li, i) => li.classList.toggle('is-active', i === step));
      buttons.forEach((b, i) => (i === step ? b.setAttribute('aria-current', 'step') : b.removeAttribute('aria-current')));
      // Já carrega o print da próxima etapa.
      new Image().src = DEMO_STEPS[(step + 1) % DEMO_STEPS.length].img;
    }
    for (const k of ['x', 'y', 'w', 'h']) ring.style.setProperty(`--${k}`, t[k]);
    front = 1 - front;
    paint(layers[front], DEMO_STEPS[step].img, t, layout(t));
    layers.forEach((l, i) => l.classList.toggle('is-active', i === front));
    view.setAttribute('aria-label', `Detalhe da tela: ${t.note}`);
    note.textContent = t.note;
    cur = { step, target };
  };

  const update = (p) => {
    const n = DEMO_FRAMES.length;
    const { step, target } = DEMO_FRAMES[Math.min(n - 1, Math.floor(p * n))];
    show(step, target);
    bar.style.setProperty('--p', p.toFixed(4));
    segments.forEach((seg, i) => {
      const start = firstFrame(i);
      const count = DEMO_STEPS[i].targets.length;
      seg.style.setProperty('--p', clamp((p * n - start) / count).toFixed(4));
    });
    hint.classList.toggle('is-hidden', p > 0.9);
  };

  buttons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const i = Number(btn.dataset.stepButton);
      if (reduced) {
        // Sem rolagem guiada: tocar de novo na etapa mostra o próximo detalhe.
        const next = i === cur.step ? (cur.target + 1) % DEMO_STEPS[i].targets.length : 0;
        show(i, next);
        const done = (firstFrame(i) + next + 1) / DEMO_FRAMES.length;
        bar.style.setProperty('--p', done.toFixed(3));
      } else {
        scrollToProgress(track, (firstFrame(i) + 0.5) / DEMO_FRAMES.length);
      }
    });
  });

  addEventListener('resize', () => {
    const { step, target } = cur;
    const t = DEMO_STEPS[step].targets[target];
    paint(layers[front], DEMO_STEPS[step].img, t, layout(t));
  });

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
