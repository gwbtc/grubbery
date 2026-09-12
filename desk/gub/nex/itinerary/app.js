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
    // a click on a zone opens its popup instead of the pin form
    var hits = mapReady ? map.queryRenderedFeatures(e.point, { layers: ['zones-fill'] }) : [];
    if (hits.length) {
      var zid = hits[0].properties.id;
      var zone = (itinerary.zones || {})[zid];
      if (zone) {
        openPopupAt([e.lngLat.lng, e.lngLat.lat],
          popupDom(zone.name, zone.desc, null, 'edit', function() { openZoneForm(zid); }));
      }
      return;
    }
    openPinForm(null, e.lngLat.lat, e.lngLat.lng);
  });
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
function popupDom(name, desc, from, action, onAction) {
  var d = document.createElement('div');
  var n = document.createElement('div'); n.className = 'popup-name'; n.textContent = name || '';
  d.appendChild(n);
  if (desc) { var ds = document.createElement('div'); ds.className = 'popup-desc'; ds.textContent = desc; d.appendChild(ds); }
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
  renderMenu();
  renderFilters();
  renderMarkers();
  renderZones();
  renderTrip();
  renderPanel();
  renderList();
  renderGlobe();

  if (itinerary.center && itinerary.center.length === 2) {
    map.jumpTo({ center: [itinerary.center[1], itinerary.center[0]], zoom: itinerary.zoom || 13 });
  }
}

function renderEmpty() {
  document.getElementById('map-name').textContent = 'Itinerary';
  document.getElementById('pin-list').innerHTML =
    '<div class="empty-state">No itineraries yet. Click + to create one.</div>';
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
        popupDom(pin.name, pin.desc, pin.from, 'edit', function() { openPinForm(id); }));
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
      return '<div class="panel-row" data-id="' + id + '">' +
        '<div class="pin-dot" style="background:' + catColor(pin.cat) + '"></div>' +
        '<div class="panel-row-text">' +
          '<div class="panel-row-name">' + esc(pin.name) + '</div>' +
          (pin.desc ? '<div class="panel-row-desc">' + esc(pin.desc) + '</div>' : '') +
        '</div>' +
      '</div>';
    }).join('');
  }).join('');

  list.querySelectorAll('.panel-row').forEach(function(row) {
    row.onclick = function() { focusPin(row.getAttribute('data-id')); };
  });
}

function focusPin(id) {
  var pin = itinerary && (itinerary.pins || {})[id];
  if (!pin) return;
  if (activeView !== 'map') setView('map');
  map.flyTo({ center: [pin.lng, pin.lat], zoom: Math.max(map.getZoom(), 16) });
  var marker = markers[id];
  if (!marker) return;
  openPopupAt([pin.lng, pin.lat],
    popupDom(pin.name, pin.desc, pin.from, 'edit', function() { openPinForm(id); }));
  var el = marker.getElement();
  if (el) {
    el.classList.remove('pin-pulse');
    void el.offsetWidth;
    el.classList.add('pin-pulse');
    setTimeout(function() { el.classList.remove('pin-pulse'); }, 1800);
  }
}

// -- Trip tab --

function renderTrip() {
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
  var url = API + '/geocode?kind=autocomplete&q=' + encodeURIComponent(q) +
    '&lat=' + c.lat.toFixed(4) + '&lon=' + c.lng.toFixed(4);
  var data;
  try {
    data = await fetch(url).then(function(r) { return r.json(); });
  } catch(e) { return; }
  // stale response guard: only render if the input still matches
  if (document.getElementById('search-input').value.trim() !== q) return;
  var feats = (data && data.features) || [];
  if (!feats.length) {
    box.innerHTML = '<div class="search-empty">No results</div>';
    box.classList.remove('hidden');
    return;
  }
  box.innerHTML = feats.map(function(f, i) {
    var bits = searchLabel(f.properties || {});
    return '<div class="search-hit" data-i="' + i + '">' +
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
  var zoneBtn = '<button class="filter-btn zone-toggle' + (zonesVisible ? '' : ' inactive') +
    '" style="border-color:#555;color:#555">Zones</button>';
  container.innerHTML = zoneBtn + keys.map(function(key) {
    var inactive = hiddenCats[key] ? ' inactive' : '';
    return '<button class="filter-btn' + inactive + '" data-cat="' + key +
      '" style="border-color:' + c[key].color + ';color:' + c[key].color + '">' +
      c[key].label + '</button>';
  }).join('');

  container.querySelector('.zone-toggle').onclick = function() {
    zonesVisible = !zonesVisible;
    this.classList.toggle('inactive', !zonesVisible);
    renderZones();
  };

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
    renderList();
    renderGlobe();
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
  if (view === 'map') setTimeout(function() { map.resize(); }, 50);
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
  document.getElementById('btn-panel').onclick = function() { split.toggle(); };
  split.addEventListener('sv-resize', function() { map.resize(); });
  split.addEventListener('sv-collapse', function(e) {
    document.getElementById('btn-panel').classList.toggle('active', !e.detail.collapsed);
    map.resize();
  });
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
