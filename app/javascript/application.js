// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const CLICKABLE_CONTAINER_SELECTOR = "[data-clickable-href]";
const INTERACTIVE_SELECTOR = "a, button, input, select, textarea, label, summary, details, [role='button'], [data-no-row-nav]";

const isInteractiveClick = (event, container) => {
  const interactiveNode = event.target.closest(INTERACTIVE_SELECTOR);
  return interactiveNode && container.contains(interactiveNode);
};

const navigateToContainerHref = (container) => {
  const { clickableHref } = container.dataset;
  if (!clickableHref) return;
  window.location.href = clickableHref;
};

const hasActiveTextSelectionIn = (container) => {
  if (!window.getSelection) return false;

  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return false;
  if (!selection.toString().trim()) return false;

  const { anchorNode, focusNode } = selection;
  const anchorInside = anchorNode && container.contains(anchorNode);
  const focusInside = focusNode && container.contains(focusNode);
  return anchorInside || focusInside;
};

if (!window.__clickableContainerNavBound) {
  window.__clickableContainerNavBound = true;

  document.addEventListener("click", (event) => {
    const container = event.target.closest(CLICKABLE_CONTAINER_SELECTOR);
    if (!container || event.defaultPrevented) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (isInteractiveClick(event, container)) return;
    if (hasActiveTextSelectionIn(container)) return;
    navigateToContainerHref(container);
  });

  document.addEventListener("keydown", (event) => {
    const container = event.target.closest(CLICKABLE_CONTAINER_SELECTOR);
    if (!container || event.defaultPrevented) return;
    if (event.key !== "Enter" && event.key !== " ") return;
    if (isInteractiveClick(event, container)) return;

    event.preventDefault();
    navigateToContainerHref(container);
  });
}

const bindLiveImagePreview = () => {
  document.querySelectorAll("input[type='file'][data-live-preview-target]").forEach((input) => {
    if (input.dataset.boundPreview === "true") return;
    input.dataset.boundPreview = "true";

    const target = document.querySelector(input.dataset.livePreviewTarget);
    const fallback = input.dataset.livePreviewFallback ? document.querySelector(input.dataset.livePreviewFallback) : null;
    if (!target) return;

    input.addEventListener("change", () => {
      const file = input.files && input.files[0];
      if (!file || !file.type.startsWith("image/")) return;

      const objectUrl = URL.createObjectURL(file);
      target.src = objectUrl;
      target.hidden = false;
      if (fallback) fallback.hidden = true;
    });
  });
};

bindLiveImagePreview();
document.addEventListener("turbo:load", bindLiveImagePreview);

const bindProductRowMenus = () => {
  const menus = Array.from(document.querySelectorAll(".product-row-menu"));
  if (!menus.length) return;

  const closeAll = (except = null) => {
    menus.forEach((menu) => {
      if (menu !== except) menu.removeAttribute("open");
    });
  };

  menus.forEach((menu) => {
    if (menu.dataset.menuBound === "true") return;
    menu.dataset.menuBound = "true";

    menu.addEventListener("toggle", () => {
      if (menu.open) closeAll(menu);
    });
  });

  document.addEventListener("click", (event) => {
    const insideMenu = event.target.closest(".product-row-menu");
    if (insideMenu) return;
    closeAll();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    closeAll();
  });
};

if (!window.__productRowMenusBound) {
  window.__productRowMenusBound = true;
  bindProductRowMenus();
  document.addEventListener("turbo:load", bindProductRowMenus);
}

const getProductLightboxElements = () => {
  const lightbox = document.querySelector("[data-product-lightbox]");
  const previewImage = lightbox && lightbox.querySelector("[data-product-lightbox-image]");
  if (!lightbox || !previewImage) return null;
  return { lightbox, previewImage };
};

const closeProductLightbox = () => {
  const elements = getProductLightboxElements();
  if (!elements) return;
  const { lightbox, previewImage } = elements;

  lightbox.hidden = true;
  previewImage.src = "";
  previewImage.alt = "";
  document.body.style.overflow = "";
};

const openProductLightbox = (src, alt = "") => {
  if (!src) return;
  const elements = getProductLightboxElements();
  if (!elements) return;
  const { lightbox, previewImage } = elements;

  previewImage.src = src;
  previewImage.alt = alt;
  lightbox.hidden = false;
  document.body.style.overflow = "hidden";
};

if (!window.__productLightboxListenersBound) {
  window.__productLightboxListenersBound = true;

  document.addEventListener("click", (event) => {
    const trigger = event.target.closest("[data-product-lightbox-trigger]");
    if (trigger) {
      openProductLightbox(trigger.dataset.fullSrc, trigger.dataset.alt || "Product image");
      return;
    }

    const elements = getProductLightboxElements();
    if (!elements || elements.lightbox.hidden) return;
    if (event.target.closest("[data-product-lightbox-close]")) {
      closeProductLightbox();
    }
  });

  document.addEventListener("keydown", (event) => {
    const elements = getProductLightboxElements();
    if (!elements || event.key !== "Escape" || elements.lightbox.hidden) return;
    closeProductLightbox();
  });

  document.addEventListener("turbo:before-cache", closeProductLightbox);
}
