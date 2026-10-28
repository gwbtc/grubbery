/<  tools  /lib/tools.hoon
::  deploy-to-desk: deploy a grubbery directory tree to a Clay desk
::
::  Walks the source directory, reads every file as mime, diffs against
::  the current Clay desk contents, and sends one atomic %info with all
::  inserts and deletes.  Clay tube-converts each %mime cage to the
::  destination mark derived from the path extension.
::
!:
^-  tool:tools
=>
|%
++  collect-files
  |=  [=ball:tarball current-path=path]
  ^-  (list [path @ta])
  =/  files=(list @ta)  (~(lis ba:tarball ball) current-path)
  =/  files-with-path=(list [path @ta])
    %+  turn  files
    |=(f=@ta [current-path f])
  =/  current-ball=ball:tarball  (~(dip ba:tarball ball) current-path)
  =/  subdirs=(list @ta)  ~(tap in ~(key by dir.current-ball))
  =/  subdir-files=(list [path @ta])
    |-  ^-  (list [path @ta])
    ?~  subdirs  ~
    =/  subdir-path=path  (snoc current-path i.subdirs)
    (weld (collect-files ball subdir-path) $(subdirs t.subdirs))
  (weld files-with-path subdir-files)
--
|%
++  name  'deploy_to_desk'
++  description
  ^~  %-  crip
  ;:  weld
    "Deploy a grubbery directory tree to a Clay desk. "
    "Walks the source path recursively, reads every file as mime, "
    "diffs against the target desk, and commits inserts + deletes "
    "as one atomic Clay write. File extensions become Clay marks "
    "(e.g. foo.hoon -> /foo/hoon)."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['source' [%string 'Grubbery source directory path (e.g. "/apps/myrepo/data/tree/code")']]
      ['desk' [%string 'Target Clay desk name (e.g. "landscape")']]
  ==
++  required  ~['source' 'desk']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?+  step.st  (pure:m [%error 'Unknown deploy step'])
      %start
    ;<  err=(unit tang)  bind:m  (sleep-or-crud:tools (div ~s1 10))
    ?^  err
      =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
    =/  parsed=(each [@t @t] tang)
      %-  mule  |.
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['source' so:dejs:format]
          ['desk' so:dejs:format]
      ==
    ?:  ?=(%| -.parsed)
      (pure:m [%error 'Missing or invalid required arguments (source, desk)'])
    =/  [source=@t desk=@t]  p.parsed
    =/  src-pax=path  (stab source)
    =/  dek=@tas  (slav %tas desk)
    ::  walk the grubbery source tree
    ;<  =view:nexus  bind:m  (peek:io [%& %| src-pax] ~)
    ?.  ?=([%ball *] view)
      (pure:m [%error (crip "Source directory not found: {(trip source)}")])
    =/  src-files=(list [path @ta])
      (collect-files ball.view ~)
    ?~  src-files
      (pure:m [%error (crip "No files found under {(trip source)}")])
    ::  read each file as mime and build the insert list
    =/  inserts=(list [path (unit mime)])  ~
    =/  remaining=(list [path @ta])  src-files
    |-
    ?~  remaining
      ::  get current Clay desk tree for deletion diff
      =/  ins=(list [path (unit mime)])  (flop inserts)
      =/  ins-paths=(set path)
        %-  ~(gas in *(set path))
        (turn ins |=([p=path *] p))
      ;<  clay-files=(list path)  bind:m
        (clay-tree:io dek /)
      =/  dels=(list [path (unit mime)])
        %+  murn  clay-files
        |=  p=path
        ^-  (unit [path (unit mime)])
        ?.  (~(has in ins-paths) p)
          `[p ~]
        ~
      =/  soba=(list [path (unit mime)])
        (weld ins dels)
      ?~  soba
        (pure:m [%text 'No changes to deploy'])
      ;<  initial=cass:clay  bind:m  (clay-case:io dek)
      =/  write-data=json
        %-  pairs:enjs:format
        :~  ['initial-ud' (numb:enjs:format ud.initial)]
            ['desk' s+desk]
            ['file-path' s+(crip "{<(lent ins)>} inserts, {<(lent dels)>} deletes")]
            ['logs' a+~]
        ==
      ;<  ~  bind:m
        (replace:io [tool.st args.st %deploying write-data ~])
      ;<  *  bind:m  (keep:io /dill/logs [%& %& /sys/dill %'logs.dill-told'] ~)
      ;<  now=@da  bind:m  get-time:io
      ;<  ~  bind:m
        (set-timer:io /commit-timeout (add now ~m2))
      ;<  ~  bind:m
        (clay-info:io dek soba)
      ;<  ~  bind:m  collect-logs:tools
      ;<  ~  bind:m  (drop:io /dill/logs [%& %& /sys/dill %'logs.dill-told'])
      ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
      ;<  res=tool-result:tools  bind:m  (finish-clay-write:tools args.st data.st)
      ?-  -.res
        %error  (pure:m res)
        %mime   (pure:m res)
        %text
          =/  summary=tape
            "{<(lent ins)>} files deployed, {<(lent dels)>} deleted on %{(trip desk)}"
          (pure:m [%text (crip (zing ~[(trip text.res) "\0a" summary]))])
      ==
    ::  read current file as mime
    =/  [dir=path filename=@ta]  i.remaining
    =/  full-path=path  (weld src-pax dir)
    ;<  file-view=view:nexus  bind:m
      (peek:io [%& %& full-path filename] ~)
    ?.  ?=([%file *] file-view)
      $(remaining t.remaining)
    =/  =sage:tarball  (need-sage:tarball sang.file-view)
    ?.  =([/ %mime] p.sage)
      $(remaining t.remaining)
    =/  =mime  !<(mime q.sage)
    ::  convert filename.ext -> /dir/filename/ext for Clay
    =/  clay-path=path
      =/  name-tape=tape  (trip filename)
      =/  dot=(unit @ud)  (find "." (flop name-tape))
      ?~  dot
        (snoc dir filename)
      =/  len=@ud  (lent name-tape)
      =/  base=@ta  (crip (scag (sub len +(u.dot)) name-tape))
      =/  ext=@ta   (crip (slag (sub len u.dot) name-tape))
      (snoc (snoc dir base) ext)
    %=  $
      remaining  t.remaining
      inserts    [[clay-path `mime] inserts]
    ==
      %deploying
    (finish-clay-write:tools args.st data.st)
  ==
--
