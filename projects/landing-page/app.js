// HomeBase — app.js
// Handles tile rendering, add/edit/delete, and localStorage persistence.

const STORAGE_KEY = 'homebase_tiles';

let tiles = [];
let editingIndex = null;

// ─── Storage ──────────────────────────────────────────────────────────────────

function loadTiles() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (raw) {
    try {
      tiles = JSON.parse(raw);
      return;
    } catch {
      // corrupted data — fall through to defaults
    }
  }
  tiles = DEFAULT_TILES.map(t => ({ ...t }));
}

function saveTiles() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(tiles));
}

// ─── Favicon helpers ──────────────────────────────────────────────────────────

function getDomain(url) {
  try { return new URL(url).hostname; }
  catch { return url; }
}

function faviconSrc(url) {
  return `https://www.google.com/s2/favicons?domain=${getDomain(url)}&sz=64`;
}

function initial(name) {
  return (name || '?').trim().charAt(0).toUpperCase();
}

// ─── Rendering ────────────────────────────────────────────────────────────────

function renderTiles() {
  const grid  = document.getElementById('tile-grid');
  const empty = document.getElementById('empty-state');
  grid.innerHTML = '';

  if (tiles.length === 0) {
    empty.classList.remove('hidden');
    return;
  }
  empty.classList.add('hidden');

  tiles.forEach((tile, index) => {
    const a = document.createElement('a');
    a.className = 'tile';
    a.href = tile.url;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';

    // Favicon with letter-avatar fallback
    const img = document.createElement('img');
    img.className = 'favicon';
    img.src = faviconSrc(tile.url);
    img.alt = '';
    img.loading = 'lazy';

    const fallback = document.createElement('div');
    fallback.className = 'favicon-fallback';
    fallback.textContent = initial(tile.name);
    fallback.style.display = 'none';

    img.addEventListener('error', () => {
      img.style.display = 'none';
      fallback.style.display = 'flex';
    });

    // Name label
    const nameEl = document.createElement('span');
    nameEl.className = 'tile-name';
    nameEl.textContent = tile.name;
    nameEl.title = tile.name;

    // Action buttons
    const actions = document.createElement('div');
    actions.className = 'tile-actions';

    const editBtn = document.createElement('button');
    editBtn.className = 'tile-action-btn edit';
    editBtn.title = 'Edit';
    editBtn.setAttribute('aria-label', `Edit ${tile.name}`);
    editBtn.textContent = '✎';
    editBtn.addEventListener('click', e => {
      e.preventDefault();
      e.stopPropagation();
      openEditModal(index);
    });

    const delBtn = document.createElement('button');
    delBtn.className = 'tile-action-btn delete';
    delBtn.title = 'Remove';
    delBtn.setAttribute('aria-label', `Remove ${tile.name}`);
    delBtn.textContent = '✕';
    delBtn.addEventListener('click', e => {
      e.preventDefault();
      e.stopPropagation();
      removeTile(index);
    });

    actions.append(editBtn, delBtn);
    a.append(img, fallback, nameEl, actions);
    grid.appendChild(a);
  });
}

// ─── CRUD ─────────────────────────────────────────────────────────────────────

function removeTile(index) {
  if (!confirm(`Remove "${tiles[index].name}"?`)) return;
  tiles.splice(index, 1);
  saveTiles();
  renderTiles();
}

function saveTileFromForm() {
  const name = document.getElementById('tile-name').value.trim();
  let   url  = document.getElementById('tile-url').value.trim();
  const err  = document.getElementById('form-error');

  if (!name) { showError('Please enter a name.'); return false; }
  if (!url)  { showError('Please enter a URL.');  return false; }

  // Auto-prefix protocol if missing
  if (!/^https?:\/\//i.test(url)) {
    url = 'https://' + url;
    document.getElementById('tile-url').value = url;
  }

  try { new URL(url); }
  catch { showError('That doesn\'t look like a valid URL.'); return false; }

  if (editingIndex !== null) {
    tiles[editingIndex] = { name, url };
  } else {
    tiles.push({ name, url });
  }

  saveTiles();
  renderTiles();
  return true;
}

function showError(msg) {
  const el = document.getElementById('form-error');
  el.textContent = msg;
  el.classList.remove('hidden');
}

// ─── Modal ────────────────────────────────────────────────────────────────────

function openAddModal() {
  editingIndex = null;
  document.getElementById('modal-title').textContent = 'Add Tile';
  document.getElementById('tile-name').value = '';
  document.getElementById('tile-url').value  = '';
  document.getElementById('form-error').classList.add('hidden');
  document.getElementById('modal-overlay').classList.remove('hidden');
  document.getElementById('tile-name').focus();
}

function openEditModal(index) {
  editingIndex = index;
  const t = tiles[index];
  document.getElementById('modal-title').textContent = 'Edit Tile';
  document.getElementById('tile-name').value = t.name;
  document.getElementById('tile-url').value  = t.url;
  document.getElementById('form-error').classList.add('hidden');
  document.getElementById('modal-overlay').classList.remove('hidden');
  document.getElementById('tile-name').focus();
}

function closeModal() {
  document.getElementById('modal-overlay').classList.add('hidden');
  editingIndex = null;
}

// ─── Event listeners ──────────────────────────────────────────────────────────

document.getElementById('add-tile-btn').addEventListener('click', openAddModal);

document.getElementById('tile-form').addEventListener('submit', e => {
  e.preventDefault();
  if (saveTileFromForm()) closeModal();
});

document.getElementById('modal-cancel').addEventListener('click', closeModal);

// Close on backdrop click
document.getElementById('modal-overlay').addEventListener('click', e => {
  if (e.target === document.getElementById('modal-overlay')) closeModal();
});

// Close on Escape
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeModal();
});

// ─── Init ─────────────────────────────────────────────────────────────────────

loadTiles();
renderTiles();
