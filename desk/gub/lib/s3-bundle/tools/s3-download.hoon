/<  tools  /lib/tools.hoon
/<  s3t    /lib/s3-tools.hoon
::  s3-download: pull a path of a bucket into its mount
::
^-  tool:tools
|%
++  name  's3_download'
++  description  'Pull a path of a bucket into the namespace, at /apps/s3/mounts/<bucket>/<path>. A file path pulls one object; a folder path (ending in /) pulls everything under it. The path must be inside one of the bucket\'s mounts (see /apps/s3/mounts.json; mounts are made in the s3 nexus UI).'
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
    (call-s3:s3t (pairs:enjs:format ~[['op' s+'pull'] ['bucket' s+bucket] ['path' s+path]]))
  =/  failed=(list @t)  (jarr:s3t resp 'failed')
  %-  pure:m
  %+  render:s3t  resp
  %-  crip
  %+  weld  "Pulled {<(jnum:s3t resp 'pulled')>} into /apps/s3/mounts/{(trip bucket)}/{(trip path)}"
  ?~  failed  ""
  (weld "; failed: " (commas:s3t failed))
--
