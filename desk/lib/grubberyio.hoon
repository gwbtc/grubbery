/-  g=grubbery
/+  server, multipart
=|  hold=? :: switch to interleave vs sequentialize processes
|%
++  charm  charm:base:g
+$  input  input:base:g
+$  bowl   bowl:base:g
++  carp
  |=  cord=@t
  ^-  @t
  %+  fall
    %+  rush  cord
    %+  cook  |=(=@t (cat 3 '%' (rsh [3 2] (scot %ux t))))
    ;~  pose
      col  fas  wut  hax  sel  ser
      pat  zap  buc  pam  soq  pal
      par  tar  lus  com  mic  tis
      ace
    ==
  cord
::
++  gems  |=(=@t (rap 3 (turn (trip t) carp)))
++  tapa  |=(p=(list @t) ^+(p (turn p gems)))
::
++  get-ship-groups
  |=  [=ship =cone:g]
  ^-  (set path)
  %-  ~(gas in *(set path))
  %+  murn  ~(tap of (~(dip of cone) /grp/who))
  |=  [=path =grub:g]
  ^-  (unit ^path)
  =/  data=(each vase tang)  (grab-data-soft grub)
  ?:  ?=(%| -.data)  ~
  =/  res  (mule |.(!<((set @p) p.data)))
  ?:  ?=(%| -.res)  ~
  ?.  (~(has in p.res) ship)  ~
  [~ path]
::
++  merge-weirs
  =|  =weir:g
  |=  weirs=(list weir:g)
  ^+  weir
  ?~  weirs
    weir
  %=  $
    weirs      t.weirs
    make.weir  (~(uni in make.weir) make.i.weirs)
    poke.weir  (~(uni in poke.weir) poke.i.weirs)
    peek.weir  (~(uni in peek.weir) peek.i.weirs)
  ==
::
++  get-ship-weir
  |=  [=ship =cone:g]
  ^-  weir:g
  =/  groups=(set path)  (get-ship-groups ship cone)
  =/  groups-weir=(list weir:g)
    %+  murn  ~(tap of (~(dip of cone) /grp/how))
    |=  [=path =grub:g]
    ^-  (unit weir:g)
    ?.  (~(has in groups) path)  ~
    =/  data=(each vase tang)  (grab-data-soft grub)
    ?:  ?=(%| -.data)  ~
    =/  res  (mule |.(!<(weir:g p.data)))
    ?:(?=(%| -.res) ~ [~ p.res])
  =/  public-weir=weir:g
    ?~  grub=(~(get of cone) /grp/pub)  *weir:g
    =/  data=(each vase tang)  (grab-data-soft u.grub)
    ?:  ?=(%| -.data)  *weir:g
    =/  res  (mule |.(!<(weir:g p.data)))
    ?:(?=(%| -.res) *weir:g p.res)
  (merge-weirs public-weir groups-weir)
::
++  grab-data-soft
  |=  =grub:g
  ^-  (each vase tang)
  ?-  -.grub
    %base  &+data.grub
    %stem  data.grub
  ==
::
++  grab-data
  |=  =grub:g
  ^-  vase
  =/  res  (grab-data-soft grub)
  ?-  -.res
    %&  p.res
    %|  (mean p.res)
  ==
::
++  grab-data-as
  |*  [a=mold =grub:g]
  ^-  a
  !<(a (grab-data grub))
::
++  nead
  |*  a=(each)
  ?:  ?=(%& -.a)
    p.a
  (mean p.a)
::
++  get-base-stud
  |=  base=path
  =/  m  (charm ,stud:g)
  ^-  form:m
  ?:  ?=([%boot ~] base)  (pure:m /sig)
  ?:  ?=([%lib ~] base)  (pure:m /lib)
  ?:  ?=([%bin ~] base)  (pure:m /bin)
  ;<  =grub:g  bind:m  (peek-root [%bin %base base])
  ?>  ?=(%stem -.grub)
  =/  res  (mule |.(!<([=stud:g *] (grab-data grub))))
  ?:  ?=(%& -.res)
    (pure:m stud.p.res)
  ~|("base {(spud base)} failed to compile" !!)
::
++  get-stem-stud
  |=  stem=path
  =/  m  (charm ,stud:g)
  ^-  form:m
  ?:  ?=([%bin ~] stem)  (pure:m /bin)
  ;<  =grub:g  bind:m  (peek-root [%bin %stem stem])
  ?>  ?=(%stem -.grub)
  =/  res  (mule |.(!<([=stud:g *] (grab-data grub))))
  ?:  ?=(%& -.res)
    (pure:m stud.p.res)
  ~|("stem {(spud stem)} failed to compile" !!)
::
++  get-grub-stud
  |=  =path
  =/  m  (charm ,stud:g)
  ^-  form:m
  ;<  =grub:g  bind:m  (peek-root path)
  ?-  -.grub
    %base  (get-base-stud base.grub)
    %stem  (get-stem-stud stem.grub)
  ==
::
++  send-raw-darts
  |=  darts=(list dart:g)
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  [darts state temp %done ~]
::
++  send-raw-dart
  |=  =dart:g
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-darts dart ~)
::
++  send-raw-cards
  |=  cards=(list card:agent:gall)
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  [(turn cards (lead %sysc)) state temp %done ~]
::
++  send-raw-card
  |=  =card:agent:gall
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-cards card ~)
:: Consult lib/strandio.hoon for context
:: +main-loop rigamarole completely eliminated with skip queue in $pipe
::
++  echo
  =/  m  (charm ,~)
  ^-  form:m
  ;<  [=from:base:g =pail:g]  bind:m  take-bump
  |-
  ?.  ?=([%txt ~] p.pail)
    %-  (slog leaf+"over..." ~)
    (pure:m ~)
  =/  message=tape  (trip !<(@t q.pail))
  %-  (slog leaf+"{message}..." ~)
  ;<  ~  bind:m  (sleep ~s2)
  ((slog leaf+"{message}.." ~) $)
::
++  veto-error
  |=  veto=$<(%perk dart:g)
  ^-  tang
  ?-  -.veto
    ?(%sysc %scry %bowl)  [leaf+"vetoed system call" ~]
    %grub                 [leaf+"vetoed grub call on wire {(spud wire.veto)}" ~]
  ==
::
++  take-watch
  =/  m  (charm ,path)
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %watch *]
    [%done path.u.in]
  ==
::
++  take-leave
  =/  m  (charm ,path)
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %leave *]
    [%done path.u.in]
  ==
::
++  send-wait
  |=  until=@da
  =/  m  (charm ,~)
  ^-  form:m
  %-  send-raw-dart
  [%sysc %pass /wait/(scot %da until) %arvo %b %wait until]
::
++  take-wake
  |=  until=(unit @da)
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?.  |(?=(~ until) =(`u.until (slaw %da i.t.wire.u.in)))
      [%skip hold]
    ?~  error.sign.u.in
      [%done ~]
    [%fail %timer-error u.error.sign.u.in]
  ==
::
++  wait
  |=  until=@da
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-wait until)
  (take-wake `until)
::
++  sleep
  |=  for=@dr
  =/  m  (charm ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time
  (wait (add now for))
::
++  take-pack-sign
  |=  =wire
  =/  m  (charm ,@ta)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %base * %pack *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?-  -.p.sign.u.in
        %&  [%done p.p.sign.u.in]
        %|  [%fail p.p.sign.u.in]
    ==
  ==
::
++  take-pack-sign-soft
  |=  =wire
  =/  m  (charm ,(each @ta tang))
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%done |+(veto-error dart.u.in)]
      [~ %base * %pack *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done p.sign.u.in]
  ==
::
++  take-poke-sign
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %base * %poke *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.sign.u.in
      [%done ~]
    [%fail %poke-fail u.err.sign.u.in]
  ==
::
++  take-poke-sign-soft
  |=  =wire
  =/  m  (charm ,(unit tang))
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %base * %poke *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done err.sign.u.in]
  ==
:: TODO: need to gracefully handle vetoes
::
++  poke
  |=  [=path =pail:g]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-raw-dart %grub /poke &+path %poke pail)
  ;<  *  bind:m  (take-pack-sign /poke)
  (take-poke-sign /poke)
::
++  poke-soft
  |=  [=path =pail:g]
  =/  m  (charm ,(unit tang))
  ^-  form:m
  ;<  ~  bind:m  (send-raw-dart %grub /poke &+path %poke pail)
  ;<  res=(each @ta tang)  bind:m  (take-pack-sign-soft /poke)
  ?:  ?=(%| -.res)
    (pure:m ~ p.res)
  (take-poke-sign-soft /poke)
:: poke without awaiting completion
:: returns process id for further interaction
::
++  toss
  |=  [=path =pail:g]
  =/  m  (charm ,@ta)
  ^-  form:m
  ;<  ~  bind:m  (send-raw-dart %grub /poke &+path %poke pail)
  (take-pack-sign /poke)
:: poke while expecting a single returned piece of data (perk)
::
++  vent
  |=  [=path poke=pail:g]
  =/  m  (charm ,pail:g)
  ^-  form:m
  ~&  >>>  %venting
  ;<  ~      bind:m  (send-raw-dart %grub /vent &+path %poke poke)
  ~&  >>>  %taking-pack
  ;<  *  bind:m  (take-pack-sign /vent)
  ~&  >>>  %taking-perk
  ;<  =pail:g  bind:m  (take-perk /vent)
  ~&  >>>  %taking-poke-sign
  ;<  ~      bind:m  (take-poke-sign /vent)
  ~&  >>>  %returning-pail
  (pure:m pail)
::
++  take-perk
  |=  =wire
  =/  m  (charm ,pail:g)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %perk *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done pail.u.in]
  ==
::
++  take-bump
  =/  m  (charm ,[=from:base:g =pail:g])
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %bump *]
    [%done [from pail]:u.in]
  ==
::
++  take-bump-sign
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %base * %bump *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.sign.u.in
      [%done ~]
    [%fail %bump-nack u.err.sign.u.in]
  ==
::
++  bump
  |=  [=wire =path pid=@ta =pail:g]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart:g  [%grub wire &+path %bump pid pail]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-bump-sign /bump)
::
++  take-bump-sign-soft
  |=  =wire
  =/  m  (charm ,(unit tang))
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%done ~ (veto-error dart.u.in)]
      [~ %base * %bump *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.sign.u.in
      [%done ~]
    [%done ~ u.err.sign.u.in]
  ==
::
++  bump-soft
  |=  [=wire =path pid=@ta =pail:g]
  =/  m  (charm ,(unit tang))
  ^-  form:m
  =/  =dart:g  [%grub wire &+path %bump pid pail]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-bump-sign-soft /poke)
::
++  take-peek
  |=  =wire
  =/  m  (charm ,[cone:g sand:g])
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %peek *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done [cone sand]:u.in]
  ==
::
++  ls
  |=  =path
  =/  m  (charm ,(list @ta))
  ^-  form:m
  ;<  =cone:g  bind:m  (peek path)
  (pure:m ~(tap in ~(key by dir.cone)))

:: list of the first non-empty descendents of a path
::
++  kids
  |=  =path
  =/  m  (charm ,(list ^path))
  ^-  form:m
  ;<  =cone:g  bind:m  (peek path)
  =.  cone  (~(del of cone) /)
  =|  sub-path=^path
  =|  kids=(list ^path)
  %-  pure:m
  |-
  ^-  (list ^path)
  ?:  ?=(^ fil.cone)
    [sub-path kids]
  =/  dir  ~(tap by dir.cone)
  |-
  ^+   kids
  ?~  dir
    kids
  %=  $
    dir   t.dir
    kids  ^$(sub-path (weld sub-path /[p.i.dir]), cone q.i.dir)
  ==
:: tree information without the data
::
++  tree
  |=  =path
  =/  m  (charm ,(axal ~))
  ^-  form:m
  ;<  =cone:g  bind:m  (peek path)
  %-  pure:m
  %-  ~(gas of *(axal ~))
  (turn ~(tap of cone) |=([p=^path *] [p ~]))
::
++  get-weir
  |=  =path
  =/  m  (charm ,(unit weir:g))
  ^-  form:m
  =/  =dart:g  [%grub /get-weir &+path %peek ~]
  ;<  ~  bind:m  (send-raw-dart dart)
  ;<  [* =sand:g]  bind:m  (take-peek /get-weir)
  (pure:m (~(get of sand) /))
::
++  peek
  |=  =path
  =/  m  (charm ,cone:g)
  ^-  form:m
  =/  =dart:g  [%grub /peek &+path %peek ~]
  ;<  ~  bind:m  (send-raw-dart dart)
  ;<  [=cone:g *]  bind:m  (take-peek /peek)
  (pure:m cone)
::
++  peek-root
  |=  =path
  =/  m  (charm ,grub:g)
  ^-  form:m
  ;<  =cone:g  bind:m  (peek path)
  ?~  grub=(~(get of cone) /)
    (charm-fail leaf+"no-root-grub" leaf+(spud path) ~)
  (pure:m u.grub)
::
++  peek-root-soft
  |=  =path
  =/  m  (charm ,(unit grub:g))
  ^-  form:m
  ;<  =cone:g  bind:m  (peek path)
  (pure:m (~(get of cone) /))
::
++  peek-root-as
  |*  [a=mold =path]
  =/  m  (charm ,a)
  ^-  form:m
  ;<  =grub:g  bind:m  (peek-root path)
  (pure:m ;;(a q:(grab-data grub)))
::
++  peek-root-as-soft
  |*  [a=mold =path]
  =/  m  (charm ,(unit a))
  ^-  form:m
  ;<  grub=(unit grub:g)  bind:m  (peek-root-soft path)
  ?~  grub
    (pure:m ~)
  (pure:m `!<(a (grab-data u.grub)))
:: peek, but with relative path
::
++  grab
  |=  =path
  =/  m  (charm ,cone:g)
  ^-  form:m
  ;<  here=^path  bind:m  get-here
  (peek (weld here path))
::
++  grab-root
  |=  =path
  =/  m  (charm ,grub:g)
  ^-  form:m
  ;<  here=^path  bind:m  get-here
  (peek-root (weld here path))
::
++  grab-root-as
  |*  [a=mold =path]
  =/  m  (charm ,a)
  ^-  form:m
  ;<  here=^path  bind:m  get-here
  (peek-root-as (weld here path))
::
++  take-scry
  |*  [=mold =wire]
  =/  m  (charm ,mold)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %scry *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done !<(mold vase.u.in)]
  ==
::
++  scry
  |*  [=mold =path]
  =/  m  (charm ,mold)
  ^-  form:m
  =/  =dart:g  [%scry /scry ~ mold path]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-scry mold /scry)
::
++  take-bowl
  |=  =wire
  =/  m  (charm ,bowl)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %bowl *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done bowl.u.in]
  ==
::
++  get-bowl
  =/  m  (charm ,bowl)
  ^-  form:m
  =/  =dart:g  [%bowl /bowl]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-bowl /bowl)
::
++  eyre-connect
  |=  [url=(list @t) dest=path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  our=@p     bind:m  get-our
  (gall-poke [our %grubbery] connect+!>([url dest]))
::
++  eyre-disconnect
  |=  url=(list @t)
  =/  m  (charm ,~)
  ^-  form:m
  ;<  our=@p     bind:m  get-our
  (gall-poke [our %grubbery] disconnect+!>(url))
::
++  kill-base
  |=  [=path pid=(unit @ta)]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart:g  [%grub /kill-base &+path %kill pid]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-dead /kill-base)
::
++  take-dead
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %dead *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %kill-fail u.err.u.in]
  ==
::
++  oust-grub
  |=  =path
  =/  m  (charm ,~)
  ^-  form:m
  ~&  >  %ousting-grub
  =/  =dart:g  [%grub /oust-grub &+path %oust ~]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-gone /oust-grub)
::
++  take-gone
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  ~&  >  "taking-gone {(spud wire)}"
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %oust-fail u.err.u.in]
  ==
::
++  cull-cone
  |=  =path
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart:g  [%grub /cull-cone &+path %cull ~]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-cull /cull-cone)
::
++  take-cull
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %cull *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %cull-fail u.err.u.in]
  ==
::
++  edit-weir
  |=  [=path weir=(unit weir:g)]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart:g  [%grub /edit-weir &+path %sand weir]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-sand /edit-weir)
::
++  take-sand
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %sand *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %sand-fail u.err.u.in]
  ==
::
++  check-base
  |=  [=path data=vase base=path]
  =/  m  (charm ,?)
  ^-  form:m
  ;<  grub=(unit grub:g)  bind:m  (peek-root-soft path)
  ?~  grub
    (pure:m |)
  (pure:m =(u.grub [%base data base]))
::
++  check-stem
  |=  [=path =vine:stem:g stem=path]
  =/  m  (charm ,?)
  ^-  form:m
  ;<  grub=(unit grub:g)  bind:m  (peek-root-soft path)
  ?~  grub
    (pure:m |)
  ?.  ?=(%stem -.u.grub)
    (pure:m |)
  (pure:m =([vine stem] [vine stem]:u.grub))
::
++  make-stem
  |=  [=path stem=path =vine:stem:g]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart:g  [%grub /make-stem &+path %make %stem stem vine]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-made /make-stem)
::
++  overwrite-stem
  =|  chk=?
  |=  [=path stem=path =vine:stem:g]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  skip=?  bind:m
    ?.  chk   (pure:(charm ?) |)
    (check-stem path vine stem)
  ?:  skip
    (pure:m ~)
  ;<  ~  bind:m  (oust-grub path)
  (make-stem path stem vine)
::
++  make-base
  |=  [=path base=path data=(unit vase)]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart:g  [%grub /make-base &+path %make %base base data]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-made /make-base)
::
++  overwrite-base
  =|  chk=?
  |=  [=path base=path data=(unit vase)]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  skip=?  bind:m
    ?.  chk   (pure:(charm ?) |)
    ?~  data  (pure:(charm ?) |)
    (check-base path u.data base)
  ?:  skip
    (pure:m ~)
  ;<  ~  bind:m  (oust-grub path)
  (make-base path base data)
::
++  make-and-poke
  |=  [=path base=path data=(unit vase) poke=pail:g]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (make-base path base data)
  (^poke path poke)
::
++  overwrite-and-poke
  |=  [=path base=path data=(unit vase) poke=pail:g]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (overwrite-base path base data)
  (^poke path poke)
::
++  make-lib
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  *  bind:m 
    %:  make-and-poke
      [%lib path]
      /lib  ~
      [/txt !>(code)]
    ==
  (pure:m ~)
::
++  overwrite-lib
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  res=(unit tang)  bind:m  (poke-soft [%lib path] /txt !>(code))
  ?~  res
    (pure:m ~)
  ;<  ~  bind:m  (oust-grub [%lib path])
  (make-lib path code)
::
++  overwrite-libs
  |=  libs=(list [path @t])
  =/  m  (charm ,~)
  ^-  form:m
  ?~  libs  done
  ;<  ~  bind:m  (overwrite-lib i.libs)
  $(libs t.libs)
::
++  sync-lib-cone
  =/  m  (charm ,~)
  ^-  form:m
  ;<  =bowl:base:g      bind:m  get-bowl
  =/  =beak             [our.bowl %grubbery da+now.bowl]
  :: NOTE: we scry directly so that any crashes
  ::       still occur in the +on-load
  ::
  ;<  tree=(list path)  bind:m  (scry-tree %grubbery /gub)
  |-
  ?~  tree  done
  ;<  file=@t  bind:m  (scry-file @t %grubbery i.tree)
  ;<  ~        bind:m  (overwrite-lib (slag 1 (snip i.tree)) file)
  $(tree t.tree)
::
++  make-stud-lib 
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  (make-lib [%stud path] code)
::
++  overwrite-stud-lib
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  (overwrite-lib [%stud path] code)
::
++  make-base-lib 
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  (make-lib [%base path] code)
::
++  overwrite-base-lib
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  (overwrite-lib [%base path] code)
::
++  make-stem-lib 
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  (make-lib [%stem path] code)
::
++  overwrite-stem-lib
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  (overwrite-lib [%stem path] code)
::
++  take-made
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  ~&  >  "taking-made {(spud wire)}"
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %made *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %make-fail u.err.u.in]
  ==
::
++  copy-grub
  |=  [from=path to=path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  =grub:g  bind:m  (peek-root from)
  ?-  -.grub
    %base  (overwrite-base to base.grub ~ data.grub)
    %stem  (overwrite-stem to stem.grub vine.grub)
  ==
:: mostly useful for recomputing a stem when you edit its stem code
::
++  re-make
  |=  here=path
  =/  m  (charm ,~)
  ^-  form:m
  (copy-grub here here)
::
++  move-grub
  |=  [from=path to=path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (copy-grub from to)
  (oust-grub from)
::
++  copy-cone
  |=  [from=path to=path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  =cone:g  bind:m  (peek from)
  =/  grubs=(list path)  (turn ~(tap of cone) head)
  |-
  ?~  grubs
    (pure:m ~)
  ;<  ~  bind:m  (copy-grub (weld from i.grubs) (weld to i.grubs))
  $(grubs t.grubs)
::
++  move-cone
  |=  [from=path to=path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (copy-cone from to)
  (cull-cone from)
::
++  re-source
  |=  [here=path =vine:stem:g]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  =grub:g  bind:m  (peek-root here)
  ?>  ?=(%stem -.grub)
  (overwrite-stem here stem.grub vine)
::
++  get-poke
  =/  m  (charm ,(unit pail:g))
  ^-  form:m
  |=  input
  [~ state temp %done pail]
::
++  get-poke-pail
  =/  m  (charm ,pail:g)
  ^-  form:m
  |=  input
  [~ state temp %done (need pail)]
::
++  get-time
  =/  m  (charm ,@da)
  ^-  form:m
  ;<  =bowl  bind:m  get-bowl
  (pure:m now.bowl)
::
++  get-our
  =/  m  (charm ,ship)
  ^-  form:m
  ;<  =bowl  bind:m  get-bowl
  (pure:m our.bowl)
::
++  get-entropy
  =/  m  (charm ,@uvJ)
  ^-  form:m
  ;<  =bowl  bind:m  get-bowl
  (pure:m eny.bowl)
::
++  get-from
  =/  m  (charm ,from:base:g)
  ^-  form:m
  |=  input
  [~ state temp %done from]
::
++  get-here
  =/  m  (charm ,path)
  ^-  form:m
  ;<  =bowl  bind:m  get-bowl
  (pure:m here.bowl)
::
++  get-state
  =/  m  (charm ,vase)
  ^-  form:m
  |=  input
  [~ state temp %done state]
::
++  get-state-as
  |*  a=mold
  =/  m  (charm ,a)
  ^-  form:m
  |=  input
  [~ state temp %done ;;(a q.state)]
::
++  gut-state-as
  |*  a=mold
  |=  gut=$-(tang a)
  =/  m  (charm ,a)
  ^-  form:m
  |=  input
  =/  res  (mule |.(;;(a q.state)))
  ?-  -.res
    %&  [~ state temp %done p.res]
    %|  [~ state temp %done (gut p.res)]
  ==
::
++  charm-fail
  |=  err=tang
  |=  input
  [~ state temp %fail err]
::
++  transform
  |=  transform=$-(vase vase)
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ (transform state) temp %done ~]
::
++  replace
  |=  new=vase
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ new temp %done ~]
:: short four letter alias
::
++  pour  replace
:: do nothing and give a sig
::
++  done
  =/  m  (charm ,~)
  ^-  form:m
  (pure:m ~)
::
++  perk
  |=  =pail:g
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-dart %perk pail)
::
++  gall-poke
  |=  [=dock =cage]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass /poke %agent dock %poke cage]
  ;<  ~  bind:m  (send-raw-card card)
  (take-gall-poke-ack /poke)
::
++  gall-poke-our
  |=  [=dude:gall =cage]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (gall-poke [our dude] cage)
::
++  take-gall-poke-ack
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * %poke-ack *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %poke-fail u.p.sign.u.in]
  ==
::
++  gall-poke-soft
  |=  [=dock =cage]
  =/  m  (charm ,(unit tang))
  ^-  form:m
  =/  =dart:g  [%sysc %pass /poke %agent dock %poke cage]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-gall-poke-ack-soft /poke)
::
++  gall-poke-our-soft
  |=  [=dude:gall =cage]
  =/  m  (charm ,(unit tang))
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (gall-poke-soft [our dude] cage)
::
++  take-gall-poke-ack-soft
  |=  =wire
  =/  m  (charm ,(unit tang))
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * %poke-ack *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  p.sign.u.in
      [%done ~]
    [%done ~ u.p.sign.u.in]
  ==
::
++  handle-http-response
  |=  [eyre-id=@ta pay=simple-payload:http]
  =/  m  (charm ,~)
  ^-  form:m
  %+  gall-poke-our
    %grubbery
  handle-http-response+!>([eyre-id pay])
::
++  final-http-response
  |=  [eyre-id=@ta pay=simple-payload:http]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (handle-http-response eyre-id pay)
  done
::
++  watch
  |=  [=wire =dock =path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m
    (send-raw-dart %sysc %pass watch+wire %agent dock %watch path)
  (take-watch-ack wire)
::
++  watch-one
  |=  [=wire =dock =path]
  =/  m  (charm ,cage)
  ^-  form:m
  ;<  ~      bind:m  (watch wire dock path)
  ;<  =cage  bind:m  (take-fact wire)
  ;<  ~      bind:m  (take-kick wire)
  (pure:m cage)
::
++  watch-our
  |=  [=wire =term =path]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (watch wire [our term] path)
::
++  leave
  |=  [=wire =dock]
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-dart %sysc %pass watch+wire %agent dock %leave ~)
::
++  leave-our
  |=  [=wire =term]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (leave wire [our term])
::
++  take-watch-ack
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * %watch-ack *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %watch-ack-fail u.p.sign.u.in]
  ==
::
++  take-fact
  |=  =wire
  =/  m  (charm ,cage)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * %fact *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    [%done cage.sign.u.in]
  ==
::
++  take-kick
  |=  =wire
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * %kick *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    [%done ~]
  ==
::
::  Read from Clay
::
++  warp
  |=  [=ship =riff:clay]
  =/  m  (charm ,riot:clay)
  ;<  ~  bind:m  (send-raw-card %pass /warp %arvo %c %warp ship riff)
  (take-writ /warp)
::
++  read-file
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (charm ,cage)
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %x case spur)
  ?~  riot
    (charm-fail leaf+"read fail" >arg< ~)
  (pure:m r.u.riot)
::
++  scry-file
  |*  [=mold =desk =path]
  =/  m  (charm ,mold)
  (scry mold %cx desk path)
::
++  read-files
  =|  files=(map spur cage)
  |=  [[=ship =desk =case] spurs=(list spur)]
  =/  m  (charm ,(map spur cage))
  ?~  spurs
    (pure:m files)
  ;<  file=cage  bind:m  (read-file [ship desk case] i.spurs)
  $(spurs t.spurs, files (~(put by files) i.spurs file))
::
++  read-text-file
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (charm ,@t)
  ;<  =cage  bind:m  (read-file [ship desk case] spur)
  (pure:m !<(@t q.cage))
::
++  read-text-files
  =|  files=(map spur @t)
  |=  [[=ship =desk =case] spurs=(list spur)]
  =/  m  (charm ,(map spur @t))
  ?~  spurs
    (pure:m files)
  ;<  file=@t  bind:m  (read-text-file [ship desk case] i.spurs)
  $(spurs t.spurs, files (~(put by files) i.spurs file))
::
++  check-for-file
  |=  [[=ship =desk =case] =spur]
  =/  m  (charm ,?)
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %u case spur)
  ?>  ?=(^ riot)
  (pure:m !<(? q.r.u.riot))
::
++  list-tree
  |=  [[=ship =desk =case] =spur]
  =*  arg  +<
  =/  m  (charm ,(list path))
  ;<  =riot:clay  bind:m  (warp ship desk ~ %sing %t case spur)
  ?~  riot
    (charm-fail leaf+"list tree" >arg< ~)
  (pure:m !<((list path) q.r.u.riot))
::
++  scry-tree
  |=  [=desk =path]
  =/  m  (charm ,(list ^path))
  (scry (list ^path) %ct desk path)
::
::  Take Clay read result
::
++  take-writ
  |=  =wire
  =/  m  (charm ,riot:clay)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
      ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %arvo * ?(%behn %clay) %writ *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done +>.sign.u.in]
  ==
::
++  send-request
  |=  =request:http
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-dart %sysc %pass /request %arvo %i %request request *outbound-config:iris)
::
++  send-cancel-request
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-dart %sysc %pass /request %arvo %i %cancel-request ~)
::
++  take-client-response
  =/  m  (charm ,client-response:iris)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
    ::
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    ::NOTE  iris does not (yet?) retry after cancel, so it means failure
    :+  %fail
      %http-request-cancelled
    ['http request was cancelled by the runtime']~
    ::
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done client-response.sign.u.in]
  ==
::  Wait until we get an HTTP response or cancelation and unset contract
::
++  take-maybe-sigh
  =/  m  (charm ,(unit httr:eyre))
  ^-  form:m
  ;<  rep=(unit client-response:iris)  bind:m
    take-maybe-response
  ?~  rep
    (pure:m ~)
  ::  XX s/b impossible
  ::
  ?.  ?=(%finished -.u.rep)
    (pure:m ~)
  (pure:m (some (to-httr:iris +.u.rep)))
::
++  take-maybe-response
  =/  m  (charm ,(unit client-response:iris))
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%done ~]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done `client-response.sign.u.in]
  ==
::
++  extract-body
  |=  =client-response:iris
  =/  m  (charm ,cord)
  ^-  form:m
  ?>  ?=(%finished -.client-response)
  %-  pure:m
  ?~  full-file.client-response  ''
  q.data.u.full-file.client-response
::
++  fetch-cord
  |=  url=tape
  =/  m  (charm ,cord)
  ^-  form:m
  =/  =request:http  [%'GET' (crip url) ~ ~]
  ;<  ~                      bind:m  (send-request request)
  ;<  =client-response:iris  bind:m  take-client-response
  (extract-body client-response)
::
++  fetch-json
  |=  url=tape
  =/  m  (charm ,json)
  ^-  form:m
  ;<  =cord  bind:m  (fetch-cord url)
  =/  json=(unit json)  (de:json:html cord)
  ?~  json
    (charm-fail leaf+"json-parse-error" ~)
  (pure:m u.json)
::
++  hiss-request
  |=  =hiss:eyre
  =/  m  (charm ,(unit httr:eyre))
  ^-  form:m
  ;<  ~  bind:m  (send-request (hiss-to-request:html hiss))
  take-maybe-sigh
::
++  give-response-header
  |=  =response-header:http
  =/  m  (charm ,~)
  ^-  form:m
  (perk /http-response-header !>(response-header))
::
++  give-response-data
  |=  data=(unit octs)
  =/  m  (charm ,~)
  ^-  form:m
  (perk /http-response-data !>(data))
::
++  give-simple-payload
  |=  simple-payload:http
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (give-response-header response-header)
  ;<  ~  bind:m  (give-response-data data)
  done
::
++  is-sse-request
  |=  req=inbound-request:eyre
  ^-  ?
  ?&  ?=(%'GET' method.request.req)
      .=  [~ 'text/event-stream']
      (get-header:http 'accept' header-list.request.req)
  ==
::
++  sse-last-id
  |=  req=inbound-request:eyre
  ^-  (unit @t)
  (get-header:http 'last-event-id' header-list.request.req)
::
++  sse-header
  ^-  response-header:http
  :-  200
  :~  ['content-type' 'text/event-stream']
      ['cache-control' 'no-cache']
      ['connection' 'keep-alive']
  ==
::
++  give-sse-header
  =/  m  (charm ,~)
  ^-  form:m
  (give-response-header sse-header)
::
++  numb :: adapted from numb:enjs:format
  |=  a=@u
  ^-  tape
  ?:  =(0 a)  "0"
  %-  flop
  |-  ^-  tape
  ?:(=(0 a) ~ [(add '0' (mod a 10)) $(a (div a 10))])
::
+$  sse-event
  $:  id=(unit @t)
      event=(unit @t)
      data=wain
  ==
::
++  sse-events
  =|  comments=wain
  =|  retry=(unit @ud)
  |=  events=(list sse-event)
  ^-  octs
  =|  response=wain
  =?  response  ?=(^ retry)
    (snoc response (cat 3 'retry: ' (crip (numb u.retry))))
  =.  response
    |-
    ?~  events
      (snoc response '')
    =?  response  ?=(^ id.i.events)
      (snoc response (cat 3 'id: ' u.id.i.events))
    =?  response  ?=(^ event.i.events)
      (snoc response (cat 3 'event: ' u.event.i.events))
    =.  response
      %+  weld  response
      %+  turn  data.i.events
      |=(=@t (cat 3 'data: ' t))
    $(events t.events)
  =.  response
    |-
    ?~  comments
      (snoc response '')
    =.  response  (snoc response (cat 3 ': ' i.comments))
    $(comments t.comments)
  (as-octs:mimes:html (of-wain:format response))
::
++  give-sse-manx
  |=  [id=(unit @t) event=(unit @t) =manx]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =sse-event  [id event [(crip (en-xml:html manx))]~]
  =/  data=octs  (sse-events ~[sse-event])
  (give-response-data `data)
::
++  give-sse-json
  |=  [id=(unit @t) event=(unit @t) =json]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =sse-event  [id event [(en:json:html json)]~]
  =/  data=octs  (sse-events ~[sse-event])
  (give-response-data `data)
::
++  give-manx-response
  |=  =manx
  =/  m  (charm ,~)
  ^-  form:m
  (give-simple-payload (manx-response:gen:server manx))
::
++  render-tang-to-wall
  |=  [wid=@u tan=tang]
  ^-  wall
  (zing (turn tan |=(a=tank (wash 0^wid a))))
::
++  render-tang-to-marl
  |=  [wid=@u tan=tang]
  ^-  marl
  =/  raw=(list tape)  (zing (turn tan |=(a=tank (wash 0^wid a))))
  ::
  |-  ^-  marl
  ?~  raw  ~
  [;/(i.raw) ;br; $(raw t.raw)]
::
++  two-oh-four
  [[204 ['content-type' 'application/json']~] ~]
::
++  internal-server-error
  |=  [authorized=? msg=tape t=tang]
  ^-  simple-payload:http
  =;  =manx
    :_  `(manx-to-octs:server manx)
    [500 ['content-type' 'text/html']~]
  ;html
    ;head
      ;title:"500 Internal Server Error"
    ==
    ;body
      ;h1:"Internal Server Error"
      ;p: {msg}
      ;*  ?:  authorized
            ;=
              ;code:"*{(render-tang-to-marl 80 t)}"
            ==
          ~
    ==
  ==
::
++  method-not-allowed
  |=  method=@t
  ^-  simple-payload:http
  =;  =manx
    :_  `(manx-to-octs:server manx)
    [405 ['content-type' 'text/html']~]
  ;html
    ;head
      ;title:"405 Method Not Allowed"
    ==
    ;body
      ;h1:"Method Not Allowed: {(trip method)}"
    ==
  ==
::
++  mime-response
  |=  [cache=@dr =mime]
  ^-  simple-payload:http
  ~&  >>  mime-response+mime
  :_  `q.mime
  :-  200
  :~  ['cache-control' (crip "max-age={(numb (div cache ~s1))}")]
      ['content-type' (rsh [3 1] (spat p.mime))]
  ==
::
++  give-mime-response
  |=  [cache=@dr =mime]
  =/  m  (charm ,~)
  ^-  form:m
  (give-simple-payload (mime-response cache mime))
--
