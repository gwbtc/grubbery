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
::  The validator and the bunt are built here, once per marc, and the
::  arms return them. An arm is recomputed on every read, so building
::  them in the arms ran the compiler (+build-vale's slap) on every
::  validation, cache hits included (gwbtc/grubbery#115). A mark whose
::  validator does not build still fails when the arm is read, with
::  its own trace, as before.
::
++  build-marc
  |=  cor=vase
  ^-  marc:tarball
  =/  vg=(each $-(* vase) tang)  (mule |.((build-vale cor)))
  =/  bn=(each vase tang)
    ?:  ?=(%| -.vg)  [%| p.vg]
    (mule |.((p.vg +6.q.cor)))
  |%
  ++  type  p:bunt
  ++  bunt  ?:(?=(%& -.bn) p.bn (mean p.bn))
  ++  vale  ?:(?=(%& -.vg) p.vg (mean p.vg))
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
