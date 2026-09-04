::  shell nexus: the home surface. Composes services — the launcher grid
::  (from the tiles store) and the notifications bell — over HTTP, and
::  owns the cross-ship discovery state: public.json, the derived
::  directory of this ship's shared desks, and /peers/, live mirrors
::  of other ships' directories.
::
::  Terminology — the shell/kernel distinction. The "shell" is the
::  userspace permission MANAGER: it reads apps' declared alias.json /
::  weir.json, surfaces them, records what you consent to, and writes
::  weirs. It decides. The "grubbery kernel" (the runtime, formerly
::  "runtime") is what ENFORCES those weirs — the dart gate. So the
::  permits registry below lives entirely on the deciding side; the
::  stopping is the kernel's job. Manager vs enforcer, shell vs kernel.
::
/<  feather-icons  /lib/feather-icons.hoon
/<  app-js         shell/app.js
/<  app-css        shell/style.css
/<  permits-html   shell/permits.html
/<  home-html      shell/home.html
/<  docs-html      shell/docs.html
/<  docs-js        shell/docs.js
/<  chat-js        shell/chat.js
/<  chat-css       shell/chat.css
/<  marked-js      shell/marked.min.js
/<  hoon-grammar   shell/hoon-grammar.json
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          ::  usergroups.sig: the shell's ONE registry liaison. Registrant
          ::  prefixes nest-clobber (%how replaces every road under the
          ::  sender's prefix), so exactly one root-prefix fiber makes all
          ::  of the shell's grants. public.json is inert data it writes.
          [%fall %& [/ %'usergroups.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'public.json'] [[/ %json] [%a ~]]]
          [%fall %& [/ %'peers.json'] [[/ %json] [%a ~]]]
          ::  authoritative permission state, in two component grubs:
          ::  permit/approved (app path -> consented manifest) and
          ::  permit/hidden (suppressed alias options). The derived views
          ::  (aliases, asks, weirs) are computed live per request from these
          ::  plus a shallow /apps scan — always fresh, never materialized.
          [%fall %| /permit empty-dir:loader]
          [%fall %& [/permit %'approved.json'] [[/ %json] [%o ~]]]
          [%fall %& [/permit %'hidden.json'] [[/ %json] [%o ~]]]
          ::  permit/notified: app path -> the pending ask we last notified
          ::  about (same road-shape as an approved manifest's `declared`).
          ::  Dedups the "wants permissions" banner so a still-pending ask
          ::  does not re-fire on every reload. Dropped when the app leaves.
          [%fall %& [/permit %'notified.json'] [[/ %json] [%o ~]]]
          ::  /cache: REBUILDABLE view caches, follower-maintained — kept
          ::  apart from /permit so the system-of-record tier is visible
          ::  at a glance. Losing /cache costs nothing; losing /permit
          ::  loses consent history.
          [%fall %| /cache empty-dir:loader]
          [%fall %& [/cache %'asks.json'] [[/ %json] [%a ~]]]
          [%fall %& [/cache %'aliases.json'] [[/ %json] [%o ~]]]
          [%fall %& [/cache %'weirs.json'] [[/ %json] [%o ~]]]
          ::  permit/share.json: per-alias discovery visibility — the USER's
          ::  map of @alias -> 'public' | [usergroup paths]. Absent = private
          ::  (the default): an app never chooses its own discoverability.
          [%fall %& [/permit %'share.json'] [[/ %json] [%o ~]]]
          ::  /sys/link: the discovery registry lives at the system level.
          ::  One dest.json per @name holding its claimants+locations —
          ::  the alias menu made materialized-and-subscribable, so peers
          ::  (local or cross-ship) can `keep` a name and learn where its
          ::  app lives, and get pushed the new location when it moves.
          ::  sweep.sig: poke target for "new apps may exist — look now".
          ::  Desk installs poke it after applying their bill, so fresh
          ::  apps get followers (and their rise-notify) immediately
          ::  instead of waiting for a permits page load.
          [%fall %& [/ %'sweep.sig'] [[/ %sig] ~]]
          ::  bootstrap.sig: runs the repos-to-sync setup ONCE on first boot
          ::  (guarded by the /bootstrapped.json marker it writes), then never
          ::  again automatically. The marker is NOT seeded here — its absence
          ::  is what signals "first boot".
          [%fall %& [/ %'bootstrap.sig'] [[/ %sig] ~]]
          ::  /sync: one pure-follower grub per app, mirroring /apps. Each
          ::  follows its app's files by subscription and pings the scanner
          ::  to reconcile — so /sys/link (and the asks) stay current without a
          ::  poll. /sync/main.sig is the coordinator: it watches /apps
          ::  membership and spawns/keeps the followers.
          [%fall %| /sync empty-dir:loader]
          ::  /share: per-usergroup discovery directories, derived from
          ::  local desks' share.usergroups. /share/<group>/desks.json lists
          ::  the desks that group may subscribe to and where their code +
          ::  version live. Rebuilt from the live grants by the followers.
          [%fall %| /share empty-dir:loader]
          [%fall %| /peers empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
          ::  /docs: the grubbery handbook. Markdown grubs served at
          ::  /apps/grubbery/docs and rendered client-side (marked). Authored
          ::  in the *-md stubs below and deployed with %over — the Hoon
          ::  source is the source of truth while there's no in-browser
          ::  editor. When that editor lands these flip to %fall (seed-once)
          ::  so live edits win instead of being clobbered on reload.
          [%fall %| /docs empty-dir:loader]
          [%over %& [/docs %'intro.md'] [[/ %mime] (md-seed intro-md)]]
          [%over %& [/docs %'nexuses.md'] [[/ %mime] (md-seed nexuses-md)]]
          [%over %& [/docs %'grubs.md'] [[/ %mime] (md-seed grubs-md)]]
          [%over %& [/docs %'fibers.md'] [[/ %mime] (md-seed fibers-md)]]
          [%over %& [/docs %'roadmap.md'] [[/ %mime] (md-seed roadmap-md)]]
          ::  tutorials
          [%over %& [/docs %'hello-nexus.md'] [[/ %mime] (md-seed hello-nexus-md)]]
          [%over %& [/docs %'serving-a-page.md'] [[/ %mime] (md-seed serving-a-page-md)]]
          [%over %& [/docs %'talking-to-apis.md'] [[/ %mime] (md-seed talking-to-apis-md)]]
          ::  principles
          [%over %& [/docs %'namespace-first.md'] [[/ %mime] (md-seed namespace-first-md)]]
          [%over %& [/docs %'reboot-anytime.md'] [[/ %mime] (md-seed reboot-anytime-md)]]
          [%over %& [/docs %'composition.md'] [[/ %mime] (md-seed composition-md)]]
          ::  subsystems
          [%over %& [/docs %'permissions.md'] [[/ %mime] (md-seed permissions-md)]]
          [%over %& [/docs %'desks.md'] [[/ %mime] (md-seed desks-md)]]
          [%over %& [/docs %'cross-ship.md'] [[/ %mime] (md-seed cross-ship-md)]]
          [%over %& [/docs %'http-serving.md'] [[/ %mime] (md-seed http-serving-md)]]
          [%over %& [/docs %'code-nexuses.md'] [[/ %mime] (md-seed code-nexuses-md)]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] app-css]]
          [%over %& [/ %'permits.html'] [[/ %mime] permits-html]]
          ::  docs-agent: the docs chatbot as a CONTAINED, sandboxed nexus
          ::  (neck [/ %docs-agent], code at nex/docs-agent.hoon). The
          ::  SANDBOX is the weir WE set on it here (kernel-enforced): the
          ::  whole agent — and anything it mounts — may only read /docs,
          ::  root /code, and the raw grubbery desk source, poke the metered
          ::  provider + bowl, and write within its own subtree.
          [%fall %| /docs/agent [`[`[/shell %docs-agent] `agent-weir %.n ~] ~]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/tiles])
        (http-dispatch:io %shell)
          ::  usergroups.sig: register once, then hold every shell grant
          ::  current — the base /public grant on public.json plus the
          ::  per-group /sys/link shares from permit/share.json — and keep
          ::  public.json (inert json) an honest reflection of the /public
          ::  group's weir. Event-driven: wakes on share.json changes, on
          ::  the public group's weir changing (desk grants), or a poke.
          ::
          [~ %'usergroups.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell registry: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        ;<  ~  bind:m  (reg-register-at:io here)
        =/  nex-dir=path  path.here
        ;<  *  bind:m
          (keep:io /share (nex-road:io rail [%& /permit %'share.json']) ~)
        ;<  *  bind:m
          (keep:io /pubw [%& %& /sys/ames/usergroups/'public.grp' %'how.weir'] ~)
        =|  prev=(set path)
        |-
        ;<  shares=(map path (set road:tarball))  bind:m  (read-shares rail nex-dir)
        ::  one %how per group, total-state: base grant + that group's name
        ::  shares. /public always recomputes (the base grant rides it);
        ::  prev keeps un-shared groups in the set once more to clear them.
        =/  groups=(list path)
          ~(tap in (~(put in (~(uni in prev) ~(key by shares))) /public))
        ;<  ~  bind:m
          =/  m  (fiber:fiber:nexus ,~)
          |-  ^-  form:m
          ?~  groups  (pure:m ~)
          =/  grp=path  i.groups
          =/  link-roads=(set road:tarball)  (fall (~(get by shares) grp) ~)
          =/  base=(set road:tarball)
            ?.  =(/public grp)  ~
            %-  sy
            ^-  (list road:tarball)
            :~  [%& %& nex-dir %'public.json']
                ::  the new desk storefront — the /public group reads this to
                ::  discover which desks it may subscribe to and where.
                [%& %& (weld nex-dir /share/public) %'desks.json']
            ==
          =/  peeks=(set road:tarball)  (~(uni in base) link-roads)
          ;<  ~  bind:m  (reg-how:io grp [~ ~ peeks])
          $(groups t.groups)
        =.  prev  ~(key by shares)
        ;<  ~  bind:m  (reg-poke:io [%gc ~])
        ;<  paths=(list @t)  bind:m  scan-public
        ;<  cur=(unit json)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'public.json']) ,json)
        =/  next=json  a+(turn paths |=(p=@t s+p))
        ;<  ~  bind:m
          ?:  =(`next cur)  (pure:(fiber:fiber:nexus ,~) ~)
          (over:io (nex-road:io rail [%& / %'public.json']) [[/ %json] next])
        ;<  ~  bind:m  take-reg-wake
        $
          ::  sweep.sig: on any poke, spawn followers for apps that lack
          ::  them and refresh the caches if anything new appeared.
          ::
          [~ %'sweep.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell sweep: failed")
        |-
        ;<  *  bind:m  take-poke:io
        ;<  made=?  bind:m  (spawn-followers rail)
        ;<  ~  bind:m
          ?.  made  (pure:(fiber:fiber:nexus ,~) ~)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-links rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
          (build-weirs rail)
        ::  desk shares change without spawning a follower, so /share must
        ::  rebuild on every sweep, not only when a new app appeared.
        ;<  ~  bind:m  (build-share rail)
        $
          ::  bootstrap.sig: first-boot setup. On the FIRST rise where the
          ::  /bootstrapped.json marker is absent, run the repos-to-sync
          ::  pipeline once and write the marker. The marker persists, so every
          ::  later rise (restart/crash-recovery) skips — setup runs exactly
          ::  once. The manual POST /desks/sync-defaults stays available.
          ::
          [~ %'bootstrap.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell bootstrap: failed")
        ;<  done=?  bind:m
          (peek-exists:io (nex-road:io rail [%& / %'bootstrapped.json']))
        ?:  done  (pure:m ~)
        ~&  >  %shell-bootstrap-first-boot
        ;<  ~  bind:m  sync-defaults
        ;<  err=(unit tang)  bind:m
          (make-soft:io (nex-road:io rail [%& / %'bootstrapped.json']) |+[[[/ %json] `json`[%b %.y]] ~])
        ~?  >>>  ?=(^ err)  %shell-bootstrap-mark-failed
        (pure:m ~)
          ::  peers.json: poke target for managing which ships' public
          ::  desk directories we mirror. {"add": "~ship"} makes the
          ::  mirror grub, {"del": "~ship"} culls it. Pure local CRUD:
          ::  each mirror grub runs its own fiber and owns its own
          ::  network traffic, so an unreachable ship can never block
          ::  this loop.
          ::
          [~ %'peers.json']
        ;<  ~  bind:m  (rise-wait:io prod "%shell peers: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  cmd=json  (fall (mole |.(!<(json q.sage))) *json)
        =/  add=(unit @t)  (jget cmd 'add')
        =/  del=(unit @t)  (jget cmd 'del')
        ?^  add
          ?~  (slaw %p u.add)
            ~&  >>>  [%shell-peers-bad-ship u.add]
            $
          =/  =road:tarball  (nex-road:io rail [%& /peers (peer-file u.add)])
          ;<  has=?  bind:m  (peek-exists:io road)
          ?:  has  $
          ;<  err=(unit tang)  bind:m
            (make-soft:io road |+[[[/ %json] `json`[%a ~]] ~])
          ~?  >>>  ?=(^ err)  [%shell-peer-make-failed u.add]
          $
        ?^  del
          ;<  err=(unit tang)  bind:m
            (cull-soft:io (nex-road:io rail [%& /peers (peer-file u.del)]))
          ~?  >>>  ?=(^ err)  [%shell-peer-cull-failed u.del]
          $
        $
          ::  /sync/<app>: a pure follower. Subscribes to its app's tree and
          ::  on any change (alias.json, weir.json, …) pings the scanner to
          ::  reconcile /sys/link and the asks. Holds no state, writes nothing.
          ::
          [[%sync *] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell follow: failed")
        =/  ap=(unit path)  (app-path-of rail)
        ?~  ap  (pure:m ~)
        ;<  ~  bind:m  drop-stale-subs
        ::  follow ONLY the declaration files — never the whole app tree, or
        ::  a ticking app (counter, weather) fires us on every data write.
        ;<  *  bind:m  (keep:io /alias [%& %& u.ap %'alias.json'] ~)
        ;<  *  bind:m  (keep:io /weir [%& %& u.ap %'weir.json'] ~)
        ::  a desk's opening declaration — absent for non-desk apps (a sub on
        ::  an absent road is legal and fires if it ever appears).
        ;<  *  bind:m  (keep:io /shareg [%& %& u.ap %'share.usergroups'] ~)
        ::  notify at rise too: a fresh install's ask predates this
        ::  follower, so there is no change-news to catch — and an ask
        ::  still pending across a reload deserves the re-ping anyway.
        ;<  ~  bind:m  (notify-if-unsettled rail u.ap)
        |-
        ;<  ~  bind:m  take-any-news
        ;<  live=?  bind:m  (peek-exists:io [%& %| u.ap])
        ?.  live
          ::  our app was uninstalled — consent dies with the app: drop its
          ::  approval record so a reinstall asks fresh (a stale record
          ::  would settle the new ask silently while the fresh instance
          ::  sits jailed). Then reconcile the caches and self-clean.
          ;<  approved=(map @t json)  bind:m  (read-approved rail)
          =/  key=@t  (crip (spud u.ap))
          ;<  ~  bind:m
            ?.  (~(has by approved) key)  (pure:(fiber:fiber:nexus ,~) ~)
            %+  put:io  (nex-road:io rail [%& /permit %'approved.json'])
            [[/ %json] [%o (~(del by approved) key)]]
          ::  drop the notify record too, so a reinstall re-surfaces its ask.
          ;<  notified=(map @t json)  bind:m  (read-notified rail)
          ;<  ~  bind:m
            ?.  (~(has by notified) key)  (pure:(fiber:fiber:nexus ,~) ~)
            %+  put:io  (nex-road:io rail [%& /permit %'notified.json'])
            [[/ %json] [%o (~(del by notified) key)]]
          ;<  ~  bind:m  (build-links rail)
          ;<  ~  bind:m  (build-asks rail)
          ;<  ~  bind:m  (build-share rail)
          (pure:m ~)
        ::  a real change to our app's declarations: notify if the ask is
        ::  unsettled (the subscription IS the dedup — news only fires on
        ::  actual change), then refresh the caches.
        ;<  ~  bind:m  (notify-if-unsettled rail u.ap)
        ;<  ~  bind:m  (build-links rail)
        ;<  ~  bind:m  (build-asks rail)
        ;<  ~  bind:m  (build-aliases rail)
        ;<  ~  bind:m  (build-weirs rail)
        ;<  ~  bind:m  (build-share rail)
        $
          ::  /peers/<ship>.json: live mirror of one ship's public desk
          ::  directory, held current by subscription. All network
          ::  traffic for the ship happens here; if the ship is
          ::  unreachable, only this fiber waits.
          ::
          [[%peers ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell mirror: failed")
        =/  s=@t  (mirror-ship name.rail)
        ?~  (slaw %p s)  (pure:m ~)
        ;<  *  bind:m  (keep:io /pub (peer-pub-road s) ~)
        ;<  ~  bind:m  (refresh-mirror s)
        |-
        ;<  *  bind:m  (take-news:io /pub)
        ;<  ~  bind:m  (refresh-mirror s)
        $
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  prefix=path  /grubbery/tiles
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ::  POST /apps/grubbery/permits → a user permission action, applied
        ::  directly (we are already gated to src==our, the authenticated
        ::  user). Writes the authoritative component grubs — permit/approved/
        ::  <app> or permit/hidden — sands the weir, then nudges the derived
        ::  views to refresh. The shell is the ship's only weir-writer.
        ?:  &(=('POST' method.request.req) ?=([%permits ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  act=@t  ?.(?=(%o -.jon) '' (fall (jget jon 'action') ''))
          ;<  now=@da  bind:m  get-time:io
          ;<  ~  bind:m  (apply-permit-action rail jon act now)
          ::  the action changed the views — rebuild the caches before the
          ::  UI reloads them.
          ;<  ~  bind:m  (build-asks rail)
          ;<  ~  bind:m  (build-aliases rail)
          ;<  ~  bind:m  (build-weirs rail)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::  POST /uninstall {root}: delete an installed app from its tile.
        ::  A desk-nested root uninstalls the WHOLE desk (the UI says so
        ::  and lists what ships with it). Consent records, followers, and
        ::  caches all reconcile via the follower self-clean.
        ?:  &(=('POST' method.request.req) ?=([%uninstall ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  rt=(unit path)  (soft-path (fall (jget jon 'root') ''))
          =/  target=(unit path)
            ?~  rt  ~
            ?:  ?=([%apps @ %desk %data @ ~] u.rt)  `/apps/[i.t.u.rt]
            ?:  ?=([%apps @ ~] u.rt)  `u.rt
            ~
          ?~  target
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'bad root')])
            (pure:m ~)
          ;<  err=(unit tang)  bind:m  (cull-soft:io [%& %| u.target])
          ~?  >>>  ?=(^ err)  [%shell-uninstall-failed u.target]
          =/  code=@ud  ?~(err 200 500)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html ?~(err 'ok' 'failed'))])
          (pure:m ~)
        ::  POST /desks/peers {add|del: ship}: forward to our own peers.json
        ::  fiber (folded in from the retired /desks nexus).
        ?:  &(=('POST' method.request.req) ?=([%desks %peers ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          ;<  ~  bind:m  (poke:io (nex-road:io rail [%& / %'peers.json']) [[/ %json] jon])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::  POST /desks/add {name, code}: install a peer's shared desk as a
        ::  local cross-ship /desk. Make a trusted [/ %desk] wrapper (weir ~ —
        ::  it enforces via apply-bill), then poke its source.json with the
        ::  peer-prefixed code road (from the peer card); the /desk follows it
        ::  and syncs the code in (the version rides inside /code/version.json).
        ?:  &(=('POST' method.request.req) ?=([%desks %add ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  name=@t  (jstr jon 'name')
          =/  code=@t  (jstr jon 'code')
          ?:  =('' name)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'name required')])
            (pure:m ~)
          ?:  =('' code)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'code required')])
            (pure:m ~)
          =/  dir-path=path  /apps/[(cat 3 `@ta`name '.desk')]
          ;<  live=?  bind:m  (peek-exists:io [%& %| dir-path])
          ?:  live
            ;<  ~  bind:m  (send-simple:srv eyre-id [[409 ~] `(as-octs:mimes:html 'a desk by that name already exists')])
            (pure:m ~)
          ;<  ~  bind:m
            (make:io [%& %| dir-path] &+`bole:tarball`[`[`[/ %desk] ~ %.n ~] ~])
          =/  source=json  (pairs:enjs:format ~[['code' s+code]])
          ;<  ~  bind:m  (poke:io [%& %& dir-path %'source.json'] [[/ %json] source])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'created')])
          (pure:m ~)
        ::  POST /desks/sync-defaults: bootstrap the shipped "repos to sync"
        ::  list — for each entry, ensure its git_repo (polling github) and a
        ::  desk following the repo's checked-out tree exist and are wired.
        ::  Idempotent: guarded makes + a replace-in-place source poke, so it's
        ::  safe to re-run. This is the shell-owned setup pipeline (replaces the
        ::  old root.hoon contacts/wallet seeds).
        ?:  &(=('POST' method.request.req) ?=([%desks %sync-defaults ~] suffix))
          ;<  ~  bind:m  sync-defaults
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'synced')])
          (pure:m ~)
        ::  POST /desks/delete {app}: cull the /apps/<app> subtree.
        ?:  &(=('POST' method.request.req) ?=([%desks %delete ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  app=@t  (jstr jon 'app')
          ?:  =('' app)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'app required')])
            (pure:m ~)
          ;<  ~  bind:m  (cull:io [%& %| /apps/[(crip (trip app))]])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'deleted')])
          (pure:m ~)
        ::  tile store, served from the tiles data ball over the namespace
        ::  /grubbery/tiles/tiles.json → all tile data
        ?:  ?=([%'tiles.json' ~] suffix)
          ;<  tiles=(list [tile (unit path)])  bind:m  read-all-tiles
          =/  =json  (tiles-to-json tiles)
          =/  body=octs  (as-octs:mimes:html (en:json:html json))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `body])
          (pure:m ~)
        ::  /grubbery/tiles/icon/<nexus-root-path> → serve a nexus's icon
        ::  file. The path may be deep (a desk-install's desk/data/<nexus>).
        ?:  ?=([%icon ^] suffix)
          ::  reconstruct the nexus root from the compressed icon path:
          ::  <desk>/<nexus> -> /apps/<desk>/desk/data/<nexus>, a bare
          ::  <nexus> -> /apps/<nexus>, or a full /apps/... path as-is.
          =/  segs=path  t.suffix
          =/  root=path
            ?:  ?=([%apps *] segs)  segs
            ?:  ?=([@ @ ~] segs)  ~[%apps i.segs %desk %data i.t.segs]
            ?:  ?=([@ ~] segs)  ~[%apps i.segs]
            [%apps segs]
          ;<  kid-root=view:nexus  bind:m
            (peek-shallow:io [%& %| root] ~)
          =/  icon-file=(unit [name=@ta sang=sang:tarball])
            ?.  ?=([%ball *] kid-root)  ~
            =/  =lump:tarball  (fall fil.ball.kid-root *lump:tarball)
            %-  ~(rep by contents.lump)
            |=  [[n=@ta s=sang:tarball g=? b=(unit tang)] out=(unit [name=@ta sang=sang:tarball])]
            ?^  out  out
            =/  nam=tape  (trip n)
            ?.  =("icon." (scag 5 nam))  out
            ?:  (is-boom:tarball s)  out
            `[n s]
          ?~  icon-file
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.u.icon-file))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
          (pure:m ~)
        ::  static assets: the shell's javascript and stylesheet
        ?:  |(?=([%'app.js' ~] suffix) ?=([%'style.css' ~] suffix))
          =/  fname=@ta  ?>(?=([@ ~] suffix) i.suffix)
          =/  ctype=@t   ?:(?=([%'app.js' ~] suffix) 'text/javascript' 'text/css')
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& ~ fname]) `[/ %mime])
          ?.  ?=([%file *] fv)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.fv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' ctype]]] `q.mime])
          (pure:m ~)
        ::  /apps/grubbery/permits → the read-only permissions page
        ?:  ?=([%permits ~] suffix)
          ::  the sweep: a UI request IS the scan — pick up any apps that
          ::  don't have followers yet (new installs). ~25 cheap existence
          ::  checks; followers do everything else event-driven.
          ;<  made=?  bind:m  (spawn-followers rail)
          ::  a fresh follower won't fire until its app NEXT changes, so a
          ::  sweep that spawned anything rebuilds the caches once now.
          ;<  ~  bind:m
            ?.  made  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-links rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
            (build-weirs rail)
          ::  /share tracks desk shares, which move without a new follower —
          ::  rebuild it on every permits load, not only when one spawned.
          ;<  ~  bind:m  (build-share rail)
          ::  lazy seed: if the view caches are empty (fresh boot, never
          ::  rebuilt), build them once now; afterwards every load is pure
          ::  cached reads.
          ;<  av=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /cache %'aliases.json']) ,json)
          ;<  ~  bind:m
            ?.  |(?=(~ av) =([%o ~] u.av))  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
            (build-weirs rail)
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& ~ %'permits.html']) `[/ %mime])
          ?.  ?=([%file *] fv)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.fv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/html']]] `q.mime])
          (pure:m ~)
        ::  /apps/grubbery/approved.json → the per-app approval records,
        ::  aggregated into a map keyed by app path (what the UI keys on).
        ?:  ?=([%'approved.json' ~] suffix)
          ;<  approved=(map @t json)  bind:m  (read-approved rail)
          =/  bod=octs  (as-octs:mimes:html (en:json:html [%o approved]))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/weirs.json → ground truth: the live weir on each
        ::  governed dir, with the registry's intention overlaid per road.
        ?:  ?=([%'weirs.json' ~] suffix)
          ;<  wv=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /cache %'weirs.json']) ,json)
          =/  bod=octs  (as-octs:mimes:html (en:json:html (fall wv [%o ~])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/aliases.json → the alias directory as menus:
        ::  app-declared alias.json options merged with your stored ones.
        ::  /grubbery/tiles/desks/peers → peers' published desks, enriched
        ::  for the "add apps" browser (folded in from the retired /desks).
        ?:  ?=([%desks %peers ~] suffix)
          ;<  lst=json  bind:m  gather-peers
          =/  bod=octs  (as-octs:mimes:html (en:json:html lst))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /grubbery/tiles/desks/taken → every /apps child name, for
        ::  install-name availability checks.
        ?:  ?=([%desks %taken ~] suffix)
          ;<  =view:nexus  bind:m  (peek-shallow:io [%& %| /apps] ~)
          =/  names=(list @ta)
            ?.  ?=([%ball *] view)  ~
            ~(tap in ~(key by dir.ball.view))
          =/  lst=json  a+(turn names |=(n=@ta `json`s+`@t`n))
          =/  bod=octs  (as-octs:mimes:html (en:json:html lst))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /grubbery/tiles/desks/list → your local desks, for the publish UI.
        ?:  ?=([%desks %list ~] suffix)
          ;<  lst=json  bind:m  discover-desks
          =/  bod=octs  (as-octs:mimes:html (en:json:html lst))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /grubbery/tiles/desks/stock → the vendored default-repos list with
        ::  each entry's synced status, for the Stock tab.
        ?:  ?=([%desks %stock ~] suffix)
          ;<  lst=json  bind:m  stock-status
          =/  bod=octs  (as-octs:mimes:html (en:json:html lst))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ?:  ?=([%'aliases.json' ~] suffix)
          ;<  av=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /cache %'aliases.json']) ,json)
          =/  bod=octs  (as-octs:mimes:html (en:json:html (fall av [%o ~])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/asks.json → each app's declared weir.json ask.
        ?:  ?=([%'asks.json' ~] suffix)
          ;<  av=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /cache %'asks.json']) ,json)
          =/  bod=octs  (as-octs:mimes:html (en:json:html (fall av [%a ~])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/share.json → per-alias discovery visibility map.
        ?:  ?=([%'share.json' ~] suffix)
          ;<  sv=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /permit %'share.json']) ,json)
          =/  bod=octs  (as-octs:mimes:html (en:json:html (fall sv [%o ~])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/groups.json → the ship's usergroups (names).
        ?:  ?=([%'groups.json' ~] suffix)
          ;<  gv=view:nexus  bind:m
            (peek-shallow:io [%& %| /sys/ames/usergroups] ~)
          =/  names=(list @t)
            ?.  ?=([%ball *] gv)  ~
            ::  storage kids are <group>.grp; the group's path is the stem.
            %+  turn  (sort ~(tap in ~(key by dir.ball.gv)) aor)
            |=  g=@ta
            ^-  @t
            =/  t=tape  (trip g)
            =/  stem=tape
              ?:  &((gth (lent t) 4) =(".grp" (slag (sub (lent t) 4) t)))
                (scag (sub (lent t) 4) t)
              t
            (crip "/{stem}")
          =/  bod=octs
            (as-octs:mimes:html (en:json:html a+(turn names |=(g=@t s+g))))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /icon.svg → the shell's favicon
        ?:  ?=([%'icon.svg' ~] suffix)
          =/  bod=octs  (as-octs:mimes:html shell-icon)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'image/svg+xml']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/docs → the handbook reader shell
        ?:  ?=([%docs ~] suffix)
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils docs-html))
          (pure:m ~)
        ::  docs client assets: our reader script + the markdown renderer
        ?:  ?=([%docs %'docs.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.docs-js])
          (pure:m ~)
        ::  the docs assistant widget: sandboxed chatbot UI (js + css)
        ?:  ?=([%docs %'chat.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.chat-js])
          (pure:m ~)
        ?:  ?=([%docs %'chat.css' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/css']]] `q.chat-css])
          (pure:m ~)
        ?:  ?=([%docs %'marked.min.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.marked-js])
          (pure:m ~)
        ?:  ?=([%docs %'hoon-grammar.json' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `q.hoon-grammar])
          (pure:m ~)
        ::  /apps/grubbery/docs/nav.json → the sidebar tree. Served straight
        ::  from code (docs-nav) so it's one source of truth: adding a doc is
        ::  a nav line + a seed row. When the in-browser editor lands we can
        ::  promote this to a live-editable grub without the seed-once trap.
        ?:  ?=([%docs %'nav.json' ~] suffix)
          =/  bod=octs  (as-octs:mimes:html (en:json:html docs-nav))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/docs/search?q=<query> → server-side full-text
        ::  search over the /docs grubs. Returns hits (path+title+snippet);
        ::  the browser never loads the whole corpus, only what it clicks.
        ?:  ?=([%docs %search ~] suffix)
          =/  args=quay:eyre  args:(parse-url:http-utils url.request.req)
          =/  ql  (skim args |=([p=@t q=@t] =(p 'q')))
          =/  q=@t  ?~(ql '' q.i.ql)
          =/  qlow=tape  (cass (trip q))
          ?:  =(~ qlow)
            =/  bod=octs  (as-octs:mimes:html (en:json:html [%a ~]))
            ;<  ~  bind:m
              (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
            (pure:m ~)
          =/  items=(list [path=@t title=@t])  docs-list
          =|  hits=(list json)
          |-  ^-  process:fiber:nexus
          ?~  items
            =/  bod=octs  (as-octs:mimes:html (en:json:html [%a (flop hits)]))
            ;<  ~  bind:m
              (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
            (pure:m ~)
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /docs `@ta`path.i.items]) `[/ %mime])
          =/  txt=@t
            ?.  ?=([%file *] fv)  ''
            =/  mm=mime  !<(mime (need-vase:tarball sang.fv))
            `@t`q.q.mm
          =/  snip=(unit @t)  (find-snippet txt q)
          =/  tmatch=?  !=(~ (find qlow (cass (trip title.i.items))))
          =?  hits  |(?=(^ snip) tmatch)
            =/  s=@t  ?~(snip title.i.items u.snip)
            [(doc-hit path.i.items title.i.items s) hits]
          $(items t.items)
        ::  /apps/grubbery/docs/page?path=<name.md> → one doc's raw markdown
        ?:  ?=([%docs %page ~] suffix)
          =/  args=quay:eyre  args:(parse-url:http-utils url.request.req)
          =/  pl  (skim args |=([p=@t q=@t] =(p 'path')))
          =/  pax=@t  ?~(pl '' q.i.pl)
          ?:  =('' pax)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'path required')])
            (pure:m ~)
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /docs `@ta`pax]) `[/ %mime])
          ?.  ?=([%file *] fv)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.fv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/plain']]] `q.mime])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/chat → the docs assistant. One metered
        ::  round-trip through the anthropic proxy; returns {reply}.
        ?:  &(=('POST' method.request.req) ?=([%docs %chat ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  msg=@t  (fall (jget jon 'message') '')
          ;<  [reply=@t trace=json]  bind:m  (ask-agent rail msg)
          =/  bod=octs
            %-  as-octs:mimes:html
            %-  en:json:html
            (pairs:enjs:format ~[['reply' s+reply] ['trace' trace]])
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  GET /apps/grubbery/docs/history → the stored conversation, read
        ::  straight from the agent's chat.json. Restores across refreshes.
        ?:  ?=([%docs %history ~] suffix)
          =/  chat-road=road:tarball
            (nex-road:io rail [%& /docs/agent %'chat.json'])
          ;<  fv=view:nexus  bind:m  (peek:io chat-road `[/ %json])
          =/  conv=json
            ?.  ?=([%file *] fv)  [%a ~]
            (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) [%a ~])
          =/  bod=octs  (as-octs:mimes:html (en:json:html conv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/clear → archive + reset the conversation.
        ?:  &(=('POST' method.request.req) ?=([%docs %clear ~] suffix))
          ;<  ~  bind:m
            %-  poke:io
            :+  (nex-road:io rail [%& /docs/agent %'main.sig'])
              [/ %json]
            (pairs:enjs:format ~[['action' s+'clear']])
          =/  bod=octs
            (as-octs:mimes:html (en:json:html (pairs:enjs:format ~[['ok' [%b %.y]]])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/say {chat-id, message} → poke the
        ::  docs-agent turn handler. Sign of life for the new nexus: the
        ::  message lands as a grub at docs-agent.docs-agent/chats/<id>.json.
        ?:  &(=('POST' method.request.req) ?=([%docs %say ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          ;<  ~  bind:m
            (poke:io (nex-road:io rail [%& /docs/agent %'main.sig']) [/ %json] jon)
          =/  bod=octs
            (as-octs:mimes:html (en:json:html (pairs:enjs:format ~[['ok' [%b %.y]]])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/stop → interrupt the docs-agent's
        ::  current turn (manual cancel). Pokes the turn handler, which its
        ::  in-flight await catches and aborts.
        ?:  &(=('POST' method.request.req) ?=([%docs %stop ~] suffix))
          ;<  ~  bind:m
            %-  poke:io
            :+  (nex-road:io rail [%& /docs/agent %'main.sig'])
              [/ %json]
            (pairs:enjs:format ~[['action' s+'interrupt']])
          =/  bod=octs
            (as-octs:mimes:html (en:json:html (pairs:enjs:format ~[['ok' [%b %.y]]])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/config {system, model, max_tokens} →
        ::  write the agent's prompt + model config grubs.
        ?:  &(=('POST' method.request.req) ?=([%docs %config ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  po=(map @t json)  ?:(?=([%o *] jon) p.jon ~)
          =/  sys=@t    (fall (jget jon 'system') '')
          =/  model=@t  =/(mo=@t (fall (jget jon 'model') '') ?:(=('' mo) 'claude-sonnet-4-6' mo))
          =/  mt=json   (fall (~(get by po) 'max_tokens') [%n '1024'])
          ;<  ~  bind:m
            %-  over:io
            :-  (nex-road:io rail [%& /docs/agent %'system.md'])
            [[/ %mime] [/text/markdown (as-octs:mimes:html sys)]]
          ;<  ~  bind:m
            %-  over:io
            :-  (nex-road:io rail [%& /docs/agent %'config.json'])
            [[/ %json] (pairs:enjs:format ~[['model' s+model] ['max_tokens' mt]])]
          =/  bod=octs
            (as-octs:mimes:html (en:json:html (pairs:enjs:format ~[['ok' [%b %.y]]])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  GET /apps/grubbery/docs/config → the agent's current prompt +
        ::  model config, for the chat config modal.
        ?:  ?=([%docs %config ~] suffix)
          ;<  sv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /docs/agent %'system.md']) `[/ %mime])
          =/  sys=@t
            ?.  ?=([%file *] sv)  ''
            `@t`q.q:!<(mime (need-vase:tarball sang.sv))
          ;<  cv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /docs/agent %'config.json']) `[/ %json])
          =/  cfg=json
            ?.  ?=([%file *] cv)  [%o ~]
            (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) [%o ~])
          =/  bod=octs
            %-  as-octs:mimes:html
            (en:json:html (pairs:enjs:format ~[['system' s+sys] ['config' cfg]]))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  default → serve the home page (static file, /<-imported home-html)
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils home-html))
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  md-seed: wrap stub markdown text as a text/markdown mime, for seeding
::  the /docs grubs. Seeds only fire once (%fall), so this is a starting
::  point the user edits in place — never re-applied over live content.
++  md-seed
  |=  t=@t  ^-  mime
  [/text/markdown (as-octs:mimes:html t)]
::  docs-nav: the initial sidebar tree, the SUMMARY equivalent. Stored as
::  an editable grub (nav.json) so reordering/adding is a data edit, not a
::  code change.
::  docs-nav: THE single structured source for the docs sidebar, as JSON.
::  Built with two gates — a `doc` leaf ({title,path}) and a `sec` section
::  ({title,kids}). A section's kids is just a list of json, so sections
::  NEST ARBITRARILY: drop a `sec` inside another `sec`'s kids for as many
::  levels as you like. No custom recursive mold (those loop the build) — we
::  lean on json's own recursion.
++  docs-nav
  ^-  json
  =/  doc
    |=  [p=@t t=@t]  ^-  json
    (pairs:enjs:format ~[['title' s+t] ['path' s+p]])
  =/  sec
    |=  [t=@t kids=(list json)]  ^-  json
    (pairs:enjs:format ~[['title' s+t] ['kids' [%a kids]]])
  :-  %a
  :~  (doc 'intro.md' 'Introduction')
      %+  sec  'Principles'
      :~  (doc 'namespace-first.md' 'Namespace-first')
          (doc 'reboot-anytime.md' 'Reboot-anytime')
          (doc 'composition.md' 'Composition over entanglement')
      ==
      %+  sec  'Core model'
      :~  (doc 'nexuses.md' 'Nexuses')
          (doc 'grubs.md' 'Grubs & the namespace')
          (doc 'fibers.md' 'Fibers')
      ==
      %+  sec  'Tutorials'
      :~  (doc 'hello-nexus.md' 'Your first nexus')
          (doc 'serving-a-page.md' 'Serving a web page')
          (doc 'talking-to-apis.md' 'Talking to external APIs')
      ==
      %+  sec  'Subsystems'
      :~  (doc 'permissions.md' 'Permissions')
          (doc 'desks.md' 'Desks')
          (doc 'cross-ship.md' 'Cross-ship')
          (doc 'http-serving.md' 'HTTP serving')
          (doc 'code-nexuses.md' 'Code nexuses')
      ==
      (doc 'roadmap.md' 'TODO & future topics')
  ==
::  docs-list: the flat [path title] of every doc, for server-side search.
::  Derived by walking the docs-nav json tree — recursion in the ARM (fine),
::  over json's existing recursive type. Arbitrary depth, still one source.
++  docs-list
  ^-  (list [path=@t title=@t])
  |^  (walk docs-nav)
  ++  walk
    |=  j=json
    ^-  (list [path=@t title=@t])
    ?.  ?=([%a *] j)  ~
    %-  zing
    %+  turn  p.j
    |=  node=json
    ^-  (list [path=@t title=@t])
    ?.  ?=([%o *] node)  ~
    =/  pax  (~(get by p.node) 'path')
    ?:  ?=([~ %s *] pax)
      =/  ttl  (~(get by p.node) 'title')
      ~[[p.u.pax ?:(?=([~ %s *] ttl) p.u.ttl '')]]
    =/  kids  (~(get by p.node) 'kids')
    ?~(kids ~ (walk u.kids))
  --
::  find-snippet: first line of `text` containing `q` (case-insensitive),
::  capped for display. ~ if no line matches. Grep's line-as-context trick.
++  find-snippet
  |=  [text=@t q=@t]
  ^-  (unit @t)
  =/  ql=tape  (cass (trip q))
  =/  lines=(list @t)  (to-wain:format text)
  |-  ^-  (unit @t)
  ?~  lines  ~
  ?.  =(~ (find ql (cass (trip i.lines))))
    `(crip (scag 200 (trip i.lines)))
  $(lines t.lines)
::  doc-hit: one search result as JSON.
++  doc-hit
  |=  [p=@t t=@t snip=@t]
  ^-  json
  (pairs:enjs:format ~[['path' s+p] ['title' s+t] ['snippet' s+snip]])
::  docs-system: the assistant's persona and scope. It answers only from
::  the docs, reached through its two read-only tools.
++  docs-system
  ^-  @t
  '''
  You are the Grubbery docs assistant, embedded in the Grubbery handbook.
  Answer questions about Grubbery using ONLY the search_docs and read_doc
  tools: search first, read the relevant docs, then answer from what they
  actually say. If the docs do not cover something, say so plainly rather
  than guessing. Be concrete and brief, and cite doc paths when useful.
  '''
::  docs-tools: the Anthropic tool schema for the two scoped capabilities.
++  docs-tools
  ^-  json
  =/  tool
    |=  [nm=@t desc=@t prop=@t pdesc=@t]
    ^-  json
    %-  pairs:enjs:format
    :~  ['name' s+nm]
        ['description' s+desc]
        :-  'input_schema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            :-  'properties'
            %-  pairs:enjs:format
            :~  :-  prop
                (pairs:enjs:format ~[['type' s+'string'] ['description' s+pdesc]])
            ==
            ['required' [%a ~[s+prop]]]
        ==
    ==
  :-  %a
  :~  %+  tool  'search_docs'
        :*  'Full-text search the Grubbery docs. Returns matching doc paths, titles, and snippets.'
            'query'  'the search terms'
        ==
      %+  tool  'read_doc'
        :*  'Read one Grubbery doc in full by its path (as returned by search_docs).'
            'path'  'the doc path, e.g. intro.md'
        ==
  ==
::  agent-weir: THE SANDBOX. The complete external reach we grant the
::  docs-agent when we mount it — the kernel refuses everything else.
::  Files (sigs) are granted as rails; directories as folds. make stays
::  empty: writing its own subtree (chats) is inherent, and it writes
::  nothing outside itself.
::    peek: the docs, root /code, the raw grubbery desk source, proxy calls
::    poke: bowl.sig (time + entropy), the proxy's main.sig
++  agent-weir
  ^-  weir:tarball
  =/  dir  |=(p=path `road:tarball`[%& %| p])
  =/  fil  |=([p=path n=@ta] `road:tarball`[%& %& p n])
  :*  make=~
      poke=(sy ~[(fil /sys 'bowl.sig') (fil /apps/'anthropic.anthropic' 'main.sig')])
      %-  sy
      :~  (dir /apps/'shell.shell'/docs)
          (dir /code)
          (dir /sys/clay/desks/grubbery)
          (dir /apps/'anthropic.anthropic'/calls)
      ==
  ==
::  ask-agent: bridge one browser turn to the docs-agent nexus. Subscribe
::  to the conversation grub, poke the agent's main.sig with {chat-id,
::  message}, await its write, and return the last (assistant) reply +
::  trace. All the model/tool work runs inside the sandboxed agent.
++  ask-agent
  |=  [=rail:tarball message=@t]
  =/  m  (fiber:fiber:nexus ,[reply=@t trace=json])
  ^-  form:m
  =/  chat-road=road:tarball
    (nex-road:io rail [%& /docs/agent %'chat.json'])
  =/  main-road=road:tarball
    (nex-road:io rail [%& /docs/agent %'main.sig'])
  ;<  *  bind:m  (keep:io /agent chat-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    (pairs:enjs:format ~[['message' s+message]])
  ;<  conv=json  bind:m  (await-agent chat-road)
  ;<  ~  bind:m  (drop:io /agent chat-road)
  =/  msgs=(list json)  ?.(?=([%a *] conv) ~ p.conv)
  ?~  msgs  (pure:m ['(no reply)' [%a ~]])
  =/  last=json  (rear msgs)
  ?.  ?=([%o *] last)  (pure:m ['(no reply)' [%a ~]])
  =/  reply=@t
    (fall (bind (~(get by p.last) 'content') |=(j=json ?>(?=(%s -.j) p.j))) '')
  =/  trace=json  (fall (~(get by p.last) 'trace') [%a ~])
  (pure:m [reply trace])
::  await-agent: wait for the agent's ASSISTANT write to the conversation
::  grub. The agent writes twice per turn (the user message first, then the
::  completed turn), so we skip news whose last message is still the user's.
++  await-agent
  |=  chat-road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  |-
  ;<  ~  bind:m  (take-news /agent)
  ;<  =view:nexus  bind:m  (peek:io chat-road ~)
  ?.  ?=([%file *] view)  $
  =/  conv=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) [%a ~])
  =/  msgs=(list json)  ?.(?=([%a *] conv) ~ p.conv)
  ?~  msgs  $
  =/  last=json  (rear msgs)
  ?.  &(?=([%o *] last) ?=([~ %s %'assistant'] (~(get by p.last) 'role')))  $
  (pure:m conv)
::  run-chat: the agent loop. Each turn pokes the metering proxy, and if
::  the model asks for tools, runs them (scoped to the docs) and loops.
::  Returns the final text plus a trace of every tool call, for the UI.
++  run-chat
  |=  [rail=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,[reply=@t trace=(list json)])
  ^-  form:m
  ::  keep only {role, content} per message — the client also carries a
  ::  `trace` field for its own UI, which the API rejects as an extra input.
  =/  msgs=(list json)
    =/  raw=(list json)
      ?.  ?=([%o *] jon)  ~
      =/  mj  (~(get by p.jon) 'messages')
      ?.(?=([~ %a *] mj) ~ p.u.mj)
    %+  turn  raw
    |=  mj=json
    ^-  json
    ?.  ?=([%o *] mj)  mj
    %-  pairs:enjs:format
    %+  murn  `(list @t)`~['role' 'content']
    |=  k=@t
    =/  v=(unit json)  (~(get by p.mj) k)
    ?~(v ~ `[k u.v])
  =|  trace=(list json)
  |-  ^-  form:m
  =/  body=json
    %-  pairs:enjs:format
    :~  ['model' s+'claude-sonnet-4-6']
        ['max_tokens' (numb:enjs:format 1.024)]
        ['system' s+docs-system]
        ['tools' docs-tools]
        ['messages' [%a msgs]]
    ==
  ;<  resp=json  bind:m  (call-anthropic body)
  =/  content-arr=(list json)
    ?.  ?=([%o *] resp)  ~
    =/  c  (~(get by p.resp) 'content')
    ?.(?=([~ %a *] c) ~ p.u.c)
  =/  tool-uses=(list json)
    %+  skim  content-arr
    |=  b=json
    ?&(?=([%o *] b) ?=([~ %s %'tool_use'] (~(get by p.b) 'type')))
  ?~  tool-uses
    (pure:m [(extract-text resp) (flop trace)])
  ;<  [results=(list json) new-trace=(list json)]  bind:m
    (run-tools rail tool-uses)
  =.  trace  (weld (flop new-trace) trace)
  =/  asst=json  (pairs:enjs:format ~[['role' s+'assistant'] ['content' [%a content-arr]]])
  =/  usr=json   (pairs:enjs:format ~[['role' s+'user'] ['content' [%a results]]])
  $(msgs (weld msgs ~[asst usr]))
::  call-anthropic: one metered round-trip. Subscribe to the call grub,
::  poke main.sig with {id, body}, await done, drop. Key custody and
::  metering live in the proxy.
++  call-anthropic
  |=  body=json
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  call-id=@t     (scot %uv (end [3 8] eny))
  =/  call-name=@ta  (crip "{(trip call-id)}.json")
  =/  main-road=road:tarball  [%& %& /apps/'anthropic.anthropic' %'main.sig']
  =/  call-road=road:tarball  [%& %& /apps/'anthropic.anthropic'/calls call-name]
  ;<  *  bind:m  (keep:io /chat-call call-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    (pairs:enjs:format ~[['id' s+call-id] ['body' body]])
  ;<  resp=json  bind:m  (await-call call-road)
  ;<  ~  bind:m  (drop:io /chat-call call-road)
  (pure:m resp)
::  run-tools: execute each requested tool_use, returning the tool_result
::  blocks (for the model) and trace entries (for the UI).
++  run-tools
  |=  [rail=rail:tarball tool-uses=(list json)]
  =/  m  (fiber:fiber:nexus ,[(list json) (list json)])
  ^-  form:m
  =|  results=(list json)
  =|  trace=(list json)
  |-  ^-  form:m
  ?~  tool-uses  (pure:m [(flop results) (flop trace)])
  =*  tu  i.tool-uses
  ?.  ?=([%o *] tu)  $(tool-uses t.tool-uses)
  =/  tid=@t      (jstr tu 'id')
  =/  name=@t     (jstr tu 'name')
  =/  input=json  (fall (~(get by p.tu) 'input') [%o ~])
  ;<  [out=@t note=@t]  bind:m  (run-one-tool rail name input)
  =/  result=json
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+tid]
        ['content' s+out]
    ==
  =/  arg=@t
    ?.  ?=([%o *] input)  ''
    =/  q  (~(get by p.input) 'query')
    ?:  ?=([~ %s *] q)  p.u.q
    =/  pa  (~(get by p.input) 'path')
    ?:(?=([~ %s *] pa) p.u.pa '')
  =/  te=json
    (pairs:enjs:format ~[['tool' s+name] ['arg' s+arg] ['note' s+note]])
  $(tool-uses t.tool-uses, results [result results], trace [te trace])
::  run-one-tool: dispatch by name to a scoped, read-only capability.
++  run-one-tool
  |=  [rail=rail:tarball name=@t input=json]
  =/  m  (fiber:fiber:nexus ,[@t @t])
  ^-  form:m
  ?:  =(name 'search_docs')
    (tool-search-docs rail ?:(?=([%o *] input) (jstr input 'query') ''))
  ?:  =(name 'read_doc')
    (tool-read-doc rail ?:(?=([%o *] input) (jstr input 'path') ''))
  (pure:m ['unknown tool' 'error'])
::  tool-search-docs: full-text search over the /docs grubs (the same
::  corpus the reader's search box uses). Returns a compact hit list.
++  tool-search-docs
  |=  [rail=rail:tarball q=@t]
  =/  m  (fiber:fiber:nexus ,[@t @t])
  ^-  form:m
  =/  qlow=tape  (cass (trip q))
  ?:  =(~ qlow)  (pure:m ['(empty query)' '0 hits'])
  =/  items=(list [path=@t title=@t])  docs-list
  =|  hits=(list tape)
  |-  ^-  form:m
  ?~  items
    =/  n=@ud  (lent hits)
    =/  out=@t
      ?:  =(0 n)  'No matching docs.'
      %-  crip
      %-  zing
      (turn (flop hits) |=(l=tape (weld l "\0a")))
    (pure:m [out (crip "{(a-co:co n)} hits")])
  ;<  fv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /docs `@ta`path.i.items]) `[/ %mime])
  =/  txt=@t
    ?.  ?=([%file *] fv)  ''
    `@t`q.q:!<(mime (need-vase:tarball sang.fv))
  =/  snip=(unit @t)  (find-snippet txt q)
  =/  tmatch=?  !=(~ (find qlow (cass (trip title.i.items))))
  ?.  |(?=(^ snip) tmatch)  $(items t.items)
  =/  line=tape
    "{(trip path.i.items)} — {(trip title.i.items)}: {?~(snip "" (trip u.snip))}"
  $(items t.items, hits [line hits])
::  tool-read-doc: read one /docs grub in full as markdown.
++  tool-read-doc
  |=  [rail=rail:tarball p=@t]
  =/  m  (fiber:fiber:nexus ,[@t @t])
  ^-  form:m
  ?:  =('' p)  (pure:m ['(no path given)' 'error'])
  ;<  fv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /docs `@ta`p]) `[/ %mime])
  ?.  ?=([%file *] fv)
    (pure:m [(crip "no doc at {(trip p)}") 'not found'])
  =/  txt=@t  `@t`q.q:!<(mime (need-vase:tarball sang.fv))
  (pure:m [txt (crip "{(a-co:co (met 3 txt))} bytes")])
::  await-call: loop on news for our call grub until status is done,
::  then yield the raw provider response json.
++  await-call
  |=  call-road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  |-
  ;<  ~  bind:m  (take-news /chat-call)
  ;<  =view:nexus  bind:m  (peek:io call-road ~)
  ?.  ?=([%file *] view)  $
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%o -.jon)  $
  ?.  ?=([~ %s %'done'] (~(get by p.jon) 'status'))  $
  (pure:m (fall (~(get by p.jon) 'response') [%o ~]))
::  take-news: wait for a news wave on `wire`, ignore everything else.
++  take-news
  |=  =wire
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~              [%wait ~]
    [~ %news * *]  ?:(=(wire wire.u.in) [%done ~] [%skip ~])
  ==
::  extract-text: concatenate the text blocks of an Anthropic Messages
::  response; surface proxy/API errors as plain text.
++  extract-text
  |=  resp=json
  ^-  @t
  ?.  ?=([%o *] resp)  'no response'
  =/  err=(unit json)  (~(get by p.resp) 'error')
  ?^  err
    ?:  ?=(%s -.u.err)  p.u.err
    (crip "API error: {(trip (en:json:html u.err))}")
  =/  content=(unit json)  (~(get by p.resp) 'content')
  ?.  ?=([~ %a *] content)  'no content in response'
  %-  crip
  %-  zing
  %+  turn  p.u.content
  |=  b=json
  ^-  tape
  ?.  ?=([%o *] b)  ""
  ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
  =/  t=(unit json)  (~(get by p.b) 'text')
  ?:(?=([~ %s *] t) (trip p.u.t) "")
::  Stub handbook content — deliberately thin. Flesh these out live at
::  /apps/grubbery/docs; edits persist (grubs), the seeds never overwrite.
++  intro-md
  '''
  # The Grubbery Handbook

  Grubbery is a general-purpose application model for Urbit. A stock Gall app
  is one agent holding one big state noun, migrated by hand every time that
  shape changes. Grubbery takes the opposite bet: an application is a set of
  small **nexuses** composing over a shared **namespace** of content-addressed
  **grubs**, and all their work runs as restartable **fibers**. State doesn't
  live in an agent heap — it lives in the namespace, versioned and portable,
  and code reads it back on demand.

  Three nouns carry the whole model:

  - **Nexus** — the unit of an application. Declares what lives in its slice
    of the namespace, and answers requests against it.
  - **Grub** — the unit of state. One content-addressed file carrying a mark
    (its type).
  - **Fiber** — the unit of work. A monadic process that reads and writes the
    namespace and can be rebooted at any point.

  ## Why bother

  The payoff is how it scales. A monolithic agent gets *harder* to extend the
  bigger it grows — every feature entangles with one state and one event
  handler. Nexuses compose instead of entangle, so the next feature reuses
  primitives rather than thickening a core. And because state *is* the
  namespace, the two worst Gall taxes — hand-written migrations and cross-ship
  auth boilerplate — mostly evaporate.

  ## Where to start

  - [Nexuses](#nexuses.md) — the unit of an application
  - [Grubs & the namespace](#grubs.md) — where state actually lives
  - [Fibers](#fibers.md) — how work gets done

  ## This handbook is live

  > These pages are markdown grubs served by the shell nexus, and they quote
  > source **straight from the running ship** — no copy-paste, so a snippet
  > can't drift from the code it describes.

  Here is a whole nexus helper lib, read live from the namespace through the
  kernel's own file API and highlighted in place:

  ```live
  /lib/shell.hoon
  ```
  '''
++  nexuses-md
  '''
  # Nexuses

  A nexus is the grubbery unit of an application — a core with two arms:

  - **`on-load`** declares what persistently lives in the nexus's subtree of
    the namespace: the grubs it owns and their initial state.
  - **`on-file`** answers "given this file — a request, a timer, a
    subscription update — do the work." HTTP handlers and fibers live here.

  ## on-load: declaring your state

  `on-load` returns a *bole* built by `spin:loader` over a list of loader
  operations. The two you'll reach for constantly:

  - **`%fall`** seeds a grub *only if absent* — the runtime owns it after, and
    reloads never clobber it. For state edited at runtime.
  - **`%over`** *overwrites* on every load — the code is the source of truth.
    For assets and content authored in-source.

  ```hoon
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]      ::  a fiber entrypoint
      [%fall %| /cache empty-dir:loader]           ::  a rebuildable cache dir
      [%over %& [/ %'app.js'] [[/ %mime] app-js]]  ::  a served asset
  ==
  ```

  Getting these backwards is the classic footgun: seed content with `%fall`
  and it freezes at first boot; author it with `%over` and every commit
  redeploys it. It's the same record-vs-cache distinction as
  [Grubs](#grubs.md).

  ## on-file: doing the work

  Requests route in as the file that represents them. A nexus binds an HTTP
  path and hands off to a fiber:

  ```hoon
  [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "failed")
    ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
    (http-dispatch:io %shell)
  ```

  The kernel routes matching requests here and spawns a fiber per request.

  ## Reading anything, live

  A nexus can read any file in the running namespace. Here's how a tool greps
  the whole ball — the same read primitive the live-code embeds use:

  ```live
  /lib/mcp/grep.hoon 53-64
  ```

  _TODO: registration via a `%fall` row in `root.hoon`; the full loader
  vocabulary; declaring weirs._
  '''
++  grubs-md
  '''
  # Grubs & the namespace

  A **grub** is one file in the namespace: a path, a name, and a **blot** —
  its content plus a **mark** (its type). Marks are what let the system
  convert a grub on the way out — the kernel's file API serves a `.hoon` grub
  as text by running its mark's `mime` tube.

  The **namespace** is the shared tree of every nexus's grubs. It's
  content-addressed, so identical content is stored once and dedup'd across
  the whole system. Crucially it *is* the state — there is no separate agent
  heap to migrate when a type changes.

  ## Two tiers: record vs cache

  Not all state is equal, and grubbery keeps a hard line between:

  - **System of record** — authoritative state, the truth. Lose it and you
    lose data.
  - **Cache** — derived, rebuildable state. Lose it and you recompute it.

  The convention is to keep them in *separate sibling grubs* so the tiers are
  legible at a glance. The shell nexus does exactly this: consent records live
  under `/permit`, rebuildable views under `/cache`. That split is a design
  rule, not a suggestion — it's how you know, staring at an `on-load`, what's
  precious and what's disposable.

  ## %fall vs %over encode lifecycle

  The two loader verbs aren't just "seed" and "write" — they declare who owns
  a grub:

  - **`%fall`** = "owned at runtime; seed once." Record tier, or anything a
    user or editor mutates.
  - **`%over`** = "defined in code; overwrite." Assets, and content with no
    runtime editor yet.

  ## Reading a grub

  From inside a fiber you `peek` a grub by its road, optionally casting to a
  mark:

  ```hoon
  ;<  jon=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /cache %'weirs.json']) ,json)
  ```

  A `~` back means "nothing there" — a clean miss the reader handles, not an
  error.

  _TODO: content-addressing internals; the blot type in depth; marks and
  tubes; cross-nexus and cross-ship peeks._
  '''
++  fibers-md
  '''
  # Fibers

  A **fiber** is grubbery's unit of work: a monadic process that reads and
  writes the namespace, binds HTTP, peeks other nexuses, waits on timers —
  and, the whole point, **restarts cleanly from state** at any moment.

  ## The monad

  Open a fiber by naming its result type, sequence effects with `;< … bind:m`,
  finish with `pure:m`:

  ```hoon
  =/  m  (fiber:fiber:nexus ,~)
  ;<  now=@da         bind:m  get-time:io
  ;<  ~               bind:m  (bind-http:io [~ /apps/grubbery])
  ;<  wv=(unit json)  bind:m  (peek-as:io road ,json)
  (pure:m ~)
  ```

  Each `;<` line is one step: run the effect on the right, bind its result on
  the left, continue. Reads, writes, time, HTTP — everything sequences the
  same way, and the main arm reads top-to-bottom as the action it performs.

  ## Roads and weirs

  A **road** names a location in the namespace —
  `(nex-road:io rail [%& /dir %'file'])` addresses a grub relative to the
  nexus. A **weir** is a *capability*: the set of reaches a nexus declares it
  may make. Reaching outside your declared weir is refused — that's how
  cross-nexus and cross-ship reads stay safe without per-call auth checks.

  > An empty weir `{}` means "declared, with no holes"; an *absent* weir `~`
  > means "no filter at all." That's a real, intentional distinction — not a
  > typo to paper over.

  ## The restart contract

  The load-bearing invariant: **reboot at any time, recover from state.** A
  fiber isn't a long-lived thread you must keep alive — it's derived from the
  namespace, so the runtime can restart it whenever and it resumes from where
  the state says. This is why grubbery treats restarts as ordinary rather than
  hazardous, and why a loud crash is a *bug report*, not corruption to hide.

  _TODO: timeouts and `%timer-rest`; `poke` / `poke-soft`; the fiber
  code-style conventions (one-line binds, helpers in a bottom core)._
  '''
++  roadmap-md
  '''
  # TODO & future topics

  The doc backlog. Check things off as pages land; add topics freely.

  ## Core model (the fundamentals)

  - [ ] Nexuses: `on-load` vs `on-file`, the request/fiber lifecycle
  - [ ] The loader vocabulary: `%fall` vs `%over`, `manifest`, `spin`
  - [ ] Grubs, marks, and content-addressing
  - [ ] System-of-record vs rebuildable-cache tiers (sibling grubs)
  - [ ] Fibers: the `bind:m` monad, shadowing `m`, helper cores
  - [ ] Roads: `nex-road`, `peek`/`peek-as`, cross-nexus reads
  - [ ] Reboot-anytime + recover-from-state: the core contract

  ## Cross-ship

  - [ ] Weirs: capability-scoped reaches, empty `{}` vs absent `~`
  - [ ] Cross-ship peeks, veto/tomb, the snap protocol
  - [ ] Discovery: usergroups, grants, the /sys/link registry

  ## Building real things

  - [ ] Serving HTTP: binding, static shell + data endpoints
  - [ ] The permission system: sources vs views, consent, enforcement
  - [ ] Desks: install, sync, follower model, publishing
  - [ ] Dynamic tools: `write_code`, `check_bin`, the MCP surface

  ## Why grubbery (the pitch)

  - [ ] A program vs a substrate: composition beats entanglement
  - [ ] Migrating a Gall agent: the strangler-fig pattern (see lattice)
  - [ ] The overlay pattern: keep source in your own repo, sync into gub

  ## Meta

  - [ ] The in-browser editor (`<code-editor>` + save)
  - [ ] A worked example, end to end
  '''
::
::  === tutorials ===
::
++  hello-nexus-md
  '''
  # Your first nexus

  *How to build a minimal nexus from scratch — on-load, on-file, and the fiber lifecycle.*

  (Coming soon)
  '''
++  serving-a-page-md
  '''
  # Serving a web page

  *Bind an HTTP route, serve static assets, and build a simple UI on grubbery primitives.*

  (Coming soon)
  '''
++  talking-to-apis-md
  '''
  # Talking to external APIs

  *Use iris to call HTTP APIs, parse JSON responses, and persist results as grubs.*

  (Coming soon)
  '''
::
::  === principles ===
::
++  namespace-first-md
  '''
  # Namespace-first

  *Authoritative state lives in the namespace. Derived and rebuildable caches go in sibling grubs. Write-cost never justifies moving truth out.*

  (Coming soon)
  '''
++  reboot-anytime-md
  '''
  # Reboot-anytime

  *The core contract: reboot at any point, recover from persisted state. Restarts are not hazards — they are the normal case.*

  (Coming soon)
  '''
++  composition-md
  '''
  # Composition over entanglement

  *A program vs a substrate. Nexuses compose through the namespace, not through shared mutable state. The strangler-fig pattern for migrating Gall agents.*

  (Coming soon)
  '''
::
::  === subsystems ===
::
++  permissions-md
  '''
  # Permissions

  *Sources vs views, grant.json, consent flows, the active/denied/missing/unmanaged overlay.*

  (Coming soon)
  '''
++  desks-md
  '''
  # Desks

  *Install, sync, the follower model, publishing from a git repo to a desk.*

  (Coming soon)
  '''
++  cross-ship-md
  '''
  # Cross-ship

  *Weirs, capability-scoped reaches, cross-ship peeks, veto/tomb, the snap protocol.*

  (Coming soon)
  '''
++  http-serving-md
  '''
  # HTTP serving

  *Binding routes, web.sig, static shell + data endpoints, the serve pattern, content-types.*

  (Coming soon)
  '''
++  code-nexuses-md
  '''
  # Code nexuses

  *Scoped code builds, find-code resolution, check_bin, dynamic tools.*

  (Coming soon)
  '''
::  === repos-to-sync bootstrap (shell-owned git_repo + desk setup) ===
::  default-repos: the shipped list of libraries this ship follows by
::  default. Each becomes a git_repo (polling github) + a desk following
::  the repo's checked-out tree. Add entries here to bootstrap more.
::
::  a stock entry is either a github repo (shell provisions a git_repo that
::  polls it, then a desk following the checkout) or a direct /code path (just
::  a desk following that namespace dir, like a plain /desk).
+$  stock-entry
  $%  [%github name=@t repo=@t ref=@t]
      [%code name=@t code=@t]
  ==
++  default-repos
  ^-  (list stock-entry)
  :~  [%github 'contacts' 'niblyx-malnus/contacts-nexus' 'main']
      [%github 'wallet' 'niblyx-malnus/wallet-nexus' 'main']
  ==
::  stock-name / stock-code: pull the name (and, for %code, the code path)
::  out of an entry regardless of kind.
++  stock-name  |=(e=stock-entry ?-(-.e %github name.e, %code name.e))
::  repo-config: the config.json a git_repo instance is seeded with.
::
++  repo-config
  |=  [repo=@t ref=@t]
  ^-  json
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['ref' s+ref]
      ['token' s+'']
      ['poll' n+'15']
  ==
::  ensure-pairing: idempotently stand up ONE git_repo + desk pairing.
::  Guarded makes (skip what exists) + a replace-in-place source poke, so
::  re-running is safe. The desk follows the repo's /data/tree/code and
::  the stock desk machinery owns the rest (version watch, sync, bill).
::
++  ensure-pairing
  |=  entry=stock-entry
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@t  (stock-name entry)
  =/  desk-dir=path  /apps/[(cat 3 `@ta`name '.desk')]
  ::  the /code path the desk will follow
  =/  code=@t
    ?-  -.entry
      %code    code.entry
      %github  (crip "/apps/forge.git_forge/repos/{(trip name)}.git_repo/data/tree/code")
    ==
  ::  1. a %github entry provisions its source: ensure the git_repo (polls
  ::  github) and force a fresh pull. A %code entry follows a namespace dir
  ::  directly — no repo to make.
  ;<  ~  bind:m
    ?.  ?=(%github -.entry)  (pure:m ~)
    =/  repo-dir=path  /apps/'forge.git_forge'/repos/[(cat 3 `@ta`name '.git_repo')]
    ;<  has-repo=?  bind:m  (peek-exists:io [%& %| repo-dir])
    ;<  ~  bind:m
      ?:  has-repo  (pure:m ~)
      ;<  ~  bind:m  (make:io [%& %| repo-dir] &+`bole:tarball`[`[`[/git %repo] ~ %.n ~] ~])
      (poke:io [%& %& repo-dir %'config.json'] [[/ %json] (repo-config repo.entry ref.entry)])
    ::  a new repo boot-syncs on its own; poking sync.sig forces an existing
    ::  one to re-fetch now, so "sync" always means "pull latest".
    (poke:io [%& %& (weld repo-dir /actions) %'sync.sig'] [[/ %sig] ~])
  ::  2. ensure the desk
  ;<  has-desk=?  bind:m  (peek-exists:io [%& %| desk-dir])
  ;<  ~  bind:m
    ?:  has-desk  (pure:m ~)
    (make:io [%& %| desk-dir] &+`bole:tarball`[`[`[/ %desk] ~ %.n ~] ~])
  ::  3. always wire the desk's source at the computed code path
  (poke:io [%& %& desk-dir %'source.json'] [[/ %json] (pairs:enjs:format ~[['code' s+code]])])
::  sync-defaults: run ensure-pairing over the whole default-repos list.
::
++  sync-defaults
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  todo=(list stock-entry)  default-repos
  |-  ^-  form:m
  ?~  todo  (pure:m ~)
  ;<  ~  bind:m  (ensure-pairing i.todo)
  $(todo t.todo)
::  stock-status: the default-repos list as json, each with a `synced` flag
::  (its desk exists and its source is wired). Feeds the Stock tab.
::
++  stock-status
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  todo=(list stock-entry)  default-repos
  =|  acc=(list json)
  |-  ^-  form:m
  ?~  todo  (pure:m a+(flop acc))
  =/  name=@t  (stock-name i.todo)
  =/  desk-dir=path  /apps/[(cat 3 `@ta`name '.desk')]
  ;<  has-desk=?  bind:m  (peek-exists:io [%& %| desk-dir])
  ;<  src=(unit json)  bind:m
    ?.  has-desk  (pure:(fiber:fiber:nexus ,(unit json)) ~)
    (peek-as:io [%& %& desk-dir %'source.json'] ,json)
  =/  synced=?
    ?&  has-desk
        ?=(^ src)
        ?=([%o *] u.src)
        ?=([~ %s *] (~(get by p.u.src) 'code'))
    ==
  =/  fields=(list [@t json])
    ?-  -.i.todo
        %github
      :~  ['name' s+name]  ['kind' s+'github']
          ['repo' s+repo.i.todo]  ['ref' s+ref.i.todo]  ['synced' b+synced]
      ==
        %code
      :~  ['name' s+name]  ['kind' s+'code']
          ['code' s+code.i.todo]  ['synced' b+synced]
      ==
    ==
  $(todo t.todo, acc [(pairs:enjs:format fields) acc])
::  === peer-desk storefront (folded in from the retired /desks nexus) ===
::  +gather-peers: every mirrored peer directory, each published desk
::  enriched with tile metadata, icon, and version read through the peer's
::  public grants. This is the "add apps" browser's backend.
::
++  gather-peers
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io [%& %| /apps/'shell.shell'/peers] ~)
  ?.  ?=([%ball *] view)  (pure:m a+~)
  ?~  fil.ball.view  (pure:m a+~)
  =/  entries=(list [n=@ta =sang:tarball gain=? bang=(unit tang)])
    ~(tap by contents.u.fil.ball.view)
  ;<  srcs=(map @t @t)  bind:m  installed-sources
  ;<  out=(list json)  bind:m  (peer-groups entries srcs)
  (pure:m a+out)
::  +installed-sources: source string -> local desk dir name for every
::  configured local desk, for marking peer listings already installed.
::
++  installed-sources
  =/  m  (fiber:fiber:nexus ,(map @t @t))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek-shallow:io [%& %| /apps] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  kids=(list @ta)  ~(tap in ~(key by dir.ball.view))
  =|  acc=(map @t @t)
  |-
  ?~  kids  (pure:m acc)
  ::  a local desk's source.json.code is the peer road it follows — the same
  ::  key a peer card carries, so a mirrored desk shows as already installed.
  ;<  src=(unit json)  bind:m
    (peek-as:io [%& %& /apps/[i.kids] %'source.json'] ,json)
  ?~  src  $(kids t.kids)
  =/  code=@t  (jstr u.src 'code')
  ?:  =('' code)  $(kids t.kids)
  $(kids t.kids, acc (~(put by acc) code `@t`i.kids))
::
++  peer-groups
  |=  [entries=(list [n=@ta =sang:tarball gain=? bang=(unit tang)]) srcs=(map @t @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  entries  (pure:m ~)
  ;<  one=json  bind:m  (peer-group i.entries srcs)
  ;<  rest=(list json)  bind:m  $(entries t.entries)
  (pure:m [one rest])
::
++  peer-group
  |=  [[n=@ta =sang:tarball gain=? bang=(unit tang)] srcs=(map @t @t)]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  t=tape  (trip n)
  =/  s=@t  (crip (scag (sub (lent t) 5) t))
  ::  the mirror holds the peer's /share/public/desks.json — an array of
  ::  desk cards {name, dir, code}, each a desk we may install.
  =/  entries=(list json)
    ?:  (is-boom:tarball sang)  ~
    =/  r=(each json tang)
      (mule |.(!<(json (need-vase:tarball sang))))
    ?:  ?=(%| -.r)  ~
    ?.  ?=(%a -.p.r)  ~
    p.p.r
  ;<  apps=(list json)  bind:m  (peer-apps s entries srcs)
  (pure:m (pairs:enjs:format ~[['ship' s+s] ['apps' a+apps]]))
::
++  peer-apps
  |=  [s=@t entries=(list json) srcs=(map @t @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  entries  (pure:m ~)
  ;<  one=json  bind:m  (peer-app s i.entries srcs)
  ;<  rest=(list json)  bind:m  $(entries t.entries)
  (pure:m [one rest])
::  +peer-app: one published desk as a card — tile metadata and icon from
::  a shallow peek of its code tree, version from canonical file names.
::
++  peer-app
  |=  [s=@t entry=json srcs=(map @t @t)]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  dir=@t    (jstr entry 'dir')       :: the desk's dir name on the peer
  =/  ename=@t  (jstr entry 'name')      :: display name (already slugged)
  =/  codep=@t  (jstr entry 'code')      :: "/apps/<dir>/desk/code"
  ?:  =('' dir)  (pure:m entry)          :: malformed card — pass through
  =/  base=path  (weld /sys/ames/ships/[s]/root /apps/[`@ta`dir])
  ;<  cv=view:nexus  bind:m
    (peek-shallow:io [%& %| (weld base /desk/code)] ~)
  =/  [title=@t info=@t color=@t icon=(unit @ta)]
    ?.  ?=([%ball *] cv)  [ename '' '' ~]
    ?~  fil.ball.cv  [ename '' '' ~]
    =/  cs  contents.u.fil.ball.cv
    =/  tj=json
      =/  tf  (~(get by cs) %'tile.json')
      ?~  tf  [%o ~]
      ?:  (is-boom:tarball sang.u.tf)  [%o ~]
      =/  r=(each json tang)
        (mule |.(!<(json (need-vase:tarball sang.u.tf))))
      ?:(?=(%| -.r) [%o ~] p.r)
    =/  ic=(unit @ta)
      =/  ks=(list @ta)  ~(tap in ~(key by cs))
      |-  ^-  (unit @ta)
      ?~  ks  ~
      ?:  =('icon.' (end [3 5] i.ks))  `i.ks
      $(ks t.ks)
    :^    ?:(=('' (jstr tj 'title')) ename (jstr tj 'title'))
        (jstr tj 'info')
      (jstr tj 'color')
    ic
  ;<  ver=(unit @t)  bind:m  (try-version base)
  =/  icon-url=json
    ?~  icon  ~
    s+(crip "/grubbery/ball{(spud (weld base /desk/code))}/{(trip u.icon)}?raw=1")
  ::  the peer-prefixed code road, which /desks/add writes into the new
  ::  desk's source.json. `source` doubles as the installed-check key
  ::  (matches installed-sources' source.json.code).
  =/  code-src=@t  (cat 3 s codep)
  %-  pure:m
  %-  pairs:enjs:format
  :~  ['path' s+(cat 3 '/apps/' dir)]
      ['name' s+ename]
      ['title' s+title]
      ['info' s+info]
      ['color' s+color]
      ['version' ?~(ver ~ s+u.ver)]
      ['icon' icon-url]
      ['ship' s+s]
      ['code' s+code-src]
      ['source' s+code-src]
      ['installed' b+(~(has by srcs) code-src)]
      ['local' ?~((~(get by srcs) code-src) ~ s+(need (~(get by srcs) code-src)))]
  ==
::  +try-version: a remote desk's version through canonical file names,
::  since its root is not listable.
::
++  try-version
  |=  base=path
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  names=(list @ta)  ~[%'version.txt' %'version.ud' %'version.json']
  |-  ^-  form:m
  ?~  names  (pure:m ~)
  ;<  vv=view:nexus  bind:m  (peek:io [%& %& base i.names] ~)
  ?.  ?=([%file *] vv)  $(names t.names)
  ?:  (is-boom:tarball sang.vv)  $(names t.names)
  =/  nun  (sang-noun:tarball sang.vv)
  ?+    p.sang.vv  $(names t.names)
      [~ %ud]
    =/  x  ((soft @ud) nun)
    ?~  x  $(names t.names)
    (pure:m `(crip (a-co:co u.x)))
      [~ %txt]
    =/  w  ((soft wain) nun)
    ?~  w  $(names t.names)
    ?~  u.w  $(names t.names)
    (pure:m `i.u.w)
  ==
::  +jstr: a string field from a json object, '' if absent.
::
++  jstr
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v  (~(get by p.jon) k)
  ?.(?=([~ %s *] v) '' p.u.v)
::  +discover-desks: every local /apps/<x>.desk with its source and a link
::  to its own page — the shell's desk launcher (config/publish live there).
::
++  discover-desks
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| /apps] ~)
  ?.  ?=([%ball *] view)  (pure:m a+~)
  =/  apps=(list @ta)  ~(tap in ~(key by dir.ball.view))
  ;<  cards=(list json)  bind:m  (gather-desks apps)
  (pure:m a+cards)
::
++  gather-desks
  |=  apps=(list @ta)
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  apps  (pure:m ~)
  ;<  one=(unit json)  bind:m  (desk-card i.apps)
  ;<  rest=(list json)  bind:m  $(apps t.apps)
  (pure:m ?~(one rest [u.one rest]))
::
++  desk-card
  |=  app=@ta
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ?.  =('desk' (desk-suffix app))  (pure:m ~)
  ;<  sj=(unit json)  bind:m
    (peek-as:io [%& %& /apps/[app] %'source.json'] ,json)
  =/  code=@t  ?~(sj '' (jstr u.sj 'code'))
  ::  publishing + source editing live in the desk's OWN page now; this list
  ::  is just navigation, so it carries name, source, and a link to the page.
  %-  pure:m  :-  ~
  %-  pairs:enjs:format
  :~  ['name' s+app]
      ['source' ?:(=('' code) ~ s+code)]
      ['url' s+(cat 3 '/grubbery/desk/' (app-slug app))]
  ==
::  +desk-suffix: the extension after the last dot ('foo.desk' -> 'desk').
::
++  desk-suffix
  |=  app=@ta
  ^-  @t
  =/  t=tape  (trip app)
  =/  idx=(unit @ud)  (find "." (flop t))
  ?~  idx  ''
  (crip (slag (sub (lent t) u.idx) t))
::  the home favicon: the launcher grid itself
::
++  shell-icon
  ^-  @t
  '''
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
    <rect width="64" height="64" rx="14" fill="#7a5ac0"/>
    <rect x="12" y="12" width="17" height="17" rx="5" fill="#fff"/>
    <rect x="35" y="12" width="17" height="17" rx="5" fill="#fff"/>
    <rect x="12" y="35" width="17" height="17" rx="5" fill="#fff"/>
    <rect x="35" y="35" width="17" height="17" rx="5" fill="#ede7fa" opacity="0.75"/>
  </svg>
  '''
::  +scan-public: derive the public desk directory from the /public
::  group's grants. A desk shared to /public grants peeks on its root
::  version.* files; the directories those grants sit in ARE the
::  public desks.
::
++  scan-public
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io [%& %& /sys/ames/usergroups/'public.grp' %'how.weir'] `[/ %weir])
  ?.  ?=([%file *] view)  (pure:m ~)
  ?:  (is-boom:tarball sang.view)  (pure:m ~)
  =/  =weir:tarball  !<(weir:tarball (need-vase:tarball sang.view))
  =/  dirs=(set path)
    %+  roll  ~(tap in peek.weir)
    |=  [r=road:tarball acc=(set path)]
    ?.  ?=([%& %& *] r)  acc
    ?.  =('version.' (end [3 8] name.p.p.r))  acc
    (~(put in acc) path.p.p.r)
  %-  pure:m
  (sort (turn ~(tap in dirs) |=(p=path (crip (spud p)))) aor)
::  peer directory mirroring
::
++  peer-file  |=(s=@t `@ta`(cat 3 s '.json'))
::
::  +mirror-ship: a mirror grub's ship, from its file name
::
++  mirror-ship
  |=  n=@ta
  ^-  @t
  =/  t=tape  (trip n)
  ?:  (lth (lent t) 5)  n
  (crip (scag (sub (lent t) 5) t))
::
++  peer-pub-road
  |=  s=@t
  ^-  road:tarball
  [%& %& /sys/ames/ships/[s]/root/apps/'shell.shell'/share/public %'desks.json']
::
++  jget
  |=  [j=json k=@t]
  ^-  (unit @t)
  ?.  ?=(%o -.j)  ~
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) ~ `p.u.v)
::  +suppress-alias: hide an app-declared option (alias name + path) from
::  the directory. App options are derived from alias.json, so they can't
::  be deleted outright — this records a suppression the menu builder
::  filters out, so the option stops being offered. Operates on the
::  permit/hidden map: alias name -> [suppressed path strings].
::
++  suppress-alias
  |=  [hidden=json alias=@t path=@t]
  ^-  json
  =/  supp=(map @t json)  ?.(?=(%o -.hidden) ~ p.hidden)
  =/  cur=(list json)
    =/  e  (~(get by supp) alias)
    ?.(?=([~ %a *] e) ~ p.u.e)
  =/  has=?  (lien cur |=(j=json &(?=(%s -.j) =(path p.j))))
  =/  next=(list json)  ?:(has cur (snoc cur s+path))
  [%o (~(put by supp) alias [%a next])]
::  +unsuppress-alias: un-hide a previously suppressed app-declared option.
::
++  unsuppress-alias
  |=  [hidden=json alias=@t path=@t]
  ^-  json
  =/  supp=(map @t json)  ?.(?=(%o -.hidden) ~ p.hidden)
  =/  cur=(list json)
    =/  e  (~(get by supp) alias)
    ?.(?=([~ %a *] e) ~ p.u.e)
  =/  next=(list json)  (skip cur |=(j=json &(?=(%s -.j) =(path p.j))))
  [%o (~(put by supp) alias [%a next])]
::  +read-hidden: the permit/hidden grub (suppressed alias options), or an
::  empty map if absent.
::
++  read-hidden
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  hv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'hidden.json']) ,json)
  (pure:m (fall hv [%o ~]))
::  +do-suppress: read permit/hidden, hide (suppress=%.y) or un-hide an
::  app-declared option, and write it back.
::
++  do-suppress
  |=  [rail=rail:tarball alias=@t path=@t suppress=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  hidden=json  bind:m  (read-hidden rail)
  =/  next=json
    ?:  suppress  (suppress-alias hidden alias path)
    (unsuppress-alias hidden alias path)
  ;<  ~  bind:m  (put:io (nex-road:io rail [%& /permit %'hidden.json']) [[/ %json] next])
  (build-asks rail)
::  +read-shares: permit/share.json inverted for granting — usergroup
::  path -> set of /sys/link roads it may peek. 'public' maps to /public.
::
++  read-shares
  |=  [rail=rail:tarball nex-dir=path]
  =/  m  (fiber:fiber:nexus ,(map path (set road:tarball)))
  ^-  form:m
  ;<  sv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'share.json']) ,json)
  =/  jon=json  (fall sv [%o ~])
  ?.  ?=(%o -.jon)  (pure:m ~)
  =|  out=(map path (set road:tarball))
  =/  entries=(list [al=@t v=json])  ~(tap by p.jon)
  |-  ^-  form:m
  ?~  entries  (pure:m out)
  =/  road=road:tarball  (link-road al.i.entries)
  =/  grps=(list path)
    ?:  ?=([%s *] v.i.entries)
      ?:  =('public' p.v.i.entries)  ~[/public]
      (drop (soft-path p.v.i.entries))
    ?.  ?=([%a *] v.i.entries)  ~
    %+  murn  p.v.i.entries
    |=(g=json ?.(?=([%s *] g) ~ (soft-path p.g)))
  =/  o=(map path (set road:tarball))
    %+  roll  grps
    |=  [g=path acc=_out]
    (~(put by acc) g (~(put in (fall (~(get by acc) g) ~)) road))
  $(entries t.entries, out o)
::  +read-approved: the permit/approved grub — the map of app path -> its
::  consented manifest. The system of record for present grant state.
::
++  read-approved
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t json))
  ^-  form:m
  ;<  av=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'approved.json']) ,json)
  (pure:m ?~(av ~ ?.(?=(%o -.u.av) ~ p.u.av)))
::  +read-notified: the permit/notified grub — app path -> the pending ask
::  we last surfaced a banner for. The "already told you" record.
::
++  read-notified
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t json))
  ^-  form:m
  ;<  nv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'notified.json']) ,json)
  (pure:m ?~(nv ~ ?.(?=(%o -.u.nv) ~ p.u.nv)))
::  +mark-notified: record that we have surfaced THIS ask for an app, so an
::  unchanged pending ask does not re-notify on the next reload.
::
++  mark-notified
  |=  [rail=rail:tarball app=@t ask=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(map @t json)  bind:m  (read-notified rail)
  %+  put:io  (nex-road:io rail [%& /permit %'notified.json'])
  [[/ %json] [%o (~(put by cur) app ask)]]
::  +notify-target: poke road to the notifications nexus's main.sig.
::
++  notify-target
  ^-  road:tarball
  [%& %& [/apps/'notifications.notifications' %'main.sig']]
::  +register-notify: register the shell with the notifications nexus so
::  its notify pokes are accepted (senders must be registered). Poke-soft
::  so a failed registration is logged, not fatal — re-run on every rise.
::
++  register-notify
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  payload=json
    (pairs:enjs:format ~[['action' s+'register'] ['name' s+'permissions']])
  ;<  *  bind:m  (poke-soft:io notify-target [[/ %json] payload])
  (pure:m ~)
::  +is-settled: has this exact declared ask already been ruled on? True iff
::  permit/approved holds a record for the app whose `declared` roads match
::  the current ask (order-insensitive). Settled asks never notify.
::
::  +asks-match: do two ask-shaped jsons declare the same poke/peek/make
::  roads (order-insensitive)? The shared identity test for both "already
::  ruled on" (is-settled) and "already surfaced" (is-notified).
::
++  asks-match
  |=  [a=json b=json]
  ^-  ?
  =/  same=$-([(list @t) (list @t)] ?)
    |=([x=(list @t) y=(list @t)] =((sort x aor) (sort y aor)))
  ?&  (same (road-strs a 'poke') (road-strs b 'poke'))
      (same (road-strs a 'peek') (road-strs b 'peek'))
      (same (road-strs a 'make') (road-strs b 'make'))
  ==
::
++  is-settled
  |=  [ask=json approved=(map @t json)]
  ^-  ?
  =/  app=@t  (fall (jget ask 'app') '')
  =/  ap=(unit json)  (~(get by approved) app)
  ?~  ap  %.n
  ?.  ?=(%o -.u.ap)  %.n
  =/  dec=json  (fall (~(get by p.u.ap) 'declared') [%o ~])
  (asks-match ask dec)
::  +is-notified: have we already surfaced a banner for THIS exact ask? A
::  changed ask (new roads) fails the match and notifies afresh.
::
++  is-notified
  |=  [ask=json notified=(map @t json)]
  ^-  ?
  =/  app=@t  (fall (jget ask 'app') '')
  =/  rec=(unit json)  (~(get by notified) app)
  ?~  rec  %.n
  ?.  ?=(%o -.u.rec)  %.n
  (asks-match ask u.rec)
::  +notify-app: ping the notifications nexus about one app's pending ask.
::  Uses poke-soft so a failed ping returns an error instead of crashing the
::  scan loop; returns whether it delivered, so the caller retries if not.
::
++  notify-app
  |=  [rail=rail:tarball app=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  pax=path  (fall (soft-path app) /unknown)
  ::  desk-nested apps keep their nested identity in the title:
  ::  /apps/<desk>/desk/data/<app> -> "<desk>/<app>".
  =/  nm=@t
    ?:  ?=([%apps @ %desk %data @ ~] pax)
      (rap 3 (app-slug i.t.pax) '/' (app-slug i.t.t.t.t.pax) ~)
    (app-slug (rear pax))
  =/  meta=json
    %-  pairs:enjs:format
    :~  ['title' s+(cat 3 nm ' wants permissions')]
        ['body' s+'A new access request — tap to review and approve.']
        ['url' s+'/apps/grubbery/permits']
    ==
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['action' s+'notify']
        ['push' s+'true']
        ['metadata' meta]
    ==
  ;<  err=(unit tang)  bind:m  (poke-soft:io notify-target [[/ %json] payload])
  (pure:m =(~ err))
::  +apply-permit-action: dispatch a validated POST permission action to the
::  authoritative component grubs. The caller already gated on src==our, so
::  this is the authenticated user.
::
++  apply-permit-action
  |=  [rail=rail:tarball jon=json act=@t now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%o -.jon)  (pure:m ~)
  =/  app=@t    (fall (jget jon 'app') '')
  =/  alias=@t  (fall (jget jon 'alias') '')
  =/  path=@t   (fall (jget jon 'path') '')
  =/  picks=json    (fall (~(get by p.jon) 'picks') [%o ~])
  =/  granted=json  (fall (~(get by p.jon) 'granted') [%o ~])
  ?:  ?&(=('approve-weir' act) ?!(=('' app)))
    ;<  hidden=json  bind:m  (read-hidden rail)
    (do-approve-weir rail app picks granted hidden now)
  ?:  ?&(=('deny-weir' act) ?!(=('' app)))
    (do-deny-weir rail app now)
  ?:  =('alias-share' act)
    ?:  =('' alias)  (pure:m ~)
    ;<  sv=(unit json)  bind:m
      (peek-as:io (nex-road:io rail [%& /permit %'share.json']) ,json)
    =/  cur=json  (fall sv [%o ~])
    =/  mp=(map @t json)  ?.(?=(%o -.cur) ~ p.cur)
    =/  share=(unit json)  (~(get by p.jon) 'share')
    =/  nxt=(map @t json)
      ?~  share  (~(del by mp) alias)
      ?:  ?=(~ u.share)  (~(del by mp) alias)
      (~(put by mp) alias u.share)
    ::  writing share.json IS the nudge; grants re-apply on the news.
    (put:io (nex-road:io rail [%& /permit %'share.json']) [[/ %json] [%o nxt]])
  ?:  ?&  ?|(=('alias-suppress' act) =('alias-unsuppress' act))
          ?!(=('' alias))
          ?!(=('' path))
      ==
    (do-suppress rail alias path =('alias-suppress' act))
  (pure:m ~)
::  +parse-road: road text -> a road. trailing slash = directory, no
::  slash = file; leading ../ climbs out (one step each). Same as desks.
::
++  parse-road
  |=  s=@t
  ^-  (unit road:tarball)
  =/  tap=tape  (trip s)
  =|  ups=@ud
  |-  ^-  (unit road:tarball)
  ?:  &((gte (lent tap) 3) =("../" (scag 3 tap)))
    $(tap (slag 3 tap), ups +(ups))
  ?:  =(".." tap)  $(tap ~, ups +(ups))
  ?~  tap  ?:(=(0 ups) ~ `[%| ups %| /])
  ?:  =("/" tap)  `[%& %| /]
  =/  is-dir=?  =("/" (scag 1 (flop `tape`tap)))
  =/  core=tape  ?:(is-dir (flop (slag 1 (flop `tape`tap))) tap)
  =/  txt=@t  (crip ?:(=("/" (scag 1 core)) core ['/' core]))
  =/  res  (mule |.((stab txt)))
  ?:  ?=(%| -.res)  ~
  =/  pax=path  p.res
  ?:  is-dir
    ?:(=(0 ups) `[%& %| pax] `[%| ups %| pax])
  =/  fp=(list @ta)  (flop pax)
  ?~  fp  ~
  =/  =rail:tarball  [(flop t.fp) i.fp]
  ?:(=(0 ups) `[%& %& rail] `[%| ups %& rail])
::
::  +refresh-mirror: pull the peer's public.json into this mirror grub
::
++  refresh-mirror
  |=  s=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  pv=view:nexus  bind:m  (peek:io (peer-pub-road s) ~)
  ?.  ?=([%file *] pv)
    ~&  >>  [%shell-peer-unreachable s]
    (pure:m ~)
  ?:  (is-boom:tarball sang.pv)  (pure:m ~)
  =/  res=(each json tang)
    (mule |.(!<(json (need-vase:tarball sang.pv))))
  ?:  ?=(%| -.res)  (pure:m ~)
  (replace:io p.res)
::
+$  tile
  $:  name=@ta
      title=@t
      info=@t
      color=@t
      image=@t
      href=@t
  ==
::
::  each local tile is its own subdir /tiles/<name>/ holding tile.json
::  (and optionally icon.svg); the tile's name is the subdir name.
++  read-local-tiles
  =/  m  (fiber:fiber:nexus ,(list tile))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| /apps/'tiles.tiles'/tiles] ~)
  ?.  ?=([%ball *] view)
    (pure:m ~)
  =/  subdirs=(list [@ta ball:tarball])  ~(tap by dir.ball.view)
  =|  acc=(list tile)
  |-
  ?~  subdirs  (pure:m (flop acc))
  =/  name=@ta  -.i.subdirs
  ;<  tv=view:nexus  bind:m
    (peek:io [%& %& /apps/'tiles.tiles'/tiles/[name] %'tile.json'] `[/ %json])
  ?.  ?=([%file *] tv)
    $(subdirs t.subdirs)
  =/  til=(unit tile)  (json-to-tile name sang.tv)
  ?~  til  $(subdirs t.subdirs)
  $(subdirs t.subdirs, acc [u.til acc])
::
++  json-to-tile
  |=  [name=@ta =sang:tarball]
  ^-  (unit tile)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang))))
  ?~  jon  ~
  ?.  ?=(%o -.u.jon)  ~
  =/  m  p.u.jon
  :-  ~
  :*  name
      (fall (bind (~(get by m) 'title') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'info') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'color') |=(=json ?>(?=(%s -.json) p.json))) '#333')
      (fall (bind (~(get by m) 'image') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'href') |=(=json ?>(?=(%s -.json) p.json))) '')
  ==
::
++  read-app-tiles
  =/  m  (fiber:fiber:nexus ,(list [tile path]))
  ^-  form:m
  ;<  roots=(list path)  bind:m  app-roots
  =|  acc=(list [tile path])
  |-  ^-  form:m
  ?~  roots  (pure:m (flop acc))
  =/  root=path  i.roots
  =/  leaf=@ta  (rear root)
  ?:  =('tiles.tiles' leaf)
    $(roots t.roots)
  =/  slug=@ta  (app-slug leaf)
  ;<  kid-view=view:nexus  bind:m
    (peek:io [%& %& [root %'tile.json']] `[/ %json])
  ?.  ?=([%file *] kid-view)
    $(roots t.roots)
  =/  tile-name=@ta  (crip "{(trip slug)}.json")
  =/  made=(unit tile)  (json-to-tile tile-name sang.kid-view)
  ?~  made  $(roots t.roots)
  ::  an app that ships an icon file gets it as the tile image, addressed
  ::  by its full nexus-root path.
  ;<  kid-root=view:nexus  bind:m  (peek-shallow:io [%& %| root] ~)
  =/  icon=(unit @ta)
    ?.  ?=([%ball *] kid-root)  ~
    =/  =lump:tarball  (fall fil.ball.kid-root *lump:tarball)
    %-  ~(rep by contents.lump)
    |=  [[n=@ta s=sang:tarball g=? b=(unit tang)] out=(unit @ta)]
    ?^  out  out
    ?.  =("icon." (scag 5 (trip n)))  out
    ?:  (is-boom:tarball s)  out
    `n
  ::  compress the icon URL: /apps and /desk/data are always boilerplate,
  ::  so a desk nexus is <desk>/<nexus>, a plain one just <nexus>.
  =/  icon-segs=path
    ?:  ?=([%apps @ %desk %data @ ~] root)  ~[i.t.root i.t.t.t.t.root]
    ?:  ?=([%apps @ ~] root)  ~[i.t.root]
    root
  =/  til=tile
    ?~  icon  u.made
    u.made(image (crip "/grubbery/tiles/icon{(spud icon-segs)}"))
  $(roots t.roots, acc [[til root] acc])
::
++  app-slug
  |=  name=@ta
  ^-  @ta
  =/  nam=tape  (trip name)
  =/  dix=(unit @ud)  (find "." nam)
  ?~  dix  name
  (crip (scag u.dix nam))
::  +read-app-aliases: scan /apps for each app's self-declared alias.json
::  ({name, description}) and build the app-sourced half of the alias
::  directory: @name -> list of option json {path, description, source}.
::  Derived — rescanned on read, never stored. A name grants no power, so
::  declaring one needs no consent; it just appears as a menu option.
::
++  app-roots
  =/  m  (fiber:fiber:nexus ,(list path))
  ^-  form:m
  ;<  av=view:nexus  bind:m  (peek-shallow:io [%& %| /apps] ~)
  ?.  ?=([%ball *] av)  (pure:m ~)
  =/  kids=(list @ta)  ~(tap in ~(key by dir.ball.av))
  =|  out=(list path)
  |-  ^-  form:m
  ?~  kids  (pure:m (flop out))
  =/  kid=@ta  i.kids
  ::  a shallow listing STUBS its dir kids (neck=~ always), so the kid's
  ::  own neck must come from peeking the kid itself — its own lump
  ::  carries the real neck.
  ;<  kv=view:nexus  bind:m  (peek-shallow:io [%& %| /apps/[kid]] ~)
  =/  nek=(unit neck:tarball)
    ?.  ?=([%ball *] kv)  ~
    ?~(fil.ball.kv ~ neck.u.fil.ball.kv)
  ?.  =(`[/ %desk] nek)
    ::  a plain nexus is itself the governable app
    $(kids t.kids, out [/apps/[kid] out])
  ::  a [/ %desk] install is the sync wrapper — trusted local infra, not
  ::  the remote's code, so it is not itself a governable app. Its real
  ::  apps are the neck'd children of desk/data (same stub caveat: any
  ::  dir kid with a manifest is an instance; apply-bill only creates
  ::  nexus instances there).
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%& %| /apps/[kid]/desk/data] ~)
  =/  subs=(list path)
    ?.  ?=([%ball *] dv)  ~
    (turn ~(tap in ~(key by dir.ball.dv)) |=(sub=@ta /apps/[kid]/desk/data/[sub]))
  $(kids t.kids, out (weld subs out))
::  +read-app-aliases: scan every app root (descending desks) for its
::  alias.json, building @name -> menu options. Each root is a nexus; its
::  option path is the nexus root. `name` may be a string or a list of
::  strings — a nexus can advertise several synonyms, all pointing at it.
::
++  read-app-aliases
  =/  m  (fiber:fiber:nexus ,(map @t (list json)))
  ^-  form:m
  ;<  roots=(list path)  bind:m  app-roots
  =|  acc=(map @t (list json))
  |-  ^-  form:m
  ?~  roots  (pure:m acc)
  =/  root=path  i.roots
  =/  src=@ta  (rear root)
  ;<  kv=view:nexus  bind:m
    (peek:io [%& %& [root %'alias.json']] `[/ %json])
  ?.  ?=([%file *] kv)  $(roots t.roots)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang.kv))))
  ?~  jon  $(roots t.roots)
  ?.  ?=(%o -.u.jon)  $(roots t.roots)
  =/  names=(list @t)
    =/  nv  (~(get by p.u.jon) 'name')
    ?~  nv  ~
    ?:  ?=(%s -.u.nv)  ~[p.u.nv]
    ?.  ?=(%a -.u.nv)  ~
    (murn p.u.nv |=(j=json ?.(?=(%s -.j) ~ `p.j)))
  ?:  =(~ names)  $(roots t.roots)
  =/  opt=json
    %-  pairs:enjs:format
    :~  ['path' s+(crip (spud root))]
        ['description' s+(fall (jget u.jon 'description') '')]
        ['source' s+src]
    ==
  =/  acc2=(map @t (list json))
    =/  ns=(list @t)  names
    =/  a=(map @t (list json))  acc
    |-  ^-  (map @t (list json))
    ?~  ns  a
    =/  aname=@t  (cat 3 '@' i.ns)
    =/  cur=(list json)  (fall (~(get by a) aname) ~)
    $(ns t.ns, a (~(put by a) aname (snoc cur opt)))
  $(roots t.roots, acc acc2)
::  +build-alias-menus: the full alias directory as menus. Merges the
::  app-scanned options with the user's stored aliases (each a `you`-
::  sourced option), keyed by @name: {@name: [{path, description,
::  source}, ...]}. Stored user options are authoritative; app options
::  are derived. This is what the permission manager renders.
::
++  build-alias-menus
  |=  [suppressed=json show-hidden=?]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  menus=(map @t (list json))  bind:m  read-app-aliases
  ::  suppressed (hidden) options: for the directory view (show-hidden)
  ::  they stay, marked `hidden`, so they can be un-hidden; for resolution
  ::  they're dropped (a hidden option is never offered / resolvable).
  =/  supp=(map @t json)  ?.(?=(%o -.suppressed) ~ p.suppressed)
  =.  menus
    %-  ~(urn by menus)
    |=  [nm=@t opts=(list json)]
    =/  hidden=(set @t)
      =/  h  (~(get by supp) nm)
      ?.  ?=([~ %a *] h)  ~
      (silt (murn p.u.h |=(j=json ?.(?=(%s -.j) ~ `p.j))))
    ?.  show-hidden
      (skip opts |=(o=json (~(has in hidden) (fall (jget o 'path') ''))))
    %+  turn  opts
    |=  o=json
    ?.  (~(has in hidden) (fall (jget o 'path') ''))  o
    ?.  ?=(%o -.o)  o
    [%o (~(put by p.o) 'hidden' b+&)]
  (pure:m [%o (~(run by menus) |=(opts=(list json) `json`[%a opts]))])
::  +link-road: the /sys/link road for an @alias. Strips the leading @
::  and splits on / to build the path — '@pad' -> /sys/link/pad/dest.json,
::  '@chat/v1' -> /sys/link/chat/v1/dest.json. The registry lives outside
::  any nexus subtree so it's world-readable by default.
::
++  link-road
  |=  nm=@t
  ^-  road:tarball
  [%& %& (link-dir nm) %'dest.json']
::  +link-dir: the /sys/link directory path for an @alias (for shallow
::  listing during cull).
::
++  link-dir
  |=  nm=@t
  ^-  path
  =/  bare=tape  ?~((trip nm) ~ (slag 1 (trip nm)))
  (weld /sys/link (stab (crip (weld "/" bare))))
::  +spawn-followers: ensure a /sync/<app> follower grub exists for every
::  top-level app in /apps. Making the grub starts its follower fiber (the
::  [[%sync ~] @] case). Idempotent — skips ones already present. (Culling
::  removed apps' followers + descending into desks are later increments.)
::
::  +sync-lane: the /sync grub lane for an app-root path. Top-level apps
::  mirror as /sync/<name>; desk-nested apps drop the /desk/data and mirror
::  as /sync/<desk>/<sub>. ~ for anything unrecognized.
::
++  sync-lane
  |=  ap=path
  ^-  (unit lane:tarball)
  ?+  ap  ~
    [%apps @ ~]                `[%& [/sync i.t.ap]]
    [%apps @ %desk %data @ ~]  `[%& [/sync/[i.t.ap] i.t.t.t.t.ap]]
  ==
::  +app-road-of: inverse — the app-root road a /sync follower is watching,
::  from the follower's own rail.
::
++  app-path-of
  |=  =rail:tarball
  ^-  (unit path)
  ?+  path.rail  ~
    [%sync ~]    `~[%apps name.rail]
    [%sync @ ~]  `~[%apps i.t.path.rail %desk %data name.rail]
  ==
::  +drop-stale-subs: subscriptions persist across fiber restarts and are
::  never auto-cleaned. An earlier follower version kept its app's WHOLE
::  dir (wire /follow) — those stale dir subs fire on every data write of
::  the app and must be dropped. Only dir-lane subs are stale; the two
::  file keeps are ours.
::
++  drop-stale-subs
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =kept:nexus  bind:m  get-kept:io
  =/  stale=(list bend:tarball)
    (skim ~(tap in kept) |=(b=bend:tarball ?=(%| -.q.b)))
  |-  ^-  form:m
  ?~  stale  (pure:m ~)
  ;<  ~  bind:m  (drop:io /follow [%| i.stale])
  $(stale t.stale)
::  +take-reg-wake: wake the registry liaison — any news (share.json or
::  the public group's weir) or any poke.
::
++  take-reg-wake
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]  [%done ~]
      [~ %poke * *]  [%done ~]
  ==
::  +take-any-news: wake on news from our own file keeps only.
::
++  take-any-news
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  |(=(/alias wire.u.in) =(/weir wire.u.in))  [%done ~]
    [%skip ~]
  ==
::  +spawn-followers: ensure a /sync follower grub exists for every app-root
::  (descending desks, via app-roots). Making the grub starts its follower
::  fiber. Idempotent. (Culling removed apps is a later increment.)
::
++  spawn-followers
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  roots=(list path)  bind:m  app-roots
  =|  made=?
  |-  ^-  form:m
  ?~  roots  (pure:m made)
  =/  syn=(unit lane:tarball)  (sync-lane i.roots)
  ?~  syn  $(roots t.roots)
  =/  fr=road:tarball  (nex-road:io rail u.syn)
  ;<  has=?  bind:m  (peek-exists:io fr)
  ?:  has  $(roots t.roots)
  ::  desk-nested followers live in /sync/<desk>/ — ensure the parent
  ::  dir exists first (make into a missing dir fails).
  ;<  ~  bind:m
    ?.  ?=([%& [%sync @ *] *] u.syn)  (pure:(fiber:fiber:nexus ,~) ~)
    =/  pdir=road:tarball  (nex-road:io rail [%| /sync/[i.t.path.p.u.syn]])
    ;<  pex=?  bind:(fiber:fiber:nexus ,~)  (peek-exists:io pdir)
    ?:  pex  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  err=(unit tang)  bind:(fiber:fiber:nexus ,~)
      (make-soft:io pdir &+empty-dir:loader)
    ~?  >>>  ?=(^ err)  [%shell-sync-dir-failed pdir]
    (pure:(fiber:fiber:nexus ,~) ~)
  ;<  err=(unit tang)  bind:m  (make-soft:io fr |+[[[/ %sig] ~] ~])
  ~?  >>>  ?=(^ err)  [%shell-sync-spawn-failed i.roots]
  $(roots t.roots, made |(made ?=(~ err)))
::  +build-links: materialize the discovery registry at /sys/link/. For
::  each @name, write /sys/link/<segments>/dest.json holding its claimants
::  and locations. Only writes on a genuine content change, so an idle
::  rescan doesn't bump versions and spam subscribers. Discovery is the
::  whole job — the grub holds WHERE apps are, never their data.
::
::  INVARIANT: /sys/link MUST always be current. A discovery registry that
::  lags hands out stale locations — it's worthless if it can be stale.
::
::  TODO (not built yet): drive this by SUBSCRIPTION, never a poll.
::
::  TODO (related): alias resolution is frozen into grant.json bindings at
::  approval time. When /sys/link shows an @name now resolves to a different
::  target, every approved weir that referenced that name is pointing at a
::  stale path — the shell should surface those and ask the user to re-point
::  them.
::
::  +build-share: invert every local desk's share.usergroups into per-
::  usergroup discovery directories. /share/<group>/desks.json lists the
::  desks that group may subscribe to and where their code + version live.
::  Rebuilt wholesale so a group that lost its last desk clears cleanly.
::
++  build-share
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek-shallow:io [%& %| /apps] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  kids=(list @ta)  ~(tap in ~(key by dir.ball.view))
  ;<  pairs=(list [grp=path entry=json])  bind:m  (gather-shares kids)
  =/  jarred=(jar path json)
    %+  roll  pairs
    |=  [[grp=path entry=json] a=(jar path json)]
    (~(add ja a) grp entry)
  ::  wipe the old tree, then write one desks.json per group present now
  ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%| /share]))
  =/  groups=(list [grp=path es=(list json)])  ~(tap by jarred)
  |-  ^-  form:m
  ?~  groups  (pure:m ~)
  ;<  ~  bind:m
    %+  over:io  (nex-road:io rail [%& (weld /share grp.i.groups) %'desks.json'])
    [[/ %json] a+`(list json)`es.i.groups]
  $(groups t.groups)
::  +gather-shares: for each local app, read its share.usergroups (absent
::  for non-desks) and emit one [group, desk-entry] pair per group it opens to.
::
++  gather-shares
  |=  kids=(list @ta)
  =/  m  (fiber:fiber:nexus ,(list [path json]))
  ^-  form:m
  ?~  kids  (pure:m ~)
  ;<  shr=(unit (set path))  bind:m
    (peek-as:io [%& %& /apps/[i.kids] %'share.usergroups'] ,(set path))
  ;<  rest=(list [path json])  bind:m  $(kids t.kids)
  ?~  shr  (pure:m rest)
  =/  entry=json  (desk-entry i.kids)
  (pure:m (weld (turn ~(tap in u.shr) |=(g=path [g entry])) rest))
::  +desk-entry: one shared desk as a discovery card — display name plus the
::  code road a follower subscribes to (peers prepend the ship; the version
::  rides inside <code>/version.json).
::
++  desk-entry
  |=  name=@ta
  ^-  json
  %-  pairs:enjs:format
  :~  ['name' s+(app-slug name)]
      ['dir' s+name]
      ['code' s+(crip "/apps/{(trip name)}/desk/code")]
  ==
::
++  build-links
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  menus=(map @t (list json))  bind:m  read-app-aliases
  =/  entries=(list [nm=@t opts=(list json)])  ~(tap by menus)
  =/  want=(set path)  (silt (turn entries |=([nm=@t *] (link-dir nm))))
  |-  ^-  form:m
  ?~  entries
    ::  cull pass: drop /sys/link dirs whose alias no longer has any claimant
    ;<  bv=view:nexus  bind:m  (peek-shallow:io [%& %| /sys/link] ~)
    ?.  ?=([%ball *] bv)  (pure:m ~)
    =/  haves=(list @ta)  ~(tap in ~(key by dir.ball.bv))
    |-  ^-  form:m
    ?~  haves  (pure:m ~)
    ?:  (~(has in want) /sys/link/[i.haves])  $(haves t.haves)
    ;<  *  bind:m  (cull-soft:io [%& %| /sys/link/[i.haves]])
    $(haves t.haves)
  =/  road=road:tarball  (link-road nm.i.entries)
  =/  wj=json   [%a opts.i.entries]
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  have=(unit json)
    ?.  ?=([%file *] cur)  ~
    (mole |.(!<(json (need-vase:tarball sang.cur))))
  ?:  =(`wj have)  $(entries t.entries)
  ;<  ~  bind:m  (put:io road [[/ %json] wj])
  $(entries t.entries)
::  +build-aliases: materialize the alias directory (menus incl. hidden
::  marks) into /permit/aliases.json — the permits page reads it ready.
::
++  build-aliases
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  hidden=json  bind:m  (read-hidden rail)
  ;<  want=json    bind:m  (build-alias-menus hidden %.y)
  ;<  cur=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /cache %'aliases.json']) `[/ %json])
  =/  have=(unit json)
    ?.  ?=([%file *] cur)  ~
    (mole |.(!<(json (need-vase:tarball sang.cur))))
  ?:  =(`want have)  (pure:m ~)
  (put:io (nex-road:io rail [%& /cache %'aliases.json']) [[/ %json] want])
::  +build-weirs: materialize the live-weir overlay view into
::  /permit/weirs.json.
::
++  build-weirs
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  approved=(map @t json)  bind:m  (read-approved rail)
  ;<  hidden=json  bind:m  (read-hidden rail)
  ;<  want=json    bind:m  (read-approved-weirs approved hidden)
  ;<  cur=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /cache %'weirs.json']) `[/ %json])
  =/  have=(unit json)
    ?.  ?=([%file *] cur)  ~
    (mole |.(!<(json (need-vase:tarball sang.cur))))
  ?:  =(`want have)  (pure:m ~)
  (put:io (nex-road:io rail [%& /cache %'weirs.json']) [[/ %json] want])
::  +notify-if-unsettled: one app's weir.json changed — notify unless the
::  ask is already settled (matches its approved record). No stored dedup:
::  the follower's subscription only fires on real change.
::
++  notify-if-unsettled
  |=  [rail=rail:tarball ap=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  wv=view:nexus  bind:m  (peek:io [%& %& ap %'weir.json'] `[/ %json])
  ?.  ?=([%file *] wv)  (pure:m ~)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang.wv))))
  ?~  jon  (pure:m ~)
  ?.  ?=(%o -.u.jon)  (pure:m ~)
  =/  app=@t  (crip (spud ap))
  =/  ask=json  [%o (~(put by p.u.jon) 'app' s+app)]
  ;<  approved=(map @t json)  bind:m  (read-approved rail)
  ?:  (is-settled ask approved)  (pure:m ~)
  ::  already told the user about this exact pending ask? don't re-ping on a
  ::  reload. A changed ask fails the match below and notifies afresh.
  ;<  notified=(map @t json)  bind:m  (read-notified rail)
  ?:  (is-notified ask notified)  (pure:m ~)
  ;<  ~  bind:m  (register-notify rail)
  ;<  *  bind:m  (notify-app rail app)
  ;<  ~  bind:m  (mark-notified rail app ask)
  (pure:m ~)
::  +build-asks: materialize the pending-asks view into /permit/asks.json so
::  the UI fetches a ready grub instead of re-running read-app-weirs +
::  alias-menu marking on every request. Same diff-then-write discipline as
::  build-links. Kept fresh by the followers and by
::  do-suppress (hidden changes affect the @name resolution marking).
::
++  build-asks
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  hidden=json      bind:m  (read-hidden rail)
  ;<  menus=json       bind:m  (build-alias-menus hidden %.n)
  ;<  asks=(list json)  bind:m  read-app-weirs
  =/  marked=(list json)  (turn asks |=(a=json (mark-unresolved a menus)))
  =/  want=json  [%a marked]
  ;<  cur=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /cache %'asks.json']) `[/ %json])
  =/  have=(unit json)
    ?.  ?=([%file *] cur)  ~
    (mole |.(!<(json (need-vase:tarball sang.cur))))
  ?:  =(`want have)  (pure:m ~)
  (put:io (nex-road:io rail [%& /cache %'asks.json']) [[/ %json] want])
::  +read-app-weirs: scan /apps for each app's weir.json — its complete
::  declared permission ask ({poke, peek, make} lists of target roads,
::  some `@alias` refs). Returns one json per app {app, path, poke,
::  peek, make}. This is the manifest the user consents to as a unit.
::
++  read-app-weirs
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  roots=(list path)  bind:m  app-roots
  =|  acc=(list json)
  |-  ^-  form:m
  ?~  roots  (pure:m (flop acc))
  =/  root=path  i.roots
  ;<  wv=view:nexus  bind:m
    (peek:io [%& %& [root %'weir.json']] `[/ %json])
  ?.  ?=([%file *] wv)  $(roots t.roots)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang.wv))))
  ?~  jon  $(roots t.roots)
  ?.  ?=(%o -.u.jon)  $(roots t.roots)
  ::  the app id IS its nexus-root path (disambiguates two nexuses of the
  ::  same name in different desks); path is the same.
  =/  ap=@t  (crip (spud root))
  =/  ask=json
    %-  pairs:enjs:format
    :~  ['app' s+ap]
        ['path' s+ap]
        ['poke' (fall (~(get by p.u.jon) 'poke') [%a ~])]
        ['peek' (fall (~(get by p.u.jon) 'peek') [%a ~])]
        ['make' (fall (~(get by p.u.jon) 'make') [%a ~])]
    ==
  $(roots t.roots, acc [ask acc])
::  +read-app-weir-json: one app's declared weir.json, if any. `app` is
::  its nexus-root path.
::
++  read-app-weir-json
  |=  app=@t
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  tp=(unit path)  (soft-path app)
  ?~  tp  (pure:m ~)
  =/  root=path  u.tp
  ;<  wv=view:nexus  bind:m
    (peek:io [%& %& [root %'weir.json']] `[/ %json])
  ?.  ?=([%file *] wv)  (pure:m ~)
  (pure:m (mole |.(!<(json (need-vase:tarball sang.wv)))))
::  +road-strs: the string list for one category of a weir.json ask.
::
++  road-strs
  |=  [ask=json cat=@t]
  ^-  (list @t)
  ?.  ?=(%o -.ask)  ~
  =/  v  (~(get by p.ask) cat)
  ?.  ?=([~ %a *] v)  ~
  ::  a line is either a bare road string or {road, why}
  %+  murn  p.u.v
  |=  j=json
  ?:  ?=(%s -.j)  `p.j
  ?.  ?=(%o -.j)  ~
  =/  r  (~(get by p.j) 'road')
  ?.(?=([~ %s *] r) ~ `p.u.r)
::  +cat-arr: pass a category's raw json array through (for the record).
::
++  cat-arr
  |=  [ask=json cat=@t]
  ^-  json
  ?.  ?=(%o -.ask)  [%a ~]
  (fall (~(get by p.ask) cat) [%a ~])
::  +parse-at-ref: split an @-prefixed ref into [name suffix]. Handles
::  both @simple/suffix and @'quoted/name'/suffix forms.
::
++  parse-at-ref
  |=  ref=@t
  ^-  [aname=@t suffix=@t]
  =/  tap=tape  (trip ref)
  ?~  tap  [ref '']
  ?.  =('@' i.tap)  [ref '']
  =/  rest=tape  t.tap
  ?~  rest  [ref '']
  ?:  =(39 i.rest)
    =/  close=(unit @ud)  (find "'" t.rest)
    ?~  close  [ref '']
    =/  name=@t  (crip (scag u.close t.rest))
    =/  after=tape  (slag +(u.close) t.rest)
    [(cat 3 '@' name) ?~(after '' (crip after))]
  =/  idx=(unit @ud)  (find "/" rest)
  ?~  idx  [ref '']
  =/  aname=@t  (crip (scag +(u.idx) `tape`tap))
  =/  suffix=@t  (crip (slag u.idx `tape`rest))
  [aname suffix]
::  +ref-aliases: the unique @alias names referenced across an ask (the
::  base, before any /sub-path). For building the app's grant.json map.
::
++  ref-aliases
  |=  ask=json
  ^-  (list @t)
  =/  all=(list @t)
    :(weld (road-strs ask 'poke') (road-strs ask 'peek') (road-strs ask 'make'))
  =/  names=(set @t)
    %+  roll  all
    |=  [s=@t acc=(set @t)]
    ?.  =("@" (scag 1 (trip s)))  acc
    (~(put in acc) aname:(parse-at-ref s))
  ~(tap in names)
::  +resolve-alias-ref: a weir.json target -> concrete road text. A plain
::  road passes through; an @alias resolves against the menu (first
::  option's path for now) with everything after the @name appended as
::  the sub-path. Supports @'multi/segment' names. '' when the alias
::  has no options.
::
++  resolve-alias-ref
  |=  [picks=json menus=json ref=@t]
  ^-  @t
  ?.  =("@" (scag 1 (trip ref)))  ref
  =/  [aname=@t suffix=@t]  (parse-at-ref ref)
  ::  the user's explicit pick for this alias wins; else the first option
  =/  picked=@t  ?.(?=(%o -.picks) '' (fall (jget picks aname) ''))
  =/  base=@t
    ?.  =('' picked)  picked
    =/  opts=(unit json)  ?.(?=(%o -.menus) ~ (~(get by p.menus) aname))
    ?~  opts  ''
    ?.  ?=([%a *] u.opts)  ''
    ?~  p.u.opts  ''
    (fall (jget i.p.u.opts 'path') '')
  ?:(=('' base) '' (cat 3 base suffix))
::  +add-roads: fold a list of road-text into a category's road set.
::
++  add-roads
  |=  [s=(set road:tarball) strs=(list @t)]
  ^-  (set road:tarball)
  %+  roll  strs
  |=  [str=@t acc=_s]
  =/  r=(unit road:tarball)  (parse-road str)
  ?~(r acc (~(put in acc) u.r))
::  +approval-entry: build one app's approval record — the GRANTED subset
::  (poke/peek/make, drives overlay + grant.json) plus `declared` (the full
::  ask ruled on, drives the settled diff so granting a subset still settles
::  instead of re-nagging), the alias bindings, verdict, and timestamp. This
::  is the content of its permit/approved/<app> grub — present grant state,
::  the system of record.
::
++  approval-entry
  |=  [app=@t declared=json granted=json verdict=@t bindings=json now=@da]
  ^-  json
  %-  pairs:enjs:format
  :~  ['app' s+app]
      ['poke' (cat-arr granted 'poke')]
      ['peek' (cat-arr granted 'peek')]
      ['make' (cat-arr granted 'make')]
      :-  'declared'
      %-  pairs:enjs:format
      :~  ['poke' (cat-arr declared 'poke')]
          ['peek' (cat-arr declared 'peek')]
          ['make' (cat-arr declared 'make')]
      ==
      ['bindings' bindings]
      ['verdict' s+verdict]
      ['at' s+(scot %da now)]
  ==
::  +soft-path: parse a cord to a path without crashing (stab throws a
::  syntax error on bad input; an app id should be a valid path, but a
::  stale/malformed one must not take down the fiber).
::
++  soft-path
  |=  s=@t
  ^-  (unit path)
  =/  r  (mule |.((stab s)))
  ?:(?=(%| -.r) ~ `p.r)
::  +read-live-weir: the live weir on a target dir (via its parent entry).
::
++  read-live-weir
  |=  target=path
  =/  m  (fiber:fiber:nexus ,weir:tarball)
  ^-  form:m
  =/  parent=path  (snip `path`target)
  =/  leaf=@ta  (rear `path`target)
  ;<  pv=view:nexus  bind:m  (peek-shallow:io [%& %| parent] ~)
  ?.  ?=([%ball *] pv)  (pure:m [~ ~ ~])
  =/  child  (~(get by dir.ball.pv) leaf)
  ?~  child  (pure:m [~ ~ ~])
  (pure:m (fall ?~(fil.u.child ~ weir.u.fil.u.child) [~ ~ ~]))
::  +overlay-cat: one category's roads, the approved manifest overlaid on
::  the live weir. Each approved road (resolved via its bindings) is
::  `active` if present in the live weir, else `missing` (consented but
::  gone — drift). Live roads with no approved match are `unmanaged`
::  (present but never consented — drift the other way).
::
::  +optional-roads: the set of road-text an ask marks optional (a weir.json
::  line with "optional": true), so the overlay can tag them.
::
++  optional-roads
  |=  [ask=json cat=@t]
  ^-  (set @t)
  ?.  ?=(%o -.ask)  ~
  =/  v  (~(get by p.ask) cat)
  ?.  ?=([~ %a *] v)  ~
  %-  silt
  %+  murn  p.u.v
  |=  j=json
  ?.  ?=(%o -.j)  ~
  ?.  =(`[%b &] (~(get by p.j) 'optional'))  ~
  =/  r  (~(get by p.j) 'road')
  ?.(?=([~ %s *] r) ~ `p.u.r)
::
++  overlay-cat
  |=  [entry=json picks=json menus=json live=(set road:tarball) cat=@t]
  ^-  json
  =/  declared=json
    ?.  ?=(%o -.entry)  [%o ~]
    (fall (~(get by p.entry) 'declared') [%o ~])
  =/  opt-set=(set @t)  (optional-roads declared cat)
  =/  granted-strs=(list @t)  (road-strs entry cat)
  ::  build one road json, tagging `optional` when the raw ref was declared so.
  =/  mk=$-([@t @t @t] json)
    |=  [d=@t txt=@t stat=@t]
    =/  base=(list [@t json])  ~[['road' s+txt] ['status' s+stat]]
    (pairs:enjs:format ?:((~(has in opt-set) d) (snoc base ['optional' b+&]) base))
  =/  pairs=(list [d=@t txt=@t r=(unit road:tarball)])
    %+  turn  granted-strs
    |=  d=@t
    =/  resolved=@t  (resolve-alias-ref picks menus d)
    [d resolved (parse-road resolved)]
  =/  approved-set=(set road:tarball)
    (silt (murn pairs |=([d=@t txt=@t r=(unit road:tarball)] r)))
  =/  approved-json=(list json)
    %+  turn  pairs
    |=  [d=@t txt=@t r=(unit road:tarball)]
    =/  active=?  &(?=(^ r) (~(has in live) u.r))
    (mk d txt ?:(active 'active' 'missing'))
  ::  denied: roads the app declared but we withheld (declared - granted),
  ::  resolved for display (raw @ref if it doesn't resolve).
  =/  denied-json=(list json)
    %+  turn  (skip (road-strs declared cat) |=(d=@t (lien granted-strs |=(g=@t =(g d)))))
    |=  d=@t
    =/  resolved=@t  (resolve-alias-ref picks menus d)
    (mk d ?:(=('' resolved) d resolved) 'denied')
  =/  extra-json=(list json)
    %+  turn  (skim ~(tap in live) |=(r=road:tarball !(~(has in approved-set) r)))
    |=  r=road:tarball
    (pairs:enjs:format ~[['road' s+(road-to-cord:tarball r)] ['status' s+'unmanaged']])
  [%a :(weld approved-json denied-json extra-json)]
::  +read-approved-weirs: for each consented app, its approved manifest
::  overlaid on the live weir at its target. The honest per-app picture.
::
++  read-approved-weirs
  |=  [approved=(map @t json) hidden=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  menus=json  bind:m  (build-alias-menus hidden %.n)
  =|  out=(map @t json)
  =/  apps=(list [@t json])  ~(tap by approved)
  |-  ^-  form:m
  ?~  apps  (pure:m [%o out])
  =/  app=@t  -.i.apps
  =/  entry=json  +.i.apps
  =/  picks=json
    ?.(?=(%o -.entry) [%o ~] (fall (~(get by p.entry) 'bindings') [%o ~]))
  =/  tp=(unit path)  (soft-path app)
  ?~  tp  $(apps t.apps)
  =/  target=path  u.tp
  ;<  live=weir:tarball  bind:m  (read-live-weir target)
  =/  result=json
    %-  pairs:enjs:format
    :~  ['app' s+app]
        ['target' s+(crip (spud target))]
        ['verdict' s+(fall (jget entry 'verdict') '')]
        ['poke' (overlay-cat entry picks menus poke.live 'poke')]
        ['peek' (overlay-cat entry picks menus peek.live 'peek')]
        ['make' (overlay-cat entry picks menus make.live 'make')]
    ==
  $(apps t.apps, out (~(put by out) app result))
::  +do-approve-weir: consent to an app's whole weir.json as a unit —
::  resolve its @alias refs, add the roads to the app's own weir (read-
::  modify-sand, additive), then record the approved manifest.
::
++  do-approve-weir
  |=  [rail=rail:tarball app=@t picks=json granted=json hidden=json now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ask=(unit json)  bind:m  (read-app-weir-json app)
  ?~  ask  (pure:m ~)
  ?.  ?=(%o -.u.ask)  (pure:m ~)
  ::  what gets sanded is the granted subset, not the whole declared ask
  =/  sub=json  ?:(?=(%o -.granted) granted u.ask)
  ;<  menus=json  bind:m  (build-alias-menus hidden %.n)
  =/  tp=(unit path)  (soft-path app)
  ?~  tp  (pure:m ~)
  =/  target=path  u.tp
  =/  poke-res=(list @t)
    (turn (road-strs sub 'poke') |=(t=@t (resolve-alias-ref picks menus t)))
  =/  peek-res=(list @t)
    (turn (road-strs sub 'peek') |=(t=@t (resolve-alias-ref picks menus t)))
  =/  make-res=(list @t)
    (turn (road-strs sub 'make') |=(t=@t (resolve-alias-ref picks menus t)))
  ::  TOTAL REPLACEMENT: the target weir becomes exactly the granted
  ::  subset — not a union with what was there. Safe because the sand
  ::  target is born-locked (a desk's data) or the whole app root, and
  ::  the manifest is meant to be complete. Wipes any prior drift.
  =/  new=weir:tarball
    [(add-roads ~ make-res) (add-roads ~ poke-res) (add-roads ~ peek-res)]
  ;<  ~  bind:m  (sand:io [%& %| target] `new)
  ::  write grant.json into the app's sandbox root: its resolved grants +
  ::  the @alias -> path map, so the app can read what it holds and
  ::  resolve its own aliases (fill config) without guessing.
  =/  amap=json
    :-  %o
    %-  ~(gas by *(map @t json))
    %+  turn  (ref-aliases sub)
    |=(n=@t [n s+(resolve-alias-ref picks menus n)])
  =/  grant-json=json
    %-  pairs:enjs:format
    :~  ['poke' [%a (turn poke-res |=(t=@t s+t))]]
        ['peek' [%a (turn peek-res |=(t=@t s+t))]]
        ['make' [%a (turn make-res |=(t=@t s+t))]]
        ['aliases' amap]
        ::  the app's own root path — so it knows its address without a
        ::  privileged walk to root (get-here-abs). It's just structural
        ::  boilerplate (/apps/<name> or /apps/<desk>/desk/data/<name>).
        ['here' s+app]
    ==
  ;<  ~  bind:m  (put:io [%& %& [target %'grant.json']] [[/ %json] grant-json])
  ::  freeze the FULL resolved binding map (amap), not just the explicit
  ::  picks — so a menu-of-one (auto-resolved, no picker) still records what
  ::  it dereferenced to, and the applied overlay shows the concrete path.
  =/  entry=json  (approval-entry app u.ask sub 'granted' amap now)
  ;<  cur=(map @t json)  bind:m  (read-approved rail)
  ;<  ~  bind:m
    (put:io (nex-road:io rail [%& /permit %'approved.json']) [[/ %json] [%o (~(put by cur) app entry)]])
  ::  reboot the app with its new grants: fibers that crashed while jailed
  ::  (a closed install's rise) come back alive holding what was granted.
  (reload:io [%& %| target])
::  +do-deny-weir: record an app's weir.json as denied (no sand), so it
::  stops prompting until the app re-declares a different manifest.
::
++  do-deny-weir
  |=  [rail=rail:tarball app=@t now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ask=(unit json)  bind:m  (read-app-weir-json app)
  ?~  ask  (pure:m ~)
  =/  entry=json  (approval-entry app u.ask [%o ~] 'denied' [%o ~] now)
  ;<  cur=(map @t json)  bind:m  (read-approved rail)
  (put:io (nex-road:io rail [%& /permit %'approved.json']) [[/ %json] [%o (~(put by cur) app entry)]])
::  +mark-unresolved: flag an ask's @alias refs that can't resolve against
::  the (hidden-excluded) resolution menu — an unknown name or one whose
::  every option is hidden. These are surfaced and blocked at consent, not
::  silently dropped. `menus` is build-alias-menus with show-hidden=%.n.
::
++  mark-unresolved
  |=  [ask=json menus=json]
  ^-  json
  ?.  ?=(%o -.ask)  ask
  =/  refs=(list @t)
    :(weld (road-strs ask 'poke') (road-strs ask 'peek') (road-strs ask 'make'))
  =/  bad=(list @t)
    %+  murn  refs
    |=  r=@t
    ?.  =("@" (scag 1 (trip r)))  ~
    ?.  =('' (resolve-alias-ref [%o ~] menus r))  ~
    `r
  [%o (~(put by p.ask) 'unresolved' [%a (turn bad |=(r=@t s+r))])]
::
++  read-all-tiles
  =/  m  (fiber:fiber:nexus ,(list [tile root=(unit path)]))
  ^-  form:m
  ;<  local=(list tile)  bind:m  read-local-tiles
  =/  local-names=(set @ta)  (sy (turn local |=(t=tile name.t)))
  ;<  app-pairs=(list [tile path])  bind:m  read-app-tiles
  ::  local tiles have no app root (not uninstallable); app tiles carry
  ::  theirs so the UI can offer uninstall.
  =/  merged=(list [tile (unit path)])
    %+  weld  (turn local |=(t=tile [t *(unit path)]))
    %+  murn  app-pairs
    |=  [t=tile r=path]
    ^-  (unit [tile (unit path)])
    ?:((~(has in local-names) name.t) ~ `[t `r])
  (pure:m (sort merged |=([a=[tile *] b=[tile *]] (aor name.-.a name.-.b))))
::
++  tiles-to-json
  |=  tiles=(list [t=tile root=(unit path)])
  ^-  json
  :-  %a
  %+  turn  tiles
  |=  [t=tile root=(unit path)]
  %-  pairs:enjs:format
  :~  name+s+name.t
      title+s+title.t
      info+s+info.t
      color+s+color.t
      image+s+image.t
      href+s+href.t
      root+?~(root ~ s+(crip (spud u.root)))
  ==
--
