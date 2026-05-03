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
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['api-key' s+'']
            ['url' s+'https://api.anthropic.com/v1/messages']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %| /calls [~ ~] [~ ~] empty-dir:loader]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
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
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  id=@t
          (fall (bind (~(get by p.jon) 'id') |=(=json ?>(?=(%s -.json) p.json))) '')
        =/  body=(unit json)  (~(get by p.jon) 'body')
        ?:  |(=('' id) ?=(~ body))
          ~&  >>>  "%api/anthropic: missing id or body in poke"
          $
        ~&  >  ["%api/anthropic: creating call" id]
        =/  call-road=road:tarball
          (cord-to-road:tarball (crip "./calls/{(trip id)}.json"))
        =/  call-content=json
          (pairs:enjs:format ~[['status' s+'pending'] ['request' u.body]])
        ;<  ~  bind:m  (make:io call-road |+[%.n [[/ %json] !>(call-content)] ~])
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
        ?~  request
          ~&  >>>  "%api/anthropic call: no request in content"
          (pure:m ~)
        ::  read config for credentials
        ;<  cfg=api-config  bind:m  read-config
        ?:  =('' api-key.cfg)
          ~&  >>>  "%api/anthropic call: no api-key"
          =/  err=json
            (pairs:enjs:format ~[['status' s+'done'] ['response' (pairs:enjs:format ~[['error' s+'no api-key configured']])]])
          ;<  ~  bind:m  (replace:io !>(err))
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
        ::  write response — this triggers news for subscribers
        =/  result=json
          (pairs:enjs:format ~[['status' s+'done'] ['response' resp-json]])
        ~&  >  "%api/anthropic call: writing response"
        ;<  ~  bind:m  (replace:io !>(result))
        ::  done — fiber exits, file remains for caller to read and clean up
        (pure:m ~)
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Directory under the Anthropic API proxy.'
            ~
          %-  crip
          ;:  weld
            "ANTHROPIC API PROXY\0a\0a"
            "Proxies requests to the Anthropic Messages API.\0a"
            "Holds API key and URL in config.json.\0a\0a"
            "Poke main.sig with \{\"id\": \"call-id\", \"body\": \{...api body...}}.\0a"
            "Subscribe to calls/[id].json before poking to get the response.\0a"
            "Response arrives as \{\"status\": \"done\", \"response\": \{...}}.\0a"
          ==
            [%calls ~]
          'Per-request lifecycle files. Each call gets its own file and fiber.'
        ==
          %|
        ?+  rail.p.mana  'File under the Anthropic API proxy.'
          [~ %'config.json']   'API config: api-key and url.'
          [~ %'main.sig']      'Poke with JSON (id + body) to create a call in calls/.'
          [[%calls ~] *]       'API call lifecycle file. Created by main.sig, runs HTTP, writes response.'
        ==
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
  =/  cfg=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
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
++  take-http-response
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%fail ~[leaf+"HTTP request cancelled"]]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done client-response.sign.u.in]
  ==
--
