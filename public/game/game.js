/* La cameretta — il gioco.
   Scene: menu → strada innevata → salotto → cameretta (punta e clicca).
   I contenuti arrivano da /api/public (server locale) o, in mancanza, da data.json. */
{
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const safeUrl = u => /^(https?:\/\/|\/|\.\/|assets\/|mailto:)/i.test(u || '') ? u : '';
const store = {get(k,d){try{const v=localStorage.getItem('cam_'+k);return v===null?d:JSON.parse(v)}catch(e){return d}},set(k,v){try{localStorage.setItem('cam_'+k,JSON.stringify(v))}catch(e){}}};
const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
const touch = matchMedia('(pointer: coarse)').matches;
const wait = ms => new Promise(r => setTimeout(r, ms));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rnd = (a, b) => a + Math.random() * (b - a);
const GROUPS = ['letto','scrivania','lavagna','libreria','finestra'];
if(touch) document.body.classList.add('touch');

/* ================================================================ lingue */
const T = {
  en: {
    tips: ['Tip: use <kbd>←</kbd> <kbd>→</kbd> to walk, hold <kbd>SHIFT</kbd> to run.', 'Tip: press <kbd>E</kbd> near a door to go inside.', 'Tip: in my room, click the objects to open them.', 'Tip: the lit window on the menu takes you straight in.'],
    room: 'GO STRAIGHT TO MY ROOM', language: 'LANGUAGE', langName: 'ENGLISH', audio: 'AUDIO', on: 'ON', off: 'OFF', help: 'HOW TO PLAY',
    street: 'the street', living: 'the living room',
    hintWalk: '<kbd>←</kbd><kbd>→</kbd> walk · <kbd>SHIFT</kbd> run · <kbd>E</kbd> interact', hintRoom: 'click an object · <kbd>←</kbd><kbd>→</kbd> choose · <kbd>ENTER</kbd> open',
    enterHouse: 'Go inside', tv: 'Change channel', fire: 'Warm your hands', door: 'Enter my room', warm: 'Ahh, much better.',
    back: '◀ Living room', skip: 'Skip ▸', explored: 'OBJECTS EXPLORED', sheet: 'What do you want to explore?', close: 'CLOSE',
    empty: 'Nothing here yet. Come back soon.', find: 'Where to find me', cv: 'Open my CV', rotate: 'Turn your phone sideways for a bigger view',
    titles: { street: 'A SNOWY NIGHT', living: 'HOME, SWEET HOME', room: 'MY LITTLE ROOM' },
    helpTitle: 'How to play',
    helpItems: ['Walk down the snowy street with <kbd>←</kbd> <kbd>→</kbd> (or <kbd>A</kbd> <kbd>D</kbd>). Hold <kbd>SHIFT</kbd> to run. On a phone, use the arrows or tap where you want to go.', 'Read the bubbles along the way: they tell you who I am.', 'At the house, and near the TV, the fireplace and the glowing door, press <kbd>E</kbd> (or the yellow button).', 'In my room, every object opens a part of my portfolio. <kbd>ESC</kbd> goes back.'],
    noServer: 'Start the server (python server.py) to load the content'
  },
  it: {
    tips: ['Suggerimento: <kbd>←</kbd> <kbd>→</kbd> per camminare, tieni premuto <kbd>SHIFT</kbd> per correre.', 'Suggerimento: premi <kbd>E</kbd> vicino a una porta per entrare.', 'Suggerimento: in cameretta clicca gli oggetti per aprirli.', 'Suggerimento: nel menu, la finestra accesa ti porta subito dentro.'],
    room: 'VAI SUBITO IN CAMERETTA', language: 'LINGUA', langName: 'ITALIANO', audio: 'AUDIO', on: 'ON', off: 'OFF', help: 'COME SI GIOCA',
    street: 'la strada', living: 'il salotto',
    hintWalk: '<kbd>←</kbd><kbd>→</kbd> cammina · <kbd>SHIFT</kbd> corri · <kbd>E</kbd> interagisci', hintRoom: 'clicca un oggetto · <kbd>←</kbd><kbd>→</kbd> scegli · <kbd>INVIO</kbd> apri',
    enterHouse: 'Entra in casa', tv: 'Cambia canale', fire: 'Scaldati le mani', door: 'Entra in cameretta', warm: 'Ahh, molto meglio.',
    back: '◀ Salotto', skip: 'Salta ▸', explored: 'OGGETTI ESPLORATI', sheet: 'Cosa vuoi esplorare?', close: 'CHIUDI',
    empty: 'Qui non c\'è ancora niente. Torna presto.', find: 'Dove trovarmi', cv: 'Apri il CV', rotate: 'Gira il telefono per vedere meglio',
    titles: { street: 'UNA NOTTE DI NEVE', living: 'CASA, DOLCE CASA', room: 'LA MIA CAMERETTA' },
    helpTitle: 'Come si gioca',
    helpItems: ['Percorri la strada innevata con <kbd>←</kbd> <kbd>→</kbd> (o <kbd>A</kbd> <kbd>D</kbd>). Tieni <kbd>SHIFT</kbd> per correre. Da telefono usa le frecce o tocca dove vuoi andare.', 'Leggi le bolle lungo la strada: ti raccontano chi sono.', 'Davanti a casa, e vicino a TV, camino e porta luminosa, premi <kbd>E</kbd> (o il pulsante giallo).', 'In cameretta ogni oggetto apre una parte del portfolio. <kbd>ESC</kbd> torna indietro.'],
    noServer: 'Avvia il server (python server.py) per caricare i contenuti'
  }
};
let lang = 'en';
const t = k => (T[lang] || T.en)[k];
const L = (o, k) => (lang === 'en' && o && o[k + '_en']) ? o[k + '_en'] : (o ? o[k] : '');

/* ================================================================ stato */
let DATA = null, S = {}, SECTIONS = [], byId = {}, BUBBLES = [];
let IMG = {}, J = {};
let explored = new Set(store.get('explored', []));
let audioOn = true;
let scene = 'menu', busy = false;

function toast(msg){ const el = $('#toast'); el.textContent = msg; el.hidden = false; clearTimeout(toast.h); toast.h = setTimeout(() => el.hidden = true, 3000); }
async function loadJSON(url){ const r = await fetch(url, {cache:'no-store'}); if(!r.ok) throw new Error(url); return r.json(); }
function loadImg(src){ return new Promise((ok, ko) => { const i = new Image(); i.onload = () => ok(i); i.onerror = ko; i.src = src; }); }

/* ================================================================ musica */
let music = null, musicFade = null;
const musicVol = () => clamp(parseFloat(S.music_volume) || .35, 0, 1);
function fadeMusic(to, ms = 700){
  if(!music) return;
  clearInterval(musicFade);
  const from = music.volume, steps = 14; let k = 0;
  musicFade = setInterval(() => { k++; music.volume = clamp(from + (to - from) * k / steps, 0, 1); if(k >= steps){ clearInterval(musicFade); if(to === 0) music.pause(); } }, ms / steps);
}
function startMusic(){
  if(!audioOn || !safeUrl(S.music_url) || document.hidden) return;
  if(!music){ music = new Audio(S.music_url); music.loop = true; music.volume = 0; }
  music.play().then(() => fadeMusic(musicVol())).catch(() => {});
}
function duckMusic(){ if(music && !music.paused){ fadeMusic(musicVol() * .25, 300); setTimeout(() => { if(audioOn && music && !music.paused) fadeMusic(musicVol(), 900); }, 900); } }
document.addEventListener('visibilitychange', () => { if(!music) return; if(document.hidden) music.pause(); else if(audioOn) startMusic(); });
const SPK_ON = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="square" aria-hidden="true"><path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M17 8c2 2 2 6 0 8M20 5c4 4 4 10 0 14"/></svg>';
const SPK_OFF = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="square" aria-hidden="true"><path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M17 9l5 6M22 9l-5 6"/></svg>';
function setAudio(on){
  audioOn = on; store.set('audio', on);
  SFX.setEnabled(on);
  if(on) startMusic(); else fadeMusic(0, 400);
  $('#audioVal').textContent = on ? t('on') : t('off');
  for(const b of [$('#bAudio'), $('#mAudio')]){ b.innerHTML = on ? SPK_ON : SPK_OFF; b.setAttribute('aria-label', 'Audio ' + (on ? t('on') : t('off'))); }
}

/* ================================================================ layout */
let scale = 1, mobile = false;
function layout(){
  const vw = innerWidth, vh = innerHeight;
  mobile = vw < 760 && vh > vw;
  document.body.classList.toggle('mobile', mobile);
  const vp = $('#vp'), wrap = $('#stageWrap'), stage = $('#stage');
  if(!mobile){
    scale = Math.min(vw / 1280, vh / 800);
    Object.assign(vp.style, {left: ((vw - 1280 * scale) / 2) + 'px', top: ((vh - 800 * scale) / 2) + 'px', width: (1280 * scale) + 'px', height: (800 * scale) + 'px'});
  } else if(scene === 'room'){
    const sheetH = $('#sheet').offsetHeight || 300;
    const h = Math.max(240, vh - 60 - sheetH);
    scale = h / 800;
    Object.assign(vp.style, {left: '0px', top: '60px', width: vw + 'px', height: h + 'px'});
  } else {
    scale = vw / 1280;
    Object.assign(vp.style, {left: '0px', top: '60px', width: vw + 'px', height: (800 * scale) + 'px'});
    document.body.style.setProperty('--stageH', (800 * scale) + 'px');
  }
  wrap.style.width = (1280 * scale) + 'px'; wrap.style.height = (800 * scale) + 'px';
  stage.style.transform = `scale(${scale})`;
  if(mobile && scene === 'room' && !layout.centered){ vp.scrollLeft = (1280 * scale - vw) / 2 + 40 * scale; layout.centered = true; }
}
addEventListener('resize', layout);

/* ================================================================ testi */
function applyTexts(){
  document.documentElement.lang = lang;
  const set = (id, v) => { const el = $(id); if(el) el.textContent = v || ''; };
  set('#tKicker', L(S, 'menu_kicker')); set('#tName', S.site_name); set('#tSub', L(S, 'menu_subtitle')); set('#tTag', L(S, 'menu_tagline'));
  set('#miEnter', L(S, 'menu_enter_label') || 'START'); set('#miRoom', t('room')); set('#miLang', t('language')); set('#langVal', t('langName'));
  set('#miAudio', t('audio')); set('#audioVal', audioOn ? t('on') : t('off')); set('#miHelp', t('help'));
  set('#tPress', L(S, 'press_text')); set('#tFoot', L(S, 'footer_text'));
  set('#cName', S.site_name); set('#mName', S.site_name);
  set('#bBack', t('back')); set('#bSkip', t('skip')); set('#mSkip', t('skip')); set('#rotate', t('rotate'));
  for(const b of [$('#bLang'), $('#mLang')]){ b.textContent = lang.toUpperCase(); b.setAttribute('aria-label', t('language') + ': ' + t('langName')); }
  const git = $('#tGit'); if(safeUrl(S.github_url)){ git.href = S.github_url; git.textContent = S.github_url.replace(/^https?:\/\//, ''); } else git.hidden = true;
  document.title = (S.site_name || 'Eracul') + ' · ' + (L(S, 'room_crumb') || 'the little room');
  if(S.accent_color && /^#[0-9a-f]{3,8}$/i.test(S.accent_color)) document.documentElement.style.setProperty('--gold', S.accent_color);
  if(scene !== 'menu') hudFor(scene);
  refreshBubbles();
  if(scene === 'room'){ renderSign(); renderProgress(); renderHotButtons(); }
  if(openId && openId !== '_info') openSection(openId, true);
  else if(openId === '_info') openInfo(infoKind, true);
}
function setLang(l){ lang = l === 'it' ? 'it' : 'en'; store.set('lang', lang); applyTexts(); }

/* ================================================================ menu */
const skyfx = $('#skyfx'), sctx = skyfx.getContext('2d');
let customSky = false, shooting = null, menuSel = 0;
const menuItems = () => [...document.querySelectorAll('#menuNav .mi')];
function selMenu(i){ const it = menuItems(); menuSel = (i + it.length) % it.length; it.forEach((b, k) => b.classList.toggle('sel', k === menuSel)); }
function drawSky(time){
  sctx.clearRect(0, 0, 320, 200);
  const ma = J.menu;
  if(!customSky && ma){
    for(let i = 0; i < ma.stars.length; i++){
      const [x, y, k] = ma.stars[i]; if(k === 0) continue;
      const tw = Math.sin(time / 600 + i * 1.7);
      if(tw > .55){ sctx.fillStyle = '#fffbe6'; sctx.fillRect(x - 1, y, 3, 1); sctx.fillRect(x, y - 1, 1, 3); if(k === 2 && tw > .85){ sctx.fillRect(x - 2, y, 5, 1); sctx.fillRect(x, y - 2, 1, 5); } }
      else if(tw < -.6){ sctx.fillStyle = 'rgba(15,15,38,.75)'; sctx.fillRect(x, y, 1, 1); }
    }
    const [wx0, wy0, wx1, wy1] = ma.window;
    const f = .10 + .06 * Math.sin(time / 300) + (Math.random() < .03 ? .08 : 0);
    sctx.fillStyle = `rgba(255,220,140,${f})`; sctx.fillRect(wx0 - 2, wy0 - 2, wx1 - wx0 + 4, wy1 - wy0 + 4);
  }
  if(S.menu_shooting_stars !== '0'){
    if(!shooting && Math.random() < .006) shooting = {x: 80 + Math.random() * 200, y: 6 + Math.random() * 50, l: 0};
    if(shooting){
      shooting.l += 1;
      for(let k = 0; k < 10; k++){ sctx.fillStyle = `rgba(255,248,220,${1 - k / 10})`; sctx.fillRect(Math.round(shooting.x + shooting.l * 3 - k * 2), Math.round(shooting.y + shooting.l * 1.4 - k * .9), 1, 1); }
      if(shooting.l > 26) shooting = null;
    }
  }
}
function skyPoint(e){
  const r = skyfx.getBoundingClientRect(), s = Math.max(r.width / 320, r.height / 200);
  return [(e.clientX - r.left - (r.width - 320 * s) * (mobile ? .15 : .3)) / s, (e.clientY - r.top - (r.height - 200 * s) * .5) / s];
}
const onWindow = e => { if(customSky || !J.menu) return false; const [x, y] = skyPoint(e), [x0, y0, x1, y1] = J.menu.window; return x > x0 - 8 && x < x1 + 8 && y > y0 - 8 && y < y1 + 8; };
skyfx.addEventListener('click', e => { if(onWindow(e)) startGame(); });
skyfx.addEventListener('mousemove', e => { skyfx.style.cursor = onWindow(e) ? 'pointer' : 'default'; });
$('#menuNav').addEventListener('click', e => { const b = e.target.closest('.mi'); if(b){ selMenu(menuItems().indexOf(b)); menuAct(b.dataset.act); } });
$('#menuNav').addEventListener('mousemove', e => { const b = e.target.closest('.mi'); if(b){ const i = menuItems().indexOf(b); if(i !== menuSel){ selMenu(i); SFX.move(); } } });
function menuAct(a){
  SFX.unlock();
  if(a === 'enter') startGame();
  else if(a === 'room') startGame(true);
  else if(a === 'lang'){ SFX.select(); setLang(lang === 'en' ? 'it' : 'en'); }
  else if(a === 'audio'){ setAudio(!audioOn); SFX.select(); }
  else if(a === 'help') openInfo('help');
}

/* ================================================================ input */
const keys = new Set();
let padDir = 0, tapTarget = null;
function heldDir(){
  let d = 0;
  if(keys.has('ArrowLeft') || keys.has('KeyA')) d -= 1;
  if(keys.has('ArrowRight') || keys.has('KeyD')) d += 1;
  return d || padDir;
}
function bindHold(el, dir){
  const on = e => { e.preventDefault(); padDir = dir; tapTarget = null; SFX.unlock(); };
  const off = e => { e.preventDefault(); if(padDir === dir) padDir = 0; };
  el.addEventListener('pointerdown', on); el.addEventListener('pointerup', off); el.addEventListener('pointercancel', off); el.addEventListener('pointerleave', off);
}
bindHold($('#pL'), -1); bindHold($('#pR'), 1);
$('#pA').addEventListener('click', () => doAction());
$('#prompt').addEventListener('click', () => doAction());

/* ================================================================ omino */
const P = {x: 40, dir: 1, moving: false, anim: 0, idle: 0, frame: 0, lastStep: -1, breath: 2};
function updatePlayer(dt, minX, maxX, stepSound){
  let d = heldDir();
  if(!d && tapTarget !== null){
    if(Math.abs(tapTarget - P.x) < 2) tapTarget = null; else d = Math.sign(tapTarget - P.x);
  }
  const run = keys.has('ShiftLeft') || keys.has('ShiftRight');
  if(d && !busy){
    P.dir = d; P.moving = true;
    const nx = clamp(P.x + d * (run ? 69 : 41) * dt, minX, maxX);
    if(nx === P.x) { P.moving = false; tapTarget = null; } else P.x = nx;
  } else P.moving = false;
  if(P.moving){
    P.anim += dt * (run ? 10 : 6.7);
    const f = Math.floor(P.anim) % 6;
    if(f !== P.lastStep && (f === 2 || f === 5)) stepSound();
    P.lastStep = f; P.frame = J.player.walk[f];
  } else {
    P.idle += dt * 3; P.lastStep = -1; P.frame = J.player.idle[Math.floor(P.idle) % 4];
  }
}
function drawPlayer(ctx, sx, feet, shadow = 'rgba(20,24,60,.35)'){
  const fw = J.player.fw, fh = J.player.fh;
  ctx.fillStyle = shadow;
  ctx.beginPath(); ctx.ellipse(Math.round(sx), feet + 1, 8, 2, 0, 0, Math.PI * 2); ctx.fill();
  const x = Math.round(sx - fw / 2), y = feet - J.player.footY;
  if(P.dir < 0){ ctx.save(); ctx.translate(x + fw, y); ctx.scale(-1, 1); ctx.drawImage(IMG.player, P.frame * fw, 0, fw, fh, 0, 0, fw, fh); ctx.restore(); }
  else ctx.drawImage(IMG.player, P.frame * fw, 0, fw, fh, x, y, fw, fh);
}

/* ================================================================ prompt di azione */
let promptAction = null;
function showPrompt(worldX, y, label, action, camX = 0){
  const pr = $('#prompt');
  if(promptAction !== action || pr.hidden || pr.dataset.l !== label){
    pr.innerHTML = `${touch ? '' : '<kbd>E</kbd>'}<span>${esc(label)}</span>`; pr.dataset.l = label;
    pr.hidden = false; $('#pA').hidden = false; $('#pA').textContent = touch ? '★' : 'E';
    if(!promptAction || promptAction !== action) SFX.hover();
  }
  promptAction = action;
  pr.style.left = ((worldX - camX) * 4) + 'px'; pr.style.top = (y * 4) + 'px';
}
function hidePrompt(){ if(promptAction){ promptAction = null; $('#prompt').hidden = true; $('#pA').hidden = true; } }
function doAction(){ if(promptAction && !busy) promptAction(); }

/* ================================================================ strada */
const ST = {camX: 0, flakes: [], smoke: [], puffs: [], bub: []};
function makeFlakes(n){
  const f = [];
  for(let i = 0; i < n; i++){ const z = Math.random() < .6 ? .5 : 1.1; f.push({x: rnd(0, 320), y: rnd(-200, 200), z, vy: z * rnd(9, 16), ph: rnd(0, 6)}); }
  return f;
}
function buildBubbles(){
  const host = $('#bubbles'); host.innerHTML = ''; ST.bub = [];
  const s = J.street, n = BUBBLES.length; if(!n) return;
  const x0 = 210, x1 = s.stop - 200, step = n > 1 ? (x1 - x0) / (n - 1) : 0;
  BUBBLES.forEach((b, i) => {
    const el = document.createElement('div');
    el.className = 'bub' + (b.kind === 'quote' ? ' quote' : '');
    const x = x0 + i * step, top = i % 2 ? 136 : 84;
    el.style.left = (x * 4 - 60) + 'px'; el.style.top = top + 'px';
    el.innerHTML = (b.kind === 'quote' ? '<span class="qm" aria-hidden="true">“</span>' : '') + '<p><span class="txt"></span><span class="caret"></span></p>' + (b.kind === 'quote' && b.author ? `<p class="auth">— ${esc(b.author)}</p>` : '');
    host.appendChild(el);
    ST.bub.push({x, el, data: b, state: 'idle', timer: null});
  });
}
function typeBubble(B){
  B.state = 'typing'; B.el.classList.add('show');
  const txt = B.el.querySelector('.txt'), full = L(B.data, 'text');
  let i = 0;
  const next = () => {
    if(B.state !== 'typing') return;
    i++; txt.textContent = full.slice(0, i);
    SFX.key(full[i - 1]);
    mirror(B, full.slice(0, i), i >= full.length);
    if(i >= full.length){ B.state = 'done'; B.el.classList.add('done'); return; }
    const ch = full[i - 1];
    B.timer = setTimeout(next, reduced ? 4 : ('.!?'.includes(ch) ? 220 : ',;:'.includes(ch) ? 120 : rnd(24, 46)));
  };
  B.timer = setTimeout(next, 260);
}
// su telefono in verticale le bolle sono piccole: il testo si ripete in un riquadro grande sotto la scena
function mirror(B, text, done){
  const d = $('#mDialog'); if(!mobile) return;
  d.className = B.data.kind === 'quote' ? 'quote' : '';
  d.innerHTML = esc(text) + (done && B.data.kind === 'quote' && B.data.author ? `<span class="auth">— ${esc(B.data.author)}</span>` : '');
}
function refreshBubbles(){
  for(const B of ST.bub){
    if(B.state === 'idle') continue;
    clearTimeout(B.timer); B.state = 'done';
    B.el.querySelector('.txt').textContent = L(B.data, 'text'); B.el.classList.add('show', 'done');
  }
  const last = [...ST.bub].reverse().find(B => B.state !== 'idle');
  if(last) mirror(last, L(last.data, 'text'), true);
}
function updateStreet(dt){
  const s = J.street;
  updatePlayer(dt, 14, s.stop, SFX.stepSnow);
  ST.camX = clamp(P.x - 120, 0, s.world - 320);
  $('#bubbles').style.transform = `translateX(${-ST.camX * 4}px)`;
  for(const B of ST.bub) if(B.state === 'idle' && P.x > B.x - 150) typeBubble(B);
  if(Math.abs(P.x - s.door.x) < 26) showPrompt(s.door.x, s.door.y - 26, t('enterHouse'), goLiving, ST.camX); else hidePrompt();
  // fumo dal comignolo
  if(Math.random() < dt * 6) ST.smoke.push({x: s.chimney.x + rnd(-2, 2), y: s.chimney.y, r: 1.5, a: .5, vx: rnd(-7, -3), vy: rnd(-9, -6)});
  for(const p of ST.smoke){ p.x += p.vx * dt; p.y += p.vy * dt; p.r += dt * 2.2; p.a -= dt * .12; }
  ST.smoke = ST.smoke.filter(p => p.a > 0);
  // respiro nel freddo
  P.breath -= dt;
  if(P.breath <= 0){ P.breath = rnd(2.2, 3.4); for(let k = 0; k < 4; k++) ST.puffs.push({x: P.x + P.dir * 7, y: J.street.feet - 31, vx: P.dir * rnd(5, 10), vy: rnd(-5, -2), a: .55, d: k * .06}); }
  for(const p of ST.puffs){ if(p.d > 0){ p.d -= dt; continue; } p.x += p.vx * dt; p.y += p.vy * dt; p.a -= dt * .5; }
  ST.puffs = ST.puffs.filter(p => p.a > 0);
}
function snow(ctx, flakes, dt, dx, front){
  for(const f of flakes){
    if((f.z > 1) !== front) continue;
    f.y += f.vy * dt; f.x += (Math.sin(f.y / 14 + f.ph) * 6 - 4) * dt * f.z - dx * f.z;
    if(f.y > 200){ f.y = -4; f.x = rnd(0, 320); }
    if(f.x < -4) f.x += 328; if(f.x > 324) f.x -= 328;
    ctx.fillStyle = f.z > 1 ? 'rgba(255,255,255,.95)' : 'rgba(220,230,255,.6)';
    ctx.fillRect(Math.round(f.x), Math.round(f.y), f.z > 1 ? 2 : 1, f.z > 1 ? 2 : 1);
  }
}
let lastCam = 0;
function drawStreet(ctx, time, dt){
  const s = J.street, cam = Math.round(ST.camX), dcam = cam - lastCam; lastCam = cam;
  ctx.drawImage(IMG.far, -Math.round(cam * s.pfar), 0);
  ctx.drawImage(IMG.mid, -Math.round(cam * s.pmid), 0);
  snow(ctx, ST.flakes, dt, dcam * .4, false);
  ctx.drawImage(IMG.near, -cam, 0);
  // lampioni che pulsano piano
  ctx.globalCompositeOperation = 'lighter';
  for(const l of s.lamps){
    const x = l.x - cam; if(x < -40 || x > 360) continue;
    const a = .07 + .02 * Math.sin(time / 500 + l.x);
    const g = ctx.createRadialGradient(x, 64, 1, x, 64, 22); g.addColorStop(0, `rgba(255,210,140,${a * 2})`); g.addColorStop(1, 'rgba(255,210,140,0)');
    ctx.fillStyle = g; ctx.fillRect(x - 22, 42, 44, 44);
  }
  for(const w of s.windows){ const x = w[0] - cam; if(x > -40 && x < 360){ ctx.fillStyle = `rgba(255,190,110,${.05 + .03 * Math.sin(time / 260 + w[0])})`; ctx.fillRect(x, w[1], w[2] - w[0], w[3] - w[1]); } }
  ctx.globalCompositeOperation = 'source-over';
  for(const p of ST.smoke){ ctx.fillStyle = `rgba(210,214,236,${Math.max(0, p.a)})`; ctx.beginPath(); ctx.arc(Math.round(p.x - cam), Math.round(p.y), p.r, 0, Math.PI * 2); ctx.fill(); }
  drawPlayer(ctx, P.x - cam, s.feet);
  for(const p of ST.puffs){ if(p.d > 0) continue; ctx.fillStyle = `rgba(240,244,255,${p.a})`; ctx.fillRect(Math.round(p.x - cam), Math.round(p.y), 1, 1); }
  snow(ctx, ST.flakes, dt, dcam, true);
}

/* ================================================================ salotto */
const LV = {ch: store.get('tv', 0), sparks: [], flakes: [], steam: [], warm: 0};
function updateLiving(dt){
  const l = J.living;
  updatePlayer(dt, 12, l.stop, SFX.stepWood);
  SFX.proximity({fire: clamp(1 - Math.abs(P.x - l.spots.fire) / 120, 0, 1), tv: clamp(1 - Math.abs(P.x - l.spots.tv) / 110, 0, 1)});
  const spots = [['door', l.spots.door, l.door[1] - 20, t('door'), goRoom], ['tv', l.spots.tv, l.tv[1] - 22, t('tv'), changeChannel], ['fire', l.spots.fire, 46, LV.warm > 0 ? t('warm') : t('fire'), warmHands]];
  const near = spots.filter(s => Math.abs(P.x - s[1]) < 20).sort((a, b) => Math.abs(P.x - a[1]) - Math.abs(P.x - b[1]))[0];
  if(near) showPrompt(near[1], near[2], near[3], near[4]); else hidePrompt();
  LV.warm = Math.max(0, LV.warm - dt);
  for(const p of LV.sparks){ p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 20 * dt; p.a -= dt * .9; }
  LV.sparks = LV.sparks.filter(p => p.a > 0);
  if(Math.random() < dt * 3) LV.steam.push({y: 0, ph: rnd(0, 6)});
  for(const p of LV.steam) p.y += dt * 6;
  LV.steam = LV.steam.filter(p => p.y < 14);
}
function changeChannel(){ LV.ch = (LV.ch + 1) % 4; store.set('tv', LV.ch); SFX.channel(); SFX.tv(LV.ch); }
function warmHands(){
  LV.warm = 2.4; SFX.pop();
  const f = J.living.fire;
  for(let k = 0; k < 22; k++) LV.sparks.push({x: rnd(f[0] + 6, f[2] - 6), y: f[3] - 6, vx: rnd(-14, 14), vy: rnd(-46, -18), a: 1});
}
function drawFire(ctx, time){
  const [x0, y0, x1, y1] = J.living.fire, tick = Math.floor(time / 90);
  for(let x = x0; x <= x1; x++){
    const c = (x - x0) / (x1 - x0);
    const base = Math.sin(c * Math.PI);
    const h = Math.max(0, (y1 - y0) * (.35 + .55 * base) * (.75 + .25 * Math.sin(tick * 1.7 + x * .9) + .15 * Math.sin(tick * .6 + x * 2.3)) * (1 + LV.warm * .12));
    for(let k = 0; k < h; k++){
      const r = k / h;
      ctx.fillStyle = r < .35 ? '#fff1b8' : r < .6 ? '#ffc04a' : r < .85 ? '#f0702a' : '#b8321e';
      if(r > .85 && (x + k + tick) % 2) continue;
      ctx.fillRect(x, y1 - k, 1, 1);
    }
  }
  if(tick % 3 === 0 && Math.random() < .5) LV.sparks.push({x: rnd(x0 + 8, x1 - 8), y: y1 - 14, vx: rnd(-6, 6), vy: rnd(-30, -16), a: .9});
}
function drawTV(ctx, time){
  const [x0, y0, x1, y1] = J.living.tv, w = x1 - x0 + 1, h = y1 - y0 + 1, tick = Math.floor(time / 100);
  ctx.save(); ctx.beginPath(); ctx.rect(x0, y0, w, h); ctx.clip();
  if(LV.ch === 0){            // tramonto sul mare
    const g = ctx.createLinearGradient(0, y0, 0, y1); g.addColorStop(0, '#ff9a6b'); g.addColorStop(.55, '#ffd28a'); g.addColorStop(.56, '#2c5d8f'); g.addColorStop(1, '#1b3557');
    ctx.fillStyle = g; ctx.fillRect(x0, y0, w, h);
    ctx.fillStyle = '#fff1c2'; ctx.beginPath(); ctx.arc(x0 + w * .6, y0 + h * .52, 5, Math.PI, 0); ctx.fill();
    for(let k = 0; k < 6; k++){ const yy = y0 + h * .6 + k * 2; ctx.fillStyle = 'rgba(255,220,160,.6)'; ctx.fillRect(x0 + ((tick * (k + 1) * 2 + k * 9) % w), yy, 4, 1); }
  } else if(LV.ch === 1){     // telegiornale
    ctx.fillStyle = '#20407a'; ctx.fillRect(x0, y0, w, h);
    ctx.fillStyle = '#d8e4ff'; ctx.fillRect(x0 + 4, y0 + 5, 14, 12);
    ctx.fillStyle = '#f2c79a'; ctx.fillRect(x0 + 8, y0 + 7, 6, 5); ctx.fillStyle = '#3a2a24'; ctx.fillRect(x0 + 8, y0 + 6, 6, 2); ctx.fillStyle = '#2b2550'; ctx.fillRect(x0 + 6, y0 + 12, 10, 5);
    ctx.fillStyle = '#ffffff'; for(let k = 0; k < 3; k++) ctx.fillRect(x0 + 22, y0 + 6 + k * 4, 18 - k * 4, 2);
    ctx.fillStyle = '#c83a32'; ctx.fillRect(x0, y1 - 6, w, 6);
    ctx.fillStyle = '#ffffff'; for(let k = 0; k < 9; k++) ctx.fillRect(x0 + ((k * 9 - tick * 2) % (w + 20) + w + 20) % (w + 20) - 10, y1 - 4, 5, 2);
  } else if(LV.ch === 2){     // neve statica
    for(let yy = y0; yy <= y1; yy++) for(let xx = x0; xx <= x1; xx += 1){ const v = Math.random() * 200 | 0; ctx.fillStyle = `rgb(${v},${v},${v + 10})`; ctx.fillRect(xx, yy, 1, 1); }
    ctx.fillStyle = 'rgba(255,255,255,.15)'; ctx.fillRect(x0, y0 + (tick * 2) % h, w, 3);
  } else {                    // pong
    ctx.fillStyle = '#0c0c18'; ctx.fillRect(x0, y0, w, h);
    const bx = x0 + 4 + Math.abs(((tick * 2) % ((w - 8) * 2)) - (w - 8)), by = y0 + 3 + Math.abs(((tick * 3) % ((h - 6) * 2)) - (h - 6));
    ctx.fillStyle = '#ffffff'; ctx.fillRect(bx, by, 2, 2);
    ctx.fillRect(x0 + 2, clamp(by - 4, y0 + 1, y1 - 8), 2, 8); ctx.fillRect(x1 - 3, clamp(by - 3, y0 + 1, y1 - 8), 2, 8);
    for(let yy = y0; yy < y1; yy += 4) ctx.fillRect(x0 + (w >> 1), yy, 1, 2);
  }
  for(let yy = y0; yy <= y1; yy += 2){ ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.fillRect(x0, yy, w, 1); }
  ctx.restore();
}
function drawLiving(ctx, time, dt){
  const l = J.living;
  ctx.drawImage(IMG.living, 0, 0);
  // neve dalla finestra
  const [wx0, wy0, wx1, wy1] = l.window;
  ctx.save(); ctx.beginPath(); ctx.rect(wx0, wy0, wx1 - wx0, wy1 - wy0 - 3); ctx.clip();
  for(const f of LV.flakes){ f.y += f.vy * dt * .7; f.x += Math.sin(f.y / 9 + f.ph) * dt * 4; if(f.y > wy1){ f.y = wy0 - 2; f.x = rnd(wx0, wx1); } ctx.fillStyle = 'rgba(240,246,255,.9)'; ctx.fillRect(Math.round(f.x), Math.round(f.y), 1, 1); }
  ctx.restore();
  drawFire(ctx, time);
  drawTV(ctx, time);
  // lucine
  const cols = ['#ff7a6e', '#ffd36a', '#8ce69e', '#8ec8ff'];
  l.fairy.forEach(([x, y], i) => { const on = Math.sin(time / 380 + i * 1.3) > -.3; ctx.fillStyle = on ? cols[i % 4] : '#5a4a40'; ctx.fillRect(x, y, 1, 2); });
  // pendolo
  const [cx, cy, cb] = l.clock, a = .32 * Math.sin(time / 1000 * Math.PI);
  const px = cx + Math.sin(a) * (cb - cy - 4), py = cy + Math.cos(a) * (cb - cy - 4);
  ctx.strokeStyle = '#d9b46a'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(cx + .5, cy); ctx.lineTo(px + .5, py); ctx.stroke();
  ctx.fillStyle = '#f2c86a'; ctx.fillRect(Math.round(px) - 1, Math.round(py) - 1, 3, 3);
  // vapore della tazza
  const [mx, my] = l.mug;
  for(const p of LV.steam){ ctx.fillStyle = `rgba(250,250,255,${Math.max(0, .7 - p.y / 18)})`; ctx.fillRect(Math.round(mx + Math.sin(p.y / 2.5 + p.ph) * 1.3), Math.round(my - p.y), 1, 1); }
  // luci additive: fuoco, TV, porta
  ctx.globalCompositeOperation = 'lighter';
  const fl = .09 + .03 * Math.sin(time / 120) + .02 * Math.sin(time / 47) + LV.warm * .02;
  let g = ctx.createRadialGradient(150, 130, 4, 150, 130, 90); g.addColorStop(0, `rgba(255,150,70,${fl})`); g.addColorStop(1, 'rgba(255,150,70,0)'); ctx.fillStyle = g; ctx.fillRect(60, 40, 180, 160);
  const tvc = ['rgba(255,170,110,', 'rgba(110,150,255,', 'rgba(200,200,220,', 'rgba(160,160,255,'][LV.ch];
  g = ctx.createRadialGradient(230, 100, 4, 230, 100, 50); g.addColorStop(0, tvc + (.06 + .03 * Math.random()) + ')'); g.addColorStop(1, tvc + '0)'); ctx.fillStyle = g; ctx.fillRect(180, 50, 100, 100);
  const dg = .10 + .03 * Math.sin(time / 700);
  g = ctx.createRadialGradient(288, 110, 4, 288, 110, 46); g.addColorStop(0, `rgba(255,214,140,${dg})`); g.addColorStop(1, 'rgba(255,214,140,0)'); ctx.fillStyle = g; ctx.fillRect(242, 64, 78, 136);
  ctx.globalCompositeOperation = 'source-over';
  for(const p of LV.sparks){ ctx.fillStyle = `rgba(255,${180 + (p.a * 60 | 0)},90,${p.a})`; ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 1); }
  drawPlayer(ctx, P.x, l.feet, 'rgba(40,20,10,.35)');
}

/* ================================================================ cameretta */
const cv = $('#cv'), ctx = cv.getContext('2d');
let mask, dims = {}, rings = {}, boxes = {}, hover = null, defaultRoom = true, rsteam = [];
function buildMaskLayers(maskImg){
  const c = document.createElement('canvas'); c.width = 320; c.height = 200;
  const m = c.getContext('2d'); m.drawImage(maskImg, 0, 0);
  const px = m.getImageData(0, 0, 320, 200).data;
  mask = new Uint8Array(320 * 200);
  for(let i = 0; i < mask.length; i++) mask[i] = px[i * 4];
  GROUPS.forEach((g, gi) => {
    const id = gi + 1; let x0 = 320, y0 = 200, x1 = -1, y1 = -1; const xs = [];
    const d = new ImageData(320, 200), r = new ImageData(320, 200);
    for(let y = 0; y < 200; y++) for(let x = 0; x < 320; x++){
      const i = y * 320 + x;
      if(mask[i] === id){ if(x < x0) x0 = x; if(x > x1) x1 = x; if(y < y0) y0 = y; if(y > y1) y1 = y; if(xs.length < 6000) xs.push(x); }
      else {
        d.data[i * 4] = 10; d.data[i * 4 + 1] = 8; d.data[i * 4 + 2] = 24; d.data[i * 4 + 3] = 105;
        let near = false;
        for(let dy = -1; dy <= 1 && !near; dy++) for(let dx = -1; dx <= 1; dx++){ const xx = x + dx, yy = y + dy; if(xx >= 0 && yy >= 0 && xx < 320 && yy < 200 && mask[yy * 320 + xx] === id){ near = true; break; } }
        if(near){ r.data[i * 4] = 255; r.data[i * 4 + 1] = 232; r.data[i * 4 + 2] = 160; r.data[i * 4 + 3] = 255; }
      }
    }
    if(x1 < 0) return;
    xs.sort((a, b) => a - b);
    boxes[g] = {x0, y0, x1, y1, cx: xs[xs.length >> 1]};
    const dc = document.createElement('canvas'); dc.width = 320; dc.height = 200; dc.getContext('2d').putImageData(d, 0, 0); dims[g] = dc;
    const rc = document.createElement('canvas'); rc.width = 320; rc.height = 200; rc.getContext('2d').putImageData(r, 0, 0); rings[g] = rc;
  });
}
function groupAt(x, y){ x = Math.floor(x); y = Math.floor(y); if(x < 0 || y < 0 || x >= 320 || y >= 200) return null; const g = GROUPS[mask[y * 320 + x] - 1]; return g && byId[g] ? g : null; }
const order = () => GROUPS.filter(g => byId[g] && boxes[g]).sort((a, b) => boxes[a].cx - boxes[b].cx);
const BULB = ['#ffdc8c', '#ffc86e', '#ffecaa', '#ffbe78'];
function drawRoom(c, time){
  c.drawImage(IMG.room, 0, 0);
  const an = J.anim;
  if(defaultRoom && an){
    const [lx, ly] = an.lamp, fl = .10 + .025 * Math.sin(time / 190) + (Math.random() < .04 ? .03 : 0);
    const gr = c.createRadialGradient(lx, ly, 2, lx, ly, 46); gr.addColorStop(0, `rgba(255,214,140,${fl})`); gr.addColorStop(1, 'rgba(255,214,140,0)');
    c.globalCompositeOperation = 'lighter'; c.fillStyle = gr; c.fillRect(lx - 46, ly - 46, 92, 92); c.globalCompositeOperation = 'source-over';
    for(const [x, y, k] of an.bulbs){ c.globalAlpha = Math.max(.35, .62 + .38 * Math.sin(time / 420 + x * .35 + k)); c.fillStyle = BULB[k % 4]; c.fillRect(x, y, 1, 1); }
    c.globalAlpha = 1;
    for(let i = 0; i < an.stars.length; i++){ const [x, y] = an.stars[i], s = Math.sin(time / 700 + i * 2.3); if(s < -.5){ c.fillStyle = '#1e2a60'; c.fillRect(x, y, 1, 1); } else if(s > .8){ c.fillStyle = '#ffffff'; c.fillRect(x, y, 1, 1); } }
    if(Math.floor(time / 500) % 2){ c.fillStyle = '#f0d6a0'; c.fillRect(Math.round(an.cursor[0]), Math.round(an.cursor[1]), 1, 2); }
    const [mx, my] = an.mug;
    if(rsteam.length < 7 && Math.random() < .25) rsteam.push({y: 0, p: Math.random() * 6});
    for(const p of rsteam){ p.y += .5; c.fillStyle = `rgba(250,250,255,${Math.max(0, 1 - p.y / 16) * .8})`; c.fillRect(Math.round(mx + Math.sin(p.y / 2.5 + p.p) * 1.3), Math.round(my - 2 - p.y), 1, 1); }
    rsteam = rsteam.filter(p => p.y < 16);
  }
  if(hover && dims[hover]){ c.drawImage(dims[hover], 0, 0); c.drawImage(rings[hover], 0, 0); }
}
const DIAMOND = col => `<svg class="marker" viewBox="0 0 5 5" shape-rendering="crispEdges" aria-hidden="true"><rect x="2" y="0" width="1" height="5" fill="#1a1733"/><rect x="0" y="2" width="5" height="1" fill="#1a1733"/><rect x="1" y="1" width="3" height="3" fill="#1a1733"/><rect x="2" y="1" width="1" height="3" fill="${col}"/><rect x="1" y="2" width="3" height="1" fill="${col}"/></svg>`;
function renderMarkers(){
  $('#markers').innerHTML = scene !== 'room' ? '' : order().map(g => { const b = boxes[g]; if(g === hover) return ''; return `<div style="position:absolute;left:${b.cx * 4}px;top:${Math.max(30, b.y0 * 4 - 26)}px">${DIAMOND(explored.has(g) ? '#a3bb8c' : '#f2b85b')}</div>`; }).join('');
}
function renderSign(){
  const host = $('#signHost');
  if(!hover || scene !== 'room'){ host.innerHTML = ''; return; }
  const b = boxes[hover], s = byId[hover];
  host.innerHTML = `<div class="sign" style="left:${clamp(b.cx * 4, 130, 1150)}px;top:${Math.max(16, b.y0 * 4 - 128)}px"><div class="board"><span class="o">${esc(L(s, 'object_name').toUpperCase())}</span><span class="s">${esc(L(s, 'sign_label'))}</span></div><div class="posts"><i></i><i></i></div></div>`;
}
function setHover(g){
  if(g === hover) return;
  hover = g; cv.classList.toggle('hot', !!g && scene === 'room');
  if(g) SFX.hover();
  renderSign(); renderMarkers();
}
function renderHotButtons(){
  $('#hbs').innerHTML = scene !== 'room' ? '' : order().map(g => { const b = boxes[g], s = byId[g];
    return `<button class="hb" data-g="${g}" style="left:${b.x0 * 4}px;top:${b.y0 * 4}px;width:${(b.x1 - b.x0 + 1) * 4}px;height:${(b.y1 - b.y0 + 1) * 4}px" aria-label="${esc(L(s, 'object_name'))}: ${esc(L(s, 'title'))}"></button>`; }).join('');
}
$('#hbs').addEventListener('focusin', e => { const b = e.target.closest('.hb'); if(b) setHover(b.dataset.g); });
$('#hbs').addEventListener('click', e => { const b = e.target.closest('.hb'); if(b) openSection(b.dataset.g); });
function lpos(e){ const r = cv.getBoundingClientRect(); return [(e.clientX - r.left) / r.width * 320, (e.clientY - r.top) / r.height * 200]; }
cv.addEventListener('pointermove', e => { if(scene === 'room' && e.pointerType === 'mouse') setHover(groupAt(...lpos(e))); });
cv.addEventListener('pointerleave', () => { if(scene === 'room') setHover(null); });
cv.addEventListener('pointerdown', e => {
  SFX.unlock();
  if(scene === 'street' || scene === 'living'){ const [x] = lpos(e); tapTarget = clamp(x + (scene === 'street' ? ST.camX : 0), 10, 1e5); }
});
cv.addEventListener('click', e => { if(scene !== 'room') return; const g = groupAt(...lpos(e)); if(g){ setHover(g); openSection(g); } });
function renderProgress(){
  const ids = order(), n = ids.filter(g => explored.has(g)).length;
  $('#progTxt').textContent = `${t('explored')} ${n}/${ids.length}`;
  $('#pips').innerHTML = ids.map(g => `<i class="${explored.has(g) ? 'on' : ''}"></i>`).join('');
  $('#sheet').innerHTML = `<h2>${esc(t('sheet'))} <span style="font:400 18px VT323,monospace;color:var(--muted)">${n}/${ids.length}</span></h2>` +
    SECTIONS.filter(s => boxes[s.id]).map(s => `<button data-g="${s.id}">${esc(L(s, 'object_name'))}<span>${esc(L(s, 'sign_label').toLowerCase())}${explored.has(s.id) ? ' ✓' : ' ▶'}</span></button>`).join('');
}
$('#sheet').addEventListener('click', e => { const b = e.target.closest('button[data-g]'); if(b) openSection(b.dataset.g); });

/* ================================================================ pannelli */
const ICONS = {
  letto: '<rect x="1" y="5" width="10" height="4" fill="#f6e9c8"/><rect x="4" y="5" width="7" height="4" fill="#d97a4b"/><rect x="1" y="9" width="1" height="2" fill="#8a5a36"/><rect x="10" y="9" width="1" height="2" fill="#8a5a36"/>',
  scrivania: '<rect x="1" y="2" width="10" height="7" fill="#1a1733"/><rect x="2" y="3" width="8" height="5" fill="#8fb2ee"/><rect x="3" y="4" width="3" height="1" fill="#f2b85b"/><rect x="3" y="6" width="5" height="1" fill="#a3bb8c"/><rect x="3" y="10" width="6" height="1" fill="#f6e9c8"/>',
  lavagna: '<rect x="0" y="2" width="12" height="8" fill="#8a5a36"/><rect x="1" y="3" width="10" height="6" fill="#2f5d48"/><rect x="2" y="4" width="4" height="1" fill="#f6e9c8"/><rect x="2" y="6" width="6" height="1" fill="#f6e9c8"/><rect x="8" y="4" width="2" height="2" fill="#f2b85b"/>',
  libreria: '<rect x="1" y="0" width="10" height="12" fill="#8a5a36"/><rect x="2" y="1" width="8" height="4" fill="#3d2616"/><rect x="2" y="6" width="8" height="4" fill="#3d2616"/><rect x="2" y="2" width="2" height="3" fill="#d97a4b"/><rect x="4" y="1" width="1" height="4" fill="#8fb2ee"/><rect x="6" y="2" width="2" height="3" fill="#a3bb8c"/><rect x="3" y="7" width="2" height="3" fill="#f2b85b"/><rect x="6" y="6" width="2" height="4" fill="#f6e9c8"/>',
  finestra: '<rect x="1" y="0" width="10" height="12" fill="#8a5a36"/><rect x="2" y="1" width="8" height="10" fill="#1b2350"/><rect x="5" y="1" width="1" height="10" fill="#8a5a36"/><rect x="2" y="6" width="8" height="1" fill="#8a5a36"/><rect x="7" y="2" width="2" height="2" fill="#fff0c8"/><rect x="3" y="3" width="1" height="1" fill="#f6e9c8"/>'
};
const icon = id => `<svg width="48" height="48" viewBox="0 0 12 12" shape-rendering="crispEdges" aria-hidden="true">${ICONS[id] || ICONS.scrivania}</svg>`;
const tagsHTML = it => it.tags.length ? `<div class="tags">${it.tags.map(x => `<span>${esc(x)}</span>`).join('')}</div>` : '';
const linkHTML = (it, def) => safeUrl(it.url) ? `<a href="${esc(it.url)}" target="_blank" rel="noopener">${esc(L(it, 'link_label') || def)}</a>` : '';
function cardsHTML(items){
  return `<div class="cards">${items.map(it => `<article class="card">
    ${it.image ? `<img src="${esc(safeUrl(it.image))}" alt="" loading="lazy">` : ''}
    ${L(it, 'kicker') ? `<span class="k">${esc(L(it, 'kicker'))}</span>` : ''}
    <h4>${esc(L(it, 'title'))}</h4>
    ${L(it, 'status') ? `<span class="badge">${esc(L(it, 'status'))}</span>` : ''}
    ${L(it, 'description') ? `<p>${esc(L(it, 'description'))}</p>` : ''}
    ${tagsHTML(it)}${linkHTML(it, lang === 'en' ? 'open ↗' : 'apri ↗')}
  </article>`).join('')}</div>`;
}
function timelineHTML(items){
  return `<div class="tl">${items.map(it => `<div class="row"><span class="when">${esc(L(it, 'kicker'))}</span><div><h4>${esc(L(it, 'title'))}</h4>${L(it, 'description') ? `<p>${esc(L(it, 'description'))}</p>` : ''}${it.tags.length ? `<div style="margin-top:6px">${tagsHTML(it)}</div>` : ''}${safeUrl(it.url) ? `<p>${linkHTML(it, lang === 'en' ? 'open ↗' : 'apri ↗')}</p>` : ''}</div></div>`).join('')}</div>`;
}
const SPINES = ['#7a3626', '#2f5d48', '#23406e', '#8a5a36', '#5b3f78', '#a8642e'];
function booksHTML(items){
  return `<div class="books">${items.map((it, i) => `<div class="book">
    ${it.image ? `<img class="cover" src="${esc(safeUrl(it.image))}" alt="${esc(L(it, 'title'))}">` : `<div class="cover" style="background:${SPINES[i % SPINES.length]}">${esc(L(it, 'title'))}</div>`}
    <span class="a">${esc(L(it, 'kicker'))}</span>${linkHTML(it, lang === 'en' ? 'details ↗' : 'scheda ↗')}
  </div>`).join('')}</div>`;
}
function sectionBody(s){
  const groups = [];
  for(const it of s.items){ const name = L(it, 'grp'); let g = groups.find(x => x.key === it.grp); if(!g){ g = {key: it.grp, name, items: []}; groups.push(g); } g.items.push(it); }
  let html = L(s, 'intro') ? `<p class="intro">${esc(L(s, 'intro'))}</p>` : '';
  if(!groups.length) html += `<p class="empty">${esc(t('empty'))}</p>`;
  for(const g of groups){
    const inner = (s.id === 'finestra' && g === groups[0]) ? timelineHTML(g.items) : (s.id === 'libreria' && g === groups[0]) ? booksHTML(g.items) : cardsHTML(g.items);
    html += `<section class="grp${s.id === 'lavagna' ? ' chalk' : ''}">${g.name ? `<h3>${esc(g.name)}</h3>` : ''}${inner}</section>`;
  }
  const bits = [];
  if(safeUrl(s.link_url)) bits.push(`<a class="btn" href="${esc(s.link_url)}" target="_blank" rel="noopener">${esc(L(s, 'link_label') || s.link_url)}</a>`);
  if(s.id === 'finestra'){
    if(safeUrl(S.cv_url)) bits.push(`<a class="btn" href="${esc(S.cv_url)}" target="_blank" rel="noopener">${esc(t('cv'))}</a>`);
    if(safeUrl(S.github_url)) bits.push(`<a class="btn ghost" href="${esc(S.github_url)}" target="_blank" rel="noopener">GitHub ↗</a>`);
    if(safeUrl(S.github_physics_url)) bits.push(`<a class="btn ghost" href="${esc(S.github_physics_url)}" target="_blank" rel="noopener">GitHub · ${lang === 'en' ? 'physics' : 'fisica'} ↗</a>`);
    if(S.email) bits.push(`<span class="btn ghost">${esc(S.email)}</span>`);
    if(L(S, 'location')) bits.push(`<span style="color:var(--muted)">${esc(L(S, 'location'))}</span>`);
  }
  if(bits.length) html += `<section class="grp">${s.id === 'finestra' ? `<h3>${esc(t('find'))}</h3>` : ''}<div class="contact">${bits.join('')}</div></section>`;
  return html;
}
let openId = null, infoKind = null, lastFocus = null;
function openSection(id, silent){
  const s = byId[id]; if(!s) return;
  if(!openId) lastFocus = document.activeElement;
  openId = id; explored.add(id); store.set('explored', [...explored]);
  const ids = order().length ? order() : SECTIONS.map(x => x.id), k = ids.indexOf(id);
  const prev = byId[ids[(k - 1 + ids.length) % ids.length]], next = byId[ids[(k + 1) % ids.length]];
  const m = $('#modal');
  m.innerHTML = `<div class="panel px" role="dialog" aria-modal="true" aria-labelledby="ptitle" style="--hc:${esc(s.color)}">
    <header class="ph"><div class="who">${icon(id)}<div><small>${esc(L(s, 'object_name').toUpperCase())}</small><h2 id="ptitle">${esc(L(s, 'title'))}</h2></div></div>
      <button class="close" id="pClose"><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="square" aria-hidden="true"><path d="M3 3l10 10M13 3L3 13"/></svg>${esc(t('close'))} <span>ESC</span></button></header>
    <div class="pb">${sectionBody(s)}</div>
    <footer class="pf"><button data-go="${prev.id}">◀ ${esc(L(prev, 'object_name'))}</button><span class="pips">${ids.map(g => `<i class="${g === id ? 'on' : ''}"></i>`).join('')}</span><button data-go="${next.id}">${esc(L(next, 'object_name'))} ▶</button></footer>
  </div>`;
  m.hidden = false;
  m.querySelector('#pClose').onclick = closeModal;
  m.querySelectorAll('[data-go]').forEach(b => b.onclick = () => { SFX.select(); openSection(b.dataset.go); });
  m.querySelectorAll('.pb a').forEach(a => a.addEventListener('click', () => SFX.select()));
  if(!silent){ m.querySelector('#pClose').focus(); SFX.open(); }
  try{ history.replaceState(null, '', '#' + id); }catch(e){}
  renderProgress(); renderMarkers();
}
function closeModal(){
  if($('#modal').hidden) return;
  const wasSection = openId && openId !== '_info';
  openId = null; infoKind = null; $('#modal').hidden = true; $('#modal').innerHTML = '';
  if(wasSection) try{ history.replaceState(null, '', '#stanza'); }catch(e){}
  SFX.close();
  if(lastFocus && document.contains(lastFocus)) lastFocus.focus({preventScroll: true});
}
$('#modal').addEventListener('click', e => { if(e.target.id === 'modal') closeModal(); });
function openInfo(kind, silent){
  if(!openId) lastFocus = document.activeElement;
  infoKind = kind; openId = '_info';
  const m = $('#modal');
  m.innerHTML = `<div class="panel px" role="dialog" aria-modal="true" aria-labelledby="ptitle" style="max-width:760px">
    <header class="ph"><div class="who"><h2 id="ptitle">${esc(t('helpTitle'))}</h2></div><button class="close" id="pClose">${esc(t('close'))} <span>ESC</span></button></header>
    <div class="pb"><ul class="help" style="margin:0;padding-left:22px;font-size:23px">${t('helpItems').map(x => `<li>${x}</li>`).join('')}</ul></div></div>`;
  m.hidden = false; m.querySelector('#pClose').onclick = closeModal;
  if(!silent){ m.querySelector('#pClose').focus(); SFX.open(); }
}

/* ================================================================ scene e transizioni */
function fade(on){ $('#fade').classList.toggle('on', on); }
function showTitle(text){ const el = $('#sceneTitle'); el.textContent = text; el.classList.remove('show'); void el.offsetWidth; if(!reduced) el.classList.add('show'); }
function hudFor(sc){
  const name = sc === 'street' ? t('street') : sc === 'living' ? t('living') : L(S, 'room_crumb');
  $('#cScene').textContent = name; $('#mScene').textContent = name;
  $('#bBack').hidden = sc !== 'room'; $('#mBack').hidden = sc !== 'room';
  $('#bSkip').hidden = sc === 'room';
  $('#prog').hidden = sc !== 'room';
  $('#hint').innerHTML = sc === 'room' ? t('hintRoom') : t('hintWalk');
  document.body.classList.toggle('walk', sc === 'street' || sc === 'living');
  document.body.classList.toggle('inroom', sc === 'room');
}
function setScene(sc){
  scene = sc; hidePrompt(); setHover(null); tapTarget = null; padDir = 0;
  $('#bubbles').hidden = sc !== 'street';
  hudFor(sc); SFX.scene(sc);
  renderMarkers(); renderHotButtons(); renderSign(); renderProgress();
  layout.centered = false; layout();
  if(sc !== 'menu') showTitle(t('titles')[sc]);
}
async function transition(fn, {door = false} = {}){
  if(busy) return; busy = true;
  if(door) SFX.doorOpen();
  duckMusic(); fade(true); await wait(500);
  fn();
  await wait(120); fade(false);
  if(door) setTimeout(() => SFX.doorClose(), 250);
  busy = false;
}
function enterStreet(){ $('#mDialog').innerHTML = ''; $('#menu').hidden = true; $('#game').hidden = false; P.x = J.street.start; P.dir = 1; ST.camX = 0; lastCam = 0; buildBubbles(); setScene('street'); try{ history.replaceState(null, '', '#strada'); }catch(e){} }
function enterLiving(fromRoom){ $('#menu').hidden = true; $('#game').hidden = false; P.x = fromRoom ? J.living.spots.door - 6 : J.living.start; P.dir = fromRoom ? -1 : 1; setScene('living'); SFX.tv(LV.ch); try{ history.replaceState(null, '', '#salotto'); }catch(e){} }
function enterRoom(){ $('#menu').hidden = true; $('#game').hidden = false; setScene('room'); store.set('visited', true); try{ history.replaceState(null, '', '#stanza'); }catch(e){} }
const goLiving = () => transition(enterLiving, {door: true});
const goRoom = () => transition(enterRoom, {door: true});
async function startGame(direct){
  if(busy || scene !== 'menu') return;
  SFX.unlock(); startMusic(); SFX.start();
  const toRoom = direct || S.skip_intro === '1';
  busy = true;
  const r = skyfx.getBoundingClientRect(), s = Math.max(r.width / 320, r.height / 200);
  if(!customSky && J.menu){
    const [x0, y0, x1, y1] = J.menu.window;
    $('#menu').style.setProperty('--ox', ((r.width - 320 * s) * (mobile ? .15 : .3) + (x0 + x1) / 2 * s) + 'px');
    $('#menu').style.setProperty('--oy', ((r.height - 200 * s) * .5 + (y0 + y1) / 2 * s) + 'px');
  }
  if(!reduced && toRoom) $('#menu').classList.add('zoom');
  await wait(reduced ? 50 : 450); fade(true); await wait(480);
  $('#menu').classList.remove('zoom');
  if(toRoom) enterRoom(); else enterStreet();
  await wait(100); fade(false); busy = false;
}
async function toMenu(){
  if(scene === 'menu' || busy) return;
  closeModal(); busy = true; fade(true); await wait(450);
  setScene('menu'); $('#game').hidden = true; $('#menu').hidden = false;
  for(const B of ST.bub) clearTimeout(B.timer);
  try{ history.replaceState(null, '', location.pathname); }catch(e){}
  fade(false); busy = false; selMenu(0); menuItems()[0].focus();
}
$('#bMenu').onclick = $('#mMenu').onclick = () => { SFX.select(); toMenu(); };
$('#bAudio').onclick = $('#mAudio').onclick = () => { setAudio(!audioOn); SFX.select(); };
$('#bLang').onclick = $('#mLang').onclick = () => { SFX.select(); setLang(lang === 'en' ? 'it' : 'en'); };
$('#bBack').onclick = $('#mBack').onclick = () => { SFX.select(); transition(() => enterLiving(true), {door: true}); };
$('#mSkip').onclick = () => $('#bSkip').onclick();
$('#bSkip').onclick = () => { SFX.select(); transition(enterRoom, {door: scene === 'living'}); };

/* ================================================================ tastiera */
addEventListener('keydown', e => {
  if(loadingActive) return;
  SFX.unlock();
  if(!$('#modal').hidden){
    if(e.key === 'Escape'){ e.preventDefault(); closeModal(); }
    else if(openId && openId !== '_info' && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')){
      const ids = order(), k = ids.indexOf(openId); if(k < 0) return;
      e.preventDefault(); SFX.select(); openSection(ids[(k + (e.key === 'ArrowRight' ? 1 : -1) + ids.length) % ids.length]);
    }
    return;
  }
  if(scene === 'menu'){
    if(e.key === 'ArrowDown'){ e.preventDefault(); selMenu(menuSel + 1); SFX.move(); }
    else if(e.key === 'ArrowUp'){ e.preventDefault(); selMenu(menuSel - 1); SFX.move(); }
    else if(e.key === 'Enter' && !e.target.closest('button,a')){ e.preventDefault(); menuAct(menuItems()[menuSel].dataset.act); }
    return;
  }
  if(scene === 'street' || scene === 'living'){
    if(['ArrowLeft', 'ArrowRight', 'KeyA', 'KeyD', 'ShiftLeft', 'ShiftRight'].includes(e.code)){ keys.add(e.code); tapTarget = null; if(e.code.startsWith('Arrow')) e.preventDefault(); }
    else if(['KeyE', 'Enter', 'Space', 'ArrowUp', 'KeyW'].includes(e.code) && !e.target.closest('button,a')){ e.preventDefault(); doAction(); }
    else if(e.key === 'Escape'){ e.preventDefault(); toMenu(); }
    return;
  }
  const ids = order();
  if(e.key === 'ArrowRight' || e.key === 'ArrowLeft'){
    e.preventDefault(); const k = ids.indexOf(hover);
    const n = ids[(k < 0 ? 0 : k + (e.key === 'ArrowRight' ? 1 : -1) + ids.length) % ids.length];
    setHover(n); const b = document.querySelector(`.hb[data-g="${n}"]`); if(b) b.focus({preventScroll: true});
    if(mobile) $('#vp').scrollTo({left: boxes[n].cx * 4 * scale - innerWidth / 2, behavior: reduced ? 'auto' : 'smooth'});
  } else if((e.key === 'Enter' || e.key === ' ') && hover && !e.target.closest('.hb,button,a')){ e.preventDefault(); openSection(hover); }
  else if(e.key === 'Escape'){ e.preventDefault(); transition(() => enterLiving(true), {door: true}); }
});
addEventListener('keyup', e => keys.delete(e.code));
addEventListener('blur', () => { keys.clear(); padDir = 0; });

/* ================================================================ caricamento e avvio */
let loadingActive = true, ldDone = 0, LD_TOTAL = 12;
function ldStep(){ ldDone = Math.min(LD_TOTAL, ldDone + 1); const pct = Math.round(ldDone / LD_TOTAL * 20) * 5; $('#ldFill').style.width = pct + '%'; $('#ldPct').textContent = pct + '%'; }
const track = p => p.finally(ldStep);
async function finishLoading(t0){
  $('#ldFill').style.width = '100%'; $('#ldPct').textContent = '100%';
  const left = 1500 - (performance.now() - t0); if(left > 0) await wait(left);
  $('#loading').classList.add('out'); await wait(520);
  $('#loading').hidden = true; loadingActive = false;
}
async function boot(){
  const t0 = performance.now();
  lang = store.get('lang', null) || 'en';
  $('#ldTip').innerHTML = T[lang].tips[Math.floor(Math.random() * T[lang].tips.length)];
  try{ DATA = await track(loadJSON('/api/public')); }
  catch(e){ try{ DATA = await loadJSON('data.json'); } catch(e2){ toast(T[lang].noServer); DATA = {settings: {}, sections: [], bubbles: []}; } }
  S = DATA.settings || {}; SECTIONS = DATA.sections || []; BUBBLES = DATA.bubbles || [];
  byId = Object.fromEntries(SECTIONS.map(s => [s.id, s]));
  lang = store.get('lang', null) || (S.default_lang === 'it' ? 'it' : 'en');
  customSky = !!safeUrl(S.menu_background);
  if(customSky){ $('#skyimg').src = S.menu_background; $('#ldBg').src = S.menu_background; $('#skyimg').classList.toggle('pxi', S.menu_background_pixelated !== '0'); }
  defaultRoom = !safeUrl(S.room_image);
  const img = (k, src, fb) => track(loadImg(src).catch(() => fb ? loadImg(fb) : null)).then(i => IMG[k] = i);
  const json = (k, src) => track(loadJSON(src).catch(() => null)).then(j => J[k] = j);
  await Promise.all([
    img('room', defaultRoom ? 'assets/room.png' : S.room_image, 'assets/room.png'),
    img('mask', safeUrl(S.room_mask) || 'assets/mask.png', 'assets/mask.png'),
    img('far', 'assets/street_far.png'), img('mid', 'assets/street_mid.png'), img('near', 'assets/street_near.png'),
    img('living', 'assets/living.png'), img('player', 'assets/player.png'),
    json('anim', 'assets/anim.json'), json('menu', 'assets/menu_anim.json'), json('street', 'assets/street.json'),
    json('living', 'assets/living.json'), json('player', 'assets/player.json'),
    track(Promise.race([document.fonts ? document.fonts.ready : Promise.resolve(), wait(2500)]))
  ]);
  if(IMG.room.naturalWidth !== 320){ const c = document.createElement('canvas'); c.width = 320; c.height = 200; const g = c.getContext('2d'); g.imageSmoothingEnabled = false; g.drawImage(IMG.room, 0, 0, 320, 200); IMG.room = c; }
  buildMaskLayers(IMG.mask);
  ST.flakes = makeFlakes(90); LV.flakes = makeFlakes(14).map(f => ({...f, x: rnd(J.living.window[0], J.living.window[2]), y: rnd(J.living.window[1], J.living.window[3]), vy: rnd(6, 11)}));
  SFX.levels({amb: S.ambience_volume, steps: S.steps_volume});
  audioOn = store.get('audio', S.audio_default !== '0');
  setAudio(audioOn);
  applyTexts();
  const firstGesture = () => { SFX.unlock(); startMusic(); removeEventListener('pointerdown', firstGesture); removeEventListener('keydown', firstGesture); };
  addEventListener('pointerdown', firstGesture); addEventListener('keydown', firstGesture);
  layout();
  let last = performance.now();
  const loop = now => {
    const dt = Math.min(.05, (now - last) / 1000); last = now;
    if(scene === 'menu') drawSky(now);
    else if(!busy || true){
      if(scene === 'street'){ if(!busy) updateStreet(dt); drawStreet(ctx, now, dt); }
      else if(scene === 'living'){ if(!busy) updateLiving(dt); drawLiving(ctx, now, dt); }
      else if(scene === 'room') drawRoom(ctx, now);
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  const h = location.hash.slice(1);
  if(h === 'stanza' || byId[h]){ enterRoom(); if(byId[h]) openSection(h, true); }
  else if(h === 'salotto') enterLiving();
  else if(h === 'strada') enterStreet();
  await finishLoading(t0);
  if(scene === 'menu') menuItems()[0].focus({preventScroll: true});
}
boot();
}
