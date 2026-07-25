export class BrowserExtensionRuntime {
  constructor(browserApi = globalThis.chrome) { this.browser = browserApi }
  storage = {
    get: async (key, fallback = null) => (await this.browser.storage.local.get(key))[key] ?? fallback,
    set: async (key, value) => this.browser.storage.local.set({ [key]: value }),
    remove: async key => this.browser.storage.local.remove(key)
  }
  auth = {
    getToken: async () => this.storage.get("auth:token"),
    setToken: async token => this.storage.set("auth:token", token),
    clearToken: async () => this.storage.remove("auth:token")
  }
  http = { request: options => fetch(options.url, { method: options.method, headers: options.headers, body: options.body }).then(async response => ({ status: response.status, json: await response.json().catch(() => null) })) }
  openApp(path = "") { this.browser.tabs.create({ url: `https://next.rubusoo.com${path}` }) }
  notify(text) { this.browser.notifications.create({ type: "basic", title: "Rubusoo", message: text, iconUrl: "icon.png" }) }
}
