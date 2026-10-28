::  lib/shell/notifications: the notifications inbox, a service of the shell.
::
::  A human-addressed message bus. Applications register a name, then
::  send notifications; the inbox owns delivery (push) and ack
::  tracking; payloads are opaque jobjs (title/body/url are
::  conventions, not protocol). Senders find it by NAME: the /sys/link
::  entry `notifications` points at the shell's /notifications directory, so
::  @notifications/main.sig is the poke target, as it always was.
::
::    <shell>/notifications/main.sig       pokes: register / notify / ack / clear
::    <shell>/notifications/registry.json  { "<abs path of registrant dir>": "app" }
::                                 a registrant covers its whole subtree
::    <shell>/notifications/inbox.inbox    one mop of notifications, newest first;
::                                 ack is a state flip inside it
::    <shell>/ui/notifications/*   the inbox page, at /grubbery/inbox
::
::  Every road below is relative to the serving grub, so the service
::  reads and writes only its own directory wherever the shell lives.
::
/<  nib  /lib/inbox.hoon
|%
::  +serve: the main.sig loop. Takes pokes forever; a malformed poke is
::  skipped, never fatal.
::
++  serve
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=(%o -.jon)  $
  =/  act=@t  (gs jon 'action')
  ::  from is a bend relative to this grub; resolve to the sender's
  ::  absolute rail
  ;<  here=rail:tarball  bind:m  get-here-abs:io
  =/  sender=rail:tarball  (resolve-bend:io here from)
  ?:  =('register' act)
    =/  name=@t  (gs jon 'name')
    ?:  =('' name)  $
    ;<  reg=(map @t json)  bind:m  read-registry
    =/  key=@t  (crip (spud path.sender))
    ;<  ~  bind:m  (write-registry (~(put by reg) key s+name))
    $
  ?:  =('notify' act)
    ;<  reg=(map @t json)  bind:m  read-registry
    =/  app=(unit @t)  (lookup-app reg path.sender)
    ?~  app
      ~&  >>>  "%shell notifications: unregistered sender {(spud path.sender)}"
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
::  +serve-page: one request under /grubbery/inbox: a file of the page
::  (ui/notifications/<name>), the index by default. Owner only.
::
++  serve-page
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  eyre-id=@ta  name.rail
  =/  s  ~(. http-res:io (nex-road:io rail [%& /ui %'http.sig']))
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
    (peek:io (nex-road:io rail [%& /ui/notifications filename]) `[/ %mime])
  ?.  ?=([%file *] file-view)
    ;<  ~  bind:m  (send-simple:s eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.file-view))
  ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils mime))
  (pure:m ~)
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
++  read-registry
  =/  m  (fiber:fiber:nexus ,(map @t json))
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io (cord-to-road:tarball './registry.json') ~)
  %-  pure:m
  ?.  ?=([%file *] view)  ~
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.(?=(%o -.j) ~ p.j)
::
++  write-registry
  |=  reg=(map @t json)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (cord-to-road:tarball './registry.json') [[/ %json] `json`[%o reg]])
::  +lookup-app: longest registered path-prefix of the sender wins: a
::  registrant covers its subtree
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
::
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
