/<  tools  /lib/nex/tools.hoon
::  git-branch: create a new branch at HEAD
::
!:
^-  tool:tools
|%
++  name  'git-branch'
++  description
  'Create a new branch at the current HEAD in a git/repo nexus. Pokes branch.sig with the branch name.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/git.git_repo")']]
      ['name' [%string 'Branch name to create']]
  ==
++  required  ~['path' 'name']
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
  =/  branch=@t    (get-str 'name' '')
  ?:  =('' nex-path)  (pure:m [%error 'Missing required argument: path'])
  ?:  =('' branch)    (pure:m [%error 'Missing required argument: name'])
  =/  pax-parsed=(each path @t)  (parse-path:tools nex-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  rd=road:tarball  [%& %& [(weld pax /actions) %'branch.sig']]
  =/  msg-wain=wain  (to-wain:format branch)
  ;<  ~  bind:m  (poke:io rd [[/ %txt] msg-wain])
  (pure:m [%text (cat 3 'Branch created: ' branch)])
--
