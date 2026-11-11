::  lib/shell/contacts: the people record, a service of the shell.
::
::  Two directories, one file per ship in each, named without the sig.
::  profiles: what a ship publishes, as this ship last read it; your
::  own ship's is what you publish. overlays: yours alone, the name you
::  call them, labels, notes. Apps find it by NAME: /sys/link/contacts
::  points at the shell's /contacts directory.
::
::    <shell>/contacts/main.sig                 pokes: set / del / profile
::    <shell>/contacts/profiles/<ship>.json     as that ship publishes it
::    <shell>/contacts/overlays/<ship>.json     your overlay on that ship
::    <shell>/ui/contacts/*                     the page, at /grubbery/contacts
::    GET /grubbery/contacts/api/{overlays,profiles}   every file as one object
::
::  Every road below is relative to the serving grub, so the service
::  reads and writes only its own directory wherever the shell lives.
::
|%
::  +serve: the main.sig loop. Takes pokes forever; a malformed poke is
::  skipped, never fatal.
::
::    {"action": "set", "ship": "~zod", "overlay": {...}}
::      your overlay on that ship, replaced whole
::    {"action": "del", "ship": "~zod"}
::      your overlay on that ship and its profile both go
::    {"action": "profile", "profile": {...}}
::      the profile this ship publishes, replaced whole
::    {"action": "sync-ames"}
::      every ship ames knows that has no overlay yet gets one, marked
::      {"source": "ames"}. Only on request, never at start, and only
::      the ships not already here: a ship with thousands of peers
::      writes each once and never again.
::
++  serve
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [* =sage:tarball]  bind:m  take-poke-from:io
  ::  the start's kick and any other non-json poke are nobody's action
  ?.  =([/ %json] p.sage)  $
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  act=@t  (gs jon 'action')
  ?:  =('set' act)
    =/  who=(unit @p)  (slaw %p (gs jon 'ship'))
    ?~  who  $
    ;<  ~  bind:m  (write (ship-file /overlays u.who) (gj jon 'overlay'))
    $
  ?:  =('del' act)
    =/  who=(unit @p)  (slaw %p (gs jon 'ship'))
    ?~  who  $
    ;<  *  bind:m  (cull-soft:io (ship-file /overlays u.who))
    ;<  *  bind:m  (cull-soft:io (ship-file /profiles u.who))
    $
  ?:  =('profile' act)
    ;<  our=@p  bind:m  get-our:io
    ;<  ~  bind:m  (write (ship-file /profiles our) (gj jon 'profile'))
    $
  ?:  =('sync-ames' act)
    ;<  ~  bind:m  sync-ames
    $
  $
::  +sync-ames: the ships ames knows, as overlays, for those not here yet
::
++  sync-ames
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  peers=(map ship ?(%alien %known))  bind:m
    (typed-scry:io (map ship ?(%alien %known)) %ames-peers /ax//peers)
  ;<  have=(list [who=@p doc=json])  bind:m  (read-dir [%| 0 [%| /overlays]])
  =/  had=(set @p)  (silt (turn have |=([who=@p *] who)))
  =/  new=(list @p)
    %+  murn  ~(tap by peers)
    |=  [who=@p val=?(%alien %known)]
    ?:  |(=(who our) ?=(%alien val) (~(has in had) who))  ~
    `who
  |-  ^-  form:m
  ?~  new  (pure:m ~)
  ;<  ~  bind:m
    (write (ship-file /overlays i.new) (pairs:enjs:format ~[['source' s+'ames']]))
  $(new t.new)
::  +read-dir: every ship's json in one of the two directories
::
++  read-dir
  |=  =road:tarball
  =/  m  (fiber:fiber:nexus ,(list [who=@p doc=json]))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  %-  pure:m
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  ^-  (unit [@p json])
  =/  stem=tape  (trip name)
  =/  len=@ud  (lent stem)
  ?.  &((gth len 5) =(".json" (slag (sub len 5) stem)))  ~
  =/  who=(unit @p)  (slaw %p (crip ['~' (scag (sub len 5) stem)]))
  ?~  who  ~
  =/  doc=(unit json)  (mole |.(!<(json (need-vase:tarball sang))))
  ?~  doc  ~
  `[u.who u.doc]
::  +ship-file: a ship's file in one of the two directories, the ship
::  without its sig
::
++  ship-file
  |=  [dir=path who=@p]
  ^-  road:tarball
  [%| 0 [%& dir (rap 3 (rsh [3 1] (scot %p who)) '.json' ~)]]
::  +write: one json file, made or replaced. Anything but an object is
::  written as an empty one.
::
++  write
  |=  [=road:tarball doc=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (put:io road [[/ %json] ?:(?=([%o *] doc) doc [%o ~])])
::  +serve-page: one request under /grubbery/contacts: a file of the page
::  (ui/contacts/<name>), the index by default. Owner only. The page
::  reads and writes through the kernel's namespace api itself.
::
++  serve-page
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  eyre-id=@ta  name.rail
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
    (pure:m ~)
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path
    %+  skip  (slag (lent `path`/grubbery/contacts) site)
    |=(seg=@ta =('' seg))
  ::  /api/overlays and /api/profiles: one object, every ship's file
  ::  under its name with the sig, which is how an app spells a ship
  ?:  ?=([%api ?(%overlays %profiles) ~] suffix)
    =/  dir=path  ?:(?=(%overlays i.t.suffix) /overlays /profiles)
    ;<  rows=(list [who=@p doc=json])  bind:m
      (read-dir (nex-road:io rail [%| (weld /contacts dir)]))
    =/  out=json  [%o (malt (turn rows |=([who=@p doc=json] [`@t`(scot %p who) doc])))]
    ;<  ~  bind:m
      %+  send-simple:http-res:io  eyre-id
      [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html (en:json:html out))]
    (pure:m ~)
  =/  filename=@ta
    ?~  suffix  'index.html'
    i.suffix
  ;<  file-view=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& /ui/contacts filename]) `[/ %mime])
  ?.  ?=([%file *] file-view)
    ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.file-view))
  ;<  ~  bind:m  (send-simple:http-res:io eyre-id (mime-response:http-utils mime))
  (pure:m ~)
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  gj
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
--
