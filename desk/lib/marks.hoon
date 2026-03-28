::  marks: marc builder
::
::  Compiles a mark source core into a marc:tarball dispatch core.
::  Each marc is a pure function of its own source — no dependency on
::  other marks.  Transitive conversion chains are the caller's job.
::
/+  nexus, tarball
|%
::  +build-marc: compile a mark source core into a marc dispatch core
::
++  build-marc
  |=  cor=vase
  ^-  marc:tarball
  |%
  ++  vale  (build-vale cor)
  ++  grow  (build-grow cor)
  ++  grab  (build-grab cor)
  --
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
::  +build-grow: build dispatch gate for outbound conversions
::
::  Returns a gate: given a target blot, produce a tube.
::  Converts blot to arm name via rail-to-arm for the slap.
::
++  build-grow
  |=  cor=vase
  ^-  $-(blot:tarball tube:clay)
  |=  to=blot:tarball
  ^-  tube:clay
  =/  arm=@tas  (rail-to-arm:tarball to)
  =/  gat=vase
    %+  slap  (with-faces cor+cor ~)
    ^-  hoon
    :+  %brcl  !,(*hoon v=+<.cor)
    :+  %tsgl  [%limb arm]
    !,(*hoon ~(grow cor v))
  =>([gat=gat ..zuse] |=(v=vase (slam gat v)))
::  +build-grab: build dispatch gate for inbound conversions
::
::  Returns a gate: given a source blot, produce a tube.
::  Converts blot to arm name via rail-to-arm for the slap.
::
++  build-grab
  |=  cor=vase
  ^-  $-(blot:tarball tube:clay)
  |=  from=blot:tarball
  ^-  tube:clay
  =/  arm=@tas  (rail-to-arm:tarball from)
  =/  gat=vase  (slap cor tsgl/[[%limb arm] limb/%grab])
  =>([gat=gat ..zuse] |=(v=vase (slam gat v)))
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
--
