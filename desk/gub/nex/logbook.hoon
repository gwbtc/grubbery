::  logbook nexus: accepts text pokes, appends to a log
::
^-  nexus:nexus
|%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.txt'] [[/ %txt] *wain]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.txt']
        ;<  ~  bind:m  (rise-wait:io prod "%logbook: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ?.  =([/ %txt] p.sage)
          ~&  [%logbook-unexpected-mark p.sage]
          $
        =/  new-lines=wain  !<(wain q.sage)
        ;<  log=wain  bind:m  (get-state-as:io ,wain)
        ;<  ~  bind:m  (replace:io !>((weld log new-lines)))
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'File under logbook.'
            ~
          'Logbook: accepts txt pokes, appends lines to main.txt log.'
        ==
          %|
        ?+  rail.p.mana  'File under logbook.'
            [~ %'main.txt']
          'Log file. Poke with txt to append lines.'
        ==
      ==
--
