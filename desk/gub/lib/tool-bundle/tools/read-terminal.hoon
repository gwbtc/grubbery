/<  tools  /lib/tools.hoon
/<  clurd  /lib/clurd.hoon
::  read-terminal: read rendered dill terminal output
::
::  Reads historical blit batches from a dill session and renders
::  them through a VT100 terminal simulator. Each version in the
::  session grub's history is one blit batch from dill.
::
::  The session's blits are the prompt and drum's output only. The
::  ship's slog stream (printfs, ~& traces, crash reports) is a second
::  dill stream, %logs, which grubbery records as versions of
::  /sys/dill/logs.dill-told; those from the same span of time are
::  interleaved here by version time, the way webterm interleaves them
::  on screen. (The runtime's own prints, %bout's "took" lines among
::  them, go to vere's stderr and never enter Arvo: see /~_~/slog.)
::
::  Parameters:
::    session:  session name (default: "" for default session)
::    width:    terminal width for rendering (default: 80)
::    last:     number of recent versions to render (default: 100)
::    from:     start version for range query (optional)
::    to:       end version for range query (optional)
::    logs:     interleave the slog stream (default: true)
::
!:
^-  tool:tools
|%
++  name  'read_terminal'
++  description
  'Read rendered terminal output from a dill session, with the slog stream (printfs, ~& traces, crashes) interleaved by time. Replays blit history through a terminal renderer.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  ^-  (list [@t parameter-def:tools])
  :~  ['session' [%string 'Session name (default: empty for default session)']]
      ['width' [%number 'Terminal width for rendering (default: 80)']]
      ['last' [%number 'Number of recent blit batches to replay (default: 100)']]
      ['from' [%number 'Start of version range (inclusive)']]
      ['to' [%number 'End of version range (inclusive)']]
      ['logs' [%boolean 'Interleave the slog stream from /sys/dill/logs.dill-told (default: true)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  args=json  [%o args.st]
  =/  session=@ta
    =/  ses=@t  (~(dug jo:json-utils args) /session so:dejs:format '')
    (crip (trip ses))
  =/  wid=@ud
    (~(dug jo:json-utils args) /width ni:dejs:format 80)
  =/  last=@ud
    (~(dug jo:json-utils args) /last ni:dejs:format 100)
  =/  from=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /from)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  to=(unit @ud)
    =/  v=(unit json)  (~(get jo:json-utils args) /to)
    ?~  v  ~
    `(ni:dejs:format u.v)
  =/  logs=?
    =/  v=(unit json)  (~(get jo:json-utils args) /logs)
    ?:(?=([~ %b *] v) p.u.v %.y)
  =/  ses-road=road:tarball
    [%& %& /sys/dill/sessions session]
  ::  Get current version to compute range
  ;<  =view:nexus  bind:m
    (peek:io ses-road ~)
  ?.  ?=([%file *] view)
    (pure:m [%error 'Session not found'])
  =/  cur-ver=@ud  ud.cass.view
  ::  Determine version range
  =/  range-from=@ud
    ?^  from  u.from
    ?:  (lth cur-ver last)  1
    +((sub cur-ver last))
  =/  range-to=@ud
    (fall to cur-ver)
  ::  Fetch all versions in range via peep
  ;<  res=(each (list [=cass:clay =sage:tarball]) tang)  bind:m
    (peep:io ses-road [%numb `range-from `range-to])
  ?:  ?=(%| -.res)
    (pure:m [%error (crip (zing (turn (flop p.res) |=(=tank (weld ~(ram re tank) "\0a")))))])
  ?~  p.res
    (pure:m [%text 'No terminal history found'])
  ::  the session's batches, each at its version time
  =/  batches=(list [da=@da blits=(list blit:dill)])
    %+  turn  p.res
    |=  [=cass:clay =sage:tarball]
    [da.cass !<((list blit:dill) q.sage)]
  ::  the slog entries from the same span of time, each told as lines
  ;<  slogs=(list [da=@da blits=(list blit:dill)])  bind:m
    =/  ms  (fiber:fiber:nexus ,(list [da=@da blits=(list blit:dill)]))
    ?.  logs  (pure:ms ~)
    =/  lo=@da  da:(rear batches)
    =/  hi=@da  da:(head batches)
    =.  lo  (roll batches |=([[da=@da *] a=_lo] ?:((lth da a) da a)))
    =.  hi  (roll batches |=([[da=@da *] a=_hi] ?:((gth da a) da a)))
    =/  logs-road=road:tarball  [%& %& /sys/dill %'logs.dill-told']
    ;<  lres=(each (list [=cass:clay =sage:tarball]) tang)  bind:ms
      (peep:io logs-road [%date `lo `hi])
    ?:  ?=(%| -.lres)  (pure:ms ~)
    %-  pure:ms
    %+  murn  p.lres
    |=  [=cass:clay =sage:tarball]
    ^-  (unit [@da (list blit:dill)])
    =/  told=(unit told:dill)  (mole |.(!<(told:dill q.sage)))
    ?~  told  ~
    ::  the grub's seed is an empty crud: not a log line
    ?:  &(?=(%crud -.u.told) ?=(~ q.u.told))  ~
    =/  lines=(list tape)  (to-lines (format-told:tools u.told))
    :-  ~
    :-  da.cass
    %-  zing
    %+  turn  lines
    |=(l=tape `(list blit:dill)`~[[%put (tuba l)] [%nel ~]])
  ::  one scrollback: everything in time order
  =/  all=(list [da=@da blits=(list blit:dill)])
    %+  sort  (weld batches slogs)
    |=([a=[da=@da *] b=[da=@da *]] (lth da.a da.b))
  =/  all-blits=(list blit:dill)  (zing (turn all |=([* b=(list blit:dill)] b)))
  =/  rendered=@t  (render-blits:clurd all-blits wid)
  (pure:m [%text (crip "Terminal ({<session>}, versions {<range-from>}-{<range-to>} of {<cur-ver>}, {(a-co:co (lent slogs))} log entries):\0a{(trip rendered)}")])
::  +to-lines: a text on newlines (an empty trailing line dropped)
++  to-lines
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  acc=(list tape)
  |-  ^-  (list tape)
  ?~  t  (flop ?~(cur acc [(flop cur) acc]))
  ?:  =('\0a' i.t)  $(t t.t, acc [(flop cur) acc], cur ~)
  $(t t.t, cur [i.t cur])
--
