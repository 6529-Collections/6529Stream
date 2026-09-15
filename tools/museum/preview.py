"""Deterministic, unrecorded fixture packages with source-first coverage.

No Linked Art representation or schema registration is fabricated. This is the
first offline export surface; recorded packages require the later source adapter.
"""

from hashlib import sha256
from pathlib import Path

from .canonical import MuseumError, dumps, loads
from .coverage import inventory, verify_coverage
from .dependencies import safe_path


def _sha(data):
    return "0x" + sha256(data).hexdigest()


def fixture_package(schema_bytes: bytes, source_bytes: bytes) -> dict[str, bytes]:
    schema = loads(schema_bytes, canonical=True)
    source = loads(source_bytes, canonical=True)
    if source.get("fixtureMode") != "synthetic_fixture":
        raise MuseumError("fixture exporter cannot promote nonfixture input")
    fields = inventory(schema, source)
    coverage = [{"pointer": f.pointer, "presence": f.presence, "exactHex": "0x" + f.exact.hex(),
                 "disposition": "retained_stream_only", "rule": "fixture-source-retention",
                 "reason": "Original field retained; target projection not evaluated"} for f in fields]
    verify_coverage(fields, coverage)
    components = {"source/payload.json": source_bytes, "source/schema.json": schema_bytes,
                  "reports/coverage.json": dumps(coverage)}
    components["manifest.json"] = dumps({
        "mode": "synthetic_fixture", "scenario": source["scenario"],
        "claims": {"recordedState": False, "schemaRegistration": False, "linkedArtModel": "not_evaluated",
                   "museumConformance": "not_evaluated", "institutionalIngest": "not_evaluated"},
        "components": [{"path": path, "sha256": _sha(data), "byteLength": str(len(data))}
                       for path, data in sorted(components.items())]})
    return components


def write_package(destination: Path, components: dict[str, bytes]):
    # Refuse stale/mixed output: no silently retained unmanifested components.
    if destination.exists() and any(destination.iterdir()):
        raise MuseumError("output directory must be empty")
    destination.mkdir(parents=True, exist_ok=True)
    for relative, content in components.items():
        path = safe_path(destination, relative)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)


def verify_fixture_package(root: Path):
    if (root / "manifest.json").stat().st_size > 24576:
        raise MuseumError("fixture manifest limit")
    manifest_bytes = (root / "manifest.json").read_bytes()
    manifest = loads(manifest_bytes, canonical=True)
    if manifest.get("mode") != "synthetic_fixture":
        raise MuseumError("not a fixture package")
    entries = manifest.get("components", [])
    if len(entries) != 3:
        raise MuseumError("fixture component count")
    data = {}
    for entry in entries:
        relative = entry["path"]
        if relative in data or relative == "manifest.json":
            raise MuseumError("duplicate/circular component")
        path = safe_path(root, relative)
        if path.stat().st_size > 24576:
            raise MuseumError("fixture component limit")
        content = path.read_bytes()
        if _sha(content) != entry["sha256"] or str(len(content)) != entry["byteLength"]:
            raise MuseumError("fixture component hash/length mismatch")
        data[relative] = content
    if set(data) != {"source/payload.json", "source/schema.json", "reports/coverage.json"}:
        raise MuseumError("fixture component set")
    actual_files = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()}
    if actual_files != set(data) | {"manifest.json"}:
        raise MuseumError("unmanifested package file")
    expected = fixture_package(data["source/schema.json"], data["source/payload.json"])
    if any(content != (root / path).read_bytes() for path, content in expected.items()):
        raise MuseumError("package cannot be deterministically regenerated")
    return manifest
