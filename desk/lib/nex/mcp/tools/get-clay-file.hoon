::  get-clay-file: fetch a file from Clay and return its contents
::
!:
^-  tool:tools
|%
++  name  'get_clay_file'
++  description  'Fetch a file from Clay and return its contents as text'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name (e.g. "base")']]
      ['path' [%string 'File path (e.g. "/gen/hood/commit/hoon")']]
  ==
++  required  ~['desk' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  [desk=@t file-path=@t]
    %.  [%o args.st]
    %-  ot:dejs:format
    :~  ['desk' so:dejs:format]
        ['path' so:dejs:format]
    ==
  =/  dek=@tas  (slav %tas desk)
  =/  pax=path  (stab file-path)
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  ;<  =riot:clay  bind:m
    (warp:io our.bowl dek ~ %sing %x da+now.bowl pax)
  ?~  riot
    (pure:m [%error 'File not found'])
  =/  =tang  (pretty-file:pretty-file:tools !<(noun q.r.u.riot))
  =/  =wain
    %-  zing
    %+  turn  tang
    |=(=tank (turn (wash [0 160] tank) crip))
  (pure:m [%text (of-wain:format wain)])
--
