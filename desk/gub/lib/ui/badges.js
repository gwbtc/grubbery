// Shared row badges for the <tree-view> sidebar: a weir shield on restricted
// directories, and fixed-width name chips for a directory's neck or a file's
// blot (clipped with an ellipsis, full value on hover). Used by both the
// explorer and the forge, welded into each app's kit bundle.
//
// window.attachBadges(row, item, opts) builds a .row-badges span and appends
// it to the row (returning the span). The host owns the show/hide toggle: it
// passes the current state as opts.enabled and flips every .row-badges display
// itself (the spans live in the <tree-view> shadow DOM).
//
//   opts.enabled          initial visibility (false → start hidden)
//   opts.onWeir(item,row) shield click; omit to suppress the shield
//   opts.onNeck(item,row) neck chip click; omit to suppress the neck chip
//   opts.onBlot(item,row) blot chip click; omit to suppress the blot chip
//
// item fields read: kind ('dir' | 'file'), hasWeir (bool), neck (str | null),
// blot (str | null). A click's stopPropagation keeps the row from toggling.
(function () {
  // monochrome filled shield — tints with the pill color via currentColor
  var SHIELD =
    '<svg viewBox="0 0 24 24" width="12" height="12" style="display:block" ' +
    'fill="currentColor" aria-hidden="true">' +
    '<path d="M12 1 3 5v6c0 5.25 3.75 9.75 9 11 5.25-1.25 9-5.75 9-11V5z"/></svg>';

  function pill(content, title, bg, fg, bd, onClick) {
    var b = document.createElement('span');
    if (content[0] === '<') b.innerHTML = content; else b.textContent = content;
    b.title = title;
    b.style.cssText =
      'display:inline-flex;align-items:center;justify-content:center;' +
      'min-width:18px;height:18px;padding:0 5px;margin-left:4px;border-radius:4px;' +
      'font:700 10px ui-monospace,Menlo,monospace;cursor:pointer;' +
      'background:' + bg + ';color:' + fg + ';border:1px solid ' + bd + ';';
    b.addEventListener('click', function (e) { e.stopPropagation(); onClick(); });
    return b;
  }

  function chip(txt, title, bg, fg, bd, onClick) {
    var b = document.createElement('span');
    b.textContent = txt;
    b.title = title;
    b.style.cssText =
      'display:inline-block;box-sizing:border-box;width:92px;' +
      'padding:2px 7px;margin-left:4px;border-radius:4px;cursor:pointer;' +
      'font:600 10px ui-monospace,Menlo,monospace;line-height:1.3;' +
      'overflow:hidden;text-overflow:ellipsis;white-space:nowrap;' +
      'background:' + bg + ';color:' + fg + ';border:1px solid ' + bd + ';';
    b.addEventListener('click', function (e) { e.stopPropagation(); onClick(); });
    return b;
  }

  window.attachBadges = function (row, item, opts) {
    opts = opts || {};
    var badges = document.createElement('span');
    badges.className = 'row-badges';
    badges.style.cssText =
      'flex:none;margin-left:6px;align-items:center;display:' +
      (opts.enabled === false ? 'none' : 'inline-flex') + ';';
    if (item.kind === 'dir') {
      if (item.hasWeir && opts.onWeir)
        badges.appendChild(pill(SHIELD, 'restricted',
          '#fff1d6', '#9a6700', '#f0d9a8', function () { opts.onWeir(item, row); }));
      if (item.neck && opts.onNeck)
        badges.appendChild(chip(item.neck, item.neck,
          '#eef1f4', '#57606a', '#dfe3e8', function () { opts.onNeck(item, row); }));
    } else if (item.kind === 'file' && item.blot && opts.onBlot) {
      badges.appendChild(chip(item.blot, item.blot,
        '#f3eefc', '#8250df', '#e4d8f7', function () { opts.onBlot(item, row); }));
    }
    if (badges.children.length) row.appendChild(badges);
    return badges;
  };
})();
