/<  tools  /lib/tools.hoon
::  forge_log: a followed repo's commit history, read from the history
::  grub the repo's data nexus keeps (data/ui/commits.json), newest
::  first. Filters are optional: since/until as YYYY-MM-DD, author as a
::  substring of the author name or email, limit as a count.
::
!:
=<  ^-  tool:tools
    |%
++  name  'forge_log'
++  description
  '''
  List a repo's commits, newest first: short hash, date, author and
  subject, with the body when there is one. repo is the name as
  forge_repos lists it. Optional filters: since and until (YYYY-MM-DD,
  inclusive), author (substring of name or email) and limit (default 50).
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['repo' [%string 'repo name, e.g. "hatchery"']]
      ['since' [%string 'earliest commit date to include, YYYY-MM-DD']]
      ['until' [%string 'latest commit date to include, YYYY-MM-DD']]
      ['author' [%string 'only commits whose author name or email contains this']]
      ['limit' [%number 'at most this many commits (default 50)']]
  ==
++  required  ~['repo']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  repo=@t  (fall (deg /repo so:dejs:format) '')
  =/  since=(unit @da)  (day-of (fall (deg /since so:dejs:format) ''))
  =/  until=(unit @da)  (day-of (fall (deg /until so:dejs:format) ''))
  =/  who=@t  (fall (deg /author so:dejs:format) '')
  =/  limit=@ud  (fall (deg /limit ni:dejs:format) 50)
  ?:  =('' repo)  (pure:m [%error 'repo is required'])
  ;<  fb=(unit lane:tarball)  bind:m  (resolve-link:io '@forge')
  ?.  ?=([~ %| *] fb)  (pure:m [%error 'forge is not in /sys/link'])
  =/  dir=@ta  (cat 3 repo '.git_repo')
  =/  ui=path  (weld p.u.fb /repos/[dir]/data/ui)
  ;<  v=view:nexus  bind:m  (peek:io [%& %& ui %'commits.json'] `[/ %json])
  ?.  ?=([%file *] v)
    (pure:m [%error (crip "no such repo, or no history yet: {(trip repo)}")])
  =/  log=(unit json)  (mole |.(!<(json (need-vase:tarball sang.v))))
  ?.  ?&(?=(^ log) ?=([%a *] u.log))
    (pure:m [%error (crip "the history of {(trip repo)} is not readable")])
  =/  all=(list json)  p.u.log
  =/  kept=(list json)
    %+  skim  all
    |=  c=json
    =/  at=@da  (when c)
    ?&  ?~(since & (gte at u.since))
        ?~(until & (lth at (add u.until ~d1)))
        ?|  =('' who)
            ?=(^ (find (trip who) (trip (str c 'author'))))
            ?=(^ (find (trip who) (trip (str c 'authorEmail'))))
        ==
    ==
  ?:  =(~ kept)  (pure:m [%text 'No commits match.'])
  =/  shown=(list json)  (scag limit kept)
  =/  head=tape
    "{(a-co:co (lent all))} commits in {(trip repo)}, {(a-co:co (lent kept))} match, showing {(a-co:co (lent shown))}\0a"
  =/  body=tape  (roll (turn shown render) |=([a=tape b=tape] (weld b a)))
  (pure:m [%text (crip (weld head body))])
--
|%
::  a commit's field as text ('' when absent or not a string)
++  str
  |=  [c=json key=@t]
  ^-  @t
  ?.  ?=([%o *] c)  ''
  =/  r  (~(get by p.c) key)
  ?:(?=([~ %s *] r) p.u.r '')
::  a commit's author date (written by time:enjs, read by di:dejs)
++  when
  |=  c=json
  ^-  @da
  ?.  ?=([%o *] c)  *@da
  =/  r  (~(get by p.c) 'date')
  ?~  r  *@da
  (fall (mole |.((di:dejs:format u.r))) *@da)
::  YYYY-MM-DD to midnight UTC that day, ~ when blank or malformed
++  day-of
  |=  t=@t
  ^-  (unit @da)
  ?:  =('' t)  ~
  =/  parts=(unit [y=@ud m=@ud d=@ud])
    (rush t ;~((glue hep) dem dem dem))
  ?~  parts  ~
  ?.  &((gte m.u.parts 1) (lte m.u.parts 12) (gte d.u.parts 1) (lte d.u.parts 31))  ~
  `(year [[%.y y.u.parts] m.u.parts d.u.parts 0 0 0 ~])
::  one commit: "short  date  author  subject", body lines indented
++  render
  |=  c=json
  ^-  tape
  =/  d=date  (yore (when c))
  =/  stamp=tape
    "{(a-co:co y.d)}-{(pad (a-co:co m.d))}-{(pad (a-co:co d.t.d))}"
  =/  body=tape  (trip (str c 'body'))
  =/  nl=(unit @ud)  (find "\0a" body)
  =/  first=tape
    ?:  =("" body)  (trip (str c 'message'))
    ?~  nl  body
    (scag u.nl body)
  =/  rest=tape
    ?~  nl  ""
    =/  tail=tape  (strip-nl (slag u.nl body))
    ?:  =("" tail)  ""
    "\0a    {(indent tail)}"
  "\0a{(trip (str c 'short'))}  {stamp}  {(trip (str c 'author'))}  {first}{rest}\0a"
::  drop leading and trailing newlines
++  strip-nl
  |=  t=tape
  ^-  tape
  (flop (lead (flop (lead t))))
::
++  lead
  |=  t=tape
  ^-  tape
  ?:  ?&(?=(^ t) =('\0a' i.t))  $(t t.t)
  t
::  continuation lines, each indented four
++  indent
  |=  t=tape
  ^-  tape
  =|  acc=tape
  |-
  ?~  t  (flop acc)
  ?:  =('\0a' i.t)  $(t t.t, acc (weld "    \0a" acc))
  $(t t.t, acc [i.t acc])
::
++  pad
  |=  t=tape
  ^-  tape
  ?:(=(1 (lent t)) ['0' t] t)
--
