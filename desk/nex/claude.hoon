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
      ::  clean up legacy api-requests, registry dir, registry.txt
      =.  ball  (~(del ba:tarball ball) [/ %'requests.claude-registry'])
      =.  ball  (~(del of ball) /api-requests)
      =.  ball  (~(del of ball) /registry)
      =.  ball  (~(del ba:tarball ball) [/ %'registry.txt'])
      ::  main.claude-registry — create if missing, preserve across restarts
      =?  ball  =(~ (~(get ba:tarball ball) [/ %'main.claude-registry']))
        (~(put ba:tarball ball) [/ %'main.claude-registry'] [~ %claude-registry !>(`registry`[%0 0 ~ %.y])])
      ::  weir.txt — live rendered view of parent directory weir
      =.  ball
        (~(put ba:tarball ball) [/ %'weir.txt'] [~ %txt !>(`wain`~['No weir set.'])])
      =?  ball  =(~ (~(get of ball) /ui))
        (~(put of ball) /ui [~ ~ ~])
      =.  ball
        %+  ~(put ba:tarball ball)  [/ui %'chat.html']
        [~ %manx !>((chat-page ~))]
      =?  ball  =(~ (~(get of ball) /ui/sse))
        (~(put of ball) /ui/sse [~ ~ ~])
      ::  migrate: last-message.json -> last-message.html
      =.  ball  (~(del ba:tarball ball) [/ui/sse %'last-message.json'])
      =.  ball  (~(del ba:tarball ball) [/ui/sse %'last-message.txt'])
      =.  ball
        (~(put ba:tarball ball) [/ui/sse %'last-message.html'] [~ %manx !>(*manx)])
      =.  ball
        (~(put ba:tarball ball) [/ui/sse %'status.json'] [~ %json !>((pairs:enjs:format ~[['loading' b+%.n] ['live' b+%.y]]))])
      [sand gain ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
      ::  /messages.claude-messages — inert store. Accepts pokes, appends, saves.
      ::
          [~ %'messages.claude-messages']
        ;<  ~  bind:m  (rise-wait:io prod "%claude chat: failed")
        |-
        ;<  =cage  bind:m  take-poke:io
        ?.  ?=(%claude-action p.cage)
          ~&  >  [%claude-chat %unknown-mark p.cage]
          $
        =/  =action  !<(action q.cage)
        ?:  ?=(%live -.action)  $       ::  not a message — skip
        ?:  ?=(%interrupt -.action)  $  ::  not a message — skip
        =/  [role=@t text=@t]
          ?-  -.action
              %say  ['user' text.action]
              %add  [role.action text.action]
          ==
        ?:  =('' text)  $
        ;<  msg=messages  bind:m  (get-state-as:io ,messages)
        =/  idx=@ud
          =/  top  (ram:mon messages.msg)
          ?~(top 0 +(key.u.top))
        =/  new=messages  msg(messages (put:mon messages.msg idx [role text]))
        ;<  ~  bind:m  (replace:io !>(new))
        $
      ::  /main.claude-registry — THE process. Handles user messages, Claude API,
      ::  everything. Messages file is inert state written via poke:io.
      ::
      ::  State: [%0 nex=@ud slots=(map @ud slot)]
      ::  Every outgoing operation gets a slot. Responses match by wire /slot/N.
      ::
      ::  Event loop multiplexes ALL events:
      ::  - Pokes: user messages (claude-action from UI)
      ::  - Peek/made/over/gone/pack/diff/sand/manu: async responses
      ::  - Bond/news/fell: subscription lifecycle
      ::
          [~ %'main.claude-registry']
        ;<  ~  bind:m  (rise-wait:io prod "%claude: failed")
        =/  msg-road=road:tarball  (cord-to-road:tarball './messages.claude-messages')
        ::  On restart, just resume. Keeps and flights survive — wires still route.
        ?:  ?=(%rise -.prod)
          ~&  >  %claude-registry-reboot
          (main-loop msg-road)
        (main-loop msg-road)
      ::  /weir.txt — live view of parent directory weir
      ::
          [~ %'weir.txt']
        ;<  ~  bind:m  (rise-wait:io prod "%claude weir: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /weir (cord-to-road:tarball '../') ~)
        ;<  ~  bind:m  (replace:io !>((render-weir init)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /weir)
        ;<  ~  bind:m  (replace:io !>((render-weir upd)))
        $
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
      ::  /ui/sse/last-message.html — watches messages, emits last as HTML
      ::
          [[%ui %sse ~] %'last-message.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claude sse: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /msgs (cord-to-road:tarball '../../messages.claude-messages') ~)
        ?.  ?=([%file *] init)  $
        =/  msg=messages  !<(messages q.cage.init)
        =/  last=(unit [key=@ud val=message])  (ram:mon messages.msg)
        =/  init-manx=manx  ?~(last *manx (msg-to-manx val.u.last))
        ;<  ~  bind:m  (replace:io !>(init-manx))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /msgs)
        ?.  ?=([%file *] upd)  $
        =/  msg=messages  !<(messages q.cage.upd)
        =/  last=(unit [key=@ud val=message])  (ram:mon messages.msg)
        ?~  last  $
        ;<  ~  bind:m  (replace:io !>((msg-to-manx val.u.last)))
        $
      ::  /ui/sse/status.json — loading state, updated by message fiber
      ::
          [[%ui %sse ~] %'status.json']
        ;<  ~  bind:m  (rise-wait:io prod "%claude status: failed")
        stay:m
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana
            'Inert subdirectory under the claude nexus. No special behavior — exists as part of the chat system directory structure.'
            ~
          %-  crip
          """
          CLAUDE NEXUS — AI chat via Anthropic API

          Flat-chat architecture: one main process (main.claude-registry) drives
          everything. It pokes the inert message store, calls the Anthropic API,
          dispatches tool/api actions, and manages keep subscriptions.

          FILES:
            config.json             API key, model, max_tokens (JSON)
            messages.claude-messages Ordered message log (claude-messages mark)
            custom-prompt.txt       Prepended to system prompt on every API call
            main.claude-registry    Async slot registry — every request gets a slot
            weir.txt                Live-rendered view of parent directory sandbox rules

          DIRECTORIES:
            ui/                     Web interface
            ui/chat.html            Full chat page (re-rendered on each message)
            ui/sse/                 SSE endpoints for live streaming
            ui/sse/last-message.html  Last message as HTML (SSE stream source)
            ui/sse/status.json      Loading indicator state (JSON)

          PROCESSES:
            messages.claude-messages  Inert store. Accepts %claude-action pokes,
                                      appends [role content] to the mop. That's all.
            main.claude-registry      THE process. Multiplexes ALL events:
                                      pokes (user messages), peek/ack responses,
                                      bond/news/fell (subscription lifecycle).
                                      Every outgoing dart gets a slot with wire
                                      /slot/N. Responses match back by wire.
            weir.txt                  Watches parent dir via keep ../  Renders
                                      sandbox rules as text on each change.
            ui/chat.html              Watches messages via keep. Re-renders full
                                      page (server-side Sail) on each new message.
            ui/sse/last-message.html  Watches messages. Emits last message as HTML
                                      fragment for SSE consumers. This is how the
                                      web UI gets live updates without polling.
            ui/sse/status.json        Passive. Written by main process to signal
                                      loading state to the UI.

          API (via <api> tags in chat):
            Paths support ./ and ../ relative to the nexus.
            READ:  file, kids, tree, sand, weir, manu, keep, drop
            WRITE: make, over, rmf, dir, rmd, poke, diff, setweir, rmweir
            All paths are parsed by cord-to-road — trailing / means directory,
            no trailing / means file. Relative paths resolve from the nexus.

          COORDINATION:
            - Server nexus routes HTTP to /ui/ for the web interface
            - MCP nexus handles <tool> dispatches
            - Keep subscriptions use tarball internal subs (keep:io / drop:io)
            - Messages file is the single source of truth for chat history
            - UI files watch messages and re-render reactively
          """
            [%ui ~]
          %-  crip
          """
          ui/ — Web chat interface directory.

          Contains the server-rendered chat page and SSE streaming endpoints.
          The server nexus binds /grubbery/claude/ to route HTTP requests here.

          FILES:
            chat.html              Full chat page. Mark: manx (Sail/HTML).
                                   Re-rendered server-side on every new message
                                   via a keep on ../messages.claude-messages.
                                   Served as the main page at /grubbery/claude/.

          SUBDIRECTORIES:
            sse/                   Server-sent event sources for live UI updates.
          """
            [%ui %sse ~]
          %-  crip
          """
          ui/sse/ — SSE streaming endpoints for live chat updates.

          FILES:
            last-message.html    Last chat message as an HTML fragment. Mark: manx.
                                 Watches ../../messages.claude-messages via keep.
                                 On each new message, re-renders just the latest
                                 message as HTML. The web UI subscribes to this via
                                 SSE to get live message streaming without polling
                                 or re-fetching the full page.

            status.json          Loading indicator. Mark: json. \{"loading": true/false}.
                                 Written by main.claude-registry when an API call
                                 starts/finishes. The UI reads this to show/hide
                                 a spinner.
          """
        ==
          %|
        ?+  rail.p.mana
            'File under the claude nexus.'
            [~ %'config.json']
          %-  crip
          """
          config.json — API configuration. Mark: json.

          FIELDS:
            api_key     @t   Anthropic API key (sk-ant-...). Required.
            model       @t   Model ID (e.g. claude-sonnet-4-20250514)
            max_tokens  @ud  Max response tokens per API call (default 4096)

          READ:  peek, or api action "file ./config.json"
          WRITE: over with full JSON body, or api action "over ./config.json"

          If api_key is empty, the first chat message returns an error.
          """
            [~ %'messages.claude-messages']
          %-  crip
          """
          messages.claude-messages — Chat history. Mark: claude-messages.

          TYPE: [%0 messages=((mop @ud message) lth)]
          Each message: [role=@t content=@t]
          Roles: 'user', 'assistant', 'system'
          Content: plain text or XML protocol tags

          POKE: %claude-action mark
            [%say text=@t]           Send a user message (triggers API call)
            [%add role=@t text=@t]   Inject a message with explicit role

          KEEP: Subscribe to get live updates as messages are appended.
                The UI uses this for reactive rendering.

          This file is an inert store — it only appends messages on poke.
          All logic (API calls, tool dispatch, etc.) lives in main.claude-registry,
          which pokes this file to record messages.
          """
            [~ %'custom-prompt.txt']
          %-  crip
          """
          custom-prompt.txt — Custom system prompt. Mark: txt (wain).

          Prepended to the built-in system prompt on every Anthropic API call.
          Use this to give Claude persistent instructions, personality, context,
          or constraints that survive across conversations. Empty by default.

          READ:  peek, or api action "file ./custom-prompt.txt"
          WRITE: over with text body, or api action "over ./custom-prompt.txt"
          """
            [~ %'main.claude-registry']
          %-  crip
          """
          main.claude-registry — Main process + request tracker. Mark: claude-registry.

          TYPE: [%0 nex=@ud keeps=(map @t @ud) flights=(map @ud [action=@t path=@t])]
            nex:     Next flight ID counter
            keeps:   Active subscriptions keyed by path, value is update count
            flights: In-flight one-shot requests keyed by ID

          This is THE process — it runs the entire chat loop:
          1. Waits for pokes (user messages) or news (keep updates)
          2. On user message: appends to messages, calls Anthropic API, parses
             response XML, dispatches actions, loops until pause/done
          3. On keep update: formats as <api> tag, appends to messages
          4. Tracks all active API requests in the registry state

          Keeps and flights survive process restarts (wires still route).
          Do not write to this file directly — it is self-managed.
          The registry state is included in the system prompt so Claude
          knows what subscriptions and requests are active.
          """
            [~ %'weir.txt']
          %-  crip
          """
          weir.txt — Live sandbox rules display. Mark: txt.

          Watches the parent directory (../) via keep subscription.
          On each change, re-renders the weir (sandbox access rules) as
          human-readable text. Included in the system prompt so Claude
          knows what API operations it is allowed to perform.

          This is a derived view — do not edit directly.
          To change sandbox rules, use setweir/rmweir on the parent directory.
          """
            [~ %'ver.ud']
          'ver.ud — Nexus schema version counter. Mark: ud. Incremented on structural migrations in on-load.'
            [[%ui ~] %'chat.html']
          %-  crip
          """
          ui/chat.html — Full chat page. Mark: manx (Sail HTML).

          Server-rendered page showing the complete chat history with distinct
          styling for each message type (thoughts, API calls, tool use, errors,
          user messages, assistant messages). Re-rendered on every new message
          via a keep subscription on ../messages.claude-messages.

          Features: message filtering, prompt editor modal, registry viewer,
          auto-resizing input, keyboard shortcuts, loading indicators.

          Served at /grubbery/claude/ via the server nexus HTTP binding.
          """
            [[%ui %sse ~] %'last-message.html']
          %-  crip
          """
          ui/sse/last-message.html — SSE message stream. Mark: manx.

          Watches ../../messages.claude-messages via keep. On each new message,
          re-renders just the latest message as an HTML fragment. The web UI
          subscribes to this file's SSE stream to get live updates — each
          event contains one rendered message that gets appended to the page
          without a full reload.

          This is the live streaming backbone of the chat UI.
          """
            [[%ui %sse ~] %'status.json']
          %-  crip
          """
          ui/sse/status.json — Loading state. Mark: json. \{"loading": true/false}.

          Written by main.claude-registry when an Anthropic API call starts
          (loading: true) and finishes (loading: false). The web UI reads
          this via SSE to show/hide a spinner during API calls.

          Passive process — does not watch anything, just holds state.
          """
        ==
      ==
    --
::  helper core
::
|%
::  Main event loop — handles user messages, Claude API, keeps, everything
::
::  Multiplexes ALL events: pokes, peeks, acks, keeps, etc.
::  Every outgoing dart has a slot in the registry. Every response
::  matches back by wire /slot/N, formats a message, and calls claude-turn.
::
++  main-loop
  |=  msg-road=road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  ev=main-event  bind:m  take-main-event
  ;<  reg=registry  bind:m  (get-state-as:io ,registry)
  ?-    -.ev
  ::  User message from UI
  ::
      %poke
    =/  =action  !<(action q.cage.ev)
    ?:  ?=(%interrupt -.action)
      ~&  >  %claude-interrupt-no-op
      $
    ?:  ?=(%live -.action)
      ~&  >  [%claude-live flag.action]
      ;<  ~  bind:m  (set-live flag.action)
      $
    =/  [role=@t text=@t]
      ?-  -.action
          %say  ['user' text.action]
          %add  [role.action text.action]
      ==
    ?:  =('' text)  $
    ~&  >  [%claude-say (end [3 80] text)]
    ::  User message always resumes live mode
    ?.  live.reg
      ~&  >  %claude-resuming
      ;<  ~  bind:m  (set-live %.y)
      ;<  ~  bind:m  (append-to-msgs msg-road role text)
      ;<  ~  bind:m  (claude-turn msg-road)
      $
    ;<  ~  bind:m  (append-to-msgs msg-road role text)
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Peek result (file, kids, tree, sand, weir)
  ::
      %peek
    =/  id-slot  (get-slot wire.ev slots.reg)
    ?~  id-slot
      ~&  >>>  [%claude-stale-peek wire.ev]
      $
    =/  [id=@ud =slot]  u.id-slot
    ;<  ~  bind:m  (clear-slot id)
    ;<  [result=@t rev=(unit @ud)]  bind:m  (format-peek slot seen.ev)
    ;<  ~  bind:m  (append-msg msg-road slot result rev)
    ?.  live.reg  $
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Ack responses (make, over, cull, poke, diff, sand)
  ::
      %made
    ;<  ~  bind:m  (handle-ack msg-road wire.ev err.ev slots.reg live.reg)
    $
      %over
    ;<  ~  bind:m  (handle-ack msg-road wire.ev err.ev slots.reg live.reg)
    $
      %gone
    ;<  ~  bind:m  (handle-ack msg-road wire.ev err.ev slots.reg live.reg)
    $
      %pack
    ;<  ~  bind:m  (handle-ack msg-road wire.ev err.ev slots.reg live.reg)
    $
      %diff
    ;<  ~  bind:m  (handle-ack msg-road wire.ev err.ev slots.reg live.reg)
    $
      %sand
    ;<  ~  bind:m  (handle-ack msg-road wire.ev err.ev slots.reg live.reg)
    $
  ::  Manu documentation result
  ::
      %manu
    =/  id-slot  (get-slot wire.ev slots.reg)
    ?~  id-slot
      ~&  >>>  [%claude-stale-manu wire.ev]
      $
    =/  [id=@ud =slot]  u.id-slot
    ;<  ~  bind:m  (clear-slot id)
    =/  result=@t
      ?:  ?=(%& -.res.ev)  p.res.ev
      (crip "ERROR: manu failed")
    ;<  ~  bind:m  (append-msg msg-road slot result ~)
    ?.  live.reg  $
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Keep subscription acked — initial view
  ::
      %bond
    =/  id-slot  (get-slot wire.ev slots.reg)
    ?~  id-slot
      ~&  >>>  [%claude-stale-bond wire.ev]
      $
    =/  [id=@ud =slot]  u.id-slot
    ?:  ?=(%| -.now.ev)
      ;<  ~  bind:m  (clear-slot id)
      ;<  ~  bind:m  (append-msg msg-road slot 'ERROR: Subscription failed' ~)
      ?.  live.reg  $
      ;<  ~  bind:m  (claude-turn msg-road)
      $
    ;<  ~  bind:m  (format-view msg-road path.slot p.now.ev %.y)
    ?.  live.reg  $
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Keep subscription update
  ::
      %news
    =/  id-slot  (get-slot wire.ev slots.reg)
    ?~  id-slot
      ~&  >>>  [%claude-stale-news wire.ev]
      $
    =/  [id=@ud =slot]  u.id-slot
    ::  Suppress updates for subscriptions being dropped
    ?:  =(action.slot 'drop')
      ~&  >  [%claude-news-after-drop path.slot]
      $
    ;<  ~  bind:m  (format-view msg-road path.slot view.ev %.n)
    ?.  live.reg  $
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Subscription ended (drop, kicked, deleted, weir change)
  ::
      %fell
    =/  id-slot  (get-slot wire.ev slots.reg)
    ?~  id-slot
      ~&  >>>  [%claude-stale-fell wire.ev]
      $
    =/  [id=@ud =slot]  u.id-slot
    ;<  ~  bind:m  (clear-slot id)
    =/  result=@t
      ?:  =(action.slot 'drop')  'Unsubscribed'
      'SUBSCRIPTION ENDED'
    ;<  ~  bind:m  (append-msg msg-road slot result ~)
    ?.  live.reg  $
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Dart vetoed by sandbox
  ::
      %veto
    ~&  >>>  [%claude-veto dart.ev]
    $
  ==
::  Claude conversation turn — call API, parse response, dispatch
::  Called after any event that should trigger Claude to respond.
::
++  claude-turn
  |=  msg-road=road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  errs=@ud  0
  =/  thinks=@ud  0
  |-  ::  inner loop for agent turns
  ;<  msg=messages  bind:m  (read-msgs msg-road)
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
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<error>No API key set. Add your Anthropic API key in /config/creds or /claude.claude/config.json</error>')
      (pure:m ~)
    =/  model=@t       (jget-t cfg 'model' 'claude-sonnet-4-20250514')
    =/  max-tokens=@ud  (jget-n cfg 'max_tokens' 4.096)
    =/  max-messages=@ud  (jget-n cfg 'max_messages' 50)
    ::  build system prompt
    ;<  custom-seen=seen:nexus  bind:m
      (peek:io /prompt (cord-to-road:tarball './custom-prompt.txt') `%txt)
    ;<  weir-seen=seen:nexus  bind:m
      (peek:io /weir (cord-to-road:tarball './weir.txt') `%txt)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  custom=@t
      ?.  ?=([%& %file *] custom-seen)  ''
      =/  =wain  !<(wain q.cage.p.custom-seen)
      ?~(wain '' (of-wain:format wain))
    ::  Registry state rendered to text for system prompt
    ;<  reg=registry  bind:m  (get-state-as:io ,registry)
    =/  reg-wain=wain
      =/  slot-list=(list [@ud slot])  ~(tap by slots.reg)
      :-  ?:(live.reg 'REGISTRY: LIVE' 'REGISTRY: HALTED (waiting for user message to resume)')
      ?~  slot-list  ~['No active requests.']
      :-  'ACTIVE REQUESTS:'
      %+  turn  slot-list
      |=  [id=@ud =slot]
      (crip "  [{(a-co:co id)}] {(trip action.slot)} {(trip path.slot)}")
    =/  reg-text=@t  (of-wain:format reg-wain)
    =/  weir-text=@t
      ?.  ?=([%& %file *] weir-seen)  ''
      =/  =wain  !<(wain q.cage.p.weir-seen)
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
          '\0a\0a'
          reg-text
          ?:(=('' weir-text) '' (rap 3 ~['\0a\0a' weir-text]))
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
    ;<  reg=registry  bind:m  (get-state-as:io ,registry)
    =/  loading-on=json   (pairs:enjs:format ~[['loading' b+%.y] ['live' b+live.reg]])
    =/  loading-off=json  (pairs:enjs:format ~[['loading' b+%.n] ['live' b+live.reg]])
    ;<  ~  bind:m  (over:io /status status-road json+!>(loading-on))
    =/  =request:http
      :^  %'POST'  'https://api.anthropic.com/v1/messages'
        :~  ['content-type' 'application/json']
            ['x-api-key' api-key]
            ['anthropic-version' '2023-06-01']
        ==
      `(as-octs:mimes:html body-cord)
    ;<  response=(unit @t)  bind:m  (fetch-or-interrupt request)
    ;<  ~  bind:m  (over:io /status status-road json+!>(loading-off))
    ?~  response
      ~&  >  %claude-interrupted
      ;<  ~  bind:m  (set-live %.n)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<error>Interrupted by user.</error>')
      (pure:m ~)
    ~&  >  %claude-got-response
    ::  check for API-level errors
    =/  err=(unit @t)  (extract-error u.response)
    ?^  err
      ~&  >>>  [%claude-api-error u.err]
      ;<  ~  bind:m  (set-live %.n)
      ;<  ~  bind:m  (append-to-msgs msg-road 'assistant' (cat 3 '<error>' (cat 3 u.err '</error>')))
      (pure:m ~)
    =/  reply=@t  (extract-reply u.response)
    ?:  =('' reply)
      ~&  >>>  [%claude-empty-reply u.response]
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<error>Empty response from Claude API — no text content blocks returned.</error>')
      ?:  (gte +(errs) 3)
        ~&  >>>  %claude-error-limit-reached
        ;<  ~  bind:m  (set-live %.n)
        (pure:m ~)
      $(errs +(errs))
    ::  parse XML tags from response
    =/  tags=(list response-tag)  (parse-responses reply)
    ::  process tags sequentially
    =|  did-think=?
    |-
    ?~  tags
      ~&  >>>  [%claude-bad-tag reply]
      =/  err-msg=@t
        (rap 3 ~['<error>Invalid response — must be valid XML tags. Your response was: ' reply '</error>'])
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' err-msg)
      ?:  (gte +(errs) 3)
        ~&  >>>  %claude-error-limit-reached
        ;<  ~  bind:m  (set-live %.n)
        (pure:m ~)
      $(errs +(errs))
    ::  valid tag(s) — store and dispatch
    ;<  ~  bind:m  (append-to-msgs msg-road 'assistant' reply)
    ;<  ~  bind:m  (sleep:io ~s0..0001)
    =/  tag=response-tag  i.tags
    =/  more=?  ?=(^ t.tags)
    ?-  -.tag
        %thought
      ~&  >  [%claude-thought (end [3 80] text.tag)]
      =.  thinks  +(thinks)
      ?:  more  $(tags t.tags, did-think %.y)
      ::  last tag is thought — continue
      ?:  (gte thinks 5)
        ~&  >>>  %claude-thought-cap-reached
        ;<  ~  bind:m  (sleep:io ~s0..0001)
        ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<error>Thought cap reached (5). You must respond with message, wait, or done.</error>')
        $(errs 0, thinks 0)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(errs 0)
    ::
        %tool
      ~&  >  [%claude-tool (lent calls.tag) %calls continue.tag]
      ?:  more  $(tags t.tags, thinks 0)
      ?.  continue.tag  (pure:m ~)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(thinks 0)
    ::
        %api
      ~&  >  [%claude-api action.tag path.tag]
      ;<  ~  bind:m  (handle-api msg-road action.tag path.tag body.tag)
      ?:  more  $(tags t.tags, thinks 0)
      ?.  continue.tag  (pure:m ~)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(thinks 0)
    ::
        %notify
      ~&  >  [%claude-notify continue.tag]
      ?:  more  $(tags t.tags, thinks 0)
      ?.  continue.tag  (pure:m ~)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(thinks 0)
    ::
        %message
      ~&  >  %claude-message
      ?:  more  $(tags t.tags, thinks 0)
      ?.  continue.tag  (pure:m ~)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(thinks 0)
    ::
        %wait
      ~&  >  %claude-wait
      ?:  more  $(tags t.tags)
      (pure:m ~)
    ::
        %done
      ~&  >  [%claude-done output.tag]
      (pure:m ~)  ::  terminal — even if more tags follow
    ==
::  Handle API request — fire-and-forget
::
::  Allocates a slot, sends the dart, returns immediately.
::  The response arrives as a main-event and is handled in main-loop.
::
++  handle-api
  |=  [msg-road=road:tarball act=@t api-path=@t body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  =road:tarball  (cord-to-road:tarball api-path)
  ;<  reg=registry  bind:m  (get-state-as:io ,registry)
  ~&  >  [%claude-api-dispatch act api-path]
  ::  drop — find existing keep slot, send drop dart on its wire
  ::
  ?:  =(act 'drop')
    =/  keep-id=(unit @ud)
      =/  slist  ~(tap by slots.reg)
      |-
      ?~  slist  ~
      =/  [id=@ud =slot]  i.slist
      ?:  &(=('keep' action.slot) =(api-path path.slot))
        `id
      $(slist t.slist)
    ?~  keep-id
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="drop" path="' api-path '">Not subscribed to this path.</api>']))
    ::  Mark slot as "drop" so fell handler knows it was user-initiated
    ;<  ~  bind:m
      (replace:io !>(`registry`reg(slots (~(put by slots.reg) u.keep-id ['drop' api-path]))))
    =/  keep-wire=wire  /slot/(scot %ud u.keep-id)
    (send-dart:io %node keep-wire road %drop ~)
  ::  keep — check for duplicate
  ::
  ?:  =(act 'keep')
    =/  already=?
      %+  lien  ~(tap by slots.reg)
      |=  [id=@ud act=@t pax=@t]
      &(=('keep' act) =(api-path pax))
    ?:  already
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="keep" path="' api-path '">Already subscribed to this path.</api>']))
    =/  id=@ud  nex.reg
    =/  slot-wire=wire  /slot/(scot %ud id)
    ;<  ~  bind:m
      (replace:io !>(`registry`reg(nex +(id), slots (~(put by slots.reg) id [act api-path]))))
    (send-dart:io %node slot-wire road %keep ~)
  ::  All other actions — allocate slot, fire dart
  ::
  =/  id=@ud  nex.reg
  =/  slot-wire=wire  /slot/(scot %ud id)
  =/  new-reg=registry  reg(nex +(id), slots (~(put by slots.reg) id [act api-path]))
  ;<  ~  bind:m  (replace:io !>(`registry`new-reg))
  ?+    act
    ::  Unknown action — deregister and report error
    ;<  ~  bind:m  (replace:io !>(`registry`new-reg(slots (~(del by slots.reg) id))))
    %-  append-to-msgs  :+  msg-road  'user'
    (rap 3 ~['<api action="' act '" path="' api-path '">ERROR: Unknown action. Valid: file, kids, tree, sand, weir, manu, keep, drop, make, over, rmf, dir, rmd, poke, diff, setweir, rmweir</api>'])
  ::  reads
      %'file'   (send-dart:io %node slot-wire road %peek ~ ~ %.n)
      %'kids'   (send-dart:io %node slot-wire road %peek ~ ~ %.n)
      %'tree'   (send-dart:io %node slot-wire road %peek ~ ~ %.n)
      %'sand'   (send-dart:io %node slot-wire road %peek ~ ~ %.n)
      %'weir'   (send-dart:io %node slot-wire road %peek ~ ~ %.n)
  ::  manu
      %'manu'   (send-dart:io %manu slot-wire |+road)
  ::  writes
      %'make'
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    (send-dart:io %node slot-wire road %make |+[%.n mime+!>(mime) ~])
      %'dir'
    (send-dart:io %node slot-wire road %make &+[*sand:nexus *gain:nexus `[~ ~ ~] ~])
      %'over'
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    (send-dart:io %node slot-wire road %over mime+!>(mime))
      %'rmf'   (send-dart:io %node slot-wire road %cull ~)
      %'rmd'   (send-dart:io %node slot-wire road %cull ~)
      %'poke'
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    (send-dart:io %node slot-wire road %poke mime+!>(mime))
      %'diff'
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    (send-dart:io %node slot-wire road %diff mime+!>(mime))
      %'setweir'
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      ;<  ~  bind:m  (replace:io !>(`registry`new-reg(slots (~(del by slots.reg) id))))
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="setweir" path="' api-path '">ERROR: Invalid JSON body</api>']))
    =/  parsed=(each weir:nexus tang)
      (mule |.((weir-from-json:nexus u.jon)))
    ?:  ?=(%| -.parsed)
      ;<  ~  bind:m  (replace:io !>(`registry`new-reg(slots (~(del by slots.reg) id))))
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="setweir" path="' api-path '">ERROR: Invalid weir JSON</api>']))
    (send-dart:io %node slot-wire road %sand `p.parsed)
      %'rmweir'
    (send-dart:io %node slot-wire road %sand ~)
  ==
::  Multiplex ALL events — pokes, responses, subscriptions
::
+$  main-event
  $%  [%poke =cage]
      [%peek =wire =seen:nexus]
      [%made =wire err=(unit tang)]
      [%over =wire err=(unit tang)]
      [%gone =wire err=(unit tang)]
      [%pack =wire err=(unit tang)]
      [%diff =wire err=(unit tang)]
      [%sand =wire err=(unit tang)]
      [%manu =wire res=(each @t tang)]
      [%bond =wire now=(each view:nexus tang)]
      [%news =wire =view:nexus]
      [%fell =wire]
      [%veto =dart:nexus]
  ==
++  take-main-event
  =/  m  (fiber:fiber:nexus ,main-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  ?=(%claude-action p.cage.u.in)
      [%skip ~]
    [%done %poke cage.u.in]
      [~ %peek * *]   [%done %peek wire.u.in seen.u.in]
      [~ %made * *]   [%done %made wire.u.in err.u.in]
      [~ %over * *]   [%done %over wire.u.in err.u.in]
      [~ %gone * *]   [%done %gone wire.u.in err.u.in]
      [~ %pack * *]   [%done %pack wire.u.in err.u.in]
      [~ %diff * *]   [%done %diff wire.u.in err.u.in]
      [~ %sand * *]   [%done %sand wire.u.in err.u.in]
      [~ %manu * *]   [%done %manu wire.u.in res.u.in]
      [~ %bond * *]   [%done %bond wire.u.in now.u.in]
      [~ %news * *]   [%done %news wire.u.in view.u.in]
      [~ %fell *]     [%done %fell wire.u.in]
      [~ %veto *]     [%done %veto dart.u.in]
  ==
++  system-prompt
  ^~
  %-  of-wain:format
  :~  'You are Claude, an AI assistant running natively on an Urbit ship.'
      'Urbit is a peer-to-peer operating system. You run as a Hoon application on the user\'s personal server.'
      ''
      '=== CRITICAL RULES (read these first) ==='
      ''
      'XML TAGS ONLY. Your ENTIRE output must be one or more XML tags — nothing else.'
      'NO PLAIN TEXT OUTSIDE OF TAGS. Every piece of output must be inside a tag.'
      'Multiple tags in one response are processed left-to-right. The last tag\'s continue flag'
      'determines whether you get another turn. Earlier tags are processed unconditionally.'
      ''
      'FLOW CONTROL:'
      '- You can include multiple tags in one response. They are processed left-to-right.'
      '  The LAST tag\'s continue flag determines whether you get another turn.'
      '  Example: <thought>Let me check.</thought><api action="file" path="./x.txt"/>'
      '  This thinks AND reads in a single response — no round-trip needed.'
      '- <thought> for internal reasoning. ALWAYS follow thoughts with action or message.'
      '  Do not chain more than 2-3 thoughts. After 5, the system forces a non-thought tag.'
      '- <message> is how you talk to the user. If you want to say something, say it.'
      '  <message>Text.</message> — says it, then pauses for user input or events.'
      '  <message>Text.</message><api .../> — says it AND acts in one response.'
      '- <wait/> pauses with no output. Use this when you genuinely have nothing to say.'
      '  Do NOT narrate what you are doing. Do NOT explain your own tag choices.'
      '- <done> ends the session permanently. Optional body (JSON or text).'
      '- continue="true" on the LAST tag means you get another turn immediately.'
      '  continue="false" (default) on the LAST tag means pause until user message or event.'
      ''
      '<continue/> is a SYSTEM message, NOT from the user. It means "your previous response was'
      'processed — now respond again." Do NOT treat it as user input. Do NOT ask the'
      'user to clarify. Do NOT say "the user sent continue." Just proceed with your next response.'
      'With multi-tag responses, you need fewer continues — put multiple tags in one response.'
      ''
      'API results appear under the USER ROLE because that is how the system injects responses.'
      'They are REAL system-generated messages. Do NOT assume they are fake or user-fabricated.'
      ''
      '=== EXAMPLES ==='
      ''
      'Read a file:          <api action="file" path="./data.txt"/>'
      'Read a directory:     <api action="kids" path="./"/>'
      'Create a file:        <api action="make" path="./notes.txt">Hello world</api>'
      'Overwrite a file:     <api action="over" path="./notes.txt">New content</api>'
      'Think then read:      <thought>I should check what files exist.</thought><api action="kids" path="./"/>'
      'Speak then read:      <message>Let me look that up.</message><api action="file" path="./config.json"/>'
      'Read two files:       <api action="file" path="./a.txt"/><api action="file" path="./b.txt"/>'
      'Subscribe:            <api action="keep" path="./logs/"/>'
      'Unsubscribe:          <api action="drop" path="./logs/"/>'
      'Use a tool:           <tool>{"name":"echo","args":{"message":"hi"}}</tool>'
      'Nothing to say:       <wait/>'
      'End session:          <done>Task complete.</done>'
      ''
      'WRONG (text+tag):     Let me check. <api action="file" path="./x"/>'
      'WRONG (no close tag): <api action="file" path="./x">'
      ''
      '=== TAG REFERENCE ==='
      ''
      '<thought>Internal reasoning. Not shown to user.</thought>'
      '<message>Text shown to user.</message>'
      '<message continue="true">Text shown, then you get another turn.</message>'
      '<wait/>'
      '<done>Optional final output.</done>'
      '<tool continue="true">{"name":"tool_name","args":{"key":"value"}}</tool>'
      '  Multiple: <tool>[{"name":"a","args":{}},{"name":"b","args":{}}]</tool>'
      '<api action="ACTION" path="/path" continue="true">optional body</api>  (closing tag REQUIRED)'
      '<notify continue="true">payload</notify>'
      ''
      '=== API REFERENCE ==='
      ''
      'The grubbery is a ball — a nested filesystem of typed files (grubs) and directories.'
      'Files have marks (types) like hoon, txt, json, mime. The system auto-converts to text.'
      ''
      'PATHS: Trailing slash = directory, no trailing slash = file. This matters!'
      '  /path/to/name.ext  — file (name.ext in /path/to/)'
      '  /path/to/dir/      — directory'
      '  ./relative          — relative to this nexus (file)'
      '  ./relative/         — relative to this nexus (directory)'
      '  ../up/              — up one level then into directory'
      'The system parses paths strictly. "ui/sse" is a FILE named sse. "ui/sse/" is a DIRECTORY.'
      ''
      'READ actions (no body needed, self-closing OK):'
      '  file  /path/to/name.ext  — read file content (auto-converted to text)'
      '  kids  /path/             — list immediate files + subdirs as JSON'
      '  tree  /path/             — recursive tree as JSON'
      '  sand  /path/             — directory permissions as JSON'
      '  weir  /path/             — single directory access rule as JSON'
      '  manu  /path/to/name.ext  — documentation for a file (from nearest nexus)'
      '  manu  /path/to/dir/     — documentation for a directory (from nearest nexus)'
      '  keep  /path/             — subscribe to changes (long-lived, streams updates)'
      '  drop  /path/             — unsubscribe from a keep subscription'
      ''
      'WRITE actions (body = text content or JSON):'
      '  make  /path/to/name.ext  — create new file (body = content, mark from extension)'
      '  over  /path/to/name.ext  — overwrite existing file (body = new content)'
      '  rmf   /path/to/name.ext  — delete file'
      '  dir   /path/             — create directory'
      '  rmd   /path/             — delete directory'
      '  poke  /path/to/name.ext  — poke file process (body = payload)'
      '  diff  /path/to/name.ext  — diff file (body = diff payload)'
      '  setweir /path/           — set directory access rule (body = weir JSON)'
      '  rmweir  /path/           — clear directory access rule'
      ''
      'RESULTS: All actions are async. Results arrive as user-role messages:'
      '  <api action="file" path="/the/path">content or error</api>'
      ''
      'WEIR (permissions): make (create/delete), poke (write/modify), peek (read).'
      'Each field lists allowed roads. Empty = no restrictions. Your weir is in LIVE CONTEXT below.'
      ''
      'ACTIVE REQUESTS: The registry state is shown in LIVE CONTEXT below.'
      'ALL api actions are async — results arrive as user-role messages when ready.'
      'keep subscriptions stay active until you drop them or they are kicked.'
      'drop cancels a keep by path: <api action="drop" path="/same/path"/>'
  ==
::  Registry helpers — slot lookup and cleanup
::
++  get-slot
  |=  [=wire slots=(map @ud slot)]
  ^-  (unit [@ud slot])
  ?.  ?=([%slot @ *] wire)  ~
  =/  id=(unit @ud)  (slaw %ud i.t.wire)
  ?~  id  ~
  =/  s=(unit slot)  (~(get by slots) u.id)
  ?~  s  ~
  `[u.id u.s]
::
++  clear-slot
  |=  id=@ud
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  reg=registry  bind:m  (get-state-as:io ,registry)
  (replace:io !>(`registry`reg(slots (~(del by slots.reg) id))))
::  Fetch with interrupt: send HTTP request, wait for response OR interrupt poke.
::  Returns ~ on interrupt, (some body) on HTTP response.
::
++  fetch-or-interrupt
  |=  =request:http
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  ~  bind:m  (send-request:io request)
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
    ::  Interrupt poke — consumed, returns ~
    ::
      [~ %poke * *]
    =/  =action  !<(action q.cage.u.in)
    ?.  ?=(%interrupt -.action)
      [%skip ~]
    [%done ~]
    ::  HTTP response — extract body, return (some body)
    ::
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%done ~]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    =/  =client-response:iris  client-response.sign.u.in
    ?>  ?=(%finished -.client-response)
    =/  body=@t
      ?~(full-file.client-response '' q.data.u.full-file.client-response)
    [%done `body]
  ==
::
++  set-live
  |=  flag=?
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  reg=registry  bind:m  (get-state-as:io ,registry)
  ;<  ~  bind:m  (replace:io !>(`registry`reg(live flag)))
  =/  status-road=road:tarball  (cord-to-road:tarball './ui/sse/status.json')
  =/  =json  (pairs:enjs:format ~[['loading' b+%.n] ['live' b+flag]])
  (over:io /status status-road json+!>(json))
::
++  append-msg
  |=  [msg-road=road:tarball =slot result=@t rev=(unit @ud)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rev-attr=@t
    ?~  rev  ''
    (crip " rev=\"{(a-co:co u.rev)}\"")
  =/  msg=@t  (rap 3 ~['<api action="' action.slot '" path="' path.slot '"' rev-attr '>' result '</api>'])
  (append-to-msgs msg-road 'user' msg)
::  Format peek response based on slot action
::
++  format-peek
  |=  [=slot =seen:nexus]
  =/  m  (fiber:fiber:nexus ,[@t (unit @ud)])
  ^-  form:m
  ?+    action.slot
    (pure:m [(crip "ERROR: Unknown read action {(trip action.slot)}") ~])
  ::
      %'file'
    ?.  ?=([%& %file *] seen)
      (pure:m [(crip "ERROR: Not found: {(trip path.slot)}") ~])
    ;<  content=@t  bind:m  (cage-to-txt cage.p.seen)
    (pure:m [content `ud.file.sack.p.seen])
  ::
      %'kids'
    ?.  ?=([%& %ball *] seen)
      (pure:m [(crip "ERROR: Not found: {(trip path.slot)}") ~])
    =/  b=ball:tarball  ball.p.seen
    =/  files=(list @ta)
      ?~(fil.b ~ ~(tap in ~(key by contents.u.fil.b)))
    =/  dirs=(list @ta)  ~(tap in ~(key by dir.b))
    =/  result=json
      %-  pairs:enjs:format
      :~  ['files' [%a (turn files |=(n=@ta s+n))]]
          ['dirs' [%a (turn dirs |=(n=@ta s+n))]]
      ==
    (pure:m [(en:json:html result) ~])
  ::
      %'tree'
    ?.  ?=([%& %ball *] seen)
      (pure:m [(crip "ERROR: Not found: {(trip path.slot)}") ~])
    (pure:m [(en:json:html (tree-to-json:tarball (ball-to-tree:tarball ball.p.seen))) ~])
  ::
      %'sand'
    ?.  ?=([%& %ball *] seen)
      (pure:m [(crip "ERROR: Not found: {(trip path.slot)}") ~])
    (pure:m [(en:json:html (sand-to-json:nexus sand.p.seen)) ~])
  ::
      %'weir'
    ?.  ?=([%& %ball *] seen)
      (pure:m [(crip "ERROR: Not found: {(trip path.slot)}") ~])
    =/  =weir:nexus  (fall fil.sand.p.seen *weir:nexus)
    (pure:m [(en:json:html (weir-to-json:nexus weir)) ~])
  ==
::  Handle ack response (make, over, cull, poke, diff, sand)
::
++  handle-ack
  |=  [msg-road=road:tarball =wire err=(unit tang) slots=(map @ud slot) live=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id-slot  (get-slot wire slots)
  ?~  id-slot
    ~&  >>>  [%claude-stale-ack wire]
    (pure:m ~)
  =/  [id=@ud =slot]  u.id-slot
  ;<  ~  bind:m  (clear-slot id)
  =/  result=@t
    ?~  err
      ?+  action.slot
        (crip "Done: {(trip action.slot)} {(trip path.slot)}")
          %'make'     (crip "Created {(trip path.slot)}")
          %'dir'      (crip "Created directory {(trip path.slot)}")
          %'over'     (crip "Wrote {(trip path.slot)}")
          %'rmf'      (crip "Deleted {(trip path.slot)}")
          %'rmd'      (crip "Deleted directory {(trip path.slot)}")
          %'poke'     (crip "Poked {(trip path.slot)}")
          %'diff'     (crip "Diffed {(trip path.slot)}")
          %'setweir'  (crip "Set weir for {(trip path.slot)}")
          %'rmweir'   (crip "Cleared weir for {(trip path.slot)}")
      ==
    (crip "ERROR: {(trip action.slot)} failed")
  ;<  ~  bind:m  (append-msg msg-road slot result ~)
  ?.  live  (pure:m ~)
  (claude-turn msg-road)
::  Format a view (file or ball) as messages — used by bond and news
::
++  format-view
  |=  [msg-road=road:tarball api-path=@t =view:nexus is-bond=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  act=@t  ?:(is-bond 'bond' 'keep')
  ?-    -.view
      %none
    (append-to-msgs msg-road 'user' (rap 3 ~['<api action="' act '" path="' api-path '">DELETED</api>']))
      %file
    ;<  content=@t  bind:m  (cage-to-txt cage.view)
    =/  rev=@ud  ud.file.sack.view
    =/  rev-attr=@t  (crip " rev=\"{(a-co:co rev)}\"")
    (append-to-msgs msg-road 'user' (rap 3 ~['<api action="' act '" path="' api-path '"' rev-attr '>' content '</api>']))
      %ball
    (walk-ball msg-road api-path act ball.view /)
  ==
::  Walk a ball recursively, sending a message per file
::
++  walk-ball
  |=  [msg-road=road:tarball api-path=@t act=@t b=ball:tarball here=path]
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
    =/  msg=@t
      (rap 3 ~['<api action="' act '" path="' lane-path '">' content-text '</api>'])
    ;<  ~  bind:m  (append-to-msgs msg-road 'user' msg)
    $(files t.files)
  ::  Recurse into subdirectories
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
  |-
  ?~  dirs  (pure:m ~)
  =/  [dir-name=@ta sub=ball:tarball]  i.dirs
  ;<  ~  bind:m  (walk-ball msg-road api-path act sub (snoc here dir-name))
  $(dirs t.dirs)
::
++  render-weir
  |=  v=view:nexus
  ^-  wain
  ?.  ?=([%ball *] v)  ~['No weir set.']
  =/  =weir:nexus  (fall fil.sand.v *weir:nexus)
  ?:  =(*weir:nexus weir)  ~['No weir set.']
  ~[(crip "PERMISSIONS (weir): {(trip (en:json:html (weir-to-json:nexus weir)))}")]
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
::  Split a path cord into non-empty segments
::
++  segments
  |=  p=@t
  ^-  (list @t)
  %+  turn
    (skip (split (trip p) '/') |=(t=tape =(~ t)))
  crip
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
::  Classified message: shared structure for SSE and Sail rendering
::  Both renderers consume this, so they can never diverge.
::
+$  display-msg
  $:  role=@t     ::  'user' or 'assistant'
      type=@t     ::  'message', 'thought', 'tool', 'api', 'notify', 'wait', 'done', 'continue', 'error'
      content=@t  ::  display text
      sub=@t      ::  sub-label (e.g. 'thought', 'keep /path')
      action=@t   ::  api action (or '')
      pax=@t      ::  api path (or '')
  ==
::
::  Classify a raw message into a display-msg — single source of truth
::
++  classify
  |=  =message
  ^-  display-msg
  =/  rol=@t  role.message
  =/  raw=@t  content.message
  ::  protocol: continue
  ?:  =('<continue/>' raw)
    [rol 'continue' '' 'continue' '' '']
  ::  protocol: error (either role)
  ?:  =((end [3 7] raw) '<error>')
    [rol 'error' (extract-inner raw) 'error' '' '']
  ::  user: tool result
  ?:  &(=('user' rol) =((end [3 6] raw) '<tool>'))
    ['user' 'tool' (extract-inner raw) 'tool' '' '']
  ::  user: api result
  ?:  &(=('user' rol) |(?=(%'<api>' (end [3 5] raw)) ?=(%'<api ' (end [3 5] raw))))
    =/  tag-str=tape  (slag 1 (scag (need (find ">" (trip raw))) (trip raw)))
    =/  a=@t  (get-attr tag-str "action")
    =/  p=@t  (get-attr tag-str "path")
    =/  r=@t  (get-attr tag-str "rev")
    =/  sub=@t
      ?:  =('' a)  'api'
      ?:  =('' r)  (crip "{(trip (api-display-name a))} {(trip p)}")
      (crip "{(trip (api-display-name a))} {(trip p)} (rev {(trip r)})")
    ['user' 'api' (extract-inner raw) sub a p]
  ::  user: notify result
  ?:  &(=('user' rol) =((end [3 8] raw) '<notify>'))
    ['user' 'notify' (extract-inner raw) 'notify' '' '']
  ::  user: plain text
  ?:  =('user' rol)
    ['user' 'message' raw '' '' '']
  ::  assistant: parse XML protocol tag(s)
  =/  tags=(list response-tag)  (parse-responses raw)
  ?~  tags
    ['assistant' 'message' raw '' '' '']
  (tag-to-dm i.tags)
::  Friendly display name for api actions
::
++  api-display-name
  |=  act=@t
  ^-  @t
  ?+  act  act
    %'file'     'read'
    %'kids'     'kids'
    %'tree'     'tree'
    %'sand'     'sand'
    %'weir'     'weir'
    %'manu'     'docs'
    %'make'     'create'
    %'over'     'write'
    %'rmf'      'delete'
    %'rmd'      'rmdir'
    %'dir'      'mkdir'
    %'poke'     'poke'
    %'diff'     'diff'
    %'setweir'  'setweir'
    %'rmweir'   'rmweir'
    %'bond'     'subscribed'
    %'keep'     'update'
    %'drop'     'unsubscribe'
  ==
::  Convert a response-tag to a display-msg
::
++  tag-to-dm
  |=  tag=response-tag
  ^-  display-msg
  ?-  -.tag
      %thought   ['assistant' 'thought' text.tag 'thought' '' '']
      %message   ['assistant' 'message' text.tag '' '' '']
      %tool
    =/  names=@t
      %+  roll  calls.tag
      |=  [tc=tool-call acc=@t]
      ?:(=('' acc) name.tc (cat 3 acc (cat 3 ', ' name.tc)))
    ['assistant' 'tool' names 'tool' '' '']
      %api
    =/  sub=@t  (crip "{(trip (api-display-name action.tag))} {(trip path.tag)}")
    ['assistant' 'api' body.tag sub action.tag path.tag]
      %notify    ['assistant' 'notify' text.tag 'notify' '' '']
      %wait      ['assistant' 'wait' '' 'wait' '' '']
      %done      ['assistant' 'done' output.tag 'done' '' '']
  ==
::  Classify a message into a list of display-msgs (multi-tag aware)
::
++  classify-multi
  |=  =message
  ^-  (list display-msg)
  =/  rol=@t  role.message
  =/  raw=@t  content.message
  ::  non-assistant messages: always a single display-msg
  ?.  =('assistant' rol)
    ~[(classify message)]
  ::  assistant: parse all XML tags
  =/  tags=(list response-tag)  (parse-responses raw)
  ?~  tags  ~[(classify message)]
  (turn tags tag-to-dm)
::
::  Render a single display-msg to a manx div
::
++  dm-to-manx
  |=  dm=display-msg
  ^-  manx
  =/  role=tape   (trip role.dm)
  =/  type=tape   (trip type.dm)
  =/  cls=tape    "msg {type} {role}"
  =/  sub=tape    (trip sub.dm)
  =/  body=tape   (trip content.dm)
  ::  no-content types: one-liners with just role + sub
  ?:  |(=("continue" type) =("wait" type) &(!=('' sub) =('' body)))
    ;div(class cls)
      ;b: {role}
      ;span(class "sub"): {sub}
    ==
  ::  sub + content
  ?:  !=('' sub)
    ;div(class cls)
      ;b: {role}
      ;span(class "sub"): {sub}
      ;pre: {body}
    ==
  ::  content only
  ;div(class cls)
    ;b: {role}
    ;pre: {body}
  ==
::
::  Render a message to manx — the one true renderer
::  Used by both SSE (manx->txt via mark) and Sail server render
::
++  msg-to-manx
  |=  =message
  ^-  manx
  =/  dms=(list display-msg)  (classify-multi message)
  ?~  dms  ;div;
  ?:  ?=(~ t.dms)
    (dm-to-manx i.dms)
  ::  multi-tag: wrap in a group div
  =/  children=(list manx)  (turn dms dm-to-manx)
  ;div(class "msg-group")
    ;*  children
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
::  Read messages from the messages file via peek
::
++  read-msgs
  |=  msg-road=road:tarball
  =/  m  (fiber:fiber:nexus ,messages)
  ^-  form:m
  ;<  seen=seen:nexus  bind:m  (peek:io /msgs msg-road `%claude-messages)
  ?.  ?=([%& %file *] seen)
    (pure:m `messages`[%0 *((mop @ud message) lth)])
  (pure:m !<(messages q.cage.p.seen))
::  Append a message to the messages file via poke
::
++  append-to-msgs
  |=  [msg-road=road:tarball role=@t content=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (poke:io /msgs msg-road claude-action+!>(`action`[%add role content]))
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
  ::  Check for self-closing tag: <tag ... />
  ::  Find first /> to detect self-closing (works even with trailing content)
  ?~  t  ~
  ?.  =('<' i.t)  ~
  =/  sc=(unit @ud)  (find "/>" t)
  =/  gt=(unit @ud)  (find ">" t)
  ?:  &(?=(^ sc) ?=(^ gt) =(+(u.sc) u.gt))
    =/  inner=tape  (slag 1 (scag u.sc `tape`t))
    =/  tag-name=tape
      =/  sp=(unit @ud)  (find " " inner)
      ?~(sp inner (scag u.sp inner))
    ?:  =("wait" tag-name)     `[%wait ~]
    ?:  =("api" tag-name)      (parse-api-tag inner '')
    ?:  =("notify" tag-name)   `[%notify '' (parse-continue inner)]
    ~
  ::  Match <tag>content</tag> pattern
  =/  open=(unit @ud)  (find "<" t)
  ?~  open  ~
  =/  close-bracket=(unit @ud)  (find ">" (slag u.open `tape`t))
  ?~  close-bracket  ~
  =/  tag-end=@ud  (add u.open +(u.close-bracket))
  =/  tag-str=tape  (slag +(u.open) (scag (dec tag-end) `tape`t))
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
  =/  inner=@t  (crip (scag (sub u.close-pos tag-end) (slag tag-end `tape`t)))
  ?:  =("thought" tag-name)  `[%thought inner]
  ?:  =("message" tag-name)  `[%message inner (parse-continue tag-str)]
  ?:  =("done" tag-name)     `[%done inner]
  ?:  =("tool" tag-name)     (parse-tool-tag tag-str inner)
  ?:  =("api" tag-name)      (parse-api-tag tag-str inner)
  ?:  =("notify" tag-name)   `[%notify inner (parse-continue tag-str)]
  ~
::  Parse multiple XML tags from a single response
::
++  parse-responses
  |=  reply=@t
  ^-  (list response-tag)
  =/  t=tape  (trim-tape (trip reply))
  =|  acc=(list response-tag)
  |-
  ?:  =(~ t)  (flop acc)
  =/  chunk=@t  (crip t)
  =/  tag=(unit response-tag)  (parse-response chunk)
  ?~  tag  (flop acc)
  =/  end=@ud  (find-tag-end t)
  ?:  =(0 end)  (flop [u.tag acc])
  $(acc [u.tag acc], t (trim-tape (slag end `tape`t)))
::  Find the character position after the first complete XML tag
::
++  find-tag-end
  |=  t=tape
  ^-  @ud
  ?.  ?=(^ t)  0
  ?.  =('<' i.t)  0
  ::  self-closing: <tag ... />
  =/  sc=(unit @ud)  (find "/>" t)
  =/  gt=(unit @ud)  (find ">" t)
  ?~  gt  0
  ::  if /> appears before or at >  it's self-closing
  ?:  &(?=(^ sc) =(+(u.sc) u.gt))
    +(u.gt)
  ::  paired tag: extract name, find </name>
  =/  tag-str=tape  (slag 1 (scag u.gt `tape`t))
  =/  tag-name=tape
    =/  sp=(unit @ud)  (find " " tag-str)
    ?~(sp tag-str (scag u.sp tag-str))
  =/  close-tag=tape  "</{tag-name}>"
  =/  close-pos=(unit @ud)  (find close-tag t)
  ?~  close-pos  0
  (add u.close-pos (lent close-tag))
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
::  Parse <api> tag: extract action and path attributes
::
++  parse-api-tag
  |=  [tag-str=tape body=@t]
  ^-  (unit response-tag)
  =/  act=@t   (get-attr tag-str "action")
  =/  path=@t  (get-attr tag-str "path")
  ?:  |(=('' act) =('' path))  ~
  `[%api act path body (parse-continue tag-str)]
::  Extract an attribute value from a tag string
::  e.g. (get-attr "api action=\"file\" path=\"/foo\"" "action") -> 'file'
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
  =('true' val)
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
      "function showError(msg)\{var d=document.createElement('div');d.className='msg error';d.innerHTML='<b>system</b><span class=\\'sub\\'>error</span><pre>'+esc(msg)+'</pre>';box.appendChild(d);scrollBottom()}"
      "function autoResize()\{input.style.height='auto';input.style.height=input.scrollHeight+'px'}"
      "input.addEventListener('input',autoResize);"
      "input.addEventListener('keydown',function(e)\{if(e.key==='Enter'&&!e.shiftKey)\{e.preventDefault();form.dispatchEvent(new Event('submit'))}});"
      "form.onsubmit=async function(e)\{e.preventDefault();var t=input.value.trim();if(!t)return;input.value='';autoResize();var r=await fetch(API+'/poke/'+BASE+'/main.claude-registry?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{text:t})});if(!r.ok)\{var err=await r.text();showError(r.status+': '+err)}};"
      "function onLastMsg(e)\{if(e.data)\{box.insertAdjacentHTML('beforeend',e.data);scrollBottom()}}"
      "function connect()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/last-message.html?mark=txt');es.addEventListener('upd last-message.html',onLastMsg);es.onerror=function()\{es.close();setTimeout(connect,2000)}}"
      "var intBtn=document.getElementById('interrupt-btn');"
      "function onStatus(e)\{try\{var s=JSON.parse(e.data);var el=document.getElementById('loading');if(s.loading)\{el.classList.add('active');intBtn.classList.add('active')}else\{el.classList.remove('active');intBtn.classList.remove('active')};if('live' in s)\{setLiveUI(s.live)}}catch(x)\{}}"
      "intBtn.onclick=async function()\{await fetch(API+'/poke/'+BASE+'/main.claude-registry?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{interrupt:true})})};"
      "var lastEsc=0;document.addEventListener('keydown',function(e)\{if(e.key==='Escape')\{var now=Date.now();if(now-lastEsc<500)\{intBtn.click();lastEsc=0}else\{lastEsc=now}}});"
      "function connectStatus()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/status.json?mark=json');es.addEventListener('upd status.json',onStatus);es.onerror=function()\{es.close();setTimeout(connectStatus,2000)}}"
    "document.querySelectorAll('#filters input').forEach(function(cb)\{cb.addEventListener('change',function()\{var t=this.getAttribute('data-type');var r=this.getAttribute('data-role');var cls='hide-'+r+'-'+t;if(this.checked)\{box.classList.remove(cls)}else\{box.classList.add(cls)}})});"
    "var backdrop=document.getElementById('modal-backdrop'),editor=document.getElementById('prompt-editor'),sysDiv=document.getElementById('prompt-system'),saveBtn=document.getElementById('prompt-save');"
    "document.getElementById('prompt-btn').onclick=async function()\{backdrop.classList.add('open');sysDiv.textContent=SYSTEM_PROMPT;try\{var r=await fetch(API+'/file/'+BASE+'/custom-prompt.txt?mark=txt');editor.value=r.ok?await r.text():''}catch(e)\{editor.value=''}};"
    "document.getElementById('prompt-close').onclick=function()\{backdrop.classList.remove('open')};"
    "backdrop.onclick=function(e)\{if(e.target===backdrop)backdrop.classList.remove('open')};"
    "saveBtn.onclick=async function()\{try\{var r=await fetch(API+'/over/'+BASE+'/custom-prompt.txt?mark=txt',\{method:'POST',body:editor.value});if(r.ok)\{backdrop.classList.remove('open')}else\{alert('Save failed: '+r.status)}}catch(e)\{alert('Save failed: '+e.message)}};"
    "document.querySelectorAll('#modal-tabs button').forEach(function(btn)\{btn.onclick=function()\{document.querySelectorAll('#modal-tabs button').forEach(function(b)\{b.classList.remove('active')});document.querySelectorAll('.tab-pane').forEach(function(p)\{p.classList.remove('active')});btn.classList.add('active');document.getElementById('tab-'+btn.getAttribute('data-tab')).classList.add('active');saveBtn.style.display=btn.getAttribute('data-tab')==='custom'?'':'none'}});"
    "var regBack=document.getElementById('reg-backdrop'),regContent=document.getElementById('reg-content');"
    "document.getElementById('registry-btn').onclick=async function()\{regBack.classList.add('open');regContent.innerHTML='<span class=\\'reg-empty\\'>Loading...</span>';try\{var r=await fetch(API+'/file/'+BASE+'/main.claude-registry?mark=txt');var txt=r.ok?await r.text():'Failed to load';regContent.innerHTML='<pre>'+esc(txt)+'</pre>'}catch(e)\{regContent.innerHTML='<span class=\\'reg-empty\\'>Error: '+esc(e.message)+'</span>'}};"
    "document.getElementById('reg-close').onclick=function()\{regBack.classList.remove('open')};"
    "regBack.onclick=function(e)\{if(e.target===regBack)regBack.classList.remove('open')};"
    "var cfgBack=document.getElementById('cfg-backdrop'),cfgEditor=document.getElementById('cfg-editor');"
    "document.getElementById('config-btn').onclick=async function()\{cfgBack.classList.add('open');try\{var r=await fetch(API+'/file/'+BASE+'/config.json?mark=json');cfgEditor.value=r.ok?JSON.stringify(JSON.parse(await r.text()),null,2):''}catch(e)\{cfgEditor.value=''}};"
    "document.getElementById('cfg-save').onclick=async function()\{try\{var j=JSON.parse(cfgEditor.value);var r=await fetch(API+'/over/'+BASE+'/config.json?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(j)});if(r.ok)\{cfgBack.classList.remove('open')}else\{alert('Save failed: '+r.status)}}catch(e)\{alert('Invalid JSON: '+e.message)}};"
    "document.getElementById('cfg-close').onclick=function()\{cfgBack.classList.remove('open')};"
    "cfgBack.onclick=function(e)\{if(e.target===cfgBack)cfgBack.classList.remove('open')};"
    "var liveBtn=document.getElementById('live-btn');"
    "function setLiveUI(on)\{liveBtn.className=on?'on':'off';liveBtn.textContent=on?'live':'halted'}"
    "liveBtn.onclick=async function()\{var on=liveBtn.className==='off';setLiveUI(on);await fetch(API+'/poke/'+BASE+'/main.claude-registry?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{live:on})})};"
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
          ".msg-group \{ margin-bottom: 1rem; } "
          ".msg-group > .msg \{ margin-bottom: 0.25rem; } "
          ".msg-group > .msg:last-child \{ margin-bottom: 0; } "
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
          "#prompt-btn, #registry-btn, #config-btn, #live-btn \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; cursor: pointer; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; background: none; } "
          "#prompt-btn:hover, #registry-btn:hover, #config-btn:hover, #live-btn:hover \{ opacity: 0.8; } "
          "#interrupt-btn \{ display: none; color: #c00; border-color: #c00; } "
          "#interrupt-btn.active \{ display: block; } "
          "#interrupt-btn:hover \{ background: #fdd; } "
          "#live-btn.on \{ opacity: 0.8; color: #080; border-color: #080; } "
          "#live-btn.off \{ opacity: 0.8; color: #c00; border-color: #c00; } "
          "#reg-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.3); z-index: 100; } "
          "#reg-backdrop.open \{ display: flex; align-items: center; justify-content: center; } "
          "#reg-modal \{ background: #fff; border: 1px solid #ccc; border-radius: 4px; width: 90%; max-width: 700px; max-height: 70vh; display: flex; flex-direction: column; padding: 1rem; } "
          "#reg-header \{ display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 0.75rem; } "
          "#reg-header span \{ font-family: monospace; font-size: 0.8rem; font-weight: bold; text-transform: uppercase; opacity: 0.5; } "
          "#reg-header button \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; padding: 0.2rem 0.5rem; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; background: none; } "
          "#reg-header button:hover \{ background: #eee; } "
          "#reg-content \{ overflow-y: auto; font-family: monospace; font-size: 0.8rem; line-height: 1.8; } "
          "#cfg-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.3); z-index: 100; } "
          "#cfg-backdrop.open \{ display: flex; align-items: center; justify-content: center; } "
          "#cfg-modal \{ background: #fff; border: 1px solid #ccc; border-radius: 4px; width: 90%; max-width: 700px; height: 50vh; display: flex; flex-direction: column; padding: 1rem; } "
          "#cfg-header \{ display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 0.75rem; } "
          "#cfg-header span \{ font-family: monospace; font-size: 0.8rem; font-weight: bold; text-transform: uppercase; opacity: 0.5; } "
          "#cfg-actions \{ display: flex; gap: 0.5rem; } "
          "#cfg-actions button \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; padding: 0.2rem 0.5rem; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; background: none; } "
          "#cfg-actions button:hover \{ background: #eee; } "
          "#cfg-editor \{ flex: 1; font-family: monospace; font-size: 0.8rem; line-height: 1.5; border: 1px solid #ccc; border-radius: 4px; padding: 0.5rem; resize: none; } "
          ".reg-empty \{ opacity: 0.4; } "
          ".reg-entry \{ display: flex; justify-content: space-between; align-items: center; padding: 0.3rem 0; border-bottom: 1px solid #eee; } "
          ".reg-entry .reg-info \{ } "
          ".reg-entry .reg-type \{ font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; margin-right: 0.5rem; } "
          ".reg-entry button \{ font-family: monospace; font-size: 0.6rem; text-transform: uppercase; padding: 0.1rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; background: none; color: #c00; } "
          ".reg-entry button:hover \{ background: #fee; } "
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
        ;button#live-btn.on: live
        ;button#prompt-btn: prompt
        ;button#registry-btn: registry
        ;button#config-btn: config
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
            ;input(type "checkbox", checked "", data-type "done", data-role "assistant");
            ;span: done
          ==
          ;label
            ;input(type "checkbox", checked "", data-type "wait", data-role "assistant");
            ;span: wait
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
        ;*  %+  turn  msgs
            |=  [idx=@ud =message]
            (msg-to-manx message)
      ==
      ;div#loading;
      ;form#form
        ;button#interrupt-btn(type "button"): Stop
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
      ;div#reg-backdrop
        ;div#reg-modal
          ;div#reg-header
            ;span: Registry
            ;button#reg-close: close
          ==
          ;div#reg-content;
        ==
      ==
      ;div#cfg-backdrop
        ;div#cfg-modal
          ;div#cfg-header
            ;span: Config
            ;div#cfg-actions
              ;button#cfg-save: save
              ;button#cfg-close: close
            ==
          ==
          ;textarea#cfg-editor;
        ==
      ==
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
