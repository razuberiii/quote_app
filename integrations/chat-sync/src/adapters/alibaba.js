import { BaseAdapter } from "./base-adapter.js"

export class AlibabaAdapter extends BaseAdapter {
  getPlatform() { return "alibaba" }
  isSupportedPage() {
    return /(^|\.)alibaba\.com$/.test(location.hostname) && /message|inquiry|chat|contact/i.test(location.href)
  }

  getCurrentAccount() {
    const id = document.querySelector("[data-account-id]")?.getAttribute("data-account-id") || "alibaba-web"
    return { id, name: "Alibaba.com" }
  }

  getCurrentConversation() {
    const selected = document.querySelector("[data-conversation-id][aria-selected='true'], [data-conversation-id].active")
    const header = document.querySelector("[class*='conversation'] [class*='header'], [class*='chat'] [class*='header']")
    const displayName = selected?.getAttribute("title") || header?.querySelector("[title]")?.getAttribute("title") ||
      header?.textContent?.trim().slice(0, 160)
    const id = selected?.getAttribute("data-conversation-id") || selected?.dataset?.conversationId
    if (!displayName && !id) return null
    return { id: this.stableConversationId(id || displayName), displayName: displayName || id }
  }

  findMessageContainer() {
    return document.querySelector("[data-testid='message-list'], [class*='message-list'], [class*='messageList'], [class*='conversation-content']")
  }

  parseVisibleMessages() {
    const container = this.findMessageContainer()
    if (!container) return []
    const nodes = container.querySelectorAll("[data-message-id], [class*='message-item'], [class*='messageItem']")
    return [...new Set(nodes)].map(node => this.parseMessage(node)).filter(Boolean)
  }

  parseMessage(node) {
    const textNode = node.querySelector("[class*='text'], [class*='content'], [data-testid='message-text']")
    const text = textNode?.textContent?.trim()
    const attachment = node.querySelector("a[download], [class*='attachment'], [class*='file']")
    if (!text && !attachment) return null
    const own = node.matches("[class*='self'],[class*='right'],[data-sender='self']") ||
      node.querySelector("[class*='self'],[data-sender='self']")
    const timeText = node.querySelector("time, [class*='time']")?.textContent?.trim()
    return {
      platformMessageId: node.getAttribute("data-message-id") || node.dataset?.messageId,
      direction: own ? "sales" : "customer",
      senderName: node.querySelector("[class*='sender'],[class*='name']")?.textContent?.trim(),
      sentAt: parseTime(timeText), type: attachment ? "file" : "text", text,
      attachmentName: attachment?.getAttribute("download") || attachment?.textContent?.trim(),
      sourceMetadata: { visibleTimestamp: timeText, adapter: "alibaba-v1" },
      parserVersion: "alibaba-v1"
    }
  }
}

function parseTime(value) {
  if (!value) return null
  const date = new Date(value)
  return Number.isNaN(date.valueOf()) ? null : date.toISOString()
}
