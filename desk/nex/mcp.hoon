::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Binds /grubbery/mcp and handles JSON-RPC 2.0 requests.
::  Delegates tool execution to lib/nex/tools built-ins.
::
::  Tree layout:
::    /main             bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool process (mark %json, can replace:io)
::
/+  nexus, tarball, io=fiberio, server, http-utils, nex-server, nex-mcp
/+  json-utils
!: :: turn on stack trace
=>  |%
    ++  srv  ~(. res:nex-server [%| 1 %& ~ %main])
    --
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
  =?  ball  =(~ (~(get of ball) /requests))
    (~(put of ball) /requests [~ ~ ~])
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
      [~ %main]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /main: failed")
    ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/mcp])
    ~&  >  "%mcp /main: ready, bound /grubbery/mcp"
    (http-dispatch:nex-server %mcp)
      ::  /requests/{eyre-id}: parse HTTP, dispatch
      ::
      [[%requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp request failed")
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m
      (get-state-as:io ,[src=@p inbound-request:eyre])
    ;<  our=@p  bind:m  get-our:io
    ?.  =(src our)
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
      (pure:m ~)
    ::  Parse JSON body
    =/  bod=(unit octs)  body.request.req
    ?~  bod
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
      (pure:m ~)
    =/  parsed=(unit json)  (de:json:html q.u.bod)
    ?~  parsed
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
      (pure:m ~)
    ::  tools/call: spawn a tool process in /tools/{id}
    ::  Uses now as base ID, increments if taken.
    =/  method=(unit json)  (~(get jo:json-utils u.parsed) /method)
    ?:  ?=([~ %s %'tools/call'] method)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      =/  tool-state=json
        %-  pairs:enjs:format
        :~  ['eyre-id' s+eyre-id]
            ['request' u.parsed]
        ==
      =/  base=@da  now.bowl
      |-
      =/  tid=@ta  (scot %da base)
      ;<  exists=?  bind:m
        (peek-exists:io /peek [%| 1 %& /tools tid])
      ?.  exists
        ;<  ~  bind:m
          (make:io /make [%| 1 %& /tools tid] |+json+!>(tool-state))
        (pure:m ~)
      $(base +(base))
    ::  Protocol methods (initialize, tools/list, etc.): handle inline
    ;<  response=(unit json)  bind:m  (handle-request:nex-mcp u.parsed)
    ?~  response
      ;<  ~  bind:m  (send-simple:srv eyre-id [[202 ~] ~])
      (pure:m ~)
    =/  json-bytes=octs  (as-octs:mimes:html (en:json:html u.response))
    ;<  ~  bind:m
      %-  send-simple:srv
      [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
    (pure:m ~)
      ::  /tools/{id}: tool process
      ::  Born with mark %json. State includes request and
      ::  optional eyre-id for HTTP response delivery.
      ::
      [[%tools ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp tool failed")
    ;<  init=json  bind:m  (get-state-as:io ,json)
    =/  eyre-id=@ta
      (~(dog jo:json-utils init) /eyre-id so:dejs:format)
    =/  request=json  (~(got jo:json-utils init) /request)
    ;<  response=(unit json)  bind:m  (handle-request:nex-mcp request)
    ?~  response
      ;<  ~  bind:m  (send-simple:srv eyre-id [[202 ~] ~])
      (pure:m ~)
    =/  json-bytes=octs  (as-octs:mimes:html (en:json:html u.response))
    ;<  ~  bind:m
      %-  send-simple:srv
      [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
    (pure:m ~)
  ==
--
