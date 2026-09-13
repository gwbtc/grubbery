::  places nexus: imported POI datasets, one city per grub.
::
::  Cities live under /cities as JSON grubs produced by
::  scripts/extract-places.py (Overture Maps extracts):
::  {city, bbox, release, count, places: [{name, cat, lat, lng,
::  conf, addr}]}. The itinerary search box reads these client-side
::  for instant, confidence-ranked local search.
::
::    GET  /                 the upload/browse page
::    GET  /api/cities       [{id, city, count, bbox}]
::    GET  /api/city/[id]    the full extract
::    PUT  /api/city/[id]    store an extract (body = the JSON)
::    DELETE /api/city/[id]
::
/&  ui-html   places/index.html
/&  ui-js     places/app.js
/&  ui-css    places/style.css
/&  ui-icon   places/icon.svg
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
                (pairs:enjs:format ~[['road' s+'/sys/eyre/'] ['why' s+'serve the page and city data over HTTP']])
            ==
        ==
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Places'
            info+s+'Imported POI datasets'
            color+s+'#8e6bbf'
            image+s+'/grubbery/places/icon.svg'
            href+s+'/grubbery/places'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'places'] ['description' s+'Imported POI datasets (Overture city extracts)']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /cities empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%places main: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/places])
        (http-dispatch:io %places)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%places req: failed")
        (serve rail name.rail)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
++  serve
  |=  [=rail:tarball eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/places
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  =/  method=@t  method.request.req
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %cities ~]
    ;<  dirv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /cities]) ~)
    =/  entries
      ?.  ?=([%ball *] dirv)  ~
      ?~  fil.ball.dirv  ~
      ~(tap by contents.u.fil.ball.dirv)
    =/  out=(list json)
      %+  murn  entries
      |=  [nam=@ta ent=[=sang:tarball *]]
      ^-  (unit json)
      =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang.ent))))
      ?~  jon  ~
      ?.  ?=([%o *] u.jon)  ~
      =/  strip=@t  (strip-ext nam)
      %-  some
      %-  pairs:enjs:format
      :~  ['id' s+strip]
          ['city' (fall (~(get by p.u.jon) 'city') s+strip)]
          ['count' (fall (~(get by p.u.jon) 'count') (numb:enjs:format 0))]
          ['bbox' (fall (~(get by p.u.jon) 'bbox') [%a ~])]
      ==
    (send-json eyre-id [%a out])
  ::
      [%api %city @ ~]
    =/  id=@ta  i.t.t.suffix
    =/  city-road=road:tarball
      (nex-road:io rail [%& /cities (crip "{(trip id)}.json")])
    ?:  =('PUT' method)
      =/  jon=(unit json)
        (de:json:html ?~(body.request.req '' q.u.body.request.req))
      ?.  ?&(?=(^ jon) ?=([%o *] u.jon))  (reply eyre-id 400 'Bad JSON')
      ;<  err=(unit tang)  bind:m  (make-soft:io city-road |+[[[/ %json] u.jon] ~])
      ;<  ~  bind:m
        ?~  err  (pure:m ~)
        (over:io city-road [[/ %json] u.jon])
      (send-json eyre-id (pairs:enjs:format ~[['ok' [%b %.y]]]))
    ?:  =('DELETE' method)
      ;<  *  bind:m  (cull-soft:io city-road)
      (send-json eyre-id (pairs:enjs:format ~[['ok' [%b %.y]]]))
    ;<  cv=(unit json)  bind:m  (peek-as:io city-road ,json)
    ?~  cv  (reply eyre-id 404 'No such city')
    (send-json eyre-id u.cv)
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
++  strip-ext
  |=  name=@ta
  ^-  @t
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".json" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
--
