var API = '/grubbery/itinerary/api';
var currentId = null;
var itinerary = null;
var itineraries = [];
var map;
var markers = {};
var gmap = null;
var gmarkers = [];
var activeView = 'map';
var hiddenCats = {};
var editingPinId = null;

var DEFAULT_CATEGORIES = {
  food: { color: '#e67e22', label: 'Food' },
  bar: { color: '#3498db', label: 'Bars' },
  museum: { color: '#9b59b6', label: 'Museums' },
  park: { color: '#27ae60', label: 'Parks' },
  nightlife: { color: '#e91e63', label: 'Nightlife' },
  daytrip: { color: '#795548', label: 'Day Trips' },
  accommodation: { color: '#e74c3c', label: 'Accommodation' }
};

async function init() {
  initMap();
  bindEvents();
  await loadList();
  if (itineraries.length) {
    await loadItinerary(itineraries[0].id);
  } else {
    renderEmpty();
  }
}

function initMap() {
  map = L.map('map-container').setView([0, 0], 2);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 18,
    attribution: '&copy; OpenStreetMap'
  }).addTo(map);
  map.on('click', function(e) {
    if (!currentId) return;
    openPinForm(null, e.latlng.lat, e.latlng.lng);
  });
}

async function loadList() {
  try {
    itineraries = await fetch(API + '/list').then(function(r) { return r.json(); });
  } catch(e) {
    itineraries = [];
  }
  renderSidebar();
}

async function loadItinerary(id) {
  try {
    itinerary = await fetch(API + '/i/' + id).then(function(r) { return r.json(); });
    currentId = id;
  } catch(e) {
    itinerary = null;
    currentId = null;
    return;
  }
  if (!itinerary.pins) itinerary.pins = {};
  if (!itinerary.categories) itinerary.categories = DEFAULT_CATEGORIES;

  document.getElementById('map-name').textContent = itinerary.name || id;
  renderSidebar();
  renderFilters();
  renderMarkers();
  renderList();
  renderGlobe();

  if (itinerary.center && itinerary.center.length === 2) {
    map.setView(itinerary.center, itinerary.zoom || 13);
  }
}

function renderEmpty() {
  document.getElementById('map-name').textContent = 'Itinerary';
  document.getElementById('pin-list').innerHTML =
    '<div class="empty-state">No itineraries yet. Click + to create one.</div>';
}

// -- Sidebar --

function openSidebar() {
  document.getElementById('sidebar').classList.add('open');
  document.getElementById('sidebar').classList.remove('hidden');
  document.getElementById('sidebar-overlay').classList.remove('hidden');
}

function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  setTimeout(function() {
    document.getElementById('sidebar').classList.add('hidden');
  }, 200);
  document.getElementById('sidebar-overlay').classList.add('hidden');
}

function renderSidebar() {
  var list = document.getElementById('sidebar-list');
  list.innerHTML = itineraries.map(function(it) {
    var active = it.id === currentId ? ' active' : '';
    return '<div class="sidebar-item' + active + '" data-id="' + it.id + '">' +
      esc(it.name) + '</div>';
  }).join('');
  if (!itineraries.length) {
    list.innerHTML = '<div style="padding:16px;color:#999;font-size:13px">No itineraries yet</div>';
  }
  list.querySelectorAll('.sidebar-item').forEach(function(item) {
    item.onclick = function() {
      loadItinerary(item.getAttribute('data-id'));
      closeSidebar();
    };
  });
}

// -- Categories & Colors --

function cats() {
  return (itinerary && itinerary.categories) || DEFAULT_CATEGORIES;
}

function catColor(cat) {
  var c = cats();
  return c[cat] ? c[cat].color : '#888';
}

function catLabel(cat) {
  var c = cats();
  return c[cat] ? c[cat].label : cat;
}

// -- Map Markers --

function makeIcon(color) {
  return L.divIcon({
    className: '',
    html: '<div style="background:' + color +
      ';width:14px;height:14px;border-radius:50%;border:2px solid white;' +
      'box-shadow:0 1px 4px rgba(0,0,0,0.4)"></div>',
    iconSize: [14, 14],
    iconAnchor: [7, 7],
    popupAnchor: [0, -10]
  });
}

function renderMarkers() {
  Object.keys(markers).forEach(function(id) { map.removeLayer(markers[id]); });
  markers = {};
  if (!itinerary) return;
  var pins = itinerary.pins || {};

  Object.keys(pins).forEach(function(id) {
    var pin = pins[id];
    if (hiddenCats[pin.cat]) return;
    var marker = L.marker([pin.lat, pin.lng], { icon: makeIcon(catColor(pin.cat)) }).addTo(map);
    var fromHtml = '';
    if (pin.from && pin.from.length) {
      fromHtml = '<div class="popup-from">' + esc(pin.from.join(', ')) + '</div>';
    }
    marker.bindPopup(
      '<div class="popup-name">' + esc(pin.name) + '</div>' +
      '<div class="popup-desc">' + esc(pin.desc || '') + '</div>' +
      fromHtml +
      '<span class="popup-edit" data-id="' + id + '">edit</span>'
    );
    markers[id] = marker;
  });

  map.on('popupopen', function(e) {
    var el = e.popup.getElement();
    if (!el) return;
    var btn = el.querySelector('.popup-edit');
    if (btn) {
      btn.onclick = function() {
        map.closePopup();
        openPinForm(btn.getAttribute('data-id'));
      };
    }
  });
}

// -- List View --

function renderList() {
  var list = document.getElementById('pin-list');
  if (!itinerary) { list.innerHTML = ''; return; }
  var pins = itinerary.pins || {};
  var ids = Object.keys(pins).filter(function(id) { return !hiddenCats[pins[id].cat]; });

  if (!ids.length) {
    list.innerHTML = '<div class="empty-state">No pins. Click the map or press + to add one.</div>';
    return;
  }

  ids.sort(function(a, b) { return (pins[a].name || '').localeCompare(pins[b].name || ''); });

  list.innerHTML = ids.map(function(id) {
    var pin = pins[id];
    var fromHtml = pin.from && pin.from.length
      ? '<div class="pin-card-from">' + esc(pin.from.join(', ')) + '</div>' : '';
    return '<div class="pin-card" data-id="' + id + '">' +
      '<div class="pin-dot" style="background:' + catColor(pin.cat) + '"></div>' +
      '<div class="pin-info">' +
        '<div class="pin-card-name">' + esc(pin.name) + '</div>' +
        (pin.desc ? '<div class="pin-card-desc">' + esc(pin.desc) + '</div>' : '') +
        fromHtml +
      '</div>' +
      '<span class="pin-card-cat" style="background:' + catColor(pin.cat) + '">' +
        esc(catLabel(pin.cat)) + '</span>' +
    '</div>';
  }).join('');

  list.querySelectorAll('.pin-card').forEach(function(card) {
    card.onclick = function() { openPinForm(card.getAttribute('data-id')); };
  });
}

// -- Filters --

function renderFilters() {
  var container = document.getElementById('filters');
  var c = cats();
  var keys = Object.keys(c);
  if (!keys.length) { container.classList.add('hidden'); return; }
  container.classList.remove('hidden');
  container.innerHTML = keys.map(function(key) {
    var inactive = hiddenCats[key] ? ' inactive' : '';
    return '<button class="filter-btn' + inactive + '" data-cat="' + key +
      '" style="border-color:' + c[key].color + ';color:' + c[key].color + '">' +
      c[key].label + '</button>';
  }).join('');

  container.querySelectorAll('.filter-btn').forEach(function(btn) {
    btn.onclick = function() {
      var cat = btn.getAttribute('data-cat');
      if (hiddenCats[cat]) { delete hiddenCats[cat]; btn.classList.remove('inactive'); }
      else { hiddenCats[cat] = true; btn.classList.add('inactive'); }
      renderMarkers();
      renderList();
      renderGlobe();
    };
  });
}

// -- Pin Form --

function openPinForm(id, lat, lng) {
  editingPinId = id;
  var pin = id && itinerary ? (itinerary.pins || {})[id] : null;
  document.getElementById('form-title').textContent = pin ? 'Edit Pin' : 'Add Pin';
  document.getElementById('form-delete').classList.toggle('hidden', !pin);
  document.getElementById('pin-name').value = pin ? pin.name || '' : '';
  document.getElementById('pin-desc').value = pin ? pin.desc || '' : '';
  document.getElementById('pin-from').value = pin && pin.from ? pin.from.join(', ') : '';
  document.getElementById('pin-notes').value = pin ? pin.notes || '' : '';
  document.getElementById('pin-lat').value = pin ? pin.lat : (lat || '');
  document.getElementById('pin-lng').value = pin ? pin.lng : (lng || '');
  document.getElementById('form-status').textContent = '';

  var sel = document.getElementById('pin-cat');
  var c = cats();
  sel.innerHTML = Object.keys(c).map(function(key) {
    var selected = (pin && pin.cat === key) ? ' selected' : '';
    return '<option value="' + key + '"' + selected + '>' + c[key].label + '</option>';
  }).join('');

  document.getElementById('pin-modal').classList.remove('hidden');
}

function closePinForm() {
  document.getElementById('pin-modal').classList.add('hidden');
  editingPinId = null;
}

async function savePin() {
  var name = document.getElementById('pin-name').value.trim();
  var lat = parseFloat(document.getElementById('pin-lat').value);
  var lng = parseFloat(document.getElementById('pin-lng').value);

  if (!name) { document.getElementById('form-status').textContent = 'Name is required'; return; }
  if (isNaN(lat) || isNaN(lng)) { document.getElementById('form-status').textContent = 'Valid coordinates required'; return; }

  var fromStr = document.getElementById('pin-from').value.trim();
  var from = fromStr ? fromStr.split(',').map(function(s) { return s.trim(); }).filter(Boolean) : [];

  var pin = {
    name: name, lat: lat, lng: lng,
    cat: document.getElementById('pin-cat').value,
    desc: document.getElementById('pin-desc').value.trim(),
    from: from,
    notes: document.getElementById('pin-notes').value.trim()
  };

  var pinId = editingPinId || ('pin-' + Date.now().toString(36));

  try {
    var r = await fetch(API + '/i/' + currentId + '/pin/' + pinId, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(pin)
    });
    if (!r.ok) throw new Error('Save failed');
    itinerary = await r.json();
    renderMarkers();
    renderList();
    renderGlobe();
    closePinForm();
    if (!editingPinId && activeView === 'map') {
      map.setView([lat, lng], Math.max(map.getZoom(), 14));
    }
  } catch(e) {
    document.getElementById('form-status').textContent = 'Save failed';
  }
}

async function deletePin() {
  if (!editingPinId) return;
  if (!confirm('Delete this pin?')) return;
  try {
    var r = await fetch(API + '/i/' + currentId + '/pin/' + editingPinId, { method: 'DELETE' });
    if (!r.ok) throw new Error('Delete failed');
    itinerary = await r.json();
    renderMarkers();
    renderList();
    renderGlobe();
    closePinForm();
  } catch(e) {
    document.getElementById('form-status').textContent = 'Delete failed';
  }
}

// -- New Itinerary --

function openNewItinerary() {
  var name = prompt('Itinerary name:');
  if (!name) return;
  var id = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  if (!id) return;
  var doc = {
    name: name,
    center: [0, 0],
    zoom: 2,
    categories: DEFAULT_CATEGORIES,
    pins: {}
  };
  fetch(API + '/i/' + id, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(doc)
  }).then(function(r) {
    if (!r.ok) throw new Error();
    return loadList();
  }).then(function() {
    return loadItinerary(id);
  });
}

// -- View Toggle --

function setView(view) {
  activeView = view;
  ['map', 'globe', 'list'].forEach(function(v) {
    document.getElementById(v + '-view').classList.toggle('hidden', view !== v);
    document.getElementById('btn-' + v).classList.toggle('active', view === v);
  });
  if (view === 'map') setTimeout(function() { map.invalidateSize(); }, 50);
  if (view === 'globe') {
    initGlobe();
    setTimeout(function() { resizeGlobe(); renderGlobe(); focusGlobe(); }, 50);
  }
}

// -- Globe View (MapLibre GL, globe projection) --
// Same tiled map as the Leaflet view, but it curls into a globe on zoom-out.

function initGlobe() {
  if (gmap) return;
  gmap = new maplibregl.Map({
    container: 'globe-container',
    style: {
      version: 8,
      sources: {
        osm: {
          type: 'raster',
          tiles: [
            'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          attribution: '&copy; OpenStreetMap'
        }
      },
      layers: [{ id: 'osm', type: 'raster', source: 'osm' }]
    },
    center: [0, 20],
    zoom: 1.4
  });
  gmap.addControl(new maplibregl.NavigationControl(), 'top-right');
  gmap.on('style.load', function() { gmap.setProjection({ type: 'globe' }); });
  gmap.on('move', cullGlobeFar);
}
// pins are DOM elements over the canvas, so the sphere doesn't
// occlude them — hide any pin past the horizon (a hair under 90° of
// great-circle distance from the view center)
function cullGlobeFar() {
  if (!gmap) return;
  var c = gmap.getCenter();
  gmarkers.forEach(function(m) {
    var p = m.getLngLat();
    m.getElement().style.visibility =
      (gcDist(c.lat, c.lng, p.lat, p.lng) > 85) ? 'hidden' : '';
  });
}
function gcDist(lat1, lon1, lat2, lon2) {
  var r = Math.PI / 180;
  var a = Math.sin((lat2 - lat1) * r / 2), b = Math.sin((lon2 - lon1) * r / 2);
  var h = a * a + Math.cos(lat1 * r) * Math.cos(lat2 * r) * b * b;
  return 2 * Math.asin(Math.sqrt(h)) / r;
}

function renderGlobe() {
  if (!gmap || !itinerary) return;
  gmarkers.forEach(function(m) { m.remove(); });
  gmarkers = [];
  var pins = itinerary.pins || {};
  Object.keys(pins)
    .filter(function(id) { return !hiddenCats[pins[id].cat]; })
    .forEach(function(id) {
      var p = pins[id];
      var el = document.createElement('div');
      el.className = 'globe-pin';
      el.style.background = catColor(p.cat);
      el.title = p.name;
      el.onclick = function(e) { e.stopPropagation(); openPinForm(id); };
      gmarkers.push(new maplibregl.Marker({ element: el }).setLngLat([p.lng, p.lat]).addTo(gmap));
    });
  cullGlobeFar();
}

function resizeGlobe() {
  if (gmap) gmap.resize();
}

function focusGlobe() {
  if (!gmap || !itinerary) return;
  var c = itinerary.center;
  if (c && c.length === 2) gmap.flyTo({ center: [c[1], c[0]], zoom: 3, duration: 800 });
}

// -- Events --

function bindEvents() {
  document.getElementById('btn-map').onclick = function() { setView('map'); };
  document.getElementById('btn-globe').onclick = function() { setView('globe'); };
  document.getElementById('btn-list').onclick = function() { setView('list'); };
  window.addEventListener('resize', function() { if (activeView === 'globe') resizeGlobe(); });
  document.getElementById('btn-add').onclick = function() {
    if (!currentId) { openNewItinerary(); return; }
    var center = map.getCenter();
    openPinForm(null, center.lat, center.lng);
  };
  document.getElementById('btn-sidebar').onclick = openSidebar;
  document.getElementById('sidebar-overlay').onclick = closeSidebar;
  document.getElementById('sidebar-new').onclick = function() {
    closeSidebar();
    openNewItinerary();
  };
  document.getElementById('form-close').onclick = closePinForm;
  document.getElementById('form-save').onclick = savePin;
  document.getElementById('form-delete').onclick = deletePin;
  document.getElementById('pin-modal').onclick = function(e) {
    if (e.target === document.getElementById('pin-modal')) closePinForm();
  };
}

function esc(s) {
  if (!s) return '';
  var d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

init();
