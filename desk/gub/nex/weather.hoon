::  weather nexus: current conditions and forecasts from open-meteo
::
::  Locations are configured by place name; adding one geocodes it
::  through open-meteo's free geocoding API and stores name + lat +
::  lon. The refresh loop fetches every location's forecast on a
::  timer (any poke refreshes immediately), stores the full API
::  response per location, and rewrites the nexus's own tile.json so
::  the shell tile shows live conditions for the first location.
::
::  /config.json      {units: 'c'|'f', locations: [{name, lat, lon}, ...]}
::  /weather.json     { <name>: {loc, resp, at} }
::  /refresh.sig      fetch loop: all locations every 30m; any poke
::  /main.sig         HTTP at /grubbery/weather
::    GET  /data      config + weather as one json
::    POST /add       {"name": "stockholm"} — geocode and add
::    POST /del       {"name": "..."}
::    POST /units     {"units": "c" | "f"}
::    POST /refresh
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
          [%fall %& [/ %'weather.json'] [[/ %json] [%o ~]]]
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
          ::  refresh.sig: fetch all locations, sleep, repeat.
          ::  Timer wakes and direct pokes both mean refresh now.
          ::
          [~ %'refresh.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%weather /refresh: failed")
        |-
        ;<  ~  bind:m  (refresh-all rail)
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (send-wait:io (add now ~m30))
        ;<  ~  bind:m  take-any-poke
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
            ;<  ~  bind:m  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'added')])
            (pure:m ~)
              [%del ~]
            =/  name=@t  (jstr jon 'name')
            ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
            ;<  ~  bind:m
              (write-config rail units (skip locs |=(l=json =(name (jstr l 'name')))))
            ;<  ~  bind:m  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'deleted')])
            (pure:m ~)
              [%units ~]
            =/  units=@t  (jstr jon 'units')
            ?.  |(=('c' units) =('f' units))
              ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'units must be c or f')])
              (pure:m ~)
            ;<  [old=@t locs=(list json)]  bind:m  (read-config rail)
            ;<  ~  bind:m  (write-config rail units locs)
            ;<  ~  bind:m  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              [%refresh ~]
            ;<  ~  bind:m  (poke:io (nex-road:io rail [%& ~ %'refresh.sig']) [[/ %sig] ~])
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
          ==
        ?:  ?=([%data ~] suffix)
          ;<  cfg=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& ~ %'config.json']) ,json)
          ;<  wx=(unit json)  bind:m
            (peek-as:io (nex-road:io rail [%& ~ %'weather.json']) ,json)
          =/  cfg-j=json  (fall cfg [%a ~])
          =/  out=json
            %-  pairs:enjs:format
            :~  ['units' s+?:(&(?=(%o -.cfg-j) =('f' (jstr cfg-j 'units'))) 'f' 'c')]
                :-  'locations'
                ?:  ?=(%a -.cfg-j)  cfg-j
                ?.  ?=(%o -.cfg-j)  [%a ~]
                (fall (~(get by p.cfg-j) 'locations') [%a ~])
                ['weather' (fall wx [%o ~])]
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
::  +geocode: place name -> {name, lat, lon} via open-meteo, taking
::  the first match. lat/lon keep the API's number literals as text.
::
++  geocode
  |=  name=@t
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  url=@t
    %+  rap  3
    :~  'https://geocoding-api.open-meteo.com/v1/search?count=1&name='
        name
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
::  +refresh-all: fetch every location's forecast, store the lot,
::  and rewrite the tile from the first location's current weather
::
++  refresh-all
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [units=@t locs=(list json)]  bind:m  (read-config rail)
  ;<  now=@da  bind:m  get-time:io
  =|  out=(list [@t json])
  |-
  ?~  locs
    =.  out  (flop out)
    ;<  ~  bind:m
      (over:io (nex-road:io rail [%& ~ %'weather.json']) [[/ %json] `json`o+(malt out)])
    (update-tile rail out)
  =/  loc=json  i.locs
  =/  name=@t  (jstr loc 'name')
  ;<  resp=(unit json)  bind:m
    (fetch-forecast (jstr loc 'lat') (jstr loc 'lon') units)
  ?~  resp
    ~&  >>  [%weather-fetch-failed name]
    $(locs t.locs)
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['loc' loc]
        ['resp' u.resp]
        ['at' s+(scot %da now)]
    ==
  $(locs t.locs, out [[name entry] out])
::
++  fetch-forecast
  |=  [lat=@t lon=@t units=@t]
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
        ?:  =('f' units)
          '&temperature_unit=fahrenheit&wind_speed_unit=mph'
        ''
    ==
  ;<  bod=(unit @t)  bind:m  (fetch url)
  %-  pure:m
  ?~  bod  ~
  (de:json:html u.bod)
::
++  fetch
  |=  url=@t
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  ~  bind:m  (send-request:io [%'GET' url ~ ~])
  ;<  resp=client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.resp)  (pure:m ~)
  ?:  (gte status-code.response-header.resp 400)  (pure:m ~)
  ?~  full-file.resp  (pure:m ~)
  (pure:m `q.data.u.full-file.resp)
::  +update-tile: live tile — first location's current temp and
::  conditions become the shell tile's info and color
::
++  update-tile
  |=  [=rail:tarball out=(list [@t json])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  tile=json
    ?~  out  default-tile
    =/  [name=@t entry=json]  i.out
    =/  resp=json
      ?.  ?=(%o -.entry)  [%o ~]
      (fall (~(get by p.entry) 'resp') [%o ~])
    =/  cur=json
      ?.  ?=(%o -.resp)  [%o ~]
      (fall (~(get by p.resp) 'current') [%o ~])
    =/  temp=@t  (jnumt cur 'temperature_2m')
    =/  code=@t  (jnumt cur 'weather_code')
    ?:  =('' temp)  default-tile
    %-  pairs:enjs:format
    :~  title+s+'Weather'
        info+s+(rap 3 temp '° ' (wmo-word code) ' — ' name ~)
        color+s+(wmo-color code)
        image+s+'/grubbery/tiles/icon/weather.weather'
        href+s+'/grubbery/weather'
    ==
  (over:io (nex-road:io rail [%& ~ %'tile.json']) [[/ %json] tile])
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
