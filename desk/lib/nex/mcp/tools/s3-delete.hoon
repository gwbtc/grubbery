::  s3-delete: delete a file from S3
::
!:
^-  tool:tools
|%
++  name  's3_delete'
++  description  'Delete a file from S3'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['s3_key' [%string 'S3 object key to delete']]
  ==
++  required  ~['s3_key']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  s3-key=@t
    %.  [%o args.st]
    %-  ot:dejs:format
    :~  ['s3_key' so:dejs:format]
    ==
  ;<  creds=s3-creds:tools  bind:m  read-s3-creds:tools
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3:tools
      'DELETE'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      s3-key
      ''
      ~
      now.bowl
    ==
  =/  url=@t  (build-url:s3:tools endpoint.creds bucket.creds s3-key ~)
  =/  headers=(list [@t @t])  (build-headers:s3:tools 'DELETE' payload-hash amz-date authorization)
  =/  =request:http  [%'DELETE' url headers ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    (pure:m [%error 'S3 delete failed'])
  =/  code=@ud  status-code.response-header.client-response
  ?.  (lth code 300)
    (pure:m [%error (crip "S3 delete error: HTTP {<code>}")])
  (pure:m [%text (crip "Deleted s3://{(trip s3-key)}")])
--
