// <pane-split> — a tmux-style recursive pane tree.
//
// EXPERIMENTAL. Not wired into the live explorer. Composes <split-view>
// (which must be defined first) into an arbitrarily-nested tree of panes.
// Each leaf holds host-supplied content; every internal node is a
// <split-view>, so drag-resize / collapse / persist come for free.
//
// CONTRACT
//   properties (set from the host, in JS — this is a programmatic element):
//     leafFactory  (id) => HTMLElement
//                  builds the body content for a new leaf. Required before
//                  the first leaf is created. Called for the seed leaf and
//                  for the far side of every split. Keep it cheap/idempotent.
//     onDestroy    (id, bodyEl) => void   (optional)
//                  called when a leaf is closed, so the host can tear down
//                  whatever it mounted (e.g. FileView.destroy).
//   attributes (config in):
//     prefix       the tmux prefix chord, "mod+key" (default "ctrl+b").
//                  After the prefix, the next key is a command (see KEYS).
//   methods (the same ops the keys drive):
//     .seed()                 create the first leaf if the tree is empty
//     .splitRight(id?)        split a leaf side-by-side (new pane on the right)
//     .splitDown(id?)         split a leaf stacked (new pane below)
//     .close(id?)             close a leaf, promote its sibling
//     .focus(id)              make a leaf active
//     .focusMove(dir)         move focus spatially: left|right|up|down
//     .focusNext()            cycle to the next leaf
//     .zoomToggle(id?)        maximize/restore a leaf (tmux ctrl-b z)
//     id? defaults to the active leaf.
//   getters:
//     .activeId   current focused leaf id (or null)
//     .leafIds    all leaf ids, in document order
//   events (bubbling + composed):
//     ps-focus  { id }
//     ps-split  { id, dir, newId }
//     ps-close  { id }
//     ps-empty  {}            the last pane was closed
//     ps-zoom   { id, zoomed }
//
//   KEYS (after the prefix): % or | split right · " or - split down ·
//     x close (cursor leaf OR subtree) · z zoom cursor · c collapse cursor ·
//     o cycle · m mark a swap target · space swap cursor with mark (content +
//     state travel), or with sibling when no mark · [ climb to parent subtree ·
//     ] descend · Tab sibling subtree · Esc reset cursor to active leaf ·
//     h cycle highlight (full / active-ring-only / none) · 1-9 jump to pane · arrows move focus ·
//     shift+arrows shift the boundary · r enter resize. move and resize are
//     "sticky" modes: after one, bare arrows repeat it (no prefix) until a
//     non-arrow key or Esc exits — no timer.
//
//   CURSOR (structural selection, "paredit for panes"): selection is a NODE,
//   leaf or split. climb/descend/sibling walk the tree; a split cursor outlines
//   its subtree and dims the rest; every op (close/zoom/collapse/swap/resize)
//   targets the cursor. The active (input-focused) leaf is tracked separately.
//
// DESIGN NOTES
//   - Light DOM, not shadow: leaf content (a FileView, an editor) expects to
//     live in the normal document and reach global styles. We scope our own
//     chrome with a .ps- prefix and inject one <style> per document.
//   - The JS tree (leaf/split nodes) is the source of truth; the DOM mirrors
//     it. Each node knows its parent and the split-view slot it occupies, so
//     splitting and promoting are local pointer surgery.
//   - Nesting is the whole trick: N-way layouts are just split-views inside
//     split-views. We never need an N-pane primitive.

const STYLE_ID = 'pane-split-style';
const CSS = `
  pane-split { display:block; width:100%; height:100%; min-width:0; min-height:0; position:relative; }
  pane-split split-view { width:100%; height:100%; }
  .ps-pane {
    position:relative; width:100%; height:100%; min-width:0; min-height:0;
    box-sizing:border-box; overflow:hidden; display:flex; flex-direction:column;
  }
  .ps-pane-body { flex:1 1 auto; min-height:0; overflow:auto; }
  /* the active pane gets an inset ring; inactive panes a hairline */
  .ps-pane::after {
    content:""; position:absolute; inset:0; pointer-events:none;
    outline:1px solid transparent; outline-offset:-1px;
    background:transparent; transition:outline-color .1s, background .1s;
  }
  .ps-pane.ps-active::after { outline:2px solid var(--ps-accent,#0969da); outline-offset:-2px; }
  /* structural cursor: when a SPLIT (subtree) is selected, lay a real overlay
     box over the whole subtree (an inset outline on the split-view gets painted
     over by its panes), and dim every leaf outside it. */
  .ps-sel-box {
    position:absolute; pointer-events:none; z-index:20; display:none;
    border:3px solid var(--ps-sel,#8250df); box-sizing:border-box; border-radius:3px;
  }
  .ps-sel-box.on { display:block; }
  /* the mark (pending swap target) — amber dashed, distinct from the purple
     selection box. */
  .ps-mark-box {
    position:absolute; pointer-events:none; z-index:19; display:none;
    border:3px dashed var(--ps-mark,#bf8700); box-sizing:border-box; border-radius:3px;
  }
  .ps-mark-box.on { display:block; }
  .ps-pane.ps-dim { opacity:.4; transition:opacity .1s; }
  /* zoom: the maximized pane is relocated here, over everything */
  pane-split.ps-zoomed > :not(.ps-zoom-layer) { display:none !important; }
  .ps-zoom-layer { position:absolute; inset:0; z-index:5; background:var(--ps-bg,#fff); }
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
  #activeId = null;       // the leaf that holds input focus (always a leaf)
  #cursor = null;         // the SELECTED node (leaf or split) — the paredit cursor
  #selLevel = 2;          // 2 = full (box+dim+ring), 1 = active ring only, 0 = none (Ctrl-B h cycles)
  #awaiting = false;
  #awaitTimer = null;
  #zoom = null;          // { leaf, parent, next, slot } when zoomed
  #hint = null;

  connectedCallback() {
    ensureStyle();
    this.tabIndex = this.tabIndex < 0 ? 0 : this.tabIndex;
    this.#hint = document.createElement('div');
    this.#hint.className = 'ps-hint';
    this.appendChild(this.#hint);
    this.#selBox = document.createElement('div');
    this.#selBox.className = 'ps-sel-box';
    this.appendChild(this.#selBox);
    this.#markBox = document.createElement('div');
    this.#markBox.className = 'ps-mark-box';
    this.appendChild(this.#markBox);
    this.addEventListener('keydown', this.#onKey);
    // keep the selection box glued to its subtree while a divider is dragged
    this.addEventListener('sv-resize', this.#reposition);
    window.addEventListener('resize', this.#reposition);
    if (!this.#root && this.leafFactory) this.seed();
  }

  disconnectedCallback() {
    this.removeEventListener('keydown', this.#onKey);
    this.removeEventListener('sv-resize', this.#reposition);
    window.removeEventListener('resize', this.#reposition);
  }

  #selBox = null;
  #markBox = null;
  #mark = null;           // pending swap target (a node), set with Ctrl-B m
  #repeat = null;         // 'resize' | 'move' — sticky mode: bare arrows repeat until a non-arrow key / Esc
  #reposition = () => {
    if (this.#selLevel >= 2 && this.#cursor && this.#cursor.kind === 'split' && !this.#hidden(this.#cursor)) this.#placeBox(this.#selBox, this.#cursor);
    this.#renderMark();
  };

  get activeId() { return this.#activeId; }
  get leafIds() { const out = []; walkLeaves(this.#root, l => out.push(l.id)); return out; }

  // ---- tree construction ----

  seed() {
    if (this.#root) return this.#activeId;
    const leaf = this.#makeLeaf();
    this.#root = leaf;
    this.#place(leaf, this, null);
    this.focus(leaf.id);
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
    pane.addEventListener('mousedown', () => this.focus(id), true);
    const content = this.leafFactory ? this.leafFactory(id) : document.createTextNode(id);
    if (content) body.appendChild(content);
    const leaf = { kind: 'leaf', id, dom: pane, body, parent: null };
    this.#leaves.set(id, leaf);
    return leaf;
  }

  // put a node's element into parentEl at the given split-view slot
  // (slot null = it is the tree root, sitting directly in the host).
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
    if (!leaf || this.#zoom) return null;           // no splitting while zoomed
    const parent = leaf.parent;                      // split node or null (root)
    const wasSlot = leaf.dom.getAttribute('slot');   // 'start' | 'end' | null
    const host = parent ? parent.sv : this;

    const newLeaf = this.#makeLeaf();
    const sv = document.createElement('split-view');
    sv.setAttribute('orientation', orientation);
    sv.setAttribute('primary', 'start');
    sv.setAttribute('size', '50%');
    sv.setAttribute('min', '60');

    // dom aliases sv so #place/#zoom can treat leaf and split nodes alike
    const node = { kind: 'split', dir: orientation, sv, dom: sv, a: leaf, b: newLeaf, parent };
    leaf.parent = node; newLeaf.parent = node;

    // existing leaf moves into start, new leaf into end, both under the new sv
    this.#place(leaf, sv, 'start');
    this.#place(newLeaf, sv, 'end');
    // the new split takes the slot the leaf used to occupy
    this.#place(node, host, wasSlot);

    if (parent) { if (parent.a === leaf) parent.a = node; else parent.b = node; }
    else this.#root = node;

    this.focus(newLeaf.id);
    this.#emit('ps-split', { id, dir, newId: newLeaf.id });
    return newLeaf.id;
  }

  // ---- closing ----

  // close the cursor NODE: a leaf, or a whole subtree if a split is selected.
  close(node) {
    node = node ?? this.#cursor;
    if (!node) return;
    if (this.#zoom) this.zoomToggle();                     // never close while zoomed
    if (this.#mark && (this.#mark === node || this.#isAncestor(node, this.#mark))) this.#mark = null;
    const parent = node.parent;
    walkLeaves(node, l => this.#destroyLeaf(l));            // tear down every leaf under it

    if (!parent) {                         // closed the whole tree
      if (node.kind === 'split') node.sv.remove();
      this.#root = null; this.#activeId = null; this.#cursor = null;
      this.#emit('ps-empty', {});
      return;
    }
    const sib = parent.a === node ? parent.b : parent.a;   // the surviving subtree
    const gp = parent.parent;
    const slot = parent.sv.getAttribute('slot');           // where the split sat
    parent.sv.remove();                                    // removes node + its subtree too
    sib.parent = gp;

    if (gp) { if (gp.a === parent) gp.a = sib; else gp.b = sib; this.#place(sib, gp.sv, slot); }
    else { this.#root = sib; this.#place(sib, this, null); }

    this.cursorTo(firstLeaf(sib));
    this.#emit('ps-close', {});
  }

  #destroyLeaf(leaf) {
    try { if (this.onDestroy) this.onDestroy(leaf.id, leaf.body); } catch (_) {}
    this.#leaves.delete(leaf.id);
    leaf.dom.remove();
  }

  // ---- cursor (structural selection) ----

  get cursor() { return this.#cursor; }

  // selection-visual level: 2 full (subtree box + dim + active ring), 1 active
  // ring only, 0 none. Two tiers because the ring says "where input goes" while
  // the box+dim is the heavier structural cue — quiet them independently.
  get highlight() { return this.#selLevel; }
  set highlight(v) { this.#selLevel = Math.max(0, Math.min(2, v | 0)); this.#render(); }
  cycleHighlight() { this.#selLevel = (this.#selLevel + 2) % 3; this.#render(); return this.#selLevel; }

  // move the cursor to any node (leaf or split). Records descent memory along
  // the path so a later descend() returns to where we climbed from. A leaf
  // cursor also becomes the active (input-focused) leaf.
  cursorTo(node) {
    if (!node) return;
    this.#cursor = node;
    let n = node, p = node.parent;
    while (p) { p.last = n; n = p; p = p.parent; }
    if (node.kind === 'leaf') this.#activeId = node.id;
    this.#render();
    this.#emit('ps-focus', { id: node.kind === 'leaf' ? node.id : null, kind: node.kind });
  }

  // focus a leaf by id (clicking, spatial move, split) — a leaf-level cursor.
  focus(id) { const leaf = this.#leaves.get(id); if (leaf) this.cursorTo(leaf); }

  climb() { if (this.#cursor && this.#cursor.parent) this.cursorTo(this.#cursor.parent); }
  descend() { const c = this.#cursor; if (c && c.kind === 'split') this.cursorTo(c.last || c.a); }
  sibling() { const c = this.#cursor, p = c && c.parent; if (p) this.cursorTo(p.a === c ? p.b : p.a); }
  escape() { if (this.#activeId) this.focus(this.#activeId); }

  // paint the active-leaf ring, and (when a subtree is selected) the subtree
  // outline plus a dim on every leaf outside the selection.
  #render() {
    for (const l of this.#leaves.values()) l.dom.classList.remove('ps-active', 'ps-dim');
    const sel = this.#cursor;
    // SUBTREE selected: a purple box around it + dim the rest, and NO blue leaf
    // ring (the box is the whole story). A selection hidden behind a collapse
    // shows nothing — don't strand a box or a dim.
    if (this.#selLevel >= 2 && sel && sel.kind === 'split' && !this.#hidden(sel)) {
      const inSel = new Set(); walkLeaves(sel, l => inSel.add(l));
      for (const l of this.#leaves.values()) if (!inSel.has(l)) l.dom.classList.add('ps-dim');
      this.#placeBox(this.#selBox, sel);
    } else {
      this.#selBox?.classList.remove('on');
      const al = this.#leaves.get(this.#activeId);   // active-leaf ring (level >= 1)
      if (this.#selLevel >= 1 && al && !this.#hidden(al)) al.dom.classList.add('ps-active');
    }
    this.#renderMark();
  }

  // position an overlay box over a node's bounding rect (container-relative)
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

  // the mark box shows wherever the marked node is (independent of the
  // highlight level — it's a deliberate pending action), but not while zoomed.
  #renderMark() {
    if (!this.#markBox) return;
    if (this.#mark && !this.#hidden(this.#mark) && !this.classList.contains('ps-zoomed')) this.#placeBox(this.#markBox, this.#mark);
    else this.#markBox.classList.remove('on');
  }

  // is this node hidden behind a collapsed ancestor split? (it sits on the
  // primary — collapsed — side of some ancestor)
  #hidden(node) {
    let n = node, p = node.parent;
    while (p) {
      if (p.sv.hasAttribute('collapsed') && n.dom.getAttribute('slot') === (p.sv.getAttribute('primary') || 'start')) return true;
      n = p; p = p.parent;
    }
    return false;
  }

  focusNext() {
    const ids = this.leafIds;
    if (ids.length < 2) return;
    const i = ids.indexOf(this.#activeId);
    this.focus(ids[(i + 1) % ids.length]);
  }

  // spatial move: pick the nearest leaf whose center lies in `dir`.
  focusMove(dir) {
    const cur = this.#leaves.get(this.#activeId);
    if (!cur) return;
    const a = center(cur.dom);
    let best = null, bestD = Infinity;
    for (const l of this.#leaves.values()) {
      if (l === cur) continue;
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
    if (best) this.focus(best.id);
  }

  // ---- zoom ----

  zoomToggle(node) {
    if (this.#zoom) {
      const z = this.#zoom; this.#zoom = null;
      this.classList.remove('ps-zoomed');
      if (z.slot) z.node.dom.setAttribute('slot', z.slot); else z.node.dom.removeAttribute('slot');
      z.parent.insertBefore(z.node.dom, z.next);
      this.#zoomLayer?.remove(); this.#zoomLayer = null;
      this.cursorTo(z.node);
      this.#emit('ps-zoom', { zoomed: false });
      return;
    }
    node = node ?? this.#cursor;
    if (!node || !node.parent) return;                     // nothing to zoom against at the root
    this.#zoom = { node, parent: node.dom.parentNode, next: node.dom.nextSibling, slot: node.dom.getAttribute('slot') };
    const layer = document.createElement('div');
    layer.className = 'ps-zoom-layer';
    node.dom.removeAttribute('slot');
    layer.appendChild(node.dom);
    this.appendChild(layer);
    this.#zoomLayer = layer;
    this.classList.add('ps-zoomed');
    this.cursorTo(node);
    this.#emit('ps-zoom', { zoomed: true });
  }
  #zoomLayer = null;

  // collapse (or expand) the cursor node within its parent split — a one-sided
  // collapse toward the shared divider, with split-view's reopen rail. Pressing
  // it again from the sibling (same parent) expands.
  collapse() {
    const node = this.#cursor, p = node && node.parent;
    if (!p) return;
    if (p.sv.hasAttribute('collapsed')) { p.sv.expand(); this.cursorTo(node); return; }
    p.sv.setAttribute('primary', node.dom.getAttribute('slot'));  // collapse the SELECTED side
    p.sv.collapse();
    this.cursorTo(firstLeaf(p.a === node ? p.b : p.a));           // move to the pane still visible
  }

  // ---- keys ----

  get #prefix() {
    const raw = (this.getAttribute('prefix') || 'ctrl+b').toLowerCase().split('+');
    return { key: raw.pop(), ctrl: raw.includes('ctrl'), meta: raw.includes('meta') || raw.includes('cmd'), alt: raw.includes('alt'), shift: raw.includes('shift') };
  }

  #onKey = (e) => {
    // sticky repeat: after a resize/move, bare arrows keep going (no prefix).
    if (this.#repeat && !this.#awaiting) {
      if (MODS[e.key]) return;                             // Shift to resize — keep the window open
      const d = DIR[e.key];
      if (d) {
        if (this.#repeat === 'resize' || e.shiftKey) this.nudge(d); else this.focusMove(d);
        this.#arm(this.#repeat);
        e.preventDefault(); e.stopPropagation();
        return;
      }
      this.#endRepeat();                                   // any other key exits; fall through to normal handling
      if (e.key === 'Escape') { e.preventDefault(); return; }
    }
    if (!this.#awaiting) {
      const p = this.#prefix;
      if (e.key.toLowerCase() === p.key && e.ctrlKey === p.ctrl && e.metaKey === p.meta && e.altKey === p.alt) {
        this.#awaiting = true;
        this.#flashHint('% split · " stack · c collapse · z zoom · x close · m mark · ␣ swap · [ ] climb/descend · Tab sibling · h highlight · 1-9 jump · ←↑↓→ move · ⇧←↑↓→ / r resize (then arrows repeat)');
        clearTimeout(this.#awaitTimer);
        this.#awaitTimer = setTimeout(() => { this.#awaiting = false; this.#flashHint(''); }, 2500);
        e.preventDefault(); e.stopPropagation();
      }
      return;
    }
    // awaiting a command
    const k = e.key;
    // a lone modifier (you pressed Shift to reach % or ") is NOT the command —
    // keep waiting for the real key, or shifted commands get eaten.
    if (k === 'Shift' || k === 'Control' || k === 'Alt' || k === 'Meta') { e.preventDefault(); return; }
    this.#awaiting = false; clearTimeout(this.#awaitTimer); this.#flashHint('');
    let handled = true;
    const dir = DIR[k];
    if (k === '%' || k === '|') this.splitRight();
    else if (k === '"' || k === '-') this.splitDown();
    else if (k === 'x') this.close();                      // close cursor (leaf or subtree)
    else if (k === 'z') this.zoomToggle();                 // zoom cursor
    else if (k === 'c') this.collapse();                   // collapse cursor within its split
    else if (k === 'h') { const lv = this.cycleHighlight(); this.#flashHint('highlight: ' + ['none', 'active only', 'full'][lv]); }
    else if (k === 'o') this.focusNext();
    else if (k === ' ') this.swap();                       // swap with mark, else sibling
    else if (k === 'm') { const on = this.markToggle(); this.#flashHint(on ? 'marked — move the cursor, then space to swap' : 'mark cleared'); }
    else if (k === '[') this.climb();                      // select parent subtree
    else if (k === ']') this.descend();                    // descend into subtree
    else if (k === 'Tab') this.sibling();                  // jump to sibling subtree
    else if (k === 'Escape') this.escape();                // reset cursor to active leaf
    else if (k >= '1' && k <= '9') this.focusIndex(+k - 1); // jump to pane N
    else if (k === 'r') this.#arm('resize');               // enter sticky resize (then bare arrows)
    else if (dir && e.shiftKey) { this.nudge(dir); this.#arm('resize'); }   // shift the boundary (repeatable)
    else if (dir) { this.focusMove(dir); this.#arm('move'); }               // move focus (repeatable)
    else handled = false;
    if (handled) { e.preventDefault(); e.stopPropagation(); }
  };

  // jump to the Nth leaf in document order
  focusIndex(i) { const ids = this.leafIds; if (i >= 0 && i < ids.length) this.focus(ids[i]); }

  // move the boundary of the cursor's nearest ancestor split on the arrow axis
  nudge(dir) {
    const start = this.#cursor;
    if (!start) return;
    const axis = (dir === 'left' || dir === 'right') ? 'horizontal' : 'vertical';
    let node = start, parent = start.parent;
    while (parent && parent.dir !== axis) { node = parent; parent = parent.parent; }
    if (!parent) return;
    const r = parent.a.dom.getBoundingClientRect();
    const cur = axis === 'horizontal' ? r.width : r.height;
    const grow = (dir === 'right' || dir === 'down');
    parent.sv.setAttribute('size', Math.max(40, Math.round(cur + (grow ? 32 : -32))) + 'px');
  }

  // mark the cursor node as a pending swap target (toggle). Returns true if a
  // mark is now set. The mark's live state (content) travels on swap.
  markToggle() {
    this.#mark = (this.#mark === this.#cursor) ? null : this.#cursor;
    this.#renderMark();
    return !!this.#mark;
  }
  clearMark() { this.#mark = null; this.#renderMark(); }

  // space: swap the cursor with the MARK if one is set (positions in the tree
  // trade, so content + live state move); otherwise swap with the sibling.
  swap() {
    const c = this.#cursor;
    if (this.#mark && this.#mark !== c) {
      if (this.#swapNodes(c, this.#mark)) { this.clearMark(); this.cursorTo(c); }
      return;                                              // invalid pair → keep the mark, no-op
    }
    const p = c && c.parent;
    if (!p) return;
    [p.a, p.b] = [p.b, p.a];
    this.#place(p.a, p.sv, 'start');
    this.#place(p.b, p.sv, 'end');
    this.#render();
  }

  // exchange two nodes' positions in the tree (each keeps its own content/state
  // and travels to the other's slot). Illegal if one contains the other, or if
  // either is the root.
  #swapNodes(n1, n2) {
    if (n1 === n2) return false;
    const p1 = n1.parent, p2 = n2.parent;
    if (!p1 || !p2) return false;
    if (this.#isAncestor(n1, n2) || this.#isAncestor(n2, n1)) return false;
    const s1 = n1.dom.getAttribute('slot'), s2 = n2.dom.getAttribute('slot');
    if (p1.a === n1) p1.a = n2; else p1.b = n2;
    if (p2.a === n2) p2.a = n1; else p2.b = n1;
    n1.parent = p2; n2.parent = p1;
    this.#place(n2, p1.sv, s1);
    this.#place(n1, p2.sv, s2);
    return true;
  }

  #isAncestor(a, b) { let n = b.parent; while (n) { if (n === a) return true; n = n.parent; } return false; }

  // enter a sticky mode; no timer — bare arrows repeat until a non-arrow key or
  // Esc exits. The hint stays up as the mode indicator so you always know.
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

  #emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }));
  }
}

function walkLeaves(node, fn) {
  if (!node) return;
  if (node.kind === 'leaf') fn(node);
  else { walkLeaves(node.a, fn); walkLeaves(node.b, fn); }
}
function firstLeaf(node) { return node.kind === 'leaf' ? node : firstLeaf(node.a); }
function center(el) { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }

customElements.define('pane-split', PaneSplit);
