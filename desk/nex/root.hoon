/+  nexus, tarball, io=fiberio
^-  nexus:nexus
!: :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  ::  Create /main file if not present
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
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
  [sand ball]
::
++  on-file
  |=  [=rail:tarball =mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [~ %main]
    ;<  ~  bind:m  (rise-wait:io prod "%root /main: failed, poke to restart")
    ~&  >  "%root /main: warming tube cache"
    ;<  ~  bind:m  (warm-tubes:io &)
    ~&  >  "%root /main: tube cache warm"
    stay:m
  ==
--
