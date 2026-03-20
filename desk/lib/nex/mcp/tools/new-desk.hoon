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
  =/  desk=@t  (~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)
  =/  dek=@tas  (slav %tas desk)
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  ::  Scry default files from %base
  =/  our=@p  our.bowl
  =/  now=@da  now.bowl
  =/  scry-base
    |=  =path
    ^-  [^path page:clay]
    :-  path
    :-  (rear path)
    .^(noun %cx (scot %p our) %base (scot %da now) path)
  =/  files=(map path page:clay)
    %-  ~(gas by *(map path page:clay))
    %+  welp
      ::  Agent template
      :~  :-  /app/[dek]/hoon
          :-  %hoon
          .^(noun %cx (scot %p our) %base (scot %da now) /lib/skeleton/hoon)
      ==
    %+  turn
      ^-  (list path)
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
    scry-base
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
