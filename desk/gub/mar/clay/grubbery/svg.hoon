::
::::  /hoon/svg/mar
  ::
|_  mud=@
++  grow
  |%
  ++  mime  [/image/'svg+xml' (as-octs:mimes:html mud)]
  --
++  grab
  |%
  ++  mime  |=([p=mite q=octs] q.q)
  ++  noun  @
  --
--
