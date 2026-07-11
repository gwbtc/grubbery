::  usergroups-registry: maps grub rails to authorized path prefixes
::
|_  reg=(map rail:tarball path)
++  grab
  |%
  ++  noun  ,(map rail:tarball path)
  --
++  grow
  |%
  ++  noun  reg
  ++  mime
    =/  entries=(list [rail:tarball path])  ~(tap by reg)
    =/  lines=(list tape)
      %+  turn  entries
      |=  [=rail:tarball pax=path]
      "{(spud path.rail)}/{(trip name.rail)} -> {(spud pax)}"
    =/  txt=tape
      ?~  lines  "(empty)"
      (zing (join "\0a" lines))
    [/text/plain (as-octs:mimes:html (crip txt))]
  --
--
