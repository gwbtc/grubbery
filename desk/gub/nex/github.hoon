::  github: local structured proxy for all GitHub traffic (issue #45).
::
::  Every consumer that wants GitHub talks to THIS nexus instead of
::  iris directly: token custody lives here once, the client etiquette
::  (auth headers, redirects) is handled once, and a consumer's weir
::  needs only this nexus — not the whole internet.
::
::    config.json  -- {token, api} (the ONE GitHub credential)
::    main.sig     -- poke to create a call
::    calls/       -- REST lifecycle grubs (json): {id, req} poked as
::                    json -> calls/[id].json {status,request} ->
::                    fiber executes -> {status: done, code, body}
::    xfer/        -- git smart-HTTP transport lifecycle grubs (noun):
::                    poked as noun [%xfer id=@t xreq] ->
::                    xfer/[id] [%pending xreq] -> [%done octs]/[%fail tang]
::
::  Flow (both kinds): keep the lifecycle grub's road FIRST, then poke
::  main.sig; read the result on news, then drop. The claw/api pattern.
::
/&  man  ../man/github/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['token' s+'']
            ['api' s+'https://api.github.com']
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'github'] ['description' s+'Local structured proxy for GitHub']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %| /calls empty-dir:loader]
          [%fall %| /xfer empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%github/main: failed")
        main-loop
          [[%calls ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%github/call: failed")
        run-call
          [[%xfer ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%github/xfer: failed")
        run-xfer
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
          (line '/sys/iris/' 'the only nexus that talks to GitHub over HTTP')
      ==
  ==
::  +$  xreq: a git smart-HTTP transport request. repo is 'owner/name'.
::
+$  xreq
  $%  [%discovery repo=@t]
      [%pack repo=@t body=octs]
  ==
+$  xlife                            ::  xfer/[id] grub content
  $%  [%pending req=xreq]
      [%done =octs]
      [%fail =tang]
  ==
::  +main-loop: accept call-creation pokes. A json poke makes a REST
::  call grub; a noun poke [%xfer id xreq] makes a transport grub.
::
++  main-loop
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  ?:  =([/ %json] p.sage)
    =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
    ?.  ?=(%o -.jon)  $
    =/  id=@t
      (fall (bind (~(get by p.jon) 'id') |=(=json ?>(?=(%s -.json) p.json))) '')
    =/  req=(unit json)  (~(get by p.jon) 'req')
    ?:  |(=('' id) ?=(~ req))
      ~&  >>>  "%github: poke missing id or req"
      $
    =/  call-road=road:tarball
      (cord-to-road:tarball (crip "./calls/{(trip id)}.json"))
    =/  content=json
      (pairs:enjs:format ~[['status' s+'pending'] ['request' u.req]])
    ;<  ~  bind:m  (make:io call-road |+[[[/ %json] content] ~])
    ;<  ~  bind:m  (gain:io call-road %.y)
    $
  ?:  =([/ %noun] p.sage)
    =/  parsed=(unit [%xfer id=@t req=xreq])
      (mole |.(;;([%xfer id=@t req=xreq] q.q.sage)))
    ?~  parsed
      ~&  >>>  "%github: bad xfer poke"
      $
    =/  xfer-road=road:tarball
      (cord-to-road:tarball (crip "./xfer/{(trip id.u.parsed)}"))
    ;<  ~  bind:m  (make:io xfer-road |+[[[/ %noun] `xlife`[%pending req.u.parsed]] ~])
    ;<  ~  bind:m  (gain:io xfer-road %.y)
    $
  ~&  >>>  "%github: unrecognized poke mark"
  $
::  +run-call: execute one REST call. Reads its own pending request,
::  attaches auth from config, follows redirects, overwrites itself
::  with the outcome. The grub then idles as the record of the call;
::  the CALLER culls it when done reading (or leaves it as history).
::
++  run-call
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=json  bind:m  (get-state-as:io ,json)
  ?.  ?=(%o -.own)  idle:io
  =/  status=@t
    (fall (bind (~(get by p.own) 'status') |=(=json ?>(?=(%s -.json) p.json))) '')
  ?.  =('pending' status)  idle:io      ::  reboot after completion: done
  =/  req=json  (fall (~(get by p.own) 'request') *json)
  ?.  ?=(%o -.req)  idle:io
  =/  gets  ~(get by p.req)
  =/  method=@t
    (fall (bind (gets 'method') |=(=json ?>(?=(%s -.json) p.json))) 'GET')
  =/  pax=@t
    (fall (bind (gets 'path') |=(=json ?>(?=(%s -.json) p.json))) '')
  =/  body=(unit json)  (gets 'body')
  ;<  cfg=[token=@t api=@t]  bind:m  read-config
  =/  url=@t  (cat 3 api.cfg pax)
  =/  =request:http
    :^    (parse-method method)
        url
      (gh-headers token.cfg)
    ?~  body  ~
    `(as-octs:mimes:html (en:json:html u.body))
  ;<  res=[code=@ud =octs]  bind:m  (fetch request)
  =/  body-json=(unit json)  (de:json:html q.octs.res)
  =/  done=json
    %-  pairs:enjs:format
    :~  ['status' s+'done']
        ['request' req]
        ['code' (numb:enjs:format code.res)]
        :-  'body'
        ?^  body-json  u.body-json
        s+q.octs.res
    ==
  ;<  ~  bind:m  (replace:io done)
  idle:io
::  +run-xfer: execute one transport request. Same lifecycle, noun
::  content, raw octs out. Auth rides along when a token is set, which
::  is what makes private-repo clone possible at all.
::
++  run-xfer
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=xlife  bind:m  (get-state-as:io ,xlife)
  ?.  ?=(%pending -.own)  idle:io
  ;<  cfg=[token=@t api=@t]  bind:m  read-config
  =/  auth=(list [@t @t])
    ?:  =('' token.cfg)  ~
    ~[['Authorization' (cat 3 'token ' token.cfg)]]
  =/  =request:http
    ?-    -.req.own
        %discovery
      :^  %'GET'
          (rap 3 ~['https://github.com/' repo.req.own '.git/info/refs?service=git-upload-pack'])
        (weld auth ~[['User-Agent' 'grubbery']])
      ~
        %pack
      :^  %'POST'
          (rap 3 ~['https://github.com/' repo.req.own '.git/git-upload-pack'])
        %+  weld  auth
        :~  ['Content-Type' 'application/x-git-upload-pack-request']
            ['User-Agent' 'grubbery']
        ==
      `body.req.own
    ==
  ;<  res=[code=@ud =octs]  bind:m  (fetch request)
  =/  out=xlife
    ?:  =(200 code.res)  [%done octs.res]
    [%fail ~[leaf+"github xfer: HTTP {(a-co:co code.res)}"]]
  ;<  ~  bind:m  (replace:io out)
  idle:io
::  +fetch: one HTTP round trip via iris, following one redirect hop
::  (github serves 301s for renamed repos and pack endpoints)
::
++  fetch
  |=  =request:http
  =/  m  (fiber:fiber:nexus ,[code=@ud =octs])
  ^-  form:m
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "%github: request did not finish"  !!
  =/  code=@ud  status-code.response-header.client-response
  ?:  |(=(301 code) =(302 code) =(307 code))
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location  ~|  "%github: redirect without location"  !!
    ;<  ~  bind:m  (send-request:io request(url u.location))
    ;<  =res=client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.res-client-response)
      ~|  "%github: redirect did not finish"  !!
    %-  pure:m
    :-  status-code.response-header.res-client-response
    ?~  full-file.res-client-response  *octs
    data.u.full-file.res-client-response
  %-  pure:m
  :-  code
  ?~  full-file.client-response  *octs
  data.u.full-file.client-response
::
++  read-config
  =/  m  (fiber:fiber:nexus ,[token=@t api=@t])
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
  =/  cfg=json  (fall ucfg *json)
  ?.  ?=(%o -.cfg)  (pure:m ['' 'https://api.github.com'])
  =/  get  |=(k=@t `@t`(fall (bind (~(get by p.cfg) k) |=(=json ?>(?=(%s -.json) p.json))) ''))
  =/  api=@t  (get 'api')
  (pure:m [(get 'token') ?:(=('' api) 'https://api.github.com' api)])

::
++  gh-headers
  |=  token=@t
  ^-  (list [@t @t])
  %+  weld
    ?:  =('' token)  ~
    ~[['Authorization' (cat 3 'token ' token)]]
  :~  ['User-Agent' 'grubbery']
      ['Accept' 'application/vnd.github.v3+json']
      ['Content-Type' 'application/json']
  ==
::
++  parse-method
  |=  m=@t
  ^-  method:http
  ?+  m  %'GET'
    %'GET'     %'GET'
    %'POST'    %'POST'
    %'PATCH'   %'PATCH'
    %'PUT'     %'PUT'
    %'DELETE'  %'DELETE'
  ==
--
