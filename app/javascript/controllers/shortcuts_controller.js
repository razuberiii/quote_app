import { Controller } from "@hotwired/stimulus";

// Handles global keyboard shortcuts.
// Attach to <body> with URL values for signed-in users only.
export default class extends Controller {
  static values = {
    newCustomerUrl: String,
    newProductUrl: String,
    customerPickerUrl: String,
    commandPaletteUrl: String,
  };

  connect() {
    this.paletteItems = [];
    this.paletteActiveIndex = -1;
    this._handler = this._onKey.bind(this);
    document.addEventListener("keydown", this._handler);
  }

  disconnect() {
    window.clearTimeout(this._searchTimer);
    window.clearTimeout(this._paletteSearchTimer);
    document.removeEventListener("keydown", this._handler);
  }

  openHelp() {
    this.closeCommandPalette();
    this.closeQuotePicker();
    const modal = document.getElementById("shortcuts-modal");
    if (!modal) return;
    modal.removeAttribute("hidden");
    modal.querySelector(".js-shortcuts-close")?.focus();
  }

  closeHelp() {
    document.getElementById("shortcuts-modal")?.setAttribute("hidden", "");
  }

  openCommandPalette() {
    if (!this.commandPaletteUrlValue) return;
    this.closeHelp();
    this.closeQuotePicker();

    const modal = document.getElementById("command-palette-modal");
    const input = document.getElementById("command-palette-search");
    if (!modal || !input) return;

    this.paletteItems = [];
    this.paletteActiveIndex = -1;
    modal.removeAttribute("hidden");
    input.value = "";
    this.loadCommandPalette("");
    input.focus();
  }

  closeCommandPalette() {
    document
      .getElementById("command-palette-modal")
      ?.setAttribute("hidden", "");
    this.paletteItems = [];
    this.paletteActiveIndex = -1;
  }

  commandPaletteBackdropClick(e) {
    if (e.target === e.currentTarget) this.closeCommandPalette();
  }

  onCommandPaletteInput(e) {
    const query = e.target.value || "";
    window.clearTimeout(this._paletteSearchTimer);
    this._paletteSearchTimer = window.setTimeout(
      () => this.loadCommandPalette(query),
      150,
    );
  }

  onCommandPaletteKeydown(e) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      this.movePaletteSelection(1);
      return;
    }

    if (e.key === "ArrowUp") {
      e.preventDefault();
      this.movePaletteSelection(-1);
      return;
    }

    if (e.key === "Enter") {
      e.preventDefault();
      this.activatePaletteSelection();
    }
  }

  activatePaletteItem(e) {
    const index = Number(e.currentTarget.dataset.paletteIndex);
    if (Number.isNaN(index)) return;
    const item = this.paletteItems[index];
    if (!item) return;
    this.runPaletteItem(item);
  }

  movePaletteSelection(step) {
    if (this.paletteItems.length === 0) return;
    const next = this.paletteActiveIndex + step;

    if (next < 0) {
      this.paletteActiveIndex = this.paletteItems.length - 1;
    } else if (next >= this.paletteItems.length) {
      this.paletteActiveIndex = 0;
    } else {
      this.paletteActiveIndex = next;
    }

    this.updatePaletteActiveState();
  }

  activatePaletteSelection() {
    if (this.paletteItems.length === 0) return;
    if (this.paletteActiveIndex < 0) this.paletteActiveIndex = 0;
    const item = this.paletteItems[this.paletteActiveIndex];
    if (!item) return;
    this.runPaletteItem(item);
  }

  async loadCommandPalette(query) {
    if (!this.commandPaletteUrlValue) return;

    try {
      const url = new URL(this.commandPaletteUrlValue, window.location.origin);
      if (query) url.searchParams.set("query", query);
      const res = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
      });
      if (!res.ok) throw new Error("request_failed");
      const data = await res.json();
      this.renderCommandPalette(data);
    } catch (_) {
      this.renderCommandPalette({ labels: { no_results: "No results" } });
    }
  }

  renderCommandPalette(data) {
    const container = document.getElementById("command-palette-results");
    if (!container) return;

    const labels = data?.labels || {};
    const groups = [
      {
        key: "actions",
        title: labels.actions,
        items: Array.isArray(data?.actions) ? data.actions : [],
      },
      {
        key: "customers",
        title: labels.customers,
        items: Array.isArray(data?.customers) ? data.customers : [],
      },
      {
        key: "products",
        title: labels.products,
        items: Array.isArray(data?.products) ? data.products : [],
      },
      {
        key: "quotes",
        title: labels.quotes,
        items: Array.isArray(data?.quotes) ? data.quotes : [],
      },
    ];

    this.paletteItems = [];
    let html = "";

    groups.forEach((group) => {
      if (!group.items || group.items.length === 0) return;
      html += `<section class=\"app-command-group\"><h4 class=\"app-command-group-title\">${group.title || ""}</h4>`;
      html += '<ul class="app-command-list">';
      group.items.forEach((item) => {
        const index = this.paletteItems.length;
        this.paletteItems.push(item);
        const metaHtml = item.meta
          ? `<span class=\"app-command-meta\">${item.meta}</span>`
          : "";
        html += `<li><button type=\"button\" class=\"app-command-item\" data-palette-index=\"${index}\" data-action=\"click->shortcuts#activatePaletteItem\"><span class=\"app-command-label\">${item.label || ""}</span>${metaHtml}</button></li>`;
      });
      html += "</ul></section>";
    });

    if (this.paletteItems.length === 0) {
      html = `<p class=\"app-shortcuts-empty\">${labels.no_results || "No results"}</p>`;
    }

    container.innerHTML = html;
    this.paletteActiveIndex = this.paletteItems.length > 0 ? 0 : -1;
    this.updatePaletteActiveState();
  }

  updatePaletteActiveState() {
    const nodes = document.querySelectorAll(
      "#command-palette-results .app-command-item",
    );
    nodes.forEach((node, idx) => {
      const isActive = idx === this.paletteActiveIndex;
      node.classList.toggle("is-active", isActive);
      if (isActive) node.scrollIntoView({ block: "nearest" });
    });
  }

  runPaletteItem(item) {
    this.closeCommandPalette();
    if (item.command === "open_quote_picker") {
      this.openQuotePicker();
      return;
    }
    if (item.path) Turbo.visit(item.path);
  }

  openQuotePicker() {
    if (!this.customerPickerUrlValue) return;
    this.closeHelp();

    const modal = document.getElementById("shortcut-quote-picker-modal");
    const searchInput = document.getElementById(
      "shortcut-quote-customer-search",
    );
    if (!modal || !searchInput) return;

    modal.removeAttribute("hidden");
    searchInput.value = "";
    this.loadCustomerCandidates("");
    searchInput.focus();
  }

  closeQuotePicker() {
    document
      .getElementById("shortcut-quote-picker-modal")
      ?.setAttribute("hidden", "");
  }

  quotePickerBackdropClick(e) {
    if (e.target === e.currentTarget) this.closeQuotePicker();
  }

  onQuoteSearchInput(e) {
    const query = e.target.value || "";
    window.clearTimeout(this._searchTimer);
    this._searchTimer = window.setTimeout(
      () => this.loadCustomerCandidates(query),
      180,
    );
  }

  selectQuoteCustomer(e) {
    const target = e.currentTarget;
    if (!target?.dataset?.quotePath) return;
    this.closeQuotePicker();
    Turbo.visit(target.dataset.quotePath);
  }

  async loadCustomerCandidates(query) {
    if (!this.customerPickerUrlValue) return;
    const list = document.getElementById("shortcut-quote-customer-results");
    const empty = document.getElementById("shortcut-quote-customer-empty");
    if (!list || !empty) return;

    try {
      const url = new URL(this.customerPickerUrlValue, window.location.origin);
      if (query) url.searchParams.set("query", query);
      const res = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
      });
      if (!res.ok) throw new Error("request_failed");
      const data = await res.json();
      const customers = Array.isArray(data.customers) ? data.customers : [];

      list.innerHTML = customers
        .map(
          (customer) =>
            `<li><button type="button" class="app-shortcuts-customer-option" data-action="click->shortcuts#selectQuoteCustomer" data-quote-path="${customer.quote_path}">${customer.name}</button></li>`,
        )
        .join("");

      empty.hidden = customers.length > 0;
      if (customers.length === 0) list.innerHTML = "";
    } catch (_) {
      list.innerHTML = "";
      empty.hidden = false;
    }
  }

  backdropClick(e) {
    if (e.target === e.currentTarget) this.closeHelp();
  }

  _onKey(e) {
    if (e.key === "Escape") {
      this.closeCommandPalette();
      this.closeHelp();
      this.closeQuotePicker();
      return;
    }

    const key = (e.key || "").toLowerCase();
    if ((e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey && key === "k") {
      e.preventDefault();
      this.openCommandPalette();
      return;
    }

    const tag = document.activeElement?.tagName;
    if (["INPUT", "TEXTAREA", "SELECT"].includes(tag)) return;
    if (document.activeElement?.isContentEditable) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;

    if (!e.shiftKey && key === "j") {
      e.preventDefault();
      this.moveListSelection(1);
      return;
    }

    if (!e.shiftKey && key === "k") {
      e.preventDefault();
      this.moveListSelection(-1);
      return;
    }

    if (!e.shiftKey && e.key === "Enter") {
      if (this.activateSelectedListItem()) {
        e.preventDefault();
        return;
      }
    }

    if (e.shiftKey && key === "c") {
      e.preventDefault();
      if (this.newCustomerUrlValue) Turbo.visit(this.newCustomerUrlValue);
      return;
    }

    if (e.shiftKey && key === "p") {
      e.preventDefault();
      if (this.newProductUrlValue) Turbo.visit(this.newProductUrlValue);
      return;
    }

    if (e.shiftKey && key === "q") {
      e.preventDefault();
      if (this.clickShortcutTarget(".js-shortcut-new-quote-current-customer"))
        return;
      this.openQuotePicker();
      return;
    }

    if (e.shiftKey && key === "s") {
      e.preventDefault();
      if (this.clickShortcutTarget(".js-banner-share-btn")) return;
      this.openQuoteShareShortcut();
      return;
    }

    switch (e.key) {
      case "/":
        if (e.shiftKey) return;
        e.preventDefault();
        document.querySelector(".app-search-input")?.focus();
        break;
      case "?":
        e.preventDefault();
        this.openHelp();
        break;
    }
  }

  clickShortcutTarget(selector) {
    const node = document.querySelector(selector);
    if (!node) return false;
    node.focus?.();
    node.click();
    return true;
  }

  openQuoteShareShortcut() {
    const shareDetails = document.querySelector(".js-send-share-menu");
    if (shareDetails) shareDetails.open = true;
    this.clickShortcutTarget(".js-share-public-link");
  }

  listRows() {
    return Array.from(
      document.querySelectorAll(
        ".app-data-table tbody tr[data-clickable-href]",
      ),
    );
  }

  moveListSelection(step) {
    const rows = this.listRows();
    if (rows.length === 0) return;

    let currentIndex = rows.findIndex((row) =>
      row.classList.contains("is-shortcut-active"),
    );
    if (currentIndex === -1) {
      currentIndex = step > 0 ? -1 : 0;
    }

    const nextIndex = (currentIndex + step + rows.length) % rows.length;
    rows.forEach((row, idx) => {
      row.classList.toggle("is-shortcut-active", idx === nextIndex);
      if (idx === nextIndex) row.scrollIntoView({ block: "nearest" });
    });
  }

  activateSelectedListItem() {
    const activeRow = document.querySelector(
      ".app-data-table tbody tr[data-clickable-href].is-shortcut-active",
    );
    const href = activeRow?.dataset?.clickableHref;
    if (!href) return false;
    Turbo.visit(href);
    return true;
  }
}
