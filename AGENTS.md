# AGENTS.md

## Purpose
This file defines project execution rules for coding agents working on this repository.
Read this file before making any changes.

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

## CSS Workflow Rules (Important)
1. Before any CSS change, read:
- `docs/css-components.md`

2. Any change to CSS conventions, class families, or styling patterns must update:
- `docs/css-components.md`

3. CSS scope discipline:
- Reuse existing class families first.
- Avoid creating parallel button/input systems.
- Remove dead selectors when safe.

## Code Change Rules
1. Keep changes minimal and task-focused.
2. Do not modify unrelated files.
3. Preserve existing coding style and naming.
4. Avoid broad refactors unless explicitly requested.

## Verification Rules
1. After code changes, run the smallest relevant test/check first.
2. If full test suite is not run, clearly state what was and was not verified.
3. For UI/CSS changes, verify affected pages in desktop and mobile layouts.

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
- Read `docs/css-components.md` before CSS edits
- Updated `docs/css-components.md` if CSS rules changed
- Used `rails` (not `/bin/rails`)
- Ran relevant checks/tests
- Kept scope tight and avoided unrelated edits
