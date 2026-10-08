"""Stops YouTube on the kiosk while the TV screen is off.

The TV keeps HDMI hotplug asserted in standby, so the connector reads
"connected" either way. HDMI-CEC tells them apart: the TV acknowledges a
CEC poll to logical address 0 while it is on and ignores it in standby.
(This needs nothing beyond the TV's CEC hardware; with SimpLink off it
acks but answers no requests, so a power-status query would not do.)

While the TV is off, the kiosk tab is parked on about:blank, which drops
the stream and its bandwidth; when it comes back on, the tab returns to
the TV home screen. The check is level-triggered, so a cast that lands
while the screen is off is parked too.

The HDMI outputs stay powered on. Powering them down with sway while the
TV was off hard-froze the board (2026-10-08), most likely CEC touching
the HDMI block after it lost its clocks, and saves under a watt anyway.
"""

import glob
import json
import os
import subprocess
import time
import urllib.request

from websockets.sync.client import connect

CDP_PORT = int(os.environ.get("CDP_PORT", "9222"))
TV_URL = os.environ.get("TV_URL", "https://www.youtube.com/tv")
OSD_NAME = os.environ.get("OSD_NAME", "TV-Pi")
INTERVAL = 30  # seconds between polls
OFF_AFTER = 2  # consecutive unacked polls before the TV counts as off
PARKED = "about:blank"


def log(msg):
    print(msg, flush=True)


def adapters():
    """CEC devices of the HDMI outputs (not the board's HDMI input)."""
    return sorted(
        "/dev/" + os.path.basename(d)
        for d in glob.glob("/sys/bus/cec/devices/cec*")
        if os.path.basename(os.path.dirname(os.path.realpath(d))).endswith(".hdmi")
    )


def cec_ctl(dev, *args):
    r = subprocess.run(["cec-ctl", "-d", dev, *args], capture_output=True, text=True, timeout=15)
    return r.stdout + r.stderr


def tv_acks(dev):
    # cec-ctl exits 0 even when the poll goes unacknowledged.
    out = cec_ctl(dev, "--poll", "-t0")
    return "Tx Timestamp" in out and "Not Acknowledged" not in out


def page():
    with urllib.request.urlopen(f"http://127.0.0.1:{CDP_PORT}/json/list", timeout=5) as r:
        return next(t for t in json.load(r) if t["type"] == "page")


def navigate(target, url):
    with connect(target["webSocketDebuggerUrl"], open_timeout=5, max_size=None) as ws:
        ws.send(json.dumps({"id": 1, "method": "Page.navigate", "params": {"url": url}}))
        while True:
            msg = json.loads(ws.recv(timeout=10))
            if msg.get("id") == 1:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return


def main():
    devs = adapters()
    # Polling needs a logical address of our own; the kernel keeps the
    #  claim across hotplugs.
    for dev in devs:
        cec_ctl(dev, "--playback", "--osd-name", OSD_NAME)
    log(f"watching {', '.join(devs)}")

    misses = 0
    last = None
    while True:
        misses = 0 if any(tv_acks(d) for d in devs) else misses + 1
        on = misses < OFF_AFTER
        if on != last:
            log(f"TV {'on' if on else 'off'}")
            last = on
        try:
            target = page()
            parked = target["url"] == PARKED
            if not on and not parked:
                log(f"parking {target['url']}")
                navigate(target, PARKED)
            elif on and parked:
                log("restoring TV home screen")
                navigate(target, TV_URL)
        except Exception as e:
            log(f"browser control failed: {e!r}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
