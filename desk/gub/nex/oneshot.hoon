::  oneshot nexus: playground for one-shot LLM composition
::
/<  oneshot  /lib/oneshot.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-claude=json
        %-  pairs:enjs:format
        :~  ['api_key' s+'']
            ['model' s+'claude-sonnet-4-20250514']
            ['max_tokens' (numb:enjs:format 4.096)]
        ==
      =/  default-brave=json
        (pairs:enjs:format ~[['api_key' s+'']])
      =/  default-descs=json
        %-  pairs:enjs:format
        %+  turn  ~(tap by descs:oneshot)
        |=  [k=@t v=@t]
        [k s+v]
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/config %'claude.json'] %.n [~ [/ %json] !>(default-claude)]]
            [%fall %& [/config %'brave.json'] %.n [~ [/ %json] !>(default-brave)]]
            [%over %& [/ %'descs.json'] %.n [~ [/ %json] !>(default-descs)]]
            [%fall %& [/ %'request.json'] %.n [~ [/ %json] !>((pairs:enjs:format ~))]]
            [%fall %& [/ %'result.json'] %.n [~ [/ %json] !>((pairs:enjs:format ~[['status' s+'idle']]))]]
            [%fall %& [/ %'briefing.json'] %.n [~ [/ %json] !>((pairs:enjs:format ~[['step' s+'idle']]))]]
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%over %& [/ui %'page.html'] %.n [~ [/ %manx] !>((oneshot-page '' ~))]]
            [%over %& [/ui %'briefing.html'] %.n [~ [/ %manx] !>(briefing-page)]]
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
          ::  /main.sig: accept pokes, run one-shot calls, store result
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%oneshot: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ?.  ?=(%json name.p.sage)
          ~&  >  [%oneshot-unknown-mark name.p.sage]
          $
        =/  req=json  !<(json q.sage)
        ?.  ?=(%o -.req)  $
        =/  request-road=road:tarball  (cord-to-road:tarball './request.json')
        =/  result-road=road:tarball  (cord-to-road:tarball './result.json')
        ::  check for save-only (no prompt, just persist fields)
        =/  action=@t
          =/  v  (~(get by p.req) 'action')
          ?.  ?=([~ %s *] v)  'call'
          p.u.v
        ?:  =(action 'save')
          ;<  ~  bind:m  (over:io /req request-road [[/ %json] !>(req)])
          $
        ?:  =(action 'search')
          =/  query=@t
            =/  v  (~(get by p.req) 'prompt')
            ?.  ?=([~ %s *] v)  ''
            p.u.v
          ?:  =('' query)  $
          ;<  ~  bind:m
            (over:io /res result-road [[/ %json] !>((pairs:enjs:format ~[['status' s+'loading']]))])
          ;<  brave-key=@t  bind:m  read-brave-key
          ?:  =('' brave-key)
            ;<  ~  bind:m
              (over:io /res result-road [[/ %json] !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'No Brave API key configured']]))])
            $
          ;<  results=@t  bind:m  (~(web search:oneshot brave-key) query)
          ;<  ~  bind:m
            (over:io /res result-road [[/ %json] !>((pairs:enjs:format ~[['status' s+'ok'] ['output' s+results] ['mark' s+'search']]))])
          $
        ?:  =(action 'brief')
          =/  topic=@t
            =/  v  (~(get by p.req) 'prompt')
            ?.  ?=([~ %s *] v)  ''
            p.u.v
          ?:  =('' topic)  $
          =/  brief-road=road:tarball  (cord-to-road:tarball './briefing.json')
          ::  step 1: generating queries
          ::
          ;<  ~  bind:m
            (over:io /brf brief-road [[/ %json] !>((pairs:enjs:format ~[['step' s+'generating-queries'] ['topic' s+topic]]))])
          ;<  cfg=claude-config:oneshot  bind:m  read-claude-config
          ?:  =('' api-key.cfg)
            ;<  ~  bind:m
              (over:io /brf brief-road [[/ %json] !>((pairs:enjs:format ~[['step' s+'error'] ['error' s+'No API key configured']]))])
            $
          ;<  brave-key=@t  bind:m  read-brave-key
          ?:  =('' brave-key)
            ;<  ~  bind:m
              (over:io /brf brief-road [[/ %json] !>((pairs:enjs:format ~[['step' s+'error'] ['error' s+'No Brave API key configured']]))])
            $
          =/  brfng  ~(. briefing:oneshot [cfg brave-key])
          ;<  queries=(list @t)  bind:m  (generate-queries:brfng topic)
          ?~  queries
            ;<  ~  bind:m
              (over:io /brf brief-road [[/ %json] !>((pairs:enjs:format ~[['step' s+'error'] ['error' s+'No queries generated']]))])
            $
          ::  step 2: searching (show queries)
          ::
          =/  query-json=json  [%a (turn queries |=(q=@t s+q))]
          =/  total=@t  (crip (a-co:co (lent queries)))
          ;<  ~  bind:m
            (over:io /brf brief-road [[/ %json] !>((pairs:enjs:format ~[['step' s+'searching'] ['topic' s+topic] ['queries' query-json] ['completed' s+'0'] ['total' s+total]]))])
          ;<  research=@t  bind:m  (run-searches:brfng queries)
          ::  step 3: synthesizing
          ::
          ;<  ~  bind:m
            (over:io /brf brief-road [[/ %json] !>((pairs:enjs:format ~[['step' s+'synthesizing'] ['topic' s+topic] ['queries' query-json] ['research' s+research]]))])
          ;<  =result:oneshot  bind:m
            (synthesize:brfng topic research [%txt 'Write a clear, analytical briefing.'])
          ::  done
          ::
          =/  resp=json
            %-  pairs:enjs:format
            ?:  ?=(%& -.result)
              :~  ['step' s+'done']
                  ['topic' s+topic]
                  ['queries' query-json]
                  ['research' s+research]
                  ['briefing' s+raw.p.result]
              ==
            ~[['step' s+'error'] ['topic' s+topic] ['error' s+'Synthesis failed']]
          ;<  ~  bind:m  (over:io /brf brief-road [[/ %json] !>(resp)])
          $
        ::  extract fields
        =/  system=@t
          =/  v  (~(get by p.req) 'system')
          ?.  ?=([~ %s *] v)  ''
          p.u.v
        =/  prompt=@t
          =/  v  (~(get by p.req) 'prompt')
          ?.  ?=([~ %s *] v)  ''
          p.u.v
        =/  out-mark=@t
          =/  v  (~(get by p.req) 'mark')
          ?.  ?=([~ %s *] v)  'txt'
          p.u.v
        =/  out-desc=@t
          =/  v  (~(get by p.req) 'desc')
          ?.  ?=([~ %s *] v)  'Respond with plain text.'
          p.u.v
        ?:  =('' prompt)  $
        ::  save request, set loading state
        ;<  ~  bind:m  (over:io /req request-road [[/ %json] !>(req)])
        ;<  ~  bind:m
          (over:io /res result-road [[/ %json] !>((pairs:enjs:format ~[['status' s+'loading']]))])
        ::  read config
        ;<  cfg=claude-config:oneshot  bind:m  read-claude-config
        ?:  =('' api-key.cfg)
          ~&  >>>  %oneshot-no-api-key
          ;<  ~  bind:m
            (over:io /res result-road [[/ %json] !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'No API key configured']]))])
          $
        ;<  =result:oneshot  bind:m
          (~(call agent:oneshot cfg) [system prompt [out-mark out-desc]])
        =/  resp=json
          %-  pairs:enjs:format
          ?:  ?=(%& -.result)
            ~[['status' s+'ok'] ['output' s+raw.p.result] ['mark' s+out-mark]]
          ?-  -.p.result
            %&  :~  ['status' s+'error']
                    ['mark' s+out-mark]
                    ['output' s+raw.p.p.result]
                    :-  'error'
                    s+(of-wain:format (turn tang.p.p.result |=(=tank (crip ~(ram re tank)))))
                ==
            %|  ~[['status' s+'error'] ['error' s+p.p.result]]
          ==
        ;<  ~  bind:m  (over:io /res result-road [[/ %json] !>(resp)])
        $
          ::  /ui/page.html: watches result.json, peeks request.json on render
          ::
          [[%ui ~] %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%oneshot page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /res (cord-to-road:tarball '../result.json') ~)
        =/  res=@t
          ?.  ?=([%file *] init)  ''
          (render-result !<(json q.sage.init))
        ;<  req=json  bind:m  (read-request '../request.json')
        ;<  ~  bind:m  (replace:io !>((oneshot-page res req)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /res)
        ?.  ?=([%file *] upd)  $
        =/  res=@t  (render-result !<(json q.sage.upd))
        ;<  req=json  bind:m  (read-request '../request.json')
        ;<  ~  bind:m  (replace:io !>((oneshot-page res req)))
        $
          ::  /ui/briefing.html: watches briefing.json for live progress
          ::
          [[%ui ~] %'briefing.html']
        ;<  ~  bind:m  (rise-wait:io prod "%briefing page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /brf (cord-to-road:tarball '../briefing.json') ~)
        =/  state=json
          ?.  ?=([%file *] init)  ~
          !<(json q.sage.init)
        ;<  ~  bind:m  (replace:io !>((briefing-page-live state)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /brf)
        ?.  ?=([%file *] upd)  $
        =/  state=json  !<(json q.sage.upd)
        ;<  ~  bind:m  (replace:io !>((briefing-page-live state)))
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the oneshot nexus.'
            ~
          %-  crip
          """
          ONESHOT NEXUS — playground for one-shot LLM composition

          Experimental nexus for building and testing composed one-shot
          LLM call pipelines. Each call is independent with no chat history.

          Poke /main.sig with %json containing system and prompt fields.
          View UI at /ui/page.html.
          """
        ==
          %|
        ?+  rail.p.mana  'File under the oneshot nexus.'
          [~ %'ver.ud']        'Schema version. Mark: ud.'
          [~ %'descs.json']    'Mark format descriptions for LLM output constraining. Mark: json.'
          [~ %'request.json']  'Saved request fields (system, prompt, mark, desc). Mark: json.'
          [~ %'main.sig']      'Accepts JSON pokes with system/prompt/mark/desc, runs one-shot call.'
        ==
      ==
    --
|%
++  read-request
  |=  rel=@t
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /req (cord-to-road:tarball rel) `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m ~)
  (pure:m !<(json q.sage.p.seen))
::
++  read-claude-config
  =/  m  (fiber:fiber:nexus ,claude-config:oneshot)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /cfg (cord-to-road:tarball './config/claude.json') `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m ['' 'claude-sonnet-4-20250514' 4.096])
  =/  cfg=json  !<(json q.sage.p.seen)
  ?.  ?=(%o -.cfg)
    (pure:m ['' 'claude-sonnet-4-20250514' 4.096])
  =/  api-key=@t
    =/  v  (~(get by p.cfg) 'api_key')
    ?.  ?=([~ %s *] v)  ''
    p.u.v
  =/  model=@t
    =/  v  (~(get by p.cfg) 'model')
    ?.  ?=([~ %s *] v)  'claude-sonnet-4-20250514'
    p.u.v
  =/  max-tokens=@ud
    =/  v  (~(get by p.cfg) 'max_tokens')
    ?.  ?=([~ %n *] v)  4.096
    (fall (rush p.u.v dem) 4.096)
  (pure:m [api-key model max-tokens])
::
++  read-brave-key
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /cfg (cord-to-road:tarball './config/brave.json') `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m '')
  =/  cfg=json  !<(json q.sage.p.seen)
  ?.  ?=(%o -.cfg)
    (pure:m '')
  =/  v  (~(get by p.cfg) 'api_key')
  ?.  ?=([~ %s *] v)  (pure:m '')
  (pure:m p.u.v)
::
++  render-result
  |=  state=json
  ^-  @t
  ?.  ?=(%o -.state)  ''
  =/  status=(unit json)  (~(get by p.state) 'status')
  ?+  status  ''
    [~ %s %'loading']  'Thinking...'
    [~ %s %'error']
      =/  err=(unit json)  (~(get by p.state) 'error')
      =/  out=(unit json)  (~(get by p.state) 'output')
      %+  rap  3
      :~  'Error: '
          ?:(?=([~ %s *] err) p.u.err 'Unknown error')
          ?:(?=([~ %s *] out) (cat 3 '\0a\0aRaw output:\0a' p.u.out) '')
      ==
    [~ %s %'ok']
      =/  out=(unit json)  (~(get by p.state) 'output')
      ?.  ?=([~ %s *] out)  ''
      p.u.out
  ==
::
++  oneshot-page
  |=  [result=@t req=json]
  ^-  manx
  =/  api=tape  "/grubbery/api"
  =/  base=tape  "oneshot.oneshot"
  =/  sys=tape   (trip (~(dug jo:json-utils req) /system so:dejs:format 'You are a helpful assistant. Reply concisely.'))
  =/  prm=tape   (trip (~(dug jo:json-utils req) /prompt so:dejs:format ''))
  =/  mrk=tape   (trip (~(dug jo:json-utils req) /mark so:dejs:format 'txt'))
  =/  dsc=tape   (trip (~(dug jo:json-utils req) /desc so:dejs:format 'Respond with plain text.'))
  ;html
    ;head
      ;title: Oneshot
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/
          ;:  weld
            "body \{ font-family: monospace; max-width: 600px; margin: 0 auto; padding: 2rem; } "
            "textarea \{ width: 100%; box-sizing: border-box; font-family: monospace; padding: 0.5rem; } "
            "#output \{ white-space: pre-wrap; padding: 1rem; border: 1px solid #ccc; margin-top: 1rem; min-height: 4rem; max-height: 30vh; overflow-y: auto; background: #f9f9f9; word-break: break-word; } "
            "#status \{ margin-top: 0.5rem; padding: 0.4rem 0.6rem; font-size: 0.8rem; border-radius: 3px; display: none; } "
            "#status.ok \{ display: block; background: #e6f4ea; color: #1e7e34; border: 1px solid #b7dfbf; } "
            "#status.error \{ display: block; background: #fce8e6; color: #c62828; border: 1px solid #f5c6cb; } "
            "#status.loading \{ display: block; background: #fff3e0; color: #e65100; border: 1px solid #ffe0b2; } "
            "input \{ font-family: monospace; padding: 0.5rem; box-sizing: border-box; width: 100%; } "
            "button \{ padding: 0.5rem 1rem; margin-top: 0.5rem; cursor: pointer; font-family: monospace; } "
            ".muted \{ opacity: 0.5; } "
            "label \{ display: block; margin-top: 1rem; } "
            "#header \{ display: flex; justify-content: space-between; align-items: baseline; } "
            ".hdr-btn \{ font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; background: none; cursor: pointer; margin-left: 0.4rem; } "
            ".hdr-btn:hover \{ opacity: 0.8; } "
            "#cfg-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.3); z-index: 100; } "
            "#cfg-backdrop.open \{ display: flex; align-items: center; justify-content: center; } "
            "#cfg-modal \{ background: #fff; border: 1px solid #ccc; border-radius: 4px; width: 90%; max-width: 500px; height: 40vh; display: flex; flex-direction: column; padding: 1rem; } "
            "#cfg-header \{ display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 0.75rem; } "
            "#cfg-header span \{ font-size: 0.8rem; font-weight: bold; text-transform: uppercase; opacity: 0.5; } "
            "#cfg-actions button \{ font-size: 0.7rem; margin-left: 0.5rem; } "
            "#cfg-tabs \{ display: flex; gap: 0.3rem; margin-bottom: 0.5rem; } "
            ".cfg-tab \{ font-size: 0.75rem; padding: 0.2rem 0.5rem; border: 1px solid #ccc; border-radius: 3px; background: none; cursor: pointer; font-family: monospace; } "
            ".cfg-tab.active \{ background: #333; color: #fff; border-color: #333; } "
            "#cfg-editor \{ flex: 1; font-family: monospace; font-size: 0.8rem; line-height: 1.5; border: 1px solid #ccc; border-radius: 4px; padding: 0.5rem; resize: none; } "
            "#descs-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.3); z-index: 100; } "
            "#descs-backdrop.open \{ display: flex; align-items: center; justify-content: center; } "
            "#descs-modal \{ background: #fff; border: 1px solid #ccc; border-radius: 4px; width: 90%; max-width: 600px; height: 60vh; display: flex; flex-direction: column; padding: 1rem; } "
            "#descs-list \{ display: flex; gap: 0.3rem; flex-wrap: wrap; margin-bottom: 0.5rem; } "
            "#descs-list button \{ font-size: 0.75rem; padding: 0.2rem 0.5rem; border: 1px solid #ccc; border-radius: 3px; background: none; cursor: pointer; font-family: monospace; } "
            "#descs-list button.active \{ background: #333; color: #fff; border-color: #333; } "
            "#descs-editor \{ flex: 1; font-family: monospace; font-size: 0.8rem; line-height: 1.5; border: 1px solid #ccc; border-radius: 4px; padding: 0.5rem; resize: none; } "
          ==
      ==
    ==
    ;body
      ;div#header
        ;h1: Oneshot
        ;div
          ;a.hdr-btn(href "briefing.html"): briefing
          ;button#descs-btn.hdr-btn: marks
          ;button#config-btn.hdr-btn: config
        ==
      ==
      ;label: System prompt
      ;textarea#system(rows "3"): {sys}
      ;label: Prompt
      ;textarea#prompt(rows "4", placeholder "Ask something..."): {prm}
      ;label: Output mark
      ;input#mark(type "text", value "{mrk}", style "width: 100%; box-sizing: border-box");
      ;label: Format description
      ;textarea#desc(rows "2"): {dsc}
      ;button#send: Send
      ;button#search-btn: Search
      ;div#status;
      ;div#output
        ;+  ;/  ?:(=('' result) "Response will appear here." (trip result))
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
          ;div#cfg-tabs
            ;button.cfg-tab.active(data-file "config/claude.json", onclick "cfgLoad(this.dataset.file)"): claude
            ;button.cfg-tab(data-file "config/brave.json", onclick "cfgLoad(this.dataset.file)"): brave
          ==
          ;textarea#cfg-editor;
        ==
      ==
      ;div#descs-backdrop
        ;div#descs-modal
          ;div#cfg-header
            ;span: Mark Descriptions
            ;button#descs-close.hdr-btn: close
          ==
          ;div#descs-list;
          ;textarea#descs-editor;
        ==
      ==
      ;script
        ;+  ;/
          ;:  weld
            "var API='{api}';var BASE='{base}';"
            ::  load mark descriptions and auto-populate on mark change
            "var DESCS=\{};(async function()\{try\{var r=await fetch(API+'/file/'+BASE+'/descs.json?mark=json');if(r.ok)DESCS=JSON.parse(await r.text())}catch(e)\{}})();document.getElementById('mark').addEventListener('blur',function()\{var m=this.value.trim();if(DESCS[m])document.getElementById('desc').value=DESCS[m]});"
            ::  load latest request on init (server-side may be stale)
            "(async function()\{try\{var r=await fetch(API+'/file/'+BASE+'/request.json?mark=json');if(!r.ok)return;var j=JSON.parse(await r.text());if(j.system)document.getElementById('system').value=j.system;if(j.prompt)document.getElementById('prompt').value=j.prompt;if(j.mark)document.getElementById('mark').value=j.mark;if(j.desc)document.getElementById('desc').value=j.desc}catch(e)\{}})();"
            ::  send: include mark and desc
            "document.getElementById('send').onclick=async function()\{var s=document.getElementById('system').value;var p=document.getElementById('prompt').value.trim();var m=document.getElementById('mark').value.trim()||'txt';var d=document.getElementById('desc').value;if(!p)\{document.getElementById('prompt').style.border='2px solid #c62828';return}document.getElementById('prompt').style.border='';document.getElementById('output').textContent='Sending...';document.getElementById('output').className='muted';await fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{system:s,prompt:p,mark:m,desc:d})})};"
            ::  search button
            "document.getElementById('search-btn').onclick=async function()\{var p=document.getElementById('prompt').value.trim();if(!p)\{document.getElementById('prompt').style.border='2px solid #c62828';return}document.getElementById('prompt').style.border='';document.getElementById('output').textContent='Searching...';document.getElementById('output').className='muted';await fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{action:'search',prompt:p})})};"
            ::  live-save: persist fields on blur
            "function saveFields()\{var b=\{action:'save',system:document.getElementById('system').value,prompt:document.getElementById('prompt').value,mark:document.getElementById('mark').value,desc:document.getElementById('desc').value};fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(b)})}['system','prompt','mark','desc'].forEach(function(id)\{document.getElementById(id).addEventListener('input',saveFields)});"
            ::  config modal: tabs for claude/brave
            "var cfgBack=document.getElementById('cfg-backdrop'),cfgEditor=document.getElementById('cfg-editor'),cfgFile='config/claude.json';"
            "function cfgLoad(f)\{cfgFile=f;document.querySelectorAll('.cfg-tab').forEach(function(b)\{b.className='cfg-tab'+(b.dataset.file===f?' active':'')});fetch(API+'/file/'+BASE+'/'+f+'?mark=json').then(function(r)\{return r.ok?r.text():''}).then(function(t)\{try\{cfgEditor.value=JSON.stringify(JSON.parse(t),null,2)}catch(e)\{cfgEditor.value=t}})}"
            "document.getElementById('config-btn').onclick=function()\{cfgBack.classList.add('open');cfgLoad('config/claude.json')};"
            "document.getElementById('cfg-save').onclick=async function()\{try\{var j=JSON.parse(cfgEditor.value);var r=await fetch(API+'/over/'+BASE+'/'+cfgFile+'?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(j)});if(r.ok)\{cfgBack.classList.remove('open')}else\{alert('Save failed: '+r.status)}}catch(e)\{alert('Invalid JSON: '+e.message)}};"
            "document.getElementById('cfg-close').onclick=function()\{cfgBack.classList.remove('open')};"
            "cfgBack.onclick=function(e)\{if(e.target===cfgBack)cfgBack.classList.remove('open')};"
            ::  descs modal
            "var descsBack=document.getElementById('descs-backdrop'),descsList=document.getElementById('descs-list'),descsEditor=document.getElementById('descs-editor'),curMark='';"
            "function renderDescsList()\{descsList.innerHTML='';Object.keys(DESCS).sort().forEach(function(k)\{var b=document.createElement('button');b.textContent='%'+k;if(k===curMark)b.className='active';b.onclick=function()\{curMark=k;descsEditor.value=DESCS[k];renderDescsList()};descsList.appendChild(b)})}"
            "document.getElementById('descs-btn').onclick=function()\{descsBack.classList.add('open');curMark='';descsEditor.value='Select a mark to view its description.';descsEditor.readOnly=true;renderDescsList()};"
            "document.getElementById('descs-close').onclick=function()\{descsBack.classList.remove('open')};"
            "descsBack.onclick=function(e)\{if(e.target===descsBack)descsBack.classList.remove('open')};"
            ::  SSE: stream result updates
            "async function connect()\{try\{var r=await fetch(API+'/keep/'+BASE+'/result.json?mark=txt',\{headers:\{Accept:'text/event-stream'}});var R=r.body.getReader();var d=new TextDecoder();var buf='';while(true)\{var c=await R.read();if(c.done)break;buf+=d.decode(c.value,\{stream:true});var ps=buf.split('\\n\\n');buf=ps.pop();for(var i=0;i<ps.length;i++)\{if(!ps[i].trim())continue;var data='',ls=ps[i].split('\\n');for(var j=0;j<ls.length;j++)\{if(ls[j].indexOf('data: ')===0)data+=ls[j].slice(6)}if(!data)continue;try\{var j=JSON.parse(data);var o=document.getElementById('output');var st=document.getElementById('status');if(j.status==='loading')\{o.textContent='Thinking...';o.className='muted';st.className='loading';st.textContent='Waiting for response...'}else if(j.status==='ok')\{o.textContent=j.output;o.className='';st.className='ok';st.textContent='Parsed as %'+j.mark}else if(j.status==='error')\{o.textContent=j.output||'';o.className='';st.className='error';st.textContent=j.error;st.style.whiteSpace='pre-wrap'}}catch(e)\{}}}}catch(x)\{}setTimeout(connect,2000)}connect();"
          ==
      ==
    ==
  ==
::
++  briefing-page
  ^-  manx
  (briefing-page-live (pairs:enjs:format ~[['step' s+'idle']]))
::
++  briefing-page-live
  |=  state=json
  ^-  manx
  =/  api=tape  "/grubbery/api"
  =/  base=tape  "oneshot.oneshot"
  =/  step=@t
    ?.  ?=(%o -.state)  'idle'
    =/  v  (~(get by p.state) 'step')
    ?.  ?=([~ %s *] v)  'idle'
    p.u.v
  =/  topic=tape
    ?.  ?=(%o -.state)  ""
    (trip (~(dug jo:json-utils state) /topic so:dejs:format ''))
  =/  briefing=tape
    ?.  ?=(%o -.state)  ""
    (trip (~(dug jo:json-utils state) /briefing so:dejs:format ''))
  =/  error=tape
    ?.  ?=(%o -.state)  ""
    (trip (~(dug jo:json-utils state) /error so:dejs:format ''))
  =/  queries=tape
    ?.  ?=(%o -.state)  ""
    =/  v  (~(get by p.state) 'queries')
    ?.  ?=([~ %a *] v)  ""
    %-  trip
    %-  of-wain:format
    %+  murn  p.u.v
    |=(q=json ?.(?=(%s -.q) ~ `p.q))
  =/  research=tape
    ?.  ?=(%o -.state)  ""
    (trip (~(dug jo:json-utils state) /research so:dejs:format ''))
  ;html
    ;head
      ;title: Briefing
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/
          ;:  weld
            "body \{ font-family: monospace; max-width: 700px; margin: 0 auto; padding: 2rem; } "
            "textarea \{ width: 100%; box-sizing: border-box; font-family: monospace; padding: 0.5rem; } "
            "button \{ padding: 0.5rem 1rem; margin-top: 0.5rem; cursor: pointer; font-family: monospace; } "
            "label \{ display: block; margin-top: 1rem; } "
            "@keyframes pulse \{ 0%,100% \{ opacity: 1; } 50% \{ opacity: 0.4; } } "
            "#step \{ margin-top: 0.5rem; padding: 0.4rem 0.6rem; font-size: 0.8rem; border-radius: 3px; } "
            "#step.idle \{ background: #f0f0f0; color: #666; } "
            "#step.generating-queries \{ background: #fff3e0; color: #e65100; animation: pulse 1.5s ease-in-out infinite; } "
            "#step.searching \{ background: #e3f2fd; color: #1565c0; animation: pulse 1.5s ease-in-out infinite; } "
            "#step.synthesizing \{ background: #fff3e0; color: #e65100; animation: pulse 1.5s ease-in-out infinite; } "
            "#step.done \{ background: #e6f4ea; color: #1e7e34; } "
            "#step.error \{ background: #fce8e6; color: #c62828; } "
            "#preview \{ margin-top: 0.3rem; padding: 0.3rem 0.6rem; font-size: 0.75rem; opacity: 0.6; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-height: 1.2em; } "
            "#tabs \{ display: flex; gap: 0.3rem; margin-top: 0.75rem; } "
            "#tabs button \{ font-size: 0.75rem; padding: 0.25rem 0.6rem; border: 1px solid #ccc; border-radius: 3px 3px 0 0; background: #f0f0f0; cursor: pointer; font-family: monospace; border-bottom: none; position: relative; top: 1px; } "
            "#tabs button.active \{ background: #f9f9f9; border-color: #ccc; border-bottom: 1px solid #f9f9f9; font-weight: bold; } "
            "#tabs button:not(.active):hover \{ background: #e8e8e8; } "
            ".panel \{ border: 1px solid #ccc; border-radius: 0 3px 3px 3px; padding: 1rem; min-height: 6rem; max-height: 60vh; overflow-y: auto; background: #f9f9f9; } "
            "#output \{ white-space: pre-wrap; word-break: break-word; } "
            "#queries-content \{ white-space: pre-wrap; font-size: 0.85rem; opacity: 0.8; } "
            "#search-content \{ white-space: pre-wrap; font-size: 0.85rem; } "
            ".hdr-btn \{ font-size: 0.65rem; text-transform: uppercase; opacity: 0.4; padding: 0.15rem 0.4rem; border: 1px solid #ccc; border-radius: 3px; background: none; cursor: pointer; margin-left: 0.4rem; } "
            ".hdr-btn:hover \{ opacity: 0.8; } "
            "#header \{ display: flex; justify-content: space-between; align-items: baseline; } "
          ==
      ==
    ==
    ;body
      ;div#header
        ;h1: Briefing
        ;a.hdr-btn(href "page.html"): oneshot
      ==
      ;label: Topic
      ;textarea#topic(rows "5", placeholder "What would you like briefed on?"): {topic}
      ;button#go: Brief
      ;div#step(class "{(trip step)}")
        ;+  ;/
          ?+  step  "Ready"
            %idle                "Ready"
            %generating-queries  "Generating search queries..."
            %searching           "Searching..."
            %synthesizing        "Synthesizing briefing..."
            %done                "Briefing complete"
            %error               "Error: {error}"
          ==
      ==
      ;div#preview;
      ;div#tabs
        ;button.tab.active(data-panel "briefing-panel"): Briefing
        ;button.tab(data-panel "queries-panel"): Queries
        ;button.tab(data-panel "search-panel"): Search
      ==
      ;div#briefing-panel.panel
        ;div#output
          ;+  ;/
            ?:  !=(briefing "")  briefing
            ?:  !=(error "")     error
            "Briefing will appear here."
        ==
      ==
      ;div#queries-panel.panel(style "display:none")
        ;div#queries-content
          ;+  ;/  ?:(=(queries "") "No queries yet." queries)
        ==
      ==
      ;div#search-panel.panel(style "display:none")
        ;div#search-content
          ;+  ;/  ?:(=(research "") "No search results yet." research)
        ==
      ==
      ;script
        ;+  ;/
          ;:  weld
            "var API='{api}';var BASE='{base}';"
            ::  tab switching
            "var tabs=document.querySelectorAll('#tabs .tab');"
            "function showTab(id)\{tabs.forEach(function(t)\{t.classList.toggle('active',t.dataset.panel===id)});document.querySelectorAll('.panel').forEach(function(p)\{p.style.display=p.id===id?'':'none'})};"
            "tabs.forEach(function(t)\{t.onclick=function()\{showTab(t.dataset.panel)}});"
            ::  brief button
            "document.getElementById('go').onclick=async function()\{var t=document.getElementById('topic').value.trim();if(!t)\{document.getElementById('topic').style.border='2px solid #c62828';return}document.getElementById('topic').style.border='';await fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{action:'brief',prompt:t})})};"
            ::  SSE: stream briefing state
            "async function connect()\{try\{var r=await fetch(API+'/keep/'+BASE+'/briefing.json?mark=txt',\{headers:\{Accept:'text/event-stream'}});var R=r.body.getReader();var d=new TextDecoder();var buf='';while(true)\{var c=await R.read();if(c.done)break;buf+=d.decode(c.value,\{stream:true});var ps=buf.split('\\n\\n');buf=ps.pop();for(var i=0;i<ps.length;i++)\{if(!ps[i].trim())continue;var data='',ls=ps[i].split('\\n');for(var j=0;j<ls.length;j++)\{if(ls[j].indexOf('data: ')===0)data+=ls[j].slice(6)}if(!data)continue;try\{var j=JSON.parse(data);"
            "var st=document.getElementById('step');var pv=document.getElementById('preview');"
            "var o=document.getElementById('output');var qc=document.getElementById('queries-content');var sc=document.getElementById('search-content');"
            "st.className=j.step||'idle';"
            "if(j.step==='generating-queries')\{st.textContent='Generating search queries...';pv.textContent='';o.textContent='';qc.textContent='';sc.textContent=''}"
            "else if(j.step==='searching')\{st.textContent='Searching... ('+j.total+' queries)';if(j.queries)\{qc.textContent=j.queries.join('\\n');pv.textContent=j.queries.join(', ')}}"
            "else if(j.step==='synthesizing')\{st.textContent='Synthesizing briefing...';pv.textContent='Analyzing '+j.total+' searches...';if(j.research)sc.textContent=j.research;if(j.queries)qc.textContent=j.queries.join('\\n')}"
            "else if(j.step==='done')\{st.textContent='Briefing complete';pv.textContent='';if(j.briefing)o.textContent=j.briefing;if(j.queries)qc.textContent=j.queries.join('\\n');if(j.research)sc.textContent=j.research;showTab('briefing-panel')}"
            "else if(j.step==='error')\{st.textContent='Error: '+(j.error||'unknown');pv.textContent='';if(j.error)o.textContent=j.error}"
            "}catch(e)\{}}}}catch(x)\{}setTimeout(connect,2000)}connect();"
          ==
      ==
    ==
  ==
--
