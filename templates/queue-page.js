/* Every 10 s: fetch this page (8 s limit) and swap what changed. The filter, open cards and open steps stay. No change for 2 min: stale.
   Buttons: /queue/api (bin/vibe-web) after whoami; a data-confirm button needs a second tap within 4 s.
   Args: the data-* of the nearest .jacts; data-ask=<arg> prompts for it (title as the question). After a write: poll now. */
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const key = d => $('h2', d.closest('.repo')).textContent + '|' + $('b', d.closest('.job')).textContent + '|' + d.className;
  const tail = x => { const o = []; while ((x = x.nextSibling)) o.push(x); return o; };
  const html = ns => ns.map(x => x.outerHTML || x.textContent).join('');
  let last = '', jobs = html(tail($('.filter'))), seen = Date.now(), busy = false;
  setInterval(() => $('.updated').classList.toggle('stale', Date.now() - seen > 120000), 1000);
  const api = '/queue/api/';
  const who = () => fetch(api + 'whoami', { cache: 'no-store' }).then(r => (r.ok ? r.json() : {})).then(j => { if (j.login) document.body.classList.add('can'); }).catch(() => {});
  const poll = async () => {
    if (!document.body.classList.contains('can')) who(); /* no buttons yet: the server may be back */
    if (busy || $('#queue .armed')) return; /* a swap would un-arm a confirm button */
    busy = true;
    try {
      const r = await fetch(location.href, { cache: 'no-store', signal: AbortSignal.timeout(8000) }), t = await r.text();
      if (r.ok && t !== last) {
        const n = new DOMParser().parseFromString(t, 'text/html'), f = $('.filter'), g = tail($('.filter', n)), h = html(g);
        for (const s of ['.updated', '.chips', '.flags', '.acts', '#briefing', '#config']) if ($(s).innerHTML !== $(s, n).innerHTML) $(s).innerHTML = $(s, n).innerHTML;
        if (h !== jobs) { /* against the last fetch, not the live nodes: an open <details> changes their HTML */
          const open = [...document.querySelectorAll('#queue details[open]')].map(key);
          tail(f).forEach(x => x.remove());
          f.after(...g);
          document.querySelectorAll('#queue details').forEach(d => { d.open = open.includes(key(d)); });
          jobs = h;
        }
        last = t; seen = Date.now();
      }
    } catch (e) { /* keep the old content; the next poll tries again */ } finally { busy = false; }
  };
  setInterval(poll, 10000);
  who();
  document.addEventListener('click', async e => {
    /* #queue only: its cards are escaped; #briefing and #config carry agent-written Markdown. */
    const b = e.target.closest('#queue button[data-act]');
    if (!b || b.disabled || !document.body.classList.contains('can')) return;
    if ('confirm' in b.dataset && !b.classList.contains('armed')) {
      const t = b.textContent;
      b.classList.add('armed'); b.textContent = 'Tap again: ' + t;
      setTimeout(() => { b.classList.remove('armed'); b.textContent = t; }, 4000);
      return;
    }
    b.classList.remove('armed'); /* the poll after the write may swap again */
    const args = {}, card = b.closest('.jacts');
    if (card) Object.assign(args, card.dataset); /* data-id, data-pr, data-repo, data-feature */
    if (b.dataset.ask) {
      const v = prompt(b.title || b.textContent);
      if (!v) return;
      args[b.dataset.ask] = v;
    }
    const out = $('.act-out');
    b.disabled = true; out.textContent = '…';
    try {
      const r = await fetch(api + b.dataset.act, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(args) }), j = await r.json();
      out.textContent = r.ok ? `exit ${j.code}\n${j.out}` : `refused: ${j.error}`;
    } catch (err) { out.textContent = 'no answer from /queue/api'; }
    b.disabled = false;
    await poll();
  });
})();
