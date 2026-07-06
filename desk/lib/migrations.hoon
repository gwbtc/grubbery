::  migrations: old state types and migration functions for grubbery
::
::  Each state version gets a core (++state-N) that snapshots the
::  exact types live when that version was persisted. Only the
::  current state references live nexus types. When adding a new
::  version: snapshot the current types into a new core and define
::  the new state with live types.
::
::  WARNING: every migration resets pool, killing all running fibers.
::  Acceptable during development; post-release, pool migrations must
::  preserve running state or gracefully drain.
::
/+  nexus
|%
::  state-0/1: no tags on pace
::
++  state-0
  =<  state-0
  |%
  +$  state-0
    $:  %0
        =born
        =silo:nexus
        =subs:nexus
        pool=*
        =code:nexus
        =bins:nexus
        =vale:nexus
        remo=*
        =upki:nexus
        last=[now=@da eny=@uvJ]
    ==
  +$  pace
    $%  [%firm p=(unit lobe:clay)]
        [%temp p=(unit lobe:clay)]
        [%tomb ~]
    ==
  ++  hist
    =<  hist
    |%
    ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
    +$  hist  ((mop cass:clay pace) cor)
    ++  hon    ((on cass:clay pace) cor)
    --
  +$  born  (axal [fold=hist:hist file=(map @ta hist:hist)])
  --
::
++  state-1
  =<  state-1
  |%
  +$  state-1
    $:  %1
        =born
        =silo:nexus
        =subs:nexus
        pool=*
        =code:nexus
        =bins:nexus
        =vale:nexus
        remo=*
        =upki:nexus
        last=[now=@da eny=@uvJ]
    ==
  +$  pace
    $%  [%firm p=(unit lobe:clay)]
        [%temp p=(unit lobe:clay)]
        [%tomb ~]
    ==
  ++  hist
    =<  hist
    |%
    ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
    +$  hist  ((mop cass:clay pace) cor)
    ++  hon    ((on cass:clay pace) cor)
    --
  +$  born  (axal [fold=hist:hist file=(map @ta hist:hist)])
  --
::  state-2: tags on pace
::
++  state-2
  =<  state-2
  |%
  +$  state-2
    $:  %2
        =born
        =silo:nexus
        =subs:nexus
        pool=*
        =code:nexus
        =bins:nexus
        =vale:nexus
        remo=*
        =upki:nexus
        last=[now=@da eny=@uvJ]
    ==
  +$  pace
    $%  [%firm tags=(set @t) p=(unit lobe:clay)]
        [%temp tags=(set @t) p=(unit lobe:clay)]
        [%tomb ~]
    ==
  ++  hist
    =<  hist
    |%
    ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
    +$  hist  ((mop cass:clay pace) cor)
    ++  hon    ((on cass:clay pace) cor)
    --
  +$  born  (axal [fold=hist:hist file=(map @ta hist:hist)])
  --
::  state-3: tags next to pace (entry wrapper)
::
++  state-3
  =<  state-3
  |%
  +$  state-3
    $:  %3
        =born
        =silo:nexus
        =subs:nexus
        pool=*
        =code:nexus
        =bins:nexus
        =vale:nexus
        =remo:nexus
        =upki:nexus
        last=[now=@da eny=@uvJ]
    ==
  +$  pace
    $%  [%firm p=(unit lobe:clay)]
        [%temp p=(unit lobe:clay)]
        [%tomb ~]
    ==
  +$  entry  [=pace tags=(set @t)]
  ++  hist
    =<  hist
    |%
    ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
    +$  hist  ((mop cass:clay entry) cor)
    ++  hon    ((on cass:clay entry) cor)
    --
  +$  born  (axal [fold=hist:hist file=(map @ta hist:hist)])
  --
::  state-4: current — uses live nexus types
::
+$  state-4
  $:  %4
      =born:nexus
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      =remo:nexus
      =upki:nexus
      last=[now=@da eny=@uvJ]
  ==
::
++  migrate-0-to-1
  |=  [old=state-0 now=@da eny=@uvJ]
  ^-  state-1
  ~&  >  "%grubbery: migrating %0 -> %1 (resetting pool)"
  :*  %1
      born.old
      silo.old
      subs.old
      *pool:nexus
      code.old
      bins.old
      vale.old
      *remo:nexus
      upki.old
      last.old
  ==
::
++  migrate-1-to-2
  |=  old=state-1
  ^-  state-2
  ~&  >  "%grubbery: migrating %1 -> %2 (adding tags to born)"
  :*  %2
      (upgrade-born-1-to-2 born.old)
      silo.old
      subs.old
      *pool:nexus
      code.old
      bins.old
      vale.old
      *remo:nexus
      upki.old
      last.old
  ==
::
++  upgrade-born-1-to-2
  |=  =born:state-1
  ^-  born:state-2
  :-  (bind fil.born upgrade-node-1-to-2)
  (~(run by dir.born) upgrade-born-1-to-2)
::
++  upgrade-node-1-to-2
  |=  [fold=hist:hist:state-1 file=(map @ta hist:hist:state-1)]
  :_  (~(run by file) upgrade-hist-1-to-2)
  (upgrade-hist-1-to-2 fold)
::
++  upgrade-hist-1-to-2
  |=  sk=hist:hist:state-1
  ^-  hist:hist:state-2
  =/  entries=(list [cas=cass:clay pac=pace:state-1])
    (tap:hon:hist:state-1 sk)
  =/  new=hist:hist:state-2  *hist:hist:state-2
  |-
  ?~  entries  new
  =/  new-pace=pace:state-2
    ?-  -.pac.i.entries
      %firm  [%firm ~ p.pac.i.entries]
      %temp  [%temp ~ p.pac.i.entries]
      %tomb  [%tomb ~]
    ==
  $(entries t.entries, new (put:hon:hist:state-2 new cas.i.entries new-pace))
::
++  migrate-2-to-3
  |=  old=state-2
  ^-  state-3
  ~&  >  "%grubbery: migrating %2 -> %3 (tags next to pace)"
  :*  %3
      (upgrade-born-2-to-3 born.old)
      silo.old
      subs.old
      *pool:nexus
      code.old
      bins.old
      vale.old
      *remo:nexus
      upki.old
      last.old
  ==
::
++  upgrade-born-2-to-3
  |=  =born:state-2
  ^-  born:state-3
  :-  (bind fil.born upgrade-node-2-to-3)
  (~(run by dir.born) upgrade-born-2-to-3)
::
++  upgrade-node-2-to-3
  |=  [fold=hist:hist:state-2 file=(map @ta hist:hist:state-2)]
  :_  (~(run by file) upgrade-hist-2-to-3)
  (upgrade-hist-2-to-3 fold)
::
++  upgrade-hist-2-to-3
  |=  sk=hist:hist:state-2
  ^-  hist:hist:state-3
  =/  entries=(list [cas=cass:clay pac=pace:state-2])
    (tap:hon:hist:state-2 sk)
  =/  new=hist:hist:state-3  *hist:hist:state-3
  |-
  ?~  entries  new
  =/  =entry:state-3
    ?-  -.pac.i.entries
      %firm  [[%firm p.pac.i.entries] tags.pac.i.entries]
      %temp  [[%temp p.pac.i.entries] tags.pac.i.entries]
      %tomb  [[%tomb ~] ~]
    ==
  $(entries t.entries, new (put:hon:hist:state-3 new cas.i.entries entry))
::
++  migrate-3-to-4
  |=  old=state-3
  ^-  state-4
  ~&  >  "%grubbery: migrating %3 -> %4 (resetting pool for %tag load)"
  :*  %4
      born.old
      silo.old
      subs.old
      *pool:nexus
      code.old
      bins.old
      vale.old
      remo.old
      upki.old
      last.old
  ==
--
