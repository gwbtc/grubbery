::  contacts nexus: identity and contact management
::
::  /profile/[ship].jobj — peer-published contact data
::  /overlay/[ship].jobj — local edits on top of peer data
::
/<  cui  /lib/contacts-ui.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%over %& [/ %'main.sig'] [[/ %sig] ~]]
            [%fall %| /profile empty-dir:loader]
            [%fall %| /overlay empty-dir:loader]
            [%fall %| /ui empty-dir:loader]
            [%fall %& [/ui %'main.sig'] [[/ %sig] ~]]
            [%fall %| /ui/requests empty-dir:loader]
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
          ::  /main.sig: granular CRUD for jobj fields
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%contacts /main: failed")
        ::  sync ames peers on startup
        ;<  ~  bind:m  sync-ames
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?.  =(%json name.p.sage)
          ~&  >  [%contacts %unknown-mark name.p.sage]
          $
        =/  jon=json  !<(json q.sage)
        ?.  ?=([%o *] jon)  $
        =/  act=(unit json)  (~(get by p.jon) 'action')
        ?.  ?=([~ %s @] act)  $
        =/  action=@t  p.u.act
        ?:  =(%'sync-ames' action)
          ;<  ~  bind:m  sync-ames
          $
        =/  dir=(unit json)  (~(get by p.jon) 'dir')
        ?.  ?=([~ %s ?(%profile %overlay)] dir)  $
        =/  dir-name=@t  p.u.dir
        =/  who=(unit json)  (~(get by p.jon) 'ship')
        ?.  ?=([~ %s @] who)  $
        =/  ship=@t  p.u.who
        ?~  (slaw %p ship)  $
        =/  file=@ta  (cat 3 ship '.jobj')
        =/  file-road=road:tarball  [%| 0 %& /[dir-name] file]
        ?+    action  $
            ::  %put: set fields (merge into existing)
            ::
            %'put'
          =/  fields=(unit json)  (~(get by p.jon) 'fields')
          ?.  ?=([~ %o *] fields)  $
          ;<  seen=seen:nexus  bind:m  (peek:io file-road `[/ %jobj])
          =/  existing=(map @t json)
            ?.  ?=([%& %file *] seen)  ~
            ?:  (is-boom:tarball sang.p.seen)  ~
            !<((map @t json) (need-vase:tarball sang.p.seen))
          =/  merged=(map @t json)  (~(uni by existing) p.u.fields)
          ;<  ~  bind:m  (over:io file-road [[/ %jobj] merged])
          $
            ::  %del: delete specific fields
            ::
            %'del'
          =/  fields=(unit json)  (~(get by p.jon) 'fields')
          ?.  ?=([~ %a *] fields)  $
          =/  keys=(list @t)
            %+  murn  p.u.fields
            |=(=json ?.(?=([%s @] json) ~ `p.json))
          ;<  seen=seen:nexus  bind:m  (peek:io file-road `[/ %jobj])
          =/  existing=(map @t json)
            ?.  ?=([%& %file *] seen)  ~
            ?:  (is-boom:tarball sang.p.seen)  ~
            !<((map @t json) (need-vase:tarball sang.p.seen))
          =/  pruned=(map @t json)
            |-  ?~  keys  existing
            $(keys t.keys, existing (~(del by existing) i.keys))
          ;<  ~  bind:m  (over:io file-road [[/ %jobj] pruned])
          $
            ::  %wipe: delete entire contact file
            ::
            %'wipe'
          ;<  *  bind:m  (cull-soft:io file-road)
          $
        ==
          ::  /ui/main.sig: HTTP endpoint
          ::
          [[%ui ~] %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%contacts /ui/main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/contacts])
        (http-dispatch:io %contacts)
          ::  /ui/requests/*: individual HTTP request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%contacts /ui/requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /grubbery/contacts
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        =/  method=@t  method.request.req
        ::  resolve ancestor steps once for all routes
        ;<  nex-road=road:tarball  bind:m
          (ancestor-road:io [/ %contacts] [%| /])
        =/  steps=@ud  ?-(-.nex-road %& 0, %| p.p.nex-road)
        ::
        ::  GET / — contacts page
        ::
        ?:  ?&(=(%'GET' method) =(~ suffix))
          ;<  profiles=(map @t (map @t json))  bind:m  (load-dir steps /profile)
          ;<  contacts=(map @t (map @t json))  bind:m  (load-dir steps /overlay)
          =/  page=manx  (contacts-page:cui profiles contacts)
          ;<  ~  bind:m  (send-html eyre-id page)
          (pure:m ~)
        ::
        ::  GET /api/profiles — all profiles as JSON
        ::
        ?:  ?&(=(%'GET' method) =(/api/profiles suffix))
          ;<  profiles=(map @t (map @t json))  bind:m  (load-dir steps /profile)
          =/  body=@t
            %-  en:json:html
            [%o (~(run by profiles) |=((map @t json) [%o +<]))]
          ;<  ~  bind:m  (send-json eyre-id body)
          (pure:m ~)
        ::
        ::  GET /api/overlays — all overlays as JSON
        ::
        ?:  ?&(=(%'GET' method) =(/api/overlays suffix))
          ;<  overlays=(map @t (map @t json))  bind:m  (load-dir steps /overlay)
          =/  body=@t
            %-  en:json:html
            [%o (~(run by overlays) |=((map @t json) [%o +<]))]
          ;<  ~  bind:m  (send-json eyre-id body)
          (pure:m ~)
        ::
        ::  POST /api/sync-ames — import ames peers as contacts
        ::
        ?:  ?&(=(%'POST' method) =(/api/'sync-ames' suffix))
          ;<  ~  bind:m  sync-ames
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ::  POST /api/overlay/[ship] — put fields into overlay
        ::
        ?:  ?&(=(%'POST' method) ?=([%api %overlay @ ~] suffix))
          =/  who=@ta  i.t.t.suffix
          ?~  (slaw %p who)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship name')])
            (pure:m ~)
          =/  bod=(unit @t)  ?~(body.request.req ~ `q.u.body.request.req)
          ?~  bod
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
            (pure:m ~)
          =/  jon=(unit json)  (de:json:html u.bod)
          ?~  jon
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
            (pure:m ~)
          ?.  ?=([%o *] u.jon)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Must be JSON object')])
            (pure:m ~)
          =/  file=@ta  (cat 3 who '.jobj')
          =/  file-road=road:tarball  [%| steps %& /overlay file]
          ;<  seen=seen:nexus  bind:m  (peek:io file-road `[/ %jobj])
          =/  existing=(map @t json)
            ?.  ?=([%& %file *] seen)  ~
            ?:  (is-boom:tarball sang.p.seen)  ~
            !<((map @t json) (need-vase:tarball sang.p.seen))
          =/  merged=(map @t json)  (~(uni by existing) p.u.jon)
          ;<  ~  bind:m  (over:io file-road [[/ %jobj] merged])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ::  DELETE /api/overlay/[ship] — wipe overlay
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %overlay @ ~] suffix))
          =/  who=@ta  i.t.t.suffix
          ?~  (slaw %p who)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship name')])
            (pure:m ~)
          =/  file=@ta  (cat 3 who '.jobj')
          =/  file-road=road:tarball  [%| steps %& /overlay file]
          ;<  *  bind:m  (cull-soft:io file-road)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ::  DELETE /api/overlay/[ship]/[field] — delete single overlay field
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %overlay @ @ ~] suffix))
          =/  who=@ta  i.t.t.suffix
          ?~  (slaw %p who)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship name')])
            (pure:m ~)
          =/  field=@t  i.t.t.t.suffix
          =/  file=@ta  (cat 3 who '.jobj')
          =/  file-road=road:tarball  [%| steps %& /overlay file]
          ;<  seen=seen:nexus  bind:m  (peek:io file-road `[/ %jobj])
          =/  existing=(map @t json)
            ?.  ?=([%& %file *] seen)  ~
            ?:  (is-boom:tarball sang.p.seen)  ~
            !<((map @t json) (need-vase:tarball sang.p.seen))
          =/  pruned=(map @t json)  (~(del by existing) field)
          ;<  ~  bind:m  (over:io file-road [[/ %jobj] pruned])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      ==
    --
|%
::  +sync-ames: scry ames peers and create overlay entries for known peers
::
++  sync-ames
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  peers=(map ship ?(%alien %known))  bind:m
    (scry:io (map ship ?(%alien %known)) /ax//peers)
  =/  known=(list ship)
    %+  murn  ~(tap by peers)
    |=  [=ship val=?(%alien %known)]
    ?:  =(ship our)  ~
    ?-  val
      %alien  ~
      %known  `ship
    ==
  ~&  [%contacts %sync-ames %known-peers (lent known)]
  (write-peers known)
++  write-peers
  |=  peers=(list ship)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  peers  (pure:m ~)
  =/  who=@t  (scot %p i.peers)
  =/  file=@ta  (cat 3 who '.jobj')
  =/  file-road=road:tarball  [%| 0 %& /overlay file]
  ;<  seen=seen:nexus  bind:m  (peek:io file-road `[/ %jobj])
  =/  existing=(map @t json)
    ?.  ?=([%& %file *] seen)  ~
    ?:  (is-boom:tarball sang.p.seen)  ~
    !<((map @t json) (need-vase:tarball sang.p.seen))
  ?^  existing
    ::  already has overlay data, don't overwrite
    $(peers t.peers)
  =/  fields=(map @t json)
    (~(put by *(map @t json)) 'source' s+'ames')
  ;<  ~  bind:m  (over:io file-road [[/ %jobj] fields])
  $(peers t.peers)
::
::  HTTP helpers — road from /ui/requests/* to /ui/main.sig
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  send-html
  |=  [eyre-id=@ta page=manx]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  htm=@t  (crip (en-xml:html page))
  (send-simple:srv eyre-id [[200 ~[['content-type' 'text/html']]] `(as-octs:mimes:html htm)])
::
++  send-json
  |=  [eyre-id=@ta body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
::
::  +load-dir: read all jobj files from a directory relative to root road
::
++  load-dir
  |=  [steps=@ud dir=path]
  =/  m  (fiber:fiber:nexus ,(map @t (map @t json)))
  ^-  form:m
  ;<  dir-seen=seen:nexus  bind:m  (peek:io [%| steps %| dir] ~)
  ?.  ?=([%& %ball *] dir-seen)
    (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.p.dir-seen *lump:tarball)
  =/  result=(map @t (map @t json))
    %-  ~(gas by *(map @t (map @t json)))
    %+  murn  ~(tap by contents.lump)
    |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
    ?.  =(%jobj name.p.sang)  ~
    ?:  (is-boom:tarball sang)  ~
    ::  strip .jobj suffix to get key
    =/  name-tape=tape  (trip name)
    =/  key=@t
      =/  parts=(list tape)  (rash name (more dot (star ;~(less dot prn))))
      ?~  parts  name
      (crip i.parts)
    =/  obj=(map @t json)  !<((map @t json) (need-vase:tarball sang))
    `[key obj]
  (pure:m result)
--
