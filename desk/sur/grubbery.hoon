|%
+$  stud  path
+$  pail  (pair stud vase)
:: TODO: However it's done, packaging and sharing code needs to be
::       made effortless in such a way that doesn't
::       overcomplicated imports and other references.
::
+$  grub
  $%  [%base data=vase base=path]
      [%stem data=(each vase tang) =vine:stem stem=path]
  ==
::
+$  scry  [=mold =path] :: normal non-grubbery scry request
:: effects that a base grub can emit
::
+$  dart
  $%  [%grub =wire =road =load]
      [%perk =pail]                   :: updates to the poker
      [%sysc =card:agent:gall]
      [%scry =wire scry=(unit scry)]  :: null returns grubbery agent state
      [%bowl =wire]                   :: ask grubbery for bowl info
  ==
::
+$  make
  $%  [%base base=path data=(unit vase)]
      [%stem stem=path =vine:stem]
  ==
:: dart payload
::
+$  load
  $%  [%make =make]
      [%oust ~]
      [%cull ~]
      [%sand weir=(unit weir)]
      [%poke =pail]
      [%bump pid=@ta =pail]
      [%kill pid=(unit @ta)]
      [%peek ~]
  ==
:: versioning and "signals"-style acyclic dependencies
::
+$  tack
  $:  kind=(unit ?(%base %stem))
      last=@da
      sinx=(set path)
      tidy=?
      sour=(map path @da)
  ==
::
+$  bend  (pair @ud path)                 :: relative path
+$  road  (each path bend)                :: absolute or relative path
+$  prov  [src=@p sap=path]               :: external provenance
+$  from  (each path prov)                :: absolute source
+$  give  [=from =wire]                   :: return address
+$  poke  [=give pail=(unit pail)]        :: null poke means on-load
+$  take  [[here=path pid=@ta] take:base] :: localized input + return address
::
+$  proc
  $:  =proc:base
      =poke                :: keep initial poke
      next=(qeu take:base) :: queue of held inputs
      skip=(qeu take:base) :: queue of skipped inputs
  ==
::
+$  pipe
  $:  last=@da
      boar=(unit @ta)          :: who is hogging the pipe
      temp=(axal vase)         :: persist shared "transient" state
      proc=(map @ta proc)
  ==
:: SANDBOXING:
:: All darts are addressed be sent to either a path in the namespace or to
:: something outside of grubbery to be understood as living "above" the root /.
:: Darts are considered in principle to be emitted by base grubs and to
:: move first up the tree to the nearest common ancestor with their destination
:: and then down the tree to their destination. All downward movement is
:: considered legal. All upward movement or darts addressed to yourself
:: must be checked against a filter ($weir) for allowed destination prefixes.
:: - Any dart blocked by a filter is %vetoed.
:: - Any dynamically typed data passing through a filter must be clammed.
::
:: ~      means unfiltered
:: [~ %&] means filtered but allowed; any moving vases should be clammed
:: [~ %|] means filtered and disallowed; dart will be %vetoed
::
+$  filt  (unit ?)
:: It's called a jump because filters only apply to darts moving UP the tree
::
+$  jump
  $?  %make :: checking if make-related functionality is filtered
      %poke :: checking if poke-related functionality is filtered
      %peek :: checking if %peek requests are filtered
      %give :: checking if %peek results are filtered
      %sysc :: checking if syscalls are filtered
      %perk :: checking if %perk updates are filtered
  ==
:: a filter or net
::
+$  weir
  $:  make=(set road) :: %make, %oust, %cull or %sand
      poke=(set road) :: %poke, %bump or %kill
      peek=(set road)
  ==
::
+$  cone  (axal grub)
+$  trac  (axal tack)
+$  pool  (axal pipe)
+$  sand  (axal weir)
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
  :: [%| ~zod /gall/...]                - from outside grubbery
  :: [%& %& /some/absolute/path]        - absolute path from inside grubbery
  :: [%& %| 2 /relative/path/to/source] - relative path from inside grubbery
  ::
  +$  from  (each bend prov) :: base can see only RELATIVE source
  ::
  +$  bowl
    $:  now=@da
        our=@p
        eny=@uvJ
        wex=boat:gall
        sup=bitt:gall
        here=path
    ==
  :: acks and nacks
  ::
  +$  sign
    $%  [%poke err=(unit tang)]   :: complete poke cycle (finish or crash)
        [%bump err=(unit tang)]   :: response to command for a running process
        [%pack p=(each @ta tang)] :: build poke (id or build error)
    ==
  ::
  +$  intake
    $%  [%bump =from =pail] :: command for a running process
        [%perk =wire =pail] :: gift / subscription
        [%peek =wire =path =cone =sand] :: local read
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to oust
        [%cull =wire err=(unit tang)] :: response to cull
        [%dead =wire err=(unit tang)] :: response to kill
        [%sand =wire err=(unit tang)] :: response to sand
        [%base =wire =sign] :: response from poke or bump
        [%veto dart=$<(%perk dart)] :: notify that a dart was sandboxed
        :: messages from gall and arvo
        ::
        [%scry =wire =path =vase]
        [%bowl =wire =bowl]
        [%arvo =wire sign=sign-arvo]
        [%agent =wire =sign:agent:gall]
        [%watch =path]
        [%leave =path]
    ==
  ::
  +$  input
    $:  pid=@ta          :: process id
        =from            :: no anonymous pokes allowed
        pail=(unit pail) :: the poke data is always available
        state=vase       :: state for which we are responsible
        temp=(axal vase) :: a scratchpad for logistical data for coordination
        in=(unit intake) :: command/response/data to ingest (null means start)
    ==
  ::
  +$  take  [=give in=(unit intake)]
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ !>(~) [~ ~] %done *value]
    $:  darts=(list dart)
        state=vase
        temp=(axal vase)
        $=  next
        $%  [%wait hold=?] :: process intake and optionally claim mutex (boar)
            [%skip hold=?] :: ignore intake and optionally claim mutex
            [%cont self=(form-raw value)] :: continue to next computation
            [%fail err=tang] :: return failure
            [%done =value]   :: return result
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
:: hardcoded studs
::
++  lib
  =<  lib
  |%
  +$  lib   [text=@t code=(each code tang)]
  +$  code  [deps=(list (pair term path)) =hoon]
  --
:: types that can move across the network
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
            [%sand weir=(unit weir)]
            [%poke =stud =noun]
            [%bump pid=@ta =stud =noun]
            [%kill pid=(unit @ta)]
        ==
    ==
  --
--
