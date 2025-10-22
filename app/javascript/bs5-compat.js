// Bootstrap 5 compatibility helpers for legacy Bootstrap 4 markup/APIs
// - Translate data-toggle/target/dismiss to data-bs-*
// - Provide a minimal jQuery plugin shim for tooltip()

import * as bootstrap from "bootstrap";

function migrateDataAttributes(root = document) {
  const mappings = [
    ["toggle", "bs-toggle"],
    ["target", "bs-target"],
    ["dismiss", "bs-dismiss"],
    ["placement", "bs-placement"],
    ["container", "bs-container"],
  ];

  mappings.forEach(([oldKey, newKey]) => {
    const selector = `[data-${oldKey}]`;
    root.querySelectorAll(selector).forEach((el) => {
      const oldAttr = `data-${oldKey}`;
      const newAttr = `data-${newKey}`;
      if (!el.hasAttribute(newAttr)) {
        const val = el.getAttribute(oldAttr);
        el.setAttribute(newAttr, val);
      }
    });
  });
}

function initTooltips(root = document) {
  // Initialize tooltips for any element that declares tooltip via either data-toggle or data-bs-toggle
  const candidates = Array.from(
    new Set([
      ...root.querySelectorAll('[data-bs-toggle="tooltip"]'),
      ...root.querySelectorAll('[data-toggle="tooltip"]'),
      ...root.querySelectorAll('label[data-toggle="tooltip"]'),
    ]),
  );
  candidates.forEach((el) => {
    // Avoid double init: store instance on element
    let instance = bootstrap.Tooltip.getInstance(el);
    if (!instance) {
      const title = el.getAttribute("data-original-title") || el.getAttribute("title") || undefined;
      const trigger = el.getAttribute("data-trigger") || undefined; // e.g., 'hover'
      const options = {};
      if (title) options.title = title;
      if (trigger) options.trigger = trigger;
      try {
        new bootstrap.Tooltip(el, options);
      } catch (e) {
        // ignore
      }
    }
  });
}

function installjQueryTooltipShim() {
  const $ = window.jQuery || window.$;
  if (!$) return;

  // If bootstrap 4 plugin exists, do nothing
  if ($.fn && $.fn.tooltip && $.fn.tooltip.Constructor) return;

  $.fn.tooltip = function (arg) {
    // Support basic .tooltip('enable'|'disable'|'dispose') and init with options
    return this.each(function () {
      const el = this;
      let instance = bootstrap.Tooltip.getInstance(el);
      if (typeof arg === "string") {
        if (instance) {
          switch (arg) {
            case "enable":
              instance.enable();
              break;
            case "disable":
              instance.disable();
              break;
            case "dispose":
              instance.dispose();
              break;
            case "show":
              instance.show();
              break;
            case "hide":
              instance.hide();
              break;
            default:
              break;
          }
        } else if (arg === "enable") {
          // if no instance, create one
          instance = new bootstrap.Tooltip(el);
        }
      } else {
        // Treat as options
        const options = arg || {};
        if (!instance) {
          new bootstrap.Tooltip(el, options);
        }
      }
    });
  };
}

function compatInit(root = document) {
  migrateDataAttributes(root);
  initTooltips(root);
  installjQueryTooltipShim();
}

document.addEventListener("DOMContentLoaded", () => compatInit());
document.addEventListener("turbo:load", () => compatInit());
document.addEventListener("turbo:before-render", (e) => compatInit(e?.data?.newBody || document));

export { compatInit, migrateDataAttributes, initTooltips };
