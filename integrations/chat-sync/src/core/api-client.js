export class ApiClient {
  constructor(runtime, apiBase) {
    this.runtime = runtime
    this.apiBase = apiBase
  }

  async pair(code) {
    return this.request("/pair", { method: "POST", body: { code, label: `${navigator.userAgent.slice(0, 60)}` }, authenticated: false })
  }

  context(context) {
    const query = new URLSearchParams(context)
    return this.request(`/context?${query}`)
  }

  bind(payload) {
    return this.request("/bindings", { method: "POST", body: payload })
  }

  updateBinding(id, payload) {
    return this.request(`/bindings/${id}`, { method: "PATCH", body: payload })
  }

  unbind(id) {
    return this.request(`/bindings/${id}`, { method: "DELETE" })
  }

  upload(bindingId, payload) {
    return this.request(`/bindings/${bindingId}/messages`, { method: "POST", body: payload })
  }

  analyze(bindingId) {
    return this.request(`/bindings/${bindingId}/analysis`, { method: "POST", body: {} })
  }

  analysis(bindingId) {
    return this.request(`/bindings/${bindingId}/analysis`)
  }

  async request(path, options = {}) {
    const token = options.authenticated === false ? null : await this.runtime.auth.getToken()
    const response = await this.runtime.http.request({
      url: `${this.apiBase}${path}`,
      method: options.method || "GET",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {})
      },
      body: options.body ? JSON.stringify(options.body) : null
    })
    if (response.status < 200 || response.status >= 300) {
      const error = new Error(`api_${response.status}`)
      error.status = response.status
      error.payload = response.json
      throw error
    }
    return response.json || {}
  }
}
