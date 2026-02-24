::  lib/nex/mcp: MCP (Model Context Protocol) JSON-RPC 2.0 adapter
::
::  Thin protocol layer that converts tool definitions from lib/nex/tools
::  to MCP JSON-RPC format and routes MCP requests to tool handlers.
::
/+  nexus, tarball, io=fiberio, json-utils, tools=nex-tools
|%
::  JSON-RPC 2.0 error codes
::
++  rpc-parse-error       ~.-32700
++  rpc-invalid-request   ~.-32600
++  rpc-method-not-found  ~.-32601
++  rpc-invalid-params    ~.-32602
++  rpc-internal-error    ~.-32603
::
++  rpc-error
  |=  [code=@ta message=@t id=(unit json)]
  %-  pairs:enjs:format
  %+  welp
    ?~(id ~ ['id' u.id]~)
  :~  ['jsonrpc' s+'2.0']
      :-  'error'
      %-  pairs:enjs:format
      :~  ['code' n+code]
          ['message' s+message]
      ==
  ==
::
++  rpc-result
  |=  [result=json id=(unit json)]
  %-  pairs:enjs:format
  %+  welp
    ?~(id ~ ['id' u.id]~)
  :~  ['jsonrpc' s+'2.0']
      ['result' result]
  ==
::
++  mcp-text-result
  |=  [text=@t id=(unit json)]
  %-  pairs:enjs:format
  %+  welp
    ?~(id ~ ['id' u.id]~)
  :~  ['jsonrpc' s+'2.0']
      :-  'result'
      %-  pairs:enjs:format
      :~  :-  'content'
          :-  %a
          :~  %-  pairs:enjs:format
              :~  ['type' s+'text']
                  ['text' s+text]
              ==
          ==
      ==
  ==
::
++  mcp-initialize
  |=  [server-name=@t version=@t id=(unit json)]
  %-  pairs:enjs:format
  %+  welp
    ?~(id ~ ['id' u.id]~)
  :~  ['jsonrpc' s+'2.0']
      :-  'result'
      %-  pairs:enjs:format
      :~  ['protocolVersion' s+'2024-11-05']
          :-  'capabilities'
          %-  pairs:enjs:format
          :~  :-  'tools'
              (pairs:enjs:format ~[['listChanged' b+%.n]])
          ==
          :-  'serverInfo'
          %-  pairs:enjs:format
          :~  ['name' s+server-name]
              ['version' s+version]
          ==
      ==
  ==
::
++  param-type-to-json
  |=  type=parameter-type:tools
  ^-  @t
  ?-  type
    %string   'string'
    %number   'number'
    %boolean  'boolean'
    %array    'array'
    %object   'object'
  ==
::
++  tool-def-to-mcp
  |=  =tool:tools
  ^-  json
  =/  properties=(map @t json)
    %-  ~(run by parameters:tool)
    |=  param=parameter-def:tools
    %-  pairs:enjs:format
    :~  ['type' s+(param-type-to-json type.param)]
        ['description' s+description.param]
    ==
  =/  required-array=(list json)
    (turn required:tool |=(f=@t s+f))
  %-  pairs:enjs:format
  :~  ['name' s+name:tool]
      ['description' s+description:tool]
      :-  'inputSchema'
      %-  pairs:enjs:format
      :~  ['type' s+'object']
          ['properties' [%o properties]]
          ['required' [%a required-array]]
      ==
  ==
::
++  tool-definitions
  ^-  (list json)
  (turn all-tool-defs:tools tool-def-to-mcp)
::
++  mcp-tools-list
  |=  id=(unit json)
  %-  pairs:enjs:format
  %+  welp
    ?~(id ~ ['id' u.id]~)
  :~  ['jsonrpc' s+'2.0']
      :-  'result'
      %-  pairs:enjs:format
      :~  ['tools' [%a tool-definitions]]
      ==
  ==
::  Main MCP request handler
::
++  handle-request
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  method=(unit json)  (~(get jo:json-utils jon) /method)
  =/  id=(unit json)      (~(get jo:json-utils jon) /id)
  ?+    method
    (pure:m `(rpc-error rpc-method-not-found 'Method not found' id))
  ::
      [~ [%s %'initialize']]
    (pure:m `(mcp-initialize 'urbit-grubbery' '1.0.0' id))
  ::
      [~ [%s %'notifications/initialized']]
    (pure:m ~)
  ::
      [~ [%s %'tools/list']]
    (pure:m `(mcp-tools-list id))
  ::
      [~ [%s %'tools/call']]
    =/  tool-name=(unit json)  (~(get jo:json-utils jon) /params/name)
    ?~  tool-name
      (pure:m `(rpc-error rpc-invalid-params 'Missing tool name' id))
    ?.  ?=([%s *] u.tool-name)
      (pure:m `(rpc-error rpc-invalid-params 'Invalid tool name' id))
    =/  arguments=(unit json)  (~(get jo:json-utils jon) /params/arguments)
    ?~  arguments
      (pure:m `(rpc-error rpc-invalid-params 'Missing arguments' id))
    ?.  ?=([%o *] u.arguments)
      (pure:m `(rpc-error rpc-invalid-params 'Invalid arguments' id))
    =/  resolved=(unit tool:tools)
      (~(get by built-ins:tools) p.u.tool-name)
    ?~  resolved
      (pure:m `(rpc-error rpc-method-not-found 'Unknown tool' id))
    ;<  result=tool-result:tools  bind:m  handler:u.resolved
    ?-  -.result
      %text   (pure:m `(mcp-text-result text.result id))
      %error  (pure:m `(rpc-error rpc-internal-error message.result id))
    ==
  ==
--
