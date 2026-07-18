# Architecture

Rails 8.1, Hotwire/Stimulus, PostgreSQL, Solid Queue/Cache/Cable, Active Storage and server-rendered HTML form the application. `Company` is the workspace boundary. Controllers always load seller records through `current_user.company`; public actions resolve a cryptographically random `QuoteRevision#secure_token` and then validate revision actionability.

Existing customers, products, quotes, items, uploads, PDF/Excel and mail assets remain migration sources. New immutable records are `QuoteRevision`, `QuoteAcceptance` and `ProformaInvoice`. Buyer interactions and activities carry workspace and revision foreign keys plus database-enforced idempotency/deduplication keys.
# AI inquiry extraction

`InquiryAiExtractor` and `CatalogAiExtractor` call an OpenAI-compatible Chat Completions endpoint and return constrained JSON structures. Provider settings are supplied only through `OPENAI_API_KEY`, `OPENAI_BASE_URL`, and `OPENAI_MODEL`; secrets must never be committed. The configured model must be verified with both a basic completion and `response_format: json_schema`, because a model can appear in `/models` while its completion route still returns 503. Extraction never invents prices or freight amounts and falls back to manual review when the provider is unavailable.
