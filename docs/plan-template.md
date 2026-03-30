# Plan Template

Use this file as the starting point for any scoped improvement cycle (UI, feature, stability, performance, refactor, etc.).
This template is delivery-oriented: every phase must map to concrete actions, files, checks, and evidence.

## 1. Context and Goal
- Project/area:
- Why now:
- Target outcome:
- Out of scope:
- Business value / success metric:
- Delivery deadline (if any):

## 2. Current Problems
- Problem A:
- Problem B:
- Problem C:
- Existing workaround and why it is insufficient:

## 3. Scope and Constraints
- Scope (explicit pages/modules/files):
- Business logic policy (allowed / not allowed):
- Visual/UX policy:
- Risk boundaries:
- Non-negotiable constraints (performance/compliance/compatibility):

## 4. Execution Roadmap

### Phase 1 - [name]
Status: `Planned`

Goals (outcome):
- 

Implementation actions (must be executable):
- [ ] Action 1:
- [ ] Action 2:

Deliverables (must be tangible):
- Code files:
- Docs updated:
- Test cases added/updated:

Acceptance (must be verifiable):
- [ ] Behavior acceptance:
- [ ] Channel/output acceptance:
- [ ] Regression acceptance:

Evidence required:
- Commands/checks run:
- Screenshot/PDF paths:
- Notes on what could not be verified:

### Phase 2 - [name]
Status: `Planned`

Goals (outcome):
- 

Implementation actions (must be executable):
- [ ] Action 1:
- [ ] Action 2:

Deliverables (must be tangible):
- Code files:
- Docs updated:
- Test cases added/updated:

Acceptance (must be verifiable):
- [ ] Behavior acceptance:
- [ ] Channel/output acceptance:
- [ ] Regression acceptance:

Evidence required:
- Commands/checks run:
- Screenshot/PDF paths:
- Notes on what could not be verified:

### Phase 3 - [name]
Status: `Planned`

Goals (outcome):
- 

Implementation actions (must be executable):
- [ ] Action 1:
- [ ] Action 2:

Deliverables (must be tangible):
- Code files:
- Docs updated:
- Test cases added/updated:

Acceptance (must be verifiable):
- [ ] Behavior acceptance:
- [ ] Channel/output acceptance:
- [ ] Regression acceptance:

Evidence required:
- Commands/checks run:
- Screenshot/PDF paths:
- Notes on what could not be verified:

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- Do not change business logic unless the phase explicitly allows it.
- Clean conflicting/obsolete same-scope rules while editing.
- No "intent-only" phase updates: every status update must include completed actions and evidence.
- If a phase is marked `Completed`, unresolved TODOs must be moved to next phase/queue explicitly.

## 6. Definition of Done
- Hierarchy/readability improved in target scope.
- No functional regressions in core interactions.
- Changes are traceable in progress log.
- Follow-up queue is explicit.
- Each completed phase has:
- Action checklist marked with outcomes.
- File-level change list.
- Verification evidence (commands + artifacts).
- Known gaps and next owner.

## 7. Verification Plan
- Desktop checks:
- Mobile checks:
- Minimal functional checks:
- What is intentionally not tested:
- Execution log format:
- Command:
- Result:
- Pass/Fail:
- Evidence path:

## 8. File Impact Plan
- Expected files:
- Optional files:
- Docs to update:
- Out-of-scope files that must not be touched:

## 9. Progress Log
- `YYYY-MM-DD`: Phase started.
- `YYYY-MM-DD`: Main changes completed.
- `YYYY-MM-DD`: Verification completed.
- `YYYY-MM-DD`: Blockers/risks discovered and mitigation.
- `YYYY-MM-DD`: Scope change approved (what changed and why).

## 10. Next Priority Queue
- Next phase/task:
- Deferred items:
- Reopen conditions:
- Owner:
- Earliest start date:
- Dependency:

## 11. Archive Notes (when cycle is done)
- Final status:
- Archive filename:
- Key decisions to preserve:
- Delivery summary:
- Completed vs deferred:
- Evidence index:
