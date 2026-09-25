::  shell nexus: the home surface. Composes services — the launcher grid
::  (from the tiles store) and the notifications bell — over HTTP, and
::  owns the cross-ship discovery state: public.json, the derived
::  directory of this ship's shared desks, and /peers/, live mirrors
::  of other ships' directories.
::
::  Terminology — the shell/kernel distinction. The "shell" is the
::  userspace permission MANAGER: it reads apps' declared link.json /
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
::  shared <split-view> web component — the resizable docs sidebar
/&  splitview-js   /lib/ui/split-view.js
::  shared window components — the docs assistant floats in a <float-window>.
::  window-manager.js publishes window.floatwm and MUST load before float-window.
/&  windowmgr-js   /lib/ui/window-manager.js
/&  floatwin-js    /lib/ui/float-window.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          ::  mirror.sig: keeps a local copy of the covered source under
          ::  /docs/mirror, so coverage recomputes from our own ball (data.hoon
          ::  style) and the docs subsystem (config, mirror, agent) is one
          ::  self-contained subtree. On rise it re-mirrors every target; the
          ::  mirror dir is rebuildable cache, never user data.
          [%fall %& [/ %'mirror.sig'] [[/ %sig] ~]]
          [%fall %| /docs/mirror empty-dir:loader]
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
          ::  One dest.lanes per @name holding its target lanes — peers
          ::  (local or cross-ship) can `keep` a name and learn where
          ::  its app lives.
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
          ::  /desks: installed remote code (desk nexus instances). Lives
          ::  under the shell, not /apps — desks need permission management,
          ::  built-in apps at /apps don't.
          [%fall %| /desks empty-dir:loader]
          ::  /share: per-usergroup discovery directories, derived from
          ::  local desks' share.usergroups. /share/<group>/desks.json lists
          ::  the desks that group may subscribe to and where their code +
          ::  version live. Rebuilt from the live grants by the followers.
          [%fall %| /share empty-dir:loader]
          [%fall %| /peers empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
          ::  /docs: holds the handbook's CONFIG grubs (targets, ignore, pins).
          ::  The prose itself is NOT seeded here — it lives in the documented
          ::  target's own man/docs (referenced, not owned) and is read from the
          ::  mirror. See the docs page/search/anchor arms.
          [%fall %| /docs empty-dir:loader]
          ::  freshness pins for the live-code blocks: a map of
          ::  "<doc>|<file>|<range>" -> the content hash of that span as of
          ::  when the block was first seen. %fall so it seeds empty once and
          ::  then belongs to the runtime — pins persist across reloads. The
          ::  browser computes the hash (the same cyrb53 the badges use) and
          ::  the ship only stores it; auto-pin is stamp-once, never re-stamped
          ::  on view, so drift stays visible.
          [%fall %& [/docs %'pins.json'] [[/ %json] [%o ~]]]
          ::  coverage targets: the list of source files we WANT documented,
          ::  the denominator for coverage. A file on this list with no live
          ::  block reads as uncovered (a gap); a documented file NOT on the
          ::  list is extra credit. %fall so the list is editable at runtime
          ::  and persists. Stored as a json array of "/code"-relative paths.
          [%fall %& [/docs %'targets.json'] [[/ %json] [%a ~]]]
          ::  (ignore is not a shell grub — it lives in the documented target's
          ::  own man/docs manifest, read from the mirror at compute time.)
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
          ::  mirror.sig: on rise, copy every target directory's source into our
          ::  own /docs/mirror (each mounted by +mirror-mount), so
          ::  coverage computes from local data. Re-mirrors on rise and whenever
          ::  targets.json changes; the mirror is not pruned, so coverage counts
          ::  only files under a current target (+under-roots).
          [~ %'mirror.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell mirror: failed")
        |^
        ;<  ~  bind:m  do-mirror
        ::  wake and re-mirror whenever the target list changes
        ;<  *  bind:m  (keep:io /cfg-t (nex-road:io rail [%& /docs %'targets.json']) `[/ %json])
        |-  ^-  process:fiber:nexus
        ;<  ~  bind:m  take-any-news
        ;<  ~  bind:m  do-mirror
        $
        ++  do-mirror
          =/  m  (fiber:fiber:nexus ,~)
          ^-  form:m
          ;<  tgs=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /docs %'targets.json']) ,json)
          =/  dirs=(list @t)  (turn (targ-list tgs) |=([t=@t *] t))
          |-  ^-  form:m
          ?~  dirs  (pure:m ~)
          ;<  ~  bind:m  (mirror-dir rail (target-path i.dirs))
          $(dirs t.dirs)
        --
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
          ::  on any change (link.json, weir.json, …) pings the scanner to
          ::  reconcile /sys/link and the asks. Holds no state, writes nothing.
          ::
          [[%sync *] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell follow: failed")
        =/  ap=(unit path)  (app-path-of rail)
        ?~  ap  (pure:m ~)
        ;<  ~  bind:m  drop-stale-subs
        ::  follow ONLY the declaration files — never the whole app tree, or
        ::  a ticking app (counter, weather) fires us on every data write.
        ;<  *  bind:m  (keep:io /alias [%& %& u.ap %'link.json'] ~)
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
            ?:  ?=([%apps %'shell.shell' %desks @ %desk %data @ ~] u.rt)
              `/apps/'shell.shell'/desks/[i.t.t.t.u.rt]
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
          =/  dir-path=path
            /apps/'shell.shell'/desks/[(cat 3 `@ta`name '.desk')]
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
        ::  POST /desks/sync {name}: sync ONE stock desk — find its entry and
        ::  run the same +ensure-pairing the "Sync all" path uses per entry.
        ?:  &(=('POST' method.request.req) ?=([%desks %sync ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  name=@t  (jstr jon 'name')
          =/  match=(unit stock-entry)  (find-stock name)
          ?~  match
            ;<  ~  bind:m
              (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'no such stock desk')])
            (pure:m ~)
          ;<  ~  bind:m  (ensure-pairing u.match)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'synced')])
          (pure:m ~)
        ::  POST /desks/delete {app}: cull a desk from /desks/<app>.
        ?:  &(=('POST' method.request.req) ?=([%desks %delete ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  app=@t  (jstr jon 'app')
          ?:  =('' app)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'app required')])
            (pure:m ~)
          ;<  ~  bind:m
            (cull:io (nex-road:io rail [%| /desks/[(crip (trip app))]]))
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
          ::  <desk>/<nexus> -> /apps/shell.shell/desks/<desk>/desk/data/<nexus>,
          ::  a bare <nexus> -> /apps/<nexus>, or a full /apps/... path as-is.
          =/  segs=path  t.suffix
          =/  root=path
            ?:  ?=([%apps *] segs)  segs
            ?:  ?=([@ @ ~] segs)
              ~[%apps %'shell.shell' %desks i.segs %desk %data i.t.segs]
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
        ::  app-declared link.json options merged with your stored ones.
        ::  /grubbery/tiles/desks/peers → peers' published desks, enriched
        ::  for the "add apps" browser (folded in from the retired /desks).
        ?:  ?=([%desks %peers ~] suffix)
          ;<  lst=json  bind:m  gather-peers
          =/  bod=octs  (as-octs:mimes:html (en:json:html lst))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /grubbery/tiles/desks/taken → every /desks child name, for
        ::  install-name availability checks.
        ?:  ?=([%desks %taken ~] suffix)
          ;<  =view:nexus  bind:m
            (peek-shallow:io [%& %| /apps/'shell.shell'/desks] ~)
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
        ::  shared <split-view> web component (the resizable sidebar)
        ?:  ?=([%docs %'split-view.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.splitview-js])
          (pure:m ~)
        ::  window components for the floating docs assistant (manager first)
        ?:  ?=([%docs %'window-manager.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.windowmgr-js])
          (pure:m ~)
        ?:  ?=([%docs %'float-window.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.floatwin-js])
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
        ::  /apps/grubbery/docs/nav.json → the sidebar tree, read from the
        ::  documented target's own man/docs/docs.json manifest (nav field) via
        ::  the mirror. The desk owns its sidebar shape; the shell just renders.
        ?:  ?=([%docs %'nav.json' ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          ;<  [* nav=json]  bind:m  (read-docs-config rail c)
          ::  tag each section with whether it has coverage (a ◆ in the reader).
          ;<  anchors=(list [doc=@t file=@t from=@ud to=@ud])  bind:m
            (gather-all-anchors rail c)
          =/  anchored=(set @t)  (silt (turn anchors |=(a=[doc=@t *] doc.a)))
          =/  bod=octs  (as-octs:mimes:html (en:json:html (annotate-nav nav anchored)))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/docs/pins.json → the freshness pins map, read by
        ::  the reader to check each live block against its stamped hash.
        ?:  ?=([%docs %'pins.json' ~] suffix)
          ;<  cur=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /docs %'pins.json']) ,json)
          =/  bod=octs  (as-octs:mimes:html (en:json:html (fall cur [%o ~])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  PROBE: /apps/grubbery/docs/covsrc?path=/lib/x.hoon → read /code
        ::  source ship-side; report line count + mug + head, to check that
        ::  the ship's raw-text extraction lines up with the browser's.
        ?:  ?=([%docs %covsrc ~] suffix)
          =/  args=quay:eyre  args:(parse-url:http-utils url.request.req)
          =/  pl  (skim args |=([p=@t q=@t] =(p 'path')))
          =/  pax=@t  ?~(pl '' q.i.pl)
          =/  raw-pax=tape  (trip pax)
          =/  full=path
            (stab (crip ?:(=("/code" (scag 5 raw-pax)) raw-pax (weld "/code" raw-pax))))
          ;<  =view:nexus  bind:m  (peek:io [%& %& (snip full) (rear full)] ~)
          ?.  ?=([%file *] view)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'not found')])
            (pure:m ~)
          =/  txt=@t  (grub-text view)
          =/  lines=(list @t)  (to-wain:format txt)
          =/  resp=json
            %-  pairs:enjs:format
            :~  ['lines' (numb:enjs:format (lent lines))]
                ['mug' (numb:enjs:format `@`(mug txt))]
                ['head' s+(crip (scag 90 (trip txt)))]
            ==
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html resp))])
          (pure:m ~)
        ::  DEBUG: /apps/grubbery/docs/anchors.json → every live-block anchor
        ::  across all docs, parsed ship-side. Validates the anchor parser.
        ?:  ?=([%docs %'anchors.json' ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          ;<  [* nav=json]  bind:m  (read-docs-config rail c)
          ;<  dc=path  bind:m  (docs-of rail c)
          =/  items=(list [path=@t title=@t])  (nav-items nav)
          =|  all=(list json)
          |-  ^-  process:fiber:nexus
          ?~  items
            =/  bod=octs  (as-octs:mimes:html (en:json:html [%a (flop all)]))
            ;<  ~  bind:m
              (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
            (pure:m ~)
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& (coll-docs c dc) `@ta`path.i.items]) ~)
          =/  txt=@t  (grub-text fv)
          =.  all
            %+  weld  all
            %+  turn  (parse-anchors txt)
            |=  [file=@t from=@ud to=@ud]
            %-  pairs:enjs:format
            :~  ['doc' s+path.i.items]
                ['file' s+file]
                ['from' (numb:enjs:format from)]
                ['to' (numb:enjs:format to)]
            ==
          $(items t.items)
        ::  /apps/grubbery/docs/coverage.json → the computed coverage, from the
        ::  mirror: per target file, its line total and how many lines a doc's
        ::  live block covers. Denominator = mirrored files minus the ignore
        ::  list. (Freshness via mug + pins is layered on next.)
        ?:  ?=([%docs %'coverage.json' ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          ::  ignore lives in the collection's own man/docs manifest — the desk
          ::  declares what within itself doesn't count. nav carries the section
          ::  scopes (sub-coverage) alongside the sidebar tree.
          ;<  [ignore=(list @t) nav=json]  bind:m  (read-docs-config rail c)
          ::  optional ?section=<name>: restrict the denominator to that nav
          ::  section's scope (a list of "path [range]" selectors). Empty = the
          ::  whole collection.
          =/  sec=@t
            =/  qa=quay:eyre  args:(parse-url:http-utils url.request.req)
            =/  sl  (skim qa |=([p=@t q=@t] =(p 'section')))
            ?~(sl '' q.i.sl)
          =/  in-section=?  !=('' sec)
          ::  enumerate this collection's mirror subtree: source-path (relative
          ::  to the collection root) -> its lines. Ignored files are kept in the
          ::  set — they stay resolvable so a doc block on one reads as EXTRA
          ::  CREDIT, not gone; the ignore filter applies to the denominator.
          ;<  mv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| (coll-mirror c)]) ~)
          =/  finfo=(map @t (list @t))
            ?.  ?=([%ball *] mv)  ~
            %-  malt
            %+  murn  ~(tap ba:tarball ball.mv)
            |=  [=rail:tarball =sang:tarball]
            =/  src=@t  (spat (snoc path.rail name.rail))
            `[src (to-wain:format (sang-text sang))]
          ::  which enumerated files are ignored — excluded from the count but
          ::  still shown (as extra credit) when a doc block covers them.
          =/  ig-set=(set @t)
            (silt (skim ~(tap in ~(key by finfo)) |=(s=@t (ignored s ignore))))
          ::  gather anchors first — a section's scope, when not declared
          ::  explicitly, is DERIVED from them (the whole files this section's
          ::  own docs reference), so every section covers what it documents.
          ;<  anchors=(list [doc=@t file=@t from=@ud to=@ud])  bind:m
            (gather-all-anchors rail c)
          =/  scope-strs=(list @t)
            ?:(=('' sec) ~ (section-scope nav anchors sec))
          ::  when a section is active, the lines in scope per file — the "path
          ::  [range]" selectors resolved against the mirror. Denominator + cover
          ::  restrict to these; empty means the file isn't in the section.
          =/  scope-lines=(map @t (set @ud))
            ?.(in-section ~ (ref-lines finfo scope-strs))
          ::  ranged ignores: an ignore entry that carries a range (has a space)
          ::  excludes just those lines — a license header, a generated table —
          ::  rather than the whole file. Whole-file ignores stay prefix-matched
          ::  (ig-set above); these subtract lines from the denominator.
          =/  ignore-lines=(map @t (set @ud))
            (ref-lines finfo (skim ignore |=(e=@t !=(~ (find " " (trip e))))))
          ::  pins: the ship's own freshness store (mug per span, stamp-once)
          ;<  pj=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /docs %'pins.json']) ,json)
          =/  pins=(map @t json)  ?~(pj ~ ?:(?=([%o *] u.pj) p.u.pj ~))
          ::  fold the anchors into covered-line sets, per-file fresh/drift/gone
          ::  flags, and any new pins to stamp.
          =+  ^=  res
            =|  cov=(map @t (set @ud))
            =|  flg=(map @t [f=@ud d=@ud g=@ud])
            =|  np=(map @t @t)
            =|  ancs=(map @t (list json))
            |-  ^-  [(map @t (set @ud)) (map @t [f=@ud d=@ud g=@ud]) (map @t @t) (map @t (list json))]
            ?~  anchors  [cov flg np ancs]
            =/  a  i.anchors
            =/  fl=[f=@ud d=@ud g=@ud]  (fall (~(get by flg) file.a) [0 0 0])
            =/  al=(list json)  (fall (~(get by ancs) file.a) ~)
            =/  mka
              |=  st=@t
              ^-  json
              %-  pairs:enjs:format
              :~  ['doc' s+doc.a]
                  ['from' (numb:enjs:format from.a)]
                  ['to' (numb:enjs:format to.a)]
                  ['status' s+st]
              ==
            =/  ls=(unit (list @t))  (~(get by finfo) file.a)
            ?:  |(?=(~ ls) (gth from.a (lent u.ls)))
              %=  $
                anchors  t.anchors
                flg   (~(put by flg) file.a fl(g +(g.fl)))
                ancs  (~(put by ancs) file.a [(mka 'gone') al])
              ==
            =/  total=@ud  (lent u.ls)
            =/  hi=@ud  (min total ?:(=(0 to.a) total to.a))
            =/  s=(set @ud)  (fall (~(get by cov) file.a) ~)
            =.  s
              =/  ln=@ud  from.a
              |-  ^-  (set @ud)
              ?:  (gth ln hi)  s
              $(ln +(ln), s (~(put in s) ln))
            =/  span=(list @t)  (swag [(dec from.a) +((sub hi from.a))] u.ls)
            =/  hash=@t  `@t`(scot %ux (mug span))
            =/  rng=@t  ?:(=(0 to.a) 'all' (crip "{(a-co:co from.a)}-{(a-co:co to.a)}"))
            ::  pin key carries the collection, so one pins store holds every
            ::  collection's freshness without cross-contamination.
            =/  key=@t  (crip "{(spud c)}|{(trip doc.a)}|{(trip file.a)}|{(trip rng)}")
            =/  stored=(unit json)  (~(get by pins) key)
            =+  ^=  fps
              ?~  stored  [fl(f +(f.fl)) (~(put by np) key hash) 'fresh']
              ?:  =(hash ?:(?=([%s *] u.stored) p.u.stored ''))
                [fl(f +(f.fl)) np 'fresh']
              [fl(d +(d.fl)) np 'drifted']
            %=  $
              anchors  t.anchors
              cov   (~(put by cov) file.a s)
              flg   (~(put by flg) file.a -.fps)
              np    +<.fps
              ancs  (~(put by ancs) file.a [(mka +>.fps) al])
            ==
          =/  covered=(map @t (set @ud))  -.res
          =/  flags=(map @t [f=@ud d=@ud g=@ud])  +<.res
          =/  newpins=(map @t @t)  +>-.res
          =/  fancs=(map @t (list json))  +>+.res
          ::  section freshness: mug the whole scope's content and compare to its
          ::  pin (key "<c>|§<section>"). Stamp-once on first sight; a mismatch =
          ::  the section's code changed since vouched → a soft "re-audit" signal.
          =/  section-key=@t  ?:(in-section (crip "{(spud c)}|§{(trip sec)}") '')
          =/  section-mug=@t
            ?.(in-section '' (scot %ux (mug (scope-content finfo scope-lines))))
          =/  section-stored=(unit json)  ?:(in-section (~(get by pins) section-key) ~)
          =/  section-status=@t
            ?.  in-section  ''
            ?~  section-stored  'fresh'
            ?:  =(section-mug ?:(?=([%s *] u.section-stored) p.u.section-stored ''))
              'fresh'
            'drifted'
          =?  newpins  &(in-section ?=(~ section-stored))
            (~(put by newpins) section-key section-mug)
          ::  ship-side auto-pin: persist the freshly stamped spans
          ;<  ~  bind:m
            ?:  =(~ newpins)  (pure:(fiber:fiber:nexus ,~) ~)
            %+  over:io  (nex-road:io rail [%& /docs %'pins.json'])
            [[/ %json] [%o (~(uni by pins) (~(run by newpins) |=(h=@t `json`s+h)))]]
          ::  emit per-file coverage + freshness + covered ranges + anchors. An
          ::  ignored file appears only when a doc block covers it, flagged
          ::  extra (extra credit); an ignored, undocumented file is dropped.
          ::  in-scope lines for a file: the section's selected lines, or the
          ::  whole file when no section is active.
          =/  in-scope
            |=  [src=@t ls=(list @t)]
            ^-  (set @ud)
            =/  base=(set @ud)
              ?.  in-section
                =/  n=@ud  1
                =|  s=(set @ud)
                |-  ^-  (set @ud)
                ?:  (gth n (lent ls))  s
                $(n +(n), s (~(put in s) n))
              (fall (~(get by scope-lines) src) ~)
            (~(dif in base) (fall (~(get by ignore-lines) src) ~))
          =/  file-jsons=(list json)
            %+  murn  (sort ~(tap by finfo) |=([[a=@t *] [b=@t *]] (aor a b)))
            |=  [src=@t ls=(list @t)]
            ^-  (unit json)
            =/  sc=(set @ud)  (in-scope src ls)
            ?:  &(in-section =(~ sc))  ~   :: file not in this section
            =/  ig=?  (~(has in ig-set) src)
            =/  fl=[f=@ud d=@ud g=@ud]  (fall (~(get by flags) src) [0 0 0])
            =/  documented=?  |(!=(0 f.fl) !=(0 d.fl) !=(0 g.fl))
            ?:  &(ig !documented)  ~
            =/  cset=(set @ud)  (~(int in (fall (~(get by covered) src) ~)) sc)
            :-  ~
            %-  pairs:enjs:format
            :~  ['file' s+src]
                ['extra' [%b ig]]
                ['total' (numb:enjs:format ~(wyt in sc))]
                ['covered' (numb:enjs:format ~(wyt in cset))]
                ['fresh' (numb:enjs:format f.fl)]
                ['drifted' (numb:enjs:format d.fl)]
                ['gone' (numb:enjs:format g.fl)]
                :-  'ranges'
                :-  %a
                %+  turn  (ranges cset)
                |=([lo=@ud hi=@ud] `json`[%a ~[(numb:enjs:format lo) (numb:enjs:format hi)]])
                ['anchors' [%a (flop (fall (~(get by fancs) src) ~))]]
            ==
          ::  the denominator excludes ignored files (they are extra credit) and,
          ::  under a section, restricts to that section's scoped lines.
          =/  tot-lines=@ud
            %+  roll  ~(tap by finfo)
            |=  [[s=@t l=(list @t)] a=@ud]
            ?:  (~(has in ig-set) s)  a
            (add a ~(wyt in (in-scope s l)))
          =/  tot-cov=@ud
            %+  roll  ~(tap by covered)
            |=  [[s=@t c=(set @ud)] a=@ud]
            ?:  (~(has in ig-set) s)  a
            (add a ~(wyt in (~(int in c) (in-scope s (fall (~(get by finfo) s) ~)))))
          =/  tf=[f=@ud d=@ud g=@ud]
            %+  roll  ~(tap by flags)
            |=  [[s=@t x=[f=@ud d=@ud g=@ud]] a=[f=@ud d=@ud g=@ud]]
            ?:  &(in-section =(~ (fall (~(get by scope-lines) s) *(set @ud))))  a
            [(add f.x f.a) (add d.x d.a) (add g.x g.a)]
          =/  resp=json
            %-  pairs:enjs:format
            :~  ['files' [%a file-jsons]]
                ['totalLines' (numb:enjs:format tot-lines)]
                ['coveredLines' (numb:enjs:format tot-cov)]
                ['fresh' (numb:enjs:format f.tf)]
                ['drifted' (numb:enjs:format d.tf)]
                ['gone' (numb:enjs:format g.tf)]
                :-  'section'
                ?:  =('' sec)  ~
                (pairs:enjs:format ~[['name' s+sec] ['status' s+section-status]])
            ==
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html resp))])
          (pure:m ~)
        ::  /apps/grubbery/docs/mirror?path=/lib/x.hoon → the mirrored source
        ::  text of one file, so the heatmap reads locally (no per-block /code
        ::  fetch). Exactly what coverage measured.
        ?:  ?=([%docs %mirror ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          =/  qargs=quay:eyre  args:(parse-url:http-utils url.request.req)
          =/  pl  (skim qargs |=([p=@t q=@t] =(p 'path')))
          =/  src=@t  ?~(pl '' q.i.pl)
          =/  mir=path  (welp (coll-mirror c) (stab src))
          ;<  mv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& (snip mir) (rear mir)]) ~)
          =/  txt=@t  (grub-text mv)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html txt)])
          (pure:m ~)
        ::  /apps/grubbery/docs/targets.json → the coverage target list.
        ?:  ?=([%docs %'targets.json' ~] suffix)
          ;<  cur=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /docs %'targets.json']) ,json)
          =/  bod=octs  (as-octs:mimes:html (en:json:html (fall cur [%a ~])))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/docs/ignore.json → the coverage ignore list, READ-ONLY.
        ::  It's authored in the target's man/docs manifest (the desk owns its
        ::  exclusions), so the UI shows it but no longer edits it.
        ?:  ?=([%docs %'ignore.json' ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          ;<  [ignore=(list @t) *]  bind:m  (read-docs-config rail c)
          =/  bod=octs
            %-  as-octs:mimes:html
            %-  en:json:html
            [%a (turn ignore |=(s=@t `json`[%s s]))]
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/docs/search?q=<query> → server-side full-text
        ::  search over the /docs grubs. Returns hits (path+title+snippet);
        ::  the browser never loads the whole corpus, only what it clicks.
        ?:  ?=([%docs %search ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          =/  args=quay:eyre  args:(parse-url:http-utils url.request.req)
          =/  ql  (skim args |=([p=@t q=@t] =(p 'q')))
          =/  q=@t  ?~(ql '' q.i.ql)
          =/  qlow=tape  (cass (trip q))
          ?:  =(~ qlow)
            =/  bod=octs  (as-octs:mimes:html (en:json:html [%a ~]))
            ;<  ~  bind:m
              (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
            (pure:m ~)
          ;<  [* nav=json]  bind:m  (read-docs-config rail c)
          ;<  dc=path  bind:m  (docs-of rail c)
          =/  items=(list [path=@t title=@t])  (nav-items nav)
          =|  hits=(list json)
          |-  ^-  process:fiber:nexus
          ?~  items
            =/  bod=octs  (as-octs:mimes:html (en:json:html [%a (flop hits)]))
            ;<  ~  bind:m
              (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
            (pure:m ~)
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& (coll-docs c dc) `@ta`path.i.items]) ~)
          =/  txt=@t  (grub-text fv)
          =/  snip=(unit @t)  (find-snippet txt q)
          =/  tmatch=?  !=(~ (find qlow (cass (trip title.i.items))))
          =?  hits  |(?=(^ snip) tmatch)
            =/  s=@t  ?~(snip title.i.items u.snip)
            [(doc-hit path.i.items title.i.items s) hits]
          $(items t.items)
        ::  /apps/grubbery/docs/page?path=<name.md> → one doc's raw markdown
        ?:  ?=([%docs %page ~] suffix)
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          =/  args=quay:eyre  args:(parse-url:http-utils url.request.req)
          =/  pl  (skim args |=([p=@t q=@t] =(p 'path')))
          =/  pax=@t  ?~(pl '' q.i.pl)
          ?:  =('' pax)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'path required')])
            (pure:m ~)
          ::  prose lives in the collection's target: serve it straight from its
          ::  mirror handbook dir — the same source coverage measures. No seed
          ::  fallback; a page absent from the mirror is a real 404.
          ;<  dc=path  bind:m  (docs-of rail c)
          ;<  mv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& (coll-docs c dc) `@ta`pax]) ~)
          =/  mtxt=@t  (grub-text mv)
          ?:  =('' mtxt)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/plain']]] `(as-octs:mimes:html mtxt)])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/confirm?c=<collection>
        ::    {"blocks":[{"doc","file","range"},...]}
        ::  → re-confirm freshness. For each block the SHIP re-hashes the CURRENT
        ::  span from the collection's mirror and force-stamps its pin. The caller
        ::  supplies only intent (which blocks it verified); the ship supplies the
        ::  hash, so the browser never computes a mug. One block from the reader's
        ::  "re-confirm" button, or a batch from an LLM audit pass — same call.
        ?:  &(=('POST' method.request.req) ?=([%docs %confirm ~] suffix))
          ;<  c=path  bind:m  (coll-of rail url.request.req)
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  blocks=(list [doc=@t file=@t range=@t])
            ?.  ?=([%o *] jon)  ~
            =/  bl=(unit json)  (~(get by p.jon) 'blocks')
            ?.  ?=([~ %a *] bl)  ~
            %+  murn  p.u.bl
            |=  b=json
            ^-  (unit [@t @t @t])
            ?.  ?=([%o *] b)  ~
            =/  d=(unit json)  (~(get by p.b) 'doc')
            =/  f=(unit json)  (~(get by p.b) 'file')
            =/  r=(unit json)  (~(get by p.b) 'range')
            ?.  ?&(?=([~ %s *] d) ?=([~ %s *] f) ?=([~ %s *] r))  ~
            `[p.u.d p.u.f p.u.r]
          ::  read the collection's mirror (to hash spans) and the current pins
          ;<  mv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| (coll-mirror c)]) ~)
          =/  finfo=(map @t (list @t))
            ?.  ?=([%ball *] mv)  ~
            %-  malt
            %+  murn  ~(tap ba:tarball ball.mv)
            |=  [=rail:tarball =sang:tarball]
            `[(spat (snoc path.rail name.rail)) (to-wain:format (sang-text sang))]
          ;<  pj=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /docs %'pins.json']) ,json)
          =/  pins=(map @t json)  ?~(pj ~ ?:(?=([%o *] u.pj) p.u.pj ~))
          ::  sections to re-confirm (by name) — each scope is read from the
          ::  manifest nav (or derived from its docs), re-hashed and re-pinned.
          ;<  [* nav=json]  bind:m  (read-docs-config rail c)
          ;<  anchors=(list [doc=@t file=@t from=@ud to=@ud])  bind:m
            (gather-all-anchors rail c)
          =/  sections=(list @t)
            ?.  ?=([%o *] jon)  ~
            =/  sl=(unit json)  (~(get by p.jon) 'sections')
            ?.  ?=([~ %a *] sl)  ~
            (murn p.u.sl |=(x=json ?:(?=([%s *] x) `p.x ~)))
          =/  block-updates=(map @t json)
            %+  roll  blocks
            |=  [b=[doc=@t file=@t range=@t] acc=(map @t json)]
            =/  ls=(unit (list @t))  (~(get by finfo) file.b)
            ?~  ls  acc
            =/  rng=[from=@ud to=@ud]
              ?:  =('all' range.b)  [1 0]
              =/  dh=(unit @ud)  (find "-" (trip range.b))
              ?~  dh  [(fall (rush range.b dem) 1) (fall (rush range.b dem) 1)]
              :-  (fall (rush (crip (scag u.dh (trip range.b))) dem) 1)
              (fall (rush (crip (slag +(u.dh) (trip range.b))) dem) 0)
            =/  total=@ud  (lent u.ls)
            ?:  (gth from.rng total)  acc
            =/  hi=@ud  (min total ?:(=(0 to.rng) total to.rng))
            =/  span=(list @t)  (swag [(dec from.rng) +((sub hi from.rng))] u.ls)
            =/  key=@t  (crip "{(spud c)}|{(trip doc.b)}|{(trip file.b)}|{(trip range.b)}")
            (~(put by acc) key s+`@t`(scot %ux (mug span)))
          =/  updated=(map @t json)
            %+  roll  sections
            |=  [name=@t acc=(map @t json)]
            =/  strs=(list @t)  (section-scope nav anchors name)
            ?~  strs  acc
            =/  mg=@t  (scot %ux (mug (scope-content finfo (ref-lines finfo strs))))
            (~(put by acc) (crip "{(spud c)}|§{(trip name)}") s+mg)
          =.  updated  (~(uni by updated) block-updates)
          ;<  ~  bind:m
            ?:  =(~ updated)  (pure:(fiber:fiber:nexus ,~) ~)
            (over:io (nex-road:io rail [%& /docs %'pins.json']) [[/ %json] [%o (~(uni by pins) updated)]])
          =/  bod=octs
            %-  as-octs:mimes:html
            %-  en:json:html
            (pairs:enjs:format ~[['confirmed' (numb:enjs:format ~(wyt by updated))]])
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  POST /apps/grubbery/docs/targets  [{"path","docs"}, ...] → replace
        ::  the registry with the posted json array. Each entry names a target and
        ::  its handbook subpath (see +targ-list); stored verbatim, legacy bare
        ::  strings tolerated on read.
        ?:  &(=('POST' method.request.req) ?=([%docs %targets ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) [%a ~])
          ;<  ~  bind:m
            (over:io (nex-road:io rail [%& /docs %'targets.json']) [[/ %json] jon])
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html [%b %.y]))])
          (pure:m ~)
        ::  (no POST /ignore — ignore is authored in the target's man/docs
        ::  manifest, not editable through the shell.)
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
        ::  straight from the agent's chats/main.json. Restores across refreshes.
        ?:  ?=([%docs %history ~] suffix)
          =/  chat-road=road:tarball
            (nex-road:io rail [%& /docs/agent/chats %'main.json'])
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
::  coll-of: the collection a request is scoped to — the `c` query param (a
::  target path). Absent, we fall back to the first registered collection, so
::  a bare request still resolves the default.
++  coll-of
  |=  [=rail:tarball url=@t]
  =/  m  (fiber:fiber:nexus ,path)
  ^-  form:m
  =/  qa=quay:eyre  args:(parse-url:http-utils url)
  =/  cl  (skim qa |=([p=@t q=@t] =(p 'c')))
  ?^  cl  (pure:m (stab q.i.cl))
  ;<  tg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /docs %'targets.json']) ,json)
  =/  ts=(list [t=@t docs=path])  (targ-list tg)
  (pure:m ?~(ts ~ (stab t.i.ts)))
::  docs-of: a collection's handbook subpath within its target, from the registry.
::  Defaults to /man/docs when the target isn't found or names no docs path — the
::  same default +targ-list applies to a legacy bare-string entry.
++  docs-of
  |=  [=rail:tarball c=path]
  =/  m  (fiber:fiber:nexus ,path)
  ^-  form:m
  ;<  tg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /docs %'targets.json']) ,json)
  =/  ts=(list [t=@t docs=path])  (targ-list tg)
  =/  hit  (skim ts |=([t=@t *] =((stab t) c)))
  (pure:m ?~(hit /man/docs docs.i.hit))
::  read-docs-config: a collection's handbook manifest, read from its mirror's
::  man/docs/docs.json — {ignore, nav}. Config lives WITH the documented target
::  (the desk owns its coverage exclusions and its sidebar shape), not in the
::  shell. Empty when the manifest isn't mirrored yet.
++  read-docs-config
  |=  [=rail:tarball c=path]
  =/  m  (fiber:fiber:nexus ,[ignore=(list @t) nav=json])
  ^-  form:m
  ::  the manifest is a %json grub in the mirror — clam it to json directly,
  ::  not through grub-text (which extracts source TEXT, not a json noun).
  ;<  dc=path  bind:m  (docs-of rail c)
  ;<  ju=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& (coll-docs c dc) %'docs.json']) ,json)
  =/  obj=(map @t json)  ?~(ju ~ ?:(?=([%o *] u.ju) p.u.ju ~))
  =/  nav=json  (fall (~(get by obj) 'nav') [%a ~])
  (pure:m [(json-strs (~(get by obj) 'ignore')) nav])
::  nav-items: the flat [path title] of every doc in a nav tree, walking the
::  {title,path} / {title,kids} json. Arbitrary depth, over json's recursion.
++  nav-items
  |=  nav=json
  ^-  (list [path=@t title=@t])
  |^  (walk nav)
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
::  nav-scope: the `scope` selectors of the nav section titled `name` — a list
::  of "path [range]" strings defining a sub-coverage. ~ if no such section or
::  it declares no scope (then coverage falls back to the whole collection).
++  nav-scope
  |=  [nav=json name=@t]
  ^-  (list @t)
  |^  (find nav)
  ++  find
    |=  j=json
    ^-  (list @t)
    ?.  ?=([%a *] j)  ~
    |-  ^-  (list @t)
    ?~  p.j  ~
    =/  got=(list @t)  (node i.p.j)
    ?^(got got $(p.j t.p.j))
  ++  node
    |=  nd=json
    ^-  (list @t)
    ?.  ?=([%o *] nd)  ~
    =/  ttl  (~(get by p.nd) 'title')
    ?:  ?&(?=([~ %s *] ttl) =(name p.u.ttl))
      (json-strs (~(get by p.nd) 'scope'))
    =/  kids  (~(get by p.nd) 'kids')
    ?~(kids ~ (find u.kids))
  --
::  nav-section-docs: every doc path under the nav section titled `name` — used
::  to DERIVE a section's coverage scope (the whole files its docs reference)
::  when it declares no explicit scope. So every section gets coverage of the
::  code it documents, for free.
++  nav-section-docs
  |=  [nav=json name=@t]
  ^-  (set @t)
  =<  (silt (walk nav %.n))
  |%
  ++  walk
    |=  [j=json in=?]
    ^-  (list @t)
    ?.  ?=([%a *] j)  ~
    %-  zing
    %+  turn  p.j
    |=  nd=json
    ^-  (list @t)
    ?.  ?=([%o *] nd)  ~
    =/  ttl  (~(get by p.nd) 'title')
    =/  here=?  |(in ?&(?=([~ %s *] ttl) =(name p.u.ttl)))
    =/  pax  (~(get by p.nd) 'path')
    =/  self=(list @t)  ?:(?&(here ?=([~ %s *] pax)) ~[p.u.pax] ~)
    =/  kids  (~(get by p.nd) 'kids')
    (weld self ?~(kids ~ (walk u.kids here)))
  --
::  section-scope: a section's coverage scope — its declared `scope` selectors,
::  or (when none) the whole files its own docs reference, derived from anchors.
++  section-scope
  |=  [nav=json anchors=(list [doc=@t file=@t from=@ud to=@ud]) name=@t]
  ^-  (list @t)
  =/  explicit=(list @t)  (nav-scope nav name)
  ?^  explicit  explicit
  =/  sec-docs=(set @t)  (nav-section-docs nav name)
  %~  tap  in
  %-  silt
  %+  murn  anchors
  |=  a=[doc=@t file=@t from=@ud to=@ud]
  ?:((~(has in sec-docs) doc.a) `file.a ~)
::  docs-in-node: every doc path beneath one nav node (a leaf is itself).
++  docs-in-node
  |=  nd=json
  ^-  (list @t)
  ?.  ?=([%o *] nd)  ~
  =/  pax  (~(get by p.nd) 'path')
  ?:  ?=([~ %s *] pax)  ~[p.u.pax]
  =/  kids  (~(get by p.nd) 'kids')
  ?~  kids  ~
  ?.  ?=([%a *] u.kids)  ~
  (zing (turn p.u.kids docs-in-node))
::  annotate-nav: tag each section with `cov` — whether it has any coverage to
::  show (a declared scope, or docs that reference code). The reader shows a ◆
::  handle only where cov is true, at any depth.
++  annotate-nav
  |=  [nav=json anchored=(set @t)]
  ^-  json
  ?.  ?=([%a *] nav)  nav
  :-  %a
  %+  turn  p.nav
  |=  nd=json
  ^-  json
  ?.  ?=([%o *] nd)  nd
  ?:  ?=([~ %s *] (~(get by p.nd) 'path'))  nd
  =/  kids  (~(get by p.nd) 'kids')
  =/  po=(map @t json)
    ?~(kids p.nd (~(put by p.nd) 'kids' (annotate-nav u.kids anchored)))
  =/  has-scope=?  ?=(^ (~(get by po) 'scope'))
  =/  has-anc=?  (lien (docs-in-node nd) |=(d=@t (~(has in anchored) d)))
  [%o (~(put by po) 'cov' [%b |(has-scope has-anc)])]
::  ref-lines: resolve a list of "path [range]" selectors against the mirror
::  line map into per-file line sets — the shared primitive for section scopes
::  and ranged ignores. A bare path (no range) selects the whole file.
++  ref-lines
  |=  [finfo=(map @t (list @t)) refs=(list @t)]
  ^-  (map @t (set @ud))
  %+  roll  refs
  |=  [ss=@t acc=(map @t (set @ud))]
  =/  ref=(unit [file=@t from=@ud to=@ud])  (parse-ref (trip ss))
  ?~  ref  acc
  =/  ls=(unit (list @t))  (~(get by finfo) file.u.ref)
  ?~  ls  acc
  =/  total=@ud  (lent u.ls)
  =/  hi=@ud  (min total ?:(=(0 to.u.ref) total to.u.ref))
  =/  lset=(set @ud)
    =/  n=@ud  from.u.ref
    =|  s=(set @ud)
    |-  ^-  (set @ud)
    ?:  (gth n hi)  s
    $(n +(n), s (~(put in s) n))
  (~(put by acc) file.u.ref (~(uni in (fall (~(get by acc) file.u.ref) ~)) lset))
::  scope-content: the concatenated text of a section's in-scope lines (files
::  sorted, lines in order) — the thing we mug for a section's freshness. A
::  whole-file scope mugs the whole file, so any edit to it drifts the section.
++  scope-content
  |=  [finfo=(map @t (list @t)) scope-lines=(map @t (set @ud))]
  ^-  @t
  %-  crip  %-  zing
  %+  turn  (sort ~(tap by scope-lines) |=([[a=@t *] [b=@t *]] (aor a b)))
  |=  [file=@t lset=(set @ud)]
  =/  ls=(list @t)  (fall (~(get by finfo) file) ~)
  =/  i=@ud  0
  =|  out=(list tape)
  |-  ^-  tape
  ?~  ls  (zing (flop out))
  =/  n=@ud  +(i)
  ?:  (~(has in lset) n)
    $(ls t.ls, i n, out ["{(trip i.ls)}\0a" out])
  $(ls t.ls, i n)
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
::  agent-weir: THE SANDBOX. The complete external reach we grant the
::  docs-agent when we mount it — the kernel refuses everything else.
::  Files (sigs) are granted as rails; directories as folds. make stays
::  empty: writing its own subtree (chats) is inherent, and it writes
::  nothing outside itself.
::
::  The agent sees ONLY the docs subtree — nothing external. That subtree holds
::  everything it needs: the local mirror (/docs/mirror, a copy of every
::  documented target's source AND handbook), the registry (targets.json), and
::  its own chats. No /code or raw-desk grant: the mirror already contains that
::  source, so the sandbox stays the docs' own data.
::    peek: /docs (mirror + registry + own subtree), proxy calls
::    poke: bowl.sig (time + entropy), the proxy's main.sig
++  agent-weir
  ^-  weir:tarball
  =/  dir  |=(p=path `road:tarball`[%& %| p])
  =/  fil  |=([p=path n=@ta] `road:tarball`[%& %& p n])
  :*  make=~
      poke=(sy ~[(fil /sys 'bowl.sig') (fil /apps/'anthropic.anthropic' 'main.sig')])
      %-  sy
      :~  (dir /apps/'shell.shell'/docs)
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
    (nex-road:io rail [%& /docs/agent/chats %'main.json'])
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
::  (the docs chat loop that used to live here moved into the sandboxed
::  docs-agent nexus, now built on lib/clanker)
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
  =/  desk-dir=path  /apps/'shell.shell'/desks/[(cat 3 `@ta`name '.desk')]
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
      (make:io [%& %| repo-dir] &+`bole:tarball`[`[`[/git %repo] ~ %.n ~] ~])
    ::  ensure the repo's remote matches the stock entry — an existing repo
    ::  may have been made empty or misconfigured (repo:""), so set config
    ::  whenever it differs from intended, not only on first make, else the
    ::  pull below has no github remote to follow. write only on a real
    ::  difference, so a correct repo isn't clobbered (and its config fiber
    ::  needlessly restarted) on every sync.
    ;<  cur=(unit json)  bind:m
      (peek-as:io [%& %& repo-dir %'config.json'] ,json)
    =/  cur-obj=(map @t json)
      ?~(cur ~ ?:(?=([%o *] u.cur) p.u.cur ~))
    =/  cur-repo=@t
      =/(v (~(get by cur-obj) 'repo') ?:(?=([~ %s *] v) p.u.v ''))
    =/  cur-ref=@t
      =/(v (~(get by cur-obj) 'ref') ?:(?=([~ %s *] v) p.u.v ''))
    ;<  ~  bind:m
      ?:  &(=(cur-repo repo.entry) =(cur-ref ref.entry))  (pure:m ~)
      ::  config.json is a plain data grub (no poke handler), so overwrite
      ::  it with over:io — poke:io would nack and crash this handler.
      (over:io [%& %& repo-dir %'config.json'] [[/ %json] (repo-config repo.entry ref.entry)])
    ::  a pull on the run.git-action serial lane forces a re-fetch now, so
    ::  "sync" always means "pull latest".
    %+  poke:io  [%& %& repo-dir %'run.git-action']
    [[/ %json] (pairs:enjs:format ~[['command' s+'pull']])]
  ::  2. ensure the desk
  ;<  has-desk=?  bind:m  (peek-exists:io [%& %| desk-dir])
  ;<  ~  bind:m
    ?:  has-desk  (pure:m ~)
    (make:io [%& %| desk-dir] &+`bole:tarball`[`[`[/ %desk] ~ %.n ~] ~])
  ::  3. always wire the desk's source at the computed code path
  (poke:io [%& %& desk-dir %'source.json'] [[/ %json] (pairs:enjs:format ~[['code' s+code]])])
::  find-stock: the default-repos entry whose name matches, if any.
::
++  find-stock
  |=  nom=@t
  ^-  (unit stock-entry)
  =/  todo=(list stock-entry)  default-repos
  |-  ^-  (unit stock-entry)
  ?~  todo  ~
  ?:  =(nom (stock-name i.todo))  `i.todo
  $(todo t.todo)
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
  =/  desk-dir=path  /apps/'shell.shell'/desks/[(cat 3 `@ta`name '.desk')]
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
  ;<  =view:nexus  bind:m
    (peek-shallow:io [%& %| /apps/'shell.shell'/desks] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  kids=(list @ta)  ~(tap in ~(key by dir.ball.view))
  =|  acc=(map @t @t)
  |-
  ?~  kids  (pure:m acc)
  ;<  src=(unit json)  bind:m
    (peek-as:io [%& %& /apps/'shell.shell'/desks/[i.kids] %'source.json'] ,json)
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
::  +discover-desks: every local desk instance with its source and a link
::  to its own page — the shell's desk launcher (config/publish live there).
::
++  discover-desks
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io [%& %| /apps/'shell.shell'/desks] ~)
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
  ;<  sj=(unit json)  bind:m
    (peek-as:io [%& %& /apps/'shell.shell'/desks/[app] %'source.json'] ,json)
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
::  the directory. App options are derived from link.json, so they can't
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
::  path -> set of /sys/link dest.lanes roads it may peek.
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
  ::  /apps/shell.shell/desks/<desk>/desk/data/<app> -> "<desk>/<app>".
  =/  nm=@t
    ?:  ?=([%apps %'shell.shell' %desks @ %desk %data @ ~] pax)
      (rap 3 (app-slug i.t.t.t.pax) '/' (app-slug i.t.t.t.t.t.t.pax) ~)
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
::  +read-app-aliases: scan /apps for each app's self-declared link.json
::  ({name, description}) and build the app-sourced half of the alias
::  directory: @name -> list of option json {path, description, source}.
::  Derived — rescanned on read, never stored. A name grants no power, so
::  declaring one needs no consent; it just appears as a menu option.
::
++  app-roots
  =/  m  (fiber:fiber:nexus ,(list path))
  ^-  form:m
  ::  built-in apps: every direct child of /apps (no neck check needed)
  ;<  av=view:nexus  bind:m  (peek-shallow:io [%& %| /apps] ~)
  =/  builtins=(list path)
    ?.  ?=([%ball *] av)  ~
    (turn ~(tap in ~(key by dir.ball.av)) |=(k=@ta /apps/[k]))
  ::  desk apps: each child of /desks is a desk wrapper; its real apps
  ::  are the children of /desk/data (what apply-bill creates).
  ;<  dv=view:nexus  bind:m
    (peek-shallow:io [%& %| /apps/'shell.shell'/desks] ~)
  ?.  ?=([%ball *] dv)  (pure:m builtins)
  =/  desks=(list @ta)  ~(tap in ~(key by dir.ball.dv))
  =|  out=(list path)
  |-  ^-  form:m
  ?~  desks  (pure:m (weld builtins (flop out)))
  ;<  sv=view:nexus  bind:m
    (peek-shallow:io [%& %| /apps/'shell.shell'/desks/[i.desks]/desk/data] ~)
  =/  subs=(list path)
    ?.  ?=([%ball *] sv)  ~
    %+  turn  ~(tap in ~(key by dir.ball.sv))
    |=(sub=@ta /apps/'shell.shell'/desks/[i.desks]/desk/data/[sub])
  $(desks t.desks, out (weld subs out))
::  +read-app-aliases: scan every app root (descending desks) for its
::  link.json, building @name -> menu options. Each root is a nexus; its
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
    (peek:io [%& %& [root %'link.json']] `[/ %json])
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
::  and splits on / to build the path — '@pad' -> /sys/link/pad/dest.lanes,
::  '@chat/v1' -> /sys/link/chat/v1/dest.lanes.
::
++  link-road
  |=  nm=@t
  ^-  road:tarball
  [%& %& (link-dir nm) %'dest.lanes']
::  +link-dir: the /sys/link directory path for an @alias (for shallow
::  listing during cull).
::
++  link-dir
  |=  nm=@t
  ^-  path
  =/  bare=tape  ?~((trip nm) ~ (slag 1 (trip nm)))
  (weld /sys/link (stab (crip (weld "/" bare))))
::  +json-strs: the string elements of a (unit json) array, in order.
::
++  json-strs
  |=  j=(unit json)
  ^-  (list @t)
  ?~  j  ~
  ?.  ?=([%a *] u.j)  ~
  (murn p.u.j |=(x=json ?:(?=([%s *] x) `p.x ~)))
::  +targ-list: parse targets.json into [target-string, docs-subpath] pairs. Each
::  entry is an object {"path","docs"}: path = the target we mirror, docs = where
::  the handbook (docs.json + .md) lives within it. docs omitted defaults to
::  /man/docs; grubbery's entry sets /gub/man/docs (its manuals live under gub/).
++  targ-list
  |=  j=(unit json)
  ^-  (list [t=@t docs=path])
  ?~  j  ~
  ?.  ?=([%a *] u.j)  ~
  %+  murn  p.u.j
  |=  x=json
  ^-  (unit [t=@t docs=path])
  ?.  ?=([%o *] x)  ~
  =/  pt  (~(get by p.x) 'path')
  ?~  pt  ~
  ?.  ?=([%s *] u.pt)  ~
  =/  dc  (~(get by p.x) 'docs')
  =/  docs=path
    ?~  dc  /man/docs
    ?.(?=([%s *] u.dc) /man/docs (stab p.u.dc))
  `[p.u.pt docs]
::  +target-path: a configured target string to the namespace path it names.
::  Targets are namespace directories we subscribe to and mirror (ignore, by
::  contrast, is mirror-relative and never passes through here). A path rooted
::  at a known namespace top (/code, /sys, /apps, /docs) is taken as-is — so a
::  target can point at the raw grubbery desk source under /sys/clay/desks/
::  grubbery, not just /code. Anything else is /code-relative (a bare "/lib/..."
::  means "/code/lib/...").
::
++  target-path
  |=  t=@t
  ^-  path
  =/  p=path  (stab t)
  ?~  p  p
  ?:  ?=(?(%code %sys %apps %docs) i.p)  p
  [%code p]
::  +mirror-mount: the /docs/mirror path a target directory mounts at —
::  /docs/mirror ++ its own full path, so collections never collide and a request
::  scopes by /docs/mirror ++ c. The full path is kept (not stripped) precisely so
::  distinct targets stay distinct; anchor paths are correspondingly target-rooted.
::  The mirror lives under /docs so the whole docs subsystem is one subtree.
++  mirror-mount
  |=  code=path
  ^-  path
  (welp /docs/mirror code)
::  +coll-mirror: the mirror subtree of one collection (its target path).
++  coll-mirror
  |=  c=path
  ^-  path
  (welp /docs/mirror c)
::  +coll-docs: a collection's handbook directory in the mirror. The handbook's
::  location WITHIN the target is target-specific — man/docs is a grubbery-relative
::  convention (each nexus's manuals live under gub/…/man/), so grubbery's handbook
::  is at gub/man/docs, while a bare Clay desk has no such convention. So dc (the
::  docs subpath) is carried per-target in the registry and resolved by +docs-of;
::  this gate just joins it onto the mirror. dc is target-relative.
++  coll-docs
  |=  [c=path dc=path]
  ^-  path
  (welp /docs/mirror (welp c dc))
::  +mirror-dir: mirror one target directory subtree into our own /docs/mirror
::  in a single event — a deep peek of the whole subtree as a ball,
::  written back with over-fold (the %over analog for directories). The
::  namespace's own copy-a-directory primitive; no per-file walk. The mirror
::  is a faithful grub copy; what counts toward coverage (ignore) is applied
::  later, at compute time.
::
++  mirror-dir
  |=  [=rail:tarball code=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| code] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  mir=path  (mirror-mount code)
  =/  bol=bole:tarball  (ball-to-bole:tarball ball.view)
  ::  preserve the dest dir's own neck (what on-load established) so the
  ::  overwrite doesn't strip it — the same care sync-dir takes in nex/desk.
  ;<  cur=view:nexus  bind:m  (peek:io (nex-road:io rail [%| mir]) ~)
  =/  nek  ?.(?=([%ball *] cur) ~ ?~(fil.ball.cur ~ neck.u.fil.ball.cur))
  =/  root=pulp:tarball  (fall fil.bol `pulp:tarball`[~ ~ %.n ~])
  =.  bol  bol(fil `root(neck nek))
  (over-fold:io (nex-road:io rail [%| mir]) bol)
::  +triml: drop leading spaces from a tape.
::
++  triml
  |=  t=tape
  ^-  tape
  ?~  t  t
  ?:  =(' ' i.t)  $(t t.t)
  t
::  +parse-ref: one live-block ref line -> [file from to]. "path a-b" is a
::  line range; "path" alone is the whole file (to=0 sentinel). ~ if unparsable.
::
++  parse-ref
  |=  ln=tape
  ^-  (unit [file=@t from=@ud to=@ud])
  =/  t=tape  (triml ln)
  ?~  t  ~
  =/  full=tape  t
  =/  sp=(unit @ud)  (find " " full)
  ?~  sp
    `[(crip full) 1 0]
  =/  file=@t   (crip (scag u.sp full))
  =/  rest=tape  (triml (slag +(u.sp) full))
  =/  dash=(unit @ud)  (find "-" rest)
  ?~  dash
    =/  n=(unit @ud)  (rush (crip rest) dem)
    ?~(n `[file 1 0] `[file u.n u.n])
  =/  from=(unit @ud)  (rush (crip (scag u.dash rest)) dem)
  =/  to=(unit @ud)    (rush (crip (slag +(u.dash) rest)) dem)
  ?:  |(?=(~ from) ?=(~ to))  ~
  `[file u.from u.to]
::  +parse-anchors: the live-block anchors in one doc's markdown — each a
::  ` ```live ` fence whose body is "path range". Returns [file from to] list.
::
++  parse-anchors
  |=  md=@t
  ^-  (list [file=@t from=@ud to=@ud])
  =/  lines=(list tape)  (turn (to-wain:format md) trip)
  =|  out=(list [@t @ud @ud])
  =/  live=?  %.n
  |-  ^-  (list [@t @ud @ud])
  ?~  lines  (flop out)
  =/  ln=tape  (triml i.lines)
  ?:  live
    ?:  =("```" (scag 3 ln))  $(lines t.lines, live |)
    =/  a=(unit [@t @ud @ud])  (parse-ref ln)
    ?~  a  $(lines t.lines, live |)
    $(lines t.lines, out [u.a out], live |)
  ?:  =("```live" (scag 7 ln))  $(lines t.lines, live &)
  $(lines t.lines)
::  +gather-all-anchors: every live-block anchor across all docs, tagged with
::  its doc. Reads each /docs grub, parses its fences.
::
++  gather-all-anchors
  |=  [=rail:tarball c=path]
  =/  m  (fiber:fiber:nexus ,(list [doc=@t file=@t from=@ud to=@ud]))
  ^-  form:m
  ;<  [* nav=json]  bind:m  (read-docs-config rail c)
  ;<  dc=path  bind:m  (docs-of rail c)
  =/  items=(list [path=@t title=@t])  (nav-items nav)
  =|  all=(list [@t @t @ud @ud])
  |-  ^-  form:m
  ?~  items  (pure:m (flop all))
  ;<  fv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& (coll-docs c dc) `@ta`path.i.items]) ~)
  =/  txt=@t  (grub-text fv)
  =.  all
    %+  weld  all
    %+  turn  (parse-anchors txt)
    |=([file=@t from=@ud to=@ud] [path.i.items file from to])
  $(items t.items)
::  +ranges: a set of line numbers as a compact list of contiguous [lo hi]
::  runs, for painting the heatmap without shipping every line number.
::
++  ranges
  |=  s=(set @ud)
  ^-  (list [@ud @ud])
  =/  ns=(list @ud)  (sort ~(tap in s) lth)
  ?~  ns  ~
  =/  lo=@ud  i.ns
  =/  hi=@ud  i.ns
  =/  rest  t.ns
  =|  out=(list [@ud @ud])
  |-  ^-  (list [@ud @ud])
  ?~  rest  (flop [[lo hi] out])
  ?:  =(i.rest +(hi))  $(hi i.rest, rest t.rest)
  $(out [[lo hi] out], lo i.rest, hi i.rest, rest t.rest)
::  +ignored: is a source path excluded by the ignore list (itself or under
::  an ignored directory)?
::
++  ignored
  |=  [src=@t ign=(list @t)]
  ^-  ?
  %+  lien  ign
  |=  ip=@t
  =/  ipt=tape  (trip ip)
  =(ip (crip (scag (lent ipt) (trip src))))
::  +grub-text: raw text of a source grub view. A .hoon/.js/.css grub holds
::  its source in the vase as a @t; %txt is a wain; %mime carries octs.
::  Empty for a boom or a shape we can't read.
::
++  grub-text
  |=  =view:nexus
  ^-  @t
  ?.  ?=([%file *] view)  ''
  (sang-text sang.view)
::  +sang-text: the raw text of a grub's sang directly (for enumerating a
::  mirrored ball, where we hold the sang, not a file view).
::
++  sang-text
  |=  =sang:tarball
  ^-  @t
  ?:  ?=(%| -.q.sang)  ''
  =/  =sage:tarball  (need-sage:tarball sang)
  =/  mk=@tas  name.p.sage
  ?:  =(%txt mk)   (of-wain:format !<(wain q.sage))
  ?:  =(%md mk)    (of-wain:format !<(wain q.sage))
  ?:  =(%mime mk)  `@t`q.q:!<(mime q.sage)
  (fall (mole |.(!<(@t q.sage))) '')
::  +spawn-followers: ensure a /sync/<app> follower grub exists for every
::  top-level app in /apps. Making the grub starts its follower fiber (the
::  [[%sync ~] @] case). Idempotent — skips ones already present. (Culling
::  removed apps' followers + descending into desks are later increments.)
::
::  +sync-lane: the /sync grub lane for an app-root path. Built-in apps
::  at /apps/<name> mirror as /sync/<name>; desk sub-apps at
::  /apps/shell.shell/desks/<desk>/desk/data/<sub> mirror as
::  /sync/<desk>/<sub>. ~ for anything unrecognized.
::
++  sync-lane
  |=  ap=path
  ^-  (unit lane:tarball)
  ?+  ap  ~
    [%apps @ ~]
      `[%& [/sync i.t.ap]]
    [%apps %'shell.shell' %desks @ %desk %data @ ~]
      `[%& [/sync/[i.t.t.t.ap] i.t.t.t.t.t.t.ap]]
  ==
::  +app-path-of: inverse — the app-root path a /sync follower watches,
::  from the follower's own rail.
::
++  app-path-of
  |=  =rail:tarball
  ^-  (unit path)
  ?+  path.rail  ~
    [%sync ~]
      `~[%apps name.rail]
    [%sync @ ~]
      `~[%apps %'shell.shell' %desks i.t.path.rail %desk %data name.rail]
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
::  each @name, write /sys/link/<segments>/dest.lanes — a (set lane:tarball)
::  of target locations. Only writes on genuine content change.
::
::  INVARIANT: /sys/link MUST always be current.
::
::  TODO (not built yet): drive this by SUBSCRIPTION, never a poll.
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
  ;<  =view:nexus  bind:m
    (peek-shallow:io [%& %| /apps/'shell.shell'/desks] ~)
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
    (peek-as:io [%& %& /apps/'shell.shell'/desks/[i.kids] %'share.usergroups'] ,(set path))
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
      ['code' s+(crip "/apps/shell.shell/desks/{(trip name)}/desk/code")]
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
    ::  cull pass: drop /sys/link dirs whose link no longer has any claimant
    ;<  bv=view:nexus  bind:m  (peek-shallow:io [%& %| /sys/link] ~)
    ?.  ?=([%ball *] bv)  (pure:m ~)
    =/  haves=(list @ta)  ~(tap in ~(key by dir.ball.bv))
    |-  ^-  form:m
    ?~  haves  (pure:m ~)
    ?:  (~(has in want) /sys/link/[i.haves])  $(haves t.haves)
    ;<  *  bind:m  (cull-soft:io [%& %| /sys/link/[i.haves]])
    $(haves t.haves)
  =/  road=road:tarball  (link-road nm.i.entries)
  =/  lanes=(set lane:tarball)
    %-  silt
    %+  murn  opts.i.entries
    |=  o=json
    =/  p=@t  (fall (jget o 'path') '')
    ?:(=('' p) ~ `[%| (stab p)])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %lanes])
  =/  have=(unit (set lane:tarball))
    ?.  ?=([%file *] cur)  ~
    (mole |.(!<((set lane:tarball) (need-vase:tarball sang.cur))))
  ?:  =(`lanes have)  $(entries t.entries)
  ;<  ~  bind:m  (over:io road [[/ %lanes] lanes])
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
        ::  boilerplate (/apps/<name> or /desks/<desk>/desk/data/<name>).
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
