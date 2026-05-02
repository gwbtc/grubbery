/-  spider
/+  default-agent, dbug, tarball, nexus,
    server, multipart, http-utils, html-utils, json-utils,
    marks, build, fiberio, loader, cram, pretty-file, root
/=  t-  /tests/nexus
/=  t-  /tests/tarball
/=  t-  /tests/build
/=  t-  /tests/loader
/=  m-  /mar/kids
/=  m-  /mar/tree
/=  m-  /mar/sand
/=  m-  /mar/born
/=  m-  /mar/subs
/=  m-  /mar/gain
::
|%
+$  versioned-state
  $%  state-0
  ==
+$  card  card:agent:gall
+$  state-0
  $:  %0
      =ball:tarball
      =pool:nexus
      =sand:nexus
      =born:nexus
      =subs:nexus
      =silo:nexus
      =gain:nexus
      =code:nexus
      jael-source=(unit rail:tarball)
  ==
++  kel  21.000.000 :: start big; burn many at once
++  sut
  :: Need to determine how much actually needs to be in here...
  ::
  %+  slop
    !>  :*  tarball=tarball
            nexus=nexus
            marks=marks
            build=build
            loader=loader
            server=server
            multipart=multipart
            http-utils=http-utils
            html-utils=html-utils
            json-utils=json-utils
            pretty-file=pretty-file
            io=fiberio
            cram=cram
        ==
  !>(..zuse)
--
::
=|  state-0
=*  state  -
::
=<
%-  agent:dbug
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
    hc    ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  ::  Ensure root lump with hardcoded neck (root nexus from lib, not code)
  =/  lmp=lump:tarball  (fall fil.ball *lump:tarball)
  =.  ball  ball(fil `lmp(neck `[/ %root]))
  ::  Write /sys/bowl/ virtual files
  =.  ball
    (~(put ba:tarball ball) [/sys/bowl %our] [~ [/ %ship] !>(our.bowl)])
  =.  ball
    (~(put ba:tarball ball) [/sys/bowl %now] [~ [/ %time] !>(now.bowl)])
  =.  ball
    (~(put ba:tarball ball) [/sys/bowl %eny] [~ [/ %entropy] !>(eny.bowl)])
  ::  Compile code from Clay
  ~&  >>  "on-init: sync-gub"
  =^  gub-cards  state  abet:sync-gub:hc
  ::  Reload root nexus (hardcoded — after code compile so child nexuses build)
  ~&  >>  "on-init: reload-nexus-at"
  =^  root-cards  state  abet:(reload-nexus-at:hc / root)
  ::  Purge stale code namespaces, then register new ones
  =.  code  purge-stale-code:hc
  =^  code-cards  state  abet:(build-new-code-namespaces:hc / ball)
  =^  spawn-cards  state  abet:(spawn-all-files:hc / ball)
  ~&  >>  "on-init: sync-dill"
  =^  dill-cards  state  abet:sync-dill:hc
  ~&  >>  "on-init: sync-clay"
  =^  clay-cards  state  abet:sync-clay:hc
  ~&  >>  "on-init: sync-jael"
  =^  jael-cards  state  abet:sync-jael:hc
  ~&  >>  "on-init: done"
  :_  this
  ;:  weld
    root-cards
    code-cards
    spawn-cards
    gub-cards
    dill-cards
    clay-cards
    jael-cards
    cards
  ==
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old-state)
  ?-    -.old
      %0
    ::  Restore all state
    =.  state  old
    ::  Write /sys/bowl/ virtual files — backfill on load
    =.  ball
      (~(put ba:tarball ball) [/sys/bowl %our] [~ [/ %ship] !>(our.bowl)])
    =.  ball
      (~(put ba:tarball ball) [/sys/bowl %eny] [~ [/ %entropy] !>(eny.bowl)])
    ::  Compile code from Clay (cascades nexus on-loads)
    ~&  >>  "on-load: sync-gub"
    =^  gub-cards  state  abet:sync-gub:hc
    ::  Reload root nexus (hardcoded — runs on every app reload, after code compile)
    ~&  >>  "on-load: reload-nexus-at"
    =^  root-cards  state  abet:(reload-nexus-at:hc / root)
    ::  Purge stale code namespaces, then register new ones
    =.  code  purge-stale-code:hc
    =^  code-cards  state  abet:(build-new-code-namespaces:hc / ball)
    =^  spawn-cards  state  abet:(spawn-all-files:hc / ball)
    ~&  >>  "on-load: sync-dill"
    =^  dill-cards  state  abet:sync-dill:hc
    ~&  >>  "on-load: sync-clay"
    =^  clay-cards  state  abet:sync-clay:hc
    ~&  >>  "on-load: sync-jael"
    =^  jael-cards  state  abet:sync-jael:hc
    ~&  >>  "on-load: done"
    :_  this
    ;:  weld
      root-cards
      code-cards
      spawn-cards
      gub-cards
      dill-cards
      clay-cards
      jael-cards
      cards
    ==
  ==
::
++  on-poke
  |=  [mak=mark vas=vase]
  ^-  (quip card _this)
  ?+    mak  (on-poke:def mak vas)
      %grubbery-action
    =+  !<(=action:nexus vas)
    ?-    +<.action
        %poke
      ::  All pokes route through /peers.peers/main.sig gateway
      ?>  ?=(%& -.dest.action)
      =/  =give:nexus  [|+[src sap]:bowl wire.action]
      =^  cards  state
        abet:(poke:hc give [/'peers.peers' %'main.sig'] [[/ %poke-in] !>([p.dest.action bask.action])])
      [cards this]
      ::
        %make
      ?>  =(src our):bowl
      =^  cards  state
        abet:(make:hc [dest make]:action)
      [cards this]
      ::
        %cull
      ?>  =(src our):bowl
      =^  cards  state
        abet:(cull:hc dest.action)
      [cards this]
      ::
        %sand
      ?>  =(src our):bowl
      ::  Sand destination must be a directory
      ?>  ?=(%| -.dest.action)
      =^  cards  state
        abet:(set-weir:hc [p.dest.action weir.action])
      [cards this]
      ::
        %load
      ?>  =(src our):bowl
      ::  Load destination must be a directory
      ?>  ?=(%| -.dest.action)
      =^  cards  state
        abet:(reload-nexus:hc p.dest.action)
      [cards this]
    ==
    ::  HTTP request from eyre: forward to /server.server/main.server-state
    ::
    ::  NOTE: HTTP requests go directly to /server.server/main.server-state, bypassing /peers.peers.
    ::  Eyre gestures at treating them as "from a ship" via src.bowl —
    ::  this feels misleading.
    ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vas)
    =/  =give:nexus  [|+[src sap]:bowl /[eyre-id]]
    =^  cards  state
      abet:(poke:hc give [/'server.server' %'main.server-state'] [[/ %handle-http-request] !>([eyre-id src.bowl req])])
    [cards this]
      ::
      %refresh-sessions
    ::  Scry for dill sessions, sync subscriptions and grubs
    ?>  =(src our):bowl
    =^  cards  state
      abet:sync-dill:hc
    [cards this]
      ::
      %mount-desk
    ::  Mount a Clay desk into /sys/clay/[desk]
    ?>  =(src our):bowl
    =/  dek=desk  !<(desk vas)
    =?  ball  =(~ (~(get of ball) /sys/clay/[dek]))
      (~(put of ball) /sys/clay/[dek] [~ ~ ~])
    =^  cards  state
      abet:(sync-clay-desk:hc dek)
    [cards this]
      ::
      %unmount-desk
    ::  Unmount a Clay desk from /sys/clay/[desk]
    ?>  =(src our):bowl
    =/  dek=desk  !<(desk vas)
    ?>  !=(dek %grubbery)
    ?>  !=(dek %base)
    =^  cards  state
      abet:(unmount-clay-desk:hc dek)
    [cards this]
      ::
      %set-jael-source
    ::  Set the rail whose file backs jael PKI subscriptions.
    ::  Jael subscribes on / and /(scot %p ship); grubbery gives
    ::  %azimuth-udiffs facts when the file at this rail changes.
    ?>  =(src our):bowl
    =/  rl=rail:tarball  !<(rail:tarball vas)
    ~&  >  [%grubbery %set-jael-source rl]
    =.  jael-source  `rl
    ::  Tell jael to listen to us
    :-  [%pass /jael-listen %arvo %j %listen ~ [%| %grubbery]]~
    this
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%poke @ *]
    ?>  =(src.bowl (slav %p i.t.path))
    [~ this]
      [%http-response *]
    [~ this]
      ::  Jael subscribes on / for all udiffs
      ~
    ?~  jael-source  (on-watch:def path)
    =/  content=(unit content:tarball)
      (~(get ba:tarball ball) u.jael-source)
    ?~  content  `this
    :_  this
    [%give %fact ~ %azimuth-udiffs q.sage.u.content]~
      ::  Jael subscribes on /(scot %p ship) for per-ship udiffs
      [@ ~]
    ?~  jael-source  (on-watch:def path)
    =/  who=(unit @p)  (slaw %p i.path)
    ?~  who  (on-watch:def path)
    =/  content=(unit content:tarball)
      (~(get ba:tarball ball) u.jael-source)
    ?~  content  `this
    =+  !<(uds=udiffs:point:jael q.sage.u.content)
    =/  filtered=udiffs:point:jael
      %+  skim  uds
      |=([=ship *] =(ship u.who))
    :_  this
    [%give %fact ~ %azimuth-udiffs !>(filtered)]~
      [%proc @ *]
    =^  cards  state
      abet:(take-watch:hc path)
    [cards this]
  ==
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-leave:def path)
      [%poke @ *]
    [~ this]
      [%http-response @ ~]
    =/  eyre-id=@ta  i.t.path
    =/  =give:nexus  [|+[src sap]:bowl /cancel/[eyre-id]]
    =^  cards  state
      abet:(poke:hc give [/'server.server' %'main.server-state'] [[/ %handle-http-cancel] !>(eyre-id)])
    [cards this]
      [%proc ^]
    =^  cards  state
      abet:(take-leave:hc path)
    [cards this]
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %peek %file *]
    ::  Single file's sage, converted to cage for scry
    =/  here=^path  t.t.t.path
    ?~  here  ~
    =/  dir=^path  (snip `^path`here)
    =/  name=@ta  (rear here)
    =/  content=(unit content:tarball)
      (~(get ba:tarball ball) dir name)
    ?~  content
      [~ ~]
    ``[name.p.sage.u.content q.sage.u.content]
    ::
      [%x %peek %kids *]
    ::  File names at path
    =/  here=^path  t.t.t.path
    ``kids+!>((~(lis ba:tarball ball) here))
    ::
      [%x %peek %subs *]
    ::  Subdirectory names at path
    =/  here=^path  t.t.t.path
    ``kids+!>((~(lss ba:tarball ball) here))
    ::
      [%x %peek %tree *]
    ::  Tree structure with marks, no content
    =/  here=^path  t.t.t.path
    =/  sub=ball:tarball  (~(dip ba:tarball ball) here)
    ``tree+!>((ball-to-tree:tarball sub))
    ::
      [%x %peek %sand *]
    ::  Sand (filter) subtree
    =/  here=^path  t.t.t.path
    ``sand+!>((~(dip of sand) here))
    ::
      [%x %peek %born *]
    ::  Born (version tracking) subtree
    =/  here=^path  t.t.t.path
    ``born+!>((~(dip of born) here))
    ::
      [%x %peek %gain *]
    ::  Gain (history retention flags) subtree
    =/  here=^path  t.t.t.path
    ``gain+!>((~(dip of gain) here))
    ::
      [%x %peek %silo %lobe @ ~]
    ::  Look up page in silo by lobe hash
    =/  =lobe:clay  (slav %uv i.t.t.t.t.path)
    =/  got=(unit bask:tarball)  (~(get si:nexus silo) lobe)
    ?~  got  [~ ~]
    ``name.p.u.got^!>(q.u.got)
    ::
      [%x %peek %subs ~]
    ::  Internal subscriptions
    ``subs+!>(subs)
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  =^  cards  state
    abet:(take-agent:hc wire sign)
  [cards this]
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%dill %logs ~] wire)
    ?>  ?=([%dill %logs *] sign)
    =^  cards  state
      abet:(save-file:hc [/sys/dill %'logs.dill-told'] [~ [/ %dill-told] !>(told.sign)])
    [cards this]
  ?:  ?=([%dill %session @ ~] wire)
    ?>  ?=([%dill %blit *] sign)
    =/  ses=@tas  i.t.t.wire
    =^  cards  state
      abet:(save-file:hc [/sys/dill/sessions ses] [~ [/ %dill-blit] !>(p.sign)])
    [cards this]
  ?:  ?=([%clay-desk @ ~] wire)
    ~&  >>  "on-arvo: clay writ on wire {<wire>}"
    ?>  ?=([%clay %writ *] sign)
    =/  dek=desk  (slav %tas i.t.wire)
    =^  cards  state
      abet:(on-clay-writ:hc dek +>.sign)
    [cards this]
  ?:  ?=([%jael %public ~] wire)
    ?>  ?=([%jael %public-keys *] sign)
    =^  cards  state
      abet:(on-jael-public:hc public-keys-result.sign)
    [cards this]
  ?:  ?=([%jael %private ~] wire)
    ?>  ?=([%jael %private-keys *] sign)
    =^  cards  state
      abet:(save-file:hc [/sys/jael %'private-keys.jael-private-keys'] [~ [/ %jael-private-keys] !>([life.sign vein.sign])])
    [cards this]
  =^  cards  state
    abet:(take-arvo:hc wire sign)
  [cards this]
::
++  on-fail   on-fail:def
--
::  helper core for routing events to processes
::
=|  cards=(list card)
=|  takes=(qeu take:nexus)
|_  =bowl:gall
+*  this  .
::
++  abet
  |-
  ?:  =(~ takes)
    [(flop cards) state]
  =^  [here=rail:tarball =take:fiber:nexus]  takes  ~(get to takes)
  =.  this  (process-take here take)
  $(this this)
::  Purge code map entries whose paths no longer exist as code nexuses.
::
++  purge-stale-code
  ^-  (map path lode:nexus)
  =/  keys=(list path)  ~(tap in ~(key by code))
  |-
  ?~  keys  code
  =/  node=(unit lump:tarball)  (~(get of ball) i.keys)
  ?:  ?&(?=(^ node) ?=(^ neck.u.node) =([/ %code] u.neck.u.node))
    $(keys t.keys)
  ~&  >  "purge-stale-code: {(spud i.keys)}"
  $(keys t.keys, code (~(del by code) i.keys))
::  Put subtree into sand at path
::
++  put-sub-sand
  |=  [snd=sand:nexus pax=path sub=sand:nexus]
  ^-  sand:nexus
  ?~  pax  sub
  =/  kid  (~(gut by dir.snd) i.pax *sand:nexus)
  snd(dir (~(put by dir.snd) i.pax $(snd kid, pax t.pax)))
::
++  put-sub-gain
  |=  [gn=gain:nexus pax=path sub=gain:nexus]
  ^-  gain:nexus
  ?~  pax  sub
  =/  kid  (~(gut by dir.gn) i.pax *gain:nexus)
  gn(dir (~(put by dir.gn) i.pax $(gn kid, pax t.pax)))
::  Look up gain flag for a file (rail)
::
++  lookup-gain
  |=  here=rail:tarball
  ^-  ?
  =/  node=(unit (map @ta ?))  (~(get of gain) path.here)
  ?~  node  %.n
  (fall (~(get by u.node) name.here) %.n)
::  Set gain flag for a file
::
++  set-gain
  |=  [here=rail:tarball flag=?]
  ^-  gain:nexus
  =/  node=(map @ta ?)  (fall (~(get of gain) path.here) ~)
  (~(put of gain) path.here (~(put by node) name.here flag))
::  Set gain for a lane: single file or recursive on directory
::
++  set-gain-lane
  |=  [=lane:tarball flag=?]
  ^+  this
  ?-    -.lane
      %&
    ::  File: set gain for single rail
    =.  gain  (set-gain p.lane flag)
    this
      %|
    ::  Directory: set gain for all files in subtree
    =/  sub-ball=ball:tarball  (~(dip ba:tarball ball) p.lane)
    =/  lumps=(list [pax=path =lump:tarball])  ~(tap of sub-ball)
    |-
    ?~  lumps  this
    =/  files=(list @ta)  ~(tap in ~(key by contents.lump.i.lumps))
    =.  this
      |-
      ?~  files  this
      =.  gain  (set-gain [(weld p.lane pax.i.lumps) i.files] flag)
      $(files t.files)
    $(lumps t.lumps)
  ==
::  Drop hist entries matching a lose spec, decrementing silo refs
::
++  drop-hist
  |=  [here=rail:tarball =lose:nexus]
  ^+  this
  =/  sk=sack:nexus  (need (get-born here))
  =/  entries=(list [key=cass:clay val=lobe:clay])
    (tap:on-hist:nexus hist.sk)
  =/  kept=(list [key=cass:clay val=lobe:clay])  ~
  |-
  ?~  entries
    =/  new-hist=((mop cass:clay lobe:clay) cor:nexus)  *((mop cass:clay lobe:clay) cor:nexus)
    =.  new-hist
      |-
      ?~  kept  new-hist
      $(kept t.kept, new-hist (put:on-hist:nexus new-hist key.i.kept val.i.kept))
    =.  born  (~(put bo:nexus now.bowl [born ball]) here sk(hist new-hist))
    this
  =/  drop=?
    ?-    -.lose
        %pick
      (~(has in cass.lose) key.i.entries)
        %date
      ?&  (fall (bind from.lose |=(d=@da (gte da.key.i.entries d))) %.y)
          (fall (bind to.lose |=(d=@da (lte da.key.i.entries d))) %.y)
      ==
        %numb
      ?&  (fall (bind from.lose |=(n=@ud (gte ud.key.i.entries n))) %.y)
          (fall (bind to.lose |=(n=@ud (lte ud.key.i.entries n))) %.y)
      ==
    ==
  ?:  drop
    =.  silo  (~(drop si:nexus silo) val.i.entries)
    $(entries t.entries)
  $(entries t.entries, kept [i.entries kept])
::  Find all [rail cass] pairs in a subtree whose hist contains a lobe
::
++  seek-lobe
  |=  [=lane:tarball target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  ?-    -.lane
      %&
    ::  Single file: check its hist
    =/  node=(unit [=tote:nexus bags=(map @ta sack:nexus)])
      (~(get of born) path.p.lane)
    ?~  node  ~
    =/  sk=(unit sack:nexus)  (~(get by bags.u.node) name.p.lane)
    ?~  sk  ~
    (match-hist p.lane hist.u.sk target)
      %|
    ::  Directory: walk all files in born subtree
    =/  sub-born=born:nexus  (~(dip of born) p.lane)
    =/  nodes=(list [pax=path =tote:nexus bags=(map @ta sack:nexus)])
      ~(tap of sub-born)
    (seek-nodes p.lane nodes target)
  ==
::
++  seek-nodes
  |=  [base=path nodes=(list [pax=path =tote:nexus bags=(map @ta sack:nexus)]) target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  ?~  nodes  ~
  =/  files=(list [@ta sack:nexus])  ~(tap by bags.i.nodes)
  =/  hits=(list [=rail:tarball =cass:clay])
    (seek-files base pax.i.nodes files target)
  (weld hits $(nodes t.nodes))
::
++  seek-files
  |=  [base=path pax=path files=(list [@ta sack:nexus]) target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  ?~  files  ~
  =/  hits=(list [=rail:tarball =cass:clay])
    (match-hist [(weld base pax) -.i.files] hist.+.i.files target)
  (weld hits $(files t.files))
::
++  match-hist
  |=  [here=rail:tarball hist=((mop cass:clay lobe:clay) cor:nexus) target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  %+  murn  (tap:on-hist:nexus hist)
  |=  [key=cass:clay val=lobe:clay]
  ?.  =(val target)  ~
  `[here key]
::
++  emit-card
  |=  =card
  this(cards [card cards])
::
++  emit-cards
  |=  cadz=(list card)
  this(cards (welp (flop cadz) cards))
::
++  enqu-take
  |=  [here=rail:tarball =give:nexus in=(unit intake:fiber:nexus)]
  this(takes (~(put to takes) [here give in]))
::  Generate a system give (for internal system operations)
::
++  sys-give
  |=  =wire
  ^-  give:nexus
  [|+[our.bowl /gall/grubbery] wire]
::  Validate a vase using a vale gate $-(* vase)
::
::  Assumes old vase was part of a chain of +validate-vase uses where the
::  original was clammed
::  Nest optimization: if old vase exists and types nest, reuse old type.
::  Otherwise run vale to get canonical type.
::
::  force=%.y skips nest optimization (for reload when types may have changed)
::
++  validate-vase
  |=  [vale=$-(* vase) old=(unit vase) new=vase force=?]
  ^-  (each vase tang)
  ?:  ?&  !force
          ?=(^ old)
          (~(nest ut p.u.old) | p.new)
      ==
    &+[p.u.old q.new]
  =/  vale-result=(each vase tang)
    (mule |.((vale q.new)))
  ?:  ?=(%| -.vale-result)
    =/  err=tang
      :~  leaf+"vale failed"
          leaf+"got:"
          (skol p.new)
      ==
    |+(weld err p.vale-result)
  &+p.vale-result
::  Find the code nexus governing a given path.
::  Walks up ancestors, checking if any immediate child is in the code map.
::  Walk up the tree looking for a compiled artifact in code nexuses.
::  At each ancestor, checks for a child named %code in the code map.
::  A %tang counts as found; only true absence walks to the next.
::
::  +seek-built: find a compiled artifact by walking up the tree
::  +find-built: namespace + source rail (no artifact)
::  +get-built: just the artifact
::  Code namespace governance
::
::  Every path in the tarball is governed by exactly one /code namespace:
::  the nearest /code sibling found by walking up from the path.
::  Governance is hermetic — if the governing namespace doesn't have an
::  artifact, we return ~ rather than falling back to a parent. Lower
::  namespaces must include marks/libs they need. A ford-style refcounted
::  cache (TODO) will make this redundancy free via content-addressed dedup.
::
::  +find-code-ns: find the /code namespace governing a path
::
++  find-code-ns
  |=  pax=path
  ^-  (unit fold:tarball)
  |-
  =/  cod=path
    ?~  pax  /code
    (snoc (snip `(list @ta)`pax) %code)
  ?^  (~(get by code) cod)  `cod
  ?~  pax  ~
  $(pax (snip `(list @ta)`pax))
::  +seek-built: find a compiled artifact in the governing namespace
::
++  seek-built
  |=  [pax=path =path name=@ta]
  ^-  (unit [namespace=fold:tarball source=rail:tarball =built:nexus])
  =/  ns=(unit fold:tarball)  (find-code-ns pax)
  ?~  ns  ~
  =/  lod=lode:nexus  (~(got by code) u.ns)
  =/  node=(unit (map @ta built:nexus))
    (~(get of bins.lod) path)
  =/  hit=(unit built:nexus)
    ?~  node  ~
    (~(get by u.node) name)
  ?~  hit  ~
  `[u.ns [path name] u.hit]
::
++  find-built
  |=  [pax=path =path name=@ta]
  ^-  (unit [namespace=fold:tarball source=rail:tarball])
  =/  res  (seek-built pax path name)
  ?~  res  ~
  `[namespace.u.res source.u.res]
::
++  get-built
  |=  [pax=path =path name=@ta]
  ^-  (unit built:nexus)
  =/  res  (seek-built pax path name)
  ?~  res  ~
  `built.u.res
::
::  Get a compiled marc from bins
::
++  get-marc
  |=  [pax=path =blot:tarball]
  ^-  marc:tarball
  =/  res=(unit built:nexus)  (get-built pax (weld /mar path.blot) name.blot)
  ?~  res
    =/  nam=@tas  (rail-to-arm:tarball blot)
    ~&  >>>  "get-marc: %{(trip nam)} not found, searched from {(spud pax)}"
    ~|([%marc-not-found nam pax] !!)
  ?.  ?=(%vase -.u.res)
    =/  nam=@tas  (rail-to-arm:tarball blot)
    ~&  >>>  "get-marc: %{(trip nam)} failed (tang), searched from {(spud pax)}"
    ~|([%marc-failed nam pax] !!)
  !<(marc:tarball vase.u.res)
::
++  get-vale
  |=  [pax=path =blot:tarball]
  ^-  $-(* vase)
  vale:(get-marc pax blot)
::
++  get-tube
  |=  [pax=path =bars:tarball]
  ^-  tube:clay
  =/  via-grow=(each tube:clay tang)
    (mule |.((grow:(get-marc pax a.bars) b.bars)))
  ?:  ?=(%& -.via-grow)  p.via-grow
  (grab:(get-marc pax b.bars) a.bars)
::  Validate file content, looks up cached dais
::
++  validate-new-sage
  |=  [pax=path =blot:tarball old=(unit vase) new=vase force=?]
  ^-  (each vase tang)
  ::  Bootstrap marks — hardcoded like Clay's page-to-cage
  ?:  =([/ %boom] blot)
    (mule |.(!>(;;([tang bask:tarball] q.new))))
  ?:  =([/ %hoon] blot)
    (mule |.(!>(;;(@t q.new))))
  ?:  =([/ %tang] blot)
    (mule |.(!>(;;(tang q.new))))
  ?:  =([/ %mime] blot)
    (mule |.(!>(;;(mime q.new))))
  ?:  =([/ %kelvin] blot)
    (mule |.(!>(;;(waft:clay q.new))))
  =/  res=(unit built:nexus)  (get-built pax (weld /mar path.blot) name.blot)
  ?~  res
    =/  nam=@tas  (rail-to-arm:tarball blot)
    |+~[leaf+"validate-new-sage: no marc for %{(trip nam)} at {(spud pax)}"]
  ?.  ?=(%vase -.u.res)
    =/  nam=@tas  (rail-to-arm:tarball blot)
    |+~[leaf+"validate-new-sage: marc for %{(trip nam)} failed at {(spud pax)}"]
  =/  nam=@tas  (rail-to-arm:tarball blot)
  =/  vale-res=(each $-(* vase) tang)
    ~|  [%validate-new-sage %marc-extract-failed nam pax]
    %-  mule  |.
    vale:!<(marc:tarball vase.u.res)
  ?:  ?=(%| -.vale-res)
    |+[leaf+"validate-new-sage: marc for %{(trip nam)} broke at {(spud pax)}" p.vale-res]
  (validate-vase p.vale-res old new force)
::  Clam a sage at sandbox boundary
::  Used when data crosses a weir filter from untrusted source.
::  Always forces full validation (no nest optimization).
::
++  clam-sage
  |=  [pax=path =sage:tarball]
  ^-  (each sage:tarball tang)
  =/  result=(each vase tang)
    (validate-new-sage pax p.sage ~ q.sage %.y)
  ?:  ?=(%| -.result)
    result
  &+[p.sage p.result]
::  Clam a bask (blot + noun) into a sage.
::  Used when reading historical data from the silo.
::
++  clam-bask
  |=  [pax=path =bask:tarball]
  ^-  (each sage:tarball tang)
  ::  boom: unwrap inner bask and retry its mark
  ::  if it heals, return the real sage; otherwise re-boom
  ?:  =([/ %boom] p.bask)
    =/  [err=tang inner=bask:tarball]  ;;([tang bask:tarball] q.bask)
    =/  res  $(bask inner)
    ?:  ?=(%& -.res)  res
    &+[[/ %boom] !>([p.res inner])]
  ?:  =([/ %hoon] p.bask)
    (mule |.([[/ %hoon] !>(;;(@t q.bask))]))
  ?:  =([/ %tang] p.bask)
    (mule |.([[/ %tang] !>(;;(tang q.bask))]))
  ?:  =([/ %mime] p.bask)
    (mule |.([[/ %mime] !>(;;(mime q.bask))]))
  =/  vale=$-(* vase)  (get-vale pax p.bask)
  =/  res=(each vase tang)  (mule |.((vale q.bask)))
  ?:  ?=(%| -.res)  res
  &+[p.bask p.res]
::  Validate all cages in a ball subtree, crash on failure
::
::  Always forces full dais validation (no nest optimization) because
::  validate-ball is only called when installing a fresh subtree where
::  the nest optimization wouldn't help anyway.
::
++  validate-ball
  |=  [cod=path =ball:tarball]
  ^-  ball:tarball
  ::  validate files at this level
  ::  for each file, run validate-new-sage and crash if it fails
  ::  rebuild contents map with validated vases
  ::
  =|  here=path
  |-
  =/  validated-contents=(map @ta content:tarball)
    ?~  fil.ball  ~
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.ball)
    =|  out=(map @ta content:tarball)
    |-
    ?~  files  out
    =/  [name=@ta =content:tarball]  i.files
    =/  res=(each vase tang)
      ~|  [%validate-ball name (weld cod here) p.sage.content]
      (validate-new-sage cod p.sage.content ~ q.sage.content %.y)
    ?.  ?=(%& -.res)
      ~&  >>  "validate-ball: boom {(trip name)} (mark %{(trip name.p.sage.content)}) at {(spud (weld cod here))}"
      $(files t.files, out (~(put by out) name content(sage [[/ %boom] !>([p.res [p.sage.content q.q.sage.content]])])))
    $(files t.files, out (~(put by out) name content(sage [p.sage.content p.res])))
  ::  recurse into subdirectories
  ::  validate each child ball and rebuild dir map
  ::
  =/  validated-dir=(map @ta ball:tarball)
    =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
    =|  out=(map @ta ball:tarball)
    |-
    ?~  kids  out
    =/  [name=@ta kid=ball:tarball]  i.kids
    $(kids t.kids, out (~(put by out) name ^$(here (snoc here name), ball kid)))
  ::  build validated ball
  ::  preserve fil metadata, swap in validated contents
  ::
  :_  validated-dir
  ?~  fil.ball  ~
  `u.fil.ball(contents validated-contents)
::
++  store-proc
  |=  [here=rail:tarball =proc:fiber:nexus]
  ^+  this
  =/  old=pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  =pipe:nexus  old(proc (~(put by proc.old) name.here proc))
  this(pool (~(put of pool) path.here pipe))
::  Bang a nexus directory — store tang, +stay all processes under it
::  TODO: bang subscriptions via born. Add proc=cass:clay to $tote that bumps
::  on any proc change (spawn, crash, bang, heal) under that directory.
::  Nexus bangs bump it too since they stay all procs. File-level healing is
::  implicit (successful spawn overwrites |+tang with &+process). Nexus-level
::  healing is explicit via clear-bangs-under before reload.
::
++  bang-nexus
  |=  [dest=fold:tarball err=tang]
  ^+  this
  ~&  >>>  "BANG nexus {(spud dest)}"
  %-  (slog err)
  ::  Set bang on the pipe at dest
  =/  old=pipe:nexus  (fall (~(get of pool) dest) *pipe:nexus)
  =.  pool  (~(put of pool) dest old(bang `err))
  ::  Bang every file under dest (set process to |+err)
  =/  sub=ball:tarball  (~(dip ba:tarball ball) dest)
  =.  this
    %+  roll  ~(tap ba:tarball sub)
    |=  [[=rail:tarball *] acc=_this]
    (bang-file:acc [(weld dest path.rail) name.rail] err)
  ::  Replace all processes under dest with +stay
  (stay-all-procs dest)
::  Bang a file — store tang on its process
::
++  bang-file
  |=  [here=rail:tarball err=tang]
  ^+  this
  ~&  >>>  "BANG file {(spud (snoc path.here name.here))}"
  :: %-  (slog err) often too big
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  old=(unit proc:fiber:nexus)  (~(get by proc.pipe) name.here)
  =/  =proc:fiber:nexus
    ?~  old  [|+err ~ ~]
    [|+err next.u.old skip.u.old]
  (store-proc here proc)
::  Replace all processes under a directory with +stay
::
++  stay-all-procs
  |=  dest=fold:tarball
  ^+  this
  =/  sub-pool=pool:nexus  (~(dip of pool) dest)
  (stay-pipe dest sub-pool)
::
++  stay-pipe
  |=  [here=fold:tarball sub=pool:nexus]
  ^+  this
  ::  Stay all files in this directory's pipe
  =.  this
    ?~  fil.sub  this
    =/  files=(list [@ta proc:fiber:nexus])  ~(tap by proc.u.fil.sub)
    |-
    ?~  files  this
    =/  old=proc:fiber:nexus  +.i.files
    =/  stay-proc=proc:fiber:nexus
      [&+stay:(fiber:fiber:nexus ,~) next.old skip.old]
    =.  this  (store-proc [here -.i.files] stay-proc)
    $(files t.files)
  ::  Recurse into subdirectories
  =/  kids=(list [@ta pool:nexus])  ~(tap by dir.sub)
  |-
  ?~  kids  this
  =.  this  (stay-pipe (snoc here -.i.kids) +.i.kids)
  $(kids t.kids)
::  Clear all bangs (nexus and file) under a directory
::
++  clear-bangs-under
  |=  dest=fold:tarball
  ^-  pool:nexus
  ?~  dest  (clear-pool-bangs pool)
  =/  kid=pool:nexus  (~(gut by dir.pool) i.dest ^+(pool [~ ~]))
  pool(dir (~(put by dir.pool) i.dest $(pool kid, dest t.dest)))
::
++  clear-pool-bangs
  |=  pol=pool:nexus
  ^-  pool:nexus
  =.  fil.pol
    ?~  fil.pol  ~
    `[~ proc.u.fil.pol]
  %=  pol
    dir  %-  ~(run by dir.pol)
         |=(sub=pool:nexus ^-(pool:nexus (clear-pool-bangs sub)))
  ==
::  Check if a file's nexus is banged (any ancestor directory has bang)
::
++  is-nexus-banged
  |=  here=rail:tarball
  ^-  ?
  =/  pax=path  path.here
  |-
  =/  pip=pipe:nexus  (fall (~(get of pool) pax) *pipe:nexus)
  ?:  ?=(^ bang.pip)  &
  ?~  pax  |
  $(pax (snip `path`pax))
::  Delete a file from pool and ball (NOT born - it's a high-water mark)
::
++  delete
  |=  [dir=path name=@ta]
  ^+  this
  ~?  >>  ?=(~ (~(get ba:tarball ball) [dir name]))
    "no grub at {(spud (weld dir /[name]))}"
  ::  Clean up outgoing subscriptions from this file
  =.  this  (sub-wipe [dir name])
  ::  Drop all silo refs from hist
  =/  sok=(unit sack:nexus)  (get-born [dir name])
  =?  silo  ?=(^ sok)
    (~(drop-hist si:nexus silo) hist.u.sok)
  ::  Remove from ball BEFORE notify so subscribers see deletion
  =.  ball  (~(del ba:tarball ball) dir name)
  =.  this  (bump-file [dir name])
  =/  old=pipe:nexus  (fall (~(get of pool) dir) *pipe:nexus)
  =/  =pipe:nexus  old(proc (~(del by proc.old) name))
  =.  pool  (~(put of pool) dir pipe)
  ::  Rebuild if deletion is inside a code nexus
  =/  cod=(unit path)
    =+  pax=dir
    |-  ?:  (~(has by code) pax)  `pax
    ?~  pax  ~
    $(pax (snip `path`pax))
  ?~  cod  this
  ~&  >>>  "delete: triggering build-code from {(spud dir)}"
  (build-code u.cod)
::  Send ack/nack back to poke source
::  - Internal (%&): enqueue %pack intake to source path
::  - External (%|): emit gall card
::
::  For internal pokes, sanitizes error if source can't peek target.
::
++  give-poke-ack
  |=  [here=rail:tarball =from:nexus =wire err=(unit tang)]
  ^+  this
  ::  Sanitize error if internal poke without peek permission
  =/  err=(unit tang)
    ?.  ?=(%& -.from)
      ?~(err ~ `~[leaf+"poke failed"])
    ?.  ?=([~ %|] (allowed %peek p.from `[%& here]))
      err
    ?~(err ~ `~[leaf+"poke failed"])  :: no peek = generic error
  ?-    -.from
      %&
    ::  Internal - send %pack intake to source path
    (enqu-take p.from (sys-give /pack) ~ %pack wire err)
    ::
      %|
    ::  External - send fact on caller's subscription path, then kick
    =/  src=@ta  (scot %p src.p.from)
    =/  pat=path  (weld /poke/[src] wire)
    =.  this  (emit-card %give %fact ~[pat] grubbery-ack+!>(err))
    (emit-card %give %kick ~[pat] ~)
  ==
::
++  give-poke-sign
  |=  [here=rail:tarball =took:eval:fiber:nexus]
  ^+  this
  ?.  ?=([~ %poke *] in.take.took)  this
  (give-poke-ack here from.give.take.took wire.give.take.took err.took)
::
++  give-poke-signs
  |=  [here=rail:tarball done=(list took:eval:fiber:nexus)]
  ^+  this
  ?~  done  this
  =.  this  (give-poke-sign here i.done)
  $(done t.done)
::
++  nack-poke-takes
  |=  [here=rail:tarball takes=(qeu take:fiber:nexus) err=tang]
  ^+  this
  ?:  =(~ takes)  this
  =^  =take:fiber:nexus  takes  ~(get to takes)
  =.  this  (give-poke-sign here [take `err])
  $(takes takes)
::  Nack all queued pokes in a pool subtree
::
++  nack-pool
  |=  [here=fold:tarball =pool:nexus err=tang]
  ^+  this
  ::  Nack pokes in procs at this level
  =.  this
    ?~  fil.pool  this
    =/  procs=(list [name=@ta =proc:fiber:nexus])  ~(tap by proc.u.fil.pool)
    |-
    ?~  procs  this
    =/  proc-rail=rail:tarball  [here name.i.procs]
    =.  this  (nack-poke-takes proc-rail next.proc.i.procs err)
    =.  this  (nack-poke-takes proc-rail skip.proc.i.procs err)
    $(procs t.procs)
  ::  Recurse into subdirectories
  =/  kids=(list [@ta pool:nexus])  ~(tap by dir.pool)
  |-
  ?~  kids  this
  =.  this  ^$(here (snoc here -.i.kids), pool +.i.kids)
  $(kids t.kids)
::  Run nexus on-loads top-down recursively
::
++  run-on-loads
  |=  [here=fold:tarball sub-sand=sand:nexus sub-gain=gain:nexus sub-ball=ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  ::  Check if this node has a nexus (skip on compile failure during boot)
  =/  nex=(unit nexus:nexus)
    ?~  fil.sub-ball  ~
    ?~  neck.u.fil.sub-ball  ~
    =/  res  (build-nexus here u.neck.u.fil.sub-ball)
    ?:  ?=(%& -.res)  `p.res
    ~&  >>  "run-on-loads: nexus build error at {(spud here)}"
    ~
  ::  Run on-load if nexus exists
  ::
  ::  IMPORTANT: The weir at the root of sub-sand is preserved from the parent.
  ::  A nexus cannot control its own sandboxing - that would defeat the purpose.
  ::  Sandboxing is always imposed from above. The nexus can only set weirs
  ::  for its children, never for itself.
  ::
  =/  parent-weir=(unit weir:nexus)  fil.sub-sand
  =/  parent-neck=(unit neck:tarball)
    ?~(fil.sub-ball ~ neck.u.fil.sub-ball)
  =/  [upd-sand=sand:nexus upd-gain=gain:nexus upd-ball=ball:tarball]
    ?~  nex  [sub-sand sub-gain sub-ball]
    (on-load:u.nex sub-sand sub-gain sub-ball)
  ::  Enforce parent weir on sand and parent neck on ball.
  ::  A nexus cannot change its own sandboxing or its own identity.
  ::
  =/  restored-lump=lump:tarball
    (fall fil.upd-ball *lump:tarball)
  =:  sub-sand  upd-sand(fil parent-weir)
      sub-gain  upd-gain
      sub-ball  upd-ball(fil `restored-lump(neck parent-neck))
  ==
  ::  Recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub-ball)
  |-
  ?~  kids  [sub-sand sub-gain sub-ball]
  =/  kid-name=@ta  -.i.kids
  =/  kid-ball=ball:tarball  +.i.kids
  =/  kid-sand=sand:nexus  (~(dip of sub-sand) /[kid-name])
  =/  kid-gain=gain:nexus  (~(dip of sub-gain) /[kid-name])
  =/  [new-kid-sand=sand:nexus new-kid-gain=gain:nexus new-kid-ball=ball:tarball]
    ^$(here (snoc here kid-name), sub-sand kid-sand, sub-gain kid-gain, sub-ball kid-ball)
  =.  sub-sand  (put-sub-sand sub-sand /[kid-name] new-kid-sand)
  =.  sub-gain  (put-sub-gain sub-gain /[kid-name] new-kid-gain)
  =.  dir.sub-ball  (~(put by dir.sub-ball) kid-name new-kid-ball)
  $(kids t.kids)
::  Reload a single nexus at dest (re-run on-load)
::
++  reload-nexus
  |=  dest=fold:tarball
  ^+  this
  =/  sub-ball=ball:tarball  (~(dip ba:tarball ball) dest)
  ?~  fil.sub-ball  ~|("no nexus at destination" !!)
  ?~  neck.u.fil.sub-ball  ~|("no nexus at destination" !!)
  =/  nex=(each nexus:nexus tang)
    (build-nexus dest u.neck.u.fil.sub-ball)
  ?:  ?=(%| -.nex)
    ~&  >>  "reload-nexus: build error at {(spud dest)}"
    (bang-nexus dest p.nex)
  =.  this  (reload-nexus-at dest p.nex)
  (spawn-all-files dest (~(dip ba:tarball ball) dest))
::  Run on-load for a nexus at dest and apply results
::
::  Reload a nexus: run on-load, write ball, recurse into child nexuses.
::  Does NOT spawn processes — callers spawn after the full tree is settled.
::
++  reload-nexus-at
  |=  [dest=fold:tarball nex=nexus:nexus]
  ^+  this
  =/  old-sub=ball:tarball  (~(dip ba:tarball ball) dest)
  =/  sub-ball=ball:tarball  old-sub
  =/  sub-sand=sand:nexus  (~(dip of sand) dest)
  =/  sub-gain=gain:nexus  (~(dip of gain) dest)
  =/  parent-weir=(unit weir:nexus)  fil.sub-sand
  =/  parent-neck=(unit neck:tarball)  ?~(fil.sub-ball ~ neck.u.fil.sub-ball)
  ::  Clear all bangs under this nexus before reloading
  ::  (reload will re-bang anything that still fails)
  =.  pool  (clear-bangs-under dest)
  ::  Run on-load (may crash)
  =/  load-res=(each [sand:nexus gain:nexus ball:tarball] tang)
    (mule |.((on-load:nex sub-sand sub-gain sub-ball)))
  ?:  ?=(%| -.load-res)
    ::  on-load crashed — bang this nexus, stay all processes
    ~&  >>  "reload-nexus-at: bang at {(spud dest)}"
    (bang-nexus dest p.load-res)
  =/  [upd-sand=sand:nexus upd-gain=gain:nexus upd-ball=ball:tarball]
    p.load-res
  ::  Enforce parent weir on sand and parent neck on ball
  =/  restored-lump=lump:tarball  (fall fil.upd-ball *lump:tarball)
  =/  new-sand=sand:nexus    upd-sand(fil parent-weir)
  =/  new-gain=gain:nexus    upd-gain
  =/  new-ball=ball:tarball  upd-ball(fil `restored-lump(neck parent-neck))
  ::  Validate marks in the new ball — failures become /boom blots so
  ::  bad marks surface as inspectable files rather than downstream bangs.
  =.  new-ball  ~|([%validate-ball-reload dest] (validate-ball dest new-ball))
  ::  Put results back — load-ball-changes writes ball and does bookkeeping
  =.  sand  (put-sub-sand sand dest new-sand)
  =.  gain  (put-sub-gain gain dest new-gain)
  =.  this  (load-ball-changes dest old-sub new-ball)
  =.  this  (bump-weir-changes dest sub-sand new-sand)
  =.  this  (audit-weir dest)
  (reload-child-nexuses dest)
::  Recursively reload all child nexuses top-to-bottom.
::  Every directory with a neck loads state and recurses into its children.
::
++  reload-child-nexuses
  |=  dest=fold:tarball
  ^+  this
  =/  sub=ball:tarball  (~(dip ba:tarball ball) dest)
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub)
  |-
  ?~  kids  this
  =/  [kid-name=@ta kid-ball=ball:tarball]  i.kids
  =/  kid-path=fold:tarball  (snoc dest kid-name)
  =.  this
    ::  Directory with a neck — reload it (recurses into its children)
    ::  Skip /code — it has a neck but is the code compiler, not a nexus
    ?:  ?&  ?=(^ fil.kid-ball)
            ?=(^ neck.u.fil.kid-ball)
            !=([/ %code] u.neck.u.fil.kid-ball)
        ==
      =/  kid-nex=(each nexus:nexus tang)
        (build-nexus kid-path u.neck.u.fil.kid-ball)
      ?:  ?=(%| -.kid-nex)
        (bang-nexus kid-path p.kid-nex)
      (reload-nexus-at kid-path p.kid-nex)
    ::  Non-nexus directory — recurse deeper
    $(kids ~(tap by dir.kid-ball), dest kid-path)
  $(kids t.kids)
::  Spawn processes for files in new ball, bump if content changed from old
::
++  spawn-new-files
  |=  [here=fold:tarball new=ball:tarball]
  ^+  this
  ?~  fil.new  this
  =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.new)
  |-
  ?~  files  this
  =/  file-name=@ta             -.i.files
  =/  file-rail=rail:tarball    [here file-name]
  =.  this  ?^((get-born file-rail) this (init-born file-rail))
  =.  this  (spawn-proc file-rail [%load ~])
  $(files t.files)
::  Spawn processes for all files in new ball recursively.
::
++  spawn-all-files
  |=  [here=fold:tarball new=ball:tarball]
  ^+  this
  =.  this  (spawn-new-files here new)
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.new)
  |-
  ?~  kids  this
  =/  kid-name=@ta  -.i.kids
  =.  this  ^$(here (snoc here kid-name), new +.i.kids)
  $(kids t.kids)
::
:: TODO: handle outgoing keens
::
::  Clean up subscriptions for a file (%file) or subtree (%tree)
::
++  clean
  |=  [=path mode=?(%file %tree)]
  ^+  this
  ::  Leave outgoing subscriptions (wex)
  ::
  =.  this
    %-  emit-cards
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] *]
    ^-  (unit card)
    ?.  ?=([%proc @ *] wire)  ~
    =/  [proc-rail=rail:tarball @ ^path]  (unwrap-wire wire)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
    ?.  ?-  mode
          %file  =(proc-path path)
          %tree  =((scag (lent path) proc-path) path)
        ==
      ~
    [~ %pass wire %agent [ship term] %leave ~]
  ::  Kick incoming subscribers (sup)
  ::
  %-  emit-cards
  %+  murn  ~(tap by sup.bowl)
  |=  [=duct =ship pat=^path]
  ^-  (unit card)
  ?.  ?=([%proc @ *] pat)  ~
  =/  [proc-rail=rail:tarball sub=^path]  (unwrap-watch-path pat)
  =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
  ?.  ?-  mode
        %file  =(proc-path path)
        %tree  =((scag (lent path) proc-path) path)
      ==
    ~
  [~ %give %kick ~[pat] ~]
::  =subs: Subscription management
::
::  Axal helpers for fwd/rev indices
::
++  fwd-get
  |=  target=lane:tarball
  ^-  subscribers:nexus
  =/  pax=path  ?-(-.target %| p.target, %& path.p.target)
  =/  node=[dir=subscribers:nexus fil=(map @ta subscribers:nexus)]
    (fall (~(get of fwd.subs) pax) [~ ~])
  ?-(-.target %| dir.node, %& (fall (~(get by fil.node) name.p.target) ~))
::
++  fwd-set
  |=  [target=lane:tarball watchers=subscribers:nexus]
  ^+  fwd.subs
  =/  pax=path  ?-(-.target %| p.target, %& path.p.target)
  =/  node=[dir=subscribers:nexus fil=(map @ta subscribers:nexus)]
    (fall (~(get of fwd.subs) pax) [~ ~])
  =.  node
    ?-  -.target
      %|  node(dir watchers)
      %&  ?~  watchers  node(fil (~(del by fil.node) name.p.target))
          node(fil (~(put by fil.node) name.p.target watchers))
    ==
  ?:  &(=(~ dir.node) =(~ fil.node))
    (~(del of fwd.subs) pax)
  (~(put of fwd.subs) pax node)
::
++  rev-get
  |=  watcher=rail:tarball
  ^-  subscriptions:nexus
  =/  node=(map @ta subscriptions:nexus)
    (fall (~(get of rev.subs) path.watcher) ~)
  (fall (~(get by node) name.watcher) ~)
::
++  rev-set
  |=  [watcher=rail:tarball targets=subscriptions:nexus]
  ^+  rev.subs
  =/  node=(map @ta subscriptions:nexus)
    (fall (~(get of rev.subs) path.watcher) ~)
  =.  node
    ?~  targets  (~(del by node) name.watcher)
    (~(put by node) name.watcher targets)
  ?~  node  (~(del of rev.subs) path.watcher)
  (~(put of rev.subs) path.watcher node)
::
++  tap-fwd
  =/  fwd=_fwd.subs  fwd.subs
  =|  pax=path
  =|  acc=(list [lane:tarball subscribers:nexus])
  |-  ^+  acc
  =.  acc
    ?~  fil.fwd  acc
    =+  nod=u.fil.fwd
    =.  acc  ?~(dir.nod acc [[[%| pax] dir.nod] acc])
    =/  fils  ~(tap by fil.nod)
    |-  ?~  fils  acc
    =?  acc  ?=(^ q.i.fils)  [[[%& pax p.i.fils] q.i.fils] acc]
    $(fils t.fils)
  =/  kids  ~(tap by dir.fwd)
  |-  ?~  kids  acc
  =.  acc  ^$(pax (snoc pax p.i.kids), fwd q.i.kids)
  $(kids t.kids)
::
++  tap-rev
  =/  rev=_rev.subs  rev.subs
  =|  pax=path
  =|  acc=(list [rail:tarball subscriptions:nexus])
  |-  ^+  acc
  =.  acc
    ?~  fil.rev  acc
    =/  entries  ~(tap by u.fil.rev)
    |-  ?~  entries  acc
    =?  acc  ?=(^ q.i.entries)  [[[pax p.i.entries] q.i.entries] acc]
    $(entries t.entries)
  =/  kids  ~(tap by dir.rev)
  |-  ?~  kids  acc
  =.  acc  ^$(pax (snoc pax p.i.kids), rev q.i.kids)
  $(kids t.kids)
::
::  Add subscription: watcher subscribes to target with wire
::
++  sub-put
  |=  [target=lane:tarball watcher=rail:tarball =wire mark=(unit mark)]
  ^+  this
  ::  Add to forward index: target → (watcher → [wire mark])
  =/  watchers=subscribers:nexus  (fwd-get target)
  =.  fwd.subs  (fwd-set target (~(put by watchers) watcher [wire mark]))
  ::  Add to reverse index: watcher → targets
  =/  targets=subscriptions:nexus  (rev-get watcher)
  =.  rev.subs  (rev-set watcher (~(put in targets) target))
  this
::  Remove subscription: watcher unsubscribes from target
::
++  sub-del
  |=  [target=lane:tarball watcher=rail:tarball]
  ^+  this
  ::  Remove from forward index
  =/  watchers=subscribers:nexus  (~(del by (fwd-get target)) watcher)
  =.  fwd.subs  (fwd-set target watchers)
  ::  Remove from reverse index
  =/  targets=subscriptions:nexus  (~(del in (rev-get watcher)) target)
  =.  rev.subs  (rev-set watcher targets)
  this
::  Remove all subscriptions from a watcher (for cleanup on death)
::
++  sub-wipe
  |=  watcher=rail:tarball
  ^+  this
  =/  targets=(set lane:tarball)  (rev-get watcher)
  =.  this
    %-  ~(rep in targets)
    |=  [target=lane:tarball acc=_this]
    (sub-del:acc target watcher)
  this
::  Send %news to all subscribers watching changed lanes
::
++  notify
  |=  old-born=born:nexus
  ^+  this
  =/  changed=(set lane:tarball)  (diff-born-state:nexus old-born born)
  ?:  =(~ changed)  this
  ::  If the jael-source file changed, give udiffs to gall subscribers
  =.  this  (maybe-give-jael changed)
  ::  For each watched lane, find subscribers and send news
  =/  watched=(list [target=lane:tarball watchers=(map rail:tarball [=wire mark=(unit mark)])])
    tap-fwd
  |-
  ?~  watched  this
  =/  [target=lane:tarball watchers=(map rail:tarball [=wire mark=(unit mark)])]  i.watched
  ::  Find all changed lanes that are inside this target (or equal to target)
  =/  relevant=(set lane:tarball)
    %-  ~(gas in *(set lane:tarball))
    %+  murn  ~(tap in changed)
    |=  chg=lane:tarball
    ^-  (unit lane:tarball)
    ?-    -.target
        ::  File target: only exact match counts
        %&
      ?.  &(?=(%& -.chg) =(p.chg p.target))  ~
      `chg
        ::  Dir target: changed lane must be under target dir
        %|
      ?-  -.chg
        ::  Changed file: file's dir must be under target dir
        %&  ?~((decap:tarball p.target path.p.chg) ~ `chg)
        ::  Changed dir: must be under or equal to target dir
        %|  ?~((decap:tarball p.target p.chg) ~ `chg)
      ==
    ==
  ::  Skip if nothing relevant changed
  ?:  =(~ relevant)  $(watched t.watched)
  ::  Get current view of target
  =/  =view:nexus
    ?-    -.target
        %&
      =/  content=(unit content:tarball)
        (~(get ba:tarball ball) path.p.target name.p.target)
      ?~  content  [%none ~]
      =/  node=(unit [=tote:nexus bags=(map @ta sack:nexus)])
        (~(get of born) path.p.target)
      =/  sk=sack:nexus
        ?~  node  *sack:nexus
        (fall (~(get by bags.u.node) name.p.target) *sack:nexus)
      [%file sk (lookup-gain p.target) sage.u.content]
        %|
      =/  sub-ball=(unit ball:tarball)  (~(dap ba:tarball ball) p.target)
      ?~  sub-ball  [%none ~]
      [%ball (~(dip of sand) p.target) (~(dip of gain) p.target) (~(dip of born) p.target) u.sub-ball]
    ==
  ::  Send to each watcher, converting file view if mark is set
  =.  this
    %-  ~(rep by watchers)
    |=  [[watcher=rail:tarball =wire mark=(unit mark)] acc=_this]
    =/  watcher-view=view:nexus
      ?~  mark  view
      ?.  ?=(%file -.view)  view
      ?:  =(name.p.sage.view u.mark)  view  :: already correct mark
      =/  =tube:clay  (get-tube path.watcher [p.sage.view [/ u.mark]])
      view(sage [[/ u.mark] (tube q.sage.view)])
    (enqu-take:acc watcher (sys-give:acc /news) ~ %news wire watcher-view)
  $(watched t.watched)
::  If the jael-source rail changed, give %azimuth-udiffs to gall subs.
::  Sends on / (all udiffs) and on /(scot %p ship) (filtered per ship).
::
++  maybe-give-jael
  |=  changed=(set lane:tarball)
  ^+  this
  ?~  jael-source  this
  =/  src-lane=lane:tarball  [%& u.jael-source]
  ?.  (~(has in changed) src-lane)  this
  =/  content=(unit content:tarball)
    (~(get ba:tarball ball) u.jael-source)
  ?~  content  this
  =+  !<(uds=udiffs:point:jael q.sage.u.content)
  ?:  =(~ uds)  this
  ::  Give full batch on /
  =.  cards
    [[%give %fact ~[/] %azimuth-udiffs !>(uds)] cards]
  ::  Give per-ship filtered batches on /(scot %p ship)
  =/  remaining=(list @p)
    %+  turn  uds
    |=([=ship *] ship)
  |-
  ?~  remaining  this
  =/  filtered=udiffs:point:jael
    (skim uds |=([s=^ship *] =(s i.remaining)))
  =.  cards
    [[%give %fact ~[/(scot %p i.remaining)] %azimuth-udiffs !>(filtered)] cards]
  $(remaining t.remaining)
::  Fell a single subscription: remove from indices, send %fell to watcher
::
++  fell-sub
  |=  [target=lane:tarball watcher=rail:tarball]
  ^+  this
  =/  val=[=wire mark=(unit mark)]  (~(got by (fwd-get target)) watcher)
  =.  this  (sub-del target watcher)
  (enqu-take watcher (sys-give /fell) ~ %fell wire.val)
::  Re-check subscriptions after weir change: fell any that are now blocked
::
++  audit-weir
  |=  base=path
  ^+  this
  ::  Find watchers whose path is under (or equal to) the changed weir
  =/  affected=(list [watcher=rail:tarball targets=subscriptions:nexus])
    %+  skim  tap-rev
    |=  [watcher=rail:tarball *]
    ?=(^ (decap:tarball base path.watcher))
  |-
  ?~  affected  this
  =/  watcher=rail:tarball  watcher.i.affected
  =/  tgts=(list lane:tarball)  ~(tap in targets.i.affected)
  =.  this
    |-
    ?~  tgts  this
    =/  =filt:nexus  (allowed %peek watcher `i.tgts)
    =?  this  ?=([~ %|] filt)  (fell-sub i.tgts watcher)
    $(tgts t.tgts)
  $(affected t.affected)
::
++  process-darts
  |=  [here=rail:tarball darts=(list dart:nexus)]
  ^+  this
  ?~  darts  this
  =.  this  (process-dart here i.darts)
  $(darts t.darts)
::
++  build-nexus
  |=  [pax=path =neck:tarball]
  ^-  (each nexus:nexus tang)
  ?:  =([/ %root] neck)  &+root
  =/  res=(unit built:nexus)  (get-built pax (weld /nex path.neck) name.neck)
  ?~  res  |+~[leaf+"build-nexus: {(trip (rail-to-arm:tarball [path.neck name.neck]))} not found in code"]
  ?+  -.u.res
    |+~[leaf+"build-nexus: unexpected artifact type {<-.u.res>}"]
    %tang  |+tang.u.res
    %vase
  =/  nex=(unit nexus:nexus)  (mole |.(!<(nexus:nexus vase.u.res)))
  ?~  nex  |+~[leaf+"build-nexus: failed to extract nexus from vase"]
  &+u.nex
  ==
::
++  find-nearest-nexus
  |=  here=rail:tarball
  ^-  (unit (pair path neck:tarball))
  =/  here-path=path  (snoc path.here name.here)
  |-
  ?~  lump=(~(get of ball) here-path)
    ?~  here-path  ~
    $(here-path (snip `path`here-path))
  ?^  neck.u.lump
    `[here-path u.neck.u.lump]
  ?~  here-path  ~
  $(here-path (snip `path`here-path))
::
::
++  build-spool
  |=  here=rail:tarball
  ^-  (unit spool:fiber:nexus)
  ::  Get the file from the ball - must exist
  =/  file-data=(unit content:tarball)  (~(get ba:tarball ball) path.here name.here)
  ?~  file-data  ~
  ::  Extract mark from the sage
  =/  =mark  name.p.sage.u.file-data
  ::  Find the nearest parent nexus
  =/  nex-info=(unit (pair path neck:tarball))  (find-nearest-nexus here)
  ?~  nex-info  ~
  ::  Build the nexus from the neck
  =/  nex-res=(each nexus:nexus tang)  (build-nexus path.here q.u.nex-info)
  ?:  ?=(%| -.nex-res)  ~
  ::  Call on-file with rail relative to nexus location
  `(on-file:p.nex-res (relativize-rail:tarball p.u.nex-info here) mark)
::
++  process-dart
  |=  [here=rail:tarball =dart:nexus]
  ^+  this
  ::  %here does its own permission checks — skip weir pre-check
  ?:  ?=(%here -.dart)
    (handle-dart here dart ~)
  =/  [=jump:nexus dest=(unit lane:tarball)]  (dart-to-dest here dart)
  =/  =filt:nexus  (allowed jump here dest)
  ?+    filt  (handle-dart here dart filt)
      [~ %|]
    ::  Vetoed - send %veto intake back to source
    (enqu-take here (sys-give /veto) ~ %veto dart)
    ::
      [~ %&]
    ::  Allowed but should clam vases crossing sandbox boundary
    ::  (make darts don't need clamming - they go through validate-sage anyway)
    ::  Peek results are clammed inside handle-dart (data flows back)
    ?.  ?=([%node * * ?(%poke %over) *] dart)
      (handle-dart here dart filt)
    =/  clammed=(each sage:tarball tang)  (clam-sage path.here sage.load.dart)
    ?:  ?=(%| -.clammed)
      (enqu-take here (sys-give /veto) ~ %veto dart)
    (handle-dart here dart(sage.load p.clammed) filt)
  ==
::  Extract jump category and destination from a dart for weir filtering.
::  Returns [jump dest] where:
::    - jump: the filter category (%sysc, %make, %poke, %peek)
::    - dest: absolute destination path, or ~ for syscalls
::
++  dart-to-dest
  |=  [here=rail:tarball =dart:nexus]
  ^-  [jump:nexus (unit lane:tarball)]
  ?+    -.dart  [%sysc ~]          :: %sysc, %scry, %here target system
      %node                        :: %node darts target a file/dir
    =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] road.dart)
    :_  dest-lane
    ?-  -.load.dart
      ?(%peek %keep %drop %seek %peep %manu %bang %code %font)  %peek  :: read operations
      %poke                       %poke
        $?  %make  %cull  %sand  %load
            %over  %gain  %lose
        ==
      %make  :: all modify tree structure
    ==
    ::
      %manu
    [%sysc ~]  :: direct: no path to check, bypasses weir
  ==
::
++  handle-dart
  |=  [here=rail:tarball =dart:nexus =filt:nexus]
  ^+  this
  =/  cod=path  path.here
  ?-    -.dart
      %sysc
    ::  Emit gall card directly (with wrapped wire/paths)
    ::  Exception: /http-response/ paths go to eyre unwrapped
    =/  =card  card.dart
    ?+    card  (emit-card card)
        [%pass *]
      (emit-card card(p (wrap-wire here p.card)))
        [%give ?(%fact %kick) *]
      =/  wrapped=(list path)
        %+  turn  paths.p.card
        |=  p=path
        ?:  ?=([%http-response *] p)
          p  :: don't wrap http-response paths
        (wrap-watch-path here p)
      (emit-card card(paths.p wrapped))
    ==
    ::
      %node
    ::  Send load to another path
    =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] road.dart)
    ?~  dest-lane
      ~&  [%node-bad-road here road.dart]
      this
    ?-    -.load.dart
        %poke
      ::  Poke destination must be a file
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      ::  Poke with return address (relativize source for fiber intake)
      =/  rel=from:fiber:nexus  (relativize-from:nexus dest &+here)
      (enqu-take dest [&+here wire.dart] ~ %poke rel sage.load.dart)
      ::
        %make
      ::  Create file or directory.
      ::  If mark is set on a file make, convert the cage to the
      ::  destination mark via cached tube before storing.
      =/  =make:nexus
        ?.  ?=(%| -.make.load.dart)
          make.load.dart
        ?~  mark.p.make.load.dart
          make.load.dart
        ?:  =(name.p.sage.p.make.load.dart u.mark.p.make.load.dart)
          make.load.dart
        =/  =tube:clay  (get-tube cod [p.sage.p.make.load.dart [/ u.mark.p.make.load.dart]])
        make.load.dart(sage.p [[/ u.mark.p.make.load.dart] (tube q.sage.p.make.load.dart)])
      =/  res=(each _this tang)  (mule |.((^make u.dest-lane make)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /made) ~ %made wire.dart ~)
        %|  (enqu-take here (sys-give /made) ~ %made wire.dart `p.res)
      ==
      ::
        %cull
      ::  Delete file or directory at dest
      =/  res=(each _this tang)  (mule |.((cull u.dest-lane)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /gone) ~ %gone wire.dart ~)
        %|  (enqu-take here (sys-give /gone) ~ %gone wire.dart `p.res)
      ==
      ::
        %sand
      ::  Set weir at dest (must be a directory)
      ?>  ?=(%| -.u.dest-lane)
      =/  dest=fold:tarball  p.u.dest-lane
      =/  res=(each _this tang)  (mule |.((set-weir dest weir.load.dart)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /sand) ~ %sand wire.dart ~)
        %|  (enqu-take here (sys-give /sand) ~ %sand wire.dart `p.res)
      ==
      ::
        %load
      ::  Reload nexus at dest (must be a directory with a nexus)
      ?>  ?=(%| -.u.dest-lane)
      =/  dest=fold:tarball  p.u.dest-lane
      =/  res=(each _this tang)  (mule |.((reload-nexus dest)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /load) ~ %load wire.dart ~)
        %|  (enqu-take here (sys-give /load) ~ %load wire.dart `p.res)
      ==
      ::
        %over
      ::  Overwrite grub content, converting mark via warm tube if needed
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      =/  old=(unit content:tarball)
        (~(get ba:tarball ball) path.dest name.dest)
      ?~  old
        (enqu-take here (sys-give /over) ~ %over wire.dart `~[leaf+"file not found: {(spud (snoc path.dest name.dest))}"])
      =/  old-blot=blot:tarball  p.sage.u.old
      =/  new-blot=blot:tarball  p.sage.load.dart
      ?:  =([/ %boom] old-blot)
        ~&  >>>  "over: target file is boomed: {(spud (snoc path.dest name.dest))}"
        (enqu-take here (sys-give /over) ~ %over wire.dart `~[leaf+"over: target file is boomed, fix the mark and reload: {(spud (snoc path.dest name.dest))}"])
      =/  converted=sage:tarball
        ?:  =(old-blot new-blot)
          sage.load.dart
        =/  =tube:clay  (get-tube cod [[/ name.new-blot] [/ name.old-blot]])
        [old-blot (tube q.sage.load.dart)]
      =/  val=(each vase tang)
        (validate-new-sage cod p.converted `q.sage.u.old q.converted %.n)
      ?:  ?=(%| -.val)
        (enqu-take here (sys-give /over) ~ %over wire.dart `p.val)
      =/  new-content=content:tarball  u.old(sage [p.converted p.val])
      =.  this  (save-file dest new-content)
      =.  this  (enqu-take dest (sys-give /writ) ~ %writ ~)
      (enqu-take here (sys-give /over) ~ %over wire.dart ~)
      ::
        %peek
      ::  Refresh /sys/bowl/ virtual files on every peek
      =.  ball
        (~(put ba:tarball ball) [/sys/bowl %our] [~ [/ %ship] !>(our.bowl)])
      =/  now-existing=(unit content:tarball)
        (~(get ba:tarball ball) /sys/bowl %now)
      =/  now-val=@da
        ?~  now-existing  now.bowl
        =/  prev=@da  !<(@da q.sage.u.now-existing)
        ?:  (gte prev now.bowl)
          (add prev (div ~s1 1.000))
        now.bowl
      =.  ball
        (~(put ba:tarball ball) [/sys/bowl %now] [~ [/ %time] !>(now-val)])
      =/  eny-existing=(unit content:tarball)
        (~(get ba:tarball ball) /sys/bowl %eny)
      =/  eny-val=@uvJ
        ?~  eny-existing  eny.bowl
        (shaz (cat 3 eny.bowl !<(@uvJ q.sage.u.eny-existing)))
      =.  ball
        (~(put ba:tarball ball) [/sys/bowl %eny] [~ [/ %entropy] !>(eny-val)])
      ::  Peek at dest - directory returns ball+sand, file returns cage
      ::  Returns %none if directory doesn't exist or has no lump
      ::  ver: if set, read historical version from hist via silo
      ?-    -.u.dest-lane
          %|
        =/  dest=fold:tarball  p.u.dest-lane
        =/  sub-ball=(unit ball:tarball)  (~(dap ba:tarball ball) dest)
        ?~  sub-ball
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        =/  sub-sand=sand:nexus  (~(dip of sand) dest)
        =/  sub-born=born:nexus  (~(dip of born) dest)
        =?  u.sub-ball  |(?=([~ %&] filt) clam.load.dart)
          (validate-ball cod u.sub-ball)
        =/  sub-gain=gain:nexus  (~(dip of gain) dest)
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %ball sub-sand sub-gain sub-born u.sub-ball)
        ::
          %&
        =/  dest=rail:tarball  p.u.dest-lane
        =/  content=(unit content:tarball)
          (~(get ba:tarball ball) path.dest name.dest)
        ?~  content
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        =/  node=(unit [=tote:nexus bags=(map @ta sack:nexus)])
          (~(get of born) path.dest)
        =/  sk=sack:nexus
          ?~  node  *sack:nexus
          (fall (~(get by bags.u.node) name.dest) *sack:nexus)
        ::  Resolve source: historical bask from silo or current sage from ball
        =/  source=(unit sage:tarball)
          ?^  case.load.dart
            =/  =lobe:clay
              (resolve-case:nexus u.case.load.dart hist.sk)
            =/  got=(unit bask:tarball)  (~(get si:nexus silo) lobe)
            ?~  got  ~
            ::  Clam bask back to sage
            =/  res=(each sage:tarball tang)  (clam-bask cod u.got)
            ?:  ?=(%| -.res)  ~
            `p.res
          `sage.u.content
        ?~  source
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        ::  Clam at weir boundary or by request
        =/  clammed=sage:tarball
          ?.  |(?=([~ %&] filt) clam.load.dart)  u.source
          =/  res=(each sage:tarball tang)  (clam-sage cod u.source)
          ?:  ?=(%| -.res)
            ~|(%peek-clam-failed !!)
          p.res
        ::  Apply mark conversion if requested
        =/  result=sage:tarball
          ?~  mark.load.dart  clammed
          ?:  =(name.p.clammed u.mark.load.dart)  clammed
          =/  =tube:clay  (get-tube cod [[/ name.p.clammed] [/ u.mark.load.dart]])
          [p.clammed (tube q.clammed)]
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %file sk (lookup-gain dest) result)
      ==
      ::
        %bang
      ::  Query error state at dest: directory bangs or file error
      ?-    -.u.dest-lane
          %|
        =/  dest=fold:tarball  p.u.dest-lane
        =/  pip=pipe:nexus  (fall (~(get of pool) dest) *pipe:nexus)
        =/  err=(map @ta (unit tang))
          %-  ~(run by proc.pip)
          |=(=proc:fiber:nexus ?:(?=(%| -.process.proc) `p.process.proc ~))
        (enqu-take here (sys-give /bang) ~ %bang wire.dart &+[bang.pip err])
        ::
          %&
        =/  dest=rail:tarball  p.u.dest-lane
        =/  pip=pipe:nexus  (fall (~(get of pool) path.dest) *pipe:nexus)
        =/  prc=(unit proc:fiber:nexus)  (~(get by proc.pip) name.dest)
        =/  err=(unit tang)  ?~(prc ~ ?:(?=(%| -.process.u.prc) `p.process.u.prc ~))
        (enqu-take here (sys-give /bang) ~ %bang wire.dart |+err)
      ==
      ::
        %code
      ::  Peek the bins slice at dest
      ::
      ?-    -.u.dest-lane
          %|
        =/  dest=fold:tarball  p.u.dest-lane
        =/  nex=(unit fold:tarball)
          =+  pax=dest
          |-  ?:  (~(has by code) pax)  `pax
          ?~  pax  ~
          $(pax (snip `path`pax))
        ?~  nex
          (enqu-take here (sys-give /code) ~ %code wire.dart |+[%tang ~[leaf+"code: no code nexus at {(spud dest)}"]])
        =/  =lode:nexus  (~(got by code) u.nex)
        =/  inner=fold:tarball  (slag (lent u.nex) dest)
        =/  sub-bins=bins:nexus  (~(dip of bins.lode) inner)
        (enqu-take here (sys-give /code) ~ %code wire.dart &+sub-bins)
        ::
          %&
        =/  dest=rail:tarball  p.u.dest-lane
        =/  nex=(unit fold:tarball)
          =+  pax=path.dest
          |-  ?:  (~(has by code) pax)  `pax
          ?~  pax  ~
          $(pax (snip `path`pax))
        ?~  nex
          (enqu-take here (sys-give /code) ~ %code wire.dart |+[%tang ~[leaf+"code: no code nexus at {(spud path.dest)}"]])
        =/  =lode:nexus  (~(got by code) u.nex)
        =/  inner=path  (slag (lent u.nex) path.dest)
        =/  node=(unit (map @ta built:nexus))  (~(get of bins.lode) inner)
        =/  hit=(unit built:nexus)
          ?~  node  ~
          (~(get by u.node) name.dest)
        ?^  hit
          (enqu-take here (sys-give /code) ~ %code wire.dart |+u.hit)
        ::  Tube requests: /tub/from/to — resolve via marc grow gate
        ?.  ?=([%tub @ ~] inner)
          (enqu-take here (sys-give /code) ~ %code wire.dart |+[%tang ~[leaf+"code: {(trip name.dest)} not found at {(spud path.dest)}"]])
        =/  from=blot:tarball  [/ i.t.inner]
        =/  to=blot:tarball  [/ name.dest]
        =/  tube-res=(each tube:clay tang)
          (mule |.((grow:(get-marc (snip `path`u.nex) from) to)))
        ?:  ?=(%| -.tube-res)
          (enqu-take here (sys-give /code) ~ %code wire.dart |+[%tang p.tube-res])
        (enqu-take here (sys-give /code) ~ %code wire.dart |+[%vase !>(p.tube-res)])
      ==
      ::
        %font
      ::  Find the /code namespace governing this node.
      ::  Walks up from dest to the nearest /code lode.
      =/  pax=path
        ?-(-.u.dest-lane %| p.u.dest-lane, %& path.p.u.dest-lane)
      =/  ns=(unit fold:tarball)  (find-code-ns pax)
      ?~  ns
        (enqu-take here (sys-give /font) ~ %font wire.dart ~)
      =/  =bend:tarball  (make-bend:tarball here [%| u.ns])
      (enqu-take here (sys-give /font) ~ %font wire.dart `bend)
      ::
        %keep
      ::  Subscribe to changes at dest (uses peek permission)
      =.  this  (sub-put u.dest-lane here wire.dart mark.load.dart)
      ::  Construct initial view of the watched lane
      =/  =view:nexus
        ?-  -.u.dest-lane
            %&
          =/  dest=rail:tarball  p.u.dest-lane
          =/  content=(unit content:tarball)
            (~(get ba:tarball ball) path.dest name.dest)
          ?~  content  [%none ~]
          =/  node=(unit [=tote:nexus bags=(map @ta sack:nexus)])
            (~(get of born) path.dest)
          =/  sk=sack:nexus
            ?~  node  *sack:nexus
            (fall (~(get by bags.u.node) name.dest) *sack:nexus)
          [%file sk (lookup-gain dest) sage.u.content]
            %|
          =/  dest=fold:tarball  p.u.dest-lane
          =/  sub-ball=(unit ball:tarball)  (~(dap ba:tarball ball) dest)
          ?~  sub-ball  [%none ~]
          [%ball (~(dip of sand) dest) (~(dip of gain) dest) (~(dip of born) dest) u.sub-ball]
        ==
      ::  Apply mark conversion if requested
      =?  view  &(?=(^ mark.load.dart) ?=(%file -.view))
        ?:  =(name.p.sage.view u.mark.load.dart)  view
        =/  =tube:clay  (get-tube cod [p.sage.view [/ u.mark.load.dart]])
        view(sage [[/ u.mark.load.dart] (tube q.sage.view)])
      (enqu-take here (sys-give /bond) ~ %bond wire.dart &+view)
      ::
        %drop
      ::  Unsubscribe from dest
      =.  this  (sub-del u.dest-lane here)
      (enqu-take here (sys-give /fell) ~ %fell wire.dart)
      ::
        %seek
      ::  Find all [rail cass] pairs with matching lobe in subtree
      =/  res=(each (list [=rail:tarball =cass:clay]) tang)
        (mule |.((seek-lobe u.dest-lane lobe.load.dart)))
      (enqu-take here (sys-give /found) ~ %seek wire.dart res)
      ::
        %peep
      ::  Query hist entries matching find spec, clam pages to cages
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      =/  sk=(unit sack:nexus)  (get-born dest)
      ?~  sk
        (enqu-take here (sys-give /peep) ~ %peep wire.dart |+~[leaf+"no history for {(spud (snoc path.dest name.dest))}"])
      =/  entries=(list [key=cass:clay val=lobe:clay])
        (tap:on-hist:nexus hist.u.sk)
      =/  hits=(list [cass:clay sage:tarball])
        %+  murn  entries
        |=  [key=cass:clay val=lobe:clay]
        ^-  (unit [cass:clay sage:tarball])
        =/  match=?
          ?-    -.find.load.dart
              %pick
            (~(has in cass.find.load.dart) key)
              %date
            ?&  (fall (bind from.find.load.dart |=(d=@da (gte da.key d))) %.y)
                (fall (bind to.find.load.dart |=(d=@da (lte da.key d))) %.y)
            ==
              %numb
            ?&  (fall (bind from.find.load.dart |=(n=@ud (gte ud.key n))) %.y)
                (fall (bind to.find.load.dart |=(n=@ud (lte ud.key n))) %.y)
            ==
          ==
        ?.  match  ~
        =/  got=(unit bask:tarball)  (~(get si:nexus silo) val)
        ?~  got  ~
        =/  res=(each sage:tarball tang)  (clam-bask cod u.got)
        ?:  ?=(%| -.res)  ~
        `[key p.res]
      (enqu-take here (sys-give /peep) ~ %peep wire.dart &+hits)
      ::
        %gain
      ::  Set gain flag. Recursive on directories, single file on rails.
      =/  res=(each _this tang)
        (mule |.((set-gain-lane u.dest-lane flag.load.dart)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /gain) ~ %gain wire.dart ~)
        %|  (enqu-take here (sys-give /gain) ~ %gain wire.dart `p.res)
      ==
      ::
        %lose
      ::  Drop hist entries and decrement silo refs
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      =/  res=(each _this tang)
        (mule |.((drop-hist dest lose.load.dart)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /lost) ~ %lost wire.dart ~)
        %|  (enqu-take here (sys-give /lost) ~ %lost wire.dart `p.res)
      ==
      ::
        %manu
      ::  By road: resolve, find nearest nexus, relativize, call on-manu
      =/  target-path=path
        ?-(-.u.dest-lane %& (snoc path.p.u.dest-lane name.p.u.dest-lane), %| p.u.dest-lane)
      ::  Walk up tree to find nearest covering nexus
      =/  nex-info=(unit (pair path neck:tarball))
        |-
        ?~  lump=(~(get of ball) target-path)
          ?~  target-path  ~
          $(target-path (snip `path`target-path))
        ?^  neck.u.lump
          `[target-path u.neck.u.lump]
        ?~  target-path  ~
        $(target-path (snip `path`target-path))
      ?~  nex-info
        (enqu-take here (sys-give /manu) ~ %manu wire.dart |+~[leaf+"no nexus covers this path"])
      ::  ~&  >  "process-manu-search: build-nexus {(trip q.u.nex-info)} at {(spud (snoc path.here name.here))}"
      =/  nex-res=(each nexus:nexus tang)  (build-nexus cod q.u.nex-info)
      ?:  ?=(%| -.nex-res)
        (enqu-take here (sys-give /manu) ~ %manu wire.dart |+~[leaf+"nexus build failed: {(trip (rail-to-arm:tarball q.u.nex-info))}"])
      ::  Relativize target path to nexus location
      =/  rel-path=path  (slag (lent p.u.nex-info) target-path)
      ::  Build query from relative path + lane type
      =/  =mana:nexus
        ?-    -.u.dest-lane
            %|  [%& rel-path]
            %&
          ?~  rel-path
            [%& ~]
          =/  =mark
            =/  content=(unit content:tarball)
              (~(get ba:tarball ball) path.p.u.dest-lane name.p.u.dest-lane)
            (fall (bind content |=(c=content:tarball name.p.sage.c)) %$)
          [%| [(snip `path`rel-path) (rear rel-path)] mark]
        ==
      =/  manu-res=(each @t tang)
        (mule |.((on-manu:p.nex-res mana)))
      (enqu-take here (sys-give /manu) ~ %manu wire.dart manu-res)
    ==
    ::
      %manu
    ::  Direct: build nexus from neck, call on-manu directly
    ::  ~&  >  "process-manu-direct: build-nexus {(trip neck.dart)} at {(spud (snoc path.here name.here))}"
    =/  nex-res=(each nexus:nexus tang)  (build-nexus cod neck.dart)
    ?:  ?=(%| -.nex-res)
      (enqu-take here (sys-give /manu) ~ %manu wire.dart |+~[leaf+"nexus not found: {(trip (rail-to-arm:tarball neck.dart))}"])
    =/  manu-res=(each @t tang)
      (mule |.((on-manu:p.nex-res mana.dart)))
    (enqu-take here (sys-give /manu) ~ %manu wire.dart manu-res)
    ::
      %scry
    ?~  scry.dart
      ::  Null scry returns agent state
      (enqu-take here (sys-give /scry) ~ %scry wire.dart !>(state))
    ::  Do the scry and enqueue result
    ::  Path format: /vane/desk/rest... -> /vane/~ship/desk/~date/rest...
    =/  pat=path  path.u.scry.dart
    ?>  ?=([@ @ *] pat)
    =/  res=vase
      !>(.^(mold.u.scry.dart i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat))
    (enqu-take here (sys-give /scry) ~ %scry wire.dart res)
    ::
      %here
    ::  Request location — walk up, reveal as much as allowed
    =/  loc=here:nexus  (walk-here here)
    (enqu-take here (sys-give /here) ~ %here wire.dart loc)
    ::
      %soup
    ::  Request filtered wex/sup for this process
    (enqu-take here (sys-give /soup) ~ %soup wire.dart (make-soup here))
    ::
      %kept
    ::  Return this grub's outgoing subscriptions, relativized
    =/  targets=(set lane:tarball)  (rev-get here)
    =/  =kept:nexus
      %-  ~(gas in *kept:nexus)
      %+  turn  ~(tap in targets)
      |=(target=lane:tarball (make-bend:tarball here target))
    (enqu-take here (sys-give /kept) ~ %kept wire.dart kept)
  ==
::
++  spawn-proc
  |=  [here=rail:tarball =prod:fiber:nexus]
  ^+  this
  ::  Skip if nexus is banged — don't try to build processes
  ?:  (is-nexus-banged here)
    this
  ::  Bump proc cass quietly (caller batches notify)
  =.  this  (bump-proc here %.n)
  ::  Build spool and process — bang file on crash
  =/  spool-res=(each spool:fiber:nexus tang)
    (mule |.((fall (build-spool here) default-spool)))
  ?:  ?=(%| -.spool-res)
    ~&  >>  "spawn-proc: bang {(spud (snoc path.here name.here))} — on-file crash"
    (bang-file here p.spool-res)
  =/  proc-res=(each process:fiber:nexus tang)
    (mule |.((p.spool-res prod)))
  ?:  ?=(%| -.proc-res)
    ~&  >>  "spawn-proc: bang {(spud (snoc path.here name.here))} — spool crash"
    (bang-file here p.proc-res)
  ::  Success — process is live. Move existing next into skip so the
  ::  fresh process doesn't consume stale takes meant for the old one.
  ::  They merge back on %cont when the process is ready.
  =/  =process:fiber:nexus  p.proc-res
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  old=(unit proc:fiber:nexus)  (~(get by proc.pipe) name.here)
  =/  old-next=(qeu take:fiber:nexus)  ?~(old ~ next.u.old)
  =/  old-skip=(qeu take:fiber:nexus)  ?~(old ~ skip.u.old)
  =/  merged-skip=(qeu take:fiber:nexus)
    (~(gas to old-skip) ~(tap to old-next))
  =.  this  (store-proc here [&+process ~ merged-skip])
  (enqu-take here (sys-give /start) ~)
::
++  default-spool
  ^-  spool:fiber:nexus
  |=  prod:fiber:nexus
  stay:(fiber:fiber:nexus ,~)
::
++  process-take
  |=  [here=rail:tarball =take:fiber:nexus]
  ^+  this
  ::  Get pipe at directory
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  ::  Get proc for this file - must exist
  =/  prc=(unit proc:fiber:nexus)  (~(get by proc.pipe) name.here)
  ?~  prc  this
  =/  =proc:fiber:nexus  u.prc
  ::  Crashed process — nack pokes immediately, queue everything else
  ?:  ?=(%| -.process.proc)
    ?:  ?=([* ~ %poke *] take)
      (give-poke-sign here [take `p.process.proc])
    =.  proc  proc(next (~(put to next.proc) take))
    (store-proc here proc)
  ::  Add take to queue, store, and run
  =.  proc  proc(next (~(put to next.proc) take))
  =.  this  (store-proc here proc)
  (process-do-next here)
::
++  process-do-next
  |=  here=rail:tarball
  ^+  this
  ::  Get proc from pool
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  =proc:fiber:nexus  (~(got by proc.pipe) name.here)
  ::  Crashed process — takes accumulate in next, don't evaluate
  ?:  ?=(%| -.process.proc)  this
  ::  Get file state from ball
  =/  file-data=(unit content:tarball)
    (~(get ba:tarball ball) path.here name.here)
  ?~  file-data  this  :: file doesn't exist
  =/  fil-state=vase  q.sage.u.file-data
  ::  Build bowl for this process (with filtered wex/sup)
  ::  Run the evaluator (mule to catch hard crashes like !< mismatches)
  =/  eval-res=(each [darts=(list dart:nexus) done=(list took:eval:fiber:nexus) new-state=vase new-proc=proc:fiber:nexus res=result:eval:fiber:nexus] tang)
    (mule |.((take:eval:fiber:nexus fil-state proc)))
  ?:  ?=(%| -.eval-res)
    ~&  >>  "process-take: eval crashed, banging {(spud (snoc path.here name.here))}"
    (bang-file here p.eval-res)
  =/  [darts=(list dart:nexus) done=(list took:eval:fiber:nexus) new-state=vase new-proc=proc:fiber:nexus res=result:eval:fiber:nexus]
    p.eval-res
  ::  Process darts (emit cards or enqueue takes)
  =.  this  (process-darts here darts)
  ::  Ack consumed pokes
  =.  this  (give-poke-signs here done)
  ::  Validate new state before handling result (runtime, no force)
  ::  ~&  >  "process-result: validate-new-sage for %{(trip p.sage.u.file-data)} at {(spud (snoc path.here name.here))}"
  =/  validated=(each vase tang)
    (validate-new-sage path.here p.sage.u.file-data `fil-state new-state %.n)
  ?:  ?=(%| -.validated)
    ::  Validation failed - bang the file (don't restart, infra is broken)
    ~&  >>  "process-take: validation failed, bang {(spud (snoc path.here name.here))}"
    (bang-file here p.validated)
  ::  Validation passed - handle result normally
  ?-    -.res
      %next
    ::  Save state (bumps aeon only if content changed)
    =.  this  (save-file here [metadata.u.file-data p.sage.u.file-data p.validated])
    (store-proc here new-proc)
      %done
    ::  Save final state so subscribers see it, then delete
    =.  this  (save-file here [metadata.u.file-data p.sage.u.file-data p.validated])
    =/  err=tang  ~[leaf+"process completed"]
    :: only nack-pokes when we're done
    ::
    =.  this  (nack-poke-takes here next.new-proc err)
    =.  this  (nack-poke-takes here skip.new-proc err)
    =.  this  (clean (snoc path.here name.here) %file)
    (delete path.here name.here)
      %fail
    ::  Process failed - don't save state, restart. Subs survive (wires still route).
    ::  Sync queues (consumed takes removed), rebuild process, enqueue
    ::  rise via abet. Same pattern as spawn-proc.
    ?:  (is-nexus-banged here)  this
    =.  this  (bump-proc here %.y)
    =/  spool-res=(each spool:fiber:nexus tang)
      (mule |.((fall (build-spool here) default-spool)))
    ?:  ?=(%| -.spool-res)
      (bang-file here p.spool-res)
    =/  proc-res=(each process:fiber:nexus tang)
      (mule |.((p.spool-res [%rise err.res])))
    ?:  ?=(%| -.proc-res)
      (bang-file here p.proc-res)
    =/  merged-skip=(qeu take:fiber:nexus)
      (~(gas to skip.new-proc) ~(tap to next.new-proc))
    =.  this  (store-proc here [&+p.proc-res ~ merged-skip])
    (enqu-take here (sys-give /rise) ~)
  ==
::
++  poke
  |=  [=give:nexus here=rail:tarball =sage:tarball]
  ^+  this
  =/  rel-from=from:fiber:nexus  (relativize-from:nexus here from.give)
  (enqu-take here give ~ %poke rel-from sage)
::
++  make
  |=  [dest=lane:tarball =make:nexus]
  ^+  this
  ?-    -.dest
      %|
    ::  Make directory - payload must be [sand gain ball]
    ?>  ?=(%& -.make)
    =/  dest-path=fold:tarball  p.dest
    =/  new-sand=sand:nexus  sand.p.make
    =/  new-gain=gain:nexus  gain.p.make
    =/  new-ball=ball:tarball  ball.p.make
    ::  Assert nothing exists at path
    =/  existing=ball:tarball  (~(dip ba:tarball ball) dest-path)
    ?:  |(?=(^ fil.existing) !=(~ dir.existing))
      ~|("path is not empty" !!)
    ::  Put new sand, gain, and ball at path
    =.  sand  (put-sub-sand sand dest-path new-sand)
    =.  gain  (put-sub-gain gain dest-path new-gain)
    =.  ball  (~(pub ba:tarball ball) dest-path new-ball)
    ::  Run on-loads top-down (may modify sand, ball, and gain)
    =/  [rol-sand=sand:nexus rol-gain=gain:nexus rol-ball=ball:tarball]
      (run-on-loads dest-path new-sand new-gain new-ball)
    =:  new-sand  rol-sand
        new-gain  rol-gain
        new-ball  rol-ball
    ==
    ::  Validate all cages in loaded ball
    =/  validated=ball:tarball  ~|(%validate-ball-make (validate-ball dest-path new-ball))
    ::  Put the final sand, gain, and ball back
    =.  sand  (put-sub-sand sand dest-path new-sand)
    =.  gain  (put-sub-gain gain dest-path new-gain)
    ::  Sync all changes (old is empty) and spawn processes
    =.  this  (load-ball-changes dest-path *ball:tarball validated)
    ::  Register and build any code namespaces in the new ball
    =.  this  (build-new-code-namespaces dest-path validated)
    (spawn-all-files dest-path validated)
    ::
      %&
    ::  Make file - payload must be cage
    ?>  ?=(%| -.make)
    =/  dest-rail=rail:tarball  p.dest
    ::  Assert file doesn't already exist
    =/  existing-file=(unit content:tarball)
      (~(get ba:tarball ball) path.dest-rail name.dest-rail)
    ?^  existing-file
      ~|("file already exists at path" !!)
    ::  Validate the cage before storing (new file, no old content)
    ::  ~&  >  "process-make: validate-new-sage for %{(trip p.sage.p.make)} at {(spud (snoc path.dest-rail name.dest-rail))}"
    =/  validated=(each vase tang)
      (validate-new-sage path.dest-rail p.sage.p.make ~ q.sage.p.make %.n)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  Record gain flag if set
    =?  this  gain.p.make
      =.  gain  (set-gain dest-rail %.y)
      this
    ::  Save initial state (bumps file aeon since old content is ~)
    =.  this  (save-file dest-rail [~ p.sage.p.make p.validated])
    ::  Spawn process (needs file in ball for build-spool)
    ::  bump-proc for immediate notify (spawn-proc is quiet)
    =.  this  (spawn-proc dest-rail [%make ~])
    (bump-proc dest-rail %.y)
  ==
::
++  cull
  |=  dest=lane:tarball
  ^+  this
  ?-    -.dest
      %|
    ::  Cull directory - delete entire subtree
    =/  dest-path=fold:tarball  p.dest
    =/  sub=ball:tarball  (~(dip ba:tarball ball) dest-path)
    ::  Remove from ball BEFORE notify so subscribers see deletion
    =.  ball  (~(lop ba:tarball ball) dest-path)
    ::  Bump all changes and notify
    =.  this  (cull-ball-changes dest-path sub)
    ::  Nack all queued pokes in subtree
    =.  this  (nack-pool dest-path (~(dip of pool) dest-path) ~[leaf+"culled"])
    ::  Clean gall subscriptions for subtree
    =.  this  (clean dest-path %tree)
    ::  Remove from pool
    =.  pool  (~(lop of pool) dest-path)
    this
    ::
      %&
    ::  Cull file - delete single file
    =/  dest-rail=rail:tarball  p.dest
    =/  dest-path=path  (rail-to-path:tarball dest-rail)
    ::  Nack queued pokes for this file
    =.  this  (nack-pool dest-path (~(dip of pool) dest-path) ~[leaf+"culled"])
    ::  Clean subscriptions for this file
    =.  this  (clean dest-path %file)
    ::  Bump and remove from pool and ball
    (delete path.dest-rail name.dest-rail)
  ==
::  Walk two sand trees and bump weir cass in born for changed weirs
::
++  bump-weir-changes
  |=  [here=fold:tarball old=sand:nexus new=sand:nexus]
  ^+  this
  =?  this  !=(fil.old fil.new)
    =/  old-born=born:nexus  born
    =.  born  (~(bump-weir bo:nexus now.bowl [born ball]) here)
    (notify old-born)
  =/  all-kids=(list @ta)
    ~(tap in (~(uni in ~(key by dir.old)) ~(key by dir.new)))
  |-
  ?~  all-kids  this
  =/  kid-old=sand:nexus  (fall (~(get by dir.old) i.all-kids) *sand:nexus)
  =/  kid-new=sand:nexus  (fall (~(get by dir.new) i.all-kids) *sand:nexus)
  =.  this  ^$(here (snoc here i.all-kids), old kid-old, new kid-new)
  $(all-kids t.all-kids)
::
++  set-weir
  |=  [dest=path weir=(unit weir:nexus)]
  ^+  this
  ?>  ?=(^ dest)  :: root should always have system access
  =/  old-sand=sand:nexus  sand
  =.  sand  ?~(weir (~(del of sand) dest) (~(put of sand) dest u.weir))
  ?:  =(old-sand sand)  this
  ::  Bump weir cass in born for this directory
  =/  old-born=born:nexus  born
  =.  born  (~(bump-weir bo:nexus now.bowl [born ball]) dest)
  =.  this  (notify old-born)
  ::  Re-check subscriptions from watchers under this weir
  (audit-weir dest)
::  Walk up from a grub's rail, revealing path segments while allowed.
::  Pant is in path order (outermost-first).
::
++  walk-here
  |=  here=rail:tarball
  ^-  here:nexus
  =/  remaining=path  path.here
  =|  =pant:nexus
  |-
  ?~  remaining
    ::  At root — check if allowed to peek root
    =/  =filt:nexus  (allowed %peek here `[%| /])
    [pant name.here !?=([~ %|] filt)]
  =/  ancestor=path  (snip `path`remaining)
  =/  dir=@ta  (rear remaining)
  ::  Can this grub peek this ancestor directory?
  =/  =filt:nexus  (allowed %peek here `[%| remaining])
  ?:  ?=([~ %|] filt)
    ::  Blocked — return what we have so far
    [pant name.here %.n]
  ::  Allowed — look up neck from ball's lump at this path
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball ball) remaining)
  =/  neck=(unit neck:tarball)
    ?~  sub  ~
    ?~  fil.u.sub  ~
    neck.u.fil.u.sub
  $(remaining ancestor, pant [[dir neck] pant])
::
++  make-soup
  |=  here=rail:tarball
  ^-  soup:nexus
  =/  here-path=path  (snoc path.here name.here)
  =/  filtered-wex=boat:gall
    %-  ~(gas by *boat:gall)
    %+  murn  ~(tap by wex.bowl)
    |=  [[=wire =ship =term] acked=? =path]
    ?.  ?=([%proc @ *] wire)  ~
    =/  [proc-rail=rail:tarball @ orig-wire=^wire]  (unwrap-wire wire)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
    ?.  =(proc-path here-path)  ~
    [~ [orig-wire ship term] acked path]
  =/  filtered-sup=bitt:gall
    %-  ~(gas by *bitt:gall)
    %+  murn  ~(tap by sup.bowl)
    |=  [=duct =ship =path]
    ?.  ?=([%proc @ *] path)  ~
    =/  [proc-rail=rail:tarball sub=^path]  (unwrap-watch-path path)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
    ?.  =(proc-path here-path)  ~
    [~ duct ship sub]
  [filtered-wex filtered-sup]
::  Sandboxing / weir filtering
::
::  The "governor" is the nearest directory strictly ABOVE both source
::  and destination - the neutral authority that rules over both.
::  We walk up from here TO the governor, checking weirs at each step,
::  but don't check the governor's weir (we reach it, not pass through).
::  Downward movement from the governor to dest is always free.
::
::  For syscalls (dest=~), there is no governor - walk all the way up.
::
++  nearest-governor
  |=  [here=rail:tarball dest=(unit lane:tarball)]
  ^-  (unit fold:tarball)
  ?~  dest  ~  :: syscall - no governor
  ?-    -.u.dest
      ::  File destination: governor is just the common prefix.
      %&
    [~ (prefix:tarball path.here path.p.u.dest)]
      ::  Directory destination: governor must be strictly above both.
      ::
      %|
    =/  pref=fold:tarball  (prefix:tarball path.here p.u.dest)
    ?:  &(!=(pref path.here) !=(pref p.u.dest))
      [~ pref]
    ?~  pref
      [~ ~]
    [~ (snip `fold:tarball`pref)]
  ==
::
++  allowed
  |=  [=jump:nexus here=rail:tarball dest=(unit lane:tarball)]
  ^-  filt:nexus
  =/  gov=(unit fold:tarball)  (nearest-governor here dest)
  ::  For syscalls, use root as dummy dest (syscalls get blocked by any weir anyway)
  =/  dest-lane=lane:tarball  (fall dest [%| /])
  =|  =filt:nexus
  |-
  ::  Reached governor - stop (don't check its weir)
  ?:  &(?=(^ gov) =(path.here u.gov))
    filt
  ::  Check weir at current location
  =/  weir-here  (~(get of sand) path.here)
  =/  next=filt:nexus
    (next-filt:nexus filt (filter:nexus jump path.here dest-lane weir-here))
  ?:  ?=([~ %|] next)
    [~ |]
  ::  Reached root - stop (handles syscalls which have no governor)
  ?~  path.here
    next
  $(filt next, path.here (snip `fold:tarball`path.here))
::  =born: Thin wrappers around ++bo in lib/nexus.hoon
::  See ++bo for documentation of semantics and invariants.
::
++  get-born
  |=  here=rail:tarball
  ^-  (unit sack:nexus)
  (~(get bo:nexus now.bowl [born ball]) here)
::
++  get-dir-cass
  |=  dir=fold:tarball
  ^-  (unit cass:clay)
  (~(get-dir-cass bo:nexus now.bowl [born ball]) dir)
::
++  init-born
  |=  here=rail:tarball
  ^+  this
  this(born (~(init bo:nexus now.bowl [born ball]) here))
::
++  bump-proc
  |=  [here=rail:tarball loud=?]
  ^+  this
  =/  old-born=born:nexus  born
  =.  born  (~(bump-proc bo:nexus now.bowl [born ball]) here)
  ?.  loud  this
  (notify old-born)
::
++  bump-file
  |=  here=rail:tarball
  ^+  this
  =/  old-born=born:nexus  born
  =.  born  (~(bump-file bo:nexus now.bowl [born ball]) here)
  (notify old-born)
::  Record bask in silo and append to hist on sack.
::
++  record-hist
  |=  [here=rail:tarball =sage:tarball cas=(unit cass:clay)]
  ^+  this
  =/  sok=sack:nexus  (need (get-born here))
  ::  Use provided cass or compute next from current file cass
  =/  new-cass=cass:clay
    (fall cas (~(next-cass bo:nexus now.bowl [born ball]) file.sok))
  =/  gaining=?  (lookup-gain here)
  =/  =bask:tarball  [p q.q]:sage
  =/  [=lobe:clay new-silo=silo:nexus new-hist=_hist.sok]
    (~(record si:nexus silo) bask new-cass gaining file.sok hist.sok)
  =.  silo  new-silo
  =.  born  (~(put bo:nexus now.bowl [born ball]) here sok(hist new-hist))
  this
::  Diff two balls and bump all changes (new, changed, deleted files and empty dirs).
::
++  diff-balls
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  this(born (~(diff-balls bo:nexus now.bowl [born ball]) here old-ball new-ball))
::  Spawn processes and sync all changes when a ball is created/reloaded.
::  Handles spawning files and bumping all changes (new, changed, deleted files, empty dirs).
::
++  load-ball-changes
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  ::  Write new sub-ball into main ball
  =.  ball  (~(pub ba:tarball ball) here new-ball)
  =/  old-born=born:nexus  born
  ::  diff-balls (inits/bumps born), record silo/hist, then notify
  =.  this  (diff-balls here old-ball new-ball)
  =.  this  (record-ball-changes here old-ball new-ball)
  (notify old-born)
::  Bump all changes when a ball is being deleted.
::  Diff old ball against empty ball to bump all files and empty dirs.
::
++  cull-ball-changes
  |=  [here=fold:tarball sub=ball:tarball]
  ^+  this
  =/  old-born=born:nexus  born
  =.  this  (diff-balls here sub *ball:tarball)
  =.  this  (record-ball-changes here sub *ball:tarball)
  (notify old-born)
::  Walk old/new balls and record silo/hist for new/changed files,
::  drop silo refs for deleted files.
::
++  record-ball-changes
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  =/  old-files=(map @ta content:tarball)
    ?~(fil.old-ball ~ contents.u.fil.old-ball)
  =/  new-files=(map @ta content:tarball)
    ?~(fil.new-ball ~ contents.u.fil.new-ball)
  =/  old-names=(set @ta)  ~(key by old-files)
  =/  new-names=(set @ta)  ~(key by new-files)
  =/  all-names=(list @ta)  ~(tap in (~(uni in old-names) new-names))
  =.  this
    |-
    ?~  all-names  this
    =/  name=@ta  i.all-names
    =/  in-old=?  (~(has in old-names) name)
    =/  in-new=?  (~(has in new-names) name)
    =.  this
      ?:  &(in-new !in-old)
        ::  New file: record in silo/hist (born already init'd by diff-balls)
        =/  sok=sack:nexus  (need (get-born [here name]))
        (record-hist [here name] sage:(~(got by new-files) name) `file.sok)
      ?:  &(in-old !in-new)
        ::  Deleted file: drop silo refs
        =/  sok=(unit sack:nexus)  (get-born [here name])
        =?  silo  ?=(^ sok)
          (~(drop-hist si:nexus silo) hist.u.sok)
        this
      ::  Both: record if changed
      =/  old-content=content:tarball  (~(got by old-files) name)
      =/  new-content=content:tarball  (~(got by new-files) name)
      ?.  =(sage.old-content sage.new-content)
        =/  sok=sack:nexus  (need (get-born [here name]))
        (record-hist [here name] sage.new-content `file.sok)
      this
    $(all-names t.all-names)
  ::  Recurse into subdirs
  =/  all-kids=(set @ta)
    (~(uni in ~(key by dir.old-ball)) ~(key by dir.new-ball))
  =/  kids=(list @ta)  ~(tap in all-kids)
  |-
  ?~  kids  this
  =/  old-kid=ball:tarball  (fall (~(get by dir.old-ball) i.kids) *ball:tarball)
  =/  new-kid=ball:tarball  (fall (~(get by dir.new-ball) i.kids) *ball:tarball)
  =.  this  ^$(here (snoc here i.kids), old-ball old-kid, new-ball new-kid)
  $(kids t.kids)
::  Mirror Clay desks to /sys/clay/[desk]/
::
++  sync-clay
  ^+  this
  ~&  >>  "sync-clay: start"
  ::  Ensure /sys/clay directory exists
  =?  ball  =(~ (~(get of ball) /sys/clay))
    (~(put of ball) /sys/clay [~ ~ ~])
  ::  Ensure default desks have directories
  =?  ball  =(~ (~(get of ball) /sys/clay/base))
    (~(put of ball) /sys/clay/base [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /sys/clay/grubbery))
    (~(put of ball) /sys/clay/grubbery [~ ~ ~])
  ::  Sync all desks listed as kids of /sys/clay/
  =/  dek=(list desk)  (~(lss ba:tarball ball) /sys/clay)
  |-  ^+  this
  ?~  dek  this
  $(dek t.dek, this (sync-clay-desk i.dek))
::
++  sync-clay-desk
  |=  dek=desk
  ^+  this
  =/  base=path  /sys/clay/[dek]
  =/  pax=path   /(scot %p our.bowl)/[dek]/(scot %da now.bowl)
  ::  Scry for all file paths in desk
  ::  Each path is like /app/foo/hoon where last element is mark
  =/  files=(list path)  .^((list path) %ct pax)
  ::  Get current files in tarball at this desk's mirror path
  =/  old-files=(set path)
    %-  silt
    (list-clay-files base)
  ::  Capture born before sync for change detection (grubbery desk)
  =/  pre-born=born:nexus  born
  ::  Save each Clay file into tarball
  =/  new-files=(set path)  (silt files)
  =.  this
    %+  roll  files
    |=  [fyl=path acc=_this]
    ^+  acc
    ?.  ?=([@ @ *] fyl)  acc
    =/  mar=@tas   (rear fyl)
    =/  sans=path  (snip `(list @ta)`fyl)
    =/  stem=@ta   (rear sans)
    =/  dir=path   (weld base (snip `(list @ta)`sans))
    =/  name=@ta   (cat 3 stem (cat 3 '.' mar))
    =/  new-vase=vase  .^(vase %cr (weld pax fyl))
    =/  old=(unit content:tarball)
      (~(get ba:tarball ball.acc) [dir name])
    =/  vale=(unit $-(* vase))
      ?:  ?=(?(%hoon %mime %kelvin) mar)
        =/  dais=(unit dais:clay)
          (mole |.(.^(dais:clay %cb (weld pax `path`/[mar]))))
        ?~  dais  ~
        `vale:u.dais
      =/  =blot:tarball  [/ mar]
      =/  res=(unit built:nexus)  (get-built / (weld /mar path.blot) name.blot)
      ?~  res  ~
      ?.  ?=(%vase -.u.res)  ~
      (mole |.(vale:!<(marc:tarball vase.u.res)))
    ?~  vale
      ~&  [%sync-clay-skip-no-mark mar fyl]
      acc
    =/  old-vase=(unit vase)  ?~(old ~ `q.sage.u.old)
    =/  res=(each vase tang)
      (validate-vase:acc u.vale old-vase new-vase %.n)
    ?.  ?=(%& -.res)
      ~&  [%sync-clay-vale-failed mar fyl]
      acc
    (save-file:acc [dir name] [~ [/ mar] p.res])
  ::  Delete files that no longer exist in Clay
  =/  removed=(list path)
    %+  skim  ~(tap in old-files)
    |=(p=path !(~(has in new-files) p))
  =.  this
    %+  roll  removed
    |=  [fyl=path acc=_this]
    ?.  ?=([@ @ *] fyl)  acc
    =/  mar=@tas   (rear fyl)
    =/  sans=path  (snip `(list @ta)`fyl)
    =/  stem=@ta   (rear sans)
    =/  dir=path   (weld base (snip `(list @ta)`sans))
    =/  name=@ta   (cat 3 stem (cat 3 '.' mar))
    (delete:acc dir name)
  ::  Subscribe to %next %z on desk root
  ~&  >>  "sync-clay-desk: subscribing to {<dek>}"
  %-  emit-card
  [%pass /clay-desk/[dek] %arvo %c %warp our.bowl dek `[%next %z da+now.bowl /]]
::  React to any change under a code nexus.
::  Enforces: src/ is hoon-only, bin/ is build-managed.
::  Triggers rebuild when src/ changes.
::  Walk a newly created ball and build-code for any %code neck directories.
::
++  build-new-code-namespaces
  |=  [here=fold:tarball bol=ball:tarball]
  ^+  this
  ::  check if this directory has a %code neck
  ?:  ?&  ?=(^ fil.bol)
          ?=(^ neck.u.fil.bol)
          =([/ %code] u.neck.u.fil.bol)
      ==
    ::  skip if already registered and built
    ?:  (~(has by code) here)  this
    ::  register and build
    ~&  >  "register-code-namespace: {(spud here)}"
    (build-code here)
  ::  recurse into children
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.bol)
  |-
  ?~  kids  this
  =.  this  ^$(here (snoc here -.i.kids), bol +.i.kids)
  $(kids t.kids)
::
::  Compile a code nexus into its lode in the code map.
::  Purges non-hoon files from the code nexus.
::
++  build-code
  |=  cod=path
  ^+  this
  ~&  >  "build-code: start {(spud cod)}"
  =/  src-ball=ball:tarball  (~(dip ba:tarball ball) cod)
  ::  Separate hoon and non-hoon files
  =/  all-files=(list [=rail:tarball =content:tarball])
    ~(tap ba:tarball src-ball)
  ~&  >  "build-code: {<(lent all-files)>} files"
  =/  hoon-ball=ball:tarball
    %+  roll  all-files
    |=  [[=rail:tarball =content:tarball] acc=_src-ball]
    ?.  =(p.sage.content %hoon)
      (~(del ba:tarball acc) path.rail name.rail)
    acc
  =/  mime-files=(list [=rail:tarball =content:tarball])
    (skim all-files |=([* =content:tarball] =([/ %mime] p.sage.content)))
  ::  Check kelvin compatibility
  =/  kel-content=(unit content:tarball)
    (~(get ba:tarball src-ball) [/ %'sys.kelvin'])
  ~&  >  "build-code: kelvin file {?~(kel-content "missing" "found")}"
  =/  kel-ok=?
    ?~  kel-content
      ~&  >  "build-code: no sys.kelvin, skipping check"
      %.y
    ~&  >  "build-code: sys.kelvin mark={<p.sage.u.kel-content>}"
    ~&  >  "build-code: sys.kelvin type={<p.q.sage.u.kel-content>}"
    =/  waft-res=(each waft:clay tang)
      (mule |.(!<(waft:clay q.sage.u.kel-content)))
    ?:  ?=(%| -.waft-res)
      ~&  >>>  "build-code: failed to extract waft from sys.kelvin"
      ~&  >>>  p.waft-res
      %.y
    =/  wefts=(set weft)  (waft-to-wefts:clay p.waft-res)
    ~&  >  "build-code: wefts={<wefts>} checking for [%grubbery {<kel>}]"
    =/  ok=?  (~(has in wefts) [%grubbery kel])
    ~&  >  "build-code: kelvin ok={<ok>}"
    ok
  ::  Ensure %code neck on code nexus directory
  =/  code-lump=lump:tarball
    (fall (~(get of ball) cod) *lump:tarball)
  =.  ball  (~(put of ball) cod code-lump(neck `[/ %code]))
  ::  Get or create lode for this code nexus
  =/  =lode:nexus  (fall (~(get by code) cod) *lode:nexus)
  =/  old-bins=bins:nexus  bins.lode
  ::  Kelvin mismatch: every file becomes a crash
  ?.  kel-ok
    ~&  >>>  "build-code: kelvin mismatch in {(spud cod)}"
    =/  =waft:clay  !<(waft:clay q.sage:(need kel-content))
    =/  err=tang
      :~  leaf+"incompatible kelvin: {(spud cod)}"
          leaf+"  code nexus declares: {<(waft-to-wefts:clay waft)>}"
          leaf+"  grubbery expects: [%grubbery {<kel>}]"
      ==
    ~&  >>>  "build-code: building tang bins for {<(lent all-files)>} files"
    =/  hoon-count=@ud  0
    =/  new-bins=bins:nexus
      %+  roll  all-files
      |=  [[=rail:tarball =content:tarball] acc=bins:nexus]
      ?.  =([/ %hoon] p.sage.content)  acc
      =/  stem=@ta  (strip-hoon:build name.rail)
      =/  node=(map @ta built:nexus)
        (fall (~(get of acc) path.rail) *(map @ta built:nexus))
      (~(put of acc) path.rail (~(put by node) stem [%tang err]))
    ~&  >>>  "build-code: tang bins built"
    =.  lode  [~ ~ new-bins]
    =.  code  (~(put by code) cod lode)
    ~&  >>>  "build-code: kelvin mismatch done, returning"
    this
  ::  Reconstruct cache from bins + keys
  =/  old-cache=build-cache:build  (bins-to-cache:build bins.lode keys.lode)
  ~&  >  "build-code: compiling..."
  ::  Single compilation pass: marks, libs, nexuses (hoon only)
  =/  res=build-out:build  (build-all:build sut src-ball old-cache)
  ~&  >  "build-code: compiled {<~(wyt by results.res)>} results"
  ::  Build bins axal from results + mime files
  ::  Seed bins with mime files
  =/  new-bins=bins:nexus
    %+  roll  mime-files
    |=  [[=rail:tarball =content:tarball] acc=bins:nexus]
    =/  =mime  !<(mime q.sage.content)
    =/  node=(map @ta built:nexus)
      (fall (~(get of acc) path.rail) *(map @ta built:nexus))
    (~(put of acc) path.rail (~(put by node) name.rail [%mime mime]))
  ::  Add compiled hoon results
  =.  new-bins
    %+  roll  ~(tap by results.res)
    |=  [[=rail:tarball =build-result:build] acc=_new-bins]
    =/  stem=@ta  (strip-hoon:build name.rail)
    =/  =built:nexus
      ?:  ?=(%| -.build-result)
        ~&  >>>  "build-code: FAILED {(spud (snoc path.rail name.rail))}"
        %-  (slog (flop p.build-result))
        [%tang p.build-result]
      =/  val-err=(unit tang)  (validate-build rail p.build-result)
      ?^  val-err
        ~&  >>  "validate-build failed: {(spud (snoc path.rail name.rail))}"
        [%tang u.val-err]
      [%vase p.build-result]
    =/  node=(map @ta built:nexus)
      (fall (~(get of acc) path.rail) *(map @ta built:nexus))
    (~(put of acc) path.rail (~(put by node) stem built))
  ::  Update build state
  ::  Note: /mar entries in results are already marcs (built in build.hoon)
  ~&  >  "build-code: updating lode"
  =/  old-keys=keys:nexus  keys.lode
  =.  lode  [keys.res deps.res new-bins]
  =.  code  (~(put by code) cod lode)
  ::  Validate marks: clam existing grubs through changed marks
  ~&  >  "build-code: validate-marks"
  =^  new-bins  this  (validate-marks cod old-bins new-bins)
  =/  upd-lode=lode:nexus  (fall (~(get by code) cod) *lode:nexus)
  =.  code  (~(put by code) cod upd-lode(bins new-bins))
  ::  Reload nexuses whose compiled code changed
  ~&  >  "build-code: reload-changed-nexuses"
  =.  this  (reload-changed-nexuses cod old-keys keys.res old-bins new-bins)
  ~&  >  "build-code: done"
  this
::  Validate marks: for each changed mark in bin/mar/, build a vale gate
::  Walk ball under a code namespace, pruning at child code namespaces.
::  Returns all [fold lump] pairs governed by this code namespace —
::  i.e. under scope but not under a deeper code namespace.
::
++  governed-dirs
  |=  cod=path
  ^-  (list [=fold:tarball =lump:tarball])
  =/  scope=path  (snip `(list @ta)`cod)
  =/  sub=ball:tarball  (~(dip ba:tarball ball) scope)
  =/  out=(list [=fold:tarball =lump:tarball])  ~
  =|  here=path
  |-
  ::  Check if any child is a code namespace — if so, this directory
  ::  is another code namespace's scope, not ours. Prune entirely.
  ::  Exception: here=~ is our own scope (we expect our own /code child).
  =/  has-child-code=?
    %+  lien  ~(tap by dir.sub)
    |=  [name=@ta kid=ball:tarball]
    ?&(=(%code name) ?=(^ fil.kid) ?=(^ neck.u.fil.kid) =([/ %code] u.neck.u.fil.kid))
  ::  Collect this node if it has a lump
  =?  out  ?=(^ fil.sub)
    [[(weld scope here) u.fil.sub] out]
  ::  Child code namespace means everything below is governed by it, not us.
  ::  Collect the node but don't descend. Exception: here=~ is our own scope.
  ?:  ?&(has-child-code !=(here ~))
    out
  ::  Descend into children, skipping the code directory itself
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub)
  |-
  ?~  kids  out
  =/  [name=@ta kid=ball:tarball]  i.kids
  =?  out  !=(name %code)
    ^$(here (snoc here name), sub kid)
  $(kids t.kids)
::  Walk ball under a code namespace, collecting all files governed by it.
::  Prunes at child code namespaces.
::
++  governed-files
  |=  cod=path
  ^-  (list [=rail:tarball =content:tarball])
  =/  dirs=(list [=fold:tarball =lump:tarball])  (governed-dirs cod)
  %-  zing
  %+  turn  dirs
  |=  [=fold:tarball =lump:tarball]
  %+  turn  ~(tap by contents.lump)
  |=  [name=@ta =content:tarball]
  [[fold name] content]
::  and clam all grubs with that mark through validate-vase.
::  On success, updates grubs in ball with clammed vases.
::  On failure, downgrades the mark to .tang in new-bin.
::
++  validate-marks
  |=  [cod=path old-bins=bins:nexus new-bins=bins:nexus]
  ^+  [new-bins this]
  ::  Walk /mar subtree to find all [blot built] pairs
  =/  mar-sub=bins:nexus  (~(dip of new-bins) /mar)
  =/  old-sub=bins:nexus  (~(dip of old-bins) /mar)
  =/  all-new=(list [pax=path node=(map @ta built:nexus)])
    ~(tap of mar-sub)
  ::  Find changed blots (any change — vase, tang, etc)
  =/  changed=(list [=blot:tarball =built:nexus])
    %-  zing
    %+  turn  all-new
    |=  [pax=path node=(map @ta built:nexus)]
    %+  murn  ~(tap by node)
    |=  [nam=@ta =built:nexus]
    =/  old-node=(map @ta built:nexus)
      (fall (~(get of old-sub) pax) *(map @ta built:nexus))
    =/  old=(unit built:nexus)  (~(get by old-node) nam)
    ?:  =(old `built)  ~
    `[[pax nam] built]
  ::  Process each changed mark
  =/  remaining=_changed  changed
  |-
  ?~  remaining  [new-bins this]
  =/  [=blot:tarball =built:nexus]  i.remaining
  =/  nam=@tas  (rail-to-arm:tarball blot)
  ::  Find all grubs with this mark, including booms with matching inner mark
  =/  grubs=(list [=rail:tarball =content:tarball])
    %+  skim  (governed-files cod)
    |=  [=rail:tarball =content:tarball]
    ?:  =(name.blot name.p.sage.content)  &
    ?.  =([/ %boom] p.sage.content)  |
    =/  [* inner=bask:tarball]  ;;([tang bask:tarball] q.q.sage.content)
    =(name.blot name.p.inner)
  ?~  grubs  $(remaining t.remaining)
  ::  Get vale gate, or a crash gate if mark failed to compile
  =/  vale=$-(* vase)
    ?.  ?=(%vase -.built)
      |=(* (mean ?:(?=(%tang -.built) tang.built ~[leaf+"validate-marks: {(trip nam)} failed"])))
    =/  marc-res=(each marc:tarball tang)
      (mule |.(!<(marc:tarball vase.built)))
    ?:(?=(%| -.marc-res) |=(* (mean p.marc-res)) vale.p.marc-res)
  ::  Clam each grub; success restores cage, failure booms
  =/  results=(list [=rail:tarball =content:tarball res=(each vase tang)])
    %+  turn  grubs
    |=  [=rail:tarball =content:tarball]
    =/  noun=*
      ?:  =([/ %boom] p.sage.content)
        =/  [* =bask:tarball]  ;;([tang bask:tarball] q.q.sage.content)
        q.bask
      q.q.sage.content
    =/  new=(each vase tang)  (mule |.((vale noun)))
    ?:  ?=(%| -.new)  [rail content new]
    [rail content (validate-vase vale `q.sage.content p.new %.n)]
  =.  this
    %+  roll  results
    |=  [[=rail:tarball =content:tarball res=(each vase tang)] acc=_this]
    ?:  ?=(%& -.res)
      (save-file:acc rail content(sage [p.sage.content p.res]))
    ~&  >>  "validate-marks: boom {(spud (snoc path.rail name.rail))}"
    =/  noun=*
      ?:  =([/ %boom] p.sage.content)
        =/  [* =bask:tarball]  ;;([tang bask:tarball] q.q.sage.content)
        q.bask
      q.q.sage.content
    (save-file:acc rail content(sage [[/ %boom] !>([p.res [blot noun]])]))
  =/  n-boom=@ud
    (lent (skim results |=([* * res=(each vase tang)] ?=(%| -.res))))
  ~&  >  "validate-marks: {(trip nam)} — {<(sub (lent grubs) n-boom)>} ok, {<n-boom>} boom"
  $(remaining t.remaining)
::  Reload nexuses: for each changed nexus in bin/nex/, find all
::  directories using that neck, run on-load with the new code, and
::  apply the results (like reload-nexus). Crashes if any on-load fails.
::
++  reload-changed-nexuses
  |=  [cod=path old-keys=keys:nexus new-keys=keys:nexus old-bins=bins:nexus new-bins=bins:nexus]
  ^+  this
  ::  Find nexuses in /nex whose content hash changed
  =/  nex-sub=bins:nexus  (~(dip of new-bins) /nex)
  =/  old-sub=bins:nexus  (~(dip of old-bins) /nex)
  =/  all-new=(list [pax=path node=(map @ta built:nexus)])
    ~(tap of nex-sub)
  =/  changed=(list [=neck:tarball =built:nexus])
    %-  zing
    %+  turn  all-new
    |=  [pax=path node=(map @ta built:nexus)]
    %+  murn  ~(tap by node)
    |=  [nam=@ta =built:nexus]
    =/  =rail:tarball  [(weld /nex pax) nam]
    =/  key-rail=rail:tarball  [path.rail (cat 3 nam '.hoon')]
    =/  old-key=(unit @uv)  (~(get by old-keys) key-rail)
    =/  new-key=(unit @uv)  (~(get by new-keys) key-rail)
    =/  old-node=(map @ta built:nexus)
      (fall (~(get of old-sub) pax) *(map @ta built:nexus))
    =/  old-built=(unit built:nexus)  (~(get by old-node) nam)
    ::  same key = no change (but ~ = ~ means "both missing", not "same")
    ?:  ?&  =(old-key new-key)
            ?=(^ old-key)
        ==
      ~
    `[[pax nam] built]
  ::  Process each changed nexus
  =/  remaining=_changed  changed
  |-
  ?~  remaining  this
  =/  [=neck:tarball =built:nexus]  i.remaining
  ::  Extract nexus or propagate error
  =/  nex-res=(each nexus:nexus tang)
    ?+  -.built  |+~[leaf+"reload-changed-nexuses: unexpected built type {<-.built>}"]
      %tang  |+tang.built
      %vase  (mule |.(!<(nexus:nexus vase.built)))
    ==
  ::  Find all directories using this neck, governed by this code namespace
  =/  dirs=(list fold:tarball)
    %+  murn  (governed-dirs cod)
    |=  [=fold:tarball =lump:tarball]
    ?.  ?&(?=(^ neck.lump) =(u.neck.lump neck))  ~
    `fold
  ?~  dirs  $(remaining t.remaining)
  ::  Run on-load and apply results for each directory
  ::  (reload-nexus-at handles bang/clear internally)
  =/  dir-remaining=(list fold:tarball)  dirs
  |-
  ?~  dir-remaining  ^$(remaining t.remaining)
  =/  dest=fold:tarball  i.dir-remaining
  ?:  ?=(%| -.nex-res)
    ~&  >>  "reload-changed-nexuses: bang {(spud (weld path.neck ~[name.neck]))} at {(spud dest)}"
    =.  this  (bang-nexus dest p.nex-res)
    $(dir-remaining t.dir-remaining)
  ~&  >  "reload-changed-nexuses: reloading {(spud (weld path.neck ~[name.neck]))} at {(spud dest)}"
  =.  this  (reload-nexus-at dest p.nex-res)
  =.  this  (spawn-all-files dest (~(dip ba:tarball ball) dest))
  $(dir-remaining t.dir-remaining)
::  Validate a compiled artifact based on its source path.
::
::  Returns ~ if valid, (unit tang) if the artifact doesn't match
::  the expected type for its location:
::    mar/*        — mark door (has +grab, +grow)
::    nex/*        — nexus:nexus
::
++  validate-build
  |=  [=rail:tarball =vase]
  ^-  (unit tang)
  =/  dir=path  path.rail
  ::  Marks: validated by build-marc after compilation, not here.
  ::  Cached entries are marcs (not raw doors), so slob won't find arms.
  ?:  =(/mar (scag 1 dir))  ~
  ?:  =(/nex (scag 1 dir))
    =/  res=(each nexus:nexus tang)
      (mule |.(!<(nexus:nexus vase)))
    ?:(?=(%& -.res) ~ `(weld ~[leaf+"nexus {(trip name.rail)}: type mismatch"] p.res))
  ::  No validation for other paths (e.g. lib/*.hoon)
  ~
::  Mirror /gub/ from Clay into /code/, then build.
::
++  sync-gub
  ^+  this
  ~&  >  "sync-gub: start"
  =/  pax=path  /(scot %p our.bowl)/grubbery/(scot %da now.bowl)
  ::  Build the target ball for /code/
  =/  files=(list path)  .^((list path) %ct (weld pax /gub))
  =/  new-src=ball:tarball
    %+  roll  files
    |=  [fyl=path acc=ball:tarball]
    ?.  ?=([@ @ @ *] fyl)  acc
    =/  mar=@tas   (rear fyl)
    =/  sans=path  (snip `(list @ta)`fyl)
    =/  stem=@ta   (rear sans)
    =/  rel-dir=path  (slag 1 (snip `(list @ta)`sans))
    =/  name=@ta   (cat 3 stem (cat 3 '.' mar))
    ::  sys.kelvin: store as kelvin mark at root
    ?:  =(%'sys.kelvin' name)
      =/  =vase  .^(vase %cr (weld pax fyl))
      =/  =waft:clay  ;;(waft:clay q.vase)
      (~(put ba:tarball acc) [/ %'sys.kelvin'] [~ [/ %kelvin] !>(waft)])
    ?:  =(mar %hoon)
      =/  =vase  .^(vase %cr (weld pax fyl))
      =/  val=(each ^vase tang)  (validate-new-sage /code [/ mar] ~ vase %.y)
      ?.  ?=(%& -.val)
        ~&  >>>  "sync-gub: validation failed for {(trip name)}: {(trip (render-tang:build p.val))}"
        acc
      (~(put ba:tarball acc) [rel-dir name] [~ [/ mar] p.val])
    ::  Non-hoon: convert to mime via tube, store as %mime grub
    =/  =vase  .^(vase %cr (weld pax fyl))
    =/  tub=tube:clay  .^(tube:clay %cc (weld pax /[mar]/mime))
    =/  =mime  !<(mime (tub vase))
    (~(put ba:tarball acc) [rel-dir name] [~ [/ %mime] !>(mime)])
  ::  Get old ball at /code/
  =/  old-src=ball:tarball  (~(dip ba:tarball ball) /code)
  ::  Diff and bump src changes (born, silo, hist, notify)
  ~&  >  "sync-gub: load-ball-changes start"
  =.  this  (load-ball-changes /code old-src new-src)
  ~&  >  "sync-gub: load-ball-changes done"
  ::  Compile
  ~&  >  "sync-gub: build-code start"
  =/  res=_this  (build-code /code)
  ~&  >  "sync-gub: build-code done"
  res
::  List all files mirrored under a /sys/clay/[desk] path
::  Returns Clay-style paths (like /app/foo/hoon) with mark as last element
::
++  list-clay-files
  |=  base=path
  ^-  (list path)
  =/  sub=ball:tarball  (~(dip ba:tarball ball) base)
  (ball-to-paths / sub)
::
++  ball-to-paths
  |=  [prefix=path bal=ball:tarball]
  ^-  (list path)
  =/  files=(list path)
    ?~  fil.bal  ~
    %+  turn  ~(tap by contents.u.fil.bal)
    |=  [name=@ta =content:tarball]
    ::  Reconstruct Clay path from dotted name: foo.hoon -> /prefix/foo/hoon
    =/  parts=(list @ta)  (split-dot name)
    ?~  parts  (snoc prefix name)
    (weld (snoc prefix i.parts) t.parts)
  =/  kids=(list path)
    %-  zing
    %+  turn  ~(tap by dir.bal)
    |=  [name=@ta sub=ball:tarball]
    ^$(prefix (snoc prefix name), bal sub)
  (weld files kids)
::  Split a @ta on the last dot: foo.hoon -> [foo /hoon]
::
++  split-dot
  |=  name=@ta
  ^-  (list @ta)
  =/  t=tape  (trip name)
  =/  idx=(unit @ud)
    =/  i=@ud  (lent t)
    |-  ^-  (unit @ud)
    ?:  =(0 i)  ~
    =.  i  (dec i)
    ?:  =('.' (snag i t))  `i
    $
  ?~  idx  ~[name]
  =/  pre=tape  (scag u.idx t)
  =/  suf=tape  (slag +(u.idx) t)
  ?:  |(=(~ pre) =(~ suf))  ~[name]
  ~[(crip pre) (crip suf)]
::  Handle %writ from Clay desk subscription
::
++  on-clay-writ
  |=  [dek=desk =riot:clay]
  ^+  this
  ?~  riot
    ::  Desk was deleted — unsub, remove mirror
    ~&  >>  "on-clay-writ: desk deleted {<dek>}"
    (unmount-clay-desk dek)
  ::  Desk changed — re-sync files and re-subscribe
  ~&  >>  "on-clay-writ: desk changed {<dek>}"
  =.  this  (sync-clay-desk dek)
  =?  this  =(dek %grubbery)
    ~&  >>  "on-clay-writ: triggering sync-gub"
    sync-gub
  this
::
++  unmount-clay-desk
  |=  dek=desk
  ^+  this
  =.  this  (emit-card [%pass /clay-desk/[dek] %arvo %c %warp our.bowl dek ~])
  (cull [%| /sys/clay/[dek]])
::  Subscribe to dill logs and sessions, create grubs for both.
::
++  sync-dill
  ^+  this
  ::  Create dill/logs grub and subscribe
  =.  this  (save-file [/sys/dill %'logs.dill-told'] [~ [/ %dill-told] !>(*told:dill)])
  =.  gain  (set-gain [/sys/dill %'logs.dill-told'] %.y)
  =.  this  (emit-card [%pass /dill/logs %arvo %d %logs `~])
  ::  Scry for sessions
  =/  sessions=(list @tas)
    ~(tap in .^((set @tas) %dy /(scot %p our.bowl)/$/(scot %da now.bowl)/sessions))
  ::  Unsubscribe from sessions no longer in dill
  =/  old=(list @ta)  (~(lis ba:tarball ball) /sys/dill/sessions)
  =/  new=(set @tas)  (~(gas in *(set @tas)) sessions)
  =.  this
    %-  emit-cards
    %+  murn  old
    |=  ses=@ta
    ?:  (~(has in new) ses)  ~
    `[%pass /dill/session/[ses] %arvo %d %shot ses %flee ~]
  ::  Create grubs and subscribe, with gain enabled
  =.  this
    %+  roll  sessions
    |=  [ses=@tas acc=_this]
    =.  gain.acc  (set-gain:acc [/sys/dill/sessions ses] %.y)
    (save-file:acc [/sys/dill/sessions ses] [~ [/ %dill-blit] !>(*(list blit:dill))])
  %-  emit-cards
  %+  turn  sessions
  |=(ses=@tas [%pass /dill/session/[ses] %arvo %d %shot ses %view ~])
::
++  sync-jael
  ^+  this
  ::  Create jael directory
  =?  ball  =(~ (~(get of ball) /sys/jael))
    (~(put of ball) /sys/jael [~ ~ ~])
  ::  Create grubs and subscribe
  =.  this
    (save-file [/sys/jael %'private-keys.jael-private-keys'] [~ [/ %jael-private-keys] !>(*[life (map life ring)])])
  =.  gain  (set-gain [/sys/jael %'private-keys.jael-private-keys'] %.y)
  =.  this
    (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [~ [/ %jael-public-keys-result] !>(*public-keys-result:jael)])
  =.  gain  (set-gain [/sys/jael %'public-keys.jael-public-keys-result'] %.y)
  ::  Subscribe to private keys
  =.  this
    (emit-card [%pass /jael/private %arvo %j %private-keys ~])
  ::  Subscribe to public keys for our ship
  %-  emit-cards
  ~[[%pass /jael/public %arvo %j %public-keys (silt ~[our.bowl])]]
::
++  on-jael-public
  |=  =public-keys-result:jael
  ^+  this
  (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [~ [/ %jael-public-keys-result] !>(public-keys-result)])
::  Save file state and bump ONLY if content actually changed.
::  This is the ONLY correct way to update file state.
::  Invariant: file aeon changes iff file content changes.
::
++  save-file
  |=  [here=rail:tarball new-content=content:tarball]
  ^+  this
  ::  Init born if needed
  =.  this  ?^((get-born here) this (init-born here))
  ::  Only bump if content actually changed
  =/  old=(unit content:tarball)  (~(get ba:tarball ball) here)
  =.  ball  (~(put ba:tarball ball) here new-content)
  ?:  ?&  ?=(^ old)
          =(sage.u.old sage.new-content)
      ==
    this
  ::  Record content in silo and hist
  =.  this  (record-hist here sage.new-content ~)
  =.  this  (bump-file here)
  ::  Rebuild if change is inside a code nexus
  =/  cod=(unit path)
    =+  pax=path.here
    |-  ?:  (~(has by code) pax)  `pax
    ?~  pax  ~
    $(pax (snip `path`pax))
  ?~  cod  this
  ~&  >>>  "save-file: triggering build-code from {(spud (snoc path.here name.here))}"
  (build-code u.cod)
::
++  wrap-wire
  |=  [here=rail:tarball =wire]
  ^+  wire
  =/  =sack:nexus  (need (get-born here))
  =/  here-path=path  (snoc path.here name.here)
  ;:  weld
    /proc/(scot %ud (lent here-path))
    here-path
    /(scot %ud ud.life.sack)
    wire
  ==
::
++  unwrap-wire
  |=  =wire
  ^-  [rail:tarball @ud ^wire]
  ?>  ?=([%proc @ *] wire)
  =/  len=@ud  (slav %ud i.t.wire)
  =/  here-path=path  (scag len t.t.wire)
  ?>  ?=(^ here-path)
  =/  here=rail:tarball  [(snip `path`here-path) (rear here-path)]
  =/  rest=^wire  (slag len t.t.wire)
  ?>  ?=(^ rest)
  =/  lif=@ud  (slav %ud i.rest)
  [here lif t.rest]
::
++  take-arvo
  |=  [wir=wire sign=sign-arvo]
  ^+  this
  =/  [here=rail:tarball lif=@ud =wire]  (unwrap-wire wir)
  =/  cur=(unit sack:nexus)  (get-born here)
  ?.  ?&(?=(^ cur) =(lif ud.life.u.cur))  this
  (enqu-take here (sys-give /arvo) ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=rail:tarball lif=@ud =wire]  (unwrap-wire wir)
  =/  cur=(unit sack:nexus)  (get-born here)
  ?.  ?&(?=(^ cur) =(lif ud.life.u.cur))  this
  (enqu-take here (sys-give /agent) ~ %agent wire sign)
::  Unwrap incoming watch/leave paths
::
++  unwrap-watch-path
  |=  pat=path
  ^-  [rail:tarball path]
  ?>  ?=([%proc @ *] pat)
  =/  len=@ud  (slav %ud i.t.pat)
  =/  here-path  (scag len t.t.pat)
  ?>  ?=(^ here-path)
  =/  here=rail:tarball  [(snip `(list @ta)`here-path) (rear here-path)]
  [here (slag len t.t.pat)]
::
++  wrap-watch-path
  |=  [here=rail:tarball =path]
  ^+  path
  =/  here-path=^path  (snoc path.here name.here)
  (weld /proc/(scot %ud (lent here-path)) (weld here-path path))
::
++  take-watch
  |=  pat=path
  ^+  this
  =/  [here=rail:tarball sub=path]  (unwrap-watch-path pat)
  (enqu-take here (sys-give /watch) ~ %watch sub)
::
++  take-leave
  |=  pat=path
  ^+  this
  =/  [here=rail:tarball sub=path]  (unwrap-watch-path pat)
  (enqu-take here (sys-give /leave) ~ %leave sub)
--
