/+  *test, nexus, tarball, io=fiberio
::  +with-timeout abandons the peeks of a computation it gives up on: the
::  output of the step where the deadline fires carries a %stop-wire
::  poke for each one (gwbtc/grubbery#116).
::
=>
|%
+$  intake  intake:fiber:nexus
++  m  (fiber:fiber:nexus ,(unit view:nexus))
++  eny  `@uvJ`0v1
++  nonced  |=(base=wire (snoc base (scot %uv (end 5 eny))))
::  +answer: a poke from the bowl service, as the kernel delivers one
::
++  answer
  |=  [mak=@tas =vase]
  ^-  (unit intake)
  `[%poke `from:fiber:nexus`[0 [/sys %'bowl.sig']] [[/ mak] vase]]
::  +step: one input through a form and its %conts; the form to feed
::  next and the darts this input produced
::
++  step
  |=  [f=form:m in=(unit intake)]
  ^-  [form:m (list dart:nexus)]
  =|  darts=(list dart:nexus)
  |-
  =/  out  (f [!>(~) in])
  =.  darts  (weld darts darts.out)
  ?:  ?=(%cont -.next.out)  $(f self.next.out, in ~)
  ?>  ?=(?(%wait %skip) -.next.out)
  [f darts]
--
|%
++  test-with-timeout-stops-abandoned-peeks
  =/  road=road:tarball  [%& %& /sys/ames/ships/~zod/root/a %'b.json']
  =/  f=form:m
    ((with-timeout:io ,view:nexus) /t ~s20 (peek:io road ~))
  ::  every input the fiber waits on before its peek is out, in order
  ::  each bowl answer is followed by the ack of the request
  =/  ack  `(unit intake)``[%pack /sys/eny ~]
  =/  steps=(list (unit intake))
    :~  ~                                 :: start: wants entropy
        (answer %entropy !>(eny))  ack    :: get-time's nonce
        (answer %time !>(~2026.1.1))  ack :: get-time
        (answer %entropy !>(eny))  ack    :: set-timer's poke nonce
        `[%pack (nonced /poke) ~]         :: the timer is set
        (answer %entropy !>(eny))  ack    :: the peek's nonce
    ==
  =|  last=(list dart:nexus)
  |-
  ?^  steps
    =/  res  (step f i.steps)
    $(steps t.steps, f -.res, last +.res)
  =/  pw=wire  (nonced /peek)
  ::  the deadline fires
  =/  out  (f [!>(~) (answer %timer-wake !>(`wire`/timeout/t))])
  ;:  weld
    ::  the peek did go out
    %+  expect-eq  !>(%.y)
    !>((lien last |=(d=dart:nexus &(?=(%node -.d) =(pw wire.d)))))
  ::
    %+  expect-eq  !>(`*`[%done ~])
    !>(`*`next.out)
  ::
    %+  expect-eq  !>(`(list dart:nexus)`~[(stop-wire:io pw)])
    !>(darts.out)
  ==
--
