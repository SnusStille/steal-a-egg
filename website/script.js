(() => {
  const root = document.documentElement;
  root.classList.remove("no-js");
  root.classList.add("js");

  const header = document.querySelector("[data-header]");
  const progress = document.querySelector(".reading-progress span");
  const menuToggle = document.querySelector("[data-menu-toggle]");
  const nav = document.querySelector("#site-nav");
  const mobileNavQuery = window.matchMedia("(max-width: 960px)");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Compact menu: keep the links in the document and return focus when it closes.
  const closeMenu = ({ returnFocus = false } = {}) => {
    if (!menuToggle || !nav) return;
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "Öppna meny");
    nav.hidden = mobileNavQuery.matches;
    if (returnFocus) menuToggle.focus({ preventScroll: true });
  };

  const syncMenu = () => {
    if (!menuToggle || !nav) return;
    if (mobileNavQuery.matches) {
      const isOpen = menuToggle.getAttribute("aria-expanded") === "true";
      nav.hidden = !isOpen;
    } else {
      nav.hidden = false;
      menuToggle.setAttribute("aria-expanded", "false");
      menuToggle.setAttribute("aria-label", "Öppna meny");
    }
  };

  syncMenu();
  mobileNavQuery.addEventListener?.("change", syncMenu);

  menuToggle?.addEventListener("click", () => {
    const opening = menuToggle.getAttribute("aria-expanded") !== "true";
    menuToggle.setAttribute("aria-expanded", String(opening));
    menuToggle.setAttribute("aria-label", opening ? "Stäng meny" : "Öppna meny");
    nav.hidden = !opening;
    if (opening) nav.querySelector("a")?.focus({ preventScroll: true });
  });

  nav?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      if (mobileNavQuery.matches) closeMenu({ returnFocus: true });
    });
  });

  document.addEventListener("click", (event) => {
    if (!mobileNavQuery.matches || menuToggle?.getAttribute("aria-expanded") !== "true") return;
    if (nav?.contains(event.target) || menuToggle?.contains(event.target)) return;
    closeMenu();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && menuToggle?.getAttribute("aria-expanded") === "true") {
      closeMenu({ returnFocus: true });
    }
  });

  // Header state and slim reading progress share one passive scroll listener.
  let scrollScheduled = false;
  const updateScrollState = () => {
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
    header?.classList.toggle("is-scrolled", scrollTop > 24);
    if (progress) {
      const fraction = maxScroll > 0 ? Math.min(1, Math.max(0, scrollTop / maxScroll)) : 0;
      progress.style.transform = `scaleX(${fraction})`;
    }
    scrollScheduled = false;
  };

  window.addEventListener("scroll", () => {
    if (scrollScheduled) return;
    scrollScheduled = true;
    window.requestAnimationFrame(updateScrollState);
  }, { passive: true });
  updateScrollState();

  // Current-section indicator for the compact navigation.
  if (nav && "IntersectionObserver" in window) {
    const navLinks = Array.from(nav.querySelectorAll("a[href^='#']"));
    const sections = navLinks
      .map((link) => document.querySelector(link.getAttribute("href")))
      .filter((section) => section && section.id && section.id !== "start");
    const observer = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (!visible) return;
      const current = `#${visible.target.id}`;
      navLinks.forEach((link) => {
        if (link.getAttribute("href") === current) link.setAttribute("aria-current", "location");
        else link.removeAttribute("aria-current");
      });
    }, { rootMargin: "-32% 0px -58% 0px", threshold: [0, 0.15, 0.4] });
    sections.forEach((section) => observer.observe(section));
  }

  // Very restrained pointer movement; disabled for touch and reduced-motion preferences.
  const hero = document.querySelector(".hero");
  const heroImage = document.querySelector("[data-hero-image]");
  if (hero && heroImage && window.matchMedia("(pointer: fine)").matches && !reducedMotion) {
    let frame = 0;
    hero.addEventListener("pointermove", (event) => {
      if (event.pointerType !== "mouse") return;
      const bounds = hero.getBoundingClientRect();
      const x = event.clientX / bounds.width - .5;
      const y = (event.clientY - bounds.top) / bounds.height - .5;
      window.cancelAnimationFrame(frame);
      frame = window.requestAnimationFrame(() => {
        heroImage.style.setProperty("--shift-x", `${(-x * 7).toFixed(1)}px`);
        heroImage.style.setProperty("--shift-y", `${(-y * 5).toFixed(1)}px`);
      });
    }, { passive: true });
    hero.addEventListener("pointerleave", () => {
      heroImage.style.setProperty("--shift-x", "0px");
      heroImage.style.setProperty("--shift-y", "0px");
    }, { passive: true });
  }

  // Scroll reveals are enhancements only: if observation is unavailable, show everything.
  const revealItems = document.querySelectorAll("[data-reveal]");
  if ("IntersectionObserver" in window && !reducedMotion) {
    root.classList.add("motion-ready");
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: .12, rootMargin: "0px 0px -30px 0px" });
    revealItems.forEach((item) => revealObserver.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  }

  // Service cards preselect the matching project type in the contact form.
  const serviceSelect = document.querySelector("select[name='service']");
  document.querySelectorAll("[data-service-link]").forEach((link) => {
    link.addEventListener("click", () => {
      const service = link.dataset.serviceLink;
      if (!serviceSelect || !service) return;
      const option = Array.from(serviceSelect.options).find((item) => item.textContent.trim() === service);
      if (option) serviceSelect.value = option.value || option.textContent;
      else if (service === "Snickeri & ytskikt") serviceSelect.value = "Snickeri";
    });
  });

  // Quote form is deliberately transparent: this static site prepares an SMS draft locally.
  const form = document.querySelector("#quote-form");
  const formFields = form?.querySelector("[data-form-fields]");
  if (formFields) formFields.disabled = false;
  const fileInput = form?.querySelector("[data-file-input]");
  const fileList = form?.querySelector("[data-file-list]");
  const fileReminder = form?.querySelector("[data-file-reminder]");
  const result = form?.querySelector("[data-form-result]");
  const smsLink = form?.querySelector("[data-sms-link]");
  const copyButton = form?.querySelector("[data-copy-inquiry]");
  const messageField = form?.elements.namedItem("message");
  const characterCount = form?.querySelector("[data-character-count]");
  const maxFileBytes = 10 * 1024 * 1024;
  let inquiryText = "";
  let filesAreValid = true;

  const updateCharacterCount = () => {
    if (characterCount && messageField) characterCount.textContent = String(messageField.value.length);
  };
  messageField?.addEventListener("input", updateCharacterCount);
  updateCharacterCount();

  const describeFiles = () => {
    if (!fileInput || !fileList) return;
    const files = Array.from(fileInput.files || []);
    const invalidCount = files.length > 4;
    const invalidSize = files.some((file) => file.size > maxFileBytes);
    const invalidType = files.some((file) => {
      if (file.type.startsWith("image/") || file.type === "application/pdf") return false;
      return !/\.(?:jpe?g|png|webp|gif|heic|heif|pdf)$/i.test(file.name);
    });
    filesAreValid = !invalidCount && !invalidSize && !invalidType;
    fileInput.setCustomValidity(filesAreValid ? "" : "Välj högst fyra bilder eller PDF-filer på maximalt 10 MB per fil.");
    fileInput.setAttribute("aria-invalid", String(!filesAreValid));
    fileList.classList.toggle("is-invalid", !filesAreValid);

    if (!files.length) {
      fileList.textContent = "Inga filer valda";
    } else if (!filesAreValid) {
      const reason = invalidCount ? "Välj högst fyra filer." : invalidSize ? "Varje fil får vara högst 10 MB." : "Välj bilder eller PDF-filer.";
      fileList.textContent = reason;
    } else {
      fileList.textContent = files.map((file) => file.name).join(" · ");
    }
  };
  fileInput?.addEventListener("change", describeFiles);
  describeFiles();

  const addLine = (label, value) => value ? `${label}: ${value}` : "";
  const buildInquiry = () => {
    const data = new FormData(form);
    const lines = [
      "Offertförfrågan – MV Riv & Bygg",
      addLine("Namn", String(data.get("name") || "").trim()),
      addLine("Telefon", String(data.get("phone") || "").trim()),
      addLine("E-post", String(data.get("email") || "").trim()),
      addLine("Ort", String(data.get("location") || "").trim()),
      addLine("Typ av arbete", String(data.get("service") || "").trim()),
      addLine("Omfattning", String(data.get("scope") || "").trim()),
      addLine("Önskad start", String(data.get("start") || "").trim()),
      addLine("Beskrivning", String(data.get("message") || "").trim())
    ].filter(Boolean);
    return lines.join("\n");
  };

  form?.addEventListener("submit", (event) => {
    event.preventDefault();
    if (!form.reportValidity() || !filesAreValid) return;

    inquiryText = buildInquiry();
    if (smsLink) smsLink.href = `sms:+46702811003?body=${encodeURIComponent(inquiryText)}`;

    const files = Array.from(fileInput?.files || []);
    if (fileReminder) {
      fileReminder.textContent = files.length
        ? `Kom ihåg att bifoga ${files.length === 1 ? "filen" : `de ${files.length} filerna`} i meddelandeappen innan du skickar.`
        : "";
    }

    if (result) {
      result.hidden = false;
      result.scrollIntoView({ behavior: reducedMotion ? "auto" : "smooth", block: "nearest" });
    }
    copyButton?.focus({ preventScroll: true });
  });

  copyButton?.addEventListener("click", async () => {
    if (!inquiryText) return;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(inquiryText);
      } else {
        const temporary = document.createElement("textarea");
        temporary.value = inquiryText;
        temporary.setAttribute("readonly", "");
        temporary.style.position = "fixed";
        temporary.style.opacity = "0";
        document.body.append(temporary);
        temporary.select();
        document.execCommand("copy");
        temporary.remove();
      }
      copyButton.textContent = "Kopierad ✓";
    } catch {
      copyButton.textContent = "Kopiera manuellt";
    }
  });

  const year = document.querySelector("[data-year]");
  if (year) year.textContent = String(new Date().getFullYear());
})();
