::  migrations: agent state versions
::
::  The default policy is nuke-and-restart. The runtime's core data
::  structures move too fast for every breaking change to earn a
::  migration (see ratchet.md). A migration appears here only when a
::  change is cheap to cross and the alternative is losing truth
::  fields on a live pier. The first case is the %grow/%tomb/%keen
::  widening of the load union, which breaks the saved pool's *type*
::  while every saved *value* still fits. See +state-0-narrow below.
::
/+  nexus, tarball
|%
::  state-0: the full state of the grubbery agent.
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
      =pool:nexus   ::  live: the running process for each grub
      =code:nexus   ::  derived: the build index for each code namespace
      =bins:nexus   ::  derived: compiled artifacts, keyed by build hash
      =vale:nexus   ::  derived: cached validation results
      =remo:nexus   ::  live: pending cross-ship peeks and pinned snapshots
      =upki:nexus   ::  live: the rail that backs jael pki subscriptions
      =last:nexus   ::  live: monotonic time and entropy for the bowl
  ==
::  state-0-narrow: the %0 state as saved by code from before the
::  %grow/%tomb/%keen widening of the load union.
::
::  Same fields, same %0 tag. The difference hides in pool. A fiber
::  process is an iron gate whose sample embeds the load fork, and
::  iron samples are contravariant. Against the widened fork the
::  saved pool's type does not nest, so a plain !< refuses the
::  whole vase. Every saved *value* still fits, since no
::  pre-widening vase can contain a %grow, %tomb, or %keen.
::
::  This reader never vendors the pre-widening fiber types. A live
::  gate cannot cross a reload in any case, so ONLY the process slot is
::  typed as a raw noun (the nest check passes trivially) and
::  +state-0-narrow-to-0 sheds it. The queues are deliberately typed at
::  TODAY'S take. A queue is a reading position, so the nest check is
::  covariant, and an additively-widened load/pend union always accepts
::  the older queues as they are, noun-untouched. Narrowing the queues
::  to (qeu *) here would be worse than useless. It would make this
::  narrow state accept a vase whose queue elements do NOT fit today's
::  types, and the remold would then silently shed queued takes, each
::  one carrying a give, an ack a poking fiber waits on forever. Typed
::  at take, a genuinely incompatible future change fails BOTH decodes
::  and gall rejects the upgrade atomically, which is the contract.
::
+$  proc-narrow
  $:  process=(each * tang)  ::  %&: a live gate, cannot cross; %|: crash tang
      next=(qeu take:fiber:nexus)   ::  covariant: old takes nest as-is
      skip=(qeu take:fiber:nexus)   ::  ditto
  ==
+$  pipe-narrow  [bang=(unit tang) proc=(map @ta proc-narrow)]
+$  pool-narrow  (axal pipe-narrow)
+$  state-0-narrow
  $:  %0
      =born:nexus
      =silo:nexus
      =subs:nexus
      pool=pool-narrow
      =code:nexus
      =bins:nexus
      =vale:nexus
      =remo:nexus
      =upki:nexus
      =last:nexus
  ==
::  narrow -> 0: rebuild the pool under the widened types. Every
::  other field's type is unchanged and passes through untouched.
::
++  state-0-narrow-to-0
  |=  old=state-0-narrow
  ^-  state-0
  :*  %0
      born.old
      silo.old
      subs.old
      (pool-narrow-to-pool pool.old)
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
::
++  pool-narrow-to-pool
  =|  here=path
  |=  old=pool-narrow
  ^-  pool:nexus
  :-  ?~  fil.old  ~
      `(pipe-narrow-to-pipe here u.fil.old)
  %-  ~(urn by dir.old)
  |=  [nom=@ta kid=pool-narrow]
  ^$(here (snoc here nom), old kid)
::
++  pipe-narrow-to-pipe
  |=  [here=path old=pipe-narrow]
  ^-  pipe:nexus
  :-  bang.old
  %-  ~(urn by proc.old)
  |=  [nom=@ta pro=proc-narrow]
  (proc-narrow-to-proc [here nom] pro)
::
++  proc-narrow-to-proc
  |=  [here=rail:tarball old=proc-narrow]
  ^-  proc:fiber:nexus
  =/  gnome=tape  (spud (snoc path.here name.here))
  =/  pro=(each process:fiber:nexus tang)
    ?-    -.process.old
        %|  |+p.process.old
        ::  Should be unreachable, since +on-save bangs every live
        ::  process before the vase is written. A gate that somehow
        ::  got here cannot cross, so shed it. A prod respawns from
        ::  source.
        ::
        %&
      %.  |+~[leaf+"process shed by the load-union migration; prod to respawn"]
      %+  slog
        leaf+"grubbery-migrate: shed live process at {gnome} (+on-save bangs these; seeing one is a bug)"
      ~
    ==
  [pro next.old skip.old]
--
