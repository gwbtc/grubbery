::  lib/nex/tools: types + shared helpers for MCP tool fibers
::
::  Defines $tool, $tool-state, $tool-result and shared helper arms
::  used by dynamic tool files in /lib/nex/mcp/tools/.
::
/+  nexus, tarball, io=fiberio, json-utils, pretty-file, s3
!:
|%
::  Tool execution result
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
  ==
::  Tool process state: args + step tag + step-specific data.
::  Step tag acts like a head-tagged union — handlers switch on it.
::  %start = fresh invocation. %done = finished with result.
::
+$  tool-state
  $:  tool=@t
      args=(map @t json)
      step=@tas
      data=json
  ==
::  Parameter schema for tool discovery (MCP, Claude API, etc.)
::
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
::
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
::  Tool definition: everything needed to advertise + execute a tool.
::  Built-in tools produce this directly. .hoon files must compile to this type.
::
+$  tool
  $_  ^?
  |%
  ++  name         *@t
  ++  description  *@t
  ++  parameters   *(map @t parameter-def)
  ++  required     *(list @t)
  ++  handler      *tool-handler
  --
::
+$  tool-handler  _*form:(fiber:fiber:nexus ,tool-result)
::  Simple glob pattern matching (* = any sequence of characters)
::
++  glob-match
  |=  [pat=tape txt=tape]
  ^-  ?
  ?~  pat  =(txt ~)
  ?:  =(i.pat '*')
    ?|  (glob-match t.pat txt)
        ?&(?=(^ txt) (glob-match pat t.txt))
    ==
  ?~  txt  %.n
  ?&(=(i.pat i.txt) (glob-match t.pat t.txt))
::  Shared helper arms used by dynamic tool files
::
++  finish-commit
  |=  [args=(map @t json) data=json]
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?.  ?=([%o *] data)
    (pure:m [%error 'Commit state lost (stale tool grub). Please retry.'])
  =/  mount-point=@tas
    %.  [%o args]
    %-  ot:dejs:format
    :~  ['mount_point' so:dejs:format]
    ==
  ?~  (~(get by p.data) 'initial-ud')
    (pure:m [%error 'Commit state incomplete. Please retry.'])
  =/  initial-ud=@ud
    (~(dog jo:json-utils data) /initial-ud ni:dejs:format)
  =/  log-texts=(list @t)
    (~(dug jo:json-utils data) /logs (ar:dejs:format so:dejs:format) ~)
  ;<  final=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[mount-point])
  =/  result=tape
    %+  weld  "Initial version: {<initial-ud>}\0a"
    %+  weld  "Final version: {<ud.final>}\0a"
    %+  weld  "Logs ({<(lent log-texts)>}):\0a"
    (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
  (pure:m [%text (crip result)])
::
++  finish-clay-write
  |=  [args=(map @t json) data=json]
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?.  ?=([%o *] data)
    (pure:m [%error 'Clay write state lost. Please retry.'])
  ?~  (~(get by p.data) 'initial-ud')
    (pure:m [%error 'Clay write state incomplete. Please retry.'])
  =/  initial-ud=@ud
    (~(dog jo:json-utils data) /initial-ud ni:dejs:format)
  =/  desk=@t
    (~(dog jo:json-utils data) /desk so:dejs:format)
  =/  file-path=@t
    (~(dog jo:json-utils data) /file-path so:dejs:format)
  =/  log-texts=(list @t)
    (~(dug jo:json-utils data) /logs (ar:dejs:format so:dejs:format) ~)
  =/  dek=@tas  (slav %tas desk)
  ;<  final=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
  =/  has-errors=?
    %+  lien  log-texts
    |=(t=@t !=(~ (find "ERROR" (trip t))))
  =/  result=tape
    ?:  has-errors
      %+  weld  "Clay write FAILED for {(trip file-path)} in %{(trip desk)}\0a"
      %+  weld  "Version unchanged: {<ud.final>}\0a"
      %+  weld  "Errors ({<(lent log-texts)>}):\0a"
      (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
    %+  weld  "Wrote {(trip file-path)} to %{(trip desk)}\0a"
    %+  weld  "Version: {<initial-ud>} -> {<ud.final>}\0a"
    ?~  log-texts  ""
    %+  weld  "Logs ({<(lent log-texts)>}):\0a"
    (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
  ?:  has-errors
    (pure:m [%error (crip result)])
  (pure:m [%text (crip result)])
::  Sleep to leave the Eyre HTTP request event.  Returns ~ on
::  success (timer fired cleanly) or [~ tang] if the subsequent
::  work crashed the event and behn retried with the error.
::  This lets us capture Clay build errors as data instead of
::  crashing with crud! or timer-error.
::
++  sleep-or-crud
  |=  for=@dr
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl:io /sleep)
  =/  until=@da  (add now.bowl for)
  ;<  ~  bind:m  (send-wait:io until)
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?.  =(`until (slaw %da i.t.wire.u.in))
      [%skip ~]
    ?~  error.sign.u.in
      [%done ~]
    [%done `u.error.sign.u.in]
  ==
::  Collect dill logs with debounce: returns ~1s after last log.
::  Each log spawns a quiet timer tagged with log count. If 1s passes
::  with no new logs, we're done. Main timeout is the hard backstop.
::
+$  commit-event
  $%  [%timeout ~]
      [%quiet count=@ud]
      [%log =told:dill]
  ==
::
++  take-commit-event
  =/  m  (fiber:fiber:nexus ,commit-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %arvo [%commit-timeout ~] %behn %wake *]
    [%done %timeout ~]
      [~ %arvo [%commit-quiet @ ~] %behn %wake *]
    [%done %quiet (slav %ud i.t.wire.u.in)]
      [~ %news [%dill %logs ~] *]
    ?.  ?=([%file *] view.u.in)  [%skip ~]
    ?.  ?=(%dill-told p.cage.view.u.in)  [%skip ~]
    [%done %log !<(told:dill q.cage.view.u.in)]
  ==
::
++  collect-logs
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  =commit-event  bind:m  take-commit-event
  ?-    -.commit-event
      %timeout  (pure:m ~)
      %quiet
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    ?.  =(count.commit-event (lent logs))
      $  :: stale timer, keep waiting
    (pure:m ~)
      %log
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    =/  log-text=tape  (format-told told.commit-event)
    =/  new-data=json
      (~(put jo:json-utils data.st) /logs a+[s+(crip log-text) logs])
    =/  new-count=@ud  +((lent logs))
    ;<  ~  bind:m  (replace:io !>([tool.st args.st step.st new-data]))
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (send-card:io %pass /commit-quiet/(scot %ud new-count) %arvo %b %wait (add now.bowl ~s1))
    $
  ==
::  Format a dill told to text
::
++  format-told
  |=  log=told:dill
  ^-  tape
  ?-  -.log
      %crud
    =/  err-lines=wall  (zing (turn (flop q.log) (cury wash [0 80])))
    =/  lines-text=tape
      %-  zing
      %+  turn  err-lines
      |=(line=tape "{line}\0a")
    "ERROR [{<p.log>}]:\0a{lines-text}"
      %talk
    =/  talk-lines=wall  (zing (turn p.log (cury wash [0 80])))
    %-  zing
    %+  turn  talk-lines
    |=(line=tape "{line}\0a")
      %text
    "{p.log}\0a"
  ==
::
::  Render grub content as text for tool output
::
++  render-grub-content
  |=  =seen:nexus
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?>  ?=([%& %file *] seen)
  =/  =cage  cage.p.seen
  ?+  p.cage
    ::  Fallback: scry for tube to mime via %cc
    ;<  =desk  bind:m  get-desk:io
    ;<  convert=tube:clay  bind:m
      (do-scry:io tube:clay /tube /cc/[desk]/[p.cage]/mime)
    =/  result-vase=vase  (convert q.cage)
    =/  out=mime  !<(mime result-vase)
    (pure:m [%text (crip (trip q.q.out))])
      %json
    (pure:m [%text (en:json:html !<(json q.cage))])
      %txt
    (pure:m [%text (of-wain:format !<(wain q.cage))])
      %hoon
    (pure:m [%text !<(@t q.cage)])
      %mime
    =/  out=mime  !<(mime q.cage)
    (pure:m [%text (crip (trip q.q.out))])
  ==
::  Look up a grub by name — exact match
::  Returns [actual-grub-name seen]
::
++  lookup-grub
  |=  [pax=path file-name=@ta]
  =/  m  (fiber:fiber:nexus ,[name=@ta seen=seen:nexus])
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /read [%& %& pax file-name] ~)
  (pure:m [file-name seen])
::  String replacement on tapes
::  Returns (unit tape) — ~ if not found or ambiguous
::
++  tape-replace
  |=  [txt=tape old=tape new=tape all=?]
  ^-  (each tape @tas)
  =/  old-len=@ud  (lent old)
  ?:  =(0 old-len)  [%| %empty-search]
  =/  idx=(unit @ud)  (find old txt)
  ?~  idx  [%| %not-found]
  ?.  all
    ::  Single replace: verify uniqueness
    =/  after=@ud  (add u.idx old-len)
    =/  rest=tape  (slag after txt)
    ?^  (find old rest)  [%| %not-unique]
    :-  %&
    :(weld (scag u.idx txt) new (slag after txt))
  ::  Replace all occurrences
  =|  acc=tape
  =/  src=tape  txt
  |-
  =/  hit=(unit @ud)  (find old src)
  ?~  hit  [%& (weld acc src)]
  %=  $
    acc  :(weld acc (scag u.hit src) new)
    src  (slag (add u.hit old-len) src)
  ==
::  S3 credential type
::
+$  s3-creds
  $:  access-key=@t
      secret-key=@t
      region=@t
      endpoint=@t
      bucket=@t
  ==
::  Read S3 credentials from config/creds/s3
::
++  read-s3-creds
  =/  m  (fiber:fiber:nexus ,s3-creds)
  ^-  form:m
  ;<  creds-seen=seen:nexus  bind:m
    (peek:io /creds [%& %& /config/creds 's3'] ~)
  ?.  ?=([%& %file *] creds-seen)
    ~|  %s3-creds-not-found
    !!
  =/  jon=json  !<(json q.cage.p.creds-seen)
  =/  creds=s3-creds
    %.  jon
    %-  ot:dejs:format
    :~  ['access-key' so:dejs:format]
        ['secret-key' so:dejs:format]
        ['region' so:dejs:format]
        ['endpoint' so:dejs:format]
        ['bucket' so:dejs:format]
    ==
  (pure:m creds)
--