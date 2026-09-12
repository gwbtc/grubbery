::  itinerary nexus: travel maps with pins, zones and metadata
::
::  Each itinerary lives as one JSON file under /itineraries/.
::  The backend handles pin and zone CRUD by modifying the document
::  server-side, behind the eyre boundary.
::
/&  index-html  itinerary/index.html
/&  app-js      itinerary/app.js
/&  style-css   itinerary/style.css
/&  icon        itinerary/icon.svg
/<  chat-js     itinerary/chat.js
/<  chat-css    itinerary/chat.css
/<  marked-js   itinerary/marked.min.js
::  shared web components from /lib/ui (see web-test.hoon for the pattern)
/&  sv-js       /lib/ui/split-view.js
/&  tg-js       /lib/ui/tab-group.js
/&  dm-js       /lib/ui/drop-menu.js
/&  md-js       /lib/ui/modal-dialog.js
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
        (rap 3 ~[(wrap sv-js) (wrap tg-js) (wrap dm-js) (wrap md-js)])
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Itinerary'
            info+s+'Travel maps & pins'
            color+s+'#27ae60'
            ::  full folder name, not the slug
            ::  also slugs to 'itinerary', wins the scan, and 404s
            image+s+'/grubbery/tiles/icon/itinerary.itinerary'
            href+s+'/grubbery/itinerary'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'itinerary'] ['description' s+'Travel maps with pins']])]]
          [%over %& [/ %'weir.json'] [[/ %json] (pairs:enjs:format ~[['poke' a+~[(pairs:enjs:format ~[['road' s+'/sys/bowl.sig'] ['why' s+'time, identity, entropy — every fiber op']]) (pairs:enjs:format ~[['road' s+'/sys/eyre/'] ['why' s+'serve its page over HTTP']]) (pairs:enjs:format ~[['road' s+'/apps/geocode.geocode/main.sig'] ['why' s+'map search box geocoding']])]]])]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] style-css]]
          [%fall %| /ui empty-dir:loader]
          [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /itineraries empty-dir:loader]
          ::  the itinerary agent: a contained, sandboxed chatbot nexus
          ::  (code at nex/itinerary/agent.hoon), following the docs-agent
          ::  pattern. Its weir grants it the itineraries documents and the
          ::  metered anthropic proxy — nothing else.
          [%fall %| /agent [`[`[/itinerary %agent] `agent-weir %.n ~] ~]]
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
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/itinerary])
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
                    =([%'icon.svg' ~] suffix)
                ==
            ==
          =/  filename=@ta
            ?~  suffix  'index.html'
            i.suffix
          (serve-file eyre-id / filename)
        ::
        ::  GET /ui/components.js — welded web-component bundle
        ::
        ?:  ?&(=(%'GET' method) =([%ui %'components.js' ~] suffix))
          (serve-file eyre-id /ui 'components.js')
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
          (put-entry eyre-id i.t.t.suffix 'pins' i.t.t.t.t.suffix req)
        ::
        ::  DELETE /api/i/[id]/pin/[pin-id] — delete pin
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %i @ %pin @ ~] suffix))
          (del-entry eyre-id i.t.t.suffix 'pins' i.t.t.t.t.suffix)
        ::
        ::  PUT /api/i/[id]/zone/[zone-id] — add or update zone
        ::
        ?:  ?&(=(%'PUT' method) ?=([%api %i @ %zone @ ~] suffix))
          (put-entry eyre-id i.t.t.suffix 'zones' i.t.t.t.t.suffix req)
        ::
        ::  DELETE /api/i/[id]/zone/[zone-id] — delete zone
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %i @ %zone @ ~] suffix))
          (del-entry eyre-id i.t.t.suffix 'zones' i.t.t.t.t.suffix)
        ::
        ::  GET /api/geocode?kind=...&q=...&lat=...&lon=... — bridge the
        ::  map search box to the geocode nexus (calls protocol).
        ::
        ?:  ?&(=(%'GET' method) =([%api %geocode ~] suffix))
          =/  gq
            |=  key=@t
            ^-  @t
            =/  v  (~(get by (malt args)) key)
            (fall v '')
          ;<  resp=json  bind:m
            %:  ask-geocode  rail
                (gq 'kind')
                (gq 'q')
                (gq 'lat')
                (gq 'lon')
                (gq 'polygon')
                (gq 'featuretype')
                (gq 'tag')
                (gq 'radius')
            ==
          (send-json eyre-id (en:json:html resp))
        ::
        ::  chat widget assets
        ::
        ?:  ?=([%'chat.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.chat-js])
          (pure:m ~)
        ?:  ?=([%'chat.css' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/css']]] `q.chat-css])
          (pure:m ~)
        ?:  ?=([%'marked.min.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.marked-js])
          (pure:m ~)
        ::
        ::  POST /chat → the itinerary assistant. Returns {reply, trace}.
        ::
        ?:  &(=('POST' method) ?=([%chat ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  msg=@t  (fall (jget jon 'message') '')
          ;<  [reply=@t trace=json parts=json]  bind:m  (ask-agent rail msg)
          (send-json eyre-id (en:json:html (pairs:enjs:format ~[['reply' s+reply] ['trace' trace] ['parts' parts]])))
        ::
        ::  GET /history → the stored conversation from the agent's chat.json
        ::
        ?:  ?=([%history ~] suffix)
          =/  chat-road=road:tarball
            (nex-road:io rail [%& /agent %'chat.json'])
          ;<  fv=view:nexus  bind:m  (peek:io chat-road `[/ %json])
          =/  conv=json
            ?.  ?=([%file *] fv)  [%a ~]
            (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) [%a ~])
          (send-json eyre-id (en:json:html conv))
        ::
        ::  POST /clear → archive + reset the conversation
        ::
        ?:  &(=('POST' method) ?=([%clear ~] suffix))
          ;<  ~  bind:m
            %-  poke:io
            :+  (nex-road:io rail [%& /agent %'main.sig'])
              [/ %json]
            (pairs:enjs:format ~[['action' s+'clear']])
          (send-json eyre-id '{"ok":true}')
        ::
        ::  POST /stop → interrupt the agent's current turn
        ::
        ?:  &(=('POST' method) ?=([%stop ~] suffix))
          ;<  ~  bind:m
            %-  poke:io
            :+  (nex-road:io rail [%& /agent %'main.sig'])
              [/ %json]
            (pairs:enjs:format ~[['action' s+'interrupt']])
          (send-json eyre-id '{"ok":true}')
        ::
        ::  POST /config {system, model, max_tokens} → write the agent's grubs
        ::
        ?:  &(=('POST' method) ?=([%config ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  po=(map @t json)  ?:(?=([%o *] jon) p.jon ~)
          =/  sys=@t    (fall (jget jon 'system') '')
          =/  model=@t  =/(mo=@t (fall (jget jon 'model') '') ?:(=('' mo) 'claude-sonnet-4-6' mo))
          =/  mt=json   (fall (~(get by po) 'max_tokens') [%n '1024'])
          ;<  ~  bind:m
            %-  over:io
            :-  (nex-road:io rail [%& /agent %'system.md'])
            [[/ %mime] [/text/markdown (as-octs:mimes:html sys)]]
          ;<  ~  bind:m
            %-  over:io
            :-  (nex-road:io rail [%& /agent %'config.json'])
            [[/ %json] (pairs:enjs:format ~[['model' s+model] ['max_tokens' mt]])]
          (send-json eyre-id '{"ok":true}')
        ::
        ::  GET /config → the agent's current prompt + model config
        ::
        ?:  ?=([%config ~] suffix)
          ;<  sv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /agent %'system.md']) `[/ %mime])
          =/  sys=@t
            ?.  ?=([%file *] sv)  ''
            `@t`q.q:!<(mime (need-vase:tarball sang.sv))
          ;<  cv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /agent %'config.json']) `[/ %json])
          =/  cfg=json
            ?.  ?=([%file *] cv)  [%o ~]
            (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) [%o ~])
          (send-json eyre-id (en:json:html (pairs:enjs:format ~[['system' s+sys] ['config' cfg]])))
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
  |=  [eyre-id=@ta dir=path filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %& dir filename] `[/ %mime])
  ?.  ?=([%file *] view)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.view))
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
  ;<  =view:nexus  bind:m  (peek:io (itin-road itin-id) `[/ %json])
  ?.  ?=([%file *] view)
    (pure:m ~)
  ?:  (is-boom:tarball sang.view)
    (pure:m ~)
  =/  jon=json  !<(json (need-vase:tarball sang.view))
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
  ;<  dir-view=view:nexus  bind:m  (peek:io [%| 1 %| /itineraries] ~)
  ?.  ?=([%ball *] dir-view)
    ;<  ~  bind:m  (send-json eyre-id '[]')
    (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.dir-view *lump:tarball)
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
::  +put-entry: add or update an entry (pin or zone) within an itinerary
::
++  put-entry
  |=  [eyre-id=@ta itin-id=@ta field=@t entry-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  entry-jon=(unit json)  (get-body req)
  ?~  entry-jon
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
    (pure:m ~)
  ;<  existing=(unit json)  bind:m  (load-itinerary itin-id)
  ?~  existing
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Itinerary not found')])
    (pure:m ~)
  ?.  ?=([%o *] u.existing)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Bad itinerary format')])
    (pure:m ~)
  =/  old-entries=(map @t json)
    =/  p=(unit json)  (~(get by p.u.existing) field)
    ?.  ?=([~ %o *] p)  ~
    p.u.p
  =/  new-entries=(map @t json)  (~(put by old-entries) entry-id u.entry-jon)
  =/  updated=json  [%o (~(put by p.u.existing) field [%o new-entries])]
  ;<  ~  bind:m  (save-itinerary itin-id updated)
  ;<  ~  bind:m  (send-json eyre-id (en:json:html updated))
  (pure:m ~)
::
::  +del-entry: remove an entry (pin or zone) from an itinerary
::
++  del-entry
  |=  [eyre-id=@ta itin-id=@ta field=@t entry-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  existing=(unit json)  bind:m  (load-itinerary itin-id)
  ?~  existing
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Itinerary not found')])
    (pure:m ~)
  ?.  ?=([%o *] u.existing)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Bad itinerary format')])
    (pure:m ~)
  =/  old-entries=(map @t json)
    =/  p=(unit json)  (~(get by p.u.existing) field)
    ?.  ?=([~ %o *] p)  ~
    p.u.p
  =/  new-entries=(map @t json)  (~(del by old-entries) entry-id)
  =/  updated=json  [%o (~(put by p.u.existing) field [%o new-entries])]
  ;<  ~  bind:m  (save-itinerary itin-id updated)
  ;<  ~  bind:m  (send-json eyre-id (en:json:html updated))
  (pure:m ~)
::  agent-weir: THE SANDBOX. The complete external reach we grant the
::  itinerary agent when we mount it — the kernel refuses everything else.
::    make: the itineraries documents (the tools write pins/zones)
::    poke: bowl.sig (time + entropy), the proxy's main.sig
::    peek: the itineraries documents, proxy calls
++  agent-weir
  ^-  weir:tarball
  =/  dir  |=(p=path `road:tarball`[%& %| p])
  =/  fil  |=([p=path n=@ta] `road:tarball`[%& %& p n])
  :*  make=(sy ~[(dir /apps/itinerary/itineraries)])
      %-  sy
      :~  (fil /sys 'bowl.sig')
          (fil /apps/'anthropic.anthropic' 'main.sig')
          (fil /apps/'geocode.geocode' 'main.sig')
      ==
      %-  sy
      :~  (dir /apps/itinerary/itineraries)
          (dir /apps/'anthropic.anthropic'/calls)
          (dir /apps/'geocode.geocode'/calls)
      ==
  ==
::  +ask-agent: bridge one browser turn to the agent nexus. Subscribe to
::  the conversation grub, poke the agent's main.sig, await its assistant
::  write, and return the reply + trace.
++  ask-agent
  |=  [=rail:tarball message=@t]
  =/  m  (fiber:fiber:nexus ,[reply=@t trace=json parts=json])
  ^-  form:m
  =/  chat-road=road:tarball
    (nex-road:io rail [%& /agent %'chat.json'])
  =/  main-road=road:tarball
    (nex-road:io rail [%& /agent %'main.sig'])
  ;<  *  bind:m  (keep:io /agent chat-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    (pairs:enjs:format ~[['message' s+message]])
  ;<  conv=json  bind:m  (await-agent chat-road)
  ;<  ~  bind:m  (drop:io /agent chat-road)
  =/  msgs=(list json)  ?.(?=([%a *] conv) ~ p.conv)
  ?~  msgs  (pure:m ['(no reply)' [%a ~] [%a ~]])
  =/  last=json  (rear msgs)
  ?.  ?=([%o *] last)  (pure:m ['(no reply)' [%a ~] [%a ~]])
  =/  reply=@t
    (fall (bind (~(get by p.last) 'content') |=(j=json ?>(?=(%s -.j) p.j))) '')
  =/  trace=json  (fall (~(get by p.last) 'trace') [%a ~])
  =/  parts=json  (fall (~(get by p.last) 'parts') [%a ~])
  (pure:m [reply trace parts])
::  +await-agent: wait for the agent's ASSISTANT write to the conversation
::  grub (it writes the user message first, then the completed turn).
++  await-agent
  |=  chat-road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  |-
  ;<  ~  bind:m  (take-news /agent)
  ;<  =view:nexus  bind:m  (peek:io chat-road ~)
  ?.  ?=([%file *] view)  $
  =/  conv=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) [%a ~])
  =/  msgs=(list json)  ?.(?=([%a *] conv) ~ p.conv)
  ?~  msgs  $
  =/  last=json  (rear msgs)
  ?.  &(?=([%o *] last) ?=([~ %s %'assistant'] (~(get by p.last) 'role')))  $
  (pure:m conv)
::  +ask-geocode: one geocode round-trip through the proxy nexus —
::  entropy id, keep the call grub, poke, await done, cull our sub.
++  ask-geocode
  |=  [=rail:tarball kind=@t q=@t lat=@t lon=@t poly=@t ftype=@t tag=@t radius=@t]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  proxy=path  /apps/'geocode.geocode'
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  call-id=@t     (scot %uv (end [3 8] eny))
  =/  call-name=@ta  (crip "{(trip call-id)}.json")
  =/  main-road=road:tarball  [%& %& proxy %'main.sig']
  =/  call-road=road:tarball  [%& %& (snoc proxy %calls) call-name]
  ;<  *  bind:m  (keep:io /geo call-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    %-  pairs:enjs:format
    :~  ['id' s+call-id]
        ['kind' s+kind]
        ['query' s+q]
        ['lat' s+lat]
        ['lon' s+lon]
        ['polygon' s+poly]
        ['featuretype' s+ftype]
        ['tag' s+tag]
        ['radius' s+radius]
    ==
  =|  tries=@ud
  |-  ^-  form:m
  ;<  ~  bind:m  (take-news /geo)
  ;<  res=(unit json)  bind:m  (peek-as:io call-road ,json)
  ?~  res
    ?:  (gte tries 20)
      ;<  ~  bind:m  (drop:io /geo call-road)
      (pure:m (pairs:enjs:format ~[['error' s+'geocode timed out']]))
    $(tries +(tries))
  ?.  ?&(?=([%o *] u.res) ?=([~ %s %'done'] (~(get by p.u.res) 'status')))
    $(tries +(tries))
  ;<  ~  bind:m  (drop:io /geo call-road)
  (pure:m (fall (~(get by p.u.res) 'response') [%o ~]))
::  +take-news: wait for a news wave on a wire.
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
::  +jget: a json object's string field, or ~.
++  jget
  |=  [j=json k=@t]
  ^-  (unit @t)
  ?.  ?=(%o -.j)  ~
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) ~ `p.u.v)
--
