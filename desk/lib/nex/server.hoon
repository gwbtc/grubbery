::  lib/nex/server: shared types + helpers for the server nexus protocol
::
::  Used by nexuses that communicate with the server nexus
::  (binding HTTP paths, sending responses, dispatching requests).
::
/+  nexus, tarball, io=fiberio
|%
::  Consolidated poke type for the server nexus
::
::  %bind: register a URL prefix → handler mapping.  The target bend
::    is resolved relative to the sender's position to produce an
::    absolute rail stored in the bindings map.  If target is ~,
::    the sender itself is the handler.
::  %unbind: remove a URL prefix binding.
::  %reset: kick all eyre connections and cancel to handlers.
::  %send: forward a response from a handler back through eyre.
::
+$  server-action
  $%  [%bind =binding:eyre target=(unit bend:fiber:nexus)]
      [%unbind =binding:eyre]
      [%reset ~]
      [%send eyre-id=@ta =eyre-update]
  ==
::
+$  eyre-update
  $%  [%header =response-header:http]
      [%data data=(unit octs)]
      [%kick ~]
      [%simple =simple-payload:http]
  ==
::  Server state (versioned for migration)
::
::  bindings: URL prefix → absolute rail of the handler process.
::    Computed at bind time by resolving the sender's from + target bend
::    into an absolute position in the tree.
::
::  connections: eyre-id → the binding that owns it.  Used to
::    (1) authorize responses — the server checks that a %send-action
::    came from the process that owns the binding, preventing one nexus
::    from responding to another's connections — and (2) clean up on
::    unbind or cancel by knowing which connections to kick and which
::    handler to notify.
::
+$  server-state
  $:  %0
      bindings=(map binding:eyre rail:tarball)
      connections=(map @ta binding:eyre)
  ==
::  Absolute road to /server/main
::
++  server-road  `road:tarball`[%& %& /server %main]
::  Register an eyre binding with the server nexus.
::  Target defaults to the sender (the calling process).
::
++  bind-http
  |=  =binding:eyre
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /bind server-road server-action+!>([%bind binding ~]))
::  Register an eyre binding targeting a specific process.
::  The target bend is relative to the calling process.
::
++  bind-http-to
  |=  [=binding:eyre =bend:fiber:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /bind server-road server-action+!>([%bind binding `bend]))
::  HTTP response helpers, parameterized on dispatcher road.
::  Usage: =/  srv  ~(. res:nex-server [%| 1 %& ~ %main])
::         (send-simple:srv eyre-id payload)
::
++  res
  |_  main=road:tarball
  ++  send
    |=  [eyre-id=@ta =eyre-update]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (poke:io /send main server-action+!>([%send eyre-id eyre-update]))
  ::
  ++  send-simple
    |=  [eyre-id=@ta =simple-payload:http]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (send eyre-id %simple simple-payload)
  ::
  ++  send-header
    |=  [eyre-id=@ta =response-header:http]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (send eyre-id %header response-header)
  ::
  ++  send-data
    |=  [eyre-id=@ta data=(unit octs)]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (send eyre-id %data data)
  ::
  ++  send-kick
    |=  eyre-id=@ta
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    (send eyre-id %kick ~)
  --
::  Standard HTTP dispatcher loop for nexuses with /requests/ sub-dir.
::  Spawns per-request processes, forwards responses, handles cancels.
::
++  http-dispatch
  |=  label=@tas
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
  ?+    p.cage  $
      %handle-http-request
    =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
      !<([eyre-id=@ta @p inbound-request:eyre] q.cage)
    ~&  >  [label %dispatch eyre-id url.request.req]
    ;<  ~  bind:m  (make:io /make [%| 0 %& /requests eyre-id] |+[http-request+!>([src req]) ~])
    $
      %server-action
    ;<  ~  bind:m  (poke:io /send server-road cage)
    $
      %handle-http-cancel
    =/  eyre-id=@ta  !<(@ta q.cage)
    ~&  >  [label %cancel eyre-id]
    ;<  ~  bind:m  (cull:io /cancel [%| 0 %& /requests eyre-id])
    $
  ==
::  Resolve a fiber bend to an absolute rail, given the resolver's
::  own position (here) and the bend to resolve.
::
::  A bend is [steps-up=@ud =rail:tarball].  We go up steps-up
::  directory levels from here's parent directory, then append
::  the bend's target path and name.
::
++  resolve-rail
  |=  [here=rail:tarball =bend:fiber:nexus]
  ^-  rail:tarball
  =/  base=path  path.here
  =/  up=@ud  p.bend
  =/  resolved=path
    |-
    ?:  =(0 up)  base
    ?~  base  ~
    $(up (dec up), base (snip `path`base))
  [(weld resolved path.q.bend) name.q.bend]
--
