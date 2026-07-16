# QA

Required gates are model/service tests for pricing, revisions, acceptance and PI; request tests for workspace boundaries and Buyer Room state; duplicate-operation tests; system tests for seller and buyer journeys; Chrome desktop/mobile screenshots under `tmp/review_shots/<run>`; asset build; migration; Brakeman; and live health/HTTPS checks.

No gate is reported as passed until its command has actually completed. Demo writes must remain isolated from production business records.

## 2026-07-16 production result

- Rails: 224 runs, 946 assertions, 0 failures, 0 errors, 0 skips.
- Brakeman 8.0.4: 0 security warnings.
- Production Docker image: built successfully for arm64 and tagged with the deployment commit.
- Migration `20260716000000`: completed in production.
- Live checks: `/`, `/pricing`, `/buyer-demo`, and `/up` returned HTTP 200 through Cloudflare and HTTPS.
- Chromium: 1440×1100 marketing page and 390×844 live Buyer Room captured under `tmp/review_shots/20260716`.
- Buyer Demo uses the isolated Atlas demo workspace; it does not share a real customer's workspace or statistics.
