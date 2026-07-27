::  notifications: a human-addressed message bus
::
::  Applications register a name, then send notifications; the
::  service owns delivery (push) and ack tracking; payloads are
::  opaque jobjs (title/body/url are conventions, not protocol).
::
::  /main.sig         pokes: register / notify / ack / clear
::  /registry.json    { "<abs path of registrant dir>": "app name" }
::                    a registrant covers its whole subtree — any
::                    grub under it may send as that app
::  /inbox.inbox      one mop of notifications, newest first; ack is
::                    a state flip inside it
::  /ui/*             inbox page (requests pattern)
::
/<  nib  /lib/inbox.hoon
/&  inbox-html  notifications/index.html
/&  inbox-js    notifications/app.js
/&  inbox-css   notifications/style.css
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  deliberately no tile.json: the inbox is chrome, not an app —
      ::  the tiles page renders it as the bell
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'registry.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'inbox.inbox'] [[/ %inbox] *inbox:nib]]
          [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
          [%over %& [/ui %'index.html'] [[/ %mime] inbox-html]]
          [%over %& [/ui %'app.js'] [[/ %mime] inbox-js]]
          [%over %& [/ui %'style.css'] [[/ %mime] inbox-css]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::
          [[%ui ~] %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%notifications http: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/inbox])
        (http-dispatch:io %inbox)
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%notifications request: failed")
        =/  eyre-id=@ta  name.rail
        =/  s  (srv rail)
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:s eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path
          %+  skip  (slag (lent `path`/grubbery/inbox) site)
          |=(seg=@ta =('' seg))
        =/  filename=@ta
          ?~  suffix  'index.html'
          i.suffix
        ;<  file-view=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& ~[%ui] filename]) `[/ %mime])
        ?.  ?=([%file *] file-view)
          ;<  ~  bind:m  (send-simple:s eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.file-view))
        ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils mime))
        (pure:m ~)
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%notifications main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        ::  from is a bend relative to this grub; resolve to the
        ::  sender's absolute rail
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  sender=rail:tarball  (resolve-bend:io here from)
        ?:  =('register' act)
          =/  name=@t  (gs jon 'name')
          ?:  =('' name)  $
          ;<  reg=(map @t json)  bind:m  read-registry
          =/  key=@t  (crip (spud path.sender))
          ;<  ~  bind:m
            %+  over:io  (cord-to-road:tarball './registry.json')
            [[/ %json] `json`[%o (~(put by reg) key s+name)]]
          $
        ?:  =('notify' act)
          ;<  reg=(map @t json)  bind:m  read-registry
          =/  app=(unit @t)  (lookup-app reg path.sender)
          ?~  app
            ~&  >>>  "%notifications: unregistered sender {(spud path.sender)}"
            $
          =/  push=?  =('true' (gs jon 'push'))
          =/  metadata=(map @t json)
            =/  md=(unit json)  (~(get by p.jon) 'metadata')
            ?.(?=([~ %o *] md) ~ p.u.md)
          ;<  now=@da  bind:m  get-time:io
          ;<  eny=@uvJ  bind:m  get-entropy:io
          =/  id=@uv  (end [3 8] eny)
          ;<  ib=inbox:nib  bind:m  read-inbox
          =/  key=@da
            |-(?:((has:on-inbox:nib ib now) $(now +(now)) now))
          =/  note=notification:nib
            [id u.app sender key push ~ metadata]
          ;<  ~  bind:m  (write-inbox (put:on-inbox:nib ib key note))
          ;<  ~  bind:m
            ?.  push  (pure:(fiber:fiber:nexus ,~) ~)
            %-  send-push:io
            :^  ~  ~  ~
            :*  (md-str metadata 'title')
                (md-str metadata 'body')
                ~
                ?:(=('' (md-str metadata 'url')) `'/grubbery/inbox' `(md-str metadata 'url'))
                ~
            ==
          $
        ?:  =('ack' act)
          =/  id=(unit @uv)  (slaw %uv (gs jon 'id'))
          ?~  id  $
          ;<  now=@da  bind:m  get-time:io
          ;<  ib=inbox:nib  bind:m  read-inbox
          =/  hit=(unit [key=@da n=notification:nib])  (find-note ib u.id)
          ?~  hit  $
          ;<  ~  bind:m
            (write-inbox (put:on-inbox:nib ib key.u.hit n.u.hit(mack `now)))
          $
        ?:  =('clear' act)
          =/  id=(unit @uv)  (slaw %uv (gs jon 'id'))
          ?~  id  $
          ;<  ib=inbox:nib  bind:m  read-inbox
          =/  hit=(unit [key=@da n=notification:nib])  (find-note ib u.id)
          ?~  hit  $
          ;<  ~  bind:m
            (write-inbox +:(del:on-inbox:nib ib key.u.hit))
          $
        $
      ==
    --
|%
++  srv
  |=  =rail:tarball
  ~(. http-res:io (nex-road:io rail [%& ~[%ui] %'http.sig']))
::
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  (fall (bind (~(get by p.jon) k) |=(=json ?>(?=(%s -.json) p.json))) '')
::
++  md-str
  |=  [md=(map @t json) k=@t]
  ^-  @t
  =/  j=(unit json)  (~(get by md) k)
  ?.(?=([~ %s *] j) '' p.u.j)
::
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
++  read-registry
  =/  m  (fiber:fiber:nexus ,(map @t json))
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io (cord-to-road:tarball './registry.json') ~)
  %-  pure:m
  ?.  ?=([%file *] view)  ~
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.(?=(%o -.j) ~ p.j)
::  +lookup-app: longest registered path-prefix of the sender wins —
::  a registrant covers its subtree
::
++  lookup-app
  |=  [reg=(map @t json) sender=path]
  ^-  (unit @t)
  =/  best=(unit [len=@ud name=@t])  ~
  =/  entries  ~(tap by reg)
  |-
  ?~  entries
    ?~(best ~ `name.u.best)
  =/  [key=@t val=json]  i.entries
  ?.  ?=(%s -.val)  $(entries t.entries)
  =/  pax=(unit path)  (mole |.((stab key)))
  ?~  pax  $(entries t.entries)
  ?.  (is-prefix u.pax sender)  $(entries t.entries)
  =/  len=@ud  (lent u.pax)
  ?:  |(?=(~ best) (gth len len.u.best))
    $(entries t.entries, best `[len p.val])
  $(entries t.entries)
::
++  is-prefix
  |=  [pre=path pax=path]
  ^-  ?
  |-
  ?~  pre  %.y
  ?~  pax  %.n
  ?.  =(i.pre i.pax)  %.n
  $(pre t.pre, pax t.pax)
++  read-inbox
  =/  m  (fiber:fiber:nexus ,inbox:nib)
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io (cord-to-road:tarball './inbox.inbox') ~)
  %-  pure:m
  ?.  ?=([%file *] view)  *inbox:nib
  (fall (mole |.(!<(inbox:nib (need-vase:tarball sang.view)))) *inbox:nib)
::
++  write-inbox
  |=  ib=inbox:nib
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (cord-to-road:tarball './inbox.inbox') [[/ %inbox] ib])
::
++  find-note
  |=  [ib=inbox:nib id=@uv]
  ^-  (unit [key=@da n=notification:nib])
  =/  entries=(list [key=@da n=notification:nib])  (tap:on-inbox:nib ib)
  |-
  ?~  entries  ~
  ?:  =(id id.n.i.entries)  `i.entries
  $(entries t.entries)
--
