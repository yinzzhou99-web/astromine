/* Astromine scroll story — Theatre.js choreography.
   Hero sheet plays once on load; every other sheet is
   scrubbed by the scroll position of its section.
   If anything here fails, the page stays fully visible:
   the .anim-pre hiding class is removed by a fallback
   timer in <head> and again in the catch block below. */
import { getProject, types } from './vendor/theatre-core.mjs';

const PROPS = {
  opacity: types.number(1, { range: [0, 1] }),
  y: types.number(0, { range: [-300, 300] }),
  x: types.number(0, { range: [-300, 300] }),
  scale: types.number(1, { range: [0, 2] }),
};

const SECTIONS = [
  ['Stats', '.stats'],
  ['Tiers', '#tier'],
  ['How', '#cara'],
  ['Pricing', '#harga'],
  ['Contracts', '#kontrak'],
  ['Faq', '#faq'],
];

const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

/* Stat numbers count up the first time the band appears. */
let counted = false;
function fmtN(n) {
  const lang = document.documentElement.lang || 'en-US';
  return n.toLocaleString(lang.startsWith('id') ? 'id-ID'
    : lang.startsWith('zh') ? 'zh-CN' : 'en-US');
}
function runCounters(force) {
  if (counted) return;
  counted = true;
  document.querySelectorAll('[data-count]').forEach((el) => {
    const target = Number(el.dataset.count);
    if (reduced || force === 1) { el.textContent = fmtN(target); return; }
    const t0 = performance.now(), dur = 1100;
    const step = (t) => {
      const p = Math.min(1, (t - t0) / dur);
      el.textContent = fmtN(Math.round(target * (1 - Math.pow(1 - p, 3))));
      if (p < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  });
}

try {
  const state = await (await fetch('theatre-state.json')).json();
  const project = getProject('Astromine', { state });
  await project.ready;

  const sheets = {};
  const sheetOf = (name) => (sheets[name] ??= project.sheet(name));

  document.querySelectorAll('[data-anim]').forEach((el) => {
    const obj = sheetOf(el.dataset.sheet).object(el.dataset.anim, PROPS);
    obj.onValuesChange((v) => {
      el.style.opacity = v.opacity;
      el.style.transform =
        `translate3d(${v.x}px, ${v.y}px, 0) scale(${v.scale})`;
    });
  });

  const hero = sheetOf('Hero');
  const scrollSheets = SECTIONS.map(([name, sel]) => ({
    sheet: sheetOf(name),
    el: document.querySelector(sel),
  })).filter((s) => s.el);

  window.__animReady = true;
  document.documentElement.classList.remove('anim-pre');

  if (reduced) {
    hero.sequence.position = hero.sequence.length;
    for (const { sheet } of scrollSheets) sheet.sequence.position = 1;
    runCounters(1);
  } else {
    hero.sequence.position = 0;
    hero.sequence.play({ iterationCount: 1 });
    let ticking = false;
    const update = () => {
      ticking = false;
      const vh = innerHeight;
      let statsP = 0;
      for (const { sheet, el } of scrollSheets) {
        const r = el.getBoundingClientRect();
        const start = vh * 0.92, end = vh * 0.38;
        const p = Math.min(1, Math.max(0, (start - r.top) / (start - end)));
        sheet.sequence.position = p;
        if (el.classList.contains('stats')) statsP = p;
      }
      if (statsP > 0.35) runCounters();
    };
    addEventListener('scroll', () => {
      if (!ticking) { ticking = true; requestAnimationFrame(update); }
    }, { passive: true });
    addEventListener('resize', update);
    update();
  }
} catch (e) {
  document.documentElement.classList.remove('anim-pre');
  console.warn('scroll story disabled:', e);
}
