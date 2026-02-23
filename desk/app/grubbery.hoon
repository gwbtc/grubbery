/-  spider
/+  default-agent, dbug, tarball, nexus, server
/=  t-  /tests/nexus
/=  t-  /tests/tarball
:: add /nex to the ford build cache for fast compilation
::
/~  nex  nexus:nexus  /nex
/~  ted  thread:spider  /ted
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
    abet:(reload:hc *pool:nexus init-ball *sand:nexus *born:nexus *subs:nexus)
  [cards this]
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
      abet:(reload:hc pool.old new-ball sand.old born.old subs.old)
    [cards this]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %grubbery-action
    =+  !<(=action:nexus vase)
    ?-    +<.action
        %poke
      ::  All pokes route through /peers/main gateway
      ?>  ?=(%& -.dest.action)
      =/  =give:nexus  [|+[src sap]:bowl wire.action]
      =^  cards  state
        abet:(poke:hc give [/peers %main] poke-in+!>([p.dest.action page.action]))
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
    ::  HTTP request from eyre: forward to /server/main
    ::
    ::  NOTE: HTTP requests go directly to /server/main, bypassing /peers.
    ::  Eyre gestures at treating them as "from a ship" via src.bowl —
    ::  this feels misleading.
    ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    =/  =give:nexus  [|+[src sap]:bowl /[eyre-id]]
    =^  cards  state
      abet:(poke:hc give [/server %main] handle-http-request+!>([eyre-id src.bowl req]))
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
      abet:(poke:hc give [/server %main] handle-http-cancel+!>(eyre-id))
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
    ?~  content  [~ ~]
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
::  Validate file content: handles %temp, empty-mime, scries for dais
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
  ::  Scry for dais (crashes if mark doesn't exist)
  =/  =dais:clay
    .^(dais:clay %cb /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/[mark])
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
  ~?  >>  ?=(^ (~(get ba:tarball ball) [dir name]))
    "no grub at {(spud (weld dir /[name]))}"
  ::  Clean up outgoing subscriptions from this file
  =.  this  (sub-wipe [dir name])
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
  |=  [here=fold:tarball sub-sand=sand:nexus sub-ball=ball:tarball]
  ^-  [sand:nexus ball:tarball]
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
  =/  res=[sand:nexus ball:tarball]
    ?~  nex  [sub-sand sub-ball]
    (on-load:u.nex sub-sand sub-ball)
  =:  sub-sand  -.res(fil parent-weir)
      sub-ball  +.res
  ==
  ::  Recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub-ball)
  |-
  ?~  kids  [sub-sand sub-ball]
  =/  kid-name=@ta  -.i.kids
  =/  kid-ball=ball:tarball  +.i.kids
  =/  kid-sand=sand:nexus  (~(dip of sub-sand) /[kid-name])
  =/  [new-kid-sand=sand:nexus new-kid-ball=ball:tarball]
    ^$(here (snoc here kid-name), sub-sand kid-sand, sub-ball kid-ball)
  =.  sub-sand  (put-sub-sand sub-sand /[kid-name] new-kid-sand)
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
  =/  parent-weir=(unit weir:nexus)  fil.sub-sand
  ::  Run on-load
  =/  res=[sand:nexus ball:tarball]  (on-load:u.nex sub-sand sub-ball)
  =/  new-sand=sand:nexus  -.res(fil parent-weir)
  =/  new-ball=ball:tarball  +.res
  ::  Put results back
  =/  old-born=born:nexus  born
  =.  sand  (put-sub-sand sand dest new-sand)
  =.  ball  (~(pub ba:tarball ball) dest new-ball)
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
      ==
  ^+  this
  ::  Nack pokes in old proc queues
  =.  this  (nack-pool / old-pool ~[leaf+"agent [re]loaded"])
  ::  Restore state (pool will be rebuilt)
  =.  ball  old-ball
  =.  sand  old-sand
  =.  born  old-born
  =.  subs  old-subs
  ::  Capture ball before modifications (for change detection)
  =/  pre-ball=ball:tarball  ball
  ::  Clear ephemeral %temp cages - they shouldn't survive reload
  =.  ball  ~(clear-temp ba:tarball ball)
  ::  Run nexus on-loads top-down (may modify ball and sand)
  =/  pre-sand=sand:nexus  sand
  =/  [new-sand=sand:nexus new-ball=ball:tarball]  (run-on-loads / sand ball)
  =:  sand  new-sand
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
::  Add subscription: watcher subscribes to target with wire
::
++  sub-put
  |=  [target=lane:tarball watcher=rail:tarball =wire]
  ^+  this
  ::  Add to forward index: target → (watcher → wire)
  =/  watchers=(map rail:tarball ^wire)
    (fall (~(get by fwd.subs) target) ~)
  =.  fwd.subs  (~(put by fwd.subs) target (~(put by watchers) watcher wire))
  ::  Add to reverse index: watcher → targets
  =.  rev.subs  (~(put ju rev.subs) watcher target)
  this
::  Remove subscription: watcher unsubscribes from target
::
++  sub-del
  |=  [target=lane:tarball watcher=rail:tarball]
  ^+  this
  ::  Remove from forward index
  =/  watchers=(map rail:tarball wire)
    (fall (~(get by fwd.subs) target) ~)
  =.  watchers  (~(del by watchers) watcher)
  =.  fwd.subs  ?~(watchers (~(del by fwd.subs) target) (~(put by fwd.subs) target watchers))
  ::  Remove from reverse index
  =.  rev.subs  (~(del ju rev.subs) watcher target)
  this
::  Remove all subscriptions from a watcher (for cleanup on death)
::
++  sub-wipe
  |=  watcher=rail:tarball
  ^+  this
  =/  targets=(set lane:tarball)  (~(get ju rev.subs) watcher)
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
  =/  watched=(list [target=lane:tarball watchers=(map rail:tarball wire)])
    ~(tap by fwd.subs)
  |-
  ?~  watched  this
  =/  [target=lane:tarball watchers=(map rail:tarball wire)]  i.watched
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
      [%file sk cage.u.content]
        %|
      =/  sub-ball=(unit ball:tarball)  (~(dap ba:tarball ball) p.target)
      ?~  sub-ball  [%none ~]
      [%ball (~(dip of sand) p.target) (~(dip of born) p.target) u.sub-ball]
    ==
  ::  Send to each watcher
  =.  this
    %-  ~(rep by watchers)
    |=  [[watcher=rail:tarball =wire] acc=_this]
    (enqu-take:acc watcher (sys-give:acc /news) ~ %news wire view)
  $(watched t.watched)
::  Fell a single subscription: remove from indices, send %fell to watcher
::
++  fell-sub
  |=  [target=lane:tarball watcher=rail:tarball]
  ^+  this
  =/  =wire  (~(got by (~(got by fwd.subs) target)) watcher)
  =.  this  (sub-del target watcher)
  (enqu-take watcher (sys-give /fell) ~ %fell wire)
::  Re-check subscriptions after weir change: fell any that are now blocked
::
++  audit-weir
  |=  base=path
  ^+  this
  ::  Find watchers whose path is under (or equal to) the changed weir
  =/  affected=(list rail:tarball)
    %+  murn  ~(tap in ~(key by rev.subs))
    |=  watcher=rail:tarball
    ?~((decap:tarball base path.watcher) ~ `watcher)
  |-
  ?~  affected  this
  =/  watcher=rail:tarball  i.affected
  =/  targets=(list lane:tarball)  ~(tap in (~(get ju rev.subs) watcher))
  =.  this
    |-
    ?~  targets  this
    =/  =filt:nexus  (allowed %peek watcher `i.targets)
    =?  this  ?=([~ %|] filt)  (fell-sub i.targets watcher)
    $(targets t.targets)
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
  =/  base=path  /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)
  =/  segs=(list path)  (segments:clay neck)
  |-
  ?~  segs  ~
  =/  pax=path  `path`[%nex (snoc i.segs %hoon)]
  ?.  .^(? %cu (weld base pax))
    $(segs t.segs)
  =+  .^(=vase %ca (weld base pax))
  (mole |.(!<(nexus:nexus vase)))
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
  ?+    filt  (handle-dart here dart)
      [~ %|]
    ::  Vetoed - send %veto intake back to source
    (enqu-take here (sys-give /veto) ~ %veto dart)
    ::
      [~ %&]
    ::  Allowed but should clam poke vases
    ::  (make darts don't need clamming - they go through validate-cage anyway)
    ?.  ?=([%node * * %poke *] dart)
      (handle-dart here dart)
    =/  clammed=(each cage tang)  (clam-cage cage.load.dart)
    ?:  ?=(%| -.clammed)
      (enqu-take here (sys-give /veto) ~ %veto dart)
    (handle-dart here dart(cage.load p.clammed))
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
      ?(%peek %keep %drop)        %peek  :: read operations
      %poke                       %poke
      ?(%make %cull %sand %load)  %make  :: all modify tree structure
    ==
  ==
::
++  handle-dart
  |=  [here=rail:tarball =dart:nexus]
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
      ::  Create file or directory - destination type must match payload type
      =/  res=(each _this tang)  (mule |.((make u.dest-lane make.load.dart)))
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
        %peek
      ::  Peek at dest - directory returns ball+sand, file returns cage
      ::  Returns %none if directory doesn't exist or has no lump
      ?-    -.u.dest-lane
          %|
        =/  dest=fold:tarball  p.u.dest-lane
        =/  sub-ball=(unit ball:tarball)  (~(dap ba:tarball ball) dest)
        ?~  sub-ball
          (enqu-take here (sys-give /peek) ~ %peek wire.dart &+[%none ~])
        =/  sub-sand=sand:nexus  (~(dip of sand) dest)
        =/  sub-born=born:nexus  (~(dip of born) dest)
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %ball sub-sand sub-born u.sub-ball)
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
        (enqu-take here (sys-give /peek) ~ %peek wire.dart %& %file sk cage.u.content)
      ==
      ::
        %keep
      ::  Subscribe to changes at dest (uses peek permission)
      =.  this  (sub-put u.dest-lane here wire.dart)
      (enqu-take here (sys-give /bond) ~ %bond wire.dart ~)
      ::
        %drop
      ::  Unsubscribe from dest
      =.  this  (sub-del u.dest-lane here)
      (enqu-take here (sys-give /fell) ~ %fell wire.dart)
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
    ::  State was valid, now delete
    =/  err=tang  ~[leaf+"process completed"]
    =.  this  (nack-poke-takes here next.new-proc err)
    =.  this  (nack-poke-takes here skip.new-proc err)
    =.  this  (clean (snoc path.here name.here) %file)
    (delete path.here name.here)
      %fail
    ::  Process failed - don't save state, clean subs, restart
    =.  this  (nack-poke-takes here next.new-proc err.res)
    =.  this  (nack-poke-takes here skip.new-proc err.res)
    =.  this  (clean (snoc path.here name.here) %file)
    =.  this  (sub-wipe here)
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
    ::  Make directory - payload must be [sand ball]
    ?>  ?=(%& -.make)
    =/  dest-path=fold:tarball  p.dest
    =/  new-sand=sand:nexus  sand.p.make
    =/  new-ball=ball:tarball  ball.p.make
    ::  Assert nothing exists at path
    =/  existing=ball:tarball  (~(dip ba:tarball ball) dest-path)
    ?:  |(?=(^ fil.existing) !=(~ dir.existing))
      ~|("path is not empty" !!)
    ::  Put new sand and ball at path
    =.  sand  (put-sub-sand sand dest-path new-sand)
    =.  ball  (~(pub ba:tarball ball) dest-path new-ball)
    ::  Run on-loads top-down (may modify sand and ball)
    =/  [rol-sand=sand:nexus rol-ball=ball:tarball]
      (run-on-loads dest-path new-sand new-ball)
    =:  new-sand  rol-sand
        new-ball  rol-ball
    ==
    ::  Validate all cages in loaded ball
    =/  validated=ball:tarball  ~|(%validate-ball-make (validate-ball new-ball))
    ::  Put the final sand and ball back
    =.  sand  (put-sub-sand sand dest-path new-sand)
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
      (validate-new-cage p.p.make ~ q.p.make %.n)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    ::  Save initial state (bumps file aeon since old content is ~)
    =.  this  (save-file dest-rail [~ p.p.make p.validated])
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
::  Diff two balls and bump all changes (new, changed, deleted files and empty dirs).
::
++  diff-balls
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  =/  old-born=born:nexus  born
  =.  born  (~(diff-balls bo:nexus now.bowl [born ball]) here old-ball new-ball)
  (notify old-born)
::  Spawn processes and sync all changes when a ball is created/reloaded.
::  Handles spawning files and bumping all changes (new, changed, deleted files, empty dirs).
::
++  load-ball-changes
  |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
  ^+  this
  =.  this  (spawn-all-files here new-ball)
  (diff-balls here old-ball new-ball)
::  Bump all changes when a ball is being deleted.
::  Diff old ball against empty ball to bump all files and empty dirs.
::
++  cull-ball-changes
  |=  [here=fold:tarball sub=ball:tarball]
  ^+  this
  (diff-balls here sub *ball:tarball)
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
    /(scot %da da.proc.sack)
    wire
  ==
::
++  unwrap-wire
  |=  =wire
  ^-  [rail:tarball @da ^wire]
  ?>  ?=([%proc @ *] wire)
  =/  len=@ud  (slav %ud i.t.wire)
  =/  here-path=path  (scag len t.t.wire)
  ?>  ?=(^ here-path)
  =/  here=rail:tarball  [(snip `path`here-path) (rear here-path)]
  =/  rest=^wire  (slag len t.t.wire)
  ?>  ?=([@ *] rest)
  =/  b=@da  (slav %da i.rest)
  [here b t.rest]
::
++  take-arvo
  |=  [wir=wire sign=sign-arvo]
  ^+  this
  =/  [here=rail:tarball b=@da =wire]  (unwrap-wire wir)
  =/  cur=(unit sack:nexus)  (get-born here)
  ?.  ?&(?=(^ cur) =(b da.proc.u.cur))  this
  (enqu-take here (sys-give /arvo) ~ %arvo wire sign)
::
++  take-agent
  |=  [wir=wire =sign:agent:gall]
  ^+  this
  =/  [here=rail:tarball b=@da =wire]  (unwrap-wire wir)
  =/  cur=(unit sack:nexus)  (get-born here)
  ?.  ?&(?=(^ cur) =(b da.proc.u.cur))  this
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
