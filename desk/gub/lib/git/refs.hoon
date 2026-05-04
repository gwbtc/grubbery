::  git refs: reference names and ref store
::
::  Ported from hoon-git.
::
/<  *  /lib/git/hash.hoon
/<  bytestream  /lib/bytestream.hoon
=>  |%
+$  refname  $+(refname (list @t))
+$  ref  $@(hash [%symref =refname])
+$  refs  $+(git-refs (axal ref))
::
--
|%
++  refspace
  |%
  ++  head  ['HEAD' ~]
  ++  branches  /refs/heads
  ++  tags  /refs/tags
  ++  remote  /refs/remotes
  ++  prefetch  /refs/prefetch
  --
++  has-pattern
  |=  =refname
  ^-  ?
  |-
  ?~  refname  |
  ?^  (find-byte:bytestream '*' 0+(as-octs:bytestream i.refname))
    &
  $(refname t.refname)
++  pattern-to-prefix
  |=  pat=refname
  ^-  refname
  =|  pix=refname
  |-
  ?~  pat  (flop pix)
  ?:  =('*' i.pat)
    (flop pix)
  =+  glob=(find-byte:bytestream '*' 0+(as-octs:bytestream i.pat))
  ?~  glob
    $(pat t.pat, pix [i.pat pix])
  (flop [(cut 3 [0 u.glob] i.pat) pix])
++  expand-ref-prefix
  |=  pix=refname
  ^-  (list refname)
  :~  pix
      (weld /refs pix)
      (weld /refs/tags pix)
      (weld /refs/heads pix)
      (weld /refs/remotes pix)
      :(weld /refs/remotes pix ['HEAD' ~])
  ==
++  print-ref
  |=  =ref
  ^-  tape
  ?@  ref
    (print-hash-sha-1 ref)
  "symref: {<refname.ref>}"
++  print-refname
  |=  =refname
  ^-  @t
  ?~  refname  %$
  =+  pri=i.refname
  =+  refname=t.refname
  |-
  ?~  refname  pri
  ?:  =(%$ i.refname)
    $(pri (cat 3 pri '/'), refname t.refname)
  %=  $
    refname  t.refname
    pri  :((cury cat 3) pri '/' i.refname)
  ==
++  parse-refname  refname:parse
++  parse-raw-refname  raw-refname:parse
++  parse-raw-pattern-refname  raw-pattern-refname:parse
++  parse-refname-ext  refname-ext:parse
::
++  parse
  |%
  ++  except
    ;~  pose
      col  wut
      sel  bas
      ket  sig
      ace  fas
    ==
  ++  char
    ;~  less
      except
      ;~(plug dot dot)
      ;~(plug pat kel)
      prn
    ==
  ++  segment
    %+  cook  crip
    ;~  plug
      ;~(less dot char)
      (star char)
    ==
  ++  refname
    ;~  less
      pat
      (more fas segment)
    ==
  ++  refname-ext  ;~(sfix refname (punt fas))
  ++  raw-refname
    %+  cook
      |=(a=tape ^-(@t (rap 3 a)))
    (star ;~(pose nud hig low hep dot sig cab fas))
  ++  raw-pattern-refname
    %+  cook
      |=(a=tape ^-(@t (rap 3 a)))
    (star ;~(pose nud hig low hep dot sig cab fas tar))
  --
++  refname-one-level  0x1
++  refname-pattern    0x2
::
++  has-flag
  |=  [lag=@uxD flags=@uxD]
  ^-  ?
  !=(0 (dis lag flags))
++  sane-refname
  |=  [=refname flags=@uxD]
  ^-  ?
  ?~  refname  |
  =+  rear=(rear refname)
  =+  last=(cut 3 [(dec (met 3 rear)) 1] rear)
  ?:  =('.' last)
    |
  ?:  ?&  !(has-flag refname-one-level flags)
          (lth (lent refname) 2)
      ==
    |
  &
--
