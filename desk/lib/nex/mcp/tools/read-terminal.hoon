::  read-terminal: read rendered dill terminal output
::
::  Reads historical blit batches from a dill session and renders
::  them through a VT100 terminal simulator. Each version in the
::  session grub's history is one blit batch from dill.
::
::  Parameters:
::    session:  session name (default: "" for default session)
::    width:    terminal width for rendering (default: 80)
::    last:     number of recent versions to render (default: 100)
::    from:     start version for range query (optional)
::    to:       end version for range query (optional)
::
!:
^-  tool:tools
|%
++  name  'read_terminal'
++  description
  'Read rendered terminal output from a dill session. Replays blit history through a terminal renderer.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  ^-  (list [@t parameter-def:tools])
  :~  ['session' [%string 'Session name (default: empty for default session)']]
      ['width' [%number 'Terminal width for rendering (default: 80)']]
      ['last' [%number 'Number of recent blit batches to replay (default: 100)']]
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
  =/  session=@ta
    =/  ses=@t  (~(dug jo:json-utils args) /session so:dejs:format '')
    (crip (trip ses))
  =/  wid=@ud
    (~(dug jo:json-utils args) /width ni:dejs:format 80)
  =/  last=@ud
    (~(dug jo:json-utils args) /last ni:dejs:format 100)
  =/  from=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /from)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  to=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /to)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  ses-road=road:tarball
    [%& %& /sys/dill/sessions session]
  ::  Get current version to compute range
  ;<  =seen:nexus  bind:m
    (peek:io /cur ses-road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error 'Session not found'])
  =/  cur-ver=@ud  ud.file.sack.p.seen
  ::  Determine version range
  =/  range-from=@ud
    ?^  from  u.from
    ?:  (lth cur-ver last)  1
    +((sub cur-ver last))
  =/  range-to=@ud
    (fall to cur-ver)
  ::  Fetch all versions in range via peep
  ;<  res=(each (list [=cass:clay =cage]) tang)  bind:m
    (peep:io /hist ses-road [%numb `range-from `range-to])
  ?:  ?=(%| -.res)
    (pure:m [%error (crip (zing (turn (flop p.res) |=(=tank (weld ~(ram re tank) "\0a")))))])
  ?~  p.res
    (pure:m [%text 'No terminal history found'])
  ::  Flatten all blit batches and render
  =/  all-blits=(list blit:dill)
    %-  zing
    %+  turn  p.res
    |=  [=cass:clay =cage]
    !<((list blit:dill) q.cage)
  =/  rendered=@t  (render-blits:clurd all-blits wid)
  (pure:m [%text (crip "Terminal ({<session>}, versions {<range-from>}-{<range-to>} of {<cur-ver>}):\0a{(trip rendered)}")])
--
