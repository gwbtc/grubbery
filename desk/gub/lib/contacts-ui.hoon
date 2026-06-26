::  contacts-ui: contacts page rendering
::
::  Overlay fields (local edits):
::    nickname  — display name
::    notes     — free text
::
::  Profile fields (peer-published, read-only):
::    nickname, bio, status, color, avatar
::
/<  feather  /lib/feather.hoon
|%
::
++  contacts-page
  |=  [profiles=(map @t (map @t json)) contacts=(map @t (map @t json))]
  ^-  manx
  =/  ships=(list @t)
    =-  ~(tap in -)
    (~(uni in ~(key by profiles)) ~(key by contacts))
  ;html
    ;head
      ;title: Contacts
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  style
      ==
    ==
    ;body
      ;div.container
        ;div.header
          ;h1: Contacts
          ;button.btn-add(onclick "addContact()")
            ;+  icon-plus
          ==
        ==
        ;div#contacts-list
          ;*  ?~  ships
                =/  empty=manx  ;span.muted: No contacts yet
                ~[empty]
              (turn ships |=(s=@t (contact-card s profiles contacts)))
        ==
      ==
      ;div#edit-modal.modal.hidden
        ;div.modal-content
          ;div.modal-header
            ;h2#modal-title: Contact
            ;button.btn-close(onclick "closeModal()")
              ;+  icon-x
            ==
          ==
          ;div.modal-tabs
            ;button.tab.active(onclick "switchTab('contact')", id "tab-contact"): Contact
            ;button.tab(onclick "switchTab('profile')", id "tab-profile"): Profile
          ==
          ;div#panel-contact.panel
            ;div.modal-body
              ;input#modal-ship(type "hidden");
              ;div#modal-ames-row.field-row.hidden
                ;label: Ames
                ;span#modal-ames.ames-tag;
              ==
              ;div.field-row
                ;label: Nickname
                ;input#field-nickname.field-input(type "text", placeholder "Display name");
              ==
              ;div.field-row
                ;label: Notes
                ;textarea#field-notes.field-input(rows "3", placeholder "Private notes");
              ==
              ;div.field-row
                ;label: Tags
                ;div#tags-container.tags-container;
                ;div.tags-input-wrap
                  ;input#field-tag-input.field-input(type "text", placeholder "Add tag...", onkeydown "tagKeydown(event)");
                ==
              ==
            ==
            ;div.modal-footer
              ;button.btn.btn-delete(onclick "deleteContact()")
                ;+  icon-trash
                ;span: Delete
              ==
              ;button.btn.btn-save(onclick "saveContact()"): Save
            ==
          ==
          ;div#panel-profile.panel.hidden
            ;div.modal-body
              ;div#profile-fields.profile-fields;
            ==
          ==
        ==
      ==
      ;script
        ;+  ;/  (weld "var PROFILES=" (weld (trip (en:json:html [%o (~(run by profiles) |=((map @t json) [%o +<]))])) ";"))
        ;+  ;/  (weld "var CONTACTS=" (weld (trip (en:json:html [%o (~(run by contacts) |=((map @t json) [%o +<]))])) ";"))
        ;+  ;/  js
      ==
    ==
  ==
::
++  contact-card
  |=  [ship=@t profiles=(map @t (map @t json)) contacts=(map @t (map @t json))]
  ^-  manx
  =/  con=(map @t json)  (fall (~(get by contacts) ship) ~)
  =/  pro=(map @t json)  (fall (~(get by profiles) ship) ~)
  =/  nick=tape
    =/  cn=tape  (get-text con 'nickname')
    ?~(cn (get-text pro 'nickname') cn)
  =/  display=tape  ?~(nick (trip ship) nick)
  =/  stat=tape  (get-text pro 'status')
  =/  color=tape  (get-text pro 'color')
  =/  avatar=tape  (get-text pro 'avatar')
  =/  ames=tape  (get-text con 'ames')
  =/  tags=(list tape)  (get-tags con 'tags')
  =/  ship-t=tape  (trip ship)
  ;div.contact-card
    ;div.card-main(onclick "openContact('{ship-t}')")
      ;div.card-left
        ;+  ?~  avatar
              ;div.avatar-placeholder(style ?~(color "background:#888" "background:#{color}"))
                ;+  ;/  (scag 2 display)
              ==
            ;img.avatar(src "{avatar}");
      ==
      ;div.card-info
        ;span.name: {display}
        ;+  (render-ship-sub nick ship-t ames)
        ;+  (render-card-meta tags stat)
      ==
    ==
    ;button.card-delete(onclick "quickDelete('{ship-t}')")
      ;+  icon-trash
    ==
  ==
::
++  get-text
  |=  [m=(map @t json) key=@t]
  ^-  tape
  =/  val=(unit json)  (~(get by m) key)
  ?~  val  ~
  ?.(?=([%s @] u.val) ~ (trip p.u.val))
::
++  render-ship-sub
  |=  [nick=tape ship-t=tape ames=tape]
  ^-  manx
  ?~  ames
    ;span.ship-sub: {ship-t}
  ;span.ship-sub
    ;+  ;/  ship-t
    ;span.ames-tag(class "{ames}"): {ames}
  ==
::
++  render-card-meta
  |=  [tags=(list tape) stat=tape]
  ^-  manx
  ?^  tags
    ;div.card-tags
      ;*  (render-tag-chips tags)
    ==
  ?^  stat
    ;span.status: {stat}
  ;span;
::
++  render-tag-chips
  |=  tags=(list tape)
  ^-  (list manx)
  %+  turn  tags
  |=  t=tape
  ^-  manx
  ;span.card-tag: {t}
::
++  get-tags
  |=  [m=(map @t json) key=@t]
  ^-  (list tape)
  =/  val=(unit json)  (~(get by m) key)
  ?~  val  ~
  ?.  ?=([%a *] u.val)  ~
  %+  murn  p.u.val
  |=(=json ?.(?=([%s @] json) ~ `(trip p.json)))
::  feather-style inline SVG icons
::
++  icon-plus
  ^-  manx
  ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "18", height "18", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
    ;line(x1 "12", y1 "5", x2 "12", y2 "19");
    ;line(x1 "5", y1 "12", x2 "19", y2 "12");
  ==
::
++  icon-x
  ^-  manx
  ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "18", height "18", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
    ;line(x1 "18", y1 "6", x2 "6", y2 "18");
    ;line(x1 "6", y1 "6", x2 "18", y2 "18");
  ==
::
++  icon-trash
  ^-  manx
  ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "14", height "14", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
    ;polyline(points "3 6 5 6 21 6");
    ;path(d "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2");
  ==
::
++  style
  ^-  tape
  ;:  weld
    " .container \{ max-width: 640px; margin: 0 auto; padding: 1.5rem; }"
    " .header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; }"
    " h1 \{ font-size: 1.5rem; font-weight: 600; }"
    " .btn \{ padding: 0.4rem 0.8rem; border: 1px solid #ccc; border-radius: 6px; background: #fff; cursor: pointer; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 0.35rem; }"
    " .btn:hover \{ background: #eee; }"
    " .btn-save \{ background: #222; color: #fff; border-color: #222; }"
    " .btn-save:hover \{ background: #444; }"
    " .btn-delete \{ color: #c00; border-color: #c00; }"
    " .btn-delete:hover \{ background: #fee; }"
    " .btn-add \{ width: 36px; height: 36px; border-radius: 50%; border: 1.5px solid #ddd; background: #fff; color: #999; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.15s; }"
    " .btn-add:hover \{ border-color: #222; color: #222; }"
    " .btn-close \{ background: none; border: none; cursor: pointer; color: #999; display: flex; padding: 2px; border-radius: 4px; }"
    " .btn-close:hover \{ color: #222; background: #f0f0f0; }"
    " .contact-card \{ display: flex; align-items: center; background: #fff; border-radius: 8px; margin-bottom: 0.5rem; transition: box-shadow 0.15s; }"
    " .contact-card:hover \{ box-shadow: 0 2px 8px rgba(0,0,0,0.08); }"
    " .card-main \{ display: flex; gap: 0.75rem; padding: 0.75rem; flex: 1; cursor: pointer; min-width: 0; }"
    " .card-delete \{ background: none; border: none; color: #ccc; cursor: pointer; padding: 0.75rem; display: flex; align-items: center; border-radius: 0 8px 8px 0; }"
    " .card-delete:hover \{ color: #c00; }"
    " .card-left \{ flex-shrink: 0; }"
    " .avatar \{ width: 40px; height: 40px; border-radius: 50%; object-fit: cover; }"
    " .avatar-placeholder \{ width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-weight: 600; font-size: 0.85rem; text-transform: uppercase; }"
    " .card-info \{ display: flex; flex-direction: column; gap: 0.1rem; min-width: 0; }"
    " .name \{ font-weight: 600; font-size: 0.9rem; }"
    " .ship-sub \{ font-size: 0.7rem; color: #999; font-family: monospace; display: flex; align-items: center; gap: 0.4rem; }"
    " .ames-tag \{ font-size: 0.6rem; padding: 0 4px; border-radius: 3px; font-family: sans-serif; }"
    " .ames-tag.known \{ background: #e8f5e9; color: #2e7d32; }"
    " .ames-tag.alien \{ background: #fff3e0; color: #e65100; }"
    " .card-tags \{ display: flex; gap: 0.3rem; flex-wrap: wrap; }"
    " .card-tag \{ font-size: 0.65rem; padding: 1px 6px; border-radius: 3px; background: #eee; color: #555; }"
    " .tags-container \{ display: flex; gap: 0.3rem; flex-wrap: wrap; margin-bottom: 0.3rem; }"
    " .tag-chip \{ display: inline-flex; align-items: center; gap: 2px; font-size: 0.8rem; padding: 2px 8px; border-radius: 4px; background: #e3e3e3; color: #333; }"
    " .tag-chip button \{ background: none; border: none; cursor: pointer; color: #999; font-size: 1rem; padding: 0 2px; line-height: 1; }"
    " .tag-chip button:hover \{ color: #c00; }"
    " .tags-input-wrap \{ margin-top: 0.2rem; }"
    " .status \{ font-size: 0.8rem; color: #666; }"
    " .muted \{ color: #999; }"
    " .hidden, .modal.hidden, .panel.hidden \{ display: none; }"
    " .modal \{ position: fixed; inset: 0; background: rgba(0,0,0,0.3); display: flex; align-items: center; justify-content: center; z-index: 10; }"
    " .modal-content \{ background: #fff; border-radius: 12px; padding: 1.5rem; width: 90%; max-width: 480px; }"
    " .modal-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; }"
    " .modal-header h2 \{ font-size: 1.1rem; }"
    " .modal-tabs \{ display: flex; gap: 0; margin-bottom: 1rem; border-bottom: 2px solid #eee; }"
    " .tab \{ padding: 0.4rem 0.75rem; border: none; background: none; cursor: pointer; font-size: 0.85rem; color: #999; border-bottom: 2px solid transparent; margin-bottom: -2px; }"
    " .tab:hover \{ color: #222; }"
    " .tab.active \{ color: #222; font-weight: 600; border-bottom-color: #222; }"
    " .modal-body \{ display: flex; flex-direction: column; gap: 0.75rem; }"
    " .field-row \{ display: flex; flex-direction: column; gap: 0.25rem; }"
    " .field-row label \{ font-size: 0.8rem; font-weight: 500; color: #666; }"
    " .field-input \{ padding: 0.5rem; border: 1px solid #ddd; border-radius: 6px; font-size: 0.9rem; }"
    " .field-input:focus \{ outline: none; border-color: #888; }"
    " textarea.field-input \{ resize: vertical; font-family: inherit; }"
    " .modal-footer \{ display: flex; justify-content: space-between; margin-top: 1rem; }"
    " .profile-fields \{ display: flex; flex-direction: column; gap: 0.5rem; }"
    " .profile-row \{ display: flex; flex-direction: column; gap: 0.1rem; }"
    " .profile-label \{ font-size: 0.7rem; color: #999; text-transform: uppercase; letter-spacing: 0.05em; }"
    " .profile-value \{ font-size: 0.9rem; }"
    " .profile-empty \{ color: #ddd; font-style: italic; font-size: 0.85rem; }"
  ==
::
++  js
  ^-  tape
  ;:  weld
    "var BASE = window.location.pathname.replace(/\\/$/, '');"
    "var API = BASE + '/api';"
    ::
    "function switchTab(name) \{"
    "  document.querySelectorAll('.modal-tabs .tab').forEach(t => t.classList.remove('active'));"
    "  document.querySelectorAll('.panel').forEach(p => p.classList.add('hidden'));"
    "  document.getElementById('tab-' + name).classList.add('active');"
    "  document.getElementById('panel-' + name).classList.remove('hidden');"
    "}"
    ::
    "function openContact(ship) \{"
    "  document.getElementById('modal-ship').value = ship;"
    "  document.getElementById('modal-title').textContent = ship;"
    "  switchTab('contact');"
    "  var o = (CONTACTS[ship] || \{});"
    "  document.getElementById('field-nickname').value = o.nickname || '';"
    "  document.getElementById('field-notes').value = o.notes || '';"
    "  window._tags = (o.tags || []).slice();"
    "  renderTags();"
    "  var ar = document.getElementById('modal-ames-row');"
    "  var ae = document.getElementById('modal-ames');"
    "  if(o.ames) \{ ar.classList.remove('hidden'); ae.textContent = o.ames; ae.className = 'ames-tag ' + o.ames; }"
    "  else \{ ar.classList.add('hidden'); }"
    "  var p = (PROFILES[ship] || \{});"
    "  var el = document.getElementById('profile-fields');"
    "  var fields = ['nickname','bio','status','color','avatar'];"
    "  el.innerHTML = fields.map(k => \{"
    "    var v = p[k] || '';"
    "    var cls = v ? 'profile-value' : 'profile-empty';"
    "    var txt = v || '—';"
    "    return '<div class=\"profile-row\"><span class=\"profile-label\">' + k + '</span><span class=\"' + cls + '\">' + txt + '</span></div>';"
    "  }).join('');"
    "  document.getElementById('edit-modal').classList.remove('hidden');"
    "}"
    ::
    "function closeModal() \{"
    "  document.getElementById('edit-modal').classList.add('hidden');"
    "}"
    ::
    "function saveContact() \{"
    "  var ship = document.getElementById('modal-ship').value;"
    "  var fields = \{};"
    "  var n = document.getElementById('field-nickname').value.trim();"
    "  var t = document.getElementById('field-notes').value.trim();"
    "  if(n) fields.nickname = n;"
    "  if(t) fields.notes = t;"
    "  if(window._tags && window._tags.length) fields.tags = window._tags;"
    "  fetch(API + '/overlay/' + ship, \{"
    "    method: 'POST',"
    "    headers: \{'Content-Type': 'application/json'},"
    "    body: JSON.stringify(fields)"
    "  }).then(() => \{ closeModal(); location.reload(); });"
    "}"
    ::
    "function deleteContact(ship) \{"
    "  if(!ship) ship = document.getElementById('modal-ship').value;"
    "  if(!confirm('Delete ' + ship + '?')) return;"
    "  fetch(API + '/overlay/' + ship, \{ method: 'DELETE' })"
    "  .then(() => \{ closeModal(); location.reload(); });"
    "}"
    ::
    "function quickDelete(ship) \{"
    "  event.stopPropagation();"
    "  deleteContact(ship);"
    "}"
    ::
    "function addContact() \{"
    "  var ship = prompt('Ship name (e.g. ~zod):');"
    "  if(!ship) return;"
    "  ship = ship.trim();"
    "  if(ship[0] !== '~') ship = '~' + ship;"
    "  openContact(ship);"
    "}"
    ::
    "function renderTags() \{"
    "  var c = document.getElementById('tags-container');"
    "  c.innerHTML = (window._tags || []).map(function(t) \{"
    "    return '<span class=\"tag-chip\">' + t + '<button onclick=\"removeTag(\\'' + t + '\\')\">&times;</button></span>';"
    "  }).join('');"
    "}"
    "function removeTag(t) \{"
    "  window._tags = (window._tags || []).filter(function(x)\{ return x !== t; });"
    "  renderTags();"
    "}"
    "function tagKeydown(e) \{"
    "  if(e.key !== 'Enter') return;"
    "  e.preventDefault();"
    "  var v = e.target.value.trim().toLowerCase();"
    "  if(!v) return;"
    "  if((window._tags || []).indexOf(v) === -1) \{"
    "    window._tags = (window._tags || []).concat([v]);"
    "    renderTags();"
    "  }"
    "  e.target.value = '';"
    "}"
    ::
    "document.getElementById('edit-modal').addEventListener('click', function(e) \{"
    "  if(e.target === this) closeModal();"
    "});"
  ==
--
