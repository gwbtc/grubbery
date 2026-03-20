::  list-tools: list all available MCP tools with optional filtering
::
::    Returns live tool data from /bin/ — includes dynamically added
::    tools that may not be in the MCP client's cached tools/list.
::
=>  |%
    ++  collect-all
      |=  b=ball:tarball
      ^-  (list tool:tools)
      =/  result=(list tool:tools)  ~
      =/  dirs=(list @ta)  ~[%std %cus]
      |-
      ?~  dirs  result
      =/  sub=ball:tarball  (~(gut by dir.b) i.dirs *ball:tarball)
      =.  result  (weld result (collect-from sub))
      $(dirs t.dirs)
    ::
    ++  collect-from
      |=  b=ball:tarball
      ^-  (list tool:tools)
      =/  result=(list tool:tools)  ~
      ::  Files in this directory
      =?  result  ?=(^ fil.b)
        =/  files=(list [@ta content:tarball])
          ~(tap by contents.u.fil.b)
        |-
        ?~  files  result
        =/  [* =content:tarball]  i.files
        ?.  =(%temp p.cage.content)  $(files t.files)
        =/  got=(each tool:tools tang)
          (mule |.(!<(tool:tools q.cage.content)))
        ?.  ?=(%& -.got)  $(files t.files)
        $(files t.files, result [p.got result])
      ::  Recurse into subdirectories
      =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
      |-
      ?~  dirs  result
      =/  [* sub=ball:tarball]  i.dirs
      $(dirs t.dirs, result (weld result (collect-from sub)))
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
  ::  Peek /bin/ to get all compiled tools
  ;<  bin-seen=seen:nexus  bind:m  (peek:io /bin [%| 1 %| /bin] ~)
  ?.  ?=([%& %ball *] bin-seen)
    (pure:m [%error 'Could not read /bin/'])
  =/  all-tools=(list tool:tools)
    (collect-all ball.p.bin-seen)
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
--
