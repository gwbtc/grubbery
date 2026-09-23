/<  tools  /lib/tools.hoon
::  nostr_feed: the feed as the page shows it for the current account:
::  feed.json through the account's follows, each post resolved with
::  its author's name and its reference counts.
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
++  name  'nostr_feed'
++  description
  'Read the current account\'s feed: the posts from the accounts it follows, newest first. Each entry shows the post\'s age, the author\'s name, a prefix of the event id, the text, and counts of its replies, reposts, and reactions; a repost also names who reposted.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['limit' [%number 'The maximum number of posts to return, newest first. (default: 20, max: 60)']]
      ['pubkey' [%string 'An account on this ship, as a 64-hex pubkey, whose feed to read instead of the current account\'s. (default: the current account.)']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  limit=@ud  (min 60 (argn args.st 'limit' 20))
  ;<  cur=(unit @t)  bind:m  current
  =/  want=@t  (arg args.st 'pubkey')
  =/  pk=(unit @t)  ?:(=('' want) cur `want)
  ?~  pk  (pure:m [%text 'no account: nothing to see the feed as'])
  ;<  fl=[src=@t pks=(list @t)]  bind:m  (follows-of u.pk)
  =/  fs=(set @t)  (silt pks.fl)
  ;<  idx=(unit json)  bind:m  (read / 'feed.json')
  =/  j=json  (fall idx [%o ~])
  =/  ids=(list @t)  (jstrs j 'ids')
  =/  authors=(list @t)  (turn (jarr j 'authors') |=(a=json ?:(?=([%s *] a) p.a '')))
  ::  pairs [id author]; the index is newest first already
  =/  ents=(list [id=@t a=@t])
    =|  out=(list [id=@t a=@t])
    |-
    ?~  ids  (flop out)
    =/  a=@t  ?~(authors '' i.authors)
    $(ids t.ids, authors ?~(authors ~ t.authors), out [[i.ids a] out])
  =/  pick=(list [id=@t a=@t])
    (scag (mul 2 limit) (skim ents |=([* a=@t] |(=('' a) (~(has in fs) a)))))
  ;<  now=@ud  bind:m  now-unix
  ;<  lines=(list @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(list @t))
    =|  out=(list @t)
    =|  n=@ud
    |-  ^-  form:m
    ?:  |(?=(~ pick) (gte n limit))  (pure:m (flop out))
    ;<  ev=(unit json)  bind:m  (read /events (cat 3 id.i.pick '.json'))
    ?~  ev  $(pick t.pick)
    =/  by=@t  (jstr u.ev 'pubkey')
    ?.  (~(has in fs) by)  $(pick t.pick)
    =/  kind=@ud  (jnum u.ev 'kind')
    ::  a repost: the original is what shows, with who reposted it
    ;<  shown=(unit json)  bind:m
      ?.  =(6 kind)  (pure:(fiber:fiber:nexus ,(unit json)) ev)
      =/  es  (skim (jarr u.ev 'tags') |=(t=json ?&(?=([%a [%s %e] [%s *] *] t))))
      ?~  es  (pure:(fiber:fiber:nexus ,(unit json)) ~)
      =/  target=@t  ?>(?=([%a [%s %e] [%s *] *] i.es) p.i.t.p.i.es)
      (read /events (cat 3 target '.json'))
    ?~  shown  $(pick t.pick)
    =/  oid=@t  (jstr u.shown 'id')
    ;<  nm=@t  bind:m  (name-of (jstr u.shown 'pubkey'))
    ;<  rep=@t  bind:m  ?.(=(6 kind) (pure:(fiber:fiber:nexus ,@t) '') (name-of by))
    ;<  refs=(unit json)  bind:m  (read /refs (cat 3 oid '.json'))
    =/  r=json  (fall refs [%o ~])
    =/  reply=tape
      =/  es  (skim (jarr u.shown 'tags') |=(t=json ?=([%a [%s %e] *] t)))
      ?:(=(~ es) "" " (a reply)")
    =/  line=tape
      ;:  weld
        "[{(age (jnum u.shown 'created_at') now)}] "
        ?:(=('' rep) "" "🔁 {(trip rep)} reposted · ")
        "{(trip nm)} ({(short oid 8)}){reply}: {(short (jstr u.shown 'content') 220)}"
        " · 💬{(a-co:co (lent (jarr r 'replies')))} 🔁{(a-co:co (lent (jarr r 'reposts')))} ❤{(a-co:co (lent (jarr r 'reactions')))}\0a"
      ==
    $(pick t.pick, out [(crip line) out], n +(n))
  =/  head=tape
    "feed as {(short u.pk 12)}: {(a-co:co (lent pks.fl))} follows ({(trip src.fl)}), index has {(a-co:co (lent ents))} entries\0a"
  (pure:m [%text (crip (weld head ?:(=(~ lines) "(nothing by these follows in the index)\0a" `tape`(zing (turn lines trip)))))])
--
