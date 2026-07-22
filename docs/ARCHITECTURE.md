# Architecture

Rails 8.1, Hotwire/Stimulus, PostgreSQL, Solid Queue/Cache/Cable, Active Storage and server-rendered HTML form the application. `Company` is the workspace boundary. Controllers always load seller records through `current_user.company`; public actions resolve a cryptographically random `QuoteRevision#secure_token` and then validate revision actionability.

Existing customers, products, quotes, items, uploads, PDF/Excel and mail assets remain migration sources. New immutable records are `QuoteRevision`, `QuoteAcceptance` and `ProformaInvoice`. Buyer interactions and activities carry workspace and revision foreign keys plus database-enforced idempotency/deduplication keys.

## Buyer-facing language

Seller workspace locale and buyer output locale are separate concerns. `Quote#buyer_locale` selects the customer language for that commercial record; publishing copies it into the immutable revision snapshot. Buyer Room previews, public Buyer Room requests and generated buyer PDFs resolve locale from the quote/revision instead of the signed-in seller. Supported buyer locales are `en`, `zh-CN`, and `es-419`; English remains the safe default for external quotations.
# AI inquiry extraction

`InquiryAiExtractor`, `CatalogAiExtractor`, and `CompanyProfileAiExtractor` call an OpenAI-compatible Chat Completions endpoint and return constrained JSON structures. Provider settings are supplied only through `OPENAI_API_KEY`, `OPENAI_BASE_URL`, and `OPENAI_MODEL`; secrets must never be committed. The configured model must be verified with both a basic completion and `response_format: json_schema`, because a model can appear in `/models` while its completion route still returns 503. Extraction never invents prices, freight amounts, or missing company facts and falls back to manual review when the provider is unavailable.

All AI imports obey the same write boundary: the model response is validated against `StructuredSchemas`, stored as candidate data, and presented on a second-level review screen. AI services never update `Company`, `Product`, `Quote`, or other commercial records directly. Unknown values are explicit `null` values; blank reviewed candidates do not overwrite existing company facts. Company profile imports accept pasted text or readable PDF/TXT/CSV content, retain the source record, and only apply the allowlisted company fields after an authorized workspace manager confirms them.

## Quote-only commercial core

`Quote` is the only seller-facing commercial aggregate. Customers and Library data exist only to prepare quotes; Inbox, Deal pipeline, separate Files and template CRUD are not navigation concepts. Legacy `/inbox`, `/deals`, and `/quote_templates` URLs redirect into the canonical Quote or Document design surfaces while old database tables may remain until a destructive schema cleanup is justified.

Publishing creates an immutable `QuoteRevision`. `QuoteSnapshotBuilder` freezes buyer data, seller identity, document design, customer language, line items and commercial terms. Customer page, PDF and Excel render from that same snapshot. PDF and Excel are first-level version downloads rather than delivery side effects.

Document design is one workspace profile made of brand rules, one curated layout recipe, content defaults and channel-specific language. It replaces multiple user-managed templates. Per-quote editing owns commercial content; publication freezes the resolved result so future settings changes cannot rewrite an issued quote.
