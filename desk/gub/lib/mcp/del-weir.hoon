/<  tools  /lib/nex/tools.hoon
::  del-weir: remove a sandbox rule from a directory
::
!:
^-  tool:tools
|%
++  name  'del_weir'
++  description  'Remove a sandbox (weir) rule from a directory'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory to remove the weir rule from']]
      ['category' [%string 'Rule category: "write", "poke", or "read"']]
      ['road_path' [%string 'Road path to remove']]
      ['road_type' [%string 'Road type: "dir" or "file"']]
      ['steps_up' [%string 'Steps up for relative road (e.g. "1"). Omit for absolute road.']]
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
  =/  del-road=road:tarball
    ?^  steps-up
      ?:  =('file' road-type)
        ?~  pax  [%| u.steps-up %| /]
        [%| u.steps-up %& (snip `path`pax) (rear pax)]
      [%| u.steps-up %| pax]
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
    =/  dir-sand=sand:nexus  sand.p.dir-seen
    (fall fil.dir-sand [~ ~ ~])
  =/  new=weir:nexus
    ?+  category  cur
      %'write'  cur(make (~(del in make.cur) del-road))
      %'poke'   cur(poke (~(del in poke.cur) del-road))
      %'read'   cur(peek (~(del in peek.cur) del-road))
    ==
  ;<  ~  bind:m  (sand:io [%& %| dir-pax] `new)
  (pure:m [%text (crip "Removed {(trip category)} rule from {(trip weir-path)}")])
--
