// @ts-check
import { html, render } from './vendor/lit-html.js';

// ─── Type definitions ────────────────────────────────────────────────────────

/**
 * @typedef {'Draft'|'Approved'|'Delivered'|'Released'} Phase
 */

/**
 * @typedef {'Planning'|'Committed'|'Active'|'Closed'} SprintPhase
 */

/**
 * @typedef {Object} Card
 * @property {string} slug
 * @property {string} title
 * @property {string} type - 'feature'|'bug'|'docs'|'infra' or unknown string
 * @property {Phase} phase
 * @property {string} [sprint] - sprint slug if assigned
 * @property {string} [assignee] - github handle
 * @property {string} path - relative path, e.g. 'docs/plans/2026-03-15-board-sync.md'
 */

/**
 * @typedef {Object} Column
 * @property {Phase} phase
 * @property {Card[]} cards
 */

/**
 * @typedef {Object} SprintCard
 * @property {string} slug
 * @property {string} title
 * @property {SprintPhase} phase
 */

/**
 * @typedef {Object} Board
 * @property {string} generatedAt - ISO timestamp
 * @property {Column[]} columns - always 4 columns in order: Draft, Approved, Delivered, Released
 * @property {SprintCard[]} sprints
 */

// ─── Module state ────────────────────────────────────────────────────────────

/** @type {Board|null} */
let lastBoard = null;

// ─── Rendering ───────────────────────────────────────────────────────────────

/**
 * Render a single card.
 * @param {Card} card
 * @param {string} selectedSprint - empty string means "all sprints"
 * @returns {unknown} lit-html TemplateResult
 */
function renderCard(card, selectedSprint) {
  const showSprintBadge = card.sprint && !selectedSprint;
  return html`
    <div class="card" data-phase=${card.phase}>
      <div class="card-title">${card.title}</div>
      <div class="card-badges">
        <span class="badge" data-type=${card.type}>${card.type}</span>
        ${showSprintBadge ? html`<span class="badge">${card.sprint}</span>` : ''}
      </div>
      <div class="card-path">${card.path}</div>
      ${card.assignee ? html`<div class="card-assignee">@${card.assignee}</div>` : ''}
    </div>
  `;
}

/**
 * Render the full board into #board.
 * @param {Board} board
 * @param {string} selectedSprint - empty string means "all sprints"
 * @returns {void}
 */
function renderBoard(board, selectedSprint) {
  const boardEl = document.getElementById('board');
  if (!boardEl) return;

  const columnsTemplate = html`
    ${board.columns.map(column => {
      const filteredCards = selectedSprint
        ? column.cards.filter(c => c.sprint === selectedSprint)
        : column.cards;

      return html`
        <div class="column" data-phase=${column.phase}>
          <div class="column-header">
            <h2>${column.phase}</h2>
            <span class="column-count">${filteredCards.length}</span>
          </div>
          <div class="column-cards">
            ${filteredCards.length > 0
              ? filteredCards.map(card => renderCard(card, selectedSprint))
              : html`<p class="empty-state">No plans in this phase.</p>`
            }
          </div>
        </div>
      `;
    })}
  `;

  render(columnsTemplate, boardEl);
}

// ─── Data loading ─────────────────────────────────────────────────────────────

/**
 * Fetch the board JSON from the API.
 * @returns {Promise<Board|null>} null on error (error message rendered into #board)
 */
async function fetchBoard() {
  const boardEl = document.getElementById('board');
  try {
    const response = await fetch('/api/board');
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return /** @type {Board} */ (await response.json());
  } catch (err) {
    if (boardEl) {
      render(
        html`<p class="empty-state">
          Failed to load board: ${err instanceof Error ? err.message : String(err)}
        </p>`,
        boardEl,
      );
    }
    return null;
  }
}

// ─── Sprint filter ────────────────────────────────────────────────────────────

/**
 * Read the current sprint slug from URLSearchParams.
 * @returns {string} sprint slug or empty string
 */
function getSprintFromUrl() {
  return new URLSearchParams(window.location.search).get('sprint') ?? '';
}

/**
 * Update the URL with the new sprint selection (replaceState, no reload).
 * @param {string} sprint - sprint slug or empty string for "all"
 * @returns {void}
 */
function setSprintInUrl(sprint) {
  const url = new URL(window.location.href);
  if (sprint) {
    url.searchParams.set('sprint', sprint);
  } else {
    url.searchParams.delete('sprint');
  }
  history.replaceState(null, '', url.toString());
}

/**
 * Populate the #sprint-filter <select> with sprints from the board.
 * Activates the option matching selectedSprint.
 * @param {SprintCard[]} sprints
 * @param {string} selectedSprint
 * @returns {void}
 */
function populateSprintFilter(sprints, selectedSprint) {
  const select = /** @type {HTMLSelectElement|null} */ (document.getElementById('sprint-filter'));
  if (!select) return;

  // Remove any previously-added options (keep the "All sprints" option at index 0)
  while (select.options.length > 1) {
    select.remove(1);
  }

  for (const sprint of sprints) {
    const option = document.createElement('option');
    option.value = sprint.slug;
    option.textContent = sprint.title;
    select.appendChild(option);
  }

  // Set the selected value — only if it matches a known sprint
  const knownSlugs = sprints.map(s => s.slug);
  if (selectedSprint && knownSlugs.includes(selectedSprint)) {
    select.value = selectedSprint;
  } else {
    select.value = '';
  }
}

// ─── Entry point ──────────────────────────────────────────────────────────────

/**
 * Wire up the app: load board, validate sprint, render once, attach handler.
 * @returns {Promise<void>}
 */
async function main() {
  const board = await fetchBoard();
  if (!board) return;
  lastBoard = board;

  // Validate the URL sprint slug against known sprints; clear if unknown.
  const rawSprint = getSprintFromUrl();
  const knownSlugs = board.sprints.map(s => s.slug);
  const selectedSprint = (rawSprint && knownSlugs.includes(rawSprint)) ? rawSprint : '';
  if (selectedSprint !== rawSprint) setSprintInUrl(selectedSprint);

  // Single render with the validated sprint — no double-render on bad slug.
  renderBoard(board, selectedSprint);
  populateSprintFilter(board.sprints, selectedSprint);

  const select = /** @type {HTMLSelectElement|null} */ (document.getElementById('sprint-filter'));
  if (select) {
    select.addEventListener('change', () => {
      const sprint = select.value;
      setSprintInUrl(sprint);
      if (lastBoard) renderBoard(lastBoard, sprint);
    });
  }
}

main();
