::  openrouter: the ship's OpenRouter proxy — every model behind one
::  key, in the anthropic-nexus shape. Same {id, body} poke protocol,
::  OpenAI-dialect bodies. The nexus injects usage accounting into
::  every request, so the ledger records NATIVE dollar cost per call —
::  no rates table, no estimation.
::
::    config.json  -- {api-key} (write-only via the api)
::    models.json  -- {model: {prompt, completion, context}} synced
::                    from openrouter's /models on demand
::    usage.json   -- token totals + caller-attributed call log with
::                    real cost
::    main.sig     -- poke {id, body} to create a call
::    calls/       -- per-request lifecycle grubs (consumer culls)
::
/<  ui-html  openrouter/index.html
/<  ui-js    openrouter/app.js
/<  ui-css   openrouter/style.css
/<  ui-icon  openrouter/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'OpenRouter'
            info+s+'Every model, one key'
            color+s+'#6366f1'
            image+s+'/grubbery/tiles/icon/openrouter.openrouter'
            href+s+'/grubbery/openrouter'
        ==
      =/  default-config=json
        (pairs:enjs:format ~[['api-key' s+'']])
      =/  default-usage=json
        %-  pairs:enjs:format
        :~  ['input-tokens' (numb:enjs:format 0)]
            ['output-tokens' (numb:enjs:format 0)]
            ['requests' (numb:enjs:format 0)]
            ['calls' [%a ~]]
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'openrouter'] ['description' s+'Local structured proxy for OpenRouter']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%openrouter/main: failed")
        main-loop
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%openrouter/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/openrouter])
        (http-dispatch:io %openrouter)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%openrouter/req: failed")
        (serve name.rail)
          [[%calls ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%openrouter/call: failed")
        run-call
      ==
    --
|%
++  api-base  'https://openrouter.ai/api/v1'
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind the UI route and send page responses')
          (line '/sys/iris/' 'the only nexus that talks to OpenRouter over HTTP')
      ==
  ==
::  +main-loop: accept {id, body} pokes and create call grubs, with
::  the poke source recorded as the caller
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
    ~&  >>>  "%openrouter: poke missing id or body"
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
::  +run-call: execute one chat/completions call. Accounting is
::  injected (usage.include) so the response carries real cost.
::
++  run-call
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=json  bind:m  (get-state-as:io ,json)
  ?.  ?=([%o *] own)  idle:io
  ?.  =('pending' (jget own 'status'))  idle:io
  =/  request=(unit json)  (~(get by p.own) 'request')
  =/  caller=@t  (jget own 'from')
  ?~  request  idle:io
  ;<  key=@t  bind:m  read-key
  ?:  =('' key)
    ;<  ~  bind:m
      %-  replace:io
      %-  pairs:enjs:format
      :~  ['status' s+'done']
          ['response' (pairs:enjs:format ~[['error' s+'no api-key configured']])]
      ==
    idle:io
  ::  inject usage accounting unless the caller opted out explicitly
  =/  body=json
    ?.  ?=([%o *] u.request)  u.request
    ?:  (~(has by p.u.request) 'usage')  u.request
    [%o (~(put by p.u.request) 'usage' (pairs:enjs:format ~[['include' b+&]]))]
  =/  hed=(list [key=@t value=@t])
    :~  ['content-type' 'application/json']
        ['authorization' (cat 3 'Bearer ' key)]
        ['x-title' 'grubbery']
    ==
  ;<  ~  bind:m
    %-  send-request:io
    [%'POST' (cat 3 api-base '/chat/completions') hed `(as-octs:mimes:html (en:json:html body))]
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
  idle:io
::  +accumulate-usage: fold one response into usage.json. cost is the
::  NATIVE number openrouter reports — passed through untouched, never
::  parsed server-side. Log capped at 500 entries; totals are forever.
::
++  accumulate-usage
  |=  [resp=json caller=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] resp)  (pure:m ~)
  =/  usage=(unit json)  (~(get by p.resp) 'usage')
  ?~  usage  (pure:m ~)
  ?.  ?=(%o -.u.usage)  (pure:m ~)
  =/  in-tok=@ud   (jnum u.usage 'prompt_tokens' 0)
  =/  out-tok=@ud  (jnum u.usage 'completion_tokens' 0)
  =/  cost=json    (fall (~(get by p.u.usage) 'cost') [%n '0'])
  =/  model=@t  (jget resp 'model')
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
        ['cost' cost]
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
::
++  read-key
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
  =/  cfg=json  (fall ucfg *json)
  (pure:m ?.(?=([%o *] cfg) '' (jget cfg 'api-key')))
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
::  +serve: static shell + api:
::    GET  /api/status       {keySet, requests, pending, models}
::    GET  /api/usage        usage.json verbatim
::    GET  /api/models       models.json verbatim
::    GET  /api/key          {key}
::    POST /api/config       {api-key?} merge (key never echoed)
::    POST /api/models-sync  fetch /models, store {id: {prompt, completion, context}}
::    POST /api/call-new     {..openai body..} -> {id} (caller 'ui')
::    GET  /api/call?id=
::    POST /api/call-cull    {id}
::    POST /api/reset        zero the usage ledger
::    POST /api/sweep        cull finished call grubs
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
  =/  prefix=path  /grubbery/openrouter
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %status ~]
    ;<  key=@t  bind:m  read-key
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
    ;<  cfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  synced=@ud  ?~(cfg 0 (jnum u.cfg 'models-synced' 0))
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['keySet' b+!=('' key)]
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
      [%api %key ~]
    ;<  key=@t  bind:m  read-key
    (send-json eyre-id (pairs:enjs:format ~[['key' s+key]]))
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
    ;<  ~  bind:m  (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %models-sync ~]
    ;<  ~  bind:m
      (send-request:io [%'GET' (cat 3 api-base '/models') ~[['accept' 'application/json']] ~])
    ;<  resp=client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.resp)  (reply eyre-id 502 'openrouter unreachable')
    ?~  full-file.resp  (reply eyre-id 502 'empty response')
    =/  jon=json  (fall (de:json:html q.data.u.full-file.resp) *json)
    ?.  ?=([%o *] jon)  (reply eyre-id 502 'bad response')
    =/  data  (~(get by p.jon) 'data')
    ?.  ?=([~ %a *] data)  (reply eyre-id 502 'no model data')
    =/  models=(map @t json)
      %+  roll  p.u.data
      |=  [mod=json acc=(map @t json)]
      ?.  ?=([%o *] mod)  acc
      =/  id=@t  (jget mod 'id')
      ?:  =('' id)  acc
      =/  pricing=json
        (fall (~(get by p.mod) 'pricing') *json)
      =/  ctx=json
        (fall (~(get by p.mod) 'context_length') [%n '0'])
      %+  ~(put by acc)  id
      %-  pairs:enjs:format
      :~  ['prompt' ?.(?=([%o *] pricing) s+'' (fall (~(get by p.pricing) 'prompt') s+''))]
          ['completion' ?.(?=([%o *] pricing) s+'' (fall (~(get by p.pricing) 'completion') s+''))]
          ['context' ctx]
      ==
    ;<  ~  bind:m  (over:io [%| 1 %& / %'models.json'] [[/ %json] `json`[%o models]])
    ::  stamp when we synced, so staleness is visible
    ;<  now=@da  bind:m  get-time:io
    ;<  cfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)  ?:(?=([~ %o *] cfg) p.u.cfg ~)
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
