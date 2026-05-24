::  claw/channel/telegram: telegram channel with direct API integration
::
::  Standard channel API:
::    inbox.json  -- append-only inbound messages
::    send.sig    -- poke with {"text": "..."} to send outbound
::    config.json -- bot-token, chat-id
::    poller.sig  -- long-polls telegram getUpdates
::
::  Config:
::    bot-token: telegram bot API token
::    chat-id:   telegram chat ID to bridge
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  ball:tarball
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['bot-token' s+'']
            ['chat-id' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] [[/ %json] !>(default-config)]]
            [%fall %& [/ %'inbox.json'] [[/ %json] !>([%a ~])]]
            [%fall %& [/ %'send.sig'] [[/ %sig] !>(~)]]
            [%fall %& [/ %'poller.sig'] [[/ %sig] !>(~)]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /poller.sig: long-poll telegram getUpdates, write to inbox
          ::
          [~ %'poller.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%tg-channel poller: failed")
        ;<  cfg=tg-config  bind:m  read-config
        ?:  |(=('' bot-token.cfg) =('' chat-id.cfg))
          ~&  >>>  "%tg-channel: missing bot-token or chat-id"
          stay:m
        ~&  >>  ["%tg-channel: polling chat" chat-id.cfg]
        ::  read existing inbox to not re-append old messages
        =/  offset=@ud  0
        |-
        =/  url=@t
          %+  rap  3
          :~  'https://api.telegram.org/bot'
              bot-token.cfg
              '/getUpdates?timeout=25'
              ?:(=(0 offset) '' (cat 3 '&offset=' (crip (a-co:co offset))))
          ==
        =/  =request:http
          [%'GET' url ~[['Accept' 'application/json']] ~]
        ~&  >>  ["%tg-channel: sending getUpdates, offset" offset]
        ;<  ~  bind:m  (send-request:io request)
        ;<  =client-response:iris  bind:m  take-client-response:io
        ~&  >>  ["%tg-channel: response" -.client-response ?:(?=(%finished -.client-response) status-code.response-header.client-response 0)]
        ?.  ?=(%finished -.client-response)
          ~&  >>>  "%tg-channel: not finished, retrying"
          $
        =/  body=@t
          ?~(full-file.client-response '' q.data.u.full-file.client-response)
        =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
        ?:  ?=(%| -.parsed)
          ~&  >>>  ["%tg-channel: JSON parse failed, body" (scag 200 (trip body))]
          $
        =/  resp=json  p.parsed
        ?.  ?=([%o *] resp)  $
        =/  results=(unit json)  (~(get by p.resp) 'result')
        ?.  ?=([~ %a *] results)  $
        ?~  p.u.results  $
        ::  extract messages for our chat-id
        =/  new-msgs=(list [text=@t from=@t])
          %+  murn  p.u.results
          |=  upd=json
          ?.  ?=([%o *] upd)  ~
          =/  msg=(unit json)  (~(get by p.upd) 'message')
          ?~  msg  ~
          ?.  ?=([%o *] u.msg)  ~
          =/  chat=(unit json)  (~(get by p.u.msg) 'chat')
          =/  cid=@t
            ?.  ?=([~ %o *] chat)  ''
            =/  v  (~(get by p.u.chat) 'id')
            ?.  ?=([~ %n *] v)  ''
            p.u.v
          ::  only messages for our chat
          ?.  =(cid chat-id.cfg)  ~
          =/  text=(unit json)  (~(get by p.u.msg) 'text')
          ?~  text  ~
          ?.  ?=([%s *] u.text)  ~
          =/  from=(unit json)  (~(get by p.u.msg) 'from')
          =/  from-name=@t
            ?.  ?=([~ %o *] from)  'unknown'
            =/  first  (~(get by p.u.from) 'first_name')
            ?.  ?=([~ %s *] first)  'unknown'
            p.u.first
          `[p.u.text from-name]
        ::  compute new offset
        =/  new-offset=@ud
          =/  max-id=@ud  0
          =/  updates=(list json)  p.u.results
          |-
          ?~  updates  ?:(=(0 max-id) offset +(max-id))
          =/  upd=json  i.updates
          ?.  ?=([%o *] upd)  $(updates t.updates)
          =/  uid=(unit json)  (~(get by p.upd) 'update_id')
          ?.  ?=([~ %n *] uid)  $(updates t.updates)
          =/  parsed=(unit @ud)  (rush p.u.uid dem)
          ?~  parsed  $(updates t.updates)
          $(updates t.updates, max-id (max max-id u.parsed))
        =.  offset  new-offset
        ::  append to inbox
        ?~  new-msgs  $
        ~&  >>  ["%tg-channel: new messages" (lent new-msgs)]
        ;<  now=@da  bind:m  get-time:io
        =/  inbox-road=road:tarball  (cord-to-road:tarball './inbox.json')
        ;<  cur-seen=seen:nexus  bind:m  (peek:io inbox-road ~)
        =/  cur-inbox=(list json)
          ?.  ?=([%& %file *] cur-seen)  ~
          =/  j=json  (fall (mole |.(!<(json q.sage.p.cur-seen))) *json)
          ?.  ?=(%a -.j)  ~
          p.j
        =/  new-entries=(list json)
          %+  turn  new-msgs
          |=  [text=@t from=@t]
          %-  pairs:enjs:format
          :~  ['text' s+text]
              ['from' s+from]
              ['ts' s+(scot %da now)]
          ==
        =/  updated=json  [%a (weld cur-inbox new-entries)]
        ;<  ~  bind:m  (over:io inbox-road [[/ %json] !>(updated)])
        ~&  >>  ["%tg-channel: inbox updated," (lent new-entries) "new"]
        $
          ::  /send.sig: send outbound messages via telegram API
          ::
          [~ %'send.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%tg-channel send: failed")
        ;<  cfg=tg-config  bind:m  read-config
        ?:  |(=('' bot-token.cfg) =('' chat-id.cfg))
          ~&  >>>  "%tg-channel send: missing config"
          stay:m
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=([%o *] jon)  $
        =/  action=(unit json)  (~(get by p.jon) 'action')
        ::  typing: enter typing loop, re-send every 4s until next poke
        ?:  =([~ s+'typing'] action)
          ;<  ~  bind:m  (send-typing bot-token.cfg chat-id.cfg)
          ;<  now=@da  bind:m  get-time:io
          ;<  ~  bind:m  (send-wait:io (add now ~s4))
          |-
          ;<  result=poke-or-wake  bind:m  take-poke-or-wake
          ?-    -.result
              %wake
            ;<  ~  bind:m  (send-typing bot-token.cfg chat-id.cfg)
            ;<  now=@da  bind:m  get-time:io
            ;<  ~  bind:m  (send-wait:io (add now ~s4))
            $
              %poke
            ::  got a real poke while typing — send message and return to main loop
            =/  jon=json  (fall (mole |.(!<(json q.p.result))) *json)
            ?.  ?=(%o -.jon)  ^$
            =/  text=(unit json)  (~(get by p.jon) 'text')
            ?.  ?=([~ %s *] text)  ^$
            ;<  ~  bind:m  (send-msg bot-token.cfg chat-id.cfg p.u.text)
            ^$
          ==
        ::  normal message send
        =/  text=(unit json)  (~(get by p.jon) 'text')
        ?.  ?=([~ %s *] text)  $
        ;<  ~  bind:m  (send-msg bot-token.cfg chat-id.cfg p.u.text)
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Telegram channel instance.'
            ~
          'Telegram channel. Polls getUpdates, writes inbox, sends via bot API.'
        ==
          %|
        ?+  rail.p.mana  'File under telegram channel.'
          [~ %'config.json']  'Channel config: bot-token and chat-id.'
          [~ %'inbox.json']   'Append-only inbound message list.'
          [~ %'send.sig']     'Poke with {"text": "..."} to send via telegram.'
          [~ %'poller.sig']   'Long-polling loop for incoming messages.'
        ==
      ==
    --
::
|%
::
+$  tg-config
  $:  bot-token=@t
      chat-id=@t
  ==
::
+$  poke-or-wake
  $%  [%poke p=sage:tarball]
      [%wake ~]
  ==
::
::  +take-poke-or-wake: race a poke against a timer wake
::
++  take-poke-or-wake
  =/  m  (fiber:fiber:nexus ,poke-or-wake)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %timer-wake] p.sage.u.in)
      [%done %wake ~]
    [%done %poke sage.u.in]
  ==
::
::  +send-typing: fire sendChatAction typing
::
++  send-typing
  |=  [bot-token=@t chat-id=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://api.telegram.org/bot' bot-token '/sendChatAction'])
  =/  req-body=@t
    (rap 3 ~['chat_id=' chat-id '&action=typing'])
  =/  =request:http
    :*  %'POST'
        url
        ~[['content-type' 'application/x-www-form-urlencoded']]
        `(as-octs:mimes:html req-body)
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  (pure:m ~)
::
::  +send-msg: send a text message via telegram bot API
::
++  send-msg
  |=  [bot-token=@t chat-id=@t text=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >>  ["%tg-channel send:" text]
  =/  url=@t
    (rap 3 ~['https://api.telegram.org/bot' bot-token '/sendMessage'])
  =/  req-body=@t
    (rap 3 ~['chat_id=' chat-id '&text=' text])
  =/  =request:http
    :*  %'POST'
        url
        ~[['content-type' 'application/x-www-form-urlencoded']]
        `(as-octs:mimes:html req-body)
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ~&  >>  "%tg-channel send: done"
  (pure:m ~)
::
++  read-config
  =/  m  (fiber:fiber:nexus ,tg-config)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './config.json')
  ;<  =seen:nexus  bind:m  (peek:io road `[/ %json])
  ?.  ?=([%& %file *] seen)
    (pure:m ['' ''])
  =/  cfg=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%o -.cfg)
    (pure:m ['' ''])
  =/  get
    |=  key=@t
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  ''
    p.u.v
  (pure:m [(get 'bot-token') (get 'chat-id')])
--
