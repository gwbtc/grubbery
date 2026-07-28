::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
=/  app-weir=(unit weir:tarball)
  `[make=~ poke=(sy ~[[%& %| /]]) peek=(sy ~[[%& %| /]])]
::  the desks manager installs apps, so it needs to make/cull under
::  /apps (its own subtree makes are downward and always allowed);
::  poke/peek stay open so it can reach /sys for git http + timers.
=/  desks-weir=(unit weir:tarball)
  `[make=(sy ~[[%& %| /apps]]) poke=(sy ~[[%& %| /]]) peek=(sy ~[[%& %| /]])]
=/  home-readme=mime
  :-  /text/x-markdown
  %-  as-octs:mimes:html
  '''
  # /home

  A place for what you care about and what you are working on: a
  semantic index of current awareness and intention, pointing at
  where those things live in the namespace.

  That is the intent. No structure is enforced — its real use is
  up to the user.
  '''
=/  git-desk-config
  |=  [repo=@t ref=@t]
  ^-  json
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['ref' s+ref]
      ['public' b+%.n]
      ['poll' n+'360']
  ==
::  the desks this ship installs on boot — the desks manager's manifest
=/  desks-manifest
  ^-  json
  %-  pairs:enjs:format
  :~  ['version' n+'0']
      :-  'desks'
      :-  %a
      :~  %-  pairs:enjs:format
          :~  ['name' s+'contacts']
              ['repo' s+'niblyx-malnus/contacts-nexus']
              ['ref' s+'main']
              ['app' s+'contacts']
          ==
      ==
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
        ::  /home: created but never touched by the runtime. An
        ::  intention — a place for a structured, semantic index of
        ::  present awareness and intention. What lives here is the
        ::  inhabitant's business. The README states exactly that.
        [%fall %| /home [`[~ ~ %.n ~] ~]]
        [%fall %& [/home %'README.md'] [[/ %mime] home-readme]]
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
        [%fall %| /apps/'calendar.calendar' [`[`[/ %calendar] app-weir %.n ~] ~]]
        [%fall %| /apps/'notifications.notifications' [`[`[/ %notifications] app-weir %.n ~] ~]]
        ::
        [%fall %| /apps/'wallet.git_desk' [`[`[/git %desk] app-weir %.n ~] ~]]
        [%fall %& [/apps/'wallet.git_desk' %'config.json'] [[/ %json] (git-desk-config 'niblyx-malnus/wallet-nexus' 'main')]]
        ::
        ::  desks manager: its manifest lists the desks to install on
        ::  first boot (contacts here, replacing contacts.git_desk).
        ::  the nexus carries the seeded manifest via %fall; installed
        ::  apps persist via the /apps carry.
        [%fall %| /apps/'desks.desks' [`[`[/ %desks] desks-weir %.n ~] ~]]
        [%fall %& [/apps/'desks.desks' %'manifest.json'] [[/ %json] desks-manifest]]
        ::
        [%fall %| /apps/'obelisk.obelisk_app' [`[`[/obelisk %app] app-weir %.n ~] ~]]
        [%fall %| /apps/'test.web-test' [`[`[/ %web-test] app-weir %.n ~] ~]]
        [%fall %| /apps/'test.guestbook' [`[`[/ %guestbook] app-weir %.n ~] ~]]
        [%fall %| /apps/'test.desk' [`[`[/ %desk] app-weir %.n ~] ~]]
        [%fall %| /apps/'itinerary.git_desk' [`[`[/git %desk] app-weir %.n ~] ~]]
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
