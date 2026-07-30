export const CONFIG = Object.freeze({
  apiBase: "https://quote.rubusoo.com/api/chat_sync",
  appBase: "https://quote.rubusoo.com",
  batchSize: 25,
  flushDelayMs: 1800,
  maxQueueSize: 3000,
  retryBaseMs: 2000,
  retryMaxMs: 120000,
  autoAnalysisIdleMs: 15 * 60 * 1000,
  autoAnalysisMessageThreshold: 8,
  importantTerms: /(?:quote|quotation|price|qty|quantity|delivery|lead time|incoterm|报价|价格|数量|交期|运费)/i
})
