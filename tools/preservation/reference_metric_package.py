"""Additive exact-byte metric supplement and restored Windows replay.

V1 metric sources, Metric ABI and report domains are inputs, never rewritten.
Verification is offline and does not execute archives. Replay is a separate,
explicit operation for the closed retained launcher, not arbitrary commands.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import time
import zipfile

from tools.museum.chain_abi import Array, encode
from tools.museum.canonical import keccak256
from tools.preservation.reference_package import safe_name, _write_zip
from tools.preservation.reference_archive import inspect

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ("tools/museum/canonical.py", "tools/museum/chain_abi.py",
           "tools/preservation/reference_manifest.py", "tools/preservation/reference_metric.py")
SUPPORT = ("tools/__init__.py", "tools/museum/__init__.py", "tools/preservation/__init__.py",
           "tools/metadata/__init__.py", "tools/metadata/reference_render_profile.py",
           "tools/preservation/reference_package.py", "tools/preservation/reference_archive.py")
DISTRIBUTIONS = ("attrs", "jsonschema", "jsonschema-specifications", "pycryptodome",
                 "referencing", "rfc8785", "rpds-py", "typing-extensions")
SOURCE_ROOT = "metric/source"
ENTRYPOINT = SOURCE_ROOT + "/tools/preservation/reference_metric.py"
INTERPRETER = "metric/python/python.exe"
LAUNCHER = "metric/launch.py"
ARGV = ["-I", "-S", "-B", LAUNCHER]
INDEX = "metric/implementation.json"
PARAMETERS = "metric/parameters.json"
MAX_SUPPLEMENT = 524288
MAX_TRANSCRIPT = 65536
MAX_ARCHIVE = 1024 * 1024 * 1024
MAX_EXPANDED = 2 * 1024 * 1024 * 1024
FILE_ABI = ("string", "uint64", "bytes32")
RUNTIME_ABI = ("bytes32", "bytes32", "string", "string", "string", "string",
               Array("string", 4), Array(FILE_ABI, 2048))
SOURCE_ABI = ("string", "bytes")
REPLAY_ABI = ("bytes32", "bytes32", "bytes32", "bytes32", "bytes", "bytes", "uint64", "uint32")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True, allow_nan=False).encode()


def sha(raw):
    return "0x" + hashlib.sha256(raw).hexdigest()


def blob(value):
    if not isinstance(value, str) or not value.startswith("0x"):
        raise ValueError("hex bytes required")
    raw = bytes.fromhex(value[2:])
    if "0x" + raw.hex() != value:
        raise ValueError("noncanonical hex bytes")
    return raw


def read_json(raw):
    def pairs(rows):
        result = {}
        for key, value in rows:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    result = json.loads(raw, object_pairs_hook=pairs)
    if canonical(result) != raw:
        raise ValueError("noncanonical JSON")
    return result


def file_row(name, raw):
    return {"path": safe_name(name), "byteSize": len(raw), "sha256Digest": sha(raw)}


def runtime_value(runtime):
    return (runtime["environmentObjectHash"], runtime["environmentManifestHash"],
            runtime["entrypoint"], runtime["interpreter"], runtime["launcher"], runtime["sourceRoot"],
            runtime["argv"], [(r["path"], r["byteSize"], r["sha256Digest"]) for r in runtime["members"]])


def runtime_hash(runtime):
    return keccak256(encode(("bytes32", RUNTIME_ABI),
                           (keccak256(b"6529STREAM_METRIC_RUNTIME_V1"), runtime_value(runtime))))


def source_material(source_root=ROOT):
    from tools.preservation.reference_metric import PARAMETERS as original_parameters
    sources = [{"path": name, "content": "0x" + (source_root / name).read_bytes().hex()} for name in SOURCES]
    index = canonical({row["path"]: hashlib.sha256(blob(row["content"])).hexdigest() for row in sources})
    parameters = canonical(original_parameters)
    return {"implementationIndex": "0x" + index.hex(), "parameters": "0x" + parameters.hex(), "sources": sources}


def _put(root, name, raw):
    target = root / safe_name(name)
    if not target.resolve().is_relative_to(root.resolve()):
        raise ValueError("package destination escape")
    if target.exists():
        raise ValueError("refusing to overwrite package member: " + name)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)


def _files(root):
    paths, seen = [], set()
    for path in root.rglob("*"):
        if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
            raise ValueError("linked package input")
        if path.is_file():
            name = safe_name(path.relative_to(root).as_posix())
            if name.casefold() in seen:
                raise ValueError("case-insensitive package alias")
            seen.add(name.casefold())
            paths.append((name, path))
    return sorted(paths)


def stage(environment_tree: Path, python_root: Path, distribution_root: Path, source_root=ROOT):
    """Add the complete closed metric runtime to a task-owned environment tree.

    The runtime is copied from explicit local paths. No install, registry search,
    wheel resolution, download, or mutation of the installed interpreter occurs.
    """
    environment_tree = environment_tree.resolve(strict=True)
    python_root = python_root.resolve(strict=True)
    distribution_root = distribution_root.resolve(strict=True)
    if (environment_tree / "metric").exists():
        raise ValueError("metric subtree already exists")
    material = source_material(source_root)
    for name in SOURCES + SUPPORT:
        _put(environment_tree, SOURCE_ROOT + "/" + name, (source_root / name).read_bytes())
    _put(environment_tree, INDEX, blob(material["implementationIndex"]))
    _put(environment_tree, PARAMETERS, blob(material["parameters"]))
    _put(environment_tree, LAUNCHER, Path(__file__).with_name("metric_runtime_launcher.py").read_bytes())
    dlls = sorted(python_root.glob("python3[0-9]*.dll"))
    if len(dlls) != 1 or not (python_root / "python.exe").is_file():
        raise ValueError("one actual Windows CPython runtime required")
    stem = dlls[0].stem
    # Zip every standard-library source/data file, excluding third-party site packages,
    # caches and test suites. Native extension modules are kept as separate PE files.
    stdlib = []
    for name, path in _files(python_root / "Lib"):
        parts = name.split("/")
        if parts[0] == "site-packages" or "__pycache__" in parts or "test" in parts or "tests" in parts or path.suffix in (".pyc", ".pyo"):
            continue
        stdlib.append((name, path.read_bytes()))
    target = environment_tree / "metric/python"
    target.mkdir(parents=True, exist_ok=True)
    _write_zip(target / (stem + ".zip"), stdlib)
    for path in sorted(python_root.iterdir()):
        if path.is_file() and (path.suffix.lower() == ".dll" or path.name in ("python.exe", "LICENSE.txt", "LICENSE_PYTHON.txt")):
            _put(environment_tree, "metric/python/" + path.name, path.read_bytes())
    for name, path in _files(python_root / "DLLs"):
        if path.suffix.lower() in (".pyd", ".dll"):
            _put(environment_tree, "metric/python/DLLs/" + name, path.read_bytes())
    # Conda's extensions need their adjacent native dependencies. Keep this whole
    # explicit DLL set rather than guessing which future input reaches an import.
    native_dir = python_root / "Library/bin"
    if native_dir.is_dir():
        for path in sorted(native_dir.glob("*.dll")):
            name = "metric/python/" + path.name
            prior = environment_tree / name
            if prior.exists():
                if prior.read_bytes() != path.read_bytes():
                    raise ValueError("conflicting native dependency: " + path.name)
            else:
                _put(environment_tree, name, path.read_bytes())
    _put(environment_tree, "metric/python/" + stem + "._pth",
         (stem + ".zip\nDLLs\n.\n").encode("ascii"))
    installed = {d.metadata["Name"].lower().replace("_", "-"): d
                 for d in importlib.metadata.distributions(path=[str(distribution_root)])}
    distributions = []
    for name in DISTRIBUTIONS:
        if name not in installed:
            raise ValueError("missing exact metric distribution: " + name)
        distribution = installed[name]
        distributions.append({"name": name, "version": distribution.version})
        for entry in distribution.files or []:
            relative = entry.as_posix()
            if "__pycache__" in relative.split("/") or relative.endswith((".pyc", ".pyo")):
                continue
            if relative.startswith("../"):
                continue  # console-script wrappers are not used by this closed launch recipe
            relative = safe_name(relative)
            original = Path(distribution.locate_file(entry)).resolve(strict=True)
            if not original.is_relative_to(distribution_root):
                raise ValueError("distribution source escape")
            _put(environment_tree, "metric/vendor/" + relative, original.read_bytes())
    _put(environment_tree, "metric/distributions.json", canonical(distributions))
    return material


def pack(environment_tree: Path, archive: Path):
    """Whole original environment plus the metric subtree; exact, sorted member bytes."""
    if archive.exists() or archive.resolve().is_relative_to(environment_tree.resolve()):
        raise ValueError("fresh external archive path required")
    files = [(name, path.read_bytes()) for name, path in _files(environment_tree)]
    if not files or not any(name.startswith("metric/") for name, _ in files):
        raise ValueError("metric runtime missing")
    _write_zip(archive, files)
    return [file_row(name, raw) for name, raw in files]


def bind(material, environment: dict, environment_bytes: bytes, metric):
    """Bind already packaged metric bytes to the selected original publication environment."""
    runtime = {"environmentObjectHash": environment["objectHash"],
               "environmentManifestHash": keccak256(environment_bytes),
               "entrypoint": ENTRYPOINT, "interpreter": INTERPRETER, "launcher": LAUNCHER,
               "sourceRoot": SOURCE_ROOT, "argv": list(ARGV),
               "members": [r for r in environment["packageFiles"] if r["path"].startswith("metric/")]}
    result = {**material, "runtime": runtime}
    verify_declaration(result, environment, environment_bytes, metric)
    return result


def verify_declaration(supplement, environment, environment_bytes, metric):
    """No execution. Anchored Metric and publication environment are caller-supplied inputs."""
    if set(supplement) not in ({"implementationIndex", "parameters", "sources", "runtime"},
                               {"implementationIndex", "parameters", "sources", "runtime", "replay"}):
        raise ValueError("closed metric supplement")
    if len(metric) != 7 or len(supplement["sources"]) != 4:
        raise ValueError("original metric/source shape")
    sources = supplement["sources"]
    if [r["path"] for r in sources] != list(SOURCES) or any(set(r) != {"path", "content"} for r in sources):
        raise ValueError("complete ordered original source index")
    index = canonical({r["path"]: hashlib.sha256(blob(r["content"])).hexdigest() for r in sources})
    parameters = blob(supplement["parameters"])
    read_json(parameters)
    if not 0 < len(parameters) <= 65536 or any(not 0 < len(blob(r["content"])) <= 131072 for r in sources):
        raise ValueError("source/parameter byte bound")
    if index != blob(supplement["implementationIndex"]) or keccak256(index) != metric[4] or keccak256(parameters) != metric[5]:
        raise ValueError("metric hash preimage mismatch")
    runtime = supplement["runtime"]
    # This is the original Environment JSON's decimal-string representation,
    # not a second caller-provided list allowed to disagree with the hashed bytes.
    parsed_environment = json.loads(environment_bytes)
    native_canonical = json.dumps(parsed_environment, sort_keys=True, separators=(",", ":"),
                                  ensure_ascii=False, allow_nan=False).encode("utf8")
    def declared(rows):
        return [{**row, "byteSize": str(row["byteSize"])} for row in rows]
    if native_canonical != environment_bytes or parsed_environment.get("runtimeObjectHash") != environment["objectHash"] or parsed_environment.get("packageFiles") != declared(environment["packageFiles"]) or parsed_environment.get("platformPrerequisites") != declared(environment["platformPrerequisites"]):
        raise ValueError("original hashed environment/member declaration differs")
    if set(runtime) != {"environmentObjectHash", "environmentManifestHash", "entrypoint", "interpreter", "launcher", "sourceRoot", "argv", "members"}:
        raise ValueError("closed runtime declaration")
    if (runtime["entrypoint"], runtime["interpreter"], runtime["launcher"], runtime["sourceRoot"], runtime["argv"]) != (ENTRYPOINT, INTERPRETER, LAUNCHER, SOURCE_ROOT, ARGV):
        raise ValueError("closed isolated launch recipe")
    if runtime["environmentObjectHash"] != environment["objectHash"] or runtime["environmentManifestHash"] != keccak256(environment_bytes) or environment["manifestHash"] != runtime["environmentManifestHash"]:
        raise ValueError("same publication environment required")
    expected = [r for r in environment["packageFiles"] if r["path"].startswith("metric/")]
    if runtime["members"] != expected or not 1 <= len(expected) <= 2048:
        raise ValueError("complete same-package metric inventory")
    mapping = _rows(environment["packageFiles"])
    required = {INDEX: index, PARAMETERS: parameters,
                LAUNCHER: Path(__file__).with_name("metric_runtime_launcher.py").read_bytes()}
    required.update({SOURCE_ROOT + "/" + r["path"]: blob(r["content"]) for r in sources})
    for name, raw in required.items():
        if mapping.get(name) != file_row(name, raw):
            raise ValueError("required metric bytes missing or substituted: " + name)
    for name in (INTERPRETER, "metric/distributions.json") + tuple(SOURCE_ROOT + "/" + n for n in SUPPORT):
        if name not in mapping:
            raise ValueError("required runtime member missing: " + name)
    if not any(n.startswith("metric/python/python3") and n.endswith("._pth") for n in mapping):
        raise ValueError("isolated interpreter path policy missing")
    return runtime_hash(runtime)


def _rows(rows):
    mapping, last, folded = {}, "", set()
    for row in rows:
        if set(row) != {"path", "byteSize", "sha256Digest"}:
            raise ValueError("closed package row")
        name = safe_name(row["path"])
        if name <= last or name.casefold() in folded or type(row["byteSize"]) is not int or not 0 <= row["byteSize"] < 2**64 or len(blob(row["sha256Digest"])) != 32:
            raise ValueError("canonical complete package rows")
        mapping[name] = row
        last = name
        folded.add(name.casefold())
    return mapping


def verify_archive(archive: Path, environment, coverage, destination=None):
    """Verify every original byte, exact ZIP inventory and all three whole-object digests."""
    if archive.stat().st_size > MAX_ARCHIVE:
        raise ValueError("archive byte bound")
    observed = inspect(archive)
    if environment["objectHash"] != coverage["objectHash"] or environment["coverageHash"] != coverage["coverageHash"]:
        raise ValueError("environment coverage identity")
    for actual, expected in (("sha256", "sha256Digest"), ("keccak256", "contentHash"), ("arweaveDataRoot", "arweaveDataRoot")):
        if "0x" + observed[actual] != coverage[expected]:
            raise ValueError("whole archive " + actual)
    if observed["byteSize"] != coverage["byteSize"]:
        raise ValueError("whole archive size")
    mapping = _rows(environment["packageFiles"])
    with zipfile.ZipFile(archive) as saved:
        entries = saved.infolist()
        if [e.filename for e in entries] != list(mapping) or sum(e.file_size for e in entries) > MAX_EXPANDED:
            raise ValueError("complete bounded archive inventory")
        for entry in entries:
            if entry.is_dir() or stat.S_ISLNK(entry.external_attr >> 16) or entry.flag_bits & 1:
                raise ValueError("unsupported archive member")
            raw = saved.read(entry)
            if file_row(entry.filename, raw) != mapping[entry.filename]:
                raise ValueError("archive member bytes differ")
            if destination is not None:
                _put(destination, entry.filename, raw)
    return observed


def verify_replay_receipt(supplement, environment, environment_bytes, metric, inputs, expected_report_hash):
    """Check retained execution claims, not whether anyone actually ran the program."""
    from tools.preservation.reference_metric import report_preimage, METRIC_ABI
    bound = verify_declaration(supplement, environment, environment_bytes, metric)
    receipt = supplement["replay"]
    if set(receipt) != {"runtimeHash", "contextHash", "reportHash", "inputsHash", "inputManifest", "transcript", "executedAt", "exitCode"}:
        raise ValueError("closed replay receipt")
    encoded_inputs = canonical(inputs)
    if receipt["runtimeHash"] != bound or receipt["contextHash"] != inputs["contextHash"] or receipt["reportHash"] != expected_report_hash or receipt["inputsHash"] != keccak256(encoded_inputs) or blob(receipt["inputManifest"]) != encoded_inputs:
        raise ValueError("replay receipt identity differs")
    if type(receipt["exitCode"]) is not int or receipt["exitCode"] != 0 or type(receipt["executedAt"]) is not int or not inputs["evaluatedAt"] <= receipt["executedAt"] < 2**64:
        raise ValueError("successful replay time/status required")
    raw = blob(receipt["transcript"])
    if not 0 < len(raw) <= MAX_TRANSCRIPT:
        raise ValueError("retained replay transcript bound")
    transcript = read_json(raw)
    if set(transcript) != {"runtimeHash", "contextHash", "reportHash", "inputsHash", "executedAt", "exitCode", "result"} or any(transcript[key] != receipt[key] for key in transcript if key != "result"):
        raise ValueError("transcript/receipt association differs")
    result = transcript["result"]
    report = result["report"]
    preimage = report_preimage(inputs["contextHash"], metric, inputs["threshold"], report["scores"], inputs["evaluatedAt"])
    if result["profile"] != "STREAM_METRIC_RESTORED_REPLAY_V1" or result["disabledFallbackProbes"] != ["network", "process"] or report["metric"] != list(metric) or report["inputs"] != inputs or report["reportHash"] != expected_report_hash or keccak256(preimage) != expected_report_hash or blob(report["reportPreimageABI"]) != preimage or blob(report["metricDocumentABI"]) != encode((METRIC_ABI,), (metric,)) or canonical(report["parameters"]) != blob(supplement["parameters"]):
        raise ValueError("transcript original metric/report differs")
    if len(report["scores"]) != len(inputs["captures"]) or any(type(score) is not int or not -1000000000 <= score <= 1000000000 for score in report["scores"]):
        raise ValueError("transcript score profile")
    outcomes = ["MATCH" if row["firstSha256"] == row["secondSha256"] else
                "TOLERABLE_VARIANCE" if score >= inputs["threshold"] else "DIVERGENT"
                for row, score in zip(inputs["captures"], report["scores"])]
    if report["outcomes"] != outcomes or report["publishableThreshold"] is not all(score >= inputs["threshold"] for score in report["scores"]):
        raise ValueError("transcript classification differs")
    members = _rows(supplement["runtime"]["members"])
    if not result["pythonModules"] or not result["nativeMembers"]:
        raise ValueError("runtime import observation missing")
    for row in result["pythonModules"]:
        name = safe_name(row["path"])
        if set(row) != {"name", "path", "origin"} or row["origin"] not in ("file", "frozen"):
            raise ValueError("Python module origin declaration")
        if row["origin"] == "frozen" and (not name.startswith("metric/python/python3") or not name.endswith(".dll") or name not in result["nativeMembers"]):
            raise ValueError("frozen module interpreter image")
        if name not in members and not any(name.startswith(path + "/") for path in members if path.endswith(".zip")):
            raise ValueError("transcript Python module outside package: " + name)
    if any(name not in members for name in result["nativeMembers"]):
        raise ValueError("transcript native module outside package")
    platform = {r["path"].casefold(): r for r in environment["platformPrerequisites"]}
    for row in result["platformPrerequisites"]:
        expected = platform.get(row["path"].casefold())
        if expected is None or (row["byteSize"], row["sha256Digest"]) != (expected["byteSize"], expected["sha256Digest"]):
            raise ValueError("transcript unrecorded OS prerequisite")
    replay_value = (receipt["runtimeHash"], receipt["contextHash"], receipt["reportHash"],
                    receipt["inputsHash"], encoded_inputs, raw, receipt["executedAt"], receipt["exitCode"])
    return keccak256(encode(("bytes32", REPLAY_ABI),
                           (keccak256(b"6529STREAM_METRIC_REPLAY_V1"), replay_value)))


def chunk_payload(payload: bytes, output: Path):
    """Exact existing Store.publishChunk(bytes) calls; no transaction is sent."""
    if not 0 < len(payload) <= MAX_SUPPLEMENT:
        raise ValueError("supplement payload byte bound")
    if output.exists():
        raise ValueError("fresh chunk output required")
    output.mkdir(parents=True)
    chunks = []
    selector = blob(keccak256(b"publishChunk(bytes)"))[:4]
    for offset in range(0, len(payload), 8192):
        raw = payload[offset:offset + 8192]
        name = f"chunk-{len(chunks):04d}.bin"
        (output / name).write_bytes(raw)
        chunks.append({"index": len(chunks), "offset": offset, "path": name,
                       "byteSize": len(raw), "chunkHash": keccak256(raw),
                       "value": "0", "data": "0x" + (selector + encode(("bytes",), (raw,))).hex()})
    result = {"payloadHash": keccak256(payload), "payloadBytes": len(payload), "chunkBytes": 8192,
              "chunks": chunks,
              "qualification": "CALL each zero-value publishChunk(bytes) at the original pinned SchemaDocumentStore; upload confers no publication authority."}
    (output / "chunks.json").write_bytes(canonical(result))
    return result


def replay(supplement, environment, environment_bytes, metric, archive, coverage, inputs, pairs,
           output: Path, expected_report_hash, timeout=120):
    """Explicit actual replay; never substitutes locally installed metric/runtime bytes."""
    if os.name != "nt":
        raise ValueError("this replay profile requires Windows")
    if output.exists():
        raise ValueError("fresh replay output required")
    bound = verify_declaration(supplement, environment, environment_bytes, metric)
    inputs_bytes = canonical(inputs)
    if len(inputs_bytes) > 65536 or inputs["environmentHash"] != keccak256(environment_bytes):
        raise ValueError("input/environment bound")
    job = {"runtime": supplement["runtime"], "parameters": supplement["parameters"],
           "implementationIndex": supplement["implementationIndex"], "manifest": inputs,
           "environment": "0x" + environment_bytes.hex(),
           "pairs": [["0x" + a.hex(), "0x" + b.hex()] for a, b in pairs]}
    with tempfile.TemporaryDirectory(prefix="stream-metric-replay-") as temporary:
        scratch = Path(temporary)
        restored = scratch / "environment"
        restored.mkdir()
        verify_archive(archive, environment, coverage, restored)
        job_path = scratch / "job.json"
        job_path.write_bytes(canonical(job))
        child_env = {"SystemRoot": os.environ["SystemRoot"], "WINDIR": os.environ["SystemRoot"],
                     "PATH": str(restored / "metric/python"), "TEMP": str(scratch), "TMP": str(scratch)}
        completed = subprocess.run([str(restored / INTERPRETER), *ARGV, str(job_path)],
                                   cwd=restored, env=child_env, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
        if completed.returncode != 0:
            raise ValueError("restored metric failed: " + completed.stderr.decode("utf8", "replace")[-4000:])
        result = read_json(completed.stdout.rstrip(b"\n"))
        if result["report"]["metric"] != list(metric) or result["report"]["reportHash"] != expected_report_hash or result["report"]["inputs"] != inputs:
            raise ValueError("original report/metric/input differs after replay")
        # Verify that the supposedly read-only execution changed no restored member.
        for name, row in _rows(environment["packageFiles"]).items():
            if file_row(name, (restored / name).read_bytes()) != row:
                raise ValueError("runtime modified retained bytes")
        prerequisites = {r["path"].casefold(): r for r in environment["platformPrerequisites"]}
        platform = []
        for path in result.pop("platformPaths"):
            raw = Path(path).read_bytes()
            row = {"path": path, "byteSize": len(raw), "sha256Digest": sha(raw)}
            expected = prerequisites.get(path.casefold())
            if expected is None or (row["byteSize"], row["sha256Digest"]) != (expected["byteSize"], expected["sha256Digest"]):
                raise ValueError("unrecorded/different OS prerequisite: " + path)
            platform.append(row)
        result["platformPrerequisites"] = platform
    executed = int(time.time())
    transcript = canonical({"runtimeHash": bound, "contextHash": inputs["contextHash"],
                            "reportHash": expected_report_hash, "inputsHash": keccak256(inputs_bytes),
                            "executedAt": executed, "exitCode": 0, "result": result})
    if len(transcript) > MAX_TRANSCRIPT:
        raise ValueError("retained replay transcript bound")
    receipt = {"runtimeHash": bound, "contextHash": inputs["contextHash"], "reportHash": expected_report_hash,
               "inputsHash": keccak256(inputs_bytes), "inputManifest": "0x" + inputs_bytes.hex(),
               "transcript": "0x" + transcript.hex(), "executedAt": executed, "exitCode": 0}
    final = {**supplement, "replay": receipt}
    verify_replay_receipt(final, environment, environment_bytes, metric, inputs, expected_report_hash)
    # The fixed [4] tuple is encoded explicitly; the generic Array helper represents dynamic arrays.
    source_values = tuple((r["path"], blob(r["content"])) for r in final["sources"])
    abi = encode((("bytes", "bytes", (SOURCE_ABI,) * 4, RUNTIME_ABI, REPLAY_ABI),),
                 ((blob(final["implementationIndex"]), blob(final["parameters"]), source_values,
                   runtime_value(final["runtime"]), (bound, inputs["contextHash"], expected_report_hash,
                   receipt["inputsHash"], inputs_bytes, transcript, executed, 0)),))
    if len(abi) > MAX_SUPPLEMENT:
        raise ValueError("supplement ABI byte bound")
    output.mkdir(parents=True)
    (output / "supplement.json").write_bytes(canonical(final))
    (output / "supplement.abi").write_bytes(abi)
    (output / "transcript.json").write_bytes(transcript)
    chunk_payload(abi, output / "chunks")
    return final


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    stage_parser = commands.add_parser("stage")
    stage_parser.add_argument("--environment-tree", type=Path, required=True)
    stage_parser.add_argument("--python-root", type=Path, required=True)
    stage_parser.add_argument("--distribution-root", type=Path, required=True)
    stage_parser.add_argument("--material", type=Path, required=True)
    pack_parser = commands.add_parser("pack")
    pack_parser.add_argument("--environment-tree", type=Path, required=True)
    pack_parser.add_argument("--archive", type=Path, required=True)
    pack_parser.add_argument("--inventory", type=Path, required=True)
    bind_parser = commands.add_parser("bind")
    bind_parser.add_argument("--context", type=Path, required=True)
    bind_parser.add_argument("--material", type=Path, required=True)
    bind_parser.add_argument("--output", type=Path, required=True)
    chunks_parser = commands.add_parser("chunks")
    chunks_parser.add_argument("--payload", type=Path, required=True)
    chunks_parser.add_argument("--output", type=Path, required=True)
    for name in ("verify", "replay"):
        command = commands.add_parser(name)
        command.add_argument("--context", type=Path, required=True)
        command.add_argument("--supplement", type=Path, required=True)
        command.add_argument("--archive", type=Path, required=True)
        if name == "replay":
            command.add_argument("--pair", nargs=2, action="append", type=Path, required=True)
            command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "stage":
        result = stage(args.environment_tree, args.python_root, args.distribution_root)
        with args.material.open("xb") as handle:
            handle.write(canonical(result))
    elif args.command == "pack":
        result = pack(args.environment_tree, args.archive)
        with args.inventory.open("xb") as handle:
            handle.write(canonical(result))
    elif args.command == "chunks":
        chunk_payload(args.payload.read_bytes(), args.output)
    else:
        context = read_json(args.context.read_bytes())
        environment = context["environment"]
        environment_bytes = blob(context["environmentBytes"])
        if args.command == "bind":
            result = bind(read_json(args.material.read_bytes()), environment, environment_bytes, context["metric"])
            with args.output.open("xb") as handle:
                handle.write(canonical(result))
        else:
            supplement = read_json(args.supplement.read_bytes())
            verify_declaration(supplement, environment, environment_bytes, context["metric"])
            if args.command == "verify":
                verify_archive(args.archive, environment, context["coverage"])
                if "replay" in supplement:
                    verify_replay_receipt(supplement, environment, environment_bytes, context["metric"],
                                          context["inputs"], context["expectedReportHash"])
                print("Exact bytes and any supplied replay receipt verified; execution not performed.")
            else:
                replay(supplement, environment, environment_bytes, context["metric"], args.archive,
                       context["coverage"], context["inputs"],
                       [(a.read_bytes(), b.read_bytes()) for a, b in args.pair],
                       args.output, context["expectedReportHash"])


if __name__ == "__main__":
    main()
