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
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['source' s+'']
            ['chat-id' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %& [/ %'inbox.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%over %& [/ %'send.sig'] %.n [~ [/ %sig] !>(~)]]
            [%over %& [/ %'relay.sig'] %.n [~ [/ %sig] !>(~)]]
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
          ::  /send.sig: outbound message handler
          ::  agent pokes here with {"text": "..."}, forwards to source
          ::
          [~ %'send.sig']
        ~&  >  "%channel send.sig: on-file triggered"
        ;<  ~  bind:m  (rise-wait:io prod "%channel send: failed")
        ;<  ~  bind:m  (send-dart:io %here /here)
        ;<  =here:nexus  bind:m  (take-here-raw:io /here)
        =/  app-res=(unit bend:tarball)  (find-in-here:io here `[/claw %app])
        ?~  app-res
          ~&  >>>  "%channel send: cannot find parent /claw/app"
          stay:m
        =/  app-bend=bend:tarball  u.app-res
        ;<  cfg=channel-config  bind:m  read-config
        ?:  |(=('' source.cfg) =('' chat-id.cfg))
          ~&  >>>  "%channel send: missing config"
          stay:m
        =/  source-prefix=tape
          =/  src=tape  (trip source.cfg)
          ?:  &(!=(~ src) =('/' (snag 0 src)))  src
          "{(render-bend app-bend)}{src}"
        =/  bot-send=road:tarball
          (cord-to-road:tarball (crip "{source-prefix}/send.sig"))
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)
          ~&  >>>  "%channel send: expected json object"
          $
        =/  text=(unit json)  (~(get by p.jon) 'text')
        ?.  ?=([~ %s *] text)
          ~&  >>>  "%channel send: missing text field"
          $
        =/  send-body=json
          %-  pairs:enjs:format
          :~  ['message' u.text]
              ['chat_id' s+chat-id.cfg]
          ==
        ~&  >  ["%channel send: forwarding to source" source-prefix]
        ~&  >  ["%channel send: bot-send road" bot-send]
        ~&  >  ["%channel send: payload" send-body]
        ;<  ~  bind:m  (poke:io bot-send [/ %json] !>(send-body))
        $
          ::  /relay.sig: bridge source inbound messages to inbox
          ::
          [~ %'relay.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%channel relay: failed")
        ;<  ~  bind:m  (send-dart:io %here /here)
        ;<  =here:nexus  bind:m  (take-here-raw:io /here)
        =/  app-res=(unit bend:tarball)  (find-in-here:io here `[/claw %app])
        ?~  app-res
          ~&  >>>  "%channel relay: cannot find parent /claw/app"
          stay:m
        =/  app-bend=bend:tarball  u.app-res
        ~&  >  ["%channel relay: found parent app at" app-bend]
        ;<  cfg=channel-config  bind:m  read-config
        ?:  |(=('' source.cfg) =('' chat-id.cfg))
          ~&  >>>  "%channel relay: missing config fields"
          stay:m
        ::  resolve source roads relative to parent app
        =/  source-prefix=tape
          =/  src=tape  (trip source.cfg)
          ?:  &(!=(~ src) =('/' (snag 0 src)))  src
          "{(render-bend app-bend)}{src}"
        =/  bot-msgs=road:tarball
          (cord-to-road:tarball (crip "{source-prefix}/messages/{(trip chat-id.cfg)}.json"))
        ::  watch source messages
        ;<  bot-view=view:nexus  bind:m  (keep:io /bot-msgs bot-msgs ~)
        =/  seen-count=@ud  (count-incoming bot-view)
        ~&  >  ["%channel relay: started, seen" seen-count "messages"]
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /bot-msgs)
        =/  new-count=@ud  (count-incoming upd)
        =/  new-msgs=(list [text=@t from=@t])
          (get-incoming-after upd seen-count)
        =.  seen-count  new-count
        ?~  new-msgs  $
        ~&  >  ["%channel relay: new messages" (lent new-msgs)]
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
        ;<  ~  bind:m  (over:io inbox-road [[/ %json] !>(updated)])
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
  ;<  =seen:nexus  bind:m  (peek:io road `%json)
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
::  render a bend as a relative road string
::
::  render a bend as a relative path string for cord-to-road
::  e.g. bend [2 %| /foo/bar/] -> "../../foo/bar/"
::
++  render-bend
  |=  =bend:tarball
  ^-  tape
  =/  ups=tape
    ?:  =(0 p.bend)  "./"
    %-  zing
    %+  turn  (gulf 1 p.bend)
    |=(* "../")
  ?-  -.q.bend
      %&
    =/  dir=tape  (segments path.p.q.bend)
    :(weld ups dir "/" (trip name.p.q.bend))
      %|
    =/  dir=tape  (segments p.q.bend)
    ?:  =(~ p.q.bend)  ups
    (weld ups dir)
  ==
::
++  segments
  |=  =path
  ^-  tape
  ?~  path  ""
  =/  first=tape  (trip i.path)
  |-
  ?~  t.path  first
  =/  next=tape  (trip i.t.path)
  $(t.path t.t.path, first :(weld first "/" next))
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
::  get incoming messages after a given count, with sender info
::
++  get-incoming-after
  |=  [=view:nexus skip=@ud]
  ^-  (list [text=@t from=@t])
  =/  msgs=(list json)  (extract-msgs view)
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
  |=  =view:nexus
  ^-  (list json)
  ?.  ?=([%file *] view)  ~
  =/  dat=json  (fall (mole |.(!<(json q.sage.view))) *json)
  ?:  ?=([%a *] dat)  p.dat
  ?.  ?=([%o *] dat)  ~
  =/  v  (~(get by p.dat) 'messages')
  ?.  ?=([~ %a *] v)  ~
  p.u.v
--
