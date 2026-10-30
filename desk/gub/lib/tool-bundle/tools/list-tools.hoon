/<  tools  /lib/tools.hoon
::  list-tools: list all available MCP tools with optional filtering
::
::    Looks up compiled tools from bins via %code darts.
::    Scans root /code/lib/tools and each app's /desk/code/lib/tools.
::
=>  |%
    ++  strip-hoon
      |=  name=@ta
      ^-  @ta
      =/  t=tape  (trip name)
      =/  len=@ud  (lent t)
      ?.  (gth len 5)  name
      ?.  =(".hoon" (slag (sub len 5) t))  name
      (crip (scag (sub len 5) t))
    ++  has-substr
      |=  [needle=tape haystack=tape]
      ^-  ?
      ?~  needle  %.y
      =/  nlow=tape  (cass needle)
      =/  hlow=tape  (cass haystack)
      =/  nlen=@ud  (lent nlow)
      |-
      ?~  hlow  %.n
      ?:  =(nlow (scag nlen `tape`hlow))  %.y
      $(hlow t.hlow)
    --
!:
^-  tool:tools
|%
++  name  'list_tools'
++  description
  ^~  %-  crip
  ;:  weld
    "List the MCP tools of this nexus (or of a tools nexus named by path). "
    "This reflects the current state and includes dynamically added tools "
    "that may not appear in your cached tools/list. Use this to discover "
    "tools added via add_mcp_tool. "
    "Use 'name' to glob tool names (* wildcards), 'search' to grep "
    "descriptions (substring match). Set names_only for compact output."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'A tools nexus to list instead of this one, e.g. "/apps/nostr/tools" (its tools live at <path>/code/lib/tools). Apps say where theirs is in their readme.']]
      ['name' [%string 'Glob filter on tool names (* wildcards, e.g. "*clay*", "get_*")']]
      ['search' [%string 'Substring search in tool descriptions (case-insensitive, e.g. "clay", "custom")']]
      ['names_only' [%boolean 'If true, return only tool names (compact listing)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pat-name=(unit @t)
    ?~  p=(~(get jo:json-utils [%o args.st]) /name)  ~
    ?.  ?=([%s *] u.p)  ~
    ?:  =('' p.u.p)  ~
    `p.u.p
  =/  pat-search=(unit @t)
    ?~  p=(~(get jo:json-utils [%o args.st]) /search)  ~
    ?.  ?=([%s *] u.p)  ~
    ?:  =('' p.u.p)  ~
    `p.u.p
  =/  v  (~(get jo:json-utils [%o args.st]) /'names_only')
  =/  names-only=?
    ?~  v  %.n
    ?=([%b %.y] u.v)
  ::  Collect all code-path + name pairs to try. A ~ code-path marks a
  ::  tool in THIS nexus's own /code.
  =/  pairs=(list [path @ta])  ~
  ::  Own-nexus tools: a run grub always lives at /runs/{id}, one level
  ::  below the nexus root, so [%| 1 ...] bends up to the root and into
  ::  /code/lib/tools — placement-free, no rail needed.
  ;<  src-view=view:nexus  bind:m
    (peek:io [%| 1 [%| /code/lib/tools]] ~)
  =.  pairs
    ?.  ?=([%ball *] src-view)  pairs
    ?~  fil.ball.src-view  pairs
    %+  weld  pairs
    ^-  (list [path @ta])
    %+  turn  ~(tap by contents.u.fil.ball.src-view)
    |=  [n=@ta *]
    [~ (strip-hoon n)]
  ::  a tools nexus named by path is listed instead of this one's own
  =/  at=(unit path)
    =/  v  (~(get by args.st) 'path')
    ?.  ?=([~ %s *] v)  ~
    ?:  =('' p.u.v)  ~
    (rush p.u.v stap)
  ::  the tools nexus named by path, else only this one's own tools
  =/  nexes=(list path)  ?~(at ~ ~[u.at])
  ;<  pairs=(list [path @ta])  bind:m
    =/  m  (fiber:fiber:nexus ,(list [path @ta]))
    =/  acc=(list [path @ta])  ?^(at ~ pairs)
    |-  ^-  form:m
    ?~  nexes  (pure:m acc)
    =/  app-path=path  (welp i.nexes /code/lib/tools)
    ;<  app-src=view:nexus  bind:m  (peek:io [%& %| app-path] ~)
    =/  more=(list [path @ta])
      ?.  ?=([%ball *] app-src)  ~
      ?~  fil.ball.app-src  ~
      ^-  (list [path @ta])
      %+  turn  ~(tap by contents.u.fil.ball.app-src)
      |=  [n=@ta *]
      [app-path (strip-hoon n)]
    $(nexes t.nexes, acc (weld acc more))
  =/  app-kids=(list @ta)  ~
  |-
  ?~  app-kids
    ::  All pairs collected, now compile and filter
    =/  all-tools=(list tool:tools)  ~
    ::  broken: the lines for source files in the tools dir that produced
    ::  no usable tool. These were dropped silently, which is how
    ::  remote_peek sat missing from every ship's list with its source in
    ::  the bundle looking correct -- the count read 71 instead of 72 and
    ::  nothing named the one that went. A tool you cannot call is news.
    ::
    ::  A TAPE, not a list of [name why]: this rides through the |- below
    ::  as a loop parameter, and a structured accumulator fuses a
    ::  recursive type onto that parameter when the branch below reads it
    ::  (fuse-loop, whether the test is ?~ or =(~ ...)). A tape is built
    ::  in order, needs no flop, and carries no faces to fuse.
    =/  broken=tape  ""
    |-
    ?~  pairs
      ::  broken tools ride on EVERY answer, filters included: a name
      ::  glob that matches nothing is exactly when you want to be told
      ::  the tool you asked for is sitting there not compiling.
      =/  broke-text=tape
        ?:  =("" broken)  ""
        (weld "\0a\0aFAILED TO COMPILE -- present but unusable:" broken)
      =/  matches=(list tool:tools)
        %+  skim  all-tools
        |=  =tool:tools
        =/  name-ok=?
          ?~  pat-name  %.y
          (glob-match:tools (trip u.pat-name) (trip name:tool))
        =/  search-ok=?
          ?~  pat-search  %.y
          (has-substr (trip u.pat-search) (trip description:tool))
        &(name-ok search-ok)
      ?~  matches
        (pure:m [%text (crip "No tools found{broke-text}")])
      ?:  names-only
        =/  result=tape
          (zing (turn matches |=(=tool:tools "\0a{(trip name:tool)}")))
        (pure:m [%text (crip "{<(lent matches)>} tools:{result}{broke-text}")])
      =/  result=tape
        %-  zing
        %+  turn  matches
        |=  =tool:tools
        =/  params=(list @t)
          (turn ~(tap by parameters:tool) |=([n=@t *] n))
        =/  req=(list @t)  required:tool
        =/  out=tape
          "\0a\0a{(trip name:tool)}\0a  {(trip description:tool)}"
        =?  out  ?=(^ params)
          =/  param-text=tape
            %-  zing
            ^-  (list tape)
            (join ", " (turn params trip))
          (weld out "\0a  params: {param-text}")
        =?  out  ?=(^ req)
          =/  req-text=tape
            %-  zing
            ^-  (list tape)
            (join ", " (turn req trip))
          (weld out "\0a  required: {req-text}")
        out
      (pure:m [%text (crip "{<(lent matches)>} tools found:{result}{broke-text}")])
    =/  [cp=path n=@ta]  `[path @ta]`i.pairs
    =/  tool-road=road:tarball
      ?^  cp  [%& %& cp n]
      [%| 1 [%& /code/lib/tools n]]
    ;<  res=built:nexus  bind:m  (get-code-full:io tool-road)
    ::  +built is [%vase *], [%tang *] or [%mime *]: a failed build keeps
    ::  its trace as the tang. Say so and name the file; check_bin on it
    ::  prints the trace itself.
    ?.  ?=(%vase -.res)
      =/  why=tape
        ?:  ?=(%tang -.res)  "did not compile; check_bin it for the trace"
        "no compiled artifact"
      $(pairs t.pairs, broken (weld broken "\0a  {(trip n)}  --  {why}"))
    =/  got=(each tool:tools tang)
      (mule |.(!<(tool:tools vase.res)))
    ?.  ?=(%& -.got)
      %=  $
        pairs   t.pairs
        broken  (weld broken "\0a  {(trip n)}  --  compiled, but does not nest as a tool")
      ==
    $(pairs t.pairs, all-tools [p.got all-tools])
  $(app-kids t.app-kids)
--
