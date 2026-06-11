::  peers nexus: usergroup + ship management
::
::  Binds /grubbery/peers/ via fiberio.
::  Server-renders HTML from /sys/ames/ data.
::  POST handlers for create/delete/edit operations.
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
            [%fall %| /requests empty-dir:loader]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%peers /main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/peers])
        (http-dispatch:io %peers)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%peers /requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path  (slag 2 site)  :: strip /grubbery/peers
        ?:  =('POST' method.request.req)
          (handle-post eyre-id suffix req)
        (handle-get eyre-id suffix)
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Directory under peers.'
            ~
          'Peer management UI. Usergroups and ship permissions at /grubbery/peers/.'
            [%requests ~]
          'Per-request HTTP fibers.'
        ==
          %|
        ?+  rail.p.mana  'File under peers.'
          [~ %'main.sig']  'HTTP binding process for /grubbery/peers/.'
        ==
      ==
    --
::
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
++  peer-base  /sys/ames
::
++  abs-file
  |=  [=path name=@ta]
  ^-  road:tarball
  [%& %& [(weld peer-base path) name]]
::
++  abs-dir
  |=  =path
  ^-  road:tarball
  [%& %| (weld peer-base path)]
::
::  HTTP handlers
::
++  handle-get
  |=  [eyre-id=@ta suffix=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  read all peer data
  ;<  ug-seen=seen:nexus  bind:m  (peek:io (abs-dir /usergroups) ~)
  ;<  ships-seen=seen:nexus  bind:m  (peek:io (abs-dir /ships) ~)
  =/  ug-ball=ball:tarball
    ?.  ?=([%& %ball *] ug-seen)  [~ ~]
    ball.p.ug-seen
  =/  groups=(list group-info)  (read-groups ug-ball)
  =/  ships=(list @ta)
    ?.  ?=([%& %ball *] ships-seen)  ~
    (sort ~(tap in ~(key by dir.ball.p.ships-seen)) aor)
  =/  page=manx  (render-page groups ships suffix)
  =/  bod=octs  (as-octs:mimes:html (crip (en-xml:html page)))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
  (pure:m ~)
::
++  handle-post
  |=  [eyre-id=@ta suffix=path req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  body=@t
    ?~  body.request.req  ''
    q.u.body.request.req
  ?+    suffix
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  ::
      [%create ~]
    =/  name=@t  body
    ?:  =('' name)
      (redirect eyre-id)
    =/  nam=@ta  (crip (trip name))
    =/  who-road=road:tarball  (abs-file /usergroups/[nam] %'who.ships')
    =/  how-road=road:tarball  (abs-file /usergroups/[nam] %'how.weir')
    ;<  *  bind:m  (make-soft:io who-road |+[[[/ %ships] !>(*(set @p))] ~])
    ;<  *  bind:m  (make-soft:io how-road |+[[[/ %weir] !>(*weir:nexus)] ~])
    (redirect eyre-id)
  ::
      [%delete ~]
    =/  nam=@ta  (crip (trip body))
    ;<  *  bind:m  (cull-soft:io (abs-dir /usergroups/[nam]))
    (redirect eyre-id)
  ::
      [%members ~]
    ::  body = "name\0amember1\0amember2..."
    =/  lines=(list @t)  (split-lines body)
    ?~  lines  (redirect eyre-id)
    =/  nam=@ta  (crip (trip i.lines))
    =/  ships=(set @p)
      %-  ~(gas in *(set @p))
      (murn t.lines |=(t=@t (slaw %p t)))
    ;<  ~  bind:m  (over:io (abs-file /usergroups/[nam] %'who.ships') [[/ %ships] ships])
    (redirect eyre-id)
  ::
      [%permissions ~]
    ::  body = "name\0amake:path1,path2\0apoke:path1\0apeek:path1"
    =/  lines=(list @t)  (split-lines body)
    ?~  lines  (redirect eyre-id)
    =/  nam=@ta  (crip (trip i.lines))
    =/  =weir:nexus  (parse-weir-lines t.lines)
    ;<  ~  bind:m  (over:io (abs-file /usergroups/[nam] %'how.weir') [[/ %weir] weir])
    (redirect eyre-id)
  ==
::
++  redirect
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  hed=response-header:http  [303 ~[['location' '/grubbery/peers/']]]
  ;<  ~  bind:m  (send-header:srv eyre-id hed)
  ;<  ~  bind:m  (send-data:srv eyre-id ~)
  (pure:m ~)
::
::  Data reading
::
+$  group-info
  $:  name=@ta
      members=(set @p)
      =weir:nexus
  ==
::
++  read-groups
  |=  ug-ball=ball:tarball
  ^-  (list group-info)
  =/  names=(list @ta)
    (sort ~(tap in ~(key by dir.ug-ball)) aor)
  %+  murn  names
  |=  name=@ta
  ^-  (unit group-info)
  =/  grp=ball:tarball  (~(dip ba:tarball ug-ball) /[name])
  =/  who-c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'who.ships'])
  =/  how-c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'how.weir'])
  ?~  who-c  ~
  =/  who-res  (mule |.(!<((set @p) (need-vase:tarball u.who-c))))
  =/  members=(set @p)  ?:(?=(%| -.who-res) ~ p.who-res)
  =/  =weir:nexus
    ?~  how-c  *weir:nexus
    =/  res  (mule |.(!<(weir:nexus (need-vase:tarball u.how-c))))
    ?:(?=(%| -.res) *weir:nexus p.res)
  `[name members weir]
::
::  Parsing helpers
::
++  split-lines
  |=  t=@t
  ^-  (list @t)
  =/  tape=(list @)  (trip t)
  =|  acc=(list @t)
  =|  cur=(list @)
  |-
  ?~  tape  (flop [(crip (flop cur)) acc])
  ?:  =(i.tape 10)
    $(tape t.tape, acc [(crip (flop cur)) acc], cur ~)
  $(tape t.tape, cur [i.tape cur])
::
++  parse-road-text
  |=  t=@t
  ^-  road:tarball
  =/  pax=path  (fall (rush t stap) /)
  ?~  pax  [%& %| /]
  =/  last=tape  (trip (rear pax))
  ?~  (find "." last)
    [%& %| pax]
  [%& %& (snip `path`pax) (rear pax)]
::
++  road-to-text
  |=  =road:tarball
  ^-  tape
  ?-  -.road
      %&
    ?-  -.p.road
      %&  "{(spud path.p.p.road)}/{(trip name.p.p.road)}"
      %|  (spud p.p.road)
    ==
      %|
    ?-  -.q.p.road
      %&  "{(spud path.p.q.p.road)}/{(trip name.p.q.p.road)}"
      %|  (spud p.q.p.road)
    ==
  ==
::
++  parse-weir-lines
  |=  lines=(list @t)
  ^-  weir:nexus
  =|  mk=(set road:tarball)
  =|  pk=(set road:tarball)
  =|  pe=(set road:tarball)
  |-
  ?~  lines  [mk pk pe]
  =/  line=tape  (trip i.lines)
  ?:  =("make:" (scag 5 line))
    =/  roads=(list road:tarball)
      (turn (split-commas (crip (slag 5 line))) parse-road-text)
    $(lines t.lines, mk (~(uni in mk) (silt roads)))
  ?:  =("poke:" (scag 5 line))
    =/  roads=(list road:tarball)
      (turn (split-commas (crip (slag 5 line))) parse-road-text)
    $(lines t.lines, pk (~(uni in pk) (silt roads)))
  ?:  =("peek:" (scag 5 line))
    =/  roads=(list road:tarball)
      (turn (split-commas (crip (slag 5 line))) parse-road-text)
    $(lines t.lines, pe (~(uni in pe) (silt roads)))
  $(lines t.lines)
::
++  split-commas
  |=  t=@t
  ^-  (list @t)
  =/  tape=(list @)  (trip t)
  =|  acc=(list @t)
  =|  cur=(list @)
  |-
  ?~  tape
    =/  s=@t  (crip (flop cur))
    ?:(=('' s) (flop acc) (flop [s acc]))
  ?:  =(i.tape ',')
    $(tape t.tape, acc [(crip (flop cur)) acc], cur ~)
  $(tape t.tape, cur [i.tape cur])
::
::  HTML rendering
::
++  render-page
  |=  [groups=(list group-info) ships=(list @ta) suffix=path]
  ^-  manx
  ;html
    ;head
      ;title: Peers
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  %-  trip  %-  crip
          ;:  weld
            "* \{ margin:0; padding:0; box-sizing:border-box; }"
            "body \{ font-family:monospace; max-width:720px; margin:0 auto; padding:1.5rem; background:#fafafa; color:#111; font-size:14px; }"
            "h1 \{ font-size:1.3rem; margin-bottom:1.25rem; }"
            ".group \{ background:#fff; border:1px solid #ddd; border-radius:6px; padding:.75rem; margin-bottom:.75rem; }"
            ".group-hdr \{ display:flex; align-items:center; gap:.5rem; margin-bottom:.5rem; flex-wrap:wrap; }"
            ".group-hdr strong \{ font-size:.9rem; word-break:break-all; }"
            ".group-hdr .count \{ color:#888; font-size:.75rem; }"
            ".ship \{ background:#eef; border:1px solid #ccd; border-radius:3px; padding:2px 6px; font-size:.75rem; word-break:break-all; }"
            ".perms \{ font-size:.75rem; color:#666; }"
            "label \{ display:block; font-size:.7rem; color:#888; text-transform:uppercase; margin-top:.5rem; margin-bottom:.2rem; }"
            "textarea \{ width:100%; font-family:monospace; font-size:16px; padding:.4rem; border:1px solid #ccc; border-radius:4px; resize:vertical; min-height:2.5rem; }"
            "input[type=text] \{ font-size:16px; }"
            "button \{ font-family:monospace; font-size:.8rem; padding:.3rem .75rem; border:1px solid #ccc; border-radius:4px; background:#fff; cursor:pointer; -webkit-tap-highlight-color:transparent; }"
            "button:hover \{ background:#eee; }"
            ".btn-red \{ color:#c44; border-color:#c44; }"
            ".btn-red:hover \{ background:#fdd; }"
            ".btn-grn \{ color:#2a2; border-color:#2a2; }"
            ".btn-grn:hover \{ background:#dfd; }"
            ".actions \{ display:flex; gap:.5rem; margin-top:.5rem; flex-wrap:wrap; }"
            ".create-form \{ display:flex; gap:.5rem; margin-bottom:1.25rem; flex-wrap:wrap; }"
            ".create-form input \{ font-family:monospace; font-size:16px; padding:.3rem .5rem; border:1px solid #ccc; border-radius:4px; flex:1; min-width:0; }"
            ".tabs \{ display:flex; gap:0; border-bottom:2px solid #ddd; margin-bottom:1rem; }"
            ".tab \{ font-family:monospace; font-size:.85rem; padding:.5rem 1rem; border:none; background:none; cursor:pointer; color:#888; border-bottom:2px solid transparent; margin-bottom:-2px; -webkit-tap-highlight-color:transparent; }"
            ".tab.active \{ color:#111; border-bottom-color:#111; }"
            ".tab-content \{ display:none; }"
            ".tab-content.active \{ display:block; }"
            ".ship-list \{ display:flex; flex-wrap:wrap; gap:4px; }"
            ".empty \{ color:#999; font-size:.85rem; }"
            "@media(max-width:480px)\{"
            "  body \{ padding:.75rem; }"
            "  h1 \{ font-size:1.1rem; margin-bottom:1rem; }"
            "  .group \{ padding:.6rem; }"
            "  .tab \{ padding:.4rem .6rem; font-size:.8rem; }"
            "}"
          ==
      ==
    ==
    ;body
      ;h1: Peers
      ;div(class "tabs")
        ;button(class "tab active", onclick "switchTab('groups')"): Usergroups
        ;button(class "tab", onclick "switchTab('ships')"): Ships ({(a-co:co (lent ships))})
      ==
      ;div(id "tab-groups", class "tab-content active")
        ;div(class "create-form")
          ;input(id "new-name", type "text", placeholder "/group/name");
          ;button(class "btn-grn", onclick "createGroup()"): + New Group
        ==
        ;div
          ;*  (render-groups groups)
        ==
      ==
      ;div(id "tab-ships", class "tab-content")
        ;div(class "ship-list")
          ;*  (render-ships ships)
        ==
      ==
      ;script
        ;+  ;/  %-  trip  %-  crip
          ;:  weld
            "function switchTab(id)\{\0a"
            "  document.querySelectorAll('.tab-content').forEach(e=>e.classList.remove('active'));\0a"
            "  document.querySelectorAll('.tab').forEach(e=>e.classList.remove('active'));\0a"
            "  document.getElementById('tab-'+id).classList.add('active');\0a"
            "  event.target.classList.add('active');\0a"
            "}\0a"
            "var BASE='/grubbery/peers/';\0a"
            "function createGroup()\{\0a"
            "  var n=document.getElementById('new-name').value.trim();\0a"
            "  if(!n) return;\0a"
            "  fetch(BASE+'create',\{method:'POST',body:n}).then(()=>location.reload());\0a"
            "}\0a"
            "function deleteGroup(name)\{\0a"
            "  if(!confirm('Delete group '+name+'?')) return;\0a"
            "  fetch(BASE+'delete',\{method:'POST',body:name}).then(()=>location.reload());\0a"
            "}\0a"
            "function saveMembers(name)\{\0a"
            "  var ta=document.getElementById('mem-'+name);\0a"
            "  var lines=ta.value.split('\\n').map(s=>s.trim()).filter(s=>s);\0a"
            "  fetch(BASE+'members',\{method:'POST',body:name+'\\n'+lines.join('\\n')}).then(()=>location.reload());\0a"
            "}\0a"
            "function savePerms(name)\{\0a"
            "  var mk=document.getElementById('make-'+name).value.trim();\0a"
            "  var pk=document.getElementById('poke-'+name).value.trim();\0a"
            "  var pe=document.getElementById('peek-'+name).value.trim();\0a"
            "  var body=name;\0a"
            "  if(mk) body+='\\nmake:'+mk;\0a"
            "  if(pk) body+='\\npoke:'+pk;\0a"
            "  if(pe) body+='\\npeek:'+pe;\0a"
            "  fetch(BASE+'permissions',\{method:'POST',body:body}).then(()=>location.reload());\0a"
            "}\0a"
          ==
      ==
    ==
  ==
::
++  render-groups
  |=  groups=(list group-info)
  ^-  marl
  ?~  groups
    =/  m=manx  ;span(class "empty"): No usergroups
    ~[m]
  (turn groups render-group)
::
++  render-ships
  |=  ships=(list @ta)
  ^-  marl
  ?~  ships
    =/  m=manx  ;span(class "empty"): No ships
    ~[m]
  %+  turn  ships
  |=  s=@ta
  ^-  manx
  ;span(class "ship"): {(trip s)}
::
++  render-group
  |=  =group-info
  ^-  manx
  =/  n=tape  (trip name.group-info)
  =/  is-public=?  =(%public name.group-info)
  =/  mem-list=(list @p)  (sort ~(tap in members.group-info) aor)
  =/  mem-text=tape
    %+  join  "\0a"
    (turn mem-list |=(s=@p (trip (scot %p s))))
  =/  make-text=tape
    %+  join  ","
    (turn ~(tap in make.weir.group-info) road-to-text)
  =/  poke-text=tape
    %+  join  ","
    (turn ~(tap in poke.weir.group-info) road-to-text)
  =/  peek-text=tape
    %+  join  ","
    (turn ~(tap in peek.weir.group-info) road-to-text)
  ;div(class "group")
    ;div(class "group-hdr")
      ;strong: {n}
      ;span(class "count"): {?:(is-public "all ships" "{(a-co:co (lent mem-list))} members")}
      ;+  ?.  is-public
            ;button(class "btn-red", onclick "deleteGroup('{n}')"):  x
          ;span;
    ==
    ;+  ?.  is-public
          ;div
            ;label: Members (one ~ship per line)
            ;textarea(id "mem-{n}", rows "3"): {mem-text}
            ;div(class "actions")
              ;button(class "btn-grn", onclick "saveMembers('{n}')"): Save Members
            ==
          ==
        ;span(class "perms"): Applies to all foreign ships
    ;label: Permissions (comma-separated paths)
    ;label: Make
    ;input(id "make-{n}", type "text", value "{make-text}", style "width:100%;font-family:monospace;font-size:16px;padding:.3rem .5rem;border:1px solid #ccc;border-radius:4px;");
    ;label: Poke
    ;input(id "poke-{n}", type "text", value "{poke-text}", style "width:100%;font-family:monospace;font-size:16px;padding:.3rem .5rem;border:1px solid #ccc;border-radius:4px;");
    ;label: Peek
    ;input(id "peek-{n}", type "text", value "{peek-text}", style "width:100%;font-family:monospace;font-size:16px;padding:.3rem .5rem;border:1px solid #ccc;border-radius:4px;");
    ;div(class "actions")
      ;button(class "btn-grn", onclick "savePerms('{n}')"): Save Permissions
    ==
  ==
::
++  join
  |=  [del=tape ts=(list tape)]
  ^-  tape
  ?~  ts  ~
  ?~  t.ts  i.ts
  :(weld i.ts del $(ts t.ts))
--
