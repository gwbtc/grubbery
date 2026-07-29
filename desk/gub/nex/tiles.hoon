::  tiles store: pure tile data. Holds the local tile grubs (the /tiles
::  dir); apps declare their own tiles via /apps/<app>/tile.json. The shell
::  view reads all of this over the namespace and serves it — this nexus
::  runs no HTTP and has no request machinery of its own.
::
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  landscape-tile=json
    %-  pairs:enjs:format
    :~  title+s+'Landscape'
        info+s+'Tlon'
        color+s+'#1a1a1a'
        href+s+'/apps/landscape'
        image+s+'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Urbit_Logo.svg/3840px-Urbit_Logo.svg.png'
    ==
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %| /tiles empty-dir:loader]
      [%fall %| /tiles/landscape empty-dir:loader]
      [%fall %& [/tiles/landscape %'tile.json'] [[/ %json] landscape-tile]]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  stay:m
--
