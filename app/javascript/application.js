// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

const CLICKABLE_CONTAINER_SELECTOR = "[data-clickable-href]";
const INTERACTIVE_SELECTOR =
  "a, button, input, select, textarea, label, summary, details, [role='button'], [data-no-row-nav]";

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
  if (!selection || selection.rangeCount === 0 || selection.isCollapsed)
    return false;
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
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
      return;
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
  document
    .querySelectorAll("input[type='file'][data-live-preview-target]")
    .forEach((input) => {
      if (input.dataset.boundPreview === "true") return;
      input.dataset.boundPreview = "true";

      const target = document.querySelector(input.dataset.livePreviewTarget);
      const fallback = input.dataset.livePreviewFallback
        ? document.querySelector(input.dataset.livePreviewFallback)
        : null;
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

const bindSearchableSelects = () => {
  const searchableKindTimezone = "timezone";

  const codeToFlag = (countryCode) => {
    if (!countryCode || countryCode.length !== 2) return "🌐";
    return countryCode
      .toUpperCase()
      .replace(/./g, (char) =>
        String.fromCodePoint(127397 + char.charCodeAt(0)),
      );
  };

  const flagForTimezone = (countryCode) => {
    if (!countryCode) return "🌐";
    return codeToFlag(countryCode);
  };

  const phonePrefixToTimezone = {
    "+1": "America/New_York",
    "+7": "Europe/Moscow",
    "+20": "Africa/Cairo",
    "+27": "Africa/Johannesburg",
    "+30": "Europe/Athens",
    "+31": "Europe/Amsterdam",
    "+32": "Europe/Brussels",
    "+33": "Europe/Paris",
    "+34": "Europe/Madrid",
    "+36": "Europe/Budapest",
    "+39": "Europe/Rome",
    "+40": "Europe/Bucharest",
    "+41": "Europe/Zurich",
    "+44": "Europe/London",
    "+45": "Europe/Copenhagen",
    "+46": "Europe/Stockholm",
    "+47": "Europe/Oslo",
    "+48": "Europe/Warsaw",
    "+49": "Europe/Berlin",
    "+52": "America/Mexico_City",
    "+55": "America/Sao_Paulo",
    "+60": "Asia/Kuala_Lumpur",
    "+61": "Australia/Sydney",
    "+62": "Asia/Jakarta",
    "+63": "Asia/Manila",
    "+64": "Pacific/Auckland",
    "+65": "Asia/Singapore",
    "+66": "Asia/Bangkok",
    "+81": "Asia/Tokyo",
    "+82": "Asia/Seoul",
    "+84": "Asia/Ho_Chi_Minh",
    "+86": "Asia/Shanghai",
    "+90": "Europe/Istanbul",
    "+91": "Asia/Kolkata",
    "+92": "Asia/Karachi",
    "+93": "Asia/Kabul",
    "+94": "Asia/Colombo",
    "+95": "Asia/Yangon",
    "+98": "Asia/Tehran",
    "+212": "Africa/Casablanca",
    "+213": "Africa/Algiers",
    "+216": "Africa/Tunis",
    "+230": "Indian/Mauritius",
    "+234": "Africa/Lagos",
    "+254": "Africa/Nairobi",
    "+255": "Africa/Dar_es_Salaam",
    "+351": "Europe/Lisbon",
    "+352": "Europe/Luxembourg",
    "+353": "Europe/Dublin",
    "+354": "Atlantic/Reykjavik",
    "+358": "Europe/Helsinki",
    "+359": "Europe/Sofia",
    "+380": "Europe/Kyiv",
    "+385": "Europe/Zagreb",
    "+386": "Europe/Ljubljana",
    "+420": "Europe/Prague",
    "+421": "Europe/Bratislava",
    "+852": "Asia/Hong_Kong",
    "+853": "Asia/Macau",
    "+855": "Asia/Phnom_Penh",
    "+856": "Asia/Vientiane",
    "+880": "Asia/Dhaka",
    "+886": "Asia/Taipei",
    "+960": "Indian/Maldives",
    "+961": "Asia/Beirut",
    "+962": "Asia/Amman",
    "+963": "Asia/Damascus",
    "+966": "Asia/Riyadh",
    "+971": "Asia/Dubai",
    "+972": "Asia/Jerusalem",
    "+974": "Asia/Qatar",
    "+975": "Asia/Thimphu",
    "+977": "Asia/Kathmandu",
    "+998": "Asia/Tashkent",
  };

  document
    .querySelectorAll("select[data-searchable-select='true']")
    .forEach((select) => {
      if (select.dataset.searchableBound === "true") return;
      select.dataset.searchableBound = "true";

      const options = Array.from(select.options)
        .filter((option) => option.value !== "")
        .map((option) => ({
          text: option.textContent,
          value: option.value,
          tzIdentifier: option.dataset.tzIdentifier || "",
          country: option.dataset.country || "",
          countryName: option.dataset.countryName || "",
          city: option.dataset.city || "",
          gmt: option.dataset.gmt || "",
        }));

      const wrapper = document.createElement("div");
      wrapper.className = "relative";

      const input = document.createElement("input");
      input.type = "text";
      input.autocomplete = "off";
      input.placeholder = select.dataset.searchPlaceholder || "Search";
      input.className =
        "w-full rounded-md border border-slate-300 px-3 py-2 text-sm";

      const list = document.createElement("div");
      list.className =
        "absolute z-20 hidden max-h-72 w-full overflow-y-auto rounded-b-md border border-t-0 border-slate-200 bg-white shadow-lg";

      const findOptionByValue = (value) =>
        options.find((option) => option.value === value);
      const selectedOption = findOptionByValue(select.value);
      if (selectedOption) input.value = selectedOption.text;

      const applyBrowserTimezoneSuggestion = () => {
        if (select.dataset.searchableKind !== searchableKindTimezone) return;
        if (select.dataset.browserTimezoneFallback !== "true") return;
        if (input.dataset.manualChanged === "true") return;
        if (select.value && select.value !== "UTC") return;

        const browserTimezone =
          Intl.DateTimeFormat?.().resolvedOptions?.().timeZone;
        if (!browserTimezone) return;

        const browserOption =
          findOptionByValue(browserTimezone) ||
          options.find((option) => option.tzIdentifier === browserTimezone);
        if (!browserOption) return;

        select.value = browserOption.value;
        input.value = browserOption.text;
        select.dispatchEvent(new Event("change", { bubbles: true }));
      };

      const closeList = () => {
        list.classList.add("hidden");
      };

      const renderList = (keyword = "") => {
        const term = String(keyword).trim().toLowerCase();
        const filtered = options
          .filter((option) => {
            if (!term) return true;

            const haystack = [
              option.text,
              option.value,
              option.city,
              option.country,
              option.countryName,
              option.gmt,
            ]
              .join(" ")
              .toLowerCase();

            return haystack.includes(term);
          })
          .slice(0, 80);

        list.innerHTML = "";
        filtered.forEach((option) => {
          const item = document.createElement("button");
          item.type = "button";
          item.className =
            "block w-full border-b border-slate-100 px-3 py-2.5 text-left text-sm transition-colors hover:bg-gray-100";

          if (select.dataset.searchableKind === searchableKindTimezone) {
            const city =
              option.city ||
              option.text.replace(/\s+\(GMT[+-]\d{2}:\d{2}\)$/, "").trim();
            const offset =
              option.gmt ||
              option.text.match(/\((GMT[+-]\d{2}:\d{2})\)$/)?.[1] ||
              "";
            const flag = flagForTimezone(option.country);

            const row = document.createElement("span");
            row.className = "flex items-center justify-between gap-3";

            const left = document.createElement("span");
            left.className = "flex items-center gap-2 text-slate-800";

            const flagNode = document.createElement("span");
            flagNode.className = "text-base leading-none";
            flagNode.textContent = flag;

            const cityNode = document.createElement("span");
            cityNode.className = "truncate";
            cityNode.textContent = city;

            const offsetNode = document.createElement("span");
            offsetNode.className = "text-xs font-medium text-slate-500";
            offsetNode.textContent = offset;

            left.appendChild(flagNode);
            left.appendChild(cityNode);
            row.appendChild(left);
            row.appendChild(offsetNode);
            item.appendChild(row);
          } else {
            item.textContent = option.text;
          }

          item.addEventListener("click", () => {
            select.value = option.value;
            input.value = option.text;
            input.dataset.manualChanged = "true";
            closeList();
            select.dispatchEvent(new Event("change", { bubbles: true }));
          });
          list.appendChild(item);
        });

        if (!filtered.length) {
          const empty = document.createElement("div");
          empty.className = "px-3 py-2 text-sm text-slate-500";
          empty.textContent = "No matching timezone";
          list.appendChild(empty);
        }

        if (list.firstChild && list.firstChild.classList) {
          list.firstChild.classList.remove("border-t");
        }

        list.classList.remove("hidden");
      };

      input.addEventListener("focus", () => renderList(input.value));
      input.addEventListener("input", () => renderList(input.value));
      input.addEventListener("keydown", (event) => {
        if (event.key === "Escape") closeList();
      });
      input.addEventListener("blur", () => {
        window.setTimeout(() => {
          const exact = options.find((option) => option.text === input.value);
          if (exact) {
            select.value = exact.value;
            select.dispatchEvent(new Event("change", { bubbles: true }));
          } else {
            const current = findOptionByValue(select.value);
            input.value = current ? current.text : "";
          }
          closeList();
        }, 120);
      });

      document.addEventListener("click", (event) => {
        if (!wrapper.contains(event.target)) closeList();
      });

      select.classList.add("hidden");
      select.setAttribute("aria-hidden", "true");
      select.tabIndex = -1;
      select.style.display = "none";
      select.parentNode.insertBefore(wrapper, select);
      wrapper.appendChild(input);
      wrapper.appendChild(list);

      const phoneSelector = select.dataset.phoneField;
      if (phoneSelector) {
        const phoneInput = document.querySelector(phoneSelector);
        if (phoneInput) {
          const applyPhoneSuggestion = () => {
            if (input.dataset.manualChanged === "true") return;

            const raw = String(phoneInput.value || "").trim();
            const prefix = Object.keys(phonePrefixToTimezone)
              .sort((a, b) => b.length - a.length)
              .find((key) => raw.startsWith(key));
            if (!prefix) return;
            if (select.value && select.value !== "UTC") return;

            const suggestedValue = phonePrefixToTimezone[prefix];
            const suggestedOption = findOptionByValue(suggestedValue);
            if (!suggestedOption) return;

            select.value = suggestedValue;
            input.value = suggestedOption.text;
            select.dispatchEvent(new Event("change", { bubbles: true }));
          };

          phoneInput.addEventListener("blur", applyPhoneSuggestion);
          phoneInput.addEventListener("change", applyPhoneSuggestion);
        }
      }

      applyBrowserTimezoneSuggestion();
    });
};

bindSearchableSelects();
window.bindSearchableSelects = bindSearchableSelects;
document.addEventListener("turbo:load", bindSearchableSelects);
document.addEventListener("turbo:frame-load", bindSearchableSelects);

if (!window.__searchableSelectStreamBound) {
  window.__searchableSelectStreamBound = true;
  document.addEventListener("turbo:before-stream-render", (event) => {
    const originalRender = event.detail.render;
    event.detail.render = (streamElement) => {
      originalRender(streamElement);
      window.queueMicrotask(() => {
        window.bindSearchableSelects?.();
      });
    };
  });
}

const getProductLightboxElements = () => {
  const lightbox = document.querySelector("[data-product-lightbox]");
  const previewImage =
    lightbox && lightbox.querySelector("[data-product-lightbox-image]");
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
      openProductLightbox(
        trigger.dataset.fullSrc,
        trigger.dataset.alt || "Product image",
      );
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

const bindFrameMotion = () => {
  if (window.__frameMotionBound) return;
  window.__frameMotionBound = true;

  const motionAllowed = () =>
    !window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  document.addEventListener("turbo:before-fetch-request", (event) => {
    const frame = event.target;
    if (!frame || frame.tagName !== "TURBO-FRAME") return;
    frame.classList.add("is-content-loading");
  });

  document.addEventListener("turbo:frame-load", (event) => {
    const frame = event.target;
    if (!frame || frame.tagName !== "TURBO-FRAME") return;
    frame.classList.remove("is-content-loading");

    if (!motionAllowed()) return;
    frame.classList.remove("is-content-enter");
    void frame.offsetWidth;
    frame.classList.add("is-content-enter");
    window.setTimeout(() => frame.classList.remove("is-content-enter"), 240);
  });
};

bindFrameMotion();
