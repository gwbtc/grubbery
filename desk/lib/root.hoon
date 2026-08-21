::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
::  /apps is the trusted system tier: every instance defaults to ~ (no
::  weir, unrestricted). The weir apparatus exists for the untrusted
::  userspace tier — desk-installed apps default closed ([~ ~ ~]) and
::  earn each road through weir.json + shell approval. Built-ins,
::  including the shell (the capability broker that sands everyone
::  else), just run open here.
::  git-repo-config: config for a /git/repo instance — clones + checks
::  out a github repo. poll drives the periodic re-fetch.
=/  git-repo-config
  |=  [repo=@t ref=@t]
  ^-  json
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['ref' s+ref]
      ['token' s+'']
      ['poll' n+'15']
  ==
::  desk-source-config: config for a /desk instance — subscribes to a
::  code dir already in the namespace (here, a git_repo's checked-out
::  tree) and deploys it. source is that dir's absolute path.
=/  desk-source-config
  |=  source=@t
  ^-  json
  %-  pairs:enjs:format
  :~  ['source' s+source]
      ['share' a+~]
      ::  full version-file name — lets the desk watch its road before
      ::  the source (a git_repo) has checked out. See desk.hoon.
      ['version' s+'version.json']
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
        ::  /port: authenticated typed-message ingress. Each /port/<name>
        ::  is a [/port %cargo] grub that handles its own pokes — poke it a
        ::  mime and it stamps the sender and stores it. Open weir: any ship.
        [%fall %| /port [`[`[/ %port] ~ %.n ~] ~]]
        ::  /sys/eyre: HTTP server state + request fibers
        ::
        [%fall %| /sys/eyre [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/eyre %'main.server-state'] [[/ %server-state] *server-state:nexus]]
        [%fall %| /sys/eyre/requests [`[~ ~ %.n ~] ~]]
        ::  /sys/behn: timer service
        ::
        [%fall %| /sys/behn [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/behn %'main.behn-state'] [[/ %behn-state] *behn-state:nexus]]
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
        [%fall %& [/sys/scry %'main.scry-state'] [[/ %scry-state] *scry-state:nexus]]
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
        ::  forge: the UI over git repo instances, housing them at
        ::  /repos inside itself.
        [%fall %| /apps/'forge.git_forge' [`[`[/git %forge] ~ %.n ~] ~]]
        ::
        ::  contacts + wallet seeds DISABLED: not created by default.
        ::  Existing instances persist; a deleted one stays deleted.
        ::  Uncomment to seed on a fresh boot.
        ::  contacts: git_desk is obviated. A /git/repo (housed in forge's
        ::  /repos, so it shows in the UI) checks out the github repo; a
        ::  /desk subscribes to its checked-out code dir and deploys it.
        ::  Seeded AFTER forge exists — you can't nest into a nexus that
        ::  hasn't been made yet. Root wires both directly, so no
        ::  /tools/proc sandbox dance — that's only for forge installs.
        ::[%fall %| /apps/'forge.git_forge'/repos/'contacts.git_repo' [`[`[/git %repo] ~ %.n ~] ~]]
        ::[%fall %& [/apps/'forge.git_forge'/repos/'contacts.git_repo' %'config.json'] [[/ %json] (git-repo-config 'niblyx-malnus/contacts-nexus' 'main')]]
        ::[%fall %| /apps/'contacts.desk' [`[`[/ %desk] ~ %.n ~] ~]]
        ::[%fall %& [/apps/'contacts.desk' %'config.json'] [[/ %json] (desk-source-config '/apps/forge.git_forge/repos/contacts.git_repo/data/tree/code')]]
        ::
        ::  wallet: same git_repo + /desk pattern as contacts (was git_desk).
        ::[%fall %| /apps/'forge.git_forge'/repos/'wallet.git_repo' [`[`[/git %repo] ~ %.n ~] ~]]
        ::[%fall %& [/apps/'forge.git_forge'/repos/'wallet.git_repo' %'config.json'] [[/ %json] (git-repo-config 'niblyx-malnus/wallet-nexus' 'main')]]
        ::[%fall %| /apps/'wallet.desk' [`[`[/ %desk] ~ %.n ~] ~]]
        ::[%fall %& [/apps/'wallet.desk' %'config.json'] [[/ %json] (desk-source-config '/apps/forge.git_forge/repos/wallet.git_repo/data/tree/code')]]
        ::
        [%fall %| /apps/'test.web-test' [`[`[/ %web-test] ~ %.n ~] ~]]
        [%fall %| /apps/'test.guestbook' [`[`[/ %guestbook] ~ %.n ~] ~]]
        [%fall %| /apps/'pad.pad' [`[`[/ %pad] ~ %.n ~] ~]]
        [%fall %| /apps/'routes.routes' [`[`[/ %routes] ~ %.n ~] ~]]
        [%fall %| /apps/'github.github' [`[`[/ %github] ~ %.n ~] ~]]
        [%fall %| /apps/'anthropic.anthropic' [`[`[/ %anthropic] ~ %.n ~] ~]]
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
