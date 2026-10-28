/<  tools  /lib/tools.hoon
::  dir-history: fold-hist entry count for a directory (structural
::  churn: makes+culls ever). Perf evidence tool — the fold hist gains
::  ~2 entries per lifecycle grub, so a requests dir's count is ~2x
::  the requests it ever served (see issues #48/#50).
::
!:
=<  ^-  tool:tools
    |%
    ++  name  'dir_history'
    ++  description  'Count fold-hist entries of a directory (structural changes ever: makes plus culls). For lifecycle-grub dirs this approximates 2x total requests ever served.'
    ++  parameters
      ^-  (map @t parameter-def:tools)
      %-  ~(gas by *(map @t parameter-def:tools))
      :~  ['path' [%string 'Directory path (e.g. "/sys/eyre/requests")']]
      ==
    ++  required  ~['path']
    ++  handler
      ^-  tool-handler:tools
      =/  m  (fiber:fiber:nexus ,tool-result:tools)
      ^-  form:m
      ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
      =/  parsed=(each @t tang)
        (mule |.((~(dog jo:json-utils [%o args.st]) /path so:dejs:format)))
      ?:  ?=(%| -.parsed)
        (pure:m [%error 'Missing or invalid argument: path'])
      =/  dir-pax=path
        =/  t=tape  (trip p.parsed)
        =/  clean=tape  ?:(&(!=(~ t) =('/' (rear t))) (snip t) t)
        ?~  clean  /
        (stab (crip clean))
      ;<  res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)  bind:m
        (born:io [%& %| dir-pax])
      ?:  ?=(%| -.res)
        (pure:m [%error (crip "no history: {<p.res>}")])
      =/  entries  p.res
      =/  total=@ud  (lent entries)
      =/  tombs=@ud
        (lent (skim entries |=([* * tomb=?] tomb)))
      =/  latest=tape
        ?~  entries  "none"
        =/  last  (rear `(list [=cass:clay tags=(set @t) tomb=?])`entries)
        <cass.last>
      %-  pure:m
      :-  %text
      %-  crip
      ;:  weld
        "fold hist for {<dir-pax>}:\0a"
        "  total entries (makes+culls ever): {<total>}\0a"
        "  tombstoned: {<tombs>}\0a"
        "  latest cass: {latest}"
      ==
    --
|%
--
