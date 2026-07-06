::  migrations: old state types and migration functions for grubbery
::
::  state-0: pre-pend era. take used (unit intake) directly.
::  Only pool needs reset (take changed from (unit intake) to (unit pend)).
::  pool=* because old pool type no longer matters — gets bunted away.
::
::  state-1: pre-tags era. pace had no tags field.
::  born needs migration to add tags=(set @t) on pace entries.
::  remo contains snap which references pace — blown away.
::
::  state-2: tags-on-pace era. tags lived inside %firm/%temp pace variants.
::  Refactored to tags-next-to-pace: hist entry is now [=pace tags=(set @t)].
::  born needs migration to unwrap tags from pace into entry wrapper.
::  remo snap references pace — blown away.
::
/+  nexus
|%
::  old pace type (state-0/1: no tags)
+$  old-pace
  $%  [%firm p=(unit lobe:clay)]
      [%temp p=(unit lobe:clay)]
      [%tomb ~]
  ==
++  old-hist
  =<  hist
  |%
  ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
  +$  hist  ((mop cass:clay old-pace) cor)
  ++  hon    ((on cass:clay old-pace) cor)
  --
+$  old-born  (axal [fold=hist:old-hist file=(map @ta hist:old-hist)])
::
::  mid pace type (state-2: tags on firm/temp)
+$  mid-pace
  $%  [%firm tags=(set @t) p=(unit lobe:clay)]
      [%temp tags=(set @t) p=(unit lobe:clay)]
      [%tomb ~]
  ==
++  mid-hist
  =<  hist
  |%
  ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
  +$  hist  ((mop cass:clay mid-pace) cor)
  ++  hon    ((on cass:clay mid-pace) cor)
  --
+$  mid-born  (axal [fold=hist:mid-hist file=(map @ta hist:mid-hist)])
::
+$  state-0
  $:  %0
      born=old-born
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
::
+$  state-1
  $:  %1
      born=old-born
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=*            :: snap references pace (now has tags) — reset
      =upki:nexus
      last=[now=@da eny=@uvJ]
  ==
::
+$  state-2
  $:  %2
      born=mid-born
      =silo:nexus
      =subs:nexus
      =pool:nexus
      =code:nexus
      =bins:nexus
      =vale:nexus
      remo=*            :: snap references mid-pace — reset
      =upki:nexus
      last=[now=@da eny=@uvJ]
  ==
::
+$  state-3
  $:  %3
      =born:nexus
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
      pool.old
      code.old
      bins.old
      vale.old
      *remo:nexus
      upki.old
      last.old
  ==
::
++  upgrade-born-1-to-2
  |=  ob=old-born
  ^-  mid-born
  :-  (bind fil.ob upgrade-node-1-to-2)
  (~(run by dir.ob) upgrade-born-1-to-2)
::
++  upgrade-node-1-to-2
  |=  [fold=hist:old-hist file=(map @ta hist:old-hist)]
  :_  (~(run by file) upgrade-hist-1-to-2)
  (upgrade-hist-1-to-2 fold)
::
++  upgrade-hist-1-to-2
  |=  sk=hist:old-hist
  ^-  hist:mid-hist
  =/  entries=(list [cas=cass:clay pac=old-pace])
    (tap:hon:old-hist sk)
  =/  new=hist:mid-hist  *hist:mid-hist
  |-
  ?~  entries  new
  =/  new-pace=mid-pace
    ?-  -.pac.i.entries
      %firm  [%firm ~ p.pac.i.entries]
      %temp  [%temp ~ p.pac.i.entries]
      %tomb  [%tomb ~]
    ==
  $(entries t.entries, new (put:hon:mid-hist new cas.i.entries new-pace))
::
++  migrate-2-to-3
  |=  old=state-2
  ^-  state-3
  ~&  >  "%grubbery: migrating %2 -> %3 (tags next to pace)"
  :*  %3
      (upgrade-born-2-to-3 born.old)
      silo.old
      subs.old
      pool.old
      code.old
      bins.old
      vale.old
      *remo:nexus
      upki.old
      last.old
  ==
::
++  upgrade-born-2-to-3
  |=  ob=mid-born
  ^-  born:nexus
  :-  (bind fil.ob upgrade-node-2-to-3)
  (~(run by dir.ob) upgrade-born-2-to-3)
::
++  upgrade-node-2-to-3
  |=  [fold=hist:mid-hist file=(map @ta hist:mid-hist)]
  :_  (~(run by file) upgrade-hist-2-to-3)
  (upgrade-hist-2-to-3 fold)
::
++  upgrade-hist-2-to-3
  |=  sk=hist:mid-hist
  ^-  hist:nexus
  =/  entries=(list [cas=cass:clay pac=mid-pace])
    (tap:hon:mid-hist sk)
  =/  new=hist:nexus  *hist:nexus
  |-
  ?~  entries  new
  =/  =entry:hist:nexus
    ?-  -.pac.i.entries
      %firm  [[%firm p.pac.i.entries] tags.pac.i.entries]
      %temp  [[%temp p.pac.i.entries] tags.pac.i.entries]
      %tomb  [[%tomb ~] ~]
    ==
  $(entries t.entries, new (put:hon:hist:nexus new cas.i.entries entry))
::
::  WARNING: pool reset is destructive — kills all running fibers.
::  Acceptable during development; post-release, pool migrations must
::  preserve running state or gracefully drain.
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
