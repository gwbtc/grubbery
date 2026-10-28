::
::  Specification for storing RSS/Atom data in Hoon.
::
::  XX explanatory notes
::  XX  tag <-> value rules / example
::        if one item, it's the tag value
::        otherwise, tag value is specified
::        <example>
::        attributes in comments are strictly faces corresponding to attribute
::
|%
+$  day   @t   ::  XX ?(%monday %tuesday %wednesday %thursday %friday)
::  XX should maybe have a uuid type for ids, but double-check across RSS + Atom
+$  uri   @t
::  XX note different standards in RSS vs. Atom if necessary
+$  lang  @t   ::  BCP47 language tag
+$  link  @t   ::  url
+$  mail  @t   ::  email
+$  mime  @t
+$  name  @t   ::  author
+$  text  @t
+$  vers  @t   ::  semantic version number
+$  hour  @ud  ::  hours 0 to 23
+$  numb  @ud
::
::  Atom 1.0
++  atom
  |%
  +$  feed
    $+  atom-feed
    $:  %feed
        ::  XX narrow down type
        headers=(list *)
        elems=(list feed-element)
        entries=(set entry)
    ==
  ::
  +$  entry
    $+  atom-entry
    [%entry p=(list entry-element)]
  ::
  ::  XX label attributes in comments (like %category and %source)
  +$  feed-element
    $+  feed-element
    $%  [%id p=uri]
        [%title p=text]
        [%updated p=time]
        [%author p=name q=(unit mail) r=(unit uri)]
        [%category p=text q=(unit uri) r=(unit text)]  ::  term, scheme, label
        [%contributor p=name]
        [%generator p=(unit uri) q=(unit vers)]  ::  uri, version
        [%icon p=link]
        [%logo p=link]
        [%rights p=text]
        [%subtitle p=text]
        ::  href, ref, type, hreflang, title, length
        [%link p=uri q=(unit ref) r=(unit mime) s=(unit lang) t=(unit text) u=(unit numb)]
    ==
  ::
  +$  ref
    $+  atom-ref
    ?(uri %alternate %enclosure %related %self %via)
  ::
  +$  entry-element
    $+  atom-entry-element
    $%  [%id p=uri]
        [%title p=text]
        [%updated p=time]
        [%author p=name]
        [%summary p=text]
        [%contributor p=name]
        [%published p=time]
        [%rights p=text]
        ::  XX what's optional?
        ::  XX is id a link or uri?
        [%source p=link q=text r=time]  ::  id, title, updated
        [%category p=text q=(unit uri) r=(unit text)]  ::  term, scheme, label
        ::  XX check what is required in what circumstances
        [%content p=(unit type) q=(unit uri) r=(unit text)]
        ::  href, ref, type, hreflang, title, length
        [%link p=uri q=(unit ref) r=(unit mime) s=(unit lang) t=(unit text) u=(unit numb)]
    ==
  ::
  ::  XX fine for a rough draft, but check against the actual RFC
  ::       it's a bit more complicated than this
  +$  type
    ?(mime %html %text %xhtml)
  --
::
::  RSS 2.0.1
::  XX on versions: https://www.rssboard.org/rss-specification#extendingRss
++  rss
  |%
  +$  channel
    $+  rss-channel
    $:  %channel
        ::  XX narrow down type
        headers=(list *)
        elems=(list channel-element)
        items=(set item)
    ==
  ::
  +$   item
    $+  rss-item
    [%item p=(list item-element)]
  ::
  +$  item-element
    $+  rss-item-element
    $%  [%title p=text]
        [%link p=link]
        [%description p=text]
        [%author p=text]
        [%category p=(unit link) q=text]  ::  domain, tag
        [%comments p=link]
        [%enclosure p=link q=numb r=mime]  ::  url, length, type
        ::  XX i forgot what this is, investigate
        [%guid p=(unit text) q=link]  ::  isPermaLink, tag, value
        [%pub-date p=time]
        [%source p=link q=text]  ::  url, tag
    ==
  ::
  +$  channel-element
    $%  [%title p=text]
        [%link p=link]
        [%description p=text]
        [%language p=lang]  ::  ISO639 or RFC1766 lang code
        [%pub-date p=time]
        [%last-build-date p=time]
        [%docs p=link]
        [%generator p=text]
        [%managing-editor p=text]
        [%web-master p=text]
        [%copyright p=text]
        [%category p=(unit link) q=text]  ::  domain, tag
        [%ttl p=numb]
        [%rating p=text]  ::  PICS rating; deprecated
        ::  title, desc, name, link
        [%text-input p=text q=text r=text s=link]
        ::  domain, port, path, register-procedure, protocol
        [%cloud p=link q=numb r=link s=text t=text]
        ::  url, title, link, width, height, desc
        [%image p=link q=text r=link s=(unit numb) t=(unit numb) u=(unit text)]
        [%skip-days p=(list day)]
        [%skip-hours p=(list hour)]
    ==
  --
--
