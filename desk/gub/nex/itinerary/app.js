var API = '/grubbery/itinerary/api';
var currentId = null;
var itinerary = null;
var itineraries = [];
var map;
var markers = {};
var flatProjection = true;
var activeView = 'map';
var hiddenCats = {};
var editingPinId = null;
var zoneLayers = {};
var zonesVisible = true;
var editingZoneId = null;
var drawing = false;
var drawPoints = [];
var drawLayer = null;
var panelQuery = '';

var DEFAULT_CATEGORIES = {
  food: { color: '#e67e22', label: 'Food' },
  bar: { color: '#3498db', label: 'Bars' },
  museum: { color: '#9b59b6', label: 'Museums' },
  park: { color: '#27ae60', label: 'Parks' },
  nightlife: { color: '#e91e63', label: 'Nightlife' },
  daytrip: { color: '#795548', label: 'Day Trips' },
  accommodation: { color: '#e74c3c', label: 'Accommodation' }
};

// URL hash carries the current itinerary + view (#<id>/sched),
// so a refresh lands back where you were.
var hashReady = false;

function syncHash() {
  if (!hashReady || !currentId) return;
  var h = '#' + encodeURIComponent(currentId) + '/' + activeView;
  if (location.hash !== h) history.replaceState(null, '', h);
}

async function init() {
  initMap();
  bindEvents();
  var m = /^#([^\/]*)\/?([a-z]*)/.exec(location.hash || '');
  var wantId = m ? decodeURIComponent(m[1]) : '';
  var wantView = (m && m[2]) || '';
  await loadList();
  if (itineraries.some(function(it) { return it.id === wantId; })) {
    await loadItinerary(wantId);
  } else {
    // the app only runs on a concrete itinerary; the home page picks one
    location.replace('/grubbery/itinerary');
    return;
  }
  if (wantView && wantView !== 'map') setView(wantView);
  hashReady = true;
  syncHash();
}

var mapReady = false;
var activePopup = null;

function initMap() {
  map = new maplibregl.Map({
    container: 'map-container',
    style: 'https://tiles.openfreemap.org/styles/liberty',
    center: [0, 0],
    zoom: 2,
    attributionControl: { compact: true }
  });
  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');

  map.on('load', function() {
    // zones + draw preview live in GeoJSON sources; colors ride each feature
    map.addSource('zones', { type: 'geojson', data: emptyFC() });
    map.addLayer({ id: 'zones-fill', type: 'fill', source: 'zones',
      paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.07 } });
    map.addLayer({ id: 'zones-line', type: 'line', source: 'zones',
      paint: { 'line-color': ['get', 'color'], 'line-width': 1.5, 'line-dasharray': [2, 2] } });
    map.addSource('draw', { type: 'geojson', data: emptyFC() });
    map.addLayer({ id: 'draw-fill', type: 'fill', source: 'draw',
      paint: { 'fill-color': '#1a1a1a', 'fill-opacity': 0.05 } });
    map.addLayer({ id: 'draw-line', type: 'line', source: 'draw',
      paint: { 'line-color': '#1a1a1a', 'line-width': 1.5, 'line-dasharray': [1, 2] } });
    mapReady = true;
    renderZones();
    updateDrawLayer();
  });

  // pane size settles after the web components upgrade (and changes on
  // every split drag) — keep the canvas current
  if (window.ResizeObserver) {
    new ResizeObserver(function() { map.resize(); })
      .observe(document.getElementById('map-container'));
  }

  map.on('click', function(e) {
    if (!currentId) return;
    if (drawing) {
      drawPoints.push([e.lngLat.lat, e.lngLat.lng]);
      updateDrawLayer();
      return;
    }
    // zones the click landed in ride along on the what's-here card
    var hits = mapReady ? map.queryRenderedFeatures(e.point, { layers: ['zones-fill'] }) : [];
    var zoneIds = hits.map(function(h) { return h.properties.id; });
    whatsHere(e.lngLat.lat, e.lngLat.lng, zoneIds);
  });
}

// -- "What's here?": reverse geocode a bare map click into a place
// card, with add-pin pre-filled from the answer.
async function whatsHere(lat, lng, zoneIds) {
  var loading = popupDom('Looking\u2026', null, null, null, null);
  openPopupAt([lng, lat], loading);
  var data;
  try {
    data = await fetch(API + '/geocode?kind=reverse&lat=' + lat.toFixed(6) +
      '&lon=' + lng.toFixed(6)).then(function(r) { return r.json(); });
  } catch(e) { data = null; }
  // user may have clicked elsewhere meanwhile
  if (!activePopup || !activePopup.isOpen()) return;
  var name = (data && data.name) || '';
  var addr = (data && data.display_name) || '';
  if (!name && data && data.address) {
    name = [data.address.road, data.address.house_number].filter(Boolean).join(' ');
  }
  if (!name) name = 'Unnamed spot';
  // trim the display name down to the local part
  var shortAddr = addr.split(', ').slice(0, 3).join(', ');
  var dom = popupDom(name, shortAddr, null, 'add pin', function() {
    openPinForm(null, lat, lng);
    document.getElementById('pin-name').value = name === 'Unnamed spot' ? '' : name;
  });
  (zoneIds || []).forEach(function(zid) {
    var zone = itinerary && (itinerary.zones || {})[zid];
    if (!zone) return;
    var row = document.createElement('div');
    row.className = 'popup-zone';
    var dot = document.createElement('span');
    dot.className = 'popup-zone-dot';
    dot.style.borderColor = catColor(zone.cat);
    var label = document.createElement('span');
    label.textContent = 'in ' + zone.name;
    var edit = document.createElement('span');
    edit.className = 'popup-edit';
    edit.textContent = 'edit zone';
    edit.onclick = function() { closePopups(); openZoneForm(zid); };
    row.append(dot, label, edit);
    dom.appendChild(row);
  });
  openPopupAt([lng, lat], dom);
}

function emptyFC() { return { type: 'FeatureCollection', features: [] }; }

function closePopups() {
  if (activePopup) { activePopup.remove(); activePopup = null; }
}

function openPopupAt(lngLat, dom) {
  closePopups();
  activePopup = new maplibregl.Popup({ offset: 12, maxWidth: '260px' })
    .setLngLat(lngLat)
    .setDOMContent(dom)
    .addTo(map);
}

// popup body: name, desc, optional from-list, one action link
function popupDom(name, desc, from, action, onAction, notes) {
  var d = document.createElement('div');
  var n = document.createElement('div'); n.className = 'popup-name'; n.textContent = name || '';
  d.appendChild(n);
  if (desc) { var ds = document.createElement('div'); ds.className = 'popup-desc'; ds.textContent = desc; d.appendChild(ds); }
  if (notes) { var no = document.createElement('div'); no.className = 'popup-notes'; no.innerHTML = mdNotes(notes); d.appendChild(no); }
  if (from && from.length) { var f = document.createElement('div'); f.className = 'popup-from'; f.textContent = from.join(', '); d.appendChild(f); }
  if (action) {
    var a = document.createElement('span'); a.className = 'popup-edit'; a.textContent = action;
    a.onclick = function() { closePopups(); onAction(); };
    d.appendChild(a);
  }
  return d;
}

async function loadList() {
  try {
    itineraries = await fetch(API + '/list').then(function(r) { return r.json(); });
  } catch(e) {
    itineraries = [];
  }
  renderMenu();
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
  if (!itinerary.zones) itinerary.zones = {};
  if (!itinerary.categories) itinerary.categories = DEFAULT_CATEGORIES;

  document.getElementById('map-name').textContent = itinerary.name || id;
  syncHash();
  window.dispatchEvent(new CustomEvent('itin-changed'));
  renderMenu();
  renderFilters();
  renderMarkers();
  renderZones();
  renderTrip();
  renderPanel();
  renderEvents();
  if (activeView === 'sched') renderSched();

  // fit the view to everything on the map; fall back to the stored center
  var fit = new maplibregl.LngLatBounds();
  Object.keys(itinerary.pins || {}).forEach(function(pid) {
    var p = itinerary.pins[pid];
    fit.extend([p.lng, p.lat]);
  });
  Object.keys(itinerary.zones || {}).forEach(function(zid) {
    (itinerary.zones[zid].points || []).forEach(function(pt) {
      fit.extend([pt[1], pt[0]]);
    });
  });
  if (!fit.isEmpty()) {
    map.fitBounds(fit, { padding: 70, maxZoom: 15, animate: false });
  } else if (itinerary.center && itinerary.center.length === 2) {
    map.jumpTo({ center: [itinerary.center[1], itinerary.center[0]], zoom: itinerary.zoom || 13 });
  }
}

function renderEmpty() {
  document.getElementById('map-name').textContent = 'Itinerary';
  document.getElementById('panel-list').innerHTML =
    '<div class="panel-empty">No itineraries yet \u2014 click + to create one.</div>';
}

// -- Itinerary Menu --

function renderMenu() {
  var box = document.getElementById('itin-menu-items');
  box.innerHTML = itineraries.map(function(it) {
    var active = it.id === currentId ? ' class="active"' : '';
    return '<button data-id="' + it.id + '"' + active + '>' + esc(it.name) + '</button>';
  }).join('');
  box.querySelectorAll('button[data-id]').forEach(function(item) {
    item.onclick = function() { loadItinerary(item.getAttribute('data-id')); };
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

function makePinEl(color) {
  var el = document.createElement('div');
  el.style.cssText = 'background:' + color +
    ';width:14px;height:14px;border-radius:50%;border:2px solid white;' +
    'box-shadow:0 1px 4px rgba(0,0,0,0.4);cursor:pointer';
  return el;
}

function renderMarkers() {
  Object.keys(markers).forEach(function(id) { markers[id].remove(); });
  markers = {};
  if (!itinerary) return;
  var pins = itinerary.pins || {};

  Object.keys(pins).forEach(function(id) {
    var pin = pins[id];
    if (hiddenCats[pin.cat]) return;
    var el = makePinEl(catColor(pin.cat));
    el.addEventListener('click', function(ev) {
      ev.stopPropagation();
      openPopupAt([pin.lng, pin.lat],
        popupDom(pin.name, pin.desc, pin.from, 'edit', function() { openPinForm(id); }, pin.notes));
    });
    markers[id] = new maplibregl.Marker({ element: el })
      .setLngLat([pin.lng, pin.lat])
      .addTo(map);
  });
}

// -- Pin Panel --

function pinMatches(pin, q) {
  if (!q) return true;
  var hay = [pin.name, pin.desc, pin.notes, catLabel(pin.cat)]
    .concat(pin.from || []).join(' ').toLowerCase();
  return hay.indexOf(q) !== -1;
}

function renderPanel() {
  var list = document.getElementById('panel-list');
  if (!itinerary) { list.innerHTML = ''; return; }
  var pins = itinerary.pins || {};
  var q = panelQuery.toLowerCase();
  var ids = Object.keys(pins).filter(function(id) {
    return !hiddenCats[pins[id].cat] && pinMatches(pins[id], q);
  });
  if (!ids.length) {
    list.innerHTML = '<div class="panel-empty">No matching pins</div>';
    return;
  }

  // group by category, categories in label order, pins A-Z within
  var groups = {};
  ids.forEach(function(id) {
    var cat = pins[id].cat;
    (groups[cat] = groups[cat] || []).push(id);
  });
  var catKeys = Object.keys(groups);
  catKeys.sort(function(a, b) { return catLabel(a).localeCompare(catLabel(b)); });

  list.innerHTML = catKeys.map(function(cat) {
    var rows = groups[cat];
    rows.sort(function(a, b) { return (pins[a].name || '').localeCompare(pins[b].name || ''); });
    return '<div class="panel-group">' +
      '<span class="pin-dot" style="background:' + catColor(cat) + '"></span>' +
      esc(catLabel(cat)) +
      '<span class="panel-group-count">' + rows.length + '</span>' +
    '</div>' +
    rows.map(function(id) {
      var pin = pins[id];
      var inner =
        '<div class="pin-dot" style="background:' + catColor(pin.cat) + '" data-fly="' + id + '" title="Show on map"></div>' +
        '<div class="panel-row-text">' +
          '<div class="panel-row-name">' + esc(pin.name) + '</div>' +
          (pin.desc ? '<div class="panel-row-desc">' + esc(pin.desc) + '</div>' : '') +
        '</div>';
      if (!pin.notes) {
        return '<div class="panel-row" data-id="' + id + '">' + inner + '</div>';
      }
      // native disclosure: the row is the summary, notes collapse under it
      return '<details class="panel-details" data-id="' + id + '"' + (expandedPins[id] ? ' open' : '') + '>' +
        '<summary class="panel-row">' + inner + '</summary>' +
        '<div class="panel-row-notes">' + mdNotes(pin.notes) + '</div>' +
      '</details>';
    }).join('');
  }).join('');

  // plain rows (no notes): click flies the map
  list.querySelectorAll('.panel-row[data-id]').forEach(function(row) {
    row.onclick = function() { focusPin(row.getAttribute('data-id')); };
  });
  // details rows: click toggles the disclosure AND highlights the pin
  list.querySelectorAll('.panel-details summary').forEach(function(sum) {
    sum.addEventListener('click', function() {
      focusPin(sum.closest('.panel-details').getAttribute('data-id'));
    });
  });
  // the category dot always flies, even inside a details summary
  list.querySelectorAll('.pin-dot[data-fly]').forEach(function(dot) {
    dot.onclick = function(e) {
      e.preventDefault();
      e.stopPropagation();
      focusPin(dot.getAttribute('data-fly'));
    };
  });
  // remember open/closed across rerenders
  list.querySelectorAll('.panel-details').forEach(function(det) {
    det.addEventListener('toggle', function() {
      expandedPins[det.getAttribute('data-id')] = det.open;
    });
  });
}
var expandedPins = {};

// notes are markdown: tables, lists and emphasis render properly
function mdNotes(notes) {
  if (window.marked) { try { return marked.parse(notes); } catch (e) {} }
  return esc(notes);
}

function focusPin(id) {
  var pin = itinerary && (itinerary.pins || {})[id];
  if (!pin) return;
  if (activeView !== 'map') setView('map');
  map.flyTo({ center: [pin.lng, pin.lat], zoom: Math.max(map.getZoom(), 16) });
  var marker = markers[id];
  if (!marker) return;
  openPopupAt([pin.lng, pin.lat],
    popupDom(pin.name, pin.desc, pin.from, 'edit', function() { openPinForm(id); }, pin.notes));
  var el = marker.getElement();
  if (el) {
    el.classList.remove('pin-pulse');
    void el.offsetWidth;
    el.classList.add('pin-pulse');
    setTimeout(function() { el.classList.remove('pin-pulse'); }, 1800);
  }
}

// -- Trip tab --

function renderTodos() {
  var list = document.getElementById('todo-list');
  if (!list) return;
  list.textContent = '';
  var todos = (itinerary && itinerary.todos) || {};
  var ids = Object.keys(todos);
  if (!ids.length) {
    list.innerHTML = '<div class="panel-empty" style="padding:10px">Nothing on the list.</div>';
    return;
  }
  // open items first, then done; stable by text
  ids.sort(function(x, y) {
    var a = todos[x], b = todos[y];
    if (!!a.done !== !!b.done) return a.done ? 1 : -1;
    return (a.text || '').localeCompare(b.text || '');
  });
  ids.forEach(function(id) {
    var t = todos[id];
    var row = document.createElement('label');
    row.className = 'todo-row' + (t.done ? ' done' : '');
    var cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = !!t.done;
    cb.onchange = async function() {
      t.done = cb.checked;
      try { await putDoc(); } catch(e) {}
      renderTodos();
    };
    var tx = document.createElement('span');
    tx.className = 'todo-text';
    tx.textContent = t.text || '';
    var del = document.createElement('span');
    del.className = 'todo-del';
    del.textContent = '\u00d7';
    del.onclick = async function(e) {
      e.preventDefault();
      delete itinerary.todos[id];
      try { await putDoc(); } catch(e2) {}
      renderTodos();
    };
    row.append(cb, tx, del);
    list.appendChild(row);
  });
}

function renderTrip() {
  renderTodos();
  var box = document.getElementById('about-md');
  var zl = document.getElementById('zone-list');
  if (!itinerary) { box.textContent = ''; zl.innerHTML = ''; return; }

  var md = itinerary.desc || '';
  if (!md) {
    box.className = 'about-empty';
    box.textContent = 'No description yet — click edit.';
  } else {
    box.className = '';
    if (window.marked) { box.innerHTML = marked.parse(md); }
    else { box.textContent = md; }
  }

  var zones = itinerary.zones || {};
  var ids = Object.keys(zones);
  ids.sort(function(a, b) { return (zones[a].name || '').localeCompare(zones[b].name || ''); });
  if (!ids.length) {
    zl.innerHTML = '<div class="panel-empty">No zones yet — draw one with the &#9634; button.</div>';
  } else {
    zl.innerHTML = ids.map(function(id) {
      var z = zones[id];
      return '<div class="panel-row" data-id="' + id + '">' +
        '<div class="pin-dot zone-dot" style="border-color:' + catColor(z.cat) + '"></div>' +
        '<div class="panel-row-text">' +
          '<div class="panel-row-name">' + esc(z.name) + '</div>' +
          (z.desc ? '<div class="panel-row-desc">' + esc(z.desc) + '</div>' : '') +
        '</div>' +
      '</div>';
    }).join('');
    zl.querySelectorAll('.panel-row').forEach(function(row) {
      row.onclick = function() { focusZone(row.getAttribute('data-id')); };
    });
  }
}

function focusZone(id) {
  var z = itinerary && (itinerary.zones || {})[id];
  if (!z || !z.points || z.points.length < 3) return;
  if (activeView !== 'map') setView('map');
  var b = new maplibregl.LngLatBounds();
  z.points.forEach(function(p) { b.extend([p[1], p[0]]); });
  map.fitBounds(b, { padding: 60 });
  openPopupAt(b.getCenter().toArray(),
    popupDom(z.name, z.desc, null, 'edit', function() { openZoneForm(id); }));
}

async function saveAbout() {
  var text = document.getElementById('about-text').value;
  var doc = Object.assign({}, itinerary, { desc: text });
  try {
    var r = await fetch(API + '/i/' + currentId, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(doc)
    });
    if (!r.ok) throw new Error('Save failed');
    itinerary = doc;
    renderTrip();
    document.getElementById('about-modal').close();
  } catch(e) {
    document.getElementById('about-status').textContent = 'Save failed';
  }
}

// -- Map Search (Photon autocomplete via the geocode nexus) --

var searchTimer = null;
var searchMarker = null;

// category keywords -> osm tags: typing one flips the search box into
// "nearby" mode (Overpass around the map center) instead of name search
var NEARBY_KEYWORDS = {
  tobacco: 'shop:tobacco', tabacchi: 'shop:tobacco',
  gas: 'amenity:fuel', fuel: 'amenity:fuel', benzina: 'amenity:fuel',
  pharmacy: 'amenity:pharmacy', farmacia: 'amenity:pharmacy',
  atm: 'amenity:atm', bancomat: 'amenity:atm',
  supermarket: 'shop:supermarket', grocery: 'shop:supermarket',
  cafe: 'amenity:cafe', coffee: 'amenity:cafe',
  restaurant: 'amenity:restaurant',
  bar: 'amenity:bar',
  bakery: 'shop:bakery',
  gelato: 'amenity:ice_cream',
  laundry: 'shop:laundry',
  hospital: 'amenity:hospital',
  pizza: 'cuisine:pizza', pizzeria: 'cuisine:pizza',
  bank: 'amenity:bank',
  hotel: 'tourism:hotel',
  parking: 'amenity:parking',
  wine: 'shop:wine', enoteca: 'shop:wine',
  bus: 'highway:bus_stop',
  train: 'railway:station'
};

function nearbyTag(q) {
  var k = q.toLowerCase();
  if (NEARBY_KEYWORDS[k]) return NEARBY_KEYWORDS[k];
  // plural / trailing-s forgiveness
  if (k.length > 3 && k.slice(-1) === 's' && NEARBY_KEYWORDS[k.slice(0, -1)]) {
    return NEARBY_KEYWORDS[k.slice(0, -1)];
  }
  return null;
}

// -- imported places (the places nexus): loaded once per city, then
// searched client-side — instant and confidence-ranked
var placesCities = null;
var placesDocs = {};

async function placesFor(center) {
  if (placesCities === null) {
    try {
      placesCities = await fetch('/grubbery/places/api/cities').then(function(r) { return r.json(); });
    } catch(e) { placesCities = []; }
  }
  var hit = null;
  for (var i = 0; i < placesCities.length; i++) {
    var b = placesCities[i].bbox || [];
    if (b.length === 4 && center.lng > b[0] && center.lat > b[1] &&
        center.lng < b[2] && center.lat < b[3]) { hit = placesCities[i]; break; }
  }
  if (!hit) return null;
  if (!placesDocs[hit.id]) {
    try {
      placesDocs[hit.id] = await fetch('/grubbery/places/api/city/' + hit.id)
        .then(function(r) { return r.json(); });
    } catch(e) { return null; }
  }
  return placesDocs[hit.id];
}

function searchPlaces(doc, q, center) {
  var ql = q.toLowerCase();
  var qcat = ql.replace(/ /g, '_');
  var out = [];
  var arr = (doc && doc.places) || [];
  for (var i = 0; i < arr.length; i++) {
    var p = arr[i];
    var nm = (p.name || '').toLowerCase();
    var inName = nm.indexOf(ql) !== -1;
    var inCat = p.cat && p.cat.indexOf(qcat) !== -1;
    if (!inName && !inCat) continue;
    var dist = Math.sqrt(Math.pow(p.lat - center.lat, 2) + Math.pow(p.lng - center.lng, 2));
    var score = (p.conf || 0) - dist * 2 +
      (nm.indexOf(ql) === 0 ? 0.2 : 0) + (inName ? 0.1 : 0);
    out.push({ p: p, s: score });
  }
  out.sort(function(x, y) { return y.s - x.s; });
  return out.slice(0, 6).map(function(x) {
    return {
      properties: { name: x.p.name, street: x.p.addr || '', city: '' },
      geometry: { coordinates: [x.p.lng, x.p.lat] },
      _places: true
    };
  });
}

// nearby radius follows the viewport: half the visible diagonal,
// clamped to something Overpass-friendly
function viewportRadius() {
  var b = map.getBounds();
  var ne = b.getNorthEast();
  var sw = b.getSouthWest();
  var latM = (ne.lat - sw.lat) * 111000;
  var lngM = (ne.lng - sw.lng) * 111000 * Math.cos(map.getCenter().lat * Math.PI / 180);
  var r = Math.round(Math.sqrt(latM * latM + lngM * lngM) / 4);
  return Math.max(500, Math.min(8000, r));
}

function searchLabel(props) {
  var bits = [];
  if (props.name) bits.push(props.name);
  var addr = [props.street, props.housenumber].filter(Boolean).join(' ');
  if (addr && addr !== props.name) bits.push(addr);
  if (props.city && props.city !== props.name) bits.push(props.city);
  else if (props.country) bits.push(props.country);
  return bits;
}

function hideSearchResults() {
  document.getElementById('search-results').classList.add('hidden');
}

async function runSearch(q) {
  var box = document.getElementById('search-results');
  var c = map.getCenter();
  var tag = nearbyTag(q);
  var url;
  if (tag) {
    url = API + '/geocode?kind=nearby&tag=' + encodeURIComponent(tag) +
      '&lat=' + c.lat.toFixed(4) + '&lon=' + c.lng.toFixed(4) +
      '&radius=' + viewportRadius();
  } else {
    url = API + '/geocode?kind=autocomplete&q=' + encodeURIComponent(q) +
      '&lat=' + c.lat.toFixed(4) + '&lon=' + c.lng.toFixed(4);
  }
  box.innerHTML = '<div class="search-empty"><span class="search-spin"></span>Searching\u2026</div>';
  box.classList.remove('hidden');
  var data;
  try {
    data = await fetch(url).then(function(r) { return r.json(); });
  } catch(e) {
    box.innerHTML = '<div class="search-empty">Search failed</div>';
    return;
  }
  // stale response guard: only render if the input still matches
  if (document.getElementById('search-input').value.trim() !== q) return;
  var feats = tag ? overpassToFeatures(data, c) : ((data && data.features) || []);
  // imported-places hits rank first (confidence-scored, local)
  var doc = await placesFor(c);
  if (doc) {
    if (document.getElementById('search-input').value.trim() !== q) return;
    var local = searchPlaces(doc, q, c);
    var seen = {};
    local.forEach(function(f) { seen[f.properties.name.toLowerCase()] = true; });
    feats = local.concat(feats.filter(function(f) {
      return !seen[((f.properties || {}).name || '').toLowerCase()];
    })).slice(0, 12);
  }
  if (!feats.length) {
    box.innerHTML = '<div class="search-empty">No results</div>';
    box.classList.remove('hidden');
    return;
  }
  box.innerHTML = feats.map(function(f, i) {
    var bits = searchLabel(f.properties || {});
    return '<div class="search-hit' + (f._places ? ' search-hit-db' : '') + '" data-i="' + i + '">' +
      '<div class="search-hit-name">' + esc(bits[0] || '?') + '</div>' +
      (bits.length > 1 ? '<div class="search-hit-sub">' + esc(bits.slice(1).join(', ')) + '</div>' : '') +
    '</div>';
  }).join('');
  box.classList.remove('hidden');
  box.querySelectorAll('.search-hit').forEach(function(row) {
    row.onclick = function() {
      var f = feats[parseInt(row.getAttribute('data-i'), 10)];
      if (!f || !f.geometry) return;
      pickSearchHit(f);
    };
  });
}

// normalize Overpass elements into Photon-feature shape, nearest first
function overpassToFeatures(data, center) {
  var els = (data && data.elements) || [];
  var feats = els.map(function(el) {
    var lat = el.lat != null ? el.lat : (el.center && el.center.lat);
    var lon = el.lon != null ? el.lon : (el.center && el.center.lon);
    if (lat == null) return null;
    var t = el.tags || {};
    return {
      properties: {
        name: t.name || t.brand || '(unnamed)',
        street: [t['addr:street'], t['addr:housenumber']].filter(Boolean).join(' '),
        city: t['addr:city'] || ''
      },
      geometry: { coordinates: [lon, lat] },
      _d: Math.pow(lat - center.lat, 2) + Math.pow(lon - center.lng, 2)
    };
  }).filter(Boolean);
  feats.sort(function(a, b) { return a._d - b._d; });
  return feats.slice(0, 12);
}

function pickSearchHit(f) {
  var lng = f.geometry.coordinates[0];
  var lat = f.geometry.coordinates[1];
  var props = f.properties || {};
  var name = props.name || [props.street, props.housenumber].filter(Boolean).join(' ') || 'place';
  hideSearchResults();
  document.getElementById('search-input').value = '';
  map.flyTo({ center: [lng, lat], zoom: Math.max(map.getZoom(), 16) });
  if (searchMarker) { searchMarker.remove(); }
  searchMarker = new maplibregl.Marker({ color: '#16a085' })
    .setLngLat([lng, lat])
    .addTo(map);
  openPopupAt([lng, lat],
    popupDom(name, searchLabel(props).slice(1).join(', '), null, 'add pin', function() {
      openPinForm(null, lat, lng);
      document.getElementById('pin-name').value = name;
    }));
}

// -- Schedule view --

var schedHidden = { fixed: false, tentative: false };
var SCHED_H0 = 7;    // first hour shown
var SCHED_H1 = 24;   // last
var SCHED_PX = 44;   // px per hour
var editingSchedId = null;

function isoDay(d) {
  return d.getFullYear() + '-' +
    String(d.getMonth() + 1).padStart(2, '0') + '-' +
    String(d.getDate()).padStart(2, '0');
}

function tripDayList() {
  var ds = (itinerary && itinerary.dates) || {};
  var start = ds.start, end = ds.end;
  if (!start || !end) {
    // derive from schedule entries, else a week from today
    var dates = Object.values((itinerary && itinerary.schedule) || {})
      .map(function(s) { return s.date; }).filter(Boolean).sort();
    start = start || dates[0];
    end = end || dates[dates.length - 1];
    if (!start) {
      var t = new Date();
      start = isoDay(t);
      end = isoDay(new Date(t.getTime() + 6 * 864e5));
    }
    end = end || start;
  }
  var out = [];
  var d = new Date(start + 'T12:00:00');
  var stop = new Date(end + 'T12:00:00');
  while (d <= stop && out.length < 31) {
    out.push(isoDay(d));
    d.setDate(d.getDate() + 1);
  }
  return out;
}

function minutes(t) {
  if (!t) return null;
  var m = /^(\d{1,2}):(\d{2})$/.exec(t);
  return m ? (+m[1]) * 60 + (+m[2]) : null;
}

function schedCat(entry) {
  if (entry.pin && itinerary.pins && itinerary.pins[entry.pin]) {
    return itinerary.pins[entry.pin].cat;
  }
  return '';
}

function schedColor(entry) {
  var cat = schedCat(entry);
  return cat ? catColor(cat) : '#5b6470';
}

function renderSched() {
  if (!itinerary) return;
  document.getElementById('sched-title').textContent = itinerary.name || 'Schedule';
  document.getElementById('sched-tz').textContent = itinerary.tz || '';
  renderSchedLegend();
  renderEvents();
  var days = tripDayList();
  var sched = itinerary.schedule || {};
  var wrap = document.getElementById('sched-days');
  wrap.textContent = '';

  // uniform all-day strip height across every column
  var maxAllday = 0;
  days.forEach(function(date) {
    var n = Object.keys(sched).filter(function(id) {
      return sched[id].date === date && minutes(sched[id].start) === null;
    }).length;
    if (n > maxAllday) maxAllday = n;
  });
  var alldayH = maxAllday ? maxAllday * 27 + 6 : 0;
  var bodyH = (SCHED_H1 - SCHED_H0) * SCHED_PX;
  var todayIso = isoDay(new Date());

  // left time gutter
  var gutter = document.createElement('div');
  gutter.className = 'sched-gutter';
  var ghead = document.createElement('div');
  ghead.className = 'sched-col-head';
  ghead.innerHTML = '&nbsp;';
  gutter.appendChild(ghead);
  var gall = document.createElement('div');
  gall.className = 'sched-allday';
  gall.style.height = alldayH + 'px';
  gutter.appendChild(gall);
  var gbody = document.createElement('div');
  gbody.className = 'sched-gutter-body';
  gbody.style.height = bodyH + 'px';
  for (var hh = SCHED_H0 + 1; hh < SCHED_H1; hh++) {
    var gl = document.createElement('div');
    gl.className = 'sched-gutter-hour';
    gl.style.top = ((hh - SCHED_H0) * SCHED_PX - 7) + 'px';
    gl.textContent = hh + ':00';
    gbody.appendChild(gl);
  }
  gutter.appendChild(gbody);
  wrap.appendChild(gutter);

  // week bands: subtle alternating tint, weeks starting Monday
  var firstDate = new Date(days[0] + 'T12:00:00');
  var firstMonday = new Date(firstDate);
  firstMonday.setDate(firstMonday.getDate() - ((firstMonday.getDay() + 6) % 7));

  days.forEach(function(date) {
    var dd = new Date(date + 'T12:00:00');
    var week = Math.floor((dd - firstMonday) / (7 * 864e5));
    var col = document.createElement('div');
    col.className = 'sched-col' + (date === todayIso ? ' today' : '') +
      (week % 2 === 1 ? ' wk-alt' : '');
    var d = new Date(date + 'T00:00:00');
    var head = document.createElement('div');
    head.className = 'sched-col-head';
    head.innerHTML = '<span class="sched-dow">' +
      d.toLocaleDateString(undefined, { weekday: 'short' }) +
      '</span> <span class="sched-dom">' + d.getDate() + '</span>';
    col.appendChild(head);

    var allday = document.createElement('div');
    allday.className = 'sched-allday';
    allday.style.height = alldayH + 'px';
    col.appendChild(allday);

    var body = document.createElement('div');
    body.className = 'sched-col-body';
    body.style.height = bodyH + 'px';
    body.addEventListener('click', function(e) {
      if (e.target !== body) return;
      var rect = body.getBoundingClientRect();
      var hour = Math.floor((e.clientY - rect.top) / SCHED_PX) + SCHED_H0;
      openSchedForm(null, date, (hour < 10 ? '0' : '') + hour + ':00');
    });

    Object.keys(sched).forEach(function(id) {
      var s = sched[id];
      if (s.date !== date) return;
      var scat = schedCat(s);
      if (scat && hiddenCats[scat]) return;
      if (schedHidden[s.status === 'tentative' ? 'tentative' : 'fixed']) return;
      var m0 = minutes(s.start);
      var el = document.createElement('div');
      el.className = 'sched-block' + (s.status === 'tentative' ? ' tentative' : '');
      el.style.setProperty('--sc', schedColor(s));
      var label = document.createElement('div');
      label.className = 'sched-block-title';
      label.textContent = s.title || id;
      el.appendChild(label);
      if (s.start) {
        var tl = document.createElement('div');
        tl.className = 'sched-block-time';
        tl.textContent = s.start + (s.end ? '\u2013' + s.end : '');
        el.appendChild(tl);
      }
      el.addEventListener('click', function(e) {
        e.stopPropagation();
        openSchedView(id);
      });
      if (m0 === null) {
        allday.appendChild(el);
      } else {
        var m1 = minutes(s.end);
        var top = ((m0 / 60) - SCHED_H0) * SCHED_PX;
        var hgt = m1 !== null ? Math.max(24, ((m1 - m0) / 60) * SCHED_PX - 2) : 32;
        el.style.top = Math.max(0, top) + 'px';
        el.style.height = hgt + 'px';
        el.classList.add('timed');
        body.appendChild(el);
      }
    });
    col.appendChild(body);
    wrap.appendChild(col);
  });
}

function schedModalMode(view) {
  document.getElementById('sched-view').classList.toggle('hidden', !view);
  document.getElementById('sched-form-fields').classList.toggle('hidden', view);
}

function openSchedView(id) {
  editingSchedId = id;
  var s = (itinerary.schedule || {})[id];
  if (!s) return;
  document.getElementById('sv-title').textContent = s.title || id;
  var when;
  if (s.date) {
    var d = new Date(s.date + 'T12:00:00');
    when = d.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' });
    if (s.start) when += ' \u00b7 ' + s.start + (s.end ? '\u2013' + s.end : '');
  } else {
    when = 'Unscheduled \u2014 in the idea bank';
  }
  document.getElementById('sv-when').textContent = when;

  var badges = document.getElementById('sv-badges');
  badges.textContent = '';
  var st = document.createElement('span');
  st.className = 'sv-badge' + (s.status === 'tentative' ? ' tentative' : '');
  st.textContent = s.status || 'fixed';
  badges.appendChild(st);
  if (s.pin && itinerary.pins && itinerary.pins[s.pin]) {
    var pin = itinerary.pins[s.pin];
    var pl = document.createElement('span');
    pl.className = 'sv-badge sv-pin-link';
    pl.style.borderColor = catColor(pin.cat);
    pl.textContent = '\u{1F4CD} ' + pin.name;
    pl.onclick = function() {
      document.getElementById('sched-modal').close();
      focusPin(s.pin);
    };
    badges.appendChild(pl);
  }
  var notes = document.getElementById('sv-notes');
  notes.textContent = s.notes || '';
  notes.classList.toggle('hidden', !s.notes);
  schedModalMode(true);
  document.getElementById('sched-modal').show();
}

// -- Idea bank: schedule entries with no date yet --

function eventCard(id, s) {
  var scat = schedCat(s);
  var card = document.createElement('div');
  card.className = 'idea-card' + (s.status === 'tentative' ? ' tentative' : '');
  var head = document.createElement('div');
  head.className = 'idea-card-head';
  if (scat) {
    var dot = document.createElement('span');
    dot.className = 'pin-dot';
    dot.style.background = catColor(scat);
    head.appendChild(dot);
  }
  var nm = document.createElement('span');
  nm.className = 'idea-card-title';
  nm.textContent = s.title || id;
  head.appendChild(nm);
  card.appendChild(head);
  var when = document.createElement('div');
  when.className = 'idea-card-when';
  if (s.date) {
    var d = new Date(s.date + 'T12:00:00');
    when.textContent = d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }) +
      (s.start ? ' \u00b7 ' + s.start + (s.end ? '\u2013' + s.end : '') : '');
  } else {
    when.textContent = 'unscheduled';
  }
  card.appendChild(when);
  if (s.notes) {
    var no = document.createElement('div');
    no.className = 'idea-card-notes';
    no.textContent = s.notes;
    card.appendChild(no);
  }
  card.onclick = function() { openSchedView(id); };
  return card;
}

function renderEvents() {
  var actual = document.getElementById('actual-list');
  var proposed = document.getElementById('proposed-list');
  if (!actual) return;
  actual.textContent = '';
  proposed.textContent = '';
  var sched = (itinerary && itinerary.schedule) || {};
  var ids = Object.keys(sched).filter(function(id) {
    var scat = schedCat(sched[id]);
    return !(scat && hiddenCats[scat]);
  });
  // chronological; unscheduled sink to the bottom
  ids.sort(function(x, y) {
    var a = sched[x], b = sched[y];
    var ka = (a.date || '9999') + (a.start || '99:99');
    var kb = (b.date || '9999') + (b.start || '99:99');
    return ka < kb ? -1 : ka > kb ? 1 : (a.title || '').localeCompare(b.title || '');
  });
  var na = 0, np = 0;
  ids.forEach(function(id) {
    var s = sched[id];
    if (s.date) { actual.appendChild(eventCard(id, s)); na++; }
    else { proposed.appendChild(eventCard(id, s)); np++; }
  });
  if (!na) actual.innerHTML = '<div class="panel-empty">Nothing on the calendar yet.</div>';
  if (!np) proposed.innerHTML = '<div class="panel-empty">No unscheduled events \u2014 add one, or ask the chat.</div>';
}

function renderSchedLegend() {
  var box = document.getElementById('sched-legend');
  if (!box) return;
  box.textContent = '';
  // colors come from the category chips above; only the fill semantics
  // need explaining here
  ['fixed', 'tentative'].forEach(function(kind) {
    var item = document.createElement('button');
    item.className = 'leg-item leg-toggle' + (schedHidden[kind] ? ' inactive' : '');
    var s = document.createElement('span');
    s.className = 'leg-sample' + (kind === 'tentative' ? ' tentative' : '');
    item.append(s, document.createTextNode(kind));
    item.title = 'Show/hide ' + kind + ' blocks';
    item.onclick = function() {
      schedHidden[kind] = !schedHidden[kind];
      renderSched();
    };
    box.appendChild(item);
  });
}

function openSchedForm(id, date, start) {
  editingSchedId = id;
  schedModalMode(false);
  var s = id ? ((itinerary.schedule || {})[id] || {}) : {};
  document.getElementById('sched-form-title').textContent = id ? 'Edit schedule' : 'Add to schedule';
  document.getElementById('sched-delete').classList.toggle('hidden', !id);
  document.getElementById('sched-name').value = s.title || '';
  document.getElementById('sched-date').value = s.date || date || '';
  document.getElementById('sched-start').value = s.start || start || '';
  document.getElementById('sched-end').value = s.end || '';
  document.getElementById('sched-status').value = s.status || 'fixed';
  document.getElementById('sched-notes').value = s.notes || '';
  document.getElementById('sched-form-status').textContent = '';
  var sel = document.getElementById('sched-pin');
  var pins = itinerary.pins || {};
  sel.innerHTML = '<option value="">no linked pin</option>' +
    Object.keys(pins).map(function(pid) {
      var selid = s.pin === pid ? ' selected' : '';
      return '<option value="' + pid + '"' + selid + '>' + esc(pins[pid].name) + '</option>';
    }).join('');
  document.getElementById('sched-modal').show();
}

async function putDoc() {
  var r = await fetch(API + '/i/' + currentId, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(itinerary)
  });
  if (!r.ok) throw new Error('save failed');
}

async function saveSched() {
  var title = document.getElementById('sched-name').value.trim();
  var date = document.getElementById('sched-date').value;
  if (!title) {
    document.getElementById('sched-form-status').textContent = 'Title required';
    return;
  }
  var id = editingSchedId ||
    ('s-' + title.toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 24) + '-' + Date.now().toString(36).slice(-4));
  itinerary.schedule = itinerary.schedule || {};
  itinerary.schedule[id] = {
    title: title,
    date: date,
    start: document.getElementById('sched-start').value || '',
    end: document.getElementById('sched-end').value || '',
    status: document.getElementById('sched-status').value,
    pin: document.getElementById('sched-pin').value || '',
    notes: document.getElementById('sched-notes').value.trim()
  };
  try {
    await putDoc();
    renderSched();
    renderEvents();
    document.getElementById('sched-modal').close();
  } catch(e) {
    document.getElementById('sched-form-status').textContent = 'Save failed';
  }
}

async function deleteSched() {
  if (!editingSchedId) return;
  delete (itinerary.schedule || {})[editingSchedId];
  try {
    await putDoc();
    renderSched();
    renderEvents();
    document.getElementById('sched-modal').close();
  } catch(e) {
    document.getElementById('sched-form-status').textContent = 'Delete failed';
  }
}

// -- Zones --

function renderZones() {
  if (!mapReady) return;
  var feats = [];
  if (itinerary && zonesVisible) {
    var zones = itinerary.zones || {};
    Object.keys(zones).forEach(function(id) {
      var zone = zones[id];
      if (hiddenCats[zone.cat]) return;
      if (!zone.points || zone.points.length < 3) return;
      var ring = zone.points.map(function(p) { return [p[1], p[0]]; });
      ring.push(ring[0]);
      feats.push({
        type: 'Feature',
        properties: { id: id, color: catColor(zone.cat) },
        geometry: { type: 'Polygon', coordinates: [ring] }
      });
    });
  }
  map.getSource('zones').setData({ type: 'FeatureCollection', features: feats });
}

// -- Zone Drawing --

function startDraw() {
  if (!currentId || drawing) return;
  drawing = true;
  drawPoints = [];
  document.getElementById('btn-zone').classList.add('active');
  document.getElementById('draw-bar').classList.remove('hidden');
  if (activeView !== 'map') setView('map');
}

function cancelDraw() {
  drawing = false;
  drawPoints = [];
  updateDrawLayer();
  document.getElementById('btn-zone').classList.remove('active');
  document.getElementById('draw-bar').classList.add('hidden');
}

function updateDrawLayer() {
  if (!mapReady) return;
  var feats = [];
  if (drawPoints.length) {
    var ring = drawPoints.map(function(p) { return [p[1], p[0]]; });
    ring.push(ring[0]);
    feats.push({ type: 'Feature', properties: {},
      geometry: { type: 'Polygon', coordinates: [ring] } });
  }
  map.getSource('draw').setData({ type: 'FeatureCollection', features: feats });
}

function finishDraw() {
  if (drawPoints.length < 3) {
    document.getElementById('draw-hint').textContent = 'Need at least 3 points';
    return;
  }
  openZoneForm(null);
}

// -- Zone Form --

function openZoneForm(id) {
  editingZoneId = id;
  var zone = id && itinerary ? (itinerary.zones || {})[id] : null;
  document.getElementById('zone-form-title').textContent = zone ? 'Edit Zone' : 'Add Zone';
  document.getElementById('zone-delete').classList.toggle('hidden', !zone);
  document.getElementById('zone-name').value = zone ? zone.name || '' : '';
  document.getElementById('zone-desc').value = zone ? zone.desc || '' : '';
  document.getElementById('zone-notes').value = zone ? zone.notes || '' : '';
  document.getElementById('zone-form-status').textContent = '';

  var sel = document.getElementById('zone-cat');
  var c = cats();
  sel.innerHTML = Object.keys(c).map(function(key) {
    var selected = (zone && zone.cat === key) ? ' selected' : '';
    return '<option value="' + key + '"' + selected + '>' + c[key].label + '</option>';
  }).join('');

  document.getElementById('zone-modal').show();
}

function closeZoneForm() {
  document.getElementById('zone-modal').close();
  editingZoneId = null;
}

async function saveZone() {
  var name = document.getElementById('zone-name').value.trim();
  if (!name) { document.getElementById('zone-form-status').textContent = 'Name is required'; return; }

  var existing = editingZoneId && itinerary ? (itinerary.zones || {})[editingZoneId] : null;
  var points = existing ? existing.points : drawPoints;
  if (!points || points.length < 3) {
    document.getElementById('zone-form-status').textContent = 'Zone has no outline';
    return;
  }

  var zone = {
    name: name,
    points: points,
    cat: document.getElementById('zone-cat').value,
    desc: document.getElementById('zone-desc').value.trim(),
    notes: document.getElementById('zone-notes').value.trim()
  };

  var zoneId = editingZoneId || ('zone-' + Date.now().toString(36));

  try {
    var r = await fetch(API + '/i/' + currentId + '/zone/' + zoneId, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(zone)
    });
    if (!r.ok) throw new Error('Save failed');
    itinerary = await r.json();
    cancelDraw();
    renderZones();
    renderTrip();
    closeZoneForm();
  } catch(e) {
    document.getElementById('zone-form-status').textContent = 'Save failed';
  }
}

async function deleteZone() {
  if (!editingZoneId) return;
  if (!confirm('Delete this zone?')) return;
  try {
    var r = await fetch(API + '/i/' + currentId + '/zone/' + editingZoneId, { method: 'DELETE' });
    if (!r.ok) throw new Error('Delete failed');
    itinerary = await r.json();
    renderZones();
    renderTrip();
    closeZoneForm();
  } catch(e) {
    document.getElementById('zone-form-status').textContent = 'Delete failed';
  }
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

  container.querySelectorAll('.filter-btn[data-cat]').forEach(function(btn) {
    btn.title = 'Click: toggle. Shift-click: only this category.';
    btn.onclick = function(e) {
      var cat = btn.getAttribute('data-cat');
      if (e.shiftKey) {
        // solo this category; shift-click again restores all
        var keys = Object.keys(cats());
        var isSolo = !hiddenCats[cat] && keys.every(function(k) {
          return k === cat || hiddenCats[k];
        });
        hiddenCats = {};
        if (!isSolo) {
          keys.forEach(function(k) { if (k !== cat) hiddenCats[k] = true; });
        }
        renderFilters();
      } else {
        if (hiddenCats[cat]) { delete hiddenCats[cat]; btn.classList.remove('inactive'); }
        else { hiddenCats[cat] = true; btn.classList.add('inactive'); }
      }
      renderMarkers();
      renderZones();
      renderPanel();
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

  document.getElementById('pin-modal').show();
}

function closePinForm() {
  document.getElementById('pin-modal').close();
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
    renderPanel();
        closePinForm();
    if (!editingPinId && activeView === 'map') {
      map.flyTo({ center: [lng, lat], zoom: Math.max(map.getZoom(), 14) });
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
    renderPanel();
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
  document.getElementById('map-wrap').classList.toggle('hidden', view === 'sched');
  document.getElementById('sched-wrap').classList.toggle('hidden', view !== 'sched');
  ['map', 'sched'].forEach(function(v) {
    var b = document.getElementById('btn-' + v);
    if (b) b.classList.toggle('active', view === v);
  });
  // map-only actions
  document.getElementById('btn-zone').classList.toggle('hidden', view !== 'map');
  document.getElementById('btn-add').classList.toggle('hidden', view !== 'map');
  if (view === 'sched' && drawing) cancelDraw();
  syncHash();
  if (view === 'sched') renderSched();
  if (view === 'map') setTimeout(function() { map.resize(); }, 50);
}

// -- Events --

function bindEvents() {
  document.getElementById('btn-map').onclick = function() { setView('map'); };
  document.getElementById('btn-sched').onclick = function() { setView('sched'); };
  document.getElementById('btn-zones').onclick = function() {
    zonesVisible = !zonesVisible;
    this.classList.toggle('off', !zonesVisible);
    renderZones();
  };
  document.getElementById('btn-proj').onclick = function() {
    flatProjection = !flatProjection;
    map.setProjection({ type: flatProjection ? 'mercator' : 'globe' });
    this.classList.toggle('active', !flatProjection);
  };
  document.getElementById('idea-add').onclick = function() {
    if (currentId) openSchedForm(null, '', '');
  };
  document.getElementById('sv-edit').onclick = function() {
    if (editingSchedId) openSchedForm(editingSchedId);
  };
  document.getElementById('sched-save').onclick = saveSched;
  document.getElementById('sched-delete').onclick = deleteSched;
  document.getElementById('sched-modal').addEventListener('md-close', function() { editingSchedId = null; });
  document.getElementById('btn-add').onclick = function() {
    if (!currentId) { openNewItinerary(); return; }
    var center = map.getCenter();
    openPinForm(null, center.lat, center.lng);
  };
  var searchInput = document.getElementById('search-input');
  searchInput.oninput = function() {
    var q = this.value.trim();
    clearTimeout(searchTimer);
    if (q.length < 3) { hideSearchResults(); return; }
    searchTimer = setTimeout(function() { runSearch(q); }, 300);
  };
  searchInput.onkeydown = function(e) {
    if (e.key === 'Escape') { hideSearchResults(); this.blur(); }
  };
  document.addEventListener('click', function(e) {
    if (!document.getElementById('map-search').contains(e.target)) hideSearchResults();
  });
  document.getElementById('menu-new').onclick = function() {
    document.getElementById('itin-menu').close();
    openNewItinerary();
  };
  document.getElementById('form-save').onclick = savePin;
  document.getElementById('form-delete').onclick = deletePin;
  document.getElementById('pin-modal').addEventListener('md-close', function() { editingPinId = null; });
  var split = document.getElementById('panel-split');
  document.getElementById('panel-collapse').onclick = function() { split.collapse(); };
  split.addEventListener('sv-resize', function() { map.resize(); });
  split.addEventListener('sv-collapse', function() { map.resize(); });
  document.getElementById('panel-search').oninput = function() {
    panelQuery = this.value.trim();
    renderPanel();
  };
  document.getElementById('btn-zone').onclick = function() {
    if (drawing) { cancelDraw(); return; }
    startDraw();
  };
  document.getElementById('draw-finish').onclick = finishDraw;
  document.getElementById('draw-cancel').onclick = cancelDraw;
  document.getElementById('about-edit').onclick = function() {
    if (!currentId) return;
    document.getElementById('about-text').value = (itinerary && itinerary.desc) || '';
    document.getElementById('about-status').textContent = '';
    document.getElementById('about-modal').show();
  };
  document.getElementById('about-save').onclick = saveAbout;
  document.getElementById('todo-new').addEventListener('keydown', async function(e) {
    if (e.key !== 'Enter') return;
    var text = this.value.trim();
    if (!text || !currentId) return;
    itinerary.todos = itinerary.todos || {};
    itinerary.todos['t-' + Date.now().toString(36)] = { text: text, done: false };
    this.value = '';
    try { await putDoc(); } catch(err) {}
    renderTodos();
  });
  document.getElementById('zone-save').onclick = saveZone;
  document.getElementById('zone-delete').onclick = deleteZone;
  document.getElementById('zone-modal').addEventListener('md-close', function() { editingZoneId = null; });
}

function esc(s) {
  if (!s) return '';
  var d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

init();
