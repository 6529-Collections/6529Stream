"""Retained, closed Windows metric replay entrypoint; invoke with Python -I -S -B.

This is an isolation recipe for the pinned metric, not a sandbox for arbitrary
hostile native code. The parent verifies every archive member before launching.
No source is fetched, installed, normalized or rewritten by this program.
"""
import sys
import os
import json
import hashlib
from pathlib import Path


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def main():
    if os.name != "nt" or not sys.flags.isolated or not sys.flags.no_site or not sys.dont_write_bytecode:
        raise ValueError("isolated Windows interpreter required")
    root = Path(__file__).resolve().parent.parent
    job_path = Path(sys.argv[1]).resolve(strict=True)
    job = json.loads(job_path.read_bytes())
    if set(job) != {"runtime", "parameters", "implementationIndex", "manifest", "environment", "pairs"}:
        raise ValueError("closed replay job")
    runtime = job["runtime"]
    paths = {r["path"]: r for r in runtime["members"]}
    for name, row in paths.items():
        path = root / name
        if not path.resolve(strict=True).is_relative_to(root) or path.is_symlink():
            raise ValueError("member escapes package")
        raw = path.read_bytes()
        if len(raw) != row["byteSize"] or "0x" + hashlib.sha256(raw).hexdigest() != row["sha256Digest"]:
            raise ValueError("restored member bytes differ")
    if Path(sys.executable).resolve() != (root / runtime["interpreter"]).resolve():
        raise ValueError("interpreter differs")
    python = root / "metric/python"
    # Replace, never append, startup paths. No cwd, user site or host site survives.
    version = f"python{sys.version_info.major}{sys.version_info.minor}.zip"
    sys.path[:] = [str(python / version), str(python / "DLLs"), str(python),
                   str(root / "metric/vendor"), str(root / runtime["sourceRoot"])]
    if "site" in sys.modules or any(not Path(p).is_relative_to(root) for p in sys.path):
        raise ValueError("external Python path")
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    if not kernel.SetDefaultDllDirectories(0x1000 | 0x800):
        raise ctypes.WinError(ctypes.get_last_error())
    # Keep handles alive for the entire replay. The package has no writable search root.
    dll_handles = [os.add_dll_directory(str(python)), os.add_dll_directory(str(python / "DLLs"))]
    system = Path(os.environ["SystemRoot"]).resolve()
    allowed_roots = (root, system)

    def audit(event, args):
        if event.startswith("socket.") or event in {
            "subprocess.Popen", "os.system", "os.startfile", "os.startfile/2",
            "os.exec", "os.spawn", "os.posix_spawn", "urllib.Request",
        }:
            raise PermissionError("network/process fallback is disabled")
        if event == "ctypes.dlopen":
            name = args[0]
            if name is None:
                raise PermissionError("unbound native load")
            path = Path(name)
            if path.is_absolute() and not any(path.resolve().is_relative_to(r) for r in allowed_roots):
                raise PermissionError("external native load")
        if event == "open":
            path, mode, flags = args
            if isinstance(path, (str, bytes)):
                path = Path(os.fsdecode(path)).resolve()
                # Input job is external to the immutable archive. All other reads are package-only.
                if path != job_path and not path.is_relative_to(root):
                    raise PermissionError("external file fallback is disabled")
                if (isinstance(mode, str) and any(c in mode for c in "wax+")) or flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT):
                    raise PermissionError("replay writes are disabled")

    sys.addaudithook(audit)
    # These imports are intentionally from the original unchanged source tree.
    from tools.preservation import reference_metric as metric
    from tools.museum.canonical import keccak256
    parameters = bytes.fromhex(job["parameters"][2:])
    index = bytes.fromhex(job["implementationIndex"][2:])
    if parameters != metric.canonical(metric.PARAMETERS):
        raise ValueError("archived parameters differ from original executable")
    if metric.implementation_hash() != keccak256(index):
        raise ValueError("archived implementation differs")
    pairs = [(bytes.fromhex(a[2:]), bytes.fromhex(b[2:])) for a, b in job["pairs"]]
    result = metric.measure(job["manifest"], bytes.fromhex(job["environment"][2:]), pairs)
    # Observe the complete import/native footprint of the negative probes too.
    import socket
    import subprocess
    probes = []
    for name, callback in (("network", lambda: socket.socket()),
                           ("process", lambda: subprocess.Popen([sys.executable, "-V"]))):
        try:
            callback()
        except PermissionError:
            probes.append(name)
        else:
            raise ValueError("fallback isolation probe unexpectedly succeeded")
    modules = []
    for name, module in sorted(sys.modules.items()):
        filename = getattr(module, "__file__", None)
        if filename:
            path = Path(filename).resolve()
            if not path.is_relative_to(root):
                raise ValueError("loaded Python module outside restored package: " + name)
            frozen = getattr(getattr(module, "__spec__", None), "origin", None) == "frozen"
            if frozen:
                # CPython's frozen modules expose logical Lib/*.py filenames even
                # when execution came from the immutable interpreter DLL image.
                path = python / version.replace(".zip", ".dll")
                if path.relative_to(root).as_posix() not in paths:
                    raise ValueError("frozen module interpreter image missing")
            modules.append({"name": name, "path": path.relative_to(root).as_posix(),
                            "origin": "frozen" if frozen else "file"})
    # Enumerate actual loaded PE images, including transitive DLL dependencies.
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    handles = (wintypes.HMODULE * 2048)()
    needed = wintypes.DWORD()
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    psapi.EnumProcessModules.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.HMODULE),
                                        wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    psapi.GetModuleFileNameExW.argtypes = [wintypes.HANDLE, wintypes.HMODULE,
                                         wintypes.LPWSTR, wintypes.DWORD]
    process = kernel.GetCurrentProcess()
    if not psapi.EnumProcessModules(process, handles, ctypes.sizeof(handles), ctypes.byref(needed)):
        raise ctypes.WinError(ctypes.get_last_error())
    if needed.value > ctypes.sizeof(handles):
        raise ValueError("native module bound")
    native, platform = [], []
    for handle in handles[:needed.value // ctypes.sizeof(wintypes.HMODULE)]:
        buffer = ctypes.create_unicode_buffer(32768)
        if not psapi.GetModuleFileNameExW(process, handle, buffer, len(buffer)):
            raise ctypes.WinError(ctypes.get_last_error())
        path = Path(buffer.value).resolve()
        if path.is_relative_to(root):
            name = path.relative_to(root).as_posix()
            if name not in paths:
                raise ValueError("unlisted loaded package binary")
            native.append(name)
        elif path.is_relative_to(system):
            # System files are an explicitly external prerequisite, never a packaged-runtime claim.
            platform.append(str(path))
        else:
            raise ValueError("loaded native image outside archive/declared OS: " + str(path))
    output = {"profile": "STREAM_METRIC_RESTORED_REPLAY_V1", "report": result,
              "pythonVersion": sys.version, "pythonModules": modules,
              "nativeMembers": sorted(set(native)), "platformPaths": sorted(set(platform)),
              "disabledFallbackProbes": probes,
              "qualification": "Local restored execution of pinned bytes; not chain, browser, attestor or institutional authority."}
    sys.stdout.buffer.write(canonical(output) + b"\n")


if __name__ == "__main__":
    main()
