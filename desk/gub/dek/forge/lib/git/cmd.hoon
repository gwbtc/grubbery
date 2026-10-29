::  lib/git/cmd: a git-CLI options/argv parser.
::
::    Ported from hoon-git's lib/cmd.hoon — the one real artifact there (its
::    per-command parsers were referenced but never written). Front-end
::    agnostic: it turns a command string into a parsed [command options]
::    pair. Both forge's command input and the git_cmd MCP tool sit on this,
::    so the grammar for a verb lives in exactly one place.
::
::    Build verb grammars with the combinators below:
::      +cmd       a verb that takes options (before and/or after args) + args
::      +cmd-solo  a verb with no options, just args
::      +flag-opt / +text-opt / +num-opt   declare an option of each kind
::
|%
+$  opt-kind  ?(%f %t %ud)                    ::  flag | text | number
+$  opt-val   $%([%f ~] [%t @t] [%ud @ud])
+$  option    (pair @tas opt-val)             ::  [--name value]
::  +cmd-parse: parse a full verb (front options, args, back options).
::
++  cmd-parse  cmd:parse
++  parse
  |%
  ::  Renovated @ta to include uppercase
  ::
  ++  urs  %+  cook
             |=(a=tape (rap 3 ^-((list @) a)))
           (star ;~(pose nud hig low hep dot sig cab))
  ++  gap  (plus ace)
  ++  val-f  (easy ~)  :: option is present
  ::  XX Allow non-Hoon integers
  ++  val-ud  dem:ag
  ++  val-t
    ;~  pose
      ::  "double quoted" (git/shell convention); may span lines, so a
      ::  commit message can carry a body. \" and \\ are escapes: without
      ::  them a message that quotes anything ended at its own first quote,
      ::  the rest parsed as garbage, and the command came back
      ::  "unrecognized" — which the caller never saw, since the lane
      ::  reports accepted, not done. A push then said "nothing to push".
      %+  ifix  [doq doq]
      %+  boss  256
      %-  star
      ;~  pose
        ;~(pfix bas doq)                        ::  \" is a quote
        ;~(pfix bas bas)                        ::  \\ is a backslash
        ;~(less doq ;~(pose prn (just `@`10)))
      ==
      ::  'single quoted'
      (ifix [soq soq] (boss 256 (star qit)))
      ::  unescaped cord
      (boss 256 (star ;~(less ace qit)))
    ==
  ::  +trim-tail: drop trailing spaces and newlines from a tape.
  ::
  ++  trim-tail
    |=  t=tape
    ^-  tape
    =/  r=tape  (flop t)
    |-  ^-  tape
    ?~  r  ~
    ?:  |(=(' ' i.r) =(`@`10 i.r))  $(r t.r)
    (flop r)
  ::  +val-rest: EVERYTHING that is left, as one cord.
  ::
  ::    For a trailing text option whose value runs to the end of the line —
  ::    a commit message, typically. +val-t stops a bare value at the first
  ::    space, which is git's own rule (quote it, or it is one word), but an
  ::    unquoted multi-word message then parsed as its first word and left
  ::    the rest dangling, so the whole command came back `unrecognized`
  ::    with no hint that quotes were what it wanted. A verb may offer this
  ::    as a SECOND pass (see +parse-command) so the strict grammar — where
  ::    repeated -m means paragraphs — still wins when it fits.
  ::
  ::    Trailing whitespace is dropped; inner spacing is kept as written.
  ::
  ++  val-rest
    %+  cook  |=(t=tape (crip (trim-tail t)))
    (plus ;~(pose prn (just `@`10)))
  ::  +split-pathspec: git's end-of-options convention
  ::
  ::    Everything after a bare `--` is a pathspec and never an option.
  ::    Split it off BEFORE any option grammar runs: +val-rest is greedy
  ::    to end-of-line by design, so a `-m` that sees `--` swallows it as
  ::    message text. Doing it here also means every verb gets pathspec
  ::    support for free, and strict and loose passes agree.
  ::
  ::    Returns the command with the pathspec removed, and the paths. No
  ::    `--` yields the text unchanged and ~, so this is safe to run over
  ::    every command. A leading slash is optional on each path: `--
  ::    desk/app/x.hoon` and `-- /desk/app/x.hoon` both parse.
  ::
  ++  split-pathspec
    |=  txt=@t
    ^-  [cmd=@t paths=(list path)]
    =/  res
      %+  rust  (trip txt)
      ;~  plug
        (star ;~(less (jest ' -- ') prn))
        ;~  pose
          ;~(pfix (jest ' -- ') (cook some (star prn)))
          (easy ~)
        ==
      ==
    ?~  res  [txt ~]
    =/  head=tape  -.u.res
    =/  tail=(unit tape)  +.u.res
    :-  (crip (trim-tail head))
    ?~  tail  ~
    =/  toks  (rust u.tail (most (plus ace) (plus ;~(less ace prn))))
    ?~  toks  ~
    %+  turn  u.toks
    |=  t=tape
    ^-  path
    (stab (crip ?:(=('/' -.t) t ['/' t])))
  ++  value
    |*  kind=opt-kind
    ?-  kind
      %f  (stag %f val-f)
      %t  (stag %t val-t)
      %ud  (stag %ud val-ud)
    ==
  ::  -o
  ++  short
    |=(o=char ;~(plug hep (just o)))
  ::  --opt
  ++  long
    |=  opt=@tas
    ;~(plug hep hep (jest opt))
  ::  -o val, -oval
  ++  short-value
    |=  [o=char kind=opt-kind]
    ?:  ?=(%f kind)
      ;~(pfix (short o) (value kind))
    ;~(pfix (short o) ;~(pfix (star ace) (value kind)))
  ::  --opt val, --opt=val
  ++  long-value
    |=  [opt=@tas kind=opt-kind]
    ::  XX a bug in the parser:
    ::  ?=(kind %f) parser to something wrong
    ::
    ?:  ?=(%f kind)
      ;~(pfix (long opt) (value kind))
    ;~  pfix
      (long opt)
      ;~  pose
        ;~(pfix tis (value kind))
        ;~(pfix gap (value kind))
      ==
    ==
  ++  short-or-long-value
    |=  [o=@t opt=@tas kind=opt-kind]
    ;~  pose
      (short-value o kind)
      (long-value opt kind)
    ==
  ++  opt
    |=  [opt=@tas o=@tas kind=opt-kind]
    %+  stag  opt
    ?:  =(%$ o)
      (long-value opt kind)
    (short-or-long-value o opt kind)
  ++  flag-opt
    |=  [opt=@tas o=@tas]
    (^opt opt o %f)
  ++  text-opt
    |=  [opt=@tas o=@tas]
    (^opt opt o %t)
  ++  num-opt
    |=  [opt=@tas o=@tas]
    (^opt opt o %ud)
  ++  cmd-solo
    |*  [cmd=@tas args=rule]
    %+  cook
      |=(cmd=* [cmd ~])
    (stag cmd ;~(pfix (jest cmd) args))
  ++  any-short-opt
    ;~(plug hep ;~(pose low dit))
  ++  any-long-opt
    ;~(plug hep hep ;~(pose low dit))
  ++  any-opt
    ;~(pose any-short-opt any-long-opt)
  ++  cmd
    |*  [cmd=@tas opt=rule args=rule]
    |=  tub=nail
    ^-  (like [* (list option)])
    ::  Parse front options, command arguments
    ::
    ::  XX using , somehow changes output of
    ::  compiler error.
    ::
    =/  vex=(like [(list option) (unit *) *])
      %.  tub
      ;~  pfix  (jest cmd)
        ;~  plug
          (ifix [gap (star ace)] (more gap opt))
          (punt ;~(plug hep hep gap))
          (stag cmd args)
        ==
      ==
    ?~  q.vex  vex
    =/  [front=(list option) opt-end=(unit *) command=*]
      p.u.q.vex
    ?:  ?|(?=(^ opt-end) =("" q.q.u.q.vex))
      [p.vex `[[command front] q.u.q.vex]]
    =/  vex=(like (list option))
      %.  q.u.q.vex
      ;~  sfix
        ;~(pfix gap (more gap opt))
        (star ace)
      ==
    ?~  q.vex  vex
    =+  back=p.u.q.vex
    [p.vex `[[command (weld front back)] q.u.q.vex]]
  --
--
