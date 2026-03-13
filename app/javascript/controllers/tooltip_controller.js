import { Controller } from "@hotwired/stimulus";

// Lightweight tooltip shown on hover.
// Usage:
//   data-controller="tooltip"
//   data-tooltip-content-value="Shortcut: C"
//   data-action="mouseenter->tooltip#show mouseleave->tooltip#hide"
export default class extends Controller {
  static values = { content: String };

  show() {
    if (!this.contentValue || this._tip) return;

    const tip = document.createElement("div");
    tip.className = "app-tooltip";
    tip.textContent = this.contentValue;
    document.body.appendChild(tip);
    this._tip = tip;

    const rect = this.element.getBoundingClientRect();
    const tipRect = tip.getBoundingClientRect();
    const top = rect.top + window.scrollY - tipRect.height - 8;
    const left = rect.left + rect.width / 2 - tipRect.width / 2;
    tip.style.left = `${Math.max(8, left)}px`;
    tip.style.top = `${Math.max(8, top)}px`;
  }

  hide() {
    this._tip?.remove();
    this._tip = null;
  }

  disconnect() {
    this.hide();
  }
}
