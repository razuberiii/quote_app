import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "channel", "external", "email", "link", "signal", "submit", "copy"]

  connect() { this.selectOption(this.optionTargets[0]) }

  select(event) { this.selectOption(event.currentTarget) }

  selectOption(option) {
    this.optionTargets.forEach((item) => item.classList.toggle("is-selected", item === option))
    this.channelTarget.value = option.dataset.value
    const external = option.dataset.value === "external" || option.dataset.value === "printed"
    this.externalTarget.hidden = !external
    this.emailTarget.hidden = !option.dataset.value.startsWith("email")
    this.linkTarget.hidden = option.dataset.value !== "buyer_room_link"
    const submitLabel = external ? "Record external delivery" : option.dataset.value.includes("download") || option.dataset.value.includes("export") ? "Generate file" : "Deliver Version"
    if (this.submitTarget instanceof HTMLInputElement) this.submitTarget.value = submitLabel
    else this.submitTarget.textContent = submitLabel
    this.signalTarget.textContent = option.dataset.value.includes("link") ? "Buyer Room activity available" : "View status unavailable"
  }

  async copy() {
    await navigator.clipboard.writeText(this.copyTarget.value)
    this.copyTarget.select()
    this.element.dispatchEvent(new CustomEvent("rubusoo:signal", { bubbles: true, detail: { message: "Secure link copied" } }))
  }

  sending() {
    this.signalTarget.textContent = "Queued · Preparing output…"
    this.element.classList.add("is-delivering")
    this.submitTarget.disabled = true
    this.submitTarget.dataset.originalLabel = this.submitTarget.value || this.submitTarget.textContent
    if (this.submitTarget instanceof HTMLInputElement) this.submitTarget.value = "Sending…"
    else this.submitTarget.textContent = "Sending…"
  }

  finished(event) {
    if (event.detail.success) return
    this.element.classList.remove("is-delivering")
    this.element.classList.add("has-delivery-failure")
    this.signalTarget.textContent = "Failed · Retry available"
    this.submitTarget.disabled = false
    if (this.submitTarget instanceof HTMLInputElement) this.submitTarget.value = "Retry delivery"
    else this.submitTarget.textContent = "Retry delivery"
  }
}
