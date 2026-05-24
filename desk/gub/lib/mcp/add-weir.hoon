/<  tools  /lib/nex/tools.hoon
::  add-weir: add a sandbox rule to a directory
::
!:
^-  tool:tools
|%
++  name  'add_weir'
++  description  'Add a sandbox (weir) rule to a directory. Categories: write, poke, read. Road types: dir, file. Use steps_up for relative roads.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory to add the weir rule to (e.g. "/mcp.mcp")']]
      ['category' [%string 'Rule category: "write", "poke", or "read"']]
      ['road_path' [%string 'Allowed road path (e.g. "/")']]
      ['road_type' [%string 'Road type: "dir" or "file"']]
      ['steps_up' [%string 'Steps up for relative road (e.g. "1" means ../, "0" means ./). Omit for absolute road.']]
  ==
++  required  ~['path' 'category' 'road_path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t @t] tang)
    %-  mule  |.
    :+  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
      (~(dog jo:json-utils [%o args.st]) /category so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /'road_path' so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, category, road_path)'])
  =/  [weir-path=@t category=@t road-path=@t]  p.parsed
  =/  road-type=@t
    ?~  rt=(~(get jo:json-utils [%o args.st]) /'road_type')  'dir'
    ?.  ?=([%s *] u.rt)  'dir'
    p.u.rt
  =/  steps-up=(unit @ud)
    ?~  su=(~(get jo:json-utils [%o args.st]) /'steps_up')  ~
    ?.  ?=([%s *] u.su)  ~
    `(rash p.u.su dem)
  =/  pax=path
    =/  t=tape  (trip road-path)
    =/  clean=tape  ?:(&(!=(~ t) =('/' (rear t))) (snip t) t)
    ?~  clean  /
    (stab (crip clean))
  =/  new-road=road:tarball
    ?^  steps-up
      ::  relative road (bend): steps up + lane
      ?:  =('file' road-type)
        ?~  pax  [%| u.steps-up %| /]
        [%| u.steps-up %& (snip `path`pax) (rear pax)]
      [%| u.steps-up %| pax]
    ::  absolute road
    ?:  =('file' road-type)
      ?~  pax  [%& %| /]
      [%& %& (snip `path`pax) (rear pax)]
    [%& %| pax]
  =/  dir-pax=path
    =/  t=tape  (trip weir-path)
    =/  clean=tape  ?:(&(!=(~ t) =('/' (rear t))) (snip t) t)
    ?~  clean  /
    (stab (crip clean))
  ;<  dir-seen=seen:nexus  bind:m  (peek:io [%& %| dir-pax] ~)
  =/  cur=weir:nexus
    ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
    (fall ?~(fil.ball.p.dir-seen ~ weir.u.fil.ball.p.dir-seen) [~ ~ ~])
  =/  new=weir:nexus
    ?+  category  cur
      %'write'  cur(make (~(put in make.cur) new-road))
      %'poke'   cur(poke (~(put in poke.cur) new-road))
      %'read'   cur(peek (~(put in peek.cur) new-road))
    ==
  ;<  ~  bind:m  (sand:io [%& %| dir-pax] `new)
  (pure:m [%text (crip "Added {(trip category)} rule to {(trip weir-path)}")])
--
