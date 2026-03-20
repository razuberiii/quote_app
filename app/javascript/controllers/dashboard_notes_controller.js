import { Controller } from "@hotwired/stimulus";

// Global personal notes widget (client-side only).
// Behavior contract:
// - Free notes + todo lines in one editor
// - Todo line syntax: `☐ text` or `☑ text`
// - Enter on todo -> next todo line; Enter on note -> note line
// - Backspace/Delete on todo line (collapsed caret) -> first remove todo marker
// - Click only on checkbox glyph toggles done/undone
export default class extends Controller {
  static targets = ["panel", "launcher", "editor", "dragHandle"];
  static values = { storageKey: String };

  connect() {
    this.state = this.loadState();
    this.drag = { active: false, pointerId: null, startX: 0, startY: 0, baseX: 0, baseY: 0 };
    this.resizeObserver = null;
    this.lastMeasuredSize = null;
    this.render();
  }

  disconnect() {
    this.teardownDragListeners();
    this.teardownResizeObserver();
  }

  toggle() {
    this.state.open = !this.state.open;
    this.persist();
    this.renderChrome();
    if (this.state.open) this.focusEditorToEnd();
  }

  close() {
    this.state.open = false;
    this.persist();
    this.renderChrome();
  }

  onFocus() {
    // no-op: kept for consistency/future hooks
  }

  onInput() {
    if (!this.hasEditorTarget) return;
    this.state.text = this.sanitizeNoteText(this.editorPlainText());
    this.persist();
    this.renderEditorState();
  }

  onBlur() {
    if (!this.hasEditorTarget) return;
    const plain = this.editorPlainText();
    const normalized = this.sanitizeNoteText(plain);
    this.state.text = normalized;
    this.persist();
    this.renderEditor();
    this.renderEditorState();
  }

  onKeydown(event) {
    if ((event.key === "Backspace" || event.key === "Delete") && this.tryClearAllOnFullSelection(event)) {
      return;
    }

    if (event.key === "Enter") {
      event.preventDefault();
      this.insertNewLineByModel();
      return;
    }

    if ((event.key === "Backspace" || event.key === "Delete") && this.tryRemoveTodoMarker(event)) {
      return;
    }

    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "d") {
      event.preventDefault();
      this.toggleCurrentLineDoneState();
      return;
    }

    if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "t") {
      event.preventDefault();
      this.convertCurrentLineToTodo();
      return;
    }

    if (event.key === "Tab") {
      event.preventDefault();
      this.convertCurrentLineToTodo();
    }
  }

  tryClearAllOnFullSelection(event) {
    if (!this.hasEditorTarget) return false;
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return false;

    const range = selection.getRangeAt(0);
    if (!this.isFullEditorSelection(range)) return false;

    event.preventDefault();
    this.state.text = "";
    this.persist();
    this.editorTarget.innerHTML = "";
    this.renderEditorState();
    return true;
  }

  isFullEditorSelection(range) {
    if (!this.hasEditorTarget) return false;
    const full = document.createRange();
    full.selectNodeContents(this.editorTarget);

    const startEqual =
      range.compareBoundaryPoints(Range.START_TO_START, full) === 0;
    const endEqual =
      range.compareBoundaryPoints(Range.END_TO_END, full) === 0;
    return startEqual && endEqual;
  }

  onClickLine(event) {
    if (!event || event.button !== 0 || !this.hasEditorTarget) return;
    const checkbox = event.target.closest(".dashboard-notes-check");
    if (!checkbox || !this.editorTarget.contains(checkbox)) return;

    const lineNode = checkbox.closest(".dashboard-notes-line");
    const lineIndex = Number(lineNode?.dataset?.lineIndex);
    if (!Number.isFinite(lineIndex)) return;

    event.preventDefault();
    this.toggleTodoByLineIndex(lineIndex);
  }

  startDrag(event) {
    if (!this.state.open || !this.hasPanelTarget) return;
    if (event.target.closest(".dashboard-notes-close")) return;
    if (this.drag.active) return;

    this.drag.active = true;
    this.drag.pointerId = typeof event.pointerId === "number" ? event.pointerId : null;
    this.drag.startX = event.clientX;
    this.drag.startY = event.clientY;
    this.drag.baseX = Number(this.state.position?.x || 0);
    this.drag.baseY = Number(this.state.position?.y || 0);

    this.dragMoveHandler = this.onDragMove.bind(this);
    this.dragEndHandler = this.endDrag.bind(this);
    window.addEventListener("pointermove", this.dragMoveHandler);
    window.addEventListener("pointerup", this.dragEndHandler);
    window.addEventListener("pointercancel", this.dragEndHandler);
    window.addEventListener("mousemove", this.dragMoveHandler);
    window.addEventListener("mouseup", this.dragEndHandler);
  }

  onDragMove(event) {
    if (!this.drag.active) return;
    if (typeof event.pointerId === "number" && this.drag.pointerId !== null && event.pointerId !== this.drag.pointerId) return;

    const dx = event.clientX - this.drag.startX;
    const dy = event.clientY - this.drag.startY;
    this.state.position = { x: this.drag.baseX + dx, y: this.drag.baseY + dy };
    this.applyPanelPosition();
  }

  endDrag(event) {
    if (!this.drag.active) return;
    if (typeof event.pointerId === "number" && this.drag.pointerId !== null && event.pointerId !== this.drag.pointerId) return;

    this.drag.active = false;
    this.drag.pointerId = null;
    this.persist();
    this.teardownDragListeners();
    this.renderChrome();
  }

  teardownDragListeners() {
    if (this.dragMoveHandler) window.removeEventListener("pointermove", this.dragMoveHandler);
    if (this.dragEndHandler) window.removeEventListener("pointerup", this.dragEndHandler);
    if (this.dragEndHandler) window.removeEventListener("pointercancel", this.dragEndHandler);
    if (this.dragMoveHandler) window.removeEventListener("mousemove", this.dragMoveHandler);
    if (this.dragEndHandler) window.removeEventListener("mouseup", this.dragEndHandler);
    this.dragMoveHandler = null;
    this.dragEndHandler = null;
  }

  render() {
    this.renderEditor();
    this.renderChrome();
  }

  renderEditor(caretOffset = null) {
    if (!this.hasEditorTarget) return;
    this.editorTarget.innerHTML = this.buildEditorHtml(this.state.text);
    if (Number.isFinite(caretOffset)) this.setCaretOffset(caretOffset);
    this.renderEditorState();
  }

  renderChrome() {
    const open = !!this.state.open;
    this.element.classList.toggle("is-open", open);
    this.element.classList.toggle("is-dragging", this.drag.active);
    if (this.hasPanelTarget) this.panelTarget.hidden = !open;
    if (this.hasLauncherTarget) this.launcherTarget.hidden = open;
    if (this.hasLauncherTarget) this.launcherTarget.setAttribute("aria-expanded", open ? "true" : "false");

    this.applyPanelPosition();
    this.applyPanelSize();
    if (open) this.setupResizeObserver();
    else this.teardownResizeObserver();
  }

  renderEditorState() {
    this.element.classList.toggle("has-note", this.state.text.trim().length > 0);
  }

  applyPanelPosition() {
    if (!this.hasPanelTarget) return;
    const x = Number(this.state.position?.x || 0);
    const y = Number(this.state.position?.y || 0);
    this.panelTarget.style.setProperty("--notes-offset-x", `${x}px`);
    this.panelTarget.style.setProperty("--notes-offset-y", `${y}px`);
  }

  applyPanelSize() {
    if (!this.hasPanelTarget) return;
    const size = this.normalizeSize(this.state.size);
    if (!size) return;
    this.panelTarget.style.width = `${size.width}px`;
    this.panelTarget.style.height = `${size.height}px`;
    this.lastMeasuredSize = { width: size.width, height: size.height };
  }

  loadState() {
    const fallback = { open: false, text: "", position: { x: 0, y: 0 }, size: null };
    if (!this.hasStorageKeyValue) return fallback;

    try {
      const raw = localStorage.getItem(this.storageKeyValue);
      if (!raw) return fallback;
      const parsed = JSON.parse(raw);
      return {
        open: !!parsed.open,
        text: this.sanitizeNoteText(parsed.text || ""),
        position: { x: Number(parsed.position?.x || 0), y: Number(parsed.position?.y || 0) },
        size: this.normalizeSize(parsed.size),
      };
    } catch (_) {
      return fallback;
    }
  }

  persist() {
    if (!this.hasStorageKeyValue) return;
    const payload = {
      open: !!this.state.open,
      text: this.state.text,
      position: { x: Number(this.state.position?.x || 0), y: Number(this.state.position?.y || 0) },
      size: this.normalizeSize(this.state.size),
    };
    localStorage.setItem(this.storageKeyValue, JSON.stringify(payload));
  }

  sanitizeNoteText(value) {
    const normalized = String(value || "")
      .replace(/\r\n/g, "\n")
      .replace(/\u200b/g, "")
      .replace(/\u00a0/g, " ")
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n{4,}/g, "\n\n\n");

    const lines = normalized.split("\n").map((line) => {
      const trimmedEnd = line.replace(/[ \t]+$/g, "");
      if (/^\s*\[\]\s*/.test(trimmedEnd)) return trimmedEnd.replace(/^\s*\[\]\s*/, "☐ ");
      if (/^\s*\[ \]\s*/.test(trimmedEnd)) return trimmedEnd.replace(/^\s*\[ \]\s*/, "☐ ");
      if (/^\s*\[x\]\s*/i.test(trimmedEnd)) return trimmedEnd.replace(/^\s*\[x\]\s*/i, "☑ ");
      const todoMatch = trimmedEnd.match(/^(☐|☑)\s*(.*)$/);
      if (todoMatch) {
        const mark = todoMatch[1];
        const body = (todoMatch[2] || "").replace(/[ \t]+$/g, "");
        return body.length > 0 ? `${mark} ${body}` : `${mark} `;
      }
      return trimmedEnd;
    });
    return lines.join("\n").slice(0, 2600);
  }

  buildEditorHtml(text) {
    const safe = String(text || "");
    if (!safe.length) return "";

    const lines = safe.split("\n");
    return lines
      .map((line, idx) => {
        const todoMatch = line.match(/^(☐|☑)\s*(.*)$/);
        if (todoMatch) {
          const mark = todoMatch[1];
          const done = mark === "☑";
          const body = this.escapeHtml(todoMatch[2] || "");
          return `<div class="dashboard-notes-line is-todo ${done ? "is-done" : ""}" data-line-index="${idx}"><span class="dashboard-notes-check" contenteditable="false" data-done="${done ? "true" : "false"}"></span><span class="dashboard-notes-line-text">${body || "&#8203;"}</span></div>`;
        }

        return `<div class="dashboard-notes-line" data-line-index="${idx}"><span class="dashboard-notes-line-text">${this.escapeHtml(line) || "&#8203;"}</span></div>`;
      })
      .join("");
  }

  escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  toggleTodoByLineIndex(lineIndex) {
    const lines = this.state.text.split("\n");
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    const line = lines[lineIndex];
    if (!/^(☐|☑)\s*/.test(line)) return;
    lines[lineIndex] = line.startsWith("☐") ? line.replace(/^☐\s*/, "☑ ") : line.replace(/^☑\s*/, "☐ ");
    this.state.text = this.sanitizeNoteText(lines.join("\n"));
    this.persist();
    this.renderEditor();
    this.focusLineStart(lineIndex);
  }

  toggleCurrentLineDoneState() {
    const meta = this.currentLineMeta();
    if (!meta || !meta.isTodo) return;
    this.replaceCurrentLine(meta.lineText.startsWith("☐") ? meta.lineText.replace(/^☐\s*/, "☑ ") : meta.lineText.replace(/^☑\s*/, "☐ "), meta.lineStart + meta.lineText.length);
  }

  convertCurrentLineToTodo() {
    const meta = this.currentLineMeta();
    if (!meta || meta.isTodo) return;
    const body = meta.lineText.trim();
    this.replaceCurrentLine(body.length ? `☐ ${body}` : "☐ ", meta.lineStart + 2 + body.length);
  }

  tryRemoveTodoMarker(event) {
    const meta = this.currentLineMeta();
    if (!meta || !meta.isTodo || !meta.selectionCollapsed) return false;

    event.preventDefault();
    const withoutMarker = meta.lineText.replace(/^(☐|☑)\s*/, "");
    const nextCaret = Math.max(meta.lineStart, meta.caretOffset - meta.markerLength);
    this.replaceCurrentLine(withoutMarker, nextCaret);
    return true;
  }

  replaceCurrentLine(nextLine, caretOffset) {
    const meta = this.currentLineMeta();
    if (!meta) return;
    const text = this.editorPlainText();
    const nextText = `${text.slice(0, meta.lineStart)}${nextLine}${text.slice(meta.lineEnd)}`;
    this.state.text = this.sanitizeNoteText(nextText);
    this.persist();
    this.renderEditor(Math.min(caretOffset, this.state.text.length));
    this.renderEditorState();
  }

  insertNewLineByModel() {
    const meta = this.currentLineMeta();
    if (meta?.isTodo) {
      const todoBody = meta.lineText.replace(/^(☐|☑)\s*/, "").trim();
      if (!todoBody.length) {
        // Empty todo line: second Enter exits todo mode instead of creating endless empty checkboxes.
        this.replaceCurrentLine("", meta.lineStart);
        return;
      }
    }

    const text = this.editorPlainText();
    const caret = this.getCaretOffset();
    const insertText = meta?.isTodo ? "\n☐ " : "\n";
    const nextText = `${text.slice(0, caret)}${insertText}${text.slice(caret)}`;
    this.state.text = this.sanitizeNoteText(nextText);
    this.persist();
    this.renderEditor(Math.min(caret + insertText.length, this.state.text.length));
    this.renderEditorState();
  }

  findLineBounds(text, caret) {
    const start = Math.max(0, text.lastIndexOf("\n", Math.max(0, caret - 1)) + 1);
    const nextBreak = text.indexOf("\n", caret);
    const end = nextBreak === -1 ? text.length : nextBreak;
    return { lineStart: start, lineEnd: end };
  }

  currentLineMeta() {
    if (!this.hasEditorTarget) return null;
    const text = this.editorPlainText();
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0) return null;

    const caretOffset = this.getCaretOffset();
    const { lineStart, lineEnd } = this.findLineBounds(text, caretOffset);
    const lineText = text.slice(lineStart, lineEnd);
    const markerMatch = lineText.match(/^(☐|☑)\s*/);

    return {
      lineStart,
      lineEnd,
      lineText,
      caretOffset,
      isTodo: !!markerMatch,
      markerLength: markerMatch ? markerMatch[0].length : 0,
      selectionCollapsed: selection.isCollapsed,
    };
  }

  getCaretOffset() {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0) return 0;
    const range = selection.getRangeAt(0);
    const textSnapshot = this.editorPlainText();
    const lines = textSnapshot.split("\n");
    const lineNodes = this.editorTarget.querySelectorAll(":scope > .dashboard-notes-line");

    const fallbackNativeOffset = () => {
      const preRange = range.cloneRange();
      preRange.selectNodeContents(this.editorTarget);
      preRange.setEnd(range.startContainer, range.startOffset);
      return preRange.toString().length;
    };

    // First-input phase: editor may still be plain text (no line wrapper nodes).
    if (lineNodes.length === 0) {
      return fallbackNativeOffset();
    }

    const prefixForLine = (idx) => {
      let total = 0;
      for (let i = 0; i < idx; i += 1) total += (lines[i] || "").length + 1;
      return total;
    };

    const findLineNode = (node) => {
      if (!node) return null;
      if (node.nodeType === Node.ELEMENT_NODE) return node.closest?.(".dashboard-notes-line") || null;
      return node.parentElement?.closest?.(".dashboard-notes-line") || null;
    };

    const lineNode = findLineNode(range.startContainer);

    // Caret can be directly on editor root between line blocks.
    if (!lineNode && range.startContainer === this.editorTarget) {
      const boundary = range.startOffset;
      if (boundary <= 0) return 0;
      const prevLine = lineNodes[Math.min(boundary - 1, lineNodes.length - 1)];
      if (!prevLine) return 0;
      const prevIdx = Number(prevLine.dataset.lineIndex || 0);
      return prefixForLine(prevIdx) + (lines[prevIdx] || "").length;
    }

    if (!lineNode || !this.editorTarget.contains(lineNode)) {
      return fallbackNativeOffset();
    }
    const lineIndex = Number(lineNode.dataset.lineIndex || 0);
    const lineText = lines[lineIndex] || "";
    const linePrefix = prefixForLine(lineIndex);
    const markerLen = (lineText.match(/^(☐|☑)\s*/) || [""])[0].length;

    // Caret on checkbox glyph => start of todo line.
    const checkNode = range.startContainer?.nodeType === Node.ELEMENT_NODE
      ? range.startContainer.closest?.(".dashboard-notes-check")
      : range.startContainer?.parentElement?.closest?.(".dashboard-notes-check");
    if (checkNode && lineNode.contains(checkNode)) return linePrefix;

    // Caret on line container element itself => start or end of line.
    if (range.startContainer === lineNode) {
      return range.startOffset <= 0 ? linePrefix : linePrefix + lineText.length;
    }

    const bodyNode = lineNode.querySelector(".dashboard-notes-line-text");
    if (!bodyNode) return linePrefix;

    const probe = document.createRange();
    probe.selectNodeContents(bodyNode);
    probe.setEnd(range.startContainer, range.startOffset);
    const rawBodyOffset = Math.max(0, probe.toString().length);
    const maxBodyLen = Math.max(0, lineText.length - markerLen);
    const bodyOffset = Math.min(rawBodyOffset, maxBodyLen);
    return linePrefix + markerLen + bodyOffset;
  }

  setCaretOffset(offset) {
    if (!this.hasEditorTarget) return;
    this.editorTarget.focus();
    const selection = window.getSelection();
    if (!selection) return;

    const lines = this.state.text.split("\n");
    let remaining = Math.max(0, offset);
    let lineIndex = 0;

    for (; lineIndex < lines.length; lineIndex += 1) {
      const lineLen = lines[lineIndex].length;
      if (remaining <= lineLen) break;
      remaining -= lineLen + 1;
    }

    const finalIndex = Math.min(lineIndex, Math.max(0, lines.length - 1));
    const lineNode = this.editorTarget.querySelector(`.dashboard-notes-line[data-line-index="${finalIndex}"]`);
    if (!lineNode) return;

    const lineText = lines[finalIndex] || "";
    const markerLen = /^(☐|☑)\s*/.test(lineText) ? (lineText.match(/^(☐|☑)\s*/)?.[0]?.length || 0) : 0;
    const bodyOffset = Math.max(0, remaining - markerLen);

    const bodyNode = lineNode.querySelector(".dashboard-notes-line-text");
    if (!bodyNode) return;

    const range = document.createRange();
    const target = this.resolveTextNodeAndOffset(bodyNode, bodyOffset);
    range.setStart(target.node, target.offset);
    range.collapse(true);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  resolveTextNodeAndOffset(root, desiredOffset) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    let node = walker.nextNode();
    let remaining = Math.max(0, desiredOffset);

    while (node) {
      const len = node.textContent?.length || 0;
      if (remaining <= len) {
        return { node, offset: remaining };
      }
      remaining -= len;
      node = walker.nextNode();
    }

    // Fallback to end of root
    const fallbackRange = document.createRange();
    fallbackRange.selectNodeContents(root);
    fallbackRange.collapse(false);
    return { node: fallbackRange.endContainer, offset: fallbackRange.endOffset };
  }

  focusLineStart(lineIndex) {
    const lines = this.state.text.split("\n");
    let offset = 0;
    for (let i = 0; i < lineIndex; i += 1) offset += lines[i].length + 1;
    this.setCaretOffset(offset);
  }

  editorPlainText() {
    if (!this.hasEditorTarget) return "";

    const lineNodes = this.editorTarget.querySelectorAll(":scope > .dashboard-notes-line");
    if (lineNodes.length > 0) {
      const lines = Array.from(lineNodes).map((lineNode) => {
        const bodyNode = lineNode.querySelector(".dashboard-notes-line-text");
        const body = (bodyNode?.textContent || "")
          .replace(/\u200b/g, "")
          .replace(/\u00a0/g, " ")
          .replace(/\r?\n/g, "");

        if (lineNode.classList.contains("is-todo")) {
          const doneAttr = lineNode.querySelector(".dashboard-notes-check")?.dataset?.done;
          const mark = doneAttr === "true" ? "☑" : "☐";
          return `${mark} ${body}`;
        }

        return body;
      });
      return lines.join("\n");
    }

    return (this.editorTarget.innerText || "").replace(/\r\n/g, "\n");
  }

  focusEditorToEnd() {
    if (!this.hasEditorTarget) return;
    this.editorTarget.focus();
    this.setCaretOffset(this.editorPlainText().length);
  }

  normalizeSize(size) {
    const width = Number(size?.width || 0);
    const height = Number(size?.height || 0);
    if (!width || !height) return null;
    return { width, height };
  }

  setupResizeObserver() {
    if (!this.hasPanelTarget || this.resizeObserver || typeof ResizeObserver === "undefined") return;
    this.lastMeasuredSize = { width: this.panelTarget.offsetWidth, height: this.panelTarget.offsetHeight };
    this.resizeObserver = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (!entry || this.panelTarget.hidden) return;

      const nextWidth = Math.round(this.panelTarget.offsetWidth);
      const nextHeight = Math.round(this.panelTarget.offsetHeight);
      if (!nextWidth || !nextHeight) return;

      const prev = this.lastMeasuredSize;
      if (prev && (nextWidth !== prev.width || nextHeight !== prev.height)) {
        const dx = nextWidth - prev.width;
        const dy = nextHeight - prev.height;
        this.state.position = {
          x: Number(this.state.position?.x || 0) + dx,
          y: Number(this.state.position?.y || 0) + dy,
        };
        this.applyPanelPosition();
      }

      this.lastMeasuredSize = { width: nextWidth, height: nextHeight };
      this.state.size = { width: nextWidth, height: nextHeight };
      this.persist();
    });
    this.resizeObserver.observe(this.panelTarget);
  }

  teardownResizeObserver() {
    if (!this.resizeObserver) return;
    this.resizeObserver.disconnect();
    this.resizeObserver = null;
    this.lastMeasuredSize = null;
  }
}
