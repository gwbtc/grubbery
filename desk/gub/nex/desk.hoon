::  desk nexus: sync code from a remote source with checkpoint safety
::
::  config.json holds source as JSON string:
::    "~nec/apps/counter"    (remote ship)
::    "/some/local/path"     (local namespace)
::
::  Layout:
::    config.json     source config + sync state
::    /code/          code nexus (synced from source)
::    /data/          working data for the installed nexus
::    /snapshots/     checkpoint metadata
::
::  Before each code update, firms /data and /code entries
::  to create permanent snapshots. Snapshot metadata is
::  written to /snapshots/ for browsing.
::
/&  man  ../man/desk/readme.md
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
        [%fall %& [/ %'config.json'] [[/ %json] (config-to-json *desk-config)]]
        [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
        [%fall %| /requests empty-dir:loader]
        [%fall %| /code empty-dir:loader]
        [%fall %| /data empty-dir:loader]
        [%fall %| /snapshots empty-dir:loader]
        [%over %& [/man %'readme.md'] [[/ %mime] man]]
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
      ::  config.json: watch remote source, sync code on updates
      ::
      [~ %'config.json']
    ;<  ~  bind:m  (rise-wait:io prod "%desk config: failed")
    |-
    ;<  config-json=json  bind:m  (get-state-as:io ,json)
    =/  config=desk-config  (json-to-config config-json)
    ?~  source.config
      ::  no source configured, wait for poke
      ~&  >  %desk-no-source
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  new-json=json  !<(json q.sage)
      ;<  ~  bind:m  (replace:io new-json)
      $
    ::  subscribe to remote source
    =/  source-road=road:tarball  (parse-source u.source.config)
    ~&  >  [%desk-subscribing u.source.config]
    ;<  init=wave:nexus  bind:m  (keep:io /src source-road ~)
    ~&  >  [%desk-subscribed u.source.config]
    ::  initial sync (no checkpoint on first sync)
    ;<  ~  bind:m  (sync-code source-road *wave:nexus init)
    =/  prev=wave:nexus  init
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /src)
    ?-  -.res
        %news
      ~&  >  %desk-update-received
      ::  checkpoint before applying update
      ;<  ~  bind:m  (do-checkpoint config)
      ;<  ~  bind:m  (sync-code source-road prev wave.res)
      =.  config  config(snap-count +(snap-count.config))
      $(prev wave.res)
        %poke
      ::  config change: replace state, drop sub, restart
      =/  new-json=json  !<(json q.sage.res)
      ~&  >  [%desk-config-change new-json]
      ;<  ~  bind:m  (replace:io new-json)
      ;<  ~  bind:m  (drop:io /src source-road)
      ^$
    ==
      ::  main.sig: HTTP endpoint for desk management UI
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%desk /main: failed")
    ;<  ~  bind:m  (bind-http:io [~ /grubbery/desk])
    (http-dispatch:io %desk)
      ::  /requests/*: individual HTTP request handlers
      ::
      [[%requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%desk /requests: failed")
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
    ;<  our=@p  bind:m  get-our:io
    ?.  =(src our)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
      (pure:m ~)
    =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
    =/  suffix=path  (slag 2 site)  :: strip /grubbery/desk
    ?:  =('POST' method.request.req)
      (handle-post eyre-id suffix req)
    (handle-get eyre-id suffix)
  ==
--
::
|%
+$  desk-config
  $:  source=(unit @t)
      version=@ud
      snap-count=@ud
  ==
::
+$  news-or-poke
  $%  [%news =wave:nexus]
      [%poke =sage:tarball]
  ==
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  config-to-json
  |=  config=desk-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['source' ?~(source.config ~ s+u.source.config)]
      ['version' (numb:enjs:format version.config)]
      ['snapCount' (numb:enjs:format snap-count.config)]
  ==
::
++  json-to-config
  |=  =json
  ^-  desk-config
  ?.  ?=(%o -.json)  *desk-config
  =/  src  (~(get by p.json) 'source')
  =/  ver  (~(get by p.json) 'version')
  =/  snc  (~(get by p.json) 'snapCount')
  :*  ?~(src ~ ?:(?=([~ %s *] src) `p.u.src ~))
      ?~(ver 0 ?:(?=([~ %n *] ver) (rash p.u.ver dem) 0))
      ?~(snc 0 ?:(?=([~ %n *] snc) (rash p.u.snc dem) 0))
  ==
::
++  parse-source
  |=  src=@t
  ^-  road:tarball
  ?:  =('~' (end 3 src))
    =/  txt=tape  (trip src)
    =/  ship-end=@  (need (find "/" txt))
    =/  target=@p  (slav %p (crip (scag ship-end txt)))
    =/  source-path=path  (stab (crip (slag ship-end txt)))
    [%& %| (weld /sys/ames/ships/[(scot %p target)]/root source-path)]
  [%& %| (stab src)]
::
::  do-checkpoint: firm all files under /data and /code,
::  then write snapshot metadata
::
++  do-checkpoint
  |=  config=desk-config
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  snap-id=@ud  +(snap-count.config)
  ~&  >  [%desk-checkpoint snap-id]
  ::  firm all files under /data/
  ;<  ~  bind:m  (firm-tree [%| 0 %| /data])
  ::  firm all files under /code/
  ;<  ~  bind:m  (firm-tree [%| 0 %| /code])
  ::  write snapshot metadata
  =/  snap-json=json
    %-  pairs:enjs:format
    :~  ['id' (numb:enjs:format snap-id)]
        ['version' (numb:enjs:format version.config)]
    ==
  =/  snap-name=@ta  (crip "snap-{(a-co:co snap-id)}.json")
  ;<  ~  bind:m
    (make:io [%| 0 %& /snapshots snap-name] |+[[[/ %json] snap-json] ~])
  (pure:m ~)
::
::  firm-tree: checkpoint all files under a directory road
::
++  firm-tree
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m ~)
  =/  rails=(list rail:tarball)  (ball-to-rails ball.p.seen road)
  |-
  ?~  rails  (pure:m ~)
  ;<  ~  bind:m  (checkpoint:io i.rails)
  $(rails t.rails)
::
::  ball-to-rails: extract file rails from a ball relative to base
::
++  ball-to-rails
  |=  [=ball:tarball base=road:tarball]
  ^-  (list rail:tarball)
  =/  base-path=path
    ?:  ?=([%& %| *] base)  p.p.base
    ?:  ?=([%| * %| *] base)  p.q.p.base
    /
  =|  out=(list rail:tarball)
  =/  =lump:tarball  (fall fil.ball *lump:tarball)
  =.  out
    %-  welp  :_  out
    %+  turn  ~(tap in ~(key by contents.lump))
    |=(nm=@ta [base-path nm])
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
  |-  ^-  (list rail:tarball)
  ?~  kids  out
  =/  [dname=@ta kid=ball:tarball]  i.kids
  =.  out
    (welp out (ball-to-rails kid [%& %| (weld base-path /[dname])]))
  $(kids t.kids)
::
::  sync-code: apply changes from source to local /code/
::
++  sync-code
  |=  [source-road=road:tarball prev=wave:nexus cur=wave:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  changes=(map lane:tarball cass:clay)  (diff-wave:nexus prev cur)
  =/  lanes=(list [=lane:tarball =cass:clay])  ~(tap by changes)
  ~&  >  [%desk-sync-changes (lent lanes)]
  |-
  ?~  lanes  (pure:m ~)
  =/  =lane:tarball  lane.i.lanes
  ?:  ?=(%| -.lane)
    $(lanes t.lanes)
  =/  base=path
    ?:  ?=([%& %| *] source-road)  p.p.source-road
    ?:  ?=([%| * %| *] source-road)  p.q.p.source-road
    ~|(%desk-unexpected-road-shape !!)
  =/  src-road=road:tarball  [%& %& (weld base path.p.lane) name.p.lane]
  =/  dest-road=road:tarball  [%| 0 %& (weld /code path.p.lane) name.p.lane]
  ;<  =seen:nexus  bind:m  (peek:io src-road ~)
  ?.  ?=([%& %file *] seen)
    ~&  >>  [%desk-file-not-found lane]
    ;<  *  bind:m  (cull-soft:io dest-road)
    $(lanes t.lanes)
  ;<  ~  bind:m  (over:io dest-road [p.sang.p.seen (sang-noun:tarball sang.p.seen)])
  $(lanes t.lanes)
::
++  take-news-or-poke
  |=  news-wire=wire
  =/  m  (fiber:fiber:nexus ,news-or-poke)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %news * *]
    ?.  =(news-wire wire.u.in)
      [%skip ~]
    [%done %news wave.u.in]
      [~ %poke * *]
    [%done %poke sage.u.in]
  ==
::
::  HTTP handlers
::
++  handle-get
  |=  [eyre-id=@ta suffix=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  read config
  ;<  config-seen=seen:nexus  bind:m
    (peek:io [%| 0 %& / %'config.json'] `[/ %json])
  =/  config=desk-config
    ?.  ?=([%& %file *] config-seen)  *desk-config
    (json-to-config !<(json (need-vase:tarball sang.p.config-seen)))
  ::  read snapshots
  ;<  snap-seen=seen:nexus  bind:m
    (peek:io [%| 0 %| /snapshots] ~)
  =/  snaps=(list [@ta json])  (read-snapshots snap-seen)
  ::  render page
  =/  page=manx  (render-page config snaps)
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
      [%set-source ~]
    ::  poke config.json — the config fiber picks this up
    =/  new-config=desk-config  [?:(=('' body) ~ `body) 0 0]
    ;<  ~  bind:m
      (poke:io [%| 0 %& / %'config.json'] [[/ %json] (config-to-json new-config)])
    (redirect eyre-id)
  ::
      [%checkpoint ~]
    ::  read config, then checkpoint
    ;<  config-seen=seen:nexus  bind:m
      (peek:io [%| 0 %& / %'config.json'] `[/ %json])
    =/  config=desk-config
      ?.  ?=([%& %file *] config-seen)  *desk-config
      (json-to-config !<(json (need-vase:tarball sang.p.config-seen)))
    ;<  ~  bind:m  (do-checkpoint config)
    ~&  >  %desk-manual-checkpoint
    (redirect eyre-id)
  ==
::
++  redirect
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  hed=response-header:http  [303 ~[['location' './']]]
  ;<  ~  bind:m  (send-header:srv eyre-id hed)
  ;<  ~  bind:m  (send-data:srv eyre-id ~)
  (pure:m ~)
::
++  read-snapshots
  |=  =seen:nexus
  ^-  (list [@ta json])
  ?.  ?=([%& %ball *] seen)  ~
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
  =/  names=(list @ta)
    (sort ~(tap in ~(key by contents.lump)) dor)
  %+  murn  names
  |=  nm=@ta
  ^-  (unit [@ta json])
  =/  got=(unit [=sang:tarball gain=? bang=(unit tang)])
    (~(get by contents.lump) nm)
  ?~  got  ~
  =/  res  (mule |.(!<(json (need-vase:tarball sang.u.got))))
  ?:(?=(%| -.res) ~ `[nm p.res])
::
::  HTML rendering
::
++  render-page
  |=  [config=desk-config snaps=(list [@ta json])]
  ^-  manx
  ;html
    ;head
      ;title: Desk
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  page-css
      ==
    ==
    ;body
      ;h1: Desk
      ;+  (render-config config)
      ;+  (render-snapshots snaps)
      ;script
        ;+  ;/  page-js
      ==
    ==
  ==
::
++  render-config
  |=  config=desk-config
  ^-  manx
  ;div(class "section")
    ;h2: Source
    ;div(class "config-form")
      ;input#source-input(type "text", placeholder "~ship/path or /local/path", value "{?~(source.config "" (trip u.source.config))}");
      ;button(class "btn btn-grn", onclick "setSource()"): Set Source
    ==
    ;div(class "status")
      ;span(class "label"): Status:
      ;span: {?~(source.config "not configured" "subscribed")}
    ==
    ;div(class "status")
      ;span(class "label"): Version:
      ;span: {(a-co:co version.config)}
    ==
    ;div(class "status")
      ;span(class "label"): Snapshots:
      ;span: {(a-co:co snap-count.config)}
    ==
  ==
::
++  render-snapshots
  |=  snaps=(list [@ta json])
  ^-  manx
  ;div(class "section")
    ;h2: Snapshots
    ;button(class "btn", onclick "manualCheckpoint()"): + Checkpoint Now
    ;div(class "snap-list")
      ;*  ?~  snaps
            =/  empty=manx  ;span(class "muted"): No snapshots yet
            ~[empty]
          (turn snaps render-snap)
    ==
  ==
::
++  render-snap
  |=  [nm=@ta =json]
  ^-  manx
  =/  snap-id=tape
    ?.  ?=(%o -.json)  "?"
    =/  id  (~(get by p.json) 'id')
    ?~(id "?" ?:(?=([~ %n *] id) (trip p.u.id) "?"))
  =/  snap-ver=tape
    ?.  ?=(%o -.json)  "?"
    =/  vr  (~(get by p.json) 'version')
    ?~(vr "?" ?:(?=([~ %n *] vr) (trip p.u.vr) "?"))
  ;div(class "snap")
    ;span(class "snap-id"): #{snap-id}
    ;span(class "snap-ver"): v{snap-ver}
  ==
::
++  page-css
  ^-  tape
  ;:  weld
    "* \{ margin:0; padding:0; box-sizing:border-box; }"
    "body \{ font-family:monospace; max-width:600px; margin:0 auto; padding:1.5rem; background:#fafafa; color:#111; font-size:14px; }"
    "h1 \{ font-size:1.3rem; margin-bottom:1rem; }"
    "h2 \{ font-size:1rem; margin-bottom:.5rem; }"
    ".section \{ background:#fff; border:1px solid #ddd; border-radius:6px; padding:.75rem; margin-bottom:.75rem; }"
    ".config-form \{ display:flex; gap:.5rem; margin-bottom:.5rem; }"
    ".config-form input \{ font-family:monospace; font-size:16px; padding:.3rem .5rem; border:1px solid #ccc; border-radius:4px; flex:1; min-width:0; }"
    ".status \{ font-size:.85rem; margin-bottom:.25rem; }"
    ".status .label \{ font-weight:bold; margin-right:.5rem; }"
    ".btn \{ font-family:monospace; font-size:.8rem; padding:.3rem .75rem; border:1px solid #ccc; border-radius:4px; background:#fff; cursor:pointer; }"
    ".btn:hover \{ background:#eee; }"
    ".btn-grn \{ color:#2a2; border-color:#2a2; }"
    ".btn-grn:hover \{ background:#dfd; }"
    ".snap-list \{ margin-top:.5rem; }"
    ".snap \{ display:flex; gap:.75rem; padding:.3rem 0; border-bottom:1px solid #eee; font-size:.85rem; }"
    ".snap-id \{ font-weight:bold; }"
    ".snap-ver \{ color:#888; }"
    ".muted \{ color:#999; font-size:.85rem; }"
  ==
::
++  page-js
  ^-  tape
  ;:  weld
    "var BASE=window.location.pathname;"
    "if(!BASE.endsWith('/'))BASE+='/';"
    "var API=BASE.replace('/ball/','/api/over/');"
    "function setSource()\{"
    "  var src=document.getElementById('source-input').value.trim();"
    "  fetch(API+'requests/set-source',\{method:'POST',body:src}).then(function()\{location.reload()});"
    "}"
    "function manualCheckpoint()\{"
    "  fetch(API+'requests/checkpoint',\{method:'POST'}).then(function()\{location.reload()});"
    "}"
  ==
--
