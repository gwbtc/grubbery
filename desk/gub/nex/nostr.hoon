::  nostr nexus: nostr, mirrored into the namespace.
::
::  Today the events come from nostrill (a gall agent) through the
::  /sys/scry service; tomorrow a relay client writes the same grubs.
::  Everything downstream reads the namespace either way — that is the
::  point. The mirror is the migration path.
::
::    events/<id>.json        one nostr event, verbatim (id, pubkey, kind,
::                            created_at, tags, content, sig). Immutable:
::                            written once, never touched.
::    profiles/<pubkey>.json  the author's kind-0 metadata as nostrill
::                            returns it; overwritten when it changes.
::    feed.json               {ids: [newest..oldest], at, count} — the
::                            recent timeline as an index, so a consumer
::                            gets the timeline in one peek instead of a
::                            directory listing. Rebuilt each poll.
::    config.json             {interval: seconds, keep: how many ids the
::                            feed index holds}
::    main.sig                the poller. Poke {action:'sync'} to run one
::                            pass now.
::
/&  icon     nostr/icon.svg
/<  ui-html  nostr/index.html
/<  ui-js    nostr/app.js
/<  ui-css   nostr/style.css
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
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/ %'feed.json'] [[/ %json] (feed-index ~ 0)]]
          [%fall %| /events empty-dir:loader]
          [%fall %| /profiles empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: sync on a timer forever; a {action:'sync'} poke
          ::  runs a pass immediately (the sleep is interruptible)
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%nostr/main: failed")
        |-
        ;<  ~  bind:m  (sync rail)
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
          (line '/sys/behn/' 'the poll timer')
          (line '/sys/scry/main.sig' 'read nostrill (the gall agent holding the feed) — until a relay client replaces it')
          (line '/sys/eyre/' 'serve the feed page over HTTP')
      ==
  ==
::
++  default-config
  ^-  json
  (pairs:enjs:format ~[['interval' (numb:enjs:format 120)] ['keep' (numb:enjs:format 500)]])
::
++  feed-index
  |=  [ids=(list @t) at=@ud]
  ^-  json
  %-  pairs:enjs:format
  :~  ['ids' [%a (turn ids |=(i=@t s+i))]]
      ['count' (numb:enjs:format (lent ids))]
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
::  {action:'sync'} poke from a caller lands the same way. Either ends
::  the wait; the caller re-syncs regardless of which.
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
::  +sync: one pass. Read nostrill's feeds, write every event we do not
::  have, refresh profiles for the authors on this page, rebuild the
::  feed index. Idempotent: a re-run writes nothing new.
++  sync
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  feed=json  bind:m  (typed-scry:io json %json /gx/nostrill/j/nostr/json)
  ?.  ?=([%o *] feed)
    ~&  >>>  %nostr-sync-no-feed
    (pure:m ~)
  ::  every event in every relay feed of every source, deduped by id,
  ::  newest first
  =/  dedup=[seen=(set @t) out=(list json)]
    %+  roll  (all-events feed)
    |=  [ev=json acc=[seen=(set @t) out=(list json)]]
    =/  id=@t  (jstr ev 'id')
    ?:  |(=('' id) (~(has in seen.acc) id))  acc
    [(~(put in seen.acc) id) [ev out.acc]]
  =/  events=(list json)  (flop out.dedup)
  =/  sorted=(list json)
    %+  sort  events
    |=([a=json b=json] (gth (jnum a 'created_at' 0) (jnum b 'created_at' 0)))
  ;<  cfg=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
  =/  keep=@ud  (jnum (fall cfg [%o ~]) 'keep' 500)
  ::  write the events we lack
  ;<  wrote=@ud  bind:m
    =/  m  (fiber:fiber:nexus ,@ud)
    =/  todo=(list json)  sorted
    =|  n=@ud
    |-  ^-  form:m
    ?~  todo  (pure:m n)
    =/  id=@t  (jstr i.todo 'id')
    =/  road=road:tarball  (nex-road:io rail [%& /events (cat 3 id '.json')])
    ;<  have=?  bind:m  (peek-exists:io road)
    ?:  have  $(todo t.todo)
    ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] i.todo] ~])
    $(todo t.todo, n ?~(err +(n) n))
  ::  profiles for the authors on this page (nostrill's per-user scry)
  =/  authors=[seen=(set @t) out=(list @t)]
    %+  roll  (scag keep sorted)
    |=  [ev=json acc=[seen=(set @t) out=(list @t)]]
    =/  pk=@t  (jstr ev 'pubkey')
    ?:  |(=('' pk) (~(has in seen.acc) pk))  acc
    [(~(put in seen.acc) pk) [pk out.acc]]
  =/  pks=(list @t)  (flop out.authors)
  ;<  ~  bind:m  (sync-profiles rail (scag 60 pks))
  ::  the index
  ;<  now=@da  bind:m  get-time:io
  =/  now-unix=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  ids=(list @t)  (turn (scag keep sorted) |=(ev=json (jstr ev 'id')))
  ;<  ~  bind:m
    (over:io (nex-road:io rail [%& / %'feed.json']) [[/ %json] (feed-index ids now-unix)])
  ~?  >  (gth wrote 0)  [%nostr-sync wrote=wrote total=(lent sorted)]
  (pure:m ~)
::  +all-events: flatten {source: {relay: {sub, feed: [event]}}}
++  all-events
  |=  feed=json
  ^-  (list json)
  ?.  ?=([%o *] feed)  ~
  %-  zing
  %+  turn  ~(tap by p.feed)
  |=  [* srcs=json]
  ^-  (list json)
  ?.  ?=([%o *] srcs)  ~
  %-  zing
  %+  turn  ~(tap by p.srcs)
  |=  [* relay=json]
  ^-  (list json)
  ?.  ?=([%o *] relay)  ~
  =/  f  (~(get by p.relay) 'feed')
  ?.(?=([~ %a *] f) ~ p.u.f)
::  +sync-profiles: one scry per pubkey; write when new or changed
++  sync-profiles
  |=  [=rail:tarball pks=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ?~  pks  (pure:m ~)
  ;<  prof=json  bind:m
    (typed-scry:io json %json /gx/nostrill/j/profile/nostr/[i.pks]/json)
  ?.  ?=([%o *] prof)  $(pks t.pks)
  =/  road=road:tarball  (nex-road:io rail [%& /profiles (cat 3 i.pks '.json')])
  ;<  cur=(unit json)  bind:m  (peek-as:io road ,json)
  ?:  &(?=(^ cur) =(u.cur prof))  $(pks t.pks)
  ;<  ~  bind:m
    ?^  cur  (over:io road [[/ %json] prof])
    ;<  err=(unit tang)  bind:(fiber:fiber:nexus ,~)  (make-soft:io road |+[[[/ %json] prof] ~])
    (pure:(fiber:fiber:nexus ,~) ~)
  $(pks t.pks)
::  +serve: the reader. Static shell + api, all from the namespace:
::    GET /api/status          {events, profiles, at, interval}
::    GET /api/feed?limit=n    {posts: [event + profile], count}
::    POST /api/sync           run a sync pass now
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
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %status ~]
    ;<  ev=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /events]) ~)
    ;<  pv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /profiles]) ~)
    ;<  idx=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'feed.json']) ,json)
    ;<  cfg=(unit json)  bind:m  (peek-as:io (nex-road:io rail [%& / %'config.json']) ,json)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['events' (numb:enjs:format (count-files ev))]
        ['profiles' (numb:enjs:format (count-files pv))]
        ['at' (numb:enjs:format (jnum (fall idx [%o ~]) 'at' 0))]
        ['interval' (numb:enjs:format (jnum (fall cfg [%o ~]) 'interval' 120))]
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
      (poke:io (nex-road:io rail [%& / %'main.sig']) [/ %json] (pairs:enjs:format ~[['action' s+'sync']]))
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
