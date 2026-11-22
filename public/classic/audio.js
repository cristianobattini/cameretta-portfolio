/* La cameretta — motore audio.
   Ogni suono è sintetizzato con la Web Audio API: niente file, niente licenze.
   Espone window.SFX con: unlock(), setEnabled(on), scene(name), effetti one-shot e ambienti. */
(() => {
  let ctx = null, master, sfxBus, ambBus, stepBus, noiseBuf, brownBuf, enabled = false;
  let levels = { amb: .5, steps: .7 };       // regolabili dall'admin
  let gustTimer = null, fireTimer = null, nextCrackle = 0, nextHiss = 0;
  const amb = {};           // nodi degli ambienti in loop
  let crackleTimer = null, tvTimer = null, clockTimer = null, scene = 'menu';
  let prox = { fire: 0, tv: 0 }, tvChannel = 0;

  function init(){
    if(ctx) return true;
    const AC = window.AudioContext || window.webkitAudioContext;
    if(!AC) return false;
    ctx = new AC();
    master = ctx.createGain(); master.gain.value = enabled ? 1 : 0; master.connect(ctx.destination);
    sfxBus = ctx.createGain(); sfxBus.gain.value = .9; sfxBus.connect(master);
    ambBus = ctx.createGain(); ambBus.gain.value = levels.amb; ambBus.connect(master);
    stepBus = ctx.createGain(); stepBus.gain.value = levels.steps; stepBus.connect(master);
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for(let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    // rumore marrone: molto più morbido del bianco, niente fruscio acuto
    brownBuf = ctx.createBuffer(1, ctx.sampleRate * 4, ctx.sampleRate);
    const b = brownBuf.getChannelData(0); let last = 0;
    for(let i = 0; i < b.length; i++){ last = (last + .02 * (Math.random() * 2 - 1)) / 1.02; b[i] = last * 3.5; }
    buildAmbience();
    return true;
  }
  const now = () => ctx.currentTime;
  function noise(dur, { type = 'bandpass', f = 1000, q = 1, gain = .3, attack = .002, rate = 1, when = 0, dest = sfxBus } = {}){
    const t = now() + when;
    const src = ctx.createBufferSource(); src.buffer = noiseBuf; src.playbackRate.value = rate;
    const flt = ctx.createBiquadFilter(); flt.type = type; flt.frequency.value = f; flt.Q.value = q;
    const g = ctx.createGain(); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain, t + attack); g.gain.exponentialRampToValueAtTime(.0001, t + dur);
    src.connect(flt).connect(g).connect(dest);
    src.start(t, Math.random() * 1.5); src.stop(t + dur + .02);
  }
  function tone(freq, dur, { type = 'sine', gain = .2, when = 0, slide = 0, attack = .003, dest = sfxBus } = {}){
    const t = now() + when;
    const o = ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, t);
    if(slide) o.frequency.exponentialRampToValueAtTime(Math.max(20, freq + slide), t + dur);
    const g = ctx.createGain(); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain, t + attack); g.gain.exponentialRampToValueAtTime(.0001, t + dur);
    o.connect(g).connect(dest); o.start(t); o.stop(t + dur + .02);
  }
  const r = (a, b) => a + Math.random() * (b - a);
  const clamp01 = (v, d) => { v = parseFloat(v); return isNaN(v) ? d : Math.max(0, Math.min(1, v)); };
  const ok = () => enabled && init() && ctx.state === 'running';

  /* ---------------- effetti ---------------- */
  const fx = {
    key(ch){            // tasto di una tastiera meccanica
      if(!ok()) return;
      if(ch === ' '){ noise(.05, { f: 900, q: .8, gain: .18 }); tone(r(95, 115), .06, { type: 'triangle', gain: .12 }); return; }
      if(ch === '\n' || ch === '.' || ch === ','){ /* pausa naturale: nessun suono extra */ }
      noise(.025, { type: 'highpass', f: r(2600, 4200), q: .7, gain: r(.12, .2) });
      tone(r(150, 230), .03, { type: 'triangle', gain: r(.08, .13) });
    },
    stepSnow(){         // passo sulla neve: morbido, ovattato
      if(!ok()) return;
      noise(r(.08, .11), { type: 'lowpass', f: r(700, 950), q: .4, gain: .06, attack: .012, dest: stepBus });
      noise(r(.03, .05), { f: r(1100, 1600), q: 1.2, gain: .018, when: r(.01, .03), dest: stepBus });
      tone(r(70, 90), .08, { gain: .05, slide: -15, dest: stepBus });
    },
    stepWood(){         // passo sul parquet
      if(!ok()) return;
      tone(r(95, 125), .09, { gain: .14, slide: -30, dest: stepBus });
      noise(.06, { type: 'lowpass', f: 600, gain: .05, dest: stepBus });
      if(Math.random() < .2) tone(r(320, 420), .18, { type: 'triangle', gain: .015, slide: 60, dest: stepBus });   // asse che scricchiola
    },
    select(){           // clic meccanico di selezione
      if(!ok()) return;
      noise(.012, { type: 'highpass', f: 3500, gain: .22 });
      tone(1800, .02, { type: 'square', gain: .04 });
      noise(.016, { type: 'highpass', f: 2600, gain: .16, when: .035 });
      tone(1200, .02, { type: 'square', gain: .03, when: .035 });
    },
    hover(){ if(!ok()) return; noise(.01, { type: 'highpass', f: 4200, gain: .1 }); tone(2400, .012, { type: 'square', gain: .02 }); },
    move(){ if(!ok()) return; tone(660, .04, { type: 'square', gain: .04 }); },
    open(){             // pannello che si apre: clac + piccolo carillon
      if(!ok()) return;
      fx.select();
      [784, 988, 1175].forEach((f, i) => tone(f, .25, { type: 'triangle', gain: .05, when: .06 + i * .06 }));
    },
    close(){ if(!ok()) return; noise(.014, { type: 'highpass', f: 2800, gain: .18 }); tone(880, .12, { type: 'triangle', gain: .04, when: .02, slide: -300 }); },
    start(){            // inizio gioco
      if(!ok()) return;
      [392, 523, 659, 784, 1047].forEach((f, i) => tone(f, .22, { type: 'triangle', gain: .07, when: i * .07 }));
    },
    doorOpen(){         // cigolio della porta + scatto
      if(!ok()) return;
      tone(1400, .03, { type: 'square', gain: .05 });
      const t = now() + .08;
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(170, t); o.frequency.linearRampToValueAtTime(250, t + .55);
      const lfo = ctx.createOscillator(); lfo.frequency.value = 28; const lg = ctx.createGain(); lg.gain.value = 40; lfo.connect(lg).connect(o.frequency);
      const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 1100; bp.Q.value = 9;
      const g = ctx.createGain(); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(.12, t + .1); g.gain.exponentialRampToValueAtTime(.001, t + .6);
      o.connect(bp).connect(g).connect(sfxBus); o.start(t); lfo.start(t); o.stop(t + .65); lfo.stop(t + .65);
    },
    doorClose(){ if(!ok()) return; tone(70, .25, { gain: .25, slide: -20 }); noise(.08, { type: 'lowpass', f: 500, gain: .15 }); tone(1500, .02, { type: 'square', gain: .04, when: .12 }); },
    channel(){ if(!ok()) return; fx.select(); noise(.25, { type: 'highpass', f: 1500, gain: .12, when: .04 }); },
    pop(){ if(!ok()) return; for(let i = 0; i < 5; i++) noise(r(.02, .05), { type: 'highpass', f: r(1200, 3500), gain: r(.1, .25), when: i * r(.03, .09) }); },
    chime(){ if(!ok()) return; [1319, 1568].forEach((f, i) => tone(f, .5, { type: 'sine', gain: .05, when: i * .09 })); }
  };

  /* ---------------- ambienti ---------------- */
  function loopNoise(filterType, f, q, buf = noiseBuf){
    const src = ctx.createBufferSource(); src.buffer = buf; src.loop = true;
    const flt = ctx.createBiquadFilter(); flt.type = filterType; flt.frequency.value = f; flt.Q.value = q;
    const g = ctx.createGain(); g.gain.value = 0;
    src.connect(flt).connect(g).connect(ambBus); src.start();
    return { src, flt, g };
  }
  function buildAmbience(){
    // vento: rumore marrone filtrato in basso, quasi muto; ogni tanto una folata
    amb.wind = loopNoise('lowpass', 260, .3, brownBuf);
    // respiro del fuoco: rumore marrone molto basso
    amb.fire = loopNoise('lowpass', 220, .4, brownBuf);
    // TV: brusio filtrato che imita una voce
    amb.tv = loopNoise('bandpass', 900, 3);
    // ronzio leggero (computer e lampada in cameretta)
    const hum = ctx.createOscillator(); hum.frequency.value = 58; const hg = ctx.createGain(); hg.gain.value = 0;
    const hum2 = ctx.createOscillator(); hum2.frequency.value = 117; hum2.connect(hg);
    hum.connect(hg).connect(ambBus); hum.start(); hum2.start();
    amb.hum = { g: hg };
  }
  function setGain(node, v, time = .8){ if(!node) return; node.g.gain.cancelScheduledValues(now()); node.g.gain.setTargetAtTime(v, now(), time / 3); }
  const windBase = () => scene === 'street' ? .045 : scene === 'menu' ? .02 : scene === 'living' ? .008 : .005;
  function gust(){
    // una folata: sale piano, il filtro si apre un poco, poi si spegne
    if(!ctx || !enabled) return;
    const t = now(), base = windBase(), peak = base * r(2.2, 3.2), up = r(1.6, 2.6), down = r(2.5, 4);
    const g = amb.wind.g.gain, f = amb.wind.flt.frequency;
    g.cancelScheduledValues(t); g.setValueAtTime(g.value, t); g.linearRampToValueAtTime(peak, t + up); g.linearRampToValueAtTime(base, t + up + down);
    f.cancelScheduledValues(t); f.setValueAtTime(f.value, t); f.linearRampToValueAtTime(r(380, 520), t + up); f.linearRampToValueAtTime(260, t + up + down);
  }
  // camino realistico: crepitii brevissimi a grappoli, schiocchi con un po' di corpo, sibili rari della linfa
  function crackle(when, near){
    const big = Math.random() < .07;
    if(big){
      noise(r(.012, .025), { f: r(700, 1500), q: 1.5, gain: r(.12, .22) * near, attack: .0005, when, dest: ambBus });
      tone(r(170, 320), .035, { gain: .05 * near, when, dest: ambBus });
      return;
    }
    const a = Math.pow(Math.random(), 2.2);                  // quasi tutti piccoli, pochi più forti
    noise(r(.0015, .005), { type: 'highpass', f: r(1800, 5200), q: .7, gain: (.015 + .11 * a) * near, attack: .0004, when, dest: ambBus });
  }
  function fireTick(){
    if(!ctx || !enabled) return;
    const near = scene === 'living' ? .25 + .9 * prox.fire : .08;
    const horizon = now() + .12;
    if(nextCrackle < now()) nextCrackle = now();
    while(nextCrackle < horizon){
      crackle(nextCrackle - now(), near);
      if(Math.random() < .22){                               // grappolo di crepitii
        let tt = nextCrackle; const n = 2 + (Math.random() * 4 | 0);
        for(let k = 0; k < n; k++){ tt += r(.012, .05); crackle(tt - now(), near * r(.5, 1)); }
      }
      nextCrackle += -Math.log(1 - Math.random()) / 5.5;     // processo di Poisson, ~5,5 al secondo
    }
    if(now() > nextHiss){                                    // sibilo della linfa ogni tanto
      nextHiss = now() + r(7, 15);
      noise(r(.5, 1.2), { f: r(3500, 5500), q: 2.5, gain: .012 * near, attack: .25, dest: ambBus });
    }
    // il "respiro" del fuoco cambia piano
    if(Math.random() < .25) amb.fire.g.gain.setTargetAtTime((scene === 'living' ? .05 + .1 * prox.fire : .01) * r(.7, 1.3), now(), .4);
  }
  function applyScene(){
    if(!ctx) return;
    const s = scene;
    setGain(amb.wind, windBase(), 1.2);
    setGain(amb.fire, s === 'living' ? .05 + .1 * prox.fire : s === 'room' ? .01 : 0, .4);
    setGain(amb.tv, s === 'living' ? (tvChannel === 2 ? .05 : .03) * (.2 + prox.tv) : 0, .3);
    amb.tv.flt.type = tvChannel === 2 ? 'highpass' : tvChannel === 0 ? 'lowpass' : 'bandpass';
    amb.tv.flt.frequency.value = tvChannel === 2 ? 2500 : tvChannel === 0 ? 500 : 900;
    setGain(amb.hum, s === 'room' ? .012 : 0);
    clearInterval(tvTimer); clearInterval(clockTimer); clearInterval(fireTimer); clearTimeout(gustTimer);
    if(!enabled) return;
    if(s === 'street' || s === 'menu'){
      const loop = () => { gust(); gustTimer = setTimeout(loop, r(7000, 14000)); };
      gustTimer = setTimeout(loop, r(2500, 5000));
    }
    if(s === 'living' || s === 'room'){ nextCrackle = now(); fireTimer = setInterval(fireTick, 50); }
    if(s === 'living'){
      tvTimer = setInterval(() => {                 // sillabe della TV
        if(tvChannel !== 1 && tvChannel !== 3) return;
        const t = now(), dur = r(.08, .2);
        amb.tv.flt.frequency.setValueAtTime(r(600, 1500), t);
        amb.tv.g.gain.setValueAtTime(.035 * (.2 + prox.tv), t);
        amb.tv.g.gain.setTargetAtTime(.004, t + dur, .03);
        if(tvChannel === 3 && Math.random() < .25) tone(r(400, 900), .05, { type: 'square', gain: .02 * (.2 + prox.tv), dest: ambBus });
      }, 170);
      let tick = 0;
      clockTimer = setInterval(() => {              // tic-tac dell'orologio a pendolo
        tick ^= 1; noise(.02, { type: 'bandpass', f: tick ? 3200 : 2600, q: 6, gain: .05, dest: ambBus });
      }, 1000);
    }
  }

  window.SFX = Object.assign(fx, {
    unlock(){ if(!enabled) return; if(init() && ctx.state === 'suspended') ctx.resume().then(applyScene); },
    setEnabled(on){
      enabled = on;
      if(on){ init(); if(ctx.state === 'suspended') ctx.resume(); }
      if(ctx){ master.gain.setTargetAtTime(on ? 1 : 0, now(), .05); applyScene(); }
    },
    scene(name){ scene = name; applyScene(); },
    proximity(p){ prox = { ...prox, ...p }; if(ctx && enabled && scene === 'living'){ if(tvChannel === 0 || tvChannel === 2) setGain(amb.tv, (tvChannel === 2 ? .05 : .03) * (.2 + prox.tv), .3); } },
    tv(ch){ tvChannel = ch; applyScene(); },
    levels(l){
      levels = { amb: clamp01(l.amb, .5), steps: clamp01(l.steps, .7) };
      if(ctx){ ambBus.gain.setTargetAtTime(levels.amb, now(), .1); stepBus.gain.setTargetAtTime(levels.steps, now(), .1); }
    }
  });
})();
