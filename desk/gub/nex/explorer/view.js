// file view. One pane when source and preview would be the same thing
// (code, plain text — shown highlighted); Source | Preview tabs only when
// a genuinely different rendering exists (md, csv, svg, html, images,
// binary). Edit toggles the source pane between highlighted display and a
// textarea; Save is always present, enabled when dirty, and POSTs
// action=write-text to the file's own URL — the server tubes it through
// the grub's blot, so a failed parse comes back as a 422 tang in the
// status chip.
const name = document.body.dataset.name || '';
const texty = document.body.dataset.texty === '1';
const mite = document.body.dataset.mite || '';
const ed = document.getElementById('ed');
const display = document.getElementById('src-display');
const textView = document.getElementById('text-view');
const mimeView = document.getElementById('mime-view');
const tabText = document.getElementById('tab-text');
const tabMime = document.getElementById('tab-mime');
const editBtn = document.getElementById('edit');
const saveBtn = document.getElementById('save');
const liveBtn = document.getElementById('live');
const wrapBtn = document.getElementById('wrap');
const status = document.getElementById('status');

const ext = (name.match(/\.([a-z0-9]+)$/i) || [, ''])[1].toLowerCase();
const SHIKI_LANG = { js: 'javascript', mjs: 'javascript', ts: 'typescript',
                     json: 'json', css: 'css', hoon: 'hoon' };

// does this file have a preview that differs from its source?
const previewable =
  ['md', 'markdown', 'csv'].includes(ext) ||
  !!(window.FilePreview && FilePreview.kind(name)) ||
  !texty;

// ---- panes & tabs ----
let mimeRendered = false;
function show(which) {
  const text = which === 'text';
  textView.style.display = text ? '' : 'none';
  mimeView.style.display = text ? 'none' : '';
  tabText.classList.toggle('on', text);
  tabMime.classList.toggle('on', !text);
  if (!text && !mimeRendered) { renderMime(); mimeRendered = true; }
}
tabText.addEventListener('click', () => show('text'));
tabMime.addEventListener('click', () => show('mime'));

if (!previewable) {
  // single pane: the source IS the view
  tabText.style.display = 'none';
  tabMime.style.display = 'none';
  show('text');
} else if (!texty) {
  // binary: preview is the only view
  tabText.style.display = 'none';
  tabMime.style.display = 'none';
  show('mime');
} else {
  show('mime');
}

// ---- wrap toggle: applies to source display AND editor, remembered ----
let wrap = (localStorage.getItem('explorer-wrap') ?? '1') === '1';
function applyWrap() {
  document.body.classList.toggle('wrap', wrap);
  wrapBtn.classList.toggle('on', wrap);
}
wrapBtn.addEventListener('click', () => {
  wrap = !wrap;
  try { localStorage.setItem('explorer-wrap', wrap ? '1' : '0'); } catch (_) {}
  applyWrap();
});
applyWrap();

// ---- source display: highlighted, rebuilt from the textarea ----
async function renderSource() {
  if (!display || !ed) return;
  const src = ed.value;
  display.textContent = '';
  const p = document.createElement('pre');
  p.textContent = src;
  display.appendChild(p);
  if (SHIKI_LANG[ext]) {
    try {
      const hl = await getShiki(SHIKI_LANG[ext]);
      p.outerHTML = hl.codeToHtml(src, { lang: SHIKI_LANG[ext], theme: 'github-light' });
    } catch (_) {}
  }
}
renderSource();

// ---- edit toggle ----
let editing = false;
if (ed) {
  editBtn.addEventListener('click', () => {
    editing = !editing;
    editBtn.classList.toggle('on', editing);
    ed.style.display = editing ? '' : 'none';
    display.style.display = editing ? 'none' : '';
    if (editing) { show('text'); ed.focus(); }
    else renderSource();
  });
} else {
  editBtn.setAttribute('disabled', '');
}

// ---- save (+ optional Live autosave, default off: fine for plain text,
// noisy for anything a marc validates — invalid mid-states would 422) ----
if (ed) {
  let clean = ed.value;
  let live = false;
  let liveTimer = null;
  liveBtn.addEventListener('click', () => {
    live = !live;
    liveBtn.classList.toggle('on', live);
    syncSaveBtn();
    if (live && ed.value !== clean) scheduleLive();
  });
  // Live owns saving while it's on — the Save button stands down
  function syncSaveBtn() {
    if (live || ed.value === clean) saveBtn.setAttribute('disabled', '');
    else saveBtn.removeAttribute('disabled');
  }
  function scheduleLive() {
    clearTimeout(liveTimer);
    liveTimer = setTimeout(() => { if (ed.value !== clean) save(); }, 800);
  }
  ed.addEventListener('input', () => {
    syncSaveBtn();
    if (live) scheduleLive();
  });
  async function save() {
    status.textContent = 'saving…';
    status.className = '';
    try {
      const res = await fetch(location.pathname, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ action: 'write-text', content: ed.value }),
      });
      const body = await res.text();
      if (res.ok) {
        clean = ed.value;
        syncSaveBtn();
        status.textContent = 'saved ✓';
        mimeRendered = false;
        mimeView.textContent = '';
        setTimeout(() => { if (status.textContent === 'saved ✓') status.textContent = ''; }, 2500);
      } else {
        status.className = 'err';
        status.textContent = body || ('save failed (' + res.status + ')');
      }
    } catch (e) {
      status.className = 'err';
      status.textContent = 'save failed: ' + e;
    }
  }
  saveBtn.addEventListener('click', () => {
    if (!saveBtn.hasAttribute('disabled')) save();
  });
  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      if (ed.value !== clean) save();
    }
  });
  // tab key inserts spaces instead of leaving the editor
  ed.addEventListener('keydown', (e) => {
    if (e.key !== 'Tab') return;
    e.preventDefault();
    const [s, epos] = [ed.selectionStart, ed.selectionEnd];
    ed.setRangeText('  ', s, epos, 'end');
    ed.dispatchEvent(new Event('input'));
  });
} else {
  saveBtn.setAttribute('disabled', '');
  liveBtn.setAttribute('disabled', '');
}

// ---- preview renderers ----
async function renderMime() {
  const rawUrl = location.pathname + '?raw=1';
  const text = ed ? ed.value : (document.getElementById('src')?.textContent ?? '');
  mimeView.textContent = '';

  // rendered markdown, via the same marked the docs use
  if (ext === 'md' || ext === 'markdown') {
    const d = document.createElement('div');
    d.className = 'md';
    try {
      if (!window.marked) await loadScript('/grubbery/ball/apps/explorer.explorer/marked.min.js');
      d.innerHTML = marked.parse(text);
    } catch (_) { d.textContent = text; }
    mimeView.appendChild(d);
    return;
  }

  // csv → table (simple split; quoted commas render imperfectly, fine)
  if (ext === 'csv') {
    const rows = text.trim().split('\n').map(r => r.split(','));
    const t = document.createElement('table');
    t.className = 'csv';
    rows.forEach((r, i) => {
      const tr = document.createElement('tr');
      r.forEach(c => {
        const cell = document.createElement(i === 0 ? 'th' : 'td');
        cell.textContent = c.trim();
        tr.appendChild(cell);
      });
      t.appendChild(tr);
    });
    mimeView.appendChild(t);
    return;
  }

  // svg / html / raster via the shared FilePreview surface
  if (window.FilePreview && FilePreview.kind(name)) {
    FilePreview.render(mimeView, { name, text, rawUrl });
    return;
  }

  // binary: name the mite, offer the bytes
  const p = document.createElement('pre');
  p.className = 'dim';
  const a = document.createElement('a');
  a.href = rawUrl;
  a.textContent = 'download raw bytes';
  a.style.color = '#0969da';
  p.append(mite + '\n\n', a);
  mimeView.appendChild(p);
}

function loadScript(src) {
  return new Promise((res, rej) => {
    const sc = document.createElement('script');
    sc.src = src;
    sc.onload = res;
    sc.onerror = rej;
    document.head.appendChild(sc);
  });
}

// one shared highlighter; the hoon grammar loads only when asked for
let shikiP = null;
async function getShiki(lang) {
  if (!shikiP) {
    shikiP = (async () => {
      const { createHighlighter } = await import('https://esm.sh/shiki@1.24.0');
      return createHighlighter({ themes: ['github-light'], langs: [] });
    })();
  }
  const hl = await shikiP;
  if (!hl.getLoadedLanguages().includes(lang)) {
    if (lang === 'hoon') {
      const grammar = await (await fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')).json();
      await hl.loadLanguage(grammar);
    } else {
      await hl.loadLanguage(lang);
    }
  }
  return hl;
}
