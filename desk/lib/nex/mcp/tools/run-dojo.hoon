::  run-dojo: execute a dojo command and return the output
::
::  Sends belt input to a dill session, waits for the prompt
::  to reappear, then reads and renders the terminal output
::  interleaved with system logs.  Survives reboots via
::  state machine checkpointing.
::
::  Parameters:
::    command:  the dojo command to execute
::    session:  session name (default: "" for default session)
::    width:    terminal width for rendering (default: 80)
::    timeout:  max seconds to wait for output (default: 30)
::    delay:    seconds to wait after prompt before reading (default: 2)
::
!:
^-  tool:tools
=>
|%
++  read-results
  |=  st=tool-state:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  =/  pre-ver=@ud
    (~(dug jo:json-utils data.st) /pre-ver ni:dejs:format 0)
  =/  pre-log-ver=@ud
    (~(dug jo:json-utils data.st) /pre-log-ver ni:dejs:format 0)
  =/  session=@tas
    =/  ses=@t  (~(dug jo:json-utils data.st) /session so:dejs:format '')
    (crip (trip ses))
  =/  wid=@ud
    (~(dug jo:json-utils data.st) /width ni:dejs:format 80)
  =/  ses-road=road:tarball  [%& %& /sys/dill/sessions session]
  =/  logs-road=road:tarball  [%& %& /sys/dill %'logs.dill-told']
  ::  Fetch terminal blits and logs since our command
  ;<  ses-res=(each (list [=cass:clay =cage]) tang)  bind:m
    (peep:io /hist ses-road [%numb `+(pre-ver) ~])
  ;<  log-res=(each (list [=cass:clay =cage]) tang)  bind:m
    (peep:io /logs logs-road [%numb `+(pre-log-ver) ~])
  ::  Render terminal output
  =/  all-blits=(list blit:dill)
    ?.  ?=(%& -.ses-res)  ~
    (zing (turn p.ses-res |=([=cass:clay =cage] !<((list blit:dill) q.cage))))
  =/  terminal=@t  (render-blits:clurd all-blits wid)
  ::  Render logs
  =/  log-text=tape
    ?.  ?=(%& -.log-res)  ""
    %-  zing
    %+  turn  p.log-res
    |=  [=cass:clay =cage]
    =/  =told:dill  !<(told:dill q.cage)
    (format-told:tools told)
  ::  Combine
  =/  out=tape
    %+  weld  (trip terminal)
    ?~(log-text "" "\0a--- logs ---\0a{log-text}")
  (pure:m [%text (crip out)])
--
|%
++  name  'run_dojo'
++  description
  'Execute a dojo command on the ship and return the rendered terminal output with system logs.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  ^-  (list [@t parameter-def:tools])
  :~  ['command' [%string 'The dojo command to execute']]
      ['session' [%string 'Session name (default: empty for default session)']]
      ['width' [%number 'Terminal width for rendering (default: 80)']]
      ['timeout' [%number 'Max seconds to wait (default: 30)']]
      ['delay' [%number 'Seconds to wait after prompt before reading (default: 2)']]
  ==
++  required  ~['command']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown run_dojo step'])
      %start
    =/  args=json  [%o args.st]
    =/  command=@t
      (~(dog jo:json-utils args) /command so:dejs:format)
    =/  session=@tas
      =/  ses=@t  (~(dug jo:json-utils args) /session so:dejs:format '')
      (crip (trip ses))
    =/  wid=@ud
      (~(dug jo:json-utils args) /width ni:dejs:format 80)
    =/  timeout=@ud
      (~(dug jo:json-utils args) /timeout ni:dejs:format 30)
    =/  delay=@ud
      (~(dug jo:json-utils args) /delay ni:dejs:format 2)
    ::  Record version before command for both session and logs
    =/  ses-road=road:tarball  [%& %& /sys/dill/sessions session]
    =/  logs-road=road:tarball  [%& %& /sys/dill %'logs.dill-told']
    ;<  pre=seen:nexus  bind:m  (peek:io /pre ses-road ~)
    =/  pre-ver=@ud
      ?.  ?=([%& %file *] pre)  0
      ud.file.sack.p.pre
    ;<  pre-logs=seen:nexus  bind:m  (peek:io /pre-logs logs-road ~)
    =/  pre-log-ver=@ud
      ?.  ?=([%& %file *] pre-logs)  0
      ud.file.sack.p.pre-logs
    ::  Checkpoint state before sending command
    =/  run-data=json
      %-  pairs:enjs:format
      :~  ['pre-ver' (numb:enjs:format pre-ver)]
          ['pre-log-ver' (numb:enjs:format pre-log-ver)]
          ['session' s+session]
          ['width' (numb:enjs:format wid)]
          ['delay' (numb:enjs:format delay)]
      ==
    ;<  ~  bind:m
      (replace:io !>([tool.st args.st %running run-data ~]))
    ::  Send the command as belt input + return
    =/  chars=(list @c)  (tuba (trip command))
    ;<  ~  bind:m
      (send-card:io %pass /dojo %arvo %d %shot session %belt [%txt chars])
    ;<  ~  bind:m
      (send-card:io %pass /dojo-ret %arvo %d %shot session %belt [%ret ~])
    ::  Subscribe to session for updates
    ;<  *  bind:m  (keep:io /watch ses-road ~)
    ::  Set timeout
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (send-card:io %pass /timeout %arvo %b %wait (add now.bowl (mul ~s1 timeout)))
    ::  Wait until we see a prompt in a blit batch that comes AFTER our command
    =/  batches=@ud  0
    |-
    ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
    ?:  ?=(%wake -.nw)
      ::  Timeout — re-read state (has checkpointed pre-vers) and read results
      ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
      (read-results st)
    ?.  ?=([%file *] view.nw)  $
    ?.  ?=(%dill-blit p.cage.view.nw)  $
    =.  batches  +(batches)
    ::  Skip the first batch (command echo) — wait for result + prompt
    ?.  (gth batches 1)  $
    =/  blits=(list blit:dill)
      !<((list blit:dill) q.cage.view.nw)
    =/  rendered=@t  (render-blits:clurd blits wid)
    =/  txt=tape  (trip rendered)
    ::  Check for prompt at end of this batch
    ?.  !=(~ (find ":dojo> " txt))  $
    ::  Prompt found — wait for result blits to settle
    ;<  ~  bind:m  (sleep:io (mul ~s1 delay))
    ::  Re-read state (has checkpointed pre-vers)
    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
    (read-results st)
  ::
      %running
    ::  Resumed after reboot — just read results
    (read-results st)
  ==
--
