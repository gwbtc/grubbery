// calendar client: three projections (month / week / day) of one
// window.json contract, all display projected into the calendar's
// configured zone (browser zone as fallback).

var API = '/grubbery/api';
var CAL = '/grubbery/calendar';
var CFG = { zone: '', ball: '', title: 'Calendar' };

var WD = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
var WDS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
var MN = ['January','February','March','April','May','June','July',
          'August','September','October','November','December'];
var MS_DAY = 864e5;

var state = { view: 'month', y: 0, m: 0, d: 0 };
var zfmt = null;
var nowTimer = null;

// ---- zone projection ----------------------------------------------

function mkfmt() {
  var opts = { year: 'numeric', month: '2-digit', day: '2-digit',
               hour: '2-digit', minute: '2-digit', hourCycle: 'h23' };
  try {
    zfmt = new Intl.DateTimeFormat('en-CA',
      Object.assign({}, opts, CFG.zone ? { timeZone: CFG.zone } : {}));
  } catch (e) {
    zfmt = new Intl.DateTimeFormat('en-CA', opts);
  }
}

function parts(ms) {
  var p = {};
  zfmt.formatToParts(ms).forEach(function(x) { p[x.type] = x.value; });
  return { y: +p.year, m: +p.month, d: +p.day,
           hh: +p.hour % 24, mm: +p.minute,
           ths: p.hour, tms: p.minute };
}

function serial(y, m, d) { return Date.UTC(y, m - 1, d) / MS_DAY; }
function unserial(s) {
  var dt = new Date(s * MS_DAY);
  return { y: dt.getUTCFullYear(), m: dt.getUTCMonth() + 1, d: dt.getUTCDate() };
}
function pserial(p) { return serial(p.y, p.m, p.d); }

var H12 = localStorage.getItem('cal-h12') === '1';
function fmtTime(p) {
  if (!H12) return p.ths + ':' + p.tms;
  var h = p.hh % 12 || 12;
  return h + ':' + p.tms + (p.hh < 12 ? 'a' : 'p');
}
function fmtTimeLong(p) {
  if (!H12) return p.ths + ':' + p.tms;
  var h = p.hh % 12 || 12;
  return h + ':' + p.tms + (p.hh < 12 ? ' AM' : ' PM');
}
function fmtHour(h) {
  if (!H12) return ('0' + h).slice(-2) + ':00';
  return (h % 12 || 12) + (h < 12 ? ' AM' : ' PM');
}
function fmtDate(p) {
  var dow = (new Date(pserial(p) * MS_DAY).getUTCDay() + 6) % 7;
  return WDS[dow] + ', ' + MN[p.m - 1].slice(0, 3) + ' ' + p.d;
}

// ISO 8601 week number: the week of its Thursday, weeks start Monday
function isoWeek(ser) {
  var dow = (new Date(ser * MS_DAY).getUTCDay() + 6) % 7;
  var thu = ser - dow + 3;
  var y = new Date(thu * MS_DAY).getUTCFullYear();
  var jan1 = Date.UTC(y, 0, 1) / MS_DAY;
  return Math.floor((thu - jan1) / 7) + 1;
}

// ---- data ---------------------------------------------------------

// per-event computation walls: [{id, name, stop}] where an event's
// occurrence walk was capped short of the requested range
var CAPS = [];

function fetchWindow(fromMs, toMs, cb) {
  fetch(CAL + '/window.json?from=' + fromMs + '&to=' + toMs)
    .then(function(x) { return x.json(); })
    .then(function(res) {
      var rows = res.rows || [];
      CAPS = (res.caps || []).map(function(cp) {
        var m = cp.meta || {};
        return { id: cp.id, name: m.name || '', color: m.color || '', stop: cp.stop };
      });
      // meta rides as an object; flatten the display keys onto the row
      rows.forEach(function(r) {
        var m = r.meta || {};
        r.name = m.name || '';
        r.note = m.note || '';
        r.color = m.color || '';
      });
      cb(rows);
    })
    .catch(function() { cb([]); });
}

function capsOn(ser) {
  return CAPS.filter(function(cp) {
    return pserial(msToUTC(cp.stop)) === ser;
  });
}

function capChip(cp) {
  var mk = document.createElement('div');
  mk.className = 'chip cap-chip';
  mk.textContent = '⇥ ' + cp.name + ' · computed to here';
  hoverTip(mk,
    '"' + cp.name + '" continues past this day, but only its first 10,000 ' +
    'occurrences have been computed — they end here. The series itself has no end.');
  return mk;
}

// fixed-position hover tooltip — unclippable by cell overflow
function hoverTip(el, text) {
  el.addEventListener('mouseenter', function() {
    var t = document.createElement('div');
    t.id = 'tipbox';
    t.textContent = text;
    document.body.appendChild(t);
    var r = el.getBoundingClientRect();
    t.style.left = Math.min(r.left, window.innerWidth - 260) + 'px';
    t.style.top = (r.top > 80 ? r.top - t.offsetHeight - 6 : r.bottom + 6) + 'px';
  });
  el.addEventListener('mouseleave', function() {
    var t = document.getElementById('tipbox');
    if (t) t.remove();
  });
}

function poke(body, cb) {
  fetch(API + '/poke/' + CFG.ball + '/calendar.calendar?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { if (cb) cb(r.ok); });
}

// ---- layout helpers -----------------------------------------------

function isAllDay(ev) { return ev.all || (ev.r - ev.l) >= MS_DAY; }
// all-day events live in date-space: UTC parts, no zone projection
function evParts(ev, ms) { return ev.all ? msToUTC(ms) : parts(ms); }

// overlap packing: greedy column assignment within collision clusters
function pack(items) {
  items.sort(function(a, b) { return a.s - b.s || b.e - a.e; });
  var cols = [], cluster = null, clusters = [], maxEnd = -1;
  items.forEach(function(it) {
    if (cluster === null || it.s >= maxEnd) {
      cluster = { items: [], n: 0 };
      clusters.push(cluster);
      cols = [];
      maxEnd = -1;
    }
    var c = 0;
    while (c < cols.length && cols[c] > it.s) c++;
    cols[c] = it.e;
    it.col = c;
    cluster.items.push(it);
    cluster.n = Math.max(cluster.n, cols.length);
    maxEnd = Math.max(maxEnd, it.e);
  });
  clusters.forEach(function(cl) {
    cl.items.forEach(function(it) { it.ncols = cl.n; });
  });
}

// ---- shared chrome ------------------------------------------------

var label = document.getElementById('month-label');
var pop = document.getElementById('pop');
var popTarget = null;

function showPop(ev, x, y) {
  popTarget = ev;
  document.getElementById('pop-name').textContent = ev.name;
  document.getElementById('pop-dot').style.background = ev.color || '#4a6a8a';
  var s = parts(ev.l), e = parts(ev.r);
  var sameDay = pserial(s) === pserial(e);
  var text;
  if (isAllDay(ev)) {
    var as = evParts(ev, ev.l);
    var last = evParts(ev, Math.max(ev.l, ev.r - 1));
    text = pserial(as) === pserial(last)
      ? fmtDate(as) + ' · All day'
      : fmtDate(as) + ' – ' + fmtDate(last) + ' · All day';
  } else if (ev.l === ev.r) {
    text = fmtDate(s) + ' · ' + fmtTimeLong(s);
  } else if (sameDay) {
    text = fmtDate(s) + ' · ' + fmtTimeLong(s) + ' – ' + fmtTimeLong(e);
  } else {
    text = fmtDate(s) + ' ' + fmtTimeLong(s) + ' – ' + fmtDate(e) + ' ' + fmtTimeLong(e);
  }
  document.getElementById('pop-time').textContent = text;
  var note = document.getElementById('pop-note');
  note.textContent = ev.note || '';
  note.style.display = ev.note ? '' : 'none';
  var series = (ev.cat !== 'date' && ev.kind !== 'once');
  document.getElementById('pop-skip').style.display = series ? '' : 'none';
  document.getElementById('pop-del').textContent =
    (ev.kind === 'once') ? 'Delete' : 'Delete series';
  pop.classList.remove('hidden');
  var pw = 290, ph = 170;
  pop.style.left = Math.min(x, window.innerWidth - pw - 8) + 'px';
  pop.style.top = Math.min(y, window.innerHeight - ph - 8) + 'px';
}
function hidePop() { pop.classList.add('hidden'); popTarget = null; }

document.getElementById('pop-close').onclick = hidePop;
document.getElementById('pop-skip').onclick = function() {
  if (!popTarget) return;
  poke({ action: 'skip-event', id: popTarget.id, idx: popTarget.idx });
  hidePop();
  setTimeout(load, 400);
};
document.getElementById('pop-del').onclick = function() {
  if (!popTarget) return;
  var q = popTarget.kind === 'once'
    ? 'Delete "' + popTarget.name + '"?'
    : 'Delete "' + popTarget.name + '" and all its occurrences?';
  if (!confirm(q)) return;
  poke({ action: 'del-event', id: popTarget.id });
  hidePop();
  setTimeout(load, 400);
};
document.getElementById('pop-edit').onclick = function() {
  if (!popTarget) return;
  var t = popTarget;
  fetch(CAL + '/event.json?id=' + encodeURIComponent(t.id))
    .then(function(r) { return r.json(); })
    .then(function(d) { hidePop(); openEdit(d, t); })
    .catch(function() {});
};
document.addEventListener('click', function(e) {
  if (!pop.classList.contains('hidden') &&
      !pop.contains(e.target) && !e.target.closest('.chip') &&
      !e.target.closest('.blk')) hidePop();
});

function chipEl(ev, cont) {
  var chip = document.createElement('div');
  chip.className = 'chip' + (cont ? ' cont' : '');
  chip.style.background = ev.color || '#4a6a8a';
  chip.textContent = cont ? '· ' + ev.name
    : ev.all ? ev.name : fmtTime(parts(ev.l)) + ' ' + ev.name;
  chip.title = ev.name + (ev.note ? ' — ' + ev.note : '');
  chip.onclick = function(e) {
    e.stopPropagation();
    showPop(ev, e.clientX + 6, e.clientY + 6);
  };
  return chip;
}

// ---- month view ---------------------------------------------------

var grid = document.getElementById('grid');
document.getElementById('dow-row').innerHTML =
  '<div class="dow wk-stub"></div>' +
  WD.map(function(d) { return '<div class="dow">' + WDS[WD.indexOf(d)] + '</div>'; }).join('');

function monthCells() {
  var first = serial(state.y, state.m, 1);
  var dow = (new Date(first * MS_DAY).getUTCDay() + 6) % 7;
  var out = [];
  for (var i = 0; i < 42; i++) out.push(unserial(first - dow + i));
  return out;
}

function renderMonth(rows) {
  var byDay = {};
  rows.forEach(function(ev) {
    var s = pserial(evParts(ev, ev.l));
    var e = pserial(evParts(ev, Math.max(ev.l, ev.r - 1)));
    for (var d = s, first = true; d <= e; d++, first = false) {
      (byDay[d] = byDay[d] || []).push({ ev: ev, cont: !first });
    }
  });
  var today = pserial(parts(Date.now()));
  grid.innerHTML = '';
  monthCells().forEach(function(c, i) {
    var ser = serial(c.y, c.m, c.d);
    if (i % 7 === 0) {
      var wk = document.createElement('div');
      wk.className = 'wknum';
      wk.textContent = isoWeek(ser);
      wk.title = 'Week ' + isoWeek(ser);
      wk.onclick = function() {
        state.view = 'week'; state.y = c.y; state.m = c.m; state.d = c.d; load();
      };
      grid.appendChild(wk);
    }
    var cell = document.createElement('div');
    cell.className = 'cell' + (c.m !== state.m ? ' other' : '') +
      (ser === today ? ' today' : '') +
      (ser === serial(state.y, state.m, state.d) ? ' axis' : '');
    var num = document.createElement('div');
    num.className = 'dnum';
    num.textContent = c.d;
    num.onclick = function(e) {
      e.stopPropagation();
      state.view = 'day'; state.y = c.y; state.m = c.m; state.d = c.d; load();
    };
    cell.appendChild(num);
    cell.onclick = function(e) {
      if (e.target !== cell) return;
      openModal({ date: c, kind: 'once' });
    };
    (byDay[ser] || [])
      .sort(function(a, b) { return (a.cont ? 0 : a.ev.l) - (b.cont ? 0 : b.ev.l); })
      .forEach(function(en) { cell.appendChild(chipEl(en.ev, en.cont)); });
    capsOn(ser).forEach(function(cp) { cell.appendChild(capChip(cp)); });
    grid.appendChild(cell);
  });
}

// ---- week / day view ----------------------------------------------

var tgHead = document.getElementById('tg-head');
var tgAllday = document.getElementById('tg-allday');
var tgBody = document.getElementById('tg-body');
var tgScroll = document.getElementById('tg-scroll');

function gridDays(n) {
  var base = serial(state.y, state.m, state.d);
  if (n === 7) {
    var dow = (new Date(base * MS_DAY).getUTCDay() + 6) % 7;
    base -= dow;
  }
  var out = [];
  for (var i = 0; i < n; i++) out.push(unserial(base + i));
  return out;
}

function renderTimeGrid(rows, n) {
  var days = gridDays(n);
  var sers = days.map(function(c) { return serial(c.y, c.m, c.d); });
  var today = pserial(parts(Date.now()));

  // header
  tgHead.innerHTML = '';
  days.forEach(function(c) {
    var el = document.createElement('div');
    var ser = serial(c.y, c.m, c.d);
    el.className = 'tg-day' + (ser === today ? ' today' : '') +
      (n === 7 && ser === serial(state.y, state.m, state.d) ? ' axis' : '');
    el.textContent = WDS[(new Date(ser * MS_DAY).getUTCDay() + 6) % 7] + ' ' + c.d;
    el.onclick = function() { state.view = 'day'; state.y = c.y; state.m = c.m; state.d = c.d; load(); };
    tgHead.appendChild(el);
  });

  // all-day lane
  tgAllday.innerHTML = '';
  var lanes = days.map(function(c) {
    var el = document.createElement('div');
    el.className = 'ad-col';
    capsOn(serial(c.y, c.m, c.d)).forEach(function(cp) { el.appendChild(capChip(cp)); });
    tgAllday.appendChild(el);
    return el;
  });

  // body: axis + day columns
  tgBody.innerHTML = '';
  var axis = document.createElement('div');
  axis.id = 'tg-axis';
  for (var h = 1; h < 24; h++) {
    var lab = document.createElement('div');
    lab.className = 'hour-label';
    lab.style.top = (h * 60) + 'px';
    lab.textContent = fmtHour(h);
    axis.appendChild(lab);
  }
  tgBody.appendChild(axis);

  var cols = days.map(function(c) {
    var col = document.createElement('div');
    col.className = 'tg-col';
    for (var h = 1; h < 24; h++) {
      var line = document.createElement('div');
      line.className = 'hour-line';
      line.style.top = (h * 60) + 'px';
      col.appendChild(line);
    }
    col.onclick = function(e) {
      if (e.target !== col && !e.target.classList.contains('hour-line')) return;
      var rect = col.getBoundingClientRect();
      var min = Math.max(0, Math.min(1410,
        Math.floor((e.clientY - rect.top) / 30) * 30));
      openModal({
        date: c,
        time: pad2(Math.floor(min / 60)) + ':' + pad2(min % 60),
        kind: 'once'
      });
    };
    tgBody.appendChild(col);
    return col;
  });

  // place events
  var perDay = sers.map(function() { return []; });
  rows.forEach(function(ev) {
    if (isAllDay(ev)) {
      var s = pserial(evParts(ev, ev.l));
      var e = pserial(evParts(ev, Math.max(ev.l, ev.r - 1)));
      sers.forEach(function(ser, i) {
        if (ser >= s && ser <= e) lanes[i].appendChild(chipEl(ev, ser !== s));
      });
      return;
    }
    var sp = parts(ev.l);
    var rp = parts(ev.r);
    var sSer = pserial(sp);
    var eSer = pserial(parts(Math.max(ev.l, ev.r - 1)));
    sers.forEach(function(ser, i) {
      if (ser < sSer || ser > eSer) return;
      var sMin = (ser === sSer) ? sp.hh * 60 + sp.mm : 0;
      var eMin = (ser === pserial(rp)) ? rp.hh * 60 + rp.mm : 1440;
      if (ev.l === ev.r) eMin = sMin;
      perDay[i].push({ s: sMin, e: Math.max(eMin, sMin + 20), ev: ev });
    });
  });

  perDay.forEach(function(items, i) {
    pack(items);
    items.forEach(function(it) {
      var blk = document.createElement('div');
      blk.className = 'blk';
      blk.style.background = it.ev.color || '#4a6a8a';
      blk.style.top = it.s + 'px';
      blk.style.height = Math.max(18, it.e - it.s) + 'px';
      var w = 100 / it.ncols;
      blk.style.left = (it.col * w) + '%';
      blk.style.width = 'calc(' + w + '% - 3px)';
      var t = parts(it.ev.l);
      blk.innerHTML = '<div class="blk-time">' + fmtTime(t) + '</div>' + it.ev.name;
      blk.title = it.ev.name + (it.ev.note ? ' — ' + it.ev.note : '');
      blk.onclick = function(e) {
        e.stopPropagation();
        showPop(it.ev, e.clientX + 6, e.clientY + 6);
      };
      cols[i].appendChild(blk);
    });
  });

  // now-line
  function placeNow() {
    var np = parts(Date.now());
    var ser = pserial(np);
    var idx = sers.indexOf(ser);
    var old = tgBody.querySelector('.now-line');
    if (old) old.remove();
    if (idx < 0) return;
    var line = document.createElement('div');
    line.className = 'now-line';
    line.style.top = (np.hh * 60 + np.mm) + 'px';
    cols[idx].appendChild(line);
  }
  placeNow();
  if (nowTimer) clearInterval(nowTimer);
  nowTimer = setInterval(placeNow, 60000);

  // scroll to ~8am on first paint
  tgScroll.scrollTop = 8 * 60 - 20;
}

// ---- view routing -------------------------------------------------

function setLabel() {
  var zone = '';
  if (state.view === 'month') {
    label.textContent = MN[state.m - 1] + ' ' + state.y + zone;
  } else if (state.view === 'week') {
    var ds = gridDays(7);
    var a = ds[0], b = ds[6];
    label.textContent = MN[a.m - 1].slice(0, 3) + ' ' + a.d + ' – ' +
      (a.m === b.m ? '' : MN[b.m - 1].slice(0, 3) + ' ') + b.d + ', ' + b.y + zone;
    var sub = document.createElement('span');
    sub.className = 'wk-sub';
    sub.textContent = 'Week ' + isoWeek(serial(a.y, a.m, a.d));
    label.appendChild(sub);
  } else {
    var s = serial(state.y, state.m, state.d);
    label.textContent = WDS[(new Date(s * MS_DAY).getUTCDay() + 6) % 7] + ' ' +
      MN[state.m - 1].slice(0, 3) + ' ' + state.d + ', ' + state.y + zone;
  }
}

function syncUrl() {
  var q = '?view=' + state.view + '&date=' +
    state.y + '-' + ('0' + state.m).slice(-2) + '-' + ('0' + state.d).slice(-2);
  history.replaceState(null, '', location.pathname + q);
}

var loader = document.getElementById('loader');
var loaderTimer = null;

function load() {
  syncUrl();
  setLabel();
  if (loaderTimer) clearTimeout(loaderTimer);
  loaderTimer = setTimeout(function() { loader.classList.add('on'); }, 150);
  var settle = function(fn) {
    return function(rows) {
      clearTimeout(loaderTimer);
      loader.classList.remove('on');
      fn(rows);
    };
  };
  ['month', 'week', 'day'].forEach(function(v) {
    document.getElementById('v-' + v).classList.toggle('on', state.view === v);
  });
  document.getElementById('month-view').style.display =
    state.view === 'month' ? 'flex' : 'none';
  document.getElementById('time-view').style.display =
    state.view === 'month' ? 'none' : 'flex';
  var from, to;
  if (state.view === 'month') {
    var cs = monthCells();
    from = serial(cs[0].y, cs[0].m, cs[0].d) * MS_DAY - MS_DAY;
    to = serial(cs[41].y, cs[41].m, cs[41].d) * MS_DAY + 2 * MS_DAY;
    fetchWindow(from, to, settle(renderMonth));
  } else {
    var n = state.view === 'week' ? 7 : 1;
    var ds = gridDays(n);
    from = serial(ds[0].y, ds[0].m, ds[0].d) * MS_DAY - MS_DAY;
    to = serial(ds[n - 1].y, ds[n - 1].m, ds[n - 1].d) * MS_DAY + 2 * MS_DAY;
    fetchWindow(from, to, settle(function(rows) { renderTimeGrid(rows, n); }));
  }
}

function step(dir) {
  if (state.view === 'month') {
    var m = state.m - 1 + dir;
    state.y += Math.floor(m / 12);
    state.m = ((m % 12) + 12) % 12 + 1;
    state.d = 1;
  } else {
    var days = state.view === 'week' ? 7 : 1;
    var c = unserial(serial(state.y, state.m, state.d) + dir * days);
    state.y = c.y; state.m = c.m; state.d = c.d;
  }
  load();
}

function goToday() {
  var p = parts(Date.now());
  state.y = p.y; state.m = p.m; state.d = p.d;
  load();
}

document.getElementById('prev').onclick = function() { step(-1); };
document.getElementById('next').onclick = function() { step(1); };
document.getElementById('today').onclick = goToday;
document.getElementById('v-month').onclick = function() { state.view = 'month'; load(); };
document.getElementById('v-week').onclick = function() { state.view = 'week'; load(); };
document.getElementById('v-day').onclick = function() { state.view = 'day'; load(); };

document.addEventListener('keydown', function(e) {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' ||
      e.target.tagName === 'TEXTAREA') return;
  if (e.key === 'm') { state.view = 'month'; load(); }
  if (e.key === 'w') { state.view = 'week'; load(); }
  if (e.key === 'd') { state.view = 'day'; load(); }
  if (e.key === 't') goToday();
  if (e.key === 'ArrowLeft') step(-1);
  if (e.key === 'ArrowRight') step(1);
});

// ---- add modal ----------------------------------------------------

var back = document.getElementById('modal-back');
var kindSel = document.getElementById('f-kind');
var dowSel = document.getElementById('f-dow');
var daysDiv = document.getElementById('f-days');
var WDF = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
WD.forEach(function(d, i) {
  var o = document.createElement('option');
  o.value = d; o.textContent = WDF[i];
  dowSel.appendChild(o);
  var t = document.createElement('div');
  t.className = 'day-tog';
  t.textContent = WDF[i];
  t.dataset.d = d;
  t.onclick = function() { t.classList.toggle('on'); };
  daysDiv.appendChild(t);
});
var monSel = document.getElementById('f-month');
var bmonSel = document.getElementById('f-bmonth');
MN.forEach(function(m, i) {
  [monSel, bmonSel].forEach(function(sel) {
    var o = document.createElement('option');
    o.value = i + 1; o.textContent = m;
    sel.appendChild(o);
  });
});

var KIND_HINT = {
  'once': 'Happens a single time.',
  'daily': 'Every day at the chosen time.',
  'weekly': 'Every week on the days you pick.',
  'monthly': 'On that day number each month. Short months are skipped.',
  'monthly-nth': 'On, say, the Second Tuesday of every month.',
  'yearly': 'Once a year on the same date, from the chosen year on.',
  'every': 'A fixed interval on the clock, regardless of timezone.'
};

var cat = 'timed';

function syncFields() {
  var k = kindSel.value;
  var rc = (cat !== 'date');   // has a recurrence
  var show = {
    rc: rc,
    bf: cat === 'date',
    tf: cat === 'timed',
    af: cat === 'allday',
    wf: rc && k === 'weekly',
    mf: rc && k === 'monthly',
    nf: rc && k === 'monthly-nth',
    yf: rc && k === 'yearly',
    ef: rc && k === 'every'
  };
  Object.keys(show).forEach(function(c) {
    document.querySelectorAll('.' + c).forEach(function(el) {
      el.style.display = show[c] ? '' : 'none';
    });
  });
  document.getElementById('kind-hint').textContent = KIND_HINT[k] || '';
  document.getElementById('lbl-start').textContent =
    (k === 'once') ? 'Date & time' : 'Starting from';
}
kindSel.onchange = syncFields;

var seg = document.getElementById('cat-seg');
function setCat(c) {
  cat = c;
  seg.querySelectorAll('.seg-btn').forEach(function(b) {
    b.classList.toggle('on', b.dataset.cat === c);
  });
  syncFields();
}
seg.querySelectorAll('.seg-btn').forEach(function(b) {
  b.onclick = function() { setCat(b.dataset.cat); };
});

var zoneSel = document.getElementById('f-zone');
var dispSel = document.getElementById('zone-sel');

function fillZoneSelect(sel, zs, withDefault) {
  sel.innerHTML = '';
  if (withDefault) {
    var def = document.createElement('option');
    def.value = '';
    def.textContent = CFG.zone
      ? 'Calendar default (' + CFG.zone + ')'
      : 'Calendar default (UTC)';
    sel.appendChild(def);
  }
  var utc = document.createElement('option');
  utc.value = 'none';
  utc.textContent = 'UTC';
  sel.appendChild(utc);
  zs.forEach(function(z) {
    var o = document.createElement('option');
    o.value = z;
    o.textContent = z;
    sel.appendChild(o);
  });
}

function loadZones() {
  fetch(CAL + '/zones.json')
    .then(function(r) { return r.json(); })
    .then(function(zs) {
      fillZoneSelect(zoneSel, zs, true);
      fillZoneSelect(dispSel, zs, false);
      dispSel.value = CFG.zone || 'none';
    })
    .catch(function() {});
}

// target: pick the axis date all views orient around
var axisBtn = document.getElementById('axis-btn');
var axisInput = document.getElementById('axis-input');
axisBtn.onclick = function() {
  axisInput.value = state.y + '-' + pad2(state.m) + '-' + pad2(state.d);
  if (axisInput.showPicker) axisInput.showPicker(); else axisInput.click();
};
axisInput.onchange = function() {
  if (!axisInput.value) return;
  var p = axisInput.value.split('-');
  state.y = +p[0]; state.m = +p[1]; state.d = +p[2];
  load();
};

// feeds modal: manage the named external ICS urls
var feedsBack = document.getElementById('feeds-back');
document.getElementById('feeds-btn').onclick = function() {
  loadFeeds();
  feedsBack.classList.add('open');
};
document.getElementById('feeds-close').onclick = function() { feedsBack.classList.remove('open'); };
feedsBack.onclick = function(e) { if (e.target === feedsBack) feedsBack.classList.remove('open'); };

function loadFeeds() {
  fetch(CAL + '/feeds.json')
    .then(function(r) { return r.json(); })
    .then(function(fs) {
      var list = document.getElementById('feeds-list');
      list.innerHTML = '';
      var names = Object.keys(fs);
      if (!names.length) {
        list.innerHTML = '<div class="feed-row" style="border:none;color:#666">No feeds yet. Paste your Google Calendar secret iCal address below.</div>';
        return;
      }
      names.forEach(function(n) {
        var row = document.createElement('div');
        row.className = 'feed-row';
        var nm = document.createElement('span');
        nm.className = 'fn';
        nm.textContent = n;
        var u = document.createElement('span');
        u.className = 'fu';
        u.textContent = fs[n];
        var x = document.createElement('button');
        x.className = 'fx';
        x.textContent = '✕';
        x.title = 'Remove feed';
        x.onclick = function() {
          poke({ action: 'del-feed', name: n }, function() { setTimeout(loadFeeds, 300); });
        };
        row.appendChild(nm); row.appendChild(u); row.appendChild(x);
        list.appendChild(row);
      });
    })
    .catch(function() {});
}

document.getElementById('feed-add').onclick = function() {
  var st = document.getElementById('feeds-status');
  var n = document.getElementById('feed-name').value.trim();
  var u = document.getElementById('feed-url').value.trim();
  if (!n || !u) { st.textContent = 'name and url required'; return; }
  st.textContent = '';
  poke({ action: 'add-feed', name: n, url: u }, function(ok) {
    if (!ok) { st.textContent = 'save failed'; return; }
    document.getElementById('feed-name').value = '';
    document.getElementById('feed-url').value = '';
    setTimeout(loadFeeds, 300);
  });
};

// sync: materialize external ICS feeds into this calendar
var syncBtn = document.getElementById('sync-btn');
syncBtn.onclick = function() {
  syncBtn.disabled = true;
  syncBtn.style.opacity = '0.4';
  poke({ action: 'sync-feeds' }, function() {
    setTimeout(function() {
      syncBtn.disabled = false;
      syncBtn.style.opacity = '';
      load();
    }, 1500);
  });
};

var clockBtn = document.getElementById('clock-btn');
function syncClockBtn() { clockBtn.textContent = H12 ? '12h' : '24h'; }
syncClockBtn();
clockBtn.onclick = function() {
  H12 = !H12;
  localStorage.setItem('cal-h12', H12 ? '1' : '0');
  syncClockBtn();
  load();
};

dispSel.onchange = function() {
  var z = dispSel.value;
  poke({ action: 'config', zone: z }, function() {
    CFG.zone = (z === 'none') ? '' : z;
    mkfmt();
    loadZones();
    load();
  });
};

// globe: one click to adopt the browser's timezone as the calendar zone
var globeBtn = document.getElementById('globe-btn');
var browserZone = '';
try { browserZone = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) {}
if (browserZone) {
  globeBtn.title = 'Set calendar timezone to your browser timezone (' + browserZone + ')';
}
globeBtn.onclick = function() {
  if (!browserZone) return;
  var known = [].some.call(dispSel.options, function(o) { return o.value === browserZone; });
  if (!known) { alert('The ship does not know the zone ' + browserZone); return; }
  if (dispSel.value === browserZone) return;
  dispSel.value = browserZone;
  dispSel.onchange();
};

function pad2(x) { return ('0' + x).slice(-2); }

var editCtx = null;

function openModal(opts) {
  opts = opts || {};
  editCtx = null;
  document.getElementById('modal-title').textContent = 'New Event';
  document.getElementById('edit-scope').classList.remove('on');
  var p = opts.date || parts(Date.now());
  document.getElementById('f-date').value = p.y + '-' + pad2(p.m) + '-' + pad2(p.d);
  document.getElementById('f-name').value = '';
  document.getElementById('f-note').value = '';
  document.getElementById('f-count').value = 0;
  document.getElementById('f-until').value = '';
  document.getElementById('f-days-n').value = 1;
  document.getElementById('f-dur').value = 60;
  document.getElementById('f-bmonth').value = p.m;
  document.getElementById('f-bday').value = p.d;
  if (opts.time) document.getElementById('f-time').value = opts.time;
  if (opts.kind) kindSel.value = opts.kind;
  var w = WD[(new Date(pserial(p) * MS_DAY).getUTCDay() + 6) % 7];
  daysDiv.querySelectorAll('.day-tog').forEach(function(t) {
    t.classList.toggle('on', t.dataset.d === w);
  });
  dowSel.value = w;
  zoneSel.value = '';
  setCat('timed');
  back.classList.add('open');
}

function msToUTC(ms) {
  var d = new Date(ms);
  return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate(),
           hh: d.getUTCHours(), mm: d.getUTCMinutes() };
}

function openEdit(d, target) {
  editCtx = { id: d.id, idx: target.idx, occ: parts(target.l) };
  document.getElementById('modal-title').textContent = 'Edit Event';
  var dm = d.meta || {};
  document.getElementById('f-name').value = dm.name || '';
  document.getElementById('f-note').value = dm.note || '';
  document.getElementById('f-color').value = dm.color || '#4a6a8a';

  // edit scope only for a recurring series
  var recurring = (d.cat !== 'date' && d.kind !== 'once');
  var scope = document.getElementById('edit-scope');
  scope.classList.toggle('on', recurring);
  if (recurring) document.querySelector('input[name="scope"][value="all"]').checked = true;

  if (d.cat === 'date') {
    document.getElementById('f-bmonth').value = d.month || 1;
    document.getElementById('f-bday').value = d.day || 1;
    setCat('date');
    back.classList.add('open');
    return;
  }
  kindSel.value = d.kind;
  var a = d.args || {};
  var sp = msToUTC(d.start_ms);
  document.getElementById('f-date').value = sp.y + '-' + pad2(sp.m) + '-' + pad2(sp.d);
  var atMin = (a.at !== undefined) ? a.at : (sp.hh * 60 + sp.mm);
  document.getElementById('f-time').value = pad2(Math.floor(atMin / 60)) + ':' + pad2(atMin % 60);
  document.getElementById('f-dur').value = d.dur_min || 0;
  document.getElementById('f-days-n').value = d.span_days || 1;
  document.getElementById('f-count').value = d.count || 0;
  document.getElementById('f-until').value = '';
  document.getElementById('f-period').value = a.period || 60;
  document.getElementById('f-day').value = d.kind === 'monthly' ? (a.day || 1) : 1;
  if (d.kind === 'monthly-nth') {
    document.getElementById('f-ord').value = a.ord || 'first';
    dowSel.value = a.day || 'mon';
  }
  if (d.kind === 'yearly') {
    document.getElementById('f-month').value = a.month || 1;
    document.getElementById('f-yday').value = a.day || 1;
  }
  daysDiv.querySelectorAll('.day-tog').forEach(function(t) {
    t.classList.toggle('on', (a.days || []).indexOf(t.dataset.d) >= 0);
  });
  zoneSel.value = d.zone === 'none' ? 'none' : (d.zone || '');
  setCat(d.cat);
  back.classList.add('open');
}

document.getElementById('add-btn').onclick = function() { openModal(); };
document.getElementById('modal-close').onclick = function() { back.classList.remove('open'); };
back.onclick = function(e) { if (e.target === back) back.classList.remove('open'); };

// the kind-specific args object, keyed the way the kind file reads them
function kindArgs(k, tv) {
  var a = {};
  if (k === 'weekly') {
    a.days = [].slice.call(daysDiv.querySelectorAll('.on')).map(function(t) { return t.dataset.d; });
  }
  if (k === 'monthly') a.day = +document.getElementById('f-day').value;
  if (k === 'monthly-nth') {
    a.ord = document.getElementById('f-ord').value;
    a.day = dowSel.value;
  }
  if (k === 'yearly') {
    a.month = +document.getElementById('f-month').value;
    a.day = +document.getElementById('f-yday').value;
  }
  if (k === 'every') a.period = +document.getElementById('f-period').value || 60;
  if (k !== 'once' && k !== 'every') a.at = (+tv[0]) * 60 + (+tv[1]);
  return a;
}

document.getElementById('f-save').onclick = function() {
  var st = document.getElementById('f-status');
  var name = document.getElementById('f-name').value.trim();
  if (!name) { st.textContent = 'name required'; return; }
  var color = document.getElementById('f-color').value;
  var note = document.getElementById('f-note').value;
  var body = { action: 'add-event', cat: cat, meta: { name: name, color: color, note: note } };

  if (cat === 'date') {
    body.month = +document.getElementById('f-bmonth').value;
    body.day = +document.getElementById('f-bday').value;
  } else {
    var k = kindSel.value;
    var dv = document.getElementById('f-date').value;
    if (!dv) { st.textContent = 'date required'; return; }
    var p = dv.split('-');
    var tv = (document.getElementById('f-time').value || '00:00').split(':');
    // once/every timed anchor carries the time; grid kinds day-floor
    body.kind = k;
    body.start_ms = (cat === 'timed' && (k === 'once' || k === 'every'))
      ? Date.UTC(+p[0], +p[1] - 1, +p[2], +tv[0], +tv[1])
      : Date.UTC(+p[0], +p[1] - 1, +p[2]);
    body.args = kindArgs(k, tv);
    if (k === 'weekly' && !body.args.days.length) { st.textContent = 'pick weekdays'; return; }
    if (cat === 'timed') {
      var zone = zoneSel.value;
      if (zone) body.zone = zone;
      body.fin = 'dur';
      body.dur_min = +document.getElementById('f-dur').value || 0;
    } else {
      body.span_days = +document.getElementById('f-days-n').value || 1;
    }
    if (k !== 'once') {
      var cnt = +document.getElementById('f-count').value;
      if (cnt > 0) body.count = cnt;
      var uv = document.getElementById('f-until').value;
      if (!cnt && uv) {
        var up = uv.split('-');
        body.until_ms = Date.UTC(+up[0], +up[1] - 1, +up[2] + 1);
      }
    }
  }

  var finish = function(ok) {
    if (!ok) { st.textContent = 'save failed'; return; }
    st.textContent = '';
    back.classList.remove('open');
    setTimeout(load, 400);
  };

  if (!editCtx) { poke(body, finish); return; }

  var scopeEl = document.querySelector('input[name="scope"]:checked');
  var recurring = (cat !== 'date' && kindSel.value !== 'once');
  var scope = (!recurring || !scopeEl) ? 'all' : scopeEl.value;

  if (scope === 'all') {
    body.action = 'edit-event';
    body.id = editCtx.id;
    poke(body, finish);
  } else if (scope === 'following') {
    var occMs = Date.UTC(editCtx.occ.y, editCtx.occ.m - 1, editCtx.occ.d);
    body.start_ms = occMs;
    poke({ action: 'cap-event', id: editCtx.id, dom: editCtx.idx }, function(ok) {
      if (!ok) { finish(false); return; }
      poke(body, finish);
    });
  } else {
    // only this one: skip it, add a one-off replacement in the same category
    var only = { action: 'add-event', cat: cat, meta: body.meta, kind: 'once' };
    if (cat === 'timed') {
      only.start_ms = Date.UTC(editCtx.occ.y, editCtx.occ.m - 1, editCtx.occ.d, editCtx.occ.hh, editCtx.occ.mm);
      if (body.zone) only.zone = body.zone;
      only.fin = 'dur'; only.dur_min = body.dur_min || 0;
    } else {
      only.start_ms = Date.UTC(editCtx.occ.y, editCtx.occ.m - 1, editCtx.occ.d);
      only.span_days = body.span_days || 1;
    }
    poke({ action: 'skip-event', id: editCtx.id, idx: editCtx.idx }, function(ok) {
      if (!ok) { finish(false); return; }
      poke(only, finish);
    });
  }
};

// ---- boot ---------------------------------------------------------

function boot() {
  mkfmt();
  var q = new URLSearchParams(location.search);
  var v = q.get('view');
  var dt = (q.get('date') || '').split('-');
  if (v === 'month' || v === 'week' || v === 'day') state.view = v;
  if (dt.length === 3 && +dt[0] > 1970) {
    state.y = +dt[0]; state.m = +dt[1]; state.d = +dt[2];
    load();
    return;
  }
  goToday();
}

fetch(CAL + '/config.json')
  .then(function(r) { return r.json(); })
  .then(function(cfg) {
    CFG.zone = cfg.zone || '';
    CFG.ball = cfg.ball || '';
    CFG.title = cfg.title || 'Calendar';
    loadZones();
    boot();
  })
  .catch(boot);
