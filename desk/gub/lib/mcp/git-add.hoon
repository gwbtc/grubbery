/<  tools  /lib/nex/tools.hoon
::  git-add: stage files in a git/repo nexus
::
!:
^-  tool:tools
|%
++  name  'git-add'
++  description
  'Stage files in a git/repo nexus. Pokes add.sig. Use paths for selective staging, or omit for add-all.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "/git.git_repo")']]
      ['paths' [%string 'JSON array of file paths to stage (omit for all)']]
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
  ::  build add request json
  =/  paths-str=@t  (get-str 'paths' '')
  =/  req=json
    ?:  =('' paths-str)
      (pairs:enjs:format ~[['all' b+%.y]])
    =/  parsed=(unit json)  (de:json:html paths-str)
    ?~  parsed  (pairs:enjs:format ~[['all' b+%.y]])
    ?.  ?=(%a -.u.parsed)  (pairs:enjs:format ~[['all' b+%.y]])
    (pairs:enjs:format ~[['all' b+%.n] ['paths' u.parsed]])
  =/  =road:tarball  [%& %& [(weld pax /actions) %'add.sig']]
  ;<  ~  bind:m  (poke:io road [[/ %json] !>(req)])
  (pure:m [%text 'Files staged.'])
--
