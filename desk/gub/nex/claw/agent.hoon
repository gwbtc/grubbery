::  claw nexus: self-building AI agent
::
/<  nex-tools     /lib/nex/tools.hoon
/<  iso-8601      /lib/iso-8601.hoon
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
          :~  ['model' s+'claude-sonnet-4-20250514']
              ['context_window' (numb:enjs:format 200.000)]
              ['message_cap' (numb:enjs:format 20.000)]
          ==
        =/  default-prompt=wain
          :~  'You are an AI assistant running as a nexus process on an Urbit ship,'
              'inside the grubbery build system.'
              ''
              '# What you are'
              ''
              'You are a **nexus** — a live fiber process with its own filesystem (a tarball).'
              'Your code runs as an event loop: you receive pokes, read/write files, subscribe'
              'to changes, and spawn child processes. Everything is persistent — files you'
              'write survive across conversations.'
              ''
              '# Your filesystem'
              ''
              '  ./config.json              — config (model, api-proxy, context_window, message_cap)'
              '  ./main.sig                 — your event loop (pokes arrive here)'
              '  ./page.html                — your web UI'
              '  ./context/'
              '    prompts/                 — system prompt files (concatenated alphabetically)'
              '    conversations/           — conversation logs (main.json, etc.)'
              '    memories/                — persistent notes you write to remember things'
              '    docs/                    — reference documentation (grep these for details)'
              '  ./content/                 — your working content'
              '    code/                    — your build scope (compiled by the grubbery build system)'
              '      nex/                   — nexus source code'
              '      lib/                   — libraries'
              '        tools/               — dynamic tool definitions (.hoon files)'
              '      mar/                   — mark definitions'
              '  ./tools/                   — active tool processes (managed by the system)'
              '  ./children/                — spawned child nexuses'
              '  ./result.json              — write here to return results to a parent task'
              ''
              '# Tools overview'
              ''
              '## File operations'
              '- browse: list directory contents'
              '- read: read a file (supports offset/limit for line ranges)'
              '- write: write a file'
              '- edit: exact string replacement in a file'
              '- delete: delete a file'
              '- mkdir: create a directory'
              '- grep: search file contents by pattern (supports path/name/mark globs)'
              '- glob: find files by path/name/mark patterns'
              ''
              '## Conversation history'
              'Your conversation has a sliding window — older messages drop out of context.'
              'Use these tools to search and recall beyond the window:'
              '- grep_history: search the FULL conversation (all messages ever, not just'
              '  the current window) by substring. Returns matching lines with message indices.'
              '- recall_messages: insert a [ref:N-M] marker that pulls old messages back'
              '  into the current context at assembly time.'
              '- summarize: send a message range to the LLM for targeted summarization.'
              '  Always specify what kind of summary (process, decisions, technical, action-items).'
              ''
              '## Code and building'
              '- check_bin: check if code compiled. Use after every write to code.'
              '  path is the directory, name is the file stem (e.g. path="/content/code/nex/foo" name="app")'
              '- check_bang: check if a nexus directory has errors'
              '- read_manual: look up documentation for any path in the ball'
              '- read_font: find which code namespace governs a path'
              ''
              '## Nexus management'
              '- create_nexus: create a child nexus from code'
              '- delete_nexus: remove a child nexus'
              '- spawn_task: delegate work to a child that runs independently'
              '- finish: write result.json to return results to parent'
              ''
              '## Sandbox (weir)'
              '- read_weir: see sandbox permissions for a directory'
              '- add_weir / del_weir / clear_weir: manage sandbox rules'
              ''
              '# Building nexuses'
              ''
              'A nexus is Hoon code that produces a `nexus:nexus` core with three arms:'
              ''
              '## on-load: initialize the filesystem'
              '  |=  [=sand:nexus =gain:nexus =ball:tarball]'
              '  ^-  [sand:nexus gain:nexus ball:tarball]'
              ''
              'Called when the nexus is created or its code changes. Use the loader to'
              'set up files and directories. Key loader operations:'
              '  %fall — create file/dir only if absent (keeps existing data on reload)'
              '  %over — overwrite file/dir unconditionally (resets on reload)'
              '  ver-row:loader — version tracking for schema migrations'
              ''
              '## on-file: define fiber processes'
              '  |=  [=rail:tarball =mark]'
              '  ^-  spool:fiber:nexus'
              ''
              'Pattern-matches on [path name] to spawn fiber processes. Each process is'
              'an event loop using the fiber monad (;<  result  bind:m  action).'
              ''
              'Common pattern for main.sig (poke handler):'
              '  [~ %main.sig]'
              '  ;<  ~  bind:m  (rise-wait:io prod "failed")'
              '  |-'
              '  ;<  =sage:tarball  bind:m  take-poke:io'
              '  :: handle the poke...'
              '  $  :: loop back for next poke'
              ''
              'Common pattern for reactive files (re-render on changes):'
              '  [[%ui ~] %page.html]'
              '  ;<  init=view:nexus  bind:m  (keep:io /wire some-road ~)'
              '  :: render initial state'
              '  |-'
              '  ;<  upd=view:nexus  bind:m  (take-news:io /wire)'
              '  :: re-render on change'
              '  $'
              ''
              '## on-manu: documentation'
              '  |=  =mana:nexus'
              '  ^-  @t'
              ''
              'Returns documentation strings for paths and files. Queried by read_manual.'
              ''
              '# Key fiberio operations'
              ''
              'All fiber IO uses the pattern: ;<  result  bind:m  (action:io args)'
              ''
              '  peek:io road mark          — read a file or directory'
              '  peek-exists:io road        — check if something exists'
              '  make:io road make-spec     — create a file or directory'
              '  over:io road sage          — overwrite file content'
              '  cull:io road               — delete a file or directory'
              '  poke:io road sage          — send data to another process'
              '  take-poke:io               — wait for incoming poke'
              '  keep:io wire road mark     — subscribe to changes'
              '  take-news:io wire          — wait for subscription update'
              '  drop:io wire road          — unsubscribe'
              '  replace:io vase            — overwrite own file content'
              '  get-state-as:io ,type      — read own content, cast to type'
              '  copy-grub:io src dst       — copy a file'
              '  copy-fold:io src dst       — copy a directory'
              '  sleep:io time              — wait'
              '  get-our:io                 — get ship name'
              '  get-time:io                — get current time'
              '  get-here:io                — get own rail (path + name)'
              '  rise-wait:io prod msg      — crash handler (put at top of process)'
              ''
              '# Build system'
              ''
              'Code lives in ./content/code/. The grubbery build system compiles it.'
              ''
              'To write and test code:'
              '1. Write source to ./content/code/nex/my-thing/app.hoon (or lib/, mar/)'
              '2. check_bin path="/content/code/nex/my-thing" name="app"'
              '3. If it fails, read the error, fix, write again, check again'
              '4. Once it compiles, create_nexus to instantiate it'
              ''
              'Dynamic tools: write to ./content/code/lib/tools/my-tool.hoon'
              'Must produce a tool:nex-tools core (name, description, parameters, required, handler).'
              'Available immediately after check_bin passes.'
              ''
              '# Reference docs'
              ''
              'For detailed API references, patterns, and examples, grep or read files in'
              './context/docs/. Use: grep pattern="fiberio" path="./context/docs/*"'
              ''
              '# Guidelines'
              ''
              '- Stay within scope. Respond to conversation directly. Only reach for tools'
              '  and code when the task actually calls for it.'
              '- When building code, always check_bin after writing. Fix errors iteratively.'
              '- Use read_manual to understand unfamiliar parts of the system.'
              '- Write memories to ./context/memories/ to persist important information.'
              '- Use grep_history to search beyond your context window.'
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
            [%fall %& [/context/conversations %'main.json'] %.n [~ [/ %json] !>(default-conv)]]
            [%fall %| /context/prompts [~ ~] [~ ~] empty-dir:loader]
            [%fall %& [/context/prompts %'main.txt'] %.n [~ [/ %txt] !>(default-prompt)]]
            [%fall %| /context/memories [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /context/docs [~ ~] [~ ~] empty-dir:loader]
            ::  /content: nexus content
            [%fall %| /content [~ ~] [~ ~] empty-dir:loader]
            ::  /content/code: claw's own build scope
            [%fall %| /content/code [~ ~] [~ ~] code-dir]
            [%fall %| /content/code/nex [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /content/code/lib [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /content/code/lib/tools [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /content/code/mar [~ ~] [~ ~] empty-dir:loader]
            ::  /tools: tool execution
            [%fall %| /tools [~ ~] [~ ~] empty-dir:loader]
            ::  /children: spawned child nexuses
            [%fall %| /children [~ ~] [~ ~] empty-dir:loader]
            ::  ui
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>((chat-page "" ~['main']))]]
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
        ;<  =main-event  bind:m  take-main-event
        ~&  >>  ["%claw main.sig: got event" -.main-event]
        ?-    -.main-event
            %news
          ::  deferred tool result arrived via subscription
          =/  tid=@ta  ?>(?=(^ wire.main-event) i.wire.main-event)
          ?.  ?=(%file -.view.main-event)  $
          =/  tst=tool-state:nex-tools  !<(tool-state:nex-tools q.sage.view.main-event)
          ?.  =(%done step.tst)  $
          =/  tool-road=road:tarball  [%| 0 %& /tools tid]
          ;<  ~  bind:m  (drop:io /tool-done/[tid] tool-road)
          =/  result-text=@t  (extract-tool-result tst)
          ~&  >  ["%claw: deferred result for" tid]
          =/  conv-key=@t  'main'
          ;<  config=json  bind:m  read-config
          =/  model=@t  (get-str config 'model')
          =/  proxy=@t
            =/  p  (get-str config 'api-proxy')
            ?:(=('' p) '../../apis/anthropic.sig' p)
          =/  ctx-window=@ud  (get-num config 'context_window' 200.000)
          =/  msg-cap=@ud  (get-num config 'message_cap' 20.000)
          ;<  =convo  bind:m  (read-conv conv-key)
          =/  updated=^convo
            (snoc convo [%msg 'user' (crip "[spawn_task result]: {(trip result-text)}")])
          ;<  ~  bind:m  (write-conv conv-key updated)
          ;<  tools=(map @t tool:nex-tools)  bind:m  get-tools
          ;<  final=^convo  bind:m  (agent-turn conv-key model proxy ctx-window msg-cap updated tools)
          $
            %poke
          ~&  >>  ["%claw poke from:" from.main-event]
          =/  =sage:tarball  sage.main-event
          ~&  >>  ["%claw poke: mark" name.p.sage]
        ?+    name.p.sage  $
            %json
          =/  jon=json  !<(json q.sage)
          ~&  >>  ["%claw poke json:" jon]
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (fall (bind (~(get by p.jon) 'action') |=(=json ?>(?=(%s -.json) p.json))) '')
          ~&  >>  ["%claw poke action:" act]
          ?+    act  $
              %'set-model'
            =/  model=@t  (fall (bind (~(get by p.jon) 'model') |=(=json ?>(?=(%s -.json) p.json))) '')
            ;<  config=json  bind:m  read-config
            =/  updated=json
              [%o (~(put by ?>(?=(%o -.config) p.config)) 'model' s+model)]
            ;<  ~  bind:m  (write-config updated)
            ~&  >  ["%claw: model set to" model]
            $
          ::
              %'message'
            =/  content=@t  (fall (bind (~(get by p.jon) 'content') |=(=json ?>(?=(%s -.json) p.json))) '')
            =/  conv-key=@t  (fall (bind (~(get by p.jon) 'conversation') |=(=json ?>(?=(%s -.json) p.json))) 'main')
            ~&  >>  ["%claw message: conv" conv-key "content" content]
            ?:  =('' content)  $
            ;<  finished=?  bind:m  (peek-exists:io (cord-to-road:tarball './result.json'))
            ?:  finished
              ~&  >  "%claw: nexus finished, ignoring message"
              $
            ;<  config=json  bind:m  read-config
            =/  model=@t  (get-str config 'model')
            =/  proxy=@t
              =/  p  (get-str config 'api-proxy')
              ?:(=('' p) '../../apis/anthropic.sig' p)
            =/  ctx-window=@ud  (get-num config 'context_window' 200.000)
            =/  msg-cap=@ud  (get-num config 'message_cap' 20.000)
            ::  read conversation, append user message
            ;<  =convo  bind:m  (read-conv conv-key)
            =/  updated=^convo  (snoc convo [%msg 'user' content])
            ;<  ~  bind:m  (write-conv conv-key updated)
            ::  discover tools
            ;<  tools=(map @t tool:nex-tools)  bind:m  get-tools
            ::  enter agent turn loop
            ;<  final=^convo  bind:m  (agent-turn conv-key model proxy ctx-window msg-cap updated tools)
            $
          ::
              %'clear'
            =/  conv-key=@t  (fall (bind (~(get by p.jon) 'conversation') |=(=json ?>(?=(%s -.json) p.json))) 'main')
            ;<  ~  bind:m  (write-conv conv-key ~)
            ~&  >  "%claw: conversation cleared"
            $
          ==
        ==
        ==
          ::  /tools/*: tool execution
          ::
          [[%tools ~] @]
        ;<  ~  bind:m  (rise-tool prod)
        ;<  st=tool-state:nex-tools  bind:m
          (get-state-as:io ,tool-state:nex-tools)
        ?:  =(%done step.st)  (pure:m ~)
        ::  tool execution
        =/  tl=(unit tool:nex-tools)  (~(get by builtins) tool.st)
        ?~  tl
          =/  result-data=json
            (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "Unknown tool: {(trip tool.st)}")]])
          (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data]))
        ;<  result=tool-result:nex-tools  bind:m  handler.u.tl
        =/  result-json=json
          ?-  -.result
            %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
            %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
          ==
        (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-json]))
          ::  /page.html: rendered chat page
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw page: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  ball-id=tape
          %-  zing
          %+  join  "/"
          ^-  (list tape)
          (turn path.here trip)
        ;<  convs=view:nexus  bind:m
          (keep:io /convs (cord-to-road:tarball './context/conversations/') ~)
        =/  conv-names=(list @ta)  (read-conv-names convs)
        ;<  ~  bind:m  (replace:io !>((chat-page ball-id conv-names)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /convs)
        =/  conv-names=(list @ta)  (read-conv-names upd)
        ;<  ~  bind:m  (replace:io !>((chat-page ball-id conv-names)))
        $
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
          [~ %'config.json']     'LLM config: model selection.'
          [~ %'main.sig']        'Poke handler for config and messages.'
          [~ %'page.html']       'Chat interface.'
        ==
      ==
    --
::
::  types and helpers
::
|%
::  conversation entry
::
+$  entry
  $%  [%msg role=@t content=@t]
      [%tool-use id=@t name=@t input=json]
      [%tool-result tool-use-id=@t content=@t]
  ==
::  a conversation is an ordered list of entries
::
+$  convo  (list entry)
::
::
++  get-str
  |=  [jon=json key=@t]
  ^-  @t
  ?~  jon  ''
  ?.  ?=(%o -.jon)  ''
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  ''
  ?.  ?=(%s -.u.val)  ''
  p.u.val
::
++  get-num
  |=  [jon=json key=@t default=@ud]
  ^-  @ud
  ?.  ?=(%o -.jon)  default
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  default
  ?.  ?=(%n -.u.val)  default
  (fall (rush p.u.val dem) default)
::
+$  main-event
  $%  [%poke =from:fiber:nexus =sage:tarball]
      [%news =wire =view:nexus]
  ==
::
++  take-main-event
  =/  m  (fiber:fiber:nexus ,main-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    [%done %poke [from sage]:u.in]
      [~ %news * *]
    [%done %news [wire view]:u.in]
  ==
::
::
++  read-prompts
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  prompts-road=road:tarball  (cord-to-road:tarball './context/prompts/')
  ;<  =seen:nexus  bind:m  (peek:io prompts-road ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m '')
  ?~  fil.ball.p.seen
    (pure:m '')
  =/  names=(list @ta)
    (sort ~(tap in ~(key by contents.u.fil.ball.p.seen)) aor)
  =/  parts=(list @t)  ~
  |-
  ?~  names
    ?~  parts  (pure:m '')
    =/  ordered=(list @t)  (flop parts)
    =/  out=tape
      %-  zing
      %+  join  "\0a\0a"
      ^-  (list tape)
      (turn ordered trip)
    (pure:m (crip out))
  =/  name=@ta  i.names
  =/  file-road=road:tarball  (cord-to-road:tarball (crip "./context/prompts/{(trip name)}"))
  ;<  file-seen=seen:nexus  bind:m  (peek:io file-road ~)
  ?.  ?=([%& %file *] file-seen)
    $(names t.names)
  ;<  =mime  bind:m  (sage-to-mime:io sage.p.file-seen)
  =/  txt=@t  (crip (trip q.q.mime))
  ?:  =('' txt)
    $(names t.names)
  $(names t.names, parts [txt parts])
::
++  read-memories
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  mem-road=road:tarball  (cord-to-road:tarball './context/memories/')
  ;<  =seen:nexus  bind:m  (peek:io mem-road ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m '')
  ?~  fil.ball.p.seen
    (pure:m '')
  =/  names=(list @ta)
    (sort ~(tap in ~(key by contents.u.fil.ball.p.seen)) aor)
  =/  parts=(list @t)  ~
  |-
  ?~  names
    ?~  parts  (pure:m '')
    =/  ordered=(list @t)  (flop parts)
    =/  out=tape
      %-  zing
      %+  join  "\0a\0a"
      ^-  (list tape)
      (turn ordered trip)
    (pure:m (crip out))
  =/  name=@ta  i.names
  =/  file-road=road:tarball  (cord-to-road:tarball (crip "./context/memories/{(trip name)}"))
  ;<  file-seen=seen:nexus  bind:m  (peek:io file-road ~)
  ?.  ?=([%& %file *] file-seen)
    $(names t.names)
  ;<  =mime  bind:m  (sage-to-mime:io sage.p.file-seen)
  =/  txt=@t  (crip (trip q.q.mime))
  ?:  =('' txt)
    $(names t.names)
  $(names t.names, parts [txt parts])
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
::  built-in tools map
::
++  builtins
  ^-  (map @t tool:nex-tools)
  %-  malt
  :~  [name:browse-tool browse-tool]
      [name:read-tool read-tool]
      [name:write-tool write-tool]
      [name:edit-tool edit-tool]
      [name:delete-tool delete-tool]
      [name:mkdir-tool mkdir-tool]
      [name:create-nexus-tool create-nexus-tool]
      [name:delete-nexus-tool delete-nexus-tool]
      [name:check-bin-tool check-bin-tool]
      [name:check-bang-tool check-bang-tool]
      [name:read-manual-tool read-manual-tool]
      [name:read-font-tool read-font-tool]
      [name:read-weir-tool read-weir-tool]
      [name:add-weir-tool add-weir-tool]
      [name:del-weir-tool del-weir-tool]
      [name:clear-weir-tool clear-weir-tool]
      [name:finish-tool finish-tool]
      [name:spawn-task-tool spawn-task-tool]
      [name:grep-files-tool grep-files-tool]
      [name:glob-files-tool glob-files-tool]
      [name:grep-history-tool grep-history-tool]
      [name:recall-messages-tool recall-messages-tool]
      [name:summarize-tool summarize-tool]
  ==
::
::  +get-tools: return built-in tools merged with dynamic tools from content/code/lib/tools
::
++  get-tools
  =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
  ^-  form:m
  ::  start with built-in tools
  =/  result=(map @t tool:nex-tools)  builtins
  ::  merge dynamic tools from content/code/lib/tools
  ;<  src-seen=seen:nexus  bind:m
    (peek:io [%& %| /content/code/lib/tools] ~)
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
    (get-code-full:io [%& %& /content/code/lib/tools name])
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
    (get-code-full:io [%& %& /content/code/lib/tools file-name])
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
  =/  new-vase=(each vase tang)
    (mule |.(!>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data])))
  ?:  ?=(%| -.new-vase)
    %-  (slog leaf+"%claw: crash handler failed to build vase" ~)
    =/  fallback=tool-state:nex-tools  ['' ~ %done ~ `(pairs:enjs:format ~[['type' s+'error'] ['message' s+'tool crashed and recovery failed']])]
    (replace:io !>(fallback))
  (replace:io p.new-vase)
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
  |=  [conv-key=@t model=@t proxy=@t ctx-window=@ud msg-cap=@ud =convo tools=(map @t tool:nex-tools)]
  =/  m  (fiber:fiber:nexus ,^convo)
  ^-  form:m
  ~&  >>  "%claw agent-turn: start"
  ;<  base-sys=@t  bind:m  read-prompts
  ~&  >>  "%claw agent-turn: got prompts"
  ;<  memories=@t  bind:m  read-memories
  ~&  >>  "%claw agent-turn: got memories"
  ;<  now=@da  bind:m  get-time:io
  ~&  >>  ["%claw agent-turn: got time" now]
  ;<  our=ship  bind:m  get-our:io
  ~&  >>  "%claw agent-turn: got our"
  ;<  here=rail:tarball  bind:m  get-here:io
  ~&  >>  "%claw agent-turn: got here"
  =/  runtime-ctx=@t
    %-  crip
    ;:  weld
      "Current time (UTC): {(en:datetime-local:iso-8601 now)}\0a"
      "Ship: {(scow %p our)}\0a"
      "Location: {(spud (snoc path.here name.here))}"
    ==
  |-
  =/  sys-prompt=@t
    %-  crip
    ;:  weld
      (trip base-sys)
      "\0a\0a"
      (trip runtime-ctx)
      ?:  =('' memories)  ""
      :(weld "\0a\0a## Memories\0a\0a" (trip memories))
    ==
  ::  subtract prompt + tool defs from window budget
  =/  prompt-tokens=@ud  (max 1 (div (met 3 sys-prompt) 4))
  =/  tools-tokens=@ud
    ?:  =(~ tools)  0
    (max 1 (div (met 3 (en:json:html (tools-to-json tools))) 4))
  =/  effective-window=@ud
    ?:  (gth (add prompt-tokens tools-tokens) ctx-window)  1.000
    (sub ctx-window (add prompt-tokens tools-tokens))
  =/  api-msgs-list=(list json)  (assemble convo effective-window msg-cap)
  ::  build API request body
  =/  api-msgs=json  [%a api-msgs-list]
  =/  body-pairs=(list [@t json])
    :~  ['model' s+model]
        ['max_tokens' (numb:enjs:format 4.096)]
        ['system' s+sys-prompt]
        ['messages' api-msgs]
    ==
  =?  body-pairs  !=(~ tools)
    (snoc body-pairs ['tools' (tools-to-json tools)])
  =/  payload=json  (pairs:enjs:format body-pairs)
  ~&  >  ["%claw: sending to" model]
  ::  poke the anthropic proxy — it adds auth and makes the HTTP call
  =/  proxy-road=road:tarball  (cord-to-road:tarball proxy)
  ~&  >>  ["%claw: proxy road" proxy-road]
  ~&  >>  ["%claw: about to poke proxy"]
  ;<  ~  bind:m  (poke:io proxy-road [/ %json] !>(payload))
  ~&  >>  ["%claw: poke sent, waiting for response"]
  ;<  =sage:tarball  bind:m  take-poke:io
  ~&  >>  ["%claw: got response, mark:" name.p.sage]
  =/  resp-json=json  (fall (mole |.(!<(json q.sage))) *json)
  ::  parse API response from JSON
  =/  parsed=(unit api-response)  (parse-json-response resp-json)
  ?~  parsed
    =/  raw=@t
      ?:  =(*json resp-json)  'empty response (vase extraction failed)'
      =/  full=tape  (trip (en:json:html resp-json))
      (crip ?:((lth (lent full) 200) full (weld (scag 200 full) "...")))
    =/  err-msg=@t  (crip "Error: failed to parse API response: {(trip raw)}")
    =/  err-convo=^convo  (snoc convo [%msg 'assistant' err-msg])
    ;<  ~  bind:m  (write-conv conv-key err-convo)
    (pure:m err-convo)
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
  ;<  results=(list [@t @t])  bind:m  (run-tool-calls calls conv-key)
  =/  with-results=^convo
    %+  roll  results
    |=  [[id=@t result=@t] acc=_updated]
    (snoc acc [%tool-result id result])
  ;<  ~  bind:m  (write-conv conv-key with-results)
  $(convo with-results)
::
::  +run-tool-calls: execute tool calls via /tools grubs
::
::  Waits for each tool to reach %ack or %done (whichever comes first).
::  If %ack, the tool is still running — re-subscribes on /tool-done/[tid]
::  so main.sig's event loop picks up the eventual %done.
::  If %done, the tool completed synchronously — subscription dropped.
::
++  run-tool-calls
  |=  [calls=(list content-block) conv-key=@t]
  =/  m  (fiber:fiber:nexus ,(list [@t @t]))
  ^-  form:m
  =/  results=(list [@t @t])  ~
  |-
  ?~  calls  (pure:m (flop results))
  =/  call=content-block  i.calls
  ?>  ?=(%tool-use -.call)
  =/  tool-args=(map @t json)
    ?.  ?=(%o -.input.call)  ~
    (~(put by p.input.call) '_conv_key' s+conv-key)
  =/  ts=tool-state:nex-tools
    [name.call tool-args %start ~ ~]
  =/  tid=@ta  id.call
  =/  tool-road=road:tarball  [%| 0 %& /tools tid]
  ;<  *  bind:m  (keep:io /tool-wait/[tid] tool-road ~)
  ;<  ~  bind:m  (make:io tool-road |+[%.n [[/ %tool-state] !>(ts)] ~])
  ;<  [result-text=@t more=?]  bind:m  (await-tool-ack tid)
  ;<  ~  bind:m  (drop:io /tool-wait/[tid] tool-road)
  ?:  more
    ::  tool ack'd but still running — subscribe on /tool-done for main loop
    ;<  *  bind:m  (keep:io /tool-done/[tid] tool-road ~)
    $(calls t.calls, results [[id.call result-text] results])
  $(calls t.calls, results [[id.call result-text] results])
::
::  +await-tool-ack: wait for tool grub to reach %ack or %done
::
::  Returns [result-text more=?] where more=%.y means the tool
::  is still running and will eventually reach %done.
::
++  await-tool-ack
  |=  tid=@ta
  =/  m  (fiber:fiber:nexus ,[@t ?])
  ^-  form:m
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /tool-wait/[tid])
  ?:  ?=(%wake -.nw)  $
  ?.  ?=(%file -.view.nw)  $
  =/  st=tool-state:nex-tools  !<(tool-state:nex-tools q.sage.view.nw)
  ?:  =(%ack step.st)
    (pure:m [(extract-tool-result st) %.y])
  ?.  =(%done step.st)  $
  (pure:m [(extract-tool-result st) %.n])
::
::  +extract-tool-result: pull text from tool-state update
::
++  extract-tool-result
  |=  st=tool-state:nex-tools
  ^-  @t
  ?~  update.st  'tool returned no result'
  ?.  ?=(%o -.u.update.st)  'tool returned no result'
  =/  result-type=(unit json)  (~(get by p.u.update.st) 'type')
  ?:  ?=([~ %s %'error'] result-type)
    =/  err=@t  (fall (bind (~(get by p.u.update.st) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown error')
    (crip "ERROR: {(trip err)}")
  (fall (bind (~(get by p.u.update.st) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '')
::
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
++  parse-json-response
  |=  data=json
  ^-  (unit api-response)
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
::  returns list of API message objects with sliding window.
::  walks backward from end, keeping entries within token budget.
::  if truncated, prepends a note about earlier history.
::  resolves [ref:N-M] in tool results from full convo.
::  truncates individual messages exceeding msg-cap tokens.
::  consecutive tool-use entries get merged into one assistant message.
::  consecutive tool-result entries get merged into one user message.
::
++  assemble
  |=  [=convo ctx-window=@ud msg-cap=@ud]
  ^-  (list json)
  =/  total=@ud  (lent convo)
  =/  cap-chars=@ud  (mul msg-cap 4)
  ::  sliding window: walk backward, keep entries within budget
  =/  windowed=^convo
    =/  budget=@ud  ctx-window
    =/  rev=^convo  (flop convo)
    =/  kept=^convo  ~
    |-
    ?~  rev  kept
    =/  tok=@ud  (entry-tokens i.rev)
    ?:  (gth tok budget)  kept
    $(rev t.rev, kept [i.rev kept], budget (sub budget tok))
  =/  skipped=@ud  (sub total (lent windowed))
  =/  skipped-tokens=@ud
    %+  roll  (scag skipped convo)
    |=  [e=entry acc=@ud]
    (add acc (entry-tokens e))
  =/  window-start=@ud  skipped
  =/  prefix=(unit json)
    ?:  =(0 skipped)  ~
    =/  note=@t
      %-  crip
      ;:  weld
        "[Conversation history truncated. "
        (a-co:co skipped)
        " earlier messages (est. "
        (a-co:co skipped-tokens)
        " tokens) not shown, covering messages 0-"
        (a-co:co (dec skipped))
        ". Current window starts at message "
        (a-co:co window-start)
        ".]"
      ==
    `(pairs:enjs:format ~[['role' s+'user'] ['content' s+note]])
  ::  assemble the windowed entries
  =/  msgs=(list json)  ?~(prefix ~ [u.prefix]~)
  =/  pending-tools=(list json)  ~
  =/  pending-results=(list json)  ~
  =/  walk=^convo  windowed
  |-  ^-  (list json)
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
  ?~  walk
    =.  msgs  flush-tools
    =.  msgs  flush-results
    (flop msgs)
  ?-  -.i.walk
      %msg
    =.  msgs  flush-tools
    =.  msgs  flush-results
    =/  txt=@t  (cap-content content.i.walk cap-chars)
    %=  $
      walk  t.walk
      pending-tools  ~
      pending-results  ~
      msgs  :_  msgs
             (pairs:enjs:format ~[['role' s+role.i.walk] ['content' s+txt]])
    ==
      %tool-use
    =.  msgs  flush-results
    =.  pending-results  ~
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_use']
          ['id' s+id.i.walk]
          ['name' s+name.i.walk]
          ['input' input.i.walk]
      ==
    $(walk t.walk, pending-tools [block pending-tools])
      %tool-result
    =.  msgs  flush-tools
    =.  pending-tools  ~
    ::  resolve [ref:N-M] markers from full convo
    =/  txt=@t  (resolve-content content.i.walk convo cap-chars)
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+tool-use-id.i.walk]
          ['content' s+txt]
      ==
    $(walk t.walk, pending-results [block pending-results])
  ==
::
::  +cap-content: truncate content to char limit with note
::
++  cap-content
  |=  [txt=@t limit=@ud]
  ^-  @t
  ?:  (lte (met 3 txt) limit)  txt
  =/  original=@ud  (met 3 txt)
  %-  crip
  ;:  weld
    (scag limit (trip txt))
    "\0a\0a[truncated: showing "
    (a-co:co (div limit 4))
    " of ~"
    (a-co:co (div original 4))
    " est. tokens]"
  ==
::
::  +resolve-content: resolve [ref:N-M] markers, then cap
::
++  resolve-content
  |=  [txt=@t full=convo limit=@ud]
  ^-  @t
  =/  t=tape  (trip txt)
  ?.  ?&  (gte (lent t) 5)
          =("[ref:" (scag 5 t))
      ==
    (cap-content txt limit)
  ::  parse [ref:N-M]
  =/  inner=tape  (slag 5 t)
  =/  close=(unit @ud)  (find "]" inner)
  ?~  close  (cap-content txt limit)
  =/  range=tape  (scag u.close inner)
  =/  dash=(unit @ud)  (find "-" range)
  ?~  dash  (cap-content txt limit)
  =/  from=@ud  (fall (rush (crip (scag u.dash range)) dem) 0)
  =/  to=@ud  (fall (rush (crip (slag +(u.dash) range)) dem) 0)
  ::  resolve entries from full convo
  =/  resolved=tape
    %-  zing
    %+  turn  (gulf from to)
    |=  idx=@ud
    ^-  tape
    ?:  (gte idx (lent full))  ~
    =/  e=entry  (snag idx full)
    ;:  weld
      "["
      (a-co:co idx)
      "] "
      ?-  -.e
          %msg
        ;:  weld  (trip role.e)  ": "  (trip content.e)  ==
          %tool-use
        (weld "tool_use: " (trip name.e))
          %tool-result
        (weld "tool_result: " (trip content.e))
      ==
      "\0a"
    ==
  (cap-content (crip resolved) limit)
::
::  split a tape into lines by newline
::
++  to-lines
  |=  t=tape
  ^-  (list tape)
  =/  acc=(list tape)  ~
  =/  cur=tape  ~
  |-
  ?~  t
    (flop [cur acc])
  ?:  =(i.t '\0a')
    $(t t.t, acc [cur acc], cur ~)
  $(t t.t, cur (snoc cur i.t))
::
::  estimate tokens for a conversation entry (~4 chars per token)
::
++  entry-tokens
  |=  =entry
  ^-  @ud
  =/  chars=@ud
    ?-  -.entry
        %msg          (met 3 content.entry)
        %tool-use     (add (met 3 name.entry) (met 3 (en:json:html input.entry)))
        %tool-result  (met 3 content.entry)
    ==
  (max 1 (div chars 4))
::
::
++  read-conv-names
  |=  =view:nexus
  ^-  (list @ta)
  ?.  ?=(%ball -.view)  ~
  ?~  fil.ball.view  ~
  =/  files=(list @ta)  ~(tap in ~(key by contents.u.fil.ball.view))
  =/  names=(list @ta)
    %+  murn  files
    |=  f=@ta
    ^-  (unit @ta)
    =/  t=tape  (trip f)
    ?.  =(".json" (slag (sub (lent t) 5) t))  ~
    `(crip (scag (sub (lent t) 5) t))
  (sort names aor)
::
++  chat-page
  |=  [ball-id=tape convs=(list @ta)]
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
            ;label.cfg-label: Model
            ;input#cfg-model(type "text", placeholder "claude-sonnet-4-20250514");
            ;label.cfg-label: Context window (tokens)
            ;input#cfg-window(type "number", placeholder "200000");
            ;label.cfg-label: Message cap (tokens)
            ;input#cfg-msgcap(type "number", placeholder "20000");
            ;div#cfg-status;
          ==
        ==
        ;div#layout
          ;div#sidebar
            ;div#conv-list
              ;*  %+  turn  convs
                  |=  c=@ta
                  =/  n=tape  (trip c)
                  ;div.conv-item(data-conv n, onclick "switchConv('{n}')"): {n}
            ==
          ==
          ;div#main
            ;div#messages;
            ;form#prompt-form(onsubmit "sendMessage(event)")
              ;div.input-row
                ;input#input(type "text", placeholder "Say something...", autocomplete "off");
                ;button(type "submit"): Send
              ==
            ==
          ==
        ==
      ==
      ;script
        ;+  ;/  (script-text ball-id)
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; height: 100vh; }
  #app \{ display: flex; flex-direction: column; height: 100vh; }
  #header \{ padding: 12px 16px; border-bottom: 1px solid #333; flex-shrink: 0; }
  #header h1 \{ font-size: 20px; font-weight: 700; }
  #layout \{ display: flex; flex: 1; overflow: hidden; }
  #sidebar \{ width: 180px; border-right: 1px solid #333; overflow-y: auto; flex-shrink: 0; padding: 8px 0; }
  .conv-item \{ padding: 8px 12px; cursor: pointer; font-size: 13px; color: #888; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; border-left: 2px solid transparent; }
  .conv-item:hover \{ color: #eee; background: #1a1a1a; }
  .conv-item.active \{ color: #60a5fa; border-left-color: #2563eb; background: #1a1a2e; }
  #main \{ flex: 1; display: flex; flex-direction: column; overflow: hidden; max-width: 700px; margin: 0 auto; padding: 0 16px; }
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
  #cfg-model, #cfg-window, #cfg-msgcap \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }
  #cfg-model:focus, #cfg-window:focus, #cfg-msgcap:focus \{ border-color: #2563eb; }
  #cfg-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  """
::
++  script-text
  |=  ball-id=tape
  ^-  tape
  ;:  weld
    "var API = '/grubbery/api';\0avar BALL = '{ball-id}';\0a"
  """
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
      } else if (e.role === 'user' && e.content && e.content.indexOf('[spawn_task result]:') === 0) \{
        div.className = 'msg system';
        div.textContent = '> ' + e.content.slice(20).trim().slice(0, 200);
      } else \{
        if (e.role === 'system') continue;
        div.className = 'msg ' + e.role;
        div.textContent = e.content;
      }
      el.appendChild(div);
    }
    el.scrollTop = el.scrollHeight;
  }

  var curConv = 'main';
  var sseCtrl = null;
  var sseRdr = null;

  function sendMessage(e) \{
    e.preventDefault();
    var input = document.getElementById('input');
    var text = input.value.trim();
    if (!text) return;
    input.value = '';
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'message', content: text, conversation: curConv})
    });
  }

  function switchConv(key) \{
    curConv = key;
    var items = document.querySelectorAll('.conv-item');
    items.forEach(function(el) \{
      el.classList.toggle('active', el.dataset.conv === key);
    });
    document.getElementById('messages').innerHTML = '';
    fetch(API + '/file/' + BALL + '/context/conversations/' + key + '.json?mark=json')
      .then(function(r) \{ return r.json() })
      .then(renderMessages)
      .catch(function() \{});
    connectSSE();
  }

  // mark initial active conversation
  var first = document.querySelector('.conv-item[data-conv="main"]') || document.querySelector('.conv-item');
  if (first) first.classList.add('active');

  async function connectSSE() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
    sseCtrl = new AbortController();
    try \{
      var r = await fetch(API + '/keep/' + BALL + '/context/conversations/' + curConv + '.json?mark=json', \{
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
      if (e.name !== 'AbortError') setTimeout(connectSSE, 2000);
    }
  }

  window.addEventListener('beforeunload', function() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
  });

  // Load initial conversation
  fetch(API + '/file/' + BALL + '/context/conversations/main.json?mark=json')
    .then(function(r) \{ return r.json() })
    .then(renderMessages)
    .catch(function() \{});
  connectSSE();

  // Config modal
  var cfgBack = document.getElementById('cfg-backdrop');
  var cfgModel = document.getElementById('cfg-model');
  var cfgWindow = document.getElementById('cfg-window');
  var cfgMsgcap = document.getElementById('cfg-msgcap');
  var cfgStatus = document.getElementById('cfg-status');

  document.getElementById('config-btn').onclick = function() \{
    cfgStatus.textContent = '';
    fetch(API + '/file/' + BALL + '/config.json?mark=json')
      .then(function(r) \{ return r.json() })
      .then(function(j) \{
        cfgModel.value = j['model'] || '';
        cfgWindow.value = j['context_window'] || 200000;
        cfgMsgcap.value = j['message_cap'] || 20000;
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
    var cfg = \{'model': cfgModel.value, 'context_window': parseInt(cfgWindow.value) || 200000, 'message_cap': parseInt(cfgMsgcap.value) || 20000};
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
  ==

::
::  built-in tools
::
::  +get-arg: extract a string argument from tool state
::
++  get-arg
  |=  [st=tool-state:nex-tools key=@t]
  ^-  (unit @t)
  (bind (~(get by args.st) key) |=(j=json ?>(?=(%s -.j) p.j)))
::
::  +agent-road: adjust a road so relative paths resolve from the agent root
::
::  Tools run at /tools/{tid}, one level below the agent. The LLM thinks
::  in terms of the agent directory, so ./foo should mean agent-root/foo,
::  not /tools/{tid}/foo. This prepends ../ to relative roads.
::
++  agent-road
  |=  raw=@t
  ^-  road:tarball
  =/  t=tape  (trip raw)
  =/  adjusted=@t
    ::  only adjust ./ (agent-relative), not ../ (already traversing)
    ?:  =("./" (scag 2 t))
      (crip (weld "../" (slag 2 t)))
    ::  bare ../ paths: add one more level to account for tool depth
    ?:  =(".." (scag 2 t))
      (crip (weld "../" t))
    raw
  (cord-to-road:tarball adjusted)
::
::
++  browse-tool
  ^-  tool:nex-tools
  |%
  ++  name  'browse'
  ++  description
    ^~  %-  crip
    ;:  weld
      "List files and subdirectories at a path in this nexus. "
      "Accepts a road string: absolute (/tools/) or "
      "relative (./context/, ../). Trailing slash for directories."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to a directory (e.g. "/", "./context/", "/tools/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  =seen:nexus  bind:m  (peek:io road ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error (crip "Not a directory: {(trip u.raw)}")])
    =/  sub-dirs=(list @ta)  ~(tap in ~(key by dir.ball.p.seen))
    =/  files=(list [@ta @tas])
      ?~  fil.ball.p.seen  ~
      %+  turn  ~(tap by contents.u.fil.ball.p.seen)
      |=([n=@ta c=content:tarball] [n name.p.sage.c])
    =/  dir-text=tape
      ?~  sub-dirs  ""
      (zing (turn sub-dirs |=(d=@ta "\0a  {(trip d)}/")))
    =/  file-text=tape
      ?~  files  ""
      (zing (turn files |=([n=@ta *] "\0a  {(trip n)}")))
    (pure:m [%text (crip :(weld (trip u.raw) dir-text file-text))])
  --
::
++  read-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Read a file from this nexus. Paths are relative to the agent root "
      "(e.g. ./config.json, ./context/conversations/main.json) or absolute. "
      "Use offset/limit to read a specific line range from large files."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    ^-  (list [@t parameter-def:nex-tools])
    :~  ['road' [%string 'Path to a file (e.g. "./config.json")']]
        ['offset' [%number 'Start line (1-indexed, default: 1)']]
        ['limit' [%number 'Max lines to return (default: all)']]
    ==
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  =seen:nexus  bind:m  (peek:io road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip u.raw)}")])
    =/  off=@ud
      =/  v  (~(get by args.st) 'offset')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    =/  lim=@ud
      =/  v  (~(get by args.st) 'limit')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    ?:  &(=(0 off) =(0 lim))
      ::  no range specified, return full file
      (render-grub-content:nex-tools seen)
    ::  range read: convert to text and slice by lines
    ;<  =mime  bind:m  (sage-to-mime:io sage.p.seen)
    =/  text=tape  (trip ;;(@t q.q.mime))
    =/  lines=(list tape)  (to-lines text)
    =/  total=@ud  (lent lines)
    =/  start=@ud  ?:(=(0 off) 0 (dec off))
    =/  sliced=(list tape)
      =/  after=(list tape)  (slag start lines)
      ?:(=(0 lim) after (scag lim after))
    =/  end=@ud  (add start (lent sliced))
    =/  header=tape
      "[lines {<(add start 1)>}-{<end>} of {<total>}]\0a"
    =/  numbered=tape
      %-  zing
      =/  n=@ud  (add start 1)
      |-
      ?~  sliced  ~
      =/  line=tape  :(weld (a-co:co n) "\09" i.sliced "\0a")
      [line $(sliced t.sliced, n +(n))]
    (pure:m [%text (crip (weld header numbered))])
  --
::
++  write-tool
  ^-  tool:nex-tools
  |%
  ++  name  'write'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Write a file in this nexus. "
      "Accepts a road string pointing to a file: "
      "absolute (/config.json) or relative (./content/code/lib/tools/my-tool.hoon). "
      "Creates the file if it doesn't exist, overwrites if it does. "
      "Mark is inferred from filename extension. "
      "Content is passed through mime conversion."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to a file (e.g. "/config.json", "./content/code/lib/tools/foo.hoon")']]
        ['content' [%string 'Text content to write']]
    ==
  ++  required  ~['road' 'content']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  content=(get-arg st 'content')
      (pure:m [%error 'Missing required argument: content'])
    =/  road=road:tarball  (agent-road u.raw)
    =/  src-mime=mime  [/text/plain (as-octs:mimes:html u.content)]
    ;<  exists=?  bind:m  (peek-exists:io road)
    ?:  exists
      ;<  ~  bind:m  (over:io road [[/ %mime] !>(src-mime)])
      (pure:m [%text (crip "Wrote {(trip u.raw)}")])
    ;<  ~  bind:m  (make:io road |+[%.n [[/ %mime] !>(src-mime)] ~])
    (pure:m [%text (crip "Created {(trip u.raw)}")])
  --
::
++  edit-tool
  ^-  tool:nex-tools
  |%
  ++  name  'edit'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Edit a file via exact string replacement. "
      "Fails if old_string is not found or matches multiple locations. "
      "Set replace_all to replace every occurrence."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  ~(gas by *(map @t parameter-def:nex-tools))
    :~  ['road' [%string 'Road to the file to edit']]
        ['old_string' [%string 'Exact text to find and replace']]
        ['new_string' [%string 'Replacement text']]
        ['replace_all' [%boolean 'Replace all occurrences (default: false)']]
    ==
  ++  required  ~['road' 'old_string' 'new_string']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  old=(get-arg st 'old_string')
      (pure:m [%error 'Missing required argument: old_string'])
    ?~  new=(get-arg st 'new_string')
      (pure:m [%error 'Missing required argument: new_string'])
    =/  replace-all=?
      =/  ra  (~(get by args.st) 'replace_all')
      ?~  ra  %.n
      ?:  ?=([~ %b *] ra)  p.u.ra
      %.n
    =/  road=road:tarball  (agent-road u.raw)
    ;<  =seen:nexus  bind:m  (peek:io road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip u.raw)}")])
    ;<  =mime  bind:m  (sage-to-mime:io sage.p.seen)
    =/  txt=tape  (trip q.q.mime)
    =/  result=(each tape @tas)
      (tape-replace:nex-tools txt (trip u.old) (trip u.new) replace-all)
    ?.  ?=(%& -.result)
      ?+  p.result
        (pure:m [%error 'Edit failed'])
          %not-found
        (pure:m [%error 'old_string not found in file'])
          %not-unique
        (pure:m [%error 'old_string matches multiple locations. Provide more context or set replace_all.'])
          %empty-search
        (pure:m [%error 'old_string cannot be empty'])
      ==
    =/  new-mime=^mime  [/text/plain (as-octs:mimes:html (crip p.result))]
    ;<  ~  bind:m  (over:io road [[/ %mime] !>(new-mime)])
    (pure:m [%text (crip "Edited {(trip u.raw)}")])
  --
::
++  delete-tool
  ^-  tool:nex-tools
  |%
  ++  name  'delete'
  ++  description  'Delete a file from this nexus.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the file to delete']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  ~  bind:m  (cull:io road)
    (pure:m [%text (crip "Deleted {(trip u.raw)}")])
  --
::
++  mkdir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'mkdir'
  ++  description  'Create a directory in this nexus.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the directory to create (e.g. "/children/my-thing/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    =/  new-ball=ball:tarball  [`[~ ~ ~] ~]
    ;<  ~  bind:m  (make:io road &+[*sand:nexus *gain:nexus new-ball])
    (pure:m [%text (crip "Created directory {(trip u.raw)}")])
  --
::
++  create-nexus-tool
  ^-  tool:nex-tools
  |%
  ++  name  'create_nexus'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Create a nexus (directory with code) in this nexus. "
      "Provide the road for the new directory and the code "
      "path pointing to the nexus source (e.g. /claw/agent)."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to the new nexus directory']]
        ['code' [%string 'Code path as a rail (e.g. "/nex/claw/agent")']]
    ==
  ++  required  ~['road' 'code']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  code-raw=(get-arg st 'code')
      (pure:m [%error 'Missing required argument: code'])
    =/  road=road:tarball  (agent-road u.raw)
    =/  code-pax=path  (stab u.code-raw)
    ?~  code-pax
      (pure:m [%error 'Code path cannot be empty'])
    =/  code-rail=rail:tarball  [(snip `path`code-pax) (rear code-pax)]
    =/  new-ball=ball:tarball  [`[~ `code-rail ~] ~]
    ;<  ~  bind:m  (make:io road &+[*sand:nexus *gain:nexus new-ball])
    (pure:m [%text (crip "Created nexus {(trip u.raw)} with code {(trip u.code-raw)}")])
  --
::
++  delete-nexus-tool
  ^-  tool:nex-tools
  |%
  ++  name  'delete_nexus'
  ++  description  'Delete a nexus directory and all its contents.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the nexus directory to delete']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  ~  bind:m  (cull:io road)
    (pure:m [%text (crip "Deleted nexus {(trip u.raw)}")])
  --
::
++  read-manual-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read_manual'
  ++  description  'Look up on-manu documentation for any path. Use to understand what a directory or file does.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to look up docs for']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  doc=@t  bind:m  (manu-road:io road)
    ?:  =('' doc)
      (pure:m [%text (crip "No documentation found for {(trip u.raw)}")])
    (pure:m [%text doc])
  --
::
++  read-font-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read_font'
  ++  description  'Find which code namespace governs a path.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to query']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  res=(unit bend:tarball)  bind:m  (get-font:io road)
    ?~  res
      (pure:m [%text (crip "No code found governing {(trip u.raw)}")])
    (pure:m [%text (crip "Code: {(trip (road-to-cord:tarball [%| u.res]))}")])
  --
::
++  read-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'read_weir'
  ++  description  'Read sandbox (weir) rules for a directory. Shows which roads are allowed for write, poke, and read.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the directory to inspect (e.g. "./" or "./children/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io dir-road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m [%error (crip "Not a directory or not found: {(trip u.raw)}")])
    =/  weir=weir:nexus  (fall fil.sand.p.dir-seen [~ ~ ~])
    ?:  &(=(~ make.weir) =(~ poke.weir) =(~ peek.weir))
      (pure:m [%text (crip "No weir at {(trip u.raw)} — unrestricted")])
    =/  render
      |=  roads=(set road:tarball)
      ^-  tape
      =/  lst=(list road:tarball)  ~(tap in roads)
      ?~  lst  "  (none)\0a"
      %-  zing
      %+  turn  lst
      |=(=road:tarball "  {(trip (road-to-cord:tarball road))}\0a")
    %-  pure:m
    :-  %text
    %-  crip
    ;:  weld
      "Weir at {(trip u.raw)}:\0a\0a"
      "write (make) allowed:\0a"  (render make.weir)
      "\0apoke allowed:\0a"  (render poke.weir)
      "\0aread (peek) allowed:\0a"  (render peek.weir)
    ==
  --
::
++  add-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'add_weir'
  ++  description  'Add a sandbox (weir) rule to a directory. Categories: write, poke, read.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to the directory to add the rule to']]
        ['category' [%string 'Rule category: "write", "poke", or "read"']]
        ['allow_road' [%string 'Road to allow (e.g. "/" for root, "/tools/" for tools dir)']]
    ==
  ++  required  ~['road' 'category' 'allow_road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  cat=(get-arg st 'category')
      (pure:m [%error 'Missing required argument: category'])
    ?~  allow=(get-arg st 'allow_road')
      (pure:m [%error 'Missing required argument: allow_road'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    =/  allow-road=road:tarball  (cord-to-road:tarball u.allow)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io dir-road ~)
    =/  cur=weir:nexus
      ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
      (fall fil.sand.p.dir-seen [~ ~ ~])
    =/  new=weir:nexus
      ?+  u.cat  cur
        %'write'  cur(make (~(put in make.cur) allow-road))
        %'poke'   cur(poke (~(put in poke.cur) allow-road))
        %'read'   cur(peek (~(put in peek.cur) allow-road))
      ==
    ;<  ~  bind:m  (sand:io dir-road `new)
    (pure:m [%text (crip "Added {(trip u.cat)} rule to {(trip u.raw)}")])
  --
::
++  del-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'del_weir'
  ++  description  'Remove a sandbox (weir) rule from a directory.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['road' [%string 'Road to the directory']]
        ['category' [%string 'Rule category: "write", "poke", or "read"']]
        ['allow_road' [%string 'Road to remove from the allow list']]
    ==
  ++  required  ~['road' 'category' 'allow_road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    ?~  cat=(get-arg st 'category')
      (pure:m [%error 'Missing required argument: category'])
    ?~  allow=(get-arg st 'allow_road')
      (pure:m [%error 'Missing required argument: allow_road'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    =/  del-road=road:tarball  (cord-to-road:tarball u.allow)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io dir-road ~)
    =/  cur=weir:nexus
      ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
      (fall fil.sand.p.dir-seen [~ ~ ~])
    =/  new=weir:nexus
      ?+  u.cat  cur
        %'write'  cur(make (~(del in make.cur) del-road))
        %'poke'   cur(poke (~(del in poke.cur) del-road))
        %'read'   cur(peek (~(del in peek.cur) del-road))
      ==
    ;<  ~  bind:m  (sand:io dir-road `new)
    (pure:m [%text (crip "Removed {(trip u.cat)} rule from {(trip u.raw)}")])
  --
::
++  clear-weir-tool
  ^-  tool:nex-tools
  |%
  ++  name  'clear_weir'
  ++  description  'Clear all sandbox (weir) rules from a directory, giving it unrestricted access.'
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to the directory to clear']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  ~  bind:m  (sand:io road ~)
    (pure:m [%text (crip "Cleared weir from {(trip u.raw)}")])
  --
::
++  check-bin-tool
  ^-  tool:nex-tools
  |%
  ++  name  'check_bin'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Check if a build artifact compiled successfully. "
      "Provide the code namespace road and artifact name. "
      "Example: code_road='/content/code/lib/tools/' name='my-tool' "
      "to check a compiled tool. Returns the error tang "
      "if compilation failed, or confirms success."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['code_road' [%string 'Road to code directory (e.g. "/content/code/lib/tools/", "./code/lib/")']]
        ['name' [%string 'Artifact name (e.g. "my-tool")']]
    ==
  ++  required  ~['code_road' 'name']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'code_road')
      (pure:m [%error 'Missing required argument: code_road'])
    ?~  nam=(get-arg st 'name')
      (pure:m [%error 'Missing required argument: name'])
    =/  dir-road=road:tarball  (agent-road u.raw)
    =/  bin-name=@ta  (crip (trip u.nam))
    =/  code-road=road:tarball
      ?-  -.dir-road
        %&  ?-(-.p.dir-road %& dir-road, %| [%& %& p.p.dir-road bin-name])
        %|  ?-(-.q.p.dir-road %& dir-road, %| [%| p.p.dir-road %& p.q.p.dir-road bin-name])
      ==
    ;<  res=built:nexus  bind:m  (get-code-full:io code-road)
    ?:  ?=(%vase -.res)
      (pure:m [%text (crip "OK: {(trip u.raw)}{(trip u.nam)} compiled successfully")])
    ?.  ?=(%tang -.res)
      (pure:m [%text (crip "OK: {(trip u.raw)}{(trip u.nam)} — non-vase artifact")])
    =/  rendered=tape
      %-  zing
      %+  turn  (flop tang.res)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%text (crip "FAILED: {(trip u.raw)}{(trip u.nam)}\0a{rendered}")])
  --
::
++  check-bang-tool
  ^-  tool:nex-tools
  |%
  ++  name  'check_bang'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Check runtime health at a path. "
      "Returns any nexus-level or per-file errors (bangs). "
      "Use after writing code to see if anything broke. "
      "Example: road='/' to check the whole nexus."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    (malt ~[['road' [%string 'Road to check (e.g. "/", "/content/code/", "./code/")']]])
  ++  required  ~['road']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'road')
      (pure:m [%error 'Missing required argument: road'])
    =/  road=road:tarball  (agent-road u.raw)
    ;<  res=(each bangs:nexus (unit tang))  bind:m  (get-bang:io road)
    ?:  ?=(%| -.res)
      ?~  p.res
        (pure:m [%error (crip "Path not found: {(trip u.raw)}")])
      =/  rendered=tape
        (zing (turn (flop u.p.res) |=(=tank (weld ~(ram re tank) "\0a"))))
      (pure:m [%error (crip "Query failed:\0a{rendered}")])
    =/  =bangs:nexus  p.res
    =/  out=tape  ""
    =?  out  ?=(^ bang.bangs)
      =/  rendered=tape
        (zing (turn (flop u.bang.bangs) |=(=tank (weld ~(ram re tank) "\0a"))))
      "NEXUS BANG:\0a{rendered}"
    =/  errs=(list [@ta (unit tang)])  ~(tap by err.bangs)
    =/  file-out=tape
      %-  zing
      %+  murn  errs
      |=  [name=@ta err=(unit tang)]
      ^-  (unit tape)
      ?~  err  ~
      =/  rendered=tape
        (zing (turn (flop u.err) |=(=tank (weld ~(ram re tank) "\0a"))))
      `"\0a{(trip name)}: BANGED\0a{rendered}"
    =.  out  (weld out file-out)
    ?:  =('' (crip out))
      (pure:m [%text (crip "OK: {(trip u.raw)} — no errors")])
    (pure:m [%text (crip out)])
  --
::
++  finish-tool
  ^-  tool:nex-tools
  |%
  ++  name  'finish'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Signal that this nexus has completed its task. "
      "Writes result.json at the nexus root, which closes "
      "the conversation and makes the result available to "
      "a parent nexus. Once finished, no more messages are accepted."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['result' [%string 'The final result text to return']]
        ['status' [%string 'Status: "complete", "error", "partial" (default: "complete")']]
    ==
  ++  required  ~['result']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  result=(get-arg st 'result')
      (pure:m [%error 'Missing required argument: result'])
    =/  status=@t
      (fall (get-arg st 'status') 'complete')
    =/  result-json=json
      %-  pairs:enjs:format
      :~  ['status' s+status]
          ['result' s+u.result]
      ==
    =/  road=road:tarball  (cord-to-road:tarball '../../result.json')
    ;<  exists=?  bind:m  (peek-exists:io road)
    ?:  exists
      ;<  ~  bind:m  (over:io road [[/ %json] !>(result-json)])
      (pure:m [%text 'Finished — result.json updated'])
    ;<  ~  bind:m  (make:io road |+[%.n [[/ %json] !>(result-json)] ~])
    (pure:m [%text 'Finished — result.json written'])
  --
::
++  await-child-result
  |=  pfx=tape
  =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
  ^-  form:m
  =/  result-road=road:tarball
    (cord-to-road:tarball (crip "{pfx}/result.json"))
  ::  drop any stale subscription from a previous run, then subscribe fresh
  ;<  ~  bind:m  (drop:io /spawn-result result-road)
  ;<  *  bind:m  (keep:io /spawn-result result-road ~)
  ::  check if result already exists before waiting
  ;<  =seen:nexus  bind:m  (peek:io result-road ~)
  ?:  ?=([%& %file *] seen)
    =/  result-json=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
    ;<  ~  bind:m  (drop:io /spawn-result result-road)
    (extract-child-result result-json)
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /spawn-result)
  ?:  ?=(%wake -.nw)  $
  ?.  ?=(%file -.view.nw)  $
  =/  result-json=json  (fall (mole |.(!<(json q.sage.view.nw))) *json)
  ;<  ~  bind:m  (drop:io /spawn-result result-road)
  (extract-child-result result-json)
::
++  extract-child-result
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
  ^-  form:m
  ?~  jon  (pure:m [%error 'spawn_task: child result.json is empty'])
  ?.  ?=(%o -.jon)  (pure:m [%error 'spawn_task: child result.json is not an object'])
  =/  status=@t
    (fall (bind (~(get by p.jon) 'status') |=(j=json ?>(?=(%s -.j) p.j))) 'unknown')
  =/  result=@t
    (fall (bind (~(get by p.jon) 'result') |=(j=json ?>(?=(%s -.j) p.j))) 'no result text')
  ?:  =('error' status)
    (pure:m [%error result])
  (pure:m [%text result])
::
++  spawn-task-tool
  ^-  tool:nex-tools
  |%
  ++  name  'spawn_task'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Spawn a named child claw nexus to handle a task asynchronously. "
      "Creates the nexus at ./children/<name>/, copies config, "
      "and sends the message. Returns immediately with an ack, "
      "then delivers the final result when the child finishes. "
      "Use a short descriptive name unique to this task (e.g. 'research-api', 'build-parser')."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['name' [%string 'Unique name for the child (e.g. "research-api", "build-parser")']]
        ['message' [%string 'Task message to send to the child']]
        ['prompt' [%string 'System prompt for the child (written to /context/prompts/task.txt)']]
        ['code' [%string 'Code path for the nexus (default: "/claw/agent")']]
    ==
  ++  required  ~['name' 'message']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ::  if resuming from ack, skip creation — just re-subscribe and wait
    ?:  =(%ack step.st)
      =/  pfx=tape
        =/  d=json  data.st
        ?~  d  ""
        ?.  ?=(%o -.d)  ""
        =/  v  (~(get by p.d) 'pfx')
        ?~  v  ""
        ?.  ?=(%s -.u.v)  ""
        (trip p.u.v)
      ?:  =(~ pfx)
        (pure:m [%error 'spawn_task: lost child path on restart'])
      (await-child-result pfx)
    ::  normal creation flow
    ?~  name=(get-arg st 'name')
      (pure:m [%error 'Missing required argument: name'])
    ?~  message=(get-arg st 'message')
      (pure:m [%error 'Missing required argument: message'])
    =/  code=@t  (fall (get-arg st 'code') '/claw/agent')
    =/  tid=@ta  (crip (cass:so (trip u.name)))
    =/  tid-t=tape  (trip tid)
    ::  create child nexus (relative from tool proc: ../../children/{name}/)
    =/  pfx=tape  "../../children/{tid-t}"
    =/  child-road=road:tarball  (cord-to-road:tarball (crip "{pfx}/"))
    ::  check if child already exists
    ;<  exists=?  bind:m  (peek-exists:io (cord-to-road:tarball (crip "{pfx}/main.sig")))
    ?:  exists
      (pure:m [%error (crip "Child '{tid-t}' already exists. Use a unique name.")])
    =/  code-pax=path  (stab code)
    ?~  code-pax
      (pure:m [%error 'Code path cannot be empty'])
    =/  code-rail=rail:tarball  [(snip `path`code-pax) (rear code-pax)]
    =/  new-ball=ball:tarball  [`[~ `code-rail ~] ~]
    ;<  ~  bind:m  (make:io child-road &+[*sand:nexus *gain:nexus new-ball])
    ::  read parent config (../../config.json from tool proc)
    ;<  parent-config=json  bind:m
      =/  m  (fiber:fiber:nexus ,json)
      =/  road=road:tarball  (cord-to-road:tarball '../../config.json')
      ;<  =seen:nexus  bind:m  (peek:io road ~)
      ?.  ?=([%& %file *] seen)  (pure:m *json)
      (pure:m (fall (mole |.(!<(json q.sage.p.seen))) *json))
    =/  child-config-road=road:tarball
      (cord-to-road:tarball (crip "{pfx}/config.json"))
    ;<  cfg-exists=?  bind:m  (peek-exists:io child-config-road)
    ;<  ~  bind:m
      ?:  cfg-exists
        (over:io child-config-road [[/ %json] !>(parent-config)])
      (make:io child-config-road |+[%.n [[/ %json] !>(parent-config)] ~])
    ::  write task prompt with finish instructions
    =/  base-instructions=@t
      %-  crip
      ;:  weld
        "You are running as a subtask of a parent nexus.\0a"
        "When you have completed your work, you MUST call the `finish` tool "
        "with your result text in the `result` parameter.\0a"
        "This is the ONLY way to return your result to the parent. "
        "Do not just respond with text — call `finish`.\0a"
      ==
    =/  full-prompt=@t
      =/  user-prompt=(unit @t)  (get-arg st 'prompt')
      ?~  user-prompt  base-instructions
      (crip "{(trip base-instructions)}\0a{(trip u.user-prompt)}")
    =/  prompt-road=road:tarball
      (cord-to-road:tarball (crip "{pfx}/context/prompts/task.txt"))
    =/  prompt-wain=wain  (to-wain:format full-prompt)
    ;<  ~  bind:m
      =/  m  (fiber:fiber:nexus ,~)
      ;<  pex=?  bind:m  (peek-exists:io prompt-road)
      ?:  pex
        (over:io prompt-road [[/ %txt] !>(prompt-wain)])
      (make:io prompt-road |+[%.n [[/ %txt] !>(prompt-wain)] ~])
    ::  poke child with message
    =/  msg-json=json
      (pairs:enjs:format ~[['action' s+'message'] ['content' s+u.message]])
    =/  child-sig-road=road:tarball
      (cord-to-road:tarball (crip "{pfx}/main.sig"))
    ;<  ~  bind:m
      (send-dart:io [%node /spawn-task child-sig-road %poke [[/ %json] !>(msg-json)]])
    ::  ack — store pfx in data so we can resume on restart
    =/  ack-data=json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          ['text' s+(crip "Task started at ./children/{tid-t}/")]
          ['pfx' s+(crip pfx)]
      ==
    ;<  ~  bind:m
      (replace:io !>(`tool-state:nex-tools`[tool.st args.st %ack ack-data `ack-data]))
    ::  subscribe and wait for result
    (await-child-result pfx)
  --
::
++  grep-files-tool
  ^-  tool:nex-tools
  |%
  ++  name  'grep'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search file contents for a string. Returns matching lines with "
      "file paths and line numbers. Optionally filter by path, name, or mark pattern."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['pattern' [%string 'Text string to search for']]
        ['path' [%string 'Directory path glob filter (e.g. "/context/*")']]
        ['name' [%string 'Filename glob filter (e.g. "*config*")']]
        ['mark' [%string 'Mark/extension glob filter (e.g. "hoon", "json")']]
    ==
  ++  required  ~['pattern']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'pattern')
      (pure:m [%error 'Missing required argument: pattern'])
    =/  search=tape  (trip u.raw)
    =/  pat-path=(unit @t)  (get-arg st 'path')
    =/  pat-name=(unit @t)  (get-arg st 'name')
    =/  pat-mark=(unit @t)  (get-arg st 'mark')
    ::  browse agent root (one level up from tool grub)
    ;<  =seen:nexus  bind:m  (peek:io [%| 1 %| ~] ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read ball'])
    =/  candidates=(list [rail:tarball content:tarball])
      %+  skim  ~(tap ba:tarball ball.p.seen)
      |=  [=rail:tarball =content:tarball]
      =/  fp=tape  ?~(path.rail "/" (trip (spat path.rail)))
      =/  fn=tape  (trip name.rail)
      =/  fm=tape  (trip name.p.sage.content)
      ?&  ?~(pat-path %.y (glob-match:nex-tools (trip u.pat-path) fp))
          ?~(pat-name %.y (glob-match:nex-tools (trip u.pat-name) fn))
          ?~(pat-mark %.y (glob-match:nex-tools (trip u.pat-mark) fm))
      ==
    =|  results=(list tape)
    =/  total=@ud  0
    |-
    ?~  candidates
      ?~  results
        (pure:m [%text 'No matches found'])
      =/  out=tape  (zing (flop results))
      (pure:m [%text (crip "Found {<total>} matches:{out}")])
    =/  [=rail:tarball =content:tarball]  i.candidates
    =/  label=tape
      =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
      "{pax}/{(trip name.rail)}"
    ;<  file-seen=seen:nexus  bind:m
      (peek:io [%| 1 %& path.rail name.rail] ~)
    ?.  ?=([%& %file *] file-seen)
      $(candidates t.candidates)
    ;<  =mime  bind:m  (sage-to-mime:io sage.p.file-seen)
    =/  text=tape  (trip ;;(@t q.q.mime))
    =/  lines=(list tape)  (to-lines text)
    =/  line-num=@ud  1
    =/  hits=(list tape)  ~
    |-
    ?~  lines
      =/  new-results=(list tape)
        ?~  hits  results
        (weld (flop hits) results)
      ^$(candidates t.candidates, results new-results, total (add total (lent hits)))
    =?  hits  !=(~ (find search i.lines))
      :_  hits
      "\0a{label}:{<line-num>}: {i.lines}"
    $(lines t.lines, line-num +(line-num))
  --
::
++  glob-files-tool
  ^-  tool:nex-tools
  |%
  ++  name  'glob'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search for files by path, name, and/or mark. "
      "All patterns support * wildcards. Omitted filters match everything."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['path' [%string 'Directory path glob filter (e.g. "/context/*")']]
        ['name' [%string 'Filename glob filter (e.g. "*config*")']]
        ['mark' [%string 'Mark/extension glob filter (e.g. "hoon", "json")']]
    ==
  ++  required  ~
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  pat-path=(unit @t)  (get-arg st 'path')
    =/  pat-name=(unit @t)  (get-arg st 'name')
    =/  pat-mark=(unit @t)  (get-arg st 'mark')
    ;<  =seen:nexus  bind:m  (peek:io [%| 1 %| ~] ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read ball'])
    =/  matches=(list [rail:tarball @tas])
      %+  murn  ~(tap ba:tarball ball.p.seen)
      |=  [=rail:tarball =content:tarball]
      =/  fp=tape  ?~(path.rail "/" (trip (spat path.rail)))
      =/  fn=tape  (trip name.rail)
      =/  fm=tape  (trip name.p.sage.content)
      ?.  ?&  ?~(pat-path %.y (glob-match:nex-tools (trip u.pat-path) fp))
              ?~(pat-name %.y (glob-match:nex-tools (trip u.pat-name) fn))
              ?~(pat-mark %.y (glob-match:nex-tools (trip u.pat-mark) fm))
          ==
        ~
      `[rail name.p.sage.content]
    ?~  matches
      (pure:m [%text 'No matches found'])
    =/  result=tape
      %-  zing
      %+  turn  matches
      |=  [=rail:tarball mark=@tas]
      =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
      "\0a{pax}/{(trip name.rail)}"
    (pure:m [%text (crip "Found {<(lent matches)>} matches:{result}")])
  --
::
++  grep-history-tool
  ^-  tool:nex-tools
  |%
  ++  name  'grep_history'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search the full conversation history (including messages outside the current "
      "context window) for a substring. Returns matching entries with their index, "
      "role, and the matching line. Use recall_messages to pull specific results "
      "into the current context."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['query' [%string 'Substring to search for (case-insensitive)']]
        ['conversation' [%string 'Conversation key (default: "main")']]
    ==
  ++  required  ~['query']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    ?~  raw=(get-arg st 'query')
      (pure:m [%error 'Missing required argument: query'])
    =/  query=tape  (cass (trip u.raw))
    =/  conv-key=@t
      (fall (get-arg st '_conv_key') (fall (get-arg st 'conversation') 'main'))
    =/  conv-road=road:tarball
      (agent-road (crip "./context/conversations/{(trip conv-key)}.json"))
    ;<  exists=?  bind:m  (peek-exists:io conv-road)
    ?.  exists
      (pure:m [%text (crip "Conversation '{(trip conv-key)}' not found.")])
    ;<  =seen:nexus  bind:m  (peek:io conv-road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%text (crip "Could not read conversation '{(trip conv-key)}'.")])
    =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
    =/  conv=convo  (parse-convo jon)
    =/  results=tape  ~
    =/  idx=@ud  0
    =/  walk=convo  conv
    |-
    ?~  walk
      ?~  results
        (pure:m [%text 'No matches found.'])
      (pure:m [%text (crip results)])
    =/  e=entry  i.walk
    =/  content=tape
      ?-  -.e
          %msg          (trip content.e)
          %tool-use     (weld "tool_use: " (trip name.e))
          %tool-result  (trip content.e)
      ==
    =/  role=tape
      ?-  -.e
          %msg          (trip role.e)
          %tool-use     "assistant"
          %tool-result  "tool_result"
      ==
    ::  search each line of content
    =/  lines=(list tape)  (to-lines content)
    =/  line-hits=tape
      %-  zing
      %+  murn  lines
      |=  line=tape
      ^-  (unit tape)
      =/  lower=tape  (cass line)
      ?~  (find query lower)  ~
      =/  display=tape  ?:((gth (lent line) 200) (weld (scag 200 line) "...") line)
      `:(weld "[" (a-co:co idx) "] " role ": " display "\0a")
    %=  $
      walk   t.walk
      idx    +(idx)
      results  (weld results line-hits)
    ==
  --
::
++  recall-messages-tool
  ^-  tool:nex-tools
  |%
  ++  name  'recall_messages'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Include messages from the conversation history by index range. "
      "The content is resolved at assembly time from the full stored history. "
      "Use grep_history first to find relevant message indices."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    :~  ['from' [%number 'Start message index (inclusive)']]
        ['to' [%number 'End message index (inclusive)']]
    ==
  ++  required  ~['from' 'to']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  from=@ud
      =/  v  (~(get by args.st) 'from')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    =/  to=@ud
      =/  v  (~(get by args.st) 'to')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    ?:  (gth from to)
      (pure:m [%error '"from" must be <= "to"'])
    (pure:m [%text (crip "[ref:{(a-co:co from)}-{(a-co:co to)}]")])
  --
::
++  summarize-tool
  ^-  tool:nex-tools
  |%
  ++  name  'summarize'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Summarize a range of conversation messages by sending them to the LLM. "
      "Use grep_history first to identify relevant message indices. "
      "Always specify what kind of summary you need in the prompt: "
      "process (step-by-step what happened), decisions (choices and reasoning), "
      "technical (tools/code/configs), or action-items (what's next)."
    ==
  ++  parameters
    ^-  (map @t parameter-def:nex-tools)
    %-  malt
    ^-  (list [@t parameter-def:nex-tools])
    :~  ['from' [%number 'Start message index (inclusive)']]
        ['to' [%number 'End message index (inclusive)']]
        ['prompt' [%string 'What kind of summary: process, decisions, technical, action-items, or custom instruction']]
    ==
  ++  required  ~['from' 'to']
  ++  handler
    ^-  tool-handler:nex-tools
    =/  m  (fiber:fiber:nexus ,tool-result:nex-tools)
    ^-  form:m
    ;<  st=tool-state:nex-tools  bind:m  (get-state-as:io ,tool-state:nex-tools)
    =/  from=@ud
      =/  v  (~(get by args.st) 'from')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    =/  to=@ud
      =/  v  (~(get by args.st) 'to')
      ?~  v  0
      ?:  ?=(%n -.u.v)  (fall (rush p.u.v dem) 0)
      ?:  ?=(%s -.u.v)  (fall (rush p.u.v dem) 0)
      0
    ?:  (gth from to)
      (pure:m [%error '"from" must be <= "to"'])
    =/  user-prompt=@t
      (fall (get-arg st 'prompt') 'Provide a concise chronological summary of what happened.')
    ::  read conversation
    =/  conv-key=@t
      (fall (get-arg st '_conv_key') 'main')
    =/  conv-road=road:tarball
      (agent-road (crip "./context/conversations/{(trip conv-key)}.json"))
    ;<  exists=?  bind:m  (peek-exists:io conv-road)
    ?.  exists
      (pure:m [%error (crip "Conversation '{(trip conv-key)}' not found.")])
    ;<  =seen:nexus  bind:m  (peek:io conv-road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error 'Could not read conversation.'])
    =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
    =/  full=convo  (parse-convo jon)
    ::  slice the range
    =/  sliced=convo  (scag (add (sub to from) 1) (slag from full))
    ?:  =(~ sliced)
      (pure:m [%error 'No messages in specified range.'])
    ::  flatten slice into plain text transcript
    =/  transcript=tape
      %-  zing
      =/  idx=@ud  from
      |-
      ?~  sliced  ~
      =/  e=entry  i.sliced
      =/  line=tape
        ?-  -.e
          %msg          :(weld "[" (a-co:co idx) "] " (trip role.e) ": " (trip content.e) "\0a")
          %tool-use     :(weld "[" (a-co:co idx) "] tool_use: " (trip name.e) "\0a")
          %tool-result  :(weld "[" (a-co:co idx) "] tool_result: " (trip content.e) "\0a")
        ==
      [line $(sliced t.sliced, idx +(idx))]
    ::  read config for model + proxy
    =/  cfg-road=road:tarball  (agent-road './config.json')
    ;<  cfg-seen=seen:nexus  bind:m  (peek:io cfg-road ~)
    =/  config=json
      ?.  ?=([%& %file *] cfg-seen)  *json
      (fall (mole |.(!<(json q.sage.p.cfg-seen))) *json)
    =/  model=@t
      =/  m  (get-str config 'model')
      ?:(=('' m) 'claude-sonnet-4-20250514' m)
    =/  proxy=@t
      =/  p  (get-str config 'api-proxy')
      ?:(=('' p) '' p)
    ?:  =('' proxy)
      (pure:m [%error 'No api-proxy configured. Set it in config.json.'])
    ::  build request: single user message with transcript
    =/  payload=json
      %-  pairs:enjs:format
      :~  ['model' s+model]
          ['max_tokens' (numb:enjs:format 4.096)]
          :-  'system'
          :-  %s
          %-  crip
          =/  total=@ud  (lent full)
          ;:  weld
            "You are summarizing messages "
            (a-co:co from)
            "-"
            (a-co:co to)
            " from a larger conversation ("
            (a-co:co total)
            " messages total). This is a slice, not the full exchange.\0a\0a"
            "Rules:\0a"
            "- Use third-person perspective (never first-person)\0a"
            "- Be chronological and concrete\0a"
            "- Note problems encountered, changes in behavior, and breakthroughs\0a"
            "- Preserve key details and context, not just conclusions\0a\0a"
            "User instruction: "
            (trip user-prompt)
          ==
          :-  'messages'
          :-  %a
          :~  %-  pairs:enjs:format
              :~  ['role' s+'user']
                  ['content' s+(crip transcript)]
              ==
          ==
      ==
    =/  proxy-road=road:tarball  (agent-road proxy)
    ;<  ~  bind:m  (poke:io proxy-road [/ %json] !>(payload))
    ;<  =sage:tarball  bind:m  take-poke:io
    =/  resp=json  (fall (mole |.(!<(json q.sage))) *json)
    =/  parsed=(unit api-response)  (parse-json-response resp)
    ?~  parsed
      (pure:m [%error 'Failed to parse API response.'])
    =/  text=@t
      %-  crip
      %-  zing
      %+  turn  content-blocks.u.parsed
      |=  =content-block
      ?+  -.content-block  ""
        %text  (trip text.content-block)
      ==
    =/  header=@t
      %-  crip
      ;:  weld
        "[Summary of messages "
        (a-co:co from)
        "-"
        (a-co:co to)
        " from "
        (a-co:co (lent full))
        " total]\0a"
      ==
    (pure:m [%text (crip :(weld (trip header) (trip text)))])
  --
--
