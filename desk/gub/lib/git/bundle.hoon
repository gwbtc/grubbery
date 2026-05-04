::  git bundle: bundle file format
::
::  Ported from hoon-git.
::
/<  bs  /lib/bytestream.hoon
/<  *  /lib/git/hash.hoon
/<  *  /lib/git/object.hoon
/<  *  /lib/git/refs.hoon
/<  git-pack  /lib/git/pack.hoon
|%
+$  bundle-header
  $:  version=$?(%2)
      hash=hash-algo
      need=(list hash)
      refs=(list [p=path q=hash])
  ==
+$  bundle  [header=bundle-header =pack:git-pack]
::
++  read
  |=  sea=bays:bs
  ^-  bundle
  =^  header  sea  (read-header sea)
  [header (read:git-pack sea)]
::
++  read-header
  |=  sea=bays:bs
  ^-  [bundle-header bays:bs]
  =^  line  sea  (read-line-maybe:bs sea)
  ?~  line
    ~|  "Git bundle is corrupted: signature absent"  !!
  =/  signature
    (cold %2 (jest '# v2 git bundle'))
  =+  sig=(rust (trip u.line) signature)
  ?~  sig
    ~|  "Git bundle is corrupted: invalid signature {(trip u.line)}"  !!
  =/  hal=hash-algo
    ?:  =(2 u.sig)  %sha-1
    !!
  =^  reqs=(list hash)  sea
    =|  reqs=(list hash)
    |-
    =/  [line=(unit @t) red=bays:bs]  (read-line-maybe:bs sea)
    ?~  line
      ~|  "Git bundle is corrupted: invalid header"  !!
    =/  hash=(unit hash)
      %+  rust  (trip u.line)
      %+  ifix  [hep (just '\0a')]
      ;~  sfix
        ^~  (parse-hash hal)
        (punt ;~(pfix ace (star prn)))
      ==
    ?~  hash
      [reqs sea]
    $(reqs [u.hash reqs], sea red)
  =^  refs=(list (pair refname hash))  sea
    =|  refs=(list (pair refname hash))
    |-
    =/  [line=(unit @t) red=bays:bs]  (read-line-maybe:bs sea)
    ?~  line
      ~|  "Git bundle is corrupted: invalid header"  !!
    =/  ref=(unit [=hash =refname])
      %+  rust  (trip u.line)
      ;~  plug
        ^~  (parse-hash hal)
        ;~(pfix ace parse-refname)
      ==
    ?~  ref
      [refs sea]
    $(refs [[refname.u.ref hash.u.ref] refs], sea red)
  =^  line  sea  (read-line-maybe:bs sea)
  ?~  line
    ~|  "Git bundle is corrupted: header not terminated"  !!
  ?:  (gth (met 3 u.line) 1)
    ~|  "Git bundle is corrupted: invalid header terminator"  !!
  :_  sea
  [u.sig hal reqs refs]
--
