::  read-logs: read dill system logs (slogs, errors, etc.)
::
::  Reads the current or historical state of the dill logs grub.
::  This captures ~& printfs, stack traces, and system messages.
::
::  Parameters:
::    version:  specific version number to read (optional)
::    from:     start version for range query (optional)
::    to:       end version for range query (optional)
::
!:
^-  tool:tools
|%
++  name  'read_logs'
++  description
  'Read system logs (slogs, errors, debug output). Returns current logs or historical versions.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['version' [%number 'Specific version number to read']]
      ['from' [%number 'Start of version range (inclusive)']]
      ['to' [%number 'End of version range (inclusive)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  args=json  [%o args.st]
  =/  ver=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /version)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  from=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /from)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  to=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /to)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  logs-road=road:tarball
    [%& %& /sys/dill %'logs.dill-told']
  ::  Specific version
  ?^  ver
    ;<  =seen:nexus  bind:m
      (peek-at:io /read logs-road ~ [%ud u.ver])
    ?.  ?=([%& %file *] seen)
      (pure:m [%error 'Logs not found or version does not exist'])
    =/  =told:dill  !<(told:dill q.cage.p.seen)
    (pure:m [%text (crip (format-told:tools told))])
  ::  Range query
  ?:  |(?=(^ from) ?=(^ to))
    ;<  res=(each (list [=cass:clay =cage]) tang)  bind:m
      (peep:io /hist logs-road [%numb from to])
    ?:  ?=(%| -.res)
      (pure:m [%error (crip (zing (turn (flop p.res) |=(=tank (weld ~(ram re tank) "\0a")))))])
    ?~  p.res
      (pure:m [%text 'No log versions found in range'])
    =/  out=tape  ""
    =/  entries=(list [=cass:clay =cage])  p.res
    |-
    ?~  entries
      (pure:m [%text (crip out)])
    =/  =told:dill  !<(told:dill q.cage.i.entries)
    %=  $
      entries  t.entries
      out  (weld out "--- Log {<ud.cass.i.entries>} ---\0a{(format-told:tools told)}\0a")
    ==
  ::  Current state
  ;<  =seen:nexus  bind:m
    (peek:io /read logs-road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error 'Logs grub not found'])
  =/  =told:dill  !<(told:dill q.cage.p.seen)
  (pure:m [%text (crip (format-told:tools told))])
--
