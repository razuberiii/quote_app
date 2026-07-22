# Rubusoo product

Rubusoo is a quote-first workspace for exporters, manufacturers, trading companies and small B2B sales teams. Its commercial core is:

`Inquiry conversation → working quote → customer preview → immutable Version → customer feedback → revision → acceptance → final document`.

The primary signed-in navigation is Quotes, Customers, Catalog and Settings, with AI Import and New Quote as global actions. Quote is the user-facing commercial aggregate. Buyer access never requires an account.

## Product contract

- Sellers add communication; Rubusoo decides when to merge and analyze it. Rapid additions are grouped, and sellers are interrupted only for decisions.
- AI may extract and match evidence, but never invents prices, freight or commercial terms.
- Quote creation requirements and publication blockers are distinct. A quote may be created before price and freight are complete.
- Quote Studio surfaces publication blockers from `QuoteReadinessAudit`; it does not ask the seller to rediscover missing information.
- Customer preview keeps “return to edit” and “confirm and publish” in the same task flow.
- Publication creates an immutable `QuoteRevision`. The completion state immediately exposes customer link, PDF, Excel and delivery.
- Customer changes remain tied to their source Version. Applying structured changes updates only the working draft; publishing creates V2 and never overwrites V1.

## Canonical modules

- Quotes: working drafts, customer activity and immutable versions.
- Customers: only the identity and contact data required for quoting.
- Catalog: reusable products, specifications and trusted price sources.
- Settings: company identity and recommended document defaults; advanced channel-specific controls are progressive.
- AI Import: company, catalog, inquiry and quotation-style source intake.

Legacy Deal/CRM routes and models may remain for compatibility, but they are not a product surface and must not introduce Deal stages, KPI dashboards or separate Files navigation.
