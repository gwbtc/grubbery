/<  tools  /lib/tools.hoon
::  forge-create-repo: create a git repo in forge, optionally clone from remote
::
!:
^-  tool:tools
|%
++  name  'forge_create_repo'
++  description
  ^~  %-  crip
  ;:  weld
    "Create a git repo in forge. Optionally provide a remote URL "
    "to clone from (triggers an initial pull). The repo appears at "
    "/apps/forge.git_forge/repos/<name>.git_repo with a checked-out "
    "working tree at /data/tree/."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'Repo name (e.g. "ahoy")']]
      ['remote' [%string 'Remote repo URL to clone from (e.g. "https://github.com/user/repo") — optional']]
      ['ref' [%string 'Branch to check out (default "main") — optional']]
  ==
++  required  ~['name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  get-str
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by args.st) key)
    ?~  v  default
    ?.(?=([%s *] u.v) default p.u.v)
  =/  repo-name=@t  (get-str 'name' '')
  ?:  =('' repo-name)
    (pure:m [%error 'name is required'])
  =/  remote=@t  (get-str 'remote' '')
  =/  ref=@t  (get-str 'ref' 'main')
  =/  dir-name=@ta  (cat 3 repo-name '.git_repo')
  =/  forge-base=path  /apps/'forge.git_forge'
  =/  repo-path=path  (weld forge-base /repos/[dir-name])
  ;<  =view:nexus  bind:m  (peek:io [%& %| repo-path] ~)
  ?:  ?=([%ball *] view)
    (pure:m [%error (crip "repo '{(trip repo-name)}' already exists")])
  ;<  ~  bind:m
    (make:io [%& %| repo-path] &+`bole:tarball`[`[`[/git %repo] ~ %.n ~] ~])
  ;<  ~  bind:m  (gain:io [%& %| repo-path] %.y)
  =/  config=json
    %-  pairs:enjs:format
    :~  ['repo' s+remote]
        ['ref' s+ref]
        ['account' s+'']
        ['author_name' s+'']
        ['author_email' s+'']
    ==
  ;<  ~  bind:m
    (over:io [%& %& [(weld forge-base /repos/[dir-name]) %'config.json']] [[/ %json] config])
  ?:  =('' remote)
    (pure:m [%text (crip "Created empty repo '{(trip repo-name)}' at {(spud repo-path)}")])
  ;<  ~  bind:m
    %+  poke:io  [%& %& [(weld forge-base /repos/[dir-name]) %'run.git-action']]
    [[/ %json] (pairs:enjs:format ~[['command' s+'pull']])]
  (pure:m [%text (crip "Created repo '{(trip repo-name)}' and pulling from {(trip remote)} ({(trip ref)}). Check {(spud repo-path)}/data/tree/ for the working tree.")])
--
