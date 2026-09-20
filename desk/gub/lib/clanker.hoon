::  lib/clanker: the toolkit for a CONTAINED, sandboxed chatbot nexus
::
::  A clanker is a nexus a host mounts under a weir. Its tree:
::
::    main.sig              poke {message, chat} runs a turn;
::                          {action: 'clear', chat} archives + resets;
::                          {action: 'interrupt'} cancels a running turn
::    chats/<chat>.json     one conversation per chat name (default 'main')
::    archive/              cleared conversations, timestamped
::    system.md             the system prompt (editable via the config UI)
::    config.json           {model, max_tokens}
::    tools/                its own tools-nexus instance, seeded from a
::                          bundle; runs are clamped by the host's weir
::
::  The loop (turn -> Anthropic via the metering proxy -> run requested
::  tools -> loop) is identical for every clanker; what varies is the
::  tool schema, the seeds, and the tool bundle. Those are the door's
::  sample. A clanker nexus is then ~30 lines: on-load lays out the tree
::  with +bole, on-file hands main.sig to +serve.
::
::    /<  clanker  /lib/clanker.hoon
::    /&  bundle   /lib/foo-bundle/
::    =/  ck  ~(. clanker:clanker [%foo foo-tools system-seed config-seed])
::    ...
::    ++  on-load  |=(=ball:tarball (spin:loader ball (rows:ck bundle %fall)))
::    ++  on-file  ... [~ %'main.sig'] (serve:ck rail prod)
::
::  (the door's turn arm is +chat-turn so list +turn stays usable)
::
::  Tool results: text rides as a string; %mime results (images, PDFs)
::  become base64 image/document blocks so the model sees the bytes.
::  Server-side tools (web_search) are traced from the response. The
::  stored assistant turn carries `trace` (tool chips) and `parts` (text
::  and chips in content order) for the UI; only role+content go back to
::  the API.
::
/<  nex-tools  /lib/tools.hoon
|%
+$  config
  $:  tag=@tas             ::  log prefix, e.g. %itinerary-agent
      tools=json           ::  Anthropic tool schema array
      system-seed=@t       ::  initial system prompt
      config-seed=json     ::  initial {model, max_tokens}
  ==
::
++  proxy  `path`/apps/'anthropic.anthropic'
::
++  clanker
  |_  cfg=config
  ::  +rows: the on-load spin rows. `prompt-how` is %fall (seed once,
  ::  then user-owned, edited via the config UI) or %over (the prompt is
  ::  product code: re-laid from the seed every respin).
  ::
  ++  rows
    |=  [bundle=(axal (map @ta mime)) prompt-how=?(%fall %over)]
    ^-  (list row:loader)
    =/  prompt=bask:tarball
      [[/ %mime] [/text/markdown (as-octs:mimes:html system-seed.cfg)]]
    =/  prompt-row=row:loader
      ?-  prompt-how
        %fall  [%fall %& [/ %'system.md'] prompt]
        %over  [%over %& [/ %'system.md'] prompt]
      ==
    :~  (manifest:loader 0)
        [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
        [%fall %| /chats empty-dir:loader]
        [%fall %| /archive empty-dir:loader]
        prompt-row
        [%fall %& [/ %'config.json'] [[/ %json] config-seed.cfg]]
        [%over %| /tools (seed-tools:nex-tools bundle)]
    ==
  ::  +serve: the main.sig process. Loops on pokes forever.
  ::
  ++  serve
    |=  [=rail:tarball =prod:fiber:nexus]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ;<  ~  bind:m  (rise-wait:io prod "%{(trip tag.cfg)}/main: failed")
    |-
    ;<  =sage:tarball  bind:m  take-poke:io
    =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
    =/  act=(unit @t)
      ?.  ?=([%o *] jon)  ~
      (bind (~(get by p.jon) 'action') |=(j=json ?>(?=(%s -.j) p.j)))
    =/  chat=@t  =/(c (jstr jon 'chat') ?:(=('' c) 'main' c))
    ?:  ?=([~ %'clear'] act)
      ;<  ~  bind:m  (do-clear rail chat)
      $
    ?:  ?=([~ %'interrupt'] act)  $
    ;<  ~  bind:m  (chat-turn rail jon chat)
    $
  ::  +chat-road: where a conversation lives
  ::
  ++  chat-road
    |=  [=rail:tarball chat=@t]
    ^-  road:tarball
    (nex-road:io rail [%& /chats (crip "{(trip chat)}.json")])
  ::  +chat-turn: one conversation turn. Load history, append the user
  ::  message, run the loop, append the assistant reply, persist.
  ::
  ++  chat-turn
    |=  [=rail:tarball jon=json chat=@t]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ?.  ?=([%o *] jon)  (pure:m ~)
    =/  msg=(unit @t)  (bind (~(get by p.jon) 'message') |=(j=json ?>(?=(%s -.j) p.j)))
    ?~  msg  (pure:m ~)
    =/  road=road:tarball  (chat-road rail chat)
    ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
    =/  history=(list json)
      ?.  ?=([%file *] cur)  ~
      =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
      ?.(?=([%a *] j) ~ p.j)
    =/  existed=?  ?=([%file *] cur)
    =/  user=json  (pairs:enjs:format ~[['role' s+'user'] ['content' s+u.msg]])
    =/  history  (snoc history user)
    ::  persist the user message first — a refresh shows it (and its
    ::  pending state) even if the turn stalls or is interrupted
    ;<  ~  bind:m  (write-chat road existed history)
    ::  stored assistant turns carry trace/parts for the UI; the API
    ::  only sees role + content
    =/  clean=(list json)
      %+  turn  history
      |=  mj=json
      ^-  json
      ?.  ?=([%o *] mj)  mj
      %-  pairs:enjs:format
      %+  murn  `(list @t)`~['role' 'content']
      |=  k=@t
      =/  v=(unit json)  (~(get by p.mj) k)
      ?~(v ~ `[k u.v])
    ;<  sv=view:nexus  bind:m
      (peek:io (nex-road:io rail [%& / %'system.md']) `[/ %mime])
    =/  sys=@t
      ?.  ?=([%file *] sv)  system-seed.cfg
      `@t`q.q:!<(mime (need-vase:tarball sang.sv))
    ;<  cv=view:nexus  bind:m
      (peek:io (nex-road:io rail [%& / %'config.json']) `[/ %json])
    =/  conf=json
      ?.  ?=([%file *] cv)  config-seed.cfg
      (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) config-seed.cfg)
    =/  model=@t  =/(mo=@t (jstr conf 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
    =/  max-toks=@ud  (jnum conf 'max_tokens' (jnum config-seed.cfg 'max_tokens' 1.024))
    ;<  [reply=@t trace=(list json) parts=(list json)]  bind:m
      (run-loop rail clean sys model max-toks)
    =/  asst=json
      %-  pairs:enjs:format
      :~  ['role' s+'assistant']
          ['content' s+reply]
          ['trace' [%a trace]]
          ['parts' [%a parts]]
      ==
    (write-chat road %.y (snoc history asst))
  ::  +write-chat: persist the conversation (make on first write)
  ::
  ++  write-chat
    |=  [road=road:tarball existed=? msgs=(list json)]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    ?:  existed
      (over:io road [[/ %json] [%a msgs]])
    ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] [%a msgs]] ~])
    ~?  >>>  ?=(^ err)  [tag.cfg %write-failed]
    (pure:m ~)
  ::  +do-clear: archive the conversation under /archive/<chat>-<time>.json
  ::  and reset it. A no-op if there's nothing to archive.
  ::
  ++  do-clear
    |=  [=rail:tarball chat=@t]
    =/  m  (fiber:fiber:nexus ,~)
    ^-  form:m
    =/  road=road:tarball  (chat-road rail chat)
    ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
    =/  conv=json
      ?.  ?=([%file *] cur)  [%a ~]
      (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.  ?=([%a ^] conv)  (pure:m ~)
    ;<  now=@da  bind:m  get-time:io
    =/  aname=@ta  (crip "{(trip chat)}-{(scow %da now)}.json")
    =/  arch-road=road:tarball  (nex-road:io rail [%& /archive aname])
    ;<  err=(unit tang)  bind:m  (make-soft:io arch-road |+[[[/ %json] conv] ~])
    ~?  >>>  ?=(^ err)  [tag.cfg %archive-failed]
    ;<  ~  bind:m  (over:io road [[/ %json] [%a ~]])
    (pure:m ~)
  ::  +run-loop: poke the proxy; if the model asks for tools, run them
  ::  and loop; else return the final text plus trace and ordered parts.
  ::
  ++  run-loop
    |=  [=rail:tarball msgs=(list json) sys=@t model=@t max-toks=@ud]
    =/  m  (fiber:fiber:nexus ,[reply=@t trace=(list json) parts=(list json)])
    ^-  form:m
    =|  trace=(list json)
    =|  parts=(list json)
    |-  ^-  form:m
    =/  body=json
      %-  pairs:enjs:format
      :~  ['model' s+model]
          ['max_tokens' (numb:enjs:format max-toks)]
          ['system' s+sys]
          ['tools' tools.cfg]
          ['messages' [%a msgs]]
      ==
    ;<  answered=(unit json)  bind:m  (call-anthropic body)
    ?~  answered  (pure:m ['[interrupted]' (flop trace) parts])
    =/  resp=json  u.answered
    =/  content-arr=(list json)
      ?.  ?=([%o *] resp)  ~
      =/  c  (~(get by p.resp) 'content')
      ?.(?=([~ %a *] c) ~ p.u.c)
    ::  server-side tool blocks (web_search) ran on Anthropic's end —
    ::  trace them so the UI shows the search happened
    =/  server-chip
      |=  b=json
      ^-  (unit json)
      ?.  ?=([%o *] b)  ~
      =/  input=json  (fall (~(get by p.b) 'input') [%o ~])
      =/  q=@t
        ?.  ?=([%o *] input)  ''
        =/  qq  (~(get by p.input) 'query')
        ?:(?=([~ %s *] qq) p.u.qq '')
      `(pairs:enjs:format ~[['tool' s+(jstr b 'name')] ['arg' s+q] ['note' s+'web']])
    =/  server-uses=(list json)
      %+  skim  content-arr
      |=  b=json
      ?&(?=([%o *] b) ?=([~ %s %'server_tool_use'] (~(get by p.b) 'type')))
    =.  trace  (weld (flop (murn server-uses server-chip)) trace)
    ::  ordered parts: text and server-tool chips in content order, so
    ::  the UI can interleave prose with the chips that split it
    =.  parts
      %+  weld  parts
      ^-  (list json)
      %+  murn  content-arr
      |=  b=json
      ^-  (unit json)
      ?.  ?=([%o *] b)  ~
      ?:  ?=([~ %s %'text'] (~(get by p.b) 'type'))
        =/  t  (~(get by p.b) 'text')
        ?.  ?=([~ %s *] t)  ~
        `(pairs:enjs:format ~[['type' s+'text'] ['text' s+p.u.t]])
      ?.  ?=([~ %s %'server_tool_use'] (~(get by p.b) 'type'))  ~
      =/  chip=(unit json)  (server-chip b)
      ?~  chip  ~
      ?.  ?=([%o *] u.chip)  ~
      `[%o (~(put by p.u.chip) 'type' s+'tool')]
    =/  tool-uses=(list json)
      %+  skim  content-arr
      |=  b=json
      ?&(?=([%o *] b) ?=([~ %s %'tool_use'] (~(get by p.b) 'type')))
    ?~  tool-uses
      (pure:m [(extract-text resp) (flop trace) parts])
    ;<  ran=(unit [(list json) (list json)])  bind:m  (run-tools rail tool-uses)
    ?~  ran  (pure:m ['[interrupted]' (flop trace) parts])
    =/  results=(list json)    -.u.ran
    =/  new-trace=(list json)  +.u.ran
    =.  trace  (weld (flop new-trace) trace)
    =.  parts
      %+  weld  parts
      ^-  (list json)
      %+  murn  new-trace
      |=  t=json
      ^-  (unit json)
      ?.  ?=([%o *] t)  ~
      `[%o (~(put by p.t) 'type' s+'tool')]
    =/  asst=json  (pairs:enjs:format ~[['role' s+'assistant'] ['content' [%a content-arr]]])
    =/  usr=json   (pairs:enjs:format ~[['role' s+'user'] ['content' [%a results]]])
    $(msgs (weld msgs ~[asst usr]))
  ::  +call-anthropic: one metered round-trip through the proxy —
  ::  subscribe to the call grub, poke {id, body}, await done, drop.
  ::  ~ on interrupt.
  ::
  ++  call-anthropic
    |=  body=json
    =/  m  (fiber:fiber:nexus ,(unit json))
    ^-  form:m
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  call-id=@t     (scot %uv (end [3 8] eny))
    =/  call-name=@ta  (crip "{(trip call-id)}.json")
    =/  main-road=road:tarball  [%& %& proxy %'main.sig']
    =/  call-road=road:tarball  [%& %& (snoc proxy %calls) call-name]
    ;<  *  bind:m  (keep:io /call call-road ~)
    ;<  ~  bind:m
      %-  poke:io
      :+  main-road  [/ %json]
      (pairs:enjs:format ~[['id' s+call-id] ['body' body]])
    ;<  resp=(unit json)  bind:m  (await-call call-road call-name)
    ;<  ~  bind:m  (drop:io /call call-road)
    (pure:m resp)
  ::
  ++  await-call
    |=  [call-road=road:tarball call-name=@ta]
    =/  m  (fiber:fiber:nexus ,(unit json))
    ^-  form:m
    |-
    ;<  raw=(unit wave:nexus)  bind:m  (take-news-or-interrupt /call)
    ?~  raw  (pure:m ~)
    =/  hit=(unit cass:clay)
      ?~  fil.u.raw  ~
      (~(get by file.u.fil.u.raw) call-name)
    ?~  hit  $
    ;<  =view:nexus  bind:m  (peek-at:io call-road ~ [%ud ud.u.hit])
    ?.  ?=([%file *] view)  $
    =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
    ?.  ?=(%o -.jon)  $
    ?.  ?=([~ %s %'done'] (~(get by p.jon) 'status'))  $
    (pure:m `(fall (~(get by p.jon) 'response') [%o ~]))
  ::  +take-news-or-interrupt: a news wave on `wire`, or ~ when an
  ::  {action:'interrupt'} poke lands on main.sig mid-await. Yields the
  ::  wave so the caller peeks that exact version, not the racy current one.
  ::
  ++  take-news-or-interrupt
    |=  =wire
    =/  m  (fiber:fiber:nexus ,(unit wave:nexus))
    ^-  form:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %news * *]  ?:(=(wire wire.u.in) [%done `wave.u.in] [%skip ~])
        [~ %poke * *]
      =/  jon=json  (fall (mole |.(!<(json q.sage.u.in))) *json)
      ?:  ?&(?=([%o *] jon) ?=([~ %s %'interrupt'] (~(get by p.jon) 'action')))
        [%done ~]
      [%skip ~]
    ==
  ::  +extract-text: the text blocks of a Messages response, concatenated;
  ::  proxy/API errors surfaced as plain text.
  ::
  ++  extract-text
    |=  resp=json
    ^-  @t
    ?.  ?=([%o *] resp)  'no response'
    =/  err=(unit json)  (~(get by p.resp) 'error')
    ?^  err
      ?:  ?=(%s -.u.err)  p.u.err
      (crip "API error: {(trip (en:json:html u.err))}")
    =/  content=(unit json)  (~(get by p.resp) 'content')
    ?.  ?=([~ %a *] content)  'no content in response'
    %-  crip
    %-  zing
    %+  turn  p.u.content
    |=  b=json
    ^-  tape
    ?.  ?=([%o *] b)  ""
    ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
    =/  t=(unit json)  (~(get by p.b) 'text')
    ?:(?=([~ %s *] t) (trip p.u.t) "")
  ::  +run-tools: execute each tool_use; yield the tool_result blocks
  ::  (for the model) and trace entries (for the UI). ~ on interrupt.
  ::
  ++  run-tools
    |=  [=rail:tarball tool-uses=(list json)]
    =/  m  (fiber:fiber:nexus ,(unit [(list json) (list json)]))
    ^-  form:m
    =|  results=(list json)
    =|  trace=(list json)
    |-  ^-  form:m
    ?~  tool-uses  (pure:m `[(flop results) (flop trace)])
    =*  tu  i.tool-uses
    ?.  ?=([%o *] tu)  $(tool-uses t.tool-uses)
    =/  tid=@t   (jstr tu 'id')
    =/  name=@t  (jstr tu 'name')
    =/  input=json  (fall (~(get by p.tu) 'input') [%o ~])
    ;<  outcome=(unit [json @t])  bind:m  (call-tool rail name input)
    ?~  outcome  (pure:m ~)
    =/  out=json  -.u.outcome
    =/  note=@t   +.u.outcome
    =/  result=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tid]
          ['content' out]
      ==
    ::  the chip's label: the first short string argument, if any
    =/  arg=@t  (first-arg input)
    =/  te=json
      (pairs:enjs:format ~[['tool' s+name] ['arg' s+arg] ['note' s+note]])
    $(tool-uses t.tool-uses, results [result results], trace [te trace])
  ::  +first-arg: a representative argument for the UI chip — the first
  ::  string value under 80 bytes, in a stable key order.
  ::
  ++  first-arg
    |=  input=json
    ^-  @t
    ?.  ?=([%o *] input)  ''
    =/  keys=(list @t)  ~['id' 'name' 'path' 'query' 'kind' 'field' 'itinerary']
    |-
    ?~  keys
      ::  none of the usual suspects: any short string
      =/  all=(list [k=@t v=json])  ~(tap by p.input)
      |-
      ?~  all  ''
      ?:  &(?=([%s *] v.i.all) (lth (met 3 p.v.i.all) 80))  p.v.i.all
      $(all t.all)
    =/  v  (~(get by p.input) i.keys)
    ?:  &(?=([~ %s *] v) (lth (met 3 p.u.v) 80))  p.u.v
    $(keys t.keys)
  ::  +call-tool: run one tool through this clanker's own tools instance
  ::  (the calls protocol: poke main.sig, await the run grub, read the
  ::  result, cull). Yields the tool_result content — a string, or a
  ::  content array holding an image/document block when the tool
  ::  returned bytes — plus a short note for the trace. ~ on interrupt.
  ::
  ++  call-tool
    |=  [=rail:tarball name=@t args=json]
    =/  m  (fiber:fiber:nexus ,(unit [json @t]))
    ^-  form:m
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  id=@t         (scot %uv (end [3 8] eny))
    =/  run-name=@ta  `@ta`id
    =/  main-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
    =/  run-road=road:tarball   (nex-road:io rail [%& /tools/runs run-name])
    ;<  *  bind:m  (keep:io /tool run-road ~)
    ;<  ~  bind:m
      %-  poke:io
      :+  main-road  [/ %json]
      %-  pairs:enjs:format
      :~  ['cmd' s+'call']  ['id' s+id]  ['name' s+name]  ['arguments' args]
      ==
    ;<  timed=(unit (unit json))  bind:m  (await-run run-road run-name)
    ;<  ~  bind:m  (drop:io /tool run-road)
    ;<  ~  bind:m
      %-  poke:io
      [main-road [/ %json] (pairs:enjs:format ~[['cmd' s+'cull'] ['id' s+id]])]
    ?~  timed  (pure:m ~)
    =/  res=(unit json)  u.timed
    ?~  res  (pure:m `[s+'(no result)' 'error'])
    ?.  ?=([%o *] u.res)  (pure:m `[s+'(bad result)' 'error'])
    ?:  ?=([~ %s %'error'] (~(get by p.u.res) 'type'))
      =/  msg  (fall (bind (~(get by p.u.res) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'error')
      (pure:m `[s+msg 'error'])
    ?:  ?=([~ %s %'mime'] (~(get by p.u.res) 'type'))
      ::  bytes: images as an image block, PDFs as a document block,
      ::  both base64 — the model sees the picture, not a description
      =/  mt=@t   (jstr u.res 'media_type')
      =/  b64=@t  (jstr u.res 'data')
      =/  kind=@t  ?:(=('application/pdf' mt) 'document' 'image')
      =/  block=json
        %-  pairs:enjs:format
        :~  ['type' s+kind]
            :-  'source'
            %-  pairs:enjs:format
            :~  ['type' s+'base64']
                ['media_type' s+mt]
                ['data' s+b64]
            ==
        ==
      (pure:m `[[%a ~[block]] (crip "{(trip mt)}, {(a-co:co (div (mul 3 (met 3 b64)) 4))} bytes")])
    =/  txt=@t  (fall (bind (~(get by p.u.res) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '')
    (pure:m `[s+txt (crip "{(a-co:co (met 3 txt))} bytes")])
  ::
  ++  await-run
    |=  [run-road=road:tarball run-name=@ta]
    =/  m  (fiber:fiber:nexus ,(unit (unit json)))
    ^-  form:m
    |-
    ;<  raw=(unit wave:nexus)  bind:m  (take-news-or-interrupt /tool)
    ?~  raw  (pure:m ~)
    =/  hit=(unit cass:clay)
      ?~  fil.u.raw  ~
      (~(get by file.u.fil.u.raw) run-name)
    ?~  hit  $
    ;<  =view:nexus  bind:m  (peek-at:io run-road ~ [%ud ud.u.hit])
    ?.  ?=([%file *] view)  $
    =/  st=tool-state:nex-tools  !<(tool-state:nex-tools (need-vase:tarball sang.view))
    ?.  =(%done step.st)  $
    (pure:m `update.st)
  --
::  +mk-tool: one entry of an Anthropic tool schema, all-string params.
::  +mk-tool-typed: the same with a type per param — 'string', 'number',
::  'boolean', or 'string[]' (an array of strings).
::
++  mk-tool
  |=  [nm=@t desc=@t params=(list [p=@t d=@t]) req=(list @t)]
  ^-  json
  (mk-tool-typed nm desc (turn params |=([p=@t d=@t] [p 'string' d])) req)
::
++  mk-tool-typed
  |=  [nm=@t desc=@t params=(list [p=@t t=@t d=@t]) req=(list @t)]
  ^-  json
  %-  pairs:enjs:format
  :~  ['name' s+nm]
      ['description' s+desc]
      :-  'input_schema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          :-  'properties'
          %-  pairs:enjs:format
          %+  turn  params
          |=  [p=@t t=@t d=@t]
          :-  p
          ?.  =('string[]' t)
            (pairs:enjs:format ~[['type' s+t] ['description' s+d]])
          %-  pairs:enjs:format
          :~  ['type' s+'array']
              ['items' (pairs:enjs:format ~[['type' s+'string']])]
              ['description' s+d]
          ==
          ['required' [%a (turn req |=(r=@t s+r))]]
      ==
  ==
::  +web-search: Anthropic's server-side search block
::
++  web-search
  |=  max-uses=@ud
  ^-  json
  %-  pairs:enjs:format
  :~  ['type' s+'web_search_20250305']
      ['name' s+'web_search']
      ['max_uses' (numb:enjs:format max-uses)]
  ==
::
++  jstr
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v=(unit json)  (~(get by p.jon) key)
  ?:(?=([~ %s *] v) p.u.v '')
::
++  jnum
  |=  [jon=json key=@t def=@ud]
  ^-  @ud
  ?.  ?=([%o *] jon)  def
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  def
  (fall (mole |.((ni:dejs:format u.v))) def)
--
