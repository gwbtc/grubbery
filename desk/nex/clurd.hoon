::  clurd nexus: programmatic dill terminal access
::
::  Tree layout:
::    /main.sig         main process (currently unused)
::
::  Blit rendering lives in lib/nex/clurd.hoon.
::  MCP tools (read-terminal, run-dojo, read-logs) use it directly.
::  All terminal data lives in /sys/dill/ (managed by root + grubbery).
::
/+  nexus, tarball, io=fiberio
!:
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
  =?  ball  =(~ (~(get ba:tarball ball) [/ %'main.sig']))
    (~(put ba:tarball ball) [/ %'main.sig'] [~ %sig !>(~)])
  [sand gain ball]
::
++  on-file
  |=  [=rail:tarball =mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%clurd /main: failed")
    stay:m
  ==
++  on-manu
  |=  =mana:nexus
  ^-  @t
  ?-    -.mana
      %&
    ?+  p.mana  'Inert subdirectory under the clurd nexus. No special behavior.'
      ~  'Clurd nexus. Programmatic dill terminal access. Provides blit rendering (VT100 to text) used by MCP tools for terminal operations like dojo commands.'
    ==
      %|  'Inert file under the clurd nexus. No special documentation.'
  ==
--
