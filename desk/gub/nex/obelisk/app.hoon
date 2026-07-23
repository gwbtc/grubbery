/<  odb  /lib/nex/obelisk-db.hoon
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      (db-entry:odb %'db.obelisk_server')
  ==
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+  rail  stay:m
      [~ %'db.obelisk_server']
    (db-spool:odb prod)
  ==
--
