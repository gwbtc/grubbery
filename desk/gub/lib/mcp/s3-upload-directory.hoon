/<  tools  /lib/nex/tools.hoon
::  s3-upload-directory: upload a ball directory to S3
::
!:
^-  tool:tools
|%
++  name  's3_upload_directory'
++  description  'Upload a ball directory to S3'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Ball directory path (e.g. "/mydir")']]
      ['s3_prefix' [%string 'S3 key prefix (e.g. "backups/mydir")']]
  ==
++  required  ~['path' 's3_prefix']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    %.  [%o args.st]
    %-  ot:dejs:format
    :~  ['path' so:dejs:format]
        ['s3_prefix' so:dejs:format]
    ==
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, s3_prefix)'])
  =/  [dir-path=@t s3-prefix=@t]  p.parsed
  =/  pax=path  (stab dir-path)
  ;<  =view:nexus  bind:m  (peek:io [%& %| pax] ~)
  ?.  ?=([%ball *] view)
    (pure:m [%error (crip "Directory not found: {(trip dir-path)}")])
  =/  files-to-upload=(list [path @ta])
    %+  turn  (collect-files-recursive:s3:tools ball.view ~)
    |=([p=path n=@ta] [(weld pax p) n])
  =/  uploaded=@ud  0
  |-
  ?~  files-to-upload
    (pure:m [%text (crip "Uploaded {<uploaded>} files to s3://{(trip s3-prefix)}")])
  =/  [file-path=path filename=@ta]  i.files-to-upload
  ;<  file-view=view:nexus  bind:m
    (peek:io [%& %& file-path filename] ~)
  ?.  ?=([%file *] file-view)
    $(files-to-upload t.files-to-upload)
  ;<  =mime  bind:m  (sage-to-mime:io (need-sage:tarball sang.file-view))
  =/  text=@t  ;;(@t q.q.mime)
  =/  full-name=@ta  filename
  =/  relative-path=path
    ?:  =(pax ~)  (snoc file-path full-name)
    (snoc (slag (lent pax) file-path) full-name)
  =/  s3-key=@t
    ?:  =(s3-prefix '')
      (path-to-s3-key:s3:tools relative-path)
    (crip "{(trip s3-prefix)}/{(trip (path-to-s3-key:s3:tools relative-path))}")
  ;<  creds=s3-creds:tools  bind:m  read-s3-creds:tools
  ;<  now=@da  bind:m  get-time:io
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3:tools
      'PUT'
      access-key.creds
      secret-key.creds
      region.creds
      endpoint.creds
      bucket.creds
      s3-key
      ''
      `text
      now
    ==
  =/  url=@t  (build-url:s3:tools endpoint.creds bucket.creds s3-key ~)
  =/  headers=(list [@t @t])  (build-headers:s3:tools 'PUT' payload-hash amz-date authorization)
  =/  =request:http
    [%'PUT' url headers `(as-octs:mimes:html text)]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  $(files-to-upload t.files-to-upload, uploaded +(uploaded))
--
