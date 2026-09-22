::  nostr nexus: a nostr account, as files.
::
::  nostr is a protocol with no accounts server: an identity is a
::  keypair, a post is an event signed by that key, and relays are
::  plain websocket servers that store and forward events for anyone
::  who asks. This nexus keeps every piece of that as a grub under
::  /apps/nostr so it can be read, edited and explained in place. Relay
::  clients (one fiber per relay, over /sys/iris/ws.ws-state) pull the
::  posts and profiles of the pubkeys in follows.json and push the
::  events we sign. Everything downstream — the page, ghostprompter,
::  the explorer — reads the namespace. The protocol handling follows
::  nostrill, the gall-agent client this grew out of.
::
::    accounts/<pk>/          one dir per keypair this ship holds:
::      identity.json         {pubkey, npub, since}: the public half —
::                            the account's name on the network
::      secret.json           {privkey, nsec}: the private half. Signs
::                            everything it publishes; never leaves
::                            the ship
::      profile.json          {name, about, picture}: what it publishes
::                            as its kind-0 (profile) event
::    me.json                 {current: <pk>}: the account every action
::                            here signs as (post, reply, react, repost,
::                            profile). Switch it on the Profile tab.
::    outbox/<id>.json        {event, relays: {host: {ok, message, at}},
::                            at}: an event we signed and sent, with
::                            each relay's verdict on it.
::    events/<id>.json        one nostr event, verbatim (id, pubkey, kind,
::                            created_at, tags, content, sig). Immutable:
::                            written once, never touched. Kinds 1 (post,
::                            reply), 6 (repost), 7 (reaction).
::    authors/<pubkey>.json   {ids} — the posts we hold by one author,
::                            newest first, capped. A derived index like
::                            refs/, so a person view is one peek.
::    refs/<id>.json          what points at an event: the replies in its
::                            thread (each with its parent), reposts of
::                            it, reactions to it. A derived index, one
::                            fact per e-tag, rebuilt from events/ if
::                            lost. Replies file under the thread ROOT;
::                            reposts and reactions under their target.
::    profiles/<pubkey>.json  the author's kind-0 metadata (the content
::                            of their latest profile event); overwritten
::                            when it changes.
::    feed.json               {ids: [newest..oldest], times, at, count}
::                            — the recent timeline as an index, so a
::                            consumer gets the timeline in one peek
::                            instead of a directory listing.
::    config.json             {interval: supervisor seconds, keep: how many ids
::                            the feed index holds, relays: [wss urls],
::                            backfill_days: how far back a fresh relay
::                            session asks}
::    defaults.json           {relays, follows}: the starting points,
::                            replaced from the source on every reload.
::                            Nothing reads it but the seeds below and
::                            the reset buttons.
::      follows.json          {pubkeys: [hex]} — whose posts this account
::                            wants (its kind-3 contact list, unpublished
::                            yet). Relay clients subscribe to the union
::                            over accounts; the feed shows the current
::                            account's.
::    (follows.json at the root, from before accounts, migrates in.) The
::                            system of record for the follow list,
::                            seeded once from defaults.json (this ship
::                            has no nostr key, so no kind-3 contact list
::                            to derive it from yet).
::    relays/<host>.sig       one relay client per configured relay: a
::                            websocket, one REQ for kinds 1 and 0 from
::                            the follows, frames written as the grubs
::                            above, reconnect with backoff. Ensured by
::                            main.sig.
::    relays/<host>.json      that client's state, written at every
::                            transition: {stage, wid, events, new,
::                            profiles, eose_at, notice, error, tries,
::                            updated}. Read this, not the terminal.
::    main.sig                the supervisor: makes sure a relay client
::                            exists for every configured relay, every
::                            `interval` seconds and on any poke.
::
::  The road to a full client, and what is done: nostr/TODO.md.
::    web.sig                 the page: static files + a JSON api over
::                            the grubs above (see +serve).
::
/&  icon     nostr/icon.svg
/<  ui-html  nostr/index.html
/<  ui-js    nostr/app.js
/<  ui-css   nostr/style.css
/<  defaults-mime  nostr/defaults.json
::  the roadmap, materialized at the nexus root as TODO.md (the source
::  is lowercase: clay path segments are)
/&  todo-md  nostr/todo.md
::  the kit components this page uses, welded into one served file
/&  tg-js    /lib/ui/tab-group.js
/&  md-js    /lib/ui/modal-dialog.js
/&  dm-js    /lib/ui/drop-menu.js
/&  av-js    /lib/ui/avatar-pic.js
/&  pc-js    /lib/ui/post-card.js
/&  pt-js    /lib/ui/post-text.js
/&  pv-js    /lib/ui/post-viewer.js
/&  ep-js    /lib/ui/emoji-picker.js
/<  nl       /lib/nostr.hoon
::  the MCP tools that read and drive this nexus (its own bundle, its
::  own tools-nexus instance at /tools — the ghostprompter pattern)
/<  nex-tools  /lib/tools.hoon
/&  bundle   /lib/nostr-bundle/
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  weld the component modules into one served file (single request);
      ::  each wrapped in { } so top-level consts don't collide.
      =/  wrap
        |=  =mime  ^-  @
        (rap 3 ~[123 10 q.q.mime 10 125 10])
      =/  kit-js=mime
        :-  /application/javascript
        %-  as-octs:mimes:html
        (rap 3 ~[(wrap tg-js) (wrap md-js) (wrap dm-js) (wrap av-js) (wrap ep-js) (wrap pc-js) (wrap pt-js) (wrap pv-js)])
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Nostr'
            info+s+'A nostr client: feed, people, relays, accounts'
            color+s+'#f1ecfb'
            image+s+'/grubbery/tiles/icon/nostr'
            href+s+'/grubbery/nostr'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'nostr'] ['description' s+'a nostr client in the namespace: events, profiles, relays, accounts']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%over %& [/ %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ %'defaults.json'] [[/ %json] defaults]]
          [%over %& [/ %'TODO.md'] [[/ %mime] todo-md]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /accounts empty-dir:loader]
          [%over %| /tools (seed-tools:nex-tools bundle)]
          [%fall %& [/ %'me.json'] [[/ %json] (pairs:enjs:format ~[['current' s+'']])]]
          [%fall %| /outbox empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/ %'feed.json'] [[/ %json] (feed-index ~ 0)]]
          [%fall %| /events empty-dir:loader]
          [%fall %| /profiles empty-dir:loader]
          [%fall %| /relays empty-dir:loader]
          [%fall %| /refs empty-dir:loader]
          [%fall %| /authors empty-dir:loader]
          [%fall %| /tags empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: the supervisor. Ensures the relay clients, then
          ::  sleeps `interval`; any poke wakes it early
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%nostr/main: failed")
        |-
        ;<  ~  bind:m  (ensure-relays rail)
        ;<  interval=@ud  bind:m  (read-interval rail)
        ;<  *  bind:m  (sleep-or-poke (mul interval ~s1))
        $
          ::  the feed page: a reader over the namespace, nothing else
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%nostr/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/nostr])
        (http-dispatch:io %nostr)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%nostr/req: failed")
        (serve rail name.rail)
          ::  relays/<host>.sig: the relay client, forever. Only the .sig
          ::  spawns one: the client writes relays/<host>.json beside it,
          ::  and matching that too forked a client per status write.
          [[%relays ~] @]
        =/  n=tape  (trip name.rail)
        ?.  &((gth (lent n) 4) =(".sig" (slag (sub (lent n) 4) n)))  stay:m
        ;<  ~  bind:m  (rise-wait:io prod "%nostr/relay: failed")
        =/  host=@t  (crip (scag (sub (lent n) 4) n))
        (relay-loop rail host)
      ==
    --
|%
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] (pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'time + entropy')
          (line '/sys/behn/' 'supervisor and reconnect timers')
          (line '/sys/eyre/' 'serve the feed page over HTTP')
          (line '/sys/iris/ws.ws-state' 'websockets to nostr relays')
      ==
  ==
::
::  +defaults: nostr/defaults.json as json; the seeds below read it
++  defaults
  ^-  json
  (fall (de:json:html (crip (trip q.q.defaults-mime))) [%o ~])
++  default-relays
  ^-  (list @t)
  (murn (jarr defaults 'relays') |=(u=json ?:(?=([%s *] u) `p.u ~)))
++  default-follows
  ^-  (list @t)
  (murn (jarr defaults 'follows') |=(u=json ?:(?=([%s *] u) `p.u ~)))
++  default-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['interval' (numb:enjs:format 120)]
      ['keep' (numb:enjs:format 500)]
      ['relays' [%a (turn default-relays |=(u=@t s+u))]]
      ['backfill_days' (numb:enjs:format 30)]
  ==
::
::  +feed-index: {ids, times, count, at}. ids newest first; times is the
::  parallel list of created_at, so a relay session can carry the index
::  forward without re-reading every event, and `since` falls out of it.
++  feed-index
  |=  [ents=(list [id=@t t=@ud a=@t]) at=@ud]
  ^-  json
  %-  pairs:enjs:format
  :~  ['ids' [%a (turn ents |=([i=@t *] s+i))]]
      ['times' [%a (turn ents |=([* t=@ud *] (numb:enjs:format t)))]]
      ['authors' [%a (turn ents |=([* * a=@t] s+a))]]
      ['count' (numb:enjs:format (lent ents))]
      ['at' (numb:enjs:format at)]
  ==
::
++  read-interval
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  ;<  cfg=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
  =/  n=@ud  (jnum (fall cfg [%o ~]) 'interval' 120)
  (pure:m (max 15 n))
::  +sleep-or-poke: wait out the interval, or wake early on any poke.
::  A timer wake arrives as a poke of [/ %timer-wake] from behn; a
::  poke from a caller lands the same way. Either ends the wait; the
::  caller does its work again regardless of which.
++  sleep-or-poke
  |=  d=@dr
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /poll (add now d))
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~              [%wait ~]
    [~ %poke * *]  [%done ~]
  ==
::  +ensure-relays: a relays/<host>.sig for every configured relay
++  ensure-relays
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  urls=(list @t)  bind:m  (read-relays rail)
  |-
  ?~  urls  (pure:m ~)
  =/  host=@t  (relay-host i.urls)
  =/  road=road:tarball  (nex-road:io rail [%& /relays (cat 3 host '.sig')])
  ;<  have=?  bind:m  (peek-exists:io road)
  ?:  have  $(urls t.urls)
  ~&  >  [%nostr-relay host %spawn]
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %sig] ~] ~])
  ~?  >>>  ?=(^ err)  [%nostr-relay host %spawn-failed u.err]
  $(urls t.urls)
::  +relay-host: 'wss://nos.lol/' -> 'nos.lol' (the grub name)
++  relay-host
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  =.  t  ?:(=("wss://" (scag 6 t)) (slag 6 t) t)
  =.  t  ?:(=("ws://" (scag 5 t)) (slag 5 t) t)
  ::  no ?=(^ t) here: refining t to a cell makes the wet scag's
  ::  product fail to nest back into it (mull-nice)
  =.  t  ?:(&((gth (lent t) 0) =('/' (rear t))) (scag (dec (lent t)) t) t)
  (crip t)
::
::  +read-relays: config.json's relays, or the defaults when the key is
::  absent (a config.json seeded before the key existed). The supervisor
::  and the page must agree on this.
++  read-relays
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  cfg=json  bind:m  (read-config rail)
  =/  l=(list @t)  (murn (jarr cfg 'relays') |=(u=json ?:(?=([%s *] u) `p.u ~)))
  (pure:m ?~(l default-relays l))
++  read-config
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  cfg=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
  (pure:m (fall cfg default-config))
::  +read-follows: the CURRENT account's follows (accounts/<pk>/
::  follows.json). An account without the file gets one: the ship-level
::  follows.json of the single-account days if it is still there (moved
::  in, once), else defaults.json's list. No account: no follows.
++  read-follows
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  cur=(unit @t)  bind:m  (current-pk rail)
  ?~  cur  (pure:m ~)
  (account-follows rail u.cur)
++  account-follows
  |=  [=rail:tarball pk=@t]
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  =/  road=road:tarball  (nex-road:io rail [%& (acct pk) %'follows.json'])
  ;<  f=(unit json)  bind:m  (peek-as:io road ,json)
  ?^  f  (pure:m (pks-of u.f))
  ;<  old=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'follows.json']) ,json)
  =/  start=(list @t)  ?~(old default-follows (pks-of u.old))
  ;<  *  bind:m  (make-soft:io road |+[[[/ %json] (follows-doc start)] ~])
  ;<  *  bind:m
    ?~  old  (pure:(fiber:fiber:nexus ,(unit tang)) ~)
    ~&  [%nostr-accounts %migrated-follows pk (lent start)]
    (cull-soft:io (nex-road:io rail [%& / %'follows.json']))
  (pure:m start)
++  pks-of
  |=  f=json
  ^-  (list @t)
  (murn (jarr f 'pubkeys') |=(p=json ?:(?=([%s *] p) `p.p ~)))
++  follows-doc
  |=  pks=(list @t)
  ^-  json
  (pairs:enjs:format ~[['pubkeys' [%a (turn pks |=(p=@t s+p))]]])
::  +all-follows: the union over every account (what the relay clients
::  subscribe to, so switching accounts needs no reconnect)
++  all-follows
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  pks=(list @t)  bind:m  (account-pks rail)
  =|  acc=(set @t)
  |-
  ?~  pks  (pure:m ~(tap in acc))
  ;<  fs=(list @t)  bind:m  (account-follows rail i.pks)
  $(pks t.pks, acc (~(gas in acc) fs))
::  ---------------------------------------------------------------------
::  the relay client
::
::  +relay-loop: sessions forever. A session ends when the socket closes
::  (or never opens); the wait before the next one doubles per failure
::  from 5s to 5m and resets after a session that reached EOSE.
++  relay-loop
  |=  [=rail:tarball host=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =|  tries=@ud
  |-
  ;<  r=@tas  bind:m  (relay-session rail host tries)
  ?:  =(%stop r)  (pure:m ~)
  =.  tries  ?:(=(%ok r) 0 +(tries))
  =/  wait=@dr  (min (mul ~s5 (bex (min tries 6))) ~m5)
  ;<  ~  bind:m  (sleep-or-poke wait)
  $
::  +relay-session: one socket. Connect, one REQ (kind 1 since the newest
::  event we hold, kind 0 for the same authors), then frames until the
::  socket goes: EVENT → the event/profile grub if new, EOSE → the index
::  is written, and again per event after that; OK → the relay's verdict
::  on something we published, into its outbox grub. A json poke is a
::  command: {action:'send', id} pushes outbox/<id> down this socket,
::  'reconnect' ends the session (a new one picks up follows/config),
::  'stop' ends the client. Returns %ok (EOSE reached), %fail, or %stop.
++  relay-session
  |=  [=rail:tarball host=@t tries=@ud]
  =/  m  (fiber:fiber:nexus ,@tas)
  ^-  form:m
  =/  st=relay-st  [host 'starting' ~ 0 0 0 0 '' '' tries 0 '' 0 ~]
  =/  report  |=(st=relay-st (relay-status rail st))
  ;<  follows=(list @t)  bind:m  (all-follows rail)
  ::  =(~ ...) rather than ?~: no type narrowing, so the wet gates
  ::  below (lien, turn) see the plain list
  ?:  =(~ follows)
    ;<  ~  bind:m  (report st(stage 'no-follows'))
    ;<  ~  bind:m  (sleep-or-poke ~m1)
    (pure:m %ok)
  =/  url=@t  (cat 3 'wss://' host)
  ::  the previous session's status, read BEFORE this session's first
  ::  report overwrites it: its `started` is the profile cursor below
  ;<  prev=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /relays (cat 3 host '.json')]) ,json)
  ::  carry the cursor until this session sends its own REQ, so a
  ::  session that fails to connect does not zero it for the next
  =.  st  st(started (jnum (fall prev [%o ~]) 'started' 0))
  ;<  ~  bind:m  (report st(stage 'connecting'))
  ::  a relay that never answers the handshake would park us forever;
  ::  30s is generous for a websocket upgrade
  ;<  got=(unit (unit @ud))  bind:m
    ::  one socket per client, keyed /relay: connecting again on it (a
    ::  respin, a reconnect) makes the service close the old one first
    ((with-timeout:io ,(unit @ud)) /connect ~s30 (ws-connect:io /relay url))
  =/  wid=(unit @ud)  ?~(got ~ u.got)
  ?~  wid
    ;<  ~  bind:m  (report st(stage 'closed', error ?~(got 'no answer to the handshake in 30s' 'connect failed')))
    (pure:m %fail)
  =.  st  st(wid wid, stage 'open')
  ;<  ~  bind:m  (report st)
  ;<  cfg=json  bind:m  (read-config rail)
  ;<  idx=feed-idx  bind:m  (load-index rail)
  ;<  now=@da  bind:m  get-time:io
  =/  now-unix=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  newest=@ud  (roll (turn ~(val by idx) |=([t=@ud *] t)) max)
  =/  since=@ud
    ?:  =(0 newest)  (sub now-unix (mul 86.400 (jnum cfg 'backfill_days' 30)))
    newest
  ::  profiles change rarely: ask only for ones newer than the last
  ::  session's start (from our own status grub), else every frame of
  ::  every reconnect is 75 profiles we already hold
  =/  prof-since=(unit @ud)  ?:(=(0 started.st) ~ `started.st)
  =.  st  st(started now-unix)
  =/  req=@t
    %-  en:json:html
    :-  %a
    :~  s+'REQ'  s+'timeline'
        (filter ~[1 6 5] follows `since)
        (filter ~[0] follows prof-since)
        ::  what points at the follows: replies to them, reposts and
        ::  reactions of their posts (all carry a p tag for the author)
        (filter-tag ~[1 6 7 5] 'p' follows `since)
    ==
  ;<  ~  bind:m  (ws-send:io u.wid req)
  =.  st  (note-frame st '> ' req)
  =.  st  st(since since, req (crip "kinds 1,6,5 by + kinds 1,6,7,5 #p the {<(lent follows)>} follows since {<since>}; kinds 0 since {<(fall prof-since 0)>}"))
  ;<  ~  bind:m  (report st)
  =/  keep=@ud  (jnum cfg 'keep' 500)
  =|  eose=?
  ::  discovery is batched: unknown authors and missing roots collect
  ::  in want-p / want-e and go out as ONE subscription each (disc-p,
  ::  disc-e), never more than one of each in flight (busy-*), flushed
  ::  at EOSE and every 10th event. Per-event REQs were a storm: each
  ::  answer brought more unknowns, relays cap open subscriptions.
  =|  asked=(map @t ?)
  =|  want-p=(list @t)
  =|  want-e=(list @t)
  =|  busy-p=?
  =|  busy-e=?
  |-  ^-  form:m
  ;<  in=relay-in  bind:m  (take-frame-or-cmd u.wid)
  ?:  ?=(%closed -.in)
    ;<  ~  bind:m  (report st(stage 'closed'))
    (pure:m ?:(eose %ok %fail))
  ?:  ?=(%cmd -.in)
    =/  action=@t  (jstr jon.in 'action')
    ?:  =('send' action)
      =/  road=road:tarball  (nex-road:io rail [%& /outbox (cat 3 (jstr jon.in 'id') '.json')])
      ;<  ob=(unit json)  bind:m  (peek-as:io road ,json)
      ?~  ob  $
      =/  frame=@t  (en:json:html [%a ~[s+'EVENT' (jget u.ob 'event')]])
      ;<  ~  bind:m  (ws-send:io u.wid frame)
      =.  st  (note-frame st '> ' frame)
      ;<  ~  bind:m  (report st)
      $
    ?:  =('fetch' action)
      ::  an extra subscription for what points at one event; its EOSE
      ::  closes it (below), so the socket keeps only the timeline sub
      =/  target=@t  (jstr jon.in 'id')
      ?:  =('' target)  $
      =/  frame=@t  (req-thread target)
      ;<  ~  bind:m  (ws-send:io u.wid frame)
      =.  st  (note-frame st '> ' frame)
      ;<  ~  bind:m  (report st)
      $
    ?:  =('fetch-tag' action)
      ::  posts under one hashtag, one-shot (NIP-12 #t filter)
      =/  t=(unit @t)  (clean-tag (jstr jon.in 'tag'))
      ?~  t  $
      =/  frame=@t
        %-  en:json:html
        :-  %a
        :~  s+'REQ'  s+(cat 3 'tag-' u.t)
            %-  pairs:enjs:format
            :~  ['kinds' [%a ~[(numb:enjs:format 1)]]]
                ['#t' [%a ~[s+u.t]]]
                ['limit' (numb:enjs:format 50)]
            ==
        ==
      ;<  ~  bind:m  (ws-send:io u.wid frame)
      =.  st  (note-frame st '> ' frame)
      ;<  ~  bind:m  (report st)
      $
    ?:  =('fetch-many' action)
      ::  fill in the gaps at once: profiles for a list of authors, and
      ::  roots (plus what points at them) for a list of ids; one-shot
      =/  authors=(list @t)  (jstrs jon.in 'authors')
      =/  ids=(list @t)  (jstrs jon.in 'ids')
      ;<  ~  bind:m
        ?:  =(~ authors)  (pure:(fiber:fiber:nexus ,~) ~)
        (ws-send:io u.wid (en:json:html [%a ~[s+'REQ' s+'fill-p' (filter ~[0] authors ~)]]))
      ;<  ~  bind:m
        ?:  =(~ ids)  (pure:(fiber:fiber:nexus ,~) ~)
        %+  ws-send:io  u.wid
        %-  en:json:html
        :-  %a
        :~  s+'REQ'  s+'fill-e'
            (pairs:enjs:format ~[['ids' [%a (turn ids |=(i=@t s+i))]]])
            (filter-tag ~[1 6 7 5] 'e' ids ~)
        ==
      =.  st  (note-frame st '> ' (crip "fill: {<(lent authors)>} profiles, {<(lent ids)>} roots"))
      ;<  ~  bind:m  (report st)
      $
    ?:  =('fetch-author' action)
      ::  one person's profile and recent posts, one-shot
      =/  pk=@t  (jstr jon.in 'pubkey')
      ?:  =('' pk)  $
      =/  subid=@t  (cat 3 'fetch-' (end [3 12] pk))
      =/  frame=@t
        %-  en:json:html
        :-  %a
        :~  s+'REQ'  s+subid
            %-  pairs:enjs:format
            :~  ['kinds' [%a ~[(numb:enjs:format 0) (numb:enjs:format 1)]]]
                ['authors' [%a ~[s+pk]]]
                ['limit' (numb:enjs:format 40)]
            ==
        ==
      ;<  ~  bind:m  (ws-send:io u.wid frame)
      =.  st  (note-frame st '> ' frame)
      ;<  ~  bind:m  (report st)
      $
    ?:  =('raw' action)
      =/  frame=@t  (jstr jon.in 'text')
      ?:  =('' frame)  $
      ;<  ~  bind:m  (ws-send:io u.wid frame)
      =.  st  (note-frame st '> ' frame)
      ;<  ~  bind:m  (report st)
      $
    ?:  |(=('reconnect' action) =('stop' action))
      ;<  ~  bind:m  (report st(stage ?:(=('stop' action) 'stopped' 'closed')))
      ;<  ~  bind:m  (ws-close:io u.wid)
      (pure:m ?:(=('stop' action) %stop %ok))
    $
  =.  st  (note-frame st '< ' text.in)
  =/  msg=(unit json)  (de:json:html text.in)
  ?.  ?=([~ %a *] msg)  $
  =/  parts=(list json)  p.u.msg
  ?~  parts  $
  =/  tag=@t  ?:(?=([%s *] i.parts) p.i.parts '')
  ?:  =('EOSE' tag)
    ::  a fetch-* subscription is one-shot: close it on its EOSE
    ::  (`subid`, not `sub`: that name is the subtraction gate used below)
    =/  subid=@t  (jstr-at parts 1)
    ?.  |(=('timeline' subid) =('' subid))
      =/  frame=@t  (en:json:html [%a ~[s+'CLOSE' s+subid]])
      ;<  ~  bind:m  (ws-send:io u.wid frame)
      =.  st  (note-frame st '> ' frame)
      =.  busy-p  ?:(=('disc-p' subid) | busy-p)
      =.  busy-e  ?:(=('disc-e' subid) | busy-e)
      ;<  d=[(list @t) (list @t) ? ?]  bind:m
        (flush-discovery u.wid want-p want-e busy-p busy-e)
      =.  want-p  -.d
      =.  want-e  +<.d
      =.  busy-p  +>-.d
      =.  busy-e  +>+.d
      $
    ;<  ~  bind:m  (save-index rail idx keep)
    ;<  now=@da  bind:m  get-time:io
    =.  st  st(stage 'live', eose-at (div (sub now ~1970.1.1) ~s1))
    ;<  ~  bind:m  (report st)
    $(eose &)
  ?:  =('NOTICE' tag)
    =.  st  st(notice (jstr-at parts 1))
    ;<  ~  bind:m  (report st)
    $
  ?:  =('CLOSED' tag)
    ::  only the timeline matters; a refused one-shot is just dropped
    ?.  =('timeline' (jstr-at parts 1))
      =.  busy-p  ?:(=('disc-p' (jstr-at parts 1)) | busy-p)
      =.  busy-e  ?:(=('disc-e' (jstr-at parts 1)) | busy-e)
      $
    =.  st  st(stage 'closed', error (cat 3 'relay closed the subscription: ' (jstr-at parts 2)))
    ;<  ~  bind:m  (report st)
    ;<  ~  bind:m  (ws-close:io u.wid)
    (pure:m ?:(eose %ok %fail))
  ?:  =('OK' tag)
    ;<  ~  bind:m  (record-ok rail host (jstr-at parts 1) (jbool-at parts 2) (jstr-at parts 3))
    $
  ?.  =('EVENT' tag)  $
  ?.  ?=([* * * ~] parts)  $
  =/  ev=json  i.t.t.parts
  =/  kind=@ud  (jnum ev 'kind' 1)
  ?:  =(0 kind)
    ;<  ~  bind:m  (put-profile rail (jstr ev 'pubkey') ev)
    =.  st  st(profiles +(profiles.st))
    $
  ?.  ?=(?(%1 %6 %7 %5) kind)  $
  =/  id=@t  (jstr ev 'id')
  ?:  =('' id)  $
  ::  a deletion request (kind 5, NIP-09): the author retracting their
  ::  own events. Honored here for what we hold: the retracted events
  ::  leave refs/ and the feed index, and their grubs are culled; the
  ::  request itself is kept as the record of why.
  ;<  gone=(list @t)  bind:m
    ?.  =(5 kind)  (pure:(fiber:fiber:nexus ,(list @t)) ~)
    (apply-deletion rail ev)
  =.  idx  (roll gone |=([i=@t acc=_idx] (~(del by acc) i)))
  ::  the feed index is the follows' own kind-1 posts (replies included,
  ::  the card says what they answer); everything else is reachable
  ::  through refs/
  ::  (`in` is the intake face here, so the set core is not reachable
  ::  by that name; a linear scan of 75 follows is fine)
  =/  author=@t  (jstr ev 'pubkey')
  =?  idx  &(?=(?(%1 %6) kind) (lien follows |=(p=@t =(p author))))
    (~(put by idx) id [(jnum ev 'created_at' 0) author])
  =/  road=road:tarball  (nex-road:io rail [%& /events (cat 3 id '.json')])
  ;<  have=?  bind:m  (peek-exists:io road)
  =.  st  st(events +(events.st), new ?:(have new.st +(new.st)))
  ;<  ~  bind:m
    ?:  have  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  err=(unit tang)  bind:(fiber:fiber:nexus ,~)  (make-soft:io road |+[[[/ %json] ev] ~])
    ?^  err  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  ~  bind:(fiber:fiber:nexus ,~)  (note-author rail ev)
    ;<  ~  bind:(fiber:fiber:nexus ,~)  (note-refs rail ev)
    ;<  ~  bind:(fiber:fiber:nexus ,~)  (note-tags rail ev)
    ::  a repost carries the original in its content (NIP-18): keep it
    ?.  =(6 kind)  (pure:(fiber:fiber:nexus ,~) ~)
    (store-embedded rail ev)
  ::  discovery, on every new event: an author we hold no profile for
  ::  gets a one-shot kind-0 REQ (a query, not a follow: their posts
  ::  are not asked for); a reply whose root we don't hold gets the
  ::  root by id plus what points at it, so threads arrive whole
  =/  pkey=@t  (cat 3 'p:' author)
  ;<  have-prof=?  bind:m
    ?:  |(have (~(has by asked) pkey))  (pure:(fiber:fiber:nexus ,?) &)
    (peek-exists:io (nex-road:io rail [%& /profiles (cat 3 author '.json')]))
  =.  asked  (~(put by asked) pkey &)
  =?  want-p  !have-prof  [author want-p]
  =/  root=(unit @t)
    ?:  |(have !=(1 kind))  ~
    =/  er  (e-refs ev)
    ?~  er
      ::  no reply chain: a quoted post (q tag) is worth holding too
      =/  q=@t  (first-tag ev 'q')
      ?:(=('' q) ~ `q)
    `root.u.er
  =/  ekey=@t  ?~(root '' (cat 3 'e:' u.root))
  ;<  have-root=?  bind:m
    ?:  |(?=(~ root) (~(has by asked) ekey))  (pure:(fiber:fiber:nexus ,?) &)
    (peek-exists:io (nex-road:io rail [%& /events (cat 3 u.root '.json')]))
  =.  asked  ?~(root asked (~(put by asked) ekey &))
  =?  want-e  !have-root  [(need root) want-e]
  ::  (bound to d, then =. into the loop faces: $ recurs on the trap's
  ::  own subject, which ;< bindings sit outside of)
  ;<  d=[(list @t) (list @t) ? ?]  bind:m
    ?.  =(0 (mod events.st 10))  (pure:(fiber:fiber:nexus ,[(list @t) (list @t) ? ?]) [want-p want-e busy-p busy-e])
    (flush-discovery u.wid want-p want-e busy-p busy-e)
  =?  st  &(!busy-p +>-.d)  (note-frame st '> ' (crip "disc-p: {<(min 50 (lent want-p))>} profiles"))
  =?  st  &(!busy-e +>+.d)  (note-frame st '> ' (crip "disc-e: {<(min 20 (lent want-e))>} roots"))
  =.  want-p  -.d
  =.  want-e  +<.d
  =.  busy-p  +>-.d
  =.  busy-e  +>+.d
  ::  the index and the status are rewritten every 10th event (the
  ::  index is ~40KB, revalidated on every write) and on every state
  ::  change; the first few frames of a session write too, so a stuck
  ::  session is visible. One event is one arvo event: keep it cheap.
  =/  write=?  |((lth events.st 4) =(0 (mod events.st 10)))
  ;<  ~  bind:m
    ?:  &(eose write)  (save-index rail idx keep)
    (pure:(fiber:fiber:nexus ,~) ~)
  ;<  ~  bind:m
    ?:  write  (report st)
    (pure:(fiber:fiber:nexus ,~) ~)
  $
::  +relay-st / +relay-status: the client's state as relays/<host>.json
+$  relay-st
  $:  host=@t
      stage=@t          ::  starting connecting open live closed no-follows
      wid=(unit @ud)
      events=@ud        ::  kind-1 frames this session
      new=@ud           ::  of which were not yet in events/
      profiles=@ud      ::  kind-0 frames this session
      eose-at=@ud       ::  unix seconds, 0 until EOSE
      notice=@t
      error=@t
      tries=@ud         ::  consecutive failed sessions before this one
      since=@ud         ::  the since= sent (newest indexed, or backfill)
      req=@t            ::  the REQ sent, summarised
      started=@ud       ::  this session's start, unix; the next session's
                        ::  kind-0 since=
      recent=(list @t)  ::  the last frames, newest first, '> ' sent
                        ::  '< ' received, truncated
  ==
++  relay-status
  |=  [=rail:tarball st=relay-st]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['host' s+host.st]
        ['stage' s+stage.st]
        ['wid' ?~(wid.st ~ (numb:enjs:format u.wid.st))]
        ['events' (numb:enjs:format events.st)]
        ['new' (numb:enjs:format new.st)]
        ['profiles' (numb:enjs:format profiles.st)]
        ['eose_at' (numb:enjs:format eose-at.st)]
        ['notice' s+notice.st]
        ['error' s+error.st]
        ['tries' (numb:enjs:format tries.st)]
        ['since' (numb:enjs:format since.st)]
        ['req' s+req.st]
        ['started' (numb:enjs:format started.st)]
        ['recent' [%a (turn recent.st |=(t=@t s+t))]]
        ['updated' (numb:enjs:format (div (sub now ~1970.1.1) ~s1))]
    ==
  =/  road=road:tarball  (nex-road:io rail [%& /relays (cat 3 host.st '.json')])
  ;<  have=?  bind:m  (peek-exists:io road)
  ?:  have  (over:io road [[/ %json] jon])
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] jon] ~])
  (pure:m ~)
::  +note-frame: keep the last 12 frames on the status, truncated
++  note-frame
  |=  [st=relay-st dir=@t text=@t]
  ^-  relay-st
  =/  t=tape  (trip text)
  =/  short=@t  (crip ?:((gth (lent t) 240) (weld (scag 240 t) "…") t))
  st(recent (scag 12 `(list @t)`[(cat 3 dir short) recent.st]))
::  +relay-in / +take-frame-or-cmd: the next thing a client must act
::  on — a text frame on its socket, the socket closing, or a json poke
::  (a command). Any other poke is skipped. Mirrors take-ws-frame:io.
+$  relay-in  $%([%frame text=@t] [%closed ~] [%cmd jon=json])
++  take-frame-or-cmd
  |=  wid=@ud
  =/  m  (fiber:fiber:nexus ,relay-in)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ::  anything not for this socket is DROPPED (%wait consumes it), never
  ::  %skip: a skipped input is retained and re-offered on every later
  ::  step, so frames from a stale socket would replay on every new one
  ?+  in  [%wait ~]
      ~  [%wait ~]
      [~ %veto *]  [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %json] p.sage.u.in)  [%done [%cmd !<(json q.sage.u.in)]]
    ?:  =([/ %ws-closed] p.sage.u.in)
      ?.  =(wid !<(@ud q.sage.u.in))  [%wait ~]
      [%done [%closed ~]]
    ?.  =([/ %ws-frame] p.sage.u.in)  [%wait ~]
    =/  [w=@ud msg=ws-message:nexus]  !<([@ud ws-message:nexus] q.sage.u.in)
    ?.  =(w wid)  [%wait ~]
    ?~  message.msg  [%wait ~]
    =/  bytes=octs  u.message.msg
    [%done [%frame q.bytes]]
  ==
::  +record-ok: a relay's verdict on an event we published, into
::  outbox/<id>.json relays.<host>
++  record-ok
  |=  [=rail:tarball host=@t id=@t ok=? msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  =('' id)  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& /outbox (cat 3 id '.json')])
  ;<  ob=(unit json)  bind:m  (peek-as:io road ,json)
  ?~  ob  (pure:m ~)
  ?.  ?=([%o *] u.ob)  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  =/  verdict=json
    %-  pairs:enjs:format
    :~  ['ok' b+ok]
        ['message' s+msg]
        ['at' (numb:enjs:format (div (sub now ~1970.1.1) ~s1))]
    ==
  =/  relays=json  (jget u.ob 'relays')
  =/  relays=json  [%o (~(put by ?.(?=([%o *] relays) ~ p.relays)) host verdict)]
  (over:io road [[/ %json] [%o (~(put by p.u.ob) 'relays' relays)]])
::  ---------------------------------------------------------------------
::  the account: identity, publishing, follows, relay config. Each is a
::  file; these arms are the only writers the page uses.
::
::  ACCOUNTS. One keypair is one dir, accounts/<pubkey>/ holding
::  secret.json, identity.json and profile.json; me.json says which one
::  is current, and everything that signs (post, reply, react, repost,
::  profile) signs as the current one. The older single me/ layout is
::  moved into accounts/ the first time anything asks.
::
::  +acct: the dir path of one account
++  acct
  |=  pk=@t
  ^-  path
  [%accounts `@ta`pk ~]
::  +current-pk: the current account's pubkey (hex), or ~ when none
++  current-pk
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  me=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'me.json']) ,json)
  =/  cur=@t  (jstr (fall me [%o ~]) 'current')
  ?.  =('' cur)  (pure:m `cur)
  ::  nothing current: an old me/ may still be there to migrate, or
  ::  there may be accounts and no choice yet — take the first
  ;<  moved=(unit @t)  bind:m  (migrate-me rail)
  ?^  moved  (pure:m moved)
  ;<  pks=(list @t)  bind:m  (account-pks rail)
  ?~  pks  (pure:m ~)
  ;<  ~  bind:m  (set-current rail i.pks)
  (pure:m `i.pks)
++  set-current
  |=  [=rail:tarball pk=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (nex-road:io rail [%& / %'me.json']) [[/ %json] (pairs:enjs:format ~[['current' s+pk]])])
::  +account-pks: every accounts/<pubkey>/ dir name
++  account-pks
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /accounts]) ~)
  %-  pure:m
  ?.  ?=([%ball *] v)  ~
  ::  subdirectories are the ball's dir map (contents lists files only)
  (turn ~(tap in ~(key by dir.ball.v)) |=(name=@ta `@t`name))
::  +migrate-me: me/secret.json (+ identity, profile) -> accounts/<pk>/,
::  made current; the old files are culled. ~ when there is nothing.
++  migrate-me
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  sec=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'secret.json']) ,json)
  ?~  sec  (pure:m ~)
  =/  priv=(unit @ux)  (parse-hex:nl (jstr u.sec 'privkey'))
  ?~  priv  (pure:m ~)
  ;<  idn=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'identity.json']) ,json)
  ;<  prof=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'profile.json']) ,json)
  =/  since=@ud  (jnum (fall idn [%o ~]) 'since' 0)
  ;<  pk=(unit @t)  bind:m  (add-account rail u.priv since (fall prof [%o ~]))
  ?~  pk  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /me %'secret.json']))
  ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /me %'identity.json']))
  ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /me %'profile.json']))
  ~&  [%nostr-accounts %migrated-me u.pk]
  (pure:m pk)
::  +add-account: file a keypair as accounts/<pk>/ and make it current.
::  An existing account of the same key is left alone (just made current).
++  add-account
  |=  [=rail:tarball priv=@ux since=@ud prof=json]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  pub=@ux  x:(priv-to-pub:secp256k1:secp:crypto priv)
  =/  pk=@t  (to-hex:nl 64 pub)
  =/  dir=road:tarball  (nex-road:io rail [%| (acct pk)])
  ;<  have=?  bind:m  (peek-exists:io dir)
  ;<  ~  bind:m
    ?:  have  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  now=@da  bind:(fiber:fiber:nexus ,~)  get-time:io
    =/  at=@ud  ?:(=(0 since) (div (sub now ~1970.1.1) ~s1) since)
    =/  sec=json  (pairs:enjs:format ~[['privkey' s+(to-hex:nl 64 priv)] ['nsec' s+(nsec:nl priv)]])
    =/  idn=json
      (pairs:enjs:format ~[['pubkey' s+pk] ['npub' s+(npub:nl pub)] ['since' (numb:enjs:format at)]])
    ;<  err=(unit tang)  bind:(fiber:fiber:nexus ,~)  (make-soft:io dir &+[`[~ ~ %.n ~] ~])
    ;<  *  bind:(fiber:fiber:nexus ,~)  (make-soft:io (nex-road:io rail [%& (acct pk) %'secret.json']) |+[[[/ %json] sec] ~])
    ;<  *  bind:(fiber:fiber:nexus ,~)  (make-soft:io (nex-road:io rail [%& (acct pk) %'identity.json']) |+[[[/ %json] idn] ~])
    ;<  *  bind:(fiber:fiber:nexus ,~)  (make-soft:io (nex-road:io rail [%& (acct pk) %'profile.json']) |+[[[/ %json] prof] ~])
    ::  (follows.json is made on first read: the old ship-level list if
    ::  there is one, else the defaults — see +account-follows)
    (pure:(fiber:fiber:nexus ,~) ~)
  ;<  ~  bind:m  (set-current rail pk)
  (pure:m `pk)
::  +me-keys: the current account's keypair, or ~
++  me-keys
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit keys:nl))
  ^-  form:m
  ;<  cur=(unit @t)  bind:m  (current-pk rail)
  ?~  cur  (pure:m ~)
  ;<  sec=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& (acct u.cur) %'secret.json']) ,json)
  ?~  sec  (pure:m ~)
  =/  priv=(unit @ux)  (parse-hex:nl (jstr u.sec 'privkey'))
  ?~  priv  (pure:m ~)
  (pure:m `[x:(priv-to-pub:secp256k1:secp:crypto u.priv) u.priv])
::  +generate-identity: a fresh keypair as a new account, made current
++  generate-identity
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  k=keys:nl  (gen-keys:nl eny)
  (add-account rail priv.k 0 [%o ~])
::  +account-rows: every account with its identity and profile, for the page
++  account-rows
  |=  [=rail:tarball cur=(unit @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  pks=(list @t)  bind:m  (account-pks rail)
  =|  out=(list json)
  |-
  ?~  pks  (pure:m (flop out))
  ;<  idn=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& (acct i.pks) %'identity.json']) ,json)
  ;<  prof=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& (acct i.pks) %'profile.json']) ,json)
  =/  row=json
    %-  pairs:enjs:format
    :~  ['pubkey' s+i.pks]
        ['npub' s+(jstr (fall idn [%o ~]) 'npub')]
        ['since' (numb:enjs:format (jnum (fall idn [%o ~]) 'since' 0))]
        ['profile' (fall prof [%o ~])]
        ['current' b+=(cur `i.pks)]
    ==
  $(pks t.pks, out [row out])
::  +publish: sign an event, file it in outbox/, push it down every
::  relay client. Returns the event id, or ~ without a key.
++  publish
  |=  [=rail:tarball kind=@ud tags=(list (list @t)) content=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  k=(unit keys:nl)  bind:m  (me-keys rail)
  ?~  k  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  at=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  ev=json  (make-event:nl u.k at kind tags content eny)
  =/  id=@t  (jstr ev 'id')
  =/  doc=json
    (pairs:enjs:format ~[['event' ev] ['relays' [%o ~]] ['at' (numb:enjs:format at)]])
  ;<  err=(unit tang)  bind:m
    (make-soft:io (nex-road:io rail [%& /outbox (cat 3 id '.json')]) |+[[[/ %json] doc] ~])
  ?^  err  (pure:m ~)
  ::  our own event is an event like any other: into events/ and refs/
  ::  now, so the page shows it without waiting for a relay to echo it
  ;<  *  bind:m
    (make-soft:io (nex-road:io rail [%& /events (cat 3 id '.json')]) |+[[[/ %json] ev] ~])
  ;<  ~  bind:m  (note-author rail ev)
  ;<  ~  bind:m  (note-refs rail ev)
  ;<  ~  bind:m  (poke-relays rail (pairs:enjs:format ~[['action' s+'send'] ['id' s+id]]))
  (pure:m `id)
::  +poke-relays: the same json to every relays/<host>.sig
++  poke-relays
  |=  [=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  names=(list @ta)  bind:m  (relay-names rail ".sig")
  |-
  ?~  names  (pure:m ~)
  ;<  *  bind:m  (poke-soft:io (nex-road:io rail [%& /relays i.names]) [/ %json] jon)
  $(names t.names)
::  +flush-discovery: send the pending discovery lists as one REQ each,
::  if none of that kind is in flight; caps keep a frame small
++  flush-discovery
  |=  [wid=@ud want-p=(list @t) want-e=(list @t) busy-p=? busy-e=?]
  =/  m  (fiber:fiber:nexus ,[(list @t) (list @t) ? ?])
  ^-  form:m
  ;<  ~  bind:m
    ?:  |(busy-p =(~ want-p))  (pure:(fiber:fiber:nexus ,~) ~)
    (ws-send:io wid (en:json:html [%a ~[s+'REQ' s+'disc-p' (filter ~[0] (scag 50 want-p) ~)]]))
  =/  sent-p=?  &(!busy-p !=(~ want-p))
  ;<  ~  bind:m
    ?:  |(busy-e =(~ want-e))  (pure:(fiber:fiber:nexus ,~) ~)
    %+  ws-send:io  wid
    %-  en:json:html
    :-  %a
    :~  s+'REQ'  s+'disc-e'
        (pairs:enjs:format ~[['ids' [%a (turn (scag 20 want-e) |=(i=@t s+i))]]])
        (filter-tag ~[1 6 7 5] 'e' (scag 20 want-e) ~)
    ==
  =/  sent-e=?  &(!busy-e !=(~ want-e))
  %-  pure:m
  :^    ?:(sent-p (slag 50 want-p) want-p)
      ?:(sent-e (slag 20 want-e) want-e)
    |(busy-p sent-p)
  |(busy-e sent-e)
::  +req-profile / +req-thread: one-shot REQ frames (their EOSE closes
::  them): one person's kind-0; one event by id plus what points at it
++  req-profile
  |=  pk=@t
  ^-  @t
  (en:json:html [%a ~[s+'REQ' s+(cat 3 'prof-' (end [3 12] pk)) (filter ~[0] ~[pk] ~)]])
++  req-thread
  |=  id=@t
  ^-  @t
  %-  en:json:html
  :-  %a
  :~  s+'REQ'  s+(cat 3 'fetch-' (end [3 12] id))
      (pairs:enjs:format ~[['ids' [%a ~[s+id]]]])
      (filter-tag ~[1 6 7 5] 'e' ~[id] ~)
      (filter-tag ~[1 6 7] 'q' ~[id] ~)
  ==
::  +relay-names: the grubs under relays/ with a given extension
++  relay-names
  |=  [=rail:tarball ext=tape]
  (dir-names rail /relays ext)
::  +dir-names: the grubs under a dir with a given extension
++  dir-names
  |=  [=rail:tarball dir=path ext=tape]
  =/  m  (fiber:fiber:nexus ,(list @ta))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| dir]) ~)
  %-  pure:m
  ?.  ?=([%ball *] v)  ~
  ?~  fil.ball.v  ~
  %+  murn  ~(tap by contents.u.fil.ball.v)
  |=  [name=@ta *]
  =/  n=tape  (trip name)
  =/  l=@ud  (lent ext)
  ?.  &((gth (lent n) l) =(ext (slag (sub (lent n) l) n)))  ~
  `name
::  +set-follows: the current account's follows.json, then every relay
::  client reconnects (their subscription is the union over accounts)
++  set-follows
  |=  [=rail:tarball pks=(list @t)]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  cur=(unit @t)  bind:m  (current-pk rail)
  ?~  cur  (pure:m |)
  ;<  *  bind:m  (account-follows rail u.cur)
  ;<  ~  bind:m  (over:io (nex-road:io rail [%& (acct u.cur) %'follows.json']) [[/ %json] (follows-doc pks)])
  ;<  ~  bind:m  (poke-relays rail (pairs:enjs:format ~[['action' s+'reconnect']]))
  (pure:m &)
::  +set-relays: config.json relays; new ones spawn, dropped ones stop
::  and their grubs go
++  set-relays
  |=  [=rail:tarball urls=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  (read-config rail)
  =/  next=json  [%o (~(put by ?.(?=([%o *] cfg) ~ p.cfg)) 'relays' [%a (turn urls |=(u=@t s+u))])]
  ;<  ~  bind:m  (over:io (nex-road:io rail [%& / %'config.json']) [[/ %json] next])
  =/  keep=(set @t)  (sy (turn urls relay-host))
  ;<  sigs=(list @ta)  bind:m  (relay-names rail ".sig")
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    |-  ^-  form:m
    ?~  sigs  (pure:m ~)
    =/  n=tape  (trip i.sigs)
    =/  host=@t  (crip (scag (sub (lent n) 4) n))
    ?:  (~(has in keep) host)  $(sigs t.sigs)
    ;<  *  bind:m  (poke-soft:io (nex-road:io rail [%& /relays i.sigs]) [/ %json] (pairs:enjs:format ~[['action' s+'stop']]))
    ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /relays i.sigs]))
    ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /relays (cat 3 host '.json')]))
    $(sigs t.sigs)
  (ensure-relays rail)
::  +filter: one NIP-01 filter object
++  filter
  |=  [kinds=(list @ud) authors=(list @t) since=(unit @ud)]
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    :~  ['kinds' [%a (turn kinds numb:enjs:format)]]
        ['authors' [%a (turn authors |=(a=@t s+a))]]
    ==
  ?~(since ~ ~[['since' (numb:enjs:format u.since)]])
::  +filter-tag: a NIP-01 filter on a single-letter tag ("#p": [...])
++  filter-tag
  |=  [kinds=(list @ud) tag=@t values=(list @t) since=(unit @ud)]
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    :~  ['kinds' [%a (turn kinds numb:enjs:format)]]
        [(cat 3 '#' tag) [%a (turn values |=(a=@t s+a))]]
    ==
  ?~(since ~ ~[['since' (numb:enjs:format u.since)]])
::  +tags: an event's tags as lists of strings
++  tags
  |=  ev=json
  ^-  (list (list @t))
  %+  turn  (jarr ev 'tags')
  |=(t=json ?.(?=([%a *] t) ~ (murn p.t |=(x=json ?:(?=([%s *] x) `p.x ~)))))
::  +e-refs: what an event points at (NIP-10). root = the e tag marked
::  "root", else the first e tag; parent = the one marked "reply", else
::  the last e tag. ~ for an event that points at nothing.
++  e-refs
  |=  ev=json
  ^-  (unit [root=@t parent=@t])
  =/  es=(list [id=@t marker=@t])
    %+  murn  (tags ev)
    |=  t=(list @t)
    ?.  ?=([%e @ *] t)  ~
    `[i.t.t ?~(t.t.t '' ?~(t.t.t.t '' i.t.t.t.t))]
  ?~  es  ~
  ::  (the null check refines es to a cell; the wet gates below want
  ::  the plain list type back)
  =/  all=(list [id=@t marker=@t])  es
  =/  root=(unit @t)
    =/  r  (skim all |=([* m=@t] =('root' m)))
    ?~(r ~ `id.i.r)
  =/  reply=(unit @t)
    =/  r  (skim all |=([* m=@t] =('reply' m)))
    ?~(r ~ `id.i.r)
  =/  first=@t  id.i.es
  =/  last=@t  id:(rear all)
  =/  rt=@t  (fall root first)
  `[rt (fall reply ?:(=(1 (lent es)) rt last))]
::  +apply-deletion: honor a kind 5 for every listed event we hold that
::  the same key signed: out of its target's refs row, its grub culled.
::  Returns the ids that were kind-1 posts (to drop from a feed index).
++  apply-deletion
  |=  [=rail:tarball del=json]
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  =/  who=@t  (jstr del 'pubkey')
  =/  ids=(list @t)
    %+  murn  (tags del)
    |=(t=(list @t) ?.(?=([%e @ *] t) ~ `i.t.t))
  =|  posts=(list @t)
  |-
  ?~  ids  (pure:m posts)
  =/  road=road:tarball  (nex-road:io rail [%& /events (cat 3 i.ids '.json')])
  ;<  ev=(unit json)  bind:m  (peek-as:io road ,json)
  ?~  ev  $(ids t.ids)
  ?.  =(who (jstr u.ev 'pubkey'))  $(ids t.ids)
  =/  kind=@ud  (jnum u.ev 'kind' 1)
  ;<  ~  bind:m  (unnote-refs rail u.ev)
  ;<  *  bind:m  (cull-soft:io road)
  ~&  [%nostr %deleted i.ids %kind kind %by (end [3 12] who)]
  $(ids t.ids, posts ?:(=(1 kind) [i.ids posts] posts))
::  +unnote-refs: the inverse of note-refs: one event's row leaves the
::  refs of what it pointed at
++  unnote-refs
  |=  [=rail:tarball ev=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  kind=@ud  (jnum ev 'kind' 1)
  ?.  ?=(?(%1 %6 %7) kind)  (pure:m ~)
  =/  refs=(unit [root=@t parent=@t])  (e-refs ev)
  ?~  refs  (pure:m ~)
  =/  under=@t  ?:(=(1 kind) root.u.refs parent.u.refs)
  =/  field=@t  ?+(kind 'replies' %6 'reposts', %7 'reactions')
  =/  id=@t  (jstr ev 'id')
  =/  road=road:tarball  (nex-road:io rail [%& /refs (cat 3 under '.json')])
  ;<  cur=(unit json)  bind:m  (peek-as:io road ,json)
  ?~  cur  (pure:m ~)
  ?.  ?=([%o *] u.cur)  (pure:m ~)
  =/  kept=(list json)  (skip (jarr u.cur field) |=(j=json =(id (jstr j 'id'))))
  (over:io road [[/ %json] [%o (~(put by p.u.cur) field [%a kept])]])
::  +note-refs: file one event's pointers. A reply goes under its thread
::  root (with its parent, so a tree can be built); a repost or reaction
::  goes under its target. refs/<id>.json = {replies, reposts, reactions}
++  note-refs
  |=  [=rail:tarball ev=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  kind=@ud  (jnum ev 'kind' 1)
  ::  only replies, reposts and reactions are references; a kind 5
  ::  (deletion request) also carries e tags but is not one
  ?.  ?=(?(%1 %6 %7) kind)  (pure:m ~)
  =/  refs=(unit [root=@t parent=@t])  (e-refs ev)
  ?~  refs  (pure:m ~)
  =/  under=@t  ?:(=(1 kind) root.u.refs parent.u.refs)
  =/  entry=json
    %-  pairs:enjs:format
    %+  weld
      ^-  (list [@t json])
      :~  ['id' s+(jstr ev 'id')]
          ['pubkey' s+(jstr ev 'pubkey')]
          ['at' (numb:enjs:format (jnum ev 'created_at' 0))]
      ==
    ^-  (list [@t json])
    ?+  kind  ~
      %1  ~[['parent' s+parent.u.refs]]
      %7  ~[['content' s+(jstr ev 'content')]]
    ==
  =/  field=@t  ?+(kind 'replies' %6 'reposts', %7 'reactions')
  =/  road=road:tarball  (nex-road:io rail [%& /refs (cat 3 under '.json')])
  ;<  cur=(unit json)  bind:m  (peek-as:io road ,json)
  =/  doc=json  (fall cur (pairs:enjs:format ~[['replies' [%a ~]] ['reposts' [%a ~]] ['reactions' [%a ~]]]))
  ?.  ?=([%o *] doc)  (pure:m ~)
  =/  have=(list json)  (jarr doc field)
  ::  one fact per event: a reference seen from a second relay is not new
  ?:  (lien have |=(j=json =((jstr j 'id') (jstr ev 'id'))))  (pure:m ~)
  =/  next=json  [%o (~(put by p.doc) field [%a (snoc have entry)])]
  ?^  cur  (over:io road [[/ %json] next])
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] next] ~])
  (pure:m ~)
::  +engagement: for each post id, its reposts and reactions with the
::  actor's profile: [{id, kind, pubkey, name, picture, content, at}]
++  engagement
  |=  [=rail:tarball ids=(list @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =|  out=(list json)
  =|  profs=(map @t json)
  |-
  ?~  ids  (pure:m (flop out))
  ;<  refs=json  bind:m  (read-refs rail i.ids)
  =/  acts=(list [kind=@ud j=json])
    %+  weld
      (turn (jarr refs 'reposts') |=(j=json [6 j]))
    (turn (jarr refs 'reactions') |=(j=json [7 j]))
  ;<  [rows=(list json) profs=(map @t json)]  bind:m
    =/  m  (fiber:fiber:nexus ,[(list json) (map @t json)])
    =|  rows=(list json)
    |-  ^-  form:m
    ?~  acts  (pure:m [(flop rows) profs])
    =/  pk=@t  (jstr j.i.acts 'pubkey')
    ;<  prof=json  bind:m
      ?^  hit=(~(get by profs) pk)  (pure:(fiber:fiber:nexus ,json) u.hit)
      ;<  p=(unit json)  bind:(fiber:fiber:nexus ,json)
        (peek-as:io (nex-road:io rail [%& /profiles (cat 3 pk '.json')]) ,json)
      (pure:(fiber:fiber:nexus ,json) (fall p [%o ~]))
    =/  row=json
      %-  pairs:enjs:format
      :~  ['on' s+i.ids]
          ['id' s+(jstr j.i.acts 'id')]
          ['kind' (numb:enjs:format kind.i.acts)]
          ['pubkey' s+pk]
          ['name' s+(jstr prof 'name')]
          ['picture' s+(jstr prof 'picture')]
          ['content' s+(jstr j.i.acts 'content')]
          ['at' (numb:enjs:format (jnum j.i.acts 'at' 0))]
      ==
    $(acts t.acts, rows [row rows], profs (~(put by profs) pk prof))
  $(ids t.ids, out (weld (flop rows) out), profs profs)
::  +store-embedded: a kind-6's content is the reposted event as json;
::  file it as its own event grub (with author and refs rows) if new.
::  Not verified yet (see the todo): a bad embed is a bad event grub.
++  store-embedded
  |=  [=rail:tarball ev=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  inner=(unit json)  (de:json:html (jstr ev 'content'))
  ?.  ?=([~ %o *] inner)  (pure:m ~)
  =/  id=@t  (jstr u.inner 'id')
  ?:  |(=('' id) =(~ (parse-hex:nl id)) !=(64 (met 3 id)))  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& /events (cat 3 id '.json')])
  ;<  have=?  bind:m  (peek-exists:io road)
  ?:  have  (pure:m ~)
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] u.inner] ~])
  ?^  err  (pure:m ~)
  ;<  ~  bind:m  (note-author rail u.inner)
  ;<  ~  bind:m  (note-refs rail u.inner)
  (note-tags rail u.inner)
::  +note-tags: tags/<t>.json gains this kind-1 event's id for each of
::  its hashtags — the `t` tags (NIP-24) AND #words in the content, since
::  many clients write the text without the tag — newest first, 200
::  kept. Tags are lowercased; only plain [a-z0-9_-] ones get a grub.
++  note-tags
  |=  [=rail:tarball ev=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(1 (jnum ev 'kind' 1))  (pure:m ~)
  =/  id=@t  (jstr ev 'id')
  =/  at=@ud  (jnum ev 'created_at' 0)
  =/  from-tags=(list @t)
    %+  murn  (tags ev)
    |=  l=(list @t)
    ?.  ?=([%t @ *] l)  ~
    (clean-tag i.t.l)
  =/  from-text=(list @t)
    %+  murn  (content-words (jstr ev 'content'))
    |=  w=tape
    ?~  w  ~
    ?.  =('#' i.w)  ~
    (clean-tag (crip t.w))
  =/  ts=(list @t)  ~(tap in (silt (weld from-tags from-text)))
  |-
  ?~  ts  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& /tags (cat 3 i.ts '.json')])
  ;<  cur=(unit json)  bind:m  (peek-as:io road ,json)
  =/  have=(list [id=@t at=@ud])
    %+  murn  (jarr (fall cur [%o ~]) 'posts')
    |=(j=json ?.(?=([%o *] j) ~ `[(jstr j 'id') (jnum j 'at' 0)]))
  ?:  (lien have |=([i=@t *] =(i id)))  $(ts t.ts)
  =/  next=(list [id=@t at=@ud])
    %+  scag  200
    %+  sort  [[id at] have]
    |=([a=[@t at=@ud] b=[@t at=@ud]] (gth at.a at.b))
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['tag' s+i.ts]
        ['posts' [%a (turn next |=([i=@t at=@ud] (pairs:enjs:format ~[['id' s+i] ['at' (numb:enjs:format at)]])))]]
    ==
  ;<  ~  bind:m
    ?^  cur  (over:io road [[/ %json] doc])
    ;<  err=(unit tang)  bind:(fiber:fiber:nexus ,~)  (make-soft:io road |+[[[/ %json] doc] ~])
    (pure:(fiber:fiber:nexus ,~) ~)
  $(ts t.ts)
::  +content-words: a post's text split on whitespace, trailing
::  punctuation dropped (so "#tag," and "#tag." index as #tag)
++  content-words
  |=  t=@t
  ^-  (list tape)
  =/  ws=(list tape)
    %+  murn  (split-ws (trip t))
    |=(w=tape ?:(=(~ w) ~ `w))
  %+  turn  ws
  |=  w=tape
  =/  r=tape  (flop w)
  |-
  ?~  r  ~
  ?:  ?=(?(%'.' %',' %'!' %'?' %':' %';' %')' %'"' %'\'') i.r)  $(r t.r)
  (flop r)
++  split-ws
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop [(flop cur) out])
  ?:  ?=(?(%' ' %'\0a' %'\09' %'\0d') i.t)
    $(t t.t, cur ~, out [(flop cur) out])
  $(t t.t, cur [i.t cur])
::  +clean-tag: a hashtag as a grub name: lowercase, [a-z0-9_-] only
++  clean-tag
  |=  t=@t
  ^-  (unit @t)
  =/  s=tape  (cass (trip t))
  ?:  =(~ s)  ~
  ?.  (levy s |=(c=@tD |(&((gte c 'a') (lte c 'z')) &((gte c '0') (lte c '9')) =(c '_') =(c '-'))))  ~
  `(crip s)
::  +first-tag: the second element of the first tag named t
++  first-tag
  |=  [ev=json t=@t]
  ^-  @t
  =/  hit  (find ~[t] (turn (tags ev) |=(l=(list @t) ?~(l '' i.l))))
  ?~  hit  ''
  =/  l=(list @t)  (snag u.hit (tags ev))
  ?~  l  ''
  ?~  t.l  ''
  i.t.l
::  +note-author: authors/<pk>.json gains this kind-1 event's id, newest
::  first, capped at 200
++  note-author
  |=  [=rail:tarball ev=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(1 (jnum ev 'kind' 1))  (pure:m ~)
  =/  pk=@t  (jstr ev 'pubkey')
  =/  id=@t  (jstr ev 'id')
  ?:  |(=('' pk) =('' id))  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& /authors (cat 3 pk '.json')])
  ;<  cur=(unit json)  bind:m  (peek-as:io road ,json)
  =/  have=(list [id=@t at=@ud])
    %+  murn  (jarr (fall cur [%o ~]) 'posts')
    |=(j=json ?.(?=([%o *] j) ~ `[(jstr j 'id') (jnum j 'at' 0)]))
  ?:  (lien have |=([i=@t *] =(i id)))  (pure:m ~)
  =/  next=(list [id=@t at=@ud])
    %+  scag  200
    %+  sort  [[id (jnum ev 'created_at' 0)] have]
    |=([a=[@t at=@ud] b=[@t at=@ud]] (gth at.a at.b))
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['pubkey' s+pk]
        ['posts' [%a (turn next |=([i=@t at=@ud] (pairs:enjs:format ~[['id' s+i] ['at' (numb:enjs:format at)]])))]]
    ==
  ?^  cur  (over:io road [[/ %json] doc])
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] doc] ~])
  (pure:m ~)
::  +read-refs: refs/<id>.json or an empty one
++  read-refs
  |=  [=rail:tarball id=@t]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  r=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /refs (cat 3 id '.json')]) ,json)
  (pure:m (fall r (pairs:enjs:format ~[['replies' [%a ~]] ['reposts' [%a ~]] ['reactions' [%a ~]]])))
::  +put-profile: a kind-0 event's content is the profile object; store
::  it as profiles/<pk>.json when new or changed
++  put-profile
  |=  [=rail:tarball pk=@t ev=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  =('' pk)  (pure:m ~)
  =/  prof=(unit json)  (de:json:html (jstr ev 'content'))
  ?.  ?=([~ %o *] prof)  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& /profiles (cat 3 pk '.json')])
  ;<  cur=(unit json)  bind:m  (peek-as:io road ,json)
  ?:  &(?=(^ cur) =(u.cur u.prof))  (pure:m ~)
  ?^  cur  (over:io road [[/ %json] u.prof])
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] u.prof] ~])
  (pure:m ~)
::  +load-index / +save-index: feed.json as a map id -> created_at
::  the feed index: id -> [time author]. The author is what lets one
::  shared index serve every account: each sees the ids whose author
::  is in its own follows. (An index written before authors were kept
::  has '' there; the feed route resolves those and filters after.)
+$  feed-idx  (map @t [t=@ud a=@t])
++  load-index
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,feed-idx)
  ^-  form:m
  ;<  idx=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'feed.json']) ,json)
  =/  j=json  (fall idx [%o ~])
  =/  ids=(list @t)  (murn (jarr j 'ids') |=(i=json ?:(?=([%s *] i) `p.i ~)))
  =/  times=(list @ud)  (turn (jarr j 'times') |=(t=json ?:(?=([%n *] t) (fall (rush p.t dem) 0) 0)))
  =/  authors=(list @t)  (turn (jarr j 'authors') |=(a=json ?:(?=([%s *] a) p.a '')))
  =|  out=feed-idx
  |-
  ?~  ids  (pure:m out)
  =/  t=@ud  ?~(times 0 i.times)
  =/  a=@t  ?~(authors '' i.authors)
  %=  $
    ids      t.ids
    times    ?~(times ~ t.times)
    authors  ?~(authors ~ t.authors)
    out      (~(put by out) i.ids [t a])
  ==
++  save-index
  |=  [=rail:tarball idx=feed-idx keep=@ud]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  now-unix=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  ents=(list [id=@t t=@ud a=@t])
    %+  scag  keep
    %+  sort  ~(tap by idx)
    |=([a=[@t t=@ud @t] b=[@t t=@ud @t]] (gth t.a t.b))
  (over:io (nex-road:io rail [%& / %'feed.json']) [[/ %json] (feed-index ents now-unix)])
::  +serve: the reader. Static shell + api, all from the namespace:
::    GET /api/status          {events, profiles, at, interval, relays:
::                             [relays/<host>.json ...]}
::    GET /api/feed?limit=n    {posts: [event + profile], count}
::    POST /api/sync           wake the supervisor (re-ensure relays)
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
++  serve
  |=  [=rail:tarball eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/nostr
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  =/  method=@t  method.request.req
  =/  body=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  ?+    suffix  (serve-static eyre-id suffix)
      ::  who am I: the accounts on this ship, which is current, its
      ::  profile, and what it has published (newest first)
      [%api %me ~]
    ;<  cur=(unit @t)  bind:m  (current-pk rail)
    ;<  rows=(list json)  bind:m  (account-rows rail cur)
    ;<  idn=(unit json)  bind:m
      ?~  cur  (pure:(fiber:fiber:nexus ,(unit json)) ~)
      (peek-as:io (nex-road:io rail [%& (acct u.cur) %'identity.json']) ,json)
    ;<  prof=(unit json)  bind:m
      ?~  cur  (pure:(fiber:fiber:nexus ,(unit json)) ~)
      (peek-as:io (nex-road:io rail [%& (acct u.cur) %'profile.json']) ,json)
    ;<  outbox=(list json)  bind:m  (read-outbox rail 200)
    =/  mine=(list json)
      ?~  cur  ~
      (scag 50 (skim outbox |=(o=json =(u.cur (jstr (jget o 'event') 'pubkey')))))
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['current' ?~(cur ~ s+u.cur)]
        ['accounts' [%a rows]]
        ['identity' (fall idn [%o ~])]
        ['profile' (fall prof [%o ~])]
        ['has_key' b+?=(^ cur)]
        ['outbox' [%a mine]]
    ==
  ::
      ::  secret: of one account (?pubkey=), default the current one
      [%api %me %secret ~]
    ;<  cur=(unit @t)  bind:m  (current-pk rail)
    =/  want=@t  (fall (~(get by (malt args)) 'pubkey') '')
    =/  pk=(unit @t)  ?:(=('' want) cur `want)
    ?~  pk  (send-json eyre-id [%o ~])
    ;<  sec=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& (acct u.pk) %'secret.json']) ,json)
    (send-json eyre-id (fall sec [%o ~]))
  ::
      [%api %me %generate ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  pk=(unit @t)  bind:m  (generate-identity rail)
    (send-json eyre-id (pairs:enjs:format ~[['pubkey' ?~(pk ~ s+u.pk)]]))
  ::
      ::  import: an nsec or 64-hex private key becomes an account
      [%api %me %import ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  priv=(unit @ux)  (parse-key:nl 'nsec' (jstr body 'key'))
    ?~  priv  (reply eyre-id 400 'not an nsec or a 64-hex private key')
    ;<  pk=(unit @t)  bind:m  (add-account rail u.priv 0 [%o ~])
    (send-json eyre-id (pairs:enjs:format ~[['pubkey' ?~(pk ~ s+u.pk)]]))
  ::
      [%api %me %use ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  pk=@t  (jstr body 'pubkey')
    ;<  have=?  bind:m  (peek-exists:io (nex-road:io rail [%| (acct pk)]))
    ?.  have  (reply eyre-id 404 'no such account')
    ;<  ~  bind:m  (set-current rail pk)
    (send-json eyre-id (pairs:enjs:format ~[['current' s+pk]]))
  ::
      ::  remove: the account dir is culled (its secret with it); if it
      ::  was current, whichever account is left becomes current
      [%api %me %remove ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  pk=@t  (jstr body 'pubkey')
    ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%| (acct pk)]))
    ;<  cur=(unit @t)  bind:m  (current-pk rail)
    ;<  ~  bind:m
      ?.  =(cur `pk)  (pure:(fiber:fiber:nexus ,~) ~)
      (set-current rail '')
    (send-json eyre-id (pairs:enjs:format ~[['removed' s+pk]]))
  ::
      ::  the profile of one account (body.pubkey, default current):
      ::  written, and published as its kind 0 if it is the current one
      ::  (only the current account signs)
      [%api %me %profile ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  cur=(unit @t)  bind:m  (current-pk rail)
    =/  want=@t  (jstr body 'pubkey')
    =/  pk=(unit @t)  ?:(=('' want) cur `want)
    ?~  pk  (reply eyre-id 409 'no account: generate or import one first')
    ;<  have=?  bind:m  (peek-exists:io (nex-road:io rail [%| (acct u.pk)]))
    ?.  have  (reply eyre-id 404 'no such account')
    =/  prof=json
      %-  pairs:enjs:format
      :~  ['name' s+(jstr body 'name')]
          ['about' s+(jstr body 'about')]
          ['picture' s+(jstr body 'picture')]
      ==
    ;<  ~  bind:m  (over:io (nex-road:io rail [%& (acct u.pk) %'profile.json']) [[/ %json] prof])
    ;<  id=(unit @t)  bind:m
      ?.  =(cur pk)  (pure:(fiber:fiber:nexus ,(unit @t)) ~)
      (publish rail 0 ~ (en:json:html prof))
    (send-json eyre-id (pairs:enjs:format ~[['published' ?~(id ~ s+u.id)] ['current' b+=(cur pk)]]))
  ::
      [%api %publish ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  content=@t  (jstr body 'content')
    ?:  =('' content)  (reply eyre-id 400 'empty')
    ;<  id=(unit @t)  bind:m  (publish rail 1 ~ content)
    ?~  id  (reply eyre-id 409 'no key: generate one first')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+u.id]]))
  ::
      ::  who these people are: the follow list joined with what we
      ::  know of each (their latest kind-0)
      [%api %people ~]
    ;<  pks=(list @t)  bind:m  (read-follows rail)
    ;<  people=(list json)  bind:m  (people rail pks)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['people' [%a people]]
        ['count' (numb:enjs:format (lent pks))]
        ['is_default' b+=((sort pks aor) (sort default-follows aor))]
        ['default_count' (numb:enjs:format (lent default-follows))]
    ==
  ::
      [%api %follows ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  cur=(list @t)  bind:m  (read-follows rail)
    =/  action=@t  (jstr body 'action')
    =/  pk=@t  (jstr body 'pubkey')
    ?:  ?&  !=('reset' action)
            |(?=(~ (parse-hex:nl pk)) !=(64 (met 3 pk)))
        ==
      (reply eyre-id 400 'pubkey must be 64 hex chars')
    =/  next=(list @t)
      ?:  =('reset' action)  default-follows
      ?:  =('remove' action)  (skip cur |=(p=@t =(p pk)))
      ?:((lien cur |=(p=@t =(p pk))) cur (snoc cur pk))
    ;<  ok=?  bind:m  (set-follows rail next)
    ?.  ok  (reply eyre-id 409 'no account: generate or import one first')
    (send-json eyre-id (pairs:enjs:format ~[['count' (numb:enjs:format (lent next))]]))
  ::
      ::  one relay client: reconnect (new session), stop (end the
      ::  client), start (spawn it again), raw (a frame down its socket)
      [%api %relays %cmd ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  host=@t  (relay-host (jstr body 'host'))
    =/  action=@t  (jstr body 'action')
    ?:  =('' host)  (reply eyre-id 400 'host')
    =/  sig=road:tarball  (nex-road:io rail [%& /relays (cat 3 host '.sig')])
    ?:  =('start' action)
      ;<  have=?  bind:m  (peek-exists:io sig)
      ;<  *  bind:m  ?.(have (pure:(fiber:fiber:nexus ,~) ~) (cull-soft:io sig))
      ;<  err=(unit tang)  bind:m  (make-soft:io sig |+[[[/ %sig] ~] ~])
      (send-json eyre-id (pairs:enjs:format ~[['ok' b+?=(~ err)]]))
    ?.  |(=('reconnect' action) =('stop' action) =('raw' action))
      (reply eyre-id 400 'action: reconnect | stop | start | raw')
    ;<  err=(unit tang)  bind:m
      (poke-soft:io sig [/ %json] (pairs:enjs:format ~[['action' s+action] ['text' s+(jstr body 'text')]]))
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+?=(~ err)]]))
  ::
      [%api %relays ~]
    ?:  =('POST' method)
      ;<  cur=(list @t)  bind:m  (read-relays rail)
      =/  action=@t  (jstr body 'action')
      =/  url=@t  (jstr body 'url')
      ?:  &(=('' url) !=('reset' action))  (reply eyre-id 400 'url')
      =/  next=(list @t)
        ?:  =('reset' action)  default-relays
        ?:  =('remove' action)  (skip cur |=(u=@t =((relay-host u) (relay-host url))))
        ?:((lien cur |=(u=@t =((relay-host u) (relay-host url)))) cur (snoc cur url))
      ;<  ~  bind:m  (set-relays rail next)
      (send-json eyre-id (pairs:enjs:format ~[['relays' [%a (turn next |=(u=@t s+u))]]]))
    ;<  cfg=json  bind:m  (read-config rail)
    ;<  statuses=(list json)  bind:m  (relay-statuses rail)
    ;<  configured=(list @t)  bind:m  (read-relays rail)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['configured' [%a (turn configured |=(u=@t s+u))]]
        ['relays' [%a statuses]]
        ['backfill_days' (numb:enjs:format (jnum cfg 'backfill_days' 30))]
        ['is_default' b+=((sort configured aor) (sort default-relays aor))]
        ['defaults' [%a (turn default-relays |=(u=@t s+u))]]
    ==
  ::
      [%api %status ~]
    ;<  ev=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /events]) ~)
    ;<  pv=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /profiles]) ~)
    ;<  idx=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'feed.json']) ,json)
    ;<  cfg=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    ;<  relays=(list json)  bind:m  (relay-statuses rail)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['events' (numb:enjs:format (count-files ev))]
        ['profiles' (numb:enjs:format (count-files pv))]
        ['at' (numb:enjs:format (jnum (fall idx [%o ~]) 'at' 0))]
        ['interval' (numb:enjs:format (jnum (fall cfg [%o ~]) 'interval' 120))]
        ['relays' [%a relays]]
    ==
  ::
      [%api %feed ~]
    =/  limit=@ud
      =/  v=@t  (fall (~(get by (malt args)) 'limit') '')
      =/  n=@ud  (fall (rush v dem) 40)
      ?:(=(0 n) 40 (min n 200))
    ::  the shared index, seen through the current account's follows:
    ::  entries with a known author are filtered here; entries written
    ::  before authors were indexed ('') are resolved and filtered after
    ;<  follows=(list @t)  bind:m  (read-follows rail)
    =/  fs=(set @t)  (silt follows)
    ;<  idx=feed-idx  bind:m  (load-index rail)
    =/  ids=(list @t)
      %+  turn
        %+  scag  limit
        %+  sort
          %+  skim  ~(tap by idx)
          |=([* * a=@t] |(=('' a) (~(has in fs) a)))
        |=([a=[@t t=@ud @t] b=[@t t=@ud @t]] (gth t.a t.b))
      |=([i=@t *] i)
    ;<  posts=(list json)  bind:m  (resolve rail ids)
    =/  mine=(list json)
      %+  skim  posts
      |=  p=json
      =/  rp=json  (jget p 'repost')
      =/  by=@t  ?:(?=([%o *] rp) (jstr rp 'pubkey') (jstr p 'pubkey'))
      (~(has in fs) by)
    %+  send-json  eyre-id
    (pairs:enjs:format ~[['posts' [%a mine]] ['count' (numb:enjs:format (lent mine))] ['follows' (numb:enjs:format (lent follows))]])
  ::
      ::  a thread: the root (found from any post in it), every reply in
      ::  refs/<root> resolved with its parent, newest last
      [%api %thread ~]
    =/  want=@t  (fall (~(get by (malt args)) 'id') '')
    ?:  =('' want)  (reply eyre-id 400 'id')
    ;<  ev=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events (cat 3 want '.json')]) ,json)
    ::  not held (a mention of a post that never reached us): the page
    ::  shows the gap and Fetch asks for it by id, with what points at it
    =/  er=(unit [root=@t parent=@t])  ?~(ev ~ (e-refs u.ev))
    =/  root=@t  ?~(er want root.u.er)
    ;<  refs=json  bind:m  (read-refs rail root)
    =/  reply-ids=(list @t)
      %+  turn
        %+  sort  (jarr refs 'replies')
        |=([a=json b=json] (lth (jnum a 'at' 0) (jnum b 'at' 0)))
      |=(j=json (jstr j 'id'))
    ;<  posts=(list json)  bind:m  (resolve rail [root reply-ids])
    ::  who reacted and reposted, on every post of the thread, named
    ;<  who=(list json)  bind:m  (engagement rail [root reply-ids])
    ::  the root may not have reached us (we hold a reply, not the post
    ::  it answers); the page shows a gap and Fetch asks for it by id
    ;<  held=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events (cat 3 root '.json')]) ,json)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['root' s+root]  ['root_held' b+?=(^ held)]
        ['posts' [%a posts]]  ['engagement' [%a who]]
    ==
  ::
      ::  a person: profile, whether we follow them, the posts we hold
      [%api %person ~]
    =/  pk=@t  (fall (~(get by (malt args)) 'pubkey') '')
    ?~  (parse-hex:nl pk)  (reply eyre-id 400 'pubkey must be 64 hex chars')
    ;<  prof=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /profiles (cat 3 pk '.json')]) ,json)
    ;<  follows=(list @t)  bind:m  (read-follows rail)
    ;<  au=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /authors (cat 3 pk '.json')]) ,json)
    =/  ids=(list @t)
      %+  murn  (scag 40 (jarr (fall au [%o ~]) 'posts'))
      |=(j=json ?:(?=([%o *] j) `(jstr j 'id') ~))
    ;<  posts=(list json)  bind:m  (resolve rail ids)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['pubkey' s+pk]
        ['npub' s+?~(h=(parse-hex:nl pk) '' (npub:nl u.h))]
        ['profile' (fall prof [%o ~])]
        ['known' b+?=(^ prof)]
        ['followed' b+(lien follows |=(p=@t =(p pk)))]
        ['posts' [%a posts]]
    ==
  ::
      ::  fill: every author we hold posts by but no profile for, and
      ::  every thread root we hold replies to but not the post itself,
      ::  asked for on every relay at once. Listing diffs, no per-event
      ::  reads: authors/ minus profiles/, refs/ minus events/.
      [%api %fill ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  au=(list @ta)  bind:m  (dir-names rail /authors ".json")
    ;<  pr=(list @ta)  bind:m  (dir-names rail /profiles ".json")
    ;<  rf=(list @ta)  bind:m  (dir-names rail /refs ".json")
    ;<  ev=(list @ta)  bind:m  (dir-names rail /events ".json")
    =/  strip  |=(n=@ta ^-(@t =/(t (trip n) (crip (scag (sub (lent t) 5) t)))))
    =/  known=(set @t)  (silt (turn pr strip))
    =/  held=(set @t)  (silt (turn ev strip))
    ::  people who only reacted or reposted have no authors/ row (that is
    ::  kind-1 only); their keys are in the refs rows, so read those
    =/  roots=(list @t)  (turn rf strip)
    =|  actors=(set @t)
    ;<  actors=(set @t)  bind:m
      =/  m  (fiber:fiber:nexus ,(set @t))
      |-  ^-  form:m
      ?~  roots  (pure:m actors)
      ;<  refs=json  bind:m  (read-refs rail i.roots)
      =/  pks=(list @t)
        %+  turn  (weld (jarr refs 'reposts') (jarr refs 'reactions'))
        |=(j=json (jstr j 'pubkey'))
      $(roots t.roots, actors (~(gas in actors) pks))
    =/  authors=(list @t)
      %+  scag  200
      %+  skip  (weld (turn au strip) ~(tap in actors))
      |=(p=@t |(=('' p) (~(has in known) p)))
    =/  ids=(list @t)
      (scag 100 (skip roots |=(r=@t (~(has in held) r))))
    ;<  ~  bind:m
      ?:  &(=(~ authors) =(~ ids))  (pure:(fiber:fiber:nexus ,~) ~)
      %+  poke-relays  rail
      (pairs:enjs:format ~[['action' s+'fetch-many'] ['authors' [%a (turn authors |=(a=@t s+a))]] ['ids' [%a (turn ids |=(i=@t s+i))]]])
    %+  send-json  eyre-id
    (pairs:enjs:format ~[['authors' (numb:enjs:format (lent authors))] ['roots' (numb:enjs:format (lent ids))]])
  ::
      ::  a hashtag: the posts we hold under tags/<t>.json, resolved
      [%api %tag ~]
    =/  t=(unit @t)  (clean-tag (fall (~(get by (malt args)) 't') ''))
    ?~  t  (reply eyre-id 400 'tag')
    ;<  doc=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /tags (cat 3 u.t '.json')]) ,json)
    =/  ids=(list @t)  (turn (jarr (fall doc [%o ~]) 'posts') |=(j=json (jstr j 'id')))
    ;<  posts=(list json)  bind:m  (resolve rail (scag 60 ids))
    (send-json eyre-id (pairs:enjs:format ~[['tag' s+u.t] ['posts' [%a posts]] ['count' (numb:enjs:format (lent ids))]]))
  ::
      ::  rebuild the tag index from every held kind-1 (the index began
      ::  after the events did; also after a change to what counts)
      [%api %reindex-tags ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  names=(list @ta)  bind:m  (dir-names rail /events ".json")
    =|  done=@ud
    |-
    ?~  names  (send-json eyre-id (pairs:enjs:format ~[['events' (numb:enjs:format done)]]))
    ;<  ev=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events i.names]) ,json)
    ;<  ~  bind:m
      ?~  ev  (pure:(fiber:fiber:nexus ,~) ~)
      (note-tags rail u.ev)
    $(names t.names, done +(done))
  ::
      [%api %fetch-tag ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  t=(unit @t)  (clean-tag (jstr body 'tag'))
    ?~  t  (reply eyre-id 400 'tag')
    ;<  ~  bind:m  (poke-relays rail (pairs:enjs:format ~[['action' s+'fetch-tag'] ['tag' s+u.t]]))
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::
      ::  one post by id, resolved (a quoted post inside another)
      [%api %post ~]
    =/  want=@t  (fall (~(get by (malt args)) 'id') '')
    ?:  =('' want)  (reply eyre-id 400 'id')
    ;<  posts=(list json)  bind:m  (resolve rail ~[want])
    %+  send-json  eyre-id
    ?~  posts  (pairs:enjs:format ~[['id' s+want] ['held' b+|]])
    (pairs:enjs:format ~[['id' s+want] ['held' b+&] ['post' i.posts]])
  ::
      [%api %fetch-person ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  pk=@t  (jstr body 'pubkey')
    ?~  (parse-hex:nl pk)  (reply eyre-id 400 'pubkey')
    ;<  ~  bind:m  (poke-relays rail (pairs:enjs:format ~[['action' s+'fetch-author'] ['pubkey' s+pk]]))
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::
      ::  fetch: ask every relay for what points at this event (replies,
      ::  reposts, reactions, quotes) — a one-shot subscription per socket
      [%api %fetch ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  target=@t  (jstr body 'id')
    ?:  =('' target)  (reply eyre-id 400 'id')
    ;<  ~  bind:m  (poke-relays rail (pairs:enjs:format ~[['action' s+'fetch'] ['id' s+target]]))
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+&]]))
  ::
      ::  reply: kind 1 with NIP-10 e tags (root, reply) and p tags for
      ::  the people in the conversation
      [%api %reply ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  parent-id=@t  (jstr body 'parent')
    =/  content=@t  (jstr body 'content')
    ?:  |(=('' parent-id) =('' content))  (reply eyre-id 400 'parent and content')
    ;<  parent=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events (cat 3 parent-id '.json')]) ,json)
    ?~  parent  (reply eyre-id 404 'no such event')
    =/  er=(unit [root=@t parent=@t])  (e-refs u.parent)
    =/  root=@t  ?~(er parent-id root.u.er)
    =/  people=(list @t)
      =/  ps=(list @t)  (murn (tags u.parent) |=(t=(list @t) ?.(?=([%p @ *] t) ~ `i.t.t)))
      =/  author=@t  (jstr u.parent 'pubkey')
      ?:((lien ps |=(p=@t =(p author))) ps [author ps])
    =/  etags=(list (list @t))
      ?:  =(root parent-id)  ~[`(list @t)`~['e' root '' 'root']]
      ~[`(list @t)`~['e' root '' 'root'] `(list @t)`~['e' parent-id '' 'reply']]
    =/  tgs=(list (list @t))  (weld etags (turn people |=(p=@t `(list @t)`~['p' p])))
    ;<  id=(unit @t)  bind:m  (publish rail 1 tgs content)
    ?~  id  (reply eyre-id 409 'no key: generate one first')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+u.id]]))
  ::
      ::  react: kind 7, content '+' or an emoji, e + p tags for the target
      [%api %react ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  target=@t  (jstr body 'id')
    =/  content=@t  (jstr body 'content')
    ?:  =('' target)  (reply eyre-id 400 'id')
    ;<  ev=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events (cat 3 target '.json')]) ,json)
    ?~  ev  (reply eyre-id 404 'no such event')
    =/  tgs=(list (list @t))  ~[`(list @t)`~['e' target] `(list @t)`~['p' (jstr u.ev 'pubkey')]]
    ;<  id=(unit @t)  bind:m  (publish rail 7 tgs ?:(=('' content) '+' content))
    ?~  id  (reply eyre-id 409 'no key: generate one first')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+u.id]]))
  ::
      ::  repost: a kind 6 whose content is the original event verbatim
      ::  (NIP-18), tagged with the original's id and author
      [%api %repost ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  target=@t  (jstr body 'id')
    ?:  =('' target)  (reply eyre-id 400 'id')
    ;<  ev=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events (cat 3 target '.json')]) ,json)
    ?~  ev  (reply eyre-id 404 'no such event')
    =/  tgs=(list (list @t))  ~[`(list @t)`~['e' target] `(list @t)`~['p' (jstr u.ev 'pubkey')]]
    ;<  id=(unit @t)  bind:m  (publish rail 6 tgs (en:json:html u.ev))
    ?~  id  (reply eyre-id 409 'no key: generate one first')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+u.id]]))
  ::
      ::  unreact: a NIP-09 deletion request (kind 5) for one of our
      ::  reactions, and the reaction leaves refs/ here. Relays may
      ::  honor it or not; the event grub stays (the record)
      [%api %unreact ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  rid=@t  (jstr body 'id')
    ?:  =('' rid)  (reply eyre-id 400 'id')
    ;<  cur=(unit @t)  bind:m  (current-pk rail)
    ?~  cur  (reply eyre-id 409 'no account')
    ;<  ev=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /events (cat 3 rid '.json')]) ,json)
    ?~  ev  (reply eyre-id 404 'no such event')
    ?.  =(u.cur (jstr u.ev 'pubkey'))  (reply eyre-id 403 'not ours')
    ?.  =(7 (jnum u.ev 'kind' 1))  (reply eyre-id 400 'not a reaction')
    =/  tgs=(list (list @t))  ~[`(list @t)`~['e' rid] `(list @t)`~['k' '7']]
    ;<  id=(unit @t)  bind:m  (publish rail 5 tgs '')
    ?~  id  (reply eyre-id 409 'no key')
    ::  out of the target's refs row, and the reaction's grub goes
    ;<  ~  bind:m  (unnote-refs rail u.ev)
    ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /events (cat 3 rid '.json')]))
    (send-json eyre-id (pairs:enjs:format ~[['deleted' s+rid] ['request' s+u.id]]))
  ::
      [%api %sync ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'main.sig']) [/ %json] (pairs:enjs:format ~[['action' s+'ensure']]))
    (reply eyre-id 200 'ok')
  ==
::  +slim-prof: name, picture, about of one pubkey ({} when unknown)
++  slim-prof
  |=  [=rail:tarball pk=@t]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  p=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /profiles (cat 3 pk '.json')]) ,json)
  =/  prof=json  (fall p [%o ~])
  %-  pure:m
  (pairs:enjs:format ~[['name' s+(jstr prof 'name')] ['picture' s+(jstr prof 'picture')] ['about' s+(jstr prof 'about')]])
::  +resolve: ids -> events joined with their author's profile
++  resolve
  |=  [=rail:tarball ids=(list @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  cur=(unit @t)  bind:m  (current-pk rail)
  =|  out=(list json)
  =|  profs=(map @t json)
  |-
  ?~  ids  (pure:m (flop out))
  ;<  ev=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /events (cat 3 i.ids '.json')]) ,json)
  ?~  ev  $(ids t.ids)
  ?.  ?=([%o *] u.ev)  $(ids t.ids)
  ::  a repost (kind 6) shows as the ORIGINAL post, with who reposted it
  ::  and when; the original is held (store-embedded) or we skip it
  ;<  repost=json  bind:m
    ?.  =(6 (jnum u.ev 'kind' 1))  (pure:(fiber:fiber:nexus ,json) ~)
    ;<  rp=json  bind:(fiber:fiber:nexus ,json)  (slim-prof rail (jstr u.ev 'pubkey'))
    %-  pure:(fiber:fiber:nexus ,json)
    %-  pairs:enjs:format
    :~  ['id' s+(jstr u.ev 'id')]  ['pubkey' s+(jstr u.ev 'pubkey')]
        ['name' s+(jstr rp 'name')]  ['picture' s+(jstr rp 'picture')]
        ['at' (numb:enjs:format (jnum u.ev 'created_at' 0))]
    ==
  ;<  ev=(unit json)  bind:m
    ?~  repost  (pure:(fiber:fiber:nexus ,(unit json)) ev)
    =/  target=@t  (first-tag u.ev 'e')
    ?:  =('' target)  (pure:(fiber:fiber:nexus ,(unit json)) ~)
    (peek-as:io (nex-road:io rail [%& /events (cat 3 target '.json')]) ,json)
  ?~  ev  $(ids t.ids)
  ?.  ?=([%o *] u.ev)  $(ids t.ids)
  =/  oid=@t  (jstr u.ev 'id')
  =/  pk=@t  (jstr u.ev 'pubkey')
  ;<  prof=json  bind:m
    ?^  hit=(~(get by profs) pk)  (pure:(fiber:fiber:nexus ,json) u.hit)
    ;<  p=(unit json)  bind:(fiber:fiber:nexus ,json)
      (peek-as:io (nex-road:io rail [%& /profiles (cat 3 pk '.json')]) ,json)
    (pure:(fiber:fiber:nexus ,json) (fall p [%o ~]))
  =/  slim=json
    (pairs:enjs:format ~[['name' s+(jstr prof 'name')] ['picture' s+(jstr prof 'picture')] ['about' s+(jstr prof 'about')]])
  ::  what this post answers, and what points at it
  =/  er=(unit [root=@t parent=@t])  (e-refs u.ev)
  =/  root=@t  ?~(er oid root.u.er)
  ;<  own=json  bind:m  (read-refs rail oid)
  ;<  thread=json  bind:m
    ?:  =(root oid)  (pure:(fiber:fiber:nexus ,json) own)
    (read-refs rail root)
  =/  replies=@ud
    (lent (skim (jarr thread 'replies') |=(j=json =((jstr j 'parent') oid))))
  =/  reactions=(list json)  (jarr own 'reactions')
  =/  by-emoji=(map @t @ud)
    %+  roll  reactions
    |=  [r=json acc=(map @t @ud)]
    =/  c=@t  (jstr r 'content')
    =/  c=@t  ?:(|(=('' c) =('+' c)) '+' c)
    (~(put by acc) c +((~(gut by acc) c 0)))
  ::  the current account's own reactions, emoji -> reaction id (for
  ::  the highlighted chip and for unreacting)
  =/  mine=(list [@t json])
    ?~  cur  ~
    %+  murn  reactions
    |=  r=json
    ?.  =(u.cur (jstr r 'pubkey'))  ~
    =/  c=@t  (jstr r 'content')
    `[?:(|(=('' c) =('+' c)) '+' c) s+(jstr r 'id')]
  =/  post=json
    %-  pairs:enjs:format
    %+  weld  `(list [@t json])`~(tap by p.u.ev)
    ^-  (list [@t json])
    :~  ['profile' slim]
        ['repost' repost]
        ['reply_to' ?~(er ~ (pairs:enjs:format ~[['root' s+root.u.er] ['parent' s+parent.u.er]]))]
        :-  'counts'
        %-  pairs:enjs:format
        :~  ['replies' (numb:enjs:format replies)]
            ['reposts' (numb:enjs:format (lent (jarr own 'reposts')))]
            ['reactions' (numb:enjs:format (lent reactions))]
        ==
        ['reactions' [%o (~(run by by-emoji) numb:enjs:format)]]
        ['my_reactions' (pairs:enjs:format mine)]
    ==
  $(ids t.ids, out [post out], profs (~(put by profs) pk prof))
::
++  serve-static
  |=  [eyre-id=@ta suffix=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
  ;<  v=view:nexus  bind:m  (peek:io [%| 1 %& ~ filename] `[/ %mime])
  ?.  ?=([%file *] v)  (reply eyre-id 404 'Not found')
  =/  =mime  !<(mime (need-vase:tarball sang.v))
  (send-simple:srv eyre-id (mime-response:http-utils mime))
++  reply
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html msg)])
++  send-json
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
::  +people: each followed pubkey with its profile grub, if we have one
++  people
  |=  [=rail:tarball pks=(list @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =|  out=(list json)
  |-
  ?~  pks  (pure:m (flop out))
  ;<  prof=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /profiles (cat 3 i.pks '.json')]) ,json)
  =/  p=json  (fall prof [%o ~])
  =/  row=json
    %-  pairs:enjs:format
    :~  ['pubkey' s+i.pks]
        ['npub' s+?~(h=(parse-hex:nl i.pks) '' (npub:nl u.h))]
        ['name' s+(jstr p 'name')]
        ['display_name' s+(jstr p 'display_name')]
        ['about' s+(jstr p 'about')]
        ['picture' s+(jstr p 'picture')]
        ['nip05' s+(jstr p 'nip05')]
        ['known' b+?=(^ prof)]
    ==
  $(pks t.pks, out [row out])
::  +read-outbox: the events we published, newest first
++  read-outbox
  |=  [=rail:tarball limit=@ud]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /outbox]) ~)
  =/  names=(list @ta)
    ?.  ?=([%ball *] v)  ~
    ?~  fil.ball.v  ~
    (turn ~(tap by contents.u.fil.ball.v) |=([name=@ta *] name))
  =|  out=(list json)
  |-
  ?~  names
    %-  pure:m
    %+  scag  limit
    %+  sort  out
    |=([a=json b=json] (gth (jnum a 'at' 0) (jnum b 'at' 0)))
  ;<  j=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /outbox i.names]) ,json)
  $(names t.names, out ?~(j out [u.j out]))
::  +relay-statuses: every relays/<host>.json, as written by the clients
++  relay-statuses
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /relays]) ~)
  =/  names=(list @ta)
    ?.  ?=([%ball *] v)  ~
    ?~  fil.ball.v  ~
    %+  murn  ~(tap by contents.u.fil.ball.v)
    |=  [name=@ta *]
    =/  n=tape  (trip name)
    ?.  &((gth (lent n) 5) =(".json" (slag (sub (lent n) 5) n)))  ~
    `name
  =|  out=(list json)
  |-
  ?~  names  (pure:m (flop out))
  ;<  j=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /relays i.names]) ,json)
  $(names t.names, out ?~(j out [u.j out]))
++  count-files
  |=  =view:nexus
  ^-  @ud
  ?.  ?=([%ball *] view)  0
  ?~  fil.ball.view  0
  ~(wyt by contents.u.fil.ball.view)
::
::  +jstrs: a key's array of strings
++  jstrs
  |=  [j=json k=@t]
  ^-  (list @t)
  (murn (jarr j k) |=(x=json ?:(?=([%s *] x) `p.x ~)))
++  jstr
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=([%o *] j)  ''
  =/  v  (~(get by p.j) k)
  ?:(?=([~ %s *] v) p.u.v '')
++  jget
  |=  [j=json k=@t]
  ^-  json
  ?.  ?=([%o *] j)  [%o ~]
  (fall (~(get by p.j) k) [%o ~])
++  jarr
  |=  [j=json k=@t]
  ^-  (list json)
  ?.  ?=([%o *] j)  ~
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %a *] v) ~ p.u.v)
++  jvals
  |=  j=json
  ^-  (list json)
  ?.(?=([%o *] j) ~ (turn ~(tap by p.j) |=([* v=json] v)))
++  jstr-at
  |=  [l=(list json) i=@ud]
  ^-  @t
  =/  v  (snag-soft l i)
  ?:(?=([~ %s *] v) p.u.v '')
++  jbool-at
  |=  [l=(list json) i=@ud]
  ^-  ?
  =/  v  (snag-soft l i)
  ?:(?=([~ %b *] v) p.u.v |)
++  snag-soft
  |=  [l=(list json) i=@ud]
  ^-  (unit json)
  ?:  (gte i (lent l))  ~
  `(snag i l)
++  jnum
  |=  [j=json k=@t def=@ud]
  ^-  @ud
  ?.  ?=([%o *] j)  def
  =/  v  (~(get by p.j) k)
  ?~  v  def
  ?:  ?=([%n *] u.v)  (fall (rush p.u.v dem) def)
  ?:  ?=([%s *] u.v)  (fall (rush p.u.v dem) def)
  def
--
