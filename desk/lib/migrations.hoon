::  migrations: agent state versions
::
::  The discipline:
::
::  A state version's types must be FROZEN — written against the shapes
::  as they were, not against live library types that keep moving. Only
::  the chain that actually changed is frozen; everything else refers
::  to live types precisely because it is unchanged. If a later change
::  touches a type a frozen chain refers to, that chain must deepen.
::
::  Loads persist in exactly one place: pool process queues, via pend's
::  [%veto =dart]. So a change to load freezes the chain load -> dart ->
::  pend -> take -> proc -> pipe -> pool. The process slot widens to * :
::  +on-save's bang-pool guarantees only %| tangs persist, and old
::  continuations are never resumed — they are replaced wholesale by
::  the reload machinery.
::
::  state-0 -> state-1: %make loads grew a gain=? flag (born-gained
::  grubs, no make-then-gain race).
::  state-1 -> state-2: the %tag load was renamed %tags.
::  state-2 -> state-3: lode keys are one hash per rail (in and out
::  were always equal), and the build subject is an ordinary node in
::  the dependency graph (sut-rail:nexus, keyed by the subject hash)
::  instead of a [hash hash] sentinel under the fake rail [/ %$].
::  code is derived state, so this chain is a pure map; its fallback
::  would be reset-and-rebuild.
::  state-3 -> state-4: the %font load and take are gone (the question
::  it answered — which /code governs a path — is a namespace fact,
::  see /lib/code-src). A persisted %font veto is dropped.
::  state-4 -> state-5: lode loses refs. It was a second index of keys
::  (artifact stem -> key, as an axal) carrying the same values; an
::  artifact is addressed by its source rail, which keys already maps.
::  Derived state: a field drop, pure map.
::
/+  nexus, tarball
=,  tarball
=,  nexus
=,  fiber:nexus
|%
+|  %frozen-0
::
+$  load-0
  $%  [%poke =bask:tarball]
      [%make force=? =make]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%load ~]
      [%peek blot=(unit blot:tarball) case=(unit case) deep=?]
      [%keep blot=(unit blot:tarball)]
      [%drop ~]
      [%lose =lose]
      [%gain flag=?]
      [%firm ~]
      [%tag case=(unit case) tags=(set @t)]
      [%seek =nobe]
      [%peep =find]
      [%born ~]
      [%code ~]
      [%font ~]
  ==
::
+$  dart-0
  $%  [%node =wire road=road:tarball load=load-0]
      [%here =wire]
      [%kept =wire]
  ==
::
+$  pend-0
  $%  [%poke =from =bask:tarball]
      [%peek =wire cite=cite-10]
      [%peep =wire res=(each (list [=cass:clay lobe=jobe]) tang)]
      [%code =wire res=(each (axal (map @ta @uv)) (each @uv tang))]
      [%news =wire =wave]
      [%kept =wire =kept]
      [%made =wire err=(unit tang)]
      [%gone =wire err=(unit tang)]
      [%pack =wire err=(unit tang)]
      [%sand =wire err=(unit tang)]
      [%load =wire err=(unit tang)]
      [%lost =wire err=(unit tang)]
      [%gain =wire err=(unit tang)]
      [%held =wire err=(unit tang)]
      [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)]
      [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)]
      [%fell =wire]
      [%veto dart=dart-0]
      [%font =wire res=(unit (unit bend:tarball))]
      [%here =wire =here]
  ==
::
+$  take-0  [give=(unit give) in=(unit pend-0)]
+$  proc-0
  $:  process=(each * tang)
      next=(qeu take-0)
      skip=(qeu take-0)
  ==
+$  pipe-0  [bang=(unit tang) proc=(map @ta proc-0)]
+$  pool-0  (axal pipe-0)
::
+|  %frozen-1
::  load-1: %make carries gain=?; the tag load is still %tag. Everything
::  from dart-1 down is shape-identical to the live types except for
::  the load it carries.
::
+$  load-1
  $%  [%poke =bask:tarball]
      [%make force=? gain=? =make]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%load ~]
      [%peek blot=(unit blot:tarball) case=(unit case) deep=?]
      [%keep blot=(unit blot:tarball)]
      [%drop ~]
      [%lose =lose]
      [%gain flag=?]
      [%firm ~]
      [%tag case=(unit case) tags=(set @t)]
      [%seek =nobe]
      [%peep =find]
      [%born ~]
      [%code ~]
      [%font ~]
  ==
::
+$  dart-1
  $%  [%node =wire road=road:tarball load=load-1]
      [%here =wire]
      [%kept =wire]
  ==
::
+$  pend-1
  $%  [%poke =from =bask:tarball]
      [%peek =wire cite=cite-10]
      [%peep =wire res=(each (list [=cass:clay lobe=jobe]) tang)]
      [%code =wire res=(each (axal (map @ta @uv)) (each @uv tang))]
      [%news =wire =wave]
      [%kept =wire =kept]
      [%made =wire err=(unit tang)]
      [%gone =wire err=(unit tang)]
      [%pack =wire err=(unit tang)]
      [%sand =wire err=(unit tang)]
      [%load =wire err=(unit tang)]
      [%lost =wire err=(unit tang)]
      [%gain =wire err=(unit tang)]
      [%held =wire err=(unit tang)]
      [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)]
      [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)]
      [%fell =wire]
      [%veto dart=dart-1]
      [%font =wire res=(unit (unit bend:tarball))]
      [%here =wire =here]
  ==
::
+$  take-1  [give=(unit give) in=(unit pend-1)]
+$  proc-1
  $:  process=(each * tang)
      next=(qeu take-1)
      skip=(qeu take-1)
  ==
+$  pipe-1  [bang=(unit tang) proc=(map @ta proc-1)]
+$  pool-1  (axal pipe-1)
::
+|  %frozen-2
::  The build index as it was through state-2: two keys per rail (in
::  and out, always equal) and the subject hash smuggled into keys as a
::  [hash hash] pair under the fake rail [/ %$], absent from deps.
::
+$  refs-4  (axal (map @ta @uv))
+$  keys-2  (map rail:tarball [in=@uv out=@uv])
+$  lode-2  [keys=keys-2 =deps:nexus refs=refs-4]
+$  code-2  (map fold:tarball lode-2)
++  sut-rail-2  `rail:tarball`[/ %$]
::
+|  %frozen-4
::  The build index through state-4: one key per rail, subject as a
::  dep, plus the refs axal that keys made redundant.
::
+$  lode-4  [=keys:nexus =deps:nexus refs=refs-4]
+$  code-4  (map fold:tarball lode-4)
::
+|  %frozen-3
::  load-3: the load with %font, as it was through state-3; pend-3 has
::  the %font take. Everything else below is shape-identical to live.
::
+$  load-3
  $%  [%poke =bask:tarball]
      [%make force=? gain=? =make]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%load ~]
      [%peek blot=(unit blot:tarball) case=(unit case) deep=?]
      [%keep blot=(unit blot:tarball)]
      [%drop ~]
      [%lose =lose]
      [%gain flag=?]
      [%firm ~]
      [%tags case=(unit case) tags=(set @t)]
      [%seek =nobe]
      [%peep =find]
      [%born ~]
      [%code ~]
      [%font ~]
  ==
::
+$  dart-3
  $%  [%node =wire road=road:tarball load=load-3]
      [%here =wire]
      [%kept =wire]
  ==
::
+$  pend-3
  $%  [%poke =from =bask:tarball]
      [%peek =wire cite=cite-10]
      [%peep =wire res=(each (list [=cass:clay lobe=jobe]) tang)]
      [%code =wire res=(each (axal (map @ta @uv)) (each @uv tang))]
      [%news =wire =wave]
      [%kept =wire =kept]
      [%made =wire err=(unit tang)]
      [%gone =wire err=(unit tang)]
      [%pack =wire err=(unit tang)]
      [%sand =wire err=(unit tang)]
      [%load =wire err=(unit tang)]
      [%lost =wire err=(unit tang)]
      [%gain =wire err=(unit tang)]
      [%held =wire err=(unit tang)]
      [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)]
      [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)]
      [%fell =wire]
      [%veto dart=dart-3]
      [%font =wire res=(unit (unit bend:tarball))]
      [%here =wire =here]
  ==
::
+$  take-3  [give=(unit give) in=(unit pend-3)]
+$  proc-3
  $:  process=(each * tang)
      next=(qeu take-3)
      skip=(qeu take-3)
  ==
+$  pipe-3  [bang=(unit tang) proc=(map @ta proc-3)]
+$  pool-3  (axal pipe-3)
::
+|  %versions
::  state-0: the full state of the grubbery agent, frozen.
::
::  Each field is one of three kinds. Truth fields are the namespace
::  itself and cannot be regenerated. Derived fields can be rebuilt
::  from the truth fields. Live fields are runtime state and also
::  cannot be regenerated.
::
+$  state-0
  $:  %0
      born=born-12  ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-0   ::  live: the running process for each grub (frozen)
      code=code-2   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      remo=remo-12   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-1: %make loads carry gain=?. Pool frozen (still %tag).
::
+$  state-1
  $:  %1
      born=born-12  ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-1   ::  live: the running process for each grub (frozen)
      code=code-2   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      remo=remo-12   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-2: %tag renamed %tags. Pool frozen (still %font); code frozen
::  (two-key lode).
::
+$  state-2
  $:  %2
      born=born-12  ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-3   ::  live: the running process for each grub (frozen)
      code=code-2   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      remo=remo-12   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-3: one key per rail, subject as a dep. Pool frozen (still
::  %font); code frozen (still refs).
::
+$  state-3
  $:  %3
      born=born-12  ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-3   ::  live: the running process for each grub (frozen)
      code=code-4   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      remo=remo-12   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::
::  state-4: no %font. Pool live; code frozen (still refs).
::
+$  state-4
  $:  %4
      born=born-12  ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-10    ::  live: the running process for each grub
      code=code-4   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      remo=remo-12   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::
::  state-5: lode is [keys deps]. Same fields, live types.
::
+$  state-5
  $:  %5
      born=born-12  ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-10    ::  live: the running process for each grub
      =code:nexus   ::  derived: the build index for each code namespace
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      remo=remo-12   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-6: the cite-drop fix (#80) plus its one-time skip-queue
::  correction. Shape-identical to %5; the version only records that the
::  correction has run, so it runs exactly once, at the upgrade.
+$  state-6
  $:  %6
      born=born-12
      =silo:nexus
      =subs:nexus
      pool=pool-10
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
  ==
::  state-7: conns, the eyre-id to binding map, is agent state, not a
::  grub. Same fields as %6 plus conns.
::
::  conns is per-request bookkeeping with no meaning across a reload, so
::  a grub is the wrong home for it. Holding it there drags the whole
::  write path on every inbound HTTP request: hist rebuild, gc-vale-cache,
::  silo. Measured on a real ship, that put about 4.5KB into the
::  permanent event log for a read-only GET and cost about a second per
::  request in grubbery's eyre layer. bindings are truth and stay in the
::  namespace.
::
+$  state-7
  $:  %7
      born=born-12
      =silo:nexus
      =subs:nexus
      pool=pool-10
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
      ::  live: which eyre binding is serving each open eyre-id
      conns=(map @ta binding:eyre)
  ==
::
+|  %migrations
::
++  state-0-to-1
  |=  old=state-0
  ^-  state-1
  :*  %1
      born.old
      silo.old
      subs.old
      (pool-0-to-1 pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
::
++  state-1-to-2
  |=  old=state-1
  ^-  state-2
  :*  %2
      born.old
      silo.old
      subs.old
      (pool-1-to-pool pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
::
++  state-2-to-3
  |=  old=state-2
  ^-  state-3
  :*  %3
      born.old
      silo.old
      subs.old
      pool.old
      (code-2-to-4 code.old)
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
::
++  state-3-to-4
  |=  old=state-3
  ^-  state-4
  :*  %4
      born.old
      silo.old
      subs.old
      (pool-3-to-pool pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
::
::  state-6 -> state-7: conns moves into agent state (starts empty), and a
::  one-time sweep of born. Until now a culled grub left its record behind,
::  so a ship that had served traffic carried one dead record per request
::  ever made. Both the tree walk and the born diff scan those records on
::  every later write in the same directory. New ones stop appearing at
::  the source (+cull drops an un-gained grub's record), and this clears
::  what already piled up.
::
::  state-8: peak, born's shadow. Born's skeleton with every history
::  collapsed to its highest cass, raised on every write and never
::  deleted: numbering lives here, so a born record is history and may
::  be dropped. Starts empty: every rail re-created before its first
::  write under %8 numbers from zero once more (the one rebind this
::  chain allows, at the crossing).
::
+$  state-8
  $:  %8
      born=born-12
      =peak:nexus
      =silo:nexus
      =subs:nexus
      pool=pool-10
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
      conns=(map @ta binding:eyre)
  ==
::  state-9: same shape as %8. The crossing is a one-time sweep: every
::  history loses the dead entries the old write path left behind (a
::  tomb per replaced temp pace, one absence per reload-deletion), and
::  peak is seeded from born so every rail that exists today has its
::  mark before any record of it can be dropped. Under %8 writes a
::  rail's number only reached peak on its next write; a rail last
::  written before %8 and culled after would have numbered from zero.
::
+|  %frozen-9
::  state-9 borrowed live `pool`, and %10 moves a type inside it: `view`
::  gained a `bang`, and a suspended `process` is a GATE whose mold names
::  intake -> view. No view noun is ever stored (pend is cold: "no vases
::  — lobes and ckeys only", and hydrate resolves cite -> view at
::  consumption time) but the continuation's TYPE drags it in, so the
::  chain deepens here. Only the process slot widens to *; take/pend/cite
::  are untouched by this crossing, and are frozen at %10 below.
::
+$  proc-9
  $:  process=(each * tang)
      next=(qeu take-10)
      skip=(qeu take-10)
  ==
+$  pipe-9  [bang=(unit tang) proc=(map @ta proc-9)]
+$  pool-9  (axal pipe-9)
::
+$  state-9
  $:  %9
      born=born-12
      =peak:nexus
      =silo:nexus
      =subs:nexus
      pool=pool-9
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
      conns=(map @ta binding:eyre)
  ==
::  state-10: `view` carries the grub's bang, so a fiber that follows a
::  grub learns it banged from the thing it already watches instead of
::  having to peek the parent directory's ball.
::
+$  state-10
  $:  %10
      born=born-12
      =peak:nexus
      =silo:nexus
      =subs:nexus
      pool=pool-10
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
      conns=(map @ta binding:eyre)
  ==
++  state-9-to-10
  |=  old=state-9
  ^-  state-10
  :*  %10
      born.old
      peak.old
      silo.old
      subs.old
      (pool-9-to-pool-10 pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
      conns.old
  ==
++  pool-9-to-pool-10
  |=  p=pool-9
  ^-  pool-10
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-9-to-proc-10)]
  (~(run by dir.p) pool-9-to-pool-10)
::  a live continuation cannot be re-typed, and is never resumed: the
::  reload machinery rebuilds it. A %| tang passes through untouched.
::
++  proc-9-to-proc-10
  |=  p=proc-9
  ^-  proc-10
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load (view gained bang)"]
    next.p
  skip.p
+|  %frozen-10
::  state-10 borrowed live `pool`, and %11 moves a type inside it: a
::  %file cite gained `at`, the grub's position, which is where its mark
::  resolves from. A queued peek persists in a proc's next and skip as a
::  pend holding its cite, so the chain cite -> pend -> take -> proc ->
::  pipe -> pool freezes here.
::
+$  cite-10
  $%  [%file =cass:clay lobe=jobe conv=(unit blot:tarball)]
      [%ball =wave lobe=jobe deep=?]
      [%none ~]
      [%miss ~]
      [%veto ~]
      [%tomb ~]
  ==
+$  pend-10
  $%  [%poke =from =bask:tarball]
      [%peek =wire cite=cite-10]
      [%peep =wire res=(each (list [=cass:clay lobe=jobe]) tang)]
      [%code =wire res=(each (axal (map @ta @uv)) (each @uv tang))]
      [%news =wire =wave]
      [%kept =wire =kept]
      [%made =wire err=(unit tang)]
      [%gone =wire err=(unit tang)]
      [%pack =wire err=(unit tang)]
      [%sand =wire err=(unit tang)]
      [%load =wire err=(unit tang)]
      [%lost =wire err=(unit tang)]
      [%gain =wire err=(unit tang)]
      [%held =wire err=(unit tang)]
      [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)]
      [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)]
      [%fell =wire]
      [%veto dart=dart-11]
      [%here =wire =here]
  ==
+$  take-10  [give=(unit give) in=(unit pend-10)]
+$  proc-10
  $:  process=(each * tang)
      next=(qeu take-10)
      skip=(qeu take-10)
  ==
+$  pipe-10  [bang=(unit tang) proc=(map @ta proc-10)]
+$  pool-10  (axal pipe-10)
::  state-11: a %file cite says where the grub is, so its mark resolves
::  from the grub's own code namespace and a desk-local mark reads from
::  anywhere; the reader's namespace is the fallback.
::
+$  state-11
  $:  %11
      born=born-12
      =peak:nexus
      =silo:nexus
      =subs:nexus
      pool=pool-11
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
      conns=(map @ta binding:eyre)
  ==
++  state-10-to-11
  |=  old=state-10
  ^-  state-11
  :*  %11
      born.old
      peak.old
      silo.old
      subs.old
      (pool-10-to-pool / pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
      conns.old
  ==
::  a queued peek's answer did not say where it was read. It is given
::  its reader's position, which is where its mark resolved from under
::  %10, so nothing already queued reads differently.
::
++  pool-10-to-pool
  |=  [here=path p=pool-10]
  ^-  pool-11
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) (cury proc-10-to-proc here))]
  %-  ~(urn by dir.p)
  |=([k=@ta kid=pool-10] ^$(here (snoc here k), p kid))
::
++  proc-10-to-proc
  |=  [here=path p=proc-10]
  ^-  proc-11
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load (cite gained at)"]
    (takes-10-to-takes here next.p)
  (takes-10-to-takes here skip.p)
::
++  takes-10-to-takes
  |=  [here=path q=(qeu take-10)]
  ^-  (qeu take-11)
  (~(gas to *(qeu take-11)) (turn ~(tap to q) (cury take-10-to-take here)))
::
++  take-10-to-take
  |=  [here=path t=take-10]
  ^-  take-11
  ?~  in.t  [give.t ~]
  [give.t `(pend-10-to-pend here u.in.t)]
::
++  pend-10-to-pend
  |=  [here=path p=pend-10]
  ^-  pend-11
  ?.  ?=(%peek -.p)  p
  ?.  ?=(%file -.cite.p)  [%peek wire.p cite.p]
  [%peek wire.p [%file cass.cite.p lobe.cite.p conv.cite.p here]]
++  state-8-to-9
  |=  old=state-8
  ^-  state-9
  :*  %9
      (sweep-dead-born born.old)
      (seed-peak born.old peak.old)
      silo.old  subs.old  pool.old  code.old
      bins.old  vale.old  remo.old  upki.old  last.old
      conns.old
  ==
::  +sweep-dead-born: drop every dead entry below the top of each file
::  and fold history. Dead = a tomb, or an absence (a pace with no
::  content); neither points at a ject, so no silo ref is released. The
::  top entry stays whatever it is: it is the rail's current state.
::
++  sweep-dead-born
  |=  bon=born-12
  ^-  born-12
  =?  fil.bon  ?=(^ fil.bon)
    :-  ~
    %=  u.fil.bon
      fold  (sweep-hist fold.u.fil.bon)
      file  (~(run by file.u.fil.bon) sweep-hist)
    ==
  bon(dir (~(run by dir.bon) |=(kid=born-12 ^$(bon kid))))
::
++  sweep-hist
  |=  sk=hist-12
  ^-  hist-12
  =/  top=(unit cass:clay)  (top-12 sk)
  ?~  top  sk
  %+  gas:hon-12  *hist-12
  %+  skim  (tap:hon-12 sk)
  |=  [key=cass:clay val=entry-12]
  ?:  =(key u.top)  %.y
  ?:  ?=(%tomb -.pace.val)  %.n
  ?=(^ p.pace.val)
::  +seed-peak: born collapsed to its high-water casses, merged over the
::  peak as it stands (a peak only ever rises).
::
++  seed-peak
  |=  [bon=born-12 pk=peak:nexus]
  ^-  peak:nexus
  =/  here=(unit [fold=(unit cass:clay) file=(map @ta cass:clay)])
    ?~  fil.bon  ~
    :-  ~
    :-  (top-12 fold.u.fil.bon)
    %-  ~(rep by file.u.fil.bon)
    |=  [[nom=@ta sk=hist-12] out=(map @ta cass:clay)]
    =/  t=(unit cass:clay)  (top-12 sk)
    ?~  t  out
    (~(put by out) nom u.t)
  =/  merged=(unit [fold=(unit cass:clay) file=(map @ta cass:clay)])
    ?~  here  fil.pk
    ?~  fil.pk  here
    :-  ~
    :-  (max-cass fold.u.here fold.u.fil.pk)
    %-  ~(rep by file.u.here)
    |=  [[nom=@ta c=cass:clay] out=_file.u.fil.pk]
    =/  cur=(unit cass:clay)  (~(get by out) nom)
    ?:  &(?=(^ cur) (gte ud.u.cur ud.c))  out
    (~(put by out) nom c)
  =/  kids=(set @ta)  (~(uni in ~(key by dir.bon)) ~(key by dir.pk))
  :-  merged
  %-  ~(gas by *(map @ta peak:nexus))
  %+  turn  ~(tap in kids)
  |=  k=@ta
  :-  k
  %+  seed-peak
    (fall (~(get by dir.bon) k) *born-12)
  (fall (~(get by dir.pk) k) *peak:nexus)
::
++  max-cass
  |=  [a=(unit cass:clay) b=(unit cass:clay)]
  ^-  (unit cass:clay)
  ?~  a  b
  ?~  b  a
  ?:((gte ud.u.a ud.u.b) a b)
::
++  state-7-to-8
  |=  old=state-7
  ^-  state-8
  :*  %8
      born.old  *peak:nexus
      silo.old  subs.old  pool.old  code.old
      bins.old  vale.old  remo.old  upki.old  last.old
      conns.old
  ==
++  state-6-to-7
  |=  old=state-6
  ^-  state-7
  :*  %7
      (prune-dead-born born.old)
      silo.old  subs.old  pool.old  code.old
      bins.old  vale.old  remo.old  upki.old  last.old
      ~
  ==
::  +prune-dead-born: drop file records with nothing left to read.
::
::    A record survives if any revision still points at a ject. A gained
::    grub keeps its revisions, so it survives a delete and keeps ordering
::    its future re-creations. An un-gained one has had its revisions
::    tombed already, so nothing here is reachable and nothing references
::    the silo. Dropping it releases no refcounts because it holds none.
::
++  prune-dead-born
  |=  bon=born-12
  ^-  born-12
  =?  fil.bon  ?=(^ fil.bon)
    :-  ~
    %=    u.fil.bon
        file
      %-  ~(rep by file.u.fil.bon)
      |=  [[nom=@ta sk=hist-12] out=(map @ta hist-12)]
      ?.  (hist-readable sk)  out
      (~(put by out) nom sk)
    ==
  %=    bon
      dir
    %-  ~(run by dir.bon)
    |=(kid=born-12 ^$(bon kid))
  ==
::  +hist-readable: does any revision of this file still point at a ject?
::
++  hist-readable
  |=  sk=hist-12
  ^-  ?
  %+  lien  (tap:hon-12 sk)
  |=  [key=cass:clay val=entry-12]
  ?:  ?=(%tomb -.pace.val)  %.n
  ?=(^ p.pace.val)
::
++  state-5-to-6
  |=  old=state-5
  ^-  state-6
  :*  %6
      born.old  silo.old  subs.old  pool.old  code.old
      bins.old  vale.old  remo.old  upki.old  last.old
  ==
++  state-4-to-5
  |=  old=state-4
  ^-  state-5
  :*  %5
      born.old
      silo.old
      subs.old
      pool.old
      (code-4-to-code code.old)
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
::
+|  %frozen-11
::  %12 widens the %firm load to carry tags: +firm-hist always took
::  them, the dart never supplied them. Loads persist in pool process
::  queues via pend's [%veto =dart], so the documented chain freezes
::  here: load -> dart -> pend -> take -> proc -> pipe -> pool.
::
+$  load-11
  $%  [%poke =bask:tarball]
      [%make force=? gain=? =make]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%load ~]
      [%peek blot=(unit blot:tarball) case=(unit case) deep=?]
      [%keep blot=(unit blot:tarball)]
      [%drop ~]
      [%lose =lose]
      [%gain flag=?]
      [%firm ~]
      [%tags case=(unit case) tags=(set @t)]
      [%seek =nobe]
      [%peep =find]
      [%born ~]
      [%code ~]
  ==
::
+$  dart-11
  $%  [%node =wire road=road:tarball load=load-11]
      [%here =wire]
      [%kept =wire]
  ==
::
+$  pend-11
  $%  [%poke =from =bask:tarball]
      [%peek =wire =cite]
      [%peep =wire res=(each (list [=cass:clay lobe=jobe]) tang)]
      [%code =wire res=(each (axal (map @ta @uv)) (each @uv tang))]
      [%news =wire =wave]
      [%kept =wire =kept]
      [%made =wire err=(unit tang)]
      [%gone =wire err=(unit tang)]
      [%pack =wire err=(unit tang)]
      [%sand =wire err=(unit tang)]
      [%load =wire err=(unit tang)]
      [%lost =wire err=(unit tang)]
      [%gain =wire err=(unit tang)]
      [%held =wire err=(unit tang)]
      [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)]
      [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)]
      [%fell =wire]
      [%veto dart=dart-11]
      [%here =wire =here]
  ==
::
+$  take-11  [give=(unit give) in=(unit pend-11)]
+$  proc-11
  $:  process=(each * tang)
      next=(qeu take-11)
      skip=(qeu take-11)
  ==
+$  pipe-11  [bang=(unit tang) proc=(map @ta proc-11)]
+$  pool-11  (axal pipe-11)
::  state-12: a %firm load carries the labels to set on the version it
::  promotes, so committing a version and naming it is one write.
::
+$  state-12
  $:  %12
      born=born-12
      =peak:nexus
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=remo-12
      =upki:nexus
      =last:nexus
      conns=(map @ta binding:eyre)
  ==
++  state-11-to-12
  |=  old=state-11
  ^-  state-12
  :*  %12
      born.old
      peak.old
      silo.old
      subs.old
      (pool-11-to-pool pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
      conns.old
  ==
::  a queued %firm carried no labels, so it gets none.
::
++  pool-11-to-pool
  |=  p=pool-11
  ^-  pool:nexus
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-11-to-proc)]
  (~(run by dir.p) pool-11-to-pool)
::
++  proc-11-to-proc
  |=  p=proc-11
  ^-  proc:fiber:nexus
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load (%firm gained tags)"]
    (takes-11-to-takes next.p)
  (takes-11-to-takes skip.p)
::
++  takes-11-to-takes
  |=  q=(qeu take-11)
  ^-  (qeu take)
  (~(gas to *(qeu take)) (turn ~(tap to q) take-11-to-take))
::
++  take-11-to-take
  |=  t=take-11
  ^-  take
  ?~  in.t  [give.t ~]
  [give.t `(pend-11-to-pend u.in.t)]
::
++  pend-11-to-pend
  |=  p=pend-11
  ^-  pend
  ?.  ?=(%veto -.p)  p
  [%veto (dart-11-to-dart dart.p)]
::
++  dart-11-to-dart
  |=  d=dart-11
  ^-  dart:nexus
  ?.  ?=(%node -.d)  d
  [%node wire.d road.d (load-11-to-load load.d)]
::
++  load-11-to-load
  |=  l=load-11
  ^-  load:nexus
  ?.  ?=(%firm -.l)  l
  [%firm ~]
::
+|  %frozen-12
::  %13 makes emptiness unrepresentable: a version always references
::  content. The chain pace -> entry -> hist -> born freezes here, and
::  born is a state field, so every state up to %12 holds the old one.
::
+$  pace-12
  $%  [%firm p=(unit jobe)]
      [%temp p=(unit jobe)]
      [%tomb ~]
  ==
+$  entry-12  [pace=pace-12 tags=(set @t)]
+$  hist-12   ((mop cass:clay entry-12) cor:hist:nexus)
++  hon-12    ((on cass:clay entry-12) cor:hist:nexus)
+$  born-12   (axal [fold=hist-12 file=(map @ta hist-12)])
::  pace is reachable from TWO places, not one: a staged cross-ship peek
::  holds the pace it negotiated, so remo freezes alongside born.
::
+$  snap-12   [=cass:clay pace=pace-12 refs=lobes:nexus]
+$  peek-12
  $:  ship=@p
      dest=lane:tarball
      deep=?
      blot=(unit blot:tarball)
      snap=(unit snap-12)
      snap-id=@uvJ
  ==
+$  peeks-12  (map [rail:tarball wire] peek-12)
+$  remo-12   [peeks=peeks-12 snaps=snaps:remo:nexus]
++  top-12
  |=  h=hist-12
  ^-  (unit cass:clay)
  =/  got=(unit [key=cass:clay val=entry-12])  (ram:hon-12 h)
  ?~(got ~ `key.u.got)
::  state-13: a version cannot say the path held nothing. What exists is
::  $peak's answer -- a peak above born's top is a path that no longer
::  does -- and what it held is born's. The two no longer blur.
::
+$  state-13
  $:  %13
      =born:nexus
      =peak:nexus
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      =remo:nexus
      =upki:nexus
      =last:nexus
      conns=(map @ta binding:eyre)
  ==
++  state-12-to-13
  |=  old=state-12
  ^-  state-13
  :*  %13
      (born-12-to-born born.old)
      peak.old
      silo.old  subs.old  pool.old  code.old
      bins.old  vale.old  (remo-12-to-remo remo.old)  upki.old  last.old
      conns.old
  ==
::  Every null reference goes. A version that referenced nothing was one
::  of two things and neither survives: +init's placeholder, a leftover
::  of the old [%file ~] / [%fold ~] kind sentinel, and the marker a
::  deletion used to append. A rail left with no versions goes with
::  them -- it kept no history, and $peak still holds its number, so a
::  later grub there still numbers above it.
::
::  Nothing is released: these paces name no ject, so they hold no silo
::  refs to drop.
::
::  a staged peek whose negotiated pace referenced nothing cannot be
::  represented, and could not have been read anyway: the snap goes and
::  the peek renegotiates.
::
++  remo-12-to-remo
  |=  r=remo-12
  ^-  remo:nexus
  :_  snaps.r
  %-  ~(run by peeks.r)
  |=  p=peek-12
  ^-  peek:remo:nexus
  :*  ship.p
      dest.p
      deep.p
      blot.p
      ?~  snap.p  ~
      ?:  ?=(%tomb -.pace.u.snap.p)
        `[cass.u.snap.p [%tomb ~] refs.u.snap.p]
      ?~  p.pace.u.snap.p  ~
      :-  ~
      :+  cass.u.snap.p
        ?-  -.pace.u.snap.p
          %firm  [%firm u.p.pace.u.snap.p]
          %temp  [%temp u.p.pace.u.snap.p]
        ==
      refs.u.snap.p
      snap-id.p
  ==
::
++  born-12-to-born
  |=  b=born-12
  ^-  born:nexus
  :-  ?~  fil.b  ~
      =/  files=(map @ta hist:nexus)
        %-  ~(gas by *(map @ta hist:nexus))
        %+  murn  ~(tap by file.u.fil.b)
        |=  [nom=@ta h=hist-12]
        ^-  (unit [@ta hist:nexus])
        =/  kept=hist:nexus  (hist-12-to-hist h)
        ?:  =(~ kept)  ~
        `[nom kept]
      `[(hist-12-to-hist fold.u.fil.b) files]
  (~(run by dir.b) born-12-to-born)
::
++  hist-12-to-hist
  |=  h=hist-12
  ^-  hist:nexus
  %+  gas:hon:hist:nexus  *hist:nexus
  %+  murn  (tap:hon-12 h)
  |=  [key=cass:clay val=entry-12]
  ^-  (unit [cass:clay entry:hist:nexus])
  ?:  ?=(%tomb -.pace.val)  `[key [[%tomb ~] tags.val]]
  ?~  p.pace.val  ~
  :+  ~  key
  :_  tags.val
  ?-  -.pace.val
    %firm  [%firm u.p.pace.val]
    %temp  [%temp u.p.pace.val]
  ==
::
+|  %pool-0-to-1
::
++  pool-0-to-1
  |=  p=pool-0
  ^-  pool-1
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-0-to-1)]
  (~(run by dir.p) pool-0-to-1)
::
++  proc-0-to-1
  |=  p=proc-0
  ^-  proc-1
  :+  ?:  ?=(%| -.process.p)  process.p
      ::  cannot happen: bang-pool replaces every live process with a
      ::  %| tang before save. Defensive: never resume an old gate.
      |+~[leaf+"migrated: process rebuilt on load"]
    (takes-0-to-1 next.p)
  (takes-0-to-1 skip.p)
::
++  takes-0-to-1
  |=  q=(qeu take-0)
  ^-  (qeu take-1)
  %-  ~(gas to *(qeu take-1))
  (turn ~(tap to q) take-0-to-1)
::
++  take-0-to-1
  |=  t=take-0
  ^-  take-1
  :-  give.t
  ?~  in.t  ~
  `(pend-0-to-1 u.in.t)
::
++  pend-0-to-1
  |=  p=pend-0
  ^-  pend-1
  ?.  ?=(%veto -.p)  p
  [%veto (dart-0-to-1 dart.p)]
::
++  dart-0-to-1
  |=  d=dart-0
  ^-  dart-1
  ?.  ?=(%node -.d)  d
  [%node wire.d road.d (load-0-to-1 load.d)]
::
++  load-0-to-1
  |=  l=load-0
  ^-  load-1
  ?.  ?=(%make -.l)  l
  [%make force.l %.n make.l]
::
+|  %pool-1-to-3
::
++  pool-1-to-pool
  |=  p=pool-1
  ^-  pool-3
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-1-to-3)]
  (~(run by dir.p) pool-1-to-pool)
::
++  proc-1-to-3
  |=  p=proc-1
  ^-  proc-3
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load"]
    (takes-1-to-3 next.p)
  (takes-1-to-3 skip.p)
::
++  takes-1-to-3
  |=  q=(qeu take-1)
  ^-  (qeu take-3)
  %-  ~(gas to *(qeu take-3))
  (turn ~(tap to q) take-1-to-3)
::
++  take-1-to-3
  |=  t=take-1
  ^-  take-3
  :-  give.t
  ?~  in.t  ~
  `(pend-1-to-3 u.in.t)
::
++  pend-1-to-3
  |=  p=pend-1
  ^-  pend-3
  ?.  ?=(%veto -.p)  p
  [%veto (dart-1-to-3 dart.p)]
::
++  dart-1-to-3
  |=  d=dart-1
  ^-  dart-3
  ?.  ?=(%node -.d)  d
  [%node wire.d road.d (load-1-to-3 load.d)]
::
++  load-1-to-3
  |=  l=load-1
  ^-  load-3
  ?.  ?=(%tag -.l)  l
  [%tags case.l tags.l]
::
+|  %pool-3-to-10
::  Drops what no longer exists: a queued %font take, and a vetoed dart
::  whose load was %font. Everything else passes through. The result is
::  the %10 pool: states %4 through %10 share that shape.
::
++  pool-3-to-pool
  |=  p=pool-3
  ^-  pool-10
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-3-to-proc)]
  (~(run by dir.p) pool-3-to-pool)
::
++  proc-3-to-proc
  |=  p=proc-3
  ^-  proc-10
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load"]
    (takes-3-to-takes next.p)
  (takes-3-to-takes skip.p)
::
++  takes-3-to-takes
  |=  q=(qeu take-3)
  ^-  (qeu take-10)
  %-  ~(gas to *(qeu take-10))
  (murn ~(tap to q) take-3-to-take)
::
++  take-3-to-take
  |=  t=take-3
  ^-  (unit take-10)
  ?~  in.t  `[give.t ~]
  =/  p=(unit pend-10)  (pend-3-to-pend u.in.t)
  ?~  p  ~
  `[give.t p]
::
++  pend-3-to-pend
  |=  p=pend-3
  ^-  (unit pend-10)
  ?:  ?=(%font -.p)  ~
  ?.  ?=(%veto -.p)  `p
  ?:  ?=([%node * * %font ~] dart.p)  ~
  `[%veto (dart-3-to-dart dart.p)]
::
++  dart-3-to-dart
  |=  d=dart-3
  ^-  dart-11
  ?.  ?=(%node -.d)  d
  ?<  ?=(%font -.load.d)
  [%node wire.d road.d load.d]
::
+|  %code-2-to-4
::  Per lode: the sentinel pair becomes the subject node's key under
::  sut-rail:nexus; every other key keeps its (single) hash; every
::  file's deps gain the subject; the subject node has no deps. refs
::  are unchanged. The old ckeys were computed with the subject hash
::  folded in explicitly rather than via dep-keys, so they will not
::  match new keys on the next build — one full recompile per
::  namespace, then steady state. Correct and loud.
::
++  code-2-to-4
  |=  c=code-2
  ^-  code-4
  %-  ~(run by c)
  |=  l=lode-2
  ^-  lode-4
  =/  sut-key=(unit @uv)
    =/  pair  (~(get by keys.l) sut-rail-2)
    ?~(pair ~ `in.u.pair)
  =/  =keys:nexus
    %-  ~(gas by *keys:nexus)
    %+  murn  ~(tap by keys.l)
    |=  [r=rail:tarball in=@uv out=@uv]
    ?:  =(sut-rail-2 r)  ~
    `[r in]
  =?  keys  ?=(^ sut-key)  (~(put by keys) sut-rail:nexus u.sut-key)
  =/  =deps:nexus
    %+  ~(put by (~(run by deps.l) |=(s=(set rail:tarball) (~(put in s) sut-rail:nexus))))
      sut-rail:nexus
    ~
  [keys deps refs.l]
::
+|  %code-4-to-live
::  Drop refs. keys already maps every artifact's source rail to its
::  key; the stem-keyed axal was the same information.
::
++  code-4-to-code
  |=  c=code-4
  ^-  code:nexus
  (~(run by c) |=(l=lode-4 `lode:nexus`[keys.l deps.l]))
--
