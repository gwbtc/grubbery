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
      =?  ball  =(~ (~(get ba:tarball ball) [/ %'system-prompt.txt']))
        =/  default=wain
          :~  'You are Claude, an AI assistant running natively on an Urbit ship.'
              'Urbit is a peer-to-peer operating system. You run as a Hoon application on the user\'s personal server.'
              ''
              'PROTOCOL: Every response must be exactly ONE XML tag. Valid tags:'
              ''
              '<thought>Your internal reasoning. Not shown to user. You get another turn immediately.</thought>'
              '<tool>{"name":"tool_name","args":{"key":"value"}}</tool>'
              '  Executes a tool. You can include multiple calls: <tool>[{"name":"a","args":{}},{"name":"b","args":{}}]</tool>'
              '  Results stream back as <result> tags. You get another turn immediately.'
              '<message>Text shown to the user. Pauses until the user responds or an event arrives.</message>'
              '<wait/>'
              '  Pause without showing anything. Resumes when an event arrives (tool result, user message, etc).'
              '<done>Optional final output (JSON or text). Ends the session permanently.</done>'
              ''
              'RULES:'
              '- CRITICAL: Your ENTIRE response must be exactly ONE XML tag. Nothing before it, nothing after it.'
              '- Do NOT combine multiple tags in one response. If you want to think then respond,'
              '  send <thought> ONLY. You will get another turn where you can send <message>.'
              '- <thought> and <tool> give you another turn immediately. After your thought or tool'
              '  response is stored, the system injects a <continue/> user message to hand you the next turn.'
              '  When you see <continue/>, it means your previous action was processed and you should proceed.'
              '- <message>, <wait>, and <done> pause or end.'
              '- If you need to think before acting, use <thought> first, then respond on your next turn.'
              '- IMPORTANT: Do not chain more than 2-3 thoughts in a row. After thinking, send a <message>.'
              '  The system enforces a thought cap — after 5 consecutive thoughts, your next response'
              '  MUST be a <message>, <wait>, or <done>.'
              '- For tool calls, use the exact tool names and argument formats provided.'
          ==
        (~(put ba:tarball ball) [/ %'system-prompt.txt'] [~ %txt !>(default)])
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
        ?-  -.action
            %say
          ?:  =('' text.action)  $
          ~&  >  [%claude-chat %got-message text.action]
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
          ::  read system prompt + append dynamic context
          ;<  prompt-seen=seen:nexus  bind:m
            (peek:io /prompt (cord-to-road:tarball './system-prompt.txt') `%txt)
          ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
          =/  system=(unit @t)
            ?.  ?=([%& %file *] prompt-seen)  ~
            =/  =wain  !<(wain q.cage.p.prompt-seen)
            ?~  wain  ~
            =/  base=@t  (of-wain:format wain)
            =/  ship=@t  (scot %p our.bowl)
            =/  msg-count=@t  (crip (a-co:co (lent (tap:mon messages.msg))))
            :-  ~
            %+  rap  3
            :~  base
                '\0a\0aLIVE CONTEXT: Ship: '
                ship
                '. Current time: '
                (scot %da now.bowl)
                '. Messages in conversation: '
                msg-count
                '.'
            ==
          ::  build request — filter <error> messages from API payload
          =/  msgs-json=json
            :-  %a
            %+  murn  (tap:mon messages.msg)
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
            ~&  >  [%claude-tool (lent calls.u.tag) %calls]
            ::  TODO: execute tool calls, stream results back
            ;<  ~  bind:m  (sleep:io ~s0..0001)
            ;<  msg=messages  bind:m  (get-state-as:io ,messages)
            ;<  ~  bind:m  (append-msg msg 'user' '<result>Tool execution not yet implemented</result>')
            $(thinks 0)  ::  loop back for Claude to see result
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
        ==
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
  ?:  =((end [3 8] raw) '<result>')
    %-  pairs:enjs:format
    ~[['role' s+rol] ['type' s+'result'] ['content' s+(extract-inner raw)]]
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
  ?:  =("tool" tag-name)     (parse-tool-tag inner)
  ~
::  Parse <tool> tag content as JSON tool calls
::
++  parse-tool-tag
  |=  text=@t
  ^-  (unit response-tag)
  =/  jon=(unit json)  (de:json:html text)
  ?~  jon  ~
  ?:  ?=([%a *] u.jon)
    ::  Array of tool calls
    =/  calls=(list tool-call)
      %+  murn  p.u.jon
      |=  j=json
      (parse-one-tool j)
    ?~  calls  ~
    `[%tool calls]
  ::  Single tool call object
  =/  call=(unit tool-call)  (parse-one-tool u.jon)
  ?~  call  ~
  `[%tool ~[u.call]]
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
  =/  js=tape
    ;:  weld
      "var API='{api}',BASE='{base}';"
      "var box=document.getElementById('messages'),input=document.getElementById('input'),form=document.getElementById('form');"
      "function scrollBottom()\{box.scrollTop=box.scrollHeight}"
      "setTimeout(scrollBottom,100);setTimeout(scrollBottom,300);window.addEventListener('load',scrollBottom);"
      "function esc(s)\{var d=document.createElement('div');d.textContent=s;return d.innerHTML}"
      "function addMsg(role,content,type)\{var d=document.createElement('div');var t=type||'message';d.className='msg '+t;var label='<b>'+esc(role)+'</b>';if(t==='continue'||t==='wait')\{d.innerHTML=label+'<span class=\\'sub\\'>'+esc(t)+'</span>'}else\{d.innerHTML=label+(t!=='message'?'<span class=\\'sub\\'>'+esc(t)+'</span>':'')+'<pre>'+esc(content)+'</pre>'}box.appendChild(d);scrollBottom()}"
      "function showError(msg)\{var d=document.createElement('div');d.className='msg error';d.innerHTML='<b>system</b><span class=\\'sub\\'>error</span><pre>'+esc(msg)+'</pre>';box.appendChild(d);scrollBottom()}"
      "function autoResize()\{input.style.height='auto';input.style.height=input.scrollHeight+'px'}"
      "input.addEventListener('input',autoResize);"
      "input.addEventListener('keydown',function(e)\{if(e.key==='Enter'&&!e.shiftKey)\{e.preventDefault();form.dispatchEvent(new Event('submit'))}});"
      "form.onsubmit=async function(e)\{e.preventDefault();var t=input.value.trim();if(!t)return;input.value='';autoResize();var r=await fetch(API+'/poke/'+BASE+'/messages.claude-messages?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{text:t})});if(!r.ok)\{var err=await r.text();showError(r.status+': '+err)}};"
      "function onLastMsg(e)\{try\{var m=JSON.parse(e.data);if(m.role)addMsg(m.role,m.content||'',m.type)}catch(x)\{}}"
      "function connect()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/last-message.json?mark=json');es.addEventListener('upd last-message.json',onLastMsg);es.onerror=function()\{es.close();setTimeout(connect,2000)}}"
      "function onStatus(e)\{try\{var s=JSON.parse(e.data);var el=document.getElementById('loading');if(s.loading)\{el.classList.add('active')}else\{el.classList.remove('active')}}catch(x)\{}}"
      "function connectStatus()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/status.json?mark=json');es.addEventListener('upd status.json',onStatus);es.onerror=function()\{es.close();setTimeout(connectStatus,2000)}}"
    "document.querySelectorAll('#filters input').forEach(function(cb)\{cb.addEventListener('change',function()\{var t=this.getAttribute('data-type');if(this.checked)\{box.classList.remove('hide-'+t)}else\{box.classList.add('hide-'+t)}})});"
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
          ".hide-thought .msg.thought, .hide-tool .msg.tool, .hide-error .msg.error, .hide-result .msg.result, .hide-continue .msg.continue, .hide-wait .msg.wait, .hide-done .msg.done, .hide-message .msg.message \{ display: none; } "
        ==
      ==
    ==
    ;body
      ;h1: Claude Chat
      ;div#filters
        ;div(class "filter-row")
          ;span(class "filter-label"): assistant
          ;label
            ;input(type "checkbox", checked "", data-type "message");
            ;span: message
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "thought");
            ;span: thought
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "tool");
            ;span: tool
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "wait");
            ;span: wait
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "done");
            ;span: done
          ==
        ==
        ;div(class "filter-row")
          ;span(class "filter-label"): user
          ;label
            ;input(type "checkbox", checked "", data-type "message");
            ;span: message
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "error");
            ;span: error
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "result");
            ;span: result
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "continue");
            ;span: continue
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
              ;div(class "msg continue")
                ;b: {role}
                ;span(class "sub"): continue
              ==
            ?:  ?&  =('user' role.message)
                    =((end [3 1] content.message) '<')
                ==
              =/  tag-type=tape
                ?:  =((end [3 7] content.message) '<error>')   "error"
                ?:  =((end [3 8] content.message) '<result>')  "result"
                "message"
              =/  inner=tape  (trip (extract-inner content.message))
              :-  ~
              ;div(class "msg {tag-type}")
                ;b: {role}
                ;span(class "sub"): {tag-type}
                ;pre: {inner}
              ==
            ::  [Error] messages
            =/  is-err=?  =((end [3 7] content.message) '[Error]')
            ?:  is-err
              :-  ~
              ;div(class "msg error")
                ;b: {role}
                ;span(class "sub"): error
                ;pre: {(trip (rsh [3 8] content.message))}
              ==
            ::  non-assistant: show as-is
            ?.  =('assistant' role.message)
              :-  ~
              ;div(class "msg message")
                ;b: {role}
                ;pre: {(trip content.message)}
              ==
            ::  assistant: check for <error>, then parse XML tag
            ?:  =((end [3 7] content.message) '<error>')
              :-  ~
              ;div(class "msg error")
                ;b: assistant
                ;span(class "sub"): error
                ;pre: {(trip (extract-inner content.message))}
              ==
            =/  tag=(unit response-tag)  (parse-response content.message)
            ?~  tag
              :-  ~
              ;div(class "msg message")
                ;b: assistant
                ;pre: {(trip content.message)}
              ==
            ?-  -.u.tag
                %thought
              :-  ~
              ;div(class "msg thought")
                ;b: assistant
                ;span(class "sub"): thought
                ;pre: {(trip text.u.tag)}
              ==
                %message
              :-  ~
              ;div(class "msg message")
                ;b: assistant
                ;pre: {(trip text.u.tag)}
              ==
                %tool
              =/  calls-text=tape
                %+  roll  calls.u.tag
                |=  [tc=tool-call acc=tape]
                (weld acc "{(trip name.tc)}({(trip args.tc)}) ")
              :-  ~
              ;div(class "msg tool")
                ;b: assistant
                ;span(class "sub"): tool
                ;pre: {calls-text}
              ==
                %wait
              :-  ~
              ;div(class "msg wait")
                ;b: assistant
                ;span(class "sub"): wait
              ==
                %done
              :-  ~
              ;div(class "msg done")
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
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
