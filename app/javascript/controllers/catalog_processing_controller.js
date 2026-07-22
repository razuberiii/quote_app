import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.poll()
    this.timer = window.setInterval(() => this.poll(), 3000)
  }

  disconnect() { window.clearInterval(this.timer) }

  async poll() {
    if (this.polling || document.hidden) return
    this.polling = true
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const result = await response.json()
      if (result.status !== "processing") {
        window.clearInterval(this.timer)
        if (window.Turbo) window.Turbo.visit(window.location.href, { action: "replace" })
        else window.location.reload()
      }
    } finally {
      this.polling = false
    }
  }
}
