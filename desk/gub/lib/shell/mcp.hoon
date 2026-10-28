::  lib/shell/mcp: the MCP JSON-RPC endpoint, a service of the shell.
::
::  The shell mounts a tools nexus at /tools (the tool registry and
::  execution engine, nex/tools.hoon) and serves the MCP protocol over
::  it at /grubbery/tools: tools/list, tools/call, and the page that
::  shows any tools nexus by path. Discovery and execution are the
::  child's; this is the HTTP shell.
::
::    <shell>/tools/                the tools nexus: /code (registry), /runs/{id}
::    <shell>/ui/tools/*            the page, at /grubbery/tools
::    <shell>/ui/requests/{id}      one request, served by +serve-request
::
::  Every road is relative to the request grub, so the service reads
::  and writes only the shell's own tree wherever the shell lives.
::
/<  nex-mcp   /lib/mcp-rpc.hoon
/<  tools     /lib/tools.hoon
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'http.sig'])
::  +tools-bole: the /tools mount. The live tools/code subtree is read
::  from the shell's ball and the bundle merged onto it, bundle winning
::  name conflicts, so a reseed updates bundle tools without deleting
::  ones added at runtime. /runs is left as it is.
::
++  tools-bole
  |=  [=ball:tarball bundle=(axal (map @ta mime))]
  ^-  bole:tarball
  =/  existing=bole:tarball
    =/  sub=(unit ball:tarball)  (~(dap ba:tarball ball) /tools/code)
    ?~  sub  *bole:tarball
    =/  code-bole=bole:tarball  (ball-to-bole:tarball u.sub)
    [`[`[/ %tools] ~ %.n ~] (malt ~[[%code code-bole]])]
  (merge-boles:tools existing (seed-tools:tools bundle))
::  +tile: the launcher tile for the tools page
::
++  tile
  ^-  json
  %-  pairs:enjs:format
  :~  title+s+'Tools'
      info+s+'tool registry & runs'
      color+s+'#232630'
      image+s+'/grubbery/tools/icon.svg'
      href+s+'/grubbery/tools'
  ==
::  +send-json: 200 a json body on an eyre connection
::
++  send-json
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %-  send-simple:srv
  :-  eyre-id
  :-  [200 ~[['content-type' 'application/json']]]
  `(as-octs:mimes:html (en:json:html jon))
::  +tool-json: one tool as its tools/list entry
::
++  tool-json
  |=  [nm=@t t=tool:tools]
  ^-  json
  =/  props=(list [@t json])
    %+  turn  ~(tap by parameters:t)
    |=  [k=@t pd=parameter-def:tools]
    :-  k
    %-  pairs:enjs:format
    :~  ['type' s+`@t`type.pd]
        ['description' s+description.pd]
    ==
  %-  pairs:enjs:format
  :~  ['name' s+nm]
      ['description' s+description:t]
      :-  'inputSchema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          ['properties' [%o (~(gas by *(map @t json)) props)]]
          ['required' a+(turn required:t |=(r=@t s+r))]
      ==
  ==
::  +gather-tools-tree: the tools of ONE tools nexus, named by its
::  absolute path, as a location tree. The page is a viewer for any
::  tools nexus: /grubbery/tools/<path> shows the one at <path>; no
::  registry, no scanning, the URL is the address. Our own /tools is
::  read by delegation (only the child reads its own /code); any
::  other by peeking <path>/code/lib/tools directly.
::
++  gather-tools-tree
  |=  [=rail:tarball at=path own=?]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  found=(map @t tool:tools)  bind:m
    ?:  own  (get-dynamic-tools rail)
    (scan-namespace (welp at /code/lib/tools))
  =/  tree=json  (tools-nest found)
  ?>  ?=(%o -.tree)
  (pure:m [%o (~(put by p.tree) 'path' s+(spat at))])
::  +tools-nest: a derived-name-keyed tool map as a location tree —
::  {dirs: [{name, dirs, tools}], tools: [...]}. Names round-trip
::  through the bijection, so the tree is recomputed from the keys.
::
++  tools-nest
  |=  found=(map @t tool:tools)
  ^-  json
  =/  entries=(list [sub=path tj=json])
    %+  turn
      %+  sort  ~(tap by found)
      |=([[a=@t *] [b=@t *]] (aor a b))
    |=  [nm=@t t=tool:tools]
    [sub:(name-to-place:tools nm) (tool-json nm t)]
  |^  (nest entries)
  ++  nest
    |=  ens=(list [sub=path tj=json])
    ^-  json
    =/  here=(list json)
      (murn ens |=([sub=path tj=json] ?~(sub `tj ~)))
    =/  kids=(list @ta)
      =|  seen=(set @ta)
      =/  e  ens
      |-  ^-  (list @ta)
      ?~  e  (sort ~(tap in seen) aor)
      ?~  sub.i.e  $(e t.e)
      $(e t.e, seen (~(put in seen) i.sub.i.e))
    =/  dirs=(list json)
      %+  turn  kids
      |=  kid=@ta
      =/  inner=json
        %-  nest
        %+  murn  ens
        |=  [sub=path tj=json]
        ?~  sub  ~
        ?.  =(kid i.sub)  ~
        `[t.sub tj]
      ?>  ?=(%o -.inner)
      [%o (~(put by p.inner) 'name' s+kid)]
    (pairs:enjs:format ~[['dirs' a+dirs] ['tools' a+here]])
  --
++  quay-get
  |=  [=quay:eyre key=@t]
  ^-  (unit @t)
  ?~  quay  ~
  ?:  =(key p.i.quay)  `q.i.quay
  $(quay t.quay)
::  +find-tool-src: raw source of a tool by its advertised name.
::  Underscores to hyphens, then <path>/code/lib/tools/<sub>/<name>.hoon.
::
++  find-tool-src
  |=  [at=path tool-name=@t]
  =/  m  (fiber:fiber:nexus ,(unit [path @t]))
  ^-  form:m
  =/  [sub=path arm=@ta]  (name-to-place:tools tool-name)
  =/  fname=@ta  (crip "{(trip arm)}.hoon")
  =/  in-dir=path  (weld (welp at /code/lib/tools) sub)
  ;<  fv=view:nexus  bind:m
    (peek:io [%& %& in-dir fname] `[/ %mime])
  ?.  ?&(?=([%file *] fv) !(is-boom:tarball sang.fv))
    (pure:m ~)
  =/  got  (mule |.(!<(mime (need-vase:tarball sang.fv))))
  ?:  ?=(%| -.got)  (pure:m ~)
  (pure:m `[(snoc in-dir fname) `@t`q.q.p.got])
::  +gather-runs: every run grub in a tools nexus — runs in flight.
::  Skips booms and undecodable states rather than failing the page.
::
++  gather-runs
  |=  at=path
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  runs=(list json)  bind:m  (gather-runs-in (welp at /runs))
  (pure:m a+runs)
::
++  gather-runs-in
  |=  dir=path
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| dir] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  ?~  fil.ball.view  (pure:m ~)
  =/  ids=(list @ta)
    (sort ~(tap in ~(key by contents.u.fil.ball.view)) aor)
  =|  acc=(list json)
  |-
  ?~  ids  (pure:m (flop acc))
  =/  tid=@ta  i.ids
  ?:  =('weir.json' tid)  $(ids t.ids)
  ;<  fv=view:nexus  bind:m
    (peek:io [%& %& dir tid] ~)
  ?.  ?=([%file *] fv)  $(ids t.ids)
  ?:  (is-boom:tarball sang.fv)  $(ids t.ids)
  =/  got  (mule |.(!<(tool-state:tools (need-vase:tarball sang.fv))))
  ?:  ?=(%| -.got)  $(ids t.ids)
  =/  st  p.got
  =/  run=json
    %-  pairs:enjs:format
    :~  ['id' s+tid]
        ['tool' s+tool.st]
        ['step' s+step.st]
        ['args' o+args.st]
        ['result' (fall update.st ~)]
    ==
  $(ids t.ids, acc [run acc])
::  Strip .hoon suffix from grub name
::
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
::  +get-dynamic-tools: the live tool list, obtained by DELEGATING to
::  the tools child. Only the child can read its own /code (a
::  relative, self-locating read from its own rail); the shell cannot
::  reach in. So it pokes the child %list, the child scans its /code
::  and pokes the schema array straight back; it is reshaped into the
::  tool map downstream expects.
::
++  get-dynamic-tools
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t tool:tools))
  ^-  form:m
  ;<  entries=(list json)  bind:m  (request-tool-list rail)
  %-  pure:m
  %-  ~(gas by *(map @t tool:tools))
  %+  murn  entries
  |=  j=json
  ^-  (unit [@t tool:tools])
  =/  t=(unit tool:tools)  (entry-to-tool j)
  ?~(t ~ `[name:u.t u.t])
::  +request-tool-list: poke the child %list; it computes the list and
::  pokes the schema array straight back. Pure request/response — the
::  request grub that asks handles the answer.
::
++  request-tool-list
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =/  call-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
  ;<  ~  bind:m
    (poke:io call-road [[/ %json] (pairs:enjs:format ~[['cmd' s+'list']])])
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  j=json  !<(json q.sage)
  (pure:m ?:(?=([%a *] j) p.j ~))
::  +entry-to-tool: one neutral schema entry -> tool:tools (handler is
::  a stub — these values only feed discovery, never execution).
::
++  entry-to-tool
  |=  j=json
  ^-  (unit tool:tools)
  ?.  ?=([%o *] j)  ~
  =/  nm=@t    (get-str 'name' j)
  =/  desc=@t  (get-str 'description' j)
  =/  ps=(map @t parameter-def:tools)
    (parse-params (~(get by p.j) 'parameters'))
  =/  rq=(list @t)  (parse-reqd (~(get by p.j) 'required'))
  ?:  =('' nm)  ~
  :-  ~
  ^-  tool:tools
  |%
  ++  name         nm
  ++  description  desc
  ++  parameters   ps
  ++  required     rq
  ++  handler      *tool-handler:tools
  --
++  get-str
  |=  [k=@t j=json]
  ^-  @t
  ?.  ?=([%o *] j)  ''
  =/  v=(unit json)  (~(get by p.j) k)
  ?~  v  ''
  ?.(?=([%s *] u.v) '' p.u.v)
++  parse-reqd
  |=  u=(unit json)
  ^-  (list @t)
  ?~  u  ~
  ?.  ?=([%a *] u.u)  ~
  %+  murn  p.u.u
  |=(e=json ?.(?=([%s *] e) ~ `p.e))
++  str-to-ptype
  |=  t=@t
  ^-  parameter-type:tools
  ?+  t  %string
    %number   %number
    %boolean  %boolean
    %array    %array
    %object   %object
  ==
++  parse-params
  |=  u=(unit json)
  ^-  (map @t parameter-def:tools)
  ?~  u  ~
  ?.  ?=([%o *] u.u)  ~
  %-  ~(run by p.u.u)
  |=  pj=json
  ^-  parameter-def:tools
  [(str-to-ptype (get-str 'type' pj)) (get-str 'description' pj)]
::  +scan-namespace: every compiled tool under a /code/lib/tools dir
::  named by absolute path (another nexus's tools, read directly)
::
++  scan-namespace
  |=  root=path
  =/  m  (fiber:fiber:nexus ,(map @t tool:tools))
  ^-  form:m
  ;<  src-view=view:nexus  bind:m
    (peek:io [%& %| root] ~)
  ?.  ?=([%ball *] src-view)
    (pure:m ~)
  =/  pairs=(list [sub=path file=@ta])
    (ball-code-files ~ ball.src-view)
  =/  result=(map @t tool:tools)  ~
  |-
  ?~  pairs  (pure:m result)
  =/  [sub=path file=@ta]  i.pairs
  ;<  res=built:nexus  bind:m
    (get-code-full:io [%& %& (weld root sub) (strip-hoon:tools file)])
  ?.  ?=(%vase -.res)  $(pairs t.pairs)
  =/  got=(each tool:tools tang)
    (mule |.(!<(tool:tools vase.res)))
  ?.  ?=(%& -.got)  $(pairs t.pairs)
  $(pairs t.pairs, result (~(put by result) (derive-name:tools sub file) p.got))
::  +ball-code-files: every file in a ball, with its subpath
::
++  ball-code-files
  |=  [sub=path bal=ball:tarball]
  ^-  (list [path @ta])
  =/  here=(list [path @ta])
    ?~  fil.bal  ~
    (turn ~(tap by contents.u.fil.bal) |=([n=@ta *] [sub n]))
  %+  roll  ~(tap by dir.bal)
  |=  [[nam=@ta kid=ball:tarball] acc=_here]
  (weld acc (ball-code-files (snoc sub nam) kid))
::  +serve-request: one HTTP request at /grubbery/tools, from the
::  shell's request grub. GET serves the page and its data routes;
::  POST is JSON-RPC: tools/call runs through the /tools child, the
::  protocol methods are answered inline.
::
++  serve-request
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  eyre-id=@ta  name.rail
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
  =/  [site=path qargs=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path
    %+  skip  (slag (lent `path`/grubbery/tools) site)
    |=(seg=@ta =('' seg))
  ?:  =('GET' method.request.req)
    ::  MCP Streamable HTTP: a GET that asks for an event stream is a
    ::  client opening the server-initiated channel. There is no such
    ::  channel, and the spec's answer for that is 405 — a client told
    ::  405 stops asking. Answering with the page instead (200,
    ::  text/html) reads to the client as a stream that closed at once,
    ::  so it reconnects, for ever: one ~6.5s request every ~6s per
    ::  connected client, on a ship that runs its events one at a time.
    ::  Browsers ask for text/html and are unaffected; the page's own
    ::  /api/* fetches ask for json.
    =/  accept=tape
      (trip (fall (get-header:http 'accept' header-list.request.req) ''))
    ?:  ?=(^ (find "text/event-stream" accept))
      %+  send-simple:srv  eyre-id
      :-  [405 ~[['allow' 'POST']]]
      `(as-octs:mimes:html 'Method Not Allowed')
    ::  which tools nexus the data routes are about: ?path=<abs>, default
    ::  our own /tools (this request grub sits at <shell>/ui/requests/<id>)
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  own=path  (welp (scag (sub (lent path.here) 2) path.here) /tools)
    =/  at=path
      =/  p=(unit @t)  (quay-get qargs 'path')
      ?~  p  own
      (fall (rush u.p stap) own)
    =/  is-own=?  =(at own)
    ?:  ?=([%api %tools ~] suffix)
      ::  the FULL registry, not the three-tool protocol allowlist
      ::  that tools/list advertises to MCP clients
      ;<  dynamic=(map @t tool:tools)  bind:m  (get-dynamic-tools rail)
      (send-json eyre-id (mcp-tools-list:nex-mcp dynamic ~))
    ?:  ?=([%api %runs ~] suffix)
      ;<  runs=json  bind:m  (gather-runs at)
      (send-json eyre-id runs)
    ?:  ?=([%api %tools-tree ~] suffix)
      ;<  tree=json  bind:m  (gather-tools-tree rail at is-own)
      ?>  ?=(%o -.tree)
      (send-json eyre-id [%o (~(put by p.tree) 'own' b+is-own)])
    ?:  ?=([%api %src ~] suffix)
      =/  tool-name=(unit @t)  (quay-get qargs 'tool')
      ?~  tool-name
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'tool required')])
      ;<  res=(unit [pax=path txt=@t])  bind:m  (find-tool-src at u.tool-name)
      ?~  res
        (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'not found')])
      %+  send-json  eyre-id
      (pairs:enjs:format ~[['path' s+(spat pax.u.res)] ['text' s+txt.u.res]])
    ::  a one-segment suffix that names a file of the page is that file;
    ::  any other suffix is a tools-nexus path and gets the page, which
    ::  reads the path back out of its URL
    ;<  fv=view:nexus  bind:m
      ?.  ?=([@ ~] suffix)  (pure:(fiber:fiber:nexus ,view:nexus) [%none ~])
      (peek:io (nex-road:io rail [%& /ui/tools i.suffix]) `[/ %mime])
    ;<  fv=view:nexus  bind:m
      ?:  ?=([%file *] fv)  (pure:(fiber:fiber:nexus ,view:nexus) fv)
      (peek:io (nex-road:io rail [%& /ui/tools %'index.html']) `[/ %mime])
    ?.  ?=([%file *] fv)
      (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    =/  =mime  !<(mime (need-vase:tarball sang.fv))
    (send-simple:srv eyre-id (mime-response:http-utils mime))
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
    ::  Delegate the run to the /tools child nexus: subscribe to the
    ::  run grub, poke the child's main.sig to spawn it, await %done,
    ::  then poke the child to cull it. The run executes under the
    ::  child's weir.
    =/  tid=@ta  eyre-id
    =/  run-road=road:tarball   (nex-road:io rail [%& /tools/runs tid])
    =/  call-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
    =/  call-body=json
      %-  pairs:enjs:format
      :~  ['cmd' s+'call']
          ['id' s+tid]
          ['name' u.tool-name]
          ['arguments' (fall arguments [%o ~])]
      ==
    ;<  exists=?  bind:m  (peek-exists:io run-road)
    ;<  =kept:nexus  bind:m  get-kept:io
    ;<  ~  bind:m
      ?.  =(~ kept)
        (pure:m ~)
      ;<  *  bind:m  (keep:io /watch run-road ~)
      ?:  exists  (pure:m ~)
      (poke:io call-road [[/ %json] call-body])
    ::  Wait for the run to finish
    |-
    ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
    ?:  ?=(%wake -.nw)  $
    =/  cas=(unit cass:clay)
      ?~  fil.wave.nw  ~
      (~(get by file.u.fil.wave.nw) tid)
    ?~  cas  $
    ;<  =view:nexus  bind:m  (peek-at:io run-road ~ [%ud ud.u.cas])
    ?.  ?=([%file *] view)  $
    =/  st=tool-state:tools
      !<(tool-state:tools (need-vase:tarball sang.view))
    ?.  =(%done step.st)  $
    ?~  update.st  $
    ::  Done — build JSON-RPC response from update
    =/  result-type=(unit json)
      (~(get jo:json-utils u.update.st) /type)
    =/  rpc-result=json
      ?:  ?=([~ %s %'error'] result-type)
        =/  msg=@t
          (~(dog jo:json-utils u.update.st) /message so:dejs:format)
        (rpc-error:nex-mcp rpc-internal-error:nex-mcp msg id)
      =/  txt=@t
        (~(dog jo:json-utils u.update.st) /text so:dejs:format)
      (mcp-text-result:nex-mcp txt id)
    =/  json-bytes=octs
      (as-octs:mimes:html (en:json:html rpc-result))
    ;<  ~  bind:m
      %-  send-simple:srv
      [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
    ::  requester-owned GC: tell the child to cull the finished run.
    ;<  ~  bind:m  (drop:io /watch run-road)
    ;<  ~  bind:m
      %+  poke:io  call-road
      [[/ %json] (pairs:enjs:format ~[['cmd' s+'cull'] ['id' s+tid]])]
    (pure:m ~)
  ::  Protocol methods (initialize, tools/list, etc.): handle inline
  ;<  dynamic=(map @t tool:tools)  bind:m  (get-dynamic-tools rail)
  ;<  response=(unit json)  bind:m  (handle-request:nex-mcp u.parsed dynamic)
  ?~  response
    (send-simple:srv eyre-id [[202 ~] ~])
  =/  json-bytes=octs  (as-octs:mimes:html (en:json:html u.response))
  %-  send-simple:srv
  [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
--
