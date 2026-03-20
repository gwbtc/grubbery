::  server-state: mark for server nexus state
::
/+  nexus, tarball, nex-server
!: :: turn on stack trace
|_  state=server-state:nex-server
++  grad  %noun
++  grow
  |%
  ++  noun  state
  ++  json
    ^-  ^json
    =/  bindings-list=(list [=binding:eyre handler=rail:tarball])
      ~(tap by bindings.state)
    =/  connections-list=(list [@ta =binding:eyre])
      ~(tap by connections.state)
    %-  pairs:enjs:format
    :~  :-  'bindings'
        :-  %a
        %+  turn  bindings-list
        |=  [=binding:eyre handler=rail:tarball]
        %-  pairs:enjs:format
        :~  ['site' ?~(site.binding s+'~' s+u.site.binding)]
            ['path' s+(spat path.binding)]
            :-  'handler'
            %-  pairs:enjs:format
            :~  ['path' s+(spat path.handler)]
                ['name' s+name.handler]
            ==
        ==
      ::
        :-  'connections'
        :-  %a
        %+  turn  connections-list
        |=  [eyre-id=@ta =binding:eyre]
        %-  pairs:enjs:format
        :~  ['eyre-id' s+eyre-id]
            ['site' ?~(site.binding s+'~' s+u.site.binding)]
            ['path' s+(spat path.binding)]
        ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  grab
  |%
  ++  noun  server-state:nex-server
  --
--
