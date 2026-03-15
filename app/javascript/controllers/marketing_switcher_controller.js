import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];
  static values = {
    selected: String,
  };

  connect() {
    const initialKey =
      this.selectedValue ||
      this.tabTargets.find((tab) => tab.dataset.active === "true")?.dataset
        .stateKey ||
      this.tabTargets[0]?.dataset.stateKey;

    if (initialKey) this.show(initialKey);
  }

  select(event) {
    const tab = event.currentTarget;
    const key = tab?.dataset.stateKey;
    if (!key) return;

    this.show(key);
    tab.focus({ preventScroll: true });
  }

  keydown(event) {
    const currentIndex = this.tabTargets.indexOf(event.currentTarget);
    if (currentIndex < 0) return;

    let nextIndex = null;

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        nextIndex = (currentIndex + 1) % this.tabTargets.length;
        break;
      case "ArrowLeft":
      case "ArrowUp":
        nextIndex =
          (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length;
        break;
      case "Home":
        nextIndex = 0;
        break;
      case "End":
        nextIndex = this.tabTargets.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    const nextTab = this.tabTargets[nextIndex];
    if (!nextTab) return;

    this.show(nextTab.dataset.stateKey);
    nextTab.focus({ preventScroll: true });
  }

  show(key) {
    this.selectedValue = key;

    this.tabTargets.forEach((tab, index) => {
      const isActive = tab.dataset.stateKey === key;
      tab.classList.toggle("is-active", isActive);
      tab.classList.toggle("is-inactive", !isActive);
      tab.setAttribute("aria-selected", String(isActive));
      tab.tabIndex = isActive ? 0 : -1;
      tab.dataset.active = isActive ? "true" : "false";
      if (isActive) {
        tab.setAttribute("data-active-index", String(index));
      } else {
        tab.removeAttribute("data-active-index");
      }
    });

    this.panelTargets.forEach((panel) => {
      const isActive = panel.dataset.stateKey === key;
      panel.hidden = !isActive;
      panel.classList.toggle("is-active", isActive);
      panel.setAttribute("aria-hidden", String(!isActive));
    });
  }
}
