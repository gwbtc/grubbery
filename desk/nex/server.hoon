::  server nexus: HTTP bindings manager
::
::  Central HTTP gateway between eyre and the rest of the tree.
::  Other nexuses poke to register/unregister URL path bindings,
::  receive forwarded requests, and poke back with responses.
::  Server authorizes every response to ensure it came from the
::  process that owns the binding.
::
::  /server/
::    /main    binding registry + request router + response proxy
::
::  State (server-state in nex-server):
::    bindings:     (map binding:eyre rail) — URL prefix → handler location
::    connections:  (map @ta binding:eyre) — eyre-id → owning binding
::
::  Request flow:
::    1. Eyre sends %handle-http-request to grubbery
::    2. Grubbery forwards to /server/main
::    3. Server finds longest-prefix binding match
::    4. Records connection (eyre-id → binding), forwards to handler rail
::    5. Handler pokes back %server-action [%send eyre-id update]
::    6. Server verifies sender matches handler rail, sends to eyre
::    7. On %kick or %simple, connection is cleaned up
::
::  Cancel flow:
::    1. Eyre on-leave sends %handle-http-cancel
::    2. Server removes connection, forwards cancel to handler rail
::
/+  nexus, tarball, io=fiberio, server, http-utils, nex-server
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      =/  fresh=server-state:nex-server  [%0 ~ ~]
      =/  existing  (~(get ba:tarball ball) [/ %main])
      ?^  existing
        [sand ball]
      =.  ball  (~(put ba:tarball ball) [/ %main] [~ %server-state !>(fresh)])
      [sand ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?.  ?=([~ %main] rail)  stay:m
      ;<  ~  bind:m  (rise-wait:io prod "%server /main: failed, poke to restart")
      ~&  >  "%server /main: ready"
      |-
      ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
      ;<  st=server-state:nex-server  bind:m  (get-state-as:io server-state:nex-server)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ?+    p.cage  $
          ::  Server action: bind, unbind, reset, send
          ::
          %server-action
        =+  !<(act=server-action:nex-server q.cage)
        ?-    -.act
            %bind
          ?.  ?=(%& -.from)  $
          ::  Resolve the target to an absolute rail.
          ::  If target is ~, the sender itself is the handler.
          ::  Otherwise, resolve the target bend relative to the sender.
          ::
          =/  sender-rail=rail:tarball
            (resolve-rail:nex-server here.bowl p.from)
          =/  handler-rail=rail:tarball
            ?~  target.act  sender-rail
            (resolve-rail:nex-server sender-rail u.target.act)
          ~&  >  [%server-bind binding.act handler-rail]
          =.  bindings.st  (~(put by bindings.st) binding.act handler-rail)
          ;<  ~  bind:m  (replace:io !>(st))
          ::  Register with eyre
          ;<  =dude:gall  bind:m  get-agent:io
          ;<  ~  bind:m
            %-  send-cards:io
            [%pass /eyre-bind %arvo %e %connect binding.act dude]~
          $
          ::
            %unbind
          ~&  >  [%server-unbind binding.act]
          ::  Kick orphaned connections for this binding
          =/  orphans=(list @ta)
            %+  murn  ~(tap by connections.st)
            |=  [eid=@ta =binding:eyre]
            ?.  =(binding binding.act)  ~
            `eid
          ;<  ~  bind:m
            %-  send-cards:io
            %+  turn  orphans
            |=  eid=@ta
            [%give %kick ~[/http-response/[eid]] ~]
          =.  connections.st
            %-  ~(gas by *(map @ta binding:eyre))
            %+  skip  ~(tap by connections.st)
            |=  [eid=@ta =binding:eyre]
            =(binding binding.act)
          =.  bindings.st  (~(del by bindings.st) binding.act)
          ;<  ~  bind:m  (replace:io !>(st))
          $
          ::
            %reset
          ~&  >  "%server: resetting all connections"
          =/  conns=(list [@ta binding:eyre])  ~(tap by connections.st)
          ;<  ~  bind:m
            %-  send-cards:io
            %+  turn  conns
            |=  [eid=@ta =binding:eyre]
            [%give %kick ~[/http-response/[eid]] ~]
          ;<  ~  bind:m
            |-
            ?~  conns  (pure:m ~)
            =/  [eid=@ta =binding:eyre]  i.conns
            =/  handler=rail:tarball
              (fall (~(get by bindings.st) binding) *rail:tarball)
            =/  =road:tarball  [%& %& handler]
            ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eid))
            $(conns t.conns)
          =.  connections.st  ~
          ;<  ~  bind:m  (replace:io !>(st))
          $
          ::
            %send
          ::  Authorize: sender must be the handler that owns this binding.
          ::  Resolve sender's from to an absolute rail and compare to the
          ::  stored handler rail.
          ::
          =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id.act)
          ?~  conn-binding
            ~&  >  [%server-unknown-connection eyre-id.act]
            ::  Forward cancel to sender so it can clean up
            ?.  ?=(%& -.from)  $
            =/  sender-rail=rail:tarball
              (resolve-rail:nex-server here.bowl p.from)
            =/  =road:tarball  [%& %& sender-rail]
            ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eyre-id.act))
            $
          =/  expected-rail=(unit rail:tarball)  (~(get by bindings.st) u.conn-binding)
          ?~  expected-rail
            ~&  >  [%server-binding-gone u.conn-binding]
            $
          ?.  ?=(%& -.from)
            ~&  >  [%server-external-from eyre-id.act]
            $
          =/  sender-rail=rail:tarball
            (resolve-rail:nex-server here.bowl p.from)
          ?.  =(sender-rail u.expected-rail)
            ~&  >  [%server-unauthorized eyre-id.act sender-rail u.expected-rail]
            $
          =/  cards=(list card:agent:gall)  (eyre-update-cards eyre-id.act eyre-update.act)
          ?:  ?=(?(%kick %simple) -.eyre-update.act)
            =.  connections.st  (~(del by connections.st) eyre-id.act)
            ;<  ~  bind:m  (replace:io !>(st))
            ;<  ~  bind:m  (send-cards:io cards)
            $
          ;<  ~  bind:m  (send-cards:io cards)
          $
        ==
          ::  Incoming HTTP request from eyre
          ::
          %handle-http-request
        =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
          !<([eyre-id=@ta @p inbound-request:eyre] q.cage)
        ~&  >  [%server-request eyre-id url.request.req]
        =/  =request-line:server  (parse-request-line:server url.request.req)
        =/  match=(unit [=binding:eyre handler=rail:tarball])
          (find-binding bindings.st request-line)
        ?~  match
          ~&  >  [%server-no-binding site.request-line]
          ;<  ~  bind:m
            %-  send-cards:io
            (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
          $
        ~&  >  [%server-found-binding binding.u.match handler.u.match]
        =.  connections.st  (~(put by connections.st) eyre-id binding.u.match)
        ;<  ~  bind:m  (replace:io !>(st))
        ::  Forward request to handler via absolute road
        =/  =road:tarball  [%& %& handler.u.match]
        ;<  ~  bind:m  (poke:io /forward road handle-http-request+!>([eyre-id src req]))
        $
          ::  Client disconnected (eyre on-leave)
          ::
          %handle-http-cancel
        =/  eyre-id=@ta  !<(@ta q.cage)
        ~&  >  [%server-cancel eyre-id]
        =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id)
        =.  connections.st  (~(del by connections.st) eyre-id)
        ;<  ~  bind:m  (replace:io !>(st))
        ::  Forward cancel to handler
        ?~  conn-binding  $
        =/  handler=rail:tarball
          (fall (~(get by bindings.st) u.conn-binding) *rail:tarball)
        =/  =road:tarball  [%& %& handler]
        ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eyre-id))
        $
      ==
    --
|%
::  +find-suffix: returns [~ /tail] if :full is (weld :prefix /tail)
::
++  find-suffix
  |=  [prefix=path full=path]
  ^-  (unit path)
  ?~  prefix  `full
  ?~  full    ~
  ?.  =(i.prefix i.full)  ~
  $(prefix t.prefix, full t.full)
::  +eyre-update-cards: build eyre response cards for an update
::
++  eyre-update-cards
  |=  [eyre-id=@ta upd=eyre-update:nex-server]
  ^-  (list card:agent:gall)
  ?-    -.upd
      %header
    :~  :^  %give  %fact  ~[/http-response/[eyre-id]]
        http-response-header+!>(response-header.upd)
    ==
      %data
    :~  [%give %fact ~[/http-response/[eyre-id]] http-response-data+!>(data.upd)]
    ==
      %kick
    :~  [%give %kick ~[/http-response/[eyre-id]] ~]
    ==
      %simple
    (give-simple-payload:app:server eyre-id simple-payload.upd)
  ==
::  +find-binding: longest-prefix match against registered bindings
::
++  find-binding
  |=  [bindings=(map binding:eyre rail:tarball) =request-line:server]
  ^-  (unit [=binding:eyre handler=rail:tarball])
  =|  best=(unit [=binding:eyre handler=rail:tarball])
  =/  entries=(list [=binding:eyre handler=rail:tarball])
    ~(tap by bindings)
  |-
  ?~  entries  best
  ?~  (find-suffix path.binding.i.entries site.request-line)
    $(entries t.entries)
  ?~  best  $(best `i.entries, entries t.entries)
  ?:  (gth (lent path.binding.i.entries) (lent path.binding.u.best))
    $(best `i.entries, entries t.entries)
  $(entries t.entries)
--
