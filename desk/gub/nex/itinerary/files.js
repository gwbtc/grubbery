// Files tab — the shared file-manager (lib/ui/file-manager.js) fenced to
// this trip's files/. The lib owns the markup, styling, viewer and every
// server call; this file only tells it which directory is the trip's and
// re-fences it when the trip changes. Mounts lazily: the listing is
// fetched the first time the tab is actually shown.
'use strict';

(function () {
  var ITINS = '/grubbery/ball/apps/itinerary/itineraries';
  var mount = document.getElementById('files-mount');
  var fm = FileManager.mount(mount, { persist: 'itin-files-view', rootLabel: 'files', lazy: true });
  var loaded = false;

  function visible() { return mount.offsetParent !== null; }
  function bind() {
    var id = window.currentId;
    loaded = false;
    fm.ready.then(function () {
      fm.setRoot(id ? ITINS + '/' + encodeURIComponent(id) + '/files' : null);
      if (id && visible()) { loaded = true; fm.load(); }
    });
  }
  window.addEventListener('itin-changed', bind);
  document.getElementById('side-tabs').addEventListener('tg-change', function (e) {
    if (e.detail.label === 'Files' && window.currentId && !loaded) { loaded = true; fm.load(); }
  });
  if (window.currentId) bind();
})();
