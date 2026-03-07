::  list-clay-files: list files in Clay under a given path
::
!:
^-  tool:tools
|%
++  name  'list_clay_files'
++  description  'List files in Clay under a given path'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name (e.g. "base")']]
      ['path' [%string 'Path to list (e.g. "/" or "/gen")']]
  ==
++  required  ~['desk' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  desk=@t  (~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)
  =/  file-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  dek=@tas  (slav %tas desk)
  =/  pax=path  (stab file-path)
  ;<  files=(list path)  bind:m
    (do-scry:io (list path) /scry [%ct dek pax])
  =/  result=tape
    %-  zing
    %+  turn  files
    |=(p=path "{(spud p)}\0a")
  (pure:m [%text (crip result)])
--
