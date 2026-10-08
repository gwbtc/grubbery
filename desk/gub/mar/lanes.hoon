::  lanes: the app roots that claim a /sys/link name, earliest claimant
::  first. The shell keeps the order across rebuilds (see +build-links);
::  a resolver takes the head unless the user has chosen otherwise.
::
::  As json (and as mime, which is the json text): an array of paths. A
::  path whose last segment has a dot is a file lane (/apps/x/main.sig),
::  any other a directory lane (/apps/x) — the same reading the weir and
::  peers text forms use. Reading and writing are symmetric, so a lanes
::  grub can be written from json (the MCP's write_grub with blot /lanes).
::
|_  lanes=(list lane:tarball)
++  grab
  |%
  ++  noun  ,(list lane:tarball)
  ++  json
    |=  jon=^json
    ^-  (list lane:tarball)
    ?.  ?=([%a *] jon)  ~
    %+  murn  p.jon
    |=  j=^json
    ^-  (unit lane:tarball)
    ?.  ?=([%s *] j)  ~
    =/  pax=(unit path)  (rush p.j stap)
    ?~  pax  ~
    ?~  u.pax  `[%| /]
    =/  last=tape  (trip (rear u.pax))
    ?~  (find "." last)  `[%| u.pax]
    `[%& (snip `path`u.pax) (rear u.pax)]
  ++  mime
    |=  [=mite len=@ud tex=@t]
    ^-  (list lane:tarball)
    =/  jon=(unit ^json)  (de:json:html tex)
    ?~  jon  ~
    (json u.jon)
  --
++  grow
  |%
  ++  noun  lanes
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  lanes
    |=  =lane:tarball
    s+(crip ?-(-.lane %& (spud (snoc path.p.lane name.p.lane)), %| (spud p.lane)))
  ++  mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
