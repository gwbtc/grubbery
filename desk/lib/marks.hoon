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
::  Returns a gate: given a target mark, produce a tube.
::  Only handles marks directly defined in +grow of this core.
::
++  build-grow
  |=  cor=vase
  ^-  $-(mark tube:clay)
  |=  to=mark
  ^-  tube:clay
  =/  gat=vase
    %+  slap  (with-faces cor+cor ~)
    ^-  hoon
    :+  %brcl  !,(*hoon v=+<.cor)
    :+  %tsgl  limb/to
    !,(*hoon ~(grow cor v))
  =>([gat=gat ..zuse] |=(v=vase (slam gat v)))
::  +build-grab: build dispatch gate for inbound conversions
::
::  Returns a gate: given a source mark, produce a tube.
::  Only handles marks directly defined in +grab of this core.
::
++  build-grab
  |=  cor=vase
  ^-  $-(mark tube:clay)
  |=  from=mark
  ^-  tube:clay
  =/  gat=vase  (slap cor tsgl/[limb/from limb/%grab])
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
