::  ghostprompter nexus: a ghostwriting dashboard over the nostr flow.
::  (respin: indexer connections + one genuine open question allowed)
::
::  Three surfaces: the flow (the nostr timeline, read from the
::  /apps/nostr mirror: feed.json for the order, one grub per event and
::  per profile), the library (the user's own material as mime grubs
::  under /library), and proposals (drafts the sandboxed agent files
::  under /proposals). The agent cross-references flow and library and
::  proposes posts/replies; nothing is ever posted automatically — the
::  user copies a draft into their nostr client.
::
/&  index-html  ghostprompter/index.html
/&  app-js      ghostprompter/app.js
/&  style-css   ghostprompter/style.css
/&  icon        ghostprompter/icon.svg
::  shared web components from /lib/ui (see itinerary.hoon for the pattern)
/&  sv-js       /lib/ui/split-view.js
/&  tg-js       /lib/ui/tab-group.js
/&  md-js       /lib/ui/modal-dialog.js
/&  dm-js       /lib/ui/drop-menu.js
/&  ft-js       /lib/ui/file-table.js
/&  fg-js       /lib/ui/file-grid.js
/&  cd-js       /lib/ui/card-deck.js
::  classic scripts for the library's file manager (not modules; served as files)
/&  fp-js       /lib/ui/file-preview.js
/&  fmgr-js     /lib/ui/file-manager.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  weld the component modules into one served file (single request);
      ::  each wrapped in { } so top-level consts don't collide.
      =/  wrap
        |=  =mime  ^-  @
        (rap 3 ~[123 10 q.q.mime 10 125 10])
      =/  kit-js=mime
        :-  /application/javascript
        %-  as-octs:mimes:html
        (rap 3 ~[(wrap sv-js) (wrap tg-js) (wrap md-js) (wrap dm-js) (wrap ft-js) (wrap fg-js) (wrap cd-js)])
      =/  weir-json=json
        %-  pairs:enjs:format
        :~  :-  'poke'
            :-  %a
            :~  (pairs:enjs:format ~[['road' s+'/sys/bowl.sig'] ['why' s+'time, identity, entropy — every fiber op']])
                (pairs:enjs:format ~[['road' s+'/sys/eyre/'] ['why' s+'serve the dashboard over HTTP']])
            ==
            :-  'peek'
            :-  %a
            :~  (pairs:enjs:format ~[['road' s+'/apps/nostr/'] ['why' s+'the flow: feed.json, events/, profiles/ (the nostr mirror)']])
            ==
        ==
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Ghostprompter'
            info+s+'Drafts from your library, cued by the flow'
            color+s+'#3d3a52'
            image+s+'/grubbery/ghostprompter/icon.svg'
            href+s+'/grubbery/ghostprompter'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'ghostprompter'] ['description' s+'Ghostwriting dashboard over the nostr flow']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] style-css]]
          [%fall %| /ui empty-dir:loader]
          [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ui %'file-preview.js'] [[/ %mime] fp-js]]
          [%over %& [/ui %'file-manager.js'] [[/ %mime] fmgr-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          ::  the user's material: mime grubs (markdown, notes, extracted
          ::  pdf text), added via the UI, explorer, or MCP
          [%fall %| /library empty-dir:loader]
          ::  the agent's inbox to the user: draft posts/replies
          [%fall %| /proposals empty-dir:loader]
          ::  the ghostwriting agent: a contained, sandboxed chatbot nexus
          ::  (code at nex/ghostprompter/agent.hoon), docs-agent pattern.
          ::  Its weir grants the library (read), proposals (write), the
          ::  metered anthropic proxy, and loopback iris for the feed.
          [%fall %| /agent [`[`[/ghostprompter %agent] `agent-weir %.n ~] ~]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%ghostprompter main: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/ghostprompter])
        (http-dispatch:io %ghostprompter)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%ghostprompter request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /grubbery/ghostprompter
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        =/  method=@t  method.request.req
        ::
        ::  static files
        ::
        ?:  ?&  =(%'GET' method)
                ?|  =(~ suffix)
                    =([%'app.js' ~] suffix)
                    =([%'style.css' ~] suffix)
                    =([%'icon.svg' ~] suffix)
                ==
            ==
          =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
          (serve-file eyre-id / filename)
        ::
        ::  GET /ui/components.js — welded web-component bundle
        ::
        ?:  ?&(=(%'GET' method) =([%ui %'components.js' ~] suffix))
          (serve-file eyre-id /ui 'components.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-preview.js' ~] suffix))
          (serve-file eyre-id /ui 'file-preview.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-manager.js' ~] suffix))
          (serve-file eyre-id /ui 'file-manager.js')
        ::
        ::  GET /api/feed?limit=n — the timeline, from the nostr mirror
        ::
        ?:  ?&(=(%'GET' method) =([%api %feed ~] suffix))
          =/  limit=@ud
            =/  v=@t  (fall (~(get by (malt args)) 'limit') '')
            =/  n=@ud  (fall (rush v dem) 30)
            ?:(=(0 n) 30 (min n 100))
          ;<  posts=json  bind:m  (fetch-feed limit)
          (send-json eyre-id (en:json:html posts))
        ::
        ::  GET /api/post?id=<id> — one flow post by id (a proposal's
        ::  references). Events are immutable grubs, so this is the
        ::  post exactly as it was when cited; plus its author's profile
        ::
        ?:  ?&(=(%'GET' method) =([%api %post ~] suffix))
          =/  want=@t  (fall (~(get by (malt args)) 'id') '')
          ;<  ev=(unit json)  bind:m  (peek-event want)
          ?~  ev  (send-json eyre-id '{"error":"no such event in the mirror"}')
          =/  post=json  (compact-post u.ev)
          ;<  profs=(list [@t json])  bind:m  (fetch-profiles ~[(jget-s post 'pubkey')])
          (send-json eyre-id (en:json:html (pairs:enjs:format ~[['post' post] ['profiles' [%o (malt profs)]]])))
        ::
        ::  GET /api/proposals — every proposal, with its id
        ::
        ?:  ?&(=(%'GET' method) =([%api %proposals ~] suffix))
          ;<  out=json  bind:m  (list-dir-json rail /proposals)
          (send-json eyre-id (en:json:html out))
        ::
        ::  DELETE /api/proposals/[id] — dismiss
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %proposals @ ~] suffix))
          =/  nm=@ta  i.t.t.suffix
          ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /proposals nm]))
          (send-json eyre-id '{"ok":true}')
        ::  the library is a plain directory (/library); its file surface is
        ::  the explorer's ?list=1 + POST actions, driven by lib/ui/file-manager
        ::
        ::  POST /chat → the ghost. Returns {reply, trace, parts}.
        ::
        ?:  &(=('POST' method) ?=([%chat ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  msg=@t  (fall (jget jon 'message') '')
          ;<  [reply=@t trace=json parts=json]  bind:m  (ask-agent rail msg)
          (send-json eyre-id (en:json:html (pairs:enjs:format ~[['reply' s+reply] ['trace' trace] ['parts' parts]])))
        ::
        ::  GET /history → the stored conversation
        ::
        ?:  ?=([%history ~] suffix)
          =/  chat-road=road:tarball
            (nex-road:io rail [%& /agent/chats %'main.json'])
          ;<  fv=view:nexus  bind:m  (peek:io chat-road `[/ %json])
          =/  conv=json
            ?.  ?=([%file *] fv)  [%a ~]
            (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) [%a ~])
          (send-json eyre-id (en:json:html conv))
        ::
        ::  POST /clear → archive + reset the conversation
        ::
        ?:  &(=('POST' method) ?=([%clear ~] suffix))
          ;<  ~  bind:m
            %-  poke:io
            :+  (nex-road:io rail [%& /agent %'main.sig'])
              [/ %json]
            (pairs:enjs:format ~[['action' s+'clear'] ['chat' s+'main']])
          (send-json eyre-id '{"ok":true}')
        ::
        ::  POST /stop → interrupt the agent's current turn
        ::
        ?:  &(=('POST' method) ?=([%stop ~] suffix))
          ;<  ~  bind:m
            %-  poke:io
            :+  (nex-road:io rail [%& /agent %'main.sig'])
              [/ %json]
            (pairs:enjs:format ~[['action' s+'interrupt']])
          (send-json eyre-id '{"ok":true}')
        ::
        ::  POST /config {model, max_tokens} → the agent's config grub.
        ::  The system prompt is product code (gub source, %over) and
        ::  is NOT writable here.
        ::
        ?:  &(=('POST' method) ?=([%config ~] suffix))
          =/  jon=json
            (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
          =/  po=(map @t json)  ?:(?=([%o *] jon) p.jon ~)
          =/  model=@t  =/(mo=@t (fall (jget jon 'model') '') ?:(=('' mo) 'claude-sonnet-4-6' mo))
          =/  mt=json   (fall (~(get by po) 'max_tokens') [%n '2048'])
          ;<  ~  bind:m
            %-  over:io
            :-  (nex-road:io rail [%& /agent %'config.json'])
            [[/ %json] (pairs:enjs:format ~[['model' s+model] ['max_tokens' mt]])]
          (send-json eyre-id '{"ok":true}')
        ::
        ::  GET /config → the agent's current prompt + model config
        ::
        ?:  ?=([%config ~] suffix)
          ;<  sv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /agent %'system.md']) `[/ %mime])
          =/  sys=@t
            ?.  ?=([%file *] sv)  ''
            `@t`q.q:!<(mime (need-vase:tarball sang.sv))
          ;<  cv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& /agent %'config.json']) `[/ %json])
          =/  cfg=json
            ?.  ?=([%file *] cv)  [%o ~]
            (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) [%o ~])
          (send-json eyre-id (en:json:html (pairs:enjs:format ~[['system' s+sys] ['config' cfg]])))
        ::
        ::  404
        ::
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  agent-weir: THE SANDBOX. The complete external reach we grant the
::  ghostprompter agent when we mount it — the kernel refuses all else.
::    make: /proposals (the propose tool files drafts)
::    poke: bowl.sig (time + entropy), the anthropic proxy's main.sig
::    peek: /library, /proposals, proxy calls, and /apps/nostr — the
::          flow (get_feed reads the mirror's feed.json + event grubs)
++  agent-weir
  ^-  weir:tarball
  =/  dir  |=(p=path `road:tarball`[%& %| p])
  =/  fil  |=([p=path n=@ta] `road:tarball`[%& %& p n])
  :*  make=(sy ~[(dir /apps/ghostprompter/proposals)])
      %-  sy
      :~  (fil /sys 'bowl.sig')
          (fil /apps/'anthropic.anthropic' 'main.sig')
      ==
      %-  sy
      :~  (dir /apps/ghostprompter/library)
          (dir /apps/ghostprompter/proposals)
          (dir /apps/'anthropic.anthropic'/calls)
          (dir /apps/nostr)
      ==
  ==
::
::  +jget-s: a json object's string field, or ''
++  jget-s
  |=  [j=json k=@t]
  ^-  @t
  ?.  ?=([%o *] j)  ''
  =/  v  (~(get by p.j) k)
  ?:(?=([~ %s *] v) p.u.v '')
++  serve-file
  |=  [eyre-id=@ta dir=path filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %& dir filename] `[/ %mime])
  ?.  ?=([%file *] view)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.view))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
  (pure:m ~)
::
++  send-json
  |=  [eyre-id=@ta body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
::  +fetch-feed: the timeline from the /apps/nostr mirror, compacted
::  for the dashboard: {posts: [{id, pubkey, content, at}] newest
::  first, profiles: {pubkey: {name, picture}}}. feed.json gives the
::  order; each event and profile is its own grub.
++  fetch-feed
  |=  limit=@ud
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  ids=(list @t)  bind:m  (feed-ids limit)
  ;<  evs=(list json)  bind:m  (peek-events ids)
  =/  posts=(list json)  (turn evs compact-post)
  =/  pks=(list @t)
    =|  seen=(set @t)
    =|  out=(list @t)
    |-  ^-  (list @t)
    ?~  posts  (flop out)
    =/  pk=@t  (jget-s i.posts 'pubkey')
    ?:  |(=('' pk) (~(has in seen) pk))  $(posts t.posts)
    $(posts t.posts, seen (~(put in seen) pk), out [pk out])
  ;<  profs=(list [@t json])  bind:m  (fetch-profiles (scag 40 pks))
  %-  pure:m
  %-  pairs:enjs:format
  :~  ['posts' [%a posts]]
      ['profiles' [%o (malt profs)]]
  ==
::  +feed-ids: the first n ids of the mirror's index (newest first)
++  feed-ids
  |=  limit=@ud
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  idx=(unit json)  bind:m  (peek-as:io [%& %& /apps/nostr %'feed.json'] ,json)
  %-  pure:m
  ?~  idx  ~
  ?.  ?=([%o *] u.idx)  ~
  =/  a  (~(get by p.u.idx) 'ids')
  ?.  ?=([~ %a *] a)  ~
  (murn (scag limit p.u.a) |=(j=json ?:(?=([%s *] j) `p.j ~)))
::  +peek-event / +peek-events: event grubs by id; missing ones skipped
++  peek-event
  |=  id=@t
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ?:  =('' id)  (pure:m ~)
  (peek-as:io [%& %& /apps/nostr/events (cat 3 id '.json')] ,json)
++  peek-events
  |=  ids=(list @t)
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =|  out=(list json)
  |-  ^-  form:m
  ?~  ids  (pure:m (flop out))
  ;<  ev=(unit json)  bind:m  (peek-event i.ids)
  $(ids t.ids, out ?~(ev out [u.ev out]))
::  +compact-post: an event grub as the dashboard's post shape
++  compact-post
  |=  ev=json
  ^-  json
  =/  at=@ud
    ?.  ?=([%o *] ev)  0
    =/  v  (~(get by p.ev) 'created_at')
    ?~  v  0
    (fall (mole |.((ni:dejs:format u.v))) 0)
  %-  pairs:enjs:format
  :~  ['id' s+(jget-s ev 'id')]
      ['pubkey' s+(jget-s ev 'pubkey')]
      ['content' s+(jget-s ev 'content')]
      ['at' (numb:enjs:format at)]
  ==
::  +fetch-profiles: profiles/<pk>.json per pubkey, trimmed to what the
::  flow cards render; an unknown author gets an empty profile
++  fetch-profiles
  |=  pks=(list @t)
  =/  m  (fiber:fiber:nexus ,(list [@t json]))
  ^-  form:m
  =|  out=(list [@t json])
  |-  ^-  form:m
  ?~  pks  (pure:m (flop out))
  ;<  prof=(unit json)  bind:m
    (peek-as:io [%& %& /apps/nostr/profiles (cat 3 i.pks '.json')] ,json)
  =/  slim=json
    ?~  prof  [%o ~]
    (pairs:enjs:format ~[['name' s+(jget-s u.prof 'name')] ['picture' s+(jget-s u.prof 'picture')]])
  $(pks t.pks, out [[i.pks slim] out])
::  +list-dir-json: every json grub in a dir as [{id, doc}].
++  list-dir-json
  |=  [=rail:tarball dir=path]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  =/  entries
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    ~(tap by contents.u.fil.ball.dv)
  %-  pure:m
  :-  %a
  %+  murn  entries
  |=  [nm=@ta ent=[=sang:tarball *]]
  ^-  (unit json)
  =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang.ent))))
  ?~  jon  ~
  `(pairs:enjs:format ~[['id' s+nm] ['doc' u.jon]])
::  +ask-agent: bridge one browser turn to the agent nexus. Subscribe to
::  the conversation grub, poke the agent's main.sig, await its assistant
::  write, and return the reply + trace.
++  ask-agent
  |=  [=rail:tarball message=@t]
  =/  m  (fiber:fiber:nexus ,[reply=@t trace=json parts=json])
  ^-  form:m
  =/  chat-road=road:tarball
    (nex-road:io rail [%& /agent/chats %'main.json'])
  =/  main-road=road:tarball
    (nex-road:io rail [%& /agent %'main.sig'])
  ;<  *  bind:m  (keep:io /agent chat-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    (pairs:enjs:format ~[['message' s+message] ['chat' s+'main']])
  ;<  conv=json  bind:m  (await-agent chat-road)
  ;<  ~  bind:m  (drop:io /agent chat-road)
  =/  msgs=(list json)  ?.(?=([%a *] conv) ~ p.conv)
  ?~  msgs  (pure:m ['(no reply)' [%a ~] [%a ~]])
  =/  last=json  (rear msgs)
  ?.  ?=([%o *] last)  (pure:m ['(no reply)' [%a ~] [%a ~]])
  =/  reply=@t
    (fall (bind (~(get by p.last) 'content') |=(j=json ?>(?=(%s -.j) p.j))) '')
  =/  trace=json  (fall (~(get by p.last) 'trace') [%a ~])
  =/  parts=json  (fall (~(get by p.last) 'parts') [%a ~])
  (pure:m [reply trace parts])
::  +await-agent: wait for the agent's ASSISTANT write to the conversation
::  grub (it writes the user message first, then the completed turn).
++  await-agent
  |=  chat-road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  |-
  ;<  ~  bind:m  (take-news /agent)
  ;<  =view:nexus  bind:m  (peek:io chat-road ~)
  ?.  ?=([%file *] view)  $
  =/  conv=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) [%a ~])
  =/  msgs=(list json)  ?.(?=([%a *] conv) ~ p.conv)
  ?~  msgs  $
  =/  last=json  (rear msgs)
  ?.  &(?=([%o *] last) ?=([~ %s %'assistant'] (~(get by p.last) 'role')))  $
  (pure:m conv)
::  +take-news: wait for a news wave on a wire.
++  take-news
  |=  =wire
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~              [%wait ~]
    [~ %news * *]  ?:(=(wire wire.u.in) [%done ~] [%skip ~])
  ==
::  +jget: a json object's string field, or ~.
++  jget
  |=  [j=json k=@t]
  ^-  (unit @t)
  ?.  ?=(%o -.j)  ~
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) ~ `p.u.v)
--
