::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
=/  app-weir=(unit weir:tarball)
  `[make=~ poke=(sy ~[[%& %| /]]) peek=(sy ~[[%& %| /]])]
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
    :~  (manifest:loader 0)
        [%load %| / / same-fold:loader]
        [%fall %| /apps [`[~ ~ %.n ~] ~]]
        [%fall %| /docs [`[~ ~ %.n ~] ~]]
        ::  /sys/eyre: HTTP server state + request fibers
        ::
        [%fall %| /sys/eyre [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/eyre %'main.server-state'] [[/ %server-state] *server-state:nexus]]
        [%fall %| /sys/eyre/requests [`[~ ~ %.n ~] ~]]
        ::  /sys/behn: timer service
        ::
        [%fall %| /sys/behn [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/behn %'main.timer-state'] [[/ %timer-state] *timer-state:nexus]]
        ::  /sys/iris: HTTP client service
        ::
        [%fall %| /sys/iris [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/iris %'main.iris-state'] [[/ %iris-state] *iris-state:nexus]]
        ::  /sys/clay: desk sync service (state + desks/ subdir)
        ::
        [%fall %& [/sys/clay %'main.clay-state'] [[/ %clay-state] *clay-state:nexus]]
        [%fall %| /sys/clay/desks [`[~ ~ %.n ~] ~]]
        ::  /sys/scry: scry service
        ::
        [%fall %| /sys/scry [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/scry %'main.sig'] [[/ %sig] ~]]
        ::  child nexuses
        ::
        [%fall %| /apps/'tiles.tiles' [`[`[/ %tiles] app-weir %.n ~] ~]]
        [%fall %| /apps/'counter.counter' [`[`[/ %counter] app-weir %.n ~] ~]]
        [%fall %| /apps/'explorer.explorer' [`[`[/ %explorer] ~ %.n ~] ~]]
        [%fall %| /apps/'mcp.mcp' [`[`[/ %mcp] ~ %.n ~] ~]]
        [%fall %| /apps/'peers.peers' [`[`[/ %peers] app-weir %.n ~] ~]]
        [%fall %| /apps/'wallet.wallet_app' [`[`[/wallet %app] app-weir %.n ~] ~]]
        [%fall %| /apps/'contacts.contacts' [`[`[/ %contacts] app-weir %.n ~] ~]]
        [%fall %| /apps/'test.web-test' [`[`[/ %web-test] app-weir %.n ~] ~]]
        [%fall %| /apps/'test.desk' [`[`[/ %desk] app-weir %.n ~] ~]]
        [%fall %| /apps/'echo.lick-echo' [`[`[/ %lick-echo] app-weir %.n ~] ~]]
    ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  /sys/eyre/requests/*: ball API request fibers
      ::
      [[%sys %eyre %requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%eyre /requests: failed")
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
    =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
    (dispatch:ball-api eyre-id src req site args)
  ==
--
