// routes: click waypoints, the route snaps along roads. Routing is
// done from the browser against public engines — BRouter (foot/bike)
// and the OSRM demo (driving) — the ship only stores saved routes.
var API = '/grubbery/routes';

var map = null;
var waypoints = [];   // [{lng, lat, marker}]
var geometry = null;  // routed GeoJSON LineString coords
var distance = 0;     // meters
var profile = localStorage.getItem('routes-prof') || 'foot';
var routing = false;
var routeDirty = false;
var currentName = null;

var PROFILES = {
  foot: { label: 'run', brouter: 'hiking-mountain' },
  bike: { label: 'bike', brouter: 'trekking' },
  car:  { label: 'drive' }
};

function $(id) { return document.getElementById(id); }

// ── map ──
function initMap() {
  map = new maplibregl.Map({
    container: 'map',
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
          attribution: '© OpenStreetMap'
        }
      },
      layers: [{ id: 'osm', type: 'raster', source: 'osm' }]
    },
    center: [-71.06, 42.36],
    zoom: 12
  });
  map.addControl(new maplibregl.NavigationControl(), 'top-right');
  map.on('load', function() {
    map.addSource('route', { type: 'geojson', data: emptyLine() });
    map.addLayer({
      id: 'route-line', type: 'line', source: 'route',
      paint: { 'line-color': '#3d6b52', 'line-width': 4, 'line-opacity': 0.85 }
    });
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(function(p) {
        if (!waypoints.length) map.setCenter([p.coords.longitude, p.coords.latitude]);
      }, function() {});
    }
  });
  map.on('click', function(e) { addWaypoint(e.lngLat.lng, e.lngLat.lat); });
}
function emptyLine() {
  return { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } };
}

// ── waypoints ──
function addWaypoint(lng, lat) {
  var el = document.createElement('div');
  el.className = 'wp' + (waypoints.length === 0 ? ' wp-start' : '');
  var marker = new maplibregl.Marker({ element: el, draggable: true })
    .setLngLat([lng, lat]).addTo(map);
  var wp = { lng: lng, lat: lat, marker: marker };
  marker.on('dragend', function() {
    var p = marker.getLngLat();
    wp.lng = p.lng; wp.lat = p.lat;
    reroute();
  });
  waypoints.push(wp);
  reroute();
}
function undo() {
  var wp = waypoints.pop();
  if (wp) wp.marker.remove();
  reroute();
}
function clearAll() {
  waypoints.forEach(function(w) { w.marker.remove(); });
  waypoints = [];
  currentName = null;
  reroute();
}
function outAndBack() {
  if (waypoints.length < 2) return;
  var back = waypoints.slice(0, -1).reverse();
  back.forEach(function(w) { addWaypointSilent(w.lng, w.lat); });
  reroute();
}
function addWaypointSilent(lng, lat) {
  var el = document.createElement('div');
  el.className = 'wp';
  var marker = new maplibregl.Marker({ element: el, draggable: true })
    .setLngLat([lng, lat]).addTo(map);
  var wp = { lng: lng, lat: lat, marker: marker };
  marker.on('dragend', function() {
    var p = marker.getLngLat();
    wp.lng = p.lng; wp.lat = p.lat;
    reroute();
  });
  waypoints.push(wp);
}

// ── routing ──
var rerouteSeq = 0;
function reroute() {
  routeDirty = true;
  var seq = ++rerouteSeq;
  if (waypoints.length < 2) {
    geometry = null; distance = 0;
    if (map.getSource('route')) map.getSource('route').setData(emptyLine());
    renderStats();
    return;
  }
  setStatus('routing…');
  fetchRoute(waypoints).then(function(res) {
    if (seq !== rerouteSeq) return;  // stale — a newer edit superseded us
    geometry = res.coords;
    distance = res.distance;
    map.getSource('route').setData({
      type: 'Feature', geometry: { type: 'LineString', coordinates: res.coords }
    });
    setStatus('');
    renderStats();
  }).catch(function(e) {
    if (seq !== rerouteSeq) return;
    // straight lines as honest fallback so editing can continue
    var coords = waypoints.map(function(w) { return [w.lng, w.lat]; });
    geometry = coords;
    distance = coords.reduce(function(acc, c, i) {
      return i ? acc + haversine(coords[i - 1], c) : 0;
    }, 0);
    map.getSource('route').setData({
      type: 'Feature', geometry: { type: 'LineString', coordinates: coords }
    });
    setStatus('routing unavailable — straight lines');
    renderStats();
  });
}
function fetchRoute(wps) {
  var pts = wps.map(function(w) { return w.lng + ',' + w.lat; });
  if (profile === 'car') {
    var url = 'https://router.project-osrm.org/route/v1/driving/' +
      pts.join(';') + '?overview=full&geometries=geojson';
    return fetch(url).then(function(r) { return r.json(); }).then(function(j) {
      if (!j.routes || !j.routes.length) throw new Error('no route');
      return { coords: j.routes[0].geometry.coordinates, distance: j.routes[0].distance };
    });
  }
  var url = 'https://brouter.de/brouter?lonlats=' + pts.join('|') +
    '&profile=' + PROFILES[profile].brouter + '&alternativeidx=0&format=geojson';
  return fetch(url).then(function(r) { return r.json(); }).then(function(j) {
    var f = j.features && j.features[0];
    if (!f) throw new Error('no route');
    return {
      coords: f.geometry.coordinates.map(function(c) { return [c[0], c[1]]; }),
      distance: parseFloat((f.properties || {})['track-length'] || '0')
    };
  });
}
function haversine(a, b) {
  var r = Math.PI / 180, R = 6371000;
  var dLat = (b[1] - a[1]) * r, dLng = (b[0] - a[0]) * r;
  var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(a[1] * r) * Math.cos(b[1] * r) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * R * Math.asin(Math.sqrt(h));
}

// ── stats + status ──
function renderStats() {
  var km = distance / 1000;
  $('dist').textContent = waypoints.length < 2 ? '—'
    : km.toFixed(2) + ' km · ' + (km * 0.621371).toFixed(2) + ' mi';
}
function setStatus(t) { $('status').textContent = t; }

// ── save / load ──
function save() {
  if (waypoints.length < 2) return;
  var name = prompt('route name', currentName || '');
  if (!name) return;
  var body = {
    name: name,
    profile: profile,
    waypoints: waypoints.map(function(w) { return [w.lng, w.lat]; }),
    geometry: geometry,
    distance: distance,
    at: new Date().toISOString()
  };
  fetch(API + '/save', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) {
    if (!r.ok) { alert('save failed'); return; }
    currentName = name;
    loadList();
  });
}
function loadList() {
  fetch(API + '/list').then(function(r) { return r.json(); }).then(function(routes) {
    var box = $('route-list');
    box.innerHTML = '';
    routes.sort(function(a, b) { return (a.name || '') < (b.name || '') ? -1 : 1; });
    routes.forEach(function(rt) {
      var row = document.createElement('div');
      row.className = 'r-row';
      var name = document.createElement('span');
      name.className = 'r-name';
      name.textContent = rt.name;
      var dist = document.createElement('span');
      dist.className = 'r-dist';
      dist.textContent = (rt.distance / 1000).toFixed(1) + ' km';
      var del = document.createElement('button');
      del.className = 'r-del';
      del.textContent = '×';
      del.onclick = function(e) {
        e.stopPropagation();
        fetch(API + '/del', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ name: rt.name })
        }).then(loadList);
      };
      row.append(name, dist, del);
      row.onclick = function() { loadRoute(rt); };
      box.appendChild(row);
    });
    if (!routes.length) box.innerHTML = '<div class="empty">no saved routes</div>';
  });
}
function loadRoute(rt) {
  clearAll();
  currentName = rt.name;
  profile = rt.profile || 'foot';
  localStorage.setItem('routes-prof', profile);
  renderProfile();
  (rt.waypoints || []).forEach(function(c) { addWaypointSilent(c[0], c[1]); });
  if (waypoints.length) {
    var b = rt.waypoints.reduce(function(acc, c) { return acc.extend(c); },
      new maplibregl.LngLatBounds(rt.waypoints[0], rt.waypoints[0]));
    map.fitBounds(b, { padding: 60 });
  }
  reroute();
}

// ── gpx export ──
function exportGpx() {
  if (!geometry || geometry.length < 2) return;
  var pts = geometry.map(function(c) {
    return '<trkpt lat="' + c[1] + '" lon="' + c[0] + '"/>';
  }).join('\n');
  var gpx = '<?xml version="1.0"?>\n<gpx version="1.1" creator="routes nexus" ' +
    'xmlns="http://www.topografix.com/GPX/1/1">\n<trk><name>' +
    (currentName || 'route') + '</name><trkseg>\n' + pts + '\n</trkseg></trk>\n</gpx>';
  var a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([gpx], { type: 'application/gpx+xml' }));
  a.download = (currentName || 'route') + '.gpx';
  a.click();
}

// ── controls ──
function renderProfile() {
  Array.prototype.forEach.call(document.querySelectorAll('.prof'), function(b) {
    b.classList.toggle('active', b.getAttribute('data-prof') === profile);
  });
}
Array.prototype.forEach.call(document.querySelectorAll('.prof'), function(b) {
  b.onclick = function() {
    profile = b.getAttribute('data-prof');
    localStorage.setItem('routes-prof', profile);
    renderProfile();
    reroute();
  };
});
$('undo').onclick = undo;
$('clear').onclick = clearAll;
$('oab').onclick = outAndBack;
$('save').onclick = save;
$('gpx').onclick = exportGpx;

renderProfile();
initMap();
loadList();
