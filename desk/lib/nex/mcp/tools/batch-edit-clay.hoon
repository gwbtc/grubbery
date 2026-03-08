::  batch-edit-clay: edit multiple files in Clay as a single atomic commit
::
!:
^-  tool:tools
|%
++  name  'batch_edit_clay'
++  description
  ^~  %-  crip
  ;:  weld
    "Edit multiple files in Clay as a single atomic commit. "
    "Takes a desk and an array of edits, each with path, old_string, "
    "and new_string. All edits are applied in one Clay write so the "
    "desk only recompiles once. Fails if any old_string is not found "
    "or matches multiple times."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name (e.g. "base")']]
      ['edits' [%array 'Array of {path, old_string, new_string} objects']]
  ==
++  required  ~['desk' 'edits']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown batch-edit step'])
      %start
    ;<  err=(unit tang)  bind:m  (sleep-or-crud:tools (div ~s1 10))
    ?^  err
      =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
    =/  desk=@t
      %.  [%o args.st]
      (ot:dejs:format ~[['desk' so:dejs:format]])
    =/  edits-json=json
      (~(got by args.st) 'edits')
    ?.  ?=([%a *] edits-json)
      (pure:m [%error 'edits must be a JSON array'])
    =/  edit-list=(list json)  p.edits-json
    ?~  edit-list
      (pure:m [%error 'edits array is empty'])
    =/  dek=@tas  (slav %tas desk)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  instructions=(list [pax=path mark=@tas content=@t])  ~
    =/  file-names=(list @t)  ~
    =/  remaining=(list json)  edit-list
    |-
    ?~  remaining
      ?~  instructions
        (pure:m [%error 'no valid edits to apply'])
      ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
      =/  ins=(list [path %ins @tas vase])
        %+  turn  (flop instructions)
        |=  [pax=path mark=@tas content=@t]
        [pax %ins mark !>(content)]
      =/  write-data=json
        %-  pairs:enjs:format
        :~  ['initial-ud' (numb:enjs:format ud.initial)]
            ['desk' s+desk]
            ['file-path' s+(crip "{<(lent instructions)>} files")]
            ['logs' a+~]
        ==
      ;<  ~  bind:m
        (replace:io !>([tool.st args.st %batch-editing write-data]))
      ;<  *  bind:m  (keep:io /dill/logs [%& %& /sys/dill %'logs.dill-told'] ~)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ;<  ~  bind:m
        (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl ~s30))
      ;<  ~  bind:m
        (gall-poke-our:io %hood kiln-info+!>(["" `[dek %& ins]]))
      ;<  ~  bind:m  collect-logs:tools
      ;<  ~  bind:m  (drop:io /dill/logs [%& %& /sys/dill %'logs.dill-told'])
      ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
      ;<  res=tool-result:tools  bind:m  (finish-clay-write:tools args.st data.st)
      =/  file-summary=tape
        %+  roll  (flop file-names)
        |=  [f=@t acc=tape]
        ?~  acc  (trip f)
        (zing ~[acc "\0a" (trip f)])
      ?-  -.res
        %error  (pure:m res)
        %text   (pure:m [%text (crip (zing ~[(trip text.res) "\0aFiles edited:\0a" file-summary]))])
      ==
    =/  edit=json  i.remaining
    =/  parsed=(unit [file-path=@t old=@t new=@t])
      %-  mole  |.
      %.  edit
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['old_string' so:dejs:format]
          ['new_string' so:dejs:format]
      ==
    ?~  parsed
      (pure:m [%error 'each edit must have path, old_string, new_string'])
    =/  pax=path  (stab file-path.u.parsed)
    ?~  pax
      (pure:m [%error (crip "empty path in edit")])
    =/  mark=@tas  (rear pax)
    ;<  =riot:clay  bind:m
      (warp:io our.bowl dek ~ %sing %x da+now.bowl pax)
    ?~  riot
      (pure:m [%error (crip "File not found: {(trip file-path.u.parsed)}")])
    =/  =tang  (pretty-file:pretty-file:tools !<(noun q.r.u.riot))
    =/  =wain
      %-  zing
      %+  turn  tang
      |=(=tank (turn (wash [0 160] tank) crip))
    =/  text=tape  (trip (of-wain:format wain))
    =/  old-tape=tape  (trip old.u.parsed)
    =/  idx=(unit @ud)  (find old-tape text)
    ?~  idx
      (pure:m [%error (crip "old_string not found in {(trip file-path.u.parsed)}")])
    =/  rest=tape  (slag (add u.idx (lent old-tape)) text)
    ?.  =(~ (find old-tape rest))
      (pure:m [%error (crip "old_string matches multiple times in {(trip file-path.u.parsed)}")])
    =/  new-tape=tape  (trip new.u.parsed)
    =/  before=tape  (scag u.idx text)
    =/  after=tape  (slag (add u.idx (lent old-tape)) text)
    =/  result=@t  (crip (zing ~[before new-tape after]))
    %=  $
      remaining     t.remaining
      instructions  [[pax mark result] instructions]
      file-names    [file-path.u.parsed file-names]
    ==
      %batch-editing
    (finish-clay-write:tools args.st data.st)
  ==
--
