/<  tools  /lib/nex/tools.hoon
::  delete-clay-file: delete a file from a Clay desk
::
!:
^-  tool:tools
|%
++  name  'delete_clay_file'
++  description
  ^~  %-  crip
  ;:  weld
    "Delete a file from a Clay desk. "
    "Path uses slashes including mark: /gub/nex/wallet/hoon (not .hoon). "
    "Fails if the file does not exist."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name (e.g. "grubbery")']]
      ['path' [%string 'File path including mark (e.g. "/gub/nex/wallet/hoon")']]
  ==
++  required  ~['desk' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown delete step'])
      %start
    ;<  err=(unit tang)  bind:m  (sleep-or-crud:tools (div ~s1 10))
    ?^  err
      =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
    =/  parsed=(each [@t @t] tang)
      %-  mule  |.
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
          ['path' so:dejs:format]
      ==
    ?:  ?=(%| -.parsed)
      (pure:m [%error 'Missing or invalid required arguments (desk, path)'])
    =/  [desk=@t file-path=@t]  p.parsed
    =/  dek=@tas  (slav %tas desk)
    =/  pax=path  (stab file-path)
    ?~  pax
      (pure:m [%error 'Empty path'])
    ::  Verify file exists before deleting
    ;<  our=@p  bind:m  get-our:io
    ;<  now=@da  bind:m  get-time:io
    ;<  =riot:clay  bind:m
      (warp:io our dek ~ %sing %x da+now pax)
    ?~  riot
      (pure:m [%error (crip "File not found: {(trip file-path)}")])
    ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /cw/[dek])
    =/  write-data=json
      %-  pairs:enjs:format
      :~  ['initial-ud' (numb:enjs:format ud.initial)]
          ['desk' s+desk]
          ['file-path' s+file-path]
          ['logs' a+~]
      ==
    ;<  ~  bind:m
      (replace:io !>([tool.st args.st %deleting write-data ~]))
    ;<  *  bind:m  (keep:io /dill/logs [%& %& /sys/dill %'logs.dill-told'] ~)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m
      (send-card:io %pass /commit-timeout %arvo %b %wait (add now ~s30))
    ;<  ~  bind:m
      (gall-poke-our:io %hood kiln-info+!>(["" `[dek %& [pax %del ~]~]]))
    ;<  ~  bind:m  collect-logs:tools
    ;<  ~  bind:m  (drop:io /dill/logs [%& %& /sys/dill %'logs.dill-told'])
    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
    (finish-clay-write:tools args.st data.st)
      %deleting
    (finish-clay-write:tools args.st data.st)
  ==
--
