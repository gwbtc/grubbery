:-  /sig
=,  grubberyio
=/  m  (charm:base:g ,~)
^-  form:m
;<  [=stud:g =vase]  bind:m  get-poke-pail
;<  here=path        bind:m  get-here
?+    stud  !!
    [%sig ~]
  =/  counter=path  (weld here /counter)
  =/  is-even=path  (weld here /is-even)
  =/  parity=path   (weld here /parity)
  ;<  ~  bind:m  (overwrite-base counter /counter `!>(10))
  =/  ie-vine=vine:stem:g  (~(put of *vine:stem:g) /counter &+counter)
  ;<  ~  bind:m  (overwrite-stem is-even /is-even ie-vine)
  =/  pa-vine=vine:stem:g  (~(put of *vine:stem:g) /is-even &+is-even)
  ;<  ~  bind:m  (overwrite-stem parity /parity pa-vine)
  done
==
