# Plot CLAUDE.md Snippet

Copy this into your project's `CLAUDE.md` and fill in the values.

---

## Plot Config

- **Branch prefixes:** idea/, feature/, bug/, docs/, infra/
- **Plan directory:** docs/plans/
- **Active index:** docs/plans/active/
- **Delivered index:** docs/plans/delivered/
- **Sprint directory:** docs/sprints/
<!-- Optional: uncomment if using a GitHub Projects board -->
<!-- - **Project board:** owner/number (e.g. eins78/5) -->
<!-- Note: disable GitHub Projects' built-in "PR merged → Done" and "Item added → Todo" automations if using Plot's board sync -->

## Plot Rules

- Plans merge to main before implementation begins (`/plot-approve`)
- Never edit plan files outside the Plot workflow — phase fields are machine-readable
- Implementation PRs start as drafts and reference their plan
- Sprint files are committed directly to main (no PR)
- Use MoSCoW tiers in sprints: Must / Should / Could / Deferred
