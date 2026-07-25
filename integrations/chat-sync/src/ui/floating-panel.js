export class FloatingPanel {
  constructor({ runtime, platform }) {
    this.runtime = runtime
    this.platform = platform
    this.host = document.createElement("div")
    this.host.id = "rubusoo-chat-sync"
    this.shadow = this.host.attachShadow({ mode: "closed" })
    document.documentElement.appendChild(this.host)
    this.state = { mode: "loading", collapsed: false, sync: {}, analysis: null }
  }

  setHandlers(handlers) { this.handlers = handlers }
  update(patch) { this.state = { ...this.state, ...patch }; this.render() }

  render() {
    const state = this.state
    this.shadow.innerHTML = `<style>${styles}</style><aside class="${state.collapsed ? "collapsed" : ""}">
      <header><b><i>R/</i> Rubusoo</b><button data-action="collapse">${state.collapsed ? "＋" : "—"}</button></header>
      ${state.collapsed ? `<div class="compact"><span class="dot ${state.sync.state || ""}"></span><strong>${state.sync.pending || 0}</strong></div>` : this.body()}
    </aside>`
    this.shadow.querySelectorAll("[data-action]").forEach(element => element.addEventListener("click", event => this.handle(event)))
  }

  body() {
    const state = this.state
    if (state.mode === "consent") return `<main><h3>启用 ${escapeHtml(this.platform)}</h3><p>只采集你主动绑定的会话，不读取输入框、Cookie 或其他聊天。</p><button class="primary" data-action="consent">允许此网站</button></main>`
    if (state.mode === "pair") return `<main><h3>连接 Rubusoo</h3><p>在 Rubusoo 的“网页聊天同步”页面生成一次性绑定码。</p><input data-field="code" placeholder="000-000-000"><button class="primary" data-action="pair">连接</button><button data-action="open-setup">打开设置页面</button>${this.error()}</main>`
    if (state.mode === "no-conversation") return `<main><h3>等待打开会话</h3><p>打开一个客户聊天后即可绑定。</p></main>`
    if (state.mode === "binding") return `<main><h3>${escapeHtml(state.conversation?.displayName || "当前会话")}</h3><p>绑定后才会开始采集和上传。</p>
      <label>关联已有询盘<select data-field="inquiry"><option value="">新建询盘</option>${(state.context?.inquiries || []).map(item => `<option value="${item.id}">${escapeHtml(item.label)}</option>`).join("")}</select></label>
      <label>关联已有客户<select data-field="customer"><option value="">不选择</option>${(state.context?.customers || []).map(item => `<option value="${item.id}">${escapeHtml(item.name)}</option>`).join("")}</select></label>
      <label>或创建客户<input data-field="customerName" placeholder="客户公司名称"></label>
      <button class="primary" data-action="bind">绑定并开始同步</button>${this.error()}</main>`
    if (state.mode === "bound") return `<main><div class="identity"><small>${escapeHtml(this.platform)}</small><h3>${escapeHtml(state.conversation?.displayName || state.binding?.displayName)}</h3><p>询盘 #${state.binding?.inquiryId}</p></div>
      <dl><div><dt>待上传</dt><dd>${state.sync.pending || 0}</dd></div><div><dt>同步状态</dt><dd>${syncLabel(state.sync.state)}</dd></div><div><dt>准备度</dt><dd>${readinessLabel(state.analysis?.readinessStatus)}</dd></div></dl>
      ${state.analysis ? analysisSummary(state.analysis) : ""}
      <button class="primary" data-action="analyze">立即分析</button><div class="actions"><button data-action="open-inquiry">查看询盘</button><button data-action="pause">${state.binding?.paused ? "继续同步" : "暂停同步"}</button><button data-action="unbind">解除绑定</button></div>${this.error()}</main>`
    return `<main><p>正在读取当前会话……</p></main>`
  }

  error() { return this.state.error ? `<p class="error">${escapeHtml(this.state.error)}</p>` : "" }

  async handle(event) {
    const action = event.currentTarget.dataset.action
    if (action === "collapse") return this.update({ collapsed: !this.state.collapsed })
    const values = Object.fromEntries([...this.shadow.querySelectorAll("[data-field]")].map(field => [field.dataset.field, field.value]))
    await this.handlers?.[action]?.(values)
  }
}

function analysisSummary(result) {
  const missing = (result.missingRequirements || []).map(item => item.key).join("、")
  const question = (result.suggestedQuestions || [])[0]
  return `<section class="result"><strong>${readinessLabel(result.readinessStatus)} · ${result.readinessScore || 0}%</strong>${missing ? `<p>待确认：${escapeHtml(missing)}</p>` : ""}${question ? `<p>建议追问：${escapeHtml(question)}</p>` : ""}</section>`
}
function readinessLabel(value) { return ({ insufficient: "信息不足", preliminary_ready: "可做初步报价", formal_ready: "可做正式报价", conflict: "存在冲突" })[value] || "尚未分析" }
function syncLabel(value) { return ({ syncing: "同步中", synced: "已同步", error: "同步失败", idle: "已连接" })[value] || "已连接" }
function escapeHtml(value) { const node = document.createElement("span"); node.textContent = String(value || ""); return node.innerHTML }

const styles = `
:host{all:initial}aside{position:fixed;z-index:2147483646;right:18px;bottom:84px;width:330px;max-height:calc(100vh - 120px);overflow:auto;border:1px solid #2d3748;border-radius:14px;background:#0d1118;color:#f4f7fb;box-shadow:0 22px 70px rgba(0,0,0,.42);font:14px/1.45 Inter,system-ui,sans-serif}aside.collapsed{width:116px}*{box-sizing:border-box}header{position:sticky;top:0;display:flex;align-items:center;justify-content:space-between;padding:13px 15px;border-bottom:1px solid #263042;background:#0d1118}header b{letter-spacing:.04em}header i{display:inline-grid;place-items:center;width:28px;height:28px;margin-right:7px;border-radius:7px;background:#f5f7fb;color:#121722;font-style:normal;font-size:11px}button{min-height:36px;padding:8px 11px;border:1px solid #354156;border-radius:8px;background:#151c27;color:#eef3fa;cursor:pointer}button:hover{border-color:#7598ff}.primary{width:100%;margin-top:10px;border-color:#356df3;background:#356df3;color:white;font-weight:750}main{padding:16px}h3{margin:0 0 8px;font-size:17px}p{margin:6px 0 12px;color:#aab5c5}label{display:grid;gap:5px;margin:12px 0;color:#c9d2df;font-size:12px}input,select{width:100%;min-height:38px;padding:8px 9px;border:1px solid #354156;border-radius:7px;background:#111722;color:#f4f7fb}dl{display:grid;grid-template-columns:repeat(3,1fr);gap:1px;margin:14px 0;background:#283246}dl div{padding:9px;background:#111722}dt{color:#8290a4;font-size:10px}dd{margin:4px 0 0;font-weight:750}.actions{display:flex;gap:6px;flex-wrap:wrap;margin-top:9px}.actions button{flex:1;font-size:11px}.result{margin:12px 0;padding:12px 0;border-block:1px solid #2a3547}.result strong{color:#65e6d8}.result p{font-size:12px}.error{color:#ff7a91}.compact{display:flex;align-items:center;justify-content:center;gap:8px;padding:12px}.dot{width:8px;height:8px;border-radius:50%;background:#64748b}.dot.synced{background:#55d99f}.dot.syncing{background:#7598ff}.dot.error{background:#ff657f}@media(max-width:520px){aside{right:10px;bottom:72px;width:min(330px,calc(100vw - 20px))}}`
