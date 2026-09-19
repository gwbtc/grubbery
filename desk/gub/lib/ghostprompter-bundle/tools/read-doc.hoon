/<  tools  /lib/tools.hoon
::  read_doc: one library document's text, by name (as list_library
::  prints it). Documents are mime grubs — markdown, notes, extracted
::  pdf text.
::
!:
^-  tool:tools
|%
++  name  'read_doc'
++  description  'Read one library document in full by name (from list_library).'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'the document name, e.g. notes.md']]
  ==
++  required  ~['name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  nm=@t
    =/  v  (~(get by args.st) 'name')
    ?:(?=([~ %s *] v) p.u.v '')
  ?:  =('' nm)  (pure:m [%error 'name is required'])
  ;<  fv=view:nexus  bind:m
    (peek:io [%& %& /apps/ghostprompter/library `@ta`nm] `[/ %mime])
  ?.  ?=([%file *] fv)
    (pure:m [%error (cat 3 'no such document: ' nm)])
  =/  =mime  !<(mime (need-vase:tarball sang.fv))
  (pure:m [%text `@t`q.q.mime])
--
