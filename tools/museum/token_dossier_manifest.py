"""Offline source-bound composition for the new native token dossier recipe.

Only externally pinned manifests and their explicitly selected artifacts are
read. Git supplies immutable source bytes, never compiler products. Metadata
correspondence is not a reproducible build or acceptance of the composition.
"""
import argparse
from copy import deepcopy
import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

MODE = "current_museum_native_products_v1"
AUDIT = "STREAM_MUSEUM_TOKEN_DOSSIER_COMPOSITION_AUDIT_V1"
OWNER = "StreamOwnerRecords"
OWNER_SOURCE = "smart-contracts/domains/metadata/StreamOwnerRecords.sol"
PROJECTION_PRODUCTS = ("StreamArtistIdentityAuthority", "StreamArtistOnboardingRegistry",
    "StreamArtistOwner", "StreamGasParameterHost", "StreamModuleBase")
MAX_MANIFEST, MAX_ARTIFACT, MAX_SOURCE, MAX_PRODUCTS = 16777216, 33554432, 4194304, 4096
QUALIFICATION = ("Every selected artifact is externally SHA-256 pinned and its compiler metadata source hashes "
    "are compared with the exact Git revision, using only the explicitly declared line-ending transport. "
    "The original tokenComposition, official Safe pin and graph projection are retained as lineage. New or "
    "replaced products are a new composition, not accepted mint-graph products. Compiler metadata does not "
    "prove reproducible bytecode, constructor compatibility, execution, or genuine native capture acceptance.")
CLAIMS = {"compilerMetadataSourceCorrespondence": True, "reproducibleCompilationProven": False,
    "joinedCompositionPreviouslyAccepted": False, "actualNativeCaptureAcceptance": False,
    "fullObjectDossierConformance": False, "compilerExecuted": False, "chainExecuted": False}


def _sha(raw):
    return hashlib.sha256(raw).hexdigest()


def _hash(value, label):
    require(type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) is not None, label + " SHA-256 shape")
    return value


def _read(path, maximum):
    with Path(path).open("rb") as handle:
        raw = handle.read(maximum + 1)
    require(len(raw) <= maximum, "composition file bound: " + str(path))
    return raw


def _pinned(path, expected, maximum):
    _hash(expected, "composition input")
    raw = _read(path, maximum)
    require(_sha(raw) == expected, "composition input pin differs: " + str(path))
    return loads(raw, maximum=maximum), raw


def _source_path(value):
    require(type(value) is str and 0 < len(value) <= 1024 and value.endswith(".sol")
        and "\\" not in value and ":" not in value and not any(ord(c) < 32 for c in value)
        and not value.startswith("/") and all(part not in ("", ".", "..") for part in value.split("/"))
        and str(PurePosixPath(value)) == value, "composition source path is not portable relative Solidity")
    return value


def _name(value):
    require(type(value) is str and re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]{0,127}", value) is not None,
        "composition product name")
    return value


class GitSources:
    """Read only exact revision:path objects; no worktree, index, or discovery."""
    def __init__(self, repository, revision):
        require(type(revision) is str and re.fullmatch(r"[0-9a-f]{40}", revision) is not None,
            "composition needs an immutable full Git source revision")
        self.repository, self.revision = str(Path(repository).resolve()), revision
        result = self._run("rev-parse", "--verify", revision + "^{commit}")
        require(result.returncode == 0 and result.stdout.decode("ascii").strip() == revision,
            "composition source revision is not the exact Git commit")
        self.cache = {}

    def _run(self, *arguments):
        return subprocess.run(["git", "-C", self.repository, *arguments], capture_output=True,
            check=False, timeout=30)

    def get(self, source):
        _source_path(source)
        if source not in self.cache:
            self.load([source])
        return self.cache[source]

    def load(self, sources):
        missing = sorted({_source_path(source) for source in sources} - self.cache.keys())
        require(len(self.cache) + len(missing) <= 8192, "composition source count bound")
        for start in range(0, len(missing), 64):
            batch = missing[start:start + 64]
            requests = [(self.revision + ":" + source).encode("utf-8") for source in batch]
            result = subprocess.run(["git", "-C", self.repository, "cat-file", "--batch"],
                input=b"\n".join(requests) + b"\n", capture_output=True, check=False, timeout=30)
            require(result.returncode == 0, "composition Git batch read failed")
            offset = 0
            for source, request in zip(batch, requests):
                end = result.stdout.find(b"\n", offset)
                require(end >= offset, "composition Git batch header missing")
                header = result.stdout[offset:end]; offset = end + 1
                if header == request + b" missing":
                    self.cache[source] = None
                    continue
                parts = header.split(b" ")
                require(len(parts) == 3 and parts[1] == b"blob" and parts[2].isdigit(), "composition source is not a Git blob")
                length = int(parts[2])
                require(length <= MAX_SOURCE and offset + length < len(result.stdout)
                    and result.stdout[offset + length:offset + length + 1] == b"\n", "composition Git source byte bound/framing")
                self.cache[source] = result.stdout[offset:offset + length]
                offset += length + 1
            require(offset == len(result.stdout) and sum(len(raw) for raw in self.cache.values() if raw is not None) <= 67108864,
                "composition Git source aggregate/framing bound")


def _manifest(path, expected):
    value, _ = _pinned(path, expected, MAX_MANIFEST)
    require(type(value) is dict and value.get("mode") == MODE and type(value.get("products")) is dict
        and len(value["products"]) <= MAX_PRODUCTS, "composition native manifest shape/mode")
    for name in value["products"]:
        _name(name)
    return value


def _artifact(name, row):
    require(type(row) is dict and {"source", "artifact", "sha256"} <= row.keys()
        and type(row["artifact"]) is str and Path(row["artifact"]).is_absolute(), "composition product row/path")
    _source_path(row["source"])
    value, _ = _pinned(row["artifact"], row["sha256"], MAX_ARTIFACT)
    require(type(value) is dict and type(value.get("abi")) is list and type(value.get("metadata")) is dict,
        "composition artifact ABI/metadata missing: " + name)
    metadata = value["metadata"]
    require(metadata.get("settings", {}).get("compilationTarget") == {row["source"]: name},
        "composition source/contract identity differs: " + name)
    require(type(metadata.get("sources")) is dict and row["source"] in metadata["sources"]
        and 0 < len(metadata["sources"]) <= 8192, "composition compiler source inventory missing: " + name)
    for source, source_row in metadata["sources"].items():
        _source_path(source)
        require(type(source_row) is dict and any(hex_bytes(source_row.get("keccak256"), 32)),
            "composition compiler source commitment missing")
    links = set()
    for field in ("bytecode", "deployedBytecode"):
        code = value.get(field)
        require(type(code) is dict and type(code.get("object")) is str and type(code.get("linkReferences")) is dict,
            "composition native code/link metadata missing: " + name)
        template = code["object"].removeprefix("0x")
        require(len(template) % 2 == 0, "composition bytecode alignment")
        occupied = set()
        for source, libraries in code["linkReferences"].items():
            _source_path(source)
            require(type(libraries) is dict, "composition library reference shape")
            for library, positions in libraries.items():
                _name(library)
                require(source in metadata["sources"] and type(positions) is list and positions,
                    "composition linked source/positions missing")
                links.add((source, library))
                for position in positions:
                    require(type(position) is dict and set(position) == {"start", "length"}
                        and type(position["start"]) is int and type(position["length"]) is int
                        and position["length"] == 20 and 0 <= position["start"] <= len(template) // 2 - 20,
                        "composition link offset differs")
                    span = set(range(position["start"], position["start"] + 20))
                    require(not span & occupied, "composition overlapping native links")
                    occupied |= span
                    start = position["start"] * 2
                    template = template[:start] + "00" * 20 + template[start + 40:]
        hex_bytes("0x" + template)
    if name == OWNER:
        require(row["source"] == OWNER_SOURCE and value["bytecode"]["object"] not in ("", "0x")
            and value["deployedBytecode"]["object"] not in ("", "0x"), "composition OwnerRecords root identity/code")
    return value, sorted(links)


def _source_check(source, expected, git, lf_transport):
    raw = git.get(source)
    result = {"source": source, "compilerKeccak256": expected}
    if raw is None:
        return result | {"status": "source_missing_at_revision"}
    result.update(gitSha256=_sha(raw), gitKeccak256=keccak256(raw), gitBytes=str(len(raw)))
    variants = [("exact_git_bytes", raw)]
    if lf_transport:
        lf = raw.replace(b"\r\n", b"\n")
        variants += [("git_crlf_to_lf", lf), ("git_lf_to_crlf", lf.replace(b"\n", b"\r\n"))]
    for transport, candidate in variants:
        if keccak256(candidate) == expected:
            return result | {"status": "matches", "transport": transport,
                "compilerSourceSha256": _sha(candidate), "compilerSourceBytes": str(len(candidate))}
    return result | {"status": "compiler_source_differs_from_revision"}


def _offsets(value):
    require(type(value) is dict, "composition immutable references shape")
    groups = []
    for identifier, positions in value.items():
        require(type(identifier) is str and identifier.isdecimal() and type(positions) is list and positions,
            "composition immutable reference group")
        group = []
        for position in positions:
            require(type(position) is dict and set(position) == {"start", "length"}
                and type(position["start"]) is int and position["start"] >= 0
                and type(position["length"]) is int and position["length"] == 32,
                "composition immutable offset shape")
            group.append((position["start"], position["length"]))
        groups.append(tuple(sorted(group)))
    require(len(groups) == len(set(groups)), "composition duplicate immutable groups")
    return set(groups)


def _projection(base, artifacts):
    pin = base.get("graphImmutableProjection")
    require(type(pin) is dict and set(pin) == {"directory", "manifestSha256"}, "composition graph projection pin missing")
    directory = Path(pin["directory"])
    manifest, _ = _pinned(directory / "manifest.json", pin["manifestSha256"], MAX_MANIFEST)
    require(manifest.get("artifactInputKind") == "current-native-export" and type(manifest.get("products")) is dict,
        "composition graph projection kind/shape")
    issues = []
    for name in PROJECTION_PRODUCTS:
        require(name in manifest["products"], "composition graph projection required product missing: " + name)
        row = manifest["products"][name]
        projected, raw = _pinned(directory / (name + ".json"), row["projectionSha256"], 1048576)
        require(len(raw) == row["projectionBytes"] and projected["contractName"] == name
            and projected["source"] == row["source"] and projected["compilationHash"] == manifest["compilerInputSha256"],
            "composition graph projection identity differs")
        for identifier, declaration in projected["immutableDeclarations"].items():
            require(str(declaration["id"]) == identifier and declaration["contractName"] == name
                and declaration["source"] == projected["source"] and declaration["compilationHash"] == projected["compilationHash"]
                and declaration["nodeType"] == "VariableDeclaration" and declaration["mutability"] == "immutable",
                "composition graph immutable declaration differs")
        artifact = artifacts.get(name)
        if artifact is None:
            issues.append({"product": name, "reason": "selected_artifact_unavailable"})
            continue
        identity = artifact["metadata"]["settings"]["compilationTarget"]
        if identity != {projected["source"]: name} or any(projected[field][key] != artifact[field][key]
                for field in ("bytecode", "deployedBytecode") for key in ("object", "linkReferences")):
            issues.append({"product": name, "reason": "fresh_projection_required_for_changed_template"})
        elif _offsets(projected["deployedBytecode"].get("immutableReferences", {})) != _offsets(artifact["deployedBytecode"].get("immutableReferences", {})):
            issues.append({"product": name, "reason": "fresh_projection_required_for_changed_immutable_offsets"})
    return issues


def _audit(base_path, base_sha256, products_path, products_sha256, *, repository, source_revision,
           replacements=(), lf_transport=False, projection=None):
    require(type(lf_transport) is bool, "composition LF transport must be explicit boolean")
    base, supplied = _manifest(base_path, base_sha256), _manifest(products_path, products_sha256)
    require(type(base.get("tokenComposition")) is dict and base["tokenComposition"].get("joinedCompositionPreviouslyAccepted") is False
        and "tokenDossierComposition" not in base, "composition needs original unpromoted token lineage")
    require(type(replacements) in (tuple, list) and len(replacements) == len(set(replacements)), "composition replacement list duplicate/shape")
    replacements = set(replacements)
    for name in replacements:
        _name(name)
        require(name in base["products"] and name in supplied["products"], "composition replacement must explicitly name both manifests: " + name)
    git = GitSources(repository, source_revision)
    safe = base.get("safeFixture")
    require(type(safe) is dict and set(safe) == {"path", "sha256"}, "composition original Safe pin missing")
    _pinned(safe["path"], safe["sha256"], MAX_MANIFEST)
    selected, artifacts, checks, missing, links, origins = {}, {}, {}, {}, [], {}
    pending = list(sorted(set(base["products"]) | {OWNER}, reverse=True))
    expected_sources = {OWNER: OWNER_SOURCE}
    source_checks = {}
    while pending:
        name = pending.pop()
        if name in selected or name in missing:
            continue
        require(len(selected) + len(missing) < MAX_PRODUCTS, "composition closure product bound")
        origin = "explicit_replacement" if name in replacements else "original_base" if name in base["products"] else "additional_link_closure"
        available = supplied["products"] if name in replacements or name not in base["products"] else base["products"]
        if name not in available:
            missing[name] = {"product": name, "source": expected_sources.get(name), "reason": "product_not_in_explicit_manifests"}
            continue
        row = deepcopy(available[name])
        if not Path(row["artifact"]).is_file():
            missing[name] = {"product": name, "source": row["source"], "reason": "pinned_artifact_file_missing"}
            continue
        artifact, dependencies = _artifact(name, row)
        require(name not in expected_sources or row["source"] == expected_sources[name],
            "composition linked source identity differs: " + name)
        selected[name], artifacts[name], origins[name] = row, artifact, origin
        indices = []
        git.load(artifact["metadata"]["sources"])
        for source, source_row in sorted(artifact["metadata"]["sources"].items()):
            key = (source, source_row["keccak256"])
            if key not in source_checks:
                source_checks[key] = _source_check(*key, git, lf_transport)
            indices.append(key)
        checks[name] = indices
        for source, library in dependencies:
            require(library not in expected_sources or expected_sources[library] == source,
                "composition ambiguous library source identity: " + library)
            expected_sources[library] = source
            if library in selected:
                require(selected[library]["source"] == source, "composition linked source identity differs: " + library)
            pending.append(library)
            links.append({"product": name, "library": library, "source": source})
    source_indices = {key: str(index) for index, key in enumerate(sorted(source_checks))}
    stale = [{"product": name, "source": selected[name]["source"],
        "changedSourceIndices": [source_indices[key] for key in checks[name] if source_checks[key]["status"] != "matches"],
        "explicitReplacementAvailable": name in supplied["products"] and name not in replacements}
        for name in sorted(selected) if any(source_checks[key]["status"] != "matches" for key in checks[name])]
    selected_projection = deepcopy(base.get("graphImmutableProjection") if projection is None else projection)
    projection_issues = _projection(base | {"graphImmutableProjection": selected_projection}, artifacts)
    report = {"profile": AUDIT, "version": "1", "sourceRevision": source_revision,
        "baseManifestSha256": base_sha256, "nativeProductsManifestSha256": products_sha256,
        "lfTransportEnabled": lf_transport, "explicitReplacements": sorted(replacements), "additionalRootProducts": [OWNER],
        "requiredProducts": sorted(set(selected) | set(missing)), "linkClosure": sorted(links, key=lambda row: (row["product"], row["library"])),
        "missingProducts": [missing[name] for name in sorted(missing)], "staleProducts": stale,
        "requiredNativeProducts": sorted(set(missing) | {row["product"] for row in stale}),
        "originalGraphImmutableProjection": base["graphImmutableProjection"],
        "selectedGraphImmutableProjection": selected_projection, "projectionExplicitlyReplaced": projection is not None,
        "projectionIssues": projection_issues, "closureComplete": not missing,
        "preparationReady": not missing and not stale and not projection_issues,
        "minimumQualification": "Minimum known missing/stale products for the selected base and declared link closure. Missing artifacts can hide further linked dependencies; no absent closure is guessed.",
        "products": [{"product": name, "source": selected[name]["source"], "artifactSha256": selected[name]["sha256"],
            "selection": origins[name], "compiler": artifacts[name]["metadata"].get("compiler"),
            "compilerSourceIndices": [source_indices[key] for key in checks[name]]}
            for name in sorted(selected)],
        "sourceChecks": [source_checks[key] | {"index": source_indices[key]} for key in sorted(source_checks)],
        "claims": CLAIMS | {"compilerMetadataSourceCorrespondence": not missing and not stale}, "qualification": QUALIFICATION}
    return report, base, selected, origins


def audit(base_path, base_sha256, products_path, products_sha256, **options):
    """Return canonical audit bytes; a valid pin with stale source is diagnostic."""
    return dumps(_audit(base_path, base_sha256, products_path, products_sha256, **options)[0])


def prepare_manifest(base_path, base_sha256, products_path, products_sha256, **options):
    report, base, selected, origins = _audit(base_path, base_sha256, products_path, products_sha256, **options)
    require(report["preparationReady"], "token dossier composition is incomplete/stale; required native products: "
        + ", ".join(report["requiredNativeProducts"]) + "; projection products: "
        + ", ".join(row["product"] for row in report["projectionIssues"]))
    result = deepcopy(base)
    for name, row in selected.items():
        if origins[name] != "original_base":
            selected[name] = {"source": row["source"], "artifact": row["artifact"], "sha256": row["sha256"],
                "origin": "token_dossier_" + origins[name], "sourceRevision": report["sourceRevision"],
                "nativeProductsManifestSha256": products_sha256, "originalProductRow": row}
    result["products"] = dict(sorted(selected.items()))
    result["graphImmutableProjection"] = report["selectedGraphImmutableProjection"]
    result["tokenDossierComposition"] = {"version": "1", "sourceRevision": report["sourceRevision"],
        "baseManifestSha256": base_sha256, "nativeProductsManifestSha256": products_sha256,
        "baseManifest": {"path": str(Path(base_path).resolve()), "sha256": base_sha256},
        "nativeProductsManifest": {"path": str(Path(products_path).resolve()), "sha256": products_sha256},
        "auditHash": keccak256(dumps(report)), "lfTransportEnabled": report["lfTransportEnabled"],
        "originalGraphImmutableProjection": report["originalGraphImmutableProjection"],
        "selectedGraphImmutableProjection": report["selectedGraphImmutableProjection"],
        "projectionExplicitlyReplaced": report["projectionExplicitlyReplaced"],
        "explicitReplacements": report["explicitReplacements"], "products": report["products"],
        "sourceChecks": report["sourceChecks"], "sourceQualification": QUALIFICATION,
        "joinedCaptureStatus": "not_run", "claims": CLAIMS}
    return dumps(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("audit", "prepare"))
    parser.add_argument("--base", type=Path, required=True); parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--products", type=Path, required=True); parser.add_argument("--products-sha256", required=True)
    parser.add_argument("--repository", type=Path, required=True); parser.add_argument("--source-revision", required=True)
    parser.add_argument("--replace", action="append", default=[]); parser.add_argument("--lf-transport", action="store_true")
    parser.add_argument("--projection-directory", type=Path)
    parser.add_argument("--projection-manifest-sha256")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require((args.projection_directory is None) == (args.projection_manifest_sha256 is None), "composition projection override needs directory and pin")
    projection = None if args.projection_directory is None else {"directory": str(args.projection_directory.resolve()),
        "manifestSha256": args.projection_manifest_sha256}
    function = audit if args.command == "audit" else prepare_manifest
    raw = function(args.base, args.base_sha256, args.products, args.products_sha256, repository=args.repository,
        source_revision=args.source_revision, replacements=args.replace, lf_transport=args.lf_transport, projection=projection)
    with args.output.open("xb") as output:
        output.write(raw)
    print(dumps({"mode": args.command, "sha256": _sha(raw), "bytes": str(len(raw))}).decode())


if __name__ == "__main__":
    try: main()
    except (MuseumError, OSError, subprocess.SubprocessError) as exc: raise SystemExit(str(exc)) from None
