import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  seal(event) {
    if (this.committed || matchMedia("(prefers-reduced-motion: reduce)").matches) return
    event.preventDefault()
    this.committed = true
    this.element.classList.add("is-sealing")
    const button = this.element.querySelector("button, input[type=submit]")
    if (button) button.textContent = "Freezing products and terms"
    window.setTimeout(() => { if (button) button.textContent = "Creating immutable Version" }, 350)
    window.setTimeout(() => this.element.requestSubmit(), 760)
  }
}
