::  shapeshift: one text box that becomes what you mean. As you type,
::  the input morphs into the right card — an event, a checklist, a
::  bill split, a conversion, a color — and Enter saves it as a grub.
::
::  Split of labour (after anishfn/shapeshift): a decision model says
::  WHICH card and flips a few typed signals; deterministic code in the
::  browser extracts every value (dates, amounts, units, hex). The
::  decision model decides, code computes.
::
::  The browser speaks the TypeSafe systemone shape — {state, questions}
::  in, {answers} out, one typed answer per question (choice / score /
::  noul). This nexus answers it by translating to ONE metered call
::  through the anthropic proxy and back. That translation, +decide, is
::  the only arm that knows an LLM is involved; it is a future `decide`
::  nexus in embryo. With no model reachable, the browser's keyword
::  classifier carries on alone.
::
::    config.json    -- {model}
::    questions.json -- the systemone question schema; seeded once, then
::                      yours to edit (PUT /api/questions or the inspector)
::    cards/         -- saved cards, one json grub each
::    trace/         -- the last 50 model exchanges, one json grub each:
::                      {state, prompt, raw, answers, usage, ms, error}
::    web.sig        -- the UI + api
::
/<  ui-html    shapeshift/index.html
/<  ui-css     shapeshift/style.css
/<  ui-icon    shapeshift/icon.svg
/<  app-js     shapeshift/app.js
/<  decide-js  shapeshift/decide.js
/<  classify-js  shapeshift/classify.js
/<  parse-js   shapeshift/parse.js
/<  cards-js   shapeshift/cards.js
/<  chrono-js  shapeshift/chrono.js
/<  questions  shapeshift/questions.json
/<  nw         /lib/nexus-web.hoon
::  shared web components from /lib/ui
/&  sv-js      /lib/ui/split-view.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Shapeshift'
            info+s+'An input that becomes what you mean'
            color+s+'#1f2328'
            image+s+'/grubbery/tiles/icon/shapeshift'
            href+s+'/grubbery/shapeshift'
        ==
      =/  default-config=json
        (pairs:enjs:format ~[['model' s+'claude-haiku-4-5-20251001']])
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'shapeshift'] ['description' s+'One text box that morphs into the right card']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'decide.js'] [[/ %mime] decide-js]]
          [%over %& [/ %'classify.js'] [[/ %mime] classify-js]]
          [%over %& [/ %'parse.js'] [[/ %mime] parse-js]]
          [%over %& [/ %'cards.js'] [[/ %mime] cards-js]]
          [%over %& [/ %'chrono.js'] [[/ %mime] chrono-js]]
          [%fall %& [/ %'questions.json'] [[/ %json] (need (de:json:html q.q.questions))]]
          [%fall %| /ui empty-dir:loader]
          [%over %& [/ui %'split-view.js'] [[/ %mime] sv-js]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %| /cards empty-dir:loader]
          [%fall %| /trace empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%shapeshift/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/shapeshift])
        (http-dispatch:io %shapeshift)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shapeshift/req: failed")
        (serve name.rail)
      ==
    --
|%
++  proxy  `path`/apps/'anthropic.anthropic'
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'entropy for call ids')
          (line '/sys/eyre/' 'bind the UI route and send page responses')
          (line '/apps/anthropic.anthropic/main.sig' 'one metered model call per intent request')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/apps/anthropic.anthropic/calls/' 'read the call result')
      ==
  ==
::
++  web  ~(. web:nw [%| 1 %& ~ %'web.sig'])
++  reply         reply:web
++  send-json     send-json:web
++  serve-static  serve-static:web
++  jget          jget:nw
++  post-json     post-json:nw
++  file-entries  file-entries:nw
::  +serve: static shell + api:
::    POST /api/intent        {state, questions} -> systemone answers
::    GET  /api/cards         [{id, ...card}]
::    PUT  /api/cards/<id>    card json (create or replace)
::    DELETE /api/cards/<id>
::    GET  /api/config        {model}
::    POST /api/config        {model} merge
::    GET  /api/questions     questions.json
::    PUT  /api/questions     replace questions.json
::    GET  /api/trace         [{id, time, state, model, ms, error}] newest first
::    GET  /api/trace/<id>    the full exchange
::    POST /api/trace-clear   cull them all
::
++  serve
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/shapeshift
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  =/  method  method.request.req
  ?+    suffix  (serve-static eyre-id suffix)
      [%ui @ ~]
    ;<  v=view:nexus  bind:m  (peek:io [%| 1 %& /ui i.t.suffix] `[/ %mime])
    ?.  ?=([%file *] v)  (reply eyre-id 404 'Not found')
    =/  =mime  !<(mime (need-vase:tarball sang.v))
    (send-simple:srv:web eyre-id (mime-response:http-utils mime))
  ::
      [%api %intent ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  state=@t  (jget u.jon 'state')
    =/  questions=(unit json)  (~(get by p.u.jon) 'questions')
    ?:  |(=('' state) ?=(~ questions))  (reply eyre-id 400 'state and questions required')
    ;<  t0=@da  bind:m  get-time:io
    ;<  res=json  bind:m  (decide state u.questions)
    ;<  t1=@da  bind:m  get-time:io
    =/  ms=@ud  (div (sub t1 t0) (div ~s1 1.000))
    =/  res  ?.(?=([%o *] res) res [%o (~(put by p.res) 'ms' (numb:enjs:format ms))])
    ;<  ~  bind:m  (write-trace state res t1)
    (send-json eyre-id res)
  ::
      [%api %cards ~]
    ?.  =(%'GET' method)  (reply eyre-id 405 'GET only')
    ;<  v=view:nexus  bind:m  (peek:io [%| 1 %| /cards] ~)
    =/  cards=(list json)
      %+  murn  (file-entries v)
      |=  [nam=@ta =sang:tarball]
      ^-  (unit json)
      =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang))))
      ?~  jon  ~
      ?.  ?=([%o *] u.jon)  ~
      `[%o (~(put by p.u.jon) 'id' s+(strip-json nam))]
    (send-json eyre-id [%a cards])
  ::
      [%api %cards @ ~]
    =/  id=@ta  i.t.t.suffix
    ?.  (safe-id id)  (reply eyre-id 400 'bad id')
    =/  road=road:tarball  [%| 1 %& /cards (crip "{(trip id)}.json")]
    ?:  =(%'DELETE' method)
      ;<  *  bind:m  (cull-soft:io road)
      (reply eyre-id 200 'ok')
    ?.  =(%'PUT' method)  (reply eyre-id 405 'PUT or DELETE')
    =/  jon=(unit json)
      ?~  body.request.req  ~
      (de:json:html q.u.body.request.req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  card=json  [%o (~(del by p.u.jon) 'id')]
    ;<  cur=view:nexus  bind:m  (peek:io road ~)
    ;<  ~  bind:m
      ?:  ?=([%file *] cur)
        (over:io road [[/ %json] card])
      (make:io road |+[[[/ %json] card] ~])
    (reply eyre-id 200 'ok')
  ::
      [%api %config ~]
    ?:  =(%'GET' method)
      ;<  cfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
      (send-json eyre-id (fall cfg [%o ~]))
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  cur=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
    =/  om=(map @t json)  ?:(?=([~ %o *] cur) p.u.cur ~)
    =/  model=(unit json)  (~(get by p.u.jon) 'model')
    =?  om  &(?=(^ model) ?=([%s *] u.model) !=('' p.u.model))  (~(put by om) 'model' u.model)
    ;<  ~  bind:m  (over:io [%| 1 %& / %'config.json'] [[/ %json] `json`[%o om]])
    (reply eyre-id 200 'ok')
  ::
      [%api %questions ~]
    ?:  =(%'GET' method)
      ;<  q=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'questions.json'] ,json)
      (send-json eyre-id (fall q [%o ~]))
    ?.  =(%'PUT' method)  (reply eyre-id 405 'GET or PUT')
    =/  jon=(unit json)
      ?~  body.request.req  ~
      (de:json:html q.u.body.request.req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  ~  bind:m  (over:io [%| 1 %& / %'questions.json'] [[/ %json] u.jon])
    (reply eyre-id 200 'ok')
  ::
      [%api %trace ~]
    ;<  v=view:nexus  bind:m  (peek:io [%| 1 %| /trace] ~)
    =/  rows=(list json)
      %+  murn  (sort (file-entries v) |=([a=[@ta *] b=[@ta *]] (aor -.b -.a)))
      |=  [nam=@ta =sang:tarball]
      ^-  (unit json)
      =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang))))
      ?~  jon  ~
      ?.  ?=([%o *] u.jon)  ~
      =/  pick  |=(k=@t (fall (~(get by p.u.jon) k) ~))
      %-  some
      %-  pairs:enjs:format
      :~  ['id' s+(strip-json nam)]
          ['time' (pick 'time')]
          ['state' (pick 'state')]
          ['model' (pick 'model')]
          ['ms' (pick 'ms')]
          ['error' (pick 'error')]
      ==
    (send-json eyre-id [%a rows])
  ::
      [%api %trace @ ~]
    =/  id=@ta  i.t.t.suffix
    ?.  (safe-id id)  (reply eyre-id 400 'bad id')
    ;<  res=(unit json)  bind:m
      (peek-as:io [%| 1 %& /trace (crip "{(trip id)}.json")] ,json)
    ?~  res  (reply eyre-id 404 'no such trace')
    (send-json eyre-id u.res)
  ::
      [%api %trace-clear ~]
    ;<  v=view:nexus  bind:m  (peek:io [%| 1 %| /trace] ~)
    =/  names=(list @ta)  (turn (file-entries v) head)
    |-
    ?~  names  (reply eyre-id 200 'ok')
    ;<  *  bind:m  (cull-soft:io [%| 1 %& /trace i.names])
    $(names t.names)
  ==
::  +write-trace: one grub per model exchange, newest-sortable name,
::  capped at the last 50
::
++  write-trace
  |=  [state=@t res=json now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  secs=@ud  (div (sub now ~1970.1.1) ~s1)
  =/  id=@t  (crip "{(a-co:co secs)}-{((x-co:co 4) (end [3 2] eny))}")
  =/  fields=(map @t json)  ?:(?=([%o *] res) p.res ~)
  =/  fields  (~(put by fields) 'state' s+state)
  =/  fields  (~(put by fields) 'time' (sect:enjs:format now))
  ;<  ~  bind:m
    (make:io [%| 1 %& /trace (crip "{(trip id)}.json")] |+[[[/ %json] `json`[%o fields]] ~])
  ;<  v=view:nexus  bind:m  (peek:io [%| 1 %| /trace] ~)
  =/  names=(list @ta)  (sort (turn (file-entries v) head) aor)
  =/  over=@ud  ?:((gth (lent names) 50) (sub (lent names) 50) 0)
  =/  old=(list @ta)  (scag over names)
  |-
  ?~  old  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io [%| 1 %& /trace i.old])
  $(old t.old)
::  +decide: a systemone request answered by an LLM. Builds one prompt
::  from the question schema, asks the anthropic proxy for JSON only,
::  and hands back {model, answers, usage, source}. The browser
::  normalises distributions and derives confidence (float math lives
::  there); this arm is pure translation.
::
++  decide
  |=  [state=@t questions=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  cfg=(unit json)  bind:m  (peek-as:io [%| 1 %& / %'config.json'] ,json)
  =/  model=@t
    =/  mo  ?~(cfg '' (jget u.cfg 'model'))
    ?:(=('' mo) 'claude-haiku-4-5-20251001' mo)
  =/  user=@t
    %-  crip
    ;:  weld
      "STATE:\0a"  (trip state)
      "\0a\0aQUESTIONS:\0a"  (trip (en:json:html questions))
    ==
  =/  body=json
    %-  pairs:enjs:format
    :~  ['model' s+model]
        ['max_tokens' (numb:enjs:format 3.000)]
        ['temperature' [%n '0']]
        ['system' s+system-prompt]
        ['messages' [%a ~[(pairs:enjs:format ~[['role' s+'user'] ['content' s+user]])]]]
    ==
  ;<  resp=(unit json)  bind:m  (call-anthropic body)
  =/  fail  |=(why=json `json`(pairs:enjs:format ~[['error' why] ['prompt' s+user] ['model' s+model]]))
  ?~  resp  (pure:m (fail s+'model call failed'))
  ?.  ?=([%o *] u.resp)  (pure:m (fail s+'bad proxy response'))
  ?^  (~(get by p.u.resp) 'error')
    (pure:m (fail (fall (~(get by p.u.resp) 'error') s+'error')))
  =/  text=@t  (first-text u.resp)
  =/  stop=@t  (jget u.resp 'stop_reason')
  =/  answers=(unit json)  (extract-json text)
  ?~  answers
    =/  why=@t
      ?:  =('max_tokens' stop)  'reply cut off at max_tokens'
      ?:  =('' text)  'model returned no text'
      'model returned no parseable json'
    %-  pure:m
    %-  pairs:enjs:format
    :~  ['error' s+why]  ['prompt' s+user]  ['model' s+model]
        ['raw' s+text]  ['stop_reason' s+stop]
        ['usage' (fall (~(get by p.u.resp) 'usage') [%o ~])]
    ==
  =/  inner=json
    ?.  ?=([%o *] u.answers)  u.answers
    (fall (~(get by p.u.answers) 'answers') u.answers)
  %-  pure:m
  %-  pairs:enjs:format
  :~  ['model' s+(jget u.resp 'model')]
      ['answers' inner]
      ['usage' (fall (~(get by p.u.resp) 'usage') [%o ~])]
      ['source' s+'llm']
      ['prompt' s+user]
      ['raw' s+text]
  ==
::
++  system-prompt
  ^-  @t
  '''
  You are a decision engine, not a chat assistant. You receive a STATE (text a person is typing) and a map of typed QUESTIONS about it. Answer every question, in parallel, judging only the STATE.

  Question types and the exact answer shape for each:
  - "choice": criteria is a map of option -> description. Answer {"type":"choice","choice":"<option>","probabilities":{"<option>":p,...}} with a probability for EVERY option, summing to 1. Read each option's description literally; pick the escape option ("unspecified", "other", "none", "note") when nothing fits.
  - "score": criteria is an ordered list of level descriptions, index 0 upward. Answer {"type":"score","score":<weighted average of the levels>,"probabilities":{"0":p,"1":p,...}} summing to 1.
  - "noul": a yes/no question. Answer {"type":"noul","noul":<probability that the answer is yes, 0..1>}.
  - "text": a short free-text answer described by the instructions, for things you know by name (an IANA time zone, say). Answer {"type":"text","text":"<answer>"} or {"type":"text","text":""} when it does not apply. Never put computed values, dates or numbers here.

  Be calibrated: spread probability when the text is short or ambiguous, concentrate it when the text is clearly one thing. Never extract values, count, or do date math; other code does that.

  Output ONLY a JSON object of the form {"answers":{"<question id>":<answer>,...}}. No prose, no code fences.
  '''
::  +call-anthropic: one metered round-trip through the proxy —
::  subscribe to the call grub, poke {id, body}, await done, drop.
::
++  call-anthropic
  |=  body=json
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  call-id=@t     (scot %uv (end [3 8] eny))
  =/  call-name=@ta  (crip "{(trip call-id)}.json")
  =/  main-road=road:tarball  [%& %& proxy %'main.sig']
  =/  call-road=road:tarball  [%& %& (snoc proxy %calls) call-name]
  ;<  *  bind:m  (keep:io /call call-road ~)
  ;<  err=(unit tang)  bind:m
    %+  poke-soft:io  main-road
    [[/ %json] (pairs:enjs:format ~[['id' s+call-id] ['body' body]])]
  ?^  err
    ;<  ~  bind:m  (drop:io /call call-road)
    (pure:m ~)
  ;<  resp=(unit json)  bind:m  (await-call call-road call-name)
  ;<  ~  bind:m  (drop:io /call call-road)
  ;<  *  bind:m  (cull-soft:io call-road)
  (pure:m resp)
::
++  await-call
  |=  [call-road=road:tarball call-name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  |-
  ;<  raw=wave:nexus  bind:m  (take-news /call)
  =/  hit=(unit cass:clay)
    ?~  fil.raw  ~
    (~(get by file.u.fil.raw) call-name)
  ?~  hit  $
  ;<  =view:nexus  bind:m  (peek-at:io call-road ~ [%ud ud.u.hit])
  ?.  ?=([%file *] view)  $
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  ?.  ?=(%o -.jon)  $
  ?.  ?=([~ %s %'done'] (~(get by p.jon) 'status'))  $
  (pure:m `(fall (~(get by p.jon) 'response') [%o ~]))
::  +take-news: wait for a news wave on a wire; yields the wave so the
::  caller peeks that exact version.
::
++  take-news
  |=  =wire
  =/  m  (fiber:fiber:nexus ,wave:nexus)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
    ~              [%wait ~]
    [~ %news * *]  ?:(=(wire wire.u.in) [%done wave.u.in] [%skip ~])
  ==
::  +first-text: the text of the first text block in a messages response
::
++  first-text
  |=  resp=json
  ^-  @t
  ?.  ?=([%o *] resp)  ''
  =/  content  (~(get by p.resp) 'content')
  ?.  ?=([~ %a *] content)  ''
  =/  items=(list json)  p.u.content
  |-
  ?~  items  ''
  ?:  =('text' (jget i.items 'type'))  (jget i.items 'text')
  $(items t.items)
::  +extract-json: the outermost {...} in a text, parsed; tolerates
::  fences and prose around it
::
++  extract-json
  |=  text=@t
  ^-  (unit json)
  =/  t=tape  (trip text)
  =/  open=(unit @ud)  (find "\{" t)
  ?~  open  ~
  =/  rev=tape  (flop t)
  =/  close=(unit @ud)  (find "}" rev)
  ?~  close  ~
  =/  end=@ud  (sub (lent t) u.close)
  ?:  (lte end u.open)  ~
  (de:json:html (crip (swag [u.open (sub end u.open)] t)))
::
++  strip-json
  |=  nam=@ta
  ^-  @t
  =/  t=tape  (trip nam)
  ?:  =(".json" (slag (sub (lent t) (min 5 (lent t))) t))
    (crip (scag (sub (lent t) 5) t))
  nam
++  safe-id
  |=  id=@ta
  ^-  ?
  =/  t=tape  (trip id)
  ?&  !=(~ t)
      (lte (lent t) 40)
      %+  levy  t
      |=  c=@t
      ?|  &((gte c 'a') (lte c 'z'))
          &((gte c '0') (lte c '9'))
          =(c '-')
      ==
  ==
--
