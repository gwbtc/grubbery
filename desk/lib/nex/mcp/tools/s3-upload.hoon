::  s3-upload: upload a single ball file to S3
::
!:
^-  tool:tools
|%
++  name  's3_upload'
++  description  'Upload a single ball file to S3'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Ball directory path (e.g. "/mydir")']]
      ['name' [%string 'Grub filename (e.g. "notes.txt")']]
      ['s3_key' [%string 'S3 object key (optional, defaults to filename)']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  [file-path=@t file-name=@t]
    %.  [%o args.st]
    %-  ot:dejs:format
    :~  ['path' so:dejs:format]
        ['name' so:dejs:format]
    ==
  =/  s3-key=@t
    ?~  sk=(~(get by args.st) 's3_key')  file-name
    ?.  ?=([%s *] u.sk)  file-name
    ?:  =('' p.u.sk)  file-name
    p.u.sk
  =/  pax=path  (stab file-path)
  ;<  [grub-name=@ta =seen:nexus]  bind:m
    (lookup-grub:tools pax file-name)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error (crip "Not found: {(trip file-path)}/{(trip file-name)}")])
  ;<  =mime  bind:m  (cage-to-mime:io cage.p.seen)
  =/  text=@t  ;;(@t q.q.mime)
  ;<  creds=s3-creds:tools  bind:m  read-s3-creds:tools
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
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
      now.bowl
    ==
  =/  url=@t  (build-url:s3:tools endpoint.creds bucket.creds s3-key ~)
  =/  headers=(list [@t @t])  (build-headers:s3:tools 'PUT' payload-hash amz-date authorization)
  =/  =request:http
    [%'PUT' url headers `(as-octs:mimes:html text)]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    (pure:m [%error 'S3 upload failed'])
  =/  code=@ud  status-code.response-header.client-response
  ?.  (lth code 300)
    (pure:m [%error (crip "S3 upload error: HTTP {<code>}")])
  (pure:m [%text (crip "Uploaded {(trip file-path)}/{(trip file-name)} to s3://{(trip s3-key)}")])
--
