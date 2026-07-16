/<  obelisk-ast  /lib/obelisk-ast.hoon
/<  server-state  /lib/server-state.hoon
/<  obelisk  /lib/obelisk.hoon
=,  obelisk-ast
=,  server-state
=<  ^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'db.obelisk_server'] [[/obelisk %server] *db-state]]
  ==
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      [~ %'db.obelisk_server']
    ;<  ~  bind:m  (rise-wait:io prod "%obelisk: failed")
    ~&  >  "%obelisk: ready"
    |-
    ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
    ?.  =(%json name.p.sage)
      ~&  >  [%obelisk %unknown-mark name.p.sage]
      $
    =/  jon=json  !<(json q.sage)
    ?.  ?=([%o *] jon)  $
    =/  db=@tas
      =/  v  (~(get by p.jon) 'database')
      ?~(v %db ?.(?=([%s *] u.v) %db (crip (trip p.u.v))))
    =/  script=tape
      =/  v  (~(get by p.jon) 'query')
      ?~(v ~ ?.(?=([%s *] u.v) ~ (trip p.u.v)))
    ?~  script  $
    ;<  now=@da   bind:m  get-time:io
    ;<  our=@p    bind:m  get-our:io
    ;<  state=db-state  bind:m  (get-state-as:io ,db-state)
    =/  outcome=(each [(list cmd-result) db-state] tang)
      (mule |.((exec:obelisk state now our db script)))
    =/  result-json=json
      ?:  ?=(%| -.outcome)
        %-  pairs:enjs:format
        :~  :-  'error'
            :-  %s
            %-  crip
            %+  roll  p.outcome
            |=  [t=tank acc=tape]
            (weld acc (weld (of-wall:format (~(win re t) 0 80)) "\0a"))
        ==
      %-  pairs:enjs:format
      :~  results+(results-to-json -.p.outcome)
      ==
    =/  new-state=db-state
      ?:(?=(%| -.outcome) state +.p.outcome)
    ;<  ~  bind:m  (replace:io new-state)
    ::  TODO: get rid of prov in from — always reply via bend
    ?:  ?=(%& -.from)
      =/  reply-road=road:tarball  [%| p.p.from %& q.p.from]
      ;<  ~  bind:m
        (send-dart:io [%node /reply reply-road [%poke [[/ %json] result-json]]])
      $
    $
  ==
--
|%
++  results-to-json
  |=  results=(list cmd-result:obelisk-ast)
  ^-  json
  :-  %a
  %+  turn  results
  |=  =cmd-result:obelisk-ast
  %-  pairs:enjs:format
  %+  turn  +.cmd-result
  |=  =result:obelisk-ast
  ^-  [@t json]
  ?-  -.result
    %action        ['action' s+action.result]
    %relation      ['relation' s+relation.result]
    %message       ['message' s+msg.result]
    %vector-count  ['vector-count' (numb:enjs:format count.result)]
    %server-time   ['server-time' s+(scot %da date.result)]
    %security-time  ['security-time' s+(scot %da date.result)]
    %schema-time   ['schema-time' s+(scot %da date.result)]
    %data-time     ['data-time' s+(scot %da date.result)]
    %result-set
      :-  'result-set'
      :-  %a
      %+  turn  +.result
      |=  =vector:obelisk-ast
      %-  pairs:enjs:format
      %+  turn  +.vector
      |=  =vector-cell:obelisk-ast
      ^-  [@t json]
      [p.vector-cell s+(crip (scow p.q.vector-cell q.q.vector-cell))]
  ==
--
