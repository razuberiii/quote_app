import { Controller } from "@hotwired/stimulus";

const DESKTOP_NAV_QUERY = "(min-width: 1461px)";

export default class extends Controller {
  static values = {
    unreadCountUrl: String,
    notificationLoadingText: String,
    dirtyConfirmText: String,
  };

  connect() {
    this.trackedForms = new Set();
    this.closeTimers = new WeakMap();
    this.desktopNavMatcher = window.matchMedia(DESKTOP_NAV_QUERY);
    this.hoverCloseDelayMs = 180;

    this.onTurboLoad = this.onTurboLoad.bind(this);
    this.onTurboVisit = this.onTurboVisit.bind(this);
    this.onTurboRender = this.onTurboRender.bind(this);
    this.onTurboBeforeCache = this.onTurboBeforeCache.bind(this);
    this.onOutsideClick = this.onOutsideClick.bind(this);
    this.onEscape = this.onEscape.bind(this);

    this.setupToastApi();
    this.setupDirtyGuards();
    this.setupGlobalOutsideHandlers();
    this.setupNotificationPolling();

    this.onTurboLoad();
    document.addEventListener("turbo:load", this.onTurboLoad);
    document.addEventListener("turbo:visit", this.onTurboVisit);
    document.addEventListener("turbo:render", this.onTurboRender);
    document.addEventListener("turbo:before-cache", this.onTurboBeforeCache);
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.onTurboLoad);
    document.removeEventListener("turbo:visit", this.onTurboVisit);
    document.removeEventListener("turbo:render", this.onTurboRender);
    document.removeEventListener("turbo:before-cache", this.onTurboBeforeCache);
    document.removeEventListener("click", this.onOutsideClick);
    document.removeEventListener("keydown", this.onEscape);
    if (this.pollTimerId) window.clearInterval(this.pollTimerId);
  }

  onTurboLoad() {
    this.refreshTrackedForms();
    this.setupNavGroups();
    this.setupAccountMenu();
    this.setupNotificationBell();
    this.setupLocaleNavDropdown();
    this.setupNavbarToggle();
  }

  onTurboVisit(event) {
    if (this.prefersReducedMotion()) return;
    if (event?.detail?.action === "restore") return;
    document.documentElement.classList.add("is-page-leaving");
  }

  onTurboRender() {
    if (this.prefersReducedMotion()) return;
    document.documentElement.classList.remove("is-page-leaving");
    document.documentElement.classList.add("is-page-entering");

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        document.documentElement.classList.remove("is-page-entering");
      });
    });
  }

  onTurboBeforeCache() {
    document.documentElement.classList.remove("is-page-leaving", "is-page-entering");
  }

  setupToastApi() {
    if (window.showAppToast) return;

    window.showAppToast = (text, type = "info") => {
      const container = document.getElementById("app-toast-container");
      if (!container || !text) return;

      const toast = document.createElement("div");
      toast.className = `app-toast is-${type}`;
      toast.textContent = text;
      container.appendChild(toast);

      window.requestAnimationFrame(() => {
        toast.classList.add("is-visible");
      });

      window.setTimeout(() => {
        toast.classList.remove("is-visible");
        window.setTimeout(() => toast.remove(), 220);
      }, 2400);
    };
  }

  setupDirtyGuards() {
    if (window.__settingsDirtyGuardBound) return;
    window.__settingsDirtyGuardBound = true;

    window.addEventListener("beforeunload", (event) => {
      if (!this.hasDirtyForm()) return;
      event.preventDefault();
      event.returnValue = "";
    });

    document.addEventListener("turbo:before-visit", (event) => {
      if (!this.hasDirtyForm()) return;
      const confirmText =
        this.dirtyConfirmTextValue ||
        "You have unsaved changes. Leave this page?";
      if (window.confirm(confirmText)) return;
      event.preventDefault();
    });
  }

  refreshTrackedForms() {
    document.querySelectorAll("form[data-dirty-guard='true']").forEach((form) => {
      if (this.trackedForms.has(form)) return;
      form.dataset.initialSnapshot = this.formSnapshot(form);
      form.dataset.dirty = "false";
      form.addEventListener("input", () => {
        form.dataset.dirty = String(
          form.dataset.initialSnapshot !== this.formSnapshot(form),
        );
      });
      form.addEventListener("change", () => {
        form.dataset.dirty = String(
          form.dataset.initialSnapshot !== this.formSnapshot(form),
        );
      });
      form.addEventListener("submit", () => {
        form.dataset.skipDirtyGuard = "true";
      });
      this.trackedForms.add(form);
    });
  }

  formSnapshot(form) {
    const data = new FormData(form);
    const entries = [];

    data.forEach((value, key) => {
      if (key === "authenticity_token" || key === "_method") return;
      if (value instanceof File) {
        entries.push([key, value.name || ""]);
        return;
      }
      entries.push([key, String(value)]);
    });

    entries.sort((a, b) => a[0].localeCompare(b[0]));
    return JSON.stringify(entries);
  }

  hasDirtyForm() {
    return Array.from(this.trackedForms).some((form) => {
      if (!document.body.contains(form)) return false;
      if (form.dataset.skipDirtyGuard === "true") return false;
      return form.dataset.dirty === "true";
    });
  }

  setupNavGroups() {
    document.querySelectorAll(".nav-group-details").forEach((details) => {
      if (details.dataset.bound === "true") return;
      details.dataset.bound = "true";
      details.dataset.pinned = "false";

      const summary = details.querySelector(".nav-group-trigger");
      if (summary) {
        summary.addEventListener("click", (event) => {
          event.preventDefault();
          const isOpen = details.hasAttribute("open");
          const isPinned = details.dataset.pinned === "true";

          if (!isOpen) {
            this.closeNavGroups(details);
            details.setAttribute("open", "open");
            details.dataset.pinned = "true";
            return;
          }

          if (isPinned) {
            details.removeAttribute("open");
            details.dataset.pinned = "false";
            return;
          }

          details.dataset.pinned = "true";
        });
      }

      details.addEventListener("mouseenter", () => {
        if (!this.desktopNavMatcher.matches) return;
        this.clearCloseTimer(details);
        if (details.dataset.pinned === "true") return;
        this.closeNavGroups(details);
        details.setAttribute("open", "open");
      });

      details.addEventListener("mouseleave", () => {
        if (!this.desktopNavMatcher.matches) return;
        if (details.dataset.pinned === "true") return;
        this.scheduleClose(details);
      });

      details.querySelectorAll(".nav-group-menu a").forEach((link) => {
        if (link.dataset.bound === "true") return;
        link.dataset.bound = "true";
        link.addEventListener("click", () => {
          this.clearCloseTimer(details);
          details.removeAttribute("open");
          details.dataset.pinned = "false";
        });
      });
    });
  }

  clearCloseTimer(details) {
    const timerId = this.closeTimers.get(details);
    if (!timerId) return;
    window.clearTimeout(timerId);
    this.closeTimers.delete(details);
  }

  scheduleClose(details) {
    this.clearCloseTimer(details);
    const timerId = window.setTimeout(() => {
      if (details.dataset.pinned === "true") return;
      details.removeAttribute("open");
      this.closeTimers.delete(details);
    }, this.hoverCloseDelayMs);
    this.closeTimers.set(details, timerId);
  }

  closeNavGroups(except = null) {
    document.querySelectorAll(".nav-group-details[open]").forEach((details) => {
      if (except && details === except) return;
      this.clearCloseTimer(details);
      details.removeAttribute("open");
      details.dataset.pinned = "false";
    });
  }

  setupAccountMenu() {
    const accountMenu = document.querySelector(".account-menu");
    const accountTrigger = document.querySelector(".account-menu-trigger");
    const accountDropdown = document.getElementById("account-dropdown");
    if (!accountMenu || !accountTrigger || !accountDropdown) return;

    const openAccountMenu = (pinned) => {
      accountMenu.classList.add("is-open");
      accountMenu.dataset.pinned = pinned ? "true" : "false";
      accountDropdown.hidden = false;
      accountTrigger.setAttribute("aria-expanded", "true");
    };

    const closeAccountMenu = () => {
      accountMenu.classList.remove("is-open");
      accountMenu.dataset.pinned = "false";
      accountDropdown.hidden = true;
      accountTrigger.setAttribute("aria-expanded", "false");
    };

    const clearCloseTimer = () => {
      if (!accountMenu.dataset.closeTimer) return;
      window.clearTimeout(Number(accountMenu.dataset.closeTimer));
      accountMenu.dataset.closeTimer = "";
    };

    const scheduleClose = () => {
      clearCloseTimer();
      accountMenu.dataset.closeTimer = String(
        window.setTimeout(() => {
          if (accountMenu.dataset.pinned === "true") return;
          closeAccountMenu();
        }, this.hoverCloseDelayMs),
      );
    };

    if (accountTrigger.dataset.bound !== "true") {
      accountTrigger.dataset.bound = "true";
      accountTrigger.addEventListener("click", () => {
        clearCloseTimer();
        const isOpen = accountMenu.classList.contains("is-open");
        const isPinned = accountMenu.dataset.pinned === "true";

        if (!isOpen) {
          openAccountMenu(true);
          return;
        }

        if (isPinned) {
          closeAccountMenu();
          return;
        }

        openAccountMenu(true);
      });
    }

    if (accountMenu.dataset.hoverBound !== "true") {
      accountMenu.dataset.hoverBound = "true";

      accountMenu.addEventListener("mouseenter", () => {
        if (!this.desktopNavMatcher.matches) return;
        clearCloseTimer();
        if (accountMenu.dataset.pinned === "true") return;
        openAccountMenu(false);
      });

      accountMenu.addEventListener("mouseleave", () => {
        if (!this.desktopNavMatcher.matches) return;
        if (accountMenu.dataset.pinned === "true") return;
        scheduleClose();
      });

      accountDropdown.querySelectorAll("a").forEach((link) => {
        if (link.dataset.bound === "true") return;
        link.dataset.bound = "true";
        link.addEventListener("click", () => {
          clearCloseTimer();
          closeAccountMenu();
        });
      });
    }
  }

  setupNotificationBell() {
    const bellDropdown = document.querySelector(".notification-bell-dropdown");
    if (!bellDropdown || bellDropdown.dataset.bound === "true") return;
    bellDropdown.dataset.bound = "true";

    bellDropdown.querySelectorAll("a").forEach((link) => {
      if (link.dataset.bellBound === "true") return;
      link.dataset.bellBound = "true";
      link.addEventListener("click", () => {
        bellDropdown.removeAttribute("open");
      });
    });

    bellDropdown.addEventListener("toggle", () => {
      if (!bellDropdown.open) return;

      const menu = document.getElementById("notification-bell-menu");
      if (menu && !menu.querySelector(".notification-list")) {
        menu.innerHTML = `<p class="notification-empty">${this.notificationLoadingTextValue || "Loading notifications..."}</p>`;
      }

      if (typeof window.refreshNotificationBell === "function") {
        window.refreshNotificationBell();
      }
    });
  }

  setupLocaleNavDropdown() {
    document.querySelectorAll(".locale-nav-dropdown").forEach((dropdown) => {
      if (dropdown.dataset.bound === "true") return;
      dropdown.dataset.bound = "true";

      dropdown.querySelectorAll(".locale-nav-link").forEach((link) => {
        if (link.dataset.localeBound === "true") return;
        link.dataset.localeBound = "true";
        link.addEventListener("click", () => {
          dropdown.removeAttribute("open");
        });
      });
    });
  }

  setupNavbarToggle() {
    const container = document.querySelector(".navbar-container");
    const toggle = document.querySelector(".navbar-toggle");
    if (!container || !toggle || toggle.dataset.bound === "true") return;

    toggle.dataset.bound = "true";
    toggle.addEventListener("click", () => {
      const isOpen = container.classList.toggle("menu-open");
      toggle.setAttribute("aria-expanded", String(isOpen));
    });
  }

  setupGlobalOutsideHandlers() {
    document.removeEventListener("click", this.onOutsideClick);
    document.removeEventListener("keydown", this.onEscape);
    document.addEventListener("click", this.onOutsideClick);
    document.addEventListener("keydown", this.onEscape);
  }

  onOutsideClick(event) {
    if (!event.target.closest(".nav-group")) {
      this.closeNavGroups();
    }

    if (!event.target.closest(".account-menu")) {
      const menu = document.querySelector(".account-menu");
      const dropdown = document.getElementById("account-dropdown");
      if (menu && dropdown && !dropdown.hidden) {
        if (menu.dataset.closeTimer) {
          window.clearTimeout(Number(menu.dataset.closeTimer));
          menu.dataset.closeTimer = "";
        }
        menu.classList.remove("is-open");
        menu.dataset.pinned = "false";
        dropdown.hidden = true;
        menu
          .querySelector("[aria-controls='account-dropdown']")
          ?.setAttribute("aria-expanded", "false");
      }
    }

    if (!event.target.closest(".notification-bell-container")) {
      document
        .querySelectorAll(".notification-bell-dropdown[open]")
        .forEach((menu) => menu.removeAttribute("open"));
    }

    if (!event.target.closest(".locale-nav")) {
      document
        .querySelectorAll(".locale-nav-dropdown[open]")
        .forEach((menu) => menu.removeAttribute("open"));
    }
  }

  onEscape(event) {
    if (event.key !== "Escape") return;

    this.closeNavGroups();

    const menu = document.querySelector(".account-menu");
    const dropdown = document.getElementById("account-dropdown");
    if (menu && dropdown && !dropdown.hidden) {
      if (menu.dataset.closeTimer) {
        window.clearTimeout(Number(menu.dataset.closeTimer));
        menu.dataset.closeTimer = "";
      }
      menu.classList.remove("is-open");
      menu.dataset.pinned = "false";
      dropdown.hidden = true;
      menu
        .querySelector("[aria-controls='account-dropdown']")
        ?.setAttribute("aria-expanded", "false");
    }

    document
      .querySelectorAll(".notification-bell-dropdown[open], .locale-nav-dropdown[open]")
      .forEach((openMenu) => openMenu.removeAttribute("open"));
  }

  setupNotificationPolling() {
    if (!this.hasUnreadCountUrlValue || !this.unreadCountUrlValue) return;

    const updateBadge = (count) => {
      const badge = document.getElementById("notification-badge-count");
      if (!badge) return;
      badge.textContent = count > 9 ? "9+" : String(count);
      badge.hidden = count === 0;
    };

    const updateBellMenu = (menuHtml) => {
      if (typeof menuHtml !== "string") return;
      const menu = document.getElementById("notification-bell-menu");
      if (!menu) return;
      menu.innerHTML = menuHtml;
    };

    const pollUnreadCount = async () => {
      try {
        const resp = await fetch(this.unreadCountUrlValue, {
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
          },
          credentials: "same-origin",
        });
        if (!resp.ok) return;
        const { count, menu_html: menuHtml } = await resp.json();
        updateBadge(count);
        updateBellMenu(menuHtml);
      } catch (_) {
        // no-op
      }
    };

    window.refreshNotificationBell = pollUnreadCount;
    if (this.pollTimerId) window.clearInterval(this.pollTimerId);
    this.pollTimerId = window.setInterval(window.refreshNotificationBell, 30000);
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }
}
