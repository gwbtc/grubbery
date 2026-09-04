::  anthropic: the ship's Anthropic API proxy — the github-nexus
::  pattern applied to Claude. Key custody lives here once; every
::  consumer pokes this nexus and needs only its road, not the
::  internet. Usage is metered per caller: every call logs who asked,
::  which model answered, and what it cost.
::
::    config.json  -- {api-key, url} (key write-only via the api)
::    rates.json   -- {model: {in, out}} in $/million tokens
::    usage.json   -- token totals + caller-attributed call log
::    main.sig     -- poke {id, body} to create a call
::    calls/       -- per-request lifecycle grubs (the claw/api flow:
::                    keep the grub road FIRST, poke main.sig, read on
::                    news, then drop + cull)
::
/<  ui-html  anthropic/index.html
/<  ui-js    anthropic/app.js
/<  ui-css   anthropic/style.css
/<  ui-icon  anthropic/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Anthropic'
            info+s+'The ship\'s Anthropic API proxy'
            color+s+'#cc785c'
            image+s+'/grubbery/tiles/icon/anthropic.anthropic'
            href+s+'/grubbery/anthropic'
        ==
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['api-key' s+'']
            ['url' s+'https://api.anthropic.com/v1/messages']
        ==
      =/  default-rates=json
        %-  pairs:enjs:format
        :~  :-  'claude-opus-4-7'
            (pairs:enjs:format ~[['in' s+'5.00'] ['out' s+'25.00']])
            :-  'claude-sonnet-4-6'
            (pairs:enjs:format ~[['in' s+'3.00'] ['out' s+'15.00']])
            :-  'claude-haiku-4-5-20251001'
            (pairs:enjs:format ~[['in' s+'1.00'] ['out' s+'5.00']])
        ==
      =/  default-usage=json
        %-  pairs:enjs:format
        :~  ['input-tokens' (numb:enjs:format 0)]
            ['output-tokens' (numb:enjs:format 0)]
            ['cache-read-tokens' (numb:enjs:format 0)]
            ['cache-write-tokens' (numb:enjs:format 0)]
            ['requests' (numb:enjs:format 0)]
            ['calls' [%a ~]]
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'anthropic'] ['description' s+'Local structured proxy for the Anthropic API']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/ %'rates.json'] [[/ %json] default-rates]]
          [%fall %& [/ %'usage.json'] [[/ %json] default-usage]]
          [%fall %| /calls empty-dir:loader]
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
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%anthropic/main: failed")
        main-loop
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%anthropic/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/anthropic])
        (http-dispatch:io %anthropic)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%anthropic/req: failed")
        (serve name.rail)
          [[%calls ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%anthropic/call: failed")
        run-call
      ==
    --
|%
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind the UI route and send page responses')
          (line '/sys/iris/' 'the only nexus that talks to Anthropic over HTTP')
      ==
  ==
::  +main-loop: accept {id, body} pokes and create call grubs. The
::  poke SOURCE is recorded as the caller — that is what makes the
::  usage ledger attributable.
::
++  main-loop
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  id=@t  (jget jon 'id')
  =/  body=(unit json)  (~(get by p.jon) 'body')
  ?:  |(=('' id) ?=(~ body))
    ~&  >>>  "%anthropic: poke missing id or body"
    $
  =/  caller=@t  (from-to-cord from)
  =/  call-road=road:tarball
    (cord-to-road:tarball (crip "./calls/{(trip id)}.json"))
  =/  content=json
    %-  pairs:enjs:format
    :~  ['status' s+'pending']
        ['request' u.body]
        ['from' s+caller]
    ==
  ;<  ~  bind:m  (make:io call-road |+[[[/ %json] content] ~])
  ;<  ~  bind:m  (gain:io call-road %.y)
  $
::  +run-call: execute one API call. Reads its own pending request,
::  attaches the key, meters the usage, overwrites itself with the
::  outcome. The CALLER culls when done reading.
::
++  run-call
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=json  bind:m  (get-state-as:io ,json)
  ?.  ?=([%o *] own)  stay:m
  ?.  =('pending' (jget own 'status'))  stay:m
  =/  request=(unit json)  (~(get by p.own) 'request')
  =/  caller=@t  (jget own 'from')
  ?~  request  stay:m
  ;<  cfg=[key=@t url=@t]  bind:m  read-config
  ?:  =('' key.cfg)
    ;<  ~  bind:m
      %-  replace:io
      %-  pairs:enjs:format
      :~  ['status' s+'done']
          ['response' (pairs:enjs:format ~[['error' s+'no api-key configured']])]
      ==
    stay:m
  =/  hed=(list [key=@t value=@t])
    :~  ['content-type' 'application/json']
        ['x-api-key' key.cfg]
        ['anthropic-version' '2023-06-01']
    ==
  ;<  ~  bind:m
    %-  send-request:io
    [%'POST' url.cfg hed `(as-octs:mimes:html (en:json:html u.request))]
  ;<  resp=client-response:iris  bind:m  take-client-response:io
  =/  resp-json=json
    ?.  ?=(%finished -.resp)
      (pairs:enjs:format ~[['error' s+'HTTP request did not finish']])
    ?~  full-file.resp
      (pairs:enjs:format ~[['error' s+'empty response']])
    %+  fall  (de:json:html q.data.u.full-file.resp)
    (pairs:enjs:format ~[['error' s+'JSON parse failed']])
  ;<  ~  bind:m  (accumulate-usage resp-json caller)
  ;<  ~  bind:m
    %-  replace:io
    (pairs:enjs:format ~[['status' s+'done'] ['response' resp-json]])
  stay:m
::  +accumulate-usage: fold one response's usage into usage.json,
::  attributed to the caller. The call log keeps the most recent 500
::  entries; the totals are forever.
::
++  accumulate-usage
  |=  [resp=json caller=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] resp)  (pure:m ~)
  =/  usage=(unit json)  (~(get by p.resp) 'usage')
  ?~  usage  (pure:m ~)
  ?.  ?=(%o -.u.usage)  (pure:m ~)
  =/  in-tok=@ud       (jnum u.usage 'input_tokens' 0)
  =/  out-tok=@ud      (jnum u.usage 'output_tokens' 0)
  =/  cache-read=@ud   (jnum u.usage 'cache_read_input_tokens' 0)
  =/  cache-write=@ud  (jnum u.usage 'cache_creation_input_tokens' 0)
  =/  model=@t  (jget resp 'model')
  ::  stamp the DOLLAR cost now, at the rates in force at call time —
  ::  a ledger records what was spent, it does not reprice history
  ;<  urates=(unit json)  bind:m
    (peek-as:io (cord-to-road:tarball '../rates.json') ,json)
  =/  cost=@t
    (compute-cost (fall urates *json) model in-tok out-tok cache-read cache-write)
  =/  usage-road=road:tarball  (cord-to-road:tarball '../usage.json')
  ;<  ucur=(unit json)  bind:m  (peek-as:io usage-road ,json)
  =/  cur=json  (fall ucur [%o ~])
  ?.  ?=([%o *] cur)  (pure:m ~)
  =/  old-calls=(list json)
    =/  c  (~(get by p.cur) 'calls')
    ?.(?=([~ %a *] c) ~ p.u.c)
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['in' (numb:enjs:format in-tok)]
        ['out' (numb:enjs:format out-tok)]
        ['cache-read' (numb:enjs:format cache-read)]
        ['cache-write' (numb:enjs:format cache-write)]
        ['cost' [%n cost]]
        ['model' s+model]
        ['from' s+caller]
        ['time' (sect:enjs:format now)]
    ==
  =/  new=json
    %-  pairs:enjs:format
    :~  ['input-tokens' (numb:enjs:format (add in-tok (jnum cur 'input-tokens' 0)))]
        ['output-tokens' (numb:enjs:format (add out-tok (jnum cur 'output-tokens' 0)))]
        ['cache-read-tokens' (numb:enjs:format (add cache-read (jnum cur 'cache-read-tokens' 0)))]
        ['cache-write-tokens' (numb:enjs:format (add cache-write (jnum cur 'cache-write-tokens' 0)))]
        ['requests' (numb:enjs:format (add 1 (jnum cur 'requests' 0)))]
        ['calls' [%a (scag 500 `(list json)`[entry old-calls])]]
    ==
  (over:io usage-road [[/ %json] new])
::  +compute-cost: dollars for one call, fixed-point (units of 1e-10
::  dollars) so no floats are involved. Rates are $/M-token strings;
::  cache reads bill at 0.1x input, cache writes at 1.25x.
::
++  compute-cost
  |=  [rates=json model=@t in=@ud out=@ud cr=@ud cw=@ud]
  ^-  @t
  =/  [ri=@ud ro=@ud]  (rate-for rates model)
  =/  units=@ud
    ;:  add
      (mul in (mul ri 100))
      (mul cr (mul ri 10))
      (mul cw (mul ri 125))
      (mul out (mul ro 100))
    ==
  =/  int=@ud   (div units 10.000.000.000)
  =/  frac=@ud  (mod units 10.000.000.000)
  ?:  =(0 frac)  (crip (a-co:co int))
  =/  padded=tape  =/(r (a-co:co frac) (weld (reap (sub 10 (lent r)) '0') r))
  (crip "{(a-co:co int)}.{(flop (drop-zeros (flop padded)))}")
::
++  drop-zeros
  |=  t=tape
  ^-  tape
  ?~  t  "0"
  ?:  =('0' i.t)  $(t t.t)
  t
::  +rate-for: [in out] rates in hundredths of $/M-token. Exact model
::  match first, else the longest rate key the model starts with (so
::  dated ids find their undated rate).
::
++  rate-for
  |=  [rates=json model=@t]
  ^-  [@ud @ud]
  ?.  ?=([%o *] rates)  [0 0]
  =/  ent=(unit json)  (~(get by p.rates) model)
  =?  ent  ?=(~ ent)
    =/  mt=tape  (trip model)
    =/  best=(unit @t)
      %+  roll  ~(tap in ~(key by p.rates))
      |=  [k=@t acc=(unit @t)]
      =/  kt=tape  (trip k)
      ?.  ?&  (lte (lent kt) (lent mt))
              =(kt (scag (lent kt) mt))
          ==
        acc
      ?~  acc  `k
      ?:((gth (lent kt) (met 3 u.acc)) `k acc)
    ?~(best ~ (~(get by p.rates) u.best))
  ?~  ent  [0 0]
  ?.  ?=([%o *] u.ent)  [0 0]
  :-  (parse-hundredths (jget u.ent 'in'))
  (parse-hundredths (jget u.ent 'out'))
::  +parse-hundredths: '5.00' -> 500; tolerant of missing decimals
::
++  parse-hundredths
  |=  s=@t
  ^-  @ud
  =/  t=tape  (trip s)
  =/  dot=(unit @ud)  (find "." t)
  ?~  dot  (mul 100 (fall (rush s dem) 0))
  =/  int=@ud  (fall (rush (crip (scag u.dot t)) dem) 0)
  =/  frac=tape  (scag 2 (weld (slag +(u.dot) t) "00"))
  (add (mul 100 int) (fall (rush (crip frac) dem) 0))
::
++  read-config
  =/  m  (fiber:fiber:nexus ,[key=@t url=@t])
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
  =/  cfg=json  (fall ucfg *json)
  ?.  ?=([%o *] cfg)  (pure:m ['' 'https://api.anthropic.com/v1/messages'])
  =/  url=@t  (jget cfg 'url')
  %-  pure:m
  :-  (jget cfg 'api-key')
  ?:(=('' url) 'https://api.anthropic.com/v1/messages' url)
::
++  from-to-cord
  |=  =from:fiber:nexus
  ^-  @t
  =/  =rail:tarball  q.from
  %-  crip
  =/  parts=(list @ta)  (snoc path.rail name.rail)
  =|  acc=tape
  |-
  ?~  parts  acc
  ?~  acc  $(parts t.parts, acc (trip i.parts))
  $(parts t.parts, acc (weld acc `tape`['/' (trip i.parts)]))
::
++  jget
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  v  (~(get by p.jon) k)
  ?.(?=([~ %s *] v) '' p.u.v)
++  jnum
  |=  [jon=json k=@t d=@ud]
  ^-  @ud
  ?.  ?=(%o -.jon)  d
  =/  v  (~(get by p.jon) k)
  ?.  ?=([~ %n *] v)  d
  (fall (rush p.u.v dem) d)
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  +serve: the metering UI. Static shell + api:
::    GET  /api/status   {keySet, requests, pending}
::    GET  /api/usage    {usage, rates}
::    POST /api/config   {api-key?, url?} merge (key never echoed)
::    POST /api/rates    replace rates.json
::    POST /api/reset    zero the usage ledger
::    POST /api/sweep    cull every finished call grub
::
::  TODO: sync the model catalog on a timer (server-side poll fiber,
::  stable /wait wire) instead of relying on the manual UI button;
::  for anthropic that means moving the per-token -> $/M conversion
::  from the browser into hoon.
++  serve
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/anthropic
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %status ~]
    ;<  cfg=[key=@t url=@t]  bind:m  read-config
    ;<  uusage=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'usage.json'] ,json)
    =/  usage=json  (fall uusage *json)
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    =/  pending=@ud
      %-  lent
      %+  skim  (file-entries calls)
      |=([nam=@ta =sang:tarball] =('pending' (call-status sang)))
    ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  synced=@ud  ?~(ucfg 0 (jnum u.ucfg 'rates-synced' 0))
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['keySet' b+!=('' key.cfg)]
        ['requests' (numb:enjs:format (jnum usage 'requests' 0))]
        ['pending' (numb:enjs:format pending)]
        ['syncedAt' (numb:enjs:format synced)]
    ==
  ::
      [%api %key ~]
    ;<  cfg=[key=@t url=@t]  bind:m  read-config
    (send-json eyre-id (pairs:enjs:format ~[['key' s+key.cfg]]))
  ::
      [%api %usage ~]
    ;<  uusage=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'usage.json'] ,json)
    ;<  urates=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'rates.json'] ,json)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['usage' (fall uusage *json)]
        ['rates' (fall urates *json)]
    ==
  ::
      [%api %config ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  cur=(unit json)  bind:m
      (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)
      ?~  cur  ~
      ?.(?=(%o -.u.cur) ~ p.u.cur)
    =/  key=(unit json)  (~(get by p.u.jon) 'api-key')
    =/  url=(unit json)  (~(get by p.u.jon) 'url')
    =?  om  &(?=(^ key) ?=([%s *] u.key) !=('' p.u.key))  (~(put by om) 'api-key' u.key)
    =?  om  &(?=(^ url) ?=([%s *] u.url) !=('' p.u.url))  (~(put by om) 'url' u.url)
    ;<  ~  bind:m  (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %rates ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  ~  bind:m  (over:io [%| 1 %& / %'rates.json'] [[/ %json] u.jon])
    ::  stamp when rates were synced, so staleness is visible
    ;<  now=@da  bind:m  get-time:io
    ;<  cfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)  ?:(?=([~ %o *] cfg) p.u.cfg ~)
    ;<  ~  bind:m
      %+  over:io  [%| 1 %& / %'config.json']
      [[/ %json] `json`[%o (~(put by om) 'rates-synced' (sect:enjs:format now))]]
    (reply eyre-id 200 'ok')
  ::
      [%api %reset ~]
    =/  zero=json
      %-  pairs:enjs:format
      :~  ['input-tokens' (numb:enjs:format 0)]
          ['output-tokens' (numb:enjs:format 0)]
          ['cache-read-tokens' (numb:enjs:format 0)]
          ['cache-write-tokens' (numb:enjs:format 0)]
          ['requests' (numb:enjs:format 0)]
          ['calls' [%a ~]]
      ==
    ;<  ~  bind:m  (over:io [%| 1 %& / %'usage.json'] [[/ %json] zero])
    (reply eyre-id 200 'ok')
  ::
      [%api %call-new ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  id=@t  (crip ((x-co:co 16) (end 6 eny)))
    =/  content=json
      %-  pairs:enjs:format
      :~  ['status' s+'pending']
          ['request' u.jon]
          ['from' s+'ui']
      ==
    =/  call-road=road:tarball  [%| 1 %& /calls (crip "{(trip id)}.json")]
    ;<  err=(unit tang)  bind:m
      (make-soft:io call-road |+[[[/ %json] content] ~])
    ?^  err  (reply eyre-id 500 'could not create call')
    ;<  ~  bind:m  (gain:io call-road %.y)
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ::
      [%api %call ~]
    =/  id=(unit @t)  (~(get by (malt args)) 'id')
    ?~  id  (reply eyre-id 400 'id required')
    ;<  res=(unit json)  bind:m
      (peek-as:io [%| 1 %& /calls (crip "{(trip u.id)}.json")] ,json)
    ?~  res  (reply eyre-id 404 'no such call')
    (send-json eyre-id u.res)
  ::
      [%api %call-cull ~]
    ::  the UI is a consumer like any other: it culls its call after
    ::  reading the result (the usage ledger is the durable record)
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  id=@t  (jget u.jon 'id')
    ?:  =('' id)  (reply eyre-id 400 'id required')
    ;<  *  bind:m
      (cull-soft:io [%| 1 %& /calls (crip "{(trip id)}.json")])
    (reply eyre-id 200 'ok')
  ::
      [%api %sweep ~]
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    =/  done=(list @ta)
      %+  murn  (file-entries calls)
      |=  [nam=@ta =sang:tarball]
      ?:(=('pending' (call-status sang)) ~ `nam)
    =/  n=@ud  (lent done)
    |-
    ?~  done
      (send-json eyre-id (pairs:enjs:format ~[['swept' (numb:enjs:format n)]]))
    ;<  *  bind:m  (cull-soft:io [%| 1 %& /calls i.done])
    $(done t.done)
  ==
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
::
++  count-files
  |=  =view:nexus
  ^-  @ud
  ?.  ?=([%ball *] view)  0
  ?~  fil.ball.view  0
  ~(wyt by contents.u.fil.ball.view)
++  file-entries
  |=  =view:nexus
  ^-  (list [@ta sang:tarball])
  ?.  ?=([%ball *] view)  ~
  ?~  fil.ball.view  ~
  %+  turn  ~(tap by contents.u.fil.ball.view)
  |=  [nam=@ta ent=[=sang:tarball *]]
  [nam sang.ent]
++  call-status
  |=  =sang:tarball
  ^-  @t
  =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang))))
  ?~  jon  ''
  ?.  ?=(%o -.u.jon)  ''
  (jget u.jon 'status')
++  post-json
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?.  =(%'POST' method.request.req)  ~
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
++  reply
  |=  [eyre-id=@ta code=@ud msg=@t]
  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html msg)])
++  send-json
  |=  [eyre-id=@ta jon=json]
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
--
