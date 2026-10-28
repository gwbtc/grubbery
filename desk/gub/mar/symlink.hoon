::  symlink: symbolic link mark
::  Represents symlinks as either absolute or relative paths.
::  Mime form is inode/symlink (freedesktop shared-mime-info) with the
::  Unix-style target string as body (as in git's 120000 blobs and
::  tar's linkname): absolute "/a/b" or relative "../a/b".
::
|_  =symlink:tarball
++  grow
  |%
  ++  noun  symlink
  ++  mime
    [/inode/symlink (as-octs:mimes:html (encode-symlink:tarball symlink))]
  --
++  grab
  |%
  ++  noun  symlink:tarball
  ++  mime
    |=  [=mite len=@ud tex=@t]
    ^-  symlink:tarball
    (need (parse-symlink:tarball tex))
  --
--
