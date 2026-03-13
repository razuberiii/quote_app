import { Controller } from "@hotwired/stimulus";

// Copy a text value to the clipboard and show a toast confirming the result.
// Usage:
//   data-controller="clipboard"
//   data-clipboard-text-value="the text to copy"
//   data-clipboard-success-message-value="Copied!"  (optional)
//   data-action="click->clipboard#copy"
export default class extends Controller {
  static values = {
    text: String,
    successMessage: String,
    errorMessage: String,
  };

  async copy() {
    const text = this.textValue;
    if (!text) return;

    let copied = false;
    try {
      if (navigator.clipboard?.writeText && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
        copied = true;
      } else {
        const el = document.createElement("textarea");
        el.value = text;
        el.style.cssText = "position:fixed;top:-9999px;left:-9999px";
        document.body.appendChild(el);
        el.select();
        copied = document.execCommand("copy");
        el.remove();
      }
    } catch (_) {
      copied = false;
    }

    const msg = copied
      ? this.hasSuccessMessageValue
        ? this.successMessageValue
        : "Copied!"
      : this.hasErrorMessageValue
        ? this.errorMessageValue
        : "Copy failed";
    window.showAppToast?.(msg, copied ? "success" : "error");
  }
}
