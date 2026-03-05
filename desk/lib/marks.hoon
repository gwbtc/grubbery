::  marks: synchronous tube and dais builder
::
::  Reproduces Clay's tube/dais-building logic using only safe scries.
::  All mark files are listed via %cy and built via %ca — we only
::  scry for files we KNOW exist because we listed them ourselves.
::  Tube gates are composed from grab/grow arms using slap/slam/slob,
::  exactly as Clay does internally in +build-cast.
::  Daises are built inline (like Clay's build-dais) using the
::  build-nave → build-dais pipeline with slap instead of slub.
::
/+  tarball
|%
::  +rebuild-tubes: rebuild /bin/tubes/ sub-ball
::
++  rebuild-tubes
  |=  [our=@p =desk now=@da]
  ^-  ball:tarball
  =/  tubs=(map mars:clay tube:clay)
    (build-tubes our desk now)
  ~&  >  [%tubes-rebuilt ~(wyt by tubs)]
  %+  roll  ~(tap by tubs)
  |=  [[=mars:clay =tube:clay] acc=ball:tarball]
  (~(put ba:tarball acc) [/[a.mars] b.mars] [~ %temp !>(tube)])
::  +rebuild-daises: rebuild /bin/daises/ sub-ball
::
++  rebuild-daises
  |=  [our=@p =desk now=@da]
  ^-  ball:tarball
  =/  cores=(map mark vase)  (build-mark-cores our desk now)
  =/  daises=(map mark dais:clay)
    %-  ~(gas by *(map mark dais:clay))
    %+  murn  ~(tap by cores)
    |=  [=mark cor=vase]
    ^-  (unit [^mark dais:clay])
    =/  res=(each dais:clay tang)
      (mule |.((build-dais cores mark cor)))
    ?:  ?=(%& -.res)  `[mark p.res]
    %-  (%*(. slog pri 3) leaf+"{<mark>}: dais build failed" (flop p.res))
    ~
  ~&  >  [%daises-rebuilt ~(wyt by daises)]
  %+  roll  ~(tap by daises)
  |=  [[=mark =dais:clay] acc=ball:tarball]
  (~(put ba:tarball acc) [/ mark] [~ %temp !>(dais)])
::  +build-dais: build a dais from a raw mark core
::
::  Reproduces Clay's build-nave then build-dais, using slap
::  instead of slub (which is kernel-only).
::
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
    =/  mok=mark  !<(mark gad)
    =/  deg=vase  (build-nave cores mok (~(got by cores) mok))
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
::  +build-mark-cores: list and compile all mark cores for a desk
::
++  build-mark-cores
  |=  [our=@p =desk now=@da]
  ^-  (map mark vase)
  =/  base=path  /(scot %p our)/[desk]/(scot %da now)
  =/  =arch  .^(arch %cy (weld base /mar))
  =/  mark-names=(list mark)
    %+  murn  ~(tap by dir.arch)
    |=  [name=@tas *]
    ^-  (unit mark)
    ?.  .^(? %cu (weld base /mar/[name]/hoon))  ~
    `name
  %-  ~(gas by *(map mark vase))
  %+  murn  mark-names
  |=  =mark
  ^-  (unit [^mark vase])
  `[mark .^(vase %ca (weld base /mar/[mark]/hoon))]
::  +build-tubes: build all tube conversions for a desk
::
::  Returns a map from [from-mark to-mark] to tube gate.
::  Runs synchronously — safe for on-load.
::
++  build-tubes
  |=  [our=@p =desk now=@da]
  ^-  (map mars:clay tube:clay)
  =/  cores=(map mark vase)  (build-mark-cores our desk now)
  ::  Discover all conversion pairs from grab/grow arms
  =/  all-marks=(set mark)  ~(key by cores)
  =/  pairs=(list mars:clay)
    %-  zing
    %+  turn  ~(tap by cores)
    |=  [=mark =vase]
    ^-  (list mars:clay)
    =/  [grab=(list ^mark) grow=(list ^mark)]
      :-  ?.  (slob %grab -:vase)  ~
          (sloe -:(slap vase [%limb %grab]))
      ?.  (slob %grow -:vase)  ~
      (sloe -:(slap vase [%limb %grow]))
    ;:  weld
      (murn grab |=(m=^mark ?.((~(has in all-marks) m) ~ `[m mark])))
      (murn grow |=(m=^mark ?.((~(has in all-marks) m) ~ `[mark m])))
    ==
  ::  Build tubes for each valid pair
  =/  tubes=(map mars:clay tube:clay)  ~
  |-
  ?~  pairs  tubes
  =/  =mars:clay  i.pairs
  ?:  (~(has by tubes) mars)
    $(pairs t.pairs)
  =/  tub=(unit tube:clay)
    (try-build-tube cores mars)
  =?  tubes  ?=(^ tub)
    (~(put by tubes) mars u.tub)
  $(pairs t.pairs)
::  +try-build-tube: attempt to build a single tube, return ~ on failure
::
++  try-build-tube
  |=  [cores=(map mark vase) =mars:clay]
  ^-  (unit tube:clay)
  =/  res=(each tube:clay tang)
    (mule |.((build-tube cores mars)))
  ?:  ?=(%& -.res)  `p.res
  ~&  >>>  [%tube-build-failed mars]
  ~
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
--
