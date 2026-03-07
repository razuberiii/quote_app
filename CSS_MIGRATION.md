# CSS Migration Rules

This project is in progressive migration from legacy CSS to Tailwind.

## Source of truth
- New UI styles: Tailwind utility classes in views/components first.
- Reusable new patterns: define in `app/assets/tailwind/application.css` using Tailwind layers.
- Legacy files (`legacy_core.css`, `legacy_landing.css`, `legacy_ui.css`): compatibility only.

## Mandatory workflow for every style change
1. If adding new UI:
- Do not add styles to legacy files.
- Implement with Tailwind classes directly in ERB.

2. If modifying old UI that still depends on legacy selectors:
- Migrate the touched selector(s) to Tailwind-oriented styles first.
- Remove the old selector block(s) from legacy CSS in the same change.

3. If migration is partial:
- Keep behavior unchanged.
- Leave a short TODO note in the PR/commit message describing remaining selectors.

## Deletion policy
- Legacy CSS is "delete-only" unless emergency hotfix.
- Any migrated selector must be removed from its original legacy file immediately.
- Unused old files must be renamed to `.disabled` and moved to `app/assets/stylesheets/_unused/`.

## Verification checklist
- Build passes: `ruby .\\bin\\rails tailwindcss:build`
- Main pages visually verified after hard refresh (`Ctrl+F5`)
- No duplicate selector remains in both Tailwind and legacy files

