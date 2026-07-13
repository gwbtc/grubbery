::  lib/nex/tools: types + shared helpers for MCP tool fibers
::
::  Defines $tool, $tool-state, $tool-result and shared helper arms
::  used by dynamic tool files in /lib/nex/mcp/tools/.
::
/<  s3  /lib/s3.hoon
|%
::  Tool execution result
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
      [%mime =mime]
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
      update=(unit json)
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
::  Safe path parser: returns error result instead of crashing
::
++  parse-path
  |=  t=@t
  ^-  (each path @t)
  =/  pax=(unit path)  (rush t stap)
  ?~  pax
    [%| (crip "Invalid path: {(trip t)} (must start with /)")]
  [%& u.pax]
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
  ;<  final=cass:clay  bind:m  (clay-case:io mount-point)
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
  ;<  final=cass:clay  bind:m  (clay-case:io dek)
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
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now for)
  ;<  ~  bind:m  (send-wait:io until)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    [%done ~]
  ==
::  Collect dill logs with debounce: returns ~1s after last log.
::  Each log spawns a quiet timer tagged with log count. If 1s passes
::  with no new logs, we're done. Main timeout is the hard backstop.
::
+$  commit-event
  $%  [%timeout ~]
      [%quiet count=@ud]
      [%log =wave:nexus]
  ==
::
++  take-commit-event
  =/  m  (fiber:fiber:nexus ,commit-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    =/  wak=wire  !<(wire q.sage.u.in)
    ?+  wak  [%skip ~]
        [%commit-timeout ~]
      [%done %timeout ~]
        [%commit-quiet @ ~]
      [%done %quiet (slav %ud i.t.wak)]
    ==
      [~ %news [%dill %logs ~] *]
    [%done %log wave.u.in]
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
    ;<  dill-view=view:nexus  bind:m  (peek:io [%& %& /sys/dill %'logs.dill-told'] ~)
    =/  log-text=tape
      ?.  ?=([%file *] dill-view)  ""
      ?.  ?=(%dill-told name.p.sang.dill-view)  ""
      (format-told !<(told:dill (need-vase:tarball sang.dill-view)))
    ?:  =(~ log-text)  $
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    =/  new-data=json
      (~(put jo:json-utils data.st) /logs a+[s+(crip log-text) logs])
    =/  new-count=@ud  +((lent logs))
    ;<  ~  bind:m  (replace:io [tool.st args.st step.st new-data ~])
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m
      (set-timer:io /commit-quiet/(scot %ud new-count) (add now ~s1))
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
::  Is this mark name known to be text-renderable directly?
::
++  is-text-blot
  |=  name=@tas
  ^-  ?
  %-  ~(has in `(set @tas)`(sy ~[%json %txt %hoon %html %css %js %csv %xml %md %sig]))
  name
::  Is this mime media type representable as text?
::
++  is-text-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?:  =('text' i.mite)  %.y
  ?.  =('application' i.mite)  %.n
  ?~  t.mite  %.n
  (~(has in (sy ~['json' 'xml' 'javascript' 'x-javascript' 'ecmascript'])) i.t.mite)
::  Is this mime type supported as multimodal content by Claude?
::
++  is-multimodal-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?|  =('image' i.mite)
      =([~['application' 'pdf']] mite)
  ==
::  Convert mite to media type cord (e.g. ~['image' 'png'] -> 'image/png')
::
++  mite-to-cord
  |=  =mite
  ^-  @t
  (crip (zing (join "/" (turn mite trip))))
::  Render mime content as a tool-result based on media type.
::  Text types become %text, multimodal types become %mime,
::  unsupported binary types fall back to text.
::
++  render-mime
  |=  out=mime
  ^-  tool-result
  ?:  (is-text-mime p.out)
    [%text (crip (trip q.q.out))]
  ?:  (is-multimodal-mime p.out)
    [%mime out]
  ::  unsupported binary — best-effort text
  [%text (crip (trip q.q.out))]
::
::  Render grub content for tool output.
::
::  Priority:
::    1. boom → error with trace
::    2. Known text blots → render as text directly
::    3. /mime blot → check media type (text vs multimodal)
::    4. Unknown blot → convert to mime, check media type
::    5. No conversion → error
::
++  render-grub-content
  |=  =view:nexus
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?>  ?=([%file *] view)
  ::  1. boom (validation failure): render error tang
  ?:  ?=(%| -.q.sang.view)
    =/  =boom:tarball  p.q.sang.view
    =/  rendered=tape
      %-  zing
      %+  turn  (flop tang.boom)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%error (crip "BOOM (mark %{(trip name.p.sang.view)})\0a{rendered}")])
  =/  =sage:tarball  (need-sage:tarball sang.view)
  =/  blot-text=@t
    (crip "[mark: {(spud (snoc path.p.sage name.p.sage))}]")
  ;<  result=tool-result  bind:m
    ::  2. known text blots: render as text directly
    ?:  (is-text-blot name.p.sage)
      ?+  name.p.sage
        (pure:m [%text !<(@t q.sage)])
          %json  (pure:m [%text (en:json:html !<(json q.sage))])
          %txt   (pure:m [%text (of-wain:format !<(wain q.sage))])
          %hoon  (pure:m [%text !<(@t q.sage)])
      ==
    ::  3. /mime blot: check media type
    ?:  =(%mime name.p.sage)
      (pure:m (render-mime !<(mime q.sage)))
    ::  4. unknown blot: convert to mime, then check media type
    ;<  convert=(unit tube:clay)  bind:m
      (get-tube:io [%& %| /code] [p.sage [/ %mime]])
    ?~  convert
      (pure:m [%error (crip "No conversion from {(trip name.p.sage)} to mime")])
    =/  out=mime  !<(mime (u.convert q.sage))
    (pure:m (render-mime out))
  ?:  ?=(%error -.result)  (pure:m result)
  ?:  ?=(%mime -.result)
    (pure:m [%mime mime.result])
  (pure:m [%text (crip "{(trip blot-text)}\0a{(trip text.result)}")])
::  Look up a grub by name — exact match
::  Returns [actual-grub-name view]
::
++  lookup-grub
  |=  [pax=path file-name=@ta]
  =/  m  (fiber:fiber:nexus ,[name=@ta view=view:nexus])
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io [%& %& pax file-name] ~)
  (pure:m [file-name view])
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
::  Read S3 credentials from mcp nexus
::
++  read-s3-creds
  =/  m  (fiber:fiber:nexus ,s3-creds)
  ^-  form:m
  ;<  creds-view=view:nexus  bind:m
    (peek:io [%& %& /'mcp.mcp' %'s3.json'] `[/ %json])
  ?.  ?=([%file *] creds-view)
    ~|  %s3-creds-not-found
    !!
  =/  jon=json  !<(json (need-vase:tarball sang.creds-view))
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