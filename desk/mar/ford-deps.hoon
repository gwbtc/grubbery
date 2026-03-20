::  ford-deps: ford build cache dependencies
::
::    (map mist:clay (set path))
::    Maps each build target to its dependency paths.
::
/+  ford
|_  dat=ford-deps:ford
++  grad  %noun
++  grow
  |%
  ++  noun  dat
  --
++  grab
  |%
  ++  noun  ford-deps:ford
  --
--
