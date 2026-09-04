::  web-test nexus: bouncing balls — html, css, js all as files
::
/&  bounce-html  web-test/bounce.html
/&  bounce-css   web-test/bounce.css
/&  bounce-js    web-test/bounce.js
::  web-component kit: shared sources in /lib/ui, imported by every nexus that
::  uses them (no per-nexus copies). icons.svg + demo.html stay local.
/&  sv-js        /lib/ui/split-view.js
/&  tg-js        /lib/ui/tab-group.js
/&  md-js        /lib/ui/modal-dialog.js
/&  dm-js        /lib/ui/drop-menu.js
/&  wm-js        /lib/ui/window-manager.js
/&  fw-js        /lib/ui/float-window.js
/&  db-js        /lib/ui/desk-bar.js
/&  sm-js        /lib/ui/start-menu.js
/&  icons-svg    web-test/ui/icons.svg
/&  demo-html    web-test/ui/demo.html
/&  desk-html    web-test/ui/desktop.html
/&  mi-json      web-test/ui/mark-icons.json
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  ::  kit bundle: weld the component modules into ONE served file so a page
  ::  makes a single request (each per-file fetch costs ~400-600ms on the
  ::  pier, and staggered upgrades cause a piece-by-piece "flash-in"). The
  ::  nexus build IS the bundler — no external toolchain. Each file is wrapped
  ::  in a { } block so its top-level `const TPL`/class don't collide across
  ::  files; customElements.define still runs (global side effect).
  ::  123={  125=}  10=newline.
  =/  wrap
    |=  =mime  ^-  @
    (rap 3 ~[123 10 q.q.mime 10 125 10])
  =/  kit-js=mime
    :-  /application/javascript
    %-  as-octs:mimes:html
    ::  order matters: window-manager must precede float-window (hard dep)
    (rap 3 ~[(wrap sv-js) (wrap tg-js) (wrap dm-js) (wrap md-js) (wrap wm-js) (wrap fw-js) (wrap db-js) (wrap sm-js)])
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'bounce.html'] [[/ %mime] bounce-html]]
      [%over %& [/ %'bounce.css'] [[/ %mime] bounce-css]]
      [%over %& [/ %'bounce.js'] [[/ %mime] bounce-js]]
      [%fall %| /ui empty-dir:loader]
      [%over %& [/ui %'split-view.js'] [[/ %mime] sv-js]]
      [%over %& [/ui %'tab-group.js'] [[/ %mime] tg-js]]
      [%over %& [/ui %'modal-dialog.js'] [[/ %mime] md-js]]
      [%over %& [/ui %'drop-menu.js'] [[/ %mime] dm-js]]
      [%over %& [/ui %'window-manager.js'] [[/ %mime] wm-js]]
      [%over %& [/ui %'float-window.js'] [[/ %mime] fw-js]]
      [%over %& [/ui %'desk-bar.js'] [[/ %mime] db-js]]
      [%over %& [/ui %'start-menu.js'] [[/ %mime] sm-js]]
      [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
      [%over %& [/ui %'icons.svg'] [[/ %mime] icons-svg]]
      [%over %& [/ui %'demo.html'] [[/ %mime] demo-html]]
      [%over %& [/ui %'desktop.html'] [[/ %mime] desk-html]]
      [%over %& [/ui %'mark-icons.json'] [[/ %mime] mi-json]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  /main.sig: bind HTTP and dispatch
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%web-test /main: failed")
    ;<  ~  bind:m  (bind-http:io [~ /grubbery/web-test])
    (http-dispatch:io %web-test)
      ::  /requests/*: serve files
      ::
      [[%requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%web-test /requests: failed")
    =/  srv  ~(. http-res:io (nex-road:io rail [%& ~ %'main.sig']))
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
    ;<  our=@p  bind:m  get-our:io
    ?.  =(src our)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
      (pure:m ~)
    =/  prefix=path  /grubbery/web-test
    =/  site=path  site:(parse-url:http-utils url.request.req)
    =/  suffix=path  (slag (lent prefix) site)
    ::  /desktop.json: live listing of /docs/desktop for the desktop UI.
    ::  Same conventions as the shell's read-app-tiles: a child dir with
    ::  tile.json/icon.* presents as an app (tile metadata + icon face);
    ::  everything else is a plain dir or file. Creates /docs/desktop on
    ::  first read so the desktop always has somewhere real to look.
    ?:  ?=([%'desktop.json' ~] suffix)
      =/  base=path  /docs/desktop
      ;<  dv=view:nexus  bind:m  (peek-shallow:io [%& %| base] ~)
      ;<  dv=view:nexus  bind:m
        =/  m  (fiber:fiber:nexus ,view:nexus)
        ^-  form:m
        ?:  ?=([%ball *] dv)  (pure:m dv)
        ;<  ~  bind:m
          (make:io [%& %| base] &+(ball-to-bole:tarball `ball:tarball`[`[~ ~ %.n ~ ~] ~]))
        (peek-shallow:io [%& %| base] ~)
      ?.  ?=([%ball *] dv)
        ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'desktop unavailable')])
        (pure:m ~)
      =/  subs=(list @ta)  (sort ~(tap in ~(key by dir.ball.dv)) aor)
      =/  fils=(list @ta)
        ?~  fil.ball.dv  ~
        %+  sort
          %+  murn  ~(tap by contents.u.fil.ball.dv)
          |=  [n=@ta s=sang:tarball g=? b=(unit tang)]
          ^-  (unit @ta)
          ?:  (is-boom:tarball s)  ~
          `n
        aor
      =|  kids=(list json)
      |-
      ?^  subs
        =/  name=@ta  i.subs
        ;<  tv=view:nexus  bind:m
          (peek:io [%& %& (snoc base name) %'tile.json'] `[/ %json])
        =/  tile-jon=json
          ?.  ?=([%file *] tv)  ~
          (fall (mole |.(!<(json (need-vase:tarball sang.tv)))) ~)
        ;<  rv=view:nexus  bind:m  (peek-shallow:io [%& %| (snoc base name)] ~)
        =/  icon=(unit @ta)
          ?.  ?=([%ball *] rv)  ~
          ?~  fil.ball.rv  ~
          %-  ~(rep by contents.u.fil.ball.rv)
          |=  [[n=@ta s=sang:tarball g=? b=(unit tang)] out=(unit @ta)]
          ?^  out  out
          ?.  =("icon." (scag 5 (trip n)))  out
          ?:  (is-boom:tarball s)  out
          `n
        =/  kid=json
          %-  pairs:enjs:format
          :~  ['name' s+`@t`name]
              ['kind' s+'dir']
              ['tile' tile-jon]
              ['icon' ?~(icon ~ s+`@t`u.icon)]
          ==
        $(subs t.subs, kids [kid kids])
      =/  fkids=(list json)
        %+  turn  fils
        |=  nam=@ta
        ^-  json
        (pairs:enjs:format ~[['name' s+`@t`nam] ['kind' s+'file'] ['tile' ~] ['icon' ~]])
      =/  out=json  (pairs:enjs:format ~[['children' a+(weld (flop kids) fkids)]])
      =/  bod=octs  (as-octs:mimes:html (en:json:html out))
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
      (pure:m ~)
    ::  resolve nested paths: split into [dir file] so /ui/split-view.js
    ::  serves the grub at [/ui %'split-view.js'], not a flat filename.
    ::  snag/scag take any list (no lest proof needed); guard on length
    ::  so we never index an empty path. last element = filename, rest = dir.
    =/  n=@  (lent suffix)
    =/  file=@ta  ?:(=(0 n) 'bounce.html' (snag (dec n) `(list @ta)`suffix))
    =/  dir=path  ?:(=(0 n) / (scag (dec n) suffix))
    ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%& dir file]) `[/ %mime])
    ?.  ?=([%file *] view)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
      (pure:m ~)
    =/  =mime  !<(mime (need-vase:tarball sang.view))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
    (pure:m ~)
  ==
--
