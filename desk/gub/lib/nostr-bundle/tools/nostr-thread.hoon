/<  tools  /lib/tools.hoon
::  nostr_thread: one post and what points at it: the root (found from
::  any post in the thread), every reply we hold under refs/<root>,
::  and who reacted/reposted, by name.
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
++  name  'nostr_thread'
++  description
  'Reconstruct a nostr thread from any event in it. A nostr event has a unique 64-hex id; a reply carries a tag pointing at the post it answers, and the thread root is the post at the top of that chain. Given any id in the thread, the root or any reply, this finds the root and shows: the root post, every reply this ship has stored, in time order and each labeled with the post it replies to, and the reactions and reposts on the root, with pubkeys resolved to profile names. It reads only what this ship already holds; if the root has never been fetched, it says so instead of reaching out to a relay.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['id' [%string 'The event to start from: any post in the thread, as its 64-hex event id. It need not be the root; the tool walks up the reply chain to find the root itself.']]
  ==
++  required  ~['id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  want=@t  (arg args.st 'id')
  ?:  =('' want)  (pure:m [%error 'id required'])
  ;<  ev=(unit json)  bind:m  (read /events (cat 3 want '.json'))
  ::  the root: the e tag marked root, else the first e tag, else itself
  =/  root=@t
    ?~  ev  want
    =/  es=(list [id=@t marker=@t])
      %+  murn  (jarr u.ev 'tags')
      |=  t=json
      ?.  ?=([%a [%s %e] [%s *] *] t)  ~
      =/  rest=(list json)  t.t.p.t
      =/  marker=@t
        ?.  ?=([* * *] rest)  ''
        ?:(?=([%s *] i.t.rest) p.i.t.rest '')
      `[p.i.t.p.t marker]
    ?:  =(~ es)  want
    =/  r=(list [id=@t marker=@t])  (skim es |=([* m=@t] =('root' m)))
    =/  first=(list [id=@t marker=@t])  es
    ?^  r  id.i.r
    ?^  first  id.i.first
    want
  ;<  now=@ud  bind:m  now-unix
  ;<  rev=(unit json)  bind:m  (read /events (cat 3 root '.json'))
  ;<  head=@t  bind:m
    =/  m  (fiber:fiber:nexus ,@t)
    ?~  rev  (pure:m (crip "root {(trip root)}: NOT HELD (fetch it by id)\0a"))
    ;<  nm=@t  bind:m  (name-of (jstr u.rev 'pubkey'))
    (pure:m (crip "root {(short root 12)} [{(age (jnum u.rev 'created_at') now)}] {(trip nm)}: {(short (jstr u.rev 'content') 400)}\0a"))
  ;<  refs=(unit json)  bind:m  (read /refs (cat 3 root '.json'))
  =/  r=json  (fall refs [%o ~])
  =/  replies=(list json)
    %+  sort  (jarr r 'replies')
    |=([a=json b=json] (lth (jnum a 'at') (jnum b 'at')))
  ;<  rlines=(list @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(list @t))
    =|  out=(list @t)
    |-  ^-  form:m
    ?~  replies  (pure:m (flop out))
    =/  id=@t  (jstr i.replies 'id')
    ;<  e=(unit json)  bind:m  (read /events (cat 3 id '.json'))
    ;<  nm=@t  bind:m  (name-of (jstr i.replies 'pubkey'))
    =/  parent=@t  (jstr i.replies 'parent')
    =/  line=tape
      "  ↳ {(short id 8)} → {?:(=(parent root) "root" (short parent 8))} [{(age (jnum i.replies 'at') now)}] {(trip nm)}: {?~(e "(event not held)" (short (jstr u.e 'content') 300))}\0a"
    $(replies t.replies, out [(crip line) out])
  ;<  elines=(list @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(list @t))
    =/  acts=(list [kind=@ud j=json])
      %+  weld
        (turn (jarr r 'reposts') |=(j=json [6 j]))
      (turn (jarr r 'reactions') |=(j=json [7 j]))
    =|  out=(list @t)
    |-  ^-  form:m
    ?~  acts  (pure:m (flop out))
    ;<  nm=@t  bind:m  (name-of (jstr j.i.acts 'pubkey'))
    =/  what=tape  ?:(=(6 kind.i.acts) "reposted" "reacted {(trip (jstr j.i.acts 'content'))}")
    $(acts t.acts, out [(crip "  {(trip nm)} {what} [{(age (jnum j.i.acts 'at') now)}]\0a") out])
  =/  text=tape
    ;:  weld
      (trip head)
      "replies held: {(a-co:co (lent replies))}\0a"  `tape`(zing (turn rlines trip))
      "on the root: {(a-co:co (lent elines))} reactions/reposts\0a"  `tape`(zing (turn elines trip))
    ==
  (pure:m [%text (crip text)])
--
