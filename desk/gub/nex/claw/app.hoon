::  claw/app: agent container nexus
::
::  Creates and manages claw agents in /agents/. Each agent runs
::  /claw/agent code with a read-only weir (peek everywhere, no
::  writes or pokes outside their own tree).
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        =/  default-api=json
          %-  pairs:enjs:format
          :~  ['api-key' s+'']
              ['url' s+'https://api.anthropic.com/v1/messages']
          ==
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /apis [~ ~] [~ ~] empty-dir:loader]
            [%fall %& [/apis %'anthropic.json'] %.n [~ [/ %json] !>(default-api)]]
            =/  agents-weir=weir:nexus
              :+  ~
                (sy ~[&+|+/sys/bowl |+[1 |+/apis] |+[1 |+/channels]])
              (sy ~[&+|+/])
            [%fall %| /agents [`agents-weir ~] [~ ~] empty-dir:loader]
            [%fall %| /channels [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /ui/sse [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ui/sse %'agents.html'] %.n [~ [/ %manx] !>((agents-fragment "" ~))]]
            [%over %& [/ui/sse %'channels.html'] %.n [~ [/ %manx] !>((channels-fragment "" ~))]]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>((dashboard-page "" ~ ~))]]
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
        ::
          [[%apis ~] %'anthropic.json']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app anthropic proxy: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ::  payload is the Anthropic API request body JSON
        =/  payload=json  (fall (mole |.(!<(json q.sage))) *json)
        ?~  payload  $
        ::  read config from own file
        =/  cfg-road=road:tarball  (cord-to-road:tarball './anthropic.json')
        ;<  =seen:nexus  bind:m  (peek:io cfg-road ~)
        =/  cfg=json
          ?.  ?=([%& %file *] seen)  *json
          (fall (mole |.(!<(json q.sage.p.seen))) *json)
        =/  api-key=@t
          ?.  ?=(%o -.cfg)  ''
          (fall (bind (~(get by p.cfg) 'api-key') |=(=json ?>(?=(%s -.json) p.json))) '')
        =/  api-url=@t
          ?.  ?=(%o -.cfg)  ''
          (fall (bind (~(get by p.cfg) 'url') |=(=json ?>(?=(%s -.json) p.json))) '')
        ?:  =('' api-key)
          ~&  >>>  "%claw/app: anthropic proxy: no api-key in config"
          ;<  ~  bind:m
            (poke:io (from-to-road from) [/ %json] !>((pairs:enjs:format ~[['error' s+'no api-key configured']])))
          $
        ?:  =('' api-url)
          ~&  >>>  "%claw/app: anthropic proxy: no url in config"
          ;<  ~  bind:m
            (poke:io (from-to-road from) [/ %json] !>((pairs:enjs:format ~[['error' s+'no url configured']])))
          $
        ::  build HTTP request
        =/  body-cord=@t  (en:json:html payload)
        =/  hed=(list [key=@t value=@t])
          :~  ['content-type' 'application/json']
              ['x-api-key' api-key]
              ['anthropic-version' '2023-06-01']
          ==
        ~&  >  "%claw/app: anthropic proxy: sending request"
        ;<  ~  bind:m
          (send-request:io [%'POST' api-url hed `(as-octs:mimes:html body-cord)])
        ;<  resp=client-response:iris  bind:m  take-http-response
        ::  extract response body and poke back as JSON
        =/  resp-json=json
          ?.  ?=(%finished -.resp)  [%o ~]
          ?~  full-file.resp  [%o ~]
          =/  body=@t  q.data.u.full-file.resp
          (fall (mole |.((need (de:json:html body)))) [%o ~])
        ;<  ~  bind:m  (poke:io (from-to-road from) [/ %json] !>(resp-json))
        $
        ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app page: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  ball-id=tape
          (zing (join "/" ^-((list tape) (turn path.here trip))))
        ;<  agents=view:nexus  bind:m
          (keep:io /agents (cord-to-road:tarball './agents/') ~)
        ;<  channels=view:nexus  bind:m
          (keep:io /channels (cord-to-road:tarball './channels/') ~)
        ;<  ~  bind:m
          (replace:io !>((dashboard-page ball-id (read-agents agents) (read-agents channels))))
        |-
        ;<  [tag=?(%agents %channels) =view:nexus]  bind:m
          (take-either-news /agents /channels)
        =?  agents   =(tag %agents)    view
        =?  channels  =(tag %channels)  view
        ;<  ~  bind:m
          (replace:io !>((dashboard-page ball-id (read-agents agents) (read-agents channels))))
        $
        ::
          [[%ui %sse ~] %'agents.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app sse/agents: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  ball-id=tape  (trip (snag 0 path.here))
        ;<  init=view:nexus  bind:m
          (keep:io /agents (cord-to-road:tarball '../../agents/') ~)
        ;<  ~  bind:m  (replace:io !>((agents-fragment ball-id (read-agents init))))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /agents)
        ;<  ~  bind:m  (replace:io !>((agents-fragment ball-id (read-agents upd))))
        $
        ::
          [[%ui %sse ~] %'channels.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app sse/channels: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  ball-id=tape  (trip (snag 0 path.here))
        ;<  init=view:nexus  bind:m
          (keep:io /channels (cord-to-road:tarball '../../channels/') ~)
        ;<  ~  bind:m  (replace:io !>((channels-fragment ball-id (read-agents init))))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /channels)
        ;<  ~  bind:m  (replace:io !>((channels-fragment ball-id (read-agents upd))))
        $
        ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?~  jon  $
        ?.  ?=(%o -.jon)  $
        =/  act=@t
          (fall (bind (~(get by p.jon) 'action') |=(=json ?>(?=(%s -.json) p.json))) '')
        ?+    act  $
            %'create'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' name)  $
          =/  agent-road=road:tarball
            (cord-to-road:tarball (crip "./agents/{(trip name)}/"))
          =/  new-ball=ball:tarball  [`[~ `[/claw %agent] ~] ~]
          ;<  ~  bind:m  (make:io agent-road &+[*sand:nexus *gain:nexus new-ball])
          ::  write proxy path into agent config so children inherit it
          ;<  here=rail:tarball  bind:m  get-here:io
          =/  proxy-path=tape
            "{(spud path.here)}/apis/anthropic.json"
          =/  agent-cfg=json
            %-  pairs:enjs:format
            :~  ['model' s+'claude-sonnet-4-20250514']
                ['api-proxy' s+(crip proxy-path)]
                ['context_window' (numb:enjs:format 80.000)]
                ['message_cap' (numb:enjs:format 20.000)]
            ==
          =/  cfg-road=road:tarball
            (cord-to-road:tarball (crip "./agents/{(trip name)}/config.json"))
          ;<  ~  bind:m  (over:io cfg-road [[/ %json] !>(agent-cfg)])
          $
        ::
            %'delete'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' name)  $
          =/  agent-road=road:tarball
            (cord-to-road:tarball (crip "./agents/{(trip name)}/"))
          ;<  ~  bind:m  (cull:io agent-road)
          $
        ::
            %'create-channel'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          =/  source=@t
            (fall (bind (~(get by p.jon) 'source') |=(=json ?>(?=(%s -.json) p.json))) '')
          =/  chat-id=@t
            (fall (bind (~(get by p.jon) 'chat-id') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  |(=('' name) =('' source) =('' chat-id))
            ~&  >>>  "%claw/app: create-channel missing fields"
            $
          =/  chan-road=road:tarball
            (cord-to-road:tarball (crip "./channels/{(trip name)}/"))
          ::  bake config into initial ball so relay has it at start
          =/  chan-cfg=json
            %-  pairs:enjs:format
            :~  ['source' s+source]
                ['chat-id' s+chat-id]
            ==
          =/  cfg-content=content:tarball  [~ [/ %json] !>(chan-cfg)]
          =/  new-ball=ball:tarball
            [`[~ `[/claw %channel] (malt ~[['config.json' cfg-content]])] ~]
          =/  =weir:nexus
            :+  ~
              ::  poke: bot send.sig
              (sy ~[&+|+/])
            ::  peek: bot messages
            (sy ~[&+|+/])
          =/  new-sand=sand:nexus  [`weir ~]
          ;<  ~  bind:m  (make:io chan-road &+[new-sand *gain:nexus new-ball])
          ~&  >  ["%claw/app: created channel" name]
          $
        ::
            %'delete-channel'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' name)  $
          =/  chan-road=road:tarball
            (cord-to-road:tarball (crip "./channels/{(trip name)}/"))
          ;<  ~  bind:m  (cull:io chan-road)
          $
        ==
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Directory under the claw agent container.'
            ~
          %-  crip
          ;:  weld
            "CLAW AGENT CONTAINER\0a\0a"
            "Manages claw agent nexuses in /agents/ and channels in /channels/.\0a"
            "Each agent runs /claw/agent code with a read-only weir.\0a"
            "Channels exist independently; agents link to them via channels.json.\0a\0a"
            "Poke main.sig with JSON:\0a"
            "  \{\"action\": \"create\", \"name\": \"my-agent\"}\0a"
            "  \{\"action\": \"delete\", \"name\": \"my-agent\"}\0a"
            "  \{\"action\": \"create-channel\", \"name\": \"tg\", \"source\": \"...\", \"chat-id\": \"...\"}\0a"
            "  \{\"action\": \"delete-channel\", \"name\": \"tg\"}\0a\0a"
            "API proxies in /apis/ handle HTTP for sandboxed agents.\0a"
          ==
            [%agents ~]
          'Agent nexuses. Each subdirectory is a claw agent with /claw/agent code.'
            [%apis ~]
          'API proxies and config. Each file holds its config (key, url) and acts as a proxy endpoint.'
            [%ui %sse ~]
          'SSE fragments for live dashboard updates.'
        ==
          %|
        ?+  rail.p.mana  'File under the claw agent container.'
            [~ %'main.sig']
          'Management process. Poke with JSON to create or delete agents.'
            [~ %'page.html']
          'Dashboard page. Lists all agents with links to their UIs.'
            [[%apis ~] %'anthropic.json']
          'Anthropic API proxy and config. Contains api-key and url. Poke with request body JSON, get response JSON back.'
            [[%ui %sse ~] %'agents.html']
          'Agent list HTML fragment for SSE live updates.'
        ==
      ==
    --
::
|%
++  from-to-road
  |=  =from:fiber:nexus
  ^-  road:tarball
  ?>  ?=(%& -.from)
  |+[p.p.from &+q.p.from]
::
++  take-http-response
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%fail ~[leaf+"HTTP request cancelled"]]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done client-response.sign.u.in]
  ==
::
::  +read-agents: extract agent names from a directory view
::
++  read-agents
  |=  =view:nexus
  ^-  (list @ta)
  ?.  ?=(%ball -.view)  ~
  %+  turn  ~(tap by dir.ball.view)
  |=  [name=@ta *]  name
::
::  +agents-fragment: just the agent list HTML for SSE updates
::
++  agents-fragment
  |=  [ball-id=tape agents=(list @ta)]
  ^-  manx
  =/  sorted=(list @ta)  (sort agents aor)
  ;div(id "sse-agents")
    ;*  ?~  sorted
          =/  empty=manx  ;div.empty: no agents yet
          ~[empty]
        (turn sorted |=(n=@ta (agent-card ball-id n)))
  ==
::
::  +dashboard-page: render the agent dashboard
::
++  dashboard-page
  |=  [ball-id=tape agents=(list @ta) channels=(list @ta)]
  ^-  manx
  =/  sorted-agents=(list @ta)  (sort agents aor)
  =/  sorted-channels=(list @ta)  (sort channels aor)
  ;html
    ;head
      ;title: claw
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;div
            ;h1: claw
            ;div.f3.mono.s-2: agent container
          ==
          ;button#config-btn.hdr-btn: config
        ==
        ;div#cfg-backdrop
          ;div#cfg-modal
            ;div#cfg-header
              ;span: Config
              ;div
                ;button#cfg-save.hdr-btn: save
                ;button#cfg-close.hdr-btn: close
              ==
            ==
            ;label.cfg-label: API Key
            ;input#cfg-key(type "password", placeholder "sk-ant-...");
            ;label.cfg-label: URL
            ;input#cfg-url(type "text", placeholder "https://api.anthropic.com/v1/messages");
            ;div#cfg-status;
          ==
        ==
        ;div.section-header
          ;h2.section-title: agents
        ==
        ;div#create-bar
          ;input#agent-name(type "text", placeholder "agent name...", autocomplete "off");
          ;button#create-btn(onclick "createAgent()"): + new
        ==
        ;div#agents
          ;*  ?~  sorted-agents
                =/  empty=manx  ;div.empty: no agents yet
                ~[empty]
              (turn sorted-agents |=(n=@ta (agent-card ball-id n)))
        ==
        ;div.section-header
          ;h2.section-title: channels
        ==
        ;div#channel-create
          ;div.channel-row
            ;input#ch-name(type "text", placeholder "channel path (e.g. telegram/main-bot)", autocomplete "off");
            ;input#ch-source(type "text", placeholder "source (e.g. telegram.telegram/bots/main)", autocomplete "off");
          ==
          ;div.channel-row
            ;input#ch-chatid(type "text", placeholder "chat id", autocomplete "off");
          ==
          ;button#ch-create-btn(onclick "createChannel()"): + new channel
        ==
        ;div#channels
          ;*  ?~  sorted-channels
                =/  empty=manx  ;div.empty: no channels yet
                ~[empty]
              (turn sorted-channels |=(n=@ta (channel-card ball-id n)))
        ==
      ==
      ;script
        ;+  ;/  (script-text ball-id)
      ==
    ==
  ==
::
++  agent-card
  |=  [ball-id=tape name=@ta]
  ^-  manx
  =/  n=tape  (trip name)
  ;div.agent-card(data-agent n)
    ;a.agent-name(href "/grubbery/ball/{ball-id}/agents/{n}/page.html"): {n}
    ;button.delete-btn(onclick "deleteAgent('{n}')"): delete
  ==
::
++  channel-card
  |=  [ball-id=tape name=@ta]
  ^-  manx
  =/  n=tape  (trip name)
  ;div.channel-card(data-channel n)
    ;span.channel-name: {n}
    ;button.delete-btn(onclick "deleteChannel('{n}')"): delete
  ==
::
++  channels-fragment
  |=  [ball-id=tape channels=(list @ta)]
  ^-  manx
  =/  sorted=(list @ta)  (sort channels aor)
  ;div(id "sse-channels")
    ;*  ?~  sorted
          =/  empty=manx  ;div.empty: no channels yet
          ~[empty]
        (turn sorted |=(n=@ta (channel-card ball-id n)))
  ==
::
++  take-either-news
  |=  [a=wire b=wire]
  =/  m  (fiber:fiber:nexus ,[?(%agents %channels) view:nexus])
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(a wire.u.in)  [%done %agents view.u.in]
    ?:  =(b wire.u.in)  [%done %channels view.u.in]
    [%skip ~]
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; height: 100vh; }
  #app \{ display: flex; flex-direction: column; height: 100vh; max-width: 700px; margin: 0 auto; padding: 16px; }
  #header \{ display: flex; justify-content: space-between; align-items: flex-start; padding: 12px 0; border-bottom: 1px solid #333; margin-bottom: 16px; flex-shrink: 0; }
  #header h1 \{ font-size: 20px; font-weight: 700; }
  .f3 \{ color: #888; }
  .mono \{ font-family: monospace; }
  .s-2 \{ font-size: 12px; }
  .hdr-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid #444; background: none; color: #888; cursor: pointer; }
  .hdr-btn:hover \{ color: #eee; border-color: #666; }
  #cfg-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #cfg-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #cfg-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }
  #cfg-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #cfg-header span \{ font-size: 14px; font-weight: 600; }
  #cfg-header div \{ display: flex; gap: 6px; }
  .cfg-label \{ display: block; font-size: 12px; color: #888; margin: 12px 0 4px; }
  #cfg-key \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }
  #cfg-key:focus \{ border-color: #2563eb; }
  #cfg-url \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }
  #cfg-url:focus \{ border-color: #2563eb; }
  #cfg-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  #create-bar \{ display: flex; gap: 8px; margin-bottom: 16px; }
  #agent-name \{ flex: 1; padding: 10px 14px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 14px; outline: none; }
  #agent-name:focus \{ border-color: #2563eb; }
  #create-btn \{ padding: 10px 20px; border-radius: 8px; border: none; background: #2563eb; color: white; font-size: 14px; cursor: pointer; }
  #create-btn:hover \{ background: #1d4ed8; }
  #agents \{ flex: 1; overflow-y: auto; }
  .agent-card \{ display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; border-radius: 8px; background: #1a1a1a; border: 1px solid #222; margin-bottom: 6px; }
  .agent-card:hover \{ border-color: #444; }
  .agent-name \{ color: #60a5fa; text-decoration: none; font-size: 14px; font-weight: 500; }
  .agent-name:hover \{ text-decoration: underline; }
  .delete-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid transparent; background: none; color: #555; cursor: pointer; }
  .delete-btn:hover \{ color: #f87171; border-color: #f87171; }
  .empty \{ color: #555; font-size: 14px; padding: 20px 0; text-align: center; }
  .section-header \{ margin-top: 20px; margin-bottom: 8px; }
  .section-title \{ font-size: 13px; font-weight: 600; color: #888; text-transform: uppercase; letter-spacing: 0.05em; }
  .channel-card \{ display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; border-radius: 8px; background: #1a1a1a; border: 1px solid #222; margin-bottom: 6px; }
  .channel-card:hover \{ border-color: #444; }
  .channel-name \{ color: #a78bfa; font-size: 14px; font-weight: 500; }
  #channel-create \{ margin-bottom: 12px; }
  .channel-row \{ display: flex; gap: 8px; margin-bottom: 6px; }
  .channel-row input \{ flex: 1; padding: 8px 12px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 13px; outline: none; }
  .channel-row input:focus \{ border-color: #2563eb; }
  #ch-create-btn \{ padding: 8px 16px; border-radius: 8px; border: none; background: #7c3aed; color: white; font-size: 13px; cursor: pointer; }
  #ch-create-btn:hover \{ background: #6d28d9; }
  """
::
++  script-text
  |=  ball-id=tape
  ^-  tape
  ;:  weld
    "var API='/grubbery/api';var BALL='{ball-id}';\0a"
  """
  function createAgent() \{
    var n = document.getElementById('agent-name').value.trim();
    if (!n) return;
    document.getElementById('agent-name').value = '';
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'create', name: n})
    });
  }

  function deleteAgent(n) \{
    if (!confirm('Delete agent ' + n + '?')) return;
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'delete', name: n})
    });
    var el = document.querySelector('[data-agent="' + n + '"]');
    if (el) el.remove();
  }

  function createChannel() \{
    var name = document.getElementById('ch-name').value.trim();
    var source = document.getElementById('ch-source').value.trim();
    var chatId = document.getElementById('ch-chatid').value.trim();
    if (!name || !source || !chatId) \{ alert('All fields required'); return; }
    document.getElementById('ch-name').value = '';
    document.getElementById('ch-source').value = '';
    document.getElementById('ch-chatid').value = '';
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'create-channel', name: name, source: source, 'chat-id': chatId})
    });
  }

  function deleteChannel(n) \{
    if (!confirm('Delete channel ' + n + '?')) return;
    fetch(API + '/poke/' + BALL + '/main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'delete-channel', name: n})
    });
    var el = document.querySelector('[data-channel="' + n + '"]');
    if (el) el.remove();
  }

  // Config modal
  var cfgBack = document.getElementById('cfg-backdrop');
  var cfgKey = document.getElementById('cfg-key');
  var cfgUrl = document.getElementById('cfg-url');
  var cfgStatus = document.getElementById('cfg-status');

  document.getElementById('config-btn').onclick = function() \{
    cfgStatus.textContent = '';
    fetch(API + '/file/' + BALL + '/apis/anthropic.json?mark=json')
      .then(function(r) \{ return r.json() })
      .then(function(j) \{
        cfgKey.value = j['api-key'] || '';
        cfgUrl.value = j['url'] || '';
      }).catch(function() \{});
    cfgBack.classList.add('open');
  };

  document.getElementById('cfg-close').onclick = function() \{
    cfgBack.classList.remove('open');
  };

  cfgBack.onclick = function(e) \{
    if (e.target === cfgBack) cfgBack.classList.remove('open');
  };

  document.getElementById('cfg-save').onclick = async function() \{
    var cfg = \{'api-key': cfgKey.value, 'url': cfgUrl.value};
    var r = await fetch(API + '/over/' + BALL + '/apis/anthropic.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(cfg)
    });
    if (r.ok) \{
      cfgStatus.textContent = 'Saved';
      setTimeout(function() \{ cfgBack.classList.remove('open'); }, 600);
    } else \{
      cfgStatus.textContent = 'Save failed';
      cfgStatus.style.color = '#f87171';
    }
  };

  var SSE_URL = API + '/keep/' + BALL + '/ui/sse?mark=txt';
  var sseCtrl = null;
  var sseRdr = null;

  async function connectSSE() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
    sseCtrl = new AbortController();
    try \{
      var r = await fetch(SSE_URL, \{
        headers: \{Accept: 'text/event-stream'},
        signal: sseCtrl.signal
      });
      sseRdr = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await sseRdr.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var parts = buf.split('\\n\\n');
        buf = parts.pop();
        for (var i = 0; i < parts.length; i++) \{
          var lines = parts[i].split('\\n');
          for (var j = 0; j < lines.length; j++) \{
            if (lines[j].indexOf('data:') === 0) \{
              var html = lines[j].slice(5).trim();
              var tmp = document.createElement('div');
              tmp.innerHTML = html;
              var frag = tmp.firstElementChild;
              if (frag && frag.id === 'sse-agents') \{
                var el = document.getElementById('agents');
                if (el) el.innerHTML = frag.innerHTML;
              } else if (frag && frag.id === 'sse-channels') \{
                var el = document.getElementById('channels');
                if (el) el.innerHTML = frag.innerHTML;
              }
            }
          }
        }
      }
    } catch (e) \{
      if (e.name !== 'AbortError') setTimeout(connectSSE, 2000);
    }
  }
  window.addEventListener('beforeunload', function() \{
    if (sseRdr) try \{ sseRdr.cancel(); } catch(e) \{}
    if (sseCtrl) sseCtrl.abort();
  });
  connectSSE();
  """
  ==
--
