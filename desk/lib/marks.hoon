::  marks: tube and vale builder
::
::  Reproduces Clay's tube-building logic.
::  Tube gates are composed from grab/grow arms using slap/slam/slob,
::  exactly as Clay does internally in +build-cast.
::
/+  nexus, tarball
|%
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
::  +build-tube: build a $-(vase vase) tube gate from mark cores
::
++  build-tube
  |=  [cores=(map mark vase) =mars:clay]
  ^-  tube:clay
  =/  gat=vase  (build-cast cores a.mars b.mars ~)
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
::  +tube-from: build a tube from mark cores
::
++  tube-from
  |=  [=mars:clay cores=(map mark vase)]
  ^-  tube:clay
  (build-tube cores mars)
::  +tube: build a tube from a list of [mark vase] deps
::
++  tube
  |=  [=mars:clay deps=(list [mark vase])]
  ^-  tube:clay
  (tube-from mars (~(gas by *(map mark vase)) deps))
--
