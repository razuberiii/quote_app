import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "status", "progress", "phrase"]

  connect() {
    this.index = 0
    this.phraseIndex = 0
    this.phrases = ["buyer requests", "messy emails", "spreadsheets", "purchase orders"]
    this.labels = ["Reading inquiry", "Confirming commercial gaps", "Version accepted"]
    this.render()
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.timer = setInterval(() => this.advance(1), 3200)
      this.phraseTimer = setInterval(() => this.rotatePhrase(), 2600)
    } else if (this.hasPhraseTarget) {
      this.phraseTarget.textContent = "buyer requests"
    }
  }

  disconnect() { clearInterval(this.timer); clearInterval(this.phraseTimer); clearTimeout(this.phraseSwapTimer) }
  next() { this.restart(); this.advance(1) }
  previous() { this.restart(); this.advance(-1) }
  restart() {
    clearInterval(this.timer)
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) this.timer = setInterval(() => this.advance(1), 3200)
  }
  advance(delta) { this.index = (this.index + delta + this.stepTargets.length) % this.stepTargets.length; this.render() }
  render() {
    this.stepTargets.forEach((step, index) => {
      step.classList.toggle("is-active", index === this.index)
      step.setAttribute("aria-hidden", index === this.index ? "false" : "true")
    })
    if (this.hasStatusTarget) this.statusTarget.textContent = this.labels[this.index]
    if (this.hasProgressTarget) this.progressTarget.style.transform = `scaleX(${(this.index + 1) / this.stepTargets.length})`
  }

  rotatePhrase() {
    if (!this.hasPhraseTarget) return
    this.phraseTarget.closest(".kinetic-headline__window")?.classList.add("is-changing")
    this.phraseSwapTimer = setTimeout(() => {
      this.phraseIndex = (this.phraseIndex + 1) % this.phrases.length
      this.phraseTarget.textContent = this.phrases[this.phraseIndex]
      this.phraseTarget.closest(".kinetic-headline__window")?.classList.remove("is-changing")
    }, 210)
  }
}
