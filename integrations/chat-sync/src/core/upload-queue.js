export class UploadQueue {
  constructor({ runtime, api, binding, config, onStatus }) {
    this.runtime = runtime
    this.api = api
    this.binding = binding
    this.config = config
    this.onStatus = onStatus
    this.key = `queue:${binding.id}`
    this.messages = []
    this.timer = null
    this.retryCount = 0
    this.flushing = null
    this.uploadedCount = Number(binding.messageCount || 0)
  }

  async load() {
    this.messages = await this.runtime.storage.get(this.key, [])
    this.report()
    if (this.messages.length) this.schedule()
  }

  async push(messages) {
    const known = new Set(this.messages.map(message => message.rawFingerprint))
    for (const message of messages) if (!known.has(message.rawFingerprint)) this.messages.push(message)
    this.messages = this.messages.slice(-this.config.maxQueueSize)
    await this.persist()
    this.report()
    if (this.messages.length >= this.config.batchSize) await this.flush()
    else this.schedule()
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.flush(), this.config.flushDelayMs)
  }

  async flush() {
    if (this.flushing) return this.flushing
    if (!this.messages.length) return
    this.flushing = this.performFlush().finally(() => { this.flushing = null })
    return this.flushing
  }

  async performFlush() {
    const batch = this.messages.slice(0, this.config.batchSize)
    const requestId = crypto.randomUUID()
    this.onStatus?.({ state: "syncing", pending: this.messages.length, uploaded: this.uploadedCount })
    try {
      const receipt = await this.api.upload(this.binding.id, { requestId, messages: batch })
      this.messages.splice(0, batch.length)
      this.uploadedCount = Number(receipt.messageCount ?? (this.uploadedCount + Number(receipt.acceptedCount || 0)))
      this.retryCount = 0
      await this.persist()
      this.report("synced")
      if (this.messages.length) this.schedule()
    } catch (error) {
      this.retryCount += 1
      const delay = Math.min(this.config.retryBaseMs * 2 ** (this.retryCount - 1), this.config.retryMaxMs)
      this.report("error", error.message)
      clearTimeout(this.timer)
      this.timer = setTimeout(() => this.flush(), delay)
    }
  }

  async persist() {
    await this.runtime.storage.set(this.key, this.messages)
  }

  report(state = "idle", error = null) {
    this.onStatus?.({ state, pending: this.messages.length, uploaded: this.uploadedCount, error })
  }

  dispose() {
    clearTimeout(this.timer)
  }
}
