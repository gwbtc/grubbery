/<  tools  /lib/tools.hoon
::  call-tool-in: run a tool BY LOCATION, delegating to a run-site.
::
::    Everything is a rail/path, nothing is a registry name:
::      code   the tool's source path — /apps/foo/desk/code/lib/tools/bar
::             (absolute, extensionless; any code namespace on the ship)
::      run    where the run-state grub lives while it executes —
::             /proc/<sandbox>/<id>. Whatever weir governs that
::             location governs the run: placement IS the sandbox.
::      args   the tool's arguments
::
::    Unlike call_tool, which BECOMES the target inline (its own weir,
::    its own location), this MAKES a separate run grub, watches it to
::    %done, reads the result, and culls it. The separate process is
::    what lets the run be sandboxed independently of this caller.
::
::    The run id is minted once and recorded in our own state (data),
::    so a restart re-derives it and re-watches the existing sub-run
::    instead of orphaning it — the recover-from-state contract.
::
!:
^-  tool:tools
|%
++  name  'call_tool_in'
++  description
  ^~  %-  crip
  ;:  weld
    "Run a tool by LOCATION in a chosen run-site, so it can be "
    "sandboxed. 'code' is the tool source path (absolute, "
    "extensionless, e.g. /apps/foo/desk/code/lib/tools/bar). 'run' is "
    "where the run executes (e.g. /proc/mysandbox/job1) — its weir "
    "governs the run. 'args' are the tool's arguments."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['code' [%string 'Absolute, extensionless path to the tool source']]
      ['run' [%string 'Path where the run grub lives (e.g. /proc/box/job)']]
      ['args' [%object 'Arguments to pass to the tool']]
  ==
++  required  ~['code' 'run']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  code=(unit @t)  (~(deg jo:json-utils [%o args.st]) /code so:dejs:format)
  =/  run=(unit @t)   (~(deg jo:json-utils [%o args.st]) /run so:dejs:format)
  ?~  code  (pure:m [%error 'Missing required argument: code'])
  ?~  run   (pure:m [%error 'Missing required argument: run'])
  =/  run-pax=(unit path)  (rush u.run stap)
  ?:  |(?=(~ run-pax) ?=(~ u.run-pax))
    (pure:m [%error 'run must be an absolute path'])
  =/  run-road=road:tarball  [%& %& (snip `path`u.run-pax) (rear u.run-pax)]
  =/  sub-args=(map @t json)
    =/  a  (~(get jo:json-utils [%o args.st]) /args)
    ?~  a  ~
    ?.  ?=([%o *] u.a)  ~
    p.u.a
  ::  the sub-run's tool field is the code PATH — await-tool resolves a
  ::  leading-slash tool by location, so the run-site runs our target.
  =/  sub-state=tool-state:tools  [u.code sub-args %start *json ~]
  ::  keep our watch alive across restarts; make the sub-run once
  ;<  *  bind:m  (keep:io /sub run-road ~)
  ;<  exists=?  bind:m  (peek-exists:io run-road)
  ;<  ~  bind:m
    =/  m  (fiber:fiber:nexus ,~)
    ?:  exists  (pure:m ~)
    (make-gained:io run-road |+[[[/ %tool-state] sub-state] ~])
  ::  watch until the sub-run reaches %done, then read its result
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /sub)
  ?:  ?=(%wake -.nw)  $
  ;<  sv=view:nexus  bind:m  (peek:io run-road ~)
  ?.  ?=([%file *] sv)  $
  ?:  (is-boom:tarball sang.sv)  $
  =/  got  (mule |.(!<(tool-state:tools (need-vase:tarball sang.sv))))
  ?:  ?=(%| -.got)  $
  =/  sub  p.got
  ?.  =(%done step.sub)  $
  ::  done: drop the watch, cull the sub-run, return its result
  ;<  ~  bind:m  (drop:io /sub run-road)
  ;<  ~  bind:m  (cull:io run-road)
  ?~  update.sub
    (pure:m [%text 'sub-run completed with no result'])
  =/  u=json  u.update.sub
  ?:  =([~ %s %'error'] (~(get jo:json-utils u) /type))
    =/  msg=@t  (fall (~(deg jo:json-utils u) /message so:dejs:format) 'error')
    (pure:m [%error msg])
  =/  txt=@t  (fall (~(deg jo:json-utils u) /text so:dejs:format) '')
  (pure:m [%text txt])
--
