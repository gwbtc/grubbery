::  run-spawn: trigger the reg-tester spawn flow via poke.
::
::  Pokes groundwire.groundwire/reg-tester.sig with a spawn action,
::  which mines a funding block, builds commit/reveal chains,
::  broadcasts them, and mines confirmation blocks.
::
/<  tools  /lib/nex/tools.hoon
!:
^-  tool:tools
|%
++  name  'run_spawn'
++  description
  ^~  %-  crip
  ;:  weld
    "Trigger the groundwire reg-tester spawn flow. Mines a funding block, "
    "builds 3 commit/reveal tx pairs, broadcasts them, and mines 8 "
    "confirmation blocks. Use probe_scan afterwards to find the reveal "
    "block, then probe_block stage=reveals to verify detection."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['sed' [%string 'Wallet seed (positive integer). Default 42.']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  arg-sed=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /sed so:dejs:format)
  =/  sed=@ud  ?~(arg-sed 42 (fall (rush u.arg-sed dem) 42))
  ::  build the poke json: {"action":"spawn","sed":N}
  =/  poke-json=json
    %-  pairs:enjs:format
    :~  ['action' [%s 'spawn']]
        ['sed' (numb:enjs:format sed)]
    ==
  ::  poke groundwire.groundwire/reg-tester.sig
  ;<  ~  bind:m
    %-  poke:io
    :*  (cord-to-road:tarball './groundwire.groundwire')
        [/ `@ta`'reg-tester.sig']
        !>(poke-json)
    ==
  (pure:m [%text (crip "spawn poke sent (sed={((d-co:co 1) sed)}). watch the walker — it'll mine funding + 100 maturity + reveals + 8 confirmation blocks.")])
--
