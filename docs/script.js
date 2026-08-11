/* ==========================================================================
   Core-Monitor site behaviour

   Everything here is a progressive enhancement: the page is fully readable,
   navigable and usable with this file blocked or broken. Nothing here is
   load-bearing, so no content can ever be left hidden by a JavaScript
   failure.

   No third-party libraries. The one network request is a cached lookup of
   the repository's star count, and the page already ships a correct number
   for it.
   ========================================================================== */

(function () {
  "use strict";

  var doc = document;

  var closest = function (node, selector) {
    return node && node.closest ? node.closest(selector) : null;
  };

  /* ---------- sticky header gets a shadow once you leave the top ---------- */

  var header = doc.querySelector(".site-header");
  if (header) {
    var syncHeader = function () {
      header.classList.toggle("is-scrolled", window.scrollY > 8);
    };
    syncHeader();
    window.addEventListener("scroll", syncHeader, { passive: true });
  }

  /* ---------- mobile navigation ---------- */

  var toggle = doc.querySelector(".nav-toggle");
  var nav = doc.getElementById("primary-nav");

  if (toggle && nav) {
    var setNav = function (open) {
      nav.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    };

    var navIsOpen = function () {
      return nav.classList.contains("is-open");
    };

    setNav(false);

    toggle.addEventListener("click", function () {
      setNav(!navIsOpen());
    });

    // Tapping a section link should close the sheet behind you.
    nav.addEventListener("click", function (event) {
      if (closest(event.target, "a")) setNav(false);
    });

    doc.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && navIsOpen()) {
        setNav(false);
        toggle.focus();
      }
    });

    doc.addEventListener("click", function (event) {
      if (!navIsOpen()) return;
      if (nav.contains(event.target) || toggle.contains(event.target)) return;
      setNav(false);
    });
  }

  /* ---------- scroll spy: highlight the section you are reading ---------- */

  var navLinks = Array.prototype.slice.call(
    doc.querySelectorAll('.primary-nav a[href^="#"]')
  );

  if (navLinks.length && "IntersectionObserver" in window) {
    var linkFor = {};
    var sections = [];

    navLinks.forEach(function (link) {
      var id = link.getAttribute("href").slice(1);
      var section = id ? doc.getElementById(id) : null;
      if (!section) return;
      linkFor[id] = link;
      sections.push(section);
    });

    var onScreen = {};

    var paintCurrent = function () {
      var current = null;
      sections.forEach(function (section) {
        if (!current && onScreen[section.id]) current = section.id;
      });

      navLinks.forEach(function (link) {
        if (current && linkFor[current] === link) {
          link.setAttribute("aria-current", "true");
        } else {
          link.removeAttribute("aria-current");
        }
      });
    };

    var spy = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          onScreen[entry.target.id] = entry.isIntersecting;
        });
        paintCurrent();
      },
      { rootMargin: "-30% 0px -60% 0px" }
    );

    sections.forEach(function (section) {
      spy.observe(section);
    });
  }

  /* ---------- copy-to-clipboard buttons ---------- */

  var liveRegion = doc.getElementById("copy-status");

  var announce = function (message) {
    if (liveRegion) liveRegion.textContent = message;
  };

  Array.prototype.slice
    .call(doc.querySelectorAll("[data-copy]"))
    .forEach(function (button) {
      var restingLabel = button.textContent;
      var resetTimer = null;

      var settle = function (ok) {
        button.textContent = ok ? "Copied" : "Copy failed";
        button.setAttribute("data-state", ok ? "done" : "failed");
        announce(
          ok
            ? "Command copied to the clipboard."
            : "Copying failed. Select the command and copy it manually."
        );

        window.clearTimeout(resetTimer);
        resetTimer = window.setTimeout(function () {
          button.textContent = restingLabel;
          button.removeAttribute("data-state");
          announce("");
        }, 2400);
      };

      button.addEventListener("click", function () {
        // data-copy holds a selector pointing at the block to copy, so the
        // command itself lives in exactly one place: the markup people read.
        var raw = button.getAttribute("data-copy") || "";
        var text = raw;

        if (raw.charAt(0) === "#") {
          var source = doc.getElementById(raw.slice(1));
          if (source) text = source.textContent;
        }

        text = text.replace(/\s+$/, "");

        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(
            function () {
              settle(true);
            },
            function () {
              settle(false);
            }
          );
          return;
        }

        settle(false);
      });
    });

  /* ---------- live github star count ----------
     The count is already in the markup, so this only refreshes it. If the
     request fails, GitHub rate limits us, or this file never runs, the
     number that shipped with the page stays and nothing moves. Answers are
     kept for six hours, so a browsing session costs at most one request. */

  (function () {
    var targets = doc.querySelectorAll("[data-star-count]");
    if (!targets.length || !window.fetch) return;

    var ENDPOINT = "https://api.github.com/repos/offyotto/Core-Monitor";
    var KEY = "core-monitor:stars";
    var MAX_AGE = 10 * 60 * 1000;

    var recall = function () {
      try {
        return window.localStorage.getItem(KEY);
      } catch (error) {
        // Private windows and blocked storage both throw here.
        return null;
      }
    };

    var remember = function (value) {
      try {
        window.localStorage.setItem(KEY, value);
      } catch (error) {
        // Caching is an optimisation; carry on without it.
      }
    };

    var abbreviate = function (count) {
      if (count < 1000) return String(count);
      var thousands = count / 1000;
      return (
        (thousands >= 10
          ? Math.round(thousands)
          : Math.round(thousands * 10) / 10) + "k"
      );
    };

    var paint = function (count) {
      if (typeof count !== "number" || !isFinite(count) || count < 0) return;
      Array.prototype.slice.call(targets).forEach(function (target) {
        target.textContent = abbreviate(count);
      });
    };

    var stored = recall();

    if (stored) {
      var halves = stored.split(":");
      var checkedAt = parseInt(halves[0], 10);
      var lastCount = parseInt(halves[1], 10);
      if (isFinite(checkedAt) && isFinite(lastCount)) {
        paint(lastCount);
        if (Date.now() - checkedAt < MAX_AGE) return;
      }
    }

    window
      .fetch(ENDPOINT, { headers: { Accept: "application/vnd.github+json" } })
      .then(function (response) {
        return response.ok ? response.json() : null;
      })
      .then(function (data) {
        if (!data || typeof data.stargazers_count !== "number") return;
        paint(data.stargazers_count);
        remember(Date.now() + ":" + data.stargazers_count);
      })
      .catch(function () {
        // Offline, rate limited or blocked. The shipped number stands.
      });
  })();

  /* ---------- screenshot lightbox ----------
     The gallery tiles are ordinary links to the full-size image, so with
     this disabled they still open the screenshot. When <dialog> is
     available we intercept and show it in place instead. Escape, backdrop
     clicks and focus restoration all come free from the dialog element. */

  var lightbox = doc.getElementById("lightbox");

  if (lightbox && typeof lightbox.showModal === "function") {
    var stage = lightbox.querySelector(".lightbox-img");
    var stageCaption = lightbox.querySelector(".lightbox-caption");

    doc.addEventListener("click", function (event) {
      var trigger = closest(event.target, "[data-lightbox]");
      if (!trigger) return;

      // Let people open the raw image in a new tab if they mean to.
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      if (typeof event.button === "number" && event.button !== 0) return;

      var thumb = trigger.querySelector("img");
      event.preventDefault();

      stage.setAttribute("src", trigger.getAttribute("href"));
      stage.setAttribute("alt", thumb ? thumb.getAttribute("alt") || "" : "");
      if (stageCaption) {
        stageCaption.textContent = trigger.getAttribute("data-lightbox") || "";
      }

      lightbox.showModal();
    });

    lightbox.addEventListener("click", function (event) {
      if (
        event.target === lightbox ||
        closest(event.target, "[data-lightbox-close]")
      ) {
        lightbox.close();
      }
    });

    lightbox.addEventListener("close", function () {
      stage.removeAttribute("src");
    });
  }
})();
