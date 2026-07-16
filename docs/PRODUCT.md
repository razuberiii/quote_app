# Rubusoo product

Rubusoo is an interactive quote-to-close workspace for exporters, manufacturers, trading companies and small B2B sales teams. The implemented commercial core follows Inquiry → Deal → interactive quote → buyer response → Version → acceptance snapshot → PI → won.

The primary signed-in navigation is Inbox, Deals, Library and Settings. A Deal is the user-facing aggregate for the underlying Quote, Customer, Inquiry, QuoteRevision, BuyerActivity, Question, ChangeRequest, Acceptance and PI records. Buyer access never requires an account. Trial, Solo, Pro and Business send limits are enforced by the version publishing service.

The only user-visible stages are Draft, Live, Accepted and Closed. Viewed, revision requested, expired and awaiting deposit remain signals or conditions. `DealProgress` derives one shared Next action for Inbox, Deal list and Deal detail.

Module disposition:

- Kept: Inbox, Deals, Library, Settings, Smart Intake, Quote Studio and Buyer Room.
- Merged: Catalog + Templates + Presets + brand resources into Library; Questions + Change Requests into Deal Conversation; Activity + actionable notifications into Inbox and Deal Timeline.
- Contextualized: Buyer records, Versions, Acceptance, PI, PDFs and attachments live inside a Deal.
- Removed from primary navigation: Home, Quotes, Customers, Catalog, Templates, Tasks, Activities, Files, Revisions, PI, Insights and Reports.
- Retained underneath for compatibility and audit: Quote, Customer, QuoteRevision, BuyerActivity, Notification, QuoteAcceptance and ProformaInvoice models and legacy routes.

Unknown pricing is never inferred: manual inquiry fallback explicitly marks product, price and freight as missing or required.
