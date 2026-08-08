::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
::  /apps is the trusted system tier: every instance defaults to ~ (no
::  weir, unrestricted). The weir apparatus exists for the untrusted
::  userspace tier — desk-installed apps default closed ([~ ~ ~]) and
::  earn each road through weir.json + shell approval. Built-ins,
::  including the shell (the capability broker that sands everyone
::  else), just run open here.
=/  git-desk-config
  |=  [repo=@t ref=@t]
  ^-  json
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['ref' s+ref]
      ['public' b+%.n]
      ['poll' n+'360']
  ==
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
        [%fall %| /apps/'tiles.tiles' [`[`[/ %tiles] ~ %.n ~] ~]]
        [%fall %| /apps/'shell.shell' [`[`[/ %shell] ~ %.n ~] ~]]
        [%fall %| /apps/'counter.counter' [`[`[/ %counter] ~ %.n ~] ~]]
        [%fall %| /apps/'explorer.explorer' [`[`[/ %explorer] ~ %.n ~] ~]]
        [%fall %| /apps/'mcp.mcp' [`[`[/ %mcp] ~ %.n ~] ~]]
        [%fall %| /apps/'peers.peers' [`[`[/ %peers] ~ %.n ~] ~]]
        [%fall %| /apps/'calendar.calendar' [`[`[/ %calendar] ~ %.n ~] ~]]
        [%fall %| /apps/'notifications.notifications' [`[`[/ %notifications] ~ %.n ~] ~]]
        [%fall %| /apps/'feeds.feeds' [`[`[/ %feeds] ~ %.n ~] ~]]
        [%fall %| /apps/'weather.weather' [`[`[/ %weather] ~ %.n ~] ~]]
        ::
        [%fall %| /apps/'wallet.git_desk' [`[`[/git %desk] ~ %.n ~] ~]]
        [%fall %& [/apps/'wallet.git_desk' %'config.json'] [[/ %json] (git-desk-config 'niblyx-malnus/wallet-nexus' 'main')]]
        ::
        ::  contacts: a plain git desk (the /git/desk backend), the same
        ::  way wallet boots. it was briefly the desks
        ::  manager's boot-install; desks is now only the UI, so it boots
        ::  as its own git_desk again.
        [%fall %| /apps/'contacts.git_desk' [`[`[/git %desk] ~ %.n ~] ~]]
        [%fall %& [/apps/'contacts.git_desk' %'config.json'] [[/ %json] (git-desk-config 'niblyx-malnus/contacts-nexus' 'main')]]
        ::
        ::  desks: the UI over the /desk and /git/desk nexuses. it also
        ::  creates + configures them, so it makes under /apps.
        [%fall %| /apps/'desks.desks' [`[`[/ %desks] ~ %.n ~] ~]]
        ::
        ::  forge: the UI over git repo instances, housing them at
        ::  /repos inside itself.
        [%fall %| /apps/'forge.git_forge' [`[`[/git %forge] ~ %.n ~] ~]]
        ::
        [%fall %| /apps/'test.web-test' [`[`[/ %web-test] ~ %.n ~] ~]]
        [%fall %| /apps/'test.guestbook' [`[`[/ %guestbook] ~ %.n ~] ~]]
        [%fall %| /apps/'pad.pad' [`[`[/ %pad] ~ %.n ~] ~]]
        [%fall %| /apps/'routes.routes' [`[`[/ %routes] ~ %.n ~] ~]]
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
