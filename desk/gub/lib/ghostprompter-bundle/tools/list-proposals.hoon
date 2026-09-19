/<  tools  /lib/tools.hoon
::  list_proposals: what is already on the dashboard, so the agent
::  doesn't re-propose the same idea twice.
::
!:
^-  tool:tools
|%
++  name  'list_proposals'
++  description  'List the proposals already on the dashboard (kind, why, first line of draft) so you never duplicate one.'
++  parameters  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| /apps/ghostprompter/proposals] ~)
  =/  entries
    ?.  ?=([%ball *] dv)  ~
    ?~  fil.ball.dv  ~
    ~(tap by contents.u.fil.ball.dv)
  ?~  entries  (pure:m [%text 'No proposals on the dashboard.'])
  =/  lines=(list tape)
    %+  murn  entries
    |=  [nm=@ta ent=[=sang:tarball *]]
    ^-  (unit tape)
    =/  jon=(unit json)  (mole |.(;;(json (sang-noun:tarball sang.ent))))
    ?.  ?&(?=(^ jon) ?=([%o *] u.jon))  ~
    =/  jstr
      |=  key=@t
      ^-  tape
      =/  v  (~(get by p.u.jon) key)
      ?:(?=([~ %s *] v) (trip p.u.v) "")
    =/  draft=tape  (jstr 'draft')
    =/  first  ?:((lte (lent draft) 80) draft (weld (scag 80 draft) "..."))
    `"{(trip nm)} [{(jstr 'kind')}] {(jstr 'why')} — {first}\0a"
  (pure:m [%text (crip (zing lines))])
--
