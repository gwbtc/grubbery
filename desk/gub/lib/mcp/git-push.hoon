/<  tools  /lib/nex/tools.hoon
::  git-push: commit and push file changes to GitHub via REST API
::
::  Uses GitHub's Git Data API to create blobs, trees, commits,
::  and update refs. No pack building needed.
::
!:
=>
|%
++  gh-request
  |=  [method=method:http url=@t headers=(list [key=@t value=@t]) bod=(unit octs)]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  =request:http  [method url headers bod]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "GitHub API: request did not finish"  !!
  =/  status=@ud  status-code.response-header.client-response
  ::  follow redirects
  ?:  ?|  =(301 status)
          =(302 status)
          =(307 status)
      ==
    =/  location=(unit @t)
      (~(get by (malt headers.response-header.client-response)) 'location')
    ?~  location
      ~|  "GitHub API: redirect without location"  !!
    (gh-request method u.location headers bod)
  ?~  full-file.client-response
    ~|  "GitHub API: empty response (status {<status>})"  !!
  =/  body=@t  q.data.u.full-file.client-response
  ?.  ?&  (gte status 200)
          (lth status 300)
      ==
    ~|  "GitHub API error (status {<status>}): {(trip body)}"  !!
  =/  parsed=(unit json)  (de:json:html body)
  ?~  parsed
    ~|  "GitHub API: invalid JSON in response"  !!
  (pure:m u.parsed)
::
++  gh-get
  |=  [url=@t headers=(list [key=@t value=@t])]
  (gh-request %'GET' url headers ~)
::
++  gh-post
  |=  [url=@t headers=(list [key=@t value=@t]) body=json]
  =/  body-octs=octs  (as-octs:mimes:html (en:json:html body))
  (gh-request %'POST' url headers `body-octs)
::
++  gh-patch
  |=  [url=@t headers=(list [key=@t value=@t]) body=json]
  =/  body-octs=octs  (as-octs:mimes:html (en:json:html body))
  (gh-request %'PATCH' url headers `body-octs)
--
^-  tool:tools
|%
++  name  'git-push'
++  description
  %+  rap  3
  :~  'Commit and push file changes to a GitHub repo. '
      'Pass files as a JSON array of {path, content} objects. '
      'Requires a GitHub personal access token.'
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['repo' [%string 'GitHub repo (owner/repo)']]
      ['branch' [%string 'Branch name (default: main)']]
      ['token' [%string 'GitHub personal access token']]
      ['message' [%string 'Commit message']]
      ['author_name' [%string 'Author name']]
      ['author_email' [%string 'Author email']]
      ['files' [%string 'JSON array of {path, content} objects to commit']]
  ==
++  required  ~['repo' 'token' 'message' 'files']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  get-str
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by args.st) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  =/  repo=@t       (get-str 'repo' '')
  =/  branch=@t     (get-str 'branch' 'main')
  =/  token=@t      (get-str 'token' '')
  =/  message=@t    (get-str 'message' '')
  =/  author-name=@t   (get-str 'author_name' 'grubbery')
  =/  author-email=@t  (get-str 'author_email' 'grubbery@urbit.org')
  ?:  =('' repo)     (pure:m [%error 'Missing required argument: repo'])
  ?:  =('' token)    (pure:m [%error 'Missing required argument: token'])
  ?:  =('' message)  (pure:m [%error 'Missing required argument: message'])
  ::  parse files JSON
  =/  files-str=@t  (get-str 'files' '[]')
  =/  files-json=(unit json)  (de:json:html files-str)
  ?~  files-json     (pure:m [%error 'Invalid files JSON'])
  ?.  ?=(%a -.u.files-json)
    (pure:m [%error 'files must be a JSON array'])
  =/  files=(list json)  p.u.files-json
  ?~  files  (pure:m [%error 'No files to commit'])
  ::  1. get current HEAD ref
  =/  api=@t  'https://api.github.com'
  =/  headers=(list [key=@t value=@t])
    :~  ['User-Agent' 'grubbery']
        ['Authorization' (cat 3 'token ' token)]
        ['Accept' 'application/vnd.github.v3+json']
        ['Content-Type' 'application/json']
    ==
  =/  ref-url=@t
    (cat 3 api (cat 3 '/repos/' (cat 3 repo (cat 3 '/git/refs/heads/' branch))))
  ;<  ref-resp=json  bind:m  (gh-get ref-url headers)
  ?.  ?=(%o -.ref-resp)
    ~|  "git-push: unexpected ref response"  !!
  =/  head-sha=@t
    =/  obj  (~(get by p.ref-resp) 'object')
    ?.  ?=([~ %o *] obj)
      ~|  "git-push: no 'object' in ref response"  !!
    =/  sha  (~(get by p.u.obj) 'sha')
    ?.  ?=([~ %s *] sha)
      ~|  "git-push: no 'sha' in ref object"  !!
    p.u.sha
  ::  2. get HEAD commit to find tree SHA
  =/  commit-url=@t
    (cat 3 api (cat 3 '/repos/' (cat 3 repo (cat 3 '/git/commits/' head-sha))))
  ;<  commit-resp=json  bind:m  (gh-get commit-url headers)
  ?.  ?=(%o -.commit-resp)
    ~|  "git-push: unexpected commit response"  !!
  =/  base-tree-sha=@t
    =/  tree  (~(get by p.commit-resp) 'tree')
    ?.  ?=([~ %o *] tree)
      ~|  "git-push: no 'tree' in commit response"  !!
    =/  sha  (~(get by p.u.tree) 'sha')
    ?.  ?=([~ %s *] sha)
      ~|  "git-push: no 'sha' in tree object"  !!
    p.u.sha
  ::  3. create blobs for each file
  =/  blob-url=@t
    (cat 3 api (cat 3 '/repos/' (cat 3 repo '/git/blobs')))
  =|  tree-entries=(list json)
  =/  remaining=(list json)  files
  |-
  ?~  remaining
    ::  4. create tree
    =/  tree-body=json
      %-  pairs:enjs:format
      :~  ['base_tree' s+base-tree-sha]
          ['tree' [%a (flop tree-entries)]]
      ==
    =/  tree-url=@t
      (cat 3 api (cat 3 '/repos/' (cat 3 repo '/git/trees')))
    ;<  tree-resp=json  bind:m  (gh-post tree-url headers tree-body)
    ?.  ?=(%o -.tree-resp)
      ~|  "git-push: unexpected tree response"  !!
    =/  new-tree-sha=@t
      =/  sha  (~(get by p.tree-resp) 'sha')
      ?.  ?=([~ %s *] sha)
        ~|  "git-push: no 'sha' in tree response"  !!
      p.u.sha
    ::  5. create commit
    =/  commit-body=json
      %-  pairs:enjs:format
      :~  ['message' s+message]
          ['tree' s+new-tree-sha]
          ['parents' [%a ~[s+head-sha]]]
          :-  'author'
          %-  pairs:enjs:format
          :~  ['name' s+author-name]
              ['email' s+author-email]
          ==
      ==
    =/  new-commit-url=@t
      (cat 3 api (cat 3 '/repos/' (cat 3 repo '/git/commits')))
    ;<  new-commit-resp=json  bind:m  (gh-post new-commit-url headers commit-body)
    ?.  ?=(%o -.new-commit-resp)
      ~|  "git-push: unexpected commit create response"  !!
    =/  new-commit-sha=@t
      =/  sha  (~(get by p.new-commit-resp) 'sha')
      ?.  ?=([~ %s *] sha)
        ~|  "git-push: no 'sha' in new commit response"  !!
      p.u.sha
    ::  6. update ref
    =/  update-body=json
      (pairs:enjs:format ~[['sha' s+new-commit-sha]])
    =/  update-url=@t
      (cat 3 api (cat 3 '/repos/' (cat 3 repo (cat 3 '/git/refs/heads/' branch))))
    ;<  *  bind:m  (gh-patch update-url headers update-body)
    ::  done
    %-  pure:m
    :-  %text
    %+  rap  3
    :~  'Pushed commit '
        (crip (scag 7 (trip new-commit-sha)))
        ' to '
        repo
        '/'
        branch
        '\0a'
        message
    ==
  ::  process current file
  =/  file=json  i.remaining
  ?.  ?=(%o -.file)
    $(remaining t.remaining)
  =/  file-path=(unit json)  (~(get by p.file) 'path')
  =/  file-content=(unit json)  (~(get by p.file) 'content')
  ?~  file-path    $(remaining t.remaining)
  ?.  ?=([%s *] u.file-path)  $(remaining t.remaining)
  ::  add/modify: create blob
  ?~  file-content   $(remaining t.remaining)
  ?.  ?=([%s *] u.file-content)  $(remaining t.remaining)
  =/  blob-body=json
    %-  pairs:enjs:format
    :~  ['content' u.file-content]
        ['encoding' s+'utf-8']
    ==
  ;<  blob-resp=json  bind:m  (gh-post blob-url headers blob-body)
  ?.  ?=(%o -.blob-resp)
    ~|  "git-push: unexpected blob response"  !!
  =/  blob-sha=@t
    =/  sha  (~(get by p.blob-resp) 'sha')
    ?.  ?=([~ %s *] sha)
      ~|  "git-push: no 'sha' in blob response"  !!
    p.u.sha
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['path' u.file-path]
        ['mode' s+'100644']
        ['type' s+'blob']
        ['sha' s+blob-sha]
    ==
  $(remaining t.remaining, tree-entries [entry tree-entries])
--
