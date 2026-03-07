::  eval: evaluate a Hoon expression
::
!:
^-  tool:tools
|%
++  name  'eval'
++  description  'Evaluate a Hoon expression and return the result as text'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['hoon' [%string 'Any Hoon expression, e.g. "(add 2 2)"']]])
++  required  ~['hoon']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  code=@t  (~(dog jo:json-utils [%o args.st]) /hoon so:dejs:format)
  =/  res=(each vase tang)
    (mule |.((slap !>(..zuse) (ream code))))
  ?:  ?=(%| -.res)
    =/  lines=wall  (zing (turn (flop p.res) |=(=tank (wash [0 80] tank))))
    (pure:m [%error (crip "Eval failed:\0a{(of-wall:format lines)}")])
  =/  =tank  (sell p.res)
  =/  =wall  (wash [0 160] tank)
  (pure:m [%text (of-wain:format (turn wall crip))])
--
