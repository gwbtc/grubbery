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
      =code:nexus   ::  derived: the build index for each code namespace
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
      =code:nexus   ::  derived: the build index for each code namespace
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-2: %tag renamed %tags. Same fields, live types.
::
+$  state-2
  $:  %2
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
+|  %pool-1-to-live
::
++  pool-1-to-pool
  |=  p=pool-1
  ^-  pool:nexus
  :-  ?~  fil.p  ~
      `[bang.u.fil.p (~(run by proc.u.fil.p) proc-1-to-proc)]
  (~(run by dir.p) pool-1-to-pool)
::
++  proc-1-to-proc
  |=  p=proc-1
  ^-  proc:fiber:nexus
  :+  ?:  ?=(%| -.process.p)  process.p
      |+~[leaf+"migrated: process rebuilt on load"]
    (takes-1-to-takes next.p)
  (takes-1-to-takes skip.p)
::
++  takes-1-to-takes
  |=  q=(qeu take-1)
  ^-  (qeu take)
  %-  ~(gas to *(qeu take))
  (turn ~(tap to q) take-1-to-take)
::
++  take-1-to-take
  |=  t=take-1
  ^-  take
  :-  give.t
  ?~  in.t  ~
  `(pend-1-to-pend u.in.t)
::
++  pend-1-to-pend
  |=  p=pend-1
  ^-  pend
  ?.  ?=(%veto -.p)  p
  [%veto (dart-1-to-dart dart.p)]
::
++  dart-1-to-dart
  |=  d=dart-1
  ^-  dart:nexus
  ?.  ?=(%node -.d)  d
  [%node wire.d road.d (load-1-to-load load.d)]
::
++  load-1-to-load
  |=  l=load-1
  ^-  load:nexus
  ?.  ?=(%tag -.l)  l
  [%tags case.l tags.l]
--
