/-  *grubbery
/+  server, multipart
=,  base
=|  hold=? :: switch to interleave vs sequentialize processes
|%
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
  |=  [=ship =cone]
  ^-  (set path)
  %-  ~(gas in *(set path))
  %+  murn  ~(tap of (~(dip of cone) /grp/who))
  |=  [=path =grub]
  ^-  (unit ^path)
  =/  data=(each vase tang)  (grab-data-soft grub)
  ?:  ?=(%| -.data)  ~
  =/  res  (mule |.(!<((set @p) p.data)))
  ?:  ?=(%| -.res)  ~
  ?.  (~(has in p.res) ship)  ~
  [~ path]
::
++  merge-perms
  =|  =perm
  |=  perms=(list ^perm)
  ^+  perm
  ?~  perms
    perm
  %=  $
    perms      t.perms
    make.perm  (~(uni in make.perm) make.i.perms)
    poke.perm  (~(uni in poke.perm) poke.i.perms)
    peek.perm  (~(uni in peek.perm) peek.i.perms)
  ==
::
++  get-ship-perm
  |=  [=ship =cone]
  ^-  perm
  =/  groups=(set path)  (get-ship-groups ship cone)
  =/  groups-perm=(list perm)
    %+  murn  ~(tap of (~(dip of cone) /grp/how))
    |=  [=path =grub]
    ^-  (unit perm)
    ?.  (~(has in groups) path)  ~
    =/  data=(each vase tang)  (grab-data-soft grub)
    ?:  ?=(%| -.data)  ~
    =/  res  (mule |.(!<(perm p.data)))
    ?:(?=(%| -.res) ~ [~ p.res])
  =/  public-perm=perm
    ?~  grub=(~(get of cone) /grp/pub)  *perm
    =/  data=(each vase tang)  (grab-data-soft u.grub)
    ?:  ?=(%| -.data)  *perm
    =/  res  (mule |.(!<(perm p.data)))
    ?:(?=(%| -.res) *perm p.res)
  (merge-perms public-perm groups-perm)
::
++  grab-data-soft
  |=  =grub
  ^-  (each vase tang)
  ?-  -.grub
    %base  &+data.grub
    %stem  data.grub
  ==
::
++  grab-data
  |=  =grub
  ^-  vase
  =/  res  (grab-data-soft grub)
  ?-  -.res
    %&  p.res
    %|  (mean p.res)
  ==
::
++  grab-data-as
  |*  [a=mold =grub]
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
  =/  m  (charm ,stud)
  ^-  form:m
  ?:  ?=([%boot ~] base)  (pure:m /sig)
  ?:  ?=([%lib ~] base)  (pure:m /lib)
  ?:  ?=([%bin ~] base)  (pure:m /bin)
  ;<  =grub  bind:m  (peek-root [%bin %base base])
  ?>  ?=(%stem -.grub)
  ?>  tidy.grub
  =/  res  (mule |.(!<([=stud *] (grab-data grub))))
  ?:  ?=(%& -.res)
    (pure:m stud.p.res)
  ~|("base {(spud base)} failed to compile" !!)
::
++  get-stem-stud
  |=  stem=path
  =/  m  (charm ,stud)
  ^-  form:m
  ?:  ?=([%bin ~] stem)  (pure:m /bin)
  ;<  =grub  bind:m  (peek-root [%bin %stem stem])
  ?>  ?=(%stem -.grub)
  ?>  tidy.grub
  =/  res  (mule |.(!<([=stud *] (grab-data grub))))
  ?:  ?=(%& -.res)
    (pure:m stud.p.res)
  ~|("stem {(spud stem)} failed to compile" !!)
::
++  get-grub-stud
  |=  =path
  =/  m  (charm ,stud)
  ^-  form:m
  ;<  =grub  bind:m  (peek-root path)
  ?-  -.grub
    %base  (get-base-stud base.grub)
    %stem  (get-stem-stud stem.grub)
  ==
::
++  send-raw-darts
  |=  darts=(list =dart)
  =/  m  (charm ,~)
  ^-  form:m
  |=  input
  ~&  >  %sending-raw-darts
  [darts state temp %done ~]
::
++  send-raw-dart
  |=  =dart
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-darts dart ~)
::
++  take-watch
  =/  m  (charm ,path)
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
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
      [~ %base * %pack *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?-  -.p.sign.u.in
        %&  [%done p.p.sign.u.in]
        %|  [%fail p.p.sign.u.in]
    ==
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
      [~ %base * %poke *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.sign.u.in
      [%done ~]
    [%fail %poke-fail u.err.sign.u.in]
  ==
::
++  poke
  |=  [=path =pail]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-raw-dart %grub /poke &+path %poke pail)
  ;<  *  bind:m  (take-pack-sign /poke)
  (take-poke-sign /poke)
::
++  vent
  |=  [=path poke=pail]
  =/  m  (charm ,pail)
  ^-  form:m
  ~&  >>>  %venting
  ;<  ~      bind:m  (send-raw-dart %grub /vent &+path %poke poke)
  ~&  >>>  %taking-pack
  ;<  *  bind:m  (take-pack-sign /vent)
  ~&  >>>  %taking-perk
  ;<  =pail  bind:m  (take-perk /vent)
  ~&  >>>  %taking-poke-sign
  ;<  ~      bind:m  (take-poke-sign /vent)
  ~&  >>>  %returning-pail
  (pure:m pail)
::
++  take-perk
  |=  =wire
  =/  m  (charm ,pail)
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
      [~ %perk *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    [%done pail.u.in]
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
      [~ %base * %bump *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.sign.u.in
      [%done ~]
    [%fail %bump-nack u.err.sign.u.in]
  ==
::
++  bump
  |=  [=wire =path pid=@ta =pail]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart  [%grub wire &+path %bump pid pail]
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
      [~ %base * %bump *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.sign.u.in
      [%done ~]
    [%done ~ u.err.sign.u.in]
  ==
::
++  bump-soft
  |=  [=wire =path pid=@ta =pail]
  =/  m  (charm ,(unit tang))
  ^-  form:m
  =/  =dart  [%grub wire &+path %bump pid pail]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-bump-sign-soft /poke)
::
++  take-peek
  |=  =wire
  =/  m  (charm ,[cone sand])
  ^-  form:m
  |=  input
  :-  ~
  :+  state  temp
  ?+  in  [%skip hold]
    ~  [%wait hold]
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
  ;<  =cone  bind:m  (peek path)
  (pure:m ~(tap in ~(key by dir.cone)))

:: list of the first non-empty descendents of a path
::
++  kids
  |=  =path
  =/  m  (charm ,(list ^path))
  ^-  form:m
  ;<  =cone  bind:m  (peek path)
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
:: (avoids storing large amounts of data in the monad)
::
++  tree
  |=  =path
  =/  m  (charm ,(axal ~))
  ^-  form:m
  ;<  =cone  bind:m  (peek path)
  %-  pure:m
  %-  ~(gas of *(axal ~))
  (turn ~(tap of cone) |=([p=^path *] [p ~]))
::
++  get-perm
  |=  =path
  =/  m  (charm ,(unit perm))
  ^-  form:m
  =/  =dart  [%grub /get-perm &+path %peek ~]
  ;<  ~  bind:m  (send-raw-dart dart)
  ;<  [* =sand]  bind:m  (take-peek /get-perm)
  (pure:m (~(get of sand) /))
::
++  peek
  |=  =path
  =/  m  (charm ,cone)
  ^-  form:m
  =/  =dart  [%grub /peek &+path %peek ~]
  ;<  ~  bind:m  (send-raw-dart dart)
  ;<  [=cone *]  bind:m  (take-peek /peek)
  (pure:m cone)
::
++  peek-root
  |=  =path
  =/  m  (charm ,grub)
  ^-  form:m
  ;<  =cone  bind:m  (peek path)
  ?~  grub=(~(get of cone) /)
    (charm-fail %no-root-grub leaf+(spud path) ~)
  (pure:m u.grub)
::
++  peek-root-soft
  |=  =path
  =/  m  (charm ,(unit grub))
  ^-  form:m
  ;<  =cone  bind:m  (peek path)
  (pure:m (~(get of cone) /))
::
++  peek-root-as
  |*  [a=mold =path]
  =/  m  (charm ,a)
  ^-  form:m
  ;<  =grub  bind:m  (peek-root path)
  (pure:m !<(a (grab-data grub)))
::
++  peek-root-as-soft
  |*  [a=mold =path]
  =/  m  (charm ,(unit a))
  ^-  form:m
  ;<  grub=(unit grub)  bind:m  (peek-root-soft path)
  ?~  grub
    (pure:m ~)
  (pure:m `!<(a (grab-data u.grub)))
:: peek, but with relative path
::
++  grab
  |=  =path
  =/  m  (charm ,cone)
  ^-  form:m
  ;<  here=^path  bind:m  get-here
  (peek (weld here path))
::
++  grab-root
  |=  =path
  =/  m  (charm ,grub)
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
  =/  =dart  [%scry /scry mold path]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-scry mold /scry)
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
  =/  =dart  [%grub /kill-base &+path %kill pid]
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
  =/  =dart  [%grub /oust-grub &+path %oust ~]
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
  =/  =dart  [%grub /cull-cone &+path %cull ~]
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
      [~ %cull *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %cull-fail u.err.u.in]
  ==
::
++  edit-perm
  |=  [=path perm=(unit perm)]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart  [%grub /edit-perm &+path %sand perm]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-sand /edit-perm)
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
      [~ %sand *]
    ?.  =(wire wire.u.in)
      [%skip hold]
    ?~  err.u.in
      [%done ~]
    [%fail %sand-fail u.err.u.in]
  ==
::
++  make-stem
  |=  [=path stem=path sour=(set path)]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart  [%grub /make-stem &+path %make %stem stem sour]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-made /make-stem)
::
++  overwrite-stem
  |=  [=path stem=path sour=(set path)]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (oust-grub path)
  (make-stem path stem sour)
::
++  make-base
  |=  [=path base=path data=(unit vase)]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart  [%grub /make-base &+path %make %base base data]
  ;<  ~  bind:m  (send-raw-dart dart)
  (take-made /make-base)
::
++  overwrite-base
  |=  [=path base=path data=(unit vase)]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (oust-grub path)
  (make-base path base data)
::
++  make-and-poke
  |=  [=path base=path data=(unit vase) poke=pail]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (make-base path base data)
  (^poke path poke)
::
++  overwrite-and-poke
  |=  [=path base=path data=(unit vase) poke=pail]
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
      [/sig !>(code)]
    ==
  (pure:m ~)
::
++  overwrite-lib
  |=  [=path code=@t]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (edit-perm [%lib path] ~)
  ;<  ~  bind:m  (oust-grub [%lib path])
  (make-lib path code)
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
  ;<  =grub  bind:m  (peek-root from)
  ?-    -.grub
    %base  (overwrite-base to base.grub ~ data.grub)
    %stem  (overwrite-stem to stem.grub ~(key by sour.grub))
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
  ;<  =cone  bind:m  (peek from)
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
  |=  [here=path sour=(set path)]
  =/  m  (charm ,~)
  ^-  form:m
  ;<  =grub  bind:m  (peek-root here)
  ?>  ?=(%stem -.grub)
  (overwrite-stem here stem.grub sour)
::
++  get-bowl
  =/  m  (charm ,bowl)
  ^-  form:m
  |=  input
  [~ state temp %done bowl]
::
++  get-poke-pail
  =/  m  (charm ,pail)
  ^-  form:m
  |=  input
  [~ state temp %done pail]
::
++  get-time
  =/  m  (charm ,@da)
  ^-  form:m
  |=  input
  [~ state temp %done now.bowl]
::
++  get-our
  =/  m  (charm ,ship)
  ^-  form:m
  |=  input
  [~ state temp %done (need our.bowl)]
::
++  get-entropy
  =/  m  (charm ,@uvJ)
  ^-  form:m
  |=  input
  [~ state temp %done eny.bowl]
::
++  get-from
  =/  m  (charm ,from)
  ^-  form:m
  |=  input
  [~ state temp %done from.bowl]
::
++  get-here
  =/  m  (charm ,path)
  ^-  form:m
  |=  input
  ?>  ?=(%& -.here.bowl)
  [~ state temp %done p.here.bowl]
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
  [~ state temp %done !<(a state)]
::
++  gut-state-as
  |*  a=mold
  |=  gut=$-(tang a)
  =/  m  (charm ,a)
  ^-  form:m
  |=  input
  =/  res  (mule |.(!<(a state)))
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
::
++  commit
  |=  new=vase
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (replace new)
  :: when this card leaves %grubbery
  :: the state will have officially changed and
  :: all local dependency changes will have propagated
  (sleep ~s0)
:: do nothing and give a sig
::
++  done
  =/  m  (charm ,~)
  ^-  form:m
  (pure:m ~)
:: replace with value and give a sig
::
++  pour
  |=  new=vase
  =/  m  (charm ,~)
  ^-  form:m
  ;<  ~  bind:m  (replace new)
  done
::
++  perk
  |=  =pail
  =/  m  (charm ,~)
  ^-  form:m
  (send-raw-dart %perk /perk pail)
::
++  gall-poke
  |=  [=dock =cage]
  =/  m  (charm ,~)
  ^-  form:m
  =/  =dart  [%sysc %pass /poke %agent dock %poke cage]
  ;<  ~  bind:m  (send-raw-dart dart)
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
  =/  =dart  [%sysc %pass /poke %agent dock %poke cage]
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
      [~ %agent * %kick *]
    ?.  =(watch+wire wire.u.in)
      [%skip hold]
    [%done ~]
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
    (charm-fail %json-parse-error ~)
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
