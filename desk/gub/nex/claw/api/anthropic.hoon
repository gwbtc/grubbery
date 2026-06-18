::  claw/api/anthropic: Anthropic API proxy nexus
::
::  Standard API:
::    config.json  -- api-key, url
::    main.sig     -- poke with {id, body} to create a call
::    calls/       -- per-request lifecycle files
::
::  Flow:
::    1. Caller subscribes (keep) to calls/[id].json before it exists
::    2. Caller pokes main.sig with {"id": "...", "body": {...}}
::    3. main.sig creates calls/[id].json with {status: "pending", request: body}
::    4. calls/[id].json fiber starts, reads config, makes HTTP call
::    5. Fiber overwrites self with {status: "done", response: ...}
::    6. Caller gets news, reads response, drops subscription
::
/&  man  ../../../man/claw/api/anthropic/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-rates=json
        %-  pairs:enjs:format
        :~  :-  'claude-opus-4-7'
            (pairs:enjs:format ~[['in' s+'5.00'] ['out' s+'25.00']])
            :-  'claude-sonnet-4-6'
            (pairs:enjs:format ~[['in' s+'3.00'] ['out' s+'15.00']])
            :-  'claude-haiku-4-5-20251001'
            (pairs:enjs:format ~[['in' s+'1.00'] ['out' s+'5.00']])
            :-  'claude-opus-4-6'
            (pairs:enjs:format ~[['in' s+'5.00'] ['out' s+'25.00']])
            :-  'claude-sonnet-4-5-20250929'
            (pairs:enjs:format ~[['in' s+'3.00'] ['out' s+'15.00']])
            :-  'claude-opus-4-5-20251101'
            (pairs:enjs:format ~[['in' s+'5.00'] ['out' s+'25.00']])
            :-  'claude-opus-4-1-20250805'
            (pairs:enjs:format ~[['in' s+'15.00'] ['out' s+'75.00']])
            :-  'claude-sonnet-4-20250514'
            (pairs:enjs:format ~[['in' s+'3.00'] ['out' s+'15.00']])
            :-  'claude-opus-4-20250514'
            (pairs:enjs:format ~[['in' s+'15.00'] ['out' s+'75.00']])
        ==
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['api-key' s+'']
            ['url' s+'https://api.anthropic.com/v1/messages']
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
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
            [%fall %& [/ %'config.json'] [[/ %json] default-config]]
            [%fall %& [/ %'rates.json'] [[/ %json] default-rates]]
            [%fall %& [/ %'usage.json'] [[/ %json] default-usage]]
            [%fall %| /calls empty-dir:loader]
            [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html usage-page))]]
            [%over %& [/man %'readme.md'] [[/ %mime] man]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /main.sig: accept poke with {id, body}, create calls/[id].json
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%api/anthropic: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  id=@t
          (fall (bind (~(get by p.jon) 'id') |=(=json ?>(?=(%s -.json) p.json))) '')
        =/  body=(unit json)  (~(get by p.jon) 'body')
        ?:  |(=('' id) ?=(~ body))
          ~&  >>>  "%api/anthropic: missing id or body in poke"
          $
        ::  extract caller identity from poke source
        =/  caller=@t  (from-to-cord from)
        ~&  >  ["%api/anthropic: creating call" id caller]
        =/  call-road=road:tarball
          (cord-to-road:tarball (crip "./calls/{(trip id)}.json"))
        =/  call-content=json
          %-  pairs:enjs:format
          :~  ['status' s+'pending']
              ['request' u.body]
              ['from' s+caller]
          ==
        ;<  ~  bind:m  (make:io call-road |+[[[/ %json] call-content] ~])
        $
          ::  /calls/[id].json: read request, make HTTP call, write response
          ::
          [[%calls ~] *]
        ;<  ~  bind:m  (rise-wait:io prod "%api/anthropic call: failed")
        ::  read own content (the pending request)
        ;<  own=json  bind:m  (get-state-as:io ,json)
        ?.  ?=(%o -.own)
          ~&  >>>  "%api/anthropic call: bad content"
          (pure:m ~)
        =/  request=(unit json)  (~(get by p.own) 'request')
        =/  caller=@t
          =/  f=(unit json)  (~(get by p.own) 'from')
          ?~  f  ''
          ?.  ?=(%s -.u.f)  ''
          p.u.f
        ?~  request
          ~&  >>>  "%api/anthropic call: no request in content"
          (pure:m ~)
        ::  read config for credentials
        ;<  cfg=api-config  bind:m  read-config
        ?:  =('' api-key.cfg)
          ~&  >>>  "%api/anthropic call: no api-key"
          =/  err=json
            (pairs:enjs:format ~[['status' s+'done'] ['response' (pairs:enjs:format ~[['error' s+'no api-key configured']])]])
          ;<  ~  bind:m  (replace:io err)
          (pure:m ~)
        ::  build and send HTTP request
        =/  body-cord=@t  (en:json:html u.request)
        =/  hed=(list [key=@t value=@t])
          :~  ['content-type' 'application/json']
              ['x-api-key' api-key.cfg]
              ['anthropic-version' '2023-06-01']
          ==
        ~&  >  "%api/anthropic call: sending HTTP request"
        ;<  ~  bind:m
          (send-request:io [%'POST' url.cfg hed `(as-octs:mimes:html body-cord)])
        ;<  resp=client-response:iris  bind:m  take-http-response
        ::  extract response body
        =/  resp-json=json
          ?.  ?=(%finished -.resp)
            (pairs:enjs:format ~[['error' s+'HTTP request failed']])
          ?~  full-file.resp
            (pairs:enjs:format ~[['error' s+'empty response']])
          =/  body=@t  q.data.u.full-file.resp
          (fall (mole |.((need (de:json:html body)))) (pairs:enjs:format ~[['error' s+'JSON parse failed']]))
        ::  extract and accumulate usage
        ;<  ~  bind:m  (accumulate-usage resp-json caller)
        ::  write response — this triggers news for subscribers
        =/  result=json
          (pairs:enjs:format ~[['status' s+'done'] ['response' resp-json]])
        ~&  >  "%api/anthropic call: writing response"
        ;<  ~  bind:m  (replace:io result)
        ::  done — fiber exits, file remains for caller to read and clean up
        (pure:m ~)
      ==
    --
::
|%
::
+$  api-config
  $:  api-key=@t
      url=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,api-config)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball '../config.json')
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m ['' ''])
  =/  cfg=json  (fall (mole |.(!<(json (need-vase:tarball sang.p.seen)))) *json)
  ?.  ?=(%o -.cfg)
    (pure:m ['' ''])
  =/  get
    |=  key=@t
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  ''
    p.u.v
  (pure:m [(get 'api-key') (get 'url')])
::
::  +accumulate-usage: extract usage from API response and add to usage.json
::
++  accumulate-usage
  |=  [resp=json caller=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%o -.resp)  (pure:m ~)
  =/  usage=(unit json)  (~(get by p.resp) 'usage')
  ?~  usage  (pure:m ~)
  ?.  ?=(%o -.u.usage)  (pure:m ~)
  =/  in-tok=@ud   (get-num u.usage 'input_tokens')
  =/  out-tok=@ud  (get-num u.usage 'output_tokens')
  =/  cache-read=@ud   (get-num u.usage 'cache_read_input_tokens')
  =/  cache-write=@ud  (get-num u.usage 'cache_creation_input_tokens')
  ::  read model from response
  =/  model=@t
    =/  req=(unit json)  (~(get by p.resp) 'model')
    ?~  req  ''
    ?.  ?=(%s -.u.req)  ''
    p.u.req
  ::  read current usage
  =/  usage-road=road:tarball  (cord-to-road:tarball '../usage.json')
  ;<  usage-seen=seen:nexus  bind:m  (peek:io usage-road `[/ %json])
  =/  cur=json
    ?.  ?=([%& %file *] usage-seen)  [%o ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.p.usage-seen)))) [%o ~])
  ?.  ?=(%o -.cur)  (pure:m ~)
  ::  build call entry + updated call log
  =/  old-calls=(list json)
    =/  c=(unit json)  (~(get by p.cur) 'calls')
    ?~  c  ~
    ?.  ?=(%a -.u.c)  ~
    p.u.c
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['in' (numb:enjs:format in-tok)]
        ['out' (numb:enjs:format out-tok)]
        ['cache-read' (numb:enjs:format cache-read)]
        ['cache-write' (numb:enjs:format cache-write)]
        ['model' s+model]
        ['from' s+caller]
        ['time' (sect:enjs:format now)]
    ==
  =/  new-calls=json  [%a [entry old-calls]]
  ::  accumulate totals
  =/  new=json
    %-  pairs:enjs:format
    :~  ['input-tokens' (numb:enjs:format (add in-tok (get-num cur 'input-tokens')))]
        ['output-tokens' (numb:enjs:format (add out-tok (get-num cur 'output-tokens')))]
        ['cache-read-tokens' (numb:enjs:format (add cache-read (get-num cur 'cache-read-tokens')))]
        ['cache-write-tokens' (numb:enjs:format (add cache-write (get-num cur 'cache-write-tokens')))]
        ['requests' (numb:enjs:format (add 1 (get-num cur 'requests')))]
        ['calls' new-calls]
    ==
  ;<  ~  bind:m  (over:io usage-road [/ %json] new)
  (pure:m ~)
::
::  +from-to-cord: convert poke source to a readable identifier
::
++  from-to-cord
  |=  =from:fiber:nexus
  ^-  @t
  ?-  -.from
    %|  (crip "ext:{(scow %p src.p.from)}")
    %&  =/  =rail:tarball  q.p.from
        %-  crip
        =/  parts=(list @ta)  (snoc path.rail name.rail)
        =|  acc=tape
        |-
        ?~  parts  acc
        ?~  acc  $(parts t.parts, acc (trip i.parts))
        $(parts t.parts, acc (weld acc `tape`['/' (trip i.parts)]))
  ==
::
++  get-num
  |=  [obj=json key=@t]
  ^-  @ud
  ?.  ?=(%o -.obj)  0
  =/  v=(unit json)  (~(get by p.obj) key)
  ?~  v  0
  ?+  -.u.v  0
    %n  (fall (rush p.u.v dem) 0)
  ==
::
::  +usage-page: UI for viewing API usage stats
::
++  usage-page
  ^-  manx
  ;html
    ;head
      ;title: API Usage
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  %-  trip
        %-  crip
        ;:  weld
          "* \{ margin: 0; padding: 0; box-sizing: border-box; }"
          "body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; height: 100vh; }"
          "#app \{ display: flex; flex-direction: column; height: 100vh; }"
          "#header \{ padding: 12px 16px; border-bottom: 1px solid #333; flex-shrink: 0; display: flex; justify-content: space-between; align-items: flex-start; }"
          "#header h1 \{ font-size: 20px; font-weight: 700; }"
          "#header > div \{ display: flex; gap: 6px; }"
          ".f3 \{ color: #888; }"
          ".mono \{ font-family: monospace; }"
          ".s-2 \{ font-size: 12px; }"
          ".hdr-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid #444; background: none; color: #888; cursor: pointer; font-family: inherit; }"
          ".hdr-btn:hover \{ color: #eee; border-color: #666; }"
          ".hdr-btn.danger \{ border-color: #a33; color: #f66; }"
          ".hdr-btn.danger:hover \{ color: #f87171; border-color: #f87171; background: rgba(248,113,113,0.08); }"
          "#content \{ flex: 1; overflow-y: auto; max-width: 700px; width: 100%; margin: 0 auto; padding: 16px; }"
          ".stats \{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-bottom: 24px; }"
          ".stat \{ background: #1a1a1a; border: 1px solid #333; border-radius: 6px; padding: 14px; }"
          ".stat .label \{ color: #888; font-size: 11px; text-transform: uppercase; margin-bottom: 4px; }"
          ".stat .value \{ color: #fff; font-size: 22px; font-weight: bold; font-family: monospace; }"
          ".cost \{ color: #4ade80; }"
          "h2 \{ font-size: 14px; font-weight: 600; color: #888; text-transform: uppercase; margin-bottom: 8px; }"
          "table \{ width: 100%; border-collapse: collapse; }"
          "th \{ text-align: left; color: #666; font-size: 11px; text-transform: uppercase; padding: 6px 8px; border-bottom: 1px solid #333; }"
          "td \{ padding: 6px 8px; border-bottom: 1px solid #222; font-size: 13px; font-family: monospace; }"
          "td.caller \{ max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }"
          "#error \{ color: #f87171; margin: 8px 16px; font-size: 13px; }"
          "#flash \{ color: #4ade80; font-size: 12px; margin-left: 8px; }"
          ::  modal shared styles
          ".modal-bg \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }"
          ".modal-bg.open \{ display: flex; align-items: center; justify-content: center; }"
          ".modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }"
          ".modal-hdr \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }"
          ".modal-hdr span \{ font-size: 14px; font-weight: 600; }"
          ".modal-hdr div \{ display: flex; gap: 6px; }"
          ".modal-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }"
          ".cfg-label \{ display: block; font-size: 12px; color: #888; margin: 12px 0 4px; }"
          ".cfg-label:first-child \{ margin-top: 0; }"
          ".cfg-input \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }"
          ".cfg-input:focus \{ border-color: #2563eb; }"
          "textarea.cfg-input \{ resize: vertical; }"
          ".rate-row \{ display: flex; gap: 6px; align-items: center; margin-bottom: 6px; }"
          ".rate-row .r-model \{ flex: 2; }"
          ".rate-row .r-price \{ flex: 1; }"
          ".rate-row .r-del \{ width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: #555; font-size: 16px; line-height: 1; border: none; background: none; border-radius: 4px; }"
          ".rate-row .r-del:hover \{ color: #f87171; background: rgba(248,113,113,0.08); }"
          ".rate-hdr \{ display: flex; gap: 6px; margin-bottom: 6px; }"
          ".rate-hdr span \{ font-size: 10px; color: #666; text-transform: uppercase; }"
          ".rate-hdr .r-model \{ flex: 2; }"
          ".rate-hdr .r-price \{ flex: 1; }"
          ".rate-hdr .r-del \{ width: 24px; }"
          "@media (max-width: 600px) \{"
          "  #header \{ flex-direction: column; gap: 6px; }"
          "  #header > div \{ flex-wrap: wrap; }"
          "  #content \{ padding: 12px; }"
          "  .stats \{ grid-template-columns: repeat(2, 1fr); gap: 8px; }"
          "  .stat .value \{ font-size: 18px; }"
          "  table \{ display: block; overflow-x: auto; -webkit-overflow-scrolling: touch; }"
          "  thead \{ min-width: 600px; display: table; width: 100%; }"
          "  tbody \{ min-width: 600px; display: table; width: 100%; }"
          "  td, th \{ padding: 6px 6px; font-size: 12px; }"
          "}"
        ==
      ==
    ==
    ;body
      ;div(id "app")
        ;div(id "header")
          ;div
            ;h1: API Usage
            ;div(class "f3 mono s-2"): anthropic proxy
          ==
          ;div
            ;button(class "hdr-btn", onclick "openConfig()"): config
            ;button(class "hdr-btn", onclick "openRates()"): rates
            ;button(class "hdr-btn danger", onclick "resetUsage()"): reset
            ;span(id "flash");
          ==
        ==
        ;div(id "error");
        ::  config modal (api-key, url)
        ;div(id "cfg-backdrop", class "modal-bg")
          ;div(class "modal")
            ;div(class "modal-hdr")
              ;span: Config
              ;div
                ;button(class "hdr-btn", onclick "saveConfig()"): save
                ;button(class "hdr-btn", onclick "closeModal('cfg-backdrop')"): close
              ==
            ==
            ;label(class "cfg-label"): API Key
            ;input(id "cfg-key", class "cfg-input", type "password", placeholder "sk-ant-...");
            ;label(class "cfg-label"): URL
            ;input(id "cfg-url", class "cfg-input", type "text", placeholder "https://api.anthropic.com/v1/messages");
            ;div(id "cfg-status", class "modal-status");
          ==
        ==
        ::  rates modal (per-model table)
        ;div(id "rates-backdrop", class "modal-bg")
          ;div(class "modal", style "max-width: 520px;")
            ;div(class "modal-hdr")
              ;span: Rates ($/million tokens)
              ;div
                ;button(class "hdr-btn", onclick "saveRates()"): save
                ;button(class "hdr-btn", onclick "closeModal('rates-backdrop')"): close
              ==
            ==
            ;div(id "rates-rows");
            ;div(style "margin-top: 10px;")
              ;button(class "hdr-btn", onclick "addRateRow('','',' ')"): + add model
            ==
            ;div(id "rates-status", class "modal-status");
          ==
        ==
        ;div(id "content")
          ;div(class "stats")
            ;div(class "stat")
              ;div(class "label"): Input Tokens
              ;div(class "value", id "in-tok"): -
            ==
            ;div(class "stat")
              ;div(class "label"): Output Tokens
              ;div(class "value", id "out-tok"): -
            ==
            ;div(class "stat")
              ;div(class "label"): Cache Read
              ;div(class "value", id "cache-read"): -
            ==
            ;div(class "stat")
              ;div(class "label"): Cache Write
              ;div(class "value", id "cache-write"): -
            ==
            ;div(class "stat")
              ;div(class "label"): Requests
              ;div(class "value", id "requests"): -
            ==
            ;div(class "stat")
              ;div(class "label"): Estimated Cost
              ;div(class "value cost", id "total-cost"): -
            ==
          ==
          ;h2: Cost by Caller
          ;table
            ;thead
              ;tr
                ;th: Caller
                ;th: Requests
                ;th: In
                ;th: Out
                ;th: Cost
              ==
            ==
            ;tbody(id "caller-log");
          ==
          ;h2(style "margin-top: 24px;"): Recent Calls
          ;table
            ;thead
              ;tr
                ;th: #
                ;th: Time
                ;th: Caller
                ;th: Model
                ;th: In
                ;th: Cache R
                ;th: Cache W
                ;th: Out
                ;th: Cost
              ==
            ==
            ;tbody(id "call-log");
          ==
        ==
      ==
      ;script
        ;+  ;/  %-  trip
        %-  crip
        ;:  weld
          "var P=location.pathname.replace(/page\\.html$/,'');\0a"
          "var OVER=P.replace('/ball/','/api/over/');\0a"
          "var RATES=null;\0a"
          "function fmt(n)\{ return n.toLocaleString(); }\0a"
          "function fmtTime(t)\{ if(!t) return '-'; var d=new Date(t*1000); return d.toLocaleDateString()+' '+d.toLocaleTimeString(); }\0a"
          "function $(id)\{ return document.getElementById(id); }\0a"
          "function rate(model,dir)\{\0a"
          "  if(!RATES||!RATES[model]) return 0;\0a"
          "  return parseFloat(RATES[model][dir]||'0');\0a"
          "}\0a"
          "function callCost(c)\{\0a"
          "  var ri=rate(c.model,'in'), ro=rate(c.model,'out');\0a"
          "  var cr=(c['cache-read']||0), cw=(c['cache-write']||0);\0a"
          "  return ((c.in||0)/1e6)*ri + (cr/1e6)*(ri*0.1) + (cw/1e6)*(ri*1.25) + ((c.out||0)/1e6)*ro;\0a"
          "}\0a"
          "function load()\{\0a"
          "  Promise.all([\0a"
          "    fetch(P+'usage.json').then(r=>r.json()),\0a"
          "    fetch(P+'rates.json').then(r=>r.json())\0a"
          "  ]).then(([u,r])=>\{\0a"
          "    RATES=r;\0a"
          "    $('in-tok').textContent=fmt(u['input-tokens']||0);\0a"
          "    $('out-tok').textContent=fmt(u['output-tokens']||0);\0a"
          "    $('cache-read').textContent=fmt(u['cache-read-tokens']||0);\0a"
          "    $('cache-write').textContent=fmt(u['cache-write-tokens']||0);\0a"
          "    $('requests').textContent=fmt(u['requests']||0);\0a"
          "    var totalCost=0;\0a"
          "    (u.calls||[]).forEach(function(cl)\{ totalCost+=callCost(cl); });\0a"
          "    $('total-cost').textContent='$'+totalCost.toFixed(4);\0a"
          "    var callers=Object.create(null);\0a"
          "    (u.calls||[]).forEach(function(cl)\{\0a"
          "      var f=cl.from||'unknown';\0a"
          "      if(!callers[f]) callers[f]=\{reqs:0,in:0,out:0,cost:0};\0a"
          "      callers[f].reqs++; callers[f].in+=(cl.in||0); callers[f].out+=(cl.out||0); callers[f].cost+=callCost(cl);\0a"
          "    });\0a"
          "    var ct=$('caller-log'); ct.innerHTML='';\0a"
          "    Object.keys(callers).sort().forEach(function(f)\{\0a"
          "      var c=callers[f]; var r=document.createElement('tr');\0a"
          "      r.innerHTML='<td class=caller title=\"'+f+'\">'+f+'</td><td>'+c.reqs+'</td><td>'+fmt(c.in)+'</td><td>'+fmt(c.out)+'</td><td class=cost>$'+c.cost.toFixed(4)+'</td>';\0a"
          "      ct.appendChild(r);\0a"
          "    });\0a"
          "    var tb=$('call-log'); tb.innerHTML='';\0a"
          "    (u.calls||[]).forEach(function(cl,i)\{\0a"
          "      var r=document.createElement('tr');\0a"
          "      var cc=callCost(cl);\0a"
          "      var cf=cl.from||'-';\0a"
          "      r.innerHTML='<td>'+(i+1)+'</td><td>'+fmtTime(cl.time)+'</td><td class=caller title=\"'+cf+'\">'+cf+'</td><td>'+(cl.model||'-')+'</td><td>'+fmt(cl.in||0)+'</td><td>'+fmt(cl['cache-read']||0)+'</td><td>'+fmt(cl['cache-write']||0)+'</td><td>'+fmt(cl.out||0)+'</td><td class=cost>$'+cc.toFixed(4)+'</td>';\0a"
          "      tb.appendChild(r);\0a"
          "    });\0a"
          "  }).catch(e=>\{ $('error').textContent='Failed to load: '+e; });\0a"
          "}\0a"
          ::  modal helpers
          "function closeModal(id)\{ $(id).classList.remove('open'); }\0a"
          "document.querySelectorAll('.modal-bg').forEach(bg=>\{\0a"
          "  bg.onclick=function(e)\{ if(e.target===bg) bg.classList.remove('open'); };\0a"
          "});\0a"
          ::  config modal
          "function openConfig()\{\0a"
          "  $('cfg-status').textContent='';\0a"
          "  fetch(P+'config.json').then(r=>r.json()).then(c=>\{\0a"
          "    $('cfg-key').value=c['api-key']||'';\0a"
          "    $('cfg-url').value=c.url||'';\0a"
          "  }).catch(()=>\{});\0a"
          "  $('cfg-backdrop').classList.add('open');\0a"
          "}\0a"
          "function saveConfig()\{\0a"
          "  var key=$('cfg-key').value.trim();\0a"
          "  var url=$('cfg-url').value.trim()||'https://api.anthropic.com/v1/messages';\0a"
          "  fetch(OVER+'config.json?mark=json',\{method:'POST',headers:\{'content-type':'application/json'},\0a"
          "    body:JSON.stringify(\{'api-key':key,url:url})\0a"
          "  }).then(r=>\{\0a"
          "    var s=$('cfg-status');\0a"
          "    if(r.ok)\{ s.textContent='saved'; s.style.color='#4ade80'; setTimeout(()=>closeModal('cfg-backdrop'),800); }\0a"
          "    else\{ s.textContent='save failed'; s.style.color='#f87171'; }\0a"
          "  });\0a"
          "}\0a"
          ::  rates modal
          "function addRateRow(model,inR,outR)\{\0a"
          "  var c=$('rates-rows');\0a"
          "  var d=document.createElement('div'); d.className='rate-row';\0a"
          "  d.innerHTML='<input class=\"cfg-input r-model\" placeholder=\"model-id\" value=\"'+model+'\">'\0a"
          "    +'<input class=\"cfg-input r-price\" type=\"number\" step=\"0.01\" placeholder=\"in\" value=\"'+inR+'\">'\0a"
          "    +'<input class=\"cfg-input r-price\" type=\"number\" step=\"0.01\" placeholder=\"out\" value=\"'+outR+'\">'\0a"
          "    +'<button class=\"r-del\" onclick=\"this.parentNode.remove()\">&times;</button>';\0a"
          "  c.appendChild(d);\0a"
          "}\0a"
          "function openRates()\{\0a"
          "  $('rates-status').textContent='';\0a"
          "  $('rates-rows').innerHTML='<div class=\"rate-hdr\"><span class=\"r-model\">Model</span><span class=\"r-price\">In</span><span class=\"r-price\">Out</span><span class=\"r-del\"></span></div>';\0a"
          "  fetch(P+'rates.json').then(r=>r.json()).then(j=>\{\0a"
          "    Object.keys(j).forEach(m=>addRateRow(m,j[m].in||'0',j[m].out||'0'));\0a"
          "  }).catch(()=>\{});\0a"
          "  $('rates-backdrop').classList.add('open');\0a"
          "}\0a"
          "function saveRates()\{\0a"
          "  var rows=$('rates-rows').querySelectorAll('.rate-row');\0a"
          "  var obj=Object.create(null);\0a"
          "  rows.forEach(r=>\{\0a"
          "    var inputs=r.querySelectorAll('input');\0a"
          "    var m=inputs[0].value.trim(); if(!m) return;\0a"
          "    obj[m]=\{in:inputs[1].value||'0',out:inputs[2].value||'0'};\0a"
          "  });\0a"
          "  fetch(OVER+'rates.json?mark=json',\{method:'POST',headers:\{'content-type':'application/json'},body:JSON.stringify(obj)\0a"
          "  }).then(r=>\{\0a"
          "    var s=$('rates-status');\0a"
          "    if(r.ok)\{ s.textContent='saved'; s.style.color='#4ade80'; setTimeout(()=>closeModal('rates-backdrop'),600); load(); }\0a"
          "    else\{ s.textContent='save failed'; s.style.color='#f87171'; }\0a"
          "  });\0a"
          "}\0a"
          ::  reset
          "function resetUsage()\{\0a"
          "  if(!confirm('Reset all usage data? This cannot be undone.')) return;\0a"
          "  fetch(OVER+'usage.json?mark=json',\{method:'POST',headers:\{'content-type':'application/json'},\0a"
          "    body:JSON.stringify(\{'input-tokens':0,'output-tokens':0,'cache-read-tokens':0,'cache-write-tokens':0,'requests':0,'calls':[]})\0a"
          "  }).then(r=>\{\0a"
          "    if(!r.ok)\{ $('error').textContent='Reset failed'; return; }\0a"
          "    flash('Reset'); load();\0a"
          "  }).catch(e=>\{ $('error').textContent='Reset failed: '+e; });\0a"
          "}\0a"
          "function flash(t)\{ $('flash').textContent=t; setTimeout(()=>$('flash').textContent='',2000); }\0a"
          "load(); setInterval(load, 5000);\0a"
        ==
      ==
    ==
  ==
::
++  take-http-response
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
    =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
    ?:  ?=(%cancel -.resp)
      [%fail ~[leaf+"HTTP request cancelled"]]
    [%done resp]
  ==
--
