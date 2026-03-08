/+  nexus, tarball, io=fiberio
^-  nexus:nexus
!:  :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
  ::  Create /sys directory with system processes
  =?  ball  =(~ (~(get of ball) /sys))
    (~(put of ball) /sys [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/sys %'main.sig']))
    (~(put ba:tarball ball) [/sys %'main.sig'] [~ %sig !>(~)])
  =.  ball  (~(put ba:tarball ball) [/sys %'marks.ud'] [~ %ud !>(0)])
  =.  ball  (~(put ba:tarball ball) [/sys %'nexuses.ud'] [~ %ud !>(0)])
  ::  Create /server.server directory with neck=%server
  =?  ball  =(~ (~(get of ball) /'server.server'))
    (~(put of ball) /'server.server' [~ `%server ~])
  ::  Create /counter.counter directory with neck=%counter
  =?  ball  =(~ (~(get of ball) /'counter.counter'))
    (~(put of ball) /'counter.counter' [~ `%counter ~])
  ::  Create /explorer.explorer directory with neck=%explorer
  =?  ball  =(~ (~(get of ball) /'explorer.explorer'))
    (~(put of ball) /'explorer.explorer' [~ `%explorer ~])
  ::  Create /peers.peers directory with neck=%peers
  ::  All foreign ship interaction goes through here.
  ::  Peers nexus manages gateway processes, usergroups, and weirs.
  =?  ball  =(~ (~(get of ball) /'peers.peers'))
    (~(put of ball) /'peers.peers' [~ `%peers ~])
  ::  Create /claude.claude directory with neck=%claude
  =?  ball  =(~ (~(get of ball) /'claude.claude'))
    (~(put of ball) /'claude.claude' [~ `%claude ~])
  ::  Create /mcp.mcp directory with neck=%mcp
  =?  ball  =(~ (~(get of ball) /'mcp.mcp'))
    (~(put of ball) /'mcp.mcp' [~ `%mcp ~])
  ::  Create /config/creds directory if not present
  =?  ball  =(~ (~(get of ball) /config))
    (~(put of ball) /config [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /config/creds))
    (~(put of ball) /config/creds [~ ~ ~])
  [sand ball]
::
++  on-file
  |=  [=rail:tarball =mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [[%sys ~] %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%sys /main: failed, poke to restart")
    stay:m
  ::
      [[%sys ~] %'marks.ud']
    ;<  ~  bind:m  (rise-wait:io prod "%sys /marks: failed, poke to restart")
    ::  Watch /mar for changes and rebuild marks.
    ::  Dedup: compare desk revision to last-seen, skip if unchanged.
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk   bind:m  get-desk:io
    ;<  now=@da  bind:m  get-time:io
    |-
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %next %z da+now /mar)
    ?~  riot  stay:m
    ;<  now=@da  bind:m  get-time:io
    ;<  snap=riot:clay  bind:m
      (warp:io our desk ~ %sing %w da+now /)
    =/  cur-rev=@ud  ?~(snap 0 !<(@ud q.r.u.snap))
    ;<  last-rev=@ud  bind:m  (get-state-as:io ,@ud)
    ?:  =(cur-rev last-rev)
      ~&  >  [%sys-marks %same-rev cur-rev]
      $
    ;<  ~  bind:m  (replace:io !>(cur-rev))
    ~&  >  [%sys-marks %rebuilding cur-rev]
    ;<  ~  bind:m
      (gall-poke-our:io %grubbery rebuild-caches+!>(~))
    $
  ::
      [[%sys ~] %'nexuses.ud']
    ;<  ~  bind:m  (rise-wait:io prod "%sys /nexuses: failed, poke to restart")
    ::  Watch /nex for changes and rebuild nexuses.
    ::  Same dedup pattern as marks watcher.
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk   bind:m  get-desk:io
    ;<  now=@da  bind:m  get-time:io
    |-
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %next %z da+now /nex)
    ?~  riot  stay:m
    ;<  now=@da  bind:m  get-time:io
    ;<  snap=riot:clay  bind:m
      (warp:io our desk ~ %sing %w da+now /)
    =/  cur-rev=@ud  ?~(snap 0 !<(@ud q.r.u.snap))
    ;<  last-rev=@ud  bind:m  (get-state-as:io ,@ud)
    ?:  =(cur-rev last-rev)
      ~&  >  [%sys-nexuses %same-rev cur-rev]
      $
    ;<  ~  bind:m  (replace:io !>(cur-rev))
    ~&  >  [%sys-nexuses %rebuilding cur-rev]
    ;<  ~  bind:m
      (gall-poke-our:io %grubbery rebuild-caches+!>(~))
    $
  ==
--
