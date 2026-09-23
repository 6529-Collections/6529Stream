"""Separate named prospective capture; never supplies token or chain authority.

Uses the unchanged native still runtime restrictions and two fresh sandboxed
processes. The source export must be authenticated against currentSource and
simulationHTML separately; this CLI does not turn a local JSON file into chain evidence.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import platform
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from Crypto.Hash import keccak
from .reference_capture import FLAGS, GUARDS, INSPECT, CDP, loaded_modules, check_inspection, canonical, digest

PROFILE = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"
SIMULATION = "6529STREAM_PROSPECTIVE_NAMED_SIMULATION_V1"
HTML_PREFIX = '<!doctype html><html data-stream-render-state="prospective"><head><meta charset="utf-8">'

def kh(raw: bytes) -> bytes:
    return keccak.new(digest_bits=256, data=raw).digest()

def hx(value: str, size: int | None = None) -> bytes:
    if not isinstance(value, str) or not re.fullmatch(r"0x(?:[0-9a-f]{2})*", value):
        raise ValueError("canonical lowercase hex required")
    raw = bytes.fromhex(value[2:])
    if size is not None and len(raw) != size:
        raise ValueError("hex width")
    return raw

def word(value: int, bits=256) -> bytes:
    if type(value) is not int or not 0 <= value < 2**bits:
        raise ValueError("integer width")
    return value.to_bytes(32, "big")

def dynamic(raw: bytes) -> bytes:
    return word(len(raw)) + raw + bytes((-len(raw)) % 32)

def vector_hash(vector: dict) -> bytes:
    if set(vector) != {"name", "seed", "input"} or not isinstance(vector["name"], str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", vector["name"]):
        raise ValueError("closed named vector")
    name = vector["name"].encode("ascii"); seed = hx(vector["seed"], 32); data = hx(vector["input"])
    if len(data) > 4096:
        raise ValueError("input bound")
    # Literal abi.encode(PROFILE, Vector(string,bytes32,bytes)), independent of Solidity helpers.
    name_tail = dynamic(name)
    value = word(96) + seed + word(96 + len(name_tail)) + name_tail + dynamic(data)
    return kh(kh(SIMULATION.encode()) + word(64) + value)

def simulation_html(context: dict) -> bytes:
    if set(context) != {"chainId", "core", "collectionId", "sourceHash", "vector", "scriptHex"}:
        raise ValueError("closed prospective source export")
    chain = context["chainId"]; cid = context["collectionId"]
    word(chain); word(cid)
    if chain == 0 or cid == 0 or hx(context["core"], 20) == bytes(20) or hx(context["sourceHash"], 32) == bytes(32):
        raise ValueError("source identity")
    script = hx(context["scriptHex"])
    if not 1 <= len(script) <= 24576:
        raise ValueError("script bound")
    script.decode("utf-8", errors="strict")
    script = re.sub(b"</script", lambda match: b"<\\/" + match[0][2:], script, flags=re.IGNORECASE)
    vector = context["vector"]; vh = vector_hash(vector)
    html = (HTML_PREFIX + '<meta name="viewport" content="width=device-width,initial-scale=1"></head><body><script>'
        + 'const STREAM_PROSPECTIVE={profile:"0x' + kh(SIMULATION.encode()).hex()
        + '",chainId:"' + str(chain) + '",core:"' + context["core"] + '",collectionId:"' + str(cid)
        + '",sourceHash:"' + context["sourceHash"] + '",vectorHash:"0x' + vh.hex()
        + '",name:"' + vector["name"] + '",seed:"' + vector["seed"] + '",inputBase64:"'
        + base64.b64encode(hx(vector["input"])).decode("ascii")
        + '"};Object.freeze(STREAM_PROSPECTIVE);</script><script>').encode() + script + b'</script></body></html>'
    if len(html) > 40960:
        raise ValueError("HTML bound")
    return html

def capture_once(engine: Path, html: bytes, width: int, height: int) -> tuple[bytes, dict]:
    if not (type(width) is int and type(height) is int and 1 <= width <= 4096 and 1 <= height <= 4096):
        raise ValueError("viewport outside this capture profile")
    source = html.decode("utf-8", errors="strict")
    if not source.startswith(HTML_PREFIX) or not source.endswith("</script></body></html>"):
        raise ValueError("expected exact prospective simulation wrapper")
    if len(html) > 40960:
        raise ValueError("HTML exceeds prospective serving bound")
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

def repeat_capture(engine: Path, context: dict, width: int, height: int, output: Path) -> dict:
    html = simulation_html(context)
    output.mkdir(parents=True, exist_ok=False)
    (output / "context.json").write_bytes(canonical(context))
    (output / "original.html").write_bytes(html)
    values = []
    for index in range(2):
        png, facts = capture_once(engine, html, width, height)
        (output / f"capture-{index}.png").write_bytes(png)
        (output / f"capture-{index}.json").write_bytes(canonical(facts))
        values.append(png)
    if values[0] != values[1]:
        raise ValueError("BYTE_EXACT failed; originals retained")
    result = {"simulationProfile": SIMULATION, "captureProfile": PROFILE, "sourceHash": context["sourceHash"],
        "vectorHash": "0x" + vector_hash(context["vector"]).hex(), "htmlSha256": digest(html),
        "pngSha256": [digest(x) for x in values], "observedAt": int(time.time()), "exitCode": 0,
        "independentProcesses": 2, "onchainAuthorityEstablished": False, "archiveCoverageEstablished": False}
    (output / "repeat.json").write_bytes(canonical(result))
    return result

def execution(run: Path, environment_hash: str) -> bytes:
    context = json.loads((run / "context.json").read_text(encoding="utf-8"))
    result = json.loads((run / "repeat.json").read_text(encoding="utf-8"))
    html = simulation_html(context)
    if (run / "original.html").read_bytes() != html or result["sourceHash"] != context["sourceHash"] or result["vectorHash"] != "0x" + vector_hash(context["vector"]).hex():
        raise ValueError("source/vector mismatch")
    png = [(run / f"capture-{i}.png").read_bytes() for i in range(2)]
    if png[0] != png[1] or not png[0].startswith(b"\x89PNG\r\n\x1a\n") or [digest(x) for x in png] != result["pngSha256"] or digest(html) != result["htmlSha256"]:
        raise ValueError("original byte mismatch")
    if result["simulationProfile"] != SIMULATION or result["captureProfile"] != PROFILE or result["independentProcesses"] != 2 or result["exitCode"] != 0:
        raise ValueError("profile/status mismatch")
    for i in range(2):
        facts = json.loads((run / f"capture-{i}.json").read_text(encoding="utf-8"))
        if facts["profile"] != PROFILE or facts["sourceBytes"] != len(html) or facts["sourceSha256"] != digest(html) or facts["captureBytes"] != len(png[i]) or facts["captureSha256"] != digest(png[i]):
            raise ValueError("capture diagnostic mismatch")
    env = hx(environment_hash, 32)
    if env == bytes(32):
        raise ValueError("environment hash required after complete package assembly")
    # Nine entirely static ABI words, exactly P.Execution; no outer offset.
    return (kh(SIMULATION.encode()) + hx(context["sourceHash"], 32) + vector_hash(context["vector"])
        + env + hashlib.sha256(html).digest() + hashlib.sha256(png[0]).digest() + hashlib.sha256(png[1]).digest()
        + word(result["observedAt"], 64) + word(0, 32))

def main():
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    capture = sub.add_parser("capture"); capture.add_argument("--engine", type=Path, required=True)
    capture.add_argument("--context", type=Path, required=True); capture.add_argument("--output", type=Path, required=True)
    capture.add_argument("--width", type=int, required=True); capture.add_argument("--height", type=int, required=True)
    final = sub.add_parser("execution"); final.add_argument("--run", type=Path, required=True)
    final.add_argument("--environment-hash", required=True); final.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "capture":
        print(json.dumps(repeat_capture(args.engine, json.loads(args.context.read_text(encoding="utf-8")), args.width, args.height, args.output)))
    else:
        raw = execution(args.run, args.environment_hash)
        with args.output.open("xb") as stream:
            stream.write(raw)
        print(json.dumps({"bytes": len(raw), "keccak256": "0x" + kh(raw).hex(), "onchainAuthorityEstablished": False}))

if __name__ == "__main__":
    main()
