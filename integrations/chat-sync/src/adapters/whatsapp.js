import { BaseAdapter } from "./base-adapter.js"

export class WhatsAppAdapter extends BaseAdapter {
  getPlatform() { return "whatsapp" }
  isSupportedPage() { return location.hostname === "web.whatsapp.com" }

  getCurrentAccount() {
    const avatar = document.querySelector('header [data-testid="default-user"]')?.getAttribute("aria-label")
    return { id: avatar || "whatsapp-web", name: avatar || "WhatsApp Web" }
  }

  getCurrentConversation() {
    const header = document.querySelector("#main header")
    const displayName = header?.querySelector("[title]")?.getAttribute("title") ||
      header?.querySelector("span[dir='auto']")?.textContent?.trim()
    if (!displayName) return null
    const native = document.querySelector("#main [data-id]")?.getAttribute("data-id")?.split("_")?.[1]
    return { id: this.stableConversationId(native || displayName), displayName }
  }

  findMessageContainer() {
    return document.querySelector("#main [role='application']") ||
      document.querySelector("#main div[tabindex='-1']")
  }

  parseVisibleMessages() {
    const nodes = this.findMessageContainer()?.querySelectorAll("[data-id], .message-in, .message-out") || []
    return [...new Set(nodes)].map(node => this.parseMessage(node)).filter(Boolean)
  }

  parseMessage(node) {
    const root = node.matches(".message-in,.message-out") ? node : node.closest(".message-in,.message-out") || node
    const text = [...root.querySelectorAll(".selectable-text span, [data-testid='conversation-text']")]
      .map(element => element.textContent).join(" ").trim()
    const attachment = root.querySelector("[data-testid*='document'], [data-testid*='image'], [data-testid*='audio']")
    if (!text && !attachment) return null
    const pre = root.querySelector("[data-pre-plain-text]")?.getAttribute("data-pre-plain-text") || ""
    const sender = pre.match(/\]\s*([^:]+):/)?.[1]
    const visibleTime = pre.match(/\[([^\]]+)\]/)?.[1]
    const testId = attachment?.getAttribute("data-testid") || ""
    return {
      platformMessageId: root.getAttribute("data-id") || node.getAttribute("data-id"),
      direction: root.classList.contains("message-out") ? "sales" : root.classList.contains("message-in") ? "customer" : "unknown",
      senderName: sender, sentAt: parseVisibleTime(visibleTime), type: inferType(testId, text),
      text, quotedText: root.querySelector("[data-testid='quoted-message']")?.textContent?.trim(),
      attachmentName: root.querySelector("[title][download], [data-testid*='document'] [title]")?.getAttribute("title"),
      sourceMetadata: { visibleTimestamp: visibleTime, adapter: "whatsapp-v1" },
      parserVersion: "whatsapp-v1"
    }
  }
}

function inferType(testId, text) {
  if (/audio|ptt/.test(testId)) return "audio"
  if (/image|media/.test(testId)) return "image"
  if (/document/.test(testId)) return "file"
  return text ? "text" : "unknown"
}

function parseVisibleTime(value) {
  if (!value) return null
  const date = new Date(value)
  return Number.isNaN(date.valueOf()) ? null : date.toISOString()
}
