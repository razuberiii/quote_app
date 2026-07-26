import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "detail", "link"]
  static values = { url: String, batchId: Number, status: String }

  connect() {
    if (this.statusValue !== "processing") return

    this.timer = window.setInterval(() => this.poll(), 8000)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  async poll() {
    if (this.polling || document.hidden) return

    this.polling = true
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const task = await response.json()
      if (task.id !== this.batchIdValue || task.status === "processing") return

      window.clearInterval(this.timer)
      this.statusValue = task.status
      this.element.className = `catalog-task-bar catalog-task-bar--${task.status}`
      this.labelTarget.textContent = task.label
      this.detailTarget.textContent = task.status === "review"
        ? "识别结果已保存，核对后再加入商品库。"
        : "原文件已保留，可以打开任务查看原因并重新分析。"
      this.linkTarget.href = task.path
    } finally {
      this.polling = false
    }
  }
}
