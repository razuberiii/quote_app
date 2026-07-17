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
    this.submitTarget.textContent = external ? "Record external delivery" : option.dataset.value.includes("download") || option.dataset.value.includes("export") ? "Generate file" : "Deliver Version"
    this.signalTarget.textContent = option.dataset.value.includes("link") ? "Buyer Room activity available" : "View status unavailable"
  }

  async copy() {
    await navigator.clipboard.writeText(this.copyTarget.value)
    this.copyTarget.select()
    this.element.dispatchEvent(new CustomEvent("rubusoo:signal", { bubbles: true, detail: { message: "Secure link copied" } }))
  }
}
