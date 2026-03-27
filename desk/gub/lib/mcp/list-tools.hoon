/<  tools  /lib/nex/tools.hoon
::  list-tools: list all available MCP tools with optional filtering
::
::    Looks up compiled tools from bins via %code darts.
::
=>  |%
    ::  +strip-hoon: remove .hoon suffix from filename
    ::
    ++  strip-hoon
      |=  name=@ta
      ^-  @ta
      =/  t=tape  (trip name)
      =/  len=@ud  (lent t)
      ?.  (gth len 5)  name
      ?.  =(".hoon" (slag (sub len 5) t))  name
      (crip (scag (sub len 5) t))
    ::  +has-substr: case-insensitive substring search
    ::
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
  ::  Peek ball mirror for tool source filenames
  ;<  src-seen=seen:nexus  bind:m
    (peek:io /src [%& %| /code/lib/mcp] ~)
  ?.  ?=([%& %ball *] src-seen)
    (pure:m [%error 'No tool sources found'])
  ?~  fil.ball.p.src-seen
    (pure:m [%error 'No tool sources found'])
  =/  src-names=(list @ta)
    %+  turn  ~(tap by contents.u.fil.ball.p.src-seen)
    |=([n=@ta *] (strip-hoon n))
  ::  Look up each compiled tool from bins
  =/  all-tools=(list tool:tools)  ~
  |-
  ?~  src-names
    ::  Filter by name glob and description search
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
  =/  n=@ta  i.src-names
  ;<  res=built:nexus  bind:m  (get-code-full:io /tool [%& %& /code/lib/mcp n])
  ?.  ?=(%vase -.res)  $(src-names t.src-names)
  =/  got=(each tool:tools tang)
    (mule |.(!<(tool:tools vase.res)))
  ?.  ?=(%& -.got)  $(src-names t.src-names)
  $(src-names t.src-names, all-tools [p.got all-tools])
--
