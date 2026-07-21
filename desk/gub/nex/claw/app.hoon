::  claw/app: agent container nexus
::
::  Creates and manages claw agents in /agents/. Each agent runs
::  /claw/agent code with a read-only weir (peek everywhere, no
::  writes or pokes outside their own tree).
::
/&  man  ../../man/claw/app/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Claw'
            info+s+'Agent container'
            color+s+'#8a4a4a'
            image+s+''
            href+s+'/grubbery/ball/apps/claw.claw_app/page.html'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /apis empty-dir:loader]
          [%fall %| /apis/anthropic [`[`[/claw/api %anthropic] ~ %.n ~] ~]]
          [%fall %| /agents empty-dir:loader]
          [%fall %| /agents/main [`[`[/claw %agent] `main-agent-weir %.n ~] ~]]
          [%fall %| /channels empty-dir:loader]
          [%fall %| /channels/telegram/main-bot [`[`[/claw/channel %telegram] ~ %.n ~] ~]]
          [%fall %| /ui/sse empty-dir:loader]
          [%over %& [/ui/sse %'agents.html'] [[/ %html] (crip (en-xml:html (agents-fragment "" ~)))]]
          [%over %& [/ui/sse %'channels.html'] [[/ %html] (crip (en-xml:html (channels-fragment "" ~)))]]
          [%over %& [/ui/sse %'apis.html'] [[/ %html] (crip (en-xml:html (apis-fragment "" ~)))]]
          [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html (dashboard-page "" ~ ~ ~)))]]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
        ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app page: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id path.here)
        ;<  *  bind:m  (keep:io /agents (cord-to-road:tarball './agents/') ~)
        ;<  *  bind:m  (keep:io /channels (cord-to-road:tarball './channels/') ~)
        ;<  *  bind:m  (keep:io /apis (cord-to-road:tarball './apis/') ~)
        |-
        ;<  agents=view:nexus  bind:m  (peek:io (cord-to-road:tarball './agents/') ~)
        ;<  channels=view:nexus  bind:m  (peek:io (cord-to-road:tarball './channels/') ~)
        ;<  apis=view:nexus  bind:m  (peek:io (cord-to-road:tarball './apis/') ~)
        ;<  ~  bind:m
          (replace:io (crip (en-xml:html (dashboard-page ball-id (read-names agents) (read-entities channels) (read-entities apis)))))
        ;<  [* *]  bind:m  (take-any-news /agents /channels /apis)
        $
        ::
          [[%ui %sse ~] %'agents.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app sse/agents: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id (snip (snip path.here)))
        ;<  *  bind:m  (keep:io /agents (cord-to-road:tarball '../../agents/') ~)
        |-
        ;<  agents=view:nexus  bind:m  (peek:io (cord-to-road:tarball '../../agents/') ~)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (agents-fragment ball-id (read-names agents)))))
        ;<  *  bind:m  (take-news:io /agents)
        $
        ::
          [[%ui %sse ~] %'channels.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app sse/channels: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id (snip (snip path.here)))
        ;<  *  bind:m  (keep:io /channels (cord-to-road:tarball '../../channels/') ~)
        |-
        ;<  channels=view:nexus  bind:m  (peek:io (cord-to-road:tarball '../../channels/') ~)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (channels-fragment ball-id (read-entities channels)))))
        ;<  *  bind:m  (take-news:io /channels)
        $
        ::
          [[%ui %sse ~] %'apis.html']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app sse/apis: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id (snip (snip path.here)))
        ;<  *  bind:m  (keep:io /apis (cord-to-road:tarball '../../apis/') ~)
        |-
        ;<  apis=view:nexus  bind:m  (peek:io (cord-to-road:tarball '../../apis/') ~)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (apis-fragment ball-id (read-entities apis)))))
        ;<  *  bind:m  (take-news:io /apis)
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
          =/  new-ball=ball:tarball  [`[`[/claw %agent] `agents-weir %.n ~ ~] ~]
          ;<  ~  bind:m  (make:io agent-road &+(ball-to-bole:tarball new-ball))
          =/  agent-cfg=json
            %-  pairs:enjs:format
            :~  ['model' s+'claude-sonnet-4-6']
                ['api-proxy' s+'anthropic']
                ['context_window' (numb:enjs:format 80.000)]
                ['message_cap' (numb:enjs:format 20.000)]
                ['channel' s+'']
            ==
          =/  cfg-road=road:tarball
            (cord-to-road:tarball (crip "./agents/{(trip name)}/config.json"))
          ;<  ~  bind:m  (over:io cfg-road [[/ %json] agent-cfg])
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
          =/  chan-type=@t
            (fall (bind (~(get by p.jon) 'type') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  |(=('' name) =('' chan-type))
            ~&  >>>  "%claw/app: create-channel missing name or type"
            $
          =/  chan-road=road:tarball
            (cord-to-road:tarball (crip "./channels/{(trip name)}/"))
          =/  neck=neck:tarball  [/claw/channel (slav %tas chan-type)]
          =/  new-ball=ball:tarball  [`[`neck ~ %.n ~ ~] ~]
          ;<  ~  bind:m  (make:io chan-road &+(ball-to-bole:tarball new-ball))
          $
        ::
            %'delete-channel'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' name)  $
          ;<  ~  bind:m  (cull:io (cord-to-road:tarball (crip "./channels/{(trip name)}/")))
          $
        ::
            %'create-api'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          =/  api-type=@t
            (fall (bind (~(get by p.jon) 'type') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  |(=('' name) =('' api-type))
            ~&  >>>  "%claw/app: create-api missing name or type"
            $
          =/  api-road=road:tarball
            (cord-to-road:tarball (crip "./apis/{(trip name)}/"))
          =/  neck=neck:tarball  [/claw/api (slav %tas api-type)]
          =/  new-ball=ball:tarball  [`[`neck ~ %.n ~ ~] ~]
          ;<  ~  bind:m  (make:io api-road &+(ball-to-bole:tarball new-ball))
          $
        ::
            %'delete-api'
          =/  name=@t
            (fall (bind (~(get by p.jon) 'name') |=(=json ?>(?=(%s -.json) p.json))) '')
          ?:  =('' name)  $
          ;<  ~  bind:m  (cull:io (cord-to-road:tarball (crip "./apis/{(trip name)}/")))
          $
        ==
      ==
    --
::
|%
::  +agents-weir: weir for individual agent at ./agents/{name}/
::
++  agents-weir
  ^-  weir:nexus
  :+  ~
    (sy ~[&+[%& /sys %'bowl.sig'] |+[2 |+/apis] |+[2 |+/channels] &+[%& /sys/behn %'main.timer-state'] &+[%& /sys/push %'main.push-state']])
  (sy ~[&+[%| /]])
::  +main-agent-weir: agents-weir + make/poke on /agents
::
++  main-agent-weir
  ^-  weir:nexus
  :+  (sy ~[|+[2 |+/agents]])
    (sy ~[&+[%& /sys %'bowl.sig'] |+[2 |+/apis] |+[2 |+/channels] |+[2 |+/agents] &+[%& /sys/behn %'main.timer-state'] &+[%& /sys/push %'main.push-state']])
  (sy ~[&+[%| /]])
::  +path-to-ball-id: join a path into a slash-separated tape for URLs
::
++  path-to-ball-id
  |=  =path
  ^-  tape
  (zing (join "/" ^-((list tape) (turn path trip))))
::
::  +read-names: extract top-level names from a directory view
::
++  read-names
  |=  =view:nexus
  ^-  (list @ta)
  ?.  ?=([%ball *] view)  ~
  %+  turn  ~(tap by dir.ball.view)
  |=  [name=@ta *]  name
::
::  +read-entities: find nexus instances (balls with necks) in a tree
::    returns [name type] pairs like ['telegram/main-bot' 'telegram']
::
++  read-entities
  |=  =view:nexus
  ^-  (list [name=@ta type=@ta])
  ?.  ?=([%ball *] view)  ~
  (walk-ball ~ dir.ball.view)
::
++  walk-ball
  |=  [prefix=path entries=(map @ta ball:tarball)]
  ^-  (list [name=@ta type=@ta])
  %-  zing
  %+  turn  ~(tap by entries)
  |=  [name=@ta sub=ball:tarball]
  =/  full=path  (snoc prefix name)
  ?:  ?&  ?=(^ fil.sub)
          ?=(^ neck.u.fil.sub)
      ==
    =/  nk=neck:tarball  u.neck.u.fil.sub
    :_  ~
    :_  name.nk
    (crip (zing (join "/" (turn full trip))))
  (walk-ball full dir.sub)
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
  |=  $:  ball-id=tape
          agents=(list @ta)
          channels=(list [name=@ta type=@ta])
          apis=(list [name=@ta type=@ta])
      ==
  ^-  manx
  =/  sorted-agents=(list @ta)  (sort agents aor)
  =/  sorted-channels=(list [name=@ta type=@ta])
    (sort channels |=([[a=@ta *] [b=@ta *]] (aor a b)))
  =/  sorted-apis=(list [name=@ta type=@ta])
    (sort apis |=([[a=@ta *] [b=@ta *]] (aor a b)))
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
        ==
        ;div#cfg-backdrop
          ;div#cfg-modal
            ;div#cfg-header
              ;span#cfg-title: Config
              ;div
                ;button#cfg-save.hdr-btn: save
                ;button#cfg-close.hdr-btn: close
              ==
            ==
            ;textarea#cfg-json(rows "8", placeholder "\{}", style "width:100%;font-family:monospace;font-size:12px;border:1px solid #333;border-radius:6px;padding:10px;resize:vertical;background:#111;color:#eee;outline:none;");
            ;div#cfg-status;
          ==
        ==
        ;div.section-header
          ;h2.section-title: agents
        ==
        ;div.create-bar
          ;input.create-name(id "agent-name", type "text", placeholder "agent name...", autocomplete "off");
          ;button.create-btn(onclick "createEntity('agents')"): + new
        ==
        ;div#agents
          ;*  ?~  sorted-agents
                =/  empty=manx  ;div.empty: no agents yet
                ~[empty]
              (turn sorted-agents |=(n=@ta (agent-card ball-id n)))
        ==
        ;div.section-header
          ;h2.section-title: apis
        ==
        ;div.create-bar
          ;input.create-name(id "api-name", type "text", placeholder "name...", autocomplete "off");
          ;input.create-type(id "api-type", type "text", placeholder "type (e.g. anthropic)", autocomplete "off");
          ;button.create-btn(onclick "createEntity('apis')"): + new
        ==
        ;div#apis
          ;*  ?~  sorted-apis
                =/  empty=manx  ;div.empty: no apis yet
                ~[empty]
              (turn sorted-apis |=([n=@ta t=@ta] (api-card ball-id n t)))
        ==
        ;div.section-header
          ;h2.section-title: channels
        ==
        ;div.create-bar
          ;input.create-name(id "ch-name", type "text", placeholder "name...", autocomplete "off");
          ;input.create-type(id "ch-type", type "text", placeholder "type (e.g. telegram)", autocomplete "off");
          ;button.create-btn(onclick "createEntity('channels')"): + new
        ==
        ;div#channels
          ;*  ?~  sorted-channels
                =/  empty=manx  ;div.empty: no channels yet
                ~[empty]
              (turn sorted-channels |=([n=@ta t=@ta] (channel-card ball-id n t)))
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
    ;div.card-actions
      ;button.hdr-btn(onclick "openConfig('agents','{n}')"): config
      ;button.delete-btn(onclick "deleteEntity('agents','{n}')"): delete
    ==
  ==
::
++  channel-card
  |=  [ball-id=tape name=@ta ntype=@ta]
  ^-  manx
  =/  n=tape  (trip name)
  =/  t=tape  (trip ntype)
  ;div.entity-card(data-channel n)
    ;div.entity-info
      ;span.channel-name: {n}
      ;span.entity-type.channel-type: {t}
    ==
    ;div.card-actions
      ;button.hdr-btn(onclick "openConfig('channels','{n}')"): config
      ;button.delete-btn(onclick "deleteEntity('channels','{n}')"): delete
    ==
  ==
::
++  api-card
  |=  [ball-id=tape name=@ta ntype=@ta]
  ^-  manx
  =/  n=tape  (trip name)
  =/  t=tape  (trip ntype)
  ;div.entity-card(data-api n)
    ;div.entity-info
      ;span.api-name: {n}
      ;span.entity-type.api-type: {t}
    ==
    ;div.card-actions
      ;button.hdr-btn(onclick "openConfig('apis','{n}')"): config
      ;button.delete-btn(onclick "deleteEntity('apis','{n}')"): delete
    ==
  ==
::
++  apis-fragment
  |=  [ball-id=tape apis=(list [name=@ta type=@ta])]
  ^-  manx
  =/  sorted=(list [name=@ta type=@ta])
    (sort apis |=([[a=@ta *] [b=@ta *]] (aor a b)))
  ;div(id "sse-apis")
    ;*  ?~  sorted
          =/  empty=manx  ;div.empty: no apis yet
          ~[empty]
        (turn sorted |=([n=@ta t=@ta] (api-card ball-id n t)))
  ==
::
++  channels-fragment
  |=  [ball-id=tape channels=(list [name=@ta type=@ta])]
  ^-  manx
  =/  sorted=(list [name=@ta type=@ta])
    (sort channels |=([[a=@ta *] [b=@ta *]] (aor a b)))
  ;div(id "sse-channels")
    ;*  ?~  sorted
          =/  empty=manx  ;div.empty: no channels yet
          ~[empty]
        (turn sorted |=([n=@ta t=@ta] (channel-card ball-id n t)))
  ==
::
++  take-any-news
  |=  [a=wire b=wire c=wire]
  =/  m  (fiber:fiber:nexus ,[?(%agents %channels %apis) wave:nexus])
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(a wire.u.in)  [%done %agents wave.u.in]
    ?:  =(b wire.u.in)  [%done %channels wave.u.in]
    ?:  =(c wire.u.in)  [%done %apis wave.u.in]
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
  #cfg-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  .create-bar \{ display: flex; gap: 8px; margin-bottom: 12px; }
  .create-name \{ flex: 1; padding: 8px 12px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 13px; outline: none; }
  .create-name:focus \{ border-color: #2563eb; }
  .create-type \{ width: 140px; padding: 8px 12px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 13px; outline: none; }
  .create-type:focus \{ border-color: #2563eb; }
  .create-btn \{ padding: 8px 16px; border-radius: 8px; border: none; background: #2563eb; color: white; font-size: 13px; cursor: pointer; white-space: nowrap; }
  .create-btn:hover \{ background: #1d4ed8; }
  .entity-card, .agent-card \{ display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; border-radius: 8px; background: #1a1a1a; border: 1px solid #222; margin-bottom: 6px; }
  .entity-card:hover, .agent-card:hover \{ border-color: #444; }
  .entity-info \{ display: flex; align-items: center; gap: 10px; }
  .entity-type \{ font-size: 12px; color: #444; }
  .card-actions \{ display: flex; gap: 6px; }
  .agent-name \{ color: #60a5fa; text-decoration: none; font-size: 14px; font-weight: 500; }
  .agent-name:hover \{ text-decoration: underline; }
  .channel-name \{ color: #a78bfa; font-size: 14px; font-weight: 500; }
  .api-name \{ color: #34d399; font-size: 14px; font-weight: 500; }
  .delete-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid transparent; background: none; color: #555; cursor: pointer; }
  .delete-btn:hover \{ color: #f87171; border-color: #f87171; }
  .empty \{ color: #555; font-size: 14px; padding: 20px 0; text-align: center; }
  .section-header \{ margin-top: 20px; margin-bottom: 8px; }
  .section-title \{ font-size: 13px; font-weight: 600; color: #888; text-transform: uppercase; letter-spacing: 0.05em; }
  #cfg-json:focus \{ border-color: #2563eb; }
  @media (max-width: 600px) \{
    #app \{ padding: 12px; }
    .create-bar \{ flex-wrap: wrap; }
    .create-type \{ width: 100%; }
    .entity-card, .agent-card \{ flex-direction: column; align-items: flex-start; gap: 8px; }
    .card-actions \{ align-self: flex-end; }
    #header \{ flex-direction: column; gap: 4px; }
  }
  """
::
++  script-text
  |=  ball-id=tape
  ^-  tape
  ;:  weld
    "var API='/grubbery/api';var BALL='{ball-id}';\0a"
  """
  var ACTIONS = \{
    agents:   \{create: 'create',         del: 'delete',         nameId: 'agent-name', dataAttr: 'data-agent'},
    apis:     \{create: 'create-api',     del: 'delete-api',     nameId: 'api-name',   dataAttr: 'data-api'},
    channels: \{create: 'create-channel', del: 'delete-channel', nameId: 'ch-name',    dataAttr: 'data-channel'}
  };

  function createEntity(section) \{
    var a = ACTIONS[section];
    var nameEl = document.getElementById(a.nameId);
    var name = nameEl.value.trim();
    if (!name) return;
    var body = \{action: a.create, name: name};
    if (section !== 'agents') \{
      var typeEl = document.getElementById(section === 'apis' ? 'api-type' : 'ch-type');
      var type = typeEl.value.trim();
      if (!type) \{ alert('Type required'); return; }
      body.type = type;
      typeEl.value = '';
    }
    nameEl.value = '';
    fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    });
  }

  function deleteEntity(section, name) \{
    if (!confirm('Delete ' + name + '?')) return;
    var a = ACTIONS[section];
    fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: a.del, name: name})
    });
    var el = document.querySelector('[' + a.dataAttr + '="' + name + '"]');
    if (el) el.remove();
  }

  // Config modal
  var cfgBack = document.getElementById('cfg-backdrop');
  var cfgTitle = document.getElementById('cfg-title');
  var cfgJson = document.getElementById('cfg-json');
  var cfgStatus = document.getElementById('cfg-status');
  var cfgSection = '';
  var cfgName = '';

  function openConfig(section, name) \{
    cfgSection = section;
    cfgName = name;
    cfgTitle.textContent = name + ' config';
    cfgStatus.textContent = '';
    cfgStatus.style.color = '#4ade80';
    fetch(API + '/file/' + BALL + '/' + section + '/' + name + '/config.json?blot=/json')
      .then(function(r) \{ return r.json() })
      .then(function(j) \{ cfgJson.value = JSON.stringify(j, null, 2); })
      .catch(function() \{ cfgJson.value = '\{}'; });
    cfgBack.classList.add('open');
  }

  document.getElementById('cfg-close').onclick = function() \{
    cfgBack.classList.remove('open');
  };

  cfgBack.onclick = function(e) \{
    if (e.target === cfgBack) cfgBack.classList.remove('open');
  };

  document.getElementById('cfg-save').onclick = async function() \{
    var parsed;
    try \{ parsed = JSON.parse(cfgJson.value); } catch(e) \{
      cfgStatus.textContent = 'Invalid JSON';
      cfgStatus.style.color = '#f87171';
      return;
    }
    var r = await fetch(API + '/over/' + BALL + '/' + cfgSection + '/' + cfgName + '/config.json?blot=/json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(parsed)
    });
    if (r.ok) \{
      cfgStatus.textContent = 'Saved';
      cfgStatus.style.color = '#4ade80';
      setTimeout(function() \{ cfgBack.classList.remove('open'); }, 600);
    } else \{
      cfgStatus.textContent = 'Save failed';
      cfgStatus.style.color = '#f87171';
    }
  };

  var SSE_URL = API + '/keep/' + BALL + '/ui/sse?blot=/txt';
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
              } else if (frag && frag.id === 'sse-apis') \{
                var el = document.getElementById('apis');
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
