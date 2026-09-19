/<  tools  /lib/tools.hoon
::  get_feed: the live nostr timeline, compacted. Reads nostrill's
::  gall state through the /sys/scry service (typed-scry:io) — the
::  agent weir grants that one poke. Returns the latest N posts as
::  plain lines the model can reason over, newest first, truncated.
::
=>  |%
    ::  +jget: object field
    ++  jget
      |=  [j=json k=@t]
      ^-  (unit json)
      ?.(?=([%o *] j) ~ (~(get by p.j) k))
    ::  +jstr: string field or ''
    ++  jstr
      |=  [j=json k=@t]
      ^-  @t
      =/  v  (jget j k)
      ?:(?=([~ %s *] v) p.u.v '')
    ::  +jnum: number field as @ud or 0
    ++  jnum
      |=  [j=json k=@t]
      ^-  @ud
      =/  v  (jget j k)
      ?~  v  0
      (fall (mole |.((ni:dejs:format u.v))) 0)
    --
!:
^-  tool:tools
|%
++  name  'get_feed'
++  description
  '''
  Read the current nostr timeline the user is watching (latest posts,
  newest first). Each line: [age] author-pubkey-prefix: content. Use
  this to understand the live flow before proposing posts or replies.
  The event id prefix on each line is what a reply proposal should
  reference in its "re" field.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['limit' [%string 'how many posts (default 20, max 50)']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  limit=@ud
    =/  v  (~(get by args.st) 'limit')
    =/  n=@ud
      ?:  ?=([~ %s *] v)  (fall (rush p.u.v dem) 20)
      ?:  ?=([~ %n *] v)  (fall (rush p.u.v dem) 20)
      20
    ?:(=(0 n) 20 (min n 50))
  ;<  feed-jon=json  bind:m  (typed-scry:io json %json /gx/nostrill/j/nostr/json)
  =/  jon=(unit json)  `feed-jon
  ?.  ?&(?=(^ jon) ?=([%o *] u.jon))
    (pure:m [%error 'nostrill returned no feed'])
  ::  {name: {relay-url: {sub, feed: [event...]}}} — prefer the
  ::  "timeline" feed, else union everything; dedupe by id.
  =/  feeds=(list json)
    =/  tl=(unit json)  (~(get by p.u.jon) 'timeline')
    =/  pick=(list [@t json])
      ?^  tl  [['timeline' u.tl] ~]
      ~(tap by p.u.jon)
    %-  zing
    %+  turn  pick
    |=  [* srcs=json]
    ^-  (list json)
    ?.  ?=([%o *] srcs)  ~
    %-  zing
    %+  turn  ~(tap by p.srcs)
    |=  [* sf=json]
    ^-  (list json)
    =/  f  (jget sf 'feed')
    ?.(?=([~ %a *] f) ~ p.u.f)
  =/  seen=(set @t)  ~
  =/  events=(list [at=@ud id=@t pk=@t txt=@t])
    =<  out
    %+  roll  feeds
    |=  [ev=json acc=[seen=(set @t) out=(list [at=@ud id=@t pk=@t txt=@t])]]
    =/  id=@t  (jstr ev 'id')
    ?:  |(=('' id) (~(has in seen.acc) id))  acc
    ?.  =(1 (jnum ev 'kind'))  acc
    :-  (~(put in seen.acc) id)
    [[(jnum ev 'created_at') id (jstr ev 'pubkey') (jstr ev 'content')] out.acc]
  =/  sorted  (sort events |=([a=[at=@ud *] b=[at=@ud *]] (gth at.a at.b)))
  =/  take  (scag limit sorted)
  ?~  take  (pure:m [%text 'The feed is empty.'])
  ;<  now=@da  bind:m  get-time:io
  =/  now-unix=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  lines=(list tape)
    %+  turn  `(list [at=@ud id=@t pk=@t txt=@t])`take
    |=  [at=@ud id=@t pk=@t txt=@t]
    ^-  tape
    =/  age=tape
      ?:  (gte at now-unix)  "now"
      =/  s=@ud  (sub now-unix at)
      ?:  (lth s 3.600)  "{(a-co:co (div s 60))}m"
      ?:  (lth s 86.400)  "{(a-co:co (div s 3.600))}h"
      "{(a-co:co (div s 86.400))}d"
    =/  short
      |=  [t=@t n=@ud]
      ^-  tape
      =/  tt=tape  (trip t)
      ?:((lte (lent tt) n) tt (weld (scag n tt) "..."))
    "[{age}] {(short pk 8)} (id {(short id 12)}): {(short txt 400)}\0a"
  (pure:m [%text (crip (zing lines))])
--
