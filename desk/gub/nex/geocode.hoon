::  geocode nexus: OSM geocoding proxy (Nominatim search + reverse).
::
::  Calls protocol, same shape as the anthropic proxy: poke main.sig
::  with {id, kind, ...}; the result lands at calls/<id>.json as
::  {status: 'done', response}. Kinds:
::    search:       {id, kind: 'search', query, limit?, polygon?, featuretype?}
::    reverse:      {id, kind: 'reverse', lat, lon}
::    autocomplete: {id, kind: 'autocomplete', query, lat?, lon?} — Photon,
::                  built for search-as-you-type (Nominatim policy forbids
::                  autocomplete traffic); lat/lon bias results near a point
::
::  Every result is cached forever under /cache keyed on the request
::  url (Nominatim's usage policy asks for caching; repeat lookups
::  never leave the ship). The single fiber serializes fetches, which
::  keeps us naturally under Nominatim's 1 req/s.
::
/&  ui-html   geocode/index.html
/&  ui-js     geocode/app.js
/&  ui-css    geocode/style.css
/&  ui-icon   geocode/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  weir-json=json
        %-  pairs:enjs:format
        :~  :-  'poke'
            :-  %a
            :~  (pairs:enjs:format ~[['road' s+'/sys/bowl.sig'] ['why' s+'time, identity, entropy — every fiber op']])
                (pairs:enjs:format ~[['road' s+'/sys/behn/'] ['why' s+'fetch timeout alarms']])
                (pairs:enjs:format ~[['road' s+'/sys/iris/'] ['why' s+'fetch from the OSM geocoding APIs']])
                (pairs:enjs:format ~[['road' s+'/sys/eyre/'] ['why' s+'serve the dashboard over HTTP']])
            ==
        ==
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['user-agent' s+'grubbery-geocode/1 (personal urbit ship)']
            ['search-url' s+'https://nominatim.openstreetmap.org/search']
            ['reverse-url' s+'https://nominatim.openstreetmap.org/reverse']
            ['autocomplete-url' s+'https://photon.komoot.io/api/']
        ==
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Geocode'
            info+s+'OSM geocoding proxy, cached'
            color+s+'#16a085'
            image+s+'/grubbery/geocode/icon.svg'
            href+s+'/grubbery/geocode'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'geocode'] ['description' s+'OSM geocoding proxy (Nominatim search/reverse), cached']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %| /calls empty-dir:loader]
          [%fall %| /cache empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%geocode main: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ;<  ~  bind:m  (handle-call rail jon)
        $
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%geocode web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/geocode])
        (http-dispatch:io %geocode)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%geocode req: failed")
        (serve rail name.rail)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  +serve: the dashboard. Static shell + api:
::    GET /api/info                       {config, cache, calls}
::    GET /api/test?kind=&q=&lat=&lon=... one lookup, straight through
::                                        (cached like any other)
++  serve
  |=  [=rail:tarball eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/geocode
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %info ~]
    ;<  cfg=json  bind:m  (read-config-at rail)
    ;<  cachev=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /cache]) ~)
    ;<  callsv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /calls]) ~)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['config' cfg]
        ['cache' (numb:enjs:format (count-files cachev))]
        ['calls' (numb:enjs:format (count-files callsv))]
    ==
  ::
      [%api %test ~]
    =/  gq
      |=  key=@t
      ^-  @t
      (fall (~(get by (malt args)) key) '')
    =/  jon=json
      %-  pairs:enjs:format
      :~  ['kind' s+(gq 'kind')]
          ['query' s+(gq 'q')]
          ['lat' s+(gq 'lat')]
          ['lon' s+(gq 'lon')]
          ['polygon' s+(gq 'polygon')]
          ['featuretype' s+(gq 'featuretype')]
      ==
    ;<  cfg=json  bind:m  (read-config-at rail)
    ;<  res=json  bind:m  (lookup rail cfg (gq 'kind') jon)
    (send-json eyre-id res)
  ==
::
++  serve-static
  |=  [eyre-id=@ta suffix=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
  ?.  ?=(?(%'index.html' %'app.js' %'style.css' %'icon.svg') filename)
    (reply eyre-id 404 'Not found')
  ;<  v=view:nexus  bind:m  (peek:io [%| 1 %& ~ filename] `[/ %mime])
  ?.  ?=([%file *] v)  (reply eyre-id 404 'Not found')
  =/  =mime  !<(mime (need-vase:tarball sang.v))
  (send-simple:srv eyre-id (mime-response:http-utils mime))
::
++  reply
  |=  [eyre-id=@ta code=@ud msg=@t]
  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html msg)])
::
++  send-json
  |=  [eyre-id=@ta jon=json]
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
::
++  count-files
  |=  =view:nexus
  ^-  @ud
  ?.  ?=([%ball *] view)  0
  ?~  fil.ball.view  0
  ~(wyt by contents.u.fil.ball.view)
::  +read-config-at: config from an arbitrary fiber's rail (the main
::  loop and request fibers sit at different depths).
++  read-config-at
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  cfg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& ~ %'config.json']) ,json)
  (pure:m (fall cfg [%o ~]))
::  +handle-call: one geocode request — cache hit or fetch, then
::  write the result grub the caller is watching.
::
++  handle-call
  |=  [=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=@t  (jstr jon 'id')
  ?:  =('' id)  (pure:m ~)
  =/  kind=@t  (jstr jon 'kind')
  ;<  cfg=json  bind:m  (read-config rail)
  ;<  res=json  bind:m  (lookup rail cfg kind jon)
  (write-call rail id res)
::  +lookup: cache hit or live fetch for one request; the cache is
::  keyed on the full request url. Shared by the calls protocol and
::  the dashboard's /api/test.
::
++  lookup
  |=  [=rail:tarball cfg=json kind=@t jon=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  url=(unit @t)  (build-url cfg kind jon)
  ?~  url
    (pure:m (pairs:enjs:format ~[['error' s+'bad request: need kind search/autocomplete {query} or reverse {lat, lon}']]))
  =/  cache-name=@ta  (crip "{(scow %ux (mug u.url))}.json")
  =/  cache-road=road:tarball  (nex-road:io rail [%& /cache cache-name])
  ;<  hit=(unit json)  bind:m  (peek-as:io cache-road ,json)
  ?^  hit
    (pure:m u.hit)
  =/  ua=@t  (jstr cfg 'user-agent')
  ;<  bod=(unit @t)  bind:m  (fetch-retry u.url ua)
  ?~  bod
    (pure:m (pairs:enjs:format ~[['error' s+'fetch failed']]))
  =/  resp=(unit json)  (de:json:html u.bod)
  ?~  resp
    (pure:m (pairs:enjs:format ~[['error' s+'bad response json']]))
  ;<  err=(unit tang)  bind:m  (make-soft:io cache-road |+[[[/ %json] u.resp] ~])
  (pure:m u.resp)
::  +write-call: land the result at calls/<id>.json (make or overwrite)
::
++  write-call
  |=  [=rail:tarball id=@t response=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  call-road=road:tarball
    (nex-road:io rail [%& /calls (crip "{(trip id)}.json")])
  =/  result=json
    (pairs:enjs:format ~[['status' s+'done'] ['response' response]])
  ;<  err=(unit tang)  bind:m  (make-soft:io call-road |+[[[/ %json] result] ~])
  ?~  err  (pure:m ~)
  (over:io call-road [[/ %json] result])
::  +build-url: request url for a call, with the query DOUBLE
::  percent-encoded — vere's cttp.c decodes %XX parsing the url and
::  never re-encodes, so a single %20 goes out as a literal space
::  (grep "cttp"; pattern from weather.hoon +geocode-search).
::
++  build-url
  |=  [cfg=json kind=@t jon=json]
  ^-  (unit @t)
  ?:  =('search' kind)
    =/  query=@t  (jstr jon 'query')
    ?:  =('' query)  ~
    =/  limit=@t  =/(l (jstr jon 'limit') ?:(=('' l) '6' l))
    =/  poly=?  =('true' (jstr jon 'polygon'))
    =/  ftype=@t  (jstr jon 'featuretype')
    %-  some
    %+  rap  3
    :~  (jstr cfg 'search-url')
        '?format=jsonv2&addressdetails=1&limit='
        limit
        ?:(poly '&polygon_geojson=1' '')
        ?:  =('' ftype)  ''
        (rap 3 ~['&featureType=' ftype])
        '&q='
        (crip (double-enc query))
    ==
  ?:  =('autocomplete' kind)
    =/  query=@t  (jstr jon 'query')
    ?:  =('' query)  ~
    =/  lat=@t  (jstr jon 'lat')
    =/  lon=@t  (jstr jon 'lon')
    %-  some
    %+  rap  3
    :~  (jstr cfg 'autocomplete-url')
        '?limit=6&q='
        (crip (double-enc query))
        ?:  |(=('' lat) =('' lon))  ''
        (rap 3 ~['&lat=' lat '&lon=' lon])
    ==
  ?:  =('reverse' kind)
    =/  lat=@t  (jstr jon 'lat')
    =/  lon=@t  (jstr jon 'lon')
    ?:  |(=('' lat) =('' lon))  ~
    %-  some
    %+  rap  3
    :~  (jstr cfg 'reverse-url')
        '?format=jsonv2&addressdetails=1&lat='
        lat
        '&lon='
        lon
    ==
  ~
::  +double-enc: DOUBLE percent-encode a value for an outbound url
::  (vere cttp bug — see +build-url comment)
::
++  double-enc
  |=  v=@t
  ^-  tape
  %-  zing
  %+  turn  (en-urlt:html (trip v))
  |=(c=@tD ?:(=('%' c) "%25" (trip c)))
::  +fetch-retry: one immediate retry; transient timeouts are common
::
++  fetch-retry
  |=  [url=@t ua=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  a=(unit @t)  bind:m  (fetch url ua)
  ?^  a  (pure:m a)
  (fetch url ua)
::  +fetch: GET with our User-Agent (Nominatim requires one) and our
::  own ~s15 deadline, so a timeout returns ~ instead of the fiber
::  dying on vere's runtime cutoff. Pattern from weather.hoon +fetch.
::
++  fetch
  |=  [url=@t ua=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  ~  bind:m  (send-request:io [%'GET' url ~[['user-agent' ua]] ~])
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now ~s15)
  ;<  ~  bind:m  (set-timer:io /fetch-timeout/(scot %da until) until)
  ;<  resp=(unit client-response:iris)  bind:m  (take-response-or-timeout until)
  ?~  resp  (pure:m ~)
  ?.  ?=(%finished -.u.resp)  (pure:m ~)
  ?:  (gte status-code.response-header.u.resp 400)  (pure:m ~)
  ?~  full-file.u.resp  (pure:m ~)
  (pure:m `q.data.u.full-file.u.resp)
::  +take-response-or-timeout: the response, or ~ when our alarm
::  fires first (or iris cancels). Pattern from weather.hoon.
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
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  cfg=(unit json)  bind:m
    (peek-as:io (nex-road:io rail [%& ~ %'config.json']) ,json)
  (pure:m (fall cfg [%o ~]))
::  +jstr: a json object's string field, or ''
::
++  jstr
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v=(unit json)  (~(get by p.jon) key)
  ?:(?=([~ %s *] v) p.u.v '')
--
