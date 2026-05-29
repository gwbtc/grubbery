::  channel nexus: standard messaging channel with pluggable source  ::
::
::  Standard API:
::    inbox.json  -- append-only list of inbound messages (channel writes)
::    send.sig    -- poke endpoint for outbound messages (agent pokes)
::    config.json -- source-specific config
::    relay.sig   -- internal fiber bridging source to inbox
::
::  Inbox message format:
::    [{"text": "...", "from": "...", "ts": "..."}]
::
::  Send message format (poke send.sig with json):
::    {"text": "..."}
::
::  Config (telegram source):
::    source:  road to telegram-bot (relative to parent /claw/app)
::    chat-id: telegram chat ID
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['source' s+'']
            ['chat-id' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] [[/ %json] default-config]]
            [%fall %& [/ %'inbox.json'] [[/ %json] [%a ~]]]
            [%over %& [/ %'send.sig'] [[/ %sig] ~]]
            [%over %& [/ %'relay.sig'] [[/ %sig] ~]]
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
          ::  /send.sig: outbound message handler
          ::  agent pokes here with {"text": "..."}, forwards to source
          ::
          [~ %'send.sig']
        ~&  >>  "%channel send.sig: fiber starting"
        ;<  ~  bind:m  (rise-wait:io prod "%channel send: failed")
        ;<  cfg=channel-config  bind:m  read-config
        ?:  |(=('' source.cfg) =('' chat-id.cfg))
          ~&  >>>  "%channel send: missing config"
          stay:m
        =/  source-fold=path  (source-to-fold source.cfg)
        ;<  bot-send=road:tarball  bind:m
          (ancestor-road:io [/claw %app] [%& source-fold %'send.sig'])
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)
          ~&  >>>  "%channel send: expected json object"
          $
        ::  pass through typing indicator directly to source
        =/  action=(unit json)  (~(get by p.jon) 'action')
        ?:  ?&  ?=([~ %s *] action)
                =('typing' p.u.action)
            ==
          =/  typing-body=json
            %-  pairs:enjs:format
            :~  ['action' s+'typing']
                ['chat_id' s+chat-id.cfg]
            ==
          ;<  ~  bind:m  (poke:io bot-send [/ %json] typing-body)
          $
        ::  handle normal message send
        =/  text=(unit json)  (~(get by p.jon) 'text')
        ?.  ?=([~ %s *] text)
          ~&  >>>  "%channel send: missing text field"
          $
        =/  send-body=json
          %-  pairs:enjs:format
          :~  ['message' u.text]
              ['chat_id' s+chat-id.cfg]
          ==
        ~&  >  ["%channel send: forwarding via" source-fold]
        ;<  ~  bind:m  (poke:io bot-send [/ %json] send-body)
        $
          ::  /relay.sig: bridge source inbound messages to inbox
          ::
          [~ %'relay.sig']
        ~&  >>  "%channel relay: fiber starting"
        ;<  ~  bind:m  (rise-wait:io prod "%channel relay: failed")
        ;<  cfg=channel-config  bind:m  read-config
        ~&  >>  ["%channel relay: config" source.cfg chat-id.cfg]
        ?:  |(=('' source.cfg) =('' chat-id.cfg))
          ~&  >>>  "%channel relay: missing config fields"
          stay:m
        =/  msg-file=@ta  (crip "{(trip chat-id.cfg)}.json")
        ;<  bot-msgs=road:tarball  bind:m
        =/  source-fold=path  (source-to-fold source.cfg)
          (ancestor-road:io [/claw %app] [%& (weld source-fold /messages) msg-file])
        ~&  >>  ["%channel relay: subscribing to" bot-msgs]
        ::  watch source messages
        ;<  *  bind:m  (keep:io /bot-msgs bot-msgs ~)
        ;<  bot-seen=seen:nexus  bind:m  (peek:io bot-msgs ~)
        ~&  >>  ["%channel relay: initial seen" -.bot-seen]
        =/  seen-count=@ud  (count-incoming bot-seen)
        ~&  >>  ["%channel relay: started, seen" seen-count "messages"]
        |-
        ~&  >>  "%channel relay: waiting for take-news..."
        ;<  *  bind:m  (take-news:io /bot-msgs)
        ;<  upd-seen=seen:nexus  bind:m  (peek:io bot-msgs ~)
        ~&  >>  ["%channel relay: got news!" -.upd-seen]
        =/  new-count=@ud  (count-incoming upd-seen)
        ~&  >>  ["%channel relay: new-count" new-count "seen-count" seen-count]
        =/  new-msgs=(list [text=@t from=@t])
          (get-incoming-after upd-seen seen-count)
        =.  seen-count  new-count
        ?~  new-msgs
          ~&  >>  "%channel relay: no new incoming msgs after filter"
          $
        ~&  >>>  ["%channel relay: NEW MESSAGES" (lent new-msgs)]
        ::  append to inbox
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
        ~&  >>>  ["%channel relay: writing" (lent new-entries) "entries to inbox"]
        ;<  ~  bind:m  (over:io inbox-road [[/ %json] updated])
        ~&  >>>  "%channel relay: inbox updated!"
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Channel instance.'
            ~
          'Chat channel with standard API. Bridges external sources to claw agents.'
        ==
          %|
        ?+  rail.p.mana  'File under channel.'
          [~ %'config.json']  'Channel config: source road (relative to /claw/app) and chat-id.'
          [~ %'inbox.json']   'Append-only inbound message list. Subscribe here for new messages.'
          [~ %'send.sig']     'Poke with {"text": "..."} to send outbound messages via source.'
          [~ %'relay.sig']    'Internal relay: watches source, writes to inbox.'
        ==
      ==
    --
::
|%
::
+$  channel-config
  $:  source=@t
      chat-id=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,channel-config)
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
  (pure:m [(get 'source') (get 'chat-id')])
::
::  parse source config string to a fold (path within ancestor)
::
++  source-to-fold
  |=  src=@t
  ^-  path
  =/  t=tape  (trip src)
  ?~  t  /
  =/  pax=path
    %+  scan  t
    (more fas (cook crip (star ;~(less fas next))))
  (skip pax |=(s=@ta =('' s)))
::
::  count incoming (non-bot) messages in a telegram message file view
::
++  count-incoming
  |=  =seen:nexus
  ^-  @ud
  =/  msgs=(list json)  (extract-msgs seen)
  %+  roll  msgs
  |=  [msg=json acc=@ud]
  ?.  ?=([%o *] msg)  acc
  =/  dir  (~(get by p.msg) 'dir')
  ?:  ?=([~ %s %'out'] dir)  acc
  +(acc)
::
::  get incoming messages after a given count, with sender info
::
++  get-incoming-after
  |=  [=seen:nexus skip=@ud]
  ^-  (list [text=@t from=@t])
  =/  msgs=(list json)  (extract-msgs seen)
  =/  idx=@ud  0
  =/  acc=(list [text=@t from=@t])  ~
  |-
  ?~  msgs  (flop acc)
  =/  msg=json  i.msgs
  ?.  ?=([%o *] msg)
    $(msgs t.msgs)
  =/  dir  (~(get by p.msg) 'dir')
  ?:  ?=([~ %s %'out'] dir)
    $(msgs t.msgs)
  ?:  (lth idx skip)
    $(msgs t.msgs, idx +(idx))
  =/  text  (~(get by p.msg) 'text')
  ?.  ?=([~ %s *] text)
    $(msgs t.msgs, idx +(idx))
  =/  from=@t
    =/  f  (~(get by p.msg) 'from')
    ?:  ?=([~ %s *] f)  p.u.f
    =/  fn  (~(get by p.msg) 'from_name')
    ?:  ?=([~ %s *] fn)  p.u.fn
    'unknown'
  $(msgs t.msgs, idx +(idx), acc [[p.u.text from] acc])
::
::  extract messages list from a telegram message file view
::
++  extract-msgs
  |=  =seen:nexus
  ^-  (list json)
  ?.  ?=([%& %file *] seen)  ~
  =/  dat=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?:  ?=([%a *] dat)  p.dat
  ?.  ?=([%o *] dat)  ~
  =/  v  (~(get by p.dat) 'messages')
  ?.  ?=([~ %a *] v)  ~
  p.u.v
--
