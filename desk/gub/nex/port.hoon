::  port: the authenticated typed-message ingress.
::
::  Every /port/<endpoint> is a [/port %cargo] = (unit [from mime]) grub
::  that HANDLES ITS OWN pokes: poke it with a mime and it stamps the
::  authenticated sender (from the poke, not self-reported) and replaces
::  its own state. History is the message stream + the made-by/modified-by
::  lineage. Open an endpoint by making an empty (~) cargo grub; reads are
::  just files — peek what's here, or drop your own inert files to be read.
::  Everything is a file — poked.
::
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  ::  preserve everything already here — endpoints are made directly and
  ::  must survive reloads. This nexus seeds nothing of its own.
  %+  spin:loader  ball
  :~  [%load %| / / same-fold:loader]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ::  any cargo grub handles its own pokes; everything else is inert.
  ?.  =(blot `blot:tarball`[/port %cargo])  stay:m
  ;<  ~  bind:m  (rise-wait:io prod "%port cargo: failed")
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  =/  mim=(unit mime)  (mole |.(!<(mime q.sage)))
  ?~  mim
    ~&  >>>  "%port cargo: expects a mime poke"
    $
  ;<  ~  bind:m  (replace:io `(unit [from=rail:tarball =mime])``[q.from u.mim])
  $
--
