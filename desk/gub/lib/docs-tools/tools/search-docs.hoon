/<  tools  /lib/tools.hoon
::  search_docs: full-text search the Grubbery handbook. Peeks the docs
::  directory directly; the host agent's weir clamps this to /docs.
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
  'Full-text search the Grubbery docs. Returns matching doc filenames and the first matching line of each.'
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
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| /apps/'shell.shell'/docs] ~)
  =/  cs
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    contents.u.fil.ball.dv
  =/  names=(list @ta)  ~(tap in ~(key by cs))
  =|  hits=(list tape)
  |-  ^-  form:m
  ?~  names
    ?~  hits  (pure:m [%text 'No matching docs.'])
    (pure:m [%text (crip (zing (turn (flop hits) |=(l=tape (weld l "\0a")))))])
  =/  entry  (~(get by cs) i.names)
  ?~  entry  $(names t.names)
  ?:  (is-boom:tarball sang.u.entry)  $(names t.names)
  =/  txt=@t
    =/  r=(each mime tang)  (mule |.(!<(mime (need-vase:tarball sang.u.entry))))
    ?:(?=(%| -.r) '' `@t`q.q.p.r)
  =/  snip=(unit tape)  (find-snippet txt qlow)
  ?~  snip  $(names t.names)
  $(names t.names, hits [:(weld (trip i.names) ": " u.snip) hits])
--
