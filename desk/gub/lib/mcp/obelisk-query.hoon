/<  tools  /lib/nex/tools.hoon
/<  obelisk  /lib/obelisk.hoon
/<  obelisk-ast  /lib/obelisk-ast.hoon
/<  server-state  /lib/server-state.hoon
=,  server-state
=,  obelisk-ast
^-  tool:tools
|%
++  name  'obelisk_query'
++  description
  ^~  %-  crip
  ;:  weld
    "Run a SQL query against the obelisk SQL engine. "
    "Supports CREATE DATABASE, CREATE TABLE, INSERT, "
    "SELECT, UPDATE, DELETE, etc."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['database' [%string 'Database name (default: db)']]
      ['query' [%string 'SQL query to execute']]
  ==
++  required  ~['query']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  db-name=@tas
    =/  v  (~(get by args.st) 'database')
    ?~(v %db ?.(?=([%s *] u.v) %db (crip (trip p.u.v))))
  =/  query=tape
    =/  v  (~(get by args.st) 'query')
    ?~(v ~ ?.(?=([%s *] u.v) ~ (trip p.u.v)))
  ?~  query
    (pure:m [%error 'Missing required argument: query'])
  ;<  now=@da  bind:m  get-time:io
  ;<  our=@p  bind:m  get-our:io
  =/  state-road=road:tarball  [%| 1 %& ~ %'obelisk.obelisk_server']
  ;<  =view:nexus  bind:m  (peek:io state-road ~)
  =/  state=db-state
    ?.  ?=([%file *] view)  *db-state
    !<(db-state (need-vase:tarball sang.view))
  =/  outcome=(each [(list cmd-result) db-state] tang)
    (mule |.((exec:obelisk state now our db-name query)))
  ?:  ?=(%| -.outcome)
    =/  err=tape
      %+  roll  p.outcome
      |=  [t=tank acc=tape]
      (weld acc (weld (of-wall:format (~(win re t) 0 80)) "\0a"))
    (pure:m [%error (crip err)])
  =/  [results=(list cmd-result) new-state=db-state]  p.outcome
  ;<  ~  bind:m  (put:io state-road [[/ %noun] new-state])
  =/  out=tape
    %+  roll  results
    |=  [r=cmd-result acc=tape]
    %+  weld  acc
    %+  roll  +.r
    |=  [res=result acc=tape]
    %+  weld  acc
    ?-  -.res
      %action         "{(trip action.res)}\0a"
      %message        "{(trip msg.res)}\0a"
      %relation       "relation: {(trip relation.res)}\0a"
      %vector-count   "count: {<count.res>}\0a"
      %server-time    "server-time: {(trip (scot %da date.res))}\0a"
      %schema-time    "schema-time: {(trip (scot %da date.res))}\0a"
      %data-time      "data-time: {(trip (scot %da date.res))}\0a"
      %security-time  "security-time: {(trip (scot %da date.res))}\0a"
      %result-set
        %+  roll  +.res
        |=  [v=vector inner=tape]
        %+  weld  inner
        %+  weld
          %+  roll  `(list vector-cell)`+.v
          |=  [vc=vector-cell row=tape]
          %+  weld  row
          "{(trip p.vc)}: {(trip (crip (scow p.q.vc q.q.vc)))}  "
        "\0a"
    ==
  (pure:m [%text (crip ?~(out "(no results)" out))])
--
