::  itinerary nexus: travel maps with pins and metadata
::
::  Each itinerary is a single JSON file under /itineraries/.
::  The backend handles pin CRUD by modifying the document server-side.
::
/&  index-html  itinerary/index.html
/&  app-js      itinerary/app.js
/&  style-css   itinerary/style.css
/&  icon        itinerary/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Itinerary'
            info+s+'Travel maps & pins'
            color+s+'#27ae60'
            image+s+'/grubbery/tiles/icon/itinerary'
            href+s+'/grubbery/itinerary'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] style-css]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /itineraries empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%itinerary main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/itinerary])
        (http-dispatch:io %itinerary)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%itinerary request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /grubbery/itinerary
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        =/  method=@t  method.request.req
        ::
        ::  static files: GET /, /app.js, /style.css
        ::
        ?:  ?&  =(%'GET' method)
                ?|  =(~ suffix)
                    =([%'app.js' ~] suffix)
                    =([%'style.css' ~] suffix)
                ==
            ==
          =/  filename=@ta
            ?~  suffix  'index.html'
            i.suffix
          (serve-file eyre-id filename)
        ::
        ::  GET /api/list — list all itineraries
        ::
        ?:  ?&(=(%'GET' method) =([%api %list ~] suffix))
          (list-itineraries eyre-id)
        ::
        ::  GET /api/i/[id] — get itinerary
        ::
        ?:  ?&(=(%'GET' method) ?=([%api %i @ ~] suffix))
          (get-itinerary eyre-id i.t.t.suffix)
        ::
        ::  PUT /api/i/[id] — create or replace itinerary
        ::
        ?:  ?&(=(%'PUT' method) ?=([%api %i @ ~] suffix))
          (put-itinerary eyre-id i.t.t.suffix req)
        ::
        ::  DELETE /api/i/[id] — delete itinerary
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %i @ ~] suffix))
          (del-itinerary eyre-id i.t.t.suffix)
        ::
        ::  PUT /api/i/[id]/pin/[pin-id] — add or update pin
        ::
        ?:  ?&(=(%'PUT' method) ?=([%api %i @ %pin @ ~] suffix))
          (put-pin eyre-id i.t.t.suffix i.t.t.t.t.suffix req)
        ::
        ::  DELETE /api/i/[id]/pin/[pin-id] — delete pin
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %i @ %pin @ ~] suffix))
          (del-pin eyre-id i.t.t.suffix i.t.t.t.t.suffix)
        ::
        ::  404
        ::
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  itin-road
  |=  itin-id=@ta
  ^-  road:tarball
  [%| 1 %& /itineraries (cat 3 itin-id '.json')]
::
++  serve-file
  |=  [eyre-id=@ta filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io [%| 1 %& / filename] `[/ %mime])
  ?.  ?=([%& %file *] seen)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.p.seen))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
  (pure:m ~)
::
++  send-json
  |=  [eyre-id=@ta body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
::
++  get-body
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
::
++  strip-ext
  |=  name=@ta
  ^-  @t
  =/  parts=(list tape)  (rash name (more dot (star ;~(less dot prn))))
  ?~  parts  name
  (crip i.parts)
::
::  +load-itinerary: read an itinerary file, return its json
::
++  load-itinerary
  |=  itin-id=@ta
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io (itin-road itin-id) `[/ %json])
  ?.  ?=([%& %file *] seen)
    (pure:m ~)
  ?:  (is-boom:tarball sang.p.seen)
    (pure:m ~)
  =/  jon=json  !<(json (need-vase:tarball sang.p.seen))
  (pure:m `jon)
::
::  +save-itinerary: write an itinerary file
::
++  save-itinerary
  |=  [itin-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (itin-road itin-id) [[/ %json] jon])
::
::  +list-itineraries: return [{id, name}, ...] for all itineraries
::
++  list-itineraries
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dir-seen=seen:nexus  bind:m  (peek:io [%| 1 %| /itineraries] ~)
  ?.  ?=([%& %ball *] dir-seen)
    ;<  ~  bind:m  (send-json eyre-id '[]')
    (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.p.dir-seen *lump:tarball)
  =/  entries=(list json)
    %+  murn  ~(tap by contents.lump)
    |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
    ?.  =(%json name.p.sang)  ~
    ?:  (is-boom:tarball sang)  ~
    =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang))))
    ?~  jon  ~
    =/  id=@t  (strip-ext name)
    =/  itin-name=@t
      ?.  ?=([%o *] u.jon)  id
      =/  n=(unit json)  (~(get by p.u.jon) 'name')
      ?~  n  id
      ?.  ?=([%s @] u.n)  id
      p.u.n
    `(pairs:enjs:format ~[['id' s+id] ['name' s+itin-name]])
  ;<  ~  bind:m  (send-json eyre-id (en:json:html a+entries))
  (pure:m ~)
::
::  +get-itinerary: return full itinerary document
::
++  get-itinerary
  |=  [eyre-id=@ta itin-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  jon=(unit json)  bind:m  (load-itinerary itin-id)
  ?~  jon
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  ;<  ~  bind:m  (send-json eyre-id (en:json:html u.jon))
  (pure:m ~)
::
::  +put-itinerary: write full itinerary document
::
++  put-itinerary
  |=  [eyre-id=@ta itin-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=(unit json)  (get-body req)
  ?~  jon
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
    (pure:m ~)
  ;<  ~  bind:m  (save-itinerary itin-id u.jon)
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
  (pure:m ~)
::
::  +del-itinerary: delete itinerary file
::
++  del-itinerary
  |=  [eyre-id=@ta itin-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (cull-soft:io (itin-road itin-id))
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
  (pure:m ~)
::
::  +put-pin: add or update a pin within an itinerary
::
++  put-pin
  |=  [eyre-id=@ta itin-id=@ta pin-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  pin-jon=(unit json)  (get-body req)
  ?~  pin-jon
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
    (pure:m ~)
  ;<  existing=(unit json)  bind:m  (load-itinerary itin-id)
  ?~  existing
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Itinerary not found')])
    (pure:m ~)
  ?.  ?=([%o *] u.existing)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Bad itinerary format')])
    (pure:m ~)
  =/  old-pins=(map @t json)
    =/  p=(unit json)  (~(get by p.u.existing) 'pins')
    ?.  ?=([~ %o *] p)  ~
    p.u.p
  =/  new-pins=(map @t json)  (~(put by old-pins) pin-id u.pin-jon)
  =/  updated=json  [%o (~(put by p.u.existing) 'pins' [%o new-pins])]
  ;<  ~  bind:m  (save-itinerary itin-id updated)
  ;<  ~  bind:m  (send-json eyre-id (en:json:html updated))
  (pure:m ~)
::
::  +del-pin: remove a pin from an itinerary
::
++  del-pin
  |=  [eyre-id=@ta itin-id=@ta pin-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  existing=(unit json)  bind:m  (load-itinerary itin-id)
  ?~  existing
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Itinerary not found')])
    (pure:m ~)
  ?.  ?=([%o *] u.existing)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Bad itinerary format')])
    (pure:m ~)
  =/  old-pins=(map @t json)
    =/  p=(unit json)  (~(get by p.u.existing) 'pins')
    ?.  ?=([~ %o *] p)  ~
    p.u.p
  =/  new-pins=(map @t json)  (~(del by old-pins) pin-id)
  =/  updated=json  [%o (~(put by p.u.existing) 'pins' [%o new-pins])]
  ;<  ~  bind:m  (save-itinerary itin-id updated)
  ;<  ~  bind:m  (send-json eyre-id (en:json:html updated))
  (pure:m ~)
--
