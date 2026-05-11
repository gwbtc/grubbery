/<  tools  /lib/nex/tools.hoon
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
    =/  mount-point-json=(unit json)
      (~(get by args.st) 'mount_point')
    ?~  mount-point-json
      (pure:m [%error 'Missing required argument: mount_point'])
    ?.  ?=([%s *] u.mount-point-json)
      (pure:m [%error 'mount_point must be a string'])
    =/  mount-point=@tas  (slav %tas p.u.mount-point-json)
    =/  timeout-seconds=@ud
      ?~  timeout-json=(~(get by args.st) 'timeout_seconds')
        30
      ?.  ?=([%n *] u.timeout-json)
        30
      (rash p.u.timeout-json dem)
    =/  timeout=@dr  (mul timeout-seconds ~s1)
    ;<  initial=cass:clay  bind:m  (scry:io cass:clay /cw/[mount-point])
    =/  commit-data=json
      %-  pairs:enjs:format
      :~  ['initial-ud' (numb:enjs:format ud.initial)]
          ['initial-da' s+(scot %da da.initial)]
          ['logs' a+~]
      ==
    ;<  ~  bind:m
      (replace:io !>([tool.st args.st %committing commit-data ~]))
    ~&  >>  "%commit: subscribing to dill logs"
    ;<  *  bind:m  (keep:io /dill/logs [%& %& /sys/dill %'logs.dill-told'] ~)
    ;<  now=@da  bind:m  get-time:io
    ~&  >>  "%commit: setting timeout timer"
    ;<  ~  bind:m
      (set-timer:io /commit-timeout (add now timeout))
    ~&  >>  "%commit: poking hood"
    ;<  ~  bind:m  (gall-poke-our:io %hood kiln-commit+[mount-point %.n])
    ~&  >>  "%commit: collecting logs"
    ;<  ~  bind:m  collect-logs:tools
    ~&  >>  "%commit: done collecting"
    ;<  ~  bind:m  (drop:io /dill/logs [%& %& /sys/dill %'logs.dill-told'])
    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
    (finish-commit:tools args.st data.st)
      %committing
    (finish-commit:tools args.st data.st)
  ==
--
