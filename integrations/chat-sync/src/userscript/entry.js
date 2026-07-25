import { CONFIG } from "../core/config.js"
import { ApiClient } from "../core/api-client.js"
import { Collector } from "../core/collector.js"
import { Deduplicator } from "../core/deduplicator.js"
import { UploadQueue } from "../core/upload-queue.js"
import { AnalysisTrigger } from "../core/analysis-trigger.js"
import { WhatsAppAdapter } from "../adapters/whatsapp.js"
import { AlibabaAdapter } from "../adapters/alibaba.js"
import { TampermonkeyRuntime } from "../runtime/tampermonkey-runtime.js"
import { FloatingPanel } from "../ui/floating-panel.js"

const runtime = new TampermonkeyRuntime()
const adapter = [new WhatsAppAdapter(), new AlibabaAdapter()].find(candidate => candidate.isSupportedPage())
if (adapter) start().catch(error => console.warn("[Rubusoo] startup failed", error.message))

async function start() {
  const api = new ApiClient(runtime, CONFIG.apiBase)
  const panel = new FloatingPanel({ runtime, platform: adapter.getPlatform() })
  let active = null
  let lastConversationId = null
  panel.setHandlers({
    consent: async () => { await runtime.storage.set(`consent:${adapter.getPlatform()}:${location.hostname}`, true); await refresh() },
    "open-setup": async () => runtime.openApp("/chat_integration"),
    pair: async ({ code }) => {
      try {
        const result = await api.pair(code)
        await runtime.auth.setToken(result.token)
        panel.update({ error: null })
        await refresh()
      } catch { panel.update({ error: "绑定码无效或已过期" }) }
    },
    bind: async values => {
      try {
        const conversation = adapter.getCurrentConversation()
        const account = adapter.getCurrentAccount()
        const result = await api.bind({
          platform: adapter.getPlatform(), platformAccountId: account.id,
          platformConversationId: conversation.id, displayName: conversation.displayName,
          inquiryId: values.inquiry || null, customerId: values.customer || null,
          newCustomerName: values.customerName || null
        })
        await activate(result.binding, conversation)
      } catch { panel.update({ error: "无法绑定此会话，请检查客户或询盘选择" }) }
    },
    analyze: async () => {
      panel.update({ error: null, sync: { ...panel.state.sync, state: "syncing" } })
      try { await active.analysis.run() } catch { panel.update({ error: "分析尚未完成，请稍后重试" }) }
    },
    "open-inquiry": async () => runtime.openApp(`/inquiries/${active.binding.inquiryId}`),
    pause: async () => {
      const result = await api.updateBinding(active.binding.id, { paused: !active.binding.paused })
      active.binding = result.binding
      panel.update({ binding: active.binding })
      if (active.binding.paused) active.collector.dispose(); else await refresh(true)
    },
    unbind: async () => { await api.unbind(active.binding.id); disposeActive(); await refresh(true) }
  })

  async function refresh(force = false) {
    const consent = await runtime.storage.get(`consent:${adapter.getPlatform()}:${location.hostname}`, false)
    if (!consent) return panel.update({ mode: "consent" })
    if (!await runtime.auth.getToken()) return panel.update({ mode: "pair" })
    const conversation = adapter.getCurrentConversation()
    if (!conversation) return panel.update({ mode: "no-conversation" })
    if (!force && conversation.id === lastConversationId && active) return
    disposeActive()
    lastConversationId = conversation.id
    const account = adapter.getCurrentAccount()
    try {
      const context = await api.context({
        platform: adapter.getPlatform(), platformAccountId: account.id,
        platformConversationId: conversation.id
      })
      if (context.binding) await activate(context.binding, conversation)
      else panel.update({ mode: "binding", conversation, context, error: null })
    } catch (error) {
      if (error.status === 401) { await runtime.auth.clearToken(); panel.update({ mode: "pair" }) }
      else panel.update({ mode: "binding", conversation, context: {}, error: "无法连接 Rubusoo" })
    }
  }

  async function activate(binding, conversation) {
    const account = adapter.getCurrentAccount()
    const queue = new UploadQueue({
      runtime, api, binding, config: CONFIG,
      onStatus: sync => panel.update({ sync })
    })
    const deduplicator = new Deduplicator(runtime, `${binding.id}`)
    const analysis = new AnalysisTrigger({
      api, queue, binding, config: CONFIG,
      onResult: result => panel.update({ analysis: result })
    })
    const collector = new Collector({
      adapter, deduplicator, queue, analysis,
      context: {
        platform: adapter.getPlatform(), platformAccountId: account.id,
        platformConversationId: conversation.id
      },
      onMessages: messages => analysis.note(messages)
    })
    active = { binding, queue, analysis, collector }
    panel.update({ mode: "bound", binding, conversation, analysis: binding.analysisResult || null, error: null })
    if (!binding.paused) await collector.start()
  }

  function disposeActive() {
    active?.collector?.dispose()
    active?.analysis?.dispose()
    active = null
  }

  await refresh()
  setInterval(() => refresh(), 1200)
  addEventListener("pagehide", () => active?.queue?.persist())
}
