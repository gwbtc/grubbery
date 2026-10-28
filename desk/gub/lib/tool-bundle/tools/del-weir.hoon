/<  tools  /lib/tools.hoon
::  del-weir: remove a sandbox rule from a directory
::
!:
^-  tool:tools
|%
++  name  'del_weir'
++  description  'Remove a sandbox rule (a "weir") from a directory. Identifies the rule to remove exactly as add_weir created it: by its category, road_path, and road_type on the given directory. See add_weir for what a weir bounds.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'the directory to remove the weir rule from (e.g. "/apps/example")']]
      ['category' [%string 'the category of the rule to remove. One of: read | poke | write.']]
      ['road_path' [%string 'the road_path of the rule to remove; must match how it was added']]
      ['road_type' [%string 'the road_type of the rule to remove. One of: dir | file (default: dir).']]
      ['steps_up' [%number 'the steps_up of the rule to remove, if it was added as a relative road. Omit for an absolute road.']]
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
    =/  su  (~(get jo:json-utils [%o args.st]) /'steps_up')
    ?~  su  ~
    ?+  u.su  ~
      [%s *]  `(rash p.u.su dem)
      [%n *]  `(rash p.u.su dem)
    ==
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
  ;<  dir-view=view:nexus  bind:m  (peek:io [%& %| dir-pax] ~)
  =/  cur=weir:nexus
    ?.  ?=([%ball *] dir-view)  [~ ~ ~]
    (fall ?~(fil.ball.dir-view ~ weir.u.fil.ball.dir-view) [~ ~ ~])
  =/  new=weir:nexus
    ?+  category  cur
      %'write'  cur(make (~(del in make.cur) del-road))
      %'poke'   cur(poke (~(del in poke.cur) del-road))
      %'read'   cur(peek (~(del in peek.cur) del-road))
    ==
  ;<  ~  bind:m  (sand:io [%& %| dir-pax] `new)
  (pure:m [%text (crip "Removed {(trip category)} rule from {(trip weir-path)}")])
--
