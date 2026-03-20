::  edit-file: edit a text file in the grubbery ball via string replacement
::
!:
^-  tool:tools
|%
++  name  'edit_file'
++  description
  ^~  %-  crip
  ;:  weld
    "Edit a text file in the grubbery ball via exact string replacement. "
    "Fails if old_string is not found or is ambiguous (multiple matches). "
    "Works with any mark that has a text/mime conversion."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory path (e.g. "/")']]
      ['name' [%string 'Filename (e.g. "foo.hoon")']]
      ['old_string' [%string 'The exact text to find and replace']]
      ['new_string' [%string 'The replacement text']]
      ['replace_all' [%boolean 'Replace all occurrences (default: false)']]
  ==
++  required  ~['path' 'name' 'old_string' 'new_string']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  file-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  file-name=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  old-string=@t  (~(dog jo:json-utils [%o args.st]) /'old_string' so:dejs:format)
  =/  new-string=@t  (~(dog jo:json-utils [%o args.st]) /'new_string' so:dejs:format)
  =/  replace-all=?
    =/  ra  (~(get jo:json-utils [%o args.st]) /'replace_all')
    ?~  ra  %.n
    ?:  ?=([~ %b *] ra)  p.u.ra
    %.n
  =/  pax=path  (stab file-path)
  ::  Look up the grub
  ;<  [grub-name=@ta =seen:nexus]  bind:m
    (lookup-grub:tools pax file-name)
  ?.  ?=([%& %file *] seen)
    (pure:m [%error (crip "Not found: {(trip file-path)}/{(trip file-name)}")])
  =/  original-mark=@tas  p.cage.p.seen
  ::  Convert to text via mime
  ;<  =mime  bind:m  (cage-to-mime:io cage.p.seen)
  =/  txt=tape  (trip q.q.mime)
  ::  Do replacement
  =/  result=(each tape @tas)
    (tape-replace:tools txt (trip old-string) (trip new-string) replace-all)
  ?.  ?=(%& -.result)
    ?+  p.result
      (pure:m [%error 'Edit failed'])
        %not-found
      (pure:m [%error 'old_string not found in file'])
        %not-unique
      (pure:m [%error 'old_string matches multiple locations. Provide more context to make it unique, or set replace_all.'])
        %empty-search
      (pure:m [%error 'old_string cannot be empty'])
    ==
  ::  Send edited text back via %over — runtime handles mark conversion
  =/  new-mime=^mime  [/text/plain (as-octs:mimes:html (crip p.result))]
  =/  road=road:tarball  [%& %& pax grub-name]
  ;<  ~  bind:m  (over:io /edit road mime+!>(new-mime))
  (pure:m [%text (crip "Edited {(trip file-path)}/{(trip file-name)}")])
--
