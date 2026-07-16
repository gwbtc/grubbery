const BASE = '/grubbery/guestbook';

async function loadEntries() {
  const el = document.getElementById('entries');
  try {
    const res = await fetch(BASE + '/api/entries');
    if (!res.ok) throw new Error(res.statusText);
    const data = await res.json();
    if (data.error) { el.innerHTML = '<div class="error">' + data.error + '</div>'; return; }
    const rows = Array.isArray(data) ? data : (data.results || []);
    if (!rows.length) { el.innerHTML = '<div class="entry">No entries yet.</div>'; return; }
    el.innerHTML = rows.map(function(r) {
      return '<div class="entry">'
        + '<span class="name">' + esc(r.name) + '</span>'
        + '<span class="time"></span>'
        + '<div class="msg">' + esc(r.message) + '</div>'
        + '</div>';
    }).join('');
  } catch(e) {
    el.innerHTML = '<div class="error">failed to load: ' + esc(e.message) + '</div>';
  }
}

document.getElementById('post-form').addEventListener('submit', async function(e) {
  e.preventDefault();
  const name = document.getElementById('name-input').value.trim();
  const msg = document.getElementById('msg-input').value.trim();
  if (!name || !msg) return;
  try {
    const res = await fetch(BASE + '/api/post', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({name: name, message: msg})
    });
    if (!res.ok) throw new Error(res.statusText);
    document.getElementById('msg-input').value = '';
    loadEntries();
  } catch(e) {
    alert('post failed: ' + e.message);
  }
});

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

loadEntries();
