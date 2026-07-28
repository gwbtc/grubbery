const BASE = '/grubbery/feeds';

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : s;
  return d.innerHTML;
}

async function loadItems() {
  const srcEl = document.getElementById('sources');
  const itemsEl = document.getElementById('items');
  try {
    const res = await fetch(BASE + '/api/items');
    if (!res.ok) throw new Error(res.statusText);
    const data = await res.json();
    const stores = data.stores || [];
    const byUrl = {};
    stores.forEach(function(s) { byUrl[s.url] = s; });

    srcEl.innerHTML = (data.config || []).map(function(url) {
      const s = byUrl[url];
      return '<div class="src">'
        + '<span class="del" data-url="' + esc(url) + '">×</span>'
        + '<span>' + esc(s ? s.title : url) + '</span>'
        + '<span>' + (s ? '(' + s.items.length + ')' : '(not fetched yet)') + '</span>'
        + '</div>';
    }).join('');
    srcEl.querySelectorAll('.del').forEach(function(el) {
      el.addEventListener('click', async function() {
        if (!confirm('Remove ' + el.dataset.url + '?')) return;
        await post('/api/del', {url: el.dataset.url});
        loadItems();
      });
    });

    const all = stores.flatMap(function(s) {
      return s.items.map(function(it) { return Object.assign({feed: s.title}, it); });
    }).sort(function(a, b) { return b.published - a.published; });

    if (!all.length) {
      itemsEl.innerHTML = '<div class="empty">No items yet. Add a feed above.</div>';
      return;
    }

    let day = '';
    itemsEl.innerHTML = all.map(function(it) {
      const date = new Date(it.published);
      const key = date.toDateString();
      let heading = '';
      if (key !== day) {
        day = key;
        heading = '<div class="day">' + esc(date.toLocaleDateString(undefined,
          {day: 'numeric', month: 'long', year: 'numeric'})) + '</div>';
      }
      return heading
        + '<div class="item">'
        + '<a href="' + esc(it.link) + '" target="_blank" rel="noopener">' + esc(it.title || it.link) + '</a>'
        + '<div class="meta">' + esc(it.feed) + '</div>'
        + '</div>';
    }).join('');
  } catch(e) {
    itemsEl.innerHTML = '<div class="error">failed to load: ' + esc(e.message) + '</div>';
  }
}

async function post(path, body) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(body || {})
  });
  if (!res.ok) throw new Error(res.statusText);
}

document.getElementById('add-form').addEventListener('submit', async function(e) {
  e.preventDefault();
  const url = document.getElementById('url-input').value.trim();
  if (!url) return;
  try {
    await post('/api/add', {url: url});
    document.getElementById('url-input').value = '';
    setTimeout(loadItems, 3000);
  } catch(e) {
    alert('add failed: ' + e.message);
  }
});

document.getElementById('refresh-btn').addEventListener('click', async function() {
  try {
    await post('/api/refresh');
    setTimeout(loadItems, 3000);
  } catch(e) {
    alert('refresh failed: ' + e.message);
  }
});

loadItems();
