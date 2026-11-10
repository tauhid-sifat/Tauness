/* Client-side search for the AIDLC Harness handbook. Zero dependencies, no network: it reads the
   committed window.HARNESS_SEARCH_INDEX (search-index.js) and filters it as you type. */
(function () {
  var idx = window.HARNESS_SEARCH_INDEX || [];
  var input = document.getElementById('search-input');
  var list = document.getElementById('search-results');
  if (!input || !list) return;

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function render(q) {
    q = q.replace(/\s+/g, ' ').trim().toLowerCase();
    if (q.length < 2) { list.hidden = true; list.innerHTML = ''; return; }
    var terms = q.split(' ');
    var hits = [];
    for (var i = 0; i < idx.length; i++) {
      var e = idx[i];
      var title = e.t.toLowerCase();
      var body = (e.t + ' ' + e.s).toLowerCase();
      var score = 0; var ok = true;
      for (var j = 0; j < terms.length; j++) {
        if (title.indexOf(terms[j]) >= 0) score += 3;
        else if (body.indexOf(terms[j]) >= 0) score += 1;
        else { ok = false; break; }
      }
      if (ok) hits.push({ e: e, score: score });
    }
    hits.sort(function (a, b) { return b.score - a.score; });
    hits = hits.slice(0, 20);
    if (!hits.length) { list.hidden = false; list.innerHTML = '<li class="s-none">No matches</li>'; return; }
    var html = '';
    for (var k = 0; k < hits.length; k++) {
      var e = hits[k].e;
      var href = e.p + (e.id ? '#' + e.id : '');
      var snip = e.s; if (snip.length > 110) snip = snip.slice(0, 110) + '...';
      html += '<li><a href="' + esc(href) + '"><span class="s-title">' + esc(e.t) + '</span>' +
        '<span class="s-snip">' + esc(snip) + '</span><span class="s-page">' + esc(e.p) + '</span></a></li>';
    }
    list.hidden = false;
    list.innerHTML = html;
  }

  input.addEventListener('input', function () { render(input.value); });
  input.addEventListener('keydown', function (ev) {
    if (ev.key === 'Escape') { input.value = ''; list.hidden = true; list.innerHTML = ''; }
  });
  document.addEventListener('click', function (ev) {
    if (!ev.target.closest('.search')) { list.hidden = true; }
  });
})();
