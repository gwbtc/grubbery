/<  tools  /lib/tools.hoon
::  set-gain: the retention policy of a path
::
::    gain on, every write is %firm: the history accumulates and a cull
::    leaves the record, so the path survives deletion as a ghost you
::    can still read. gain off, each write deletes the one it replaces
::    and a cull releases everything -- the path is gone for good.
::
::    So this is not "do I want history", it is "is a cull reversible".
::    Set it where the namespace holds the ONLY copy.
::
!:
=<  ^-  tool:tools
    |%
    ++  name  'set_gain'
    ++  description
      '''
      Set the retention policy (gain) of a path. gain=true: every write is
      kept, history accumulates, and a cull leaves the record so the path
      is still readable afterwards. gain=false: each write deletes the one
      it replaces and a cull releases everything. Recursive on a directory.
      Governs writes from here on; it is not retroactive.
      '''
    ++  parameters
      ^-  (map @t parameter-def:tools)
      %-  ~(gas by *(map @t parameter-def:tools))
      :~  ['path' [%string 'Directory or grub to set, e.g. "/docs" or "/docs/notes.md"']]
          ['gain' [%boolean 'true keeps history and survives a cull; false does not']]
      ==
    ++  required  ~['path' 'gain']
    ++  handler
      ^-  tool-handler:tools
      =/  m  (fiber:fiber:nexus ,tool-result:tools)
      ^-  form:m
      ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
      =/  parsed=(each [pax=@t flag=?] tang)
        %-  mule
        |.
        :-  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
        (~(dog jo:json-utils [%o args.st]) /gain bo:dejs:format)
      ?:  ?=(%| -.parsed)
        (pure:m [%error 'Missing or invalid arguments: path, gain'])
      =/  pax=@t    pax.p.parsed
      =/  flag=?    flag.p.parsed
      ::  a trailing slash means a directory; without one, decide by
      ::  looking -- a grub is a rail, a directory is a lane
      =/  t=tape  (trip pax)
      =/  slashed=?  &(!=(~ t) =('/' (rear t)))
      =/  clean=tape  ?:(slashed (snip t) t)
      =/  dir-pax=path  ?~(clean / (stab (crip clean)))
      ?~  dir-pax
        (pure:m [%error 'Cannot set gain on root: choose a path beneath it'])
      ;<  here-view=view:nexus  bind:m  (peek-shallow:io [%& %| dir-pax] ~)
      =/  is-dir=?  ?=([%ball *] here-view)
      =/  =lane:tarball
        ?:  is-dir  [%| dir-pax]
        [%& (snip `path`dir-pax) (rear dir-pax)]
      ;<  ~  bind:m  (gain:io [%& lane] flag)
      =/  what=tape  ?:(is-dir "directory (recursive)" "grub")
      =/  says=tape
        ?:  flag
          "kept: writes accumulate and a cull leaves the record"
        "not kept: each write replaces the last and a cull releases it"
      (pure:m [%text (crip "gain {<flag>} on {what} {(trip pax)} -- {says}")])
    --
::
|%
--
