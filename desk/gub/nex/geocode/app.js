'use strict';
const $ = (id) => document.getElementById(id);
const jget = (u) => fetch(u).then((r) => r.json());

async function refresh() {
  try {
    const d = await jget('/grubbery/geocode/api/info');
    $('cache-count').textContent = d.cache ?? '–';
    $('calls-count').textContent = d.calls ?? '–';
    const tb = $('cfg-table').querySelector('tbody');
    tb.textContent = '';
    for (const [k, v] of Object.entries(d.config || {})) {
      const tr = document.createElement('tr');
      const td1 = document.createElement('td');
      td1.className = 'mono';
      td1.textContent = k;
      const td2 = document.createElement('td');
      td2.className = 'mono';
      td2.textContent = v;
      tr.append(td1, td2);
      tb.appendChild(tr);
    }
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

$('t-run').addEventListener('click', runTest);
$('t-q').addEventListener('keydown', (e) => { if (e.key === 'Enter') runTest(); });
refresh();
