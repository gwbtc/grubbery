/<  tools  /lib/nex/tools.hoon
::  git_cmd: run a git command through a repo's serial command lane.
::
!:
^-  tool:tools
|%
++  name  'git_cmd'
++  description
  ^~  %-  crip
  ;:  weld
    "Run a git command through a git/repo nexus's serial command lane "
    "(/actions/run), which parses it and runs it one at a time. Examples: "
    "'commit -m \"msg\"', 'add', 'add lib/foo.hoon', 'stash', 'stash pop', "
    "'branch dev', 'branch -d dev', 'checkout main', 'push', 'pull'. "
    "Read the lane grub (/actions/run) for the outcome log."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/apps/forge.git_forge/repos/contacts.git_repo")']]
      ['command' [%string 'Git command, e.g. commit -m "msg"']]
  ==
++  required  ~['path' 'command']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  get-str
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by args.st) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  =/  nex-path=@t  (get-str 'path' '')
  =/  command=@t   (get-str 'command' '')
  ?:  =('' nex-path)  (pure:m [%error 'Missing required argument: path'])
  ?:  =('' command)   (pure:m [%error 'Missing required argument: command'])
  =/  pax-parsed=(each path @t)  (parse-path:tools nex-path)
  ?:  ?=(%| -.pax-parsed)  (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  run-rd=road:tarball  [%& %& [(weld pax /actions) %'run']]
  =/  req=json  (pairs:enjs:format ~[['command' s+command]])
  ;<  ~  bind:m  (poke:io run-rd [[/ %json] req])
  (pure:m [%text (cat 3 'ran: ' command)])
--
