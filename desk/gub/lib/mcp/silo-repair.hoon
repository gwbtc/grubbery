/<  tools  /lib/nex/tools.hoon
::  silo-repair: tomb audit-damaged versions in place, then re-audit
::
!:
^-  tool:tools
|%
++  name  'silo_repair'
++  description
  ^~  %-  crip
  ;:  weld
    "Repair the silo: tomb every version the audit reports as "
    "referenced-but-absent — in place, at the runtime level. Latest "
    "versions are never touched. Explicitly triggered, never "
    "automatic. Re-runs the audit afterward and returns it as the "
    "receipt (expect 0 remaining)."
  ==
++  parameters  ^-  (map @t parameter-def:tools)  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  ~  bind:m  (gall-poke-our:io %grubbery noun+%silo-repair)
  ;<  result=wain  bind:m  (typed-scry:io wain %txt /gx/grubbery/peek/audit/txt)
  =/  post=tape  (trip (of-wain:format result))
  (pure:m [%text (crip "repair complete; post-repair audit:\0a{post}")])
--
