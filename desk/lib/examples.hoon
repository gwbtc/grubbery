|%
++  usergroup
  %-  crip
  """
  :-  /group
  =,  grubberyio
  ^-  base:g
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
  ?>  ?=([%sig ~] stud)
  (pour !>(!<((set @p) vase)))
  """
::
++  group-weir
  %-  crip
  """
  :-  /weir
  =,  grubberyio
  ^-  base:g
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
  ?>  ?=([%sig ~] stud)
  (pour !>(!<(weir:g vase)))
  """
::
++  file
  %-  crip
  """
  :-  /noun
  =,  grubberyio
  ^-  base:g
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
  (pour vase)
  """
::
++  counter-container
  %-  crip
  """
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
  """
::
++  counter
  %-  crip
  """
  /-  t  /add/two
  :-  /ud
  =,  grubberyio
  =/  m  (charm:base:g ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
  ?+    stud  !!
      [%counter %inc ~]
    ;<  a=@ud  bind:m  (get-state-as @ud)
    (pour !>(+(a)))
    ::
      [%counter %two ~]
    ;<  a=@ud  bind:m  (get-state-as @ud)
    (pour !>((two:t a)))
  ==
  """
::
++  is-even
  %-  crip
  """
  :-  /loob
  =,  grubberyio
  |=  =deps:stem:g
  ^-  vase
  =/  deps-list  ~(tap in ~(key by ~(tar of deps)))
  ?>  ?=(^ deps-list)
  =+  !<(=@ud (nead (need (~(get of deps) i.deps-list))))
  !>(=(0 (mod ud 2)))
  """
::
++  parity
  %-  crip
  """
  :-  /txt
  =,  grubberyio
  |=  =deps:stem:g
  ^-  vase
  =/  deps-list  ~(tap in ~(key by ~(tar of deps)))
  ~&  deps-list+deps-list
  ?>  ?=(^ deps-list)
  ~&  parity-vase+!<(? (nead (need (~(get of deps) i.deps-list))))
  ?:  !<(? (nead (need (~(get of deps) i.deps-list))))
    !>('true')
  !>('false')
  """
::
++  add-two
  %-  crip
  """
  |%
  ++  two  |=(a=@ud (add 2 a))
  --
  """
::
++  base-template
  %-  crip
  """
  :-  /noun
  =,  grubberyio
  ^-  base:g
  =/  m  (charm:base:g ,~)
  ^-  form:m
  done
  """
::
++  stem-template
  %-  crip
  """
  :-  /noun
  =,  grubberyio
  |=  =deps:stem:g
  ^-  vase
  =/  deps-list  ~(tap in ~(key by ~(tar of deps)))
  ?>  ?=(^ deps-list)
  (nead (need (~(get of deps) i.deps-list)))
  """
::
++  gui-con-base-template
  %-  crip
  """
  =,  grubberyio
  |=  [here=path =cone:g]
  ^-  manx
  =/  data=vase  (grab-data (need (~(get of cone) /)))
  ;div.flex.flex-col
    ;div: \{(spud here)}
    ;code.flex-grow:"*\{(render-tang-to-marl 80 (sell data) ~)}"
  ==
  """
::
++  gui-con-stem-template
  %-  crip
  """
  =,  grubberyio
  |=  [here=path =cone:g]
  ^-  manx
  =/  data=vase  (grab-data (need (~(get of cone) /)))
  ;div.flex.flex-col
    ;div: \{(spud here)}
    ;code.flex-grow:"*\{(render-tang-to-marl 80 (sell data) ~)}"
  ==
  """
::
++  gui-con-stud-template
  %-  crip
  """
  =,  grubberyio
  |=  =vase
  ^-  manx
  ;code.flex-grow:"*\{(render-tang-to-marl 80 (sell vase) ~)}"
  """
::
++  gui-con-mime-template
  %-  crip
  """
  =,  grubberyio
  |=  [here=path =cone:g]
  ^-  [@dr mime]
  =/  data=vase  (grab-data (need (~(get of cone) /)))
  :-  ~s0
  :-  /application/octet-stream
  (as-octs:mimes:html (jam q.data))
  """
::
++  gui-con-poke-template
  %-  crip
  """
  |=  args=(list (pair @t @t))
  ^-  pail:g
  [/sig !>(~)]
  """
::
++  gui-con-bump-template
  %-  crip
  """
  |=  args=(list (pair @t @t))
  ^-  pail:g
  [/sig !>(~)]
  """
::
++  javascript-mime-con
  %-  crip
  """
  =,  grubberyio
  |=  [here=path =cone:g]
  ^-  [@dr mime]
  =/  data=vase  (grab-data (need (~(get of cone) /)))
  :-  ~s0
  :-  /application/javascript
  (as-octs:mimes:html !<(@t data))
  """
--
