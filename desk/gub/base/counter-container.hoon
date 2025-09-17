:-  /sig
=,  grubberyio
=/  m  (charm:base:g ,~)
^-  form:m
;<  [=stud:g =vase]  bind:m  get-poke-pail
;<  here=path        bind:m  get-here
?+    stud  !!
    [%sig ~]
  ;<  ~  bind:m  (overwrite-base |+[0 /counter] /counter `!>(10))
  =/  ie-vine=vine:stem:g  (~(put of *vine:stem:g) /counter |+[1 /counter])
  ;<  ~  bind:m  (overwrite-stem |+[0 /is-even] /is-even ie-vine)
  =/  pa-vine=vine:stem:g  (~(put of *vine:stem:g) /is-even |+[1 /is-even])
  ;<  ~  bind:m  (overwrite-stem |+[0 /parity] /parity pa-vine)
  done
==
