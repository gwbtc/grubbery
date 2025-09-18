/-  dir  /stud/dir
/-  server  /server
!:
=,  grubberyio
|=  [here=path =cone:g]
^-  mime
=;  =manx
  [/text/html (manx-to-octs:server manx)]
=+  !<(=dir (grab-data (need (~(get of cone) /))))
=/  links=(set path)  (sy (murn dir.dir (cury path-from-road here)))
=/  hidden=(list @ta)
  %+  murn  (sort ~(tap in ~(key by dir.cone)) aor)
  |=  name=@ta
  ^-  (unit @ta)
  =/  =path  (need (path-from-road here |+[0 /[name]]))
  ?:((~(has in links) path) ~ [~ name])
;div#root
  ;script(src "https://unpkg.com/htmx.org@2.0.3");
  ;script(src "https://unpkg.com/htmx-ext-sse@2.2.2/sse.js");
  ;div
    ;form
      =hx-post  (spud (weld /grub/poke here))
      =hx-target  "#root"
      =hx-swap  "outerHTML"
      ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
      ;input(type "hidden", name "poke", value "toggle-hidden");
      ;button(type "submit")
        ;span(class "htmx-indicator"): *
        ;span: toggle hidden
      ==
    ==
  ==
  ;div
    ;form
      =hx-post  (spud (weld /grub/poke here))
      =hx-target  "#root"
      =hx-swap  "outerHTML"
      ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
      ;input(type "hidden", name "poke", value "create-symlink");
      ;input(type "hidden", name "type", value "absolute");
      ;input(type "text", name "path");
      ;button(type "submit")
        ;span(class "htmx-indicator"): *
        ;span: create absolute symlink
      ==
    ==
  ==
  ;div
    ;form
      =hx-post  (spud (weld /grub/poke here))
      =hx-target  "#root"
      =hx-swap  "outerHTML"
      ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
      ;input(type "hidden", name "poke", value "create-symlink");
      ;input(type "hidden", name "type", value "relative");
      ;input(type "number", name "numb", min "0", step "1", pattern "\\d+");
      ;input(type "text", name "path");
      ;button(type "submit")
        ;span(class "htmx-indicator"): *
        ;span: create relative symlink
      ==
    ==
  ==
  ;div
    ;form
      =hx-post  (spud (weld /grub/poke here))
      =hx-target  "#root"
      =hx-swap  "outerHTML"
      ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
      ;input(type "hidden", name "poke", value "create-subdir");
      ;input(type "text", name "name", required "true");
      ;button(type "submit")
        ;span(class "htmx-indicator"): *
        ;span: add subdirectory
      ==
    ==
  ==
  ;div
    ;form
      =hx-post  (spud (weld /grub/upload here))
      =hx-target  "#root"
      =hx-swap  "outerHTML"
      =hx-encoding  "multipart/form-data"
      ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
      ;input(type "file", name "file", required "true");
      ;button(type "submit")
        ;span(class "htmx-indicator"): *
        ;span: upload file
      ==
    ==
  ==
  ::
  ;*  ;:  welp
        ?:  =(~ here)  ~
        ?:  hid.dir  ~
        :_  ~
        ;div
          ;a(href (spud :(weld /grub/view/cone (snip here))))
            ; {(render-road |+[1 /])}
          ==
        ==
        %+  turn  dir.dir
        |=  =road:g
        ^-  manx
        =/  =path  (need (path-from-road here road))
        =/  sym=?
          ?:  ?=(%& -.road)  &
          ?.  =(0 p.p.road)  &
          ?~  q.p.road       &  
          ?^  t.q.p.road     &
          ?>((~(has in ~(key by dir.cone)) i.q.p.road) |)
        =/  link=tape
          (spud :(weld /grub/view/cone path))
        ;div(class "inline")
          ;a(href link)
            ; {(render-road road)}{?.(sym "" " ->")}
          ==
          ;form
            =hx-post  (spud (weld /grub/poke here))
            =hx-target  "#root"
            =hx-swap  "outerHTML"
            =hx-confirm  "Delete this directory?"
            ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
            ;input(type "hidden", name "poke", value "delete");
            ;button(type "submit", title "Delete"): x
          ==
          ;a(href link, download (trip (rear path)))
            ;button(type "submit", title "Download"): download
          ==
        ==
        ?:  hid.dir  ~
        %+  turn  hidden
        |=  name=@ta
        ^-  manx
        =/  link=tape  (spud :(weld /grub/view/cone here /[name]))
        ;div(class "inline")
          ;a(href link)
            ; {(trip name)}
          ==
          ;form
            =hx-post  (spud (weld /grub/poke here))
            =hx-target  "#root"
            =hx-swap  "outerHTML"
            =hx-confirm  "Delete this directory?"
            ;input(type "hidden", name "get", value "/grub/view/cone{(spud here)}");
            ;input(type "hidden", name "poke", value "delete");
            ;button(type "submit", title "Delete"): x
          ==
          ;a(href link, download (trip name))
            ;button(type "submit", title "Download"): download
          ==
        ==
      ==
==
