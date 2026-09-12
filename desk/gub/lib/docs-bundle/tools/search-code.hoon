/<  tools  /lib/tools.hoon
::  search_code: grep the Grubbery source tree (root /code nexus). Pulls
::  source straight from the ball, so no per-file re-peek. The host agent's
::  weir clamps reads to /code.
::
=>  |%
    ::  +src-of: the text of a source-ish grub, or ~ (booms, binaries).
    ++  src-of
      |=  =sang:tarball
      ^-  (unit @t)
      ?:  (is-boom:tarball sang)  ~
      =/  mk=@ta  name.p.sang
      ?.  ?|(=(%hoon mk) =(%txt mk) =(%md mk) =(%json mk))  ~
      =/  r=(each @t tang)  (mule |.(!<(@t (need-vase:tarball sang))))
      ?:(?=(%| -.r) ~ `p.r)
    --
!:
^-  tool:tools
|%
++  name  'search_code'
++  description
  'Search the Grubbery source tree (the root /code nexus) for a string. Returns matching lines with file paths and line numbers. Optionally filter files by a path glob.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['pattern' [%string 'text to search for']]
      ['path' [%string 'optional path glob to filter files, e.g. /lib/* or *nexus*']]
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
  ;<  view=view:nexus  bind:m  (peek:io [%& %| /code] ~)
  ?.  ?=([%ball *] view)  (pure:m [%error 'could not read /code'])
  =/  files=(list [=rail:tarball =sang:tarball])  ~(tap ba:tarball ball.view)
  =|  hits=(list tape)
  |-  ^-  form:m
  ?~  files
    ?~  hits  (pure:m [%text 'No matches found in /code.'])
    (pure:m [%text (crip (zing (turn (flop hits) |=(l=tape (weld l "\0a")))))])
  ?:  (gte (lent hits) 60)
    =/  body=tape  (zing (turn (flop hits) |=(l=tape (weld l "\0a"))))
    (pure:m [%text (crip (weld body "\0a… (truncated at 60 matches)"))])
  =/  fpath=tape  (spud (snoc path.rail.i.files name.rail.i.files))
  ?.  ?|(?=(~ pfilt) (glob-match:tools u.pfilt fpath))  $(files t.files)
  =/  src=(unit @t)  (src-of sang.i.files)
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
