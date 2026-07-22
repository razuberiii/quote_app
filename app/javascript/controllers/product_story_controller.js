import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "status", "progress"]
  static values = { labels: Array }

  connect() {
    this.labels = this.hasLabelsValue ? this.labelsValue : ["", "", ""]
    this.storyIndex = 0
    this.renderStory(0)
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.start()
      this.element.addEventListener("pointerenter", this.pause)
      this.element.addEventListener("pointerleave", this.start)
      this.element.addEventListener("focusin", this.pause)
      this.element.addEventListener("focusout", this.start)
    }
  }

  disconnect() { this.pause() }

  start = () => {
    this.pause()
    this.timer = setInterval(() => this.advanceStory(1), 2600)
  }

  pause = () => { clearInterval(this.timer) }

  next() { this.advanceStory(1); this.start() }
  previous() { this.advanceStory(-1); this.start() }

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
