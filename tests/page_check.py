"""page_check.py BROWSER WEB_DIR A B RESEARCH DRAINED LIVE — drive page.js in a headless browser (CDP over --remote-debugging-pipe).

WEB_DIR holds the page `vibe queue page` wrote, with blocked jobs A and B and the research question RESEARCH
(a coordinator and 4 workers: h1, h4 below h1, h2, h3), DRAINED (Stop now while its run lives) and LIVE (a run on vast
with steps, an ETA and a box end); it is served under /queue/ and changed in place, with a whoami,
a GET writes and an Activity per job as static files; a POST gets its answer in ANSWERS after its delay. Prints one line per check; exits 1 when one fails, 77 when the browser does not
start (a sandbox that refuses its sockets). PAGE_SHOTS=<dir>: screenshots at 2560x1440, 1440x900 and 390x844 go there.
Used by tests/vibe-web.bats.
"""
import base64
import functools
import http.server
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

BROWSER, WEB, A, B, R, RD, RL = sys.argv[1:8]
PAGE = os.path.join(WEB, "index.html")
signal.alarm(80)  # a hung browser fails the test instead of the suite

root = tempfile.mkdtemp()
os.symlink(WEB, os.path.join(root, "queue"))
ANSWERS = {"archive": (8, {"code": 0, "out": "archived"}), "hold": (1.5, {"code": 1, "out": "no such job"})}  # route: s, answer; none: no answer


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        delay, a = ANSWERS.get(self.path.rsplit("/", 1)[-1], (1.5, None))
        time.sleep(delay)
        if a is None:
            self.close_connection = True
            return
        body = json.dumps(a).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=root))
threading.Thread(target=server.serve_forever, daemon=True).start()
URL = "http://127.0.0.1:%d/queue/index.html" % server.server_address[1]


def edit(fn):
    with open(PAGE, encoding="utf-8") as f:
        html = f.read()
    with open(PAGE, "w", encoding="utf-8") as f:
        f.write(fn(html))


def state(job, text):
    """The page with JOB's block head state set to TEXT."""
    return lambda h: re.sub(r'(id="job-%s" hidden><div class="bh"><i class="lamp l-[a-z]+"></i><span class="st"[^>]*>)[^<]*' % re.escape(job), r"\g<1>" + text, h)


with open(PAGE, encoding="utf-8") as f:
    FRESH = f.read()  # the page as vibe wrote it: the screenshots show it

# The API's reads as static files: whoami shows the buttons; an Activity per job with a log.
os.makedirs(os.path.join(WEB, "api", "job"), exist_ok=True)
with open(os.path.join(WEB, "api", "whoami"), "w", encoding="utf-8") as f:
    json.dump({"login": "me@example.com"}, f)


def writes(n):
    """GET writes: N writes hold or wait for the lock."""
    with open(os.path.join(WEB, "api", "writes"), "w", encoding="utf-8") as f:
        json.dump({"writes": n, "render": False}, f)


writes(2)
with open(PAGE, encoding="utf-8") as f:
    for i in set(re.findall(r'<div class="act" data-id="([^"]+)">', f.read())):
        os.makedirs(os.path.join(WEB, "api", "job", i), exist_ok=True)
        with open(os.path.join(WEB, "api", "job", i, "activity"), "w", encoding="utf-8") as g:
            json.dump([{"time": "09:58", "kind": "Agent", "text": "The runner now checks the worktree path before it runs git there."},
                       {"time": "09:57", "kind": "Bash", "text": "bats tests/vibe-queue.bats"},
                       {"time": "09:55", "kind": "Edit", "text": "bin/vibe"}], g)

# Two service cards, the first with a Place form.
ROW = '<div class="wrow" id="ws-%s"><div class="t"><span class="why"><i class="lamp l-off"></i>Off</span><b>%s</b></div>%s</div>'
FORM = '<div class="jacts" data-name="one"><span class="ask"><label>Place<select name="place"><option>turing</option><option>runpod</option></select></label><button data-act="ws-start">Start</button></span></div>'
edit(lambda h: re.sub(r'(<section id="workspaces" class="page ext">\n).*?(\n</section>)', lambda m: m.group(1) + '<section class="sec" aria-label="Services">' + ROW % ("one", "One", FORM) + ROW % ("two", "Two", "") + '</section>' + m.group(2), h, count=1, flags=re.S))

# A block S for the select checks.
edit(lambda h: h.replace('<div class="pblocks">\n', '<div class="pblocks">\n<div class="blk" id="job-S" hidden><div class="bh"><h2>S</h2></div></div>\n', 1))

# An old render: the runner stopped writing an hour ago.
edit(lambda h: re.sub(r'data-t="[0-9]+"', 'data-t="%d"' % (time.time() - 3600), h))

r_in, w_in = os.pipe()  # we write, the browser reads fd 3
r_out, w_out = os.pipe()  # the browser writes fd 4, we read
prof = tempfile.mkdtemp()


def fds():
    os.dup2(r_in, 3)
    os.dup2(w_out, 4)


proc = subprocess.Popen([BROWSER, "--headless", "--remote-debugging-pipe", "--no-sandbox", "--no-first-run",
                         "--user-data-dir=" + prof, "about:blank"], pass_fds=(3, 4), preexec_fn=fds,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
os.close(r_in)
os.close(w_out)
buf, nid, sid = b"", 0, None


def cdp(method, params=None):
    global buf, nid
    nid += 1
    msg = {"id": nid, "method": method, "params": params or {}}
    if sid:
        msg["sessionId"] = sid
    os.write(w_in, json.dumps(msg).encode() + b"\0")
    while True:
        while b"\0" not in buf:
            chunk = os.read(r_out, 1 << 16)
            if not chunk:
                raise RuntimeError("browser closed the pipe")
            buf += chunk
        line, buf = buf.split(b"\0", 1)
        m = json.loads(line)
        if m.get("id") == nid:
            if "error" in m:
                raise RuntimeError("%s: %s" % (method, m["error"]))
            return m["result"]


def js(expr):
    r = cdp("Runtime.evaluate", {"expression": expr, "returnByValue": True})
    if "exceptionDetails" in r:
        raise RuntimeError(r["exceptionDetails"])
    return r["result"].get("value")


def until(expr, secs):
    """True once EXPR is truthy, polled for SECS."""
    end = time.time() + secs
    while time.time() < end:
        if js(expr):
            return True
        time.sleep(0.25)
    return False


bad = 0


def check(name, ok):
    global bad
    print(("ok   " if ok else "FAIL ") + name)
    bad += not ok


ST = "document.getElementById('job-%s').querySelector('.st').textContent"
try:
    try:
        target = cdp("Target.createTarget", {"url": "about:blank"})["targetId"]
    except RuntimeError as e:
        print("the browser did not start: %s" % e)
        sys.exit(77)
    sid = cdp("Target.attachToTarget", {"targetId": target, "flatten": True})["sessionId"]
    cdp("Emulation.setDeviceMetricsOverride", {"width": 1440, "height": 900, "deviceScaleFactor": 1, "mobile": False})
    cdp("Page.navigate", {"url": URL + "#job-" + A})
    until("document.readyState === 'complete'", 10)
    check("an old page reads stale at load", until("document.querySelector('.updated').classList.contains('stale')", 4))
    check("a stale page says Runner stopped", js("document.querySelector('.stat').innerText.includes('Runner stopped')"))
    check("the hash shows its block", js("!document.getElementById('job-%s').hidden" % A))
    # Half a note in A's field, then B in the panel.
    js("document.querySelector('#job-%s textarea').value = 'half'" % A)
    js("location.hash = 'job-%s'" % B)
    check("another row shows its block", until("!document.getElementById('job-%s').hidden" % B, 2))
    # A select in block S set to its second option, then left: no field has focus.
    js("(() => { const s = document.createElement('select'); s.add(new Option('a')); s.add(new Option('b')); s.selectedIndex = 1; document.querySelector('#job-S .bh').append(s); })()")
    # One's Place set to runpod, then left.
    js("document.querySelector('#ws-one select').selectedIndex = 1")
    # The runner writes a new page: A and B change, a new block C, a new Needs-you count, a fresh render.
    edit(lambda h: state(B, "changed")(state(A, "changed")(h)))
    edit(lambda h: h.replace('<div class="blk" id="job-S" hidden>', '<div class="blk" id="job-C" hidden><div class="bh"><h2>C</h2></div></div>\n<div class="blk" id="job-S" hidden>', 1))
    edit(lambda h: re.sub(r'(<h2>Needs you <span class="n">)[0-9]+', r"\g<1>3", h))
    edit(lambda h: h.replace('<h2>S</h2>', '<h2>S 2</h2>', 1))
    edit(lambda h: h.replace('<i class="lamp l-off"></i>Off</span>', '<i class="lamp l-off"></i>up</span>'))
    edit(lambda h: re.sub(r'data-t="[0-9]+"', 'data-t="%d"' % time.time(), h))
    check("the block without a field in use swaps", until((ST % B) + " === 'changed'", 13))
    check("a block with text in a field stays", js(ST % A) == "Has a question" and js("document.querySelector('#job-%s textarea').value" % A) == "half")
    check("a block with a changed select and no focus stays", js("document.querySelector('#job-S h2').textContent") == "S" and js("document.querySelector('#job-S .bh select').selectedIndex") == 1)
    check("a new block arrives", js("!!document.getElementById('job-C')"))
    WHY = "document.querySelector('#ws-%s .why').textContent"
    check("a changed select holds only itself: the other row and its own row's text swap", js(WHY % "two") == "up" and js(WHY % "one") == "up")
    check("the changed select keeps its value", js("document.querySelector('#ws-one select').selectedIndex") == 1)
    check("the list swaps", js("document.querySelector('[data-k=\"you\"] h2 .n').textContent") == "3")
    check("a fresh render is not stale", js("!document.querySelector('.updated').classList.contains('stale') && !document.querySelector('.stat').innerText.includes('Runner stopped')"))
    js("location.hash = 'job-C'")
    check("the new block shows", until("!document.getElementById('job-C').hidden", 2))
    # The field empties: the next poll swaps that block too.
    js("document.querySelector('#job-%s textarea').value = ''" % A)
    js("document.querySelector('#job-S .bh select').selectedIndex = 0")
    check("an emptied field lets its block swap", until((ST % A) + " === 'changed'", 13))
    check("a select back at its default lets its block swap", until("document.querySelector('#job-S h2').textContent === 'S 2'", 2))
    # The research card: a row per worker, the builds= row right of its parent, no row wider than the panel, on a desk and a phone.
    RB = "document.getElementById('job-research/%s')" % R
    js("location.hash = 'job-research/%s'" % R)
    check("a research block shows", until("!%s.hidden" % RB, 2))
    check("a row per worker, a builds= row below its parent", js("[...%s.querySelectorAll('.wk')].map(w => w.dataset.hid).join()" % RB) == "h1,h4,h2,h3")
    LEFT = "[...%s.querySelectorAll('.wk')].map(w => Math.round(w.getBoundingClientRect().left))" % RB
    left = js(LEFT)
    check("a builds= row sits right of its parent", left[1] > left[0] and left[0] == left[2] == left[3])
    FIT = "(() => { const p = document.getElementById('panel').getBoundingClientRect().right; return [...%s.querySelectorAll('.wk')].every(w => w.getBoundingClientRect().right <= p); })()" % RB
    check("no worker row is wider than the panel", js(FIT))
    cdp("Emulation.setDeviceMetricsOverride", {"width": 390, "height": 800, "deviceScaleFactor": 1, "mobile": True})
    check("no worker row is wider than the panel on a phone", until(FIT, 2) and js("document.documentElement.scrollWidth <= window.innerWidth"))
    # The paste panel of h3: a Copy per step writes its step to the clipboard, a field answers, the stop buttons are in the block.
    js("window.copied = null; Object.defineProperty(navigator, 'clipboard', { value: { writeText: t => { window.copied = t; return Promise.resolve(); } }, configurable: true })")
    js("%s.querySelectorAll('.paste button[data-copy]')[1].click()" % RB)
    check("Copy writes its step, without the list marker", until("window.copied === 'sbatch runs/h3/job.sbatch'", 2))
    check("the button names the copy", until("%s.querySelectorAll('.paste button[data-copy]')[1].textContent === 'Copied'" % RB, 2))
    # A second tap while it reads Copied: the label goes back to Copy, not stuck on Copied.
    js("%s.querySelectorAll('.paste button[data-copy]')[1].click()" % RB)
    time.sleep(2.5)
    check("a second tap leaves the label at Copy", js("%s.querySelectorAll('.paste button[data-copy]')[1].textContent" % RB) == "Copy")
    check("a paste field and both stop buttons are in the block", js("!!%s.querySelector('.wk[data-hid=\"h3\"] .paste textarea[name=text]') && %s.querySelectorAll('button[data-act^=research-stop]').length === 2" % (RB, RB)))
    # A live run: the pill names its place, the gpu look, the spend of its box; the state line wraps on a phone, its box end in view.
    LB = "document.getElementById('job-research/%s')" % RL
    js("location.hash = 'job-research/%s'" % RL)
    check("a live research block shows", until("!%s.hidden" % LB, 2))
    check("a live run's pill reads On vast, in the gpu look", js("%s.querySelector('.pill').textContent === 'On vast' && %s.querySelector('.job').classList.contains('s-gpu')" % (LB, LB)))
    check("a live box counts its spend", js("%s.querySelector('.stats').textContent" % LB) == "$0.40 of $35")
    LINE = "[...%s.querySelectorAll('.job > p')].find(p => p.textContent.startsWith('on vast · '))" % LB
    WRAP = "(() => { const p = %s, r = document.createRange(); r.selectNodeContents(p); const q = [...r.getClientRects()]; return p.textContent.includes(' steps · eta ') && p.textContent.includes(' · box until ') && q.length > 1 && q[q.length - 1].right <= document.getElementById('panel').getBoundingClientRect().right && p.scrollWidth <= p.clientWidth; })()" % LINE
    check("the state line wraps on a phone, the box end in the panel", js(WRAP))
    # Drained: the held look is a ring with no fill; Stop now while its run lives, no Stop question, no Archive yet.
    DB = "document.getElementById('job-research/%s')" % RD
    js("location.hash = 'job-research/%s'" % RD)
    check("a drained research block shows", until("!%s.hidden" % DB, 2))
    check("a drained pill reads Drained, its lamp a ring with no fill", js("(() => { const l = getComputedStyle(%s.querySelector('.bh .lamp')); return %s.querySelector('.pill').textContent === 'Drained' && l.backgroundColor === 'rgba(0, 0, 0, 0)' && l.boxShadow !== 'none'; })()" % (DB, DB)))
    check("a drained card has Stop now alone while its run lives", js("[...%s.querySelectorAll('[data-research] button')].map(b => b.dataset.act).join()" % DB) == "research-stop-now")
    # The five tabs on a desk: each hash tab shows its page alone and is marked; Help ↗ opens Page words.
    cdp("Emulation.setDeviceMetricsOverride", {"width": 1440, "height": 900, "deviceScaleFactor": 1, "mobile": False})
    check("whoami shows the buttons", until("document.body.classList.contains('can')", 12))
    SEEN = "[...document.querySelectorAll('main > .page, main > #panel')].filter(p => getComputedStyle(p).display !== 'none').map(p => p.id).join()"
    MARK = "getComputedStyle(document.querySelector('.tabs a[href=\"#%s\"]')).borderBottomColor !== 'rgba(0, 0, 0, 0)'"
    RAW = re.compile(r"\bblocked\b|gate\.log", re.I)
    for h, want in (("recurring", "recurring"), ("workspaces", "workspaces"), ("settings", "settings"), ("jobs", "jobs,panel")):
        js("location.hash = '%s'" % h)
        check("tab %s shows its page alone, marked" % h, until("%s === '%s' && %s" % (SEEN, want, MARK % h), 2))
        check("no raw state word on tab %s" % h, not RAW.search(js("document.body.innerText")))
    HELP = "[...document.querySelectorAll('.tabs a')].filter(a => a.textContent === 'Help ↗').map(a => a.target + ' ' + a.getAttribute('href'))"
    check("Help ↗ opens Page words in a new tab", re.fullmatch(r"_blank https://github\.com/[^/]+/[^/]+/blob/HEAD/docs/vibe-queue\.md#page-words", (js(HELP) or [""])[0]) is not None)
    for b in js("[...document.querySelectorAll('#panel .blk')].map(b => b.id)"):
        js("location.hash = %s" % json.dumps(b))
        until("!document.getElementById(%s).hidden" % json.dumps(b), 2)
        check("no raw state word in %s" % b, not RAW.search(js("document.body.innerText")))
    check("a failed job's Checks log link reads Checks log", js("[...document.querySelectorAll('.files a')].some(a => a.textContent === 'Checks log' && a.href.endsWith('/gate.log'))"))
    js("location.hash = 'job-%s'" % A)
    check("Activity shows the job's last steps, agent text as text", until("document.querySelectorAll('#job-%s .act li').length === 3 && document.querySelector('#job-%s .act li.ag span:last-child').textContent.startsWith('The runner')" % (A, A), 4))
    # A write: the command and its seconds while it waits, then Done in N s; its button stays off until its card changes.
    MSG, BTN = "document.querySelector('.pmsg').textContent", "document.querySelector('#job-%s button[data-act=\"%s\"]')"
    js("%s.click(); %s.click()" % (BTN % (A, "archive"), BTN % (A, "archive")))
    check("a write in flight shows the command, its seconds and the writes before it; its button reads its verb", until("/^archive %s · [0-9]+ s · 2 writes before yours$/.test(%s)" % (A, MSG), 1) and js("%s.textContent" % (BTN % (A, "archive"))) == "Archiving…")
    check("once sent, the count leaves out the write itself", until("/^archive %s · [0-9]+ s · 1 write before yours$/.test(%s)" % (A, MSG), 2.5))
    writes(1)
    check("the count goes when the write before it ends", until("/^archive %s · [0-9]+ s$/.test(%s)" % (A, MSG), 2.5))
    edit(state(A, "moved"))
    time.sleep(2.5)
    check("a change in its card while the write runs keeps its button off", js("%s.disabled && %s.textContent === 'Archiving…'" % (BTN % (A, "archive"), BTN % (A, "archive"))) and js(ST % A) == "moved")
    check("a write that worked says Done in N s, with the output", until("/^Done in [0-9]+ s$/.test(%s)" % MSG, 5) and js("document.querySelector('.pbody pre').textContent") == "archived")
    time.sleep(2.5)
    check("its button stays off with its verb while the card is the same", js("%s.disabled && %s.textContent === 'Archiving…'" % (BTN % (A, "archive"), BTN % (A, "archive"))))
    edit(state(A, "archived"))
    check("a change in its card brings the button back", until("!%s.disabled && %s.textContent === 'Archive'" % (BTN % (A, "archive"), BTN % (A, "archive")), 4))
    js("document.querySelector('#job-%s textarea').value = 'why'; %s.click()" % (A, BTN % (A, "hold")))
    check("a write that failed says Failed (exit N), with the output; its button is back", until("%s === 'Failed (exit 1)' && !%s.disabled" % (MSG, BTN % (A, "hold")), 4) and js("document.querySelector('.pbody pre').textContent") == "no such job")
    js("%s.click()" % (BTN % (A, "retry")))
    check("a write with no answer says the command can still run; its button stays off", until("%s === 'No answer. The command can still run.'" % MSG, 4) and js("%s.disabled && %s.textContent === 'Starting…'" % (BTN % (A, "retry"), BTN % (A, "retry"))))
    SHOTS = os.environ.get("PAGE_SHOTS")
    if SHOTS:
        os.makedirs(SHOTS, exist_ok=True)
        edit(lambda h: FRESH)
        js("location.reload()")
        time.sleep(1)
        until("document.readyState === 'complete' && document.body.classList.contains('can')", 10)
        for name, w, h, mobile, hash_, dark in (("desk-2560x1440.png", 2560, 1440, False, "job-" + A, False),
                                                ("desk-1440x900.png", 1440, 900, False, "job-research/" + R, False),
                                                ("phone-390x844.png", 390, 844, True, "jobs", False),
                                                ("phone-390x844-panel.png", 390, 844, True, "job-" + A, False),
                                                ("desk-1440x900-dark.png", 1440, 900, False, "job-" + A, True),
                                                ("desk-1440x900-workspaces.png", 1440, 900, False, "workspaces", False),
                                                ("desk-1440x900-settings.png", 1440, 900, False, "settings", False)):
            cdp("Emulation.setEmulatedMedia", {"features": [{"name": "prefers-color-scheme", "value": "dark" if dark else "light"}]})
            cdp("Emulation.setDeviceMetricsOverride", {"width": w, "height": h, "deviceScaleFactor": 1, "mobile": mobile})
            js("location.hash = %s" % json.dumps(hash_))  # a navigation: :target picks the tab
            time.sleep(0.3)
            js("scrollTo(0, 0)")
            time.sleep(0.8)
            with open(os.path.join(SHOTS, name), "wb") as f:
                f.write(base64.b64decode(cdp("Page.captureScreenshot", {"format": "png"})["data"]))
finally:
    proc.kill()
    proc.wait()
    server.shutdown()
    shutil.rmtree(prof, ignore_errors=True)
    shutil.rmtree(root, ignore_errors=True)
sys.exit(1 if bad else 0)
