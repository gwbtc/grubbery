// github nexus UI: config, a generic call runner, and activity over
// the calls/ and xfer/ lifecycle grubs.
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/github';

async function jget(u) { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); }
async function jpost(u, b) { const r = await fetch(BASE + u, { method: 'POST', body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()); return r; }

async function refresh() {
  const s = await jget('/api/status');
  refreshAuth().then(a => renderConn(a, s.accounts)).catch(() => {});
  renderAccounts(s.accounts);
  $('status').textContent = `${s.calls} calls, ${s.xfers} xfers`;
  $('cid-view').textContent = s.clientId + (s.clientIdIsDefault ? '' : ' (custom)');
  cidIsDefault = s.clientIdIsDefault;
  if (s.clientIdIsDefault) cidDefault = s.clientId;
  const a = await jget('/api/activity');
  const el = $('activity');
  el.textContent = '';
  const rows = [
    ...a.calls.map(c => ({ kind: 'call', ...c })),
    ...a.xfers.map(x => ({ kind: 'xfer', ...x })),
  ];
  if (!rows.length) {
    el.innerHTML = '<p class="muted">nothing in flight, nothing finished</p>';
    return;
  }
  for (const r of rows) {
    const div = document.createElement('div');
    div.className = 'act-row';
    const kind = document.createElement('span');
    kind.className = 'chip';
    kind.textContent = r.kind;
    const desc = document.createElement('span');
    desc.className = 'mono';
    desc.textContent = r.kind === 'call' ? `${r.method} ${r.path}` : r.id;
    const st = document.createElement('span');
    st.className = 'status ' + (r.status === 'done' ? 'ok' : r.status === 'fail' ? 'err' : 'pend');
    st.textContent = r.status + (r.code ? ` ${r.code}` : '');
    div.append(kind, desc, st);
    if (r.kind === 'call') {
      div.style.cursor = 'pointer';
      div.title = 'show result';
      div.addEventListener('click', async () => {
        const full = await jget(`/api/call?id=${encodeURIComponent(r.id)}`);
        $('result').hidden = false;
        $('result').textContent = JSON.stringify(full, null, 2);
      });
    }
    el.appendChild(div);
  }
}

async function runCall(method, path, body, account) {
  const r = await (await jpost('/api/call-new', {
    method, path,
    ...(account ? { account } : {}),
    ...(body ? { body } : {}),
  })).json();
  // poll the call grub until done
  for (let i = 0; i < 40; i++) {
    await new Promise(res => setTimeout(res, 700));
    try {
      const c = await jget(`/api/call?id=${encodeURIComponent(r.id)}`);
      if (c.status === 'done') return c;
    } catch (e) { /* not yet */ }
  }
  throw new Error('timed out waiting for call');
}

$('run').addEventListener('click', async () => {
  const method = $('method').value;
  const path = $('path').value.trim();
  if (!path) return;
  let body = null;
  const raw = $('body').value.trim();
  if (raw) { try { body = JSON.parse(raw); } catch (e) { alert('body is not valid json'); return; } }
  $('result').hidden = false;
  $('result').textContent = 'running…';
  try {
    const c = await runCall(method, path, body, $('call-account').value);
    $('result').textContent = JSON.stringify(c, null, 2);
  } catch (e) { $('result').textContent = e.message; }
  refresh();
});

// OAuth device flow — the primary way of connecting. The connection
// row always reflects auth.json + tokenSet; the modal hosts a flow in
// progress and polls fast until GitHub confirms.
let authFast = null;
function renderConn(a, accounts) {
  const n = (accounts || []).length;
  $('conn-dot').className = 'dot ' + (n ? 'on' : a.status === 'fail' ? 'bad' : '');
  $('conn-label').textContent =
    n === 1 ? 'connected as ' + accounts[0]
    : n > 1 ? `${n} accounts connected`
    : a.status === 'fail' ? `connection failed: ${a.error}`
    : 'not connected';
}

// one row per connected account: login, token reveal/copy, disconnect
const ICON = {
  eye: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>',
  eyeOff: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><path d="M14.12 14.12A3 3 0 1 1 9.88 9.88"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
  copy: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>',
  check: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#16a34a" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
  x: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
};
const DOTS = '••••••••••••••••••••';
const revealed = new Set();
let knownAccounts = '';
function renderAccounts(accounts) {
  accounts = accounts || [];
  const key = accounts.join(',');
  if (key === knownAccounts) return;   // don't rebuild rows under the user
  knownAccounts = key;
  // the call runner's account picker: only visible with a real choice
  const sel = $('call-account');
  sel.hidden = accounts.length < 2;
  sel.textContent = '';
  for (const login of accounts) {
    const o = document.createElement('option');
    o.value = login; o.textContent = login;
    sel.appendChild(o);
  }
  const el = $('accounts');
  el.textContent = '';
  for (const login of accounts) {
    const row = document.createElement('div');
    row.className = 'conn-row acct-row';
    const eye = document.createElement('button');
    eye.className = 'icon'; eye.title = 'show token'; eye.innerHTML = ICON.eye;
    const copy = document.createElement('button');
    copy.className = 'icon'; copy.title = 'copy token'; copy.innerHTML = ICON.copy;
    const name = document.createElement('span');
    name.className = 'acct-login'; name.textContent = login || '(legacy token)';
    const tok = document.createElement('code');
    tok.className = 'mono acct-token'; tok.textContent = DOTS;
    const x = document.createElement('button');
    x.className = 'icon acct-x'; x.title = 'disconnect'; x.innerHTML = ICON.x;
    eye.addEventListener('click', async () => {
      if (revealed.has(login)) {
        revealed.delete(login);
        tok.textContent = DOTS;
        eye.innerHTML = ICON.eye; eye.title = 'show token';
      } else {
        const t = await jget(`/api/token?account=${encodeURIComponent(login)}`);
        revealed.add(login);
        tok.textContent = t.token || '(empty)';
        eye.innerHTML = ICON.eyeOff; eye.title = 'hide token';
      }
    });
    copy.addEventListener('click', async () => {
      const t = await jget(`/api/token?account=${encodeURIComponent(login)}`);
      await navigator.clipboard.writeText(t.token);
      copy.innerHTML = ICON.check;
      setTimeout(() => { copy.innerHTML = ICON.copy; }, 1500);
    });
    x.addEventListener('click', async () => {
      await jpost('/api/disconnect', { login });
      knownAccounts = null;
      refresh();
    });
    row.append(name, eye, copy, tok, x);
    el.appendChild(row);
  }
}
function renderModal(a) {
  if ($('modal').hidden) return;
  if (a.status === 'code') {
    $('auth-user-code').textContent = a.user_code;
    $('auth-user-code').hidden = false;
    $('auth-link').href = a.verification_uri;
    $('auth-link').hidden = false;
    $('auth-state').textContent = 'waiting for approval…';
  } else if (a.status === 'done') {
    $('auth-state').textContent = `connected ✓${a.login ? ' as ' + a.login : ''}`;
    setTimeout(closeModal, 1200);
  } else if (a.status === 'fail') {
    $('auth-state').textContent = `failed: ${a.error}`;
  }
}
function closeModal() {
  $('modal').hidden = true;
  if (authFast) { clearInterval(authFast); authFast = null; }
  refresh();
}
async function refreshAuth() {
  const a = await jget('/api/auth');
  renderModal(a);
  if (authFast && (a.status === 'done' || a.status === 'fail')) {
    clearInterval(authFast); authFast = null;
  }
  return a;
}
$('connect').addEventListener('click', async () => {
  $('modal').hidden = false;
  $('auth-user-code').hidden = true;
  $('auth-link').hidden = true;
  $('auth-state').textContent = 'requesting a code…';
  await jpost('/api/auth-start', {});
  if (!authFast) authFast = setInterval(() => refreshAuth().catch(() => {}), 1500);
});
$('modal-close').addEventListener('click', closeModal);
$('modal').addEventListener('click', (e) => { if (e.target === $('modal')) closeModal(); });
$('auth-user-code').addEventListener('click', async () => {
  await navigator.clipboard.writeText($('auth-user-code').textContent);
  $('auth-copied').textContent = 'copied to clipboard';
  setTimeout(() => { $('auth-copied').innerHTML = '&nbsp;'; }, 1500);
});

// client_id: display-only row; the pencil opens a modal. Empty save
// restores the Grubbery default.
let cidIsDefault = true;
let cidDefault = '';
$('cid-edit').addEventListener('click', () => {
  $('client-id').value = cidIsDefault ? '' : $('cid-view').textContent;
  $('client-id').placeholder = cidDefault;
  $('cid-modal').hidden = false;
  $('client-id').focus();
});
$('cid-modal').addEventListener('click', (e) => { if (e.target === $('cid-modal')) $('cid-modal').hidden = true; });
$('cid-save').addEventListener('click', async () => {
  await jpost('/api/config', { client_id: $('client-id').value.trim() });
  $('cid-modal').hidden = true;
  refresh();
});


$('sweep').addEventListener('click', async () => {
  const r = await (await jpost('/api/sweep', {})).json();
  $('status').textContent = `swept ${r.swept}`;
  refresh();
});

refresh();
setInterval(refresh, 5000);

// info modal
$('info').addEventListener('click', () => { $('info-modal').hidden = false; });
$('info-modal').addEventListener('click', (e) => { if (e.target === $('info-modal')) $('info-modal').hidden = true; });
