// s3 nexus UI: buckets, mounts, the activity log, and one explorer that
// opens over either a remote bucket (live listing from the provider) or a
// local mount (the namespace directory). Same surface, the tag says which.
//
// A mount is a path of a bucket, mirrored at mounts/<bucket>/<path>: a
// folder ('a/b/', '' = the whole bucket) or a single file ('a/b.txt').
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/s3';
const BALL = '/grubbery/ball/apps/s3';

async function jget(u) { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); }
async function jpost(u, b) { const r = await fetch(BASE + u, { method: 'POST', body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()); return r; }

const fmt = (n) => (n || 0).toLocaleString();
const fmtTime = (t) => t ? new Date(t * 1000).toLocaleString() : '–';
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const isDir = (p) => p === '' || p.endsWith('/');
const showPath = (p) => p === '' ? '(whole bucket)' : p;

// one op through the front door: create a call, poll it, cull it
async function call(body, timeoutSec = 120) {
  const { id } = await (await jpost('/api/call-new', body)).json();
  let c = null;
  for (let i = 0; i < timeoutSec; i++) {
    await new Promise((res) => setTimeout(res, 1000));
    try {
      const r = await jget(`/api/call?id=${encodeURIComponent(id)}`);
      if (r.status === 'done') { c = r; break; }
    } catch (e) { /* not yet */ }
  }
  jpost('/api/call-cull', { id }).catch(() => {});
  if (!c) throw new Error('timed out waiting for the call');
  const resp = c.response || {};
  if (resp.error) throw new Error(resp.error);
  return resp;
}

let BUCKETS = {};
let MOUNTS = [];   // [{bucket, path, files}]

function fillSelect(sel, names) {
  const cur = sel.value;
  sel.textContent = '';
  for (const n of names) {
    const o = document.createElement('option');
    o.value = n; o.textContent = n;
    sel.appendChild(o);
  }
  if (names.includes(cur)) sel.value = cur;
}

// the mounted paths of a bucket that contain a path
function mountsCovering(bucket, path) {
  return MOUNTS.filter((m) => m.bucket === bucket && (isDir(m.path) ? path.startsWith(m.path) : m.path === path));
}

async function refresh() {
  const s = await jget('/api/status');
  $('status').textContent = `${fmt(s.requests)} requests · ${s.pending} in flight · ${s.buckets} buckets · ${s.mounts} mounts`;

  BUCKETS = await jget('/api/buckets');
  const bnames = Object.keys(BUCKETS).sort();
  const bt = $('bucket-rows');
  bt.textContent = '';
  if (!bnames.length) bt.innerHTML = '<tr class="empty"><td colspan="5">no buckets yet</td></tr>';
  for (const n of bnames) {
    const b = BUCKETS[n], tr = document.createElement('tr');
    tr.innerHTML = `<td class="mono">${esc(n)}</td><td class="mono">${esc(b.bucket)}</td><td class="mono">${esc(b.endpoint)}</td><td class="mono">${esc(b.region)}</td>` +
      `<td class="r"><div class="row">` +
      `<button class="small" data-op="explore" data-bucket="${esc(n)}" title="live listing of the remote bucket">Explore</button>` +
      `<button class="small" data-op="edit" data-bucket="${esc(n)}">Edit</button>` +
      `<button class="small danger" data-op="remove" data-bucket="${esc(n)}">Remove</button>` +
      `</div></td>`;
    bt.appendChild(tr);
  }
  const hadBucket = !!$('mount-bucket').value;
  fillSelect($('mount-bucket'), bnames);
  if (!hadBucket && $('mount-bucket').value) loadPrefixes();

  MOUNTS = await jget('/api/mounts');
  const mt = $('mount-rows');
  mt.textContent = '';
  if (!MOUNTS.length) mt.innerHTML = '<tr class="empty"><td colspan="4">no mounts yet</td></tr>';
  for (const m of MOUNTS) {
    const tr = document.createElement('tr');
    const a = (op, label, title) => `<button class="small${op === 'remove' ? ' danger' : ''}" data-op="${op}" data-bucket="${esc(m.bucket)}" data-path="${esc(m.path)}" title="${title}">${label}</button>`;
    tr.innerHTML = `<td class="mono">${esc(m.bucket)}</td><td class="mono">${esc(showPath(m.path))}</td><td class="r">${fmt(m.files)}</td>` +
      `<td class="r"><div class="row">` +
      a('open', 'Open', 'browse the local copy') +
      a('pull', 'Pull', 'download from the bucket into the local copy') +
      a('push', 'Push', 'upload the local copy to the bucket') +
      a('remove', 'Remove', 'forget the mount (local files stay)') +
      `</div></td>`;
    mt.appendChild(tr);
  }

  const g = await jget('/api/activity');
  const at = $('act-rows');
  at.textContent = '';
  const log = g.log || [];
  if (!log.length) at.innerHTML = '<tr class="empty"><td colspan="5">nothing yet</td></tr>';
  for (const e of log) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${fmtTime(e.time)}</td><td class="caller mono" title="${esc(e.from)}">${esc(e.from || '–')}</td>` +
      `<td class="mono">${esc(e.op)}</td><td class="target mono" title="${esc(e.target)}">${esc(e.target || '–')}</td>` +
      `<td class="r ${e.ok ? 'ok' : 'bad'}" title="${esc(e.error)}">${e.ok ? 'ok' : esc(e.error || 'failed')}</td>`;
    at.appendChild(tr);
  }
}

// ---- buckets -------------------------------------------------------------
let secretShown = false;
function setSecretShown(on) {
  secretShown = on;
  $('cfg-secret').type = on ? 'text' : 'password';
  $('eye-open').toggleAttribute('hidden', on);
  $('eye-shut').toggleAttribute('hidden', !on);
  $('secret-toggle').title = on ? 'hide secret' : 'show secret';
}
$('secret-toggle').addEventListener('click', () => setSecretShown(!secretShown));

function openBucketModal(name) {
  const b = name ? (BUCKETS[name] || {}) : {};
  $('bucket-modal-title').textContent = name ? `Bucket: ${name}` : 'New bucket';
  $('cfg-name').value = name || '';
  $('cfg-name').disabled = !!name;
  $('cfg-endpoint').value = b.endpoint || '';
  $('cfg-region').value = b.region || '';
  $('cfg-bucket').value = b.bucket || '';
  $('cfg-access').value = b['access-key'] || '';
  $('cfg-secret').value = b['secret-key'] || '';
  setSecretShown(false);
  $('bucket-modal').show();
  (name ? $('cfg-endpoint') : $('cfg-name')).focus();
}
$('bucket-new').addEventListener('click', () => openBucketModal(null));
$('cfg-save').addEventListener('click', async () => {
  const body = {
    name: $('cfg-name').value.trim(),
    endpoint: $('cfg-endpoint').value.trim(),
    region: $('cfg-region').value.trim(),
    bucket: $('cfg-bucket').value.trim(),
    'access-key': $('cfg-access').value.trim(),
    'secret-key': $('cfg-secret').value.trim(),
  };
  if (!body.name) return;
  try { await jpost('/api/bucket-set', body); } catch (err) { $('status').textContent = err.message; }
  $('bucket-modal').close();
  refresh().catch(() => {});
});
$('bucket-rows').addEventListener('click', async (e) => {
  const b = e.target.closest('button[data-op]');
  if (!b) return;
  const name = b.dataset.bucket;
  if (b.dataset.op === 'explore') return openExplorer(remoteSource(name), '');
  if (b.dataset.op === 'edit') return openBucketModal(name);
  if (!confirm(`Forget bucket ${name}? Its mounts stop working until you add it back.`)) return;
  try { await jpost('/api/bucket-remove', { name }); } catch (err) { $('status').textContent = err.message; }
  refresh().catch(() => {});
});

// the bucket's top-level folders, as suggestions for the path field
async function loadPrefixes() {
  const bucket = $('mount-bucket').value;
  const dl = $('prefix-list');
  dl.textContent = '';
  if (!bucket) return;
  try {
    const r = await call({ op: 'list', bucket, prefix: '' });
    const tops = new Set();
    for (const k of r.keys) { const i = k.indexOf('/'); if (i > 0) tops.add(k.slice(0, i + 1)); }
    for (const p of [...tops].sort()) { const o = document.createElement('option'); o.value = p; dl.appendChild(o); }
  } catch (e) { /* no suggestions */ }
}
$('mount-bucket').addEventListener('change', loadPrefixes);

// ---- mounts --------------------------------------------------------------
async function addMount(bucket, path) {
  await jpost('/api/mount-add', { bucket, path });
  await refresh().catch(() => {});
}
async function pull(bucket, path, status) {
  status(`pulling ${showPath(path)}…`);
  const r = await call({ op: 'pull', bucket, path }, 600);
  status(`pulled ${r.pulled} into mounts/${bucket}/${path}` + (r.failed?.length ? `, ${r.failed.length} failed` : ''));
}
async function push(bucket, path, status) {
  status(`pushing ${showPath(path)}…`);
  const r = await call({ op: 'push', bucket, path }, 600);
  status(`pushed ${r.pushed} to ${bucket}:${showPath(path)}` + (r.failed?.length ? `, ${r.failed.length} failed` : ''));
}
// mount a path and pull it straight away
async function mountAndPull(bucket, path, status) {
  await addMount(bucket, path);
  await pull(bucket, path, status);
}

const dashStatus = (t) => { $('status').textContent = t; };
$('mount-rows').addEventListener('click', async (e) => {
  const b = e.target.closest('button[data-op]');
  if (!b) return;
  const { bucket, path, op } = b.dataset;
  if (op === 'open') {
    if (isDir(path)) return openExplorer(localSource(bucket), path);
    return openExplorer(localSource(bucket), path.slice(0, path.lastIndexOf('/') + 1), { name: path.split('/').pop(), kind: 'file', path });
  }
  b.disabled = true;
  try {
    if (op === 'remove') await jpost('/api/mount-remove', { bucket, path });
    else if (op === 'pull') await pull(bucket, path, dashStatus);
    else if (op === 'push') await push(bucket, path, dashStatus);
  } catch (err) { dashStatus(err.message); }
  b.disabled = false;
  refresh().catch(() => {});
});
$('mount-add').addEventListener('click', async () => {
  const path = $('mount-path').value.trim();
  const bucket = $('mount-bucket').value;
  if (!bucket) return;
  try {
    await mountAndPull(bucket, path, dashStatus);
    $('mount-path').value = '';
  } catch (err) { dashStatus(err.message); }
});

// ---- the explorer --------------------------------------------------------
// A source is where the listing comes from. Both yield the same items:
// { name, kind: 'dir'|'file', path } with path being the bucket path
// (a dir path ends in '/'). The viewer needs a raw url per file.

function remoteSource(bucket) {
  const b = BUCKETS[bucket] || {};
  return {
    kind: 'remote', tag: 'REMOTE BUCKET', title: bucket,
    sub: `${b.bucket} @ ${b.endpoint} · live from the provider`,
    rootLabel: b.bucket || bucket,
    foot: 'Mount mirrors a path into the namespace and pulls it; refresh it later with Pull on the dashboard. Delete removes from the bucket.',
    async list(prefix) {
      const r = await call({ op: 'list', bucket, prefix });
      const dirs = new Set(), files = [];
      for (const k of r.keys) {
        const rest = k.slice(prefix.length);
        if (!rest) continue;
        const i = rest.indexOf('/');
        if (i < 0) files.push({ name: rest, kind: 'file', path: k });
        else dirs.add(rest.slice(0, i));
      }
      return [...dirs].sort().map((d) => ({ name: d + '/', kind: 'dir', path: prefix + d + '/' })).concat(files);
    },
    raw: (it) => `${BASE}/api/object?bucket=${encodeURIComponent(bucket)}&key=${encodeURIComponent(it.path)}`,
    actions(it) {
      const acts = [];
      if (!mountsCovering(bucket, it.path).length) acts.push({ label: 'Mount', action: 'mount' });
      if (it.kind === 'file') acts.push({ label: 'Delete', action: 'delete', danger: true });
      return acts;
    },
    async act(action, it, status) {
      if (action === 'mount') return mountAndPull(bucket, it.path, status);
      if (action === 'delete') {
        if (!confirm(`Delete ${it.path} from the bucket? This is the remote copy.`)) return;
        await call({ op: 'delete', bucket, key: it.path });
        status(`deleted ${it.path}`);
        return 'reload';
      }
    },
    canMountHere: true,
    mountHere: (prefix, status) => mountAndPull(bucket, prefix, status),
  };
}

function localSource(bucket) {
  const root = `${BALL}/mounts/${bucket}`;
  return {
    kind: 'local', tag: 'LOCAL MOUNT', title: bucket,
    sub: `/apps/s3/mounts/${bucket}/ · the local copies of ${bucket}'s mounted paths`,
    rootLabel: bucket,
    foot: 'The local copy in the namespace. Push uploads to the bucket; Delete only removes the local copy.',
    async list(prefix) {
      const r = await fetch(`${root}/${prefix}?list=1`.replace(/\/\?/, '?'));
      if (r.status === 404) return [];
      if (!r.ok) throw new Error(`listing failed (${r.status})`);
      const data = await r.json();
      return (data.children || []).map((c) => ({
        name: c.kind === 'dir' ? c.name + '/' : c.name,
        kind: c.kind === 'dir' ? 'dir' : 'file',
        path: prefix + c.name + (c.kind === 'dir' ? '/' : ''),
      }));
    },
    raw: (it) => `${root}/${it.path}?raw=1`,
    actions: (it) => it.kind === 'dir'
      ? [{ label: 'Push', action: 'push' }]
      : [{ label: 'Push', action: 'push' }, { label: 'Delete', action: 'delete', danger: true }],
    async act(action, it, status) {
      if (action === 'push') return push(bucket, it.path, status);
      if (action === 'delete') {
        if (!confirm(`Delete the local copy ${it.name}? The bucket is untouched.`)) return;
        // the ball's own directory api, as the explorer uses it: POST to the dir
        const dir = `${root}/${it.path.slice(0, it.path.lastIndexOf('/') + 1)}`.replace(/\/$/, '');
        const r = await fetch(dir, {
          method: 'POST', redirect: 'manual',
          headers: { 'content-type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ action: 'delete-grub', filename: it.name }),
        });
        if (!r.ok && r.type !== 'opaqueredirect') throw new Error(await r.text());
        status(`deleted ${it.name}`);
        return 'reload';
      }
    },
    canMountHere: false,
  };
}

const EX = { src: null, prefix: '', file: null };
const exTable = $('ex-table');

function setupExTable() {
  exTable.columns = [
    { key: 'name', label: 'Name', link: () => '#', cls: 'mono' },
    { key: 'kind', label: 'Kind', format: (v) => v === 'dir' ? 'folder' : 'file' },
  ];
  exTable.actions = (it) => EX.src.actions(it);
}

function exCrumbs() {
  const el = $('ex-crumbs');
  el.textContent = '';
  const mk = (label, prefix) => {
    const a = document.createElement('a');
    a.href = '#'; a.textContent = label;
    a.addEventListener('click', (e) => { e.preventDefault(); openExplorer(EX.src, prefix); });
    return a;
  };
  el.appendChild(mk(EX.src.rootLabel, ''));
  let acc = '';
  for (const p of (EX.prefix ? EX.prefix.replace(/\/$/, '').split('/') : [])) {
    acc += p + '/';
    el.appendChild(document.createTextNode(' / '));
    el.appendChild(mk(p, acc));
  }
  if (EX.file) {
    el.appendChild(document.createTextNode(' / '));
    const s = document.createElement('span'); s.className = 'here'; s.textContent = EX.file.name;
    el.appendChild(s);
  }
}

const exStatus = (t) => { $('ex-status').textContent = t; };

async function openExplorer(src, prefix, file) {
  const fresh = EX.src !== src;
  EX.src = src; EX.prefix = prefix; EX.file = null;
  const modal = $('explorer');
  modal.classList.toggle('remote', src.kind === 'remote');
  modal.classList.toggle('local', src.kind === 'local');
  $('ex-kind').textContent = src.tag;
  $('ex-title').textContent = src.title;
  $('ex-sub').textContent = src.sub;
  $('ex-foot-text').textContent = src.foot;
  if (fresh) exStatus('');
  showListing();
  exCrumbs();
  if (!modal.hasAttribute('open')) modal.show();
  if (file) return viewFile(file);
  await loadListing();
}

function showListing() {
  $('ex-view').hidden = true;
  $('ex-view').textContent = '';
  exTable.style.display = '';
  const src = EX.src;
  const covered = src.kind === 'remote' && mountsCovering(src.title, EX.prefix).length > 0;
  $('ex-mount').hidden = !src.canMountHere || covered;
}

async function loadListing() {
  exTable.items = [];
  $('ex-empty').hidden = false;
  $('ex-empty').textContent = 'listing…';
  try {
    const items = await EX.src.list(EX.prefix);
    exTable.items = items;
    $('ex-empty').hidden = items.length > 0;
    $('ex-empty').textContent = 'empty';
  } catch (err) {
    $('ex-empty').hidden = false;
    $('ex-empty').textContent = err.message;
  }
}

// a file: the pane becomes the viewer, the crumbs grow by one
async function viewFile(it) {
  EX.file = it;
  exCrumbs();
  const raw = EX.src.raw(it);
  exTable.style.display = 'none';
  $('ex-empty').hidden = true;
  $('ex-mount').hidden = true;
  const body = $('ex-view');
  body.hidden = false;
  body.textContent = '';
  const spin = document.createElement('div');
  spin.className = 'ex-loading';
  spin.innerHTML = '<span class="spinner"></span> loading ' + esc(it.name) + '…';
  body.appendChild(spin);
  const done = () => spin.remove();
  const kind = window.FilePreview && FilePreview.kind(it.name);
  try {
    if (kind === 'pdf' || kind === 'image') {
      const host = document.createElement('div');
      host.className = 'ex-embed';
      body.appendChild(host);
      FilePreview.render(host, { name: it.name, text: null, rawUrl: raw });
      const el = host.querySelector('img, iframe, object, embed');
      if (el) { el.addEventListener('load', done, { once: true }); el.addEventListener('error', done, { once: true }); }
      else done();
      return;
    }
    const r = await fetch(raw);
    if (!r.ok) throw new Error(await r.text());
    const text = await r.text();
    if (EX.file !== it) return;   // navigated away while fetching
    body.textContent = '';
    if (kind) FilePreview.render(body, { name: it.name, text, rawUrl: raw });
    else { const pre = document.createElement('pre'); pre.className = 'ov-text'; pre.textContent = text; body.appendChild(pre); }
  } catch (err) { body.textContent = err.message; }
}

exTable.addEventListener('ft-navigate', (e) => {
  e.preventDefault();
  const it = e.detail.item;
  if (it.kind === 'dir') openExplorer(EX.src, it.path);
  else viewFile(it);
});
exTable.addEventListener('ft-action', async (e) => {
  const { action, item } = e.detail;
  try {
    const r = await EX.src.act(action, item, exStatus);
    if (r === 'reload') loadListing();
    else if (EX.src.kind === 'remote') { await refresh(); loadListing(); }
  } catch (err) { exStatus(err.message); }
  refresh().catch(() => {});
});
$('ex-reload').addEventListener('click', () => EX.file ? viewFile(EX.file) : loadListing());
$('ex-mount').addEventListener('click', async () => {
  try { await EX.src.mountHere(EX.prefix, exStatus); await refresh(); showListing(); }
  catch (err) { exStatus(err.message); }
});

$('sweep').addEventListener('click', async () => {
  try {
    const r = await (await jpost('/api/sweep', {})).json();
    $('status').textContent = `swept ${r.swept} call grubs`;
  } catch (err) { $('status').textContent = err.message; }
});

$('info').addEventListener('click', () => $('info-modal').show());

customElements.whenDefined('file-table').then(setupExTable);
refresh().catch((e) => { $('status').textContent = e.message; });
setInterval(() => refresh().catch(() => {}), 10000);
