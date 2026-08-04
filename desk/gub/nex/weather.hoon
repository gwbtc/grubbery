::  weather nexus: current conditions and forecasts from open-meteo
::
::  One grub per city: /forecasts/<slug>.json, whose fiber
::  independently fetches that city's forecast every 30 minutes
::  (any poke refetches now) and rewrites itself. Data is always
::  fetched metric — units are a rendering concern: the frontend
::  converts at display time, and only the shell tile (server-
::  rendered text) converts on the ship.
::
::  config.json is the user's intent: display units and the ordered
::  city list. The refresh.sig supervisor reconciles /forecasts to
::  it: makes missing city files, culls orphans, re-renders the
::  tile. Endpoints write config and poke the supervisor.
::
::  /config.json           {units: 'c'|'f', locations: [{name, lat, lon}]}
::  /forecasts/<slug>.json {resp, at}
::  /refresh.sig           supervisor (reconcile + tile)
::  /main.sig              HTTP at /grubbery/weather
::    GET  /data           config + all forecasts as one json
::    POST /add            {"name": "stockholm"} — geocode and add
::    POST /del            {"name": "..."}
::    POST /order          {"order": ["name", ...]} — reorder
::    POST /units          {"units": "c" | "f"} — display pref only
::    POST /refresh        poke every city to refetch now
::
/<  index-html  weather/index.html
/<  app-js      weather/app.js
/<  icon        weather/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'config.json'] [[/ %json] [%a ~]]]
          [%fall %| /forecasts empty-dir:loader]
          [%fall %& [/ %'refresh.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %& [/ %'tile.json'] [[/ %json] default-tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  supervisor: reconcile /forecasts to config on every
          ::  poke — make missing city files, cull orphans, tile
          ::
          [~ %'refresh.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%weather /refresh: failed")
        |-
        ;<  ~  bind:m  (reconcile rail)
        ;<  ~  bind:m  take-any-poke
        $
          ::  one city: fetch own forecast, rewrite self, loop.
          ::  Timer wakes and direct pokes both mean fetch now.
          ::
          [[%forecasts ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%weather forecast: failed")
        |-
        ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
        =/  mine=(list json)
          %+  skim  locs
          |=(l=json =(name.rail (city-file (jstr l 'name'))))
        ?~  mine
          ::  no longer configured; wait for the supervisor's cull
          ;<  ~  bind:m  (take-poke-or-wake ~)
          $
        =/  loc=json  i.mine
        =/  name=@t  (jstr loc 'name')
        ;<  resp=(unit json)  bind:m
          (fetch-forecast (jstr loc 'lat') (jstr loc 'lon'))
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m
          ?~  resp
            ::  transient failure: keep whatever we had
            ~&  >>  [%weather-fetch-failed name]
            (pure:m ~)
          %-  replace:io
          ^-  json
          (pairs:enjs:format ~[['resp' u.resp] ['at' s+(scot %da now)]])
        ::  the first-ordered city renders the shell tile
        ;<  ~  bind:m
          ?:  &(?=(^ locs) =(name (jstr i.locs 'name')))
            (render-tile rail)
          (pure:m ~)
        ;<  then=@da  bind:m  get-time:io
        =/  until=@da  (add then ~m30)
        ;<  ~  bind:m  (send-wait:io until)
        ;<  ~  bind:m  (take-poke-or-wake `until)
        $
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%weather /main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/weather])
        (http-dispatch:io %weather)
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%weather /requests: failed")
        =/  srv  ~(. http-res:io (nex-road:io rail [%& ~ %'main.sig']))
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path
          %+  skip  (slag (lent `path`/grubbery/weather) site)
          |=(seg=@ta =('' seg))
        ?:  =('POST' method.request.req)
          =/  jon=json
            %+  fall
              (de:json:html ?~(body.request.req '' q.u.body.request.req))
            *json
          ?+    suffix
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
              [%add ~]
            =/  name=@t  (jstr jon 'name')
            ?:  =('' name)
              ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'name required')])
              (pure:m ~)
            ;<  loc=(unit json)  bind:m  (geocode name)
            ?~  loc
              ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'place not found')])
              (pure:m ~)
            ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
            ;<  ~  bind:m  (write-config rail units (snoc locs u.loc))
            ;<  ~  bind:m  (poke-supervisor rail)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'added')])
            (pure:m ~)
              [%del ~]
            =/  name=@t  (jstr jon 'name')
            ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
            ;<  ~  bind:m
              (write-config rail units (skip locs |=(l=json =(name (jstr l 'name')))))
            ;<  ~  bind:m  (poke-supervisor rail)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'deleted')])
            (pure:m ~)
              ::  reorder: named locations take the given order, any
              ::  not mentioned keep their old order at the end
              [%order ~]
            =/  names=(list @t)
              ?.  ?=(%o -.jon)  ~
              =/  v  (~(get by p.jon) 'order')
              ?.  ?=([~ %a *] v)  ~
              %+  murn  p.u.v
              |=(j=json ?:(?=([%s *] j) `p.j ~))
            ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
            =/  ordered=(list json)
              %+  murn  names
              |=  n=@t
              ^-  (unit json)
              =/  hits  (skim locs |=(l=json =(n (jstr l 'name'))))
              ?~(hits ~ `i.hits)
            =/  rest=(list json)
              %+  skip  locs
              |=(l=json (lien names |=(n=@t =(n (jstr l 'name')))))
            ;<  ~  bind:m  (write-config rail units (weld ordered rest))
            ;<  ~  bind:m  (poke-supervisor rail)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              ::  display preference only — no refetch, but the
              ::  supervisor re-renders the tile in the new units
              [%units ~]
            =/  units=@t  (jstr jon 'units')
            ?.  |(=('c' units) =('f' units))
              ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'units must be c or f')])
              (pure:m ~)
            ;<  [old=@t locs=(list json)]  bind:m  (read-config rail)
            ;<  ~  bind:m  (write-config rail units locs)
            ;<  ~  bind:m  (poke-supervisor rail)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              ::  wake every city fiber to refetch now
              [%refresh ~]
            ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
            =/  todo=(list json)  locs
            |-
            ?^  todo
              =/  n=@t  (jstr i.todo 'name')
              ;<  ~  bind:m
                ?:  =('' n)  (pure:m ~)
                (poke:io (nex-road:io rail [%& /forecasts (city-file n)]) [[/ %sig] ~])
              $(todo t.todo)
            ;<  ~  bind:m  (poke-supervisor rail)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
          ==
        ?:  ?=([%data ~] suffix)
          ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
          =/  todo=(list json)  locs
          =|  wout=(list [@t json])
          |-
          ?^  todo
            =/  name=@t  (jstr i.todo 'name')
            ;<  fc=(unit json)  bind:m
              (peek-as:io (nex-road:io rail [%& /forecasts (city-file name)]) ,json)
            ?.  ?&(?=(^ fc) ?=(%o -.u.fc) (~(has by p.u.fc) 'resp'))
              $(todo t.todo)
            =/  entry=json  o+(~(put by p.u.fc) 'loc' i.todo)
            $(todo t.todo, wout [[name entry] wout])
          =/  out=json
            %-  pairs:enjs:format
            :~  ['units' s+units]
                ['locations' a+locs]
                ['weather' o+(malt (flop wout))]
            ==
          =/  bod=octs  (as-octs:mimes:html (en:json:html out))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `bod])
          (pure:m ~)
        ::  static files from the nexus root
        =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
        ;<  fv=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& ~ filename]) `[/ %mime])
        ?.  ?=([%file *] fv)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.fv))
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
++  default-tile
  ^-  json
  %-  pairs:enjs:format
  :~  title+s+'Weather'
      info+s+'add a location'
      color+s+'#4a90d9'
      image+s+'/grubbery/tiles/icon/weather.weather'
      href+s+'/grubbery/weather'
  ==
::
++  jstr
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=(%o -.j)  ''
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) '' p.u.v)
::  +jnumt: a json number's literal text ('13.4'), for URLs and
::  display without any float math
::
++  jnumt
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=(%o -.j)  ''
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %n *] v) '' `@t`p.u.v)
::  +slug: display name -> filename-safe @ta ('Mexico City' ->
::  'mexico-city'); rail names are knots, spaces don't belong
::
++  slug
  |=  n=@t
  ^-  @ta
  %-  crip
  %+  murn  (trip n)
  |=  c=@tD
  ^-  (unit @tD)
  ?:  &((gte c 'a') (lte c 'z'))  `c
  ?:  &((gte c 'A') (lte c 'Z'))  `(add c 32)
  ?:  &((gte c '0') (lte c '9'))  `c
  ?:  |(=('-' c) =('_' c))  `c
  ?:  =(' ' c)  `'-'
  ~
::
++  city-file
  |=  n=@t
  ^-  @ta
  (rap 3 (slug n) '.json' ~)
::
++  poke-supervisor
  |=  =rail:tarball
  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
::
++  take-any-poke
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~              [%wait ~]
    [~ %veto *]    [%fail (veto-error:io dart.u.in)]
    [~ %poke * *]  [%done ~]
  ==
::  +take-poke-or-wake: wake on a real poke or on our own alarm,
::  skipping stray timer-wakes (abandoned fetch timeouts) and late
::  http responses so they can't fire a premature refetch
::
++  take-poke-or-wake
  |=  until=(unit @da)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %http-response] p.sage.u.in)  [%skip ~]
    ?.  =([/ %timer-wake] p.sage.u.in)  [%done ~]
    =/  wak=path  !<(path q.sage.u.in)
    ?:  ?&  ?=(^ until)
            ?=([%wait @ ~] wak)
            =(u.until (slav %da i.t.wak))
        ==
      [%done ~]
    [%skip ~]
  ==
::  +take-response-or-timeout: the response, or ~ when our alarm
::  fires first (or iris cancels) — the fiber owns its own deadline
::  instead of dying on vere's
::
++  take-response-or-timeout
  |=  until=@da
  =/  m  (fiber:fiber:nexus ,(unit client-response:iris))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %http-response] p.sage.u.in)
      =/  resp  !<(client-response:iris q.sage.u.in)
      ?:  ?=(%cancel -.resp)  [%done ~]
      [%done `resp]
    ?.  =([/ %timer-wake] p.sage.u.in)  [%skip ~]
    =/  wak=path  !<(path q.sage.u.in)
    ?:  &(?=([%fetch-timeout @ ~] wak) =(until (slav %da i.t.wak)))
      [%done ~]
    [%skip ~]
  ==
::
++  read-config
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,[units=@t locs=(list json)])
  ^-  form:m
  ;<  cfg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& ~ %'config.json']) ,json)
  %-  pure:m
  ?~  cfg  ['c' ~]
  ?:  ?=(%a -.u.cfg)  ['c' p.u.cfg]
  ?.  ?=(%o -.u.cfg)  ['c' ~]
  =/  units=@t  (jstr u.cfg 'units')
  =/  locs  (~(get by p.u.cfg) 'locations')
  :-  ?:(=('f' units) 'f' 'c')
  ?.(?=([~ %a *] locs) ~ p.u.locs)
::
++  write-config
  |=  [=rail:tarball units=@t locs=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %+  over:io  (nex-road:io rail [%& ~ %'config.json'])
  :-  [/ %json]
  ^-  json
  (pairs:enjs:format ~[['units' s+units] ['locations' a+locs]])
::  +reconcile: make city files config wants, cull ones it doesn't,
::  re-render the tile. City fibers fetch on spin, so a fresh file
::  needs no extra poke.
::
++  reconcile
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
  =/  wanted=(list @ta)
    %+  murn  locs
    |=  l=json
    ^-  (unit @ta)
    =/  n  (jstr l 'name')
    ?:(=('' n) ~ `(city-file n))
  ;<  =view:nexus  bind:m
    (peek-shallow:io (nex-road:io rail [%| /forecasts]) ~)
  =/  have=(list @ta)
    ?.  ?=([%ball *] view)  ~
    ?~  fil.ball.view  ~
    ~(tap in ~(key by contents.u.fil.ball.view))
  =/  missing=(list @ta)
    (skip wanted |=(w=@ta (lien have |=(h=@ta =(h w)))))
  |-
  ?^  missing
    =/  road  (nex-road:io rail [%& /forecasts i.missing])
    ;<  err=(unit tang)  bind:m
      (make-soft:io road |+[[[/ %json] `json`[%o ~]] ~])
    ~?  >>>  ?=(^ err)  [%weather-make-failed i.missing]
    ;<  ~  bind:m  (gain:io road %.y)
    $(missing t.missing)
  =/  orphans=(list @ta)
    (skip have |=(h=@ta (lien wanted |=(w=@ta =(h w)))))
  |-
  ?^  orphans
    ;<  err=(unit tang)  bind:m
      (cull-soft:io (nex-road:io rail [%& /forecasts i.orphans]))
    $(orphans t.orphans)
  (render-tile rail)
::  +render-tile: first-ordered city's current conditions become the
::  shell tile; the only server-side unit conversion
::
++  render-tile
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
  =/  tile-road  (nex-road:io rail [%& ~ %'tile.json'])
  ?~  locs
    (over:io tile-road [[/ %json] default-tile])
  =/  name=@t  (jstr i.locs 'name')
  ;<  fc=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& /forecasts (city-file name)]) ,json)
  =/  cur=json
    ?.  ?&(?=(^ fc) ?=(%o -.u.fc))  [%o ~]
    =/  resp  (fall (~(get by p.u.fc) 'resp') `json`[%o ~])
    ?.  ?=(%o -.resp)  [%o ~]
    (fall (~(get by p.resp) 'current') `json`[%o ~])
  =/  temp=@t  (jnumt cur 'temperature_2m')
  =/  code=@t  (jnumt cur 'weather_code')
  =/  tile=json
    ?:  =('' temp)  default-tile
    =/  shown=@t  ?:(=('f' units) (fahren temp) temp)
    %-  pairs:enjs:format
    :~  title+s+'Weather'
        info+s+(rap 3 shown '° ' (wmo-word code) ' — ' name ~)
        color+s+(wmo-color code)
        image+s+'/grubbery/tiles/icon/weather.weather'
        href+s+'/grubbery/weather'
    ==
  (over:io tile-road [[/ %json] tile])
::  +fahren: celsius text literal -> rounded fahrenheit text
::  ('13.4' -> '56'), integer math only — no floats on the ship
::
++  fahren
  |=  t=@t
  ^-  @t
  =/  tap=tape  (trip t)
  ?~  tap  t
  =/  neg=?  =('-' i.tap)
  =/  body=tape  ?:(neg t.tap tap)
  =/  dot=(unit @ud)  (find "." body)
  =/  int=(unit @ud)  (rush (crip ?~(dot body (scag u.dot body))) dem)
  ?~  int  t
  =/  fd=@ud
    ?~  dot  0
    =/  fra=tape  (slag +(u.dot) body)
    ?~  fra  0
    ::  cast: wet gates over a ?~-refined lest mull-fail
    (fall (rush (crip (scag 1 `tape`fra)) dem) 0)
  =/  ct=@ud  (add (mul u.int 10) fd)      ::  |celsius| in tenths
  =/  d=@ud  (div (mul ct 9) 5)            ::  |c|*9/5 in tenths
  ?.  neg
    (crip ((d-co:co 1) (div (add (add 320 d) 5) 10)))
  ?:  (gte 320 d)
    (crip ((d-co:co 1) (div (add (sub 320 d) 5) 10)))
  (crip ['-' ((d-co:co 1) (div (add (sub d 320) 5) 10))])
::  +geocode: place name -> {name, lat, lon} via open-meteo, taking
::  the first match. lat/lon keep the API's number literals as text.
::
++  geocode
  |=  name=@t
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ::  double-encoded: vere's cttp.c decodes %XX when parsing the url
  ::  but doesn't re-encode when serializing the request, so a single
  ::  %20 goes out as a literal space (see +web-url in lib/oneshot)
  ::
  =/  enc=tape
    %-  zing
    %+  turn  (en-urlt:html (trip name))
    |=(c=@tD ?:(=('%' c) "%25" (trip c)))
  =/  url=@t
    %+  rap  3
    :~  'https://geocoding-api.open-meteo.com/v1/search?count=1&name='
        (crip enc)
    ==
  ;<  bod=(unit @t)  bind:m  (fetch url)
  ?~  bod  (pure:m ~)
  =/  jon=(unit json)  (de:json:html u.bod)
  ?.  ?&(?=(^ jon) ?=(%o -.u.jon))  (pure:m ~)
  =/  results  (~(get by p.u.jon) 'results')
  ?.  ?&(?=(^ results) ?=(%a -.u.results) ?=(^ p.u.results))  (pure:m ~)
  =/  hit=json  i.p.u.results
  =/  found=@t  (jstr hit 'name')
  =/  lat=@t  (jnumt hit 'latitude')
  =/  lon=@t  (jnumt hit 'longitude')
  ?:  |(=('' lat) =('' lon))  (pure:m ~)
  %-  pure:m
  %-  some
  %-  pairs:enjs:format
  :~  ['name' s+?:(=('' found) name found)]
      ['lat' s+lat]
      ['lon' s+lon]
  ==
::  always metric; units are applied at render time
::
++  fetch-forecast
  |=  [lat=@t lon=@t]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  url=@t
    %+  rap  3
    :~  'https://api.open-meteo.com/v1/forecast?latitude='
        lat
        '&longitude='
        lon
        '&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day,precipitation'
        '&hourly=temperature_2m,precipitation_probability,weather_code,is_day'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max'
        '&forecast_days=7&timezone=auto'
    ==
  ;<  bod=(unit @t)  bind:m  (fetch-retry url)
  %-  pure:m
  ?~  bod  ~
  (de:json:html u.bod)
::  +fetch-retry: one immediate retry on failure; connection
::  timeouts to the forecast API are usually transient
::
++  fetch-retry
  |=  url=@t
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  a=(unit @t)  bind:m  (fetch url)
  ?^  a  (pure:m a)
  (fetch url)
::
::  our own ~s15 deadline; a timeout returns ~ instead of the fiber
::  dying on vere's runtime-level cutoff
::
++  fetch
  |=  url=@t
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  ~  bind:m  (send-request:io [%'GET' url ~ ~])
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now ~s15)
  ;<  ~  bind:m  (set-timer:io /fetch-timeout/(scot %da until) until)
  ;<  resp=(unit client-response:iris)  bind:m  (take-response-or-timeout until)
  ?~  resp  (pure:m ~)
  ?.  ?=(%finished -.u.resp)  (pure:m ~)
  ?:  (gte status-code.response-header.u.resp 400)  (pure:m ~)
  ?~  full-file.u.resp  (pure:m ~)
  (pure:m `q.data.u.full-file.u.resp)
::  WMO weather interpretation codes, coarsely grouped
::
++  wmo-word
  |=  code=@t
  ^-  @t
  ?+  code  'weather'
    %'0'   'clear'
    ?(%'1' %'2')  'partly cloudy'
    %'3'   'overcast'
    ?(%'45' %'48')  'fog'
    ?(%'51' %'53' %'55' %'56' %'57')  'drizzle'
    ?(%'61' %'63' %'65' %'66' %'67')  'rain'
    ?(%'71' %'73' %'75' %'77')  'snow'
    ?(%'80' %'81' %'82')  'showers'
    ?(%'85' %'86')  'snow showers'
    ?(%'95' %'96' %'99')  'thunderstorm'
  ==
::
++  wmo-color
  |=  code=@t
  ^-  @t
  ?+  code  '#4a90d9'
    %'0'   '#4a90d9'
    ?(%'1' %'2')  '#6b93b8'
    %'3'   '#7d8791'
    ?(%'45' %'48')  '#9aa0a6'
    ?(%'51' %'53' %'55' %'56' %'57' %'61' %'63' %'65' %'66' %'67' %'80' %'81' %'82')  '#4a6fa5'
    ?(%'71' %'73' %'75' %'77' %'85' %'86')  '#8fa8c9'
    ?(%'95' %'96' %'99')  '#5b4bb5'
  ==
--
