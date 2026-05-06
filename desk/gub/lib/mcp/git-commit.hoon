/<  tools  /lib/nex/tools.hoon
::  git-commit: create a local git commit in a git/repo nexus
::
!:
^-  tool:tools
|%
++  name  'git-commit'
++  description
  'Create a local git commit from the current tree state in a git/repo nexus. Pokes commit.sig with the message.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/git.git_repo")']]
      ['message' [%string 'Commit message']]
  ==
++  required  ~['path' 'message']
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
  =/  message=@t   (get-str 'message' '')
  ?:  =('' nex-path)  (pure:m [%error 'Missing required argument: path'])
  ?:  =('' message)   (pure:m [%error 'Missing required argument: message'])
  ::  parse nexus path
  =/  pax-parsed=(each path @t)  (parse-path:tools nex-path)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  ::  stage all files first (git add -A)
  =/  add-rd=road:tarball  [%& %& [(weld pax /actions) %'add.sig']]
  =/  add-req=json  (pairs:enjs:format ~[['all' b+%.y]])
  ;<  ~  bind:m  (poke:io add-rd [[/ %json] !>(add-req)])
  ::  then commit from index
  =/  commit-rd=road:tarball  [%& %& [(weld pax /actions) %'commit.sig']]
  =/  msg-wain=wain  (to-wain:format message)
  ;<  ~  bind:m  (poke:io commit-rd [[/ %txt] !>(msg-wain)])
  (pure:m [%text (cat 3 'Commit triggered: ' message)])
--
