::  claw/app: agent container nexus
::
::  Creates and manages claw agents in /agents/, api proxies in
::  /apis/, channels in /channels/, and autonomous assistants in
::  /assistants/ (any <name>.assistant/ dir at any depth; plain dirs
::  are categories).
::
::  UI is the standard requests pattern: /ui/http.sig binds
::  /grubbery/claw and dispatches; /ui/requests/* serve the static
::  shell plus /api/state.json. Mutations are JSON action pokes to
::  main.sig (via the generic /grubbery/api/poke path).
::
/<  rules  /lib/rules.hoon
/<  asst   /lib/nex/assistant.hoon
/&  man  ../../man/claw/app/readme.md
/&  icon  icon.svg
/&  app-html   app/index.html
/&  app-js     app/app.js
/&  app-css    app/style.css
/&  asst-html   app/assistants.html
/&  asst-js     app/assistants.js
/&  asst1-html  app/assistant.html
/&  asst1-js    app/assistant.js
/&  cfg-js      app/config-modal.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Claw'
            info+s+'Agents & assistants'
            color+s+'#8a4a4a'
            image+s+'/grubbery/tiles/icon/claw'
            href+s+'/grubbery/claw'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /apis empty-dir:loader]
          [%fall %| /apis/anthropic [`[`[/claw/api %anthropic] ~ %.n ~] ~]]
          [%fall %| /agents empty-dir:loader]
          [%fall %| /agents/main [`[`[/claw %agent] `main-agent-weir %.n ~] ~]]
          [%fall %| /assistants empty-dir:loader]
          [%fall %| /channels empty-dir:loader]
          [%fall %| /channels/telegram/main-bot [`[`[/claw/channel %telegram] ~ %.n ~] ~]]
          [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
          [%over %& [/ui %'index.html'] [[/ %mime] app-html]]
          [%over %& [/ui %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ui %'style.css'] [[/ %mime] app-css]]
          [%over %& [/ui %'assistants.html'] [[/ %mime] asst-html]]
          [%over %& [/ui %'assistants.js'] [[/ %mime] asst-js]]
          [%over %& [/ui %'assistant.html'] [[/ %mime] asst1-html]]
          [%over %& [/ui %'assistant.js'] [[/ %mime] asst1-js]]
          [%over %& [/ui %'config-modal.js'] [[/ %mime] cfg-js]]
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
          [[%ui ~] %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app http: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/claw])
        (http-dispatch:io %claw)
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app request: failed")
        =/  eyre-id=@ta  name.rail
        =/  s  (srv rail)
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:s eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path
          %+  skip  (slag (lent `path`/grubbery/claw) site)
          |=(s=@ta =('' s))
        ::  /api/state.json: everything the shell renders
        ?:  ?=([%api %'state.json' ~] suffix)
          (serve-state eyre-id rail)
        ::  /api/tree.json?path=…: files inside one assistant dir
        ?:  ?=([%api %'tree.json' ~] suffix)
          (serve-tree eyre-id rail (fall (get-key:kv:html-utils 'path' args) ''))
        ::  static shell; /assistants is the explorer page and
        ::  /assistants/<path> the per-assistant detail page
        =/  filename=@ta
          ?~  suffix  'index.html'
          ?:  ?=([%assistants ~] suffix)  'assistants.html'
          ?:  ?=([%assistants ^] suffix)  'assistant.html'
          i.suffix
        ;<  file-view=view:nexus  bind:m
          (peek:io (nex-road:io rail [%& ~[%ui] filename]) `[/ %mime])
        ?.  ?=([%file *] file-view)
          ;<  ~  bind:m  (send-simple:s eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.file-view))
        ;<  ~  bind:m  (send-simple:s eyre-id (mime-response:http-utils mime))
        (pure:m ~)
          ::
          ::  assistants: any <name>.assistant/ dir under /assistants
          ::  (at any depth; plain dirs are categories). The fiber
          ::  walks the recur, waits, runs the code, pushes output.
          ::  Any poke to main.assistant restarts it. Missed
          ::  occurrences while the ship slept are skipped.
          ::
          [[%assistants *] %'main.assistant']
        ?.  (asst-dir path.rail)  stay:m
        =/  who=@t  (crip (spud t.path.rail))
        ;<  ~  bind:m  (rise-wait:io prod "%assistant {(trip who)}: failed")
        |-
        ;<  jon=json  bind:m  (get-state-as:io ,json)
        ?.  (enabled jon)  stay:m
        ::  self-healing registration: cheap, idempotent, and immune
        ::  to start-ordering races between claw and the service
        ;<  ~  bind:m  (register-app:io 'claw')
        =/  code=@t  (gs jon 'code')
        ?:  =('' code)
          ~&  >>>  "%assistant {(trip who)}: no code named"
          stay:m
        ;<  now=@da  bind:m  get-time:io
        ;<  when=(unit @da)  bind:m  (next-fire jon now)
        ?~  when
          ~&  >>>  "%assistant {(trip who)}: no future occurrence"
          stay:m
        ~&  >  "%assistant {(trip who)}: next run {(scow %da u.when)}"
        ;<  ~  bind:m  (wait:io u.when)
        ;<  code-vase=(unit vase)  bind:m
          (get-code:io &+&+[/code/lib/assistants (slav %tas code)])
        ?~  code-vase
          ~&  >>>  "%assistant {(trip who)}: /code/lib/assistants/{(trip code)} not built"
          stay:m
        =/  gate=(each assistant:asst tang)
          (mule |.(!<(assistant:asst u.code-vase)))
        ?:  ?=(%| -.gate)
          ~&  >>>  "%assistant {(trip who)}: code does not fit the contract"
          stay:m
        =/  args=json
          (fall (~(get by ?:(?=(%o -.jon) p.jon ~)) 'args') [%o ~])
        ;<  out=output:asst  bind:m  (p.gate args u.when)
        ~&  >  "%assistant {(trip who)}: run done, output {?~(out "empty" "present")}"
        ;<  ~  bind:m  (save-output u.when out)
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        ;<  ~  bind:m
          ?~  out  (pure:(fiber:fiber:nexus ,~) ~)
          %+  notify:io  %.y
          %-  pairs:enjs:format
          :~  ['title' s+title.u.out]
              ['body' s+body.u.out]
              ::  link straight to this run's saved output grub
              ['url' s+(crip "/grubbery/ball{(spud path.here)}/outputs/{(scow %da u.when)}.md")]
          ==
        ~&  >  "%assistant {(trip who)}: notified"
        $
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%claw/app main: failed")
        ::  claim the 'claw' app name; covers the whole subtree,
        ::  so every assistant's notifications attribute to it
        ;<  ~  bind:m  (register-app:io 'claw')
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
        ::
            %'assistant-create'
          ::  path like "daily/morning" — .assistant suffix appended here
          =/  pat=@t
            (fall (bind (~(get by p.jon) 'path') |=(=json ?>(?=(%s -.json) p.json))) '')
          =/  pax=(unit path)  (parse-asst-path pat)
          ?~  pax
            ~&  >>>  "%claw/app: assistant-create bad path"
            $
          =/  dir=path  (weld /assistants u.pax)
          ;<  ~  bind:m
            (make:io (cord-to-road:tarball (crip "./{(spud dir)}/")) &+[~ ~])
          ;<  ~  bind:m
            %+  over:io
              (cord-to-road:tarball (crip "./{(spud dir)}/main.assistant"))
            :-  [/ %json]
            ^-  json
            %-  pairs:enjs:format
            :~  ['code' s+'today']
                ['enabled' b+%.n]
                ['args' [%o ~]]
                :-  'recur'
                %-  pairs:enjs:format
                :~  ['kind' s+'daily']
                    ['args' (pairs:enjs:format ~[['at' (numb:enjs:format 480)]])]
                    ['start_ms' (numb:enjs:format 1.784.937.600.000)]
                ==
                ['zone' s+'America/New_York']
            ==
          $
        ::
            %'assistant-delete'
          =/  pat=@t
            (fall (bind (~(get by p.jon) 'path') |=(=json ?>(?=(%s -.json) p.json))) '')
          =/  pax=(unit path)  (parse-asst-path pat)
          ?~  pax  $
          =/  dir=path  (weld /assistants u.pax)
          ;<  ~  bind:m  (cull:io (cord-to-road:tarball (crip "./{(spud dir)}/")))
          $
        ==
      ==
    --
::
|%
::  +srv: the http responder, road derived from the request rail —
::  never hand-count bend steps
::
++  srv
  |=  =rail:tarball
  ~(. http-res:io (nex-road:io rail [%& ~[%ui] %'http.sig']))
::  +agents-weir: weir for individual agent at ./agents/{name}/
::
++  agents-weir
  ^-  weir:nexus
  :+  ~
    (sy ~[&+[%& /sys %'bowl.sig'] |+[2 |+/apis] |+[2 |+/channels] &+[%& /sys/behn %'main.behn-state'] &+[%& /sys/push %'main.push-state']])
  (sy ~[&+[%| /]])
::  +main-agent-weir: agents-weir + make/poke on /agents
::
++  main-agent-weir
  ^-  weir:nexus
  :+  (sy ~[|+[2 |+/agents]])
    (sy ~[&+[%& /sys %'bowl.sig'] |+[2 |+/apis] |+[2 |+/channels] |+[2 |+/agents] &+[%& /sys/behn %'main.behn-state'] &+[%& /sys/push %'main.push-state']])
  (sy ~[&+[%| /]])
::  +asst-dir: does this path name an assistant instance — its last
::  segment carries the .assistant suffix?
::
++  asst-dir
  |=  pax=path
  ^-  ?
  ?~  pax  %.n
  =/  t=tape  (trip (rear pax))
  =/  len=@ud  (lent t)
  ?&  (gth len 10)
      =(".assistant" (slag (sub len 10) t))
  ==
::
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  (fall (bind (~(get by p.jon) k) |=(=json ?>(?=(%s -.json) p.json))) '')
::
++  gn
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  ?.  ?=(%o -.jon)  ~
  =/  j=(unit json)  (~(get by p.jon) k)
  ?.  ?=([~ %n *] j)  ~
  (rush p.u.j dem)
::
++  enabled
  |=  jon=json
  ^-  ?
  ?.  ?=(%o -.jon)  %.n
  =/  e=(unit json)  (~(get by p.jon) 'enabled')
  ?.(?=([~ %b *] e) %.y p.u.e)
::  +save-output: persist a run's notification as a dated grub in
::  the instance's own outputs/ dir (relative roads resolve against
::  the running fiber's rail). Silent runs leave no artifact.
::
++  save-output
  |=  [when=@da out=output:asst]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  out  (pure:m ~)
  ;<  *  bind:m  (make-soft:io (cord-to-road:tarball './outputs/') &+[~ ~])
  =/  txt=@t  (cat 3 title.u.out (cat 3 '\0a\0a' body.u.out))
  %+  put:io
    (cord-to-road:tarball (crip "./outputs/{(scow %da when)}.md"))
  [[/ %txt] (to-wain:format txt)]
::  +next-fire: walk the recur from idx 0 to the first realized utc
::  moment strictly after now. ~ = rule exhausted or unresolvable.
::
++  next-fire
  |=  [jon=json now=@da]
  =/  m  (fiber:fiber:nexus ,(unit @da))
  ^-  form:m
  =/  recur=json
    ?.  ?=(%o -.jon)  *json
    (fall (~(get by p.jon) 'recur') *json)
  =/  kind=@t  (gs recur 'kind')
  =/  start=(unit @da)
    (bind (gn recur 'start_ms') |=(ms=@ud (add ~1970.1.1 (div (mul ms ~s1) 1.000))))
  ?:  |(=('' kind) ?=(~ start))  (pure:m ~)
  =/  kargs=(map @t json)
    ?.  ?=(%o -.recur)  ~
    =/  a=(unit json)  (~(get by p.recur) 'args')
    ?.(?=([~ %o *] a) ~ p.u.a)
  =/  zone=(unit @t)
    =/  z=@t  (gs jon 'zone')
    ?:(=('' z) ~ `z)
  ;<  kv=(unit vase)  bind:m
    (get-code:io &+&+[/code/lib/rules (slav %tas kind)])
  ?~  kv  (pure:m ~)
  =/  kg=(each kind:rules tang)  (mule |.(!<(kind:rules u.kv)))
  ?:  ?=(%| -.kg)  (pure:m ~)
  =/  idx=@ud  0
  =/  dead=@ud  0
  =/  fuel=@ud  10.000
  |-
  ?:  |((gth dead 400) =(0 fuel))  (pure:m ~)
  =/  moment=(unit @da)
    (fall (mole |.((p.kg kargs u.start idx))) ~)
  ?~  moment  $(idx +(idx), dead +(dead))
  =/  utcs=(list @da)  (realize:rules zone u.moment)
  ?:  &(?=(^ utcs) (gth i.utcs now))
    (pure:m `i.utcs)
  $(idx +(idx), dead 0, fuel (dec fuel))
::  +parse-asst-path: "daily/morning" -> /daily/morning.assistant
::  (suffix appended to the last segment if absent). ~ = invalid.
::
++  parse-asst-path
  |=  pat=@t
  ^-  (unit path)
  =/  segs=(list @ta)
    =/  t=tape  (trip pat)
    =/  out=(list @ta)  ~
    =/  buf=tape  ~
    |-  ^-  (list @ta)
    ?~  t
      ?~(buf (flop out) (flop [(crip (flop buf)) out]))
    ?:  =('/' i.t)
      ?~(buf $(t t.t) $(t t.t, out [(crip (flop buf)) out], buf ~))
    $(t t.t, buf [i.t buf])
  ?~  segs  ~
  =/  last=@ta  (rear segs)
  =/  t=tape  (trip last)
  =/  len=@ud  (lent t)
  =/  suffixed=@ta
    ?:  &((gth len 10) =(".assistant" (slag (sub len 10) t)))  last
    (cat 3 last '.assistant')
  `(weld (snip `(list @ta)`segs) ~[suffixed])
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
::  +find-assistants: usergroups-style suffix walk — every
::  <name>.assistant dir at any depth, path with suffix stripped
::
++  find-assistants
  |=  [pax=path entries=(map @ta ball:tarball)]
  ^-  (list path)
  %-  zing
  %+  turn  ~(tap by entries)
  |=  [name=@ta kid=ball:tarball]
  ^-  (list path)
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?:  &((gth len 10) =(".assistant" (slag (sub len 10) t)))
    ~[(snoc pax (crip (scag (sub len 10) t)))]
  (find-assistants (snoc pax name) dir.kid)
::  +serve-tree: file listing of one assistant's directory. pat is
::  the suffix-less path ("planning/morning"); files come back as
::  [path blot] pairs, paths relative to the assistant dir.
::
++  serve-tree
  |=  [eyre-id=@ta =rail:tarball pat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  pax=(unit path)  (parse-asst-path pat)
  ?~  pax
    ;<  ~  bind:m  (send-simple:(srv rail) eyre-id [[400 ~] `(as-octs:mimes:html 'bad path')])
    (pure:m ~)
  =/  dir=path  (weld /assistants u.pax)
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  ?.  ?=([%ball *] view)
    ;<  ~  bind:m  (send-simple:(srv rail) eyre-id [[404 ~] `(as-octs:mimes:html 'not found')])
    (pure:m ~)
  =/  files=(list json)
    %+  turn  (walk-files ~ ball.view)
    |=  [pax=path blot=@ta]
    (pairs:enjs:format ~[['path' s+(crip (spud pax))] ['blot' s+blot]])
  =/  bod=octs
    (as-octs:mimes:html (en:json:html [%a files]))
  ;<  ~  bind:m
    (send-simple:(srv rail) eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  (pure:m ~)
::  +walk-files: every file in a ball subtree as [path blot-name]
::
++  walk-files
  |=  [pax=path bal=ball:tarball]
  ^-  (list [path @ta])
  =/  here=(list [path @ta])
    ?~  fil.bal  ~
    =/  fis  ~(tap by contents.u.fil.bal)
    |-  ^-  (list [path @ta])
    ?~  fis  ~
    [[(snoc pax p.i.fis) name.p.sang.q.i.fis] $(fis t.fis)]
  =/  kids  ~(tap by dir.bal)
  |-  ^-  (list [path @ta])
  ?~  kids  here
  (weld (walk-files (snoc pax p.i.kids) q.i.kids) $(kids t.kids))
::  +serve-state: the one JSON the shell renders from
::
++  serve-state
  |=  [eyre-id=@ta =rail:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  here=rail:tarball  bind:m  get-here-abs:io
  =/  root=path  (snip (snip path.here))
  ;<  agents-view=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /agents]) ~)
  ;<  apis-view=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /apis]) ~)
  ;<  chans-view=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /channels]) ~)
  ;<  assts-view=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /assistants]) ~)
  =/  assts=(list path)
    ?.  ?=([%ball *] assts-view)  ~
    (find-assistants ~ dir.ball.assts-view)
  ::  per-assistant config peek
  =/  out=(list json)  ~
  |-
  ?^  assts
    =/  dir=path
      %+  weld  `path`/assistants
      (snoc (snip i.assts) (cat 3 (rear i.assts) '.assistant'))
    ;<  cfg-view=view:nexus  bind:m
      (peek:io (nex-road:io rail [%& dir %'main.assistant']) `[/ %json])
    =/  cfg=json
      ?.  ?=([%file *] cfg-view)  *json
      (fall (mole |.(!<(json (need-vase:tarball sang.cfg-view)))) *json)
    =/  entry=json
      %-  pairs:enjs:format
      :~  ['path' s+(crip (zing (join "/" (turn i.assts trip))))]
          ['config' cfg]
      ==
    $(assts t.assts, out [entry out])
  =/  =json
    %-  pairs:enjs:format
    :~  ['ball' s+(crip (zing (join "/" (turn root trip))))]
        ['agents' [%a (turn (sort (read-names agents-view) aor) |=(n=@ta `json`s+n))]]
        :-  'apis'
        :-  %a
        %+  turn  (read-entities apis-view)
        |=([n=@ta t=@ta] (pairs:enjs:format ~[['name' s+n] ['type' s+t]]))
        :-  'channels'
        :-  %a
        %+  turn  (read-entities chans-view)
        |=([n=@ta t=@ta] (pairs:enjs:format ~[['name' s+n] ['type' s+t]]))
        ['assistants' [%a (flop out)]]
    ==
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  ;<  ~  bind:m
    (send-simple:(srv rail) eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  (pure:m ~)
--
