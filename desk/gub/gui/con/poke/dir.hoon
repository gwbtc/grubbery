|=  args=(list (pair @t @t))
^-  pail:g
=/  poke=@t  (need (get-header:http 'poke' args))
?+    poke  !!
    %toggle-hidden
  :-  /dir/poke
  !>([%toggle-hidden ~])
  ::
    %create-symlink
  =/  type=@t  (need (get-header:http 'type' args))
  ?+    type  !!
      %absolute
    :-  /dir/poke  !>
    :-  %create-symlink
    &+(rash (need (get-header:http 'path' args)) stap)
    ::
      %relative
    =/  =path  (rash (need (get-header:http 'path' args)) stap)
    =/  =@ud  (slav %ud (need (get-header:http 'numb' args)))
    [/dir/poke !>([%create-symlink |+[ud path]])]
  ==
  ::
    %create-subdir
  :-  /dir/poke
  !>([%create-subdir (need (get-header:http 'name' args))])
==
