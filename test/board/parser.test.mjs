// @ts-check
/**
 * Unit tests for parsePlan and parseSprint logic.
 *
 * Strategy: copy the parsing logic from server.mjs into local helpers with an
 * explicit `repoRoot` parameter (the server module captures `process.cwd()` at
 * load time, making it untestable in isolation). Tests use fixture file content
 * written to temp paths with proper date-prefixed filenames so slug extraction
 * works correctly.
 */

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

// ── Fixture paths ────────────────────────────────────────────────────────────

const FIXTURES_DIR = new URL('./fixtures', import.meta.url).pathname;

function readFixture(name) {
  return fs.readFileSync(path.join(FIXTURES_DIR, name), 'utf8');
}

// ── Inline parser helpers (mirroring server.mjs, with repoRoot param) ────────

/** @typedef {'Draft'|'Approved'|'Delivered'|'Released'} Phase */
/** @typedef {'Planning'|'Committed'|'Active'|'Closed'} SprintPhase */

/**
 * @typedef {Object} Card
 * @property {string} slug
 * @property {string} title
 * @property {string} type
 * @property {Phase} phase
 * @property {string} [sprint]
 * @property {string} [assignee]
 * @property {string} path
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
 * @param {string} repoRoot - repo root for computing relative path
 * @returns {Card|null}
 */
function parsePlan(absPath, repoRoot) {
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
    if (!sprintVal.startsWith('<!--')) {
      sprint = sprintVal;
    }
  }

  const approvalSectionMatch = content.match(/## Approval\s*\n([\s\S]*?)(?=\n## |$)/);
  let assignee;
  if (approvalSectionMatch) {
    const approvalSection = approvalSectionMatch[1];
    const assigneeMatch = approvalSection.match(/^- \*\*Assignee:\*\* (.+)$/m);
    if (assigneeMatch) {
      assignee = assigneeMatch[1].trim();
    }
  }

  if (!PHASES.includes(/** @type {Phase} */ (phase))) {
    console.warn(`[parsePlan] Unknown phase "${phase}" in ${absPath} — skipping`);
    return null;
  }

  /** @type {Card} */
  const card = {
    slug,
    title,
    type,
    phase: /** @type {Phase} */ (phase),
    path: relPath,
  };

  if (sprint !== undefined) card.sprint = sprint;
  if (assignee !== undefined) card.assignee = assignee;

  return card;
}

/**
 * Parse a sprint markdown file.
 * @param {string} absPath
 * @returns {SprintCard|null}
 */
function parseSprint(absPath) {
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

  return {
    slug,
    title,
    phase: /** @type {SprintPhase} */ (phase),
  };
}

// ── Temp dir helpers ──────────────────────────────────────────────────────────

/** @type {string} */
let tmpDir;

/** @type {string} */
let plansDir;

/**
 * Write a plan file using a date-prefixed name so slug extraction works.
 * @param {string} datePrefix - e.g. '2026-01-15'
 * @param {string} slugPart   - e.g. 'webhook-support'
 * @param {string} content
 * @returns {string} absolute path
 */
function writePlanFile(datePrefix, slugPart, content) {
  const fname = `${datePrefix}-${slugPart}.md`;
  const p = path.join(plansDir, fname);
  fs.writeFileSync(p, content, 'utf8');
  return p;
}

before(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'plot-parser-test-'));
  plansDir = path.join(tmpDir, 'docs', 'plans');
  fs.mkdirSync(plansDir, { recursive: true });
});

after(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('parsePlan', () => {
  it('draft-plan.md → Draft phase, no sprint, no assignee', () => {
    const content = readFixture('draft-plan.md');
    const absPath = writePlanFile('2026-01-15', 'webhook-support', content);
    const card = parsePlan(absPath, tmpDir);

    assert.ok(card, 'parsePlan should return a card');
    assert.equal(card.slug, 'webhook-support');
    assert.equal(card.title, 'Add webhook support');
    assert.equal(card.type, 'feature');
    assert.equal(card.phase, 'Draft');
    assert.equal(card.path, path.join('docs', 'plans', '2026-01-15-webhook-support.md'));
    assert.equal(card.sprint, undefined, 'no sprint expected');
    assert.equal(card.assignee, undefined, 'no assignee expected');
  });

  it('approved-plan.md → Approved phase, sprint week-1, assignee eins78', () => {
    const content = readFixture('approved-plan.md');
    const absPath = writePlanFile('2026-03-15', 'board-sync', content);
    const card = parsePlan(absPath, tmpDir);

    assert.ok(card, 'parsePlan should return a card');
    assert.equal(card.slug, 'board-sync');
    assert.equal(card.title, 'Sync plan phase transitions to GitHub Projects board columns');
    assert.equal(card.type, 'feature');
    assert.equal(card.phase, 'Approved');
    assert.equal(card.sprint, 'week-1');
    assert.equal(card.assignee, 'eins78');
  });

  it('delivered-plan.md → Delivered phase, assignee eins78, no sprint', () => {
    const content = readFixture('delivered-plan.md');
    const absPath = writePlanFile('2026-02-11', 'sprint-support', content);
    const card = parsePlan(absPath, tmpDir);

    assert.ok(card, 'parsePlan should return a card');
    assert.equal(card.slug, 'sprint-support');
    assert.equal(card.title, 'Add sprint support to Plot');
    assert.equal(card.phase, 'Delivered');
    assert.equal(card.assignee, 'eins78');
    assert.equal(card.sprint, undefined, 'no sprint expected');
  });

  it('HTML-comment sprint placeholder → sprint field absent (not the comment string)', () => {
    const content = [
      '# My Plan',
      '',
      '## Status',
      '',
      '- **Phase:** Draft',
      '- **Type:** feature',
      '- **Sprint:** <!-- sprint slug or remove this line -->',
    ].join('\n');

    const absPath = writePlanFile('2026-05-01', 'html-sprint-test', content);
    const card = parsePlan(absPath, tmpDir);

    assert.ok(card, 'parsePlan should return a card');
    assert.equal(card.sprint, undefined, 'HTML-comment sprint placeholder should be treated as absent');
  });

  it('unknown Phase → returns null (and warns)', () => {
    const content = [
      '# Some Plan',
      '',
      '## Status',
      '',
      '- **Phase:** InProgress',
      '- **Type:** feature',
    ].join('\n');

    const absPath = writePlanFile('2026-05-01', 'bad-phase-test', content);

    // Suppress the console.warn noise during this test
    const originalWarn = console.warn;
    /** @type {string[]} */
    const warnings = [];
    console.warn = (...args) => { warnings.push(args.join(' ')); };

    let card;
    try {
      card = parsePlan(absPath, tmpDir);
    } finally {
      console.warn = originalWarn;
    }

    assert.equal(card, null, 'unknown phase should return null');
    assert.ok(
      warnings.some(w => w.includes('Unknown phase')),
      'should have warned about unknown phase'
    );
  });
});

describe('parseSprint', () => {
  it('active-sprint.md → slug alpha-week, title "Alpha week", phase Active', () => {
    const content = readFixture('active-sprint.md');
    // Sprint filename format: YYYY-Www-<slug>.md
    const sprintPath = path.join(tmpDir, '2026-W18-alpha-week.md');
    fs.writeFileSync(sprintPath, content, 'utf8');

    const sprint = parseSprint(sprintPath);

    assert.ok(sprint, 'parseSprint should return a sprint card');
    assert.equal(sprint.slug, 'alpha-week');
    assert.equal(sprint.title, 'Alpha week');
    assert.equal(sprint.phase, 'Active');
  });
});
