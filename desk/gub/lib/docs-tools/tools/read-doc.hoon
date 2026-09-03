/<  tools  /lib/tools.hoon
::  read_doc: read one Grubbery doc in full. Peeks the docs directory
::  directly; the host agent's weir clamps this to /docs.
::
!:
^-  tool:tools
|%
++  name  'read_doc'
++  description  'Read one Grubbery doc in full by filename (e.g. "intro.md").'
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
  ;<  fv=view:nexus  bind:m
    (peek:io [%& %& /apps/'shell.shell'/docs `@ta`u.p] `[/ %mime])
  ?.  ?=([%file *] fv)
    (pure:m [%error (crip "No doc at {(trip u.p)}")])
  =/  txt=@t  `@t`q.q:!<(mime (need-vase:tarball sang.fv))
  (pure:m [%text txt])
--
