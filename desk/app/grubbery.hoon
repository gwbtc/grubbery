/-  spider
/+  default-agent, dbug, tarball, nexus, server,
    nex-tools, marks, build
/=  t-  /tests/nexus
/=  t-  /tests/tarball
/=  t-  /tests/build
/=  m-  /mar/kids
/=  m-  /mar/tree
/=  m-  /mar/sand
/=  m-  /mar/born
/=  m-  /mar/subs
/=  m-  /mar/gain
/=  m-  /mar/keys
/=  m-  /mar/ships
/=  m-  /mar/dill-told
/=  m-  /mar/dill-blit
/=  m-  /mar/jael-private-keys
/=  m-  /mar/jael-public-keys-result
/=  m-  /mar/claude-action
/=  m-  /mar/claude-messages
/=  n-  /nex/build
/=  n-  /nex/mcp
/=  n-  /nex/claude
/=  n-  /nex/counter
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
  ==
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
::  Create empty ball with %root nexus at root
  =/  init-ball=ball:tarball  [`[~ `%root ~] ~]  :: lump with neck=%root
  =^  cards  state
    abet:(reload:hc *pool:nexus init-ball *sand:nexus *born:nexus *subs:nexus *silo:nexus *gain:nexus)
  =^  dill-cards  state
    abet:sync-dill:hc
  =^  clay-cards  state
    abet:sync-clay:hc
  =^  jael-cards  state
    abet:sync-jael:hc
  :_  this
  :(weld jael-cards clay-cards dill-cards cards)
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
    ::  Ensure neck at root is %root (nexus on-load will create main.sig)
    =/  new-ball=ball:tarball
      =/  lmp=lump:tarball  (fall fil.ball.old [~ ~ ~])
      ball.old(fil `lmp(neck `%root))
    =^  cards  state
      abet:(reload:hc pool.old new-ball sand.old born.old subs.old silo.old gain.old)
    =^  dill-cards  state
      abet:sync-dill:hc
    =^  clay-cards  state
      abet:sync-clay:hc
    =^  jael-cards  state
      abet:sync-jael:hc
    :_  this
    :(weld jael-cards clay-cards dill-cards cards)
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
        abet:(poke:hc give [/'peers.peers' %'main.sig'] poke-in+!>([p.dest.action page.action]))
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
      abet:(poke:hc give [/'server.server' %'main.server-state'] handle-http-request+!>([eyre-id src.bowl req]))
    [cards this]
      ::
      %rebuild-caches
    ::  Rebuild all mark tube, dais, and nexus caches.
    ?>  =(src our):bowl
    =.  ball  (~(pub ba:tarball ball) /sys/tubes (rebuild-tubes:marks our.bowl q.byk.bowl now.bowl))
    =.  ball  (~(pub ba:tarball ball) /sys/daises (rebuild-daises:marks our.bowl q.byk.bowl now.bowl))
    =.  ball  (~(pub ba:tarball ball) /sys/nexuses (rebuild-nexuses:marks our.bowl q.byk.bowl now.bowl))
    [~ this]
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
      abet:(poke:hc give [/'server.server' %'main.server-state'] handle-http-cancel+!>(eyre-id))
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
    ::  Single file's cage with its actual mark
    =/  here=^path  t.t.t.path
    ?~  here  ~
    =/  dir=^path  (snip `^path`here)
    =/  name=@ta  (rear here)
    =/  content=(unit content:tarball)
      (~(get ba:tarball ball) dir name)
    ?~  content
      [~ ~]
    ``cage.u.content
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
    ::  Look up cage in silo by lobe hash
    =/  =lobe:clay  (slav %uv i.t.t.t.t.path)
    =/  got=(unit cage)  (~(get si:nexus silo) lobe)
    ?~  got  [~ ~]
    ``u.got
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
      abet:(save-file:hc [/sys/dill %'logs.dill-told'] [~ %dill-told !>(told.sign)])
    [cards this]
  ?:  ?=([%dill %session @ ~] wire)
    ?>  ?=([%dill %blit *] sign)
    =/  ses=@tas  i.t.t.wire
    =^  cards  state
      abet:(save-file:hc [/sys/dill/sessions ses] [~ %dill-blit !>(p.sign)])
    [cards this]
  ?:  ?=([%clay-desk @ ~] wire)
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
      abet:(save-file:hc [/sys/jael %'private-keys.jael-private-keys'] [~ %jael-private-keys !>([life.sign vein.sign])])
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
::  Validate a vase according to a mark, checking nest or scrying for dais
::  Pure vase validation given a dais
::
::  Assumes old vase was part of a chain of +validate-vase uses where the
::  original was clammed
::  Nest optimization: if old vase exists and types nest, reuse old type.
::  Otherwise run vale to get canonical type from dais.
::
::  force=%.y skips nest optimization (for reload when types may have changed)
::
++  validate-vase
  |=  [=dais:clay old=(unit vase) new=vase force=?]
  ^-  (each vase tang)
  ?:  ?&  !force
          ?=(^ old)
          (~(nest ut p.u.old) | p.new)
      ==
    &+[p.u.old q.new]
  =/  vale-result=(each vase tang)
    (mule |.((vale:dais q.new)))
  ?:  ?=(%| -.vale-result)
    =/  err=tang
      :~  leaf+"vale failed"
          leaf+"got:"
          (skol p.new)
      ==
    |+(weld err p.vale-result)
  &+p.vale-result
::  Get a cached tube from /sys/tubes/[from]/[to]
::
++  get-tube
  |=  [from=mark to=mark]
  ^-  tube:clay
  =/  c=(unit content:tarball)
    (~(get ba:tarball ball) /sys/tubes/[from] to)
  ?~  c  ~|([%tube-not-cached from to] !!)
  !<(tube:clay q.cage.u.c)
::  Get a cached dais from /sys/daises/[mark]
::
++  get-dais
  |=  =mark
  ^-  dais:clay
  =/  c=(unit content:tarball)
    (~(get ba:tarball ball) /sys/daises mark)
  ?~  c  ~|([%dais-not-cached mark] !!)
  !<(dais:clay q.cage.u.c)
::  Validate file content: handles %temp, empty-mime, looks up cached dais
::
++  validate-new-cage
  |=  [=mark old=(unit vase) new=vase force=?]
  ^-  (each vase tang)
  ::  Skip validation for %temp mark - ephemeral
  ?:  =(%temp mark)
    &+new
  ::  Reject empty mime files
  ?:  ?&  =(%mime mark)
          =(0 p.q:!<(mime new))
      ==
    |+~[leaf+"empty mime file"]
  =/  =dais:clay  (get-dais mark)
  (validate-vase dais old new force)
::  Clam a cage at sandbox boundary
::  Used when data crosses a weir filter from untrusted source.
::  Always forces full validation (no nest optimization).
::
++  clam-cage
  |=  =cage
  ^-  (each ^cage tang)
  ::  Reject %temp mark - can't validate from untrusted source
  ?:  =(%temp p.cage)
    |+~[leaf+"clam: cannot validate %temp mark from untrusted source"]
  =/  result=(each vase tang)
    (validate-new-cage p.cage ~ q.cage %.y)
  ?:  ?=(%| -.result)
    result
  &+[p.cage p.result]
::  Validate all cages in a ball subtree, crash on failure
::
::  Always forces full dais validation (no nest optimization) because
::  validate-ball is only called when installing a fresh subtree where
::  the nest optimization wouldn't help anyway.
::
++  validate-ball
  |=  =ball:tarball
  ^-  ball:tarball
  ::  validate files at this level
  ::  for each file, run validate-new-cage and crash if it fails
  ::  rebuild contents map with validated vases
  ::
  =/  validated-contents=(map @ta content:tarball)
    ?~  fil.ball  ~
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.ball)
    =|  out=(map @ta content:tarball)
    |-
    ?~  files  out
    =/  [name=@ta =content:tarball]  i.files
    =/  res=(each vase tang)
      (validate-new-cage p.cage.content ~ q.cage.content %.y)
    ?.  ?=(%& -.res)  ~|(p.res !!)
    $(files t.files, out (~(put by out) name content(cage [p.cage.content p.res])))
  ::  recurse into subdirectories
  ::  validate each child ball and rebuild dir map
  ::
  =/  validated-dir=(map @ta ball:tarball)
    =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
    =|  out=(map @ta ball:tarball)
    |-
    ?~  kids  out
    =/  [name=@ta kid=ball:tarball]  i.kids
    $(kids t.kids, out (~(put by out) name ^$(ball kid)))
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
  =/  =pipe:nexus  (~(put by (fall (~(get of pool) path.here) ~)) name.here proc)
  this(pool (~(put of pool) path.here pipe))
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
  =/  =pipe:nexus  (~(del by (fall (~(get of pool) dir) ~)) name)
  this(pool (~(put of pool) dir pipe))
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
    =/  procs=(list [name=@ta =proc:fiber:nexus])  ~(tap by u.fil.pool)
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
  ::  Check if this node has a nexus
  =/  nex=(unit nexus:nexus)
    ?~  fil.sub-ball  ~
    ?~  neck.u.fil.sub-ball  ~
    (build-nexus u.neck.u.fil.sub-ball)
  ::  Run on-load if nexus exists
  ::
  ::  IMPORTANT: The weir at the root of sub-sand is preserved from the parent.
  ::  A nexus cannot control its own sandboxing - that would defeat the purpose.
  ::  Sandboxing is always imposed from above. The nexus can only set weirs
  ::  for its children, never for itself.
  ::
  =/  parent-weir=(unit weir:nexus)  fil.sub-sand
  =/  [upd-sand=sand:nexus upd-gain=gain:nexus upd-ball=ball:tarball]
    ?~  nex  [sub-sand sub-gain sub-ball]
    (on-load:u.nex sub-sand sub-gain sub-ball)
  =:  sub-sand  upd-sand(fil parent-weir)
      sub-gain  upd-gain
      sub-ball  upd-ball
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
  ::  Get the nexus for this directory
  =/  sub-ball=ball:tarball  (~(dip ba:tarball ball) dest)
  =/  nex=(unit nexus:nexus)
    ?~  fil.sub-ball  ~
    ?~  neck.u.fil.sub-ball  ~
    (build-nexus u.neck.u.fil.sub-ball)
  ?~  nex
    ~|("no nexus at destination" !!)
  ::  Get current sand subtree (preserve parent weir)
  =/  sub-sand=sand:nexus  (~(dip of sand) dest)
  =/  sub-gain=gain:nexus  (~(dip of gain) dest)
  =/  parent-weir=(unit weir:nexus)  fil.sub-sand
  ::  Run on-load
  =/  [upd-sand=sand:nexus upd-gain=gain:nexus upd-ball=ball:tarball]
    (on-load:u.nex sub-sand sub-gain sub-ball)
  =/  new-sand=sand:nexus    upd-sand(fil parent-weir)
  =/  new-gain=gain:nexus    upd-gain
  =/  new-ball=ball:tarball  upd-ball
  ::  Put results back
  =/  old-born=born:nexus  born
  =.  sand  (put-sub-sand sand dest new-sand)
  =.  ball  (~(pub ba:tarball ball) dest new-ball)
  =.  gain  (put-sub-gain gain dest new-gain)
  ::  Bump weir cass in born for any directories where weir changed
  =.  this  (bump-weir-changes dest sub-sand new-sand)
  =.  this  (notify old-born)
  ::  Re-check subscriptions against potentially changed weirs in subtree
  (audit-weir dest)
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
  =.  this  (enqu-take file-rail (sys-give /load) ~)
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
++  reload
  |=  $:  old-pool=pool:nexus
          old-ball=ball:tarball
          old-sand=sand:nexus
          old-born=born:nexus
          old-subs=subs:nexus
          old-silo=silo:nexus
          old-gain=gain:nexus
      ==
  ^+  this
  ::  Nack pokes in old proc queues
  =.  this  (nack-pool / old-pool ~[leaf+"agent [re]loaded"])
  ::  Restore state (pool will be rebuilt)
  =.  ball  old-ball
  =.  sand  old-sand
  =.  born  old-born
  =.  subs  old-subs
  =.  silo  old-silo
  =.  gain  old-gain
  ::  Capture ball before modifications (for change detection)
  =/  pre-ball=ball:tarball  ball
  ::  Clear ephemeral %temp cages - they shouldn't survive reload
  =.  ball  ~(clear-temp ba:tarball ball)
  ::  Build tube, dais, and nexus caches synchronously as %temp grubs.
  =.  ball  (~(pub ba:tarball ball) /sys/tubes (rebuild-tubes:marks our.bowl q.byk.bowl now.bowl))
  =.  ball  (~(pub ba:tarball ball) /sys/daises (rebuild-daises:marks our.bowl q.byk.bowl now.bowl))
  =.  ball  (~(pub ba:tarball ball) /sys/nexuses (rebuild-nexuses:marks our.bowl q.byk.bowl now.bowl))
  ::  Run nexus on-loads top-down (may modify ball, sand, and gain)
  =/  pre-sand=sand:nexus  sand
  =/  [new-sand=sand:nexus new-gain=gain:nexus new-ball=ball:tarball]
    (run-on-loads / sand gain ball)
  =:  sand  new-sand
      gain  new-gain
      ball  new-ball
  ==
  ::  Bump weir cass in born for any directories where weir changed
  =.  this  (bump-weir-changes / pre-sand sand)
  ::  Force-validate entire ball (type of $type may have changed since state was saved)
  =.  ball  ~|(%validate-ball-reload (validate-ball ball))
  ::  Validate name uniqueness (no file/dir collisions)
  ?>  ~(validate-names ba:tarball ball)
  ::  Re-check all subscriptions against potentially changed weirs
  =.  this  (audit-weir /)
  ::  Spawn processes and sync all changes
  =.  this  (load-ball-changes / pre-ball ball)
  this
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
  =/  changed=(set lane:tarball)  (diff-born:nexus old-born born)
  ?:  =(~ changed)  this
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
      [%file sk (lookup-gain p.target) cage.u.content]
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
      ?:  =(p.cage.view u.mark)  view  :: already correct mark
      =/  =tube:clay  (get-tube p.cage.view u.mark)
      view(cage [u.mark (tube q.cage.view)])
    (enqu-take:acc watcher (sys-give:acc /news) ~ %news wire watcher-view)
  $(watched t.watched)
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
  |=  neck=@tas
  ^-  (unit nexus:nexus)
  =/  c=(unit content:tarball)
    (~(get ba:tarball ball) /sys/nexuses neck)
  ?~  c  ~
  (mole |.(!<(nexus:nexus q.cage.u.c)))
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
++  build-spool
  |=  here=rail:tarball
  ^-  (unit spool:fiber:nexus)
  ::  Get the file from the ball - must exist
  =/  file-data=(unit content:tarball)  (~(get ba:tarball ball) path.here name.here)
  ?~  file-data  ~
  ::  Extract mark from the cage
  =/  =mark  p.cage.u.file-data
  ::  Find the nearest parent nexus
  =/  nex-info=(unit (pair path neck:tarball))  (find-nearest-nexus here)
  ?~  nex-info  ~
  ::  Build the nexus from the neck
  =/  nex=(unit nexus:nexus)  (build-nexus q.u.nex-info)
  ?~  nex  ~
  ::  Call on-file with rail relative to nexus location
  `(on-file:u.nex (relativize-rail:tarball p.u.nex-info here) mark)
::
++  process-dart
  |=  [here=rail:tarball =dart:nexus]
  ^+  this
  =/  [=jump:nexus dest=(unit lane:tarball)]  (dart-to-dest here dart)
  =/  =filt:nexus  (allowed jump here dest)
  ?+    filt  (handle-dart here dart filt)
      [~ %|]
    ::  Vetoed - send %veto intake back to source
    (enqu-take here (sys-give /veto) ~ %veto dart)
    ::
      [~ %&]
    ::  Allowed but should clam vases crossing sandbox boundary
    ::  (make darts don't need clamming - they go through validate-cage anyway)
    ::  Peek results are clammed inside handle-dart (data flows back)
    ?.  ?=([%node * * ?(%poke %over %diff) *] dart)
      (handle-dart here dart filt)
    =/  clammed=(each cage tang)  (clam-cage cage.load.dart)
    ?:  ?=(%| -.clammed)
      (enqu-take here (sys-give /veto) ~ %veto dart)
    (handle-dart here dart(cage.load p.clammed) filt)
  ==
::  Extract jump category and destination from a dart for weir filtering.
::  Returns [jump dest] where:
::    - jump: the filter category (%sysc, %make, %poke, %peek)
::    - dest: absolute destination path, or ~ for syscalls
::
++  dart-to-dest
  |=  [here=rail:tarball =dart:nexus]
  ^-  [jump:nexus (unit lane:tarball)]
  ?+    -.dart  [%sysc ~]          :: %sysc, %scry, %bowl target system
      %node                        :: %node darts target a file/dir
    =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] road.dart)
    :_  dest-lane
    ?-  -.load.dart
      ?(%peek %keep %drop %seek %peep)  %peek  :: read operations
      %poke                       %poke
        $?  %make  %cull  %sand  %load
            %over  %diff  %gain  %lose
        ==
      %make  :: all modify tree structure
    ==
    ::
      %manu
    ?-  -.target.dart
      %&  [%sysc ~]                    :: explicit: caller knows the nexus, no filtering
        %|  :: by road: requires peek permission
      [%peek (lane-from-road:tarball [%& here] p.target.dart)]
    ==
  ==
::
++  handle-dart
  |=  [here=rail:tarball =dart:nexus =filt:nexus]
  ^+  this
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
      (enqu-take dest [&+here wire.dart] ~ %poke rel cage.load.dart)
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
        ?:  =(p.cage.p.make.load.dart u.mark.p.make.load.dart)
          make.load.dart
        =/  =tube:clay  (get-tube p.cage.p.make.load.dart u.mark.p.make.load.dart)
        make.load.dart(cage.p [u.mark.p.make.load.dart (tube q.cage.p.make.load.dart)])
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
      =/  old-mark=@tas  p.cage.u.old
      =/  new-mark=@tas  p.cage.load.dart
      =/  converted=cage
        ?:  =(old-mark new-mark)
          cage.load.dart
        =/  =tube:clay  (get-tube new-mark old-mark)
        [old-mark (tube q.cage.load.dart)]
      =/  val=(each vase tang)
        (validate-new-cage p.converted `q.cage.u.old q.converted %.n)
      ?:  ?=(%| -.val)
        (enqu-take here (sys-give /over) ~ %over wire.dart `p.val)
      =/  new-content=content:tarball  u.old(cage [p.converted p.val])
      =.  this  (save-file dest new-content)
      =.  this  (enqu-take dest (sys-give /writ) ~ %writ %over)
      (enqu-take here (sys-give /over) ~ %over wire.dart ~)
      ::
        %diff
      ::  Replace grub content with same-mark cage, notify process
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      =/  old=(unit content:tarball)
        (~(get ba:tarball ball) path.dest name.dest)
      ?~  old
        (enqu-take here (sys-give /diff) ~ %diff wire.dart `~[leaf+"file not found: {(spud (snoc path.dest name.dest))}"])
      =/  old-mark=@tas  p.cage.u.old
      ?.  =(old-mark p.cage.load.dart)
        (enqu-take here (sys-give /diff) ~ %diff wire.dart `~[leaf+"mark mismatch: expected %{(trip old-mark)}, got %{(trip p.cage.load.dart)}"])
      =/  val=(each vase tang)
        (validate-new-cage old-mark `q.cage.u.old q.cage.load.dart %.n)
      ?:  ?=(%| -.val)
        (enqu-take here (sys-give /diff) ~ %diff wire.dart `p.val)
      =/  new-content=content:tarball  u.old(cage [old-mark p.val])
      =.  this  (save-file dest new-content)
      =.  this  (enqu-take dest (sys-give /writ) ~ %writ %diff)
      (enqu-take here (sys-give /diff) ~ %diff wire.dart ~)
      ::
        %peek
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
          (validate-ball u.sub-ball)
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
        ::  Resolve source cage: historical from silo or current from ball
        =/  source=(unit cage)
          ?^  case.load.dart
            =/  =lobe:clay
              (resolve-case:nexus u.case.load.dart hist.sk)
            (~(get si:nexus silo) lobe)
          `cage.u.content
        ?~  source
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        ::  Clam at weir boundary or by request
        =/  clammed=cage
          ?.  |(?=([~ %&] filt) clam.load.dart)  u.source
          =/  res=(each cage tang)  (clam-cage u.source)
          ?:  ?=(%| -.res)
            ~|(%peek-clam-failed !!)
          p.res
        ::  Update silo entry with refreshed type if from hist
        =?  silo  ?=(^ case.load.dart)
          =/  =lobe:clay  (resolve-case:nexus u.case.load.dart hist.sk)
          (~(put by silo) lobe [refs:(~(got by silo) lobe) clammed])
        ::  Apply mark conversion if requested
        =/  result=cage
          ?~  mark.load.dart  clammed
          ?:  =(p.clammed u.mark.load.dart)  clammed
          =/  =tube:clay  (get-tube p.clammed u.mark.load.dart)
          [u.mark.load.dart (tube q.clammed)]
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %file sk (lookup-gain dest) result)
      ==
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
          [%file sk (lookup-gain dest) cage.u.content]
            %|
          =/  dest=fold:tarball  p.u.dest-lane
          =/  sub-ball=(unit ball:tarball)  (~(dap ba:tarball ball) dest)
          ?~  sub-ball  [%none ~]
          [%ball (~(dip of sand) dest) (~(dip of gain) dest) (~(dip of born) dest) u.sub-ball]
        ==
      ::  Apply mark conversion if requested
      =?  view  &(?=(^ mark.load.dart) ?=(%file -.view))
        ?:  =(p.cage.view u.mark.load.dart)  view
        =/  =tube:clay  (get-tube p.cage.view u.mark.load.dart)
        view(cage [u.mark.load.dart (tube q.cage.view)])
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
      ::  Query hist entries matching find spec, return cages
      ?>  ?=(%& -.u.dest-lane)
      =/  dest=rail:tarball  p.u.dest-lane
      =/  sk=(unit sack:nexus)  (get-born dest)
      ?~  sk
        (enqu-take here (sys-give /peep) ~ %peep wire.dart |+~[leaf+"no history for {(spud (snoc path.dest name.dest))}"])
      =/  entries=(list [key=cass:clay val=lobe:clay])
        (tap:on-hist:nexus hist.u.sk)
      =/  hits=(list [cass:clay cage])
        %+  murn  entries
        |=  [key=cass:clay val=lobe:clay]
        ^-  (unit [cass:clay cage])
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
        =/  got=(unit cage)  (~(get si:nexus silo) val)
        ?~  got  ~
        `[key u.got]
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
    ==
    ::
      %manu
    ?-    -.target.dart
        %&
      ::  Explicit: build nexus from neck, call on-manu directly
      =/  nex=(unit nexus:nexus)  (build-nexus neck.p.target.dart)
      ?~  nex
        (enqu-take here (sys-give /manu) ~ %manu wire.dart |+~[leaf+"nexus not found: {(trip neck.p.target.dart)}"])
      =/  text=@t  (on-manu:u.nex mana.p.target.dart)
      (enqu-take here (sys-give /manu) ~ %manu wire.dart &+text)
      ::
        %|
      ::  By road: resolve, find nearest nexus, relativize, call on-manu
      =/  dest-lane=(unit lane:tarball)  (lane-from-road:tarball [%& here] p.target.dart)
      ?~  dest-lane
        (enqu-take here (sys-give /manu) ~ %manu wire.dart |+~[leaf+"bad road"])
      ::  Full path from lane
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
      =/  nex=(unit nexus:nexus)  (build-nexus q.u.nex-info)
      ?~  nex
        (enqu-take here (sys-give /manu) ~ %manu wire.dart |+~[leaf+"nexus build failed: {(trip q.u.nex-info)}"])
      ::  Relativize target path to nexus location
      =/  rel-path=path  (slag (lent p.u.nex-info) target-path)
      ::  Build query from relative path + lane type
      =/  =mana:nexus
        ?-    -.u.dest-lane
            %|  [%& rel-path]
            %&
          =/  =mark
            =/  content=(unit content:tarball)
              (~(get ba:tarball ball) path.p.u.dest-lane name.p.u.dest-lane)
            (fall (bind content |=(c=content:tarball p.cage.c)) %$)
          [%| [(snip rel-path) (rear rel-path)] mark]
        ==
      =/  text=@t  (on-manu:u.nex mana)
      (enqu-take here (sys-give /manu) ~ %manu wire.dart &+text)
    ==
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
      %bowl
    ::  Request bowl - build and enqueue
    (enqu-take here (sys-give /bowl) ~ %bowl wire.dart (make-bowl here))
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
  ::  Bump proc cass (born must already exist from save-file)
  =.  this  (bump-proc here)
  ::  Build and store proc - use default spool if no nexus
  =/  =spool:fiber:nexus
    (fall (build-spool here) default-spool)
  =/  =process:fiber:nexus  (spool prod)
  (store-proc here [process ~ ~])
::
++  default-spool
  ^-  spool:fiber:nexus
  |=  prod:fiber:nexus
  stay:(fiber:fiber:nexus ,~)
::
++  process-take
  |=  [here=rail:tarball =take:fiber:nexus]
  ^+  this
  ::  Get pipe at directory, or empty map
  =/  =pipe:nexus  (fall (~(get of pool) path.here) ~)
  ::  Get proc for this file - must exist
  =/  prc=(unit proc:fiber:nexus)  (~(get by pipe) name.here)
  ?~  prc  this
  ::  Add take to queue, store, and run
  =/  =proc:fiber:nexus  u.prc
  =.  proc  proc(next (~(put to next.proc) take))
  =.  this  (store-proc here proc)
  (process-do-next here)
::
++  process-do-next
  |=  here=rail:tarball
  ^+  this
  ::  Get proc from pool
  =/  =pipe:nexus  (fall (~(get of pool) path.here) ~)
  =/  =proc:fiber:nexus  (~(got by pipe) name.here)
  ::  Get file state from ball
  =/  file-data=(unit content:tarball)
    (~(get ba:tarball ball) path.here name.here)
  ?~  file-data  this  :: file doesn't exist
  =/  fil-state=vase  q.cage.u.file-data
  ::  Build bowl for this process (with filtered wex/sup)
  =/  =bowl:nexus  (make-bowl here)
  ::  Run the evaluator
  =/  [darts=(list dart:nexus) done=(list took:eval:fiber:nexus) new-state=vase new-proc=_proc res=result:eval:fiber:nexus]
    (take:eval:fiber:nexus bowl fil-state proc)
  ::  Process darts (emit cards or enqueue takes)
  =.  this  (process-darts here darts)
  ::  Ack consumed pokes
  =.  this  (give-poke-signs here done)
  ::  Validate new state before handling result (runtime, no force)
  =/  validated=(each vase tang)
    (validate-new-cage p.cage.u.file-data `fil-state new-state %.n)
  ?:  ?=(%| -.validated)
    ::  Validation failed - treat as crash
    =.  this  (nack-poke-takes here next.new-proc p.validated)
    =.  this  (nack-poke-takes here skip.new-proc p.validated)
    =.  this  (spawn-proc here [%rise p.validated])
    (enqu-take here (sys-give /rise) ~)
  ::  Validation passed - handle result normally
  ?-    -.res
      %next
    ::  Save state (bumps aeon only if content changed)
    =.  this  (save-file here [metadata.u.file-data p.cage.u.file-data p.validated])
    (store-proc here new-proc)
      %done
    ::  Save final state so subscribers see it, then delete
    =.  this  (save-file here [metadata.u.file-data p.cage.u.file-data p.validated])
    =/  err=tang  ~[leaf+"process completed"]
    =.  this  (nack-poke-takes here next.new-proc err)
    =.  this  (nack-poke-takes here skip.new-proc err)
    =.  this  (clean (snoc path.here name.here) %file)
    (delete path.here name.here)
      %fail
    ::  Process failed - don't save state, restart. Subs survive (wires still route).
    =.  this  (nack-poke-takes here next.new-proc err.res)
    =.  this  (nack-poke-takes here skip.new-proc err.res)
    =.  this  (spawn-proc here [%rise err.res])
    (enqu-take here (sys-give /rise) ~)
  ==
::
++  poke
  |=  [=give:nexus here=rail:tarball =cage]
  ^+  this
  =/  rel-from=from:fiber:nexus  (relativize-from:nexus here from.give)
  (enqu-take here give ~ %poke rel-from cage)
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
    =/  validated=ball:tarball  ~|(%validate-ball-make (validate-ball new-ball))
    ::  Put the final sand, gain, and ball back
    =.  sand  (put-sub-sand sand dest-path new-sand)
    =.  gain  (put-sub-gain gain dest-path new-gain)
    =.  ball  (~(pub ba:tarball ball) dest-path validated)
    ::  Spawn processes and sync all changes (old is empty)
    (load-ball-changes dest-path *ball:tarball validated)
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
    =/  validated=(each vase tang)
      (validate-new-cage p.cage.p.make ~ q.cage.p.make %.n)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  Record gain flag if set
    =?  this  gain.p.make
      =.  gain  (set-gain dest-rail %.y)
      this
    ::  Save initial state (bumps file aeon since old content is ~)
    =.  this  (save-file dest-rail [~ p.cage.p.make p.validated])
    ::  Spawn process (needs file in ball for build-spool)
    =.  this  (spawn-proc dest-rail [%make ~])
    (enqu-take dest-rail (sys-give /make) ~)
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
    ::  Bump all changes before deletion
    =.  this  (cull-ball-changes dest-path sub)
    ::  Nack all queued pokes in subtree
    =.  this  (nack-pool dest-path (~(dip of pool) dest-path) ~[leaf+"culled"])
    ::  Clean gall subscriptions for subtree
    =.  this  (clean dest-path %tree)
    ::  Remove from pool and ball (NOT born - it's a high-water mark)
    =.  pool  (~(lop of pool) dest-path)
    this(ball (~(lop ba:tarball ball) dest-path))
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
::
++  make-bowl
  |=  here=rail:tarball
  ^-  bowl:nexus
  ::  Filter wex to only include outgoing subscriptions for this process
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
  ::  Filter sup to only include incoming subscriptions for this process
  =/  filtered-sup=bitt:gall
    %-  ~(gas by *bitt:gall)
    %+  murn  ~(tap by sup.bowl)
    |=  [=duct =ship =path]
    ?.  ?=([%proc @ *] path)  ~
    =/  [proc-rail=rail:tarball sub=^path]  (unwrap-watch-path path)
    =/  proc-path=^path  (snoc path.proc-rail name.proc-rail)
    ?.  =(proc-path here-path)  ~
    [~ duct ship sub]
  [now our eny filtered-wex filtered-sup here dap byk]:[bowl .]
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
  |=  here=rail:tarball
  ^+  this
  =/  old-born=born:nexus  born
  =.  born  (~(bump-proc bo:nexus now.bowl [born ball]) here)
  (notify old-born)
::
++  bump-file
  |=  here=rail:tarball
  ^+  this
  =/  old-born=born:nexus  born
  =.  born  (~(bump-file bo:nexus now.bowl [born ball]) here)
  (notify old-born)
::  Record cage in silo and append to hist on sack.
::
++  record-hist
  |=  [here=rail:tarball =cage cas=(unit cass:clay)]
  ^+  this
  ::  Skip silo/hist for ephemeral %temp marks
  ?:  =(%temp p.cage)  this
  =/  sok=sack:nexus  (need (get-born here))
  ::  Use provided cass or compute next from current file cass
  =/  new-cass=cass:clay
    (fall cas (~(next-cass bo:nexus now.bowl [born ball]) file.sok))
  =/  gaining=?  (lookup-gain here)
  =/  [=lobe:clay new-silo=silo:nexus new-hist=_hist.sok]
    (~(record si:nexus silo) cage new-cass gaining file.sok hist.sok)
  =.  silo  new-silo
  =.  born  (~(put bo:nexus now.bowl [born ball]) here sok(hist new-hist))
  this
::  Diff two balls and bump all changes (new, changed, deleted files and empty dirs).
::
++  diff-balls
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  =.  born  (~(diff-balls bo:nexus now.bowl [born ball]) here old-ball new-ball)
  this
::  Spawn processes and sync all changes when a ball is created/reloaded.
::  Handles spawning files and bumping all changes (new, changed, deleted files, empty dirs).
::
++  load-ball-changes
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  =.  this  (spawn-all-files here new-ball)
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
        (record-hist [here name] cage:(~(got by new-files) name) `file.sok)
      ?:  &(in-old !in-new)
        ::  Deleted file: drop silo refs
        =/  sok=(unit sack:nexus)  (get-born [here name])
        =?  silo  ?=(^ sok)
          (~(drop-hist si:nexus silo) hist.u.sok)
        this
      ::  Both: record if changed
      =/  old-content=content:tarball  (~(got by old-files) name)
      =/  new-content=content:tarball  (~(got by new-files) name)
      ?.  =(cage.old-content cage.new-content)
        =/  sok=sack:nexus  (need (get-born [here name]))
        (record-hist [here name] cage.new-content `file.sok)
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
    =/  =vase  .^(vase %cr (weld pax fyl))
    =/  old=(unit content:tarball)
      (~(get ba:tarball ball.acc) [dir name])
    =/  dais=(unit dais:clay)
      =/  c=(unit content:tarball)
        (~(get ba:tarball ball.acc) /sys/daises mar)
      ?~  c  ~
      `!<(dais:clay q.cage.u.c)
    ?~  dais
      ~&  [%sync-clay-skip-no-mark mar fyl]
      acc
    =/  old-vase=(unit ^vase)  ?~(old ~ `q.cage.u.old)
    =/  res=(each ^vase tang)
      (validate-vase:acc u.dais old-vase vase %.n)
    ?.  ?=(%& -.res)
      ~&  [%sync-clay-vale-failed mar fyl]
      acc
    (save-file:acc [dir name] [~ mar p.res])
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
  ::  For grubbery desk: incrementally rebuild changed mark/nexus caches
  =?  this  =(dek %grubbery)
    (rebuild-changed-caches pre-born)
  ::  Subscribe to %next %z on desk root
  %-  emit-card
  [%pass /clay-desk/[dek] %arvo %c %warp our.bowl dek `[%next %z da+now.bowl /]]
::  Incrementally rebuild mark/nexus caches for files that changed
::  during a grubbery desk sync.  Diffs born before/after to detect
::  which /mar/ and /nex/ files actually had content changes.
::
++  rebuild-changed-caches
  |=  pre-born=born:nexus
  ^+  this
  =/  clay-base=path  /sys/clay/grubbery
  ::  Diff born for /mar subtree to find changed marks
  =/  old-mar=born:nexus  (~(dip of pre-born) (weld clay-base /mar))
  =/  new-mar=born:nexus  (~(dip of born) (weld clay-base /mar))
  =/  mar-changed=(set lane:tarball)
    (diff-born-state:nexus old-mar new-mar)
  =/  changed-marks=(list mark)
    %+  murn  ~(tap in mar-changed)
    |=  =lane:tarball
    ?.  ?=([%& *] lane)  ~
    =/  nom=tape  (trip name.p.lane)
    =/  len=@ud  (lent nom)
    ?.  (gth len 5)  ~
    ?.  =(".hoon" (slag (sub len 5) nom))  ~
    `(crip (scag (sub len 5) nom))
  ::  Diff born for /nex subtree to find changed nexuses
  =/  old-nex=born:nexus  (~(dip of pre-born) (weld clay-base /nex))
  =/  new-nex=born:nexus  (~(dip of born) (weld clay-base /nex))
  =/  nex-changed=(set lane:tarball)
    (diff-born-state:nexus old-nex new-nex)
  =/  changed-necks=(list neck:tarball)
    %+  murn  ~(tap in nex-changed)
    |=  =lane:tarball
    ?.  ?=([%& *] lane)  ~
    =/  nom=tape  (trip name.p.lane)
    =/  len=@ud  (lent nom)
    ?.  (gth len 5)  ~
    ?.  =(".hoon" (slag (sub len 5) nom))  ~
    =/  stem=@ta  (crip (scag (sub len 5) nom))
    =/  segs=path  (snoc path.p.lane stem)
    `(rap 3 (join '-' segs))
  ::  Rebuild marks if any changed
  =?  this  ?=(^ changed-marks)
    ~&  >  [%sync-marks %rebuilding (lent changed-marks)]
    (rebuild-marks-incremental changed-marks)
  ::  Rebuild nexuses if any changed
  =?  this  ?=(^ changed-necks)
    ~&  >  [%sync-nexuses %rebuilding (lent changed-necks)]
    (rebuild-nexuses-incremental changed-necks)
  this
::  Rebuild daises and tubes for a list of changed marks
::
++  rebuild-marks-incremental
  |=  changed=(list mark)
  ^+  this
  =/  cores=(map mark vase)  (build-mark-cores:marks our.bowl q.byk.bowl now.bowl)
  =/  all-marks=(set mark)  ~(key by cores)
  =/  changed-set=(set mark)  (silt changed)
  ::  Rebuild daises for changed marks
  =.  ball
    %+  roll  changed
    |=  [mak=mark acc=_ball]
    =/  core=(unit vase)  (~(get by cores) mak)
    ?~  core
      (~(del ba:tarball acc) [/sys/daises mak])
    =/  res=(each dais:clay tang)
      (mule |.((build-dais:marks cores mak u.core)))
    ?:  ?=(%| -.res)
      %-  (%*(. slog pri 3) leaf+"{<mak>}: dais build failed" (flop p.res))
      acc
    (~(put ba:tarball acc) [/sys/daises mak] [~ %temp !>(p.res)])
  ::  Discover all tube pairs and rebuild those involving changed marks
  =/  pairs=(list mars:clay)
    %-  zing
    %+  turn  ~(tap by cores)
    |=  [mak=mark vas=vase]
    ^-  (list mars:clay)
    =/  [grab=(list mark) grow=(list mark)]
      :-  ?.  (slob %grab -:vas)  ~
          (sloe -:(slap vas [%limb %grab]))
      ?.  (slob %grow -:vas)  ~
      (sloe -:(slap vas [%limb %grow]))
    ;:  weld
      (murn grab |=(m=mark ?.((~(has in all-marks) m) ~ `[m mak])))
      (murn grow |=(m=mark ?.((~(has in all-marks) m) ~ `[mak m])))
    ==
  =/  affected=(list mars:clay)
    %+  skim  pairs
    |=  =mars:clay
    |((~(has in changed-set) a.mars) (~(has in changed-set) b.mars))
  =.  ball
    %+  roll  affected
    |=  [=mars:clay acc=_ball]
    =/  tub=(unit tube:clay)  (try-build-tube:marks cores mars)
    ?~  tub
      (~(del ba:tarball acc) [/sys/tubes/[a.mars] b.mars])
    (~(put ba:tarball acc) [/sys/tubes/[a.mars] b.mars] [~ %temp !>(u.tub)])
  ::  Delete all tubes for deleted marks
  =/  deleted=(list mark)
    (skip changed |=(mak=mark (~(has by cores) mak)))
  =.  ball
    %+  roll  deleted
    |=  [mak=mark acc=_ball]
    =.  acc  (~(lop ba:tarball acc) /sys/tubes/[mak])
    =/  sources=(list @ta)  (~(lss ba:tarball acc) /sys/tubes)
    %+  roll  sources
    |=  [src=@ta inner=_acc]
    (~(del ba:tarball inner) [/sys/tubes/[src] mak])
  ~&  >  [%marks-rebuilt (lent changed) %tubes (lent affected)]
  this
::  Rebuild nexus cores for a list of changed necks
::
++  rebuild-nexuses-incremental
  |=  changed=(list neck:tarball)
  ^+  this
  =/  base=path  /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)
  =.  ball
    %+  roll  changed
    |=  [=neck:tarball acc=_ball]
    =/  exists=?  .^(? %cu (weld base /nex/[neck]/hoon))
    ?.  exists
      (~(del ba:tarball acc) [/sys/nexuses neck])
    =/  res=(each vase tang)
      (mule |.(.^(vase %ca (weld base /nex/[neck]/hoon))))
    ?:  ?=(%| -.res)
      %-  (%*(. slog pri 3) leaf+"{<neck>}: nexus build failed" (flop p.res))
      acc
    =/  nex-res=(each nexus:nexus tang)
      (mule |.(!<(nexus:nexus p.res)))
    ?:  ?=(%| -.nex-res)
      %-  (%*(. slog pri 3) leaf+"{<neck>}: nexus type mismatch" (flop p.nex-res))
      acc
    (~(put ba:tarball acc) [/sys/nexuses neck] [~ %temp !>(p.nex-res)])
  ~&  >  [%nexuses-rebuilt (lent changed)]
  this
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
    ~&  >  [%clay-desk-deleted dek]
    (unmount-clay-desk dek)
  ::  Desk changed — re-sync files and re-subscribe
  ~&  >  [%clay-desk-changed dek]
  (sync-clay-desk dek)
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
  =.  this  (save-file [/sys/dill %'logs.dill-told'] [~ %dill-told !>(*told:dill)])
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
    (save-file:acc [/sys/dill/sessions ses] [~ %dill-blit !>(*(list blit:dill))])
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
    (save-file [/sys/jael %'private-keys.jael-private-keys'] [~ %jael-private-keys !>(*[life (map life ring)])])
  =.  this
    (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [~ %jael-public-keys-result !>(*public-keys-result:jael)])
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
  (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [~ %jael-public-keys-result !>(public-keys-result)])
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
          =(cage.u.old cage.new-content)
      ==
    this
  ::  Record content in silo and hist
  =.  this  (record-hist here cage.new-content ~)
  (bump-file here)
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
