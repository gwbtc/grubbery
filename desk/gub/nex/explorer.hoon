::  explorer nexus: tarball tree browser
::
/<  feather  /lib/feather.hoon
/<  iso-8601  /lib/iso-8601.hoon
/&  man   ../man/explorer/readme.md
/&  icon  explorer/icon.svg
/&  gram     explorer/hoon-grammar.json
/&  view-js  explorer/view.js
/&  fp-js    /lib/ui/file-preview.js
/&  md-js    /lib/ui/modal-dialog.js
/&  dm2-js   /lib/ui/drop-menu.js
/&  ft-js    /lib/ui/file-table.js
/&  fg-js    /lib/ui/file-grid.js
/&  browse-html  explorer/ui/browse.html
/&  browse-js    explorer/ui/browse.js
/&  view-html    explorer/ui/view.html
/&  marked-js  shell/marked.min.js
/&  cm-js      /lib/cm/codemirror.min.js
/&  cm-css     /lib/cm/codemirror.min.css
/&  cm-vim     /lib/cm/vim.min.js
/&  cm-m-js    /lib/cm/javascript.min.js
/&  cm-m-css   /lib/cm/css.min.js
/&  cm-m-xml   /lib/cm/xml.min.js
/&  cm-m-md    /lib/cm/markdown.min.js
/&  cm-m-html  /lib/cm/htmlmixed.min.js
/&  cm-m-hoon  /lib/cm/hoon-mode.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Explorer'
            info+s+'Browse the tarball'
            color+s+'#4a9de5'
            image+s+'/grubbery/tiles/icon/explorer'
            href+s+'/grubbery/ball'
        ==
      ::  editor bundle: codemirror + vim keymap + modes welded into one
      ::  served file (same pattern as web-test's components.js)
      =/  cm-wrap  |=(=mime `@`(rap 3 ~[10 q.q.mime 10]))
      =/  cm-bundle=mime
        :-  /application/javascript
        %-  as-octs:mimes:html
        %+  rap  3
        :~  (cm-wrap cm-js)
            (cm-wrap cm-vim)
            (cm-wrap cm-m-js)
            (cm-wrap cm-m-css)
            (cm-wrap cm-m-xml)
            (cm-wrap cm-m-md)
            (cm-wrap cm-m-html)
            (cm-wrap cm-m-hoon)
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'explorer'] ['description' s+'Browse the namespace tree']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
          [%over %& [/ %'hoon-grammar.json'] [[/ %mime] gram]]
          [%over %& [/ %'view.js'] [[/ %mime] view-js]]
          [%over %& [/ %'file-preview.js'] [[/ %mime] fp-js]]
          [%over %& [/ %'modal-dialog.js'] [[/ %mime] md-js]]
          [%over %& [/ %'drop-menu.js'] [[/ %mime] dm2-js]]
          [%over %& [/ %'file-table.js'] [[/ %mime] ft-js]]
          [%over %& [/ %'file-grid.js'] [[/ %mime] fg-js]]
          [%over %& [/ %'browse.html'] [[/ %mime] browse-html]]
          [%over %& [/ %'browse.js'] [[/ %mime] browse-js]]
          [%over %& [/ %'view.html'] [[/ %mime] view-html]]
          [%over %& [/ %'marked.min.js'] [[/ %mime] marked-js]]
          [%over %& [/ %'cm.js'] [[/ %mime] cm-bundle]]
          [%over %& [/ %'cm.css'] [[/ %mime] cm-css]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%explorer /main: failed, poke to restart")
        ~&  >  "%explorer /main: binding /grubbery/ball"
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/ball])
        ~&  >  "%explorer /main: ready"
        (http-dispatch:io %explorer)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%explorer /requests: failed, poke to restart")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ~&  >  [%explorer-request eyre-id url.request.req]
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  raw-path=path
          ?.  ?=([%grubbery %ball *] site)  ~
          t.t.site

        ~&  >  %explorer-dispatch-start
        ;<  dir-view=view:nexus  bind:m  (peek-shallow:io [%& %| raw-path] ~)
        ~&  >  %explorer-peek-done
        ?.  ?=([%ball *] dir-view)
          ::  Not a directory — try parent for file view
          ?~  raw-path
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  parent=path  (snip `path`raw-path)
          ;<  par-view=view:nexus  bind:m  (peek-shallow:io [%& %| parent] ~)
          ?.  ?=([%ball *] par-view)
            ;<  ~  bind:m  (send-missing eyre-id raw-path args (wants-html req))
            (pure:m ~)
          ?:  =('POST' method.request.req)
            (handle-post eyre-id raw-path ~ ball.par-view req)
          (handle-get eyre-id raw-path %.n ~ ball.par-view wave.par-view args (wants-html req))
        ;<  dir-weir=(unit weir:nexus)  bind:m
          (read-weir-from-parent raw-path)
        ?:  =('POST' method.request.req)
          (handle-post eyre-id raw-path dir-weir ball.dir-view req)
        ~&  >  %explorer-handle-get-start
        (handle-get eyre-id raw-path %.y dir-weir ball.dir-view wave.dir-view args (wants-html req))
      ==
    --
::
|%
::  +kid-info: what the listing learns about a subdirectory from its own
::  shallow peek — its neck, its /code namespace if any, its fiber bang
::
+$  kid-info  [neck=(unit path) code-ns=(unit path) bang=(unit tang)]
::  +weir-json: the roads explorer reaches. peek / is honest here — a
::  namespace browser reads arbitrary paths anywhere in the tree.
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship — get-time / get-our')
          (line '/sys/eyre/' 'bind /grubbery/ball and send page responses')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/' 'browse the whole namespace — reading any path is what an explorer does')
      ==
      :-  'make'
      :-  %a
      :~  (line '/' 'create, upload, and delete files anywhere — the editor half of the explorer')
      ==
  ==
::  HTTP response door (road from /explorer.explorer/requests/* to /explorer.explorer/main.sig)
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  +send-json: a json body with the given status
::
++  send-json
  |=  [eyre-id=@ta status=@ud jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  (send-simple:srv eyre-id [[status ~[['content-type' 'application/json']]] `bod])
::  +send-missing: 404 for a path with nothing at it. Browsers get the
::  static file shell (which asks ?info=1 and hears kind=missing); the
::  ?info=1 ask itself gets that json; tools and fetches get plain text.
::
++  send-missing
  |=  [eyre-id=@ta pax=path args=(list [key=@t value=@t]) html-ok=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  ?=(^ (get-key:kv:html-utils 'info' args))
    %^  send-json  eyre-id  404
    %-  pairs:enjs:format
    :~  ['kind' s+'missing']
        ['name' s+?~(pax '' (rear pax))]
        ['path' s+(crip ?~(pax "/" (trip (spat pax))))]
    ==
  ?.  html-ok
    (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
  (send-simple:srv eyre-id [[404 ~[['content-type' 'text/html']]] `q.view-html])
::
++  wants-html
  |=  req=inbound-request:eyre
  ^-  ?
  =/  acc=(unit @t)  (get-header:http 'accept' header-list.request.req)
  ?~  acc  %.n
  ?=(^ (find "text/html" (trip u.acc)))
::
::  +texty-mite: is this mime type sensibly shown/edited as text?
::
++  texty-mite
  |=  =mite
  ^-  ?
  ?~  mite  %.y
  ?:  =(%text i.mite)  %.y
  ?:  =(/application/json mite)  %.y
  ?:  =(/application/javascript mite)  %.y
  ?:  =(/application/xml mite)  %.y
  ?:  =(~[%image %'svg+xml'] mite)  %.y
  ?:  =(/inode/symlink mite)  %.y
  %.n
::  Weir lives in the parent's dir-map, not in the directory's own lump
::
++  read-weir-from-parent
  |=  pax=path
  =/  m  (fiber:fiber:nexus ,(unit weir:nexus))
  ^-  form:m
  ?~  pax  (pure:m ~)
  =/  parent=path  (snip `path`pax)
  =/  child-name=@ta  (rear pax)
  ;<  par-view=view:nexus  bind:m  (peek-shallow:io [%& %| parent] ~)
  ?.  ?=([%ball *] par-view)  (pure:m ~)
  =/  child=(unit ball:tarball)  (~(get by dir.ball.par-view) child-name)
  ?~  child  (pure:m ~)
  ?~  fil.u.child  (pure:m ~)
  (pure:m weir.u.fil.u.child)
++  split-fas
  |=  t=@t
  ^-  path
  =/  chars=tape  (trip t)
  =|  [seg=tape out=path]
  |-  ^-  path
  ?~  chars
    ?~  seg  (flop out)
    (flop [(crip seg) out])
  ?:  =(i.chars '/')
    ?~  seg  $(chars t.chars)
    $(chars t.chars, seg ~, out [(crip seg) out])
  $(chars t.chars, seg (snoc seg i.chars))
::  +parse-road-input: parse "../../foo/bar" into a proper road
::  Counts leading "../" as relative steps, remainder as the lane.
::
++  parse-road-input
  |=  road-path=@t
  ^-  road:tarball
  =/  raw=tape  (trip road-path)
  =/  is-dir=?  &(?=(^ raw) =('/' (rear raw)))
  =/  segs=path  (split-fas road-path)
  =/  ups=@ud  0
  |-
  ?:  &(?=(^ segs) =(%'..' i.segs))
    $(segs t.segs, ups +(ups))
  =/  =lane:tarball
    ?:  is-dir
      [%| segs]
    ?~  segs  [%| /]
    [%& (snip `path`segs) (rear segs)]
  ?:(=(0 ups) &+lane |+[ups lane])
::  Handle GET requests
::
++  handle-get
  |=  [eyre-id=@ta tree-path=path is-dir=? dir-weir=(unit weir:nexus) ball=ball:tarball ball-wave=wave:nexus args=(list [key=@t value=@t]) html-ok=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >  [%explorer-peek tree-path]
  =/  download-param=(unit @t)  (get-key:kv:html-utils 'download' args)
  ?:  is-dir
    ?:  ?&(?=(^ download-param) =(u.download-param 'tar'))
      (serve-tarball eyre-id tree-path ball)
    ::  browsers get the static browse app immediately — it fetches
    ::  ?list=1 itself. Everything below (time, conversions, font) is
    ::  only needed to BUILD the listing.
    ?:  &(html-ok ?=(~ (get-key:kv:html-utils 'list' args)))
      ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils browse-html))
      (pure:m ~)
    ~&  >  %explorer-get-time
    ;<  now=@da  bind:m  get-time:io
    ~&  >  %explorer-get-conversions
    ;<  conversions=(map bars:tarball tube:clay)  bind:m
      (get-blot-conversions-shallow:io ball)
    ~&  >  %explorer-get-conversions-done
    ~&  >  %explorer-get-font
    ;<  font=(unit (unit bend:tarball))  bind:m
      (get-font:io [%& %| tree-path])
    ~&  >  %explorer-get-font-done
    =/  code-namespace=(unit path)
      ?~  font  ~
      ?~  u.font  ~
      =/  ns=(unit lane:tarball)
        (lane-from-bend:tarball [%| tree-path] u.u.font)
      ?~  ns  ~
      ?.  ?=(%| -.u.ns)  ~
      `p.u.ns
    ::  ?list=1: the listing as JSON — the static browse app's feed (and
    ::  anyone else's). Non-html non-list requests for a dir get it too.
    ::  child necks: the shallow peek of THIS dir returns subdirs as
    ::  names only, so each child is peeked for its own fil.neck (the
    ::  same per-root scan the shell's tile reader does)
    ::  the same peek also yields each child's own fiber bang, so
    ::  the row can flag a crashed sub-nexus like the old listing did
    ;<  necks=(map @ta kid-info)  bind:m
      =/  m  (fiber:fiber:nexus ,(map @ta kid-info))
      ^-  form:m
      =/  subs=(list @ta)  ~(tap in ~(key by dir.ball))
      =|  acc=(map @ta kid-info)
      |-
      ?~  subs  (pure:m acc)
      ;<  kv=view:nexus  bind:m
        (peek-shallow:io [%& %| (snoc tree-path i.subs)] ~)
      =?  acc  ?&  ?=([%ball *] kv)
                   ?=(^ fil.ball.kv)
               ==
        =/  child-code=(unit path)
          ?.  (~(has by dir.ball.kv) %code)  ~
          `(snoc (snoc tree-path i.subs) %code)
        =/  neck=(unit path)
          ?~  neck.u.fil.ball.kv  ~
          `(rail-to-path:tarball u.neck.u.fil.ball.kv)
        (~(put by acc) i.subs [neck child-code bang.u.fil.ball.kv])
      $(subs t.subs)
    =/  jon=json  (listing-json tree-path ball ball-wave now conversions code-namespace dir-weir necks)
    ;<  ~  bind:m  (send-json eyre-id 200 jon)
    (pure:m ~)
  ::  File view — ball is the parent directory
  ?~  tree-path
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  name=@ta  (rear tree-path)
  =/  content-data=(unit [=sang:tarball gain=? bang=(unit tang)])
    ?~  fil.ball  ~
    (find-grub name u.fil.ball)
  ?~  content-data
    ;<  ~  bind:m  (send-missing eyre-id tree-path args html-ok)
    (pure:m ~)
  =/  str  |=(t=tape `json`s+(crip t))
  =/  info-param=(unit @t)  (get-key:kv:html-utils 'info' args)
  =/  raw-param=(unit @t)  (get-key:kv:html-utils 'raw' args)
  =/  view-param=(unit @t)  (get-key:kv:html-utils 'view' args)
  =/  pretty-param=(unit @t)  (get-key:kv:html-utils 'pretty' args)
  ::  the static file shell (view.html + view.js): it asks ?info=1 for
  ::  what it is and ?raw=1 for the bytes. Default when a browser asks
  ::  for html; ?view=1 forces it; ?raw ?info ?pretty bypass it.
  ?:  ?&  ?=(~ raw-param)  ?=(~ info-param)  ?=(~ pretty-param)
          |(?=(^ view-param) html-ok)
      ==
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils view-html))
    (pure:m ~)
  =/  blot-tape=tape
    (spud (snoc path.p.sang.u.content-data name.p.sang.u.content-data))
  ?:  (is-boom:tarball sang.u.content-data)
    ~&  >>  [%explorer-file-boomed (rear tree-path)]
    ::  no bytes to give: the shell hears kind=boom with the tang,
    ::  everyone else gets a plain 500
    ?~  info-param
      ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'File is boomed')])
      (pure:m ~)
    =/  boom-tang=tang
      ?^  bang.u.content-data  u.bang.u.content-data
      ?:  ?=(%| -.q.sang.u.content-data)  tang.p.q.sang.u.content-data
      ~[leaf+"validation failed"]
    ;<  ~  bind:m
      %^  send-json  eyre-id  200
      %-  pairs:enjs:format
      :~  ['kind' s+'boom']
          ['name' s+name]
          ['blot' (str blot-tape)]
          ['boom' (str (render-tang boom-tang))]
      ==
    (pure:m ~)
  =/  =sage:tarball  (need-sage:tarball sang.u.content-data)
  ?^  pretty-param
    ::  ?pretty: render noun as text instead of binary download
    =/  bod=octs  (as-octs:mimes:html (crip (noah q.sage)))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/plain bod]))
    (pure:m ~)
  ;<  =mime  bind:m  (sage-to-mime:io sage)
  ?~  info-param
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [p.mime q.mime]))
    (pure:m ~)
  ::  ?info=1: the file as data. x-urb-jam is sage-to-mime's no-tube
  ::  fallback: the noun pretty-printed rides along as text, read-only.
  ::  Texty content the shell fetches itself via ?raw=1.
  =/  jammed=?  =(/application/x-urb-jam p.mime)
  =/  texty=?  &(!jammed (texty-mite p.mime))
  ::  code build status: does this file live under a /code nexus?
  =/  code-name=@ta
    =/  raw=@ta  (rear tree-path)
    =/  t=tape  (trip raw)
    =/  len=@ud  (lent t)
    ?.  &((gth len 5) =(".hoon" (slag (sub len 5) t)))
      raw
    (crip (scag (sub len 5) t))
  =/  file-road=road:tarball  [%& %& (snip `path`tree-path) code-name]
  ;<  font=(unit (unit bend:tarball))  bind:m
    (get-font:io file-road)
  =/  has-code=?  &(?=(^ font) ?=(^ u.font))
  ;<  build-info=[build-status=tape build-detail=tape]  bind:m
    ?.  has-code  (pure:(fiber:fiber:nexus ,[tape tape]) ["" ""])
    ;<  =built:nexus  bind:(fiber:fiber:nexus ,[tape tape])
      (get-code-full:io file-road)
    %-  pure:(fiber:fiber:nexus ,[tape tape])
    ?-  -.built
        %vase
      =/  printed=tape  ~(ram re (sell vase.built))
      :-  "vase"
      ?:  (lth (lent printed) 4.000)  printed
      (weld (scag 4.000 printed) "...")
        %tang
      :-  "tang"
      %-  zing
      %+  turn  (render-tang-to-wall:http-utils [160 tang.built])
      |=(t=tape (weld t "\0a"))
        %mime
      ["mime" "raw mime (no compilation)"]
    ==
  ;<  ~  bind:m
    %^  send-json  eyre-id  200
    %-  pairs:enjs:format
    :~  ['kind' s+'file']
        ['name' s+name]
        ['blot' (str blot-tape)]
        ['mite' (str (spud p.mime))]
        ['texty' b+texty]
        ['jammed' b+jammed]
        ['text' ?.(jammed ~ (str (noah q.sage)))]
        :-  'build'
        %-  pairs:enjs:format
        :~  ['status' (str build-status.build-info)]
            ['detail' (str build-detail.build-info)]
        ==
        ['bang' ?~(bang.u.content-data ~ (str (render-tang u.bang.u.content-data)))]
    ==
  (pure:m ~)
::  Handle POST requests (delete actions)
::
++  handle-post
  |=  [eyre-id=@ta tree-path=path dir-weir=(unit weir:nexus) root=ball:tarball req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  Check for multipart upload
  =/  content-type=(unit @t)
    (get-header:http 'content-type' header-list.request.req)
  ?:  ?&  ?=(^ content-type)
          =('multipart/form-data; boundary=' (end 3^30 u.content-type))
      ==
    (handle-upload eyre-id tree-path req)
  ::  Form-encoded POST
  =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
  =/  action=(unit @t)  (get-key:kv:html-utils 'action' args)
  =/  redirect-url=tape
    ?~(tree-path "/grubbery/ball" "/grubbery/ball{(trip (spat tree-path))}")
  ?~  action
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing action')])
    (pure:m ~)
  ?+    u.action
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Unknown action')])
      (pure:m ~)
  ::
      %'delete-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    ::  cull road: up 3 from /explorer.explorer/requests/[id] to root, then file
    ;<  ~  bind:m  (cull:io [%& %& tree-path filename])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      ::  write-text: the file view's save. POSTed to the FILE url, so
      ::  tree-path here is the file's own path. The edited text goes in
      ::  as mime and the runtime tubes it through the grub's existing
      ::  blot — the marc's mime grab IS the validation. Mirrors forge's
      ::  do-src: %hoon takes text directly, %mime stays mime (keeping
      ::  its mite), everything else rides over-as-soft so a failed
      ::  parse comes back as a tang for the editor, not a crash.
      ::
      %'write-text'
    ?~  tree-path
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'no file')])
      (pure:m ~)
    =/  fdir=path  (snip `path`tree-path)
    =/  fnam=@ta  (rear tree-path)
    =/  content=@t  (fall (get-key:kv:html-utils 'content' args) '')
    ;<  cur=view:nexus  bind:m  (peek:io [%& %& fdir fnam] ~)
    ?.  ?=([%file *] cur)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'not a file')])
      (pure:m ~)
    =/  ok=octs  (as-octs:mimes:html 'saved')
    ?:  =([/ %hoon] p.sang.cur)
      ;<  ~  bind:m  (over:io [%& %& fdir fnam] [[/ %hoon] content])
      ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `ok])
      (pure:m ~)
    ?:  =([/ %mime] p.sang.cur)
      =/  cur-mime=mime  !<(mime (need-vase:tarball sang.cur))
      =/  new-mite=mite
        =/  mt=(unit @t)  (get-key:kv:html-utils 'mite' args)
        ?~  mt  p.cur-mime
        ?:  =('' u.mt)  ~
        (fall (rush u.mt ;~(pfix (punt fas) (more fas sym))) p.cur-mime)
      ;<  ~  bind:m
        (over:io [%& %& fdir fnam] [[/ %mime] `mime`[new-mite (as-octs:mimes:html content)]])
      ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `ok])
      (pure:m ~)
    ;<  err=(unit tang)  bind:m
      %^    over-as-soft:io
          [%& %& fdir fnam]
        [[/ %mime] `mime`[/text/plain (as-octs:mimes:html content)]]
      p.sang.cur
    ?~  err
      ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `ok])
      (pure:m ~)
    =/  msg=tape
      (of-wall:format (render-tang-to-wall:http-utils 80 u.err))
    ;<  ~  bind:m
      (send-simple:srv eyre-id [[422 ~] `(as-octs:mimes:html (crip msg))])
    (pure:m ~)
  ::
      %'delete-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  folder-path=path  (snoc tree-path foldername)
    ;<  ~  bind:m  (cull:io [%& %| folder-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dir-name=@ta  foldername
    =/  folder-path=path  (snoc tree-path dir-name)
    =/  new-ball=ball:tarball  [`[~ ~ %.n ~ ~] ~]
    ;<  ~  bind:m  (make:io [%& %| folder-path] &+(ball-to-bole:tarball new-ball))
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-nexus'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dir-name=@ta  foldername
    =/  neck-str=@t  (fall (get-key:kv:html-utils 'neck' args) '')
    =/  dir-neck=(unit neck:tarball)
      ?:  =('' neck-str)  ~
      =/  pax=path  (stab neck-str)
      ?~  pax  ~
      `[(snip `(list @ta)`pax) (rear pax)]
    =/  folder-path=path  (snoc tree-path dir-name)
    =/  new-ball=ball:tarball  [`[dir-neck ~ %.n ~ ~] ~]
    ;<  ~  bind:m  (make:io [%& %| folder-path] &+(ball-to-bole:tarball new-ball))
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-file'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    ?:  =('' filename)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename')])
      (pure:m ~)
    =/  blot-str=@t  (fall (get-key:kv:html-utils 'blot' args) '')
    =/  blt=(unit blot:tarball)
      ?.  =('' blot-str)
        =/  pax=path  (stab blot-str)
        ?~  pax  ~
        `[(snip `(list @ta)`pax) (rear pax)]
      =/  ext=(unit @ta)  (parse-extension:tarball filename)
      ?~  ext  ~
      `[/ u.ext]
    ?~  blt
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Filename needs an extension or a mark path')])
      (pure:m ~)
    =/  =blot:tarball  u.blt
    ;<  marc=(unit marc:tarball)  bind:m  (get-marc:io [%& %| /code] blot)
    ?~  marc
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'No mark found for that extension')])
      (pure:m ~)
    =/  content=(each vase tang)  (mule |.(bunt.u.marc))
    ?.  ?=(%& -.content)
      %-  (slog p.content)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Mark bunt crashed')])
      (pure:m ~)
    =/  =bask:tarball  [blot q.p.content]
    ;<  ~  bind:m  (make:io [%& %& tree-path filename] |+[bask ~])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-symlink'
    =/  linkname=@t  (fall (get-key:kv:html-utils 'linkname' args) '')
    ?:  =('' linkname)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing linkname')])
      (pure:m ~)
    =/  target=@t  (fall (get-key:kv:html-utils 'target' args) '')
    ?:  =('' target)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing target')])
      (pure:m ~)
    =/  sym=(unit symlink:tarball)  (parse-symlink:tarball target)
    ?~  sym
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid symlink target')])
      (pure:m ~)
    ;<  ~  bind:m  (make:io [%& %& tree-path linkname] |+[[[/ %symlink] u.sym] ~])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'add-weir-road'
    ::  load-bearing weirs: a weir on /apps (or on explorer itself) locks
    ::  the very tools that manage weirs — including THIS request fiber,
    ::  which then dies un-self-cleaned and replays its sand on every
    ::  restart (learned the hard way). Flatly refuse.
    ?:  |(=(/apps tree-path) =(/apps/'explorer.explorer' tree-path))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'this weir is load-bearing: restricting it would make grubbery painfully difficult to interface with from the outside')])
      (pure:m ~)
    =/  category=@t  (fall (get-key:kv:html-utils 'category' args) '')
    =/  road-path=@t  (fall (get-key:kv:html-utils 'road-path' args) '')
    ?:  |(=('' category) =('' road-path))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing fields')])
      (pure:m ~)
    =/  new-road=road:tarball  (parse-road-input road-path)
    =/  cur=weir:nexus  (fall dir-weir [~ ~ ~])
    =/  new=weir:nexus
      ?+  category  cur
        %'write'  cur(make (~(put in make.cur) new-road))
        %'poke'   cur(poke (~(put in poke.cur) new-road))
        %'read'   cur(peek (~(put in peek.cur) new-road))
      ==
    ;<  ~  bind:m  (sand:io [%& %| tree-path] `new)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      ::  make-weir: create an EMPTY weir — a filter with no holes, i.e.
      ::  fully closed until roads are added (absent weir = unrestricted)
      ::
      %'make-weir'
    ::  load-bearing weirs: a weir on /apps (or on explorer itself) locks
    ::  the very tools that manage weirs — including THIS request fiber,
    ::  which then dies un-self-cleaned and replays its sand on every
    ::  restart (learned the hard way). Flatly refuse.
    ?:  |(=(/apps tree-path) =(/apps/'explorer.explorer' tree-path))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'this weir is load-bearing: restricting it would make grubbery painfully difficult to interface with from the outside')])
      (pure:m ~)
    =/  new=weir:nexus  [~ ~ ~]
    ;<  ~  bind:m  (sand:io [%& %| tree-path] `new)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'del-weir-road'
    ::  load-bearing weirs: a weir on /apps (or on explorer itself) locks
    ::  the very tools that manage weirs — including THIS request fiber,
    ::  which then dies un-self-cleaned and replays its sand on every
    ::  restart (learned the hard way). Flatly refuse.
    ?:  |(=(/apps tree-path) =(/apps/'explorer.explorer' tree-path))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'this weir is load-bearing: restricting it would make grubbery painfully difficult to interface with from the outside')])
      (pure:m ~)
    =/  category=@t  (fall (get-key:kv:html-utils 'category' args) '')
    =/  road-path=@t  (fall (get-key:kv:html-utils 'road-path' args) '')
    ?:  =('' category)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing category')])
      (pure:m ~)
    =/  del-road=road:tarball  (parse-road-input road-path)
    =/  cur=weir:nexus  (fall dir-weir [~ ~ ~])
    =/  new=weir:nexus
      ?+  category  cur
        %'write'  cur(make (~(del in make.cur) del-road))
        %'poke'   cur(poke (~(del in poke.cur) del-road))
        %'read'   cur(peek (~(del in peek.cur) del-road))
      ==
    ;<  ~  bind:m  (sand:io [%& %| tree-path] `new)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'clear-weir'
    ::  load-bearing weirs: a weir on /apps (or on explorer itself) locks
    ::  the very tools that manage weirs — including THIS request fiber,
    ::  which then dies un-self-cleaned and replays its sand on every
    ::  restart (learned the hard way). Flatly refuse.
    ?:  |(=(/apps tree-path) =(/apps/'explorer.explorer' tree-path))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'this weir is load-bearing: restricting it would make grubbery painfully difficult to interface with from the outside')])
      (pure:m ~)
    ;<  ~  bind:m  (sand:io [%& %| tree-path] ~)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'reload-nexus'
    ;<  ~  bind:m  (reload:io [%& %| tree-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'rename-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    =/  newname=@t  (fall (get-key:kv:html-utils 'newname' args) '')
    ?:  |(=('' filename) =('' newname))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename or newname')])
      (pure:m ~)
    ;<  ~  bind:m  (move-grub:io [%& %& tree-path filename] [%& %& tree-path newname])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'rename-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  newname=@t  (fall (get-key:kv:html-utils 'newname' args) '')
    ?:  |(=('' foldername) =('' newname))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername or newname')])
      (pure:m ~)
    ;<  ~  bind:m  (move-fold:io [%& %| (snoc tree-path foldername)] [%& %| (snoc tree-path newname)])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'move-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' filename) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ?~  dest-path
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid dest path')])
      (pure:m ~)
    =/  dst-dir=path  (snip `path`dest-path)
    =/  dst-name=@ta  (rear dest-path)
    ;<  ~  bind:m  (move-grub:io [%& %& tree-path filename] [%& %& dst-dir dst-name])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'move-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' foldername) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ;<  ~  bind:m  (move-fold:io [%& %| (snoc tree-path foldername)] [%& %| dest-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'copy-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' filename) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ?~  dest-path
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid dest path')])
      (pure:m ~)
    =/  dst-dir=path  (snip `path`dest-path)
    =/  dst-name=@ta  (rear dest-path)
    ;<  ~  bind:m  (copy-grub:io [%& %& tree-path filename] [%& %& dst-dir dst-name])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'copy-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' foldername) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ;<  ~  bind:m  (copy-fold:io [%& %| (snoc tree-path foldername)] [%& %| dest-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ==
::  Handle multipart file upload
::
++  handle-upload
  |=  [eyre-id=@ta tree-path=path req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  parts=(unit (list [@t part:multipart]))
    (de-request:multipart header-list.request.req body.request.req)
  ?~  parts
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid multipart data')])
    (pure:m ~)
  ::  Build mime→mark tubes for uploaded file extensions
  ;<  now=@da  bind:m  get-time:io
  =/  exts=(set @ta)
    %-  ~(gas in *(set @ta))
    %+  murn  u.parts
    |=  [field-name=@t =part:multipart]
    ?.  =('file' field-name)  ~
    ?~  file.part  ~
    (parse-extension:tarball u.file.part)
  ;<  conversions=(map bars:tarball tube:clay)  bind:m
    =/  m  (fiber:fiber:nexus ,(map bars:tarball tube:clay))
    =/  ext-list=(list @ta)  ~(tap in exts)
    =|  convs=(map bars:tarball tube:clay)
    |-  ^-  form:m
    ?~  ext-list  (pure:m convs)
    =/  =bars:tarball  [[/ %mime] [/ i.ext-list]]
    ;<  tube=(unit tube:clay)  bind:m
      (get-tube:io [%& %| /code] bars)
    =?  convs  ?=(^ tube)
      (~(put by convs) bars u.tube)
    $(ext-list t.ext-list)
  ::  Build ball from multipart using from-parts
  =/  new=ball:tarball
    (from-parts:tarball *ball:tarball ~ u.parts now conversions)
  ::  Make each top-level entry: files then directories
  =/  files=(list [@ta [=sang:tarball gain=? bang=(unit tang)]])
    ?~  fil.new  ~
    ~(tap by contents.u.fil.new)
  |-
  ?^  files
    =/  [name=@ta =sang:tarball gain=? bang=(unit tang)]  i.files
    ;<  ~  bind:m
      (make:io [%& %& tree-path name] |+[[p.sang (sang-noun:tarball sang)] ~])
    $(files t.files)
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.new)
  |-
  ?^  dirs
    =/  [name=@ta sub=ball:tarball]  i.dirs
    ;<  ~  bind:m
      (make:io [%& %| (snoc tree-path name)] &+(ball-to-bole:tarball sub))
    $(dirs t.dirs)
  =/  redirect-url=tape
    ?~(tree-path "/grubbery/ball" "/grubbery/ball{(trip (spat tree-path))}")
  ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
  (pure:m ~)
::  Serve a directory as a tarball download
::
++  serve-tarball
  |=  [eyre-id=@ta tree-path=path b=ball:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  conversions=(map bars:tarball tube:clay)  bind:m
    (get-blot-conversions:io b)
  =/  tar=tarball:tarball
    (~(make-tarball gen:tarball [now conversions]) tree-path b)
  =/  tar-data=octs  (encode-tarball:tarball tar)
  =/  dir-name=tape
    ?~(tree-path "root" (trip (rear tree-path)))
  =/  headers=header-list:http
    :~  ['content-type' 'application/x-tar']
        ['content-disposition' (crip "attachment; filename=\"{dir-name}.tar\"")]
    ==
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 headers] `tar-data])
  (pure:m ~)
::  Find a grub by exact name in a lump
::
++  find-grub
  |=  [seg=@ta =lump:tarball]
  ^-  (unit [=sang:tarball gain=? bang=(unit tang)])
  (~(get by contents.lump) seg)
++  road-to-form
  |=  =road:tarball
  ^-  tape
  ?-    -.road
      %&  (render-lane p.road)
      %|
    =/  prefix=tape  (zing (reap p.p.road "../"))
    =/  lane=tape  (render-lane q.p.road)
    =/  trimmed=tape  ?:(&(?=(^ lane) =(i.lane '/')) t.lane lane)
    "{prefix}{trimmed}"
  ==
::
++  render-lane
  |=  =lane:tarball
  ^-  tape
  ?-    -.lane
      %&
    ?~  path.p.lane
      "/{(trip name.p.lane)}"
    "{(trip (spat path.p.lane))}/{(trip name.p.lane)}"
      %|
    ?~(p.lane "/" "{(trip (spat p.lane))}/")
  ==
::
::  +listing-json: the dir listing as data — everything the browse app shows,
::  one child object per subdir and grub. Pure given its inputs (the mime
::  conversions ride the prefetched tube map, via gen:tarball).
::
++  listing-json
  |=  $:  pax=path
          b=ball:tarball
          b-wave=wave:nexus
          now=@da
          conversions=(map bars:tarball tube:clay)
          code-namespace=(unit path)
          dir-weir=(unit weir:nexus)
          necks=(map @ta kid-info)
      ==
  ^-  json
  =/  str  |=(t=tape `json`s+(crip t))
  =/  neck-url=(unit tape)
    ?~  fil.b  ~
    ?~  neck.u.fil.b  ~
    ?:  =([/ %code] u.neck.u.fil.b)  ~
    ?~  code-namespace  ~
    `"/grubbery/ball{(trip (spat (weld u.code-namespace /nex)))}{(trip (spat (rail-to-path:tarball u.neck.u.fil.b)))}.hoon"
  =/  neck-display=tape
    ?~  fil.b  "-"
    ?~  neck.u.fil.b  "-"
    (trip (spat (rail-to-path:tarball u.neck.u.fil.b)))
  =/  file-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    ?~  fil.b  ~
    contents.u.fil.b
  =/  mtime
    |=  name=@ta
    ^-  json
    ?~  fil.b-wave  ~
    =/  cas=(unit cass:clay)  (~(get by file.u.fil.b-wave) name)
    ?~  cas  ~
    (str (en:datetime-local:iso-8601 da.u.cas))
  =/  dirs=(list json)
    %+  turn
      (sort ~(tap by dir.b) |=([[a=@ta *] [b=@ta *]] (aor a b)))
    |=  [name=@ta kid=ball:tarball]
    ^-  json
    =/  kid=(unit kid-info)  (~(get by necks) name)
    =/  neck-json=json
      ?~  kid  ~
      ?~  neck.u.kid  ~
      s+(crip (spud u.neck.u.kid))
    =/  neck-url-json=json
      ?~  kid  ~
      ?~  neck.u.kid  ~
      ?:  =(/code u.neck.u.kid)  ~
      =/  ns=(unit path)  ?^(code-ns.u.kid code-ns.u.kid code-namespace)
      ?~  ns  ~
      (str "/grubbery/ball{(trip (spat (weld u.ns /nex)))}{(trip (spat u.neck.u.kid))}.hoon")
    =/  kid-bang=json
      ?~  kid  ~
      ?~  bang.u.kid  ~
      (str (render-tang u.bang.u.kid))
    =/  dir-mod=json
      =/  kid-wave=(unit wave:nexus)  (~(get by dir.b-wave) name)
      ?~  kid-wave  ~
      ?~  fil.u.kid-wave  ~
      (str (en:datetime-local:iso-8601 da.fold.u.fil.u.kid-wave))
    (pairs:enjs:format ~[['name' s+`@t`name] ['kind' s+'dir'] ['neck' neck-json] ['neck-url' neck-url-json] ['bang' kid-bang] ['modified' dir-mod]])
  =/  files=(list json)
    %+  turn
      (sort ~(tap by file-contents) |=([[a=@ta *] [b=@ta *]] (aor a b)))
    |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
    ^-  json
    ?:  (is-boom:tarball sang)
      =/  boom-tang=tang  ?~(bang ~[leaf+"validation failed"] u.bang)
      %-  pairs:enjs:format
      :~  ['name' s+`@t`name]
          ['kind' s+'boom']
          ['blot' (str (spud (rail-to-path:tarball p.sang)))]
          ['boom' (str (render-tang boom-tang))]
          ['modified' (mtime name)]
      ==
    =/  sag=sage:tarball  (need-sage:tarball sang)
    =/  blot-json=json  (str (spud (rail-to-path:tarball p.sag)))
    =/  mark-url=json
      ?~  code-namespace  ~
      =/  mar-path=path
        (weld u.code-namespace (weld /mar (rail-to-path:tarball p.sag)))
      (str "/grubbery/ball{(trip (spat mar-path))}.hoon")
    ?:  =(%symlink name.p.sag)
      =/  sym  !<(symlink:tarball q.sag)
      %-  pairs:enjs:format
      :~  ['name' s+`@t`name]
          ['kind' s+'symlink']
          ['blot' blot-json]
          ['blot-url' mark-url]
          ['target' (str (trip (encode-symlink:tarball sym)))]
          ['resolved' (str (trip (spat (resolve-symlink:tarball sym pax))))]
          ['modified' (mtime name)]
      ==
    =/  =mime
      ?:  =(%mime name.p.sag)
        !<(mime q.sag)
      (~(sage-to-mime gen:tarball [now conversions]) sag)
    =/  mime-raw=tape  (trip (spat p.mime))
    =/  ext=(unit @ta)  (parse-extension:tarball name)
    =/  rail-ext=@ta
      %-  crip  %-  zing
      %+  join  "_"
      (turn (rail-to-path:tarball p.sag) trip)
    %-  pairs:enjs:format
    :~  ['name' s+`@t`name]
        ['kind' s+'file']
        ['blot' blot-json]
        ['blot-url' mark-url]
        ['mismatch' b+?~(ext %.y !=(u.ext rail-ext))]
        ['mime' (str ?~(mime-raw "" (tail mime-raw)))]
        ['size' (numb:enjs:format p.q.mime)]
        ['binary' b+=(p.mime /application/x-urb-jam)]
        ['bang' ?~(bang ~ (str (render-tang u.bang)))]
        ['modified' (mtime name)]
    ==
  =/  weir-json=json
    ?~  dir-weir  ~
    =/  cat
      |=  roads=(set road:tarball)
      ^-  json
      a+(turn ~(tap in roads) |=(r=road:tarball `json`s+(crip (road-to-form r))))
    %-  pairs:enjs:format
    :~  ['write' (cat make.u.dir-weir)]
        ['poke' (cat poke.u.dir-weir)]
        ['read' (cat peek.u.dir-weir)]
    ==
  =/  nexus-bang=json
    ?~  fil.b  ~
    ?~  bang.u.fil.b  ~
    (str (render-tang u.bang.u.fil.b))
  %-  pairs:enjs:format
  :~  ['path' (str ?~(pax "/" (trip (spat pax))))]
      ['root' b+?=(~ pax)]
      :-  'nexus'
      %-  pairs:enjs:format
      :~  ['display' (str neck-display)]
          ['url' ?~(neck-url ~ (str u.neck-url))]
      ==
      ['weir' weir-json]
      ['bang' nexus-bang]
      ['children' a+(weld dirs files)]
  ==
::
++  render-tang
  |=  =tang
  ^-  tape
  %-  zing
  %+  turn  (flop tang)
  |=(=tank (weld ~(ram re tank) "\0a"))
--
