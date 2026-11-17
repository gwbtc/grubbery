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
::  === the shell's move out of /apps/shell.shell ======================
::
::  History, and it has to stay: the shell used to live at
::  /apps/shell.shell, back when a nexus instance carried its kind as a
::  name extension. A pier that has not loaded a kernel since the move
::  (2026-11) still holds it there, and such a pier exists as long as one
::  sits on a disk somewhere. So the root nexus carries the rewrite.
::
::  It runs on the tree the rows just built, not as a step in the kernel's
::  cold start. The old version peeked /apps/shell.shell on every load
::  forever, which is what got it deleted (86d95a0). Here the bole is
::  already in hand, so a ship past the move pays one map lookup.
::
::  On an old pier the rows have, by then, carried /apps/shell.shell over
::  whole and laid an empty shell at /apps/shell (that row's default). The
::  move replaces that empty one — which is why "no desks" is what tells a
::  real shell from a placeholder.
::
::  What the move does, once: lands the subtree at the new name (the
::  structure is shared, no bytes copy), drops the old one, rewrites every
::  json grub inside it that spelled the old path, drops every grant.json
::  so the shell sands its apps again at the new place, and repoints every
::  /sys/link lane that named the old path.
::
::  It moves a real shell only: the old directory's neck must be
::  [/ %shell], and /apps/shell must hold no shell of its own. The name is
::  taken by a shell or it is free; it is never squatted on.
::
=/  old-shell=@ta  'shell.shell'
=/  old-spell=tape  "/apps/shell.shell"
=/  new-spell=tape  "/apps/shell"
::  +respell: every occurrence of `from` in a tape replaced with `to`
=/  respell
  |=  [txt=tape from=tape to=tape]
  ^-  tape
  =/  n=@ud  (lent from)
  |-  ^-  tape
  ?~  txt  ~
  ?:  =(from (scag n `tape`txt))  (weld to $(txt (slag n `tape`txt)))
  [i.txt $(txt t.txt)]
::  +respell-pulp: one directory's files — grant.json goes, and a json
::  grub that spells the old path is rewritten
=/  respell-pulp
  |=  [p=pulp:tarball from=tape to=tape]
  ^-  pulp:tarball
  %=    p
      contents
    %-  ~(gas by *(map @ta [bask:tarball gain=?]))
    %+  murn  ~(tap by contents.p)
    |=  [name=@ta =bask:tarball gain=?]
    ^-  (unit [@ta [bask:tarball ?]])
    ?:  =(%'grant.json' name)  ~
    ?.  =([/ %json] p.bask)  `[name [bask gain]]
    =/  jon=(unit json)  (mole |.(;;(json q.bask)))
    ?~  jon  `[name [bask gain]]
    =/  txt=tape  (trip (en:json:html u.jon))
    ?~  (find from txt)  `[name [bask gain]]
    =/  next=(unit json)  (de:json:html (crip (respell txt from to)))
    ?~  next  `[name [bask gain]]
    `[name [[p.bask u.next] gain]]
  ==
::  +respell-bole: that, for a whole subtree
=/  respell-bole
  |=  [b=bole:tarball from=tape to=tape]
  ^-  bole:tarball
  |-  ^-  bole:tarball
  :-  ?~(fil.b ~ `(respell-pulp u.fil.b from to))
  %-  ~(run by dir.b)
  |=(kid=bole:tarball ^$(b kid))
::  +relane-bole: every dest.lanes in a subtree, repointed. A /sys/link
::  name may nest, so the walk goes all the way down.
=/  relane-bole
  |=  [b=bole:tarball old=path new=path]
  ^-  bole:tarball
  |-  ^-  bole:tarball
  =/  mine=(unit pulp:tarball)
    ?~  fil.b  ~
    =/  got  (~(get by contents.u.fil.b) %'dest.lanes')
    ?~  got  fil.b
    ?.  =([/ %lanes] p.bask.u.got)  fil.b
    =/  lanes=(unit (list lane:tarball))
      (mole |.(;;((list lane:tarball) q.bask.u.got)))
    ?~  lanes  fil.b
    =/  moved=(list lane:tarball)
      %+  turn  u.lanes
      |=  l=lane:tarball
      ?-  -.l
        %|  ?.(=(old (scag (lent old) p.l)) l [%| (weld new (slag (lent old) p.l))])
        %&  ?.(=(old (scag (lent old) path.p.l)) l [%& (weld new (slag (lent old) path.p.l)) name.p.l])
      ==
    ?:  =(moved u.lanes)  fil.b
    :-  ~
    %=  u.fil.b
      contents  (~(put by contents.u.fil.b) %'dest.lanes' [[p.bask.u.got moved] gain.u.got])
    ==
  :-  mine
  %-  ~(run by dir.b)
  |=(kid=bole:tarball ^$(b kid))
::  +move-shell: the root row's fold. Everything above happens here or
::  nowhere; a bole with no /apps/shell.shell in it comes back untouched.
=/  move-shell
  |=  b=bole:tarball
  ^-  bole:tarball
  =/  apps=(unit bole:tarball)  (~(get by dir.b) %apps)
  ?~  apps  b
  =/  old=(unit bole:tarball)  (~(get by dir.u.apps) old-shell)
  ?~  old  b
  ?.  ?&  ?=(^ fil.u.old)
          =(`[/ %shell] neck.u.fil.u.old)
      ==
    b
  ::  the new name is free, or it is a shell already and this one stays put
  =/  cur=(unit bole:tarball)  (~(get by dir.u.apps) %shell)
  ?:  ?&  ?=(^ cur)
          (~(has by dir.u.cur) %desks)
      ==
    b
  =/  moved=bole:tarball  (respell-bole u.old old-spell new-spell)
  =/  apps2=bole:tarball
    %=  u.apps
      dir  (~(put by (~(del by dir.u.apps) old-shell)) %shell moved)
    ==
  =/  b2=bole:tarball  b(dir (~(put by dir.b) %apps apps2))
  ::  /sys/link: every name that pointed into the old place
  =/  sys=(unit bole:tarball)  (~(get by dir.b2) %sys)
  ?~  sys  b2
  =/  link=(unit bole:tarball)  (~(get by dir.u.sys) %link)
  ?~  link  b2
  =/  link2=bole:tarball
    (relane-bole u.link (stab (crip old-spell)) (stab (crip new-spell)))
  =/  sys2=bole:tarball  u.sys(dir (~(put by dir.u.sys) %link link2))
  b2(dir (~(put by dir.b2) %sys sys2))
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  ::  +move-shell runs on the SPUN tree, not as a row: every %load and
  ::  %fall row reads the old ball, so a row that moved the shell would be
  ::  overwritten by the /apps row and then by /apps/shell's own default.
  %-  move-shell
  %+  spin:loader  ball
    :~  (manifest:loader 0)
        [%load %| / / same-fold:loader]
        ::  /apps is the trusted tier and MUST stay unweired: a weir here
        ::  locks the whole system including every tool that could remove
        ::  it (learned the hard way). Each load forcibly resets /apps'
        ::  own fil to the open default — an invariant, not healing.
        ::  Children untouched (%load extracts the old subtree and
        ::  transforms only the top fil).
        [%load %| /apps /apps |=(b=bole:tarball b(fil `[~ ~ %.n ~]))]
        [%fall %| /docs [`[~ ~ %.n ~] ~]]
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
        ::  websocket client table (groundwire runtime only); same vane
        [%fall %& [/sys/iris %'ws.ws-state'] [[/ %ws-state] *ws-state:nexus]]
        ::  /sys/clay: desk sync service (state + desks/ subdir)
        ::
        [%fall %& [/sys/clay %'main.clay-state'] [[/ %clay-state] *clay-state:nexus]]
        [%fall %| /sys/clay/desks [`[~ ~ %.n ~] ~]]
        ::  /sys/link: discovery registry (dest.lanes per @name)
        ::
        [%fall %| /sys/link [`[~ ~ %.n ~] ~]]
        ::  /sys/scry: scry service
        ::
        [%fall %| /sys/scry [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/scry %'main.sig'] [[/ %sig] ~]]
        [%fall %& [/sys/scry %'main.scry-state'] [[/ %scry-state] *scry-state:nexus]]
        ::  child nexuses
        ::
        ::  the shell: the one bootstrap nexus, the user's interface to the
        ::  kernel. Its home page's local tiles live inside it (/tiles).
        [%fall %| /apps/shell [`[`[/ %shell] ~ %.n ~] ~]]
        ::
        ::  forge: the UI over git repo instances, housing them at
        ::  /repos inside itself.
        ::
        ::  contacts + wallet seeds DISABLED: desks are managed by the
        ::  shell's sync-defaults pipeline now.
        ::
        ::  /sys/link built-in names: the apps that ship with grubbery claim
        ::  their discovery names HERE, next to where the apps are declared, so
        ::  @github/@forge/… resolve the instant the tree loads — no shell scan,
        ::  no approval, no first-boot race. Each dest.lanes points at the app's
        ::  own root (a %| dir lane). The shell registers only the names USER
        ::  DESKS claim; these shipped names are a fact of the base tree.
        [%fall %| /sys/link/explorer [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/link/explorer %'dest.lanes'] [[/ %lanes] ~[`lane:tarball`[%| /apps/shell/explorer]]]]
        ::  tools: the MCP endpoint's tools nexus is a service of the shell
        ::  (its /tools directory, lib/shell/mcp), so @tools is that.
        [%fall %| /sys/link/tools [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/link/tools %'dest.lanes'] [[/ %lanes] ~[`lane:tarball`[%| /apps/shell/tools]]]]
        ::  forge: the shell's git forge, and the github proxy it houses
        ::  at /github. Stock sync finds the forge by this name.
        [%fall %| /sys/link/forge [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/link/forge %'dest.lanes'] [[/ %lanes] ~[`lane:tarball`[%| /apps/shell/forge]]]]
        [%fall %| /sys/link/github [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/link/github %'dest.lanes'] [[/ %lanes] ~[`lane:tarball`[%| /apps/shell/forge/github]]]]
        ::  notifications: the inbox is a service of the shell (its
        ::  /notifications directory); the name points into it, so
        ::  @notifications/main.sig is the shell's notifications/main.sig.
        [%fall %| /sys/link/notifications [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/link/notifications %'dest.lanes'] [[/ %lanes] ~[`lane:tarball`[%| /apps/shell/notifications]]]]
        ::  contacts: the people record is a service of the shell (its
        ::  /contacts directory), so @contacts is that.
        [%fall %| /sys/link/contacts [`[~ ~ %.n ~] ~]]
        [%fall %& [/sys/link/contacts %'dest.lanes'] [[/ %lanes] ~[`lane:tarball`[%| /apps/shell/contacts]]]]
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
