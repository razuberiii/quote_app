import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    this.nodes = this.collectNodes()

    if (this.reduced) {
      this.nodes.forEach(node => node.classList.add("is-motion-visible"))
      return
    }

    document.documentElement.classList.add("motion-enabled")
    this.observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return
        const index = this.nodes.indexOf(entry.target)
        entry.target.style.setProperty("--motion-order", String(index % 6))
        entry.target.classList.add("motion-node")
        requestAnimationFrame(() => entry.target.classList.add("is-motion-visible"))
        this.observer.unobserve(entry.target)
      })
    }, { rootMargin: "0px 0px 12%", threshold: 0.04 })
    this.nodes.forEach(node => this.observer.observe(node))

    this.progress = document.createElement("div")
    this.progress.className = "motion-progress"
    this.progress.setAttribute("aria-hidden", "true")
    document.body.appendChild(this.progress)
    this.onScroll = () => {
      const maximum = document.documentElement.scrollHeight - innerHeight
      this.progress.style.setProperty("--motion-scroll", maximum > 0 ? String(scrollY / maximum) : "0")
    }
    this.onPointer = event => {
      document.documentElement.style.setProperty("--motion-x", `${event.clientX}px`)
      document.documentElement.style.setProperty("--motion-y", `${event.clientY}px`)
    }
    addEventListener("scroll", this.onScroll, { passive: true })
    addEventListener("pointermove", this.onPointer, { passive: true })
    this.onScroll()

  }

  disconnect() {
    this.observer?.disconnect()
    removeEventListener("scroll", this.onScroll)
    removeEventListener("pointermove", this.onPointer)
    this.progress?.remove()
  }

  collectNodes() {
    const selectors = [
      "main > .workspace-page",
      ".workspace-heading", ".deal-page-header", ".deal-hero",
      ".ai-entry", ".app-surface", ".deal-row", ".inbox-event",
      ".field-section", ".candidate-row", ".document-group"
    ]
    return [...new Set(this.element.querySelectorAll(selectors.join(",")))]
      .filter(node => !node.closest("dialog,[hidden]") && !node.classList.contains("product-reveal"))
  }

}
