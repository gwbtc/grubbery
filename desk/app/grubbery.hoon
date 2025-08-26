/-  g=grubbery
/+  grubbery, io=grubberyio, server, dbug, verb, default-agent
/=  x-  /mar/grub/sign-base
/=  x-  /mar/grub/action
/=  x-  /mar/grub/perk
|%
+$  card     card:agent:gall
+$  state-0
  $:  %0
      =cone:g
      =trac:g
      =sand:g
      =bindings:g
      =history:g
  ==
--
::
=|  state-0
=*  state  -
::
=<
::
%-  agent:dbug
%+  verb  |
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
    hc    ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  =^  cards  state
    abet:boot:hc
  [cards this]
::
++  on-save   !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =.  state  !<(state-0 old)
  =^  cards  state
    abet:boot:hc
  [cards this]
::
++  on-peek
  |=  =(pole knot)
  ^-  (unit (unit cage))
  ?+    pole  [~ ~]
      [%x %history since=@ta ~]
    =/  since=@da  (slav %da since.pole)
    ``noun+!>((tap:hon:g (lot:hon:g history ~ `since)))
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ~&  "poke to {<dap.bowl>} agent with mark {<mark>}"
  ?+    mark  (on-poke:def mark vase)
      %connect
    ?>  =(src our):bowl
    =+  !<([url=path =path] vase)
    :_  this
    [%pass [%connect path] %arvo %e %connect `url %grubbery]~
    ::
      %disconnect
    ?>  =(src our):bowl
    =+  !<(url=path vase)
    :-  [%pass / %arvo %e %disconnect `url]~
    this(bindings (~(del by bindings) url))
    ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    =/  lin=request-line:server
      (parse-request-line:server url.request.req)
    =/  prefix=(list @t)  (scag 1 site.lin)
    |-
    ?~  here=(~(get by bindings) prefix)
      ?.  (lth (lent prefix) (lent site.lin))
        ~&("strange url: {(spud site.lin)}" [~ this])
      $(prefix (scag +((lent prefix)) site.lin))
    =/  suffix=path  (slag (lent prefix) site.lin)
    :: send the request to the base grub with the longest
    :: corresponding prefix
    ::
    =/  dest=path  (weld u.here suffix)
    =.  dest
      |-
      ?^  get=(~(get of cone) dest)
        ?:  ?=(%base -.u.get)
          dest
        $(dest (snip dest))
      $(dest (snip dest))
    ::
    =/  =give:g  [|+[src sap]:bowl /[eyre-id]]
    ::
    =/  =pail:g  [/handle-http-request !>([lin req])]
    =^  cards  state
      abet:(poke-base:hc dest [give `pail] |)
    [cards this]
    ::
      %grub-action
    =+  !<(axn=action:protocol:g vase)
    ~&  here+here.axn
    =/  =give:g  [|+[src sap]:bowl wire.axn]
    ?-    +<.axn
        %make
      ?-    +>-.axn
          %base
        ?>  =(src our):bowl
        :: TODO: CLAMMING
        =/  data=(unit ^vase)  ?~(data.axn ~ `!>(u.data.axn))
        =^  cards  state
          abet:(make-base:hc give here.axn base.axn data)
        [cards this]
        ::
          %stem
        ?>  =(src our):bowl
        =^  cards  state
          abet:(make-stem:hc give [here stem sour]:axn)
        [cards this]
      ==
      ::
        %oust
      ?>  =(src our):bowl
      =^  cards  state
        abet:(oust-grub:hc give here.axn)
      [cards this]
      ::
        %cull
      ?>  =(src our):bowl
      =^  cards  state
        abet:(cull-cone:hc give here.axn)
      [cards this]
      ::
        %sand
      ?>  =(src our):bowl
      =^  cards  state
        abet:(edit-perm:hc give [here perm]:axn)
      [cards this]
      ::
        %poke
      :: peers can only poke beneath /peers/~sampel-palnet/ or /public
      ::
      ?>  ?|  =(src our):bowl
              ?=([%public ^] here.axn)
              ?.  ?=([%peers @ ^] here.axn)  |
              =(i.t.here.axn (scot %p src.bowl))
          ==
      =^  cards  state
        abet:(poke-base:hc here.axn [give ~ stud.axn !>(noun.axn)] &)
      [cards this]
      ::
        %bump
      :: peers can only bump beneath /peers/~sampel-palnet/ or /public
      ::
      ?>  ?|  =(src our):bowl
              ?=([%public ^] here.axn)
              ?.  ?=([%peers @ ^] here.axn)  |
              =(i.t.here.axn (scot %p src.bowl))
          ==
      =^  cards  state
        abet:(bump-base:hc here.axn pid.axn give [stud.axn !>(noun.axn)] &)
      [cards this]
      ::
        %kill
      ?>  =(src our):bowl
      =^  cards  state
        abet:(kill-base:hc give [here pid]:axn)
      [cards this]
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%base @ *]
    =^  cards  state
      abet:(take-watch path)
    [cards this]
    ::
      [%poke @ *]
    ?>  =(src.bowl (slav %p i.t.path))
    [~ this]
    ::
      [%http-response *]
    [~ this]
  ==
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  ?.  ?=([%base @ *] path)
    (on-leave:def path)
  =^  cards  state
    abet:(take-leave path)
  [cards this]
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?.  ?=([%base @ *] wire)
    (on-agent:def wire sign)
  =^  cards  state
    abet:(take-agent:hc wire sign)
  [cards this]
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ~&  >  wire+wire
  ?+    wire  (on-arvo:def wire sign)
      [%base @ *]
    =^  cards  state
      abet:(take-arvo:hc wire sign)
    [cards this]
    ::
      [%connect *]
    ?>  ?=([%eyre %bound *] sign)
    ?.  accepted.sign
      %-  (slog leaf+"Binding {(spud path.binding.sign)} to {(spud t.wire)} failed!" ~)
      [~ this]
    %-  (slog leaf+"{(spud path.binding.sign)} bound successfully to {(spud t.wire)}!" ~)
    [~ this(bindings (~(put by bindings) path.binding.sign t.wire))]
  ==
::
++  on-fail   on-fail:def
--
::
=|  cards=(list card)   :: list of gall-level effects
=|  takes=(list take:g) :: stack of grub-level function calls
|_  =bowl:gall
+*  this  .
++  emit-card   |=(=card this(cards [card cards]))
++  emit-cards  |=(cadz=(list card) this(cards (welp (flop cadz) cards)))
++  emit-take   |=(=take:g this(takes [take takes]))
++  gibs        [|+[our.bowl /gall/grubbery] /]
++  gibs-take
  |=  [[here=path pid=@ta] in=(unit intake:base:g)]
  (emit-take [here pid] gibs in)
::
++  make-from
  |=  [here=path pid=@ta]
  ^-  from:g
  &+(weld here /[pid])
::
++  get-here-pid
  |=  =from:g
  ^-  [path @ta]
  ?>  ?=(%& -.from)
  [(snip `path`p.from) (rear p.from)]
:: handle all takes and return effects and state
::
++  abet
  |-
  ?~  takes
    ~&  >  "done-abet!"
    [(flop cards) state]
  $(this (process-take(takes t.takes) i.takes))
::
++  boot
  ^+  this
  ~&  >  %booting
  =.  this  mass-kill
  =.  this  null-pokes
  =.  this  (oust-grub gibs /boot)
  =.  this  (make-base gibs /boot /boot ~)
  (poke-base /boot [gibs ~ /sig !>(~)] |)
::
++  new-last
  |=  [now=@da last=@da]
  ^-  @da
  =/  next=@da  ?:((lth last now) now +(last))
  |-
  ?.  (has:hon:g history next)
    next
  $(next +(next))
::
++  next-tack
  |=  here=path
  ^+  this
  ?~  tac=(~(get of trac) here)
    =/  step=@da  (new-last [now now]:bowl)
    =.  history  (put:hon:g history step here)
    this(trac (~(put of trac) here [step step] ~ | ~ [~ ~] ~))
  =^  del  history
    (del:hon:g history step.last.u.tac)
  ?:  &(=(~ sinx.u.tac) !(~(has of cone) here))
    this(trac (~(del of trac) here)) :: may occur in an oust
  =/  step=@da  (new-last now.bowl step.last.u.tac)
  =.  history  (put:hon:g history step here)
  this(trac (~(put of trac) here u.tac(step.last step)))
:: +decap from /lib/rudder
::
++  has-prefix
  |=  [head=path =path]
  ^-  ?
  ?~  head  %&
  ?~  path  %|
  ?.  =(i.head i.path)  %|
  $(head t.head, path t.path)
::
++  get-base-code
  |=  base=path
  ^-  base:g
  ?:  ?=([%boot ~] base)  boot:grubbery
  ?:  ?=([%lib ~] base)  base:lib:grubbery
  ?:  ?=([%bin ~] base)  base:bin:grubbery
  =/  =grub:g
    ~|  "{(spud base)}: base grub not found"
    (need (~(get of cone) (welp /bin/base base)))
  =/  =tack:g
    ~|  "{(spud base)}: base tack not found"
    (need (~(get of trac) (welp /bin/base base)))
  ?>  ?=(%stem -.grub)
  ?>  tidy.tack
  =/  res  (mule |.(!<([* b=base:g] (grab-data:io grub))))
  ?:  ?=(%& -.res)
    b.p.res
  ~|("base {(spud base)} failed to compile" !!)
::
++  get-base-stud
  |=  base=path
  ^-  stud:g
  ?:  ?=([%boot ~] base)  /sig
  ?:  ?=([%lib ~] base)  /lib
  ?:  ?=([%bin ~] base)  /bin
  =/  =grub:g
    ~|  "{(spud base)}: base grub not found"
    (need (~(get of cone) (welp /bin/base base)))
  =/  =tack:g
    ~|  "{(spud base)}: base tack not found"
    (need (~(get of trac) (welp /bin/base base)))
  ?>  ?=(%stem -.grub)
  ?>  tidy.tack
  =/  res  (mule |.(!<([=stud:g *] (grab-data:io grub))))
  ?:  ?=(%& -.res)
    stud.p.res
  ~|("base {(spud base)} failed to compile" !!)
::
++  get-stem-code
  |=  stem=path
  ^-  stem:g
  ?:  ?=([%bin ~] stem)  stem:bin:grubbery
  =/  =grub:g  
    ~|  "{(spud stem)}: stem grub not found"
    (need (~(get of cone) (welp /bin/stem stem)))
  =/  =tack:g  
    ~|  "{(spud stem)}: stem tack not found"
    (need (~(get of trac) (welp /bin/stem stem)))
  ?>  ?=(%stem -.grub)
  ?>  tidy.tack
  =/  res  (mule |.(!<([* s=stem:g] (grab-data:io grub))))
  ?:  ?=(%& -.res)
    s.p.res
  ~|("stem {(spud stem)} failed to compile" !!)
::
++  get-stem-stud
  |=  stem=path
  ^-  stud:g
  ?:  ?=([%bin ~] stem)  /bin
  =/  =grub:g  
    ~|  "{(spud stem)}: stem grub not found"
    (need (~(get of cone) (welp /bin/stem stem)))
  =/  =tack:g  
    ~|  "{(spud stem)}: stem tack not found"
    (need (~(get of trac) (welp /bin/stem stem)))
  ?>  ?=(%stem -.grub)
  ?>  tidy.tack
  =/  res  (mule |.(!<([=stud:g *] (grab-data:io grub))))
  ?:  ?=(%& -.res)
    stud.p.res
  ~|("stem {(spud stem)} failed to compile" !!)
:: only useful for clamming
::
++  get-stud
  |=  =stud:g
  ^-  vase
  ?:  ?=([%sig ~] stud)  !>(,~)
  ?:  ?=([%lib ~] stud)
    !>(,[@t (each [(list (pair term path)) hoon] tang)])
  ?:  ?=([%bin ~] stud)  !>(noun)
  =/  =grub:g
    ~|  "{(spud stud)}: stud grub not found"
    (need (~(get of cone) (welp /bin/stud stud)))
  =/  =tack:g  
    ~|  "{(spud stud)}: stud tack not found"
    (need (~(get of trac) (welp /bin/stud stud)))
  ?>  ?=(%stem -.grub)
  ?>  tidy.tack
  (grab-data:io grub)
::
++  bunt-stud
  |=  =stud:g
  ^-  vase
  =/  func=vase  (get-stud stud)
  (slam func (slot 6 func))
::
++  no-cycle
  =|  hist=(list path)
  |=  here=path
  ^-  ?
  =/  i=(unit @ud)  (find [here]~ hist) 
  =/  cycle=(list path)  ?~(i ~ [here (scag +(u.i) hist)])
  ?^  cycle
    ~&  ["ERROR: cycle" cycle]
    %| :: a cycle has been found
  ?~  nod=(~(get of cone) here)
    %& :: non-existent grubs aren't a cycle
  ?:  ?=(%base -.u.nod)
    %&
  =/  sour=(list path)  ~(tap in ~(key by sour.u.nod))
  |-
  ?~  sour
    %&
  ?.  ^$(hist [here hist], here i.sour)
    %|
  $(sour t.sour)
::
++  no-cycles
  |=  [here=path sour=(list path)]
  ^-  ?
  ?~  sour
    %&
  ?.  %*($ no-cycle hist ~[here], here i.sour)
    %|
  $(sour t.sour)
::
++  add-sources
  |=  [here=path sour=(set path)]
  ^+  this
  =/  sour=(list path)  ~(tap in sour)
  ?>  (no-cycles here sour)
  =/  =grub:g  (need (~(get of cone) here))
  ?>  ?=(%stem -.grub)
  |-
  ?~  sour
    this(cone (~(put of cone) here grub))
  =/  tac=(unit tack:g)  (~(get of trac) i.sour)
  =?  this  ?=(~ tac)  (next-tack i.sour)
  =/  =tack:g  (need (~(get of trac) i.sour))
  =.  sinx.tack  (~(put in sinx.tack) here)
  =.  trac  (~(put of trac) i.sour tack)
  =.  sour.grub  (~(put by sour.grub) i.sour `@da`0) :: 0 forces recompute
  $(sour t.sour)
::
++  allowed
  =|  prefix=(unit path)
  |=  [here=path =dart:g]
  ^-  (each (unit path) ~)
  =/  res  (allowed:grubbery here dart (~(get of sand) here))
  ?-    -.res
    %|  [%| ~]
      %&
    =?  prefix  &(?=(~ prefix) ?=(^ p.res))  p.res
    ?:  =(~ here)
      [%& prefix]
    $(here (snip here))
  ==
::
++  handle-base-emits
  |=  [here=path pid=@ta darts=(list dart:g)]
  ^+  this
  ?~  darts
    this
  =/  =tack:g  (need (~(get of trac) here))
  =.  this  (handle-base-emit here pid i.darts)
  $(darts t.darts)
::
++  handle-dart
  =/  clam=?  |
  |=  [here=path pid=@ta =dart:g]
  ^+  this
  =/  =from:g  (make-from here pid)
  ?-    -.dart
      %sysc
    :: TODO: keep track of scrying with %keen so you can
    ::       cancel with %yawn when you kill
    ::       a process or when it crashes
    ::
    (handle-sysc-card here pid card.dart)
    ::
      %scry
    (take-scry here pid [wire mold path]:dart)
    ::
      %perk
    (give-perk here pid [wire pail]:dart)
    ::
      %grub
    =/  =path  (need (path-from-road:grubbery here road.dart))
    ?-    -.load.dart
        %poke
      (poke-base path [[from wire.dart] `pail.load.dart] clam)
      ::
        %bump
      (bump-base path [pid.load [from wire] pail.load clam]:[dart .])
      ::
        %peek
      (take-peek here pid wire.dart path)
      ::
        %make
      =/  =give:g  [from wire.dart]
      ?-  -.make.load.dart
        %base  (make-base give path [base data]:make.load.dart)
        %stem  (make-stem give path [stem sour]:make.load.dart)
      ==
      ::
        %oust
      (oust-grub [from wire.dart] path)
      ::
        %cull
      (cull-cone [from wire.dart] path)
      ::
        %sand
      (edit-perm [from wire.dart] path perm.load.dart)
      ::
        %kill
      (kill-base [from wire.dart] path pid.load.dart)
    ==
  ==
::
++  handle-base-emit
  |=  [here=path pid=@ta =dart:g]
  ^+  this
  =/  res  (allowed here dart)
  ?-    -.res
      %|
    ~&  >>>  "vetoing illegal dart from {(spud here)}"
    (gibs-take [here pid] ~ %veto dart)
    ::
      %&
    ?~  p.res                                 (handle-dart here pid dart)
    ?^  (decap:grubbery u.p.res here)         (handle-dart here pid dart)
    ?.  ?=(%grub -.dart)                      (handle-dart here pid dart)
    ?.  ?=(?(%poke %bump %make) -.load.dart)  (handle-dart here pid dart)
    ?-    -.load.dart
      %poke  %*($ handle-dart clam &, +6 [here pid dart])
      %bump  %*($ handle-dart clam &, +6 [here pid dart])
      ::
        %make
      :: TODO: incorporate directly into +make-base
      ?:  ?=(%stem -.make.load.dart)  (handle-dart here pid dart)
      ?~  data.make.load.dart         (handle-dart here pid dart)
      =/  res
        (mule |.((get-stud (get-base-stud base.make.load.dart))))
      ?:  ?=(%| -.res)
        (gibs-take [here pid] ~ %made wire.dart ~ leaf+"make-stud-fail" p.res)
      =/  res  (mule |.((slam p.res u.data.make.load.dart)))
      ?:  ?=(%| -.res)
        (gibs-take [here pid] ~ %made wire.dart ~ leaf+"make-clam-fail" p.res)
      (handle-dart here pid dart(data.make.load [~ p.res]))
    ==
  ==
::
++  dirty
  |=  here=path
  ^-  [(set path) _this]
  ~&  >>  "dirtying {(spud here)}"
  ~|  "failed to dirty {(spud here)}"
  =/  =grub:g  (need (~(get of cone) here))
  =/  =tack:g  (need (~(get of trac) here))
  ?:  &(?=(%stem -.grub) !tidy.tack)
    [~ this]
  =?  trac  ?=(%stem -.grub)
    (~(put of trac) here tack(tidy |))
  ?:  =(0 ~(wyt in sinx.tack))
    ?:  ?=(%base -.grub)
      [~ this]
    [(sy ~[here]) this]
  =/  sinx=(list path)  ~(tap in sinx.tack)
  ~|  sinx+sinx
  =|  edge=(set path)
  |-
  ?~  sinx
    [edge this]
  =^  e  this  (dirty i.sinx)
  %=  $
    sinx   t.sinx
    edge   (~(uni in edge) e)
  ==
::
++  tidy
  |=  here=path
  ^+  this
  ~&  >>  "tidying {(spud here)}"
  ?~  grub=(~(get of cone) here)
    ~&  >>  "{(spud here)} has no data"
    this
  ?~  tack=(~(get of trac) here)
    ~&  >>  "{(spud here)} has no tack"
    this
  ?:  ?=(%base -.u.grub)
    ~&  >>  "{(spud here)} is a base and thus tidy"
    this
  ?:  tidy.u.tack
    ~&  >>  "{(spud here)} is already tidy"
    this
  =/  sour=(list (pair path @da))  ~(tap by sour.u.grub)
  |-
  ?~  sour
    (recompute-stem here u.grub)
  $(sour t.sour, this (tidy p.i.sour))
::
++  make-deps
  |=  [here=path sour=(set path)]
  ^-  (map path (each vase tang))
  %-  ~(gas by *(map path (each vase tang)))
  %+  turn  ~(tap in sour)
  |=  =path
  :-  path
  ?~  grub=(~(get of cone) path)
    |+[leaf+"no grub {(spud here)}" ~]
  (grab-data-soft:io u.grub)
::
++  make-sour
  |=  sour=(set path)
  ^-  (map path @da)
  %-  ~(gas by *(map path @da))
  %+  turn  ~(tap in sour)
  |=  =path
  :-  path
  step.last:(need (~(get of trac) path))
::
++  recompute-stem
  |=  [here=path =grub:g]
  ^+  this
  ~&  >>  "recompute stem"
  ?>  ?=(%stem -.grub)
  =/  new-sour=(map path @da)  (make-sour ~(key by sour.grub))
  =/  =tack:g  (need (~(get of trac) here))
  ?:  =(new-sour sour.grub)
    ~&  >>  "{(spud here)} hasn't changed on recompute"
    this(trac (~(put of trac) here tack(tidy &)))
  =/  res=(each vase tang)
    %-  mule  |.
    =/  =stem:g  (get-stem-code stem.grub)
    =/  deps=(map path (each vase tang))
      (make-deps here ~(key by sour.grub)) :: sandboxed deps
    (stem [here deps]:[bowl .])
  ?-    -.res
      %|
    ~&  >>>  "{(spud here)} crashed on recompute"
    =/  =tang  [leaf+"stem boom" leaf+(spud here) p.res]
    =?  this  !=(data.grub |+tang)  (next-tack here)
    %-  (slog tang)
    %=  this
      cone  (~(put of cone) here grub(data |+tang))
      trac  (~(put of trac) here tack(tidy %&))
    ==
    ::
      %&
    ~&  >  "{(spud here)} successfully recomputed"
    =?  this  !=(data.grub &+p.res)  (next-tack here)
    %=  this
      cone  (~(put of cone) here grub(data &+p.res, sour new-sour))
      trac  (~(put of trac) here tack(tidy %&))
    ==
  ==
::
++  dirty-and-tidy
  |=  here=path
  ^+  this
  ~&  >>  "dirty-and-tidy {(spud here)}"
  =^  e  this  (dirty here)
  =/  edge=(list path)  ~(tap in e)
  |-
  ?~  edge
    this
  =.  this  (tidy i.edge)
  $(edge t.edge)
::
++  del-sources
  |=  here=path
  ^+  this
  ~|  "deleting sources of {(spud here)} failed"
  =/  =grub:g  (need (~(get of cone) here))
  ?>  ?=(%stem -.grub)
  =/  sour=(list path)  (turn ~(tap in sour.grub) head)
  |-
  ?~  sour
    this
  =/  =tack:g    (need (~(get of trac) i.sour))
  =.  sinx.tack  (~(del in sinx.tack) here)
  ?:  &(=(~ sinx.tack) !(~(has of cone) i.sour))
    $(sour t.sour, trac (~(del of trac) i.sour))
  $(sour t.sour, trac (~(put of trac) i.sour tack))
::
++  do-oust
  |=  here=path
  ^+  this
  ?~  grub=(~(get of cone) here)
    this
  =.  this
    ?-  -.u.grub
      %base  (kill-all here)
      %stem  (del-sources here)
    ==
  =.  cone  (~(del of cone) here)
  (next-tack here)
::
++  do-cull
  |=  here=path
  ^+  this
  =/  hone=cone:g  (~(dip of cone) here)
  ?:  =(~ dir.hone)
    =.  this  (do-oust here)
    this(cone (~(lop of cone) here))
  =/  next=(list @ta)  ~(tap in ~(key by dir.hone))
  |-
  ?~  next
    this
  =.  this  (do-cull (snoc here i.next))
  $(next t.next)
::
++  oust-grub
  |=  [=give:g here=path]
  ^+  this
  ~&  >  "ousting {(spud here)}"
  =/  res=(each _this tang)  (mule |.((do-oust here)))
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %gone wire.give err)
::
++  cull-cone
  |=  [=give:g here=path]
  ^+  this
  =/  res=(each _this tang)  (mule |.((do-cull here)))
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %cull wire.give err)
::
++  put-sand
  |=  [here=path perm=(unit perm:g)]
  ^+  this
  ?>  ?=(^ here) :: root should always have system access
  ?~  perm
    this(sand (~(del of sand) here))
  =.  u.perm  (clean-perm:grubbery here u.perm)
  this(sand (~(put of sand) here u.perm))
::
++  edit-perm
  |=  [=give:g here=path perm=(unit perm:g)]
  ^+  this
  =/  res=(each _this tang)  (mule |.((put-sand here perm)))
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %sand wire.give err)
::
++  new-base
  |=  [here=path base=path data=(unit vase)]
  ^+  this
  ~|  "making base {(spud here)} failed"
  ?<  (~(has of cone) here)
  =/  =stud:g  (get-base-stud base)
  =/  data=vase  (fall data (bunt-stud stud))
  =/  =grub:g  [%base data base]
  =.  cone  (~(put of cone) here grub)
  =.  this  (next-tack here)
  (dirty-and-tidy here)
:: TODO: incorporate clamming
::
++  make-base
  |=  [=give:g here=path base=path data=(unit vase)]
  ^+  this
  ~&  >  "making-base {(spud here)} with {(spud base)}"
  =/  res=(each _this tang)  (mule |.((new-base here base data)))
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %made wire.give err)
::
++  new-stem
  |=  [here=path stem=path sour=(set path)]
  ^+  this
  ~&  >  "making-stem {(spud here)} with {(spud stem)}"
  ~|  "making stem {(spud here)} failed"
  ?<  =(~ sour)
  ?<  (~(has of cone) here)
  ?<  ?=([%lib *] here) :: stems not allowed in /lib
  =/  =stud:g  (get-stem-stud stem)
  =/  =grub:g  [%stem |+[leaf+"new stem"]~ stem ~]
  =.  cone     (~(put of cone) here grub)
  =.  this     (add-sources here sour)
  =.  this     (next-tack here)
  =/  =tack:g  (need (~(get of trac) here))
  =.  trac     (~(put of trac) here tack(tidy |))
  ~&  >>  "computing-new-stem {(spud here)}"
  =.  this     (recompute-stem here (need (~(get of cone) here)))
  (dirty-and-tidy here)
::
++  make-stem
  |=  [=give:g here=path stem=path sour=(set path)]
  ^+  this
  =/  res=(each _this tang)  (mule |.((new-stem here stem sour)))
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %made wire.give err)
::
++  take-peek
  |=  [here=path pid=@ta =wire pat=path]
  ^+  this
  :: TODO: clam when peeking into a sandboxed cone?
  (gibs-take [here pid] ~ %peek wire pat (~(dip of cone) pat) (~(dip of sand) pat))
::
++  take-scry
  |=  [here=path pid=@ta =wire =mold pat=path]
  ^+  this
  =;  =vase
    (gibs-take [here pid] ~ %scry wire pat vase)
  ?>  ?=(^ pat)
  ?>  ?=(^ t.pat)
  !>(.^(mold i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat))
::
++  kill
  |=  [here=path pid=@ta]
  ^+  this
  ~|  "killing process {(trip pid)} at {(spud here)} failed"
  =/  =tack:g  (need (~(get of trac) here))
  ?.  (~(has by proc.tack) pid)
    ~&  >>  "no process {(trip pid)} to kill at {(spud here)}"
    this
  (give-final-poke-ack here pid ~ %killed [leaf+(spud here) ~])
::
++  kill-all
  |=  here=path
  ^+  this
  ?~  tack=(~(get of trac) here)
    this 
  ?~  lit=~(tap in ~(key by proc.u.tack))
    this
  $(this (kill here i.lit))
:: in preparation for mass-kill, clear all local gives
::
++  wipe-gives
  ^+  this
  %=    this
      trac
    %-  ~(gas of *(axal tack:g))
    %+  turn  ~(tap of trac)
    |=  [here=path =tack:g]
    ^-  [path tack:g]
    :-  here
    %=    tack
        proc
      %-  ~(gas by *(map @ta proc:g))
      %+  turn  ~(tap by proc.tack)
      |=  [pid=@ta =proc:g]
      ^-  [@ta proc:g]
      :-  pid
      ?:  ?=(%| -.from.give.poke.proc) :: from outside grubbery
        proc
      proc(give.poke gibs)
    ==
  ==
::
++  mass-kill
  ^+  this
  =.  this  wipe-gives
  =/  paths=(list path)  (turn ~(tap of trac) head)
  |-
  ?~  paths
    this
  $(paths t.paths, this (kill-all i.paths))
::
++  null-pokes
  ^+  this
  =/  paths=(list path)  (turn ~(tap of trac) head)
  |-
  ?~  paths
    this
  $(paths t.paths, this (poke-base i.paths [gibs ~] |))
::
++  kill-base
  |=  [=give:g here=path pid=(unit @ta)]
  ^+  this
  =/  res=(each _this tang)
    %-  mule  |.
    ?~  pid
      (kill-all here)
    (kill here u.pid)
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %dead wire.give err)
::
++  bump-base
  |=  [here=path pid=@ta =give:g =pail:g clam=?]
  ^+  this
  ?.  clam
    (gibs-take [here pid] ~ %bump pail)
  =/  stud-res  (mule |.((get-stud p.pail)))
  ?:  ?=(%| -.stud-res)
    =/  =sign:base:g  [%bump ~ leaf+"bump-stud-fail" p.stud-res]
    ?:  ?=(%| -.from.give)
      (give-external-sign give sign)
    =/  here-pid=[path @ta]  (get-here-pid from.give)
    (gibs-take here-pid ~ %base wire.give sign)
  =/  clam-res  (mule |.((slam p.stud-res q.pail)))
  ?:  ?=(%| -.clam-res)
    =/  =sign:base:g  [%bump ~ leaf+"bump-clam-fail" p.clam-res]
    ?:  ?=(%| -.from.give)
      (give-external-sign give sign)
    =/  here-pid=[path @ta]  (get-here-pid from.give)
    (gibs-take here-pid ~ %base wire.give sign)
  (gibs-take [here pid] ~ %bump pail)
:: TODO: handle outgoing keens
::
++  clean
  |=  [here=path pid=@ta]
  ^+  this
  %-  emit-cards
  %+  murn  ~(tap by wex.bowl)
  |=  [[=wire =ship =term] *]
  ^-  (unit card)
  ?.  ?=([%base @ *] wire)
    ~
  =/  [h=path p=@ta *]  (unwrap-wire wire)
  ?.  &(=(h here) =(p pid))
    ~
  [~ %pass wire %agent [ship term] %leave ~]
::
++  make-pid
  |=  here=path
  ^-  @ta
  =/  =tack:g  (need (~(get of trac) here))
  =/  last=@da  poke.last.tack
  =/  next=@da  ?:((lth last now.bowl) now.bowl +(last))
  |-
  ?:  (~(has by proc.tack) (scot %da next))
    $(next +(next))
  (scot %da next)
::
++  give-external-sign
  |=  [=give:g =sign:base:g]
  ^+  this
  ?>  ?=(%| -.from.give) :: assert from outside grubbery
  =/  src=@ta  (scot %p src.p.from.give)
  =/  =wire  (weld /poke/[src] wire.give)
  %-  emit-cards
  :~  [%give %fact ~[wire] grub-sign-base+!>(sign)]
      [%give %kick ~[wire] ~]
  ==
::
++  start-process
  |=  [[here=path pid=@ta] =proc:base:g =poke:g]
  ^+  this
  =/  =sign:base:g  [%pack %& pid]
  =.  this
    ?:  ?=(%| -.from.give.poke)
      (give-external-sign give.poke sign)
    (gibs-take (get-here-pid from.give.poke) ~ %base wire.give.poke sign)
  =/  =tack:g  (need (~(get of trac) here))
  =.  proc.tack  (~(put by proc.tack) pid [proc poke ~ ~])
  =.  trac  (~(put of trac) here tack)
  (gibs-take [here pid] ~)
::
++  poke-base
  |=  [here=path =poke:g clam=?]
  ^+  this
  ~&  >  "poking base {(spud here)}"
  =/  grub=(unit grub:g)  (~(get of cone) here)
  ?~  grub
    ~&  >>  "ignoring poke to empty path {(spud here)}"
    this
  ?.  ?=(%base -.u.grub)
    ~&  >>  "ignoring poke to stem {(spud here)}"
    this
  =/  pid=@ta  (make-pid here)
  =/  build=(each proc:base:g tang)
    (mule |.((get-base-code base.u.grub)))
  ?:  ?=(%| -.build)
    =/  =sign:base:g  [%pack %| leaf+"build-error" p.build]
    ?:  ?=(%| -.from.give.poke)
      (give-external-sign give.poke sign)
    (gibs-take (get-here-pid from.give.poke) ~ %base wire.give.poke sign)
  ?~  pail.poke
    (start-process [here pid] p.build poke)
  ?.  clam
    (start-process [here pid] p.build poke)
  =/  stud-res  (mule |.((get-stud p.u.pail.poke)))
  ?:  ?=(%| -.stud-res)
    =/  =sign:base:g  [%pack %| leaf+"poke-stud-fail" p.stud-res]
    ?:  ?=(%| -.from.give.poke)
      (give-external-sign give.poke sign)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke)
    (gibs-take here-pid ~ %base wire.give.poke sign)
  =/  clam-res  (mule |.((slam p.stud-res q.u.pail.poke)))
  ?:  ?=(%| -.clam-res)
    =/  =sign:base:g  [%pack %| leaf+"poke-clam-fail" p.clam-res]
    ?:  ?=(%| -.from.give.poke)
      (give-external-sign give.poke sign)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke)
    (gibs-take here-pid ~ %base wire.give.poke sign)
  (start-process [here pid] p.build poke(q.u.pail p.clam-res))
::
++  make-dish
  |=  [here=path pid=@ta]
  ^-  dish:eval:grubbery
  =.  wex.bowl
    %-  ~(gas by *boat:gall)
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] acked=? pat=path]
    ?.  ?=([%base @ *] wire)
      ~
    =/  [h=path p=@ta w=path]  (unwrap-wire wire)
    ?.  &(=(h here) =(p pid))
      ~
    [~ [w ship term] acked pat]
  =.  sup.bowl
    %-  ~(gas by *bitt:gall)
    %+  murn  ~(tap by sup.bowl)
    |=  [=duct =ship pat=path]
    ?.  ?=([%base @ *] pat)
      ~
    =/  [h=path p=@ta w=path]  (unwrap-wire pat)
    ?.  &(=(h here) =(p pid))
      ~
    [~ duct ship w]
  [now our eny wex sup here pid (~(get of sand) here)]:[bowl .]
:: ack for perk or bump
::
++  give-poke-sign
  |=  [take:base:g err=(unit tang)]
  ^+  this
  ?.  ?=([~ %bump *] in)  this
  ~&  >>  %giving-bump-sign
  =/  =sign:base:g  [%bump err]
  ?:  ?=(%| -.from.give)
    (give-external-sign give sign)
  (gibs-take (get-here-pid from.give) ~ %base wire.give sign)
::
++  give-poke-signs
  |=  done=(list [take:base:g (unit tang)])
  ^+  this
  ?~  done
    this
  =.  this  (give-poke-sign i.done)
  $(done t.done)
::
++  process-take
  |=  [[here=path pid=@ta] =take:base:g]
  ^+  this
  ~&  >>  %processing-intake
  ~&  >>  [here pid]
  =/  =tack:g  (need (~(get of trac) here))
  ?.  (~(has by proc.tack) pid)
    ~&  >>  "discarding message for non-existent process {(trip pid)}"
    (give-poke-sign take ~ leaf+"non-existent process" ~)
  =/  =grub:g  (need (~(get of cone) here))
  =/  =tack:g  (need (~(get of trac) here))
  =/  =proc:g  (~(got by proc.tack) pid)
  =.  next.proc  (~(put to next.proc) take)
  =.  proc.tack  (~(put by proc.tack) pid proc)
  =.  trac       (~(put of trac) here tack)
  (process-do-next here pid)
::
++  process-do-next
  |=  [here=path pid=@ta]
  ^+  this
  =/  =tack:g  (need (~(get of trac) here))
  ?>  (~(has by proc.tack) pid)
  =/  =grub:g  (need (~(get of cone) here))
  =/  =tack:g  (need (~(get of trac) here))
  =/  =proc:g  (~(got by proc.tack) pid)
  ?.  |(=(~ boar.tack) =([~ pid] boar.tack))
    this
  ?:  =(~ next.proc)
    this
  ?>  ?=(%base -.grub)
  =/  m  (charm:base:g ,~)
  =/  =dish:eval:grubbery  (make-dish here pid)
  =/  [darts=(list dart:g) done=(list took:eval:grubbery) data=vase temp=(axal vase) =proc:g =result:eval:grubbery]
    (take:eval:grubbery dish data.grub temp.tack proc)
  ::
  ~&  >>  -.result
  ::
  =/  tick=?  !=(data data.grub)
  =?  this  tick  (next-tack here)
  =.  cone  (~(put of cone) here grub(data data))
  ::
  =.  temp.tack  temp
  =.  proc.tack  (~(put by proc.tack) pid proc)
  =.  trac  (~(put of trac) here tack)
  ::
  =?  this  tick  (dirty-and-tidy here)
  ::
  =.  this  (give-poke-signs done)
  ::
  =.  this  (handle-base-emits here pid darts)
  ::
  ?.  (~(has of trac) here)
    ~&  >>  %tack-expired
    this
  =/  =tack:g  (need (~(get of trac) here))
  ?.  (~(has by proc.tack) pid)
    ~&  >>  %proc-expired
    this
  ::
  ?:  ?=(%next -.result)
    ?:  hold.result
      (claim here pid)
    (relinquish here)
  ::
  ?>  ?=(?(%fail %done) -.result)
  %^    give-final-poke-ack
      here
    pid
  ?-  -.result
    %done  ~
    %fail  [~ err.result]
  ==
::
++  give-http-perk
  |=  [eyre-id=wire =pail:g]
  ^+  this
  =/  =wire  (weld /http-response eyre-id)
  =/  =cage  
    ?+    p.pail  !!
      [%http-response-data ~]    http-response-data+q.pail
      [%http-response-header ~]  http-response-header+q.pail
    ==
  (emit-card %give %fact ~[wire] cage)
::
++  give-external-perk
  |=  [=give:g =pail:g]
  ^+  this
  ?>  ?=(%| -.from.give) :: assert from outside grubbery
  =/  src=@ta  (scot %p src.p.from.give)
  =/  =wire  (weld /poke/[src] wire.give)
  (emit-card %give %fact ~[wire] grub-perk+!>([p.pail q.q.pail]))
::
++  give-perk
  |=  [here=path pid=@ta back=wire =pail:g]
  ^+  this
  ~&  %giving-perk
  ~&  [here+here pid+pid]
  =/  =grub:g  (need (~(get of cone) here))
  ?>  ?=(%base -.grub)
  =/  =tack:g  (need (~(get of trac) here))
  =/  =proc:g  (~(got by proc.tack) pid)
  ?:  ?=(%& -.from.give.poke.proc)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke.proc)
    =/  =give:g  [(make-from here pid) back]
    (emit-take here-pid give ~ %perk wire.give.poke.proc pail)
  ?:  ?=([%gall *] sap.p.from.give.poke.proc)
    (give-external-perk give.poke.proc pail)
  ?>  ?=([%eyre *] sap.p.from.give.poke.proc)
  (give-http-perk wire.give.poke.proc pail)
::
++  claim
  |=  [here=path pid=@ta]
  ^+  this
  =/  =tack:g  (need (~(get of trac) here))
  ?>  |(=(~ boar.tack) =([~ pid] boar.tack))
  =.  boar.tack  [~ pid]
  this(trac (~(put of trac) here tack))
::
++  relinquish
  |=  here=path
  ^+  this
  =/  =tack:g  (need (~(get of trac) here))
  =.  boar.tack  ~
  =.  trac  (~(put of trac) here tack)
  =/  pids=(list @ta)  ~(tap in ~(key by proc.tack))
  |-
  ?~  pids
    this
  $(pids t.pids, this (process-do-next here i.pids))
::
++  give-http-poke-sign
  |=  [eyre-id=wire err=(unit tang)]
  ^+  this
  =/  =wire  (weld /http-response eyre-id)
  ?~  err
    :: TODO: give some positive response?
    ::
    (emit-card %give %kick ~[wire] ~)
  =/  =simple-payload:http  (internal-server-error:io & "" u.err)
  =/  header=cage  [%http-response-header !>(response-header.simple-payload)]
  =/  data=cage    [%http-response-data !>(data.simple-payload)]
  =.  this  (emit-card %give %fact ~[wire] header)
  =.  this  (emit-card %give %fact ~[wire] data)
  (emit-card %give %kick ~[wire] ~)
::
++  give-final-poke-ack
  |=  [here=path pid=@ta res=(unit tang)]
  ^+  this
  ~|  %give-final-poke-ack-fail
  ~&  %giving-final-poke-ack
  ~&  here+here
  =/  =grub:g  (need (~(get of cone) here))
  ?>  ?=(%base -.grub)
  =/  =tack:g  (need (~(get of trac) here))
  =/  =proc:g  (~(got by proc.tack) pid)
  =.  proc.tack  (~(del by proc.tack) pid)
  =.  this  (relinquish here)
  =.  trac  (~(put of trac) here tack)
  =.  this  (clean here pid)
  =/  =sign:base:g  [%poke res]
  ?:  ?=(%& -.from.give.poke.proc)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke.proc)
    (gibs-take here-pid ~ %base wire.give.poke.proc sign)
  ?:  ?=([%clay *] sap.p.from.give.poke.proc) :: on-init / on-load
    ?~(res this ((slog u.res) this))
  ?:  ?=([%gall *] sap.p.from.give.poke.proc)
    ?:  ?=([%grubbery ~] t.sap.p.from.give.poke.proc)
      ?~(res this ((slog u.res) this))
    (give-external-sign give.poke.proc sign)
  ?>  ?=([%eyre *] sap.p.from.give.poke.proc)
  (give-http-poke-sign wire.give.poke.proc res)
::
++  wrap-wire
  |=  [here=path pid=@ta =wire]
  ^+  wire
  ;:  weld
    /base/(scot %ud (lent here))
    here  /[pid]  wire
  ==
::
++  unwrap-wire
  |=  =wire
  ^-  [path @ta ^wire]
  ?>  ?=([%base @ *] wire)
  =/  len=@ud  (slav %ud i.t.wire)
  :+  (scag len t.t.wire)
    (snag len t.t.wire)
  (slag +(len) t.t.wire)
::
++  handle-sysc-card
  |=  [here=path pid=@ta =card:agent:gall]
  ^+  this
  ?+    card  (emit-card card)
      [%give ?(%fact %kick) *]
    =-  (emit-card card(paths.p -))
    (turn paths.p.card |=(p=path (wrap-wire here pid p)))
    ::
      [%pass * *]
    (emit-card [%pass (wrap-wire here pid p.card) q.card])
  ==
::
++  take-arvo
  |=  [wir=wire sign=sign-arvo]
  ^+  this
  =/  [here=path pid=@ta =wire]  (unwrap-wire wir)
  (gibs-take [here pid] ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=path pid=@ta =wire]  (unwrap-wire wir)
  (gibs-take [here pid] ~ %agent wire sign)
::
++  take-watch
  |=  pat=path
  ^+  this
  =/  [here=path pid=@ta =wire]  (unwrap-wire pat)
  (gibs-take [here pid] ~ %watch wire)
::
++  take-leave
  |=  pat=path
  ^+  this
  =/  [here=path pid=@ta =wire]  (unwrap-wire pat)
  (gibs-take [here pid] ~ %leave wire)
--
