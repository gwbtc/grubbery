/+  nexus, tarball, io=fiberio
^-  nexus:nexus
!:  :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  ::  Create /sys directory with system processes
  =?  ball  =(~ (~(get of ball) /sys))
    (~(put of ball) /sys [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/sys %main]))
    (~(put ba:tarball ball) [/sys %main] [~ %sig !>(~)])
  =?  ball  =(~ (~(get ba:tarball ball) [/sys %marks]))
    (~(put ba:tarball ball) [/sys %marks] [~ %sig !>(~)])
  =?  ball  =(~ (~(get ba:tarball ball) [/sys %nexuses]))
    (~(put ba:tarball ball) [/sys %nexuses] [~ %sig !>(~)])
  ::  Create /server directory with neck=%server
  =?  ball  =(~ (~(get of ball) /server))
    (~(put of ball) /server [~ `%server ~])
  ::  Create /counter directory with neck=%counter
  =?  ball  =(~ (~(get of ball) /counter))
    (~(put of ball) /counter [~ `%counter ~])
  ::  Create /explorer directory with neck=%explorer
  =?  ball  =(~ (~(get of ball) /explorer))
    (~(put of ball) /explorer [~ `%explorer ~])
  ::  Create /peers directory with neck=%peers
  ::  All foreign ship interaction goes through here.
  ::  Peers nexus manages gateway processes, usergroups, and weirs.
  =?  ball  =(~ (~(get of ball) /peers))
    (~(put of ball) /peers [~ `%peers ~])
  ::  Create /claude directory with neck=%claude
  =?  ball  =(~ (~(get of ball) /claude))
    (~(put of ball) /claude [~ `%claude ~])
  ::  Create /tools directory with neck=%tools
  =?  ball  =(~ (~(get of ball) /tools))
    (~(put of ball) /tools [~ `%tools ~])
  ::  Create /mcp directory with neck=%mcp
  =?  ball  =(~ (~(get of ball) /mcp))
    (~(put of ball) /mcp [~ `%mcp ~])
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
      [[%sys ~] %main]
    ;<  ~  bind:m  (rise-wait:io prod "%sys /main: failed, poke to restart")
    stay:m
  ::
      [[%sys ~] %marks]
    ;<  ~  bind:m  (rise-wait:io prod "%sys /marks: failed, poke to restart")
    ::  Watch /mar for file additions/removals and rebuild marks.
    ::  Uses %y (directory listing) not %z (content hash) to avoid
    ::  infinite loops — %ca scries in rebuild update Clay's build
    ::  cache which changes the %z hash.
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk   bind:m  get-desk:io
    ;<  now=@da  bind:m  get-time:io
    |-
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %next %y da+now /mar)
    ?~  riot  stay:m
    ~&  >  "%sys /marks: marks changed, rebuilding"
    ;<  ~  bind:m
      (gall-poke-our:io %grubbery rebuild-caches+!>(~))
    ;<  now=@da  bind:m  get-time:io
    $
  ::
      [[%sys ~] %nexuses]
    ;<  ~  bind:m  (rise-wait:io prod "%sys /nexuses: failed, poke to restart")
    ::  Watch /nex for file additions/removals and rebuild nexuses.
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk   bind:m  get-desk:io
    ;<  now=@da  bind:m  get-time:io
    |-
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %next %y da+now /nex)
    ?~  riot  stay:m
    ~&  >  "%sys /nexuses: nexus files changed, rebuilding"
    ;<  ~  bind:m
      (gall-poke-our:io %grubbery rebuild-caches+!>(~))
    ;<  now=@da  bind:m  get-time:io
    $
  ==
--
