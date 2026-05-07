/<  tools  /lib/nex/tools.hoon
::  git-switch: switch to a different branch in a git/repo nexus
::
!:
^-  tool:tools
|%
++  name  'git-switch'
++  description
  'Switch to a different branch in a git/repo nexus. Pokes switch.sig with the branch name. Will fail if working tree is dirty.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/git.git_repo")']]
      ['branch' [%string 'Branch name to switch to']]
  ==
++  required  ~['path' 'branch']
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
  =/  branch=@t    (get-str 'branch' '')
  ?:  =('' nex-path)  (pure:m [%error 'Missing required argument: path'])
  ?:  =('' branch)    (pure:m [%error 'Missing required argument: branch'])
  =/  pax-parsed=(each path @t)  (parse-path:tools nex-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  rd=road:tarball  [%& %& [(weld pax /actions) %'switch.sig']]
  =/  msg-wain=wain  (to-wain:format branch)
  ;<  ~  bind:m  (poke:io rd [[/ %txt] !>(msg-wain)])
  (pure:m [%text (cat 3 'Switched to branch: ' branch)])
--
