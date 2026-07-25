const TYPES = new Set(["text", "image", "file", "audio", "system", "product", "unknown"])
const DIRECTIONS = new Set(["customer", "sales", "unknown"])

export async function normalizeMessage(raw, context) {
  const message = {
    localId: raw.localId || crypto.randomUUID(),
    platform: context.platform,
    platformAccountId: context.platformAccountId,
    platformConversationId: context.platformConversationId,
    platformMessageId: clean(raw.platformMessageId),
    direction: DIRECTIONS.has(raw.direction) ? raw.direction : "unknown",
    senderId: clean(raw.senderId),
    senderName: clean(raw.senderName),
    sentAt: normalizeTime(raw.sentAt),
    capturedAt: new Date().toISOString(),
    type: TYPES.has(raw.type) ? raw.type : "unknown",
    text: clean(raw.text, 50000),
    quotedText: clean(raw.quotedText, 10000),
    attachmentName: clean(raw.attachmentName, 500),
    sourceMetadata: sanitizeMetadata(raw.sourceMetadata),
    parserVersion: raw.parserVersion || "unknown"
  }
  message.rawFingerprint = await fingerprint(message)
  return message
}

function clean(value, limit = 255) {
  const result = String(value || "").replace(/\s+/g, " ").trim()
  return result ? result.slice(0, limit) : null
}

function normalizeTime(value) {
  const date = value ? new Date(value) : null
  return date && !Number.isNaN(date.valueOf()) ? date.toISOString() : null
}

function sanitizeMetadata(metadata = {}) {
  return Object.fromEntries(Object.entries(metadata)
    .filter(([key]) => ["visibleTimestamp", "deliveryState", "productId", "adapter"].includes(key))
    .map(([key, value]) => [key, clean(value, 500)]))
}

async function fingerprint(message) {
  const source = message.platformMessageId
    ? `native\u241f${message.platform}\u241f${message.platformMessageId}`
    : [
        message.platform, message.platformConversationId, message.senderId || message.senderName,
        message.sentAt, message.text, message.type, message.quotedText
      ].join("\u241f")
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(source))
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("")
}
