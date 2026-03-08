::  commit: commit a mounted desk and return version info with logs
::
!:
^-  tool:tools
|%
++  name  'commit'
++  description  'Commit a mounted desk and return version info with logs'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['mount_point' [%string 'Mount point name (e.g. "base")']]
      ['timeout_seconds' [%number 'Timeout in seconds to wait for logs (default: 30)']]
  ==
++  required  ~['mount_point']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown commit step'])
      %start
    =/  mount-point=@tas
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['mount_point' so:dejs:format]
      ==
    =/  timeout-seconds=@ud
      ?~  timeout-json=(~(get by args.st) 'timeout_seconds')
        30
      ?.  ?=([%n *] u.timeout-json)
        30
      (rash p.u.timeout-json dem)
    =/  timeout=@dr  (mul timeout-seconds ~s1)
    ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[mount-point])
    =/  commit-data=json
      %-  pairs:enjs:format
      :~  ['initial-ud' (numb:enjs:format ud.initial)]
          ['initial-da' s+(scot %da da.initial)]
          ['logs' a+~]
      ==
    ;<  ~  bind:m
      (replace:io !>([args.st %committing commit-data]))
    ;<  *  bind:m  (keep:io /dill-logs [%& %& /sys %dill-logs] ~)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl timeout))
    ;<  ~  bind:m  (gall-poke-our:io %hood kiln-commit+!>([mount-point %.n]))
    ;<  ~  bind:m  collect-logs:tools
    ;<  ~  bind:m  (drop:io /dill-logs [%& %& /sys %dill-logs])
    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
    (finish-commit:tools args.st data.st)
      %committing
    (finish-commit:tools args.st data.st)
  ==
--
