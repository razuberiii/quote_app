import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "price", "shipping", "discount", "tax", "total", "saveState"]
  connect() { this.recalculate() }
  dirty() { this.saveStateTarget.textContent = "● Unsaved changes"; this.saveStateTarget.classList.add("is-dirty"); this.recalculate() }
  saving() { this.saveStateTarget.textContent = "● Saving…"; this.saveStateTarget.classList.remove("is-saved"); this.saveStateTarget.classList.add("is-saving") }
  saved(event) {
    this.saveStateTarget.classList.remove("is-saving")
    if (!event.detail.success) { this.saveStateTarget.textContent = "● Save failed"; this.saveStateTarget.classList.add("is-dirty"); return }
    this.saveStateTarget.textContent = "● Saved"
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
    const total = Math.max(0, items + Number(this.shippingTarget?.value || 0) + Number(this.taxTarget?.value || 0) - Number(this.discountTarget?.value || 0))
    const next = new Intl.NumberFormat(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(total)
    if (this.totalTarget.textContent !== next) { this.totalTarget.textContent = next; this.totalTarget.classList.remove("is-updated"); void this.totalTarget.offsetWidth; this.totalTarget.classList.add("is-updated") }
  }
}
