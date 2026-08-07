/* ==========================================================================
   Core-Monitor site behaviour

   Everything here is a progressive enhancement: the page is fully readable,
   navigable and usable with this file blocked or broken. Notably the
   scroll reveal animations are pure CSS now, so no content can ever be left
   stuck at opacity 0 by a JavaScript failure.

   No third-party libraries and no network requests.
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
