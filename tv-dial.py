"""DIAL server that makes the TV's kiosk browser a YouTube cast target.

Desktop Chrome finds cast targets on the LAN via DIAL, and smart TVs show
up there this way. This answers SSDP M-SEARCH for the DIAL service type,
serves the device description and a single app, YouTube. When a sender
launches it (Chrome's cast dialog on youtube.com), the POST body carries
YouTube's pairing parameters (pairingCode=...); the kiosk tab is navigated
to youtube.com/tv?<those parameters> over the Chrome DevTools protocol,
and the TV page then joins the sender's session through YouTube's servers.

The app is always reported "stopped", so every cast is a fresh launch with
the caster's own pairing code; a stop request returns the tab to the plain
TV home screen.
"""

import json
import os
import socket
import struct
import threading
import urllib.parse
import urllib.request
import uuid
from email.utils import formatdate
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from xml.sax.saxutils import escape

from websockets.sync.client import connect

HTTP_PORT = int(os.environ.get("HTTP_PORT", "56790"))
CDP_PORT = int(os.environ.get("CDP_PORT", "9222"))
FRIENDLY_NAME = os.environ.get("FRIENDLY_NAME", socket.gethostname())
TV_URL = os.environ.get("TV_URL", "https://www.youtube.com/tv")

SSDP_ADDR = "239.255.255.250"
SSDP_PORT = 1900
DIAL_ST = "urn:dial-multiscreen-org:service:dial:1"
APP = "YouTube"
MAX_BODY = 4096

with open("/etc/machine-id") as f:
    UDN = "uuid:" + str(uuid.uuid5(uuid.NAMESPACE_OID, "tv-dial:" + f.read().strip()))


def log(msg):
    print(msg, flush=True)


def local_ip_towards(addr):
    """The address of the interface that routes to addr (no packet is sent)."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.connect((addr, 9))
        return s.getsockname()[0]


# --- SSDP --------------------------------------------------------------------

def ssdp_loop():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("", SSDP_PORT))
    mreq = struct.pack("4s4s", socket.inet_aton(SSDP_ADDR), socket.inet_aton("0.0.0.0"))
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, mreq)
    log(f"SSDP listening on {SSDP_ADDR}:{SSDP_PORT}")
    while True:
        data, sender = sock.recvfrom(2048)
        lines = data.decode("utf-8", "replace").split("\r\n")
        if not lines[0].upper().startswith("M-SEARCH"):
            continue
        headers = {}
        for line in lines[1:]:
            k, sep, v = line.partition(":")
            if sep:
                headers[k.strip().upper()] = v.strip()
        st = headers.get("ST", "")
        if st not in (DIAL_ST, "ssdp:all"):
            continue
        ip = local_ip_towards(sender[0])
        reply = "\r\n".join([
            "HTTP/1.1 200 OK",
            "CACHE-CONTROL: max-age=1800",
            f"DATE: {formatdate(usegmt=True)}",
            "EXT:",
            f"LOCATION: http://{ip}:{HTTP_PORT}/dd.xml",
            "SERVER: Linux UPnP/1.1 tv-dial/1.0",
            f"ST: {DIAL_ST}",
            f"USN: {UDN}::{DIAL_ST}",
            "BOOTID.UPNP.ORG: 1",
            "CONFIGID.UPNP.ORG: 1",
            "", "",
        ])
        sock.sendto(reply.encode(), sender)
        log(f"M-SEARCH from {sender[0]}:{sender[1]} -> answered")


# --- Browser control ---------------------------------------------------------

def navigate(url):
    with urllib.request.urlopen(f"http://127.0.0.1:{CDP_PORT}/json/list", timeout=5) as r:
        targets = json.load(r)
    page = next(t for t in targets if t["type"] == "page")
    with connect(page["webSocketDebuggerUrl"], open_timeout=5, max_size=None) as ws:
        ws.send(json.dumps({"id": 1, "method": "Page.navigate", "params": {"url": url}}))
        while True:
            msg = json.loads(ws.recv(timeout=10))
            if msg.get("id") == 1:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return


# --- DIAL REST ---------------------------------------------------------------

DEVICE_XML = f"""<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <device>
    <deviceType>urn:dial-multiscreen-org:device:dial:1</deviceType>
    <friendlyName>{escape(FRIENDLY_NAME)}</friendlyName>
    <manufacturer>Orange Pi</manufacturer>
    <modelName>Orange Pi 5 Plus</modelName>
    <UDN>{UDN}</UDN>
  </device>
</root>
"""

APP_XML = f"""<?xml version="1.0" encoding="UTF-8"?>
<service xmlns="urn:dial-multiscreen-org:schemas:dial" dialVer="2.1">
  <name>{APP}</name>
  <options allowStop="true"/>
  <state>stopped</state>
</service>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "tv-dial/1.0"

    def log_message(self, fmt, *args):
        log(f"{self.client_address[0]} {fmt % args}")

    def app_url(self):
        host = self.headers.get("Host") or f"{self.server.server_address[0]}:{HTTP_PORT}"
        return f"http://{host}/apps/"

    def reply(self, code, body=b"", content_type=None, headers=()):
        self.send_response(code)
        if content_type:
            self.send_header("Content-Type", content_type)
        for k, v in headers:
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/dd.xml":
            ip = self.connection.getsockname()[0]
            self.reply(200, DEVICE_XML.encode(), 'text/xml; charset="utf-8"',
                       [("Application-URL", f"http://{ip}:{HTTP_PORT}/apps/")])
        elif path == f"/apps/{APP}":
            self.reply(200, APP_XML.encode(), 'text/xml; charset="utf-8"')
        else:
            self.reply(404)

    def do_POST(self):
        if self.path.split("?")[0] != f"/apps/{APP}":
            return self.reply(404)
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            return self.reply(413)
        body = self.rfile.read(length).decode("utf-8", "replace")
        # Re-encode so only well-formed query parameters reach the URL.
        params = urllib.parse.urlencode(urllib.parse.parse_qsl(body, keep_blank_values=True))
        url = f"{TV_URL}?{params}" if params else TV_URL
        log(f"launch: {url}")
        try:
            navigate(url)
        except Exception as e:
            log(f"launch failed: {e!r}")
            return self.reply(503)
        self.reply(201, headers=[("Location", f"{self.app_url()}{APP}/run")])

    def do_DELETE(self):
        if self.path.split("?")[0] != f"/apps/{APP}/run":
            return self.reply(404)
        log("stop")
        try:
            navigate(TV_URL)
        except Exception as e:
            log(f"stop failed: {e!r}")
        self.reply(200)


def main():
    threading.Thread(target=ssdp_loop, daemon=True).start()
    log(f"DIAL '{FRIENDLY_NAME}' {UDN} on :{HTTP_PORT}")
    ThreadingHTTPServer(("", HTTP_PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
