/<  tools  /lib/tools.hoon
/<  dm     /lib/docs-mirror.hoon
::  read_doc: read one handbook doc in full by filename, from the shell's local
::  MIRROR of the registered collection's handbook (man/docs).
::
!:
^-  tool:tools
|%
++  name  'read_doc'
++  description  'Read one handbook doc in full by filename (e.g. "intro.md").'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'the doc filename, e.g. intro.md']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  p=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  ?~  p  (pure:m [%error 'Missing required argument: path'])
  ;<  tv=view:nexus  bind:m  (peek:io targets-road:dm `[/ %json])
  =/  tg=json
    ?.  ?=([%file *] tv)  [%a ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.tv)))) [%a ~])
  =/  rt  (roots-from:dm tg)
  ?~  rt  (pure:m [%error 'No documented collection is registered.'])
  ;<  fv=view:nexus  bind:m  (peek:io [%& %& doc.u.rt `@ta`u.p] ~)
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No doc at {(trip u.p)}")])
  =/  txt=(unit @t)  (src-of:dm sang.fv)
  ?~  txt  (pure:m [%error (crip "Could not read {(trip u.p)}")])
  (pure:m [%text u.txt])
--
