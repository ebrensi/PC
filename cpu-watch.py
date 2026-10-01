"""Detect sustained runaway CPU use and publish a banner for login shells.

Samples /proc every INTERVAL seconds and averages over a WINDOW-second
sliding window, so short bursts (compiles, page loads) never trigger.
Raises an alert when either
  - a single process averages >= PROC_PCT (% of one core), or
  - all processes together average >= SYS_PCT (% of all cores).
Alerts clear with hysteresis (below 75% of the threshold) or when the
process exits. Active alerts are rendered to $RUNTIME_DIRECTORY/alerts,
which interactive shells print; raise/clear events go to the journal.
"""

import glob
import os
import pwd
import time
from collections import deque

INTERVAL = int(os.environ.get("INTERVAL", "30"))
WINDOW = int(os.environ.get("WINDOW", "600"))
PROC_PCT = float(os.environ.get("PROC_PCT", "90"))
SYS_PCT = float(os.environ.get("SYS_PCT", "40"))
EXCLUDE_USER_PREFIXES = tuple(os.environ.get("EXCLUDE_USER_PREFIXES", "nixbld").split())
OUT_DIR = os.environ.get("RUNTIME_DIRECTORY", "/run/cpu-watch")
CLEAR_RATIO = 0.75

CLK_TCK = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count()
HOST = os.uname().nodename
YELLOW, BOLD, DIM, RESET = "\033[33m", "\033[1m", "\033[2m", "\033[0m"


def username(uid):
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)


def read_procs():
    """Return {(pid, starttime): (comm, uid, cpu_ticks)}; starttime guards against pid reuse."""
    procs = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
            uid = os.stat(f"/proc/{pid}").st_uid
        except OSError:
            continue
        # comm may contain spaces or parens, so split around the last ')'.
        rparen = stat.rfind(")")
        comm = stat[stat.find("(") + 1:rparen]
        fields = stat[rparen + 2:].split()
        utime, stime, start = int(fields[11]), int(fields[12]), int(fields[19])
        procs[(int(pid), start)] = (comm, uid, utime + stime)
    return procs


def cmdline(pid, limit=160):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmd = f.read().replace(b"\0", b" ").decode(errors="replace").strip()
    except OSError:
        return ""
    return cmd if len(cmd) <= limit else cmd[:limit] + "..."


def sensors():
    """Fan RPMs and temperatures from any hwmon device that reports fans."""
    parts = []
    for fan in sorted(glob.glob("/sys/class/hwmon/hwmon*/fan*_input")):
        base = fan.removesuffix("_input")
        parts.append(f"{read_label(base, 'fan')} {read_int(fan)} RPM")
        hwmon = os.path.dirname(fan)
    if parts:
        for temp in sorted(glob.glob(f"{hwmon}/temp*_input")):
            base = temp.removesuffix("_input")
            parts.append(f"{read_label(base, 'temp')} {read_int(temp) // 1000}°C")
    return ", ".join(parts)


def read_label(base, default):
    try:
        with open(base + "_label") as f:
            return f.read().strip()
    except OSError:
        return default


def read_int(path):
    try:
        with open(path) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return 0


def fmt_duration(seconds):
    minutes = int(seconds // 60)
    return f"{minutes // 60}h{minutes % 60:02d}m" if minutes >= 60 else f"{minutes}m"


def describe(key, info, pct):
    pid = key[0]
    return f"pid {pid} {info[0]} ({username(info[1])}) {pct:.0f}%\n      {DIM}{cmdline(pid)}{RESET}"


def render(proc_alerts, sys_alert, usage, procs, now):
    if not proc_alerts and sys_alert is None:
        return ""
    win = fmt_duration(WINDOW)
    lines = [f"{YELLOW}{BOLD}⚠ cpu-watch: sustained high CPU on {HOST}{RESET}"]
    for key, since in sorted(proc_alerts.items(), key=lambda kv: -usage.get(kv[0], 0)):
        lines.append(f"  {BOLD}runaway{RESET} for {fmt_duration(now - since)}: "
                     + describe(key, procs[key], usage.get(key, 0)) + f"  {DIM}(avg over {win}){RESET}")
    if sys_alert is not None:
        total = sum(usage.values()) / NCPU
        lines.append(f"  {BOLD}system{RESET} at {total:.0f}% of {NCPU} CPUs for {fmt_duration(now - sys_alert)}; top:")
        for key in sorted(usage, key=usage.get, reverse=True)[:5]:
            lines.append("    " + describe(key, procs[key], usage[key]))
    lines.append(f"  {DIM}{sensors()}{RESET}")
    lines.append(f"  {DIM}history: journalctl -u cpu-watch{RESET}")
    return "\n".join(lines) + "\n"


def publish(text):
    path = os.path.join(OUT_DIR, "alerts")
    if not text:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
        return
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def log(msg):
    print(msg, flush=True)


def main():
    samples = WINDOW // INTERVAL
    history = deque(maxlen=samples + 1)
    proc_alerts = {}  # key -> wall-clock start of the sustained window
    sys_alert = None
    excluded = {}
    log(f"watching: process >= {PROC_PCT:.0f}% of a core or system >= {SYS_PCT:.0f}% "
        f"of {NCPU} CPUs, sustained {fmt_duration(WINDOW)}")

    while True:
        mono, wall = time.monotonic(), time.time()
        procs = read_procs()
        history.append((mono, procs))
        if len(history) < history.maxlen:
            time.sleep(INTERVAL)
            continue

        t0, old = history[0]
        elapsed = mono - t0
        usage = {}
        for key, (comm, uid, ticks) in procs.items():
            if key not in old:
                continue  # younger than the window
            if uid not in excluded:
                excluded[uid] = username(uid).startswith(EXCLUDE_USER_PREFIXES)
            if not excluded[uid]:
                usage[key] = (ticks - old[key][2]) / CLK_TCK / elapsed * 100

        for key in list(proc_alerts):
            if usage.get(key, 0) < PROC_PCT * CLEAR_RATIO:
                comm = procs[key][0] if key in procs else old.get(key, ("?",))[0]
                state = "recovered" if key in procs else "exited"
                log(f"CLEARED pid {key[0]} {comm} {state} after {fmt_duration(wall - proc_alerts.pop(key))}")
        for key, pct in usage.items():
            if pct >= PROC_PCT and key not in proc_alerts:
                proc_alerts[key] = wall - elapsed
                log(f"RAISED runaway {describe(key, procs[key], pct)} | {sensors()}")

        total = sum(usage.values()) / NCPU
        if sys_alert is None and total >= SYS_PCT:
            sys_alert = wall - elapsed
            top = sorted(usage, key=usage.get, reverse=True)[:5]
            log(f"RAISED system at {total:.0f}% | {sensors()} | top: "
                + "; ".join(f"pid {k[0]} {procs[k][0]} {usage[k]:.0f}%" for k in top))
        elif sys_alert is not None and total < SYS_PCT * CLEAR_RATIO:
            log(f"CLEARED system load after {fmt_duration(wall - sys_alert)}")
            sys_alert = None

        publish(render(proc_alerts, sys_alert, usage, procs, wall))
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
