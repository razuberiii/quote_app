import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "result", "code"]
  static values = { url: String }

  async create() {
    this.buttonTarget.disabled = true
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }
      })
      if (!response.ok) throw new Error("pairing_failed")
      const payload = await response.json()
      this.codeTarget.textContent = payload.code
      this.resultTarget.hidden = false
    } catch (_error) {
      this.codeTarget.textContent = this.element.dataset.chatPairingErrorMessage
      this.resultTarget.hidden = false
    } finally {
      this.buttonTarget.disabled = false
    }
  }
}
