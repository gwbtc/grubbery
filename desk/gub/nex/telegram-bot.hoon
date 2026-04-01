::  telegram-bot nexus: chat interface for a single Telegram bot
::
::    Polls Telegram's getUpdates API via long polling, stores messages
::    per-chat in messages/{chat-id}.json files.
::
::    Each message file: {"name": "...", "chat-id": "...", "messages": [...]}
::    Config: /config.json with bot-token field.
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        ~[['bot-token' s+'']]
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %& [/ %'offset.ud'] %.n [~ [/ %ud] !>(0)]]
            [%fall %& [/ %'send.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'poller.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /messages [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ui %'chat.html'] %.n [~ [/ %manx] !>((chat-page "" *(map @t @t) *(list json)))]]
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
          ::  /poller.sig: long-poll getUpdates loop
          ::
          [~ %'poller.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%telegram-bot poller: failed")
        ;<  bot-token=@t  bind:m  read-bot-token
        ?:  =('' bot-token)
          ~&  >>>  %telegram-bot-no-token
          stay:m
        ;<  offset=@ud  bind:m  read-offset
        |-
        ::  long-poll getUpdates (25s timeout)
        ::
        =/  url=@t
          %+  rap  3
          :~  'https://api.telegram.org/bot'
              bot-token
              '/getUpdates?timeout=25'
              ?:(=(0 offset) '' (cat 3 '&offset=' (crip (a-co:co offset))))
          ==
        =/  =request:http
          [%'GET' url ~[['Accept' 'application/json']] ~]
        ;<  ~  bind:m  (send-request:io request)
        ;<  =client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.client-response)  $
        =/  body=@t
          ?~(full-file.client-response '' q.data.u.full-file.client-response)
        =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
        ?:  ?=(%| -.parsed)  $
        =/  resp=json  p.parsed
        ?.  ?=([%o *] resp)  $
        =/  results=(unit json)  (~(get by p.resp) 'result')
        ?.  ?=([~ %a *] results)  $
        ?~  p.u.results  $
        ::  process updates, extract messages
        ::
        =/  new-messages=(list json)
          %+  murn  p.u.results
          |=  upd=json
          ?.  ?=([%o *] upd)  ~
          =/  msg=(unit json)  (~(get by p.upd) 'message')
          ?~  msg  ~
          ?.  ?=([%o *] u.msg)  ~
          =/  text=(unit json)  (~(get by p.u.msg) 'text')
          =/  from=(unit json)  (~(get by p.u.msg) 'from')
          =/  chat=(unit json)  (~(get by p.u.msg) 'chat')
          =/  from-name=@t
            ?.  ?=([~ %o *] from)  'unknown'
            =/  first  (~(get by p.u.from) 'first_name')
            ?.  ?=([~ %s *] first)  'unknown'
            p.u.first
          =/  chat-id=@t
            ?.  ?=([~ %o *] chat)  ''
            =/  cid  (~(get by p.u.chat) 'id')
            ?.  ?=([~ %n *] cid)  ''
            p.u.cid
          =/  chat-title=@t
            ?.  ?=([~ %o *] chat)  ''
            =/  ttl  (~(get by p.u.chat) 'title')
            ?.  ?=([~ %s *] ttl)
              =/  first  (~(get by p.u.chat) 'first_name')
              ?.  ?=([~ %s *] first)  ''
              p.u.first
            p.u.ttl
          =/  date=(unit json)  (~(get by p.u.msg) 'date')
          ?~  text  ~
          ?.  ?=([%s *] u.text)  ~
          :-  ~
          %-  pairs:enjs:format
          :~  ['from' s+from-name]
              ['text' u.text]
              ['chat-id' s+chat-id]
              ['chat-title' s+chat-title]
              ['date' (fall date (numb:enjs:format 0))]
              ['dir' s+'in']
          ==
        ::  compute new offset: max update_id + 1
        ::
        =/  new-offset=@ud
          =/  max-id=@ud  0
          =/  updates=(list json)  p.u.results
          |-
          ?~  updates  ?:(=(0 max-id) offset +(max-id))
          =/  upd=json  i.updates
          ?.  ?=([%o *] upd)
            $(updates t.updates)
          =/  uid=(unit json)  (~(get by p.upd) 'update_id')
          ?.  ?=([~ %n *] uid)
            $(updates t.updates)
          =/  parsed=(unit @ud)  (rush p.u.uid dem)
          ?~  parsed  $(updates t.updates)
          $(updates t.updates, max-id (max max-id u.parsed))
        ::  group messages by chat-id
        ::
        =/  by-chat=(map @t (list json))
          %+  roll  new-messages
          |=  [msg=json acc=(map @t (list json))]
          ?.  ?=([%o *] msg)  acc
          =/  v  (~(get by p.msg) 'chat-id')
          ?.  ?=([~ %s *] v)  acc
          =/  cid=@t  p.u.v
          =/  existing=(list json)  (fall (~(get by acc) cid) ~)
          (~(put by acc) cid (snoc existing msg))
        ::  write per-chat message files (with chat name)
        ::
        ;<  ~  bind:m
          =/  chat-list=(list [cid=@t msgs=(list json)])  ~(tap by by-chat)
          |-
          ?~  chat-list  (pure:(fiber:fiber:nexus ,~) ~)
          =/  cid=@t  cid.i.chat-list
          =/  msgs=(list json)  msgs.i.chat-list
          ;<  existing=json  bind:m  (read-chat-file cid)
          =/  old-name=@t  (get-chat-name existing cid)
          =/  old-msgs=(list json)  (get-chat-msgs existing)
          ::  use chat-title from first new message if we have no name yet
          =/  chat-name=@t
            ?.  =(old-name cid)  old-name
            ?~  msgs  cid
            ?.  ?=([%o *] i.msgs)  cid
            =/  v  (~(get by p.i.msgs) 'chat-title')
            ?.  ?=([~ %s *] v)  cid
            ?:  =('' p.u.v)  cid
            p.u.v
          ;<  ~  bind:m  (write-chat-file cid chat-name (weld old-msgs msgs))
          $(chat-list t.chat-list)
        ::  update offset
        ::
        =/  offset-road=road:tarball  (cord-to-road:tarball './offset.ud')
        ;<  ~  bind:m  (over:io /off offset-road [[/ %ud] !>(new-offset)])
        $(offset new-offset)
          ::  /send.sig: accept pokes to send messages as the bot
          ::
          [~ %'send.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%telegram-bot send: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ?.  ?=(%json name.p.sage)  $
        =/  req=json  !<(json q.sage)
        ?.  ?=([%o *] req)  $
        =/  message=@t
          =/  v  (~(get by p.req) 'message')
          ?.  ?=([~ %s *] v)  ''
          p.u.v
        =/  chat-id=@t
          =/  v  (~(get by p.req) 'chat_id')
          ?.  ?=([~ %s *] v)  ''
          p.u.v
        ?:  |(=('' message) =('' chat-id))  $
        ;<  bot-token=@t  bind:m  read-bot-token
        ?:  =('' bot-token)  $
        ::  send via telegram API
        ::
        =/  url=@t
          (rap 3 ~['https://api.telegram.org/bot' bot-token '/sendMessage'])
        =/  body=@t
          (rap 3 ~['chat_id=' chat-id '&text=' message])
        =/  =request:http
          :*  %'POST'
              url
              ~[['content-type' 'application/x-www-form-urlencoded']]
              `(as-octs:mimes:html body)
          ==
        ;<  ~  bind:m  (send-request:io request)
        ;<  =client-response:iris  bind:m  take-client-response:io
        ::  log our outbound message
        ::
        =/  out-msg=json
          %-  pairs:enjs:format
          :~  ['from' s+'bot']
              ['text' s+message]
              ['chat-id' s+chat-id]
              ['date' (numb:enjs:format 0)]
              ['dir' s+'out']
          ==
        ;<  existing=json  bind:m  (read-chat-file chat-id)
        =/  old-name=@t  (get-chat-name existing chat-id)
        =/  old-msgs=(list json)  (get-chat-msgs existing)
        ;<  ~  bind:m  (write-chat-file chat-id old-name (snoc old-msgs out-msg))
        $
          ::  /ui/chat.html: live chat view
          ::
          [[%ui ~] %'chat.html']
        ;<  ~  bind:m  (rise-wait:io prod "%telegram-bot chat: failed")
        ::  compute base path for API calls
        ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
        =/  base=tape
          ::  path.here.bowl keys already contain dots for necks
          ::  e.g. /telegram.telegram/bots/claude-1/ui
          ::  snip /ui, then join with /
          =/  pax=path  (snip path.here.bowl)
          =/  acc=tape  ""
          |-
          ?~  pax  acc
          =/  seg=tape  (trip i.pax)
          ?~  acc  $(pax t.pax, acc seg)
          $(pax t.pax, acc (weld acc (weld "/" seg)))
        ;<  init=view:nexus  bind:m
          (keep:io /msgs [%| 1 %| /messages] ~)
        =/  chat-data=[(map @t @t) (list json)]  (view-to-chat-data init)
        ;<  ~  bind:m
          (replace:io !>((chat-page base -.chat-data +.chat-data)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /msgs)
        =/  chat-data=[(map @t @t) (list json)]  (view-to-chat-data upd)
        ;<  ~  bind:m
          (replace:io !>((chat-page base -.chat-data +.chat-data)))
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the telegram-bot nexus.'
            ~
          %-  crip
          """
          TELEGRAM BOT — chat interface for a single Telegram bot

          Long-polls Telegram's getUpdates API and maintains per-chat
          message logs in messages/[chat-id].json.

          Each file: \{"name": "...", "chat-id": "...", "messages": [...]}

          Configure /config.json with bot-token.
          View chat at /ui/chat.html.
          """
        ==
          %|
        ?+  rail.p.mana  'File under the telegram-bot nexus.'
          [~ %'offset.ud']           'Telegram update offset. Mark: ud.'
          [~ %'config.json']         'Bot config: bot-token. Mark: json.'
          [~ %'send.sig']            'Accepts JSON pokes with chat_id and message. Sends as bot.'
          [~ %'poller.sig']          'Long-polling loop for incoming messages.'
        ==
      ==
    --
|%
::
++  read-bot-token
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /cfg (cord-to-road:tarball './config.json') `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m '')
  =/  cfg=json  !<(json q.sage.p.seen)
  ?.  ?=(%o -.cfg)
    (pure:m '')
  =/  v  (~(get by p.cfg) 'bot-token')
  ?.  ?=([~ %s *] v)  (pure:m '')
  (pure:m p.u.v)
::
++  read-offset
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /off (cord-to-road:tarball './offset.ud') `%ud)
  ?.  ?=([%& %file *] seen)
    (pure:m 0)
  (pure:m !<(@ud q.sage.p.seen))
::
++  read-chat-file
  |=  cid=@t
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /msg (cord-to-road:tarball (rap 3 ~['./messages/' cid '.json'])) `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m [%o ~])
  (pure:m !<(json q.sage.p.seen))
::
++  get-chat-name
  |=  [dat=json default=@t]
  ^-  @t
  ?.  ?=([%o *] dat)  default
  =/  v  (~(get by p.dat) 'name')
  ?.  ?=([~ %s *] v)  default
  p.u.v
::
++  get-chat-msgs
  |=  dat=json
  ^-  (list json)
  ?:  ?=([%a *] dat)  p.dat
  ?.  ?=([%o *] dat)  ~
  =/  v  (~(get by p.dat) 'messages')
  ?.  ?=([~ %a *] v)  ~
  p.u.v
::
++  write-chat-file
  |=  [cid=@t name=@t msgs=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  file-road=road:tarball
    (cord-to-road:tarball (rap 3 ~['./messages/' cid '.json']))
  =/  dat=json
    %-  pairs:enjs:format
    :~  ['name' s+name]
        ['chat-id' s+cid]
        ['messages' [%a msgs]]
    ==
  ;<  =seen:nexus  bind:m
    (peek:io /chk file-road ~)
  ?:  ?=([%& %file *] seen)
    (over:io /msg file-road [[/ %json] !>(dat)])
  (make:io /msg file-road [%| gain=%.n [[/ %json] !>(dat)] ~])
::
::  Extract chat names and messages from the messages/ directory view.
::  Files live in fil.ball.view → contents (not dir, which is subdirs).
::
++  view-to-chat-data
  |=  =view:nexus
  ^-  [(map @t @t) (list json)]
  ?.  ?=([%ball *] view)  [~ ~]
  ?~  fil.ball.view  [~ ~]
  =/  files=(list [key=@ta =content:tarball])
    ~(tap by contents.u.fil.ball.view)
  %+  roll  files
  |=  [[key=@ta =content:tarball] chats=(map @t @t) msgs=(list json)]
  ?.  ?=(%json name.p.sage.content)  [chats msgs]
  =/  dat=json  !<(json q.sage.content)
  ::  handle old format: [%a msgs] — derive chat-id from first message
  ?:  ?=([%a *] dat)
    =/  old-msgs=(list json)  p.dat
    =/  cid=@t
      ?~  old-msgs  ''
      ?.  ?=([%o *] i.old-msgs)  ''
      =/  v  (~(get by p.i.old-msgs) 'chat-id')
      ?.  ?=([~ %s *] v)  ''
      p.u.v
    ?:  =('' cid)  [chats (weld msgs old-msgs)]
    [(~(put by chats) cid cid) (weld msgs old-msgs)]
  ::  new format: {"name": ..., "chat-id": ..., "messages": [...]}
  ?.  ?=([%o *] dat)  [chats msgs]
  =/  cid=@t
    =/  v  (~(get by p.dat) 'chat-id')
    ?.  ?=([~ %s *] v)  ''
    p.u.v
  =/  name=@t
    =/  v  (~(get by p.dat) 'name')
    ?.  ?=([~ %s *] v)  cid
    p.u.v
  =/  file-msgs=(list json)
    =/  v  (~(get by p.dat) 'messages')
    ?.  ?=([~ %a *] v)  ~
    p.u.v
  [(~(put by chats) cid name) (weld msgs file-msgs)]
::
++  chat-page
  |=  [base=tape chats=(map @t @t) messages=(list json)]
  ^-  manx
  =/  api=tape  "/grubbery/api"
  =/  msgs-json=tape  (trip (en:json:html [%a messages]))
  ;html
    ;head
      ;title: Telegram Bot
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/
          ;:  weld
            "* \{ box-sizing: border-box; } "
            "body \{ font-family: monospace; margin: 0; padding: 0; height: 100vh; display: flex; flex-direction: column; } "
            "#header \{ display: flex; justify-content: space-between; align-items: baseline; padding: 0.75rem 1rem; border-bottom: 1px solid #ccc; } "
            "#header h1 \{ margin: 0; font-size: 1rem; } "
            "#layout \{ display: flex; flex: 1; overflow: hidden; } "
            "#sidebar \{ width: 200px; border-right: 1px solid #ccc; display: flex; flex-direction: column; } "
            "#chat-list \{ flex: 1; overflow-y: auto; } "
            ".chat-item \{ padding: 0.5rem 0.75rem; cursor: pointer; font-size: 0.8rem; border-bottom: 1px solid #eee; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; } "
            ".chat-item:hover \{ background: #f0f0f0; } "
            ".chat-item.active \{ background: #e3f2fd; font-weight: bold; } "
            ".chat-item.all \{ opacity: 0.5; font-style: italic; } "
            "#chat-actions \{ padding: 0.5rem; border-top: 1px solid #ccc; display: flex; flex-direction: column; gap: 0.3rem; } "
            "#chat-actions input \{ font-family: monospace; padding: 0.25rem; border: 1px solid #ccc; border-radius: 3px; font-size: 0.75rem; width: 100%; } "
            "#chat-actions button \{ font-family: monospace; padding: 0.25rem; border: 1px solid #ccc; border-radius: 3px; background: none; cursor: pointer; font-size: 0.7rem; } "
            "#chat-actions button:hover \{ background: #eee; } "
            "#chat-actions button.del \{ border-color: #c62828; color: #c62828; } "
            "#chat-actions button.del:hover \{ background: #fce8e6; } "
            "#main \{ flex: 1; display: flex; flex-direction: column; overflow: hidden; } "
            "#messages \{ flex: 1; padding: 0.75rem; overflow-y: auto; background: #f9f9f9; display: flex; flex-direction: column; gap: 0.4rem; } "
            ".msg \{ padding: 0.4rem 0.6rem; border-radius: 6px; max-width: 80%; font-size: 0.85rem; line-height: 1.4; word-break: break-word; } "
            ".msg.in \{ background: #e3f2fd; align-self: flex-start; } "
            ".msg.out \{ background: #e8f5e9; align-self: flex-end; } "
            ".msg .from \{ font-size: 0.7rem; font-weight: bold; opacity: 0.6; margin-bottom: 0.15rem; } "
            "#compose \{ display: flex; gap: 0.5rem; padding: 0.5rem 0.75rem; border-top: 1px solid #ccc; } "
            "#compose input \{ flex: 1; font-family: monospace; padding: 0.4rem; border: 1px solid #ccc; border-radius: 4px; } "
            "#compose button \{ padding: 0.4rem 0.75rem; font-family: monospace; cursor: pointer; border: 1px solid #ccc; border-radius: 4px; background: #333; color: #fff; } "
            "#compose button:hover \{ background: #555; } "
            ".empty \{ opacity: 0.4; text-align: center; padding: 2rem; } "
            ".hdr-btn \{ font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; background: none; cursor: pointer; margin-left: 0.4rem; text-decoration: none; color: inherit; } "
            ".hdr-btn:hover \{ opacity: 0.8; } "
          ==
      ==
    ==
    ;body
      ;div#header
        ;h1: Telegram Bot
        ;a.hdr-btn(href "../../../ui/manage.html"): bots
      ==
      ;div#layout
        ;div#sidebar
          ;div#chat-list
            ;div.chat-item.all(data-id "all"): All chats
            ;*  %+  turn  ~(tap by chats)
                |=  [id=@t name=@t]
                =/  cid=tape  (trip id)
                =/  display=tape  (trip name)
                ;div.chat-item(data-id cid): {display}
          ==
          ;div#chat-actions
            ;input#add-chat-id(type "text", placeholder "Chat ID");
            ;input#add-chat-name(type "text", placeholder "Name");
            ;button#add-chat-btn: + add chat
            ;button#del-chat-btn.del: - delete selected
          ==
        ==
        ;div#main
          ;div#messages
            ;span.empty: Loading...
          ==
          ;div#compose
            ;input#input(type "text", placeholder "Type a message...", autocomplete "off");
            ;button#send: Send
          ==
        ==
      ==
      ;script
        ;+  ;/
          ;:  weld
            "var API='{api}';var BASE='{base}';"
            "var allMsgs={msgs-json};var curChat='all';"
            ::  chat sidebar selection
            "var items=document.querySelectorAll('.chat-item');"
            "var first=document.querySelector('.chat-item:not(.all)');"
            "if(first)\{first.classList.add('active');curChat=first.dataset.id}"
            "else\{document.querySelector('.chat-item.all').classList.add('active')}"
            "items.forEach(function(el)\{el.onclick=function()\{items.forEach(function(x)\{x.classList.remove('active')});el.classList.add('active');curChat=el.dataset.id;renderMsgs()}});"
            ::  render messages filtered by selected chat
            "function renderMsgs()\{var filtered=curChat==='all'?allMsgs:allMsgs.filter(function(m)\{return(m['chat-id']||'')==curChat});var el=document.getElementById('messages');el.innerHTML='';if(filtered.length===0)\{el.innerHTML='<span class=\"empty\">No messages yet.</span>';return}filtered.forEach(function(m)\{var d=document.createElement('div');d.className='msg '+(m.dir||'in');d.innerHTML='<div class=\"from\">'+esc(m.from||'unknown')+'</div><span>'+esc(m.text||'')+'</span>';el.appendChild(d)});scrollBottom()}"
            "renderMsgs();"
            ::  send message
            "function doSend()\{var i=document.getElementById('input');var m=i.value.trim();if(!m)return;if(curChat==='all')\{alert('Select a specific chat to send to');return}i.value='';fetch(API+'/poke/'+BASE+'/send.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{message:m,chat_id:curChat})})}"
            "document.getElementById('send').onclick=doSend;"
            "document.getElementById('input').onkeydown=function(e)\{if(e.key==='Enter')doSend()};"
            ::  helpers
            "function scrollBottom()\{var m=document.getElementById('messages');m.scrollTop=m.scrollHeight}"
            "function esc(s)\{var d=document.createElement('div');d.textContent=s;return d.innerHTML}"
            ::  chat management — create/delete message files directly
            "document.getElementById('add-chat-btn').onclick=async function()\{var id=document.getElementById('add-chat-id').value.trim();var name=document.getElementById('add-chat-name').value.trim()||id;if(!id)\{alert('Chat ID required');return}await fetch(API+'/file/'+BASE+'/messages/'+id+'.json?mark=json',\{method:'PUT',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{name:name,'chat-id':id,messages:[]})});location.reload()};"
            "document.getElementById('del-chat-btn').onclick=async function()\{if(curChat==='all')\{alert('Select a chat first');return}var el=document.querySelector('.chat-item.active');var name=el?el.textContent:curChat;if(!confirm('Delete chat \"'+name+'\" ('+curChat+')?'))return;await fetch(API+'/file/'+BASE+'/messages/'+curChat+'.json',\{method:'DELETE'});location.reload()};"
          ==
      ==
    ==
  ==
--
