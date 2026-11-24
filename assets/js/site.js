(function () {
  var root = document.documentElement;
  var store = { get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
                set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} } };

  // links para outros sites abrem em outra aba
  [].forEach.call(document.querySelectorAll('a[href^="http"]'), function (a) {
    if (a.host !== location.host) { a.target = '_blank'; a.rel = 'noopener'; }
  });

  // modo escuro
  var tb = document.querySelector('.theme-btn');
  if (tb) tb.addEventListener('click', function () {
    var cur = root.getAttribute('data-theme') ||
      (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    var next = cur === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', next); store.set('theme', next);
  });

  // menu no celular
  var nb = document.querySelector('.nav-btn'), nav = document.getElementById('nav');
  if (nb && nav) nb.addEventListener('click', function () {
    var open = nav.classList.toggle('open'); nb.setAttribute('aria-expanded', open);
  });

  // home: esconde eventos que já terminaram (o site só é regerado quando alguém edita)
  var evsec = document.getElementById('events');
  if (evsec) {
    var hoje = new Date().toISOString().slice(0, 10);
    [].forEach.call(evsec.querySelectorAll('.event'), function (e) { if (e.dataset.end < hoje) e.hidden = true; });
    if (!evsec.querySelector('.event:not([hidden])')) evsec.hidden = true;
  }

  // home: próximas palestras (ou as mais recentes)
  var tm = document.getElementById('talk-mini');
  if (tm) {
    var items = [].slice.call(tm.children), today = new Date().toISOString().slice(0, 10);
    var up = items.filter(function (li) { return li.dataset.date >= today; });
    var pick = up.length ? up.slice(0, 3) : items.slice(-3).reverse();
    if (up.length) document.getElementById('talks-h').textContent = 'Upcoming talks';
    tm.classList.add('js');
    pick.forEach(function (li) { li.classList.add('show'); tm.appendChild(li); });
  }

  // seminário: abrir/fechar todos os resumos
  var ta = document.getElementById('toggle-abs');
  if (ta) ta.addEventListener('click', function () {
    var ds = document.querySelectorAll('.talk details');
    var open = [].some.call(ds, function (d) { return !d.open; });
    [].forEach.call(ds, function (d) { d.open = open; });
    ta.textContent = open ? 'Collapse all abstracts' : 'Expand all abstracts';
  });
  if (document.querySelector('.talk, #talk-mini')) {
    window.addEventListener('load', function () {
      if (window.renderMathInElement) renderMathInElement(document.querySelector('.talks') || document.getElementById('talk-mini') || document.body, {
        delimiters: [{ left: '$$', right: '$$', display: true }, { left: '$', right: '$', display: false }, { left: '\\(', right: '\\)', display: false }],
        throwOnError: false
      });
    });
  }

  // publicações: busca e filtro por membro
  var q = document.getElementById('q'), sel = document.getElementById('member');
  if (q && sel) {
    var pubs = [].slice.call(document.querySelectorAll('.pub'));
    var groups = [].slice.call(document.querySelectorAll('.year-group'));
    var navlinks = [].slice.call(document.querySelectorAll('#yearnav a'));
    var count = document.getElementById('count'), empty = document.getElementById('empty');
    var norm = function (s) { return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); };
    pubs.forEach(function (li) { li._t = norm(li.textContent); });
    var params = new URLSearchParams(location.search);
    if (params.get('member')) sel.value = params.get('member');
    if (params.get('q')) q.value = params.get('q');
    var apply = function () {
      var terms = norm(q.value.trim()).split(/\s+/).filter(Boolean), m = sel.value, total = 0;
      pubs.forEach(function (li) {
        var ok = (!m || li.dataset.a.indexOf(m) >= 0) && terms.every(function (t) { return li._t.indexOf(t) >= 0; });
        li.hidden = !ok; if (ok) total++;
      });
      groups.forEach(function (g) {
        var n = g.querySelectorAll('.pub:not([hidden])').length;
        g.hidden = !n; g.querySelector('.count').textContent = n;
        navlinks.forEach(function (a) { if (a.dataset.g === g.dataset.g) { a.classList.toggle('hide', !n); a.querySelector('span').textContent = n; } });
      });
      count.textContent = total + (total === 1 ? ' article' : ' articles');
      empty.style.display = total ? 'none' : 'block';
      var p = new URLSearchParams(); if (m) p.set('member', m); if (q.value.trim()) p.set('q', q.value.trim());
      history.replaceState(null, '', location.pathname + (p.toString() ? '?' + p : '') + location.hash);
    };
    q.addEventListener('input', apply); sel.addEventListener('change', apply);
    if (sel.value || q.value) apply();
    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (es) {
        es.forEach(function (e) { if (e.isIntersecting) navlinks.forEach(function (a) { a.classList.toggle('on', a.dataset.g === e.target.dataset.g); }); });
      }, { rootMargin: '-140px 0px -70% 0px' });
      groups.forEach(function (g) { io.observe(g); });
    }
  }
})();
