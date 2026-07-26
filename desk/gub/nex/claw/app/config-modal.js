// shared assistant config modal: structured recurrence editor with a
// raw-JSON escape hatch. Self-injects its markup on first use.
// Usage: openAssistantConfig(ball, path, onSaved)

(function() {

var MARKUP =
  '<div id="cfg-backdrop">' +
    '<div id="cfg-modal">' +
      '<div id="cfg-header">' +
        '<span id="cfg-title">assistant</span>' +
        '<div>' +
          '<button id="cfg-raw" class="hdr-btn">raw</button>' +
          '<button id="cfg-save" class="hdr-btn">save</button>' +
          '<button id="cfg-close" class="hdr-btn">close</button>' +
        '</div>' +
      '</div>' +
      '<div id="cfg-form">' +
        '<div class="frow"><label class="fl"><input id="f-enabled" type="checkbox"> enabled</label></div>' +
        '<label class="f">Code</label>' +
        '<input id="f-code" type="text" placeholder="morning-brief">' +
        '<label class="f">Repeats</label>' +
        '<select id="f-kind">' +
          '<option value="once">Once</option>' +
          '<option value="every">Every N minutes</option>' +
          '<option value="daily" selected>Daily</option>' +
          '<option value="weekly">Weekly</option>' +
          '<option value="monthly">Monthly</option>' +
          '<option value="yearly">Yearly</option>' +
        '</select>' +
        '<div class="kf ef"><label class="f">Every (minutes)</label>' +
          '<input id="f-period" type="number" min="1" value="60"></div>' +
        '<div class="kf wf"><label class="f">On days</label><div id="f-days">' +
          '<span class="day-tog" data-d="mon">Mon</span><span class="day-tog" data-d="tue">Tue</span>' +
          '<span class="day-tog" data-d="wed">Wed</span><span class="day-tog" data-d="thu">Thu</span>' +
          '<span class="day-tog" data-d="fri">Fri</span><span class="day-tog" data-d="sat">Sat</span>' +
          '<span class="day-tog" data-d="sun">Sun</span></div></div>' +
        '<div class="kf mf"><label class="f">Day of month</label>' +
          '<input id="f-dom" type="number" min="1" max="31" value="1"></div>' +
        '<div class="kf yf"><label class="f">Month / day</label><div class="frow">' +
          '<input id="f-month" type="number" min="1" max="12" value="1">' +
          '<input id="f-yday" type="number" min="1" max="31" value="1"></div></div>' +
        '<div class="kf tf"><label class="f">At</label>' +
          '<input id="f-time" type="time" value="08:00"></div>' +
        '<label class="f">Starting from</label>' +
        '<input id="f-start" type="date">' +
        '<label class="f">Timezone</label>' +
        '<select id="f-zone"></select>' +
        '<label class="f">Args (JSON, passed to the code)</label>' +
        '<textarea id="f-args" rows="3" placeholder="{}"></textarea>' +
      '</div>' +
      '<textarea id="cfg-json" rows="14" placeholder="{}" style="display:none"></textarea>' +
      '<div id="cfg-status"></div>' +
    '</div>' +
  '</div>';

var injected = false;
var cfgBall = null;
var cfgRel = null;
var cfgLoaded = null;
var onSaved = null;
var rawMode = false;
var zonesReady = null;

function $(id) { return document.getElementById(id); }

function relOf(path) {
  var segs = path.split('/');
  segs[segs.length - 1] += '.assistant';
  return 'assistants/' + segs.join('/') + '/main.assistant';
}

function fmtAt(at) {
  if (at == null) return '';
  if (typeof at === 'string') return at;
  var h = Math.floor(at / 60), mn = at % 60;
  return ('0' + h).slice(-2) + ':' + ('0' + mn).slice(-2);
}

function inject() {
  if (injected) return;
  injected = true;
  document.body.insertAdjacentHTML('beforeend', MARKUP);
  $('f-kind').onchange = syncKindFields;
  document.querySelectorAll('#cfg-modal .day-tog').forEach(function(t) {
    t.onclick = function() { t.classList.toggle('on'); };
  });
  $('cfg-raw').onclick = toggleRaw;
  $('cfg-close').onclick = close;
  $('cfg-backdrop').onclick = function(e) { if (e.target === this) close(); };
  $('cfg-save').onclick = save;
}

function loadZones() {
  if (zonesReady) return zonesReady;
  var sel = $('f-zone');
  var add = function(v, label) {
    var o = document.createElement('option');
    o.value = v; o.textContent = label || v;
    sel.appendChild(o);
  };
  add('', 'UTC (no zone)');
  zonesReady = fetch('/grubbery/calendar/zones.json')
    .then(function(r) { return r.json(); })
    .then(function(zs) { zs.forEach(function(z) { add(z); }); })
    .catch(function() { add('America/New_York'); });
  return zonesReady;
}

function syncKindFields() {
  var k = $('f-kind').value;
  var show = {
    ef: k === 'every',
    wf: k === 'weekly',
    mf: k === 'monthly',
    yf: k === 'yearly',
    tf: k !== 'once' && k !== 'every'
  };
  Object.keys(show).forEach(function(c) {
    document.querySelectorAll('#cfg-modal .' + c).forEach(function(el) {
      el.style.display = show[c] ? '' : 'none';
    });
  });
}

function populateForm(cfg) {
  var r = cfg.recur || {};
  var a = r.args || {};
  $('f-enabled').checked = cfg.enabled === true;
  $('f-code').value = cfg.code || '';
  $('f-kind').value = r.kind || 'daily';
  $('f-period').value = a.period || 60;
  $('f-dom').value = a.day || 1;
  $('f-month').value = a.month || 1;
  $('f-yday').value = a.day || 1;
  $('f-time').value = typeof a.at === 'string' ? a.at : fmtAt(a.at) || '08:00';
  document.querySelectorAll('#cfg-modal .day-tog').forEach(function(t) {
    t.classList.toggle('on', (a.days || []).indexOf(t.dataset.d) >= 0);
  });
  var d = new Date(r.start_ms || Date.now());
  $('f-start').value = d.toISOString().slice(0, 10);
  $('f-zone').value = cfg.zone || '';
  $('f-args').value = JSON.stringify(cfg.args || {}, null, 2);
  syncKindFields();
}

function formToConfig() {
  var cfg = cfgLoaded && typeof cfgLoaded === 'object' ? cfgLoaded : {};
  cfg.enabled = $('f-enabled').checked;
  cfg.code = $('f-code').value.trim();
  var zone = $('f-zone').value;
  if (zone) cfg.zone = zone; else delete cfg.zone;
  try { cfg.args = JSON.parse($('f-args').value || '{}'); }
  catch (e) { return 'args is not valid JSON'; }
  var k = $('f-kind').value;
  var args = {};
  var at = $('f-time').value || '08:00';
  if (k === 'every') args.period = +$('f-period').value || 60;
  if (k === 'daily') args.at = at;
  if (k === 'weekly') {
    args.days = [].slice.call(document.querySelectorAll('#cfg-modal .day-tog.on'))
      .map(function(t) { return t.dataset.d; });
    if (!args.days.length) return 'pick at least one day';
    args.at = at;
  }
  if (k === 'monthly') { args.day = +$('f-dom').value || 1; args.at = at; }
  if (k === 'yearly') {
    args.month = +$('f-month').value || 1;
    args.day = +$('f-yday').value || 1;
    args.at = at;
  }
  var sv = $('f-start').value;
  var start = sv ? Date.parse(sv + 'T00:00:00Z') : Date.now();
  cfg.recur = { kind: k, args: args, start_ms: start };
  return cfg;
}

function toggleRaw() {
  rawMode = !rawMode;
  if (rawMode) {
    var cfg = formToConfig();
    if (typeof cfg !== 'string') $('cfg-json').value = JSON.stringify(cfg, null, 2);
  }
  $('cfg-form').style.display = rawMode ? 'none' : '';
  $('cfg-json').style.display = rawMode ? '' : 'none';
  $('cfg-raw').textContent = rawMode ? 'form' : 'raw';
}

function close() {
  $('cfg-backdrop').classList.remove('open');
  cfgRel = null;
}

function save() {
  var st = $('cfg-status');
  var cfg;
  if (rawMode) {
    try { cfg = JSON.parse($('cfg-json').value); }
    catch (e) { st.textContent = 'invalid JSON'; st.className = 'err'; return; }
  } else {
    cfg = formToConfig();
    if (typeof cfg === 'string') { st.textContent = cfg; st.className = 'err'; return; }
  }
  fetch('/grubbery/api/over/' + cfgBall + '/' + cfgRel + '?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(cfg)
  }).then(function(r) {
    if (!r.ok) { st.textContent = 'save failed'; st.className = 'err'; return; }
    close();
    if (onSaved) onSaved();
  });
}

window.openAssistantConfig = function(ball, path, cb) {
  inject();
  cfgBall = ball;
  cfgRel = relOf(path);
  cfgLoaded = null;
  onSaved = cb || null;
  rawMode = false;
  $('cfg-raw').textContent = 'raw';
  $('cfg-title').textContent = path;
  $('cfg-status').textContent = 'loading…';
  $('cfg-status').className = '';
  $('cfg-form').style.display = 'none';
  $('cfg-json').style.display = 'none';
  $('cfg-backdrop').classList.add('open');
  var read = fetch('/grubbery/ball/' + ball + '/' + cfgRel + '?blot=/json')
    .then(function(r) { return r.json(); });
  Promise.all([loadZones(), read]).then(function(res) {
    var j = res[1];
    cfgLoaded = j && typeof j === 'object' ? j : {};
    populateForm(cfgLoaded);
    $('cfg-json').value = JSON.stringify(cfgLoaded, null, 2);
    $('cfg-status').textContent = '';
    $('cfg-form').style.display = '';
  }).catch(function() {
    var st = $('cfg-status');
    st.textContent = 'could not load';
    st.className = 'err';
  });
};

})();
