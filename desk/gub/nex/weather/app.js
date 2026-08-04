var API = '/grubbery/weather';
var ICONS = 'https://cdn.jsdelivr.net/gh/basmilius/weather-icons@dev/production/fill/svg/';

// ── WMO code → meteocon slug (day/night aware) ──
function slugFor(code, isDay) {
  var d = isDay !== 0;
  if (code === 0) return d ? 'clear-day' : 'clear-night';
  if (code === 1 || code === 2) return d ? 'partly-cloudy-day' : 'partly-cloudy-night';
  if (code === 3) return 'overcast';
  if (code === 45 || code === 48) return 'fog';
  if (code >= 51 && code <= 55) return 'drizzle';
  if (code === 56 || code === 57 || code === 66 || code === 67) return 'sleet';
  if (code >= 61 && code <= 65) return 'rain';
  if (code >= 71 && code <= 77) return 'snow';
  if (code >= 80 && code <= 82) return d ? 'partly-cloudy-day-rain' : 'partly-cloudy-night-rain';
  if (code === 85 || code === 86) return d ? 'partly-cloudy-day-snow' : 'partly-cloudy-night-snow';
  if (code === 96 || code === 99) return 'thunderstorms-rain';
  if (code >= 95) return 'thunderstorms';
  return 'cloudy';
}
var WORDS = {
  0: 'clear', 1: 'mostly clear', 2: 'partly cloudy', 3: 'overcast',
  45: 'fog', 48: 'rime fog',
  51: 'light drizzle', 53: 'drizzle', 55: 'heavy drizzle', 56: 'freezing drizzle', 57: 'freezing drizzle',
  61: 'light rain', 63: 'rain', 65: 'heavy rain', 66: 'freezing rain', 67: 'freezing rain',
  71: 'light snow', 73: 'snow', 75: 'heavy snow', 77: 'snow grains',
  80: 'light showers', 81: 'showers', 82: 'violent showers',
  85: 'snow showers', 86: 'snow showers',
  95: 'thunderstorm', 96: 'thunderstorm', 99: 'thunderstorm'
};
function colorFor(code) {
  if (code === 0 || code === 1) return 'linear-gradient(160deg,#3f8ad4,#5aa4e8)';
  if (code === 2) return 'linear-gradient(160deg,#5d8db8,#7ba6c9)';
  if (code === 3) return 'linear-gradient(160deg,#6f7d8c,#8b98a5)';
  if (code === 45 || code === 48) return 'linear-gradient(160deg,#8d949c,#a8adb3)';
  if (code >= 95) return 'linear-gradient(160deg,#43395e,#5b4bb5)';
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return 'linear-gradient(160deg,#7d94b5,#9cb0cc)';
  if (code >= 51) return 'linear-gradient(160deg,#3d5f8f,#54779f)';
  return 'linear-gradient(160deg,#3f8ad4,#5aa4e8)';
}
// temperature → color, for the week range bars (celsius anchors,
// converted when displaying fahrenheit)
function tempColor(t) {
  var c = units === 'f' ? (t - 32) * 5 / 9 : t;
  if (c <= -10) return '#7ea6e0';
  if (c <= 0) return '#8fc1e8';
  if (c <= 10) return '#a8d8b9';
  if (c <= 18) return '#ffe08a';
  if (c <= 26) return '#ffb14e';
  return '#ff7e5a';
}
// data is always metric; units are applied here, at render time
function dT(t) { return units === 'f' ? t * 9 / 5 + 32 : t; }
function dW(s) { return units === 'f' ? s * 0.621371 : s; }
function esc(s) {
  var d = document.createElement('div');
  d.textContent = (s == null) ? '' : String(s);
  return d.innerHTML;
}
function dayName(iso) {
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][new Date(iso + 'T12:00').getDay()];
}
function icon(slug, cls) {
  return '<img class="' + cls + '" src="' + ICONS + slug + '.svg" alt="">';
}
function hhmm(iso) {
  return iso && iso.length >= 16 ? iso.slice(11, 16) : '';
}

// ── hourly chart: temp curve + precip-probability bars, pure SVG ──
function hourlyChart(hourly) {
  var times = hourly.time || [];
  var temps = hourly.temperature_2m || [];
  var probs = hourly.precipitation_probability || [];
  // window: from the current hour, 24 hours
  var start = 0;
  var now = new Date();
  for (var i = 0; i < times.length; i++) {
    if (new Date(times[i]) >= now) { start = Math.max(0, i - 1); break; }
  }
  var T = [], P = [], L = [];
  for (var i = start; i < Math.min(start + 24, times.length); i++) {
    T.push(dT(temps[i])); P.push(probs[i] || 0); L.push(times[i].slice(11, 13));
  }
  if (!T.length) return '';
  var W = 700, H = 120, top = 16, bottom = 34;
  var min = Math.min.apply(null, T), max = Math.max.apply(null, T);
  var span = (max - min) || 1;
  function x(i) { return 10 + i * (W - 20) / (T.length - 1); }
  function y(t) { return top + (H - top - bottom) * (1 - (t - min) / span); }
  var line = T.map(function(t, i) { return (i ? 'L' : 'M') + x(i).toFixed(1) + ',' + y(t).toFixed(1); }).join('');
  var area = line + 'L' + x(T.length - 1).toFixed(1) + ',' + (H - bottom) + 'L' + x(0).toFixed(1) + ',' + (H - bottom) + 'Z';
  var bars = '', labels = '', temps2 = '';
  for (var i = 0; i < T.length; i++) {
    if (P[i] > 4) {
      var bh = (H - top - bottom) * P[i] / 100;
      bars += '<rect x="' + (x(i) - 4) + '" y="' + (H - bottom - bh) + '" width="8" height="' + bh + '" rx="2" fill="rgba(160,220,255,0.45)"/>';
    }
    if (i % 3 === 0) {
      labels += '<text x="' + x(i) + '" y="' + (H - 18) + '" font-size="10" fill="rgba(255,255,255,0.75)" text-anchor="middle">' + L[i] + '</text>';
      temps2 += '<text x="' + x(i) + '" y="' + (y(T[i]) - 7) + '" font-size="10" font-weight="700" fill="#fff" text-anchor="middle">' + Math.round(T[i]) + '°</text>';
    }
    if (P[i] > 30 && i % 3 === 0) {
      labels += '<text x="' + x(i) + '" y="' + (H - 5) + '" font-size="9" fill="rgba(170,225,255,0.9)" text-anchor="middle">' + P[i] + '%</text>';
    }
  }
  return '<svg viewBox="0 0 ' + W + ' ' + H + '">' +
    '<path d="' + area + '" fill="rgba(255,255,255,0.14)"/>' +
    bars +
    '<path d="' + line + '" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>' +
    temps2 + labels + '</svg>';
}

// ── forecast document for one location ──
function buildCard(name, entry) {
  if (!entry || !entry.resp) {
    return '<div class="card" style="background:#8d949c">' +
      '<div class="c-name">' + esc(name) + '</div><div class="c-word">no data yet</div></div>';
  }
  var cur = entry.resp.current || {};
  var daily = entry.resp.daily || {};
  var hourly = entry.resp.hourly || {};
  var code = cur.weather_code || 0;
  var week = '<div class="w-row w-head">' +
    '<span></span><span></span>' +
    '<span class="w-pp">rain</span>' +
    '<span class="w-mid">temperature</span>' +
    '<span class="w-lo">low</span>' +
    '<span class="w-hi">high</span>' +
    '</div>';
  var dates = daily.time || [];
  var lows = (daily.temperature_2m_min || [0]).map(dT);
  var highs = (daily.temperature_2m_max || [1]).map(dT);
  var wmin = Math.min.apply(null, lows);
  var wmax = Math.max.apply(null, highs);
  var wspan = (wmax - wmin) || 1;
  var step = [2, 5, 10, 20].filter(function(s) { return wspan / s <= 5; })[0] || 20;
  var tickXs = [['0.0', Math.round(wmin)]];
  for (var t = Math.ceil(wmin / step) * step; t <= wmax; t += step) {
    var tx = (t - wmin) / wspan * 100;
    if (tx > 7 && tx < 93) tickXs.push([tx.toFixed(1), t]);
  }
  tickXs.push(['100.0', Math.round(wmax)]);
  var grid = tickXs.map(function(tk) {
    return '<span class="w-grid" style="left:' + tk[0] + '%"></span>';
  }).join('');
  for (var i = 0; i < dates.length; i++) {
    var lo = lows[i], hi = highs[i];
    var left = ((lo - wmin) / wspan * 100).toFixed(1), right = ((hi - wmin) / wspan * 100).toFixed(1);
    var pp = (daily.precipitation_probability_max || [])[i];
    week += '<div class="w-row">' +
      '<span class="w-day">' + (i === 0 ? 'today' : dayName(dates[i])) + '</span>' +
      icon(slugFor(daily.weather_code[i], 1), 'w-icon') +
      '<span class="w-pp">' + (pp > 4 ? pp + '%' : '') + '</span>' +
      '<span class="w-bar-track">' + grid +
        '<span class="w-bar" style="left:' + left + '%;width:' + Math.max(3, right - left) +
        '%;background:linear-gradient(90deg,' + tempColor(lo) + ',' + tempColor(hi) + ')"></span></span>' +
      '<span class="w-lo">' + Math.round(lo) + '°</span>' +
      '<span class="w-hi">' + Math.round(hi) + '°</span>' +
      '</div>';
  }
  week += '<div class="w-row w-axis">' +
    '<span></span><span></span><span></span>' +
    '<span class="w-axis-track">' + tickXs.map(function(tk) {
      return '<span class="w-tick" style="left:' + tk[0] + '%">' + tk[1] + '°</span>';
    }).join('') + '</span>' +
    '<span></span><span></span></div>';
  var sr = hhmm((daily.sunrise || [])[0]), ss = hhmm((daily.sunset || [])[0]);
  var uv = (daily.uv_index_max || [])[0];
  return '<div class="card" style="background:' + colorFor(code) + '">' +
    '<div class="c-top"><div class="c-left">' +
      '<div class="c-name">' + esc(name) + '</div>' +
      '<div class="c-temp">' + Math.round(dT(cur.temperature_2m)) + '°</div>' +
      '<div class="c-word">' + esc(WORDS[code] || 'weather') + '</div>' +
      '<div class="c-meta">feels ' + Math.round(dT(cur.apparent_temperature)) + '° · wind ' +
        Math.round(dW(cur.wind_speed_10m)) + ' ' + (units === 'f' ? 'mph' : 'km/h') +
        ' · humidity ' + esc(cur.relative_humidity_2m) + '%' +
        '<br>sunrise ' + sr + ' · sunset ' + ss + (uv != null ? ' · uv ' + Math.round(uv) : '') + '</div>' +
    '</div>' + icon(slugFor(code, cur.is_day), 'c-icon') + '</div>' +
    '<div class="hourly">' + hourlyChart(hourly) + '</div>' +
    '<div class="week">' + week + '</div>' +
    '</div>';
}

// ── state ──
var units = 'c';
var lastData = null;
var selected = null;
var mode = 'forecast';

function load() {
  fetch(API + '/data').then(function(r) { return r.json(); }).then(function(d) {
    lastData = d;
    if (Date.now() - unitsTouched > 5000) units = d.units || 'c';
    document.getElementById('unit-toggle').textContent = units === 'f' ? '°F' : '°C';
    var locs = d.locations || [];
    if (!selected || !locs.some(function(l) { return l.name === selected; })) {
      // add() optimistically selects the typed name; the server may have
      // stored a different canonical name, so fall back case-insensitively
      var ci = selected && locs.filter(function(l) {
        return l.name.toLowerCase() === selected.toLowerCase();
      })[0];
      selected = ci ? ci.name : (locs.length ? locs[0].name : null);
    }
    renderSide();
    renderDocs();
    if (map) renderMarkers();
    // a city with no forecast yet means a fetch sweep is in flight —
    // poll fast until it lands instead of waiting out the 60s baseline
    var wx = d.weather || {};
    if (locs.some(function(l) { return !wx[l.name]; })) {
      if (pendingTries++ < 30) {
        clearTimeout(pendingTimer);
        pendingTimer = setTimeout(load, 2000);
      }
    } else {
      pendingTries = 0;
    }
  });
}
var pendingTimer = null, pendingTries = 0;

// ── sidebar: the location collection (owns add + delete + order) ──
// move mode: click ⇅ on a row, the slots between rows become click
// targets; click one to drop the row there
var movingLoc = null;
function renderSide() {
  var locs = (lastData && lastData.locations) || [];
  var wx = (lastData && lastData.weather) || {};
  var list = document.getElementById('loc-list');
  var stamp = '';
  if (movingLoc && !locs.some(function(l) { return l.name === movingLoc; })) movingLoc = null;
  if (!locs.length) {
    list.innerHTML = '<div class="empty" style="padding:24px 0">no places yet</div>';
  } else {
    var movIdx = -1;
    var rows = locs.map(function(loc, i) {
      if (loc.name === movingLoc) movIdx = i;
      var entry = wx[loc.name];
      var cur = (entry && entry.resp && entry.resp.current) || {};
      if (entry && entry.at) stamp = entry.at;
      var code = cur.weather_code || 0;
      // rows show the bare city; the qualified name ("Portland,
      // Oregon") stays the stored identity and surfaces as a tooltip
      var short = loc.name.split(',')[0];
      return '<div class="l-row' + (loc.name === selected ? ' sel' : '') +
        (loc.name === movingLoc ? ' moving' : '') + '" data-loc="' + esc(loc.name) +
        '" title="' + esc(loc.name) + '">' +
        icon(slugFor(code, cur.is_day == null ? 1 : cur.is_day), 'l-icon') +
        '<span><div class="l-name">' + esc(short) + '</div>' +
          '<div class="l-word">' + esc(WORDS[code] || '') + '</div></span>' +
        '<span class="l-temp">' + (cur.temperature_2m != null ? Math.round(dT(cur.temperature_2m)) + '°' : '–') + '</span>' +
        '<span class="l-acts">' +
          (locs.length > 1 ? '<button class="l-move" data-move="' + esc(loc.name) + '" title="move">⇅</button>' : '') +
          '<button class="l-del" data-del="' + esc(loc.name) + '">×</button></span>' +
        '</div>';
    });
    if (movingLoc) {
      // interleave drop slots; skip the two adjacent to the moving row
      var out = [];
      for (var i = 0; i <= rows.length; i++) {
        if (i !== movIdx && i !== movIdx + 1) {
          out.push('<div class="l-slot" data-slot="' + i + '"></div>');
        }
        if (i < rows.length) out.push(rows[i]);
      }
      list.innerHTML = out.join('');
    } else {
      list.innerHTML = rows.join('');
    }
  }
  document.getElementById('stamp').textContent = stamp ? 'updated ' + stamp : '';
  Array.prototype.forEach.call(list.querySelectorAll('.l-row'), function(row) {
    row.onclick = function() { select(row.getAttribute('data-loc')); };
  });
  Array.prototype.forEach.call(list.querySelectorAll('.l-move'), function(b) {
    b.onclick = function(e) {
      e.stopPropagation();
      var name = b.getAttribute('data-move');
      movingLoc = movingLoc === name ? null : name;
      renderSide();
    };
  });
  Array.prototype.forEach.call(list.querySelectorAll('.l-slot'), function(s) {
    s.onclick = function() { dropAt(parseInt(s.getAttribute('data-slot'), 10)); };
  });
  Array.prototype.forEach.call(list.querySelectorAll('.l-del'), function(b) {
    b.onclick = function(e) {
      e.stopPropagation();
      fetch(API + '/del', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ name: b.getAttribute('data-del') })
      }).then(function() { setTimeout(load, 500); });
    };
  });
}

function dropAt(slot) {
  var locs = (lastData && lastData.locations) || [];
  var from = locs.map(function(l) { return l.name; }).indexOf(movingLoc);
  if (from < 0) { movingLoc = null; renderSide(); return; }
  var to = slot > from ? slot - 1 : slot;
  var reordered = locs.slice();
  reordered.splice(to, 0, reordered.splice(from, 1)[0]);
  movingLoc = null;
  // optimistic: reorder locally, then tell the server
  lastData.locations = reordered;
  renderSide();
  lastDocsJson = '';
  renderDocs();
  fetch(API + '/order', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ order: reordered.map(function(l) { return l.name; }) })
  });
}
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape' && movingLoc) { movingLoc = null; renderSide(); }
});

var spyMute = 0;
function select(name) {
  selected = name;
  renderSide();
  if (mode === 'forecast') {
    var card = document.querySelector('.doc-card[data-loc="' + CSS.escape(name) + '"]');
    if (card) {
      spyMute = Date.now() + 800;
      card.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }
  if (mode === 'map' && map && lastData) {
    var loc = (lastData.locations || []).filter(function(l) { return l.name === name; })[0];
    if (loc) map.flyTo({ center: [parseFloat(loc.lon), parseFloat(loc.lat)], zoom: 7 });
  }
}

// ── forecast pane: all locations stacked, scrollable ──
var lastDocsJson = '';
function renderDocs() {
  var doc = document.getElementById('doc');
  var locs = (lastData && lastData.locations) || [];
  if (!locs.length) {
    doc.innerHTML = '<div class="empty">no places yet — add one in the sidebar</div>';
    lastDocsJson = '';
    return;
  }
  var wx = (lastData && lastData.weather) || {};
  var json = JSON.stringify([units, locs, wx]);
  if (json === lastDocsJson) return;
  lastDocsJson = json;
  var pane = document.getElementById('pane-forecast');
  var keep = pane.scrollTop;
  doc.innerHTML = locs.map(function(loc) {
    return '<div class="doc-card" data-loc="' + esc(loc.name) + '">' +
      buildCard(loc.name, wx[loc.name]) + '</div>';
  }).join('');
  pane.scrollTop = keep;
}

// scroll-spy: sidebar highlight follows whichever card is at the top
document.getElementById('pane-forecast').addEventListener('scroll', function() {
  if (mode !== 'forecast' || Date.now() < spyMute) return;
  var pane = this;
  var cards = pane.querySelectorAll('.doc-card');
  var best = null, bestD = Infinity;
  Array.prototype.forEach.call(cards, function(c) {
    var d = Math.abs(c.getBoundingClientRect().top - pane.getBoundingClientRect().top - 20);
    if (d < bestD) { bestD = d; best = c; }
  });
  if (best && best.getAttribute('data-loc') !== selected) {
    selected = best.getAttribute('data-loc');
    renderSide();
  }
});

// ── map pane: OSM base + RainViewer radar + temp markers ──
var map = null, markers = [], radarFrames = [], radarIdx = -1, radarTimer = null;
function initMap() {
  if (map) return;
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
          attribution: '© OpenStreetMap © RainViewer'
        }
      },
      layers: [{ id: 'osm', type: 'raster', source: 'osm' }]
    },
    center: [10, 45],
    zoom: 3
  });
  map.addControl(new maplibregl.NavigationControl(), 'top-right');
  // map and globe tabs share this one live map; the tab picks the
  // projection (mercator = whole world at once, globe = the sphere)
  map.on('style.load', function() { syncProjection(); });
  map.on('load', loadRadar);
  map.on('move', cullFarSide);
}
function syncProjection() {
  if (!map) return;
  map.setProjection({ type: mode === 'globe' ? 'globe' : 'mercator' });
  cullFarSide();
}
function loadRadar() {
  fetch('https://api.rainviewer.com/public/weather-maps.json')
    .then(function(r) { return r.json(); })
    .then(function(rv) {
      var frames = (rv.radar.past || []).slice(-7).concat(rv.radar.nowcast || []);
      radarFrames = frames.map(function(f) {
        return { time: f.time, url: rv.host + f.path + '/256/{z}/{x}/{y}/2/1_1.png' };
      });
      radarFrames.forEach(function(f, i) {
        map.addSource('radar-' + i, { type: 'raster', tiles: [f.url], tileSize: 256 });
        map.addLayer({ id: 'radar-' + i, type: 'raster', source: 'radar-' + i,
          paint: { 'raster-opacity': 0 } });
      });
      showRadar(radarFrames.length - 1);
    });
}
function showRadar(i) {
  if (!radarFrames.length) return;
  if (radarIdx >= 0) map.setPaintProperty('radar-' + radarIdx, 'raster-opacity', 0);
  radarIdx = i;
  map.setPaintProperty('radar-' + i, 'raster-opacity', 0.75);
  var t = new Date(radarFrames[i].time * 1000);
  document.getElementById('radar-time').textContent =
    t.getHours().toString().padStart(2, '0') + ':' + t.getMinutes().toString().padStart(2, '0');
}
document.getElementById('radar-play').onclick = function() {
  if (radarTimer) {
    clearInterval(radarTimer);
    radarTimer = null;
    this.textContent = '▶';
    showRadar(radarFrames.length - 1);
    return;
  }
  this.textContent = '⏸';
  radarTimer = setInterval(function() {
    showRadar((radarIdx + 1) % radarFrames.length);
  }, 550);
};
function renderMarkers() {
  markers.forEach(function(m) { m.remove(); });
  markers = [];
  if (!map || !lastData) return;
  var locs = lastData.locations || [];
  var wx = lastData.weather || {};
  var bounds = [];
  locs.forEach(function(loc) {
    var entry = wx[loc.name];
    var cur = (entry && entry.resp && entry.resp.current) || {};
    var el = document.createElement('div');
    el.className = 't-chip';
    // bare city on the chip — on a map, the position is the "which one"
    el.textContent = (cur.temperature_2m != null ? Math.round(dT(cur.temperature_2m)) + '° ' : '') + loc.name.split(',')[0];
    el.title = loc.name;
    el.onclick = function() { select(loc.name); };
    var lngLat = [parseFloat(loc.lon), parseFloat(loc.lat)];
    markers.push(new maplibregl.Marker({ element: el }).setLngLat(lngLat).addTo(map));
    bounds.push(lngLat);
  });
  if (bounds.length === 1) map.flyTo({ center: bounds[0], zoom: 6 });
  if (bounds.length > 1) {
    var b = bounds.reduce(function(acc, c) { return acc.extend(c); },
      new maplibregl.LngLatBounds(bounds[0], bounds[0]));
    map.fitBounds(b, { padding: 60, maxZoom: 7 });
  }
  cullFarSide();
}
// chips are DOM elements over the canvas, so the sphere doesn't
// occlude them — hide any marker past the horizon (a hair under 90°
// of great-circle distance from the view center) while on the globe
function cullFarSide() {
  if (!map) return;
  var globe = mode === 'globe';
  var c = map.getCenter();
  markers.forEach(function(m) {
    var el = m.getElement();
    if (!globe) { el.style.visibility = ''; return; }
    var p = m.getLngLat();
    el.style.visibility = angDist(c.lat, c.lng, p.lat, p.lng) > 85 ? 'hidden' : '';
  });
}
function angDist(lat1, lon1, lat2, lon2) {
  var r = Math.PI / 180;
  var a = Math.sin((lat2 - lat1) * r / 2), b = Math.sin((lon2 - lon1) * r / 2);
  var h = a * a + Math.cos(lat1 * r) * Math.cos(lat2 * r) * b * b;
  return 2 * Math.asin(Math.sqrt(h)) / r;
}

// ── mode tabs: forecast (document) vs map (canvas, kept alive) ──
function setMode(m) {
  mode = m;
  Array.prototype.forEach.call(document.querySelectorAll('.mode'), function(b) {
    b.classList.toggle('active', b.getAttribute('data-mode') === m);
  });
  document.getElementById('pane-forecast').style.display = m === 'forecast' ? 'block' : 'none';
  document.getElementById('pane-map').style.display = (m === 'map' || m === 'globe') ? 'block' : 'none';
  if (m === 'map' || m === 'globe') {
    initMap();
    syncProjection();
    setTimeout(function() { map.resize(); renderMarkers(); }, 60);
  }
}
Array.prototype.forEach.call(document.querySelectorAll('.mode'), function(b) {
  b.onclick = function() { setMode(b.getAttribute('data-mode')); };
});

// ── controls ──
// adding is search-then-pick: many cities share a name (see:
// Portland), so the submit shows candidates and the pick — with its
// admin1 folded into the stored name — is what gets added
function add() {
  var inp = document.getElementById('add-name');
  var q = inp.value.trim();
  if (!q) return;
  fetch(API + '/search', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ q: q })
  }).then(function(r) { return r.ok ? r.json() : []; }).then(function(hits) {
    if (!hits || !hits.length) { alert('place not found'); return; }
    if (hits.length === 1) { doAdd(hits[0]); return; }
    showPicks(hits);
  });
}
function showPicks(hits) {
  var box = document.getElementById('add-picks');
  box.innerHTML = '';
  hits.forEach(function(h) {
    var row = document.createElement('div');
    row.className = 'pick';
    var sub = [h.admin1, h.country].filter(Boolean).join(', ');
    row.textContent = h.name + ' ';
    if (sub) {
      var s = document.createElement('span');
      s.className = 'pick-sub';
      s.textContent = sub;
      row.appendChild(s);
    }
    row.onclick = function() { doAdd(h); };
    box.appendChild(row);
  });
  box.style.display = 'block';
}
function doAdd(h) {
  var inp = document.getElementById('add-name');
  var name = h.admin1 ? h.name + ', ' + h.admin1 : h.name;
  document.getElementById('add-picks').style.display = 'none';
  fetch(API + '/add', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name: name, lat: h.lat, lon: h.lon })
  }).then(function(r) {
    if (!r.ok) { alert('add failed'); return; }
    inp.value = '';
    selected = name;
    setTimeout(load, 1500);
    setTimeout(load, 4000);
  });
}
document.getElementById('add-btn').onclick = add;
document.getElementById('add-name').addEventListener('keydown', function(e) {
  if (e.key === 'Enter') add();
});
document.getElementById('add-name').addEventListener('input', function() {
  document.getElementById('add-picks').style.display = 'none';
});
// data is metric either way — the toggle is a pure re-render plus a
// config write so the preference (and the shell tile) persists
var unitsTouched = 0;
document.getElementById('unit-toggle').onclick = function() {
  unitsTouched = Date.now();
  units = units === 'f' ? 'c' : 'f';
  this.textContent = units === 'f' ? '°F' : '°C';
  lastDocsJson = '';
  renderSide();
  renderDocs();
  if (map) renderMarkers();
  fetch(API + '/units', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ units: units })
  });
};
document.getElementById('refresh').onclick = function() {
  fetch(API + '/refresh', { method: 'POST' });
  setTimeout(load, 3000);
};

load();
setInterval(load, 60000);
