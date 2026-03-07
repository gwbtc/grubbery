::  s3-list: list files in S3 bucket
::
!:
^-  tool:tools
|%
++  name  's3_list'
++  description  'List files in S3 bucket'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['prefix' [%string 'S3 key prefix to filter by (optional)']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  prefix=@t
    ?~  pj=(~(get by args.st) 'prefix')  ''
    ?.  ?=([%s *] u.pj)  ''
    p.u.pj
  ;<  creds=s3-creds:tools  bind:m  read-s3-creds:tools
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  query-string=@t  (build-list-query:s3:tools prefix)
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3:tools
      'GET'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      ''
      query-string
      ~
      now.bowl
    ==
  =/  url=@t  (build-url:s3:tools endpoint.creds bucket.creds '' `query-string)
  =/  headers=(list [@t @t])  (build-headers:s3:tools 'GET' payload-hash amz-date authorization)
  =/  =request:http  [%'GET' url headers ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  =/  body=@t
    ?+  client-response  ''
      [%finished * [~ [* [p=@ q=@]]]]
    ;;(@t q.data.u.full-file.client-response)
    ==
  =/  keys=(list @t)  (parse-list-response:s3:tools body)
  ?~  keys
    (pure:m [%text 'No files found'])
  =/  result=tape
    %-  zing
    %+  turn  keys
    |=(k=@t "{(trip k)}\0a")
  (pure:m [%text (crip result)])
--
