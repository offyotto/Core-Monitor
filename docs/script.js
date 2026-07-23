// Core-Monitor site behaviour: mobile nav, scroll reveal, clipboard copy,
// and a slowed-down smooth scroll powered by Lenis.
(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function setupNav() {
    var toggle = document.querySelector("[data-nav-toggle]");
    var nav = document.querySelector("[data-nav]");
    if (!toggle || !nav) return;

    toggle.addEventListener("click", function () {
      var open = !nav.classList.contains("is-open");
      nav.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });

    nav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  function setupReveal() {
    var items = document.querySelectorAll("[data-reveal]");
    if (!items.length) return;

    if (reduceMotion || typeof IntersectionObserver === "undefined") {
      items.forEach(function (el) { el.classList.add("is-visible"); });
      return;
    }

    var watcher = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          watcher.unobserve(entry.target);
        });
      },
      { threshold: 0.2, rootMargin: "0px 0px -40px 0px" }
    );

    items.forEach(function (el, index) {
      el.style.transitionDelay = Math.min(index % 6, 5) * 70 + "ms";
      watcher.observe(el);
    });
  }

  function setupCopyButtons() {
    document.querySelectorAll("[data-copy]").forEach(function (button) {
      var target = document.querySelector(button.getAttribute("data-copy"));
      if (!target) return;
      var restLabel = button.textContent;

      button.addEventListener("click", function () {
        var text = target.textContent.replace(/\s+\n/g, "\n").trim();

        function announce(label) {
          button.textContent = label;
          window.setTimeout(function () {
            button.textContent = restLabel;
          }, 1700);
        }

        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(
            function () { announce("Copied"); },
            function () { announce("Copy failed"); }
          );
          return;
        }

        var area = document.createElement("textarea");
        area.value = text;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.opacity = "0";
        document.body.appendChild(area);
        area.select();
        try {
          document.execCommand("copy");
          announce("Copied");
        } catch (err) {
          announce("Copy failed");
        }
        document.body.removeChild(area);
      });
    });
  }

  function setupSmoothScroll() {
    if (reduceMotion) return;
    if (typeof window.Lenis !== "function") return;
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;

    var lenis = new window.Lenis({
      duration: 1.05,
      easing: function (t) {
        return Math.min(1, 1.001 - Math.pow(2, -10 * t));
      },
      autoRaf: true
    });

    document.querySelectorAll('a[href^="#"]').forEach(function (link) {
      link.addEventListener("click", function (event) {
        var id = link.getAttribute("href").slice(1);
        if (!id) return;
        var dest = document.getElementById(id);
        if (!dest) return;
        event.preventDefault();
        lenis.scrollTo(dest);
      });
    });
  }

  setupNav();
  setupReveal();
  setupCopyButtons();
  setupSmoothScroll();
})();
