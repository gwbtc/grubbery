::  claude nexus: flat chat with Claude API
::
/-  *claude
/+  nexus, tarball, io=fiberio
!:
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
      =?  ball  =(~ (~(get ba:tarball ball) [/ %'config.json']))
        =/  default=json
          %-  pairs:enjs:format
          :~  ['api_key' s+'']
              ['model' s+'claude-sonnet-4-20250514']
              ['max_tokens' (numb:enjs:format 4.096)]
          ==
        (~(put ba:tarball ball) [/ %'config.json'] [~ %json !>(default)])
      =?  ball  =(~ (~(get ba:tarball ball) [/ %'messages.claude-messages']))
        (~(put ba:tarball ball) [/ %'messages.claude-messages'] [~ %claude-messages !>(`messages`[%0 *((mop @ud message) lth)])])
      =?  ball  =(~ (~(get ba:tarball ball) [/ %'custom-prompt.txt']))
        (~(put ba:tarball ball) [/ %'custom-prompt.txt'] [~ %txt !>(*wain)])
      =?  ball  =(~ (~(get of ball) /api-requests))
        (~(put of ball) /api-requests [~ ~ ~])
      =?  ball  =(~ (~(get of ball) /ui))
        (~(put of ball) /ui [~ ~ ~])
      =.  ball
        %+  ~(put ba:tarball ball)  [/ui %'chat.html']
        [~ %manx !>((chat-page ~))]
      =?  ball  =(~ (~(get of ball) /ui/sse))
        (~(put of ball) /ui/sse [~ ~ ~])
      =.  ball
        (~(put ba:tarball ball) [/ui/sse %'last-message.json'] [~ %json !>(*json)])
      =.  ball
        (~(put ba:tarball ball) [/ui/sse %'status.json'] [~ %json !>((pairs:enjs:format ~[['loading' b+%.n]]))])
      [sand gain ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
      ::  /messages.claude-messages — accepts pokes, calls Claude
      ::
          [~ %'messages.claude-messages']
        ;<  ~  bind:m  (rise-wait:io prod "%claude chat: failed")
        |-
        ;<  msg=messages  bind:m  (get-state-as:io ,messages)
        ;<  =cage  bind:m  take-poke:io
        ?.  ?=(%claude-action p.cage)
          ~&  >  [%claude-chat %unknown-mark p.cage]
          $
        =/  =action  !<(action q.cage)
        ?:  =('' text.action)  $
        ~&  >  [%claude-say (end [3 80] text.action)]
        ::  append user message, save
        =/  idx=@ud
          =/  top  (ram:mon messages.msg)
          ?~(top 0 +(key.u.top))
        =/  msg=messages
          msg(messages (put:mon messages.msg idx ['user' text.action]))
        ;<  ~  bind:m  (replace:io !>(msg))
        ::  call-claude: read config, build request, send, dispatch response
        ::  loops back on thought/tool, stops on message/wait/done
        ::
          =/  errs=@ud  0
          =/  thinks=@ud  0
          |-  ::  inner loop for agent turns
          ;<  msg=messages  bind:m  (get-state-as:io ,messages)
          ::  read config for API key
          ;<  cfg-seen=seen:nexus  bind:m
            (peek:io /cfg (cord-to-road:tarball './config.json') `%json)
          =/  cfg=json
            ?.  ?=([%& %file *] cfg-seen)
              (need (de:json:html '{}'))
            !<(json q.cage.p.cfg-seen)
          =/  api-key=@t  (jget-t cfg 'api_key' '')
          ?:  =('' api-key)
            ~&  >>>  %claude-no-api-key
            ;<  ~  bind:m  (append-msg msg 'user' '<error>No API key set. Add your Anthropic API key in /config/creds or /claude.claude/config.json</error>')
            ^$
          =/  model=@t       (jget-t cfg 'model' 'claude-sonnet-4-20250514')
          =/  max-tokens=@ud  (jget-n cfg 'max_tokens' 4.096)
          =/  max-messages=@ud  (jget-n cfg 'max_messages' 50)
          ::  build system prompt: hardcoded protocol + optional custom prompt
          ;<  custom-seen=seen:nexus  bind:m
            (peek:io /prompt (cord-to-road:tarball './custom-prompt.txt') `%txt)
          ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
          =/  custom=@t
            ?.  ?=([%& %file *] custom-seen)  ''
            =/  =wain  !<(wain q.cage.p.custom-seen)
            ?~(wain '' (of-wain:format wain))
          =/  ship=@t  (scot %p our.bowl)
          =/  msg-count=@t  (crip (a-co:co (lent (tap:mon messages.msg))))
          =/  system=(unit @t)
            :-  ~
            %+  rap  3
            :~  system-prompt
                '\0a\0aLIVE CONTEXT: Ship: '
                ship
                '. Current time: '
                (scot %da now.bowl)
                '. Messages in conversation: '
                msg-count
                '.'
                ?:(=('' custom) '' (rap 3 ~['\0a\0aCUSTOM INSTRUCTIONS:\0a' custom]))
            ==
          ::  build request — window + filter messages for API payload
          =/  all-msgs=(list [idx=@ud =message])  (tap:mon messages.msg)
          =/  msg-count-ud=@ud  (lent all-msgs)
          =/  windowed=(list [idx=@ud =message])
            ?:  (lte msg-count-ud max-messages)  all-msgs
            (slag (sub msg-count-ud max-messages) all-msgs)
          =/  msgs-json=json
            :-  %a
            %+  murn  windowed
            |=  [idx=@ud =message]
            ?:  =((end [3 7] content.message) '<error>')  ~
            :-  ~
            %-  pairs:enjs:format
            ~[['role' s+role.message] ['content' s+content.message]]
          =/  body-pairs=(list [@t json])
            :~  ['model' s+model]
                ['max_tokens' (numb:enjs:format max-tokens)]
                ['messages' msgs-json]
            ==
          =?  body-pairs  ?=(^ system)
            (snoc body-pairs ['system' s+u.system])
          =/  body-cord=@t  (en:json:html (pairs:enjs:format body-pairs))
          ~&  >  [%claude-sending (lent (tap:mon messages.msg)) %messages]
          =/  status-road=road:tarball  (cord-to-road:tarball './ui/sse/status.json')
          =/  loading-on=json   (pairs:enjs:format ~[['loading' b+%.y]])
          =/  loading-off=json  (pairs:enjs:format ~[['loading' b+%.n]])
          ;<  ~  bind:m  (over:io /status status-road json+!>(loading-on))
          =/  =request:http
            :^  %'POST'  'https://api.anthropic.com/v1/messages'
              :~  ['content-type' 'application/json']
                  ['x-api-key' api-key]
                  ['anthropic-version' '2023-06-01']
              ==
            `(as-octs:mimes:html body-cord)
          ;<  response=@t  bind:m  (fetch:io request)
          ~&  >  %claude-got-response
          ;<  ~  bind:m  (over:io /status status-road json+!>(loading-off))
          ::  check for API-level errors
          =/  err=(unit @t)  (extract-error response)
          ?^  err
            ~&  >>>  [%claude-api-error u.err]
            ;<  ~  bind:m  (append-msg msg 'assistant' (cat 3 '<error>' (cat 3 u.err '</error>')))
            ^$  ::  API errors don't loop back
          =/  reply=@t  (extract-reply response)
          ?:  =('' reply)
            ~&  >>>  [%claude-empty-reply response]
            ;<  ~  bind:m  (append-msg msg 'user' '<error>Empty response from Claude API — no text content blocks returned.</error>')
            ?:  (gte +(errs) 3)
              ~&  >>>  %claude-error-limit-reached
              ^$  ::  stop after 3 consecutive errors
            $(errs +(errs))
          ::  store raw assistant response in history
          ;<  ~  bind:m  (append-msg msg 'assistant' reply)
          ::  parse XML tag and dispatch
          =/  tag=(unit response-tag)  (parse-response reply)
          ?~  tag
            ::  protocol violation — send error back, let Claude retry
            ~&  >>>  [%claude-bad-tag reply]
            ;<  ~  bind:m  (sleep:io ~s0..0001)
            ;<  msg=messages  bind:m  (get-state-as:io ,messages)
            ;<  ~  bind:m  (append-msg msg 'user' '<error>Invalid response. You must respond with exactly one XML tag: thought, tool, message, wait, or done.</error>')
            ?:  (gte +(errs) 3)
              ~&  >>>  %claude-error-limit-reached
              ^$
            $(errs +(errs))
          ?-  -.u.tag
              %thought
            ~&  >  [%claude-thought (end [3 80] text.u.tag)]
            ?:  (gte +(thinks) 5)
              ~&  >>>  %claude-thought-cap-reached
              ;<  ~  bind:m  (sleep:io ~s0..0001)
              ;<  msg=messages  bind:m  (get-state-as:io ,messages)
              ;<  ~  bind:m  (append-msg msg 'user' '<error>Thought cap reached (5). You must respond with message, wait, or done.</error>')
              $(errs 0, thinks 0)
            ;<  ~  bind:m  (sleep:io ~s0..0001)
            ;<  msg=messages  bind:m  (get-state-as:io ,messages)
            ;<  ~  bind:m  (append-msg msg 'user' '<continue/>')
            $(errs 0, thinks +(thinks))
          ::
              %tool
            ~&  >  [%claude-tool (lent calls.u.tag) %calls continue.u.tag]
            ::  TODO: execute tool calls, results arrive as separate events
            ?.  continue.u.tag  ^$
            ;<  ~  bind:m  (sleep:io ~s0..0001)
            ;<  msg=messages  bind:m  (get-state-as:io ,messages)
            ;<  ~  bind:m  (append-msg msg 'user' '<continue/>')
            $(thinks 0)
          ::
              %api
            ~&  >  [%claude-api method.u.tag path.u.tag continue.u.tag]
            ::  Spawn API request fiber — result arrives as %append poke
            ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
            =/  call-id=@ta  (scot %da now.bowl)
            =/  req-json=json
              %-  pairs:enjs:format
              :~  ['method' s+method.u.tag]
                  ['path' s+path.u.tag]
                  ['body' s+body.u.tag]
              ==
            ;<  ~  bind:m
              (make:io /api [%| 0 %& /api-requests call-id] |+[%.n json+!>(req-json) ~])
            ?.  continue.u.tag  ^$
            ;<  ~  bind:m  (sleep:io ~s0..0001)
            ;<  msg=messages  bind:m  (get-state-as:io ,messages)
            ;<  ~  bind:m  (append-msg msg 'user' '<continue/>')
            $(thinks 0)
          ::
              %notify
            ~&  >  [%claude-notify continue.u.tag]
            ?.  continue.u.tag  ^$
            ;<  ~  bind:m  (sleep:io ~s0..0001)
            ;<  msg=messages  bind:m  (get-state-as:io ,messages)
            ;<  ~  bind:m  (append-msg msg 'user' '<continue/>')
            $(thinks 0)
          ::
              %message
            ~&  >  %claude-message
            ^$  ::  stop — wait for next user poke
          ::
              %wait
            ~&  >  %claude-wait
            ^$  ::  stop — wait for next event
          ::
              %done
            ~&  >  [%claude-done output.u.tag]
            ^$  ::  stop permanently (for now, same as wait)
          ==
      ::  /api-requests/{call-id} — executes API call, pokes result back
      ::
          [[%api-requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%claude api-request: failed")
        =/  call-id=@ta  name.rail
        ~&  >  [%claude-api-request call-id]
        ;<  req=json  bind:m  (get-state-as:io ,json)
        =/  method=@t  (jget-t req 'method' '')
        =/  api-path=@t  (jget-t req 'path' '')
        =/  body=@t  (jget-t req 'body' '')
        =/  msg-road=road:tarball  [%| 1 %& / %'messages.claude-messages']
        ::  Keep is long-lived — handle separately
        =/  segs=(list @t)
          %+  turn
            (skip (split (trip api-path) '/') |=(t=tape =(~ t)))
          crip
        ?:  &(=((crip (cuss (trip method))) %'GET') ?=(^ segs) =(i.segs 'keep'))
          (dispatch-keep msg-road (turn t.segs |=(s=@t `@ta`s)))
        ::  One-shot operations
        ;<  result=@t  bind:m  (dispatch-api method api-path body)
        =/  result-text=@t  (cat 3 '<api>' (cat 3 result '</api>'))
        ~&  >  [%claude-api-done call-id (end [3 80] result)]
        ;<  ~  bind:m
          (poke:io /result msg-road claude-action+!>(`action`[%say result-text]))
        (pure:m ~)
      ::  /ui/chat.html — watches messages, renders page
      ::
          [[%ui ~] %'chat.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claude page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /msgs (cord-to-road:tarball '../messages.claude-messages') ~)
        ?.  ?=([%file *] init)  $
        =/  msg=messages  !<(messages q.cage.init)
        =/  page=manx  (chat-page (tap:mon messages.msg))
        ;<  ~  bind:m  (replace:io !>(page))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /msgs)
        ?.  ?=([%file *] upd)  $
        =/  msg=messages  !<(messages q.cage.upd)
        =/  page=manx  (chat-page (tap:mon messages.msg))
        ;<  ~  bind:m  (replace:io !>(page))
        $
      ::  /ui/sse/last-message.json — watches messages, emits last message
      ::
          [[%ui %sse ~] %'last-message.json']
        ;<  ~  bind:m  (rise-wait:io prod "%claude sse: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /msgs (cord-to-road:tarball '../../messages.claude-messages') ~)
        ?.  ?=([%file *] init)  $
        =/  msg=messages  !<(messages q.cage.init)
        =/  last=(unit [key=@ud val=message])  (ram:mon messages.msg)
        =/  init-json=json  ?~(last ~ (sse-json val.u.last))
        ;<  ~  bind:m  (replace:io !>(init-json))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /msgs)
        ?.  ?=([%file *] upd)  $
        =/  msg=messages  !<(messages q.cage.upd)
        =/  last=(unit [key=@ud val=message])  (ram:mon messages.msg)
        ?~  last  $
        =/  out=json  (sse-json val.u.last)
        ;<  ~  bind:m  (replace:io !>(out))
        $
      ::  /ui/sse/status.json — loading state, updated by message fiber
      ::
          [[%ui %sse ~] %'status.json']
        ;<  ~  bind:m  (rise-wait:io prod "%claude status: failed")
        stay:m
      ==
    --
::  helper core
::
|%
++  system-prompt
  ^~
  %-  of-wain:format
  :~  'You are Claude, an AI assistant running natively on an Urbit ship.'
      'Urbit is a peer-to-peer operating system. You run as a Hoon application on the user\'s personal server.'
      ''
      'PROTOCOL: Every response must be exactly ONE XML tag. Valid tags:'
      ''
      '<thought>Your internal reasoning. Not shown to user. You get another turn immediately.</thought>'
      '<tool continue="true">{"name":"tool_name","args":{"key":"value"}}</tool>'
      '  Executes a tool. Multiple calls: <tool>[{"name":"a","args":{}},{"name":"b","args":{}}]</tool>'
      '  Results come back as <tool> under user role.'
      '<api method="METHOD" path="/endpoint/path" continue="true">optional body</api>'
      '  Direct grubbery filesystem API. Results come back as <api> under user role.'
      '  The grubbery is a ball — a nested filesystem of typed files (grubs) and directories.'
      '  Files have marks (types) like hoon, txt, json, mime. The system auto-converts to text.'
      ''
      '  READ endpoints (no body needed, self-closing OK):'
      '    GET /file/path/to/name.ext  — read file content (auto-converted to text via mark tubes)'
      '    GET /kids/path/             — list immediate files + subdirs as JSON {files:[], dirs:[]}'
      '    GET /tree/path/             — recursive tree as JSON'
      '    GET /sand/path/             — directory permissions as JSON'
      '    GET /weir/path/             — single directory access rule as JSON'
      '    GET /keep/path/             — subscribe to changes (long-lived, streams updates into chat)'
      ''
      '  WRITE endpoints (body = text content or JSON):'
      '    PUT /file/path/to/name.ext  — create new file (body = content, mark detected from extension)'
      '    POST /over/path/to/name.ext — overwrite existing file (body = new content)'
      '    DELETE /file/path/to/name.ext — delete file'
      '    PUT /dir/path/              — create directory'
      '    DELETE /dir/path/           — delete directory'
      '    POST /poke/path/to/name.ext — poke file process (body = payload)'
      '    POST /diff/path/to/name.ext — diff file (body = diff payload)'
      '    PUT /weir/path/             — set directory access rule (body = weir JSON)'
      '    DELETE /weir/path/          — clear directory access rule'
      ''
      '  API calls are asynchronous. Results arrive as <api> messages in the conversation.'
      '  One-shot calls (file, kids, tree, etc.) return a single result.'
      '  GET /keep/ is long-lived — it streams updates (new/upd/del) as they happen.'
      '  Keep messages use prefixes: "old" (initial), "upd" (changed), "new" (created), "del" (deleted).'
      ''
      '  ASYNC PATTERN: With continue="false", you can fire an API call then <wait/> for the result.'
      '  With continue="true" (default), you get a turn immediately — the result arrives later as a'
      '  separate <api> message in the conversation. Use continue="false" + <wait/> when you need the'
      '  result before proceeding. Use continue="true" when you want to keep working while it loads.'
      '<notify continue="true">payload</notify>'
      '  Sends a notification to listeners (subscriptions, agents, etc). Fire-and-forget.'
      '<message>Text shown to the user. Pauses until the user responds or an event arrives.</message>'
      '<wait/>'
      '  Pause without showing anything. Resumes when an event arrives.'
      '<done>Optional final output (JSON or text). Ends the session permanently.</done>'
      ''
      'CONTINUE ATTRIBUTE:'
      '  <tool>, <api>, and <notify> accept continue="true" (default) or continue="false".'
      '  continue="true": you get another turn immediately. API/tool results arrive later as messages.'
      '  continue="false": pause until the user sends a message or an event (like an API result) arrives.'
      ''
      'RULES:'
      '- CRITICAL: Your ENTIRE response must be exactly ONE XML tag. Nothing before it, nothing after it.'
      '- Do NOT combine multiple tags in one response. If you want to think then respond,'
      '  send <thought> ONLY. You will get another turn where you can send <message>.'
      '- <thought> always gives you another turn immediately.'
      '- <tool>, <api>, <notify> with continue="true" give you another turn after the response.'
      '  With continue="false" they pause like <message>.'
      '- After your action is processed, the system injects a <continue/> message into the'
      '  conversation to hand you the next turn. The user does not send these — the system does.'
      '  They are visible in the chat log as protocol markers.'
      '- <message>, <wait>, and <done> always pause or end.'
      '- If you need to think before acting, use <thought> first, then respond on your next turn.'
      '- IMPORTANT: Do not chain more than 2-3 thoughts in a row. After thinking, send a <message>.'
      '  The system enforces a thought cap - after 5 consecutive thoughts, your next response'
      '  MUST be a <message>, <wait>, or <done>.'
      '- For tool calls, use the exact tool names and argument formats provided.'
  ==
::  Dispatch API call: parse method + path, execute, return result text
::  Path format: /endpoint/rest... (e.g. /file/config.json, /kids/, /tree/)
::
++  dispatch-api
  |=  [method=@t api-path=@t body=@t]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  path-tape=tape  (trip api-path)
  =/  segs=(list @t)
    %+  turn
      (skip (split path-tape '/') |=(t=tape =(~ t)))
    crip
  ?~  segs
    %-  pure:m
    'ERROR: Empty path. Use /file/..., /kids/..., /tree/..., /dir/..., /over/..., /poke/..., /diff/..., /sand/..., /weir/..., /keep/...'
  =/  endpoint=@t   i.segs
  =/  rest=path      (turn t.segs |=(s=@t `@ta`s))
  =/  meth=@t  (crip (cuss (trip method)))
  ?+    [meth endpoint]
      %-  pure:m
      %-  crip
      """
      ERROR: {(trip meth)} /{(trip endpoint)} is not a valid endpoint.
      Path must start with an endpoint prefix. Valid endpoints:
        GET /file/...  GET /kids/...  GET /tree/...  GET /sand/...  GET /weir/...  GET /keep/...
        PUT /file/...  PUT /dir/...  PUT /weir/...
        POST /over/...  POST /poke/...  POST /diff/...
        DELETE /file/...  DELETE /dir/...  DELETE /weir/...
      You sent: {(trip meth)} {(trip api-path)}
      """
  ::  GET /file/... — read a file
      [%'GET' %'file']
    ?~  rest
      (pure:m 'ERROR: File path required (e.g. /file/config.json)')
    =/  parent=path  (snip `path`rest)
    =/  name=@ta     (rear rest)
    =/  =road:tarball  [%& %& parent name]
    ;<  =seen:nexus  bind:m  (peek:io /api-read road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    (cage-to-txt cage.p.seen)
  ::  GET /kids/... — list files + subdirs
      [%'GET' %'kids']
    =/  dir-road=road:tarball  [%& %| rest]
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-kids dir-road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  b=ball:tarball  ball.p.dir-seen
    =/  files=(list @ta)
      ?~(fil.b ~ ~(tap in ~(key by contents.u.fil.b)))
    =/  dirs=(list @ta)  ~(tap in ~(key by dir.b))
    =/  result=json
      %-  pairs:enjs:format
      :~  ['files' [%a (turn files |=(n=@ta s+n))]]
          ['dirs' [%a (turn dirs |=(n=@ta s+n))]]
      ==
    (pure:m (en:json:html result))
  ::  GET /tree/... — recursive tree
      [%'GET' %'tree']
    =/  dir-road=road:tarball  [%& %| rest]
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-tree dir-road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    (pure:m (en:json:html (tree-to-json:tarball (ball-to-tree:tarball ball.p.dir-seen))))
  ::  PUT /file/... — create file (body is content)
      [%'PUT' %'file']
    ?~  rest
      (pure:m 'ERROR: File path required')
    =/  parent=path  (snip `path`rest)
    =/  name=@ta     (rear rest)
    =/  =road:tarball  [%& %& parent name]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?:  exists
      (pure:m (crip "ERROR: Already exists: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (make:io /api-make road |+[%.n mime+!>(mime) ~])
    (pure:m (crip "Created {(trip api-path)}"))
  ::  POST /over/... — overwrite file (body is content)
      [%'POST' %'over']
    ?~  rest
      (pure:m 'ERROR: File path required')
    =/  parent=path  (snip `path`rest)
    =/  name=@ta     (rear rest)
    =/  =road:tarball  [%& %& parent name]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (over:io /api-over road mime+!>(mime))
    (pure:m (crip "Wrote {(trip api-path)}"))
  ::  DELETE /file/... — delete file
      [%'DELETE' %'file']
    ?~  rest
      (pure:m 'ERROR: File path required')
    =/  parent=path  (snip `path`rest)
    =/  name=@ta     (rear rest)
    =/  =road:tarball  [%& %& parent name]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    ;<  ~  bind:m  (cull:io /api-cull road)
    (pure:m (crip "Deleted {(trip api-path)}"))
  ::  PUT /dir/... — create directory
      [%'PUT' %'dir']
    ?~  rest
      (pure:m 'ERROR: Directory path required')
    =/  dir-road=road:tarball  [%& %| rest]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk dir-road)
    ?:  exists
      (pure:m (crip "ERROR: Already exists: {(trip api-path)}"))
    ;<  ~  bind:m  (make:io /api-make dir-road &+[*sand:nexus *gain:nexus `[~ ~ ~] ~])
    (pure:m (crip "Created directory {(trip api-path)}"))
  ::  DELETE /dir/... — delete directory
      [%'DELETE' %'dir']
    ?~  rest
      (pure:m 'ERROR: Directory path required')
    =/  dir-road=road:tarball  [%& %| rest]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk dir-road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    ;<  ~  bind:m  (cull:io /api-cull dir-road)
    (pure:m (crip "Deleted directory {(trip api-path)}"))
  ::  POST /poke/... — poke file process
      [%'POST' %'poke']
    ?~  rest
      (pure:m 'ERROR: File path required')
    =/  parent=path  (snip `path`rest)
    =/  name=@ta     (rear rest)
    =/  =road:tarball  [%& %& parent name]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (poke:io /api-poke road mime+!>(mime))
    (pure:m (crip "Poked {(trip api-path)}"))
  ::  POST /diff/... — diff file
      [%'POST' %'diff']
    ?~  rest
      (pure:m 'ERROR: File path required')
    =/  parent=path  (snip `path`rest)
    =/  name=@ta     (rear rest)
    =/  =road:tarball  [%& %& parent name]
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (diff:io /api-diff road mime+!>(mime))
    (pure:m (crip "Diffed {(trip api-path)}"))
  ::  GET /sand/... — directory permissions
      [%'GET' %'sand']
    =/  dir-road=road:tarball  [%& %| rest]
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-sand dir-road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    (pure:m (en:json:html (sand-to-json:nexus sand.p.dir-seen)))
  ::  GET /weir/... — single directory weir
      [%'GET' %'weir']
    =/  dir-road=road:tarball  [%& %| rest]
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-weir dir-road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =weir:nexus  (fall fil.sand.p.dir-seen *weir:nexus)
    (pure:m (en:json:html (weir-to-json:nexus weir)))
  ::  PUT /weir/... — replace weir
      [%'PUT' %'weir']
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      (pure:m 'ERROR: Invalid JSON body')
    =/  parsed=(each weir:nexus tang)
      (mule |.((weir-from-json:nexus u.jon)))
    ?:  ?=(%| -.parsed)
      (pure:m 'ERROR: Invalid weir JSON')
    ;<  ~  bind:m  (sand:io /api-weir [%& %| rest] `p.parsed)
    (pure:m (crip "Set weir for {(trip api-path)}"))
  ::  DELETE /weir/... — clear weir
      [%'DELETE' %'weir']
    ;<  ~  bind:m  (sand:io /api-weir [%& %| rest] ~)
    (pure:m (crip "Cleared weir for {(trip api-path)}"))
  ==
::  Dispatch keep: long-lived subscription, pokes changes to conversation
::
++  dispatch-keep
  |=  [msg-road=road:tarball api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  Determine road: check if path points to a file or directory
  =/  file-road=(unit road:tarball)
    ?~  api-path  ~
    `[%& %& (snip `path`api-path) (rear api-path)]
  ;<  is-file=?  bind:m
    ?~  file-road  (pure:(fiber:fiber:nexus ,?) %.n)
    (peek-exists:io /check u.file-road)
  =/  =road:tarball
    ?:  is-file  (need file-road)
    [%& %| api-path]
  ::  Subscribe — keep:io returns initial view
  ;<  init=view:nexus  bind:m  (keep:io /keep road ~)
  =/  prev-born=born:nexus
    ?.  ?=([%ball *] init)  *born:nexus
    born.init
  ::  Poke initial state
  ;<  ~  bind:m
    ?+  init  (pure:m ~)
        [%file *]
      ;<  content=@t  bind:m  (cage-to-txt cage.init)
      =/  file-name=@t
        ?~(api-path '/' (rear api-path))
      =/  msg=@t  (rap 3 ~['<api>old ' file-name ': ' content '</api>'])
      (poke:io /init msg-road claude-action+!>(`action`[%say msg]))
        [%ball *]
      (poke-ball-init msg-road ball.init born.init / api-path)
    ==
  ::  Event loop — wait for changes, poke each one
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /keep)
  ?-    -.nw
      %wake  $  ::  keep-alive, just continue
      %news
    ?+    view.nw  $
        [%file *]
      ;<  content=@t  bind:m  (cage-to-txt cage.view.nw)
      =/  file-name=@t
        ?~(api-path '/' (rear api-path))
      =/  msg=@t  (rap 3 ~['<api>upd ' file-name ': ' content '</api>'])
      ;<  ~  bind:m
        (poke:io /upd msg-road claude-action+!>(`action`[%say msg]))
      $
        [%ball *]
      =/  root=ball:tarball  ball.view.nw
      =/  root-born=born:nexus  born.view.nw
      =/  what=(set lane:tarball)  (diff-born-state:nexus prev-born root-born)
      =/  old-born=born:nexus  prev-born
      =.  prev-born  root-born
      =/  lanes=(list lane:tarball)  ~(tap in what)
      |-
      ?~  lanes  ^$
      ?:  ?=(%| -.i.lanes)
        $(lanes t.lanes)
      =/  file-path=path  path.p.i.lanes
      =/  file-name=@ta  name.p.i.lanes
      =/  lane-path=@t  (spat (snoc file-path file-name))
      ::  Get content from ball
      =/  sub=ball:tarball  (~(dip ba:tarball root) file-path)
      =/  ct=(unit content:tarball)
        ?~  fil.sub  ~
        (~(get by contents.u.fil.sub) file-name)
      ?~  ct
        ::  File deleted
        =/  msg=@t  (rap 3 ~['<api>del ' lane-path '</api>'])
        ;<  ~  bind:m
          (poke:io /del msg-road claude-action+!>(`action`[%say msg]))
        $(lanes t.lanes)
      ::  File new or updated
      =/  old-sub=born:nexus  (~(dip of old-born) file-path)
      =/  old-sack=(unit sack:nexus)
        ?~  fil.old-sub  ~
        (~(get by bags.u.fil.old-sub) file-name)
      =/  act=@t  ?~(old-sack 'new' 'upd')
      ;<  content=@t  bind:m  (cage-to-txt cage.u.ct)
      =/  msg=@t
        %+  rap  3
        :~  '<api>'
            act  ' '  lane-path
            ': '  content  '</api>'
        ==
      ;<  ~  bind:m
        (poke:io /upd msg-road claude-action+!>(`action`[%say msg]))
      $(lanes t.lanes)
    ==
  ==
::  Poke initial state for a directory subscription
::
++  poke-ball-init
  |=  [msg-road=road:tarball b=ball:tarball =born:nexus here=path api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  Files in this directory
  ;<  ~  bind:m
    ?~  fil.b  (pure:m ~)
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.b)
    |-
    ?~  files  (pure:m ~)
    =/  [file-name=@ta =content:tarball]  i.files
    =/  lane-path=@t  (spat (snoc here file-name))
    ;<  content-text=@t  bind:m  (cage-to-txt cage.content)
    =/  msg=@t  (rap 3 ~['<api>old ' lane-path ': ' content-text '</api>'])
    ;<  ~  bind:m
      (poke:io /init msg-road claude-action+!>(`action`[%say msg]))
    $(files t.files)
  ::  Recurse into subdirectories
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
  |-
  ?~  dirs  (pure:m ~)
  =/  [dir-name=@ta sub=ball:tarball]  i.dirs
  ;<  ~  bind:m  (poke-ball-init msg-road sub born (snoc here dir-name) api-path)
  $(dirs t.dirs)
::  Convert a cage to text — uses mark tubes, falls back to mime
::
++  cage-to-txt
  |=  =cage
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ?:  =(%txt p.cage)
    (pure:m (of-wain:format !<(wain q.cage)))
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [p.cage %txt])
  ?~  tube
    ::  Fallback: convert to mime and extract body as text
    ;<  =mime  bind:m  (cage-to-mime:io cage)
    (pure:m `@t`(end [3 p.q.mime] q.q.mime))
  =/  result=(each vase tang)  (mule |.((u.tube q.cage)))
  ?:  ?=(%| -.result)
    ;<  =mime  bind:m  (cage-to-mime:io cage)
    (pure:m `@t`(end [3 p.q.mime] q.q.mime))
  (pure:m (of-wain:format !<(wain p.result)))
::
::  Split a tape on a delimiter character
::
++  split
  |=  [t=tape d=@t]
  ^-  (list tape)
  =|  [acc=(list tape) cur=tape]
  |-
  ?~  t  (flop [cur acc])
  ?:  =(i.t d)
    $(t t.t, acc [cur acc], cur ~)
  $(t t.t, cur (snoc cur i.t))
::
++  jget-t
  |=  [j=json key=@t default=@t]
  ^-  @t
  ?.  ?=([%o *] j)  default
  =/  v=(unit json)  (~(get by p.j) key)
  ?~  v  default
  ?.  ?=([%s *] u.v)  default
  p.u.v
::
++  jget-n
  |=  [j=json key=@t default=@ud]
  ^-  @ud
  ?.  ?=([%o *] j)  default
  =/  v=(unit json)  (~(get by p.j) key)
  ?~  v  default
  ?.  ?=([%n *] u.v)  default
  (fall (rush p.u.v dem) default)
::
++  jget-tu
  |=  [j=json key=@t]
  ^-  (unit @t)
  ?.  ?=([%o *] j)  ~
  =/  v=(unit json)  (~(get by p.j) key)
  ?~  v  ~
  ?.  ?=([%s *] u.v)  ~
  `p.u.v
::
::  Build SSE JSON for a message — every message emits
::  Includes role (user/assistant) + type tag + content
::
++  sse-json
  |=  =message
  ^-  json
  =/  rol=@t  role.message
  =/  raw=@t  content.message
  ::  detect protocol wrappers on either role
  ?:  =('<continue/>' raw)
    %-  pairs:enjs:format
    ~[['role' s+rol] ['type' s+'continue'] ['content' s+'']]
  ?:  =((end [3 7] raw) '<error>')
    %-  pairs:enjs:format
    ~[['role' s+rol] ['type' s+'error'] ['content' s+(extract-inner raw)]]
  ?:  &(=('user' rol) =((end [3 6] raw) '<tool>'))
    %-  pairs:enjs:format
    ~[['role' s+'user'] ['type' s+'tool'] ['content' s+(extract-inner raw)]]
  ?:  &(=('user' rol) =((end [3 5] raw) '<api>'))
    %-  pairs:enjs:format
    ~[['role' s+'user'] ['type' s+'api'] ['content' s+(extract-inner raw)]]
  ?:  &(=('user' rol) =((end [3 8] raw) '<notify>'))
    %-  pairs:enjs:format
    ~[['role' s+'user'] ['type' s+'notify'] ['content' s+(extract-inner raw)]]
  ::  user messages — plain text
  ?:  =('user' rol)
    %-  pairs:enjs:format
    ~[['role' s+'user'] ['type' s+'message'] ['content' s+raw]]
  ::  assistant messages — parse XML protocol tag
  =/  tag=(unit response-tag)  (parse-response raw)
  ?~  tag
    ::  unparseable — show as message
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'message'] ['content' s+raw]]
  ?-  -.u.tag
      %thought
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'thought'] ['content' s+text.u.tag]]
      %message
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'message'] ['content' s+text.u.tag]]
      %tool
    =/  names=@t
      %+  roll  calls.u.tag
      |=  [tc=tool-call acc=@t]
      ?:(=('' acc) name.tc (cat 3 acc (cat 3 ', ' name.tc)))
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'tool'] ['content' s+names]]
      %api
    =/  summary=@t  (rap 3 ~[(crip (cuss (trip method.u.tag))) ' ' path.u.tag])
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'api'] ['content' s+summary]]
      %notify
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'notify'] ['content' s+text.u.tag]]
      %wait
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'wait'] ['content' s+'']]
      %done
    %-  pairs:enjs:format
    ~[['role' s+'assistant'] ['type' s+'done'] ['content' s+output.u.tag]]
  ==
::  Trim leading and trailing whitespace from a tape
::
++  trim-tape
  |=  t=tape
  ^-  tape
  =|  ws=(set @t)
  =.  ws  (silt ~[' ' '\09' '\0a' '\0d'])
  ::  trim leading
  |-
  ?~  t  ~
  ?.  (~(has in ws) i.t)
    ::  trim trailing
    =/  r=tape  (flop t)
    |-
    ?~  r  ~
    ?.  (~(has in ws) i.r)
      (flop r)
    $(r t.r)
  $(t t.t)
::  Append a message to the mop and save
::
++  append-msg
  |=  [msg=messages role=@t content=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  idx=@ud
    =/  top  (ram:mon messages.msg)
    ?~(top 0 +(key.u.top))
  =/  new=messages  msg(messages (put:mon messages.msg idx [role content]))
  (replace:io !>(new))
::  Extract inner text from an XML tag like <error>text</error>
::
++  extract-inner
  |=  raw=@t
  ^-  @t
  =/  t=tape  (trip raw)
  =/  gt=(unit @ud)  (find ">" t)
  ?~  gt  raw
  =/  after=tape  (slag +(u.gt) t)
  =/  lt=(unit @ud)  (find "</" after)
  ?~  lt  (crip after)
  (crip (scag u.lt after))
::  Parse Claude's XML-tagged response into a $response-tag
::
++  parse-response
  |=  reply=@t
  ^-  (unit response-tag)
  =/  t=tape  (trim-tape (trip reply))
  ::  <wait/> or <wait />
  ?:  ?|  =("<wait/>" t)
          =("<wait />" t)
      ==
    `[%wait ~]
  ::  Check for self-closing <api ... /> first
  ?:  &(=('<' (snag 0 t)) =('>' (snag (dec (lent t)) t)) =('/' (snag (sub (lent t) 2) t)))
    =/  tag-str=tape  (slag 1 (scag (sub (lent t) 2) t))
    =/  tag-name=tape
      =/  sp=(unit @ud)  (find " " tag-str)
      ?~(sp tag-str (scag u.sp tag-str))
    ?:  =("api" tag-name)     (parse-api-tag tag-str '')
    ?:  =("notify" tag-name)  `[%notify '' (parse-continue tag-str)]
    ~
  ::  Match <tag>content</tag> pattern
  =/  open=(unit @ud)  (find "<" t)
  ?~  open  ~
  =/  close-bracket=(unit @ud)  (find ">" (slag u.open t))
  ?~  close-bracket  ~
  =/  tag-end=@ud  (add u.open +(u.close-bracket))
  =/  tag-str=tape  (slag +(u.open) (scag (dec tag-end) t))
  ::  strip attributes if any
  =/  tag-name=tape
    =/  sp=(unit @ud)  (find " " tag-str)
    ?~  sp  tag-str
    (scag u.sp tag-str)
  ::  find closing tag
  =/  close-tag=tape  "</{tag-name}>"
  =/  close-pos=(unit @ud)  (find close-tag t)
  ?~  close-pos  ~
  ::  extract inner content (everything between open and close tags)
  =/  inner=@t  (crip (scag (sub u.close-pos tag-end) (slag tag-end t)))
  ?:  =("thought" tag-name)  `[%thought inner]
  ?:  =("message" tag-name)  `[%message inner]
  ?:  =("done" tag-name)     `[%done inner]
  ?:  =("tool" tag-name)     (parse-tool-tag tag-str inner)
  ?:  =("api" tag-name)      (parse-api-tag tag-str inner)
  ?:  =("notify" tag-name)   `[%notify inner (parse-continue tag-str)]
  ~
::  Parse <tool> tag content as JSON tool calls
::
++  parse-tool-tag
  |=  [tag-str=tape text=@t]
  ^-  (unit response-tag)
  =/  cont=?  (parse-continue tag-str)
  =/  jon=(unit json)  (de:json:html text)
  ?~  jon  ~
  ?:  ?=([%a *] u.jon)
    ::  Array of tool calls
    =/  calls=(list tool-call)
      %+  murn  p.u.jon
      |=  j=json
      (parse-one-tool j)
    ?~  calls  ~
    `[%tool calls cont]
  ::  Single tool call object
  =/  call=(unit tool-call)  (parse-one-tool u.jon)
  ?~  call  ~
  `[%tool ~[u.call] cont]
::
++  parse-one-tool
  |=  j=json
  ^-  (unit tool-call)
  ?.  ?=([%o *] j)  ~
  =/  name=(unit json)  (~(get by p.j) 'name')
  ?.  ?=([~ %s *] name)  ~
  =/  args=(unit json)  (~(get by p.j) 'args')
  =/  args-t=@t  ?~(args '{}' (en:json:html u.args))
  `[p.u.name args-t]
::
::  Parse <api> tag: extract method and path attributes
::
++  parse-api-tag
  |=  [tag-str=tape body=@t]
  ^-  (unit response-tag)
  =/  method=@t  (get-attr tag-str "method")
  =/  path=@t    (get-attr tag-str "path")
  ?:  |(=('' method) =('' path))  ~
  `[%api method path body (parse-continue tag-str)]
::  Extract an attribute value from a tag string
::  e.g. (get-attr "api method=\"GET\" path=\"/foo\"" "method") -> 'GET'
::
++  get-attr
  |=  [tag-str=tape attr=tape]
  ^-  @t
  =/  key=tape  (weld attr "=\"")
  =/  pos=(unit @ud)  (find key tag-str)
  ?~  pos  ''
  =/  val-start=tape  (slag (add u.pos (lent key)) tag-str)
  =/  end=(unit @ud)  (find "\"" val-start)
  ?~  end  ''
  (crip (scag u.end val-start))
::  Parse continue attribute: defaults to true
::
++  parse-continue
  |=  tag-str=tape
  ^-  ?
  =/  val=@t  (get-attr tag-str "continue")
  ?.  =('false' val)  %.y
  %.n
::
++  extract-error
  |=  response=@t
  ^-  (unit @t)
  =/  res-json=(unit json)  (de:json:html response)
  ?~  res-json  `'Could not parse API response'
  ?.  ?=([%o *] u.res-json)  ~
  =/  type=(unit json)  (~(get by p.u.res-json) 'type')
  ?.  ?=([~ %s %'error'] type)  ~
  =/  error=(unit json)  (~(get by p.u.res-json) 'error')
  ?~  error  `'API error (no details)'
  ?.  ?=([%o *] u.error)  `'API error (no details)'
  =/  msg=(unit json)  (~(get by p.u.error) 'message')
  =/  typ=(unit json)  (~(get by p.u.error) 'type')
  =/  msg-t=@t  ?:(?=([~ %s *] msg) p.u.msg 'unknown error')
  =/  typ-t=@t  ?:(?=([~ %s *] typ) p.u.typ 'error')
  `(crip "Claude API {(trip typ-t)}: {(trip msg-t)}")
::
++  extract-reply
  |=  response=@t
  ^-  @t
  =/  res-json=(unit json)  (de:json:html response)
  ?~  res-json  ''
  =/  content-blocks=(unit json)
    ?.  ?=([%o *] u.res-json)  ~
    (~(get by p.u.res-json) 'content')
  ?~  content-blocks  ''
  ?.  ?=([%a *] u.content-blocks)  ''
  =/  texts=(list @t)
    %+  murn  p.u.content-blocks
    |=  block=json
    ?.  ?=([%o *] block)  ~
    =/  type=(unit json)  (~(get by p.block) 'type')
    ?.  ?=([~ %s %'text'] type)  ~
    =/  text=(unit json)  (~(get by p.block) 'text')
    ?~  text  ~
    ?.  ?=([%s *] u.text)  ~
    `p.u.text
  ?~  texts  ''
  (rap 3 texts)
::
++  chat-page
  |=  msgs=(list [idx=@ud =message])
  ^-  manx
  =/  api=tape  "/grubbery/api"
  =/  base=tape  "claude.claude"
  =/  sp-json=tape  (trip (en:json:html s+system-prompt))
  =/  js=tape
    ;:  weld
      "var API='{api}',BASE='{base}',SYSTEM_PROMPT={sp-json};"
      "var box=document.getElementById('messages'),input=document.getElementById('input'),form=document.getElementById('form');"
      "function scrollBottom()\{box.scrollTop=box.scrollHeight}"
      "setTimeout(scrollBottom,100);setTimeout(scrollBottom,300);window.addEventListener('load',scrollBottom);"
      "function esc(s)\{var d=document.createElement('div');d.textContent=s;return d.innerHTML}"
      "function addMsg(role,content,type)\{var d=document.createElement('div');var t=type||'message';d.className='msg '+t+' '+role;var label='<b>'+esc(role)+'</b>';if(t==='continue'||t==='wait')\{d.innerHTML=label+'<span class=\\'sub\\'>'+esc(t)+'</span>'}else\{d.innerHTML=label+(t!=='message'?'<span class=\\'sub\\'>'+esc(t)+'</span>':'')+'<pre>'+esc(content)+'</pre>'}box.appendChild(d);scrollBottom()}"
      "function showError(msg)\{var d=document.createElement('div');d.className='msg error';d.innerHTML='<b>system</b><span class=\\'sub\\'>error</span><pre>'+esc(msg)+'</pre>';box.appendChild(d);scrollBottom()}"
      "function autoResize()\{input.style.height='auto';input.style.height=input.scrollHeight+'px'}"
      "input.addEventListener('input',autoResize);"
      "input.addEventListener('keydown',function(e)\{if(e.key==='Enter'&&!e.shiftKey)\{e.preventDefault();form.dispatchEvent(new Event('submit'))}});"
      "form.onsubmit=async function(e)\{e.preventDefault();var t=input.value.trim();if(!t)return;input.value='';autoResize();var r=await fetch(API+'/poke/'+BASE+'/messages.claude-messages?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{text:t})});if(!r.ok)\{var err=await r.text();showError(r.status+': '+err)}};"
      "function onLastMsg(e)\{try\{var m=JSON.parse(e.data);if(m.role)addMsg(m.role,m.content||'',m.type)}catch(x)\{}}"
      "function connect()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/last-message.json?mark=json');es.addEventListener('upd last-message.json',onLastMsg);es.onerror=function()\{es.close();setTimeout(connect,2000)}}"
      "function onStatus(e)\{try\{var s=JSON.parse(e.data);var el=document.getElementById('loading');if(s.loading)\{el.classList.add('active')}else\{el.classList.remove('active')}}catch(x)\{}}"
      "function connectStatus()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/status.json?mark=json');es.addEventListener('upd status.json',onStatus);es.onerror=function()\{es.close();setTimeout(connectStatus,2000)}}"
    "document.querySelectorAll('#filters input').forEach(function(cb)\{cb.addEventListener('change',function()\{var t=this.getAttribute('data-type');var r=this.getAttribute('data-role');var cls='hide-'+r+'-'+t;if(this.checked)\{box.classList.remove(cls)}else\{box.classList.add(cls)}})});"
    "var backdrop=document.getElementById('modal-backdrop'),editor=document.getElementById('prompt-editor'),sysDiv=document.getElementById('prompt-system'),saveBtn=document.getElementById('prompt-save');"
    "document.getElementById('prompt-btn').onclick=async function()\{backdrop.classList.add('open');sysDiv.textContent=SYSTEM_PROMPT;try\{var r=await fetch(API+'/file/'+BASE+'/custom-prompt.txt?mark=txt');editor.value=r.ok?await r.text():''}catch(e)\{editor.value=''}};"
    "document.getElementById('prompt-close').onclick=function()\{backdrop.classList.remove('open')};"
    "backdrop.onclick=function(e)\{if(e.target===backdrop)backdrop.classList.remove('open')};"
    "saveBtn.onclick=async function()\{try\{var r=await fetch(API+'/over/'+BASE+'/custom-prompt.txt?mark=txt',\{method:'POST',body:editor.value});if(r.ok)\{backdrop.classList.remove('open')}else\{alert('Save failed: '+r.status)}}catch(e)\{alert('Save failed: '+e.message)}};"
    "document.querySelectorAll('#modal-tabs button').forEach(function(btn)\{btn.onclick=function()\{document.querySelectorAll('#modal-tabs button').forEach(function(b)\{b.classList.remove('active')});document.querySelectorAll('.tab-pane').forEach(function(p)\{p.classList.remove('active')});btn.classList.add('active');document.getElementById('tab-'+btn.getAttribute('data-tab')).classList.add('active');saveBtn.style.display=btn.getAttribute('data-tab')==='custom'?'':'none'}});"
    "connect();connectStatus();"
    ==
  ;html
    ;head
      ;title: Claude Chat
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  ;:  weld
          "* \{ box-sizing: border-box; margin: 0; padding: 0; } "
          "body \{ font-family: monospace; max-width: 800px; margin: 0 auto; padding: 1rem; height: 100vh; display: flex; flex-direction: column; } "
          "h1 \{ margin-bottom: 1rem; font-size: 1.2rem; } "
          "#messages \{ flex: 1; overflow-y: auto; border: 1px solid #ccc; border-radius: 4px; padding: 1rem; margin-bottom: 1rem; } "
          ".msg \{ margin-bottom: 1rem; } "
          ".msg b \{ display: inline; text-transform: uppercase; font-size: 0.7rem; opacity: 0.5; } "
          ".msg .sub \{ font-size: 0.65rem; opacity: 0.4; margin-left: 0.5rem; text-transform: uppercase; } "
          ".msg header \{ margin-bottom: 0.25rem; } "
          ".msg pre \{ white-space: pre-wrap; word-wrap: break-word; font-family: monospace; font-size: 0.9rem; line-height: 1.4; } "
          ".msg.message pre \{ background: #f5f5f5; padding: 0.5rem; border-radius: 4px; } "
          ".msg.thought \{ opacity: 0.5; } "
          ".msg.thought pre \{ background: #f0f0ff; padding: 0.5rem; border-radius: 4px; font-style: italic; } "
          ".msg.tool pre \{ background: #f0fff0; padding: 0.5rem; border-radius: 4px; } "
          ".msg.tool b \{ color: #060; } "
          ".msg.done pre \{ background: #fff8e0; padding: 0.5rem; border-radius: 4px; } "
          ".msg.continue \{ opacity: 0.3; font-size: 0.7rem; } "
          ".msg.wait \{ opacity: 0.3; font-size: 0.7rem; } "
          ".msg.result pre \{ background: #e8f4fd; padding: 0.5rem; border-radius: 4px; } "
          ".msg.result b \{ color: #036; } "
          ".msg.api pre \{ background: #f0f0ff; padding: 0.5rem; border-radius: 4px; } "
          ".msg.api b \{ color: #449; } "
          ".msg.notify pre \{ background: #fff5e6; padding: 0.5rem; border-radius: 4px; } "
          ".msg.notify b \{ color: #964; } "
          ".msg.error pre \{ background: #fee; padding: 0.5rem; border-radius: 4px; color: #c00; } "
          ".msg.error b \{ color: #c00; } "
          "#form \{ display: flex; gap: 0.5rem; align-items: flex-end; } "
          "#input \{ flex: 1; padding: 0.5rem; border: 1px solid #ccc; border-radius: 4px; font-family: monospace; font-size: 0.9rem; resize: none; overflow-y: auto; min-height: 2.2rem; max-height: 10rem; } "
          "#form button \{ padding: 0.5rem 1rem; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; font-family: monospace; } "
          "#form button:hover \{ background: #eee; } "
          "#loading \{ height: 2px; background: transparent; margin-bottom: 0.5rem; overflow: hidden; } "
          "#loading.active \{ background: #e0e0e0; } "
          "#loading.active::after \{ content: ''; display: block; height: 100%; width: 30%; background: #666; animation: slide 1s ease-in-out infinite; } "
          "@keyframes slide \{ 0% \{ transform: translateX(-100%) } 100% \{ transform: translateX(400%) } } "
          "#filters \{ margin-bottom: 0.75rem; } "
          ".filter-row \{ display: flex; gap: 0.25rem; align-items: center; margin-bottom: 0.25rem; } "
          ".filter-label \{ font-size: 0.6rem; font-family: monospace; text-transform: uppercase; opacity: 0.3; width: 4.5rem; } "
          "#filters label \{ font-size: 0.65rem; font-family: monospace; text-transform: uppercase; opacity: 0.5; cursor: pointer; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; user-select: none; } "
          "#filters label:hover \{ opacity: 0.8; } "
          "#filters input \{ display: none; } "
          "#filters input:checked + span \{ opacity: 1; } "
          "#filters input:not(:checked) + span \{ text-decoration: line-through; } "
          ".hide-assistant-message .msg.message.assistant, .hide-assistant-thought .msg.thought.assistant, .hide-assistant-tool .msg.tool.assistant, .hide-assistant-api .msg.api.assistant, .hide-assistant-notify .msg.notify.assistant, .hide-assistant-wait .msg.wait.assistant, .hide-assistant-done .msg.done.assistant, .hide-assistant-error .msg.error.assistant \{ display: none; } "
          ".hide-user-message .msg.message.user, .hide-user-error .msg.error.user, .hide-user-tool .msg.tool.user, .hide-user-api .msg.api.user, .hide-user-continue .msg.continue.user \{ display: none; } "
          "#header \{ display: flex; align-items: baseline; gap: 0.75rem; margin-bottom: 1rem; } "
          "#header h1 \{ margin-bottom: 0; } "
          "#prompt-btn \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; cursor: pointer; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; background: none; } "
          "#prompt-btn:hover \{ opacity: 0.8; } "
          "#modal-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.3); z-index: 100; } "
          "#modal-backdrop.open \{ display: flex; align-items: center; justify-content: center; } "
          "#modal \{ background: #fff; border: 1px solid #ccc; border-radius: 4px; width: 90%; max-width: 700px; height: 70vh; display: flex; flex-direction: column; padding: 1rem; } "
          "#modal-header \{ display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 0.75rem; } "
          "#modal-header span \{ font-family: monospace; font-size: 0.8rem; font-weight: bold; text-transform: uppercase; opacity: 0.5; } "
          "#modal-actions \{ display: flex; gap: 0.5rem; } "
          "#modal-actions button \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; padding: 0.2rem 0.5rem; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; background: none; } "
          "#modal-actions button:hover \{ background: #eee; } "
          "#modal-tabs \{ display: flex; gap: 0; margin-bottom: 0.75rem; border-bottom: 1px solid #ccc; } "
          "#modal-tabs button \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; padding: 0.3rem 0.6rem; border: 1px solid #ccc; border-bottom: none; border-radius: 3px 3px 0 0; cursor: pointer; background: #f5f5f5; opacity: 0.5; margin-bottom: -1px; } "
          "#modal-tabs button.active \{ background: #fff; opacity: 1; border-bottom: 1px solid #fff; } "
          "#modal-tabs button:hover \{ opacity: 0.8; } "
          ".tab-pane \{ display: none; flex: 1; min-height: 0; } "
          ".tab-pane.active \{ display: flex; flex-direction: column; flex: 1; } "
          "#prompt-system \{ flex: 1; font-family: monospace; font-size: 0.8rem; line-height: 1.5; border: 1px solid #e0e0e0; border-radius: 4px; padding: 0.5rem; background: #f8f8f8; color: #666; overflow-y: auto; white-space: pre-wrap; word-wrap: break-word; } "
          "#prompt-editor \{ flex: 1; font-family: monospace; font-size: 0.8rem; line-height: 1.5; border: 1px solid #ccc; border-radius: 4px; padding: 0.5rem; resize: none; } "
        ==
      ==
    ==
    ;body
      ;div#header
        ;h1: Claude Chat
        ;button#prompt-btn: prompt
      ==
      ;div#filters
        ;div(class "filter-row")
          ;span(class "filter-label"): assistant
          ;label
            ;input(type "checkbox", checked "", data-type "message", data-role "assistant");
            ;span: message
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "thought", data-role "assistant");
            ;span: thought
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "tool", data-role "assistant");
            ;span: tool
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "api", data-role "assistant");
            ;span: api
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "notify", data-role "assistant");
            ;span: notify
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "wait", data-role "assistant");
            ;span: wait
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "done", data-role "assistant");
            ;span: done
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "error", data-role "assistant");
            ;span: error
          ==
        ==
        ;div(class "filter-row")
          ;span(class "filter-label"): user
          ;label
            ;input(type "checkbox", checked "", data-type "message", data-role "user");
            ;span: message
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "tool", data-role "user");
            ;span: tool
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "api", data-role "user");
            ;span: api
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "continue", data-role "user");
            ;span: continue
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "error", data-role "user");
            ;span: error
          ==
        ==
      ==
      ;div#messages
        ;*  %+  murn  msgs
            |=  [idx=@ud =message]
            ^-  (unit manx)
            =/  role=tape  (trip role.message)
            ::  protocol messages (loading/continue/error/result)
            ?:  =('<continue/>' content.message)
              :-  ~
              ;div(class "msg continue {role}")
                ;b: {role}
                ;span(class "sub"): continue
              ==
            ?:  ?&  =('user' role.message)
                    =((end [3 1] content.message) '<')
                ==
              =/  tag-type=tape
                ?:  =((end [3 7] content.message) '<error>')   "error"
                ?:  =((end [3 6] content.message) '<tool>')    "tool"
                ?:  =((end [3 5] content.message) '<api>')     "api"
                ?:  =((end [3 8] content.message) '<notify>')  "notify"
                "message"
              =/  inner=tape  (trip (extract-inner content.message))
              :-  ~
              ;div(class "msg {tag-type} {role}")
                ;b: {role}
                ;span(class "sub"): {tag-type}
                ;pre: {inner}
              ==
            ::  [Error] messages
            =/  is-err=?  =((end [3 7] content.message) '[Error]')
            ?:  is-err
              :-  ~
              ;div(class "msg error {role}")
                ;b: {role}
                ;span(class "sub"): error
                ;pre: {(trip (rsh [3 8] content.message))}
              ==
            ::  non-assistant: show as-is
            ?.  =('assistant' role.message)
              :-  ~
              ;div(class "msg message {role}")
                ;b: {role}
                ;pre: {(trip content.message)}
              ==
            ::  assistant: check for <error>, then parse XML tag
            ?:  =((end [3 7] content.message) '<error>')
              :-  ~
              ;div(class "msg error assistant")
                ;b: assistant
                ;span(class "sub"): error
                ;pre: {(trip (extract-inner content.message))}
              ==
            =/  tag=(unit response-tag)  (parse-response content.message)
            ?~  tag
              :-  ~
              ;div(class "msg message assistant")
                ;b: assistant
                ;pre: {(trip content.message)}
              ==
            ?-  -.u.tag
                %thought
              :-  ~
              ;div(class "msg thought assistant")
                ;b: assistant
                ;span(class "sub"): thought
                ;pre: {(trip text.u.tag)}
              ==
                %message
              :-  ~
              ;div(class "msg message assistant")
                ;b: assistant
                ;pre: {(trip text.u.tag)}
              ==
                %tool
              =/  calls-text=tape
                %+  roll  calls.u.tag
                |=  [tc=tool-call acc=tape]
                (weld acc "{(trip name.tc)}({(trip args.tc)}) ")
              :-  ~
              ;div(class "msg tool assistant")
                ;b: assistant
                ;span(class "sub"): tool
                ;pre: {calls-text}
              ==
                %api
              =/  summary=tape
                "{(cuss (trip method.u.tag))} {(trip path.u.tag)}"
              :-  ~
              ;div(class "msg api assistant")
                ;b: assistant
                ;span(class "sub"): api
                ;pre: {summary}
              ==
                %notify
              :-  ~
              ;div(class "msg notify assistant")
                ;b: assistant
                ;span(class "sub"): notify
                ;pre: {(trip text.u.tag)}
              ==
                %wait
              :-  ~
              ;div(class "msg wait assistant")
                ;b: assistant
                ;span(class "sub"): wait
              ==
                %done
              :-  ~
              ;div(class "msg done assistant")
                ;b: assistant
                ;span(class "sub"): done
                ;pre: {(trip output.u.tag)}
              ==
            ==
      ==
      ;div#loading;
      ;form#form
        ;textarea#input(rows "1", placeholder "Type a message...");
        ;button(type "submit"): Send
      ==
      ;div#modal-backdrop
        ;div#modal
          ;div#modal-header
            ;span: Prompt
            ;div#modal-actions
              ;button#prompt-save: save
              ;button#prompt-close: close
            ==
          ==
          ;div#modal-tabs
            ;button(class "active", data-tab "system"): system
            ;button(data-tab "custom"): custom
          ==
          ;div(id "tab-system", class "tab-pane active")
            ;div#prompt-system;
          ==
          ;div(id "tab-custom", class "tab-pane")
            ;textarea#prompt-editor;
          ==
        ==
      ==
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
