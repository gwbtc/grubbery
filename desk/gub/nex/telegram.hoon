::  telegram nexus: parent nexus for managing Telegram bots
::
::    Each subdirectory is a telegram-bot nexus instance.
::    UI at /ui/manage.html for adding/deleting bots.
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%over %& [/ui %'manage.html'] %.n [~ [/ %manx] !>((manage-page ~))]]
            [%fall %| /bots [~ ~] [~ ~] empty-dir:loader]
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
          ::  /main.sig: handle add/delete bot pokes
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%telegram main: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ?.  ?=(%json name.p.sage)  $
        =/  req=json  !<(json q.sage)
        ?.  ?=([%o *] req)  $
        =/  action=@t
          =/  v  (~(get by p.req) 'action')
          ?.  ?=([~ %s *] v)  ''
          p.u.v
        ?+    action  $
            %add
          =/  bot-name=@t
            =/  v  (~(get by p.req) 'name')
            ?.  ?=([~ %s *] v)  ''
            p.u.v
          =/  bot-token=@t
            =/  v  (~(get by p.req) 'token')
            ?.  ?=([~ %s *] v)  ''
            p.u.v
          ?:  |(=('' bot-name) =('' bot-token))  $
          ::  sanitize name: lowercase, replace spaces with hyphens,
          ::  keep only a-z 0-9 and hyphens
          =/  dir-name=@ta
            %-  crip
            ^-  tape
            %+  murn  `tape`(cass (trip bot-name))
            |=  c=@tD
            ^-  (unit @tD)
            ?:  &((gte c 'a') (lte c 'z'))  `c
            ?:  &((gte c '0') (lte c '9'))  `c
            ?:  |(=(c ' ') =(c '-') =(c '_'))  `'-'
            ~
          ?:  =('' dir-name)  $
          ::  check if bot already exists
          ;<  =seen:nexus  bind:m
            (peek:io /chk [%| 0 %| /bots/[dir-name]] ~)
          ?.  ?=([%& %none *] seen)
            ~&  >>  [%telegram-bot-already-exists dir-name]
            $
          =/  new-ball=ball:tarball  [`[~ `[/ %telegram-bot] ~] ~]
          ;<  ~  bind:m
            (make:io /add [%| 0 %| /bots/[dir-name]] &+[*sand:nexus *gain:nexus new-ball])
          ::  write the bot token into its config
          =/  cfg=json
            (pairs:enjs:format ~[['bot-token' s+bot-token]])
          =/  cfg-road=road:tarball
            (cord-to-road:tarball (rap 3 ~['./bots/' dir-name '/config.json']))
          ;<  ~  bind:m  (over:io /cfg cfg-road [[/ %json] !>(cfg)])
          $
        ::
            %delete
          =/  bot-name=@t
            =/  v  (~(get by p.req) 'name')
            ?.  ?=([~ %s *] v)  ''
            p.u.v
          ?:  =('' bot-name)  $
          =/  dir-name=@ta  bot-name
          ;<  ~  bind:m  (cull:io /del [%| 0 %| /bots/[dir-name]])
          $
        ==
          ::  /ui/manage.html: bot management view
          ::
          [[%ui ~] %'manage.html']
        ;<  ~  bind:m  (rise-wait:io prod "%telegram manage: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /bots [%| 1 %| /bots] ~)
        =/  bot-names=(list @ta)  (view-to-bot-names init)
        ;<  ~  bind:m  (replace:io !>((manage-page bot-names)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /bots)
        =/  bot-names=(list @ta)  (view-to-bot-names upd)
        ;<  ~  bind:m  (replace:io !>((manage-page bot-names)))
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'A telegram-bot instance.'
            ~
          %-  crip
          """
          TELEGRAM — parent nexus for Telegram bots

          Each subdirectory is a telegram-bot nexus instance with its own
          config, message log, and polling loop.

          Manage bots at /ui/manage.html.
          """
        ==
          %|
        ?+  rail.p.mana  'File under the telegram nexus.'
          [~ %'main.sig']              'Handles add/delete bot pokes.'
          [[%ui ~] %'manage.html']     'Bot management UI.'
        ==
      ==
    --
|%
::
++  view-to-bot-names
  |=  =view:nexus
  ^-  (list @ta)
  ?.  ?=([%ball *] view)  ~
  ~(tap in ~(key by dir.ball.view))
::
++  manage-page
  |=  bots=(list @ta)
  ^-  manx
  =/  api=tape  "/grubbery/api"
  =/  ball=tape  "/grubbery/ball/telegram.telegram/bots"
  =/  base=tape  "telegram.telegram"
  ;html
    ;head
      ;title: Telegram Bots
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/
          ;:  weld
            "body \{ font-family: monospace; max-width: 700px; margin: 0 auto; padding: 2rem; } "
            "#header \{ display: flex; justify-content: space-between; align-items: baseline; } "
            ".bot-list \{ margin: 1rem 0; } "
            ".bot-item \{ display: flex; justify-content: space-between; align-items: center; padding: 0.5rem 0.75rem; border: 1px solid #ccc; border-radius: 4px; margin-bottom: 0.5rem; } "
            ".bot-item a \{ color: #333; text-decoration: none; font-weight: bold; } "
            ".bot-item a:hover \{ text-decoration: underline; } "
            ".bot-item button \{ font-size: 0.7rem; padding: 0.2rem 0.5rem; border: 1px solid #c62828; border-radius: 3px; background: none; color: #c62828; cursor: pointer; font-family: monospace; } "
            ".bot-item button:hover \{ background: #fce8e6; } "
            "#add-form \{ border: 1px solid #ccc; border-radius: 4px; padding: 1rem; margin-top: 1rem; } "
            "#add-form h3 \{ margin: 0 0 0.75rem 0; font-size: 0.85rem; text-transform: uppercase; opacity: 0.5; } "
            "#add-form label \{ display: block; margin-top: 0.5rem; font-size: 0.8rem; opacity: 0.6; } "
            "#add-form input \{ width: 100%; box-sizing: border-box; font-family: monospace; padding: 0.4rem; border: 1px solid #ccc; border-radius: 4px; margin-top: 0.2rem; } "
            "#add-form button \{ margin-top: 0.75rem; padding: 0.5rem 1rem; font-family: monospace; cursor: pointer; border: 1px solid #ccc; border-radius: 4px; background: #333; color: #fff; } "
            "#add-form button:hover \{ background: #555; } "
            ".empty \{ opacity: 0.4; text-align: center; padding: 2rem; } "
          ==
      ==
    ==
    ;body
      ;div#header
        ;h1: Telegram Bots
      ==
      ;div.bot-list
        ;*  ?~  bots
              =/  empty=manx  ;span.empty: No bots configured
              ~[empty]
            %+  turn  bots
            |=  id=@ta
            =/  dir=tape  (trip id)
            =/  href=tape
              "{ball}/{dir}/ui/chat.html"
            ;div.bot-item
              ;a(href href): {dir}
              ;button(onclick "deletBot('{dir}')"): delete
            ==
      ==
      ;div#add-form
        ;h3: Add Bot
        ;label: Name
        ;input#bot-name(type "text", placeholder "mybot", autocomplete "off");
        ;label: Bot Token
        ;input#bot-token(type "text", placeholder "123456:ABC-DEF...", autocomplete "off");
        ;button#add-btn: Create Bot
      ==
      ;script
        ;+  ;/
          ;:  weld
            "var API='{api}';var BASE='{base}';"
            "function sanitize(s)\{return s.toLowerCase().replace(/[^a-z0-9]/g,'-').replace(/-+/g,'-').replace(/^-|-$/g,'')}"
            "var nameInput=document.getElementById('bot-name');"
            "nameInput.oninput=function()\{var s=sanitize(this.value);this.title=s?'Will create: '+s:''};"
            "document.getElementById('add-btn').onclick=async function()\{var n=sanitize(document.getElementById('bot-name').value);var t=document.getElementById('bot-token').value.trim();if(!n||!t)\{alert('Name and token are required');return}await fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{action:'add',name:n,token:t})});location.reload()};"
            "function deletBot(name)\{if(!confirm('Delete bot '+name+'?'))return;fetch(API+'/poke/'+BASE+'/main.sig?mark=json',\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{action:'delete',name:name})}).then(function()\{location.reload()})}"
          ==
      ==
    ==
  ==
--
