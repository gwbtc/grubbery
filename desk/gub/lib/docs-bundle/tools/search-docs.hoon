/<  tools  /lib/tools.hoon
/<  dm     /lib/docs-mirror.hoon
::  search_docs: full-text search the handbook. Reads the shell's local MIRROR
::  of the registered collection's handbook (man/docs) — the same copy the
::  reader sees. The collection is resolved from the registry, so nothing here
::  names a specific desk.
::
=>  |%
    ++  find-snippet
      |=  [text=@t q=tape]
      ^-  (unit tape)
      =/  lines=(list @t)  (to-wain:format text)
      |-  ^-  (unit tape)
      ?~  lines  ~
      ?.  =(~ (find q (cass (trip i.lines))))
        `(scag 200 (trip i.lines))
      $(lines t.lines)
    --
!:
^-  tool:tools
|%
++  name  'search_docs'
++  description
  'Full-text search the handbook docs. Returns matching doc filenames and the first matching line of each.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['query' [%string 'the text to search for']]
  ==
++  required  ~['query']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  q=(unit @t)  (~(deg jo:json-utils [%o args.st]) /query so:dejs:format)
  ?~  q  (pure:m [%error 'Missing required argument: query'])
  =/  qlow=tape  (cass (trip u.q))
  ?:  =(~ qlow)  (pure:m [%text 'Empty query.'])
  ::  resolve the collection's handbook root from the registry
  ;<  tv=view:nexus  bind:m  (peek:io targets-road:dm `[/ %json])
  =/  tg=json
    ?.  ?=([%file *] tv)  [%a ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.tv)))) [%a ~])
  =/  rt  (roots-from:dm tg)
  ?~  rt  (pure:m [%error 'No documented collection is registered.'])
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| doc.u.rt] ~)
  =/  cs
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    contents.u.fil.ball.dv
  =/  names=(list @ta)  (skim ~(tap in ~(key by cs)) is-md:dm)
  =|  hits=(list tape)
  |-  ^-  form:m
  ?~  names
    ?~  hits  (pure:m [%text 'No matching docs.'])
    (pure:m [%text (crip (zing (turn (flop hits) |=(l=tape (weld l "\0a")))))])
  =/  entry  (~(get by cs) i.names)
  ?~  entry  $(names t.names)
  =/  txt=(unit @t)  (src-of:dm sang.u.entry)
  ?~  txt  $(names t.names)
  =/  snip=(unit tape)  (find-snippet u.txt qlow)
  ?~  snip  $(names t.names)
  $(names t.names, hits [:(weld (trip i.names) ": " u.snip) hits])
--
