::  insert-clay-file: insert or overwrite a file in Clay
::
!:
^-  tool:tools
|%
++  name  'insert_clay_file'
++  description
  ^~  %-  crip
  ;:  weld
    "Insert or overwrite a file in the Clay filesystem. "
    "Paths use slashes, not dots: /gen/hello/hoon (not /gen/hello.hoon). "
    "The last segment is the mark (e.g. /app/foo/hoon has mark %hoon). "
    "The desk must have a matching mark file in /mar/."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Target desk name (e.g. "base")']]
      ['path' [%string 'File path including mark (e.g. "/gen/hello/hoon")']]
      ['content' [%string 'File content to write']]
  ==
++  required  ~['desk' 'path' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown insert step'])
      %start
    ;<  err=(unit tang)  bind:m  (sleep-or-crud:tools (div ~s1 10))
    ?^  err
      =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
    =/  [desk=@t file-path=@t content=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
          ['path' so:dejs:format]
          ['content' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    =/  pax=path  (stab file-path)
    ?~  pax
      (pure:m [%error 'Empty path'])
    =/  mark=@tas  (rear pax)
    ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
    =/  write-data=json
      %-  pairs:enjs:format
      :~  ['initial-ud' (numb:enjs:format ud.initial)]
          ['desk' s+desk]
          ['file-path' s+file-path]
          ['logs' a+~]
      ==
    ;<  ~  bind:m
      (replace:io !>([args.st %inserting write-data]))
    ;<  *  bind:m  (keep:io /dill/logs [%& %& /sys/dill %'logs.dill-told'] ~)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl ~s30))
    ;<  ~  bind:m
      (gall-poke-our:io %hood kiln-info+!>(["" `[dek %& [pax %ins mark !>(content)]~]]))
    ;<  ~  bind:m  collect-logs:tools
    ;<  ~  bind:m  (drop:io /dill/logs [%& %& /sys/dill %'logs.dill-told'])
    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
    (finish-clay-write:tools args.st data.st)
      %inserting
    (finish-clay-write:tools args.st data.st)
  ==
--
