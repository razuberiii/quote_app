import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "status", "progress"]

  connect() {
    this.index = 0
    this.labels = ["Reading inquiry", "Confirming commercial gaps", "Version accepted"]
    this.render()
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.timer = setInterval(() => this.advance(1), 3200)
    }
  }

  disconnect() { clearInterval(this.timer) }
  next() { this.restart(); this.advance(1) }
  previous() { this.restart(); this.advance(-1) }
  restart() {
    clearInterval(this.timer)
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) this.timer = setInterval(() => this.advance(1), 3200)
  }
  advance(delta) { this.index = (this.index + delta + this.stepTargets.length) % this.stepTargets.length; this.render() }
  render() {
    this.stepTargets.forEach((step, index) => step.classList.toggle("is-active", index === this.index))
    if (this.hasStatusTarget) this.statusTarget.textContent = this.labels[this.index]
    if (this.hasProgressTarget) this.progressTarget.style.transform = `scaleX(${(this.index + 1) / this.stepTargets.length})`
  }
}
