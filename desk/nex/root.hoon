/+  nexus, tarball, io=fiberio
^-  nexus:nexus
!:  :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
  ::  Create /sys directory with system processes
  =?  ball  =(~ (~(get of ball) /sys))
    (~(put of ball) /sys [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/sys %'main.sig']))
    (~(put ba:tarball ball) [/sys %'main.sig'] [~ %sig !>(~)])
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
  ::  Create /sys/build.build directory with neck=%build
  =?  ball  =(~ (~(get of ball) /sys/'build.build'))
    (~(put of ball) /sys/'build.build' [~ `%build ~])
  ::  Create /clurd.clurd directory with neck=%clurd
  =?  ball  =(~ (~(get of ball) /'clurd.clurd'))
    (~(put of ball) /'clurd.clurd' [~ `%clurd ~])
  ::  Create /config/creds directory if not present
  =?  ball  =(~ (~(get of ball) /config))
    (~(put of ball) /config [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /config/creds))
    (~(put of ball) /config/creds [~ ~ ~])
  ::  Enable history retention for dill and jael grubs
  =/  dill-jael=(list rail:tarball)
    :~  [/sys/dill %'logs.dill-told']
        [/sys/jael %'private-keys.jael-private-keys']
        [/sys/jael %'public-keys.jael-public-keys-result']
    ==
  =.  gain
    %+  roll  dill-jael
    |=  [here=rail:tarball gn=_gain]
    =/  node=(map @ta ?)  (fall (~(get of gn) path.here) ~)
    (~(put of gn) path.here (~(put by node) name.here %.y))
  [sand gain ball]
::
++  on-file
  |=  [=rail:tarball mak=mark]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [[%sys ~] %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%sys /main: failed, poke to restart")
    stay:m
  ==
--
