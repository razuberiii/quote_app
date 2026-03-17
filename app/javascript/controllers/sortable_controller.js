import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";

export default class extends Controller {
  static values = {
    url: String,
    enabled: Boolean,
    draggableSelector: String,
    filter: String,
  };

  connect() {
    if (!this.enabledValue) return;

    this.sortable = Sortable.create(this.element, {
      animation: 90,
      draggable: this.draggableSelectorValue || ".customer-tag-chip",
      ghostClass: "is-dragging",
      chosenClass: "is-dragging",
      fallbackTolerance: 3,
      filter: this.filterValue || "input, [data-tag-delete]",
      preventOnFilter: false,
      onEnd: () => this.persistOrder(),
    });
  }

  disconnect() {
    this.sortable?.destroy();
  }

  async persistOrder() {
    if (!this.hasUrlValue || !this.urlValue) {
      this.dispatchReordered();
      return;
    }

    const ids = Array.from(
      this.element.querySelectorAll(".customer-tag-chip.is-selected[data-id]"),
    )
      .map((chip) => Number.parseInt(chip.dataset.id || "", 10))
      .filter((id) => Number.isInteger(id) && id > 0);

    if (!ids.length) return;

    const csrf =
      document.querySelector("meta[name='csrf-token']")?.content || "";

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrf,
      },
      credentials: "same-origin",
      body: JSON.stringify({ ids }),
    });

    if (!response.ok) {
      window.showAppToast?.("Tag order save failed", "error");
      return;
    }

    this.dispatchReordered(ids);
  }

  dispatchReordered(ids = []) {
    this.element.dispatchEvent(
      new CustomEvent("sortable:reordered", {
        bubbles: true,
        detail: { ids },
      }),
    );
  }
}
