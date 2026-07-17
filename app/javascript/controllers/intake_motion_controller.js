import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "field", "build"]
  connect() {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.sourceTarget?.classList.add("is-scanning")
    this.fieldTargets.forEach((field, index) => { field.style.setProperty("--extract-index", index); field.classList.add("is-extracting") })
  }
  focusSource(event) {
    this.fieldTargets.forEach(field => field.classList.toggle("is-linked", field === event.currentTarget))
    const excerpt = event.currentTarget.querySelector("small")?.textContent?.replace(/[“”]/g, "").trim()
    if (!excerpt || excerpt.includes("No source")) return
    const body = this.sourceTarget.querySelector(".inquiry-source-panel__body")
    body.querySelectorAll("mark").forEach(mark => mark.replaceWith(mark.textContent))
    const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT)
    while (walker.nextNode()) {
      const node = walker.currentNode, index = node.textContent.toLowerCase().indexOf(excerpt.toLowerCase())
      if (index < 0) continue
      const range = document.createRange(); range.setStart(node, index); range.setEnd(node, index + excerpt.length)
      const mark = document.createElement("mark"); range.surroundContents(mark); mark.scrollIntoView({ block: "center", behavior: "smooth" }); break
    }
  }
  build(event) {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return
    event.currentTarget.classList.add("is-building"); this.element.classList.add("is-converging")
  }
}
