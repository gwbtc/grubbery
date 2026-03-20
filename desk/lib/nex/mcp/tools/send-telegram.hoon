::  send-telegram: send a Telegram message via bot API
::
!:
^-  tool:tools
|%
++  name  'send_telegram'
++  description  'Send a Telegram message. Requires config/creds/telegram with bot-token and chat-id.'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['message' [%string 'Message to send']]])
++  required  ~['message']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  message=@t  (~(dog jo:json-utils [%o args.st]) /message so:dejs:format)
  ::  Read telegram config from ball
  ;<  creds-seen=seen:nexus  bind:m
    (peek:io /creds [%& %& /config/creds 'telegram'] ~)
  ?.  ?=([%& %file *] creds-seen)
    (pure:m [%error 'Telegram credentials not configured. Create config/creds/telegram with bot-token and chat-id.'])
  =/  jon=json  !<(json q.cage.p.creds-seen)
  =/  bot-token=@t  (~(dog jo:json-utils jon) /bot-token so:dejs:format)
  =/  chat-id=@t  (~(dog jo:json-utils jon) /chat-id so:dejs:format)
  ::  POST to Telegram Bot API
  =/  url=@t
    (crip "{(trip 'https://api.telegram.org/bot')}{(trip bot-token)}/sendMessage")
  =/  body=@t
    (rap 3 ~['chat_id=' chat-id '&text=' message])
  =/  =request:http
    :*  %'POST'
        url
        ~[['content-type' 'application/x-www-form-urlencoded']]
        `(as-octs:mimes:html body)
    ==
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    (pure:m [%error 'Telegram request failed'])
  =/  code=@ud  status-code.response-header.client-response
  ?.  =(200 code)
    (pure:m [%error (crip "Telegram API error: HTTP {<code>}")])
  (pure:m [%text 'Telegram message sent'])
--
