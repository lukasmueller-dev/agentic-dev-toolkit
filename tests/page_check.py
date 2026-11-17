"""page_check.py BROWSER WEB_DIR A B — drive page.js in a headless browser (CDP over --remote-debugging-pipe).

WEB_DIR holds the page `vibe queue page` wrote, with blocked jobs A and B; it is served under /queue/ and changed
in place. Prints one line per check; exits 1 when one fails, 77 when the browser does not start (a sandbox that
refuses its sockets). Used by tests/vibe-web.bats.
"""
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

BROWSER, WEB, A, B = sys.argv[1:5]
PAGE = os.path.join(WEB, "index.html")
signal.alarm(80)  # a hung browser fails the test instead of the suite

root = tempfile.mkdtemp()
os.symlink(WEB, os.path.join(root, "queue"))
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
handler.func.log_message = lambda *a: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
URL = "http://127.0.0.1:%d/queue/index.html" % server.server_address[1]


def edit(fn):
    with open(PAGE, encoding="utf-8") as f:
        html = f.read()
    with open(PAGE, "w", encoding="utf-8") as f:
        f.write(fn(html))


def state(job, text):
    """The page with JOB's block head state set to TEXT."""
    return lambda h: re.sub(r'(id="job-%s" hidden><div class="bh"><i class="lamp l-[a-z]+"></i><span class="st">)[^<]*' % re.escape(job), r"\g<1>" + text, h)


# Two service rows, the first with a Place form.
ROW = '<div class="wrow" id="ws-%s"><i class="lamp l-off"></i><div class="t"><b>%s</b><span class="why">Off</span></div>%s</div>'
FORM = '<div class="jacts" data-name="one"><span class="ask"><label>Place<select name="place"><option>turing</option><option>runpod</option></select></label><button data-act="ws-start">Start</button></span></div>'
edit(lambda h: re.sub(r'(<section id="workspaces" class="page">\n).*?(\n</section>)', lambda m: m.group(1) + '<section class="sec" aria-label="Services">' + ROW % ("one", "One", FORM) + ROW % ("two", "Two", "") + '</section>' + m.group(2), h, count=1, flags=re.S))

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
    check("the hash shows its block", js("!document.getElementById('job-%s').hidden" % A))
    # Half a note in A's field, then B in the panel.
    js("document.querySelector('#job-%s textarea').value = 'half'" % A)
    js("location.hash = 'job-%s'" % B)
    check("another row shows its block", until("!document.getElementById('job-%s').hidden" % B, 2))
    # A select in New job set to its second option, then left: no field has focus.
    js("(() => { const s = document.createElement('select'); s.add(new Option('a')); s.add(new Option('b')); s.selectedIndex = 1; document.querySelector('#new .bh').append(s); })()")
    # One's Place set to runpod, then left.
    js("document.querySelector('#ws-one select').selectedIndex = 1")
    # The runner writes a new page: A and B change, a new block C, a new Needs-you count, a fresh render.
    edit(lambda h: state(B, "changed")(state(A, "changed")(h)))
    edit(lambda h: h.replace('<div class="blk" id="new" hidden>', '<div class="blk" id="job-C" hidden><div class="bh"><h2>C</h2></div></div>\n<div class="blk" id="new" hidden>', 1))
    edit(lambda h: re.sub(r'(<h2>Needs you <span class="n">)[0-9]+', r"\g<1>3", h))
    edit(lambda h: h.replace('<h2>New job</h2>', '<h2>New job 2</h2>', 1))
    edit(lambda h: h.replace('<span class="why">Off</span>', '<span class="why">up</span>'))
    edit(lambda h: re.sub(r'data-t="[0-9]+"', 'data-t="%d"' % time.time(), h))
    check("the block without a field in use swaps", until((ST % B) + " === 'changed'", 13))
    check("a block with text in a field stays", js(ST % A) == "blocked" and js("document.querySelector('#job-%s textarea').value" % A) == "half")
    check("a block with a changed select and no focus stays", js("document.querySelector('#new h2').textContent") == "New job" and js("document.querySelector('#new .bh select').selectedIndex") == 1)
    check("a new block arrives", js("!!document.getElementById('job-C')"))
    WHY = "document.querySelector('#ws-%s .why').textContent"
    check("a changed select holds only itself: the other row and its own row's text swap", js(WHY % "two") == "up" and js(WHY % "one") == "up")
    check("the changed select keeps its value", js("document.querySelector('#ws-one select').selectedIndex") == 1)
    check("the list swaps", js("document.querySelector('[data-k=\"you\"] h2 .n').textContent") == "3")
    check("a fresh render is not stale", js("!document.querySelector('.updated').classList.contains('stale')"))
    js("location.hash = 'job-C'")
    check("the new block shows", until("!document.getElementById('job-C').hidden", 2))
    # The field empties: the next poll swaps that block too.
    js("document.querySelector('#job-%s textarea').value = ''" % A)
    js("document.querySelector('#new .bh select').selectedIndex = 0")
    check("an emptied field lets its block swap", until((ST % A) + " === 'changed'", 13))
    check("a select back at its default lets its block swap", until("document.querySelector('#new h2').textContent === 'New job 2'", 2))
finally:
    proc.kill()
    proc.wait()
    server.shutdown()
    shutil.rmtree(prof, ignore_errors=True)
    shutil.rmtree(root, ignore_errors=True)
sys.exit(1 if bad else 0)
