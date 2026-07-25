export class Deduplicator {
  constructor(runtime, namespace) {
    this.runtime = runtime
    this.key = `dedupe:${namespace}`
    this.seen = new Set()
  }

  async load() {
    this.seen = new Set(await this.runtime.storage.get(this.key, []))
  }

  has(message) {
    return this.seen.has(message.rawFingerprint)
  }

  async remember(messages) {
    messages.forEach(message => this.seen.add(message.rawFingerprint))
    const retained = [...this.seen].slice(-5000)
    this.seen = new Set(retained)
    await this.runtime.storage.set(this.key, retained)
  }
}
