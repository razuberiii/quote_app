import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "summary", "submit"]
  static values = {
    selectedOne: String,
    selectedMany: String,
    submitting: String
  }

  update() {
    const files = Array.from(this.inputTarget.files || [])
    if (files.length === 0) return

    const size = this.formatSize(files.reduce((total, file) => total + file.size, 0))
    this.summaryTarget.textContent = files.length === 1
      ? this.selectedOneValue.replace("%{name}", files[0].name).replace("%{size}", size)
      : this.selectedManyValue.replace("%{count}", files.length).replace("%{size}", size)
    this.element.classList.add("has-files")
  }

  submit() {
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = true
    this.submitTarget.value = this.submittingValue
    this.submitTarget.textContent = this.submittingValue
  }

  formatSize(bytes) {
    if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  }
}
