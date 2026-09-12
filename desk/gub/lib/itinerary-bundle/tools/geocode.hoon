/<  tools  /lib/tools.hoon
::  geocode: exact coordinates and addresses from OSM, via the geocode
::  nexus (Nominatim proxy, cached). kind 'search' turns a place name
::  or address into candidates with lat/lon; kind 'reverse' turns
::  lat/lon into "what's here". Calls protocol: poke the proxy, await
::  the result grub, cull it.
::
=>  |%
    ++  proxy  `path`/apps/'geocode.geocode'
    ++  take-news
      |=  =wire
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      |=  input:fiber:nexus
      :+  ~  q.state
      ?+  in  [%skip ~]
        ~              [%wait ~]
        [~ %news * *]  ?:(=(wire wire.u.in) [%done ~] [%skip ~])
      ==
    --
!:
^-  tool:tools
|%
++  name  'geocode'
++  description
  '''
  Exact coordinates and addresses from OpenStreetMap. kind "search":
  turn a place name or street address into candidates (name, address,
  lat, lon; set polygon "true" to also get boundary geometry for
  districts/parks — useful for zones). kind "reverse": turn lat + lon
  into the place/address at that point. Always prefer this over
  guessing coordinates.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['kind' [%string '"search" or "reverse"']]
      ['query' [%string 'search only: the place name or address, include the city']]
      ['lat' [%string 'reverse only: latitude']]
      ['lon' [%string 'reverse only: longitude']]
      ['polygon' [%string 'search only: "true" to include boundary geometry']]
      ['featuretype' [%string 'search only: bias to a feature class — settlement, city, street']]
  ==
++  required  ~['kind']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  args=json  [%o args.st]
  =/  jstr
    |=  key=@t
    ^-  @t
    =/  v=(unit json)  (~(get by args.st) key)
    ?:(?=([~ %s *] v) p.u.v '')
  =/  kind=@t  (jstr 'kind')
  ?.  |(=('search' kind) =('reverse' kind))
    (pure:m [%error 'kind must be "search" or "reverse"'])
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  call-id=@t     (scot %uv (end [3 8] eny))
  =/  call-name=@ta  (crip "{(trip call-id)}.json")
  =/  main-road=road:tarball  [%& %& proxy %'main.sig']
  =/  call-road=road:tarball  [%& %& (snoc proxy %calls) call-name]
  ;<  *  bind:m  (keep:io /geo call-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    %-  pairs:enjs:format
    :~  ['id' s+call-id]
        ['kind' s+kind]
        ['query' s+(jstr 'query')]
        ['lat' s+(jstr 'lat')]
        ['lon' s+(jstr 'lon')]
        ['polygon' s+(jstr 'polygon')]
        ['featuretype' s+(jstr 'featuretype')]
    ==
  =|  tries=@ud
  |-  ^-  form:m
  ;<  ~  bind:m  (take-news /geo)
  ;<  res=(unit json)  bind:m  (peek-as:io call-road ,json)
  ?~  res
    ?:  (gte tries 20)
      ;<  ~  bind:m  (drop:io /geo call-road)
      (pure:m [%error 'geocode timed out'])
    $(tries +(tries))
  ?.  ?&(?=([%o *] u.res) ?=([~ %s %'done'] (~(get by p.u.res) 'status')))
    $(tries +(tries))
  ;<  ~  bind:m  (drop:io /geo call-road)
  =/  response=json  (fall (~(get by p.u.res) 'response') [%o ~])
  (pure:m [%text (en:json:html response)])
--
