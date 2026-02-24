::  lib/nex/tools: types + built-in tool fibers for the tools nexus
::
::  A $tool is a self-contained unit: metadata (name, description, schema)
::  plus a fiber handler. Built-ins live here; user tools are .hoon files
::  in /tools/tools/ that compile to the same $tool type.
::
/+  nexus, tarball, io=fiberio, json-utils, pretty-file
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
::  Built-in tool registry
::
++  built-ins
  ^-  (map @t tool)
  %-  ~(gas by *(map @t tool))
  :~  ['get_ship' get-ship]
      ['commit' tool-commit]
      ['desk_version' tool-desk-version]
      ['scry' tool-scry]
      ['list_files' tool-list-files]
      ['get_file' tool-get-file]
      ['nuke_agent' tool-nuke-agent]
      ['revive_agent' tool-revive-agent]
      ['mount_desk' tool-mount-desk]
      ['install_app' tool-install-app]
      ['toggle_permissions' tool-toggle-permissions]
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
  =/  mount-point=@tas
    %.  [%o args]
    %-  ot:dejs:format
    :~  ['mount_point' so:dejs:format]
    ==
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
    ;<  result=json  bind:m
      (do-scry:io json /scry (stab path-text))
    (pure:m [%text (en:json:html result)])
  --
::
++  tool-list-files
  ^-  tool
  |%
  ++  name  'list_files'
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
  ++  name  'get_file'
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
--
