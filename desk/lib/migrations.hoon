::  migrations: agent state versions
::
::  Deliberately empty of migration machinery. The runtime's core
::  data structures are still moving too fast for migrations to be
::  worth their weight — on a breaking state change, nuke the agent
::  and start fresh at %0. Real migrations begin once the core
::  structures stabilize (see ratchet.md).
::
/+  nexus
|%
::  state-0: current — uses live nexus types
::
+$  state-0
  $:  %0
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
--
