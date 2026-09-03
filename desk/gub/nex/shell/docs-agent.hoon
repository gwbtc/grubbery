::  docs-agent: the grubbery docs chatbot as a CONTAINED, sandboxed nexus.
::  Its weir.json IS the sandbox — the WHOLE agent (turn handler and tools)
::  runs bounded by it: it may only READ /docs, the root /code nexus, and
::  the raw grubbery desk source, and POKE the metered provider proxy.
::  Conversation history lives in chats/ as grubs — durable and inspectable.
::  Bespoke for now; the reusable agent library will precipitate from here.
/<  nex-tools  /lib/tools.hoon
/&  bundle     /lib/docs-tools/
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  the sandbox is NOT self-declared here — it is the weir shell sets
      ::  on this nexus in its mount bole (kernel-enforced). This on-load
      ::  only lays out the agent's own tree.
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          ::  one conversation, one grub. Clearing archives it under /archive.
          [%fall %& [/ %'chat.json'] [[/ %json] [%a ~]]]
          [%fall %| /archive empty-dir:loader]
          ::  the system prompt + model config are materialized grubs — the
          ::  agent's context lives in the namespace, editable (via the chat
          ::  config modal), not compiled in. %fall = seed once, then user-owned.
          [%fall %& [/ %'system.md'] [[/ %mime] [/text/markdown (as-octs:mimes:html system-seed)]]]
          [%fall %& [/ %'config.json'] [[/ %json] config-seed]]
          ::  tools: the agent's own tools nexus instance, seeded with
          ::  the docs bundle (search_docs, read_doc). Nested here, it is
          ::  clamped by the weir shell set on this agent — so the tools can
          ::  only reach what the agent can. Invoked via the calls protocol.
          [%over %| /tools (seed-tools:nex-tools bundle)]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: poke {message} to run a turn, {action:'clear'} to
          ::  archive + reset the conversation. ({action:'interrupt'} is
          ::  caught mid-turn by the awaits; an idle one is a no-op.)
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%docs-agent/main: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        =/  act=(unit @t)
          ?.  ?=([%o *] jon)  ~
          (bind (~(get by p.jon) 'action') |=(j=json ?>(?=(%s -.j) p.j)))
        ?:  ?=([~ %'clear'] act)
          ;<  ~  bind:m  (do-clear rail)
          $
        ?:  ?=([~ %'interrupt'] act)  $
        ;<  ~  bind:m  (turn rail jon)
        $
      ==
    --
|%
++  proxy      `path`/apps/'anthropic.anthropic'
::  +turn: one conversation turn. Load history, append the user message,
::  run the loop, append the assistant reply (with its tool trace), persist.
++  turn
  |=  [=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m ~)
  =/  msg=(unit @t)  (bind (~(get by p.jon) 'message') |=(j=json ?>(?=(%s -.j) p.j)))
  ?~  msg  (pure:m ~)
  =/  chat-road=road:tarball  (nex-road:io rail [%& / %'chat.json'])
  ;<  cur=view:nexus  bind:m  (peek:io chat-road `[/ %json])
  =/  history=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  =/  existed=?  ?=([%file *] cur)
  =/  user=json  (pairs:enjs:format ~[['role' s+'user'] ['content' s+u.msg]])
  =/  history  (snoc history user)
  ::  persist the user message immediately — a refresh always shows it and
  ::  its pending state, even if the turn stalls or is interrupted.
  ;<  ~  bind:m  (write-chat chat-road existed history)
  ::  the stored assistant turns carry a `trace` field for the UI; strip
  ::  every message to {role, content} before the API sees it.
  =/  clean=(list json)
    %+  turn:type  history
    |=  mj=json
    ^-  json
    ?.  ?=([%o *] mj)  mj
    %-  pairs:enjs:format
    %+  murn  `(list @t)`~['role' 'content']
    |=  k=@t
    =/  v=(unit json)  (~(get by p.mj) k)
    ?~(v ~ `[k u.v])
  ::  read the system prompt + model config from their grubs (seed fallbacks)
  ;<  sv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& / %'system.md']) `[/ %mime])
  =/  sys=@t
    ?.  ?=([%file *] sv)  system-seed
    `@t`q.q:!<(mime (need-vase:tarball sang.sv))
  ;<  cv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& / %'config.json']) `[/ %json])
  =/  cfg=json
    ?.  ?=([%file *] cv)  config-seed
    (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) config-seed)
  =/  model=@t  =/(mo=@t (jstr cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max-toks=@ud  (jnum cfg 'max_tokens' 1.024)
  ;<  [reply=@t trace=(list json)]  bind:m  (run-loop rail clean sys model max-toks)
  =/  asst=json
    (pairs:enjs:format ~[['role' s+'assistant'] ['content' s+reply] ['trace' [%a trace]]])
  ::  the grub now exists (we wrote the user message above) — overwrite it
  ::  with the completed turn.
  (write-chat chat-road %.y (snoc history asst))
::  +write-chat: persist the conversation grub (make on first write, else
::  overwrite). Incremental — called for the user message and again for the
::  completed turn, so a stall never loses what happened.
++  write-chat
  |=  [chat-road=road:tarball existed=? msgs=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  existed
    (over:io chat-road [[/ %json] [%a msgs]])
  ;<  err=(unit tang)  bind:m  (make-soft:io chat-road |+[[[/ %json] [%a msgs]] ~])
  ~?  >>>  ?=(^ err)  %docs-agent-write-failed
  (pure:m ~)
::  +do-clear: archive the current conversation under /archive/<time>.json,
::  then reset chat.json to empty. A no-op if there's nothing to archive.
++  do-clear
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  chat-road=road:tarball  (nex-road:io rail [%& / %'chat.json'])
  ;<  cur=view:nexus  bind:m  (peek:io chat-road `[/ %json])
  =/  conv=json
    ?.  ?=([%file *] cur)  [%a ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
  ?.  ?=([%a ^] conv)  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  =/  aname=@ta  (crip "{(scow %da now)}.json")
  =/  arch-road=road:tarball  (nex-road:io rail [%& /archive aname])
  ;<  err=(unit tang)  bind:m  (make-soft:io arch-road |+[[[/ %json] conv] ~])
  ~?  >>>  ?=(^ err)  %docs-agent-archive-failed
  ;<  ~  bind:m  (over:io chat-road [[/ %json] [%a ~]])
  (pure:m ~)
::  +system-seed: the initial system prompt, materialized into the
::  system.md grub on load. The agent reads the grub, not this arm.
++  system-seed
  ^-  @t
  '''
  You are the Grubbery assistant, embedded in the Grubbery handbook. You can
  search and read both the handbook docs (search_docs, read_doc) AND the
  actual Grubbery source tree — the root /code nexus (search_code, read_code).
  Search first, read the relevant docs or source, then answer from what they
  actually say. Use the handbook for concepts and the source for exact
  implementation detail. If something isn't covered, say so plainly rather
  than guessing. Be concrete and brief, and cite doc or file paths.
  '''
::  +config-seed: default model config, seeded into config.json on load.
++  config-seed
  ^-  json
  %-  pairs:enjs:format
  ~[['model' s+'claude-sonnet-4-6'] ['max_tokens' (numb:enjs:format 1.024)]]
::  +jnum: a json object's numeric field as @ud, or a default.
++  jnum
  |=  [jon=json key=@t def=@ud]
  ^-  @ud
  ?.  ?=([%o *] jon)  def
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  def
  (fall (mole |.((ni:dejs:format u.v))) def)
::  +docs-tools: the Anthropic tool schema for the two scoped capabilities.
++  docs-tools
  ^-  json
  =/  mk-tool
    |=  [nm=@t desc=@t params=(list [p=@t d=@t]) req=(list @t)]
    ^-  json
    %-  pairs:enjs:format
    :~  ['name' s+nm]
        ['description' s+desc]
        :-  'input_schema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            :-  'properties'
            %-  pairs:enjs:format
            %+  turn:type  params
            |=  [p=@t d=@t]
            [p (pairs:enjs:format ~[['type' s+'string'] ['description' s+d]])]
            ['required' [%a (turn:type req |=(r=@t s+r))]]
        ==
    ==
  :-  %a
  :~  %:  mk-tool  'search_docs'
        'Full-text search the Grubbery handbook docs. Returns matching doc filenames and snippet lines.'
        ~[['query' 'the search terms']]  ~['query']
      ==
      %:  mk-tool  'read_doc'
        'Read one Grubbery handbook doc in full by its filename (as returned by search_docs).'
        ~[['path' 'the doc filename, e.g. intro.md']]  ~['path']
      ==
      %:  mk-tool  'search_code'
        'Search the Grubbery SOURCE TREE (the root /code nexus — the actual .hoon implementation) for a string. Returns matching lines with file paths + line numbers.'
        ~[['pattern' 'text to search for'] ['path' 'optional path glob to filter files, e.g. /lib/* or *nexus*']]
        ~['pattern']
      ==
      %:  mk-tool  'read_code'
        'Read a source file from the root /code nexus (the Grubbery source tree). Path like /lib/nexus.hoon or /nex/shell/docs-agent.hoon.'
        ~[['path' 'file path under /code, e.g. /lib/tarball.hoon']]  ~['path']
      ==
      %:  mk-tool  'search_desk'
        'Search the raw Grubbery Clay desk — the full source desk, including runtime/kernel and non-/code files (marks, man pages, sys.kelvin). Returns matching lines with file paths + line numbers.'
        ~[['pattern' 'text to search for'] ['path' 'optional path glob, e.g. /mar/* or *kelvin*']]
        ~['pattern']
      ==
      %:  mk-tool  'read_desk'
        'Read a file from the raw Grubbery Clay desk (source desk — includes files not in /code, like marks, man pages, sys.kelvin). Path like /mar/md.hoon.'
        ~[['path' 'file path within the desk, e.g. /mar/md.hoon']]  ~['path']
      ==
  ==
::  +run-loop: the agent loop. Each turn pokes the metering proxy; if the
::  model asks for tools, run them (scoped to the docs) and loop; else return
::  the final text plus a trace of every tool call.
++  run-loop
  |=  [=rail:tarball msgs=(list json) sys=@t model=@t max-toks=@ud]
  =/  m  (fiber:fiber:nexus ,[reply=@t trace=(list json)])
  ^-  form:m
  =|  trace=(list json)
  |-  ^-  form:m
  =/  body=json
    %-  pairs:enjs:format
    :~  ['model' s+model]
        ['max_tokens' (numb:enjs:format max-toks)]
        ['system' s+sys]
        ['tools' docs-tools]
        ['messages' [%a msgs]]
    ==
  ;<  answered=(unit json)  bind:m  (call-anthropic body)
  ?~  answered  (pure:m ['[interrupted]' (flop trace)])
  =/  resp=json  u.answered
  =/  content-arr=(list json)
    ?.  ?=([%o *] resp)  ~
    =/  c  (~(get by p.resp) 'content')
    ?.(?=([~ %a *] c) ~ p.u.c)
  =/  tool-uses=(list json)
    %+  skim  content-arr
    |=  b=json
    ?&(?=([%o *] b) ?=([~ %s %'tool_use'] (~(get by p.b) 'type')))
  ?~  tool-uses
    (pure:m [(extract-text resp) (flop trace)])
  ;<  ran=(unit [(list json) (list json)])  bind:m  (run-tools rail tool-uses)
  ?~  ran  (pure:m ['[interrupted]' (flop trace)])
  =/  results=(list json)    -.u.ran
  =/  new-trace=(list json)  +.u.ran
  =.  trace  (weld (flop new-trace) trace)
  =/  asst=json  (pairs:enjs:format ~[['role' s+'assistant'] ['content' [%a content-arr]]])
  =/  usr=json   (pairs:enjs:format ~[['role' s+'user'] ['content' [%a results]]])
  $(msgs (weld msgs ~[asst usr]))
::  +call-anthropic: one metered round-trip. Subscribe to the call grub,
::  poke the proxy's main.sig with {id, body}, await done, drop.
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
::  +await-call: loop on news for our call grub until status is done.
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
::  +take-news-or-interrupt: wait for a news wave on `wire` OR an interrupt
::  poke ({action:'interrupt'}) to our main.sig. Yields the WAVE on news (so
::  the caller can peek that exact version, not the racy current one), or ~
::  on interrupt — so any await can be manually cancelled mid-turn.
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
::  +extract-text: concatenate the text blocks of a Messages response;
::  surface proxy/API errors as plain text.
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
  %+  turn:type  p.u.content
  |=  b=json
  ^-  tape
  ?.  ?=([%o *] b)  ""
  ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
  =/  t=(unit json)  (~(get by p.b) 'text')
  ?:(?=([~ %s *] t) (trip p.u.t) "")
::  +run-tools: execute each requested tool_use, returning tool_result
::  blocks (for the model) and trace entries (for the UI).
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
  ;<  outcome=(unit [@t @t])  bind:m  (call-tool rail name input)
  ?~  outcome  (pure:m ~)
  =/  out=@t   -.u.outcome
  =/  note=@t  +.u.outcome
  =/  result=json
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+tid]
        ['content' s+out]
    ==
  =/  arg=@t
    ?.  ?=([%o *] input)  ''
    =/  q  (~(get by p.input) 'query')
    ?:  ?=([~ %s *] q)  p.u.q
    =/  pa  (~(get by p.input) 'path')
    ?:(?=([~ %s *] pa) p.u.pa '')
  =/  te=json
    (pairs:enjs:format ~[['tool' s+name] ['arg' s+arg] ['note' s+note]])
  $(tool-uses t.tool-uses, results [result results], trace [te trace])
::  +call-tool: invoke a tool through the agent's own tools nexus instance
::  (the calls protocol): poke its main.sig, await the run grub, read the
::  result, cull. The tool runs sandboxed under this agent's weir.
++  call-tool
  |=  [=rail:tarball name=@t args=json]
  =/  m  (fiber:fiber:nexus ,(unit [@t @t]))
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
  ?~  res  (pure:m `['(no result)' 'error'])
  ?.  ?=([%o *] u.res)  (pure:m `['(bad result)' 'error'])
  ?:  ?=([~ %s %'error'] (~(get by p.u.res) 'type'))
    =/  msg  (fall (bind (~(get by p.u.res) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'error')
    (pure:m `[msg 'error'])
  =/  txt=@t  (fall (bind (~(get by p.u.res) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '')
  (pure:m `[txt (crip "{(a-co:co (met 3 txt))} bytes")])
::  +await-run: loop on news for a tool run grub until step is done, then
::  yield its result json.
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
::  +jstr: a json object's string field, or '' if absent/wrong-type.
++  jstr
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v=(unit json)  (~(get by p.jon) key)
  ?:(?=([~ %s *] v) p.u.v '')
--
