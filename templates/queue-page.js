/* Every 10 s: fetch this page (8 s limit) and swap what changed. Open folds stay. The header counts the render's age by the server's clock; over 2 min: stale.
   Buttons: /queue/api (bin/vibe-web) after whoami; a data-confirm button needs a second tap within 4 s.
   Args: the data-* of the nearest .jacts or .prow; data-ask="<arg> …" prompts for each (title: the questions, split by |).
   Output: #panel; Roadmap and Worktrees as rows, each with its own button; agent text only through textContent, or in .md, where no button works: raw HTML can repeat any id or class chain, so a guard compares nodes, never selectors.
   After a write: poll now, or once more after a poll in flight. */
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  /* The real nodes, held at load; in a fetched page, a path from body: a .md in #queue can hold any class, never a child of main. */
  const main = $('body > main'), parts = ['body > nav > .q > .n', 'body > main > .head > .stat', 'body > main > .head > .jacts', 'body > main > #new', 'body > main > #config'].map(s => [s, $(s)]);
  const queue = $('body > main > #queue');
  /* A fold's key: its own or nearest data-k (a row, a section), then its place among that node's folds. */
  const key = d => { const k = d.closest('[data-k]') || queue; return k.dataset.k + '#' + [...k.querySelectorAll('details')].indexOf(d); };
  /* base: the browser time at which the render was 0 s old; the browser clock only ever measures a span. */
  let last = '', jobs = queue.innerHTML, busy = false, again = false, base = Date.now();
  setInterval(() => {
    const u = $('.updated', parts[1][1]), s = Math.max(0, Math.round((Date.now() - base) / 1000));
    u.textContent = `updated ${s} s ago`; u.classList.toggle('stale', s > 120);
  }, 1000);
  const api = '/queue/api/';
  const who = () => fetch(api + 'whoami', { cache: 'no-store' }).then(r => (r.ok ? r.json() : {})).then(j => { if (j.login) document.body.classList.add('can'); }).catch(() => {});
  const poll = async () => {
    if (!document.body.classList.contains('can')) who(); /* no buttons yet: the server may be back */
    if (busy || $('.armed', main)) return; /* a swap would un-arm a confirm button */
    busy = true;
    try {
      const r = await fetch(location.href, { cache: 'no-store', signal: AbortSignal.timeout(8000) }), t = await r.text();
      if (r.ok && t !== last) {
        const n = new DOMParser().parseFromString(t, 'text/html'), h = $('body > main > #queue', n).innerHTML;
        for (const [s, live] of parts) if (live.innerHTML !== $(s, n).innerHTML) live.innerHTML = $(s, n).innerHTML;
        document.title = n.title;
        if (h !== jobs) { /* against the last fetch, not the live nodes: an open <details> changes their HTML */
          const open = [...queue.querySelectorAll('details[open]')].map(key);
          queue.innerHTML = h;
          queue.querySelectorAll('details').forEach(d => { d.open = open.includes(key(d)); });
          jobs = h;
        }
      }
      /* The age at fetch: the Date header minus data-t, both the server's clock; no header: a new render is 0 s old. */
      const d = Date.parse(r.headers.get('Date'));
      if (r.ok && d) base = Date.now() - (d - $('.updated', parts[1][1]).dataset.t * 1000);
      else if (r.ok && t !== last) base = Date.now();
      if (r.ok) last = t;
    } catch (e) { /* keep the old content; the next poll tries again */ } finally {
      busy = false;
      if (again) { again = false; poll(); } /* a write came in mid-fetch: that fetch may hold the old page */
    }
  };
  setInterval(poll, 10000);
  who();
  const panel = $('#panel'), msg = $('.pmsg'), pbody = $('.pbody'), wide = matchMedia('(min-width: 1024px)');
  let view = 0; /* the newest open(): an older answer must not fill it */
  const open = (title, sub) => {
    $('strong', panel).textContent = title; $('.ph span', panel).textContent = sub;
    msg.textContent = '…'; msg.classList.remove('bad'); pbody.replaceChildren();
    if (!panel.open) { if (wide.matches) panel.show(); else panel.showModal(); }
    panel.scrollTop = 0;
    return ++view;
  };
  const say = (t, bad) => { msg.textContent = t; msg.classList.toggle('bad', !!bad); };
  const el = (tag, text) => { const n = document.createElement(tag); if (text) n.textContent = text; return n; };
  /* **bold** and `code` as nodes: the text stays text. */
  const inline = (n, s) => { s.split(/(\*\*[^*]+\*\*|`[^`]+`)/).forEach((p, i) => n.append(i % 2 === 0 ? p : p[0] === '*' ? el('b', p.slice(2, -2)) : el('code', p.slice(1, -1)))); return n; };
  const row = (data, title, lines, button) => {
    const r = el('div'); r.className = 'prow'; Object.assign(r.dataset, data);
    r.append(inline(el('b'), title));
    if (button) r.append(button);
    lines.filter(Boolean).forEach(l => r.append(inline(el('p'), l)));
    return r;
  };
  const rows = (list, none) => { const d = el('div'); d.className = 'prows'; d.append(...list); pbody.replaceChildren(list.length ? d : el('pre', none)); };
  const action = (text, act, attrs) => { const b = el('button', text); b.type = 'button'; b.dataset.act = act; Object.assign(b.dataset, attrs.data); if (attrs.title) b.title = attrs.title; return b; };
  const views = {
    roadmap: (out, a) => rows(out.split('\n').flatMap(l => {
      const m = /^(\d+): (.*)$/.exec(l); if (!m) return [];
      const t = /^\*\*(.+?)\*\*\s*(?:— )?(.*)$/.exec(m[2]) || [0, m[2], ''], k = t[2].search(/\b[Dd]one when\b/);
      return row({ repo: a.repo, line: m[1] }, t[1], k < 0 ? [t[2]] : [t[2].slice(0, k), t[2].slice(k)], action('Queue', 'roadmap-new', { data: { ask: 'branch' }, title: 'Branch slug' }));
    }), 'No open roadmap item.'),
    worktrees: out => rows(out.split('\n').flatMap(l => {
      const [state, path, branch, why] = l.split('\t'); if (!why) return [];
      return row({ path }, branch === '-' ? path : branch, [`${state}: ${why}`], /^(merged|prunable)$/.test(state) ? action('Remove', 'worktree-remove', { data: { confirm: '' } }) : null);
    }), 'No linked worktree.'),
  };
  $('.x', panel).addEventListener('click', () => panel.close());
  panel.addEventListener('click', e => { /* the backdrop; a tap on the sheet's empty part has the same target */
    const r = panel.getBoundingClientRect();
    if (e.target === panel && (e.clientY < r.top || e.clientX < r.left || e.clientX > r.right)) panel.close();
  });
  document.addEventListener('click', async e => {
    const f = e.target.closest('.files a');
    if (f && main.contains(f)) {
      e.preventDefault();
      const md = f.href.endsWith('.md');
      const v = open(f.textContent, f.closest('.jacts').dataset.id);
      try {
        const r = await fetch(f.href + (md ? '?html' : ''), { cache: 'no-store' }), t = await r.text();
        if (v !== view) return;
        if (!r.ok) return say('no such file', true);
        say('');
        if (md) {
          const d = el('div'); d.className = 'md'; d.innerHTML = t;
          /* Off the page, so nothing has acted yet: a style element or attribute reaches the whole page, a class or id the page's CSS, a meta refresh navigates. */
          d.querySelectorAll('style').forEach(n => n.remove());
          d.querySelectorAll('*').forEach(n => [...n.attributes].forEach(a => { if (!/^(href|src|alt|title|type|checked|start)$/.test(a.name)) n.removeAttribute(a.name); }));
          pbody.replaceChildren(d);
        } else pbody.replaceChildren(el('pre', t));
      } catch (err) { if (v === view) say('no answer from /queue/api', true); }
      return;
    }
    /* main and the rows rows() built only: their text is escaped; a .md (Triage, Tools, Config, a panel) carries agent-written Markdown. */
    const b = e.target.closest('button[data-act]');
    if (!b || b.closest('.md') || !(main.contains(b) || b.closest('.prows')?.parentNode === pbody)) return;
    if (b.disabled || !document.body.classList.contains('can')) return;
    if ('confirm' in b.dataset && !b.classList.contains('armed')) {
      const t = b.textContent;
      b.classList.add('armed'); b.textContent = 'Tap again: ' + t;
      setTimeout(() => { b.classList.remove('armed'); b.textContent = t; }, 4000);
      return;
    }
    b.classList.remove('armed'); /* the poll after the write may swap again */
    const args = {}, card = b.closest('.jacts, .prow'), inner = b.closest('#panel');
    if (card) Object.assign(args, card.dataset); /* data-id, data-pr, data-repo, data-feature, data-job; a row: data-line, data-path */
    if (b.dataset.ask) { /* data-ask="a b": one prompt per arg; title "question a|question b" */
      const qs = (b.title || b.textContent).split('|');
      for (const [i, a] of b.dataset.ask.split(' ').entries()) {
        const v = prompt(qs[i] || a);
        if (!v) return;
        args[a] = v;
      }
    }
    b.disabled = true;
    const v = inner ? view : open(b.textContent.replace('Tap again: ', ''), (args.repo || '').split('/').pop() || args.id || '');
    if (inner) say('…');
    let done = false;
    try {
      const r = await fetch(api + b.dataset.act, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(args) }), j = await r.json();
      done = r.ok && j.code === 0;
      if (v !== view) { /* a newer view is open */ }
      else if (!r.ok) say(`refused: ${j.error}`, true);
      else if (inner) say((done ? '' : `exit ${j.code}\n`) + j.out, !done);
      else if (done && views[b.dataset.act]) { say(''); views[b.dataset.act](j.out, args); }
      else { say(done ? '' : `exit ${j.code}`, !done); pbody.replaceChildren(el('pre', j.out || 'Done.')); }
    } catch (err) { if (v === view) say('no answer from /queue/api', true); }
    b.disabled = inner ? done : false; /* a row that worked stays off: its item is queued, its worktree gone */
    if (busy) again = true; else await poll();
  });
})();
