/<  tools  /lib/nex/tools.hoon
/<  s3t    /lib/nex/s3-tools.hoon
::  s3-download-directory: download all files under an S3 prefix to the ball
::
!:
^-  tool:tools
|%
++  name  's3_download_directory'
++  description  'Download all files under an S3 prefix to the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['s3_prefix' [%string 'S3 key prefix to download (e.g. "backups/mydir")']]
      ['path' [%string 'Ball directory path to save to (e.g. "/downloads")']]
  ==
++  required  ~['s3_prefix' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    %.  [%o args.st]
    %-  ot:dejs:format
    :~  ['s3_prefix' so:dejs:format]
        ['path' so:dejs:format]
    ==
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (s3_prefix, path)'])
  =/  [s3-prefix=@t dest-path=@t]  p.parsed
  =/  pax=path  (stab dest-path)
  ;<  creds=s3-creds:s3t  bind:m  read-s3-creds:s3t
  ;<  now=@da  bind:m  get-time:io
  =/  query-string=@t  (build-list-query:s3:s3t s3-prefix)
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3:s3t
      'GET'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      ''
      query-string
      ~
      now
    ==
  =/  url=@t  (build-url:s3:s3t endpoint.creds bucket.creds '' `query-string)
  =/  headers=(list [@t @t])  (build-headers:s3:s3t 'GET' payload-hash amz-date authorization)
  =/  =request:http  [%'GET' url headers ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  =/  body=@t
    ?+  client-response  ''
      [%finished * [~ [* [p=@ q=@]]]]
    ;;(@t q.data.u.full-file.client-response)
    ==
  =/  all-keys=(list @t)  (parse-list-response:s3:s3t body)
  =/  files=(list @t)
    %+  skip  all-keys
    |=(key=@t =((rear (trip key)) '/'))
  =/  downloaded=@ud  0
  |-
  ?~  files
    (pure:m [%text (crip "Downloaded {<downloaded>} files to {(trip dest-path)}")])
  =/  s3-key=@t  i.files
  =/  filename=@ta  (extract-filename:s3:s3t s3-key)
  =/  ext=(unit @ta)  (parse-extension:tarball filename)
  ;<  now=@da  bind:m  get-time:io
  =/  [ld-amz-date=@t ld-payload-hash=@t ld-authorization=@t]
    %:  build-signature:s3:s3t
      'GET'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      s3-key
      ''
      ~
      now
    ==
  =/  dl-url=@t  (build-url:s3:s3t endpoint.creds bucket.creds s3-key ~)
  =/  dl-headers=(list [@t @t])  (build-headers:s3:s3t 'GET' ld-payload-hash ld-amz-date ld-authorization)
  =/  dl-request=request:http  [%'GET' dl-url dl-headers ~]
  ;<  ~  bind:m  (send-request:io dl-request)
  ;<  dl-response=client-response:iris  bind:m  take-client-response:io
  ?.  ?=([%finished *] dl-response)
    $(files t.files)
  ?~  full-file.dl-response
    $(files t.files)
  =/  content=@t  ;;(@t q.data.u.full-file.dl-response)
  =/  response-headers=(list [key=@t value=@t])
    headers.response-header.dl-response
  =/  ct=(unit @t)  (extract-content-type:s3:s3t response-headers)
  =/  mtype=path  (determine-mime-type:tarball ct filename)
  =/  file-mime=mime  [mtype (as-octs:mimes:html content)]
  =/  road=road:tarball  [%& %& pax filename]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ;<  ~  bind:m  (over:io road [[/ %mime] file-mime])
    $(files t.files, downloaded +(downloaded))
  ;<  ~  bind:m  (make:io road |+[[[/ %mime] file-mime] (bind ext |=(e=@ta [/ e]))])
  $(files t.files, downloaded +(downloaded))
--
