// @ts-check
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

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
 * @property {string} path - relative path under repo root (e.g. docs/plans/2026-03-15-board-sync.md)
 */

/**
 * @typedef {Object} SprintCard
 * @property {string} slug
 * @property {string} title
 * @property {SprintPhase} phase
 */

/**
 * @typedef {Object} Column
 * @property {Phase} phase
 * @property {Card[]} cards
 */

/**
 * @typedef {Object} Board
 * @property {string} generatedAt - ISO timestamp
 * @property {Column[]} columns
 * @property {SprintCard[]} sprints
 */

const REPO_ROOT = process.cwd(); // pnpm board runs from repo root
const PORT = Number(process.env.PORT ?? 7777);
const PHASES = /** @type {Phase[]} */ (['Draft', 'Approved', 'Delivered', 'Released']);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
};

/**
 * Parse a plan markdown file.
 * @param {string} absPath - absolute path to the plan .md file
 * @returns {Card|null} - null if Phase is unknown or file is unreadable
 */
function parsePlan(absPath) {
  let content;
  try {
    content = fs.readFileSync(absPath, 'utf8');
  } catch {
    return null;
  }

  // Extract title from first # heading
  const titleMatch = content.match(/^# (.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : path.basename(absPath, '.md');

  // Extract slug from filename: strip YYYY-MM-DD- prefix and .md extension
  const filename = path.basename(absPath);
  const slugMatch = filename.match(/^\d{4}-\d{2}-\d{2}-(.+)\.md$/);
  const slug = slugMatch ? slugMatch[1] : path.basename(absPath, '.md');

  // Extract path relative to REPO_ROOT
  const relPath = path.relative(REPO_ROOT, absPath);

  // Find the ## Status section (slice from ## Status to next ##)
  const statusSectionMatch = content.match(/^## Status\s*\n([\s\S]*?)(?=\n## |\n*$)/m);
  const statusSection = statusSectionMatch ? statusSectionMatch[1] : '';

  // Extract Phase
  const phaseMatch = statusSection.match(/^- \*\*Phase:\*\* (.+)$/m);
  const phase = phaseMatch ? phaseMatch[1].trim() : '';

  // Extract Type
  const typeMatch = statusSection.match(/^- \*\*Type:\*\* (.+)$/m);
  const type = typeMatch ? typeMatch[1].trim() : 'unknown';

  // Extract Sprint (treat HTML comment placeholders as absent)
  const sprintMatch = statusSection.match(/^- \*\*Sprint:\*\* (.+)$/m);
  let sprint;
  if (sprintMatch) {
    const sprintVal = sprintMatch[1].trim();
    if (!sprintVal.startsWith('<!--')) {
      sprint = sprintVal;
    }
  }

  // Find the ## Approval section (may not exist)
  const approvalSectionMatch = content.match(/^## Approval\s*\n([\s\S]*?)(?=\n## |\n*$)/m);
  let assignee;
  if (approvalSectionMatch) {
    const approvalSection = approvalSectionMatch[1];
    const assigneeMatch = approvalSection.match(/^- \*\*Assignee:\*\* (.+)$/m);
    if (assigneeMatch) {
      assignee = assigneeMatch[1].trim();
    }
  }

  // Validate Phase
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

  // Extract title from "# Sprint: <title>" pattern
  const titleMatch = content.match(/^# Sprint: (.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : path.basename(absPath, '.md');

  // Extract slug from filename: strip YYYY-Www- prefix
  const filename = path.basename(absPath);
  const slugMatch = filename.match(/^\d{4}-W\d{2}-(.+)\.md$/);
  const slug = slugMatch ? slugMatch[1] : path.basename(absPath, '.md');

  // Find ## Status section, extract Phase
  const statusSectionMatch = content.match(/^## Status\s*\n([\s\S]*?)(?=\n## |\n*$)/m);
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

/**
 * Walk plan/sprint directories and build the board JSON.
 * @returns {Board}
 */
function buildBoard() {
  const seen = new Set(); // Set of realpath strings for deduplication
  /** @type {Card[]} */
  const cards = [];

  // Walk in priority order: active/ first, then delivered/, then full plans/ dir
  const planDirs = [
    path.join(REPO_ROOT, 'docs/plans/active'),
    path.join(REPO_ROOT, 'docs/plans/delivered'),
    path.join(REPO_ROOT, 'docs/plans'),
  ];

  for (const dir of planDirs) {
    if (!fs.existsSync(dir)) continue;
    for (const entry of fs.readdirSync(dir)) {
      if (!entry.endsWith('.md')) continue;
      const entryPath = path.join(dir, entry);
      let resolved;
      try {
        resolved = fs.realpathSync(entryPath);
      } catch {
        continue; // broken symlink or unresolvable
      }
      if (seen.has(resolved)) continue;
      seen.add(resolved);
      const card = parsePlan(resolved);
      if (card) cards.push(card);
    }
  }

  /** @type {SprintCard[]} */
  const sprints = [];
  const sprintsDir = path.join(REPO_ROOT, 'docs/sprints/active');
  if (fs.existsSync(sprintsDir)) {
    for (const entry of fs.readdirSync(sprintsDir)) {
      if (!entry.endsWith('.md')) continue;
      const entryPath = path.join(sprintsDir, entry);
      let resolved;
      try { resolved = fs.realpathSync(entryPath); } catch { continue; }
      const sprint = parseSprint(resolved);
      if (sprint) sprints.push(sprint);
    }
  }

  // Group cards into columns
  const columns = PHASES.map(phase => ({
    phase,
    cards: cards.filter(c => c.phase === phase),
  }));

  return { generatedAt: new Date().toISOString(), columns, sprints };
}

/**
 * @param {http.IncomingMessage} req
 * @param {http.ServerResponse} res
 */
function handleRequest(req, res) {
  const url = new URL(req.url ?? '/', `http://localhost:${PORT}`);

  if (req.method !== 'GET') {
    res.writeHead(405); res.end('Method Not Allowed'); return;
  }

  // API endpoint
  if (url.pathname === '/api/board') {
    try {
      const board = buildBoard();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(board));
    } catch (err) {
      console.error('Error building board:', err);
      res.writeHead(500); res.end('Internal Server Error');
    }
    return;
  }

  // Static file serving
  // Map URL pathname to file on disk
  let filePath;
  if (url.pathname === '/' || url.pathname === '/index.html') {
    filePath = path.join(__dirname, 'index.html');
  } else {
    // All other requests: serve from the board directory
    // Strip leading slash, normalize to prevent directory traversal
    const relative = path.normalize(url.pathname.slice(1));
    if (relative.startsWith('..')) {
      res.writeHead(403); res.end('Forbidden'); return;
    }
    filePath = path.join(__dirname, relative);
  }

  // Read and serve the file
  try {
    const content = fs.readFileSync(filePath);
    const ext = path.extname(filePath);
    const contentType = MIME[ext] ?? 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(content);
  } catch {
    res.writeHead(404); res.end('Not Found');
  }
}

// Boot check: ensure we're running from the repo root
const plansDir = path.join(REPO_ROOT, 'docs/plans');
if (!fs.existsSync(plansDir)) {
  console.error(`Error: docs/plans/ not found. Run 'pnpm board' from the repo root.`);
  process.exit(1);
}

const server = http.createServer(handleRequest);
server.listen(PORT, 'localhost', () => {
  console.log(`Plot board: http://localhost:${PORT}`);
});
