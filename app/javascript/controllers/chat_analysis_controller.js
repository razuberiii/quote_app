import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, status: String }

  connect() {
    if (this.statusValue === "queued") this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.poll(), 1800)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json", "Cache-Control": "no-store" }
      })
      const payload = await response.json()
      if (payload.status === "queued") return this.schedule()
      location.reload()
    } catch {
      this.schedule()
    }
  }
}
