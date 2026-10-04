/* ==========================================================================
   Core-Monitor site behaviour

   Everything here is progressive enhancement. With this file blocked the
   page still reads correctly: charts and readings show a fixed sample, the
   screenshot tabs still switch (they are radio buttons), and the fan curve
   shows its operating point. No libraries, no network requests.

   The readings are simulated. One small model of a Mac (load, heat, fans,
   memory, power, network) drives every live number on the page, so the
   menu bar, the floating cards, the tiles and the Touch Bar always agree.
   With reduced motion the model renders once and stays still.
   ========================================================================== */

(function () {
  "use strict";

  var doc = document;
  var root = doc.documentElement;
  root.classList.add("js");

  var still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var canObserve = "IntersectionObserver" in window;
  var finePointer = window.matchMedia("(hover: hover) and (pointer: fine)").matches;

  function $(selector, scope) { return (scope || doc).querySelector(selector); }
  function $$(selector, scope) { return Array.prototype.slice.call((scope || doc).querySelectorAll(selector)); }
  function clamp(value, low, high) { return value < low ? low : value > high ? high : value; }
  function rand(low, high) { return low + Math.random() * (high - low); }
  function wobble() { return Math.random() * 2 - 1; }

  var whole = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });
  var tenth = new Intl.NumberFormat("en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 });

  // Calls back with true or false as an element enters or leaves the viewport.
  function watch(el, callback, margin) {
    if (!el) return;
    if (!canObserve) { callback(true); return; }
    new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) { callback(entry.isIntersecting); });
    }, { rootMargin: margin || "80px 0px" }).observe(el);
  }

  /* ---------- navigation: menu, scrolled state, progress, active link ---------- */

  var nav = $("[data-nav]");
  var menuBtn = $("[data-menu-btn]");
  var menu = $("[data-menu]");

  if (menuBtn && menu) {
    var setMenu = function (open) {
      menu.classList.toggle("is-open", open);
      if (nav) nav.classList.toggle("is-open", open);
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
      menuBtn.textContent = open ? "Close" : "Menu";
    };

    menuBtn.addEventListener("click", function () {
      setMenu(!menu.classList.contains("is-open"));
    });

    menu.addEventListener("click", function (event) {
      if (event.target.closest("a")) setMenu(false);
    });

    doc.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && menu.classList.contains("is-open")) {
        setMenu(false);
        menuBtn.focus();
      }
    });
  }

  var progress = $("[data-progress]");
  var activeLink = null;
  var desk = $("[data-desk]");
  var hero = desk ? desk.closest(".hero") : null;
  var tilting = !still && desk && hero;
  var scrollQueued = false;

  function onScroll() {
    scrollQueued = false;
    var y = window.scrollY;
    if (nav) nav.classList.toggle("is-scrolled", y > 8);
    if (activeLink && y < window.innerHeight * 0.4) {
      activeLink.classList.remove("is-active");
      activeLink = null;
    }
    if (progress) {
      var room = root.scrollHeight - window.innerHeight;
      progress.style.transform = "scaleX(" + (room > 0 ? clamp(y / room, 0, 1) : 0).toFixed(4) + ")";
    }
    if (tilting) {
      // The screen leans back on load and straightens as the page scrolls.
      var lean = 1 - clamp(-hero.getBoundingClientRect().top / (window.innerHeight * 0.5), 0, 1);
      desk.style.setProperty("--tilt", lean.toFixed(3));
    }
  }

  window.addEventListener("scroll", function () {
    if (!scrollQueued) {
      scrollQueued = true;
      window.requestAnimationFrame(onScroll);
    }
  }, { passive: true });
  onScroll();

  var navLinks = $$("[data-menu] a[href^='#']");
  if (canObserve && navLinks.length) {
    var linkFor = {};
    navLinks.forEach(function (link) { linkFor[link.getAttribute("href").slice(1)] = link; });
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var link = linkFor[entry.target.id];
        if (!link) return;
        if (entry.isIntersecting) {
          if (activeLink) activeLink.classList.remove("is-active");
          activeLink = link;
          link.classList.add("is-active");
        } else if (link === activeLink && entry.boundingClientRect.top > 0) {
          link.classList.remove("is-active");
          activeLink = null;
        }
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    Object.keys(linkFor).forEach(function (id) {
      var section = doc.getElementById(id);
      if (section) spy.observe(section);
    });
  }

  /* ---------- reveal on scroll ---------- */

  var reveals = $$(".reveal");
  if (!still && canObserve) {
    var revealer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          revealer.unobserve(entry.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.06 });
    reveals.forEach(function (el) { revealer.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add("is-in"); });
  }

  /* ---------- copy to clipboard ---------- */

  var copyStatus = doc.getElementById("copy-status");

  $$("[data-copy]").forEach(function (button) {
    var label = $("span", button) || button;
    var resting = label.textContent;
    var timer = 0;

    button.addEventListener("click", function () {
      var source = doc.getElementById(button.getAttribute("data-copy"));
      var text = source ? source.textContent.replace(/\s+$/, "") : "";

      var settle = function (ok) {
        label.textContent = ok ? "Copied" : "Copy failed";
        button.setAttribute("data-state", ok ? "done" : "failed");
        if (copyStatus) {
          copyStatus.textContent = ok
            ? "Command copied to the clipboard."
            : "Copying failed. Select the command and copy it manually.";
        }
        window.clearTimeout(timer);
        timer = window.setTimeout(function () {
          label.textContent = resting;
          button.removeAttribute("data-state");
          if (copyStatus) copyStatus.textContent = "";
        }, 2200);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(
          function () { settle(true); },
          function () { settle(false); }
        );
      } else {
        settle(false);
      }
    });
  });

  /* ---------- the simulated Mac ---------- */

  // Temperature to fan speed, shared by the live readings and the curve demo.
  var CURVE = [[40, 1800], [52, 2700], [66, 3400], [80, 4600], [95, 6000]];

  function rpmFor(temp) {
    if (temp <= CURVE[0][0]) return CURVE[0][1];
    for (var i = 1; i < CURVE.length; i++) {
      if (temp <= CURVE[i][0]) {
        var a = CURVE[i - 1], b = CURVE[i];
        return a[1] + (b[1] - a[1]) * (temp - a[0]) / (b[0] - a[0]);
      }
    }
    return CURVE[CURVE.length - 1][1];
  }

  var model = {
    phase: Math.random() * 60, burst: 0,
    cpu: 14, pcore: 18, ecore: 5, cores: [40, 16, 52, 12, 30, 8, 20, 34, 14, 26],
    temp: 51, gpu: 47, rpm: 2600, rpm2: 2610, mem: 65, watts: 9, down: 1.2, up: 0.4
  };

  function advance() {
    var m = model;
    m.phase += 1;
    m.burst = m.burst * 0.55 + (Math.random() < 0.09 ? rand(18, 46) : 0);
    var base = 15 + 7 * Math.sin(m.phase / 17) + 4 * Math.sin(m.phase / 5.3);
    m.cpu = clamp(base + wobble() * 4 + m.burst, 3, 97);
    m.pcore = clamp(m.cpu * 1.25 + wobble() * 5, 1, 100);
    m.ecore = clamp(m.cpu * 0.45 + wobble() * 4 + 3, 1, 100);
    for (var i = 0; i < m.cores.length; i++) {
      var target = i < 6 ? m.pcore : m.ecore;
      m.cores[i] = clamp(target * rand(0.4, 1.45) + wobble() * 6, 3, 100);
    }
    m.temp += (46 + m.cpu * 0.3 - m.temp) * 0.16 + wobble() * 0.35;
    m.gpu += (m.temp - 4 - m.gpu) * 0.2 + wobble() * 0.3;
    m.rpm += (rpmFor(m.temp) - m.rpm) * 0.25;
    m.rpm2 = m.rpm + 14 + wobble() * 9;
    m.mem = clamp(m.mem + wobble() * 0.35 + (65 - m.mem) * 0.06, 58, 74);
    m.watts = clamp(3.8 + m.cpu * 0.27 + wobble() * 0.5, 2, 40);
    m.down = Math.random() < 0.16 ? rand(30, 640) : Math.max(0.2, m.down * 0.3 + rand(0, 2.2));
    m.up = Math.random() < 0.1 ? rand(10, 180) : Math.max(0.1, m.up * 0.3 + rand(0, 1.2));
  }

  function snapshot() {
    return {
      cpu: model.cpu, pcore: model.pcore, ecore: model.ecore, cores: model.cores.slice(),
      temp: model.temp, gpu: model.gpu, rpm: model.rpm, rpm2: model.rpm2,
      mem: model.mem, watts: model.watts, down: model.down, up: model.up
    };
  }

  // The newest sample sits one tick ahead of what is shown, so a chart can
  // slide it in from the right edge while the numbers settle on the last one.
  var HISTORY = 64;
  var samples = [];
  for (var s = 0; s < HISTORY; s++) { advance(); samples.push(snapshot()); }

  function shown() { return samples[samples.length - 2]; }

  function rate(kb) {
    if (kb >= 1000) return [tenth.format(kb / 1000), "MB/s"];
    return [kb >= 10 ? whole.format(kb) : tenth.format(kb), "KB/s"];
  }

  function shortRate(kb) {
    if (kb >= 1000) return tenth.format(kb / 1000) + "M";
    return (kb >= 10 ? whole.format(kb) : tenth.format(kb)) + "K";
  }

  function roundRpm(rpm) { return whole.format(Math.round(rpm / 10) * 10); }

  var formats = {
    cpu: function (d) { return whole.format(d.cpu); },
    pcore: function (d) { return whole.format(d.pcore); },
    ecore: function (d) { return whole.format(d.ecore); },
    temp: function (d) { return whole.format(d.temp); },
    gpu: function (d) { return whole.format(d.gpu); },
    rpm: function (d) { return roundRpm(d.rpm); },
    rpmShort: function (d) { return tenth.format(d.rpm / 1000) + "k"; },
    rpm2Short: function (d) { return tenth.format(d.rpm2 / 1000) + "k"; },
    mem: function (d) { return whole.format(d.mem); },
    memGB: function (d) { return tenth.format(d.mem / 100 * 16); },
    watts: function (d) { return tenth.format(d.watts); },
    downNum: function (d) { return rate(d.down)[0]; },
    downUnit: function (d) { return rate(d.down)[1]; },
    upNum: function (d) { return rate(d.up)[0]; },
    upUnit: function (d) { return rate(d.up)[1]; },
    downShort: function (d) { return shortRate(d.down); }
  };

  var liveText = $$("[data-live]");
  var cores = $$("[data-core]");
  var rings = $$("[data-ring]");
  var memParts = $$("[data-mem]");

  function paintReadings() {
    var d = shown();
    liveText.forEach(function (el) {
      var format = formats[el.getAttribute("data-live")];
      if (!format) return;
      var text = format(d);
      if (el.textContent !== text) el.textContent = text;
    });
    cores.forEach(function (el, i) {
      el.style.setProperty("--h", (d.cores[i % d.cores.length] / 100).toFixed(3));
    });
    rings.forEach(function (el) {
      var rpm = el.getAttribute("data-ring") === "rpm2" ? d.rpm2 : d.rpm;
      el.style.setProperty("--pct", clamp(rpm / 6000 * 100, 4, 100).toFixed(1));
    });
    memParts.forEach(function (el) {
      var part = el.getAttribute("data-mem");
      var share = part === "app" ? 0.48 : part === "wired" ? 0.2 : part === "comp" ? 0.32 : 1;
      el.style.setProperty("--w", (d.mem * share).toFixed(1));
    });
  }

  /* ---------- sparklines and bar charts ---------- */

  function smoothPath(points, height) {
    var d = "M" + points[0][0].toFixed(1) + " " + points[0][1].toFixed(1);
    for (var i = 0; i < points.length - 1; i++) {
      var p0 = points[i - 1] || points[i];
      var p1 = points[i];
      var p2 = points[i + 1];
      var p3 = points[i + 2] || p2;
      var c1y = clamp(p1[1] + (p2[1] - p0[1]) / 6, 0, height);
      var c2y = clamp(p2[1] - (p3[1] - p1[1]) / 6, 0, height);
      d += "C" + (p1[0] + (p2[0] - p0[0]) / 6).toFixed(1) + " " + c1y.toFixed(1) + " " +
        (p2[0] - (p3[0] - p1[0]) / 6).toFixed(1) + " " + c2y.toFixed(1) + " " +
        p2[0].toFixed(1) + " " + p2[1].toFixed(1);
    }
    return d;
  }

  function Spark(svg) {
    var box = svg.viewBox.baseVal;
    this.svg = svg;
    this.width = box.width;
    this.height = box.height;
    this.count = +(svg.getAttribute("data-points") || 40);
    this.step = this.width / (this.count - 1);
    this.min = svg.hasAttribute("data-min") ? +svg.getAttribute("data-min") : 0;
    this.max = svg.hasAttribute("data-max") ? +svg.getAttribute("data-max") : null;
    this.floor = +(svg.getAttribute("data-floor") || 0);
    this.sqrt = svg.getAttribute("data-scale") === "sqrt";
    this.mover = $(".spark-move", svg);
    this.paths = $$("[data-series]", svg);
    this.visible = false;
  }

  Spark.prototype.render = function () {
    var self = this;
    var recent = samples.slice(-(this.count + 1));
    var keys = {};
    this.paths.forEach(function (path) { keys[path.getAttribute("data-series")] = true; });

    var top = this.max;
    if (top === null) {
      top = this.floor;
      Object.keys(keys).forEach(function (key) {
        recent.forEach(function (sample) { top = Math.max(top, sample[key] * 1.18); });
      });
    }
    var scale = function (v) { return self.sqrt ? Math.sqrt(Math.max(v, 0)) : v; };
    var low = scale(this.min);
    var span = Math.max(scale(top) - low, 0.0001);
    var pad = this.height * 0.08;

    var lines = {};
    Object.keys(keys).forEach(function (key) {
      var points = recent.map(function (sample, i) {
        var k = clamp((scale(sample[key]) - low) / span, 0, 1);
        return [i * self.step, self.height - pad - k * (self.height - pad * 2)];
      });
      lines[key] = { d: smoothPath(points, self.height), last: points[points.length - 1][0] };
    });

    this.paths.forEach(function (path) {
      var line = lines[path.getAttribute("data-series")];
      var d = line.d;
      if (path.classList.contains("spark-area")) {
        d += "L" + line.last.toFixed(1) + " " + self.height + "L0 " + self.height + "Z";
      }
      path.setAttribute("d", d);
    });
    this.slide(0);
  };

  Spark.prototype.slide = function (fraction) {
    if (this.mover) this.mover.setAttribute("transform", "translate(" + (-fraction * this.step).toFixed(2) + " 0)");
  };

  function Bars(svg) {
    var box = svg.viewBox.baseVal;
    this.key = svg.getAttribute("data-bars");
    this.count = +(svg.getAttribute("data-points") || 24);
    this.floor = +(svg.getAttribute("data-floor") || 1);
    this.visible = false;
    this.rects = [];
    var gap = box.width / this.count;
    for (var i = 0; i < this.count; i++) {
      var rect = doc.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("x", (i * gap + gap * 0.18).toFixed(2));
      rect.setAttribute("y", "0");
      rect.setAttribute("width", (gap * 0.64).toFixed(2));
      rect.setAttribute("height", String(box.height));
      rect.setAttribute("rx", (gap * 0.18).toFixed(2));
      svg.appendChild(rect);
      this.rects.push(rect);
    }
  }

  Bars.prototype.render = function () {
    var key = this.key;
    var values = samples.slice(-(this.count + 1), -1).map(function (sample) { return sample[key]; });
    var top = Math.max.apply(null, values.concat([this.floor / 1.15])) * 1.15;
    this.rects.forEach(function (rect, i) {
      rect.style.setProperty("--v", clamp(values[i] / top, 0.04, 1).toFixed(3));
    });
  };

  var sparks = $$("svg[data-spark]").map(function (svg) { return new Spark(svg); });
  var barCharts = $$("svg[data-bars]").map(function (svg) { return new Bars(svg); });

  /* ---------- fan rotors ---------- */

  function Rotor(el, speed) {
    this.el = el;
    this.speed = speed;
    this.angle = Math.random() * 90;
    this.visible = false;
  }

  Rotor.prototype.turn = function (ms) {
    // A readable rotation, not a literal one: 3,000 rpm turns 1.5 times a second.
    this.angle = (this.angle + ms / 1000 * this.speed() / 2000 * 360) % 360;
    this.el.style.transform = "rotate(" + this.angle.toFixed(1) + "deg)";
  };

  var rotors = $$("[data-rotor]").map(function (el) {
    return new Rotor(el, function () { return shown().rpm; });
  });

  /* ---------- the frame loop ---------- */

  var TICK = 1000;
  var running = false;
  var lastFrame = 0;
  var elapsed = 0;
  var frameHooks = [];
  var liveRegions = 0;

  function tick() {
    advance();
    samples.push(snapshot());
    if (samples.length > HISTORY) samples.shift();
    paintReadings();
    sparks.forEach(function (spark) { if (spark.visible) spark.render(); });
    barCharts.forEach(function (bars) { if (bars.visible) bars.render(); });
  }

  // Only one loop may exist: stopping cancels the queued frame, so a quick
  // stop and start (a tab switch, or one region leaving as another enters)
  // cannot leave a second loop running.
  var frameId = 0;

  function frame(now) {
    frameId = 0;
    if (!running) return;
    var ms = lastFrame ? Math.min(64, now - lastFrame) : 16;
    lastFrame = now;
    if (liveRegions > 0) {
      elapsed += ms;
      if (elapsed >= TICK) {
        elapsed = elapsed % TICK;
        tick();
      }
      var fraction = elapsed / TICK;
      sparks.forEach(function (spark) { if (spark.visible) spark.slide(fraction); });
      rotors.forEach(function (rotor) { if (rotor.visible) rotor.turn(ms); });
    }
    frameHooks.forEach(function (hook) { hook(ms); });
    frameId = window.requestAnimationFrame(frame);
  }

  function updateRunning() {
    var wanted = !still && !doc.hidden && (liveRegions > 0 || frameHooks.some(function (hook) { return hook.active; }));
    if (wanted && !running) {
      running = true;
      lastFrame = 0;
      if (!frameId) frameId = window.requestAnimationFrame(frame);
    } else if (!wanted && running) {
      running = false;
      if (frameId) window.cancelAnimationFrame(frameId);
      frameId = 0;
    }
  }

  doc.addEventListener("visibilitychange", updateRunning);

  // Each chart and rotor only animates while it is on screen.
  function follow(items, elementOf) {
    items.forEach(function (item) {
      watch(elementOf(item), function (visible) {
        if (visible && !item.visible && item.render) item.render();
        item.visible = visible;
      });
    });
  }

  paintReadings();
  sparks.forEach(function (spark) { spark.render(); });
  barCharts.forEach(function (bars) { bars.render(); });

  if (!still) {
    follow(sparks, function (spark) { return spark.svg; });
    follow(barCharts, function (bars) { return bars.rects[0] && bars.rects[0].ownerSVGElement; });
    follow(rotors, function (rotor) { return rotor.el; });

    $$(".stage, [data-live-region], .deck").forEach(function (region) {
      var inside = false;
      watch(region, function (visible) {
        if (visible === inside) return;
        inside = visible;
        liveRegions += visible ? 1 : -1;
        updateRunning();
      }, "120px 0px");
    });
  }

  /* ---------- hero: pointer parallax for the floating cards ---------- */

  if (tilting && finePointer) {
    var pointer = { x: 0, y: 0, queued: false };
    var applyPointer = function () {
      pointer.queued = false;
      desk.style.setProperty("--px", pointer.x.toFixed(3));
      desk.style.setProperty("--py", pointer.y.toFixed(3));
    };
    hero.addEventListener("pointermove", function (event) {
      pointer.x = event.clientX / window.innerWidth * 2 - 1;
      pointer.y = event.clientY / window.innerHeight * 2 - 1;
      if (!pointer.queued) {
        pointer.queued = true;
        window.requestAnimationFrame(applyPointer);
      }
    });
    hero.addEventListener("pointerleave", function () {
      pointer.x = 0;
      pointer.y = 0;
      window.requestAnimationFrame(applyPointer);
    });
  }

  /* ---------- tiles: a soft light that follows the pointer ---------- */

  if (finePointer) {
    $$("[data-spotlight]").forEach(function (el) {
      el.addEventListener("pointermove", function (event) {
        var box = el.getBoundingClientRect();
        el.style.setProperty("--mx", (event.clientX - box.left).toFixed(0) + "px");
        el.style.setProperty("--my", (event.clientY - box.top).toFixed(0) + "px");
      });
    });
  }

  /* ---------- menu bar and Touch Bar clocks ---------- */

  var clocks = $$("[data-clock]");
  if (clocks.length) {
    var longClock = new Intl.DateTimeFormat(undefined, { weekday: "short", hour: "numeric", minute: "2-digit" });
    var shortClock = new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" });
    var paintClock = function () {
      var now = new Date();
      clocks.forEach(function (el) {
        el.textContent = (el.getAttribute("data-clock") === "short" ? shortClock : longClock).format(now);
      });
    };
    paintClock();
    window.setInterval(paintClock, 20000);
  }

  /* ---------- screenshot tabs: advance on their own until touched ---------- */

  var showcase = $("[data-showcase]");
  if (showcase) {
    var radios = $$("input[type=radio]", showcase);
    var tabs = $$(".sc-tab", showcase);
    var DWELL = 6000;
    var autoplay = !still;
    var inView = false;
    var timer = 0;

    var current = function () {
      for (var i = 0; i < radios.length; i++) if (radios[i].checked) return i;
      return 0;
    };
    var mark = function () {
      var id = radios[current()].id;
      tabs.forEach(function (tab) { tab.classList.toggle("is-current", tab.getAttribute("for") === id); });
    };
    var arm = function () {
      window.clearTimeout(timer);
      showcase.classList.remove("is-running");
      if (!autoplay || !inView || doc.hidden) return;
      void showcase.offsetWidth; // restart the progress line
      showcase.classList.add("is-running");
      timer = window.setTimeout(function () {
        radios[(current() + 1) % radios.length].checked = true;
        mark();
        arm();
      }, DWELL);
    };
    var stop = function () {
      autoplay = false;
      arm();
    };

    radios.forEach(function (radio) {
      radio.addEventListener("change", function () { mark(); stop(); });
    });
    showcase.addEventListener("pointerdown", stop);
    doc.addEventListener("visibilitychange", arm);
    mark();
    watch(showcase, function (visible) {
      if (visible === inView) return;
      inView = visible;
      arm();
    }, "0px");
  }

  /* ---------- fan curve: a slider and a self-driving demo ---------- */

  var curve = $("[data-curve]");
  if (curve) {
    var op = $("[data-op]", curve);
    var opRing = $("[data-op-ring]", curve);
    var guideV = $("[data-guide-v]", curve);
    var guideH = $("[data-guide-h]", curve);
    var tempOut = $("[data-curve-temp]", curve);
    var rpmOut = $("[data-curve-rpm]", curve);
    var sliderWrap = $("[data-curve-slider]", curve);
    var slider = sliderWrap && $("input", sliderWrap);
    var curveRotor = $("[data-curve-rotor]", curve);
    var demo = { temp: 72, phase: 0, manual: still, angle: 0, visible: false };

    var x = function (t) { return 50 + (t - 40) * (450 / 55); };
    var y = function (r) { return 262 - (r - 1000) * (234 / 5500); };

    var place = function (temp) {
      var rpm = rpmFor(temp);
      var px = x(temp).toFixed(1);
      var py = y(rpm).toFixed(1);
      demo.temp = temp;
      op.setAttribute("cx", px);
      op.setAttribute("cy", py);
      opRing.setAttribute("cx", px);
      opRing.setAttribute("cy", py);
      guideV.setAttribute("x1", px);
      guideV.setAttribute("x2", px);
      guideV.setAttribute("y1", py);
      guideH.setAttribute("x2", px);
      guideH.setAttribute("y1", py);
      guideH.setAttribute("y2", py);
      tempOut.textContent = whole.format(temp);
      rpmOut.textContent = roundRpm(rpm);
      if (slider && !demo.manual) slider.value = String(Math.round(temp));
    };

    if (slider) {
      sliderWrap.hidden = false;
      slider.addEventListener("input", function () {
        demo.manual = true;
        place(+slider.value);
        slider.setAttribute("aria-valuetext", slider.value + " degrees, fans at " + roundRpm(rpmFor(+slider.value)) + " rpm");
      });
    }

    var curveHook = function (ms) {
      if (!demo.visible) return;
      if (!demo.manual) {
        demo.phase += ms / 1000;
        place(66 + 15 * Math.sin(demo.phase * 0.42) + 4 * Math.sin(demo.phase * 1.3));
      }
      if (curveRotor) {
        demo.angle = (demo.angle + ms / 1000 * rpmFor(demo.temp) / 2000 * 360) % 360;
        curveRotor.style.transform = "rotate(" + demo.angle.toFixed(1) + "deg)";
      }
    };
    curveHook.active = false;

    if (!still) {
      frameHooks.push(curveHook);
      watch(curve, function (visible) {
        demo.visible = visible;
        curveHook.active = visible;
        updateRunning();
      });
    }
  }

  /* ---------- privacy check: runs once when it scrolls into view ---------- */

  var scan = $("[data-scan]");
  if (scan && !still && canObserve) {
    var rows = $$(".readouts > div", scan);
    var status = $("[data-scan-status]", scan);
    var finalStatus = status ? status.textContent : "";
    scan.classList.add("is-pending");
    if (status) status.textContent = "Checking";

    var scanWatch = new IntersectionObserver(function (entries) {
      if (!entries[0].isIntersecting) return;
      scanWatch.disconnect();
      scan.classList.add("is-scanning");
      rows.forEach(function (row, i) {
        window.setTimeout(function () { row.classList.add("is-done"); }, 500 + i * 330);
      });
      window.setTimeout(function () {
        scan.classList.remove("is-pending", "is-scanning");
        if (status) status.textContent = finalStatus;
      }, 650 + rows.length * 330);
    }, { threshold: 0.45 });
    scanWatch.observe(scan);
  }

  /* ---------- tour video: play muted while on screen ---------- */

  // Without this script, or with reduced motion, the clip waits on its poster
  // with native controls. Once a visitor pauses it, it stays paused.
  $$("video[data-autoplay]").forEach(function (video) {
    if (still || !canObserve) return;

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
})();
