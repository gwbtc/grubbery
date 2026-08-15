::  migrations: agent state versions
::
::  The default policy is still nuke-and-restart: the runtime's core
::  data structures move too fast for every breaking change to earn a
::  migration (see ratchet.md). A migration appears here only when a
::  change is cheap to cross and the alternative is losing truth
::  fields on a live pier. First case: the %grow/%tomb/%keen widening
::  of the load union, which breaks the saved pool's *type* while
::  every saved *value* still fits — see +state-0-narrow below.
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
::  Same fields, same %0 tag; the difference hides in pool. A fiber
::  process is an iron gate whose sample embeds the load fork, and
::  iron samples are contravariant: against the widened fork the
::  saved pool's type no longer nests, so a plain !< refuses the
::  whole vase — even though every saved *value* still fits, since
::  %grow, %tomb, and %keen did not exist when it was written.
::
::  We do not vendor the pre-widening fiber types to read it. A live
::  gate cannot cross a reload in any case, and everything else those
::  slots can hold nests under %noun — so the changed slots are typed
::  as raw nouns here (the nest check passes trivially) and
::  +state-0-narrow-to-0 remolds their values under today's types,
::  shedding what cannot cross. +on-save banged every live process to
::  a %| crash tang before the vase was written, so the salvageable
::  content is exactly: crash tangs, and queued cold takes whose
::  narrow-load values are a strict subset of the wide-load union.
::
+$  proc-narrow
  $:  process=(each * tang)  ::  %&: a live gate, cannot cross; %|: crash tang
      next=(qeu *)           ::  queued takes, remolded by +remold-queue
      skip=(qeu *)           ::  ditto
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
::  narrow -> 0: rebuild the pool under the widened types; every
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
        ::  should be unreachable — +on-save bangs every live process
        ::  before the vase is written — but a gate that somehow got
        ::  here cannot cross, so shed it; a prod respawns from source
        ::
        %&
      %.  |+~[leaf+"process shed by the load-union migration; prod to respawn"]
      %+  slog
        leaf+"grubbery-migrate: shed live process at {gnome} (+on-save bangs these; seeing one is a bug)"
      ~
    ==
  :+  pro
    (remold-queue gnome "next" next.old)
  (remold-queue gnome "skip" skip.old)
::  +remold-queue: re-type a queue of narrow takes under the wide
::  types. Narrow load values are a strict subset of wide ones, so
::  the whole queue is expected to remold noun-identically in one
::  pass; if it does not, salvage element-wise and shed (with a slog)
::  whatever will not fit. The salvage path rebuilds via tap/put, so
::  it preserves order only as well as those do — acceptable for a
::  path that only runs on data that is already damaged.
::
++  remold-queue
  |=  [gnome=tape which=tape raw=(qeu *)]
  ^-  (qeu take:fiber:nexus)
  =/  whole  (mule |.(;;((qeu take:fiber:nexus) raw)))
  ?:  ?=(%& -.whole)  p.whole
  =/  els=(list *)  ~(tap to raw)
  =|  out=(qeu take:fiber:nexus)
  =|  shed=@ud
  |-  ^-  (qeu take:fiber:nexus)
  ?~  els
    ?:  =(0 shed)  out
    %.  out
    %+  slog
      leaf+"grubbery-migrate: shed {<shed>} queued input(s) from the {which} queue of {gnome}"
    ~
  =/  try  (mule |.(;;(take:fiber:nexus i.els)))
  ?:  ?=(%& -.try)
    $(els t.els, out (~(put to out) p.try))
  $(els t.els, shed +(shed))
--
