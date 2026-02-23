::  tools nexus: tool execution engine
::
::  Tree layout:
::    /main             dispatcher — receives %tool-execute pokes
::    /requests/{id}    ephemeral execution processes
::    /tools/{name}     user .hoon tool files (compiled to $tool)
::
/+  nexus, tarball, io=fiberio, tools=nex-tools
!: :: turn on stack trace
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  ::  Create /main file if not present
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
  ::  Create /requests directory
  =?  ball  =(~ (~(get of ball) /requests))
    (~(put of ball) /requests [~ ~ ~])
  ::  Create /tools directory for user .hoon tool files
  =?  ball  =(~ (~(get of ball) /tools))
    (~(put of ball) /tools [~ ~ ~])
  [sand ball]
::
++  on-file
  |=  [=rail:tarball =mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
  ::  /main: dispatcher — receives %tool-execute, spawns /requests/{id}
      [~ %main]
    ;<  ~  bind:m  (rise-wait:io prod "%tools /main: failed, poke to restart")
    ~&  >  "%tools /main: ready"
    |-
    ;<  =cage  bind:m  take-poke:io
    ?.  =(%tool-execute p.cage)
      ~&  >>>  "%tools /main: unknown mark {<p.cage>}"
      ^$
    =/  req=[call-id=@ta tool-name=@t args=(map @t json)]
      !<([call-id=@ta tool-name=@t args=(map @t json)] q.cage)
    ~&  >  "%tools /main: {(trip tool-name.req)} [{(trip call-id.req)}]"
    ;<  ~  bind:m
      %^  make:io  /exec
        [%& %& [%requests ~] call-id.req]
      |+[%tool-args !>(`[@t (map @t json)]`[tool-name.req args.req])]
    ^$
  ::  /requests/{call-id}: resolve tool, run handler, done
      [[%requests ~] @]
    =/  call-id=@ta  name.rail
    ;<  [tool-name=@t args=(map @t json)]  bind:m
      (get-state-as:io ,[@t (map @t json)])
    ~&  >  "%tools req/{(trip call-id)}: {(trip tool-name)}"
    =/  resolved=(unit tool:tools)
      (~(get by built-ins:tools) tool-name)
    ::  TODO: if not built-in, compile /tools/{tool-name}.hoon
    ?~  resolved
      ~&  >>>  "%tools req/{(trip call-id)}: not found: {(trip tool-name)}"
      (pure:m ~)
    ;<  =tool-result:tools  bind:m  (handler:u.resolved args)
    ~&  >  "%tools req/{(trip call-id)}: {<-.tool-result>}"
    (pure:m ~)
  ==
--
