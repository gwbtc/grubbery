::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Tree layout:
::    /main             bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool execution grub (mark %tool-state)
::    /lib/std/**        standard tool sources (synced from clay by per-file watchers)
::    /lib/cus/**        custom tool sources (user-managed, inert)
::    /bin/**            compiled tools (mark %temp on success, %tang on failure)
::    /builder           watches /lib/, compiles all sources to /bin/
::    /mirror            watches clay dir, creates/destroys /lib/std/ watchers
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
    ::  Compile a tool source file and write result to /bin/.
    ::  Success → mark %temp (compiled vase).
    ::  Failure → mark %tang (error trace).
    ::  Same grub name either way; mark distinguishes state.
    ::
    ++  compile-lib
      |=  [file-path=path file-name=@ta source=cage]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  bin-path=path  (weld /bin file-path)
      =/  bin-road=road:tarball  [%| 0 %& bin-path file-name]
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
        (write-bin bin-path bin-road tang+!>(p.res))
      ::  Validate as $tool
      =/  check=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools p.res)))
      ?:  ?=(%| -.check)
        ~&  >  [%mcp-builder-type-fail file-path file-name]
        =/  =tang  [[%leaf "does not nest against $tool:nex-tools"] p.check]
        (write-bin bin-path bin-road tang+!>(tang))
      ::  Success
      ~&  >  [%mcp-builder-ok file-path file-name]
      (write-bin bin-path bin-road temp+p.res)
    ::  Write a cage to /bin/, creating dir if needed, overwriting if exists.
    ::
    ++  write-bin
      |=  [bin-path=path bin-road=road:tarball =cage]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk bin-road)
      ?:  exists
        ::  Cull and recreate: mark may change (temp↔tang)
        ;<  ~  bind:m  (cull:io /build bin-road)
        (make:io /build bin-road |+[cage ~])
      ;<  ~  bind:m  (ensure-bin-dir bin-path)
      (make:io /build bin-road |+[cage ~])
    ::  Peek /bin/ and extract all successfully compiled tools.
    ::  Walks the ball tree recursively, collecting vase-marked grubs.
    ::
    ++  get-dynamic-tools
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  bin-seen=seen:nexus  bind:m  (peek:io /bin [%| 1 %| /bin] ~)
      ?.  ?=([%& %ball *] bin-seen)
        (pure:m ~)
      ::  Collect cus/ first, then std/ — std wins on name conflicts
      =/  cus-ball=ball:tarball
        (~(gut by dir.ball.p.bin-seen) %cus *ball:tarball)
      =/  std-ball=ball:tarball
        (~(gut by dir.ball.p.bin-seen) %std *ball:tarball)
      =/  cus-tools=(map @t tool:nex-tools)  (collect-tools cus-ball)
      =/  std-tools=(map @t tool:nex-tools)  (collect-tools std-ball)
      (pure:m (~(uni by cus-tools) std-tools))
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
        ?:  !=(p.cage.content %temp)
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
  =?  ball  =(~ (~(get of ball) /lib/std))
    (~(put of ball) /lib/std [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /lib/cus))
    (~(put of ball) /lib/cus [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /bin))
    (~(put of ball) /bin [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/ %builder]))
    (~(put ba:tarball ball) [/ %builder] [~ %sig !>(~)])
  ::  Always restart mirror to recompile all std tools
  =.  ball  (~(put ba:tarball ball) [/ %mirror] [~ %sig !>(~)])
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
      ::  /builder: watch /lib/, compile all sources to /bin/
      ::
      [~ %builder]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /builder: failed")
    ~&  >  "%mcp /builder: starting"
    ::  Subscribe to /lib/ for changes
    ;<  ~  bind:m  (keep:io /lib [%| 0 %| /lib] ~)
    ;<  lib-init=seen:nexus  bind:m  (peek:io /born [%| 0 %| /lib] ~)
    =/  prev-born=born:nexus
      ?.  ?&(?=(%& -.lib-init) ?=(%ball -.p.lib-init))
        *born:nexus
      born.p.lib-init
    ;<  =bowl:nexus  bind:m  (get-bowl:io /tmr)
    ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
    ~&  >  "%mcp /builder: watching /lib/"
    |-
    ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /lib)
    ?:  ?=(%wake -.nw)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /tmr)
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
      ::  File deleted — cull corresponding /bin/ entry
      ~&  >  [%mcp-builder-delete file-path file-name]
      =/  bin-road=road:tarball  [%| 0 %& (weld /bin file-path) file-name]
      ;<  ~  bind:m  (cull-if-exists bin-road)
      $(lanes t.lanes)
    ::  File exists — compile it
    ~&  >  [%mcp-builder-compile file-path file-name]
    ;<  ~  bind:m  (compile-lib file-path file-name cage.u.ct)
    $(lanes t.lanes)
      ::  /mirror: watch clay dir, create/destroy /lib/std/ watchers
      ::
      [~ %mirror]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /mirror: failed")
    ~&  >  "%mcp /mirror: starting"
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk  bind:m  get-desk:io
    ::  Delete all existing /lib/std/ processes for clean slate
    ;<  std-seen=seen:nexus  bind:m  (peek:io /std [%| 0 %| /lib/std] ~)
    ;<  ~  bind:m
      ?.  ?&  ?=([%& %ball *] std-seen)
              ?=(^ fil.ball.p.std-seen)
          ==
        (pure:m ~)
      =/  old=(list [@ta content:tarball])
        ~(tap by contents.u.fil.ball.p.std-seen)
      |-
      ?~  old  (pure:m ~)
      =/  [oname=@ta *]  i.old
      ~&  >  [%mcp-mirror-cull-old oname]
      ;<  ~  bind:m  (cull:io /cull [%| 0 %& /lib/std oname])
      $(old t.old)
    ::  List tool files from clay
    ;<  now=@da  bind:m  get-time:io
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %sing %y da+now /lib/nex/mcp/tools)
    ?.  ?=(^ riot)
      ~&  >  "%mcp /mirror: no /lib/nex/mcp/tools/ on desk"
      stay:m
    ;<  files=(list path)  bind:m
      (do-scry:io (list path) /scry [%ct desk /lib/nex/mcp/tools])
    =/  tool-files=(list path)
      (skip files |=(p=path !=(%hoon (rear p))))
    ~&  >  [%mcp-mirror-files (lent tool-files)]
    ::  Create a /lib/std/ process for each tool file
    |-
    ?~  tool-files
      ::  Done creating, watch clay dir for additions/removals
      ~&  >  "%mcp /mirror: watching clay"
      ;<  now=@da  bind:m  get-time:io
      |-
      ;<  =riot:clay  bind:m
        (warp:io our desk ~ %next %z da+now /lib/nex/mcp/tools)
      ?~  riot  stay:m
      ~&  >  "%mcp /mirror: clay dir changed"
      ;<  now=@da  bind:m  get-time:io
      ;<  files=(list path)  bind:m
        (do-scry:io (list path) /scry [%ct desk /lib/nex/mcp/tools])
      =/  tool-files=(list path)
        (skip files |=(p=path !=(%hoon (rear p))))
      =/  new-names=(set @ta)
        %-  ~(gas in *(set @ta))
        (turn tool-files |=(p=path (rear (snip p))))
      ::  Get current /lib/std/ processes
      ;<  std-seen=seen:nexus  bind:m  (peek:io /std [%| 0 %| /lib/std] ~)
      =/  old-names=(set @ta)
        ?.  ?&  ?=([%& %ball *] std-seen)
                ?=(^ fil.ball.p.std-seen)
            ==
          ~
        (~(run in ~(key by contents.u.fil.ball.p.std-seen)) |=(n=@ta n))
      ::  Delete removed tools
      =/  removed=(list @ta)  ~(tap in (~(dif in old-names) new-names))
      ;<  ~  bind:m
        |-
        ?~  removed  (pure:m ~)
        ~&  >  [%mcp-mirror-remove i.removed]
        ;<  ~  bind:m  (cull:io /cull [%| 0 %& /lib/std i.removed])
        $(removed t.removed)
      ::  Create new tools
      =/  added=(list @ta)  ~(tap in (~(dif in new-names) old-names))
      ;<  ~  bind:m
        |-
        ?~  added  (pure:m ~)
        ~&  >  [%mcp-mirror-add i.added]
        ;<  ~  bind:m
          (make:io /std [%| 0 %& /lib/std i.added] |+[hoon+!>('') ~])
        $(added t.added)
      ^$
    ::  Create /lib/std/ process for this tool
    =/  pax=path  i.tool-files
    =/  file-name=@ta  (rear (snip pax))
    ~&  >  [%mcp-mirror-create file-name]
    ;<  ~  bind:m
      (make:io /std [%| 0 %& /lib/std file-name] |+[hoon+!>('') ~])
    $(tool-files t.tool-files)
      ::  /lib/std/**/name: watches own clay file, stores source as content
      ::
      [[%lib %std *] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /lib/std: failed")
    =/  file-name=@ta  name.rail
    =/  sub-path=path  (slag 2 `path`path.rail)
    ~&  >  [%mcp-std-start sub-path file-name]
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk  bind:m  get-desk:io
    =/  clay-path=path
      :(weld /lib/nex/mcp/tools sub-path /[file-name] /hoon)
    ::  Read source from clay, store as own content
    ;<  now=@da  bind:m  get-time:io
    ;<  src=@t  bind:m  (do-scry:io @t /scry [%cx desk clay-path])
    ;<  ~  bind:m  (replace:io !>(src))
    ::  Watch for changes
    |-
    ;<  now=@da  bind:m  get-time:io
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %next %x da+now clay-path)
    ?~  riot
      ~&  >  [%mcp-std-gone file-name]
      stay:m
    ~&  >  [%mcp-std-changed file-name]
    ;<  now=@da  bind:m  get-time:io
    ;<  src=@t  bind:m  (do-scry:io @t /scry [%cx desk clay-path])
    ;<  ~  bind:m  (replace:io !>(src))
    $
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
    ::  Look up in dynamic tools from /bin/
    ;<  all=(map @t tool:nex-tools)  bind:m  get-dynamic-tools
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
