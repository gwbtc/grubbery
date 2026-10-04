/<  tools  /lib/tools.hoon
::  peek_by_name: peek a grub addressed by its /sys/link NAME, not a path.
::
::    A name resolves through /sys/link to the app root(s) claiming it,
::    earliest first. `path`+`name` address a grub under that root.
::    which='first' (default) reads the default/earliest claimant at full
::    fidelity; which='all' reads every claimant, one text section each.
::    ship (e.g. '~zod') resolves the name on another ship; omit for local.
::
!:
^-  tool:tools
|%
++  name  'peek_by_name'
++  description
  ^~  %-  crip
  ;:  weld
    "Peek a grub by its /sys/link NAME rather than a fixed path. The name "
    "resolves through /sys/link to the app root(s) claiming it (earliest "
    "first); path+name address a grub under that root. which='first' "
    "(default) reads the earliest claimant at full fidelity; which='all' "
    "reads every claimant and returns one section each. ship (e.g. '~zod') "
    "resolves the name on another ship; omit for local. Names live under "
    "/sys/link; browse or peek it to see what's claimed."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['link' [%string 'The /sys/link name, e.g. "@anthropic" or "chat/v1"']]
      ['path' [%string 'Subpath under the claimant root (default "/")']]
      ['name' [%string 'Grub filename under the subpath; omit to peek the directory']]
      ['which' [%string '"first" (default) or "all"']]
      ['ship' [%string 'Resolve the name on another ship, e.g. "~zod" (default: local)']]
  ==
++  required  ~['link']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  a=json  [%o args.st]
  =/  link=(unit @t)  (~(deg jo:json-utils a) /link so:dejs:format)
  ?~  link  (pure:m [%error 'Missing required argument: link'])
  ::  subpath under the claimant root ("" or "/" => the root itself)
  =/  sub=path
    =/  p=@t  (fall (~(deg jo:json-utils a) /path so:dejs:format) '')
    =/  t=tape  (trip p)
    =.  t  ?:(&(?=(^ t) =('/' i.t)) t.t t)
    ?~  t  ~
    (fall (mole |.((stab (crip ['/' t])))) ~)
  =/  fname=(unit @t)  (~(deg jo:json-utils a) /name so:dejs:format)
  =/  which=@t  (fall (~(deg jo:json-utils a) /which so:dejs:format) 'first')
  =/  ship=(unit @p)
    =/  s=(unit @t)  (~(deg jo:json-utils a) /ship so:dejs:format)
    ?~(s ~ (rush u.s ;~(pfix sig fed:ag)))
  ::  the target lane under a claimant root: a file if `name` is given
  =/  at=lane:tarball  ?~(fname [%| sub] [%& sub u.fname])
  ::  build the full road to `at` beneath one claimant root (a %| dir lane)
  =/  road-under
    |=  root=lane:tarball
    ^-  (unit road:tarball)
    ?.  ?=(%| -.root)  ~
    :-  ~
    ?-  -.at
      %&  [%& %& (weld p.root path.p.at) name.p.at]
      %|  [%& %| (weld p.root p.at)]
    ==
  ;<  roots=(list lane:tarball)  bind:m
    ?~  ship  (link-lanes:io u.link)
    (link-lanes-on:io u.ship u.link)
  ?~  roots
    (pure:m [%error (crip "link: no claimant for {(trip u.link)}")])
  ?.  =('all' which)
    ::  first: the earliest claimant, rendered at full fidelity
    =/  rd=(unit road:tarball)  (road-under i.roots)
    ?~  rd  (pure:m [%error 'link: claimant root is not a directory'])
    ;<  =view:nexus  bind:m  (peek:io u.rd ~)
    ?.  ?=([%file *] view)
      (pure:m [%error (crip "no grub at the resolved place for {(trip u.link)}")])
    (render-grub-content:tools view)
  ::  all: one text section per claimant
  =/  rest=(list lane:tarball)  roots
  =|  out=tape
  |-  ^-  form:m
  ?~  rest  (pure:m [%text ?~(out '(no readable claimant)' (crip out))])
  =/  rd=(unit road:tarball)  (road-under i.rest)
  ?~  rd  $(rest t.rest)
  ;<  =view:nexus  bind:m  (peek:io u.rd ~)
  =/  rpath=path  ?-(-.i.rest %| p.i.rest, %& path.p.i.rest)
  =/  head=tape  "=== {(spud rpath)} ===\0a"
  ?.  ?=([%file *] view)
    $(rest t.rest, out :(weld out head "(no grub here)\0a\0a"))
  ;<  res=tool-result:tools  bind:m  (render-grub-content:tools view)
  =/  body=tape
    ?-  -.res
      %text   (trip text.res)
      %error  (weld "ERROR: " (trip message.res))
      %mime   :(weld "(binary " (trip (mite-to-cord:tools p.mime.res)) ")")
    ==
  $(rest t.rest, out :(weld out head body "\0a\0a"))
--
