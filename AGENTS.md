# AGENTS.md

## Purpose
This file defines project execution rules for coding agents working on this repository.
Read this file before making any changes.
## Documentation First Rules (Important)
1. Before starting any task, read this file (`AGENTS.md`) once end-to-end.
2. Treat project documentation as part of the codebase and maintain it continuously.
3. If implementation reality conflicts with docs, docs are incomplete, or docs are wrong:
- Update the relevant `.md` files in the same task.
- Report what was updated and why.
4. If anything is ambiguous or risky, ask the project owner directly before proceeding.
5. Any new scoped plan/task document under `docs/` must be created from `docs/plan-template.md` structure (same section skeleton).

## Environment
- OS: Windows
- Shell: PowerShell
- Current project root: `quote_app`

## Command Rules (Important)
1. Do not use `/bin` prefixed Rails commands in this project.
- Wrong: `/bin/rails db:migrate`
- Right: `rails db:migrate`

2. Prefer `bundle exec` for Ruby/Rails tasks when needed.
- Example: `bundle exec rails test`

3. Use PowerShell-safe command style and Windows paths when running scripts.

## Asset Troubleshooting Rules (Development)
1. If CSS updates do not apply or you see `The asset 'tailwind.css' was not found in the load path`:
- Ensure `app/assets/builds/tailwind.css` exists.
- Run: `bundle exec rails tailwindcss:build`

2. If stale precompiled assets are being served in development:
- Stop server, then remove `public/assets/.manifest.json` (if present).
- Restart Rails server.

3. Avoid running `bundle exec rails assets:precompile` in development unless required.
- If run, remember to remove manifest afterwards to restore normal dev asset behavior.

## CSS Workflow Rules (Important)
1. Before any CSS change, read:
- `docs/css-components.md`

2. Any change to CSS conventions, class families, or styling patterns must update:
- `docs/css-components.md`

3. CSS scope discipline:
- Reuse existing class families first.
- Avoid creating parallel button/input systems.
- Remove dead selectors when safe.

4. CSS cleanup discipline (required):
- For every CSS task, clean the same-scope obsolete/conflicting selectors first, not only add new overrides.
- If multiple historical rules target the same page/component and create interference, consolidate into one canonical rule block.
- Prioritize deleting no-longer-used or shadowed rules to keep `components.css` maintainable.

## Code Change Rules
1. Keep changes minimal and task-focused.
2. Do not modify unrelated files.
3. Preserve existing coding style and naming.
4. Avoid broad refactors unless explicitly requested.

## Verification Rules
1. After code changes, run the smallest relevant test/check first.
2. If full test suite is not run, clearly state what was and was not verified.
3. For UI/CSS changes, verify affected pages in desktop and mobile layouts.

## Screenshot Output Rules
1. Base folder is fixed: `tmp/review_shots/`.
2. For each screenshot run, create one new subfolder under `tmp/review_shots/` (for example `tmp/review_shots/<task_or_timestamp>/`).
3. Keep all screenshots for that run inside the same subfolder.
4. In the final report, always provide the subfolder path first, then key file names.

## Safety Rules
1. Never run destructive Git commands unless explicitly requested.
- Includes: `git reset --hard`, `git checkout -- <file>`, forced history rewrites.

2. If unexpected unrelated local changes are detected, pause and ask before proceeding.

## Suggested Task Output Format
When reporting back, include:
1. What changed
2. Files touched
3. Verification performed
4. Risks or follow-up suggestions

## Quick Checklist Before Submitting
- Re-read `AGENTS.md` at task start (mandatory)
- Read `docs/css-components.md` before CSS edits
- Updated `docs/css-components.md` if CSS rules changed
- Cleaned obsolete/conflicting CSS in the edited scope (not only appended new rules)
- Used `rails` (not `/bin/rails`)
- Ran relevant checks/tests
- Saved screenshots in one dedicated `tmp/review_shots/<run_folder>/` subfolder and reported that path
- Kept scope tight and avoided unrelated edits
