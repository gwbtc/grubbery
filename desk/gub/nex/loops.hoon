::  loops: open-loops stores — flat commitments with labels + best-by
::
::  /main.sig                 json pokes: open / close / reopen /
::                            delete / label / best-by / text
::  /store/<ctx>.open-loops   one loops store per context; created
::                            on first use
::
/<  ol   /lib/open-loops.hoon
/<  iso  /lib/iso-8601.hoon
/&  loops-html  loops/index.html
/&  loops-js    loops/app.js
/&  loops-css   loops/style.css
/&  icon        loops/icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Loops'
            info+s+'Open commitments'
            color+s+'#5b4bb5'
            image+s+'/grubbery/tiles/icon/loops.loops'
            href+s+'/grubbery/loops'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'loops'] ['description' s+'Open loops and running threads']])]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /store empty-dir:loader]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
          [%over %& [/ui %'index.html'] [[/ %mime] loops-html]]
          [%over %& [/ui %'app.js'] [[/ %mime] loops-js]]
          [%over %& [/ui %'style.css'] [[/ %mime] loops-css]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%loops http: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/loops])
        (http-dispatch:io %loops)
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%loops request: failed")
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
          %+  skip  (slag (lent `path`/grubbery/loops) site)
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
        ;<  ~  bind:m  (rise-wait:io prod "%loops main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        =/  ctx=@t  (gs jon 'context')
        ?:  =('' ctx)  $
        ;<  now=@da  bind:m  get-time:io
        ;<  lops=loops:ol  bind:m  (read-store ctx)
        =/  new=(unit loops:ol)  (apply lops act jon now)
        ?~  new  $
        ;<  ~  bind:m  (write-store ctx u.new)
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
++  gn
  |=  [jon=json k=@t]
  ^-  @ud
  ?.  ?=(%o -.jon)  0
  =/  j=(unit json)  (~(get by p.jon) k)
  ?.  ?=([~ %n *] j)  0
  (fall (rush p.u.j dem) 0)
::
++  ga
  |=  [jon=json k=@t]
  ^-  (list @t)
  ?.  ?=(%o -.jon)  ~
  =/  j=(unit json)  (~(get by p.jon) k)
  ?.  ?=([~ %a *] j)  ~
  (murn p.u.j |=(x=json ?:(?=(%s -.x) `p.x ~)))
::
++  parse-day
  |=  s=@t
  ^-  (unit @da)
  ?:  =('' s)  ~
  =/  p=(unit [[a=? y=@ud] m=@ud d=@ud])  (de-soft:date-input:iso s)
  ?~  p  ~
  `(year [[a.u.p y.u.p] m.u.p [d.u.p 0 0 0 ~]])
::  +apply: dispatch one action against a store. ~ means no change
::  (unknown action, missing id, empty text) — the poke is dropped.
::
++  apply
  |=  [lops=loops:ol act=@t jon=json now=@da]
  ^-  (unit loops:ol)
  =/  id=@ud  (gn jon 'id')
  =/  has=?  ?=(^ (~(get-loop lo:ol lops) id))
  ?:  =('open' act)
    =/  text=@t  (gs jon 'text')
    ?:  =('' text)  ~
    =/  labels=(set @t)  (sy (ga jon 'labels'))
    `(~(open lo:ol lops) text labels now (parse-day (gs jon 'best_by')))
  ?:  =('close' act)
    ?.  (~(has by open.lops) id)  ~
    `(~(close lo:ol lops) id now)
  ?:  =('reopen' act)
    ?.  (~(has by closed.lops) id)  ~
    `(~(reopen lo:ol lops) id now)
  ?:  =('delete' act)
    ?.  (~(has by closed.lops) id)  ~
    `(~(delete-loop lo:ol lops) id)
  ?:  =('label' act)
    ?.  has  ~
    =/  l1=loops:ol
      %+  roll  (ga jon 'add')
      |=([lb=@t acc=_lops] (~(add-label lo:ol acc) id lb now))
    :-  ~
    %+  roll  (ga jon 'del')
    |=([lb=@t acc=_l1] (~(remove-label lo:ol acc) id lb now))
  ?:  =('best-by' act)
    ?.  has  ~
    `(~(update-best-by lo:ol lops) id (parse-day (gs jon 'best_by')) now)
  ?:  =('text' act)
    =/  text=@t  (gs jon 'text')
    ?:  |(!has =('' text))  ~
    `(~(update-text lo:ol lops) id text now)
  ~
::
++  store-road
  |=  ctx=@t
  ^-  road:tarball
  (cord-to-road:tarball (crip "./store/{(trip ctx)}.open-loops"))
::
++  read-store
  |=  ctx=@t
  =/  m  (fiber:fiber:nexus ,loops:ol)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (store-road ctx) ~)
  %-  pure:m
  ?.  ?=([%file *] view)  *loops:ol
  (fall (mole |.(!<(loops:ol (need-vase:tarball sang.view)))) *loops:ol)
::
++  write-store
  |=  [ctx=@t lops=loops:ol]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (store-road ctx) ~)
  ?:  ?=([%file *] view)
    (over:io (store-road ctx) [[/ %open-loops] lops])
  (make:io (store-road ctx) |+[[[/ %open-loops] lops] ~])
--
