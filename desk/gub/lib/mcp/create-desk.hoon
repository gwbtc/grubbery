/<  tools  /lib/tools.hoon
::  create-desk: create a source /desk syncer in /apps/. It subscribes to
::  a code dir already in the namespace (a git_repo's checked-out tree, a
::  remote ship path, or a local path) and deploys it. The git_desk type
::  is retired — clone-from-github is a /git/repo now, and a /desk consumes
::  its tree.
::
!:
^-  tool:tools
|%
++  name  'create_desk'
++  description
  ^~  %-  crip
  ;:  weld
    "Create a new /desk syncer in /apps/. It syncs from a source code dir "
    "already in the namespace and deploys it. Provide source (~ship/path "
    "or /local/path — e.g. a git_repo's /data/tree/code)."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'App name (e.g. "myapp") — becomes /apps/myapp.desk']]
      ['source' [%string 'Source path (e.g. "~nec/apps/counter" or "/local/path")']]
      ['public' [%boolean 'Whether the desk code namespace is publicly readable (default false)']]
  ==
++  required  ~['name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  nam=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  ?~  nam  (pure:m [%error 'Missing required argument: name'])
  =/  app-name=@ta  u.nam
  =/  dir-name=@ta  (cat 3 app-name '.desk')
  =/  dir-path=path  /apps/[dir-name]
  =/  app-weir=(unit weir:nexus)
    `[make=~ poke=(sy ~[[%& %| /]]) peek=(sy ~[[%& %| /]])]
  =/  =bole:tarball  [`[`[/ %desk] app-weir %.n ~] ~]
  ;<  exists=?  bind:m  (peek-exists:io [%& %| dir-path])
  ?:  exists
    (pure:m [%error (crip "{(trip dir-name)} already exists")])
  ;<  ~  bind:m  (make:io [%& %| dir-path] &+bole)
  =/  source=(unit @t)  (~(deg jo:json-utils [%o args.st]) /source so:dejs:format)
  =/  pub=?
    =/  p  (~(get jo:json-utils [%o args.st]) /public)
    ?:(?=([~ %b %&] p) %.y %.n)
  =/  config=json
    %-  pairs:enjs:format
    :~  ['source' ?~(source ~ s+u.source)]
        ['public' b+pub]
    ==
  ;<  ~  bind:m  (poke:io [%& %& dir-path %'config.json'] [[/ %json] config])
  =/  msg=tape
    ?~  source  "Created {(trip dir-name)}"
    "Created {(trip dir-name)} syncing {(trip u.source)}"
  (pure:m [%text (crip msg)])
--
