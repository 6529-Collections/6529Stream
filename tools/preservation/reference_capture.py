"""Pinned native Chromium capture for the declared synchronous canvas still profile.

The input is the exact original HTML. Runtime restrictions are explicit capture
environment instrumentation, not a rewrite of that source or a static classifier.
This tool neither signs reference-render records nor supplies archive receipts.
"""

from __future__ import annotations

import argparse
import base64
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time

PROFILE = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"
FLAGS = (
    "--headless=new", "--disable-gpu", "--force-color-profile=srgb",
    "--force-device-scale-factor=1", "--disable-lcd-text", "--hide-scrollbars",
    "--no-first-run", "--no-default-browser-check", "--disable-background-networking",
    "--disable-component-update", "--disable-sync", "--metrics-recording-only",
    "--disable-default-apps", "--disable-extensions", "--disable-breakpad",
    "--disable-features=Translate,MediaRouter,OptimizationHints",
    "--password-store=basic", "--use-mock-keychain", "--lang=en-US",
    "--enable-automation", "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=0",
)

# No original HTML byte is modified. These guards define this capture profile's
# deliberately finite runtime environment. Successful execution is not proof
# that arbitrary unreachable JavaScript or a work is intrinsically static.
GUARDS = r"""(() => {
  const rejected = [];
  const fail = name => function() { rejected.push(name); throw new Error('STREAM_UNSUPPORTED:' + name); };
  Object.defineProperty(globalThis, '__streamUnsupported', {get: () => rejected.slice(), configurable: false});
  for (const name of ['setTimeout','setInterval','requestAnimationFrame','requestIdleCallback',
    'fetch','WebSocket','EventSource','Worker','SharedWorker','Audio','AudioContext',
    'webkitAudioContext','OffscreenCanvas','Image','VideoFrame']) {
    if (name in globalThis) Object.defineProperty(globalThis, name, {value: fail(name), writable: false, configurable: false});
  }
  Math.random = fail('Math.random');
  Date.now = fail('Date.now');
  const DateOriginal = Date;
  globalThis.Date = new Proxy(DateOriginal, {apply: fail('Date'), construct: fail('Date')});
  for (const name of ['fillText','strokeText','measureText','drawImage'])
    CanvasRenderingContext2D.prototype[name] = fail(name);
  const context = HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext = function(kind, options) {
    if (kind !== '2d') return fail('canvas context:' + kind)();
    return context.call(this, kind, options);
  };
})()"""

INSPECT = r"""(() => {
 const body = document.body;
 const canvases = [...document.querySelectorAll('canvas')];
 const nodes = [...document.querySelectorAll('body *')];
 const text = [...body.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent).join('');
 return {
   unsupported: globalThis.__streamUnsupported,
   nodes: nodes.map(n => n.tagName), text,
   canvas: canvases.map(c => ({width:c.width,height:c.height,x:c.getBoundingClientRect().x,
     y:c.getBoundingClientRect().y,displayWidth:c.getBoundingClientRect().width,
     displayHeight:c.getBoundingClientRect().height})),
   animations: document.getAnimations().length,
   width: innerWidth, height: innerHeight, ratio: devicePixelRatio,
   resources: performance.getEntriesByType('resource').map(e => e.name)
 };
})()"""


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value: object) -> bytes:
    """Deterministic diagnostic JSON; no RFC8785 registration claim is made."""
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
                      allow_nan=False).encode("utf-8")


def loaded_modules(process_ids: list[int]) -> list[dict]:
    """Read only our explicitly supplied capture processes, including the runner.

    Native OS prerequisites are retained as exact file identities. This inventory
    does not say that Windows itself has been included in the runtime package.
    """
    if sys.platform != "win32":
        raise ValueError("this profile requires its named Windows platform")
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    psapi.EnumProcessModulesEx.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.HMODULE),
                                          wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.DWORD]
    psapi.GetModuleFileNameExW.argtypes = [wintypes.HANDLE, wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]
    found = set()
    for pid in sorted(set(process_ids + [os.getpid()])):
        handle = kernel.OpenProcess(0x0410, False, pid)
        if not handle:
            raise OSError(ctypes.get_last_error(), "cannot inventory capture process")
        try:
            size = 256
            while True:
                modules = (wintypes.HMODULE * size)()
                needed = wintypes.DWORD()
                if not psapi.EnumProcessModulesEx(handle, modules, ctypes.sizeof(modules), ctypes.byref(needed), 3):
                    raise OSError(ctypes.get_last_error(), "cannot inventory capture modules")
                if needed.value <= ctypes.sizeof(modules):
                    break
                size = (needed.value // ctypes.sizeof(wintypes.HMODULE)) + 16
            for module in modules[:needed.value // ctypes.sizeof(wintypes.HMODULE)]:
                name = ctypes.create_unicode_buffer(32768)
                length = psapi.GetModuleFileNameExW(handle, module, name, len(name))
                if not length or length == len(name):
                    raise OSError(ctypes.get_last_error(), "cannot identify capture module")
                found.add(str(Path(name.value).resolve(strict=True)))
        finally:
            kernel.CloseHandle(handle)
    return [{"path": name, "bytes": Path(name).stat().st_size,
             "sha256": digest(Path(name).read_bytes())} for name in sorted(found, key=str.casefold)]


def check_inspection(value: dict, width: int, height: int) -> None:
    if value["unsupported"] or value["animations"] or value["resources"]:
        raise ValueError("unsupported runtime feature")
    if value["text"].strip() or any(n not in ("CANVAS", "SCRIPT") for n in value["nodes"]):
        raise ValueError("only a canvas and the original script are supported")
    expected = {"width": width, "height": height, "x": 0, "y": 0,
                "displayWidth": width, "displayHeight": height}
    if value["canvas"] != [expected]:
        raise ValueError("canvas must exactly occupy the viewport")
    if (value["width"], value["height"], value["ratio"]) != (width, height, 1):
        raise ValueError("capture viewport differs")


class CDP:
    def __init__(self, url: str):
        from websockets.sync.client import connect
        # The endpoint is emitted by our new local process, never a caller URL.
        self.socket = connect(url, open_timeout=10, max_size=32 * 1024 * 1024,
                              compression=None, proxy=None)
        self.next_id = 0
        self.events: list[dict] = []
        self.messages: dict[int, dict] = {}

    def call(self, method: str, params: dict | None = None, session: str | None = None):
        self.next_id += 1
        wanted = self.next_id
        request = {"id": wanted, "method": method, "params": params or {}}
        if session is not None:
            request["sessionId"] = session
        self.socket.send(json.dumps(request))
        deadline = time.monotonic() + 20
        while wanted not in self.messages:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(method)
            response = json.loads(self.socket.recv(timeout=remaining))
            if "id" in response:
                self.messages[response["id"]] = response
            else:
                self.events.append(response)
        response = self.messages.pop(wanted)
        if "error" in response:
            raise ValueError(f"CDP {method}: {response['error']}")
        return response.get("result", {})

    def close(self):
        self.socket.close()


def capture_once(engine: Path, html: bytes, width: int, height: int) -> tuple[bytes, dict]:
    if not (type(width) is int and type(height) is int and 1 <= width <= 4096 and 1 <= height <= 4096):
        raise ValueError("viewport outside this capture profile")
    source = html.decode("utf-8", errors="strict")
    if not source.startswith("<html><head></head><body><script>") or not source.endswith("</script></body></html>"):
        raise ValueError("expected exact native Stream HTML wrapper")
    if len(html) > 65536:
        raise ValueError("HTML exceeds native serving bound")
    engine = engine.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="stream-reference-") as directory:
        profile = Path(directory)
        command = [str(engine), *FLAGS, f"--user-data-dir={profile}", "about:blank"]
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL,
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        cdp = None
        try:
            active = profile / "DevToolsActivePort"
            deadline = time.monotonic() + 20
            while not active.is_file():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("private browser failed to start")
                time.sleep(0.02)
            lines = active.read_text("utf-8").splitlines()
            port = int(lines[0])
            if not (0 < port < 65536) or not lines[1].startswith("/devtools/browser/"):
                raise ValueError("unexpected local CDP endpoint")
            cdp = CDP(f"ws://127.0.0.1:{port}{lines[1]}")
            version = cdp.call("Browser.getVersion")
            system = cdp.call("SystemInfo.getInfo")
            features = system["gpu"]["featureStatus"]
            if features.get("gpu_compositing") != "disabled_software" or features.get("rasterization") != "disabled_software":
                raise ValueError("software rasterization not established")
            if not system["gpu"]["auxAttributes"].get("sandboxed"):
                raise ValueError("sandboxed GPU process required")
            target = cdp.call("Target.createTarget", {"url": "about:blank"})["targetId"]
            session = cdp.call("Target.attachToTarget", {"targetId": target, "flatten": True})["sessionId"]
            def call(method, params=None):
                return cdp.call(method, params, session)
            call("Page.enable")
            call("Runtime.enable")
            call("Network.enable")
            call("Network.setBlockedURLs", {"urls": ["http://*", "https://*", "file://*", "ftp://*", "ws://*", "wss://*"]})
            call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
            call("Emulation.setLocaleOverride", {"locale": "en-US"})
            call("Emulation.setTimezoneOverride", {"timezoneId": "UTC"})
            call("Emulation.setEmulatedMedia", {"features": [{"name": "prefers-color-scheme", "value": "light"}, {"name": "prefers-reduced-motion", "value": "reduce"}]})
            call("Page.addScriptToEvaluateOnNewDocument", {"source": GUARDS})
            url = "data:text/html;base64," + base64.b64encode(html).decode("ascii")
            call("Page.navigate", {"url": url})
            deadline = time.monotonic() + 10
            while True:
                state = call("Runtime.evaluate", {"expression": "document.readyState", "returnByValue": True})
                if state["result"].get("value") == "complete":
                    break
                if time.monotonic() > deadline:
                    raise TimeoutError("document did not complete")
                time.sleep(0.01)
            inspected = call("Runtime.evaluate", {"expression": INSPECT, "returnByValue": True})
            if "exceptionDetails" in inspected:
                raise ValueError("inspection failed")
            observation = inspected["result"]["value"]
            check_inspection(observation, width, height)
            # Attributed STATIC declaration is external; pausing virtual time is
            # a capture environment setting, not evidence of work classification.
            call("Emulation.setVirtualTimePolicy", {"policy": "pause"})
            png = base64.b64decode(call("Page.captureScreenshot", {"format": "png", "fromSurface": True,
                                      "captureBeyondViewport": False, "optimizeForSpeed": False})["data"], validate=True)
            call("Runtime.evaluate", {"expression": "0", "returnByValue": True})
            bad = [e for e in cdp.events if e.get("sessionId") == session and
                   (e["method"] in ("Runtime.exceptionThrown", "Network.loadingFailed") or
                    (e["method"] == "Network.requestWillBeSent" and e["params"]["request"]["url"] != url))]
            if bad:
                raise ValueError("page error or unsupported resource request")
            if not png.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("browser did not return PNG")
            actual_args = cdp.call("Browser.getBrowserCommandLine")["arguments"]
            if "--no-sandbox" in actual_args:
                raise ValueError("browser sandbox disabled")
            processes = cdp.call("SystemInfo.getProcessInfo")["processInfo"]
            modules = loaded_modules([row["id"] for row in processes])
            facts = {"profile": PROFILE, "browser": version,
                     "engineSha256": digest(engine.read_bytes()), "gpu": system["gpu"],
                     "command": [a.replace(str(profile), "<fresh-profile>") for a in actual_args],
                     "os": {"platform": sys.platform, "version": platform.version(), "machine": platform.machine()},
                     "viewport": {"width": width, "height": height, "deviceScaleFactor": 1},
                     "locale": "en-US", "timezone": "UTC", "colorSpace": "srgb",
                     "guardsSha256": digest(GUARDS.encode()), "inspection": observation,
                     "sourceBytes": len(html), "sourceSha256": digest(html),
                     "captureBytes": len(png), "captureSha256": digest(png)}
            facts["loadedModules"] = modules
            cdp.call("Browser.close")
            process.wait(timeout=10)
            return png, facts
        finally:
            if cdp is not None:
                cdp.close()
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)


def repeat_capture(engine: Path, html: bytes, width: int, height: int, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    (output / "original.html").write_bytes(html)
    captures = []
    for index in range(2):
        png, facts = capture_once(engine, html, width, height)
        (output / f"capture-{index}.png").write_bytes(png)
        (output / f"capture-{index}.json").write_bytes(canonical(facts) + b"\n")
        captures.append(png)
    if captures[0] != captures[1]:
        raise ValueError("BYTE_EXACT repeat failed; both original captures retained")
    result = {"profile": PROFILE, "acceptanceMode": "BYTE_EXACT", "captureClass": "still",
              "sourceSha256": digest(html), "captureSha256": digest(captures[0]),
              "independentProcessCount": 2, "recordAuthorityEstablished": False,
              "archiveCoverageEstablished": False}
    (output / "repeat.json").write_bytes(canonical(result) + b"\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--html", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    args = parser.parse_args()
    print(json.dumps(repeat_capture(args.engine, args.html.read_bytes(), args.width, args.height, args.output)))


if __name__ == "__main__":
    main()
