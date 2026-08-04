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
    T.push(temps[i]); P.push(probs[i] || 0); L.push(times[i].slice(11, 13));
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

// ── cards ──
var units = 'c';
var lastData = null;
function load() {
  fetch(API + '/data').then(function(r) { return r.json(); }).then(function(d) {
    lastData = d;
    units = d.units || 'c';
    document.getElementById('unit-toggle').textContent = units === 'f' ? '°F' : '°C';
    render(d);
    if (mapOn) renderMarkers();
  });
}
function render(d) {
  var locs = d.locations || [];
  var wx = d.weather || {};
  var box = document.getElementById('cards');
  if (!locs.length) {
    box.innerHTML = '<div class="empty">no places yet — add one above</div>';
    document.getElementById('stamp').textContent = '';
    return;
  }
  var stamp = '';
  box.innerHTML = locs.map(function(loc) {
    var name = loc.name;
    var entry = wx[name];
    if (!entry || !entry.resp) {
      return '<div class="card" style="background:#8d949c">' +
        '<div class="c-name">' + esc(name) + '</div><div class="c-word">no data yet</div>' +
        '<button class="c-del" data-del="' + esc(name) + '">×</button></div>';
    }
    stamp = entry.at || stamp;
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
    var wmin = Math.min.apply(null, daily.temperature_2m_min || [0]);
    var wmax = Math.max.apply(null, daily.temperature_2m_max || [1]);
    var wspan = (wmax - wmin) || 1;
    var step = [2, 5, 10, 20].filter(function(s) { return wspan / s <= 5; })[0] || 20;
    var tickXs = [['0.0', Math.round(wmin)]];
    for (var t = Math.ceil(wmin / step) * step; t <= wmax; t += step) {
      var tx = (t - wmin) / wspan * 100;
      if (tx > 7) tickXs.push([tx.toFixed(1), t]);
    }
    var grid = tickXs.map(function(tk) {
      return '<span class="w-grid" style="left:' + tk[0] + '%"></span>';
    }).join('');
    for (var i = 0; i < dates.length; i++) {
      var lo = daily.temperature_2m_min[i], hi = daily.temperature_2m_max[i];
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
      '<button class="c-del" data-del="' + esc(name) + '">×</button>' +
      '<div class="c-top"><div class="c-left">' +
        '<div class="c-name">' + esc(name) + '</div>' +
        '<div class="c-temp">' + Math.round(cur.temperature_2m) + '°</div>' +
        '<div class="c-word">' + esc(WORDS[code] || 'weather') + '</div>' +
        '<div class="c-meta">feels ' + Math.round(cur.apparent_temperature) + '° · wind ' +
          Math.round(cur.wind_speed_10m) + ' ' + (units === 'f' ? 'mph' : 'km/h') +
          ' · humidity ' + esc(cur.relative_humidity_2m) + '%' +
          '<br>sunrise ' + sr + ' · sunset ' + ss + (uv != null ? ' · uv ' + Math.round(uv) : '') + '</div>' +
      '</div>' + icon(slugFor(code, cur.is_day), 'c-icon') + '</div>' +
      '<div class="hourly">' + hourlyChart(hourly) + '</div>' +
      '<div class="week">' + week + '</div>' +
      '</div>';
  }).join('');
  document.getElementById('stamp').textContent = stamp ? 'updated ' + stamp : '';
  Array.prototype.forEach.call(box.querySelectorAll('.c-del'), function(b) {
    b.onclick = function() {
      fetch(API + '/del', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ name: b.getAttribute('data-del') })
      }).then(function() { setTimeout(load, 500); });
    };
  });
}

// ── map view: OSM base + RainViewer radar + temp markers ──
var map = null, mapOn = false, markers = [], radarFrames = [], radarIdx = -1, radarTimer = null;
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
  map.on('load', loadRadar);
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
    el.textContent = (cur.temperature_2m != null ? Math.round(cur.temperature_2m) + '° ' : '') + loc.name;
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
}
document.getElementById('view-map').onclick = function() {
  mapOn = !mapOn;
  this.classList.toggle('active', mapOn);
  document.getElementById('map-wrap').style.display = mapOn ? 'block' : 'none';
  if (mapOn) {
    initMap();
    setTimeout(function() { map.resize(); renderMarkers(); }, 60);
  }
};

// ── controls ──
function add() {
  var inp = document.getElementById('add-name');
  var name = inp.value.trim();
  if (!name) return;
  fetch(API + '/add', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name: name })
  }).then(function(r) {
    if (!r.ok) { alert('place not found'); return; }
    inp.value = '';
    setTimeout(load, 1500);
    setTimeout(load, 4000);
  });
}
document.getElementById('add-btn').onclick = add;
document.getElementById('add-name').addEventListener('keydown', function(e) {
  if (e.key === 'Enter') add();
});
document.getElementById('unit-toggle').onclick = function() {
  fetch(API + '/units', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ units: units === 'f' ? 'c' : 'f' })
  }).then(function() {
    setTimeout(load, 1500);
    setTimeout(load, 4000);
  });
};
document.getElementById('refresh').onclick = function() {
  fetch(API + '/refresh', { method: 'POST' });
  setTimeout(load, 3000);
};

load();
setInterval(load, 60000);
