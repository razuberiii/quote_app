# Rubusoo design system

The commercial product uses one visual language: **Rubusoo Neo Commerce OS**. Seller workflows use a five-level graphite system (`Canvas`, `Shell`, `Surface`, `Elevated`, `Signal`) with Electric Blue for action, Rubus Red for attention, Signal Green for confirmed outcomes, precise typography, and compact controls. Light surfaces are reserved for buyer-facing or immutable document semantics. New product surfaces use `app/assets/stylesheets/rubusoo.css`; legacy selectors in `components.css` and `public_quote.css` are migration-only and must not be introduced into new pages.

Core tokens are the `--rb-*` family, with compatibility aliases for `--canvas`, `--paper`, `--ink`, `--muted`, `--line`, `--brand`, `--action`, `--success`, and `--danger`. Interactive actions use Rubusoo green; coral is reserved for deal attention and editorial punctuation.

Visual convergence contract: authenticated pages are audited as a dark operating surface. A light area wider than 520px and taller than 160px is considered a visual leak unless it is inside `.studio-paper`, `.pi-document`, `.final-document`, `.document-preview`, or `.buyer-storefront`. Shared overlays use `.neo-modal`, `.neo-modal__panel`, and `.neo-modal__state`; inline modal presentation styles are not allowed. The automated full-site crawler records overflow, clipped text, broken images, and light-surface leaks at 1440, 390, and priority 360/412 widths before a visual baseline may be updated.

Signature motion uses the same motion tokens as application feedback. `.kinetic-headline__window` owns the marketing phrase transition; Smart Intake retains evidence/extraction motion; `.studio-save-state` owns Dirty → Saving → Saved feedback; and `.channel-flow` owns delivery preparation/failure feedback. Every signature animation must have a non-animated `prefers-reduced-motion` state with identical content and controls.

Canonical primitives are `.button` with `--primary`, `--secondary`, `--ghost`, and `--full` modifiers; `.input`; `.textarea`; `.field-label`; `.status`; `.rubusoo-dialog`; `.brand`; `.eyebrow`; and `.section-kicker`. Marketing campaign structures use `marketing-`; pricing and guided demo structures use `rb-`; buyer-facing structures use `buyer-`; inquiry workflow uses `inquiry-`; and authenticated product pages use `rubusoo-`. Do not add Bootstrap-style dashboard patterns, generic utility-card grids, decorative glass effects, or alternate button/input systems.

Buyer Room is mobile-first below 860px. Its selection panel becomes a fixed bottom action bar. All focusable controls require a visible blue focus ring. Amounts use tabular numerals. Customer-facing long values must wrap safely.

Inquiry import and review use the `inquiry-import__*` and `inquiry-review__*` families. The review is evidence-led: source content remains in a sticky paper panel, extracted fields use quiet inline status text, Catalog candidates are rows rather than generic cards, and all monetary confirmation is grouped in a dark commercial band. On narrow screens the source becomes a bounded preview above the editable results.

Quote Studio uses `quote-studio--editor` with three true functional columns. The center `studio-paper` is the buyer document itself and owns inline editing; the left outline is navigation/readiness, and the right summary is commercial validation. Do not render the legacy `.quote-edit-shell` inside this surface.

Buyer Room uses `buyer-storefront` as a branded commercial microsite: editorial cover, visual product stories, working selections, plan comparison, commercial terms, and a dark sticky decision summary. Desktop retains a sticky side summary; below 980px it becomes a bottom decision bar. Dialogs must preserve the selected plan, quantities, and accessories without mutating the formal Revision.

Revision comparison uses paired `revision-values` and `revision-item-diff` columns; never expose raw snapshot JSON. PI uses the print-safe `pi-document` hierarchy and must always render from the immutable acceptance snapshot.

Delivery, response review, and document evidence use the `channel-flow`, `response-review`, and `documents-hub` families. System-executed delivery must never expose a user-selectable success state. Returned file differences are compact semantic rows, and unsafe workbook cells use a dedicated non-actionable signal. The Documents hub groups Published quote files, Buyer files, and Final documents without introducing a global Files module.

The remainder of this document describes legacy families retained only while old pages are replaced.

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
  - `.quote-summary-strip--internal` should read as a lightweight internal meta row (document-to-workflow bridge), not as dashboard-like KPI widgets.
- `.quote-internal-*` (internal webview semantic renderers: `summary` / `facts` / `table` / `settlement` / `gallery` / `matrix` / `list` / `footer`; used only for internal quote reading flow, not for PDF/public/excel)
  - second-pass tightening rule: preserve renderer types, prioritize reading hierarchy (`status` first, `buyer > quote info > seller`), keep items as commercial rows with lightweight subordinate spec/add-on details, treat formal closing and footer as low-emphasis reference blocks.
  - settlement placement rule: internal settlement totals are rendered as the `quote-internal-items-footer` inside the items block (right-aligned on desktop, stacked on narrow screens), not as a separate standalone section.
  - disclosure tightening rule: any internal “more/collapse” trigger must be a bottom control row (`quote-inline-disclosure*`), never inserted between content items.
- `.quote-workspace-*` (internal quote webview layer boundary: document body vs. internal workflow summary/actions/history)
- `.quote-form-advanced*` (advanced quote section local spacing/typography overrides; used to neutralize global hint offsets and keep advanced subsection rhythm readable)
- `.quote-advanced-module-*` (extended module editors in quote form: lightweight configuration rows and detail-picture mixed-source rows; detail list uses `quote-advanced-module-list--detail-pictures` card-grid variant)
- `.quote-preset-control*`, `.js-fee-preset-controls` (module preset selector wrapper/hint/clear affordance and local spacing rhythm in quote form)
- `.quote-preset-library*`, `.quote-preset-row-menu*` (quote preset library table refinement: name/meta stack, position pill, primary action + more-actions dropdown)
- `.quote-signature-image-preview*` (formal closing signature/stamp upload preview with top-right remove affordance in quote/preset editors)
- `.quote-advanced-module-row--loading`, `.quote-mini-table*` (container-loading lightweight matrix editor + shared compact table rendering for module blocks)
- `.quote-detail-batch-preview*`, `.quote-detail-item-preview*` (detail pictures batch upload preview merges into the same card-grid container as selected detail rows; supports per-image removal before submit)
- `.quote-detail-gallery-*` (detail pictures picker panel that previews only currently selected quote-item products and supports card-highlight multi-select / select-all toggle without checkbox UI)
- `.quote-form-collapsible*`, `.template-editor-summary*` (details/summary based collapsible cards for quote/template long-form editors)
- `.quote-supp-*` (PDF-only supplementary terms/logistics key-value presentation used by `export_pdf` for formal document readability polish)
- PDF flow contract (`quotes/export_pdf` + `layouts/pdf`): first page is fixed formal quotation structure (header/meta, buyer block, items table, right-aligned totals, brief notes, one-line footer). Annex sections start on page 2+ and render only when data exists.
- PDF section/title contract: remove repeated “SUPPLEMENTARY” kicker usage in PDF output; annex sections use single uppercase section titles with unified bordered title/body treatment.
- PDF detail pictures contract: only render when filtered detail cards still exist after removing main table representative images; keep stable 2-column rows with final single-image row centered when needed.
- PDF formal quote table contract: export PDF main items table uses `No. / Item Details / Qty / Unit Price / Amount` (no standalone `Image` column). Item image, when present, is rendered inside `Item Details` as a left mini column; no-image rows consume full detail width.
- PDF signature/footer contract (Grover): signature/stamp images in PDF should use inline data URI to avoid browser fetch misses; footer typography is defined in Grover `footerTemplate` and should match document sans stack.
- PDF first-page settlement contract: totals use a light boxed block (soft outer border + light row dividers + emphasized grand-total separator) to keep hierarchy without heavy grid feel; the commercial summary strip remains value-only and rhythm-led (no empty placeholder cells).
- Long-value policy in quote supplementary/term blocks: prefer `overflow-wrap: anywhere` for customer-facing document values to avoid layout break on unspaced strings.
- `.quote-detail-picture-*`, `.quote-detail-pictures-grid` (shared detail-pictures section rendering across internal/public/PDF with stable 3-column baseline)
- `.quote-public-*` (buyer-facing public quote structure: hero, facts, commercial core, settlement, signoff, and public system state; used only in `public_quote.css`)
  - settlement placement rule: public settlement renders as a narrowed totals block inside the items card footer (`quote-public-core-footer`), right-aligned on desktop and full-width stacked on narrow screens.
  - item subdetail rhythm rule: `Spec / Add-on` in public item rows should keep compact spacing (tight label-to-first-row and row-to-row gaps), stable key/value scan alignment, and light group separation (not card-like breaks).
  - high-alignment rule: when public item subdetails are tightened to internal baseline, reuse internal geometry (`minmax(72px, 30%)` key/value grid, compact 0.06~0.08 vertical rhythm) while preserving public’s lighter color weight and no-disclosure behavior.
  - item image rule: public items table must render product thumbnails inside a dedicated wrapper (`quote-public-item-image-wrap` + `quote-public-item-image`) so row height is controlled by content rhythm, not raw image natural size.
  - row hierarchy rule: public items rows should expose product vs charge rhythm via row classes (`quote-public-row--product` / `quote-public-row--charge`) without changing business semantics.
  - no-placeholder image rule: public items no longer reserve an empty image slot for no-image fee rows; image appears only inside item details when a real product image exists.
  - watermark layering rule: public watermark state must be mounted on `.public-quote-document.quote-watermarked` (not outer canvas), and image watermark must use `.quote-public-watermark-image` so stacking remains consistent above all section content including detail pictures.
- `.quote-internal-document-body` watermark contract: internal webview watermark is mounted at this body wrapper (`quote-watermarked` + optional `.quote-internal-watermark-image`) so overlay behavior is isolated from template-preview/public watermark selectors.
- `.quote-items-table--internal` item-details image rule: internal webview follows the same inline-image contract as PDF/public (`has-inline-image` with a fixed wrapper), and fee rows keep full-width details with no fake thumbnail slot.
- `.quote-item-kind*` (lightweight item-type marker for product vs fee rows in formal quote tables)
- `.quote-item-row--fee` (quote form row variant for logistics/fee items; hides spec/add-on columns and keeps manual fee-row editing compact)
- `.template-form-subgroup*` (template form grouping helper for long-form clarity)
- `.template-advanced-defaults-*` (opt-in advanced quote defaults split layout in template editor: trade/logistics subgroup readability)
- `.template-stage-*`, `.template-level-marker*`, `.template-editor-section--*` (template-new information-tier hierarchy adapters)

Quote families are local to quote workflows.

5. Dashboard-scope families
- `.dashboard-priority-layer*` (dashboard decision hierarchy layers: urgent/health/insight)
- `.dashboard-onboarding-secondary` (secondary treatment wrapper for setup/checklist modules)
- `.dashboard-module--urgent`
- `.dashboard-module--snapshot`
- `.dashboard-module--insight`
- `.dashboard-urgent-composition`, `.dashboard-urgent-main` (composed urgent group layout)
- `.dashboard-decision-*` inside sales signals should keep a unified summary-column syntax; avoid per-column inner widget blocks (including attention signal).
- `.dashboard-side-module*` (stable compact-summary system for variable-density urgent side rail content)
- `.dashboard-urgent-main-primary` (left primary stack in urgent composition to avoid blank compensation area)
- `.dashboard-kpi-matrix` (quiet 3x2 metric matrix in analysis layer)
- `.dashboard-metric-overview*` (single-panel quiet metrics system: 4 core metrics + lightweight mix trend)
- `.dashboard-analysis-table*`, `.dashboard-top-products-table*` (unified insight-table language for revision depth + top quoted products; shared header/row density and numeric alignment)
- shared bar tokens under dashboard scope (`--dashboard-bar-*`) unify metric mix bars, win/loss distribution bars, and funnel micro-progress tracks
- `.dashboard-analysis-grid` (desktop-first 2x2 deep-analysis layout; collapses to single-column on small screens)
- `.sales-insight-card--dual`, `.sales-insight-win-loss-dual` (paired win/loss distribution panel with fixed-height balanced halves)
- `.sales-insight-summary-strip*`, `.sales-insight-winrate-*` (light revision-depth summary row + mini win-rate bar in analysis table)
  - `sales-insight-summary-strip*` should stay as slot rows (light separators), not inner mini-card blocks.
- `.dashboard-report-compact-summary` (folded owner-workload signal inside portfolio report card)
- `.dashboard-overview-snapshot` (balanced compact composition for right-side overview signals)
- `.dashboard-report-silent-group*` (silent-customer insight merged into customer portfolio grouping)
- `.dashboard-notes-*` (global personal notes widget, localStorage-backed, draggable panel, user-owned scratchpad)

Dashboard families are local to dashboard sequencing and must not be reused as global card primitives.

6. Team-scope families
- `.team-member-profile-*` (team member detail card layout, avatar + key info blocks)
- `.team-members-table*` (team management table + mobile card transform for member/invitation rows)

Team families are local to team management pages.

7. Admin Console helpers (minimal)
- Prefer canonical families for admin pages: `.app-page-shell`, `.app-surface`, `.app-table-surface`, `.app-ui-button`, `.app-ui-input`.
- Keep admin-specific classes only as narrow helpers where canonical classes are insufficient:
  - `.admin-impersonation-banner*` (banner layout helper)
  - `.admin-navbar-container` (admin nav width adapter, admin-only)
  - `.admin-users-actions*` (row action wrapping/alignment)
  - `.admin-users-action-card*` (row-level expandable action card in admin users table)
  - `.admin-table-scroll` (admin table horizontal overflow wrapper)
  - `.admin-json-cell` (long metadata wrapping)
  - `.admin-kv-*` (user detail key-value card grid)
  - `.admin-page-shell*` / `.admin-dashboard-stat-grid` (admin-only width/readability adapters layered on top of canonical `app-*` shells and `app-stat-*` cards)

Do not create a parallel admin visual system unless explicitly approved.

8. Product-scope families
- `.product-gallery-*` (product media editor/gallery cards; selection uses card highlight state + round indicator and avoids visible checkbox UI; staged upload preview reuses the same gallery card language)
- `.product-preset-library*` (spec/add-on preset library table refinement aligned with quote preset visual language: readable name/value cells and right-side action group)
- `.product-lightbox*` (global image-preview overlay; mounted as a body-level singleton so backdrop always covers full viewport across product and quote detail-picture triggers)

9. Scoped exception families
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

7. Filter pills
- Use: `.app-filter-pill`, `.app-filter-pill--kpi`
- Canonical source: `app/assets/stylesheets/components.css` (do not redefine this family in `app/assets/tailwind/application.css`)

## 8. Motion Tokens

Use shared motion tokens from `:root` in `components.css`:

- `--motion-duration-fast`
- `--motion-duration-base`
- `--motion-duration-slow`
- `--motion-ease-standard`
- `--motion-ease-emphasized`

Rules:

1. New transitions/animations in app-level reusable components must use motion tokens.
2. Do not hardcode random one-off durations/easing in canonical families when a token is suitable.
3. Keep motion subtle and state-driven; avoid decorative motion loops in CRUD surfaces.

## 9. Scenario Quickstart

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

## 10. Frontend JS Utilities

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

6. App shell (`app_shell_controller.js`)
- Purpose: signed-in shell interaction wiring (navbar toggle, nav group/account dropdown interactions, locale/notification close behaviors, dirty-form guards, global app toast API, notification polling).
- Mounted on `<body>` as `data-controller="app-shell"` with optional values:
  - `data-app-shell-unread-count-url-value`
  - `data-app-shell-notification-loading-text-value`
  - `data-app-shell-dirty-confirm-text-value`

7. Dashboard actions (`dashboard_actions_controller.js`)
- Purpose: animate/collapse “show more / show less” stacks in dashboard action blocks.
- Markup contract:
  - expandable block: `data-expand-id="..."`
  - toggle button: `data-action-toggle` or `data-action-items-toggle` + matching `data-expand-id`
  - container values: `data-dashboard-actions-show-less-label-value`, `data-dashboard-actions-show-more-template-value`
- Motion timing/easing source: reads `--motion-duration-*` and `--motion-ease-*` tokens from `:root` (no controller-local hardcoded rhythm).

8. Dashboard enhance (`dashboard_enhance_controller.js`)
- Purpose: add lightweight premium motion on dashboard (KPI count-up).
- Markup contract:
  - mount on dashboard root: `data-controller="dashboard-enhance"`
  - count targets: `data-dashboard-enhance-target="count"` + `data-count-final`

9. Global frame motion (`app/javascript/application.js`)
- Purpose: smooth `turbo-frame` content refresh transitions for filter/list-like interactions.
- Hooks:
  - add loading class on `turbo:before-fetch-request`
  - add enter transition class on `turbo:frame-load`
- CSS hooks in `components.css`: `turbo-frame.is-content-loading`, `turbo-frame.is-content-enter`

## 11. PR Checklist

### Commercial PDF document

- `.commercial-pdf` is the snapshot-only quotation PDF family used by Buyer Room downloads.
- `.pi-document` is the immutable acceptance/PI document family and must remain print-safe.
- Totals and commercial term blocks use `break-inside: avoid`; internal notes never enter either document.
- `.commercial-flow` is the seller-side readiness/revision/activity handoff placed above legacy document tools.
- `.buyer-inbox` groups contextual buyer questions, revision requests, and immutable acceptance actions.
- `.seller-demo` is the public, read-only commercial-flow tour; its sections mirror real seller concepts and collapse to a single mobile column.
- `.product-landing` owns the marketing narrative; `.product-hero__product`, `.feature-extract`, `.feature-studio`, and `.feature-buyer` are product UI compositions, not generic card primitives.
- Buyer Room is layout-independent: `.buyer-body`, `.buyer-cover`, `.buyer-grid`, `.doc-section`, `.selection-panel`, and `.rubusoo-dialog` provide the complete public baseline before storefront variants.

### Neo Commerce OS visual scope

- `.neo-os` is the sole visual-system boundary for Rubusoo V2. Layouts add one surface modifier: `.neo-os--marketing`, `.neo-os--app`, or `.neo-os--buyer`.
- Tokens use graphite surfaces with electric blue actions, Rubus red identity, signal green decisions, and cyan data signals. Amounts always use tabular numerals.
- V2 uses background level, one-pixel dividers, grid and typography for hierarchy. A content region may have one primary border; nested rounded card stacks are prohibited.
- Standard control radius is `8px`, panels are `10px–12px`, and larger radii are reserved for dialogs only. V2 styles must not use `!important` to defeat legacy rules.
- Marketing product compositions are connected panels at desktop sizes and become ordinary full-width responsive sections below `760px`; they never use device or browser mockup frames.
- Seller pages use a graphite OS shell. Quote Studio owns a dark structure rail, a light buyer-facing canvas and a dark command rail.
- Quote Studio kickers on graphite surfaces use the accessible signal-blue token (`#8aa7ff`); darker document-blue is reserved for light canvas surfaces.
- Buyer Room owns a light premium storefront plus graphite selection rail. Below `1100px` the summary becomes a true viewport-bottom action bar and the document receives matching bottom clearance.
- Buyer Room light surfaces use document-blue (`#315fdc`) and dark Rubus red (`#b8244c`) for small signal text; cyan and bright red are reserved for graphite surfaces so WCAG contrast remains intact.
- Mobile verification widths are `360px`, `390px`, and `412px`; page gutters are `16px–18px`, never a scaled desktop viewport.

### Deal-first workspace

- `.deal-workspace` is the shared page boundary for Inbox, Deals, Deal detail and Library.
- `.inbox-event`, `.deal-row` and `.deal-primary-action` all render the same `DealProgress` result; visual wording must not invent a second Next action.
- `.deal-stage--draft|live|accepted|closed` exposes only four stages. Detailed quote states belong in activity signals and conditions.
- `.deal-tabs` owns Overview, Quote, Conversation, Versions and Documents within one Deal. These are contextual views, not primary navigation.
- `.deal-motion` uses a short staggered entry animation for actionable Inbox items. Motion is disabled by the global reduced-motion rule.
- Ordinary Deal surfaces remain graphite. Light surfaces are reserved for Quote Studio canvas, Buyer Room light theme, PI and printable documents.
- `.channel-flow` and `.context-form` are the canonical channel-neutral workflow surfaces for Delivery, buyer Response and seller-recorded Acceptance. They use the existing button/input primitives, graphite surface hierarchy and shared motion tokens.
- `.channel-picker` is a flat connected decision grid, not a card collection. Selecting a channel moves the signal edge and updates whether Buyer Room view activity is available.
- Delivery/Acceptance forms become one-column, nearly full-width workflows below `900px`; no desktop modal is scaled down on mobile.

1. Search class usage with `rg` in `app/views` and stylesheet files.
2. Confirm no duplicate selector blocks were introduced.
3. Check responsive behavior for edited families.
4. Remove dead selectors in the same change when safe.
5. For edited scopes, remove/merge conflicting historical overrides so the final cascade is intentional and minimal.
6. Update this manual when conventions change.
7. If a CSS change no longer matches this manual, update this file in the same PR.

## 12. What Not To Do

1. Do not add broad global overrides for local visual fixes.
2. Do not create one-off page selectors when a family can be reused.
3. Do not create parallel button systems.
4. Do not hardcode long utility class strings in JS when helper output is available.
5. Do not force `white-space: nowrap` on descriptive text in mobile cards/lists unless truncation is explicitly required.
