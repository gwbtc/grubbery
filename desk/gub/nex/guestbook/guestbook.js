const BASE = '/grubbery/guestbook';

async function loadWhoami() {
  const el = document.getElementById('signer');
  const form = document.getElementById('post-form');
  try {
    const res = await fetch(BASE + '/api/whoami');
    if (!res.ok) throw new Error(res.statusText);
    const who = await res.json();
    if (who.authenticated) {
      el.innerHTML = 'signing as <span class="ship">' + esc(who.ship) + '</span>';
      form.hidden = false;
    } else {
      el.innerHTML = '<a href="/~/login?redirect=' + encodeURIComponent(BASE) + '">log in</a> to sign';
    }
  } catch(e) {
    el.innerHTML = '<div class="error">failed to load identity: ' + esc(e.message) + '</div>';
  }
}

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
  const msg = document.getElementById('msg-input').value.trim();
  if (!msg) return;
  try {
    const res = await fetch(BASE + '/api/post', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({message: msg})
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

loadWhoami();
loadEntries();
