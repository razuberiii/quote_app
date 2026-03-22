import { Controller } from "@hotwired/stimulus";

const COUNT_MS = 820;
const EASE_OUT = (t) => 1 - (1 - t) ** 3;

export default class extends Controller {
  static targets = ["count"];

  connect() {
    this.prefersReducedMotion = window
      .matchMedia("(prefers-reduced-motion: reduce)")
      .matches;

    if (this.prefersReducedMotion) {
      this.animateAllCounts(true);
      return;
    }

    this.animateAllCounts(false);
  }

  disconnect() {
    if (this.frameId) window.cancelAnimationFrame(this.frameId);
  }

  animateAllCounts(immediate) {
    this.countTargets.forEach((node) => {
      const raw = node.dataset.countFinal || node.textContent || "0";
      const value = Number(String(raw).replace(/[^\d.-]/g, ""));
      if (!Number.isFinite(value)) return;

      if (immediate || node.dataset.countAnimated === "true") {
        node.textContent = this.formatCount(value);
        return;
      }

      node.dataset.countAnimated = "true";
      this.animateCountNode(node, value);
    });
  }

  animateCountNode(node, finalValue) {
    const start = performance.now();

    const step = (now) => {
      const progress = Math.min(1, (now - start) / COUNT_MS);
      const eased = EASE_OUT(progress);
      const current = Math.round(finalValue * eased);
      node.textContent = this.formatCount(current);

      if (progress < 1) {
        this.frameId = window.requestAnimationFrame(step);
      } else {
        node.textContent = this.formatCount(finalValue);
      }
    };

    this.frameId = window.requestAnimationFrame(step);
  }

  formatCount(value) {
    return new Intl.NumberFormat().format(value);
  }
}
