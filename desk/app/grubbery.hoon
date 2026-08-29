/-  spider, push, grub
/+  nexus, tarball, build, marks,
    loader, fiberio, migrations, root,
    default-agent, dbug,
    server, http-utils, html-utils, json-utils,
    multipart, web-push,
    cram, pretty-file, zlib, bytestream,
    wasm-lia
::  These marks and tests are imported only so they compile when the
::  agent builds. A broken mark or test then fails the commit. The
::  m- and t- faces are never referenced.
::
/=  m-  /mar/hoon
/=  m-  /mar/tang
/=  m-  /mar/mime
/=  m-  /mar/kelvin
/=  m-  /mar/noun
/=  m-  /mar/sig
/=  m-  /mar/subs
/=  m-  /mar/kids
/=  m-  /mar/tree
/=  m-  /mar/born
/=  m-  /mar/bill
/=  m-  /mar/grubbery-intake
/=  m-  /mar/grubbery-load
/=  m-  /mar/grubbery-transfer
/=  m-  /mar/handle-http-request
/=  m-  /mar/handle-http-cancel
/=  m-  /mar/http-request
/=  m-  /mar/eyre/bindings
/=  m-  /mar/dill-blit
/=  m-  /mar/dill-told
/=  m-  /mar/timer-wake
/=  m-  /mar/jael-private-keys
/=  m-  /mar/jael-public-keys-result
/=  m-  /mar/docket-0
/=  m-  /mar/html
/=  m-  /mar/manx
/=  m-  /mar/css
/=  m-  /mar/js
/=  m-  /mar/json
/=  m-  /mar/md
/=  m-  /mar/txt
/=  m-  /mar/png
/=  m-  /mar/ico
/=  m-  /mar/svg
/=  m-  /mar/ud
/=  m-  /mar/wasm
/=  t-  /tests/nexus
/=  t-  /tests/tarball
/=  t-  /tests/build
/=  t-  /tests/loader
|%
+$  versioned-state
  $%  state-1:migrations
      state-0:migrations
  ==
+$  card  card:agent:gall
::  kel: the idea of kelvin-versioning the grubbery runtime itself.
::  Start from a large number and burn many kelvins at once as the
::  space of allowable changes shrinks toward a frozen runtime.
::  Nothing consumes this yet.
::
++  kel  21.000.000
:: The subject all code gets compiled against (/nex, /mar or /lib)
::
++  sut
  :: TODO: Need to determine how much actually needs to be in here...
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
            wasm=wasm-lia
        ==
  !>(..zuse)
--
::
=|  state-1:migrations
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
++  on-fail   on-fail:def
::
++  on-save
  ^-  vase
  ::  crash live processes so they rebuild in +on-load
  ::  without carrying continuations across the upgrade
  ::
  =.  pool  (bang-pool:hc pool %.y)
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old-state)
  ?-    -.old
      %0
    ~>  %slog.[0 leaf+"grubbery: migrating state %0 -> %1"]
    =.  state  (state-0-to-1:migrations old)
    =^  start-cards  state
      abet:cold-start:hc
    [start-cards this]
  ::
      %1
    =.  state  old
    =^  start-cards  state
      abet:cold-start:hc
    [start-cards this]
  ==
::
++  on-init
  ^-  (quip card _this)
  ::  genesis-bole: the tree grubbery is born with
  ::    the root nexus and an empty /code namespace to fill in
  ::
  =/  genesis-bole=bole:tarball
    :: / with neck /root
    ::
    :*  fil=`[neck=`[/ %root] weir=~ gain=%.n contents=~]
        ^=  dir
        %+  ~(put by *(map @ta bole:tarball))
          %code
        :: /code with neck /code
        ::
        :*  fil=`[neck=`[/ %code] weir=~ gain=%.n contents=~]
            dir=~
        ==
    ==
  ::  install the seed tree, then boot it — /code's empty stub must exist
  ::  before cold-start's sync-gub fills it, or the seed stomps it after.
  =^  lbc-cards  state  abet:(load-ball-changes:hc / genesis-bole)
  =^  cs-cards   state  abet:cold-start:hc
  :_(this (weld lbc-cards cs-cards))
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
    :: handling eyre requests to grubs
    ::
      %handle-http-request
    =^  cards  state
      abet:(route-http:hc !<([@ta inbound-request:eyre] vase))
    [cards this]
    ::  remote operation from another ship, over its ship.sig dart
    ::  a "load" is a payload. it's a request a grub can make with
    ::  respect to a place in the namespace. (poke, make, peek, etc)
    ::
      %grubbery-load
    =^  cards  state
      abet:(take-remote-load:hc !<(load:remo:nexus vase))
    [cards this]
    ::  runtime-to-runtime content-addressed negotiation
    ::  cross-ship peek logic
    ::
      %grubbery-transfer
    =^  cards  state
      abet:(take-remote-transfer:hc !<(transfer:remo:nexus vase))
    [cards this]
    :: cross-ship subscription updates
    ::
      %grubbery-intake
    =^  cards  state
      abet:(process-intake:hc src.bowl !<(intake:remo:nexus vase))
    [cards this]
    ::  Scry for dill sessions, sync subscriptions and grubs
    ::  dill sessions have no push signal; only available via scry,
    ::  so you have to stay up to date manually
    ::
      %grub-cmd
    ::  the thin agent-facing surface (sur/grub): plain-typed requests
    ::  from gall agents, local or remote; outcomes go out as
    ::  %grub-fact on the caller's /client/[id] subscription
    =^  cards  state
      abet:(handle-grub-cmd:hc src.bowl !<(cmd:grub vase))
    [cards this]
    ::
      %refresh-sessions
    ?>  =(src our):bowl
    =^  cards  state
      abet:sync-dill:hc
    [cards this]
      ::
      %set-upki
    ::  Set the rail whose file backs jael PKI subscriptions.
    ::  Jael subscribes on / and /(scot %p ship); grubbery gives
    ::  %azimuth-udiffs facts when the file at this rail changes.
    ::  (must be blot /urb-udiffs)
    ::
    ?>  =(src our):bowl
    :_  this(upki [~ !<(rail:tarball vase)])
    [%pass /jael-listen %arvo %j %listen ~ [%| %grubbery]]~
    ::  Subscribe to a gall agent, materialize at /sys/gall/
    ::
      %gall-watch
    ?>  =(src our):bowl
    =+  !<([=ship agent=dude:gall =path] vase)
    =^  cards  state
      abet:(gall-sub:hc ship agent path)
    [cards this]
    ::  Unsubscribe from a materialized gall subscription
    ::
      %gall-leave
    ?>  =(src our):bowl
    =+  !<([=ship agent=dude:gall =path] vase)
    =^  cards  state
      abet:(gall-unsub:hc ship agent path)
    [cards this]
    :: easy-to-reach-from-dojo utilities
    ::
      %noun
    =/  cmd  ;;(@tas q.vase)
    ?>  =(src.bowl our.bowl)
    ?+  cmd  ~|(%unknown-noun-poke !!)
      :: Force a reload of the root nexus (reboot the whole namespace)
      ::
        %reload
      ~&  >  %grubbery-reload
      =^  cards  state
        abet:cold-start:hc
      [cards this]
      ::
        %revalidate
      ~&  >  %grubbery-revalidate
      =^  cards  state
        abet:revalidate-all:hc
      [cards this]
      :: Tomb every audit-damaged version in place (see +repair-silo).
      :: Explicitly triggered only — corruption stays loud until a
      :: human asks for the cleanup.
      ::
        %silo-repair
      ~&  >  %grubbery-silo-repair
      =^  cards  state
        abet:repair-silo:hc
      [cards this]
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%http-response *]
    [~ this]
      ::  agent-facing response channel: subscribe before poking
      ::  %grub-cmd requests tagged with the same id
      [%client @ ~]
    [~ this]
      ::  Jael subscribes on / for all udiffs
      ::
      ~
    ?:  =(~ upki)  (on-watch:def path)
    =^  cards  state  abet:(serve-jael:hc ~)
    [cards this]
      ::  Jael subscribes on /(scot %p ship) for per-ship udiffs
      ::
      [@ ~]
    ?:  =(~ upki)  (on-watch:def path)
    =^  cards  state  abet:(serve-jael:hc path)
    [cards this]
  ==
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-leave:def path)
      [%http-response @ ~]
    =^  cards  state  abet:(cancel-http:hc i.t.path)
    [cards this]
      ::  a client channel died: drop the keeps it registered, so no
      ::  subscription outlives its subscriber
      [%client @ ~]
    =^  cards  state  abet:(drop-client-keeps:hc src.bowl i.t.path)
    [cards this]
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+    path  (on-peek:def path)
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
    ``kids+!>((lis-born t.t.t.path))
    ::
      [%x %peek %subd *]
    ::  Subdirectory names at path
    ``kids+!>((lss-born t.t.t.path))
    ::
      [%x %peek %tree *]
    ::  Tree structure with marks, no content
    =/  sub=ball:tarball  (peek-ball-now t.t.t.path)
    ``tree+!>((ball-to-tree:tarball sub))
    ::
    ::
      [%x %peek %born *]
    ::  Born (version tracking) subtree
    ``born+!>((~(dip of born) t.t.t.path))
    ::
      [%x %peek %silo %lobe @ ~]
    ::  Look up noun in silo by lobe hash
    =/  =nobe:nexus  (slav %uv i.t.t.t.t.path)
    =/  got=(unit noun)  (~(get si:nexus silo) nobe)
    ?~  got  [~ ~]
    ``noun+!>(u.got)
    ::
      [%x %peek %subs ~]
    ::  Internal subscriptions
    ``subs+!>(subs)
    ::
      [%x %peek %audit ~]
    ::  Silo audit: every referenced-but-absent lobe, rendered as
    ::  text lines (see +audit-silo / +audit-render)
    =/  hits  audit-silo:hc
    ~&  >  [%audit-hits (lent hits)]
    ``txt+!>(`wain`(audit-render:hc hits))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    wire
    ~&  >>>  "on-agent: unhandled wire {<wire>}"
    [~ this]
      ::  ames / remote-scry ack wires. success acks are ignored — the real
      ::  response arrives as a separate poke.
      ::  TODO: on a nack, clean up the staged peek/sub and notify the grub;
      ::        right now error acks leave state dangling.
      ::
      [?(%peek %want %keep %drop %wave %pack) *]
    [~ this]
    ::
      ::  a %poke load we forwarded for a fiber: success acks are
      ::  ignored — the consumption result arrives separately as a
      ::  %pack transfer. A nack means their gate refused the load
      ::  (veto or crash at admission); report that as the %pack.
      ::
      [%grub-poke *]
    ?>  ?=(%poke-ack -.sign)
    ?~  p.sign  [~ this]
    =^  cards  state
      abet:(take-grub-poke-nack:hc wire u.p.sign)
    [cards this]
    ::
      [%gall-sub *]
    =^  cards  state
      abet:(take-gall-sub:hc t.wire sign)
    [cards this]
    ::
      [%gall-poke *]
    ?>  ?=(%poke-ack -.sign)
    =^  cards  state
      abet:(take-gall-poke:hc t.wire sign)
    [cards this]
  ==
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+    wire
    ~&  >>>  "on-arvo: unhandled wire {<wire>}"
    [~ this]
    ::
      [%dill %logs ~]
    ?>  ?=([%dill %logs *] sign)
    =^  cards  state
      abet:(save-file:hc [/sys/dill %'logs.dill-told'] [[/ %dill-told] told.sign])
    [cards this]
    ::
      [%dill %session @ ~]
    ?>  ?=([%dill %blit *] sign)
    =/  ses=@tas  i.t.t.wire
    =^  cards  state
      abet:(save-file:hc [/sys/dill/sessions ses] [[/ %dill-blit] p.sign])
    [cards this]
    ::
      [%lick *]
    ?>  ?=([%lick %soak *] sign)
    =^  cards  state
      abet:(take-lick-soak:hc name.sign mark.sign noun.sign)
    [cards this]
    ::
      [%clay-desk @ ~]
    ?>  ?=([%clay %writ *] sign)
    =/  dek=desk  (slav %tas i.t.wire)
    =^  cards  state
      abet:(on-clay-writ:hc dek +>.sign)
    [cards this]
    ::
      [%jael %public ~]
    ?>  ?=([%jael %public-keys *] sign)
    =^  cards  state
      abet:(on-jael-public:hc public-keys-result.sign)
    [cards this]
    ::
      [%jael %private ~]
    ?>  ?=([%jael %private-keys *] sign)
    =^  cards  state
      abet:(save-file:hc [/sys/jael %'private-keys.jael-private-keys'] [[/ %jael-private-keys] [life.sign vein.sign]])
    [cards this]
    ::
      [%behn %snap-pin @ @ ~]
    ?>  ?=([%behn %wake *] sign)
    =^  cards  state
      abet:(expire-snap:hc t.t.wire error.sign)
    [cards this]
    ::
      [%behn %timer @ *]
    ?>  ?=([%behn %wake *] sign)
    =^  cards  state
      abet:(handle-timer-wake:hc t.t.wire error.sign)
    [cards this]
    ::
      [%iris %request @ *]
    ?>  ?=([%iris %http-response *] sign)
    =^  cards  state
      abet:(handle-iris-response:hc t.t.wire client-response.sign)
    [cards this]
    ::
      [%keen @ @ *]
    ::  The kernel answers a %keen with an %ames %sage gift, delivered
    ::  verbatim. sage = [spar dat=$@(~ (cask))]: the page bound at
    ::  the path, or ~ for nothing bound (a negative answer is still a
    ::  %sage). Other ames signs can ride this wire, an ack most of
    ::  all; anything that is not the %sage answer is ignored.
    ::
    ::  dat is the PUBLISHER's binding, fully attacker-controlled. ames
    ::  verifies the signature, not the shape: a hostile publisher can
    ::  bind a cell where the page's mark (an atom) belongs. A plain cast
    ::  passes that through, and the cell mark then crashes the
    ::  %keen-response vale downstream, which +validate-noun's mule turns
    ::  into a [%fail] that RESTARTS the reading fiber on every answer.
    ::  Clam to page inside a mule instead: a well-formed binding (mark
    ::  atom, body any noun, including a cell body) passes, and anything
    ::  malformed reads as ~ (nothing bound), a clean miss the reader
    ::  already handles. Same guard +keen:io keeps on the fiber side.
    ?.  ?=([%ames %sage *] sign)  [~ this]
    =*  sg  sage.sign
    =/  pag=(unit page)  (mole |.(;;(page `*`q.sg)))
    =^  cards  state
      abet:(take-keen-sage:hc t.wire ship.p.sg pag)
    [cards this]
    ::
      [%push %send @ *]
    ?>  ?=([%iris %http-response *] sign)
    =^  cards  state
      abet:(handle-push-response:hc t.t.wire client-response.sign)
    [cards this]
    ::
      ?([%eyre ~] [%eyre-bind ~] [%eyre-api ~] [%eyre-push ~])
    ::  surface rejected eyre bindings — silence here cost us dearly
    ~?  >>>  ?&(?=([%eyre %bound *] sign) !accepted.sign)
      [%eyre-rejected-binding path.binding.sign]
    [~ this]
  ==
--
::  the grubbery runtime. the gall arms above delegate the bulk of
::  their computation to this core, draining it through +abet.
::
::    A take is a grub input. takes is the queue of pending takes.
::    +abet lands each take in its grub's own queue and lets the grub
::    process that queue as far as it will go, which may queue
::    further takes. This proceeds, accumulating gall effects in
::    cards and modifying the grubbery namespace and state, until no
::    takes remain.
::
=|  cards=(list card)
=|  takes=(qeu take:nexus)
|_  =bowl:gall
+*  this  .
::  +carry-behn-state: one-time rename of the behn service grub from
::  its old name (main.timer-state). Reads the RAW noun via +sang-noun
::  — no mark, no validation — so it works from any past version, even
::  though the old mark file is gone and the old grub's view booms.
::  Union-merges into the new grub (same key = same timer) so a
::  both-exist pier loses nothing, then culls the old. Idempotent and
::  inert once no pier holds the old grub; cheap to keep forever.
::
++  carry-behn-state
  ^+  this
  =/  old-rail=rail:tarball  [/sys/behn %'main.timer-state']
  =/  new-rail=rail:tarball  [/sys/behn %'main.behn-state']
  =/  old-file  (peek-grub-now old-rail)
  ?~  old-file  this
  =/  old-st=(unit behn-state:nexus)
    (mole |.(;;(behn-state:nexus (sang-noun:tarball u.old-file))))
  ?~  old-st
    ~&  >>>  %carry-behn-state-unreadable-dropped
    (cull-if-exists %& old-rail)
  =/  new-file  (peek-grub-now new-rail)
  =/  new-st=behn-state:nexus
    ?~  new-file  [%0 ~]
    %+  fall
      (mole |.(;;(behn-state:nexus (sang-noun:tarball u.new-file))))
    [%0 ~]
  =/  merged=behn-state:nexus
    [%0 (~(uni by timers.u.old-st) timers.new-st)]
  =.  this  (save-file new-rail [[/ %behn-state] merged])
  (cull-if-exists %& old-rail)
++  cold-start
  ^-  _this
  =.  this  bootstrap-marcs
  =.  this  sync-gub
  =.  this  rebuild-stale-code
  =.  this  carry-behn-state
  =.  this  (reload-nexus-at / root)
  =.  this  purge-stale-code
  =.  this  (build-new-code-namespaces / (peek-bole-now /))
  =.  this  (spawn-all-files / (peek-bole-now /))
  =.  this  sync-dill
  =.  this  sync-clay
  =.  this  sync-jael
  =.  this  sync-bowl
  =.  this  sync-peer
  =.  this  sync-gall
  =.  this  sync-lick
  =.  this  sync-eyre
  sync-push
::  +put-pace: write a pace into a born tree at the given dest lane.
::  Used to record remote peek results.
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
    =/  new-hist=hist:nexus  (put-pace:hist:nexus sk cas pace)
    (~(put of born) path.r node(file (~(put by file.node) name.r new-hist)))
      %|
    =/  dir=path  p.dest
    =/  node=[fold=hist:nexus file=(map @ta hist:nexus)]
      (fall (~(get of born) dir) default-node:~(. bo:nexus now.bowl born))
    =/  top-cas=(unit cass:clay)  (top:hist:nexus fold.node)
    =/  next-ud=@ud  ?~(top-cas 1 +(ud.u.top-cas))
    =/  cas=cass:clay  [next-ud now.bowl]
    =/  new-fold=hist:nexus  (put-pace:hist:nexus fold.node cas pace)
    (~(put of born) dir node(fold new-fold))
  ==
::  +release-snap-refs: drop the silo refcounts a snap holds
::
::    A snap bumps a refcount on every lobe it references so the
::    content survives tombstoning while the snap is alive. This
::    undoes exactly those bumps when the snap is released. Call it
::    only with lobes the snap bumped, or the counts drift.
::
++  release-snap-refs
  |=  refs=lobes:nexus
  ^-  silo:nexus
  =.  silo
    %+  roll  ~(tap in jects.refs)
    |=  [=jobe:nexus s=_silo]
    (~(drop-ject si:nexus s) jobe)
  %+  roll  ~(tap in nouns.refs)
  |=  [=nobe:nexus s=_silo]
  (~(drop si:nexus s) nobe)
::  +audit-silo: report every version whose content is not fully
::  present in the silo — the landmines left by refcount bugs, each a
::  read that will boom when touched. Read-only by design: repair is
::  a separate, explicitly-triggered pass, because corruption from a
::  bug should stay loud until a human has seen it.
::
::  No tree traversal (per Thomas): content-addressing gives an
::  induction — a version's closure is fully present iff its root
::  ject is present and no present ject anywhere references anything
::  absent or broken. So: one flat pass over the silo finds broken
::  jects, a small fixpoint propagates brokenness upward, and each
::  hist entry is then a single lookup against that set.
::
++  audit-silo
  ^-  (list [pax=path name=(unit @ta) =cass:clay latest=? kind=?(%ject %noun) lobe=@])
  =/  broken=(set jobe:nexus)  broken-jects
  =/  hits=(list [pax=path name=(unit @ta) =cass:clay latest=? kind=?(%ject %noun) lobe=@])  ~
  =/  nodes=(list [pax=path node=_born])  [[/ born] ~]
  |-  ^+  hits
  ?~  nodes  hits
  =/  [pax=path node=_born]  i.nodes
  =/  more=(list [pax=path node=_born])
    %+  weld  t.nodes
    (turn ~(tap by dir.node) |=([k=@ta n=_born] [(snoc pax k) n]))
  ?~  fil.node  $(nodes more)
  =/  jobs=(list [name=(unit @ta) sk=hist:nexus])
    :-  [~ fold.u.fil.node]
    (turn ~(tap by file.u.fil.node) |=([n=@ta sk=hist:nexus] [`n sk]))
  |-  ^+  hits
  ?~  jobs  ^$(nodes more)
  =/  [name=(unit @ta) sk=hist:nexus]  i.jobs
  =/  top=(unit cass:clay)  (top:hist:nexus sk)
  =/  entries=(list [key=cass:clay val=entry:hist:nexus])  (tap:hon:hist:nexus sk)
  |-  ^+  hits
  ?~  entries  ^$(jobs t.jobs)
  =/  [key=cass:clay val=entry:hist:nexus]  i.entries
  ?:  ?=(%tomb -.pace.val)  $(entries t.entries)
  ?~  p.pace.val  $(entries t.entries)
  =/  root=jobe:nexus  u.p.pace.val
  =/  absent=?  !(~(has by jects.silo) root)
  ?.  |(absent (~(has in broken) root))
    $(entries t.entries)
  =/  latest=?  =(`key top)
  $(entries t.entries, hits [[pax name key latest %ject `@`root] hits])
::  +broken-jects: every present ject whose closure is incomplete.
::  Seed: jects with an absent immediate reference (leaf noun or tree
::  child). Fixpoint: jects referencing a broken ject are broken.
::  Rounds bound = damage-chain depth.
::
++  broken-jects
  ^-  (set jobe:nexus)
  =/  broken=(set jobe:nexus)  ~
  |-
  =/  next=(set jobe:nexus)
    %+  roll  ~(tap by jects.silo)
    |=  [[j=jobe:nexus jot=[refs=@ud =ject:nexus]] acc=_broken]
    ?:  (~(has in acc) j)  acc
    =/  bad=?
      ?-    -.ject.jot
          %leaf
        !(~(has by nouns.silo) lobe.leaf.ject.jot)
          %tree
        =/  kids=(list jobe:nexus)
          %+  weld
            (turn ~(val by fil.tree.ject.jot) |=(x=jobe:nexus x))
          (turn ~(val by dir.tree.ject.jot) |=([x=jobe:nexus *] x))
        %+  lien  kids
        |=  k=jobe:nexus
        |(!(~(has by jects.silo) k) (~(has in broken) k))
      ==
    ?.(bad acc (~(put in acc) j))
  ?:  =(~(wyt in next) ~(wyt in broken))  broken
  $(broken next)
::  +audit-render: one text line per audit hit, count first
::
++  audit-render
  |=  hits=(list [pax=path name=(unit @ta) =cass:clay latest=? kind=?(%ject %noun) lobe=@])
  ^-  wain
  :-  (crip "{(a-co:co (lent hits))} referenced-but-absent lobes")
  %+  turn  hits
  |=  h=[pax=path name=(unit @ta) =cass:clay latest=? kind=?(%ject %noun) lobe=@]
  =/  fil=tape  (spud ?~(name.h pax.h (snoc pax.h u.name.h)))
  =/  ver=tape  (a-co:co ud.cass.h)
  =/  lob=tape  (scow %uv lobe.h)
  (crip "{fil}  v{ver}{?:(latest.h "  LATEST" "")}  %{(trip kind.h)}  {lob}")
::  +repair-silo: tomb every audit-damaged version in place. The
::  content is gone; the tomb makes the books say so instead of
::  booming readers. Latest versions are never touched. Explicitly
::  triggered only (%silo-repair poke) — never automatic.
::
++  repair-silo
  ^+  this
  ::  iterate to fixpoint: the audit attributes shared deep damage to
  ::  one referencing version per walk (the ok cache marks subtrees
  ::  visited, not verified-clean), so one sweep peels one layer.
  ::  Loop until a sweep changes nothing — remaining hits are then
  ::  latest-guarded only, and clear on their next natural demotion.
  =/  rounds=@ud  0
  |-
  ?:  (gte rounds 100)
    ~&  >>>  [%silo-repair-round-cap rounds]
    this
  =/  dmg=(list [pax=path name=(unit @ta) =cass:clay])
    =-  ~(tap in -)
    %-  sy
    %+  turn  audit-silo
    |=  [pax=path name=(unit @ta) =cass:clay latest=? kind=?(%ject %noun) lobe=@]
    [pax name cass]
  ?~  dmg
    ~&  >  [%silo-repair-clean rounds=rounds]
    this
  ~&  >  [%silo-repair round=rounds damaged-versions=(lent dmg)]
  =/  before  this
  =/  todo=(list [pax=path name=(unit @ta) =cass:clay])  dmg
  =.  this
    |-
    ?~  todo  this
    =.  this  (tomb-version [pax name cass]:i.todo)
    $(todo t.todo)
  ?:  =(born.before born)
    ~&  >  [%silo-repair-remaining-latest-guarded (lent dmg)]
    this
  $(rounds +(rounds))
::  +tomb-version: rewrite one hist entry's pace to %tomb, releasing
::  the ref the pace held (cascade prints for already-absent lobes
::  are expected and tolerated — that's the corpse being buried)
::
++  tomb-version
  |=  [pax=path name=(unit @ta) =cass:clay]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) pax)
  ?~  node  this
  =/  sk=hist:nexus
    ?~  name  fold.u.node
    (fall (~(get by file.u.node) u.name) *hist:nexus)
  ?:  =(`cass (top:hist:nexus sk))
    ~&  >>>  [%silo-repair-skipping-latest pax name]
    this
  =/  ent=(unit entry:hist:nexus)  (get:hon:hist:nexus sk cass)
  ?~  ent  this
  ?:  ?=(%tomb -.pace.u.ent)  this
  ~&  >  [%silo-tombed pax name ud=ud.cass]
  =?  silo  ?=(^ p.pace.u.ent)
    (~(drop-ject si:nexus silo) u.p.pace.u.ent)
  =/  new-hist=hist:nexus
    (put:hon:hist:nexus sk cass u.ent(pace [%tomb ~]))
  =.  born
    ?~  name  (~(put of born) pax u.node(fold new-hist))
    (~(put of born) pax u.node(file (~(put by file.u.node) u.name new-hist)))
  this
::  +discharge-peeks: discharge staged peeks whose refs have all arrived
::
::    Sweeps the staged cross-ship peeks. If every ref a peek's snap
::    names is now in the local silo, the requesting grub can read the
::    content it asked for: it gets its %peek intake and the staged
::    peek is removed.
::
++  discharge-peeks
  ^+  this
  =/  entries=(list [[=rail:tarball =wire] =peek:remo:nexus])
    ~(tap by peeks.remo)
  =/  have-jects=(set jobe:nexus)  ~(key by jects.silo)
  =/  have-nouns=(set nobe:nexus)  ~(key by nouns.silo)
  |-
  ?~  entries  this
  =/  [key=[=rail:tarball =wire] pk=peek:remo:nexus]  i.entries
  ?~  snap.pk
    ::  Still waiting for %snap — skip
    $(entries t.entries)
  =/  missing=lobes:nexus
    :-  (~(dif in jects.refs.u.snap.pk) have-jects)
    (~(dif in nouns.refs.u.snap.pk) have-nouns)
  ?.  &(=(~ jects.missing) =(~ nouns.missing))
    ::  Not all refs present yet — skip
    $(entries t.entries)
  ::  All refs present — discharge: build view from snap+silo,
  ::  send %peek intake to the requesting fiber.
  ~&  >  [%peek-discharged ship.pk dest.pk key=key peeks-remaining=~(wyt by peeks.remo)]
  =/  =cite:nexus
    ?:  ?=(%tomb -.pace.u.snap.pk)  [%none ~]
    ?~  p.pace.u.snap.pk  [%none ~]
    ?-  -.dest.pk
      %|  [%ball *wave:nexus u.p.pace.u.snap.pk deep.pk]
      %&  [%file cass.u.snap.pk u.p.pace.u.snap.pk blot.pk]
    ==
  ::  Bump silo ref for data-carrying cites — %file and %ball both
  ::  carry a lobe that +hydrate drops after reading, so both must
  ::  bump here or every discharged remote file peek nets -1 and
  ::  bleeds shared content out of the silo.
  =?  silo  ?=([%ball *] cite)
    (~(bump-ject-ref si:nexus silo) lobe.cite)
  =?  silo  ?=([%file *] cite)
    (~(bump-ject-ref si:nexus silo) lobe.cite)
  =?  silo  ?=([%file *] cite)
    (~(bump-ject-ref si:nexus silo) lobe.cite)
  =.  this  (enqu-take rail.key ~ ~ %peek wire.key cite)
  =.  peeks.remo  (~(del by peeks.remo) key)
  $(entries t.entries)
::  ship-sig-rail: the /sys/ames/ships/[who]/ship.sig rail a remote ship's
::  darts arrive from. our own ship has no weir (full access); foreign ships
::  get their weir from usergroups.
::
++  ship-sig-rail
  |=  who=@p
  ^-  rail:tarball
  [/sys/ames/ships/[(scot %p who)] %'ship.sig']
::  take-remote-load: a remote ship's operation, dispatched by kind. peek/
::  keep/drop are weir-gated and answered directly; the rest become darts
::  routed through the peer system from the caller's ship.sig.
::
::  the agent-facing surface (sur/grub): thin plain-typed cmds from
::  gall agents, local or remote. One identity model for every
::  caller: the poking SHIP's ship.sig, our own included — local
::  privilege is the absence of a weir on your own path. Readers get
::  MATERIALIZED content (gnode: raw [mark noun], simplified trees);
::  the content-addressed snap protocol stays grubbery-to-grubbery.
::  Outcomes ride %grub-fact on /client/[id]: peeks answer here
::  synchronously, dart outcomes arrive via +process-take's client
::  forward.
::
::  +drop-client-keeps: remove every keep a client channel registered
::  (watcher = the ship.sig, stored wire = the channel). Runs on
::  on-leave so agent subscriptions never leak. Note: subs key by
::  watcher RAIL, so two channels of one ship keeping the same target
::  share (and clobber) one entry — a known v1 limitation.
::
++  drop-client-keeps
  |=  [src=@p id=@ta]
  ^+  this
  =/  watcher=rail:tarball  (ship-sig-rail src)
  =/  cwire=wire  /client/[id]
  =/  all  tap-fwd
  |-
  ?~  all  this
  =/  [target=lane:tarball watchers=(map rail:tarball [=wire blot=(unit blot:tarball)])]  i.all
  =/  ent  (~(get by watchers) watcher)
  =?  this  &(?=(^ ent) =(cwire wire.u.ent))
    (sub-del target watcher)
  $(all t.all)
::
++  give-client-fact
  |=  [id=@ta =res:grub]
  ^+  this
  (emit-card [%give %fact ~[/client/[id]] %grub-fact !>(`fact:grub`[id res])])
::
++  handle-grub-cmd
  |=  [src=@p =cmd:grub]
  ^+  this
  =.  this  (ensure-peer-ship src)
  =/  caller=rail:tarball  (ship-sig-rail src)
  =/  cwire=wire  /client/[chan.cmd]
  =/  op  op.cmd
  ?-    -.op
      %poke
    %+  process-dart  caller
    [%node cwire [%& %& [path.op name.op]] %poke [[/ mark.op] noun.op]]
  ::
      %make-file
    ::  a conflicting make crashes the event kernel-side; answer it as
    ::  an error fact instead
    ?:  &(!force.op ?=(^ (peek-grub-now path.op name.op)))
      (give-client-fact chan.cmd [%ack `~[leaf+"already exists"]])
    %+  process-dart  caller
    :^  %node  cwire  [%& %& [path.op name.op]]
    [%make force.op %.y %| [[/ mark.op] noun.op] ~]
  ::
      %make-dir
    ?:  &(!force.op ?=(^ (~(get of born) path.op)))
      (give-client-fact chan.cmd [%ack `~[leaf+"already exists"]])
    %+  process-dart  caller
    :^  %node  cwire  [%& %| path.op]
    [%make force.op %.y %& `[~ ~ %.n ~] ~]
  ::
      %cull
    =/  dest=lane:tarball
      ?~  name.op  [%| path.op]
      [%& [path.op u.name.op]]
    =/  exists=?
      ?-  -.dest
        %&  ?=(^ (peek-grub-now p.dest))
        %|  ?=(^ (~(get of born) p.dest))
      ==
    ?.  exists
      (give-client-fact chan.cmd [%ack `~[leaf+"nothing there"]])
    (process-dart caller [%node cwire [%& dest] %cull ~])
  ::
      %keep
    ::  subscribe the channel to a target: %news facts on changes.
    ::  Gated like a read. The watcher is the caller's ship.sig with
    ::  the client wire — +notify's client branch routes it to facts.
    =/  target=lane:tarball
      ?~  name.op  [%| path.op]
      [%& [path.op u.name.op]]
    ?:  ?=([~ %|] (allowed %peek caller `target))
      (give-client-fact chan.cmd [%ack `~[leaf+"vetoed by weir"]])
    =.  this  (sub-put target caller cwire ~)
    (give-client-fact chan.cmd [%ack ~])
  ::
      %drop
    =/  target=lane:tarball
      ?~  name.op  [%| path.op]
      [%& [path.op u.name.op]]
    =.  this  (sub-del target caller)
    (give-client-fact chan.cmd [%ack ~])
  ::
      %peek
    ::  synchronous: the data is local, no snap negotiation. Weir
    ::  check first; a vetoed or absent read is a clean answer.
    =/  dest=lane:tarball
      ?~  name.op  [%| path.op]
      [%& [path.op u.name.op]]
    ?:  ?=([~ %|] (allowed %peek caller `dest))
      (give-client-fact chan.cmd [%ack `~[leaf+"vetoed by weir"]])
    ?-    -.dest
        %&
      =/  got  (peek-grub-now p.dest)
      ?~  got  (give-client-fact chan.cmd [%miss ~])
      %+  give-client-fact  chan.cmd
      [%got %file name.p.u.got (sang-noun:tarball u.got)]
    ::
        %|
      ?~  (~(get of born) p.dest)
        (give-client-fact chan.cmd [%miss ~])
      =/  =ball:tarball  (peek-ball-now p.dest)
      ?.  deep.op
        %+  give-client-fact  chan.cmd
        :+  %got  %ls
        %+  weld
          ?~(fil.ball ~ (turn ~(tap by contents.u.fil.ball) head))
        (turn ~(tap by dir.ball) head)
      (give-client-fact chan.cmd [%got (ball-to-gnode ball)])
    ==
  ==
::  +ball-to-gnode: materialize a peeked ball as a plain tree. Content
::  goes out raw via +sang-noun — booms included as their underlying
::  noun, validation is the reader's job.
::
++  ball-to-gnode
  |=  b=ball:tarball
  ^-  gnode:grub
  :-  %tree
  %-  ~(gas by *(map @ta gnode:grub))
  ^-  (list [@ta gnode:grub])
  %+  weld
    ^-  (list [@ta gnode:grub])
    ?~  fil.b  ~
    %+  turn  ~(tap by contents.u.fil.b)
    |=  [nam=@ta ent=[=sang:tarball gain=? bang=(unit tang)]]
    [nam %file name.p.sang.ent (sang-noun:tarball sang.ent)]
  %+  turn  ~(tap by dir.b)
  |=  [nam=@ta sub=ball:tarball]
  [nam (ball-to-gnode sub)]
::
++  take-remote-load
  |=  req=load:remo:nexus
  ^+  this
  =.  this  (ensure-peer-ship src.bowl)
  =/  caller=rail:tarball  (ship-sig-rail src.bowl)
  =/  dart  |=(l=load:nexus (process-dart caller [%node /peer [%& dest.req] l]))
  ?-  +<.req
    %peek  (process-peek caller req)
    %keep  (process-keep caller req)
    %drop  (process-drop caller req)
    ::  pokes keep the request wire so the consumption %pack lands on
    ::  the caller's ship.sig with the sender-encoded return address
    ::  (see the forward in +process-take)
    %poke  (process-dart caller [%node wire.req [%& dest.req] %poke bask.req])
    %make  (dart [%make force.req gain.req make.req])
    %cull  (dart [%cull ~])
    %sand  (dart [%sand weir.req])
    %load  (dart [%load ~])
  ==
::  process-peek: resolve a remote peek. weir-gate first; a blocked peek is
::  vetoed. otherwise resolve the case/pace, pin the reachable refs so they
::  survive tombstoning until the %want arrives (kind-directed — reachable
::  told us which store each lobe is in), arm a 5-minute expiry, and snap the
::  result back.
::
++  process-peek
  |=  [caller=rail:tarball req=load:remo:nexus]
  ^+  this
  ?>  ?=(%peek +<.req)
  =/  dest-lane=lane:tarball  dest.req
  ?:  ?=([~ %|] (allowed %peek caller `dest-lane))
    (respond-transfer %peek [wire.req %veto dest-lane])
  =/  snap=(unit snap:remo:nexus)
    =/  cas-pace=(unit [=cass:clay =pace:hist:nexus])
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
          =/  pac  (get-pace:hist:nexus sk u.cas)
          ?~  pac  ~
          (some [cass=u.cas pace=u.pac])
        =/  cp  (resolve-case:nexus u.case.req sk)
        ?~  cp  ~
        (some [cass=cass.u.cp pace=pace.u.cp])
          %|
        =/  dest=fold:tarball  p.dest-lane
        =/  sub-born=born:nexus  (~(dip of born) dest)
        ?~  fil.sub-born  ~
        =/  sk=hist:nexus  fold.u.fil.sub-born
        ?~  case.req
          =/  cas=(unit cass:clay)  (top:hist:nexus sk)
          ?~  cas  ~
          =/  pac  (get-pace:hist:nexus sk u.cas)
          ?~  pac  ~
          (some [cass=u.cas pace=u.pac])
        =/  cp  (resolve-case:nexus u.case.req sk)
        ?~  cp  ~
        (some [cass=cass.u.cp pace=pace.u.cp])
      ==
    ?~  cas-pace  ~
    =/  refs=lobes:nexus
      ?:  ?=(%tomb -.pace.u.cas-pace)  [~ ~]
      ?~  p.pace.u.cas-pace  [~ ~]
      ?:  deep.req
        (~(reachable si:nexus silo) u.p.pace.u.cas-pace)
      (~(reachable-shallow si:nexus silo) u.p.pace.u.cas-pace)
    `[cass.u.cas-pace pace.u.cas-pace refs]
  =/  snap-id=@uvJ  `@uvJ`(shaz eny.bowl)
  ::  Inline the payload when it's cheaper to send than to negotiate:
  ::  the subset rides in the snap, the receiver skips want/data, and
  ::  no pin is needed since no %want will ever come.
  =/  inline=(unit silo:nexus)
    ?~  snap  ~
    =/  n-refs=@ud
      (add ~(wyt in jects.refs.u.snap) ~(wyt in nouns.refs.u.snap))
    ?:  (gth n-refs max-inline-refs)  ~
    =/  send=silo:nexus  (snap-subset refs.u.snap)
    =/  size=@ud
      %+  roll  ~(tap by nouns.send)
      |=  [[* refs=@ud =noun] acc=@ud]
      (add acc ?@(noun (met 3 noun) (met 3 (jam noun))))
    =.  size  (add size (mul 128 ~(wyt by jects.send)))
    ?:  (gth size max-inline-bytes)  ~
    `send
  =/  pinned=?  &(?=(^ snap) ?=(~ inline))
  =?  silo  &(?=(^ snap) pinned)
    =.  silo
      %+  roll  ~(tap in jects.refs.u.snap)
      |=  [=jobe:nexus s=_silo]
      (~(bump-ject-ref si:nexus s) jobe)
    %+  roll  ~(tap in nouns.refs.u.snap)
    |=  [=nobe:nexus s=_silo]
    (~(bump-ref si:nexus s) nobe)
  =/  expiry=@da  (add now.bowl ~m5)
  =?  snaps.remo  &(?=(^ snap) pinned)
    (~(put by snaps.remo) [snap-id src.bowl] [dest-lane refs.u.snap expiry])
  =?  cards  &(?=(^ snap) pinned)
    :_  cards
    [%pass /behn/snap-pin/[(scot %uv snap-id)]/[(scot %p src.bowl)] %arvo %b %wait expiry]
  (respond-transfer %peek [wire.req %snap dest-lane snap-id snap inline])
::  process-keep: register the caller as a remote watcher, unless the weir
::  gate blocks it (a vetoed subscribe is silently dropped).
::
++  process-keep
  |=  [caller=rail:tarball req=load:remo:nexus]
  ^+  this
  ?>  ?=(%keep +<.req)
  ?:  ?=([~ %|] (allowed %peek caller `dest.req))
    this
  (keep caller dest.req wire.req)
::  process-drop: remove the caller as a remote watcher.
::
++  process-drop
  |=  [caller=rail:tarball req=load:remo:nexus]
  ^+  this
  ?>  ?=(%drop +<.req)
  (drop caller dest.req)
::  take-remote-transfer: a content-negotiation message. snap/data/veto/miss
::  are responses to things we asked for (processed locally, no auth); want is
::  an inbound request we serve from a pinned snap.
::
++  take-remote-transfer
  |=  req=transfer:remo:nexus
  ^+  this
  =.  this  (ensure-peer-ship src.bowl)
  ?-  +<.req
    %want  (process-want req)
    %pack  (process-pack src.bowl req)
    ?(%snap %data %veto %miss)  (process-transfer src.bowl req)
  ==
::  process-pack: a remote ship reports the consumption result of a
::  poke we sent it. Decode the sender from the wire (the encoding
::  from +dart-poke's remote branch) and poke the originating grub
::  with the result — the cross-ship sibling of +take-gall-poke.
::
++  process-pack
  |=  [src=@p req=transfer:remo:nexus]
  ^+  this
  ?>  ?=(%pack +<.req)
  =/  segs=wire  wire.req
  ?.  ?=([%grub-poke @ *] segs)  this
  =/  path-len=@ud  (slav %ud i.t.segs)
  =/  from-path=path  (scag path-len t.t.segs)
  =/  rest=wire  (slag path-len t.t.segs)
  ?~  rest  this
  =/  sender=rail:tarball  [from-path i.rest]
  =/  orig-wire=wire  t.rest
  ::  deliver the cross-ship consumption result as a normal %pack on the
  ::  sender's wire — identical to a local poke's pack, so awaiters don't
  ::  fork on reach.
  (enqu-take sender ~ ~ %pack orig-wire err.req)
::  process-want: a remote ship wants the content behind a snap it holds. look
::  up the pinned snap; miss if unknown. otherwise serve every pinned lobe from
::  its store (kind-directed; a pinned lobe gone missing is a books error worth
::  hearing about), then release the snap and cancel its timer.
::
++  process-want
  |=  req=transfer:remo:nexus
  ^+  this
  ?>  ?=(%want +<.req)
  =/  pin-key=[@uvJ @p]  [snap-id.req src.bowl]
  =/  pin  (~(get by snaps.remo) pin-key)
  ?~  pin
    (respond-transfer %want [/want %miss ~])
  =/  send=silo:nexus  (snap-subset refs.u.pin)
  ::  release the snap, drop refs, cancel the pin timer
  =.  snaps.remo  (~(del by snaps.remo) pin-key)
  =.  silo  (release-snap-refs refs.u.pin)
  =.  vale  (gc-vale-cache vale bins)
  =.  cards
    :_  cards
    :*  %pass
        /behn/snap-pin/[(scot %uv snap-id.req)]/[(scot %p src.bowl)]
        %arvo  %b  %rest  expiry.u.pin
    ==
  (respond-transfer %want [/want %data send])
::  merge-transfer-data: fold received content into the silo and
::  settle the peeks it satisfies. Verify hashes, merge (insert at
::  refcount 1 or bump), discharge, then release exactly what this
::  handler merged — the transfer is a temporary owner that keeps
::  the data alive through the discharge sweep, where cites claim
::  their own refs. Unmerged lobes (hash mismatch, already-present
::  refs never sent) are never released: release only mirrors this
::  handler's bumps. Shared by %data transfers and inline snaps.
::
++  merge-transfer-data
  |=  got=silo:nexus
  ^+  this
  =/  good-nouns=(list [=nobe:nexus =noun])
    %+  murn  ~(tap by nouns.got)
    |=  [=nobe:nexus refs=@ud =noun]
    ?.  =(nobe `@uvI`(sham noun))
      ~&  >>  [%data-hash-mismatch %noun nobe]
      ~
    `[nobe noun]
  =/  good-jects=(list [=jobe:nexus =ject:nexus])
    %+  murn  ~(tap by jects.got)
    |=  [=jobe:nexus refs=@ud =ject:nexus]
    ?.  =(jobe `@uvI`(sham ject))
      ~&  >>  [%data-hash-mismatch %ject jobe]
      ~
    `[jobe ject]
  ::  Merge verified data into silo: insert at refcount 1 if new,
  ::  bump refcount if already present.
  =.  silo
    %+  roll  good-nouns
    |=  [[=nobe:nexus =noun] s=_silo]
    =/  existing  (~(get by nouns.s) nobe)
    ?~  existing
      s(nouns (~(put by nouns.s) nobe [1 noun]))
    s(nouns (~(put by nouns.s) nobe u.existing(refs +(refs.u.existing))))
  ::  Jects must insert bottom-up: put-ject bumps a new ject's
  ::  children only if they are already present. Topologically
  ::  insert — a tree waits until its child jects are in the silo.
  =.  silo
    =/  pending=(list [=jobe:nexus =ject:nexus])  good-jects
    |-
    ?:  =(~ pending)  silo
    =/  ready=(list [=jobe:nexus =ject:nexus])
      %+  skim  `(list [=jobe:nexus =ject:nexus])`pending
      |=  [=jobe:nexus =ject:nexus]
      ?.  ?=(%tree -.ject)  %.y
      =/  kids=(list jobe:nexus)
        %+  weld
          (turn ~(val by fil.tree.ject) |=(j=jobe:nexus j))
        (turn ~(val by dir.tree.ject) |=([j=jobe:nexus *] j))
      %+  levy  kids
      |=(j=jobe:nexus (~(has by jects.silo) j))
    ::  Nothing ready but work remains: refs point outside this
    ::  transfer and are absent — insert anyway rather than loop.
    =/  batch=(list [=jobe:nexus =ject:nexus])
      ?~(ready pending ready)
    ~?  >>  =(~ ready)  [%data-merge-unresolved-children (lent pending)]
    =.  silo
      %+  roll  batch
      |=  [[=jobe:nexus =ject:nexus] s=_silo]
      +:(~(put-ject si:nexus s) ject)
    =/  done=(set jobe:nexus)  (sy (turn batch |=([j=jobe:nexus *] j)))
    %=  $
      pending  (skip pending |=([j=jobe:nexus *] (~(has in done) j)))
    ==
  ~&  >  [%peek-data-received nouns=(lent good-nouns) jects=(lent good-jects)]
  =/  merged=lobes:nexus
    :-  (sy (turn good-jects |=([=jobe:nexus *] jobe)))
    (sy (turn good-nouns |=([=nobe:nexus *] nobe)))
  =.  this  discharge-peeks
  =.  silo  (release-snap-refs merged)
  =.  vale  (gc-vale-cache vale bins)
  this
::  snap-subset: the silo subset behind a ref set, served at refcount 0
::  (the receiver's merge assigns its own counts). A referenced lobe
::  missing from its store is a books error worth hearing about.
::
++  snap-subset
  |=  refs=lobes:nexus
  ^-  silo:nexus
  =/  acc=silo:nexus  *silo:nexus
  =.  acc
    %+  roll  ~(tap in jects.refs)
    |=  [=jobe:nexus a=_acc]
    =/  jot  (~(get by jects.silo) jobe)
    ?~  jot
      ~&  >>>  [%snap-subset-ject-absent jobe]
      a
    a(jects (~(put by jects.a) jobe [0 ject.u.jot]))
  %+  roll  ~(tap in nouns.refs)
  |=  [=nobe:nexus a=_acc]
  =/  got  (~(get by nouns.silo) nobe)
  ?~  got
    ~&  >>>  [%snap-subset-noun-absent nobe]
    a
  a(nouns (~(put by nouns.a) nobe [0 noun.u.got]))
::  Inline-snap thresholds: payloads under these ride inside the %snap
::  itself, skipping the want/data legs (see +process-peek).
::
++  max-inline-refs   64
++  max-inline-bytes  8.192
::  respond-transfer: poke the caller's grubbery back with a transfer, on
::  /[tag]/[caller-ship] — tag is the request kind (peek or want).
::
++  respond-transfer
  |=  [tag=@tas resp=transfer:remo:nexus]
  ^+  this
  =.  cards
    :_  cards
    :*  %pass  /[tag]/[(scot %p src.bowl)]
        %agent  [src.bowl %grubbery]  %poke  grubbery-transfer+!>(resp)
    ==
  this
::  +keep: register a remote watcher and send initial wave.
::  Called when a remote ship sends %keep load.
::
++  keep
  |=  [watcher=rail:tarball target=lane:tarball =wire]
  ^+  this
  =.  this  (sub-put target watcher wire ~)
  =/  =wave:nexus  (wave-at:nexus born target)
  =/  resp=intake:remo:nexus
    [wire target wave]
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
::  %snap: populate staged peeks, request missing lobes.
::  %data: merge silo, discharge fulfilled peeks.
::
++  process-transfer
  |=  [src=@p resp=transfer:remo:nexus]
  ^+  this
  ?-  +<.resp
      %snap
    ::  Solicitation check: only accept snaps we asked for
    =/  solicited=?
      %+  lien  ~(tap by peeks.remo)
      |=  [[* *] pk=peek:remo:nexus]
      &(=(ship.pk src) =(dest.pk dest.resp))
    ?.  solicited
      this
    ::  1. Populate snap on staged peeks matching this ship+dest.
    ::  2. Diff refs against silo and request missing lobes.
    ::  3. Discharge any peeks that can already be fulfilled.
    ::
    =/  matching=(list [[=rail:tarball =wire] =peek:remo:nexus])
      %+  skim  ~(tap by peeks.remo)
      |=  [[=rail:tarball =wire] pk=peek:remo:nexus]
      &(=(ship.pk src) =(dest.pk dest.resp))
    ?~  snap.resp
      ::  Nothing exists at dest — discharge with %none and remove peeks
      ~&  >  [%snap-not-found dest=dest.resp]
      =/  to-discharge=(list [[=rail:tarball =wire] =peek:remo:nexus])
        %+  skim  ~(tap by peeks.remo)
        |=  [[=rail:tarball =wire] pk=peek:remo:nexus]
        &(=(ship.pk src) =(dest.pk dest.resp))
      =.  this
        %+  roll  to-discharge
        |=  [[[=rail:tarball =wire] pk=peek:remo:nexus] sat=_this]
        =.  peeks.remo.sat  (~(del by peeks.remo.sat) [rail wire])
        (enqu-take:sat rail ~ ~ %peek wire [%none ~])
      this
    =.  peeks.remo
      %-  ~(run by peeks.remo)
      |=  pk=peek:remo:nexus
      ?.  &(=(ship.pk src) =(dest.pk dest.resp))
        pk
      pk(snap snap.resp, snap-id snap-id.resp)
    ::  Inline payload: the server sent the content with the snap.
    ::  Merge it through the same discipline as a %data transfer —
    ::  the want/data legs are skipped entirely.
    ?:  ?=(^ data.resp)
      ~&  >  [%snap-inline-from src]
      (merge-transfer-data u.data.resp)
    =/  missing=lobes:nexus
      :-  (~(dif in jects.refs.u.snap.resp) ~(key by jects.silo))
      (~(dif in nouns.refs.u.snap.resp) ~(key by nouns.silo))
    =/  n-missing=@ud  (add ~(wyt in jects.missing) ~(wyt in nouns.missing))
    ~&  >  [%snap-processed refs=(add ~(wyt in jects.refs.u.snap.resp) ~(wyt in nouns.refs.u.snap.resp)) missing=n-missing]
    ?:  =(0 n-missing)
      ::  All refs already in silo — discharge immediately
      ~&  >  %snap-all-refs-present-discharging
      discharge-peeks
    ::  Send %want with snap-id — server uses it to look up pinned refs
    ~&  >  [%snap-sending-want missing=n-missing snap-id=snap-id.resp]
    =/  want-req=transfer:remo:nexus
      [/want %want dest.resp snap-id.resp]
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
    ~&  >  [%data-received-from src]
    (merge-transfer-data silo.resp)
    ::
      %veto
    ::  Remote peek was blocked by weir. Discharge matching peeks.
    ::
    ~&  >>  [%veto-received-from src dest=dest.resp]
    =/  vetoed=(list [[=rail:tarball =wire] =peek:remo:nexus])
      %+  skim  ~(tap by peeks.remo)
      |=  [[=rail:tarball =wire] pk=peek:remo:nexus]
      &(=(ship.pk src) =(dest.pk dest.resp))
    %+  roll  vetoed
    |=  [[[=rail:tarball =wire] pk=peek:remo:nexus] sat=_this]
    =.  peeks.remo.sat  (~(del by peeks.remo.sat) [rail wire])
    (enqu-take:sat rail ~ ~ %peek wire [%veto ~])
    ::
      %miss
    ::  Remote snap expired before want arrived. Discharge affected
    ::  peeks as %miss so callers can retry.
    ::
    ~&  >>  [%miss-received-from src]
    =/  stale=(list [[=rail:tarball =wire] =peek:remo:nexus])
      %+  skim  ~(tap by peeks.remo)
      |=  [[* *] pk=peek:remo:nexus]
      =(ship.pk src)
    |-
    ?~  stale  this
    =/  [key=[=rail:tarball =wire] pk=peek:remo:nexus]  i.stale
    =.  this  (enqu-take rail.key ~ ~ %peek wire.key [%miss ~])
    =.  peeks.remo  (~(del by peeks.remo) key)
    $(stale t.stale)
    ::
      %pack
    ::  Routed to +process-pack in +take-remote-transfer; unreachable.
    this
  ==
::  Subscription wave from remote watcher. Translate dest back to
::  namespaced lane and deliver %news to local watchers.
::
++  process-intake
  |=  [src=@p resp=intake:remo:nexus]
  ^+  this
  ~&  >  [%wave-received-from src dest=dest.resp]
  =/  ns-lane=lane:tarball
    =/  prefix=path  /sys/ames/ships/[(scot %p src)]/root
    ?-(-.dest.resp %& [%& (weld prefix path.p.dest.resp) name.p.dest.resp], %| [%| (weld prefix p.dest.resp)])
  =/  watchers=subscribers:nexus  (fwd-get ns-lane)
  =.  this
    %-  ~(rep by watchers)
    |=  [[watcher=rail:tarball =wire blot=(unit blot:tarball)] acc=_this]
    ::  self-heal: a watcher whose grub no longer exists is a leaked
    ::  subscription; drop it instead of delivering
    ?~  (peek-grub-now watcher)
      (sub-del:acc ns-lane watcher)
    (enqu-take:acc watcher ~ ~ %news wire wave.resp)
  ::  nobody watches this lane anymore: unsubscribe from the source,
  ::  so cross-ship cleanup rides the delivery path the same way
  ::  local self-heal does
  ?.  =(~ (fwd-get ns-lane))  this
  =/  req=load:remo:nexus  [[wire.resp dest.resp] %drop ~]
  =.  cards
    :_  cards
    [%pass /drop/[(scot %p src)] %agent [src %grubbery] %poke grubbery-load+!>(req)]
  this
::  +abet: run the take queue dry, then return cards and state
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
  =/  entries=(list [key=cass:clay val=entry:hist:nexus])
    (tap:hon:hist:nexus sk)
  =/  kept=(list [key=cass:clay val=entry:hist:nexus])  ~
  |-
  ?~  entries
    =|  new-hist=hist:nexus
    =.  new-hist
      |-
      ?~  kept  new-hist
      $(kept t.kept, new-hist (put:hon:hist:nexus new-hist key.i.kept val.i.kept))
    =.  born  (~(put bo:nexus now.bowl born) here new-hist)
    =.  vale  (gc-vale-cache vale bins)
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
      =/  pv=pace:hist:nexus  pace.val.i.entries
      ?:  ?=(%tomb -.pv)  silo
      ?~  p.pv  silo
      (~(drop-ject si:nexus silo) u.p.pv)
    ::  if tombstoning the top, append a new [%temp ~] wavefront
    =/  new-kept  [[key.i.entries [[%tomb ~] ~]] kept]
    ?.  =(key.i.entries (need (top:hist:nexus sk)))
      $(entries t.entries, kept new-kept)
    =/  new-cass=cass:clay
      (~(next-cass bo:nexus now.bowl born) key.i.entries)
    $(entries t.entries, kept [[new-cass [[%temp ~] ~]] new-kept])
  $(entries t.entries, kept [i.entries kept])
::  Drop fold hist entries matching a lose spec: tombstone them and
::  clear their tags, decrementing silo refs (which frees the entry's
::  merkle tree if nothing else owns it). The live top entry is never
::  tombstoned — the current tree must survive — but a matched top is
::  DEMOTED: pace back to %temp, tags cleared, lobe and refs intact.
::  Metadata + silo only: the current pace lobe is untouched, so no
::  rollup — write the node back directly.
::
++  drop-fold-hist
  |=  [pax=path =lose:nexus]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) pax)
  ?~  node  this
  =/  sk=hist:nexus  fold.u.node
  =/  top=(unit cass:clay)  (top:hist:nexus sk)
  =/  entries=(list [key=cass:clay val=entry:hist:nexus])
    (tap:hon:hist:nexus sk)
  =/  kept=(list [key=cass:clay val=entry:hist:nexus])  ~
  |-
  ?~  entries
    =|  new-hist=hist:nexus
    =.  new-hist
      |-
      ?~  kept  new-hist
      $(kept t.kept, new-hist (put:hon:hist:nexus new-hist key.i.kept val.i.kept))
    =.  born  (~(put of born) pax u.node(fold new-hist))
    =.  vale  (gc-vale-cache vale bins)
    this
  =/  match=?
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
  ?.  match
    $(entries t.entries, kept [i.entries kept])
  ?:  =(`key.i.entries top)
    ::  matched top: demote to %temp and clear tags, keep the tree
    =/  pv=pace:hist:nexus  pace.val.i.entries
    =/  demoted=pace:hist:nexus
      ?:  ?=(%tomb -.pv)  pv
      [%temp p.pv]
    $(entries t.entries, kept [[key.i.entries [demoted ~]] kept])
  =.  silo
    =/  pv=pace:hist:nexus  pace.val.i.entries
    ?:  ?=(%tomb -.pv)  silo
    ?~  p.pv  silo
    (~(drop-ject si:nexus silo) u.p.pv)
  $(entries t.entries, kept [[key.i.entries [[%tomb ~] ~]] kept])
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
    =/  got=(unit [key=cass:clay val=entry:hist:nexus])
      (ram:hon:hist:nexus u.fh)
    ?~  got  this
    ?:  ?=(%tomb -.pace.val.u.got)  this
    ?~  p.pace.val.u.got  this
    =/  jot  (~(get by jects.silo) u.p.pace.val.u.got)
    ?~  jot  this
    ?.  ?=(%leaf -.ject.u.jot)  this
    ?:  =(gain.leaf.ject.u.jot flag)  this
    ::  Rewrite leaf ject with new gain flag
    =/  new-leaf=leaf:nexus  leaf.ject.u.jot(gain flag)
    =.  silo  (~(drop-ject si:nexus silo) u.p.pace.val.u.got)
    =/  [new-jobe=jobe:nexus new-silo=silo:nexus]
      (~(put-ject si:nexus silo) [%leaf new-leaf])
    =.  silo  new-silo
    ::  Update hist to point to new ject lobe
    =/  =pace:hist:nexus  ?:(flag [%firm `new-jobe] [%temp `new-jobe])
    =/  new-hist=hist:nexus
      (put-pace:hist:nexus u.fh key.u.got pace)
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
::  Promote current hist entry to %firm at a rail, with optional tags.
::
++  firm-hist
  |=  [here=rail:tarball tags=(set @t)]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.here)
  ?~  node  this
  =/  fh=(unit hist:nexus)  (~(get by file.u.node) name.here)
  ?~  fh  this
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus u.fh)
  ?~  got  this
  ?-    -.pace.val.u.got
      %tomb  this
      %firm
    ?:  =(tags tags.val.u.got)  this
    =/  new-hist=hist:nexus
      (put:hon:hist:nexus u.fh key.u.got val.u.got(tags (~(uni in tags.val.u.got) tags)))
    =.  born  (~(put bo:nexus now.bowl born) here new-hist)
    this
      %temp
    =/  new-hist=hist:nexus
      (put:hon:hist:nexus u.fh key.u.got [[%firm p.pace.val.u.got] tags])
    =.  born  (~(put bo:nexus now.bowl born) here new-hist)
    this
  ==
::  Promote current fold hist entry to %firm at a path.
::  Metadata-only: the pace lobe is untouched, so no rollup or
::  silo changes — write the node back directly.
::
++  firm-fold
  |=  [pax=path tags=(set @t)]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) pax)
  ?~  node  this
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  this
  ?-    -.pace.val.u.got
      %tomb  this
      %firm
    ?:  =(tags tags.val.u.got)  this
    =/  new-hist=hist:nexus
      (put:hon:hist:nexus fold.u.node key.u.got val.u.got(tags (~(uni in tags.val.u.got) tags)))
    =.  born  (~(put of born) pax u.node(fold new-hist))
    this
      %temp
    =/  new-hist=hist:nexus
      (put:hon:hist:nexus fold.u.node key.u.got [[%firm p.pace.val.u.got] tags])
    =.  born  (~(put of born) pax u.node(fold new-hist))
    this
  ==
::  Set tags on a fold hist entry at a path.
::
++  tag-fold
  |=  [pax=path cas=(unit case:nexus) tags=(set @t)]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) pax)
  ?~  node  this
  =/  target=(unit cass:clay)
    ?~  cas  (top:hist:nexus fold.u.node)
    =/  cp  (resolve-case:nexus u.cas fold.u.node)
    ?~(cp ~ `cass.u.cp)
  ?~  target  this
  =/  new-hist=hist:nexus  (tag:hist:nexus fold.u.node u.target tags)
  =.  born  (~(put of born) pax u.node(fold new-hist))
  this
::  Set tags on the current hist entry at a rail.
::
++  tag-hist
  |=  [here=rail:tarball cas=(unit case:nexus) tags=(set @t)]
  ^+  this
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.here)
  ?~  node  this
  =/  fh=(unit hist:nexus)  (~(get by file.u.node) name.here)
  ?~  fh  this
  =/  target=(unit cass:clay)
    ?~  cas  (top:hist:nexus u.fh)
    =/  cp  (resolve-case:nexus u.cas u.fh)
    ?~(cp ~ `cass.u.cp)
  ?~  target  this
  =/  new-hist=hist:nexus  (tag:hist:nexus u.fh u.target tags)
  =.  born  (~(put bo:nexus now.bowl born) here new-hist)
  this
::  Find all [rail cass] pairs in a subtree whose hist contains a lobe
::
++  seek-lobe
  |=  [=lane:tarball target=nobe:nexus]
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
  |=  [base=path nodes=(list [pax=path fold=hist:nexus file=(map @ta hist:nexus)]) target=nobe:nexus]
  ^-  (list [=rail:tarball =cass:clay])
  ?~  nodes  ~
  =/  files=(list [@ta hist:nexus])  ~(tap by file.i.nodes)
  =/  hits=(list [=rail:tarball =cass:clay])
    (seek-files base pax.i.nodes files target)
  (weld hits $(nodes t.nodes))
::
++  seek-files
  |=  [base=path pax=path files=(list [@ta hist:nexus]) target=nobe:nexus]
  ^-  (list [=rail:tarball =cass:clay])
  ?~  files  ~
  =/  hits=(list [=rail:tarball =cass:clay])
    (match-hist [(weld base pax) -.i.files] +.i.files target)
  (weld hits $(files t.files))
::
::  match-hist: find hist entries whose leaf ject contains target noun-lobe
++  match-hist
  |=  [here=rail:tarball =hist:nexus target=nobe:nexus]
  ^-  (list [=rail:tarball =cass:clay])
  %+  murn  (tap:hon:hist:nexus hist)
  |=  [key=cass:clay val=entry:hist:nexus]
  ?:  ?=(%tomb -.pace.val)  ~
  ?~  p.pace.val  ~
  =/  jot  (~(get by jects.silo) u.p.pace.val)
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
  |=  [here=rail:tarball give=(unit give:nexus) in=(unit pend:fiber:nexus)]
  this(takes (~(put to takes) [here give in]))
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
::  +resolve-built: find a compiled artifact by walking ancestor namespaces
::
::  Unlike seek-built (which only checks the governing namespace),
::  resolve-built walks up through all ancestor code namespaces until
::  it finds the artifact. This is the gradated fallback: a mark or
::  nexus defined in /code is available to all namespaces, but a
::  closer ancestor can shadow it.
::
++  resolve-built
  |=  [pax=path =path name=@ta]
  ^-  (unit [namespace=fold:tarball source=rail:tarball ckey=@uv =built:nexus])
  |-
  =/  cod=^path
    ?~  pax  /code
    (snoc (snip `(list @ta)`pax) %code)
  =/  ns  (~(get by code) cod)
  ?^  ns
    =/  lod=lode:nexus  u.ns
    =/  node=(unit (map @ta @uv))
      (~(get of refs.lod) path)
    =/  ckey=(unit @uv)
      ?~(node ~ (~(get by u.node) name))
    ?^  ckey
      =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) u.ckey)
      ?~  entry  ~
      `[cod [path name] u.ckey built.u.entry]
    ?~  pax  ~
    $(pax (snip `(list @ta)`pax))
  ?~  pax  ~
  $(pax (snip `(list @ta)`pax))
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
::  +get-marc: find a compiled marc via ancestor resolution
::
++  get-marc
  |=  [pax=path =blot:tarball]
  ^-  marc:tarball
  =/  res=(unit [namespace=fold:tarball source=rail:tarball ckey=@uv =built:nexus])
    (resolve-built pax (weld /mar path.blot) name.blot)
  ?~  res
    =/  nam=@tas  (rail-to-arm:tarball blot)
    ~&  >>>  "get-marc: %{(trip nam)} not found from {(spud pax)}"
    ~|([%marc-not-found nam pax] !!)
  ?.  ?=(%vase -.built.u.res)
    =/  nam=@tas  (rail-to-arm:tarball blot)
    ~&  >>>  "get-marc: %{(trip nam)} failed (tang) from {(spud pax)}"
    ~|([%marc-failed nam pax] !!)
  !<(marc:tarball vase.built.u.res)
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
  |=  [lob=nobe:nexus ckey=@uv]
  ^-  (unit (unit tang))
  (~(get by vale) [lob ckey])
::  Vale cache write: store validation result
::
++  vale-put
  |=  [lob=nobe:nexus ckey=@uv res=(unit tang)]
  ^+  this
  this(vale (~(put by vale) [lob ckey] res))
::  Check vale cache for a prior validation result.
::  Returns ~ on miss, [~ (each vase tang)] on hit.
::  On cached success, reconstructs vase from marc type + noun.
::
++  check-vale-cache
  |=  [pax=path =blot:tarball noun=*]
  ^-  (unit (each vase tang))
  =/  built-res  (resolve-built pax (weld /mar path.blot) name.blot)
  ?~  built-res  ~
  =/  lob=nobe:nexus  (sham noun)
  =/  hit  (vale-hit lob ckey.u.built-res)
  ?~  hit  ~
  ?^  u.hit  `|+u.u.hit
  ?.  ?=(%vase -.built.u.built-res)  ~
  =/  marc-res=(each marc:tarball tang)
    (mule |.(!<(marc:tarball vase.built.u.built-res)))
  ?.  ?=(%& -.marc-res)  ~
  `&+[type:p.marc-res noun]
::
++  cache-validation
  |=  [pax=path =blot:tarball noun=* res=(each * tang)]
  ^+  this
  =/  lob=nobe:nexus  (sham noun)
  ::  Only cache silo-resident nouns. One-shot payloads (pokes, http
  ::  bodies) sham to a key that can never recur, so caching them
  ::  only grows the map. Recorded grubs get their entry from +record.
  ?.  (~(has by nouns.silo) lob)  this
  =/  built-res  (resolve-built pax (weld /mar path.blot) name.blot)
  ?~  built-res  this
  (vale-put lob ckey.u.built-res ?:(?=(%& -.res) ~ `p.res))
::  Validate a noun against its mark, using the cache if possible.
::  Caches the result on miss. Returns validated vase or error tang.
::
++  validate-cached
  |=  [pax=path =blot:tarball noun=*]
  ^-  [(each vase tang) _this]
  =/  cached  (check-vale-cache pax blot noun)
  ?^  cached  [u.cached this]
  =/  res=(each vase tang)  (validate-noun pax blot noun)
  [res (cache-validation pax blot noun res)]
::
++  get-tube
  |=  [pax=path =bars:tarball]
  ^-  tube:clay
  =/  via-grow=(each tube:clay tang)
    (mule |.((grow:(get-marc pax a.bars) b.bars)))
  ?:  ?=(%& -.via-grow)  p.via-grow
  (grab:(get-marc pax b.bars) a.bars)
::  Validate file content via compiled marc
::
++  validate-noun
  |=  [pax=path =blot:tarball noun=*]
  ^-  (each vase tang)
  =/  res  (resolve-built pax (weld /mar path.blot) name.blot)
  ?^  res
    ?.  ?=(%vase -.built.u.res)
      =/  nam=@tas  (rail-to-arm:tarball blot)
      |+~[leaf+"validate-noun: marc for %{(trip nam)} failed at {(spud pax)}"]
    =/  nam=@tas  (rail-to-arm:tarball blot)
    =/  marc-res=(each marc:tarball tang)
      ~|  [%validate-noun %marc-extract-failed nam pax]
      (mule |.(!<(marc:tarball vase.built.u.res)))
    ?:  ?=(%| -.marc-res)
      |+[leaf+"validate-noun: marc for %{(trip nam)} broke at {(spud pax)}" p.marc-res]
    ::  computing the marc's arms runs +build-vale's slap against the
    ::  stored artifact. For some artifacts that slap crashes (-find),
    ::  and an unguarded crash here kills the whole event. Trap both
    ::  arm computations so a bad artifact reads as a validation error
    ::  carrying the real trace instead.
    =/  vale-gate=(each $-(* vase) tang)
      (mule |.(vale:p.marc-res))
    ?:  ?=(%| -.vale-gate)
      |+[leaf+"validate-noun: vale build for %{(trip nam)} crashed at {(spud pax)}" p.vale-gate]
    =/  val-res=(each vase tang)
      (validate-vase p.vale-gate noun)
    ?:  ?=(%| -.val-res)  val-res
    =/  typ=(each type tang)
      (mule |.(type:p.marc-res))
    ?:  ?=(%| -.typ)
      |+[leaf+"validate-noun: type build for %{(trip nam)} crashed at {(spud pax)}" p.typ]
    &+[p.typ noun]
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
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus u.fh)
  ?~  got  %.n
  ?:  ?=(%tomb -.pace.val.u.got)  %.n
  ?~  p.pace.val.u.got  %.n
  =/  jot  (~(get by jects.silo) u.p.pace.val.u.got)
  ?~  jot  %.n
  ?.  ?=(%leaf -.ject.u.jot)  %.n
  gain.leaf.ject.u.jot
::  Peek a single file by ject-lobe.  Looks up the leaf ject in silo,
::  fetches the raw noun, validates via vale cache, returns sang.
::
++  peek-grub
  |=  =jobe:nexus
  ^-  (unit sang:tarball)
  =/  jot  (~(get by jects.silo) jobe)
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
  |=  =jobe:nexus
  ^-  ball:tarball
  =/  jot  (~(get by jects.silo) jobe)
  ?~  jot  *ball:tarball
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%tree -.jt)  *ball:tarball
  =/  nek=(unit neck:tarball)
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  =/  contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    %-  ~(gas by *(map @ta [=sang:tarball gain=? bang=(unit tang)]))
    %+  murn  ~(tap by fil.tree.jt)
    |=  [name=@ta =jobe:nexus]
    ^-  (unit [@ta [=sang:tarball gain=? bang=(unit tang)]])
    =/  got  (peek-grub jobe)
    ?~  got  ~
    =/  leaf-jot  (~(get by jects.silo) jobe)
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
    |=  [name=@ta =jobe:nexus weir=(unit weir:tarball)]
    ^-  [@ta ball:tarball]
    =/  child=ball:tarball  (peek-ball jobe)
    =/  child-fil=lump:tarball  (fall fil.child [~ ~ %.n ~ ~])
    [name child(fil `child-fil(weir weir))]
  [`lump sub-dirs]
::  Peek bole: raw nouns, no vase construction or bang resolution.
::
++  peek-bole
  |=  =jobe:nexus
  ^-  bole:tarball
  =/  jot  (~(get by jects.silo) jobe)
  ?~  jot  *bole:tarball
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%tree -.jt)  *bole:tarball
  =/  nek=(unit neck:tarball)
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  =/  contents=(map @ta [=bask:tarball gain=?])
    %-  ~(gas by *(map @ta [=bask:tarball gain=?]))
    %+  murn  ~(tap by fil.tree.jt)
    |=  [name=@ta =jobe:nexus]
    ^-  (unit [@ta [=bask:tarball gain=?]])
    =/  leaf-jot  (~(get by jects.silo) jobe)
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
    |=  [name=@ta =jobe:nexus weir=(unit weir:tarball)]
    ^-  [@ta bole:tarball]
    [name (peek-bole jobe)]
  [`pulp sub-dirs]
::
++  peek-bole-now
  |=  =fold:tarball
  ^-  bole:tarball
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  *bole:tarball
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  *bole:tarball
  =/  =pace:hist:nexus  pace.val.u.got
  ?:  ?=(%tomb -.pace)  *bole:tarball
  ?~  p.pace  *bole:tarball
  (peek-bole u.p.pace)
::  Shallow peek: resolve files at this level, subdirs as empty balls.
::  No recursion — O(files at this level) instead of O(all files).
::
++  peek-ball-shallow
  |=  =jobe:nexus
  ^-  ball:tarball
  =/  jot  (~(get by jects.silo) jobe)
  ?~  jot  *ball:tarball
  =/  jt=ject:nexus  ject.u.jot
  ?.  ?=(%tree -.jt)  *ball:tarball
  =/  nek=(unit neck:tarball)
    (bind nek.tree.jt |=([=neck:tarball *] neck))
  =/  contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    %-  ~(gas by *(map @ta [=sang:tarball gain=? bang=(unit tang)]))
    %+  murn  ~(tap by fil.tree.jt)
    |=  [name=@ta =jobe:nexus]
    ^-  (unit [@ta [=sang:tarball gain=? bang=(unit tang)]])
    =/  got  (peek-grub jobe)
    ?~  got  ~
    =/  leaf-jot  (~(get by jects.silo) jobe)
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
  ::  Preserve parent-owned weir on children (content left empty for shallow)
  =/  sub-dirs=(map @ta ball:tarball)
    %-  ~(gas by *(map @ta ball:tarball))
    %+  turn  ~(tap by dir.tree.jt)
    |=  [name=@ta =jobe:nexus weir=(unit weir:tarball)]
    ^-  [@ta ball:tarball]
    [name [`[~ weir %.n ~ ~] ~]]
  [`lump sub-dirs]
::  Peek the current sang at a rail (born lookup + peek-grub).
::
::  +grub-lives: does a grub currently exist — the hist walk from
::  +peek-grub-now without the silo fetch, for existence gates on
::  hot paths
::
++  grub-lives
  |=  =rail:tarball
  ^-  ?
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.rail)
  ?~  node  %.n
  =/  sok=(unit hist:nexus)  (~(get by file.u.node) name.rail)
  ?~  sok  %.n
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus u.sok)
  ?~  got  %.n
  =/  =pace:hist:nexus  pace.val.u.got
  ?:  ?=(%tomb -.pace)  %.n
  ?=(^ p.pace)
::
++  peek-grub-now
  |=  =rail:tarball
  ^-  (unit sang:tarball)
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) path.rail)
  ?~  node  ~
  =/  sok=(unit hist:nexus)  (~(get by file.u.node) name.rail)
  ?~  sok  ~
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus u.sok)
  ?~  got  ~
  =/  =pace:hist:nexus  pace.val.u.got
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
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  *ball:tarball
  =/  =pace:hist:nexus  pace.val.u.got
  ?:  ?=(%tomb -.pace)  *ball:tarball
  ?~  p.pace  *ball:tarball
  (peek-ball u.p.pace)
::  Look up a directory's weir from its parent's tree ject.
::
++  get-weir-for
  |=  =fold:tarball
  ^-  (unit weir:tarball)
  ?~  fold  ~
  =/  parent=fold:tarball  (snip `path`fold)
  =/  name=@ta  (rear fold)
  =/  parent-node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) parent)
  ?~  parent-node  ~
  =/  parent-got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus fold.u.parent-node)
  ?~  parent-got  ~
  =/  =pace:hist:nexus  pace.val.u.parent-got
  ?:  ?=(%tomb -.pace)  ~
  ?~  p.pace  ~
  =/  jot  (~(get by jects.silo) u.p.pace)
  ?~  jot  ~
  ?.  ?=(%tree -.ject.u.jot)  ~
  =/  entry  (~(get by dir.tree.ject.u.jot) name)
  ?~  entry  ~
  weir.u.entry
::  get-neck-for: the neck of the nexus rooted at fold, read straight from its
::  tree ject in born/silo — no subtree materialization (the get-weir-for
::  pattern). ~ if there's no node, no live pace, or it isn't a directory tree.
::
++  get-neck-for
  |=  =fold:tarball
  ^-  (unit neck:tarball)
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  ~
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  ~
  =/  =pace:hist:nexus  pace.val.u.got
  ?:  ?=(%tomb -.pace)  ~
  ?~  p.pace  ~
  =/  jot  (~(get by jects.silo) u.p.pace)
  ?~  jot  ~
  ?.  ?=(%tree -.ject.u.jot)  ~
  (bind nek.tree.ject.u.jot |=([=neck:tarball *] neck))
::  Shallow peek: files at fold + subdir names, no recursion.
::
++  peek-ball-shallow-now
  |=  =fold:tarball
  ^-  ball:tarball
  =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
    (~(get of born) fold)
  ?~  node  *ball:tarball
  =/  got=(unit [key=cass:clay val=entry:hist:nexus])
    (ram:hon:hist:nexus fold.u.node)
  ?~  got  *ball:tarball
  =/  =pace:hist:nexus  pace.val.u.got
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
    ~|  [%validate-ball name (weld cod here) p.sang]
    =^  res=(each vase tang)  this
      (validate-cached cod p.sang noun)
    ?.  ?=(%& -.res)
      ~&  >>  "validate-ball: vale via mark %{(trip name.p.sang)} crashed for file '{(trip name)}' cod={<cod>} here={<here>}"
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
::  +bang-pool: prepare pool for persistence
::
::  Bangs processes to crash tangs (gates can't survive reload).
::  If latest=%.n, also clears skip/next queues — queues hold pend
::  values which reference dart/load via %veto, and load changes
::  across versions. Clearing queues avoids nesting failures on load.
::
::  WARNING: clearing queues loses queued inputs. Post-release, fix
::  %veto to not carry =dart (root cause of pend referencing load).
::
::  bang-pool: neutralize every running process in the pool, replacing its
::  live continuation with a %| "rebuild me" marker so on-load re-spawns it
::  from current source (a continuation can't survive a code change). `latest`:
::  %.y keeps each process's pending take-queues (in-flight work survives the
::  reload); %.n clears them too.
++  bang-pool
  |=  [=pool:nexus latest=?]
  ^-  pool:nexus
  =/  new-fil=(unit pipe:nexus)
    ?~  fil.pool  ~
    =/  =pipe:nexus  u.fil.pool
    :-  ~
    %=  pipe
      proc  %-  ~(run by proc.pipe)
             |=  =proc:fiber:nexus
             ?:  latest
               ?:  ?=(%| -.process.proc)  proc
               proc(process |+~[leaf+"saving for reload"])
             ?:  ?=(%| -.process.proc)
               proc(next ~, skip ~)
             proc(process |+~[leaf+"saving for reload"], next ~, skip ~)
    ==
  =/  new-dir=(map @ta pool:nexus)
    (~(run by dir.pool) |=(p=pool:nexus (bang-pool p latest)))
  [new-fil new-dir]
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
  =/  pv=(unit pace:hist:nexus)  (get-pace:hist:nexus u.sok u.cas)
  ?~  pv  this
  ?:  ?=(%tomb -.u.pv)  this
  ?~  p.u.pv  this
  =/  [new-jobe=jobe:nexus new-silo=silo:nexus]
    (~(set-bang si:nexus silo) u.p.u.pv err)
  =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.cas)
  =/  new-sok=hist:nexus
    (put-pace:hist:nexus u.sok new-cass [%temp `new-jobe])
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
  =/  pv=(unit pace:hist:nexus)  (get-pace:hist:nexus fold.u.node u.cas)
  ?~  pv  this
  ?:  ?=(%tomb -.u.pv)  this
  ?~  p.u.pv  this
  =/  [new-jobe=jobe:nexus new-silo=silo:nexus]
    (~(set-bang si:nexus silo) u.p.u.pv err)
  =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.cas)
  =/  new-fold=hist:nexus
    (put-pace:hist:nexus fold.u.node new-cass [%temp `new-jobe])
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
    =/  pv=(unit pace:hist:nexus)  (get-pace:hist:nexus fold.u.fil.bor u.fold-cas)
    ?~  pv  this
    ?:  ?=(%tomb -.u.pv)  this
    ?~  p.u.pv  this
    =/  cleared  (~(clear-bang si:nexus silo) u.p.u.pv)
    ?~  cleared  this
    =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.fold-cas)
    =/  new-fold=hist:nexus
      (put-pace:hist:nexus fold.u.fil.bor new-cass [%temp `lobe.u.cleared])
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
    =/  pv=(unit pace:hist:nexus)  (get-pace:hist:nexus sok u.cas)
    ?~  pv  $(files t.files)
    ?:  ?=(%tomb -.u.pv)  $(files t.files)
    ?~  p.u.pv  $(files t.files)
    =/  cleared  (~(clear-bang si:nexus silo) u.p.u.pv)
    ?~  cleared  $(files t.files)
    =/  here=rail:tarball  [pax name]
    =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) u.cas)
    =/  new-sok=hist:nexus
      (put-pace:hist:nexus sok new-cass [%temp `lobe.u.cleared])
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
  ::  Tomb previous %temp entry, then append [%temp ~ ~] for deletion
  =/  sok=(unit hist:nexus)  (get-born [dir name])
  =.  this
    ?.  ?=(^ sok)  this
    =/  file-cass=cass:clay  (need (top:hist:nexus u.sok))
    ::  Capture the leaf being tombed so its vale entry can follow it
    =/  prev-leaf=(unit leaf:nexus)  (hist-leaf u.sok file-cass)
    =/  [tombed-silo=silo:nexus tombed-hist=hist:nexus]
      (~(tomb-temp si:nexus silo) u.sok file-cass)
    =/  new-cass=cass:clay  (~(next-cass bo:nexus now.bowl born) file-cass)
    =/  new-sok=hist:nexus  (put-pace:hist:nexus tombed-hist new-cass [%temp ~])
    =.  silo  tombed-silo
    =.  born  (~(put bo:nexus now.bowl born) [dir name] new-sok)
    =.  vale  (gc-vale-prev prev-leaf)
    this
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
  =.  this  (build-code u.cod `(sy `(list rail:tarball)`~[[dir name]]))
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
  =/  err=(unit tang)
    ?.  ?=([~ %|] (allowed %peek from `[%& here]))
      err
    ?~(err ~ `~[leaf+"poke failed"])
  (enqu-take from ~ ~ %pack wire err)
::
++  give-poke-sign
  |=  [here=rail:tarball =took:eval]
  ^+  this
  ?.  ?=([~ %poke *] in.take.took)  this
  ?~  give.take.took  this
  (give-poke-ack here from.u.give.take.took wire.u.give.take.took err.took)
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
  =.  this  (drop-pend-refs in.take)
  =.  this  (give-poke-sign here [take `err])
  $(takes takes)
::  Drop silo refs held by lobes in a pend
::
++  drop-pend-refs
  |=  in=(unit pend:fiber:nexus)
  ^+  this
  ?~  in  this
  ?+  -.u.in  this
      %peek
    ?+  -.cite.u.in  this
      %file  this(silo (~(drop-ject si:nexus silo) lobe.cite.u.in))
      %ball  this(silo (~(drop-ject si:nexus silo) lobe.cite.u.in))
    ==
      %peep
    ?.  ?=(%& -.res.u.in)  this
    =-  this(silo -)
    %+  roll  p.res.u.in
    |=  [[* =jobe:nexus] acc=_silo]
    (~(drop-ject si:nexus acc) jobe)
  ==
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
  ::  A reload can drop subdirs that carried code necks (deregister)
  ::  or create new ones (register) — reconcile both ways.
  =.  this  purge-stale-code
  =.  this  (build-new-code-namespaces dest (peek-bole-now dest))
  (spawn-all-files dest (peek-bole-now dest))
::  Run on-load for a nexus at dest and apply results
::
::  Reload a nexus: run on-load, write ball, recurse into child nexuses.
::  Does NOT spawn processes — callers spawn after the full tree is settled.
::
++  reload-nexus-at
  |=  [dest=fold:tarball nex=nexus:nexus]
  ^+  this
  =/  old-sub  (peek-ball-now dest)
  =/  sub-ball=ball:tarball  old-sub
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
    (bang-nexus dest p.load-res)
  =/  upd-bole=bole:tarball  p.load-res
  ::  Enforce parent weir and parent neck on bole
  =/  restored-pulp=pulp:tarball  (fall fil.upd-bole *pulp:tarball)
  =.  upd-bole
    upd-bole(fil `restored-pulp(neck parent-neck, weir parent-weir))
  ::  Put results back — load-ball-changes writes bole and does bookkeeping
  =.  this  (load-ball-changes dest upd-bole)
  =.  this  (bump-weir-changes dest (ball-to-bole:tarball old-sub) upd-bole)
  =.  this  (audit-weir dest)
  =.  this  (reload-child-nexuses dest)
  ::  Propagate tree ject changes upward to root after child nexuses reload.
  =.  this  (record-trees dest)
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
::  +spawn-all-files: spawn a process for every file in a bole
::
::    Walks the bole recursively. At each directory carrying a neck
::    the governing nexus is built once and passed down as the scope;
::    each file gets its spool from the scope nexus and is spawned.
::    Files at levels with no governing nexus are skipped.
::
++  spawn-all-files
  |=  [here=fold:tarball new=bole:tarball]
  ^+  this
  (spawn-all-files-in here new ~)
::  +spawn-all-files-in: the recursive worker for +spawn-all-files
::
++  spawn-all-files-in
  |=  $:  here=fold:tarball
          new=bole:tarball
          scope=(unit [nex-path=path nex=nexus:nexus])
      ==
  ^+  this
  ::  If this level has a neck, build nexus once (overrides parent scope).
  ::  A failed build bangs the whole subtree and spawns nothing under it —
  ::  same as the reload path. The [/ %code] sentinel is not a nexus,
  ::  it marks a code namespace — no neck as far as spawning goes.
  =/  built=(unit (each nexus:nexus tang))
    ?~  fil.new  ~
    ?~  neck.u.fil.new  ~
    ?:  =([/ %code] u.neck.u.fil.new)  ~
    `(build-nexus here u.neck.u.fil.new)
  ?:  ?=([~ %| *] built)
    (bang-nexus here p.u.built)
  =/  nex-scope=(unit [nex-path=path nex=nexus:nexus])
    ?~  built  scope
    `[here p.u.built]
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
    =.  this  (spawn-proc-with file-rail ~ spool-res)
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
  ::  If the upki file changed, give udiffs to gall subscribers
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
  =/  =wave:nexus  (wave-at:nexus born target)
  ::  Send wavefront to each watcher
  =.  this
    %-  ~(rep by watchers)
    |=  [[watcher=rail:tarball =wire blot=(unit blot:tarball)] acc=_this]
    ::  the registry watches its registrants; it has no fiber, so its
    ::  news is handled synchronously
    ?:  =([/sys/ames %'registry'] watcher)
      (registry-news:acc target)
    ::  self-heal: a watcher whose grub no longer exists is a leaked
    ::  subscription; drop it instead of delivering
    ?~  (peek-grub-now watcher)
      (sub-del:acc target watcher)
    ::  agent watcher (thin surface): a ship.sig watcher whose wire
    ::  is a client channel gets a %news fact instead of a grubbery-
    ::  intake poke — gall fans it to the channel's subscribers,
    ::  local or cross-ship
    ?:  ?&  ?=([%sys %ames %ships @ *] path.watcher)
            ?=([%client @ *] wire)
        ==
      =/  id=@ta  i.t.wire
      =/  news=[=path name=(unit @ta)]
        ?-  -.target
          %&  [path.p.target `name.p.target]
          %|  [p.target ~]
        ==
      (give-client-fact:acc id [%news news])
    ::  Remote watcher: poke wave to subscriber ship
    ?:  ?=([%sys %ames %ships @ *] path.watcher)
      =/  dest=@p  (slav %p i.t.t.t.path.watcher)
      =/  resp=intake:remo:nexus
        [wire target wave]
      =.  cards.acc
        :_  cards.acc
        [%pass /wave/[(scot %p dest)] %agent [dest %grubbery] %poke grubbery-intake+!>(resp)]
      acc
    ::  Local watcher: deliver directly
    (enqu-take:acc watcher ~ ~ %news wire wave)
  $(watched t.watched)
::  Handle jael on-watch: give initial udiffs on subscription.
::  path=~ gives all udiffs, path=[@ ~] filters per ship.
::
++  serve-jael
  |=  =path
  ^+  this
  =/  js  upki
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
::  If the upki rail changed, give %azimuth-udiffs to gall subs.
::  Sends on / (all udiffs) and on /(scot %p ship) (filtered per ship).
::
++  maybe-give-jael
  |=  changed=(set lane:tarball)
  ^+  this
  =/  js  upki
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
  (enqu-take watcher ~ ~ %fell wire.val)
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
::  +build-nexus: compile a nexus via ancestor resolution
::
++  build-nexus
  |=  [pax=path =neck:tarball]
  ^-  (each nexus:nexus tang)
  ?:  =([/ %root] neck)  &+root
  =/  res  (resolve-built pax (weld /nex path.neck) name.neck)
  ?~  res  |+~[leaf+"build-nexus: no built nexus %{(trip (rail-to-arm:tarball [path.neck name.neck]))} at {(spud (weld /nex path.neck))} (from {(spud pax)})"]
  ?+  -.built.u.res
    |+~[leaf+"build-nexus: unexpected artifact type {<-.built.u.res>}"]
    %tang  |+tang.built.u.res
    %vase
  =/  nex=(unit nexus:nexus)
    (mole |.(!<(nexus:nexus vase.built.u.res)))
  ?~  nex  |+~[leaf+"build-nexus: failed to extract nexus from vase"]
  &+u.nex
  ==
::
++  find-nearest-nexus
  |=  here=rail:tarball
  ^-  (unit (pair path neck:tarball))
  =/  here-path=path  (snoc path.here name.here)
  |-
  ::  walk up, reading each level's neck directly from born/silo (no ball
  ::  materialization); return the nearest ancestor that carries one.
  =/  nek=(unit neck:tarball)  (get-neck-for here-path)
  ?^  nek  `[here-path u.nek]
  ?~  here-path  ~
  $(here-path (snip `path`here-path))
::
::
++  build-spool
  |=  here=rail:tarball
  ^-  (each (unit spool:fiber:nexus) tang)
  ::  Get the file from the ball - must exist
  =/  file-data  (peek-grub-now path.here name.here)
  ?~  file-data  &+~
  ::  Extract blot from the sage
  =/  =blot:tarball  p.u.file-data
  ::  Find the nearest parent nexus. The [/ %code] sentinel marks a
  ::  code namespace, not a nexus — absence, not failure.
  =/  nex-info  (find-nearest-nexus here)
  ?~  nex-info  &+~
  ?:  =([/ %code] q.u.nex-info)  &+~
  ::  Build the nexus from the neck.
  ::  A build failure is an answer, not an absence — surface the tang
  ::  so callers bang the file instead of silently spawning default-spool.
  =/  nex-res=(each nexus:nexus tang)
    (build-nexus path.here q.u.nex-info)
  ?:  ?=(%| -.nex-res)  nex-res
  ::  Call on-file with rail relative to nexus location
  =/  rel=rail:tarball  (relativize-rail:tarball p.u.nex-info here)
  &+`(on-file:p.nex-res rel blot)
::
++  process-dart
  |=  [here=rail:tarball =dart:nexus]
  ^+  this
  ::  %here does its own permission checks — skip weir pre-check
  ?:  ?=(%here -.dart)
    (handle-dart here dart ~ ~)
  =/  [=jump:nexus dest=(unit lane:tarball)]  (dart-to-dest here dart)
  ::  %node dart with an unresolvable road — drop at admission.
  ::  Past this point a %node dart always carries a resolved dest.
  ?:  &(?=(%node -.dart) ?=(~ dest))
    ~&  [%node-bad-road here road.dart]
    this
  =/  =filt:nexus  (allowed jump here dest)
  ?+    filt  (handle-dart here dart filt dest)
      [~ %|]
    ::  Vetoed — crash for foreign ship darts (gall nacks the sender),
    ::  send %veto intake back to source for internal darts.
    ~&  >>>  [%process-dart-vetoed jump=jump here=here dest=dest filt=filt dart-type=-.dart]
    ?:  ?=([%sys %ames %ships @ ~] path.here)
      ~|  [%peer-vetoed name.here dest]
      !!
    (enqu-take here ~ ~ %veto dart)
    ::
      [~ %&]
    ::  Weir boundary allowed — validation happens in handler for all dart types.
    ::  Peek results are validated inside handle-dart (data flows back).
    (handle-dart here dart filt dest)
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
      ?(%peek %keep %drop %seek %peep %code %font %born)  %peek  :: read operations
      %poke                       %poke
        $?  %make  %cull  %sand  %load
            %lose  %gain  %firm  %tag
        ==
      %make  :: all modify tree structure
    ==
  ==
::
::  +resolve-remote: check if a lane is under /sys/ames/ships/ and
::  extract the target ship and real (non-ames) dest lane.
::
++  resolve-remote
  |=  =lane:tarball
  ^-  (unit [@p lane:tarball])
  =/  pax=path
    ?-(-.lane %& path.p.lane, %| p.lane)
  ?.  ?=([%sys %ames %ships @ %root *] pax)
    ~
  =/  target=@p  (slav %p i.t.t.t.pax)
  =/  real-path=path  t.t.t.t.t.pax
  :-  ~  :-  target
  ?-(-.lane %& [%& real-path name.p.lane], %| [%| real-path])
::
++  handle-dart
  |=  $:  here=rail:tarball
          =dart:nexus
          =filt:nexus
          dest=(unit lane:tarball)
      ==
  ^+  this
  =/  cod=path  path.here
  ?-    -.dart
      %node
    ::  Send load to another path. Road was resolved in process-dart;
    ::  bad roads are dropped there, so %node always has a dest.
    ?>  ?=(^ dest)
    =*  dest-lane  dest
    ?-    -.load.dart
        %poke
      ?>  ?=(^ dest-lane)
      (dart-poke here dart u.dest-lane)
      ::
        %make
      ::  Create file or directory.
      ::  If mark is set on a file make, convert the content via
      ::  cached tube before storing.
      =/  mak=make:nexus  make.load.dart
      =/  res=(each _this tang)
        (mule |.((make path.here u.dest-lane force.load.dart gain.load.dart mak)))
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %made wire.dart ~)
          %|
        ?:  =(/sys (scag 1 path.here))
          (mean p.res)
        (enqu-take here ~ ~ %made wire.dart `p.res)
      ==
      ::
        %cull
      ::  Delete file or directory at dest
      =/  res=(each _this tang)  (mule |.((cull u.dest-lane)))
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %gone wire.dart ~)
          %|
        ?:  =(/sys (scag 1 path.here))
          (mean p.res)
        (enqu-take here ~ ~ %gone wire.dart `p.res)
      ==
      ::
        %sand
      ::  Set weir at dest (must be a directory)
      ?>  ?=(%| -.u.dest-lane)
      =/  dest=fold:tarball  p.u.dest-lane
      =/  res=(each _this tang)  (mule |.((set-weir dest weir.load.dart)))
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %sand wire.dart ~)
        %|  (enqu-take here ~ ~ %sand wire.dart `p.res)
      ==
      ::
        %load
      ::  Reload nexus at dest (must be a directory with a nexus)
      ?>  ?=(%| -.u.dest-lane)
      =/  dest=fold:tarball  p.u.dest-lane
      =/  res=(each _this tang)  (mule |.((reload-nexus dest)))
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %load wire.dart ~)
        %|  (enqu-take here ~ ~ %load wire.dart `p.res)
      ==
      ::
        %peek
      ?>  ?=(^ dest-lane)
      (dart-peek here dart u.dest-lane)
      ::
        %code
      ?>  ?=(^ dest-lane)
      (dart-code here dart u.dest-lane)
      ::
        %font
      ::  Find the /code namespace governing this node.
      ::  Walks up from dest to the nearest /code lode.
      ::  ~: blocked (weir), [~ ~]: definitively none, [~ ~ bend]: found.
      =/  pax=path
        ?-(-.u.dest-lane %| p.u.dest-lane, %& path.p.u.dest-lane)
      =/  ns=(unit fold:tarball)  (find-code-ns pax)
      ?~  ns
        ::  No code nexus anywhere. But can the querier see all the way up?
        =/  =filt:nexus  (allowed %peek here `[%| /])
        ?:  ?=([~ %|] filt)
          (enqu-take here ~ ~ %font wire.dart ~)
        (enqu-take here ~ ~ %font wire.dart `~)
      =/  =filt:nexus  (allowed %peek here `[%| u.ns])
      ?:  ?=([~ %|] filt)
        (enqu-take here ~ ~ %font wire.dart ~)
      =/  =bend:tarball  (make-bend:tarball here [%| u.ns])
      (enqu-take here ~ ~ %font wire.dart ``bend)
      ::
        %keep
      ::  Subscribe to changes at dest (uses peek permission)
      ?>  ?=(^ dest-lane)
      =/  remote=(unit [@p lane:tarball])  (resolve-remote u.dest-lane)
      ?^  remote
        ::  Remote subscribe: register locally and send %keep to remote
        =/  [target=@p real-dest=lane:tarball]  u.remote
        =.  this  (sub-put u.dest-lane here wire.dart blot.load.dart)
        =/  req=load:remo:nexus
          [[wire.dart real-dest] %keep ~]
        =.  cards
          :_  cards
          [%pass /keep/[(scot %p target)] %agent [target %grubbery] %poke grubbery-load+!>(req)]
        this
      ::  Local subscribe
      =.  this  (sub-put u.dest-lane here wire.dart blot.load.dart)
      =/  =wave:nexus  (wave-at:nexus born u.dest-lane)
      (enqu-take here ~ ~ %news wire.dart wave)
      ::
        %drop
      ::  Unsubscribe from dest
      ?>  ?=(^ dest-lane)
      =/  remote=(unit [@p lane:tarball])  (resolve-remote u.dest-lane)
      ?^  remote
        ::  Remote unsubscribe
        =/  [target=@p real-dest=lane:tarball]  u.remote
        =.  this  (sub-del u.dest-lane here)
        =/  req=load:remo:nexus
          [[wire.dart real-dest] %drop ~]
        =.  cards
          :_  cards
          [%pass /drop/[(scot %p target)] %agent [target %grubbery] %poke grubbery-load+!>(req)]
        this
      =.  this  (sub-del u.dest-lane here)
      (enqu-take here ~ ~ %fell wire.dart)
      ::
        %seek
      ::  Find all [rail cass] pairs with matching lobe in subtree
      =/  res=(each (list [=rail:tarball =cass:clay]) tang)
        (mule |.((seek-lobe u.dest-lane nobe.load.dart)))
      (enqu-take here ~ ~ %seek wire.dart res)
      ::
        %peep
      ?>  ?=(^ dest-lane)
      (dart-peep here dart u.dest-lane)
      ::
        %born
      ::  Read hist metadata at dest: file hist (%&) or fold hist (%|).
      ::  Pure metadata — no lobes leave the runtime, no silo refs.
      =/  sk=(unit hist:nexus)
        ?-  -.u.dest-lane
          %&  (get-born p.u.dest-lane)
          %|  =/  node  (~(get of born) p.u.dest-lane)
              ?~(node ~ `fold.u.node)
        ==
      ?~  sk
        (enqu-take here ~ ~ %born wire.dart |+~[leaf+"no history at dest"])
      =/  entries=(list [=cass:clay tags=(set @t) tomb=?])
        %+  turn  (tap:hon:hist:nexus u.sk)
        |=  [key=cass:clay val=entry:hist:nexus]
        [key tags.val ?=(%tomb -.pace.val)]
      (enqu-take here ~ ~ %born wire.dart &+entries)
      ::
        %lose
      ::  Drop hist entries and decrement silo refs (file or fold)
      =/  res=(each _this tang)
        %-  mule  |.
        ?-  -.u.dest-lane
          %&  (drop-hist p.u.dest-lane lose.load.dart)
          %|  (drop-fold-hist p.u.dest-lane lose.load.dart)
        ==
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %lost wire.dart ~)
        %|  (enqu-take here ~ ~ %lost wire.dart `p.res)
      ==
      ::
        %gain
      ::  Set gain flag. Recursive on directories, single file on rails.
      =/  res=(each _this tang)
        (mule |.((set-gain-lane u.dest-lane flag.load.dart)))
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %gain wire.dart ~)
        %|  (enqu-take here ~ ~ %gain wire.dart `p.res)
      ==
      ::
        %firm
      ::  Promote current hist entry to %firm (file or fold).
      =/  res=(each _this tang)
        %-  mule  |.
        ?-  -.u.dest-lane
          %&  (firm-hist p.u.dest-lane ~)
          %|  (firm-fold p.u.dest-lane ~)
        ==
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %held wire.dart ~)
        %|  (enqu-take here ~ ~ %held wire.dart `p.res)
      ==
      ::
        %tag
      ::  Set tags on current hist entry (file or fold).
      =/  res=(each _this tang)
        %-  mule  |.
        ?-  -.u.dest-lane
          %&  (tag-hist p.u.dest-lane case.load.dart tags.load.dart)
          %|  (tag-fold p.u.dest-lane case.load.dart tags.load.dart)
        ==
      ?-  -.res
        %&  (enqu-take:p.res here ~ ~ %held wire.dart ~)
        %|  (enqu-take here ~ ~ %held wire.dart `p.res)
      ==
    ==
    ::
      %here
    ::  Request location — walk up, reveal as much as allowed
    =/  loc=here:nexus  (walk-here here)
    (enqu-take here ~ ~ %here wire.dart loc)
    ::
    ::
      %kept
    ::  Return this grub's outgoing subscriptions, relativized
    =/  targets=(set lane:tarball)  (rev-get here)
    =/  =kept:nexus
      %-  ~(gas in *kept:nexus)
      %+  turn  ~(tap in targets)
      |=(target=lane:tarball (make-bend:tarball here target))
    (enqu-take here ~ ~ %kept wire.dart kept)
  ==
::  dart-peek: resolve a %peek dart. a remote dest (under /sys/ames/ships/…)
::  stages the peek and forwards a %peek load to the owning ship, suspending
::  until the intake discharges it. a local dir returns ball+born, a local
::  file returns its cage; %none when nothing lives at dest.
::
++  dart-peek
  |=  [here=rail:tarball =dart:nexus dest-lane=lane:tarball]
  ^+  this
  ?>  ?=([%node *] dart)
  ?>  ?=([%peek *] load.dart)
  ::  Remote peek: if dest is under /sys/ames/ships/[ship]/root/,
  ::  stage the peek and send %peek load to the remote ship.
  ::  The fiber suspends until discharge-peeks sends the intake back.
  =/  remote=(unit [@p lane:tarball])  (resolve-remote dest-lane)
  ?^  remote
    =/  [target=@p real-dest=lane:tarball]  u.remote
    =/  key=[rail:tarball wire]  [here wire.dart]
    =.  peeks.remo
      %+  ~(put by peeks.remo)  key
      [target real-dest deep.load.dart blot.load.dart ~ *@uvJ]
    =/  req=load:remo:nexus
      [[wire.dart real-dest] %peek case.load.dart deep.load.dart]
    =.  cards
      :_  cards
      [%pass /peek/[(scot %p target)] %agent [target %grubbery] %poke grubbery-load+!>(req)]
    this
  ::  Peek at dest - directory returns ball+born, file returns cage
  ::  Returns %none if directory doesn't exist or has no lump
  ::  ver: if set, read historical version from hist via silo
  ?-    -.dest-lane
      %|
    =/  dest=fold:tarball  p.dest-lane
    =/  sub-born=born:nexus  (~(dip of born) dest)
    ?:  &(=(~ fil.sub-born) =(~ dir.sub-born))
      (enqu-take here ~ ~ %peek wire.dart [%none ~])
    ::  Get root tree ject lobe from born fold hist:
    ::  historical if case is set, current top otherwise.
    =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
      fil.sub-born
    =/  root-lobe=(unit jobe:nexus)
      ?~  node  ~
      ?^  case.load.dart
        =/  cp  (resolve-case:nexus u.case.load.dart fold.u.node)
        ?~  cp  ~
        ?:  ?=(%tomb -.pace.u.cp)  ~
        p.pace.u.cp
      =/  got=(unit [key=cass:clay val=entry:hist:nexus])
        (ram:hon:hist:nexus fold.u.node)
      ?~  got  ~
      ?:  ?=(%tomb -.pace.val.u.got)  ~
      p.pace.val.u.got
    ?~  root-lobe
      ::  empty answer: a cased peek that found nothing is a %miss (the
      ::  dir exists, that REVISION doesn't) — honest and distinct from
      ::  %none (nothing here at all).
      =/  empty=cite:nexus  ?:(?=(^ case.load.dart) [%miss ~] [%none ~])
      (enqu-take here ~ ~ %peek wire.dart empty)
    ::  Bump ref to keep tree alive while queued
    =.  silo  (~(bump-ject-ref si:nexus silo) u.root-lobe)
    =/  =wave:nexus  (wave-from-born:nexus sub-born)
    (enqu-take here ~ ~ %peek wire.dart [%ball wave u.root-lobe deep.load.dart])
    ::
      %&
    =/  dest=rail:tarball  p.dest-lane
    =/  content  (peek-grub-now path.dest name.dest)
    ?:  &(?=(~ content) ?=(~ case.load.dart))
      (enqu-take here ~ ~ %peek wire.dart [%none ~])
    =/  node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])
      (~(get of born) path.dest)
    =/  sk=hist:nexus
      ?~  node  *hist:nexus
      (fall (~(get by file.u.node) name.dest) *hist:nexus)
    ::  Resolve lobe: historical from silo or current from born
    =/  src-lobe=(unit jobe:nexus)
      ?^  case.load.dart
        =/  cp  (resolve-case:nexus u.case.load.dart sk)
        ?~  cp  ~
        ?:  ?=(%tomb -.pace.u.cp)  ~
        p.pace.u.cp
      ::  Current: get lobe from born pace
      =/  got=(unit [key=cass:clay val=entry:hist:nexus])
        (ram:hon:hist:nexus sk)
      ?~  got  ~
      ?:  ?=(%tomb -.pace.val.u.got)  ~
      p.pace.val.u.got
    ?~  src-lobe
      ::  a cased peek that found nothing is a %miss (that revision isn't
      ::  here), distinct from %none (nothing here at all).
      =/  empty=cite:nexus  ?:(?=(^ case.load.dart) [%miss ~] [%none ~])
      (enqu-take here ~ ~ %peek wire.dart empty)
    ::  Bump silo ref to keep ject alive while queued
    =.  silo  (~(bump-ject-ref si:nexus silo) u.src-lobe)
    =/  =cass:clay  (fall (top:hist:nexus sk) *cass:clay)
    (enqu-take here ~ ~ %peek wire.dart [%file cass u.src-lobe blot.load.dart])
  ==
::  dart-code: peek the /code bins slice at dest — walk up to the governing
::  code nexus (lode), return its refs at the inner path. a file may resolve a
::  /tub/from/to tube request via the marc grow gate, caching the built tube in
::  bins so it can be referenced by ckey.
::
++  dart-code
  |=  [here=rail:tarball =dart:nexus dest-lane=lane:tarball]
  ^+  this
  ?>  ?=([%node *] dart)
  ?-    -.dest-lane
      %|
    =/  dest=fold:tarball  p.dest-lane
    =/  nex=(unit fold:tarball)
      =+  pax=dest
      |-  ?:  (~(has by code) pax)  `pax
      ?~  pax  ~
      $(pax (snip `path`pax))
    ?~  nex
      (enqu-take here ~ ~ %code wire.dart |+|+~[leaf+"code: no code nexus at {(spud dest)}"])
    =/  =lode:nexus  (~(got by code) u.nex)
    =/  inner=fold:tarball  (slag (lent u.nex) dest)
    =/  sub-refs=refs:nexus  (~(dip of refs.lode) inner)
    (enqu-take here ~ ~ %code wire.dart &+sub-refs)
    ::
      %&
    =/  dest=rail:tarball  p.dest-lane
    =/  nex=(unit fold:tarball)
      =+  pax=path.dest
      |-  ?:  (~(has by code) pax)  `pax
      ?~  pax  ~
      $(pax (snip `path`pax))
    ?~  nex
      (enqu-take here ~ ~ %code wire.dart |+|+~[leaf+"code: no code nexus at {(spud path.dest)}"])
    =/  =lode:nexus  (~(got by code) u.nex)
    =/  inner=path  (slag (lent u.nex) path.dest)
    =/  node=(unit (map @ta @uv))  (~(get of refs.lode) inner)
    =/  ckey=(unit @uv)
      ?~  node  ~
      (~(get by u.node) name.dest)
    ?^  ckey
      (enqu-take here ~ ~ %code wire.dart |+&+u.ckey)
    ::  Tube requests: /tub/from/to — resolve via marc grow gate
    ?.  ?=([%tub @ ~] inner)
      (enqu-take here ~ ~ %code wire.dart |+|+~[leaf+"code: {(trip name.dest)} not found at {(spud path.dest)}"])
    =/  from=blot:tarball  [/ i.t.inner]
    =/  to=blot:tarball  [/ name.dest]
    =/  tube-res=(each tube:clay tang)
      (mule |.((grow:(get-marc (snip `path`u.nex) from) to)))
    ?:  ?=(%| -.tube-res)
      (enqu-take here ~ ~ %code wire.dart |+|+p.tube-res)
    ::  Store tube in bins so it can be referenced by ckey
    =/  =built:nexus  [%vase !>(p.tube-res)]
    =/  tube-ckey=@uv  (sham built)
    =.  bins  (~(put by bins) tube-ckey [1 built])
    (enqu-take here ~ ~ %code wire.dart |+&+tube-ckey)
  ==
::  dart-poke: route a poke dart to a file. pokes under /sys/ are validated and
::  consumed immediately — timer-set / eyre-action / push-action and other sys
::  intercepts are handled inline; everything else (and all non-sys pokes) is
::  enqueued as a bask, validated at consumption.
::
++  dart-poke
  |=  [here=rail:tarball =dart:nexus dest-lane=lane:tarball]
  ^+  this
  ?>  ?=([%node *] dart)
  ?>  ?=([%poke *] load.dart)
  ::  Poke destination must be a file
  ?>  ?=(%& -.dest-lane)
  =/  dest=rail:tarball  p.dest-lane
  ::  Remote poke: forward a %poke load to the owning ship with the
  ::  sender and wire encoded for the return trip. No %pack is given
  ::  here — a %pack means "consumed", and consumption happens on the
  ::  other ship. The result arrives later as a %pack poke: from
  ::  +process-pack when their grub consumes it, or from the
  ::  %grub-poke on-agent case if their gate nacks the load itself.
  =/  remote=(unit [@p lane:tarball])  (resolve-remote dest-lane)
  ?^  remote
    =/  [target=@p real-dest=lane:tarball]  u.remote
    =/  grub-wire=path
      :-  %grub-poke
      :-  (scot %ud (lent path.here))
      (weld path.here [name.here wire.dart])
    =/  req=load:remo:nexus
      [[grub-wire real-dest] %poke bask.load.dart]
    =.  cards
      :_  cards
      [%pass grub-wire %agent [target %grubbery] %poke grubbery-load+!>(req)]
    this
  ::  /sys/ intercepts: validate and consume immediately.
  ::  Direct validation, no cache: poke payloads are transient
  ::  (never silo-resident), so the sham-keyed vale cache can only
  ::  miss — probing it just hashes the full payload twice.
  ?:  ?=([%sys *] path.dest)
    =/  validated=(each vase tang)
      (validate-noun path.dest p.bask.load.dart q.bask.load.dart)
    ?:  ?=(%| -.validated)
      ::  No marc or validation failed — fall through to general poke
      =/  rel=from:fiber:nexus  (relativize-from:nexus dest here)
      (enqu-take dest `[here wire.dart] ~ %poke rel bask.load.dart)
    =/  =sage:tarball  [p.bask.load.dart p.validated]
    ?:  ?&  =([/sys/behn %'main.behn-state'] dest)
            =([/ %timer-set] p.sage)
        ==
      =.  this  (handle-timer-set here wire.dart q.sage)
      (enqu-take here ~ ~ %pack wire.dart ~)
    ?:  ?&  =([/sys/behn %'main.behn-state'] dest)
            =([/ %timer-rest] p.sage)
        ==
      =.  this  (handle-timer-rest here q.sage)
      (enqu-take here ~ ~ %pack wire.dart ~)
    ?:  ?&  =([/sys/eyre %'main.server-state'] dest)
            =([/ %eyre-action] p.sage)
        ==
      =.  this  (handle-eyre-action here wire.dart q.sage)
      (enqu-take here ~ ~ %pack wire.dart ~)
    ?:  ?&  =([/sys/push %'main.push-state'] dest)
            =([/ %push-action] p.sage)
        ==
      =.  this  (handle-push-action here wire.dart q.sage)
      (enqu-take here ~ ~ %pack wire.dart ~)
    =/  sys=(unit _this)
      (handle-sys-poke dest here wire.dart sage)
    ?^  sys  u.sys
    ::  /sys/ poke not intercepted — enqueue as bask
    =/  rel=from:fiber:nexus  (relativize-from:nexus dest here)
    (enqu-take dest `[here wire.dart] ~ %poke rel bask.load.dart)
  ::  General poke: enqueue as bask, validate at consumption
  =/  rel=from:fiber:nexus  (relativize-from:nexus dest here)
  (enqu-take dest `[here wire.dart] ~ %poke rel bask.load.dart)
::  dart-peep: query the hist entries at a file matching the dart's find spec
::  (case-set, date range, or block number), returning the matched [cass lobe]
::  pairs — bumping a silo ref on each so the jects survive while queued.
::
++  dart-peep
  |=  [here=rail:tarball =dart:nexus dest-lane=lane:tarball]
  ^+  this
  ?>  ?=([%node *] dart)
  ?>  ?=([%peep *] load.dart)
  ?>  ?=(%& -.dest-lane)
  =/  dest=rail:tarball  p.dest-lane
  =/  sk=(unit hist:nexus)  (get-born dest)
  ?~  sk
    (enqu-take here ~ ~ %peep wire.dart |+~[leaf+"no history for {(spud (snoc path.dest name.dest))}"])
  =/  entries=(list [key=cass:clay val=entry:hist:nexus])
    (tap:hon:hist:nexus u.sk)
  =/  hits=(list [cass:clay jobe:nexus])
    %+  murn  entries
    |=  [key=cass:clay val=entry:hist:nexus]
    ^-  (unit [cass:clay jobe:nexus])
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
    ?:  ?=(%tomb -.pace.val)  ~
    ?~  p.pace.val  ~
    `[key u.p.pace.val]
  ::  Bump silo refs for all matched lobes (pace lobes are jects)
  =.  silo
    %+  roll  hits
    |=  [[* =jobe:nexus] acc=_silo]
    (~(bump-ject-ref si:nexus acc) jobe)
  (enqu-take here ~ ~ %peep wire.dart &+hits)
::
++  spawn-proc
  |=  [here=rail:tarball =prod:fiber:nexus]
  ^+  this
  ::  Skip if nexus is banged — don't try to build processes
  ?:  (is-nexus-banged here)
    this
  ::  Build spool and process — bang file on crash or build failure
  =/  spool-got
    (build-spool here)
  =/  spool-res=(each spool:fiber:nexus tang)
    ?:  ?=(%| -.spool-got)  spool-got
    (mule |.((fall p.spool-got default-spool)))
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
  (enqu-take here ~ ~)
::
++  default-spool
  ^-  spool:fiber:nexus
  |=  prod:fiber:nexus
  stay:(fiber:fiber:nexus ,~)
::
++  process-take
  |=  [here=rail:tarball =take:fiber:nexus]
  ^+  this
  ::  a %pack landing on a ship.sig with a %grub-poke wire is the
  ::  consumption result of a poke that ship sent us — forward it
  ::  home as a %pack transfer instead of feeding the representative
  ::  fiber
  ?:  ?&  ?=([%sys %ames %ships @ ~] path.here)
          =(%'ship.sig' name.here)
          ?=([* ~ %pack * *] take)
          ?=([%grub-poke *] wire.u.in.take)
      ==
    =/  target=(unit @p)  (slaw %p i.t.t.t.path.here)
    ?~  target  this
    =/  =transfer:remo:nexus  [wire.u.in.take %pack err.u.in.take]
    (emit-card [%pass /pack %agent [u.target %grubbery] %poke grubbery-transfer+!>(transfer)])
  ::  an outcome landing on a ship.sig with a %client wire is the
  ::  result of a grub-cmd from an external agent on that ship (the
  ::  thin surface, sur/grub) — give it as a %grub-fact on the
  ::  client's subscription instead of feeding the representative
  ::  fiber. %pack/%made/%gone/%sand/%load all carry [wire err].
  ?:  ?&  ?=([%sys %ames %ships @ ~] path.here)
          =(%'ship.sig' name.here)
          ?=(^ in.take)
          ?=(?(%pack %made %gone %sand %load) -.u.in.take)
          ?=([%client @ *] wire.u.in.take)
      ==
    =/  id=@ta  i.t.wire.u.in.take
    (give-client-fact id [%ack err.u.in.take])
  ::  a vetoed client dart: same channel, as an error ack
  ?:  ?&  ?=([%sys %ames %ships @ ~] path.here)
          =(%'ship.sig' name.here)
          ?=(^ in.take)
          ?=([%veto *] u.in.take)
          ?=([%node *] dart.u.in.take)
          ?=([%client @ *] wire.dart.u.in.take)
      ==
    =/  id=@ta  i.t.wire.dart.u.in.take
    (give-client-fact id [%ack `~[leaf+"vetoed by weir"]])
  ::  Get pipe at directory
  =/  =pipe:nexus  (fall (~(get of pool) path.here) *pipe:nexus)
  ::  Get proc for this file - must exist
  =/  prc=(unit proc:fiber:nexus)  (~(get by proc.pipe) name.here)
  ?~  prc
    ::  no process at this rail: nack pokes instead of silently
    ::  dropping them, and release any silo refs the take carries
    =.  this  (drop-pend-refs in.take)
    ?.  ?=([* ~ %poke *] take)  this
    %+  give-poke-sign  here
    [take `~[leaf+"no process at {(spud (snoc path.here name.here))}"]]
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
  =^  res=(each vase tang)  this
    (validate-cached path.here blot new)
  ?:  ?=(%& -.res)
    [%& p.res this]
  [%| p.res]
::
++  hydrate
  |=  [cod=path in=(unit pend:fiber:nexus)]
  ^-  [(each (unit intake:fiber:nexus) tang) _this]
  ?~  in  [&+~ this]
  ?+    -.u.in  [&+`u.in this]
      %poke
    ::  bask → sage: validate noun through compiled type.
    ::  Direct, no cache — transient poke payloads can't hit it (see
    ::  the /sys/ intercept note at the dispatch site).
    =/  validated=(each vase tang)
      (validate-noun cod p.bask.u.in q.bask.u.in)
    ?:  ?=(%| -.validated)
      :-  |+[leaf+"hydrate: poke validation failed for {<p.bask.u.in>} at {(spud cod)}" p.validated]
      this
    [&+`[%poke from.u.in [p.bask.u.in p.validated]] this]
      %peek
    ::  cite → view: resolve lobe from silo, wrap with type
    =/  =cite:nexus  cite.u.in
    =/  =view:nexus
      ?-  -.cite
        %none  [%none ~]
        %miss  [%miss ~]
        %veto  [%veto ~]
        %tomb  [%tomb ~]
          %file
        =/  jot  (~(get by jects.silo) lobe.cite)
        ?~  jot  [%none ~]
        =/  jt=ject:nexus  ject.u.jot
        ?.  ?=(%leaf -.jt)  [%none ~]
        =/  got=(unit noun)  (~(get si:nexus silo) lobe.leaf.jt)
        ?~  got  [%none ~]
        =/  =bask:tarball  [blot.mark.leaf.jt u.got]
        =/  res  (validate-bask cod bask)
        ?:  ?=(%| -.res)
          [%file cass.cite [blot.mark.leaf.jt %| [p.res u.got]]]
        =/  =sage:tarball  p.res
        =/  result=sang:tarball
          ?~  conv.cite  (sage-to-sang:tarball sage)
          ?:  =(p.sage u.conv.cite)  (sage-to-sang:tarball sage)
          =/  =tube:clay  (get-tube cod [p.sage u.conv.cite])
          (sage-to-sang:tarball [u.conv.cite (tube q.sage)])
        [%file cass.cite result]
          %ball
        =/  sub-ball
          ?:  deep.cite
            (peek-ball lobe.cite)
          (peek-ball-shallow lobe.cite)
        [%ball wave.cite sub-ball]
      ==
    ::  Drop silo refs after hydrating
    =?  silo  ?=(%file -.cite)  (~(drop-ject si:nexus silo) lobe.cite)
    =?  silo  ?=(%ball -.cite)  (~(drop-ject si:nexus silo) lobe.cite)
    [&+`[%peek wire.u.in view] this]
      %peep
    ::  Resolve lobes to sages
    ?:  ?=(%| -.res.u.in)
      [&+`[%peep wire.u.in |+p.res.u.in] this]
    =/  hits=(list [cass:clay sage:tarball])
      %+  murn  p.res.u.in
      |=  [cas=cass:clay =jobe:nexus]
      ^-  (unit [cass:clay sage:tarball])
      =/  jot  (~(get by jects.silo) jobe)
      ?~  jot  ~
      =/  jt=ject:nexus  ject.u.jot
      ?.  ?=(%leaf -.jt)  ~
      =/  got=(unit noun)  (~(get si:nexus silo) lobe.leaf.jt)
      ?~  got  ~
      =/  res  (validate-bask cod [blot.mark.leaf.jt u.got])
      ?:  ?=(%| -.res)  ~
      `[cas p.res]
    ::  Drop silo refs (pace lobes are jects)
    =.  silo
      %+  roll  p.res.u.in
      |=  [[* =jobe:nexus] acc=_silo]
      (~(drop-ject si:nexus acc) jobe)
    [&+`[%peep wire.u.in &+hits] this]
      %code
    ::  Resolve ckeys to builts
    ?:  ?=(%| -.res.u.in)
      ?:  ?=(%| -.p.res.u.in)
        [&+`[%code wire.u.in |+[%tang p.p.res.u.in]] this]
      =/  ckey=@uv  p.p.res.u.in
      =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) ckey)
      ?~  entry
        [&+`[%code wire.u.in |+[%tang ~[leaf+"code: artifact missing"]]] this]
      [&+`[%code wire.u.in |+built.u.entry] this]
    ::  Directory: resolve ckey tree to built tree
    =/  materialized=(axal (map @ta built:nexus))
      %+  roll  ~(tap of p.res.u.in)
      |=  [[pax=path node=(map @ta @uv)] acc=(axal (map @ta built:nexus))]
      =/  resolved=(map @ta built:nexus)
        %-  ~(gas by *(map @ta built:nexus))
        %+  murn  ~(tap by node)
        |=  [nam=@ta key=@uv]
        =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) key)
        ?~  entry  ~
        `[nam built.u.entry]
      (~(put of acc) pax resolved)
    [&+`[%code wire.u.in &+materialized] this]
  ==
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
    ::  Hydrate pend → intake at consumption time
    =^  hydrated=(each (unit intake:fiber:nexus) tang)  this
      (hydrate path.here in.take)
    ?:  ?=(%| -.hydrated)
      =/  =tang  [leaf+"hydrate failed" p.hydrated]
      :*  darts
          :_(done [take `tang])
          state
          proc
          [%fail tang]
          this
      ==
    =/  hot-in=(unit intake:fiber:nexus)  p.hydrated
    =/  res=(each output tang)
      ?>  ?=(%& -.process.proc)
      (mule |.((p.process.proc state hot-in)))
    ?:  ?=(%| -.res)
      =/  =tang  [leaf+"crash" p.res]
      %-  (slog ~[leaf+"%fiber-crash {(spud (snoc path.here name.here))} in={<in-tag=?~(in.take ~ `-.u.in.take)>}"])
      %-  (slog tang)
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
      =/  =tang  [leaf+"state validation failed at {(spud (snoc path.here name.here))}"]~
      :*  darts
          :_(done [take `tang])
          state
          proc
          [%fail tang]
          this
      ==
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
  =/  file-data
    (peek-grub-now path.here name.here)
  ?~  file-data  this
  ?:  (is-boom:tarball u.file-data)  this
  =/  fil-state=vase  (need-vase:tarball u.file-data)
  ::  Run the evaluator (mule to catch hard crashes like !< mismatches)
  =/  eval-res=(each [darts=(list dart:nexus) done=(list took:eval) new-state=vase new-proc=proc:fiber:nexus res=result:eval core=_this] tang)
    (mule |.((take:eval here fil-state proc)))
  ?:  ?=(%| -.eval-res)
    ::  Runtime crash — restart process with error prod
    ?:  (is-nexus-banged here)  this
    =/  spool-got  (build-spool here)
    =/  spool-res=(each spool:fiber:nexus tang)
      ?:  ?=(%| -.spool-got)  spool-got
      (mule |.((fall p.spool-got default-spool)))
    ?:  ?=(%| -.spool-res)
      (bang-file here p.spool-res)
    =/  proc-res=(each process:fiber:nexus tang)
      (mule |.((p.spool-res `p.eval-res)))
    ?:  ?=(%| -.proc-res)
      (bang-file here p.proc-res)
    =.  this  (store-proc here [&+p.proc-res ~ next.proc])
    (enqu-take here ~ ~)
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
    =.  this  (save-file here [p.u.file-data q.new-state])
    (store-proc here new-proc)
      %done
    ::  Save final state so subscribers see it, then delete
    =.  this  (save-file here [p.u.file-data q.new-state])
    =/  err=tang  ~[leaf+"process completed"]
    :: only nack-pokes when we're done
    ::
    =.  this  (nack-poke-takes here next.new-proc err)
    =.  this  (nack-poke-takes here skip.new-proc err)
    (delete path.here name.here)
      %fail
    ::  Progress is STEP-atomic: the failing step contributed nothing
    ::  (its state and darts were annulled in the eval loop), but every
    ::  completed step before it stands — commit the accumulated
    ::  last-validated state, exactly as %next does. (The old don't-
    ::  save rollback was half a transaction: darts always leaked, so
    ::  discarding the state only made effects and state diverge —
    ::  and re-running from stale state double-executed work.)
    ::  Then restart. Subs survive (wires still route). Sync queues
    ::  (consumed takes removed), rebuild process, enqueue.
    =.  this  (save-file here [p.u.file-data q.new-state])
    ?:  (is-nexus-banged here)  this
    =/  spool-got  (build-spool here)
    =/  spool-res=(each spool:fiber:nexus tang)
      ?:  ?=(%| -.spool-got)  spool-got
      (mule |.((fall p.spool-got default-spool)))
    ?:  ?=(%| -.spool-res)
      (bang-file here p.spool-res)
    =/  proc-res=(each process:fiber:nexus tang)
      (mule |.((p.spool-res `err.res)))
    ?:  ?=(%| -.proc-res)
      (bang-file here p.proc-res)
    =/  merged-skip=(qeu take:fiber:nexus)
      (~(gas to skip.new-proc) ~(tap to next.new-proc))
    =.  this  (store-proc here [&+p.proc-res ~ merged-skip])
    (enqu-take here ~ ~)
  ==
::
++  poke
  |=  [give=(unit give:nexus) here=rail:tarball =bask:tarball]
  ^+  this
  =/  rel-from=from:fiber:nexus
    ?~  give  *from:fiber:nexus
    (relativize-from:nexus here from.u.give)
  (enqu-take here give ~ %poke rel-from bask)
::
++  make
  |=  [src=fold:tarball dest=lane:tarball force=? gain=? =make:nexus]
  ^+  this
  ?-    -.dest
      %|
    ::  Make directory — sync bole into dest, fail if exists without force
    ?>  ?=(%& -.make)
    =/  dest-path=fold:tarball  p.dest
    =/  new-bole=bole:tarball  p.make
    ?.  force
      =/  existing=born:nexus  (~(dip of born) dest-path)
      ?~  fil.existing  $(force %.y)
      =/  fold-cas=(unit cass:clay)
        (top:hist:nexus fold.u.fil.existing)
      ?~  fold-cas  $(force %.y)
      =/  cur-pace=(unit pace:hist:nexus)
        (get-pace:hist:nexus fold.u.fil.existing u.fold-cas)
      ::  Latest version is empty = directory was deleted, allow recreate
      ?:  &(?=(^ cur-pace) ?=(?(%temp %firm) -.u.cur-pace) =(~ p.u.cur-pace))
        $(force %.y)
      ~|("make failed: directory {(spud dest-path)} already exists" !!)
    =.  this  (load-ball-changes dest-path new-bole)
    ::  born gained: set retention on the whole made subtree in the same
    ::  event — after content lands, before anything can run against it.
    ::  Guarded: an unguarded %.n sweep would strip gains the bole set.
    =?  this  gain  (set-gain-lane dest %.y)
    ::  record the made bole's ROOT weir. Kid weirs ride the tree build,
    ::  but the root's own weir lives in its PARENT's dir entry and was
    ::  never recorded — making make-with-weir silently partial. Set it
    ::  before any on-load/spawn below so the nexus never runs unjailed.
    ::  ONLY when the maker sits OUTSIDE the made dir: sandboxing is
    ::  imposed from above, and a grub remaking its own root must never
    ::  smuggle in its own weir (self-escalation by rebirth).
    =?  this
      ?&  ?=(^ fil.new-bole)
          ?=(^ weir.u.fil.new-bole)
          !=(dest-path (prefix:tarball dest-path src))
      ==
      (set-weir dest-path weir.u.fil.new-bole)
    ::  a directory landing inside an existing code namespace changes
    ::  sources the per-file write path would have registered — resync
    ::  the governing lode with a full sweep, as +delete already does
    =.  this
      =/  cod=(unit path)
        =+  pax=dest-path
        |-  ?:  (~(has by code) pax)  `pax
        ?~  pax  ~
        $(pax (snip `path`pax))
      ?~  cod  this
      (build-code u.cod ~)
    =.  this  (build-new-code-namespaces dest-path new-bole)
    ::  Reload nexuses in the new bole (runs on-load, recurses children)
    =/  sub-ball  (peek-ball-now dest-path)
    =.  this
      ?:  ?&(?=(^ fil.sub-ball) ?=(^ neck.u.fil.sub-ball) !=([/ %code] u.neck.u.fil.sub-ball))
        =/  nex=(each nexus:nexus tang)
          (build-nexus dest-path u.neck.u.fil.sub-ball)
        ?:(?=(%| -.nex) (bang-nexus dest-path p.nex) (reload-nexus-at dest-path p.nex))
      (reload-child-nexuses dest-path)
    ::  On-loads can CREATE %code-necked subdirs (e.g. the desk
    ::  nexus's /desk/code) — re-scan the realized tree so they
    ::  register now, not at the next cold-start. Idempotent.
    =.  this  (build-new-code-namespaces dest-path (peek-bole-now dest-path))
    (spawn-all-files dest-path (peek-bole-now dest-path))
    ::
      %&
    ::  Make file — fail if exists without force
    ?>  ?=(%| -.make)
    =/  dest-rail=rail:tarball  p.dest
    ?.  force
      =/  sk=(unit hist:nexus)  (get-born dest-rail)
      ?~  sk  $(force %.y)
      =/  latest=(unit [key=cass:clay val=entry:hist:nexus])
        (ram:hon:hist:nexus u.sk)
      ?~  latest  $(force %.y)
      ?:  ?=(%tomb -.pace.val.u.latest)  $(force %.y)
      ?~  p.pace.val.u.latest  $(force %.y)
      ~|("make failed: file {(spud (snoc path.dest-rail name.dest-rail))} already exists" !!)
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
    ::  Validate the bask before storing
    =^  validated=(each vase tang)  this
      (validate-cached path.dest-rail p.bask q.bask)
    ?:  ?=(%| -.validated)
      ~|("make failed: validation error" (mean p.validated))
    =.  this
      (save-file dest-rail [p.bask q.p.validated])
    ::  born gained: same event as the save — no window for a fast
    ::  process's self-clean to tomb the grub before retention lands
    =?  this  gain  (set-gain-lane dest %.y)
    ::  Spawn process (respawns if already exists via store-proc)
    (spawn-proc dest-rail ~)
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
    =.  this  (load-ball-changes dest-path *bole:tarball)
    ::  Deregister any code namespaces that lived in the culled subtree
    purge-stale-code
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
  =/  old-weir=(unit weir:nexus)  (get-weir-for dest)
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
    =/  pac=(unit pace:hist:nexus)  (get-pace:hist:nexus fold.node u.fold-top)
    ?~  pac  [~ %.n ~ ~ ~]
    ?:  ?=(%tomb -.u.pac)  [~ %.n ~ ~ ~]
    ?~  p.u.pac  [~ %.n ~ ~ ~]
    =/  jot  (~(get by jects.silo) u.p.u.pac)
    ?~  jot  [~ %.n ~ ~ ~]
    ?.  ?=(%tree -.ject.u.jot)  [~ %.n ~ ~ ~]
    tree.ject.u.jot
  =/  old-entry=[=jobe:nexus weir=(unit weir:nexus)]
    (fall (~(get by dir.existing-tree) child-name) [*jobe:nexus ~])
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
    =/  fold-top=(unit [key=cass:clay val=entry:hist:nexus])
      (ram:hon:hist:nexus fold.u.fil.sub)
    ?~  fold-top  ~
    =/  =pace:hist:nexus  pace.val.u.fold-top
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
::  Dest-less darts (%kept) never reach here: a dart that names no
::  destination crosses no boundary, so +allowed passes it unfiltered.
::
++  nearest-governor
  |=  [here=rail:tarball dest=(unit lane:tarball)]
  ^-  (unit fold:tarball)
  ?~  dest  ~  :: unreachable from +allowed; no dest, no governor
  ?-    -.u.dest
      ::  File destination: governor is just the common prefix.
      %&
    [~ (prefix:tarball path.here path.p.u.dest)]
      ::  Directory destination: if dest is at-or-above here's dir, the
      ::  operation touches a dir whose entry the parent owns, so the
      ::  governor must be strictly above dest. Otherwise (dest strictly
      ::  inside here's namespace, or disjoint) the common prefix
      ::  governs, same as file destinations.
      ::
      %|
    =/  pref=fold:tarball  (prefix:tarball path.here p.u.dest)
    ?.  =(pref p.u.dest)
      [~ pref]
    ?~  pref
      [~ ~]
    [~ (snip `fold:tarball`pref)]
  ==
::
++  allowed
  |=  [=jump:nexus here=rail:tarball dest=(unit lane:tarball)]
  ^-  filt:nexus
  ::  No destination (%kept): crosses no boundary, no weir has jurisdiction
  ?~  dest  ~
  =/  gov=(unit fold:tarball)  (nearest-governor here dest)
  =/  dest-lane=lane:tarball  u.dest
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
  ::  Reached root - stop
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
    (get-pace:hist:nexus fold.u.fil.parent-born u.fold-top)
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
::  +propagate: repair ancestors and notify, after a leaf mutation
::
::    The mandatory tail of every write. Whatever was done to the
::    leaf: recording a new version, tombing a deletion, or syncing
::    a subtree, the ancestor tree hashes above it must be rebuilt
::    and watchers notified by diffing against the born from before
::    the mutation. Callers snapshot old-born first.
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
  =/  resolved  (resolve-built path.here (weld /mar path.p.bask) name.p.bask)
  =/  marc-ckey=@uv   ?~(resolved 0v0 ckey.u.resolved)
  =/  marc-ns=path     ?~(resolved / namespace.u.resolved)
  =/  raw=*  q.bask
  ::  Capture the leaf being replaced before si-record tombs it
  =/  prev-leaf=(unit leaf:nexus)  (hist-leaf sok file-cass)
  =/  [=nobe:nexus new-silo=silo:nexus new-sok=hist:nexus]
    (~(record si:nexus silo) raw p.bask marc-ckey marc-ns gain new-cass file-cass sok)
  =.  silo  new-silo
  =.  vale  (gc-vale-prev prev-leaf)
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
  (vale-put nobe marc-ckey ?:(?=(%& -.res) ~ `p.res))
::  Sync a bole into the namespace.  One function for make, reload, and
::  cull (cull = empty bole).  Bottom-up walk: children settle before
::  parent builds its tree.  New bole is sole source of truth.
::
++  load-ball-changes
  |=  [here=fold:tarball =bole:tarball]
  ^+  this
  =/  old-born=born:nexus  born
  =.  this  (sync-bole here bole)
  =?  this  !=(~ here)  (record-trees (snip `path`here))
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
  ::  2. Record files: store jects for bole files, [%temp ~ ~] for stale
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
      (get-pace:hist:nexus u.sok u.file-cas)
    ?:  &(?=(^ cur-pace) ?=(?(%temp %firm) -.u.cur-pace) =(~ p.u.cur-pace))
      $(to-delete t.to-delete)
    =/  new-cass=cass:clay  (next-cass:boo u.file-cas)
    =/  new-sok=hist:nexus  (put-pace:hist:nexus u.sok new-cass [%temp ~])
    =.  born  (~(put bo:nexus now.bowl born) [here i.to-delete] new-sok)
    ::  Nack queued inputs and remove process for deleted file
    =/  del-rail=rail:tarball  [here i.to-delete]
    =/  old-pipe=pipe:nexus  (fall (~(get of pool) here) *pipe:nexus)
    =/  old-proc=(unit proc:fiber:nexus)  (~(get by proc.old-pipe) i.to-delete)
    =?  this  ?=(^ old-proc)
      =.  this  (nack-poke-takes del-rail next.u.old-proc ~[leaf+"deleted"])
      (nack-poke-takes del-rail skip.u.old-proc ~[leaf+"deleted"])
    =.  pool
      =/  =pipe:nexus  old-pipe(proc (~(del by proc.old-pipe) i.to-delete))
      (~(put of pool) here pipe)
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
      (get-pace:hist:nexus fold.u.fold-node u.fold-cas)
    ?:  &(?=(^ cur-pace) ?=(?(%temp %firm) -.u.cur-pace) =(~ p.u.cur-pace))
      this
    =/  new-cass=cass:clay  (next-cass:boo u.fold-cas)
    =/  new-fold=hist:nexus
      (put-pace:hist:nexus fold.u.fold-node new-cass [%temp ~])
    this(born (~(put of born) here u.fold-node(fold new-fold)))
  ::  Build tree: file lobes + child fold lobes from born
  =/  settled-born=born:nexus  (~(dip of born) here)
  =/  settled-node=[fold=hist:nexus file=(map @ta hist:nexus)]
    (fall fil.settled-born default-node:boo)
  ::  Neck from bole
  =/  nek=(unit [neck:tarball @uv ns=path])
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
    `[neck nex-ckey (fall nex-ns /)]
  ::  File lobes from born (skip deleted/tombed)
  =/  fil=(map @ta jobe:nexus)
    %-  ~(rep by file.settled-node)
    |=  [[name=@ta sk=hist:nexus] out=(map @ta jobe:nexus)]
    =/  cas=(unit cass:clay)  (top:hist:nexus sk)
    ?~  cas  out
    =/  val=(unit pace:hist:nexus)  (get-pace:hist:nexus sk u.cas)
    ?~  val  out
    ?:  ?=(%tomb -.u.val)  out
    ?~  p.u.val  out
    (~(put by out) name u.p.u.val)
  ::  Dir lobes from born (skip deleted/tombed/null-lobe)
  =/  dir-map=(map @ta [jobe:nexus weir=(unit weir:nexus)])
    %-  ~(rep by dir.settled-born)
    |=  [[name=@ta kid=born:nexus] out=(map @ta [jobe:nexus weir=(unit weir:nexus)])]
    =/  kid-node=(unit [fold=hist:nexus file=(map @ta hist:nexus)])  fil.kid
    ?~  kid-node  out
    =/  cas=(unit cass:clay)  (top:hist:nexus fold.u.kid-node)
    ?~  cas  out
    =/  got=(unit pace:hist:nexus)
      (get-pace:hist:nexus fold.u.kid-node u.cas)
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
  =.  this  (save-file clay-rail [[/ %clay-state] st])
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
    (save-file:acc [dir name] [[/ mar] q.p.res])
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
::  +build-new-code-namespaces: register and build new %code directories
::
::    Walks a newly installed bole. Any directory carrying the %code
::    neck that is not yet in the code map is registered and built
::    with a full sweep. Recurses into children.
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
    ::  register and build (new namespace: no prior graph, full sweep)
    ~&  >  "register-code-namespace: {(spud here)}"
    =.  this  (build-code here ~)
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
  ::  Compile the 4 foundational marks from their real source in /gub/mar/.
  ::  Needed before sync-gub so marks exist to validate incoming files.
  ::  build-code forces these same sources into every code nexus later.
  ::
  ^+  this
  =/  pax=path  /(scot %p our.bowl)/grubbery/(scot %da now.bowl)
  =/  names=(list @ta)  ~[%hoon %tang %mime %kelvin]
  %+  roll  names
  |=  [nam=@ta acc=_this]
  =/  src=@t  !<(@t .^(vase %cr (weld pax /gub/mar/[nam]/hoon)))
  =/  compiled=(each vase tang)
    (build-hoon:build sut /gub/mar/[nam]/hoon src 0)
  ?.  ?=(%& -.compiled)
    ~&  >>>  "bootstrap-marcs: FAILED to compile {(trip nam)}"
    %-  (slog p.compiled)
    acc
  =/  =marc:tarball  (build-marc:marks p.compiled)
  =/  marc-vase=vase  !>(marc)
  =/  =built:nexus  [%vase marc-vase]
  =/  ckey=@uv  (sham built)
  =.  bins.acc  (~(put by bins.acc) ckey [1 built])
  ::  Register in code namespace refs at /mar/{mark-name}
  =/  =lode:nexus  (fall (~(get by code.acc) /code) *lode:nexus)
  =/  ref-path=path  /mar
  =/  node=(map @ta @uv)
    (fall (~(get of refs.lode) ref-path) *(map @ta @uv))
  =.  node  (~(put by node) nam ckey)
  =.  refs.lode  (~(put of refs.lode) ref-path node)
  =.  code.acc  (~(put by code.acc) /code lode)
  acc
::  Sentinel rail in keys recording the subject hash a lode was
::  built under. Not a real file (empty name can't exist in a ball);
::  bins-to-cache skips it (no bins entry), refs never contain it.
::
++  sut-rail  `rail:tarball`[/ %$]
::  +skip-set: rails safe to reuse for an incremental build.
::
::    Returns [skip skip-deps] for build-inc; empty means full sweep.
::    Sweeps unless: the changed set is known, a prior graph exists,
::    the subject sentinel matches (agent upgrade invalidates all
::    keys), and no changed rail is new to the graph — creates can
::    change import resolution of unchanged files, so they always
::    sweep. This is load-bearing, not an optimization shortcut.
::    Foundational mark rails are force-injected from gub into every
::    fold's ball, so they can change without a write under the fold:
::    always treat them as changed (they cache-hit when stable).
::    Otherwise every keyed rail outside the reverse closure of the
::    changed set is reused, carrying its prior key, result (from
::    bins; missing means rebuild normally), and graph edges.
::
++  skip-set
  |=  [cod=path =lode:nexus changed=(unit (set rail:tarball)) sut-hash=@uv]
  ^-  $:  skip=(map rail:tarball [key=@uv res=build-result:build])
          skip-deps=(map rail:tarball (set rail:tarball))
      ==
  =/  none
    ^-  $:  skip=(map rail:tarball [key=@uv res=build-result:build])
            skip-deps=(map rail:tarball (set rail:tarball))
        ==
    [~ ~]
  ?~  changed  none
  ?:  =(~ deps.lode)  none
  ?.  =(`[sut-hash sut-hash] (~(get by keys.lode) sut-rail))
    ~&  >  "skip-set: subject changed, full sweep"
    none
  ::  Relativize changed rails to the fold. A rail outside the fold
  ::  or absent from the prior graph (a create) forces a sweep.
  =/  rel=(unit (set rail:tarball))
    =/  out  *(set rail:tarball)
    =/  todo  ~(tap in u.changed)
    |-
    ?~  todo  `out
    ?.  =(cod (scag (lent cod) path.i.todo))  ~
    =/  rr=rail:tarball  [(slag (lent cod) path.i.todo) name.i.todo]
    ?.  (~(has by deps.lode) rr)  ~
    $(todo t.todo, out (~(put in out) rr))
  ?~  rel
    ~&  >  "skip-set: create or foreign rail in diff, full sweep"
    none
  ::  Foundational marks: changed by fiat, every build
  =/  seed=(set rail:tarball)
    %+  roll  `(list @ta)`~[%hoon %tang %mime %kelvin]
    |=  [nam=@ta acc=_u.rel]
    =/  r=rail:tarball  [/mar (cat 3 nam '.hoon')]
    ?.((~(has by deps.lode) r) acc (~(put in acc) r))
  =/  closure=(set rail:tarball)  (reverse-closure:build deps.lode seed)
  %+  roll  ~(tap by keys.lode)
  ::  ki/ko, not in/out: `in` would shadow the set door
  |=  [[=rail:tarball ki=@uv ko=@uv] acc=_none]
  ?:  =(sut-rail rail)  acc
  ?:  (~(has in closure) rail)  acc
  =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) ko)
  ?~  entry  acc
  =/  res=(unit build-result:build)
    ?-  -.built.u.entry
      %vase  `[%& vase.built.u.entry]
      %tang  `[%| tang.built.u.entry]
      %mime  ~
    ==
  ?~  res  acc
  :-  (~(put by skip.acc) rail [ki u.res])
  (~(put by skip-deps.acc) rail (~(gut by deps.lode) rail ~))
::  +ball-diff: rails that differ between two balls (either side
::  missing, or blot/content changed).
::
++  ball-diff
  |=  [a=ball:tarball b=ball:tarball]
  ^-  (set rail:tarball)
  =/  ma  (~(gas by *(map rail:tarball sang:tarball)) ~(tap ba:tarball a))
  =/  mb  (~(gas by *(map rail:tarball sang:tarball)) ~(tap ba:tarball b))
  %-  ~(gas in *(set rail:tarball))
  %+  weld
    %+  murn  ~(tap by ma)
    |=  [r=rail:tarball s=sang:tarball]
    ^-  (unit rail:tarball)
    =/  t=(unit sang:tarball)  (~(get by mb) r)
    ?~  t  `r
    ?:  ?&(=(p.s p.u.t) =((sang-noun:tarball s) (sang-noun:tarball u.t)))  ~
    `r
  %+  murn  ~(tap by mb)
  |=  [r=rail:tarball *]
  ^-  (unit rail:tarball)
  ?:((~(has by ma) r) ~ `r)
::  Compile a code nexus into its lode in the code map.
::
::  +rebuild-stale-code: recompile every registered code namespace whose
::  recorded build subject differs from the current one.
::
::  An agent upgrade changes sut, invalidating every compiled artifact:
::  a cached nexus built against the old subject fails !< extraction at
::  the kernel boundary. Root /code rebuilds anyway (sync-gub changes
::  its sources), but a scoped namespace with untouched sources was
::  skipped by build-new-code-namespaces' already-registered guard, so
::  its subject sentinel was never consulted and stale artifacts
::  survived to bang at spawn. Runs before the root reload so nothing
::  is built-against-stale when nexuses respawn. No-op when the
::  subject is unchanged — ordinary restarts stay free.
::
::  TODO (state-2, deliberate — do NOT rider this onto another change):
::  the subject hash currently hides in keys.lode under the fake rail
::  [/ %$] as an [hash hash] pair, with special cases in skip-set and
::  refs iteration stepping around it. The clean shape, decided but
::  not yet built:
::    1. lode gains an explicit sut=@uv field (cheap per-namespace
::       gate; this arm's lookup becomes one line)
::    2. build-inc folds sut-hash into every per-file in-hash, so a
::       stale key CANNOT match by construction — no code path can
::       bypass what isn't a separate check
::    3. delete the fake-rail sentinel and all its special cases
::  Costs: lode reshape = state-2 migration (code is derived state —
::  map or reset+rebuild), and the hash change itself forces one full
::  recompile sweep on deploy. Both correct, both loud. Sequence it
::  as its own change with its own verification.
::
++  rebuild-stale-code
  ^+  this
  =/  sut-hash=@uv  (sham q:sut)
  =/  cods=(list [cod=path =lode:nexus])  ~(tap by code)
  |-
  ?~  cods  this
  ?:  =(`[sut-hash sut-hash] (~(get by keys.lode.i.cods) sut-rail))
    $(cods t.cods)
  ~&  >  "rebuild-stale-code: subject changed, rebuilding {(spud cod.i.cods)}"
  =.  this  (build-code cod.i.cods ~)
  $(cods t.cods)
::
++  build-code
  |=  [cod=path changed=(unit (set rail:tarball))]
  ^+  this
  ~&  >  "build-code: start {(spud cod)}"
  ::  1. Source: get ball, force foundational marks
  ::
  =/  src-ball  (peek-ball-now cod)
  =^  src-ball  this  (force-foundational-marks cod src-ball)
  ::  2. Compile: reconstruct cache, run incremental build
  ::
  ::  changed is the set of ball-absolute rails known to have changed;
  ::  ~ means unknown and forces a full sweep. skip-set turns it into
  ::  the rails provably safe to reuse.
  ::
  =/  =lode:nexus   (fall (~(get by code) cod) *lode:nexus)
  =/  old-refs       refs.lode
  =/  old-cache      ~>(%bout.[1 %bins-to-cache] (bins-to-cache:build keys.lode bins))
  =/  sut-hash=@uv   ~>(%bout.[1 %build-sut-hash] (sham q:sut))
  =/  skp            ~>(%bout.[1 %build-skip-set] (skip-set cod lode changed sut-hash))
  =/  res            ~>(%bout.[1 %build-all] (build-inc:build sut sut-hash src-ball old-cache skp))
  ~&  >  "build-code: compiled {<~(wyt by results.res)>} results"
  ::  3. Index: compute output ckeys, build keys/refs/builds
  ::
  =/  [new-keys=keys:nexus new-refs=refs:nexus builds=(map @uv built:nexus)]
      ~>(%bout.[1 %index-results] (index-results res lode src-ball))
  ::  4. Update bins: increment new refs, decrement old
  ::
  =.  bins  ~>(%bout.[1 %refs-inc] (refs-inc new-refs builds))
  =.  bins  ~>(%bout.[1 %refs-dec] (refs-dec old-refs))
  ::  5. GC vale cache: drop entries whose marc was removed
  ::
  =.  vale  (gc-vale-cache vale bins)
  ::  6. Store lode — with the subject sentinel, so a later
  ::  incremental build can prove the subject hasn't changed
  ::  since these keys were computed (agent upgrades change sut)
  ::
  =.  lode  [(~(put by new-keys) sut-rail [sut-hash sut-hash]) deps.res new-refs]
  =.  code  (~(put by code) cod lode)
  ::  7. Validate marks: re-clam grubs through changed marks
  ::
  =^  new-refs  this
    ~>(%bout.[1 %validate-marks] (validate-marks cod old-refs new-refs))
  =.  code
    =/  upd=lode:nexus  (fall (~(get by code) cod) *lode:nexus)
    (~(put by code) cod upd(refs new-refs))
  ::  8. Reload nexuses whose compiled code changed
  ::
  =.  this
    ~>(%bout.[1 %reload-changed-nexuses] (reload-changed-nexuses cod old-refs new-refs))
  ~&  >  "build-code: done"
  this
::  Force foundational mark sources into born and the src-ball.
::  Overwrites any user modifications; these marks are immutable.
::
++  force-foundational-marks
  |=  [cod=path src-ball=ball:tarball]
  ^-  [ball:tarball _this]
  =/  pax=path  /(scot %p our.bowl)/grubbery/(scot %da now.bowl)
  %+  roll  `(list @ta)`~[%hoon %tang %mime %kelvin]
  |=  [nam=@ta [acc=_src-ball sat=_this]]
  =/  src=vase  .^(vase %cr (weld pax /gub/mar/[nam]/hoon))
  =/  val=(each vase tang)  (validate-noun:sat cod [/ %hoon] q.src)
  ?.  ?=(%& -.val)  [acc sat]
  =/  dest=rail:tarball  [(weld cod /mar) (cat 3 nam '.hoon')]
  =/  =sang:tarball  [[/ %hoon] %& p.val]
  ::  write to born (record skips if unchanged)
  =.  sat  ?^((get-born:sat dest) sat (init-born:sat dest))
  =.  sat  (record:sat dest [[/ %hoon] q.src] %.n ~)
  ::  inject into src-ball
  [(~(put ba:tarball acc) [/mar (cat 3 nam '.hoon')] sang) sat]
::
++  index-results
  |=  [res=build-out:build =lode:nexus src-ball=ball:tarball]
  ^-  [keys:nexus refs:nexus (map @uv built:nexus)]
  =/  all-files=(list [=rail:tarball =sang:tarball])
    ~(tap ba:tarball src-ball)
  ::  Seed with mime files
  =/  mime-files=(list [=rail:tarball =sang:tarball])
    (skim all-files |=([* =sang:tarball] =([/ %mime] p.sang)))
  =/  [refs=refs:nexus builds=(map @uv built:nexus)]
    %+  roll  mime-files
    |=  [[=rail:tarball =sang:tarball] [acc=refs:nexus bld=(map @uv built:nexus)]]
    =/  =mime  !<(mime (need-vase:tarball sang))
    =/  =built:nexus  [%mime mime]
    =/  ckey=@uv  (~(got by keys.res) rail)
    =/  node=(map @ta @uv)
      (fall (~(get of acc) path.rail) *(map @ta @uv))
    [(~(put of acc) path.rail (~(put by node) name.rail ckey)) (~(put by bld) ckey built)]
  ::  Add compiled hoon results
  =/  [new-keys=keys:nexus refs=_refs builds=_builds]
    %+  roll  ~(tap by results.res)
    |=  $:  [=rail:tarball =build-result:build]
            [kz=keys:nexus acc=_refs bld=_builds]
        ==
    ::  skip mimes — already handled in mime-files loop above
    =/  sang=(unit sang:tarball)  (~(get ba:tarball src-ball) rail)
    ?:  ?&(?=(^ sang) =([/ %mime] p.u.sang))
      [kz acc bld]
    =/  stem=@ta  (strip-hoon:build name.rail)
    =/  =built:nexus
      ?:  ?=(%| -.build-result)
        ~&  >>  "WARNING {(spud (snoc path.rail name.rail))} did not compile"
        [%tang p.build-result]
      =/  val-err=(unit tang)  (validate-build rail p.build-result)
      ?^  val-err
        ~&  >>  "validate-build failed: {(spud (snoc path.rail name.rail))}"
        [%tang u.val-err]
      ::  TODO: consider extracting the marc or nexus here and storing it as its
      ::  own type instead of a raw vase, so readers don't !< it on every read.
      ::  bootstrap-marcs already does this for the foundational marks.
      [%vase p.build-result]
    =/  in-ckey=@uv  (~(got by keys.res) rail)
    =/  out-ckey=@uv  in-ckey
    =/  node=(map @ta @uv)
      (fall (~(get of acc) path.rail) *(map @ta @uv))
    :+  (~(put by kz) rail [in-ckey out-ckey])
      (~(put of acc) path.rail (~(put by node) stem out-ckey))
    (~(put by bld) out-ckey built)
  [new-keys refs builds]
::
++  gc-vale-cache
  |=  [=vale:nexus =bins:nexus]
  ^-  vale:nexus
  %-  ~(gas by *vale:nexus)
  %+  skip  ~(tap by vale)
  |=  [[lob=nobe:nexus ckey=@uv] *]
  ::  drop if mark was removed or lobe was tombstoned from silo
  |(!(~(has by bins) ckey) !(~(has by nouns.silo) lob))
::  Look up the leaf ject a hist entry points at, if any.
::
++  hist-leaf
  |=  [sok=hist:nexus cas=cass:clay]
  ^-  (unit leaf:nexus)
  =/  pv=(unit pace:hist:nexus)  (get-pace:hist:nexus sok cas)
  ?~  pv  ~
  ?:  ?=(%tomb -.u.pv)  ~
  ?~  p.u.pv  ~
  =/  got  (~(get by jects.silo) u.p.u.pv)
  ?~  got  ~
  ?.  ?=(%leaf -.ject.u.got)  ~
  `leaf.ject.u.got
::  Incremental vale GC for the record/delete hot path: when a
::  replaced or tombed leaf's noun no longer lives in the silo,
::  drop just its cache entry. O(log V) instead of the full sweep,
::  which stays at the sites where lobes die in bulk (drop-hist,
::  snap release, build-code).
::
::  NB: precise eviction covers the record/delete path only. Entries
::  orphaned indirectly (bang-noun ref cascades, the same content
::  cached under a second mark) persist until a bulk-sweep site runs,
::  so vale can leak slowly on a quiet ship. If that ever matters,
::  add an opportunistic full sweep at commit/snap — or size-cap and
::  clear the whole map, since every entry rebuilds lazily on miss
::  and staleness is impossible (keys are content-addressed).
::
++  gc-vale-prev
  |=  prev=(unit leaf:nexus)
  ^-  vale:nexus
  ?~  prev  vale
  ?:  (~(has by nouns.silo) lobe.u.prev)  vale
  (~(del by vale) [lobe.u.prev ckey.mark.u.prev])
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
  ^-  (list [=rail:tarball =sang:tarball lob=jobe:nexus])
  =/  dirs=(list [=fold:tarball =lump:tarball])  (governed-dirs cod)
  %-  zing
  %+  turn  dirs
  |=  [=fold:tarball =lump:tarball]
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  =/  sk=(unit hist:nexus)  (~(get bo:nexus now.bowl born) [fold name])
  ?~  sk  ~
  =/  top=(unit [key=cass:clay val=entry:hist:nexus])  (ram:hon:hist:nexus u.sk)
  ?~  top  ~
  ?:  ?=(%tomb -.pace.val.u.top)  ~
  ?~  p.pace.val.u.top  ~
  `[[fold name] sang u.p.pace.val.u.top]
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
  ::  Collect all grubs whose mark.ns = this code namespace
  =/  all-grubs=(list [=rail:tarball lob=jobe:nexus =leaf:nexus])
    %-  zing
    %+  turn  ~(tap of born)
    |=  [fold=path node=[fold=hist:nexus file=(map @ta hist:nexus)]]
    %+  murn  ~(tap by file.node)
    |=  [name=@ta sk=hist:nexus]
    =/  top=(unit [key=cass:clay val=entry:hist:nexus])
      (ram:hon:hist:nexus sk)
    ?~  top  ~
    ?:  ?=(%tomb -.pace.val.u.top)  ~
    ?~  p.pace.val.u.top  ~
    =/  entry  (~(get by jects.silo) u.p.pace.val.u.top)
    ?~  entry  ~
    ?.  ?=(%leaf -.ject.u.entry)  ~
    ?.  =(cod ns.mark.leaf.ject.u.entry)  ~
    `[[fold name] u.p.pace.val.u.top leaf.ject.u.entry]
  ::  Process each changed mark
  =/  remaining=_changed  changed
  |-
  ?~  remaining  [new-refs this]
  =/  [ckey=@uv =blot:tarball =built:nexus]  i.remaining
  =/  nam=@tas  (rail-to-arm:tarball blot)
  ::  Skip foundational marks -- re-validating all .hoon/.mime/etc
  ::  files through them would cascade into build-code loops.
  ?:  ?=(?(%hoon %tang %mime %kelvin) nam)
    $(remaining t.remaining)
  ::  Find all grubs with this mark
  =/  grubs=(list [=rail:tarball lob=jobe:nexus =leaf:nexus])
    %+  skim  all-grubs
    |=  [=rail:tarball lob=jobe:nexus =leaf:nexus]
    =(blot blot.mark.leaf)
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
  =/  grubs=(list [=rail:tarball lob=jobe:nexus =leaf:nexus])  grubs
  =/  [n-ok=@ud n-boom=@ud]  [0 0]
  =.  this
    |-
    ?~  grubs  this
    =/  [=rail:tarball lob=jobe:nexus =leaf:nexus]  i.grubs
    =/  noun=*  noun:(~(got by nouns.silo) lobe.leaf)
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
      =.  this  (save-file rail [blot.mark.leaf noun])
      =.  n-ok  +(n-ok)
      $(grubs t.grubs)
    ~&  >>  "validate-marks: boom {(spud (snoc path.rail name.rail))}"
    %-  (slog p.res)
    =.  this
      (save-file rail [blot noun])
    =.  n-boom  +(n-boom)
    $(grubs t.grubs)
  ~&  >  "validate-marks: {(trip nam)} — {<n-ok>} ok, {<n-boom>} boom"
  $(remaining t.remaining)
::
++  revalidate-all
  ^+  this
  ~&  >  "revalidate-all: start"
  =/  all-grubs=(list [=rail:tarball lob=jobe:nexus =leaf:nexus])
    %-  zing
    %+  turn  ~(tap of born)
    |=  [fold=path node=[fold=hist:nexus file=(map @ta hist:nexus)]]
    %+  murn  ~(tap by file.node)
    |=  [name=@ta sk=hist:nexus]
    =/  top=(unit [key=cass:clay val=entry:hist:nexus])
      (ram:hon:hist:nexus sk)
    ?~  top  ~
    ?:  ?=(%tomb -.pace.val.u.top)  ~
    ?~  p.pace.val.u.top  ~
    =/  entry  (~(get by jects.silo) u.p.pace.val.u.top)
    ?~  entry  ~
    ?.  ?=(%leaf -.ject.u.entry)  ~
    `[[fold name] u.p.pace.val.u.top leaf.ject.u.entry]
  ~&  >  "revalidate-all: {<(lent all-grubs)>} grubs"
  =/  [n-ok=@ud n-boom=@ud n-skip=@ud]  [0 0 0]
  |-
  ?~  all-grubs
    ~&  >  "revalidate-all: done — {<n-ok>} ok, {<n-boom>} boom, {<n-skip>} skip"
    this
  =/  [=rail:tarball lob=jobe:nexus =leaf:nexus]  i.all-grubs
  =/  nam=@tas  (rail-to-arm:tarball blot.mark.leaf)
  ?:  ?=(?(%hoon %tang %mime %kelvin) nam)
    $(all-grubs t.all-grubs, n-skip +(n-skip))
  =/  cod=path  ns.mark.leaf
  =/  mark-refs=refs:nexus
    =/  cod-lode=(unit lode:nexus)  (~(get by code) cod)
    ?~  cod-lode  *refs:nexus
    refs.u.cod-lode
  =/  mark-ckey=(unit @uv)
    =/  node=(unit (map @ta @uv))  (~(get of mark-refs) (weld /mar path.blot.mark.leaf))
    ?~  node  ~
    (~(get by u.node) name.blot.mark.leaf)
  ?~  mark-ckey
    ~&  >>  "revalidate-all: no ckey for {(spud (snoc path.blot.mark.leaf name.blot.mark.leaf))}"
    $(all-grubs t.all-grubs, n-skip +(n-skip))
  =/  bin-entry=(unit [refs=@ud =built:nexus])  (~(get by bins) u.mark-ckey)
  ?~  bin-entry
    ~&  >>  "revalidate-all: no bin for {(trip nam)}"
    $(all-grubs t.all-grubs, n-skip +(n-skip))
  =/  marc-res=(each marc:tarball tang)
    ?.  ?=(%vase -.built.u.bin-entry)
      |+~[leaf+"revalidate-all: {(trip nam)} not a vase"]
    (mule |.(!<(marc:tarball vase.built.u.bin-entry)))
  ?:  ?=(%| -.marc-res)
    ~&  >>  "revalidate-all: marc failed for {(trip nam)}"
    $(all-grubs t.all-grubs, n-skip +(n-skip))
  =/  noun=*  noun:(~(got by nouns.silo) lobe.leaf)
  =/  res=(each vase tang)
    =/  val  (validate-vase vale:p.marc-res noun)
    ?:(?=(%| -.val) val &+[type:p.marc-res noun])
  =.  this  (vale-put lob u.mark-ckey ?:(?=(%& -.res) ~ `p.res))
  ?:  ?=(%& -.res)
    =.  this  (save-file rail [blot.mark.leaf noun])
    $(all-grubs t.all-grubs, n-ok +(n-ok))
  ~&  >>  "revalidate-all: boom {(spud (snoc path.rail name.rail))}"
  %-  (slog p.res)
  =.  this  (save-file rail [blot.mark.leaf noun])
  $(all-grubs t.all-grubs, n-boom +(n-boom))
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
  ::  Find all directories using this neck, whose nek.ns = this namespace
  =/  dirs=(list fold:tarball)
    %+  murn  ~(tap of born)
    |=  [pax=path node=[fold=hist:nexus file=(map @ta hist:nexus)]]
    =/  top=(unit [key=cass:clay val=entry:hist:nexus])
      (ram:hon:hist:nexus fold.node)
    ?~  top  ~
    ?:  ?=(%tomb -.pace.val.u.top)  ~
    ?~  p.pace.val.u.top  ~
    =/  entry  (~(get by jects.silo) u.p.pace.val.u.top)
    ?~  entry  ~
    ?.  ?=(%tree -.ject.u.entry)  ~
    ?~  nek.tree.ject.u.entry  ~
    ?.  =(cod ns.u.nek.tree.ject.u.entry)  ~
    ?.  =(neck neck.u.nek.tree.ject.u.entry)  ~
    `pax
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
  ~&  >  "reload-changed-nexuses: reload-nexus-at start"
  =.  this  (reload-nexus-at dest p.nex-res)
  ~&  >  "reload-changed-nexuses: reload-nexus-at done"
  =/  reload-bole  (peek-bole-now dest)
  ~&  >  "reload-changed-nexuses: spawn-all-files start"
  =.  this  (spawn-all-files dest reload-bole)
  ~&  >  "reload-changed-nexuses: spawn-all-files done"
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
::  +gub-ball: build the /code ball from the desk's /gub files
::
::    Reads every file under /gub in the desk at pax and translates
::    each into a grub, restoring the dotted filename clay split
::    apart: /lib/foo/hoon becomes foo.hoon under /lib. A .hoon file
::    is stored under the hoon mark, sys.kelvin under the kelvin mark
::    at the root, and any other file is converted to mime through a
::    clay tube. Files that fail validation are reported and skipped.
::
++  gub-ball
  |=  pax=path
  ^-  ball:tarball
  =/  files=(list path)  .^((list path) %ct (weld pax /gub))
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
::  +sync-gub: mirror /gub/ from clay into /code/, then build
::
++  sync-gub
  ^+  this
  ~&  >  "sync-gub: start"
  =/  pax=path  /(scot %p our.bowl)/grubbery/(scot %da now.bowl)
  ::  Build the target ball for /code/ (see +gub-ball)
  =/  new-src=ball:tarball  (gub-ball pax)
  ::  Ensure %code neck on the source ball
  =/  src-lump=lump:tarball  (fall fil.new-src *lump:tarball)
  =.  new-src  new-src(fil `src-lump(neck `[/ %code]))
  ::  Get old ball at /code/
  =/  old-src  (peek-ball-now /code)
  ::  Diff and bump src changes (born, silo, hist, notify)
  ~&  >  "sync-gub: load-ball-changes start"
  =.  this  (load-ball-changes /code (ball-to-bole:tarball new-src))
  ~&  >  "sync-gub: load-ball-changes done"
  ::  Compile — changed set is the ball diff, absolutized to /code
  ~&  >  "sync-gub: build-code start"
  =/  diff=(set rail:tarball)
    %-  ~(run in (ball-diff old-src new-src))
    |=(r=rail:tarball `rail:tarball`[(weld /code path.r) name.r])
  ~&  >  "sync-gub: {<~(wyt in diff)>} changed rails"
  =.  this  (build-code /code `diff)
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
  =.  this  (save-file [/sys/dill %'logs.dill-told'] [[/ %dill-told] *told:dill])
  =.  this  (set-gain-lane [%& /sys/dill %'logs.dill-told'] %.y)
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
    =/  acc  (save-file:acc [/sys/dill/sessions ses] [[/ %dill-blit] *(list blit:dill)])
    (set-gain-lane:acc [%& /sys/dill/sessions ses] %.y)
  %-  emit-cards
  %+  turn  sessions
  |=(ses=@tas [%pass /dill/session/[ses] %arvo %d %shot ses %view ~])
::  +sync-jael: mirror our keys into /sys/jael and subscribe to jael
::
++  sync-jael
  ^+  this
  ::  Ensure jael directory exists (properly tracked via load-ball-changes)
  =.  this  (ensure-dir /sys/jael)
  ::  Create grubs and subscribe
  =.  this
    (save-file [/sys/jael %'private-keys.jael-private-keys'] [[/ %jael-private-keys] *[life (map life ring)]])
  =.  this
    (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [[/ %jael-public-keys-result] *public-keys-result:jael])
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
  (save-file [/sys/jael %'public-keys.jael-public-keys-result'] [[/ %jael-public-keys-result] public-keys-result])
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
::  ============================ TODO ============================
::  !!  GAIN GALL SUBSCRIPTION GRUBS  !!
::  The materialized sub state under /sys/gall/subs/<ship>/<agent>/<path>/
::  (`live` + `data`) is NOT gained, so the self-clean/tomb GC can tomb it
::  WHILE THE SUBSCRIPTION IS STILL LIVE. Gain these grubs (%.y) for as long
::  as the sub is alive, so they persist as long as the sub does. Open q:
::  clear them on reboot if the sub itself doesn't survive a reboot.
::  =============================================================
::
++  gall-sub
  |=  [=ship agent=dude:gall =path]
  ^+  this
  =/  dir=^path  (gall-sub-dir ship agent path)
  =/  wir=wire   (gall-sub-wire ship agent path)
  ::  Ensure directory exists
  =.  this  (ensure-dir dir)
  ::  Create live file (%.y = subscribing)
  =.  this  (save-file [dir %live] [[/ %loob] %.y])
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
      (save-file [dir %live] [[/ %loob] %.y])
    ::  Failed — set live to %.n, don't retry
    ~&  >>>  "gall-sub: watch-ack failed {<ship>}/{(trip agent)}/{(spud path)}"
    %-  (slog u.p.sign)
    (save-file [dir %live] [[/ %loob] %.n])
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
      (save-file [dir %data] [[/ %page] `[p=@tas q=*]`[mar q.q.cage.sign]])
    =/  res=(each vase tang)
      (validate-vase u.vale q.q.cage.sign)
    ?.  ?=(%& -.res)
      ~&  >>>  "gall-sub: vale failed for {<mar>}"
      this
    (save-file [dir %data] [[/ mar] q.p.res])
  ::
      %kick
    ::  Set live to %.n, auto-resubscribe
    ~&  >  "gall-sub: kicked from {<ship>}/{(trip agent)}/{(spud path)}, resubscribing"
    =.  this  (save-file [dir %live] [[/ %loob] %.n])
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
::  /sys/lick: local IPC ports (lick vane; unix sockets under .urb/dev/)
::
::    - A nexus opens a port by poking /sys/lick with blot [/ %lick-spin]
::      and a path payload; vere serves the socket at
::      <pier>/.urb/dev/grubbery/<name> (agent dir + port path, verbatim).
::    - Inbound %soak messages are materialized at /sys/lick/<name>/in as
::      [seq=@ud =mark noun=*]. seq increments per message so identical
::      payloads still fire a wave. Connection state (%connect/%disconnect
::      soaks from the runtime) lives at /sys/lick/<name>/live as a loobean.
::    - Outbound: blot [/ %lick-spit] with [name mark noun] payload.
::      Blot [/ %lick-shut] closes the port and deletes its tree.
::    - Ports are respun from the tree on reload (sync-lick); the vane
::      itself re-registers sockets with vere on %born.
::    - /live is advisory: %connect/%disconnect are ordinary soak marks,
::      so a local client could spoof them. The socket is same-user-only
::      (unix perms), so this is a footgun note, not a security boundary.
::    - Runtime port errors (%error soaks) persist at /sys/lick/<name>/err.
::
++  lick-dir
  |=  name=path
  ^-  path
  (weld /sys/lick name)
::
++  lick-wire
  |=  name=path
  ^-  wire
  (weld /lick name)
::
++  handle-lick-spin
  |=  [name=path gained=?]
  ^+  this
  ?~  name
    ~&  >>>  "lick: refusing to spin empty port name"
    this
  =/  dir=path  (lick-dir name)
  =.  this  (ensure-dir dir)
  =.  this
    ?^  (peek-grub-now dir %live)  this
    (save-file [dir %live] [[/ %loob] %.n])
  =?  this  gained
    (set-gain-lane [%& dir %in] %.y)
  ~&  >  "lick: spinning {(spud name)}"
  (emit-card [%pass (lick-wire name) %arvo %l %spin name])
::
++  handle-lick-shut
  |=  name=path
  ^+  this
  =/  dir=path  (lick-dir name)
  ~&  >  "lick: shutting {(spud name)}"
  =.  this  (emit-card [%pass (lick-wire name) %arvo %l %shut name])
  =.  pool  (~(lop of pool) dir)
  (load-ball-changes dir *bole:tarball)
::
++  handle-lick-spit
  |=  req=[name=path =mark noun=*]
  ^+  this
  (emit-card [%pass (lick-wire name.req) %arvo %l %spit req])
::  Handle a %soak gift: connection state to /live, data to /in
::
++  take-lick-soak
  |=  [name=path =mark noun=*]
  ^+  this
  =/  dir=path  (lick-dir name)
  ::  drop soaks for ports we no longer track (tree culled or shut):
  ::  save-file would silently resurrect a half-tree otherwise, and the
  ::  socket keeps producing events regardless of tree state.
  ?:  ?=(~ (peek-grub-now dir %live))
    ~&  >>  "lick: dropping soak for unknown port {(spud name)}"
    this
  ?:  =(%connect mark)
    (save-file [dir %live] [[/ %loob] %.y])
  ?:  =(%disconnect mark)
    (save-file [dir %live] [[/ %loob] %.n])
  ?:  =(%error mark)
    ~&  >>>  "lick: error on {(spud name)}: {<noun>}"
    (save-file [dir %err] [[/ %page] `[p=@tas q=*]`[%error noun]])
  ::  data message: bump seq so equal payloads still fire a wave
  =/  old=(unit sang:tarball)  (peek-grub-now dir %in)
  =/  seq=@ud
    ?~  old  0
    =/  prev  !<([seq=@ud @tas *] (need-vase:tarball u.old))
    +(seq.prev)
  (save-file [dir %in] [[/ %lick-in] [seq mark noun]])
::  Respin all recorded ports on reload
::
++  sync-lick
  ^+  this
  =.  this  (ensure-dir /sys/lick)
  (respin-lick-tree / (peek-ball-now /sys/lick))
::
++  respin-lick-tree
  |=  [pax=path sub=ball:tarball]
  ^+  this
  =/  has-live=?
    ?&  ?=(^ fil.sub)
        (~(has by contents.u.fil.sub) %live)
    ==
  ::  no /live reset here: the socket (and its client) survive agent
  ::  reloads in vere, so no new %connect would arrive to undo a forced
  ::  %.n. %connect/%disconnect soaks own /live.
  =.  this
    ?.  has-live  this
    ~&  >  "sync-lick: respinning {(spud pax)}"
    (emit-card [%pass (lick-wire pax) %arvo %l %spin pax])
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.sub)
  |-
  ?~  kids  this
  =.  this  ^$(pax (snoc pax -.i.kids), sub +.i.kids)
  $(kids t.kids)
::  +sync-bowl: reset bowl service state and ensure /sys/bowl.sig
::
++  sync-bowl
  ^+  this
  =.  last  [now=now.bowl eny=eny.bowl]
  =?  this  =(~ (peek-grub-now [/sys %'bowl.sig']))
    (save-file [/sys %'bowl.sig'] [[/ %sig] ~])
  this
::  +sync-peer: create the /sys/ames peer infrastructure
::
::    Creates the /sys/ames/ directory structure for foreign ship
::    management. Usergroups are .grp directories under
::    /sys/ames/usergroups/ with who.ships and how.weir files. Groups
::    can be nested in namespaces, for example
::    /sys/ames/usergroups/contacts/friends.grp/. Ship directories
::    are created lazily on first foreign poke. Weirs recompute
::    atomically on any usergroup change.
::
++  sync-peer
  ^+  this
  =.  this  (ensure-dir /sys/ames)
  =.  this  (ensure-dir /sys/ames/usergroups)
  =.  this  (ensure-dir /sys/ames/ships)
  ::  Ensure usergroups registry exists
  =/  reg-rail=rail:tarball  [/sys/ames %'registry']
  =?  this  =(~ (peek-grub-now reg-rail))
    (save-file reg-rail [[/usergroups %registry] *(map rail:tarball path)])
  =.  this  ensure-public-group
  (ensure-peer-ship our.bowl)
::  Ensure /sys/ames/usergroups/public.grp/ exists with who.ships and how.weir.
::  The public group's weir applies to all foreign ships regardless of membership.
::
++  ensure-public-group
  ^+  this
  =/  pub-dir=path  (grp-storage-path /public)
  =/  who-rail=rail:tarball  [pub-dir %'who.ships']
  =/  how-rail=rail:tarball  [pub-dir %'how.weir']
  =/  man-rail=rail:tarball  [pub-dir %'man.md']
  =.  this  (ensure-dir pub-dir)
  =?  this  =(~ (~(get bo:nexus now.bowl born) pub-dir %'who.ships'))
    (save-file who-rail [[/ %ships] *(set @p)])
  =?  this  =(~ (~(get bo:nexus now.bowl born) pub-dir %'how.weir'))
    (save-file how-rail [[/ %weir] *weir:nexus])
  =?  this  =(~ (~(get bo:nexus now.bowl born) pub-dir %'man.md'))
    =/  default-man=mime
      :-  /text/markdown
      %-  as-octs:mimes:html
      ^-  @t
      '''
      # Public

      The default usergroup for all foreign ships. Every ship that connects to this grubbery is automatically a member of the public group.

      ## Permissions

      The public group's weir controls what unauthenticated or unrecognized ships can do:

      - **make** — create files or directories
      - **poke** — send actions to running processes
      - **peek** — read files and directories

      Each permission is a set of path prefixes. A request is allowed if its destination matches any prefix in the relevant set. An empty set means that category is blocked.
      '''
    (save-file man-rail [[/ %mime] default-man])
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
    =.  this  (save-file ship-rail [[/ %sig] ~])
    (spawn-proc ship-rail ~)
  ::  Set weir (our ship gets none — full access)
  ?:  =(src our.bowl)  this
  =/  =weir:nexus  (compute-peer-weir src)
  =.  this  (set-weir ship-dir `weir)
  ::  Aggregate man pages from this ship's usergroups
  (sync-peer-man src ship-dir)
::  Copy man pages from this ship's usergroups into /man/ under its dir.
::
++  sync-peer-man
  |=  [src=@p ship-dir=path]
  ^+  this
  =/  man=(map path mime)  read-peer-man
  =/  who=(map path (set @p))  read-peer-who
  =/  peer-src=(map @p (set path))  (build-peer-src who)
  =/  ship-groups=(set path)
    %-  ~(uni in (fall (~(get by peer-src) src) *(set path)))
    (~(gas in *(set path)) ~[/public])
  =/  man-dir=path  (weld ship-dir /man)
  =.  this  (ensure-dir man-dir)
  %+  roll  ~(tap in ship-groups)
  |=  [grp=path sat=_this]
  =/  grp-man=(unit mime)  (~(get by man) grp)
  ?~  grp-man  sat
  ?~  grp  sat
  (save-file:sat [man-dir (cat 3 (rear grp) '.md')] [[/ %mime] u.grp-man])
::  Usergroup helpers: .grp directory convention
::
::  Groups live under /sys/ames/usergroups/ and are identified by path
::  (e.g. /public, /contacts/friends). Storage directories use a .grp
::  suffix on the last segment to mark group boundaries.
::
++  grp-dir-name
  |=  name=@ta
  ^-  @ta
  (cat 3 name '.grp')
::
++  grp-storage-path
  |=  grp=path
  ^-  path
  ?~  grp  /sys/ames/usergroups
  %+  weld  /sys/ames/usergroups
  (snoc (snip `path`grp) (grp-dir-name (rear grp)))
::
++  is-grp-name
  |=  name=@ta
  ^-  ?
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?&  (gte len 5)
      =(".grp" (slag (sub len 4) t))
  ==
::
++  strip-grp-suffix
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  (crip (scag (sub (lent t) 4) t))
::  Recursively find all .grp directories in a ball.
::  Returns [group-path group-ball] pairs.
::
++  find-groups
  |=  [pax=path ug=ball:tarball]
  ^-  (list [name=path grp=ball:tarball])
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ug)
  =|  acc=(list [name=path grp=ball:tarball])
  |-
  ?~  kids  acc
  =/  [kid-name=@ta kid=ball:tarball]  i.kids
  ?:  (is-grp-name kid-name)
    $(kids t.kids, acc [[(snoc pax (strip-grp-suffix kid-name)) kid] acc])
  $(kids t.kids, acc (weld acc ^$(pax (snoc pax kid-name), ug kid)))
::
++  read-peer-who
  ^-  (map path (set @p))
  =/  ug=ball:tarball
    (peek-ball-now /sys/ames/usergroups)
  =/  groups=(list [name=path grp=ball:tarball])  (find-groups / ug)
  %-  ~(gas by *(map path (set @p)))
  %+  murn  groups
  |=  [name=path grp=ball:tarball]
  ^-  (unit [path (set @p)])
  =/  c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'who.ships'])
  ?~  c  ~
  =/  res  (mule |.(!<((set @p) (need-vase:tarball u.c))))
  ?:(?=(%| -.res) ~ `[name p.res])
::
++  read-peer-how
  ^-  (map path weir:nexus)
  =/  ug=ball:tarball
    (peek-ball-now /sys/ames/usergroups)
  =/  groups=(list [name=path grp=ball:tarball])  (find-groups / ug)
  %-  ~(gas by *(map path weir:nexus))
  %+  murn  groups
  |=  [name=path grp=ball:tarball]
  ^-  (unit [path weir:nexus])
  =/  c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'how.weir'])
  ?~  c  ~
  =/  res  (mule |.(!<(weir:nexus (need-vase:tarball u.c))))
  ?:(?=(%| -.res) ~ `[name p.res])
::
++  read-peer-man
  ^-  (map path mime)
  =/  ug=ball:tarball
    (peek-ball-now /sys/ames/usergroups)
  =/  groups=(list [name=path grp=ball:tarball])  (find-groups / ug)
  %-  ~(gas by *(map path mime))
  %+  murn  groups
  |=  [name=path grp=ball:tarball]
  ^-  (unit [path mime])
  =/  c=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'man.md'])
  ?~  c  ~
  =/  res  (mule |.(!<(mime (need-vase:tarball u.c))))
  ?:(?=(%| -.res) ~ `[name p.res])
::  Build reverse index: ship → group paths
::
++  build-peer-src
  |=  who=(map path (set @p))
  ^-  (map @p (set path))
  =/  groups=(list [path (set @p)])  ~(tap by who)
  =|  acc=(map @p (set path))
  |-
  ?~  groups  acc
  =/  [name=path members=(set @p)]  i.groups
  =/  ships=(list @p)  ~(tap in members)
  =.  acc
    |-
    ?~  ships  acc
    =/  existing=(set path)  (fall (~(get by acc) i.ships) ~)
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
  =/  who=(map path (set @p))  read-peer-who
  =/  how=(map path weir:nexus)  read-peer-how
  (compute-peer-weir-from ship (build-peer-src who) how)
::
++  compute-peer-weir-from
  |=  [=ship src=(map @p (set path)) how=(map path weir:nexus)]
  ^-  weir:nexus
  =/  public-weir=weir:nexus
    (fall (~(get by how) /public) *weir:nexus)
  =/  ship-groups=(set path)
    (fall (~(get by src) ship) ~)
  =/  ship-weir=weir:nexus
    %+  roll  ~(tap in ship-groups)
    |=  [name=path acc=weir:nexus]
    (union-weirs acc (fall (~(get by how) name) *weir:nexus))
  (union-weirs ship-weir public-weir)
::  /sys/eyre: ensure directory structure + register /grubbery/api
::
++  sync-eyre
  ^+  this
  ::  Ensure /sys/eyre directory structure exists
  =.  this  (ensure-dir /sys/eyre)
  =.  this  (ensure-dir /sys/eyre/requests)
  ::  Register /grubbery/api and /grubbery/push, and reconcile every
  ::  binding in server-state with eyre — eyre's table and ours can
  ::  drift (nukes, rejected connects), and ours is authoritative.
  =/  st=server-state:nexus  get-server-state
  %-  emit-cards
  %+  weld
    ^-  (list card)
    :~  [%pass /eyre-api %arvo %e %connect [~ /grubbery/api] dap.bowl]
        [%pass /eyre-push %arvo %e %connect [~ /grubbery/push] dap.bowl]
    ==
  ^-  (list card)
  %+  turn  ~(tap by bindings.st)
  |=  [=binding:eyre *]
  ^-  card
  [%pass /eyre-bind %arvo %e %connect binding dap.bowl]
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
  ::  TODO: conns is transient per-request bookkeeping but this records it to
  ::  the grub. Consider moving conns to agent state to avoid the write.
  ::  bindings are authoritative and stay in the namespace.
  (save-file [/sys/eyre %'main.server-state'] [[/ %server-state] st])
::  cancel-http: a client dropped an http subscription — cancel its in-flight
::  request. no binding means it was a ball-API request (cull the request
::  fiber); a bound request is dropped from conns and its handler told to cancel.
::
++  cancel-http
  |=  eyre-id=@ta
  ^+  this
  =/  st=server-state:nexus  get-server-state
  =/  conn-binding=(unit binding:eyre)  (~(get by conns.st) eyre-id)
  ?~  conn-binding
    (cull-if-exists [%& /sys/eyre/requests eyre-id])
  =/  new-st  st(conns (~(del by conns.st) eyre-id))
  =/  handler=rail:tarball
    (fall (~(get by bindings.new-st) u.conn-binding) *rail:tarball)
  (poke:(save-server-state new-st) ~ handler [[/ %handle-http-cancel] eyre-id])
::  route-http: dispatch an inbound eyre request by URL.
::  /grubbery/push is the notification endpoint.
::  /grubbery/api spawns a ball-API request fiber.
::  any other path is matched against the eyre bindings.
::
++  route-http
  |=  [eyre-id=@ta req=inbound-request:eyre]
  ^+  this
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  ?+    site
    (forward-http eyre-id req site)
    ::
      [%grubbery %push *]
    (handle-push-http eyre-id src.bowl req t.t.site args)
    ::
      [%grubbery %api *]
    ::  ARCHITECTURAL RULE: a request enters the namespace (materializes
    ::  as a grub in /sys/eyre/requests, spawning a fiber) ONLY if it
    ::  needs a general-purpose ASYNCHRONOUS script to handle it — one
    ::  that emits darts and awaits responses (writes, pokes, keep-SSE,
    ::  upload). A request answerable synchronously from current state —
    ::  every built-in read — is served inline here: no grub, no
    ::  make+cull cascade, no permanent event-log record per read.
    ::
    =/  handled=(unit (list card:agent:gall))
      (serve-api-read-sync eyre-id src.bowl req)
    ?^  handled
      (emit-cards u.handled)
    ::  needs a fiber: materialize the request grub as before
    (make /sys/eyre [%& /sys/eyre/requests eyre-id] %.n %.n [%| [[/ %http-request] [src.bowl req]] ~])
  ==
::  +serve-api-read-sync: answer a /grubbery/api request inline when it
::  is a pure read of current state. Returns [~ cards] when handled (the
::  response, or an error response), ~ when the request needs an async
::  fiber and route-http should +make the grub. Mirrors the read half of
::  +dispatch:ball-api, but synchronous — the peeks resolve from state
::  directly and the response is emitted with give-simple-payload rather
::  than routed up through a request fiber.
::
++  serve-api-read-sync
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  ^-  (unit (list card:agent:gall))
  =/  err
    |=  [code=@ud msg=@t]
    ^-  (unit (list card:agent:gall))
    `(give-simple-payload:app:server eyre-id [[code ~] `(as-octs:mimes:html msg)])
  =/  ok-payload
    |=  =simple-payload:http
    ^-  (unit (list card:agent:gall))
    `(give-simple-payload:app:server eyre-id simple-payload)
  =/  ok-mime
    |=  =mime
    (ok-payload (mime-response:http-utils mime))
  =/  ok-json
    |=  =json
    (ok-mime [/application/json (as-octs:mimes:html (en:json:html json))])
  ?.  =(src our.bowl)  (err 403 'Forbidden')
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  ?.  ?=([%grubbery %api @ *] site)  ~
  =/  endpoint=@tas  i.t.t.site
  =/  api-path=path  t.t.t.site
  ?+  [method.request.req endpoint]  ~   ::  ~ = not a sync read; needs a fiber
      [%'GET' %kids]
    =/  =ball:tarball  (peek-ball-now api-path)
    %-  ok-json
    %-  pairs:enjs:format
    :~  ['files' [%a (turn (~(lis ba:tarball ball) /) |=(n=@ta s+n))]]
        ['dirs' [%a (turn (~(lss ba:tarball ball) /) |=(n=@ta s+n))]]
    ==
  ::
      [%'GET' %tree]
    =/  =ball:tarball  (peek-ball-now api-path)
    (ok-json (tree-to-json:tarball (ball-to-tree:tarball ball)))
  ::
      [%'GET' %sand]
    =/  =ball:tarball  (peek-ball-now api-path)
    (ok-json (ball-weirs-to-json:nexus ball))
  ::
      [%'GET' %weir]
    =/  =ball:tarball  (peek-ball-now api-path)
    (ok-json (ball-weirs-to-json:nexus ball))
  ::
      [%'GET' %file]
    ?~  api-path  (err 400 'File path required')
    =/  dir=path  (snip `path`api-path)
    =/  name=@ta  (rear api-path)
    =/  content=(unit sang:tarball)  (peek-grub-now dir name)
    ?~  content  (err 404 'Not found')
    =/  =sage:tarball  [p.u.content (need-vase:tarball u.content)]
    ::  optional ?blot= conversion, then blot->mime, all synchronous via
    ::  get-tube (resolved from the grub's own governing code nexus)
    =/  blot-param=(unit @t)  (get-key:kv:html-utils 'blot' args)
    =/  target=blot:tarball
      ?~  blot-param  p.sage
      =/  tp=path  (stab u.blot-param)
      ?~(tp p.sage [(snip `path`tp) (rear tp)])
    =/  conv=(each sage:tarball tang)
      ?:  =(p.sage target)  &+sage
      (mule |.(`sage:tarball`[target ((get-tube dir [p.sage target]) q.sage)]))
    ?:  ?=(%| -.conv)  (err 400 'No tube for mark conversion')
    =/  cs=sage:tarball  p.conv
    ?:  =([/ %mime] p.cs)
      (ok-mime !<(mime q.cs))
    =/  mres=(each vase tang)
      (mule |.((`tube:clay`(get-tube dir [p.cs [/ %mime]]) q.cs)))
    ?:  ?=(%| -.mres)
      (ok-mime [/application/x-urb-jam (as-octs:mimes:html (jam q.cs))])
    (ok-mime !<(mime p.mres))
  ==
::  forward-http: match a request against the eyre bindings and hand it to the
::  bound handler, recording the connection; 404 if nothing matches.
::
++  forward-http
  |=  [eyre-id=@ta req=inbound-request:eyre site=path]
  ^+  this
  =/  st=server-state:nexus  get-server-state
  =/  match=(unit [=binding:eyre handler=rail:tarball])
    (find-eyre-binding bindings.st site)
  ?~  match
    ~&  >  [%eyre-no-binding site]
    ::  emit-cards (flop-correct) NOT a raw weld into `cards`, which is
    ::  reversed and flopped at abet — a raw weld ships the response
    ::  facts to eyre in the wrong order (data before header).
    (emit-cards (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')]))
  =/  new-st  st(conns (~(put by conns.st) eyre-id binding.u.match))
  (poke:(save-server-state new-st) ~ handler.u.match [[/ %handle-http-request] [eyre-id src.bowl req]])
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
  ?.  ?=(%| -.q.u.old)
    !<(push-state:nexus p.q.u.old)
  ~&  >>>  "get-push-state: push-state grub is boomed, using default"
  %-  (slog tang.p.q.u.old)
  *push-state:nexus
::
++  save-push-state
  |=  st=push-state:nexus
  ^+  this
  (save-file [/sys/push %'main.push-state'] [[/ %push-state] st])
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
    ~&  >>  ["%push send:" subs=~(wyt by subs.st) targets=(lent target-subs)]
    ::  Send to each subscription
    =/  unix-now=@ud  (div (sub now.bowl ~1970.1.1) ~s1)
    =/  exp=@ud  (add unix-now 86.400)
    |-
    ?~  target-subs  this
    =/  [sub-id=@ta ps=push-sub:nexus]  i.target-subs
    =/  sub=subscription:push  subscription.ps
    =/  req=request:http
      (send-notification:web-push sub config payload exp eny.act)
    ::  Build push wire: /push/send/{path-len}/{path...}/{name}/{sub-id}/{notif-id}
    ::  notif-id keeps concurrent sends to the same sub on distinct wires
    =/  notif-id=@ta  (scot %uv (end [3 8] (shax (cat 3 eny.act sub-id))))
    =/  push-wire=path
      :-  %push
      :-  %send
      :-  (scot %ud (lent path.sender))
      (weld path.sender [name.sender sub-id notif-id ~])
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
  ::  self-reporting: record the outcome where tools can read it
  =.  this
    %+  save-file  [/sys/push %'last-response.json']
    :-  [/ %json]
    ^-  json
    %-  pairs:enjs:format
    :~  ['at_ms' (numb:enjs:format (unm:chrono:userlib now.bowl))]
        :-  'outcome'
        ?.  ?=(%finished -.client-response)
          s+(crip "failed: {(trip -.client-response)}")
        (numb:enjs:format status-code.response-header.client-response)
    ==
  ::  If push service returns 404/410, subscription is stale — remove it
  ?:  ?=(%finished -.client-response)
    =/  code=@ud  status-code.response-header.client-response
    ~&  >>  ["%push response:" code]
    ?:  |(=(404 code) =(410 code))
      ::  Extract sub-id from wire (second-to-last segment, before notif-id)
      =/  sub-id=@ta  (rear (snip segs))
      =.  subs.st  (~(del by subs.st) sub-id)
      (save-push-state st)
    (save-push-state st)
  ~&  >>>  ["%push response: request failed" -.client-response]
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
          data: { url: data.url || '/grubbery/tiles' }
        };
        // a tag makes same-tag notifications silently REPLACE each
        // other with no new banner -- only tag if explicitly sent,
        // and renotify so replacements still alert
        if (data.tag) { options.tag = data.tag; options.renotify = true; }
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
    ?.  &(=(65 p.u.p256dh-octs) =(16 p.u.auth-octs))
      (respond [[400 ~] `(as-octs:mimes:html '"invalid key length"')])
    ::  Convert to MSB-first atoms (crypto convention)
    =/  p256dh-raw=@  (rev 3 p.u.p256dh-octs q.u.p256dh-octs)
    =/  auth-raw=@    (rev 3 p.u.auth-octs q.u.auth-octs)
    ::  Reject off-curve points now; deserialize-p256 asserts at send time
    ?~  (mole |.((deserialize-p256:web-push p256dh-raw)))
      (respond [[400 ~] `(as-octs:mimes:html '"invalid p256dh key"')])
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
  |=  [here=rail:tarball new-content=bask:tarball]
  ^+  this
  ::  Init born if needed
  =.  this  ?^((get-born here) this (init-born here))
  ::  Only bump if content actually changed
  =/  old=(unit sang:tarball)  (peek-grub-now here)
  ?:  ?&  ?=(^ old)
          =(p.u.old p.new-content)
          =(q.new-content (sang-noun:tarball u.old))
      ==
    this
  ::  record the new version, then propagate; preserve the gain flag
  =/  old-born=born:nexus  born
  =/  file-gain=?  (lookup-gain here)
  =.  this  (record here new-content file-gain ~)
  =.  this  (propagate old-born here)
  =/  cod=(unit path)
    =+  pax=path.here
    |-  ?:  (~(has by code) pax)  `pax
    ?~  pax  ~
    $(pax (snip `path`pax))
  =.  this
    ?~  cod  this
    (build-code u.cod `(sy `(list rail:tarball)`~[here]))
  this
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
  ?:  =(dest [/sys %'bowl.sig'])
    ?.  =([/ %bowl-req] p.sage)  ~
    =.  this  (handle-bowl-req here wir q.sage)
    `(enqu-take here ~ ~ %pack wir ~)
  ?.  ?=([%sys @ *] path.dest)  ~
  =/  service=@tas  i.t.path.dest
  ?+  service  ~
      %clay
    ?:  =([/ %mount-desk] p.sage)
      =/  dek=desk  !<(desk q.sage)
      =.  this  (handle-clay-mount dek)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %unmount-desk] p.sage)
      =/  dek=desk  !<(desk q.sage)
      =.  this  (handle-clay-unmount dek)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %new-desk] p.sage)
      =/  dek=desk  !<(desk q.sage)
      =.  this  (handle-clay-new-desk dek)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %clay-info] p.sage)
      =/  [dek=desk changes=(list [path ?([%ins @tas *] [%del ~])])]
        !<([desk (list [path ?([%ins @tas *] [%del ~])])] q.sage)
      =.  this  (handle-clay-info dek changes)
      `(enqu-take here ~ ~ %pack wir ~)
    ~  :: unknown clay poke, fall through
  ::
      %dill
    ?.  =([/ %dill-belt] p.sage)  ~
    =/  [session=@tas =belt:dill]  !<([@tas belt:dill] q.sage)
    =.  this  (emit-card [%pass /dill/belt %arvo %d %shot session %belt belt])
    `(enqu-take here ~ ~ %pack wir ~)
  ::
      %gall
    ?.  =([/ %gall-poke] p.sage)  ~
    =.  this  (handle-gall-poke here wir q.sage)
    `(enqu-take here ~ ~ %pack wir ~)
  ::
      %iris
    ?.  =([/ %iris-request] p.sage)  ~
    =.  this  (handle-iris-request here wir q.sage)
    `(enqu-take here ~ ~ %pack wir ~)
  ::
      %scry
    ?:  =([/ %scry-request] p.sage)
      =.  this  (handle-typed-scry here wir q.sage)
      `(enqu-take here ~ ~ %pack wir ~)
    ::  remote-scry farm writes. Weir-gated as ordinary /sys pokes by
    ::  arrival here; gall consumes the emitted cards and signs
    ::  nothing back, so each is fire-and-forget on this %pack.
    ?:  =([/ %scry-grow] p.sage)
      =.  this  (handle-scry-grow q.sage)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %scry-tomb] p.sage)
      =.  this  (handle-scry-tomb q.sage)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %scry-cull] p.sage)
      =.  this  (handle-scry-cull q.sage)
      `(enqu-take here ~ ~ %pack wir ~)
    ::  remote-scry reads: the answer arrives later as a
    ::  %keen-response poke-back (see +take-keen-sage); the request
    ::  itself packs immediately like every consumed service poke.
    ?:  =([/ %scry-keen] p.sage)
      =.  this  (handle-scry-keen here q.sage)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %scry-yawn] p.sage)
      =.  this  (handle-scry-yawn here q.sage)
      `(enqu-take here ~ ~ %pack wir ~)
    ~
  ::
      %lick
    ?:  =([/ %lick-spin] p.sage)
      =/  req=[name=path gained=?]  !<([path ?] q.sage)
      =.  this  (handle-lick-spin req)
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %lick-shut] p.sage)
      =.  this  (handle-lick-shut !<(path q.sage))
      `(enqu-take here ~ ~ %pack wir ~)
    ?:  =([/ %lick-spit] p.sage)
      =/  req=[name=path =mark noun=*]  !<([path @tas *] q.sage)
      =.  this  (handle-lick-spit req)
      `(enqu-take here ~ ~ %pack wir ~)
    ~
  ::
      %ames
    ?>  =(dest [/sys/ames %'registry'])
    ?>  =([/usergroups %registry-action] p.sage)
    =.  this  (handle-ames-registry here wir q.sage)
    `(enqu-take here ~ ~ %pack wir ~)
  ==
::  /sys/behn/ timer service
::
++  handle-timer-set
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  req=[=^wire when=@da]  !<([^wire @da] vaz)
  =/  timer-rail=rail:tarball  [/sys/behn %'main.behn-state']
  ::  Read current state
  =/  old=(unit sang:tarball)  (peek-grub-now timer-rail)
  =/  st=behn-state:nexus
    ?~  old  [%0 ~]
    !<(behn-state:nexus (need-vase:tarball u.old))
  ::  Same-key replace: rest the superseded arvo timer so it never
  ::  fires (its wake would be dropped as stale anyway, but why wake)
  =/  prev=(unit @da)  (~(get by timers.st) [sender wire.req])
  =?  this  &(?=(^ prev) !=(u.prev when.req))
    =/  old-wire=^wire
      :-  %behn
      :-  %timer
      :-  (scot %da u.prev)
      :-  (scot %ud (lent path.sender))
      (weld path.sender [name.sender wire.req])
    (emit-card [%pass old-wire %arvo %b %rest u.prev])
  ::  Update state
  =.  timers.st  (~(put by timers.st) [sender wire.req] when.req)
  =.  this  (save-file timer-rail [[/ %behn-state] st])
  ::  Build behn wire: /behn/timer/{da}/{path-len}/{path...}/{name}/{wire...}
  =/  timer-wire=^wire
    :-  %behn
    :-  %timer
    :-  (scot %da when.req)
    :-  (scot %ud (lent path.sender))
    (weld path.sender [name.sender wire.req])
  (emit-card [%pass timer-wire %arvo %b %wait when.req])
::  Cancel a timer previously set with %timer-set, keyed by [sender wire].
::  No-op if no such timer is live (it already fired or was never set).
::  %rest must carry the same wire and @da the %wait went out with, so
::  both are reconstructed from the stored entry.
::
++  handle-timer-rest
  |=  [sender=rail:tarball vaz=vase]
  ^+  this
  =/  req=wire  !<(wire vaz)
  =/  timer-rail=rail:tarball  [/sys/behn %'main.behn-state']
  =/  old=(unit sang:tarball)  (peek-grub-now timer-rail)
  =/  st=behn-state:nexus
    ?~  old  [%0 ~]
    !<(behn-state:nexus (need-vase:tarball u.old))
  =/  when=(unit @da)  (~(get by timers.st) [sender req])
  ?~  when  this
  =.  timers.st  (~(del by timers.st) [sender req])
  =.  this  (save-file timer-rail [[/ %behn-state] st])
  =/  timer-wire=wire
    :-  %behn
    :-  %timer
    :-  (scot %da u.when)
    :-  (scot %ud (lent path.sender))
    (weld path.sender [name.sender req])
  (emit-card [%pass timer-wire %arvo %b %rest u.when])
::  expire-snap: a snap-pin timer fired — release the snap's held refs and
::  drop it. no-op if the snap was already released (a %want beat the timer).
::  wire tail is [snap-id ship ~].
::
++  expire-snap
  |=  [tail=wire error=(unit tang)]
  ^+  this
  ?^  error
    ~&(>>> [%snap-pin-timer-error u.error] this)
  ?>  ?=([@ @ ~] tail)
  =/  snap-id=@uvJ  (slav %uv i.tail)
  =/  ship=@p       (slav %p i.t.tail)
  =/  snap-key=[@uvJ @p]  [snap-id ship]
  =/  snap  (~(get by snaps.remo) snap-key)
  ?~  snap  this
  =.  silo         (release-snap-refs refs.u.snap)
  =.  vale         (gc-vale-cache vale bins)
  =.  snaps.remo   (~(del by snaps.remo) snap-key)
  this
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
  =/  timer-rail=rail:tarball  [/sys/behn %'main.behn-state']
  =/  old=(unit sang:tarball)  (peek-grub-now timer-rail)
  =/  st=behn-state:nexus
    ?~  old  [%0 ~]
    !<(behn-state:nexus (need-vase:tarball u.old))
  ::  A wake is only delivered if it matches the live entry: a
  ::  replaced or cancelled timer's in-flight wake is stale — drop it
  ::  without touching state or the sleeping fiber
  =/  live=(unit @da)  (~(get by timers.st) [sender req-wire])
  ?.  &(?=(^ live) =(u.live when))
    this
  =.  timers.st  (~(del by timers.st) [sender req-wire])
  =.  this  (save-file timer-rail [[/ %behn-state] st])
  ::  Poke sender back with timer-wake
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender timer-rail)
  (enqu-take sender ~ ~ %poke rel [[/ %timer-wake] req-wire])
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
  =.  this  (save-file clay-rail [[/ %clay-state] st])
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
  =.  this  (save-file clay-rail [[/ %clay-state] st])
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
    ::  NB: avoid dots in binding paths. Eyre parses a dotted final
    ::  segment of a request URL as a file extension and matches
    ::  bindings against the STRIPPED path, so a binding ending in
    ::  a dotted segment never matches a slash-less URL (it falls
    ::  through to docket's catch-all). Bind dot-free paths.
    =.  bindings.st  (~(put by bindings.st) binding.act handler.act)
    =.  this  (save-server-state st)
    (emit-card [%pass /eyre-bind %arvo %e %connect binding.act dap.bowl])
  ::
      %bind-self
    ::  bind requests to the SENDER — the kernel already knows who poked,
    ::  so the caller needn't walk to root (get-here-abs) to self-report a
    ::  handler rail. This is the common case: a nexus serving its own UI.
    =.  bindings.st  (~(put by bindings.st) binding.act sender)
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
  =/  orig-wire=wire  t.rest
  ?>  ?=(%poke-ack -.sign)
  ::  Step 3: tell the requester what happened by POKING it back — a
  ::  poke-ack-marked [wire (unit tang)], keyed to the requester's own wire
  ::  so it correlates its own ack (NOT a %pack — that was already given for
  ::  the request poke to /sys/gall itself).
  =/  =from:fiber:nexus  (relativize-from:nexus sender [/sys/gall %'main.sig'])
  (enqu-take sender ~ ~ %poke from [[/ %poke-ack] [orig-wire p.sign]])
::  take-grub-poke-nack: a remote ship's gate refused a %poke load we
::  forwarded (never reached its grub). Decode the sender from the
::  wire — the same encoding as +take-gall-poke — and report the nack
::  as a %pack, exactly as a consumption nack would arrive.
::
++  take-grub-poke-nack
  |=  [segs=wire err=tang]
  ^+  this
  ?>  ?=([%grub-poke ^] segs)
  =/  path-len=@ud  (slav %ud i.t.segs)
  =/  from-path=path  (scag path-len t.t.segs)
  =/  rest=wire  (slag path-len t.t.segs)
  ?>  ?=(^ rest)
  =/  sender=rail:tarball  [from-path i.rest]
  =/  orig-wire=wire  t.rest
  (enqu-take sender ~ ~ %pack orig-wire `err)
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
  =.  this  (save-file iris-rail [[/ %iris-state] st])
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
  =.  this  (save-file iris-rail [[/ %iris-state] st])
  ::  Poke sender back with http-response
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender iris-rail)
  (enqu-take sender ~ ~ %poke rel [[/ %http-response] client-response])
::  /sys/scry/ typed scry service
::
++  handle-typed-scry
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  [mark=@tas pat=path]  !<([@tas path] vaz)
  =/  scry-rail=rail:tarball  [/sys/scry %'main.sig']
  ?>  ?=([@ @ *] pat)
  =/  res=*
    .^(* i.pat (scot %p our.bowl) i.t.pat (scot %da now.bowl) t.t.pat)
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender scry-rail)
  (enqu-take sender ~ ~ %poke rel [[/ mark] res])
::  /sys/scry remote-scry farm service, write side. Semantics ported
::  from nisfeb's PR #41 (the dart-shaped original); delivery moved to
::  service pokes so weirs gate it with no special cases and no state
::  migration. Malformed payloads slog and drop rather than crash: the
::  service is reachable by any fiber whose weir grants /sys.
::
::  scry-state: outstanding-keen bookkeeping, in the service's state
::  grub (the iris-state pattern — a grub, so no agent-state
::  migration). Entries are added on keen, removed on answer or yawn;
::  an entry orphaned by a crash is harmless (a %yawn on a dead wire
::  is a no-op).
::
++  scry-state-rail  `rail:tarball`[/sys/scry %'main.scry-state']
++  get-scry-state
  ^-  scry-state:nexus
  =/  old=(unit sang:tarball)  (peek-grub-now scry-state-rail)
  ?~  old  [%0 ~]
  !<(scry-state:nexus (need-vase:tarball u.old))
++  save-scry-state
  |=  st=scry-state:nexus
  ^+  this
  (save-file scry-state-rail [[/ %scry-state] st])
::  +handle-scry-grow: publish a page at spur, typed as $page.
::
++  handle-scry-grow
  |=  vaz=vase
  ^+  this
  =/  req=(unit [pax=path pag=page])  (mole |.(!<([path page] vaz)))
  ?~  req  ~&(>>> %scry-grow-malformed this)
  (emit-card [%pass /scry-grow %grow pax.u.req pag.u.req])
::
++  handle-scry-tomb
  |=  vaz=vase
  ^+  this
  =/  req=(unit [case=@ud pax=path])  (mole |.(!<([@ud path] vaz)))
  ?~  req  ~&(>>> %scry-tomb-malformed this)
  (emit-card [%pass /scry-tomb %tomb ud+case.u.req pax.u.req])
::  +handle-scry-cull: retract every case bound at spur. Only the
::  spur's current top case clears it (gall's +ap-cull range-checks
::  and no-ops outside the bound keys), so resolve that top here. A
::  spur with nothing bound emits no card and still packs.
::
++  handle-scry-cull
  |=  vaz=vase
  ^+  this
  =/  req=(unit path)  (mole |.(!<(path vaz)))
  ?~  req  ~&(>>> %scry-cull-malformed this)
  =/  top=(unit @ud)  (farm-top u.req)
  ?~  top  this
  (emit-card [%pass /scry-cull %cull ud+u.top u.req])
::  +farm-top: the highest case currently bound at spur in our own
::  farm, ~ when nothing is published there. Ported from PR #41.
::
::  %gw is a PARTIAL read: it answers [~ ~] for a spur it does not
::  hold, +mink turns that into a crash, and a failing .^ cannot be
::  softened from inside the event (+mute hands the scry back out to
::  the real namespace, so the crash lands outside the simulation).
::  So %gw is only asked about a spur %gt has already listed. %gt is
::  the total read: it lists every bound spur strictly BELOW the path
::  it is given (hence the snip: ask the parent about its children)
::  at O(bound spurs) per call. Caveat carried from the PR: gall
::  keeps an emptied plot after a full cull, so %gt still lists a
::  spur %gw would crash on — callers gate re-culls on their own
::  records (see +cull-farm:io).
::
::  The scries read the farm as of the START of this event; gall
::  applies the %grow/%cull cards an agent emits only after the agent
::  returns. So the base read is folded forward through this event's
::  already-emitted farm cards: a pending %grow raises the top exactly
::  as gall's key+1 will, a pending %cull clears it. Multi-publish
::  events (a folder move) thus cull the predecessors they grew in
::  the same event instead of no-opping against the pre-event farm.
::
++  farm-top
  |=  pax=path
  ^-  (unit @ud)
  =/  pre=path  ~[(scot %p our.bowl) dap.bowl (scot %da now.bowl) %$ %'1']
  =/  kin=(list path)  .^((list path) %gt (weld pre (snip pax)))
  =/  base=(unit @ud)
    ?.  (lien kin |=(p=path =(p pax)))  ~
    ::  the mold is spelled out: gall only ever answers %w with ud+key
    =/  cas=[%ud p=@ud]  .^([%ud p=@ud] %gw (weld pre pax))
    `p.cas
  =/  live=(unit @ud)  base
  =/  high=@ud  (fall base 0)
  =/  todo=(list card)  (flop cards)
  |-  ^-  (unit @ud)
  ?~  todo  live
  ?:  &(?=([%pass * %grow * *] i.todo) =(pax spur.q.i.todo))
    =/  nh=@ud  +(high)
    $(todo t.todo, high nh, live `nh)
  ?:  &(?=([%pass * %cull * *] i.todo) =(pax spur.q.i.todo))
    $(todo t.todo, live ~)
  $(todo t.todo)
::  +handle-scry-keen: read a path from a remote ship's farm. Nothing
::  is staged: the requester's return address (rail + wire) rides the
::  arvo keen wire, the iris idiom, so the %sage finds its way home
::  through +take-keen-sage with no state to clean up.
::
++  handle-scry-keen
  |=  [sender=rail:tarball vaz=vase]
  ^+  this
  =/  req=(unit [who=@p pax=path ret=path])
    (mole |.(!<([@p path path] vaz)))
  ?~  req  ~&(>>> %scry-keen-malformed this)
  =/  keen-wire=wire
    :-  %keen
    :-  (scot %p who.u.req)
    :-  (scot %ud (lent path.sender))
    (weld path.sender [name.sender ret.u.req])
  =/  st=scry-state:nexus  get-scry-state
  =.  keens.st  (~(put by keens.st) keen-wire [who.u.req pax.u.req sender])
  =.  this  (save-scry-state st)
  (emit-card [%pass keen-wire %keen %.n who.u.req pax.u.req])
::  +handle-scry-yawn: cancel the CALLER's outstanding keens at a spar,
::  precisely. ames %yawn cancels by duct, so the cancel must ride the
::  same wire the keen did — the service records every keen's wire in
::  scry-state (see +handle-scry-keen) and replays %yawn on each wire
::  the yawning grub holds at that spar. Other grubs' keens at the
::  same spar stay parked: the longpoll pattern has many grubs waiting
::  on one name, and a by-spar %wham would cancel them all (PR #44's
::  interim fix). %wham remains only as the fallback when bookkeeping
::  has no record — better a broad cancel than a keen that
::  retransmits forever.
::
++  handle-scry-yawn
  |=  [sender=rail:tarball vaz=vase]
  ^+  this
  =/  req=(unit [who=@p pax=path])  (mole |.(!<([@p path] vaz)))
  ?~  req  ~&(>>> %scry-yawn-malformed this)
  =/  st=scry-state:nexus  get-scry-state
  =/  mine=(list [=wire * * *])
    %+  skim  ~(tap by keens.st)
    |=  [* rec=[=ship pax=path sender=rail:tarball]]
    &(=(ship.rec who.u.req) =(pax.rec pax.u.req) =(sender.rec sender))
  ?:  =(~ mine)
    (emit-card [%pass /scry-yawn %arvo %a %wham who.u.req pax.u.req])
  =.  keens.st
    (roll mine |=([[=wire * * *] acc=_keens.st] (~(del by acc) wire)))
  =.  this  (save-scry-state st)
  %+  roll  mine
  |=  [[=wire * * *] acc=_this]
  (emit-card:acc [%pass wire %arvo %a %yawn who.u.req pax.u.req])
::  +take-keen-sage: an ames %sage answered a keen we passed for a
::  fiber. Decode the return address from the wire, drop an answer
::  whose spar names a different ship than the wire asked for, and
::  poke the requesting grub back with the page typed as arvo's $page
::  under the %keen-response mark — hydrated through the normal mark
::  pipeline like any poke, extracted by the fiber with !<.
::  Wire tail is {ship}/{path-len}/{path...}/{name}/{ret-wire...}.
::
++  take-keen-sage
  |=  [segs=wire =ship pag=(unit page)]
  ^+  this
  ?>  ?=([@ @ *] segs)
  =/  who=@p  (slav %p i.segs)
  =/  path-len=@ud  (slav %ud i.t.segs)
  =/  from-path=path  (scag path-len t.t.segs)
  =/  rest=wire  (slag path-len t.t.segs)
  ?~  rest  this
  =/  sender=rail:tarball  [from-path i.rest]
  =/  ret=wire  t.rest
  ?.  =(who ship)  this
  =/  st=scry-state:nexus  get-scry-state
  =.  keens.st  (~(del by keens.st) `wire`[%keen segs])
  =.  this  (save-scry-state st)
  =/  scry-rail=rail:tarball  [/sys/scry %'main.sig']
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender scry-rail)
  (enqu-take sender ~ ~ %poke rel [[/ %keen-response] [ret pag]])
::
++  handle-bowl-req
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  req=@tas  !<(@tas vaz)
  =/  bowl-rail=rail:tarball  [/sys %'bowl.sig']
  =/  rel=from:fiber:nexus  (relativize-from:nexus sender bowl-rail)
  ?+  req  this
    %our  (enqu-take sender ~ ~ %poke rel [[/ %ship] our.bowl])
      %now
    =.  last  last(now ?:((gte now.last now.bowl) (add now.last (div ~s1 1.000)) now.bowl))
    (enqu-take sender ~ ~ %poke rel [[/ %time] now.last])
      %eny
    =.  last  last(eny (shaz (cat 3 eny.bowl eny.last)))
    (enqu-take sender ~ ~ %poke rel [[/ %entropy] eny.last])
  ==
::  /sys/ames/ usergroups registry
::
::  Namespace ownership + per-group weir management.
::  - %register/%deregister: claim/release a path prefix
::  - %how: set weir roads for a named group, scoped to owned prefix
::  - %gc: sweep grants whose managing registrant no longer exists
::  - %create-group/%delete-group: group lifecycle
::  - %add-ship/%del-ship: group membership
::
++  handle-ames-registry
  |=  [sender=rail:tarball =wire vaz=vase]
  ^+  this
  =/  reg-rail=rail:tarball  [/sys/ames %'registry']
  =/  reg=(map rail:tarball path)
    =/  got=(unit sang:tarball)  (peek-grub-now reg-rail)
    ?~  got  *(map rail:tarball path)
    =/  res  (mule |.(!<((map rail:tarball path) (need-vase:tarball u.got))))
    ?:(?=(%| -.res) *(map rail:tarball path) p.res)
  =/  act  !<(registry-action:nexus vaz)
  ?-    -.act
      %register
    =/  new-prefix  pax.act
    ::  last-writer-wins, like eyre bindings: the new registrant claims
    ::  its prefix, evicting any existing registrant whose prefix
    ::  overlaps it. auto-heals stale rows left by a deleted nexus that
    ::  never got to deregister.
    =/  pruned=(map rail:tarball path)
      %-  ~(gas by *(map rail:tarball path))
      %+  skip  ~(tap by reg)
      |=  [r=rail:tarball existing=path]
      ^-  ?
      ?:  =(r rail.act)  %.n
      ?|  (is-prefix new-prefix existing)
          (is-prefix existing new-prefix)
      ==
    ::  watch the registrant so its deletion reaches +registry-news;
    ::  drop the watches of any rows the claim evicted
    =.  this
      %+  roll  (skip ~(tap by reg) |=([r=rail:tarball *] (~(has by pruned) r)))
      |=  [[r=rail:tarball *] acc=_this]
      ?:  =(r rail.act)  acc
      (sub-del:acc [%& r] reg-rail)
    =.  this  (sub-put [%& rail.act] reg-rail /registrant ~)
    =/  new-reg=(map rail:tarball path)  (~(put by pruned) rail.act new-prefix)
    (save-file reg-rail [[/usergroups %registry] new-reg])
  ::
      %deregister
    =/  prefix=(unit path)  (~(get by reg) rail.act)
    ?~  prefix  this
    =.  this  (sub-del [%& rail.act] reg-rail)
    =/  new-reg=(map rail:tarball path)  (~(del by reg) rail.act)
    =.  this  (save-file reg-rail [[/usergroups %registry] new-reg])
    ?.  clean.act  this
    ::  Strip roads under prefix from ALL groups
    =/  groups=(list [name=path grp=ball:tarball])
      (find-groups / (peek-ball-now /sys/ames/usergroups))
    |-
    ?~  groups  recompute-all-weirs
    =/  how-rail=rail:tarball  [(grp-storage-path name.i.groups) %'how.weir']
    =/  cur=weir:nexus  (read-group-weir how-rail)
    =/  new=weir:nexus
      :*  (replace-roads make.cur ~ u.prefix)
          (replace-roads poke.cur ~ u.prefix)
          (replace-roads peek.cur ~ u.prefix)
      ==
    =.  this  (save-file how-rail [[/ %weir] new])
    $(groups t.groups)
  ::
      %how
    =/  prefix=(unit path)  (~(get by reg) sender)
    ?~  prefix
      ~&  >>  [%how-rejected-not-registered sender]
      this
    =/  grp-dir=path  (grp-storage-path group.act)
    =/  how-rail=rail:tarball  [grp-dir %'how.weir']
    =/  exists=(unit sang:tarball)  (peek-grub-now [grp-dir %'who.ships'])
    ?~  exists
      ~&  >>  [%how-rejected-no-such-group group.act]
      this
    =/  cur=weir:nexus  (read-group-weir how-rail)
    ?.  (validate-weir-roads weir.act u.prefix)
      ~&  >>  [%how-rejected-roads-outside-prefix sender group.act u.prefix]
      this
    =/  new=weir:nexus
      :*  (replace-roads make.cur make.weir.act u.prefix)
          (replace-roads poke.cur poke.weir.act u.prefix)
          (replace-roads peek.cur peek.weir.act u.prefix)
      ==
    =.  this  (save-file how-rail [[/ %weir] new])
    recompute-all-weirs
  ::
      %gc
    ::  Garbage-collect grants by manager existence, not target
    ::  existence: a grant may legitimately point at a path its
    ::  manager has not created yet, but a grant whose managing
    ::  registrant is gone can never be updated or revoked again.
    ::  Drops ownership rows for dead registrant grubs, then strips
    ::  every group road no live prefix covers, and re-establishes the
    ::  registrant watches +registry-news relies on — a full
    ::  reconciliation, so it also migrates rows that predate the
    ::  watches. Removal-only on grants, so any local sender may
    ::  invoke it.
    =/  rows=(list [r=rail:tarball pre=path])  ~(tap by reg)
    =/  live=(list path)
      %+  murn  rows
      |=([r=rail:tarball pre=path] ?~((peek-grub-now r) ~ `pre))
    =.  this
      %+  roll  rows
      |=  [[r=rail:tarball *] acc=_this]
      ?~  (peek-grub-now r)
        (sub-del:acc [%& r] reg-rail)
      (sub-put:acc [%& r] reg-rail /registrant ~)
    =/  new-reg=(map rail:tarball path)
      %-  ~(gas by *(map rail:tarball path))
      (skip rows |=([r=rail:tarball pre=path] =(~ (peek-grub-now r))))
    =?  this  !=(new-reg reg)
      (save-file reg-rail [[/usergroups %registry] new-reg])
    =/  keep-road
      |=  =road:tarball
      ^-  ?
      =/  pax=(unit path)  (ug-extract-dir road)
      ?~  pax  |
      (lien live |=(pre=path (is-prefix pre u.pax)))
    =/  groups=(list [name=path grp=ball:tarball])
      (find-groups / (peek-ball-now /sys/ames/usergroups))
    |-
    ?~  groups  recompute-all-weirs
    =/  how-rail=rail:tarball
      [(grp-storage-path name.i.groups) %'how.weir']
    =/  cur=weir:nexus  (read-group-weir how-rail)
    =/  new=weir:nexus
      :*  (sy (skim ~(tap in make.cur) keep-road))
          (sy (skim ~(tap in poke.cur) keep-road))
          (sy (skim ~(tap in peek.cur) keep-road))
      ==
    =?  this  !=(new cur)
      (save-file how-rail [[/ %weir] new])
    $(groups t.groups)
  ==
::
::  +registry-news: a watched registrant grub changed. The registry
::  subscribes to every registrant at %register, so a registrant's
::  deletion arrives here as ordinary news. A content change is
::  ignored; a death sweeps the ownership row, the group grants under
::  its prefix, and the watch itself.
::
++  registry-news
  |=  target=lane:tarball
  ^+  this
  ?.  ?=(%& -.target)  this
  =/  r=rail:tarball  p.target
  ?:  (grub-lives r)  this
  =/  reg-rail=rail:tarball  [/sys/ames %'registry']
  =.  this  (sub-del target reg-rail)
  =/  reg=(map rail:tarball path)
    =/  got=(unit sang:tarball)  (peek-grub-now reg-rail)
    ?~  got  ~
    =/  res  (mule |.(!<((map rail:tarball path) (need-vase:tarball u.got))))
    ?:(?=(%| -.res) ~ p.res)
  =/  pre=(unit path)  (~(get by reg) r)
  ?~  pre  this
  =.  this  (save-file reg-rail [[/usergroups %registry] (~(del by reg) r)])
  =/  keep-road
    |=  =road:tarball
    ^-  ?
    =/  pax=(unit path)  (ug-extract-dir road)
    ?~  pax  %.y
    !(is-prefix u.pre u.pax)
  =/  groups=(list [name=path grp=ball:tarball])
    (find-groups / (peek-ball-now /sys/ames/usergroups))
  |-
  ?~  groups  recompute-all-weirs
  =/  how-rail=rail:tarball
    [(grp-storage-path name.i.groups) %'how.weir']
  =/  cur=weir:nexus  (read-group-weir how-rail)
  =/  new=weir:nexus
    :*  (sy (skim ~(tap in make.cur) keep-road))
        (sy (skim ~(tap in poke.cur) keep-road))
        (sy (skim ~(tap in peek.cur) keep-road))
    ==
  =?  this  !=(new cur)
    (save-file how-rail [[/ %weir] new])
  $(groups t.groups)
::
++  read-group-weir
  |=  how-rail=rail:tarball
  ^-  weir:nexus
  =/  got=(unit sang:tarball)  (peek-grub-now how-rail)
  ?~  got  *weir:nexus
  =/  res  (mule |.(!<(weir:nexus (need-vase:tarball u.got))))
  ?:(?=(%| -.res) *weir:nexus p.res)
::
++  is-prefix
  |=  [pre=path full=path]
  ^-  ?
  ?~  pre  &
  ?~  full  |
  ?.  =(i.pre i.full)  |
  $(pre t.pre, full t.full)
::  +ug-extract-dir:
::    a road's directory — a file's parent, or the dir itself.
::    we ignore relative roads. normal weirs can have relative roads.
::    usergroup weirs cannot.
::
++  ug-extract-dir
  |=  =road:tarball
  ^-  (unit path)
  ?.  ?=(%& -.road)  ~ :: ignore relative roads
  :-  ~
  ?-  -.p.road
    %|  p.p.road      :: for folders, the path
    %&  path.p.p.road :: for files, the path of the parent folder
  ==
::
++  validate-weir-roads
  |=  [=weir:nexus prefix=path]
  ^-  ?
  %+  levy
    %+  weld  ~(tap in make.weir)
    %+  weld  ~(tap in poke.weir)
    ~(tap in peek.weir)
  |=  =road:tarball
  =/  pax=(unit path)  (ug-extract-dir road)
  ?~  pax  |  :: reject relative roads
  (is-prefix prefix u.pax)
::
++  replace-roads
  |=  [cur=(set road:tarball) new=(set road:tarball) prefix=path]
  ^-  (set road:tarball)
  ::  Strip roads under prefix from current
  =/  stripped=(set road:tarball)
    %-  ~(gas in *(set road:tarball))
    %+  skip  ~(tap in cur)
    |=  =road:tarball
    =/  pax=(unit path)  (ug-extract-dir road)
    ?~  pax  |
    (is-prefix prefix u.pax)
  ::  Add new roads
  (~(uni in stripped) new)
::
++  recompute-all-weirs
  ^+  this
  =/  ships-ball=ball:tarball  (peek-ball-now /sys/ames/ships)
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ships-ball)
  |-
  ?~  kids  this
  =/  ship-name=@ta  -.i.kids
  =/  ship=(unit @p)  (slaw %p ship-name)
  ?~  ship  $(kids t.kids)
  ?:  =(u.ship our.bowl)  $(kids t.kids)
  =/  =weir:nexus  (compute-peer-weir u.ship)
  =.  this  (set-weir /sys/ames/ships/[ship-name] `weir)
  $(kids t.kids)
--
