// <post-card> — one social post: who, when, what, and the standard row
// under it. The row is the compact convention every client uses: a reply
// count that opens the thread (absent at zero), a repost count, one chip
// per reaction emoji — clicking one reacts the same way — a 👥 chip that
// opens the list of who, and Reply / React (an <emoji-picker> in a modal) on the right. The card renders none of the text itself — the host slots
// the content in, so mentions, links and media stay the host's business —
// and it holds no data beyond what it is given; everything it wants done
// it asks for with an event.
//
// USAGE
//   const card = document.createElement('post-card');
//   card.post = { id, pubkey, created_at, profile: { name, picture },
//                 reply_to, counts: { replies, reposts }, reactions: { '+': 3, '🔥': 1 } };
//   card.append(contentEl);               // contentEl.slot = 'content'
//   card.addEventListener('pc-open',   e => openThread(e.detail.post.id));
//   card.addEventListener('pc-person', e => openPerson(e.detail.pubkey));
//   card.addEventListener('pc-reply',  e => …);
//   card.addEventListener('pc-react',  e => { … e.detail.content … ; e.detail.done(); });
//   card.addEventListener('pc-who',    e => showWho(card));
//   card.addEventListener('pc-repost', e => { … ; e.detail.done(); });
//   card.append(whoListEl);               // whoListEl.slot = 'who' — shown while present
//
// CONTRACT
//   properties:
//     post      the post object above (profile/counts/reactions optional).
//               Setting re-renders. Reactions keyed '+' show as 👍.
//               `repost: { pubkey, name, picture, at }` draws a "reposted
//               by" line above the header (the post itself is the original).
//   attributes (config in):
//     in-thread   boolean; the card is part of a thread view: no open-on-
//                 click, 💬 and Reply both mean "reply to this one"
//     depth       indent level inside a thread (0–6)
//     target      boolean; highlighted (the post a reply box is aimed at)
//     link        href for the id line at the bottom (omit: no id line)
//     compact     boolean; a quoted post inside another: bordered, no
//                 action row, the whole card opens it (pc-open)
//   slots (content in):
//     content   the rendered text (the host renders it)
//     who       an expanded list of who reacted; the host adds/removes it
//   css vars (theme in), house-light defaults:
//     --pc-accent   links, highlights (default #6b3fd6)
//     --pc-pad      card padding (default 13px 18px)
//     --pc-border   bottom border (default 1px solid #f2f4f6)
//     --pc-muted    secondary text (default #57606a)
//   events (state out), bubbling + composed, detail always carries `post`:
//     pc-open    the card body was clicked (not in-thread)
//     pc-person  { pubkey } — avatar or name clicked
//     pc-reply   Reply pressed (or 💬 when in-thread)
//     pc-react   { content, done() } — an emoji chip clicked (content is
//                that emoji, '+' for 👍) or one picked from the React
//                picker; the source button spins until done() is called
//     pc-who     the 👥 chip clicked: show who reacted and reposted
//     pc-repost  { done() } — Repost pressed; the button spins until done()
//     pc-unreact { content, id, done() } — one of our own reaction chips
//                clicked (post.my_reactions maps emoji -> our reaction id)
//   Chip clicks (react / unreact) ask first in a small dialog: Enter
//   confirms, Esc cancels. Picks from the picker do not. The dialog is
//   exposed as window.confirmModal(text, okLabel) -> Promise<boolean>.
//
// DESIGN NOTES — chips are buttons inside the shadow root so the host's
// button styles don't leak in; the who slot sits under the row inside the
// card so the list reads as part of it. Time is shown as a short age with
// the full date as a tooltip. Keep this template literal backtick-free.

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    /* padding lives on an inner box: a host page's "* { padding: 0 }"
       reset outranks :host, and would strip it */
    :host { display: block; font-family: inherit; font-size: 13px; color: #1f2328; cursor: pointer; min-width: 0; }
    #box { padding: var(--pc-pad, 13px 18px); border-bottom: var(--pc-border, 1px solid #f2f4f6); }
    :host([in-thread]) { cursor: default; }
    :host([target]) { background: #f8f5ff; }
    :host([hidden]) { display: none; }
    :host([compact]) { cursor: pointer; }
    :host([compact]) #box { padding: 6px 10px 7px; margin-top: 6px; border: 1px solid #e4e7eb; border-radius: 10px; background: #fff; line-height: 1.4; }
    :host([compact]:hover) #box { border-color: #c9b8f2; }
    :host([compact]) #head { margin-bottom: 2px; }
    :host([compact]) ::slotted([slot="content"]) { line-height: 1.45; }
    :host([compact]) #av { --av-size: 22px; }
    :host([compact]) #row, :host([compact]) #id, :host([compact]) #ctx { display: none; }
    #head { display: flex; align-items: center; gap: 9px; margin-bottom: 6px; }
    #who { font-weight: 650; font-size: 13.5px; cursor: pointer; }
    #who.pk { font-family: "SF Mono", Menlo, monospace; font-weight: 500; color: var(--pc-muted, #57606a); }
    #who:hover { text-decoration: underline; }
    #age { margin-left: auto; font-size: 12px; color: #9aa0a8; }
    #ctx { font-size: 11.5px; color: var(--pc-accent, #6b3fd6); margin: -2px 0 6px; }
    #ctx[hidden] { display: none; }
    #rep { font-size: 11.5px; color: var(--pc-muted, #57606a); margin: 0 0 7px; display: flex; align-items: center; gap: 6px; }
    #rep[hidden] { display: none; }
    #rep .by { font-weight: 600; cursor: pointer; }
    #rep .by:hover { text-decoration: underline; }
    ::slotted([slot="content"]) { font-size: 14px; line-height: 1.55; white-space: pre-wrap; word-break: break-word; }
    #row { display: flex; align-items: center; gap: 6px; margin-top: 8px; flex-wrap: wrap; }
    #row .grow { flex: 1; }
    button { font: inherit; cursor: pointer; line-height: 1.5; }
    button.stat {
      padding: 2px 9px; border-radius: 999px; font-size: 12px;
      border: 1px solid transparent; background: #f4f5f7; color: var(--pc-muted, #57606a);
    }
    button.stat:hover { background: #ebedf0; color: #1f2328; }
    button.act {
      padding: 5px 12px; border-radius: 8px; font-size: 12px;
      border: 1px solid #d6dae0; background: #fff; color: #1f2328;
    }
    button.act:hover { background: #f0f2f4; }
    button.stat.emoji { font-size: 13px; }
    button.stat.mine { background: #f1ecfb; border-color: #c9b8f2; color: #4b2ca8; }
    button.stat.mine:hover { background: #e6dcfa; }
    button.busy { position: relative; color: transparent; pointer-events: none; }
    button.busy::after {
      content: ''; position: absolute; inset: 0; margin: auto; width: 12px; height: 12px;
      border: 2px solid #e4e7eb; border-top-color: var(--pc-accent, #6b3fd6); border-radius: 50%;
      animation: spin .8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    #whoslot { display: block; }
    ::slotted([slot="who"]) { margin-top: 6px; }
    #id { margin-top: 6px; font-family: "SF Mono", Menlo, monospace; font-size: 10.5px; color: #c4c8cd; }
    #id[hidden] { display: none; }
    #id a { color: inherit; text-decoration: none; }
    #id a:hover { color: var(--pc-accent, #6b3fd6); }
  </style>
  <div id="box">
    <div id="rep" hidden>🔁 <span class="by"></span><span class="when"></span></div>
    <div id="head">
      <avatar-pic id="av" size="30"></avatar-pic>
      <span id="who"></span>
      <span id="age"></span>
    </div>
    <div id="ctx" hidden>replying in a thread</div>
    <slot name="content"></slot>
    <div id="row"></div>
    <slot name="who" id="whoslot"></slot>
    <div id="id" hidden><a target="_blank"></a></div>
  </div>
`;

class PostCard extends HTMLElement {
  static get observedAttributes() { return ['depth', 'link', 'in-thread']; }
  #post = null;
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    const $ = (id) => this.shadowRoot.getElementById(id);
    const person = (e) => { e.stopPropagation(); if (this.#post) this.#emit('pc-person', { pubkey: this.#post.pubkey }); };
    $('av').addEventListener('click', person);
    $('who').addEventListener('click', person);
    this.addEventListener('click', (e) => {
      if (this.hasAttribute('in-thread') && !this.hasAttribute('compact')) return;
      const path = e.composedPath();
      if (path.some((n) => n.tagName === 'A' || n.tagName === 'BUTTON')) return;
      this.#emit('pc-open', {});
    });
  }
  connectedCallback() {
    // a classic-script host may have set .post before upgrade
    if (Object.prototype.hasOwnProperty.call(this, 'post')) { const v = this.post; delete this.post; this.post = v; }
    this.#render();
  }
  attributeChangedCallback() { if (this.isConnected) this.#render(); }
  get post() { return this.#post; }
  set post(v) { this.#post = v || null; if (this.isConnected) this.#render(); }
  #emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail: Object.assign({ post: this.#post }, detail), bubbles: true, composed: true }));
  }
  #render() {
    const p = this.#post; if (!p) return;
    const $ = (id) => this.shadowRoot.getElementById(id);
    const prof = p.profile || {};
    const pk = p.pubkey || '';
    const depth = parseInt(this.getAttribute('depth') || '0', 10);
    this.style.marginLeft = depth ? Math.min(depth, 6) * 18 + 'px' : '';
    const av = $('av');
    av.setAttribute('name', prof.name || ''); av.setAttribute('seed', pk); av.setAttribute('src', prof.picture || '');
    const who = $('who');
    who.textContent = prof.name || pk.slice(0, 12);
    who.classList.toggle('pk', !prof.name);
    who.title = 'open ' + (prof.name || pk);
    const age = $('age');
    age.textContent = fmtAge(p.created_at);
    age.title = p.created_at ? new Date(p.created_at * 1000).toLocaleString() : '';
    const rep = $('rep');
    rep.hidden = !p.repost;
    if (p.repost) {
      const by = rep.querySelector('.by');
      by.textContent = (p.repost.name || (p.repost.pubkey || '').slice(0, 12)) + ' reposted';
      by.title = p.repost.pubkey || '';
      by.onclick = (e) => { e.stopPropagation(); this.#emit('pc-person', { pubkey: p.repost.pubkey }); };
      rep.querySelector('.when').textContent = fmtAge(p.repost.at);
    }
    const ctx = $('ctx');
    ctx.hidden = !(p.reply_to && !this.hasAttribute('in-thread'));
    if (p.reply_to) ctx.title = 'root ' + (p.reply_to.root || '').slice(0, 12) + '… · parent ' + (p.reply_to.parent || '').slice(0, 12) + '…';
    // the row
    const row = $('row'); row.textContent = '';
    const c = p.counts || {};
    const inThread = this.hasAttribute('in-thread');
    const stat = (text, title, on) => {
      const b = document.createElement('button'); b.className = 'stat'; b.textContent = text; b.title = title;
      b.addEventListener('click', (e) => { e.stopPropagation(); on(); }); row.appendChild(b);
    };
    if (c.replies) stat('💬 ' + c.replies, inThread ? 'replies · reply to this one' : 'replies · open the thread',
      () => this.#emit(inThread ? 'pc-reply' : 'pc-open', {}));
    if (c.reposts) stat('🔁 ' + c.reposts, 'reposts', () => this.#emit('pc-who', {}));
    const emojis = p.reactions || {};
    const react = (content, btn) => {
      btn.classList.add('busy');
      this.#emit('pc-react', { content, done: () => btn.classList.remove('busy') });
    };
    const mine = p.my_reactions || {};
    const whoName = (prof.name || pk.slice(0, 12));
    Object.keys(emojis).sort((x, y) => emojis[y] - emojis[x]).forEach((k) => {
      const shown = (k === '+' || !k) ? '👍' : k;
      const key = k === '' ? '+' : k;
      const own = mine[key];
      const b = document.createElement('button'); b.className = 'stat emoji' + (own ? ' mine' : ''); b.textContent = shown + ' ' + emojis[k];
      b.title = own ? 'you reacted ' + shown + ' — click to take it back' : 'react ' + shown + ' too';
      b.addEventListener('click', async (e) => {
        e.stopPropagation();
        if (own) {
          if (!(await confirmModal('Take back your ' + shown + ' on ' + whoName + "'s post?", 'Unreact'))) return;
          b.classList.add('busy');
          this.#emit('pc-unreact', { content: key, id: own, done: () => b.classList.remove('busy') });
        } else {
          if (!(await confirmModal('React ' + shown + ' to ' + whoName + "'s post?", 'React ' + shown))) return;
          react(key, b);
        }
      });
      row.appendChild(b);
    });
    if (c.reposts || c.reactions || Object.keys(emojis).length) stat('👥', 'who reacted and reposted', () => this.#emit('pc-who', {}));
    const grow = document.createElement('span'); grow.className = 'grow'; row.appendChild(grow);
    const reply = document.createElement('button'); reply.className = 'act'; reply.textContent = 'Reply';
    reply.addEventListener('click', (e) => { e.stopPropagation(); this.#emit('pc-reply', {}); });
    const rp = document.createElement('button'); rp.className = 'act'; rp.textContent = 'Repost'; rp.title = 'repost to your followers (a kind-6 event)';
    rp.addEventListener('click', (e) => { e.stopPropagation(); rp.classList.add('busy'); this.#emit('pc-repost', { done: () => rp.classList.remove('busy') }); });
    // React opens the kit's <emoji-picker> in one shared modal
    const pb = document.createElement('button'); pb.className = 'act'; pb.textContent = 'React'; pb.title = 'react with an emoji (a kind-7 event)';
    pb.addEventListener('click', (e) => { e.stopPropagation(); openEmojiModal((em) => react(em === '👍' ? '+' : em, pb)); });
    row.append(reply, rp, pb);
    // the id line
    const link = this.getAttribute('link');
    const id = $('id'); id.hidden = !link;
    if (link) { const a = id.querySelector('a'); a.href = link; a.textContent = (p.id || '').slice(0, 16) + '…'; a.title = 'the event grub'; }
  }
}

// a small confirm: Enter confirms (the OK button has focus), Esc cancels
let confirmDlg = null, confirmRes = null;
function confirmModal(text, okLabel) {
  if (!confirmDlg) {
    const st = document.createElement('style');
    st.textContent = '.pc-confirm { --md-width: 360px; --md-pad: 18px 20px; --md-radius: 14px; }' +
      '.pc-confirm .msg { font-size: 14px; color: #1f2328; margin: 0 24px 14px 0; line-height: 1.5; }' +
      '.pc-confirm .btns { display: flex; justify-content: flex-end; gap: 8px; }' +
      '.pc-confirm button { padding: 6px 14px; border-radius: 8px; font: inherit; font-size: 13px; cursor: pointer; border: 1px solid #d6dae0; background: #fff; color: #1f2328; }' +
      '.pc-confirm button.ok { background: #6b3fd6; border-color: #6b3fd6; color: #fff; }' +
      '.pc-confirm button.ok:focus { outline: 2px solid #c9b8f2; outline-offset: 2px; }';
    document.head.appendChild(st);
    confirmDlg = document.createElement('modal-dialog'); confirmDlg.className = 'pc-confirm'; confirmDlg.setAttribute('no-x', '');
    confirmDlg.innerHTML = '<div class="msg"></div><div class="btns"><button class="cancel" type="button">Cancel</button><button class="ok" type="button">OK</button></div>';
    confirmDlg.querySelector('.cancel').onclick = () => { const r = confirmRes; confirmRes = null; confirmDlg.close(); if (r) r(false); };
    confirmDlg.querySelector('.ok').onclick = () => { const r = confirmRes; confirmRes = null; confirmDlg.close(); if (r) r(true); };
    confirmDlg.addEventListener('md-close', () => { const r = confirmRes; confirmRes = null; if (r) r(false); });
    confirmDlg.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); confirmDlg.querySelector('.ok').click(); } });
    document.body.appendChild(confirmDlg);
  }
  confirmDlg.querySelector('.msg').textContent = text;
  confirmDlg.querySelector('.ok').textContent = okLabel || 'OK';
  return new Promise((res) => { confirmRes = res; confirmDlg.show(); setTimeout(() => confirmDlg.querySelector('.ok').focus(), 0); });
}

// the confirm is useful to the host page too (destructive buttons)
window.confirmModal = confirmModal;

// one <modal-dialog> holding one <emoji-picker>, shared by every card on
// the page; created on first use, appended to the document body
let emojiModal = null, emojiPicker = null, emojiCb = null;
function openEmojiModal(cb) {
  if (!emojiModal) {
    const st = document.createElement('style');
    st.textContent = '.pc-emoji-modal { --md-width: 340px; --md-pad: 0; --md-radius: 14px; }';
    document.head.appendChild(st);
    emojiModal = document.createElement('modal-dialog'); emojiModal.className = 'pc-emoji-modal';
    emojiPicker = document.createElement('emoji-picker');
    emojiPicker.setAttribute('inline', ''); emojiPicker.setAttribute('persist', 'post-card-recent');
    emojiPicker.addEventListener('ep-pick', (e) => { const f = emojiCb; emojiCb = null; emojiModal.close(); if (f) f(e.detail.emoji); });
    emojiPicker.addEventListener('ep-close', () => emojiModal.close());
    emojiModal.appendChild(emojiPicker);
    document.body.appendChild(emojiModal);
  }
  emojiCb = cb;
  emojiModal.show();
  emojiPicker.focus();
}

function fmtAge(unix) {
  if (!unix) return '';
  const s = Math.max(0, Date.now() / 1000 - unix);
  if (s < 60) return 'now';
  if (s < 3600) return Math.round(s / 60) + 'm';
  if (s < 86400) return Math.round(s / 3600) + 'h';
  return Math.round(s / 86400) + 'd';
}

customElements.define('post-card', PostCard);
