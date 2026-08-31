/<  tools  /lib/tools.hoon
::  gcal-feeds: manage the named map of external ICS feed urls
::
::  Stored as a json grub at /apps/calendar.calendar/gcal-feeds.json
::  (calendar state lives with the calendar):
::  {"main": "https://calendar.google.com/calendar/ical/.../basic.ics"}
::  Secret addresses are capability urls — they stay in this grub
::  and never belong in git.
::
^-  tool:tools
|%
++  name  'gcal_feeds'
++  description
  ^~  %-  crip
  ;:  weld
    "Manage named external calendar ICS feed urls (e.g. Google "
    "Calendar secret addresses). action=list shows feeds; "
    "action=add stores name+url; action=del removes by name. "
    "Read events from a feed with gcal_read."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['action' [%string 'list | add | del']]
      ['name' [%string 'Feed name (for add/del)']]
      ['url' [%string 'ICS url (for add)']]
  ==
++  required  ~['action']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  gs
    |=  k=@t
    ^-  @t
    =/  j=(unit json)  (~(get by args.st) k)
    ?~  j  ''
    ?.  ?=(%s -.u.j)  ''
    p.u.j
  =/  road=road:tarball  [%& %& /apps/[%'calendar.calendar'] %'gcal-feeds.json']
  ;<  =view:nexus  bind:m  (peek:io road ~)
  =/  feeds=(map @t json)
    ?.  ?=([%file *] view)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
    ?.(?=(%o -.j) ~ p.j)
  =/  act=@t  (gs 'action')
  ?:  =('list' act)
    ?:  =(~ feeds)  (pure:m [%text 'No feeds. Add one with action=add.'])
    =/  out=tape
      %-  zing
      %+  turn  ~(tap by feeds)
      |=  [n=@t v=json]
      "{(trip n)}: {?:(?=(%s -.v) (trip p.v) "?")}\0a"
    (pure:m [%text (crip out)])
  ?:  =('add' act)
    ?:  |(=('' (gs 'name')) =('' (gs 'url')))
      (pure:m [%error 'add needs name and url'])
    =/  jon=json  [%o (~(put by feeds) (gs 'name') s+(gs 'url'))]
    ;<  ~  bind:m  (over:io road [[/ %json] jon])
    (pure:m [%text (crip "Feed '{(trip (gs 'name'))}' saved")])
  ?:  =('del' act)
    ?:  =('' (gs 'name'))  (pure:m [%error 'del needs name'])
    =/  jon=json  [%o (~(del by feeds) (gs 'name'))]
    ;<  ~  bind:m  (over:io road [[/ %json] jon])
    (pure:m [%text (crip "Feed '{(trip (gs 'name'))}' removed")])
  (pure:m [%error 'action must be list, add, or del'])
--
