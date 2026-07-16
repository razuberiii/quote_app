import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionDialog", "changesDialog", "acceptDialog", "questionContext"]
  openQuestion(event) { this.questionContextTarget.value = event.currentTarget.dataset.context || "quote"; this.questionDialogTarget.showModal() }
  openChanges() { this.changesDialogTarget.showModal() }
  openAccept() { this.acceptDialogTarget.showModal() }
  close(event) { event.currentTarget.closest("dialog").close() }
}
