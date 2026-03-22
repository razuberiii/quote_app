import { Controller } from "@hotwired/stimulus";

const DEFAULT_EASE = "cubic-bezier(0.16, 1, 0.3, 1)";
const DEFAULT_FAST_MS = 120;
const DEFAULT_BASE_MS = 200;
const DEFAULT_SLOW_MS = 320;

export default class extends Controller {
  static values = {
    showLessLabel: String,
    showMoreTemplate: String,
  };

  connect() {
    this.animating = new WeakSet();
    this.motion = this.resolveMotion();
    this.bindToggles();
  }

  bindToggles() {
    this.element
      .querySelectorAll("[data-action-toggle], [data-action-items-toggle]")
      .forEach((toggle) => {
        if (toggle.dataset.bound === "true") return;

        const expandId = toggle.dataset.expandId;
        if (!expandId) return;

        const content = this.element.querySelector(`[data-expand-id='${expandId}']`);
        if (!content) return;

        toggle.dataset.bound = "true";
        toggle.dataset.originalLabel = toggle.textContent.trim();

        content.hidden = false;
        content.classList.add("is-collapsible");
        this.applyCollapsedState(content);
        this.updateToggleLabel(toggle, false);

        toggle.addEventListener("click", () => {
          if (this.animating.has(content)) return;
          const expanded = toggle.dataset.expanded === "true";
          this.setExpanded(toggle, content, !expanded);
        });
      });
  }

  setExpanded(toggle, content, expanded) {
    toggle.dataset.expanded = expanded ? "true" : "false";
    content.setAttribute("aria-hidden", expanded ? "false" : "true");
    this.updateToggleLabel(toggle, expanded);

    if (this.prefersReducedMotion()) {
      if (expanded) this.applyExpandedState(content);
      else this.applyCollapsedState(content);
      return;
    }

    if (expanded) this.animateExpand(content);
    else this.animateCollapse(content);
  }

  updateToggleLabel(toggle, expanded) {
    const count = Number(toggle.dataset.actionCount || 0);
    if (expanded) {
      toggle.textContent = this.showLessLabelValue || "Show less";
      return;
    }

    const template =
      this.showMoreTemplateValue ||
      toggle.dataset.originalLabel ||
      "Show more (%{count})";
    toggle.textContent = template.replace("%{count}", String(count));
  }

  animateExpand(content) {
    this.animating.add(content);
    const { expandMs, fadeMs, ease } = this.motion;
    content.classList.add("is-expanded");
    content.style.overflow = "hidden";
    content.style.transition = "none";
    content.style.height = "0px";
    content.style.opacity = "0";
    content.style.transform = "translateY(-6px)";

    const targetHeight = content.scrollHeight;

    window.requestAnimationFrame(() => {
      content.style.transition = [
        `height ${expandMs}ms ${ease}`,
        `opacity ${fadeMs}ms ${ease}`,
        `transform ${fadeMs}ms ${ease}`,
      ].join(", ");
      content.style.height = `${targetHeight}px`;
      content.style.opacity = "1";
      content.style.transform = "translateY(0)";
    });

    this.bindTransitionCleanup(content, true);
  }

  animateCollapse(content) {
    this.animating.add(content);
    const { expandMs, fadeMs, ease } = this.motion;
    const startHeight = content.scrollHeight;

    content.style.overflow = "hidden";
    content.style.transition = "none";
    content.style.height = `${startHeight}px`;
    content.style.opacity = "1";
    content.style.transform = "translateY(0)";

    window.requestAnimationFrame(() => {
      content.style.transition = [
        `height ${Math.max(expandMs - 30, 220)}ms ${ease}`,
        `opacity ${Math.max(fadeMs - 20, 180)}ms ${ease}`,
        `transform ${Math.max(fadeMs - 20, 180)}ms ${ease}`,
      ].join(", ");
      content.style.height = "0px";
      content.style.opacity = "0";
      content.style.transform = "translateY(-6px)";
    });

    this.bindTransitionCleanup(content, false);
  }

  bindTransitionCleanup(content, expandedAfterFinish) {
    const cleanup = (event) => {
      if (event.propertyName !== "height") return;
      content.removeEventListener("transitionend", cleanup);
      content.style.transition = "";

      if (expandedAfterFinish) {
        content.style.height = "auto";
        content.style.overflow = "visible";
      } else {
        content.classList.remove("is-expanded");
        content.style.height = "0px";
        content.style.overflow = "hidden";
      }
      this.animating.delete(content);
    };

    content.addEventListener("transitionend", cleanup);
  }

  applyCollapsedState(content) {
    content.classList.remove("is-expanded");
    content.style.transition = "none";
    content.style.height = "0px";
    content.style.opacity = "0";
    content.style.transform = "translateY(-6px)";
    content.style.overflow = "hidden";
  }

  applyExpandedState(content) {
    content.classList.add("is-expanded");
    content.style.transition = "none";
    content.style.height = "auto";
    content.style.opacity = "1";
    content.style.transform = "translateY(0)";
    content.style.overflow = "visible";
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  resolveMotion() {
    const root = getComputedStyle(document.documentElement);
    const fastMs = this.readMs(root.getPropertyValue("--motion-duration-fast"), DEFAULT_FAST_MS);
    const baseMs = this.readMs(root.getPropertyValue("--motion-duration-base"), DEFAULT_BASE_MS);
    const slowMs = this.readMs(root.getPropertyValue("--motion-duration-slow"), DEFAULT_SLOW_MS);
    const ease =
      this.readToken(root.getPropertyValue("--motion-ease-emphasized")) ||
      this.readToken(root.getPropertyValue("--motion-ease-standard")) ||
      DEFAULT_EASE;

    return {
      expandMs: Math.max(slowMs + fastMs, 300),
      fadeMs: Math.max(slowMs, baseMs),
      ease,
    };
  }

  readToken(value) {
    return String(value || "").trim();
  }

  readMs(value, fallback) {
    const token = this.readToken(value);
    if (!token) return fallback;
    if (token.endsWith("ms")) {
      const parsed = Number(token.slice(0, -2));
      return Number.isFinite(parsed) ? parsed : fallback;
    }
    if (token.endsWith("s")) {
      const parsed = Number(token.slice(0, -1));
      return Number.isFinite(parsed) ? parsed * 1000 : fallback;
    }
    const parsed = Number(token);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
}
