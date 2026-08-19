/<  tools  /lib/nex/tools.hoon
::  scry-test: exercise the /sys/scry farm write service.
::
::  op %grow publishes a noun-page at the spur, %tomb retracts one
::  revision, %cull retracts the whole spur. Verify from dojo with
::    .^((list path) %gt /=grubbery=//1)
::
^-  tool:tools
|%
++  name  'scry_test'
++  description  'Test remote-scry farm writes: grow/tomb/cull a page at a spur'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['op' [%string 'One of: grow, tomb, cull, keen']]
      ['spur' [%string 'Farm spur to operate on, e.g. /test/hello']]
      ['value' [%string 'grow only: text to publish (as a noun page)']]
      ['case' [%string 'tomb only: revision number to tombstone']]
      ['ship' [%string 'keen only: ship whose farm to read, e.g. ~zod']]
      ['timeout' [%string 'keen only: seconds to wait before yawning (default 30)']]
  ==
++  required  ~['op' 'spur']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ::  render-page: mark plus the noun, shown as text when the noun is
  ::  a valid cord (the common case for farm pages), raw otherwise
  =/  render-page
    |=  pag=page
    ^-  @t
    =/  body=tape
      ?:  &(?=(@ q.pag) ((sane %t) q.pag))
        "'{(trip q.pag)}'"
      "{<q.pag>}"
    (crip "mark=%{(trip p.pag)} noun={body}")
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  jon=json  [%o args.st]
  =/  op=(unit @t)  (mole |.((~(dog jo:json-utils jon) /op so:dejs:format)))
  =/  spur-txt=(unit @t)  (mole |.((~(dog jo:json-utils jon) /spur so:dejs:format)))
  ?:  |(?=(~ op) ?=(~ spur-txt))
    (pure:m [%error 'op and spur are required'])
  =/  spur=(unit path)  (rush u.spur-txt ;~(pfix fas (more fas urs:ab)))
  ?~  spur  (pure:m [%error 'bad spur: want /seg/ments'])
  ?+    u.op  (pure:m [%error 'op must be grow, tomb, or cull'])
      %grow
    =/  val=@t
      %+  fall
        (mole |.((~(dog jo:json-utils jon) /value so:dejs:format)))
      'hello from the farm'
    ;<  ~  bind:m  (grow:io u.spur noun+val)
    (pure:m [%text (crip "grew {(spud u.spur)}")])
  ::
      %tomb
    =/  case-txt=(unit @t)  (mole |.((~(dog jo:json-utils jon) /case so:dejs:format)))
    =/  case=(unit @ud)  ?~(case-txt ~ (rush u.case-txt dem))
    ?~  case  (pure:m [%error 'tomb needs a numeric case'])
    ;<  ~  bind:m  (tomb:io u.case u.spur)
    (pure:m [%text (crip "tombed case {(scow %ud u.case)} at {(spud u.spur)}")])
  ::
      %cull
    ;<  ~  bind:m  (cull-farm:io u.spur)
    (pure:m [%text (crip "culled {(spud u.spur)}")])
  ::
      %keen
    ::  read [spur] from [ship]'s grubbery farm over remote scry.
    ::  case names the bound revision (remote scry is immutable; no
    ::  "latest"), default 1. Timeout yawns the abandoned request.
    =/  ship-txt=(unit @t)  (mole |.((~(dog jo:json-utils jon) /ship so:dejs:format)))
    =/  who=(unit @p)  (biff ship-txt (cury slaw %p))
    ?~  who  (pure:m [%error 'keen needs a ship, e.g. ~zod'])
    =/  cas=@ta
      %+  fall
        (mole |.((~(dog jo:json-utils jon) /case so:dejs:format)))
      '1'
    =/  kpath=path  (weld /g/x/[cas]/grubbery `path`[%$ '1' u.spur])
    =/  secs=@ud
      %+  fall
        %+  biff
          (mole |.((~(dog jo:json-utils jon) /timeout so:dejs:format)))
        |=(t=@t (rush t dem))
      30
    ;<  res=(unit (unit page))  bind:m
      %+  (with-timeout:io ,(unit page))  (mul secs ~s1)
      (keen:io u.who kpath)
    ?~  res
      ;<  ~  bind:m  (yawn:io u.who kpath)
      (pure:m [%error (crip "keen timed out after {(scow %ud secs)}s (request yawned)")])
    ?~  u.res
      (pure:m [%text 'remote bound nothing at that path'])
    (pure:m [%text (render-page u.u.res)])
  ::
      %keen-raw
    ::  keen an arbitrary full remote-scry path (spur = the raw path,
    ::  e.g. /c/x/1/kids/sys/kelvin). Bisects our pipeline against
    ::  known-servable vanes like clay.
    =/  ship-txt=(unit @t)  (mole |.((~(dog jo:json-utils jon) /ship so:dejs:format)))
    =/  who=(unit @p)  (biff ship-txt (cury slaw %p))
    ?~  who  (pure:m [%error 'keen-raw needs a ship'])
    ;<  res=(unit (unit page))  bind:m
      %+  (with-timeout:io ,(unit page))  ~s30
      (keen:io u.who u.spur)
    ?~  res
      ;<  ~  bind:m  (yawn:io u.who u.spur)
      (pure:m [%error 'keen-raw timed out after 30s (request yawned)'])
    ?~  u.res
      (pure:m [%text 'remote bound nothing at that path'])
    (pure:m [%text (render-page u.u.res)])
  ==
--
