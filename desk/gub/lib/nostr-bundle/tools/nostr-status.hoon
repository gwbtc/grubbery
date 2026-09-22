/<  tools  /lib/tools.hoon
::  nostr_status: the client's state, from its grubs: relays, counts,
::  accounts, the current one and its follows. For checking the ship
::  without a browser or the terminal.
=>  |%
    ::  json helpers (the tool is self-contained: the code namespace
    ::  it compiles in has /lib/tools.hoon and nothing else of ours)
    ++  jget
      |=  [j=json k=@t]
      ^-  (unit json)
      ?.(?=([%o *] j) ~ (~(get by p.j) k))
    ++  jstr
      |=  [j=json k=@t]
      ^-  @t
      =/  v  (jget j k)
      ?:(?=([~ %s *] v) p.u.v '')
    ++  jnum
      |=  [j=json k=@t]
      ^-  @ud
      =/  v  (jget j k)
      ?~  v  0
      (fall (mole |.((ni:dejs:format u.v))) 0)
    ++  jarr
      |=  [j=json k=@t]
      ^-  (list json)
      =/  v  (jget j k)
      ?:(?=([~ %a *] v) p.u.v ~)
    ++  jstrs
      |=  [j=json k=@t]
      ^-  (list @t)
      (murn (jarr j k) |=(x=json ?:(?=([%s *] x) `p.x ~)))
    ++  arg
      |=  [args=(map @t json) k=@t]
      ^-  @t
      =/  v  (~(get by args) k)
      ?:  ?=([~ %s *] v)  p.u.v
      ?:  ?=([~ %n *] v)  p.u.v
      ''
    ++  argn
      |=  [args=(map @t json) k=@t d=@ud]
      ^-  @ud
      =/  s=@t  (arg args k)
      ?:(=('' s) d (fall (rush s dem) d))
    ++  short
      |=  [t=@t n=@ud]
      ^-  tape
      =/  tt=tape  (trip t)
      ?:((lte (lent tt) n) tt (weld (scag n tt) "..."))
    ++  age
      |=  [at=@ud now=@ud]
      ^-  tape
      ?:  |(=(0 at) (gte at now))  "now"
      =/  s=@ud  (sub now at)
      ?:  (lth s 3.600)  "{(a-co:co (div s 60))}m"
      ?:  (lth s 86.400)  "{(a-co:co (div s 3.600))}h"
      "{(a-co:co (div s 86.400))}d"
    ++  now-unix
      =/  m  (fiber:fiber:nexus ,@ud)
      ^-  form:m
      ;<  now=@da  bind:m  get-time:io
      (pure:m (div (sub now ~1970.1.1) ~s1))
    ::  grubs under /apps/nostr
    ++  root  `path`/apps/nostr
    ++  file
      |=  [dir=path name=@t]
      ^-  road:tarball
      [%& %& `path`(weld root dir) `@ta`name]
    ++  read
      |=  [dir=path name=@t]
      =/  m  (fiber:fiber:nexus ,(unit json))
      ^-  form:m
      (peek-as:io (file dir name) ,json)
    ++  names-in
      |=  dir=path
      =/  m  (fiber:fiber:nexus ,(list @ta))
      ^-  form:m
      ;<  v=view:nexus  bind:m  (peek-shallow:io [%& %| `path`(weld root dir)] ~)
      %-  pure:m
      ?.  ?=([%ball *] v)  ~
      ?~  fil.ball.v  ~
      (turn ~(tap by contents.u.fil.ball.v) |=([n=@ta *] n))
    ++  dirs-in
      |=  dir=path
      =/  m  (fiber:fiber:nexus ,(list @ta))
      ^-  form:m
      ;<  v=view:nexus  bind:m  (peek-shallow:io [%& %| `path`(weld root dir)] ~)
      %-  pure:m
      ?.  ?=([%ball *] v)  ~
      ~(tap in ~(key by dir.ball.v))
    ++  strip
      |=  n=@ta
      ^-  @t
      =/  t=tape  (trip n)
      ?:  (lth (lent t) 5)  n
      (crip (scag (sub (lent t) 5) t))
    ::  the current account and its follows (accounts/<pk>/follows.json,
    ::  else the root follows.json of before accounts)
    ++  current
      =/  m  (fiber:fiber:nexus ,(unit @t))
      ^-  form:m
      ;<  me=(unit json)  bind:m  (read / 'me.json')
      =/  c=@t  (jstr (fall me [%o ~]) 'current')
      (pure:m ?:(=('' c) ~ `c))
    ++  follows-of
      |=  pk=@t
      =/  m  (fiber:fiber:nexus ,[src=@t pks=(list @t)])
      ^-  form:m
      ;<  f=(unit json)  bind:m  (read `path`[%accounts `@ta`pk ~] 'follows.json')
      ?^  f  (pure:m ['account' (jstrs u.f 'pubkeys')])
      ;<  old=(unit json)  bind:m  (read / 'follows.json')
      ?^  old  (pure:m ['root (unmigrated)' (jstrs u.old 'pubkeys')])
      (pure:m ['none' ~])
    ++  name-of
      |=  pk=@t
      =/  m  (fiber:fiber:nexus ,@t)
      ^-  form:m
      ;<  p=(unit json)  bind:m  (read /profiles (cat 3 pk '.json'))
      =/  n=@t  (jstr (fall p [%o ~]) 'name')
      (pure:m ?:(=('' n) (crip (short pk 8)) n))
    --
!:
^-  tool:tools
|%
++  name  'nostr_status'
++  description
  'The nostr client (/apps/nostr) as its grubs say: relay clients (stage, tries, events this session, subscription), counts (events, profiles, refs, outbox), accounts and which is current, its follows count.'
++  parameters  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  now=@ud  bind:m  now-unix
  ;<  rnames=(list @ta)  bind:m  (names-in /relays)
  =/  rjson=(list @ta)  (skim rnames |=(n=@ta =(".json" (slag (sub (lent (trip n)) 5) (trip n)))))
  ;<  relays=(list @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(list @t))
    =|  out=(list @t)
    |-  ^-  form:m
    ?~  rjson  (pure:m (flop out))
    ;<  r=(unit json)  bind:m  (read /relays i.rjson)
    ?~  r  $(rjson t.rjson)
    =/  line=tape
      "  {(trip (jstr u.r 'host'))}: {(trip (jstr u.r 'stage'))}, tries {(a-co:co (jnum u.r 'tries'))}, {(a-co:co (jnum u.r 'events'))} events ({(a-co:co (jnum u.r 'new'))} new) this session, updated {(age (jnum u.r 'updated') now)} ago{?:(=('' (jstr u.r 'error')) "" (weld ", error: " (trip (jstr u.r 'error'))))}\0a    sub: {(short (jstr u.r 'req') 140)}\0a"
    $(rjson t.rjson, out [(crip line) out])
  ;<  ev=(list @ta)  bind:m  (names-in /events)
  ;<  pr=(list @ta)  bind:m  (names-in /profiles)
  ;<  rf=(list @ta)  bind:m  (names-in /refs)
  ;<  ob=(list @ta)  bind:m  (names-in /outbox)
  ;<  tg=(list @ta)  bind:m  (names-in /tags)
  ;<  cur=(unit @t)  bind:m  current
  ;<  accts=(list @ta)  bind:m  (dirs-in /accounts)
  ;<  alines=(list @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(list @t))
    =|  out=(list @t)
    |-  ^-  form:m
    ?~  accts  (pure:m (flop out))
    =/  pk=@t  `@t`i.accts
    ;<  prof=(unit json)  bind:m  (read `path`[%accounts i.accts ~] 'profile.json')
    ;<  fl=[src=@t pks=(list @t)]  bind:m  (follows-of pk)
    =/  nm=@t  (jstr (fall prof [%o ~]) 'name')
    =/  line=tape
      "  {?:(=(cur `pk) "* " "  ")}{(short pk 12)} {?:(=('' nm) "(no name)" (trip nm))}: {(a-co:co (lent pks.fl))} follows ({(trip src.fl)})\0a"
    $(accts t.accts, out [(crip line) out])
  ;<  root-follows=(unit json)  bind:m  (read / 'follows.json')
  =/  text=tape
    ;:  weld
      "relays:\0a"  `tape`(zing (turn relays trip))
      "counts: {(a-co:co (lent ev))} events, {(a-co:co (lent pr))} profiles, {(a-co:co (lent rf))} refs, {(a-co:co (lent tg))} tags, {(a-co:co (lent ob))} in outbox\0a"
      "accounts ({(a-co:co (lent accts))}; * = current{?:(?=(~ cur) ", none current" "")}):\0a"  `tape`(zing (turn alines trip))
      ?:(?=(~ root-follows) "" "root follows.json still present (migrates on first read)\0a")
    ==
  (pure:m [%text (crip text)])
--
