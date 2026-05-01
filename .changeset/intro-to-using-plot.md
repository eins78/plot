---
"plot": patch
---

Add a narrative tutorial for new users, and clarify how Plot relates to GitHub Issues.

`skills/plot/intro-to-using-plot.md` is a new second-person walkthrough of the lifecycle (Draft → Approved → Delivered → Released), modeled on [changesets' `intro-to-using-changesets.md`](https://github.com/changesets/changesets/blob/main/docs/intro-to-using-changesets.md). It closes the gap between the high-level `README.md` and the AI-facing reference manual in `SKILL.md`. Linked from both.

The MANIFESTO's "Not an issue tracker" bullet is reframed to match. Previously it said GitHub Issues "overlap and conflict" with Plot. The updated wording keeps the strong stance that Plot replaces issue trackers for *planned implementation work*, while acknowledging that issues remain useful **upstream** of the workflow — as the inbox for external feedback (bug reports, user-submitted feature requests, high-level user stories or business goals) that may eventually become plans. The boundary: issues are signals; plans are commitments.

<!--
bumps:
  skills:
    plot: patch
-->
