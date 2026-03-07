::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Tree layout:
::    /main             bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool execution grub (mark %tool-state)
::    /lib/**           user tool source (hoon text)
::    /bin/**           compiled tools (mark %temp; name.tang on failure)
::    /mirror           watches clay /lib/nex/mcp/tools/, writes to /lib/
::    /builder          watches /lib/, compiles to /bin/
::
/+  nexus, tarball, io=fiberio, server, nex-server, nex-mcp
/+  json-utils, nex-tools
!: :: turn on stack trace
=>  |%
    ++  srv  ~(. res:nex-server [%| 1 %& ~ %main])
    ::  Subject vase for compiling user tools.
    ::  Includes standard library + grubbery libs.
    ::
    ++  tool-subject
      ^-  vase
      !>  :*  nexus=nexus
              tarball=tarball
              io=io
              json-utils=json-utils
              tools=nex-tools
              ..zuse
          ==
    ::  Ensure /bin/ subdirectory exists
    ::
    ++  ensure-bin-dir
      |=  bin-path=path
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk [%| 0 %| bin-path])
      ?:  exists  (pure:m ~)
      (make:io /mkd [%| 0 %| bin-path] &+[*sand:nexus [`[~ ~ ~] ~]])
    ::  Cull a grub if it exists
    ::
    ++  cull-if-exists
      |=  =road:tarball
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk road)
      ?:  exists  (cull:io /cull road)
      (pure:m ~)
    ::  Write error tang to /bin/, ensuring dir exists.
    ::  Overwrites if tang file already present.
    ::
    ++  write-error
      |=  [bin-path=path tang-road=road:tarball =tang]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  has-tang=?  bind:m  (peek-exists:io /chk tang-road)
      ?:  has-tang
        (over:io /build tang-road temp+!>(tang))
      ;<  ~  bind:m  (ensure-bin-dir bin-path)
      (make:io /build tang-road |+[temp+!>(tang) ~])
    ::
    ++  compile-lib
      |=  [file-path=path file-name=@ta source=cage]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  bin-path=path  (weld /bin file-path)
      =/  bin-road=road:tarball  [%| 0 %& bin-path file-name]
      =/  tang-name=@ta  (crip "{(trip file-name)}.tang")
      =/  tang-road=road:tarball  [%| 0 %& bin-path tang-name]
      ::  Extract source text
      =/  src=@t
        ?:  =(%txt p.source)  (of-wain:format !<(wain q.source))
        ?:  =(%hoon p.source)  !<(@t q.source)
        !<(@t q.source)
      ::  Try to compile
      =/  res=(each vase tang)
        (mule |.((slap tool-subject (ream src))))
      ?:  ?=(%| -.res)
        ~&  >  [%mcp-builder-fail file-path file-name]
        (write-error bin-path tang-road p.res)
      ::  Validate as $tool
      =/  check=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools p.res)))
      ?:  ?=(%| -.check)
        ~&  >  [%mcp-builder-type-fail file-path file-name]
        =/  =tang  [[%leaf "does not nest against $tool:nex-tools"] p.check]
        (write-error bin-path tang-road tang)
      ::  Success — write compiled tool, clean up old tang
      ~&  >  [%mcp-builder-ok file-path file-name]
      ;<  has-bin=?  bind:m  (peek-exists:io /chk bin-road)
      ?:  has-bin
        ;<  ~  bind:m  (over:io /build bin-road temp+p.res)
        (cull-if-exists tang-road)
      ;<  ~  bind:m  (ensure-bin-dir bin-path)
      ;<  ~  bind:m  (make:io /build bin-road |+[temp+p.res ~])
      (cull-if-exists tang-road)
    ::  Peek /bin/ and extract all successfully compiled tools.
    ::  Walks the ball tree recursively, collecting vase-marked grubs.
    ::
    ++  get-dynamic-tools
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  bin-seen=seen:nexus  bind:m  (peek:io /bin [%| 1 %| /bin] ~)
      ?.  ?=([%& %ball *] bin-seen)
        (pure:m ~)
      (pure:m (collect-tools ball.p.bin-seen))
    ::
    ++  collect-tools
      |=  b=ball:tarball
      ^-  (map @t tool:nex-tools)
      =/  result=(map @t tool:nex-tools)  ~
      ::  Collect files in this directory
      =?  result  ?=(^ fil.b)
        =/  files=(list [@ta content:tarball])
          ~(tap by contents.u.fil.b)
        |-
        ?~  files  result
        =/  [name=@ta =content:tarball]  i.files
        ?:  ?|  !=(p.cage.content %temp)
                ?=(^ (find ".tang" (trip name)))  ::  skip error files
            ==
          $(files t.files)
        =/  got=(each tool:nex-tools tang)
          (mule |.(!<(tool:nex-tools q.cage.content)))
        ?.  ?=(%& -.got)
          $(files t.files)
        $(files t.files, result (~(put by result) name:p.got p.got))
      ::  Recurse into subdirectories
      =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
      |-
      ?~  dirs  result
      =/  [* sub=ball:tarball]  i.dirs
      $(dirs t.dirs, result (~(uni by result) (collect-tools sub)))
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
  =?  ball  =(~ (~(get of ball) /lib))
    (~(put of ball) /lib [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /bin))
    (~(put of ball) /bin [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/ %builder]))
    (~(put ba:tarball ball) [/ %builder] [~ %sig !>(~)])
  =?  ball  =(~ (~(get ba:tarball ball) [/ %mirror]))
    (~(put ba:tarball ball) [/ %mirror] [~ %sig !>(~)])
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
      (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
    ::  Parse JSON body
    =/  bod=(unit octs)  body.request.req
    ?~  bod
      (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
    =/  parsed=(unit json)  (de:json:html q.u.bod)
    ?~  parsed
      (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
    ::  tools/call: create tool grub, watch for result, respond
    =/  method=(unit json)  (~(get jo:json-utils u.parsed) /method)
    ?:  ?=([~ %s %'tools/call'] method)
      =/  id=(unit json)  (~(get jo:json-utils u.parsed) /id)
      =/  params=(unit json)  (~(get jo:json-utils u.parsed) /params)
      ?~  params
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing params')])
      =/  tool-name=(unit json)  (~(get jo:json-utils u.params) /name)
      =/  arguments=(unit json)  (~(get jo:json-utils u.params) /arguments)
      ?~  tool-name
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing tool name')])
      ?.  ?=([%s *] u.tool-name)
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid tool name')])
      ::  Build tool-state with _tool in args for handler lookup
      =/  tool-args=(map @t json)
        ?~  arguments  ~
        ?.  ?=([%o *] u.arguments)  ~
        p.u.arguments
      =/  ts=tool-state:nex-tools
        :+  (~(put by tool-args) '_tool' u.tool-name)
          %start
        ~
      ::  Create tool grub and subscribe
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      =/  tid=@ta  (scot %da now.bowl)
      ;<  ~  bind:m
        (keep:io /watch [%| 1 %& /tools tid] ~)
      ;<  ~  bind:m
        (make:io /make [%| 1 %& /tools tid] |+[tool-state+!>(ts) ~])
      ::  Wait for tool to finish
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
      ?:  ?=(%wake -.nw)  $  :: timer, keep waiting
      ::  Got news — extract tool-state from view
      ?.  ?=(%file -.view.nw)  $  :: not a file update, keep waiting
      =/  st=tool-state:nex-tools
        !<(tool-state:nex-tools q.cage.view.nw)
      ?.  =(%done step.st)  $  :: not done yet
      ::  Done — build JSON-RPC response
      =/  result-type=(unit json)
        (~(get jo:json-utils data.st) /type)
      =/  rpc-result=json
        ?:  ?=([~ %s %'error'] result-type)
          =/  msg=@t
            (~(dog jo:json-utils data.st) /message so:dejs:format)
          (rpc-error:nex-mcp rpc-internal-error:nex-mcp msg id)
        =/  txt=@t
          (~(dog jo:json-utils data.st) /text so:dejs:format)
        (mcp-text-result:nex-mcp txt id)
      =/  json-bytes=octs
        (as-octs:mimes:html (en:json:html rpc-result))
      %-  send-simple:srv
      [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
    ::  Protocol methods (initialize, tools/list, etc.): handle inline
    ;<  dynamic=(map @t tool:nex-tools)  bind:m  get-dynamic-tools
    ;<  response=(unit json)  bind:m  (handle-request:nex-mcp u.parsed dynamic)
    ?~  response
      (send-simple:srv eyre-id [[202 ~] ~])
    =/  json-bytes=octs  (as-octs:mimes:html (en:json:html u.response))
    %-  send-simple:srv
    [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
      ::  /builder: watch /lib/, compile to /bin/
      ::
      [~ %builder]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /builder: failed")
    ~&  >  "%mcp /builder: starting"
    ::  Initial compile: peek /lib/ ball, compile all existing files
    ;<  lib-seen=seen:nexus  bind:m  (peek:io /lib [%| 0 %| /lib] ~)
    ;<  ~  bind:m
      ?.  ?&  ?=([%& %ball *] lib-seen)
              ?=(^ fil.ball.p.lib-seen)
          ==
        (pure:m ~)
      =/  files=(list [@ta content:tarball])
        ~(tap by contents.u.fil.ball.p.lib-seen)
      |-
      ?~  files  (pure:m ~)
      =/  [name=@ta =content:tarball]  i.files
      ;<  ~  bind:m  (compile-lib / name cage.content)
      $(files t.files)
    ::  Subscribe to /lib/ for changes
    ;<  ~  bind:m  (keep:io /lib [%| 0 %| /lib] ~)
    ;<  initial=seen:nexus  bind:m  (peek:io /born [%| 0 %| /lib] ~)
    =/  prev-born=born:nexus
      ?.  ?&(?=(%& -.initial) ?=(%ball -.p.initial))
        *born:nexus
      born.p.initial
    ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
    ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
    ~&  >  "%mcp /builder: watching /lib/"
    |-
    ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /lib)
    ?:  ?=(%wake -.nw)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
      ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
      $
    ?.  ?=([%ball *] view.nw)  $
    =/  root=ball:tarball  ball.view.nw
    =/  root-born=born:nexus  born.view.nw
    =/  what=(set lane:tarball)  (diff-born-state:nexus prev-born root-born)
    =.  prev-born  root-born
    =/  lanes=(list lane:tarball)  ~(tap in what)
    |-
    ?~  lanes  ^$
    ?:  ?=(%| -.i.lanes)  $(lanes t.lanes)
    =/  file-path=path  path.p.i.lanes
    =/  file-name=@ta  name.p.i.lanes
    ::  Check if file still exists (not a delete)
    =/  sub=ball:tarball  (~(dip ba:tarball root) file-path)
    =/  ct=(unit content:tarball)
      ?~  fil.sub  ~
      (~(get by contents.u.fil.sub) file-name)
    ?~  ct
      ::  File deleted — cull corresponding /bin/ entries
      ~&  >  [%mcp-builder-delete file-path file-name]
      =/  bin-road=road:tarball  [%| 0 %& (weld /bin file-path) file-name]
      =/  tang-name=@ta  (crip "{(trip file-name)}.tang")
      =/  tang-road=road:tarball  [%| 0 %& (weld /bin file-path) tang-name]
      ;<  ~  bind:m  (cull-if-exists bin-road)
      ;<  ~  bind:m  (cull-if-exists tang-road)
      $(lanes t.lanes)
    ::  File exists — compile it
    ~&  >  [%mcp-builder-compile file-path file-name]
    ;<  ~  bind:m  (compile-lib file-path file-name cage.u.ct)
    $(lanes t.lanes)
      ::  /mirror: watch clay /lib/nex/mcp/tools/, write sources to /lib/
      ::
      [~ %mirror]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /mirror: failed")
    ~&  >  "%mcp /mirror: starting"
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk  bind:m  get-desk:io
    ;<  now=@da  bind:m  get-time:io
    ::  Initial read: list all tool files and write to /lib/
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %sing %y da+now /lib/nex/mcp/tools)
    ?.  ?=(^ riot)
      ~&  >  "%mcp /mirror: no /lib/nex/mcp/tools/ on desk"
      stay:m
    ::  List files via %t care
    ;<  files=(list path)  bind:m
      (do-scry:io (list path) /scry [%ct desk /lib/nex/mcp/tools])
    ~&  >  [%mcp-mirror-files files]
    =/  tool-files=(list path)
      (skip files |=(p=path !=(%hoon (rear p))))
    |-
    ?~  tool-files
      ::  Done with initial mirror, watch for changes
      ~&  >  "%mcp /mirror: watching clay"
      ;<  now=@da  bind:m  get-time:io
      |-
      ;<  =riot:clay  bind:m
        (warp:io our desk ~ %next %z da+now /lib/nex/mcp/tools)
      ?~  riot  stay:m
      ~&  >  "%mcp /mirror: clay changed, re-mirroring"
      ;<  now=@da  bind:m  get-time:io
      ;<  files=(list path)  bind:m
        (do-scry:io (list path) /scry [%ct desk /lib/nex/mcp/tools])
      =/  tool-files=(list path)
        (skip files |=(p=path !=(%hoon (rear p))))
      |-
      ?~  tool-files  ^$
      =/  pax=path  i.tool-files
      =/  file-name=@ta  (rear (snip pax))
      ~&  >  [%mcp-mirror-write file-name]
      ;<  src=@t  bind:m
        (do-scry:io @t /scry [%cx desk pax])
      =/  lib-road=road:tarball  [%| 0 %& /lib file-name]
      ;<  exists=?  bind:m  (peek-exists:io /chk lib-road)
      ;<  ~  bind:m
        ?:  exists  (over:io /mirror lib-road hoon+!>(src))
        (make:io /mirror lib-road |+[hoon+!>(src) ~])
      $(tool-files t.tool-files)
    ::  Initial mirror: write each file
    =/  pax=path  i.tool-files
    =/  file-name=@ta  (rear (snip pax))
    ~&  >  [%mcp-mirror-write file-name]
    ;<  src=@t  bind:m
      (do-scry:io @t /scry [%cx desk pax])
    =/  lib-road=road:tarball  [%| 0 %& /lib file-name]
    ;<  exists=?  bind:m  (peek-exists:io /chk lib-road)
    ;<  ~  bind:m
      ?:  exists  (over:io /mirror lib-road hoon+!>(src))
      (make:io /mirror lib-road |+[hoon+!>(src) ~])
    $(tool-files t.tool-files)
      ::  /tools/{id}: tool process (mark %tool-state)
      ::  Reads tool-state, runs handler step machine, writes %done.
      ::  Knows nothing about HTTP — the request watcher handles that.
      ::
      [[%tools ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp tool failed")
    ;<  st=tool-state:nex-tools  bind:m
      (get-state-as:io ,tool-state:nex-tools)
    ?:  =(%done step.st)  (pure:m ~)
    ::  Look up handler by tool name stored in args
    =/  tool-json=json  (~(got by args.st) '_tool')
    ?.  ?=([%s *] tool-json)  !!
    =/  tool-name=@t  p.tool-json
    ::  Look up in built-ins, then dynamic tools from /bin/
    ;<  dynamic=(map @t tool:nex-tools)  bind:m  get-dynamic-tools
    =/  all=(map @t tool:nex-tools)
      (~(uni by built-ins:nex-tools) dynamic)
    =/  tl=(unit tool:nex-tools)  (~(get by all) tool-name)
    ?~  tl
      =/  err-data=json
        %-  pairs:enjs:format
        :~  ['type' s+'error']
            ['message' s+(crip "Unknown tool: {(trip tool-name)}")]
        ==
      (replace:io !>(`tool-state:nex-tools`[args.st %done err-data]))
    ::  Run handler — returns tool-result
    ;<  result=tool-result:nex-tools  bind:m  handler.u.tl
    ::  Write result as %done
    =/  result-data=json
      ?-  -.result
        %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
        %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
      ==
    (replace:io !>(`tool-state:nex-tools`[args.st %done result-data]))
  ==
--
