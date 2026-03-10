::  claude nexus: flat chat with Claude API
::
/-  *claude
/+  nexus, tarball, io=fiberio
!:
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
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
          :~  'You are Claude, a helpful AI assistant integrated with an Urbit ship.'
              'Urbit is a peer-to-peer operating system and network.'
              'This integration runs as a native Hoon application on the user\'s personal server (their "ship").'
              'The user is interacting with you through a web interface served by their ship.'
              'Be helpful, concise, and knowledgeable about Urbit when relevant.'
          ==
        (~(put ba:tarball ball) [/ %'system-prompt.txt'] [~ %txt !>(default)])
      =?  ball  =(~ (~(get of ball) /ui))
        (~(put of ball) /ui [~ ~ ~])
      =?  ball  =(~ (~(get ba:tarball ball) [/ui %'chat.html']))
        %+  ~(put ba:tarball ball)  [/ui %'chat.html']
        [~ %manx !>((chat-page ~))]
      =?  ball  =(~ (~(get of ball) /ui/sse))
        (~(put of ball) /ui/sse [~ ~ ~])
      =?  ball  =(~ (~(get ba:tarball ball) [/ui/sse %'last-message.json']))
        (~(put ba:tarball ball) [/ui/sse %'last-message.json'] [~ %json !>(*json)])
      [sand ball]
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
            $
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
          ::  build request
          =/  msgs-json=json
            :-  %a
            %+  turn  (tap:mon messages.msg)
            |=  [idx=@ud =message]
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
          =/  =request:http
            :^  %'POST'  'https://api.anthropic.com/v1/messages'
              :~  ['content-type' 'application/json']
                  ['x-api-key' api-key]
                  ['anthropic-version' '2023-06-01']
              ==
            `(as-octs:mimes:html body-cord)
          ;<  response=@t  bind:m  (fetch:io request)
          ~&  >  %claude-got-response
          =/  reply=@t  (extract-reply response)
          ?:  =('' reply)
            ~&  >>>  [%claude-empty-reply response]
            $
          =/  idx=@ud
            =/  top  (ram:mon messages.msg)
            ?~(top 0 +(key.u.top))
          =/  msg=messages
            msg(messages (put:mon messages.msg idx ['assistant' reply]))
          ;<  ~  bind:m  (replace:io !>(msg))
          ~&  >  %claude-done
          $
        ==
      ::  /ui/chat.html — watches messages, renders page
      ::
          [[%ui ~] %'chat.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claude page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /msgs (cord-to-road:tarball '../messages.claude-messages') ~)
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
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /msgs)
        ?.  ?=([%file *] upd)  $
        =/  msg=messages  !<(messages q.cage.upd)
        =/  last=(unit [key=@ud val=message])  (ram:mon messages.msg)
        =/  =json
          ?~  last  ~
          %-  pairs:enjs:format
          ~[['role' s+role.val.u.last] ['content' s+content.val.u.last]]
        ;<  ~  bind:m  (replace:io !>(json))
        $
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
      "function esc(s)\{var d=document.createElement('div');d.textContent=s;return d.innerHTML}"
      "function addMsg(role,content)\{var d=document.createElement('div');d.className='msg '+role;d.innerHTML='<b>'+role+'</b><pre>'+esc(content)+'</pre>';box.appendChild(d);box.scrollTop=box.scrollHeight}"
      "function showError(msg)\{var d=document.createElement('div');d.className='msg error';d.innerHTML='<b>error</b><pre>'+esc(msg)+'</pre>';box.appendChild(d);box.scrollTop=box.scrollHeight}"
      "form.onsubmit=async function(e)\{e.preventDefault();var t=input.value.trim();if(!t)return;input.value='';var r=await fetch(API+'/poke/'+BASE+'/messages.claude-messages?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{text:t})});if(!r.ok)\{var err=await r.text();showError(r.status+': '+err)}};"
      "function onLastMsg(e)\{try\{var m=JSON.parse(e.data);if(m.role&&m.content)addMsg(m.role,m.content)}catch(x)\{}}"
      "function connect()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/last-message.json?mark=json');es.addEventListener('upd last-message.json',onLastMsg);es.onerror=function()\{es.close();setTimeout(connect,2000)}}"
      "connect();"
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
          ".msg b \{ display: block; margin-bottom: 0.25rem; text-transform: uppercase; font-size: 0.7rem; opacity: 0.5; } "
          ".msg pre \{ white-space: pre-wrap; word-wrap: break-word; font-family: monospace; font-size: 0.9rem; line-height: 1.4; } "
          ".msg.assistant pre \{ background: #f5f5f5; padding: 0.5rem; border-radius: 4px; } "
          ".msg.error pre \{ background: #fee; padding: 0.5rem; border-radius: 4px; color: #c00; } "
          ".msg.error b \{ color: #c00; } "
          "#form \{ display: flex; gap: 0.5rem; } "
          "#input \{ flex: 1; padding: 0.5rem; border: 1px solid #ccc; border-radius: 4px; font-family: monospace; font-size: 0.9rem; } "
          "#form button \{ padding: 0.5rem 1rem; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; font-family: monospace; } "
          "#form button:hover \{ background: #eee; } "
        ==
      ==
    ==
    ;body
      ;h1: Claude Chat
      ;div#messages
        ;*  %+  turn  msgs
            |=  [idx=@ud =message]
            ;div(class "msg {(trip role.message)}")
              ;b: {(trip role.message)}
              ;pre: {(trip content.message)}
            ==
      ==
      ;form#form
        ;input#input(type "text", placeholder "Type a message...", autocomplete "off");
        ;button(type "submit"): Send
      ==
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
