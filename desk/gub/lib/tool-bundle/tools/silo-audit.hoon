/<  tools  /lib/tools.hoon
::  silo-audit: report referenced-but-absent silo content
::
!:
^-  tool:tools
|%
++  name  'silo_audit'
++  description
  ^~  %-  crip
  ;:  weld
    "Audit the silo: walk every version history and report "
    "referenced-but-absent content, one line per damaged version "
    "(path, version, LATEST flag, ject/noun, lobe). These are reads "
    "that will boom when touched — landmines left by refcount bugs. "
    "Read-only; repair is a separate, explicitly-triggered step."
  ==
++  parameters  ^-  (map @t parameter-def:tools)  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  result=wain  bind:m  (typed-scry:io wain %txt /gx/grubbery/peek/audit/txt)
  (pure:m [%text (of-wain:format result)])
--
