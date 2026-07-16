import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "number"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.itemTargets.forEach((item, index) => {
      item.style.setProperty("--deal-enter-delay", `${Math.min(index * 45, 270)}ms`)
      item.classList.add("is-entering")
    })
  }
}
