::  scry: read data from a vane or agent
::
!:
^-  tool:tools
|%
++  name  'scry'
++  description
  ^~  %-  crip
  ;:  weld
    "Run a scry (read) to retrieve data from a vane or agent. "
    "Path format: /[vane letter][care]/[desk-or-agent]/[rest...]/[mark]. "
    "The return type will always be JSON, and the read will fail if "
    "there is no mark conversion from the endpoint's mark to JSON. "
    "Examples: /gx/hood/kiln/pikes/json, /cx/base/sys/kelvin"
    "Supported marks: json, txt, hoon, mime."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  :-  'path'
      :-  %string
      ^~  %-  crip
      ;:  weld
        "The scry path (e.g. /gx/hood/kiln/pikes/json "
        "or /cx/base/sys/kelvin)"
      ==
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  path-text=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  pax=path  (stab path-text)
  =/  mark=@tas  (rear pax)
  ?+  mark
    (pure:m [%error (crip "Unsupported scry mark: %{(trip mark)}. Use /json, /txt, /hoon, or /mime.")])
      %json
    ;<  result=json  bind:m  (do-scry:io json /scry pax)
    (pure:m [%text (en:json:html result)])
      %txt
    ;<  result=wain  bind:m  (do-scry:io wain /scry pax)
    (pure:m [%text (of-wain:format result)])
      %hoon
    ;<  result=@t  bind:m  (do-scry:io @t /scry pax)
    (pure:m [%text result])
      %mime
    ;<  result=mime  bind:m  (do-scry:io mime /scry pax)
    (pure:m [%text (crip (trip q.q.result))])
  ==
--
