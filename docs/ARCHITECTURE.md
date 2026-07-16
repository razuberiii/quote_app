# Architecture

Rails 8.1, Hotwire/Stimulus, PostgreSQL, Solid Queue/Cache/Cable, Active Storage and server-rendered HTML form the application. `Company` is the workspace boundary. Controllers always load seller records through `current_user.company`; public actions resolve a cryptographically random `QuoteRevision#secure_token` and then validate revision actionability.

Existing customers, products, quotes, items, uploads, PDF/Excel and mail assets remain migration sources. New immutable records are `QuoteRevision`, `QuoteAcceptance` and `ProformaInvoice`. Buyer interactions and activities carry workspace and revision foreign keys plus database-enforced idempotency/deduplication keys.
