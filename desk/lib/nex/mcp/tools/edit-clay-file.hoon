::  edit-clay-file: edit a file in Clay via exact string replacement
::
!:
^-  tool:tools
|%
++  name  'edit_clay_file'
++  description
  ^~  %-  crip
  ;:  weld
    "Edit a file in Clay via exact string replacement. "
    "Reads the file, replaces old_string with new_string, and writes it back. "
    "Fails if old_string is not found or matches multiple times."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name (e.g. "base")']]
      ['path' [%string 'File path including mark (e.g. "/gen/hello/hoon")']]
      ['old_string' [%string 'The exact text to find and replace']]
      ['new_string' [%string 'The replacement text']]
  ==
++  required  ~['desk' 'path' 'old_string' 'new_string']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown edit step'])
      %start
    ;<  err=(unit tang)  bind:m  (sleep-or-crud:tools (div ~s1 10))
    ?^  err
      =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
    =/  [desk=@t file-path=@t old=@t new=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
          ['path' so:dejs:format]
          ['old_string' so:dejs:format]
          ['new_string' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    =/  pax=path  (stab file-path)
    ?~  pax
      (pure:m [%error 'Empty path'])
    =/  mark=@tas  (rear pax)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  =riot:clay  bind:m
      (warp:io our.bowl dek ~ %sing %x da+now.bowl pax)
    ?~  riot
      (pure:m [%error (crip "File not found: {(trip file-path)}")])
    =/  =tang  (pretty-file:pretty-file:tools !<(noun q.r.u.riot))
    =/  =wain
      %-  zing
      %+  turn  tang
      |=(=tank (turn (wash [0 160] tank) crip))
    =/  text=tape  (trip (of-wain:format wain))
    =/  old-tape=tape  (trip old)
    =/  idx=(unit @ud)  (find old-tape text)
    ?~  idx
      (pure:m [%error 'old_string not found in file'])
    =/  rest=tape  (slag (add u.idx (lent old-tape)) text)
    ?.  =(~ (find old-tape rest))
      (pure:m [%error 'old_string matches multiple times; provide more context'])
    =/  new-tape=tape  (trip new)
    =/  before=tape  (scag u.idx text)
    =/  after=tape  (slag (add u.idx (lent old-tape)) text)
    =/  result=@t  (crip (zing ~[before new-tape after]))
    ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
    =/  write-data=json
      %-  pairs:enjs:format
      :~  ['initial-ud' (numb:enjs:format ud.initial)]
          ['desk' s+desk]
          ['file-path' s+file-path]
          ['logs' a+~]
      ==
    ;<  ~  bind:m
      (replace:io !>([args.st %editing write-data]))
    ;<  *  bind:m  (keep:io /dill-logs [%& %& /sys %dill-logs] ~)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl ~s30))
    ;<  ~  bind:m
      (gall-poke-our:io %hood kiln-info+!>(["" `[dek %& [pax %ins mark !>(result)]~]]))
    ;<  ~  bind:m  collect-logs:tools
    ;<  ~  bind:m  (drop:io /dill-logs [%& %& /sys %dill-logs])
    ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
    (finish-clay-write:tools args.st data.st)
      %editing
    (finish-clay-write:tools args.st data.st)
  ==
--
