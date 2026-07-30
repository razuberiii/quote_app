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
    const title = header?.querySelector(
      "[data-testid='conversation-info-header-chat-title'], " +
      "[data-testid='conversation-info-header'] span[dir='auto'][title], " +
      "div[role='button'] span[dir='auto'][title], " +
      "span[dir='auto'][title]"
    )
    const displayName = title?.getAttribute("title") || title?.textContent?.trim() ||
      header?.querySelector("span[dir='auto']")?.textContent?.trim()
    if (!displayName) return null
    const native = document.querySelector("#main [data-id]")?.getAttribute("data-id")?.split("_")?.[1]
    return { id: this.stableConversationId(native || displayName), displayName }
  }

  findMessageContainer() {
    return document.querySelector("#main")
  }

  parseVisibleMessages() {
    const nodes = document.querySelectorAll(
      "#main [data-pre-plain-text], #main [data-id], #main .message-in, #main .message-out, " +
      "#main [data-testid*='document'], #main [data-testid*='image'], #main [data-testid*='audio']"
    )
    const roots = [...nodes]
      .map(node => node.closest(".message-in,.message-out,[data-testid='msg-container']") ||
        node.closest("[data-id]") || node.parentElement || node)
      .filter(node => node.querySelector("[data-pre-plain-text], .selectable-text, [data-testid*='document'], [data-testid*='image'], [data-testid*='audio']"))
    return [...new Set(roots)].map(node => this.parseMessage(node)).filter(Boolean)
  }

  parseMessage(node) {
    const root = node.matches(".message-in,.message-out") ? node : node.closest(".message-in,.message-out") || node
    const text = [...root.querySelectorAll(".selectable-text span, [data-testid='conversation-text']")]
      .map(element => element.textContent).join(" ").trim()
    const attachment = root.querySelector("[data-testid*='document'], [data-testid*='image'], [data-testid*='audio']")
    if (!text && !attachment) return null
    const dataId = root.getAttribute("data-id") || root.querySelector("[data-id]")?.getAttribute("data-id") || ""
    const direction = inferDirection(root, dataId)
    const pre = root.querySelector("[data-pre-plain-text]")?.getAttribute("data-pre-plain-text") || ""
    const sender = pre.match(/\]\s*([^:]+):/)?.[1]
    const visibleTime = pre.match(/\[([^\]]+)\]/)?.[1]
    const testId = attachment?.getAttribute("data-testid") || ""
    return {
      platformMessageId: dataId || null,
      direction,
      senderName: sender, sentAt: parseVisibleTime(visibleTime), type: inferType(testId, text),
      text, quotedText: root.querySelector("[data-testid='quoted-message']")?.textContent?.trim(),
      attachmentName: root.querySelector("[title][download], [data-testid*='document'] [title]")?.getAttribute("title"),
      sourceMetadata: { visibleTimestamp: visibleTime, adapter: "whatsapp-v2" },
      parserVersion: "whatsapp-v2"
    }
  }
}

function inferDirection(root, dataId) {
  const directionHost = root.closest(".message-in,.message-out") ||
    root.querySelector(".message-in,.message-out")
  if (directionHost?.classList.contains("message-out") || dataId.startsWith("true_")) return "sales"
  if (directionHost?.classList.contains("message-in") || dataId.startsWith("false_")) return "customer"

  const sentMarker = root.querySelector(
    "[data-icon='msg-check'], [data-icon='msg-dblcheck'], " +
    "[data-testid='msg-check'], [data-testid='msg-dblcheck']"
  )
  if (sentMarker) return "sales"

  const main = document.querySelector("#main")
  const bubbleRect = root.getBoundingClientRect()
  const mainRect = main?.getBoundingClientRect()
  if (bubbleRect.width && mainRect?.width) {
    const bubbleCenter = bubbleRect.left + bubbleRect.width / 2
    const mainCenter = mainRect.left + mainRect.width / 2
    return bubbleCenter > mainCenter ? "sales" : "customer"
  }
  return "unknown"
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
