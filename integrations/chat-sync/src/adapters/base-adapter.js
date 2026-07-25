export class BaseAdapter {
  observer = null

  isSupportedPage() { return false }
  getPlatform() { return "generic" }
  getCurrentAccount() { return { id: location.hostname, name: location.hostname } }
  getCurrentConversation() { return null }
  findMessageContainer() { return null }
  parseVisibleMessages() { return [] }
  getConversationDisplayName() { return this.getCurrentConversation()?.displayName || "" }

  observeConversationChanges(callback) {
    const container = this.findMessageContainer()
    if (!container) return
    this.observer?.disconnect()
    this.observer = new MutationObserver(() => callback())
    this.observer.observe(container, { childList: true, subtree: true })
  }

  dispose() {
    this.observer?.disconnect()
    this.observer = null
  }

  stableConversationId(value) {
    return `${this.getPlatform()}:${String(value || "").trim().toLowerCase().replace(/\s+/g, "-").slice(0, 180)}`
  }
}
