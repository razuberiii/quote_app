import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state"]
  static values = { locking: String, recording: String }

  lock(event) {
    if (this.committed || matchMedia("(prefers-reduced-motion: reduce)").matches) return
    event.preventDefault()
    this.committed = true
    this.element.closest(".buyer-storefront")?.classList.add("is-accepting")
    this.stateTarget.hidden = false
    this.stateTarget.textContent = this.lockingValue
    window.setTimeout(() => { this.stateTarget.textContent = this.recordingValue }, 360)
    window.setTimeout(() => this.element.requestSubmit(), 760)
  }
}
