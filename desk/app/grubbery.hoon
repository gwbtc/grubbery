/-  g=grubbery
/+  grubbery, io=grubberyio, server, dbug, verb, default-agent
/=  x-  /mar/grub/sign-base :: x- means import for compilation in development
/=  x-  /mar/grub/action
/=  x-  /mar/grub/perk
/=  x-  /mar/grub/event
::
|%
+$  card     card:agent:gall
+$  state-0
  $:  %0
      =cone:g
      =trac:g
      =pool:g
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
    ::
      [%c t=*]
    =/  here=path  (snip t.pole)
    =/  ship=@p  (slav %p (rear t.pole))
    :: TODO: implement security context logic (Remote Scry)
    ::
    ``[%noun !>(=(ship our.bowl))]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ~&  "poke to {<dap.bowl>} agent with mark {<mark>}"
  ?+    mark  (on-poke:def mark vase)
      %connect
    ?>  =(src our):bowl
    :: connect grub at path to url prefix
    ::
    =+  !<([url=path =path] vase)
    :_  this
    [%pass [%connect path] %arvo %e %connect `url %grubbery]~
    ::
      %disconnect
    ?>  =(src our):bowl
    :: disconnect whatever grub bound at url prefix
    ::
    =+  !<(url=path vase)
    :-  [%pass / %arvo %e %disconnect `url]~
    this(bindings (~(del by bindings) url))
    ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    =/  lin=request-line:server  (parse-request-line:server url.request.req)
    :: recursively extend a prefix of the site path and look for bindings
    ::
    =/  prefix=(list @t)  (scag 1 site.lin)
    |-
    ?~  here=(~(get by bindings) prefix)
      ?:  (lth (lent prefix) (lent site.lin))
        :: site not exhausted; pop next term into prefix
        ::
        $(prefix (scag +((lent prefix)) site.lin))
      :: no prefix left to pop and nothing bound
      ::
      =/  msg=tape  "strange url: {(spud site.lin)}"
      ~&  >>  msg
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (internal-server-error:io authenticated.req msg ~)
    :: TODO: Unclear if the longest-corresponding-prefix approach
    ::       is useful now that pokes are concurrent
    ::
    :: Consider the request to be addressed to the base grub
    :: with the longest corresponding binding-relative prefix
    :: e.g. if /url/path is bound to /path/to/grub and if
    :: and /path/to/grub/alice and /path/to/grub/bob are base grubs
    :: then send request /url/path/alice to /path/to/grub/alice and
    :: /url/path/bob to /path/to/grub/bob
    ::
    =/  suffix=path       (slag (lent prefix) site.lin)
    =/  dest=(unit path)  (nearest-base-ancestor:hc (weld u.here suffix))
    ?~  dest
      =/  msg=tape  "no base bound to url: {(spud site.lin)}"
      ~&  >>  msg
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (internal-server-error:io authenticated.req msg ~)
    :: poke the dest grub with the pre-parsed request line
    :: and the raw request with a return address for the eyre-id
    ::
    =/  =give:g  [|+[src sap]:bowl /[eyre-id]]
    =/  =pail:g  [/handle-http-request !>([lin req])]
    =^  cards  state
      abet:(poke-base:hc u.dest [give `pail] |)
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
          abet:(make-stem:hc give [here stem vine]:axn)
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
        abet:(edit-weir:hc give [here weir]:axn)
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
      [%history ~]
    ?>  =(src our):bowl
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
=|  cards=(list card)  :: list of gall-level effects
=|  takes=(qeu take:g) :: queue of grub-level function calls
|_  =bowl:gall
+*  this  .
++  emit-card   |=(=card this(cards [card cards]))
++  emit-cards  |=(cadz=(list card) this(cards (welp (flop cadz) cards)))
++  enqu-take   |=(=take:g this(takes (~(put to takes) take)))
++  gibs        |=(=wire `give:g`[|+[our.bowl /gall/grubbery] wire])
++  gibs-take
  =|  =wire
  |=  [[here=path pid=@ta] in=(unit intake:base:g)]
  (enqu-take [here pid] (gibs wire) in)
:: handle all takes and return effects and state
::
++  abet
  |-
  ?:  =(~ takes)
    ~&  >  "done-abet!"
    [(flop cards) state]
  =^  =take:g  takes  ~(get to takes)
  $(this (process-take take))
:: TODO: Remote Scry functionality
:: NOTE: Because $coops are associated with ALL versions of a path
::       and we may want to restrict access to historical versions
::       WITHOUT DELETING THEM we may have to roll our own versioning
::       system and simply stick our own version at the head of the here path
::
++  emit-tend
  |=  [here=path =pail:g]
  ^+  this
  :: Presumably germs are selected for processing before tends
  :: regardless of order?
  ::
  %-  emit-cards
  :~  [%pass / %germ here] :: is there any reason not to do this every time?
      [%pass / %tend here here %noun p.pail q.q.pail]
  ==
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
::
++  boot
  ^+  this
  ~&  >  %booting
  =.  this  mass-kill
  =.  this  null-pokes
  =.  this  (oust-grub (gibs /boot) /boot)
  =.  this  (make-base (gibs /boot) /boot /boot ~)
  (poke-base /boot [(gibs /boot) ~ /sig !>(~)] |)
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
++  nearest-base-ancestor
  |=  here=path
  ^-  (unit path)
  ?~  get=(~(get of cone) here)
    ?:  =(/ here)  ~
    $(here (snip here))
  ?:  ?=(%base -.u.get)
    `here
  ?:  =(/ here)  ~
  $(here (snip here))
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
  ?>  ?=(%stem kind.tack)
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
  ?>  ?=(%stem kind.tack)
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
  ?>  ?=(%stem kind.tack)
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
  ?>  ?=(%stem kind.tack)
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
  ?>  ?=(%stem kind.tack)
  ?>  tidy.tack
  (grab-data:io grub)
::
++  bunt-stud
  |=  =stud:g
  ^-  vase
  =/  func=vase  (get-stud stud)
  (slam func (slot 6 func))
::
++  dart-to-dest
  |=  [here=path pid=@ta =dart:g]
  ^-  [jump:g (unit path)]
  ?+    -.dart  [%sysc [~ /]] :: %sysc, %scry, %bowl
      %grub
    :_  (path-from-road:grubbery here road.dart)
    ?-  -.load.dart
      %peek                       %peek
      ?(%poke %bump %kill)        %poke
      ?(%make %oust %cull %sand)  %make
    ==
    ::
      %perk
    =/  =pipe:g  (need (~(get of pool) here))
    =/  =proc:g  (~(got by proc.pipe) pid)
    :-  %perk
    ?-  -.from.give.poke.proc
      %|  [~ /]
      %&  [~ p.from.give.poke.proc]
    ==
  ==
::
++  allowed
  |=  [here=path =jump:g dest=(unit path)]
  ^-  filt:g
  ?~  dest  [~ %|]
  =/  =bend:g  (make-bend:grubbery here u.dest)
  =/  steps=@ud  p.bend
  =|  =filt:g
  |-
  =/  next=filt:g 
    %+  next-filt:grubbery
      filt
    (filter:grubbery u.dest jump here (~(get of sand) here))
  ?:  =(0 steps)
    ?:(=(/ q.bend) next filt) :: check for self, not for kids
  ?:  ?=([~ %|] next)  next
  %=  $
    filt   next
    here   (snip here)
    steps  (dec steps)
  ==
::
++  handle-base-emits
  |=  [here=path pid=@ta darts=(list dart:g)]
  ^+  this
  ?~  darts
    this
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
    (take-scry here pid [wire scry]:dart)
    ::
      %bowl
    (take-bowl here pid wire.dart)
    ::
      %perk
    (give-perk here pid pail.dart clam)
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
        %stem  (make-stem give path [stem vine]:make.load.dart)
      ==
      ::
        %oust
      (oust-grub [from wire.dart] path)
      ::
        %cull
      (cull-cone [from wire.dart] path)
      ::
        %sand
      (edit-weir [from wire.dart] path weir.load.dart)
      ::
        %kill
      (kill-base [from wire.dart] path pid.load.dart)
    ==
  ==
::
++  handle-base-emit
  |=  [here=path pid=@ta =dart:g]
  ^+  this
  =/  [=jump:g dest=(unit path)]  (dart-to-dest here pid dart)
  =/  =filt:g  (allowed here jump dest)
  ?+    filt  (handle-dart here pid dart)
      [~ %|]
    ~&  >>>  "vetoing illegal dart from {(spud here)}"
    (gibs-take [here pid] ~ %veto dart)
    ::
      [~ %&]
    ?.  ?=([%grub * * %make *] dart)
      %*($ handle-dart clam &, +6 [here pid dart])
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
::
++  new-last
  |=  [now=@da last=@da]
  ^-  @da
  =/  next=@da  ?:((lth last now) now +(last))
  |-
  ?.  (has:hon:g history next)
    next
  $(next +(next))
:: NOTE: tacks persist as long as they have either
::       a corresponding grub or non-empty sinx
::
++  emit-event
  |=  [when=@da =path]
  ^+  this
  (emit-card %give %fact ~[/history] %grub-event !>([when path]))
::
++  next-tack
  |=  here=path
  ^+  this
  ?~  tac=(~(get of trac) here)
    =/  =grub:g  (need (~(get of cone) here))
    =/  step=@da  (new-last [now now]:bowl)
    =.  history  (put:hon:g history step here)
    =.  this  (emit-event step here)
    this(trac (~(put of trac) here -.grub step ~ | ~))
  =^  del  history
    (del:hon:g history last.u.tac)
  ?:  &(=(~ sinx.u.tac) !(~(has of cone) here))
    this(trac (~(del of trac) here)) :: may occur in an oust
  =/  step=@da  (new-last now.bowl last.u.tac)
  =.  history  (put:hon:g history step here)
  =.  this  (emit-event step here)
  this(trac (~(put of trac) here u.tac(last step)))
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
  ?~  tak=(~(get of trac) here)
    %& :: non-existent grubs aren't a cycle
  =/  sour=(list path)  ~(tap in ~(key by sour.u.tak))
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
  |=  [here=path =vine:stem:g]
  ^+  this
  =/  sour=(list path)
    %+  murn  (turn ~(tap of vine) tail)
    (cury path-from-road:grubbery here)
  ?>  (no-cycles here sour)
  =/  =tack:g  ~|("no tack for {(spud here)}" (need (~(get of trac) here)))
  ?>  ?=(%stem kind.tack)
  |-
  ?~  sour
    this(trac (~(put of trac) here tack))
  =/  tac=(unit tack:g)  (~(get of trac) i.sour)
  =?  this  ?=(~ tac)  (next-tack i.sour)
  =/  sour-tack=tack:g  (need (~(get of trac) i.sour))
  =.  sinx.sour-tack  (~(put in sinx.sour-tack) here)
  =.  trac  (~(put of trac) i.sour sour-tack)
  =.  sour.tack  (~(put by sour.tack) i.sour `@da`0) :: 0 forces recompute
  $(sour t.sour)
::
++  dirty
  |=  here=path
  ^-  [(set path) _this]
  ~&  >>  "dirtying {(spud here)}"
  ~|  "failed to dirty {(spud here)}"
  =/  =tack:g  (need (~(get of trac) here))
  ?:  &(?=(%stem kind.tack) !tidy.tack)
    [~ this]
  =?  trac  ?=(%stem kind.tack)
    (~(put of trac) here tack(tidy |))
  ?:  =(0 ~(wyt in sinx.tack))
    ?:  ?=(%base kind.tack)
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
  ?:  ?=(%base kind.u.tack)
    ~&  >>  "{(spud here)} is a base and thus tidy"
    this
  ?:  tidy.u.tack
    ~&  >>  "{(spud here)} is already tidy"
    this
  =/  sour=(list (pair path @da))  ~(tap by sour.u.tack)
  |-
  ?~  sour
    (recompute-stem here u.grub)
  $(sour t.sour, this (tidy p.i.sour))
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
++  make-deps
  |=  [here=path =vine:stem:g]
  ^-  deps:stem:g
  %-  ~(gas of *deps:stem:g)
  %+  turn  ~(tap of vine)
  |=  [name=path =road:g]
  ^-  [path (each vase tang)]
  :-  name
  ?~  dep=(path-from-road:grubbery here road)
    :: TODO: make sure actually cannot see outside of peek sandbox
    |+[leaf+"beyond peek sandbox: {(render-road:grubbery road)}" ~]
  ?~  grub=(~(get of cone) u.dep)
    |+[leaf+"no grub: {(spud here)}" ~]
  (grab-data-soft:io u.grub)
::
++  make-sour
  |=  sour=(set path)
  ^-  (map path @da)
  %-  ~(gas by *(map path @da))
  %+  turn  ~(tap in sour)
  |=  =path
  :-  path
  last:(need (~(get of trac) path))
::
++  recompute-stem
  |=  [here=path =grub:g]
  ^+  this
  ~&  >>  "recompute stem {(spud here)}"
  ?>  ?=(%stem -.grub)
  =/  =tack:g  (need (~(get of trac) here))
  =/  new-sour=(map path @da)  (make-sour ~(key by sour.tack))
  ?:  =(new-sour sour.tack)
    ~&  >>  "{(spud here)} hasn't changed on recompute"
    this(trac (~(put of trac) here tack(tidy &)))
  =/  res=(each vase tang)
    %-  mule  |.
    =/  =stem:g  (get-stem-code stem.grub)
    =/  deps=(axal (each vase tang))
      (make-deps here vine.grub) :: sandboxed deps
    (stem deps)
  ?-    -.res
      %|
    ~&  >>>  "{(spud here)} crashed on recompute"
    =/  =tang  [leaf+"stem boom" leaf+(spud here) p.res]
    =?  this  !=(data.grub |+tang)  (next-tack here)
    :: TODO: need less error prone pattern for this kind of change
    ::       we want to avoid *refetching* data we already have
    ::
    =/  =tack:g  (need (~(get of trac) here)) :: tack changed on +next-tack
    %-  (slog tang)
    %=  this
      cone  (~(put of cone) here grub(data |+tang))
      trac  (~(put of trac) here tack(tidy %&))
    ==
    ::
      %&
    ~&  >  "{(spud here)} successfully recomputed"
    =?  this  !=(data.grub &+p.res)  (next-tack here)
    :: TODO: need less error prone pattern for this kind of change
    ::       we want to avoid *refetching* data we already have
    ::
    =/  =tack:g  (need (~(get of trac) here)) :: tack changed on +next-tack
    %=  this
      cone  (~(put of cone) here grub(data &+p.res))
      trac  (~(put of trac) here tack(tidy %&, sour new-sour))
    ==
  ==
::
++  del-sources
  |=  here=path
  ^+  this
  ~|  "deleting sources of {(spud here)} failed"
  =/  =tack:g  (need (~(get of trac) here))
  ?>  ?=(%stem kind.tack)
  =/  sour=(list path)  (turn ~(tap in sour.tack) head)
  |-
  ?~  sour
    this
  =/  sour-tack=tack:g    (need (~(get of trac) i.sour))
  =.  sinx.sour-tack  (~(del in sinx.sour-tack) here)
  ?:  &(=(~ sinx.sour-tack) !(~(has of cone) i.sour))
    $(sour t.sour, trac (~(del of trac) i.sour))
  $(sour t.sour, trac (~(put of trac) i.sour sour-tack))
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
  =.  pool  (~(del of pool) here)
  :: NOTE: we don't remove tack here in order to preserve sinx
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
  |=  [here=path weir=(unit weir:g)]
  ^+  this
  ?>  ?=(^ here) :: root should always have system access
  ?~  weir
    this(sand (~(del of sand) here))
  this(sand (~(put of sand) here u.weir))
::
++  edit-weir
  |=  [=give:g here=path weir=(unit weir:g)]
  ^+  this
  =/  res=(each _this tang)  (mule |.((put-sand here weir)))
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
  =/  step=@da  (new-last [now now]:bowl)
  =.  pool  (~(put of pool) here step ~ [~ ~] ~)
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
  |=  [here=path stem=path =vine:stem:g]
  ^+  this
  ~&  >  "making-stem {(spud here)} with {(spud stem)}"
  ~|  "making stem {(spud here)} failed"
  ?:  =(~ vine)
    ~&  >>>  "empty vine" :: TODO: should this be disallowed?
    !!
  ?:  (~(has of cone) here)
    ~&  >>>  "path {(spud here)} already populated"
    !!
  ?:  ?=([%lib *] here) :: stems not allowed in /lib
    ~&  >>>  "stems not allowed in /lib"
    !!
  =/  =stud:g  (get-stem-stud stem)
  =/  =grub:g  [%stem |+[leaf+"new stem"]~ vine stem]
  =.  cone     (~(put of cone) here grub)
  =.  this     (next-tack here)
  =.  this     (add-sources here vine)
  =/  =tack:g  (need (~(get of trac) here))
  =.  trac     (~(put of trac) here tack(tidy |))
  ~&  >>  "computing-new-stem {(spud here)}"
  =.  this     (recompute-stem here (need (~(get of cone) here)))
  (dirty-and-tidy here)
::
++  make-stem
  |=  [=give:g here=path stem=path =vine:stem:g]
  ^+  this
  =/  res=(each _this tang)  (mule |.((new-stem here stem vine)))
  =/  err=(unit tang)  ?-(-.res %& ~, %| `p.res)
  =?  this  ?=(%& -.res)  p.res
  ?:  ?=(%| -.from.give)
    ?:(?=(%& -.res) this (mean p.res))
  (gibs-take (get-here-pid from.give) ~ %made wire.give err)
::
++  take-peek
  |=  [here=path pid=@ta =wire =path]
  ^+  this
  :: this says: does giving the peek results pass through a filter when
  :: going from the object back to the requester
  =/  =filt:g  (allowed path %give ~ here)
  :: TODO: Clam  cone contents if filt is [~ %&]
  %+  gibs-take  [here pid]
  [~ %peek wire path (~(dip of cone) path) (~(dip of sand) path)]
::
++  take-scry
  |=  [here=path pid=@ta =wire scry=(unit scry:g)]
  ^+  this
  ?~  scry
    (gibs-take [here pid] ~ %scry wire /gall/grubbery/state !>(state))
  =;  =vase
    (gibs-take [here pid] ~ %scry wire path.u.scry vase)
  =*  pat  path.u.scry
  ?>  ?=(^ pat)
  ?>  ?=(^ t.pat)
  !>(.^(mold.u.scry i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat))
::
++  make-bowl
  |=  [here=path pid=@ta]
  ^-  bowl:base:g
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
  [now our eny wex sup here]:[bowl .]
::
++  take-bowl
  |=  [here=path pid=@ta =wire]
  ^+  this
  (gibs-take [here pid] ~ %bowl wire (make-bowl here pid))
::
++  kill
  |=  [here=path pid=@ta]
  ^+  this
  ~|  "killing process {(trip pid)} at {(spud here)} failed"
  =/  =pipe:g  (need (~(get of pool) here))
  ?.  (~(has by proc.pipe) pid)
    ~&  >>  "no process {(trip pid)} to kill at {(spud here)}"
    this
  (give-final-poke-ack here pid ~ %killed [leaf+(spud here) ~])
::
++  kill-all
  |=  here=path
  ^+  this
  ?~  pipe=(~(get of pool) here)
    this 
  ?~  lit=~(tap in ~(key by proc.u.pipe))
    this
  $(this (kill here i.lit))
:: in preparation for mass-kill, clear all local gives
::
++  wipe-gives
  ^+  this
  %=    this
      pool
    %-  ~(gas of *pool:g)
    %+  turn  ~(tap of pool)
    |=  [here=path =pipe:g]
    ^-  [path pipe:g]
    :-  here
    %=    pipe
        proc
      %-  ~(gas by *(map @ta proc:g))
      %+  turn  ~(tap by proc.pipe)
      |=  [pid=@ta =proc:g]
      ^-  [@ta proc:g]
      :-  pid
      ?:  ?=(%| -.from.give.poke.proc) :: from outside grubbery
        proc
      proc(give.poke (gibs /))
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
  $(paths t.paths, this (poke-base i.paths [(gibs /null-poke) ~] |))
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
  =/  =from:base:g  (relativize-from:grubbery here from.give)
  ?.  clam
    (gibs-take [here pid] ~ %bump from pail)
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
  (gibs-take [here pid] ~ %bump from pail)
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
  =/  =pipe:g  (need (~(get of pool) here))
  =/  last=@da  last.pipe
  =/  next=@da  ?:((lth last now.bowl) now.bowl +(last))
  |-
  ?:  (~(has by proc.pipe) (scot %da next))
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
  =/  =pipe:g  (need (~(get of pool) here))
  =.  proc.pipe  (~(put by proc.pipe) pid [proc poke ~ ~])
  =.  pool  (~(put of pool) here pipe)
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
    ~&  >>>  "build-error {(spud here)}"
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
    ~&  >>>  "poke-stud-fail at {(spud here)} for stud {(spud p.u.pail.poke)}"
    =/  =sign:base:g  [%pack %| leaf+"poke-stud-fail" p.stud-res]
    ?:  ?=(%| -.from.give.poke)
      (give-external-sign give.poke sign)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke)
    (gibs-take here-pid ~ %base wire.give.poke sign)
  =/  clam-res  (mule |.((slam p.stud-res q.u.pail.poke)))
  ?:  ?=(%| -.clam-res)
    ~&  >>>  "poke-clam-fail {(spud here)}"
    =/  =sign:base:g  [%pack %| leaf+"poke-clam-fail" p.clam-res]
    ?:  ?=(%| -.from.give.poke)
      ~&  >>  "giving external pack sign {(spud here)}"
      (give-external-sign give.poke sign)
    ~&  >>  "giving internal pack sign {(spud here)}"
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke)
    (gibs-take here-pid ~ %base wire.give.poke sign)
  ~&  >>  "starting process {(spud here)}"
  (start-process [here pid] p.build poke(q.u.pail p.clam-res))
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
  =/  =pipe:g  (need (~(get of pool) here))
  ?.  (~(has by proc.pipe) pid)
    ~&  >>  "discarding message for non-existent process {(trip pid)}"
    (give-poke-sign take ~ leaf+"non-existent process" ~)
  =/  =proc:g  (~(got by proc.pipe) pid)
  =.  next.proc  (~(put to next.proc) take)
  =.  proc.pipe  (~(put by proc.pipe) pid proc)
  =.  pool       (~(put of pool) here pipe)
  (process-do-next here pid)
::
++  process-do-next
  |=  [here=path pid=@ta]
  ^+  this
  =/  =grub:g  (need (~(get of cone) here))
  =/  =pipe:g  (need (~(get of pool) here))
  =/  =proc:g  (~(got by proc.pipe) pid)
  ?.  |(=(~ boar.pipe) =([~ pid] boar.pipe))
    this
  ?:  =(~ next.proc)
    this
  ?>  ?=(%base -.grub)
  =/  m  (charm:base:g ,~)
  =/  [darts=(list dart:g) done=(list took:eval:grubbery) data=vase temp=(axal vase) =proc:g =result:eval:grubbery]
    (take:eval:grubbery here data.grub temp.pipe pid proc)
  ::
  ~&  >>  -.result
  ::
  =.  cone  (~(put of cone) here grub(data data))
  =.  temp.pipe  temp
  =.  proc.pipe  (~(put by proc.pipe) pid proc)
  =.  pool  (~(put of pool) here pipe)
  ::
  =/  tick=?  !=(data data.grub)
  =?  this  tick  (next-tack here)
  =?  this  tick  (dirty-and-tidy here)
  ::
  =.  this  (give-poke-signs done)
  =.  this  (handle-base-emits here pid darts)
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
  |=  [here=path pid=@ta =pail:g clam=?]
  ^+  this
  :: TODO: implement clam
  ~&  %giving-perk
  ~&  [here+here pid+pid]
  =/  =grub:g  (need (~(get of cone) here))
  ?>  ?=(%base -.grub)
  =/  =pipe:g  (need (~(get of pool) here))
  =/  =proc:g  (~(got by proc.pipe) pid)
  ?:  ?=(%& -.from.give.poke.proc)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke.proc)
    =/  =give:g  [(make-from here pid) /] :: not expecting a sign
    (enqu-take here-pid give ~ %perk wire.give.poke.proc pail)
  ?:  ?=([%gall *] sap.p.from.give.poke.proc)
    (give-external-perk give.poke.proc pail)
  ?>  ?=([%eyre *] sap.p.from.give.poke.proc)
  (give-http-perk wire.give.poke.proc pail)
::
++  claim
  |=  [here=path pid=@ta]
  ^+  this
  =/  =pipe:g  (need (~(get of pool) here))
  ?>  |(=(~ boar.pipe) =([~ pid] boar.pipe))
  =.  boar.pipe  [~ pid]
  this(pool (~(put of pool) here pipe))
::
++  relinquish
  |=  here=path
  ^+  this
  =/  =pipe:g  (need (~(get of pool) here))
  =.  boar.pipe  ~
  =.  pool  (~(put of pool) here pipe)
  =/  pids=(list @ta)  ~(tap in ~(key by proc.pipe))
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
  =/  =pipe:g  (need (~(get of pool) here))
  =/  =proc:g  (~(got by proc.pipe) pid)
  =.  proc.pipe  (~(del by proc.pipe) pid)
  =.  this  (relinquish here)
  =.  pool  (~(put of pool) here pipe)
  =.  this  (clean here pid)
  =/  =sign:base:g  [%poke res]
  ?:  ?=(%& -.from.give.poke.proc)
    =/  here-pid=[path @ta]  (get-here-pid from.give.poke.proc)
    (gibs-take here-pid ~ %base wire.give.poke.proc sign)
  ?:  ?=([%clay *] sap.p.from.give.poke.proc) :: on-init / on-load
    ?~(res this ((slog u.res) this))
  ?:  ?=([%gall *] sap.p.from.give.poke.proc)
    ?:  ?=([%grubbery ~] t.sap.p.from.give.poke.proc)
      ?~  res  this
      ~|  "crashed with wire {(spud wire.give.poke.proc)}"
      ?+  wire.give.poke.proc  !!
        [%boot ~]       (mean u.res)
        [%null-poke ~]  ((slog leaf+"null-poke-fail" u.res) this)
      ==
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
