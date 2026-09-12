'use strict';
const $ = (id) => document.getElementById(id);
const jget = (u) => fetch(u).then((r) => r.json());

let cfg = {};
let editing = false;

function renderConfig() {
  const tb = $('cfg-table').querySelector('tbody');
  tb.textContent = '';
  for (const [k, v] of Object.entries(cfg)) {
    const tr = document.createElement('tr');
    const td1 = document.createElement('td');
    td1.className = 'mono';
    td1.textContent = k;
    const td2 = document.createElement('td');
    if (editing) {
      const input = document.createElement('input');
      input.className = 'cfg-input mono';
      input.dataset.key = k;
      input.value = v;
      td2.appendChild(input);
    } else {
      td2.className = 'mono';
      td2.textContent = v;
    }
    tr.append(td1, td2);
    tb.appendChild(tr);
  }
  $('cfg-edit').hidden = editing;
  $('cfg-save').hidden = !editing;
  $('cfg-cancel').hidden = !editing;
}

async function refresh() {
  try {
    const d = await jget('/grubbery/geocode/api/info');
    $('cache-count').textContent = d.cache ?? '–';
    $('calls-count').textContent = d.calls ?? '–';
    if (!editing) { cfg = d.config || {}; renderConfig(); }
    $('status').textContent = 'updated ' + new Date().toLocaleTimeString();
  } catch (e) {
    $('status').textContent = 'info fetch failed';
  }
}

async function runTest() {
  const kind = $('t-kind').value;
  const params = new URLSearchParams({ kind });
  const q = $('t-q').value.trim();
  const lat = $('t-lat').value.trim();
  const lon = $('t-lon').value.trim();
  if (q) params.set('q', q);
  if (lat) params.set('lat', lat);
  if (lon) params.set('lon', lon);
  if ($('t-poly').checked) params.set('polygon', 'true');
  $('t-out').textContent = 'running…';
  $('t-out').className = 'muted';
  try {
    const d = await jget('/grubbery/geocode/api/test?' + params.toString());
    $('t-out').textContent = JSON.stringify(d, null, 2);
    $('t-out').className = '';
    refresh();
  } catch (e) {
    $('t-out').textContent = 'failed: ' + e.message;
  }
}

async function saveConfig() {
  const body = {};
  document.querySelectorAll('.cfg-input').forEach((i) => { body[i.dataset.key] = i.value.trim(); });
  $('cfg-status').textContent = 'saving…';
  try {
    const r = await fetch('/grubbery/geocode/api/config', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!r.ok) throw new Error(r.status);
    editing = false;
    document.querySelectorAll('.cfg-input').forEach((i) => { cfg[i.dataset.key] = i.value.trim(); });
    renderConfig();
    $('cfg-status').textContent = 'saved';
    setTimeout(() => { $('cfg-status').textContent = ''; }, 2000);
  } catch (e) {
    $('cfg-status').textContent = 'save failed';
  }
}

$('cfg-edit').addEventListener('click', () => { editing = true; renderConfig(); });
$('cfg-cancel').addEventListener('click', () => { editing = false; renderConfig(); });
$('cfg-save').addEventListener('click', saveConfig);
$('t-run').addEventListener('click', runTest);
$('t-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') runTest(); });
refresh();
