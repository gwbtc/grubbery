::  docs-mirror: shared helpers for the docs-agent tools. The agent reads the
::  shell's LOCAL MIRROR of the documented collection — its code sources at
::  /apps/shell.shell/docs/mirror/<name>/<tag>/… and its handbook prose at
::  /apps/shell.shell/docs/hb/<name>/…. Which collection comes from the registry
::  (targets.json), so the tools name none: register one and its assistant works
::  with no code change. Source paths carry the tag as their first segment
::  (/gub/lib/build.hoon), which is just where that source mounts under the
::  collection mirror. The agent's weir clamps every read to the /docs subtree.
::
|%
::  +mirror-base: the code-source mirror root in the namespace (absolute).
++  mirror-base  `path`/apps/'shell.shell'/docs/mirror
::  +hb-base: the handbook (prose) mirror root in the namespace (absolute).
++  hb-base  `path`/apps/'shell.shell'/docs/hb
::  +targets-road: the registry grub the tools read to resolve the collection.
++  targets-road  `road:tarball`[%& %& /apps/'shell.shell'/docs %'targets.json']
::  +roots-from: the first registered collection's two mirror roots — its SOURCE
::  root (the collection mirror; each source sits under its tag as the first path
::  segment) and its handbook (DOC) root. General to whatever is registered.
++  roots-from
  |=  tg=json
  ^-  (unit [src=path doc=path])
  ?.  ?=([%a *] tg)  ~
  ?~  p.tg  ~
  ?.  ?=([%o *] i.p.tg)  ~
  =/  nm  (~(get by p.i.p.tg) 'name')
  ?.  ?=([~ %s *] nm)  ~
  =/  c=path  ~[p.u.nm]
  `[(welp mirror-base c) (welp hb-base c)]
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
