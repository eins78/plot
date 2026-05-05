// @ts-check
import fs from 'node:fs';
import path from 'node:path';

/** @typedef {'Draft'|'Approved'|'Delivered'|'Released'} Phase */
/** @typedef {'Planning'|'Committed'|'Active'|'Closed'} SprintPhase */

/**
 * @typedef {Object} Card
 * @property {string} slug
 * @property {string} title
 * @property {string} type - 'feature'|'bug'|'docs'|'infra' or unknown string
 * @property {Phase} phase
 * @property {string} [sprint] - sprint slug if the plan is part of a sprint
 * @property {string} [assignee] - github handle from ## Approval section
 * @property {string} path - relative path under repo root
 */

/**
 * @typedef {Object} SprintCard
 * @property {string} slug
 * @property {string} title
 * @property {SprintPhase} phase
 */

const PHASES = /** @type {Phase[]} */ (['Draft', 'Approved', 'Delivered', 'Released']);

/**
 * Parse a plan markdown file.
 * @param {string} absPath - absolute path to the plan .md file
 * @param {string} repoRoot - repo root used to compute the relative card.path
 * @returns {Card|null} - null if Phase is unknown or file is unreadable
 */
export function parsePlan(absPath, repoRoot) {
  let content;
  try {
    content = fs.readFileSync(absPath, 'utf8');
  } catch {
    return null;
  }

  const titleMatch = content.match(/^# (.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : path.basename(absPath, '.md');

  const filename = path.basename(absPath);
  const slugMatch = filename.match(/^\d{4}-\d{2}-\d{2}-(.+)\.md$/);
  const slug = slugMatch ? slugMatch[1] : path.basename(absPath, '.md');

  const relPath = path.relative(repoRoot, absPath);

  // No 'm' flag: without multiline mode, '$' only matches at string end,
  // so the non-greedy [\s\S]*? correctly spans all lines to the next ## heading.
  const statusSectionMatch = content.match(/## Status\s*\n([\s\S]*?)(?=\n## |$)/);
  const statusSection = statusSectionMatch ? statusSectionMatch[1] : '';

  const phaseMatch = statusSection.match(/^- \*\*Phase:\*\* (.+)$/m);
  const phase = phaseMatch ? phaseMatch[1].trim() : '';

  const typeMatch = statusSection.match(/^- \*\*Type:\*\* (.+)$/m);
  const type = typeMatch ? typeMatch[1].trim() : 'unknown';

  const sprintMatch = statusSection.match(/^- \*\*Sprint:\*\* (.+)$/m);
  let sprint;
  if (sprintMatch) {
    const sprintVal = sprintMatch[1].trim();
    if (!sprintVal.startsWith('<!--')) sprint = sprintVal;
  }

  const approvalSectionMatch = content.match(/## Approval\s*\n([\s\S]*?)(?=\n## |$)/);
  let assignee;
  if (approvalSectionMatch) {
    const assigneeMatch = approvalSectionMatch[1].match(/^- \*\*Assignee:\*\* (.+)$/m);
    if (assigneeMatch) assignee = assigneeMatch[1].trim();
  }

  if (!PHASES.includes(/** @type {Phase} */ (phase))) {
    console.warn(`[parsePlan] Unknown phase "${phase}" in ${absPath} — skipping`);
    return null;
  }

  /** @type {Card} */
  const card = { slug, title, type, phase: /** @type {Phase} */ (phase), path: relPath };
  if (sprint !== undefined) card.sprint = sprint;
  if (assignee !== undefined) card.assignee = assignee;
  return card;
}

/**
 * Parse a sprint markdown file.
 * @param {string} absPath
 * @returns {SprintCard|null}
 */
export function parseSprint(absPath) {
  let content;
  try {
    content = fs.readFileSync(absPath, 'utf8');
  } catch {
    return null;
  }

  const titleMatch = content.match(/^# Sprint: (.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : path.basename(absPath, '.md');

  const filename = path.basename(absPath);
  const slugMatch = filename.match(/^\d{4}-W\d{2}-(.+)\.md$/);
  const slug = slugMatch ? slugMatch[1] : path.basename(absPath, '.md');

  const statusSectionMatch = content.match(/## Status\s*\n([\s\S]*?)(?=\n## |$)/);
  const statusSection = statusSectionMatch ? statusSectionMatch[1] : '';
  const phaseMatch = statusSection.match(/^- \*\*Phase:\*\* (.+)$/m);
  const phase = phaseMatch ? phaseMatch[1].trim() : '';

  if (!phase) {
    console.warn(`[parseSprint] No phase found in ${absPath} — skipping`);
    return null;
  }

  return { slug, title, phase: /** @type {SprintPhase} */ (phase) };
}
