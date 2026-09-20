/<  tools  /lib/tools.hoon
::  propose: file a CONNECTION on the dashboard — an index entry, not
::  authorship. A connection is a topic label plus raw material: real
::  excerpts from flow posts and/or verbatim passages from library
::  documents that touch the same topic. No generated ideas, angles,
::  arguments, or commentary — juxtaposition only. The thinking and
::  the writing are the user's.
::
!:
=<  ^-  tool:tools
    |%
++  name  'propose'
++  description
  '''
  File a connection on the dashboard: a topic label (plain noun
  phrase) plus the raw material that shares it — verbatim excerpts
  from flow posts, and/or a verbatim passage from a library document.
  You are an indexer, not an author: no invented text of any kind.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['topic' [%string 'a plain noun-phrase label for the shared topic']]
      ['question' [%string 'optional: one genuine open question the material raises — to stimulate thought, never to smuggle a take']]
      ['posts' [%string 'flow side: newline-separated lines, each "id-prefix | author-prefix | verbatim excerpt from the post"']]
      ['passage' [%string 'library side: one passage copied VERBATIM from a library document']]
      ['source' [%string 'the library document the passage comes from (its filename from list_library)']]
      ['from' [%string 'library side: first line number of the passage (from read_doc output)']]
      ['to' [%string 'library side: last line number of the passage']]
      ['post_ids' [%array 'flow side: the FULL post ids of every post cited in posts (from get_feed output)']]
  ==
++  required  ~['topic']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  jstr
    |=  key=@t
    ^-  @t
    =/  v=(unit json)  (~(get by args.st) key)
    ?:(?=([~ %s *] v) p.u.v '')
  ?:  =('' (jstr 'topic'))  (pure:m [%error 'topic is required'])
  ?:  &(=('' (jstr 'posts')) =('' (jstr 'passage')))
    (pure:m [%error 'a connection needs material: posts, a passage, or both'])
  ;<  now=@da  bind:m  get-time:io
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  id=@t  (scot %uv (end [3 6] eny))
  ::  structured references beside the verbatim text, so the dashboard
  ::  can open the actual post and jump to the actual lines
  =/  num  |=(k=@t ^-(json ?~(v=(rush (jstr k) dem) ~ (numb:enjs:format u.v))))
  =/  ids=(list @t)
    =/  v=(unit json)  (~(get by args.st) 'post_ids')
    ?.  ?=([~ %a *] v)  ~
    %+  murn  p.u.v
    |=(j=json ?:(?=([%s *] j) `p.j ~))
  ::  snapshot the cited posts NOW: the flow is a moving window and a
  ::  connection is about what was there when it was made
  ;<  snap=(list json)  bind:m  (snapshot-posts ids)
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['topic' s+(jstr 'topic')]
        ['question' s+(jstr 'question')]
        ['posts' s+(jstr 'posts')]
        ['passage' s+(jstr 'passage')]
        ['source' s+(jstr 'source')]
        ['from' (num 'from')]
        ['to' (num 'to')]
        ['post_ids' [%a (turn ids |=(i=@t s+i))]]
        ['post_snap' [%a snap]]
        ['at' (sect:enjs:format now)]
    ==
  =/  =road:tarball
    [%& %& /apps/ghostprompter/proposals (crip "{(trip id)}.json")]
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] doc] ~])
  ?^  err  (pure:m [%error 'failed to write the connection'])
  (pure:m [%text (cat 3 'Filed connection ' id)])
--
|%
::  +snapshot-posts: the cited posts as {id, pubkey, at, content, name},
::  read from nostrill the way get_feed does. Ids not in the current
::  feed are skipped (the pasted excerpt still records them).
++  snapshot-posts
  |=  ids=(list @t)
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  ids  (pure:m ~)
  ;<  feed=json  bind:m  (typed-scry:io json %json /gx/nostrill/j/nostr/json)
  ?.  ?=([%o *] feed)  (pure:m ~)
  =/  want=(set @t)  (sy ids)
  ::  every event in every feed of every source; profiles by pubkey
  =/  srcs=(list json)  (turn ~(tap by p.feed) |=([* j=json] j))
  =/  events=(list json)
    %-  zing
    %+  turn  srcs
    |=  src=json
    ^-  (list json)
    ?.  ?=([%o *] src)  ~
    %-  zing
    %+  turn  ~(tap by p.src)
    |=  [* relay=json]
    ^-  (list json)
    ?.  ?=([%o *] relay)  ~
    =/  f  (~(get by p.relay) 'feed')
    ?.(?=([~ %a *] f) ~ p.u.f)
  =/  profiles=(map @t json)
    %-  ~(gas by *(map @t json))
    %+  murn  events
    |=  ev=json
    ^-  (unit [@t json])
    ?.  =(0 (jnum ev 'kind'))  ~
    =/  pk=@t  (jstr-of ev 'pubkey')
    =/  meta=(unit json)  (de:json:html (jstr-of ev 'content'))
    ?~  meta  ~
    `[pk u.meta]
  ::  the same event arrives from every relay that carries it: one copy
  %-  pure:m
  =<  out
  %+  roll  events
  |=  [ev=json acc=[seen=(set @t) out=(list json)]]
  =/  id=@t  (jstr-of ev 'id')
  ?.  (~(has in want) id)  acc
  ?:  (~(has in seen.acc) id)  acc
  ?.  =(1 (jnum ev 'kind'))  acc
  =/  pk=@t  (jstr-of ev 'pubkey')
  =/  prof=json  (fall (~(get by profiles) pk) [%o ~])
  =/  row=json
    %-  pairs:enjs:format
    :~  ['id' s+id]
        ['pubkey' s+pk]
        ['at' (numb:enjs:format (jnum ev 'created_at'))]
        ['content' s+(jstr-of ev 'content')]
        ['name' s+(jstr-of prof 'name')]
        ['picture' s+(jstr-of prof 'picture')]
    ==
  [(~(put in seen.acc) id) (snoc out.acc row)]
++  jstr-of
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=([%o *] j)  ''
  =/  v  (~(get by p.j) k)
  ?:(?=([~ %s *] v) p.u.v '')
++  jnum
  |=  [j=json k=@t]
  ^-  @ud
  ?.  ?=([%o *] j)  0
  =/  v  (~(get by p.j) k)
  ?~  v  0
  ?:  ?=([%n *] u.v)  (fall (rush p.u.v dem) 0)
  ?:  ?=([%s *] u.v)  (fall (rush p.u.v dem) 0)
  0
--
