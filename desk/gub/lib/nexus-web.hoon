::  lib/nexus-web: the helpers every web-serving nexus was copying.
::
::  Three groups:
::
::    json accessors   +jget +jnum +post-json
::    ball views       +count-files +file-entries +call-status
::    poke attribution +caller-path +resolve-up
::    eyre replies     +web, a door over the nexus's web.sig road:
::                     +reply +send-json +serve-static
::
::  A nexus imports it and keeps one-line shims so its call sites read
::  as before:
::
::    /<  nw  /lib/nexus-web.hoon
::    ...
::    ++  reply         reply:web:nw
::    ++  reply         reply:web
::    ++  send-json     send-json:web
::    ++  serve-static  serve-static:web
::    ++  jget          jget:nw
::
|%
::  +jget: string field or ''
::
++  jget
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  v  (~(get by p.jon) k)
  ?.(?=([~ %s *] v) '' p.u.v)
::  +jnum: number field or the default
::
++  jnum
  |=  [jon=json k=@t d=@ud]
  ^-  @ud
  ?.  ?=(%o -.jon)  d
  =/  v  (~(get by p.jon) k)
  ?.  ?=([~ %n *] v)  d
  (fall (rush p.u.v dem) d)
::  +post-json: the parsed body of a POST, or ~
::
++  post-json
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?.  =(%'POST' method.request.req)  ~
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
::  +count-files: how many files a %ball view holds
::
++  count-files
  |=  =view:nexus
  ^-  @ud
  ?.  ?=([%ball *] view)  0
  ?~  fil.ball.view  0
  ~(wyt by contents.u.fil.ball.view)
::  +file-entries: [name sang] per file in a %ball view
::
++  file-entries
  |=  =view:nexus
  ^-  (list [@ta sang:tarball])
  ?.  ?=([%ball *] view)  ~
  ?~  fil.ball.view  ~
  %+  turn  ~(tap by contents.u.fil.ball.view)
  |=  [nam=@ta ent=[=sang:tarball *]]
  [nam sang.ent]
::  +call-status: the `status` string of a json lifecycle grub, or ''
::
++  call-status
  |=  =sang:tarball
  ^-  @t
  =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang))))
  ?~  jon  ''
  ?.  ?=(%o -.u.jon)  ''
  (jget u.jon 'status')
::  +caller-path: a poke's from is a bend relative to this grub. Render
::  it absolute when our %here walk reached root; otherwise relative,
::  one ../ per step up, so a weir-blocked walk still yields an honest
::  path instead of a crash.
::
++  caller-path
  |=  [loc=here:nexus =from:fiber:nexus]
  ^-  @t
  =/  tail=path  (snoc path.q.from name.q.from)
  ?:  root.loc
    =/  base=path  path:(coerce-here:io loc)
    (crip (spud (weld (resolve-up base p.from) tail)))
  =/  rel=tape  (slag 1 (spud tail))
  =/  up=@ud  p.from
  |-  ^-  @t
  ?:  =(0 up)  (crip rel)
  $(up (dec up), rel (weld "../" rel))
::
++  resolve-up
  |=  [base=path up=@ud]
  ^-  path
  ?:  =(0 up)  base
  ?~  base  ~
  $(up (dec up), base (snip `path`base))
::  +web: eyre replies, a step above +http-res:io.
::
++  web
  |%
  ++  reply
    |=  [eyre-id=@ta code=@ud msg=@t]
    (send-simple:http-res:io eyre-id [[code ~] `(as-octs:mimes:html msg)])
  ++  send-json
    |=  [eyre-id=@ta jon=json]
    =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
    (send-simple:http-res:io eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  ::  +serve-file: a %mime grub of this nexus as the response, named by
  ::  its dir under the nexus root and its filename, or a 404. Called
  ::  from a request fiber, one dir below the root.
  ::
  ++  serve-file
    |=  [eyre-id=@ta dir=path filename=@ta]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  v=view:nexus  bind:m  (peek:io [%| 1 %& dir filename] `[/ %mime])
    ?.  ?=([%file *] v)  (reply eyre-id 404 'Not found')
    =/  =mime  !<(mime (need-vase:tarball sang.v))
    (send-simple:http-res:io eyre-id (mime-response:http-utils mime))
  ::  +serve-static: a file at the nexus root, index.html by default
  ::
  ++  serve-static
    |=  [eyre-id=@ta suffix=path]
    (serve-file eyre-id / ?~(suffix 'index.html' i.suffix))
  ::  +send-to-kernel: a file of this nexus is the kernel's to serve, at
  ::  /grubbery/api/peek under its absolute path, which its link name
  ::  finds. A 307 keeps the browser's url and is transparent to fetch
  ::  and script tags. The kernel answers 404 for a file it does not have.
  ::
  ++  send-to-kernel
    |=  [eyre-id=@ta name=@t file=path]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io name)
    ?.  ?=([~ %| *] root)  (reply eyre-id 404 'Not found')
    =/  loc=@t  (crip "/grubbery/api/peek{(spud p.u.root)}{(spud file)}")
    (send-simple:http-res:io eyre-id [[307 ~[['location' loc]]] ~])
  --
--
