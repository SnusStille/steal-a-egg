(() => {
  const root = document.documentElement;
  root.classList.remove("no-js");
  root.classList.add("js");

  const header = document.querySelector("[data-header]");
  const progress = document.querySelector(".reading-progress span");
  const menuToggle = document.querySelector("[data-menu-toggle]");
  const nav = document.querySelector("#site-nav");
  const mobileQuery = window.matchMedia("(max-width: 720px)");

  // Keep the navigation usable without JavaScript; enhance it to a compact menu on mobile.
  const syncMenuForViewport = () => {
    if (!nav || !menuToggle) return;
    if (mobileQuery.matches) {
      nav.hidden = menuToggle.getAttribute("aria-expanded") !== "true";
    } else {
      nav.hidden = false;
      menuToggle.setAttribute("aria-expanded", "false");
      menuToggle.setAttribute("aria-label", "Öppna meny");
    }
  };

  syncMenuForViewport();
  mobileQuery.addEventListener?.("change", syncMenuForViewport);

  menuToggle?.addEventListener("click", () => {
    const isOpen = menuToggle.getAttribute("aria-expanded") === "true";
    menuToggle.setAttribute("aria-expanded", String(!isOpen));
    menuToggle.setAttribute("aria-label", isOpen ? "Öppna meny" : "Stäng meny");
    nav.hidden = isOpen;
    if (!isOpen) nav.querySelector("a")?.focus({ preventScroll: true });
  });

  nav?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      if (!mobileQuery.matches || !menuToggle) return;
      menuToggle.setAttribute("aria-expanded", "false");
      menuToggle.setAttribute("aria-label", "Öppna meny");
      nav.hidden = true;
    });
  });

  // Tiny pointer parallax on the hero photograph; disabled for touch and reduced motion.
  const hero = document.querySelector(".hero");
  const heroImage = document.querySelector(".hero-image img");
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (hero && heroImage && window.matchMedia("(pointer: fine)").matches && !prefersReducedMotion) {
    let heroFrame = 0;
    hero.addEventListener("pointermove", (event) => {
      if (event.pointerType !== "mouse") return;
      const bounds = hero.getBoundingClientRect();
      const x = (event.clientX - bounds.left) / bounds.width - 0.5;
      const y = (event.clientY - bounds.top) / bounds.height - 0.5;
      window.cancelAnimationFrame(heroFrame);
      heroFrame = window.requestAnimationFrame(() => {
        heroImage.style.setProperty("--hero-shift-x", `${(-x * 10).toFixed(2)}px`);
        heroImage.style.setProperty("--hero-shift-y", `${(-y * 8).toFixed(2)}px`);
      });
    }, { passive: true });
    hero.addEventListener("pointerleave", () => {
      heroImage.style.setProperty("--hero-shift-x", "0px");
      heroImage.style.setProperty("--hero-shift-y", "0px");
    }, { passive: true });
  }

  // Keep the small desktop navigation marker in sync with the section in view.
  if (nav && "IntersectionObserver" in window) {
    const sectionLinks = Array.from(nav.querySelectorAll("a[href^='#']"));
    const trackedSections = sectionLinks
      .map((link) => document.querySelector(link.getAttribute("href")))
      .filter((section) => section && section.id !== "start");
    const navObserver = new IntersectionObserver((entries) => {
      const current = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!current) return;
      const currentHref = `#${current.target.id}`;
      sectionLinks.forEach((link) => {
        if (link.getAttribute("href") === currentHref) link.setAttribute("aria-current", "location");
        else link.removeAttribute("aria-current");
      });
    }, { rootMargin: "-34% 0px -56% 0px", threshold: [0, 0.2, 0.5] });
    trackedSections.forEach((section) => navObserver.observe(section));
  }

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && menuToggle?.getAttribute("aria-expanded") === "true") {
      menuToggle.setAttribute("aria-expanded", "false");
      menuToggle.setAttribute("aria-label", "Öppna meny");
      nav.hidden = true;
      menuToggle.focus({ preventScroll: true });
    }
  });

  // One passive scroll listener updates the sticky header and thin reading indicator.
  let scrollScheduled = false;
  const updateScrollChrome = () => {
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const scrollable = document.documentElement.scrollHeight - window.innerHeight;
    header?.classList.toggle("is-scrolled", scrollTop > 24);
    const ratio = scrollable > 0 ? Math.min(1, Math.max(0, scrollTop / scrollable)) : 0;
    if (progress) progress.style.transform = `scaleX(${ratio})`;
    scrollScheduled = false;
  };

  window.addEventListener("scroll", () => {
    if (scrollScheduled) return;
    scrollScheduled = true;
    window.requestAnimationFrame(updateScrollChrome);
  }, { passive: true });
  updateScrollChrome();

  // Reveal content only when observed; falls back to visible content on older browsers.
  const revealItems = document.querySelectorAll("[data-reveal]");
  if ("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    root.classList.add("motion-ready");
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -32px 0px" });
    revealItems.forEach((item) => revealObserver.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  }

  // Services are real text controls; the adjacent photograph is explicitly illustrative.
  const serviceButtons = Array.from(document.querySelectorAll("[data-image][data-label]"));
  const serviceImage = document.querySelector("[data-service-image]");
  const serviceIndex = document.querySelector("[data-service-index]");
  const serviceLabel = document.querySelector("[data-service-label]");
  const serviceDetail = document.querySelector("[data-service-detail]");
  let activeImage = serviceImage?.getAttribute("src") || "";
  let imageSequence = 0;

  const showService = (button) => {
    if (!serviceImage || !button) return;
    serviceButtons.forEach((item) => {
      const active = item === button;
      item.classList.toggle("is-active", active);
      item.setAttribute("aria-pressed", String(active));
    });

    if (serviceIndex) serviceIndex.textContent = `${button.dataset.index} / 05`;
    if (serviceLabel) serviceLabel.textContent = button.dataset.label;
    if (serviceDetail) serviceDetail.textContent = button.dataset.detail || "";

    const nextImage = button.dataset.image;
    if (!nextImage || nextImage === activeImage) return;
    const sequence = ++imageSequence;
    const preload = new Image();
    preload.onload = () => {
      if (sequence !== imageSequence) return;
      serviceImage.classList.add("is-changing");
      window.setTimeout(() => {
        if (sequence !== imageSequence) return;
        serviceImage.src = nextImage;
        serviceImage.alt = button.dataset.alt || "Visuell referensbild.";
        activeImage = nextImage;
        requestAnimationFrame(() => serviceImage.classList.remove("is-changing"));
      }, 120);
    };
    preload.onerror = () => {
      if (sequence === imageSequence) serviceImage.classList.remove("is-changing");
    };
    preload.src = nextImage;
  };

  serviceButtons.forEach((button) => {
    button.addEventListener("pointerenter", (event) => {
      if (event.pointerType === "mouse" || event.pointerType === "pen") showService(button);
    });
    button.addEventListener("focus", () => showService(button));
    button.addEventListener("click", () => showService(button));
  });

  // The copyright year remains correct without hardcoding a future footer date.
  const year = document.querySelector("[data-year]");
  if (year) year.textContent = String(new Date().getFullYear());
})();
