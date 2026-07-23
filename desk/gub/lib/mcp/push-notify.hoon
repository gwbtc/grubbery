/<  tools  /lib/nex/tools.hoon
::  push-notify: send a web push notification to subscribed devices
::
::  Broadcasts to every stored push subscription (each browser/device
::  that enabled notifications registers one). No connection selection
::  needed — stale subscriptions self-prune on 404/410.
::
^-  tool:tools
|%
++  name  'push_notify'
++  description
  ^~  %-  crip
  ;:  weld
    "Send a web push notification to all of the user's subscribed "
    "browsers/devices. title is required; body, url (opened on tap), "
    "and tag (replaces earlier notifications with the same tag) are "
    "optional."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['title' [%string 'Notification title']]
      ['body' [%string 'Notification body text']]
      ['url' [%string 'Optional url to open when tapped']]
      ['tag' [%string 'Optional tag; a later send with the same tag replaces it']]
  ==
++  required  ~['title']
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
  ?:  =('' (gs 'title'))
    (pure:m [%error 'title required'])
  ;<  ~  bind:m
    %-  send-push:io
    :^  ~  ~  ~
    :*  (gs 'title')
        (gs 'body')
        ~
        ?:(=('' (gs 'url')) ~ `(gs 'url'))
        ?:(=('' (gs 'tag')) ~ `(gs 'tag'))
    ==
  (pure:m [%text 'Notification sent to all subscribed devices'])
--
