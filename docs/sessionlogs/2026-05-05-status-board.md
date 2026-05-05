# Local Kanban Status Board (`pnpm board`)

**Date:** 2026-05-05
**Scope:** New feature — local read-only Kanban board for plot plan state
**Branch:** `worktree-plot-status-board`
**PR:** [eins78/plot#18](https://github.com/eins78/plot/pull/18) — merged
**Plugin version bump:** `1.0.0` → `1.1.0`

## What

Adds `skills/plot/scripts/board/` — a zero-runtime-dependency Node HTTP server that reads `docs/plans/` + `docs/sprints/` from repo root and renders a local Kanban board at `http://localhost:7777`. Ships inside the plot skill and distributes to every adopting project.

Files added:
- `skills/plot/scripts/board/server.mjs` — HTTP server, walker, `/api/board` endpoint
- `skills/plot/scripts/board/parser.mjs` — extracted `parsePlan` / `parseSprint` (testable)
- `skills/plot/scripts/board/app.mjs` — lit-html browser app, sprint filter, URL state
- `skills/plot/scripts/board/index.html` — HTML shell
- `skills/plot/scripts/board/styles.css` — Open Props two-layer token system
- `skills/plot/scripts/board/tsconfig.json` — board-local `tsc --noEmit` config
- `skills/plot/scripts/board/vendor/lit-html.js` — vendored ESM (v3.2.1, `// @ts-nocheck`)
- `skills/plot/scripts/board/vendor/open-props.min.css` — vendored design tokens (v1.7.23)
- `test/board/parser.test.mjs` — 6 unit tests via `node --test`
- `test/board/walker.test.mjs` — 4 integration tests (symlinks, missing dirs, broken symlinks, sprint discovery)
- `test/board/fixtures/` — sample plan + sprint markdown files

Files modified:
- `package.json` — added `board`, `typecheck`, `test:board` scripts; `typescript` + `@types/node` devDeps; version `1.1.0`
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — version `1.1.0`
- `skills/plot/SKILL.md` — added `## Local Status Board` section; version `1.1.0`
- `skills/plot/README.md` — added board row to structure table
- `CLAUDE.md` — added `board/server.mjs` row to Helper Scripts table
- `.changeset/20260430-board.md` — changeset for release notes

## Key design decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Stack | `.mjs` + `// @ts-check` + JSDoc + `tsc --noEmit` | Zero build step; type safety without runtime cost |
| Templating | vendored lit-html v3 | ~12KB ESM, no build step, typed tagged templates; DOM manipulation would be 3× the LOC |
| Design tokens | Open Props + two-layer semantic aliases | Raw OP vars only in `:root`; selectors use only semantic names — the alias layer is the iteration surface |
| Parser extraction | `parser.mjs` imported by both server and tests | Tests must hit real production code, not a copy |
| Section-capture regex | no `m` flag | With `m` flag, `$` matches at every line boundary — kills multi-line section capture |
| Vendor files | `// @ts-nocheck` pragma (not tsconfig `exclude`) | `exclude` blocks compilation entry points, not transitive imports from `.mjs` source |

## Shipped in this session (2026-05-05 additions)

- **"Not in sprint" filter** — dropdown option (after "All plans") showing only orphaned plans; `?sprint=__no_sprint__` is bookmarkable
- **"All plans" label** — renamed from "All sprints" (the old label was misleading — it shows all plans regardless of sprint)
- **`HOST` env var** — `HOST=0.0.0.0 pnpm board` binds to all interfaces; prints tailscale IP on start
- **🧪 Beta marker** — callout in `SKILL.md` Local Status Board section and README table row
- **Complete semantic alias layer** — all raw OP vars (`--size-X`, `--font-size-X`, `--radius-X`) removed from selectors; new aliases: `--text-xs/sm/lg`, `--weight-medium/bold`, `--leading-tight/snug/base`, `--tracking-tight`, `--radius-card/pill`, `--space-xs/sm`, `--pad-header/board`, `--col-min-width`, `--count-min-width`

## Verification

- `pnpm typecheck` — 0 errors
- `pnpm test:board` — 10/10 pass
- `pnpm test` — 8 skills valid
- Playwright smoke (headless Chrome): 4 columns, 2 plans in correct phase, empty-state placeholders, sprint dropdown, no console errors, dark mode background flip
- Board running on `http://100.86.215.114:7777` (qubert data, tailscale-accessible)
