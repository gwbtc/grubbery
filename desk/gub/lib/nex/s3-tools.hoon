/<  s3  /lib/s3.hoon
|%
+$  s3-creds
  $:  access-key=@t
      secret-key=@t
      region=@t
      endpoint=@t
      bucket=@t
  ==
++  read-s3-creds
  =/  m  (fiber:fiber:nexus ,s3-creds)
  ^-  form:m
  ;<  creds-view=view:nexus  bind:m
    (peek:io [%& %& /'mcp.mcp' %'s3.json'] `[/ %json])
  ?.  ?=([%file *] creds-view)
    ~|  %s3-creds-not-found
    !!
  =/  jon=json  !<(json (need-vase:tarball sang.creds-view))
  =/  creds=s3-creds
    %.  jon
    %-  ot:dejs:format
    :~  ['access-key' so:dejs:format]
        ['secret-key' so:dejs:format]
        ['region' so:dejs:format]
        ['endpoint' so:dejs:format]
        ['bucket' so:dejs:format]
    ==
  (pure:m creds)
--
