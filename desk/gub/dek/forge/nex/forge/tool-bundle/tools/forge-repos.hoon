/<  tools  /lib/tools.hoon
::  forge_repos: the repos forge follows, with each one's remote, ref
::  and tip. A registry read, not a namespace walk.
::
!:
=<  ^-  tool:tools
    |%
++  name  'forge_repos'
++  description
  '''
  List the repos forge follows: name, remote, checked-out ref and the
  tip commit. The name is what forge_log and git_cmd's path refer to;
  the repo nexus lives at <forge>/repos/<name>.git_repo.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  *(map @t parameter-def:tools)
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  fb=(unit lane:tarball)  bind:m  (resolve-link:io '@forge')
  ?.  ?=([~ %| *] fb)  (pure:m [%error 'forge is not in /sys/link'])
  =/  base=path  p.u.fb
  ;<  v=view:nexus  bind:m  (peek-shallow:io [%& %| (weld base /repos)] ~)
  ?.  ?=([%ball *] v)  (pure:m [%text 'forge follows no repos.'])
  =/  kids=(list @ta)  (sort ~(tap in ~(key by dir.ball.v)) aor)
  =/  names=(list @ta)  (murn kids repo-name)
  =|  out=(list tape)
  |-
  ?~  names
    ?~  out  (pure:m [%text 'forge follows no repos.'])
    (pure:m [%text (crip (zing (flop out)))])
  =/  dir=@ta  (cat 3 i.names '.git_repo')
  ;<  cfg=(unit json)  bind:m  (json-at (weld base /repos/[dir]) %'config.json')
  ;<  cur=(unit json)  bind:m  (json-at (weld base /repos/[dir]/data/ui) %'current.json')
  =/  remote=@t  (str (fall cfg [%o ~]) 'repo')
  =/  ref=@t  (str (fall cfg [%o ~]) 'ref')
  =/  tip=@t  (crip (scag 7 (trip (str (fall cur [%o ~]) 'hash'))))
  =/  line=tape
    ;:  weld
      (trip i.names)
      ?:(=('' remote) "" "  {(trip remote)}")
      ?:(=('' ref) "" "  {(trip ref)}")
      ?:(=('' tip) "" "  @{(trip tip)}")
      "\0a"
    ==
  $(names t.names, out [line out])
--
|%
::  "<name>.git_repo" -> name; anything else is not a repo
++  repo-name
  |=  n=@ta
  ^-  (unit @ta)
  =/  t=tape  (trip n)
  =/  suf=tape  ".git_repo"
  =/  len=@ud  (lent t)
  ?.  (gth len (lent suf))  ~
  ?.  =(suf (slag (sub len (lent suf)) t))  ~
  `(crip (scag (sub len (lent suf)) t))
::
++  json-at
  |=  [dir=path name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io [%& %& dir name] `[/ %json])
  ?.  ?=([%file *] v)  (pure:m ~)
  ?:  (is-boom:tarball sang.v)  (pure:m ~)
  (pure:m (mole |.(!<(json (need-vase:tarball sang.v)))))
::
++  str
  |=  [c=json key=@t]
  ^-  @t
  ?.  ?=([%o *] c)  ''
  =/  r  (~(get by p.c) key)
  ?:(?=([~ %s *] r) p.u.r '')
--
