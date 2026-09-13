'use strict';
const $ = (id) => document.getElementById(id);

async function refresh() {
  try {
    const cities = await fetch('/grubbery/places/api/cities').then((r) => r.json());
    const box = $('city-list');
    box.textContent = '';
    box.className = '';
    if (!cities.length) {
      box.textContent = 'No cities imported yet.';
      box.className = 'muted';
      return;
    }
    for (const c of cities) {
      const row = document.createElement('div');
      row.className = 'city-row';
      const name = document.createElement('span');
      name.className = 'city-name';
      name.textContent = c.city || c.id;
      const count = document.createElement('span');
      count.className = 'muted';
      count.textContent = (c.count || 0).toLocaleString() + ' places';
      const del = document.createElement('button');
      del.className = 'danger';
      del.textContent = 'delete';
      del.onclick = async () => {
        if (!confirm('Delete ' + c.id + '?')) return;
        await fetch('/grubbery/places/api/city/' + c.id, { method: 'DELETE' });
        refresh();
      };
      row.append(name, count, del);
      box.appendChild(row);
    }
  } catch (e) {
    $('city-list').textContent = 'load failed';
  }
}

async function upload(file) {
  $('up-status').textContent = 'reading ' + file.name + '…';
  const text = await file.text();
  let doc;
  try { doc = JSON.parse(text); } catch (e) {
    $('up-status').textContent = 'not valid JSON';
    return;
  }
  const id = (doc.city || file.name.replace(/\.json$/, ''))
    .toLowerCase().replace(/[^a-z0-9]+/g, '-');
  $('up-status').textContent = 'uploading ' + id + ' (' + (doc.count || '?') + ' places)…';
  try {
    const r = await fetch('/grubbery/places/api/city/' + id, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: text,
    });
    if (!r.ok) throw new Error(r.status);
    $('up-status').textContent = 'imported ' + id;
    refresh();
  } catch (e) {
    $('up-status').textContent = 'upload failed: ' + e.message;
  }
}

$('file').addEventListener('change', (e) => {
  if (e.target.files[0]) upload(e.target.files[0]);
});
const drop = $('drop');
drop.addEventListener('dragover', (e) => { e.preventDefault(); drop.classList.add('over'); });
drop.addEventListener('dragleave', () => drop.classList.remove('over'));
drop.addEventListener('drop', (e) => {
  e.preventDefault();
  drop.classList.remove('over');
  if (e.dataTransfer.files[0]) upload(e.dataTransfer.files[0]);
});
refresh();
