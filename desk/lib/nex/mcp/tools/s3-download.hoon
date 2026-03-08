::  s3-download: download an S3 file to the grubbery ball
::
!:
^-  tool:tools
|%
++  name  's3_download'
++  description  'Download an S3 file to the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['s3_key' [%string 'S3 object key to download']]
      ['path' [%string 'Ball directory path to save to (e.g. "/downloads")']]
  ==
++  required  ~['s3_key' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  [s3-key=@t dest-path=@t]
    %.  [%o args.st]
    %-  ot:dejs:format
    :~  ['s3_key' so:dejs:format]
        ['path' so:dejs:format]
    ==
  =/  pax=path  (stab dest-path)
  ;<  creds=s3-creds:tools  bind:m  read-s3-creds:tools
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3:tools
      'GET'
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
  =/  headers=(list [@t @t])  (build-headers:s3:tools 'GET' payload-hash amz-date authorization)
  =/  =request:http  [%'GET' url headers ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=([%finished *] client-response)
    (pure:m [%error 'S3 download failed'])
  =/  code=@ud  status-code.response-header.client-response
  ?.  (lth code 300)
    (pure:m [%error (crip "S3 download error: HTTP {<code>}")])
  ?~  full-file.client-response
    (pure:m [%error 'Empty response from S3'])
  =/  content=@t  ;;(@t q.data.u.full-file.client-response)
  =/  filename=@ta  (extract-filename:s3:tools s3-key)
  =/  ext=(unit @ta)  (parse-extension:tarball filename)
  =/  response-headers=(list [key=@t value=@t])
    headers.response-header.client-response
  =/  ct=(unit @t)  (extract-content-type:s3:tools response-headers)
  =/  mtype=path  (determine-mime-type:tarball ct filename)
  =/  file-mime=mime  [mtype (as-octs:mimes:html content)]
  =/  road=road:tarball  [%& %& pax filename]
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?:  exists
    ;<  ~  bind:m  (over:io /write road mime+!>(file-mime))
    (pure:m [%text (crip "Downloaded s3://{(trip s3-key)} to {(trip dest-path)}/{(trip filename)}")])
  ;<  ~  bind:m  (make:io /write road |+[mime+!>(file-mime) ext])
  (pure:m [%text (crip "Downloaded s3://{(trip s3-key)} to {(trip dest-path)}/{(trip filename)}")])
--
