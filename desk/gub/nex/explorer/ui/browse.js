// TODO: extract the file/dir table into a <file-table> web component in
// lib/ui/. Accept rows as a JS property, declare columns via config, emit
// events (file-rename, file-move, file-delete, etc.) instead of POSTing
// directly. Host page wires events to its backend. Enables a Finder-like
// app and other directory UIs to reuse the same table.
//
// explorer browse app. Renders a directory from <dir>?list=1 and drives
// every action through the same POST endpoints the sail page used —
// success re-fetches the listing in place (no page reloads), failure
// shows the server's text in the status toast. Dialogs are kit
// <modal-dialog>s. Navigation is plain links: the server serves this
// same shell for every directory.
const $ = (id) => document.getElementById(id);
const PREFIX = '/grubbery/ball';
let here = location.pathname;                         // /grubbery/ball/docs/desktop
let dirPath = here.slice(PREFIX.length) || '/';       // /docs/desktop

// dir navigation is client-side: swap the path, refetch the listing —
// one request instead of shell + peek + listing. File links (different
// page) still navigate normally; only links we mark data-nav intercept.
function nav(p, push) {
  here = p;
  dirPath = p.slice(PREFIX.length) || '/';
  if (push !== false) history.pushState(null, '', p);
  document.title = dirPath;
  renderCrumbs();
  showLoading();
  load();
}
document.addEventListener('click', (e) => {
  const a = e.target.closest('a[data-nav]');
  if (!a || e.metaKey || e.ctrlKey || e.shiftKey) return;
  e.preventDefault();
  nav(new URL(a.href).pathname);
});
window.addEventListener('popstate', () => nav(location.pathname, false));

function showLoading() {
  $('rows').innerHTML =
    '<tr><td colspan="6" style="color:#8b949e"><span class="dload">\u25c6</span> loading\u2026</td></tr>';
}

let data = null;
let sortKey = 'name';
let sortDir = 1;

// the URL alone renders the crumbs — do it before any network
renderCrumbs();
document.title = dirPath;

// ---- fetch + render ----
async function load() {
  try {
    const r = await fetch(here + '?list=1');
    if (!r.ok) throw new Error(r.status);
    data = await r.json();
  } catch (e) {
    toast('listing failed: ' + e, true);
    return;
  }
  renderChips();
  renderBang();
  renderRows();
  renderManage();
  if ($('weir-modal').hasAttribute('open')) renderWeir();
}

function renderCrumbs() {
  const c = $('crumbs');
  c.textContent = '';
  const segs = dirPath === '/' ? [] : dirPath.slice(1).split('/');
  const a = document.createElement('a');
  a.href = PREFIX;
  a.textContent = '/';
  a.dataset.nav = '1';
  c.appendChild(a);
  let acc = '';
  segs.forEach((s, i) => {
    acc += '/' + s;
    if (i === segs.length - 1) {
      const sp = document.createElement('span');
      sp.className = 'here';
      sp.textContent = s + '/';
      c.appendChild(sp);
    } else {
      const l = document.createElement('a');
      l.href = PREFIX + acc;
      l.textContent = s + '/';
      l.dataset.nav = '1';
      c.appendChild(l);
    }
  });
}

function chip(k, v, warn) {
  const s = document.createElement('span');
  s.className = 'chip' + (warn ? ' warn' : '');
  const kk = document.createElement('span'); kk.className = 'k'; kk.textContent = k;
  const vv = document.createElement('span'); vv.className = 'v';
  if (v instanceof Node) vv.appendChild(v); else vv.textContent = v;
  s.append(kk, vv);
  return s;
}

function renderChips() {
  const c = $('chips');
  c.textContent = '';
  if (data.nexus && data.nexus.display !== '-') {
    let v = data.nexus.display;
    if (data.nexus.url) {
      const a = document.createElement('a');
      a.href = data.nexus.url;
      a.textContent = data.nexus.display;
      v = a;
    }
    c.appendChild(chip('nexus', v));
  }
  c.appendChild(chip('items', String(data.children.length)));
  const open = data.root || !data.weir;
  const sb = chip('sandbox', open ? 'unrestricted' : 'restricted', open);
  // load-bearing weirs are not offered: restricting /apps (or explorer
  // itself) locks the tools that manage weirs — server refuses too
  const PROTECTED = ['/apps', '/apps/explorer.explorer'];
  if (!data.root && !PROTECTED.includes(dirPath)) {
    sb.classList.add('click');
    sb.title = 'manage this sandbox';
    sb.addEventListener('click', () => { renderWeir(); $('weir-modal').show(); });
  } else if (PROTECTED.includes(dirPath)) {
    sb.classList.add('locked');
    sb.querySelector('.v').append(' \ud83d\udd12');
    sb.title = 'load-bearing: restricting this directory would make grubbery painfully difficult to interface with from the outside — the server refuses it';
  }
  c.appendChild(sb);
}

function renderWeir() {
  $('w-path').textContent = dirPath;
  const roads = $('m-weir-roads');
  roads.textContent = '';
  $('m-weir-clear').style.display = data.weir ? '' : 'none';
  $('m-weir-make').style.display = data.weir ? 'none' : '';
  if (!data.weir) {
    const p = document.createElement('div');
    p.className = 'w-none';
    p.textContent = 'unrestricted — no weir. Restricting starts fully closed; open it road by road.';
    roads.appendChild(p);
    return;
  }
  for (const cat of ['write', 'poke', 'read']) {
    const row = document.createElement('div');
    row.className = 'w-cat';
    const k = document.createElement('span');
    k.className = 'w-k';
    k.textContent = cat;
    const rs = document.createElement('div');
    rs.className = 'w-roads';
    for (const rd of (data.weir[cat] || [])) {
      const s = document.createElement('span');
      s.className = 'weir-road';
      s.append(rd);
      const x = document.createElement('button');
      x.textContent = '\u00d7';
      x.title = 'remove road';
      x.addEventListener('click', () =>
        post({ action: 'del-weir-road', category: cat, 'road-path': rd }));
      s.appendChild(x);
      rs.appendChild(s);
    }
    // per-row +: swaps into an inline input; Enter adds, Esc backs out
    const plus = document.createElement('button');
    plus.className = 'w-plus';
    plus.textContent = '+';
    plus.title = 'add ' + cat + ' road';
    plus.addEventListener('click', () => {
      const inp = document.createElement('input');
      inp.className = 'w-inline';
      inp.placeholder = '/path or /path/';
      inp.spellcheck = false;
      rs.replaceChild(inp, plus);
      inp.focus();
      const done = () => { if (inp.parentNode) rs.replaceChild(plus, inp); };
      inp.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && inp.value.trim()) {
          post({ action: 'add-weir-road', category: cat, 'road-path': inp.value.trim() });
          done();
        }
        if (e.key === 'Escape') done();
      });
      inp.addEventListener('blur', done);
    });
    rs.appendChild(plus);
    row.append(k, rs);
    roads.appendChild(row);
  }
}

function renderBang() {
  const b = $('bang');
  if (!data.bang) { b.style.display = 'none'; return; }
  b.style.display = '';
  b.textContent = 'nexus crashed — click for details';
  b.onclick = () => showBoom(data.bang);
}

function fmtSize(n) {
  if (n == null) return '–';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return Math.round(n / 1024) + ' KB';
  return (n / (1024 * 1024)).toFixed(1) + ' MB';
}

function sorted() {
  const ks = { name: c => c.name, blot: c => c.blot || c.neck || '',
               mime: c => c.mime || '', size: c => c.size ?? -1,
               modified: c => c.modified || '' };
  const f = ks[sortKey] || ks.name;
  return [...data.children].sort((a, b) => {
    if (a.kind === 'dir' && b.kind !== 'dir') return -1;   // dirs first, always
    if (b.kind === 'dir' && a.kind !== 'dir') return 1;
    const x = f(a), y = f(b);
    return (x < y ? -1 : x > y ? 1 : 0) * sortDir;
  });
}

function td(cls, content) {
  const t = document.createElement('td');
  if (cls) t.className = cls;
  if (content instanceof Node) t.appendChild(content);
  else t.textContent = content;
  const full = t.textContent.trim();
  if (full && full !== '\u2013') t.title = full;
  return t;
}

function actBtn(label, fn, danger) {
  const b = document.createElement('button');
  b.className = 'mi' + (danger ? ' danger' : '');
  b.textContent = label;
  b.addEventListener('click', fn);
  return b;
}

// the actions cell: one quiet dots-trigger opening a kit drop-menu
function actsCell(buttons) {
  const cell = td('acts', '');
  cell.removeAttribute('title');
  const dm = document.createElement('drop-menu');
  dm.setAttribute('align', 'end');
  const trig = document.createElement('button');
  trig.slot = 'trigger';
  trig.className = 'dots';
  trig.textContent = '\u22ef';
  trig.title = 'actions';
  dm.append(trig, ...buttons);
  cell.appendChild(dm);
  return cell;
}

function renderRows() {
  const tb = $('rows');
  tb.textContent = '';
  if (dirPath !== '/') {
    const tr = document.createElement('tr');
    const up = document.createElement('a');
    up.className = 'name';
    up.href = PREFIX + (dirPath.split('/').slice(0, -1).join('/') || '');
    up.textContent = '../';
    up.dataset.nav = '1';
    tr.append(td('', up), td('mono', '–'), td('mono', '–'),
              td('mono', '–'), td('mono', '–'), td('acts', ''));
    tb.appendChild(tr);
  }
  for (const c of sorted()) tb.appendChild(row(c));
}

function row(c) {
  const tr = document.createElement('tr');
  const base = here.replace(/\/$/, '') + '/' + c.name;
  const nameCell = document.createElement('span');

  if (c.kind === 'dir') {
    const a = document.createElement('a');
    a.className = 'name';
    a.href = base;
    a.textContent = c.name + '/';
    a.dataset.nav = '1';
    nameCell.appendChild(a);
    tr.append(td('', nameCell), td('mono', c.neck || '–'),
              td('mono', '–'), td('mono', '–'), td('mono', c.modified || '–'));
    tr.appendChild(actsCell([
      actBtn('Download', () => { location.href = base + '?download=tar'; }),
      actBtn('Rename', () => ask('rename ' + c.name, c.name, nn =>
        post({ action: 'rename-folder', foldername: c.name, newname: nn }))),
      actBtn('Move', () => ask('move ' + c.name + ' to', dirPath + '/' + c.name, d =>
        post({ action: 'move-folder', foldername: c.name, dest: d }))),
      actBtn('Copy', () => ask('copy ' + c.name + ' to', dirPath + '/' + c.name + '-copy', d =>
        post({ action: 'copy-folder', foldername: c.name, dest: d }))),
      actBtn('Delete', () => confirm('Delete ' + c.name + '/?') &&
        post({ action: 'delete-folder', foldername: c.name }), true),
    ]));
    return tr;
  }

  if (c.kind === 'symlink') {
    const a = document.createElement('a');
    a.className = 'name';
    a.href = PREFIX + c.resolved;
    a.textContent = c.name;
    const t = document.createElement('span');
    t.className = 'sym';
    t.textContent = ' → ' + c.target;
    nameCell.append(a, t);
    tr.append(td('', nameCell), td('mono', 'symlink'), td('mono', '–'),
              td('mono', '–'), td('mono', c.modified || '–'));
    tr.appendChild(actsCell([
      actBtn('Delete', () => confirm('Delete ' + c.name + '?') &&
        post({ action: 'delete-grub', filename: c.name }), true),
    ]));
    return tr;
  }

  // file (or boom)
  const boom = c.kind === 'boom';
  const a = document.createElement('a');
  a.className = 'name';
  a.href = c.binary ? base + '?pretty' : base;
  a.textContent = c.name;
  nameCell.appendChild(a);
  const bangText = boom ? c.boom : c.bang;
  if (bangText) {
    const x = document.createElement('span');
    x.className = 'boomch';
    x.textContent = '!';
    x.title = 'crash details';
    x.addEventListener('click', (e) => { e.preventDefault(); showBoom(bangText); });
    nameCell.appendChild(x);
  }
  let blot = document.createTextNode(c.blot || '–');
  if (!boom && c['blot-url']) {
    blot = document.createElement('a');
    blot.href = c['blot-url'];
    blot.textContent = c.blot;
  }
  const blotTd = td('mono', blot);
  tr.append(td('', nameCell), blotTd,
            td('mono', boom ? '–' : (c.mime || '–')),
            td('mono', boom ? '–' : fmtSize(c.size)),
            td('mono', c.modified || '–'));
  const buttons = [];
  if (!boom) {
    buttons.push(
      actBtn('Download', () => {
        const l = document.createElement('a');
        l.href = base + '?raw=1';
        l.download = c.name;
        l.click();
      }),
      actBtn('Rename', () => ask('rename ' + c.name, c.name, nn =>
        post({ action: 'rename-grub', filename: c.name, newname: nn }))),
      actBtn('Move', () => ask('move ' + c.name + ' to', dirPath + '/' + c.name, d =>
        post({ action: 'move-grub', filename: c.name, dest: d }))),
      actBtn('Copy', () => ask('copy ' + c.name + ' to', dirPath + '/' + c.name, d =>
        post({ action: 'copy-grub', filename: c.name, dest: d }))));
  }
  buttons.push(actBtn('Delete', () => confirm('Delete ' + c.name + '?') &&
    post({ action: 'delete-grub', filename: c.name }), true));
  tr.appendChild(actsCell(buttons));
  return tr;
}

// ---- sorting ----
document.querySelectorAll('th[data-k]').forEach(th => {
  th.addEventListener('click', () => {
    const k = th.dataset.k;
    if (sortKey === k) sortDir = -sortDir;
    else { sortKey = k; sortDir = 1; }
    document.querySelectorAll('th').forEach(h => {
      h.classList.toggle('sorted', h.dataset.k === sortKey);
      const arr = h.querySelector('.arr');
      if (arr) arr.innerHTML = h.dataset.k === sortKey
        ? (sortDir === 1 ? '&#8593;' : '&#8595;') : '&#8597;';
    });
    renderRows();
  });
});

// ---- actions ----
async function post(params) {
  try {
    const r = await fetch(here, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      redirect: 'manual',
      body: new URLSearchParams(params),
    });
    if (r.status >= 400) { toast(await r.text() || 'failed (' + r.status + ')', true); return; }
    toast('done ✓');
    load();
  } catch (e) { toast('failed: ' + e, true); }
}

async function upload(files, withPaths) {
  if (!files.length) return;
  const fd = new FormData();
  for (const f of files)
    fd.append('file', f, (withPaths && f.webkitRelativePath) || f.name);
  toast('uploading…');
  try {
    const r = await fetch(here, { method: 'POST', redirect: 'manual', body: fd });
    if (r.status >= 400) { toast(await r.text() || 'upload failed', true); return; }
    toast('uploaded ✓');
    load();
  } catch (e) { toast('upload failed: ' + e, true); }
}

// ---- dialogs ----
function ask(title, initial, fn) {
  $('ask-title').textContent = title;
  const inp = $('ask-input');
  inp.value = initial;
  const go = $('ask-go');
  const done = () => { $('ask-modal').close(); fn(inp.value.trim()); };
  go.onclick = done;
  inp.onkeydown = (e) => { if (e.key === 'Enter') done(); };
  $('ask-modal').show();
  inp.focus();
  inp.select();
}

function showBoom(text) {
  $('boom-text').textContent = text;
  $('boom-modal').show();
}

function renderManage() {
  $('mi-reload').style.display = (data.nexus && data.nexus.display !== '-') ? '' : 'none';
}

// manage menu: each item opens its own small modal; download + reload act
function openModal(id, focus) {
  $(id).show();
  if (focus) { $(focus).focus(); }
}
$('mi-folder').addEventListener('click', () => openModal('folder-modal', 'm-folder'));
$('mi-symlink').addEventListener('click', () => openModal('symlink-modal', 'm-link'));
$('mi-upload').addEventListener('click', () => openModal('upload-modal'));
$('mi-upload-dir').addEventListener('click', () => openModal('upload-dir-modal'));
$('mi-download').addEventListener('click', () => { location.href = here + '?download=tar'; });
$('mi-reload').addEventListener('click', () => post({ action: 'reload-nexus' }));
$('m-weir-make').addEventListener('click', () => post({ action: 'make-weir' }));
$('m-weir-clear').addEventListener('click', () =>
  confirm('Remove weir? This gives unrestricted access.') &&
  post({ action: 'clear-weir' }));
$('m-folder-go').addEventListener('click', () => {
  const n = $('m-folder').value.trim();
  if (!n) return;
  post({ action: 'create-folder', foldername: n });
  $('m-folder').value = '';
  $('folder-modal').close();
});
$('m-folder').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-folder-go').click(); });
$('m-link-go').addEventListener('click', () => {
  const n = $('m-link').value.trim(), t = $('m-target').value.trim();
  if (!(n && t)) return;
  post({ action: 'create-symlink', linkname: n, target: t });
  $('symlink-modal').close();
});
// hidden file inputs, driven by styled buttons; the label shows the haul
function wirePicker(pick, input, label, what) {
  $(pick).addEventListener('click', () => $(input).click());
  $(input).addEventListener('change', () => {
    const n = $(input).files.length;
    $(label).textContent = n === 0 ? 'nothing chosen'
      : n === 1 ? $(input).files[0].name
      : n + ' ' + what;
  });
}
wirePicker('m-files-pick', 'm-files', 'm-files-n', 'files');
wirePicker('m-dir-pick', 'm-dir', 'm-dir-n', 'files in directory');
$('m-files-go').addEventListener('click', () => {
  upload([...$('m-files').files], false);
  $('upload-modal').close();
});
$('m-dir-go').addEventListener('click', () => {
  upload([...$('m-dir').files], true);
  $('upload-dir-modal').close();
});

// ---- toast ----
let toastTimer = null;
function toast(msg, err) {
  const s = $('status');
  s.textContent = msg;
  s.className = err ? 'err' : '';
  s.style.display = 'block';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { s.style.display = 'none'; }, err ? 6000 : 2000);
}

load();
