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
  =/  desk=(unit @t)  (~(deg jo:json-utils [%o args.st]) /desk so:dejs:format)
  =/  file-path=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  ?~  desk
    (pure:m [%error 'Missing required argument: desk'])
  ?~  file-path
    (pure:m [%error 'Missing required argument: path'])
  =/  dek=(unit @tas)  (slaw %tas u.desk)
  ?~  dek
    (pure:m [%error (crip "Invalid desk name: {(trip u.desk)}")])
  =/  pax=path  (stab u.file-path)
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  ;<  =riot:clay  bind:m
    (warp:io our.bowl u.dek ~ %sing %x da+now.bowl pax)
  ?~  riot
    (pure:m [%error 'File not found'])
  =/  =tang  (pretty-file:pretty-file:tools !<(noun q.r.u.riot))
  =/  =wain
    %-  zing
    %+  turn  tang
    |=(=tank (turn (wash [0 160] tank) crip))
  (pure:m [%text (of-wain:format wain)])
--
