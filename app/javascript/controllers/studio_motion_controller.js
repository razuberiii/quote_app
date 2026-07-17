import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "price", "shipping", "discount", "tax", "total", "saveState"]
  connect() { this.recalculate() }
  dirty() { this.saveStateTarget.textContent = "● Unsaved changes"; this.saveStateTarget.classList.add("is-dirty"); this.recalculate() }
  recalculate() {
    const items = this.quantityTargets.reduce((sum, input, index) => sum + Number(input.value || 0) * Number(this.priceTargets[index]?.value || 0), 0)
    const total = Math.max(0, items + Number(this.shippingTarget?.value || 0) + Number(this.taxTarget?.value || 0) - Number(this.discountTarget?.value || 0))
    const next = new Intl.NumberFormat(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(total)
    if (this.totalTarget.textContent !== next) { this.totalTarget.textContent = next; this.totalTarget.classList.remove("is-updated"); void this.totalTarget.offsetWidth; this.totalTarget.classList.add("is-updated") }
  }
}
