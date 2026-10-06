/* Core-Monitor site
   A simulated Mac, sampled ten times a second, drives every live number on the
   page. Nothing here talks to a server. */

(function () {
  "use strict";

  var doc = document;
  var root = doc.documentElement;
  var $ = function (sel, ctx) { return (ctx || doc).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || doc).querySelectorAll(sel)); };
  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var colorScheme = window.matchMedia("(prefers-color-scheme: dark)");

  root.classList.remove("no-live");

  /* ---------- menu (small screens) ---------- */

  var menuBtn = $("[data-menu-toggle]");
  var menu = $("[data-menu]");
  if (menuBtn && menu) {
    var setMenu = function (open) {
      menu.classList.toggle("is-open", open);
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
      menuBtn.textContent = open ? "Close" : "Menu";
    };
    menuBtn.addEventListener("click", function () { setMenu(!menu.classList.contains("is-open")); });
    menu.addEventListener("click", function (event) { if (event.target.closest("a")) setMenu(false); });
    doc.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && menu.classList.contains("is-open")) { setMenu(false); menuBtn.focus(); }
    });
  }

  /* ---------- copy-to-clipboard ---------- */

  var copyStatus = doc.getElementById("copy-status");

  $$("[data-copy]").forEach(function (button) {
    var resting = button.textContent;
    var timer = null;

    button.addEventListener("click", function () {
      var source = doc.getElementById(button.getAttribute("data-copy"));
      var text = source ? source.textContent.replace(/^#.*\n/, "").replace(/\s+$/, "") : "";

      var settle = function (ok) {
        button.textContent = ok ? "Copied" : "Copy failed";
        if (copyStatus) {
          copyStatus.textContent = ok
            ? "Command copied to the clipboard."
            : "Copying failed. Select the command and copy it manually.";
        }
        window.clearTimeout(timer);
        timer = window.setTimeout(function () {
          button.textContent = resting;
          if (copyStatus) copyStatus.textContent = "";
        }, 2200);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { settle(true); }, function () { settle(false); });
      } else {
        settle(false);
      }
    });
  });

  /* ---------- the simulated Mac ---------- */

  var HZ = 10;
  var DT = 1 / HZ;
  var N = 600; // sixty seconds of history

  function Ring(n, init) {
    this.a = new Float32Array(n);
    this.a.fill(init);
    this.n = n;
    this.i = 0;
  }
  Ring.prototype.push = function (v) { this.a[this.i] = v; this.i = (this.i + 1) % this.n; };
  Ring.prototype.at = function (k) { return this.a[(this.i + k) % this.n]; };
  Ring.prototype.last = function () { return this.a[(this.i + this.n - 1) % this.n]; };

  function gauss() {
    var u = 0, v = 0;
    while (u === 0) u = Math.random();
    while (v === 0) v = Math.random();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  }
  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
  function lerp(a, b, k) { return a + (b - a) * k; }
  function ease(dt, tau) { return 1 - Math.exp(-dt / tau); }

  // [temperature °C, fan rpm]
  var CURVE_DEFAULT = [[35, 1200], [55, 1800], [70, 3200], [85, 5200], [100, 6500]];
  var CURVE_MACOS = [[40, 1200], [70, 1600], [85, 3800], [100, 6500]];

  function curveAt(points, t) {
    if (t <= points[0][0]) return points[0][1];
    for (var i = 1; i < points.length; i++) {
      if (t <= points[i][0]) {
        var a = points[i - 1], b = points[i];
        return lerp(a[1], b[1], (t - a[0]) / (b[0] - a[0]));
      }
    }
    return points[points.length - 1][1];
  }

  var sim = {
    t: 0,
    cpu: 14, pc: 18, ec: 6, gpu: 5,
    cores: [0.2, 0.15, 0.22, 0.18, 0.06, 0.05, 0.08, 0.04, 0.05, 0.06],
    temp: 52, gpuTemp: 49,
    fan: 2790, fan2: 2802,
    power: 9.2,
    mem: 65, memApp: 0.52, memComp: 0.08,
    netD: 1000, netU: 200, netSpike: 0,
    burst: null, gpuBurst: null,
    auto: false,
    curve: CURVE_DEFAULT.map(function (p) { return p.slice(); }),
    hist: {
      temp: new Ring(N, 52),
      cpu: new Ring(N, 14),
      fan: new Ring(N, 2790),
      power: new Ring(N, 9),
      mem: new Ring(N, 65),
      net: new Ring(N, 1000)
    },
    step: function (dt) {
      var s = this;
      s.t += dt;

      if (!s.burst) {
        if (Math.random() < 0.012) s.burst = { left: 2.5 + Math.random() * 7, lvl: 38 + Math.random() * 52 };
      } else {
        s.burst.left -= dt;
        if (s.burst.left <= 0) s.burst = null;
      }
      var cpuTarget = s.burst ? s.burst.lvl + 6 * Math.sin(s.t * 3.1) : 10 + 3 * Math.sin(s.t / 5);
      s.cpu = clamp(s.cpu + (cpuTarget - s.cpu) * ease(dt, 0.45) + gauss() * (s.burst ? 2.4 : 1.0), 1, 100);
      s.pc = clamp(s.cpu * 1.3 + gauss() * 2, 0, 100);
      s.ec = clamp(s.cpu * 0.45 + gauss() * 1.5, 0, 100);
      for (var i = 0; i < 10; i++) {
        var base = i < 4 ? s.pc : s.ec;
        var target = clamp(base / 100 + gauss() * 0.06, 0.02, 1);
        s.cores[i] = lerp(s.cores[i], target, 0.35);
      }

      if (!s.gpuBurst) {
        if (Math.random() < 0.004) s.gpuBurst = { left: 3 + Math.random() * 6, lvl: 25 + Math.random() * 30 };
      } else {
        s.gpuBurst.left -= dt;
        if (s.gpuBurst.left <= 0) s.gpuBurst = null;
      }
      s.gpu = clamp(s.gpu + ((s.gpuBurst ? s.gpuBurst.lvl : 4) - s.gpu) * ease(dt, 0.8) + gauss() * 0.6, 0, 100);

      var tempTarget = 45.5 + s.cpu * 0.42 + s.gpu * 0.12;
      s.temp += (tempTarget - s.temp) * ease(dt, 5) + gauss() * 0.06;
      s.gpuTemp += ((s.temp - 3 + s.gpu * 0.08) - s.gpuTemp) * ease(dt, 4) + gauss() * 0.05;

      var fanTarget = curveAt(s.auto ? CURVE_MACOS : s.curve, s.temp);
      s.fan += (fanTarget - s.fan) * ease(dt, 2.2);
      s.fan2 = s.fan * 1.0043 + 3 * Math.sin(s.t * 0.7);

      s.power = Math.max(2.5, 3.6 + s.cpu * 0.24 + s.gpu * 0.2 + gauss() * 0.15);

      s.mem = clamp(s.mem + (65 + (s.burst ? 4 : 0) - s.mem) * 0.004 + gauss() * 0.05, 55, 80);
      s.memApp = s.mem / 100 * 0.8;
      s.memComp = s.mem / 100 * 0.12;

      if (Math.random() < 0.018) s.netSpike = 2e5 + Math.random() * 3.2e6;
      s.netSpike *= Math.exp(-dt / 1.4);
      s.netD = 400 + Math.random() * 1400 + s.netSpike;
      s.netU = 80 + Math.random() * 300 + s.netSpike * 0.07;

      s.hist.temp.push(s.temp);
      s.hist.cpu.push(s.cpu);
      s.hist.fan.push(s.fan);
      s.hist.power.push(s.power);
      s.hist.mem.push(s.mem);
      s.hist.net.push(s.netD);
    }
  };

  // Fill a minute of history so the charts are full on first paint.
  for (var k = 0; k < N; k++) sim.step(DT);

  /* ---------- formatting ---------- */

  var fmtInt = function (v) { return Math.round(v).toLocaleString("en-US"); };
  function fmtBytes(v) {
    if (v >= 1e6) return { n: (v / 1e6).toFixed(1), u: "MB/s" };
    return { n: (v / 1e3).toFixed(1), u: "KB/s" };
  }

  function statusFor(s) {
    if (s.temp >= 78) return "Running hot. Fans are ramping.";
    if (s.temp >= 64 || s.cpu >= 55) return "Working. Cooling is keeping up.";
    return "Running cool. Everything looks normal.";
  }
  function pressureFor(t) {
    return t < 70 ? "No thermal pressure" : t < 80 ? "Mild thermal pressure" : t < 90 ? "Serious thermal pressure" : "Critical thermal pressure";
  }

  /* ---------- text bindings ---------- */

  var bound = {};
  $$("[data-r]").forEach(function (el) {
    var key = el.getAttribute("data-r");
    (bound[key] = bound[key] || []).push(el);
  });
  function setText(key, value) {
    var list = bound[key];
    if (!list) return;
    for (var i = 0; i < list.length; i++) {
      if (list[i].textContent !== value) list[i].textContent = value;
    }
  }

  var coreBars = $$("[data-cores] i");
  var diskBar = $("[data-disk]");
  if (diskBar) {
    diskBar.children[0].style.setProperty("--w", "0.73");
    diskBar.children[1].style.setProperty("--w", "0.078");
  }

  function updateText() {
    var s = sim;
    var net = fmtBytes(s.netD), up = fmtBytes(s.netU);
    var gb = s.mem / 100 * 16;

    setText("temp", String(Math.round(s.temp)));
    setText("temp-deg", Math.round(s.temp) + " °C");
    setText("gpu-temp", String(Math.round(s.gpuTemp)));
    setText("fan", fmtInt(s.fan));
    setText("fan-rpm", fmtInt(s.fan) + " rpm");
    setText("cpu", String(Math.round(s.cpu)));
    setText("cpu-pct", Math.round(s.cpu) + "%");
    setText("pcore", String(Math.round(s.pc)));
    setText("ecore", String(Math.round(s.ec)));
    setText("power", s.power.toFixed(1));
    setText("mem-gb", gb.toFixed(1));
    setText("mem-app", (gb * 0.68).toFixed(1));
    setText("mem-wired", (gb * 0.21).toFixed(1));
    setText("mem-comp", (gb * 0.11).toFixed(1));
    setText("mem-pressure", s.mem < 72 ? "Pressure normal" : "Pressure elevated");
    setText("net-down", net.n);
    setText("net-down-unit", net.u);
    setText("net-up", up.n);
    setText("net-up-unit", up.u);
    setText("pressure", pressureFor(s.temp));
    setText("cool-mode", s.auto ? "System automatic" : "Custom curve");
    setText("status", statusFor(s));

    for (var i = 0; i < coreBars.length; i++) coreBars[i].style.setProperty("--h", s.cores[i].toFixed(3));
  }

  /* ---------- canvases ---------- */

  var tintCache = {};
  var TINT_BY_KEY = { temp: "thermal", cpu: "cpu", fan: "cooling", power: "power", mem: "memory", net: "network" };
  var SCALE_BY_KEY = { temp: [30, 100], cpu: [0, 100], fan: [0, 7000], power: [0, 40], mem: [0, 100], net: [0, 4e6] };

  function tint(name) {
    if (!tintCache[name]) {
      tintCache[name] = getComputedStyle(root).getPropertyValue("--tint-" + name).trim() || "#999";
    }
    return tintCache[name];
  }
  var onScheme = function () { tintCache = {}; drawAll(0, true); };
  if (colorScheme.addEventListener) colorScheme.addEventListener("change", onScheme);
  else if (colorScheme.addListener) colorScheme.addListener(onScheme);

  function hexToRgba(hex, a) {
    var h = hex.replace("#", "");
    if (h.length === 3) h = h.split("").map(function (c) { return c + c; }).join("");
    var n = parseInt(h, 16);
    return "rgba(" + ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a + ")";
  }

  var inViewport = new WeakMap();
  var viewWatch = "IntersectionObserver" in window
    ? new IntersectionObserver(function (entries) {
        entries.forEach(function (e) { inViewport.set(e.target, e.isIntersecting); });
      }, { rootMargin: "80px" })
    : null;

  function fitCanvas(canvas) {
    var rect = canvas.getBoundingClientRect();
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var w = Math.max(1, Math.round(rect.width * dpr));
    var h = Math.max(1, Math.round(rect.height * dpr));
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    return { w: w, h: h, dpr: dpr };
  }

  /* a sparkline: one sensor, the last minute, autoscaled with a floor so flat lines stay flat */

  function Spark(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.key = canvas.getAttribute("data-spark");
    if (viewWatch) viewWatch.observe(canvas);
  }
  Spark.prototype.draw = function (phase, force) {
    if (!force && viewWatch && inViewport.get(this.canvas) === false) return;
    var size = fitCanvas(this.canvas);
    var ctx = this.ctx, w = size.w, h = size.h, dpr = size.dpr;
    var ring = sim.hist[this.key];
    if (!ring) return;
    var color = tint(TINT_BY_KEY[this.key]);
    var lo = Infinity, hi = -Infinity;
    for (var i = 0; i < N; i++) { var v = ring.at(i); if (v < lo) lo = v; if (v > hi) hi = v; }
    var scale = SCALE_BY_KEY[this.key];
    var span = Math.max(hi - lo, (scale[1] - scale[0]) * 0.08);
    var mid = (hi + lo) / 2;
    lo = mid - span / 2 - span * 0.12;
    hi = mid + span / 2 + span * 0.12;
    var dx = w / (N - 1);
    var pad = 2 * dpr;

    ctx.clearRect(0, 0, w, h);

    // baseline
    ctx.beginPath();
    ctx.moveTo(0, h - 0.5 * dpr); ctx.lineTo(w, h - 0.5 * dpr);
    ctx.strokeStyle = hexToRgba(color, 0.25);
    ctx.lineWidth = 1 * dpr;
    ctx.stroke();

    ctx.beginPath();
    for (i = 0; i < N; i++) {
      var x = w - (N - 1 - i + phase) * dx;
      var y = pad + (1 - (ring.at(i) - lo) / (hi - lo)) * (h - pad * 2);
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.lineWidth = 1.5 * dpr;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.strokeStyle = color;
    ctx.stroke();

    var hx = w - phase * dx;
    var hy = pad + (1 - (ring.last() - lo) / (hi - lo)) * (h - pad * 2);
    ctx.beginPath(); ctx.arc(Math.min(hx, w - 2 * dpr), hy, 2.5 * dpr, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill();
  };

  var sparks = $$("canvas[data-spark]").map(function (c) { return new Spark(c); });

  /* the hero trace: three sensors on one minute-long timeline, labelled at the line ends */

  var traceBox = $("[data-trace]");
  var trace = traceBox ? (function () {
    var canvas = $("canvas", traceBox);
    var ctx = canvas.getContext("2d");
    if (viewWatch) viewWatch.observe(canvas);
    var series = [
      { key: "temp", tint: "thermal", lo: 30, hi: 100, fill: true },
      { key: "cpu", tint: "cpu", lo: 0, hi: 100, fill: false },
      { key: "fan", tint: "cooling", lo: 0, hi: 7000, fill: false }
    ];
    var labels = {};
    $$("[data-trace-label]", traceBox).forEach(function (el) { labels[el.getAttribute("data-trace-label")] = el; });
    var PAD = 18; // css px, top and bottom

    function placeLabels(h) {
      // Spread the three labels so they never overlap, then set them.
      var want = series.map(function (s) {
        var ring = sim.hist[s.key];
        return { key: s.key, y: PAD + (1 - (ring.last() - s.lo) / (s.hi - s.lo)) * (h - PAD * 2) };
      });
      want.sort(function (a, b) { return a.y - b.y; });
      var minGap = 36;
      for (var i = 1; i < want.length; i++) {
        if (want[i].y - want[i - 1].y < minGap) want[i].y = want[i - 1].y + minGap;
      }
      for (i = want.length - 2; i >= 0; i--) {
        if (want[i + 1].y - want[i].y < minGap) want[i].y = want[i + 1].y - minGap;
      }
      want.forEach(function (p) {
        var el = labels[p.key];
        if (!el) return;
        var y = clamp(p.y, 14, h - 14);
        el.style.setProperty("--y", y.toFixed(1) + "px");
        el.style.setProperty("--c", tint(TINT_BY_KEY[p.key]));
      });
    }

    return {
      draw: function (phase, force) {
        if (!force && viewWatch && inViewport.get(canvas) === false) return;
        var size = fitCanvas(canvas), w = size.w, h = size.h, dpr = size.dpr;
        var pad = PAD * dpr;
        var dx = w / (N - 1);
        ctx.clearRect(0, 0, w, h);

        // faint horizontal rules, like a chart on paper
        ctx.strokeStyle = getComputedStyle(root).getPropertyValue("--rule").trim() || "rgba(0,0,0,.15)";
        ctx.lineWidth = 1;
        for (var g = 0; g <= 4; g++) {
          var gy = Math.round(pad + (h - pad * 2) * g / 4) + 0.5;
          ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke();
        }

        series.forEach(function (s) {
          var ring = sim.hist[s.key];
          var color = tint(s.tint);
          var path = function () {
            ctx.beginPath();
            for (var i = 0; i < N; i++) {
              var x = w - (N - 1 - i + phase) * dx;
              var y = pad + (1 - (ring.at(i) - s.lo) / (s.hi - s.lo)) * (h - pad * 2);
              if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
          };
          if (s.fill) {
            path();
            ctx.lineTo(w - phase * dx, h); ctx.lineTo(w - (N - 1 + phase) * dx, h); ctx.closePath();
            var grad = ctx.createLinearGradient(0, 0, 0, h);
            grad.addColorStop(0, hexToRgba(color, 0.14));
            grad.addColorStop(1, hexToRgba(color, 0));
            ctx.fillStyle = grad;
            ctx.fill();
          }
          path();
          ctx.lineJoin = "round"; ctx.lineCap = "round";
          ctx.strokeStyle = color;
          ctx.lineWidth = 1.6 * dpr;
          ctx.stroke();

          var hx = Math.min(w - phase * dx, w - 3 * dpr);
          var hy = pad + (1 - (ring.last() - s.lo) / (s.hi - s.lo)) * (h - pad * 2);
          ctx.beginPath(); ctx.arc(hx, hy, 3 * dpr, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill();
        });

        placeLabels(h / dpr);
      }
    };
  })() : null;

  /* ---------- cooling lab: an editable fan curve ---------- */

  var labEl = $("[data-lab]");
  var lab = labEl ? (function () {
    var svg = $("svg", labEl);
    var nodes = $$("[data-node]", labEl);
    var line = $("[data-curve-line]", labEl);
    var fill = $("[data-curve-fill]", labEl);
    var op = $("[data-op]", labEl);
    var opRing = $("[data-op-ring]", labEl);
    var opLine = $("[data-op-line]", labEl);
    var opLabel = $("[data-op-label]", labEl);
    var slider = $("[data-lab-temp]", labEl);
    var sliderOut = $("[data-lab-temp-out]", labEl);
    var toggle = $("[data-lab-toggle]", labEl);
    var modeEl = $("[data-lab-mode]", labEl);
    var subEl = $("[data-lab-sub]", labEl);
    var rpmEl = $("[data-lab-rpm]", labEl);
    var fanEl = $("[data-fan]", labEl);

    var X0 = 48, X1 = 540, Y0 = 256, Y1 = 20, T0 = 30, T1 = 100, R1 = 6500;
    var tx = function (t) { return X0 + (t - T0) / (T1 - T0) * (X1 - X0); };
    var ty = function (r) { return Y0 - r / R1 * (Y0 - Y1); };
    var fromX = function (x) { return T0 + (x - X0) / (X1 - X0) * (T1 - T0); };
    var fromY = function (y) { return (Y0 - y) / (Y0 - Y1) * R1; };

    var manualTemp = null;     // null: follow the simulation
    var angle = 0;
    var rpm = 2900;

    labEl.classList.add("is-js");

    function render() {
      var pts = sim.auto ? CURVE_MACOS : sim.curve;
      var d = "M" + X0 + " " + ty(pts[0][1]).toFixed(1);
      for (var i = 0; i < pts.length; i++) d += " L" + tx(pts[i][0]).toFixed(1) + " " + ty(pts[i][1]).toFixed(1);
      d += " L" + X1 + " " + ty(pts[pts.length - 1][1]).toFixed(1);
      line.setAttribute("d", d);
      fill.setAttribute("d", d + " L" + X1 + " " + Y0 + " L" + X0 + " " + Y0 + " Z");
      nodes.forEach(function (n, i) {
        var p = sim.curve[i];
        n.setAttribute("cx", tx(p[0]).toFixed(1));
        n.setAttribute("cy", ty(p[1]).toFixed(1));
        n.setAttribute("aria-valuetext", Math.round(p[0]) + " degrees, " + fmtInt(p[1]) + " rpm");
      });

      var t = manualTemp === null ? sim.temp : manualTemp;
      rpm = curveAt(pts, t);
      var ox = tx(t), oy = ty(rpm);
      op.setAttribute("cx", ox.toFixed(1)); op.setAttribute("cy", oy.toFixed(1));
      opRing.setAttribute("cx", ox.toFixed(1)); opRing.setAttribute("cy", oy.toFixed(1));
      opLine.setAttribute("x1", ox.toFixed(1)); opLine.setAttribute("x2", ox.toFixed(1)); opLine.setAttribute("y2", oy.toFixed(1));
      opLabel.textContent = Math.round(t) + "° · " + fmtInt(rpm) + " rpm";
      var flip = ox > X1 - 120;
      opLabel.setAttribute("text-anchor", flip ? "end" : "start");
      opLabel.setAttribute("x", (flip ? ox - 10 : ox + 10).toFixed(1));
      opLabel.setAttribute("y", Math.max(Y1 + 12, oy - 10).toFixed(1));

      if (slider && manualTemp === null) slider.value = String(Math.round(t));
      if (sliderOut) sliderOut.textContent = Math.round(t) + "°";
      if (rpmEl) rpmEl.textContent = fmtInt(rpm);
      if (modeEl) modeEl.textContent = sim.auto ? "macOS" : "Your curve";
      if (subEl) {
        subEl.textContent = sim.auto
          ? "deciding on its own; the curve is parked"
          : manualTemp === null ? "following the live temperature" : "following the temperature you set";
      }
    }

    /* dragging */
    var dragging = null;
    var svgPoint = function (event) {
      var pt = svg.createSVGPoint();
      pt.x = event.clientX; pt.y = event.clientY;
      var ctm = svg.getScreenCTM();
      return ctm ? pt.matrixTransform(ctm.inverse()) : pt;
    };
    var moveNode = function (i, t, r) {
      var pts = sim.curve;
      var lo = i === 0 ? T0 : pts[i - 1][0] + 1;
      var hi = i === pts.length - 1 ? T1 : pts[i + 1][0] - 1;
      pts[i][0] = Math.round(clamp(t, lo, hi));
      pts[i][1] = Math.round(clamp(r, 0, R1) / 50) * 50;
      render();
    };

    nodes.forEach(function (n, i) {
      n.addEventListener("pointerdown", function (event) {
        if (sim.auto) return;
        dragging = i;
        n.classList.add("is-dragging");
        n.setPointerCapture(event.pointerId);
        event.preventDefault();
      });
      n.addEventListener("pointermove", function (event) {
        if (dragging !== i) return;
        var p = svgPoint(event);
        moveNode(i, fromX(p.x), fromY(p.y));
      });
      var release = function () {
        if (dragging !== i) return;
        dragging = null;
        n.classList.remove("is-dragging");
      };
      n.addEventListener("pointerup", release);
      n.addEventListener("pointercancel", release);
      n.addEventListener("keydown", function (event) {
        if (sim.auto) return;
        var pts = sim.curve;
        var stepT = event.shiftKey ? 5 : 1, stepR = event.shiftKey ? 500 : 100;
        var handled = true;
        switch (event.key) {
          case "ArrowLeft": moveNode(i, pts[i][0] - stepT, pts[i][1]); break;
          case "ArrowRight": moveNode(i, pts[i][0] + stepT, pts[i][1]); break;
          case "ArrowUp": moveNode(i, pts[i][0], pts[i][1] + stepR); break;
          case "ArrowDown": moveNode(i, pts[i][0], pts[i][1] - stepR); break;
          default: handled = false;
        }
        if (handled) event.preventDefault();
      });
    });

    if (slider) {
      slider.addEventListener("input", function () {
        manualTemp = Number(slider.value);
        render();
      });
    }

    if (toggle) {
      toggle.addEventListener("click", function () {
        sim.auto = !sim.auto;
        labEl.classList.toggle("is-auto", sim.auto);
        toggle.textContent = sim.auto ? "Take the fans back" : "Hand cooling back to macOS";
        render();
        updateText();
      });
    }

    render();

    return {
      render: render,
      spin: function (dt) {
        if (!fanEl || reducedMotion.matches) return;
        angle = (angle + rpm / 2800 * 360 * dt) % 360;
        fanEl.style.transform = "rotate(" + angle.toFixed(1) + "deg)";
      }
    };
  })() : null;

  /* ---------- videos: play muted while on screen ---------- */

  $$("video[data-autoplay]").forEach(function (video) {
    if (reducedMotion.matches || !("IntersectionObserver" in window)) return;
    var followView = true;
    var selfPausing = false;
    video.addEventListener("pause", function () {
      if (!selfPausing) followView = false;
      selfPausing = false;
    });
    new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!followView) return;
        if (entry.isIntersecting) {
          video.muted = true;
          var playing = video.play();
          if (playing && playing.catch) playing.catch(function () {});
        } else if (!video.paused) {
          selfPausing = true;
          video.pause();
        }
      });
    }, { threshold: 0.5 }).observe(video);
  });

  /* ---------- main loop ---------- */

  function drawAll(phase, force) {
    for (var i = 0; i < sparks.length; i++) sparks[i].draw(phase, force);
    if (trace) trace.draw(phase, force);
  }

  updateText();
  drawAll(0, true);

  var textEvery = HZ / 2; // numbers settle at 2 Hz so they stay readable
  var stepCount = 0;

  function afterStep() {
    stepCount++;
    if (stepCount % textEvery === 0) {
      updateText();
      if (lab) lab.render();
    }
  }

  if (reducedMotion.matches) {
    // Still alive, just calm: advance once a second, no interpolation, no spinning.
    window.setInterval(function () {
      if (doc.hidden) return;
      for (var i = 0; i < HZ; i++) { sim.step(DT); }
      stepCount = 0; updateText(); if (lab) lab.render();
      drawAll(0, false);
    }, 1000);
  } else {
    var last = performance.now();
    var acc = 0;
    var running = false;

    var frame = function (now) {
      var dt = Math.min((now - last) / 1000, 0.25);
      last = now;
      acc += dt;
      while (acc >= DT) { sim.step(DT); acc -= DT; afterStep(); }
      drawAll(acc / DT, false);
      if (lab) lab.spin(dt);
      if (doc.hidden) { running = false; return; }
      requestAnimationFrame(frame);
    };
    var start = function () {
      if (running) return;
      running = true;
      last = performance.now();
      requestAnimationFrame(frame);
    };
    doc.addEventListener("visibilitychange", function () { if (!doc.hidden) start(); });
    start();
  }

  var resizeTimer = null;
  window.addEventListener("resize", function () {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(function () { drawAll(0, true); }, 80);
  });
})();
