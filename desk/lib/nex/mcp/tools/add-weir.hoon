::  add-weir: add a sandbox rule to a directory
::
!:
^-  tool:tools
|%
++  name  'add_weir'
++  description  'Add a sandbox (weir) rule to a directory. Categories: write, poke, read. Road types: dir, file.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory to add the weir rule to (e.g. "/mcp.mcp")']]
      ['category' [%string 'Rule category: "write", "poke", or "read"']]
      ['road_path' [%string 'Allowed road path (e.g. "/")']]
      ['road_type' [%string 'Road type: "dir" or "file"']]
  ==
++  required  ~['path' 'category' 'road_path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  weir-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  category=@t  (~(dog jo:json-utils [%o args.st]) /category so:dejs:format)
  =/  road-path=@t  (~(dog jo:json-utils [%o args.st]) /'road_path' so:dejs:format)
  =/  road-type=@t
    ?~  rt=(~(get jo:json-utils [%o args.st]) /'road_type')  'dir'
    ?.  ?=([%s *] u.rt)  'dir'
    p.u.rt
  =/  pax=path  (stab road-path)
  =/  new-road=road:tarball
    ?:  =('file' road-type)
      ?~  pax  [%& %| /]
      [%& %& (snip `path`pax) (rear pax)]
    [%& %| pax]
  =/  dir-pax=path  (stab weir-path)
  ;<  dir-seen=seen:nexus  bind:m  (peek:io /weir [%& %| dir-pax] ~)
  =/  cur=weir:nexus
    ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
    =/  dir-sand=sand:nexus  sand.p.dir-seen
    (fall fil.dir-sand [~ ~ ~])
  =/  new=weir:nexus
    ?+  category  cur
      %'write'  cur(make (~(put in make.cur) new-road))
      %'poke'   cur(poke (~(put in poke.cur) new-road))
      %'read'   cur(peek (~(put in peek.cur) new-road))
    ==
  ;<  ~  bind:m  (sand:io /weir [%& %| dir-pax] `new)
  (pure:m [%text (crip "Added {(trip category)} rule to {(trip weir-path)}")])
--
