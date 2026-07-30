import { normalizeMessage } from "./message-normalizer.js"

export class Collector {
  constructor({ adapter, context, deduplicator, queue, onMessages }) {
    this.adapter = adapter
    this.context = context
    this.deduplicator = deduplicator
    this.queue = queue
    this.onMessages = onMessages
    this.disposed = false
    this.poller = null
  }

  async start() {
    await this.deduplicator.load()
    await this.queue.load()
    await this.collect()
    this.adapter.observeConversationChanges(() => this.collect())
    this.poller = setInterval(() => this.collect(), 2500)
  }

  async collect() {
    if (this.disposed) return
    const rawMessages = this.adapter.parseVisibleMessages()
    const normalized = await Promise.all(rawMessages.map(raw => normalizeMessage(raw, this.context)))
    const fresh = normalized.filter(message => !this.deduplicator.has(message))
    if (!fresh.length) return
    await this.queue.push(fresh)
    await this.deduplicator.remember(fresh)
    this.onMessages?.(fresh)
  }

  dispose() {
    this.disposed = true
    clearInterval(this.poller)
    this.queue.dispose()
    this.adapter.dispose()
  }
}
