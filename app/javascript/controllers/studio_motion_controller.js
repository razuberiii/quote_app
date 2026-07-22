import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "price", "shipping", "discount", "tax", "total", "saveState", "summarySubtotal", "summaryFees", "summaryTotal", "readiness", "readinessTitle", "readinessHelp"]
  static values = { unsaved: String, saving: String, saved: String, saveFailed: String, recheck: String, recheckHelp: String }
  connect() { this.recalculate() }
  dirty() {
    this.saveStateTarget.textContent = `● ${this.unsavedValue}`
    this.saveStateTarget.classList.add("is-dirty")
    if (this.hasReadinessTarget) {
      this.readinessTarget.classList.remove("is-ready")
      this.readinessTarget.classList.add("is-stale")
      this.readinessTarget.querySelector("ul")?.setAttribute("hidden", "hidden")
      this.readinessTitleTarget.textContent = this.recheckValue
      this.readinessHelpTarget.textContent = this.recheckHelpValue
    }
    this.recalculate()
  }
  saving() { this.saveStateTarget.textContent = `● ${this.savingValue}`; this.saveStateTarget.classList.remove("is-saved"); this.saveStateTarget.classList.add("is-saving") }
  saved(event) {
    this.saveStateTarget.classList.remove("is-saving")
    if (!event.detail.success) { this.saveStateTarget.textContent = `● ${this.saveFailedValue}`; this.saveStateTarget.classList.add("is-dirty"); return }
    this.saveStateTarget.textContent = `● ${this.savedValue}`
    this.saveStateTarget.classList.remove("is-dirty")
    this.saveStateTarget.classList.add("is-saved")
  }
  duplicateItem(event) {
    const item = event.currentTarget.closest(".studio-product")
    if (!item) return
    const copy = item.cloneNode(true)
    copy.querySelectorAll("input, textarea, select").forEach(field => {
      if (field.name?.includes("[id]")) field.remove()
      else if (field.name) field.name = field.name.replace(/quote_items_attributes\]\[\d+\]/, `quote_items_attributes][new_${Date.now()}]`)
    })
    item.after(copy)
    copy.animate([{ opacity: 0, transform: "translateY(-10px)" }, { opacity: 1, transform: "none" }], { duration: 220, easing: "cubic-bezier(.2,.8,.2,1)" })
    this.dirty()
  }
  newItem() {
    const item = this.element.querySelector(".studio-product:last-of-type")
    if (!item) return
    const copy = item.cloneNode(true)
    copy.querySelectorAll("input, textarea, select").forEach(field => {
      if (field.name?.includes("[id]")) return field.remove()
      if (field.name) field.name = field.name.replace(/quote_items_attributes\]\[\d+\]/, `quote_items_attributes][new_${Date.now()}]`)
      if (field.type === "checkbox") field.checked = false
      else if (field.tagName === "SELECT") field.selectedIndex = 0
      else field.value = field.name?.includes("[quantity]") ? "1" : ""
    })
    item.after(copy)
    copy.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "center" })
    this.dirty()
  }
  recalculate() {
    const items = this.quantityTargets.reduce((sum, input, index) => sum + Number(input.value || 0) * Number(this.priceTargets[index]?.value || 0), 0)
    const fees = Number(this.shippingTarget?.value || 0) + Number(this.taxTarget?.value || 0)
    const total = Math.max(0, items + fees - Number(this.discountTarget?.value || 0))
    const next = new Intl.NumberFormat(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(total)
    if (this.totalTarget.textContent !== next) { this.totalTarget.textContent = next; this.totalTarget.classList.remove("is-updated"); void this.totalTarget.offsetWidth; this.totalTarget.classList.add("is-updated") }
    const currency = this.element.querySelector("select[name='quote[currency]']")?.value || ""
    const money = value => `${currency} ${new Intl.NumberFormat(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value)}`
    if (this.hasSummarySubtotalTarget) this.summarySubtotalTarget.textContent = money(items)
    if (this.hasSummaryFeesTarget) this.summaryFeesTarget.textContent = money(fees)
    if (this.hasSummaryTotalTarget) this.summaryTotalTarget.textContent = money(total)
  }
}
