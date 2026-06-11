/-  spider, push
/+  default-agent, dbug, tarball, nexus,
    server, multipart, http-utils, html-utils, json-utils,
    marks, build, fiberio, loader, cram, pretty-file, zlib, bytestream, root,
    web-push
/=  t-  /tests/nexus
/=  t-  /tests/tarball
/=  t-  /tests/build
/=  t-  /tests/loader
/=  m-  /mar/kids
/=  m-  /mar/tree
/=  m-  /mar/born
/=  m-  /mar/subs
/=  m-  /mar/grubbery-load
/=  m-  /mar/grubbery-transfer
/=  m-  /mar/grubbery-intake
|%
+$  versioned-state
  $%  state-0
  ==
+$  card  card:agent:gall
+$  state-0
  $:  %0
      =born:nexus
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      afar=(map @p born:nexus)
      =peeks:remote:nexus
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
            bytestream=bytestream
            zlib=zlib
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
  ::  Seed bootstrap marcs into bins before any code compilation
  =^  bootstrap-cards  state  abet:bootstrap-marcs:hc
  ::  Bootstrap root tree with /code namespace stub.
  ::  Must run BEFORE sync-gub so sync-gub fills /code rather than
  ::  the root bole stomping /code's files after the fact.
  =/  root-bole=bole:tarball
    :-  `[`[/ %root] ~ %.n ~]
    (malt ~[[%code [`[`[/ %code] ~ %.n ~] ~]]])
  =^  root-tree-cards  state
    abet:(load-ball-changes:hc / root-bole)
  ::  Compile code from Clay — fills /code with sources and compiles
  =^  gub-cards  state  abet:sync-gub:hc
  ::  Reload root nexus (after code compile so child nexuses can build)
  =^  root-cards  state  abet:(reload-nexus-at:hc / root)
  ::  Purge stale code namespaces, then register new ones
  =^  purge-cards  state  abet:purge-stale-code:hc
  =^  code-cards  state  abet:(build-new-code-namespaces:hc / (peek-bole-now:hc /))
  =^  spawn-cards  state  abet:(spawn-all-files:hc / (peek-bole-now:hc /))
  =^  dill-cards  state  abet:sync-dill:hc
  =^  clay-cards  state  abet:sync-clay:hc
  =^  jael-cards  state  abet:sync-jael:hc
  =^  bowl-cards  state  abet:sync-bowl:hc
  =^  peer-cards  state  abet:sync-peer:hc
  =^  gall-cards  state  abet:sync-gall:hc
  =^  eyre-cards  state  abet:sync-eyre:hc
  =^  push-cards  state  abet:sync-push:hc
  :_  this
  ;:  weld
    bootstrap-cards
    root-tree-cards
    root-cards
    purge-cards
    code-cards
    spawn-cards
    gub-cards
    dill-cards
    clay-cards
    jael-cards
    bowl-cards
    peer-cards
    gall-cards
    eyre-cards
    push-cards
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
    ::  Seed bootstrap marcs into bins
    =^  bootstrap-cards  state  abet:bootstrap-marcs:hc
    ::  Compile code from Clay (cascades nexus on-loads)
    =^  gub-cards    state  abet:sync-gub:hc
    ::  Reload root nexus (hardcoded — runs on every app reload, after code compile)
    =^  root-cards   state  abet:(reload-nexus-at:hc / root)
    ::  Purge stale code namespaces, then register new ones
    =^  purge-cards  state  abet:purge-stale-code:hc
    =^  code-cards   state  abet:(build-new-code-namespaces:hc / (peek-bole-now:hc /))
    =^  spawn-cards  state  abet:(spawn-all-files:hc / (peek-bole-now:hc /))
    =^  dill-cards   state  abet:sync-dill:hc
    =^  clay-cards   state  abet:sync-clay:hc
    =^  jael-cards   state  abet:sync-jael:hc
    =^  bowl-cards   state  abet:sync-bowl:hc
    =^  peer-cards   state  abet:sync-peer:hc
    =^  gall-cards   state  abet:sync-gall:hc
    =^  eyre-cards   state  abet:sync-eyre:hc
    =^  push-cards   state  abet:sync-push:hc
    :_  this
    ;:  weld
      bootstrap-cards
      root-cards
      purge-cards
      code-cards
      spawn-cards
      gub-cards
      dill-cards
      clay-cards
      jael-cards
      bowl-cards
      peer-cards
      gall-cards
      eyre-cards
      push-cards
      cards
    ==
  ==
::
++  on-poke
  |=  [mak=mark vas=vase]
  ^-  (quip card _this)
  ?+    mak  (on-poke:def mak vas)
      %grubbery-load
    =+  !<(req=load:remote:nexus vas)
    ::  All actions route through /sys/ames/ships/[src]/ as a dart
    ::  from ship.sig.  Our ship has no weir (full access); foreign
    ::  ships get weir from usergroups.
    =/  ship-ta=@ta  (scot %p src.bowl)
    =^  peer-cards  state
      abet:(ensure-peer-ship:hc src.bowl)
    =/  ship-rail=rail:tarball  [/sys/ames/ships/[ship-ta] %'ship.sig']
    ~&  >  [%grubbery-load +<.req src=src.bowl]
    ?:  ?=(%peek +<.req)
      =/  dest-lane=lane:tarball  dest.req
      ::  Weir gate: simulate dart traversal from ship-rail to dest
      ?:  ?=([~ %|] (allowed:hc %peek ship-rail `dest-lane))
        ~&  >>  [%peek-vetoed src=src.bowl dest=dest-lane]
        :_  this  peer-cards
      =/  snap=(unit snap:remote:nexus)
        =/  pace=(unit pace:hist:nexus)
          ?-  -.dest-lane
              %&
            =/  r=rail:tarball  p.dest-lane
            =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
              (~(get of born) path.r)
            ?~  node  ~
            =/  sk=hist:nexus
              (fall (~(get by file.u.node) name.r) *hist:nexus)
            ?~  case.req
              =/  cas=(unit cass:clay)  (top:hist:nexus sk)
              ?~  cas  ~
              (get:hon:hist:nexus sk u.cas)
            `(resolve-case:nexus u.case.req sk)
              %|
            =/  dest=fold:tarball  p.dest-lane
            =/  sub-born=born:nexus  (~(dip of born) dest)
            ?~  fil.sub-born  ~
            =/  sk=hist:nexus  fold.u.fil.sub-born
            ?~  case.req
              =/  cas=(unit cass:clay)  (top:hist:nexus sk)
              ?~  cas  ~
              (get:hon:hist:nexus sk u.cas)
            `(resolve-case:nexus u.case.req sk)
          ==
        ?~  pace  ~
        =/  refs=(set lobe:clay)
          ?:  ?=(%tomb -.u.pace)  ~
          ?~  p.u.pace  ~
          ?:  deep.req
            (~(reachable si:nexus silo) u.p.u.pace)
          (~(reachable-shallow si:nexus silo) u.p.u.pace)
        `[u.pace refs]
      ~&  >  [%peek-resolved snap=?~(snap %none -.pace.u.snap) refs=?~(snap 0 ~(wyt in refs.u.snap))]
      =/  resp=transfer:remote:nexus
        [wire.req %snap dest-lane snap]
      :_  this
      %+  weld  peer-cards
      ^-  (list card)
      :~  [%pass /peek/[(scot %p src.bowl)] %agent [src.bowl %grubbery] %poke grubbery-transfer+!>(resp)]
      ==
    ?:  ?=(%keep +<.req)
      ::  Remote subscribe: register src as watcher via ship.sig rail
      ~&  >  [%keep-received-from src.bowl dest=dest.req]
      ::  Weir gate: simulate dart traversal from ship-rail to dest
      ?:  ?=([~ %|] (allowed:hc %peek ship-rail `dest.req))
        ~&  >>  [%keep-vetoed src=src.bowl dest=dest.req]
        :_  this  peer-cards
      =/  watcher=rail:tarball  [/sys/ames/ships/[ship-ta] %'ship.sig']
      =^  cards  state
        abet:(keep:hc watcher dest.req wire.req)
      [(weld peer-cards cards) this]
    ?:  ?=(%drop +<.req)
      ::  Remote unsubscribe: remove src as watcher
      ~&  >  [%drop-received-from src.bowl dest=dest.req]
      =/  watcher=rail:tarball  [/sys/ames/ships/[ship-ta] %'ship.sig']
      =^  cards  state
        abet:(drop:hc watcher dest.req)
      [(weld peer-cards cards) this]
    ::  All other actions route through dart system
    =/  =load:nexus
      ?-  +<.req
        %poke  [%poke bask.req]
        %over  [%over bask.req]
          %make
        [%make ?:(?=(%& -.make.req) &+(ball-to-bole:tarball p.make.req) make.req)]
        %cull  [%cull ~]
        %sand  [%sand weir.req]
        %load  [%load ~]
      ==
    =/  =dart:nexus  [%node /peer [%& dest.req] load]
    =^  dart-cards  state
      abet:(process-dart:hc ship-rail dart)
    [(weld peer-cards dart-cards) this]
    ::
      %grubbery-transfer
    ::  Runtime-to-runtime content-addressed negotiation.
    ::  Separate from grubbery-load (dart-like operations).
    =+  !<(req=transfer:remote:nexus vas)
    =/  ship-ta=@ta  (scot %p src.bowl)
    =^  peer-cards  state
      abet:(ensure-peer-ship:hc src.bowl)
    =/  ship-rail=rail:tarball  [/sys/ames/ships/[ship-ta] %'ship.sig']
    ~&  >  [%grubbery-transfer +<.req src=src.bowl]
    ?:  ?=(?(%snap %data) +<.req)
      ::  Inbound snap/data: process locally (no auth needed, we requested it)
      =^  cards  state
        abet:(process-transfer:hc src.bowl req)
      [(weld peer-cards cards) this]
    ::  %want: inbound content request — weir gate + containment
    ?>  ?=(%want +<.req)
    ~&  >  [%want-received-from src.bowl dest=dest.req haves=~(wyt in haves.req)]
    ::  Weir gate: simulate dart traversal from ship-rail to dest
    ?:  ?=([~ %|] (allowed:hc %peek ship-rail `dest.req))
      ~&  >>  [%want-vetoed src=src.bowl dest=dest.req]
      :_  this  peer-cards
    ::  Containment: resolve refs at dest, only serve lobes reachable there
    =/  allowed-refs=(set lobe:clay)
      =/  pace=(unit pace:hist:nexus)
        ?-  -.dest.req
            %&
          =/  r=rail:tarball  p.dest.req
          =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
            (~(get of born) path.r)
          ?~  node  ~
          =/  sk=hist:nexus
            (fall (~(get by file.u.node) name.r) *hist:nexus)
          =/  cas=(unit cass:clay)  (top:hist:nexus sk)
          ?~  cas  ~
          (get:hon:hist:nexus sk u.cas)
            %|
          =/  dest=fold:tarball  p.dest.req
          =/  sub-born=born:nexus  (~(dip of born) dest)
          ?~  fil.sub-born  ~
          =/  sk=hist:nexus  fold.u.fil.sub-born
          =/  cas=(unit cass:clay)  (top:hist:nexus sk)
          ?~  cas  ~
          (get:hon:hist:nexus sk u.cas)
        ==
      ?~  pace  ~
      ?:  ?=(%tomb -.u.pace)  ~
      ?~  p.u.pace  ~
      (~(reachable si:nexus silo) u.p.u.pace)
    ::  Only serve lobes that are actually at the claimed dest
    =/  send=silo:nexus
      =/  wanted=(list lobe:clay)
        ~(tap in (~(int in haves.req) allowed-refs))
      =/  acc=silo:nexus  *silo:nexus
      |-
      ?~  wanted  acc
      =/  cur=lobe:clay  i.wanted
      =/  jot  (~(get by jects.silo) cur)
      ?^  jot
        $(wanted t.wanted, acc acc(jects (~(put by jects.acc) cur [0 ject.u.jot])))
      =/  got  (~(get by nouns.silo) cur)
      ?~  got  $(wanted t.wanted)
      $(wanted t.wanted, acc acc(nouns (~(put by nouns.acc) cur [0 noun.u.got])))
    ~&  >  [%want-sending nouns=~(wyt by nouns.send) jects=~(wyt by jects.send)]
    =/  resp=transfer:remote:nexus
      [/want %data send]
    ~&  >  [%want-responding-with-data nouns=~(wyt by nouns.send) jects=~(wyt by jects.send) to=src.bowl]
    :_  this
    %+  weld  peer-cards
    ^-  (list card)
    :~  [%pass /want/[(scot %p src.bowl)] %agent [src.bowl %grubbery] %poke grubbery-transfer+!>(resp)]
    ==
    ::
      %grubbery-intake
    ~&  >  [%grubbery-intake-raw src=src.bowl]
    =+  !<(resp=intake:remote:nexus vas)
    ~&  >  [%grubbery-intake +<.resp src=src.bowl]
    =^  cards  state
      abet:(process-intake:hc src.bowl resp)
    [cards this]
    ::  HTTP request from eyre: route directly
    ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vas)
    =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
    ::  Push notification endpoints
    ?:  ?=([%grubbery %push *] site)
      =^  cards  state
        abet:(handle-push-http:hc eyre-id src.bowl req t.t.site args)
      [cards this]
    ::  Ball API: spawn request fiber at /sys/eyre/requests/{eyre-id}
    ?:  ?=([%grubbery %api *] site)
      ~&  >  [%eyre-api eyre-id url.request.req ~(wyt by nouns.silo) ~(wyt by jects.silo)]
      =^  cards  state
        abet:(make:hc [%& /sys/eyre/requests eyre-id] [%| [[/ %http-request] [src.bowl req]] ~])
      [cards this]
    ::  Binding match: find handler, forward request
    =/  st=server-state:nexus  get-server-state:hc
    =/  match=(unit [=binding:eyre handler=rail:tarball])
      (find-eyre-binding:hc bindings.st site)
    ?~  match
      ~&  >  [%eyre-no-binding site]
      :_  this
      (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
    ~&  >  [%eyre-dispatch binding.u.match handler.u.match]
    =/  =give:nexus  [|+[src.bowl /eyre] /[eyre-id]]
    =/  new-st  st(conns (~(put by conns.st) eyre-id binding.u.match))
    =^  cards  state
      abet:(poke:(save-server-state:hc new-st) give handler.u.match [[/ %handle-http-request] !>([eyre-id src.bowl req])])
    [cards this]
      ::
      %refresh-sessions
    ::  Scry for dill sessions, sync subscriptions and grubs
    ?>  =(src our):bowl
    =^  cards  state
      abet:sync-dill:hc
    [cards this]
      ::
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
      ::
      %gall-watch
    ::  Subscribe to a gall agent, materialize at /sys/gall/
    ?>  =(src our):bowl
    =+  !<([=ship agent=dude:gall =path] vas)
    =^  cards  state
      abet:(gall-sub:hc ship agent path)
    [cards this]
      ::
      %gall-leave
    ::  Unsubscribe from a materialized gall subscription
    ?>  =(src our):bowl
    =+  !<([=ship agent=dude:gall =path] vas)
    =^  cards  state
      abet:(gall-unsub:hc ship agent path)
    [cards this]
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
    ?:  =(~ jael-source)  (on-watch:def path)
    =^  cards  state  abet:(serve-jael:hc ~)
    [cards this]
      ::  Jael subscribes on /(scot %p ship) for per-ship udiffs
      [@ ~]
    ?:  =(~ jael-source)  (on-watch:def path)
    =^  cards  state  abet:(serve-jael:hc path)
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
    =/  st=server-state:nexus  get-server-state:hc
    =/  conn-binding=(unit binding:eyre)  (~(get by conns.st) eyre-id)
    ::  No binding = ball API request — cull request fiber
    ?~  conn-binding
      =^  cards  state
        abet:(cull-if-exists:hc [%& /sys/eyre/requests eyre-id])
      [cards this]
    ::  Bound request — update conns, forward cancel to handler
    =/  new-st  st(conns (~(del by conns.st) eyre-id))
    =/  handler=rail:tarball
      (fall (~(get by bindings.new-st) u.conn-binding) *rail:tarball)
    =/  =give:nexus  [|+[our.bowl /eyre] /cancel/[eyre-id]]
    =^  cards  state
      abet:(poke:(save-server-state:hc new-st) give handler [[/ %handle-http-cancel] !>(eyre-id)])
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
    =/  content=(unit sang:tarball)  (peek-grub-now dir name)
    ?~  content
      [~ ~]
    ``[name.p.u.content (need-vase:tarball u.content)]
    ::
      [%x %peek %kids *]
    ::  File names at path
    =/  here=^path  t.t.t.path
    ``kids+!>((lis-born here))
    ::
      [%x %peek %subs *]
    ::  Subdirectory names at path
    =/  here=^path  t.t.t.path
    ``kids+!>((lss-born here))
    ::
      [%x %peek %tree *]
    ::  Tree structure with marks, no content
    =/  here=^path  t.t.t.path
    =/  sub=ball:tarball  (peek-ball-now here)
    ``tree+!>((ball-to-tree:tarball sub))
    ::
    ::
      [%x %peek %born *]
    ::  Born (version tracking) subtree
    =/  here=^path  t.t.t.path
    ``born+!>((~(dip of born) here))
    ::
      [%x %peek %silo %lobe @ ~]
    ::  Look up noun in silo by lobe hash
    =/  =lobe:clay  (slav %uv i.t.t.t.t.path)
    =/  got=(unit noun)  (~(get si:nexus silo) lobe)
    ?~  got  [~ ~]
    ``%noun^!>(u.got)
    ::
      [%x %peek %subs ~]
    ::  Internal subscriptions
    ``subs+!>(subs)
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?:  ?=([%gall-poke *] wire)
    ?>  ?=(%poke-ack -.sign)
    =^  cards  state
      abet:(take-gall-poke:hc t.wire sign)
    [cards this]
  ?:  ?=([%gall-sub *] wire)
    =^  cards  state
      abet:(take-gall-sub:hc t.wire sign)
    [cards this]
  ::  TODO: handle %poke-ack failures on these wires — on nack,
  ::  clean up staged peeks/subs and notify grub of failure.
  ::  Currently success acks are fine to ignore (real response
  ::  comes as a separate poke), but error acks leave state dangling.
  ?:  ?=(?([%peek *] [%want *] [%keep *] [%drop *] [%wave *]) wire)
    `this
  ~&  >>>  "on-agent: unhandled wire {<wire>}"
  `this
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%dill %logs ~] wire)
    ?>  ?=([%dill %logs *] sign)
    =^  cards  state
      abet:(save-file:hc [/sys/dill %'logs.dill-told'] [[/ %dill-told] %& !>(told.sign)])
    [cards this]
  ?:  ?=([%dill %session @ ~] wire)
    ?>  ?=([%dill %blit *] sign)
    =/  ses=@tas  i.t.t.wire
    =^  cards  state
      abet:(save-file:hc [/sys/dill/sessions ses] [[/ %dill-blit] %& !>(p.sign)])
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
      abet:(save-file:hc [/sys/jael %'private-keys.jael-private-keys'] [[/ %jael-private-keys] %& !>([life.sign vein.sign])])
    [cards this]
  ?:  ?=([%behn %timer @ *] wire)
    ?>  ?=([%behn %wake *] sign)
    =^  cards  state
      abet:(handle-timer-wake:hc t.t.wire error.sign)
    [cards this]
  ?:  ?=([%iris %request @ *] wire)
    ?>  ?=([%iris %http-response *] sign)
    =^  cards  state
      abet:(handle-iris-response:hc t.t.wire client-response.sign)
    [cards this]
  ?:  ?=([%push %send @ *] wire)
    ?>  ?=([%iris %http-response *] sign)
    =^  cards  state
      abet:(handle-push-response:hc t.t.wire client-response.sign)
    [cards this]
  ?:  ?=(?([%eyre ~] [%eyre-bind ~] [%eyre-api ~] [%eyre-push ~]) wire)
    `this
  ~&  >>>  "on-arvo: unhandled wire {<wire>}"
  `this
::
++  on-fail   on-fail:def
--
::  helper core for routing events to processes
::
=|  cards=(list card)
=|  takes=(qeu take:nexus)
|_  =bowl:gall
+*  this  .
::  +put-pace: write a pace into a born tree at the given dest lane.
::  Used to record remote peek results into afar.
::
++  put-pace
  |=  [=born:nexus dest=lane:tarball =pace:hist:nexus]
  ^-  born:nexus
  ?-  -.dest
      %&
    =/  r=rail:tarball  p.dest
    =/  node=[fold=hist:nexus file=(map @ta hist:nexus)]
      (fall (~(get of born) path.r) default-node:~(. bo:nexus now.bowl born))
    =/  sk=hist:nexus  (fall (~(get by file.node) name.r) *hist:nexus)
    =/  top-cas=(unit cass:clay)  (top:hist:nexus sk)
    =/  next-ud=@ud  ?~(top-cas 1 +(ud.u.top-cas))
    =/  cas=cass:clay  [next-ud now.bowl]
    =/  new-hist=hist:nexus  (put:hon:hist:nexus sk cas pace)
    (~(put of born) path.r node(file (~(put by file.node) name.r new-hist)))
      %|
    =/  dir=path  p.dest
    =/  node=[fold=hist:nexus file=(map @ta hist:nexus)]
      (fall (~(get of born) dir) default-node:~(. bo:nexus now.bowl born))
    =/  top-cas=(unit cass:clay)  (top:hist:nexus fold.node)
    =/  next-ud=@ud  ?~(top-cas 1 +(ud.u.top-cas))
    =/  cas=cass:clay  [next-ud now.bowl]
    =/  new-fold=hist:nexus  (put:hon:hist:nexus fold.node cas pace)
    (~(put of born) dir node(fold new-fold))
  ==
::  +record-afar: write a pace into afar for a remote ship.
::  Records what we know about the remote ship's state at a path.
::  This is pure data — independent of who asked for it.
::
++  record-afar
  |=  [ship=@p dest=lane:tarball snap=(unit snap:remote:nexus)]
  ^+  afar
  ?~  snap  afar  :: nothing to record
  =/  remote-born=born:nexus
    (fall (~(get by afar) ship) *born:nexus)
  (~(put by afar) ship (put-pace remote-born dest pace.u.snap))
::  +discharge-peeks: sweep staged peeks, discharge any whose refs
::  are fully present in the local silo. Discharge means the grub
::  can now read the content it asked for — notify and remove.
::  afar is already populated by %snap; this is purely about
::  peek fulfillment.
::
++  discharge-peeks
  ^+  this
  =/  entries=(list [[=rail:tarball =wire] =peek:remote:nexus])
    ~(tap by peeks)
  =/  have=(set lobe:clay)
    (~(uni in ~(key by jects.silo)) ~(key by nouns.silo))
  |-
  ?~  entries  this
  =/  [key=[=rail:tarball =wire] pk=peek:remote:nexus]  i.entries
  ?~  snap.pk
    ::  Still waiting for %snap — skip
    $(entries t.entries)
  =/  missing=(set lobe:clay)
    (~(dif in refs.u.snap.pk) have)
  ?.  =(~ missing)
    ::  Not all refs present yet — skip
    $(entries t.entries)
  ::  All refs present — discharge: build view from afar+silo,
  ::  send %peek intake to the requesting fiber.
  ~&  >  [%peek-discharged ship.pk dest.pk key=key peeks-remaining=~(wyt by peeks)]
  =/  remote-born=born:nexus
    (fall (~(get by afar) ship.pk) *born:nexus)
  =/  =seen:nexus
    ?-  -.dest.pk
        %|
      ::  Directory: build ball+born from remote born subtree
      =/  dest=fold:tarball  p.dest.pk
      =/  sub-born=born:nexus  (~(dip of remote-born) dest)
      =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
        (~(get of remote-born) dest)
      ?~  node  &+[%none ~]
      =/  got=(unit [key=cass:clay val=pace:hist:nexus])
        (ram:hon:hist:nexus fold.u.node)
      ?~  got  &+[%none ~]
      =/  =pace:hist:nexus  val.u.got
      ?:  ?=(%tomb -.pace)  &+[%none ~]
      ?~  p.pace  &+[%none ~]
      =/  sub-ball
        ?:  deep.pk
          (peek-ball u.p.pace)
        (peek-ball-shallow u.p.pace)
      &+[%ball sub-born sub-ball]
        %&
      ::  File: read content from silo via pace
      =/  r=rail:tarball  p.dest.pk
      ?:  ?=(%tomb -.pace.u.snap.pk)  &+[%none ~]
      ?~  p.pace.u.snap.pk  &+[%none ~]
      =/  jot  (~(get by jects.silo) u.p.pace.u.snap.pk)
      ?~  jot  &+[%none ~]
      =/  jt=ject:nexus  ject.u.jot
      ?.  ?=(%leaf -.jt)  &+[%none ~]
      =/  got=(unit noun)  (~(get si:nexus silo) lobe.leaf.jt)
      ?~  got  &+[%none ~]
      =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
        (~(get of remote-born) path.r)
      =/  sk=hist:nexus
        ?~  node  *hist:nexus
        (fall (~(get by file.u.node) name.r) *hist:nexus)
      ::  TODO: apply blot conversion here once discharge has cod access
      &+[%file sk [blot.mark.leaf.jt %| [~ u.got]]]
    ==
  =.  this  (enqu-take rail.key (sys-give /peek) ~ %peek wire.key seen)
  =.  peeks  (~(del by peeks) key)
  $(entries t.entries)
::  +process-intake: handle inbound cross-ship responses.
::  +keep: register a remote watcher and send initial wave.
::  Called when a remote ship sends %keep load.
::
++  keep
  |=  [watcher=rail:tarball target=lane:tarball =wire]
  ^+  this
  =.  this  (sub-put target watcher wire ~)
  =/  =wave:nexus
    %-  relativize-wave:nexus
    [target (wave-from-born:nexus born (~(put in *(set lane:tarball)) target))]
  =/  resp=intake:remote:nexus
    [wire %bond target wave]
  =.  cards
    :_  cards
    =/  dest=@p  (slav %p (snag 3 path.watcher))
    [%pass /keep/[(scot %p dest)] %agent [dest %grubbery] %poke grubbery-intake+!>(resp)]
  this
::  +drop: remove a remote watcher.
::
++  drop
  |=  [watcher=rail:tarball target=lane:tarball]
  ^+  this
  (sub-del target watcher)
::  %snap: record pace in afar, populate staged peeks, request missing lobes.
::  %data: merge silo, discharge fulfilled peeks.
::
++  process-transfer
  |=  [src=@p resp=transfer:remote:nexus]
  ^+  this
  ?-  +<.resp
      %snap
    ::  Solicitation check: only accept snaps we asked for
    =/  solicited=?
      %+  lien  ~(tap by peeks)
      |=  [[* *] pk=peek:remote:nexus]
      &(=(ship.pk src) =(dest.pk dest.resp))
    ?.  solicited
      ~&  >>  [%snap-unsolicited src=src dest=dest.resp]
      this
    ::  1. Record pace into afar — we now know this about the remote ship.
    ::  2. Populate snap on staged peeks matching this ship+dest.
    ::  3. Diff refs against silo and request missing lobes.
    ::  4. Discharge any peeks that can already be fulfilled.
    ::
    =.  afar  (record-afar src dest.resp snap.resp)
    =.  peeks
      %-  ~(run by peeks)
      |=  pk=peek:remote:nexus
      ?.  &(=(ship.pk src) =(dest.pk dest.resp))
        pk
      pk(snap snap.resp)
    ?~  snap.resp
      ::  Nothing exists at dest — discharge immediately with %none
      ~&  >  [%snap-not-found dest=dest.resp]
      discharge-peeks
    =/  have=(set lobe:clay)
      (~(uni in ~(key by jects.silo)) ~(key by nouns.silo))
    =/  missing=(set lobe:clay)
      (~(dif in refs.u.snap.resp) have)
    ~&  >  [%snap-processed refs=~(wyt in refs.u.snap.resp) have=~(wyt in have) missing=~(wyt in missing)]
    ?:  =(~ missing)
      ::  All refs already in silo — discharge immediately
      ~&  >  %snap-all-refs-present-discharging
      discharge-peeks
    ::  Send %want for missing lobes
    ~&  >  [%snap-sending-want missing=~(wyt in missing)]
    =/  want-req=transfer:remote:nexus
      [/want %want dest.resp missing]
    =.  cards
      :_  cards
      [%pass /want/[(scot %p src)] %agent [src %grubbery] %poke grubbery-transfer+!>(want-req)]
    this
    ::
      %want
    ::  Inbound want — should not arrive here (handled in on-poke).
    ~&  >>>  [%unexpected-want-in-process-transfer src]
    this
    ::
      %data
    ::  Received jects/nouns from remote. Verify hashes, merge into
    ::  local silo, then discharge any staged peeks whose refs are present.
    ::
    ~&  >  [%data-received-from src]
    =/  got=silo:nexus  silo.resp
    ::  Hash verification: only accept blobs whose content matches their lobe
    =/  verified-nouns=(map lobe:clay [refs=@ud =noun])
      %-  ~(gas by *(map lobe:clay [refs=@ud =noun]))
      %+  murn  ~(tap by nouns.got)
      |=  [=lobe:clay refs=@ud =noun]
      ?.  =(lobe `@uvI`(sham noun))
        ~&  >>  [%data-hash-mismatch %noun lobe]
        ~
      `[lobe 0 noun]
    =/  verified-jects=(map lobe:clay [refs=@ud =ject:nexus])
      %-  ~(gas by *(map lobe:clay [refs=@ud =ject:nexus]))
      %+  murn  ~(tap by jects.got)
      |=  [=lobe:clay refs=@ud =ject:nexus]
      ?.  =(lobe `@uvI`(sham ject))
        ~&  >>  [%data-hash-mismatch %ject lobe]
        ~
      `[lobe 0 ject]
    =.  nouns.silo  (~(uni by nouns.silo) verified-nouns)
    =.  jects.silo  (~(uni by jects.silo) verified-jects)
    ~&  >  [%peek-data-received nouns=~(wyt by verified-nouns) jects=~(wyt by verified-jects)]
    discharge-peeks
  ==
::  %bond/%wave: subscription events from remote watchers.
::
++  process-intake
  |=  [src=@p resp=intake:remote:nexus]
  ^+  this
  ?-  +<.resp
      %bond
    ::  Initial wave from remote subscription. Translate dest back to
    ::  namespaced lane and deliver %bond to local watchers.
    ::
    ~&  >  [%bond-received-from src dest=dest.resp]
    =/  ns-lane=lane:tarball
      =/  prefix=path  /sys/ames/ships/[(scot %p src)]/root
      ?-(-.dest.resp %& [%& (weld prefix path.p.dest.resp) name.p.dest.resp], %| [%| (weld prefix p.dest.resp)])
    =/  watchers=subscribers:nexus  (fwd-get ns-lane)
    =.  this
      %-  ~(rep by watchers)
      |=  [[watcher=rail:tarball =wire blot=(unit blot:tarball)] acc=_this]
      (enqu-take:acc watcher (sys-give:acc /bond) ~ %bond wire wave.resp)
    this
    ::
      %wave
    ::  Ongoing wave from remote subscription. Same as %bond but
    ::  delivers %news to watchers.
    ::
    ~&  >  [%wave-received-from src dest=dest.resp]
    =/  ns-lane=lane:tarball
      =/  prefix=path  /sys/ames/ships/[(scot %p src)]/root
      ?-(-.dest.resp %& [%& (weld prefix path.p.dest.resp) name.p.dest.resp], %| [%| (weld prefix p.dest.resp)])
    =/  watchers=subscribers:nexus  (fwd-get ns-lane)
    =.  this
      %-  ~(rep by watchers)
      |=  [[watcher=rail:tarball =wire blot=(unit blot:tarball)] acc=_this]
      (enqu-take:acc watcher (sys-give:acc /news) ~ %news wire wave.resp)
    this
  ==
::
++  abet
  |-
  ?:  =(~ takes)
    [(flop cards) state]
  =^  [here=rail:tarball =take:fiber:nexus]  takes  ~(get to takes)
  =.  this  (process-take here take)
  $
::  Purge code map entries whose paths no longer exist as code nexuses.
::
++  purge-stale-code
  ^+  this
  =/  keys=(list path)  ~(tap in ~(key by code))
  |-
  ?~  keys  this
  =/  sub  (peek-ball-now i.keys)
  ?:  ?&(?=(^ fil.sub) ?=(^ neck.u.fil.sub) =([/ %code] u.neck.u.fil.sub))
    $(keys t.keys)
  =/  old-lode=lode:nexus  (~(got by code) i.keys)
  =.  bins  (refs-dec refs.old-lode)
  $(keys t.keys, code (~(del by code) i.keys))
::  Drop hist entries matching a lose spec, decrementing silo refs
::
++  drop-hist
  |=  [here=rail:tarball =lose:nexus]
  ^+  this
  =/  sk=hist:nexus  (need (get-born here))
  =/  entries=(list [key=cass:clay val=pace:hist:nexus])
    (tap:hon:hist:nexus sk)
  =/  kept=(list [key=cass:clay val=pace:hist:nexus])  ~
  |-
  ?~  entries
    =|  new-hist=hist:nexus
    =.  new-hist
      |-
      ?~  kept  new-hist
      $(kept t.kept, new-hist (put:hon:hist:nexus new-hist key.i.kept val.i.kept))
    =.  born  (~(put bo:nexus now.bowl born) here new-hist)
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
    =.  silo
      =/  pv=pace:hist:nexus  val.i.entries
      ?:  ?=(%tomb -.pv)  silo
      ?~  p.pv  silo
      (~(drop-ject si:nexus silo) u.p.pv)
    ::  if tombstoning the top, append a new [%temp ~] wavefront
    =/  new-kept  [[key.i.entries [%tomb ~]] kept]
    ?.  =(key.i.entries (need (top:hist:nexus sk)))
      $(entries t.entries, kept new-kept)
    =/  new-cass=cass:clay
      (~(next-cass bo:nexus now.bowl born) key.i.entries)
    $(entries t.entries, kept [[new-cass [%temp ~]] new-kept])
  $(entries t.entries, kept [i.entries kept])
::  Set gain flag on a lane: single file or recursive on directory.
::  For files, rewrites the leaf ject with the new gain flag.
::  For directories, recurses into all descendant files.
::
++  set-gain-lane
  |=  [=lane:tarball flag=?]
  ^+  this
  ?-    -.lane
      %&
    ::  File: set gain on the leaf ject at this rail
    =/  here=rail:tarball  p.lane
    =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
      (~(get of born) path.here)
    ?~  node  this
    =/  fh=(unit hist:nexus)  (~(get by file.u.node) name.here)
    ?~  fh  this
    =/  got=(unit [key=cass:clay val=pace:hist:nexus])
      (ram:hon:hist:nexus u.fh)
    ?~  got  this
    ?:  ?=(%tomb -.val.u.got)  this
    ?~  p.val.u.got  this
    =/  jot  (~(get by jects.silo) u.p.val.u.got)
    ?~  jot  this
    ?.  ?=(%leaf -.ject.u.jot)  this
    ?:  =(gain.leaf.ject.u.jot flag)  this
    ::  Rewrite leaf ject with new gain flag
    =/  new-leaf=leaf:nexus  leaf.ject.u.jot(gain flag)
    =.  silo  (~(drop-ject si:nexus silo) u.p.val.u.got)
    =/  [new-lobe=lobe:clay new-silo=silo:nexus]
      (~(put-ject si:nexus silo) [%leaf new-leaf])
    =.  silo  new-silo
    ::  Update hist to point to new ject lobe
    =/  =pace:hist:nexus  ?:(flag [%firm `new-lobe] [%temp `new-lobe])
    =/  new-hist=hist:nexus
      (put:hon:hist:nexus u.fh key.u.got pace)
    =.  born  (~(put bo:nexus now.bowl born) here new-hist)
    this
      %|
    ::  Directory: recurse into all files in subtree
    =/  sub-ball=ball:tarball  (peek-ball-now p.lane)
    =/  entries=(list [pax=path lp=lump:tarball])  ~(tap of sub-ball)
    |-
    ?~  entries  this
    =/  files=(list @ta)  ~(tap in ~(key by contents.lp.i.entries))
    |-
    ?~  files  ^$(entries t.entries)
    =.  this  (set-gain-lane &+[(weld p.lane pax.i.entries) i.files] flag)
    $(files t.files)
  ==
::  Promote current %temp hist entry to %firm at a rail.
::
++  firm-hist
  |=  here=rail:tarball
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.here)
  ?~  node  this
  =/  fh=(unit hist:nexus)  (~(get by file.u.node) name.here)
  ?~  fh  this
  =/  got=(unit [key=cass:clay val=pace:hist:nexus])
    (ram:hon:hist:nexus u.fh)
  ?~  got  this
  ?.  ?=(%temp -.val.u.got)  this
  ::  Promote %temp → %firm in hist
  =/  new-hist=hist:nexus
    (put:hon:hist:nexus u.fh key.u.got [%firm p.val.u.got])
  =.  born  (~(put bo:nexus now.bowl born) here new-hist)
  this
::  Find all [rail cass] pairs in a subtree whose hist contains a lobe
::
++  seek-lobe
  |=  [=lane:tarball target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  ?-    -.lane
      %&
    ::  Single file: check its hist
    =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
      (~(get of born) path.p.lane)
    ?~  node  ~
    =/  sk=(unit hist:nexus)  (~(get by file.u.node) name.p.lane)
    ?~  sk  ~
    (match-hist p.lane u.sk target)
      %|
    ::  Directory: walk all files in born subtree
    =/  sub-born=born:nexus  (~(dip of born) p.lane)
    =/  nodes=(list [pax=path fold=hist:nexus file=(map @ta hist:nexus)])
      ~(tap of sub-born)
    (seek-nodes p.lane nodes target)
  ==
::
++  seek-nodes
  |=  [base=path nodes=(list [pax=path fold=hist:nexus file=(map @ta hist:nexus)]) target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  ?~  nodes  ~
  =/  files=(list [@ta hist:nexus])  ~(tap by file.i.nodes)
  =/  hits=(list [=rail:tarball =cass:clay])
    (seek-files base pax.i.nodes files target)
  (weld hits $(nodes t.nodes))
::
++  seek-files
  |=  [base=path pax=path files=(list [@ta hist:nexus]) target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  ?~  files  ~
  =/  hits=(list [=rail:tarball =cass:clay])
    (match-hist [(weld base pax) -.i.files] +.i.files target)
  (weld hits $(files t.files))
::
::  match-hist: find hist entries whose leaf ject contains target noun-lobe
++  match-hist
  |=  [here=rail:tarball =hist:nexus target=lobe:clay]
  ^-  (list [=rail:tarball =cass:clay])
  %+  murn  (tap:hon:hist:nexus hist)
  |=  [key=cass:clay val=pace:hist:nexus]
  ?:  ?=(%tomb -.val)  ~
  ?~  p.val  ~
  =/  jot  (~(get by jects.silo) u.p.val)
  ?~  jot  ~
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%leaf -.jt)  ~
  ?.  =(lobe.leaf.jt target)  ~
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
::  Validate a noun using a vale gate $-(* vase)
::
++  validate-vase
  |=  [vale=$-(* vase) noun=*]
  ^-  (each vase tang)
  (mule |.((vale noun)))
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
  ^-  (unit [namespace=fold:tarball source=rail:tarball ckey=@uv =built:nexus])
  =/  ns=(unit fold:tarball)  (find-code-ns pax)
  ?~  ns  ~
  =/  lod=lode:nexus  (~(got by code) u.ns)
  =/  node=(unit (map @ta @uv))
    (~(get of refs.lod) path)
  ?~  node  ~
  =/  ckey=(unit @uv)
    (~(get by u.node) name)
  ?~  ckey  ~
  =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) u.ckey)
  ?~  entry  ~
  `[u.ns [path name] u.ckey built.u.entry]
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
::  Vale cache: check/store validation results by [lobe ckey].
::  TODO: pass lobe from silo instead of hashing noun
::
::  Vale cache read: check if [lobe ckey] has been validated
::
++  vale-hit
  |=  [lob=lobe:clay ckey=@uv]
  ^-  (unit (unit tang))
  (~(get by vale) [lob ckey])
::  Vale cache write: store validation result
::
++  vale-put
  |=  [lob=lobe:clay ckey=@uv res=(unit tang)]
  ^+  this
  this(vale (~(put by vale) [lob ckey] res))
::  Check vale cache for a prior validation result.
::  Returns ~ on miss, [~ (each vase tang)] on hit.
::  On cached success, reconstructs vase from marc type + noun.
::
++  check-vale-cache
  |=  [pax=path =blot:tarball noun=*]
  ^-  (unit (each vase tang))
  =/  built-res  (seek-built pax (weld /mar path.blot) name.blot)
  ?~  built-res  ~
  =/  lob=lobe:clay  (sham noun)
  =/  hit  (vale-hit lob ckey.u.built-res)
  ?~  hit  ~
  ?^  u.hit  `|+u.u.hit
  ::  Cached success: reconstruct vase from marc type + noun
  ?.  ?=(%vase -.built.u.built-res)  ~
  =/  marc-res=(each marc:tarball tang)
    (mule |.(!<(marc:tarball vase.built.u.built-res)))
  ?.  ?=(%& -.marc-res)  ~
  `&+[type:p.marc-res noun]
::  Cache a validation result by looking up the mark's ckey.
::  No-op if the mark has no compiled artifact.
::
++  cache-validation
  |=  [pax=path =blot:tarball noun=* res=(each * tang)]
  ^+  this
  =/  lob=lobe:clay  (sham noun)
  =/  built-res  (seek-built pax (weld /mar path.blot) name.blot)
  ?~  built-res  this
  (vale-put lob ckey.u.built-res ?:(?=(%& -.res) ~ `p.res))
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
++  validate-noun
  |=  [pax=path =blot:tarball noun=*]
  ^-  (each vase tang)
  ::  Try compiled marc first — type:marc is the canonical type
  =/  res=(unit built:nexus)  (get-built pax (weld /mar path.blot) name.blot)
  ?^  res
    ?.  ?=(%vase -.u.res)
      =/  nam=@tas  (rail-to-arm:tarball blot)
      |+~[leaf+"validate-noun: marc for %{(trip nam)} failed at {(spud pax)}"]
    =/  nam=@tas  (rail-to-arm:tarball blot)
    =/  marc-res=(each marc:tarball tang)
      ~|  [%validate-noun %marc-extract-failed nam pax]
      (mule |.(!<(marc:tarball vase.u.res)))
    ?:  ?=(%| -.marc-res)
      |+[leaf+"validate-noun: marc for %{(trip nam)} broke at {(spud pax)}" p.marc-res]
    =/  val-res=(each vase tang)
      (validate-vase vale:p.marc-res noun)
    ?:  ?=(%| -.val-res)  val-res
    &+[type:p.marc-res noun]
  ::  No compiled marc — bootstrap fallback
  ?:  =([/ %hoon] blot)
    (mule |.(!>(;;(@t noun))))
  ?:  =([/ %tang] blot)
    (mule |.(!>(;;(tang noun))))
  ?:  =([/ %mime] blot)
    (mule |.(!>(;;(mime noun))))
  ?:  =([/ %kelvin] blot)
    (mule |.(!>(;;(waft:clay noun))))
  =/  nam=@tas  (rail-to-arm:tarball blot)
  |+~[leaf+"validate-noun: no marc for %{(trip nam)} at {(spud pax)}"]
::  Validate a sage at sandbox boundary
::  Used when data crosses a weir filter from untrusted source.
::
++  validate-sage
  |=  [pax=path =sage:tarball]
  ^-  (each sage:tarball tang)
  =/  result=(each vase tang)
    (validate-noun pax p.sage q.q.sage)
  ?:  ?=(%| -.result)
    result
  &+[p.sage p.result]
::  Validate sang: re-validate noun through its mark.
::  Boom (%| reus) is re-tried; success heals it.
::
++  validate-sang
  |=  [pax=path =sang:tarball]
  ^-  sang:tarball
  =/  noun=*  (sang-noun:tarball sang)
  =/  res=(each vase tang)  (validate-noun pax p.sang noun)
  ?:  ?=(%| -.res)
    [p.sang %| [p.res noun]]
  [p.sang %& p.res]
::  Validate a bask (blot + noun) into a sage.
::  Used when reading historical data from the silo.
::
++  validate-bask
  |=  [pax=path =bask:tarball]
  ^-  (each sage:tarball tang)
  =/  res=(each vase tang)  (validate-noun pax p.bask q.bask)
  ?:  ?=(%| -.res)  res
  &+[p.bask p.res]
::  Look up gain flag for a file from its current leaf ject.
::  Returns %.n if file doesn't exist or has no leaf ject.
::
++  lookup-gain
  |=  here=rail:tarball
  ^-  ?
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.here)
  ?~  node  %.n
  =/  fh=(unit hist:nexus)  (~(get by file.u.node) name.here)
  ?~  fh  %.n
  =/  got=(unit [key=cass:clay val=pace:hist:nexus])
    (ram:hon:hist:nexus u.fh)
  ?~  got  %.n
  ?:  ?=(%tomb -.val.u.got)  %.n
  ?~  p.val.u.got  %.n
  =/  jot  (~(get by jects.silo) u.p.val.u.got)
  ?~  jot  %.n
  ?.  ?=(%leaf -.ject.u.jot)  %.n
  gain.leaf.ject.u.jot
::  Peek a single file by ject-lobe.  Looks up the leaf ject in silo,
::  fetches the raw noun, validates via vale cache, returns sang.
::
++  peek-grub
  |=  =lobe:clay
  ^-  (unit sang:tarball)
  =/  jot  (~(get by jects.silo) lobe)
  ?~  jot  ~
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%leaf -.jt)  ~
  =/  raw  (~(get si:nexus silo) lobe.leaf.jt)
  ?~  raw  ~
  =/  =blot:tarball  blot.mark.leaf.jt
  =/  ckey=@uv  ckey.mark.leaf.jt
  =/  hit  (vale-hit lobe.leaf.jt ckey)
  =/  entry  (~(get by bins) ckey)
  ?~  entry
    `[blot %| [~[leaf+"peek-grub: mark not in bins {<blot>} ckey={<ckey>}"] u.raw]]
  ?.  ?=(%vase -.built.u.entry)
    `[blot %| [~[leaf+"peek-grub: bins entry not a vase {<blot>} ckey={<ckey>}"] u.raw]]
  =/  marc-res=(each marc:tarball tang)
    (mule |.(!<(marc:tarball vase.built.u.entry)))
  ?:  ?=(%| -.marc-res)
    `[blot %| [(weld ~[leaf+"peek-grub: marc extraction failed {<blot>}"] p.marc-res) u.raw]]
  ?^  hit
    ::  Cache hit: valid → reconstruct vase from marc type
    ?^  u.hit  `[blot %| [u.u.hit u.raw]]
    `[blot %& type:p.marc-res u.raw]
  ::  Cache miss: validate via marc
  =/  val-res=(each vase tang)
    (mule |.((vale:p.marc-res u.raw)))
  ?:  ?=(%| -.val-res)  `[blot %| [p.val-res u.raw]]
  `[blot %& p.val-res]
::  Peek a ball subtree by ject-lobe.  If the lobe is a tree ject,
::  recurse into fil (leaf children) and dir (tree children).
::
++  peek-ball
  |=  =lobe:clay
  ^-  ball:tarball
  =/  jot  (~(get by jects.silo) lobe)
  ?~  jot  *ball:tarball
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%tree -.jt)  *ball:tarball
  =/  nek=(unit neck:tarball)
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  =/  contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    %-  ~(gas by *(map @ta [=sang:tarball gain=? bang=(unit tang)]))
    %+  murn  ~(tap by fil.tree.jt)
    |=  [name=@ta =lobe:clay]
    ^-  (unit [@ta [=sang:tarball gain=? bang=(unit tang)]])
    =/  got  (peek-grub lobe)
    ?~  got  ~
    =/  leaf-jot  (~(get by jects.silo) lobe)
    =/  leaf-gain=?
      ?~  leaf-jot  %.n
      ?.  ?=(%leaf -.ject.u.leaf-jot)  %.n
      gain.leaf.ject.u.leaf-jot
    =/  leaf-bang=(unit tang)
      ?~  leaf-jot  ~
      ?.  ?=(%leaf -.ject.u.leaf-jot)  ~
      ?~  bang.leaf.ject.u.leaf-jot  ~
      =/  tn  (~(get si:nexus silo) u.bang.leaf.ject.u.leaf-jot)
      ?~  tn  ~
      `!<(tang [-:!>(*tang) u.tn])
    `[name u.got leaf-gain leaf-bang]
  ::  Resolve directory-level bang
  =/  dir-bang=(unit tang)
    ?~  bang.tree.jt  ~
    =/  tn  (~(get si:nexus silo) u.bang.tree.jt)
    ?~  tn  ~
    `!<(tang [-:!>(*tang) u.tn])
  =/  =lump:tarball  [nek ~ gain.tree.jt dir-bang contents]
  =/  sub-dirs=(map @ta ball:tarball)
    %-  ~(gas by *(map @ta ball:tarball))
    %+  turn  ~(tap by dir.tree.jt)
    |=  [name=@ta =lobe:clay weir=(unit weir:tarball)]
    ^-  [@ta ball:tarball]
    [name (peek-ball lobe)]
  [`lump sub-dirs]
::  Peek bole: raw nouns, no vase construction or bang resolution.
::
++  peek-bole
  |=  =lobe:clay
  ^-  bole:tarball
  =/  jot  (~(get by jects.silo) lobe)
  ?~  jot  *bole:tarball
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%tree -.jt)  *bole:tarball
  =/  nek=(unit neck:tarball)
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  =/  contents=(map @ta [=bask:tarball gain=?])
    %-  ~(gas by *(map @ta [=bask:tarball gain=?]))
    %+  murn  ~(tap by fil.tree.jt)
    |=  [name=@ta =lobe:clay]
    ^-  (unit [@ta [=bask:tarball gain=?]])
    =/  leaf-jot  (~(get by jects.silo) lobe)
    ?~  leaf-jot  ~
    ?.  ?=(%leaf -.ject.u.leaf-jot)  ~
    =/  raw  (~(get si:nexus silo) lobe.leaf.ject.u.leaf-jot)
    ?~  raw  ~
    =/  =blot:tarball  blot.mark.leaf.ject.u.leaf-jot
    =/  leaf-gain=?  gain.leaf.ject.u.leaf-jot
    `[name [blot u.raw] leaf-gain]
  =/  weir=(unit weir:nexus)  ~
  =/  =pulp:tarball  [nek weir gain.tree.jt contents]
  =/  sub-dirs=(map @ta bole:tarball)
    %-  ~(gas by *(map @ta bole:tarball))
    %+  turn  ~(tap by dir.tree.jt)
    |=  [name=@ta =lobe:clay weir=(unit weir:tarball)]
    ^-  [@ta bole:tarball]
    [name (peek-bole lobe)]
  [`pulp sub-dirs]
::
++  peek-bole-now
  |=  =fold:tarball
  ^-  bole:tarball
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  *bole:tarball
  =/  got=(unit [key=cass:clay val=pace:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  *bole:tarball
  =/  =pace:hist:nexus  val.u.got
  ?:  ?=(%tomb -.pace)  *bole:tarball
  ?~  p.pace  *bole:tarball
  (peek-bole u.p.pace)
::  Shallow peek: resolve files at this level, subdirs as empty balls.
::  No recursion — O(files at this level) instead of O(all files).
::
++  peek-ball-shallow
  |=  =lobe:clay
  ^-  ball:tarball
  =/  jot  (~(get by jects.silo) lobe)
  ?~  jot  *ball:tarball
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%tree -.jt)  *ball:tarball
  =/  nek=(unit neck:tarball)
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  =/  contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    %-  ~(gas by *(map @ta [=sang:tarball gain=? bang=(unit tang)]))
    %+  murn  ~(tap by fil.tree.jt)
    |=  [name=@ta =lobe:clay]
    ^-  (unit [@ta [=sang:tarball gain=? bang=(unit tang)]])
    =/  got  (peek-grub lobe)
    ?~  got  ~
    =/  leaf-jot  (~(get by jects.silo) lobe)
    =/  leaf-gain=?
      ?~  leaf-jot  %.n
      ?.  ?=(%leaf -.ject.u.leaf-jot)  %.n
      gain.leaf.ject.u.leaf-jot
    =/  leaf-bang=(unit tang)
      ?~  leaf-jot  ~
      ?.  ?=(%leaf -.ject.u.leaf-jot)  ~
      ?~  bang.leaf.ject.u.leaf-jot  ~
      =/  tn  (~(get si:nexus silo) u.bang.leaf.ject.u.leaf-jot)
      ?~  tn  ~
      `!<(tang [-:!>(*tang) u.tn])
    `[name u.got leaf-gain leaf-bang]
  =/  dir-bang=(unit tang)
    ?~  bang.tree.jt  ~
    =/  tn  (~(get si:nexus silo) u.bang.tree.jt)
    ?~  tn  ~
    `!<(tang [-:!>(*tang) u.tn])
  =/  =lump:tarball  [nek ~ gain.tree.jt dir-bang contents]
  =/  sub-dirs=(map @ta ball:tarball)
    %-  ~(gas by *(map @ta ball:tarball))
    %+  turn  ~(tap by dir.tree.jt)
    |=  [name=@ta =lobe:clay weir=(unit weir:tarball)]
    ^-  [@ta ball:tarball]
    [name *ball:tarball]
  [`lump sub-dirs]
::  Peek the current sang at a rail (born lookup + peek-grub).
::
++  peek-grub-now
  |=  =rail:tarball
  ^-  (unit sang:tarball)
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.rail)
  ?~  node  ~
  =/  sok=(unit hist:nexus)  (~(get by file.u.node) name.rail)
  ?~  sok  ~
  =/  got=(unit [key=cass:clay val=pace:hist:nexus])
    (ram:hon:hist:nexus u.sok)
  ?~  got  ~
  =/  =pace:hist:nexus  val.u.got
  ?:  ?=(%tomb -.pace)  ~
  ?~  p.pace  ~
  (peek-grub u.p.pace)
::  Peek the current ball at a fold (born lookup + peek-ball).
::
++  peek-ball-now
  |=  =fold:tarball
  ^-  ball:tarball
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  *ball:tarball
  =/  got=(unit [key=cass:clay val=pace:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  *ball:tarball
  =/  =pace:hist:nexus  val.u.got
  ?:  ?=(%tomb -.pace)  *ball:tarball
  ?~  p.pace  *ball:tarball
  (peek-ball u.p.pace)
::  Shallow peek: files at fold + subdir names, no recursion.
::
++  peek-ball-shallow-now
  |=  =fold:tarball
  ^-  ball:tarball
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  *ball:tarball
  =/  got=(unit [key=cass:clay val=pace:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  *ball:tarball
  =/  =pace:hist:nexus  val.u.got
  ?:  ?=(%tomb -.pace)  *ball:tarball
  ?~  p.pace  *ball:tarball
  (peek-ball-shallow u.p.pace)
::  List file names at a directory (from born).
::
++  lis-born
  |=  =fold:tarball
  ^-  (list @ta)
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  ~
  ~(tap in ~(key by file.u.node))
::  List subdirectory names at a directory (from born).
::
++  lss-born
  |=  =fold:tarball
  ^-  (list @ta)
  =/  sub=born:nexus  (~(dip of born) fold)
  ~(tap in ~(key by dir.sub))
::  Validate all cages in a ball subtree, crash on failure
::
::  Validates every file in the ball through its mark's vale gate.
::
++  validate-ball
  |=  [cod=path =ball:tarball]
  ^-  [ball:tarball _this]
  =|  here=path
  |-
  =/  validated-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    ?~  fil.ball  ~
    =/  files=(list [@ta [=sang:tarball gain=? bang=(unit tang)]])  ~(tap by contents.u.fil.ball)
    =|  out=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    |-
    ?~  files  out
    =/  [name=@ta =sang:tarball gain=? bang=(unit tang)]  i.files
    =/  noun=*  (sang-noun:tarball sang)
    =/  cached  (check-vale-cache cod p.sang noun)
    =/  res=(each vase tang)
      ?^  cached  u.cached
      ~|  [%validate-ball name (weld cod here) p.sang]
      (validate-noun cod p.sang noun)
    =?  this  ?=(~ cached)
      (cache-validation cod p.sang noun res)
    ?.  ?=(%& -.res)
      ~&  >>  "validate-ball: boom {(trip name)} (mark %{(trip name.p.sang)}) at {(spud (weld cod here))}"
      $(files t.files, out (~(put by out) name [[p.sang %| [p.res noun]] gain bang]))
    $(files t.files, out (~(put by out) name [[p.sang %& p.res] gain bang]))
  =/  validated-dir=(map @ta ball:tarball)
    =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
    =|  out=(map @ta ball:tarball)
    |-
    ?~  kids  out
    =/  [name=@ta kid=ball:tarball]  i.kids
    =^  validated-kid  this  ^$(here (snoc here name), ball kid)
    $(kids t.kids, out (~(put by out) name validated-kid))
  :-  :_  validated-dir
      ?~  fil.ball  ~
      `u.fil.ball(contents validated-contents)
  this
::  Validate all basks in a bole subtree, producing a ball
::
::  Converts each bask (blot + noun) to sage (blot + vase) via validate-bask.
::  Used after on-load returns a bole.
::
++  validate-bole
  |=  [cod=path =bole:tarball]
  ^-  ball:tarball
  =|  here=path
  |-
  =/  validated-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    ?~  fil.bole  ~
    =/  files=(list [@ta [=bask:tarball gain=?]])  ~(tap by contents.u.fil.bole)
    =|  out=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    |-
    ?~  files  out
    =/  [name=@ta =bask:tarball gain=?]  i.files
    =/  res=(each sage:tarball tang)
      ~|  [%validate-bole name (weld cod here) p.bask]
      (validate-bask (weld cod here) bask)
    ?.  ?=(%& -.res)
      ~&  >>  "validate-bole: boom {(trip name)} at {(spud (weld cod here))}"
      $(files t.files, out (~(put by out) name [[p.bask %| [p.res q.bask]] gain ~]))
    $(files t.files, out (~(put by out) name [(sage-to-sang:tarball p.res) gain ~]))
  =/  validated-dir=(map @ta ball:tarball)
    =/  kids=(list [@ta bole:tarball])  ~(tap by dir.bole)
    =|  out=(map @ta ball:tarball)
    |-
    ?~  kids  out
    =/  [name=@ta kid=bole:tarball]  i.kids
    $(kids t.kids, out (~(put by out) name ^$(here (snoc here name), bole kid)))
  :_  validated-dir
  ?~  fil.bole  ~
  `[neck.u.fil.bole weir.u.fil.bole gain.u.fil.bole ~ validated-contents]
::
++  store-proc
  |=  [here=rail:tarball =proc:fiber:nexus]
  ^+  this
  =/  old=pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  =pipe:nexus  old(proc (~(put by proc.old) name.here proc))
  this(pool (~(put of pool) path.here pipe))
::  Bang a nexus directory — store tang on pipe + ject,
::  stay all processes under it.
::
++  bang-nexus
  |=  [dest=fold:tarball err=tang]
  ^+  this
  %-  (slog [leaf+"BANG nexus {(spud dest)}" err])
  ::  Set bang on the pipe at dest
  =/  old=pipe:nexus  (fall (~(get of pool) dest) *pipe:nexus)
  =.  pool  (~(put of pool) dest old(bang `err))
  ::  Persist bang to fold ject in silo
  =.  this  (bang-fold dest err)
  ::  Bang every file under dest (set process to |+err)
  =/  sub  (peek-ball-now dest)
  =.  this
    %+  roll  ~(tap ba:tarball sub)
    |=  [[=rail:tarball *] acc=_this]
    (bang-file:acc [(weld dest path.rail) name.rail] err)
  ::  Replace all processes under dest with +stay
  (stay-all-procs dest)
::  Bang a file — store tang on its process and persist to ject.
::  Records trees and notifies subscribers.
::
++  bang-file
  |=  [here=rail:tarball err=tang]
  ^+  this
  ~&  >>>  "BANG file {(spud (snoc path.here name.here))}"
  %-  (slog (scag 10 err))
  ::  Set bang on pipe/proc
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  old=(unit proc:fiber:nexus)  (~(get by proc.pipe) name.here)
  =/  =proc:fiber:nexus
    ?~  old  [|+err ~ ~]
    [|+err next.u.old skip.u.old]
  =.  this  (store-proc here proc)
  ::  Persist bang to leaf ject in silo
  =/  sok=(unit hist:nexus)  (get-born here)
  ?~  sok  this
  =/  cas=(unit cass:clay)  (top:hist:nexus u.sok)
  ?~  cas  this
  =/  pv=(unit pace:hist:nexus)  (get:hon:hist:nexus u.sok u.cas)
  ?~  pv  this
  ?:  ?=(%tomb -.u.pv)  this
  ?~  p.u.pv  this
  =/  [new-lobe=lobe:clay new-silo=silo:nexus]
    (~(set-bang si:nexus silo) u.p.u.pv err)
  =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.cas)
  =/  new-sok=hist:nexus
    (put:hon:hist:nexus u.sok new-cass [%temp `new-lobe])
  =.  silo  new-silo
  =.  born  (~(put bo:nexus now.bowl born) here new-sok)
  =/  old-born=born:nexus  born
  =.  this  (record-trees path.here)
  (notify old-born)
::  Bang a fold (directory) ject — persist tang to tree ject in silo.
::  Records trees and notifies subscribers.
::
++  bang-fold
  |=  [dest=fold:tarball err=tang]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) dest)
  ?~  node  this
  =/  cas=(unit cass:clay)  (top:hist:nexus fold.u.node)
  ?~  cas  this
  =/  pv=(unit pace:hist:nexus)  (get:hon:hist:nexus fold.u.node u.cas)
  ?~  pv  this
  ?:  ?=(%tomb -.u.pv)  this
  ?~  p.u.pv  this
  =/  [new-lobe=lobe:clay new-silo=silo:nexus]
    (~(set-bang si:nexus silo) u.p.u.pv err)
  =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.cas)
  =/  new-fold=hist:nexus
    (put:hon:hist:nexus fold.u.node new-cass [%temp `new-lobe])
  =.  silo  new-silo
  =.  born  (~(put of born) dest u.node(fold new-fold))
  =/  old-born=born:nexus  born
  =.  this  (record-trees dest)
  (notify old-born)
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
  ^+  this
  =.  pool  (clear-pool-bangs-at pool dest)
  (clear-ject-bangs-under dest)
::
++  clear-pool-bangs-at
  |=  [pol=pool:nexus dest=fold:tarball]
  ^-  pool:nexus
  ?~  dest  (clear-pool-bangs pol)
  =/  kid=pool:nexus  (~(gut by dir.pol) i.dest ^+(pol [~ ~]))
  pol(dir (~(put by dir.pol) i.dest $(pol kid, dest t.dest)))
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
::  Walk born under dest, clear bang on every ject (fold + file).
::
++  clear-ject-bangs-under
  |=  dest=fold:tarball
  ^+  this
  =/  sub-born=born:nexus  (~(dip of born) dest)
  (clear-ject-bangs-born dest sub-born)
::
++  clear-ject-bangs-born
  |=  [pax=fold:tarball bor=born:nexus]
  ^+  this
  ::  Clear fold-level bang
  =.  this
    ?~  fil.bor  this
    =/  fold-cas=(unit cass:clay)  (top:hist:nexus fold.u.fil.bor)
    ?~  fold-cas  this
    =/  pv=(unit pace:hist:nexus)  (get:hon:hist:nexus fold.u.fil.bor u.fold-cas)
    ?~  pv  this
    ?:  ?=(%tomb -.u.pv)  this
    ?~  p.u.pv  this
    =/  cleared  (~(clear-bang si:nexus silo) u.p.u.pv)
    ?~  cleared  this
    =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.fold-cas)
    =/  new-fold=hist:nexus
      (put:hon:hist:nexus fold.u.fil.bor new-cass [%temp `lobe.u.cleared])
    =.  silo  silo.u.cleared
    =.  born
      =/  node  (fall (~(get of born) pax) *[fold=hist:nexus file=(map @ta hist:nexus)])
      (~(put of born) pax node(fold new-fold))
    this
  ::  Clear file-level bangs
  =.  this
    ?~  fil.bor  this
    =/  files=(list [@ta hist:nexus])  ~(tap by file.u.fil.bor)
    |-
    ?~  files  this
    =/  [name=@ta sok=hist:nexus]  i.files
    =/  cas=(unit cass:clay)  (top:hist:nexus sok)
    ?~  cas  $(files t.files)
    =/  pv=(unit pace:hist:nexus)  (get:hon:hist:nexus sok u.cas)
    ?~  pv  $(files t.files)
    ?:  ?=(%tomb -.u.pv)  $(files t.files)
    ?~  p.u.pv  $(files t.files)
    =/  cleared  (~(clear-bang si:nexus silo) u.p.u.pv)
    ?~  cleared  $(files t.files)
    =/  here=rail:tarball  [pax name]
    =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.cas)
    =/  new-sok=hist:nexus
      (put:hon:hist:nexus sok new-cass [%temp `lobe.u.cleared])
    =.  silo  silo.u.cleared
    =.  born  (~(put bo:nexus now.bowl born) here new-sok)
    $(files t.files)
  ::  Recurse into subdirectories
  =/  kids=(list [name=@ta kid=born:nexus])  ~(tap by dir.bor)
  |-
  ?~  kids  this
  =.  this  (clear-ject-bangs-born (snoc pax name.i.kids) kid.i.kids)
  $(kids t.kids)
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
  =/  del-check  (peek-grub-now [dir name])
  ~?  >>  ?=(~ del-check)
    "no grub at {(spud (weld dir /[name]))}"
  ::  Clean up outgoing subscriptions from this file
  =.  this  (sub-wipe [dir name])
  ::  Snapshot before mutations
  =/  old-born=born:nexus  born
  ::  Tomb previous %temp entry, then append [%temp ~] for deletion
  =/  sok=(unit hist:nexus)  (get-born [dir name])
  =.  this
    ?.  ?=(^ sok)  this
    =/  file-cass=cass:clay  (need (top:hist:nexus u.sok))
    =/  [tombed-silo=silo:nexus tombed-hist=hist:nexus]
      (~(tomb-temp si:nexus silo) u.sok file-cass)
    =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) file-cass)
    =/  new-sok=hist:nexus  (put:hon:hist:nexus tombed-hist new-cass [%temp ~])
    this(silo tombed-silo, born (~(put bo:nexus now.bowl born) [dir name] new-sok))
  =.  this  (propagate old-born [dir name])
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
  =.  this  (build-code u.cod)
  this
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
  |=  [here=rail:tarball =took:eval]
  ^+  this
  ?.  ?=([~ %poke *] in.take.took)  this
  (give-poke-ack here from.give.take.took wire.give.take.took err.took)
::
++  give-poke-signs
  |=  [here=rail:tarball done=(list took:eval)]
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
  |=  [here=fold:tarball sub-ball=ball:tarball]
  ^-  ball:tarball
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
  ::  IMPORTANT: The weir at the root lump is preserved from the parent.
  ::  A nexus cannot control its own sandboxing - that would defeat the purpose.
  ::  Sandboxing is always imposed from above. The nexus can only set weirs
  ::  for its children, never for itself.
  ::
  =/  parent-weir=(unit weir:nexus)
    ?~  fil.sub-ball  ~
    weir.u.fil.sub-ball
  =/  parent-neck=(unit neck:tarball)
    ?~(fil.sub-ball ~ neck.u.fil.sub-ball)
  =/  upd-ball=ball:tarball
    ?~  nex  sub-ball
    =/  =bole:tarball  (on-load:u.nex sub-ball)
    =/  restored-pulp=pulp:tarball  (fall fil.bole *pulp:tarball)
    =.  bole  bole(fil `restored-pulp(neck parent-neck, weir parent-weir))
    (validate-bole here bole)
  ::  Enforce parent weir and parent neck on ball.
  ::  A nexus cannot change its own sandboxing or its own identity.
  ::
  =/  restored-lump=lump:tarball
    (fall fil.upd-ball *lump:tarball)
  =.  sub-ball  upd-ball(fil `restored-lump(neck parent-neck, weir parent-weir))
  ::  Recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub-ball)
  |-
  ?~  kids  sub-ball
  =/  kid-name=@ta  -.i.kids
  =/  kid-ball=ball:tarball  +.i.kids
  =/  new-kid-ball=ball:tarball
    ^$(here (snoc here kid-name), sub-ball kid-ball)
  =.  dir.sub-ball  (~(put by dir.sub-ball) kid-name new-kid-ball)
  $(kids t.kids)
::  Reload a single nexus at dest (re-run on-load)
::
++  reload-nexus
  |=  dest=fold:tarball
  ^+  this
  =/  sub-ball  (peek-ball-now dest)
  ?~  fil.sub-ball  ~|("no nexus at destination" !!)
  ?~  neck.u.fil.sub-ball  ~|("no nexus at destination" !!)
  =/  nex=(each nexus:nexus tang)
    (build-nexus dest u.neck.u.fil.sub-ball)
  ?:  ?=(%| -.nex)
    ~&  >>  "reload-nexus: build error at {(spud dest)}"
    (bang-nexus dest p.nex)
  =.  this  (reload-nexus-at dest p.nex)
  (spawn-all-files dest (peek-bole-now dest))
::  Run on-load for a nexus at dest and apply results
::
::  Reload a nexus: run on-load, write ball, recurse into child nexuses.
::  Does NOT spawn processes — callers spawn after the full tree is settled.
::
++  reload-nexus-at
  |=  [dest=fold:tarball nex=nexus:nexus]
  ^+  this
  ~&  >  [%reload-nexus-at dest]
  =/  old-sub  (peek-ball-now dest)
  =/  sub-ball=ball:tarball  old-sub
  ~&  >  [%reload-old-sub-fil ?=(^ fil.sub-ball) %neck ?~(fil.sub-ball ~ ?=(^ neck.u.fil.sub-ball))]
  =/  parent-weir=(unit weir:nexus)
    ?~  fil.sub-ball  ~
    weir.u.fil.sub-ball
  =/  parent-neck=(unit neck:tarball)  ?~(fil.sub-ball ~ neck.u.fil.sub-ball)
  ::  Clear all bangs under this nexus before reloading
  ::  (reload will re-bang anything that still fails)
  =.  this  (clear-bangs-under dest)
  ::  Run on-load (may crash)
  =/  load-res=(each bole:tarball tang)
    (mule |.((on-load:nex sub-ball)))
  ?:  ?=(%| -.load-res)
    ~&  >>>  [%reload-nexus-at-bang dest]
    (bang-nexus dest p.load-res)
  ~&  >  [%reload-on-load-ok dest]
  =/  upd-bole=bole:tarball  p.load-res
  ::  Enforce parent weir and parent neck on bole
  =/  restored-pulp=pulp:tarball  (fall fil.upd-bole *pulp:tarball)
  =.  upd-bole
    upd-bole(fil `restored-pulp(neck parent-neck, weir parent-weir))
  ~&  >  [%reload-validated dest %fil ?=(^ fil.upd-bole) %neck ?~(fil.upd-bole ~ ?=(^ neck.u.fil.upd-bole))]
  ::  Put results back — load-ball-changes writes bole and does bookkeeping
  =.  this  (load-ball-changes dest upd-bole)
  ~&  >  [%reload-loaded dest]
  =.  this  (bump-weir-changes dest (ball-to-bole:tarball old-sub) upd-bole)
  =.  this  (audit-weir dest)
  =.  this  (reload-child-nexuses dest)
  ::  Propagate tree ject changes upward to root after child nexuses reload.
  =.  this  (record-trees dest)
  ~&  >  [%reload-done dest]
  this
::  Recursively reload all child nexuses top-to-bottom.
::  Every directory with a neck loads state and recurses into its children.
::
++  reload-child-nexuses
  |=  dest=fold:tarball
  ^+  this
  =/  sub  (peek-ball-now dest)
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
::  Spawn processes for all files in ball recursively.
::
::  Tracks the current nexus scope to avoid redundant silo lookups.
::  Builds the nexus once per scope and passes blot from ball directly.
::
++  spawn-all-files
  |=  [here=fold:tarball new=bole:tarball]
  ^+  this
  (spawn-all-files-in here new ~)
::
++  spawn-all-files-in
  |=  $:  here=fold:tarball
          new=bole:tarball
          scope=(unit [nex-path=path nex=nexus:nexus])
      ==
  ^+  this
  ::  If this level has a neck, build nexus once (overrides parent scope)
  =/  nex-scope=(unit [nex-path=path nex=nexus:nexus])
    ?~  fil.new  scope
    ?~  neck.u.fil.new  scope
    =/  nex-res=(each nexus:nexus tang)
      (build-nexus here u.neck.u.fil.new)
    ?:(?=(%| -.nex-res) scope `[here p.nex-res])
  ::  Spawn files at this level
  =/  files=(list [@ta [=bask:tarball gain=?]])
    ?~  fil.new  ~
    ~(tap by contents.u.fil.new)
  =/  ns  nex-scope
  =.  this
    ?:  |(=(~ files) =(~ ns))  this
    =/  nxp=path  nex-path:(need ns)
    =/  nxc=nexus:nexus  nex:(need ns)
    |-
    ?~  files  this
    =/  file-name=@ta  -.i.files
    =/  file-rail=rail:tarball  [here file-name]
    =/  =blot:tarball  p.bask.i.files
    =/  rel=rail:tarball  (relativize-rail:tarball nxp file-rail)
    =/  spool-res=(each spool:fiber:nexus tang)
      (mule |.((on-file:nxc rel blot)))
    =.  this  ?^((get-born file-rail) this (init-born file-rail))
    =.  this  (spawn-proc-with file-rail [%load ~] spool-res)
    $(files t.files)
  ::  Recurse into children
  =/  kids=(list [@ta bole:tarball])  ~(tap by dir.new)
  |-
  ?~  kids  this
  =/  kid-name=@ta  -.i.kids
  =.  this  ^$(here (snoc here kid-name), new +.i.kids, scope nex-scope)
  $(kids t.kids)
::
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
  |=  [target=lane:tarball watcher=rail:tarball =wire blot=(unit blot:tarball)]
  ^+  this
  ::  Add to forward index: target → (watcher → [wire blot])
  =/  watchers=subscribers:nexus  (fwd-get target)
  =.  fwd.subs  (fwd-set target (~(put by watchers) watcher [wire blot]))
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
  =/  watched=(list [target=lane:tarball watchers=(map rail:tarball [=wire blot=(unit blot:tarball)])])
    tap-fwd
  |-
  ?~  watched  this
  =/  [target=lane:tarball watchers=(map rail:tarball [=wire blot=(unit blot:tarball)])]  i.watched
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
  ::  Build wavefront for relevant lanes, relativized to target
  =/  =wave:nexus  (relativize-wave:nexus target (wave-from-born:nexus born relevant))
  ::  Send wavefront to each watcher
  =.  this
    %-  ~(rep by watchers)
    |=  [[watcher=rail:tarball =wire blot=(unit blot:tarball)] acc=_this]
    ::  Remote watcher: poke wave to subscriber ship
    ?:  ?=([%sys %ames %ships @ *] path.watcher)
      =/  dest=@p  (slav %p i.t.t.t.path.watcher)
      =/  resp=intake:remote:nexus
        [wire %wave target wave]
      =.  cards.acc
        :_  cards.acc
        [%pass /wave/[(scot %p dest)] %agent [dest %grubbery] %poke grubbery-intake+!>(resp)]
      acc
    ::  Local watcher: deliver directly
    (enqu-take:acc watcher (sys-give:acc /news) ~ %news wire wave)
  $(watched t.watched)
::  Handle jael on-watch: give initial udiffs on subscription.
::  path=~ gives all udiffs, path=[@ ~] filters per ship.
::
++  serve-jael
  |=  =path
  ^+  this
  =/  js  jael-source
  ?~  js  this
  =/  content=(unit sang:tarball)  (peek-grub-now u.js)
  ?~  content  this
  ?~  path
    ::  / — give all udiffs
    =.  cards
      [[%give %fact ~ %azimuth-udiffs (need-vase:tarball u.content)] cards]
    this
  ::  /[ship] — give filtered udiffs
  =/  who=(unit @p)  (slaw %p i.path)
  ?~  who  this
  =+  !<(uds=udiffs:point:jael (need-vase:tarball u.content))
  =/  filtered=udiffs:point:jael
    (skim uds |=([=ship *] =(ship u.who)))
  =.  cards
    [[%give %fact ~ %azimuth-udiffs !>(filtered)] cards]
  this
::  If the jael-source rail changed, give %azimuth-udiffs to gall subs.
::  Sends on / (all udiffs) and on /(scot %p ship) (filtered per ship).
::
++  maybe-give-jael
  |=  changed=(set lane:tarball)
  ^+  this
  =/  js  jael-source
  ?~  js  this
  =/  src-lane=lane:tarball  [%& u.js]
  ?.  (~(has in changed) src-lane)  this
  =/  content=(unit sang:tarball)  (peek-grub-now u.js)
  ?~  content  this
  =+  !<(uds=udiffs:point:jael (need-vase:tarball u.content))
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
  =/  val=[=wire blot=(unit blot:tarball)]  (~(got by (fwd-get target)) watcher)
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
  =/  sub  (peek-ball-now here-path)
  ?.  |(?=(^ fil.sub) !=(~ dir.sub))
    ?~  here-path  ~
    $(here-path (snip `path`here-path))
  ?:  ?&(?=(^ fil.sub) ?=(^ neck.u.fil.sub))
    `[here-path u.neck.u.fil.sub]
  ?~  here-path  ~
  $(here-path (snip `path`here-path))
::
::
++  build-spool
  |=  here=rail:tarball
  ^-  (unit spool:fiber:nexus)
  ::  Get the file from the ball - must exist
  =/  file-data  (peek-grub-now path.here name.here)
  ?~  file-data  ~
  ::  Extract blot from the sage
  =/  =blot:tarball  p.u.file-data
  ::  Find the nearest parent nexus
  =/  nex-info  (find-nearest-nexus here)
  ?~  nex-info  ~
  ::  Build the nexus from the neck
  =/  nex-res=(each nexus:nexus tang)  (build-nexus path.here q.u.nex-info)
  ?:  ?=(%| -.nex-res)  ~
  ::  Call on-file with rail relative to nexus location
  =/  rel=rail:tarball  (relativize-rail:tarball p.u.nex-info here)
  `(on-file:p.nex-res rel blot)
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
    ::  Vetoed — crash for foreign ship darts (gall nacks the sender),
    ::  send %veto intake back to source for internal darts.
    ?:  ?=([%sys %ames %ships @ ~] path.here)
      ~|  [%peer-vetoed name.here dest]
      !!
    (enqu-take here (sys-give /veto) ~ %veto dart)
    ::
      [~ %&]
    ::  Weir boundary allowed — validation happens in handler for all dart types.
    ::  Peek results are validated inside handle-dart (data flows back).
    (handle-dart here dart filt)
  ==
::  Extract jump category and destination from a dart for weir filtering.
::  Returns [jump dest] where:
::    - jump: the filter category (%make, %poke, %peek)
::    - dest: absolute destination lane, or ~ for system darts
::
++  dart-to-dest
  |=  [here=rail:tarball =dart:nexus]
  ^-  [jump:nexus (unit lane:tarball)]
  ?+    -.dart  [%peek ~]          :: system darts: no dest, always allowed
      %node                        :: %node darts target a file/dir
    =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] road.dart)
    :_  dest-lane
    ?-  -.load.dart
      ?(%peek %keep %drop %seek %peep %manu %code %font)  %peek  :: read operations
      %poke                       %poke
        $?  %make  %cull  %sand  %load
            %over  %lose  %gain  %firm
        ==
      %make  :: all modify tree structure
    ==
    ::
      %manu
    [%peek ~]  :: direct: no dest, bypasses weir
  ==
::
++  handle-dart
  |=  [here=rail:tarball =dart:nexus =filt:nexus]
  ^+  this
  =/  cod=path  path.here
  ?-    -.dart
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
      ::  Validate poke bask → sage
      =/  cached  (check-vale-cache path.dest p.bask.load.dart q.bask.load.dart)
      =/  validated=(each vase tang)
        ?^  cached  u.cached
        (validate-noun path.dest p.bask.load.dart q.bask.load.dart)
      =?  this  ?=(~ cached)
        (cache-validation path.dest p.bask.load.dart q.bask.load.dart validated)
      ?:  ?=(%| -.validated)
        ?:  ?=([%sys %ames %ships @ ~] path.here)
          ~|  [%peer-clam-failed name.here dest]  !!
        (enqu-take here (sys-give /veto) ~ %veto dart)
      =/  =sage:tarball  [p.bask.load.dart p.validated]
      ::  /sys/behn/ timer service: intercept timer-set pokes
      ?:  ?&  =([/sys/behn %'main.timer-state'] dest)
              =([/ %timer-set] p.sage)
          ==
        =.  this  (handle-timer-set here wire.dart q.sage)
        (enqu-take here (sys-give /behn) ~ %pack wire.dart ~)
      ::  /sys/eyre/ HTTP service: intercept eyre-action pokes
      ?:  ?&  =([/sys/eyre %'main.server-state'] dest)
              =([/ %eyre-action] p.sage)
          ==
        =.  this  (handle-eyre-action here wire.dart q.sage)
        (enqu-take here (sys-give /eyre) ~ %pack wire.dart ~)
      ::  /sys/push/ push service: intercept push-action pokes
      ?:  ?&  =([/sys/push %'main.push-state'] dest)
              =([/ %push-action] p.sage)
          ==
        =.  this  (handle-push-action here wire.dart q.sage)
        (enqu-take here (sys-give /push) ~ %pack wire.dart ~)
      ::  /sys/ namespace services: general dispatch
      =/  sys=(unit _this)
        (handle-sys-poke dest here wire.dart sage)
      ?^  sys  u.sys
      ::  Poke with return address (relativize source for fiber intake)
      =/  rel=from:fiber:nexus  (relativize-from:nexus dest &+here)
      (enqu-take dest [&+here wire.dart] ~ %poke rel sage)
      ::
        %make
      ::  Create file or directory.
      ::  If mark is set on a file make, convert the content via
      ::  cached tube before storing.
      =/  mak=make:nexus  make.load.dart
      =/  res=(each _this tang)
        (mule |.((make u.dest-lane mak)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /made) ~ %made wire.dart ~)
          %|
        ::  Runtime services (/sys/) crash on make failure
        ?:  =(/sys (scag 1 path.here))
          (mean p.res)
        (enqu-take here (sys-give /made) ~ %made wire.dart `p.res)
      ==
      ::
        %cull
      ::  Delete file or directory at dest
      =/  res=(each _this tang)  (mule |.((cull u.dest-lane)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /gone) ~ %gone wire.dart ~)
          %|
        ?:  =(/sys (scag 1 path.here))
          (mean p.res)
        (enqu-take here (sys-give /gone) ~ %gone wire.dart `p.res)
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
      =/  old  (peek-grub-now path.dest name.dest)
      ?~  old
        (enqu-take here (sys-give /over) ~ %over wire.dart `~[leaf+"file not found: {(spud (snoc path.dest name.dest))}"])
      =/  old-blot=blot:tarball  p.u.old
      =/  new-blot=blot:tarball  p.bask.load.dart
      ?:  (is-boom:tarball u.old)
        ~&  >>>  "over: target file is boomed: {(spud (snoc path.dest name.dest))}"
        (enqu-take here (sys-give /over) ~ %over wire.dart `~[leaf+"over: target file is boomed, fix the mark and reload: {(spud (snoc path.dest name.dest))}"])
      =/  =bask:tarball
        ?:  =(old-blot new-blot)
          bask.load.dart
        =/  src=(each vase tang)  (validate-noun cod p.bask.load.dart q.bask.load.dart)
        ?:  ?=(%| -.src)  ~|("over: source validation failed" (mean p.src))
        =/  =tube:clay  (get-tube cod [[/ name.new-blot] [/ name.old-blot]])
        [old-blot q:(tube p.src)]
      =/  cached  (check-vale-cache cod p.bask q.bask)
      =/  val=(each vase tang)
        ?^  cached  u.cached
        (validate-noun cod p.bask q.bask)
      =?  this  ?=(~ cached)
        (cache-validation cod p.bask q.bask val)
      ?:  ?=(%| -.val)
        (enqu-take here (sys-give /over) ~ %over wire.dart `p.val)
      =/  new-content=sang:tarball  [p.bask %& p.val]
      =.  this  (save-file dest new-content)
      =.  this  (enqu-take dest (sys-give /writ) ~ %writ ~)
      (enqu-take here (sys-give /over) ~ %over wire.dart ~)
      ::
        %peek
      ::  Remote peek: if dest is under /sys/ames/ships/[ship]/root/,
      ::  stage the peek and send %peek load to the remote ship.
      ::  The fiber suspends until discharge-peeks sends the intake back.
      ::
      ?>  ?=(^ dest-lane)
      =/  remote=(unit [@p lane:tarball])
        =/  pax=path
          ?-(-.u.dest-lane %& path.p.u.dest-lane, %| p.u.dest-lane)
        ?.  ?=([%sys %ames %ships @ %root *] pax)
          ~
        =/  target=@p  (slav %p i.t.t.t.pax)
        =/  real-path=path  t.t.t.t.t.pax
        :-  ~  :-  target
        ?-(-.u.dest-lane %& [%& real-path name.p.u.dest-lane], %| [%| real-path])
      ?^  remote
        =/  [target=@p real-dest=lane:tarball]  u.remote
        =/  key=[rail:tarball wire]  [here wire.dart]
        =.  peeks
          %+  ~(put by peeks)  key
          [target real-dest deep.load.dart blot.load.dart ~]
        =/  req=load:remote:nexus
          [[wire.dart real-dest] %peek case.load.dart deep.load.dart]
        =.  cards
          :_  cards
          [%pass /peek/[(scot %p target)] %agent [target %grubbery] %poke grubbery-load+!>(req)]
        this
      ::  Refresh /sys/bowl/ on peek-at-latest only.
      ::  Peek-at-cass returns historical values from silo.
      ::  This breaks the notify loop: save-file notifies → subscriber
      ::  re-peeks at the notified cass → no refresh → no loop.
      =?  this  =(~ case.load.dart)
        =/  now-existing  (peek-grub-now /sys/bowl %now)
        =/  now-val=@da
          ?~  now-existing  now.bowl
          =/  prev=@da  ;;(@da (sang-noun:tarball u.now-existing))
          ?:  (gte prev now.bowl)
            (add prev (div ~s1 1.000))
          now.bowl
        =/  eny-existing  (peek-grub-now /sys/bowl %eny)
        =/  eny-val=@uvJ
          ?~  eny-existing  eny.bowl
          (shaz (cat 3 eny.bowl ;;(@uvJ (sang-noun:tarball u.eny-existing))))
        =.  this  (save-file [/sys/bowl %our] [[/ %ship] %& !>(our.bowl)])
        =.  this  (save-file [/sys/bowl %now] [[/ %time] %& !>(now-val)])
        (save-file [/sys/bowl %eny] [[/ %entropy] %& !>(eny-val)])
      ::  Peek at dest - directory returns ball+born, file returns cage
      ::  Returns %none if directory doesn't exist or has no lump
      ::  ver: if set, read historical version from hist via silo
      ?-    -.u.dest-lane
          %|
        =/  dest=fold:tarball  p.u.dest-lane
        =/  sub-born=born:nexus  (~(dip of born) dest)
        ?:  &(=(~ fil.sub-born) =(~ dir.sub-born))
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        =/  sub-ball
          ?:  deep.load.dart
            (peek-ball-now dest)
          (peek-ball-shallow-now dest)
        =^  vball  this  (validate-ball cod sub-ball)
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %ball sub-born vball)
        ::
          %&
        =/  dest=rail:tarball  p.u.dest-lane
        =/  content  (peek-grub-now path.dest name.dest)
        ?:  &(?=(~ content) ?=(~ case.load.dart))
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
          (~(get of born) path.dest)
        =/  sk=hist:nexus
          ?~  node  *hist:nexus
          (fall (~(get by file.u.node) name.dest) *hist:nexus)
        ::  Resolve source: historical bask from silo or current sang from ball
        =/  source=(unit sang:tarball)
          ?^  case.load.dart
            =/  =pace:hist:nexus
              (resolve-case:nexus u.case.load.dart sk)
            ?:  ?=(%tomb -.pace)  ~
            ?~  p.pace  ~
            =/  jot  (~(get by jects.silo) u.p.pace)
            ?~  jot  ~
            =/  jt=ject:nexus  ject.u.jot
            ?.  ?=(%leaf -.jt)  ~
            =/  got=(unit noun)  (~(get si:nexus silo) lobe.leaf.jt)
            ?~  got  ~
            ::  Validate bask back to sang
            =/  res  (validate-bask cod [blot.mark.leaf.jt u.got])
            ?:  ?=(%| -.res)
              `[blot.mark.leaf.jt %| [p.res u.got]]
            `(sage-to-sang:tarball p.res)
          ?~  content  ~
          `u.content
        ?~  source
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        ::  Boom content passes through as-is
        ?:  (is-boom:tarball u.source)
          (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %file sk u.source)
        ::  Validate peek result
        =/  =sage:tarball  (need-sage:tarball u.source)
        =/  clammed=sage:tarball
          =/  cached  (check-vale-cache cod p.sage q.q.sage)
          =/  validated=(each vase tang)
            ?^  cached  u.cached
            (validate-noun cod p.sage q.q.sage)
          =?  this  ?=(~ cached)
            (cache-validation cod p.sage q.q.sage validated)
          ?:  ?=(%| -.validated)
            ~|(%peek-clam-failed !!)
          [p.sage p.validated]
        ::  Apply mark conversion if requested
        =/  result=sang:tarball
          ?~  blot.load.dart  (sage-to-sang:tarball clammed)
          ?:  =(p.clammed u.blot.load.dart)  (sage-to-sang:tarball clammed)
          =/  =tube:clay  (get-tube cod [p.clammed u.blot.load.dart])
          (sage-to-sang:tarball [p.clammed (tube q.clammed)])
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %file sk result)
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
        =/  sub-refs=refs:nexus  (~(dip of refs.lode) inner)
        =/  materialized=(axal (map @ta built:nexus))
          %+  roll  ~(tap of sub-refs)
          |=  [[pax=path node=(map @ta @uv)] acc=(axal (map @ta built:nexus))]
          =/  resolved=(map @ta built:nexus)
            %-  ~(gas by *(map @ta built:nexus))
            %+  murn  ~(tap by node)
            |=  [nam=@ta key=@uv]
            =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) key)
            ?~  entry  ~
            `[nam built.u.entry]
          (~(put of acc) pax resolved)
        (enqu-take here (sys-give /code) ~ %code wire.dart &+materialized)
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
        =/  node=(unit (map @ta @uv))  (~(get of refs.lode) inner)
        =/  hit=(unit built:nexus)
          ?~  node  ~
          =/  ckey=(unit @uv)  (~(get by u.node) name.dest)
          ?~  ckey  ~
          =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) u.ckey)
          ?~  entry  ~
          `built.u.entry
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
      ?>  ?=(^ dest-lane)
      =/  remote=(unit [@p lane:tarball])
        =/  pax=path
          ?-(-.u.dest-lane %& path.p.u.dest-lane, %| p.u.dest-lane)
        ?.  ?=([%sys %ames %ships @ %root *] pax)
          ~
        =/  target=@p  (slav %p i.t.t.t.pax)
        =/  real-path=path  t.t.t.t.t.pax
        :-  ~  :-  target
        ?-(-.u.dest-lane %& [%& real-path name.p.u.dest-lane], %| [%| real-path])
      ?^  remote
        ::  Remote subscribe: register locally and send %keep to remote
        =/  [target=@p real-dest=lane:tarball]  u.remote
        =.  this  (sub-put u.dest-lane here wire.dart blot.load.dart)
        =/  req=load:remote:nexus
          [[wire.dart real-dest] %keep ~]
        =.  cards
          :_  cards
          [%pass /keep/[(scot %p target)] %agent [target %grubbery] %poke grubbery-load+!>(req)]
        this
      ::  Local subscribe
      =.  this  (sub-put u.dest-lane here wire.dart blot.load.dart)
      =/  =wave:nexus
        %-  relativize-wave:nexus
        [u.dest-lane (wave-from-born:nexus born (~(put in *(set lane:tarball)) u.dest-lane))]
      (enqu-take here (sys-give /bond) ~ %bond wire.dart wave)
      ::
        %drop
      ::  Unsubscribe from dest
      ?>  ?=(^ dest-lane)
      =/  remote=(unit [@p lane:tarball])
        =/  pax=path
          ?-(-.u.dest-lane %& path.p.u.dest-lane, %| p.u.dest-lane)
        ?.  ?=([%sys %ames %ships @ %root *] pax)
          ~
        =/  target=@p  (slav %p i.t.t.t.pax)
        =/  real-path=path  t.t.t.t.t.pax
        :-  ~  :-  target
        ?-(-.u.dest-lane %& [%& real-path name.p.u.dest-lane], %| [%| real-path])
      ?^  remote
        ::  Remote unsubscribe
        =/  [target=@p real-dest=lane:tarball]  u.remote
        =.  this  (sub-del u.dest-lane here)
        =/  req=load:remote:nexus
          [[wire.dart real-dest] %drop ~]
        =.  cards
          :_  cards
          [%pass /drop/[(scot %p target)] %agent [target %grubbery] %poke grubbery-load+!>(req)]
        this
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
      =/  sk=(unit hist:nexus)  (get-born dest)
      ?~  sk
        (enqu-take here (sys-give /peep) ~ %peep wire.dart |+~[leaf+"no history for {(spud (snoc path.dest name.dest))}"])
      =/  entries=(list [key=cass:clay val=pace:hist:nexus])
        (tap:hon:hist:nexus u.sk)
      =/  hits=(list [cass:clay sage:tarball])
        %+  murn  entries
        |=  [key=cass:clay val=pace:hist:nexus]
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
        ?:  ?=(%tomb -.val)  ~
        ?~  p.val  ~
        =/  jot  (~(get by jects.silo) u.p.val)
        ?~  jot  ~
        =/  jt=ject:nexus  ject.u.jot
        ?.  ?=(%leaf -.jt)  ~
        =/  got=(unit noun)  (~(get si:nexus silo) lobe.leaf.jt)
        ?~  got  ~
        =/  res  (validate-bask cod [blot.mark.leaf.jt u.got])
        ?:  ?=(%| -.res)  ~
        `[key p.res]
      (enqu-take here (sys-give /peep) ~ %peep wire.dart &+hits)
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
        %gain
      ::  Set gain flag. Recursive on directories, single file on rails.
      =/  res=(each _this tang)
        (mule |.((set-gain-lane u.dest-lane flag.load.dart)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /gain) ~ %gain wire.dart ~)
        %|  (enqu-take here (sys-give /gain) ~ %gain wire.dart `p.res)
      ==
      ::
        %firm
      ::  Promote current %temp hist entry to %firm at a rail.
      ?>  ?=(%& -.u.dest-lane)
      =/  res=(each _this tang)
        (mule |.((firm-hist p.u.dest-lane)))
      ?-  -.res
        %&  (enqu-take:p.res here (sys-give /firm) ~ %held wire.dart ~)
        %|  (enqu-take here (sys-give /firm) ~ %held wire.dart `p.res)
      ==
      ::
        %manu
      ::  By road: resolve, find nearest nexus, relativize, call on-manu
      =/  target-path=path
        ?-(-.u.dest-lane %& (snoc path.p.u.dest-lane name.p.u.dest-lane), %| p.u.dest-lane)
      ::  Walk up tree to find nearest covering nexus
      =/  nex-info=(unit (pair path neck:tarball))
        |-
        =/  sub  (peek-ball-now target-path)
        ?.  |(?=(^ fil.sub) !=(~ dir.sub))
          ?~  target-path  ~
          $(target-path (snip `path`target-path))
        ?:  ?&(?=(^ fil.sub) ?=(^ neck.u.fil.sub))
          `[target-path u.neck.u.fil.sub]
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
          =/  manu-content  (peek-grub-now path.p.u.dest-lane name.p.u.dest-lane)
          =/  =blot:tarball
            (fall (bind manu-content |=(c=sang:tarball p.c)) *blot:tarball)
          [%| [(snip `path`rel-path) (rear rel-path)] blot]
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
    ::
      %here
    ::  Request location — walk up, reveal as much as allowed
    =/  loc=here:nexus  (walk-here here)
    (enqu-take here (sys-give /here) ~ %here wire.dart loc)
    ::
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
  ::  Build spool and process — bang file on crash
  =/  spool-got  (build-spool here)
  =/  spool-res=(each spool:fiber:nexus tang)
    (mule |.((fall spool-got default-spool)))
  (spawn-proc-with here prod spool-res)
::  Spawn a process with a pre-built spool result.
::  Used by spawn-all-files to avoid redundant silo lookups.
::
++  spawn-proc-with
  |=  [here=rail:tarball =prod:fiber:nexus spool-res=(each spool:fiber:nexus tang)]
  ^+  this
  ?:  (is-nexus-banged here)
    ~&  >>  [%spawn-skip-banged (snoc path.here name.here)]
    this
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
++  clam-output
  |=  [here=rail:tarball =blot:tarball old=vase new=*]
  ^-  (each [vase _this] tang)
  ?:  =(new q.old)  [%& old this]
  =/  cached  (check-vale-cache path.here blot new)
  =/  res=(each vase tang)
    ?^  cached  u.cached
    (validate-noun path.here blot new)
  =.  this  (cache-validation path.here blot new res)
  ?:  ?=(%& -.res)
    [%& p.res this]
  [%| p.res]
::
++  eval
  |%
  ++  output  (output-raw:fiber:nexus ,~)
  +$  result
    $%  [%next ~]
        [%fail err=tang]
        [%done ~]
    ==
  +$  took  [=take:fiber:nexus err=(unit tang)]
  ++  take
    =|  darts=(list dart:nexus)
    =|  done=(list took)
    |=  [here=rail:tarball state=vase =proc:fiber:nexus]
    ^-  [(list dart:nexus) (list took) vase proc:fiber:nexus result _this]
    =/  file-data  (peek-grub-now path.here name.here)
    =/  =blot:tarball
      ?~  file-data  [/ %noun]
      p.u.file-data
    =^  =take:fiber:nexus  next.proc  ~(get to next.proc)
    |-
    =/  res=(each output tang)
      ?>  ?=(%& -.process.proc)
      (mule |.((p.process.proc state in.take)))
    ?:  ?=(%| -.res)
      =/  =tang  [leaf+"crash" p.res]
      :*  darts
          :_(done [take `tang])
          state
          proc
          [%fail tang]
          this
      ==
    =/  =output  p.res
    =/  clam=(each [vase _this] tang)
      ?:  ?=(?(%fail %skip) -.next.output)  [%& state this]
      (clam-output here blot state state.output)
    ?:  ?=(%| -.clam)
      (mean [leaf+"state validation failed at {(spud (snoc path.here name.here))}"]~)
    =.  this  +.p.clam
    =/  val=vase  -.p.clam
    ?-    -.next.output
        %fail
      :*  darts
          :_(done [take `err.next.output])
          state
          proc
          [%fail err.next.output]
          this
      ==
        %done
      :*  (weld darts darts.output)
          :_(done [take ~])
          val
          proc
          [%done ~]
          this
      ==
        %cont
      %=  $
        darts         (weld darts darts.output)
        done          :_(done [take ~])
        state         val
        next.proc     (~(gas to next.proc) ~(tap to skip.proc))
        skip.proc     ~
        process.proc  &+self.next.output
        take          [give.take ~]
      ==
        %wait
      =.  darts  (weld darts darts.output)
      =.  done   :_(done [take ~])
      ?.  =(~ next.proc)
        =^  top  next.proc  ~(get to next.proc)
        %=  $
          take       top
          state      val
        ==
      :*  darts
          done
          val
          proc
          [%next ~]
          this
      ==
        %skip
      ?:  =(~ in.take)
        =/  =tang  [leaf+"cannot skip null input" ~]
        :*  darts
            :_(done [take `tang])
            state
            proc
            [%fail tang]
            this
        ==
      =.  skip.proc  (~(put to skip.proc) take)
      ?.  =(~ next.proc)
        =^  top  next.proc  ~(get to next.proc)
        $(take top)
      :*  darts
          done
          state
          proc
          [%next ~]
          this
      ==
    ==
  --
::
++  process-do-next
  |=  here=rail:tarball
  ^+  this
  ::  Get proc from pool
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  =/  prc=(unit proc:fiber:nexus)  (~(get by proc.pipe) name.here)
  ?~  prc  this
  =/  =proc:fiber:nexus  u.prc
  ::  Crashed process — takes accumulate in next, don't evaluate
  ?:  ?=(%| -.process.proc)  this
  ::  Get file state from ball
  =/  file-data  (peek-grub-now path.here name.here)
  ?~  file-data  this
  ?:  (is-boom:tarball u.file-data)  this
  =/  fil-state=vase  (need-vase:tarball u.file-data)
  ::  Run the evaluator (mule to catch hard crashes like !< mismatches)
  =/  eval-res=(each [darts=(list dart:nexus) done=(list took:eval) new-state=vase new-proc=proc:fiber:nexus res=result:eval core=_this] tang)
    (mule |.((take:eval here fil-state proc)))
  ?:  ?=(%| -.eval-res)
    (bang-file here p.eval-res)
  =/  [darts=(list dart:nexus) done=(list took:eval) new-state=vase new-proc=proc:fiber:nexus res=result:eval core=_this]
    p.eval-res
  ::  Restore core with updated vale cache
  =.  this  core
  ::  Process darts (emit cards or enqueue takes)
  =.  this  (process-darts here darts)
  ::  Ack consumed pokes
  =.  this  (give-poke-signs here done)
  ::  State already validated inside eval loop
  ?-    -.res
      %next
    ::  Save state (bumps aeon only if content changed)
    =.  this  (save-file here [p.u.file-data %& new-state])
    (store-proc here new-proc)
      %done
    ::  Save final state so subscribers see it, then delete
    =.  this  (save-file here [p.u.file-data %& new-state])
    =/  err=tang  ~[leaf+"process completed"]
    :: only nack-pokes when we're done
    ::
    =.  this  (nack-poke-takes here next.new-proc err)
    =.  this  (nack-poke-takes here skip.new-proc err)
    (delete path.here name.here)
      %fail
    ::  Process failed - don't save state, restart. Subs survive (wires still route).
    ::  Sync queues (consumed takes removed), rebuild process, enqueue
    ::  rise via abet. Same pattern as spawn-proc.
    ?:  (is-nexus-banged here)  this
    =/  spool-got  (build-spool here)
    =/  spool-res=(each spool:fiber:nexus tang)
      (mule |.((fall spool-got default-spool)))
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
    ::  Make directory - payload must be bole
    ?>  ?=(%& -.make)
    =/  dest-path=fold:tarball  p.dest
    =/  new-bole=bole:tarball  p.make
    ::  Assert nothing exists at path
    =/  existing  (peek-ball-now dest-path)
    ?:  |(?=(^ fil.existing) !=(~ dir.existing))
      ~|("path is not empty" !!)
    ::  Run on-loads top-down (still uses ball internally)
    =/  new-ball=ball:tarball
      (run-on-loads dest-path (validate-bole dest-path new-bole))
    =/  made=bole:tarball  (ball-to-bole:tarball new-ball)
    ::  Sync all changes (old is empty) and spawn processes
    =.  this  (load-ball-changes dest-path made)
    ::  Register and build any code namespaces in the new bole
    =.  this  (build-new-code-namespaces dest-path made)
    (spawn-all-files dest-path made)
    ::
      %&
    ::  Make file - payload must be bask
    ?>  ?=(%| -.make)
    =/  dest-rail=rail:tarball  p.dest
    ::  Convert mark if blot override is set
    =/  =bask:tarball
      ?.  ?&  ?=(^ blot.p.make)
              !=(p.bask.p.make u.blot.p.make)
          ==
        bask.p.make
      =/  src=(each vase tang)  (validate-noun path.dest-rail p.bask.p.make q.bask.p.make)
      ?:  ?=(%| -.src)  ~|("make: source validation failed" (mean p.src))
      =/  =tube:clay  (get-tube path.dest-rail [p.bask.p.make u.blot.p.make])
      [u.blot.p.make q:(tube p.src)]
    ::  Assert file doesn't already exist
    =/  existing-file  (peek-grub-now path.dest-rail name.dest-rail)
    ?^  existing-file
      ~|("file already exists at path" !!)
    ::  Validate the bask before storing
    =/  cached  (check-vale-cache path.dest-rail p.bask q.bask)
    =/  validated=(each vase tang)
      ?^  cached  u.cached
      (validate-noun path.dest-rail p.bask q.bask)
    =?  this  ?=(~ cached)
      (cache-validation path.dest-rail p.bask q.bask validated)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  Save initial state (bumps file aeon since old content is ~)
    =.  this  (save-file dest-rail [p.bask %& p.validated])
    ::  Spawn process (needs file in ball for build-spool)
    (spawn-proc dest-rail [%make ~])
  ==
::
++  cull
  |=  dest=lane:tarball
  ^+  this
  ?-    -.dest
      %|
    ::  Cull directory — sync with empty ball deletes everything
    =/  dest-path=fold:tarball  p.dest
    ::  Nack all queued pokes in subtree
    =.  this  (nack-pool dest-path (~(dip of pool) dest-path) ~[leaf+"culled"])
    ::  Remove from pool
    =.  pool  (~(lop of pool) dest-path)
    (load-ball-changes dest-path *bole:tarball)
    ::
      %&
    ::  Cull file - delete single file
    =/  dest-rail=rail:tarball  p.dest
    =/  dest-path=path  (rail-to-path:tarball dest-rail)
    ::  Nack queued pokes for this file
    =.  this  (nack-pool dest-path (~(dip of pool) dest-path) ~[leaf+"culled"])
    ::  Bump and remove from pool and ball
    (delete path.dest-rail name.dest-rail)
  ==
::  Walk two ball trees and bump weir cass in born for changed weirs
::
++  bump-weir-changes
  |=  [here=fold:tarball old=bole:tarball new=bole:tarball]
  ^+  this
  =/  old-weir=(unit weir:nexus)  ?~(fil.old ~ weir.u.fil.old)
  =/  new-weir=(unit weir:nexus)  ?~(fil.new ~ weir.u.fil.new)
  =?  this  !=(old-weir new-weir)
    =/  old-born=born:nexus  born
    =.  this  (record-trees here)
    (notify old-born)
  =/  all-kids=(list @ta)
    ~(tap in (~(uni in ~(key by dir.old)) ~(key by dir.new)))
  |-
  ?~  all-kids  this
  =/  kid-old=bole:tarball  (fall (~(get by dir.old) i.all-kids) *bole:tarball)
  =/  kid-new=bole:tarball  (fall (~(get by dir.new) i.all-kids) *bole:tarball)
  =.  this  ^$(here (snoc here i.all-kids), old kid-old, new kid-new)
  $(all-kids t.all-kids)
::
++  set-weir
  |=  [dest=path weir=(unit weir:nexus)]
  ^+  this
  ?>  ?=(^ dest)  :: root should always have system access
  ::  Read old weir from materialized ball
  =/  sub  (peek-ball-now dest)
  =/  old-weir=(unit weir:nexus)
    ?~  fil.sub  ~
    weir.u.fil.sub
  ?:  =(old-weir weir)  this
  ::  Update parent's tree ject with new child weir
  =/  parent=path  (snip `path`dest)
  =/  child-name=@ta  (rear dest)
  =/  parent-born=born:nexus  (~(dip of born) parent)
  =/  boo  ~(. bo:nexus now.bowl born)
  =/  node=[fold=hist:nexus file=(map @ta hist:nexus)]
    (fall fil.parent-born default-node:boo)
  =/  existing-tree=tree:nexus
    =/  top-fold  top:hist:nexus
    =/  fold-top=(unit cass:clay)  (top-fold fold.node)
    ?~  fold-top  [~ %.n ~ ~ ~]
    =/  got=(unit pace:hist:nexus)  (get:hon:hist:nexus fold.node u.fold-top)
    ?~  got  [~ %.n ~ ~ ~]
    ?:  ?=(%tomb -.u.got)  [~ %.n ~ ~ ~]
    ?~  p.u.got  [~ %.n ~ ~ ~]
    =/  jot  (~(get by jects.silo) u.p.u.got)
    ?~  jot  [~ %.n ~ ~ ~]
    ?.  ?=(%tree -.ject.u.jot)  [~ %.n ~ ~ ~]
    tree.ject.u.jot
  =/  old-entry=[=lobe:clay weir=(unit weir:nexus)]
    (fall (~(get by dir.existing-tree) child-name) [*lobe:clay ~])
  =/  new-tree=tree:nexus
    existing-tree(dir (~(put by dir.existing-tree) child-name old-entry(weir weir)))
  =/  [* new-born=born:nexus new-silo=silo:nexus]
    (put-tree:nexus born silo now.bowl parent node new-tree)
  =.  born  new-born
  =.  silo  new-silo
  ::  Record tree from parent up, notify
  =/  old-born=born:nexus  born
  =.  this  (record-trees parent)
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
  ::  Allowed — look up neck from tree ject at this path
  =/  sub=born:nexus  (~(dip of born) remaining)
  =/  neck=(unit neck:tarball)
    ?~  fil.sub  ~
    =/  fold-top=(unit [key=cass:clay val=pace:hist:nexus])
      (ram:hon:hist:nexus fold.u.fil.sub)
    ?~  fold-top  ~
    =/  =pace:hist:nexus  val.u.fold-top
    ?:  ?=(%tomb -.pace)  ~
    ?~  p.pace  ~
    =/  jot  (~(get by jects.silo) u.p.pace)
    ?~  jot  ~
    =/  jt=ject:nexus  ject.u.jot
    ?.  ?=(%tree -.jt)  ~
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  $(remaining ancestor, pant [[dir neck] pant])
::
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
  ::  System darts have dest=~; use root as dummy dest (no weir match = pass)
  =/  dest-lane=lane:tarball  (fall dest [%| /])
  =|  =filt:nexus
  |-
  ::  Reached governor - stop (don't check its weir)
  ?:  &(?=(^ gov) =(path.here u.gov))
    filt
  ::  Check weir at current location (stored on parent's tree dir entry)
  =/  weir-here=(unit weir:nexus)  (peek-weir path.here)
  =/  next=filt:nexus
    (next-filt:nexus filt (filter:nexus jump path.here dest-lane weir-here))
  ?:  ?=([~ %|] next)
    [~ |]
  ::  Reached root - stop (handles syscalls which have no governor)
  ?~  path.here
    next
  $(filt next, path.here (snip `fold:tarball`path.here))
::  Read weir for a directory from its parent's tree ject dir entry.
::  A directory's weir is owned by its parent, not by itself.
::
++  peek-weir
  |=  here=fold:tarball
  ^-  (unit weir:nexus)
  ?~  here  ~
  =/  parent=path  (snip `path`here)
  =/  child-name=@ta  (rear here)
  =/  parent-born=born:nexus  (~(dip of born) parent)
  ?~  fil.parent-born  ~
  =/  fold-top=(unit cass:clay)
    (top:hist:nexus fold.u.fil.parent-born)
  ?~  fold-top  ~
  =/  got=(unit pace:hist:nexus)
    (get:hon:hist:nexus fold.u.fil.parent-born u.fold-top)
  ?~  got  ~
  ?:  ?=(%tomb -.u.got)  ~
  ?~  p.u.got  ~
  =/  jot  (~(get by jects.silo) u.p.u.got)
  ?~  jot  ~
  ?.  ?=(%tree -.ject.u.jot)  ~
  =/  entry  (~(get by dir.tree.ject.u.jot) child-name)
  ?~  entry  ~
  weir.u.entry
::  =born: Thin wrappers around ++bo in lib/nexus.hoon
::  See ++bo for documentation of semantics and invariants.
::
++  get-born
  |=  here=rail:tarball
  ^-  (unit hist:nexus)
  (~(get bo:nexus now.bowl born) here)
::
++  get-dir-cass
  |=  dir=fold:tarball
  ^-  (unit cass:clay)
  (~(get-dir-cass bo:nexus now.bowl born) dir)
::
++  init-born
  |=  here=rail:tarball
  ^+  this
  this(born (~(init bo:nexus now.bowl born) here))
::
::
++  propagate
  |=  [old-born=born:nexus here=rail:tarball]
  ^+  this
  =.  this  (record-trees path.here)
  (notify old-born)
::  Record tree objects from dir up to root into silo + fold hist.
::  Only bumps fold when tree hash actually changes. Stops propagating
::  when a level produces the same hash (nothing above can change).
::
++  record-trees
  |=  dir=path
  ^+  this
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born silo code now.bowl dir)
  this(born new-born, silo new-silo)
::  Ensure a directory exists in the namespace.
::
++  ensure-dir
  |=  here=fold:tarball
  ^+  this
  =/  node  (~(get of born) here)
  ?^  node  this
  (load-ball-changes here [`[~ ~ %.n ~] ~])
::  Record noun+blot in silo and append to file hist.
::
++  record
  |=  [here=rail:tarball =bask:tarball gain=? cas=(unit cass:clay)]
  ^+  this
  =/  sok=hist:nexus  (need (get-born here))
  ::  Use provided cass or compute next from current top of hist
  =/  file-cass=cass:clay  (need (top:hist:nexus sok))
  =/  new-cass=cass:clay
    (fall cas (~(next-cass bo:nexus now.bowl born) file-cass))
  =/  marc-ckey=@uv
    =/  res  (seek-built path.here (weld /mar path.p.bask) name.p.bask)
    ?~(res 0v0 ckey.u.res)
  =/  raw=*  q.bask
  =/  [=lobe:clay new-silo=silo:nexus new-sok=hist:nexus]
    (~(record si:nexus silo) raw p.bask marc-ckey gain new-cass file-cass sok)
  =.  silo  new-silo
  =.  born  (~(put bo:nexus now.bowl born) here new-sok)
  ::  Populate vale cache so reads never miss
  ?:  =(marc-ckey 0v0)  this
  =/  entry  (~(get by bins) marc-ckey)
  ?~  entry  this
  ?.  ?=(%vase -.built.u.entry)  this
  =/  marc-res=(each marc:tarball tang)
    (mule |.(!<(marc:tarball vase.built.u.entry)))
  ?:  ?=(%| -.marc-res)
    ~|([%record-marc-broken p.bask path.here name.here] !!)
  =/  res=(each vase tang)
    (mule |.((vale:p.marc-res raw)))
  ?:  ?=(%| -.res)
    ~|([%record-vale-failed p.bask path.here name.here] !!)
  (vale-put lobe marc-ckey ~)
::  Sync a bole into the namespace.  One function for make, reload, and
::  cull (cull = empty bole).  Bottom-up walk: children settle before
::  parent builds its tree.  New bole is sole source of truth.
::
++  load-ball-changes
  |=  [here=fold:tarball new-bole=bole:tarball]
  ^+  this
  =/  old-born=born:nexus  born
  =.  this  (sync-bole here new-bole)
  =?  this  !=(~ here)
    (record-trees (snip `path`here))
  (notify old-born)
::  Bottom-up recursive sync: at each level, record files, delete
::  stale refs, build tree from settled born.
::
++  sync-bole
  |=  [here=fold:tarball bol=bole:tarball]
  ^+  this
  ::  1. Recurse children bottom-up (union of bole + born kids)
  =/  sub-born=born:nexus  (~(dip of born) here)
  =/  all-kids=(list @ta)
    ~(tap in (~(uni in ~(key by dir.bol)) ~(key by dir.sub-born)))
  =.  this
    |-
    ?~  all-kids  this
    =/  kid-bole=bole:tarball
      (fall (~(get by dir.bol) i.all-kids) *bole:tarball)
    =.  this  ^$(here (snoc here i.all-kids), bol kid-bole)
    $(all-kids t.all-kids)
  ::  2. Record files: store jects for bole files, [%temp ~] for stale
  =/  new-files=(map @ta [=bask:tarball gain=?])
    ?~(fil.bol ~ contents.u.fil.bol)
  =/  new-names=(set @ta)  ~(key by new-files)
  ::  Record bole files (init born if new)
  =/  to-record=(list @ta)  ~(tap in new-names)
  =.  this
    |-
    ?~  to-record  this
    =/  name=@ta  i.to-record
    =.  this  ?^((get-born [here name]) this (init-born [here name]))
    =/  entry  (~(got by new-files) name)
    =/  sok=hist:nexus  (need (get-born [here name]))
    =.  this
      (record [here name] bask.entry gain.entry `(need (top:hist:nexus sok)))
    $(to-record t.to-record)
  ::  Delete files in born but not in ball
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    fil:(~(dip of born) here)
  =/  boo  ~(. bo:nexus now.bowl born)
  =.  this
    ?~  node  this
    =/  to-delete=(list @ta)
      ~(tap in (~(dif in ~(key by file.u.node)) new-names))
    |-
    ?~  to-delete  this
    =/  sok=(unit hist:nexus)  (get-born [here i.to-delete])
    ?~  sok  $(to-delete t.to-delete)
    =/  file-cas=(unit cass:clay)  (top:hist:nexus u.sok)
    ?~  file-cas  $(to-delete t.to-delete)
    =/  cur-pace=(unit pace:hist:nexus)
      (get:hon:hist:nexus u.sok u.file-cas)
    ?:  &(?=(^ cur-pace) ?=(?(%temp %firm) -.u.cur-pace) =(~ p.u.cur-pace))
      $(to-delete t.to-delete)
    =/  new-cass=cass:clay  (next-cass:boo u.file-cas)
    =/  new-sok=hist:nexus  (put:hon:hist:nexus u.sok new-cass [%temp ~])
    =.  born  (~(put bo:nexus now.bowl born) [here i.to-delete] new-sok)
    $(to-delete t.to-delete)
  ::  3. Build tree from settled born + update fold
  ::  If bole has no content here, delete the fold
  ?:  &(=(~ fil.bol) =(~ dir.bol))
    =/  fold-node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
      fil:(~(dip of born) here)
    ?~  fold-node  this
    =/  fold-cas=(unit cass:clay)  (top:hist:nexus fold.u.fold-node)
    ?~  fold-cas  this
    =/  cur-pace=(unit pace:hist:nexus)
      (get:hon:hist:nexus fold.u.fold-node u.fold-cas)
    ?:  &(?=(^ cur-pace) ?=(?(%temp %firm) -.u.cur-pace) =(~ p.u.cur-pace))
      this
    =/  new-cass=cass:clay  (next-cass:boo u.fold-cas)
    =/  new-fold=hist:nexus
      (put:hon:hist:nexus fold.u.fold-node new-cass [%temp ~])
    this(born (~(put of born) here u.fold-node(fold new-fold)))
  ::  Build tree: file lobes + child fold lobes from born
  =/  settled-born=born:nexus  (~(dip of born) here)
  =/  settled-node=[fold=hist:nexus file=(map @ta hist:nexus)]
    (fall fil.settled-born default-node:boo)
  ::  Neck from bole
  =/  nek=(unit [neck:tarball @uv])
    ?~  fil.bol  ~
    ?~  neck.u.fil.bol  ~
    =/  =neck:tarball  u.neck.u.fil.bol
    =/  nex-ns=(unit fold:tarball)
      =/  pax=path  (weld here path.neck)
      |-
      ?~  pax  ~
      ?:  (~(has by code) pax)  `pax
      $(pax (snip `path`pax))
    =/  nex-ckey=@uv
      ?~  nex-ns  0v0
      =/  =lode:nexus  (~(got by code) u.nex-ns)
      =/  nd=(unit (map @ta @uv))
        (~(get of refs.lode) (slag (lent u.nex-ns) (weld here path.neck)))
      ?~  nd  0v0
      (fall (~(get by u.nd) name.neck) 0v0)
    `[neck nex-ckey]
  ::  File lobes from born (skip deleted/tombed)
  =/  fil=(map @ta lobe:clay)
    %-  ~(rep by file.settled-node)
    |=  [[name=@ta sk=hist:nexus] out=(map @ta lobe:clay)]
    =/  cas=(unit cass:clay)  (top:hist:nexus sk)
    ?~  cas  out
    =/  val=(unit pace:hist:nexus)  (get:hon:hist:nexus sk u.cas)
    ?~  val  out
    ?:  ?=(%tomb -.u.val)  out
    ?~  p.u.val  out
    (~(put by out) name u.p.u.val)
  ::  Dir lobes from born (skip deleted/tombed/null-lobe)
  =/  dir-map=(map @ta [lobe:clay weir=(unit weir:nexus)])
    %-  ~(rep by dir.settled-born)
    |=  [[name=@ta kid=born:nexus] out=(map @ta [lobe:clay weir=(unit weir:nexus)])]
    =/  kid-node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])  fil.kid
    ?~  kid-node  out
    =/  cas=(unit cass:clay)  (top:hist:nexus fold.u.kid-node)
    ?~  cas  out
    =/  got=(unit pace:hist:nexus)
      (get:hon:hist:nexus fold.u.kid-node u.cas)
    ?~  got  out
    ?:  ?=(%tomb -.u.got)  out
    ?~  p.u.got  out
    =/  kid-weir=(unit weir:nexus)
      =/  kid-bol=(unit bole:tarball)  (~(get by dir.bol) name)
      ?~  kid-bol  ~
      ?~  fil.u.kid-bol  ~
      weir.u.fil.u.kid-bol
    (~(put by out) name [u.p.u.got kid-weir])
  =/  tree-gain=?  ?~(fil.bol %.n gain.u.fil.bol)
  =/  =tree:nexus  [nek tree-gain ~ fil dir-map]
  =/  [changed=? new-born=born:nexus new-silo=silo:nexus]
    (put-tree:nexus born silo now.bowl here settled-node tree)
  this(born new-born, silo new-silo)
::  Mirror Clay desks to /sys/clay/desks/[desk]/
::
++  sync-clay
  ^+  this
  ~&  >>  "sync-clay: start"
  ::  Ensure /sys/clay/desks directory structure exists
  =.  this  (ensure-dir /sys/clay/desks)
  =.  this  (ensure-dir /sys/clay/desks/base)
  =.  this  (ensure-dir /sys/clay/desks/grubbery)
  ::  Sync all desks listed as kids of /sys/clay/desks/
  =/  dek=(list desk)  (lss-born /sys/clay/desks)
  ::  Update clay-state with synced desks
  =/  clay-rail=rail:tarball  [/sys/clay %'main.clay-state']
  =/  st=clay-state:nexus  [%0 (silt dek)]
  =.  this  (save-file clay-rail [[/ %clay-state] %& !>(st)])
  |-  ^+  this
  ?~  dek  this
  $(dek t.dek, this (sync-clay-desk i.dek))
::
++  sync-clay-desk
  |=  dek=desk
  ^+  this
  =/  base=path  /sys/clay/desks/[dek]
  =/  pax=path   /(scot %p our.bowl)/[dek]/(scot %da now.bowl)
  ::  Scry for all file paths in desk
  ::  Each path is like /app/foo/hoon where last element is mark
  =/  files=(list path)  .^((list path) %ct pax)
  ::  Get current files in tarball at this desk's mirror path
  =/  clay-files  (list-clay-files base)
  =/  old-files=(set path)  (silt clay-files)
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
    =/  old  (peek-grub-now:acc dir name)
    =/  res=(each vase tang)
      (validate-noun:acc / [/ mar] q.new-vase)
    ?.  ?=(%& -.res)
      ~&  [%sync-clay-vale-failed mar fyl]
      acc
    (save-file:acc [dir name] [[/ mar] %& p.res])
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
  |=  [here=fold:tarball bol=bole:tarball]
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
    =.  this  (build-code here)
    this
  ::  recurse into children
  =/  kids=(list [@ta bole:tarball])  ~(tap by dir.bol)
  |-
  ?~  kids  this
  =.  this  ^$(here (snoc here -.i.kids), bol +.i.kids)
  $(kids t.kids)
::
::  +refs-inc: increment refcounts for all ckeys in a refs axal
::  For new ckeys, stores the built value from the provided map.
::
++  refs-inc
  |=  [=refs:nexus builds=(map @uv built:nexus)]
  ^-  bins:nexus
  %+  roll  ~(tap of refs)
  |=  [[* node=(map @ta @uv)] acc=_bins]
  %+  roll  ~(tap by node)
  |=  [[* ckey=@uv] inner-acc=_acc]
  =/  existing=(unit [refs=@ud =built:nexus])  (~(get by inner-acc) ckey)
  ?^  existing
    (~(put by inner-acc) ckey u.existing(refs +(refs.u.existing)))
  =/  =built:nexus  (~(got by builds) ckey)
  (~(put by inner-acc) ckey [1 built])
::  +refs-dec: decrement refcounts for all entries in a refs axal
::
++  refs-dec
  |=  =refs:nexus
  ^-  bins:nexus
  %+  roll  ~(tap of refs)
  |=  [[* node=(map @ta @uv)] acc=_bins]
  %+  roll  ~(tap by node)
  |=  [[* ckey=@uv] inner-acc=_acc]
  =/  entry=(unit [refs=@ud =built:nexus])  (~(get by inner-acc) ckey)
  ?~  entry  inner-acc
  ?:  (lte refs.u.entry 1)
    (~(del by inner-acc) ckey)
  (~(put by inner-acc) ckey u.entry(refs (dec refs.u.entry)))
::  Seed bins with hardcoded bootstrap marcs so peek-grub can
::  validate files before the build system compiles mark files.
::
++  bootstrap-marcs
  ^+  this
  =/  marcs=(list [=blot:tarball =marc:tarball])
    :~  :-  [/ %hoon]
        |%
        ++  type  -:!>(*@t)
        ++  vale  |=(n=* !>(;;(@t n)))
        ++  grow  |=(* !!)
        ++  grab  |=(* !!)
        --
      ::
        :-  [/ %tang]
        |%
        ++  type  -:!>(*tang)
        ++  vale  |=(n=* !>(;;(tang n)))
        ++  grow  |=(* !!)
        ++  grab  |=(* !!)
        --
      ::
        :-  [/ %mime]
        |%
        ++  type  -:!>(*mime)
        ++  vale  |=(n=* !>(;;(mime n)))
        ++  grow  |=(* !!)
        ++  grab  |=(* !!)
        --
      ::
        :-  [/ %kelvin]
        |%
        ++  type  -:!>(*waft:clay)
        ++  vale  |=(n=* !>(;;(waft:clay n)))
        ++  grow  |=(* !!)
        ++  grab  |=(* !!)
        --
    ==
  %+  roll  marcs
  |=  [[=blot:tarball =marc:tarball] acc=_this]
  =/  marc-vase=vase  !>(marc)
  =/  =built:nexus  [%vase marc-vase]
  =/  ckey=@uv  (sham built)
  =.  bins.acc  (~(put by bins.acc) ckey [1 built])
  ::  Register in code namespace refs at /mar/{mark-name}
  =/  =lode:nexus  (fall (~(get by code.acc) /code) *lode:nexus)
  =/  ref-path=path  /mar
  =/  node=(map @ta @uv)
    (fall (~(get of refs.lode) ref-path) *(map @ta @uv))
  =.  node  (~(put by node) name.blot ckey)
  =.  refs.lode  (~(put of refs.lode) ref-path node)
  =.  code.acc  (~(put by code.acc) /code lode)
  acc
::  Compile a code nexus into its lode in the code map.
::  Purges non-hoon files from the code nexus.
::
++  build-code
  |=  cod=path
  ^+  this
  ~&  >  "build-code: start {(spud cod)}"
  =/  src-ball  (peek-ball-now cod)
  ::  Separate hoon and non-hoon files
  =/  all-files=(list [=rail:tarball =sang:tarball])
    ~(tap ba:tarball src-ball)
  ~&  >  "build-code: {<(lent all-files)>} files"
  =/  hoon-ball=ball:tarball
    %+  roll  all-files
    |=  [[=rail:tarball =sang:tarball] acc=_src-ball]
    ?.  =(p.sang %hoon)
      (~(del ba:tarball acc) path.rail name.rail)
    acc
  =/  mime-files=(list [=rail:tarball =sang:tarball])
    (skim all-files |=([* =sang:tarball] =([/ %mime] p.sang)))
  ::  Get or create lode for this code nexus
  =/  =lode:nexus  (fall (~(get by code) cod) *lode:nexus)
  =/  old-refs=refs:nexus  refs.lode
  ::  Reconstruct cache: join keys→refs→bins
  ~&  >  %bins-to-cache
  =/  old-cache=build-cache:build
    ~>  %bout
    (bins-to-cache:build keys.lode bins)
  ~&  >  "build-code: compiling..."
  ::  Single compilation pass: marks, libs, nexuses (hoon only)
  ~&  >  %build-all
  =/  res=build-out:build
    ~>  %bout
    (build-all:build sut src-ball old-cache)
  ~&  >  "build-code: compiled {<~(wyt by results.res)>} results"
  ~&  >  %sham-and-refs
  ::  Build refs + builds map, keyed by input ckey
  ::  Seed with mime files
  =/  [new-refs=refs:nexus builds=(map @uv built:nexus)]
    ~>  %bout
    %+  roll  mime-files
    |=  [[=rail:tarball =sang:tarball] [acc=refs:nexus bld=(map @uv built:nexus)]]
    =/  =mime  !<(mime (need-vase:tarball sang))
    =/  =built:nexus  [%mime mime]
    =/  ckey=@uv  (sham built)
    =/  node=(map @ta @uv)
      (fall (~(get of acc) path.rail) *(map @ta @uv))
    [(~(put of acc) path.rail (~(put by node) name.rail ckey)) (~(put by bld) ckey built)]
  ::  Add compiled hoon results
  ~&  >  %sham-hoon-results
  =^  new-refs  builds
    ~>  %bout
    %+  roll  ~(tap by results.res)
    |=  [[=rail:tarball =build-result:build] [acc=_new-refs bld=_builds]]
    =/  stem=@ta  (strip-hoon:build name.rail)
    ::  Skip bootstrap marks — these are seeded by bootstrap-marcs and
    ::  must not be replaced, or leaf ject ckeys become stale.
    ?:  ?&  =(path.rail /mar)
            ?=(?(%hoon %tang %mime %kelvin) stem)
        ==
      [acc bld]
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
    =/  ckey=@uv  (~(got by keys.res) rail)
    =/  node=(map @ta @uv)
      (fall (~(get of acc) path.rail) *(map @ta @uv))
    [(~(put of acc) path.rail (~(put by node) stem ckey)) (~(put by bld) ckey built)]
  ::  Carry bootstrap mark refs from old-refs into new-refs so they
  ::  survive the inc/dec cycle (bootstrap-marcs is authoritative).
  =/  old-mar=(map @ta @uv)
    (fall (~(get of old-refs) /mar) *(map @ta @uv))
  =/  merged-refs=refs:nexus  new-refs
  =/  cur-mar=(map @ta @uv)
    (fall (~(get of merged-refs) /mar) *(map @ta @uv))
  =/  boot=(list @ta)  ~[%hoon %tang %mime %kelvin]
  =/  patched=(map @ta @uv)
    %+  roll  boot
    |=  [nam=@ta acc=_cur-mar]
    =/  old-ckey=(unit @uv)  (~(get by old-mar) nam)
    ?~  old-ckey  acc
    (~(put by acc) nam u.old-ckey)
  =.  new-refs  (~(put of merged-refs) /mar patched)
  ::  Update global bins: increment new, decrement old
  ~&  >  %refs-inc
  =.  bins  ~>(%bout (refs-inc new-refs builds))
  ::  Decrement old refs, update lode
  ~&  >  %refs-dec
  =.  bins  ~>(%bout (refs-dec old-refs))
  ::  GC vale cache: drop entries whose marc ckey was removed from bins
  =.  vale
    %-  ~(gas by *(map [lobe:clay @uv] (unit tang)))
    %+  skip  ~(tap by vale)
    |=  [[* ckey=@uv] *]
    !(~(has by bins) ckey)
  =.  lode  [keys.res deps.res new-refs]
  =.  code  (~(put by code) cod lode)
  ::  Validate marks: clam existing grubs through changed marks
  ~&  >  %validate-marks
  =^  new-refs  this
    ~>  %bout
    (validate-marks cod old-refs new-refs)
  =/  upd-lode=lode:nexus  (fall (~(get by code) cod) *lode:nexus)
  =.  code  (~(put by code) cod upd-lode(refs new-refs))
  ::  Reload nexuses whose compiled code changed
  ~&  >  %reload-changed-nexuses
  =.  this
    ~>  %bout
    (reload-changed-nexuses cod old-refs new-refs)
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
  =/  sub=ball:tarball  (peek-ball-now scope)
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
  ^-  (list [=rail:tarball =sang:tarball])
  =/  dirs=(list [=fold:tarball =lump:tarball])  (governed-dirs cod)
  %-  zing
  %+  turn  dirs
  |=  [=fold:tarball =lump:tarball]
  %+  turn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  [[fold name] sang]
::  and clam all grubs with that mark through validate-vase.
::  On success, updates grubs in ball with clammed vases.
::  On failure, downgrades the mark to .tang in new-bin.
::
++  validate-marks
  |=  [cod=path old-refs=refs:nexus new-refs=refs:nexus]
  ^+  [new-refs this]
  ::  Walk /mar subtree to find changed marks by comparing ckeys
  =/  mar-sub=refs:nexus  (~(dip of new-refs) /mar)
  =/  old-sub=refs:nexus  (~(dip of old-refs) /mar)
  =/  all-new=(list [pax=path node=(map @ta @uv)])
    ~(tap of mar-sub)
  ::  Find changed blots (ckey differs or newly added)
  =/  changed=(list [ckey=@uv =blot:tarball =built:nexus])
    %-  zing
    %+  turn  all-new
    |=  [pax=path node=(map @ta @uv)]
    %+  murn  ~(tap by node)
    |=  [nam=@ta ckey=@uv]
    =/  old-node=(map @ta @uv)
      (fall (~(get of old-sub) pax) *(map @ta @uv))
    =/  old-key=(unit @uv)  (~(get by old-node) nam)
    ?:  =(old-key `ckey)  ~
    =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) ckey)
    ?~  entry  ~
    `[ckey [pax nam] built.u.entry]
  ::  Collect all governed files once (expensive tree walk)
  =/  all-grubs=(list [=rail:tarball =sang:tarball])  (governed-files cod)
  ::  Process each changed mark
  =/  remaining=_changed  changed
  |-
  ?~  remaining  [new-refs this]
  =/  [ckey=@uv =blot:tarball =built:nexus]  i.remaining
  =/  nam=@tas  (rail-to-arm:tarball blot)
  ::  Skip bootstrap marks — these are hardcoded in validate-noun
  ::  and can't meaningfully change. Re-validating all .hoon/.mime/etc
  ::  files would cascade into build-code loops.
  ?:  ?=(?(%hoon %tang %mime %kelvin) nam)
    $(remaining t.remaining)
  ::  Find all grubs with this mark
  =/  grubs=(list [=rail:tarball =sang:tarball])
    %+  skim  all-grubs
    |=  [=rail:tarball =sang:tarball]
    =(name.blot name.p.sang)
  ?~  grubs  $(remaining t.remaining)
  ::  Get marc, or skip if mark failed to compile
  =/  marc-res=(each marc:tarball tang)
    ?.  ?=(%vase -.built)
      |+?:(?=(%tang -.built) tang.built ~[leaf+"validate-marks: {(trip nam)} failed"])
    (mule |.(!<(marc:tarball vase.built)))
  ?:  ?=(%| -.marc-res)
    ~&  >>  "validate-marks: {(trip nam)} marc failed"
    $(remaining t.remaining)
  ::  Validate each grub, threading state for cache
  =/  grubs=(list [=rail:tarball =sang:tarball])  grubs
  =/  [n-ok=@ud n-boom=@ud]  [0 0]
  =.  this
    |-
    ?~  grubs  this
    =/  [=rail:tarball =sang:tarball]  i.grubs
    =/  noun=*  (sang-noun:tarball sang)
    ::  TODO: pass lobe instead of hashing noun
    =/  lob=lobe:clay  (sham noun)
    =/  hit  (vale-hit lob ckey)
    =/  res=(each vase tang)
      ?^  hit
        ?~  u.hit  &+[type:p.marc-res noun]
        |+u.u.hit
      =/  val  (validate-vase vale:p.marc-res noun)
      ?:(?=(%| -.val) val &+[type:p.marc-res noun])
    =?  this  ?=(~ hit)
      (vale-put lob ckey ?:(?=(%& -.res) ~ `p.res))
    ?:  ?=(%& -.res)
      =.  this  (save-file rail [p.sang %& p.res])
      =.  n-ok  +(n-ok)
      $(grubs t.grubs)
    ~&  >>  "validate-marks: boom {(spud (snoc path.rail name.rail))}"
    =.  this
      (save-file rail [blot %| [p.res noun]])
    =.  n-boom  +(n-boom)
    $(grubs t.grubs)
  ~&  >  "validate-marks: {(trip nam)} — {<n-ok>} ok, {<n-boom>} boom"
  $(remaining t.remaining)
::  Reload nexuses: for each changed nexus in bin/nex/, find all
::  directories using that neck, run on-load with the new code, and
::  apply the results (like reload-nexus). Crashes if any on-load fails.
::
++  reload-changed-nexuses
  |=  [cod=path old-refs=refs:nexus new-refs=refs:nexus]
  ^+  this
  ::  Find nexuses in /nex whose ckey changed
  =/  nex-sub=refs:nexus  (~(dip of new-refs) /nex)
  =/  old-sub=refs:nexus  (~(dip of old-refs) /nex)
  =/  all-new=(list [pax=path node=(map @ta @uv)])
    ~(tap of nex-sub)
  =/  changed=(list [=neck:tarball =built:nexus])
    %-  zing
    %+  turn  all-new
    |=  [pax=path node=(map @ta @uv)]
    %+  murn  ~(tap by node)
    |=  [nam=@ta ckey=@uv]
    =/  old-node=(map @ta @uv)
      (fall (~(get of old-sub) pax) *(map @ta @uv))
    =/  old-ckey=(unit @uv)  (~(get by old-node) nam)
    ?:  =(old-ckey `ckey)  ~
    =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) ckey)
    ?~  entry  ~
    `[[pax nam] built.u.entry]
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
  =/  reload-bole  (peek-bole-now dest)
  =.  this  (spawn-all-files dest reload-bole)
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
      =/  val=(each ^vase tang)  (validate-noun /code [/ %kelvin] q.vase)
      ?.  ?=(%& -.val)
        ~&  >>>  "sync-gub: kelvin validation failed"
        acc
      (~(put ba:tarball acc) [/ %'sys.kelvin'] [[/ %kelvin] %& p.val])
    ?:  =(mar %hoon)
      =/  =vase  .^(vase %cr (weld pax fyl))
      =/  val=(each ^vase tang)  (validate-noun /code [/ mar] q.vase)
      ?.  ?=(%& -.val)
        ~&  >>>  "sync-gub: validation failed for {(trip name)}: {(trip (render-tang:build p.val))}"
        acc
      (~(put ba:tarball acc) [rel-dir name] [[/ mar] %& p.val])
    ::  Non-hoon: convert to mime via tube, validate as %mime
    =/  =vase  .^(vase %cr (weld pax fyl))
    =/  tub=tube:clay  .^(tube:clay %cc (weld pax /[mar]/mime))
    =/  =mime  !<(mime (tub vase))
    =/  val=(each ^vase tang)  (validate-noun /code [/ %mime] [p q]:mime)
    ?.  ?=(%& -.val)
      ~&  >>>  "sync-gub: mime validation failed for {(trip name)}"
      acc
    (~(put ba:tarball acc) [rel-dir name] [[/ %mime] %& p.val])
  ::  Ensure %code neck on the source ball
  =/  src-lump=lump:tarball  (fall fil.new-src *lump:tarball)
  =.  new-src  new-src(fil `src-lump(neck `[/ %code]))
  ::  Get old ball at /code/
  =/  old-src  (peek-ball-now /code)
  ::  Diff and bump src changes (born, silo, hist, notify)
  ~&  >  "sync-gub: load-ball-changes start"
  =.  this  (load-ball-changes /code (ball-to-bole:tarball new-src))
  ~&  >  "sync-gub: load-ball-changes done"
  ::  Compile
  ~&  >  "sync-gub: build-code start"
  =.  this  (build-code /code)
  ~&  >  "sync-gub: build-code done"
  this
::  List all files mirrored under a /sys/clay/desks/[desk] path
::  Returns Clay-style paths (like /app/foo/hoon) with mark as last element
::
++  list-clay-files
  |=  base=path
  ^-  (list path)
  (ball-to-paths / (peek-ball-now base))
::
++  ball-to-paths
  |=  [prefix=path bal=ball:tarball]
  ^-  (list path)
  =/  files=(list path)
    ?~  fil.bal  ~
    %+  turn  ~(tap by contents.u.fil.bal)
    |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
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
  (cull [%| /sys/clay/desks/[dek]])
::  Subscribe to dill logs and sessions, create grubs for both.
::
++  sync-dill
  ^+  this
  ::  Create dill/logs grub and subscribe
  =.  this  (save-file [/sys/dill %'logs.dill-told'] [[/ %dill-told] %& !>(*told:dill)])
  =.  this  (emit-card [%pass /dill/logs %arvo %d %logs `~])
  ::  Scry for sessions
  =/  sessions=(list @tas)
    ~(tap in .^((set @tas) %dy /(scot %p our.bowl)/$/(scot %da now.bowl)/sessions))
  ::  Unsubscribe from sessions no longer in dill
  =/  old=(list @ta)  (lis-born /sys/dill/sessions)
  =/  new=(set @tas)  (~(gas in *(set @tas)) sessions)
  =.  this
    %-  emit-cards
    %+  murn  old
    |=  ses=@ta
    ?:  (~(has in new) ses)  ~
    `[%pass /dill/session/[ses] %arvo %d %shot ses %flee ~]
  ::  Create grubs and subscribe
  =.  this
    %+  roll  sessions
    |=  [ses=@tas acc=_this]
    (save-file:acc [/sys/dill/sessions ses] [[/ %dill-blit] %& !>(*(list blit:dill))])
  %-  emit-cards
  %+  turn  sessions
  |=(ses=@tas [%pass /dill/session/[ses] %arvo %d %shot ses %view ~])
::
++  sync-jael
  ^+  this
  ::  Ensure jael directory exists (properly tracked via load-ball-changes)
  =.  this  (ensure-dir /sys/jael)
  ::  Create grubs and subscribe
  =.  this
    (save-file [/sys/jael %'private-keys.jael-private-keys'] [[/ %jael-private-keys] %& !>(*[life (map life ring)])])
  =.  this
    (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [[/ %jael-public-keys-result] %& !>(*public-keys-result:jael)])
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
  (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [[/ %jael-public-keys-result] %& !>(public-keys-result)])
::  /sys/gall: materialized gall subscriptions
::
::  Poke %grubbery with %gall-watch to subscribe to a gall agent.
::  Incoming facts are validated via marc and materialized as files.
::  Any grub can peek or watch the materialized data.
::
::  Poke format:
::    %gall-watch  [ship=@p agent=dude:gall path=path]
::    %gall-leave  [ship=@p agent=dude:gall path=path]
::
::  Directory structure per subscription:
::    /sys/gall/[ship]/[agent]/[path...]/
::      data         latest fact (blot from incoming cage mark)
::      live         loob: %.y when subscribed, %.n on kick/nack
::
::  Behavior:
::    - On %fact: look up marc for cage mark in /code/mar, validate,
::      save-file to data. Skip if no marc found.
::    - On %kick: set live to %.n, auto-resubscribe, set live to
::      %.y on successful %watch-ack.
::    - On %watch-ack with error: set live to %.n, don't retry.
::    - All files retain history in silo.
::    - Wire format: /gall-sub/{ship}/{agent}/{path...}
::
::
++  gall-sub-dir
  |=  [=ship agent=dude:gall =path]
  ^-  ^path
  (weld /sys/gall/subs/[(scot %p ship)]/[agent] path)
::
++  gall-sub-wire
  |=  [=ship agent=dude:gall =path]
  ^-  wire
  (weld /gall-sub/[(scot %p ship)]/[agent] path)
::  Subscribe to a gall agent, materialize at /sys/gall/
::
++  gall-sub
  |=  [=ship agent=dude:gall =path]
  ^+  this
  =/  dir=^path  (gall-sub-dir ship agent path)
  =/  wir=wire   (gall-sub-wire ship agent path)
  ::  Ensure directory exists
  =.  this  (ensure-dir dir)
  ::  Create live file (%.y = subscribing)
  =.  this  (save-file [dir %live] [[/ %loob] %& !>(%.y)])
  ::  Subscribe
  ~&  >  "gall-sub: subscribing to {<ship>}/{(trip agent)}/{(spud path)}"
  (emit-card [%pass wir %agent [ship agent] %watch path])
::  Unsubscribe from a materialized gall subscription
::
++  gall-unsub
  |=  [=ship agent=dude:gall =path]
  ^+  this
  =/  dir=^path  (gall-sub-dir ship agent path)
  =/  wir=wire   (gall-sub-wire ship agent path)
  ~&  >  "gall-unsub: leaving {<ship>}/{(trip agent)}/{(spud path)}"
  =.  this  (emit-card [%pass wir %agent [ship agent] %leave ~])
  ::  Delete the subscription tree
  =.  pool  (~(lop of pool) dir)
  (load-ball-changes dir *bole:tarball)
::  Handle signs from materialized gall subscriptions
::
++  take-gall-sub
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  ::  Parse wire: /[ship]/[agent]/[path...]
  ?>  ?=([@ @ *] wir)
  =/  =ship  (slav %p i.wir)
  =/  agent=dude:gall  i.t.wir
  =/  =path  t.t.wir
  =/  dir=^path  (gall-sub-dir ship agent path)
  ?-    -.sign
      %poke-ack
    ~&  >>>  "gall-sub: unexpected poke-ack on sub wire"
    this
  ::
      %watch-ack
    ?~  p.sign
      ::  Success — set live to %.y
      ~&  >  "gall-sub: watch-ack ok {<ship>}/{(trip agent)}/{(spud path)}"
      (save-file [dir %live] [[/ %loob] %& !>(%.y)])
    ::  Failed — set live to %.n, don't retry
    ~&  >>>  "gall-sub: watch-ack failed {<ship>}/{(trip agent)}/{(spud path)}"
    %-  (slog u.p.sign)
    (save-file [dir %live] [[/ %loob] %& !>(%.n)])
  ::
      %fact
    ::  Validate via marc, save to data
    =/  mar=@tas  p.cage.sign
    =/  =blot:tarball  [/ mar]
    =/  vale=(unit $-(* vase))
      =/  res=(unit built:nexus)  (get-built / (weld /mar path.blot) name.blot)
      ?~  res  ~
      ?.  ?=(%vase -.u.res)  ~
      (mole |.(vale:!<(marc:tarball vase.u.res)))
    ?~  vale
      ::  No marc — fall back to page (original mark + raw noun)
      ~&  >  "gall-sub: no marc for {<mar>}, storing as page"
      (save-file [dir %data] [[/ %page] %& !>(`[p=@tas q=*]`[mar q.q.cage.sign])])
    =/  res=(each vase tang)
      (validate-vase u.vale q.q.cage.sign)
    ?.  ?=(%& -.res)
      ~&  >>>  "gall-sub: vale failed for {<mar>}"
      this
    (save-file [dir %data] [[/ mar] %& p.res])
  ::
      %kick
    ::  Set live to %.n, auto-resubscribe
    ~&  >  "gall-sub: kicked from {<ship>}/{(trip agent)}/{(spud path)}, resubscribing"
    =.  this  (save-file [dir %live] [[/ %loob] %& !>(%.n)])
    (emit-card [%pass (gall-sub-wire ship agent path) %agent [ship agent] %watch path])
  ==
::  Resubscribe all existing gall subs on reload
::
++  sync-gall
  ^+  this
  =.  this  (ensure-dir /sys/gall)
  ::  Walk existing subscriptions under /sys/gall/subs/
  =/  subs=ball:tarball  (peek-ball-now /sys/gall/subs)
  =/  ships=(list [@ta ball:tarball])  ~(tap by dir.subs)
  |-
  ?~  ships  this
  =/  [ship-ta=@ta ship-ball=ball:tarball]  i.ships
  =/  agents=(list [@ta ball:tarball])  ~(tap by dir.ship-ball)
  =.  this
    |-
    ?~  agents  this
    =/  [agent-ta=@ta agent-ball=ball:tarball]  i.agents
    =.  this  (resub-gall-tree ship-ta agent-ta / agent-ball)
    $(agents t.agents)
  $(ships t.ships)
::  Recursively find subscription leaves (dirs with a 'live' file)
::  and resubscribe them.
::
++  resub-gall-tree
  |=  [ship-ta=@ta agent-ta=@ta pax=path sub=ball:tarball]
  ^+  this
  ::  If this dir has a live file, it's a subscription leaf — resubscribe
  =/  has-live=?
    ?&  ?=(^ fil.sub)
        (~(has by contents.u.fil.sub) %live)
    ==
  =.  this
    ?.  has-live  this
    =/  =ship  (slav %p ship-ta)
    =/  agent=dude:gall  agent-ta
    =/  wir=wire  (gall-sub-wire ship agent pax)
    ~&  >  "sync-gall: resubscribing {<ship>}/{(trip agent)}/{(spud pax)}"
    (emit-card [%pass wir %agent [ship agent] %watch pax])
  ::  Recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub)
  |-
  ?~  kids  this
  =.  this  ^$(pax (snoc pax -.i.kids), sub +.i.kids)
  $(kids t.kids)
::
::  /sys/ames: runtime-owned peer infrastructure
::
::  Creates /sys/ames/ directory structure for foreign ship management.
::  Usergroups are per-group directories with who.ships and how.weir files.
::  Ship directories are created lazily on first foreign poke.
::  Weirs recompute atomically on any usergroup change.
::
++  sync-bowl
  ^+  this
  ::  seed /sys/bowl/ with save-file (proper silo entries + notify).
  ::  no loop: explorer peeks at cass on news, not latest.
  =.  this  (ensure-dir /sys/bowl)
  =.  this  (save-file [/sys/bowl %our] [[/ %ship] %& !>(our.bowl)])
  =.  this  (save-file [/sys/bowl %now] [[/ %time] %& !>(now.bowl)])
  (save-file [/sys/bowl %eny] [[/ %entropy] %& !>(eny.bowl)])
::
++  sync-peer
  ^+  this
  =.  this  (ensure-dir /sys/ames)
  =.  this  (ensure-dir /sys/ames/usergroups)
  =.  this  (ensure-dir /sys/ames/ships)
  =.  this  ensure-public-group
  (ensure-peer-ship our.bowl)
::  Ensure /sys/ames/usergroups/public/ exists with who.ships and how.weir.
::  The public group's weir applies to all foreign ships regardless of membership.
::
++  ensure-public-group
  ^+  this
  =/  pub-dir=path  /sys/ames/usergroups/public
  =/  who-rail=rail:tarball  [pub-dir %'who.ships']
  =/  how-rail=rail:tarball  [pub-dir %'how.weir']
  =.  this  (ensure-dir pub-dir)
  =?  this  =(~ (~(get bo:nexus now.bowl born) pub-dir %'who.ships'))
    (save-file who-rail [[/ %ships] %& !>(*(set @p))])
  =?  this  =(~ (~(get bo:nexus now.bowl born) pub-dir %'how.weir'))
    (save-file how-rail [[/ %weir] %& !>(*weir:nexus)])
  this
::  Ensure /sys/ames/ships/~ship/ exists with ship.sig and computed weir.
::  Our ship gets no weir (full access). Foreign ships get weir from usergroups.
::
++  ensure-peer-ship
  |=  src=@p
  ^+  this
  =/  ship-ta=@ta  (scot %p src)
  =/  ship-dir=path  /sys/ames/ships/[ship-ta]
  ::  Always ensure dir, /root, and ship.sig exist
  =.  this  (ensure-dir ship-dir)
  =.  this  (ensure-dir (weld ship-dir /root))
  =?  this  =(~ (~(get bo:nexus now.bowl born) ship-dir %'ship.sig'))
    =/  ship-rail=rail:tarball  [ship-dir %'ship.sig']
    =.  this  (save-file ship-rail [[/ %sig] %& !>(~)])
    (spawn-proc ship-rail [%load ~])
  ::  Set weir (our ship gets none — full access)
  ?:  =(src our.bowl)  this
  =/  =weir:nexus  (compute-peer-weir src)
  (set-weir ship-dir `weir)
::  Compute weir for a ship from usergroup data.
::  Union of all group weirs the ship belongs to, plus public weir.
::
++  read-peer-who
  ^-  (map @ta (set @p))
  =/  ug=ball:tarball
    (peek-ball-now /sys/ames/usergroups)
  %-  ~(gas by *(map @ta (set @p)))
  %+  murn  ~(tap in ~(key by dir.ug))
  |=  name=@ta
  ^-  (unit [@ta (set @p)])
  =/  grp=ball:tarball  (~(dip ba:tarball ug) /[name])
  =/  c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'who.ships'])
  ?~  c  ~
  =/  res  (mule |.(!<((set @p) (need-vase:tarball u.c))))
  ?:(?=(%| -.res) ~ `[name p.res])
::
++  read-peer-how
  ^-  (map @ta weir:nexus)
  =/  ug=ball:tarball
    (peek-ball-now /sys/ames/usergroups)
  %-  ~(gas by *(map @ta weir:nexus))
  %+  murn  ~(tap in ~(key by dir.ug))
  |=  name=@ta
  ^-  (unit [@ta weir:nexus])
  =/  grp=ball:tarball  (~(dip ba:tarball ug) /[name])
  =/  c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'how.weir'])
  ?~  c  ~
  =/  res  (mule |.(!<(weir:nexus (need-vase:tarball u.c))))
  ?:(?=(%| -.res) ~ `[name p.res])
::  Build reverse index: ship → group names
::
++  build-peer-src
  |=  who=(map @ta (set @p))
  ^-  (map @p (set @ta))
  =/  groups=(list [@ta (set @p)])  ~(tap by who)
  =|  acc=(map @p (set @ta))
  |-
  ?~  groups  acc
  =/  [name=@ta members=(set @p)]  i.groups
  =/  ships=(list @p)  ~(tap in members)
  =.  acc
    |-
    ?~  ships  acc
    =/  existing=(set @ta)  (fall (~(get by acc) i.ships) ~)
    $(ships t.ships, acc (~(put by acc) i.ships (~(put in existing) name)))
  $(groups t.groups)
::  Union two weirs
::
++  union-weirs
  |=  [a=weir:nexus b=weir:nexus]
  ^-  weir:nexus
  :+  (~(uni in make.a) make.b)
    (~(uni in poke.a) poke.b)
  (~(uni in peek.a) peek.b)
::  Compute weir for a ship from usergroup data.
::  Union of all group weirs the ship belongs to, plus public weir.
::
++  compute-peer-weir
  |=  =ship
  ^-  weir:nexus
  =/  who=(map @ta (set @p))  read-peer-who
  =/  how=(map @ta weir:nexus)  read-peer-how
  (compute-peer-weir-from ship (build-peer-src who) how)
::
++  compute-peer-weir-from
  |=  [=ship src=(map @p (set @ta)) how=(map @ta weir:nexus)]
  ^-  weir:nexus
  =/  public-weir=weir:nexus
    (fall (~(get by how) %public) *weir:nexus)
  =/  ship-groups=(set @ta)
    (fall (~(get by src) ship) ~)
  =/  ship-weir=weir:nexus
    %+  roll  ~(tap in ship-groups)
    |=  [name=@ta acc=weir:nexus]
    (union-weirs acc (fall (~(get by how) name) *weir:nexus))
  (union-weirs ship-weir public-weir)
::  Recompute weirs for all foreign ship directories.
::  Called when usergroup data changes. Lazily creates ship dirs
::  for ships in usergroups that don't have dirs yet.
::
++  recompute-peer-weirs
  ^+  this
  =/  who=(map @ta (set @p))  read-peer-who
  =/  how=(map @ta weir:nexus)  read-peer-how
  =/  src=(map @p (set @ta))  (build-peer-src who)
  ::  Collect all ships from usergroups + existing ship dirs
  =/  all-members=(set @p)
    %-  ~(gas in *(set @p))
    %-  zing
    %+  turn  ~(val by who)
    |=  members=(set @p)
    ~(tap in members)
  =/  ships-ball=ball:tarball
    (peek-ball-now /sys/ames/ships)
  =/  existing=(set @p)
    %-  ~(gas in *(set @p))
    %+  murn  ~(tap in ~(key by dir.ships-ball))
    |=(name=@ta (slaw %p name))
  =/  all-ships=(list @p)  ~(tap in (~(uni in all-members) existing))
  |-
  ?~  all-ships  this
  =/  =ship  i.all-ships
  ?:  =(ship our.bowl)
    $(all-ships t.all-ships)
  =.  this  (ensure-peer-ship ship)
  =/  =weir:nexus  (compute-peer-weir-from ship src how)
  =.  this  (set-weir /sys/ames/ships/[(scot %p ship)] `weir)
  $(all-ships t.all-ships)
::  /sys/eyre: ensure directory structure + register /grubbery/api
::
++  sync-eyre
  ^+  this
  ::  Ensure /sys/eyre directory structure exists
  =.  this  (ensure-dir /sys/eyre)
  =.  this  (ensure-dir /sys/eyre/requests)
  ::  Register /grubbery/api and /grubbery/push with eyre
  %-  emit-cards
  :~  [%pass /eyre-api %arvo %e %connect [~ /grubbery/api] dap.bowl]
      [%pass /eyre-push %arvo %e %connect [~ /grubbery/push] dap.bowl]
  ==
::
::  /sys/eyre: read/write server state, find bindings
::
++  get-server-state
  ^-  server-state:nexus
  =/  eyre-rail=rail:tarball  [/sys/eyre %'main.server-state']
  =/  old=(unit sang:tarball)  (peek-grub-now eyre-rail)
  ?~  old  *server-state:nexus
  ?:  (is-boom:tarball u.old)  *server-state:nexus
  !<(server-state:nexus (need-vase:tarball u.old))
::
++  save-server-state
  |=  st=server-state:nexus
  ^+  this
  (save-file [/sys/eyre %'main.server-state'] [[/ %server-state] %& !>(st)])
::
++  find-eyre-binding
  |=  [bindings=(map binding:eyre rail:tarball) site=path]
  ^-  (unit [=binding:eyre handler=rail:tarball])
  =|  best=(unit [=binding:eyre handler=rail:tarball])
  =/  entries=(list [=binding:eyre handler=rail:tarball])
    ~(tap by bindings)
  |-
  ?~  entries  best
  =/  suffix=(unit path)
    =+  [prefix=path.binding.i.entries full=site]
    |-  ^-  (unit path)
    ?~  prefix  `full
    ?~  full    ~
    ?.  =(i.prefix i.full)  ~
    $(prefix t.prefix, full t.full)
  ?~  suffix
    $(entries t.entries)
  ?~  best  $(best `i.entries, entries t.entries)
  ?:  (gth (lent path.binding.i.entries) (lent path.binding.u.best))
    $(best `i.entries, entries t.entries)
  $(entries t.entries)
::  /sys/push: ensure directory structure
::
++  sync-push
  ^+  this
  =.  this  (ensure-dir /sys/push)
  ::  Auto-init VAPID keypair if not yet configured
  =/  st=push-state:nexus  get-push-state
  ?^  config.st  this
  =/  sub=@t  (rap 3 ~['mailto:' (scot %p our.bowl) '@urbit.org'])
  =/  new-config=push-config:push  (generate-vapid-keypair:web-push eny.bowl sub)
  ~&  >>  "%push: generated VAPID keypair"
  (save-push-state st(config `new-config))
::
::  /sys/push: read/write push state
::
++  get-push-state
  ^-  push-state:nexus
  =/  push-rail=rail:tarball  [/sys/push %'main.push-state']
  =/  old=(unit sang:tarball)  (peek-grub-now push-rail)
  ?~  old  *push-state:nexus
  !<(push-state:nexus (need-vase:tarball u.old))
::
++  save-push-state
  |=  st=push-state:nexus
  ^+  this
  (save-file [/sys/push %'main.push-state'] [[/ %push-state] %& !>(st)])
::
++  handle-push-action
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  act=push-action:nexus  !<(push-action:nexus vaz)
  =/  st=push-state:nexus  get-push-state
  ?-    -.act
      %init
    ?^  config.st  this  :: already initialized
    =/  new-config=push-config:push  (generate-vapid-keypair:web-push eny.act sub.act)
    (save-push-state st(config `new-config))
  ::
      %subscribe
    =.  subs.st  (~(put by subs.st) sub-id.act [ship.act subscription.act])
    (save-push-state st)
  ::
      %unsubscribe
    =.  subs.st  (~(del by subs.st) sub-id.act)
    (save-push-state st)
  ::
      %send
    ?~  config.st  this
    =/  config=push-config:push  u.config.st
    =/  msg=push-message:push  msg.push-send.act
    =/  payload=octs  (message-to-json:web-push msg)
    ::  Determine target subscriptions
    =/  target-subs=(list [@ta push-sub:nexus])
      %+  skim  ~(tap by subs.st)
      |=  [id=@ta ps=push-sub:nexus]
      ?:  (~(has in exclude.push-send.act) ship.ps)  %.n
      ?:  =(~ targets.push-send.act)  %.y  :: empty = all
      (~(has in targets.push-send.act) ship.ps)
    ::  Send to each subscription
    =/  unix-now=@ud  (div (sub now.bowl ~1970.1.1) ~s1)
    =/  exp=@ud  (add unix-now 86.400)
    |-
    ?~  target-subs  this
    =/  [sub-id=@ta ps=push-sub:nexus]  i.target-subs
    =/  sub=subscription:push  subscription.ps
    =/  req=request:http
      (send-notification:web-push sub config payload exp eny.act)
    ::  Build push wire: /push/send/{path-len}/{path...}/{name}/{sub-id}
    =/  push-wire=path
      :-  %push
      :-  %send
      :-  (scot %ud (lent path.sender))
      (weld path.sender [name.sender sub-id ~])
    =.  inflight.st  (~(put by inflight.st) push-wire sender)
    =.  this  (save-push-state st)
    =.  this  (emit-card [%pass push-wire %arvo %i %request req *outbound-config:iris])
    $(target-subs t.target-subs)
  ==
::
++  handle-push-response
  |=  [segs=wire =client-response:iris]
  ^+  this
  =/  st=push-state:nexus  get-push-state
  =/  push-wire=path  [%push %send segs]
  =.  inflight.st  (~(del by inflight.st) push-wire)
  ::  If push service returns 404/410, subscription is stale — remove it
  ?:  ?=(%finished -.client-response)
    =/  code=@ud  status-code.response-header.client-response
    ?:  |(=(404 code) =(410 code))
      ::  Extract sub-id from wire (last segment)
      =/  sub-id=@ta  (rear segs)
      =.  subs.st  (~(del by subs.st) sub-id)
      (save-push-state st)
    (save-push-state st)
  (save-push-state st)
::
++  handle-push-http
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre site=path args=quay:eyre]
  ^+  this
  =/  respond
    |=  =simple-payload:http
    ^+  this
    (emit-cards (give-simple-payload:app:server eyre-id simple-payload))
  =/  json-ok
    |=  =json
    =/  body=@t  (en:json:html json)
    (respond [[200 ['content-type' 'application/json'] ~] `(as-octs:mimes:html body)])
  ::  Serve service worker publicly (no auth required)
  ?:  ?=([%sw ~] site)
    =/  sw-js=@t
      '''
      self.addEventListener('install', function(e) { self.skipWaiting(); });
      self.addEventListener('activate', function(e) { e.waitUntil(clients.claim()); });
      self.addEventListener('push', function(event) {
        var data = event.data ? event.data.json() : {};
        var title = data.title || 'Notification';
        var options = {
          body: data.body || '',
          icon: data.icon || '/grubbery/ball/favicon.svg',
          tag: data.tag || 'default',
          data: { url: data.url || '/grubbery/ball/' }
        };
        event.waitUntil(self.registration.showNotification(title, options));
      });

      self.addEventListener('notificationclick', function(event) {
        event.notification.close();
        const url = event.notification.data && event.notification.data.url;
        if (url) {
          event.waitUntil(clients.openWindow(url));
        }
      });
      '''
    (respond [[200 ['content-type' 'application/javascript'] ['service-worker-allowed' '/'] ~] `(as-octs:mimes:html sw-js)])
  ::  All other push routes require authentication
  ?.  authenticated.req
    (respond [[403 ~] `(as-octs:mimes:html '"not authenticated"')])
  ?+    site
    (respond [[404 ~] `(as-octs:mimes:html '"not found"')])
  ::
      [%vapid-key ~]
    ::  GET: return VAPID public key as base64url
    =/  st=push-state:nexus  get-push-state
    ?~  config.st
      (respond [[503 ~] `(as-octs:mimes:html '"push not configured"')])
    =/  pub-b64=@t
      (en-base64url:web-push [65 (rev 3 65 public-key.u.config.st)])
    (respond [[200 ['content-type' 'text/plain'] ~] `(as-octs:mimes:html pub-b64)])
  ::
      [%subscribe ~]
    ::  POST: save browser push subscription
    ?.  =(%'POST' method.request.req)
      (respond [[405 ~] `(as-octs:mimes:html '"method not allowed"')])
    ?~  body.request.req
      (respond [[400 ~] `(as-octs:mimes:html '"missing body"')])
    =/  jon=(unit json)  (de:json:html q.u.body.request.req)
    ?~  jon
      (respond [[400 ~] `(as-octs:mimes:html '"invalid json"')])
    ?.  ?=(%o -.u.jon)
      (respond [[400 ~] `(as-octs:mimes:html '"expected object"')])
    =/  obj=(map @t json)  p.u.jon
    =/  endpoint=(unit @t)
      ?~  e=(~(get by obj) 'endpoint')  ~
      ?.  ?=([~ %s *] e)  ~
      `p.u.e
    =/  p256dh=(unit @t)
      ?~  k=(~(get by obj) 'p256dh')  ~
      ?.  ?=([~ %s *] k)  ~
      `p.u.k
    =/  auth-key=(unit @t)
      ?~  a=(~(get by obj) 'auth')  ~
      ?.  ?=([~ %s *] a)  ~
      `p.u.a
    ?:  |(?=(~ endpoint) ?=(~ p256dh) ?=(~ auth-key))
      (respond [[400 ~] `(as-octs:mimes:html '"missing endpoint, p256dh, or auth"')])
    ::  Decode base64url keys to raw bytes
    =/  p256dh-octs=(unit octs)  (de-base64url:web-push u.p256dh)
    =/  auth-octs=(unit octs)    (de-base64url:web-push u.auth-key)
    ?:  |(?=(~ p256dh-octs) ?=(~ auth-octs))
      (respond [[400 ~] `(as-octs:mimes:html '"invalid key encoding"')])
    ::  Convert to MSB-first atoms (crypto convention)
    =/  p256dh-raw=@  (rev 3 p.u.p256dh-octs q.u.p256dh-octs)
    =/  auth-raw=@    (rev 3 p.u.auth-octs q.u.auth-octs)
    =/  sub=subscription:push  [u.endpoint p256dh-raw auth-raw]
    ::  Generate sub-id from endpoint hash
    =/  sub-id=@ta  (scot %uv (end [3 16] (shax u.endpoint)))
    =/  st=push-state:nexus  get-push-state
    =.  subs.st  (~(put by subs.st) sub-id [src sub])
    =.  this  (save-push-state st)
    =/  body=@t  (en:json:html [%o (~(gas by *(map @t json)) ~[['ok' [%b %.y]] ['sub_id' [%s sub-id]]])])
    (emit-cards (give-simple-payload:app:server eyre-id [[200 ['content-type' 'application/json'] ~] `(as-octs:mimes:html body)]))
  ::
      [%unsubscribe ~]
    ::  POST: remove subscription
    ?.  =(%'POST' method.request.req)
      (respond [[405 ~] `(as-octs:mimes:html '"method not allowed"')])
    ?~  body.request.req
      (respond [[400 ~] `(as-octs:mimes:html '"missing body"')])
    =/  jon=(unit json)  (de:json:html q.u.body.request.req)
    ?~  jon
      (respond [[400 ~] `(as-octs:mimes:html '"invalid json"')])
    ?.  ?=(%o -.u.jon)
      (respond [[400 ~] `(as-octs:mimes:html '"expected object"')])
    =/  sub-id=(unit @t)
      ?~  s=(~(get by p.u.jon) 'sub_id')  ~
      ?.  ?=([~ %s *] s)  ~
      `p.u.s
    ?~  sub-id
      (respond [[400 ~] `(as-octs:mimes:html '"missing sub_id"')])
    =/  st=push-state:nexus  get-push-state
    =.  subs.st  (~(del by subs.st) u.sub-id)
    =.  this  (save-push-state st)
    =/  body=@t  (en:json:html [%o (~(gas by *(map @t json)) ~[['ok' [%b %.y]]])])
    (emit-cards (give-simple-payload:app:server eyre-id [[200 ['content-type' 'application/json'] ~] `(as-octs:mimes:html body)]))
  ==
::
++  cull-if-exists
  |=  dest=lane:tarball
  ^+  this
  ?>  ?=(%& -.dest)
  =/  dest-file  (peek-grub-now p.dest)
  ?~  dest-file  this
  (cull dest)
::
::  Save file state and bump ONLY if content actually changed.
::  This is the ONLY correct way to update file state.
::  Invariant: file aeon changes iff file content changes.
::
++  save-file
  |=  [here=rail:tarball new-content=sang:tarball]
  ^+  this
  ::  Init born if needed
  =.  this  ?^((get-born here) this (init-born here))
  ::  Only bump if content actually changed
  =/  old=(unit sang:tarball)  (peek-grub-now here)
  ?:  ?&  ?=(^ old)
          =(u.old new-content)
      ==
    ::  same content — no bump
    this
  ::  Types may differ structurally (e.g. %hold context) but nest
  ::  identically. If blot and data match and types nest, keep the
  ::  old content to avoid false-change rebuild cascades.
  ?:  ?&  ?=(^ old)
          =(p.u.old p.new-content)
          ?=(%& -.q.u.old)
          ?=(%& -.q.new-content)
          =(q.p.q.u.old q.p.q.new-content)
          (~(nest ut p.p.q.u.old) | p.p.q.new-content)
      ==
    this
  ::  Record, propagate, notify — preserve existing gain flag
  =/  old-born=born:nexus  born
  =/  file-gain=?  (lookup-gain here)
  =.  this  (record here [p.new-content (sang-noun:tarball new-content)] file-gain ~)
  =.  this  (propagate old-born here)
  ::  Rebuild if change is inside a code nexus
  =/  cod=(unit path)
    =+  pax=path.here
    |-  ?:  (~(has by code) pax)  `pax
    ?~  pax  ~
    $(pax (snip `path`pax))
  =.  this
    ?~  cod  this
    (build-code u.cod)
  ::  Recompute peer weirs if usergroup data changed
  ?.  ?=([%sys %ames %usergroups *] path.here)
    this
  ~&  >>  "save-file: usergroup changed, recomputing peer weirs"
  recompute-peer-weirs
::
::  /sys/ namespace services
::  Grubs interact with vanes through /sys/ namespace pokes.
::  The agent intercepts these pokes, translates them to arvo
::  cards, and routes responses back to the sender.
::
::  /sys/ service dispatch
::  Intercepts pokes to /sys/ rails before they reach fibers.
::  Returns ~ to fall through to normal poke handling.
::
++  handle-sys-poke
  |=  [dest=rail:tarball here=rail:tarball wir=path =sage:tarball]
  ^-  (unit _this)
  ?.  ?=([%sys @ *] path.dest)  ~
  =/  service=@tas  i.t.path.dest
  ?+  service  ~
      %clay
    ?:  =([/ %mount-desk] p.sage)
      =/  dek=desk  !<(desk q.sage)
      =.  this  (handle-clay-mount dek)
      `(enqu-take here (sys-give /clay) ~ %pack wir ~)
    ?:  =([/ %unmount-desk] p.sage)
      =/  dek=desk  !<(desk q.sage)
      =.  this  (handle-clay-unmount dek)
      `(enqu-take here (sys-give /clay) ~ %pack wir ~)
    ?:  =([/ %new-desk] p.sage)
      =/  dek=desk  !<(desk q.sage)
      =.  this  (handle-clay-new-desk dek)
      `(enqu-take here (sys-give /clay) ~ %pack wir ~)
    ?:  =([/ %clay-info] p.sage)
      =/  [dek=desk changes=(list [path ?([%ins @tas *] [%del ~])])]
        !<([desk (list [path ?([%ins @tas *] [%del ~])])] q.sage)
      =.  this  (handle-clay-info dek changes)
      `(enqu-take here (sys-give /clay) ~ %pack wir ~)
    ~  :: unknown clay poke, fall through
  ::
      %dill
    ?.  =([/ %dill-belt] p.sage)  ~
    =/  [session=@tas =belt:dill]  !<([@tas belt:dill] q.sage)
    =.  this  (emit-card [%pass /dill/belt %arvo %d %shot session %belt belt])
    `(enqu-take here (sys-give /dill) ~ %pack wir ~)
  ::
      %gall
    ?.  =([/ %gall-poke] p.sage)  ~
    =.  this  (handle-gall-poke here wir q.sage)
    `(enqu-take here (sys-give /gall) ~ %pack wir ~)
  ::
      %iris
    ?.  =([/ %iris-request] p.sage)  ~
    =.  this  (handle-iris-request here wir q.sage)
    `(enqu-take here (sys-give /iris) ~ %pack wir ~)
  ::
      %scry
    ?.  =([/ %scry-request] p.sage)  ~
    =.  this  (handle-scry-request here wir q.sage)
    `(enqu-take here (sys-give /scry) ~ %pack wir ~)
  ==
::
::  /sys/behn/ timer service
::
++  handle-timer-set
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  req=[=^wire when=@da]  !<([^wire @da] vaz)
  =/  timer-rail=rail:tarball  [/sys/behn %'main.timer-state']
  ::  Read current state
  =/  old=(unit sang:tarball)  (peek-grub-now timer-rail)
  =/  st=timer-state:nexus
    ?~  old  [%0 ~]
    !<(timer-state:nexus (need-vase:tarball u.old))
  ::  Update state
  =.  timers.st  (~(put by timers.st) [sender wire.req] when.req)
  =.  this  (save-file timer-rail [[/ %timer-state] %& !>(st)])
  ::  Build behn wire: /behn/timer/{da}/{path-len}/{path...}/{name}/{wire...}
  =/  timer-wire=^wire
    :-  %behn
    :-  %timer
    :-  (scot %da when.req)
    :-  (scot %ud (lent path.sender))
    (weld path.sender [name.sender wire.req])
  (emit-card [%pass timer-wire %arvo %b %wait when.req])
::
++  handle-timer-wake
  |=  [segs=wire error=(unit tang)]
  ^+  this
  ?^  error
    ~&  >>>  ["%behn: timer error" u.error]
    this
  ::  Decode wire: {da}/{path-len}/{path...}/{name}/{wire...}
  ?>  ?=(^ segs)
  =/  when=@da  (slav %da i.segs)
  =/  rest=wire  t.segs
  ?>  ?=(^ rest)
  =/  path-len=@ud  (slav %ud i.rest)
  =/  from-path=path  (scag path-len t.rest)
  =/  rest2=wire  (slag path-len t.rest)
  ?>  ?=(^ rest2)
  =/  from-name=@ta  i.rest2
  =/  req-wire=wire  t.rest2
  =/  sender=rail:tarball  [from-path from-name]
  ::  Remove from state
  =/  timer-rail=rail:tarball  [/sys/behn %'main.timer-state']
  =/  old=(unit sang:tarball)  (peek-grub-now timer-rail)
  =/  st=timer-state:nexus
    ?~  old  [%0 ~]
    !<(timer-state:nexus (need-vase:tarball u.old))
  =.  timers.st  (~(del by timers.st) [sender req-wire])
  =.  this  (save-file timer-rail [[/ %timer-state] %& !>(st)])
  ::  Poke sender back with timer-wake
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender &+timer-rail)
  (enqu-take sender (sys-give /behn) ~ %poke rel [[/ %timer-wake] !>(req-wire)])
::
::  /sys/clay/ desk sync service
::
++  handle-clay-mount
  |=  dek=desk
  ^+  this
  =/  clay-rail=rail:tarball  [/sys/clay %'main.clay-state']
  =/  old=(unit sang:tarball)  (peek-grub-now clay-rail)
  =/  st=clay-state:nexus
    ?~  old  [%0 ~]
    !<(clay-state:nexus (need-vase:tarball u.old))
  =.  desks.st  (~(put in desks.st) dek)
  =.  this  (save-file clay-rail [[/ %clay-state] %& !>(st)])
  ::  Ensure directory exists
  =.  this  (ensure-dir /sys/clay/desks/[dek])
  (sync-clay-desk dek)
::
++  handle-clay-unmount
  |=  dek=desk
  ^+  this
  ?>  !=(dek %grubbery)
  ?>  !=(dek %base)
  =/  clay-rail=rail:tarball  [/sys/clay %'main.clay-state']
  =/  old=(unit sang:tarball)  (peek-grub-now clay-rail)
  =/  st=clay-state:nexus
    ?~  old  [%0 ~]
    !<(clay-state:nexus (need-vase:tarball u.old))
  =.  desks.st  (~(del in desks.st) dek)
  =.  this  (save-file clay-rail [[/ %clay-state] %& !>(st)])
  (unmount-clay-desk dek)
::
++  handle-clay-new-desk
  |=  dek=desk
  ^+  this
  =/  base-paths=(list path)
    :~  /sys/kelvin
        /mar/bill/hoon
        /mar/hoon/hoon
        /mar/mime/hoon
        /mar/noun/hoon
        /mar/kelvin/hoon
        /lib/dbug/hoon
        /lib/default-agent/hoon
        /lib/verb/hoon
        /sur/verb/hoon
    ==
  =/  files=(map path page:clay)
    %-  ~(gas by *(map path page:clay))
    :-  :-  /app/[dek]/hoon
        :-  %hoon
        .^(noun %cx (scot %p our.bowl) %base (scot %da now.bowl) /lib/skeleton/hoon)
    %+  turn  base-paths
    |=  =path
    ^-  [^path page:clay]
    :-  path
    :-  (rear path)
    .^(noun %cx (scot %p our.bowl) %base (scot %da now.bowl) path)
  =.  this  (emit-card [%pass /new-desk %arvo (new-desk:cloy dek ~ files)])
  (emit-card [%pass /desk-bill %arvo %c %info dek %& [/desk/bill %ins bill+!>(~[dek])]~])
::
::  /sys/clay/ file write service
::
++  handle-clay-info
  |=  [dek=desk changes=(list [path ?([%ins @tas *] [%del ~])])]
  ^+  this
  =/  mis=(list [path miso:clay])
    %+  turn  changes
    |=  [pax=path change=?([%ins @tas *] [%del ~])]
    ^-  [path miso:clay]
    ?-  -.change
        %del  [pax %del ~]
        %ins
      [pax %ins +<.change !>(+>.change)]
    ==
  (emit-card [%pass /clay-info %arvo %c %info dek %& mis])
::
::  /sys/eyre/ HTTP server service
::
++  eyre-response-cards
  |=  [eyre-id=@ta upd=eyre-update:nexus]
  ^-  (list card)
  ?-    -.upd
      %header
    [%give %fact ~[/http-response/[eyre-id]] http-response-header+!>(response-header.upd)]~
      %data
    [%give %fact ~[/http-response/[eyre-id]] http-response-data+!>(data.upd)]~
      %kick
    [%give %kick ~[/http-response/[eyre-id]] ~]~
      %simple
    (give-simple-payload:app:server eyre-id simple-payload.upd)
  ==
::
++  handle-eyre-action
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  act=eyre-action:nexus  !<(eyre-action:nexus vaz)
  =/  st=server-state:nexus  get-server-state
  ?-    -.act
      %bind
    =.  bindings.st  (~(put by bindings.st) binding.act handler.act)
    =.  this  (save-server-state st)
    (emit-card [%pass /eyre-bind %arvo %e %connect binding.act dap.bowl])
  ::
      %unbind
    =/  orphans=(list @ta)
      %+  murn  ~(tap by conns.st)
      |=  [eid=@ta =binding:eyre]
      ?.  =(binding binding.act)  ~
      `eid
    =.  this
      %-  emit-cards
      %+  turn  orphans
      |=  eid=@ta
      ^-  card
      [%give %kick ~[/http-response/[eid]] ~]
    =.  conns.st
      %-  ~(gas by *(map @ta binding:eyre))
      %+  skip  ~(tap by conns.st)
      |=  [eid=@ta =binding:eyre]
      =(binding binding.act)
    =.  bindings.st  (~(del by bindings.st) binding.act)
    (save-server-state st)
  ::
      %send
    =/  crds=(list card)
      (eyre-response-cards eyre-id.act eyre-update.act)
    =/  conn-binding=(unit binding:eyre)
      (~(get by conns.st) eyre-id.act)
    ?:  ?=(?(%kick %simple) -.eyre-update.act)
      ?~  conn-binding
        (emit-cards crds)
      =.  conns.st  (~(del by conns.st) eyre-id.act)
      =.  this  (save-server-state st)
      (emit-cards crds)
    (emit-cards crds)
  ==
::
::  /sys/gall/ agent poke service
::
++  handle-gall-poke
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  [=dock =page]  !<([dock page] vaz)
  ::  Remote pokes: wrap noun as-is, remote gall validates on arrival
  ::  Local pokes: clam through code nexus marc
  =/  =vase
    ?.  =(our.bowl p.dock)
      !>(`*`q.page)
    ::  Split mark on hyphens (like Clay +segments) to find matching file
    =/  dek=desk
      .^(desk %gd /(scot %p p.dock)/[q.dock]/(scot %da now.bowl)/$)
    =/  segs=(list path)  (segments:clay p.page)
    =/  marc-res=(unit built:nexus)
      |-
      ?~  segs  ~
      =/  seg=path  i.segs
      =/  dir=path  (snip seg)
      =/  nam=@ta   (rear seg)
      ::  Try /mar/clay/[desk]/ then /mar/clay/base/
      =/  res=(unit built:nexus)
        (get-built / (weld /mar/clay/[dek] dir) nam)
      ?^  res  res
      =/  res=(unit built:nexus)
        (get-built / (weld /mar/clay/base dir) nam)
      ?^  res  res
      $(segs t.segs)
    =/  =marc:tarball
      ?~  marc-res
        ~|([%marc-not-found p.page dek] !!)
      ?.  ?=(%vase -.u.marc-res)
        ~|([%marc-failed p.page dek] !!)
      !<(marc:tarball vase.u.marc-res)
    (vale:marc q.page)
  ::  Encode sender in wire: /gall-poke/{path-len}/{path...}/{name}/{wire...}
  =/  gall-wire=path
    :-  %gall-poke
    :-  (scot %ud (lent path.sender))
    (weld path.sender [name.sender wire])
  (emit-card [%pass gall-wire %agent dock %poke p.page vase])
::
++  take-gall-poke
  |=  [segs=wire =sign:agent:gall]
  ^+  this
  ::  Decode wire: {path-len}/{path...}/{name}/{wire...}
  ?>  ?=(^ segs)
  =/  path-len=@ud  (slav %ud i.segs)
  =/  from-path=path  (scag path-len t.segs)
  =/  rest=wire  (slag path-len t.segs)
  ?>  ?=(^ rest)
  =/  sender=rail:tarball  [from-path i.rest]
  =/  req-wire=wire  t.rest
  ::  Route poke-ack back to sender
  ?>  ?=(%poke-ack -.sign)
  =/  ack-sage=sage:tarball  [[/ %poke-ack] !>(p.sign)]
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender &+[/sys/gall %'main.sig'])
  (enqu-take sender (sys-give /gall) ~ %poke rel ack-sage)
::
::  /sys/iris/ HTTP client service
::
++  handle-iris-request
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  =request:http  !<(request:http vaz)
  =/  iris-rail=rail:tarball  [/sys/iris %'main.iris-state']
  ::  Build iris wire: /iris/request/{path-len}/{path...}/{name}/{wire...}
  =/  iris-wire=path
    :-  %iris
    :-  %request
    :-  (scot %ud (lent path.sender))
    (weld path.sender [name.sender wire])
  ::  Update state
  =/  old=(unit sang:tarball)  (peek-grub-now iris-rail)
  =/  st=iris-state:nexus
    ?~  old  [%0 ~]
    !<(iris-state:nexus (need-vase:tarball u.old))
  =.  requests.st  (~(put by requests.st) iris-wire [sender url.request])
  =.  this  (save-file iris-rail [[/ %iris-state] %& !>(st)])
  (emit-card [%pass iris-wire %arvo %i %request request *outbound-config:iris])
::
++  handle-iris-response
  |=  [segs=wire =client-response:iris]
  ^+  this
  ::  Decode wire: {path-len}/{path...}/{name}/{wire...}
  ?>  ?=(^ segs)
  =/  path-len=@ud  (slav %ud i.segs)
  =/  from-path=path  (scag path-len t.segs)
  =/  rest=wire  (slag path-len t.segs)
  ?>  ?=(^ rest)
  =/  from-name=@ta  i.rest
  =/  req-wire=wire  t.rest
  =/  sender=rail:tarball  [from-path from-name]
  ::  Remove from state
  =/  iris-rail=rail:tarball  [/sys/iris %'main.iris-state']
  =/  iris-wire=path  [%iris %request segs]
  =/  old=(unit sang:tarball)  (peek-grub-now iris-rail)
  =/  st=iris-state:nexus
    ?~  old  [%0 ~]
    !<(iris-state:nexus (need-vase:tarball u.old))
  =.  requests.st  (~(del by requests.st) iris-wire)
  =.  this  (save-file iris-rail [[/ %iris-state] %& !>(st)])
  ::  Poke sender back with http-response
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender &+iris-rail)
  (enqu-take sender (sys-give /iris) ~ %poke rel [[/ %http-response] !>(client-response)])
::
::  /sys/scry/ scry service
::
++  handle-scry-request
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  pat=path  !<(path vaz)
  =/  scry-rail=rail:tarball  [/sys/scry %'main.sig']
  ?>  ?=([@ @ *] pat)
  =/  res=vase
    !>(.^(* i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat))
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender &+scry-rail)
  (enqu-take sender (sys-give /scry) ~ %poke rel [[/ %scry-response] res])
--
