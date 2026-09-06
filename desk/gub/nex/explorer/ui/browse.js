// explorer browse app. Renders a directory listing via <file-table> and
// drives every action through POST endpoints — success re-fetches the
// listing in place (no page reloads), failure shows the server's text
// in the status toast. Dialogs are kit <modal-dialog>s. Navigation is
// client-side for dirs, normal for files.
const $ = (id) => document.getElementById(id);
const PREFIX = '/grubbery/ball';
let here = location.pathname;
let dirPath = here.slice(PREFIX.length) || '/';

function nav(p, push) {
  here = p;
  dirPath = p.slice(PREFIX.length) || '/';
  if (push !== false) history.pushState(null, '', p);
  document.title = dirPath;
  renderCrumbs();
  ft.showLoading();
  load();
}
document.addEventListener('click', (e) => {
  const a = e.target.closest('a[data-nav]');
  if (!a || e.metaKey || e.ctrlKey || e.shiftKey) return;
  e.preventDefault();
  nav(new URL(a.href).pathname);
});
window.addEventListener('popstate', () => nav(location.pathname, false));

let data = null;
const ft = $('ft');

function fmtSize(n) {
  if (n == null) return '–';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return Math.round(n / 1024) + ' KB';
  return (n / (1024 * 1024)).toFixed(1) + ' MB';
}

// ---- file-table setup ----
ft.columns = [
  {
    key: 'name', label: 'Name', width: '30%',
    format: (v, item) => {
      if (item.kind === 'dir') return v + '/';
      return v;
    },
    link: (item) => {
      if (item.kind === 'dir') return here.replace(/\/$/, '') + '/' + item.name;
      if (item.kind === 'symlink') return PREFIX + item.resolved;
      if (item.binary) return here.replace(/\/$/, '') + '/' + item.name + '?pretty';
      return here.replace(/\/$/, '') + '/' + item.name;
    },
    decorate: (cell, item) => {
      const bangText = item.kind === 'boom' ? item.boom : item.bang;
      if (bangText) {
        const x = document.createElement('span');
        x.style.cssText = 'color:#cf222e;font-weight:700;cursor:pointer;margin-left:5px;';
        x.textContent = '!';
        x.title = 'crash details';
        x.addEventListener('click', (e) => { e.stopPropagation(); showBoom(bangText); });
        cell.appendChild(x);
      }
    },
  },
  {
    key: 'blot', label: 'Blot / Neck', cls: 'mono',
    format: (v, item) => {
      if (item.kind === 'dir') return item.neck || '–';
      if (item.kind === 'symlink') return 'symlink';
      if (item.kind === 'boom') return '–';
      return v || '–';
    },
    link: (item) => {
      if (item.kind !== 'boom' && item['blot-url']) return item['blot-url'];
      return null;
    },
  },
  {
    key: 'mime', label: 'Mime Type', cls: 'mono',
    format: (v, item) => {
      if (item.kind === 'dir' || item.kind === 'symlink' || item.kind === 'boom') return '–';
      return v || '–';
    },
  },
  {
    key: 'size', label: 'Size', cls: 'mono',
    format: (v, item) => {
      if (item.kind === 'dir' || item.kind === 'symlink' || item.kind === 'boom') return '–';
      return fmtSize(v);
    },
  },
  { key: 'modified', label: 'Modified', cls: 'mono' },
];

ft.actions = (item) => {
  if (item.kind === 'dir') {
    return [
      { label: 'Download', action: 'download' },
      { label: 'Rename', action: 'rename' },
      { label: 'Move', action: 'move' },
      { label: 'Copy', action: 'copy' },
      { label: 'Delete', action: 'delete', danger: true },
    ];
  }
  if (item.kind === 'symlink') {
    return [{ label: 'Delete', action: 'delete', danger: true }];
  }
  const acts = [];
  if (item.kind !== 'boom') {
    acts.push(
      { label: 'Download', action: 'download' },
      { label: 'Rename', action: 'rename' },
      { label: 'Move', action: 'move' },
      { label: 'Copy', action: 'copy' },
    );
  }
  acts.push({ label: 'Delete', action: 'delete', danger: true });
  return acts;
};

ft.addEventListener('ft-navigate', (e) => {
  const { item, href } = e.detail;
  if (!item) { nav(href); return; }
  if (item.kind === 'dir') { nav(href); return; }
  location.href = href;
});

ft.addEventListener('ft-action', (e) => {
  const { action, item } = e.detail;
  const base = here.replace(/\/$/, '') + '/' + item.name;
  if (item.kind === 'dir') {
    switch (action) {
      case 'download': location.href = base + '?download=tar'; break;
      case 'rename': ask('rename ' + item.name, item.name, nn =>
        post({ action: 'rename-folder', foldername: item.name, newname: nn })); break;
      case 'move': ask('move ' + item.name + ' to', dirPath + '/' + item.name, d =>
        post({ action: 'move-folder', foldername: item.name, dest: d })); break;
      case 'copy': ask('copy ' + item.name + ' to', dirPath + '/' + item.name + '-copy', d =>
        post({ action: 'copy-folder', foldername: item.name, dest: d })); break;
      case 'delete': if (confirm('Delete ' + item.name + '/?'))
        post({ action: 'delete-folder', foldername: item.name }); break;
    }
    return;
  }
  if (item.kind === 'symlink') {
    if (action === 'delete' && confirm('Delete ' + item.name + '?'))
      post({ action: 'delete-grub', filename: item.name });
    return;
  }
  switch (action) {
    case 'download': {
      const l = document.createElement('a');
      l.href = base + '?raw=1'; l.download = item.name; l.click();
    } break;
    case 'rename': ask('rename ' + item.name, item.name, nn =>
      post({ action: 'rename-grub', filename: item.name, newname: nn })); break;
    case 'move': ask('move ' + item.name + ' to', dirPath + '/' + item.name, d =>
      post({ action: 'move-grub', filename: item.name, dest: d })); break;
    case 'copy': ask('copy ' + item.name + ' to', dirPath + '/' + item.name, d =>
      post({ action: 'copy-grub', filename: item.name, dest: d })); break;
    case 'delete': if (confirm('Delete ' + item.name + '?'))
      post({ action: 'delete-grub', filename: item.name }); break;
  }
});

// ---- fetch + render ----
renderCrumbs();
document.title = dirPath;

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
  ft.parentHref = dirPath !== '/' ? PREFIX + (dirPath.split('/').slice(0, -1).join('/') || '') : null;
  ft.items = data.children;
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
  const PROTECTED = ['/apps', '/apps/explorer.explorer'];
  if (!data.root && !PROTECTED.includes(dirPath)) {
    sb.classList.add('click');
    sb.title = 'manage this sandbox';
    sb.addEventListener('click', () => { renderWeir(); $('weir-modal').show(); });
  } else if (PROTECTED.includes(dirPath)) {
    sb.classList.add('locked');
    sb.querySelector('.v').append(' 🔒');
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
      x.textContent = '×';
      x.title = 'remove road';
      x.addEventListener('click', () =>
        post({ action: 'del-weir-road', category: cat, 'road-path': rd }));
      s.appendChild(x);
      rs.appendChild(s);
    }
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

function openModal(id, focus) {
  $(id).show();
  if (focus) { $(focus).focus(); }
}
$('mi-folder').addEventListener('click', () => openModal('folder-modal', 'm-folder'));
$('mi-nexus').addEventListener('click', () => openModal('nexus-modal', 'm-nexus-name'));
$('mi-file').addEventListener('click', () => openModal('file-modal', 'm-file-name'));
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
$('m-nexus-go').addEventListener('click', () => {
  const n = $('m-nexus-name').value.trim();
  const neck = $('m-nexus-neck').value.trim();
  if (!n) return;
  post({ action: 'create-nexus', foldername: n, ...(neck ? { neck } : {}) });
  $('m-nexus-name').value = '';
  $('m-nexus-neck').value = '';
  $('nexus-modal').close();
});
$('m-nexus-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-nexus-go').click(); });
$('m-nexus-neck').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-nexus-go').click(); });
$('m-file-go').addEventListener('click', () => {
  const n = $('m-file-name').value.trim();
  if (!n) return;
  post({ action: 'create-file', filename: n });
  $('m-file-name').value = '';
  $('file-modal').close();
});
$('m-file-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-file-go').click(); });
$('m-link-go').addEventListener('click', () => {
  const n = $('m-link').value.trim(), t = $('m-target').value.trim();
  if (!(n && t)) return;
  post({ action: 'create-symlink', linkname: n, target: t });
  $('symlink-modal').close();
});
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
