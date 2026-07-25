// ==UserScript==
// @name         Rubusoo Chat Sync
// @namespace    https://next.rubusoo.com/
// @version      0.1.0
// @description  Sync explicitly bound WhatsApp Web and Alibaba conversations to Rubusoo.
// @match        https://web.whatsapp.com/*
// @match        https://*.alibaba.com/*
// @connect      next.rubusoo.com
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_deleteValue
// @grant        GM_xmlhttpRequest
// @grant        GM_openInTab
// @grant        GM_notification
// @run-at       document-idle
// ==/UserScript==

(() => {
  // integrations/chat-sync/src/core/config.js
  var CONFIG = Object.freeze({
    apiBase: "https://next.rubusoo.com/api/chat_sync",
    appBase: "https://next.rubusoo.com",
    batchSize: 25,
    flushDelayMs: 1800,
    maxQueueSize: 3e3,
    retryBaseMs: 2e3,
    retryMaxMs: 12e4,
    autoAnalysisIdleMs: 15 * 60 * 1e3,
    autoAnalysisMessageThreshold: 8,
    importantTerms: /(?:quote|quotation|price|qty|quantity|delivery|lead time|incoterm|报价|价格|数量|交期|运费)/i
  });

  // integrations/chat-sync/src/core/api-client.js
  var ApiClient = class {
    constructor(runtime2, apiBase) {
      this.runtime = runtime2;
      this.apiBase = apiBase;
    }
    async pair(code) {
      return this.request("/pair", { method: "POST", body: { code, label: `${navigator.userAgent.slice(0, 60)}` }, authenticated: false });
    }
    context(context) {
      const query = new URLSearchParams(context);
      return this.request(`/context?${query}`);
    }
    bind(payload) {
      return this.request("/bindings", { method: "POST", body: payload });
    }
    updateBinding(id, payload) {
      return this.request(`/bindings/${id}`, { method: "PATCH", body: payload });
    }
    unbind(id) {
      return this.request(`/bindings/${id}`, { method: "DELETE" });
    }
    upload(bindingId, payload) {
      return this.request(`/bindings/${bindingId}/messages`, { method: "POST", body: payload });
    }
    analyze(bindingId) {
      return this.request(`/bindings/${bindingId}/analysis`, { method: "POST", body: {} });
    }
    analysis(bindingId) {
      return this.request(`/bindings/${bindingId}/analysis`);
    }
    async request(path, options = {}) {
      const token = options.authenticated === false ? null : await this.runtime.auth.getToken();
      const response = await this.runtime.http.request({
        url: `${this.apiBase}${path}`,
        method: options.method || "GET",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...token ? { Authorization: `Bearer ${token}` } : {}
        },
        body: options.body ? JSON.stringify(options.body) : null
      });
      if (response.status < 200 || response.status >= 300) {
        const error = new Error(`api_${response.status}`);
        error.status = response.status;
        error.payload = response.json;
        throw error;
      }
      return response.json || {};
    }
  };

  // integrations/chat-sync/src/core/message-normalizer.js
  var TYPES = /* @__PURE__ */ new Set(["text", "image", "file", "audio", "system", "product", "unknown"]);
  var DIRECTIONS = /* @__PURE__ */ new Set(["customer", "sales", "unknown"]);
  async function normalizeMessage(raw, context) {
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
      capturedAt: (/* @__PURE__ */ new Date()).toISOString(),
      type: TYPES.has(raw.type) ? raw.type : "unknown",
      text: clean(raw.text, 5e4),
      quotedText: clean(raw.quotedText, 1e4),
      attachmentName: clean(raw.attachmentName, 500),
      sourceMetadata: sanitizeMetadata(raw.sourceMetadata),
      parserVersion: raw.parserVersion || "unknown"
    };
    message.rawFingerprint = await fingerprint(message);
    return message;
  }
  function clean(value, limit = 255) {
    const result = String(value || "").replace(/\s+/g, " ").trim();
    return result ? result.slice(0, limit) : null;
  }
  function normalizeTime(value) {
    const date = value ? new Date(value) : null;
    return date && !Number.isNaN(date.valueOf()) ? date.toISOString() : null;
  }
  function sanitizeMetadata(metadata = {}) {
    return Object.fromEntries(Object.entries(metadata).filter(([key]) => ["visibleTimestamp", "deliveryState", "productId", "adapter"].includes(key)).map(([key, value]) => [key, clean(value, 500)]));
  }
  async function fingerprint(message) {
    const source = message.platformMessageId ? `native\u241F${message.platform}\u241F${message.platformMessageId}` : [
      message.platform,
      message.platformConversationId,
      message.senderId || message.senderName,
      message.sentAt,
      message.text,
      message.type,
      message.quotedText
    ].join("\u241F");
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(source));
    return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  }

  // integrations/chat-sync/src/core/collector.js
  var Collector = class {
    constructor({ adapter: adapter2, context, deduplicator, queue, onMessages }) {
      this.adapter = adapter2;
      this.context = context;
      this.deduplicator = deduplicator;
      this.queue = queue;
      this.onMessages = onMessages;
      this.disposed = false;
    }
    async start() {
      await this.deduplicator.load();
      await this.queue.load();
      await this.collect();
      this.adapter.observeConversationChanges(() => this.collect());
    }
    async collect() {
      if (this.disposed) return;
      const rawMessages = this.adapter.parseVisibleMessages();
      const normalized = await Promise.all(rawMessages.map((raw) => normalizeMessage(raw, this.context)));
      const fresh = normalized.filter((message) => !this.deduplicator.has(message));
      if (!fresh.length) return;
      await this.queue.push(fresh);
      await this.deduplicator.remember(fresh);
      this.onMessages?.(fresh);
    }
    dispose() {
      this.disposed = true;
      this.queue.dispose();
      this.adapter.dispose();
    }
  };

  // integrations/chat-sync/src/core/deduplicator.js
  var Deduplicator = class {
    constructor(runtime2, namespace) {
      this.runtime = runtime2;
      this.key = `dedupe:${namespace}`;
      this.seen = /* @__PURE__ */ new Set();
    }
    async load() {
      this.seen = new Set(await this.runtime.storage.get(this.key, []));
    }
    has(message) {
      return this.seen.has(message.rawFingerprint);
    }
    async remember(messages) {
      messages.forEach((message) => this.seen.add(message.rawFingerprint));
      const retained = [...this.seen].slice(-5e3);
      this.seen = new Set(retained);
      await this.runtime.storage.set(this.key, retained);
    }
  };

  // integrations/chat-sync/src/core/upload-queue.js
  var UploadQueue = class {
    constructor({ runtime: runtime2, api, binding, config, onStatus }) {
      this.runtime = runtime2;
      this.api = api;
      this.binding = binding;
      this.config = config;
      this.onStatus = onStatus;
      this.key = `queue:${binding.id}`;
      this.messages = [];
      this.timer = null;
      this.retryCount = 0;
      this.flushing = null;
    }
    async load() {
      this.messages = await this.runtime.storage.get(this.key, []);
      this.report();
      if (this.messages.length) this.schedule();
    }
    async push(messages) {
      const known = new Set(this.messages.map((message) => message.rawFingerprint));
      for (const message of messages) if (!known.has(message.rawFingerprint)) this.messages.push(message);
      this.messages = this.messages.slice(-this.config.maxQueueSize);
      await this.persist();
      this.report();
      if (this.messages.length >= this.config.batchSize) await this.flush();
      else this.schedule();
    }
    schedule() {
      clearTimeout(this.timer);
      this.timer = setTimeout(() => this.flush(), this.config.flushDelayMs);
    }
    async flush() {
      if (this.flushing) return this.flushing;
      if (!this.messages.length) return;
      this.flushing = this.performFlush().finally(() => {
        this.flushing = null;
      });
      return this.flushing;
    }
    async performFlush() {
      const batch = this.messages.slice(0, this.config.batchSize);
      const requestId = crypto.randomUUID();
      this.onStatus?.({ state: "syncing", pending: this.messages.length });
      try {
        await this.api.upload(this.binding.id, { requestId, messages: batch });
        this.messages.splice(0, batch.length);
        this.retryCount = 0;
        await this.persist();
        this.report("synced");
        if (this.messages.length) this.schedule();
      } catch (error) {
        this.retryCount += 1;
        const delay = Math.min(this.config.retryBaseMs * 2 ** (this.retryCount - 1), this.config.retryMaxMs);
        this.report("error", error.message);
        clearTimeout(this.timer);
        this.timer = setTimeout(() => this.flush(), delay);
      }
    }
    async persist() {
      await this.runtime.storage.set(this.key, this.messages);
    }
    report(state = "idle", error = null) {
      this.onStatus?.({ state, pending: this.messages.length, error });
    }
    dispose() {
      clearTimeout(this.timer);
    }
  };

  // integrations/chat-sync/src/core/analysis-trigger.js
  var AnalysisTrigger = class {
    constructor({ api, queue, binding, config, onResult }) {
      this.api = api;
      this.queue = queue;
      this.binding = binding;
      this.config = config;
      this.onResult = onResult;
      this.newCount = 0;
      this.lastCursorKey = `analysis:${binding.id}`;
      this.timer = null;
    }
    note(messages) {
      if (!this.binding.autoAnalysis) return;
      this.newCount += messages.length;
      clearTimeout(this.timer);
      const important = messages.some((message) => this.config.importantTerms.test(message.text || ""));
      if (important || this.newCount >= this.config.autoAnalysisMessageThreshold) this.timer = setTimeout(() => this.run(), 2500);
      else this.timer = setTimeout(() => this.run(), this.config.autoAnalysisIdleMs);
    }
    async run() {
      await this.queue.flush();
      await this.api.analyze(this.binding.id);
      this.newCount = 0;
      await this.poll();
    }
    async poll() {
      for (let attempt = 0; attempt < 60; attempt += 1) {
        const payload = await this.api.analysis(this.binding.id);
        if (["complete", "failed"].includes(payload.status)) {
          this.onResult?.(payload.result);
          return payload.result;
        }
        await new Promise((resolve) => setTimeout(resolve, 2e3));
      }
      throw new Error("analysis_timeout");
    }
    dispose() {
      clearTimeout(this.timer);
    }
  };

  // integrations/chat-sync/src/adapters/base-adapter.js
  var BaseAdapter = class {
    observer = null;
    isSupportedPage() {
      return false;
    }
    getPlatform() {
      return "generic";
    }
    getCurrentAccount() {
      return { id: location.hostname, name: location.hostname };
    }
    getCurrentConversation() {
      return null;
    }
    findMessageContainer() {
      return null;
    }
    parseVisibleMessages() {
      return [];
    }
    getConversationDisplayName() {
      return this.getCurrentConversation()?.displayName || "";
    }
    observeConversationChanges(callback) {
      const container = this.findMessageContainer();
      if (!container) return;
      this.observer?.disconnect();
      this.observer = new MutationObserver(() => callback());
      this.observer.observe(container, { childList: true, subtree: true });
    }
    dispose() {
      this.observer?.disconnect();
      this.observer = null;
    }
    stableConversationId(value) {
      return `${this.getPlatform()}:${String(value || "").trim().toLowerCase().replace(/\s+/g, "-").slice(0, 180)}`;
    }
  };

  // integrations/chat-sync/src/adapters/whatsapp.js
  var WhatsAppAdapter = class extends BaseAdapter {
    getPlatform() {
      return "whatsapp";
    }
    isSupportedPage() {
      return location.hostname === "web.whatsapp.com";
    }
    getCurrentAccount() {
      const avatar = document.querySelector('header [data-testid="default-user"]')?.getAttribute("aria-label");
      return { id: avatar || "whatsapp-web", name: avatar || "WhatsApp Web" };
    }
    getCurrentConversation() {
      const header = document.querySelector("#main header");
      const displayName = header?.querySelector("[title]")?.getAttribute("title") || header?.querySelector("span[dir='auto']")?.textContent?.trim();
      if (!displayName) return null;
      const native = document.querySelector("#main [data-id]")?.getAttribute("data-id")?.split("_")?.[1];
      return { id: this.stableConversationId(native || displayName), displayName };
    }
    findMessageContainer() {
      return document.querySelector("#main [role='application']") || document.querySelector("#main div[tabindex='-1']");
    }
    parseVisibleMessages() {
      const nodes = this.findMessageContainer()?.querySelectorAll("[data-id], .message-in, .message-out") || [];
      return [...new Set(nodes)].map((node) => this.parseMessage(node)).filter(Boolean);
    }
    parseMessage(node) {
      const root = node.matches(".message-in,.message-out") ? node : node.closest(".message-in,.message-out") || node;
      const text = [...root.querySelectorAll(".selectable-text span, [data-testid='conversation-text']")].map((element) => element.textContent).join(" ").trim();
      const attachment = root.querySelector("[data-testid*='document'], [data-testid*='image'], [data-testid*='audio']");
      if (!text && !attachment) return null;
      const pre = root.querySelector("[data-pre-plain-text]")?.getAttribute("data-pre-plain-text") || "";
      const sender = pre.match(/\]\s*([^:]+):/)?.[1];
      const visibleTime = pre.match(/\[([^\]]+)\]/)?.[1];
      const testId = attachment?.getAttribute("data-testid") || "";
      return {
        platformMessageId: root.getAttribute("data-id") || node.getAttribute("data-id"),
        direction: root.classList.contains("message-out") ? "sales" : root.classList.contains("message-in") ? "customer" : "unknown",
        senderName: sender,
        sentAt: parseVisibleTime(visibleTime),
        type: inferType(testId, text),
        text,
        quotedText: root.querySelector("[data-testid='quoted-message']")?.textContent?.trim(),
        attachmentName: root.querySelector("[title][download], [data-testid*='document'] [title]")?.getAttribute("title"),
        sourceMetadata: { visibleTimestamp: visibleTime, adapter: "whatsapp-v1" },
        parserVersion: "whatsapp-v1"
      };
    }
  };
  function inferType(testId, text) {
    if (/audio|ptt/.test(testId)) return "audio";
    if (/image|media/.test(testId)) return "image";
    if (/document/.test(testId)) return "file";
    return text ? "text" : "unknown";
  }
  function parseVisibleTime(value) {
    if (!value) return null;
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? null : date.toISOString();
  }

  // integrations/chat-sync/src/adapters/alibaba.js
  var AlibabaAdapter = class extends BaseAdapter {
    getPlatform() {
      return "alibaba";
    }
    isSupportedPage() {
      return /(^|\.)alibaba\.com$/.test(location.hostname) && /message|inquiry|chat|contact/i.test(location.href);
    }
    getCurrentAccount() {
      const id = document.querySelector("[data-account-id]")?.getAttribute("data-account-id") || "alibaba-web";
      return { id, name: "Alibaba.com" };
    }
    getCurrentConversation() {
      const selected = document.querySelector("[data-conversation-id][aria-selected='true'], [data-conversation-id].active");
      const header = document.querySelector("[class*='conversation'] [class*='header'], [class*='chat'] [class*='header']");
      const displayName = selected?.getAttribute("title") || header?.querySelector("[title]")?.getAttribute("title") || header?.textContent?.trim().slice(0, 160);
      const id = selected?.getAttribute("data-conversation-id") || selected?.dataset?.conversationId;
      if (!displayName && !id) return null;
      return { id: this.stableConversationId(id || displayName), displayName: displayName || id };
    }
    findMessageContainer() {
      return document.querySelector("[data-testid='message-list'], [class*='message-list'], [class*='messageList'], [class*='conversation-content']");
    }
    parseVisibleMessages() {
      const container = this.findMessageContainer();
      if (!container) return [];
      const nodes = container.querySelectorAll("[data-message-id], [class*='message-item'], [class*='messageItem']");
      return [...new Set(nodes)].map((node) => this.parseMessage(node)).filter(Boolean);
    }
    parseMessage(node) {
      const textNode = node.querySelector("[class*='text'], [class*='content'], [data-testid='message-text']");
      const text = textNode?.textContent?.trim();
      const attachment = node.querySelector("a[download], [class*='attachment'], [class*='file']");
      if (!text && !attachment) return null;
      const own = node.matches("[class*='self'],[class*='right'],[data-sender='self']") || node.querySelector("[class*='self'],[data-sender='self']");
      const timeText = node.querySelector("time, [class*='time']")?.textContent?.trim();
      return {
        platformMessageId: node.getAttribute("data-message-id") || node.dataset?.messageId,
        direction: own ? "sales" : "customer",
        senderName: node.querySelector("[class*='sender'],[class*='name']")?.textContent?.trim(),
        sentAt: parseTime(timeText),
        type: attachment ? "file" : "text",
        text,
        attachmentName: attachment?.getAttribute("download") || attachment?.textContent?.trim(),
        sourceMetadata: { visibleTimestamp: timeText, adapter: "alibaba-v1" },
        parserVersion: "alibaba-v1"
      };
    }
  };
  function parseTime(value) {
    if (!value) return null;
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? null : date.toISOString();
  }

  // integrations/chat-sync/src/runtime/tampermonkey-runtime.js
  var TampermonkeyRuntime = class {
    storage = {
      get: async (key, fallback = null) => GM_getValue(key, fallback),
      set: async (key, value) => GM_setValue(key, value),
      remove: async (key) => GM_deleteValue(key)
    };
    auth = {
      getToken: async () => this.storage.get("auth:token"),
      setToken: async (token) => this.storage.set("auth:token", token),
      clearToken: async () => this.storage.remove("auth:token")
    };
    http = {
      request: (options) => new Promise((resolve, reject) => {
        GM_xmlhttpRequest({
          method: options.method,
          url: options.url,
          headers: options.headers,
          data: options.body,
          timeout: 12e4,
          onload: (response) => {
            let json = null;
            try {
              json = response.responseText ? JSON.parse(response.responseText) : null;
            } catch {
            }
            resolve({ status: response.status, json, text: response.responseText });
          },
          ontimeout: () => reject(new Error("request_timeout")),
          onerror: () => reject(new Error("network_error"))
        });
      })
    };
    openApp(path = "") {
      GM_openInTab(`https://next.rubusoo.com${path}`, { active: true });
    }
    notify(text) {
      GM_notification({ title: "Rubusoo", text, timeout: 5e3 });
    }
  };

  // integrations/chat-sync/src/ui/floating-panel.js
  var FloatingPanel = class {
    constructor({ runtime: runtime2, platform }) {
      this.runtime = runtime2;
      this.platform = platform;
      this.host = document.createElement("div");
      this.host.id = "rubusoo-chat-sync";
      this.shadow = this.host.attachShadow({ mode: "closed" });
      document.documentElement.appendChild(this.host);
      this.state = { mode: "loading", collapsed: false, sync: {}, analysis: null };
    }
    setHandlers(handlers) {
      this.handlers = handlers;
    }
    update(patch) {
      this.state = { ...this.state, ...patch };
      this.render();
    }
    render() {
      const state = this.state;
      this.shadow.innerHTML = `<style>${styles}</style><aside class="${state.collapsed ? "collapsed" : ""}">
      <header><b><i>R/</i> Rubusoo</b><button data-action="collapse">${state.collapsed ? "\uFF0B" : "\u2014"}</button></header>
      ${state.collapsed ? `<div class="compact"><span class="dot ${state.sync.state || ""}"></span><strong>${state.sync.pending || 0}</strong></div>` : this.body()}
    </aside>`;
      this.shadow.querySelectorAll("[data-action]").forEach((element) => element.addEventListener("click", (event) => this.handle(event)));
    }
    body() {
      const state = this.state;
      if (state.mode === "consent") return `<main><h3>\u542F\u7528 ${escapeHtml(this.platform)}</h3><p>\u53EA\u91C7\u96C6\u4F60\u4E3B\u52A8\u7ED1\u5B9A\u7684\u4F1A\u8BDD\uFF0C\u4E0D\u8BFB\u53D6\u8F93\u5165\u6846\u3001Cookie \u6216\u5176\u4ED6\u804A\u5929\u3002</p><button class="primary" data-action="consent">\u5141\u8BB8\u6B64\u7F51\u7AD9</button></main>`;
      if (state.mode === "pair") return `<main><h3>\u8FDE\u63A5 Rubusoo</h3><p>\u5728 Rubusoo \u7684\u201C\u7F51\u9875\u804A\u5929\u540C\u6B65\u201D\u9875\u9762\u751F\u6210\u4E00\u6B21\u6027\u7ED1\u5B9A\u7801\u3002</p><input data-field="code" placeholder="000-000-000"><button class="primary" data-action="pair">\u8FDE\u63A5</button><button data-action="open-setup">\u6253\u5F00\u8BBE\u7F6E\u9875\u9762</button>${this.error()}</main>`;
      if (state.mode === "no-conversation") return `<main><h3>\u7B49\u5F85\u6253\u5F00\u4F1A\u8BDD</h3><p>\u6253\u5F00\u4E00\u4E2A\u5BA2\u6237\u804A\u5929\u540E\u5373\u53EF\u7ED1\u5B9A\u3002</p></main>`;
      if (state.mode === "binding") return `<main><h3>${escapeHtml(state.conversation?.displayName || "\u5F53\u524D\u4F1A\u8BDD")}</h3><p>\u7ED1\u5B9A\u540E\u624D\u4F1A\u5F00\u59CB\u91C7\u96C6\u548C\u4E0A\u4F20\u3002</p>
      <label>\u5173\u8054\u5DF2\u6709\u8BE2\u76D8<select data-field="inquiry"><option value="">\u65B0\u5EFA\u8BE2\u76D8</option>${(state.context?.inquiries || []).map((item) => `<option value="${item.id}">${escapeHtml(item.label)}</option>`).join("")}</select></label>
      <label>\u5173\u8054\u5DF2\u6709\u5BA2\u6237<select data-field="customer"><option value="">\u4E0D\u9009\u62E9</option>${(state.context?.customers || []).map((item) => `<option value="${item.id}">${escapeHtml(item.name)}</option>`).join("")}</select></label>
      <label>\u6216\u521B\u5EFA\u5BA2\u6237<input data-field="customerName" placeholder="\u5BA2\u6237\u516C\u53F8\u540D\u79F0"></label>
      <button class="primary" data-action="bind">\u7ED1\u5B9A\u5E76\u5F00\u59CB\u540C\u6B65</button>${this.error()}</main>`;
      if (state.mode === "bound") return `<main><div class="identity"><small>${escapeHtml(this.platform)}</small><h3>${escapeHtml(state.conversation?.displayName || state.binding?.displayName)}</h3><p>\u8BE2\u76D8 #${state.binding?.inquiryId}</p></div>
      <dl><div><dt>\u5F85\u4E0A\u4F20</dt><dd>${state.sync.pending || 0}</dd></div><div><dt>\u540C\u6B65\u72B6\u6001</dt><dd>${syncLabel(state.sync.state)}</dd></div><div><dt>\u51C6\u5907\u5EA6</dt><dd>${readinessLabel(state.analysis?.readinessStatus)}</dd></div></dl>
      ${state.analysis ? analysisSummary(state.analysis) : ""}
      <button class="primary" data-action="analyze">\u7ACB\u5373\u5206\u6790</button><div class="actions"><button data-action="open-inquiry">\u67E5\u770B\u8BE2\u76D8</button><button data-action="pause">${state.binding?.paused ? "\u7EE7\u7EED\u540C\u6B65" : "\u6682\u505C\u540C\u6B65"}</button><button data-action="unbind">\u89E3\u9664\u7ED1\u5B9A</button></div>${this.error()}</main>`;
      return `<main><p>\u6B63\u5728\u8BFB\u53D6\u5F53\u524D\u4F1A\u8BDD\u2026\u2026</p></main>`;
    }
    error() {
      return this.state.error ? `<p class="error">${escapeHtml(this.state.error)}</p>` : "";
    }
    async handle(event) {
      const action = event.currentTarget.dataset.action;
      if (action === "collapse") return this.update({ collapsed: !this.state.collapsed });
      const values = Object.fromEntries([...this.shadow.querySelectorAll("[data-field]")].map((field) => [field.dataset.field, field.value]));
      await this.handlers?.[action]?.(values);
    }
  };
  function analysisSummary(result) {
    const missing = (result.missingRequirements || []).map((item) => item.key).join("\u3001");
    const question = (result.suggestedQuestions || [])[0];
    return `<section class="result"><strong>${readinessLabel(result.readinessStatus)} \xB7 ${result.readinessScore || 0}%</strong>${missing ? `<p>\u5F85\u786E\u8BA4\uFF1A${escapeHtml(missing)}</p>` : ""}${question ? `<p>\u5EFA\u8BAE\u8FFD\u95EE\uFF1A${escapeHtml(question)}</p>` : ""}</section>`;
  }
  function readinessLabel(value) {
    return { insufficient: "\u4FE1\u606F\u4E0D\u8DB3", preliminary_ready: "\u53EF\u505A\u521D\u6B65\u62A5\u4EF7", formal_ready: "\u53EF\u505A\u6B63\u5F0F\u62A5\u4EF7", conflict: "\u5B58\u5728\u51B2\u7A81" }[value] || "\u5C1A\u672A\u5206\u6790";
  }
  function syncLabel(value) {
    return { syncing: "\u540C\u6B65\u4E2D", synced: "\u5DF2\u540C\u6B65", error: "\u540C\u6B65\u5931\u8D25", idle: "\u5DF2\u8FDE\u63A5" }[value] || "\u5DF2\u8FDE\u63A5";
  }
  function escapeHtml(value) {
    const node = document.createElement("span");
    node.textContent = String(value || "");
    return node.innerHTML;
  }
  var styles = `
:host{all:initial}aside{position:fixed;z-index:2147483646;right:18px;bottom:84px;width:330px;max-height:calc(100vh - 120px);overflow:auto;border:1px solid #2d3748;border-radius:14px;background:#0d1118;color:#f4f7fb;box-shadow:0 22px 70px rgba(0,0,0,.42);font:14px/1.45 Inter,system-ui,sans-serif}aside.collapsed{width:116px}*{box-sizing:border-box}header{position:sticky;top:0;display:flex;align-items:center;justify-content:space-between;padding:13px 15px;border-bottom:1px solid #263042;background:#0d1118}header b{letter-spacing:.04em}header i{display:inline-grid;place-items:center;width:28px;height:28px;margin-right:7px;border-radius:7px;background:#f5f7fb;color:#121722;font-style:normal;font-size:11px}button{min-height:36px;padding:8px 11px;border:1px solid #354156;border-radius:8px;background:#151c27;color:#eef3fa;cursor:pointer}button:hover{border-color:#7598ff}.primary{width:100%;margin-top:10px;border-color:#356df3;background:#356df3;color:white;font-weight:750}main{padding:16px}h3{margin:0 0 8px;font-size:17px}p{margin:6px 0 12px;color:#aab5c5}label{display:grid;gap:5px;margin:12px 0;color:#c9d2df;font-size:12px}input,select{width:100%;min-height:38px;padding:8px 9px;border:1px solid #354156;border-radius:7px;background:#111722;color:#f4f7fb}dl{display:grid;grid-template-columns:repeat(3,1fr);gap:1px;margin:14px 0;background:#283246}dl div{padding:9px;background:#111722}dt{color:#8290a4;font-size:10px}dd{margin:4px 0 0;font-weight:750}.actions{display:flex;gap:6px;flex-wrap:wrap;margin-top:9px}.actions button{flex:1;font-size:11px}.result{margin:12px 0;padding:12px 0;border-block:1px solid #2a3547}.result strong{color:#65e6d8}.result p{font-size:12px}.error{color:#ff7a91}.compact{display:flex;align-items:center;justify-content:center;gap:8px;padding:12px}.dot{width:8px;height:8px;border-radius:50%;background:#64748b}.dot.synced{background:#55d99f}.dot.syncing{background:#7598ff}.dot.error{background:#ff657f}@media(max-width:520px){aside{right:10px;bottom:72px;width:min(330px,calc(100vw - 20px))}}`;

  // integrations/chat-sync/src/userscript/entry.js
  var runtime = new TampermonkeyRuntime();
  var adapter = [new WhatsAppAdapter(), new AlibabaAdapter()].find((candidate) => candidate.isSupportedPage());
  if (adapter) start().catch((error) => console.warn("[Rubusoo] startup failed", error.message));
  async function start() {
    const api = new ApiClient(runtime, CONFIG.apiBase);
    const panel = new FloatingPanel({ runtime, platform: adapter.getPlatform() });
    let active = null;
    let lastConversationId = null;
    panel.setHandlers({
      consent: async () => {
        await runtime.storage.set(`consent:${adapter.getPlatform()}:${location.hostname}`, true);
        await refresh();
      },
      "open-setup": async () => runtime.openApp("/chat_integration"),
      pair: async ({ code }) => {
        try {
          const result = await api.pair(code);
          await runtime.auth.setToken(result.token);
          panel.update({ error: null });
          await refresh();
        } catch {
          panel.update({ error: "\u7ED1\u5B9A\u7801\u65E0\u6548\u6216\u5DF2\u8FC7\u671F" });
        }
      },
      bind: async (values) => {
        try {
          const conversation = adapter.getCurrentConversation();
          const account = adapter.getCurrentAccount();
          const result = await api.bind({
            platform: adapter.getPlatform(),
            platformAccountId: account.id,
            platformConversationId: conversation.id,
            displayName: conversation.displayName,
            inquiryId: values.inquiry || null,
            customerId: values.customer || null,
            newCustomerName: values.customerName || null
          });
          await activate(result.binding, conversation);
        } catch {
          panel.update({ error: "\u65E0\u6CD5\u7ED1\u5B9A\u6B64\u4F1A\u8BDD\uFF0C\u8BF7\u68C0\u67E5\u5BA2\u6237\u6216\u8BE2\u76D8\u9009\u62E9" });
        }
      },
      analyze: async () => {
        panel.update({ error: null, sync: { ...panel.state.sync, state: "syncing" } });
        try {
          await active.analysis.run();
        } catch {
          panel.update({ error: "\u5206\u6790\u5C1A\u672A\u5B8C\u6210\uFF0C\u8BF7\u7A0D\u540E\u91CD\u8BD5" });
        }
      },
      "open-inquiry": async () => runtime.openApp(`/inquiries/${active.binding.inquiryId}`),
      pause: async () => {
        const result = await api.updateBinding(active.binding.id, { paused: !active.binding.paused });
        active.binding = result.binding;
        panel.update({ binding: active.binding });
        if (active.binding.paused) active.collector.dispose();
        else await refresh(true);
      },
      unbind: async () => {
        await api.unbind(active.binding.id);
        disposeActive();
        await refresh(true);
      }
    });
    async function refresh(force = false) {
      const consent = await runtime.storage.get(`consent:${adapter.getPlatform()}:${location.hostname}`, false);
      if (!consent) return panel.update({ mode: "consent" });
      if (!await runtime.auth.getToken()) return panel.update({ mode: "pair" });
      const conversation = adapter.getCurrentConversation();
      if (!conversation) return panel.update({ mode: "no-conversation" });
      if (!force && conversation.id === lastConversationId && active) return;
      disposeActive();
      lastConversationId = conversation.id;
      const account = adapter.getCurrentAccount();
      try {
        const context = await api.context({
          platform: adapter.getPlatform(),
          platformAccountId: account.id,
          platformConversationId: conversation.id
        });
        if (context.binding) await activate(context.binding, conversation);
        else panel.update({ mode: "binding", conversation, context, error: null });
      } catch (error) {
        if (error.status === 401) {
          await runtime.auth.clearToken();
          panel.update({ mode: "pair" });
        } else panel.update({ mode: "binding", conversation, context: {}, error: "\u65E0\u6CD5\u8FDE\u63A5 Rubusoo" });
      }
    }
    async function activate(binding, conversation) {
      const account = adapter.getCurrentAccount();
      const queue = new UploadQueue({
        runtime,
        api,
        binding,
        config: CONFIG,
        onStatus: (sync) => panel.update({ sync })
      });
      const deduplicator = new Deduplicator(runtime, `${binding.id}`);
      const analysis = new AnalysisTrigger({
        api,
        queue,
        binding,
        config: CONFIG,
        onResult: (result) => panel.update({ analysis: result })
      });
      const collector = new Collector({
        adapter,
        deduplicator,
        queue,
        analysis,
        context: {
          platform: adapter.getPlatform(),
          platformAccountId: account.id,
          platformConversationId: conversation.id
        },
        onMessages: (messages) => analysis.note(messages)
      });
      active = { binding, queue, analysis, collector };
      panel.update({ mode: "bound", binding, conversation, analysis: binding.analysisResult || null, error: null });
      if (!binding.paused) await collector.start();
    }
    function disposeActive() {
      active?.collector?.dispose();
      active?.analysis?.dispose();
      active = null;
    }
    await refresh();
    setInterval(() => refresh(), 1200);
    addEventListener("pagehide", () => active?.queue?.persist());
  }
})();
