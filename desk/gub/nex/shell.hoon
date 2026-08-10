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
          ::  /book: the discovery registry. One grub per @alias holding the
          ::  current claimants and their locations — the alias menu made
          ::  materialized-and-subscribable, so peers (local or cross-ship)
          ::  can `keep` a name and learn where its app lives, and get pushed
          ::  the new location when it moves.
          [%fall %| /book empty-dir:loader]
          ::  sweep.sig: poke target for "new apps may exist — look now".
          ::  Desk installs poke it after applying their bill, so fresh
          ::  apps get followers (and their rise-notify) immediately
          ::  instead of waiting for a permits page load.
          [%fall %& [/ %'sweep.sig'] [[/ %sig] ~]]
          ::  /book/main.sig: the discovery-grant fiber. Owns the registry
          ::  grants for /book files (it sits at /book, so they're in its
          ::  subtree), recomputed from permit/share.json by subscription.

          ::  /sync: one pure-follower grub per app, mirroring /apps. Each
          ::  follows its app's files by subscription and pings the scanner
          ::  to reconcile — so /book (and the asks) stay current without a
          ::  poll. /sync/main.sig is the coordinator: it watches /apps
          ::  membership and spawns/keeps the followers.
          [%fall %| /sync empty-dir:loader]
          [%fall %| /peers empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] app-css]]
          [%over %& [/ %'permits.html'] [[/ %mime] permits-html]]
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
          ::  per-group /book shares from permit/share.json — and keep
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
        ;<  shares=(map path (set @ta))  bind:m  (read-shares rail nex-dir)
        ::  one %how per group, total-state: base grant + that group's book
        ::  shares. /public always recomputes (the base grant rides it);
        ::  prev keeps un-shared groups in the set once more to clear them.
        =/  groups=(list path)
          ~(tap in (~(put in (~(uni in prev) ~(key by shares))) /public))
        ;<  ~  bind:m
          =/  m  (fiber:fiber:nexus ,~)
          |-  ^-  form:m
          ?~  groups  (pure:m ~)
          =/  grp=path  i.groups
          =/  files=(set @ta)  (fall (~(get by shares) grp) ~)
          =/  base=(set road:tarball)
            ?.  =(/public grp)  ~
            (sy `(list road:tarball)`~[[%& %& nex-dir %'public.json']])
          =/  peeks=(set road:tarball)
            %-  ~(gas in base)
            (turn ~(tap in files) |=(f=@ta `road:tarball`[%& %& (weld nex-dir /book) f]))
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
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-book rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
          (build-weirs rail)
        $
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
          ::  reconcile /book and the asks. Holds no state, writes nothing.
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
          ;<  ~  bind:m  (build-book rail)
          ;<  ~  bind:m  (build-asks rail)
          (pure:m ~)
        ::  a real change to our app's declarations: notify if the ask is
        ::  unsettled (the subscription IS the dedup — news only fires on
        ::  actual change), then refresh the caches.
        ;<  ~  bind:m  (notify-if-unsettled rail u.ap)
        ;<  ~  bind:m  (build-book rail)
        ;<  ~  bind:m  (build-asks rail)
        ;<  ~  bind:m  (build-aliases rail)
        ;<  ~  bind:m  (build-weirs rail)
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
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-book rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
            (build-weirs rail)
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
        ::  default → serve the home page
        =/  page=@t  (crip (en-xml:html shell-page))
        =/  =mime  [/text/html (as-octs:mimes:html page)]
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
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
  [%& %& /sys/ames/ships/[s]/root/apps/'shell.shell' %'public.json']
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
::  path -> set of /book files it may peek. 'public' maps to /public.
::
++  read-shares
  |=  [rail=rail:tarball nex-dir=path]
  =/  m  (fiber:fiber:nexus ,(map path (set @ta)))
  ^-  form:m
  ;<  sv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'share.json']) ,json)
  =/  jon=json  (fall sv [%o ~])
  ?.  ?=(%o -.jon)  (pure:m ~)
  =|  out=(map path (set @ta))
  =/  entries=(list [al=@t v=json])  ~(tap by p.jon)
  |-  ^-  form:m
  ?~  entries  (pure:m out)
  =/  file=@ta  (book-file al.i.entries)
  =/  grps=(list path)
    ?:  ?=([%s *] v.i.entries)
      ?:  =('public' p.v.i.entries)  ~[/public]
      (drop (soft-path p.v.i.entries))
    ?.  ?=([%a *] v.i.entries)  ~
    %+  murn  p.v.i.entries
    |=(g=json ?.(?=([%s *] g) ~ (soft-path p.g)))
  =/  o=(map path (set @ta))
    %+  roll  grps
    |=  [g=path acc=_out]
    (~(put by acc) g (~(put in (fall (~(get by acc) g) ~)) file))
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
++  is-settled
  |=  [ask=json approved=(map @t json)]
  ^-  ?
  =/  app=@t  (fall (jget ask 'app') '')
  =/  ap=(unit json)  (~(get by approved) app)
  ?~  ap  %.n
  ?.  ?=(%o -.u.ap)  %.n
  =/  dec=json  (fall (~(get by p.u.ap) 'declared') [%o ~])
  =/  same=$-([(list @t) (list @t)] ?)
    |=([a=(list @t) b=(list @t)] =((sort a aor) (sort b aor)))
  ?&  (same (road-strs ask 'poke') (road-strs dec 'poke'))
      (same (road-strs ask 'peek') (road-strs dec 'peek'))
      (same (road-strs ask 'make') (road-strs dec 'make'))
  ==
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
    ::  the /book/main.sig fiber keeps share.json — writing it IS the
    ::  nudge; grants re-apply on the news.
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
::  +book-file: the /book grub name for an @alias. Strips the leading @
::  and appends .json — '@pad' -> 'pad.json'.
::
++  book-file
  |=  nm=@t
  ^-  @ta
  =/  tp=tape  (trip nm)
  =/  bare=tape  ?~(tp ~ t.tp)
  (cat 3 (crip bare) '.json')
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
::  +build-book: materialize the discovery registry. For each @alias, write
::  /book/<name>.json holding its claimants+locations (the alias menu made
::  a real, subscribable grub). Only writes on a genuine content change, so
::  an idle rescan doesn't bump versions and spam subscribers. Discovery is
::  the whole job — the grub holds WHERE apps are, never their data.
::
::  INVARIANT: /book MUST always be current. A discovery registry that lags
::  hands out stale locations — it's worthless if it can be stale. Being
::  rebuilt on the notify scanner's heartbeat (a POLL) is a placeholder and
::  is NOT good enough.
::
::  TODO (not built yet): drive this by SUBSCRIPTION, never a poll. Seed with
::  one scan on load, then subscribe to /apps membership (apps installed /
::  removed / moved) AND to EACH app's alias.json individually as it's
::  discovered (apps can self-edit alias.json), rebuilding the affected
::  /book entry the moment any of them fires. Poll drops to a bare backstop
::  or goes entirely.
::
::  TODO (related): alias resolution is frozen into grant.json bindings at
::  approval time. When /book shows an @alias now resolves to a different
::  target, every approved weir that referenced that alias is pointing at a
::  stale path — the shell should surface those and ask the user to re-point
::  them. /book being live is the signal that a binding went stale.
::
++  build-book
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  menus=(map @t (list json))  bind:m  read-app-aliases
  =/  entries=(list [nm=@t opts=(list json)])  ~(tap by menus)
  =/  want=(set @ta)  (silt (turn entries |=([nm=@t *] (book-file nm))))
  |-  ^-  form:m
  ?~  entries
    ::  cull pass: drop /book grubs whose alias no longer has any claimant
    ;<  bv=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /book]) ~)
    ?.  ?=([%ball *] bv)  (pure:m ~)
    =/  haves=(list @ta)  ~(tap in ~(key by dir.ball.bv))
    |-  ^-  form:m
    ?~  haves  (pure:m ~)
    ?:  (~(has in want) i.haves)  $(haves t.haves)
    ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /book i.haves]))
    $(haves t.haves)
  =/  fname=@ta  (book-file nm.i.entries)
  =/  wj=json   [%a opts.i.entries]
  ;<  cur=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /book fname]) `[/ %json])
  =/  have=(unit json)
    ?.  ?=([%file *] cur)  ~
    (mole |.(!<(json (need-vase:tarball sang.cur))))
  ?:  =(`wj have)  $(entries t.entries)
  ;<  ~  bind:m  (put:io (nex-road:io rail [%& /book fname]) [[/ %json] wj])
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
  ;<  ~  bind:m  (register-notify rail)
  ;<  *  bind:m  (notify-app rail app)
  (pure:m ~)
::  +build-asks: materialize the pending-asks view into /permit/asks.json so
::  the UI fetches a ready grub instead of re-running read-app-weirs +
::  alias-menu marking on every request. Same diff-then-write discipline as
::  build-book. Kept fresh by the followers and by
::  do-suppress (hidden changes affect the @alias resolution marking).
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
    =/  tap=tape  (trip s)
    =/  idx=(unit @ud)  (find "/" tap)
    (~(put in acc) ?~(idx s (crip (scag u.idx tap))))
  ~(tap in names)
::  +resolve-alias-ref: a weir.json target -> concrete road text. A plain
::  road passes through; an @alias resolves against the menu (first
::  option's path for now) with everything after the first / appended as
::  the sub-path. '' when the alias has no options.
::
++  resolve-alias-ref
  |=  [picks=json menus=json ref=@t]
  ^-  @t
  ?.  =("@" (scag 1 (trip ref)))  ref
  =/  tap=tape  (trip ref)
  =/  idx=(unit @ud)  (find "/" tap)
  =/  aname=@t  ?~(idx ref (crip (scag u.idx tap)))
  =/  suffix=@t  ?~(idx '' (crip (slag u.idx tap)))
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
::
++  shell-page
  ^-  manx
  ;html
    ;head
      ;title: home
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", type "image/svg+xml", href "/apps/grubbery/icon.svg");
      ;link(rel "stylesheet", href "/grubbery/tiles/style.css");
    ==
    ;body
      ;div#app
        ;div#header
          ;a#bell(href "#", onclick "openBell(event)", title "Notifications")
            ;+  (make:feather-icons 'bell')
            ;span#bell-count(style "display:none");
          ==
          ;button#add-btn.hdr-btn(onclick "addTile()"): + New
          ;button#get-btn.hdr-btn(onclick "openGet()"): Get Apps
        ==
        ;div#bell-backdrop(onclick "closeBell(event)")
          ;div#bell-panel
            ;div#bell-head
              ;span: Notifications
              ;div
                ;button#bell-ack-all.hdr-btn(onclick "bellAckAll()"): Mark all as read
                ;button.hdr-btn(onclick "closeBellNow()"): close
              ==
            ==
            ;div#bell-notes;
          ==
        ==
        ;div#get-backdrop(onclick "closeGet(event)")
          ;div#get-panel
            ;div#get-head
              ;button#get-back.hdr-btn(onclick "instBack()"): back
              ;span#get-title: Get apps
              ;a.hdr-btn(href "/apps/grubbery/permits"): Sandbox Settings
              ;button.hdr-btn(onclick "closeGetNow()"): close
            ==
            ;div#get-slider
              ;div.get-screen
                ;div#get-search
                  ;input#peer-ship(type "text", placeholder "search ~ship", autocomplete "off");
                  ;button.hdr-btn(onclick "peerAdd()"): search
                  ;div#peer-suggest;
                ==
                ;div#peer-lists;
              ==
              ;div.get-screen
                ;div#inst-screen;
                ;div#inst-foot;
              ==
            ==
          ==
        ==
        ;div#edit-backdrop
          ;div#edit-modal
            ;div#edit-header
              ;span#edit-title: Edit tile
              ;div
                ;button#edit-save.hdr-btn: save
                ;button#edit-close.hdr-btn: close
              ==
            ==
            ;textarea#edit-json(rows "10", placeholder "\{}");
            ;div#edit-status;
          ==
        ==
        ;div#tiles
          ;div#loading-tile
            ;div.spinner;
          ==
        ==
      ==
      ;script(src "/grubbery/tiles/app.js");
    ==
  ==
--
