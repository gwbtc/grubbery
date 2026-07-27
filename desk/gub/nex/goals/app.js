// goals: DAG stores as a navigable outline. Reads store grubs via
// the ball, mutations poke main.sig with goal-action json.
//
// The tree is a place, not a list: per-node fold (remembered),
// zoom-to-subtree (hash-addressed, bookmarkable), and a frontier
// lens that shows only paths to actionable undone goals.

var API = '/grubbery/api';
var BALL = 'apps/goals.goals';
var storeName = '';
var goals = {};
var zoomId = '0';
var parentForNew = '0';
var view = localStorage.getItem('goals-view') || 'tree';
if (['tree', 'frontier', 'gantt', 'kanban'].indexOf(view) < 0) view = 'tree';
var folds = {};

function el(id) { return document.getElementById(id); }

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function loadFolds() {
  try { folds = JSON.parse(localStorage.getItem('goals-fold-' + storeName)) || {}; }
  catch (e) { folds = {}; }
}
function saveFolds() {
  localStorage.setItem('goals-fold-' + storeName, JSON.stringify(folds));
}

function nodeDone(n) {
  return !!(n && n.status && n.status.length && n.status[0].done);
}
function isDone(g) { return nodeDone(g.end); }

function summaryOf(g) { return (g.data && g.data.summary) || '(no summary)'; }

function lineage(id) {
  var out = [];
  var cur = id;
  while (cur && cur !== '0' && goals[cur]) {
    out.unshift(cur);
    cur = goals[cur].parent;
  }
  return out;
}

// the engine's harvest rule, ported: a goal is on the frontier iff
// it's actionable, its end isn't done, and no incomplete work flows
// into it (walk inflow of the incomplete graph; empty harvest at an
// actionable end-node means the goal itself is ready)
function harvest(rootId) {
  var memo = {};
  function nkey(nid) { return nid['goal-id'] + '|' + nid.point; }
  function visit(nid) {
    var key = nkey(nid);
    if (memo[key]) return memo[key];
    memo[key] = {};
    var gid = nid['goal-id'];
    var g = goals[gid];
    if (!g) return {};
    if (isDone(g)) return (memo[key] = {});
    var node = nid.point === 'start' ? g.start : g.end;
    var acc = {};
    ((node && node.inflow) || []).forEach(function(up) {
      var res = visit(up);
      Object.keys(res).forEach(function(k) { acc[k] = true; });
    });
    if (!Object.keys(acc).length && nid.point === 'end' && g.actionable) {
      acc[gid] = true;
    }
    return (memo[key] = acc);
  }
  return Object.keys(visit({ 'goal-id': rootId, point: 'end' }));
}

function setHash() {
  var h = '#' + storeName + (zoomId !== '0' ? '/' + zoomId : '');
  if (location.hash !== h) history.replaceState(null, '', h);
}

function readHash() {
  var h = location.hash.replace(/^#/, '');
  if (!h) return;
  var parts = h.split('/');
  if (parts[0]) storeName = parts[0];
  zoomId = parts[1] || '0';
}

function fetchStores() {
  return fetch(API + '/tree/' + BALL + '/store')
    .then(function(r) { return r.json(); })
    .then(function(t) {
      var names = Object.keys((t && t.files) || {})
        .filter(function(n) { return n.slice(-11) === '.goal-store'; })
        .map(function(n) { return n.slice(0, -11); });
      var sel = el('store-select');
      sel.innerHTML = '';
      if (!names.length) { storeName = ''; return; }
      if (names.indexOf(storeName) < 0) {
        storeName = localStorage.getItem('goals-store') || '';
        if (names.indexOf(storeName) < 0) storeName = names.sort()[0];
      }
      names.sort().forEach(function(n) {
        var o = document.createElement('option');
        o.value = n; o.textContent = n;
        if (n === storeName) o.selected = true;
        sel.appendChild(o);
      });
    })
    .catch(function() {});
}

function fetchStore() {
  if (!storeName) { goals = {}; render(); return Promise.resolve(); }
  loadFolds();
  el('loader').classList.add('on');
  return fetch('/grubbery/ball/' + BALL + '/store/' + storeName + '.goal-store?blot=/json')
    .then(function(r) { if (!r.ok) throw 0; return r.json(); })
    .then(function(s) { goals = s || {}; })
    .catch(function() { goals = {}; })
    .finally(function() {
      el('loader').classList.remove('on');
      if (zoomId !== '0' && !goals[zoomId]) zoomId = '0';
      render();
    });
}

function poke(body, cb) {
  fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function() { setTimeout(cb || fetchStore, 450); });
}

function act(type, extra) {
  var body = { action: 'goal-action', store: storeName, type: type };
  Object.keys(extra || {}).forEach(function(k) { body[k] = extra[k]; });
  poke(body);
}

function zoomTo(id) {
  zoomId = id;
  setHash();
  render();
}

function goalRow(id, depth) {
  var g = goals[id];
  if (!g) return null;
  var done = isDone(g);
  var started = nodeDone(g.start) && !done;
  var summary = summaryOf(g);
  var kids = (g.children || []).filter(function(c) { return goals[c]; });
  var folded = !!folds[id];
  var row = document.createElement('div');
  row.className = 'goal' + (done ? ' done' : '') + (depth === 0 ? ' top' : '');
  var badges = '';
  if (started) badges += '<span class="badge started">started</span>';
  if (g.actionable && !done) badges += '<span class="badge actionable">actionable</span>';
  var caret = kids.length
    ? '<button class="caret' + (folded ? '' : ' open') + '" title="' + (folded ? 'expand' : 'collapse') + '">▸</button>'
    : '<span class="caret-spacer"></span>';
  row.innerHTML =
    caret +
    '<input type="checkbox" class="check"' + (done ? ' checked' : '') + ' title="' + (done ? 'mark undone' : 'mark done') + '">' +
    '<div class="goal-main">' +
      '<span class="goal-text" title="zoom in">' + esc(summary) + '</span>' + badges +
      (kids.length && folded ? '<span class="kid-count">' + kids.length + '</span>' : '') +
    '</div>' +
    '<div class="goal-actions">' +
      '<button class="mini" data-a="info" title="Details">i</button>' +
      '<button class="mini" data-a="add" title="Add subgoal">+</button>' +
      '<button class="mini del" data-a="del" title="Delete">✕</button>' +
    '</div>';
  var c = row.querySelector('.caret');
  if (c && kids.length) {
    c.onclick = function() {
      folds[id] = !folds[id];
      saveFolds();
      render();
    };
  }
  row.querySelector('.check').onchange = function() {
    act(done ? 'undone' : 'done', { id: id });
  };
  row.querySelector('.goal-text').onclick = function() { zoomTo(id); };
  row.querySelector('[data-a="info"]').onclick = function() { openDetail(id); };
  row.querySelector('[data-a="add"]').onclick = function() { openModal(id, summary); };
  row.querySelector('[data-a="del"]').onclick = function() {
    if (confirm('Delete this goal' + (kids.length ? ' and orphan its children' : '') + '?')) {
      act('delete', { id: id });
    }
  };
  return row;
}

function renderInto(container, id, depth) {
  var g = goals[id];
  if (!g) return;
  var row = goalRow(id, depth);
  if (!row) return;
  container.appendChild(row);
  if (folds[id]) return;
  var kids = (g.children || []).filter(function(c) { return goals[c]; });
  if (!kids.length) return;
  var nest = document.createElement('div');
  nest.className = 'kids';
  container.appendChild(nest);
  kids.forEach(function(c) { renderInto(nest, c, depth + 1); });
}

function frontierRow(id) {
  var g = goals[id];
  var row = document.createElement('div');
  row.className = 'goal fr';
  var path = lineage(id).slice(0, -1).map(function(a) {
    return esc(summaryOf(goals[a]));
  }).join(' › ');
  row.innerHTML =
    '<input type="checkbox" class="check" title="mark done">' +
    '<div class="goal-main fr-main">' +
      '<span class="goal-text" title="zoom to subtree">' + esc(summaryOf(g)) + '</span>' +
      (path ? '<div class="fr-path">' + path + '</div>' : '') +
    '</div>';
  row.querySelector('.check').onchange = function() { act('done', { id: id }); };
  row.querySelector('.goal-text').onclick = function() { openDetail(id); };
  return row;
}

function setView(v) {
  view = v;
  localStorage.setItem('goals-view', v);
  render();
}

// explicit precedence edges: predecessors and successors over the
// start/end inflow/outflow, minus the structural parent/child links
function depsOf(id) {
  var g = goals[id];
  var fam = {};
  fam[g.parent || '0'] = true;
  (g.children || []).forEach(function(c) { fam[c] = true; });
  fam[id] = true;
  function collect(nodes, dir) {
    var seen = {};
    nodes.forEach(function(node) {
      (((node || {})[dir]) || []).forEach(function(nid) {
        var gid = nid['goal-id'];
        if (!fam[gid] && goals[gid]) seen[gid] = true;
      });
    });
    return Object.keys(seen);
  }
  return {
    after: collect([g.start, g.end], 'inflow'),
    before: collect([g.start, g.end], 'outflow')
  };
}

var detailId = null;

function openDetail(id) {
  var g = goals[id];
  if (!g) return;
  detailId = id;
  var crumbs = lineage(id).slice(0, -1).map(function(a) {
    return esc(summaryOf(goals[a]));
  }).join(' › ');
  el('d-crumbs').textContent = crumbs || '(top level)';
  el('d-summary').value = summaryOf(g);
  el('d-actionable').checked = !!g.actionable;
  el('d-started').checked = nodeDone(g.start);
  el('d-done').checked = isDone(g);
  var deps = depsOf(id);
  var dd = el('d-deps');
  dd.innerHTML = '';
  function depSection(label, ids, cls) {
    if (!ids.length) return;
    var sec = document.createElement('div');
    sec.className = 'd-dep-sec';
    var h = document.createElement('span');
    h.className = 'd-dep-label ' + cls;
    h.textContent = label;
    sec.appendChild(h);
    ids.forEach(function(did) {
      var chip = document.createElement('button');
      chip.className = 'd-dep-chip' + (isDone(goals[did]) ? ' done' : '');
      chip.textContent = summaryOf(goals[did]);
      chip.onclick = function() { openDetail(did); };
      sec.appendChild(chip);
    });
    dd.appendChild(sec);
  }
  depSection('waiting on', deps.after.filter(function(d) { return !isDone(goals[d]); }), 'wait');
  depSection('after (done)', deps.after.filter(function(d) { return isDone(goals[d]); }), 'past');
  depSection('unlocks', deps.before, 'unlock');
  var kids = (g.children || []).filter(function(c) { return goals[c]; });
  if (kids.length) {
    var done = kids.filter(function(c) { return isDone(goals[c]); }).length;
    var sub = document.createElement('div');
    sub.className = 'd-dep-sec';
    sub.innerHTML = '<span class="d-dep-label">subgoals</span><span class="m-note">' +
      done + ' of ' + kids.length + ' done</span>';
    dd.appendChild(sub);
  }
  el('detail-back').classList.add('open');
}

function closeDetail() {
  detailId = null;
  el('detail-back').classList.remove('open');
}

// descendants of the zoom root (goal ids), zoom root excluded
function subtreeIds(rootId) {
  var out = [];
  function walk(id) {
    (goals[id] && goals[id].children || []).forEach(function(c) {
      if (!goals[c]) return;
      out.push(c);
      walk(c);
    });
  }
  walk(rootId);
  return out;
}

// longest-chain depth per node key "id|point", relaxed over inflow
function nodeDepths(ids) {
  var inSet = {};
  ids.forEach(function(id) { inSet[id] = true; });
  var depths = {};
  ids.forEach(function(id) {
    depths[id + '|start'] = 0;
    depths[id + '|end'] = 0;
  });
  var changed = true;
  var guard = 0;
  while (changed && guard < ids.length * 2 + 4) {
    changed = false;
    guard++;
    ids.forEach(function(id) {
      var g = goals[id];
      ['start', 'end'].forEach(function(pt) {
        var node = pt === 'start' ? g.start : g.end;
        var best = 0;
        ((node && node.inflow) || []).forEach(function(up) {
          var uid = up['goal-id'];
          if (!inSet[uid] && uid !== zoomId) return;
          var d = depths[uid + '|' + up.point];
          if (d != null && d + 1 > best) best = d + 1;
        });
        var key = id + '|' + pt;
        if (best > depths[key]) { depths[key] = best; changed = true; }
      });
    });
  }
  return depths;
}

function renderGantt(container) {
  var all = subtreeIds(zoomId);
  if (!all.length) {
    container.innerHTML = '<div class="empty">nothing to chart under here</div>';
    return;
  }
  var depths = nodeDepths(all);
  var maxd = 0;
  all.forEach(function(id) {
    maxd = Math.max(maxd, depths[id + '|end'] || 0);
  });
  var order = [];
  function walk(id) {
    order.push(id);
    if (folds[id]) return;
    (goals[id].children || []).forEach(function(c) {
      if (goals[c]) walk(c);
    });
  }
  ((goals[zoomId] && goals[zoomId].children) || []).forEach(function(c) {
    if (goals[c]) walk(c);
  });
  var unit = 110;
  var wrap = document.createElement('div');
  wrap.className = 'gantt-scroll';
  var inner = document.createElement('div');
  inner.className = 'gantt';
  inner.style.width = ((maxd + 1) * unit + 40) + 'px';
  order.forEach(function(id) {
    var g = goals[id];
    var kids = (g.children || []).filter(function(c) { return goals[c]; });
    var s = depths[id + '|start'] || 0;
    var e = Math.max(depths[id + '|end'] || 0, s + 1);
    var done = isDone(g);
    var started = nodeDone(g.start) && !done;
    var row = document.createElement('div');
    row.className = 'gantt-row';
    var bar = document.createElement('div');
    bar.className = 'gantt-bar' +
      (done ? ' done' : started ? ' started' : g.actionable ? ' actionable' : '');
    bar.style.left = (s * unit) + 'px';
    bar.style.width = ((e - s) * unit - 10) + 'px';
    if (kids.length) {
      var c = document.createElement('span');
      c.className = 'gantt-caret';
      c.textContent = folds[id] ? '▸' : '▾';
      c.title = folds[id] ? 'expand' : 'collapse';
      c.onclick = function(ev) {
        ev.stopPropagation();
        folds[id] = !folds[id];
        saveFolds();
        render();
      };
      bar.appendChild(c);
    }
    var label = document.createElement('span');
    label.className = 'gantt-label';
    label.textContent = summaryOf(g) +
      (kids.length && folds[id] ? ' (' + kids.length + ')' : '');
    bar.appendChild(label);
    bar.title = summaryOf(g);
    bar.onclick = function() {
      setView('tree');
      zoomTo(kids.length ? id : (g.parent || '0'));
    };
    row.appendChild(bar);
    inner.appendChild(row);
  });
  wrap.appendChild(inner);
  container.appendChild(wrap);
}

function renderCrumbs() {
  var bar = el('crumbs');
  bar.innerHTML = '';
  if (!storeName) { bar.style.display = 'none'; return; }
  var line = lineage(zoomId);
  bar.style.display = (line.length || view !== 'tree') ? '' : 'none';
  var rootBtn = document.createElement('button');
  rootBtn.className = 'crumb';
  rootBtn.textContent = storeName;
  rootBtn.onclick = function() { zoomTo('0'); };
  bar.appendChild(rootBtn);
  line.forEach(function(id) {
    var sep = document.createElement('span');
    sep.className = 'crumb-sep';
    sep.textContent = '›';
    bar.appendChild(sep);
    var b = document.createElement('button');
    b.className = 'crumb' + (id === zoomId ? ' here' : '');
    b.textContent = summaryOf(goals[id]);
    b.onclick = function() { zoomTo(id); };
    bar.appendChild(b);
  });
}

// feather icons, verbatim (chevrons-up / chevrons-down)
var SVG_COLLAPSE =
  '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-chevrons-up"><polyline points="17 11 12 6 7 11"></polyline><polyline points="17 18 12 13 7 18"></polyline></svg>';
var SVG_EXPAND =
  '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-chevrons-down"><polyline points="7 13 12 18 17 13"></polyline><polyline points="7 6 12 11 17 6"></polyline></svg>';

function anyFoldOpen() {
  return Object.keys(goals).some(function(id) {
    return id !== '0' && (goals[id].children || []).length && !folds[id];
  });
}

function kanbanCard(id, col, ready) {
  var g = goals[id];
  var card = document.createElement('div');
  card.className = 'kb-card' + (col === 'done' ? ' done' : '');
  var path = lineage(id).slice(0, -1).map(function(a) {
    return esc(summaryOf(goals[a]));
  }).join(' › ');
  card.innerHTML =
    '<div class="kb-text">' + esc(summaryOf(g)) + '</div>' +
    (path ? '<div class="fr-path">' + path + '</div>' : '') +
    '<div class="kb-acts"></div>';
  card.querySelector('.kb-text').onclick = function() { openDetail(id); };
  var acts = card.querySelector('.kb-acts');
  function btn(label, fn) {
    var b = document.createElement('button');
    b.className = 'mini kb-btn';
    b.textContent = label;
    b.onclick = fn;
    acts.appendChild(b);
  }
  if (col === 'ready') btn('start', function() { act('done', { id: id, point: 'start' }); });
  if (col === 'ready' || col === 'started') btn('finish', function() { act('done', { id: id }); });
  if (col === 'started') btn('unstart', function() { act('undone', { id: id, point: 'start' }); });
  if (col === 'done') btn('reopen', function() { act('undone', { id: id }); });
  return card;
}

function renderKanban(container) {
  var ids = subtreeIds(zoomId);
  if (!ids.length) {
    container.innerHTML = '<div class="empty">nothing to board under here</div>';
    return;
  }
  var ready = {};
  harvest(zoomId).forEach(function(id) { ready[id] = true; });
  var cols = { blocked: [], ready: [], started: [], done: [] };
  ids.forEach(function(id) {
    var g = goals[id];
    if (isDone(g)) cols.done.push(id);
    else if (nodeDone(g.start)) cols.started.push(id);
    else if (ready[id]) cols.ready.push(id);
    else cols.blocked.push(id);
  });
  var board = document.createElement('div');
  board.className = 'kanban';
  [['blocked', 'blocked'], ['ready', 'ready'], ['started', 'started'], ['done', 'done']]
    .forEach(function(pair) {
      var key = pair[0];
      var colEl = document.createElement('div');
      colEl.className = 'kb-col';
      colEl.innerHTML =
        '<div class="kb-head kb-' + key + '">' + pair[1] +
        ' <span class="kb-count">' + cols[key].length + '</span></div>';
      cols[key].forEach(function(id) {
        colEl.appendChild(kanbanCard(id, key, ready));
      });
      board.appendChild(colEl);
    });
  container.appendChild(board);
}

function render() {
  setHash();
  renderCrumbs();
  el('view-tree').classList.toggle('active', view === 'tree');
  el('view-frontier').classList.toggle('active', view === 'frontier');
  el('view-gantt').classList.toggle('active', view === 'gantt');
  el('view-kanban').classList.toggle('active', view === 'kanban');
  el('fold-all').style.display = view === 'frontier' ? 'none' : '';
  el('fold-all').innerHTML = anyFoldOpen() ? SVG_COLLAPSE : SVG_EXPAND;
  el('fold-all').title = anyFoldOpen() ? 'Collapse everything' : 'Expand everything';
  el('tree-bar').style.display =
    (view !== 'frontier' || el('crumbs').style.display !== 'none') ? '' : 'none';
  var tree = el('tree');
  tree.innerHTML = '';
  if (!storeName) {
    tree.innerHTML = '<div class="empty">no stores yet — make one</div>';
    return;
  }
  if (view === 'frontier') {
    var ready = harvest(zoomId).sort(function(a, b) {
      return summaryOf(goals[a]).localeCompare(summaryOf(goals[b]));
    });
    if (!ready.length) {
      tree.innerHTML = '<div class="empty">nothing ready under here — decompose or mark something actionable</div>';
      return;
    }
    ready.forEach(function(id) { tree.appendChild(frontierRow(id)); });
    return;
  }
  if (view === 'gantt') {
    renderGantt(tree);
    return;
  }
  if (view === 'kanban') {
    renderKanban(tree);
    return;
  }
  var root = goals[zoomId];
  var tops = ((root && root.children) || []).filter(function(c) { return goals[c]; });
  if (!tops.length) {
    tree.innerHTML = zoomId === '0'
      ? '<div class="empty">empty store — add a root goal</div>'
      : '<div class="empty">no subgoals — add one</div>';
    return;
  }
  tops.forEach(function(c) { renderInto(tree, c, 0); });
}

function openModal(parentId, parentSummary) {
  parentForNew = parentId;
  el('m-title').textContent = parentId === '0' ? 'new root goal' : 'new subgoal';
  el('m-parent').textContent = parentId === '0' ? '' : 'under: ' + parentSummary;
  el('m-summary').value = '';
  el('modal-back').classList.add('open');
  el('m-summary').focus();
}

el('store-select').onchange = function() {
  storeName = this.value;
  localStorage.setItem('goals-store', storeName);
  zoomId = '0';
  setHash();
  fetchStore();
};

el('new-store').onclick = function() {
  var n = prompt('new store name (short, no spaces):');
  if (!n) return;
  n = n.trim().toLowerCase().replace(/[^a-z0-9-]/g, '-');
  if (!n) return;
  poke({ action: 'create-store', name: n }, function() {
    storeName = n;
    localStorage.setItem('goals-store', n);
    zoomId = '0';
    fetchStores().then(fetchStore);
  });
};

el('new-root').onclick = function() {
  if (!storeName) { el('new-store').click(); return; }
  openModal(zoomId, zoomId === '0' ? '' : summaryOf(goals[zoomId]));
};

el('fold-all').onclick = function() {
  var anyOpen = anyFoldOpen();
  Object.keys(goals).forEach(function(id) {
    if (id !== '0' && (goals[id].children || []).length) folds[id] = anyOpen;
  });
  saveFolds();
  render();
};

el('view-tree').onclick = function() { setView('tree'); };
el('view-frontier').onclick = function() { setView('frontier'); };
el('view-gantt').onclick = function() { setView('gantt'); };
el('view-kanban').onclick = function() { setView('kanban'); };

el('m-cancel').onclick = function() { el('modal-back').classList.remove('open'); };
el('modal-back').onclick = function(e) {
  if (e.target === el('modal-back')) el('modal-back').classList.remove('open');
};

el('m-save').onclick = function() {
  var summary = el('m-summary').value.trim();
  if (!summary) return;
  act('create', { parent: parentForNew, summary: summary });
  el('modal-back').classList.remove('open');
};

el('d-close').onclick = closeDetail;
el('detail-back').onclick = function(e) {
  if (e.target === el('detail-back')) closeDetail();
};
el('d-zoom').onclick = function() {
  var id = detailId;
  closeDetail();
  setView('tree');
  zoomTo(id);
};
el('d-add').onclick = function() {
  var id = detailId;
  closeDetail();
  openModal(id, summaryOf(goals[id]));
};
el('d-save').onclick = function() {
  var id = detailId;
  if (!id || !goals[id]) return;
  var g = goals[id];
  var pokes = [];
  var s = el('d-summary').value.trim();
  if (s && s !== summaryOf(g)) {
    pokes.push({ type: 'update', id: id, data: JSON.stringify({ summary: s }) });
  }
  if (el('d-actionable').checked !== !!g.actionable) {
    pokes.push({ type: 'set-actionable', id: id, actionable: el('d-actionable').checked });
  }
  if (el('d-started').checked !== nodeDone(g.start)) {
    pokes.push({ type: el('d-started').checked ? 'done' : 'undone', id: id, point: 'start' });
  }
  if (el('d-done').checked !== isDone(g)) {
    pokes.push({ type: el('d-done').checked ? 'done' : 'undone', id: id });
  }
  closeDetail();
  if (!pokes.length) return;
  var i = 0;
  (function next() {
    if (i >= pokes.length) { fetchStore(); return; }
    var p = pokes[i++];
    var body = { action: 'goal-action', store: storeName };
    Object.keys(p).forEach(function(k) { if (k !== 'type') body[k] = p[k]; });
    body.type = p.type;
    poke(body, next);
  })();
};

window.addEventListener('hashchange', function() {
  var prevStore = storeName;
  readHash();
  if (storeName !== prevStore) fetchStores().then(fetchStore);
  else render();
});

readHash();
fetchStores().then(fetchStore);
