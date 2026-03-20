# CSS Manual

This document is the single usage guide for project styling.

- Canonical app stylesheet: `app/assets/stylesheets/components.css`
- Public quote stylesheet: `app/assets/stylesheets/public_quote.css`
- Goal: predictable, component-first styling

## 1. Fast Onboarding

When adding UI, use this order:

1. Reuse existing UI partials in `app/views/components/ui/`.
2. Reuse helpers: `ui_button_classes`, `ui_input_classes`.
3. Reuse an existing class family in CSS.
4. Add a variant to an existing family if needed.
5. Create a new family only when reuse is not possible.

## 2. ERB Cookbook

### Buttons

```erb
<%= f.submit t("save"), class: ui_button_classes(:primary) %>
<%= link_to t("cancel"), path, class: ui_button_classes(:secondary) %>
<%= button_to t("delete"), path, method: :delete, class: ui_button_classes(:danger) %>
```

With feature-level adapter class:

```erb
<%= button_tag t("Run"), class: ui_button_classes(:secondary, "report-run-btn") %>
```

### Inputs

```erb
<%= f.text_field :name, class: ui_input_classes %>
<%= f.text_area :notes, rows: 4, class: ui_input_classes("notes-field") %>
```

### Shared button partial

```erb
<%= render "components/ui/button", href: some_path, variant: :secondary do %>
  Open
<% end %>
```

## 3. Canonical Families

1. Buttons
- `.app-ui-button`
- `.app-ui-button--primary`
- `.app-ui-button--secondary`
- `.app-ui-button--danger`
- `.app-ui-button--ghost`

2. Inputs
- `.app-ui-input`

3. Surfaces/layout
- `.app-surface`
- `.app-table-surface`
- `.app-page-shell`
- `.app-page-shell--form` (long-form page rhythm baseline)
- `.app-page-shell--customer-form`
- `.app-page-shell--customer-detail`
- `.app-page-shell--product-form`
- `.app-page-shell--settings-form`
- `.app-page-shell--template-form`
- `.app-page-header`
- `.app-toolbar-surface`

4. Quote-scope families
- `.quote-btn*`
- `.quote-toolbar*`
- `.quote-turnstile-modal*`
- `.quote-inline-*`, `.quote-diff-*` (revision diff presentation)
  - `.quote-inline-flag*` is a lightweight text annotation (no pill, no border, no separator glyph)
- `.quote-revision-*` (internal revision comparison panel and detail layout)
- `.quote-summary-*`, `.quote-collab-*` (internal webview default-focus + collapsible collaboration blocks)
- `.template-form-subgroup*` (template form grouping helper for long-form clarity)
- `.template-stage-*`, `.template-level-marker*`, `.template-editor-section--*` (template-new information-tier hierarchy adapters)

Quote families are local to quote workflows.

5. Dashboard-scope families
- `.dashboard-priority-layer*` (dashboard decision hierarchy layers: urgent/health/insight)
- `.dashboard-onboarding-secondary` (secondary treatment wrapper for setup/checklist modules)
- `.dashboard-module--urgent`
- `.dashboard-module--snapshot`
- `.dashboard-module--insight`
- `.dashboard-urgent-composition`, `.dashboard-urgent-main`, `.dashboard-urgent-rail` (composed urgent group layout)
- `.dashboard-side-module*` (stable compact-summary system for variable-density urgent side rail content)
- `.dashboard-urgent-main-primary` (left primary stack in urgent composition to avoid blank compensation area)
- `.dashboard-report-compact-summary` (folded owner-workload signal inside portfolio report card)
- `.dashboard-overview-snapshot` (balanced compact composition for right-side overview signals)
- `.dashboard-report-silent-group*` (silent-customer insight merged into customer portfolio grouping)
- `.dashboard-notes-*` (global personal notes widget, localStorage-backed, draggable panel, user-owned scratchpad)

Dashboard families are local to dashboard sequencing and must not be reused as global card primitives.

6. Scoped exception families
- When a UI block has a clearly different product role and tone (for example, a personal sticky-note rail that is intentionally non-system), it may use a dedicated feature family instead of force-fitting existing card/form families.
- This exception must remain strictly scoped by feature prefix and ownership boundaries. Example: `.dashboard-notes-*` is mounted globally for signed-in pages, but should not leak into other feature families or become generic card primitives.
- Do not create broad global overrides for this exception type; keep tokens restrained and compatible with admin baseline.

## 4. CSS Layer Contract

Keep `components.css` ordered as:

1. Tokens/theme variables
2. Base shell/layout
3. Primitives (`.app-ui-button`, `.app-ui-input`)
4. Reusable components (cards, tables, toolbars, modals)
5. Page scopes (`.app-page-shell--*`, `.marketing-root *`, etc.)
6. Responsive sections (`@media`)
7. Temporary compatibility section (shrinking over time)

If a selector appears in multiple sections, consolidate into one canonical block.

## 5. Naming Rules

1. App-wide reusable classes use `app-` prefix.
2. Feature-local classes keep feature prefix (`quote-`, `dashboard-`, `customer-`, `marketing-`).
3. Variants/states use `--variant` or `.is-state`.
4. Avoid ambiguous names like `.panel2`, `.custom-btn`, `.temp-style`.

## 6. Usage Rules

1. Keep ERB on helper-generated base classes.
2. Use feature classes as adapters for local spacing/size/layout only.
3. If JavaScript creates buttons at runtime, generate class strings with helper output instead of hardcoded utility strings.
4. Remove dead selectors when references reach zero.
5. Do not stack new page overrides on top of known conflicting historical rules in the same scope; consolidate first.
6. For any edited component/page scope, prefer one canonical selector block at the end state (avoid multi-era duplicate rule chains).
7. If a selector is functionally replaced, delete or merge the old selector in the same change when safe.
8. If a component is approved as a scoped exception family (personal widget / sticky utility), do not force it into existing app-card/app-form primitives; keep it isolated and documented.

## 7. Component Index

1. Form submit/action button
- Use: `ui_button_classes(:primary|:secondary|:danger|:ghost)`
- Example pages: auth forms, team members, presets

2. Text input/select/textarea
- Use: `ui_input_classes`
- Example pages: customer form, product form, quote form

3. Page containers/sections
- Use: `.app-page-shell`, `.app-surface`, `.app-table-surface`
- Example pages: dashboard, customers, products

4. Quote workspace toolbar/actions
- Use: `ui_button_classes(...) + quote-btn quote-btn-*`
- Example: `app/views/quotes/_show_content.html.erb`

5. Public quote actions
- Use: `ui_button_classes(...)` plus public-page adapter class (for example `.quote-utility-btn`)
- Example: `app/views/public/quote_shares/show.html.erb`

6. Settings long-form subsections
- Use: `.settings-subsection`, `.settings-subsection--spaced` inside settings panels to reduce nested box heaviness.
- Example: `app/views/company_settings/edit.html.erb`

## 8. Scenario Quickstart

1. New form page
- Shell: `.app-page-shell` + `.app-surface`
- For long admin forms, prefer `.app-page-shell app-page-shell--form` and add a page-specific modifier when available.
- Inputs: `ui_input_classes`
- Actions: primary submit + secondary cancel via `ui_button_classes`

2. Data table/list page
- Wrap table in `.app-table-surface`
- Keep row actions on canonical helper buttons
- Add feature class only for local spacing/width tuning

3. Modal/dialog actions
- Use existing modal family (`quote-turnstile-modal*` or other established family)
- Use canonical helper buttons for confirm/cancel
- For runtime-created actions, use helper-generated class strings

## 9. Frontend JS Utilities

These small JS tools are in `app/javascript/controllers/` (Stimulus).

1. Tooltip (`tooltip_controller.js`)
- Purpose: show hover tooltip text
- Markup:
```erb
data-controller="tooltip"
data-tooltip-content-value="Shortcut: Shift+P"
data-action="mouseenter->tooltip#show mouseleave->tooltip#hide"
```
- Style hook: `.app-tooltip` in `app/assets/stylesheets/components.css`

2. Clipboard (`clipboard_controller.js`)
- Purpose: copy text and show toast result
- Markup:
```erb
data-controller="clipboard"
data-clipboard-text-value="..."
data-action="click->clipboard#copy"
```

3. Shortcuts (`shortcuts_controller.js`)
- Purpose: global keyboard shortcuts + command palette + help modal
- Usually mounted once at page/root level for signed-in app pages

4. Sortable (`sortable_controller.js`)
- Purpose: drag-sort customer tags and persist order
- Depends on `sortablejs`
- Emits event: `sortable:reordered`

5. Marketing switcher (`marketing_switcher_controller.js`)
- Purpose: tab/panel switcher with keyboard navigation
- Uses `data-state-key`, `tabTargets`, `panelTargets`

## 10. PR Checklist

1. Search class usage with `rg` in `app/views` and stylesheet files.
2. Confirm no duplicate selector blocks were introduced.
3. Check responsive behavior for edited families.
4. Remove dead selectors in the same change when safe.
5. For edited scopes, remove/merge conflicting historical overrides so the final cascade is intentional and minimal.
6. Update this manual when conventions change.
7. If a CSS change no longer matches this manual, update this file in the same PR.

## 11. What Not To Do

1. Do not add broad global overrides for local visual fixes.
2. Do not create one-off page selectors when a family can be reused.
3. Do not create parallel button systems.
4. Do not hardcode long utility class strings in JS when helper output is available.
5. Do not force `white-space: nowrap` on descriptive text in mobile cards/lists unless truncation is explicitly required.
