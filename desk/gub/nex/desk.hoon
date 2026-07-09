::  desk nexus: sync code from a remote source with checkpoint safety
::
::  config.json holds source as JSON string:
::    "~nec/apps/counter"    (remote ship)
::    "/some/local/path"     (local namespace)
::
::  Layout:
::    config.json     source config
::    version.ud      release version (source bumps, sink subscribes)
::    /code/          code nexus (synced from source)
::    /data/          working data for the installed nexus
::
::  Before each code update, firms /data and /code entries
::  and tags them as checkpoints.
::
::  Future: this could extend to a repo nexus. The content store
::  gives you dedup (silo lobes) and history (hist). But real
::  commits need a merkle DAG — each commit hashes over parent +
::  tree, not just firm entries. Would need a commit object type
::  (parent hash, tree hash, message, author @p, signature)
::  layered on top of the born tree, not replacing it.
::
/&  man  ../man/desk/readme.md
=<  ^-  nexus:nexus
    |%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'config.json'] [[/ %json] (config-to-json *desk-config)]]
      [%fall %& [/ %'version.ud'] [[/ %ud] 0]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /code empty-dir:loader]
      [%fall %| /data empty-dir:loader]
      [%over %& [/ %'README.md'] [[/ %mime] man]]
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
    ::  subscribe to source's version.ud
    =/  source-road=road:tarball  (parse-source u.source.config)
    =/  ver-road=road:tarball  (version-road source-road)
    =/  code-road=road:tarball  (code-road source-road)
    ~&  >  [%desk-subscribing u.source.config]
    ;<  init=wave:nexus  bind:m  (keep:io /ver ver-road `[/ %ud])
    ~&  >  [%desk-subscribed u.source.config]
    ::  initial sync: peek source /code/ and copy
    ;<  ~  bind:m  (sync-from-source code-road)
    |-
    ;<  res=news-or-poke  bind:m  (take-news-or-poke /ver)
    ?-  -.res
        %news
      ~&  >  %desk-update-received
      ::  checkpoint current state, then sync new code
      ;<  ~  bind:m  do-checkpoint
      ;<  ~  bind:m  (sync-from-source code-road)
      ::  update local version.ud to match source
      ;<  ver-seen=seen:nexus  bind:m  (peek:io ver-road `[/ %ud])
      ?:  ?=([%& %file *] ver-seen)
        =/  ver=@ud  !<(@ud (need-vase:tarball sang.p.ver-seen))
        ;<  ~  bind:m  (over:io [%| 0 %& / %'version.ud'] [[/ %ud] ver])
        $
      $
        %poke
      ::  config change: replace state, drop sub, restart
      =/  new-json=json  !<(json q.sage.res)
      ~&  >  [%desk-config-change new-json]
      ;<  ~  bind:m  (replace:io new-json)
      ;<  ~  bind:m  (drop:io /ver ver-road)
      ^$
    ==
      ::  main.sig: HTTP endpoint for desk management UI
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%desk /main: failed")
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    ;<  ~  bind:m  (bind-http:io [~ (weld /grubbery/desk path.here)])
    ::  Register with /public usergroup if configured
    ;<  config-json=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  config=desk-config  ?~(config-json *desk-config (json-to-config u.config-json))
    =/  nex-dir=path  path.here
    =/  reg-road=road:tarball  [%& %& /sys/ames %'public.usergroups_registry']
    =/  reg-blot=blot:tarball  [/usergroups %registry-action]
    =*  reg-poke  |=(act=* (poke:io reg-road [reg-blot act]))
    ;<  ~  bind:m  (reg-poke [%register here nex-dir])
    ;<  ~  bind:m
      %-  reg-poke
      ?:  public.config
        [%how [~ ~ (sy [%& %| nex-dir] ~)]]
      [%how *weir:nexus]
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
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  nex-path=path  (snip path.here)  :: /foo/requests -> /foo
    =/  prefix=path  (weld /grubbery/desk nex-path)
    =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
    =/  suffix=path  (slag (lent prefix) site)
    ?:  =('POST' method.request.req)
      (handle-post eyre-id suffix req)
    (handle-get eyre-id suffix)
  ==
--
::
|%
+$  desk-config
  $:  source=(unit @t)
      public=?
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
      ['public' b+public.config]
  ==
::
++  json-to-config
  |=  =json
  ^-  desk-config
  ?.  ?=(%o -.json)  *desk-config
  =/  src  (~(get by p.json) 'source')
  =/  pub  (~(get by p.json) 'public')
  :*  ?~(src ~ ?:(?=([~ %s *] src) `p.u.src ~))
      ?~(pub %.n ?:(?=([~ %b *] pub) p.u.pub %.n))
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
::  version-road: source's version.ud road from base source road
::
++  version-road
  |=  source-road=road:tarball
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %& p.p.source-road %'version.ud']
::  code-road: source's /code/ directory road from base source road
::
++  code-road
  |=  source-road=road:tarball
  ^-  road:tarball
  ?.  ?=([%& %| *] source-road)  ~|(%desk-unexpected-road-shape !!)
  [%& %| (weld p.p.source-road /code)]
::  sync-from-source: peek source /code/ tree and mirror locally
::
++  sync-from-source
  |=  source-code=road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io source-code ~)
  ?.  ?=([%& %ball *] seen)
    ~&  >>  %desk-no-code-at-source
    (pure:m ~)
  =/  rails=(list rail:tarball)  (ball-to-rails ball.p.seen source-code)
  ~&  >  [%desk-sync-files (lent rails)]
  =/  base=path
    ?.  ?=([%& %| *] source-code)  ~|(%desk-unexpected-code-road !!)
    p.p.source-code
  |-
  ?~  rails  (pure:m ~)
  =/  src-road=road:tarball  [%& %& path.i.rails name.i.rails]
  =/  rel-path=path  (slag (lent base) path.i.rails)
  =/  dest-road=road:tarball  [%| 0 %& (weld /code rel-path) name.i.rails]
  ;<  =seen:nexus  bind:m  (peek:io src-road ~)
  ?.  ?=([%& %file *] seen)
    $(rails t.rails)
  ;<  ~  bind:m  (over:io dest-road [p.sang.p.seen (sang-noun:tarball sang.p.seen)])
  $(rails t.rails)
::
::  do-checkpoint: firm and tag all files under /data and /code
::
++  do-checkpoint
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >  %desk-checkpoint
  ;<  ~  bind:m  (firm-and-tag-tree [%| 0 %| /data])
  (firm-and-tag-tree [%| 0 %| /code])
::
::  firm-and-tag-tree: firm and tag 'checkpoint' on all files under a road
::
++  firm-and-tag-tree
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
  ;<  ~  bind:m  (tag:io i.rails ~ (sy ~['checkpoint']))
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
  ::  read version
  ;<  ver-seen=seen:nexus  bind:m
    (peek:io [%| 0 %& / %'version.ud'] `[/ %ud])
  =/  version=@ud
    ?.  ?=([%& %file *] ver-seen)  0
    !<(@ud (need-vase:tarball sang.p.ver-seen))
  ::  render page
  =/  page=manx  (render-page config version)
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
    ;<  cur-json=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  cur=desk-config  ?~(cur-json *desk-config (json-to-config u.cur-json))
    =/  new-config=desk-config  cur(source ?:(=('' body) ~ `body))
    ;<  ~  bind:m
      (poke:io [%| 0 %& / %'config.json'] [[/ %json] (config-to-json new-config)])
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
::
::  HTML rendering
::
++  render-page
  |=  [config=desk-config version=@ud]
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
      ;+  (render-config config version)
      ;script
        ;+  ;/  page-js
      ==
    ==
  ==
::
++  render-config
  |=  [config=desk-config version=@ud]
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
      ;span: {(a-co:co version)}
    ==
  ==
::
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
  ==
--
