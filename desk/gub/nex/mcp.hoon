::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Tree layout:
::    /main.sig         bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/           the tools child nexus: /code (registry), /runs/{id}
::
/<  nex-mcp   /lib/mcp-rpc.hoon
/<  tools     /lib/tools.hoon
/&  bundle    /lib/tool-bundle/
/&  man       ../man/mcp/readme.md
/&  ui-html   mcp/index.html
/&  ui-js     mcp/app.js
/&  ui-css    mcp/style.css
/&  ui-icon   mcp/icon.svg
/&  ui-md     mcp/marked.min.js
=>  |%
    ::  +weir-json: mcp runs ARBITRARY user tools, and those tools execute
    ::  under mcp's own weir — a tool may scry, poke, or make anything. So
    ::  mcp cannot be scoped: it needs everything. (Scoping it to tool
    ::  discovery — peek /code/lib/tools + /apps — is wrong; it starves tool
    ::  EXECUTION, e.g. a tool's /sys/scry gets vetoed.) The real fix later
    ::  is to run each tool under its OWN weir so mcp itself can be narrow;
    ::  until then mcp is honestly unrestricted.
    ::
    ++  weir-json
      ^-  json
      =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
      %-  pairs:enjs:format
      :~  :-  'poke'
          :-  %a
          :~  (line '/' 'runs arbitrary tools under its own weir — a tool may poke anything')
          ==
          :-  'peek'
          :-  %a
          :~  (line '/' 'a tool may read anything')
          ==
          :-  'make'
          :-  %a
          :~  (line '/' 'a tool may create grubs anywhere')
          ==
      ==
    ++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
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
    ::  +gather-tools-tree: the registry grouped by where the code
    ::  lives — root /code/lib/tools plus each app's code namespace.
    ::
    ++  gather-tools-tree
      |=  =rail:tarball
      =/  m  (fiber:fiber:nexus ,json)
      ^-  form:m
      ;<  root=(map @t tool:tools)  bind:m
        (get-dynamic-tools rail)
      =/  root-tree=json  (tools-nest root)
      ;<  app-paths=(list path)  bind:m  get-app-mcp-paths
      =|  app-dirs=(list json)
      |-
      ?~  app-paths
        ?>  ?=(%o -.root-tree)
        =/  dirs=json  (fall (~(get by p.root-tree) 'dirs') [%a ~])
        ?>  ?=(%a -.dirs)
        %-  pure:m
        :-  %o
        (~(put by p.root-tree) 'dirs' a+(weld p.dirs (flop app-dirs)))
      ;<  found=(map @t tool:tools)  bind:m  (scan-namespace i.app-paths)
      ?:  =(~ found)  $(app-paths t.app-paths)
      =/  app-name=@ta
        ?>  ?=([%apps @ *] i.app-paths)
        i.t.i.app-paths
      =/  sub=json  (tools-nest found)
      ?>  ?=(%o -.sub)
      =/  entry=json
        :-  %o
        (~(put by p.sub) 'name' s+(crip "apps/{(trip app-name)}"))
      $(app-paths t.app-paths, app-dirs [entry app-dirs])
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
    ::  Same resolution order as +await-tool: underscores to hyphens,
    ::  root /code/lib/tools first, then each app's code namespace.
    ::
    ++  find-tool-src
      |=  tool-name=@t
      =/  m  (fiber:fiber:nexus ,(unit [path @t]))
      ^-  form:m
      =/  [sub=path arm=@ta]  (name-to-place:tools tool-name)
      =/  fname=@ta  (crip "{(trip arm)}.hoon")
      ;<  app-paths=(list path)  bind:m  get-app-mcp-paths
      =/  dirs=(list path)  [/code/lib/tools app-paths]
      |-
      ?~  dirs  (pure:m ~)
      =/  in-dir=path  (weld i.dirs sub)
      ;<  fv=view:nexus  bind:m
        (peek:io [%& %& in-dir fname] `[/ %mime])
      ?.  ?&(?=([%file *] fv) !(is-boom:tarball sang.fv))
        $(dirs t.dirs)
      =/  got  (mule |.(!<(mime (need-vase:tarball sang.fv))))
      ?:  ?=(%| -.got)  $(dirs t.dirs)
      (pure:m `[(snoc in-dir fname) `@t`q.q.p.got])
    ::  +gather-runs: every run grub in the tools child — runs in
    ::  flight. Skips booms and undecodable states rather than failing
    ::  the page.
    ::
    ++  gather-runs
      |=  =rail:tarball
      =/  m  (fiber:fiber:nexus ,json)
      ^-  form:m
      ;<  runs=(list json)  bind:m  (gather-runs-in rail /tools/runs)
      (pure:m a+runs)
    ::
    ++  gather-runs-in
      |=  [=rail:tarball dir=path]
      =/  m  (fiber:fiber:nexus ,(list json))
      ^-  form:m
      ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
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
        (peek:io (nex-road:io rail [%& dir tid]) ~)
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
    ::  On crash, write error to tool state so MCP returns it.
    ::  On normal startup, continue.
    ::
    ++  rise-tool
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ?~  prod  (pure:m ~)
      %-  (slog leaf+"%mcp tool crashed" u.prod)
      ;<  st=tool-state:tools  bind:m
        (get-state-as:io ,tool-state:tools)
      ::  a finished run poked post-hoc (stray input nacked by stay)
      ::  is not a failed run — keep its result
      ?:  =(%done step.st)  (pure:m ~)
      =/  err-msg=@t  (render-tang:build u.prod)
      =/  result-data=json
        (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "crash\0a{(trip err-msg)}")]])
      (replace:io `tool-state:tools`[tool.st args.st %done data.st `result-data])
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
    ::  relative, self-locating read from its own rail); mcp cannot reach
    ::  in. So mcp pokes the child %list, the child scans its /code and
    ::  pokes the schema array straight back; mcp reshapes it into the tool
    ::  map downstream expects.
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
    ::  main.sig grub that handles the request handles the response.
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
    ++  get-app-mcp-paths
      =/  m  (fiber:fiber:nexus ,(list path))
      ^-  form:m
      ;<  apps-view=view:nexus  bind:m
        (peek:io [%& %| /apps] ~)
      ?.  ?=([%ball *] apps-view)
        (pure:m ~)
      %-  pure:m
      %+  turn  ~(tap by dir.ball.apps-view)
      |=  [nam=@ta *]
      (welp ~[%apps nam] /desk/code/lib/tools)
    ::  +await-tool: look up a compiled tool handler by name
    ::
    ::    Converts underscores to hyphens (get_ship → get-ship).
    ::    Checks root code namespace, then each app's code namespace.
    ::
    ++  await-tool
      |=  tool-name=@t
      =/  m  (fiber:fiber:nexus ,(each tool:tools tang))
      ^-  form:m
      ::  a leading slash means the tool is addressed by LOCATION —
      ::  an absolute, extensionless path to its source in any code
      ::  namespace — rather than by registry name
      ?:  =('/' (end 3 tool-name))
        =/  pax=(unit path)  (rush tool-name stap)
        ?:  |(?=(~ pax) ?=(~ u.pax))
          (pure:m [%| ~[leaf+"bad tool path: {(trip tool-name)}"]])
        ;<  got=(unit tool:tools)  bind:m
          (try-compile (snip `path`u.pax) (rear u.pax))
        ?^  got  (pure:m [%& u.got])
        (pure:m [%| ~[leaf+"no tool at {(trip tool-name)}"]])
      =/  [sub=path arm=@ta]  (name-to-place:tools tool-name)
      ;<  got=(unit tool:tools)  bind:m
        (try-compile (weld /code/lib/tools sub) arm)
      ?^  got  (pure:m [%& u.got])
      ;<  app-paths=(list path)  bind:m  get-app-mcp-paths
      |-
      ?~  app-paths
        (pure:m [%| ~[leaf+"tool not found: {(trip tool-name)}"]])
      ;<  got=(unit tool:tools)  bind:m
        (try-compile (weld i.app-paths sub) arm)
      ?^  got  (pure:m [%& u.got])
      $(app-paths t.app-paths)
    ::
    ++  try-compile
      |=  [code-path=path file-name=@ta]
      =/  m  (fiber:fiber:nexus ,(unit tool:tools))
      ^-  form:m
      ;<  res=built:nexus  bind:m  (get-code-full:io [%& %& code-path file-name])
      ?.  ?=(%vase -.res)
        (pure:m ~)
      =/  got=(each tool:tools tang)
        (mule |.(!<(tool:tools vase.res)))
      ?.  ?=(%& -.got)
        (pure:m ~)
      (pure:m `p.got)
    --
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  ::  preserve any tools added live: read the current tools/code
  ::  subtree (just the code — /runs stays a clean slate each reload) and
  ::  merge the bundle onto it, bundle winning name conflicts, so a reseed
  ::  updates bundle tools without deleting user-added ones.
  =/  existing-tools=bole:tarball
    =/  sub=(unit ball:tarball)  (~(dap ba:tarball ball) /tools/code)
    ?~  sub  *bole:tarball
    =/  code-bole=bole:tarball  (ball-to-bole:tarball u.sub)
    [`[`[/ %tools] ~ %.n ~] (malt ~[[%code code-bole]])]
  =/  tile=json
    %-  pairs:enjs:format
    :~  title+s+'Tools'
        info+s+'tool registry & runs'
        color+s+'#232630'
        image+s+'/grubbery/tiles/icon/mcp.mcp'
        href+s+'/grubbery/mcp'
    ==
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'mcp'] ['description' s+'MCP JSON-RPC endpoint for tools']])]]
      [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
      [%over %& [/ %'tile.json'] [[/ %json] tile]]
      [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
      [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
      [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
      [%over %& [/ %'marked.min.js'] [[/ %mime] ui-md]]
      [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      ::  tools: the tools child nexus instance — owns discovery and
      ::  execution. Run grubs live at /tools/runs, under its own weir
      ::  (bounded by mcp). Neck [/ %tools] (code at nex/tools.hoon — a
      ::  reusable top-level nexus any nexus can mount). %over replaces
      ::  the subtree wholesale. mcp keeps no run grubs of its own.
      [%over %| /tools (merge-boles:tools existing-tools (seed-tools:tools bundle))]
      [%over %& [/ %'README.md'] [[/ %mime] man]]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /main: failed")
    ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/mcp])
    (http-dispatch:io %mcp)
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
    ::  GET: the UI and its data endpoints. POST continues to the
    ::  JSON-RPC protocol path below, unchanged.
    =/  [site=path qargs=quay:eyre]  (parse-url:http-utils url.request.req)
    =/  suffix=path
      %+  skip  (slag (lent `path`/grubbery/mcp) site)
      |=(seg=@ta =('' seg))
    ?:  =('GET' method.request.req)
      ?:  ?=([%api %tools ~] suffix)
        ::  the FULL registry, not the three-tool protocol allowlist
        ::  that tools/list advertises to MCP clients
        ;<  dynamic=(map @t tool:tools)  bind:m  (get-dynamic-tools rail)
        (send-json eyre-id (mcp-tools-list:nex-mcp dynamic ~))
      ?:  ?=([%api %runs ~] suffix)
        ;<  runs=json  bind:m  (gather-runs rail)
        (send-json eyre-id runs)
      ?:  ?=([%api %tools-tree ~] suffix)
        ;<  tree=json  bind:m  (gather-tools-tree rail)
        (send-json eyre-id tree)
      ?:  ?=([%api %src ~] suffix)
        =/  tool-name=(unit @t)  (quay-get qargs 'tool')
        ?~  tool-name
          (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'tool required')])
        ;<  res=(unit [pax=path txt=@t])  bind:m  (find-tool-src u.tool-name)
        ?~  res
          (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'not found')])
        %+  send-json  eyre-id
        (pairs:enjs:format ~[['path' s+(spat pax.u.res)] ['text' s+txt.u.res]])
      =/  filename=@ta
        ?~  suffix  'index.html'
        i.suffix
      ;<  fv=view:nexus  bind:m
        (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
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
      ::  child's weir, not mcp's.
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
  ==
--
