import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state"]

  lock(event) {
    if (this.committed || matchMedia("(prefers-reduced-motion: reduce)").matches) return
    event.preventDefault()
    this.committed = true
    this.element.closest(".buyer-storefront")?.classList.add("is-accepting")
    this.stateTarget.hidden = false
    this.stateTarget.textContent = "Locking your selection"
    window.setTimeout(() => { this.stateTarget.textContent = "Recording acceptance" }, 360)
    window.setTimeout(() => this.element.requestSubmit(), 760)
  }
}
