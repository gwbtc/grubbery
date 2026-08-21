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
          [%fall %& [/ %'auth.json'] [[/ %json] (pairs:enjs:format ~[['status' s+'idle']])]]
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
          [~ %'auth.json']
        ;<  ~  bind:m  (rise-wait:io prod "%github/auth: failed")
        run-auth
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
          (line '/sys/behn/' 'timers for polling the OAuth device flow')
      ==
  ==
::  client-id: the registered "Grubbery" OAuth App (device flow enabled).
::  Public by design — it names the app to GitHub; it is not a secret.
::
++  client-id  'Ov23liQkxjTNOKj8ejW2'
::  +$  xreq: a git smart-HTTP transport request. repo is 'owner/name'.
::
+$  xreq
  $%  [%discovery account=@t repo=@t]
      [%pack account=@t repo=@t body=octs]
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
  ?.  ?=(%o -.own)  stay:m
  =/  status=@t
    (fall (bind (~(get by p.own) 'status') |=(=json ?>(?=(%s -.json) p.json))) '')
  ?.  =('pending' status)  stay:m      ::  reboot after completion: done
  =/  req=json  (fall (~(get by p.own) 'request') *json)
  ?.  ?=(%o -.req)  stay:m
  =/  gets  ~(get by p.req)
  =/  method=@t
    (fall (bind (gets 'method') |=(=json ?>(?=(%s -.json) p.json))) 'GET')
  =/  pax=@t
    (fall (bind (gets 'path') |=(=json ?>(?=(%s -.json) p.json))) '')
  =/  body=(unit json)  (gets 'body')
  =/  account=@t
    (fall (bind (gets 'account') |=(=json ?>(?=(%s -.json) p.json))) '')
  ;<  cfg=[api=@t accounts=(map @t @t)]  bind:m  read-config
  =/  url=@t  (cat 3 api.cfg pax)
  =/  =request:http
    :^    (parse-method method)
        url
      (gh-headers (pick-token accounts.cfg account))
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
  stay:m
::  +run-xfer: execute one transport request. Same lifecycle, noun
::  content, raw octs out. Auth rides along when a token is set, which
::  is what makes private-repo clone possible at all.
::
++  run-xfer
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=xlife  bind:m  (get-state-as:io ,xlife)
  ?.  ?=(%pending -.own)  stay:m
  ;<  cfg=[api=@t accounts=(map @t @t)]  bind:m  read-config
  =/  token=@t  (pick-token accounts.cfg account.req.own)
  ::  the git transport endpoints only accept HTTP Basic auth — the
  ::  REST 'token' scheme 401s there (x-access-token is the
  ::  conventional username; only the password/token part matters)
  =/  auth=(list [@t @t])
    ?:  =('' token)  ~
    =/  cred=octs  (as-octs:mimes:html (cat 3 'x-access-token:' token))
    ~[['Authorization' (cat 3 'Basic ' (~(en base64:mimes:html & |) cred))]]
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
  stay:m
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
::  +run-auth: the OAuth device flow, living on auth.json. starting ->
::  request a device code from GitHub, record it -> poll until the user
::  approves in a browser -> write the token into config.json -> done.
::  Restart-safe: the device code and deadline live in the grub, so a
::  reboot in mid-flow just resumes polling. The token never touches
::  auth.json; /api/auth strips the device code before echoing.
::
++  run-auth
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=json  bind:m  (get-state-as:io ,json)
  ;<  cid=@t  bind:m  read-client-id
  =/  status=@t  (jget own 'status')
  ?:  =('starting' status)
    ;<  res=json  bind:m
      %+  www-post  'https://github.com/login/device/code'
      (pairs:enjs:format ~[['client_id' s+cid] ['scope' s+'repo']])
    =/  device=@t    (jget res 'device_code')
    =/  user=@t      (jget res 'user_code')
    =/  uri=@t       (jget res 'verification_uri')
    =/  interval=@ud  (jnum res 'interval' 5)
    =/  expires=@ud   (jnum res 'expires_in' 900)
    ?:  =('' device)
      ;<  ~  bind:m  (replace:io (auth-fail 'no device code from github'))
      stay:m
    ;<  now=@da  bind:m  get-time:io
    =/  deadline=@da  (add now (mul expires ~s1))
    ;<  ~  bind:m
      %-  replace:io
      %-  pairs:enjs:format
      :~  ['status' s+'code']
          ['user_code' s+user]
          ['verification_uri' s+uri]
          ['device_code' s+device]
          ['interval' (numb:enjs:format interval)]
          ['deadline' s+(scot %da deadline)]
      ==
    (poll-auth cid device interval deadline)
  ?:  =('code' status)
    =/  device=@t     (jget own 'device_code')
    =/  interval=@ud  (jnum own 'interval' 5)
    =/  deadline=@da  (fall (slaw %da (jget own 'deadline')) *@da)
    ?:  =('' device)  stay:m
    (poll-auth cid device interval deadline)
  stay:m
::
++  poll-auth
  |=  [cid=@t device=@t interval=@ud deadline=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  ~  bind:m  (sleep:io (mul interval ~s1))
  ;<  now=@da  bind:m  get-time:io
  ?:  (gth now deadline)
    ;<  ~  bind:m  (replace:io (auth-fail 'device code expired'))
    stay:m
  ;<  res=json  bind:m
    %+  www-post  'https://github.com/login/oauth/access_token'
    %-  pairs:enjs:format
    :~  ['client_id' s+cid]
        ['device_code' s+device]
        ['grant_type' s+'urn:ietf:params:oauth:grant-type:device_code']
    ==
  =/  err=@t  (jget res 'error')
  ?:  =('authorization_pending' err)  $
  ?:  =('slow_down' err)  $(interval (add interval 5))
  =/  token=@t  (jget res 'access_token')
  ?:  =('' token)
    ;<  ~  bind:m  (replace:io (auth-fail ?:(=('' err) 'no token in response' err)))
    stay:m
  ::  identify the account FIRST — tokens are stored keyed by login
  ;<  cur=(unit json)  bind:m
    (peek-as:io (cord-to-road:tarball './config.json') ,json)
  =/  om=(map @t json)
    ?~  cur  ~
    ?.(?=(%o -.u.cur) ~ p.u.cur)
  =/  api=@t
    =/  a  (~(get by om) 'api')
    ?:(?=([~ %s *] a) p.u.a 'https://api.github.com')
  ;<  res=[code=@ud =octs]  bind:m
    (fetch [%'GET' (cat 3 api '/user') (gh-headers token) ~])
  =/  login=@t
    ?.  =(200 code.res)  ''
    (jget (fall (de:json:html q.octs.res) *json) 'login')
  ?:  =('' login)
    ;<  ~  bind:m  (replace:io (auth-fail 'token granted but could not read login'))
    stay:m
  =/  amap=(map @t json)
    =/  a  (~(get by om) 'accounts')
    ?.(?=([~ %o *] a) ~ p.u.a)
  =.  amap  (~(put by amap) login s+token)
  =.  om  (~(put by om) 'accounts' [%o amap])
  =.  om  (~(del by om) 'token')       ::  legacy single-token slot retired
  ;<  ~  bind:m
    %+  over:io  (cord-to-road:tarball './config.json')
    [[/ %json] `json`[%o om]]
  ;<  ~  bind:m
    (replace:io (pairs:enjs:format ~[['status' s+'done'] ['login' s+login]]))
  stay:m
::
++  auth-fail
  |=  err=@t
  (pairs:enjs:format ~[['status' s+'fail'] ['error' s+err]])
::  +read-client-id: config.json's client_id overrides the baked-in
::  default; absent or empty means the default
::
++  read-client-id
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m
    (peek-as:io (cord-to-road:tarball './config.json') ,json)
  =/  cfg=json  (fall ucfg *json)
  =/  cid=@t  ?.(?=([%o *] cfg) '' (jget cfg 'client_id'))
  (pure:m ?:(=('' cid) client-id cid))
::  +www-post: JSON round trip against github.com (not the REST api) —
::  the OAuth endpoints live on the www host and answer JSON when asked
::
++  www-post
  |=  [url=@t bod=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  =request:http
    :^    %'POST'
        url
      :~  ['User-Agent' 'grubbery']
          ['Accept' 'application/json']
          ['Content-Type' 'application/json']
      ==
    `(as-octs:mimes:html (en:json:html bod))
  ;<  res=[code=@ud =octs]  bind:m  (fetch request)
  (pure:m (fall (de:json:html q.octs.res) *json))
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
::  +read-config: api base + the connected accounts (login -> token).
::  A legacy top-level 'token' folds in under login '' so old configs
::  keep working until the next connect rewrites them properly.
::
++  read-config
  =/  m  (fiber:fiber:nexus ,[api=@t accounts=(map @t @t)])
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
  =/  cfg=json  (fall ucfg *json)
  ?.  ?=([%o *] cfg)  (pure:m ['https://api.github.com' ~])
  =/  api=@t  (jget cfg 'api')
  =.  api  ?:(=('' api) 'https://api.github.com' api)
  =/  accounts=(map @t @t)
    =/  a  (~(get by p.cfg) 'accounts')
    ?.  ?=([~ %o *] a)  ~
    %-  malt
    %+  murn  ~(tap by p.u.a)
    |=  [k=@t v=json]
    ^-  (unit [@t @t])
    ?.(?=([%s *] v) ~ `[k p.v])
  =/  legacy=@t  (jget cfg 'token')
  =?  accounts  &(=(~ accounts) !=('' legacy))  (malt ~[['' legacy]])
  (pure:m [api accounts])
::  +pick-token: a named account's token, or the FIRST account's
::  (alphabetically) when the caller doesn't care (account '')
::
++  pick-token
  |=  [accounts=(map @t @t) account=@t]
  ^-  @t
  ?.  =('' account)  (fall (~(get by accounts) account) '')
  =/  l  (sort ~(tap by accounts) |=([a=[@t @t] b=[@t @t]] (aor -.a -.b)))
  ?~(l '' q.i.l)

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
    ;<  cfg=[api=@t accounts=(map @t @t)]  bind:m  read-config
    ;<  cur=(unit json)  bind:m
      (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  override=@t
      ?~  cur  ''
      ?.(?=([%o *] u.cur) '' (jget u.cur 'client_id'))
    =/  effective=@t  ?:(=('' override) client-id override)
    ;<  calls=view:nexus  bind:m  (peek:io [%| 1 %| /calls] ~)
    ;<  xfers=view:nexus  bind:m  (peek:io [%| 1 %| /xfer] ~)
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  :-  'accounts'
        :-  %a
        (turn (sort ~(tap in ~(key by accounts.cfg)) aor) |=(l=@t `json`s+l))
        ['api' s+api.cfg]
        ['clientId' s+effective]
        ['clientIdIsDefault' b+=('' override)]
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
    =/  cid=(unit json)  (~(get by p.u.jon) 'client_id')
    =?  om  &(?=(^ tok) ?=([%s *] u.tok) !=('' p.u.tok))  (~(put by om) 'token' u.tok)
    =?  om  &(?=(^ api) ?=([%s *] u.api) !=('' p.u.api))  (~(put by om) 'api' u.api)
    ::  client_id: empty string RESETS to the baked-in default
    =?  om  &(?=(^ cid) ?=([%s *] u.cid) !=('' p.u.cid))  (~(put by om) 'client_id' u.cid)
    =?  om  &(?=(^ cid) ?=([%s *] u.cid) =('' p.u.cid))   (~(del by om) 'client_id')
    ;<  ~  bind:m  (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %token ~]
    ;<  cfg=[api=@t accounts=(map @t @t)]  bind:m  read-config
    =/  acct=@t  (fall (~(get by (malt args)) 'account') '')
    %+  send-json  eyre-id
    (pairs:enjs:format ~[['token' s+(pick-token accounts.cfg acct)]])
  ::
      [%api %disconnect ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  login=@t  (jget u.jon 'login')
    ?:  =('' login)  (reply eyre-id 400 'login required')
    ;<  cur=(unit json)  bind:m
      (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)
      ?~  cur  ~
      ?.(?=(%o -.u.cur) ~ p.u.cur)
    =/  amap=(map @t json)
      =/  a  (~(get by om) 'accounts')
      ?.(?=([~ %o *] a) ~ p.u.a)
    =.  amap  (~(del by amap) login)
    =.  om  (~(put by om) 'accounts' [%o amap])
    ;<  ~  bind:m
      (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %auth-start ~]
    ::  auth.json always exists (loader-owned); overwriting restarts
    ::  its fiber, which picks the flow up from %starting
    ;<  ~  bind:m
      %+  over:io  [%| 1 %& / %'auth.json']
      [[/ %json] (pairs:enjs:format ~[['status' s+'starting']])]
    (reply eyre-id 200 'ok')
  ::
      [%api %auth ~]
    ;<  res=(unit json)  bind:m
      (peek-as:io [%| 1 %& / %'auth.json'] ,json)
    ?~  res
      (send-json eyre-id (pairs:enjs:format ~[['status' s+'idle']]))
    =/  jon=json  u.res
    =?  jon  ?=(%o -.jon)  [%o (~(del by p.jon) 'device_code')]
    (send-json eyre-id jon)
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
