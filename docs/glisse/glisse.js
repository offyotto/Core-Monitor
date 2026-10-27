/* Glisse 0.4.3 for pages without React.
   Ports the Glass, Button and TabBar behavior of
   https://github.com/0kzh/glisse to plain DOM. Copyright (c) 2026 Kelvin Zhang,
   MIT License, see LICENSE in this folder.

   Chromium refracts the live backdrop. Other browsers keep the blur and the rim
   highlight, which is what Glisse itself does when no backdrop copy is marked. */

(function () {
  "use strict";

  var doc = document;
  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var clamp = function (value, min, max) { return Math.min(max, Math.max(min, value)); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || doc).querySelectorAll(sel)); };

  /* ---------- springs ---------- */

  var moving = new Set();
  var springFrame = 0;
  var springLast = 0;

  function advance(s, dt) {
    var x = s.value - s.target;
    var v = s.velocity;
    var half = s.damping / 2;
    var discriminant = half * half - s.stiffness;
    var decay, b;

    if (Math.abs(discriminant) < 1e-4) {
      decay = Math.exp(-half * dt);
      b = v + half * x;
      s.value = s.target + decay * (x + b * dt);
      s.velocity = decay * (v - half * b * dt);
    } else if (discriminant > 0) {
      var root = Math.sqrt(discriminant);
      var r1 = -half + root;
      var r2 = -half - root;
      var a = (v - r2 * x) / (r1 - r2);
      b = x - a;
      s.value = s.target + a * Math.exp(r1 * dt) + b * Math.exp(r2 * dt);
      s.velocity = a * r1 * Math.exp(r1 * dt) + b * r2 * Math.exp(r2 * dt);
    } else {
      var omega = Math.sqrt(-discriminant);
      decay = Math.exp(-half * dt);
      var cos = Math.cos(omega * dt);
      var sin = Math.sin(omega * dt);
      s.value = s.target + decay * (x * cos + ((v + half * x) / omega) * sin);
      s.velocity = decay * (v * cos - ((half * v + s.stiffness * x) / omega) * sin);
    }
  }

  function tick(time) {
    springFrame = 0;
    var dt = Math.min(0.1, Math.max(0, (time - springLast) / 1000));
    springLast = time;
    moving.forEach(function (s) {
      advance(s, dt);
      if (Math.abs(s.value - s.target) < 1e-4 && Math.abs(s.velocity) < 1e-3) {
        s.value = s.target;
        s.velocity = 0;
        moving.delete(s);
      }
      s.paint(s.value);
    });
    if (moving.size) springFrame = requestAnimationFrame(tick);
  }

  function createSpring(value, stiffness, damping, paint) {
    var s = { value: value, target: value, velocity: 0, stiffness: stiffness, damping: damping, paint: paint };
    return {
      paint: function () { paint(s.value); },
      set: function (target, instant) {
        s.target = target;
        if (instant || doc.hidden || reducedMotion.matches) {
          s.value = target;
          s.velocity = 0;
          moving.delete(s);
          paint(target);
          return;
        }
        moving.add(s);
        if (!springFrame) {
          // Measure from the start of the current frame, so the next one
          // already shows a frame's worth of motion.
          springLast = Number((doc.timeline && doc.timeline.currentTime) || performance.now());
          springFrame = requestAnimationFrame(tick);
        }
      },
      tune: function (nextStiffness, nextDamping) {
        s.stiffness = nextStiffness;
        s.damping = nextDamping;
      },
      stop: function () { moving.delete(s); }
    };
  }

  /* A touch that rests on a control this long, or has started to drag, belongs
     to the control rather than the page, as with UIScrollView's delay. */
  var HOLD = 150;
  var held = function (at, moved) { return moved || performance.now() - at >= HOLD; };

  /* ---------- refraction (model: https://kube.io/blog/liquid-glass-css-svg/) ---------- */

  var SVG = "http://www.w3.org/2000/svg";
  var lenses = new Map();
  var defs = null;
  var refractsBackdrop = /Chrom(?:e|ium)\//.test(navigator.userAgent);

  function svg(name, attributes) {
    var element = doc.createElementNS(SVG, name);
    Object.keys(attributes).forEach(function (key) { element.setAttribute(key, String(attributes[key])); });
    return element;
  }

  function container() {
    if (defs && defs.isConnected) return defs;
    var root = svg("svg", { width: 0, height: 0, "aria-hidden": "true" });
    root.style.position = "absolute";
    root.style.pointerEvents = "none";
    defs = svg("defs", {});
    root.appendChild(defs);
    doc.body.appendChild(root);
    return defs;
  }

  function profile(bezel, thickness) {
    var samples = new Float32Array(128);
    var maximum = 0;
    for (var i = 0; i < samples.length; i++) {
      var t = Math.max(0.001, i / (samples.length - 1));
      var surface = Math.pow(1 - Math.pow(1 - t, 4), 0.25);
      var incident = Math.atan(Math.pow(1 - t, 3) / Math.pow(surface, 3));
      var refracted = Math.asin(Math.sin(incident) / 1.5);
      samples[i] = Math.tan(incident - refracted) * (thickness + surface * bezel);
      maximum = Math.max(maximum, samples[i]);
    }
    return { samples: samples, maximum: maximum };
  }

  function maps(width, height, radius, selection, shape) {
    var density = Math.min(window.devicePixelRatio || 1, 2);
    var bezel = shape.bezel !== undefined ? shape.bezel : clamp(Math.min(width, height) * 0.12, 4, 10);
    var thickness = shape.thickness !== undefined ? shape.thickness : clamp(Math.min(width, height) * 0.2, 8, 24);
    var prof = profile(bezel, thickness);
    var samples = prof.samples;
    var maximum = prof.maximum;

    var canvas = doc.createElement("canvas");
    canvas.width = Math.ceil(width * density);
    canvas.height = Math.ceil(height * density);
    var context = canvas.getContext("2d");
    var field = context.createImageData(canvas.width, canvas.height);
    var shine = context.createImageData(canvas.width, canvas.height);
    var direction = selection ? 1 : -1;

    for (var y = 0; y < canvas.height; y++) {
      for (var x = 0; x < canvas.width; x++) {
        var px = ((x + 0.5) * width) / canvas.width - width / 2;
        var py = ((y + 0.5) * height) / canvas.height - height / 2;
        var qx = Math.abs(px) - (width / 2 - radius);
        var qy = Math.abs(py) - (height / 2 - radius);
        var ox = Math.max(qx, 0);
        var oy = Math.max(qy, 0);
        var length = Math.hypot(ox, oy);
        var distance = radius - (length + Math.min(Math.max(qx, qy), 0));
        var nx = length > 0 ? (ox / length) * Math.sign(px) : qx > qy ? Math.sign(px) : 0;
        var ny = length > 0 ? (oy / length) * Math.sign(py) : qx > qy ? 0 : Math.sign(py);

        var shift = 0;
        if (distance >= 0 && distance < bezel) {
          var sample = (distance / bezel) * (samples.length - 1);
          var lower = Math.floor(sample);
          var a = samples[lower];
          var b = samples[Math.min(lower + 1, samples.length - 1)];
          shift = a + (b - a) * (sample - lower);
        }

        var i = (y * canvas.width + x) * 4;
        field.data[i] = Math.round(127.5 + ((direction * nx * shift) / maximum) * 127.5);
        field.data[i + 1] = Math.round(127.5 + ((direction * ny * shift) / maximum) * 127.5);
        field.data[i + 2] = 128;
        field.data[i + 3] = 255;

        var light = -(nx + ny) * Math.SQRT1_2;
        var glint = Math.pow(Math.max(light, 0), 3);
        var reflected = Math.pow(Math.max(-light, 0), 3);
        shine.data[i] = shine.data[i + 1] = shine.data[i + 2] = 255;

        var alpha = 0;
        if (distance >= 0 && selection) {
          var bands = [0.18, 0.42, 0.66].map(function (centre) {
            return Math.exp(-Math.pow((distance - centre) / 0.22, 2));
          });
          var peak = Math.max(bands[0], bands[1], bands[2]);
          alpha = peak * (0.06 + 0.8 * glint + 0.35 * reflected) * 0.85;
          for (var channel = 0; channel < 3; channel++) {
            shine.data[i + channel] = Math.round(255 * (0.65 + 0.35 * (peak ? bands[channel] / peak : 0)));
          }
        } else if (distance >= 0) {
          var rim = Math.exp(-Math.pow((distance - 0.4) / 0.38, 2));
          var bloom = Math.exp(-Math.pow(distance / (bezel * 0.22), 2));
          alpha = rim * (0.045 + 0.52 * glint + 0.2 * reflected) + bloom * 0.02 * glint;
        }
        shine.data[i + 3] = Math.round(clamp(alpha, 0, 1) * 255);
      }
    }

    context.putImageData(field, 0, 0);
    var displacement = canvas.toDataURL();
    context.putImageData(shine, 0, 0);
    var highlight = canvas.toDataURL();
    return { displacement: displacement, highlight: highlight, scale: maximum * 2 * shape.level };
  }

  // The filter only bends the rim. Blur and the rim highlight are applied in
  // CSS, which Chromium positions correctly when it repaints part of the glass.
  function lens(width, height, radius, selection, shape) {
    var key = [width, height, radius, selection, shape.bezel, shape.thickness, shape.level].join("-");
    var cached = lenses.get(key);
    if (cached) return cached;

    var made = maps(width, height, radius, selection, shape);
    var id = "glisse-" + lenses.size;
    var box = { x: 0, y: 0, width: width, height: height };
    var withBox = function (extra) {
      var out = {};
      Object.keys(box).forEach(function (k) { out[k] = box[k]; });
      Object.keys(extra).forEach(function (k) { out[k] = extra[k]; });
      return out;
    };
    var filter = svg("filter", withBox({
      id: id,
      filterUnits: "userSpaceOnUse",
      primitiveUnits: "userSpaceOnUse",
      "color-interpolation-filters": "sRGB"
    }));

    filter.appendChild(svg("feImage", withBox({ href: made.displacement, preserveAspectRatio: "none", result: "field" })));

    if (selection) {
      var channels = [
        ["r", 1.035, "1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0"],
        ["g", 1, "0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 1 0"],
        ["b", 0.965, "0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 1 0"]
      ];
      channels.forEach(function (c) {
        filter.appendChild(svg("feDisplacementMap", {
          in: "SourceGraphic",
          in2: "field",
          scale: made.scale * c[1],
          xChannelSelector: "R",
          yChannelSelector: "G",
          result: c[0] + "-ray"
        }));
        filter.appendChild(svg("feColorMatrix", { in: c[0] + "-ray", type: "matrix", values: c[2], result: c[0] }));
      });
      filter.appendChild(svg("feComposite", { in: "r", in2: "g", operator: "arithmetic", k2: 1, k3: 1, result: "rg" }));
      filter.appendChild(svg("feComposite", { in: "rg", in2: "b", operator: "arithmetic", k2: 1, k3: 1 }));
    } else {
      filter.appendChild(svg("feDisplacementMap", {
        in: "SourceGraphic",
        in2: "field",
        scale: made.scale,
        xChannelSelector: "R",
        yChannelSelector: "G",
        result: "bent"
      }));
      // The displacement samples the nearest pixel, which leaves stair-steps
      // where the rim bends hardest; a sub-pixel blur smooths them.
      filter.appendChild(svg("feGaussianBlur", { in: "bent", stdDeviation: 0.4, result: "displaced" }));
      filter.appendChild(svg("feColorMatrix", { in: "displaced", type: "saturate", values: 1.5, result: "face" }));
    }
    container().appendChild(filter);

    var result = { filter: 'url("#' + id + '")', rim: 'url("' + made.highlight + '")' };
    lenses.set(key, result);
    return result;
  }

  function fit(element, selection, filtered) {
    var width = element.offsetWidth;
    var height = element.offsetHeight;
    if (!width || !height) return;
    var style = getComputedStyle(element);
    var corner = style.borderTopLeftRadius;
    var radius = Math.min(
      width / 2,
      height / 2,
      /%$/.test(corner) ? (Math.min(width, height) * parseFloat(corner)) / 100 : parseFloat(corner) || 0
    );
    var length = function (name) {
      var value = parseFloat(style.getPropertyValue(name));
      return isFinite(value) ? value : undefined;
    };
    var level = length("--lg-refraction");
    var shape = {
      bezel: length("--lg-bezel"),
      thickness: length("--lg-thickness"),
      level: level === undefined ? 1 : level
    };
    var made = lens(width, height, radius, selection, shape);
    if (filtered) element.style.setProperty("--lg-filter", made.filter);
    element.style.setProperty("--lg-rim", made.rim);
  }

  function whenIdle(callback) {
    if ("requestIdleCallback" in window) {
      var handle = window.requestIdleCallback(callback, { timeout: 500 });
      return function () { window.cancelIdleCallback(handle); };
    }
    var timer = window.setTimeout(callback, 50);
    return function () { window.clearTimeout(timer); };
  }

  // Refits the lens whenever the element changes size.
  function refraction(element, selection) {
    if (!("ResizeObserver" in window)) return;
    var cancel = null;
    new ResizeObserver(function () {
      if (cancel) cancel();
      cancel = whenIdle(function () { fit(element, !!selection, refractsBackdrop); });
    }).observe(element);
  }

  /* ---------- press: glass buttons swell and follow the finger ---------- */

  // A mouse press stays subtle. A finger gets the iOS 26 glass button: it grows
  // until its longer side is about 15pt bigger, and bounces back on release.
  var POINTER = { grow: 6, press: [417.6, 29.2], release: [230, 23.7] };
  var TOUCH = { grow: 15, press: [515, 27.3], release: [250, 11.8] };

  function press(el) {
    var value = [1, 1, 0, 0];
    var paint = function () {
      el.style.scale = value[0] + " " + value[1];
      el.style.translate = value[2] + "px " + value[3] + "px";
    };
    var springs = value.map(function (initial, i) {
      return createSpring(initial, POINTER.release[0], POINTER.release[1], function (next) {
        value[i] = next;
        paint();
      });
    });
    var pointer = null;

    var target = function (next, tuning) {
      springs.forEach(function (spring, i) {
        spring.tune(tuning[0], tuning[1]);
        spring.set(next[i] || 0);
      });
    };

    var track = function (event) {
      if (!pointer) return;
      var box = pointer.box;
      var feel = pointer.feel;
      el.style.setProperty("--lg-x", ((event.clientX - box.left) / box.width) * 100 + "%");
      el.style.setProperty("--lg-y", ((event.clientY - box.top) / box.height) * 100 + "%");

      var base = 1 + feel.grow / Math.max(box.width, box.height);
      var aspect = box.width / box.height;
      var dx = (event.clientX - pointer.x) / aspect;
      var dy = event.clientY - pointer.y;
      var length = Math.hypot(dx, dy);
      if (!length) return target([base, base, 0, 0], feel.press);

      var nx = dx / length;
      var ny = dy / length;
      var rubber = 1 - 1 / (1 + length / box.height / (5 * aspect));
      var stretch = 1 + (6 / box.height) * rubber * Math.abs(Math.abs(nx) - Math.abs(ny));
      var horizontal = Math.abs(nx) > Math.abs(ny);
      target([
        base * (horizontal ? stretch : 1 / stretch),
        base * (horizontal ? 1 / stretch : stretch),
        nx * 8 * rubber,
        ny * 8 * rubber
      ], feel.press);
    };

    var move = function (event) { if (pointer && event.pointerId === pointer.id) track(event); };

    var end = function (event) {
      if (event && (!pointer || event.pointerId !== pointer.id)) return;
      var feel = pointer ? pointer.feel : POINTER;
      pointer = null;
      delete el.dataset.pressed;
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", end);
      window.removeEventListener("pointercancel", end);
      target([1, 1, 0, 0], feel.release);
    };

    el.addEventListener("pointerdown", function (event) {
      if (!event.isPrimary || event.button !== 0 || pointer || el.matches(":disabled")) return;
      pointer = {
        id: event.pointerId,
        x: event.clientX,
        y: event.clientY,
        box: el.getBoundingClientRect(),
        feel: event.pointerType === "mouse" ? POINTER : TOUCH
      };
      el.dataset.pressed = "";
      window.addEventListener("pointermove", move);
      window.addEventListener("pointerup", end);
      window.addEventListener("pointercancel", end);
      track(event);
    });
    window.addEventListener("blur", function () { end(); });
  }

  /* ---------- tab bar ---------- */

  function part(parent, className) {
    var found = parent.querySelector(":scope > ." + className);
    if (found) return found;
    found = doc.createElement("span");
    found.className = className;
    found.setAttribute("aria-hidden", "true");
    parent.appendChild(found);
    return found;
  }

  var REST = [1024, 58.9, 676, 47.8];
  var DRAG = [2500, 94, 576, 44.2];

  function tabBar(bar) {
    var tabs = $$(".lg-tab", bar);
    if (!tabs.length) return null;
    var glass = part(bar, "lg-tab-bar-glass");
    glass.classList.add("lg-glass");
    if (glass !== bar.firstElementChild) bar.insertBefore(glass, bar.firstChild);
    var tint = part(bar, "lg-tab-tint");
    var row = tint.querySelector(".lg-tab-row");
    if (!row) {
      row = doc.createElement("span");
      row.className = "lg-tab-row";
      tabs.forEach(function (tab) {
        var copy = doc.createElement("span");
        copy.className = "lg-tab-copy";
        copy.textContent = tab.textContent;
        row.appendChild(copy);
      });
      tint.appendChild(row);
    }
    var lens = part(bar, "lg-tab-lens");
    lens.classList.add("lg-glass");

    refraction(glass, false);
    refraction(lens, true);

    var slot = 0;
    var height = 0;
    var growX = 16;
    var growY = 12;
    var active = tabs.findIndex(function (tab) { return tab.hasAttribute("data-selected"); });
    var shown = false;
    var settleFrame = 0;
    var gesture = null;
    var state = { x: 0, lift: 0 };
    var suppressClick = false;

    var mark = function (index) {
      tabs.forEach(function (tab, i) {
        if (i === index) {
          tab.setAttribute("data-selected", "");
          tab.setAttribute("aria-current", tab.getAttribute("data-current") || "page");
        } else {
          tab.removeAttribute("data-selected");
          tab.removeAttribute("aria-current");
        }
      });
      bar.style.setProperty("--lg-index", String(Math.max(index, 0)));
    };

    var measure = function () {
      var style = getComputedStyle(bar);
      slot = (bar.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)) / tabs.length;
      height = lens.offsetHeight;
      growX = parseFloat(style.getPropertyValue("--lg-lens-grow-x")) || 0;
      growY = parseFloat(style.getPropertyValue("--lg-lens-grow-y")) || 0;
    };

    var paint = function () {
      if (!(slot > 0) || !(height > 0)) return;
      var sx = 1 + (growX / slot) * state.lift;
      var sy = 1 + (growY / height) * state.lift;
      lens.style.transform = tint.style.transform = "translateX(" + state.x + "px) scale(" + sx + ", " + sy + ")";
      row.style.transform = "scale(" + 1 / sx + ", " + 1 / sy + ") translate(" + (-state.x + ((sx - 1) * slot) / 2) + "px, " + ((sy - 1) * height) / 2 + "px)";
      if (!gesture && state.lift < 0.01) delete bar.dataset.refracting;
    };

    var x = createSpring(0, REST[0], REST[1], function (value) { state.x = value; paint(); });
    var lift = createSpring(0, REST[2], REST[3], function (value) { state.lift = value; paint(); });

    var move = function (to, lifted, instant) {
      var tuning = gesture ? DRAG : REST;
      x.tune(tuning[0], tuning[1]);
      lift.tune(tuning[2], tuning[3]);
      x.set(to, instant);
      lift.set(lifted ? 1 : 0, instant);
    };

    var settle = function (instant) {
      if (gesture) return;
      var show = active >= 0;
      if (show) delete bar.dataset.hidden;
      else bar.dataset.hidden = "";
      if (show) move(active * slot, false, instant || !shown);
      shown = show;
    };

    var select = function (index) {
      active = index;
      mark(index);
      settle();
      bar.dispatchEvent(new CustomEvent("glisse:select", { bubbles: true, detail: { index: index } }));
    };

    var position = function (event) {
      return clamp(gesture.anchor + event.clientX - gesture.x, 0, slot * (tabs.length - 1));
    };

    var light = function (event, box) {
      glass.style.setProperty("--lg-x", clamp(((event.clientX - box.left) / box.width) * 100, 0, 100) + "%");
      lens.style.setProperty("--lg-x", clamp(((event.clientX - box.left - 4 - state.x) / slot) * 100, 0, 100) + "%");
    };

    var release = function () {
      var old = gesture;
      gesture = null;
      delete bar.dataset.lifted;
      delete lens.dataset.pressed;
      if (old && bar.hasPointerCapture(old.id)) bar.releasePointerCapture(old.id);
      return old;
    };

    bar.addEventListener("pointerdown", function (event) {
      var tab = event.target.closest(".lg-tab");
      if (!event.isPrimary || event.button !== 0 || gesture || !tab) return;
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      cancelAnimationFrame(settleFrame);
      settleFrame = 0;
      measure();
      var box = bar.getBoundingClientRect();
      gesture = { id: event.pointerId, x: event.clientX, anchor: tabs.indexOf(tab) * slot, moved: false, box: box, at: performance.now() };
      suppressClick = false;
      bar.dataset.lifted = "";
      bar.dataset.refracting = "";
      delete bar.dataset.hidden;
      lens.dataset.pressed = "";
      light(event, box);
      move(gesture.anchor, true, !shown);
      shown = true;
    });

    // A mouse isn't captured until it has moved, so follow it past the bar.
    window.addEventListener("pointermove", function (event) {
      if (!gesture || event.pointerId !== gesture.id) return;
      if (!gesture.moved && Math.abs(event.clientX - gesture.x) > 6) {
        gesture.moved = true;
        bar.setPointerCapture(event.pointerId);
      }
      if (gesture.moved) move(position(event), true);
      light(event, gesture.box);
    });

    var onPointerEnd = function (event) {
      if (!gesture || event.pointerId !== gesture.id) return;
      // Touch implicitly captures the tab before a drag captures the bar. The
      // tab's bubbling capture-loss event is a handoff, not the end of the drag.
      if (event.type === "lostpointercapture" && event.target !== bar) return;
      var index = Math.round(position(event) / slot);
      var old = release();
      // A drag selects wherever it leaves the lens, even released off the bar.
      // A tap only counts if it ends on the bar, as with a button.
      var near = event.clientY >= old.box.top - 24 && event.clientY <= old.box.bottom + 24;
      if (event.type === "pointerup" && (old.moved || near)) {
        // Activate at release, before settling. Waiting for the browser's
        // click briefly sends the lens back toward the old selection.
        suppressClick = true;
        settleFrame = requestAnimationFrame(function () {
          settleFrame = 0;
          settle();
        });
        if (tabs[index]) tabs[index].click();
      } else {
        suppressClick = old.moved;
        settle();
      }
    };
    window.addEventListener("pointerup", onPointerEnd);
    window.addEventListener("pointercancel", onPointerEnd);
    bar.addEventListener("lostpointercapture", onPointerEnd);

    // A quick swipe that starts on the bar still scrolls the page, but a press
    // that has rested there, or a drag already under way, keeps the touch.
    bar.addEventListener("touchmove", function (event) {
      if (gesture && event.cancelable && held(gesture.at, gesture.moved)) event.preventDefault();
    }, { passive: false });

    bar.addEventListener("click", function (event) {
      if (event.isTrusted && suppressClick && event.detail !== 0) {
        suppressClick = false;
        event.preventDefault();
        return;
      }
      var tab = event.target.closest(".lg-tab");
      if (!tab || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      select(tabs.indexOf(tab));
    }, true);

    var reset = function () {
      cancelAnimationFrame(settleFrame);
      settleFrame = 0;
      release();
      settle(true);
    };
    doc.addEventListener("visibilitychange", function () { if (doc.hidden) reset(); });
    window.addEventListener("blur", reset);
    if ("ResizeObserver" in window) {
      new ResizeObserver(function () {
        measure();
        if (!gesture) settle(true);
      }).observe(bar);
    }

    mark(active);
    measure();
    bar.dataset.ready = "";
    settle(true);

    return {
      setActive: function (index) {
        if (index === active) return;
        cancelAnimationFrame(settleFrame);
        settleFrame = 0;
        active = index;
        mark(index);
        settle();
      }
    };
  }

  /* ---------- wiring ---------- */

  $$(".lg-tab-bar").forEach(function (bar) { bar.glisse = tabBar(bar); });
  $$(".lg-glass").forEach(function (el) {
    if (!el.closest(".lg-tab-bar")) refraction(el, false);
  });
  $$(".lg-button").forEach(press);
})();
