# First-quote focus plan

## 1. Context and Goal
- Project/area: New-account activation through first quote draft.
- Why now: The functional path exists, but repeated entry points and explanatory panels obscure the next action.
- Target outcome: Each page communicates one primary task at a glance and progressively reveals secondary setup or advanced information.
- Out of scope: Authentication policy changes, quote publishing semantics, pricing automation, and third-party adapter work.
- Business value / success metric: A new verified user can identify and start the correct first-quote path without visiting unrelated setup modules.
- Delivery deadline (if any): Current implementation cycle.

## 2. Current Problems
- Problem A: Empty Quotes sends users into a second decision page without explaining the fastest path.
- Problem B: New Quote repeats paste, chat, upload, Catalog, and manual choices even when several lead to the same page.
- Problem C: Inquiry intake explains internal processing before the user completes the simple paste/upload task.
- Existing workaround and why it is insufficient: Documentation explains the workflow, but the interface itself does not establish a clear next action.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files): Quotes empty state, New Quote, Inquiry intake, related canonical CSS, controller/system tests, and UX documentation.
- Business logic policy (allowed / not allowed): Keep both intelligent and manual quote creation; do not make company profile or Catalog setup mandatory.
- Visual/UX policy: One primary action, one secondary path, advanced explanations in disclosures, open editorial canvas.
- Risk boundaries: Preserve existing form endpoints and draft/publication requirements.
- Non-negotiable constraints (performance/compliance/compatibility): Mobile-first readability, keyboard-accessible disclosures, no hidden monetary assumptions.

## 4. Execution Roadmap

### Phase 1 - Focus the first decision
Status: `Completed`

Goals (outcome):
- Make the empty account and New Quote page self-explanatory.

Implementation actions (must be executable):
- [x] Replace the generic empty Quotes state with a first-quote launch surface.
- [x] Consolidate duplicate New Quote entry points into intelligent and manual paths.

Deliverables (must be tangible):
- Code files: Quotes index/new views and canonical CSS.
- Docs updated: this plan and CSS contract.
- Test cases added/updated: empty-state and entry-path assertions.

Acceptance (must be verifiable):
- [x] Behavior acceptance: Intelligent path opens Inquiry intake; manual path remains available.
- [x] Channel/output acceptance: No prerequisite setup is implied.
- [x] Regression acceptance: Existing customer and quote-copy flows remain available.

Evidence required:
- Commands/checks run: focused controller tests.
- Screenshot/PDF paths: Phase 3.
- Notes on what could not be verified: Progress Log.

### Phase 2 - Reduce intake explanation noise
Status: `Completed`

Goals (outcome):
- Put the paste/upload task and extraction action ahead of process education.

Implementation actions (must be executable):
- [x] Replace the four-step rail with one compact action panel.
- [x] Move guardrails and processing details into an accessible disclosure.

Deliverables (must be tangible):
- Code files: Inquiry intake view and CSS.
- Docs updated: CSS contract.
- Test cases added/updated: intake structure assertions.

Acceptance (must be verifiable):
- [x] Behavior acceptance: Paste/upload and submit remain unchanged.
- [x] Channel/output acceptance: Desktop and mobile show the primary action without scrolling past explanations.
- [x] Regression acceptance: File formats and source retention remain communicated.

Evidence required:
- Commands/checks run: focused tests and browser flow.
- Screenshot/PDF paths: Phase 3.
- Notes on what could not be verified: Progress Log.

### Phase 3 - Verify first-use comprehension
Status: `Completed`

Goals (outcome):
- Confirm the focused hierarchy across empty, choice, and intake pages.

Implementation actions (must be executable):
- [x] Run focused Rails and style checks.
- [x] Capture desktop/mobile evidence with a verified empty account.
- [x] Record deferred Quote Studio simplification separately.

Deliverables (must be tangible):
- Code files: verification fixes only.
- Docs updated: plan progress and deferred queue.
- Test cases added/updated: regressions discovered during browser review.

Acceptance (must be verifiable):
- [x] Behavior acceptance: Every page exposes one visually dominant next action.
- [x] Channel/output acceptance: No overflow or action obstruction at 1440px and 390px.
- [x] Regression acceptance: Focused suite passes.

Evidence required:
- Commands/checks run: recorded in Progress Log.
- Screenshot/PDF paths: `tmp/review_shots/first_quote_focus_20260805/`.
- Notes on what could not be verified: Progress Log.

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- Do not change business logic unless the phase explicitly allows it.
- Clean conflicting/obsolete same-scope rules while editing.
- No intent-only phase updates: every status update must include completed actions and evidence.
- If a phase is marked `Completed`, unresolved TODOs must be moved to next phase/queue explicitly.

## 6. Definition of Done
- Hierarchy/readability improved in target scope.
- No functional regressions in core interactions.
- Changes are traceable in progress log.
- Follow-up queue is explicit.
- Each completed phase has action checklist, file changes, verification evidence, and known gaps.

## 7. Verification Plan
- Desktop checks: empty Quotes, New Quote, Inquiry intake at 1440px.
- Mobile checks: same pages at 390px.
- Minimal functional checks: both quote paths, customer creation, inquiry submission controls.
- What is intentionally not tested: Live AI provider response and email verification delivery.
- Execution log format: command, result, pass/fail, evidence path.

## 8. File Impact Plan
- Expected files: quote/inquiry views, `rubusoo.css`, focused tests.
- Optional files: controllers only if view state cannot be derived safely.
- Docs to update: this plan and `docs/css-components.md`.
- Out-of-scope files that must not be touched: publishing, exports, billing, chat adapters.

## 9. Progress Log
- `2026-08-05`: Phase 1 started after new-account workflow audit.
- `2026-08-05`: Focused empty Quotes and New Quote around one recommended customer-content path, with manual creation progressively disclosed.
- `2026-08-05`: Reduced Inquiry intake to the composer, one submit action, and collapsed processing details; removed obsolete same-scope CSS selectors.
- `2026-08-05`: Browser-reviewed all three pages at 1440px and 390px; the empty-state review exposed residual list chrome, which was then removed for accounts without quotes.
- `2026-08-05`: `19 runs, 136 assertions, 0 failures, 0 errors`; RuboCop inspected five changed Ruby files with no offenses; `git diff --check` passed.
- Known gap: Live AI provider response and email delivery were not exercised in this UX pass.

## 10. Next Priority Queue
- Next phase/task: First-quote simplified Quote Studio mode and exact blocker-to-field navigation.
- Deferred items: Email verification visual convergence and post-verification auto sign-in decision.
- Reopen conditions: Browser review reveals unclear or competing primary actions.
- Owner: Project team.
- Earliest start date: After this cycle.
- Dependency: None.

## 11. Archive Notes (when cycle is done)
- Final status: Completed.
- Archive filename: `first-quote-focus-plan-2026-08-05.md`.
- Key decisions to preserve: Setup remains optional; intelligent preparation is the recommended first path.
- Delivery summary: Empty-account launch, New Quote choice, and Inquiry intake now each present one dominant next action with secondary detail disclosed on demand.
- Completed vs deferred: First-use entry and intake are complete; Quote Studio simplification and email-verification convergence remain deferred.
- Evidence index: `tmp/review_shots/first_quote_focus_20260805/`.
