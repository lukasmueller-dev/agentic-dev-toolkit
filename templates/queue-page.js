/* At load and every 10 s: fetch this page (8 s limit) and swap each part that changed; in a part with a field in focus or with a changed value, each child swaps, down to the field; the panel swaps block by block. Open folds stay. The render's age by the server's clock; over 2 min: Runner stopped.
   Panel: a hidden block per row (#job-<key>); the URL hash names the one it shows, j/k move it. From 1200 px a column, always open; under it a modal (a bottom sheet on a phone) while it shows a block or an output.
   Activity: GET job/<id>/activity when its block shows, again after the block swaps; agent text only through textContent.
   Buttons: a paste step's Copy writes its text to the clipboard; /queue/api (bin/vibe-web) after whoami; a data-confirm button needs a second tap within 4 s.
   Args: the data-* of the nearest .jacts, then each named field of the button's .ask after its data-pre, empty only with data-opt and a button without data-need; ⌘↵ in a field sends, Esc clears it.
   Output: .pout under the block; agent text only through textContent, or in .md, where no button works: raw HTML can repeat any id or class chain, so a guard compares nodes, never selectors.
   Write: GET writes (the writes before yours), then the POST; the output shows the command and a seconds counter, then Done in N s or
   Failed (exit N) and the output; no answer: the command can still run. Each button of a write is off with a verb while it runs; after it
   worked or got no answer, until a fetched page shows a change in its card, at most 60 s. The poll runs every 2 s meanwhile, else every 10 s.
   After a write: poll now, or once more after a poll in flight. */
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  /* The real nodes, held at load; in a fetched page, a path from body: a .md in #queue can hold any class, never a child of main. */
  const main = $('body > main'), jobs = $('body > main > #jobs'), panel = $('body > main > #panel'), blocks = $('body > main > #panel > .pblocks');
  const pout = $('body > main > #panel > .pout'), none = $('body > main > #panel > .pnone'), msg = $('.pmsg', pout), pbody = $('.pbody', pout);
  /* [path, live node, its HTML at the last fetch]: open folds and the shown block change the live HTML. */
  const parts = ['body > header > .bar > nav > .tj > .n', 'body > header > .bar > .stat', 'body > header > .bar > .jacts', 'body > main > #jobs', 'body > main > #settings', 'body > main > #panel > .pblocks', 'body > header > .bar > nav > .tw', 'body > main > #workspaces', 'body > main > #recurring'].map(s => [s, $(s), $(s).innerHTML]);
  /* A fold's key: its nearest data-k (a section) or id (a block), then its place among that node's folds. */
  const key = d => { const k = d.closest('[data-k], [id]'); return (k.dataset.k || k.id) + '#' + [...k.querySelectorAll('details')].indexOf(d); };
  /* A select's default: the option marked selected, else the first. */
  const dflt = s => [...s.options].find(o => o.defaultSelected) || s.options[0];
  /* A field the user is in or changed from its default: the swap leaves its part, or its block, alone. */
  const held = n => [...n.querySelectorAll('input, textarea, select')].some(f => f === document.activeElement || (f.tagName === 'SELECT' ? f.options[f.selectedIndex] !== dflt(f) : f.value !== f.defaultValue));
  /* The panel block by block: one with a field in use stays, a changed one swaps, a gone one goes. True when one stayed. */
  const src = new WeakMap(); /* a live block -> the fetched HTML it came from */
  for (const b of blocks.children) src.set(b, b.outerHTML);
  const swapBlocks = part => {
    let kept = false;
    const got = [...part.children], ids = new Set(got.map(f => f.id));
    for (const b of [...blocks.children]) if (!ids.has(b.id) && !held(b)) b.remove();
    for (const f of got) {
      const b = [...blocks.children].find(x => x.id === f.id), h = f.outerHTML;
      if (b && held(b)) { kept = true; continue; }
      if (b && src.get(b) === h) continue;
      const open = b ? [...b.querySelectorAll('details[open]')].map(key) : [];
      src.set(f, h);
      if (b) b.replaceWith(f); else blocks.append(f);
      f.querySelectorAll('details').forEach(d => { d.open = open.includes(key(d)); });
    }
    return kept;
  };
  /* A part with a field in use, child by child: one unchanged stays, one without a field in use swaps, one with it recurses;
     a field stays. A changed child list waits for the next poll. True when one stayed. */
  const swapIn = (live, got) => {
    const a = [...live.children], b = [...got.children];
    if (a.length !== b.length || a.some((x, i) => x.tagName !== b[i].tagName || x.id !== b[i].id)) return true;
    let kept = false;
    a.forEach((x, i) => {
      const f = b[i], h = f.outerHTML;
      if (src.get(x) === h || x.outerHTML === h) { src.set(x, h); return; }
      if (x.matches('input, textarea, select')) { kept = true; return; }
      if (held(x)) { if (swapIn(x, f)) kept = true; return; }
      const open = [...x.querySelectorAll('details[open]')].map(key);
      src.set(f, h); x.replaceWith(f);
      f.querySelectorAll('details').forEach(d => { d.open = open.includes(key(d)); });
    });
    return kept;
  };
  /* A write's verb while its buttons stay off. */
  const VERB = { now: 'Starting…', retry: 'Starting…', run: 'Starting…', 'ws-start': 'Starting…', archive: 'Archiving…', 'feature-archive': 'Archiving…',
    'research-archive': 'Archiving…', stop: 'Stopping…', 'research-stop': 'Stopping…', 'research-stop-now': 'Stopping…', 'ws-stop': 'Stopping…',
    cancel: 'Cancelling…', 'gpu-cancel': 'Cancelling…', restart: 'Restarting…', 'server-restart': 'Restarting…', pause: 'Pausing…', resume: 'Resuming…',
    hold: 'Holding…', answer: 'Sending…', steer: 'Sending…', noreview: 'Skipping…', 'feature-ready': 'Marking ready…', reset: 'Resetting…',
    unlimit: 'Clearing…', conf: 'Saving…' };
  /* pend: the writes whose buttons stay off; a write: its route (act) and the JSON of its .jacts data (key). doc: the last fetched page.
     A card: the nearest [data-k] or [id] of each button of the write (a row, a block, a section), else its .jacts. */
  let pend = [], doc = null;
  const jkey = c => JSON.stringify(Object.assign({}, c && c.dataset));
  const mine = (d, p) => [...d.querySelectorAll('button[data-act]')].filter(x => x.dataset.act === p.act && !x.closest('.md') && jkey(x.closest('.jacts')) === p.key);
  const sig = (d, p) => mine(d, p).map(x => (x.closest('[data-k], [id]') || x.closest('.jacts')).outerHTML).join('');
  const mark = (p, on) => mine(document, p).forEach(x => { if (on || x.textContent === p.verb) { x.disabled = on; x.textContent = on ? p.verb : p.label; } });
  const drop = p => { if (pend.includes(p)) { pend = pend.filter(x => x !== p); mark(p, false); } };
  /* base: the browser time at which the render was 0 s old; the browser clock only ever measures a span. */
  let last = '', busy = false, again = false, base = Date.now(), cur = '', view = 0;
  setInterval(() => {
    const u = $('.updated', parts[1][1]), s = Math.max(0, Math.round((Date.now() - base) / 1000));
    u.classList.toggle('stale', s > 120);
  }, 1000);
  const api = '/queue/api/', wide = matchMedia('(min-width: 1200px)');
  const who = () => fetch(api + 'whoami', { cache: 'no-store' }).then(r => (r.ok ? r.json() : {})).then(j => { if (j.login) { document.body.classList.add('can'); show(); } }).catch(() => {});
  const el = (tag, text) => { const n = document.createElement(tag); if (text) n.textContent = text; return n; };
  /* The Activity of a shown block, once per block node: a swap brings a new node, which loads again. */
  const acts = new WeakSet();
  const activity = blk => {
    const a = blk && $('.act', blk);
    if (!a || acts.has(a) || !document.body.classList.contains('can')) return;
    acts.add(a);
    fetch(api + 'job/' + encodeURIComponent(a.dataset.id) + '/activity', { cache: 'no-store' }).then(r => (r.ok ? r.json() : [])).catch(() => []).then(rows => {
      const ol = $('ol', a);
      if (!Array.isArray(rows) || !rows.length) return a.replaceChildren(el('h3', 'Activity'), el('p', 'No step yet.'));
      ol.replaceChildren(...rows.map(x => {
        const li = el('li'); if (x.kind === 'Agent') li.className = 'ag';
        li.append(el('span', String(x.time || '')), el('span', String(x.kind || '')), el('span', String(x.text || '')));
        return li;
      }));
    });
  };
  /* The block the hash names, its row marked; another block drops the output. Under 1200 px the modal opens only for a block or an output. */
  const show = () => {
    let id = '', blk = null;
    try { id = decodeURIComponent(location.hash.slice(1)); } catch (e) { /* a bad % escape: no block */ }
    for (const b of blocks.children) { b.hidden = b.id !== id; if (!b.hidden) blk = b; }
    jobs.querySelectorAll('.row').forEach(r => r.classList.toggle('sel', 'job-' + r.dataset.k === id));
    activity(blk);
    if ((blk ? blk.id : '') !== cur) { cur = blk ? blk.id : ''; pout.hidden = true; view++; }
    none.hidden = !!blk || !pout.hidden;
    if (wide.matches || (!blk && pout.hidden)) { if (panel.open) panel.close(); } /* wide: CSS shows it; show() would take the focus */
    else if (!panel.open) panel.showModal();
    return blk;
  };
  const shut = () => { pout.hidden = true; if (/^#job-/.test(location.hash)) history.pushState(null, '', '#jobs'); show(); };
  const poll = async () => {
    if (!document.body.classList.contains('can')) who(); /* no buttons yet: the server may be back */
    if (busy || $('button.armed')) return; /* a swap would un-arm a confirm button */
    busy = true;
    try {
      const r = await fetch(location.href, { cache: 'no-store', signal: AbortSignal.timeout(8000) }), t = await r.text();
      let kept = false;
      if (r.ok && t !== last) {
        const n = new DOMParser().parseFromString(t, 'text/html');
        doc = n;
        [...pend].forEach(p => { if (sig(n, p) !== p.was) drop(p); });
        for (const p of parts) {
          const [s, live, was] = p, h = $(s, n).innerHTML;
          if (h === was) continue;
          if (live === blocks) { if (swapBlocks($(s, n))) kept = true; else p[2] = h; continue; }
          if (held(live)) { if (swapIn(live, $(s, n))) kept = true; else p[2] = h; continue; } /* kept: the next poll tries again */
          const open = [...live.querySelectorAll('details[open]')].map(key);
          live.innerHTML = h; p[2] = h;
          live.querySelectorAll('details').forEach(d => { d.open = open.includes(key(d)); });
        }
        document.title = n.title;
        pend.forEach(p => mark(p, true)); /* a part that swapped for another card brings the button back */
        show();
      }
      /* The age at fetch: the Date header minus data-t, both the server's clock; no header: a new render is 0 s old. */
      const d = Date.parse(r.headers.get('Date'));
      if (r.ok && d) base = Date.now() - (d - $('.updated', parts[1][1]).dataset.t * 1000);
      else if (r.ok && t !== last) base = Date.now();
      if (r.ok && !kept) last = t;
    } catch (e) { /* keep the old content; the next poll tries again */ } finally {
      busy = false;
      if (again) { again = false; poll(); } /* a write came in mid-fetch: that fetch may hold the old page */
    }
  };
  let ticks = 0;
  setInterval(() => { if (pend.length || ++ticks % 5 === 0) poll(); }, 2000);
  poll(); /* now too: until a fetch gives the server's Date, a page the runner stopped writing would read fresh */
  /* The output under the block: a button's answer or a file. */
  const out = (title, sub) => {
    $('strong', pout).textContent = title; $('.ph span', pout).textContent = sub;
    msg.textContent = '…'; msg.classList.remove('bad'); pbody.replaceChildren();
    pout.hidden = false; show(); pout.scrollIntoView({ block: 'nearest' });
    return ++view; /* the newest output: an older answer must not fill it */
  };
  const say = (t, bad) => { msg.textContent = t; msg.classList.toggle('bad', !!bad); };
  $('body > main > #panel > .close').addEventListener('click', shut);
  panel.addEventListener('cancel', e => { e.preventDefault(); shut(); }); /* Esc on the modal */
  panel.addEventListener('click', e => { /* the backdrop; a tap on the sheet's empty part has the same target */
    const r = panel.getBoundingClientRect();
    if (e.target === panel && (e.clientY < r.top || e.clientX < r.left || e.clientX > r.right)) shut();
  });
  addEventListener('hashchange', show);
  wide.addEventListener('change', show);
  show();
  document.addEventListener('keydown', e => {
    const f = e.target.closest && e.target.closest('input, textarea, select');
    if (f) {
      if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); $('button[data-act]', f.closest('.ask') || f)?.click(); }
      else if (e.key === 'Escape' && f.value && f.tagName !== 'SELECT') { e.preventDefault(); f.value = ''; }
      return;
    }
    /* j/k: the next or the previous visible row; no single key writes. */
    if (e.metaKey || e.ctrlKey || e.altKey || (e.key !== 'j' && e.key !== 'k')) return;
    const list = [...jobs.querySelectorAll('.row')].filter(r => r.offsetParent), i = list.findIndex(r => r.classList.contains('sel'));
    const r = list[i < 0 ? 0 : Math.max(0, Math.min(list.length - 1, i + (e.key === 'j' ? 1 : -1)))];
    if (!r) return;
    history.replaceState(null, '', '#job-' + r.dataset.k);
    show(); r.scrollIntoView({ block: 'nearest' });
  });
  document.addEventListener('click', async e => {
    const g = e.target.closest('a.go, a.t');
    if (g && jobs.contains(g) && !e.metaKey && !e.ctrlKey) { /* a row or its Answer: its block, no jump of the page; Answer focuses the first field */
      e.preventDefault();
      history.pushState(null, '', g.getAttribute('href'));
      const blk = show();
      if (blk && g.matches('.go')) [...blk.querySelectorAll('textarea, input')].find(f => f.offsetParent)?.focus({ preventScroll: true });
      return;
    }
    const c = e.target.closest('button[data-copy]');
    if (c && blocks.contains(c)) { /* a paste step: its text to the clipboard; no write */
      (navigator.clipboard ? navigator.clipboard.writeText(c.previousElementSibling.textContent) : Promise.reject()).then(() => 'Copied', () => 'No clipboard')
        .then(m => { c.textContent = m; setTimeout(() => { c.textContent = 'Copy'; }, 1500); });
      return;
    }
    const f = e.target.closest('.files a');
    if (f && blocks.contains(f)) {
      e.preventDefault();
      const md = f.href.endsWith('.md');
      const v = out(f.textContent, f.closest('[data-id]').dataset.id);
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
    /* main and the blocks only: their text is escaped; a .md (PR problems, a file) carries agent-written Markdown. */
    const b = e.target.closest('button[data-act]');
    if (!b || b.closest('.md') || !(main.contains(b) || blocks.contains(b))) return;
    if (b.disabled || !document.body.classList.contains('can')) return;
    const card = b.closest('.jacts'), box = b.closest('.ask');
    const fields = box ? [...box.querySelectorAll('[name]')] : [], vals = {};
    for (const x of fields) {
      const v = x.value.trim().replace(/\s*\n\s*/g, ' '); /* one line: a route refuses control characters */
      if (!v && 'opt' in x.dataset && !('need' in b.dataset)) continue; /* an optional field left empty: its arg is not sent */
      if (!v) { x.focus(); return; }
      vals[x.name] = (x.dataset.pre || '') + v; /* Slots: slots=<n> */
    }
    if ('confirm' in b.dataset && !b.classList.contains('armed')) {
      const t = b.textContent;
      b.classList.add('armed'); b.textContent = 'Tap again: ' + t;
      setTimeout(() => { if (b.classList.contains('armed')) { b.classList.remove('armed'); b.textContent = t; } }, 4000); /* a second tap disarms it */
      return;
    }
    b.classList.remove('armed'); /* the poll after the write may swap again */
    /* data-id, data-pr, data-repo, data-feature, data-job, data-server, data-name; then the fields */
    const args = Object.assign({}, card && card.dataset, vals), act = b.dataset.act;
    const p = { act, key: jkey(card), label: b.textContent.replace('Tap again: ', ''), verb: VERB[act] || 'Sent…' };
    p.was = doc ? sig(doc, p) : null;
    pend.push(p); mark(p, true);
    const v = out(p.label, (args.repo || '').split('/').pop() || args.id || args.name || args.server || '');
    /* The command as the page sends it: the route, then each value but the PR link. */
    const cmd = [act, ...Object.keys(args).filter(k => k !== 'pr').map(k => args[k])].join(' '), t0 = Date.now();
    const secs = () => Math.round((Date.now() - t0) / 1000);
    let before = 0, r = null, j = null, keep = true;
    const tick = () => { if (v === view) say(`${cmd} · ${secs()} s` + (before ? ` · ${before} write${before > 1 ? 's' : ''} before yours` : '')); };
    tick();
    const clock = setInterval(tick, 1000);
    try {
      before = await fetch(api + 'writes', { cache: 'no-store' }).then(x => x.json()).then(x => +x.writes || 0, () => 0);
      tick();
      r = await fetch(api + act, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(args) });
      j = await r.json();
    } catch (err) { /* no answer: the command can still run */ }
    clearInterval(clock);
    if (!j) { if (v === view) say('No answer. The command can still run.', true); }
    else {
      keep = r.ok && j.code === 0;
      if (keep) fields.forEach(x => { if (x.tagName !== 'SELECT') x.value = x.defaultValue; else if (dflt(x)) dflt(x).selected = true; }); /* a field at its default frees its part for the swap */
      if (v !== view) { /* a newer view is open */ }
      else if (!r.ok) say(`refused: ${j.error}`, true);
      else { say(keep ? `Done in ${secs()} s` : `Failed (exit ${j.code})`, !keep); if (j.out) pbody.replaceChildren(el('pre', j.out)); }
    }
    if (keep) setTimeout(() => drop(p), 60000); else drop(p);
    if (busy) again = true; else await poll();
  });
})();
