export class TampermonkeyRuntime {
  storage = {
    get: async (key, fallback = null) => GM_getValue(key, fallback),
    set: async (key, value) => GM_setValue(key, value),
    remove: async key => GM_deleteValue(key)
  }

  auth = {
    getToken: async () => this.storage.get("auth:token"),
    setToken: async token => this.storage.set("auth:token", token),
    clearToken: async () => this.storage.remove("auth:token")
  }

  http = {
    request: options => new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: options.method,
        url: options.url,
        headers: options.headers,
        data: options.body,
        timeout: 120000,
        onload: response => {
          let json = null
          try { json = response.responseText ? JSON.parse(response.responseText) : null } catch {}
          resolve({ status: response.status, json, text: response.responseText })
        },
        ontimeout: () => reject(new Error("request_timeout")),
        onerror: () => reject(new Error("network_error"))
      })
    })
  }

  openApp(path = "") { GM_openInTab(`https://next.rubusoo.com${path}`, { active: true }) }
  notify(text) { GM_notification({ title: "Rubusoo", text, timeout: 5000 }) }
}
