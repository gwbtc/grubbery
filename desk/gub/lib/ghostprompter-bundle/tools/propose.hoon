/<  tools  /lib/tools.hoon
::  propose: file a CONNECTION on the dashboard — an index entry, not
::  authorship. A connection is a topic label plus raw material: real
::  excerpts from flow posts and/or verbatim passages from library
::  documents that touch the same topic. No generated ideas, angles,
::  arguments, or commentary — juxtaposition only. The thinking and
::  the writing are the user's.
::
!:
^-  tool:tools
|%
++  name  'propose'
++  description
  '''
  File a connection on the dashboard: a topic label (plain noun
  phrase) plus the raw material that shares it — verbatim excerpts
  from flow posts, and/or a verbatim passage from a library document.
  You are an indexer, not an author: no invented text of any kind.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['topic' [%string 'a plain noun-phrase label for the shared topic']]
      ['question' [%string 'optional: one genuine open question the material raises — to stimulate thought, never to smuggle a take']]
      ['posts' [%string 'flow side: newline-separated lines, each "id-prefix | author-prefix | verbatim excerpt from the post"']]
      ['passage' [%string 'library side: one passage copied VERBATIM from a library document']]
      ['source' [%string 'the library document the passage comes from']]
  ==
++  required  ~['topic']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  jstr
    |=  key=@t
    ^-  @t
    =/  v=(unit json)  (~(get by args.st) key)
    ?:(?=([~ %s *] v) p.u.v '')
  ?:  =('' (jstr 'topic'))  (pure:m [%error 'topic is required'])
  ?:  &(=('' (jstr 'posts')) =('' (jstr 'passage')))
    (pure:m [%error 'a connection needs material: posts, a passage, or both'])
  ;<  now=@da  bind:m  get-time:io
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  id=@t  (scot %uv (end [3 6] eny))
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['topic' s+(jstr 'topic')]
        ['question' s+(jstr 'question')]
        ['posts' s+(jstr 'posts')]
        ['passage' s+(jstr 'passage')]
        ['source' s+(jstr 'source')]
        ['at' (sect:enjs:format now)]
    ==
  =/  =road:tarball
    [%& %& /apps/ghostprompter/proposals (crip "{(trip id)}.json")]
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %json] doc] ~])
  ?^  err  (pure:m [%error 'failed to write the connection'])
  (pure:m [%text (cat 3 'Filed connection ' id)])
--
