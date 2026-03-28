::  marks: marc builder
::
::  Compiles mark source cores into marc:tarball dispatch cores.
::  All slap/slob introspection happens at build time.
::
/+  nexus, tarball
|%
::  +build-marc: compile a mark source core into a marc dispatch core
::
::  Takes the mark's own name, its compiled vase, and all mark core vases
::  in scope.  Returns a marc with vale/grow/grab gates.
::
++  build-marc
  |=  [mak=mark cor=vase cores=(map mark vase)]
  ^-  marc:tarball
  :+  (build-vale cor)
    (build-grow mak cor cores)
  (build-grab mak cor cores)
::  +build-vale: extract noun validator from a mark core
::
::  Pulls +noun:grab from the mark core as a $-(* vase) gate.
::
++  build-vale
  |=  cor=vase
  ^-  $-(* vase)
  =/  gat=vase
    (slap cor !,(*hoon |=(noun=* (noun:grab noun))))
  |=(noun=* (slam gat !>(noun)))
::  +build-grow: build a dispatch gate for outbound conversions
::
::  Returns a gate that takes a target mark and produces a tube.
::  Closes over available mark cores for intermediary resolution.
::
++  build-grow
  |=  [mak=mark cor=vase cores=(map mark vase)]
  ^-  $-(mark tube:clay)
  |=  to=mark
  ^-  tube:clay
  =/  gat=vase  (build-cast cores mak to ~)
  =>([gat=gat ..zuse] |=(v=vase (slam gat v)))
::  +build-grab: build a dispatch gate for inbound conversions
::
::  Returns a gate that takes a source mark and produces a tube.
::  Closes over available mark cores for intermediary resolution.
::
++  build-grab
  |=  [mak=mark cor=vase cores=(map mark vase)]
  ^-  $-(mark tube:clay)
  |=  from=mark
  ^-  tube:clay
  =/  gat=vase  (build-cast cores from mak ~)
  =>([gat=gat ..zuse] |=(v=vase (slam gat v)))
::  +build-cast: produce a gate to convert mark a to mark b
::
::  Reproduces Clay's +build-cast priority:
::  1. Identity (a == b)
::  2. %mime -> %hoon shortcut
::  3. +b:grow on source mark
::  4. +a:grab on target mark (direct gate)
::  5. +jump on source mark (intermediary)
::  6. +grab return as intermediary mark
::  7. Anything -> %noun is identity
::
++  build-cast
  |=  [cores=(map mark vase) a=mark b=mark cycle=(set mars:clay)]
  ^-  vase
  ?:  (~(has in cycle) [a b])
    ~|(cycle+cast+[a b] !!)
  =.  cycle  (~(put in cycle) [a b])
  ?:  =(a b)  !>(same)
  ?:  =([%mime %hoon] [a b])
    !>(|=(m=mime q.q.m))
  =/  old=vase  (~(got by cores) a)
  ?:  (has-arm %grow b old)
    %+  slap  (with-faces cor+old ~)
    ^-  hoon
    :+  %brcl  !,(*hoon v=+<.cor)
    :+  %tsgl  limb/b
    !,(*hoon ~(grow cor v))
  =/  new=vase  (~(got by cores) b)
  =/  arm=?  (has-arm %grab a new)
  =/  rab
    %-  mule  |.
    (slap new tsgl/[limb/a limb/%grab])
  ?:  &(arm ?=(%& -.rab) ?=(^ q.p.rab))
    p.rab
  =/  jum  (mule |.((slap old tsgl/[limb/b limb/%jump])))
  ?:  &((slob %jump -:old) ?=(%& -.jum))
    =/  via  !<(mark p.jum)
    (compose-casts cores a via b cycle)
  ?:  &(arm ?=(%& -.rab))
    =/  via  !<(mark p.rab)
    (compose-casts cores a via b cycle)
  ?:  ?=(%noun b)  !>(same)
  ~|(no-cast-from+[a b] !!)
::
++  compose-casts
  |=  [cores=(map mark vase) a=mark y=mark b=mark cycle=(set mars:clay)]
  ^-  vase
  =/  uno=vase  (build-cast cores a y cycle)
  =/  dos=vase  (build-cast cores y b cycle)
  %+  slap
    (with-faces uno+uno dos+dos ~)
  !,(*hoon |=(_+<.uno (dos (uno +<))))
::
++  has-arm
  |=  [arm=@tas =mark core=vase]
  ^-  ?
  =/  rib  (mule |.((slap core [%wing ~[arm]])))
  ?:  ?=(%| -.rib)  %.n
  =/  lab  (mule |.((slob mark p.p.rib)))
  ?:  ?=(%| -.lab)  %.n
  p.lab
::
++  with-face
  |=  [face=@tas =vase]
  vase(p [%face face p.vase])
::
++  with-faces
  =|  res=(unit vase)
  |=  vaz=(list [face=@tas =vase])
  ^-  vase
  ?~  vaz  (need res)
  =/  faz  (with-face i.vaz)
  =.  res  `?~(res faz (slop faz u.res))
  $(vaz t.vaz)
::  +tube-from: build a tube from raw mark cores (used at compile time)
::
++  tube-from
  |=  [=mars:clay cores=(map mark vase)]
  ^-  tube:clay
  =/  gat=vase  (build-cast cores a.mars b.mars ~)
  =>([gat=gat ..zuse] |=(v=vase (slam gat v)))
--
