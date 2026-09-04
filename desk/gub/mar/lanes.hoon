|_  lanes=(set lane:tarball)
++  grab
  |%
  ++  noun  ,(set lane:tarball)
  --
++  grow
  |%
  ++  noun  lanes
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  ~(tap in lanes)
    |=  =lane:tarball
    s+(crip ?-(-.lane %& (spud (snoc path.p.lane name.p.lane)), %| (spud p.lane)))
  ++  mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
