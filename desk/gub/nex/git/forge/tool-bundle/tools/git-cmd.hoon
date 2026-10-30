/<  tools  /lib/tools.hoon
::  git_cmd: run a git command through a repo's serial command queue.
::
!:
^-  tool:tools
|%
++  name  'git_cmd'
++  description
  ^~  %-  crip
  ;:  weld
    "Run a git command through a git/repo nexus's serial command queue "
    "(/run.git-action), which parses it and runs it one at a time. Examples: "
    "'commit -m \"msg\"', 'add', 'add lib/foo.hoon', 'stash', 'stash pop', "
    "'branch dev', 'branch -d dev', 'checkout main', 'push', 'pull'. "
    "A directory path stages everything beneath it; plain 'add' stages "
    "the whole tree. Returns the command's REAL outcome, waiting for it "
    "to finish; the queue's history is at /run.git-action."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Path to git/repo nexus (e.g. "@forge/repos/contacts.git_repo")']]
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
  =/  run-rd=road:tarball  [%& %& [pax %'run.git-action']]
  ::  `reply` asks the queue to poke us back when the command has actually
  ::  finished. +poke:io already waits -- but only for the %pack, which
  ::  means the queue CONSUMED the command, not that it ran. Reporting
  ::  that as `ran:` was the whole problem: accepted is not done.
  =/  req=json
    %-  pairs:enjs:format
    :~  ['command' s+command]
        ['reply' b+%.y]
    ==
  ;<  ~  bind:m  (poke:io run-rd [[/ %json] req])
  ::  now wait for the answer. A command that takes longer than this is
  ::  still running, not failed, and the queue's own log is where it
  ::  lands -- so say so rather than claiming either outcome.
  ::  +with-timeout takes THREE arguments -- [wire time computation] --
  ::  so it is applied with parens, not %+. Under-applying it left the
  ::  take unarmed, the queue's reply landed on a fiber with no handler
  ::  ("inert: no handler for input", banging it), and this tool sat here
  ::  until its own timeout.
  =/  waiting
    =/  m  (fiber:fiber:nexus ,sage:tarball)
    ^-  form:m
    ;<  [* =sage:tarball]  bind:m  take-poke-from:io
    (pure:m sage)
  ;<  rep=(unit sage:tarball)  bind:m
    ((with-timeout:io sage:tarball) /git-cmd ~m5 waiting)
  ?~  rep
    %-  pure:m
    :-  %text
    (cat 3 'still running: read /run.git-action for the outcome — ' command)
  =/  jon=json  (fall (mole |.(!<(json q.u.rep))) *json)
  =/  obj=(map @t json)  ?:(?=(%o -.jon) p.jon ~)
  =/  msg=@t
    =/  m  (~(get by obj) 'message')
    ?.(?=([~ %s *] m) '(no message)' p.u.m)
  =/  ok=?
    =/  b  (~(get by obj) 'ok')
    ?=([~ %b %.y] b)
  ?.  ok  (pure:m [%error msg])
  (pure:m [%text msg])
--
