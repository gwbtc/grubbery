/<  tools  /lib/tools.hoon
::  list-tools: list all available MCP tools with optional filtering
::
::    Looks up compiled tools from bins via %code darts.
::    Scans root /code/lib/mcp and each app's /desk/code/lib/mcp.
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
    "List all available MCP tools from the live compiled tool registry. "
    "This reflects the current state and includes dynamically added tools "
    "that may not appear in your cached tools/list. Use this to discover "
    "tools added via add_mcp_tool. "
    "Use 'name' to glob tool names (* wildcards), 'search' to grep "
    "descriptions (substring match). Set names_only for compact output."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'Glob filter on tool names (* wildcards, e.g. "*clay*", "get_*")']]
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
  ::  Collect all code-path + name pairs to try
  =/  pairs=(list [path @ta])  ~
  ::  Root namespace tools
  ;<  src-view=view:nexus  bind:m
    (peek:io [%& %| /code/lib/mcp] ~)
  =.  pairs
    ?.  ?=([%ball *] src-view)  pairs
    ?~  fil.ball.src-view  pairs
    %+  weld  pairs
    ^-  (list [path @ta])
    %+  turn  ~(tap by contents.u.fil.ball.src-view)
    |=  [n=@ta *]
    [/code/lib/mcp (strip-hoon n)]
  ::  App namespace tools
  ;<  apps-view=view:nexus  bind:m
    (peek:io [%& %| /apps] ~)
  =/  app-kids=(list @ta)
    ?.  ?=([%ball *] apps-view)  ~
    (turn ~(tap by dir.ball.apps-view) |=([nam=@ta *] nam))
  |-
  ?~  app-kids
    ::  All pairs collected, now compile and filter
    =/  all-tools=(list tool:tools)  ~
    |-
    ?~  pairs
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
        (pure:m [%text 'No tools found'])
      ?:  names-only
        =/  result=tape
          (zing (turn matches |=(=tool:tools "\0a{(trip name:tool)}")))
        (pure:m [%text (crip "{<(lent matches)>} tools:{result}")])
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
      (pure:m [%text (crip "{<(lent matches)>} tools found:{result}")])
    =/  [cp=path n=@ta]  `[path @ta]`i.pairs
    ;<  res=built:nexus  bind:m  (get-code-full:io [%& %& cp n])
    ?.  ?=(%vase -.res)  $(pairs t.pairs)
    =/  got=(each tool:tools tang)
      (mule |.(!<(tool:tools vase.res)))
    ?.  ?=(%& -.got)  $(pairs t.pairs)
    $(pairs t.pairs, all-tools [p.got all-tools])
  ::  Peek this app's mcp dir and add any tool sources
  =/  app-path=path  (welp ~[%apps i.app-kids] /desk/code/lib/mcp)
  ;<  app-src=view:nexus  bind:m
    (peek:io [%& %| app-path] ~)
  =.  pairs
    ?.  ?=([%ball *] app-src)  pairs
    ?~  fil.ball.app-src  pairs
    %+  weld  pairs
    ^-  (list [path @ta])
    %+  turn  ~(tap by contents.u.fil.ball.app-src)
    |=  [n=@ta *]
    [app-path (strip-hoon n)]
  $(app-kids t.app-kids)
--
