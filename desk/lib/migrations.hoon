::  migrations: old state types and migration functions for grubbery
::
::  state-0: pre-pend era. take used (unit intake) directly.
::  Only pool needs reset (take changed from (unit intake) to (unit pend)).
::  Everything else carries over. pool=* because we don't use the old
::  pool data — it gets bunted away, so the exact old type doesn't matter.
::
/+  nexus
|%
+$  state-0
  $:  %0
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
+$  state-1
  $:  %1
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
      remo.old
      upki.old
      last.old
  ==
--
