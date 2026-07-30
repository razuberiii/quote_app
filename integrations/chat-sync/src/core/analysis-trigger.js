export class AnalysisTrigger {
  constructor({ api, queue, binding, config, onResult }) {
    this.api = api
    this.queue = queue
    this.binding = binding
    this.config = config
    this.onResult = onResult
    this.newCount = 0
    this.lastCursorKey = `analysis:${binding.id}`
    this.timer = null
    this.running = null
  }

  note(messages) {
    if (!this.binding.autoAnalysis) return
    this.newCount += messages.length
    clearTimeout(this.timer)
    const important = messages.some(message => this.config.importantTerms.test(message.text || ""))
    if (important || this.newCount >= this.config.autoAnalysisMessageThreshold) this.timer = setTimeout(() => this.run(), 2500)
    else this.timer = setTimeout(() => this.run(), this.config.autoAnalysisIdleMs)
  }

  async run() {
    if (this.running) return this.running
    this.running = this.performRun().finally(() => { this.running = null })
    return this.running
  }

  async performRun() {
    await this.queue.flush()
    await this.api.analyze(this.binding.id)
    this.newCount = 0
    return this.poll()
  }

  async poll() {
    for (let attempt = 0; attempt < 60; attempt += 1) {
      const payload = await this.api.analysis(this.binding.id)
      if (["complete", "failed"].includes(payload.status)) {
        this.onResult?.(payload.result)
        return payload.result
      }
      await new Promise(resolve => setTimeout(resolve, 2000))
    }
    throw new Error("analysis_timeout")
  }

  dispose() {
    clearTimeout(this.timer)
  }
}
