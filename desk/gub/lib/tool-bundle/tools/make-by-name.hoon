/<  tools  /lib/tools.hoon
::  make_by_name: make a grub addressed by its /sys/link NAME, not a path.
::
::    The name resolves through /sys/link to the app root(s) claiming it.
::    path+name address the grub to create under that root; content is
::    stored as a json grub. which='first' (default) makes under the
::    earliest claimant; which='all' makes under every claimant (seed the
::    same grub into each instance of a service), reporting each ok/nack —
::    a claimant that already holds the file nacks. ship (e.g. '~zod')
::    targets a name on another ship; omit for local.
::
!:
^-  tool:tools
|%
++  name  'make_by_name'
++  description
  ^~  %-  crip
  ;:  weld
    "Make (create) a grub by its /sys/link NAME rather than a fixed path. "
    "The name resolves through /sys/link to the app root(s) claiming it; "
    "path+name address the grub under that root, stored as a json grub. "
    "which='first' (default) makes under the earliest claimant; which='all' "
    "makes under every claimant (seed the same grub into each), reporting "
    "each ok/nack — a claimant already holding the file nacks. ship (e.g. "
    "'~zod') targets a name on another ship; omit for local. Names live "
    "under /sys/link; browse or peek it to see what's claimed."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['link' [%string 'The /sys/link name, e.g. "@anthropic" or "chat/v1"']]
      ['path' [%string 'Subpath under the claimant root (default "/")']]
      ['name' [%string 'Grub filename to create under the subpath']]
      ['content' [%string 'JSON content for the new grub']]
      ['which' [%string '"first" (default) or "all"']]
      ['ship' [%string 'Target the name on another ship, e.g. "~zod" (default: local)']]
  ==
++  required  ~['link' 'name' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  a=json  [%o args.st]
  =/  link=(unit @t)   (~(deg jo:json-utils a) /link so:dejs:format)
  =/  fname=(unit @t)  (~(deg jo:json-utils a) /name so:dejs:format)
  =/  cont=(unit @t)   (~(deg jo:json-utils a) /content so:dejs:format)
  ?~  link   (pure:m [%error 'Missing required argument: link'])
  ?~  fname  (pure:m [%error 'Missing required argument: name'])
  ?~  cont   (pure:m [%error 'Missing required argument: content'])
  =/  jon=(unit json)  (de:json:html u.cont)
  ?~  jon  (pure:m [%error 'Failed to parse content as JSON'])
  =/  sub=path
    =/  p=@t  (fall (~(deg jo:json-utils a) /path so:dejs:format) '')
    =/  t=tape  (trip p)
    =.  t  ?:(&(?=(^ t) =('/' i.t)) t.t t)
    ?~  t  ~
    (fall (mole |.((stab (crip ['/' t])))) ~)
  =/  which=@t  (fall (~(deg jo:json-utils a) /which so:dejs:format) 'first')
  =/  ship=(unit @p)
    =/  s=(unit @t)  (~(deg jo:json-utils a) /ship so:dejs:format)
    ?~(s ~ (rush u.s ;~(pfix sig fed:ag)))
  =/  mak=make:nexus  |+[[[/ %json] u.jon] ~]
  ::  the file road beneath one claimant root (a %| dir lane)
  =/  road-under
    |=  root=lane:tarball
    ^-  (unit road:tarball)
    ?.  ?=(%| -.root)  ~
    `[%& %& (weld p.root sub) u.fname]
  ;<  roots=(list lane:tarball)  bind:m
    ?~  ship  (link-lanes:io u.link)
    (link-lanes-on:io u.ship u.link)
  ?~  roots
    (pure:m [%error (crip "link: no claimant for {(trip u.link)}")])
  ?.  =('all' which)
    ::  first: the earliest claimant
    =/  rd=(unit road:tarball)  (road-under i.roots)
    ?~  rd  (pure:m [%error 'link: claimant root is not a directory'])
    ;<  err=(unit tang)  bind:m  (make-soft:io u.rd mak)
    ?~  err  (pure:m [%text (crip "made {(trip u.fname)} under {(trip u.link)}")])
    (pure:m [%error (crip "make nacked by {(trip u.link)}: {(zing (turn (flop u.err) |=(=tank (weld ~(ram re tank) " "))))}")])
  ::  all: make under every claimant, one line each
  =/  rest=(list lane:tarball)  roots
  =|  out=tape
  |-  ^-  form:m
  ?~  rest  (pure:m [%text ?~(out '(no claimant made)' (crip out))])
  =/  rd=(unit road:tarball)  (road-under i.rest)
  ?~  rd  $(rest t.rest)
  =/  rpath=path  ?-(-.i.rest %| p.i.rest, %& path.p.i.rest)
  ;<  err=(unit tang)  bind:m  (make-soft:io u.rd mak)
  =/  line=tape  "{(spud rpath)}: {?~(err "ok" "NACK")}\0a"
  $(rest t.rest, out (weld out line))
--
