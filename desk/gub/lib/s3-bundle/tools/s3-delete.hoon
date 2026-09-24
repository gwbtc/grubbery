/<  tools  /lib/tools.hoon
/<  s3t    /lib/s3-tools.hoon
::  s3-delete: delete one object from the bucket
::
^-  tool:tools
|%
++  name  's3_delete'
++  description  'Delete one object from a bucket (by its local name). Nothing in the namespace changes: a mirrored copy in a mount stays until you delete it there.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['bucket' [%string 'The bucket, by its local name.']]
      ['s3_key' [%string 'The object key to delete.']]
  ==
++  required  ~['bucket' 's3_key']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  bucket=@t  (arg:s3t args.st 'bucket')
  =/  key=@t  (arg:s3t args.st 's3_key')
  ?:  |(=('' bucket) =('' key))
    (pure:m [%error 'Missing required arguments (bucket, s3_key)'])
  ;<  resp=json  bind:m
    (call-s3:s3t (pairs:enjs:format ~[['op' s+'delete'] ['bucket' s+bucket] ['key' s+key]]))
  =/  ok=?
    =/  v  ?.(?=([%o *] resp) ~ (~(get by p.resp) 'ok'))
    ?=([~ %b %.y] v)
  %-  pure:m
  ?.  ok
    ?:  =('' (jstr:s3t resp 'error'))
      [%error (crip "Delete refused: HTTP {<(jnum:s3t resp 'code')>}")]
    (render:s3t resp '')
  (render:s3t resp (crip "Deleted s3://{(trip key)}"))
--
