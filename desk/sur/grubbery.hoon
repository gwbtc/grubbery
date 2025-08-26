|%
+$  stud  path
+$  pail  (pair stud vase)
+$  card  card:agent:gall
+$  make
  $%  [%base base=path data=(unit vase)]
      [%stem stem=path =vine:stem]
  ==
::
+$  deed  ?(%make %oust %cull %sand %poke %bump %kill %peek)
::
+$  perm
  $:  make=(set path) :: %make or %oust (%sand ?)
      poke=(set path) :: %poke, %bump or %kill
      peek=(set path)
  ==
::
+$  sand  (axal perm)
:: effects that a base grub can emit
::
+$  dart
  $%  [%grub =wire =road =load]
      [%perk =wire =pail]       :: updates to the poker
      [%sysc =card:agent:gall]
      [%scry =wire =mold =path]
  ==
:: dart payload
::
+$  load
  $%  [%make =make]
      [%oust ~]
      [%cull ~]
      [%sand perm=(unit perm)]
      [%poke =pail]
      [%bump pid=@ta =pail]
      [%kill pid=(unit @ta)]
      [%peek ~]
  ==
::
+$  grub
  $%  [%base data=vase base=path]
      [%stem data=(each vase tang) =vine:stem stem=path]
  ==
::
+$  bend  (pair @ud path)   :: relative path
+$  road  (each path bend)  :: absolute or relative path
+$  prov  [src=@p sap=path] :: external provenance
:: [%| ~zod /gall/...]                    - from outside grubbery
:: [%& ~ %& /some/absolute/path]          - absolute path from inside grubbery
:: [%& ~ %| &+2 /relative/path/to/source] - relative path in peek sandbox
:: [%& ~]                                 - out of peek sandbox
::
+$  from  (each path prov)
+$  take  [[here=path pid=@ta] take:base]
::
+$  proc
  $:  =proc:base
      =poke            :: keep initial poke
      next=cute:base   :: queue of held inputs
      skip=cute:base   :: queue of skipped inputs
  ==
::
+$  cone  (axal grub)
+$  give  [=from =wire]
+$  poke  [=give pail=(unit pail)] :: null poke means on-load
+$  tack
  $:  last=[step=@da poke=@da]
      sinx=(set path)
      tidy=?
      sour=(map path @da)
      boar=(unit @ta)          :: who is hogging the pipes
      temp=(axal vase)         :: persist shared "transient" state
      proc=(map @ta proc)
  ==
+$  trac  (axal tack)
:: NOTE: the distinction between cone and trac exists because
::       it is not yet clear what information should be available
::       on peek. Sinx being in tack also makes dependencies
::       more ergonomic (for now) in the case where a source
::       is deleted and then recreated or replaced
::
+$  bindings  (map (list @t) path) :: eyre bindings
:: time ordered latest changes
::
+$  history   ((mop @da path) gth)
++  hon       ((on @da path) gth)
::
++  stem
  =<  stem
  |%
  +$  stem  $-(deps vase)
  +$  vine  (axal road)             :: interface defining inputs
  +$  deps  (axal (each vase tang)) :: real computed values
  --
::
++  base
  =<  proc
  |%
  +$  from  (each (unit road) prov)
  +$  bowl
    $:  now=@da              :: time
        our=(unit @p)        :: host - sandboxed grubs may not see
        eny=@uvJ             :: entropy
        wex=(unit boat:gall) :: outgoing gall subs
        sup=(unit bitt:gall) :: incoming gall subs
        =from                :: provenance
        here=road            :: our address
        pid=@ta              :: our process id
    ==
  ::
  +$  sign
    $%  [%poke err=(unit tang)]   :: complete poke cycle (finish or crash)
        [%bump err=(unit tang)]   :: response to command for a running process
        [%pack p=(each @ta tang)] :: build poke (id or build error)
    ==
  ::
  +$  intake
    $%  [%bump =pail] :: command for a running process
        [%perk =wire =pail] :: gift / subscription
        [%peek =wire =path =cone =sand] :: local read
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to oust
        [%cull =wire err=(unit tang)] :: response to cull
        [%dead =wire err=(unit tang)] :: response to kill
        [%sand =wire err=(unit tang)] :: response to sand
        [%base =wire =sign] :: response from poke or bump
        [%veto =dart] :: notify that a dart was sandboxed
        :: messages from gall and arvo
        ::
        [%scry =wire =path =vase]
        [%arvo =wire sign=sign-arvo]
        [%agent =wire =sign:agent:gall]
        [%watch =path]
        [%leave =path]
    ==
  ::
  +$  input  [=bowl pail=(unit pail) state=vase temp=(axal vase) in=(unit intake)]
  ::
  +$  take  [=give in=(unit intake)]
  +$  cute  (qeu take)
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ !>(~) [~ ~] %done *value]
    $:  darts=(list dart)
        state=vase
        temp=(axal vase)
        $=  next
        $%  [%wait hold=?]
            [%skip hold=?]
            [%cont self=(form-raw value)]
            [%fail err=tang]
            [%done =value]
        ==
    ==
  ::
  ++  form-raw
    |*  value=mold
    $-(input (output-raw value))
  ::
  +$  proc  _*form:(charm ,~)
  :: 
  ++  charm
    |*  value=mold
    |%
    ++  output  (output-raw value)
    ++  form    (form-raw value)
    :: give value; leave state unchanged
    ::
    ++  pure
      |=  =value
      ^-  form
      |=  input
      ^-  output
      [~ state temp %done value]
    ::
    ++  bind
      |*  b=mold
      |=  [m-b=(form-raw b) fun=$-(b form)]
      ^-  form
      |=  =input
      =/  b-res=(output-raw b)  (m-b input)
      ^-  output
      :-  darts.b-res
      :-  state.b-res
      :-  temp.b-res
      ?-    -.next.b-res
        %wait  [%wait hold.next.b-res]
        %skip  [%skip hold.next.b-res]
        %cont  [%cont ..$(m-b self.next.b-res)]
        %fail  [%fail err.next.b-res]
        %done  [%cont (fun value.next.b-res)]
      ==
    --
  --
::
++  protocol
  |%
  +$  perk  [=wire =stud =noun] :: updates to the poker
  +$  make
    $%  [%base base=path data=(unit noun)]
        [%stem stem=path =vine:stem]
    ==
  +$  action
    $:  [=wire here=path]
        $%  [%make make]
            [%oust ~]
            [%cull ~]
            [%sand perm=(unit perm)]
            [%poke =stud =noun]
            [%bump pid=@ta =stud =noun]
            [%kill pid=(unit @ta)]
        ==
    ==
  --
--
