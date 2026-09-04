::  calendar: events over the rules library
::
::  /calendar.calendar   portable intent: config + events (poke CRUD)
::  /order.calendar-cache     derived index, reinflated on calendar news
::  /main.sig            binds /grubbery/calendar
::  /requests            window.json + events.json endpoints
::
/<  cal    /lib/calendar.hoon
/<  rules  /lib/rules.hoon
/<  pytz   /lib/pytz.hoon
/<  ics    /lib/ics.hoon
/<  sh     /lib/shell.hoon
/&  icon      calendar/icon.svg
/&  cal-html  calendar/calendar.html
/&  cal-css   calendar/calendar.css
/&  cal-js    calendar/calendar.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Calendar'
            info+s+'Events and schedules'
            color+s+'#1e3a5f'
            image+s+'/grubbery/tiles/icon/calendar'
            href+s+'/grubbery/calendar'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'calendar'] ['description' s+'Calendar events']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'calendar.calendar'] [[/ %calendar] fresh-calendar:cal]]
          [%fall %& [/ %'order.calendar-cache'] [[/ %calendar-cache] *cache:cal]]
          [%fall %& [/ %'gcal-feeds.json'] [[/ %json] [%o ~]]]
          :*  %fall  %&  [/ %'reminders.json']
              :-  [/ %json]
              ^-  json
              :-  %o
              %-  ~(gas by *(map @t json))
              ~[['lead_min' n+'30'] ['fired_ms' n+'0']]
          ==
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'calendar.html'] [[/ %mime] cal-html]]
          [%over %& [/ %'calendar.css'] [[/ %mime] cal-css]]
          [%over %& [/ %'calendar.js'] [[/ %mime] cal-js]]
          [%fall %| /requests empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar main: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/calendar])
        (http-dispatch:io %cal)
          ::
          ::  /calendar.calendar: poke CRUD on events
          ::
          [~ %'calendar.calendar']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar events: failed")
        |-
        ;<  [* =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        ;<  c=calendar:cal  bind:m  (get-state-as:io ,calendar:cal)
        ?:  =('del-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ?:  =('' id)  $
          ;<  ~  bind:m  (replace:io c(events (~(del by events.c) id)))
          $
        ?:  =('skip-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  idx=(unit @ud)  (gn jon 'idx')
          ?:  |(=('' id) ?=(~ idx))  $
          =/  ev=(unit event:cal)  (~(get by events.c) id)
          ?~  ev  $
          =/  new=(unit event:cal)
            ?-  -.u.ev
              %date   ~                ::  a date can't be skipped
              %timed   `u.ev(except.bound (~(put in except.bound.u.ev) u.idx))
              %allday  `u.ev(except.bound (~(put in except.bound.u.ev) u.idx))
            ==
          ?~  new  $
          ;<  ~  bind:m  (replace:io c(events (~(put by events.c) id u.new)))
          $
        ?:  =('config' act)
          =/  ti=@t  (gs jon 'title')
          =/  zo=@t  (gs jon 'zone')
          =/  hd=(unit @ud)  (gn jon 'horizon_days')
          =.  title.c  ?:(=('' ti) title.c ti)
          =.  zone.c  ?:(=('' zo) zone.c ?:(=('none' zo) ~ `zo))
          =.  horizon.c  ?~(hd horizon.c (mul u.hd ~d1))
          ;<  ~  bind:m  (replace:io c)
          $
        ?:  =('add-feed' act)
          =/  nm=@t   (gs jon 'name')
          =/  url=@t  (gs jon 'url')
          ?:  |(=('' nm) =('' url))  $
          ;<  fv=view:nexus  bind:m
            (peek:io (cord-to-road:tarball './gcal-feeds.json') ~)
          =/  feeds=(map @t json)
            ?.  ?=([%file *] fv)  ~
            =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
            ?.(?=(%o -.j) ~ p.j)
          ;<  ~  bind:m
            %+  over:io  (cord-to-road:tarball './gcal-feeds.json')
            [[/ %json] `json`[%o (~(put by feeds) nm s+url)]]
          $
        ?:  =('del-feed' act)
          =/  nm=@t  (gs jon 'name')
          ?:  =('' nm)  $
          ;<  fv=view:nexus  bind:m
            (peek:io (cord-to-road:tarball './gcal-feeds.json') ~)
          =/  feeds=(map @t json)
            ?.  ?=([%file *] fv)  ~
            =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
            ?.(?=(%o -.j) ~ p.j)
          ;<  ~  bind:m
            %+  over:io  (cord-to-road:tarball './gcal-feeds.json')
            [[/ %json] `json`[%o (~(del by feeds) nm)]]
          $
        ?:  =('sync-feeds' act)
          ::  materialize external ICS feeds as events: drop all
          ::  prior feed-tagged events, re-add fresh (recurring
          ::  VEVENTs are skipped for now)
          ;<  feeds-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball './gcal-feeds.json') ~)
          =/  feeds=(list [nm=@t url=@t])
            ?.  ?=([%file *] feeds-view)  ~
            =/  j=json
              (fall (mole |.(!<(json (need-vase:tarball sang.feeds-view)))) *json)
            ?.  ?=(%o -.j)  ~
            %+  murn  ~(tap by p.j)
            |=([k=@t v=json] ?.(?=(%s -.v) ~ `[k p.v]))
          ?~  feeds
            ~&  >>>  "%calendar sync: no feeds configured"
            $
          ;<  now=@da  bind:m  get-time:io
          ;<  [synced=(map eid:cal event:cal) skipped=@ud]  bind:m
            (do-sync feeds (sub now (mul 90 ~d1)) (add now (mul 2 ~d365)))
          =/  kept=(map eid:cal event:cal)
            %-  ~(gas by *(map eid:cal event:cal))
            %+  skim  ~(tap by events.c)
            |=  [@ta e=event:cal]
            =('' (meta-str:cal (get-meta e) 'feed'))
          ~&  >  "%calendar sync: {(scow %ud ~(wyt by synced))} synced, {(scow %ud skipped)} recurring skipped"
          ;<  ~  bind:m  (replace:io c(events (~(uni by kept) synced)))
          $
        ?:  =('edit-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  old=(unit event:cal)  (~(get by events.c) id)
          ?~  old  $
          =/  ev=(unit event:cal)  (parse-event jon zone.c)
          ?~  ev
            ~&  >>>  "%calendar: bad edit-event"
            $
          ::  the shape is replaced but exceptions survive the edit
          =/  merged=event:cal  (carry-except u.old u.ev)
          ;<  new=event:cal  bind:m  (apply-until merged (gn jon 'until_ms'))
          ;<  ~  bind:m  (replace:io c(events (~(put by events.c) id new)))
          $
        ?:  =('cap-event' act)
          ::  end the series before index dom (this-and-following edits)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  cap=(unit @ud)  (gn jon 'dom')
          ?:  |(=('' id) ?=(~ cap))  $
          =/  old=(unit event:cal)  (~(get by events.c) id)
          ?~  old  $
          =/  new=(unit event:cal)
            ?-  -.u.old
              %date   ~
              %timed   `u.old(dom.bound `u.cap)
              %allday  `u.old(dom.bound `u.cap)
            ==
          ?~  new  $
          ;<  ~  bind:m  (replace:io c(events (~(put by events.c) id u.new)))
          $
        ?.  =('add-event' act)  $
        =/  ev=(unit event:cal)  (parse-event jon zone.c)
        ?~  ev
          ~&  >>>  "%calendar: bad add-event"
          $
        ;<  ev2=event:cal  bind:m  (apply-until u.ev (gn jon 'until_ms'))
        ;<  eny=@uvJ  bind:m  get-entropy:io
        =/  id=@ta  (scot %uv (end [3 8] eny))
        ;<  ~  bind:m  (replace:io c(events (~(put by events.c) id ev2)))
        $
          ::
          ::  /order.calendar-cache: reinflate on calendar news
          ::
          [~ %'order.calendar-cache']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar cache: failed")
        =/  road  (cord-to-road:tarball './calendar.calendar')
        ;<  *  bind:m  (keep:io /cal road ~)
        |-
        ;<  =view:nexus  bind:m  (peek:io road ~)
        ?.  ?=([%file *] view)
          ;<  *  bind:m  (take-news:io /cal)
          $
        =/  c=calendar:cal
          %+  fall
            (mole |.(!<(calendar:cal (need-vase:tarball sang.view))))
          fresh-calendar:cal
        =/  rails=(list rail:tarball)
          %~  tap  in
          %-  sy
          %+  murn  ~(tap by events.c)
          |=  [@ta e=event:cal]
          ^-  (unit rail:tarball)
          ?-  -.e
            %date   ~
            %timed   `kind.recur.e
            %allday  `kind.recur.e
          ==
        ;<  kinds=(map rail:tarball kind:rules)  bind:m  (resolve-kinds rails)
        ;<  now=@da  bind:m  get-time:io
        =/  thru=@da  (add now horizon.c)
        =/  [stops=(map eid:cal @da) o=order:cal]  (inflate:cal events.c kinds thru)
        ;<  ~  bind:m  (replace:io `cache:cal`[thru stops o])
        ;<  *  bind:m  (take-news:io /cal)
        $
          ::
          ::  /reminders.json: tick on utc 5-minute marks, push-notify
          ::  timed events starting lead_min ahead. fired_ms is the
          ::  watermark: everything due in (fired, now] goes out once.
          ::
          [~ %'reminders.json']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar reminders: failed")
        |-
        ;<  now=@da  bind:m  get-time:io
        =/  tick=@da  (add (sub now (mod now ~m5)) ~m5)
        ;<  ~  bind:m  (wait:io tick)
        ;<  now=@da  bind:m  get-time:io
        ;<  st=json  bind:m  (get-state-as:io ,json)
        =/  lead=@dr  (mul (max 1 (fall (gn st 'lead_min') 30)) ~m1)
        =/  fired=@da
          =/  ms=(unit @ud)  (gn st 'fired_ms')
          ?~(ms *@da (ms-to-da u.ms))
        ::  cap lookback so a ship that slept doesn't spam stale
        ::  reminders on wake
        =/  floor=@da  (sub now ~m15)
        =/  from=@da  ?:((gth fired floor) fired floor)
        ;<  cache-view=view:nexus  bind:m
          (peek:io (cord-to-road:tarball './order.calendar-cache') ~)
        ;<  cal-view=view:nexus  bind:m
          (peek:io (cord-to-road:tarball './calendar.calendar') ~)
        =/  ca=cache:cal
          ?.  ?=([%file *] cache-view)  *cache:cal
          (fall (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view)))) *cache:cal)
        =/  c=calendar:cal
          ?.  ?=([%file *] cal-view)  fresh-calendar:cal
          %+  fall
            (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
          fresh-calendar:cal
        =/  lo=@da  (add from lead)
        =/  hi=@da  (add now lead)
        =/  due=(list ref:cal)
          %+  skim  ~(tap in (window:cal order.ca lo hi))
          |=  r=ref:cal
          &((gth l.span.r lo) (lte l.span.r hi))
        ;<  ~  bind:m  (send-reminders due events.c now)
        =/  new-st=json
          :-  %o
          %-  ~(put by ?:(?=(%o -.st) p.st ~))
          ['fired_ms' (numb:enjs:format (da-to-ms now))]
        ;<  ~  bind:m  (replace:io new-st)
        $
          ::
          ::  /requests: window.json, events.json
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%calendar request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent `path`/grubbery/calendar) site)
        ?:  ?=([%'window.json' ~] suffix)
          =/  from=(unit @da)  (ms-arg args 'from')
          =/  to=(unit @da)    (ms-arg args 'to')
          ?:  |(?=(~ from) ?=(~ to))
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'need from/to (unix ms)')])
            (pure:m ~)
          ;<  cache-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../order.calendar-cache') ~)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  ca=cache:cal
            ?.  ?=([%file *] cache-view)  *cache:cal
            (fall (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view)))) *cache:cal)
          =/  c=calendar:cal
            ?.  ?=([%file *] cal-view)  fresh-calendar:cal
            %+  fall
              (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
            fresh-calendar:cal
          ::  refresh-ahead: the cache is derived state, so a read
          ::  past the wall (or with under half the horizon left)
          ::  reinflates and persists rather than serving a silent
          ::  truncation
          ;<  now=@da  bind:m  get-time:io
          ;<  ca=cache:cal  bind:m
            ?.  ?|  (gth u.to thru.ca)
                    (lth thru.ca (add now (div horizon.c 2)))
                ==
              (pure:(fiber:fiber:nexus ,cache:cal) ca)
            =/  m  (fiber:fiber:nexus ,cache:cal)
            =/  rails=(list rail:tarball)
              %~  tap  in
              %-  sy
              %+  murn  ~(tap by events.c)
              |=  [@ta e=event:cal]
              ^-  (unit rail:tarball)
              ?-  -.e
                %date    ~
                %timed   `kind.recur.e
                %allday  `kind.recur.e
              ==
            ;<  kinds=(map rail:tarball kind:rules)  bind:m  (resolve-kinds rails)
            =/  thru=@da  (max (add now horizon.c) u.to)
            =/  [stops=(map eid:cal @da) o=order:cal]  (inflate:cal events.c kinds thru)
            =/  new=cache:cal  [thru stops o]
            ;<  ~  bind:m
              %+  over:io  (cord-to-road:tarball '../order.calendar-cache')
              [[/ %calendar-cache] new]
            (pure:m new)
          =/  refs=(list ref:cal)
            ~(tap in (window:cal order.ca u.from u.to))
          =/  rows=json
            :-  %a
            %+  murn  refs
            |=  r=ref:cal
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by events.c) eid.r)
            ?~  ev  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+eid.r]
                ['idx' (numb:enjs:format idx.r)]
                ['meta' [%o (get-meta u.ev)]]
                ['cat' s+-.u.ev]
                ['kind' s+(ev-kind u.ev)]
                ['all' b+(all-day:cal u.ev)]
                ['l' (numb:enjs:format (da-to-ms l.span.r))]
                ['r' (numb:enjs:format (da-to-ms r.span.r))]
            ==
          =/  caps=json
            :-  %a
            %+  murn  ~(tap by stops.ca)
            |=  [id=@ta stop=@da]
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by events.c) id)
            ?~  ev  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+id]
                ['meta' [%o (get-meta u.ev)]]
                ['stop' (numb:enjs:format (da-to-ms stop))]
            ==
          %+  send-json  eyre-id
          %-  pairs:enjs:format
          :~  ['caps' caps]
              ['rows' rows]
          ==
        ::  /event.json?id=: full rule breakdown for the edit form
        ?:  ?=([%'event.json' ~] suffix)
          =/  id=@ta  (crip (trip (fall (get-key:kv:html-utils 'id' args) '')))
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal
            ?.  ?=([%file *] cal-view)  fresh-calendar:cal
            %+  fall
              (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
            fresh-calendar:cal
          =/  ev=(unit event:cal)  (~(get by events.c) id)
          ?~  ev
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'No such event')])
            (pure:m ~)
          (send-json eyre-id (event-json:cal id u.ev))
        ?:  ?=([%'events.json' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal
            ?.  ?=([%file *] cal-view)  fresh-calendar:cal
            %+  fall
              (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
            fresh-calendar:cal
          =/  rows=json
            :-  %a
            %+  turn  ~(tap by events.c)
            |=  [id=@ta e=event:cal]
            ^-  json
            %-  pairs:enjs:format
            :~  ['id' s+id]
                ['meta' [%o (get-meta e)]]
                ['cat' s+-.e]
            ==
          (send-json eyre-id rows)
        ::  /feeds.json: the named external ICS feeds
        ?:  ?=([%'feeds.json' ~] suffix)
          ;<  fv=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../gcal-feeds.json') ~)
          =/  feeds=json
            ?.  ?=([%file *] fv)  [%o ~]
            =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
            ?:(?=(%o -.j) j [%o ~])
          (send-json eyre-id feeds)
        ::  /zones.json: every pytz zone name, for dropdowns
        ?:  ?=([%'zones.json' ~] suffix)
          %+  send-json  eyre-id
          [%a (turn zone-names:pytz |=(n=@t `json`s+n))]
        ::  /config.json: title, display zone, poke target for the client
        ?:  ?=([%'config.json' ~] suffix)
          ::  our own address, read from grant.json (no peek / walk).
          ;<  bh=(unit @t)  bind:m  (here:sh rail)
          =/  ball=tape
            ?~  bh  ""
            =/  bt=tape  (trip u.bh)
            ?:(?&(?=(^ bt) =('/' i.bt)) t.bt bt)
          ;<  zone-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal
            ?.  ?=([%file *] zone-view)  fresh-calendar:cal
            %+  fall
              (mole |.(!<(calendar:cal (need-vase:tarball sang.zone-view))))
            fresh-calendar:cal
          =/  =json
            %-  pairs:enjs:format
            :~  ['title' s+title.c]
                ['zone' ?~(zone.c ~ s+u.zone.c)]
                ['ball' s+(crip ball)]
            ==
          (send-json eyre-id json)
        ::  static files; the shell is the default
        =/  filename=@ta
          ?~  suffix  'calendar.html'
          i.suffix
        ;<  file-view=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
        ?.  ?=([%file *] file-view)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.file-view))
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  get-meta
  |=  e=event:cal
  ^-  meta:cal
  ?-(-.e %timed meta.e, %allday meta.e, %date meta.e)
::  +ev-kind: the recurrence kind name, or 'date'
::
++  ev-kind
  |=  e=event:cal
  ^-  @t
  ?-(-.e %date 'date', %timed name.kind.recur.e, %allday name.kind.recur.e)
::  +carry-except: preserve the old event's skipped indices onto the
::  freshly-parsed replacement (only where both have a bound)
::
++  carry-except
  |=  [old=event:cal new=event:cal]
  ^-  event:cal
  =/  ex=(set @ud)
    ?-(-.old %date ~, %timed except.bound.old, %allday except.bound.old)
  ?~  ex  new
  ?-  -.new
    %date   new
    %timed   new(except.bound ex)
    %allday  new(except.bound ex)
  ==
::
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  (fall (bind (~(get by p.jon) k) |=(=json ?>(?=(%s -.json) p.json))) '')
::
++  gn
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  ?.  ?=(%o -.jon)  ~
  =/  j=(unit json)  (~(get by p.jon) k)
  ?~  j  ~
  ?.  ?=(%n -.u.j)  ~
  (rush p.u.j dem)
::
++  ms-to-da  |=(ms=@ud `@da`(add ~1970.1.1 (div (mul ms ~s1) 1.000)))
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
::
++  ms-arg
  |=  [args=quay:eyre k=@t]
  ^-  (unit @da)
  =/  v=(unit @t)  (get-key:kv:html-utils k args)
  ?~  v  ~
  (bind (rush u.v dem) ms-to-da)
::
++  send-json
  |=  [eyre-id=@ta =json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  ;<  ~  bind:m
    (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  (pure:m ~)
::  +send-reminders: one push per due timed occurrence. The tag is
::  eid+idx so a re-send replaces rather than stacks.
::
++  send-reminders
  |=  [due=(list ref:cal) events=(map eid:cal event:cal) now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  due  (pure:m ~)
  =/  r=ref:cal  i.due
  =/  ev=(unit event:cal)  (~(get by events) eid.r)
  ?.  &(?=(^ ev) ?=(%timed -.u.ev))
    $(due t.due)
  =/  name=@t  (meta-str:cal (get-meta u.ev) 'name')
  =/  mins=@ud
    (div ?:((gth l.span.r now) (sub l.span.r now) 0) ~m1)
  =/  body=@t
    (crip ?:(=(0 mins) "starting now" "in {(scow %ud mins)} min"))
  =/  tag=@t
    (crip "cal-{(trip eid.r)}-{(scow %ud idx.r)}")
  ;<  ~  bind:m
    (send-push:io [~ ~ ~ [name body ~ `'/grubbery/calendar' `tag]])
  $(due t.due)
::  +do-sync: fetch each feed, parse its ICS, and convert single
::  (non-recurring) vevents inside [lo hi] into events tagged with
::  feed name + uid. Stable ids: same feed+uid = same event id.
::
++  do-sync
  |=  [feeds=(list [nm=@t url=@t]) lo=@da hi=@da]
  =/  m  (fiber:fiber:nexus ,[(map eid:cal event:cal) skipped=@ud])
  ^-  form:m
  =/  out=(map eid:cal event:cal)  ~
  =/  skipped=@ud  0
  |-
  ?~  feeds  (pure:m [out skipped])
  ~&  >  "%calendar sync: fetching {(trip nm.i.feeds)}"
  ;<  body=@t  bind:m  (fetch:io [%'GET' url.i.feeds ~ ~])
  =/  evs=(list vevent:ics)  ?:(=('' body) ~ (events:ics body))
  =/  res=[got=(map eid:cal event:cal) sk=@ud]
    %+  roll  evs
    |=  [ve=vevent:ics acc=[got=(map eid:cal event:cal) sk=@ud]]
    ?.  =('' rrule.ve)  acc(sk +(sk.acc))
    =/  ev=(unit event:cal)  (ics-event ve nm.i.feeds lo hi)
    ?~  ev  acc
    =/  id=@ta  (crip "gc-{(trip (scot %uw (mug [nm.i.feeds uid.ve])))}")
    acc(got (~(put by got.acc) id u.ev))
  %=  $
    feeds    t.feeds
    out      (~(uni by out) got.res)
    skipped  (add skipped sk.res)
  ==
::  +ics-event: one parsed vevent to a ship event. Date-only becomes
::  %allday; datetimes become a %timed %once, TZID as the zone and
::  DTEND as an absolute %to end.
::
++  ics-event
  |=  [ve=vevent:ics feed=@t lo=@da hi=@da]
  ^-  (unit event:cal)
  ?~  start.ve  ~
  =/  s=when:ics  u.start.ve
  =/  sd=@da  ?-(-.s %utc d.s, %local d.s, %day d.s)
  ?:  |((lth sd lo) (gth sd hi))  ~
  =/  =meta:cal
    %-  ~(gas by *(map @t json))
    ^-  (list [@t json])
    ;:  weld
      ^-  (list [@t json])
      ~[['name' s+?:(=('' summary.ve) 'Untitled' summary.ve)]]
      ^-  (list [@t json])
      ?:(=('' location.ve) ~ ~[['note' s+location.ve]])
      ^-  (list [@t json])
      ~[['feed' s+feed] ['uid' s+uid.ve]]
    ==
  ?:  ?=(%day -.s)
    =/  days=@ud
      ?~  end.ve  1
      ?.  ?=(%day -.u.end.ve)  1
      (max 1 (div (sub d.u.end.ve d.s) ~d1))
    `[%allday [[/lib/rules %once] ~ d.s] days [~ ~] meta]
  =/  zone=(unit @t)  ?:(?=(%local -.s) `zone.s ~)
  =/  =fin:cal
    ?~  end.ve  [%dur ~s0]
    ?-  -.u.end.ve
      %day    [%dur ~s0]
      %utc    [%to d.u.end.ve]
      %local  [%to d.u.end.ve]
    ==
  `[%timed [[/lib/rules %once] ~ sd] zone fin [~ ~] meta]
::  +weir-json: the roads calendar actually reaches (declared for the shell).
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship — every fiber uses get-time / get-our')
          (line '/sys/eyre/' 'bind its HTTP route and send page responses')
          (line '/sys/behn/' 'the reminders fiber ticks on 5-minute marks to fire due reminders')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/code/lib/rules/' 'build recurrence-rule kinds from the rules code library')
      ==
  ==
::  +resolve-kinds: load kind gates from the code namespace
::
++  resolve-kinds
  |=  rails=(list rail:tarball)
  =/  m  (fiber:fiber:nexus ,(map rail:tarball kind:rules))
  ^-  form:m
  =|  out=(map rail:tarball kind:rules)
  |-
  ?~  rails  (pure:m out)
  =/  code-road=road:tarball
    &+&+[(weld /code path.i.rails) name.i.rails]
  ;<  code=(unit vase)  bind:m  (get-code:io code-road)
  ?~  code  $(rails t.rails)
  =/  got=(each kind:rules tang)  (mule |.(!<(kind:rules u.code)))
  ?:  ?=(%| -.got)  $(rails t.rails)
  $(rails t.rails, out (~(put by out) i.rails p.got))
::  +apply-until: compile an until-date into dom by scanning the
::  rule's instances. Explicit count (dom already set) wins; sugar
::  only — the stored rule never knows about the date.
::
++  apply-until
  ::  compile an until-date into the index cap (dom) by walking the
  ::  kind's moments. Explicit count wins; only for shapes with a
  ::  recur (timed/allday). Sugar — the stored event keeps only dom.
  ::
  |=  [e=event:cal until=(unit @ud)]
  =/  m  (fiber:fiber:nexus ,event:cal)
  ^-  form:m
  ?~  until  (pure:m e)
  =/  rd=(unit [=recur:cal dom=(unit @ud)])
    ?-  -.e
      %date   ~
      %timed   `[recur.e dom.bound.e]
      %allday  `[recur.e dom.bound.e]
    ==
  ?~  rd  (pure:m e)
  ?.  ?=(~ dom.u.rd)  (pure:m e)  ::  explicit count wins
  =/  =recur:cal  recur.u.rd
  =/  lim=@da  (ms-to-da u.until)
  =/  kr=rail:tarball  kind.recur
  ;<  code=(unit vase)  bind:m
    (get-code:io &+&+[(weld /code path.kr) name.kr])
  ?~  code  (pure:m e)
  =/  kg=(each kind:rules tang)  (mule |.(!<(kind:rules u.code)))
  ?:  ?=(%| -.kg)  (pure:m e)
  =/  cap=@ud
    =/  idx=@ud  0
    =/  dead=@ud  0
    |-  ^-  @ud
    ?:  |((gth dead 400) (gth idx 10.000))  idx
    =/  moment=(unit @da)
      (fall (mole |.((p.kg args.recur start.recur idx))) ~)
    ?~  moment  $(idx +(idx), dead +(dead))
    ?:  (gth u.moment lim)  idx
    $(idx +(idx), dead 0)
  %-  pure:m
  ?-  -.e
    %date   e
    %timed   e(dom.bound `cap)
    %allday  e(dom.bound `cap)
  ==
::  +parse-recur: json -> a shared clock [kind args start]. args
::  pass through as the 'args' object verbatim — only the kind file
::  knows what they mean.
::
++  parse-recur
  |=  jon=json
  ^-  (unit recur:cal)
  =/  kind=@t  (gs jon 'kind')
  ?:  =('' kind)  ~
  =/  start=(unit @da)  (bind (gn jon 'start_ms') ms-to-da)
  ?~  start  ~
  =/  args=(map @t json)
    =/  a=(unit json)  (~(get jo:json-utils jon) /args)
    ?.(?=([~ %o *] a) ~ p.u.a)
  `[[/lib/rules (slav %tas kind)] args u.start]
::  +parse-event: json -> one of the three event shapes. dz is the
::  calendar's default zone for timed events with none named.
::
++  parse-event
  |=  [jon=json dz=(unit @t)]
  ^-  (unit event:cal)
  =/  cat=@t  (gs jon 'cat')
  ::  meta passes through verbatim; only 'name' is required
  =/  =meta:cal
    =/  mj=(unit json)  (~(get jo:json-utils jon) /meta)
    ?.(?=([~ %o *] mj) ~ p.u.mj)
  ?:  =('' (meta-str:cal meta 'name'))  ~
  ::  date: a bare recurring date, no clock
  ?:  =('date' cat)
    =/  mo=(unit @ud)  (gn jon 'month')
    =/  dy=(unit @ud)  (gn jon 'day')
    ?:  |(?=(~ mo) ?=(~ dy))  ~
    `[%date u.mo u.dy meta]
  ::  timed / allday both wrap a recur
  =/  rec=(unit recur:cal)  (parse-recur jon)
  ?~  rec  ~
  =/  dom=(unit @ud)
    =/  n=(unit @ud)  (gn jon 'count')
    ?~  n  ~
    ?:(=(0 u.n) ~ n)
  =/  =bound:cal  [dom ~]
  ?:  =('allday' cat)
    =/  days=@ud  (max 1 (fall (gn jon 'span_days') 1))
    `[%allday u.rec days bound meta]
  ::  timed
  =/  zone=(unit @t)
    =/  z=@t  (gs jon 'zone')
    ?:  =('none' z)  ~
    ?:(=('' z) dz `z)
  =/  =fin:cal
    =/  f=@t  (gs jon 'fin')
    ?:  =('to' f)  [%to (fall (bind (gn jon 'end_ms') ms-to-da) *@da)]
    [%dur (mul (fall (gn jon 'dur_min') 0) ~m1)]
  `[%timed u.rec zone fin bound meta]
--
