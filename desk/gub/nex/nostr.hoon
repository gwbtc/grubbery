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
::  the explorer — reads the namespace. No gall agent is involved.
::
::    me/identity.json        {pubkey, npub, since}: the public half of
::                            our key — our name on the network. Empty
::                            until a key is generated.
::    me/secret.json          {privkey, nsec}: the private half. Signs
::                            everything we publish; never leaves the
::                            ship. Absent until generated.
::    me/profile.json         {name, about, picture}: what we publish
::                            as our kind-0 (profile) event.
::    outbox/<id>.json        {event, relays: {host: {ok, message, at}},
::                            at}: an event we signed and sent, with
::                            each relay's verdict on it.
::    events/<id>.json        one nostr event, verbatim (id, pubkey, kind,
::                            created_at, tags, content, sig). Immutable:
::                            written once, never touched.
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
::    follows.json            {pubkeys: [hex]} — whose posts we want. The
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
::  TODO publishing: signing needs our nostr private key as a grub with a
::  weir only the publisher may read (nostrill: lib/nostr/keys.hoon,
::  schnorr over the event hash). TODO verify inbound signatures; today,
::  like nostrill, we trust the relay.
::    web.sig                 the page: static files + a JSON api over
::                            the grubs above (see +serve).
::
/&  icon     nostr/icon.svg
/<  ui-html  nostr/index.html
/<  ui-js    nostr/app.js
/<  ui-css   nostr/style.css
/<  defaults-mime  nostr/defaults.json
/&  tg-js    /lib/ui/tab-group.js
/&  md-js    /lib/ui/modal-dialog.js
/<  nl       /lib/nostr.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Nostr'
            info+s+'Your nostr feed, in the namespace'
            color+s+'#f1ecfb'
            image+s+'/grubbery/tiles/icon/nostr'
            href+s+'/grubbery/nostr'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'nostr'] ['description' s+'nostr events and profiles, mirrored']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%over %& [/ %'tab-group.js'] [[/ %mime] tg-js]]
          [%over %& [/ %'modal-dialog.js'] [[/ %mime] md-js]]
          [%over %& [/ %'defaults.json'] [[/ %json] defaults]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /me empty-dir:loader]
          [%fall %& [/me %'identity.json'] [[/ %json] (pairs:enjs:format ~[['pubkey' s+''] ['npub' s+'']])]]
          [%fall %& [/me %'profile.json'] [[/ %json] [%o ~]]]
          [%fall %| /outbox empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/ %'feed.json'] [[/ %json] (feed-index ~ 0)]]
          [%fall %& [/ %'follows.json'] [[/ %json] (pairs:enjs:format ~[['pubkeys' [%a (jarr defaults 'follows')]]])]]
          [%fall %| /events empty-dir:loader]
          [%fall %| /profiles empty-dir:loader]
          [%fall %| /relays empty-dir:loader]
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
          (line '/sys/iris/ws.ws-state' 'websockets to nostr relays (the client that will replace the poller)')
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
  |=  [ents=(list [id=@t t=@ud]) at=@ud]
  ^-  json
  %-  pairs:enjs:format
  :~  ['ids' [%a (turn ents |=([i=@t *] s+i))]]
      ['times' [%a (turn ents |=([* t=@ud] (numb:enjs:format t)))]]
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
++  read-follows
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  f=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'follows.json']) ,json)
  %-  pure:m
  (murn (jarr (fall f [%o ~]) 'pubkeys') |=(p=json ?:(?=([%s *] p) `p.p ~)))
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
  ;<  follows=(list @t)  bind:m  (read-follows rail)
  ?~  follows
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
  ;<  idx=(map @t @ud)  bind:m  (load-index rail)
  ;<  now=@da  bind:m  get-time:io
  =/  now-unix=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  newest=@ud  (roll ~(val by idx) max)
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
        (filter ~[1] follows `since)
        (filter ~[0] follows prof-since)
    ==
  ;<  ~  bind:m  (ws-send:io u.wid req)
  =.  st  (note-frame st '> ' req)
  =.  st  st(since since, req (crip "kinds 1 since {<since>} + kinds 0 since {<(fall prof-since 0)>}, {<(lent follows)>} authors"))
  ;<  ~  bind:m  (report st)
  =/  keep=@ud  (jnum cfg 'keep' 500)
  =|  eose=?
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
  ?.  =(1 kind)  $
  =/  id=@t  (jstr ev 'id')
  ?:  =('' id)  $
  =.  idx  (~(put by idx) id (jnum ev 'created_at' 0))
  =/  road=road:tarball  (nex-road:io rail [%& /events (cat 3 id '.json')])
  ;<  have=?  bind:m  (peek-exists:io road)
  =.  st  st(events +(events.st), new ?:(have new.st +(new.st)))
  ;<  ~  bind:m
    ?:  have  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  err=(unit tang)  bind:(fiber:fiber:nexus ,~)  (make-soft:io road |+[[[/ %json] ev] ~])
    (pure:(fiber:fiber:nexus ,~) ~)
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
::  +me-keys: our keypair from me/secret.json + me/identity.json, or ~
++  me-keys
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(unit keys:nl))
  ^-  form:m
  ;<  sec=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'secret.json']) ,json)
  ?~  sec  (pure:m ~)
  =/  priv=(unit @ux)  (parse-hex:nl (jstr u.sec 'privkey'))
  ?~  priv  (pure:m ~)
  (pure:m `[x:(priv-to-pub:secp256k1:secp:crypto u.priv) u.priv])
::  +generate-identity: a fresh keypair, unless one exists
++  generate-identity
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  secret=road:tarball  (nex-road:io rail [%& /me %'secret.json'])
  ;<  have=?  bind:m  (peek-exists:io secret)
  ?:  have  (pure:m |)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  ;<  now=@da  bind:m  get-time:io
  =/  k=keys:nl  (gen-keys:nl eny)
  =/  sec=json
    (pairs:enjs:format ~[['privkey' s+(to-hex:nl 64 priv.k)] ['nsec' s+(nsec:nl priv.k)]])
  =/  idn=json
    %-  pairs:enjs:format
    :~  ['pubkey' s+(to-hex:nl 64 pub.k)]
        ['npub' s+(npub:nl pub.k)]
        ['since' (numb:enjs:format (div (sub now ~1970.1.1) ~s1))]
    ==
  ;<  err=(unit tang)  bind:m  (make-soft:io secret |+[[[/ %json] sec] ~])
  ?^  err  (pure:m |)
  ;<  ~  bind:m  (over:io (nex-road:io rail [%& /me %'identity.json']) [[/ %json] idn])
  (pure:m &)
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
::  +relay-names: the grubs under relays/ with a given extension
++  relay-names
  |=  [=rail:tarball ext=tape]
  =/  m  (fiber:fiber:nexus ,(list @ta))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /relays]) ~)
  %-  pure:m
  ?.  ?=([%ball *] v)  ~
  ?~  fil.ball.v  ~
  %+  murn  ~(tap by contents.u.fil.ball.v)
  |=  [name=@ta *]
  =/  n=tape  (trip name)
  =/  l=@ud  (lent ext)
  ?.  &((gth (lent n) l) =(ext (slag (sub (lent n) l) n)))  ~
  `name
::  +set-follows: follows.json, then every client reconnects with it
++  set-follows
  |=  [=rail:tarball pks=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  doc=json  (pairs:enjs:format ~[['pubkeys' [%a (turn pks |=(p=@t s+p))]]])
  ;<  ~  bind:m  (over:io (nex-road:io rail [%& / %'follows.json']) [[/ %json] doc])
  (poke-relays rail (pairs:enjs:format ~[['action' s+'reconnect']]))
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
++  load-index
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t @ud))
  ^-  form:m
  ;<  idx=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'feed.json']) ,json)
  =/  j=json  (fall idx [%o ~])
  =/  ids=(list @t)  (murn (jarr j 'ids') |=(i=json ?:(?=([%s *] i) `p.i ~)))
  =/  times=(list @ud)  (turn (jarr j 'times') |=(t=json ?:(?=([%n *] t) (fall (rush p.t dem) 0) 0)))
  =|  out=(map @t @ud)
  |-
  ?~  ids  (pure:m out)
  =/  t=@ud  ?~(times 0 i.times)
  $(ids t.ids, times ?~(times ~ t.times), out (~(put by out) i.ids t))
++  save-index
  |=  [=rail:tarball idx=(map @t @ud) keep=@ud]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  now-unix=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  ents=(list [id=@t t=@ud])
    %+  scag  keep
    %+  sort  ~(tap by idx)
    |=([a=[@t t=@ud] b=[@t t=@ud]] (gth t.a t.b))
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
      ::  who am I: the public identity, the profile we publish, whether
      ::  a key exists, and what we have published (newest first)
      [%api %me ~]
    ;<  idn=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'identity.json']) ,json)
    ;<  prof=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'profile.json']) ,json)
    ;<  has=?  bind:m  (peek-exists:io (nex-road:io rail [%& /me %'secret.json']))
    ;<  outbox=(list json)  bind:m  (read-outbox rail 50)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['identity' (fall idn [%o ~])]
        ['profile' (fall prof [%o ~])]
        ['has_key' b+has]
        ['outbox' [%a outbox]]
    ==
  ::
      [%api %me %secret ~]
    ;<  sec=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& /me %'secret.json']) ,json)
    (send-json eyre-id (fall sec [%o ~]))
  ::
      [%api %me %generate ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  made=?  bind:m  (generate-identity rail)
    (send-json eyre-id (pairs:enjs:format ~[['generated' b+made]]))
  ::
      ::  the profile we publish: write it, then publish it as kind 0
      [%api %me %profile ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    =/  prof=json
      %-  pairs:enjs:format
      :~  ['name' s+(jstr body 'name')]
          ['about' s+(jstr body 'about')]
          ['picture' s+(jstr body 'picture')]
      ==
    ;<  ~  bind:m  (over:io (nex-road:io rail [%& /me %'profile.json']) [[/ %json] prof])
    ;<  id=(unit @t)  bind:m  (publish rail 0 ~ (en:json:html prof))
    (send-json eyre-id (pairs:enjs:format ~[['published' ?~(id ~ s+u.id)]]))
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
    ;<  ~  bind:m  (set-follows rail next)
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
    ;<  idx=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'feed.json']) ,json)
    =/  ids=(list @t)
      ?~  idx  ~
      ?.  ?=([%o *] u.idx)  ~
      =/  a  (~(get by p.u.idx) 'ids')
      ?.  ?=([~ %a *] a)  ~
      (murn (scag limit p.u.a) |=(j=json ?:(?=([%s *] j) `p.j ~)))
    ;<  posts=(list json)  bind:m  (resolve rail ids)
    %+  send-json  eyre-id
    (pairs:enjs:format ~[['posts' [%a posts]] ['count' (numb:enjs:format (lent posts))]])
  ::
      [%api %sync ~]
    ?.  =('POST' method)  (reply eyre-id 405 'POST')
    ;<  ~  bind:m
      (poke:io (nex-road:io rail [%& / %'main.sig']) [/ %json] (pairs:enjs:format ~[['action' s+'ensure']]))
    (reply eyre-id 200 'ok')
  ==
::  +resolve: ids -> events joined with their author's profile
++  resolve
  |=  [=rail:tarball ids=(list @t)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =|  out=(list json)
  =|  profs=(map @t json)
  |-
  ?~  ids  (pure:m (flop out))
  ;<  ev=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /events (cat 3 i.ids '.json')]) ,json)
  ?~  ev  $(ids t.ids)
  ?.  ?=([%o *] u.ev)  $(ids t.ids)
  =/  pk=@t  (jstr u.ev 'pubkey')
  ;<  prof=json  bind:m
    ?^  hit=(~(get by profs) pk)  (pure:(fiber:fiber:nexus ,json) u.hit)
    ;<  p=(unit json)  bind:(fiber:fiber:nexus ,json)
      (peek-as:io (nex-road:io rail [%& /profiles (cat 3 pk '.json')]) ,json)
    (pure:(fiber:fiber:nexus ,json) (fall p [%o ~]))
  =/  slim=json
    (pairs:enjs:format ~[['name' s+(jstr prof 'name')] ['picture' s+(jstr prof 'picture')] ['about' s+(jstr prof 'about')]])
  =/  post=json  [%o (~(put by p.u.ev) 'profile' slim)]
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
