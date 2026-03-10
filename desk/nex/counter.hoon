::  counter nexus: many auto-incrementing counters identified by @da
::
/+  nexus, tarball, io=fiberio, server, http-utils, feather, nex-server
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
      ::  Create /counters directory if not present
      =?  ball  =(~ (~(get of ball) /counters))
        (~(put of ball) /counters [~ ~ ~])
      ::  Create /ui/views directory if not present
      =?  ball  =(~ (~(get of ball) /ui/views))
        (~(put of ball) /ui/views [~ ~ ~])
      ::  Create /ui/views/page.html if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ui/views %'page.html']))
        (~(put ba:tarball ball) [/ui/views %'page.html'] [~ %manx !>((counter-page ~))])
      ::  Create /ui/main.sig file if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ui %'main.sig']))
        (~(put ba:tarball ball) [/ui %'main.sig'] [~ %sig !>(~)])
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
          ::  /ui/views/page.html: render full page HTML once, persist
          ::
          [[%ui %views ~] %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/views/page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /ctrs (cord-to-road:tarball '../../counters/') ~)
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /ctrs)
        ?.  ?=([%ball *] upd)  $
        =/  counters=(list [@ta @ud])
          =/  =lump:tarball  (fall fil.ball.upd *lump:tarball)
          %+  murn  ~(tap by contents.lump)
          |=  [name=@ta =content:tarball]
          ?.  ?=(%ud p.cage.content)  ~
          `[name !<(@ud q.cage.content)]
        =/  page=manx  (counter-page counters)
        ;<  ~  bind:m  (replace:io !>(page))
        $
          ::  /ui/main.sig: bind /grubbery/counters/ as a separate HTTP
          ::  endpoint and dispatch requests into /ui/requests/.
          ::  Nexuses can bind their own endpoints independently of
          ::  the central /grubbery/api.
          ::
          [[%ui ~] %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/main: failed")
        ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
        =/  prefix=path  (url-prefix (snip path.here.bowl))
        ;<  ~  bind:m  (bind-http:nex-server [~ prefix])
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
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ::  Serve counter page from view grub
        ;<  =seen:nexus  bind:m  (peek:io /peek [%| 2 %& /ui/views %'page.html'] `%mime)
        ?.  ?=([%& %file *] seen)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'View not ready')])
          (pure:m ~)
        =/  =mime  !<(mime q.cage.p.seen)
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
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
::  HTTP response door (road from /ui/requests/* to /ui/main.sig)
::
++  srv  ~(. res:nex-server [%| 1 %& ~ %'main.sig'])
::
++  counter-page
  |=  counters=(list [@ta @ud])
  ^-  manx
  =/  api=tape  "/grubbery/api/file/counter.counter/counters"
  =/  keep=tape  "/grubbery/api/keep/counter.counter/counters"
  =/  js=tape
    ;:  weld
      "var API='{api}';"
      "var KEEP='{keep}';"
      "document.getElementById('create').onclick=function()\{fetch(API+'/'+Date.now().toString(36)+'?mark=ud',\{method:'PUT',headers:\{'Content-Type':'text/plain'},body:'0'})};"
      "function removeCounter(n)\{var e=document.getElementById('c-'+n);if(e)e.remove();if(!document.querySelector('.counter'))document.getElementById('counters').textContent='No counters'}"
      "function deleteCounter(n)\{fetch(API+'/'+n,\{method:'DELETE'});removeCounter(n)}"
      "function upsertCounter(n,v)\{var b=document.getElementById('counters');var e=document.getElementById('c-'+n);if(!e)\{if(b.textContent==='No counters')b.textContent='';e=document.createElement('div');e.id='c-'+n;e.className='counter fc fh g2 p2 b1 br1 jcsb';b.appendChild(e)}e.innerHTML='<div class=\"fc-col\"><span class=\"s7 bold\">'+v+'</span><span class=\"s9 muted\">'+n+'</span></div><button class=\"p-1 b1 br1 hover pointer s9\" onclick=\"deleteCounter(\\x27'+n+'\\x27)\">Delete</button>'}"
      "async function connect()\{try\{var r=await fetch(KEEP+'?mark=txt',\{headers:\{Accept:'text/event-stream'}});var R=r.body.getReader();var d=new TextDecoder();var buf='';while(true)\{var c=await R.read();if(c.done)break;buf+=d.decode(c.value,\{stream:true});var ps=buf.split('\\n\\n');buf=ps.pop();for(var i=0;i<ps.length;i++)\{if(!ps[i].trim())continue;var ev='',data='',ls=ps[i].split('\\n');for(var j=0;j<ls.length;j++)\{if(ls[j].indexOf('event: ')===0)ev=ls[j].slice(7);else if(ls[j].indexOf('data: ')===0)data=ls[j].slice(6)}if(!ev)continue;var sp=ev.indexOf(' ');if(sp<0)continue;var act=ev.slice(0,sp);var nm=ev.slice(sp+2);if(act==='old')continue;if(act==='del')removeCounter(nm);else upsertCounter(nm,data)}}}catch(x)\{}setTimeout(connect,2000)}connect()"
    ==
  ;html
    ;head
      ;title: Grubbery Counters
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  "body \{ font-family: monospace; max-width: 600px; margin: 0 auto; padding: 2rem; } .counter \{ margin-bottom: 0.5rem; } .muted \{ opacity: 0.5; } .fc \{ display: flex; } .fh \{ flex-direction: row; } .fc-col \{ display: flex; flex-direction: column; } .g2 \{ gap: 0.5rem; } .p2 \{ padding: 0.5rem; } .p-1 \{ padding: 0.25rem 0.5rem; } .b1 \{ border: 1px solid #ccc; } .br1 \{ border-radius: 4px; } .jcsb \{ justify-content: space-between; align-items: center; } .s7 \{ font-size: 1.2rem; } .s9 \{ font-size: 0.8rem; } .bold \{ font-weight: bold; } .hover:hover \{ background: #eee; } .pointer \{ cursor: pointer; } .mb2 \{ margin-bottom: 1rem; }"
      ==
    ==
    ;body
      ;h1: Grubbery Counters
      ;button#create.mb2.p2.b1.br1.hover.pointer: + New Counter
      ;div#counters
        ;*  ?~  counters
              =/  empty=manx  ;span: No counters
              ~[empty]
            %+  turn  counters
            |=  [name=@ta val=@ud]
            =/  n=tape  (trip name)
            =/  v=tape  (scow %ud val)
            ;div.counter.fc.fh.g2.p2.b1.br1.jcsb(id "c-{n}")
              ;div.fc-col
                ;span.s7.bold: {v}
                ;span.s9.muted: {n}
              ==
              ;button.p-1.b1.br1.hover.pointer.s9(onclick "deleteCounter('{n}')"): Delete
            ==
      ==
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
