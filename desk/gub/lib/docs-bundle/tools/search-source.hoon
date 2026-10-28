/<  tools  /lib/tools.hoon
/<  dm     /lib/docs-mirror.hoon
::  search_source: grep the documented target's SOURCE — the shell's local
::  mirror of the whole target (for a Clay-desk target, the entire desk: hoon,
::  marks, sys files). Pulls source straight from the mirror ball. Paths are
::  relative to the collection root. The collection comes from the registry.
::
!:
^-  tool:tools
|%
++  name  'search_source'
++  description
  'Search the source of the documented target (the whole mirrored desk — .hoon, marks, sys files) for a string. Returns matching lines with file paths and line numbers. Optionally filter files by a path glob, e.g. /gub/lib/* or *nexus*.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['pattern' [%string 'text to search for']]
      ['path' [%string 'optional path glob to filter files, e.g. /gub/lib/* or *nexus*']]
  ==
++  required  ~['pattern']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pat=(unit @t)  (~(deg jo:json-utils [%o args.st]) /pattern so:dejs:format)
  ?~  pat  (pure:m [%error 'Missing required argument: pattern'])
  =/  needle=tape  (trip u.pat)
  =/  pfilt=(unit tape)
    =/  pp=(unit json)  (~(get jo:json-utils [%o args.st]) /path)
    ?.  ?=([~ %s *] pp)  ~
    ?:(=('' p.u.pp) ~ `(trip p.u.pp))
  ;<  tv=view:nexus  bind:m  (peek:io targets-road:dm `[/ %json])
  =/  tg=json
    ?.  ?=([%file *] tv)  [%a ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.tv)))) [%a ~])
  =/  rt  (roots-from:dm tg)
  ?~  rt  (pure:m [%error 'No documented collection is registered.'])
  ;<  view=view:nexus  bind:m  (peek:io [%& %| src.u.rt] ~)
  ?.  ?=([%ball *] view)  (pure:m [%error 'could not read the mirrored source'])
  =/  files=(list [=rail:tarball =sang:tarball])  ~(tap ba:tarball ball.view)
  =|  hits=(list tape)
  |-  ^-  form:m
  ?~  files
    ?~  hits  (pure:m [%text 'No matches found.'])
    (pure:m [%text (crip (zing (turn (flop hits) |=(l=tape (weld l "\0a")))))])
  ?:  (gte (lent hits) 60)
    =/  body=tape  (zing (turn (flop hits) |=(l=tape (weld l "\0a"))))
    (pure:m [%text (crip (weld body "\0a… (truncated at 60 matches)"))])
  =/  fpath=tape  (spud (snoc path.rail.i.files name.rail.i.files))
  ?.  ?|(?=(~ pfilt) (glob-match:tools u.pfilt fpath))  $(files t.files)
  =/  src=(unit @t)  (src-of:dm sang.i.files)
  ?~  src  $(files t.files)
  =/  fh=(list tape)
    =/  lines=(list @t)  (to-wain:format u.src)
    =/  n=@ud  1
    =|  acc=(list tape)
    |-  ^-  (list tape)
    ?~  lines  (flop acc)
    =?  acc  !=(~ (find needle (trip i.lines)))
      :_  acc
      "{fpath}:{(a-co:co n)}: {(trip i.lines)}"
    $(lines t.lines, n +(n))
  $(files t.files, hits (weld (flop fh) hits))
--
