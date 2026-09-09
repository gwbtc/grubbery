// file view. Static shell (view.html) driven by two fetches of the file's
// own URL: ?info=1 says what it is (blot, mime, build status, fiber bang;
// or kind=boom with the tang, or kind=missing), ?raw=1 gives the bytes.
// One pane when source and preview would be the same thing (code, plain
// text — shown highlighted); Source | Preview tabs only when a genuinely
// different rendering exists (md, csv, svg, html, images, binary). Edit
// toggles the source pane between highlighted display and a textarea;
// Save is always present, enabled when dirty, and POSTs action=write-text
// to the file's own URL — the server tubes it through the grub's blot, so
// a failed parse comes back as a 422 tang in the error overlay.
const $ = (id) => document.getElementById(id);
const here = location.pathname;
const name = decodeURIComponent(here.split('/').filter(Boolean).pop() || '');
const ext = (name.match(/\.([a-z0-9]+)$/i) || [, ''])[1].toLowerCase();

const ed = $('ed');
const edwrap = $('edwrap');
const display = $('src-display');
const src = $('src');
const textView = $('text-view');
const mimeView = $('mime-view');
const buildView = $('build-view');
const tabText = $('tab-text');
const tabMime = $('tab-mime');
const tabBuild = $('tab-build');
const editBtn = $('edit');
const saveBtn = $('save');
const liveBtn = $('live');
const wrapBtn = $('wrap');
const status = $('status');
const tools = $('tools');
const mimeInput = $('mime-input');
const errOverlay = $('save-err-overlay');
const errBody = $('save-err-body');

// ---- bar: crumbs, name, chips ----
document.title = name || 'explorer';
$('fname').textContent = name;
(function crumbs() {
  const wrap = $('crumbs');
  const parts = here.replace('/grubbery/ball', '').split('/').filter(Boolean);
  const mk = (t, href) => {
    const a = document.createElement('a');
    a.href = href; a.textContent = t;
    return a;
  };
  let acc = '/grubbery/ball';
  wrap.appendChild(mk('/', acc));
  parts.slice(0, -1).forEach(s => { acc += '/' + s; wrap.appendChild(mk(s + '/', acc)); });
})();
function chip(id, text) {
  const c = $(id);
  c.querySelector('.v').textContent = text;
  c.style.display = '';
}

// ---- the one error overlay, titled per use ----
$('save-err-close').addEventListener('click', () => { errOverlay.style.display = 'none'; });
errOverlay.addEventListener('click', (e) => { if (e.target === errOverlay) errOverlay.style.display = 'none'; });
function showErr(title, text) {
  $('save-err-title').textContent = title;
  errBody.textContent = text;
  errOverlay.style.display = '';
}

// ---- boot ----
let info = null;
let mite = '';
let texty = false;
let editable = false;
let buildStatus = '';
(async function boot() {
  try {
    info = await (await fetch(here + '?info=1', { headers: { accept: 'application/json' } })).json();
  } catch (e) {
    showErr('explorer', 'could not load file info: ' + e);
    return;
  }
  if (info.bang) {
    const b = $('bang-chip');
    b.style.display = '';
    b.addEventListener('click', () => showErr('fiber crashed', info.bang));
  }
  if (info.kind === 'missing') return renderMissing();
  if (info.kind === 'boom') return renderBoom();
  await renderFile();
})();

function renderMissing() {
  const parent = here.replace(/\/[^/]*$/, '') || '/grubbery/ball';
  $('missing-path').textContent = 'There is no file or directory at ' + (info.path || here.replace('/grubbery/ball', '') || '/') + '.';
  const up = $('missing-up');
  up.href = parent;
  up.textContent = 'back to ' + (parent.replace('/grubbery/ball', '') || '/');
  $('missing').style.display = '';
}

function renderBoom() {
  chip('chip-blot', info.blot || '');
  chip('chip-mime', 'boomed');
  src.className = 'boom';
  src.textContent = info.boom || 'validation failed';
  src.style.display = '';
}

async function renderFile() {
  mite = info.mite || '';
  texty = !!info.texty;
  editable = texty && !info.jammed;
  buildStatus = (info.build && info.build.status) || '';
  chip('chip-blot', info.blot || '');
  chip('chip-mime', mite);
  mimeInput.value = mite;
  tools.style.display = '';
  $('mime-row').style.display = '';
  if (buildStatus) tabBuild.style.display = '';

  if (editable) {
    ed.value = present(await readRaw());
    edwrap.style.display = '';
  } else if (info.jammed) {
    src.textContent = info.text || '';
    src.style.display = '';
  } else {
    src.className = 'dim';
    src.textContent = 'binary content';
    src.style.display = '';
  }
  setupPanes();
  setupWrap();
  setupEditor();
  renderSource();
}

// ---- what the editor shows is the server's bytes, presented ----
// The marc, not the editor, owns the canonical form: json comes back
// compact whatever you typed. So every read from the backend goes
// through present() before it lands in the textarea — json gets the
// same pretty-print the Preview's text mode uses; everything else is
// shown as-is. After a save the file is re-read and re-presented, so
// the pane always shows what is actually stored.
function readRaw() {
  return fetch(here + '?raw=1').then(r => r.text());
}
function present(text) {
  if (ext === 'json') {
    try { return JSON.stringify(JSON.parse(text), null, 2); } catch (_) {}
  }
  return text;
}

const SHIKI_LANG = { js: 'javascript', mjs: 'javascript', ts: 'typescript',
                     json: 'json', css: 'css', hoon: 'hoon' };

// ---- panes & tabs ----
let mimeRendered = false;
let buildRendered = false;
function show(which) {
  textView.style.display = which === 'text' ? '' : 'none';
  mimeView.style.display = which === 'mime' ? '' : 'none';
  buildView.style.display = which === 'build' ? '' : 'none';
  tabText.classList.toggle('on', which === 'text');
  tabMime.classList.toggle('on', which === 'mime');
  tabBuild.classList.toggle('on', which === 'build');
  tools.style.display = which === 'text' ? '' : 'none';
  if (which === 'mime' && !mimeRendered) { renderMime(); mimeRendered = true; }
  if (which === 'build' && !buildRendered) { renderBuild(); buildRendered = true; }
}
function setupPanes() {
  // does this file have a preview that differs from its source?
  const previewable =
    ['md', 'markdown', 'csv'].includes(ext) ||
    !!(window.FilePreview && FilePreview.kind(name)) ||
    !texty;
  tabText.addEventListener('click', () => show('text'));
  tabMime.addEventListener('click', () => show('mime'));
  tabBuild.addEventListener('click', () => show('build'));
  const showTabs = previewable || buildStatus;
  tabText.style.display = showTabs ? '' : 'none';
  tabMime.style.display = showTabs ? '' : 'none';
  if (!previewable) show('text');
  else show('mime');
}

// ---- wrap toggle: applies to source display AND editor, remembered ----
function setupWrap() {
  let wrap = true;
  try { wrap = (localStorage.getItem('explorer-wrap') ?? '1') === '1'; } catch (_) {}
  const applyWrap = () => {
    document.body.classList.toggle('wrap', wrap);
    wrapBtn.classList.toggle('on', wrap);
  };
  wrapBtn.addEventListener('click', () => {
    wrap = !wrap;
    try { localStorage.setItem('explorer-wrap', wrap ? '1' : '0'); } catch (_) {}
    applyWrap();
  });
  applyWrap();
}

// ---- source display: highlighted, rebuilt from the textarea ----
async function renderSource() {
  if (!editable) return;
  const text = ed.value;
  display.textContent = '';
  const p = document.createElement('pre');
  p.textContent = text;
  display.appendChild(p);
  if (SHIKI_LANG[ext]) {
    try {
      const hl = await getShiki(SHIKI_LANG[ext]);
      p.outerHTML = hl.codeToHtml(text, { lang: SHIKI_LANG[ext], theme: 'github-light' });
    } catch (_) {}
  }
}

// ---- edit toggle + save (+ optional Live autosave, default off: fine
// for plain text, noisy for anything a marc validates — invalid
// mid-states would 422) ----
function setupEditor() {
  if (!editable) {
    editBtn.setAttribute('disabled', '');
    saveBtn.setAttribute('disabled', '');
    liveBtn.setAttribute('disabled', '');
    return;
  }
  let editing = false;
  editBtn.addEventListener('click', () => {
    editing = !editing;
    editBtn.classList.toggle('on', editing);
    ed.style.display = editing ? '' : 'none';
    display.style.display = editing ? 'none' : '';
    mimeInput.readOnly = !editing;
    if (editing) { show('text'); ed.focus(); }
    else renderSource();
  });

  let clean = ed.value;
  let live = false;
  let liveTimer = null;
  let miteChanged = false;
  liveBtn.addEventListener('click', () => {
    live = !live;
    liveBtn.classList.toggle('on', live);
    syncSaveBtn();
    if (live && ed.value !== clean) scheduleLive();
  });
  // Live owns saving while it's on — the Save button stands down
  function syncSaveBtn() {
    if (live || (ed.value === clean && !miteChanged)) saveBtn.setAttribute('disabled', '');
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
  mimeInput.addEventListener('input', () => {
    miteChanged = mimeInput.value.trim() !== mite;
    syncSaveBtn();
  });
  async function save() {
    status.textContent = 'saving…';
    status.className = '';
    const sent = ed.value;
    try {
      const res = await fetch(here, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(Object.assign(
          { action: 'write-text', content: sent },
          miteChanged ? { mite: mimeInput.value.trim() } : {}
        )),
      });
      const body = await res.text();
      if (res.ok) {
        // read back what the marc actually stored; only swap the pane
        // if nothing was typed while the save was in flight
        const stored = present(await readRaw());
        clean = stored;
        if (ed.value === sent && stored !== sent) {
          const [s, epos] = [ed.selectionStart, ed.selectionEnd];
          ed.value = stored;
          ed.setSelectionRange(Math.min(s, stored.length), Math.min(epos, stored.length));
          if (!editing) renderSource();
        }
        mite = mimeInput.value.trim();
        miteChanged = false;
        syncSaveBtn();
        status.textContent = 'saved ✓';
        mimeRendered = false;
        mimeView.textContent = '';
        setTimeout(() => { if (status.textContent === 'saved ✓') status.textContent = ''; }, 2500);
      } else {
        ed.value = clean;
        syncSaveBtn();
        status.textContent = '';
        showErr('save failed', body || ('save failed (' + res.status + ')'));
      }
    } catch (e) {
      ed.value = clean;
      syncSaveBtn();
      status.textContent = '';
      showErr('save failed', 'save failed: ' + e);
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
}

// ---- preview renderers ----
async function renderMime() {
  const rawUrl = here + '?raw=1';
  const text = editable ? ed.value : (src.textContent ?? '');
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

function renderBuild() {
  if (!buildStatus) return;
  const detail = (info.build && info.build.detail) || '';
  buildView.textContent = '';
  const badge = document.createElement('div');
  badge.id = 'build-badge';
  if (buildStatus === 'vase') {
    badge.className = 'ok';
    badge.textContent = 'compiled';
  } else if (buildStatus === 'tang') {
    badge.className = 'err';
    badge.textContent = 'build error';
  } else {
    badge.className = 'raw';
    badge.textContent = 'raw ' + buildStatus;
  }
  buildView.appendChild(badge);
  if (detail) {
    const pre = document.createElement('pre');
    pre.style.cssText = 'margin:0;white-space:pre-wrap;overflow-wrap:anywhere;';
    pre.textContent = detail;
    buildView.appendChild(pre);
  }
}
