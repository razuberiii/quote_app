import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "result", "code", "copy", "countdown"]
  static values = { url: String, copyLabel: String, copiedLabel: String, expiresLabel: String }

  disconnect() {
    if (this.countdownTimer) clearInterval(this.countdownTimer)
  }

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
      this.copyTarget.hidden = false
      this.startCountdown(payload.expiresIn)
    } catch (_error) {
      this.codeTarget.textContent = this.element.dataset.chatPairingErrorMessage
      this.resultTarget.hidden = false
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  async copy() {
    const code = this.codeTarget.textContent.trim()
    if (!code) return

    await navigator.clipboard.writeText(code)
    this.copyTarget.textContent = this.copiedLabelValue
    window.setTimeout(() => { this.copyTarget.textContent = this.copyLabelValue }, 1600)
  }

  startCountdown(seconds) {
    if (this.countdownTimer) clearInterval(this.countdownTimer)
    let remaining = Number(seconds) || 0
    const render = () => {
      const minutes = Math.floor(remaining / 60)
      const secondsPart = String(remaining % 60).padStart(2, "0")
      this.countdownTarget.textContent = this.expiresLabelValue.replace("__TIME__", `${minutes}:${secondsPart}`)
    }
    render()
    this.countdownTimer = window.setInterval(() => {
      remaining = Math.max(remaining - 1, 0)
      render()
      if (remaining === 0) clearInterval(this.countdownTimer)
    }, 1000)
  }
}
