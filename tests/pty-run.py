#!/usr/bin/env python3
"""Run a command under a pseudo-terminal, playing the part of the terminal.

The suite needs this for one thing only: vibe's drain_tty is unreachable
without a tty on stdin, so the bug it fixes — a terminal's answer to a query
arriving after the program that asked is gone — cannot be reproduced with a
pipe.

As "the terminal" this driver answers, LAG seconds later, the way a real one
does over a link with latency:

  * a cursor-position report (ESC [ 6 n) with ESC [ 24;1 R;
  * MARKER, once it appears in the child's output, with STALE — an OSC 11
    background-colour answer, exactly what tmux's attach-time query provokes.
    The marker is how a test says "the tmux client has just gone away", which
    is the moment the stale answer is in flight.

Answers are queued and written in order, as a terminal sends them. Everything
the child prints is relayed to stdout, so the caller asserts on it normally.

Usage: pty-run.py <command> [args...]
Environment: PTY_RUN_MARKER, PTY_RUN_LAG, PTY_RUN_TIMEOUT.
"""

import os
import pty
import select
import signal
import sys
import time

STALE = b"\x1b]11;rgb:1818/1818/1818\x1b\\"
CURSOR = b"\x1b[24;1R"
MARKER = os.environ.get("PTY_RUN_MARKER", "").encode()
LAG = float(os.environ.get("PTY_RUN_LAG", "0.15"))
LIMIT = float(os.environ.get("PTY_RUN_TIMEOUT", "60"))


def main(argv):
    if not argv:
        sys.stderr.write("usage: pty-run.py <command> [args...]\n")
        return 2

    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.execvp(argv[0], argv)

    out = b""
    queued = []  # (due, bytes) — answers still on their way back to the child
    marker_seen = False
    start = time.time()
    while time.time() - start < LIMIT:
        now = time.time()
        for answer in list(queued):
            if now >= answer[0]:
                os.write(fd, answer[1])
                queued.remove(answer)
        ready, _, _ = select.select([fd], [], [], 0.02)
        if not ready:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError:  # the child closed the pty: it has exited
            break
        if not chunk:
            break
        out += chunk
        if MARKER and not marker_seen and MARKER in out:
            marker_seen = True
            queued.append((time.time() + LAG, STALE))
        queued.extend(
            (time.time() + LAG, CURSOR) for _ in range(chunk.count(b"\x1b[6n"))
        )

    sys.stdout.buffer.write(out)
    sys.stdout.buffer.flush()
    if time.time() - start >= LIMIT:  # child never finished — do not hang here
        os.kill(pid, signal.SIGKILL)
    _, status = os.waitpid(pid, 0)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
