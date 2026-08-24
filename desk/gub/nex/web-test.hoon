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
/&  icons-svg    web-test/ui/icons.svg
/&  demo-html    web-test/ui/demo.html
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
    (rap 3 ~[(wrap sv-js) (wrap tg-js) (wrap dm-js) (wrap md-js)])
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
      [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
      [%over %& [/ui %'icons.svg'] [[/ %mime] icons-svg]]
      [%over %& [/ui %'demo.html'] [[/ %mime] demo-html]]
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
