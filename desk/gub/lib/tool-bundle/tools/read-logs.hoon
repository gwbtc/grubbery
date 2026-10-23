/<  tools  /lib/tools.hoon
::  read-logs: the ship's slog stream (printfs, ~&, crashes) from the
::  namespace. Grubbery subscribes to dill's %logs and writes every $told
::  to /sys/dill/logs.dill-told, history kept; this peeps the last N
::  versions and renders them. read_terminal shows the session's blits
::  (the prompt, drum's output), never slogs; this is the other half.
::
!:
^-  tool:tools
|%
++  name  'read_logs'
++  description
  '''
  Read the ship's recent slog output (printfs, ~& traces, crash reports)
  from /sys/dill/logs.dill-told. last: how many recent log entries to
  show (default 50). Optional grep: only entries containing this text.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['last' [%number 'how many recent entries (default 50)']]
      ['grep' [%string 'only entries containing this text']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  args=json  [%o args.st]
  =/  last=@ud  (~(dug jo:json-utils args) /last ni:dejs:format 50)
  =/  pat=(unit @t)
    =/  v=(unit json)  (~(get jo:json-utils args) /grep)
    ?.  ?=([~ %s *] v)  ~
    ?:(=('' p.u.v) ~ `p.u.v)
  =/  road=road:tarball  [%& %& /sys/dill %'logs.dill-told']
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] view)  (pure:m [%error 'no /sys/dill/logs.dill-told'])
  =/  cur=@ud  ud.cass.view
  =/  from=@ud  ?:((lth cur last) 1 +((sub cur last)))
  ;<  res=(each (list [=cass:clay =sage:tarball]) tang)  bind:m
    (peep:io road [%numb `from `cur])
  ?:  ?=(%| -.res)
    (pure:m [%error (crip (zing (turn (flop p.res) |=(=tank (weld ~(ram re tank) "\0a")))))])
  =/  lines=(list tape)
    %+  murn  p.res
    |=  [=cass:clay =sage:tarball]
    ^-  (unit tape)
    =/  told=(unit told:dill)  (mole |.(!<(told:dill q.sage)))
    ?~  told  ~
    =/  t=tape  (format-told:tools u.told)
    ?:  &(?=(^ pat) ?=(~ (find (trip u.pat) t)))  ~
    `"[{(a-co:co ud.cass)}] {t}"
  ?~  lines  (pure:m [%text (crip "no log entries in versions {(a-co:co from)}-{(a-co:co cur)}")])
  (pure:m [%text (crip "logs ({(a-co:co from)}-{(a-co:co cur)} of {(a-co:co cur)}):\0a{(zing lines)}")])
--
