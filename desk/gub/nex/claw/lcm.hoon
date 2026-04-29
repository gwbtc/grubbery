::  lcm nexus: lossless context management
::
::  Hierarchical summary DAG with immutable message store.
::  Accepts messages via poke, compacts when context exceeds
::  threshold, assembles token-budgeted context windows.
::
::  Files:
::    config.json  — parameters (threshold, chunk size, targets)
::    main.sig     — poke handler (ingest, compact, assemble)
::    store.json   — immutable message array (index = seq)
::    dag.json     — summary node array (index = id)
::    active.json  — active context ordering (msg/sum refs)
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['threshold' (numb:enjs:format 32.000)]
            ['chunk_tokens' (numb:enjs:format 20.000)]
            ['leaf_target' (numb:enjs:format 1.200)]
            ['condense_target' (numb:enjs:format 2.000)]
            ['fresh_tail' (numb:enjs:format 32)]
            ['leaf_fanout' (numb:enjs:format 8)]
            ['condense_fanout' (numb:enjs:format 4)]
            ['proxy' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'store.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %& [/ %'dag.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %& [/ %'active.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %& [/ %'assembled.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %& [/ %'grep-results.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>((lcm-page ""))]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ~&  >  "%lcm: main.sig on-file entered"
        ;<  ~  bind:m  (rise-wait:io prod "%lcm: failed")
        ~&  >  "%lcm: past rise-wait, entering loop"
        |-
        ~&  >  "%lcm: waiting for poke"
        ;<  =sage:tarball  bind:m  take-poke:io
        ~&  >  ["%lcm: got poke, mark:" name.p.sage]
        =/  jon=json
          ?:  =(%json name.p.sage)
            (fall (mole |.(!<(json q.sage))) *json)
          ?:  =(%mime name.p.sage)
            =/  m=mime  (fall (mole |.(!<(mime q.sage))) *mime)
            (fall (de:json:html q.q.m) *json)
          *json
        ~&  >  ["%lcm: parsed json:" jon]
        ?.  ?=([%o *] jon)
          ~&  >>>  "%lcm: not a json object, skipping"
          $
        =/  act=@t  (get-str jon 'action')
        ~&  >  ["%lcm: action:" act]
        ?+    act
          ~&  >>>  ["%lcm: unknown action:" act]
          $
        ::
            %'ingest'
          =/  role=@t  (get-str jon 'role')
          =/  content=@t  (get-str jon 'content')
          ~&  >  ["%lcm: ingest" role (met 3 content) "bytes"]
          ?:  |(=('' role) =('' content))
            ~&  >>>  "%lcm: empty role or content"
            $
          ;<  ~  bind:m  (do-ingest role content)
          ~&  >  "%lcm: ingest done"
          $
        ::
            %'compact'
          ~&  >  "%lcm: compact requested"
          ;<  ~  bind:m  do-compact
          ~&  >  "%lcm: compact done"
          $
        ::
            %'assemble'
          =/  budget=@ud  (get-num jon 'budget')
          ~&  >  ["%lcm: assemble with budget" budget]
          ?:  =(0 budget)
            ~&  >>>  "%lcm: zero budget"
            $
          ;<  ~  bind:m  (do-assemble budget)
          ~&  >  "%lcm: assemble done"
          $
        ::
            %'grep'
          =/  query=@t  (get-str jon 'query')
          ~&  >  ["%lcm: grep query:" query]
          ?:  =('' query)
            ~&  >>>  "%lcm: empty query"
            $
          ;<  ~  bind:m  (do-grep query)
          ~&  >  "%lcm: grep done"
          $
        ==
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%lcm page: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  ball-id=tape
          %-  zing
          %+  join  "/"
          ^-  (list tape)
          (turn path.here trip)
        ;<  ~  bind:m  (replace:io !>((lcm-page ball-id)))
        stay:m
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'LCM subdirectory.'
            ~
          'Lossless context management. Hierarchical summary DAG over immutable message store.'
        ==
          %|
        ?+  rail.p.mana  'LCM file.'
          [~ %'config.json']   'LCM config: threshold, chunk size, targets, proxy.'
          [~ %'main.sig']      'Poke handler: ingest, compact, assemble, grep.'
          [~ %'store.json']    'Immutable message store (array).'
          [~ %'dag.json']      'Summary DAG (array).'
          [~ %'active.json']   'Active context ordering.'
        ==
      ==
    --
::
::  helpers
::
|%
::
::  json field access
::
++  get-str
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  ''
  ?.  ?=(%s -.u.val)  ''
  p.u.val
::
++  get-num
  |=  [jon=json key=@t]
  ^-  @ud
  ?.  ?=(%o -.jon)  0
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  0
  ?.  ?=(%n -.u.val)  0
  (fall (rush p.u.val dem) 0)
::
::  +estimate-tokens: rough token count from cord length
::
++  estimate-tokens
  |=  text=@t
  ^-  @ud
  (div (add (met 3 text) 3) 4)
::
::  file I/O helpers
::
++  read-json-file
  |=  name=@t
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball name)
  ;<  =seen:nexus  bind:m  (peek:io road `%json)
  ?.  ?=([%& %file *] seen)  (pure:m [%a ~])
  (pure:m (fall (mole |.(!<(json q.sage.p.seen))) [%a ~]))
::
++  write-json-file
  |=  [name=@t dat=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (cord-to-road:tarball name) [[/ %json] !>(dat)])
::
::  +json-arr: unwrap json array, default empty
::
++  json-arr
  |=  j=json
  ^-  (list json)
  ?.  ?=(%a -.j)  ~
  p.j
::
::  +msg-tokens: get token estimate from a stored message json
::
++  msg-tokens
  |=  msg=json
  ^-  @ud
  (get-num msg 'tokens')
::
::  +sum-tokens: get token estimate from a summary json
::
++  sum-tokens
  |=  sum=json
  ^-  @ud
  (get-num sum 'tokens')
::
::  +sum-depth: get depth from a summary json
::
++  sum-depth
  |=  sum=json
  ^-  @ud
  (get-num sum 'depth')
::
::  +item-type: get type field from a context item
::
++  item-type
  |=  item=json
  ^-  @t
  (get-str item 'type')
::
::  +item-seq: get seq field from a msg context item
::
++  item-seq
  |=  item=json
  ^-  @ud
  (get-num item 'seq')
::
::  +item-id: get id field from a sum context item
::
++  item-id
  |=  item=json
  ^-  @ud
  (get-num item 'id')
::
::  +snag-or: safe list index with default
::
++  snag-or
  |=  [idx=@ud lst=(list json) def=json]
  ^-  json
  ?:  (gte idx (lent lst))  def
  (snag idx lst)
::
::  +do-ingest: add a message to the store and active context
::
++  do-ingest
  |=  [role=@t content=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  tokens=@ud  (estimate-tokens content)
  ;<  store=json  bind:m  (read-json-file './store.json')
  =/  msgs=(list json)  (json-arr store)
  =/  seq=@ud  (lent msgs)
  =/  new-msg=json
    %-  pairs:enjs:format
    :~  ['role' s+role]
        ['content' s+content]
        ['tokens' (numb:enjs:format tokens)]
    ==
  =/  new-store=json  [%a (snoc msgs new-msg)]
  ;<  ~  bind:m  (write-json-file './store.json' new-store)
  ::  append ref to active context
  ;<  active=json  bind:m  (read-json-file './active.json')
  =/  items=(list json)  (json-arr active)
  =/  new-item=json
    (pairs:enjs:format ~[['type' s+'msg'] ['seq' (numb:enjs:format seq)]])
  =/  new-active=json  [%a (snoc items new-item)]
  ;<  ~  bind:m  (write-json-file './active.json' new-active)
  ~&  >  ["%lcm: ingested" role seq tokens "tokens"]
  (pure:m ~)
::
::  +do-assemble: build context within token budget, write to assembled.json
::
::  Strategy: always include the fresh tail (last N items) raw.
::  Fill remaining budget from older items (summaries or messages).
::
++  do-assemble
  |=  budget=@ud
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json     bind:m  (read-json-file './config.json')
  ;<  store=json   bind:m  (read-json-file './store.json')
  ;<  dag=json     bind:m  (read-json-file './dag.json')
  ;<  active=json  bind:m  (read-json-file './active.json')
  =/  msgs=(list json)   (json-arr store)
  =/  sums=(list json)   (json-arr dag)
  =/  items=(list json)  (json-arr active)
  =/  tail-n=@ud  (min (lent items) (get-num cfg 'fresh_tail'))
  =/  split=@ud  (sub (lent items) tail-n)
  =/  before=(list json)  (scag split items)
  =/  fresh=(list json)   (slag split items)
  ::  resolve fresh tail — always included
  =/  fresh-resolved=(list json)
    %+  murn  fresh
    |=  item=json
    ^-  (unit json)
    =/  typ=@t  (item-type item)
    ?:  =(typ 'msg')
      =/  msg=json  (snag-or (item-seq item) msgs *json)
      `(pairs:enjs:format ~[['role' s+(get-str msg 'role')] ['content' s+(get-str msg 'content')]])
    ?:  =(typ 'sum')
      =/  sum=json  (snag-or (item-id item) sums *json)
      =/  txt=@t
        %+  rap  3
        :~  '<summary id="'
            (crip (a-co:co (item-id item)))
            '" depth="'
            (crip (a-co:co (sum-depth sum)))
            '">\0a'
            (get-str sum 'content')
            '\0a</summary>'
        ==
      `(pairs:enjs:format ~[['role' s+'user'] ['content' s+txt]])
    ~
  ::  count fresh tail tokens
  =/  fresh-tok=@ud
    %+  roll  fresh
    |=  [item=json acc=@ud]
    =/  typ=@t  (item-type item)
    ?:  =(typ 'msg')  (add acc (msg-tokens (snag-or (item-seq item) msgs *json)))
    ?:  =(typ 'sum')  (add acc (sum-tokens (snag-or (item-id item) sums *json)))
    acc
  =/  remaining=@ud  ?:((gth fresh-tok budget) 0 (sub budget fresh-tok))
  ::  fill from older items within remaining budget
  =/  prefix=(list json)  ~
  |-
  ?~  before
    =/  result=json  [%a (weld (flop prefix) fresh-resolved)]
    ;<  ~  bind:m  (write-json-file './assembled.json' result)
    ~&  >  ["%lcm: assembled" (lent (weld (flop prefix) fresh-resolved)) "messages within" budget "token budget"]
    (pure:m ~)
  =/  item=json  i.before
  =/  typ=@t  (item-type item)
  =/  tok=@ud
    ?:  =(typ 'msg')  (msg-tokens (snag-or (item-seq item) msgs *json))
    ?:  =(typ 'sum')  (sum-tokens (snag-or (item-id item) sums *json))
    0
  ?:  (gth tok remaining)
    $(before t.before)
  =/  resolved=(unit json)
    ?:  =(typ 'msg')
      =/  msg=json  (snag-or (item-seq item) msgs *json)
      `(pairs:enjs:format ~[['role' s+(get-str msg 'role')] ['content' s+(get-str msg 'content')]])
    ?:  =(typ 'sum')
      =/  sum=json  (snag-or (item-id item) sums *json)
      =/  txt=@t
        %+  rap  3
        :~  '<summary id="'
            (crip (a-co:co (item-id item)))
            '" depth="'
            (crip (a-co:co (sum-depth sum)))
            '">\0a'
            (get-str sum 'content')
            '\0a</summary>'
        ==
      `(pairs:enjs:format ~[['role' s+'user'] ['content' s+txt]])
    ~
  ?~  resolved  $(before t.before)
  $(before t.before, remaining (sub remaining tok), prefix [u.resolved prefix])
::
::  +do-compact: check threshold, select chunk, summarize via LLM
::
++  do-compact
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json     bind:m  (read-json-file './config.json')
  ;<  store=json   bind:m  (read-json-file './store.json')
  ;<  dag=json     bind:m  (read-json-file './dag.json')
  ;<  active=json  bind:m  (read-json-file './active.json')
  =/  msgs=(list json)   (json-arr store)
  =/  sums=(list json)   (json-arr dag)
  =/  items=(list json)  (json-arr active)
  =/  threshold=@ud   (get-num cfg 'threshold')
  =/  chunk-tok=@ud   (get-num cfg 'chunk_tokens')
  =/  leaf-target=@ud  (get-num cfg 'leaf_target')
  =/  tail-n=@ud      (get-num cfg 'fresh_tail')
  =/  leaf-fan=@ud    (get-num cfg 'leaf_fanout')
  =/  proxy=@t  (get-str cfg 'proxy')
  ?:  =('' proxy)
    ~&  >>>  "%lcm: no proxy configured, set 'proxy' in config.json"
    (pure:m ~)
  ::  count total tokens in active context
  =/  total-tok=@ud
    %+  roll  items
    |=  [item=json acc=@ud]
    =/  typ=@t  (item-type item)
    ?:  =(typ 'msg')  (add acc (msg-tokens (snag-or (item-seq item) msgs *json)))
    ?:  =(typ 'sum')  (add acc (sum-tokens (snag-or (item-id item) sums *json)))
    acc
  ~&  >  ["%lcm: total tokens" total-tok "threshold" threshold]
  ::  select raw messages to compact
  ::  if above threshold, only compact outside fresh tail
  ::  if manual (below threshold), compact all raw messages
  =/  above=?  (gth total-tok threshold)
  =/  split=@ud
    ?:  above
      (sub (lent items) (min (lent items) tail-n))
    (lent items)
  =/  eligible=(list json)  (scag split items)
  =/  chunk=(list @ud)  ~
  =/  chunk-acc=@ud  0
  |-
  ?~  eligible
    ?~  chunk
      ~&  >  "%lcm: nothing to compact"
      (pure:m ~)
    =/  chunk-seqs=(list @ud)  (flop chunk)
    (do-leaf-compact chunk-seqs msgs sums items leaf-target proxy)
  =/  item=json  i.eligible
  ?.  =('msg' (item-type item))
    $(eligible t.eligible)
  =/  seq=@ud  (item-seq item)
  =/  tok=@ud  (msg-tokens (snag-or seq msgs *json))
  ?:  &(!=(~ chunk) (gth (add chunk-acc tok) chunk-tok))
    =/  chunk-seqs=(list @ud)  (flop chunk)
    (do-leaf-compact chunk-seqs msgs sums items leaf-target proxy)
  $(eligible t.eligible, chunk [seq chunk], chunk-acc (add chunk-acc tok))
::
::  +do-leaf-compact: summarize a chunk of messages into a leaf node
::
++  do-leaf-compact
  |=  [chunk=(list @ud) msgs=(list json) sums=(list json) items=(list json) target=@ud proxy=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  build the text to summarize
  =/  input-text=@t
    %-  crip
    %-  zing
    %+  turn  chunk
    |=  seq=@ud
    =/  msg=json  (snag-or seq msgs *json)
    :(weld (trip (get-str msg 'role')) ": " (trip (get-str msg 'content')) "\0a")
  ::  build summarization prompt
  =/  sys-prompt=@t  (leaf-prompt target)
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['model' s+'claude-haiku-4-5-20251001']
        ['max_tokens' (numb:enjs:format (mul 2 target))]
        ['system' s+sys-prompt]
        ['messages' [%a ~[(pairs:enjs:format ~[['role' s+'user'] ['content' s+input-text]])]]]
    ==
  ~&  >  ["%lcm: compacting" (lent chunk) "messages"]
  =/  proxy-road=road:tarball  (cord-to-road:tarball proxy)
  ;<  ~  bind:m  (poke:io proxy-road [/ %json] !>(payload))
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  resp=json  (fall (mole |.(!<(json q.sage))) *json)
  =/  summary-text=(unit @t)  (parse-api-text resp)
  ?~  summary-text
    ~&  >>>  "%lcm: failed to parse compaction response"
    (pure:m ~)
  =/  sum-tok=@ud  (estimate-tokens u.summary-text)
  ::  create leaf summary node
  =/  sid=@ud  (lent sums)
  =/  new-sum=json
    %-  pairs:enjs:format
    :~  ['kind' s+'leaf']
        ['depth' (numb:enjs:format 0)]
        ['content' s+u.summary-text]
        ['tokens' (numb:enjs:format sum-tok)]
        ['sources' [%a (turn chunk |=(s=@ud (numb:enjs:format s)))]]
    ==
  =/  new-dag=json  [%a (snoc sums new-sum)]
  ;<  ~  bind:m  (write-json-file './dag.json' new-dag)
  ::  replace compacted messages in active context with summary ref
  =/  chunk-set=(set @ud)  (silt chunk)
  =/  new-items=(list json)
    =|  out=(list json)
    =|  inserted=_|
    |-
    ?~  items  (flop out)
    =/  item=json  i.items
    ?.  =('msg' (item-type item))
      $(items t.items, out [item out])
    ?.  (~(has in chunk-set) (item-seq item))
      $(items t.items, out [item out])
    ?:  inserted
      $(items t.items)
    =/  sum-ref=json
      (pairs:enjs:format ~[['type' s+'sum'] ['id' (numb:enjs:format sid)]])
    $(items t.items, out [sum-ref out], inserted &)
  ;<  ~  bind:m  (write-json-file './active.json' [%a new-items])
  ~&  >  ["%lcm: created leaf summary" sid (lent chunk) "msgs ->" sum-tok "tokens"]
  ::  check for condensation opportunity
  (maybe-condense new-items (snoc sums new-sum))
::
::  +maybe-condense: condense same-depth summaries if enough accumulate
::
++  maybe-condense
  |=  [items=(list json) sums=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg=json  bind:m  (read-json-file './config.json')
  =/  tail-n=@ud       (get-num cfg 'fresh_tail')
  =/  cond-fan=@ud     (get-num cfg 'condense_fanout')
  =/  cond-target=@ud  (get-num cfg 'condense_target')
  =/  proxy=@t  (get-str cfg 'proxy')
  ?:  =('' proxy)  (pure:m ~)
  ::  find same-depth summary groups outside fresh tail
  =/  split=@ud  (sub (lent items) (min (lent items) tail-n))
  =/  eligible=(list json)  (scag split items)
  =/  depth-map=(map @ud (list @ud))  ~
  |-
  ?~  eligible
    ::  find shallowest depth with enough summaries
    =/  depths=(list @ud)  (sort ~(tap in ~(key by depth-map)) lth)
    |-
    ?~  depths  (pure:m ~)
    =/  ids=(list @ud)  (~(got by depth-map) i.depths)
    ?.  (gte (lent ids) cond-fan)
      $(depths t.depths)
    ::  condense this group
    (do-condense (flop ids) sums items +(i.depths) cond-target proxy)
  =/  item=json  i.eligible
  ?.  =((item-type item) 'sum')  $(eligible t.eligible)
  =/  id=@ud    (item-id item)
  =/  sum=json  (snag-or id sums *json)
  =/  d=@ud     (sum-depth sum)
  =/  existing=(list @ud)  (fall (~(get by depth-map) d) ~)
  $(eligible t.eligible, depth-map (~(put by depth-map) d [id existing]))
::
::  +do-condense: merge same-depth summaries into a higher-depth node
::
++  do-condense
  |=  [ids=(list @ud) sums=(list json) items=(list json) new-depth=@ud target=@ud proxy=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  input-text=@t
    %-  crip
    %-  zing
    %+  turn  ids
    |=  id=@ud
    =/  sum=json  (snag-or id sums *json)
    ;:  weld
      "--- Summary (depth "
      (a-co:co (sum-depth sum))
      ") ---\0a"
      (trip (get-str sum 'content'))
      "\0a\0a"
    ==
  =/  sys-prompt=@t  (condense-prompt new-depth target)
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['model' s+'claude-haiku-4-5-20251001']
        ['max_tokens' (numb:enjs:format (mul 2 target))]
        ['system' s+sys-prompt]
        ['messages' [%a ~[(pairs:enjs:format ~[['role' s+'user'] ['content' s+input-text]])]]]
    ==
  ~&  >  ["%lcm: condensing" (lent ids) "depth-" (dec new-depth) "summaries"]
  =/  proxy-road=road:tarball  (cord-to-road:tarball proxy)
  ;<  ~  bind:m  (poke:io proxy-road [/ %json] !>(payload))
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  resp=json  (fall (mole |.(!<(json q.sage))) *json)
  =/  summary-text=(unit @t)  (parse-api-text resp)
  ?~  summary-text
    ~&  >>>  "%lcm: failed to parse condensation response"
    (pure:m ~)
  =/  sum-tok=@ud  (estimate-tokens u.summary-text)
  =/  sid=@ud  (lent sums)
  ::  collect all sources from children
  =/  all-sources=json
    :-  %a
    %-  zing
    %+  turn  ids
    |=  id=@ud
    =/  sum=json  (snag-or id sums *json)
    (json-arr (~(gut by ?>(?=(%o -.sum) p.sum)) 'sources' [%a ~]))
  =/  new-sum=json
    %-  pairs:enjs:format
    :~  ['kind' s+'condensed']
        ['depth' (numb:enjs:format new-depth)]
        ['content' s+u.summary-text]
        ['tokens' (numb:enjs:format sum-tok)]
        ['sources' all-sources]
        ['parents' [%a (turn ids |=(id=@ud (numb:enjs:format id)))]]
    ==
  =/  new-dag=json  [%a (snoc sums new-sum)]
  ;<  ~  bind:m  (write-json-file './dag.json' new-dag)
  ::  replace child summaries in active with new condensed ref
  =/  id-set=(set @ud)  (silt ids)
  =/  new-items=(list json)
    =|  out=(list json)
    =|  inserted=_|
    |-
    ?~  items  (flop out)
    =/  item=json  i.items
    ?.  =((item-type item) 'sum')
      $(items t.items, out [item out])
    ?.  (~(has in id-set) (item-id item))
      $(items t.items, out [item out])
    ?:  inserted
      $(items t.items)
    =/  sum-ref=json
      (pairs:enjs:format ~[['type' s+'sum'] ['id' (numb:enjs:format sid)]])
    $(items t.items, out [sum-ref out], inserted &)
  ;<  ~  bind:m  (write-json-file './active.json' [%a new-items])
  ~&  >  ["%lcm: created condensed summary" sid "depth" new-depth (lent ids) "children ->" sum-tok "tokens"]
  (pure:m ~)
::
::  +do-grep: search immutable store for matching messages
::
++  do-grep
  |=  query=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  store=json  bind:m  (read-json-file './store.json')
  ;<  dag=json    bind:m  (read-json-file './dag.json')
  =/  msgs=(list json)  (json-arr store)
  =/  sums=(list json)  (json-arr dag)
  =/  q=tape  (cass (trip query))
  ::  search messages
  =/  msg-hits=(list json)  ~
  =/  idx=@ud  0
  =.  msg-hits
    |-
    ?~  msgs  (flop msg-hits)
    =/  content=tape  (cass (trip (get-str i.msgs 'content')))
    =/  hit=?  !=(~ (find q content))
    %=  $
      msgs  t.msgs
      idx   +(idx)
      msg-hits  ?.  hit  msg-hits
        :_  msg-hits
        %-  pairs:enjs:format
        :~  ['type' s+'msg']
            ['seq' (numb:enjs:format idx)]
            ['role' s+(get-str i.msgs 'role')]
            ['content' s+(crip (scag 300 (trip (get-str i.msgs 'content'))))]
        ==
    ==
  ::  search summaries
  =/  sum-hits=(list json)  ~
  =/  sidx=@ud  0
  =.  sum-hits
    |-
    ?~  sums  (flop sum-hits)
    =/  content=tape  (cass (trip (get-str i.sums 'content')))
    =/  hit=?  !=(~ (find q content))
    %=  $
      sums  t.sums
      sidx  +(sidx)
      sum-hits  ?.  hit  sum-hits
        :_  sum-hits
        %-  pairs:enjs:format
        :~  ['type' s+'summary']
            ['id' (numb:enjs:format sidx)]
            ['depth' (numb:enjs:format (sum-depth i.sums))]
            ['content' s+(crip (scag 500 (trip (get-str i.sums 'content'))))]
        ==
    ==
  =/  results=json  [%a (weld msg-hits sum-hits)]
  ;<  ~  bind:m  (write-json-file './grep-results.json' results)
  ~&  >  ["%lcm: grep found" (lent msg-hits) "messages," (lent sum-hits) "summaries"]
  (pure:m ~)
::
::  +parse-api-text: extract text from anthropic API response
::
++  parse-api-text
  |=  resp=json
  ^-  (unit @t)
  ?.  ?=(%o -.resp)  ~
  =/  content  (~(get by p.resp) 'content')
  ?~  content  ~
  ?.  ?=([~ %a *] content)  ~
  ?~  p.u.content  ~
  =/  first=json  i.p.u.content
  ?.  ?=(%o -.first)  ~
  =/  text  (~(get by p.first) 'text')
  ?.  ?=([~ %s *] text)  ~
  `p.u.text
::
::  +leaf-prompt: system prompt for leaf (depth 0) summarization
::
++  leaf-prompt
  |=  target=@ud
  ^-  @t
  %-  crip
  ;:  weld
    "You summarize a SEGMENT of a conversation for future model turns. "
    "This is incremental memory compaction, not a full-conversation summary.\0a\0a"
    "Preserve:\0a"
    "- Key decisions, rationale, constraints, active tasks\0a"
    "- Technical details needed to continue work safely\0a"
    "- File operations (created, modified, deleted) with paths\0a"
    "- Timestamps for key events\0a\0a"
    "Remove:\0a"
    "- Repetition and conversational filler\0a"
    "- Resolved intermediate states\0a\0a"
    "Output: plain text, no markdown headings, concise.\0a"
    "End with: \"Expand for details about: <list of compressed-away specifics>\"\0a"
    "Target: ~"
    (a-co:co target)
    " tokens."
  ==
::
::  +condense-prompt: system prompt for condensation (depth 1+)
::
++  condense-prompt
  |=  [depth=@ud target=@ud]
  ^-  @t
  %-  crip
  ;:  weld
    "You are condensing multiple conversation summaries into a higher-level memory node.\0a"
    "Focus on what matters for continuation:\0a"
    "- Decisions still in effect and their rationale\0a"
    "- Completed work with outcomes\0a"
    "- Things still in progress: current state, what remains\0a"
    "- Blockers and open questions\0a\0a"
    "Drop:\0a"
    "- Per-session operational minutiae\0a"
    "- Intermediate states superseded by later summaries\0a"
    "- Process details (unless the method was the decision)\0a\0a"
    "Output: plain text, concise.\0a"
    "End with: \"Expand for details about: <list of compressed-away specifics>\"\0a"
    "Target: ~"
    (a-co:co target)
    " tokens."
  ==
::
::  +lcm-page: test UI for LCM nexus
::
++  lcm-page
  |=  ball-id=tape
  ^-  manx
  ;html
    ;head
      ;title: lcm
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  lcm-style
      ==
    ==
    ;body
      ;div#app
        ;h1: lcm
        ;div.subtitle: lossless context management
        ;div#panels
          ;div.panel
            ;h2: ingest
            ;div.row
              ;select#role
                ;option(value "user"): user
                ;option(value "assistant"): assistant
              ==
              ;button(onclick "doIngest()"): send
            ==
            ;textarea#content(rows "3", placeholder "message content...");
          ==
          ;div.panel
            ;h2: controls
            ;div.row
              ;button(onclick "doCompact()"): compact
              ;input#budget(type "number", value "32000", placeholder "budget");
              ;button(onclick "doAssemble()"): assemble
            ==
            ;div.row
              ;input#grep-q(type "text", placeholder "grep query...");
              ;button(onclick "doGrep()"): grep
            ==
            ;div.row
              ;input#proxy(type "text", placeholder "proxy road e.g. /apis/anthropic.sig");
              ;button(onclick "saveConfig()"): save config
            ==
          ==
        ==
        ;div#panels
          ;div.panel.wide
            ;h2: active context
            ;div#active-view.mono;
          ==
        ==
        ;div#panels
          ;div.panel
            ;h2: store
            ;div#store-view.mono;
          ==
          ;div.panel
            ;h2: dag
            ;div#dag-view.mono;
          ==
        ==
        ;div.panel.wide
          ;h2: assembled
          ;div#assembled-view.mono;
        ==
        ;div.panel.wide
          ;h2: grep results
          ;div#grep-view.mono;
        ==
        ;div#status;
      ==
      ;script
        ;+  ;/  (lcm-script ball-id)
      ==
    ==
  ==
::
++  lcm-style
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; padding: 20px; }
  h1 \{ font-size: 22px; margin-bottom: 2px; }
  .subtitle \{ color: #666; font-size: 12px; margin-bottom: 16px; }
  h2 \{ font-size: 13px; color: #888; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; }
  #panels \{ display: flex; gap: 12px; margin-bottom: 12px; }
  .panel \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; padding: 12px; flex: 1; }
  .panel.wide \{ margin-bottom: 12px; }
  .row \{ display: flex; gap: 6px; margin-bottom: 6px; align-items: center; }
  textarea, input[type="text"], input[type="number"] \{ background: #111; border: 1px solid #333; border-radius: 4px; color: #eee; padding: 6px 8px; font-size: 13px; outline: none; }
  textarea \{ width: 100%; resize: vertical; font-family: monospace; }
  input[type="text"] \{ flex: 1; }
  input[type="number"] \{ width: 80px; }
  select \{ background: #111; border: 1px solid #333; border-radius: 4px; color: #eee; padding: 6px 8px; font-size: 13px; }
  button \{ padding: 6px 14px; border-radius: 4px; border: 1px solid #444; background: #222; color: #eee; font-size: 12px; cursor: pointer; }
  button:hover \{ background: #333; border-color: #666; }
  .mono \{ font-family: monospace; font-size: 12px; white-space: pre-wrap; word-break: break-all; max-height: 300px; overflow-y: auto; color: #aaa; }
  #status \{ font-size: 12px; color: #4ade80; margin-top: 8px; }
  .msg-item \{ padding: 4px 0; border-bottom: 1px solid #222; }
  .msg-role \{ color: #60a5fa; }
  .sum-item \{ padding: 4px 0; border-bottom: 1px solid #222; color: #f59e0b; }
  .active-msg \{ color: #60a5fa; }
  .active-sum \{ color: #f59e0b; }
  .grep-hit \{ padding: 4px 0; border-bottom: 1px solid #222; }
  """
::
++  lcm-script
  |=  ball-id=tape
  ^-  tape
  ;:  weld
    "var API = '/grubbery/api';\0avar BALL = '{ball-id}';\0a"
  """

  function fileUrl(name) \{
    return API + '/file/' + BALL + '/' + name + '?mark=json';
  }

  async function readFile(name) \{
    var r = await fetch(fileUrl(name));
    if (!r.ok) return null;
    return r.json();
  }

  async function pokeSig(body) \{
    var r = await fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    });
    return r.json();
  }

  function renderStore(data) \{
    var el = document.getElementById('store-view');
    if (!data || !Array.isArray(data) || !data.length) \{
      el.textContent = '(empty)'; return;
    }
    el.innerHTML = data.map(function(m, i) \{
      return '<div class="msg-item"><span class="msg-role">[' + i + '] ' + m.role + '</span>: ' +
        (m.content || '').substring(0, 200) + ' <span style="color:#666">(' + m.tokens + 't)</span></div>';
    }).join('');
  }

  function renderDag(data) \{
    var el = document.getElementById('dag-view');
    if (!data || !Array.isArray(data) || !data.length) \{
      el.textContent = '(empty)'; return;
    }
    el.innerHTML = data.map(function(s, i) \{
      return '<div class="sum-item">[' + i + '] d' + s.depth + ' ' + s.kind +
        ' (' + s.tokens + 't) src:' + JSON.stringify(s.sources) +
        '\\n' + (s.content || '').substring(0, 300) + '</div>';
    }).join('');
  }

  function renderActive(data) \{
    var el = document.getElementById('active-view');
    if (!data || !Array.isArray(data) || !data.length) \{
      el.textContent = '(empty)'; return;
    }
    el.innerHTML = data.map(function(item) \{
      if (item.type === 'msg') return '<span class="active-msg">msg:' + item.seq + '</span> ';
      if (item.type === 'sum') return '<span class="active-sum">sum:' + item.id + '</span> ';
      return '? ';
    }).join('');
  }

  function renderAssembled(data) \{
    var el = document.getElementById('assembled-view');
    if (!data || !Array.isArray(data) || !data.length) \{
      el.textContent = '(not yet assembled)'; return;
    }
    el.innerHTML = data.map(function(m) \{
      return '<div class="msg-item"><span class="msg-role">' + m.role + '</span>: ' +
        (m.content || '').substring(0, 400) + '</div>';
    }).join('');
  }

  function renderGrep(data) \{
    var el = document.getElementById('grep-view');
    if (!data || !Array.isArray(data) || !data.length) \{
      el.textContent = 'no results'; return;
    }
    el.innerHTML = data.map(function(r) \{
      if (r.type === 'msg') return '<div class="grep-hit"><span class="msg-role">msg:' + r.seq + ' ' + r.role + '</span>: ' + r.content + '</div>';
      if (r.type === 'summary') return '<div class="grep-hit"><span class="active-sum">sum:' + r.id + ' d' + r.depth + '</span>: ' + r.content + '</div>';
      return '';
    }).join('');
  }

  async function refresh() \{
    var results = await Promise.all([
      readFile('store.json'),
      readFile('dag.json'),
      readFile('active.json'),
      readFile('assembled.json')
    ]);
    renderStore(results[0]);
    renderDag(results[1]);
    renderActive(results[2]);
    renderAssembled(results[3]);
  }

  async function doIngest() \{
    var role = document.getElementById('role').value;
    var content = document.getElementById('content').value;
    if (!content) return;
    document.getElementById('status').textContent = 'ingesting...';
    await pokeSig(\{action: 'ingest', role: role, content: content});
    document.getElementById('content').value = '';
    document.getElementById('status').textContent = 'ingested';
    setTimeout(refresh, 300);
  }

  async function doCompact() \{
    document.getElementById('status').textContent = 'compacting...';
    await pokeSig(\{action: 'compact'});
    document.getElementById('status').textContent = 'compacted';
    setTimeout(refresh, 1000);
  }

  async function doAssemble() \{
    var budget = parseInt(document.getElementById('budget').value) || 32000;
    document.getElementById('status').textContent = 'assembling...';
    await pokeSig(\{action: 'assemble', budget: budget});
    document.getElementById('status').textContent = 'assembled';
    setTimeout(refresh, 300);
  }

  async function loadConfig() \{
    var cfg = await readFile('config.json');
    if (cfg && cfg.proxy) \{
      document.getElementById('proxy').value = cfg.proxy;
    }
  }

  async function saveConfig() \{
    var cfg = await readFile('config.json') || \{};
    cfg.proxy = document.getElementById('proxy').value;
    await fetch(API + '/over/' + BALL + '/config.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(cfg)
    });
    document.getElementById('status').textContent = 'config saved';
  }

  async function doGrep() \{
    var q = document.getElementById('grep-q').value;
    if (!q) return;
    document.getElementById('status').textContent = 'searching...';
    await pokeSig(\{action: 'grep', query: q});
    document.getElementById('status').textContent = 'search done';
    setTimeout(function() \{
      readFile('grep-results.json').then(renderGrep);
    }, 500);
  }

  var sseCtrl = null;
  var sseRdr = null;

  async function connectSSE() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
    sseCtrl = new AbortController();
    try \{
      var r = await fetch(API + '/keep/' + BALL + '/store.json?mark=json', \{
        headers: \{Accept: 'text/event-stream'},
        signal: sseCtrl.signal
      });
      sseRdr = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await sseRdr.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var evts = buf.split('\\n\\n');
        buf = evts.pop();
        for (var i = 0; i < evts.length; i++) \{
          if (!evts[i].trim()) continue;
          refresh();
          break;
        }
      }
    } catch(e) \{
      if (e.name !== 'AbortError') setTimeout(connectSSE, 2000);
    }
  }

  window.addEventListener('beforeunload', function() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
  });

  refresh();
  loadConfig();
  connectSSE();
  """
  ==
--
