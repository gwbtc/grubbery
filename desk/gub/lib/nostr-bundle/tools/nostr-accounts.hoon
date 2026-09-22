/<  tools  /lib/tools.hoon
::  nostr_accounts: the accounts on this ship and the current one;
::  switch, follow, unfollow. Writes what the page's endpoints write:
::  me.json, accounts/<pk>/follows.json, then a reconnect poke to
::  every relay client (their subscription is the union of follows).
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
++  name  'nostr_accounts'
++  description
  'Accounts on this ship. action=list (default) shows them with names, follows counts and which is current. action=use pubkey=<hex> makes one current. action=follow / unfollow pubkey=<hex> edits the current account\'s follows and reconnects the relay clients.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['action' [%string 'list | use | follow | unfollow']]
      ['pubkey' [%string 'a pubkey (64 hex): the account to use, or the person to follow/unfollow']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  action=@t  (arg args.st 'action')
  =/  pk=@t  (arg args.st 'pubkey')
  ;<  cur=(unit @t)  bind:m  current
  ?:  =('use' action)
    ?:  =('' pk)  (pure:m [%error 'pubkey required'])
    ;<  have=?  bind:m  (peek-exists:io [%& %| `path`(weld root `path`[%accounts `@ta`pk ~])])
    ?.  have  (pure:m [%error 'no such account'])
    ;<  ~  bind:m  (over:io (file / 'me.json') [[/ %json] (pairs:enjs:format ~[['current' s+pk]])])
    (pure:m [%text (crip "current account is now {(trip pk)}")])
  ?:  |(=('follow' action) =('unfollow' action))
    ?:  =('' pk)  (pure:m [%error 'pubkey required'])
    ?~  cur  (pure:m [%error 'no current account'])
    ;<  fl=[src=@t pks=(list @t)]  bind:m  (follows-of u.cur)
    =/  next=(list @t)
      ?:  =('unfollow' action)  (skip pks.fl |=(p=@t =(p pk)))
      ?:((lien pks.fl |=(p=@t =(p pk))) pks.fl (snoc pks.fl pk))
    =/  doc=json  (pairs:enjs:format ~[['pubkeys' [%a (turn next |=(p=@t s+p))]]])
    =/  road=road:tarball  (file `path`[%accounts `@ta`u.cur ~] 'follows.json')
    ;<  have=?  bind:m  (peek-exists:io road)
    ;<  ~  bind:m
      ?:  have  (over:io road [[/ %json] doc])
      ;<  *  bind:(fiber:fiber:nexus ,~)  (make-soft:io road |+[[[/ %json] doc] ~])
      (pure:(fiber:fiber:nexus ,~) ~)
    ;<  sigs=(list @ta)  bind:m  (names-in /relays)
    =/  sigs  (skim sigs |=(n=@ta =(".sig" (slag (sub (lent (trip n)) 4) (trip n)))))
    ;<  ~  bind:m
      =/  m  (fiber:fiber:nexus ,~)
      |-  ^-  form:m
      ?~  sigs  (pure:m ~)
      ;<  *  bind:m  (poke-soft:io (file /relays i.sigs) [/ %json] (pairs:enjs:format ~[['action' s+'reconnect']]))
      $(sigs t.sigs)
    (pure:m [%text (crip "{(trip action)}ed {(short pk 12)}: {(a-co:co (lent next))} follows now; relay clients reconnecting")])
  ::  list
  ;<  accts=(list @ta)  bind:m  (dirs-in /accounts)
  ;<  lines=(list @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(list @t))
    =|  out=(list @t)
    |-  ^-  form:m
    ?~  accts  (pure:m (flop out))
    =/  apk=@t  `@t`i.accts
    ;<  idn=(unit json)  bind:m  (read `path`[%accounts i.accts ~] 'identity.json')
    ;<  prof=(unit json)  bind:m  (read `path`[%accounts i.accts ~] 'profile.json')
    ;<  fl=[src=@t pks=(list @t)]  bind:m  (follows-of apk)
    =/  nm=@t  (jstr (fall prof [%o ~]) 'name')
    =/  line=tape
      "{?:(=(cur `apk) "* " "  ")}{(trip apk)}\0a    {(trip (jstr (fall idn [%o ~]) 'npub'))}\0a    name: {?:(=('' nm) "(none)" (trip nm))} · {(a-co:co (lent pks.fl))} follows ({(trip src.fl)})\0a"
    $(accts t.accts, out [(crip line) out])
  =/  text=tape
    ?:  =(~ lines)  "no accounts\0a"
    (weld "accounts (* = current{?:(?=(~ cur) ", none current" "")}):\0a" `tape`(zing (turn lines trip)))
  (pure:m [%text (crip text)])
--
