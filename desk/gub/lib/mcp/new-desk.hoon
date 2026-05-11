/<  tools  /lib/nex/tools.hoon
::  new-desk: create a new desk with default provisions
::
!:
^-  tool:tools
|%
++  name  'new_desk'
++  description
  ^~  %-  crip
  ;:  weld
    "Create a new desk with a default agent, marks, and libraries. "
    "The desk will have a minimal Gall agent and standard imports "
    "(dbug, default-agent, skeleton, verb)."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['desk' [%string 'Name of the desk to create (e.g. "my-app")']]])
++  required  ~['desk']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: desk'])
  =/  desk=@t  p.parsed
  =/  dek=@tas  (slav %tas desk)
  ::  Scry default files from %base
  =/  base-paths=(list path)
    :~  /sys/kelvin
        /mar/bill/hoon
        /mar/hoon/hoon
        /mar/mime/hoon
        /mar/noun/hoon
        /mar/kelvin/hoon
        /lib/dbug/hoon
        /lib/default-agent/hoon
        /lib/verb/hoon
        /sur/verb/hoon
    ==
  =/  n  (fiber:fiber:nexus ,(list [path page:clay]))
  =/  fetch-files
    |=  paths=(list path)
    ^-  form:n
    ?~  paths  (pure:n ~)
    =/  pax=path  i.paths
    ;<  dat=noun  bind:n  (scry:io noun (weld /cx/base pax))
    ;<  rest=(list [path page:clay])  bind:n  $(paths t.paths)
    (pure:n [[pax (rear pax) dat] rest])
  ;<  base-files=(list [path page:clay])  bind:m
    (fetch-files base-paths)
  ::  Agent template from skeleton
  ;<  skel=noun  bind:m  (scry:io noun /cx/base/lib/skeleton/hoon)
  =/  files=(map path page:clay)
    %-  ~(gas by *(map path page:clay))
    [[/app/[dek]/hoon %hoon skel] base-files]
  ::  Create desk with new-desk:cloy
  ;<  ~  bind:m
    (send-card:io %pass /new-desk %arvo (new-desk:cloy dek ~ files))
  ::  Write desk.bill so the agent starts
  ;<  ~  bind:m
    %:  send-card:io
      %pass  /desk-bill  %arvo
      %c  %info  dek  %&  :~  [/desk/bill %ins bill+!>(~[dek])]
    ==  ==
  (pure:m [%text (crip "Created desk %{(trip dek)}")])
--
