::  channel nexus: bridges external chat sources to claw agents
::
::  Config: /config.json with fields:
::    agent:   road to the agent (e.g. "../agents/test")
::    source:  road to telegram-bot (e.g. "/telegram.telegram/bots/main")
::    chat-id: telegram chat ID to bridge
::
::  The relay watches the telegram-bot's message file for new incoming
::  messages, pokes the agent with each one, then watches the agent's
::  conversation file for assistant responses and sends them back via
::  the telegram-bot's send.sig.
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['agent' s+'']
            ['source' s+'']
            ['chat-id' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %& [/ %'relay.sig'] %.n [~ [/ %sig] !>(~)]]
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
          ::  /relay.sig: bridge between telegram-bot and agent
          ::
          [~ %'relay.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%channel relay: failed")
        ;<  cfg=channel-config  bind:m  read-config
        ?:  |(=('' agent.cfg) =('' source.cfg) =('' chat-id.cfg))
          ~&  >>>  "%channel: missing config fields"
          stay:m
        ::  roads to the external endpoints
        =/  agent-main=road:tarball
          (cord-to-road:tarball (crip "{(trip agent.cfg)}/main.sig"))
        =/  agent-conv=road:tarball
          (cord-to-road:tarball (crip "{(trip agent.cfg)}/context/conversations/telegram-{(trip chat-id.cfg)}.json"))
        =/  bot-msgs=road:tarball
          (cord-to-road:tarball (crip "{(trip source.cfg)}/messages/{(trip chat-id.cfg)}.json"))
        =/  bot-send=road:tarball
          (cord-to-road:tarball (crip "{(trip source.cfg)}/send.sig"))
        ::  read initial state
        ;<  bot-view=view:nexus  bind:m  (keep:io /bot-msgs bot-msgs ~)
        =/  seen-count=@ud  (count-incoming bot-view)
        ~&  >  ["%channel: started, seen" seen-count "messages"]
        ::  also watch the agent conversation for responses
        ;<  conv-view=view:nexus  bind:m  (keep:io /agent-conv agent-conv ~)
        =/  last-reply=@ud  (count-assistant conv-view)
        ~&  >  ["%channel: agent has" last-reply "replies"]
        |-
        ;<  [tag=?(%bot %conv) =view:nexus]  bind:m
          (take-either /bot-msgs /agent-conv)
        ?-    tag
            %bot
          ::  new telegram messages arrived
          =/  new-count=@ud  (count-incoming view)
          =/  new-msgs=(list @t)  (get-incoming-after view seen-count)
          ~&  >  ["%channel: new messages" (lent new-msgs)]
          =.  seen-count  new-count
          ;<  ~  bind:m  (forward-to-agent new-msgs agent-main chat-id.cfg)
          $
        ::
            %conv
          ::  agent conversation updated — check for new assistant messages
          =/  new-reply-count=@ud  (count-assistant view)
          =/  new-replies=(list @t)  (get-assistant-after view last-reply)
          =.  last-reply  new-reply-count
          ;<  ~  bind:m  (send-to-telegram new-replies bot-send chat-id.cfg)
          $
        ==
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Channel instance.'
            ~
          'Chat channel. Bridges an external source (telegram, etc) to a claw agent.'
        ==
          %|
        ?+  rail.p.mana  'File under channel.'
          [~ %'config.json']  'Channel config: agent, source, chat-id.'
          [~ %'relay.sig']    'Relay process bridging messages.'
        ==
      ==
    --
::
|%
::
+$  channel-config
  $:  agent=@t
      source=@t
      chat-id=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,channel-config)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './config.json')
  ;<  =seen:nexus  bind:m  (peek:io road `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m ['' '' ''])
  =/  cfg=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%o -.cfg)
    (pure:m ['' '' ''])
  =/  get
    |=  key=@t
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  ''
    p.u.v
  (pure:m [(get 'agent') (get 'source') (get 'chat-id')])
::
::  forward a list of messages to the agent
::
++  forward-to-agent
  |=  [msgs=(list @t) agent-main=road:tarball chat-id=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  msgs  (pure:m ~)
  =/  poke-body=json
    %-  pairs:enjs:format
    :~  ['action' s+'message']
        ['content' s+i.msgs]
        ['conversation' s+(crip "telegram-{(trip chat-id)}")]
    ==
  ~&  >  ["%channel: forwarding to agent:" i.msgs]
  ;<  ~  bind:m  (poke:io agent-main [/ %json] !>(poke-body))
  $(msgs t.msgs)
::
::  send a list of replies to telegram
::
++  send-to-telegram
  |=  [replies=(list @t) bot-send=road:tarball chat-id=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  replies  (pure:m ~)
  =/  send-body=json
    %-  pairs:enjs:format
    :~  ['message' s+i.replies]
        ['chat_id' s+chat-id]
    ==
  ~&  >  ["%channel: sending reply to telegram:" i.replies]
  ;<  ~  bind:m  (poke:io bot-send [/ %json] !>(send-body))
  $(replies t.replies)
::
::  count incoming (non-bot) messages in a telegram message file view
::
++  count-incoming
  |=  =view:nexus
  ^-  @ud
  =/  msgs=(list json)  (extract-msgs view)
  %+  roll  msgs
  |=  [msg=json acc=@ud]
  ?.  ?=([%o *] msg)  acc
  =/  dir  (~(get by p.msg) 'dir')
  ?:  ?=([~ %s %'out'] dir)  acc
  +(acc)
::
::  count assistant messages in an agent conversation view
::
++  count-assistant
  |=  =view:nexus
  ^-  @ud
  =/  entries=(list json)  (extract-conv view)
  %+  roll  entries
  |=  [entry=json acc=@ud]
  ?.  ?=([%o *] entry)  acc
  =/  role  (~(get by p.entry) 'role')
  ?.  ?=([~ %s %'assistant'] role)  acc
  +(acc)
::
::  get incoming messages after a given count
::
++  get-incoming-after
  |=  [=view:nexus skip=@ud]
  ^-  (list @t)
  =/  msgs=(list json)  (extract-msgs view)
  =/  idx=@ud  0
  =/  acc=(list @t)  ~
  |-
  ?~  msgs  (flop acc)
  =/  msg=json  i.msgs
  ?.  ?=([%o *] msg)
    $(msgs t.msgs)
  =/  dir  (~(get by p.msg) 'dir')
  ?:  ?=([~ %s %'out'] dir)
    $(msgs t.msgs)
  ::  this is an incoming message
  ?:  (lth idx skip)
    $(msgs t.msgs, idx +(idx))
  =/  text  (~(get by p.msg) 'text')
  ?.  ?=([~ %s *] text)
    $(msgs t.msgs, idx +(idx))
  $(msgs t.msgs, idx +(idx), acc [p.u.text acc])
::
::  get assistant messages after a given count
::
++  get-assistant-after
  |=  [=view:nexus skip=@ud]
  ^-  (list @t)
  =/  entries=(list json)  (extract-conv view)
  =/  idx=@ud  0
  =/  acc=(list @t)  ~
  |-
  ?~  entries  (flop acc)
  =/  entry=json  i.entries
  ?.  ?=([%o *] entry)
    $(entries t.entries)
  =/  role  (~(get by p.entry) 'role')
  ?.  ?=([~ %s %'assistant'] role)
    $(entries t.entries)
  ?:  (lth idx skip)
    $(entries t.entries, idx +(idx))
  =/  content  (~(get by p.entry) 'content')
  ?.  ?=([~ %s *] content)
    $(entries t.entries, idx +(idx))
  $(entries t.entries, idx +(idx), acc [p.u.content acc])
::
::  extract messages list from a telegram message file view
::
++  extract-msgs
  |=  =view:nexus
  ^-  (list json)
  ?.  ?=([%file *] view)  ~
  =/  dat=json  (fall (mole |.(!<(json q.sage.view))) *json)
  ?:  ?=([%a *] dat)  p.dat
  ?.  ?=([%o *] dat)  ~
  =/  v  (~(get by p.dat) 'messages')
  ?.  ?=([~ %a *] v)  ~
  p.u.v
::
::  extract entries from an agent conversation view
::
++  extract-conv
  |=  =view:nexus
  ^-  (list json)
  ?.  ?=([%file *] view)  ~
  =/  dat=json  (fall (mole |.(!<(json q.sage.view))) *json)
  ?.  ?=([%a *] dat)  ~
  p.dat
::
::  take news from either of two wires
::
++  take-either
  |=  [a=wire b=wire]
  =/  m  (fiber:fiber:nexus ,[?(%bot %conv) view:nexus])
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(a wire.u.in)  [%done %bot view.u.in]
    ?:  =(b wire.u.in)  [%done %conv view.u.in]
    [%skip ~]
  ==
--
