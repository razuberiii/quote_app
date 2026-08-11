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

  applyCandidate(event) {
    const choice = event.currentTarget
    const card = choice.closest(".inquiry-product-card")
    if (!card) return

    const proposal = JSON.parse(choice.dataset.proposal || "{}")
    this.applyProposal(card, proposal)

    card.querySelectorAll(".catalog-candidate").forEach((row) => row.classList.remove("is-selected"))
    choice.closest(".catalog-candidate")?.classList.add("is-selected")
    const state = card.querySelector("[data-candidate-state]")
    if (state) state.textContent = choice.dataset.priceAvailable === "true" ? "已采用产品库资料与价格" : "已采用产品资料，价格仍需确认"
  }

  applyProposal(card, proposal) {
    this.setField(card, "name", proposal.name)
    this.setField(card, "model", proposal.model)
    this.setField(card, "unit", proposal.unit)
    this.setField(card, "packing", proposal.packing)
    this.setField(card, "lead_time", proposal.lead_time)
    this.setField(card, "unit_price", proposal.unit_price ?? "")
    this.setField(card, "price_source", proposal.price_source || "unpriced")
    Object.entries(proposal.specifications || {}).forEach(([key, value]) => {
      const field = card.querySelector(`[data-spec-key="${CSS.escape(key)}"]`)
      if (field && value != null) field.value = value
    })

  }

  keepRequested(event) {
    const card = event.currentTarget.closest(".inquiry-product-card")
    if (!card) return

    this.applyProposal(card, JSON.parse(event.currentTarget.dataset.proposal || "{}"))
    card?.querySelectorAll(".catalog-candidate").forEach((row) => row.classList.remove("is-selected"))
    event.currentTarget.closest(".catalog-candidate")?.classList.add("is-selected")
    const state = card?.querySelector("[data-candidate-state]")
    if (state) state.textContent = "保留客户原始需求，作为本次临时报价项"
  }

  setField(card, key, value) {
    if (value == null) return
    const field = card.querySelector(`[data-product-field="${key}"]`)
    if (field) field.value = value
  }

  get reducedMotion() {
    return matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
