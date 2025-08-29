::  user groups:
::  /grp/who/group-name  (set ship)  (i.e. who is in what usergroup?)
::  /grp/how/group-name  weir        (i.e. what can which usergroup do?)
::  /grp/pub             weir        (i.e. what can the public do?)
::
:-  /group
=,  grubberyio
^-  base:g
=/  m  (charm:base:g ,~)
^-  form:m
;<  [=stud:g =vase]  bind:m  get-poke-pail
?>  ?=([%sig ~] stud)
(pour !>(!<((set @p) vase)))
