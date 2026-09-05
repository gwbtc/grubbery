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
/&  browse-html  explorer/ui/browse.html
/&  browse-js    explorer/ui/browse.js
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
          [%over %& [/ %'browse.html'] [[/ %mime] browse-html]]
          [%over %& [/ %'browse.js'] [[/ %mime] browse-js]]
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
        ~&  >  "%explorer /main: binding /grubbery/ball and /grubbery/split"
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/ball])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/split])
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
        ?:  ?=([%grubbery %split *] site)
          =/  bod=octs  (manx-to-octs:server render-split)
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
          (pure:m ~)
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
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
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
          (line '/sys/eyre/' 'bind /grubbery/ball and /grubbery/split and send page responses')
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
::  +view-page: source view shell — plain pre, upgraded client-side
::  by view.js (shiki + the pkova hoon grammar)
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
  ?~  mite  %.n
  ?:  =(%text i.mite)  %.y
  ?:  =(/application/json mite)  %.y
  ?:  =(/application/javascript mite)  %.y
  ?:  =(/application/xml mite)  %.y
  ?:  =(~[%image %'svg+xml'] mite)  %.y
  %.n
::  +view-page: file page — Text (editable when the mime is texty and a
::  tube exists) | Mime (FilePreview render / raw). Saving posts back to
::  the file URL as action=write-text; the server tubes the mime through
::  the grub's own blot, so the marc validates the edit (see handle-post).
::
++  view-page
  |=  [name=@ta txt=tape blot-tape=tape mite-tape=tape texty=? jammed=?]
  ^-  manx
  ;html
    ;head
      ;title: {(trip name)}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", type "image/svg+xml", href "/grubbery/tiles/icon/explorer.explorer");
      ;style: {view-css}
    ==
    ;body(data-name (trip name), data-texty ?:(texty "1" "0"), data-jammed ?:(jammed "1" "0"), data-mite mite-tape)
      ;div#bar
        ;button#tab-text: Source
        ;button#tab-mime: Preview
        ;span#fname: {(trip name)}
        ;span.chip
          ;span.k: blot
          ;span.v: {blot-tape}
        ==
        ;span.chip
          ;span.k: mime
          ;span.v: {mite-tape}
        ==
        ;span.grow;
      ==
      ;div#tools
        ;button#edit: Edit
        ;button#save(disabled ""): Save
        ;button#live: Live
        ;button#wrap: Wrap
        ;span#status;
      ==
      ;div#text-view
        ;+  ?:  &(texty !jammed)
              ;div.edwrap
                ;div#src-display;
                ;textarea#ed(spellcheck "false", style "display:none"): {txt}
              ==
            ?:  jammed
              ;pre#src: {txt}
            ;pre#src.dim: binary content
      ==
      ;div#mime-view(style "display:none");
      ;script(src "/grubbery/ball/apps/explorer.explorer/file-preview.js");
      ;script(type "module", src "/grubbery/ball/apps/explorer.explorer/view.js");
    ==
  ==
::  the file page's css, kept out of the manx for legibility
::
++  view-css
  ^-  tape
  ::  cords, not tapes: css braces would read as tape interpolation.
  ::  house-light, per the kit.
  %-  trip
  %+  rap  3
  :~
      'body { background: #ffffff; color: #1f2328; margin: 0; height: 100vh; display: flex; flex-direction: column; font: 13px/1.5 -apple-system, BlinkMacSystemFont, sans-serif; }'
      '#bar { flex: none; display: flex; align-items: center; gap: 8px; padding: 8px 12px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; }'
      '#fname { font-weight: 600; margin-left: 8px; }'
      '.chip { display: inline-flex; align-items: center; gap: 5px; background: #eef1f4; border: 1px solid #e2e7ee; border-radius: 6px; padding: 2px 8px; }'
      '.chip .k { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; }'
      '.chip .v { font: 11px ui-monospace, SFMono-Regular, Menlo, monospace; color: #24292f; }'
      '.grow { flex: 1; }'
      '#bar button { all: unset; cursor: pointer; padding: 4px 12px; border-radius: 7px; font-size: 12px; color: #57606a; }'
      '#bar button:hover { color: #24292f; background: #eaeef2; }'
      '#bar button.on { color: #24292f; background: #ffffff; border: 1px solid #d0d7de; font-weight: 600; padding: 3px 11px; }'
      '#tools { flex: none; display: flex; align-items: center; gap: 8px; padding: 6px 12px; background: #fff; border-bottom: 1px solid #e2e7ee; }'
      '#tools button { all: unset; cursor: pointer; padding: 3px 12px; border-radius: 7px; font-size: 12px; border: 1px solid #d0d7de; color: #24292f; }'
      '#tools button:hover { background: #f6f8fa; }'
      '#tools button.on { background: #ddf4ff; border-color: #54aeff; color: #0969da; font-weight: 600; }'
      '#save:not([disabled]) { background: #0969da; border-color: #0969da; color: #fff; }'
      '#save:not([disabled]):hover { background: #0857b8; }'
      '#save[disabled] { color: #8b949e; cursor: default; }'
      '#tools button[disabled] { color: #8b949e; cursor: default; background: none; }'
      '#status { font: 11px ui-monospace, monospace; color: #57606a; max-width: 40ch; overflow: hidden; text-overflow: ellipsis; white-space: pre; }'
      '#status.err { color: #cf222e; white-space: pre-wrap; }'
      '#text-view, #mime-view { flex: 1; min-height: 0; overflow: auto; }'
      '.edwrap, #src-display { height: 100%; }'
      'body.wrap #text-view pre { white-space: pre-wrap; overflow-wrap: anywhere; }'
      'body:not(.wrap) #ed { white-space: pre; overflow-x: auto; }'
      'pre { margin: 0; padding: 18px; font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; overflow: auto; box-sizing: border-box; min-height: 100%; }'
      'pre.dim { color: #8b949e; }'
      'code { font: inherit; }'
      '#ed { width: 100%; height: 100%; box-sizing: border-box; background: #fff; color: #1f2328; border: none; outline: none; resize: none; padding: 18px; font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }'
      '#ed[readonly] { background: #fbfcfd; color: #3b434b; }'
      '#hl-status { position: fixed; top: 48px; right: 12px; font: 11px ui-monospace, monospace; color: #57606a; background: #f6f8fa; border: 1px solid #d0d7de; border-radius: 12px; padding: 4px 10px; }'
      '.md { max-width: 74ch; padding: 24px 32px; line-height: 1.65; }'
      '.md h1, .md h2, .md h3 { border-bottom: 1px solid #e2e7ee; padding-bottom: .3em; }'
      '.md code { background: #f2f4f7; padding: 1px 5px; border-radius: 5px; font: 12px ui-monospace, monospace; }'
      '.md pre { background: #f6f8fa; border-radius: 8px; min-height: 0; }'
      '.md pre code { background: none; padding: 0; }'
      '.md a { color: #0969da; }'
      '.md blockquote { border-left: 3px solid #d0d7de; margin-left: 0; padding-left: 14px; color: #57606a; }'
      'table.csv { border-collapse: collapse; margin: 20px; font: 12px ui-monospace, monospace; }'
      'table.csv th, table.csv td { border: 1px solid #d0d7de; padding: 5px 12px; text-align: left; }'
      'table.csv th { background: #f6f8fa; }'
      'table.csv tr:nth-child(even) td { background: #fbfcfd; }'
  ==
::  Weir lives in the parent's dir-map, not in the directory's own lump
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
    ::  only needed to BUILD a listing or the ?legacy sail page.
    ?:  ?&  html-ok
            ?=(~ (get-key:kv:html-utils 'list' args))
            ?=(~ (get-key:kv:html-utils 'legacy' args))
        ==
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
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  code-namespace=(unit path)
      ?~  font  ~
      ?~  u.font  ~
      =/  ns=(unit lane:tarball)
        (lane-from-bend:tarball [%& here] u.u.font)
      ?~  ns  ~
      ?.  ?=(%| -.u.ns)  ~
      `p.u.ns
    ::  ?list=1: the same data render-dir renders, as JSON — the static
    ::  browse app's feed (and anyone else's)
    ?:  ?=(^ (get-key:kv:html-utils 'list' args))
      =/  jon=json  (listing-json tree-path ball ball-wave now conversions code-namespace dir-weir)
      =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
      (pure:m ~)
    ::  ~>(%bout.[1 %explorer-render-dir] ...)
    =/  page=manx  (render-dir tree-path ball ball-wave now conversions code-namespace dir-weir)
    ::  ~>(%bout.[1 %explorer-manx-to-octs] ...)
    =/  bod=octs  (manx-to-octs:server page)
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
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
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  ?:  (is-boom:tarball sang.u.content-data)
    ~&  >>  [%explorer-file-boomed (rear tree-path)]
    ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'File is boomed')])
    (pure:m ~)
  =/  =sage:tarball  (need-sage:tarball sang.u.content-data)
  =/  pretty-param=(unit @t)  (get-key:kv:html-utils 'pretty' args)
  ?^  pretty-param
    ::  ?pretty: render noun as text instead of binary download
    =/  bod=octs  (as-octs:mimes:html (crip (noah q.sage)))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/plain bod]))
    (pure:m ~)
  ::  source view: html + syntax highlighting (hoon via shiki + the
  ::  same pkova grammar github renders with). Default for .hoon
  ::  when a browser asks (Accept: text/html) — tools and fetch get
  ::  raw bytes as ever. ?view=1 forces, ?raw=1 suppresses.
  =/  view-param=(unit @t)  (get-key:kv:html-utils 'view' args)
  =/  raw-param=(unit @t)  (get-key:kv:html-utils 'raw' args)
  ::  file view page: Text (editable, tubed both ways) | Mime (rendered).
  ::  Default when a browser asks for html; tools and fetch still get raw
  ::  bytes (?raw=1 always does, ?view=1 always forces the page).
  ?:  ?&  ?=(~ raw-param)
          |(?=(^ view-param) html-ok)
      ==
    ;<  =mime  bind:m  (sage-to-mime:io sage)
    ::  x-urb-jam is sage-to-mime's no-tube fallback: show the noun
    ::  pretty-printed, read-only. Binary mites: mime view only.
    =/  jammed=?  =(/application/x-urb-jam p.mime)
    =/  texty=?  &(!jammed (texty-mite p.mime))
    =/  txt=tape
      ?:  jammed  (noah q.sage)
      ?:  texty  (trip q.q.mime)
      ""
    =/  bod=octs
      %-  as-octs:mimes:html  %-  crip  %-  en-xml:html
      =/  blot-tape=tape  (spud (snoc path.p.sage name.p.sage))
      (view-page name txt blot-tape (spud p.mime) texty jammed)
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
    (pure:m ~)
  ;<  =mime  bind:m  (sage-to-mime:io sage)
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [p.mime q.mime]))
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
      ;<  ~  bind:m
        (over:io [%& %& fdir fnam] [[/ %mime] `mime`[p.cur-mime (as-octs:mimes:html content)]])
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
    =/  dir-neck=(unit neck:tarball)
      (bind (parse-extension:tarball dir-name) ext-to-neck:tarball)
    =/  folder-path=path  (snoc tree-path dir-name)
    =/  new-ball=ball:tarball  [`[dir-neck ~ %.n ~ ~] ~]
    ;<  ~  bind:m  (make:io [%& %| folder-path] &+(ball-to-bole:tarball new-ball))
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
      %'del-weir-road'
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
++  resolve-url-path
  |=  [raw=path root=ball:tarball]
  ^-  path
  =/  current=ball:tarball  root
  =/  result=path  ~
  |-
  ?~  raw  result
  =/  child=(unit ball:tarball)  (~(get by dir.current) i.raw)
  ?^  child
    $(raw t.raw, result (snoc result i.raw), current u.child)
  ::  No match — keep segment as-is
  $(raw t.raw, result (snoc result i.raw))
::  Build URL path from segments
::
++  build-url
  |=  pax=path
  ^-  tape
  =/  acc=tape  "/grubbery/ball"
  |-
  ?~  pax  acc
  $(pax t.pax, acc (weld acc "/{(trip i.pax)}"))
::
++  page-head
  |=  title=tape
  ^-  manx
  ;head
    ;title: {title}
    ;meta(charset "utf-8");
    ;meta(name "viewport", content "width=device-width, initial-scale=1");
    ;link(rel "icon", type "image/svg+xml", href "/grubbery/tiles/icon/explorer.explorer");
    ;style
      ; * { box-sizing: border-box; }
      ; body { font: 13px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #1f2328; background: #fff; margin: 0; padding-bottom: 48px; }
      ; h1 { display: none; }
      ; a { color: #0969da; text-decoration: none; }
      ; a:hover { text-decoration: underline; }
      ; .breadcrumb { position: sticky; top: 0; display: flex; align-items: center; flex-wrap: wrap; gap: 2px; padding: 10px 20px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; font: 600 13px ui-monospace, SFMono-Regular, Menlo, monospace; z-index: 5; }
      ; .breadcrumb a { color: #57606a; padding: 2px 4px; border-radius: 5px; margin: 0; }
      ; .breadcrumb a:hover { color: #24292f; background: #eaeef2; text-decoration: none; }
      ; .breadcrumb a:last-child { color: #24292f; }
      ; .info { margin: 16px 20px 4px; padding: 0; background: none; border-radius: 0; }
      ; .info dl { display: grid; grid-template-columns: max-content 1fr; gap: 3px 14px; margin: 0 0 12px; }
      ; .info dt { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; float: none; width: auto; align-self: center; }
      ; .info dd { margin: 0; font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; color: #24292f; }
      ; button { font: 12px -apple-system, BlinkMacSystemFont, sans-serif; padding: 4px 12px; cursor: pointer; color: #24292f; background: #fff; border: 1px solid #d0d7de; border-radius: 7px; }
      ; button:hover { background: #f6f8fa; }
      ; input[type="text"] { font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; padding: 4px 9px; border: 1px solid #d0d7de; border-radius: 7px; outline: none; }
      ; input[type="text"]:focus { border-color: #0969da; }
      ; input[type="file"] { font: 12px -apple-system, sans-serif; color: #57606a; }
      ; select { font: 12px -apple-system, sans-serif; padding: 4px 6px; border: 1px solid #d0d7de; border-radius: 7px; background: #fff; color: #24292f; }
      ; .del-form { display: inline; }
      ; .symlink-target { color: #8b949e; }
      ; .mark-mismatch { color: #cf222e; font-weight: 600; }
      ; details.tools { margin: 0 0 8px; }
      ; details.tools summary { cursor: pointer; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #57606a; user-select: none; padding: 3px 0; width: max-content; }
      ; details.tools summary:hover { color: #24292f; }
      ; details.tools[open] summary { margin-bottom: 8px; }
      ; .action-row { margin: 0 0 7px; display: flex; gap: 8px; align-items: center; }
      ; .action-row label { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; min-width: 110px; }
      ; .inline-form { display: flex; gap: 6px; align-items: center; }
      ; .inline-form input[type="text"] { width: 150px; padding: 4px 9px; font-size: 12px; }
      ; .weir-system { color: #bc4c00; font-weight: 600; }
      ; .weir-label { color: #8b949e; margin-right: 4px; }
      ; .weir-roads { color: #8250df; }
      ; .weir-road-item { margin-right: 8px; }
      ; .weir-del { font-size: 10px; padding: 0 5px; margin-left: 2px; color: #cf222e; cursor: pointer; border-radius: 5px; }
      ; table { border-collapse: collapse; width: calc(100% - 40px); margin: 10px 20px; }
      ; th, td { text-align: left; padding: 7px 10px; }
      ; th { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; border-bottom: 1px solid #d0d7de; }
      ; td { border-bottom: 1px solid #eef1f4; font-size: 13px; }
      ; td a { font: 12.5px ui-monospace, SFMono-Regular, Menlo, monospace; }
      ; td:nth-child(2), td:nth-child(3), td:nth-child(4), td:nth-child(5) { font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; color: #57606a; }
      ; tr:hover td { background: #f6f8fa; }
      ; .sortable { cursor: pointer; user-select: none; }
      ; .sortable:hover { color: #24292f; background: none; }
      ; .sortable::after { content: ' \2195'; opacity: 0.35; }
      ; .sortable.asc::after { content: ' \2191'; opacity: 1; }
      ; .sortable.desc::after { content: ' \2193'; opacity: 1; }
      ; .actions-cell { white-space: nowrap; text-align: right; }
      ; .actions-cell button, .actions-cell .del-form button { padding: 3px 10px; border-color: transparent; background: none; color: #57606a; opacity: 0; transition: opacity .1s; }
      ; tr:hover .actions-cell button { opacity: 1; }
      ; .actions-cell button:hover { background: #eaeef2; color: #24292f; }
      ; .actions-cell .del-form button:hover { background: #ffebe9; color: #cf222e; }
      ; .boom-banner { margin: 12px 20px; padding: 10px 14px; background: #fff8f8; border: 1px solid #ffcecb; border-radius: 8px; cursor: pointer; color: #cf222e; }
      ; .boom-banner:hover { background: #ffebe9; }
      ; .boom-icon { color: #cf222e; font-weight: 600; cursor: pointer; margin-left: 4px; display: inline; }
      ; .boom-icon:hover { text-decoration: underline; }
      ; .boom-modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(31,35,40,0.4); z-index: 1000; }
      ; .boom-modal-overlay.active { display: flex; align-items: center; justify-content: center; }
      ; .boom-modal { background: #fff; border: 1px solid #ffcecb; border-radius: 12px; box-shadow: 0 12px 36px rgba(31,35,40,.22); padding: 18px; max-width: 80vw; max-height: 80vh; overflow: auto; min-width: 400px; }
      ; .boom-modal h3 { color: #cf222e; margin: 0 0 8px; font-size: 14px; }
      ; .boom-modal pre { white-space: pre-wrap; font: 12px/1.5 ui-monospace, Menlo, monospace; margin: 0; max-height: 60vh; overflow: auto; background: #fff8f8; padding: 10px; border-radius: 8px; }
      ; @media (max-width: 768px) {
      ;   .col-blot, .col-mime, .col-mtime { display: none; }
      ;   .action-row { flex-wrap: wrap; }
      ;   .action-row label { min-width: unset; width: 100%; margin-bottom: 4px; }
      ;   .inline-form { flex-wrap: wrap; width: 100%; }
      ;   .inline-form input[type="text"] { width: 100%; min-width: 0; }
      ;   table { font-size: 13px; }
      ;   th, td { padding: 6px 4px; }
      ;   .actions-cell button { opacity: 1; }
      ;   .boom-modal { min-width: unset; width: 90vw; }
      ; }
      ; @media (max-width: 480px) {
      ;   .actions-cell { display: flex; flex-wrap: wrap; gap: 4px; }
      ;   .col-size { display: none; }
      ; }
    ==
  ==
::
++  breadcrumb
  |=  pax=path
  ^-  manx
  =/  seg-data=(list [seg=@ta url=tape])
    =/  built=path  ~
    =/  acc=(list [seg=@ta url=tape])  ~
    =/  rem=path  pax
    |-
    ?~  rem  (flop acc)
    =.  built  (snoc built i.rem)
    =/  url=tape  (build-url built)
    $(rem t.rem, acc [[i.rem url] acc])
  =/  crumbs=(list manx)
    :~  ;a/"/grubbery/ball": /
    ==
  =.  crumbs
    %+  weld  crumbs
    %+  turn  seg-data
    |=  [seg=@ta url=tape]
    ^-  manx
    ;a/"{url}": {(trip seg)}/
  ;div.breadcrumb
    ;*  crumbs
  ==
::
++  dir-info
  |=  [b=ball:tarball url-prefix=tape dir-weir=(unit weir:nexus) pax=path neck-url=(unit tape)]
  ^-  manx
  =/  neck-display=tape
    ?~  fil.b  "-"
    ?~  neck.u.fil.b  "-"
    (trip (spat (rail-to-path:tarball u.neck.u.fil.b)))
  =/  nkids=@ud
    %+  add
      ~(wyt by dir.b)
    ?~(fil.b 0 ~(wyt by contents.u.fil.b))
  =/  download-url=tape  "{url-prefix}?download=tar"
  ;div.info
    ;dl
      ;dt: nexus
      ;dd
        ;*  ?~  neck-url
              :~  ;span: {neck-display}
              ==
            :~  ;a/"{u.neck-url}": {neck-display}
            ==
      ==
      ;dt: items
      ;dd: {(scow %ud nkids)}
      ;dt: sandbox
      ;dd#sandbox-value
        ;*  (render-sandbox dir-weir url-prefix pax)
      ==
    ==
    ;*  ?.  ?=(^ pax)  ~
        :~  ;div.action-row
              ;form.inline-form(method "POST", action url-prefix)
                ;label: Add to Weir:
                ;select(name "category")
                  ;option(value "write"): write
                  ;option(value "poke"): poke
                  ;option(value "read"): read
                ==
                ;input(type "text", name "road-path", placeholder "/path or /path/", required "");
                ;input(type "hidden", name "action", value "add-weir-road");
                ;button(type "submit"): Add
              ==
            ==
        ==
    ;details.tools
    ;summary:  manage
    ;*  ?.  ?&(?=(^ fil.b) ?=(^ neck.u.fil.b))  ~
        :~  ;div.action-row
              ;form.inline-form(method "POST", action url-prefix)
                ;label: Nexus:
                ;input(type "hidden", name "action", value "reload-nexus");
                ;button(type "submit"): Reload
              ==
            ==
        ==
    ;div.action-row
      ;label: Download:
      ;a/"{download-url}"
        ;button(type "button"): Download as Tarball
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix)
        ;label: Create Folder:
        ;input(type "text", name "foldername", placeholder "folder-name", required "");
        ;input(type "hidden", name "action", value "create-folder");
        ;button(type "submit"): Create
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix)
        ;label: Create Symlink:
        ;input(type "text", name "linkname", placeholder "link-name", required "");
        ;input(type "text", name "target", placeholder "target-path", required "");
        ;input(type "hidden", name "action", value "create-symlink");
        ;button(type "submit"): Create
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix, enctype "multipart/form-data")
        ;label: Upload Grub:
        ;input(type "file", name "file");
        ;button(type "submit"): Upload
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix, enctype "multipart/form-data")
        ;label: Upload Grubs:
        ;input(type "file", name "file", multiple "");
        ;button(type "submit"): Upload All
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix, enctype "multipart/form-data")
        ;label: Upload Directory:
        ;input(type "file", name "file", webkitdirectory "", directory "");
        ;button(type "submit"): Upload Directory
      ==
    ==
    ==
  ==
::
++  render-sandbox
  |=  [dir-weir=(unit weir:nexus) url-prefix=tape pax=path]
  ^-  (list manx)
  ?.  ?=(^ pax)
    :~  ;span.weir-system: unrestricted
    ==
  (render-weir dir-weir url-prefix)
::
++  render-weir
  |=  [dir-weir=(unit weir:nexus) url-prefix=tape]
  ^-  (list manx)
  ?~  dir-weir
    :~  ;span.weir-system: unrestricted
    ==
  =/  items=(list manx)
    ;:  weld
      (render-weir-category "write" make.u.dir-weir url-prefix)
      (render-weir-category "poke" poke.u.dir-weir url-prefix)
      (render-weir-category "read" peek.u.dir-weir url-prefix)
    ==
  %+  snoc  items
  ;form.del-form(method "POST", action url-prefix)
    ;input(type "hidden", name "action", value "clear-weir");
    ;button.weir-del(type "submit", onclick "return confirm('Remove weir? This gives unrestricted access.')"): clear weir
  ==
::
++  render-weir-category
  |=  [label=tape roads=(set road:tarball) url-prefix=tape]
  ^-  (list manx)
  =/  road-items=(list manx)
    %+  turn  ~(tap in roads)
    |=  =road:tarball
    ^-  manx
    =/  road-path=tape  (road-to-form road)
    ;span.weir-road-item
      ;span.weir-roads: {road-path}
      ;form.del-form(method "POST", action url-prefix)
        ;input(type "hidden", name "action", value "del-weir-road");
        ;input(type "hidden", name "category", value label);
        ;input(type "hidden", name "road-path", value road-path);
        ;button.weir-del(type "submit"): x
      ==
    ==
  %+  weld
    :~  ;span.weir-label: {label}:
    ==
  ?~  road-items
    :~  ;span.weir-roads: -
        ;br;
    ==
  (snoc road-items ;br;)
::
++  render-road
  |=  =road:tarball
  ^-  tape
  ?-    -.road
      %&  (render-lane p.road)
      %|
    =/  ups=tape  ?:(=(0 p.p.road) "./" (zing (reap p.p.road "../")))
    =/  lane=tape  (render-lane q.p.road)
    ::  strip leading / since ups already provides the prefix
    =/  trimmed=tape  ?:(&(?=(^ lane) =(i.lane '/')) t.lane lane)
    "{ups}{trimmed}"
  ==
::
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
::  +listing-json: the dir listing as data — everything render-dir shows,
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
      ==
  ^-  json
  =/  str  |=(t=tape `json`s+(crip t))
  =/  neck-url=(unit tape)
    ?~  code-namespace  ~
    ?~  fil.b  ~
    ?~  neck.u.fil.b  ~
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
    =/  neck-json=json
      ?~  fil.kid  ~
      ?~  neck.u.fil.kid  ~
      s+(crip (spud (rail-to-path:tarball u.neck.u.fil.kid)))
    (pairs:enjs:format ~[['name' s+`@t`name] ['kind' s+'dir'] ['neck' neck-json]])
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
    ?:  =(%symlink name.p.sag)
      =/  sym  !<(symlink:tarball q.sag)
      %-  pairs:enjs:format
      :~  ['name' s+`@t`name]
          ['kind' s+'symlink']
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
    =/  mark-url=json
      ?~  code-namespace  ~
      =/  mar-path=path
        (weld u.code-namespace (weld /mar (rail-to-path:tarball p.sag)))
      (str "/grubbery/ball{(trip (spat mar-path))}.hoon")
    %-  pairs:enjs:format
    :~  ['name' s+`@t`name]
        ['kind' s+'file']
        ['blot' (str (spud (rail-to-path:tarball p.sag)))]
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
++  render-dir
  |=  $:  pax=path
          b=ball:tarball
          b-wave=wave:nexus
          now=@da
          conversions=(map bars:tarball tube:clay)
          code-namespace=(unit path)
          dir-weir=(unit weir:nexus)
      ==
  ^-  manx
  ::  Nexus source link: combines the governing /code namespace
  ::  with the directory's neck rail to form a URL to the .hoon source.
  ::  e.g. /grubbery/ball/code/nex/wallet/account.hoon
  =/  neck-url=(unit tape)
    ?~  code-namespace  ~
    ?~  fil.b  ~
    ?~  neck.u.fil.b  ~
    `"/grubbery/ball{(trip (spat (weld u.code-namespace /nex)))}{(trip (spat (rail-to-path:tarball u.neck.u.fil.b)))}.hoon"
  =/  path-display=tape
    ?~  pax  "/"
    (trip (spat pax))
  =/  kids  dir.b
  =/  file-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    ?~  fil.b  ~
    contents.u.fil.b
  =/  subdirs=(list @ta)  ~(tap in ~(key by kids))
  =/  files=(list @ta)  ~(tap in ~(key by file-contents))
  =/  url-prefix=tape  (build-url pax)
  ::  Error state at this level
  =/  nexus-bang=(unit tang)  ?~(fil.b ~ bang.u.fil.b)
  ;html
    ;+  (page-head "Index of {path-display}")
    ;body
      ;+  (breadcrumb pax)
      ;h1: Index of {path-display}
      ;+  (dir-info b url-prefix dir-weir pax neck-url)
      ;*  ?~  nexus-bang  ~
          =/  rendered=tape  (render-tang u.nexus-bang)
          :~  ;div.boom-banner(data-tang rendered, onclick "showBoom(this)")
                nexus crashed — click for details
              ==
          ==
      ;table#listing(data-path (trip (spat pax)))
        ;tr
          ;th.sortable(data-col "0", onclick "sortTable(0)"): Name
          ;th.sortable.col-blot(data-col "1", onclick "sortTable(1)"): Blot
          ;th.sortable.col-mime(data-col "2", onclick "sortTable(2)"): Mime Type
          ;th.sortable(data-col "3", onclick "sortTable(3)"): Size
          ;th.sortable.col-mtime(data-col "4", onclick "sortTable(4)"): Modified
          ;th: Actions
        ==
        ;*
        =/  rows=(list manx)  ~
        ::  Parent link
        =?  rows  ?=(^ pax)
          =/  parent=path  (snip `path`pax)
          =/  parent-url=tape  (build-url parent)
          %+  snoc  rows
          ;tr
            ;td
              ;a/"{parent-url}": ../
            ==
            ;td.col-blot: -
            ;td.col-mime: -
            ;td: -
            ;td.col-mtime: -
            ;td: -
          ==
        ::  Subdirectories
        =.  rows
          %+  weld  rows
          %+  turn  subdirs
          |=  name=@ta
          ^-  manx
          =/  sub=ball:tarball  (~(got by kids) name)
          =/  sub-bang=(unit tang)  ?~(fil.sub ~ bang.u.fil.sub)
          (render-dir-row name sub url-prefix sub-bang)
        ::  Grubs
        =.  rows
          %+  weld  rows
          %+  turn  files
          |=  name=@ta
          ^-  manx
          =/  [=sang:tarball gain=? bang=(unit tang)]  (~(got by file-contents) name)
          (render-grub-row name sang url-prefix pax b-wave now conversions code-namespace bang)
        rows
      ==
      ;div#boom-overlay.boom-modal-overlay
        ;div.boom-modal
          ;h3: Error
          ;pre;
        ==
      ==
      ;script: {(trip page-script)}
    ==
  ==
::
++  page-script
  ^-  @t
  '''
  var sortCol = 0, sortAsc = true;
  function getRows() {
    var tbl = document.getElementById('listing');
    return Array.from(tbl.querySelectorAll('tr[data-name]'));
  }
  function sortVal(row, col) {
    if (col === 3) return parseInt(row.dataset.size || '0') || 0;
    return (row.cells[col] && row.cells[col].textContent || '').toLowerCase();
  }
  function doSort() {
    var tbl = document.getElementById('listing');
    var tb = tbl.querySelector('tbody') || tbl;
    var rows = getRows();
    rows.sort(function(a, b) {
      var ta = a.dataset.type || '', tb2 = b.dataset.type || '';
      if (ta !== tb2) { var df = ta === 'dir' ? -1 : 1; return sortAsc ? df : -df; }
      var va = sortVal(a, sortCol), vb = sortVal(b, sortCol);
      var cmp = (typeof va === 'number') ? va - vb : (va < vb ? -1 : va > vb ? 1 : 0);
      return sortAsc ? cmp : -cmp;
    });
    rows.forEach(function(r) { tb.appendChild(r); });
    tbl.querySelectorAll('th.sortable').forEach(function(th) {
      th.classList.remove('asc', 'desc');
      if (parseInt(th.dataset.col) === sortCol) th.classList.add(sortAsc ? 'asc' : 'desc');
    });
  }
  function sortTable(col) {
    if (sortCol === col) { sortAsc = !sortAsc; }
    else { sortCol = col; sortAsc = true; }
    doSort();
  }
  doSort();
  function doAction(action, params) {
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = location.pathname;
    var a = document.createElement('input');
    a.type = 'hidden'; a.name = 'action'; a.value = action;
    form.appendChild(a);
    for (var k in params) {
      var i = document.createElement('input');
      i.type = 'hidden'; i.name = k; i.value = params[k];
      form.appendChild(i);
    }
    document.body.appendChild(form);
    form.submit();
  }
  function renameItem(type, name) {
    var n = prompt('New name for ' + name + ':', name);
    if (!n || n === name) return;
    doAction('rename-' + type, type === 'grub' ? {filename: name, newname: n} : {foldername: name, newname: n});
  }
  function moveItem(type, name) {
    var cur = location.pathname.replace('/grubbery/ball', '') || '/';
    var d = prompt('Move ' + name + ' to (full path):', cur + (cur === '/' ? '' : '/') + name);
    if (!d) return;
    doAction('move-' + type, type === 'grub' ? {filename: name, dest: d} : {foldername: name, dest: d});
  }
  function copyItem(type, name) {
    var cur = location.pathname.replace('/grubbery/ball', '') || '/';
    var d = prompt('Copy ' + name + ' to (full path):', cur + (cur === '/' ? '' : '/') + name);
    if (!d) return;
    doAction('copy-' + type, type === 'grub' ? {filename: name, dest: d} : {foldername: name, dest: d});
  }
  function showBoom(el) {
    var pre = el.dataset.tang;
    var ov = document.getElementById('boom-overlay');
    ov.querySelector('pre').textContent = pre;
    ov.classList.add('active');
  }
  document.addEventListener('click', function(e) {
    var ov = document.getElementById('boom-overlay');
    if (e.target === ov) ov.classList.remove('active');
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') document.getElementById('boom-overlay').classList.remove('active');
  });
  '''
::
++  render-split
  ^-  manx
  ;html
    ;head
      ;title: grubbery split view
      ;meta(charset "utf-8");
      ;link(rel "icon", type "image/svg+xml", href "/grubbery/tiles/icon/explorer.explorer");
      ;style
        ; * { box-sizing: border-box; margin: 0; padding: 0; }
        ; html, body { height: 100%; font-family: monospace; }
        ; .split-header { display: flex; height: 32px; background: #f6f8fa; border-bottom: 1px solid #ccc; }
        ; .pane-bar { display: flex; align-items: center; padding: 0 6px; gap: 4px; }
        ; .pane-bar.left { flex: 1; border-right: 1px solid #ccc; }
        ; .pane-bar.right { flex: 1; }
        ; .pane-bar input { flex: 1; font-family: monospace; font-size: 12px; border: 1px solid #ccc; padding: 2px 6px; min-width: 0; }
        ; .pane-bar button { background: none; border: 1px solid #ccc; cursor: pointer; font-family: monospace; font-size: 12px; padding: 2px 6px; }
        ; .pane-bar button:hover { background: #e1e4e8; }
        ; .split-container { display: flex; height: calc(100% - 32px); }
        ; .split-container iframe { border: none; height: 100%; }
        ; #left-frame { flex: 1; border-right: 1px solid #ccc; }
        ; #right-frame { flex: 1; }
      ==
    ==
    ;body
      ;div.split-header
        ;div.pane-bar.left
          ;button(onclick "goBack('left-frame')"): ←
          ;button(onclick "goFwd('left-frame')"): →
          ;input#left-url(type "text", value "/grubbery/ball", placeholder "/grubbery/ball/...", onkeydown "if(event.key==='Enter')navLeft()");
          ;button(onclick "navLeft()"): go
          ;button(onclick "mirrorRight()"): mirror →
        ==
        ;div.pane-bar.right
          ;button(onclick "goBack('right-frame')"): ←
          ;button(onclick "goFwd('right-frame')"): →
          ;input#right-url(type "text", value "/grubbery/ball", placeholder "/grubbery/ball/...", onkeydown "if(event.key==='Enter')navRight()");
          ;button(onclick "navRight()"): go
          ;button(onclick "mirrorLeft()"): mirror ←
        ==
      ==
      ;div#split.split-container
        ;iframe#left-frame(src "/grubbery/ball");
        ;iframe#right-frame(src "/grubbery/ball");
      ==
      ;script: {(trip split-script)}
    ==
  ==
::
++  split-script
  ^-  @t
  '''
  var hist = { 'left-frame': [], 'right-frame': [] };
  var fwd  = { 'left-frame': [], 'right-frame': [] };
  function navTo(id, inputId, url) {
    var f = document.getElementById(id);
    try { var cur = f.contentWindow.location.href; if (cur && cur !== 'about:blank') hist[id].push(cur); } catch(e) {}
    fwd[id] = [];
    f.src = url;
    document.getElementById(inputId).value = url;
  }
  function navLeft() {
    var url = document.getElementById('left-url').value.trim();
    if (url) navTo('left-frame', 'left-url', url);
  }
  function navRight() {
    var url = document.getElementById('right-url').value.trim();
    if (url) navTo('right-frame', 'right-url', url);
  }
  function mirrorLeft() {
    try {
      var loc = document.getElementById('left-frame').contentWindow.location.href;
      navTo('right-frame', 'right-url', loc);
    } catch(e) {}
  }
  function mirrorRight() {
    try {
      var loc = document.getElementById('right-frame').contentWindow.location.href;
      navTo('left-frame', 'left-url', loc);
    } catch(e) {}
  }
  function goBack(id) {
    if (!hist[id].length) return;
    var inputId = id === 'left-frame' ? 'left-url' : 'right-url';
    var f = document.getElementById(id);
    try { var cur = f.contentWindow.location.href; if (cur && cur !== 'about:blank') fwd[id].push(cur); } catch(e) {}
    var prev = hist[id].pop();
    f.src = prev;
    document.getElementById(inputId).value = prev;
  }
  function goFwd(id) {
    if (!fwd[id].length) return;
    var inputId = id === 'left-frame' ? 'left-url' : 'right-url';
    var f = document.getElementById(id);
    try { var cur = f.contentWindow.location.href; if (cur && cur !== 'about:blank') hist[id].push(cur); } catch(e) {}
    var next = fwd[id].pop();
    f.src = next;
    document.getElementById(inputId).value = next;
  }
  function trackFrame(id, inputId) {
    var frame = document.getElementById(id);
    frame.addEventListener('load', function() {
      try {
        var loc = frame.contentWindow.location.href;
        if (loc && loc !== 'about:blank') {
          document.getElementById(inputId).value = loc;
        }
      } catch(e) {}
    });
  }
  trackFrame('left-frame', 'left-url');
  trackFrame('right-frame', 'right-url');
  '''
::
++  render-tang
  |=  =tang
  ^-  tape
  %-  zing
  %+  turn  (flop tang)
  |=(=tank (weld ~(ram re tank) "\0a"))
::
++  format-size
  |=  n=@ud
  ^-  tape
  ?:  (lth n 1.024)
    "{(scow %ud n)} B"
  ?:  (lth n 1.048.576)
    "{(scow %ud (div n 1.024))} KB"
  "{(scow %ud (div n 1.048.576))} MB"
::
++  render-dir-row
  |=  [name=@ta sub=ball:tarball url-prefix=tape nexus-bang=(unit tang)]
  ^-  manx
  =/  dir-url=tape  "{url-prefix}/{(trip name)}"
  ;tr(data-name (trip name), data-type "dir")
    ;td
      ;a/"{dir-url}": {(trip name)}/
      ;*  ?~  nexus-bang  ~
          =/  rendered=tape  (render-tang u.nexus-bang)
          :~  ;span.boom-icon(data-tang rendered, onclick "showBoom(this)"): !
          ==
    ==
    ;td.col-blot: -
    ;td.col-mime: -
    ;td: -
    ;td.col-mtime: -
    ;td.actions-cell
      ;a/"{dir-url}?download=tar"
        ;button(type "button"): Download
      ==
      ;button(type "button", onclick "renameItem('folder','{(trip name)}')"): Rename
      ;button(type "button", onclick "moveItem('folder','{(trip name)}')"): Move
      ;button(type "button", onclick "copyItem('folder','{(trip name)}')"): Copy
      ;form.del-form(method "POST", action url-prefix)
        ;input(type "hidden", name "action", value "delete-folder");
        ;input(type "hidden", name "foldername", value (trip name));
        ;button(type "submit", onclick "return confirm('Delete folder {(trip name)} and all its contents?')"): Delete
      ==
    ==
  ==
::
++  render-grub-row
  |=  $:  name=@ta
          =sang:tarball
          url-prefix=tape
          pax=path
          dir-wave=wave:nexus
          now=@da
          conversions=(map bars:tarball tube:clay)
          code-namespace=(unit path)
          file-bang=(unit tang)
      ==
  ^-  manx
  =/  mtime-display=tape
    ?~  fil.dir-wave  "-"
    =/  cas=(unit cass:clay)  (~(get by file.u.fil.dir-wave) name)
    ?~  cas  "-"
    (en:datetime-local:iso-8601 da.u.cas)
  =/  display-name=tape  (trip name)
  =/  file-url=tape  "{url-prefix}/{display-name}"
  ::  Boom file: render error row instead of crashing
  ?:  (is-boom:tarball sang)
    =/  boom-tang=tang
      ?~  file-bang  ~[leaf+"validation failed"]
      u.file-bang
    =/  rendered=tape  (render-tang boom-tang)
    ;tr.boom-row(data-name display-name, data-type "grub")
      ;td
        ;a/"{file-url}": {display-name}
        ;span.boom-icon(data-tang rendered, onclick "showBoom(this)"): !
      ==
      ;td.col-blot: {(spud (rail-to-path:tarball p.sang))}
      ;td.col-mime: -
      ;td: -
      ;td.col-mtime: {mtime-display}
      ;td.actions-cell
        ;form.del-form(method "POST", action url-prefix)
          ;input(type "hidden", name "action", value "delete-grub");
          ;input(type "hidden", name "filename", value display-name);
          ;button(type "submit", onclick "return confirm('Delete {display-name}?')"): Delete
        ==
      ==
    ==
  =/  sag=sage:tarball  (need-sage:tarball sang)
  ?:  =(%symlink name.p.sag)
    =/  sym  !<(symlink:tarball q.sag)
    =/  target-display=tape  (trip (encode-symlink:tarball sym))
    =/  resolved-path=path  (resolve-symlink:tarball sym pax)
    =/  target-url=tape  "/grubbery/ball{(trip (spat resolved-path))}"
    ;tr(data-name (trip name), data-type "grub")
      ;td
        ;a/"{target-url}": {(trip name)}
        ;span.symlink-target:  -> {target-display}
      ==
      ;td.col-blot: symlink
      ;td.col-mime: -
      ;td: -
      ;td.col-mtime: {mtime-display}
      ;td.actions-cell
        ;form.del-form(method "POST", action url-prefix)
          ;input(type "hidden", name "action", value "delete-grub");
          ;input(type "hidden", name "filename", value (trip name));
          ;button(type "submit", onclick "return confirm('Delete {(trip name)}?')"): Delete
        ==
      ==
    ==
  =/  mark-name=tape  (spud (rail-to-path:tarball p.sag))
  =/  ext=(unit @ta)  (parse-extension:tarball name)
  =/  rail-ext=@ta
    %-  crip  %-  zing
    %+  join  "_"
    (turn (rail-to-path:tarball p.sag) trip)
  =/  mark-matches=?
    ?~  ext  %.n
    =(u.ext rail-ext)
  =/  mark-class=tape  ?:(mark-matches "" " mark-mismatch")
  =/  =mime
    ?:  =(%mime name.p.sag)
      !<(mime q.sag)
    (~(sage-to-mime gen:tarball [now conversions]) sag)
  =/  mime-raw=tape  (trip (spat p.mime))
  =/  mime-display=tape  ?~(mime-raw "" (tail mime-raw))
  =/  is-binary=?  =(p.mime /application/x-urb-jam)
  =/  view-url=tape  ?:(is-binary "{file-url}?pretty" file-url)
  ;tr(data-name (trip name), data-type "grub", data-size (scow %ud p.q.mime))
    ;td
      ;a/"{view-url}": {display-name}
      ;*  ?~  file-bang  ~
          =/  rendered=tape  (render-tang u.file-bang)
          :~  ;span.boom-icon(data-tang rendered, onclick "showBoom(this)"): !
          ==
    ==
    ::  Blot link: governing /code namespace + /mar/ + blot rail
    ;td.col-blot(class mark-class)
      ;*  =/  mark-url=(unit tape)
            ?~  code-namespace  ~
            =/  mar-path=path  (weld u.code-namespace (weld /mar (rail-to-path:tarball p.sag)))
            `"/grubbery/ball{(trip (spat mar-path))}.hoon"
          ?~  mark-url
            :~  ;span: {mark-name}
            ==
          :~  ;a/"{u.mark-url}": {mark-name}
          ==
    ==
    ;td.col-mime: {mime-display}
    ;td: {(format-size p.q.mime)}
    ;td.col-mtime: {mtime-display}
    ;td.actions-cell
      ;a/"{file-url}"(download display-name)
        ;button(type "button"): Download
      ==
      ;button(type "button", onclick "renameItem('grub','{display-name}')"): Rename
      ;button(type "button", onclick "moveItem('grub','{display-name}')"): Move
      ;button(type "button", onclick "copyItem('grub','{display-name}')"): Copy
      ;form.del-form(method "POST", action url-prefix)
        ;input(type "hidden", name "action", value "delete-grub");
        ;input(type "hidden", name "filename", value (trip name));
        ;button(type "submit", onclick "return confirm('Delete {(trip name)}?')"): Delete
      ==
    ==
  ==
--
