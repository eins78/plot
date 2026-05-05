// @ts-check
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { parsePlan, parseSprint } from './parser.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

/** @typedef {import('./parser.mjs').Phase} Phase */
/** @typedef {import('./parser.mjs').SprintPhase} SprintPhase */
/** @typedef {import('./parser.mjs').Card} Card */
/** @typedef {import('./parser.mjs').SprintCard} SprintCard */

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
const HOST = process.env.HOST ?? 'localhost';
const PHASES = /** @type {Phase[]} */ (['Draft', 'Approved', 'Delivered', 'Released']);

/** @type {Record<string, string>} */
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
};

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
      const card = parsePlan(resolved, REPO_ROOT);
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
server.listen(PORT, HOST, () => {
  console.log(`Plot board: http://localhost:${PORT}`);
  if (HOST === '0.0.0.0') {
    try {
      const tsIp = execFileSync('tailscale', ['ip', '-4'], { encoding: 'utf8' }).trim();
      if (tsIp) console.log(`  tailscale:  http://${tsIp}:${PORT}`);
    } catch { /* tailscale not running or not installed */ }
  }
});
