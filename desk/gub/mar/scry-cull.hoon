::  scry-cull: retract EVERY bound case of a published farm spur
::
::  Carries no case: gall's +ap-cull range-checks the case it is
::  handed and only the spur's current top case clears it, so the
::  service resolves that top itself (see +farm-top in the agent).
::
|_  req=path
++  grab
  |%
  ++  noun  ,path
  --
++  grow
  |%
  ++  noun  req
  --
--
