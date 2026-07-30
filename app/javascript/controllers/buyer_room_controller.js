import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionDialog", "changesDialog", "replyDialog", "replyContext", "replyContextType", "replyKind", "acceptDialog", "questionContext", "plan", "quantity", "accessory", "total", "selectionCopy"]
  static values = { currency: String, shipping: Number, tax: Number, discount: Number }

  connect() { this.recalculate() }
  openQuestion(event) {
    const context = event.currentTarget.dataset.context || "quote"
    if (this.hasReplyDialogTarget) {
      this.syncSelectionForms()
      this.replyContextTarget.value = context.split(":").slice(1).join(":")
      this.replyContextTypeTarget.value = context.split(":")[0]
      this.replyKindTargets.forEach(input => { input.checked = input.value === "question" })
      this.replyDialogTarget.querySelector(".dialog-context").textContent = event.currentTarget.dataset.contextLabel || "Entire quotation"
      this.replyDialogTarget.showModal()
      return
    }
    this.questionContextTarget.value = context
    this.questionDialogTarget.querySelector("[name=context_type]").value = context.split(":")[0]
    this.questionDialogTarget.querySelector("[name=context_key]").value = context.split(":").slice(1).join(":")
    this.questionDialogTarget.querySelector(".dialog-context").textContent = event.currentTarget.dataset.contextLabel || "Entire quotation"
    this.questionDialogTarget.showModal()
  }
  openChanges() {
    this.syncSelectionForms()
    if (this.hasReplyDialogTarget) {
      this.replyContextTarget.value = "quote"
      this.replyContextTypeTarget.value = "quote"
      this.replyKindTargets.forEach(input => { input.checked = input.value === "change" })
      this.replyDialogTarget.querySelector(".dialog-context").textContent = "Entire quotation"
      this.replyDialogTarget.showModal()
      return
    }
    this.changesDialogTarget.showModal()
  }
  openAccept() { this.syncSelectionForms(); this.acceptDialogTarget.showModal() }
  close(event) { event.currentTarget.closest("dialog").close() }
  selectPlan(event) {
    this.planTargets.forEach(el => el.classList.toggle("is-selected", el === event.currentTarget))
    if (event.currentTarget.dataset.plan === "essential") this.accessoryTargets.forEach(input => { input.checked = false })
    if (event.currentTarget.dataset.plan === "complete") this.accessoryTargets.forEach(input => { input.checked = true })
    this.recalculate()
  }
  recalculate() {
    let subtotal = 0
    this.quantityTargets.forEach(input => { subtotal += Number(input.dataset.unitPrice || 0) * Number(input.value || 0) })
    this.accessoryTargets.filter(input => input.checked).forEach(input => { subtotal += Number(input.dataset.price || 0) })
    const total = Math.max(0, subtotal + this.shippingValue + this.taxValue - this.discountValue)
    this.totalTargets.forEach(el => {
      el.textContent = `${this.currencyValue} ${new Intl.NumberFormat(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(total)}`
      if (matchMedia("(prefers-reduced-motion: reduce)").matches) return
      el.classList.remove("is-total-updating")
      requestAnimationFrame(() => el.classList.add("is-total-updating"))
      window.setTimeout(() => el.classList.remove("is-total-updating"), 420)
    })
    this.syncSelectionForms()
  }
  syncSelectionForms() {
    const plan = this.planTargets.find(el => el.classList.contains("is-selected"))?.dataset.plan || "recommended"
    this.selectionCopyTargets.forEach(container => {
      container.innerHTML = `<input type="hidden" name="selection[plan]" value="${plan}">`
      this.quantityTargets.forEach(input => container.insertAdjacentHTML("beforeend", `<input type="hidden" name="selection[quantities][${input.dataset.index}]" value="${input.value}">`))
      this.accessoryTargets.filter(input => input.checked).forEach(input => container.insertAdjacentHTML("beforeend", `<input type="hidden" name="selection[accessories][]" value="${input.value}">`))
    })
  }
}
