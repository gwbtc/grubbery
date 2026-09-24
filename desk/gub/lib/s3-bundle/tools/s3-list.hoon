/<  tools  /lib/tools.hoon
/<  s3t    /lib/s3-tools.hoon
::  s3-list: the object keys of the bucket under a prefix
::
^-  tool:tools
|%
++  name  's3_list'
++  description  'List the object keys in a bucket, one per line. Runs as a call on the s3 nexus (/apps/s3), which holds the credentials; bucket is the local name it was added under (see /apps/s3/config.json). Keys ending in / are directory markers.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['bucket' [%string 'The bucket, by its local name.']]
      ['prefix' [%string 'Only keys starting with this prefix. Default: the whole bucket.']]
  ==
++  required  ~['bucket']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  bucket=@t  (arg:s3t args.st 'bucket')
  =/  prefix=@t  (arg:s3t args.st 'prefix')
  ?:  =('' bucket)
    (pure:m [%error 'Missing required argument: bucket'])
  ;<  resp=json  bind:m
    (call-s3:s3t (pairs:enjs:format ~[['op' s+'list'] ['bucket' s+bucket] ['prefix' s+prefix]]))
  =/  keys=(list @t)  (jarr:s3t resp 'keys')
  %-  pure:m
  %+  render:s3t  resp
  ?~  keys  'No objects found'
  (crip (zing (turn keys |=(k=@t "{(trip k)}\0a"))))
--
