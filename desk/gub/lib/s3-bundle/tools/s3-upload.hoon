/<  tools  /lib/tools.hoon
/<  s3t    /lib/s3-tools.hoon
::  s3-upload: push a path of a mount up to its bucket
::
^-  tool:tools
|%
++  name  's3_upload'
++  description  'Push a path from the namespace up to a bucket: /apps/s3/mounts/<bucket>/<path> becomes the object(s) at that path. A file path pushes one object; a folder path (ending in /) pushes everything under it. The path must be inside one of the bucket\'s mounts; put a file in a mount first (copy_grub) to upload it.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['bucket' [%string 'The bucket, by its local name.']]
      ['path' [%string 'The object key, or a folder prefix ending in /. Empty for the whole bucket.']]
  ==
++  required  ~['bucket' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  bucket=@t  (arg:s3t args.st 'bucket')
  =/  path=@t    (arg:s3t args.st 'path')
  ?:  =('' bucket)
    (pure:m [%error 'Missing required argument: bucket'])
  ;<  resp=json  bind:m
    (call-s3:s3t (pairs:enjs:format ~[['op' s+'push'] ['bucket' s+bucket] ['path' s+path]]))
  =/  failed=(list @t)  (jarr:s3t resp 'failed')
  %-  pure:m
  %+  render:s3t  resp
  %-  crip
  %+  weld  "Pushed {<(jnum:s3t resp 'pushed')>} to {(trip bucket)}:{(trip path)}"
  ?~  failed  ""
  (weld "; failed: " (commas:s3t failed))
--
