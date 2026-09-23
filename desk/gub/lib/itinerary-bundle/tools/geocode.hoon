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
  Turn place names into coordinates, or coordinates into places, using
  OpenStreetMap through a cached Nominatim proxy. kind "search" turns a
  place name or street address into candidates, each with its name,
  address, and lat/lon; set polygon to also return the boundary geometry
  of a district or park, which is useful for defining a zone. kind
  "reverse" turns a lat/lon point into the place or address there. Always
  prefer this over guessing coordinates.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['kind' [%string 'What to do. One of: search | reverse.']]
      ['query' [%string 'search only: the place name or address; include the city']]
      ['lat' [%number 'reverse only: latitude in decimal degrees (e.g. 43.77). Pairs with lon.']]
      ['lon' [%number 'reverse only: longitude in decimal degrees (e.g. 11.25). Pairs with lat.']]
      ['polygon' [%boolean 'search only: also return the boundary geometry (a polygon) of the match, for a district or park. (default: false)']]
      ['featuretype' [%string 'search only: bias toward a feature class. Examples, not an exhaustive set: settlement, city, street.']]
      ['tag' [%string 'nearby only: osm tag key:value, e.g. shop:tobacco, amenity:fuel']]
      ['radius' [%number 'nearby only: search radius in meters around lat/lon. (default: 1500)']]
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
  ::  a caller may send a number (%n) or, being a fuzzy LLM client, a
  ::  string (%s); take the raw cord either way (these pass through to the
  ::  proxy as text).
  =/  jval
    |=  key=@t
    ^-  @t
    =/  v=(unit json)  (~(get by args.st) key)
    ?~  v  ''
    ?+  u.v  ''
      [%s *]  p.u.v
      [%n *]  p.u.v
    ==
  ::  a boolean the caller may send as JSON true/false (%b) or as a string;
  ::  the proxy reads the text "true".
  =/  jbool
    |=  key=@t
    ^-  @t
    =/  v=(unit json)  (~(get by args.st) key)
    ?~  v  ''
    ?+  u.v  ''
      [%b %.y]  'true'
      [%b %.n]  ''
      [%s *]  p.u.v
    ==
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
        ['lat' s+(jval 'lat')]
        ['lon' s+(jval 'lon')]
        ['polygon' s+(jbool 'polygon')]
        ['featuretype' s+(jstr 'featuretype')]
        ['tag' s+(jstr 'tag')]
        ['radius' s+(jval 'radius')]
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
