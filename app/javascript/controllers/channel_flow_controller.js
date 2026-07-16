import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "channel", "external", "signal"]

  connect() { this.selectOption(this.optionTargets[0]) }

  select(event) { this.selectOption(event.currentTarget) }

  selectOption(option) {
    this.optionTargets.forEach((item) => item.classList.toggle("is-selected", item === option))
    this.channelTarget.value = option.dataset.value
    const external = option.dataset.value === "external" || option.dataset.value === "printed"
    this.externalTarget.hidden = !external
    this.signalTarget.textContent = option.dataset.value.includes("link") ? "Buyer Room activity available" : "View status unavailable"
  }
}
