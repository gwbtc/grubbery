::  typesafe: the ship's TypeSafe AI proxy — Jev, the System One
::  decision model, in the anthropic/openrouter-nexus shape. Same
::  {id, body} poke protocol; bodies are {state, questions, model?}
::  and the answer is one typed decision per question (choice / score
::  / noul) with calibrated probabilities. Not a chat model: it
::  decides, it does not generate.
::
::    config.json  -- {api-key, model} (key write-only via the api;
::                    model is the default when a body names none)
::    rates.json   -- {model-prefix: {in}} in $/BILLION input tokens
::                    (output tokens are free)
::    models.json  -- {id: {description, released}} synced from
::                    /v1/models on demand
::    usage.json   -- token totals + caller-attributed call log
::    main.sig     -- poke {id, body} to create a call
::    calls/       -- per-request lifecycle grubs (consumer culls)
::
/<  ui-html  typesafe/index.html
/<  ui-js    typesafe/app.js
/<  ui-css   typesafe/style.css
/<  ui-icon  typesafe/icon.svg
/<  nw       /lib/nexus-web.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'TypeSafe'
            info+s+'Jev: typed decisions, not text'
            color+s+'#d45bb6'
            image+s+'/grubbery/tiles/icon/typesafe'
            href+s+'/grubbery/typesafe'
        ==
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['api-key' s+'']
            ['model' s+'jev-latest']
        ==
      =/  default-rates=json
        %-  pairs:enjs:format
        :~  ['jev' (pairs:enjs:format ~[['in' s+'42.00']])]
        ==
      =/  default-usage=json
        %-  pairs:enjs:format
        :~  ['input-tokens' (numb:enjs:format 0)]
            ['output-tokens' (numb:enjs:format 0)]
            ['requests' (numb:enjs:format 0)]
            ['calls' [%a ~]]
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'typesafe'] ['description' s+'Local structured proxy for TypeSafe AI (Jev)']])]]
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
          [%fall %& [/ %'models.json'] [[/ %json] [%o ~]]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%typesafe/main: failed")
        main-loop
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%typesafe/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/typesafe])
        (http-dispatch:io %typesafe)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%typesafe/req: failed")
        (serve name.rail)
          [[%calls ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%typesafe/call: failed")
        run-call
      ==
    --
|%
++  api-base  'https://api.typesafe.ai/v1'
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind the UI route and send page responses')
          (line '/sys/iris/' 'the only nexus that talks to TypeSafe over HTTP')
      ==
  ==
::  +main-loop: accept {id, body} pokes and create call grubs, with
::  the poke source recorded as the caller
::
++  main-loop
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  loc=here:nexus  bind:m  get-here:io
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  id=@t  (jget jon 'id')
  =/  body=(unit json)  (~(get by p.jon) 'body')
  ?:  |(=('' id) ?=(~ body))
    ~&  >>>  "%typesafe: poke missing id or body"
    $
  =/  caller=@t  (caller-path loc from)
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
::  +run-call: execute one /systemone call. Fills in the default
::  model when the body names none, meters the input tokens, and
::  overwrites itself with the outcome. The CALLER culls.
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
  ;<  cfg=[key=@t model=@t]  bind:m  read-config
  ?:  =('' key.cfg)
    ;<  ~  bind:m
      %-  replace:io
      %-  pairs:enjs:format
      :~  ['status' s+'done']
          ['response' (pairs:enjs:format ~[['error' s+'no api-key configured']])]
      ==
    stay:m
  =/  body=json
    ?.  ?=([%o *] u.request)  u.request
    ?:  (~(has by p.u.request) 'model')  u.request
    [%o (~(put by p.u.request) 'model' s+model.cfg)]
  =/  hed=(list [key=@t value=@t])
    :~  ['content-type' 'application/json']
        ['authorization' (cat 3 'Bearer ' key.cfg)]
    ==
  ;<  ~  bind:m
    %-  send-request:io
    [%'POST' (cat 3 api-base '/systemone') hed `(as-octs:mimes:html (en:json:html body))]
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
::  attributed to the caller. Only input tokens cost money; output
::  tokens are recorded for the record. Log capped at 500 entries;
::  totals are forever.
::
++  accumulate-usage
  |=  [resp=json caller=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] resp)  (pure:m ~)
  =/  usage=(unit json)  (~(get by p.resp) 'usage')
  ?~  usage  (pure:m ~)
  ?.  ?=(%o -.u.usage)  (pure:m ~)
  =/  in-tok=@ud   (jnum u.usage 'input_tokens' 0)
  =/  out-tok=@ud  (jnum u.usage 'output_tokens' 0)
  =/  model=@t  (jget resp 'model')
  ::  stamp the DOLLAR cost now, at the rate in force at call time
  ;<  urates=(unit json)  bind:m
    (peek-as:io (cord-to-road:tarball '../rates.json') ,json)
  =/  cost=@t  (compute-cost (fall urates *json) model in-tok)
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
        ['cost' [%n cost]]
        ['model' s+model]
        ['from' s+caller]
        ['time' (sect:enjs:format now)]
    ==
  =/  new=json
    %-  pairs:enjs:format
    :~  ['input-tokens' (numb:enjs:format (add in-tok (jnum cur 'input-tokens' 0)))]
        ['output-tokens' (numb:enjs:format (add out-tok (jnum cur 'output-tokens' 0)))]
        ['requests' (numb:enjs:format (add 1 (jnum cur 'requests' 0)))]
        ['calls' [%a (scag 500 `(list json)`[entry old-calls])]]
    ==
  (over:io usage-road [[/ %json] new])
::  +compute-cost: dollars for one call, fixed-point (units of 1e-11
::  dollars) so no floats are involved. The rate is a $/BILLION-token
::  string parsed to hundredths, so tokens * hundredths lands in
::  1e-11 dollars.
::
++  compute-cost
  |=  [rates=json model=@t in=@ud]
  ^-  @t
  =/  ri=@ud  (rate-for rates model)
  =/  units=@ud  (mul in ri)
  =/  int=@ud   (div units 100.000.000.000)
  =/  frac=@ud  (mod units 100.000.000.000)
  ?:  =(0 frac)  (crip (a-co:co int))
  =/  padded=tape  =/(r (a-co:co frac) (weld (reap (sub 11 (lent r)) '0') r))
  (crip "{(a-co:co int)}.{(flop (drop-zeros (flop padded)))}")
::
++  drop-zeros
  |=  t=tape
  ^-  tape
  ?~  t  "0"
  ?:  =('0' i.t)  $(t t.t)
  t
::  +rate-for: input rate in hundredths of $/B-token. Exact model
::  match first, else the longest rate key the model starts with (so
::  'jev-1.13.0' finds 'jev').
::
++  rate-for
  |=  [rates=json model=@t]
  ^-  @ud
  ?.  ?=([%o *] rates)  0
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
  ?~  ent  0
  ?.  ?=([%o *] u.ent)  0
  (parse-hundredths (jget u.ent 'in'))
::  +parse-hundredths: '42.00' -> 4200; tolerant of missing decimals
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
  =/  m  (fiber:fiber:nexus ,[key=@t model=@t])
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
  =/  cfg=json  (fall ucfg *json)
  ?.  ?=([%o *] cfg)  (pure:m ['' 'jev-latest'])
  =/  model=@t  (jget cfg 'model')
  (pure:m [(jget cfg 'api-key') ?:(=('' model) 'jev-latest' model)])
++  web  ~(. web:nw [%| 1 %& ~ %'web.sig'])
++  reply         reply:web
++  send-json     send-json:web
++  serve-static  serve-static:web
++  jget          jget:nw
++  jnum          jnum:nw
++  post-json     post-json:nw
++  file-entries  file-entries:nw
++  call-status   call-status:nw
++  caller-path   caller-path:nw
::  +serve: static shell + api:
::    GET  /api/status       {keySet, model, requests, pending, models}
::    GET  /api/usage        usage.json verbatim
::    GET  /api/models       models.json verbatim
::    GET  /api/rates        rates.json verbatim
::    GET  /api/key          {key}
::    POST /api/config       {api-key?, model?} merge (key never echoed)
::    POST /api/models-sync  fetch /models, store {id: {description, released}}
::    POST /api/call-new     {state, questions, model?} -> {id}
::    GET  /api/call?id=
::    POST /api/call-cull    {id}
::    POST /api/reset        zero the usage ledger
::    POST /api/sweep        cull finished call grubs
::
++  serve
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/typesafe
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %status ~]
    ;<  cfg=[key=@t model=@t]  bind:m  read-config
    ;<  uusage=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'usage.json'] ,json)
    =/  usage=json  (fall uusage *json)
    ;<  umod=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'models.json'] ,json)
    =/  models=@ud
      ?~  umod  0
      ?.(?=([%o *] u.umod) 0 ~(wyt by p.u.umod))
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    =/  pending=@ud
      %-  lent
      %+  skim  (file-entries calls)
      |=([nam=@ta =sang:tarball] =('pending' (call-status sang)))
    ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  synced=@ud  ?~(ucfg 0 (jnum u.ucfg 'models-synced' 0))
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['keySet' b+!=('' key.cfg)]
        ['model' s+model.cfg]
        ['requests' (numb:enjs:format (jnum usage 'requests' 0))]
        ['pending' (numb:enjs:format pending)]
        ['models' (numb:enjs:format models)]
        ['syncedAt' (numb:enjs:format synced)]
    ==
  ::
      [%api %usage ~]
    ;<  uusage=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'usage.json'] ,json)
    (send-json eyre-id (fall uusage *json))
  ::
      [%api %models ~]
    ;<  umod=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'models.json'] ,json)
    (send-json eyre-id (fall umod *json))
  ::
      [%api %rates ~]
    ;<  urates=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'rates.json'] ,json)
    (send-json eyre-id (fall urates *json))
  ::
      [%api %key ~]
    ;<  cfg=[key=@t model=@t]  bind:m  read-config
    (send-json eyre-id (pairs:enjs:format ~[['key' s+key.cfg]]))
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
    =?  om  &(?=(^ key) ?=([%s *] u.key) !=('' p.u.key))  (~(put by om) 'api-key' u.key)
    =/  model=(unit json)  (~(get by p.u.jon) 'model')
    =?  om  &(?=(^ model) ?=([%s *] u.model) !=('' p.u.model))  (~(put by om) 'model' u.model)
    ;<  ~  bind:m  (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %models-sync ~]
    ;<  cfg=[key=@t model=@t]  bind:m  read-config
    ?:  =('' key.cfg)  (reply eyre-id 400 'no api-key configured')
    =/  hed=(list [key=@t value=@t])
      :~  ['accept' 'application/json']
          ['authorization' (cat 3 'Bearer ' key.cfg)]
      ==
    ;<  ~  bind:m
      (send-request:io [%'GET' (cat 3 api-base '/models') hed ~])
    ;<  resp=client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.resp)  (reply eyre-id 502 'typesafe unreachable')
    ?~  full-file.resp  (reply eyre-id 502 'empty response')
    =/  jon=json  (fall (de:json:html q.data.u.full-file.resp) *json)
    ::  tolerate either a bare array or {data|models: [...]}
    =/  items=(list json)
      ?:  ?=([%a *] jon)  p.jon
      ?.  ?=([%o *] jon)  ~
      =/  d  (~(get by p.jon) 'data')
      ?:  ?=([~ %a *] d)  p.u.d
      =/  ms  (~(get by p.jon) 'models')
      ?:(?=([~ %a *] ms) p.u.ms ~)
    ::  =(~) not ?~: a lest into wet +roll trips mull-grow
    ?:  =(~ items)  (reply eyre-id 502 'no model data')
    =/  models=(map @t json)
      %+  roll  items
      |=  [mod=json acc=(map @t json)]
      ?.  ?=([%o *] mod)  acc
      =/  id=@t  =/(i (jget mod 'id') ?:(=('' i) (jget mod 'name') i))
      ?:  =('' id)  acc
      %+  ~(put by acc)  id
      %-  pairs:enjs:format
      :~  ['description' s+(jget mod 'description')]
          ['released' (fall (~(get by p.mod) 'release_date') (fall (~(get by p.mod) 'released_at') s+''))]
      ==
    ;<  ~  bind:m  (over:io [%| 1 %& / %'models.json'] [[/ %json] `json`[%o models]])
    ;<  now=@da  bind:m  get-time:io
    ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)  ?:(?=([~ %o *] ucfg) p.u.ucfg ~)
    ;<  ~  bind:m
      %+  over:io  [%| 1 %& / %'config.json']
      [[/ %json] `json`[%o (~(put by om) 'models-synced' (sect:enjs:format now))]]
    (send-json eyre-id (pairs:enjs:format ~[['synced' (numb:enjs:format ~(wyt by models))]]))
  ::
      [%api %call-new ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  id=@t  (crip ((x-co:co 16) (end 6 eny)))
    ::  through the front door: poke our own main.sig like any other
    ::  caller, so the kernel records this request grub as the caller
    ;<  err=(unit tang)  bind:m
      %+  poke-soft:io  [%| 1 %& / %'main.sig']
      [[/ %json] (pairs:enjs:format ~[['id' s+id] ['body' u.jon]])]
    ?^  err  (reply eyre-id 500 'could not create call')
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
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  id=@t  (jget u.jon 'id')
    ?:  =('' id)  (reply eyre-id 400 'id required')
    ;<  *  bind:m
      (cull-soft:io [%| 1 %& /calls (crip "{(trip id)}.json")])
    (reply eyre-id 200 'ok')
  ::
      [%api %reset ~]
    =/  zero=json
      %-  pairs:enjs:format
      :~  ['input-tokens' (numb:enjs:format 0)]
          ['output-tokens' (numb:enjs:format 0)]
          ['requests' (numb:enjs:format 0)]
          ['calls' [%a ~]]
      ==
    ;<  ~  bind:m  (over:io [%| 1 %& / %'usage.json'] [[/ %json] zero])
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
--
