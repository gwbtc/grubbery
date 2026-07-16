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
      [%fall %& [/ %'db.obelisk_server'] [[/ %sig] ~]]
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
    |-
    ;<  =sage:tarball  bind:m  take-poke:io
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
    =/  [results=(list cmd-result:obelisk-ast) new-state=db-state]
      (exec:obelisk state now our db script)
    =/  state-road=road:tarball
      (nex-road:io rail [%& ~ %'db.obelisk_server'])
    ;<  ~  bind:m  (put:io state-road [[/ %'obelisk_server'] new-state])
    =/  result-json=json
      %-  pairs:enjs:format
      :~  results+(results-to-json results)
      ==
    =/  result-road=road:tarball
      (nex-road:io rail [%& ~ %'result.json'])
    ;<  ~  bind:m  (over:io result-road [[/ %json] result-json])
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
