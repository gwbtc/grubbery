::  shell nexus: the home surface. Composes services — the launcher grid
::  (from the tiles store) and the notifications bell — over HTTP, holds
::  the notifications inbox itself (/notifications, lib/shell/notifications), and owns
::  the cross-ship discovery state: public.json, the derived directory
::  of this ship's shared desks, and /peers/, live mirrors of other
::  ships' directories.
::
::  Terminology — the shell/kernel distinction. The "shell" is the
::  userspace permission MANAGER: it reads apps' declared link.json /
::  weir.json, surfaces them, records what you consent to, and writes
::  weirs. It decides. The "grubbery kernel" (the runtime, formerly
::  "runtime") is what ENFORCES those weirs — the dart gate. So the
::  permits registry below lives entirely on the deciding side; the
::  stopping is the kernel's job. Manager vs enforcer, shell vs kernel.
::
::  the pages, under shell/ui: the home page and its script and style,
::  the permissions page, the peers panes, and the notifications inbox
/<  feather-icons  /lib/feather-icons.hoon
/<  app-js         shell/ui/app.js
/<  app-css        shell/ui/style.css
/<  permits-html   shell/ui/permits.html
/<  home-html      shell/ui/home.html
::  peers: the usergroups panes of the explorer mounted on /sys/ames
/&  peers-js       shell/ui/peers.js
::  notifications: the service (lib/shell/notifications), its page at
::  /grubbery/inbox, and its tools nexus (push_notify)
/<  notifications  /lib/shell/notifications.hoon
/<  nib            /lib/inbox.hoon
/<  nex-tools      /lib/tools.hoon
/&  notif-bundle   /lib/notifications-bundle/
/&  notif-icon     shell/ui/notifications/icon.svg
/&  notif-html     shell/ui/notifications/index.html
/&  notif-js       shell/ui/notifications/app.js
/&  notif-css      shell/ui/notifications/style.css
::  tools: the MCP endpoint (lib/shell/mcp), its page at /grubbery/tools
::  on the kit (tab-group, modal-dialog), and its tools nexus seeded
::  from the tool bundle
/<  mcp            /lib/shell/mcp.hoon
::  explorer: the namespace browser and editor (lib/shell/explorer), its
::  page at /grubbery/explorer over the tree at /grubbery/ball, the gmux
::  sessions under /explorer/sessions, snaps under /explorer/snaps
/<  explorer       /lib/shell/explorer.hoon
/&  tool-bundle    /lib/tool-bundle/
/&  tools-icon     shell/ui/tools/icon.svg
/&  tools-html     shell/ui/tools/index.html
/&  tools-js       shell/ui/tools/app.js
/&  tools-css      shell/ui/tools/style.css
::  the explorer panes for a tools nexus and one of its tools
/&  tools-pane-js  shell/ui/tools/pane.js
/&  tg-js          /lib/ui/tab-group.js
/&  md-js          /lib/ui/modal-dialog.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  the kit components the tools page uses, welded into one served file
      =/  wrap  |=(=mime ^-(@ (rap 3 ~[123 10 q.q.mime 10 125 10])))
      =/  kit-js=mime
        [/application/javascript (as-octs:mimes:html (rap 3 ~[(wrap tg-js) (wrap md-js)]))]
      %+  spin:loader  ball
      ::  the explorer's rows come after: its /ui/explorer sits under /ui
      %+  weld
      :~  (manifest:loader 0)
          ::  /ui: everything served over HTTP. http.sig binds the routes and
          ::  spawns a request grub per hit under /ui/requests; the pages and
          ::  their assets sit beside it, the notifications page in its own
          ::  subdirectory.
          [%fall %| /ui empty-dir:loader]
          [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
          [%over %& [/ui %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ui %'style.css'] [[/ %mime] app-css]]
          [%over %& [/ui %'permits.html'] [[/ %mime] permits-html]]
          [%over %& [/ui %'peers.js'] [[/ %mime] peers-js]]
          [%fall %| /ui/notifications empty-dir:loader]
          [%over %& [/ui/notifications %'index.html'] [[/ %mime] notif-html]]
          [%over %& [/ui/notifications %'app.js'] [[/ %mime] notif-js]]
          [%over %& [/ui/notifications %'style.css'] [[/ %mime] notif-css]]
          [%over %& [/ui/notifications %'icon.svg'] [[/ %mime] notif-icon]]
          ::  /ui/tools: the tools page (lib/shell/mcp), at /grubbery/tools
          [%fall %| /ui/tools empty-dir:loader]
          [%over %& [/ui/tools %'index.html'] [[/ %mime] tools-html]]
          [%over %& [/ui/tools %'app.js'] [[/ %mime] tools-js]]
          [%over %& [/ui/tools %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ui/tools %'style.css'] [[/ %mime] tools-css]]
          [%over %& [/ui/tools %'icon.svg'] [[/ %mime] tools-icon]]
          [%over %& [/ui/tools %'pane.js'] [[/ %mime] tools-pane-js]]
          ::  usergroups.sig: the shell's ONE registry liaison. Registrant
          ::  prefixes nest-clobber (%how replaces every road under the
          ::  sender's prefix), so exactly one root-prefix fiber makes all
          ::  of the shell's grants. public.json is inert data it writes.
          [%fall %& [/ %'usergroups.sig'] [[/ %sig] ~]]
          ::  groups.sig: the user's write path into usergroups (the Peers
          ::  page and the tools poke it); it edits permit/groups.json and
          ::  usergroups.sig derives the groups' files from the record and
          ::  every granted app's own groups.json.
          [%fall %& [/ %'groups.sig'] [[/ %sig] ~]]
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
          ::  permit/link.json: the USER's side of discovery, by bare name:
          ::  {<name>: {path: <where you point it>, share: [usergroups]}}.
          ::  `path` is a name you declare yourself, a claimant beside the
          ::  apps'; `share` is who may resolve the name here, the single
          ::  record of that grant whoever asked for it. Absent = private.
          [%fall %& [/permit %'link.json'] [[/ %json] [%o ~]]]
          ::  permit/groups.json: the user's usergroup record —
          ::  {user: {<group>: {members, make, poke, peek}}}. Apps state
          ::  theirs in the groups.json at their own root. A group exists
          ::  while someone names it; its who.ships and how.weir are the
          ::  union, rewritten whole.
          [%fall %& [/permit %'groups.json'] [[/ %json] [%o ~]]]
          ::  /sys/link: the discovery registry lives at the system level.
          ::  One dest.lanes per @name holding its target lanes — peers
          ::  (local or cross-ship) can `keep` a name and learn where
          ::  its app lives.
          ::  sweep.sig: poke target for "new apps may exist — look now".
          ::  Desk installs poke it after applying their bill, so fresh
          ::  apps get followers (and their reload-time notify) immediately
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
          ::  /forge: the forge. A nexus, not a desk — it ships with the
          ::  kernel, so its code is already in this namespace, named by
          ::  the neck below (/nex/git/forge.hoon). Desks are for code
          ::  that lives on another ship.
          ::
          ::  %fall, so the forge's own world — its repos and their git
          ::  working trees — survives a shell reload.
          [%fall %| /forge [`[`[/git %forge] ~ %.n ~] ~]]
          ::  /share: per-usergroup discovery directories, derived from
          ::  local desks' share.usergroups. /share/<group>/desks.json lists
          ::  the desks that group may subscribe to and where their code +
          ::  version live. Rebuilt from the live grants by the followers.
          [%fall %| /share empty-dir:loader]
          [%fall %| /peers empty-dir:loader]
          ::  local tiles: the home page's own launcher entries, one subdir
          ::  /tiles/<name>/ holding tile.json (apps declare theirs in their
          ::  own root's tile.json). %fall: seeded once with Landscape, then
          ::  the user's, edited from the home page.
          [%fall %| /tiles empty-dir:loader]
          [%fall %| /tiles/landscape empty-dir:loader]
          [%fall %& [/tiles/landscape %'tile.json'] [[/ %json] landscape-tile]]
          ::  hidden-tiles.json: the user's launcher preference — the set of
          ::  tile names hidden from the home grid, toggled from the UI. This
          ::  replaces the old hardcoded hidden set (any tile can be hidden or
          ::  shown now); seeded empty.
          [%fall %& [/ %'hidden-tiles.json'] [[/ %json] [%a ~]]]
          ::  /notifications: the service (see lib/shell/notifications).
          ::  /sys/link/notifications points here, so senders poke
          ::  @notifications/main.sig and land on notifications/main.sig.
          ::  The registry and the inbox are user data; the page (under
          ::  /ui/notifications) is chrome, the home page's bell, not a tile.
          [%fall %| /notifications empty-dir:loader]
          [%fall %& [/notifications %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/notifications %'registry.json'] [[/ %json] [%o ~]]]
          [%fall %& [/notifications %'inbox.inbox'] [[/ %inbox] *inbox:nib]]
          [%over %| /notifications/tools (seed-tools:nex-tools notif-bundle)]
          ::  /tools: the tools nexus the MCP endpoint serves (lib/shell/mcp):
          ::  the bundle over whatever tools were added at runtime. Its tile
          ::  is a local one, like Landscape's.
          [%over %| /tools (tools-bole:mcp ball tool-bundle)]
          [%fall %| /tiles/tools empty-dir:loader]
          [%fall %& [/tiles/tools %'tile.json'] [[/ %json] tile:mcp]]
          [%fall %| /tiles/explorer empty-dir:loader]
          [%fall %& [/tiles/explorer %'tile.json'] [[/ %json] tile:explorer]]
          ::  the forge and the github proxy it houses live under this
          ::  shell, not under /apps, so the tile reader never finds them:
          ::  their tiles are local ones too.
          [%fall %| /tiles/forge empty-dir:loader]
          [%fall %& [/tiles/forge %'tile.json'] [[/ %json] forge-tile]]
          [%fall %| /tiles/github empty-dir:loader]
          [%fall %& [/tiles/github %'tile.json'] [[/ %json] github-tile]]
      ==
      rows:explorer
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  ui/http.sig: every route the shell serves. The home page and
          ::  its API, the permissions page and its API, the peers panes,
          ::  and the notifications inbox page.
          [[%ui ~] %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell http: failed")
        ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/tiles])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/inbox])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/tools])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/ball])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/explorer])
        (http-dispatch:io %shell)
          ::  explorer/sessions/<name>.json: a gmux workspace the ship keeps;
          ::  lib/shell/explorer runs the session's poke loop
          ::
          [[%explorer %sessions ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell explorer session: failed, poke to restart")
        session-loop:explorer
          ::  notifications/main.sig: the bus's poke loop (register, notify,
          ::  ack, clear); lib/shell/notifications does the work
          ::
          [[%notifications ~] %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell notifications: failed")
        serve:notifications
          ::  usergroups.sig: register once, then hold every shell grant
          ::  current — the base /public grant on public.json plus the
          ::  per-group /sys/link shares from permit/link.json — and keep
          ::  public.json (inert json) an honest reflection of the /public
          ::  group's weir. Event-driven: wakes on the link record, on
          ::  the public group's weir changing (desk grants), or a poke.
          ::
          [~ %'usergroups.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell groups: failed")
        ;<  ~  bind:m  (carry-links rail)
        ;<  *  bind:m
          (keep:io /share (nex-road:io rail [%& /permit %'link.json']) ~)
        ;<  *  bind:m
          (keep:io /groups (nex-road:io rail [%& /permit %'groups.json']) ~)
        ::  the derived files themselves: a hand edit to a who.ships or a
        ::  how.weir is drift, and the next derive puts it back. No loop —
        ::  the derive writes only what differs, so its own writes are
        ::  silent and a hand edit settles after one round.
        ;<  *  bind:m  (keep:io /derived [%& %| /sys/ames/usergroups] ~)
        |-
        ::  every group's files, from the record: the user's section, each
        ::  section, the names opened (the link record), the desks opened
        ::  (their share.usergroups), and the shell's own /public base.
        ;<  ~  bind:m  (apply-groups rail)
        ;<  paths=(list @t)  bind:m  scan-public
        ;<  cur=(unit json)  bind:m
          (peek-as:io (nex-road:io rail [%& / %'public.json']) ,json)
        =/  next=json  a+(turn paths |=(p=@t s+p))
        ;<  ~  bind:m
          ?:  =(`next cur)  (pure:(fiber:fiber:nexus ,~) ~)
          (over:io (nex-road:io rail [%& / %'public.json']) [[/ %json] next])
        ::  wakes: the record or the names changed (news), or a desk's
        ::  share changed (its listener pokes)
        ;<  ~  bind:m  take-reg-wake
        $
          ::  groups.sig: a contribution to the user's usergroup record,
          ::  from a request fiber or a tool under this shell.
          ::
          [~ %'groups.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell groups.sig: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        =/  sender=rail:tarball  (resolve-bend:io here from)
        ;<  err=(unit @t)  bind:m  (group-request rail sender jon)
        ~?  >>  ?=(^ err)  [%shell-groups-refused path.sender u.err]
        $
          ::  sweep.sig: on any poke, spawn followers for apps that lack
          ::  them and refresh the caches if anything new appeared.
          ::
          [~ %'sweep.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell sweep: failed")
        ::  a sweep on every nexus reload too: a follower this version
        ::  adds (the desk share listener) must appear on a ship that
        ::  already has desks, not wait for the next poke
        ;<  *  bind:m  (spawn-followers rail)
        |-
        ;<  *  bind:m  take-poke:io
        ;<  made=?  bind:m  (spawn-followers rail)
        ;<  ~  bind:m
          ?.  made  (pure:(fiber:fiber:nexus ,~) ~)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-links rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
          ;<  ~  bind:(fiber:fiber:nexus ,~)  (regrant-moved rail)
          (build-weirs rail)
        ::  desk shares change without spawning a follower, so /share must
        ::  rebuild on every sweep, not only when a new app appeared.
        ;<  ~  bind:m  (build-share rail)
        $
          ::  bootstrap.sig: the stock desks, held current at every nexus reload.
          ::  /bootstrapped.json marks that the first run happened. The
          ::  manual POST /desks/sync-defaults does the same on demand.
          ::
          [~ %'bootstrap.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell bootstrap: failed")
        ;<  ~  bind:m  ensure-polls
        ::  every nexus reload: each stock entry's repo and desk, made if missing,
        ::  and its source re-pointed at the forge as it stands now. A
        ::  stock entry added later, or a forge that moved, is taken up by
        ::  the next reload with no one's hand on it. Idempotent; the network
        ::  is touched last and softly.
        ;<  ~  bind:m  sync-defaults
        ;<  done=?  bind:m
          (peek-exists:io (nex-road:io rail [%& / %'bootstrapped.json']))
        ?:  done  (pure:m ~)
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
          ::  /sync/<desk>/share.sig: the desk's share listener. One job:
          ::  when the desk's share set changes, the storefront follows.
          ::  Nothing else runs in this fiber, so nothing can keep it from
          ::  hearing the change.
          ::
          [[%sync @ ~] %'share.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shell share-listener: failed")
        =/  desk=@ta  i.t.path.rail
        =/  road=road:tarball  [%& %& /apps/shell/desks/[desk] %'share.usergroups']
        ;<  *  bind:m  (keep:io /share road ~)
        ::  a change made while the shell was down shows on reload
        ;<  ~  bind:m  (build-share rail)
        |-
        ;<  *  bind:m  (take-news:io /share)
        ;<  ~  bind:m  (build-share rail)
        ::  the groups the desk is open to are part of the record's union
        ;<  ~  bind:m
          (poke:io (nex-road:io rail [%& / %'usergroups.sig']) [[/ %json] [%o ~]])
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
        ::  its facts about usergroups; absent for most apps
        ;<  *  bind:m  (keep:io /groups [%& %& u.ap %'groups.json'] ~)
        ::  a desk's opening declaration — absent for non-desk apps (a sub on
        ::  an absent road is legal and fires if it ever appears).
        ;<  *  bind:m  (keep:io /shareg (share-road u.ap) ~)
        ::  notify on reload too: a fresh install's ask predates this
        ::  follower, so there is no change-news to catch — and an ask
        ::  still pending across a reload deserves the re-ping anyway.
        ::  The app's sand is the shell's to set and the kernel's to keep:
        ::  a reload carries every directory's weir forward, so nothing is
        ::  re-granted here. The weir changes only when a grant or an alias
        ::  does. (grant.json is the app's to keep, if it cares.)
        ::  The notice, bounded: a notify whose ack never came (the
        ::  notifications nexus busy or banged) used to hold the follower
        ::  here for good, deaf to every change to the files it follows
        ;<  did=(unit ~)  bind:m
          ((with-timeout:io ,~) /notify ~s30 (notify-if-unsettled rail u.ap))
        ~?  >>  ?=(~ did)  [%shell-follower-notify-timeout u.ap]
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
        ::  its groups.json may be what changed: derive the groups again
        ;<  ~  bind:m
          (poke:io (nex-road:io rail [%& / %'usergroups.sig']) [[/ %json] [%o ~]])
        ;<  ~  bind:m  (build-links rail)
        ;<  ~  bind:m  (build-asks rail)
        ;<  ~  bind:m  (build-aliases rail)
        ::  a name this app claims may be one another app was granted
        ::  against: their sand follows the registry
        ;<  ~  bind:m  (regrant-moved rail)
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
        ::  a peer on an older grubbery keeps its storefront under
        ::  /apps/shell.shell (the shell installed as a desk app): both
        ::  roads are kept, and whichever answers is read.
        ;<  *  bind:m  (keep:io /pub (peer-pub-road s) ~)
        ;<  *  bind:m  (keep-soft:io /pub-legacy (peer-pub-road-legacy s) ~ ~s30)
        ;<  ~  bind:m  (refresh-mirror s)
        |-
        ;<  ~  bind:m  take-pub-news
        ;<  ~  bind:m  (refresh-mirror s)
        $
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  prefix=path  /grubbery/tiles
        =/  site=path  site:(parse-url:http-utils url.request.req)
        ::  /grubbery/inbox[/<file>] → the notifications page
        ?:  ?=([%grubbery %inbox *] site)
          (serve-page:notifications rail)
        ::  /grubbery/tools → the MCP endpoint and its page
        ?:  ?=([%grubbery %tools *] site)
          (serve-request:mcp rail)
        ::  /grubbery/ball[/...] and /grubbery/explorer[/...] → the explorer:
        ::  the tree and its page
        ?:  |(?=([%grubbery %ball *] site) ?=([%grubbery %explorer *] site))
          (serve-request:explorer rail)
        =/  suffix=path  (slag (lent prefix) site)
        ::  POST /apps/grubbery/peers/{create,members,permissions}: the three
        ::  writes the peers panes need. Reads are the explorer's; these are
        ::  the registry's (a ships mark, the usergroups registry poke).
        ?:  &(=('POST' method.request.req) ?=([%peers @ ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          ;<  err=(unit @t)  bind:m  (peers-write rail i.t.suffix jon)
          ?^  err
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html u.err)])
            (pure:m ~)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html '{"ok":true}')])
          (pure:m ~)
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
          ::  Apply and ANSWER. The three cache rebuilds this used to run here -
          ::  a round-trip per app, each - were seven seconds of nothing after
          ::  every click, and they cannot be deferred inside this fiber either
          ::  (the response waits for the fiber). The page requests them through
          ::  POST /permits/refresh the moment this returns, and reloads when
          ::  that completes.
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::  POST /permits/refresh {full}: the slow work, on the page's schedule
        ::  rather than the user's. The follower sweep (new installs get their
        ::  followers), the share view, and - with full - every cache the
        ::  permissions page reads. The page fires this in the background after
        ::  it renders and after every action, and reloads its data when it
        ::  answers. Same total work as before; none of it in front of a click.
        ?:  &(=('POST' method.request.req) ?=([%permits %refresh ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  full=?  ?.(?=(%o -.jon) | =([~ %b &] (~(get by p.jon) 'full')))
          ;<  made=?  bind:m  (spawn-followers rail)
          ;<  ~  bind:m  (build-share rail)
          ;<  av=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& /cache %'aliases.json']) ,json)
          =/  seed=?  |(?=(~ av) =([%o ~] u.av))
          ;<  ~  bind:m
            ?.  |(full made seed)  (pure:(fiber:fiber:nexus ,~) ~)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-links rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-asks rail)
            ;<  ~  bind:(fiber:fiber:nexus ,~)  (build-aliases rail)
            (build-weirs rail)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::  POST /permits/reload {app}: reboot an app after a grant, so the
        ::  fibers that crashed while jailed come back holding what was
        ::  granted. Its own request because a reboot takes seconds (lattice:
        ::  6s on ~wex) and the approve answer must not wait on it.
        ?:  &(=('POST' method.request.req) ?=([%permits %reload ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  tp=(unit path)
            (soft-path ?.(?=(%o -.jon) '' (fall (jget jon 'app') '')))
          ;<  ~  bind:m
            ?~  tp  (pure:(fiber:fiber:nexus ,~) ~)
            (reload:io [%& %| u.tp])
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
          ::  three spellings reach the same place. A desk-nested app names
          ::  one nexus inside a desk and uninstalls the WHOLE desk, so walk
          ::  up to the desk root; the desk root itself is already there (the
          ::  Desks panel's "remove" sends this one); a bare /apps/<app> is a
          ::  built-in app. Anything else is refused.
          =/  target=(unit path)
            ?~  rt  ~
            ?:  ?=([%apps %shell %desks @ %desk %data @ ~] u.rt)
              `/apps/shell/desks/[i.t.t.t.u.rt]
            ?:  ?=([%apps %shell %desks @ ~] u.rt)  `u.rt
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
        ::  POST /visibility {name, hidden}: hide or show a tile by name. The
        ::  hidden set is the user's own launcher preference (replaces the old
        ::  hardcoded set) — any tile can be toggled from the home page.
        ?:  &(=('POST' method.request.req) ?=([%visibility ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  name=@t  (fall (jget jon 'name') '')
          =/  hide=?  &(?=([%o *] jon) =([~ %b %.y] (~(get by p.jon) 'hidden')))
          ?:  =('' name)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'name required')])
            (pure:m ~)
          ;<  cur=(set @t)  bind:m  (read-hidden-tiles rail)
          =/  next=(set @t)  ?:(hide (~(put in cur) name) (~(del in cur) name))
          ;<  ~  bind:m
            %+  over:io  (nex-road:io rail [%& / %'hidden-tiles.json'])
            [[/ %json] [%a (turn ~(tap in next) |=(n=@t s+n))]]
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
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
            /apps/shell/desks/[(cat 3 `@ta`name '.desk')]
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
        ::  POST /desks/share {name, add|remove: <group>}: publish a desk to
        ::  a usergroup, or stop. Forwarded to the desk's share.usergroups,
        ::  which grants and the follower rebuilds the listing.
        ?:  &(=('POST' method.request.req) ?=([%desks %share ~] suffix))
          =/  jon=json
            %+  fall  (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          =/  name=@t  (jstr jon 'name')
          =/  dir-path=path  /apps/shell/desks/[(cat 3 `@ta`name '.desk')]
          ;<  live=?  bind:m  (peek-exists:io [%& %| dir-path])
          ?.  live
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'no such desk')])
            (pure:m ~)
          =/  cmd=json
            ?.  ?=([%o *] jon)  [%o ~]
            [%o (~(del by p.jon) 'name')]
          ;<  ~  bind:m  (poke:io [%& %& dir-path %'share.usergroups'] [[/ %json] cmd])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::  POST /desks/sync-defaults: bootstrap the shipped "repos to sync"
        ::  list — for each entry, ensure its git_repo (polling github) and a
        ::  desk following the repo's checked-out tree exist and are wired.
        ::  Idempotent: guarded makes + a replace-in-place source poke, so it's
        ::  safe to re-run. This is the shell-owned setup pipeline (replaces the
        ::  old root.hoon contacts/wallet seeds).
        ?:  &(=('POST' method.request.req) ?=([%desks %sync-defaults ~] suffix))
          ::  answer first, for the reason spelled out at /desks/sync below:
          ::  syncing every stock entry touches the network once per entry, and
          ::  an HTTP request held open across that stalls the server.
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'syncing')])
          ;<  ~  bind:m  sync-defaults
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
          ::  ANSWER FIRST, then do the work. +ensure-pairing touches the
          ::  network, and holding an HTTP request open across that is how this
          ::  route took the whole server down: the pairing blocked on a fetch
          ::  that never answered, so this request never completed, and every
          ::  request behind it went with it — including the shell's own consent
          ::  page, which is the one page a user needs in order to fix anything.
          ::  The caller learns the outcome from /desks/stock, which reports each
          ::  entry's synced flag; it does not need this response to carry it.
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'syncing')])
          ;<  ~  bind:m  (ensure-pairing u.match)
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
          ;<  hidden=(set @t)  bind:m  (read-hidden-tiles rail)
          =/  =json  (tiles-to-json tiles hidden)
          =/  body=octs  (as-octs:mimes:html (en:json:html json))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `body])
          (pure:m ~)
        ::  /grubbery/tiles/icon/<nexus-root-path> → serve a nexus's icon
        ::  file. The path may be deep (a desk-install's desk/data/<nexus>).
        ?:  ?=([%icon ^] suffix)
          ::  reconstruct the nexus root from the compressed icon path:
          ::  <desk>/<nexus> -> /apps/shell/desks/<desk>/desk/data/<nexus>,
          ::  a bare <nexus> -> /apps/<nexus>, or a full /apps/... path as-is.
          =/  segs=path  t.suffix
          =/  root=path
            ?:  ?=([%apps *] segs)  segs
            ?:  ?=([@ @ ~] segs)
              ~[%apps %shell %desks i.segs %desk %data i.t.segs]
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
            (peek:io (nex-road:io rail [%& /ui fname]) `[/ %mime])
          ?.  ?=([%file *] fv)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.fv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' ctype]]] `q.mime])
          (pure:m ~)
        ::  /apps/grubbery/permits → the read-only permissions page
        ?:  ?=([%permits ~] suffix)
          ::  Serve the page and NOTHING else. This route used to run a follower
          ::  sweep and a share rebuild first, and that is why the page took ten
          ::  to twenty seconds to appear. Doing that work after the send did not
          ::  help either: the response is not released until the request fiber
          ::  finishes. So the page itself asks for that work, in the background,
          ::  once it has rendered - see POST /permits/refresh below.
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /ui %'permits.html']) `[/ %mime])
          ?.  ?=([%file *] fv)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.fv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/html']]] `q.mime])
          (pure:m ~)
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
            (peek-shallow:io [%& %| /apps/shell/desks] ~)
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
        ::  /grubbery/tiles/desks/forge-repos → the forge's repos, each one
        ::  a source a desk can follow. The "From your forge" tab.
        ?:  ?=([%desks %'forge-repos' ~] suffix)
          ;<  lst=json  bind:m  forge-repos
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
        ::  /apps/grubbery/link.json → per-name discovery: who may resolve
        ::  each name, from the link record.
        ?:  ?=([%'link.json' ~] suffix)
          ;<  links=(map @t json)  bind:m  (read-links rail)
          =/  sv=(unit json)
            :-  ~
            :-  %o
            %-  ~(gas by *(map @t json))
            %+  murn  ~(tap by links)
            |=  [nm=@t e=json]
            ^-  (unit [@t json])
            =/  gs=(list path)  (link-groups e)
            ?~  gs  ~
            `[(cat 3 '@' nm) a+(turn gs |=(g=path s+(spat g)))]
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
        ::  === peers: the explorer mounted on /sys/ames, with panes ===
        ::  /apps/grubbery/peers.js → the panes (groups, group)
        ?:  ?=([%'peers.js' ~] suffix)
          =/  bod=octs  q.peers-js
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/javascript']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/peers.json → every usergroup folded from its files
        ?:  ?=([%'peers.json' ~] suffix)
          ;<  groups=json  bind:m  (peers-groups rail)
          =/  bod=octs  (as-octs:mimes:html (en:json:html groups))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/peers-viewer?path=&kind= → which pane a path under
        ::  /sys/ames opens in (the explorer asks per tab; see +peers-viewer)
        ?:  ?=([%'peers-viewer' ~] suffix)
          =/  args=(map @t @t)  (malt args:(parse-url:http-utils url.request.req))
          =/  pax=path  (fall (rush (fall (~(get by args) 'path') '') stap) /)
          =/  pick=(unit json)  (peers-viewer pax =(`'dir' (~(get by args) 'kind')))
          =/  bod=octs  (as-octs:mimes:html ?~(pick '' (en:json:html u.pick)))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  /apps/grubbery/peers[/<path>] → the explorer's browse page, mounted
        ::  here and rooted at /sys/ames: the ships and usergroups directories,
        ::  browsed like anything else, with the panes above on the groups.
        ?:  ?=([%peers *] suffix)
          (serve-explorer-page eyre-id peers-mount)
        ::  default → serve the home page (static file, /<-imported home-html)
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils home-html))
        (pure:m ~)
      ==
    --
|%
::  +dbg: the routine traces print only when this is yes. It lives in this
::  helper core, where the nexus core above can see it.
::
++  dbg  ^-(? |)
++  srv  ~(. http-res:io [%| 1 %& ~ %'http.sig'])
::  === peers: usergroups + ships as the explorer mounted on /sys/ames ===
::  The page is the explorer's browse page with one declaration injected:
::  route /apps/grubbery/peers, root /sys/ames, and a viewer endpoint.
::  +peers-viewer answers it: the usergroups directory opens in the groups
::  pane, each <name>.grp directory in its group pane (peers.js). The
::  panes read /peers.json and write through +peers-write; everything else
::  (the ships listing, the raw who.ships / how.weir, delete) is the
::  explorer's. A group /a/b is stored at /sys/ames/usergroups/a/b.grp.
++  peers-mount
  ^-  json
  %-  pairs:enjs:format
  :~  ['route' s+'/apps/grubbery/peers']
      ['root' s+'/sys/ames']
      ['title' s+'peers']
      ['icon' s+'/apps/grubbery/icon.svg']
      ['viewers' s+'/apps/grubbery/peers-viewer']
  ==
::  +serve-explorer-page: the explorer's browse page with a mount
::  declaration ahead of its scripts, the way a mounting app serves it.
++  serve-explorer-page
  |=  [eyre-id=@ta mount=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  page=tape  (trip q.q:browse-html:explorer)
  =/  decl=tape
    "<script>window.EXPLORER_MOUNT = {(trip (en:json:html mount))};</script>\0a"
  =/  marker=tape  "<script src=\"/grubbery/ball/apps/shell/ui/explorer/kit.js\""
  =/  at=(unit @ud)  (find marker page)
  =/  out=tape
    ?~  at  (weld decl page)
    :(weld (scag u.at page) decl (slag u.at page))
  ;<  ~  bind:m
    (send-simple:srv eyre-id [[200 ~[['content-type' 'text/html']]] `(as-octs:mimes:html (crip out))])
  (pure:m ~)
::  +peers-viewer: the pane for a path relative to /sys/ames, dirs only
++  peers-viewer
  |=  [pax=path dir=?]
  ^-  (unit json)
  ?.  dir  ~
  =/  script=json  s+'/apps/grubbery/peers.js'
  ?:  =(/usergroups pax)
    `(pairs:enjs:format ~[['view' s+'groups'] ['script' script] ['args' [%o ~]]])
  ?.  ?=([%usergroups @ *] pax)  ~
  =/  grp=(unit path)  (peers-group-of t.pax)
  ?~  grp  ~
  :-  ~
  %-  pairs:enjs:format
  :~  ['view' s+'group']
      ['script' script]
      ['args' (pairs:enjs:format ~[['group' s+(spat u.grp)] ['dir' s+(spat pax)]])]
  ==
::  +peers-group-of: /a/b.grp -> `/a/b; a last segment without .grp is a
::  category directory, not a group
++  peers-group-of
  |=  rel=path
  ^-  (unit path)
  ?~  rel  ~
  =/  last=tape  (trip (rear rel))
  =/  len=@ud  (lent last)
  ?.  &((gth len 4) =(".grp" (slag (sub len 4) last)))  ~
  `(snoc (snip `path`rel) (crip (scag (sub len 4) last)))
::  +peers-storage: where a group's files live
++  peers-storage
  |=  grp=path
  ^-  path
  ?~  grp  /sys/ames/usergroups
  (weld /sys/ames/usergroups (snoc (snip `path`grp) (cat 3 (rear grp) '.grp')))
::  +peers-find: every group under a directory, recursing through
::  category directories; the group's name is its path of stems
++  peers-find
  |=  [pax=path ug=ball:tarball]
  ^-  (list [name=path grp=ball:tarball])
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ug)
  =|  acc=(list [name=path grp=ball:tarball])
  |-
  ?~  kids  acc
  =/  [kid-name=@ta kid=ball:tarball]  i.kids
  =/  stem=(unit path)  (peers-group-of ~[kid-name])
  ?^  stem
    $(kids t.kids, acc [[(weld pax u.stem) kid] acc])
  $(kids t.kids, acc (weld acc ^$(pax (snoc pax kid-name), ug kid)))
::  +peers-groups: every usergroup as json: name, dir (relative to
::  /sys/ames), public, members, and its make/poke/peek roads as text
++  peers-groups
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  ug=view:nexus  bind:m  (peek:io [%& %| /sys/ames/usergroups] ~)
  ?.  ?=([%ball *] ug)  (pure:m a+~)
  ;<  all=(list [grp=path by=@t members=(set @p) =weir:nexus])  bind:m  (gather-groups rail)
  ;<  rec=json  bind:m  (read-groups-record rail)
  =/  found=(list [name=path grp=ball:tarball])  (peers-find / ball.ug)
  =/  roads  |=(s=(set road:tarball) ^-(json a+(turn ~(tap in s) |=(r=road:tarball s+(crip (peers-road-text r))))))
  =/  ships  |=(s=(set @p) ^-(json a+(turn (sort ~(tap in s) aor) |=(p=@p s+(scot %p p)))))
  =/  part
    |=  [by=@t members=(set @p) w=weir:nexus]
    ^-  json
    %-  pairs:enjs:format
    :~  ['by' s+by]
        ['members' (ships members)]
        ['make' (roads make.w)]
        ['poke' (roads poke.w)]
        ['peek' (roads peek.w)]
    ==
  %-  pure:m
  :-  %a
  %+  murn  found
  |=  [name=path grp=ball:tarball]
  ^-  (unit json)
  =/  who=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'who.ships'])
  =/  how=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'how.weir'])
  ?~  who  ~
  =/  who-res  (mule |.(!<((set @p) (need-vase:tarball u.who))))
  =/  members=(set @p)  ?:(?=(%| -.who-res) ~ p.who-res)
  =/  =weir:nexus
    ?~  how  *weir:nexus
    =/  res  (mule |.(!<(weir:nexus (need-vase:tarball u.how))))
    ?:(?=(%| -.res) *weir:nexus p.res)
  =/  here=(list [grp=path by=@t members=(set @p) =weir:nexus])
    (skim all |=([g=path * * *] =(g name)))
  ::  the shell's record part alone is editable; its name shares and
  ::  /public base ride in the merged shell row below
  =/  mine=json
    =/  g=(map @t json)  (contribution rec (spat name))
    =/  strs
      |=  k=@t
      ^-  (list @t)
      =/  v  (~(get by g) k)
      ?.  ?=([~ %a *] v)  ~
      (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
    =/  rd  |=(k=@t (sy (murn (strs k) peers-parse-road)))
    (part 'manual' (sy (murn (strs 'members') |=(t=@t (slaw %p t)))) [(rd 'make') (rd 'poke') (rd 'peek')])
  =/  merged=(list [by=@t members=(set @p) =weir:nexus])
    %+  roll  here
    |=  [[* by=@t ms=(set @p) w=weir:nexus] acc=(list [by=@t members=(set @p) =weir:nexus])]
    ?~  (find ~[by] (turn acc |=([b=@t * *] b)))
      (snoc acc [by ms w])
    %+  turn  acc
    |=  [b=@t m=(set @p) x=weir:nexus]
    ?.  =(b by)  [b m x]
    [b (~(uni in m) ms) [(~(uni in make.x) make.w) (~(uni in poke.x) poke.w) (~(uni in peek.x) peek.w)]]
  :-  ~
  %-  pairs:enjs:format
  :~  ['name' s+(spat name)]
      ['dir' s+(spat (slag 2 (peers-storage name)))]
      ['public' b+=(/public name)]
      ['members' (ships members)]
      ['make' (roads make.weir)]
      ['poke' (roads poke.weir)]
      ['peek' (roads peek.weir)]
      ::  your part, which the pane edits
      ['mine' mine]
      ::  every contribution, with who made it
      ['contributions' a+(turn merged |=([by=@t ms=(set @p) w=weir:nexus] (part by ms w)))]
  ==
::  +peers-write: the panes' three writes. ~ on success, an error text
::  otherwise.
++  peers-write
  |=  [rail=rail:tarball what=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  jarr
    |=  k=@t
    ^-  json
    ?.  ?=([%o *] jon)  [%a ~]
    (fall (~(get by p.jon) k) [%a ~])
  =/  grp=@t  (jstr jon ?:(=(%create what) 'name' 'group'))
  ?:  =('' grp)  (pure:m `'group required (a path like /friends)')
  =/  req=(unit json)
    ?+  what  ~
      %create       `(pairs:enjs:format ~[['group' s+grp]])
      %members      `(pairs:enjs:format ~[['group' s+grp] ['members' (jarr 'ships')]])
      %permissions  `(pairs:enjs:format ~[['group' s+grp] ['make' (jarr 'make')] ['poke' (jarr 'poke')] ['peek' (jarr 'peek')]])
      %delete       `(pairs:enjs:format ~[['group' s+grp] ['remove' b+&]])
    ==
  ?~  req  (pure:m `'unknown peers action')
  ;<  ~  bind:m  (poke:io (nex-road:io rail [%& / %'groups.sig']) [[/ %json] u.req])
  (pure:m ~)
::  === usergroups: the record, and the files derived from it ===
::
::  +read-groups-record: permit/groups.json as an object.
++  read-groups-record
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  v=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'groups.json']) ,json)
  (pure:m ?~(v [%o ~] ?:(?=(%o -.u.v) u.v [%o ~])))
::  +user-section: the user's groups, from the record.
++  user-section
  |=  rec=json
  ^-  json
  ?.  ?=(%o -.rec)  [%o ~]
  (fall (~(get by p.rec) 'user') [%o ~])
::  +contribution: what the user says about one group.
++  contribution
  |=  [rec=json gkey=@t]
  ^-  (map @t json)
  =/  sec=json  (user-section rec)
  ?.  ?=(%o -.sec)  ~
  =/  g  (~(get by p.sec) gkey)
  ?.(?=([~ %o *] g) ~ p.u.g)
::  +set-contribution: the record with the user's say on one group
::  replaced (~ removes it).
++  set-contribution
  |=  [rec=json gkey=@t next=(unit json)]
  ^-  json
  =/  top=(map @t json)  ?.(?=(%o -.rec) ~ p.rec)
  =/  sec=json  (user-section rec)
  =/  smap=(map @t json)  ?.(?=(%o -.sec) ~ p.sec)
  =/  smap2=(map @t json)
    ?~(next (~(del by smap) gkey) (~(put by smap) gkey u.next))
  [%o (~(put by top) 'user' [%o smap2])]
::  +group-request: one poke to groups.sig, the user's write path (the
::  Peers page and the tools, both under this shell). {group, members?,
::  make?, poke?, peek?, remove?}: each key present replaces that part of
::  the user's contribution to the group; `remove` drops it; a group named
::  with nothing else is declared. Apps never poke this: they state their
::  facts in their own groups.json, read at derivation. ~ on success.
++  group-request
  |=  [rail=rail:tarball sender=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m `'not an object')
  ?.  =(/apps/shell (scag 2 path.sender))  (pure:m `'not the user')
  ;<  roots=(list path)  bind:m  app-roots
  ?:  (lien roots |=(r=path =(r (scag (lent r) path.sender))))
    (pure:m `'an app states its groups in its own groups.json')
  =/  grp=(unit path)  (biff (jget jon 'group') |=(t=@t (rush t stap)))
  ?:  |(?=(~ grp) ?=(~ u.grp))  (pure:m `'group required (a path like /friends)')
  ;<  rec=json  bind:m  (read-groups-record rail)
  =/  gkey=@t  (spat u.grp)
  =/  cur=(map @t json)  (contribution rec gkey)
  =/  field
    |=  k=@t
    ^-  json
    =/  v  (~(get by p.jon) k)
    ?:(?=([~ %a *] v) u.v (fall (~(get by cur) k) [%a ~]))
  =/  remove=?  =(`[%b %.y] (~(get by p.jon) 'remove'))
  =/  next=(unit json)
    ?:  remove  ~
    :-  ~
    %-  pairs:enjs:format
    :~  ['members' (field 'members')]
        ['make' (field 'make')]
        ['poke' (field 'poke')]
        ['peek' (field 'peek')]
    ==
  =/  rec2=json  (set-contribution rec gkey next)
  ?:  =(rec2 rec)  (pure:m ~)
  ;<  ~  bind:m
    (put:io (nex-road:io rail [%& /permit %'groups.json']) [[/ %json] rec2])
  (pure:m ~)
::  +app-groups: one app's facts about usergroups, from the groups.json at
::  its root, within the top-level keys Permits granted it. A key naming
::  a group opens the app's own roads into it (roads only); a key ending
::  in a slash is a prefix the app runs groups under: each entry inside
::  is a group with members and roads. Roads are relative to the app's
::  root, so they can only ever name its own subtree.
++  app-groups
  |=  [app=path entry=json]
  =/  m  (fiber:fiber:nexus ,(list [grp=path members=(set @p) =weir:nexus]))
  ^-  form:m
  =/  granted=(set @t)
    ?.  ?=(%o -.entry)  ~
    =/  v  (~(get by p.entry) 'groups')
    ?.  ?=([~ %a *] v)  ~
    (sy (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j))))
  ?:  =(~ granted)  (pure:m ~)
  ;<  gv=(unit json)  bind:m  (peek-as:io [%& %& app %'groups.json'] ,json)
  ?~  gv  (pure:m ~)
  ?.  ?=(%o -.u.gv)  (pure:m ~)
  =/  strs
    |=  [g=json k=@t]
    ^-  (list @t)
    ?.  ?=(%o -.g)  ~
    =/  v  (~(get by p.g) k)
    ?.  ?=([~ %a *] v)  ~
    (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  =/  roads
    |=  [g=json k=@t]
    ^-  (set road:tarball)
    %-  sy
    %+  murn  (strs g k)
    |=  t=@t
    ^-  (unit road:tarball)
    =/  rel=(unit road:tarball)  (peers-parse-road t)
    ?~  rel  ~
    ?.  ?=(%& -.u.rel)  ~
    ?-  -.p.u.rel
      %&  `[%& %& (weld app path.p.p.u.rel) name.p.p.u.rel]
      %|  `[%& %| (weld app p.p.u.rel)]
    ==
  =/  weir-of  |=(g=json `weir:nexus`[(roads g 'make') (roads g 'poke') (roads g 'peek')])
  =/  is-prefix=$-(@t ?)  |=(k=@t =('/' (rear (trip k))))
  %-  pure:m
  %-  zing
  %+  turn  ~(tap by p.u.gv)
  |=  [key=@t g=json]
  ^-  (list [grp=path members=(set @p) =weir:nexus])
  ?.  (~(has in granted) key)  ~
  ?.  (is-prefix key)
    ::  a group it opens into: its own roads, never the roster
    =/  grp=(unit path)  (rush key stap)
    ?~  grp  ~
    [u.grp ~ (weir-of g)]~
  ::  a prefix it runs: every group inside, roster and roads
  =/  pre=(unit path)  (rush (crip (snip (trip key))) stap)
  ?~  pre  ~
  ?.  ?=(%o -.g)  ~
  %+  murn  ~(tap by p.g)
  |=  [sub=@t sg=json]
  ^-  (unit [grp=path members=(set @p) =weir:nexus])
  ::  a sub-key is a name under the prefix, spelled with or without a
  ::  leading slash. Absolute is fine too, as long as it IS under the
  ::  prefix: an app never names a group outside the key it was granted.
  =/  rest=(unit path)
    =/  tap=tape  (trip sub)
    ?~  tap  ~
    (rush (crip ?:(=('/' i.tap) tap ['/' tap])) stap)
  ?~  rest  ~
  =/  full=path
    ?:  =(u.pre (scag (lent u.pre) u.rest))  u.rest
    (weld u.pre u.rest)
  ?.  =(u.pre (scag (lent u.pre) full))  ~
  =/  members=(set @p)  (sy (murn (strs sg 'members') |=(t=@t (slaw %p t))))
  `[full members (weir-of sg)]
::  +gather-groups: every contribution to usergroups, each with who made
::  it. 'manual' is what the shell DECLARES: permit/groups.json, written
::  through the Peers page or the tools. 'shell' is what it DERIVES: its
::  storefront, a desk published, a name shared — each follows from a
::  feature, not from an entry. Everything else is one app, named by its
::  nexus root, declared in the groups.json at that root. The derivation
::  and the Peers page both read this.
++  gather-groups
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(list [grp=path by=@t members=(set @p) =weir:nexus]))
  ^-  form:m
  ;<  rec0=json  bind:m  (read-groups-record rail)
  ;<  rec=json  bind:m  (seed-groups-record rail rec0)
  =/  from-user=(list [grp=path by=@t members=(set @p) =weir:nexus])
    =/  sec=json  (user-section rec)
    ?.  ?=(%o -.sec)  ~
    %+  murn  ~(tap by p.sec)
    |=  [gkey=@t g=json]
    ^-  (unit [grp=path by=@t members=(set @p) =weir:nexus])
    =/  grp=(unit path)  (rush gkey stap)
    ?~  grp  ~
    =/  strs
      |=  k=@t
      ^-  (list @t)
      ?.  ?=(%o -.g)  ~
      =/  v  (~(get by p.g) k)
      ?.  ?=([~ %a *] v)  ~
      (murn p.u.v |=(j=json ?.(?=([%s *] j) ~ `p.j)))
    =/  roads  |=(k=@t (sy (murn (strs k) peers-parse-road)))
    `[u.grp 'manual' (sy (murn (strs 'members') |=(t=@t (slaw %p t)))) [(roads 'make') (roads 'poke') (roads 'peek')]]
  =/  base=[grp=path by=@t members=(set @p) =weir:nexus]
    :^  /public  'shell'  ~
    :+  ~  ~
    %-  sy
    ^-  (list road:tarball)
    :~  [%& %& /apps/shell %'public.json']
        [%& %& /apps/shell/share/public %'desks.json']
    ==
  ;<  names=(map path (set road:tarball))  bind:m  (read-shares rail /apps/shell)
  =/  from-names=(list [grp=path by=@t members=(set @p) =weir:nexus])
    %-  zing
    %+  turn  ~(tap by names)
    |=  [grp=path rs=(set road:tarball)]
    %+  turn  ~(tap in rs)
    |=  r=road:tarball
    ^-  [grp=path by=@t members=(set @p) =weir:nexus]
    [grp 'shell' ~ [~ ~ (sy ~[r])]]
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%& %| /apps/shell/desks] ~)
  =/  kids=(list @ta)  ?.(?=([%ball *] dv) ~ ~(tap in ~(key by dir.ball.dv)))
  ;<  shares=(list [path json])  bind:m  (gather-shares kids)
  =/  from-desks=(list [grp=path by=@t members=(set @p) =weir:nexus])
    %+  murn  shares
    |=  [grp=path entry=json]
    ^-  (unit [grp=path by=@t members=(set @p) =weir:nexus])
    =/  dir=@t  (fall (jget entry 'dir') '')
    ?:  =('' dir)  ~
    =/  dpath=path  /apps/shell/desks/[`@ta`dir]
    ::  the shell's grant, on the user's publish: a desk wrapper has no
    ::  app of its own
    :-  ~
    :^  grp  'shell'  ~
    :+  ~  ~
    (sy ~[`road:tarball`[%& %| (weld dpath /desk/code)] `road:tarball`[%& %& dpath %'version.json']])
  ;<  approved=(map @t json)  bind:m  (read-approved rail)
  ;<  from-apps=(list [grp=path by=@t members=(set @p) =weir:nexus])  bind:m
    =/  m  (fiber:fiber:nexus ,(list [grp=path by=@t members=(set @p) =weir:nexus]))
    =/  todo=(list [app=@t entry=json])  ~(tap by approved)
    |-  ^-  form:m
    ?~  todo  (pure:m ~)
    =/  root=(unit path)  (soft-path app.i.todo)
    ?~  root  $(todo t.todo)
    ?.  =('granted' (fall (jget entry.i.todo 'verdict') ''))  $(todo t.todo)
    ;<  mine=(list [grp=path members=(set @p) =weir:nexus])  bind:m
      (app-groups u.root entry.i.todo)
    ;<  rest=(list [grp=path by=@t members=(set @p) =weir:nexus])  bind:m  $(todo t.todo)
    %-  pure:m
    %+  weld
      (turn mine |=([grp=path members=(set @p) w=weir:nexus] [grp app.i.todo members w]))
    rest
  (pure:m :(weld from-user [base ~] from-names from-desks from-apps))
::  +apply-groups: every group's who.ships and how.weir, rewritten whole
::  from the union of every contribution (+gather-groups). A group nobody
::  contributes to is culled; /public always stands.
++  apply-groups
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  all=(list [grp=path by=@t members=(set @p) =weir:nexus])  bind:m  (gather-groups rail)
  =/  union=(map path [members=(set @p) =weir:nexus])
    %+  roll  all
    |=  [[grp=path * members=(set @p) w=weir:nexus] u=(map path [members=(set @p) =weir:nexus])]
    =/  cur  (fall (~(get by u) grp) `[members=(set @p) =weir:nexus]`[~ *weir:nexus])
    %+  ~(put by u)  grp
    :-  (~(uni in members.cur) members)
    :*  (~(uni in make.weir.cur) make.w)
        (~(uni in poke.weir.cur) poke.w)
        (~(uni in peek.weir.cur) peek.w)
    ==
  ::  write what changed
  =/  groups=(list [grp=path members=(set @p) =weir:nexus])  ~(tap by union)
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    |-  ^-  form:m
    ?~  groups  (pure:m ~)
    =/  dir=path  (peers-storage grp.i.groups)
    ;<  who=(unit (set @p))  bind:m  (peek-as:io [%& %& dir %'who.ships'] ,(set @p))
    ;<  how=(unit weir:nexus)  bind:m  (peek-as:io [%& %& dir %'how.weir'] ,weir:nexus)
    ;<  ~  bind:m
      ?:  =(who `members.i.groups)  (pure:m ~)
      (put:io [%& %& dir %'who.ships'] [[/ %ships] members.i.groups])
    ;<  ~  bind:m
      ?:  =(how `weir.i.groups)  (pure:m ~)
      (put:io [%& %& dir %'how.weir'] [[/ %weir] weir.i.groups])
    $(groups t.groups)
  ::  cull what nobody names any more
  ;<  ug=view:nexus  bind:m  (peek:io [%& %| /sys/ames/usergroups] ~)
  ?.  ?=([%ball *] ug)  (pure:m ~)
  =/  found=(list [name=path grp=ball:tarball])  (peers-find / ball.ug)
  =/  gone=(list path)
    %+  murn  found
    |=  [name=path *]
    ?:  |(=(/public name) (~(has by union) name))  ~
    `name
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    |-  ^-  form:m
    ?~  gone  (pure:m ~)
    ;<  *  bind:m  (cull-soft:io [%& %| (peers-storage i.gone)])
    $(gone t.gone)
  ::  a category directory the last group left is itself gone: /a/b.grp
  ::  culled leaves /a, which is no group and names nothing
  ;<  ug2=view:nexus  bind:m  (peek:io [%& %| /sys/ames/usergroups] ~)
  ?.  ?=([%ball *] ug2)  (pure:m ~)
  =/  cats=(list @ta)
    %+  murn  ~(tap by dir.ball.ug2)
    |=  [nm=@ta sub=ball:tarball]
    ^-  (unit @ta)
    ?:  ?=(^ (peers-group-of ~[nm]))  ~
    ?.  =(~ (peers-find / sub))  ~
    `nm
  |-  ^-  form:m
  ?~  cats  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io [%& %| /sys/ames/usergroups/[i.cats]])
  $(cats t.cats)
::  +seed-groups-record: a ship whose groups predate the record keeps
::  them: every group's members, and the roads of every group but
::  /public (whose roads are derived), become the user's section, once.
++  seed-groups-record
  |=  [rail=rail:tarball rec=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?.  ?=(%o -.rec)  (pure:m rec)
  ?.  =(~ p.rec)  (pure:m rec)
  ;<  ug=view:nexus  bind:m  (peek:io [%& %| /sys/ames/usergroups] ~)
  ?.  ?=([%ball *] ug)  (pure:m rec)
  =/  found=(list [name=path grp=ball:tarball])  (peers-find / ball.ug)
  =/  roads  |=(s=(set road:tarball) ^-(json a+(turn ~(tap in s) |=(r=road:tarball s+(crip (peers-road-text r))))))
  =/  user=(map @t json)
    %-  ~(gas by *(map @t json))
    %+  murn  found
    |=  [name=path grp=ball:tarball]
    ^-  (unit [@t json])
    ::  /public is the shell's to name; the user's record carries only
    ::  what the user adds to it
    ?:  =(/public name)  ~
    =/  who=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'who.ships'])
    =/  how=(unit sang:tarball)  (~(get ba:tarball grp) [/ %'how.weir'])
    =/  members=(set @p)
      ?~  who  ~
      =/  r  (mule |.(!<((set @p) (need-vase:tarball u.who))))
      ?:(?=(%| -.r) ~ p.r)
    =/  =weir:nexus
      ?:  |(=(/public name) ?=(~ how))  *weir:nexus
      =/  r  (mule |.(!<(weir:nexus (need-vase:tarball u.how))))
      ?:(?=(%| -.r) *weir:nexus p.r)
    :-  ~
    :-  (spat name)
    %-  pairs:enjs:format
    :~  ['members' a+(turn ~(tap in members) |=(p=@p s+(scot %p p)))]
        ['make' (roads make.weir)]
        ['poke' (roads poke.weir)]
        ['peek' (roads peek.weir)]
    ==
  ?:  =(~ user)  (pure:m rec)
  =/  rec2=json  [%o (~(put by *(map @t json)) 'user' [%o user])]
  ;<  ~  bind:m
    (put:io (nex-road:io rail [%& /permit %'groups.json']) [[/ %json] rec2])
  (pure:m rec2)
::  a road as the panes show it: /dir/ for a subtree, /dir/file.ext for a grub
::  +peers-parse-road: a road from its text, or nothing. A trailing slash
::  names a subtree and is dropped before parsing; a last segment with a
::  dot is a file. Text that does not parse yields NO road: a bad line
::  must never widen into "/", which is everything.
++  peers-parse-road
  |=  t=@t
  ^-  (unit road:tarball)
  =/  tap=tape  (trip t)
  =/  trimmed=tape
    ?:  &((gth (lent tap) 1) =('/' (rear tap)))  (snip tap)
    tap
  ?:  =("/" trimmed)  `[%& %| /]
  =/  pax=(unit path)  (rush (crip trimmed) stap)
  ?~  pax  ~
  ?~  u.pax  ~
  =/  last=tape  (trip (rear u.pax))
  ?~  (find "." last)
    `[%& %| u.pax]
  `[%& %& (snip `path`u.pax) (rear u.pax)]
++  peers-road-text
  |=  =road:tarball
  ^-  tape
  ?-  -.road
      %&
    ?-  -.p.road
      %&  "{(spud path.p.p.road)}/{(trip name.p.p.road)}"
      %|  (spud p.p.road)
    ==
      %|
    ?-  -.q.p.road
      %&  "{(spud path.p.q.p.road)}/{(trip name.p.q.p.road)}"
      %|  (spud p.q.p.road)
    ==
  ==
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
::  how a github entry's checkout becomes live code, which is also what
::  its build chat's repo_deploy tool does after a commit:
::    %desk  a /desk follows the tree's /code and deploys when its
::           code/version.json is bumped (the stock app path)
::    %clay  the tree's <dir> IS a Clay desk: deploying commits it into
::           the named desk, the way a Unix |commit does (the kernel)
+$  deploy-spec
  $%  [%desk ~]
      [%clay desk=@tas dir=@t]
  ==
+$  stock-entry
  $%  [%github name=@t repo=@t ref=@t deploy=deploy-spec]
  ==
++  default-repos
  ^-  (list stock-entry)
  ::  every entry is a github repo the forge mirrors. The forge itself is
  ::  not one: it is a nexus of this shell at /apps/shell/forge. These
  ::  entries are housed in it and find it by name.
  :~  [%github 'hatchery' 'gwbtc/hatchery' 'main' [%desk ~]]
      [%github 'grubbery' 'gwbtc/grubbery' 'develop' [%clay %grubbery 'desk']]
  ==
::  deploy-json: the deploy spec as the repo's config.json carries it
::  (and the forge copies into the repo clanker's config for repo_deploy)
++  deploy-json
  |=  d=deploy-spec
  ^-  json
  ?-  -.d
    %desk  (pairs:enjs:format ~[['kind' s+'version'] ['file' s+'code/version.json']])
    %clay  (pairs:enjs:format ~[['kind' s+'clay'] ['desk' s+desk.d] ['dir' s+dir.d]])
  ==
::  stock-name: an entry's name.
++  stock-name  |=(e=stock-entry name.e)
::  repo-config: the config.json a git_repo instance is seeded with.
::
++  repo-config
  |=  [repo=@t ref=@t deploy=deploy-spec]
  ^-  json
  %-  pairs:enjs:format
  :~  ['repo' s+repo]
      ['ref' s+ref]
      ['token' s+'']
      ['poll' n+'15']
      ['deploy' (deploy-json deploy)]
  ==
::  ensure-pairing: idempotently stand up ONE git_repo + desk pairing.
::  Guarded makes (skip what exists) + a replace-in-place source poke, so
::  re-running is safe. The desk follows the repo's /data/tree/code and
::  the stock desk machinery owns the rest (version watch, sync, bill).
::
::  +await-forge: the forge's root lane, waiting on /sys/link/forge until
::  the name is claimed (the way a desk waits for an @name source)
::
++  await-forge
  =/  m  (fiber:fiber:nexus ,(unit lane:tarball))
  ^-  form:m
  =/  link=road:tarball  [%& %& /sys/link/forge %'dest.lanes']
  |-  ^-  form:m
  ;<  fr=(unit lane:tarball)  bind:m  (resolve-link:io '@forge')
  ?:  ?=([~ %| *] fr)  (pure:m fr)
  ~&  >>  %shell-pairing-awaiting-forge
  ;<  *  bind:m  (keep:io /forge-link link ~)
  ;<  *  bind:m  (take-news:io /forge-link)
  ;<  ~  bind:m  (drop:io /forge-link link)
  $
++  ensure-pairing
  |=  entry=stock-entry
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@t  (stock-name entry)
  =/  desk-dir=path  /apps/shell/desks/[(cat 3 `@ta`name '.desk')]
  ::  forge houses the repo instances; it is found by name. On a fresh
  ::  ship the name may not be claimed yet when the first entry is
  ::  reached: wait for the link rather than skip the entry.
  ;<  fr=(unit lane:tarball)  bind:m  await-forge
  ?.  ?=([~ %| *] fr)
    ~&  >>>  %shell-pairing-no-forge
    (pure:m ~)
  =/  forge=path  p.u.fr
  ::  the code path the desk will follow: a github entry's by the forge's
  ::  NAME, so the desk resolves it where the forge is, now and after a move
  =/  code=@t  (crip "@forge/repos/{(trip name)}.git_repo/data/tree/code")
  =/  repo-dir=path  (weld forge /repos/[(cat 3 `@ta`name '.git_repo')])
  ::  ORDER MATTERS HERE, and it used to leave a user with a repo, no desk,
  ::  and nothing at all in the log.
  ::
  ::  The fresh pull was fired at the END of step 1 as a HARD poke, with the
  ::  desk made after it. A pull is a clone on the run.git-action serial lane;
  ::  if that fetch is lost, this fiber blocks forever on the ack and steps 2
  ::  and 3 never run. A blocked fiber has not failed, so there is nothing to
  ::  read anywhere — the symptom is simply an absent desk.
  ::
  ::  So: everything that needs no network is made FIRST, and the network is
  ::  touched LAST and softly. A slow or failed fetch now costs this sync its
  ::  "latest" and nothing else; the desk exists and picks the code up when it
  ::  lands, and the repo's own poll loop pulls again on its interval.
  ::
  ::  1. the repo instance and its remote — no fetch yet
  ;<  ~  bind:m
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
    =/  cur-deploy=(unit json)  (~(get by cur-obj) 'deploy')
    =/  want-deploy=json  (deploy-json deploy.entry)
    ;<  ~  bind:m
      ?:  ?&  =(cur-repo repo.entry)
              =(cur-ref ref.entry)
              =(cur-deploy `want-deploy)
          ==
        (pure:m ~)
      ::  config.json is a plain data grub (no poke handler), so overwrite
      ::  it with over:io — poke:io would nack and crash this handler.
      ::  A user's other fields (author, account, token) are kept.
      =/  cfg=json  (repo-config repo.entry ref.entry deploy.entry)
      =/  merged=json
        ?.  ?=([%o *] cfg)  cfg
        [%o (~(uni by cur-obj) p.cfg)]
      (over:io [%& %& repo-dir %'config.json'] [[/ %json] merged])
    ::  the poll daemon reads poll.json, not config.json's `poll`: a repo
    ::  is seeded with minutes 0 (off) and nothing ever copied the cadence
    ::  across, so a stock mirror only pulled when something poked it —
    ::  a version pushed to github never reached the distributor on its
    ::  own. Turn the daemon on once; a cadence someone set stays.
    (ensure-poll repo-dir)
  ::  2. the desk, BEFORE any network work. Only a %desk deploy has one:
  ::  a %clay entry (the kernel) deploys by committing its tree into a
  ::  Clay desk, which its build chat's repo_deploy does; no follower
  =/  follower=?  ?=(%desk -.deploy.entry)
  ;<  has-desk=?  bind:m  (peek-exists:io [%& %| desk-dir])
  ;<  ~  bind:m
    ?:  |(has-desk !follower)  (pure:m ~)
    (make:io [%& %| desk-dir] &+`bole:tarball`[`[`[/ %desk] ~ %.n ~] ~])
  ::  3. always wire the desk's source at the computed code path
  ;<  ~  bind:m
    ?.  follower  (pure:m ~)
    (poke:io [%& %& desk-dir %'source.json'] [[/ %json] (pairs:enjs:format ~[['code' s+code]])])
  ::  4. LAST, and SOFT: ask for a fresh fetch, so "sync" still means "pull
  ::  latest" when the network cooperates. Soft because a nack here would
  ::  otherwise roll back steps 1-3 with it.
  ;<  *  bind:m
    %+  poke-soft:io  [%& %& repo-dir %'run.git-action']
    [[/ %json] (pairs:enjs:format ~[['command' s+'pull']])]
  (pure:m ~)
::  ensure-poll: turn a stock mirror's poll daemon on if it is off. Runs
::  from +ensure-pairing and on every shell boot, so a ship that already
::  has its mirrors gets them polling without anyone pressing Sync.
::
++  ensure-poll
  |=  repo-dir=path
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  poll=(unit json)  bind:m
    (peek-as:io [%& %& repo-dir %'poll.json'] ,json)
  =/  minutes=@ud
    ?~  poll  0
    ?.  ?=([%o *] u.poll)  0
    =/  v  (~(get by p.u.poll) 'minutes')
    ?:(?=([~ %n *] v) (fall (rush p.u.v dem) 0) 0)
  ?.  =(0 minutes)  (pure:m ~)
  (over:io [%& %& repo-dir %'poll.json'] [[/ %json] (pairs:enjs:format ~[['minutes' n+'15']])])
::  ensure-polls: every github stock entry whose mirror exists
::
++  ensure-polls
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  todo=(list stock-entry)  default-repos
  ;<  fr=(unit lane:tarball)  bind:m  (resolve-link:io '@forge')
  ?.  ?=([~ %| *] fr)  (pure:m ~)
  |-  ^-  form:m
  ?~  todo  (pure:m ~)
  =/  repo-dir=path  (weld p.u.fr /repos/[(cat 3 `@ta`(stock-name i.todo) '.git_repo')])
  ;<  has=?  bind:m  (peek-exists:io [%& %| repo-dir])
  ;<  ~  bind:m  ?.(has (pure:m ~) (ensure-poll repo-dir))
  $(todo t.todo)
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
::  +forge-repos: every repo in the forge, as a source a desk can follow.
::
::    name   the repo without its .git_repo suffix — the desk's name
::    code   the source road, by the forge's NAME, so it keeps resolving
::           if the forge moves
::    ready  the checkout has a /code directory. A repo that has never
::           been pulled has none yet, and the UI greys it out rather
::           than offering an install that would follow nothing.
::
::  No forge, or no /repos, is an empty list, not an error: a ship that
::  has not provisioned one yet has nothing to show, which is what the
::  tab should say.
::
++  forge-repos
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  fr=(unit lane:tarball)  bind:m  (resolve-link:io '@forge')
  ?.  ?=([~ %| *] fr)  (pure:m a+~)
  =/  repos-dir=path  (weld p.u.fr /repos)
  ;<  =view:nexus  bind:m  (peek-shallow:io [%& %| repos-dir] ~)
  ?.  ?=([%ball *] view)  (pure:m a+~)
  =/  kids=(list @ta)  ~(tap in ~(key by dir.ball.view))
  =|  acc=(list json)
  |-  ^-  form:m
  ?~  kids  (pure:m a+(flop acc))
  =/  nam=tape  (trip i.kids)
  =/  len=@ud  (lent nam)
  ?.  &((gth len 9) =(".git_repo" (slag (sub len 9) nam)))
    $(kids t.kids)
  =/  short=@t  (crip (scag (sub len 9) nam))
  ;<  ready=?  bind:m
    (peek-exists:io [%& %| (weld repos-dir /[i.kids]/data/tree/code)])
  =/  one=json
    %-  pairs:enjs:format
    :~  ['name' s+short]
        ['code' s+(crip "@forge/repos/{nam}/data/tree/code")]
        ['ready' b+ready]
    ==
  $(kids t.kids, acc [one acc])
::
++  stock-status
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  todo=(list stock-entry)  default-repos
  =|  acc=(list json)
  |-  ^-  form:m
  ?~  todo  (pure:m a+(flop acc))
  ::  only a %desk entry belongs here. A %clay entry is the ship's own
  ::  source: it deploys by committing its tree into a Clay desk, the way
  ::  a |commit does, and never becomes a desk at all. Listing it on a
  ::  tab whose verb is "install" offered something that does not exist.
  ::  Its repo mirror is the forge's business, not the desk installer's.
  ?.  ?=(%desk -.deploy.i.todo)  $(todo t.todo)
  =/  name=@t  (stock-name i.todo)
  =/  desk-dir=path  /apps/shell/desks/[(cat 3 `@ta`name '.desk')]
  ;<  has-desk=?  bind:m  (peek-exists:io [%& %| desk-dir])
  ;<  src=(unit json)  bind:m
    ?.  has-desk  (pure:(fiber:fiber:nexus ,(unit json)) ~)
    (peek-as:io [%& %& desk-dir %'source.json'] ,json)
  ::  a desk entry is set up when its desk exists and follows a source.
  =/  synced=?
    ?&  has-desk
        ?=(^ src)
        ?=([%o *] u.src)
        ?=([~ %s *] (~(get by p.u.src) 'code'))
    ==
  =/  fields=(list [@t json])
    :~  ['name' s+name]  ['kind' s+'github']
        ['repo' s+repo.i.todo]  ['ref' s+ref.i.todo]  ['synced' b+synced]
        ['deploy' (deploy-json deploy.i.todo)]
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
    (peek:io [%& %| /apps/shell/peers] ~)
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
    (peek-shallow:io [%& %| /apps/shell/desks] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  kids=(list @ta)  ~(tap in ~(key by dir.ball.view))
  =|  acc=(map @t @t)
  |-
  ?~  kids  (pure:m acc)
  ;<  src=(unit json)  bind:m
    (peek-as:io [%& %& /apps/shell/desks/[i.kids] %'source.json'] ,json)
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
  ::  the mirror holds the peer's desk cards, enriched by the mirror
  ::  fiber when the peer's storefront last changed; nothing here reaches
  ::  the peer, so a dead peer costs this listing nothing
  =/  cards=(list json)
    ?:  (is-boom:tarball sang)  ~
    =/  r=(each json tang)
      (mule |.(!<(json (need-vase:tarball sang))))
    ?:  ?=(%| -.r)  ~
    ?.  ?=(%a -.p.r)  ~
    p.p.r
  =/  apps=(list json)  (turn cards |=(c=json (mark-installed c srcs)))
  (pure:m (pairs:enjs:format ~[['ship' s+s] ['apps' a+apps]]))
::
++  peer-apps
  |=  [s=@t entries=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  entries  (pure:m ~)
  ::  each card costs remote peeks into the peer; a peer that stops
  ::  answering mid-way costs this mirror a wait and a bare card, never
  ::  the listing
  ;<  one=(unit json)  bind:m
    ((with-timeout:io ,json) /enrich ~s20 (peer-app s i.entries))
  ~?  >>  ?=(~ one)  [%shell-peer-card-timeout s (jstr i.entries 'name')]
  =/  card=json  ?^(one u.one (bare-card s i.entries))
  ;<  rest=(list json)  bind:m  $(entries t.entries)
  (pure:m [card rest])
::  +bare-card: a peer's desk card with nothing fetched from the peer:
::  what its storefront entry alone says
::
++  bare-card
  |=  [s=@t entry=json]
  ^-  json
  =/  ename=@t  (jstr entry 'name')
  =/  dir=@t    (jstr entry 'dir')
  =/  code-src=@t  (cat 3 s (jstr entry 'code'))
  %-  pairs:enjs:format
  :~  ['path' s+(cat 3 '/apps/shell/desks/' dir)]
      ['name' s+ename]
      ['title' s+ename]
      ['info' s+'']
      ['color' s+'']
      ['version' ~]
      ['icon' ~]
      ['ship' s+s]
      ['code' s+code-src]
      ['source' s+code-src]
  ==
::  +mark-installed: a mirrored card plus whether this ship follows it
::  (a local desk whose source is the card's code) and as what
::
++  mark-installed
  |=  [card=json srcs=(map @t @t)]
  ^-  json
  ?.  ?=([%o *] card)  card
  =/  src=@t  (jstr card 'source')
  =/  loc=(unit @t)  (~(get by srcs) src)
  :-  %o
  %-  ~(gas by p.card)
  :~  ['installed' b+?=(^ loc)]
      ['local' ?~(loc ~ s+u.loc)]
  ==
::  +peer-app: one published desk as a card — tile metadata and icon from
::  a shallow peek of its code tree, version from canonical file names.
::
++  peer-app
  |=  [s=@t entry=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  dir=@t    (jstr entry 'dir')       :: the desk's dir name on the peer
  =/  ename=@t  (jstr entry 'name')      :: display name (already slugged)
  =/  codep=@t  (jstr entry 'code')      :: "/apps/shell/desks/<dir>/desk/code"
  ?:  =('' dir)  (pure:m entry)          :: malformed card — pass through
  ::  the desk's root on the peer is wherever its card says the code is,
  ::  two levels up from /desk/code: never guess the layout of their ship
  =/  codepath=path  (fall (rush codep stap) /)
  =/  n=@ud  (lent codepath)
  =/  desk-root=path
    ?.  &((gth n 2) =(/desk/code (slag (sub n 2) codepath)))
      /apps/shell/desks/[`@ta`dir]
    `path`(scag (sub n 2) codepath)
  =/  base=path  (weld /sys/ames/ships/[s]/root desk-root)
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
  :~  ['path' s+(spat desk-root)]
      ['name' s+ename]
      ['title' s+title]
      ['info' s+info]
      ['color' s+color]
      ['version' ?~(ver ~ s+u.ver)]
      ['icon' icon-url]
      ['ship' s+s]
      ['code' s+code-src]
      ['source' s+code-src]
  ==
::  +try-version: a remote desk's version through canonical file names,
::  since its root is not listable.
::
++  try-version
  |=  base=path
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ::  a desk's root version.json is the one a peer's share grants a read
  ::  on; the older spellings are tried only after it, so a published desk
  ::  costs one peek and no vetoes
  =/  names=(list @ta)  ~[%'version.json' %'version.txt' %'version.ud']
  |-  ^-  form:m
  ?~  names  (pure:m ~)
  ;<  vv=view:nexus  bind:m  (peek:io [%& %& base i.names] ~)
  ?.  ?=([%file *] vv)  $(names t.names)
  ?:  (is-boom:tarball sang.vv)  $(names t.names)
  =/  nun  (sang-noun:tarball sang.vv)
  ?+    p.sang.vv  $(names t.names)
      [~ %json]
    =/  j  ((soft json) nun)
    ?~  j  $(names t.names)
    =/  v=(unit @t)  (version-in-json u.j)
    ?~  v  $(names t.names)
    (pure:m v)
      ::  a desk mirrors its source's version file as it found it; a
      ::  source kept as raw text holds the same json in mime
      [~ %mime]
    =/  mm  ((soft mime) nun)
    ?~  mm  $(names t.names)
    =/  j=(unit json)  (de:json:html q.q.u.mm)
    ?~  j  $(names t.names)
    =/  v=(unit @t)  (version-in-json u.j)
    ?~  v  $(names t.names)
    (pure:m v)
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
::  +version-in-json: the `version` of a version.json, as text
::
++  version-in-json
  |=  j=json
  ^-  (unit @t)
  ?.  ?=([%o *] j)  ~
  =/  v=(unit json)  (~(get by p.j) 'version')
  ?~  v  ~
  ?+  -.u.v  ~
    %n  `p.u.v
    %s  `p.u.v
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
    (peek:io [%& %| /apps/shell/desks] ~)
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
    (peek-as:io [%& %& /apps/shell/desks/[app] %'source.json'] ,json)
  =/  code=@t  ?~(sj '' (jstr u.sj 'code'))
  ::  share: the usergroups this desk is published to (its share set),
  ::  so the Installed tab can show and change who may follow it
  ;<  shr=(unit (set path))  bind:m
    (peek-as:io [%& %& /apps/shell/desks/[app] %'share.usergroups'] ,(set path))
  =/  groups=(list path)  (sort ~(tap in (fall shr ~)) aor)
  %-  pure:m  :-  ~
  %-  pairs:enjs:format
  :~  ['name' s+app]
      ['source' ?:(=('' code) ~ s+code)]
      ['url' s+(cat 3 '/grubbery/desk/' (app-slug app))]
      ['share' a+(turn groups |=(g=path s+(spat g)))]
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
  [%& %& /sys/ames/ships/[s]/root/apps/shell/share/public %'desks.json']
::  +peer-pub-road-legacy: the same storefront on a peer whose shell is
::  still a desk app at /apps/shell.shell.
::
++  peer-pub-road-legacy
  |=  s=@t
  ^-  road:tarball
  [%& %& /sys/ames/ships/[s]/root/apps/'shell.shell'/share/public %'desks.json']
::  +take-pub-news: wake on news from either storefront keep.
::
++  take-pub-news
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  |(=(/pub wire.u.in) =(/pub-legacy wire.u.in))  [%done ~]
    [%skip ~]
  ==
::
++  jget
  |=  [j=json k=@t]
  ^-  (unit @t)
  ?.  ?=([%o *] j)  ~
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
::  +carry-links: the record was permit/links.json before it was
::  permit/link.json, to match the link.json an app declares. The shares
::  in it are the user's decisions and cannot be recomputed, so they are
::  carried over once and the old grub culled. Delete this when no ship
::  is still holding the plural name.
::
++  carry-links
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  old=road:tarball  (nex-road:io rail [%& /permit %'links.json'])
  ;<  ov=(unit json)  bind:m  (peek-as:io old ,json)
  ?.  ?=([~ %o ^] ov)  (pure:m ~)
  ;<  cur=(map @t json)  bind:m  (read-links rail)
  ;<  ~  bind:m
    ?^  cur  (pure:m ~)
    (put:io (nex-road:io rail [%& /permit %'link.json']) [[/ %json] u.ov])
  ;<  *  bind:m  (cull-soft:io old)
  (pure:m ~)
::  +read-links: the user's link record, permit/link.json, by bare name.
::
++  read-links
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t json))
  ^-  form:m
  ;<  lv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /permit %'link.json']) ,json)
  (pure:m ?~(lv ~ ?.(?=(%o -.u.lv) ~ p.u.lv)))
::  +bare-name: a name without its @ — the key links.json uses.
::
++  bare-name
  |=  nm=@t
  ^-  @t
  =/  t=tape  (trip nm)
  ?~(t nm ?:(=('@' i.t) (crip t.t) nm))
::  +link-groups: the usergroups one link record entry is open to.
::
++  link-groups
  |=  e=json
  ^-  (list path)
  ?.  ?=(%o -.e)  ~
  =/  v  (~(get by p.e) 'share')
  ?:  ?=([~ %s *] v)
    ?:(=('public' p.u.v) ~[/public] (drop (soft-path p.u.v)))
  ?.  ?=([~ %a *] v)  ~
  (murn p.u.v |=(g=json ?.(?=([%s *] g) ~ (soft-path p.g))))
::  +read-shares: the link record inverted for granting — usergroup path
::  -> the /sys/link dest.lanes roads it may peek. A name's share is a
::  property of the NAME: one road, one record, whoever asked for it.
::
++  read-shares
  |=  [rail=rail:tarball nex-dir=path]
  =/  m  (fiber:fiber:nexus ,(map path (set road:tarball)))
  ^-  form:m
  ;<  links=(map @t json)  bind:m  (read-links rail)
  %-  pure:m
  %+  roll  ~(tap by links)
  |=  [[nm=@t e=json] out=(map path (set road:tarball))]
  =/  road=road:tarball  (link-road (cat 3 '@' nm))
  %+  roll  (link-groups e)
  |=  [g=path acc=_out]
  (~(put by acc) g (~(put in (fall (~(get by acc) g) ~)) road))
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
::  +notify-target: the notifications nexus's main.sig, found by name
::
++  notify-target
  (resolve-link-at:io '@notifications' [%& / %'main.sig'])
::  +register-notify: register the shell with the notifications nexus so
::  its notify pokes are accepted (senders must be registered). Poke-soft
::  so a failed registration is logged, not fatal — re-run on every reload.
::
++  register-notify
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  payload=json
    (pairs:enjs:format ~[['action' s+'register'] ['name' s+'permissions']])
  ;<  nt=(unit road:tarball)  bind:m  notify-target
  ?~  nt  (pure:m ~)
  ;<  *  bind:m  (poke-soft:io u.nt [[/ %json] payload])
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
      (same (road-strs a 'groups') (road-strs b 'groups'))
      =((name-shares a) (name-shares b))
  ==
::  +name-shares: the ask's `names` as a comparable list — each claimed
::  name with the groups it asks to be opened to, both sorted. A change
::  here is a change of audience, so it reopens the ask like any road.
::
++  name-shares
  |=  a=json
  ^-  (list [@t (list @t)])
  =/  v  ?.(?=(%o -.a) ~ (~(get by p.a) 'names'))
  ?.  ?=([~ %a *] v)  ~
  %+  sort
    %+  murn  p.u.v
    |=  n=json
    ^-  (unit [@t (list @t)])
    ?.  ?=(%o -.n)  ~
    =/  al=@t  (fall (jget n 'alias') '')
    ?:  =('' al)  ~
    =/  gs  (~(get by p.n) 'groups')
    :-  ~
    :-  al
    %+  sort
      ?.  ?=([~ %a *] gs)  ~
      (murn p.u.gs |=(g=json ?.(?=([%s *] g) ~ `p.g)))
    aor
  |=([x=[al=@t *] y=[al=@t *]] (aor al.x al.y))
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
  ::  /apps/shell/desks/<desk>/desk/data/<app> -> "<desk>/<app>".
  =/  nm=@t
    ?:  ?=([%apps %shell %desks @ %desk %data @ ~] pax)
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
  ;<  nt=(unit road:tarball)  bind:m  notify-target
  ;<  err=(unit tang)  bind:m
    ?~  nt  (pure:(fiber:fiber:nexus ,(unit tang)) `~[leaf+"notifications is not in /sys/link"])
    (poke-soft:io u.nt [[/ %json] payload])
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
    ;<  ~  bind:m  (do-approve-weir rail app picks granted hidden now)
    ::  the name shares the user ticked, into the one record that holds
    ::  them. A name the app declared and the user left empty is closed.
    =/  shares=json  (fall (~(get by p.jon) 'shares') [%o ~])
    ?.  ?=(%o -.shares)  (pure:m ~)
    (set-link-shares rail ~(tap by p.shares))
  ?:  ?&(=('deny-weir' act) ?!(=('' app)))
    (do-deny-weir rail app now)
  ?:  =('alias-share' act)
    ?:  =('' alias)  (pure:m ~)
    (set-link-shares rail ~[[alias (fall (~(get by p.jon) 'share') ~)]])
  ::  a name of your own: {alias, path} points it, {alias} alone drops it
  ?:  =('link-set' act)
    ?:  =('' alias)  (pure:m ~)
    (set-user-link rail alias ?:(=('' path) ~ `path))
  ?:  ?&  ?|(=('alias-suppress' act) =('alias-unsuppress' act))
          ?!(=('' alias))
          ?!(=('' path))
      ==
    (do-suppress rail alias path =('alias-suppress' act))
  (pure:m ~)
::  +set-link-shares: record which usergroups may resolve each name, in
::  permit/link.json. An empty list closes the name; an entry left with
::  neither a share nor a path of yours goes. Writing the record IS the
::  nudge: usergroups.sig re-derives the group grants on the news.
::
++  set-link-shares
  |=  [rail=rail:tarball shares=(list [name=@t groups=json])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(map @t json)  bind:m  (read-links rail)
  =/  nxt=(map @t json)
    %+  roll  shares
    |=  [[name=@t groups=json] acc=_cur]
    =/  key=@t  (bare-name name)
    =/  e=(map @t json)
      =/  g  (~(get by acc) key)
      ?.(?=([~ %o *] g) ~ p.u.g)
    =/  empty=?  |(?=(~ groups) &(?=([%a *] groups) =(~ p.groups)))
    =/  e2=(map @t json)
      ?:(empty (~(del by e) 'share') (~(put by e) 'share' groups))
    ?:(=(~ e2) (~(del by acc) key) (~(put by acc) key [%o e2]))
  ?:  =(nxt cur)  (pure:m ~)
  (put:io (nex-road:io rail [%& /permit %'link.json']) [[/ %json] [%o nxt]])
::  +set-user-link: declare a name of your own, pointing at a path, or
::  drop that declaration (path=~). Its share, if any, stays.
::
++  set-user-link
  |=  [rail=rail:tarball name=@t path=(unit @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(map @t json)  bind:m  (read-links rail)
  =/  key=@t  (bare-name name)
  =/  e=(map @t json)
    =/  g  (~(get by cur) key)
    ?.(?=([~ %o *] g) ~ p.u.g)
  =/  e2=(map @t json)
    ?~  path  (~(del by e) 'path')
    (~(put by e) 'path' s+u.path)
  =/  nxt=(map @t json)
    ?:(=(~ e2) (~(del by cur) key) (~(put by cur) key [%o e2]))
  ?:  =(nxt cur)  (pure:m ~)
  ;<  ~  bind:m
    (put:io (nex-road:io rail [%& /permit %'link.json']) [[/ %json] [%o nxt]])
  ::  a name nobody claims any more leaves no /sys/link behind
  ;<  ~  bind:m  (build-links rail)
  ;<  ~  bind:m  (build-aliases rail)
  (build-asks rail)
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
  ;<  pv=view:nexus  bind:m
    ?:  ?=([%file *] pv)  (pure:(fiber:fiber:nexus ,view:nexus) pv)
    (peek:io (peer-pub-road-legacy s) ~)
  ?.  ?=([%file *] pv)
    ~&  >>  [%shell-peer-unreachable s]
    (pure:m ~)
  ?:  (is-boom:tarball sang.pv)  (pure:m ~)
  =/  res=(each json tang)
    (mule |.(!<(json (need-vase:tarball sang.pv))))
  ?:  ?=(%| -.res)  (pure:m ~)
  ::  the storefront names desks; the cards other pages show need the
  ::  peer's tile, icon and version too. Fetch them HERE, once per change
  ::  of the storefront, so the listing endpoint reads only this mirror.
  =/  entries=(list json)  ?.(?=([%a *] p.res) ~ p.p.res)
  ;<  cards=(list json)  bind:m  (peer-apps s entries)
  (replace:io a+cards)
::
+$  tile
  $:  name=@ta
      title=@t
      info=@t
      color=@t
      image=@t
      href=@t
      ::  which launcher tab the tile sits in: 'app', 'utility' or
      ::  'other'. A tile.json that does not say lands in 'other' — the
      ::  junk drawer is the nudge to declare one. Tiles the shell itself
      ::  ships set theirs; see the seed constructors below.
      kind=@t
  ==
::
::  the seed local tile
++  landscape-tile
  ^-  json
  %-  pairs:enjs:format
  :~  title+s+'Landscape'
      info+s+'Tlon'
      color+s+'#1a1a1a'
      href+s+'/apps/landscape'
      image+s+'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Urbit_Logo.svg/3840px-Urbit_Logo.svg.png'
      kind+s+'app'
  ==
++  forge-tile
  ^-  json
  %-  pairs:enjs:format
  :~  title+s+'Forge'
      info+s+'git repos'
      color+s+'#3d3a45'
      href+s+'/grubbery/forge'
      image+s+'/grubbery/tiles/icon/apps/shell/forge'
      kind+s+'app'
  ==
++  github-tile
  ^-  json
  %-  pairs:enjs:format
  :~  title+s+'GitHub'
      info+s+'The ship\'s GitHub proxy'
      color+s+'#24292f'
      href+s+'/grubbery/github'
      image+s+'/grubbery/tiles/icon/apps/shell/forge/github'
      kind+s+'utility'
  ==
::  each local tile is its own subdir /tiles/<name>/ holding tile.json
::  (and optionally icon.svg); the tile's name is the subdir name. They
::  live in the shell's own root.
++  read-local-tiles
  =/  m  (fiber:fiber:nexus ,(list tile))
  ^-  form:m
  =/  tiles-root=path  /apps/shell
  ;<  =view:nexus  bind:m  (peek:io [%& %| (weld tiles-root /tiles)] ~)
  ?.  ?=([%ball *] view)
    (pure:m ~)
  =/  subdirs=(list [@ta ball:tarball])  ~(tap by dir.ball.view)
  =|  acc=(list tile)
  |-
  ?~  subdirs  (pure:m (flop acc))
  =/  name=@ta  -.i.subdirs
  ;<  tv=view:nexus  bind:m
    (peek:io [%& %& (weld tiles-root /tiles/[name]) %'tile.json'] `[/ %json])
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
  (tile-from-json name u.jon)
::  +tiles-from-sang: an app's tile.json as its tiles. One object is one
::  tile, named by the app's slug; an array is several, the first named
::  by the slug (the app's own tile, the one its icon file dresses) and
::  the rest <slug>-2, <slug>-3, ... so each can be hidden on its own.
::  An app housing more than one surface (the forge and its github
::  proxy) puts a tile on the home page for each.
::
++  tiles-from-sang
  |=  [slug=@ta =sang:tarball]
  ^-  (list tile)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang))))
  ?~  jon  ~
  ?:  ?=(%o -.u.jon)  (drop (tile-from-json (crip "{(trip slug)}.json") u.jon))
  ?.  ?=(%a -.u.jon)  ~
  =/  n=@ud  1
  |-  ^-  (list tile)
  ?~  p.u.jon  ~
  =/  name=@ta  ?:(=(1 n) (crip "{(trip slug)}.json") (crip "{(trip slug)}-{(a-co:co n)}.json"))
  =/  one=(unit tile)  (tile-from-json name i.p.u.jon)
  =/  rest  $(p.u.jon t.p.u.jon, n +(n))
  ?~(one rest [u.one rest])
++  tile-from-json
  |=  [name=@ta jon=json]
  ^-  (unit tile)
  ?.  ?=(%o -.jon)  ~
  =/  m  p.jon
  :-  ~
  :*  name
      (fall (bind (~(get by m) 'title') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'info') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'color') |=(=json ?>(?=(%s -.json) p.json))) '#333')
      (fall (bind (~(get by m) 'image') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'href') |=(=json ?>(?=(%s -.json) p.json))) '')
      ::  no 'kind' means 'other' — an undeclared tile lands in the junk
      ::  drawer until its tile.json says app or utility.
      (fall (bind (~(get by m) 'kind') |=(=json ?>(?=(%s -.json) p.json))) 'other')
  ==
::
++  read-app-tiles
  =/  m  (fiber:fiber:nexus ,(list [tile path]))
  ^-  form:m
  ;<  roots=(list path)  bind:m  all-app-roots
  =|  acc=(list [tile path])
  |-  ^-  form:m
  ?~  roots  (pure:m (flop acc))
  =/  root=path  i.roots
  =/  leaf=@ta  (rear root)
  =/  slug=@ta  (app-slug leaf)
  ;<  kid-view=view:nexus  bind:m
    (peek:io [%& %& [root %'tile.json']] `[/ %json])
  ?.  ?=([%file *] kid-view)
    $(roots t.roots)
  =/  tiles=(list tile)  (tiles-from-sang slug sang.kid-view)
  ?~  tiles  $(roots t.roots)
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
  ::  the app's own tile (the first) wears its icon; the others keep the
  ::  image they declared
  =/  first=tile
    ?~  icon  i.tiles
    i.tiles(image (crip "/grubbery/tiles/icon{(spud icon-segs)}"))
  =/  more=(list [tile path])  (turn t.tiles |=(t=tile [t root]))
  $(roots t.roots, acc (weld (flop more) [[first root] acc]))
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
  ::  USER DESKS ONLY. The shell manages discovery + approval for apps the
  ::  user chose to install; built-ins are the trusted tier — they declare
  ::  their /sys/link names in root.hoon and run open, so the shell never
  ::  scans /apps root, follows them, or asks about them. Each desk wrapper's
  ::  real apps are the children of its /desk/data (what apply-bill creates).
  ;<  dv=view:nexus  bind:m
    (peek-shallow:io [%& %| /apps/shell/desks] ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  =/  desks=(list @ta)  ~(tap in ~(key by dir.ball.dv))
  =|  out=(list path)
  |-  ^-  form:m
  ?~  desks  (pure:m (flop out))
  ;<  sv=view:nexus  bind:m
    (peek-shallow:io [%& %| /apps/shell/desks/[i.desks]/desk/data] ~)
  =/  subs=(list path)
    ?.  ?=([%ball *] sv)  ~
    %+  turn  ~(tap in ~(key by dir.ball.sv))
    |=(sub=@ta /apps/shell/desks/[i.desks]/desk/data/[sub])
  $(desks t.desks, out (weld subs out))
::  +all-app-roots: built-ins (every direct child of /apps) PLUS user desks.
::  Only the tile reader uses this — a home-page tile is benign UI, so built-in
::  apps (forge, …) surface theirs too; the discovery/approval machinery stays
::  desks-only (+app-roots).
++  all-app-roots
  =/  m  (fiber:fiber:nexus ,(list path))
  ^-  form:m
  ;<  av=view:nexus  bind:m  (peek-shallow:io [%& %| /apps] ~)
  =/  builtins=(list path)
    ?.  ?=([%ball *] av)  ~
    (turn ~(tap in ~(key by dir.ball.av)) |=(k=@ta /apps/[k]))
  ;<  desks=(list path)  bind:m  app-roots
  (pure:m (weld builtins desks))
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
  ::  an option: `path` is where the name points, `app` the app that
  ::  claims it (the approval is the app's). The app's own name points at
  ::  its root; an alias (`aliases: [{name, path, description}]`) points at
  ::  a place INSIDE the app, so one app can claim several names: the
  ::  forge claims @github for the github proxy it houses at /github.
  =/  opt
    |=  [sub=path desc=@t]
    ^-  json
    %-  pairs:enjs:format
    :~  ['path' s+(crip (spud (weld root sub)))]
        ['app' s+(crip (spud root))]
        ['description' s+desc]
        ['source' s+src]
    ==
  =/  claims=(list [nm=@t o=json])
    %+  weld
      (turn names |=(n=@t [n (opt / (fall (jget u.jon 'description') ''))]))
    %+  murn
      =/  al  (~(get by p.u.jon) 'aliases')
      ?.(?=([~ %a *] al) ~ p.u.al)
    |=  a=json
    ^-  (unit [@t json])
    =/  n=@t  (fall (jget a 'name') '')
    =/  sub=(unit path)  (rush (fall (jget a 'path') '/') stap)
    ?:  |(=('' n) ?=(~ sub))  ~
    `[n (opt u.sub (fall (jget a 'description') ''))]
  =/  acc2=(map @t (list json))
    =/  cs=(list [nm=@t o=json])  claims
    =/  a=(map @t (list json))  acc
    |-  ^-  (map @t (list json))
    ?~  cs  a
    =/  aname=@t  (cat 3 '@' nm.i.cs)
    =/  cur=(list json)  (fall (~(get by a) aname) ~)
    $(cs t.cs, a (~(put by a) aname (snoc cur o.i.cs)))
  $(roots t.roots, acc acc2)
::  +build-alias-menus: the full alias directory as menus. Merges the
::  app-scanned options with the user's stored aliases (each a `you`-
::  sourced option), keyed by @name: {@name: [{path, description,
::  source}, ...]}. Stored user options are authoritative; app options
::  are derived. This is what the permission manager renders.
::
::  +read-link-names: every name /sys/link actually holds, and where it
::  points. THE RECORD IS THE ANSWER: a name resolves because it is in
::  /sys/link, not because an app claimed it in a link.json, and the
::  built-in nexuses (notifications, explorer, forge, …) register theirs
::  there directly. Reading claimants alone left those names invisible —
::  resolvable by the kernel, unresolvable to this page.
::
++  read-link-names
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t (list json)))
  ^-  form:m
  ;<  lv=view:nexus  bind:m  (peek-shallow:io [%& %| /sys/link] ~)
  ?.  ?=([%ball *] lv)  (pure:m ~)
  =/  names=(list @ta)  ~(tap in ~(key by dir.ball.lv))
  =|  acc=(map @t (list json))
  |-  ^-  form:m
  ?~  names  (pure:m acc)
  ;<  dest=(unit lane:tarball)  bind:m  (resolve-link:io (cat 3 '@' i.names))
  ?.  ?=([~ %| *] dest)  $(names t.names)
  =/  pax=@t  (crip (spud p.u.dest))
  =/  opt=json
    %-  pairs:enjs:format
    :~  ['path' s+pax]
        ['app' s+pax]
        ['description' s+'a name the link record holds']
        ['source' s+'link']
    ==
  $(names t.names, acc (~(put by acc) (cat 3 '@' i.names) ~[opt]))
::  +read-aliases: the whole alias directory — what /sys/link holds,
::  what apps claim on top of it, and the names you declare in
::  permit/link.json. Yours lead, so a name you point resolves your way
::  by default.
::
++  read-aliases
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t (list json)))
  ^-  form:m
  ;<  links=(map @t json)  bind:m  (read-links rail)
  ;<  held=(map @t (list json))  bind:m  (read-link-names rail)
  ;<  claimed=(map @t (list json))  bind:m  read-app-aliases
  ::  a claimant says more about a name than the bare record does, so it
  ::  leads; the record's own option stays behind it, and a name nobody
  ::  claims is still a name.
  =/  apps=(map @t (list json))
    %-  ~(uni by held)
    %-  ~(urn by claimed)
    |=  [nm=@t opts=(list json)]
    =/  from-link=(list json)  (fall (~(get by held) nm) ~)
    =/  seen=(set @t)  (silt (turn opts |=(o=json (fall (jget o 'path') ''))))
    (weld opts (skip from-link |=(o=json (~(has in seen) (fall (jget o 'path') '')))))
  %-  pure:m
  %+  roll  ~(tap by links)
  |=  [[nm=@t e=json] acc=_apps]
  =/  pax=@t  ?.(?=(%o -.e) '' (fall (jget e 'path') ''))
  ?:  =('' pax)  acc
  =/  aname=@t  (cat 3 '@' nm)
  =/  opt=json
    %-  pairs:enjs:format
    :~  ['path' s+pax]
        ['app' s+'']
        ['description' s+'a name you declared']
        ['source' s+'you']
    ==
  (~(put by acc) aname [opt (fall (~(get by acc) aname) ~)])
++  build-alias-menus
  |=  [rail=rail:tarball suppressed=json show-hidden=?]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  menus=(map @t (list json))  bind:m  (read-aliases rail)
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
::  +spawn-followers: ensure a /sync/<app> follower grub exists for every
::  top-level app in /apps. Making the grub starts its follower fiber (the
::  [[%sync ~] @] case). Idempotent — skips ones already present. (Culling
::  removed apps' followers + descending into desks are later increments.)
::
::  +sync-lane: the /sync grub lane for an app-root path. Built-in apps
::  at /apps/<name> mirror as /sync/<name>; desk sub-apps at
::  /apps/shell/desks/<desk>/desk/data/<sub> mirror as
::  /sync/<desk>/<sub>. ~ for anything unrecognized.
::
++  sync-lane
  |=  ap=path
  ^-  (unit lane:tarball)
  ?+  ap  ~
    [%apps @ ~]
      `[%& [/sync i.t.ap]]
    [%apps %shell %desks @ %desk %data @ ~]
      `[%& [/sync/[i.t.t.t.ap] i.t.t.t.t.t.t.ap]]
  ==
::  +app-path-of: inverse — the app-root path a /sync follower watches,
::  from the follower's own rail.
::
::  +share-road: where an app's share.usergroups lives. A desk's apps
::  share as one desk: the file sits on the desk dir, not under the app.
::
++  share-road
  |=  ap=path
  ^-  road:tarball
  ?:  ?=([%apps %shell %desks @ %desk %data @ ~] ap)
    [%& %& /apps/shell/desks/[i.t.t.t.ap] %'share.usergroups']
  [%& %& ap %'share.usergroups']
++  app-path-of
  |=  =rail:tarball
  ^-  (unit path)
  ?+  path.rail  ~
    [%sync ~]
      `~[%apps name.rail]
    [%sync @ ~]
      `~[%apps %shell %desks i.t.path.rail %desk %data name.rail]
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
::  +take-reg-wake: wake the group derivation — any news (the record or
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
    ?:  |(=(/alias wire.u.in) =(/weir wire.u.in) =(/groups wire.u.in))  [%done ~]
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
  ::  a desk's apps share as one desk: one share listener per desk dir,
  ::  ensured whether or not this app's own follower already exists
  ;<  ~  bind:m
    ?.  ?=([%& [%sync @ *] *] u.syn)  (pure:(fiber:fiber:nexus ,~) ~)
    (ensure-share-listener rail i.t.path.p.u.syn)
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
::  +ensure-share-listener: /sync/<desk>/share.sig exists
::
++  ensure-share-listener
  |=  [rail=rail:tarball desk=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rd=road:tarball  (nex-road:io rail [%& /sync/[desk] %'share.sig'])
  ;<  has=?  bind:m  (peek-exists:io rd)
  ?:  has  (pure:m ~)
  ;<  err=(unit tang)  bind:m  (make-soft:io rd |+[[[/ %sig] ~] ~])
  ~?  >>>  ?=(^ err)  [%shell-share-listener-failed desk]
  (pure:m ~)
::  +build-links: materialize the discovery registry at /sys/link/. For
::  each @name, write /sys/link/<segments>/dest.lanes — a (list lane:tarball)
::  of target locations, earliest claimant first. Only writes on genuine
::  content change. Driven by the /sync followers (each app's link.json is
::  kept by subscription), not by a poll.
::
::  INVARIANT: /sys/link MUST always be current.
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
    (peek-shallow:io [%& %| /apps/shell/desks] ~)
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
    (peek-as:io [%& %& /apps/shell/desks/[i.kids] %'share.usergroups'] ,(set path))
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
      ['code' s+(crip "/apps/shell/desks/{(trip name)}/desk/code")]
  ==
::
++  build-links
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  menus=(map @t (list json))  bind:m  (read-aliases rail)
  ;<  approved=(map @t json)  bind:m  (read-approved rail)
  ::  a desk earns its /sys/link name only once the user approves it — being
  ::  reachable by name is a capability, gated like a road. Drop every opt
  ::  whose app isn't approved, and any name left with no approved claimant.
  ::  A name you declared yourself needs no approval; it is your decision.
  ::  (Built-in names aren't here at all; root.hoon seeds those directly.)
  =/  entries=(list [nm=@t opts=(list json)])
    %+  murn  ~(tap by menus)
    |=  [nm=@t opts=(list json)]
    ^-  (unit [@t (list json)])
    =/  keep=(list json)
      %+  skim  opts
      |=  o=json
      ?|  =('you' (fall (jget o 'source') ''))
          (~(has by approved) (fall (jget o 'app') (fall (jget o 'path') '')))
      ==
    ?~(keep ~ `[nm keep])
  =/  want=(set path)  (silt (turn entries |=([nm=@t *] (link-dir nm))))
  |-  ^-  form:m
  ?~  entries
    ::  cull pass: drop /sys/link dirs whose link no longer has any claimant.
    ::  Only names the SHELL registered, i.e. whose lanes point into its
    ::  desks: the built-ins' names are root.hoon's seeds, pointing at
    ::  /apps/<app>, and a name claimed by anything outside the desks tree
    ::  is not ours to remove. (Culling them here was what emptied /sys/link
    ::  of @github/@forge/… on every sweep and broke every clone.)
    ;<  bv=view:nexus  bind:m  (peek-shallow:io [%& %| /sys/link] ~)
    ?.  ?=([%ball *] bv)  (pure:m ~)
    =/  haves=(list @ta)  ~(tap in ~(key by dir.ball.bv))
    =/  desks-root=path  /apps/shell/desks
    |-  ^-  form:m
    ?~  haves  (pure:m ~)
    ?:  (~(has in want) /sys/link/[i.haves])  $(haves t.haves)
    ;<  cur=view:nexus  bind:m  (peek:io [%& %& /sys/link/[i.haves] %'dest.lanes'] `[/ %lanes])
    =/  lanes=(list lane:tarball)
      ?.  ?=([%file *] cur)  ~
      (fall (mole |.(!<((list lane:tarball) (need-vase:tarball sang.cur)))) ~)
    =/  ours=?
      %+  levy  lanes
      |=  l=lane:tarball
      ?.  ?=(%| -.l)  %.n
      =((scag (lent desks-root) p.l) desks-root)
    ?.  ours  $(haves t.haves)
    ;<  *  bind:m  (cull-soft:io [%& %| /sys/link/[i.haves]])
    $(haves t.haves)
  =/  road=road:tarball  (link-road nm.i.entries)
  =/  want=(list lane:tarball)
    %+  murn  opts.i.entries
    |=  o=json
    =/  p=@t  (fall (jget o 'path') '')
    ?:(=('' p) ~ `[%| (stab p)])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %lanes])
  =/  have=(list lane:tarball)
    ?.  ?=([%file *] cur)  ~
    (fall (mole |.(!<((list lane:tarball) (need-vase:tarball sang.cur)))) ~)
  ::  the list is ORDERED, earliest claimant first, and the order is
  ::  kept across rebuilds: claimants already listed stay in place,
  ::  claimants gone are dropped, new ones are appended. So the head is
  ::  whoever claimed the name first, and a resolver may take it as the
  ::  default without the shell having to remember anything else.
  =/  want-set=(set lane:tarball)  (silt want)
  =/  kept=(list lane:tarball)  (skim have |=(l=lane:tarball (~(has in want-set) l)))
  =/  kept-set=(set lane:tarball)  (silt kept)
  =/  lanes=(list lane:tarball)
    (weld kept (skip want |=(l=lane:tarball (~(has in kept-set) l))))
  ?:  =(lanes have)  $(entries t.entries)
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
  ;<  want=json    bind:m  (build-alias-menus rail hidden %.y)
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
  ;<  want=json    bind:m  (read-approved-weirs rail approved hidden)
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
  ;<  gkeys=json  bind:m  (read-app-group-keys ap)
  =/  ask=json  [%o (~(put by (~(put by p.u.jon) 'app' s+app)) 'groups' gkeys)]
  ;<  approved=(map @t json)  bind:m  (read-approved rail)
  ?:  (is-settled ask approved)  (pure:m ~)
  ::  EVERY app asks, the ones that ship with grubbery included. An app
  ::  shipping in the box is a reason to trust its author, not a reason
  ::  to decide for the user what it may reach or open to other ships.
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
  ;<  menus=json       bind:m  (build-alias-menus rail hidden %.n)
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
  ::  A root instance /apps/X whose code has moved into a desk - the same X
  ::  installed at /apps/shell/desks/<d>/desk/data/X - is dormant: its
  ::  code left the ball, its data was carried, and it keeps its weir.json.
  ::  It is not an ask anyone can act on, and listing it puts a permanent
  ::  "pending" on every ship that ever migrated an app. Skip it.
  =/  leaves=(list @ta)
    %+  murn  roots
    |=  p=path
    ^-  (unit @ta)
    ?.  ?=([%apps @ta %desks @ta %desk %data @ta ~] p)  ~
    `i.t.t.t.t.t.t.p
  =.  roots
    %+  skip  roots
    |=  p=path
    ^-  ?
    ?.  ?=([%apps @ta ~] p)  |
    =/  leaf=@ta  i.t.p
    (lien leaves |=(l=@ta =(l leaf)))
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
  ;<  names=json  bind:m  (read-app-shares ap)
  ;<  groups=json  bind:m  (read-app-group-keys root)
  =/  ask=json
    %-  pairs:enjs:format
    :~  ['app' s+ap]
        ['path' s+ap]
        ['poke' (fall (~(get by p.u.jon) 'poke') [%a ~])]
        ['peek' (fall (~(get by p.u.jon) 'peek') [%a ~])]
        ['make' (fall (~(get by p.u.jon) 'make') [%a ~])]
        ::  names it claims, and the groups it wants them opened to
        ::  (link.json)
        ['names' names]
        ::  the usergroups it wants: the top-level keys of its groups.json
        ::  — a group it opens its own roads into, or a prefix (trailing
        ::  slash) it runs groups under
        ['groups' groups]
    ==
  $(roots t.roots, acc [ask acc])
::  +read-app-group-keys: the usergroups an app asks for — the top-level
::  keys of the groups.json at its root. The contents are the app's
::  facts about them, read at derivation within the keys approved.
::
++  read-app-group-keys
  |=  root=path
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  gv=(unit json)  bind:m  (peek-as:io [%& %& root %'groups.json'] ,json)
  ?~  gv  (pure:m [%a ~])
  ?.  ?=(%o -.u.gv)  (pure:m [%a ~])
  (pure:m a+(turn (sort ~(tap in ~(key by p.u.gv)) aor) |=(k=@t s+k)))
::  +read-app-shares: the names an app asks to open to usergroups, from
::  its link.json: [{alias, groups}] for every claimed name carrying a
::  `share` list (the app's own name reads the top-level `share`; an
::  alias entry its own). A share is a request like a road: the user
::  grants it on Permits, and the grant is the group's peek on
::  /sys/link/<alias>/dest.lanes, nothing more.
::
++  read-app-shares
  |=  app=@t
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  tp=(unit path)  (soft-path app)
  ?~  tp  (pure:m [%a ~])
  ;<  lv=view:nexus  bind:m
    (peek:io [%& %& [u.tp %'link.json']] `[/ %json])
  ?.  ?=([%file *] lv)  (pure:m [%a ~])
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang.lv))))
  ?~  jon  (pure:m [%a ~])
  ?.  ?=(%o -.u.jon)  (pure:m [%a ~])
  =/  groups-of
    |=  j=json
    ^-  (list @t)
    ?.  ?=([%a *] j)  ~
    (murn p.j |=(g=json ?.(?=([%s *] g) ~ `p.g)))
  =/  names=(list @t)
    =/  nv  (~(get by p.u.jon) 'name')
    ?~  nv  ~
    ?:  ?=(%s -.u.nv)  ~[p.u.nv]
    ?.  ?=(%a -.u.nv)  ~
    (murn p.u.nv |=(j=json ?.(?=(%s -.j) ~ `p.j)))
  =/  own=(list @t)  (groups-of (fall (~(get by p.u.jon) 'share') [%a ~]))
  =/  entry
    |=  [alias=@t groups=(list @t)]
    ^-  json
    (pairs:enjs:format ~[['alias' s+alias] ['groups' a+(turn groups |=(g=@t s+g))]])
  =/  out=(list json)
    %+  weld
      ?~  own  ~
      (turn names |=(n=@t (entry n own)))
    %+  murn
      =/  al  (~(get by p.u.jon) 'aliases')
      ?.(?=([~ %a *] al) ~ p.u.al)
    |=  a=json
    ^-  (unit json)
    =/  n=@t  (fall (jget a 'name') '')
    =/  gs=(list @t)  ?.(?=(%o -.a) ~ (groups-of (fall (~(get by p.a) 'share') [%a ~])))
    ?:  |(=('' n) =(~ gs))  ~
    `(entry n gs)
  (pure:m a+out)
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
  ?.  ?=([%o *] j)  ~
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
::  +regrant-moved: an approved app's @name bindings were resolved when
::  it was granted, and its sand set from them. When the registry moves
::  a name, or a name it was granted against appears, the recorded path
::  is stale and the sand with it. Re-resolve every granted app that
::  references a name; one whose paths changed is granted again and
::  rebooted so its fibers hold the new roads.
::
++  regrant-moved
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  approved=(map @t json)  bind:m  (read-approved rail)
  ;<  hidden=json  bind:m  (read-hidden rail)
  ;<  menus=json  bind:m  (build-alias-menus rail hidden %.n)
  =/  todo=(list [app=@t entry=json])  ~(tap by approved)
  |-  ^-  form:m
  ?~  todo  (pure:m ~)
  =/  entry=json  entry.i.todo
  ?.  ?=([%o *] entry)  $(todo t.todo)
  ?.  =('granted' (fall (jget entry 'verdict') ''))  $(todo t.todo)
  =/  bindings=json  (fall (~(get by p.entry) 'bindings') [%o ~])
  ?.  ?=([%o *] bindings)  $(todo t.todo)
  =/  bmap=(map @t json)  p.bindings
  ?:  =(~ bmap)  $(todo t.todo)
  ::  a recorded pick the registry still offers stays the user's choice;
  ::  one that is empty or gone falls back to the registry's first option
  =/  picks=json
    :-  %o
    %-  ~(gas by *(map @t json))
    %+  murn  ~(tap by bmap)
    |=  [n=@t v=json]
    ^-  (unit [@t json])
    ?.  ?=([%s *] v)  ~
    ?:  =('' p.v)  ~
    ?.  (offered menus n p.v)  ~
    `[n v]
  =/  moved=?
    %+  lien  ~(tap by bmap)
    |=  [n=@t v=json]
    =/  was=@t  ?:(?=([%s *] v) p.v '')
    !=(was (resolve-alias-ref picks menus n))
  ?.  moved  $(todo t.todo)
  ~&  >  [%shell-regrant-moved app.i.todo]
  =/  granted=json  (fall (~(get by p.entry) 'declared') [%o ~])
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (do-approve-weir rail app.i.todo picks granted hidden now)
  =/  tp=(unit path)  (soft-path app.i.todo)
  ;<  ~  bind:m  ?~(tp (pure:m ~) (reload:io [%& %| u.tp]))
  $(todo t.todo)
::  +offered: is this path one of the registry's options for the name
::
++  offered
  |=  [menus=json n=@t p=@t]
  ^-  ?
  ?.  ?=([%o *] menus)  %.n
  =/  opts=(unit json)  (~(get by p.menus) n)
  ?~  opts  %.n
  ?.  ?=([%a *] u.opts)  %.n
  (lien p.u.opts |=(o=json =(p (fall (jget o 'path') ''))))
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
      ::  no granted `names` here: a name's share is a property of the
      ::  name and lives once, in permit/link.json. `declared` keeps what
      ::  the app asked, which is what settling compares.
      ['groups' (cat-arr granted 'groups')]
      :-  'declared'
      %-  pairs:enjs:format
      :~  ['poke' (cat-arr declared 'poke')]
          ['peek' (cat-arr declared 'peek')]
          ['make' (cat-arr declared 'make')]
          ['names' (cat-arr declared 'names')]
          ['groups' (cat-arr declared 'groups')]
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
  ?.  ?=([%o *] j)  ~
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
  |=  [rail=rail:tarball approved=(map @t json) hidden=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  menus=json  bind:m  (build-alias-menus rail hidden %.n)
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
  ::  the alias directory costs a peek per installed app - most of this
  ::  fiber's time - and only an ask that names an @alias needs it.
  ;<  menus=json  bind:m
    ?:  =(~ (ref-aliases sub))  (pure:(fiber:fiber:nexus ,json) [%o ~])
    (build-alias-menus rail hidden %.n)
  =/  tp=(unit path)  (soft-path app)
  ?~  tp  (pure:m ~)
  =/  target=path  u.tp
  =/  poke-res=(list @t)
    (turn (road-strs sub 'poke') |=(t=@t (resolve-alias-ref picks menus t)))
  =/  peek-res=(list @t)
    (turn (road-strs sub 'peek') |=(t=@t (resolve-alias-ref picks menus t)))
  =/  make-res=(list @t)
    (turn (road-strs sub 'make') |=(t=@t (resolve-alias-ref picks menus t)))
  =/  groups-given=json  (cat-arr sub 'groups')
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
        ::  the usergroups it holds: its groups.json is read within them
        ['groups' groups-given]
    ==
  ;<  ~  bind:m  (put:io [%& %& [target %'grant.json']] [[/ %json] grant-json])
  ::  the name shares ride the same record: what the app asked
  ::  (link.json) and what the user ticked, so a changed ask shows up
  ::  as pending the way a changed road does. The grant itself lives in
  ::  permit/link.json (set-link-shares, written by the caller).
  ;<  names-asked=json  bind:m  (read-app-shares app)
  ;<  groups-asked=json  bind:m  (read-app-group-keys target)
  =/  ask-full=json
    [%o (~(put by (~(put by p.u.ask) 'names' names-asked)) 'groups' groups-asked)]
  =/  sub-full=json
    ?.  ?=(%o -.sub)  sub
    [%o (~(put by p.sub) 'groups' groups-given)]
  ::  freeze the FULL resolved binding map (amap), not just the explicit
  ::  picks — so a menu-of-one (auto-resolved, no picker) still records what
  ::  it dereferenced to, and the applied overlay shows the concrete path.
  =/  entry=json  (approval-entry app ask-full sub-full 'granted' amap now)
  ;<  cur=(map @t json)  bind:m  (read-approved rail)
  ;<  ~  bind:m
    (put:io (nex-road:io rail [%& /permit %'approved.json']) [[/ %json] [%o (~(put by cur) app entry)]])
  ::  the prefixes an app may state groups under may have changed
  ;<  ~  bind:m
    (poke:io (nex-road:io rail [%& / %'usergroups.sig']) [[/ %json] [%o ~]])
  ::  this one app's live-weir overlay, written now: the page reloads the
  ::  moment this answers and must see the grant applied, not the stale
  ::  cache. The full rebuild (every app, a peek each) runs behind it.
  ;<  live=weir:tarball  bind:m  (read-live-weir target)
  =/  overlay=json
    %-  pairs:enjs:format
    :~  ['app' s+app]
        ['target' s+(crip (spud target))]
        ['verdict' s+'granted']
        ['poke' (overlay-cat entry amap menus poke.live 'poke')]
        ['peek' (overlay-cat entry amap menus peek.live 'peek')]
        ['make' (overlay-cat entry amap menus make.live 'make')]
    ==
  ;<  wv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /cache %'weirs.json']) ,json)
  =/  wm=(map @t json)  ?.(?=([~ %o *] wv) ~ p.u.wv)
  ;<  ~  bind:m
    (put:io (nex-road:io rail [%& /cache %'weirs.json']) [[/ %json] [%o (~(put by wm) app overlay)]])
  ::  the reboot that makes the grant live - fibers that crashed while
  ::  jailed come back holding it - is POST /permits/reload, the page's
  ::  next request: a reboot takes seconds and this answer must not wait.
  (pure:m ~)
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
  ::  A root instance /apps/X whose code has moved into a desk - the same X
  ::  installed at /apps/shell/desks/<d>/desk/data/X - is dormant: it
  ::  keeps its tile.json but nothing behind it runs, and its address is
  ::  the desk install's now. One icon, not two. Same rule as read-app-weirs.
  =/  leaves=(list @ta)
    %+  murn  app-pairs
    |=  [* r=path]
    ^-  (unit @ta)
    ?.  ?=([%apps @ta %desks @ta %desk %data @ta ~] r)  ~
    `i.t.t.t.t.t.t.r
  =.  app-pairs
    %+  skip  app-pairs
    |=  [* r=path]
    ^-  ?
    ?.  ?=([%apps @ta ~] r)  |
    =/  leaf=@ta  i.t.r
    (lien leaves |=(l=@ta =(l leaf)))
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
  |=  [tiles=(list [t=tile root=(unit path)]) hidden=(set @t)]
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
      kind+s+kind.t
      root+?~(root ~ s+(crip (spud u.root)))
      hidden+b+(~(has in hidden) name.t)
  ==
::  +read-hidden-tiles: the user's hidden-tile preference — the set of tile
::  names suppressed from the home grid, from /hidden-tiles.json. ~ = none.
++  read-hidden-tiles
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,(set @t))
  ^-  form:m
  ;<  hv=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& / %'hidden-tiles.json']) ,json)
  ?.  ?=([~ %a *] hv)  (pure:m ~)
  (pure:m (silt (murn p.u.hv |=(j=json ?:(?=([%s *] j) `p.j ~)))))
--
