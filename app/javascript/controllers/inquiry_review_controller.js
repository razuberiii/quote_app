import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["products", "template"]

  addProduct() {
    const index = `${Date.now()}`
    const fragment = this.templateTarget.content.cloneNode(true)
    fragment.querySelectorAll("[name]").forEach((field) => {
      field.name = field.name.replaceAll("NEW_INDEX", index)
    })
    const item = fragment.querySelector("article")
    this.productsTarget.appendChild(fragment)
    item?.scrollIntoView({ behavior: this.reducedMotion ? "auto" : "smooth", block: "center" })
    item?.querySelector("input")?.focus()
  }

  removeProduct(event) {
    event.currentTarget.closest("article")?.remove()
  }

  get reducedMotion() {
    return matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
