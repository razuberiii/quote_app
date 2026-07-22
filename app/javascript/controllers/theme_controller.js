import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.apply(this.savedTheme() || "light")
  }

  toggle(event) {
    const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    const rect = event.currentTarget.getBoundingClientRect()
    document.documentElement.style.setProperty("--theme-x", `${rect.left + rect.width / 2}px`)
    document.documentElement.style.setProperty("--theme-y", `${rect.top + rect.height / 2}px`)

    this.apply(nextTheme, true)
  }

  apply(theme, persist = false) {
    document.documentElement.dataset.theme = theme
    document.documentElement.style.colorScheme = theme
    if (persist) localStorage.setItem("rubusoo-theme", theme)
    document.querySelectorAll("[data-theme-label]").forEach((label) => {
      label.textContent = theme === "dark" ? label.dataset.lightLabel : label.dataset.darkLabel
    })
    document.querySelectorAll(".theme-switch").forEach((button) => {
      button.setAttribute("aria-pressed", theme === "dark" ? "true" : "false")
      button.setAttribute("aria-label", theme === "dark" ? "切换浅色模式" : "切换深色模式")
      button.title = button.getAttribute("aria-label")
    })
  }

  savedTheme() {
    try { return localStorage.getItem("rubusoo-theme") } catch (_) { return null }
  }

}
