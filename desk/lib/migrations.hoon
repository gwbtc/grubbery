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
/+  nexus
|%
::  old pace type (no tags on %firm)
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
      (upgrade-born born.old)
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
++  upgrade-born
  |=  ob=old-born
  ^-  born:nexus
  :-  (bind fil.ob upgrade-node)
  (~(run by dir.ob) upgrade-born)
::
++  upgrade-node
  |=  [fold=hist:old-hist file=(map @ta hist:old-hist)]
  :_  (~(run by file) upgrade-hist)
  (upgrade-hist fold)
::
++  upgrade-hist
  |=  sk=hist:old-hist
  ^-  hist:nexus
  =/  entries=(list [cas=cass:clay pac=old-pace])
    (tap:hon:old-hist sk)
  =/  new=hist:nexus  *hist:nexus
  |-
  ?~  entries  new
  =/  new-pace=pace:hist:nexus
    ?-  -.pac.i.entries
      %firm  [%firm ~ p.pac.i.entries]
      %temp  [%temp ~ p.pac.i.entries]
      %tomb  [%tomb ~]
    ==
  $(entries t.entries, new (put:hon:hist:nexus new cas.i.entries new-pace))
--
