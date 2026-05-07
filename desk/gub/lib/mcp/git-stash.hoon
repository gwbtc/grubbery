/<  tools  /lib/nex/tools.hoon
::  git-stash: stash dirty index and reset to HEAD
::
!:
^-  tool:tools
|%
++  name  'git-stash'
++  description
  'Stash the current staged changes in a git/repo nexus and reset the working tree to HEAD. Does nothing if tree is clean.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/git.git_repo")']]
  ==
++  required  ~['path']
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
  ?:  =('' nex-path)  (pure:m [%error 'Missing required argument: path'])
  =/  pax-parsed=(each path @t)  (parse-path:tools nex-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  rd=road:tarball  [%& %& [(weld pax /actions) %'stash.sig']]
  ;<  ~  bind:m  (poke:io rd [[/ %sig] !>(~)])
  (pure:m [%text 'Stash requested'])
--
