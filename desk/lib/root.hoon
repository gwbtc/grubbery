::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
::  /apps is the trusted system tier: every instance defaults to ~ (no
::  weir, unrestricted). The weir apparatus exists for the untrusted
::  userspace tier — desk-installed apps default closed ([~ ~ ~]) and
::  earn each road through weir.json + shell approval. Built-ins,
::  including the shell (the capability broker that sands everyone
::  else), just run open here.
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
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
        ::  Lattice is NOT declared here any more, and that is the whole
        ::  point of the migration: it installs as a stock desk under the
        ::  shell, from its own repo, exactly as auspex, contacts and
        ::  wallet do. A row here would boot a second instance that fights
        ::  the desk's one for the /apps/lattice eyre binding.
        ::
        ::  What remains below is the core tier plus the apps a grubbery
        ::  ship needs in order to install anything at all: the shell to
        ::  consent, the forge to check out source, mcp to be reachable
        ::  from a tool, explorer to look at the namespace.
        ::
        ::  the shell: the home surface and the userspace permission
        ::  MANAGER. It reads each app's alias.json and weir.json, records
        ::  what the user consents to, writes the weirs the kernel then
        ::  enforces, and owns cross-ship discovery - public.json, the
        ::  /peers mirrors, and the /sys/link registry above. Restored from
        ::  upstream in the develop merge: the 2026-09-05 trim had deleted
        ::  it because at the time nothing reached it.
        [%fall %| /apps/'shell.shell' [`[`[/ %shell] ~ %.n ~] ~]]
        ::
        ::  mcp hosts the memory tool surface. Lattice serves no /mcp
        ::  route of its own, so lattice-list, lattice-read, lattice-save
        ::  and the rest live in gub/lib/tool-bundle/ here - a hermetic
        ::  namespace carrying its own copies of the two lattice libs its
        ::  tools import. Those tools reach the lattice instance through
        ::  one constant, +base in tool-bundle/lattice-mcp.hoon, which the
        ::  desk migration repoints at the shell's data tree. Removing mcp
        ::  would leave the memory store reachable only over HTTP, which
        ::  is the feature most of this distribution's users are here for.
        ::
        [%fall %| /apps/'mcp.mcp' [`[`[/ %mcp] ~ %.n ~] ~]]
        ::
        ::  explorer: the namespace browser and file viewer. Kept as a
        ::  DEFAULT app, not as something a user installs later - it is how
        ::  you look at a grubbery ship at all, and a distribution whose
        ::  only windows onto the namespace are two apps of our own is a
        ::  worse ship than the one upstream ships. Its row is upstream's,
        ::  unchanged.
        ::
        [%fall %| /apps/'explorer.explorer' [`[`[/ %explorer] ~ %.n ~] ~]]
        ::
        ::  forge: the UI over git repo instances, housing them at
        ::  /apps/forge.git_forge/repos/<name>.git_repo. Upstream's row,
        ::  unchanged.
        ::
        ::  This is a PUBLISHER's tool, not a user's: an installer gets apps
        ::  from a peer's storefront and never needs it. It is here because
        ::  we publish, and a desk mirrors from a path in the namespace - so
        ::  something has to put the source there, and checking out the repo
        ::  is how. ~200 KB, the largest single thing we carry for a role
        ::  most ships never play; revisit if the ball budget gets tight.
        ::
        [%fall %| /apps/'forge.git_forge' [`[`[/git %forge] ~ %.n ~] ~]]
        ::  github: how a git_repo actually FETCHES. Nothing imports it -
        ::  repo.hoon reaches it by poking /apps/github.github/main.sig - so
        ::  the forge looked complete and then failed at run time with "no
        ::  process at /apps/github.github/main.sig". Upstream's row.
        [%fall %| /apps/'github.github' [`[`[/ %github] ~ %.n ~] ~]]
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
