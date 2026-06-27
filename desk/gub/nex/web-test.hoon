::  web-test nexus: bouncing balls — html, css, js all as files
::
/&  bounce-html  web-test/bounce.html
/&  bounce-css   web-test/bounce.css
/&  bounce-js    web-test/bounce.js
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  =ver:loader  (get-ver:loader ball)
  ?+  ver  !!
      ?(~ [~ %0])
    %+  spin:loader  ball
    :~  (ver-row:loader 0)
        [%over %& [/ %'bounce.html'] [[/ %mime] bounce-html]]
        [%over %& [/ %'bounce.css'] [[/ %mime] bounce-css]]
        [%over %& [/ %'bounce.js'] [[/ %mime] bounce-js]]
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
    =/  filename=@ta
      ?~  suffix  'bounce.html'
      i.suffix
    ;<  =seen:nexus  bind:m  (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
    ?.  ?=([%& %file *] seen)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
      (pure:m ~)
    =/  =mime  !<(mime (need-vase:tarball sang.p.seen))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
    (pure:m ~)
  ==
--
