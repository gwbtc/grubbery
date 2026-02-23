::  counter nexus: many auto-incrementing counters identified by @da
::
/+  nexus, tarball, io=fiberio, server, http-utils, feather, nex-server
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      ::  Create /counters directory if not present
      =?  ball  =(~ (~(get of ball) /counters))
        (~(put of ball) /counters [~ ~ ~])
      ::  Create /ui/main file if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ui %main]))
        (~(put ba:tarball ball) [/ui %main] [~ %sig !>(~)])
      ::  Create /ui/requests directory if not present
      =?  ball  =(~ (~(get of ball) /ui/requests))
        (~(put of ball) /ui/requests [~ ~ ~])
      [sand ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /counters/*: each counter ticks up every second
          ::
          [[%counters ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%counter: process failed")
        |-
        ;<  count=@ud  bind:m  (get-state-as:io ,@ud)
        ;<  ~  bind:m  (sleep:io ~s1)
        ;<  ~  bind:m  (replace:io !>(+(count)))
        $
          ::  /ui/main: bind paths and dispatch requests
          ::
          [[%ui ~] %main]
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/main: failed")
        ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
        =/  prefix=path  (url-prefix (snip path.here.bowl))
        ;<  ~  bind:m  (bind-http:nex-server [~ prefix])
        ;<  ~  bind:m  (bind-http:nex-server [~ (weld prefix /delete)])
        ;<  ~  bind:m  (bind-http:nex-server [~ (weld prefix /stream)])
        (http-dispatch:nex-server %counter)
          ::  /ui/requests/*: individual request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
        =/  prefix=path  (url-prefix (snip (snip path.here.bowl)))
        =/  =request-line:server  (parse-request-line:server url.request.req)
        =/  suffix=path  (slag (lent prefix) site.request-line)
        ?+    suffix
          ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
          (pure:m ~)
        ::
            ~
          ?:  ?=(%'POST' method.request.req)
            ::  Create a new counter
            =/  counter-name=@ta  (scot %da now.bowl)
            ;<  ~  bind:m  (make:io /make [%| 2 %& /counters counter-name] |+ud+!>(0))
            ;<  ~  bind:m  (send-simple:srv eyre-id two-oh-four:http-utils)
            (pure:m ~)
          ::  Serve counter page
          =/  bod=octs  (manx-to-octs:server (counter-page prefix))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
          (pure:m ~)
        ::
            [%delete ~]
          ?.  ?=(%'POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] ~])
            (pure:m ~)
          =/  bod=(unit octs)  body.request.req
          ?~  bod
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
            (pure:m ~)
          =/  params=(list [@t @t])  (fall (rush q.u.bod yquy:de-purl:html) ~)
          =/  id=(unit @t)
            |-
            ?~  params  ~
            =/  [key=@t val=@t]  i.params
            ?:  =('id' key)  `val
            $(params t.params)
          ?~  id
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing id')])
            (pure:m ~)
          =/  counter-name=@ta  u.id
          ;<  ~  bind:m  (cull:io /cull [%| 2 %& /counters counter-name])
          ;<  ~  bind:m  (send-simple:srv eyre-id two-oh-four:http-utils)
          (pure:m ~)
        ::
            [%stream ~]
          ?.  (is-sse-request:http-utils req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
            (pure:m ~)
          ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
          ::  Subscribe to /counters directory
          ;<  ~  bind:m  (keep:io /counters [%| 2 %| /counters])
          ::  Start keep-alive timer
          ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
          |-
          ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /counters)
          ?-  -.nw
              %wake
            ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
            ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
            ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
            $
              %news
            =/  =sse-event:http-utils
              [~ `'counters-update' (manx-to-wain:http-utils (render-counters prefix view.nw))]
            =/  data=octs  (sse-encode:http-utils ~[sse-event])
            ;<  ~  bind:m  (send-data:srv eyre-id `data)
            $
          ==
        ==
      ==
    --
|%
::  Derive URL prefix from nexus root path
::  e.g. / -> /grubbery/counters, /foo -> /grubbery/counters/foo
::
++  url-prefix
  |=  root=path
  ^-  path
  (weld /grubbery/counters root)
::  HTTP response door (road from /ui/requests/* to /ui/main)
::
++  srv  ~(. res:nex-server [%| 1 %& ~ %main])
::
++  render-counters
  |=  [prefix=path =view:nexus]
  ^-  manx
  ?.  ?=(%ball -.view)
    ;div#counters: No counters
  =/  files=(list [key=@ta =content:tarball])
    ?~  fil.ball.view  ~
    %+  sort  ~(tap by contents.u.fil.ball.view)
    |=  [[a=@ta *] [b=@ta *]]
    (lth (slav %da a) (slav %da b))
  =/  del-url=tape  (spud (weld prefix /delete))
  ;div#counters
    ;*  %+  turn  files
        |=  [key=@ta =content:tarball]
        ^-  manx
        =/  val=@ud  !<(@ud q.cage.content)
        ;div.counter.fc.fh.g2.p2.b1.br1.jcsb
          ;div.fc-col
            ;span.s7.bold: {(scow %ud val)}
            ;span.s9.muted: {(scow %da (slav %da key))}
          ==
          ;form(hx-post del-url, hx-swap "none")
            ;input(type "hidden", name "id", value (trip key));
            ;button.p-1.b1.br1.hover.pointer.s9(type "submit"): Delete
          ==
        ==
  ==
::
++  counter-page
  |=  prefix=path
  ^-  manx
  =/  base-url=tape  (spud prefix)
  =/  stream-url=tape  (spud (weld prefix /stream))
  ;html
    ;head
      ;title: Grubbery Counters
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;script(src "https://unpkg.com/htmx.org@2.0.3");
      ;script(src "https://unpkg.com/htmx-ext-sse@2.2.2/sse.js");
      ;+  feather:feather
      ;style
        ;+  ;/  "body \{ font-family: monospace; max-width: 600px; margin: 0 auto; padding: 2rem; } .counter \{ margin-bottom: 0.5rem; } .muted \{ opacity: 0.5; } .fc \{ display: flex; } .fh \{ flex-direction: row; } .fc-col \{ display: flex; flex-direction: column; } .g2 \{ gap: 0.5rem; } .p2 \{ padding: 0.5rem; } .p-1 \{ padding: 0.25rem 0.5rem; } .b1 \{ border: 1px solid #ccc; } .br1 \{ border-radius: 4px; } .jcsb \{ justify-content: space-between; align-items: center; } .s7 \{ font-size: 1.2rem; } .s9 \{ font-size: 0.8rem; } .bold \{ font-weight: bold; } .hover:hover \{ background: #eee; } .pointer \{ cursor: pointer; } .mb2 \{ margin-bottom: 1rem; }"
      ==
    ==
    ;body
      ;h1: Grubbery Counters
      ;form.mb2(hx-post base-url, hx-swap "none")
        ;button.p2.b1.br1.hover.pointer(type "submit"): + New Counter
      ==
      ;div(hx-ext "sse", sse-connect stream-url, sse-swap "counters-update")
        ;div#counters: Connecting...
      ==
    ==
  ==
--
