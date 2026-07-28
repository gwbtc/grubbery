/<  odb  /lib/nex/obelisk-db.hoon
/<  index-html  guestbook/index.html
/<  guestbook-js  guestbook/guestbook.js
/<  icon  guestbook/icon.svg
=<  ^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  tile=json
    %-  pairs:enjs:format
    :~  title+s+'Guestbook'
        info+s+'Sign the guestbook'
        color+s+'#6b8aad'
        image+s+'/grubbery/tiles/icon/test.guestbook'
        href+s+'/grubbery/guestbook'
    ==
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'tile.json'] [[/ %json] tile]]
      [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
      [%over %& [/ %'index.html'] [[/ %mime] index-html]]
      [%over %& [/ %'guestbook.js'] [[/ %mime] guestbook-js]]
      (db-entry:odb %'db.guestbook')
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
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
      [~ %'db.guestbook']
    (db-spool:odb prod)
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%guestbook /main: failed")
    =/  db-road=road:tarball  [%| 0 %& / %'db.guestbook']
    =/  init-sql=@t
      %-  crip
      ;:  weld
        "CREATE DATABASE db; "
        "CREATE TABLE db..guestbook (id @da, name @t, message @t) PRIMARY KEY (id)"
      ==
    =/  init-json=json  (pairs:enjs:format ~[['query' s+init-sql]])
    ;<  ~  bind:m  (poke:io db-road [[/ %json] init-json])
    ;<  =sage:tarball  bind:m  take-poke:io
    ~&  >  "%guestbook: db initialized"
    ;<  ~  bind:m  (bind-http:io [~ /grubbery/guestbook])
    (http-dispatch:io %guestbook)
      ::
      [[%requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%guestbook /requests: failed")
    =/  srv  ~(. http-res:io (nex-road:io rail [%& ~ %'main.sig']))
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
    =/  prefix=path  /grubbery/guestbook
    =/  site=path  site:(parse-url:http-utils url.request.req)
    =/  suffix=path  (slag (lent prefix) site)
    =/  db-road=road:tarball  (nex-road:io rail [%& / %'db.guestbook'])
    ?+    suffix
      ::  static files
      =/  filename=@ta
        ?~  suffix  'index.html'
        i.suffix
      ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%& / filename]) `[/ %mime])
      ?.  ?=([%file *] view)
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      =/  =mime  !<(mime (need-vase:tarball sang.view))
      ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
      (pure:m ~)
        ::
        [%api %whoami ~]
      =/  who=json
        %-  pairs:enjs:format
        :~  ['ship' s+(scot %p src)]
            ['authenticated' b+authenticated.req]
        ==
      =/  bod=octs  (as-octs:mimes:html (en:json:html who))
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
      (pure:m ~)
        ::
        [%api %entries ~]
      =/  sql=tape  "FROM db..guestbook SELECT name, message"
      =/  poke-json=json
        %-  pairs:enjs:format
        :~  ['query' s+(crip sql)]
        ==
      ;<  ~  bind:m  (poke:io db-road [[/ %json] poke-json])
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  result=json  !<(json q.sage)
      =/  rows=json  (flatten-results result)
      =/  bod=octs  (as-octs:mimes:html (en:json:html rows))
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
      (pure:m ~)
        ::
        [%api %post ~]
      ?.  =(%'POST' method.request.req)
        ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
        (pure:m ~)
      ?.  authenticated.req
        ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Log in to sign')])
        (pure:m ~)
      =/  bod=(unit octs)  body.request.req
      ?~  bod
        ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
        (pure:m ~)
      =/  jon=(unit json)  (de:json:html q.u.bod)
      ?~  jon
        ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
        (pure:m ~)
      ?.  ?=([%o *] u.jon)
        ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Expected object')])
        (pure:m ~)
      ::  signer identity comes from the eyre session, never the client
      =/  name-val=tape  (trip (scot %p src))
      =/  msg-val=tape
        =/  v  (~(get by p.u.jon) 'message')
        ?~(v ~ ?.(?=([%s *] u.v) ~ (trip p.u.v)))
      ?:  ?~(msg-val & |)
        ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing message')])
        (pure:m ~)
      ;<  now=@da  bind:m  get-time:io
      =/  sql=tape
        ;:  weld
          "INSERT INTO db..guestbook (id, name, message) VALUES ("
          (trip (scot %da now))
          ", '"
          (sanitize name-val)
          "', '"
          (sanitize msg-val)
          "')"
        ==
      =/  poke-json=json
        %-  pairs:enjs:format
        :~  ['query' s+(crip sql)]
        ==
      ;<  ~  bind:m  (poke:io db-road [[/ %json] poke-json])
      ;<  =sage:tarball  bind:m  take-poke:io
      =/  bod=octs  (as-octs:mimes:html '{"ok":true}')
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
      (pure:m ~)
    ==
  ==
--
|%
++  sanitize
  |=  t=tape
  ^-  tape
  %-  zing
  %+  turn  t
  |=  c=@t
  ?:(=('\'' c) "''" [c ~])
::
++  flatten-results
  |=  =json
  ^-  ^json
  ?.  ?=([%o *] json)  json
  =/  results  (~(get by p.json) 'results')
  ?~  results  json
  ?.  ?=([%a *] u.results)  json
  =/  rows=(list ^json)
    %+  turn  p.u.results
    |=  cmd=^json
    ?.  ?=([%o *] cmd)  cmd
    =/  rs  (~(get by p.cmd) 'result-set')
    ?~  rs  cmd
    ?.  ?=([%a *] u.rs)  cmd
    :-  %a
    %+  turn  p.u.rs
    |=  row=^json
    row
  ?~  rows  [%a ~]
  i.rows
--
