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
/&  man      ../man/github/readme.md
/<  ui-html  github/index.html
/<  ui-js    github/app.js
/<  ui-css   github/style.css
/<  ui-icon  github/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'GitHub'
            info+s+'The ship\'s GitHub proxy'
            color+s+'#24292f'
            image+s+'/grubbery/tiles/icon/github.github'
            href+s+'/grubbery/github'
        ==
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['token' s+'']
            ['api' s+'https://api.github.com']
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'github'] ['description' s+'Local structured proxy for GitHub']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %| /calls empty-dir:loader]
          [%fall %| /xfer empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%github/main: failed")
        main-loop
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%github/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/github])
        (http-dispatch:io %github)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%github/req: failed")
        (serve name.rail)
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
          (line '/sys/eyre/' 'bind the UI route and send page responses')
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
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  +serve: the introspection UI. Static shell + api:
::    GET  /api/status          {tokenSet, api, calls, xfers}
::    GET  /api/activity        recent calls + xfers, summarized
::    GET  /api/call?id=        one call grub, verbatim
::    POST /api/config          {token?, api?} merge (token never echoed)
::    POST /api/call            {method, path, body?} -> {id}
::    POST /api/sweep           cull every done/failed lifecycle grub
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
  =/  prefix=path  /grubbery/github
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
      [%api %status ~]
    ;<  cfg=[token=@t api=@t]  bind:m  read-config
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    ;<  xfers=view:nexus  bind:m  (peek:io [%| 1 %| /xfer] ~)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['tokenSet' b+!=('' token.cfg)]
        ['api' s+api.cfg]
        ['calls' (numb:enjs:format (count-files calls))]
        ['xfers' (numb:enjs:format (count-files xfers))]
    ==
  ::
      [%api %activity ~]
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    ;<  xfers=view:nexus  bind:m  (peek:io [%| 1 %| /xfer] ~)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['calls' a+(call-summaries calls)]
        ['xfers' a+(xfer-summaries xfers)]
    ==
  ::
      [%api %call ~]
    =/  id=(unit @t)  (~(get by (malt args)) 'id')
    ?~  id  (reply eyre-id 400 'id required')
    ;<  res=(unit json)  bind:m
      (peek-as:io [%| 1 %& /calls (crip "{(trip u.id)}.json")] ,json)
    ?~  res  (reply eyre-id 404 'no such call')
    (send-json eyre-id u.res)
  ::
      [%api %config ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=(%o -.u.jon)  (reply eyre-id 400 'object required')
    ;<  cur=(unit json)  bind:m
      (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)
      ?~  cur  ~
      ?.(?=(%o -.u.cur) ~ p.u.cur)
    =/  tok=(unit json)  (~(get by p.u.jon) 'token')
    =/  api=(unit json)  (~(get by p.u.jon) 'api')
    =?  om  &(?=(^ tok) ?=([%s *] u.tok) !=('' p.u.tok))  (~(put by om) 'token' u.tok)
    =?  om  &(?=(^ api) ?=([%s *] u.api) !=('' p.u.api))  (~(put by om) 'api' u.api)
    ;<  ~  bind:m  (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %call-new ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=(%o -.u.jon)  (reply eyre-id 400 'object required')
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  id=@t  (crip ((x-co:co 16) (end 6 eny)))
    =/  content=json
      %-  pairs:enjs:format
      :~  ['status' s+'pending']
          ['request' u.jon]
      ==
    =/  call-road=road:tarball
      [%| 1 %& /calls (crip "{(trip id)}.json")]
    ;<  err=(unit tang)  bind:m
      (make-soft:io call-road |+[[[/ %json] content] ~])
    ?^  err  (reply eyre-id 500 'could not create call')
    ;<  ~  bind:m  (gain:io call-road %.y)
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ::
      [%api %sweep ~]
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    ;<  xfers=view:nexus  bind:m  (peek:io [%| 1 %| /xfer] ~)
    =/  done-calls=(list @ta)
      %+  murn  (file-entries calls)
      |=  [nam=@ta =sang:tarball]
      ?:(=('pending' (call-status sang)) ~ `nam)
    =/  done-xfers=(list @ta)
      %+  murn  (file-entries xfers)
      |=  [nam=@ta =sang:tarball]
      ?:(=(%pending (xfer-status sang)) ~ `nam)
    =/  culls
      %+  weld
        (turn done-calls |=(n=@ta `road:tarball`[%| 1 %& /calls n]))
      (turn done-xfers |=(n=@ta `road:tarball`[%| 1 %& /xfer n]))
    =/  n=@ud  (lent culls)
    |-
    ?~  culls
      (send-json eyre-id (pairs:enjs:format ~[['swept' (numb:enjs:format n)]]))
    ;<  *  bind:m  (cull-soft:io i.culls)
    $(culls t.culls)
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
  (fall (bind (~(get by p.u.jon) 'status') |=(=json ?>(?=(%s -.json) p.json))) '')
++  xfer-status
  |=  =sang:tarball
  ^-  @tas
  =/  n=*  (sang-noun:tarball sang)
  ?@  n  %$
  ?.  ?=(?(%pending %done %fail) -.n)  %$
  ;;(@tas -.n)
++  call-summaries
  |=  =view:nexus
  ^-  (list json)
  %+  turn  (file-entries view)
  |=  [nam=@ta =sang:tarball]
  =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang))))
  =/  gets
    |=  pth=(list @t)
    ^-  @t
    ?~  jon  ''
    =/  cur=json  u.jon
    |-
    ?~  pth  ?:(?=([%s *] cur) p.cur '')
    ?.  ?=(%o -.cur)  ''
    =/  nxt  (~(get by p.cur) i.pth)
    ?~  nxt  ''
    $(cur u.nxt, pth t.pth)
  =/  code=@t
    ?~  jon  ''
    ?.  ?=(%o -.u.jon)  ''
    =/  c  (~(get by p.u.jon) 'code')
    ?:(?=([~ %n *] c) p.u.c '')
  %-  pairs:enjs:format
  :~  ['id' s+nam]
      ['status' s+(gets ~['status'])]
      ['method' s+(gets ~['request' 'method'])]
      ['path' s+(gets ~['request' 'path'])]
      ['code' s+code]
  ==
++  xfer-summaries
  |=  =view:nexus
  ^-  (list json)
  %+  turn  (file-entries view)
  |=  [nam=@ta =sang:tarball]
  %-  pairs:enjs:format
  :~  ['id' s+nam]
      ['status' s+(xfer-status sang)]
  ==
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
