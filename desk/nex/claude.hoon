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
        (~(put ba:tarball ball) [/ %'main.claude-registry'] [~ %claude-registry !>(`registry`[%0 0 ~ ~])])
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
      ::  keeps, one-shots, everything. Messages file is inert state written via
      ::  poke:io.
      ::
      ::  State: [%0 next-id=@ud active=(map @ud reg-request)]
      ::  Tracks active keep subscriptions. One-shots complete inline.
      ::
      ::  Event loop multiplexes:
      ::  - Pokes: user messages (claude-action from UI)
      ::  - News on /keep/N: keep subscription updates
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
            main.claude-registry    Active request tracker — keeps + flights
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
            main.claude-registry      THE process. On user poke (%say):
                                      1. Appends user message to store
                                      2. Builds system prompt (custom + live context)
                                      3. Calls Anthropic API via HTTP
                                      4. Parses response as single XML tag
                                      5. Dispatches tag:
                                         <thought>  → append, loop (gets another turn)
                                         <tool>     → dispatch to MCP, append result, loop
                                         <api>      → dispatch to ball API, append result
                                         <message>  → append, pause for input/events
                                         <wait/>    → pause without output
                                         <done>     → end session
                                         <notify>   → fire-and-forget notification
                                         <continue/> → get another turn immediately
                                      6. Also multiplexes keep subscription updates
                                         (news events arrive between turns)
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
        ?+  name.rail.p.mana
            'Inert file under the claude nexus. No special behavior or documentation beyond its mark and contents.'
            %'config.json'
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
            %'messages.claude-messages'
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
            %'custom-prompt.txt'
          %-  crip
          """
          custom-prompt.txt — Custom system prompt. Mark: txt (wain).

          Prepended to the built-in system prompt on every Anthropic API call.
          Use this to give Claude persistent instructions, personality, context,
          or constraints that survive across conversations. Empty by default.

          READ:  peek, or api action "file ./custom-prompt.txt"
          WRITE: over with text body, or api action "over ./custom-prompt.txt"
          """
            %'main.claude-registry'
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
            %'weir.txt'
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
            %'ver.ud'
          'ver.ud — Nexus schema version counter. Mark: ud. Incremented on structural migrations in on-load.'
            %'chat.html'
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
            %'last-message.html'
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
            %'status.json'
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
::  Multiplexes pokes (user messages from UI) and news (keep updates).
::  Messages file written via poke:io (%claude-action).
::
++  main-loop
  |=  msg-road=road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  ev=main-event  bind:m  take-main-event
  ?-    -.ev
  ::  User message from UI — run Claude conversation turn
  ::
      %poke
    =/  =action  !<(action q.cage.ev)
    =/  [role=@t text=@t]
      ?-  -.action
          %say  ['user' text.action]
          %add  [role.action text.action]
      ==
    ?:  =('' text)  $
    ~&  >  [%claude-say (end [3 80] text)]
    ;<  ~  bind:m  (append-to-msgs msg-road role text)
    ;<  ~  bind:m  (claude-turn msg-road)
    $
  ::  Keep subscription update — append result to messages, then call Claude
  ::
      %news
    ::  Wire is /keep/(scot %t path) — extract the path
    =/  keep-path=(unit @t)
      ?~  wire.ev  ~
      ?~  t.wire.ev  ~
      (slaw %t i.t.wire.ev)
    ?~  keep-path
      ~&  >>>  [%claude-unknown-wire wire.ev]
      $
    ;<  reg=registry  bind:m  (get-state-as:io ,registry)
    ?.  (~(has by keeps.reg) u.keep-path)  $  ::  stale — ignore
    ::  Bump update count
    =/  count=@ud  (fall (~(get by keeps.reg) u.keep-path) 0)
    ;<  ~  bind:m  (replace:io !>(`registry`reg(keeps (~(put by keeps.reg) u.keep-path +(count)))))
    ?+    view.ev  $
        [%file *]
      ;<  content=@t  bind:m  (cage-to-txt cage.view.ev)
      =/  msg=@t
        (rap 3 ~['<api action="keep" path="' u.keep-path '">' content '</api>'])
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' msg)
      ;<  ~  bind:m  (claude-turn msg-road)
      $
        [%ball *]
      =/  rest=path  (turn (segments u.keep-path) |=(s=@t `@ta`s))
      =/  root=ball:tarball  ball.view.ev
      =/  root-born=born:nexus  born.view.ev
      =/  what=(set lane:tarball)  (diff-born-state:nexus *born:nexus root-born)
      =/  lanes=(list lane:tarball)  ~(tap in what)
      |-
      ?~  lanes
        ;<  ~  bind:m  (claude-turn msg-road)
        ^$
      ?:  ?=(%| -.i.lanes)
        $(lanes t.lanes)
      =/  file-path=path  path.p.i.lanes
      =/  file-name=@ta  name.p.i.lanes
      =/  lane-path=@t  (spat (snoc file-path file-name))
      =/  sub=ball:tarball  (~(dip ba:tarball root) file-path)
      =/  ct=(unit content:tarball)
        ?~  fil.sub  ~
        (~(get by contents.u.fil.sub) file-name)
      ?~  ct
        =/  msg=@t
          (rap 3 ~['<api action="keep" path="' lane-path '">DELETED</api>'])
        ;<  ~  bind:m  (append-to-msgs msg-road 'user' msg)
        $(lanes t.lanes)
      ;<  content=@t  bind:m  (cage-to-txt cage.u.ct)
      =/  msg=@t
        (rap 3 ~['<api action="keep" path="' lane-path '">' content '</api>'])
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' msg)
      $(lanes t.lanes)
    ==
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
      =/  keep-list=(list [@t @ud])  ~(tap by keeps.reg)
      =/  flight-list=(list [@ud [action=@t path=@t]])  ~(tap by flights.reg)
      ?:  &(=(~ keep-list) =(~ flight-list))  ~['No active requests.']
      :-  'ACTIVE REQUESTS:'
      %+  weld
        %+  turn  keep-list
        |=  [pax=@t updates=@ud]
        (crip "  keep {(trip pax)}{?:(=(0 updates) "" " ({(a-co:co updates)} updates)")}")
      %+  turn  flight-list
      |=  [id=@ud action=@t path=@t]
      (crip "  {(trip action)} {(trip path)}")
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
      ;<  ~  bind:m  (append-to-msgs msg-road 'assistant' (cat 3 '<error>' (cat 3 u.err '</error>')))
      (pure:m ~)  ::  API errors don't loop back
    =/  reply=@t  (extract-reply response)
    ?:  =('' reply)
      ~&  >>>  [%claude-empty-reply response]
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<error>Empty response from Claude API — no text content blocks returned.</error>')
      ?:  (gte +(errs) 3)
        ~&  >>>  %claude-error-limit-reached
        (pure:m ~)
      $(errs +(errs))
    ::  parse XML tag — take the first valid tag, ignore the rest
    =/  tag=(unit response-tag)  (parse-response reply)
    ?~  tag
      ~&  >>>  [%claude-bad-tag reply]
      =/  err-msg=@t
        (rap 3 ~['<error>Invalid response — must be exactly one XML tag. Your response was: ' reply '</error>'])
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' err-msg)
      ?:  (gte +(errs) 3)
        ~&  >>>  %claude-error-limit-reached
        (pure:m ~)
      $(errs +(errs))
    ::  valid tag — store and dispatch
    ;<  ~  bind:m  (append-to-msgs msg-road 'assistant' reply)
    ;<  ~  bind:m  (sleep:io ~s0..0001)
    ?-  -.u.tag
        %thought
      ~&  >  [%claude-thought (end [3 80] text.u.tag)]
      ?:  (gte +(thinks) 5)
        ~&  >>>  %claude-thought-cap-reached
        ;<  ~  bind:m  (sleep:io ~s0..0001)
        ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<error>Thought cap reached (5). You must respond with message, wait, or done.</error>')
        $(errs 0, thinks 0)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(errs 0, thinks +(thinks))
    ::
        %tool
      ~&  >  [%claude-tool (lent calls.u.tag) %calls continue.u.tag]
      ?.  continue.u.tag  (pure:m ~)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(thinks 0)
    ::
        %api
      ~&  >  [%claude-api action.u.tag path.u.tag continue.u.tag]
      ?:  continue.u.tag
        ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
        ;<  ~  bind:m  (handle-api msg-road action.u.tag path.u.tag body.u.tag)
        $(thinks 0)
      ;<  ~  bind:m  (handle-api msg-road action.u.tag path.u.tag body.u.tag)
      (pure:m ~)
    ::
        %notify
      ~&  >  [%claude-notify continue.u.tag]
      ?.  continue.u.tag  (pure:m ~)
      ;<  ~  bind:m  (sleep:io ~s0..0001)
      ;<  ~  bind:m  (append-to-msgs msg-road 'user' '<continue/>')
      $(thinks 0)
    ::
        %message
      ~&  >  %claude-message
      (pure:m ~)  ::  done — return to main loop
    ::
        %wait
      ~&  >  %claude-wait
      (pure:m ~)  ::  done — return to main loop
    ::
        %done
      ~&  >  [%claude-done output.u.tag]
      (pure:m ~)  ::  done — return to main loop
    ==
::  Handle API request inline — keeps, one-shots, drop
::
++  handle-api
  |=  [msg-road=road:tarball act=@t api-path=@t body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  reg=registry  bind:m  (get-state-as:io ,registry)
  ~&  >  [%claude-api-dispatch act api-path]
  ::  drop — cancel keep subscription and remove from registry
  ?:  =(act 'drop')
    ?.  (~(has by keeps.reg) api-path)
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="drop" path="' api-path '">Not subscribed to this path.</api>']))
    =/  rest=path  (turn (segments api-path) |=(s=@t `@ta`s))
    =/  file-road=(unit road:tarball)
      ?~  rest  ~
      `[%& %& (snip `path`rest) (rear rest)]
    ;<  is-file=?  bind:m
      ?~  file-road  (pure:(fiber:fiber:nexus ,?) %.n)
      (peek-exists:io /check u.file-road)
    =/  =road:tarball
      ?:  is-file  (need file-road)
      [%& %| rest]
    =/  keep-wire=wire  /keep/(scot %t api-path)
    ;<  ~  bind:m  (drop:io keep-wire road)
    ;<  ~  bind:m  (replace:io !>(`registry`reg(keeps (~(del by keeps.reg) api-path))))
    (append-to-msgs msg-road 'user' (rap 3 ~['<api action="drop" path="' api-path '">Unsubscribed</api>']))
  ::  keep — one per path
  ?:  =(act 'keep')
    ?:  (~(has by keeps.reg) api-path)
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="keep" path="' api-path '">Already subscribed to this path.</api>']))
    =/  rest=path  (turn (segments api-path) |=(s=@t `@ta`s))
    =/  file-road=(unit road:tarball)
      ?~  rest  ~
      `[%& %& (snip `path`rest) (rear rest)]
    ;<  is-file=?  bind:m
      ?~  file-road  (pure:(fiber:fiber:nexus ,?) %.n)
      (peek-exists:io /check u.file-road)
    =/  =road:tarball
      ?:  is-file  (need file-road)
      [%& %| rest]
    =/  keep-wire=wire  /keep/(scot %t api-path)
    ;<  init=view:nexus  bind:m  (keep:io keep-wire road ~)
    ;<  ~  bind:m  (replace:io !>(`registry`reg(keeps (~(put by keeps.reg) api-path 0))))
    ::  Append initial value to messages
    ?+  init  (pure:m ~)
        [%file *]
      ;<  content=@t  bind:m  (cage-to-txt cage.init)
      (append-to-msgs msg-road 'user' (rap 3 ~['<api action="keep" path="' api-path '">' content '</api>']))
        [%ball *]
      (poke-ball-init msg-road api-path ball.init / rest)
    ==
  ::  In-flight request — track, dispatch, remove
  =/  fid=@ud  nex.reg
  ;<  ~  bind:m  (replace:io !>(`registry`reg(nex +(fid), flights (~(put by flights.reg) fid [act api-path]))))
  ;<  result=@t  bind:m  (dispatch-api act api-path body)
  ~&  >  [%claude-api-done act (end [3 80] result)]
  ;<  reg=registry  bind:m  (get-state-as:io ,registry)
  ;<  ~  bind:m  (replace:io !>(`registry`reg(flights (~(del by flights.reg) fid))))
  (append-to-msgs msg-road 'user' (rap 3 ~['<api action="' act '" path="' api-path '">' result '</api>']))
::  Multiplex pokes (user messages) and news (keep updates)
::
+$  main-event
  $%  [%poke =cage]
      [%news =wire =view:nexus]
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
      [~ %news * *]
    [%done %news wire.u.in view.u.in]
  ==
++  system-prompt
  ^~
  %-  of-wain:format
  :~  'You are Claude, an AI assistant running natively on an Urbit ship.'
      'Urbit is a peer-to-peer operating system. You run as a Hoon application on the user\'s personal server.'
      ''
      'PROTOCOL: Your ENTIRE response must be exactly ONE XML tag — nothing else.'
      'NOT TWO TAGS. NOT TEXT THEN A TAG. NOT A TAG THEN ANOTHER TAG. ONE. SINGLE. TAG.'
      'If you send <api .../> followed by <message>...</message>, the ENTIRE response is'
      'rejected and you get an error. You will get another turn — send each tag separately.'
      ''
      'Valid tags:'
      ''
      '<thought>Your internal reasoning. Not shown to user. You get another turn immediately.</thought>'
      '<tool continue="true">{"name":"tool_name","args":{"key":"value"}}</tool>'
      '  Executes a tool. Multiple calls: <tool>[{"name":"a","args":{}},{"name":"b","args":{}}]</tool>'
      '  Results come back as <tool> under user role.'
      '<api action="ACTION" path="/path" continue="true">optional body</api>'
      '  Direct grubbery filesystem API. Results come back as <api> under user role.'
      '  The grubbery is a ball — a nested filesystem of typed files (grubs) and directories.'
      '  Files have marks (types) like hoon, txt, json, mime. The system auto-converts to text.'
      ''
      '  PATHS: Trailing slash = directory, no trailing slash = file. This matters!'
      '    /path/to/name.ext  — file (name.ext in /path/to/)'
      '    /path/to/dir/      — directory'
      '    ./relative          — relative to this nexus (file)'
      '    ./relative/         — relative to this nexus (directory)'
      '    ../up/              — up one level then into directory'
      '  The system parses paths strictly. "ui/sse" is a FILE named sse. "ui/sse/" is a DIRECTORY.'
      ''
      '  READ actions (no body needed, self-closing OK):'
      '    file  /path/to/name.ext  — read file content (auto-converted to text)'
      '    kids  /path/             — list immediate files + subdirs as JSON'
      '    tree  /path/             — recursive tree as JSON'
      '    sand  /path/             — directory permissions as JSON'
      '    weir  /path/             — single directory access rule as JSON'
      '    manu  /path/to/name.ext  — documentation for a file (from nearest nexus)'
      '    manu  /path/to/dir/     — documentation for a directory (from nearest nexus)'
      '    keep  /path/             — subscribe to changes (long-lived, streams updates)'
      '    drop  /path/             — unsubscribe from a keep subscription'
      ''
      '  WRITE actions (body = text content or JSON):'
      '    make  /path/to/name.ext  — create new file (body = content, mark from extension)'
      '    over  /path/to/name.ext  — overwrite existing file (body = new content)'
      '    rmf   /path/to/name.ext  — delete file'
      '    dir   /path/             — create directory'
      '    rmd   /path/             — delete directory'
      '    poke  /path/to/name.ext  — poke file process (body = payload)'
      '    diff  /path/to/name.ext  — diff file (body = diff payload)'
      '    setweir /path/           — set directory access rule (body = weir JSON)'
      '    rmweir  /path/           — clear directory access rule'
      ''
      '  HOW RESULTS WORK: When you send an <api> tag, the registry assigns a numeric ID and'
      '  handles the request. The result comes back as a USER-ROLE message with this format:'
      '    <api id="42" action="file" path="/the/path">content</api>'
      '  The id matches YOUR request. The action and path confirm what it was for.'
      '  These are REAL system-generated messages — they are NOT from the user. They appear'
      '  under the user role because that is how the system injects responses into the chat.'
      '  Do NOT assume API results are fake, spoofed, or user-fabricated. They are genuine.'
      ''
      '  WEIR (permissions): Your weir controls which API operations you can perform.'
      '  It has three fields: make (create/delete), poke (write/modify), peek (read).'
      '  Each field lists the roads (paths) you are allowed to target. An empty list means'
      '  no restrictions for that operation. Your current weir is shown in LIVE CONTEXT below.'
      ''
      '  ACTIVE REQUESTS: This prompt includes a live view of the registry state.'
      '  Each entry shows: ID, action, path, and status (pending/streaming).'
      '  One-shot actions (file, kids, make, etc.) complete quickly and disappear.'
      '  keep subscriptions stay as "streaming" until you drop them.'
      '  drop cancels a keep by path. Use <api action="drop" path="/same/path"/>.'
      ''
      '  ASYNC PATTERN: With continue="true" (default), you get a turn immediately —'
      '  the result arrives later as a user-role <api> message. Use continue="false"'
      '  + <wait/> when you need the result before proceeding.'
      '<notify continue="true">payload</notify>'
      '  Sends a notification to listeners (subscriptions, agents, etc). Fire-and-forget.'
      '<message>Text shown to the user. Pauses until the user responds or an event arrives.</message>'
      '<wait/>'
      '  Pause without showing anything. Resumes when an event arrives.'
      '  Prefer <wait/> over <message> when you have nothing new or useful to say. If your message'
      '  would just be a summary of what happened, a restatement of results the user can already see,'
      '  or filler like "Got it" or "Interesting!" — send <wait/> instead. Save <message> for when'
      '  you have a genuine question, insight, or something the user needs to know.'
      '<done>Optional final output (JSON or text). Ends the session permanently.</done>'
      ''
      'CONTINUE ATTRIBUTE:'
      '  <tool>, <api>, and <notify> support continue="true" (default) or continue="false".'
      '  continue="true": you get another turn immediately. API/tool results arrive later as messages.'
      '  continue="false": pause until the user sends a message or an event (like an API result) arrives.'
      ''
      'RULES:'
      '- CRITICAL: ONE TAG PER RESPONSE. Your output is parsed as a single XML tag. If you'
      '  include anything else — a second tag, prose, explanation — the ENTIRE response is'
      '  DISCARDED and replaced with an error. You WILL get another turn. Use it.'
      '- NEVER send <api .../> then <message> in the same response. Send <api/>, get your'
      '  turn back via <continue/>, THEN send <message> on the next turn.'
      '- <thought> always gives you another turn immediately.'
      '- <tool>, <api>, <notify> with continue="true" give you another turn after the response.'
      '  With continue="false" they pause like <message>.'
      '- <continue/> is a SYSTEM message, NOT from the user. It means "your previous action was'
      '  processed — now take your next action." Do NOT treat it as user input. Do NOT ask the'
      '  user to clarify. Do NOT say "the user sent continue." Just proceed with your next tag.'
      '- <message>, <wait>, and <done> always pause or end.'
      '- If you need to think before acting, use <thought> first, then <message> on your next turn.'
      '  ALWAYS follow thoughts with a <message> before <wait>ing or <done>. Never think then go silent.'
      '- Do not chain more than 2-3 thoughts in a row. The system enforces a thought cap — after 5'
      '  consecutive thoughts, your next response MUST be a <message>, <wait>, or <done>.'
      '- Do NOT chain multiple <message> tags in a row. If you need to act after speaking, use'
      '  <message continue="true">text</message> to get another turn, then send your <api> or <tool>.'
      '- For tool calls, use the exact tool names and argument formats provided.'
  ==
::  Dispatch API call by action
::
++  dispatch-api
  |=  [act=@t api-path=@t body=@t]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  =road:tarball  (cord-to-road:tarball api-path)
  ?+    act
      %-  pure:m
      %-  crip
      """
      ERROR: Unknown action '{(trip act)}'.
      Valid actions: file, kids, tree, sand, weir, manu, keep, drop,
        make, over, rmf, dir, rmd, poke, diff, setweir, rmweir
      """
  ::  file — read a file
      %'file'
    ;<  =seen:nexus  bind:m  (peek:io /api-read road ~)
    ?.  ?=([%& %file *] seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    (cage-to-txt cage.p.seen)
  ::  kids — list files + subdirs
      %'kids'
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-kids road ~)
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
  ::  tree — recursive tree
      %'tree'
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-tree road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    (pure:m (en:json:html (tree-to-json:tarball (ball-to-tree:tarball ball.p.dir-seen))))
  ::  make — create file or directory (body is content for files)
      %'make'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?:  exists
      (pure:m (crip "ERROR: Already exists: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (make:io /api-make road |+[%.n mime+!>(mime) ~])
    (pure:m (crip "Created {(trip api-path)}"))
  ::  over — overwrite file (body is content)
      %'over'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (over:io /api-over road mime+!>(mime))
    (pure:m (crip "Wrote {(trip api-path)}"))
  ::  rmf — delete file
      %'rmf'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    ;<  ~  bind:m  (cull:io /api-cull road)
    (pure:m (crip "Deleted {(trip api-path)}"))
  ::  dir — create directory
      %'dir'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?:  exists
      (pure:m (crip "ERROR: Already exists: {(trip api-path)}"))
    ;<  ~  bind:m  (make:io /api-make road &+[*sand:nexus *gain:nexus `[~ ~ ~] ~])
    (pure:m (crip "Created directory {(trip api-path)}"))
  ::  rmd — delete directory
      %'rmd'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    ;<  ~  bind:m  (cull:io /api-cull road)
    (pure:m (crip "Deleted directory {(trip api-path)}"))
  ::  poke — poke file process
      %'poke'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (poke:io /api-poke road mime+!>(mime))
    (pure:m (crip "Poked {(trip api-path)}"))
  ::  diff — diff file
      %'diff'
    ;<  exists=?  bind:m  (peek-exists:io /api-chk road)
    ?.  exists
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =mime  [/text/plain (as-octs:mimes:html body)]
    ;<  ~  bind:m  (diff:io /api-diff road mime+!>(mime))
    (pure:m (crip "Diffed {(trip api-path)}"))
  ::  sand — directory permissions
      %'sand'
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-sand road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    (pure:m (en:json:html (sand-to-json:nexus sand.p.dir-seen)))
  ::  weir — single directory weir
      %'weir'
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /api-weir road ~)
    ?.  ?=([%& %ball *] dir-seen)
      (pure:m (crip "ERROR: Not found: {(trip api-path)}"))
    =/  =weir:nexus  (fall fil.sand.p.dir-seen *weir:nexus)
    (pure:m (en:json:html (weir-to-json:nexus weir)))
  ::  setweir — replace weir
      %'setweir'
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      (pure:m 'ERROR: Invalid JSON body')
    =/  parsed=(each weir:nexus tang)
      (mule |.((weir-from-json:nexus u.jon)))
    ?:  ?=(%| -.parsed)
      (pure:m 'ERROR: Invalid weir JSON')
    ;<  ~  bind:m  (sand:io /api-weir road `p.parsed)
    (pure:m (crip "Set weir for {(trip api-path)}"))
  ::  rmweir — clear weir
      %'rmweir'
    ;<  ~  bind:m  (sand:io /api-weir road ~)
    (pure:m (crip "Cleared weir for {(trip api-path)}"))
  ::  manu — documentation for a path
      %'manu'
    ;<  text=@t  bind:m  (manu:io /api-manu |+road)
    (pure:m text)
  ==
::  Poke initial state for a directory subscription
::
++  poke-ball-init
  |=  [msg-road=road:tarball keep-path=@t b=ball:tarball here=path api-path=path]
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
      (rap 3 ~['<api action="keep" path="' lane-path '">' content-text '</api>'])
    ;<  ~  bind:m  (append-to-msgs msg-road 'user' msg)
    $(files t.files)
  ::  Recurse into subdirectories
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
  |-
  ?~  dirs  (pure:m ~)
  =/  [dir-name=@ta sub=ball:tarball]  i.dirs
  ;<  ~  bind:m  (poke-ball-init msg-road keep-path sub (snoc here dir-name) api-path)
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
    =/  sub=@t
      ?:  =('' a)  'api'
      (crip "{(trip a)} {(trip p)}")
    ['user' 'api' (extract-inner raw) sub a p]
  ::  user: notify result
  ?:  &(=('user' rol) =((end [3 8] raw) '<notify>'))
    ['user' 'notify' (extract-inner raw) 'notify' '' '']
  ::  user: plain text
  ?:  =('user' rol)
    ['user' 'message' raw '' '' '']
  ::  assistant: parse XML protocol tag
  =/  tag=(unit response-tag)  (parse-response raw)
  ?~  tag
    ['assistant' 'message' raw '' '' '']
  ?-  -.u.tag
      %thought   ['assistant' 'thought' text.u.tag 'thought' '' '']
      %message   ['assistant' 'message' text.u.tag '' '' '']
      %tool
    =/  names=@t
      %+  roll  calls.u.tag
      |=  [tc=tool-call acc=@t]
      ?:(=('' acc) name.tc (cat 3 acc (cat 3 ', ' name.tc)))
    ['assistant' 'tool' names 'tool' '' '']
      %api
    =/  sub=@t  (crip "{(trip action.u.tag)} {(trip path.u.tag)}")
    ['assistant' 'api' body.u.tag sub action.u.tag path.u.tag]
      %notify    ['assistant' 'notify' text.u.tag 'notify' '' '']
      %wait      ['assistant' 'wait' '' 'wait' '' '']
      %done      ['assistant' 'done' output.u.tag 'done' '' '']
  ==
::
::  Render a message to a manx div — the one true renderer
::  Used by both SSE (manx->txt via mark) and Sail server render
::
++  msg-to-manx
  |=  =message
  ^-  manx
  =/  dm=display-msg  (classify message)
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
      "function showError(msg)\{var d=document.createElement('div');d.className='msg error';d.innerHTML='<b>system</b><span class=\\'sub\\'>error</span><pre>'+esc(msg)+'</pre>';box.appendChild(d);scrollBottom()}"
      "function autoResize()\{input.style.height='auto';input.style.height=input.scrollHeight+'px'}"
      "input.addEventListener('input',autoResize);"
      "input.addEventListener('keydown',function(e)\{if(e.key==='Enter'&&!e.shiftKey)\{e.preventDefault();form.dispatchEvent(new Event('submit'))}});"
      "form.onsubmit=async function(e)\{e.preventDefault();var t=input.value.trim();if(!t)return;input.value='';autoResize();var r=await fetch(API+'/poke/'+BASE+'/main.claude-registry?mark=claude-action',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{text:t})});if(!r.ok)\{var err=await r.text();showError(r.status+': '+err)}};"
      "function onLastMsg(e)\{if(e.data)\{box.insertAdjacentHTML('beforeend',e.data);scrollBottom()}}"
      "function connect()\{var es=new EventSource(API+'/keep/'+BASE+'/ui/sse/last-message.html?mark=txt');es.addEventListener('upd last-message.html',onLastMsg);es.onerror=function()\{es.close();setTimeout(connect,2000)}}"
      "function onStatus(e)\{try\{var s=JSON.parse(e.data);var el=document.getElementById('loading');if(s.loading)\{el.classList.add('active')}else\{el.classList.remove('active')}}catch(x)\{}}"
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
          "#prompt-btn, #registry-btn, #config-btn \{ font-family: monospace; font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; cursor: pointer; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; background: none; } "
          "#prompt-btn:hover, #registry-btn:hover, #config-btn:hover \{ opacity: 0.8; } "
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
