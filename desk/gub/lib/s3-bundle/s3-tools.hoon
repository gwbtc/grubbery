::  s3-tools: the calls protocol from a tool's side. A tool never talks
::  to the bucket; it pokes the s3 nexus's main.sig with {id, body},
::  waits for the call grub to finish, culls it, and renders the response.
::  The nexus records the tool's run grub as the caller.
::
/<  tools  /lib/tools.hoon
|%
++  root  `path`/apps/s3
::  +call-s3: run one op body through the nexus; the response json
::
++  call-s3
  |=  body=json
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  call-id=@t     (scot %uv (end [3 8] eny))
  =/  call-name=@ta  (crip "{(trip call-id)}.json")
  =/  main-road=road:tarball  [%& %& root %'main.sig']
  =/  call-road=road:tarball  [%& %& (snoc root %calls) call-name]
  ;<  *  bind:m  (keep:io /call call-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    (pairs:enjs:format ~[['id' s+call-id] ['body' body]])
  ;<  resp=json  bind:m  (await-call call-road call-name)
  ;<  ~  bind:m  (drop:io /call call-road)
  ;<  *  bind:m  (cull-soft:io call-road)
  (pure:m resp)
::  +await-call: news on the calls dir until our grub reads done
::
++  await-call
  |=  [call-road=road:tarball call-name=@ta]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  |-
  ;<  raw=wave:nexus  bind:m  (take-news:io /call)
  =/  hit=(unit cass:clay)
    ?~  fil.raw  ~
    (~(get by file.u.fil.raw) call-name)
  ?~  hit  $
  ;<  =view:nexus  bind:m  (peek-at:io call-road ~ [%ud ud.u.hit])
  ?.  ?=([%file *] view)  $
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%o -.jon)  $
  ?.  ?=([~ %s %'done'] (~(get by p.jon) 'status'))  $
  (pure:m (fall (~(get by p.jon) 'response') [%o ~]))
::  +render: a response as a tool result — its error, or a text
::
++  render
  |=  [resp=json ok=@t]
  ^-  tool-result:tools
  =/  error=@t  (jstr resp 'error')
  ?.  =('' error)  [%error error]
  [%text ok]
::
++  jstr
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=([%o *] j)  ''
  =/  v  (~(get by p.j) k)
  ?:(?=([~ %s *] v) p.u.v '')
::
++  jnum
  |=  [j=json k=@t]
  ^-  @ud
  ?.  ?=([%o *] j)  0
  =/  v  (~(get by p.j) k)
  ?.  ?=([~ %n *] v)  0
  (fall (rush p.u.v dem) 0)
::
++  jarr
  |=  [j=json k=@t]
  ^-  (list @t)
  ?.  ?=([%o *] j)  ~
  =/  v  (~(get by p.j) k)
  ?.  ?=([~ %a *] v)  ~
  (murn p.u.v |=(x=json ?:(?=([%s *] x) `p.x ~)))
::  +commas: a list of cords as one comma-separated tape
::
++  commas
  |=  l=(list @t)
  ^-  tape
  ?~  l  ""
  ?~  t.l  (trip i.l)
  (welp (trip i.l) (welp ", " $(l t.l)))
::  +arg: a string argument or ''
::
++  arg
  |=  [args=(map @t json) k=@t]
  ^-  @t
  =/  v  (~(get by args) k)
  ?:(?=([~ %s *] v) p.u.v '')
--
