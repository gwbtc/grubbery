// PostText — how a social post's text becomes DOM, shared by every nexus
// that shows posts (nostr, ghostprompter, feeds…). A post is TEXT plus
// ATTACHED MEDIA: urls that point at images, video files, or an embeddable
// player (youtube) come out of the text and render as an attachment block
// below it; other urls stay as links;
// nostr: mentions (npub / note / nprofile / nevent) become handles that
// the host resolves. Not a component (no element of its own — it fills the
// host's elements), so it is a plain global, safe to weld into a bundle.
//
// USAGE (classic script or welded into components.js)
//   PostText.render(el, text, {
//     onPerson: (hex) => openPerson(hex),      // a mention of a person was clicked
//     onPost:   (hex) => openThread(hex),      // a mention of a post was clicked
//     nameFor:  async (hex) => 'name' | null,  // optional: fills in @name
//     onTag:    (tag) => …,                    // optional: a #hashtag was clicked (lowercased, no #)
//   });
//   const media = PostText.mediaOf(text);      // [{ url, video }]
//   el.appendChild(PostText.attachments(media, 'thumb', (i) => open(i)));
//   // modes: 'thumb' (height-capped previews, fade + badge when clipped)
//   //        'full'  (natural size, videos playable)
//
// The attachment styles inject once into the document head on first use
// (class prefix .attach), so a host needs no CSS of its own for them.
// Mentions get class "mention person" / "mention post", hashtags "hashtag",
// for the host to color.
(function () {
  'use strict';
  var IMG_RE = /\.(jpe?g|png|gif|webp|avif)(\?\S*)?$/i;
  var VID_RE = /\.(mp4|webm|mov|m4v)(\?\S*)?$/i;
  var TOKEN = /https?:\/\/[^\s<>"')\]]+|(?:nostr:)?\b(?:npub|note|nprofile|nevent)1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{20,}|(?:^|(?<=\s))#[\p{L}\p{N}_]{2,}/gu;
  var CSS = '.attach { margin-top: 8px; }\n' +
    '.attach .attach-cell { position: relative; overflow: hidden; }\n' +
    '.attach .attach-cell.clickable { cursor: pointer; }\n' +
    '.attach img, .attach video { display: block; }\n' +
    '.attach .vid-badge { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: 34px; height: 34px; border-radius: 50%; background: rgba(15,15,22,0.72); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 13px; pointer-events: none; z-index: 1; }\n' +
    '.attach.thumb { display: flex; flex-direction: column; gap: 8px; }\n' +
    '.attach.thumb .attach-cell { margin: 0 auto; max-width: 100%; width: fit-content; max-height: 190px; overflow: hidden; border-radius: 12px; box-shadow: 0 2px 12px rgba(20,18,40,0.12); }\n' +
    '.attach.thumb img, .attach.thumb video { display: block; max-width: 100%; width: auto; height: auto; border-radius: 12px; }\n' +
    '.attach.thumb video { max-height: 190px; }\n' +
    '.attach.thumb .attach-cell.cut::after { content: ""; position: absolute; left: 0; right: 0; bottom: 0; height: 44px; pointer-events: none; background: linear-gradient(to bottom, rgba(255,255,255,0), rgba(255,255,255,0.92)); }\n' +
    '.attach.thumb .attach-cell.cut::before { content: "\\2922"; position: absolute; right: 7px; bottom: 6px; z-index: 1; width: 22px; height: 22px; border-radius: 7px; background: rgba(31,35,40,0.72); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 12px; pointer-events: none; }\n' +
    '.attach.full { display: flex; flex-direction: column; gap: 12px; margin-top: 14px; }\n' +
    '.attach.full .attach-cell { border-radius: 12px; margin: 0 auto; max-width: 100%; width: fit-content; }\n' +
    '.attach.full img, .attach.full video { max-width: 100%; max-height: 440px; width: auto; height: auto; border-radius: 12px; }\n' +
    '.attach iframe.embed { display: block; width: min(100%, 640px); aspect-ratio: 16 / 9; border: 0; border-radius: 12px; background: #000; }\n' +
    '.attach.full .attach-cell:has(iframe.embed) { width: 100%; max-width: 640px; }\n';
  var styled = false;
  function ensureCss() {
    if (styled) return;
    var st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st); styled = true;
  }

  // embeds: sites whose links are really a video. youtube for now;
  // returns { embed: player url, poster: still } or null
  var YT_RE = /^https?:\/\/(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/;
  function embedOf(url) {
    var m = YT_RE.exec(url);
    if (m) return { embed: 'https://www.youtube-nocookie.com/embed/' + m[1], poster: 'https://i.ytimg.com/vi/' + m[1] + '/hqdefault.jpg' };
    return null;
  }
  function classify(url) {
    if (VID_RE.test(url)) return 'video';
    if (IMG_RE.test(url) || /picsum\.photos|\/media\./.test(url)) return 'image';
    if (embedOf(url)) return 'embed';
    return 'link';
  }
  function mediaOf(text) {
    var out = [];
    String(text || '').split(/(https?:\/\/\S+)/g).forEach(function (part) {
      if (!/^https?:\/\//.test(part)) return;
      var kind = classify(part);
      if (kind === 'link') return;
      var m = { url: part, video: kind === 'video' };
      if (kind === 'embed') { var e = embedOf(part); m.embed = e.embed; m.poster = e.poster; }
      out.push(m);
    });
    return out;
  }
  // an embedded player (16:9 iframe)
  function embedEl(m) {
    var f = document.createElement('iframe');
    f.src = m.embed; f.allow = 'accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen';
    f.allowFullscreen = true; f.referrerPolicy = 'strict-origin-when-cross-origin'; f.loading = 'lazy';
    f.className = 'embed';
    return f;
  }

  // ---- NIP-19: bech32 identifiers (npub, note, nprofile, nevent) ----
  var B32 = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  function bech32Decode(str) {
    var s = str.toLowerCase();
    var pos = s.lastIndexOf('1');
    if (pos < 1) return null;
    var hrp = s.slice(0, pos), data = [];
    for (var i = pos + 1; i < s.length; i++) { var v = B32.indexOf(s[i]); if (v < 0) return null; data.push(v); }
    var words = data.slice(0, -6), bytes = [], acc = 0, bits = 0;
    for (var j = 0; j < words.length; j++) {
      acc = (acc << 5) | words[j]; bits += 5;
      while (bits >= 8) { bits -= 8; bytes.push((acc >> bits) & 255); }
    }
    return { hrp: hrp, bytes: bytes };
  }
  function hex(bytes) { return bytes.map(function (b) { return ('0' + b.toString(16)).slice(-2); }).join(''); }
  function nip19(str) {
    var d = bech32Decode(str); if (!d) return null;
    if (d.hrp === 'npub' && d.bytes.length === 32) return { kind: 'person', id: hex(d.bytes) };
    if (d.hrp === 'note' && d.bytes.length === 32) return { kind: 'post', id: hex(d.bytes) };
    if (d.hrp === 'nprofile' || d.hrp === 'nevent') {
      for (var i = 0; i + 1 < d.bytes.length;) {
        var t = d.bytes[i], l = d.bytes[i + 1];
        if (t === 0 && l === 32) return { kind: d.hrp === 'nprofile' ? 'person' : 'post', id: hex(d.bytes.slice(i + 2, i + 34)) };
        i += 2 + l;
      }
    }
    return null;
  }

  function linkEl(url) {
    var a = document.createElement('a');
    a.href = url; a.target = '_blank'; a.rel = 'noopener';
    var label = url.replace(/^https?:\/\/(www\.)?/, '');
    if (label.length > 48) label = label.slice(0, 45) + '…';
    a.textContent = label;
    a.addEventListener('click', function (e) { e.stopPropagation(); });
    return a;
  }
  // a hashtag: on nostr a `t` tag relays can filter on ({"#t": [...]}),
  // so it is a link to "more of this", when the host has somewhere to go
  function tagEl(tok, opts) {
    var a = document.createElement('a');
    a.href = '#'; a.className = 'hashtag'; a.textContent = tok; a.title = 'tag ' + tok.slice(1);
    a.onclick = function (e) { e.preventDefault(); e.stopPropagation(); if (opts.onTag) opts.onTag(tok.slice(1).toLowerCase()); };
    return a;
  }
  function mentionEl(tok, opts) {
    var ref = nip19(tok.replace(/^nostr:/, ''));
    var a = document.createElement('a');
    a.href = '#'; a.className = 'mention ' + (ref ? ref.kind : 'unknown');
    if (!ref) { a.textContent = tok.slice(0, 18) + '…'; a.title = 'could not decode'; return a; }
    a.title = ref.id;
    if (ref.kind === 'person') {
      a.textContent = '@' + ref.id.slice(0, 8) + '…';
      if (opts.nameFor) Promise.resolve(opts.nameFor(ref.id)).then(function (n) { if (n) a.textContent = '@' + n; });
      a.onclick = function (e) { e.preventDefault(); e.stopPropagation(); if (opts.onPerson) opts.onPerson(ref.id); };
    } else {
      a.textContent = 'note ' + ref.id.slice(0, 8) + '…';
      a.onclick = function (e) { e.preventDefault(); e.stopPropagation(); if (opts.onPost) opts.onPost(ref.id); };
    }
    return a;
  }

  // text → nodes: media urls dropped (they render as attachments), other
  // urls as links, mentions as handles, the rest as text; whitespace
  // around a dropped url collapses so the text doesn't gap where it was.
  function render(el, text, opts) {
    opts = opts || {};
    text = String(text || '');
    var parts = [], last = 0, m;
    TOKEN.lastIndex = 0;
    while ((m = TOKEN.exec(text))) {
      if (m.index > last) parts.push({ text: text.slice(last, m.index) });
      parts.push({ tok: m[0] });
      last = m.index + m[0].length;
    }
    if (last < text.length) parts.push({ text: text.slice(last) });
    var isMedia = function (p) { return p && p.tok && /^https?:/.test(p.tok) && classify(p.tok) !== 'link'; };
    parts.forEach(function (p, i) {
      if (p.tok) {
        if (isMedia(p)) return;
        el.appendChild(/^https?:/.test(p.tok) ? linkEl(p.tok) : p.tok.charAt(0) === '#' ? tagEl(p.tok, opts) : mentionEl(p.tok, opts));
        return;
      }
      var t = p.text.replace(/\n{3,}/g, '\n\n');
      var prevM = isMedia(parts[i - 1]), nextM = isMedia(parts[i + 1]);
      if (t.trim() === '' && (prevM || nextM)) return;
      if (prevM) t = t.replace(/^\s+/, '');
      if (nextM) t = t.replace(/\s+$/, '');
      if (t) el.appendChild(document.createTextNode(t));
    });
  }

  function attachments(media, mode, onMedia) {
    ensureCss();
    var box = document.createElement('div');
    box.className = 'attach ' + (mode || 'thumb');
    media.forEach(function (m, i) {
      var cell = document.createElement('div'); cell.className = 'attach-cell';
      var el;
      if (m.embed && mode === 'full') {
        el = embedEl(m);
      } else if (m.embed) {
        // feed preview: the poster with a play badge; the viewer plays it
        el = document.createElement('img');
        el.loading = 'lazy'; el.referrerPolicy = 'no-referrer'; el.src = m.poster; el.alt = '';
        el.onerror = function () { el.remove(); };
        var pb = document.createElement('span'); pb.className = 'vid-badge'; pb.textContent = '▶';
        cell.appendChild(pb);
      } else if (m.video) {
        el = document.createElement('video');
        el.preload = 'metadata'; el.playsInline = true;
        if (mode === 'full') el.controls = true;
        else {
          el.muted = true;
          var badge = document.createElement('span'); badge.className = 'vid-badge'; badge.textContent = '▶';
          cell.appendChild(badge);
        }
      } else {
        el = document.createElement('img');
        el.loading = 'lazy'; el.referrerPolicy = 'no-referrer';
        el.onerror = function () { cell.remove(); };
        if (mode !== 'full') el.onload = function () { if (el.offsetHeight > cell.clientHeight + 2) cell.classList.add('cut'); };
      }
      if (!m.embed) el.src = m.url;
      cell.insertBefore(el, cell.firstChild);
      if (onMedia && !((m.video || m.embed) && mode === 'full')) {
        cell.addEventListener('click', function (e) { e.stopPropagation(); onMedia(i, m); });
        cell.classList.add('clickable');
      }
      box.appendChild(cell);
    });
    return box;
  }

  window.PostText = { render: render, mediaOf: mediaOf, classify: classify, embedOf: embedOf, embedEl: embedEl, attachments: attachments, nip19: nip19, bech32Decode: bech32Decode };
})();
