::  logbook nexus: accepts text pokes, appends to a log
::  mirror.sig subscribes to a remote ship's logbook and mirrors main.txt
::
=<  ^-  nexus:nexus
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
            [%fall %& [/ %'mirror.sig'] [[/ %sig] ~]]
            [%fall %| /mirrored empty-dir:loader]
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
        ;<  ~  bind:m  (replace:io (weld log new-lines))
        $
          ::  /mirror.sig: poke with ship name to mirror its logbook
          ::
          [~ %'mirror.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%logbook /mirror: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ?.  =([/ %txt] p.sage)
          ~&  [%mirror-bad-mark p.sage]
          $
        =/  target=@p  (slav %p (of-wain:format !<(wain q.sage)))
        ~&  >  [%mirror-starting target]
        (mirror-loop target)
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'File under logbook.'
            ~
          'Logbook: accepts txt pokes, appends lines to main.txt. Mirror grub for cross-ship mirroring.'
            [%mirrored ~]
          'Mirrored main.txt from a remote ship.'
        ==
          %|
        ?+  rail.p.mana  'File under logbook.'
            [~ %'main.txt']
          'Log file. Poke with txt to append lines.'
            [~ %'mirror.sig']
          'Mirror process. Poke with ship name (e.g. ~nec) to start mirroring.'
        ==
      ==
    --
|%
++  mirror-loop
  |=  target=@p
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ;<  here=rail:tarball  bind:m  get-here-abs:io
  ::  here is mirror.sig's rail; path.here is the nexus dir
  =/  prefix=path  /sys/ames/ships/[(scot %p target)]/root
  =/  remote-dir=road:tarball  [%& %| (weld prefix path.here)]
  ;<  =wave:nexus  bind:m  (keep:io /mirror remote-dir ~)
  ~&  >  [%mirror-subscribed target]
  =/  remote-file=road:tarball  [%& %& (weld prefix path.here) %'main.txt']
  ;<  ~  bind:m  (sync-remote remote-file)
  |-
  ;<  =wave:nexus  bind:m  (take-news:io /mirror)
  ~&  >  [%mirror-news target]
  ;<  ~  bind:m  (sync-remote remote-file)
  $
::
++  sync-remote
  |=  remote-file=road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io remote-file ~)
  ?.  ?=([%& %file *] seen)
    ~&  >>  [%mirror-peek-failed]
    (pure:m ~)
  =/  =sang:tarball  sang.p.seen
  ~&  >  [%mirror-sync p.sang]
  =/  mirrored=road:tarball  [%| 0 %& /mirrored %'main.txt']
  =/  =bask:tarball  [p.sang (sang-noun:tarball sang)]
  ;<  exists=?  bind:m  (peek-exists:io mirrored)
  ?:  exists
    ;<  ~  bind:m  (over:io mirrored bask)
    (pure:m ~)
  ;<  ~  bind:m  (make:io mirrored |+[bask ~])
  (pure:m ~)
--
