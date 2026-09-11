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
+$  keys-2  (map rail:tarball [in=@uv out=@uv])
+$  lode-2  [keys=keys-2 =deps:nexus =refs:nexus]
+$  code-2  (map fold:tarball lode-2)
++  sut-rail-2  `rail:tarball`[/ %$]
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
      =born:nexus   ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-0   ::  live: the running process for each grub (frozen)
      code=code-2   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-1: %make loads carry gain=?. Pool frozen (still %tag).
::
+$  state-1
  $:  %1
      =born:nexus   ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-1   ::  live: the running process for each grub (frozen)
      code=code-2   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-2: %tag renamed %tags. Pool frozen (still %font); code frozen
::  (two-key lode).
::
+$  state-2
  $:  %2
      =born:nexus   ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-3   ::  live: the running process for each grub (frozen)
      code=code-2   ::  derived: the build index for each code namespace (frozen)
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-3: one key per rail, subject as a dep. Pool frozen (still %font).
::
+$  state-3
  $:  %3
      =born:nexus   ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      pool=pool-3   ::  live: the running process for each grub (frozen)
      =code:nexus   ::  derived: the build index for each code namespace
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::
::  state-4: no %font. Same fields, live types.
::
+$  state-4
  $:  %4
      =born:nexus   ::  truth: version history for every directory and file
      =silo:nexus   ::  truth: content-addressed object store with refcounts
      =subs:nexus   ::  live: subscription indexes, by target and by watcher
      =pool:nexus   ::  live: the running process for each grub
      =code:nexus   ::  derived: the build index for each code namespace
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
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
      (code-2-to-code code.old)
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
+|  %pool-3-to-live
::  Drops what no longer exists: a queued %font take, and a vetoed dart
::  whose load was %font. Everything else passes through.
::
++  pool-3-to-pool
  |=  p=pool-3
  ^-  pool:nexus
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-3-to-proc)]
  (~(run by dir.p) pool-3-to-pool)
::
++  proc-3-to-proc
  |=  p=proc-3
  ^-  proc:fiber:nexus
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load"]
    (takes-3-to-takes next.p)
  (takes-3-to-takes skip.p)
::
++  takes-3-to-takes
  |=  q=(qeu take-3)
  ^-  (qeu take)
  %-  ~(gas to *(qeu take))
  (murn ~(tap to q) take-3-to-take)
::
++  take-3-to-take
  |=  t=take-3
  ^-  (unit take)
  ?~  in.t  `[give.t ~]
  =/  p=(unit pend)  (pend-3-to-pend u.in.t)
  ?~  p  ~
  `[give.t p]
::
++  pend-3-to-pend
  |=  p=pend-3
  ^-  (unit pend)
  ?:  ?=(%font -.p)  ~
  ?.  ?=(%veto -.p)  `p
  ?:  ?=([%node * * %font ~] dart.p)  ~
  `[%veto (dart-3-to-dart dart.p)]
::
++  dart-3-to-dart
  |=  d=dart-3
  ^-  dart:nexus
  ?.  ?=(%node -.d)  d
  ?<  ?=(%font -.load.d)
  [%node wire.d road.d load.d]
::
+|  %code-2-to-live
::  Per lode: the sentinel pair becomes the subject node's key under
::  sut-rail:nexus; every other key keeps its (single) hash; every
::  file's deps gain the subject; the subject node has no deps. refs
::  are unchanged. The old ckeys were computed with the subject hash
::  folded in explicitly rather than via dep-keys, so they will not
::  match new keys on the next build — one full recompile per
::  namespace, then steady state. Correct and loud.
::
++  code-2-to-code
  |=  c=code-2
  ^-  code:nexus
  %-  ~(run by c)
  |=  l=lode-2
  ^-  lode:nexus
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
--
