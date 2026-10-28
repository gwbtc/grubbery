/<  tools  /lib/tools.hoon
::  add-weir: add a sandbox rule to a directory
::
!:
^-  tool:tools
|%
++  name  'add_weir'
++  description  'Add a sandbox rule (a "weir") to a directory. A weir bounds what code under that directory may reach: it grants one category of access — read, poke, or write — along one road. The road is road_path, taken as absolute unless steps_up is given, which makes it relative to this directory. road_type says whether the road names a single file or a whole directory subtree.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'the directory to add the weir rule to (e.g. "/apps/example")']]
      ['category' [%string 'the kind of access the rule grants. One of: read | poke | write.']]
      ['road_path' [%string 'the road the rule allows, a path (e.g. "/"). Absolute unless steps_up is set.']]
      ['road_type' [%string 'whether the road names one file or a directory subtree. One of: dir | file (default: dir).']]
      ['steps_up' [%number 'makes road_path relative to this directory: 1 means one level up (../), 0 means this directory (./). Omit for an absolute road.']]
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
  ::  a directory's weir lives in its parent's entry for it, so read
  ::  through the parent — peeking the directory itself never shows it
  =/  parent=path  ?~(dir-pax / (snip `path`dir-pax))
  ;<  parent-view=view:nexus  bind:m  (peek:io [%& %| parent] ~)
  =/  cur=weir:nexus
    ?~  dir-pax  [~ ~ ~]
    ?.  ?=([%ball *] parent-view)  [~ ~ ~]
    =/  child=(unit ball:tarball)
      (~(get by dir.ball.parent-view) (rear dir-pax))
    ?~  child  [~ ~ ~]
    (fall ?~(fil.u.child ~ weir.u.fil.u.child) [~ ~ ~])
  =/  new=weir:nexus
    ?+  category  cur
      %'write'  cur(make (~(put in make.cur) new-road))
      %'poke'   cur(poke (~(put in poke.cur) new-road))
      %'read'   cur(peek (~(put in peek.cur) new-road))
    ==
  ;<  ~  bind:m  (sand:io [%& %| dir-pax] `new)
  (pure:m [%text (crip "Added {(trip category)} rule to {(trip weir-path)}")])
--
