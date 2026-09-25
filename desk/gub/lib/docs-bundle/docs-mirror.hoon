::  docs-mirror: shared helpers for the docs-agent tools. The agent reads the
::  shell's LOCAL MIRROR of each documented target — a copy the shell keeps at
::  /apps/shell.shell/docs/mirror/<target>. Which target(s) to read comes from
::  the registry (targets.json), so the tools name no specific collection: add a
::  target and its assistant works with no code change. The agent's weir clamps
::  every read here to the /docs subtree.
::
|%
::  +mirror-base: the mirror root in the namespace (absolute).
++  mirror-base  `path`/apps/'shell.shell'/docs/mirror
::  +targets-road: the registry grub the tools read to resolve collections.
++  targets-road  `road:tarball`[%& %& /apps/'shell.shell'/docs %'targets.json']
::  +roots-from: the current collection's mirror roots parsed from targets.json —
::  its whole-target SOURCE root and its handbook (DOC) root. Takes the first
::  registered entry: one collection today, general to whatever is registered.
::  docs subpath defaults to /man/docs when an entry omits it.
++  roots-from
  |=  tg=json
  ^-  (unit [src=path doc=path])
  ?.  ?=([%a *] tg)  ~
  ?~  p.tg  ~
  ?.  ?=([%o *] i.p.tg)  ~
  =/  cp  (~(get by p.i.p.tg) 'path')
  ?.  ?=([~ %s *] cp)  ~
  =/  dp  (~(get by p.i.p.tg) 'docs')
  =/  c=path  (stab p.u.cp)
  =/  d=path  ?:(?=([~ %s *] dp) (stab p.u.dp) /man/docs)
  =/  src=path  (welp mirror-base c)
  `[src (welp src d)]
::  +is-md: a handbook page (not the docs.json manifest beside it in man/docs).
++  is-md
  |=  n=@ta
  ^-  ?
  =/  t=tape  (trip n)
  =/  l=@ud  (lent t)
  ?:  (lth l 4)  |
  =(".md" (slag (sub l 3) t))
::  +src-of: the text of a searchable/readable grub, or ~ (booms, binaries).
::  Handles the mark variety the mirror holds: %hoon (@t), %md/%txt (a wain),
::  %json (re-encoded). Anything else (images, sigs) is not text.
++  src-of
  |=  =sang:tarball
  ^-  (unit @t)
  ?:  (is-boom:tarball sang)  ~
  ?+  name.p.sang  ~
    %hoon  (mole |.(!<(@t (need-vase:tarball sang))))
    %txt   (mole |.((of-wain:format !<(wain (need-vase:tarball sang)))))
    %md    (mole |.((of-wain:format !<(wain (need-vase:tarball sang)))))
    %json  (mole |.((en:json:html !<(json (need-vase:tarball sang)))))
  ==
--
