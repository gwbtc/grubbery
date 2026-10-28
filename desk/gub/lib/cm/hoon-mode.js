// CodeMirror 5 mode for hoon — a stream parser, deliberately simple.
// Not the pkova TextMate grammar (shiki renders that in read views); this
// covers what makes hoon legible while editing: comments, cords/strings,
// runes, %constants, @auras, arm declarations, numbers, faces. It's a file
// on the ship — refine it whenever it annoys you.
(function () {
  if (!window.CodeMirror) return;

  CodeMirror.defineMode('hoon', function () {
    var RUNE_HEADS = '|$%:.^;~=?!+@_&,'.split('');
    var RUNE_TAILS = '|$%:.^;~=?!+@_&,-*<>#'.split('');

    return {
      startState: function () {
        return { inTripleQuote: false };
      },
      token: function (stream, state) {
        // """ multi-line strings
        if (state.inTripleQuote) {
          if (stream.match('"""')) { state.inTripleQuote = false; return 'string'; }
          stream.next();
          return 'string';
        }
        if (stream.match('"""')) { state.inTripleQuote = true; return 'string'; }

        // :: comments to end of line
        if (stream.match('::')) { stream.skipToEnd(); return 'comment'; }

        // "tape" strings (with {} interpolation left plain)
        if (stream.match(/^"(?:[^"\\]|\\.)*"/)) return 'string';

        // 'cord' literals
        if (stream.match(/^'(?:[^'\\]|\\.)*'/)) return 'string-2';

        // arm declarations: ++  name / +$  name / +*  name
        if (stream.match(/^\+[+$*]\s+[a-z][a-z0-9-]*/)) return 'def';

        // %constants and %.y %.n
        if (stream.match(/^%\.[yn]\b/)) return 'atom';
        if (stream.match(/^%[a-z][a-z0-9-]*/)) return 'atom';
        if (stream.match(/^%\d+/)) return 'atom';

        // @auras
        if (stream.match(/^@[a-zA-Z]*/)) return 'type';

        // path literals: /foo/bar (only after whitespace or line start)
        if ((stream.sol() || /\s/.test(stream.string.charAt(stream.pos - 1))) &&
            stream.match(/^\/[a-z0-9$\-\/%']*/) && stream.current() !== '/') return 'attribute';

        // numbers: 1.024, 0x1f, 0b101, plain
        if (stream.match(/^0x[0-9a-f.]+/)) return 'number';
        if (stream.match(/^0b[01.]+/)) return 'number';
        if (stream.match(/^\d[\d.]*/)) return 'number';

        // two-character runes
        var ch = stream.peek();
        if (RUNE_HEADS.indexOf(ch) >= 0) {
          var two = stream.string.slice(stream.pos, stream.pos + 2);
          if (two.length === 2 && RUNE_TAILS.indexOf(two.charAt(1)) >= 0) {
            stream.next(); stream.next();
            return 'keyword';
          }
        }

        // faces / terms
        if (stream.match(/^[a-z][a-z0-9-]*/)) return null;

        stream.next();
        return null;
      },
      lineComment: '::',
    };
  });

  CodeMirror.defineMIME('text/x-hoon', 'hoon');
})();
