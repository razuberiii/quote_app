import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.sections = Array.from(this.element.querySelectorAll(":scope > section:not(.product-hero)"))
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.sections.forEach(section => section.classList.add("is-revealed"))
      return
    }

    this.sections.forEach(section => section.classList.add("product-reveal"))
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return
        entry.target.classList.add("is-revealed")
        this.observer.unobserve(entry.target)
      })
    }, { rootMargin: "0px 0px -12%", threshold: 0.12 })
    this.sections.forEach(section => this.observer.observe(section))
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
