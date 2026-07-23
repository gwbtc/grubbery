::  git refspec: reference specifications
::
::  Ported from hoon-git.
::
/<  *  /lib/git/refs.hoon
=>  |%
+$  raw-refspec
  [opt=(unit @tD) src=@t dst=(unit @t)]
+$  refspec
  $:  force=_|
      negative=_|
      pattern=_|
      matching=_|
      hash=_|
      src=$~([%ref ~] $@(hash [%ref ref=refname]))
      dst=(unit refname)
  ==
--
|%
++  sane-refspec
  |=  [=refspec fetch=_|]
  &
++  map-refname
  |=  [=refspec ref=refname]
  ^-  (unit refname)
  ?.  pattern.refspec  ~
  ?@  src.refspec  ~
  =+  src=(pattern-to-prefix ref.src.refspec)
  =/  sub=(unit refname)
    |-
    ?~  src  `ref
    ?~  ref  `ref
    ?.  =(i.src i.ref)  ~
    $(src t.src, ref t.ref)
  ?~  sub  sub
  %-  some
  (weld (pattern-to-prefix (need dst.refspec)) u.sub)
++  ref-prefixes
  |=  [=refspec fetch=_|]
  ^-  (list refname)
  =,  refspec
  =/  base=(unit refname)
    ?:  |(hash negative)
      ~
    ?:  fetch
      `+.src
    ?:  ?=(^ dst)
      dst
    ?:  !hash
      `+.src
    ~
  ?~  base  ~
  ?:  pattern
    ~[(pattern-to-prefix u.base)]
  :~  u.base
      (weld /refs u.base)
      (weld /refs/heads u.base)
      (weld /refs/tags u.base)
  ==
++  parse-refspec  refspec:parse
++  parse-raw-refspec  raw-refspec:parse
++  raw-to-refspec
  |=  [raw=raw-refspec fetch=?]
  ^-  (unit refspec)
  =+  src=(scan (trip src.raw) refspec-src:parse)
  =/  dst=(unit refname)
    ?~  dst.raw  ~
    %-  some
    (scan (trip u.dst.raw) refspec-dst:parse)
  (to-refspec opt.raw src dst fetch)
++  to-refspec
  |=  $:  opt=(unit @t)
          src=$@(hash [%ref refname])
          dst=(unit refname)
          fetch=?
      ==
  ^-  (unit refspec)
  =/  force=?
    ?&(?=(^ opt) =('+' u.opt))
  =/  negative=?
    ?&(?=(^ opt) =('^' u.opt))
  =|  =refspec
  ?:  &(negative ?=(^ dst))
    ~|  "Invalid negative refspec"  ~
  ?:  ?&  !fetch
          ?=([%ref %$] src)
          ?=([~ %$] dst)
      ==
    `refspec(matching &)
  =|  dst-glob=_|
  =?  dst-glob  ?=(^ dst)
    (has-pattern u.dst)
  =/  src-glob=?
    ?@  src  |
    (has-pattern src)
  ?:  ?:  src-glob
        ?|  &(?=(^ dst) !dst-glob)
            &(?=(~ dst) !negative fetch)
        ==
      ?&  ?=(^ dst)
        dst-glob
      ==
    ~|  "Invalid wildcard refspec"  ~
  =/  pattern  |(src-glob dst-glob)
  =/  flags
    (con refname-one-level ?.(pattern 0 refname-pattern))
  =/  sane-src=?
    ?@  src  &
    (sane-refname +.src flags)
  ?:  ?&  negative
          ?|  ?=(~ src)
              ?=(hash src)
              !sane-src
          ==
      ==
    ~|  "Invalid negative refspec"  ~
  ?:  ?&  fetch
        ?|  &(!?=(~ src) !sane-src)
            &(?=(^ dst) !?=(~ u.dst) !(sane-refname u.dst flags))
        ==
      ==
      ~|  "Invalid fetch refspec"  ~
  ?:  ?&  !fetch
        ?|  &(pattern !sane-src)
            ?~  dst
              !sane-src
            !(sane-refname u.dst flags)
        ==
      ==
    ~|  "Invalid push refspec"  ~
  %-  some
  %=  refspec
    force  force
    negative  negative
    pattern  pattern
    hash  ?=(@ src)
    src  src
    dst  dst
  ==
++  parse
  |%
  ++  refspec-opt
    (punt ;~(pose lus ket))
  ++  refspec-src
    ;~  pose
      parse-hash-sha-1
      (stag %ref (cold ['HEAD' ~] pat))
      (stag %ref parse-refname)
    ==
  ++  refspec-dst  parse-refname
  ++  refspec
    |*  fetch=?
    %+  cook
      |=  $:  opt=(unit @t)
              src=$@(hash [%ref refname])
              dst=(unit refname)
          ==
      (need (to-refspec opt src dst fetch))
    ;~  plug
      refspec-opt
      refspec-src
      (punt ;~(pfix col refspec-dst))
    ==
  ++  raw-refspec
    ;~  plug
      (punt ;~(pose lus ket))
      ;~  pose
        pat
        parse-raw-pattern-refname
      ==
      (punt ;~(pfix col parse-raw-pattern-refname))
    ==
  --
--
