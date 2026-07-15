/<  tools  /lib/nex/tools.hoon
::  create-desk: create a git_desk or desk syncer in /apps/
::
!:
^-  tool:tools
|%
++  name  'create_desk'
++  description
  ^~  %-  crip
  ;:  weld
    "Create a new desk syncer in /apps/. "
    "Type 'git' clones from a public GitHub repo. "
    "Type 'desk' syncs from a remote ship or local path. "
    "For git: provide repo (owner/repo), optional ref (default main), optional poll (minutes, 0=off). "
    "For desk: provide source (~ship/path or /local/path)."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'App name (e.g. "myapp") — becomes /apps/myapp.git_desk or /apps/myapp.desk']]
      ['type' [%string '"git" for GitHub repo, "desk" for remote/local sync']]
      ['repo' [%string '(git only) GitHub owner/repo (e.g. "niblyx-malnus/lick-test-nexus")']]
      ['ref' [%string '(git only) Branch or tag, default "main"']]
      ['poll' [%number '(git only) Polling interval in minutes, 0=off']]
      ['source' [%string '(desk only) Source path (e.g. "~nec/apps/counter" or "/local/path")']]
      ['public' [%boolean 'Whether the desk code namespace is publicly readable (default false)']]
  ==
++  required  ~['name' 'type']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  nam=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  typ=(unit @t)  (~(deg jo:json-utils [%o args.st]) /type so:dejs:format)
  ?~  nam  (pure:m [%error 'Missing required argument: name'])
  ?~  typ  (pure:m [%error 'Missing required argument: type'])
  =/  is-git=?  =(u.typ 'git')
  ?.  |(is-git =(u.typ 'desk'))
    (pure:m [%error 'type must be "git" or "desk"'])
  =/  app-name=@ta  u.nam
  =/  suffix=@ta  ?:(is-git %'git_desk' %desk)
  =/  dir-name=@ta  (cat 3 app-name (cat 3 '.' suffix))
  =/  dir-path=path  /apps/[dir-name]
  =/  app-weir=(unit weir:nexus)
    `[make=~ poke=(sy ~[[%& %| /]]) peek=(sy ~[[%& %| /]])]
  =/  neck=rail:tarball
    ?:  is-git  [/git %desk]
    [/ %desk]
  =/  =bole:tarball  [`[`neck app-weir %.n ~] ~]
  ;<  exists=?  bind:m  (peek-exists:io [%& %| dir-path])
  ?:  exists
    (pure:m [%error (crip "{(trip dir-name)} already exists")])
  ;<  ~  bind:m  (make:io [%& %| dir-path] &+bole)
  ?:  is-git
    =/  repo=(unit @t)  (~(deg jo:json-utils [%o args.st]) /repo so:dejs:format)
    =/  ref=@t
      (fall (~(deg jo:json-utils [%o args.st]) /ref so:dejs:format) 'main')
    =/  poll=@ud
      =/  p  (~(get jo:json-utils [%o args.st]) /poll)
      ?~  p  0
      ?.  ?=([%n *] u.p)  0
      (fall (rush p.u.p dem) 0)
    =/  pub=?
      =/  p  (~(get jo:json-utils [%o args.st]) /public)
      ?:(?=([~ %b %&] p) %.y %.n)
    =/  config=json
      %-  pairs:enjs:format
      :~  ['repo' s+(fall repo '')]
          ['ref' s+ref]
          ['public' b+pub]
          ['poll' (numb:enjs:format poll)]
      ==
    ;<  ~  bind:m  (poke:io [%& %& dir-path %'config.json'] [[/ %json] config])
    ?~  repo
      (pure:m [%text (crip "Created {(trip dir-name)} — configure repo to sync")])
    ;<  ~  bind:m  (poke:io [%& %& dir-path %'sync.sig'] [[/ %sig] ~])
    (pure:m [%text (crip "Created {(trip dir-name)} syncing {(trip u.repo)}")])
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
