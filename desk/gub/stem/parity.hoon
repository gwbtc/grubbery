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
