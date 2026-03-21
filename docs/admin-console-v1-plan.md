# Admin Console v1 Plan

## 1. Context and Goal
- Project/area: Rubusoo `Admin Console v1` (Rails app admin-only backend area).
- Why now: Current admin account still shares normal user business UI, causing weak permission boundary, poor support troubleshooting efficiency, and lack of clear risk fallback operations.
- Target outcome:
- Build an independent `/admin` console and layout.
- Ensure strict role boundary (`role=admin`) across all admin routes and actions.
- Provide lightweight but complete support-oriented capabilities: dashboard overview, user management, impersonation, auditability.
- Out of scope:
- Heavy operations backend, BI/report platform, full business CRUD under admin.
- Generic arbitrary field editor for all models.
- Physical user deletion and data-destructive admin tooling.

## 2. Current Problems
- Problem A: Admin and regular-user UI are mixed, so admin workflow is inefficient and permission boundary is visually and structurally weak.
- Problem B: There is no dedicated support-first user management surface (search/pagination/status control/role change/impersonation in one place).
- Problem C: High-risk admin actions (role change, suspension, impersonation) lack complete audit traceability and explicit UI safeguards.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files):
- Routing/auth: `config/routes.rb`, admin base controller/concerns, post-login redirect policy.
- Admin UI: admin layout + shared navigation + global impersonation banner.
- Pages: `/admin`, `/admin/users`, `/admin/users/:id`, `/admin/audit_logs`.
- Models/migrations: `users.status`, `audit_logs` (or existing audit abstraction extension).
- Service/policy layer: role change, suspend/reactivate, impersonation start/stop, auditing hooks.
- Business logic policy (allowed / not allowed):
- Allowed: minimal user lifecycle controls needed for support/risk fallback.
- Not allowed: broad business domain mutation tools, mass update systems, deep workflow automation.
- Visual/UX policy:
- Tooling-oriented, stable, low-noise UI.
- Admin-only navigation (no regular user dashboard modules mixed in).
- High-risk actions require explicit confirmation.
- Global impersonation state must be continuously visible and one-click exit.
- Risk boundaries:
- `role!=admin` users must never access `/admin/*`.
- Suspended users must be blocked from normal app usage.
- Every high-risk admin action must be auditable with actor/target/metadata/time.
- v1 role/status remain minimal unless existing code already requires otherwise:
- `role`: `user`, `vip`, `admin`
- `status`: `active`, `suspended`
- Admins cannot impersonate other admins in v1.
- Impersonation must preserve real admin actor context; actor identity must never be overwritten by impersonated identity in audit.
- Admins cannot change their own role.
- System must prevent demotion of the last remaining admin.

## 4. Execution Roadmap

### Phase 1 - Admin boundary and skeleton
Status: `Completed`

Goals:
- Create independent admin route namespace and layout (`/admin` entry).
- Enforce admin-only access guard for all `/admin/*` routes.
- Adjust login/post-auth redirect so admins default to `/admin`.
- Add baseline navigation for Dashboard, Users, Audit Logs.

Acceptance:
- Admin user can access `/admin` and sees admin layout.
- Non-admin user gets denied/redirected for `/admin/*`.
- Admin login default landing is `/admin`.
- Regular users continue normal business UI flow unchanged.

### Phase 2 - User status and enforcement
Status: `Completed`

Goals:
- Add `users.status` (at least `active`, `suspended`) with safe default and index support.
- Enforce suspended-account lockout in regular app flows.
- Implement admin actions for `suspend/reactivate`.

Acceptance:
- New/existing users have deterministic status value.
- Suspended users are blocked from new login.
- If a logged-in user becomes suspended, next authenticated request denies access and forces logout or suspended-access redirect.
- Suspension blocks normal product usage only (no extra heavy side effects unless existing logic already has them).
- Reactivated users can resume normal access.
- No physical deletion path introduced.

### Phase 3 - Admin dashboard and users list
Status: `Completed`

Goals:
- Build lightweight `/admin` dashboard with key counts:
- total users, recent 7-day signups, active/suspended split (if easily available).
- Build `/admin/users` list with:
- search by `email/name` (company/workspace optional only if schema supports it cleanly), pagination, required columns, row actions.

Acceptance:
- Dashboard loads quickly without heavy charts.
- If a metric needs expensive aggregation/heavy reporting logic, it is intentionally omitted in v1.
- User list supports search + pagination together.
- Columns include: `id, name, email, role, status, created_at, last_login_at, last_active_at`.
- Row actions include: `View`, `Change Role`, `Suspend/Reactivate`, `Impersonate`.

### Phase 4 - User detail and action orchestration
Status: `Completed`

Goals:
- Build `/admin/users/:id` with base profile/account activity fields.
- Add optional associated summaries (customers/quotes/revisions/public shares counts) when query cost is acceptable.
- Provide detail-page action controls: role change, suspend/reactivate, impersonation.

Acceptance:
- Detail page exposes required base fields completely.
- Association summary shows correctly or is intentionally omitted with clear fallback.
- All action outcomes are visible to admin and reflect updated state immediately.
- Self-role change is blocked.
- Demotion of the last remaining admin is blocked.

### Phase 5 - Impersonation and global safety UX
Status: `Completed`

Goals:
- Implement admin impersonation session start/stop flow.
- Add globally obvious impersonation banner across pages while active.
- Add one-click “exit impersonation and return admin console”.

Acceptance:
- Admin can enter non-admin target user view and exit safely.
- Banner remains visible on every page during impersonation.
- Exit returns to `/admin` context reliably.
- Start/stop actions both produce audit log records.

### Phase 6 - Audit logs and hardening
Status: `Completed`

Goals:
- Implement or extend audit persistence for required actions:
- role change, suspend/reactivate, impersonation start/stop.
- Build `/admin/audit_logs` list for chronological trace.
- Add confirmation UX and basic regression tests around permissions and auditing.

Acceptance:
- Audit records include `actor_id, target_type, target_id, action, metadata, created_at`.
- Audit metadata minimum shape:
- role change: `before_role`, `after_role`
- status change: `before_status`, `after_status`
- impersonation start/stop: `impersonated_user_id`, `impersonated_user_email`
- Auditable actions during impersonation still record the original admin as real actor.
- Admin can browse recent audit events in UI.
- Unauthorized access tests and key admin action tests pass.

## 5. Rules for Implementation
- Keep scope tight: support troubleshooting, user management, risk fallback only.
- Prioritize permission boundary correctness and audit completeness over UI richness.
- Reuse existing auth/session/policy patterns before introducing new abstractions.
- Keep admin actions explicit and reversible where possible.
- Do not expand into full admin CRUD for domain entities in this cycle.
- Keep role/status enum surface minimal in v1 (`user/vip/admin`, `active/suspended`) and do not add extra states.
- For impersonation, always separate "effective user context" from "real admin actor context".
- Hard-block risky edge cases by default: impersonate-admin, self-demotion, last-admin demotion.

## 6. Definition of Done
- Admin has a separate `/admin` entry, layout, and navigation.
- Non-admin cannot access admin routes.
- Users support `active/suspended` and suspension is enforced in normal usage.
- Admin can search/manage users via list + detail pages.
- Impersonation has global visible state and safe exit path.
- Required admin actions are fully audit-logged and viewable in admin audit list.

## 7. Verification Plan
- Desktop checks:
- Admin login redirects to `/admin`.
- `/admin`, `/admin/users`, `/admin/users/:id`, `/admin/audit_logs` render and actions work.
- Impersonation banner visibility and exit behavior.
- Mobile checks:
- Core admin pages remain usable (navigation, table/list readability, banner visibility, confirm flows).
- Minimal functional checks:
- Route authorization tests (`admin` vs non-admin).
- User status transitions and suspended-user access blocking tests.
- Audit log creation tests for each required admin action.
- Guardrail tests: cannot impersonate admin, cannot self-change role, cannot demote last admin.
- Impersonation audit integrity tests: actor remains original admin for auditable actions.
- What is intentionally not tested:
- Heavy performance benchmarking and advanced analytics/reporting.
- Non-scope admin CRUD for full business modules.

## 8. File Impact Plan
- Expected files:
- `config/routes.rb`
- `app/controllers/admin/base_controller.rb`
- `app/controllers/admin/dashboard_controller.rb`
- `app/controllers/admin/users_controller.rb`
- `app/controllers/admin/audit_logs_controller.rb`
- `app/controllers/admin/impersonations_controller.rb`
- `app/controllers/suspended_access_controller.rb`
- `app/controllers/concerns/*` (auth/impersonation helpers, if needed)
- `app/models/user.rb`
- `app/models/audit_log.rb` (or existing audit model extension)
- `db/migrate/*_add_status_to_users.rb`
- `db/migrate/*_create_audit_logs.rb` (if new model)
- `app/views/layouts/admin.html.erb`
- `app/views/admin/dashboard/index.html.erb`
- `app/views/admin/users/index.html.erb`
- `app/views/admin/users/show.html.erb`
- `app/views/admin/audit_logs/index.html.erb`
- `app/views/suspended_access/show.html.erb`
- Optional files:
- `app/policies/*` or authorization layer files
- `app/services/admin/*` for action orchestration + audit write
- Docs to update:
- `README.md` (admin console entry, role access notes, audit model notes)
- Additional admin operation doc if created (recommended: `docs/admin-console-v1.md`)

## 9. Progress Log
- `2026-03-21`: Plan created.
- `2026-03-21`: Phase 1 started and completed (`/admin` entry, admin layout, admin-only access boundary, post-login redirect).
- `2026-03-21`: Core users management completed (search/pagination, list/detail, role/status actions, guardrails).
- `2026-03-21`: Impersonation + audit log completed (start/stop flow, global banner, actor-preserving audit).
- `2026-03-21`: Verification completed (`bundle exec rails zeitwerk:check` + targeted integration tests).

## 10. Next Priority Queue
- Next phase/task:
- Enter maintenance + readability polish mode for Admin Console (`v1.1`).
- Deferred items:
- Advanced metrics panel (retention/cohort/trend charting).
- Bulk admin actions and workflow automation.
- Reopen conditions:
- Permission leak, audit gap, or impersonation safety issue observed in production/testing.
- New compliance requirement mandates deeper audit metadata or export.

## 11. Archive Notes (when cycle is done)
- Final status: `Completed`
- Archive filename: `docs/archive/admin-console-v1-plan-2026-03.md`
- Key decisions to preserve:
- Keep admin console lightweight and support-first.
- Permission boundary and auditability are first-class, non-negotiable requirements.
- No heavy operations-platform expansion in v1.
- Baseline freeze date: `2026-03-21`
- Reopen only for concrete regressions in permissions, suspension enforcement, impersonation safety, or audit integrity.
