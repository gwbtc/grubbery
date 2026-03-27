::  marks: tube, dais, and nave builder
::
::  Reproduces Clay's tube/dais-building logic.
::  Tube gates are composed from grab/grow arms using slap/slam/slob,
::  exactly as Clay does internally in +build-cast.
::  Daises are built inline (like Clay's build-dais) using the
::  build-nave → build-dais pipeline with slap instead of slub.
::
/+  nexus, tarball
|%
::  +build-nave: build statically typed nave from mark core
::
::  Mirrors Clay's build-nave. Core-grad builds from grad arms
::  directly. Atom-grad delegates to another mark's nave via tubes.
::
++  build-nave
  |=  [cores=(map mark vase) mak=mark cor=vase]
  ^-  vase
  =/  gad=vase  (slap cor limb/%grad)
  ?@  q.gad
    ::  Atom grad — delegate to another mark's nave + tubes.
    =+  !<(mok=mark gad)
    =/  deg=vase
      ~|  leaf+"build-nave: {(trip mak)} missing grad mark {(trip mok)}"
      (build-nave cores mok (~(got by cores) mok))
    =/  tub=vase  (build-cast cores mak mok ~)
    =/  but=vase  (build-cast cores mok mak ~)
    %+  slap
      (with-faces deg+deg tub+tub but+but cor+cor nave+!>(nave:clay) ~)
    !,  *hoon
    =/  typ  _+<.cor
    =/  dif  _*diff:deg
    ^-  (nave typ dif)
    |%
    ++  diff
      |=  [old=typ new=typ]
      ^-  dif
      (diff:deg (tub old) (tub new))
    ++  form  form:deg
    ++  join  join:deg
    ++  mash  mash:deg
    ++  pact
      |=  [v=typ d=dif]
      ^-  typ
      (but (pact:deg (tub v) d))
    ++  vale  noun:grab:cor
    --
  ::  Core grad — build full nave from grad arms.
  %+  slap  (slop (with-face %cor cor) !>(..zuse))
  !,  *hoon
  =/  typ  _+<.cor
  =/  dif  _*diff:grad:cor
  ^-  (nave:clay typ dif)
  |%
  ++  diff  |=([old=typ new=typ] (diff:~(grad cor old) new))
  ++  form  form:grad:cor
  ++  join
    |=  [a=dif b=dif]
    ^-  (unit (unit dif))
    ?:  =(a b)  ~
    `(join:grad:cor a b)
  ++  mash
    |=  [a=[=ship =desk =dif] b=[=ship =desk =dif]]
    ^-  (unit dif)
    ?:  =(dif.a dif.b)  ~
    `(mash:grad:cor a b)
  ++  pact  |=([v=typ d=dif] (pact:~(grad cor v) d))
  ++  vale  noun:grab:cor
  --
::  +build-dais: build a dais from a raw mark core
::
::  Mirrors Clay's build-nave → build-dais pipeline.
::
++  build-dais
  |=  [cores=(map mark vase) mak=mark cor=vase]
  ^-  dais:clay
  =/  gad=vase  (slap cor limb/%grad)
  =/  frm=vase
    ?@  q.gad  gad
    (slap gad limb/%form)
  =/  frm-mark=mark  !<(mark frm)
  =/  nav=vase  (build-nave cores mak cor)
  ::  Wrap nave as dais (dynamically typed door).
  =>  [nav=nav frm-mark=frm-mark ..zuse]
  ^-  dais:clay
  |_  sam=vase
  ++  diff
    |=  new=vase
    (slam (slap nav limb/%diff) (slop sam new))
  ++  form  frm-mark
  ++  join
    |=  [a=vase b=vase]
    ^-  (unit (unit vase))
    =/  res=vase  (slam (slap nav limb/%join) (slop a b))
    ?~  q.res    ~
    ?~  +.q.res  [~ ~]
    ``(slap res !,(*hoon ?>(?=([~ ~ *] .) u.u)))
  ++  mash
    |=  [a=[=ship =desk diff=vase] b=[=ship =desk diff=vase]]
    ^-  (unit vase)
    =/  res=vase
      %+  slam  (slap nav limb/%mash)
      %+  slop
        :(slop [[%atom %p ~] ship.a] [[%atom %tas ~] desk.a] diff.a)
      :(slop [[%atom %p ~] ship.b] [[%atom %tas ~] desk.b] diff.b)
    ?~  q.res  ~
    `(slap res !,(*hoon ?>((^ .) u)))
  ++  pact
    |=  diff=vase
    (slam (slap nav limb/%pact) (slop sam diff))
  ++  vale
    |=  noun=*
    (slam (slap nav limb/%vale) !>(noun))
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
::  +nave-from: build a nave from mark cores
::
++  nave-from
  |=  [mak=mark cores=(map mark vase)]
  ^-  vase
  (build-nave cores mak (~(got by cores) mak))
::  +dais-from: build a dais from mark cores
::
++  dais-from
  |=  [mak=mark cores=(map mark vase)]
  ^-  dais:clay
  (build-dais cores mak (~(got by cores) mak))
::  +tube-from: build a tube from mark cores
::
++  tube-from
  |=  [=mars:clay cores=(map mark vase)]
  ^-  tube:clay
  (build-tube cores mars)
::  +dais: build a dais from a list of [mark vase] deps
::
++  dais
  |=  [mak=mark deps=(list [mark vase])]
  ^-  dais:clay
  (dais-from mak (~(gas by *(map mark vase)) deps))
::  +nave: build a nave from a list of [mark vase] deps
::
++  nave
  |=  [mak=mark deps=(list [mark vase])]
  ^-  vase
  (nave-from mak (~(gas by *(map mark vase)) deps))
::  +tube: build a tube from a list of [mark vase] deps
::
++  tube
  |=  [=mars:clay deps=(list [mark vase])]
  ^-  tube:clay
  (tube-from mars (~(gas by *(map mark vase)) deps))
--
