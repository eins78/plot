// @ts-check
/**
 * Integration tests for the board walker (buildBoard) via the HTTP server.
 *
 * Strategy: spin up a real server process (`node skills/plot/scripts/board/server.mjs`)
 * with CWD = a temp dir configured for each test scenario, hit GET /api/board,
 * and assert the returned Board JSON.
 */

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import net from 'node:net';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../..');
const SERVER_PATH = path.join(REPO_ROOT, 'skills/plot/scripts/board/server.mjs');
const FIXTURES_DIR = path.join(__dirname, 'fixtures');

// ── Fixture content ───────────────────────────────────────────────────────────

function readFixture(name) {
  return fs.readFileSync(path.join(FIXTURES_DIR, name), 'utf8');
}

const DRAFT_CONTENT = readFixture('draft-plan.md');
const APPROVED_CONTENT = readFixture('approved-plan.md');
const DELIVERED_CONTENT = readFixture('delivered-plan.md');
const SPRINT_CONTENT = readFixture('active-sprint.md');

// ── Port allocation ───────────────────────────────────────────────────────────

/**
 * Find a free port by binding to port 0 and reading the assigned port.
 * @returns {Promise<number>}
 */
function findFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      if (!address || typeof address === 'string') {
        server.close();
        reject(new Error('Could not get port'));
        return;
      }
      const { port } = address;
      server.close(() => resolve(port));
    });
    server.on('error', reject);
  });
}

// ── Server lifecycle ──────────────────────────────────────────────────────────

/**
 * @typedef {Object} ServerHandle
 * @property {number} port
 * @property {() => void} kill
 */

/**
 * Start the board server with the given CWD and wait until it's ready.
 * @param {string} cwd - directory to run the server from (must have docs/plans/)
 * @param {number} port - port to bind the server on
 * @returns {Promise<ServerHandle>}
 */
function startServer(cwd, port) {
  return new Promise((resolve, reject) => {
    const proc = spawn('node', [SERVER_PATH], {
      cwd,
      env: { ...process.env, PORT: String(port) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    /** @type {string[]} */
    const stderrLines = [];
    let resolved = false;

    const timeout = setTimeout(() => {
      if (!resolved) {
        proc.kill('SIGTERM');
        reject(new Error(
          `Server did not start within 5s.\nstderr: ${stderrLines.join('\n')}`
        ));
      }
    }, 5000);

    proc.stdout.on('data', (/** @type {Buffer} */ chunk) => {
      const text = chunk.toString();
      if (!resolved && text.includes(`http://localhost:`)) {
        resolved = true;
        clearTimeout(timeout);
        resolve({
          port,
          kill: () => proc.kill('SIGTERM'),
        });
      }
    });

    proc.stderr.on('data', (/** @type {Buffer} */ chunk) => {
      stderrLines.push(chunk.toString());
    });

    proc.on('error', (err) => {
      clearTimeout(timeout);
      if (!resolved) reject(err);
    });

    proc.on('exit', (code) => {
      clearTimeout(timeout);
      if (!resolved) {
        reject(new Error(
          `Server exited with code ${code} before becoming ready.\nstderr: ${stderrLines.join('\n')}`
        ));
      }
    });
  });
}

/**
 * GET /api/board from the server at the given port.
 * @param {number} port
 * @returns {Promise<import('./..').Board>}
 */
function fetchBoard(port) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:${port}/api/board`, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      });
    }).on('error', reject);
  });
}

// ── Temp dir scaffold helpers ─────────────────────────────────────────────────

/**
 * Create a minimal temp repo layout.
 * @param {{
 *   plans?: Array<{ date: string, slug: string, content: string }>,
 *   activePlans?: Array<{ target: string }>,
 *   sprints?: Array<{ file: string, content: string }>,
 * }} opts
 * @returns {string} tmp dir path
 */
function createTempRepo(opts = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'plot-walker-test-'));
  const plansDir = path.join(tmp, 'docs', 'plans');
  fs.mkdirSync(plansDir, { recursive: true });

  for (const plan of (opts.plans ?? [])) {
    const fname = `${plan.date}-${plan.slug}.md`;
    fs.writeFileSync(path.join(plansDir, fname), plan.content, 'utf8');
  }

  if (opts.activePlans && opts.activePlans.length > 0) {
    const activeDir = path.join(tmp, 'docs', 'plans', 'active');
    fs.mkdirSync(activeDir, { recursive: true });
    for (const link of opts.activePlans) {
      const target = path.join(plansDir, link.target);
      const linkPath = path.join(activeDir, link.target);
      fs.symlinkSync(target, linkPath);
    }
  }

  if (opts.sprints && opts.sprints.length > 0) {
    const sprintsDir = path.join(tmp, 'docs', 'sprints', 'active');
    fs.mkdirSync(sprintsDir, { recursive: true });
    for (const sprint of opts.sprints) {
      fs.writeFileSync(path.join(sprintsDir, sprint.file), sprint.content, 'utf8');
    }
  }

  return tmp;
}

// ── Test suite: missing dirs ──────────────────────────────────────────────────

describe('walker: missing optional dirs', () => {
  /** @type {string} */
  let tmpDir;
  /** @type {ServerHandle} */
  let server;

  before(async () => {
    tmpDir = createTempRepo({
      plans: [
        { date: '2026-01-15', slug: 'webhook-support', content: DRAFT_CONTENT },
      ],
      // No active/, no delivered/, no docs/sprints/
    });
    const port = await findFreePort();
    server = await startServer(tmpDir, port);
  });

  after(() => {
    if (server) server.kill();
    if (tmpDir) fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('returns valid Board JSON with 4 columns when optional dirs are absent', async () => {
    const board = await fetchBoard(server.port);

    assert.ok(board.generatedAt, 'generatedAt should be present');
    assert.ok(Array.isArray(board.columns), 'columns should be an array');
    assert.equal(board.columns.length, 4, 'exactly 4 columns (one per phase)');
    assert.ok(Array.isArray(board.sprints), 'sprints should be an array');
    assert.equal(board.sprints.length, 0, 'no sprints when docs/sprints absent');

    // Verify column phase labels
    const phases = board.columns.map((/** @type {any} */ c) => c.phase);
    assert.deepEqual(phases, ['Draft', 'Approved', 'Delivered', 'Released']);

    // The one draft plan should appear
    const draftCards = board.columns.find((/** @type {any} */ c) => c.phase === 'Draft')?.cards ?? [];
    assert.equal(draftCards.length, 1, 'draft plan should appear in Draft column');
    assert.equal(draftCards[0].slug, 'webhook-support');
  });
});

// ── Test suite: symlink deduplication ────────────────────────────────────────

describe('walker: symlink deduplication', () => {
  /** @type {string} */
  let tmpDir;
  /** @type {ServerHandle} */
  let server;

  before(async () => {
    tmpDir = createTempRepo({
      plans: [
        { date: '2026-03-15', slug: 'board-sync', content: APPROVED_CONTENT },
      ],
      activePlans: [
        { target: '2026-03-15-board-sync.md' }, // symlink to the plan
      ],
    });
    const port = await findFreePort();
    server = await startServer(tmpDir, port);
  });

  after(() => {
    if (server) server.kill();
    if (tmpDir) fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('plan symlinked from active/ appears exactly once in board JSON', async () => {
    const board = await fetchBoard(server.port);

    // Count total cards across all columns
    const allCards = board.columns.flatMap((/** @type {any} */ c) => c.cards);
    assert.equal(allCards.length, 1, 'plan should appear exactly once despite symlink');
    assert.equal(allCards[0].slug, 'board-sync');
  });
});

// ── Test suite: broken symlink ────────────────────────────────────────────────

describe('walker: broken symlink tolerance', () => {
  /** @type {string} */
  let tmpDir;
  /** @type {ServerHandle} */
  let server;

  before(async () => {
    // Create a repo with one real plan and one broken symlink in active/
    tmpDir = createTempRepo({
      plans: [
        { date: '2026-02-11', slug: 'sprint-support', content: DELIVERED_CONTENT },
      ],
    });

    // Manually add a broken symlink in active/
    const activeDir = path.join(tmpDir, 'docs', 'plans', 'active');
    fs.mkdirSync(activeDir, { recursive: true });
    const brokenLinkPath = path.join(activeDir, '2026-01-01-deleted-plan.md');
    // Point to a file that doesn't exist
    fs.symlinkSync(
      path.join(tmpDir, 'docs', 'plans', '2026-01-01-deleted-plan.md'),
      brokenLinkPath
    );

    const port = await findFreePort();
    server = await startServer(tmpDir, port);
  });

  after(() => {
    if (server) server.kill();
    if (tmpDir) fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('server ignores broken symlinks and returns valid Board JSON', async () => {
    const board = await fetchBoard(server.port);

    assert.ok(board.generatedAt, 'board should have generatedAt');
    assert.equal(board.columns.length, 4, '4 columns present');

    // The real delivered plan should appear
    const deliveredCards = board.columns.find((/** @type {any} */ c) => c.phase === 'Delivered')?.cards ?? [];
    assert.equal(deliveredCards.length, 1, 'real delivered plan should appear');
    assert.equal(deliveredCards[0].slug, 'sprint-support');
  });
});

// ── Test suite: sprint discovery ─────────────────────────────────────────────

describe('walker: sprint discovery', () => {
  /** @type {string} */
  let tmpDir;
  /** @type {ServerHandle} */
  let server;

  before(async () => {
    tmpDir = createTempRepo({
      plans: [
        { date: '2026-01-15', slug: 'webhook-support', content: DRAFT_CONTENT },
      ],
      sprints: [
        { file: '2026-W18-alpha-week.md', content: SPRINT_CONTENT },
      ],
    });
    const port = await findFreePort();
    server = await startServer(tmpDir, port);
  });

  after(() => {
    if (server) server.kill();
    if (tmpDir) fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('active sprint appears in board.sprints', async () => {
    const board = await fetchBoard(server.port);

    assert.ok(Array.isArray(board.sprints), 'sprints should be an array');
    assert.equal(board.sprints.length, 1, 'one sprint should be discovered');
    assert.equal(board.sprints[0].slug, 'alpha-week');
    assert.equal(board.sprints[0].title, 'Alpha week');
    assert.equal(board.sprints[0].phase, 'Active');
  });
});
