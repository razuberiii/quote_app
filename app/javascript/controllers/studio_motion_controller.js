import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "price", "shipping", "discount", "tax", "total", "saveState", "summarySubtotal", "summaryFees", "summaryTotal", "readiness", "readinessTitle", "readinessHelp"]
  static values = { unsaved: String, saving: String, saved: String, saveFailed: String, recheck: String, recheckHelp: String }
  connect() {
    this.recalculate()
    this.form = this.element.querySelector("#quote-studio-form")
    this.beforeVisit = this.handleBeforeVisit.bind(this)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }
  disconnect() {
    clearTimeout(this.saveTimer)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
  }
  dirty() {
    this.isDirty = true
    this.saveStateTarget.textContent = `● ${this.unsavedValue}`
    this.saveStateTarget.classList.add("is-dirty")
    if (this.hasReadinessTarget) {
      this.readinessTarget.classList.remove("is-ready")
      this.readinessTarget.classList.add("is-stale")
      this.readinessTarget.querySelector("ul")?.setAttribute("hidden", "hidden")
      if (this.hasReadinessTitleTarget) this.readinessTitleTarget.textContent = this.recheckValue
      if (this.hasReadinessHelpTarget) this.readinessHelpTarget.textContent = this.recheckHelpValue
    }
    this.recalculate()
    clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.autosave(), 900)
  }
  saving() { this.saveStateTarget.textContent = `● ${this.savingValue}`; this.saveStateTarget.classList.remove("is-saved"); this.saveStateTarget.classList.add("is-saving") }
  saved(event) {
    this.saveStateTarget.classList.remove("is-saving")
    if (!event.detail.success) { this.saveStateTarget.textContent = `● ${this.saveFailedValue}`; this.saveStateTarget.classList.add("is-dirty"); return }
    this.saveStateTarget.textContent = `● ${this.savedValue}`
    this.saveStateTarget.classList.remove("is-dirty")
    this.saveStateTarget.classList.add("is-saved")
  }
  async autosave() {
    if (!this.form || !this.isDirty || this.isSaving) return
    this.isSaving = true
    this.saving()
    try {
      const response = await fetch(this.form.action, {
        method: "POST",
        body: new FormData(this.form),
        credentials: "same-origin",
        headers: { "Accept": "text/html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "" }
      })
      if (!response.ok) throw new Error(`Autosave failed (${response.status})`)
      const html = await response.text()
      this.refreshServerState(html)
      this.isDirty = false
      this.saved({ detail: { success: true } })
      if (this.resumeUrl) {
        const url = this.resumeUrl
        this.resumeUrl = null
        window.Turbo.visit(url)
      }
    } catch (_error) {
      this.saved({ detail: { success: false } })
      this.resumeUrl = null
    } finally {
      this.isSaving = false
      if (this.isDirty && !this.resumeUrl) this.saveTimer = setTimeout(() => this.autosave(), 1200)
    }
  }
  refreshServerState(html) {
    const document = new DOMParser().parseFromString(html, "text/html")
    const nextReadiness = document.querySelector("[data-studio-motion-target='readiness']")
    if (nextReadiness && this.hasReadinessTarget) this.readinessTarget.replaceWith(nextReadiness)

    const nextPrimaryAction = document.querySelector(".studio-actions .button--primary")
    const currentPrimaryAction = this.element.querySelector(".studio-actions .button--primary")
    if (nextPrimaryAction && currentPrimaryAction) currentPrimaryAction.replaceWith(nextPrimaryAction)
  }
  handleBeforeVisit(event) {
    if (!this.isDirty || this.isSaving) return
    event.preventDefault()
    this.resumeUrl = event.detail.url
    clearTimeout(this.saveTimer)
    this.autosave()
  }
  duplicateItem(event) {
    const item = event.currentTarget.closest(".studio-product")
    if (!item) return
    const copy = item.cloneNode(true)
    const itemIndex = `${Date.now()}`
    copy.querySelectorAll("input, textarea, select").forEach(field => {
      if (field.name?.includes("[id]")) field.remove()
      else if (field.name) field.name = field.name.replace(/quote_items_attributes\]\[\d+\]/, `quote_items_attributes][${itemIndex}]`)
    })
    item.after(copy)
    copy.animate([{ opacity: 0, transform: "translateY(-10px)" }, { opacity: 1, transform: "none" }], { duration: 220, easing: "cubic-bezier(.2,.8,.2,1)" })
    this.dirty()
  }
  newItem() {
    const item = this.element.querySelector(".studio-product:last-of-type")
    if (!item) return
    const copy = item.cloneNode(true)
    const itemIndex = `${Date.now()}`
    copy.querySelectorAll("input, textarea, select").forEach(field => {
      if (field.name?.includes("[id]")) return field.remove()
      if (field.name) field.name = field.name.replace(/quote_items_attributes\]\[\d+\]/, `quote_items_attributes][${itemIndex}]`)
      if (field.type === "checkbox") field.checked = false
      else if (field.name?.includes("[quantity]")) field.value = "1"
      else if (field.name?.includes("[unit_price]")) field.value = "0"
      else if (field.name?.includes("[price_source]")) field.value = "unpriced"
      else if (field.name?.includes("[selection_mode]")) field.value = "fixed"
      else if (field.tagName === "SELECT") field.selectedIndex = 0
      else field.value = ""
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
