// <pane-split> — a tmux-style recursive pane tree.
//
// EXPERIMENTAL. Composes <split-view> (which must be defined first) into an
// arbitrarily-nested tiling tree. Each leaf holds host-supplied content; every
// internal node is a <split-view>.
//
// MODEL IS TRUTH. Layout lives in the tree, not in the DOM:
//   - each split node has a `ratio` (0..1) — the START child's fraction of the
//     split. Proportions, so they survive any dimension change (zoom, window).
//   - `fold` ('start'|'end'|null) marks a collapsed side — a non-destructive
//     flag; the ratio underneath is untouched, so uncollapse restores exactly.
//   - zoom is a STACK of nodes; the top is shown maximized. Zoom in pushes,
//     out pops, reset clears — nest as deep as you like.
// #applyLayout() writes each split's ratio (as a %) and fold to its split-view.
// Zoom is separate and orthogonal: it picks which subtree is the VIEWPORT and
// mounts that rectangle to fill the container (#applyZoom) — the partition is a
// binary tree of rectangles, and zoom just chooses which rectangle you're in.
//
// CONTRACT
//   properties (set from the host, in JS):
//     leafFactory  (id) => HTMLElement    content for a new leaf (required)
//     onDestroy    (id, bodyEl) => void   teardown when a leaf closes (optional)
//   attribute: prefix  — the chord, "mod+key" (default "ctrl+b")
//   methods: seed · splitRight/splitDown · close · focusPane(id) · focusMove ·
//     zoomToggle/zoomOut/zoomReset · collapse · nudge · markToggle · swap
//   getters: activeId · leafIds · cursor · highlight
//   events (bubbling+composed): ps-focus · ps-split · ps-close · ps-empty · ps-zoom
//
//   KEYS (after the prefix): % / | split right · " / - split down ·
//     c collapse/expand cursor (keeps selection) · z zoom in · Z zoom out ·
//     x close (leaf or subtree) · o cycle · m mark · space swap (mark/sibling) ·
//     [ climb · ] descend · Tab sibling · Esc reset cursor · h cycle highlight ·
//     1-9 jump · arrows move · shift+arrows / r resize. move & resize are sticky
//     (bare arrows repeat until a non-arrow key / Esc; no timer).
//
// Light DOM (leaf content wants the normal document); the JS tree is the source
// of truth and the DOM mirrors it.

const STYLE_ID = 'pane-split-style';
const CSS = `
  pane-split { display:block; width:100%; height:100%; min-width:0; min-height:0; position:relative; }
  pane-split split-view { width:100%; height:100%; }
  .ps-pane {
    position:relative; width:100%; height:100%; min-width:0; min-height:0;
    box-sizing:border-box; overflow:hidden; display:flex; flex-direction:column;
  }
  .ps-pane-body { flex:1 1 auto; min-height:0; overflow:auto; }
  .ps-pane::after {
    content:""; position:absolute; inset:0; pointer-events:none;
    outline:1px solid transparent; outline-offset:-1px; transition:outline-color .1s;
  }
  .ps-pane.ps-active::after { outline:2px solid var(--ps-accent,#0969da); outline-offset:-2px; }
  /* structural cursor: a purple overlay box around a selected subtree (an inset
     outline on the split-view gets painted over by its panes), rest dimmed. */
  .ps-sel-box {
    position:absolute; pointer-events:none; z-index:20; display:none;
    border:3px solid var(--ps-sel,#8250df); box-sizing:border-box; border-radius:3px;
  }
  .ps-sel-box.on { display:block; }
  /* the mark (pending swap target) — amber dashed. */
  .ps-mark-box {
    position:absolute; pointer-events:none; z-index:19; display:none;
    border:3px dashed var(--ps-mark,#bf8700); box-sizing:border-box; border-radius:3px;
  }
  .ps-mark-box.on { display:block; }
  .ps-pane.ps-dim { opacity:.4; transition:opacity .1s; }
  .ps-hint {
    position:absolute; left:8px; bottom:8px; z-index:10;
    background:#1f2328; color:#fff; font:12px ui-monospace,Menlo,monospace;
    padding:4px 9px; border-radius:6px; opacity:0; transition:opacity .1s;
    pointer-events:none;
  }
  .ps-hint.on { opacity:.92; }
`;

function ensureStyle() {
  if (document.getElementById(STYLE_ID)) return;
  const s = document.createElement('style');
  s.id = STYLE_ID;
  s.textContent = CSS;
  document.head.appendChild(s);
}

let SEQ = 0;

const DIR = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' };
const MODS = { Shift: 1, Control: 1, Alt: 1, Meta: 1 };

class PaneSplit extends HTMLElement {
  leafFactory = null;
  onDestroy = null;

  #root = null;          // tree root node (leaf | split) or null
  #leaves = new Map();   // id -> leaf node
  #activeId = null;      // the leaf that holds input focus (always a leaf)
  #cursor = null;        // the SELECTED node (leaf or split) — the paredit cursor
  #selLevel = 2;         // 2 full (box+dim+ring) · 1 ring only · 0 none
  #zoomStack = [];       // nodes; top = currently maximized
  #mark = null;          // pending swap target
  #hoisted = null;       // the node currently hoisted to fill the container (zoom viewport)
  #repeat = null;        // 'resize' | 'move' sticky mode
  #awaiting = false;
  #awaitTimer = null;
  #hint = null;
  #selBox = null;
  #markBox = null;

  connectedCallback() {
    ensureStyle();
    this.tabIndex = this.tabIndex < 0 ? 0 : this.tabIndex;
    this.#hint = this.#chrome('ps-hint');
    this.#selBox = this.#chrome('ps-sel-box');
    this.#markBox = this.#chrome('ps-mark-box');
    this.addEventListener('keydown', this.#onKey);
    this.addEventListener('sv-resize', this.#onSvResize);     // drag → read ratio back
    this.addEventListener('sv-collapse', this.#onSvCollapse); // rail click → mirror fold
    window.addEventListener('resize', this.#reposition);
    if (!this.#root && this.leafFactory) this.seed();
    this.focus({ preventScroll: true });   // native — take keyboard focus so keys work without a click first
  }

  disconnectedCallback() {
    this.removeEventListener('keydown', this.#onKey);
    this.removeEventListener('sv-resize', this.#onSvResize);
    this.removeEventListener('sv-collapse', this.#onSvCollapse);
    window.removeEventListener('resize', this.#reposition);
  }

  #chrome(cls) { const d = document.createElement('div'); d.className = cls; this.appendChild(d); return d; }

  get activeId() { return this.#activeId; }
  get cursor() { return this.#cursor; }
  get leafIds() { const out = []; walkLeaves(this.#root, l => out.push(l.id)); return out; }

  // ---- tree construction ----

  seed() {
    if (this.#root) return this.#activeId;
    const leaf = this.#makeLeaf();
    this.#root = leaf;
    this.#place(leaf, this, null);
    this.focusPane(leaf.id);
    return leaf.id;
  }

  #makeLeaf() {
    const id = 'p' + (++SEQ);
    const pane = document.createElement('div');
    pane.className = 'ps-pane';
    pane.dataset.paneId = id;
    const body = document.createElement('div');
    body.className = 'ps-pane-body';
    pane.appendChild(body);
    pane.addEventListener('mousedown', () => this.focusPane(id), true);
    const content = this.leafFactory ? this.leafFactory(id) : document.createTextNode(id);
    if (content) body.appendChild(content);
    const leaf = { kind: 'leaf', id, dom: pane, body, parent: null };
    this.#leaves.set(id, leaf);
    return leaf;
  }

  #place(node, parentEl, slot) {
    if (slot) node.dom.setAttribute('slot', slot);
    else node.dom.removeAttribute('slot');
    parentEl.appendChild(node.dom);
  }

  // ---- splitting ----

  splitRight(id) { return this.#split(id ?? this.#activeId, 'horizontal', 'right'); }
  splitDown(id) { return this.#split(id ?? this.#activeId, 'vertical', 'down'); }

  #split(id, orientation, dir) {
    const leaf = this.#leaves.get(id);
    if (!leaf) return null;
    // splitting while zoomed: drop to the real DOM, split there, then restore
    // the zoom — following the split leaf into its new parent split so the
    // viewport now shows both panes.
    const savedZoom = this.#zoomStack;
    if (savedZoom.length) { this.#zoomStack = []; this.#applyZoom(); }

    const parent = leaf.parent;
    const wasSlot = leaf.dom.getAttribute('slot');          // structural slot (now un-hoisted)
    const host = parent ? parent.sv : this;

    const newLeaf = this.#makeLeaf();
    const sv = document.createElement('split-view');
    sv.setAttribute('orientation', orientation);
    sv.setAttribute('min', '40');
    const node = { kind: 'split', dir: orientation, sv, dom: sv, a: leaf, b: newLeaf, parent, ratio: 0.5, fold: null };
    sv.__psnode = node;                                     // reverse lookup for sv events
    leaf.parent = node; newLeaf.parent = node;

    this.#place(leaf, sv, 'start');
    this.#place(newLeaf, sv, 'end');
    this.#place(node, host, wasSlot);
    if (parent) { if (parent.a === leaf) parent.a = node; else parent.b = node; }
    else this.#root = node;

    if (savedZoom.length) { this.#zoomStack = savedZoom.map(z => z === leaf ? node : z); this.#applyZoom(); }
    this.#applyLayout();
    this.focusPane(newLeaf.id);
    this.#emit('ps-split', { id, dir, newId: newLeaf.id });
    return newLeaf.id;
  }

  // ---- closing ----

  // close the cursor NODE: a leaf, or a whole subtree if a split is selected.
  close(node) {
    node = node ?? this.#cursor;
    if (!node) return;
    if (this.#zoomStack.length) this.zoomReset();           // exit zoom before structural change
    if (this.#mark && (this.#mark === node || this.#within(node, this.#mark))) this.#mark = null;
    const parent = node.parent;
    walkLeaves(node, l => this.#destroyLeaf(l));

    if (!parent) {                         // closed the whole tree
      if (node.kind === 'split') node.sv.remove();
      this.#root = null; this.#activeId = null; this.#cursor = null;
      this.classList.remove('ps-zoomed');
      this.#emit('ps-empty', {});
      return;
    }
    const sib = parent.a === node ? parent.b : parent.a;
    const gp = parent.parent;
    const slot = parent.sv.getAttribute('slot');
    parent.sv.remove();                                     // removes node + its subtree too
    sib.parent = gp;
    if (gp) { if (gp.a === parent) gp.a = sib; else gp.b = sib; this.#place(sib, gp.sv, slot); }
    else { this.#root = sib; this.#place(sib, this, null); }

    this.classList.toggle('ps-zoomed', this.#zoomStack.length > 0);
    this.#applyLayout();
    this.cursorTo(firstLeaf(sib));
    this.#emit('ps-close', {});
  }

  #destroyLeaf(leaf) {
    try { if (this.onDestroy) this.onDestroy(leaf.id, leaf.body); } catch (_) {}
    this.#leaves.delete(leaf.id);
    leaf.dom.remove();
  }

  // ---- layout: derive every split-view from (ratio, fold, zoom) ----

  // layout = write each split's proportion (ratio) and fold to its split-view.
  // Zoom is NOT here — it's which subtree is mounted (see #applyZoom).
  #applyLayout() {
    const visit = (node) => {
      if (!node || node.kind !== 'split') return;
      const sv = node.sv;
      sv.setAttribute('orientation', node.dir);
      sv.setAttribute('size', (node.ratio * 100) + '%');
      if (node.fold) { sv.setAttribute('primary', node.fold); sv.setAttribute('collapsed', ''); }
      else { sv.setAttribute('primary', 'start'); sv.removeAttribute('collapsed'); }
      visit(node.a); visit(node.b);
    };
    visit(this.#root);
    this.#reposition();
  }

  // drag end: convert the split-view's px size back into the model's proportion
  #onSvResize = (e) => {
    const node = e.target && e.target.__psnode;
    if (node) {
      const dim = node.dir === 'horizontal' ? e.target.clientWidth : e.target.clientHeight;
      if (dim) node.ratio = Math.max(0.02, Math.min(0.98, (e.detail?.size ?? 0) / dim));
    }
    this.#reposition();
  };

  // the user clicked split-view's reopen rail: mirror it into the model's fold
  #onSvCollapse = (e) => {
    const node = e.target && e.target.__psnode;
    if (!node) return;
    node.fold = e.detail?.collapsed ? (e.target.getAttribute('primary') || 'start') : null;
    this.#render();
  };

  // ---- cursor (structural selection) ----

  get highlight() { return this.#selLevel; }
  set highlight(v) { this.#selLevel = Math.max(0, Math.min(2, v | 0)); this.#render(); }
  cycleHighlight() { this.#selLevel = (this.#selLevel + 2) % 3; this.#render(); return this.#selLevel; }

  cursorTo(node) {
    if (!node) return;
    this.#cursor = node;
    let n = node, p = node.parent;
    while (p) { p.last = n; n = p; p = p.parent; }
    if (node.kind === 'leaf') this.#activeId = node.id;
    this.#render();
    this.#emit('ps-focus', { id: node.kind === 'leaf' ? node.id : null, kind: node.kind });
  }

  // focusPane — select a leaf by id (NOT the native focus(), which we must not
  // shadow or the host can't take keyboard focus).
  focusPane(id) { const leaf = this.#leaves.get(id); if (leaf) this.cursorTo(leaf); }
  climb() { if (this.#cursor && this.#cursor.parent) this.cursorTo(this.#cursor.parent); }
  descend() { const c = this.#cursor; if (c && c.kind === 'split') this.cursorTo(c.last || c.a); }
  sibling() { const c = this.#cursor, p = c && c.parent; if (p) this.cursorTo(p.a === c ? p.b : p.a); }
  escape() { if (this.#activeId) this.focusPane(this.#activeId); }

  #render() {
    for (const l of this.#leaves.values()) l.dom.classList.remove('ps-active', 'ps-dim');
    const sel = this.#cursor;
    if (this.#selLevel >= 2 && sel && sel.kind === 'split' && !this.#hidden(sel)) {
      const inSel = new Set(); walkLeaves(sel, l => inSel.add(l));
      for (const l of this.#leaves.values()) if (!inSel.has(l)) l.dom.classList.add('ps-dim');
      this.#placeBox(this.#selBox, sel);
    } else {
      this.#selBox?.classList.remove('on');
      const al = this.#leaves.get(this.#activeId);
      if (this.#selLevel >= 1 && al && !this.#hidden(al)) al.dom.classList.add('ps-active');
    }
    this.#renderMark();
  }

  #reposition = () => {
    if (this.#selLevel >= 2 && this.#cursor && this.#cursor.kind === 'split' && !this.#hidden(this.#cursor)) this.#placeBox(this.#selBox, this.#cursor);
    else this.#selBox?.classList.remove('on');
    this.#renderMark();
  };

  #placeBox(box, node) {
    if (!box) return;
    const cr = this.getBoundingClientRect();
    const r = node.dom.getBoundingClientRect();
    box.style.left = (r.left - cr.left) + 'px';
    box.style.top = (r.top - cr.top) + 'px';
    box.style.width = r.width + 'px';
    box.style.height = r.height + 'px';
    box.classList.add('on');
  }

  #renderMark() {
    if (!this.#markBox) return;
    if (this.#mark && !this.#hidden(this.#mark)) this.#placeBox(this.#markBox, this.#mark);
    else this.#markBox.classList.remove('on');
  }

  // hidden = outside the current zoom viewport, or behind a fold within it.
  #hidden(node) {
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    if (top && !this.#within(top, node)) return true;       // not inside the zoomed subtree
    let n = node, p = node.parent;
    while (p && n !== top) {                                 // folds above the viewport don't count
      if (p.fold === (p.a === n ? 'start' : 'end')) return true;
      n = p; p = p.parent;
    }
    return false;
  }

  focusNext() {
    const ids = this.leafIds;
    if (ids.length < 2) return;
    const i = ids.indexOf(this.#activeId);
    this.focusPane(ids[(i + 1) % ids.length]);
  }
  focusIndex(i) { const ids = this.leafIds; if (i >= 0 && i < ids.length) this.focusPane(ids[i]); }

  focusMove(dir) {
    const cur = this.#leaves.get(this.#activeId);
    if (!cur) return;
    const a = center(cur.dom);
    let best = null, bestD = Infinity;
    for (const l of this.#leaves.values()) {
      if (l === cur || this.#hidden(l)) continue;
      const b = center(l.dom);
      const dx = b.x - a.x, dy = b.y - a.y;
      const ok = dir === 'left' ? dx < -1 && Math.abs(dy) <= Math.abs(dx)
        : dir === 'right' ? dx > 1 && Math.abs(dy) <= Math.abs(dx)
          : dir === 'up' ? dy < -1 && Math.abs(dx) <= Math.abs(dy)
            : dy > 1 && Math.abs(dx) <= Math.abs(dy);
      if (!ok) continue;
      const d = dx * dx + dy * dy;
      if (d < bestD) { bestD = d; best = l; }
    }
    if (best) this.focusPane(best.id);
  }

  // ---- zoom (a stack; nest in and out) ----

  zoomToggle(node) {
    node = node ?? this.#cursor;
    if (!node) return;
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    if (node === top) this.#zoomStack.pop();                // z on the zoomed node → out one
    else {
      if (!node.parent) return;                             // can't zoom the root
      if (top && !this.#within(top, node)) return;          // only zoom deeper into the current view
      this.#zoomStack.push(node);
    }
    this.#afterZoom(node);
  }
  zoomOut() { if (this.#zoomStack.length) { this.#zoomStack.pop(); this.#afterZoom(this.#zoomStack[this.#zoomStack.length - 1] ?? this.#cursor); } }
  zoomReset() { if (this.#zoomStack.length) { this.#zoomStack = []; this.#afterZoom(this.#cursor); } }
  #afterZoom(focusNode) {
    this.#applyZoom();
    if (focusNode) this.cursorTo(focusNode);
    this.#emit('ps-zoom', { depth: this.#zoomStack.length });
  }

  // choose which subtree fills the container (the viewport). Hoist the zoom-top
  // node's element to be pane-split's direct child so it fills, and hide the
  // structural root. The model is untouched — nest in/out by pushing/popping.
  #applyZoom() {
    const top = this.#zoomStack[this.#zoomStack.length - 1] || null;
    if (this.#hoisted && this.#hoisted !== top) {           // return the old viewport to its slot
      const hn = this.#hoisted;
      if (hn.parent) this.#place(hn, hn.parent.sv, hn.parent.a === hn ? 'start' : 'end');
      this.#hoisted = null;
    }
    if (top) {
      if (this.#hoisted !== top) { this.#place(top, this, null); this.#hoisted = top; }
      if (this.#root) this.#root.dom.style.display = 'none';
      this.classList.add('ps-zoomed');
    } else {
      if (this.#root) this.#root.dom.style.display = '';
      this.classList.remove('ps-zoomed');
    }
    this.#applyLayout();   // re-sync every split's size from the model (ratios are truth)
  }

  // ---- collapse (fold a side; non-destructive, keeps the selection) ----

  collapse() {
    const node = this.#cursor, p = node && node.parent;
    if (!p) return;
    const slot = p.a === node ? 'start' : 'end';
    p.fold = (p.fold === slot) ? null : slot;               // toggle folding the SELECTED side
    this.#applyLayout();
    this.#render();                                         // cursor unchanged → selection kept
  }

  // ---- resize (adjust the model's ratio; proportional) ----

  nudge(dir) {
    const start = this.#cursor;
    if (!start) return;
    const axis = (dir === 'left' || dir === 'right') ? 'horizontal' : 'vertical';
    let node = start, parent = start.parent;
    while (parent && parent.dir !== axis) { node = parent; parent = parent.parent; }
    if (!parent) return;
    const dim = axis === 'horizontal' ? parent.sv.clientWidth : parent.sv.clientHeight;
    if (!dim) return;
    const step = 32 / dim, grow = (dir === 'right' || dir === 'down');
    parent.ratio = Math.max(0.05, Math.min(0.95, parent.ratio + (grow ? step : -step)));
    parent.sv.setAttribute('size', (parent.ratio * 100) + '%');
    this.#reposition();
  }

  // ---- mark & swap ----

  markToggle() { this.#mark = (this.#mark === this.#cursor) ? null : this.#cursor; this.#renderMark(); return !!this.#mark; }
  clearMark() { this.#mark = null; this.#renderMark(); }

  swap() {
    const c = this.#cursor;
    if (this.#mark && this.#mark !== c) {
      if (this.#swapNodes(c, this.#mark)) { this.clearMark(); this.cursorTo(c); }
      return;
    }
    const p = c && c.parent;
    if (!p) return;
    [p.a, p.b] = [p.b, p.a];
    this.#place(p.a, p.sv, 'start');
    this.#place(p.b, p.sv, 'end');
    this.#render();
  }

  // exchange two nodes' positions (content + state travel). Illegal if one
  // contains the other, or if either is the root.
  #swapNodes(n1, n2) {
    if (n1 === n2) return false;
    const p1 = n1.parent, p2 = n2.parent;
    if (!p1 || !p2) return false;
    if (this.#within(n1, n2) || this.#within(n2, n1)) return false;
    const s1 = n1.dom.getAttribute('slot'), s2 = n2.dom.getAttribute('slot');
    if (p1.a === n1) p1.a = n2; else p1.b = n2;
    if (p2.a === n2) p2.a = n1; else p2.b = n1;
    n1.parent = p2; n2.parent = p1;
    this.#place(n2, p1.sv, s1);
    this.#place(n1, p2.sv, s2);
    return true;
  }

  #within(anc, node) { let n = node; while (n) { if (n === anc) return true; n = n.parent; } return false; }

  // ---- keys ----

  get #prefix() {
    const raw = (this.getAttribute('prefix') || 'ctrl+b').toLowerCase().split('+');
    return { key: raw.pop(), ctrl: raw.includes('ctrl'), meta: raw.includes('meta') || raw.includes('cmd'), alt: raw.includes('alt') };
  }

  #onKey = (e) => {
    if (this.#repeat && !this.#awaiting) {                  // sticky repeat
      if (MODS[e.key]) return;
      const d = DIR[e.key];
      if (d) {
        if (this.#repeat === 'resize' || e.shiftKey) this.nudge(d); else this.focusMove(d);
        this.#arm(this.#repeat);
        e.preventDefault(); e.stopPropagation();
        return;
      }
      this.#endRepeat();
      if (e.key === 'Escape') { e.preventDefault(); return; }
    }
    if (!this.#awaiting) {
      const p = this.#prefix;
      if (e.key.toLowerCase() === p.key && e.ctrlKey === p.ctrl && e.metaKey === p.meta && e.altKey === p.alt) {
        this.#awaiting = true;
        this.#flashHint('% split · " stack · c collapse · z/Z zoom in/out · x close · m mark · ␣ swap · [ ] climb/descend · Tab sibling · h highlight · 1-9 jump · ←↑↓→ move · ⇧←↑↓→ / r resize (arrows repeat)');
        clearTimeout(this.#awaitTimer);
        this.#awaitTimer = setTimeout(() => { this.#awaiting = false; this.#flashHint(''); }, 2500);
        e.preventDefault(); e.stopPropagation();
      }
      return;
    }
    const k = e.key;
    if (MODS[k]) { e.preventDefault(); return; }            // lone modifier: keep waiting
    this.#awaiting = false; clearTimeout(this.#awaitTimer); this.#flashHint('');
    let handled = true;
    const dir = DIR[k];
    if (k === '%' || k === '|') this.splitRight();
    else if (k === '"' || k === '-') this.splitDown();
    else if (k === 'x') this.close();
    else if (k === 'z') this.zoomToggle();
    else if (k === 'Z') this.zoomOut();
    else if (k === 'c') this.collapse();
    else if (k === 'h') { const lv = this.cycleHighlight(); this.#flashHint('highlight: ' + ['none', 'active only', 'full'][lv]); }
    else if (k === 'o') this.focusNext();
    else if (k === ' ') this.swap();
    else if (k === 'm') { const on = this.markToggle(); this.#flashHint(on ? 'marked — move the cursor, then space to swap' : 'mark cleared'); }
    else if (k === '[') this.climb();
    else if (k === ']') this.descend();
    else if (k === 'Tab') this.sibling();
    else if (k === 'Escape') this.escape();
    else if (k >= '1' && k <= '9') this.focusIndex(+k - 1);
    else if (k === 'r') this.#arm('resize');
    else if (dir && e.shiftKey) { this.nudge(dir); this.#arm('resize'); }
    else if (dir) { this.focusMove(dir); this.#arm('move'); }
    else handled = false;
    if (handled) { e.preventDefault(); e.stopPropagation(); }
  };

  #arm(kind) {
    this.#repeat = kind;
    this.#flashHint((kind === 'resize' ? 'resize' : 'move') + ': ←↑↓→  (any other key or Esc to exit)');
  }
  #endRepeat() { this.#repeat = null; this.#flashHint(''); }

  #flashHint(msg) {
    if (!this.#hint) return;
    this.#hint.textContent = msg;
    this.#hint.classList.toggle('on', !!msg);
  }

  #emit(name, detail) { this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true })); }
}

function walkLeaves(node, fn) {
  if (!node) return;
  if (node.kind === 'leaf') fn(node);
  else { walkLeaves(node.a, fn); walkLeaves(node.b, fn); }
}
function firstLeaf(node) { return node.kind === 'leaf' ? node : firstLeaf(node.a); }
function center(el) { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }

customElements.define('pane-split', PaneSplit);
