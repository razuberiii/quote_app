import { BaseAdapter } from "./base-adapter.js"

export class GenericAdapter extends BaseAdapter {
  isSupportedPage() { return false }
}
