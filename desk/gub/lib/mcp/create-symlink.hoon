/<  tools  /lib/nex/tools.hoon
::  create-symlink: create a symlink in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'create_symlink'
++  description  'Create a symlink in the grubbery ball. Target is an absolute path like "/some/file" or a relative path like "^^/sibling".'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory to create the symlink in (e.g. "/")']]
      ['name' [%string 'Symlink name']]
      ['target' [%string 'Target path (e.g. "/some/path" for absolute, "^^/sibling" for relative)']]
  ==
++  required  ~['path' 'name' 'target']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t @t] tang)
    %-  mule  |.
    :+  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
      (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /target so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, name, target)'])
  =/  [link-path=@t link-name=@t target=@t]  p.parsed
  =/  sym=(unit symlink:tarball)  (parse-symlink:tarball target)
  ?~  sym
    (pure:m [%error (crip "Invalid symlink target: {(trip target)}")])
  ;<  ~  bind:m
    (make:io /symlink [%& %& (stab link-path) link-name] |+[%.n [[/ %symlink] !>(u.sym)] ~])
  (pure:m [%text (crip "Created symlink {(trip link-path)}/{(trip link-name)} -> {(trip target)}")])
--
