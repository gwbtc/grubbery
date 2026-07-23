::  oneshot: one-shot LLM call primitives
::
::  A door that takes API configuration and exposes arms for
::  making independent, context-free LLM calls as fiber steps.
::
::  Output constraining: every call has an output mark and description.
::  The LLM response text is converted to a wain (%txt), then tubed
::  to the target mark. If conversion fails, the error is fed back
::  and the call retries.
::
|%
::  Claude API configuration
::
+$  claude-config
  $:  api-key=@t          ::  anthropic API key
      model=@t            ::  model identifier
      max-tokens=@ud      ::  max output tokens
  ==
::  Output constraint: target mark + format description for the LLM
::
+$  output  [=mark desc=@t]
::  A one-shot call specification
::
+$  spec
  $:  system=@t           ::  system prompt
      prompt=@t           ::  user prompt (the input)
      =output             ::  output constraint
  ==
::  Result of a one-shot call
::
::  &/[raw sage]: LLM responded, tube passed
::  |/&/[raw tang]: LLM responded, tube crashed
::  |/|/@t: no LLM response (API/network error)
+$  success      [raw=@t =sage:tarball]
+$  parse-error  [raw=@t =tang]
+$  api-error    @t
+$  failure      (each parse-error api-error)
+$  result       (each success failure)
::  The door: takes claude config, exposes call arms
::
++  agent
  |_  =claude-config
  ::  +call: one-shot API call with output constraining
  ::
  ++  call
    |=  =spec
    =/  m  (fiber:fiber:nexus ,result)
    ^-  form:m
    ;<  got=(each @t @t)  bind:m  (request spec)
    ?.  ?=(%& -.got)
      (pure:m [%| %| p.got])
    (constrain p.got output.spec)
  ::  +request: send spec to Claude API, return raw text or error
  ::
  ++  request
    |=  =spec
    =/  m  (fiber:fiber:nexus ,(each @t @t))
    ^-  form:m
    ::  append format description to system prompt
    ::
    =/  full-system=@t
      (rap 3 ~[system.spec '\0a\0aOUTPUT FORMAT:\0a' desc.output.spec])
    ::  build messages API request body
    ::
    =/  body=@t  %-  en:json:html
      %-  pairs:enjs:format
      :~  ['model' s+model.claude-config]
          ['max_tokens' (numb:enjs:format max-tokens.claude-config)]
          ['system' s+full-system]
          :-  'messages'
          [%a ~[(pairs:enjs:format ~[['role' s+'user'] ['content' s+prompt.spec]])]]
      ==
    =/  =request:http
      :^  %'POST'  'https://api.anthropic.com/v1/messages'
        :~  ['content-type' 'application/json']
            ['x-api-key' api-key.claude-config]
            ['anthropic-version' '2023-06-01']
        ==
      `(as-octs:mimes:html body)
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      (pure:m [%| 'request cancelled'])
    =/  body=@t
      ?~(full-file.client-response '' q.data.u.full-file.client-response)
    (pure:m (extract-text (fall (de:json:html body) *json)))
  ::  +extract-text: pull raw text from Claude API response JSON
  ::
  ++  extract-text
    |=  resp=json
    ^-  (each @t @t)
    ?.  ?=([%o *] resp)
      [%| 'response is not a JSON object']
    ::  check for API-level error
    ::
    =/  err=(unit json)  (~(get by p.resp) 'error')
    ?^  err
      :-  %|
      ?:  ?=([%o *] u.err)
        =/  msg=(unit json)  (~(get by p.u.err) 'message')
        ?:(?=([~ %s *] msg) p.u.msg 'unknown error')
      'unknown error'
    ::  collect text from content blocks
    ::
    =/  content=(unit json)  (~(get by p.resp) 'content')
    ?~  content  [%| 'no content in response']
    ?.  ?=(%a -.u.content)  [%| 'content is not an array']
    =/  texts=(list @t)
      %+  murn  p.u.content
      |=  block=json
      ?.  ?=([%o *] block)  ~
      =/  type=(unit json)  (~(get by p.block) 'type')
      ?.  ?=([~ %s %'text'] type)  ~
      =/  text=(unit json)  (~(get by p.block) 'text')
      ?.  ?=([~ %s *] text)  ~
      `p.u.text
    ?~  texts  [%| 'no text blocks in response']
    [%& (rap 3 texts)]
  ::  +constrain: tube raw text through %mime to target mark
  ::
  ++  constrain
    |=  [raw=@t =output]
    =/  m  (fiber:fiber:nexus ,result)
    ^-  form:m
    ::  wrap raw text as %mime for tube input
    ::
    =/  =mime  [/text/plain (as-octs:mimes:html raw)]
    =/  mime-vase=vase  !>(mime)
    ?:  =(mark.output %mime)
      (pure:m [%& raw [/ %mime] mime-vase])
    ::  look up and run %mime -> target tube
    ::
    ;<  tube=(unit tube:clay)  bind:m
      (get-tube:io [%& %| /code] [[/ %mime] [/ mark.output]])
    ?~  tube
      =/  err=tang  ~[leaf+(trip (cat 3 'no tube from %mime to %' mark.output))]
      (pure:m [%| %& raw err])
    =/  convert=(each vase tang)  (mule |.((u.tube mime-vase)))
    ?:  ?=(%| -.convert)
      (pure:m [%| %& raw (flop p.convert)])
    (pure:m [%& raw [/ mark.output] p.convert])
  ::  +call-retry: call with retry on crash, accumulating errors
  ::
  ++  call-retry
    |=  [=spec max-retries=@ud]
    =/  m  (fiber:fiber:nexus ,result)
    ^-  form:m
    =|  attempts=@ud
    =|  errors=(list @t)
    |-
    ;<  =result  bind:m  (call spec)
    ?:  ?=(%& -.result)
      (pure:m result)
    ?:  (gte +(attempts) max-retries)
      (pure:m result)
    ::  extract error text for retry context
    =/  err=@t
      ?-  -.p.result
        %&  %-  of-wain:format
            %+  turn  tang.p.p.result
            |=(=tank (crip ~(ram re tank)))
        %|  p.p.result
      ==
    ::  append crash report to system prompt and retry
    =/  crash-log=@t
      %+  rap  3
      %+  join  '\0a'
      %+  turn  (snoc errors err)
      |=(e=@t (rap 3 ~['- Attempt ' (scot %ud +(attempts)) ': ' e]))
    =/  new-system=@t
      %+  rap  3
      :~  system.spec
          '\0a\0aPREVIOUS ATTEMPTS FAILED:\0a'
          crash-log
          '\0a\0aPlease try again, avoiding the above errors.'
      ==
    $(attempts +(attempts), errors (snoc errors err), spec spec(system new-system))
  --
::  +search: web search via Brave Search API
::
::  Takes a Brave API key, exposes a search arm that returns
::  results as formatted text.
::
++  search
  |_  brave-key=@t
  ::  +web: single web search (sequential fetch)
  ::
  ++  web
    |=  query=@t
    =/  m  (fiber:fiber:nexus ,@t)
    ^-  form:m
    ;<  resp=json  bind:m  (fetch (web-url query))
    (pure:m (parse-web resp))
  ::  +news: single news search (sequential fetch)
  ::
  ++  news
    |=  query=@t
    =/  m  (fiber:fiber:nexus ,@t)
    ^-  form:m
    ;<  resp=json  bind:m  (fetch (news-url query))
    (pure:m (parse-news resp))
  ::  +multi: run web + news searches for each query sequentially
  ::
  ++  multi
    |=  queries=(list @t)
    =/  m  (fiber:fiber:nexus ,@t)
    ^-  form:m
    =|  acc=(list @t)
    =/  remaining=(list @t)  queries
    |-
    ?~  remaining
      (pure:m (of-wain:format acc))
    ;<  web-res=@t  bind:m  (web i.remaining)
    ;<  news-res=@t  bind:m  (news i.remaining)
    =/  labeled=@t
      %:  rap  3
        '\0a=== SEARCH: '  i.remaining  ' ===\0a'
        web-res  '\0a'  news-res
        ~
      ==
    $(remaining t.remaining, acc (snoc acc labeled))
  ::  +fetch: sequential HTTP fetch + JSON parse
  ::
  ++  fetch
    |=  url=@t
    =/  m  (fiber:fiber:nexus ,json)
    ^-  form:m
    =/  =request:http
      :^  %'GET'  url
        :~  ['Accept' 'application/json']
            ['X-Subscription-Token' brave-key]
        ==
      ~
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      (pure:m *json)
    =/  body=@t
      ?~(full-file.client-response '' q.data.u.full-file.client-response)
    =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
    ?:  ?=(%| -.parsed)
      (pure:m *json)
    (pure:m p.parsed)
  ::  +web-url: build Brave web search URL
  ::
  ::  +web-url: build Brave web search URL
  ::
  ::  Uses + for spaces instead of %20 because vere's cttp.c
  ::  decodes %20 via de-purl:html but doesn't re-encode when
  ::  serializing the request, producing literal spaces in the
  ::  HTTP request line.
  ::  TODO: Document and fix bug in cttp.c in vere
  ::
  ++  web-url
    |=  query=@t
    ^-  @t
    =/  encoded=@t
      %-  crip
      %-  zing
      %+  turn  (trip query)
      |=(c=@t ?:(=(c ' ') "%2520" (trip c)))
    (rap 3 ~['https://api.search.brave.com/res/v1/web/search?q=' encoded])
  ::  +news-url: build Brave news search URL
  ::  (see +web-url for encoding rationale)
  ::
  ++  news-url
    |=  query=@t
    ^-  @t
    =/  encoded=@t
      %-  crip
      %-  zing
      %+  turn  (trip query)
      |=(c=@t ?:(=(c ' ') "%2520" (trip c)))
    (rap 3 ~['https://api.search.brave.com/res/v1/news/search?q=' encoded '&count=20'])
  ::  +parse-web: extract formatted text from web search response
  ::
  ++  parse-web
    |=  resp=json
    ^-  @t
    ?.  ?=([%o *] resp)  'search returned invalid response'
    =/  results=(unit json)  (~(get by p.resp) 'web')
    ?~  results  'no web results'
    ?.  ?=([%o *] u.results)  'no web results'
    =/  items=(unit json)  (~(get by p.u.results) 'results')
    ?~  items  'no result items'
    ?.  ?=(%a -.u.items)  'no result items'
    (of-wain:format (extract-results p.u.items))
  ::  +parse-news: extract formatted text from news search response
  ::
  ++  parse-news
    |=  resp=json
    ^-  @t
    ?.  ?=([%o *] resp)  'news returned invalid response'
    =/  results=(unit json)  (~(get by p.resp) 'results')
    ?~  results  'no news results'
    ?.  ?=(%a -.u.results)  'no news results'
    (of-wain:format (extract-results p.u.results))
  ::  +extract-results: pull text from a Brave results array
  ::
  ++  extract-results
    |=  items=(list json)
    ^-  (list @t)
    %+  murn  items
    |=  item=json
    ?.  ?=([%o *] item)  ~
    =/  title=(unit json)  (~(get by p.item) 'title')
    =/  url=(unit json)  (~(get by p.item) 'url')
    =/  desc=(unit json)  (~(get by p.item) 'description')
    =/  extras=(unit json)  (~(get by p.item) 'extra_snippets')
    =/  t=@t  ?:(?=([~ %s *] title) p.u.title '')
    =/  u=@t  ?:(?=([~ %s *] url) p.u.url '')
    =/  d=@t  ?:(?=([~ %s *] desc) p.u.desc '')
    =/  e=@t
      ?.  ?=([~ %a *] extras)  ''
      %-  of-wain:format
      %+  murn  p.u.extras
      |=(s=json ?.(?=([%s *] s) ~ `p.s))
    =/  tail=@t  ?:(=('' e) '' '\0a')
    `(rap 3 ~[t '\0a' u '\0a' d '\0a' e tail])
  --
::  +briefing: research a topic via search + LLM synthesis
::
::  Takes a config, a topic description, and an optional output
::  constraint. Generates search queries, runs them, then
::  synthesizes results into a briefing.
::
++  briefing
  |_  [=claude-config brave-key=@t]
  ::  +brief: research a topic and synthesize a briefing
  ::
  ++  brief
    |=  [topic=@t =output]
    =/  m  (fiber:fiber:nexus ,result)
    ^-  form:m
    ;<  queries=(list @t)  bind:m  (generate-queries topic)
    ?~  queries
      (pure:m [%| %| 'no queries generated'])
    ;<  research=@t  bind:m  (run-searches queries)
    (synthesize topic research output)
  ::  +generate-queries: ask LLM to produce search queries for a topic
  ::
  ++  generate-queries
    |=  topic=@t
    =/  m  (fiber:fiber:nexus ,(list @t))
    ^-  form:m
    =/  =spec
      :^    %+  rap  3
            :~  'You are a research assistant. Given the following topic, '
                'generate 5 to 8 search queries that would give comprehensive '
                'coverage of the subject. Mix broad and specific queries. '
                'Include both web and news angles.'
            ==
          topic
        %json
      '''
      Output a JSON array of strings, each being a search query.
      Example: ["query one", "query two", "query three"]
      No other text, just the JSON array.
      '''
    ;<  res=result  bind:m  (~(call-retry agent claude-config) spec 2)
    ?.  ?=(%& -.res)
      (pure:m ~)
    =/  query-json=json  (fall (de:json:html raw.p.res) *json)
    ?.  ?=([%a *] query-json)
      (pure:m ~)
    %-  pure:m
    %+  murn  p.query-json
    |=(q=json ?.(?=([%s *] q) ~ `p.q))
  ::  +run-searches: run all queries sequentially
  ::
  ++  run-searches
    |=  queries=(list @t)
    =/  m  (fiber:fiber:nexus ,@t)
    ^-  form:m
    =|  acc=(list @t)
    =/  remaining=(list @t)  queries
    |-
    ?~  remaining
      (pure:m (of-wain:format acc))
    ;<  web-res=@t  bind:m  (~(web search brave-key) i.remaining)
    ;<  news-res=@t  bind:m  (~(news search brave-key) i.remaining)
    =/  labeled=@t
      %:  rap  3
        '\0a=== SEARCH: '  i.remaining  ' ===\0a'
        web-res  '\0a'  news-res
        ~
      ==
    $(remaining t.remaining, acc (snoc acc labeled))
  ::  +synthesize: ask LLM to write a briefing from search results
  ::
  ++  synthesize
    |=  [topic=@t research=@t =output]
    =/  m  (fiber:fiber:nexus ,result)
    ^-  form:m
    =/  =spec
      :+  %+  rap  3
          :~  'You are an expert analyst. You have been given raw search '
              'results from multiple queries on a topic. Synthesize these '
              'into a clear, analytical briefing. Focus on what matters: '
              'key developments, why they matter, connections between events, '
              'and actionable insights. Do not just summarize headlines — '
              'provide analysis and context.'
              '\0a\0aTOPIC: '
              topic
          ==
        research
      output
    (~(call agent claude-config) spec)
  --
::
::  +descs: default format descriptions for common output marks
::
++  descs
  ^-  (map @t @t)
  %-  my
  :~  :-  'txt'
      'Any text output will be considered valid.'
    ::
      :-  'json'
      '''
      Your output is constrained to pure json. Output only valid JSON that
      can be directly parsed. Do not include markdown formatting, code
      blocks, or any text outside the JSON structure.

      Examples of expected output formats:

      For a string value:
      "Hello world"

      For a number:
      42

      For a boolean:
      true

      For null:
      null

      For an array:
      ["apple", "banana", "cherry"]

      For an object:
      {"name": "John", "age": 30, "city": "New York"}

      For nested structures:
      {"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}], "total": 2}

      Always ensure your output is valid JSON that starts with a JSON value
      (object, array, string, number, boolean, or null) and contains no
      additional text or formatting.
      '''
    ::
      :-  'ud'
      '''
      You must output ONLY a decimal number using digits 0-9.
      No separators, no periods, no commas, no spaces.
      No other text, explanations, or characters.

      EXAMPLES:
      - 0
      - 42
      - 137
      - 1000
      - 12345
      - 1234567
      - 999999999

      Your response must be exactly one number, nothing else.
      '''
  ==
--
