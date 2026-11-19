(function () {
  'use strict';
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $ = function (id) { return document.getElementById(id); };
  var clamp = function (v, a, b) { return Math.max(a, Math.min(b, v)); };
  var lerp = function (a, b, t) { return a + (b - a) * t; };

  /* ---------- scenes the background wallpaper morphs through ---------- */
  var SCENES = [
    { name: 'Synthwave',  top: [20, 0, 50],  bot: [255, 60, 140], acc: [0, 230, 255],   sun: [255, 200, 60],  stars: 0.5 },
    { name: 'Neon Tokyo', top: [10, 0, 30],  bot: [120, 30, 200], acc: [255, 60, 200],  sun: [255, 90, 120],  stars: 0.7 },
    { name: 'Deep Sea',   top: [0, 10, 40],  bot: [0, 90, 140],   acc: [60, 255, 220],  sun: [120, 220, 255], stars: 0.2 },
    { name: 'Desert Night', top: [10, 10, 40], bot: [200, 90, 40], acc: [255, 190, 90], sun: [255, 230, 170], stars: 0.8 },
    { name: 'Space',      top: [0, 0, 10],   bot: [40, 20, 90],   acc: [160, 120, 255], sun: [220, 220, 255], stars: 1 }
  ];
  function mix(a, b, t) { return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]; }
  function rgb(c, a) { return 'rgba(' + (c[0] | 0) + ',' + (c[1] | 0) + ',' + (c[2] | 0) + ',' + (a == null ? 1 : a) + ')'; }

  var canvas = $('wall'), ctx = canvas.getContext('2d');
  var W = 0, H = 0, dpr = 1;
  var stars = [];
  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth; H = window.innerHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    stars = [];
    var n = Math.round(W * H / 6000);
    for (var i = 0; i < n; i++) stars.push({ x: Math.random(), y: Math.random() * 0.62, r: Math.random() * 1.4 + 0.3, p: Math.random() * 6.28, d: Math.random() });
  }
  window.addEventListener('resize', resize);
  resize();

  var progress = 0;       // 0..1 across the whole page
  var smooth = 0;         // eased version, drives the wallpaper
  var sceneLabel = $('sceneName');
  var lastLabel = '';

  function draw(t) {
    smooth += (progress - smooth) * 0.08;
    var f = smooth * (SCENES.length - 1);
    var i = Math.min(Math.floor(f), SCENES.length - 2);
    var k = f - i;
    var A = SCENES[i], B = SCENES[i + 1];
    var top = mix(A.top, B.top, k), bot = mix(A.bot, B.bot, k), acc = mix(A.acc, B.acc, k), sun = mix(A.sun, B.sun, k);
    var starAmt = lerp(A.stars, B.stars, k);

    var label = (k < 0.5 ? A : B).name;
    if (label !== lastLabel && sceneLabel) { sceneLabel.textContent = label; lastLabel = label; }

    // beat: 120 bpm kick with a fast decay
    var beatPhase = reduce ? 0.5 : (t / 1000 * 2) % 1;
    var pulse = reduce ? 0.2 : Math.exp(-beatPhase * 5);

    var horizon = H * lerp(0.62, 0.48, smooth);   // scrolling raises the camera
    var g = ctx.createLinearGradient(0, 0, 0, horizon);
    g.addColorStop(0, rgb(top)); g.addColorStop(1, rgb(bot));
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);

    // stars drift upward as you scroll (parallax)
    ctx.fillStyle = '#fff';
    for (var s = 0; s < stars.length; s++) {
      var st = stars[s];
      var y = ((st.y * H - smooth * H * 0.5 * (0.3 + st.d)) % (horizon) + horizon) % horizon;
      var tw = 0.5 + 0.5 * Math.sin(t / 700 + st.p);
      ctx.globalAlpha = starAmt * (0.25 + 0.75 * tw) * (1 - y / horizon * 0.6);
      ctx.fillRect(st.x * W, y, st.r, st.r);
    }
    ctx.globalAlpha = 1;

    // sun / moon rises with scroll and thumps on the beat
    var sr = Math.min(W, H) * (0.17 + 0.02 * pulse);
    var sy = lerp(horizon + sr * 0.2, horizon - sr * 1.5, clamp(smooth * 1.6, 0, 1));
    var sx = W * lerp(0.5, 0.5 + 0.2 * Math.sin(smooth * 6), 1);
    var glow = ctx.createRadialGradient(sx, sy, sr * 0.2, sx, sy, sr * 2.6);
    glow.addColorStop(0, rgb(sun, 0.35 + 0.25 * pulse)); glow.addColorStop(1, rgb(sun, 0));
    ctx.fillStyle = glow; ctx.fillRect(0, 0, W, H);
    ctx.save();
    ctx.beginPath(); ctx.rect(0, 0, W, horizon); ctx.clip();
    var sg = ctx.createLinearGradient(0, sy - sr, 0, sy + sr);
    sg.addColorStop(0, rgb(sun)); sg.addColorStop(1, rgb(bot));
    ctx.fillStyle = sg; ctx.beginPath(); ctx.arc(sx, sy, sr, 0, 6.2832); ctx.fill();
    ctx.fillStyle = rgb(bot);                     // sunset stripes
    for (var b = 0; b < 6; b++) {
      var by = sy + sr * (0.05 + b * 0.17);
      ctx.fillRect(sx - sr, by, sr * 2, sr * 0.03 * (b + 1));
    }
    ctx.restore();

    // floor
    ctx.fillStyle = rgb(mix(top, [0, 0, 0], 0.55));
    ctx.fillRect(0, horizon, W, H - horizon);
    ctx.strokeStyle = rgb(acc, 0.55 + 0.35 * pulse);
    ctx.lineWidth = 1.2;
    var vx = W / 2, rows = 16;
    var scroll = reduce ? 0 : (t / 1000 * 0.5 + smooth * 6) % 1;
    for (var r = 0; r < rows; r++) {
      var z = (r + scroll) / rows;
      var yy = horizon + Math.pow(z, 2.2) * (H - horizon);
      ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(W, yy); ctx.stroke();
    }
    for (var c = -14; c <= 14; c++) {
      ctx.beginPath(); ctx.moveTo(vx + c * 6, horizon); ctx.lineTo(vx + c * W * 0.16, H); ctx.stroke();
    }

    // equalizer bars along the horizon, driven by a fake spectrum
    var bars = Math.max(24, Math.round(W / 28));
    var bw = W / bars;
    for (var n = 0; n < bars; n++) {
      var wob = 0.5 + 0.5 * Math.sin(t / 380 + n * 0.55) * Math.sin(t / 910 + n * 0.21);
      var edge = 1 - Math.abs(n / bars - 0.5) * 1.2;
      var h = (0.03 + 0.12 * wob * edge + 0.1 * pulse * edge) * H;
      ctx.fillStyle = rgb(acc, 0.8);
      ctx.fillRect(n * bw + 2, horizon - h, bw - 4, h);
    }

    // beat flash overlay
    ctx.fillStyle = rgb(acc, 0.05 * pulse);
    ctx.fillRect(0, 0, W, H);
  }

  /* ---------- collections cards ---------- */
  var COLL = [
    ['BeatsWall', '#ff4fa3', '#6a2cff'], ['Concert', '#ffb347', '#d6205a'], ['Light Show', '#4ff0ff', '#6a2cff'],
    ['Skateboarding', '#ffd23f', '#ee5a24'], ['Synthwave', '#ff2e93', '#2b0a5e'], ['Space', '#6c5ce7', '#050520'],
    ['Ocean & Nature', '#00cec9', '#0a3d62'], ['Lo-fi Chill', '#fab1a0', '#6c5ce7'], ['Halloween', '#ff9f1a', '#2d1b4e'],
    ['Retro Arcade', '#55efc4', '#d63031'], ['Neon Tokyo', '#ff6bd6', '#1b1464'], ['Winter Holidays', '#dff9fb', '#2980b9'],
    ['Deep Sea', '#48dbfb', '#01123a'], ['Abstract Minimal', '#f5f6fa', '#576574'], ['Cyberpunk', '#f9ff3d', '#7d1ea8'],
    ['Tropical Jungle', '#7bed9f', '#0b5345'], ['Desert Night', '#ffbe76', '#30336b']
  ];
  var track = $('track');
  COLL.forEach(function (c, idx) {
    var d = document.createElement('div');
    d.className = 'ccard';
    d.style.background = 'linear-gradient(155deg,' + c[1] + ',' + c[2] + ')';
    d.innerHTML = '<div class="n">' + String(idx + 1).padStart(2, '0') + '</div><b></b><span>Live wallpapers</span>';
    d.querySelector('b').textContent = c[0];
    track.appendChild(d);
  });

  /* ---------- scroll-driven pieces ---------- */
  var bar = $('progress'), heroInner = $('heroInner'), mac = $('mac');
  var desktop = $('desktop'), hpin = $('collections');
  var shots = document.querySelectorAll('.shot'), dots = document.querySelectorAll('#dots i');
  var capTitle = $('capTitle'), capText = $('capText');
  var CAPS = [
    ['Concert: Main Stage', 'A full concert stage on your desktop, lit by the song you’re playing.'],
    ['Synthwave: Outrun Grid', 'A neon grid that rolls forward on every bar.'],
    ['BeatsWall: Beat B', 'The signature BeatsWall look, pulsing with the bass.'],
    ['BeatsWall: Woofie', 'Because every desktop needs a dog that dances.']
  ];
  var step = -1;
  var steps = $('steps'), lineFill = $('lineFill');

  // how far (0..1) we've scrolled through a tall section
  function sectionProgress(el) {
    var r = el.getBoundingClientRect();
    return clamp(-r.top / (r.height - window.innerHeight), 0, 1);
  }

  function setHPinHeight() {
    var vw = window.innerWidth;
    var extra = Math.max(0, track.scrollWidth - vw);
    hpin.style.height = (window.innerHeight + extra) + 'px';
  }
  window.addEventListener('resize', setHPinHeight);
  setHPinHeight();

  function update() {
    var max = document.documentElement.scrollHeight - window.innerHeight;
    progress = max > 0 ? clamp(window.scrollY / max, 0, 1) : 0;
    bar.style.transform = 'scaleX(' + progress + ')';

    // hero text drifts up and fades
    var hp = clamp(window.scrollY / (window.innerHeight * 0.8), 0, 1);
    heroInner.style.transform = 'translateY(' + (-hp * 80) + 'px) scale(' + (1 - hp * 0.08) + ')';
    heroInner.style.opacity = String(1 - hp);

    // pinned desktop: swap wallpaper by scroll position
    var dp = sectionProgress(desktop);
    var s = Math.min(shots.length - 1, Math.floor(dp * shots.length));
    if (s !== step) {
      step = s;
      shots.forEach(function (el, i) { el.classList.toggle('on', i === s); });
      dots.forEach(function (el, i) { el.classList.toggle('on', i === s); });
      capTitle.textContent = CAPS[s][0]; capText.textContent = CAPS[s][1];
    }
    if (!reduce) mac.style.transform = 'perspective(1200px) rotateY(' + (lerp(-12, 12, dp)) + 'deg) rotateX(' + (lerp(6, -3, dp)) + 'deg)';

    // horizontal collections
    var hpP = sectionProgress(hpin);
    var dist = Math.max(0, track.scrollWidth - window.innerWidth);
    track.style.transform = 'translateX(' + (-hpP * dist) + 'px)';

    // install timeline fills as you scroll
    var sr = steps.getBoundingClientRect();
    var fill = clamp((window.innerHeight * 0.65 - sr.top) / sr.height, 0, 1);
    lineFill.style.height = (fill * 100) + '%';
  }

  var ticking = false;
  window.addEventListener('scroll', function () {
    if (!ticking) { ticking = true; requestAnimationFrame(function () { update(); ticking = false; }); }
  }, { passive: true });
  window.addEventListener('resize', update);
  window.addEventListener('load', function () { setHPinHeight(); update(); });

  /* ---------- reveal on view ---------- */
  var io = 'IntersectionObserver' in window ? new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.15 }) : null;
  document.querySelectorAll('.reveal').forEach(function (el) {
    if (io) io.observe(el); else el.classList.add('in');
  });

  /* ---------- render loop ---------- */
  function loop(t) {
    draw(t);
    if (!reduce) requestAnimationFrame(loop);
  }
  update();
  if (reduce) {
    draw(0);
    window.addEventListener('scroll', function () { draw(0); }, { passive: true });
  } else {
    requestAnimationFrame(loop);
  }
})();
