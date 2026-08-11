# Chat Sync Phase One

## 1. Context and Goal
- Project/area: Rubusoo seller conversation intake.
- Why now: Sales teams cannot repeatedly copy long WhatsApp and Alibaba conversations into an inquiry.
- Target outcome: Explicitly bound browser conversations are captured incrementally, uploaded idempotently, and analyzed on demand or after inactivity.
- Out of scope: OCR, voice transcription, attachment download, reading unsent input, and sending messages.
- Business value / success metric: A bound conversation can resume after reload or offline use without duplicate or lost messages.
- Delivery deadline (if any): Current delivery cycle.

## 2. Current Problems
- Problem A: Conversation intake is manual.
- Problem B: Existing inquiry messages have no platform identity or client/server deduplication contract.
- Problem C: The website has no limited-purpose browser integration authorization.
- Existing workaround and why it is insufficient: Copy/paste is too costly for active sales conversations.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files): Chat integration models/API, integration setup page, reusable userscript source, WhatsApp/Alibaba adapters and floating panel.
- Business logic policy (allowed / not allowed): Only enabled platforms and explicitly bound conversations may upload.
- Visual/UX policy: Shadow DOM panel; no host-page CSS leakage.
- Risk boundaries: Never read cookies, passwords, unsent composer content, other tabs or unbound conversations.
- Non-negotiable constraints (performance/compliance/compatibility): Batched durable queue, HTTPS API, revocable expiring token, tenant checks, idempotent server writes.

## 4. Execution Roadmap

### Phase 1 - Secure ingestion
Status: `In progress`

Goals (outcome):
- Establish limited authorization, binding and message ingestion contracts.

Implementation actions (must be executable):
- [ ] Add pairing, token, binding, request and captured-message models.
- [ ] Add tenant-scoped JSON APIs and ownership checks.

Deliverables (must be tangible):
- Code files: Rails migrations, models, controllers and routes.
- Docs updated: This plan and API documentation.
- Test cases added/updated: Authorization, binding and idempotency integration tests.

Acceptance (must be verifiable):
- [ ] Repeated request/message uploads create one record.
- [ ] An unbound or cross-tenant conversation cannot upload.
- [ ] Expired/revoked tokens are rejected.

Evidence required:
- Commands/checks run: Targeted Rails tests.
- Screenshot/PDF paths: `tmp/review_shots/chat-sync-phase-one/`.
- Notes on what could not be verified: Live platform DOM changes remain adapter-version dependent.

### Phase 2 - Browser collector
Status: `Planned`

Goals (outcome):
- Capture normally rendered WhatsApp and Alibaba messages with a durable local queue.

Implementation actions (must be executable):
- [ ] Implement Runtime, collector, normalizer, deduplicator and upload queue modules.
- [ ] Implement platform adapters and Shadow DOM panel.

Deliverables (must be tangible):
- Code files: `integrations/chat-sync/src/**` and built userscript.
- Docs updated: Installation and adapter maintenance guide.
- Test cases added/updated: DOM fixtures and queue retry tests.

Acceptance (must be verifiable):
- [ ] SPA conversation changes are detected.
- [ ] Reloads and repeated DOM nodes do not duplicate messages.
- [ ] Unbound conversations remain local and are not uploaded.

Evidence required:
- Commands/checks run: Node tests and userscript build.
- Screenshot/PDF paths: Panel states in the review folder.
- Notes on what could not be verified: Alibaba selectors require periodic production review.

### Phase 3 - Analysis workflow
Status: `Planned`

Goals (outcome):
- Separate synchronization from structured readiness analysis.

Implementation actions (must be executable):
- [ ] Add manual analysis and configurable inactivity/threshold triggers.
- [ ] Return rule-backed readiness, missing fields, changes, questions and source cursors.

Deliverables (must be tangible):
- Code files: Analysis job/service and API status endpoints.
- Docs updated: Trigger and readiness rules.
- Test cases added/updated: Manual trigger and structured result tests.

Acceptance (must be verifiable):
- [ ] Manual analysis flushes the queue first.
- [ ] Each cursor is automatically analyzed at most once.
- [ ] Results are structured rather than prose-only.

Evidence required:
- Commands/checks run: Job/service/controller tests.
- Screenshot/PDF paths: Analysis panel state.
- Notes on what could not be verified: Model quality depends on provider availability; deterministic readiness still runs.

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse the existing Inquiry and InquiryMessage aggregate.
- Do not upload raw HTML or log full message bodies/tokens.
- Keep platform selectors isolated inside adapters.

## 6. Definition of Done
- Supported conversations can bind, collect, retry, upload and analyze.
- Core code has no direct GM or Chrome API dependency.
- Server is authoritative for tenant ownership and deduplication.
- Tests and distributable userscript are committed.

## 7. Verification Plan
- Desktop checks: Integration setup and floating panel at desktop viewport.
- Mobile checks: Website integration setup layout.
- Minimal functional checks: Pair, bind, duplicate upload, manual analysis, offline queue recovery.
- What is intentionally not tested: OCR, audio, automated outbound messages.
- Execution log format: Command / result / pass-fail / evidence.

## 8. File Impact Plan
- Expected files: Models, migrations, API controllers/routes, setup view, integration source/build/test.
- Optional files: Locale and shared CSS rules.
- Docs to update: Product, API and CSS docs when UI is added.
- Out-of-scope files that must not be touched: Buyer output and quote export renderers.

## 9. Progress Log
- `2026-07-25`: Phase started and contract defined.
- `2026-08-05`: AI input now uses a deterministic conversation transcript with platform/local message ID, normalized role, message type, channel, timestamp, sender and cleaned body. Unknown direction remains neutral (`internal`/`other`) instead of being classified as buyer content.
- `2026-08-05`: Chat setup now lists recently bound conversations and links each stable binding back to its Inquiry review. Binding identity remains company + platform + platform account ID + platform conversation ID; message identity remains native platform ID with fingerprint fallback.
- `2026-08-05`: Inquiry is the seller-visible work unit before quote creation. Rebinding the same platform conversation resumes the same Inquiry without creating an orphan task; an Inquiry can produce only one Quote, and the new Inquiry index resumes either the preparation record or that linked Quote.
- `2026-08-06`: Plugin-originated analysis now reconciles model output with trusted binding/customer identity and deterministic message facts. Normalized customer senders, English delivery, packing, payment, product names, models and requested configurations survive provider errors and prevent malformed model output from replacing explicit chat evidence.
- `2026-08-06`: Chat identity is now long-lived while Inquiry remains one quote cycle. A genuinely new buyer message with explicit quote/order intent arriving after a won, lost, cancelled, expired or archived quote rotates the binding to a new Inquiry and preserves the closed quote; replayed and ordinary post-sale messages do not rotate. AI analysis uses current-task facts plus a bounded 32,000-character head/recent-message window, while full original messages remain stored for evidence.

## 10. Next Priority Queue
- Next phase/task: Manifest V3 runtime and packaging.
- Deferred items: LinkedIn, Facebook, Gmail, Outlook, OCR, attachment download and outbound sending.
- Reopen conditions: Supported platform DOM changes or API scope expansion.
- Owner: Product engineering.
- Earliest start date: After phase-one field validation.
- Dependency: Stable first-party adapter fixtures.

## 11. Archive Notes (when cycle is done)
- Final status: Active.
- Archive filename: To be assigned after acceptance.
- Key decisions to preserve: Explicit per-site consent, explicit per-conversation binding, runtime abstraction, double deduplication.
- Delivery summary: Pending.
- Completed vs deferred: Pending.
- Evidence index: Pending.
