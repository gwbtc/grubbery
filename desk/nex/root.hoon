/+  nexus, tarball, io=fiberio
^-  nexus:nexus
!:  :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  ::  Create /root directory with system processes
  =?  ball  =(~ (~(get of ball) /root))
    (~(put of ball) /root [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/root %main]))
    (~(put ba:tarball ball) [/root %main] [~ %sig !>(~)])
  =?  ball  =(~ (~(get ba:tarball ball) [/root %marks]))
    (~(put ba:tarball ball) [/root %marks] [~ %sig !>(~)])
  =?  ball  =(~ (~(get ba:tarball ball) [/root %nexuses]))
    (~(put ba:tarball ball) [/root %nexuses] [~ %sig !>(~)])
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
      [[%root ~] %main]
    ;<  ~  bind:m  (rise-wait:io prod "%root /main: failed, poke to restart")
    stay:m
  ::
      [[%root ~] %marks]
    ;<  ~  bind:m  (rise-wait:io prod "%root /marks: failed, poke to restart")
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
    ~&  >  "%root /marks: marks changed, rebuilding"
    ;<  ~  bind:m
      (gall-poke-our:io %grubbery rebuild-marks+!>(~))
    ;<  now=@da  bind:m  get-time:io
    $
  ::
      [[%root ~] %nexuses]
    ;<  ~  bind:m  (rise-wait:io prod "%root /nexuses: failed, poke to restart")
    ::  Watch /nex for file additions/removals and rebuild nexuses.
    ;<  our=@p  bind:m  get-our:io
    ;<  =desk   bind:m  get-desk:io
    ;<  now=@da  bind:m  get-time:io
    |-
    ;<  =riot:clay  bind:m
      (warp:io our desk ~ %next %y da+now /nex)
    ?~  riot  stay:m
    ~&  >  "%root /nexuses: nexus files changed, rebuilding"
    ;<  ~  bind:m
      (gall-poke-our:io %grubbery rebuild-marks+!>(~))
    ;<  now=@da  bind:m  get-time:io
    $
  ==
--
