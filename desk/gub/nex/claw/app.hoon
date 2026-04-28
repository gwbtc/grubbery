::  claw nexus: self-building AI agent
::
/<  nex-server    /lib/nex/server.hoon
/<  nex-tools     /lib/nex/tools.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        =/  default-config=json
          %-  pairs:enjs:format
          :~  ['api-key' s+'']
              ['model' s+'claude-sonnet-4-20250514']
          ==
        =/  default-conv=json  [%a ~]
        =/  code-dir=ball:tarball  [`[~ `[/ %code] ~] ~]
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%over %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            ::  /context: conversations and memory
            [%fall %| /context [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /context/conversations [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/context/conversations %'main.json'] %.n [~ [/ %json] !>(default-conv)]]
            ::  /code: claw's own build scope
            [%fall %| /code [~ ~] [~ ~] code-dir]
            [%fall %| /code/nex [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /code/lib [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /code/mar [~ ~] [~ ~] empty-dir:loader]
            ::  /tools/code: tool code nexus (compiled tool handlers)
            [%fall %| /tools/code [~ ~] [~ ~] code-dir]
            [%fall %| /tools/code/lib [~ ~] [~ ~] empty-dir:loader]
            ::  /tools/proc: tool execution grubs (runtime)
            [%fall %| /tools/proc [~ ~] [~ ~] empty-dir:loader]
            ::  /children: spawned nexus instances
            [%fall %| /children [~ ~] [~ ~] empty-dir:loader]
            ::  ui
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>(chat-page)]]
            [%fall %& [/ui %'http.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /ui/requests [~ ~] [~ ~] empty-dir:loader]
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
          ::  /main.sig: config pokes
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%claw main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage  $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (fall (bind (~(get by p.jon) 'action') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?+    act  $
              %'set-key'
            =/  key=@t  (fall (bind (~(get by p.jon) 'api-key') |=(=json ?>(?=(%s -.json) p.json))) '')
            ;<  config=json  bind:m  read-config
            =/  updated=json
              [%o (~(put by ?>(?=(%o -.config) p.config)) 'api-key' s+key)]
            ;<  ~  bind:m  (write-config updated)
            ~&  >  "%claw: api key set"
            $
          ::
              %'set-model'
            =/  model=@t  (fall (bind (~(get by p.jon) 'model') |=(=json ?>(?=(%s -.json) p.json))) '')
            ;<  config=json  bind:m  read-config
            =/  updated=json
              [%o (~(put by ?>(?=(%o -.config) p.config)) 'model' s+model)]
            ;<  ~  bind:m  (write-config updated)
            ~&  >  ["%claw: model set to" model]
            $
          ::
              %'prompt'
            =/  content=@t  (fall (bind (~(get by p.jon) 'content') |=(=json ?>(?=(%s -.json) p.json))) '')
            =/  conv-key=@t  (fall (bind (~(get by p.jon) 'conversation') |=(=json ?>(?=(%s -.json) p.json))) 'main')
            ~&  >  ["%claw: prompt received" content]
            ?:  =('' content)  $
            ::  read config
            ;<  config=json  bind:m  read-config
            =/  api-key=@t  (get-str config 'api-key')
            =/  model=@t  (get-str config 'model')
            ~&  >  ["%claw: config" 'key-len' (met 3 api-key) 'model' model]
            ?:  =('' api-key)
              ;<  ~  bind:m  (write-conv conv-key (snoc updated [%msg 'assistant' 'Error: no API key set. Open config to add one.']))
              $
            ::  read conversation, append user message
            ;<  =convo  bind:m  (read-conv conv-key)
            =/  updated=^convo  (snoc convo [%msg 'user' content])
            ;<  ~  bind:m  (write-conv conv-key updated)
            ::  discover tools
            ;<  tools=(map @t tool:nex-tools)  bind:m  get-tools
            ::  enter agent turn loop
            ;<  final=^convo  bind:m  (agent-turn conv-key api-key model updated tools)
            $
          ::
              %'clear'
            =/  conv-key=@t  (fall (bind (~(get by p.jon) 'conversation') |=(=json ?>(?=(%s -.json) p.json))) 'main')
            ;<  ~  bind:m  (write-conv conv-key ~)
            ~&  >  "%claw: conversation cleared"
            $
          ==
        ==
          ::  /tools/proc/*: tool execution processes
          ::
          [[%tools %proc ~] @]
        ;<  ~  bind:m  (rise-tool prod)
        ;<  st=tool-state:nex-tools  bind:m
          (get-state-as:io ,tool-state:nex-tools)
        ?:  =(%done step.st)  (pure:m ~)
        ::  look up tool handler from tools/code bins
        ;<  got=(each tool:nex-tools tang)  bind:m  (await-tool st)
        ?:  ?=(%| -.got)
          =/  err-msg=@t  (render-tang:build p.got)
          =/  result-data=json
            (pairs:enjs:format ~[['type' s+'error'] ['message' s+err-msg]])
          (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data]))
        =/  tl=tool:nex-tools  p.got
        ;<  result=tool-result:nex-tools  bind:m  handler.tl
        =/  result-json=json
          ?-  -.result
            %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
            %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
          ==
        (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-json]))
          ::  /ui/http.sig: bind /groundwire/claw/ and dispatch requests
          ::
          [[%ui ~] %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%claw http: failed")
        =/  prefix=path  /groundwire/claw
        ;<  ~  bind:m  (bind-http:nex-server [~ prefix])
        (http-dispatch:nex-server %claw)
          ::  /ui/requests/*: individual HTTP request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%claw request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path
          %+  skip  (slag (lent /groundwire/claw) site)
          |=(s=@ta =('' s))
        ::  GET / → chat page
        ?~  suffix
          ;<  ~  bind:m
            (serve-page-html eyre-id (cord-to-road:tarball '../../../page.html'))
          (pure:m ~)
        ?+    suffix
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
        ::  POST /prompt → send prompt
        ::
            [%prompt ~]
          ?.  ?=(%'POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'POST only')])
            (pure:m ~)
          ?~  body.request.req  (pure:m ~)
          =/  body-json=(unit json)  (de:json:html q.u.body.request.req)
          ?~  body-json  (pure:m ~)
          ;<  ~  bind:m
            (send-dart:io [%node /prompt (cord-to-road:tarball '../../../main.sig') %poke [[/ %json] !>(u.body-json)]])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[202 ~] `(as-octs:mimes:html '"accepted"')])
          (pure:m ~)
        ::  GET /conversation → read conversation
        ::
            [%conversation ~]
          =/  conv-key=@t  (fall (bind (find-arg args 'key') same) 'main')
          ;<  =convo  bind:m  (read-conv-from-http conv-key)
          =/  body=@t  (en:json:html (convo-to-json convo))
          ;<  ~  bind:m
            %+  send-simple:srv  eyre-id
            :_  `(as-octs:mimes:html body)
            [200 ~[['content-type' 'application/json'] ['cache-control' 'no-cache']]]
          (pure:m ~)
        ::  GET /stream → SSE for conversation updates
        ::
            [%stream ~]
          =/  conv-key=@t  (fall (bind (find-arg args 'key') same) 'main')
          (handle-stream eyre-id req conv-key)
        ==
          ::  /page.html: rendered chat page
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw page: failed")
        ;<  ~  bind:m  (replace:io !>(chat-page))
        stay:m
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under claw.'
            ~
          'AI agent nexus. Chat with LLMs, build sub-nexuses.'
        ==
          %|
        ?+  rail.p.mana  'File under claw.'
          [~ %'config.json']     'LLM config: api-key, model.'
          [~ %'main.sig']        'Poke handler for config and prompts.'
          [~ %'page.html']       'Chat interface.'
          [~ %'http.sig']        'HTTP request handler.'
        ==
      ==
    --
::
::  types and helpers
::
|%
::  conversation entry: either a message or a summary placeholder
::
+$  entry
  $%  [%msg role=@t content=@t]
      [%sum id=@ud covers=(list @ud) content=@t]
      [%tool-use id=@t name=@t input=json]
      [%tool-result tool-use-id=@t content=@t]
  ==
::  a conversation is an ordered list of entries
::  messages are never deleted, only compacted behind summaries
::
+$  convo  (list entry)
::
++  srv  ~(. res:nex-server [%| 1 %& ~ %'http.sig'])
::
++  get-str
  |=  [jon=json key=@t]
  ^-  @t
  =/  val=(unit json)  ?:(?=(%o -.jon) (~(get by p.jon) key) ~)
  ?~  val  ''
  ?.  ?=(%s -.u.val)  ''
  p.u.val
::
++  find-arg
  |=  [args=quay:eyre key=@t]
  ^-  (unit @t)
  =/  match  (skim args |=([k=@t *] =(k key)))
  ?~  match  ~
  `+.i.match
::
++  read-config
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './config.json')
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *json)
  (pure:m (fall (mole |.(!<(json q.sage.p.seen))) *json))
::
++  write-config
  |=  updated=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (cord-to-road:tarball './config.json') [[/ %json] !>(updated)])
::
::  +strip-hoon: remove .hoon suffix from filename
::
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
::
::  +get-tools: return built-in tools merged with dynamic tools from tools/code/lib
::
++  get-tools
  =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
  ^-  form:m
  ::  start with built-in tools
  =/  result=(map @t tool:nex-tools)
    (malt ~[[name:echo-tool echo-tool]])
  ::  merge dynamic tools from tools/code/lib
  ;<  src-seen=seen:nexus  bind:m
    (peek:io [%& %| /tools/code/lib] ~)
  ?.  ?=([%& %ball *] src-seen)
    (pure:m result)
  ?~  fil.ball.p.src-seen
    (pure:m result)
  =/  names=(list @ta)
    %+  turn  ~(tap by contents.u.fil.ball.p.src-seen)
    |=([name=@ta *] (strip-hoon name))
  |-
  ?~  names  (pure:m result)
  =/  name=@ta  i.names
  ;<  res=built:nexus  bind:m
    (get-code-full:io [%& %& /tools/code/lib name])
  ?.  ?=(%vase -.res)  $(names t.names)
  =/  got=(each tool:nex-tools tang)
    (mule |.(!<(tool:nex-tools vase.res)))
  ?.  ?=(%& -.got)  $(names t.names)
  $(names t.names, result (~(put by result) name:p.got p.got))
::
::  +await-tool: look up a compiled tool handler by name
::
++  await-tool
  |=  st=tool-state:nex-tools
  =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
  ^-  form:m
  =/  file-name=@ta
    (crip (turn (trip tool.st) |=(c=@t ?:(=(c '_') '-' c))))
  ;<  res=built:nexus  bind:m
    (get-code-full:io [%& %& /tools/code/lib file-name])
  ?.  ?=(%vase -.res)
    (pure:m [%| ?:(?=(%tang -.res) tang.res ~[leaf+"not a vase"])])
  =/  got=(each tool:nex-tools tang)
    (mule |.(!<(tool:nex-tools vase.res)))
  (pure:m got)
::
::  +rise-tool: handle tool process crash
::
++  rise-tool
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%rise -.prod)  (pure:m ~)
  %-  (slog leaf+"%claw tool crashed" tang.prod)
  ;<  st=tool-state:nex-tools  bind:m
    (get-state-as:io ,tool-state:nex-tools)
  =/  err-msg=@t  (render-tang:build tang.prod)
  =/  result-data=json
    (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "crash\0a{(trip err-msg)}")]])
  (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data]))
::
::  +tools-to-json: convert tool map to Anthropic tools array
::
++  tools-to-json
  |=  tools=(map @t tool:nex-tools)
  ^-  json
  :-  %a
  %+  turn  ~(val by tools)
  |=  tl=tool:nex-tools
  =/  props=(list [@t json])
    %+  turn  ~(tap by parameters.tl)
    |=  [k=@t def=parameter-def:nex-tools]
    [k (pairs:enjs:format ~[['type' s+(crip (trip type.def))] ['description' s+description.def]])]
  %-  pairs:enjs:format
  :~  ['name' s+name.tl]
      ['description' s+description.tl]
      :-  'input_schema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          ['properties' [%o (~(gas by *(map @t json)) props)]]
          ['required' [%a (turn required.tl |=(r=@t s+r))]]
      ==
  ==
::
::  +agent-turn: the main agentic loop
::
::  sends prompt to API, handles tool_use responses, loops until end_turn
::
++  agent-turn
  |=  [conv-key=@t api-key=@t model=@t =convo tools=(map @t tool:nex-tools)]
  =/  m  (fiber:fiber:nexus ,^convo)
  ^-  form:m
  =/  base-sys=@t  'You are a helpful AI assistant running as a nexus on an Urbit ship. You have tools available.'
  |-
  =/  [ctx=@t api-msgs-list=(list json)]  (assemble convo)
  =/  sys-prompt=@t
    ?:  =('' ctx)  base-sys
    %-  crip
    ;:  weld  (trip base-sys)  "\0a\0a"  (trip ctx)  ==
  ::  build API request
  =/  api-msgs=json  [%a api-msgs-list]
  =/  body-pairs=(list [@t json])
    :~  ['model' s+model]
        ['max_tokens' (numb:enjs:format 4.096)]
        ['system' s+sys-prompt]
        ['messages' api-msgs]
    ==
  =?  body-pairs  !=(~ tools)
    (snoc body-pairs ['tools' (tools-to-json tools)])
  =/  body-cord=@t  (en:json:html (pairs:enjs:format body-pairs))
  =/  hed=(list [key=@t value=@t])
    :~  ['content-type' 'application/json']
        ['x-api-key' api-key]
        ['anthropic-version' '2023-06-01']
    ==
  ~&  >  ["%claw: sending to" model]
  ;<  ~  bind:m
    (send-request:io [%'POST' 'https://api.anthropic.com/v1/messages' hed `(as-octs:mimes:html body-cord)])
  ;<  resp=client-response:iris  bind:m  take-http
  ::  parse full response
  =/  parsed=(unit api-response)  (parse-api-response resp)
  ?~  parsed
    ~&  >>>  "%claw: failed to parse response"
    =/  err-convo=^convo  (snoc convo [%msg 'assistant' 'Error: failed to parse API response'])
    ;<  ~  bind:m  (write-conv conv-key err-convo)
    (pure:m err-convo)
  ~&  >  ["%claw: stop_reason=" stop-reason.u.parsed]
  ::  append all content blocks as entries
  =/  updated=^convo
    %+  roll  content-blocks.u.parsed
    |=  [=content-block acc=_convo]
    ?-  -.content-block
        %text      (snoc acc [%msg 'assistant' text.content-block])
        %tool-use  (snoc acc [%tool-use id.content-block name.content-block input.content-block])
    ==
  ::  if end_turn or no tool calls, we're done
  =/  calls=(list content-block)
    (skim content-blocks.u.parsed |=(=content-block ?=(%tool-use -.content-block)))
  ?~  calls
    ;<  ~  bind:m  (write-conv conv-key updated)
    (pure:m updated)
  ::  execute tools, append results
  ~&  >  ["%claw: executing" (lent calls) "tool calls"]
  ;<  results=(list [@t @t])  bind:m  (run-tool-calls calls)
  =/  with-results=^convo
    %+  roll  results
    |=  [[id=@t result=@t] acc=_updated]
    (snoc acc [%tool-result id result])
  ;<  ~  bind:m  (write-conv conv-key with-results)
  $(convo with-results)
::
::  +run-tool-calls: execute tool_use blocks via tools/proc grubs
::
++  run-tool-calls
  |=  calls=(list content-block)
  =/  m  (fiber:fiber:nexus ,(list [@t @t]))
  ^-  form:m
  =/  results=(list [@t @t])  ~
  |-
  ?~  calls  (pure:m (flop results))
  =/  call=content-block  i.calls
  ?>  ?=(%tool-use -.call)
  =/  tool-args=(map @t json)
    ?.  ?=(%o -.input.call)  ~
    p.input.call
  =/  ts=tool-state:nex-tools
    [name.call tool-args %start ~ ~]
  =/  tid=@ta  id.call
  =/  tool-road=road:tarball  [%| 1 %& /tools/proc tid]
  ~&  >  ["%claw: running tool" name.call id.call]
  ::  create tool grub
  ;<  ~  bind:m
    (make:io tool-road |+[%.n [[/ %tool-state] !>(ts)] ~])
  ::  subscribe and wait for %done
  ;<  *  bind:m  (keep:io /tool-wait/[tid] tool-road ~)
  ;<  result-text=@t  bind:m  (await-tool-result tid)
  $(calls t.calls, results [[id.call result-text] results])
::
::  +await-tool-result: watch tool grub until %done
::
++  await-tool-result
  |=  tid=@ta
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  |-
  ;<  upd=view:nexus  bind:m  (take-news:io /tool-wait/[tid])
  ?.  ?=(%file -.upd)  $
  =/  st=tool-state:nex-tools  !<(tool-state:nex-tools q.sage.upd)
  ?.  =(%done step.st)  $
  ?~  update.st  (pure:m 'tool returned no result')
  ?>  ?=(%o -.u.update.st)
  =/  result-type=(unit json)  (~(get by p.u.update.st) 'type')
  ?:  ?=([~ %s %'error'] result-type)
    =/  err=@t  (fall (bind (~(get by p.u.update.st) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown error')
    (pure:m (crip "ERROR: {(trip err)}"))
  =/  txt=@t  (fall (bind (~(get by p.u.update.st) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '')
  (pure:m txt)
::
::  API response types
::
+$  content-block
  $%  [%text text=@t]
      [%tool-use id=@t name=@t input=json]
  ==
+$  api-response
  $:  stop-reason=@t
      content-blocks=(list content-block)
  ==
::
::  +parse-api-response: parse Anthropic Messages API response
::
++  parse-api-response
  |=  =client-response:iris
  ^-  (unit api-response)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  =/  data=json  p.parsed
  ?.  ?=(%o -.data)  ~
  ::  check for error
  =/  typ=(unit json)  (~(get by p.data) 'type')
  ?:  ?=([~ %s %'error'] typ)
    =/  err=(unit json)  (~(get by p.data) 'error')
    =/  err-msg=@t
      ?~  err  'unknown error'
      ?:  ?=(%o -.u.err)
        (fall (bind (~(get by p.u.err) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown error')
      'unknown error'
    ~&  >>>  ["%claw: API error" err-msg]
    `[%'end_turn' [%text (crip "API error: {(trip err-msg)}")]~]
  ::  extract stop_reason
  =/  stop=@t
    (fall (bind (~(get by p.data) 'stop_reason') |=(j=json ?>(?=(%s -.j) p.j))) 'end_turn')
  ::  extract content blocks
  =/  content-arr=(unit json)  (~(get by p.data) 'content')
  ?~  content-arr  ~
  ?.  ?=(%a -.u.content-arr)  ~
  =/  blocks=(list content-block)
    %+  murn  p.u.content-arr
    |=  j=json
    ^-  (unit content-block)
    ?.  ?=(%o -.j)  ~
    =/  block-type=(unit json)  (~(get by p.j) 'type')
    ?:  ?=([~ %s %'text'] block-type)
      =/  text=(unit json)  (~(get by p.j) 'text')
      ?~  text  ~
      ?.  ?=(%s -.u.text)  ~
      `[%text p.u.text]
    ?:  ?=([~ %s %'tool_use'] block-type)
      =/  id=(unit json)  (~(get by p.j) 'id')
      =/  name=(unit json)  (~(get by p.j) 'name')
      =/  input=(unit json)  (~(get by p.j) 'input')
      ?~  id  ~
      ?~  name  ~
      ?.  ?=(%s -.u.id)  ~
      ?.  ?=(%s -.u.name)  ~
      `[%tool-use p.u.id p.u.name (fall input [%o ~])]
    ~
  `[stop blocks]
::
++  read-conv
  |=  key=@t
  =/  m  (fiber:fiber:nexus ,convo)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball (crip "./context/conversations/{(trip key)}.json"))
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m ~)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  (pure:m (parse-convo jon))
::
++  read-conv-from-http
  |=  key=@t
  =/  m  (fiber:fiber:nexus ,convo)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball (crip "../../../context/conversations/{(trip key)}.json"))
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m ~)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  (pure:m (parse-convo jon))
::
++  write-conv
  |=  [key=@t =convo]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball (crip "./context/conversations/{(trip key)}.json"))
  =/  jon=json  (convo-to-json convo)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/ %json] !>(jon)])
  (make:io road |+[%.n [[/ %json] !>(jon)] ~])
::
++  parse-convo
  |=  jon=json
  ^-  convo
  ?.  ?=(%a -.jon)  ~
  %+  murn  p.jon
  |=  =json
  ^-  (unit entry)
  ?.  ?=(%o -.json)  ~
  =/  type=(unit @t)  (bind (~(get by p.json) 'type') |=(j=^json ?>(?=(%s -.j) p.j)))
  ?:  ?=([~ %'sum'] type)
    =/  id=@ud  (fall (bind (~(get by p.json) 'id') |=(j=^json ?>(?=(%n -.j) (fall (rush p.j dem) 0)))) 0)
    =/  covers=(list @ud)
      =/  cv  (~(get by p.json) 'covers')
      ?~  cv  ~
      ?.  ?=(%a -.u.cv)  ~
      (murn p.u.cv |=(j=^json ?.(?=(%n -.j) ~ (rush p.j dem))))
    =/  content=@t  (fall (bind (~(get by p.json) 'content') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    `[%sum id covers content]
  ?:  ?=([~ %'tool_use'] type)
    =/  id=@t  (fall (bind (~(get by p.json) 'id') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  name=@t  (fall (bind (~(get by p.json) 'name') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  input=^json  (fall (~(get by p.json) 'input') [%o ~])
    `[%tool-use id name input]
  ?:  ?=([~ %'tool_result'] type)
    =/  tid=@t  (fall (bind (~(get by p.json) 'tool_use_id') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    =/  content=@t  (fall (bind (~(get by p.json) 'content') |=(j=^json ?>(?=(%s -.j) p.j))) '')
    `[%tool-result tid content]
  ::  default: message
  =/  role=(unit @t)  (bind (~(get by p.json) 'role') |=(j=^json ?>(?=(%s -.j) p.j)))
  =/  content=(unit @t)  (bind (~(get by p.json) 'content') |=(j=^json ?>(?=(%s -.j) p.j)))
  ?~  role  ~
  ?~  content  ~
  `[%msg u.role u.content]
::
++  convo-to-json
  |=  =convo
  ^-  json
  :-  %a
  %+  turn  convo
  |=  =entry
  ?-  -.entry
      %msg
    (pairs:enjs:format ~[['role' s+role.entry] ['content' s+content.entry]])
      %sum
    %-  pairs:enjs:format
    :~  ['type' s+'sum']
        ['id' (numb:enjs:format id.entry)]
        ['covers' [%a (turn covers.entry |=(n=@ud (numb:enjs:format n)))]]
        ['content' s+content.entry]
    ==
      %tool-use
    %-  pairs:enjs:format
    :~  ['type' s+'tool_use']
        ['id' s+id.entry]
        ['name' s+name.entry]
        ['input' input.entry]
    ==
      %tool-result
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+tool-use-id.entry]
        ['content' s+content.entry]
    ==
  ==
::
::  +assemble: build API messages JSON from conversation
::
::  returns context string (from summaries) and list of API message objects.
::  handles %msg, %sum, %tool-use, and %tool-result entries.
::  consecutive tool-use entries get merged into one assistant message.
::  consecutive tool-result entries get merged into one user message.
::
++  assemble
  |=  =convo
  ^-  [ctx=@t msgs=(list json)]
  =/  ctx=tape  ~
  =/  msgs=(list json)  ~
  =/  pending-tools=(list json)  ~
  =/  pending-results=(list json)  ~
  |-  ^-  [ctx=@t msgs=(list json)]
  ::  flush helpers
  =/  flush-tools=_msgs
    ?~  pending-tools  msgs
    :_  msgs
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['content' [%a (flop pending-tools)]]]
  =/  flush-results=_msgs
    ?~  pending-results  msgs
    :_  msgs
    %-  pairs:enjs:format
    ~[['role' s+'user'] ['content' [%a (flop pending-results)]]]
  ?~  convo
    =.  msgs  flush-tools
    =.  msgs  flush-results
    [(crip ctx) (flop msgs)]
  ?-  -.i.convo
      %msg
    =.  msgs  flush-tools
    =.  msgs  flush-results
    %=  $
      convo  t.convo
      pending-tools  ~
      pending-results  ~
      msgs  :_  msgs
             (pairs:enjs:format ~[['role' s+role.i.convo] ['content' s+content.i.convo]])
    ==
      %sum
    =/  line=tape
      ?:  =('' content.i.convo)
        "[Earlier conversation summarized but not yet realized]"
      (trip content.i.convo)
    $(convo t.convo, ctx ?~(ctx line (weld (weld ctx "\0a\0a") line)))
      %tool-use
    =.  msgs  flush-results
    =.  pending-results  ~
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_use']
          ['id' s+id.i.convo]
          ['name' s+name.i.convo]
          ['input' input.i.convo]
      ==
    $(convo t.convo, pending-tools [block pending-tools])
      %tool-result
    =.  msgs  flush-tools
    =.  pending-tools  ~
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tool-use-id.i.convo]
          ['content' s+content.i.convo]
      ==
    $(convo t.convo, pending-results [block pending-results])
  ==
::
++  take-http
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done client-response.sign.u.in]
  ==
::
++  handle-stream
  |=  [eyre-id=@ta req=inbound-request:eyre conv-key=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
    (pure:m ~)
  ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
  =/  conv-road=road:tarball
    (cord-to-road:tarball (crip "../../../context/conversations/"))
  ;<  *  bind:m  (keep:io /conv-stream conv-road ~)
  ;<  =bowl:nexus  bind:m  get-bowl:io
  ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /conv-stream)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
    ;<  =bowl:nexus  bind:m  get-bowl:io
    ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
    $
      %news
    ::  send full conversation as SSE event
    ;<  =convo  bind:m  (read-conv-from-http conv-key)
    =/  data=@t  (en:json:html (convo-to-json convo))
    =/  =sse-event:http-utils  [~ `'conversation' [data]~]
    =/  encoded=octs  (sse-encode:http-utils ~[sse-event])
    ;<  ~  bind:m  (send-data:srv eyre-id `encoded)
    $
  ==
::
++  serve-page-html
  |=  [eyre-id=@ta road=road:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io road `%mime)
  ?.  ?=([%& %file *] seen)
    (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Page not found')])
  =/  =mime  !<(mime q.sage.p.seen)
  (send-simple:srv eyre-id (mime-response:http-utils mime))
::
++  chat-page
  ^-  manx
  ;html
    ;head
      ;title: claw
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;div
            ;h1: claw
            ;div.f3.mono.s-2: AI agent nexus
          ==
          ;button#config-btn.hdr-btn: config
        ==
        ;div#cfg-backdrop
          ;div#cfg-modal
            ;div#cfg-header
              ;span: Config
              ;div
                ;button#cfg-save.hdr-btn: save
                ;button#cfg-close.hdr-btn: close
              ==
            ==
            ;label.cfg-label: API Key
            ;input#cfg-key(type "password", placeholder "sk-ant-...");
            ;label.cfg-label: Model
            ;input#cfg-model(type "text", placeholder "claude-sonnet-4-20250514");
            ;div#cfg-status;
          ==
        ==
        ;div#messages;
        ;form#prompt-form(onsubmit "sendPrompt(event)")
          ;div.input-row
            ;input#input(type "text", placeholder "Say something...", autocomplete "off");
            ;button(type "submit"): Send
          ==
        ==
      ==
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; height: 100vh; }
  #app \{ display: flex; flex-direction: column; height: 100vh; max-width: 700px; margin: 0 auto; padding: 16px; }
  #header \{ padding: 12px 0; border-bottom: 1px solid #333; margin-bottom: 12px; flex-shrink: 0; }
  #header h1 \{ font-size: 20px; font-weight: 700; }
  #messages \{ flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding: 8px 0; }
  .msg \{ padding: 8px 12px; border-radius: 8px; max-width: 85%; white-space: pre-wrap; word-wrap: break-word; font-size: 14px; line-height: 1.5; }
  .msg.user \{ background: #2563eb; color: white; align-self: flex-end; }
  .msg.assistant \{ background: #222; border: 1px solid #333; align-self: flex-start; }
  .msg.system \{ background: #1a1a2e; border: 1px solid #333; align-self: center; font-size: 12px; color: #888; }
  .msg.pending \{ opacity: 0.5; }
  #prompt-form \{ flex-shrink: 0; padding: 12px 0; border-top: 1px solid #333; }
  .input-row \{ display: flex; gap: 8px; }
  #input \{ flex: 1; padding: 10px 14px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 14px; outline: none; }
  #input:focus \{ border-color: #2563eb; }
  button \{ padding: 10px 20px; border-radius: 8px; border: none; background: #2563eb; color: white; font-size: 14px; cursor: pointer; }
  button:hover \{ background: #1d4ed8; }
  .f3 \{ color: #888; }
  .mono \{ font-family: monospace; }
  .s-2 \{ font-size: 12px; }
  #header \{ display: flex; justify-content: space-between; align-items: flex-start; }
  .hdr-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid #444; background: none; color: #888; cursor: pointer; }
  .hdr-btn:hover \{ color: #eee; border-color: #666; }
  #cfg-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #cfg-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #cfg-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }
  #cfg-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #cfg-header span \{ font-size: 14px; font-weight: 600; }
  #cfg-header div \{ display: flex; gap: 6px; }
  .cfg-label \{ display: block; font-size: 12px; color: #888; margin: 12px 0 4px; }
  #cfg-key, #cfg-model \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }
  #cfg-key:focus, #cfg-model:focus \{ border-color: #2563eb; }
  #cfg-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  """
::
++  script-text
  ^-  tape
  """
  var API = '/grubbery/api';
  var BALL = 'claw.claw_app';

  function renderMessages(entries) \{
    var el = document.getElementById('messages');
    el.innerHTML = '';
    for (var i = 0; i < entries.length; i++) \{
      var e = entries[i];
      var div = document.createElement('div');
      if (e.type === 'sum') \{
        div.className = 'msg system';
        div.textContent = e.content || '[summary pending]';
      } else if (e.type === 'tool_use') \{
        div.className = 'msg system';
        div.textContent = '[tool] ' + e.name;
      } else if (e.type === 'tool_result') \{
        div.className = 'msg system';
        div.textContent = '> ' + (e.content || '').slice(0, 200);
      } else \{
        if (e.role === 'system') continue;
        div.className = 'msg ' + e.role;
        div.textContent = e.content;
      }
      el.appendChild(div);
    }
    el.scrollTop = el.scrollHeight;
  }

  function sendPrompt(e) \{
    e.preventDefault();
    var input = document.getElementById('input');
    var text = input.value.trim();
    if (!text) return;
    input.value = '';
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'prompt', content: text, conversation: 'main'})
    });
  }

  async function connectSSE() \{
    try \{
      var r = await fetch(API + '/keep/' + BALL + '/context/conversations/main.json?mark=json', \{
        headers: \{Accept: 'text/event-stream'}
      });
      var reader = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await reader.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var evts = buf.split('\\n\\n');
        buf = evts.pop();
        for (var i = 0; i < evts.length; i++) \{
          if (!evts[i].trim()) continue;
          var data = '';
          var lines = evts[i].split('\\n');
          for (var j = 0; j < lines.length; j++) \{
            if (lines[j].indexOf('data: ') === 0) data += lines[j].slice(6);
          }
          if (!data) continue;
          try \{
            var msgs = JSON.parse(data);
            renderMessages(msgs);
          } catch(e) \{}
        }
      }
    } catch(e) \{
      console.error('SSE error', e);
      setTimeout(connectSSE, 2000);
    }
  }

  // Load initial conversation
  fetch(API + '/file/' + BALL + '/context/conversations/main.json?mark=json')
    .then(function(r) \{ return r.json() })
    .then(renderMessages)
    .catch(function() \{});

  connectSSE();

  // Config modal
  var cfgBack = document.getElementById('cfg-backdrop');
  var cfgKey = document.getElementById('cfg-key');
  var cfgModel = document.getElementById('cfg-model');
  var cfgStatus = document.getElementById('cfg-status');

  document.getElementById('config-btn').onclick = function() \{
    cfgStatus.textContent = '';
    fetch(API + '/file/' + BALL + '/config.json?mark=json')
      .then(function(r) \{ return r.json() })
      .then(function(j) \{
        cfgKey.value = j['api-key'] || '';
        cfgModel.value = j['model'] || '';
      }).catch(function() \{});
    cfgBack.classList.add('open');
  };

  document.getElementById('cfg-close').onclick = function() \{
    cfgBack.classList.remove('open');
  };

  cfgBack.onclick = function(e) \{
    if (e.target === cfgBack) cfgBack.classList.remove('open');
  };

  document.getElementById('cfg-save').onclick = async function() \{
    var cfg = \{'api-key': cfgKey.value, 'model': cfgModel.value};
    var r = await fetch(API + '/over/' + BALL + '/config.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(cfg)
    });
    if (r.ok) \{
      cfgStatus.textContent = 'Saved';
      setTimeout(function() \{ cfgBack.classList.remove('open'); }, 600);
    } else \{
      cfgStatus.textContent = 'Save failed';
      cfgStatus.style.color = '#f87171';
    }
  };
  """
::
::  built-in tools
::
++  echo-tool
  ^-  tool:nex-tools
  |%
  ++  name  'echo'
  ++  description  'Echoes back the provided message. Use this to test tool calling.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['message' [%string 'The message to echo back']]])
  ++  required  ~['message']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  msg=(unit @t)
      (bind (~(get by args.st) 'message') |=(j=json ?>(?=(%s -.j) p.j)))
    ?~  msg
      (pure:m [%error 'Missing required argument: message'])
    (pure:m [%text u.msg])
  --
--
