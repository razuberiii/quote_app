import { Controller } from "@hotwired/stimulus"

const TYPE_DELAY = 58
const DELETE_DELAY = 31
const HOLD_DELAY = 1150

export default class extends Controller {
  static targets = ["step", "status", "progress", "phrase"]

  connect() {
    this.reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    this.phrases = ["buyer requests", "messy emails", "spreadsheets", "purchase orders"]
    this.labels = ["Evidence located", "Commercial gaps controlled", "Version locked · accepted"]
    this.phraseIndex = 0
    this.storyIndex = 0
    this.timeouts = []

    if (this.reduced) {
      this.phraseTarget.textContent = "buyer requests"
      this.renderStory(2)
      return
    }

    this.phraseTarget.textContent = ""
    this.typeCurrentPhrase()
    this.renderStory(0)
    this.storyTimer = window.setInterval(() => this.advanceStory(1), 2700)
  }

  disconnect() {
    this.timeouts.forEach(window.clearTimeout)
    window.clearInterval(this.storyTimer)
  }

  later(callback, delay) {
    const id = window.setTimeout(callback, delay)
    this.timeouts.push(id)
    return id
  }

  typeCurrentPhrase(position = 0) {
    const phrase = this.phrases[this.phraseIndex]
    this.phraseTarget.textContent = phrase.slice(0, position)
    if (position < phrase.length) {
      // Keep the cadence human, but deterministic so visual regression captures
      // the same product story frame on every run.
      this.later(() => this.typeCurrentPhrase(position + 1), TYPE_DELAY + (position % 3) * 12)
    } else {
      this.later(() => this.deleteCurrentPhrase(phrase.length), HOLD_DELAY)
    }
  }

  deleteCurrentPhrase(position) {
    const phrase = this.phrases[this.phraseIndex]
    this.phraseTarget.textContent = phrase.slice(0, position)
    if (position > 0) {
      this.later(() => this.deleteCurrentPhrase(position - 1), DELETE_DELAY)
    } else {
      this.phraseIndex = (this.phraseIndex + 1) % this.phrases.length
      this.later(() => this.typeCurrentPhrase(), 180)
    }
  }

  next() { this.restartStory(); this.advanceStory(1) }
  previous() { this.restartStory(); this.advanceStory(-1) }

  restartStory() {
    window.clearInterval(this.storyTimer)
    if (!this.reduced) this.storyTimer = window.setInterval(() => this.advanceStory(1), 2700)
  }

  advanceStory(delta) {
    this.storyIndex = (this.storyIndex + delta + this.stepTargets.length) % this.stepTargets.length
    this.renderStory(this.storyIndex)
  }

  renderStory(index) {
    this.storyIndex = index
    this.element.dataset.storyPhase = String(index + 1)
    this.stepTargets.forEach((step, stepIndex) => {
      const active = stepIndex === index
      const complete = stepIndex < index
      step.classList.toggle("is-active", active)
      step.classList.toggle("is-complete", complete)
      step.setAttribute("aria-hidden", active ? "false" : "true")
    })
    if (this.hasStatusTarget) this.statusTarget.textContent = this.labels[index]
    if (this.hasProgressTarget) this.progressTarget.style.transform = `scaleX(${(index + 1) / this.stepTargets.length})`
  }
}
