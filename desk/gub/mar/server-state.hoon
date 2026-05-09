::  server-state: HTTP binding registry + active connections
::
|_  st=server-state:nexus
++  grow
  |%
  ++  noun  st
  ++  json
    ^-  ^json
    %-  pairs:enjs:format
    :~  ['version' (numb:enjs:format 0)]
        ['binding-count' (numb:enjs:format ~(wyt by bindings.st))]
        :-  'bindings'
        :-  %a
        %+  turn  ~(tap by bindings.st)
        |=  [=binding:eyre handler=rail:tarball]
        %-  pairs:enjs:format
        :~  ['site' ?~(site.binding ~ s+u.site.binding)]
            ['path' s+(spat path.binding)]
            ['handler' s+(spat (snoc path.handler name.handler))]
        ==
        ['conn-count' (numb:enjs:format ~(wyt by conns.st))]
        :-  'conns'
        :-  %a
        %+  turn  ~(tap by conns.st)
        |=  [eyre-id=@ta =binding:eyre]
        %-  pairs:enjs:format
        :~  ['eyre-id' s+eyre-id]
            ['path' s+(spat path.binding)]
        ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grab
  |%
  ++  noun  server-state:nexus
  --
--
