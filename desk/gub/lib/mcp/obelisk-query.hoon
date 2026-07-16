/<  tools  /lib/nex/tools.hoon
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
  =/  db-name=@t
    =/  v  (~(get by args.st) 'database')
    ?~(v 'db' ?.(?=([%s *] u.v) 'db' p.u.v))
  =/  query=@t
    =/  v  (~(get by args.st) 'query')
    ?~(v '' ?.(?=([%s *] u.v) '' p.u.v))
  ?:  =('' query)
    (pure:m [%error 'Missing required argument: query'])
  =/  poke-json=json
    %-  pairs:enjs:format
    :~  ['database' s+db-name]
        ['query' s+query]
    ==
  =/  db-road=road:tarball
    [%& %& /apps/'obelisk.obelisk_app' %'db.obelisk_server']
  ;<  ~  bind:m  (poke:io db-road [[/ %json] poke-json])
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  result-json=json  !<(json q.sage)
  (pure:m [%text (en:json:html result-json)])
--
