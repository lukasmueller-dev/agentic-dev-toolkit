#!/usr/bin/env python3
"""A stand-in for BSD date(1), so the suite can exercise the non-GNU branch.

The date handling in skills/weekly-report/report.sh is the one part of it that
cannot be checked on the machine it is written on: the GNU and BSD spellings
share no syntax, and CI's macOS leg is opt-in and billed at 10x. This stub
closes that gap by answering exactly what BSD date answers, and — just as
importantly — refusing exactly what it refuses.

Supported, because report.sh uses them:

    date --version                          exits 1 (BSD has no such flag;
                                            this is how the script detects GNU)
    date -u -j -f IN_FMT INPUT +OUT_FMT     parse, then format
    date -u -r SECONDS +OUT_FMT             render an epoch
    date +OUT_FMT                           now

Everything else exits 2, which is the point. The bug this stub exists to catch
was `-v${n}d` combined with `-f`: valid-looking, accepted by GNU's manual page
in spirit, and rejected outright by the real BSD date.
"""

import sys
from datetime import datetime, timedelta, timezone

# BSD strftime does support %F, %G and %V; Python's does not spell %F, so it is
# expanded before handing the string over. %s is computed rather than formatted
# because Python's strftime does not implement it portably.
def fmt(dt, spec):
    spec = spec.lstrip("+").replace("%F", "%Y-%m-%d")
    if "%s" in spec:
        epoch = int((dt - datetime(1970, 1, 1, tzinfo=timezone.utc)).total_seconds())
        spec = spec.replace("%s", str(epoch))
    return dt.strftime(spec) if "%" in spec else spec


def main(argv):
    args = list(argv)
    if "--version" in args:
        # The discriminator: BSD date has no --version, and report.sh reads a
        # non-zero exit here as "this is not GNU".
        sys.stderr.write("date: illegal option -- -\n")
        return 1

    parse_fmt = None
    epoch = None
    jflag = False
    operand = None
    out_fmt = "+%a %b %e %H:%M:%S %Z %Y"

    i = 0
    while i < len(args):
        a = args[i]
        if a == "-u":
            i += 1
        elif a == "-j":
            jflag = True
            i += 1
        elif a == "-f":
            parse_fmt = args[i + 1]
            i += 2
        elif a == "-r":
            epoch = int(args[i + 1])
            i += 2
        elif a.startswith("+"):
            out_fmt = a
            i += 1
        elif a.startswith("-"):
            # -d, -v and friends. BSD accepts -v, but not alongside -f, which
            # is the combination report.sh used to reach for.
            sys.stderr.write("date: illegal option or combination: %s\n" % a)
            return 2
        else:
            operand = a
            i += 1

    if epoch is not None:
        dt = datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=epoch)
    elif parse_fmt is not None:
        if operand is None or not jflag:
            sys.stderr.write("date: illegal time format\n")
            return 2
        try:
            dt = datetime.strptime(operand, parse_fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            sys.stderr.write("date: illegal time format\n")
            return 2
    else:
        dt = datetime.now(timezone.utc)

    print(fmt(dt, out_fmt))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
