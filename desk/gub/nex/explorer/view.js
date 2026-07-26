// source view: plain <pre> immediately; shiki upgrade for .hoon
// using the same pkova grammar github renders hoon with.
const pre = document.getElementById('src');
const name = document.body.dataset.name || '';
if (pre && name.endsWith('.hoon')) {
  const pill = document.createElement('div');
  pill.id = 'hl-status';
  pill.textContent = 'highlighting…';
  document.body.appendChild(pill);
  try {
    const { createHighlighter } = await import('https://esm.sh/shiki@1.24.0');
    const grammar = await (await fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')).json();
    const hl = await createHighlighter({ themes: ['github-dark'], langs: [grammar] });
    pre.outerHTML = hl.codeToHtml(pre.textContent, { lang: 'hoon', theme: 'github-dark' });
    pill.remove();
  } catch (e) {
    // no network / shiki failure: the plain pre stands
    pill.textContent = 'plain view (highlighter unavailable)';
    setTimeout(() => pill.remove(), 2500);
  }
}
