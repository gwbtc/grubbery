// github nexus UI: config, a generic call runner, and activity over
// the calls/ and xfer/ lifecycle grubs.
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/github';

async function jget(u) { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); }
async function jpost(u, b) { const r = await fetch(BASE + u, { method: 'POST', body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()); return r; }

async function refresh() {
  const s = await jget('/api/status');
  $('status').textContent = `${s.tokenSet ? 'token set' : 'NO TOKEN'} · ${s.api} · ${s.calls} calls, ${s.xfers} xfers`;
  $('api').value = s.api;
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

$('save').addEventListener('click', async () => {
  await jpost('/api/config', { token: $('token').value.trim(), api: $('api').value.trim() });
  $('token').value = '';
  refresh();
});

async function runCall(method, path, body) {
  const r = await (await jpost('/api/call-new', { method, path, ...(body ? { body } : {}) })).json();
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

$('whoami').addEventListener('click', async () => {
  $('whoami-out').textContent = 'asking…';
  try {
    const c = await runCall('GET', '/user');
    $('whoami-out').textContent = c.code === 200
      ? `authenticated as ${c.body.login}`
      : `HTTP ${c.code} — ${JSON.stringify(c.body).slice(0, 120)}`;
  } catch (e) { $('whoami-out').textContent = e.message; }
  refresh();
});

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
    const c = await runCall(method, path, body);
    $('result').textContent = JSON.stringify(c, null, 2);
  } catch (e) { $('result').textContent = e.message; }
  refresh();
});

$('sweep').addEventListener('click', async () => {
  const r = await (await jpost('/api/sweep', {})).json();
  $('status').textContent = `swept ${r.swept}`;
  refresh();
});

refresh();
setInterval(refresh, 5000);
