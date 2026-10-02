::  lanes: the app roots that claim a /sys/link name, earliest claimant
::  first. The shell keeps the order across rebuilds (see +build-links);
::  a resolver takes the head unless the user has chosen otherwise.
::
|_  lanes=(list lane:tarball)
++  grab
  |%
  ++  noun  ,(list lane:tarball)
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
