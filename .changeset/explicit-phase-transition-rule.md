---
"plot": patch
---

`plot-sprint`: make the phase-transition rule explicit, and document multiline create input.

Renames `## Guardrail` → `## Guardrails` and adds a `### Phase Transitions` sub-section stating that the `Phase` field is updated only by named subcommands (`commit`, `start`, `close`). All other actions — opening a PR, refining items, fixing typos — leave the phase unchanged. Closes the gap behind [issue #2 / observation 1](https://github.com/eins78/plot/issues/2) where "start a PR for the sprint" was misread as `/plot-sprint <slug> start`.

Also adds a one-paragraph note on multiline `$ARGUMENTS` to the Create step 1 (Parse Input): subsequent lines after the first become the body of `## Sprint Goal`, not the one-line headline. Closes [issue #2 / observation 4](https://github.com/eins78/plot/issues/2).
