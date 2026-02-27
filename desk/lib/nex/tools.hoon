::  lib/nex/tools: types + built-in tool fibers for the tools nexus
::
::  A $tool is a self-contained unit: metadata (name, description, schema)
::  plus a fiber handler. Built-ins live here; user tools are .hoon files
::  in /tools/tools/ that compile to the same $tool type.
::
/+  nexus, tarball, io=fiberio, json-utils, pretty-file, s3
!:
|%
::  Tool execution result
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
  ==
::  Tool process state: args + step tag + step-specific data.
::  Step tag acts like a head-tagged union — handlers switch on it.
::  %start = fresh invocation. %done = finished with result.
::
+$  tool-state
  $:  args=(map @t json)
      step=@tas
      data=json
  ==
::  Parameter schema for tool discovery (MCP, Claude API, etc.)
::
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
::
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
::  Tool definition: everything needed to advertise + execute a tool.
::  Built-in tools produce this directly. .hoon files must compile to this type.
::
+$  tool
  $_  ^?
  |%
  ++  name         *@t
  ++  description  *@t
  ++  parameters   *(map @t parameter-def)
  ++  required     *(list @t)
  ++  handler      *tool-handler
  --
::
+$  tool-handler  _*form:(fiber:fiber:nexus ,tool-result)
::  Simple glob pattern matching (* = any sequence of characters)
::
++  glob-match
  |=  [pat=tape txt=tape]
  ^-  ?
  ?~  pat  =(txt ~)
  ?:  =(i.pat '*')
    ?|  (glob-match t.pat txt)
        ?&(?=(^ txt) (glob-match pat t.txt))
    ==
  ?~  txt  %.n
  ?&(=(i.pat i.txt) (glob-match t.pat t.txt))
::  Built-in tool registry
::
++  built-ins
  ^-  (map @t tool)
  %-  ~(gas by *(map @t tool))
  :~  ['get_ship' get-ship]
      ['commit' tool-commit]
      ['desk_version' tool-desk-version]
      ['scry' tool-scry]
      ['eval' tool-eval]
      ['list_clay_files' tool-list-files]
      ['get_clay_file' tool-get-file]
      ['insert_clay_file' tool-insert-file]
      ['edit_clay_file' tool-edit-clay-file]
      ['nuke_agent' tool-nuke-agent]
      ['revive_agent' tool-revive-agent]
      ['poke_agent' tool-poke-agent]
      ['mount_desk' tool-mount-desk]
      ['install_app' tool-install-app]
      ['toggle_permissions' tool-toggle-permissions]
      ['send_telegram' tool-send-telegram]
      ['browse' tool-browse]
      ['glob' tool-glob]
      ['grep' tool-grep]
      ['read_grub' tool-read-grub]
      ['write_grub' tool-write-grub]
      ['delete_grub' tool-delete-grub]
      ['create_folder' tool-create-folder]
      ['delete_folder' tool-delete-folder]
      ['create_symlink' tool-create-symlink]
      ['add_weir' tool-add-weir]
      ['del_weir' tool-del-weir]
      ['clear_weir' tool-clear-weir]
      ['edit_file' tool-edit-file]
      ['s3_list' tool-s3-list]
      ['s3_upload' tool-s3-upload]
      ['s3_upload_directory' tool-s3-upload-directory]
      ['s3_download' tool-s3-download]
      ['s3_download_directory' tool-s3-download-directory]
      ['s3_delete' tool-s3-delete]
      ::  TODO: run_tests — run unit/integration tests via spider
      ::  TODO: new_desk — create a new desk with default provisions
  ==
::  All tool definitions (for MCP tools/list)
::
++  all-tool-defs
  ^-  (list tool)
  ~(val by built-ins)
::  Built-in tool implementations
::
++  get-ship
  ^-  tool
  |%
  ++  name  'get_ship'
  ++  description  'Get the current ship name'
  ++  parameters  *(map @t parameter-def)
  ++  required  *(list @t)
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    (pure:m [%text (scot %p our.bowl)])
  --
::
++  tool-desk-version
  ^-  tool
  |%
  ++  name  'desk_version'
  ++  description  'Get the current version of a mounted desk'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['mount_point' [%string 'Mount point name (e.g. "base")']]
    ==
  ++  required  ~['mount_point']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  mount-point=@tas
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['mount_point' so:dejs:format]
      ==
    ;<  =cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[mount-point])
    =/  result=tape
      ;:  weld
        "Desk: {(trip mount-point)}\0a"
        "Version: {<ud.cass>}\0a"
        "Date: {(scow %da da.cass)}"
      ==
    (pure:m [%text (crip result)])
  --
::
++  tool-commit
  ^-  tool
  |%
  ++  name  'commit'
  ++  description  'Commit a mounted desk and return version info with logs'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['mount_point' [%string 'Mount point name (e.g. "base")']]
        ['timeout_seconds' [%number 'Timeout in seconds to wait for logs (default: 30)']]
    ==
  ++  required  ~['mount_point']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    ?+  step.st  (pure:m [%error 'Unknown commit step'])
        %start
      ::  Parse arguments
      =/  mount-point=@tas
        %.  [%o args.st]
        %-  ot:dejs:format
        :~  ['mount_point' so:dejs:format]
        ==
      =/  timeout-seconds=@ud
        ?~  timeout-json=(~(get by args.st) 'timeout_seconds')
          30
        ?.  ?=([%n *] u.timeout-json)
          30
        (rash p.u.timeout-json dem)
      =/  timeout=@dr  (mul timeout-seconds ~s1)
      ::  Get initial version
      ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[mount-point])
      ::  Checkpoint: save state before committing
      =/  commit-data=json
        %-  pairs:enjs:format
        :~  ['initial-ud' (numb:enjs:format ud.initial)]
            ['initial-da' s+(scot %da da.initial)]
            ['logs' a+~]
        ==
      ;<  ~  bind:m
        (replace:io !>([args.st %committing commit-data]))
      ::  Subscribe to dill logs
      ;<  ~  bind:m  (send-card:io %pass /dill-logs %arvo %d %logs `~)
      ::  Set main timeout
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ;<  ~  bind:m
        (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl timeout))
      ::  Commit the desk (may kill us if committing own desk)
      ;<  ~  bind:m  (gall-poke-our:io %hood kiln-commit+!>([mount-point %.n]))
      ::  If we survive, collect logs and finish
      ;<  ~  bind:m  collect-logs
      ;<  ~  bind:m  (send-card:io %pass /dill-logs %arvo %d %logs ~)
      ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
      (finish-commit args.st data.st)
        ::  %committing: restarted after desk recompile
        ::
        %committing
      (finish-commit args.st data.st)
    ==
  --
::
++  finish-commit
  |=  [args=(map @t json) data=json]
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?.  ?=([%o *] data)
    (pure:m [%error 'Commit state lost (stale tool grub). Please retry.'])
  =/  mount-point=@tas
    %.  [%o args]
    %-  ot:dejs:format
    :~  ['mount_point' so:dejs:format]
    ==
  ?~  (~(get by p.data) 'initial-ud')
    (pure:m [%error 'Commit state incomplete. Please retry.'])
  =/  initial-ud=@ud
    (~(dog jo:json-utils data) /initial-ud ni:dejs:format)
  =/  log-texts=(list @t)
    (~(dug jo:json-utils data) /logs (ar:dejs:format so:dejs:format) ~)
  ;<  final=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[mount-point])
  =/  result=tape
    %+  weld  "Initial version: {<initial-ud>}\0a"
    %+  weld  "Final version: {<ud.final>}\0a"
    %+  weld  "Logs ({<(lent log-texts)>}):\0a"
    (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
  (pure:m [%text (crip result)])
::
++  finish-clay-write
  |=  [args=(map @t json) data=json]
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?.  ?=([%o *] data)
    (pure:m [%error 'Clay write state lost. Please retry.'])
  ?~  (~(get by p.data) 'initial-ud')
    (pure:m [%error 'Clay write state incomplete. Please retry.'])
  =/  initial-ud=@ud
    (~(dog jo:json-utils data) /initial-ud ni:dejs:format)
  =/  desk=@t
    (~(dog jo:json-utils data) /desk so:dejs:format)
  =/  file-path=@t
    (~(dog jo:json-utils data) /file-path so:dejs:format)
  =/  log-texts=(list @t)
    (~(dug jo:json-utils data) /logs (ar:dejs:format so:dejs:format) ~)
  =/  dek=@tas  (slav %tas desk)
  ;<  final=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
  =/  has-errors=?
    %+  lien  log-texts
    |=(t=@t !=(~ (find "ERROR" (trip t))))
  =/  result=tape
    ?:  has-errors
      %+  weld  "Clay write FAILED for {(trip file-path)} in %{(trip desk)}\0a"
      %+  weld  "Version unchanged: {<ud.final>}\0a"
      %+  weld  "Errors ({<(lent log-texts)>}):\0a"
      (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
    %+  weld  "Wrote {(trip file-path)} to %{(trip desk)}\0a"
    %+  weld  "Version: {<initial-ud>} -> {<ud.final>}\0a"
    ?~  log-texts  ""
    %+  weld  "Logs ({<(lent log-texts)>}):\0a"
    (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
  ?:  has-errors
    (pure:m [%error (crip result)])
  (pure:m [%text (crip result)])
::  Sleep to leave the Eyre HTTP request event.  Returns ~ on
::  success (timer fired cleanly) or [~ tang] if the subsequent
::  work crashed the event and behn retried with the error.
::  This lets us capture Clay build errors as data instead of
::  crashing with crud! or timer-error.
::
++  sleep-or-crud
  |=  for=@dr
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl:io /sleep)
  =/  until=@da  (add now.bowl for)
  ;<  ~  bind:m  (send-wait:io until)
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?.  =(`until (slaw %da i.t.wire.u.in))
      [%skip ~]
    ?~  error.sign.u.in
      [%done ~]
    [%done `u.error.sign.u.in]
  ==
::
++  tool-scry
  ^-  tool
  |%
  ++  name  'scry'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Run a scry (read) to retrieve data from a vane or agent. "
      "Path format: /[vane letter][care]/[desk-or-agent]/[rest...]/[mark]. "
      "The return type will always be JSON, and the read will fail if "
      "there is no mark conversion from the endpoint's mark to JSON. "
      "Examples: /gx/hood/kiln/pikes/json, /cx/base/sys/kelvin"
      "Supported marks: json, txt, hoon, mime."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  :-  'path'
        :-  %string
        ^~  %-  crip
        ;:  weld
          "The scry path (e.g. /gx/hood/kiln/pikes/json "
          "or /cx/base/sys/kelvin)"
        ==
    ==
  ++  required  ~['path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  path-text=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
      ==
    =/  pax=path  (stab path-text)
    =/  mark=@tas  (rear pax)
    ?+  mark
      (pure:m [%error (crip "Unsupported scry mark: %{(trip mark)}. Use /json, /txt, /hoon, or /mime.")])
        %json
      ;<  result=json  bind:m  (do-scry:io json /scry pax)
      (pure:m [%text (en:json:html result)])
        %txt
      ;<  result=wain  bind:m  (do-scry:io wain /scry pax)
      (pure:m [%text (of-wain:format result)])
        %hoon
      ;<  result=@t  bind:m  (do-scry:io @t /scry pax)
      (pure:m [%text result])
        %mime
      ;<  result=mime  bind:m  (do-scry:io mime /scry pax)
      (pure:m [%text (crip (trip q.q.result))])
    ==
  --
::
++  tool-eval
  ^-  tool
  |%
  ++  name  'eval'
  ++  description  'Evaluate a Hoon expression and return the result as text'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['hoon' [%string 'Any Hoon expression, e.g. "(add 2 2)"']]
    ==
  ++  required  ~['hoon']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  code=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['hoon' so:dejs:format]
      ==
    =/  res=(each vase tang)
      (mule |.((slap !>(..zuse) (ream code))))
    ?:  ?=(%| -.res)
      =/  lines=wall  (zing (turn (flop p.res) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Eval failed:\0a{(of-wall:format lines)}")])
    =/  =tank  (sell p.res)
    =/  =wall  (wash [0 160] tank)
    (pure:m [%text (of-wain:format (turn wall crip))])
  --
::
++  tool-list-files
  ^-  tool
  |%
  ++  name  'list_clay_files'
  ++  description  'List files in Clay under a given path'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Desk name (e.g. "base")']]
        ['path' [%string 'Path to list (e.g. "/" or "/gen")']]
    ==
  ++  required  ~['desk' 'path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [desk=@t file-path=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
          ['path' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    =/  pax=path  (stab file-path)
    ;<  files=(list path)  bind:m
      (do-scry:io (list path) /scry [%ct dek pax])
    =/  result=tape
      %-  zing
      %+  turn  files
      |=(p=path "{(spud p)}\0a")
    (pure:m [%text (crip result)])
  --
::
++  tool-get-file
  ^-  tool
  |%
  ++  name  'get_clay_file'
  ++  description  'Fetch a file from Clay and return its contents as text'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Desk name (e.g. "base")']]
        ['path' [%string 'File path (e.g. "/gen/hood/commit/hoon")']]
    ==
  ++  required  ~['desk' 'path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [desk=@t file-path=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
          ['path' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    =/  pax=path  (stab file-path)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  =riot:clay  bind:m
      (warp:io our.bowl dek ~ %sing %x da+now.bowl pax)
    ?~  riot
      (pure:m [%error 'File not found'])
    =/  =tang  (pretty-file:pretty-file !<(noun q.r.u.riot))
    =/  =wain
      %-  zing
      %+  turn  tang
      |=(=tank (turn (wash [0 160] tank) crip))
    (pure:m [%text (of-wain:format wain)])
  --
::
++  tool-insert-file
  ^-  tool
  |%
  ++  name  'insert_clay_file'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Insert or overwrite a file in the Clay filesystem. "
      "The mark is the last segment of the path (e.g. /app/foo/hoon has mark %hoon). "
      "The desk must have a matching mark file in /mar/."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Target desk name (e.g. "base")']]
        ['path' [%string 'File path including mark (e.g. "/gen/hello/hoon")']]
        ['content' [%string 'File content to write']]
    ==
  ++  required  ~['desk' 'path' 'content']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    ?+  step.st  (pure:m [%error 'Unknown insert step'])
        %start
      ::  Sleep to leave the Eyre HTTP request event.  If the Clay
      ::  write crashes the build, behn retries with the error and
      ::  sleep-or-crud captures it as data instead of crashing.
      ::
      ;<  err=(unit tang)  bind:m  (sleep-or-crud (div ~s1 10))
      ?^  err
        =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
        (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
      =/  [desk=@t file-path=@t content=@t]
        %.  [%o args.st]
        %-  ot:dejs:format
        :~  ['desk' so:dejs:format]
            ['path' so:dejs:format]
            ['content' so:dejs:format]
        ==
      =/  dek=@tas  (slav %tas desk)
      =/  pax=path  (stab file-path)
      ?~  pax
        (pure:m [%error 'Empty path'])
      =/  mark=@tas  (rear pax)
      ::  Get initial version
      ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
      ::  Checkpoint: save state before writing
      =/  write-data=json
        %-  pairs:enjs:format
        :~  ['initial-ud' (numb:enjs:format ud.initial)]
            ['desk' s+desk]
            ['file-path' s+file-path]
            ['logs' a+~]
        ==
      ;<  ~  bind:m
        (replace:io !>([args.st %inserting write-data]))
      ::  Subscribe to dill logs
      ;<  ~  bind:m  (send-card:io %pass /dill-logs %arvo %d %logs `~)
      ::  Set timeout
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ;<  ~  bind:m
        (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl ~s30))
      ::  Write to Clay via %hood
      ;<  ~  bind:m
        (gall-poke-our:io %hood kiln-info+!>(["" `[dek %& [pax %ins mark !>(content)]~]]))
      ::  Collect logs and finish
      ;<  ~  bind:m  collect-logs
      ;<  ~  bind:m  (send-card:io %pass /dill-logs %arvo %d %logs ~)
      ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
      (finish-clay-write args.st data.st)
        %inserting
      (finish-clay-write args.st data.st)
    ==
  --
::
++  tool-edit-clay-file
  ^-  tool
  |%
  ++  name  'edit_clay_file'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Edit a file in Clay via exact string replacement. "
      "Reads the file, replaces old_string with new_string, and writes it back. "
      "Fails if old_string is not found or matches multiple times."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Desk name (e.g. "base")']]
        ['path' [%string 'File path including mark (e.g. "/gen/hello/hoon")']]
        ['old_string' [%string 'The exact text to find and replace']]
        ['new_string' [%string 'The replacement text']]
    ==
  ++  required  ~['desk' 'path' 'old_string' 'new_string']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    ?+  step.st  (pure:m [%error 'Unknown edit step'])
        %start
      ::  Sleep to leave the Eyre HTTP request event.  If the Clay
      ::  write crashes the build, behn retries with the error and
      ::  sleep-or-crud captures it as data instead of crashing.
      ::
      ;<  err=(unit tang)  bind:m  (sleep-or-crud (div ~s1 10))
      ?^  err
        =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
        (pure:m [%error (crip "Clay build failed:\0a{(of-wall:format lines)}")])
      =/  [desk=@t file-path=@t old=@t new=@t]
        %.  [%o args.st]
        %-  ot:dejs:format
        :~  ['desk' so:dejs:format]
            ['path' so:dejs:format]
            ['old_string' so:dejs:format]
            ['new_string' so:dejs:format]
        ==
      =/  dek=@tas  (slav %tas desk)
      =/  pax=path  (stab file-path)
      ?~  pax
        (pure:m [%error 'Empty path'])
      =/  mark=@tas  (rear pax)
      ::  Read current file content
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ;<  =riot:clay  bind:m
        (warp:io our.bowl dek ~ %sing %x da+now.bowl pax)
      ?~  riot
        (pure:m [%error (crip "File not found: {(trip file-path)}")])
      =/  =tang  (pretty-file:pretty-file !<(noun q.r.u.riot))
      =/  =wain
        %-  zing
        %+  turn  tang
        |=(=tank (turn (wash [0 160] tank) crip))
      =/  text=tape  (trip (of-wain:format wain))
      ::  Find and replace
      =/  old-tape=tape  (trip old)
      =/  idx=(unit @ud)  (find old-tape text)
      ?~  idx
        (pure:m [%error 'old_string not found in file'])
      ::  Check for multiple matches
      =/  rest=tape  (slag (add u.idx (lent old-tape)) text)
      ?.  =(~ (find old-tape rest))
        (pure:m [%error 'old_string matches multiple times; provide more context'])
      ::  Build new content
      =/  new-tape=tape  (trip new)
      =/  before=tape  (scag u.idx text)
      =/  after=tape  (slag (add u.idx (lent old-tape)) text)
      =/  result=@t  (crip (zing ~[before new-tape after]))
      ::  Get initial version
      ;<  initial=cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
      ::  Checkpoint: save state before writing
      =/  write-data=json
        %-  pairs:enjs:format
        :~  ['initial-ud' (numb:enjs:format ud.initial)]
            ['desk' s+desk]
            ['file-path' s+file-path]
            ['logs' a+~]
        ==
      ;<  ~  bind:m
        (replace:io !>([args.st %editing write-data]))
      ::  Subscribe to dill logs
      ;<  ~  bind:m  (send-card:io %pass /dill-logs %arvo %d %logs `~)
      ::  Set timeout
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ;<  ~  bind:m
        (send-card:io %pass /commit-timeout %arvo %b %wait (add now.bowl ~s30))
      ::  Write to Clay via %hood
      ;<  ~  bind:m
        (gall-poke-our:io %hood kiln-info+!>(["" `[dek %& [pax %ins mark !>(result)]~]]))
      ::  Collect logs and finish
      ;<  ~  bind:m  collect-logs
      ;<  ~  bind:m  (send-card:io %pass /dill-logs %arvo %d %logs ~)
      ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
      (finish-clay-write args.st data.st)
        %editing
      (finish-clay-write args.st data.st)
    ==
  --
::
++  tool-nuke-agent
  ^-  tool
  |%
  ++  name  'nuke_agent'
  ++  description  'Permanently wipe the state of a Gall agent'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['agent' [%string 'Agent name (e.g. "chat-store")']]
    ==
  ++  required  ~['agent']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  agent=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['agent' so:dejs:format]
      ==
    =/  agt=@tas  (slav %tas agent)
    ;<  ~  bind:m  (gall-poke-our:io %hood kiln-nuke+!>([agt %.y]))
    (pure:m [%text (crip "Nuked %{(trip agt)}")])
  --
::
++  tool-revive-agent
  ^-  tool
  |%
  ++  name  'revive_agent'
  ++  description  'Revive (re-initialize) a nuked Gall agent'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['agent' [%string 'Agent name (e.g. "chat-store")']]
    ==
  ++  required  ~['agent']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  agent=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['agent' so:dejs:format]
      ==
    =/  agt=@tas  (slav %tas agent)
    ;<  ~  bind:m  (gall-poke-our:io %hood kiln-revive+!>(agt))
    (pure:m [%text (crip "Revived %{(trip agt)}")])
  --
::
++  tool-poke-agent
  ^-  tool
  |%
  ++  name  'poke_agent'
  ++  description  'Poke a Gall agent with data of a specified mark'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['agent' [%string 'Agent name (e.g. "hood")']]
        ['mark' [%string 'Poke mark (e.g. "helm-pass")']]
        ['data' [%string 'Hoon expression for the poke data (e.g. "\'my-password\'")']]
    ==
  ++  required  ~['agent' 'mark' 'data']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [agent=@t mark=@t data=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['agent' so:dejs:format]
          ['mark' so:dejs:format]
          ['data' so:dejs:format]
      ==
    =/  agt=@tas  (slav %tas agent)
    =/  mar=@tas  (slav %tas mark)
    ::  Parse and eval hoon in a mule to catch errors
    =/  res=(each vase tang)
      (mule |.((slap !>(..zuse) (ream data))))
    ?:  ?=(%| -.res)
      =/  lines=wall  (zing (turn (flop p.res) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Bad hoon expression:\0a{(of-wall:format lines)}")])
    ::  Poke and capture nack as data instead of crashing
    ;<  err=(unit tang)  bind:m
      (gall-poke-or-nack:io agt mar^p.res)
    ?^  err
      =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
      (pure:m [%error (crip "Poke nacked:\0a{(of-wall:format lines)}")])
    (pure:m [%text (crip "Poked %{(trip agt)} with %{(trip mar)}")])
  --
::
++  tool-mount-desk
  ^-  tool
  |%
  ++  name  'mount_desk'
  ++  description  'Mount a desk to the Unix filesystem'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Desk name (e.g. "base")']]
    ==
  ++  required  ~['desk']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  desk=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (gall-poke-our:io %hood kiln-mount+!>([/(scot %p our.bowl)/[dek]/(scot %da now.bowl) dek]))
    (pure:m [%text (crip "Mounted %{(trip dek)}")])
  --
::
++  tool-install-app
  ^-  tool
  |%
  ++  name  'install_app'
  ++  description  'Install a desk (local or from a remote ship)'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Desk name to install']]
        ['ship' [%string 'Source ship (optional, defaults to own ship)']]
    ==
  ++  required  ~['desk']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  desk=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  src=@p
      ?~  ship-json=(~(get by args.st) 'ship')
        our.bowl
      ?.  ?=([%s *] u.ship-json)  our.bowl
      (slav %p p.u.ship-json)
    ;<  ~  bind:m  (gall-poke-our:io %hood kiln-install+!>([dek src dek]))
    (pure:m [%text (crip "Installing %{(trip dek)} from {<src>}")])
  --
::
++  tool-toggle-permissions
  ^-  tool
  |%
  ++  name  'toggle_permissions'
  ++  description  'Make Clay nodes public or private (for publishing desks as apps)'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['desk' [%string 'Desk name']]
        ['path' [%string 'Path within desk (e.g. "/")']]
        ['public' [%boolean 'Whether to make public (true) or private (false)']]
    ==
  ++  required  ~['desk' 'path' 'public']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  desk=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['desk' so:dejs:format]
      ==
    =/  dek=@tas  (slav %tas desk)
    =/  pax=path
      (stab (~(dog jo:json-utils [%o args.st]) /path so:dejs:format))
    =/  pub=?
      (~(dog jo:json-utils [%o args.st]) /public bo:dejs:format)
    ;<  ~  bind:m
      (gall-poke-our:io %hood kiln-permission+!>([dek pax pub]))
    =/  status=tape  ?:(pub "public" "private")
    (pure:m [%text (crip "Set %{(trip dek)}{(spud pax)} to {status}")])
  --
::  Collect dill logs with debounce: returns ~1s after last log.
::  Each log spawns a quiet timer tagged with log count. If 1s passes
::  with no new logs, we're done. Main timeout is the hard backstop.
::
+$  commit-event
  $%  [%timeout ~]
      [%quiet count=@ud]
      [%log =told:dill]
  ==
::
++  take-commit-event
  =/  m  (fiber:fiber:nexus ,commit-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %arvo [%commit-timeout ~] %behn %wake *]
    [%done %timeout ~]
      [~ %arvo [%commit-quiet @ ~] %behn %wake *]
    [%done %quiet (slav %ud i.t.wire.u.in)]
      [~ %arvo [%dill-logs ~] %dill %logs *]
    [%done %log told.sign.u.in]
  ==
::
++  collect-logs
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  =commit-event  bind:m  take-commit-event
  ?-    -.commit-event
      %timeout  (pure:m ~)
      %quiet
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    ?.  =(count.commit-event (lent logs))
      $  :: stale timer, keep waiting
    (pure:m ~)
      %log
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    =/  log-text=tape  (format-told told.commit-event)
    =/  new-data=json
      (~(put jo:json-utils data.st) /logs a+[s+(crip log-text) logs])
    =/  new-count=@ud  +((lent logs))
    ;<  ~  bind:m  (replace:io !>([args.st step.st new-data]))
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ;<  ~  bind:m
      (send-card:io %pass /commit-quiet/(scot %ud new-count) %arvo %b %wait (add now.bowl ~s1))
    $
  ==
::  Format a dill told to text
::
++  format-told
  |=  log=told:dill
  ^-  tape
  ?-  -.log
      %crud
    =/  err-lines=wall  (zing (turn (flop q.log) (cury wash [0 80])))
    =/  lines-text=tape
      %-  zing
      %+  turn  err-lines
      |=(line=tape "{line}\0a")
    "ERROR [{<p.log>}]:\0a{lines-text}"
      %talk
    =/  talk-lines=wall  (zing (turn p.log (cury wash [0 80])))
    %-  zing
    %+  turn  talk-lines
    |=(line=tape "{line}\0a")
      %text
    "{p.log}\0a"
  ==
::
++  tool-send-telegram
  ^-  tool
  |%
  ++  name  'send_telegram'
  ++  description  'Send a Telegram message. Requires config/creds/telegram with bot-token and chat-id.'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['message' [%string 'Message to send']]
    ==
  ++  required  ~['message']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  message=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['message' so:dejs:format]
      ==
    ::  Read telegram config from ball
    ;<  creds-seen=seen:nexus  bind:m
      (peek:io /creds [%& %& /config/creds 'telegram'] ~)
    ?.  ?=([%& %file *] creds-seen)
      (pure:m [%error 'Telegram credentials not configured. Create config/creds/telegram with bot-token and chat-id.'])
    =/  jon=json  !<(json q.cage.p.creds-seen)
    =/  bot-token=@t  (~(dog jo:json-utils jon) /bot-token so:dejs:format)
    =/  chat-id=@t  (~(dog jo:json-utils jon) /chat-id so:dejs:format)
    ::  POST to Telegram Bot API
    =/  url=@t
      (crip "{(trip 'https://api.telegram.org/bot')}{(trip bot-token)}/sendMessage")
    =/  body=@t
      (rap 3 ~['chat_id=' chat-id '&text=' message])
    =/  =request:http
      :*  %'POST'
          url
          ~[['content-type' 'application/x-www-form-urlencoded']]
          `(as-octs:mimes:html body)
      ==
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      (pure:m [%error 'Telegram request failed'])
    =/  code=@ud  status-code.response-header.client-response
    ?.  =(200 code)
      (pure:m [%error (crip "Telegram API error: HTTP {<code>}")])
    (pure:m [%text 'Telegram message sent'])
  --
::
++  tool-browse
  ^-  tool
  |%
  ++  name  'browse'
  ++  description  'List files and subdirectories at a path in the grubbery ball'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory path (e.g. "/" or "/config/creds")']]
    ==
  ++  required  ~['path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  dir-path=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
      ==
    =/  pax=path  (stab dir-path)
    ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| pax] ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error (crip "Directory not found: {(trip dir-path)}")])
    =/  neck-text=tape
      ?~  fil.ball.p.seen  ""
      ?~  neck.u.fil.ball.p.seen  ""
      "\0aNexus: {(trip u.neck.u.fil.ball.p.seen)}"
    =/  sub-dirs=(list @ta)  ~(tap in ~(key by dir.ball.p.seen))
    =/  files=(list [@ta @tas])
      ?~  fil.ball.p.seen  ~
      %+  turn  ~(tap by contents.u.fil.ball.p.seen)
      |=([n=@ta c=content:tarball] [n p.cage.c])
    =/  dir-text=tape
      ?~  sub-dirs  ""
      %-  zing
      %+  turn  sub-dirs
      |=(d=@ta "\0a  {(trip d)}/")
    =/  file-text=tape
      ?~  files  ""
      %-  zing
      %+  turn  files
      |=([n=@ta m=@tas] "\0a  {(trip n)}.{(trip m)}")
    (pure:m [%text (crip "{(trip dir-path)}{neck-text}{dir-text}{file-text}")])
  --
::
++  tool-glob
  ^-  tool
  |%
  ++  name  'glob'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search for files in the grubbery ball by path, name, and/or mark. "
      "All patterns support * wildcards. All filters are optional; "
      "omitted filters match everything."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory path pattern (e.g. "/tools/*", "/config")']]
        ['name' [%string 'Filename pattern without extension (e.g. "config*", "*test*")']]
        ['mark' [%string 'Mark/extension pattern (e.g. "hoon", "pdf", "mime")']]
    ==
  ++  required  ~
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  pat-path=(unit @t)
      ?~  p=(~(get by args.st) 'path')  ~
      ?.  ?=([%s *] u.p)  ~
      ?:  =('' p.u.p)  ~
      `p.u.p
    =/  pat-name=(unit @t)
      ?~  n=(~(get by args.st) 'name')  ~
      ?.  ?=([%s *] u.n)  ~
      ?:  =('' p.u.n)  ~
      `p.u.n
    =/  pat-mark=(unit @t)
      ?~  mk=(~(get by args.st) 'mark')  ~
      ?.  ?=([%s *] u.mk)  ~
      ?:  =('' p.u.mk)  ~
      `p.u.mk
    ::  Browse root to get entire ball
    ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| ~] ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read ball'])
    ::  Flatten ball to list of [rail content] pairs
    =/  all-files=(list [rail:tarball content:tarball])
      ~(tap ba:tarball ball.p.seen)
    ::  Filter by patterns
    =/  matches=(list [rail:tarball @tas])
      %+  murn  all-files
      |=  [=rail:tarball =content:tarball]
      =/  file-path=tape  ?~(path.rail "/" (trip (spat path.rail)))
      =/  file-name=tape  (trip name.rail)
      =/  file-mark=tape  (trip p.cage.content)
      =/  path-ok=?
        ?~  pat-path  %.y
        (glob-match (trip u.pat-path) file-path)
      =/  name-ok=?
        ?~  pat-name  %.y
        (glob-match (trip u.pat-name) file-name)
      =/  mark-ok=?
        ?~  pat-mark  %.y
        (glob-match (trip u.pat-mark) file-mark)
      ?.  ?&(path-ok name-ok mark-ok)  ~
      `[rail p.cage.content]
    ?~  matches
      (pure:m [%text 'No matches found'])
    =/  result=tape
      %-  zing
      %+  turn  matches
      |=  [=rail:tarball mark=@tas]
      =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
      "\0a{pax}/{(trip name.rail)}.{(trip mark)}"
    (pure:m [%text (crip "Found {<(lent matches)>} matches:{result}")])
  --
::
++  tool-grep
  ^-  tool
  |%
  ++  name  'grep'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Search file contents in the grubbery ball for a string. "
      "Returns matching lines with file paths and line numbers. "
      "Optionally filter which files to search by path, name, or mark pattern."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['pattern' [%string 'Text string to search for']]
        ['path' [%string 'Directory path pattern to filter files (e.g. "/config/*")']]
        ['name' [%string 'Filename pattern to filter (e.g. "*config*")']]
        ['mark' [%string 'Mark/extension pattern to filter (e.g. "hoon", "txt")']]
    ==
  ++  required  ~['pattern']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  search=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['pattern' so:dejs:format]
      ==
    =/  pat-path=(unit @t)
      ?~  p=(~(get by args.st) 'path')  ~
      ?.  ?=([%s *] u.p)  ~
      ?:  =('' p.u.p)  ~
      `p.u.p
    =/  pat-name=(unit @t)
      ?~  n=(~(get by args.st) 'name')  ~
      ?.  ?=([%s *] u.n)  ~
      ?:  =('' p.u.n)  ~
      `p.u.n
    =/  pat-mark=(unit @t)
      ?~  mk=(~(get by args.st) 'mark')  ~
      ?.  ?=([%s *] u.mk)  ~
      ?:  =('' p.u.mk)  ~
      `p.u.mk
    =/  search-tape=tape  (trip search)
    ::  Browse root to get entire ball
    ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| ~] ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error 'Could not read ball'])
    ::  Flatten and filter by metadata patterns
    =/  candidates=(list [rail:tarball content:tarball])
      %+  skim  ~(tap ba:tarball ball.p.seen)
      |=  [=rail:tarball =content:tarball]
      =/  file-path=tape  ?~(path.rail "/" (trip (spat path.rail)))
      =/  file-name=tape  (trip name.rail)
      =/  file-mark=tape  (trip p.cage.content)
      ?&  ?~(pat-path %.y (glob-match (trip u.pat-path) file-path))
          ?~(pat-name %.y (glob-match (trip u.pat-name) file-name))
          ?~(pat-mark %.y (glob-match (trip u.pat-mark) file-mark))
      ==
    ::  Search each candidate file for the pattern
    =|  results=(list tape)
    =/  total-matches=@ud  0
    |-
    ?~  candidates
      ?~  results
        (pure:m [%text 'No matches found'])
      =/  out=tape  (zing (flop results))
      (pure:m [%text (crip "Found {<total-matches>} matches:{out}")])
    =/  [=rail:tarball =content:tarball]  i.candidates
    =/  file-label=tape
      =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
      "{pax}/{(trip name.rail)}.{(trip p.cage.content)}"
    ::  Try to read file content as text
    ;<  file-seen=seen:nexus  bind:m
      (peek:io /read [%& %& path.rail name.rail] ~)
    ?.  ?=([%& %file *] file-seen)
      $(candidates t.candidates)
    ;<  =mime  bind:m  (cage-to-mime:io cage.p.file-seen)
    =/  text=tape  (trip ;;(@t q.q.mime))
    ::  Split into lines and search
    =/  lines=(list tape)
      %+  roll  (flop text)
      |=  [c=@t acc=(list tape)]
      ?~  acc
        ?:  =(c 10)  ["" ~]
        [(trip c) ~]
      ?:  =(c 10)  ["" acc]
      [[(weld (trip c) i.acc) t.acc]]
    =/  line-num=@ud  1
    =/  file-matches=(list tape)  ~
    |-
    ?~  lines
      =/  new-results=(list tape)
        ?~  file-matches  results
        (weld (flop file-matches) results)
      ^$(candidates t.candidates, results new-results, total-matches (add total-matches (lent file-matches)))
    =/  hit=?  !=(~ (find search-tape i.lines))
    =?  file-matches  hit
      :_  file-matches
      "\0a{file-label}:{<line-num>}: {i.lines}"
    $(lines t.lines, line-num +(line-num))
  --
::
++  tool-read-grub
  ^-  tool
  |%
  ++  name  'read_grub'
  ++  description  'Read a grub (file) from the grubbery ball. Returns JSON content directly, other marks as text.'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory path (e.g. "/config/creds")']]
        ['name' [%string 'Grub filename (e.g. "telegram.json")']]
    ==
  ++  required  ~['path' 'name']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [file-path=@t file-name=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
      ==
    =/  pax=path  (stab file-path)
    ;<  [grub-name=@ta =seen:nexus]  bind:m
      (lookup-grub pax file-name)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip file-path)}/{(trip file-name)}")])
    (render-grub-content seen)
  --
::  Render grub content as text for tool output
::
++  render-grub-content
  |=  =seen:nexus
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?>  ?=([%& %file *] seen)
  =/  =cage  cage.p.seen
  ?+  p.cage
    ::  Fallback: scry for tube to mime via %cc
    ;<  =desk  bind:m  get-desk:io
    ;<  convert=tube:clay  bind:m
      (do-scry:io tube:clay /tube /cc/[desk]/[p.cage]/mime)
    =/  result-vase=vase  (convert q.cage)
    =/  out=mime  !<(mime result-vase)
    (pure:m [%text (crip (trip q.q.out))])
      %json
    (pure:m [%text (en:json:html !<(json q.cage))])
      %txt
    (pure:m [%text (of-wain:format !<(wain q.cage))])
      %hoon
    (pure:m [%text !<(@t q.cage)])
      %mime
    =/  out=mime  !<(mime q.cage)
    (pure:m [%text (crip (trip q.q.out))])
  ==
::  Look up a grub by name, trying direct then stripping extension
::  Returns [actual-grub-name seen]
::
++  lookup-grub
  |=  [pax=path file-name=@ta]
  =/  m  (fiber:fiber:nexus ,[name=@ta seen=seen:nexus])
  ^-  form:m
  ;<  =seen:nexus  bind:m
    (peek:io /read [%& %& pax file-name] ~)
  ?:  ?=([%& %file *] seen)
    (pure:m [file-name seen])
  =/  ext=(unit @ta)  (parse-extension:tarball file-name)
  ?~  ext
    (pure:m [file-name seen])
  =/  base=@ta
    =/  et=tape  (trip u.ext)
    =/  ft=tape  (trip file-name)
    (crip (scag (sub (lent ft) (add 1 (lent et))) ft))
  ;<  seen2=seen:nexus  bind:m
    (peek:io /read-base [%& %& pax base] ~)
  (pure:m [base seen2])
::  String replacement on tapes
::  Returns (unit tape) — ~ if not found or ambiguous
::
++  tape-replace
  |=  [txt=tape old=tape new=tape all=?]
  ^-  (each tape @tas)
  =/  old-len=@ud  (lent old)
  ?:  =(0 old-len)  [%| %empty-search]
  =/  idx=(unit @ud)  (find old txt)
  ?~  idx  [%| %not-found]
  ?.  all
    ::  Single replace: verify uniqueness
    =/  after=@ud  (add u.idx old-len)
    =/  rest=tape  (slag after txt)
    ?^  (find old rest)  [%| %not-unique]
    :-  %&
    :(weld (scag u.idx txt) new (slag after txt))
  ::  Replace all occurrences
  =|  acc=tape
  =/  src=tape  txt
  |-
  =/  hit=(unit @ud)  (find old src)
  ?~  hit  [%& (weld acc src)]
  %=  $
    acc  :(weld acc (scag u.hit src) new)
    src  (slag (add u.hit old-len) src)
  ==
::
++  tool-delete-grub
  ^-  tool
  |%
  ++  name  'delete_grub'
  ++  description  'Delete a grub (file) from the grubbery ball'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory containing the grub (e.g. "/mcp/tools")']]
        ['name' [%string 'Grub filename to delete']]
    ==
  ++  required  ~['path' 'name']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [file-path=@t file-name=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
      ==
    ;<  ~  bind:m  (cull:io /delete [%& %& (stab file-path) file-name])
    (pure:m [%text (crip "Deleted {(trip file-path)}/{(trip file-name)}")])
  --
::
++  tool-create-folder
  ^-  tool
  |%
  ++  name  'create_folder'
  ++  description  'Create a folder in the grubbery ball. Optionally set a nexus (neck) by providing a name like "mydir.nexus-name".'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Parent directory path (e.g. "/")']]
        ['name' [%string 'Folder name. Append .nexus to set a neck (e.g. "chat.claude" creates folder "chat" with nexus "claude")']]
    ==
  ++  required  ~['path' 'name']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [parent-path=@t folder-name=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
      ==
    =/  dir-ext=(unit @ta)  (parse-extension:tarball folder-name)
    =/  [dir-name=@ta dir-neck=(unit neck:tarball)]
      ?~  dir-ext  [folder-name ~]
      =/  ext-text=tape  (trip u.dir-ext)
      =/  full-text=tape  (trip folder-name)
      =/  name-len=@ud  (sub (lent full-text) (add 1 (lent ext-text)))
      [(crip (scag name-len full-text)) `u.dir-ext]
    =/  folder-path=path  (snoc (stab parent-path) dir-name)
    =/  new-ball=ball:tarball  [`[~ dir-neck ~] ~]
    ;<  ~  bind:m  (make:io /mkdir [%& %| folder-path] &+[*sand:nexus new-ball] ~)
    =/  neck-msg=tape  ?~(dir-neck "" " (nexus: {(trip u.dir-neck)})")
    (pure:m [%text (crip "Created folder {(spud folder-path)}{neck-msg}")])
  --
::
++  tool-delete-folder
  ^-  tool
  |%
  ++  name  'delete_folder'
  ++  description  'Delete a folder and all its contents from the grubbery ball'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Path of the folder to delete (e.g. "/old/stuff")']]
    ==
  ++  required  ~['path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  folder-path=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
      ==
    ;<  ~  bind:m  (cull:io /delete [%& %| (stab folder-path)])
    (pure:m [%text (crip "Deleted folder {(trip folder-path)}")])
  --
::
++  tool-create-symlink
  ^-  tool
  |%
  ++  name  'create_symlink'
  ++  description  'Create a symlink in the grubbery ball. Target is an absolute path like "/some/file" or a relative path like "^^/sibling".'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory to create the symlink in (e.g. "/")']]
        ['name' [%string 'Symlink name']]
        ['target' [%string 'Target path (e.g. "/some/path" for absolute, "^^/sibling" for relative)']]
    ==
  ++  required  ~['path' 'name' 'target']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [link-path=@t link-name=@t target=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
          ['target' so:dejs:format]
      ==
    =/  sym=(unit symlink:tarball)  (parse-symlink:tarball target)
    ?~  sym
      (pure:m [%error (crip "Invalid symlink target: {(trip target)}")])
    ;<  ~  bind:m
      (make:io /symlink [%& %& (stab link-path) link-name] |+[%symlink !>(u.sym)] ~)
    (pure:m [%text (crip "Created symlink {(trip link-path)}/{(trip link-name)} -> {(trip target)}")])
  --
::
++  tool-add-weir
  ^-  tool
  |%
  ++  name  'add_weir'
  ++  description  'Add a sandbox (weir) rule to a directory. Categories: write, poke, read. Road types: dir, file.'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory to add the weir rule to (e.g. "/mcp")']]
        ['category' [%string 'Rule category: "write", "poke", or "read"']]
        ['road_path' [%string 'Allowed road path (e.g. "/")']]
        ['road_type' [%string 'Road type: "dir" or "file"']]
    ==
  ++  required  ~['path' 'category' 'road_path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [weir-path=@t category=@t road-path=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['category' so:dejs:format]
          ['road_path' so:dejs:format]
      ==
    =/  road-type=@t
      ?~  rt=(~(get by args.st) 'road_type')  'dir'
      ?.  ?=([%s *] u.rt)  'dir'
      p.u.rt
    =/  pax=path  (stab road-path)
    =/  new-road=road:tarball
      ?:  =('file' road-type)
        ?~  pax  [%& %| /]
        [%& %& (snip `path`pax) (rear pax)]
      [%& %| pax]
    =/  dir-pax=path  (stab weir-path)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /weir [%& %| dir-pax] ~)
    =/  cur=weir:nexus
      ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
      =/  dir-sand=sand:nexus  sand.p.dir-seen
      (fall fil.dir-sand [~ ~ ~])
    =/  new=weir:nexus
      ?+  category  cur
        %'write'  cur(make (~(put in make.cur) new-road))
        %'poke'   cur(poke (~(put in poke.cur) new-road))
        %'read'   cur(peek (~(put in peek.cur) new-road))
      ==
    ;<  ~  bind:m  (sand:io /weir [%& %| dir-pax] `new)
    (pure:m [%text (crip "Added {(trip category)} rule to {(trip weir-path)}")])
  --
::
++  tool-del-weir
  ^-  tool
  |%
  ++  name  'del_weir'
  ++  description  'Remove a sandbox (weir) rule from a directory'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory to remove the weir rule from']]
        ['category' [%string 'Rule category: "write", "poke", or "read"']]
        ['road_path' [%string 'Road path to remove']]
        ['road_type' [%string 'Road type: "dir" or "file"']]
    ==
  ++  required  ~['path' 'category' 'road_path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [weir-path=@t category=@t road-path=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['category' so:dejs:format]
          ['road_path' so:dejs:format]
      ==
    =/  road-type=@t
      ?~  rt=(~(get by args.st) 'road_type')  'dir'
      ?.  ?=([%s *] u.rt)  'dir'
      p.u.rt
    =/  pax=path  (stab road-path)
    =/  del-road=road:tarball
      ?:  =('file' road-type)
        ?~  pax  [%& %| /]
        [%& %& (snip `path`pax) (rear pax)]
      [%& %| pax]
    =/  dir-pax=path  (stab weir-path)
    ;<  dir-seen=seen:nexus  bind:m  (peek:io /weir [%& %| dir-pax] ~)
    =/  cur=weir:nexus
      ?.  ?=([%& %ball *] dir-seen)  [~ ~ ~]
      =/  dir-sand=sand:nexus  sand.p.dir-seen
      (fall fil.dir-sand [~ ~ ~])
    =/  new=weir:nexus
      ?+  category  cur
        %'write'  cur(make (~(del in make.cur) del-road))
        %'poke'   cur(poke (~(del in poke.cur) del-road))
        %'read'   cur(peek (~(del in peek.cur) del-road))
      ==
    ;<  ~  bind:m  (sand:io /weir [%& %| dir-pax] `new)
    (pure:m [%text (crip "Removed {(trip category)} rule from {(trip weir-path)}")])
  --
::
++  tool-clear-weir
  ^-  tool
  |%
  ++  name  'clear_weir'
  ++  description  'Clear all sandbox (weir) rules from a directory, giving it unrestricted access'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory to clear the weir from']]
    ==
  ++  required  ~['path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  weir-path=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
      ==
    ;<  ~  bind:m  (sand:io /weir [%& %| (stab weir-path)] ~)
    (pure:m [%text (crip "Cleared weir from {(trip weir-path)}")])
  --
::
++  tool-write-grub
  ^-  tool
  |%
  ++  name  'write_grub'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Write a text file to the grubbery ball. "
      "Mark is detected from filename extension "
      "(e.g. .hoon, .txt, .json). Falls back to %txt if unknown. "
      "Set content_type to store as raw mime (e.g. \"text/html\"). "
      "Set mark to convert from mime to a specific mark (e.g. \"hoon\"). "
      "When using mark, omit the extension from the filename — the mark becomes the extension."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory path (e.g. "/")']]
        ['name' [%string 'Filename with extension (e.g. "foo.hoon", "notes.txt"). Omit extension when using mark parameter.']]
        ['content' [%string 'Text content to write']]
        ['content_type' [%string 'MIME content type (e.g. "text/html"). When set, stores as raw mime.']]
        ['mark' [%string 'Destination mark (e.g. "hoon", "txt"). Converts from mime to this mark via warm tube.']]
    ==
  ++  required  ~['path' 'name' 'content']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [file-path=@t file-name=@t content=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
          ['content' so:dejs:format]
      ==
    =/  content-type=(unit @t)
      ?~  ct=(~(get by args.st) 'content_type')  ~
      ?.  ?=([%s *] u.ct)  ~
      ?:  =('' p.u.ct)  ~
      `p.u.ct
    =/  dest-mark=(unit @tas)
      ?~  mk=(~(get by args.st) 'mark')  ~
      ?.  ?=([%s *] u.mk)  ~
      ?:  =('' p.u.mk)  ~
      `p.u.mk
    =/  ext=(unit @ta)  (parse-extension:tarball file-name)
    ::  Strip extension from filename for grub name
    =/  grub-name=@ta
      ?~  ext  file-name
      =/  et=tape  (trip u.ext)
      =/  ft=tape  (trip file-name)
      (crip (scag (sub (lent ft) (add 1 (lent et))) ft))
    =/  pax=path  (stab file-path)
    =/  road=road:tarball  [%& %& pax grub-name]
    ::  Explicit content_type: store as raw mime with that content-type
    ?^  content-type
      =/  mtype=path  (stab (cat 3 '/' u.content-type))
      =/  src-mime=mime  [mtype (as-octs:mimes:html content)]
      ;<  exists=?  bind:m  (peek-exists:io /check road)
      ?:  exists
        ;<  ~  bind:m  (over:io /write road mime+!>(src-mime))
        (pure:m [%text (crip "Wrote {(trip file-path)}/{(trip file-name)} [{(trip u.content-type)}]")])
      ;<  ~  bind:m  (make:io /write road |+mime+!>(src-mime) ~)
      (pure:m [%text (crip "Created {(trip file-path)}/{(trip file-name)} [{(trip u.content-type)}]")])
    ::  Build mime cage from content
    =/  src-mime=mime  [/text/plain (as-octs:mimes:html content)]
    ;<  exists=?  bind:m  (peek-exists:io /check road)
    ?:  exists
      ::  Existing file: %over converts mime to file's mark via warm tube
      ;<  ~  bind:m  (over:io /write road mime+!>(src-mime))
      (pure:m [%text (crip "Wrote {(trip file-path)}/{(trip file-name)}")])
    ::  New file: pass dest-mark so runtime converts mime before storing.
    ::  If no mark specified, stores as mime.
    ;<  ~  bind:m  (make:io /write road |+mime+!>(src-mime) dest-mark)
    =/  mark-msg=tape  ?~(dest-mark "mime" (trip u.dest-mark))
    (pure:m [%text (crip "Created {(trip file-path)}/{(trip file-name)} [{mark-msg}]")])
  --
::
++  tool-edit-file
  ^-  tool
  |%
  ++  name  'edit_file'
  ++  description
    ^~  %-  crip
    ;:  weld
      "Edit a text file in the grubbery ball via exact string replacement. "
      "Fails if old_string is not found or is ambiguous (multiple matches). "
      "Works with any mark that has a text/mime conversion."
    ==
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Directory path (e.g. "/")']]
        ['name' [%string 'Filename (e.g. "foo.hoon")']]
        ['old_string' [%string 'The exact text to find and replace']]
        ['new_string' [%string 'The replacement text']]
        ['replace_all' [%boolean 'Replace all occurrences (default: false)']]
    ==
  ++  required  ~['path' 'name' 'old_string' 'new_string']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [file-path=@t file-name=@t old-string=@t new-string=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
          ['old_string' so:dejs:format]
          ['new_string' so:dejs:format]
      ==
    =/  replace-all=?
      =/  ra  (~(get by args.st) 'replace_all')
      ?~  ra  %.n
      ?:  ?=([%b *] u.ra)  p.u.ra
      %.n
    =/  pax=path  (stab file-path)
    ::  Look up the grub
    ;<  [grub-name=@ta =seen:nexus]  bind:m
      (lookup-grub pax file-name)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip file-path)}/{(trip file-name)}")])
    =/  original-mark=@tas  p.cage.p.seen
    ::  Convert to text via mime
    ;<  =mime  bind:m  (cage-to-mime:io cage.p.seen)
    =/  txt=tape  (trip q.q.mime)
    ::  Do replacement
    =/  result=(each tape @tas)
      (tape-replace txt (trip old-string) (trip new-string) replace-all)
    ?.  ?=(%& -.result)
      ?+  p.result
        (pure:m [%error 'Edit failed'])
          %not-found
        (pure:m [%error 'old_string not found in file'])
          %not-unique
        (pure:m [%error 'old_string matches multiple locations. Provide more context to make it unique, or set replace_all.'])
          %empty-search
        (pure:m [%error 'old_string cannot be empty'])
      ==
    ::  Send edited text back via %over — runtime handles mark conversion
    =/  new-mime=^mime  [/text/plain (as-octs:mimes:html (crip p.result))]
    =/  road=road:tarball  [%& %& pax grub-name]
    ;<  ~  bind:m  (over:io /edit road mime+!>(new-mime))
    (pure:m [%text (crip "Edited {(trip file-path)}/{(trip file-name)}")])
  --
::  S3 credential type
::
+$  s3-creds
  $:  access-key=@t
      secret-key=@t
      region=@t
      endpoint=@t
      bucket=@t
  ==
::  Read S3 credentials from config/creds/s3
::
++  read-s3-creds
  =/  m  (fiber:fiber:nexus ,s3-creds)
  ^-  form:m
  ;<  creds-seen=seen:nexus  bind:m
    (peek:io /creds [%& %& /config/creds 's3'] ~)
  ?.  ?=([%& %file *] creds-seen)
    ~|  %s3-creds-not-found
    !!
  =/  jon=json  !<(json q.cage.p.creds-seen)
  =/  creds=s3-creds
    %.  jon
    %-  ot:dejs:format
    :~  ['access-key' so:dejs:format]
        ['secret-key' so:dejs:format]
        ['region' so:dejs:format]
        ['endpoint' so:dejs:format]
        ['bucket' so:dejs:format]
    ==
  (pure:m creds)
::
++  tool-s3-list
  ^-  tool
  |%
  ++  name  's3_list'
  ++  description  'List files in S3 bucket'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['prefix' [%string 'S3 key prefix to filter by (optional)']]
    ==
  ++  required  *(list @t)
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  prefix=@t
      ?~  pj=(~(get by args.st) 'prefix')  ''
      ?.  ?=([%s *] u.pj)  ''
      p.u.pj
    ;<  creds=s3-creds  bind:m  read-s3-creds
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ::  Build LIST request
    =/  query-string=@t  (build-list-query:s3 prefix)
    =/  [amz-date=@t payload-hash=@t authorization=@t]
      %:  build-signature:s3
        'GET'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        ''
        query-string
        ~
        now.bowl
      ==
    =/  url=@t  (build-url:s3 endpoint.creds bucket.creds '' `query-string)
    =/  headers=(list [@t @t])  (build-headers:s3 'GET' payload-hash amz-date authorization)
    =/  =request:http  [%'GET' url headers ~]
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    =/  body=@t
      ?+  client-response  ''
        [%finished * [~ [* [p=@ q=@]]]]
      ;;(@t q.data.u.full-file.client-response)
      ==
    =/  keys=(list @t)  (parse-list-response:s3 body)
    ?~  keys
      (pure:m [%text 'No files found'])
    =/  result=tape
      %-  zing
      %+  turn  keys
      |=(k=@t "{(trip k)}\0a")
    (pure:m [%text (crip result)])
  --
::
++  tool-s3-upload
  ^-  tool
  |%
  ++  name  's3_upload'
  ++  description  'Upload a single ball file to S3'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Ball directory path (e.g. "/mydir")']]
        ['name' [%string 'Grub filename (e.g. "notes.txt")']]
        ['s3_key' [%string 'S3 object key (optional, defaults to filename)']]
    ==
  ++  required  ~['path' 'name']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [file-path=@t file-name=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['name' so:dejs:format]
      ==
    =/  s3-key=@t
      ?~  sk=(~(get by args.st) 's3_key')  file-name
      ?.  ?=([%s *] u.sk)  file-name
      ?:  =('' p.u.sk)  file-name
      p.u.sk
    =/  pax=path  (stab file-path)
    ::  Read the file from ball
    ;<  [grub-name=@ta =seen:nexus]  bind:m
      (lookup-grub pax file-name)
    ?.  ?=([%& %file *] seen)
      (pure:m [%error (crip "Not found: {(trip file-path)}/{(trip file-name)}")])
    ::  Convert to text via mime
    ;<  =mime  bind:m  (cage-to-mime:io cage.p.seen)
    =/  text=@t  ;;(@t q.q.mime)
    ::  Get creds and sign
    ;<  creds=s3-creds  bind:m  read-s3-creds
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  [amz-date=@t payload-hash=@t authorization=@t]
      %:  build-signature:s3
        'PUT'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        s3-key
        ''
        `text
        now.bowl
      ==
    =/  url=@t  (build-url:s3 endpoint.creds bucket.creds s3-key ~)
    =/  headers=(list [@t @t])  (build-headers:s3 'PUT' payload-hash amz-date authorization)
    =/  =request:http
      [%'PUT' url headers `(as-octs:mimes:html text)]
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      (pure:m [%error 'S3 upload failed'])
    =/  code=@ud  status-code.response-header.client-response
    ?.  (lth code 300)
      (pure:m [%error (crip "S3 upload error: HTTP {<code>}")])
    (pure:m [%text (crip "Uploaded {(trip file-path)}/{(trip file-name)} to s3://{(trip s3-key)}")])
  --
::
++  tool-s3-upload-directory
  ^-  tool
  |%
  ++  name  's3_upload_directory'
  ++  description  'Upload a ball directory to S3'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['path' [%string 'Ball directory path (e.g. "/mydir")']]
        ['s3_prefix' [%string 'S3 key prefix (e.g. "backups/mydir")']]
    ==
  ++  required  ~['path' 's3_prefix']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [dir-path=@t s3-prefix=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['path' so:dejs:format]
          ['s3_prefix' so:dejs:format]
      ==
    =/  pax=path  (stab dir-path)
    ::  Browse directory to get file listing
    ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| pax] ~)
    ?.  ?=([%& %ball *] seen)
      (pure:m [%error (crip "Directory not found: {(trip dir-path)}")])
    ::  Collect all files recursively from the ball
    ::  Browse returns the subtree at pax, so walk from ~ and prepend pax
    =/  files-to-upload=(list [path @ta])
      %+  turn  (collect-files-recursive:s3 ball.p.seen ~)
      |=([p=path n=@ta] [(weld pax p) n])
    ::  Upload each file
    =/  uploaded=@ud  0
    |-
    ?~  files-to-upload
      (pure:m [%text (crip "Uploaded {<uploaded>} files to s3://{(trip s3-prefix)}")])
    =/  [file-path=path filename=@ta]  i.files-to-upload
    ::  Read file content
    ;<  file-seen=seen:nexus  bind:m
      (peek:io /read [%& %& file-path filename] ~)
    ?.  ?=([%& %file *] file-seen)
      $(files-to-upload t.files-to-upload)
    ::  Convert to text
    ;<  =mime  bind:m  (cage-to-mime:io cage.p.file-seen)
    =/  text=@t  ;;(@t q.q.mime)
    ::  Build S3 key, appending mark as extension
    =/  mark=@tas  p.cage.p.file-seen
    =/  full-name=@ta
      ?:  =(mark %mime)  filename
      (crip "{(trip filename)}.{(trip mark)}")
    =/  relative-path=path
      ?:  =(pax ~)  (snoc file-path full-name)
      (snoc (slag (lent pax) file-path) full-name)
    =/  s3-key=@t
      ?:  =(s3-prefix '')
        (path-to-s3-key:s3 relative-path)
      (crip "{(trip s3-prefix)}/{(trip (path-to-s3-key:s3 relative-path))}")
    ::  Sign and upload
    ;<  creds=s3-creds  bind:m  read-s3-creds
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  [amz-date=@t payload-hash=@t authorization=@t]
      %:  build-signature:s3
        'PUT'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        s3-key
        ''
        `text
        now.bowl
      ==
    =/  url=@t  (build-url:s3 endpoint.creds bucket.creds s3-key ~)
    =/  headers=(list [@t @t])  (build-headers:s3 'PUT' payload-hash amz-date authorization)
    =/  =request:http
      [%'PUT' url headers `(as-octs:mimes:html text)]
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    $(files-to-upload t.files-to-upload, uploaded +(uploaded))
  --
::
++  tool-s3-download
  ^-  tool
  |%
  ++  name  's3_download'
  ++  description  'Download an S3 file to the grubbery ball'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['s3_key' [%string 'S3 object key to download']]
        ['path' [%string 'Ball directory path to save to (e.g. "/downloads")']]
    ==
  ++  required  ~['s3_key' 'path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [s3-key=@t dest-path=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['s3_key' so:dejs:format]
          ['path' so:dejs:format]
      ==
    =/  pax=path  (stab dest-path)
    ;<  creds=s3-creds  bind:m  read-s3-creds
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    ::  Sign GET request
    =/  [amz-date=@t payload-hash=@t authorization=@t]
      %:  build-signature:s3
        'GET'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        s3-key
        ''
        ~
        now.bowl
      ==
    =/  url=@t  (build-url:s3 endpoint.creds bucket.creds s3-key ~)
    =/  headers=(list [@t @t])  (build-headers:s3 'GET' payload-hash amz-date authorization)
    =/  =request:http  [%'GET' url headers ~]
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=([%finished *] client-response)
      (pure:m [%error 'S3 download failed'])
    =/  code=@ud  status-code.response-header.client-response
    ?.  (lth code 300)
      (pure:m [%error (crip "S3 download error: HTTP {<code>}")])
    ?~  full-file.client-response
      (pure:m [%error 'Empty response from S3'])
    =/  content=@t  ;;(@t q.data.u.full-file.client-response)
    ::  Extract filename and parse extension
    =/  filename=@ta  (extract-filename:s3 s3-key)
    =/  ext=(unit @ta)  (parse-extension:tarball filename)
    ::  Strip extension from filename for grub name
    =/  grub-name=@ta
      ?~  ext  filename
      =/  et=tape  (trip u.ext)
      =/  ft=tape  (trip filename)
      (crip (scag (sub (lent ft) (add 1 (lent et))) ft))
    ::  Detect content type from response headers
    =/  response-headers=(list [key=@t value=@t])
      headers.response-header.client-response
    =/  ct=(unit @t)  (extract-content-type:s3 response-headers)
    ::  Build mime from content
    =/  mtype=path  (determine-mime-type:tarball ct filename)
    =/  file-mime=mime  [mtype (as-octs:mimes:html content)]
    =/  road=road:tarball  [%& %& pax grub-name]
    ;<  exists=?  bind:m  (peek-exists:io /check road)
    ?:  exists
      ;<  ~  bind:m  (over:io /write road mime+!>(file-mime))
      (pure:m [%text (crip "Downloaded s3://{(trip s3-key)} to {(trip dest-path)}/{(trip filename)}")])
    ;<  ~  bind:m  (make:io /write road |+mime+!>(file-mime) ext)
    (pure:m [%text (crip "Downloaded s3://{(trip s3-key)} to {(trip dest-path)}/{(trip filename)}")])
  --
::
++  tool-s3-download-directory
  ^-  tool
  |%
  ++  name  's3_download_directory'
  ++  description  'Download all files under an S3 prefix to the grubbery ball'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['s3_prefix' [%string 'S3 key prefix to download (e.g. "backups/mydir")']]
        ['path' [%string 'Ball directory path to save to (e.g. "/downloads")']]
    ==
  ++  required  ~['s3_prefix' 'path']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  [s3-prefix=@t dest-path=@t]
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['s3_prefix' so:dejs:format]
          ['path' so:dejs:format]
      ==
    =/  pax=path  (stab dest-path)
    ;<  creds=s3-creds  bind:m  read-s3-creds
    ::  First list all files under prefix
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  query-string=@t  (build-list-query:s3 s3-prefix)
    =/  [amz-date=@t payload-hash=@t authorization=@t]
      %:  build-signature:s3
        'GET'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        ''
        query-string
        ~
        now.bowl
      ==
    =/  url=@t  (build-url:s3 endpoint.creds bucket.creds '' `query-string)
    =/  headers=(list [@t @t])  (build-headers:s3 'GET' payload-hash amz-date authorization)
    =/  =request:http  [%'GET' url headers ~]
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    =/  body=@t
      ?+  client-response  ''
        [%finished * [~ [* [p=@ q=@]]]]
      ;;(@t q.data.u.full-file.client-response)
      ==
    =/  all-keys=(list @t)  (parse-list-response:s3 body)
    ::  Filter out directory markers (keys ending in /)
    =/  files=(list @t)
      %+  skip  all-keys
      |=(key=@t =((rear (trip key)) '/'))
    ::  Download each file
    =/  downloaded=@ud  0
    |-
    ?~  files
      (pure:m [%text (crip "Downloaded {<downloaded>} files to {(trip dest-path)}")])
    =/  s3-key=@t  i.files
    =/  filename=@ta  (extract-filename:s3 s3-key)
    =/  ext=(unit @ta)  (parse-extension:tarball filename)
    ::  Strip extension from filename for grub name
    =/  grub-name=@ta
      ?~  ext  filename
      =/  et=tape  (trip u.ext)
      =/  ft=tape  (trip filename)
      (crip (scag (sub (lent ft) (add 1 (lent et))) ft))
    ::  Sign GET request
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  [ld-amz-date=@t ld-payload-hash=@t ld-authorization=@t]
      %:  build-signature:s3
        'GET'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        s3-key
        ''
        ~
        now.bowl
      ==
    =/  dl-url=@t  (build-url:s3 endpoint.creds bucket.creds s3-key ~)
    =/  dl-headers=(list [@t @t])  (build-headers:s3 'GET' ld-payload-hash ld-amz-date ld-authorization)
    =/  dl-request=request:http  [%'GET' dl-url dl-headers ~]
    ;<  ~  bind:m  (send-request:io dl-request)
    ;<  dl-response=client-response:iris  bind:m  take-client-response:io
    ?.  ?=([%finished *] dl-response)
      $(files t.files)
    ?~  full-file.dl-response
      $(files t.files)
    =/  content=@t  ;;(@t q.data.u.full-file.dl-response)
    =/  response-headers=(list [key=@t value=@t])
      headers.response-header.dl-response
    =/  ct=(unit @t)  (extract-content-type:s3 response-headers)
    =/  mtype=path  (determine-mime-type:tarball ct filename)
    =/  file-mime=mime  [mtype (as-octs:mimes:html content)]
    =/  road=road:tarball  [%& %& pax grub-name]
    ;<  exists=?  bind:m  (peek-exists:io /check road)
    ?:  exists
      ;<  ~  bind:m  (over:io /write road mime+!>(file-mime))
      $(files t.files, downloaded +(downloaded))
    ;<  ~  bind:m  (make:io /write road |+mime+!>(file-mime) ext)
    $(files t.files, downloaded +(downloaded))
  --
::
++  tool-s3-delete
  ^-  tool
  |%
  ++  name  's3_delete'
  ++  description  'Delete a file from S3'
  ++  parameters
    ^-  (map @t parameter-def)
    %-  ~(gas by *(map @t parameter-def))
    :~  ['s3_key' [%string 'S3 object key to delete']]
    ==
  ++  required  ~['s3_key']
  ++  handler
    ^-  tool-handler
    =/  m  (fiber:fiber:nexus ,tool-result)
    ^-  form:m
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  s3-key=@t
      %.  [%o args.st]
      %-  ot:dejs:format
      :~  ['s3_key' so:dejs:format]
      ==
    ;<  creds=s3-creds  bind:m  read-s3-creds
    ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
    =/  [amz-date=@t payload-hash=@t authorization=@t]
      %:  build-signature:s3
        'DELETE'
        access-key.creds
        secret-key.creds
        region.creds
        endpoint.creds
        bucket.creds
        s3-key
        ''
        ~
        now.bowl
      ==
    =/  url=@t  (build-url:s3 endpoint.creds bucket.creds s3-key ~)
    =/  headers=(list [@t @t])  (build-headers:s3 'DELETE' payload-hash amz-date authorization)
    =/  =request:http  [%'DELETE' url headers ~]
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      (pure:m [%error 'S3 delete failed'])
    =/  code=@ud  status-code.response-header.client-response
    ?.  (lth code 300)
      (pure:m [%error (crip "S3 delete error: HTTP {<code>}")])
    (pure:m [%text (crip "Deleted s3://{(trip s3-key)}")])
  --
--