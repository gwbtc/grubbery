/<  tools  /lib/nex/tools.hoon
::  git-push: push local commits to GitHub via the repo nexus
::
!:
^-  tool:tools
|%
++  name  'git-push'
++  description
  'Push local git commits to GitHub. Pokes push.sig on the git/repo nexus. Optionally pass branch to push the local HEAD to that remote branch instead (git push origin HEAD:branch); the branch is created on GitHub if it does not exist.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/git.git_repo")']]
      ['branch' [%string 'Target remote branch. Omit to push the current branch.']]
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
  =/  =road:tarball  [%& %& [(weld pax /actions) %'push.sig']]
  =/  branch=@t  (get-str 'branch' '')
  ;<  ~  bind:m
    ?:  =('' branch)  (poke:io road [[/ %sig] ~])
    (poke:io road [[/ %json] (pairs:enjs:format ~[['branch' s+branch]])])
  %-  pure:m
  :-  %text
  ?:(=('' branch) 'Push triggered.' (crip "Push to {(trip branch)} triggered."))
--
