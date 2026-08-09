#!/usr/bin/env python3
"""Focused tests for release checksum bundle generation."""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest import mock

from jsonschema import Draft202012Validator


SCRIPT_PATH = Path(__file__).with_name("generate_release_checksums.py")
CUSTOM_OUTPUT_DIR = Path("release-artifacts/custom-checksums")
SPEC = importlib.util.spec_from_file_location("generate_release_checksums", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)

EXPECTED_RELEASE_TOOL_RUNTIME_CLOSURE = (
    Path("scripts/check_admin_ceremony_evidence.py"),
    Path("scripts/check_artist_semantic_owner_matrix.py"),
    Path("scripts/check_changelog.py"),
    Path("scripts/check_drop_authorization_signing_evidence.py"),
    Path("scripts/check_governance_action_policy.py"),
    Path("scripts/check_governed_parameter_identifiers.py"),
    Path("scripts/check_governed_parameter_inventory.py"),
    Path("scripts/check_non_local_release_evidence.py"),
    Path("scripts/check_public_beta_evidence.py"),
    Path("scripts/check_record_family_authorization.py"),
    Path("scripts/check_release_evidence_issue_links.py"),
    Path("scripts/check_release_signatures.py"),
    Path("scripts/check_risk_register.py"),
    Path("scripts/check_signer_custody_readiness.py"),
    Path("scripts/check_slither_baseline.py"),
    Path("scripts/generate_bytecode_release_proof.py"),
    Path("scripts/generate_release_candidate_lockfile.py"),
    Path("scripts/generate_release_checksums.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/generate_risk_register.py"),
    Path("scripts/no_secret_scanner.py"),
    Path("scripts/release_evidence_paths.py"),
    Path("scripts/verify_release_artifacts.py"),
)
EXPECTED_RELEASE_TOOL_FOCUSED_TESTS = (
    Path("scripts/test_changelog_check.py"),
    Path("scripts/test_release_notes.py"),
    Path("scripts/test_admin_ceremony_evidence.py"),
    Path("scripts/test_drop_authorization_signing_evidence.py"),
    Path("scripts/test_non_local_release_evidence.py"),
    Path("scripts/test_artist_semantic_owner_matrix.py"),
    Path("scripts/test_record_family_authorization.py"),
    Path("scripts/test_release_signatures.py"),
    Path("scripts/test_signer_custody_readiness.py"),
    Path("scripts/test_bytecode_release_proof.py"),
)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def copy_release_tool_call_policy_sources(destination: Path) -> None:
    repo_root = SCRIPT_PATH.parent.parent
    for relative_path in generator.RELEASE_TOOL_CALL_POLICY_PATHS:
        target = destination / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((repo_root / relative_path).read_bytes())


def release_tool_call_policy_snapshots(
    repo_root: Path,
) -> dict[str, generator.CoveredFileSnapshot]:
    policy_bytes = generator.json_text(
        generator.build_release_tool_call_policy(repo_root)
    ).encode("utf-8")
    paths = (
        *generator.RELEASE_TOOL_CALL_POLICY_PATHS,
        generator.RELEASE_TOOL_CALL_POLICY_PATH,
        generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
    )
    snapshots = {}
    for relative_path in paths:
        if relative_path == generator.RELEASE_TOOL_CALL_POLICY_PATH:
            data = policy_bytes
        else:
            data = (repo_root / relative_path).read_bytes()
        snapshots[relative_path.as_posix()] = generator.CoveredFileSnapshot(
            path=repo_root / relative_path,
            relative_path=relative_path.as_posix(),
            data=data,
            sha256=generator.sha256_bytes(data),
            size_bytes=len(data),
            classification="lf",
        )
    return snapshots


def reviewed_source_snapshots(
    repo_root: Path,
) -> dict[str, generator.CoveredFileSnapshot]:
    snapshots = {}
    for relative_path in generator.RELEASE_TOOL_CALL_POLICY_PATHS:
        data = (repo_root / relative_path).read_bytes()
        snapshots[relative_path.as_posix()] = generator.CoveredFileSnapshot(
            path=repo_root / relative_path,
            relative_path=relative_path.as_posix(),
            data=data,
            sha256=generator.sha256_bytes(data),
            size_bytes=len(data),
            classification="lf",
        )
    return snapshots


def append_snapshot_bytes(
    snapshots: dict[str, generator.CoveredFileSnapshot],
    relative_path: Path,
    suffix: bytes,
) -> None:
    key = relative_path.as_posix()
    snapshot = snapshots[key]
    data = snapshot.data + suffix
    snapshots[key] = snapshot._replace(
        data=data,
        sha256=generator.sha256_bytes(data),
        size_bytes=len(data),
    )


class ReleaseChecksumTests(unittest.TestCase):
    def test_release_tool_runtime_closure_matches_reviewed_literal(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        self.assertEqual(
            generator.release_tool_runtime_closure(repo_root),
            EXPECTED_RELEASE_TOOL_RUNTIME_CLOSURE,
        )
        self.assertEqual(
            generator.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE,
            EXPECTED_RELEASE_TOOL_RUNTIME_CLOSURE,
        )
        self.assertEqual(
            generator.RELEASE_TOOL_FOCUSED_TESTS,
            EXPECTED_RELEASE_TOOL_FOCUSED_TESTS,
        )

    def test_release_tool_trust_policy_has_exact_configured_cardinality(
        self,
    ) -> None:
        self.assertEqual(len(generator.DEFAULT_COVERED_PATHS), 286)
        self.assertEqual(
            len(set(generator.DEFAULT_COVERED_PATHS)),
            len(generator.DEFAULT_COVERED_PATHS),
        )
        self.assertIn(
            generator.GIT_ATTRIBUTES_PATH,
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            generator.RELEASE_TOOL_CALL_POLICY_PATH,
            generator.DEFAULT_COVERED_PATHS,
        )
        for path in generator.RELEASE_TOOL_SEMANTIC_SOURCE_PATHS:
            with self.subTest(path=path):
                self.assertIn(path, generator.DEFAULT_COVERED_PATHS)

    def test_canonical_policy_rejects_semantic_source_omission_or_substitution(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        output_dir = repo_root / generator.DEFAULT_OUTPUT_DIR
        for path in generator.RELEASE_TOOL_SEMANTIC_SOURCE_PATHS:
            with self.subTest(path=path, mutation="omission"):
                covered = [
                    candidate
                    for candidate in generator.DEFAULT_COVERED_PATHS
                    if candidate != path
                ]
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    re.escape(path.as_posix()),
                ):
                    generator.build_outputs(
                        repo_root,
                        covered,
                        output_dir,
                    )

            with self.subTest(path=path, mutation="substitution"):
                covered = [
                    (
                        Path("smart-contracts/core/StreamCore.sol")
                        if candidate == path
                        else candidate
                    )
                    for candidate in generator.DEFAULT_COVERED_PATHS
                ]
                self.assertEqual(
                    len(covered),
                    len(generator.DEFAULT_COVERED_PATHS),
                )
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    (
                        re.escape(path.as_posix())
                        + ".*StreamCore\\.sol|StreamCore\\.sol.*"
                        + re.escape(path.as_posix())
                    ),
                ):
                    generator.build_outputs(
                        repo_root,
                        covered,
                        output_dir,
                    )

    def test_release_tool_call_policy_has_exact_complete_static_surface(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        policy = generator.build_release_tool_call_policy(repo_root)
        rows = policy["reviewed_paths"]

        self.assertEqual(policy["schema_version"], generator.RELEASE_TOOL_CALL_POLICY_SCHEMA)
        self.assertEqual(policy["generator_version"], "1")
        self.assertEqual(
            policy["runtime_roots"],
            [
                path.as_posix()
                for path in generator.REVIEWED_RELEASE_TOOL_ROOTS
            ],
        )
        self.assertEqual(
            policy["external_modules"],
            sorted(generator.RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES),
        )
        self.assertEqual(len(policy["external_modules"]), 31)
        self.assertEqual(len(rows), 34)
        self.assertEqual(
            [row["path"] for row in rows],
            [path.as_posix() for path in generator.RELEASE_TOOL_CALL_POLICY_PATHS],
        )
        self.assertEqual(
            sum(row["role"] == "runtime" for row in rows),
            24,
        )
        self.assertEqual(
            sum(row["role"] == "focused-test" for row in rows),
            10,
        )
        self.assertEqual(
            len(generator.RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST),
            227,
        )
        self.assertEqual(
            len(generator.RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST),
            5,
        )
        schema = json.loads(
            (
                repo_root
                / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
            ).read_text(encoding="utf-8")
        )
        validator = Draft202012Validator(schema)
        self.assertEqual(list(validator.iter_errors(policy)), [])
        path_validator = Draft202012Validator(
            schema["$defs"]["reviewedPath"]["properties"]["path"]
        )
        for path in (
            "scripts/check_release_signatures.py",
            "scripts/package/sub_dir/test-file.py",
        ):
            with self.subTest(valid_path=path):
                self.assertEqual(
                    list(path_validator.iter_errors(path)),
                    [],
                )
        for path in (
            "scripts/./x.py",
            "scripts/a/./x.py",
            "scripts/../x.py",
            "scripts/a/../x.py",
            "scripts//x.py",
            "scripts/a//x.py",
            r"scripts\x.py",
        ):
            with self.subTest(path_alias=path):
                self.assertTrue(list(path_validator.iter_errors(path)))
        schema_mutations = {}
        duplicate_path = json.loads(json.dumps(policy))
        duplicate_path["reviewed_paths"][-1] = json.loads(
            json.dumps(duplicate_path["reviewed_paths"][0])
        )
        schema_mutations["duplicate-path"] = duplicate_path
        wrong_path = json.loads(json.dumps(policy))
        wrong_path["reviewed_paths"][0]["path"] = "scripts/../outside.py"
        schema_mutations["wrong-path"] = wrong_path
        wrong_role = json.loads(json.dumps(policy))
        wrong_role["reviewed_paths"][0]["role"] = "focused-test"
        schema_mutations["wrong-role"] = wrong_role
        for label, mutation in schema_mutations.items():
            with self.subTest(schema_mutation=label):
                self.assertTrue(list(validator.iter_errors(mutation)))
        for path in (
            "scripts/./x.py",
            "scripts/a/../x.py",
            "scripts/a//x.py",
            r"scripts\x.py",
        ):
            with self.subTest(semantic_path_alias=path):
                mutation = json.loads(json.dumps(policy))
                mutation["reviewed_paths"][0]["path"] = path
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    r"normalized scripts/\.\.\./\*\.py path",
                ):
                    generator.validate_release_tool_call_policy(
                        repo_root,
                        policy_bytes=generator.json_text(mutation).encode(
                            "utf-8"
                        ),
                    )
        self.assertTrue(
            all(
                len(record) == 4 and all(record)
                for record in (
                    generator.RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST
                )
            )
        )
        self.assertTrue(
            all(
                len(record) == 4 and all(record)
                for record in (
                    generator.RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST
                )
            )
        )
        for row in rows:
            with self.subTest(path=row["path"]):
                source = repo_root / row["path"]
                source_bytes = source.read_bytes()
                self.assertEqual(row["source_sha256"], generator.hashlib.sha256(source_bytes).hexdigest())
                self.assertEqual(row["size_bytes"], len(source_bytes))
                self.assertEqual(
                    row["imports"],
                    sorted(row["imports"], key=lambda record: record["record"]),
                )
                self.assertEqual(
                    row["members"],
                    sorted(row["members"], key=lambda record: record["record"]),
                )
                self.assertEqual(
                    row["calls"],
                    sorted(
                        row["calls"],
                        key=lambda record: (
                            record["target"],
                            record["shape"],
                            record["ast_sha256"],
                        ),
                    ),
                )
                self.assertTrue(all(record["count"] >= 1 for record in row["imports"]))
                self.assertTrue(all(record["count"] >= 1 for record in row["members"]))
                self.assertTrue(all(record["count"] >= 1 for record in row["calls"]))

        source_snapshots = reviewed_source_snapshots(repo_root)
        cross_role_snapshots = dict(source_snapshots)
        runtime_root = Path("scripts/generate_release_notes.py")
        append_snapshot_bytes(
            cross_role_snapshots,
            runtime_root,
            b"\nimport test_changelog_check\n",
        )
        with self.assertRaisesRegex(
            generator.ChecksumError,
            "snapshot runtime closure.*unexpected=.*test_changelog_check",
        ):
            generator.build_release_tool_call_policy(
                repo_root,
                source_snapshots=cross_role_snapshots,
            )

        alternate_loader_snapshots = dict(source_snapshots)
        append_snapshot_bytes(
            alternate_loader_snapshots,
            runtime_root,
            b"\nimport importlib.util\n"
            b"_spec = importlib.util.spec_from_file_location("
            b"'hidden', 'scripts/test_changelog_check.py')\n"
            b"_module = importlib.util.module_from_spec(_spec)\n"
            b"_spec.loader.exec_module(_module)\n",
        )
        with self.assertRaisesRegex(
            generator.ChecksumError,
            "runtime call policy forbids alternate loader",
        ):
            generator.build_release_tool_call_policy(
                repo_root,
                source_snapshots=alternate_loader_snapshots,
            )

        root_mutations = (
            generator.RELEASE_TOOL_ROOTS[:-1],
            (
                *generator.RELEASE_TOOL_ROOTS[:-1],
                Path("scripts/check_changelog.py"),
            ),
        )
        for roots in root_mutations:
            with self.subTest(roots=roots), mock.patch.object(
                generator,
                "RELEASE_TOOL_ROOTS",
                roots,
            ), self.assertRaisesRegex(
                generator.ChecksumError,
                "exact reviewed seven-root literal",
            ):
                generator.build_release_tool_call_policy(
                    repo_root,
                    source_snapshots=source_snapshots,
                )

        coordinated_roots = (
            *generator.REVIEWED_RELEASE_TOOL_ROOTS[:-1],
            Path("scripts/check_changelog.py"),
        )
        with mock.patch.object(
            generator,
            "RELEASE_TOOL_ROOTS",
            coordinated_roots,
        ), mock.patch.object(
            generator,
            "REVIEWED_RELEASE_TOOL_ROOTS",
            coordinated_roots,
        ), self.assertRaisesRegex(
            generator.ChecksumError,
            "pinned canonical digest",
        ):
            generator.build_release_tool_call_policy(
                repo_root,
                source_snapshots=source_snapshots,
            )

        with mock.patch.object(
            generator,
            "RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES",
            frozenset(
                {
                    *generator.RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES,
                    "unused_external_permission",
                }
            ),
        ), self.assertRaisesRegex(
            generator.ChecksumError,
            "external-module inventory.*unused_external_permission",
        ):
            generator.build_release_tool_call_policy(
                repo_root,
                source_snapshots=source_snapshots,
            )

        coordinated_external_snapshots = dict(source_snapshots)
        append_snapshot_bytes(
            coordinated_external_snapshots,
            runtime_root,
            b"\nimport socket\n",
        )
        with mock.patch.object(
            generator,
            "RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES",
            frozenset(
                {
                    *generator.RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES,
                    "socket",
                }
            ),
        ), self.assertRaisesRegex(
            generator.ChecksumError,
            "31-module canonical digest",
        ):
            generator.build_release_tool_call_policy(
                repo_root,
                source_snapshots=coordinated_external_snapshots,
            )

    def test_release_tool_call_policy_allows_exact_reviewed_control(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        policy_bytes = generator.json_text(
            generator.build_release_tool_call_policy(repo_root)
        ).encode("utf-8")
        schema_bytes = (
            repo_root / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
        ).read_bytes()
        with tempfile.TemporaryDirectory(dir=repo_root) as temp_dir:
            root = Path(temp_dir)
            copy_release_tool_call_policy_sources(root)
            self.assertEqual(
                generator.validate_release_tool_call_policy(
                    root,
                    policy_bytes=policy_bytes,
                    schema_bytes=schema_bytes,
                ),
                generator.RELEASE_TOOL_CALL_POLICY_PATHS,
            )

    def test_release_tool_call_policy_rejects_unlisted_static_surface(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        policy_bytes = generator.json_text(
            generator.build_release_tool_call_policy(repo_root)
        ).encode("utf-8")
        schema_bytes = (
            repo_root / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
        ).read_bytes()
        target_path = Path("scripts/check_admin_ceremony_evidence.py")
        mutations = {
            "direct-call": '\njson.dumps({"unexpected": True})\n',
            "alias": "\nescaped = json.dumps\nescaped({})\n",
            "container": "\nescaped = [json.dumps]\n",
            "return": "\ndef escaped():\n    return json.dumps\n",
            "conditional": "\nescaped = json.dumps if True else str\n",
            "getattr": "\nmember = 'loads'\ngetattr(json, member)('{}')\n",
            "descendant": "\njson.decoder.JSONDecoder()\n",
        }
        for name, suffix in mutations.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                copy_release_tool_call_policy_sources(root)
                target = root / target_path
                target.write_text(
                    target.read_text(encoding="utf-8") + suffix,
                    encoding="utf-8",
                    newline="\n",
                )
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    (
                        "release-tool call policy "
                        "(differs from the bounded static inventory|forbids)"
                    ),
                ):
                    generator.validate_release_tool_call_policy(
                        root,
                        policy_bytes=policy_bytes,
                        schema_bytes=schema_bytes,
                    )

    def test_release_tool_call_policy_rejects_role_path_or_row_duplicates(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        policy = generator.build_release_tool_call_policy(repo_root)
        schema_bytes = (
            repo_root / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
        ).read_bytes()
        mutations = []

        missing = json.loads(json.dumps(policy))
        missing["reviewed_paths"].pop()
        mutations.append(missing)

        duplicate = json.loads(json.dumps(policy))
        duplicate["reviewed_paths"][-1] = json.loads(
            json.dumps(duplicate["reviewed_paths"][0])
        )
        mutations.append(duplicate)

        wrong_role = json.loads(json.dumps(policy))
        wrong_role["reviewed_paths"][0]["role"] = "focused-test"
        mutations.append(wrong_role)

        missing_root = json.loads(json.dumps(policy))
        missing_root["runtime_roots"].pop()
        mutations.append(missing_root)

        substituted_root = json.loads(json.dumps(policy))
        substituted_root["runtime_roots"][-1] = (
            "scripts/check_changelog.py"
        )
        mutations.append(substituted_root)

        for field in ("imports", "members", "calls"):
            duplicate_semantic_key = json.loads(json.dumps(policy))
            row = next(
                candidate
                for candidate in duplicate_semantic_key["reviewed_paths"]
                if candidate[field]
            )
            duplicate_record = json.loads(json.dumps(row[field][0]))
            duplicate_record["count"] += 1
            row[field].append(duplicate_record)
            mutations.append(duplicate_semantic_key)

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            copy_release_tool_call_policy_sources(root)
            for mutation in mutations:
                with self.subTest(
                    paths=len(mutation["reviewed_paths"]),
                    first_role=mutation["reviewed_paths"][0]["role"],
                ), self.assertRaisesRegex(
                    generator.ChecksumError,
                    "release-tool call policy differs from the bounded static inventory",
                ):
                    generator.validate_release_tool_call_policy(
                        root,
                        policy_bytes=generator.json_text(mutation).encode("utf-8"),
                        schema_bytes=schema_bytes,
                    )

    def test_release_tool_call_policy_rejects_wildcard_dynamic_and_computed_calls(
        self,
    ) -> None:
        hostile_sources = {
            "wildcard": "from json import *\n",
            "relative-current": "from . import evil\n",
            "relative-parent": "from ..check_changelog import X\n",
            "dynamic-import": "__import__('json')\n",
            "computed-attribute": "import json\nname = 'loads'\ngetattr(json, name)('{}')\n",
            "computed-callable": "callbacks = [str]\ncallbacks[0](1)\n",
        }
        for name, source in hostile_sources.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                path = Path("scripts/sample.py")
                write_text(root / path, source)
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    (
                        "wildcard import|every relative import|dynamic import|"
                        "computed attribute|computed or escaped callable|"
                        "unreviewed imported value context"
                    ),
                ):
                    generator._release_tool_call_policy_row(
                        root,
                        path,
                    "focused-test",
                )

    def test_release_tool_call_policy_rejects_imported_binding_laundering(
        self,
    ) -> None:
        hostile_sources = {
            "module-alias": (
                "import json\n"
                "escaped = json\n"
                "escaped.dumps({})\n"
            ),
            "callable-alias": (
                "import json\n"
                "escaped = json.dumps\n"
                "escaped({})\n"
            ),
            "returned-module": (
                "import json\n"
                "def expose():\n"
                "    return json\n"
                "expose().dumps({})\n"
            ),
            "argument-module": (
                "import json\n"
                "def sink(value):\n"
                "    return None\n"
                "sink(json)\n"
            ),
            "argument-callable": (
                "import json\n"
                "def sink(value):\n"
                "    return None\n"
                "sink(json.dumps)\n"
            ),
            "alias-type": (
                "from pathlib import Path\n"
                "escaped = Path\n"
            ),
            "return-type": (
                "from pathlib import Path\n"
                "def expose():\n"
                "    return Path\n"
            ),
            "container-type": (
                "from pathlib import Path\n"
                "escaped = [Path]\n"
            ),
            "conditional-type": (
                "from pathlib import Path\n"
                "escaped = Path if True else str\n"
            ),
            "assignment-shadow": (
                "import json\n"
                "json = object()\n"
                "json.dumps({})\n"
            ),
            "deletion-shadow": "import json\ndel json\n",
            "parameter-shadow": (
                "import json\n"
                "def encode(json):\n"
                "    return json.dumps({})\n"
            ),
            "for-shadow": "import json\nfor json in ():\n    pass\n",
            "with-shadow": (
                "import json\n"
                "with open('unused') as json:\n"
                "    pass\n"
            ),
            "except-shadow": (
                "import json\n"
                "try:\n"
                "    pass\n"
                "except Exception as json:\n"
                "    pass\n"
            ),
            "function-shadow": "import json\ndef json():\n    pass\n",
            "async-function-shadow": "import json\nasync def json():\n    pass\n",
            "class-shadow": "import json\nclass json:\n    pass\n",
            "global-shadow": "import json\ndef use():\n    global json\n",
            "nonlocal-shadow": (
                "def outer():\n"
                "    import json\n"
                "    def inner():\n"
                "        nonlocal json\n"
            ),
            "match-as-shadow": (
                "import json\n"
                "match value:\n"
                "    case json:\n"
                "        pass\n"
                "json.dumps({})\n"
            ),
            "match-star-shadow": (
                "import json\n"
                "match value:\n"
                "    case [*json]:\n"
                "        pass\n"
                "json.dumps({})\n"
            ),
            "match-mapping-rest-shadow": (
                "import json\n"
                "match value:\n"
                "    case {**json}:\n"
                "        pass\n"
                "json.dumps({})\n"
            ),
        }
        for name, source in hostile_sources.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                path = Path("scripts/sample.py")
                write_text(root / path, source)
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    (
                        "forbids (imported binding shadow|imported binding escape|"
                        "unreviewed imported value context)"
                    ),
                ):
                    generator._release_tool_call_policy_row(
                        root,
                        path,
                        "focused-test",
                    )

        duplicate_fallback = (
            "try:\n"
            "    from jsonschema import Draft202012Validator\n"
            "except ModuleNotFoundError:\n"
            "    Draft202012Validator = None\n"
            "try:\n"
            "    pass\n"
            "except ModuleNotFoundError:\n"
            "    Draft202012Validator = None\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = Path("scripts/check_governed_parameter_inventory.py")
            write_text(root / path, duplicate_fallback)
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "forbids imported binding shadow",
            ):
                generator._release_tool_call_policy_row(
                    root,
                    path,
                    "runtime",
                )

    def test_release_tool_call_policy_allows_local_expression_receiver_only(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = Path("scripts/sample.py")
            write_text(
                root / path,
                "def resolve(root, candidate):\n"
                "    return (root / candidate).resolve()\n",
            )
            row = generator._release_tool_call_policy_row(
                root,
                path,
                "focused-test",
            )
            self.assertTrue(
                any(
                    record["target"].startswith("expression:BinOp:")
                    and record["target"].endswith(".resolve")
                    for record in row["calls"]
                )
            )

            write_text(
                root / path,
                "import pathlib\n"
                "def resolve(candidate):\n"
                "    return (pathlib.Path / candidate).resolve()\n",
            )
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "imported binding in computed receiver",
            ):
                generator._release_tool_call_policy_row(
                    root,
                    path,
                    "focused-test",
                )

    def test_release_tool_call_policy_rejects_hollow_schema(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        policy_bytes = generator.json_text(
            generator.build_release_tool_call_policy(repo_root)
        ).encode("utf-8")
        hollow_schema = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_ID,
            "title": "6529Stream Release Tool Call Policy v1",
            "type": "object",
            "additionalProperties": False,
            "required": [
                "schema_version",
                "generator_version",
                "reviewed_paths",
            ],
            "properties": {
                "schema_version": {
                    "const": generator.RELEASE_TOOL_CALL_POLICY_SCHEMA,
                },
                "generator_version": {
                    "const": "1",
                },
                "reviewed_paths": {
                    "type": "array",
                    "minItems": 34,
                    "maxItems": 34,
                    "items": {},
                },
            },
            "$defs": {},
        }
        with self.assertRaisesRegex(
            generator.ChecksumError,
            "exact strict Draft 2020-12 shape",
        ):
            generator.validate_release_tool_call_policy(
                repo_root,
                policy_bytes=policy_bytes,
                schema_bytes=generator.json_text(hollow_schema).encode("utf-8"),
            )

    def test_release_tool_call_policy_uses_one_immutable_source_snapshot(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            copy_release_tool_call_policy_sources(root)
            schema_target = root / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
            schema_target.parent.mkdir(parents=True, exist_ok=True)
            schema_target.write_bytes(
                (
                    repo_root
                    / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
                ).read_bytes()
            )
            snapshots = release_tool_call_policy_snapshots(root)
            changed_source = root / "scripts/check_admin_ceremony_evidence.py"
            write_text(changed_source, "raise RuntimeError('post-capture replacement')\n")
            with mock.patch.object(
                Path,
                "read_bytes",
                side_effect=AssertionError("unexpected live path reread"),
            ):
                self.assertEqual(
                    generator.validate_release_tool_call_policy(
                        root,
                        source_snapshots=snapshots,
                    ),
                    generator.RELEASE_TOOL_CALL_POLICY_PATHS,
                )

            changed = snapshots[
                "scripts/check_admin_ceremony_evidence.py"
            ]
            changed_data = changed.data + b"\njson.dumps({})\n"
            changed_snapshots = dict(snapshots)
            changed_snapshots[changed.relative_path] = changed._replace(
                data=changed_data,
                sha256=generator.sha256_bytes(changed_data),
                size_bytes=len(changed_data),
            )
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "differs from the bounded static inventory",
            ):
                generator.validate_release_tool_call_policy(
                    root,
                    source_snapshots=changed_snapshots,
                )

            metadata_mutations = {
                "path": changed._replace(
                    path=repo_root / changed.relative_path,
                ),
                "relative-path": changed._replace(
                    relative_path="scripts/wrong.py",
                ),
                "sha256": changed._replace(sha256="sha256:" + "0" * 64),
                "size": changed._replace(size_bytes=changed.size_bytes + 1),
                "classification": changed._replace(classification=None),
            }
            for field, mutation in metadata_mutations.items():
                with self.subTest(field=field):
                    invalid_snapshots = dict(snapshots)
                    invalid_snapshots[changed.relative_path] = mutation
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "immutable snapshot metadata mismatch",
                    ):
                        generator.validate_release_tool_call_policy(
                            root,
                            source_snapshots=invalid_snapshots,
                        )

    def test_release_tool_call_policy_explicit_refresh_and_check_modes(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        with tempfile.TemporaryDirectory(dir=repo_root) as temp_dir:
            root = Path(temp_dir)
            copy_release_tool_call_policy_sources(root)
            schema_target = root / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
            schema_target.parent.mkdir(parents=True, exist_ok=True)
            schema_target.write_bytes(
                (
                    repo_root / generator.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
                ).read_bytes()
            )

            written = generator.write_release_tool_call_policy(root)
            self.assertEqual(
                written,
                root / generator.RELEASE_TOOL_CALL_POLICY_PATH,
            )
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_release_tool_call_policy(root),
                    0,
                )

            target = root / "scripts/check_admin_ceremony_evidence.py"
            target.write_bytes(target.read_bytes() + b"\njson.dumps({})\n")
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_release_tool_call_policy(root),
                    1,
                )

    def test_release_tool_call_policy_cli_modes_reject_checksum_options(
        self,
    ) -> None:
        stderr = StringIO()
        with redirect_stdout(StringIO()), redirect_stderr(stderr):
            result = generator.main(
                [
                    "--refresh-release-tool-call-policy",
                    "--check",
                ]
            )
        self.assertEqual(result, 1)
        self.assertIn(
            "call-policy modes cannot be combined",
            stderr.getvalue(),
        )

    def test_canonical_policy_rejects_gitattributes_substitution(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        covered = [
            candidate
            for candidate in generator.DEFAULT_COVERED_PATHS
            if candidate != generator.GIT_ATTRIBUTES_PATH
        ]
        covered.append(Path(".gitignore"))
        self.assertEqual(len(covered), len(generator.DEFAULT_COVERED_PATHS))

        with self.assertRaisesRegex(
            generator.ChecksumError,
            (
                "canonical release checksum coverage policy mismatch: "
                ".*\\.gitattributes"
            ),
        ):
            generator.build_outputs(
                repo_root,
                covered,
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )

    def test_release_tool_source_missing_behavior_is_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            required = Path("scripts/required.py")
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "release-tool checksum closure source is missing",
            ) as raised:
                generator.release_tool_runtime_closure(
                    root,
                    (required,),
                )
            self.assertIsInstance(raised.exception.__cause__, FileNotFoundError)

            optional_root = Path("scripts/root.py")
            write_text(root / optional_root, "import missing_optional_module\n")
            self.assertEqual(
                generator.release_tool_runtime_closure(
                    root,
                    (optional_root,),
                ),
                (optional_root,),
            )

    def test_canonical_build_rejects_each_missing_release_tool_root(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        for path in generator.RELEASE_TOOL_ROOTS:
            with self.subTest(path=path):
                covered = [
                    candidate
                    for candidate in generator.DEFAULT_COVERED_PATHS
                    if candidate != path
                ]
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    re.escape(path.as_posix()),
                ):
                    generator.build_outputs(
                        repo_root,
                        covered,
                        repo_root / generator.DEFAULT_OUTPUT_DIR,
                    )

    def test_canonical_build_and_check_reject_same_cardinality_substitution(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        removed = generator.RELEASE_TOOL_ROOTS[0]
        covered = [
            candidate
            for candidate in generator.DEFAULT_COVERED_PATHS
            if candidate != removed
        ]
        covered.append(Path(".editorconfig"))
        with self.assertRaisesRegex(
            generator.ChecksumError,
            re.escape(removed.as_posix()),
        ):
            generator.build_outputs(
                repo_root,
                covered,
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )

        stderr = StringIO()
        with redirect_stdout(StringIO()), redirect_stderr(stderr):
            result = generator.check_outputs(
                repo_root,
                covered,
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )
        self.assertEqual(result, 1)
        self.assertIn(removed.as_posix(), stderr.getvalue())
        self.assertIn(".editorconfig", stderr.getvalue())

    def test_canonical_build_rejects_focused_test_substitution(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        removed = generator.RELEASE_TOOL_FOCUSED_TESTS[0]
        covered = [
            candidate
            for candidate in generator.DEFAULT_COVERED_PATHS
            if candidate != removed
        ]
        covered.append(Path(".editorconfig"))
        with self.assertRaisesRegex(
            generator.ChecksumError,
            re.escape(removed.as_posix()),
        ):
            generator.build_outputs(
                repo_root,
                covered,
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )

    def test_canonical_build_rejects_transitive_runtime_substitution(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        removed = Path("scripts/check_changelog.py")
        covered = [
            candidate
            for candidate in generator.DEFAULT_COVERED_PATHS
            if candidate != removed
        ]
        covered.append(Path(".editorconfig"))
        with self.assertRaisesRegex(
            generator.ChecksumError,
            re.escape(removed.as_posix()),
        ):
            generator.build_outputs(
                repo_root,
                covered,
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )

    def test_canonical_preflight_rejects_missing_or_symlinked_reviewed_runtime(
        self,
    ) -> None:
        reviewed_paths = list(
            generator.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
        ) + list(generator.RELEASE_TOOL_FOCUSED_TESTS)
        target = Path("scripts/check_changelog.py")
        for mutation in ("missing", "symlink"):
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    for path in reviewed_paths:
                        write_text(root / path, "VALUE = 1\n")
                    target_path = root / target
                    target_path.unlink()
                    if mutation == "symlink":
                        outside = root.parent / f"{root.name}-check-changelog.py"
                        write_text(outside, "VALUE = 1\n")
                        self.addCleanup(outside.unlink)
                        target_path.symlink_to(outside)
                    with mock.patch.object(
                        generator,
                        "DEFAULT_COVERED_PATHS",
                        reviewed_paths,
                    ):
                        with self.assertRaisesRegex(
                            generator.ChecksumError,
                            re.escape(target.as_posix()).replace(
                                "/",
                                r"[\\/]",
                            ),
                        ):
                            generator.build_outputs(
                                root,
                                reviewed_paths,
                                root / generator.DEFAULT_OUTPUT_DIR,
                            )

    def test_canonical_build_rejects_broad_and_duplicate_coverage(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        removed = generator.RELEASE_TOOL_ROOTS[0]
        broad = [
            candidate
            for candidate in generator.DEFAULT_COVERED_PATHS
            if candidate != removed
        ]
        broad.append(Path("scripts"))
        with self.assertRaisesRegex(
            generator.ChecksumError,
            re.escape(removed.as_posix()),
        ):
            generator.build_outputs(
                repo_root,
                broad,
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )
        with self.assertRaisesRegex(
            generator.ChecksumError,
            "duplicates=.*scripts/generate_risk_register.py",
        ):
            generator.build_outputs(
                repo_root,
                list(generator.DEFAULT_COVERED_PATHS)
                + [generator.RELEASE_TOOL_ROOTS[0]],
                repo_root / generator.DEFAULT_OUTPUT_DIR,
            )
        with self.assertRaisesRegex(
            generator.ChecksumError,
            "scripts/check_admin_ceremony_evidence.py",
        ):
            generator.validate_release_tool_checksum_closure(
                repo_root,
                [Path("scripts")],
            )

    def test_custom_subset_requires_explicit_noncanonical_mode_and_output(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = Path("input.txt")
            write_text(root / source, "input\n")
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must use a noncanonical output directory",
            ):
                generator.build_outputs(
                    root,
                    [source],
                    root / generator.DEFAULT_OUTPUT_DIR,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )

            checksum_text, manifest_text = generator.build_outputs(
                root,
                [source],
                root / CUSTOM_OUTPUT_DIR,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            self.assertIn("  input.txt\n", checksum_text)
            manifest = json.loads(manifest_text)
            self.assertEqual(
                manifest["source"]["coverage_policy"],
                generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            self.assertEqual(
                manifest["source"]["output_dir"],
                CUSTOM_OUTPUT_DIR.as_posix(),
            )

    def test_cli_rejects_implicit_custom_subset_and_canonical_output(
        self,
    ) -> None:
        stderr = StringIO()
        with redirect_stderr(stderr):
            result = generator.main(
                ["--covered-path", ".editorconfig"]
            )
        self.assertEqual(result, 1)
        self.assertIn(
            "--covered-path requires --coverage-policy custom-subset",
            stderr.getvalue(),
        )

        stderr = StringIO()
        with redirect_stderr(stderr):
            result = generator.main(
                [
                    "--coverage-policy",
                    generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                    "--covered-path",
                    ".editorconfig",
                ]
            )
        self.assertEqual(result, 1)
        self.assertIn(
            "must use a noncanonical output directory",
            stderr.getvalue(),
        )

    def test_release_tool_closure_rejects_each_missing_runtime_or_test(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        for path in EXPECTED_RELEASE_TOOL_RUNTIME_CLOSURE:
            with self.subTest(kind="runtime", path=path):
                covered = [
                    candidate
                    for candidate in generator.DEFAULT_COVERED_PATHS
                    if candidate != path
                ]
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    re.escape(path.as_posix()),
                ):
                    generator.validate_release_tool_checksum_closure(
                        repo_root,
                        covered,
                    )
        for path in EXPECTED_RELEASE_TOOL_FOCUSED_TESTS:
            with self.subTest(kind="test", path=path):
                covered = [
                    candidate
                    for candidate in generator.DEFAULT_COVERED_PATHS
                    if candidate != path
                ]
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    re.escape(path.as_posix()),
                ):
                    generator.validate_release_tool_checksum_closure(
                        repo_root,
                        covered,
                    )

    def test_release_tool_closure_rejects_hidden_first_party_import(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            for path in generator.REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE:
                source = (
                    "import hidden_release_dependency\n"
                    if path == generator.RELEASE_TOOL_ROOTS[0]
                    else "VALUE = 1\n"
                )
                write_text(root / path, source)
            for path in generator.RELEASE_TOOL_FOCUSED_TESTS:
                write_text(root / path, "VALUE = 1\n")
            write_text(
                root / "scripts/hidden_release_dependency.py",
                "VALUE = 1\n",
            )
            covered = list(generator.RELEASE_TOOL_ROOTS) + list(
                generator.RELEASE_TOOL_FOCUSED_TESTS
            )
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "scripts/hidden_release_dependency.py",
            ), mock.patch.object(
                generator,
                "REVIEWED_RELEASE_TOOL_SNAPSHOT_LOADER_SOURCES",
                {
                    Path("scripts/verify_release_artifacts.py"): (
                        generator.hashlib.sha256(b"VALUE = 1\n").hexdigest(),
                        len(b"VALUE = 1\n"),
                    )
                },
            ):
                generator.validate_release_tool_checksum_closure(root, covered)

    def test_release_tool_import_parser_covers_relative_package_and_dynamic_forms(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(root / "scripts/root.py", "\n".join(
                (
                    "import importlib",
                    "import importlib as il",
                    "import builtins as bi",
                    "import package.submodule",
                    "from package import imported_submodule",
                    "from . import relative_dependency",
                    "from .relative_second import VALUE",
                    'importlib.import_module("dynamic_one")',
                    'il.import_module("dynamic_two")',
                    '__import__("dynamic_four")',
                    'bi.__import__("dynamic_five")',
                    "",
                )
            ))
            write_text(root / "scripts/package/__init__.py", "VALUE = 1\n")
            write_text(root / "scripts/package/submodule.py", "VALUE = 1\n")
            write_text(
                root / "scripts/package/imported_submodule.py",
                "VALUE = 1\n",
            )
            for name in (
                "relative_dependency",
                "relative_second",
                "dynamic_one",
                "dynamic_two",
                "dynamic_four",
                "dynamic_five",
            ):
                write_text(root / f"scripts/{name}.py", "VALUE = 1\n")

            self.assertEqual(
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                ),
                (
                    Path("scripts/dynamic_five.py"),
                    Path("scripts/dynamic_four.py"),
                    Path("scripts/dynamic_one.py"),
                    Path("scripts/dynamic_two.py"),
                    Path("scripts/package/__init__.py"),
                    Path("scripts/package/imported_submodule.py"),
                    Path("scripts/package/submodule.py"),
                    Path("scripts/relative_dependency.py"),
                    Path("scripts/relative_second.py"),
                ),
            )

    def test_release_tool_import_parser_rejects_alternate_loaders(self) -> None:
        cases = (
            (
                "exec literal import",
                'exec("import hidden")\n',
                "alternate loader API exec in scripts/root.py:1",
            ),
            (
                "eval import",
                "eval(\"__import__('hidden')\")\n",
                "alternate loader API eval in scripts/root.py:1",
            ),
            (
                "exec compile",
                'exec(compile("import hidden", "<test>", "exec"))\n',
                "alternate loader API exec in scripts/root.py:1",
            ),
            (
                "runpy run_path",
                "import runpy\nrunpy.run_path('hidden.py')\n",
                "alternate loader API runpy in scripts/root.py:1",
            ),
            (
                "runpy run_module",
                "import runpy\nrunpy.run_module('hidden')\n",
                "alternate loader API runpy in scripts/root.py:1",
            ),
            (
                "importlib metadata entry point",
                "from importlib.metadata import EntryPoint\n"
                "EntryPoint(name='x', value='hidden:VALUE', group='x').load()\n",
                "alternate loader API importlib.metadata in scripts/root.py:1",
            ),
            (
                "aliased importlib metadata",
                "from importlib import metadata as md\n"
                "md.EntryPoint(name='x', value='hidden:VALUE', group='x').load()\n",
                "alternate loader API importlib.metadata in scripts/root.py:1",
            ),
            (
                "importlib resources files",
                "from importlib.resources import files\n"
                "files('hidden')\n",
                "alternate loader API importlib.resources in scripts/root.py:1",
            ),
            (
                "aliased importlib resources",
                "from importlib import resources as res\n"
                "res.files('hidden')\n",
                "alternate loader API importlib.resources in scripts/root.py:1",
            ),
            (
                "ctypes Python import API",
                "import ctypes\n"
                "ctypes.pythonapi.PyImport_ImportModule(b'hidden')\n",
                "alternate loader API ctypes in scripts/root.py:1",
            ),
            (
                "aliased ctypes Python execution API",
                "import ctypes as ffi\n"
                "ffi.pythonapi.PyRun_SimpleString(b'import hidden')\n",
                "alternate loader API ctypes in scripts/root.py:1",
            ),
            (
                "gc object graph import recovery",
                "import gc\n"
                "next(d for d in gc.get_objects() "
                "if isinstance(d, dict) and callable(d.get('__import__')))"
                "['__import__']('hidden')\n",
                "alternate loader API gc in scripts/root.py:1",
            ),
            (
                "aliased gc object graph import recovery",
                "import gc as collector\n"
                "next(d for d in collector.get_objects() "
                "if isinstance(d, dict) and callable(d.get('__import__')))"
                "['__import__']('hidden')\n",
                "alternate loader API gc in scripts/root.py:1",
            ),
            (
                "operator attrgetter",
                "import os, operator\n"
                "operator.attrgetter('__builtins__')(os)"
                "['__import__']('hidden')\n",
                "alternate loader API operator in scripts/root.py:1",
            ),
            (
                "operator itemgetter from-import",
                "import os\nfrom operator import attrgetter, itemgetter\n"
                "itemgetter('__import__')"
                "(attrgetter('__builtins__')(os))('hidden')\n",
                "alternate loader API operator in scripts/root.py:2",
            ),
            (
                "dynamic operator",
                "__import__('operator').attrgetter('__builtins__')"
                "(__import__('os'))['__import__']('hidden')\n",
                (
                    "dynamic import of protected module operator in "
                    "scripts/root.py:1"
                ),
            ),
            (
                "dynamic operator through importlib",
                "import importlib, os\n"
                "importlib.import_module('operator')"
                ".attrgetter('__builtins__')(os)"
                "['__import__']('hidden')\n",
                (
                    "dynamic import of protected module operator in "
                    "scripts/root.py:2"
                ),
            ),
            (
                "pkgutil locator",
                "import pkgutil\n"
                "pkgutil.resolve_name('hidden')\n",
                "alternate loader API pkgutil in scripts/root.py:1",
            ),
            (
                "pydoc locator",
                "import pydoc\n"
                "pydoc.locate('hidden')\n",
                "alternate loader API pydoc in scripts/root.py:1",
            ),
            (
                "pickle global loader",
                "import pickle\n"
                "pickle.loads(b'chidden\\nfoo\\n.')\n",
                "alternate loader API pickle in scripts/root.py:1",
            ),
            (
                "serialization from-import",
                "from shelve import open as open_shelf\n",
                "alternate loader API shelve in scripts/root.py:1",
            ),
            (
                "dynamic locator module",
                "__import__('pkgutil').resolve_name('hidden')\n",
                (
                    "dynamic import of protected module pkgutil in "
                    "scripts/root.py:1"
                ),
            ),
            (
                "dynamic subprocess builtin",
                "import sys\n"
                "__import__('subprocess').run("
                "[sys.executable, 'hidden.py'], check=True)\n",
                (
                    "dynamic import of protected module subprocess in "
                    "scripts/root.py:2"
                ),
            ),
            (
                "dynamic subprocess importlib",
                "import importlib, sys\n"
                "importlib.import_module('subprocess').run("
                "[sys.executable, 'hidden.py'], check=True)\n",
                (
                    "dynamic import of protected module subprocess in "
                    "scripts/root.py:2"
                ),
            ),
            (
                "importlib util loader",
                "import importlib.util\n"
                "spec = importlib.util.spec_from_file_location('hidden', 'hidden.py')\n"
                "module = importlib.util.module_from_spec(spec)\n"
                "spec.loader.exec_module(module)\n",
                "alternate loader API importlib.util in scripts/root.py:1",
            ),
            (
                "importlib machinery loader",
                "import importlib.machinery\n"
                "loader = importlib.machinery.SourceFileLoader('hidden', 'hidden.py')\n"
                "loader.load_module()\n",
                "alternate loader API importlib.machinery in scripts/root.py:1",
            ),
            (
                "importlib bootstrap external loader",
                "from importlib._bootstrap_external import SourceFileLoader\n"
                "loader = SourceFileLoader('hidden', 'scripts/hidden.py')\n"
                "getattr(loader, 'load_module')()\n",
                (
                    "alternate loader API importlib._bootstrap_external in "
                    "scripts/root.py:1"
                ),
            ),
            (
                "importlib bootstrap finder",
                "from importlib._bootstrap import _find_and_load\n"
                "_find_and_load('hidden', None)\n",
                (
                    "alternate loader API importlib._bootstrap in "
                    "scripts/root.py:1"
                ),
            ),
            (
                "builtins namespace dictionary alias",
                "from builtins import __dict__ as namespace\n"
                "namespace['__import__']('hidden')\n",
                "alternate loader API builtins.__dict__ in scripts/root.py:1",
            ),
            (
                "importlib namespace dictionary alias",
                "from importlib import __dict__ as namespace\n"
                "namespace['import_module']('hidden')\n",
                "alternate loader API importlib.__dict__ in scripts/root.py:1",
            ),
            (
                "aliased protected getattr",
                "from builtins import getattr as lookup\n"
                "lookup(__builtins__, '__import__')('hidden')\n",
                "alternate loader API builtins.getattr in scripts/root.py:1",
            ),
            (
                "dynamic loader method getattr",
                "class Loader:\n"
                "    def load_module(self):\n"
                "        return None\n"
                "getattr(Loader(), 'load_module')()\n",
                "alternate loader API load_module in scripts/root.py:4",
            ),
            (
                "builtins compile",
                "import builtins\nbuiltins.compile('x', '<test>', 'eval')\n",
                "alternate loader API builtins.compile in scripts/root.py:2",
            ),
            (
                "builtins alias compile",
                "import builtins as bi\nbi.compile('x', '<test>', 'eval')\n",
                "alternate loader API bi.compile in scripts/root.py:2",
            ),
            (
                "exec assignment escape",
                "loader = exec\nloader('import hidden')\n",
                "alternate loader API exec in scripts/root.py:1",
            ),
            (
                "eval container escape",
                "loaders = [eval]\nloaders[0](\"__import__('hidden')\")\n",
                "alternate loader API eval in scripts/root.py:1",
            ),
            (
                "compile argument escape",
                "consume(compile)\n",
                "alternate loader API compile in scripts/root.py:1",
            ),
            (
                "globals namespace lookup",
                "globals()['__builtins__']['__import__']('hidden')\n",
                "alternate loader API globals in scripts/root.py:1",
            ),
            (
                "locals namespace lookup",
                "locals()['__builtins__']['__import__']('hidden')\n",
                "alternate loader API locals in scripts/root.py:1",
            ),
            (
                "vars namespace lookup",
                "vars(__builtins__)['__import__']('hidden')\n",
                "alternate loader API vars in scripts/root.py:1",
            ),
            (
                "nonliteral getattr",
                "getattr(object(), ATTRIBUTE)\n",
                "alternate loader API non-literal getattr in scripts/root.py:1",
            ),
        )
        for label, source, diagnostic in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(diagnostic),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_allows_unrelated_compile_attributes(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/root.py",
                "import re\n"
                "re.compile('x')\n"
                "class Helper:\n"
                "    def compile(self, value):\n"
                "        return value\n"
                "Helper().compile('x')\n",
            )
            self.assertEqual(
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                ),
                (),
            )

    def test_release_tool_import_parser_rejects_fromlists_and_wildcards(
        self,
    ) -> None:
        cases = (
            (
                "positional non-empty fromlist",
                "__import__('package', {}, {}, ('hidden',))\n",
                "non-empty or dynamic __import__ fromlist",
            ),
            (
                "keyword non-empty fromlist",
                "__import__('package', fromlist=['hidden'])\n",
                "non-empty or dynamic __import__ fromlist",
            ),
            (
                "dynamic fromlist",
                "__import__('package', fromlist=REQUESTED)\n",
                "non-empty or dynamic __import__ fromlist",
            ),
            (
                "expanded keyword arguments",
                "__import__('package', **OPTIONS)\n",
                "expanded dynamic-import keyword arguments",
            ),
            (
                "repo-local wildcard import",
                "from package import *\n",
                "alternate loader API wildcard import",
            ),
            (
                "external wildcard import",
                "from os import *\n",
                "alternate loader API wildcard import",
            ),
        )
        for label, source, diagnostic in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/package/__init__.py", "__all__ = []\n")
                    write_text(root / "scripts/package/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(diagnostic),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/root.py",
                "__import__('dependency', fromlist=())\n",
            )
            write_text(root / "scripts/dependency.py", "VALUE = 1\n")
            self.assertEqual(
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                ),
                (Path("scripts/dependency.py"),),
            )

    def test_release_tool_import_parser_rejects_sys_module_registry(
        self,
    ) -> None:
        cases = (
            "import sys\nsys.modules['builtins'].__import__('hidden')\n",
            "import sys\nsys.modules.get('builtins').__import__('hidden')\n",
            "import sys\nsys.modules['importlib'].import_module('hidden')\n",
            "import sys as system\ngetattr(system, 'modules')['builtins']\n",
            "from sys import modules as registry\nregistry['builtins']\n",
            "import sys\nregistry = sys\nregistry.modules['builtins']\n",
            "__import__('sys').modules['builtins']\n",
            "import os\nos.sys.modules['builtins'].__import__('hidden')\n",
            "import pathlib\npathlib.os.sys.modules['builtins'].__import__('hidden')\n",
            "import os\nos.__builtins__['__import__']('hidden')\n",
            "import os\nos.__dict__['sys'].modules['builtins'].__import__('hidden')\n",
            "import pathlib\npathlib.__builtins__['__import__']('hidden')\n",
            "import os\nos.__getattribute__('__builtins__')['__import__']('hidden')\n",
            "import pkgutil\npkgutil.importlib.import_module('hidden')\n",
            "import inspect\ninspect.importlib.import_module('hidden')\n",
            "import inspect\ninspect.builtins.__import__('hidden')\n",
            "import os\ngetattr(os, '__builtins__')['__import__']('hidden')\n",
            "import pkgutil\ngetattr(pkgutil, 'importlib').import_module('hidden')\n",
        )
        for source in cases:
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "(alternate loader API (inspect|sys|pkgutil|modules|__builtins__|"
                        "__dict__|__getattribute__|__import__|import_module|"
                        "load_module)|sys module alias escape|"
                        "dynamic import of protected module sys)",
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/root.py",
                "import sys\nsys.stderr.write('')\n"
                "getattr(object(), 'safe_attribute', None)\n",
            )
            self.assertEqual(
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                ),
                (),
            )

    def test_release_tool_import_parser_rejects_frame_introspection(
        self,
    ) -> None:
        cases = (
            (
                "sys frame",
                "import sys\n"
                "sys._getframe().f_builtins['__import__']('hidden')\n",
                "alternate loader API f_builtins",
            ),
            (
                "sys frame accessor",
                "import sys\nsys._getframe()\n",
                "alternate loader API _getframe",
            ),
            (
                "inspect frame",
                "import inspect\n"
                "inspect.currentframe().f_builtins['__import__']('hidden')\n",
                "alternate loader API inspect",
            ),
            (
                "frame globals",
                "frame.f_globals['__builtins__']['__import__']('hidden')\n",
                "alternate loader API f_globals",
            ),
            (
                "traceback frame",
                "traceback.tb_frame.f_builtins['__import__']('hidden')\n",
                "alternate loader API f_builtins",
            ),
            (
                "function globals",
                "(lambda: None).__globals__['__builtins__']"
                "['__import__']('hidden')\n",
                "alternate loader API __globals__",
            ),
            (
                "nested function globals",
                "holder = {'load': (lambda: None)}\n"
                "holder['load'].__globals__['__builtins__']"
                "['__import__']('hidden')\n",
                "alternate loader API __globals__",
            ),
            (
                "returned function globals",
                "def make_loader():\n"
                "    return lambda: None\n"
                "make_loader().__globals__['__builtins__']"
                "['__import__']('hidden')\n",
                "alternate loader API __globals__",
            ),
            (
                "bound method globals",
                "class Loader:\n"
                "    def load(self):\n"
                "        return None\n"
                "Loader().load.__func__.__globals__['__builtins__']"
                "['__import__']('hidden')\n",
                "alternate loader API __globals__",
            ),
            (
                "getattr function globals",
                "getattr(lambda: None, '__globals__')['__builtins__']"
                "['__import__']('hidden')\n",
                "alternate loader API __globals__",
            ),
            (
                "getattr returned function globals",
                "def make_loader():\n"
                "    return lambda: None\n"
                "getattr(make_loader(), '__globals__')['__builtins__']"
                "['__import__']('hidden')\n",
                "alternate loader API __globals__",
            ),
            (
                "getattr generator frame builtins",
                "frame = getattr((_ for _ in ()), 'gi_frame')\n"
                "getattr(frame, 'f_builtins')['__import__']('hidden')\n",
                "alternate loader API gi_frame",
            ),
            (
                "from sys frame accessor",
                "from sys import _getframe\n"
                "getattr(_getframe(), 'f_builtins')"
                "['__import__']('hidden')\n",
                "alternate loader API sys._getframe",
            ),
            (
                "environment-selected breakpoint import",
                "import os\n"
                "os.environ['PYTHONBREAKPOINT'] = 'hidden.VALUE'\n"
                "breakpoint()\n",
                "alternate loader API breakpoint",
            ),
            (
                "sys breakpointhook",
                "import sys\nsys.breakpointhook()\n",
                "alternate loader API breakpointhook",
            ),
            (
                "from sys breakpointhook",
                "from sys import breakpointhook\nbreakpointhook()\n",
                "alternate loader API sys.breakpointhook",
            ),
            (
                "literal getattr breakpoint",
                "getattr(__builtins__, 'breakpoint')()\n",
                "getattr access on protected importer module alias __builtins__",
            ),
            (
                "literal getattr breakpointhook",
                "import sys\ngetattr(sys, 'breakpointhook')()\n",
                "sys module alias escape for sys",
            ),
            (
                "builtin help import",
                "help('hidden')\n",
                "alternate loader API help",
            ),
            (
                "from builtins help import",
                "from builtins import help as load_help\nload_help('hidden')\n",
                "alternate loader API builtins.help",
            ),
            (
                "literal getattr help",
                "getattr(__builtins__, 'help')('hidden')\n",
                "getattr access on protected importer module alias __builtins__",
            ),
        )
        for label, source, diagnostic in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(diagnostic),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

        for attribute_name in (
            "__builtins__",
            "__dict__",
            "__globals__",
            "__getattribute__",
            "_getframe",
            "ag_frame",
            "breakpoint",
            "breakpointhook",
            "cr_frame",
            "currentframe",
            "discover",
            "f_builtins",
            "f_globals",
            "f_locals",
            "gi_frame",
            "help",
            "loadTestsFromName",
            "loadTestsFromNames",
            "modules",
            "tb_frame",
        ):
            with self.subTest(literal_getattr=attribute_name):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(
                        root / "scripts/root.py",
                        f"getattr(object(), {attribute_name!r})\n",
                    )
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(
                            f"alternate loader API {attribute_name}"
                        ),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_unittest_name_loaders(
        self,
    ) -> None:
        callable_shapes = (
            "unittest.TestLoader().loadTestsFromName",
            "unittest.TestLoader().loadTestsFromNames",
            "unittest.defaultTestLoader.loadTestsFromName",
            "unittest.defaultTestLoader.discover",
        )
        source_templates = (
            "import unittest\n{callable}('hidden')\n",
            "import unittest\nload = {callable}\n",
            "import unittest\nloads = [{callable}]\n",
            "import unittest\nconsume({callable})\n",
            "import unittest\ndef load():\n    return {callable}\n",
            "import unittest\nload = {callable} if ENABLED else None\n",
        )
        for callable_shape in callable_shapes:
            expected_name = callable_shape.rsplit(".", maxsplit=1)[-1]
            for source_template in source_templates:
                source = source_template.format(callable=callable_shape)
                with self.subTest(
                    callable_shape=callable_shape,
                    source=source,
                ):
                    with tempfile.TemporaryDirectory() as temp_dir:
                        root = Path(temp_dir)
                        write_text(root / "scripts/root.py", source)
                        write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                        with self.assertRaisesRegex(
                            generator.ChecksumError,
                            re.escape(
                                f"alternate loader API {expected_name}"
                            ),
                        ):
                            generator._repo_local_script_imports(
                                root,
                                Path("scripts/root.py"),
                            )

        for method_name in (
            "loadTestsFromName",
            "loadTestsFromNames",
            "discover",
        ):
            with self.subTest(literal_getattr=method_name):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(
                        root / "scripts/root.py",
                        "import unittest\n"
                        f"getattr(unittest.defaultTestLoader, {method_name!r})"
                        "('hidden')\n",
                    )
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(
                            f"alternate loader API {method_name}"
                        ),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_builtin_name_escapes(
        self,
    ) -> None:
        source_templates = (
            "{name}('payload')\n",
            "loader = {name}\n",
            "loaders = [{name}]\n",
            "loaders = ({name},)\n",
            "loaders = {{'load': {name}}}\n",
            "consume({name})\n",
            "def loader():\n    return {name}\n",
            "loader = lambda: {name}\n",
            "loader = {name} if ENABLED else None\n",
        )
        for name in ("exec", "eval", "compile", "breakpoint", "help"):
            for source_template in source_templates:
                source = source_template.format(name=name)
                with self.subTest(name=name, source=source):
                    with tempfile.TemporaryDirectory() as temp_dir:
                        root = Path(temp_dir)
                        write_text(root / "scripts/root.py", source)
                        with self.assertRaisesRegex(
                            generator.ChecksumError,
                            re.escape(
                                "release-tool checksum closure forbids "
                                f"alternate loader API {name} in "
                                "scripts/root.py:"
                            ),
                        ):
                            generator._repo_local_script_imports(
                                root,
                                Path("scripts/root.py"),
                            )

    def test_release_tool_import_parser_rejects_getattr_callable_escapes(
        self,
    ) -> None:
        cases = (
            "lookup = getattr\n",
            "lookups = [getattr]\n",
            "lookups = (getattr,)\n",
            "consume(getattr)\n",
            "def lookup():\n    return getattr\n",
            "lookup = lambda: getattr\n",
            "lookup = getattr if ENABLED else None\n",
            "(lookup := getattr)\n",
            "def lookup(getattr):\n    return getattr\n",
            "getattr = object()\n",
        )
        for source in cases:
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "alternate loader API getattr "
                        "(callable escape|rebinding)",
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_python_subprocess_targets(
        self,
    ) -> None:
        cases = (
            (
                "sys executable",
                "import subprocess, sys\n"
                "subprocess.run([sys.executable, 'hidden.py'], check=True)\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "literal interpreter",
                "import subprocess\n"
                "subprocess.run(['python', 'hidden.py'], check=True)\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "local Python argument",
                "import subprocess\n"
                "subprocess.run(['tool', 'scripts/hidden.py'], check=True)\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "shell execution",
                "import subprocess\n"
                "subprocess.run('tool --version', shell=True)\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "executable override",
                "import subprocess\n"
                "subprocess.run(['tool'], executable='python')\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "module escape",
                "import subprocess\nrunner = subprocess\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "callable escape",
                "import subprocess\nrunner = subprocess.run\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "unsupported process API",
                "import subprocess\nsubprocess.Popen(['tool'])\n",
                "forbids subprocess outside exact reviewed sources",
            ),
            (
                "from-import",
                "from subprocess import run\nrun(['tool'])\n",
                "alternate loader API subprocess callable import",
            ),
        )
        for label, source, diagnostic in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(diagnostic),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_subprocess_sources_are_exactly_bound(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        expected_paths = {
            Path("scripts/check_changelog.py"),
            Path("scripts/check_record_family_authorization.py"),
            Path("scripts/check_slither_baseline.py"),
        }
        self.assertEqual(
            set(generator.REVIEWED_RELEASE_TOOL_SUBPROCESS_SOURCES),
            expected_paths,
        )
        for relative_path, (expected_sha256, expected_size) in sorted(
            generator.REVIEWED_RELEASE_TOOL_SUBPROCESS_SOURCES.items()
        ):
            with self.subTest(relative_path=relative_path.as_posix()):
                source_bytes = (repo_root / relative_path).read_bytes()
                self.assertEqual(
                    generator.hashlib.sha256(source_bytes).hexdigest(),
                    expected_sha256,
                )
                self.assertEqual(len(source_bytes), expected_size)
                generator._repo_local_script_imports(repo_root, relative_path)

                with tempfile.TemporaryDirectory() as temp_dir:
                    temporary_root = Path(temp_dir)
                    temporary_source = temporary_root / relative_path
                    temporary_source.parent.mkdir(parents=True, exist_ok=True)
                    temporary_source.write_bytes(source_bytes + b"# drift\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "subprocess source differs from its exact reviewed binding",
                    ):
                        generator._repo_local_script_imports(
                            temporary_root,
                            relative_path,
                        )

    def test_release_tool_snapshot_loader_source_is_exactly_bound(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = Path("scripts/verify_release_artifacts.py")
        self.assertEqual(
            set(generator.REVIEWED_RELEASE_TOOL_SNAPSHOT_LOADER_SOURCES),
            {relative_path},
        )
        expected_sha256, expected_size = (
            generator.REVIEWED_RELEASE_TOOL_SNAPSHOT_LOADER_SOURCES[
                relative_path
            ]
        )
        source_bytes = (repo_root / relative_path).read_bytes()
        self.assertEqual(
            generator.hashlib.sha256(source_bytes).hexdigest(),
            expected_sha256,
        )
        self.assertEqual(len(source_bytes), expected_size)
        generator._repo_local_script_imports(repo_root, relative_path)

        with tempfile.TemporaryDirectory() as temp_dir:
            temporary_root = Path(temp_dir)
            temporary_source = temporary_root / relative_path
            temporary_source.parent.mkdir(parents=True, exist_ok=True)
            temporary_source.write_bytes(source_bytes + b"# drift\n")
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "snapshot-loader source differs from its exact reviewed binding",
            ):
                generator._repo_local_script_imports(
                    temporary_root,
                    relative_path,
                )

    def test_release_tool_import_parser_rejects_importer_callable_aliases(
        self,
    ) -> None:
        cases = (
            (
                "importlib assignment",
                "import importlib\n"
                "load = importlib.import_module\n"
                'load("hidden")\n',
                "importer callable escape from importlib.import_module",
            ),
            (
                "__import__ assignment",
                "load = __import__\n"
                'load("hidden")\n',
                "importer callable escape from __import__",
            ),
            (
                "importlib from-import alias",
                "from importlib import import_module as load\n"
                'load("hidden")\n',
                "importer callable alias import importlib.import_module",
            ),
            (
                "builtins from-import alias",
                "from builtins import __import__ as load\n"
                'load("hidden")\n',
                "importer callable alias import builtins.__import__",
            ),
            (
                "getattr",
                "import importlib\n"
                'getattr(importlib, "import_module")("hidden")\n',
                "getattr access on protected importer module alias",
            ),
            (
                "nonliteral getattr",
                "import importlib\n"
                "getattr(importlib, ATTRIBUTE)(\"hidden\")\n",
                "getattr access on protected importer module alias",
            ),
            (
                "chained assignment",
                "import importlib\n"
                "first = second = importlib.import_module\n",
                "importer callable escape from importlib.import_module",
            ),
            (
                "annotated assignment",
                "load: object = __import__\n",
                "importer callable escape from __import__",
            ),
            (
                "named expression",
                "import importlib\n"
                "(load := importlib.import_module)\n",
                "importer callable escape from importlib.import_module",
            ),
            (
                "list escape",
                "import importlib\n"
                "loaders = [importlib.import_module]\n"
                'loaders[0]("hidden")\n',
                "importer callable escape from importlib.import_module",
            ),
            (
                "tuple escape",
                "loaders = (__import__,)\n",
                "importer callable escape from __import__",
            ),
            (
                "return escape",
                "import importlib\n"
                "def loader():\n"
                "    return importlib.import_module\n",
                "importer callable escape from importlib.import_module",
            ),
            (
                "dict escape",
                "loaders = {'load': __import__}\n",
                "importer callable escape from __import__",
            ),
            (
                "set escape",
                "loaders = {__import__}\n",
                "importer callable escape from __import__",
            ),
            (
                "yield escape",
                "def loader():\n"
                "    yield __import__\n",
                "importer callable escape from __import__",
            ),
            (
                "lambda escape",
                "import importlib\n"
                "loader = lambda: importlib.import_module\n",
                "importer callable escape from importlib.import_module",
            ),
            (
                "argument escape",
                "consume(__import__)\n",
                "importer callable escape from __import__",
            ),
            (
                "conditional escape",
                "loader = __import__ if ENABLED else None\n",
                "importer callable escape from __import__",
            ),
            (
                "subscript escape",
                "loader = (__import__,)[0]\n",
                "importer callable escape from __import__",
            ),
        )
        for label, source, diagnostic in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        re.escape(diagnostic),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_protected_importer_alias_getattr(
        self,
    ) -> None:
        cases = (
            (
                "direct nested call",
                "import builtins\n"
                "getattr(builtins, '__import__')('scripts.hidden')\n",
            ),
            (
                "escaped callable",
                "import builtins\n"
                "loader = getattr(builtins, '__import__')\n"
                "loader('scripts.hidden')\n",
            ),
            (
                "module alias",
                "import builtins as bi\n"
                "getattr(bi, '__import__')('scripts.hidden')\n",
            ),
            (
                "nonliteral attribute",
                "import builtins\n"
                "getattr(builtins, ATTRIBUTE)('scripts.hidden')\n",
            ),
            (
                "exec",
                "import builtins\n"
                "getattr(builtins, 'exec')('import scripts.hidden')\n",
            ),
            (
                "eval",
                "import builtins\n"
                "getattr(builtins, 'eval')"
                "(\"__import__('scripts.hidden')\")\n",
            ),
            (
                "compile",
                "import builtins\n"
                "getattr(builtins, 'compile')"
                "(\"import scripts.hidden\", '<test>', 'exec')\n",
            ),
            (
                "unrelated literal",
                "import builtins\n"
                "getattr(builtins, 'len')([])\n",
            ),
            (
                "importlib unrelated literal",
                "import importlib\n"
                "getattr(importlib, 'resources')\n",
            ),
            (
                "implicit builtins namespace",
                "getattr(__builtins__, '__import__')('scripts.hidden')\n",
            ),
        )
        for label, source in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        (
                            "getattr access on protected importer module alias"
                        ),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_nested_importer_getattr(
        self,
    ) -> None:
        cases = (
            (
                "nested importlib",
                "importlib",
                "getattr(__import__('importlib'), 'import_module')"
                "('scripts.hidden')\n",
            ),
            (
                "nested builtins",
                "builtins",
                "getattr(__import__('builtins'), '__import__')"
                "('scripts.hidden')\n",
            ),
            (
                "assigned builtins",
                "builtins",
                "b = __import__('builtins')\n"
                "b.__import__('scripts.hidden')\n",
            ),
            (
                "assigned importlib",
                "importlib",
                "il = __import__('importlib')\n"
                "il.import_module('scripts.hidden')\n",
            ),
            (
                "assigned importlib descendant",
                "importlib.resources",
                "il = __import__('importlib.resources')\n"
                "il.import_module('scripts.hidden')\n",
            ),
        )
        for label, module_name, source in cases:
            with self.subTest(label=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        (
                            f"dynamic import of protected module {module_name}"
                        ),
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_module_alias_rebinding(
        self,
    ) -> None:
        cases = (
            "import importlib\nimportlib = object()\n",
            "import importlib as il\ndef f(il):\n    return il\n",
            "import builtins\nclass builtins:\n    pass\n",
        )
        for source in cases:
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "importer module alias rebinding",
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_rejects_module_object_escapes(
        self,
    ) -> None:
        cases = (
            "import importlib\nil = importlib\nil.import_module('hidden')\n",
            "import importlib\n[importlib][0].import_module('hidden')\n",
            "import builtins\nb = builtins\nb.__import__('hidden')\n",
            "import importlib\nmodules = (importlib,)\n",
            "import importlib\nmodules = {'loader': importlib}\n",
            "import importlib\nmodules = {importlib}\n",
            "import importlib\nconsume(importlib)\n",
            "import importlib\ndef f():\n    return importlib\n",
            "import importlib\ndef f():\n    yield importlib\n",
            "import importlib\nf = lambda: importlib\n",
            "import importlib\nmodule = importlib if ENABLED else None\n",
            "import importlib\nmodule = [importlib][0]\n",
            "import importlib\nholder.loader = importlib\n",
            "import importlib\nfirst = second = importlib\n",
            "import importlib\nmodule: object = importlib\n",
            "import importlib\n(module := importlib)\n",
        )
        for source in cases:
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    write_text(root / "scripts/root.py", source)
                    write_text(root / "scripts/hidden.py", "VALUE = 1\n")
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "importer module alias escape",
                    ):
                        generator._repo_local_script_imports(
                            root,
                            Path("scripts/root.py"),
                        )

    def test_release_tool_import_parser_applies_package_precedence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(root / "scripts/root.py", "import package\n")
            write_text(root / "scripts/package.py", "VALUE = 'module'\n")
            write_text(
                root / "scripts/package/__init__.py",
                "VALUE = 'package'\n",
            )
            self.assertEqual(
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                ),
                (Path("scripts/package/__init__.py"),),
            )

    def test_release_tool_import_parser_includes_scripts_package_init_chain(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/root.py",
                "import scripts.package.submodule\n",
            )
            write_text(root / "scripts/__init__.py", "VALUE = 1\n")
            write_text(root / "scripts/package/__init__.py", "VALUE = 1\n")
            write_text(
                root / "scripts/package/submodule.py",
                "VALUE = 1\n",
            )
            self.assertEqual(
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                ),
                (
                    Path("scripts/__init__.py"),
                    Path("scripts/package/__init__.py"),
                    Path("scripts/package/submodule.py"),
                ),
            )

    def test_release_tool_import_parser_rejects_nonliteral_dynamic_imports(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/root.py",
                "import importlib\nimportlib.import_module(MODULE_NAME)\n",
            )
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "requires a string-literal dynamic import.*scripts/root.py:2",
            ):
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                )

    def test_release_tool_import_parser_rejects_relative_dynamic_imports(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(
                root / "scripts/root.py",
                '__import__("hidden", None, None, [], 1)\n',
            )
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "does not support relative dynamic imports.*scripts/root.py:1",
            ):
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                )

    def test_release_tool_import_parser_rejects_outside_and_symlink_sources(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            outside = root.parent / f"{root.name}-outside.py"
            write_text(outside, "VALUE = 1\n")
            self.addCleanup(outside.unlink)
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must stay below scripts",
            ):
                generator._repo_local_script_imports(
                    root,
                    Path("../outside.py"),
                )

            source_link = root / "scripts/root.py"
            source_link.parent.mkdir(parents=True)
            source_link.symlink_to(outside)
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must not include symlinks or reparse points",
            ):
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                )

    def test_release_tool_import_parser_rejects_symlinked_package_init(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            outside = root.parent / f"{root.name}-package-init.py"
            write_text(outside, "VALUE = 1\n")
            self.addCleanup(outside.unlink)
            write_text(root / "scripts/root.py", "import package\n")
            package_init = root / "scripts/package/__init__.py"
            package_init.parent.mkdir(parents=True)
            package_init.symlink_to(outside)
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must not include symlinks or reparse points",
            ):
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                )

    def test_release_tool_import_parser_rejects_dangling_import_source(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_text(root / "scripts/root.py", "import hidden\n")
            dangling = root / "scripts/hidden.py"
            try:
                dangling.symlink_to(root / "missing-hidden.py")
            except OSError as exc:
                self.skipTest(f"file symlink creation unavailable: {exc}")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must not include symlinks or reparse points",
            ):
                generator._repo_local_script_imports(
                    root,
                    Path("scripts/root.py"),
                )

    def test_check_mode_rejects_mutated_release_tool_after_bundle_creation(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            required_path = Path(
                "scripts/generate_bytecode_release_proof.py"
            )
            output_dir = root / CUSTOM_OUTPUT_DIR
            write_text(root / required_path, "VALUE = 1\n")
            generator.write_outputs(
                root,
                [required_path],
                output_dir,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            write_text(root / required_path, "VALUE = 2\n")
            stderr = StringIO()
            with redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [required_path],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )
            self.assertEqual(result, 1)
            self.assertIn(
                "hash mismatch for scripts/generate_bytecode_release_proof.py",
                stderr.getvalue(),
            )

    def test_complete_governed_parameter_references_cover_every_reference_shape(
        self,
    ) -> None:
        inventory = {
            "genesis_profile": {
                "path": "release-artifacts/genesis-deployment-profile.json",
                "sha256": "0" * 64,
            },
            "candidate_binding": {
                "status": "complete",
                "candidate_artifact_path": "release-artifacts/candidate.json",
                "candidate_artifact_sha256": "1" * 64,
                "host_bindings": [
                    {
                        "source_verification_binding": {
                            "path": (
                                "release-artifacts/latest/"
                                "source-verification-inputs.json"
                            ),
                            "sha256": "4" * 64,
                        }
                    }
                ],
            },
            "parameters": [
                {
                    "measurement_evidence": {
                        "status": "complete",
                        "path": "release-artifacts/evidence/measurement.json",
                        "sha256": "2" * 64,
                    },
                    "fixed_stipend_compatibility": {
                        "status": "complete",
                        "evidence_path": (
                            "release-artifacts/evidence/fixed-stipend.json"
                        ),
                        "evidence_sha256": "3" * 64,
                    },
                }
            ],
        }

        self.assertEqual(
            generator.complete_governed_parameter_references(inventory),
            [
                (
                    Path(
                        "release-artifacts/genesis-deployment-profile.json"
                    ),
                    "0" * 64,
                    "genesis_profile",
                ),
                (
                    Path("release-artifacts/candidate.json"),
                    "1" * 64,
                    "candidate_binding",
                ),
                (
                    Path(
                        "release-artifacts/latest/"
                        "source-verification-inputs.json"
                    ),
                    "4" * 64,
                    (
                        "candidate_binding.host_bindings[0]"
                        ".source_verification_binding"
                    ),
                ),
                (
                    Path("release-artifacts/evidence/measurement.json"),
                    "2" * 64,
                    "parameters[0].measurement_evidence",
                ),
                (
                    Path(
                        "release-artifacts/evidence/fixed-stipend.json"
                    ),
                    "3" * 64,
                    "parameters[0].fixed_stipend_compatibility",
                ),
            ],
        )

    def test_checksum_outputs_include_complete_governed_parameter_references(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            inventory_path = (
                root
                / generator.governed_parameter_inventory_checker.DEFAULT_INVENTORY
            )
            candidate_path = root / "release-artifacts/candidate.json"
            genesis_profile_path = (
                root / "release-artifacts/genesis-deployment-profile.json"
            )
            source_verification_path = (
                root
                / "release-artifacts/latest/source-verification-inputs.json"
            )
            measurement_path = (
                root / "release-artifacts/evidence/measurement.json"
            )
            fixed_path = (
                root / "release-artifacts/evidence/fixed-stipend.json"
            )
            for path, content in (
                (inventory_path, "{}\n"),
                (candidate_path, '{"candidate":true}\n'),
                (genesis_profile_path, '{"profile":true}\n'),
                (
                    source_verification_path,
                    '{"source_verification":true}\n',
                ),
                (measurement_path, '{"measurement":true}\n'),
                (fixed_path, '{"fixed_stipend":true}\n'),
            ):
                write_text(path, content)

            inventory = {
                "genesis_profile": {
                    "path": (
                        "release-artifacts/genesis-deployment-profile.json"
                    ),
                    "sha256": generator.file_sha256(
                        genesis_profile_path
                    ).removeprefix("sha256:"),
                },
                "candidate_binding": {
                    "status": "complete",
                    "candidate_artifact_path": (
                        "release-artifacts/candidate.json"
                    ),
                    "candidate_artifact_sha256": generator.file_sha256(
                        candidate_path
                    ).removeprefix("sha256:"),
                    "host_bindings": [
                        {
                            "source_verification_binding": {
                                "path": (
                                    "release-artifacts/latest/"
                                    "source-verification-inputs.json"
                                ),
                                "sha256": generator.file_sha256(
                                    source_verification_path
                                ).removeprefix("sha256:"),
                            }
                        }
                    ],
                },
                "parameters": [
                    {
                        "measurement_evidence": {
                            "status": "complete",
                            "path": (
                                "release-artifacts/evidence/measurement.json"
                            ),
                            "sha256": generator.file_sha256(
                                measurement_path
                            ).removeprefix("sha256:"),
                        },
                        "fixed_stipend_compatibility": {
                            "status": "complete",
                            "evidence_path": (
                                "release-artifacts/evidence/fixed-stipend.json"
                            ),
                            "evidence_sha256": generator.file_sha256(
                                fixed_path
                            ).removeprefix("sha256:"),
                        },
                    }
                ],
            }
            with mock.patch.object(
                generator.governed_parameter_inventory_checker,
                "validate_inventory",
                return_value=inventory,
            ):
                checksum_text, manifest_text = generator.build_outputs(
                    root,
                    [
                        generator.governed_parameter_inventory_checker.DEFAULT_INVENTORY
                    ],
                    root / CUSTOM_OUTPUT_DIR,
                    coverage_policy=(
                        generator.CUSTOM_SUBSET_COVERAGE_POLICY
                    ),
                )

            checksum_paths = {
                path
                for _digest, path in generator.parse_checksum_file(checksum_text)
            }
            self.assertEqual(
                checksum_paths,
                {
                    "release-artifacts/governed-parameter-inventory.json",
                    "release-artifacts/genesis-deployment-profile.json",
                    "release-artifacts/candidate.json",
                    (
                        "release-artifacts/latest/"
                        "source-verification-inputs.json"
                    ),
                    "release-artifacts/evidence/measurement.json",
                    "release-artifacts/evidence/fixed-stipend.json",
                },
            )
            manifest = json.loads(manifest_text)
            self.assertEqual(
                {row["path"] for row in manifest["files"]},
                checksum_paths,
            )

    def test_checksum_generation_rejects_semantically_invalid_inventory(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            inventory_path = (
                root
                / generator.governed_parameter_inventory_checker.DEFAULT_INVENTORY
            )
            write_text(inventory_path, "{}\n")
            with mock.patch.object(
                generator.governed_parameter_inventory_checker,
                "validate_inventory",
                side_effect=(
                    generator.governed_parameter_inventory_checker.GovernedParameterInventoryError(
                        "inventory.status must be 'planning'"
                    )
                ),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "inventory.status must be 'planning'",
                ):
                    generator.build_outputs(
                        root,
                        [
                            generator.governed_parameter_inventory_checker.DEFAULT_INVENTORY
                        ],
                        root / CUSTOM_OUTPUT_DIR,
                        coverage_policy=(
                            generator.CUSTOM_SUBSET_COVERAGE_POLICY
                        ),
                    )

    def test_governed_parameter_references_cannot_escape_repository(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            invalid_paths = (
                Path("../outside.json"),
                Path("/Windows/win.ini"),
                Path("C:Windows/win.ini"),
            )
            for path in invalid_paths:
                with self.subTest(path=str(path)):
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "must stay inside the repository",
                    ):
                        generator.resolve_governed_parameter_reference(
                            root,
                            path,
                            "candidate_binding",
                        )

            outside = root.parent / f"{root.name}-outside"
            outside.mkdir()
            self.addCleanup(outside.rmdir)
            link = root / "evidence-link"
            link.symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must not include symlinks",
            ):
                generator.resolve_governed_parameter_reference(
                    root,
                    Path("evidence-link/evidence.json"),
                    "parameters[0].measurement_evidence",
                )

    def assert_committed_checksums_cover(self, expected_paths: set[Path]) -> None:
        """Assert policy and both committed checksum outputs bind current files."""

        repo_root = SCRIPT_PATH.parent.parent
        configured_paths = set(generator.DEFAULT_COVERED_PATHS)
        for path in sorted(expected_paths):
            self.assertTrue(
                path in configured_paths
                or any(
                    configured in path.parents
                    and (repo_root / configured).is_dir()
                    for configured in configured_paths
                ),
                f"{path.as_posix()} is not covered by DEFAULT_COVERED_PATHS",
            )

        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            relative_path: digest
            for digest, relative_path in generator.parse_checksum_file(checksum_text)
        }
        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}

        for path in sorted(expected_paths):
            relative_path = path.as_posix()
            absolute_path = repo_root / path
            expected_hash = generator.file_sha256(absolute_path)
            if relative_path not in checksum_entries:
                self.fail(f"SHA256SUMS missing required path {relative_path}")
            self.assertEqual(
                checksum_entries[relative_path],
                expected_hash.removeprefix("sha256:"),
                f"SHA256SUMS digest drift for {relative_path}",
            )
            if relative_path not in manifest_entries:
                self.fail(
                    f"release-checksums.json missing required path {relative_path}"
                )
            self.assertEqual(
                manifest_entries[relative_path]["sha256"],
                expected_hash,
                f"release-checksums.json digest drift for {relative_path}",
            )
            self.assertEqual(
                manifest_entries[relative_path]["size_bytes"],
                absolute_path.stat().st_size,
                f"release-checksums.json size drift for {relative_path}",
            )

    def test_committed_checksums_cover_release_tool_trust_closure(self) -> None:
        expected_paths = set(EXPECTED_RELEASE_TOOL_RUNTIME_CLOSURE) | set(
            EXPECTED_RELEASE_TOOL_FOCUSED_TESTS
        )
        self.assert_committed_checksums_cover(expected_paths)
        repo_root = SCRIPT_PATH.parent.parent
        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        checksum_text = (
            repo_root
            / generator.DEFAULT_OUTPUT_DIR
            / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        self.assertEqual(len(manifest["source"]["covered_paths"]), 286)
        self.assertEqual(len(manifest["files"]), 462)
        self.assertEqual(
            len(generator.parse_checksum_file(checksum_text)),
            462,
        )

    def test_committed_checksums_bind_risk_size_checker(self) -> None:
        self.assert_committed_checksums_cover(
            {Path("scripts/check_contract_size_budget.py")}
        )

    def test_committed_checksums_cover_deployment_plan_materializer(self) -> None:
        expected_paths = {
            Path("scripts/materialize_canonical_deployment_plan.py"),
            Path("scripts/test_materialize_canonical_deployment_plan.py"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_committed_checksums_cover_post_entropy_completion_gas_evidence(
        self,
    ) -> None:
        expected_paths = {
            Path("release-artifacts/post-entropy-mint-completion-gas.json"),
            Path(
                "release-artifacts/baselines/v0.1.0/"
                "post-entropy-completion-gas.snap"
            ),
            Path("scripts/generate_post_entropy_completion_gas.py"),
            Path("scripts/check_post_entropy_completion_gas.py"),
            Path("scripts/test_post_entropy_completion_gas.py"),
            Path("test/StreamCorePermanentTarget.t.sol"),
            Path("test/StreamPostEntropyCompletionGas.t.sol"),
            Path("test/helpers/StreamPostEntropyCompletionGasHarness.sol"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_default_covered_paths_include_python_toolchain_provenance(self) -> None:
        """Policy and committed bundles bind every reviewed Python toolchain input."""

        expected_paths = {
            Path("requirements-tools.txt"),
            Path("requirements-tools.lock"),
            Path(".github/workflows/ci.yml"),
            Path(".github/workflows/release-mode.yml"),
            Path("scripts/check_python_toolchain.py"),
            Path("scripts/test_python_toolchain.py"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_default_covered_paths_include_evidence_artifacts(self) -> None:
        self.assertIn(
            Path("release-artifacts/stream-core-permanent-interface.json"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("release-artifacts/system-manifest-payload-vector.json"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(Path("release-artifacts/schema"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("release-artifacts/evidence"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(
            Path("release-artifacts/drop-authorization-signing"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("release-artifacts/signer-custody-readiness"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(Path("release-artifacts/permanence"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("release-artifacts/provenance"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(
            Path("scripts/generate_dependency_provenance_attestation.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/check_contract_size_budget.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/check_mint_manager_domain_constants.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/test_mint_manager_domain_constants.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(Path("scripts/generate_release_notes.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/verify_release_artifacts.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/build_release_artifacts.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/test_release_build_artifacts.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/test_windows_ci_wrapper.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("docs/first-30-minutes.md"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/check_first_30_minutes.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/test_first_30_minutes.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(
            Path(".github/ISSUE_TEMPLATE/integration_report.yml"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path(".github/ISSUE_TEMPLATE/audit_finding.yml"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path(".github/ISSUE_TEMPLATE/release_evidence.yml"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(Path(".github/PULL_REQUEST_TEMPLATE.md"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/check_issue_templates.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/test_issue_templates.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/check_pr_template.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/test_pr_template.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/check_markdown_links.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("scripts/test_markdown_links.py"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(
            Path("scripts/check_typescript_artifact_chain_config.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/test_typescript_artifact_chain_config.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/check_typescript_eip712_drop_authorization.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/check_typescript_event_decoding_indexer.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/test_typescript_eip712_drop_authorization.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/test_typescript_event_decoding_indexer.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/check_integration_conformance_fixtures.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("scripts/test_integration_conformance_fixtures.py"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(
            Path("docs/integrations/fixtures/integration-conformance-fixtures.json"),
            generator.DEFAULT_COVERED_PATHS,
        )
        self.assertIn(Path("deployments/admin-ceremony"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("release-artifacts/signatures"), generator.DEFAULT_COVERED_PATHS)
        self.assertIn(Path("test/fixtures/drop-authorization"), generator.DEFAULT_COVERED_PATHS)
        genesis_profile_paths = {
            Path("release-artifacts/genesis-deployment-profile.json"),
            Path("scripts/check_genesis_deployment_profile.py"),
            Path("scripts/test_genesis_deployment_profile.py"),
            Path("scripts/check_governed_parameter_identifiers.py"),
            Path("scripts/test_governed_parameter_identifiers.py"),
            Path("release-artifacts/system-manifest-payload-vector.json"),
            Path("scripts/generate_system_manifest_payload_vector.py"),
            Path("scripts/check_system_manifest_payload_vector.py"),
            Path("scripts/test_system_manifest_payload_vector.py"),
            Path("scripts/check_system_manifest_payload_vector_reference.py"),
            Path("scripts/test_system_manifest_payload_vector_reference.py"),
            Path("scripts/check_release_mode.py"),
            Path("scripts/test_release_mode.py"),
            Path("docs/launch-conformance-matrix.md"),
            Path("docs/stream-long-term-architecture.md"),
            Path("docs/adr/0004-admin-governance.md"),
            Path("docs/adr/0017-raise-only-parameter-governance.md"),
        }
        self.assert_committed_checksums_cover(genesis_profile_paths)
        slither_baseline_paths = {
            Path("ops/SLITHER_BASELINE.json"),
            Path("ops/SLITHER_BASELINE.md"),
            Path("scripts/check_slither_baseline.py"),
            Path("scripts/test_slither_baseline.py"),
            Path("docs/slither.md"),
            Path("requirements-tools.txt"),
            Path("slither.config.json"),
            Path("foundry.toml"),
        }
        self.assert_committed_checksums_cover(slither_baseline_paths)

    def test_committed_checksums_cover_governed_parameter_inventory(self) -> None:
        expected_paths = {
            Path("release-artifacts/governed-parameter-inventory.json"),
            Path(
                "release-artifacts/schema/"
                "governed-parameter-inventory.v1.schema.json"
            ),
            Path("scripts/check_governed_parameter_inventory.py"),
            Path("scripts/test_governed_parameter_inventory.py"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_committed_checksums_cover_record_family_authorization_package(
        self,
    ) -> None:
        expected_paths = {
            Path("release-artifacts/record-family-authorization-inventory.json"),
            Path(
                "release-artifacts/schema/"
                "record-family-authorization-inventory.v1.schema.json"
            ),
            Path(
                "deployments/record-family-authorization/"
                "record-family-authorization-evidence-template.json"
            ),
            Path(
                "deployments/schema/"
                "record-family-authorization-evidence.v1.schema.json"
            ),
            Path(
                "deployments/schema/"
                "record-family-authorization-grant-map.v1.schema.json"
            ),
            Path("scripts/check_record_family_authorization.py"),
            Path("scripts/test_record_family_authorization.py"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_committed_checksums_cover_artist_semantic_owner_packet(self) -> None:
        expected_paths = {
            Path("docs/adr/0023-modular-artist-authority-domain-ownership.md"),
            Path("docs/architecture/artist-semantic-owner-matrix-v2.json"),
            Path("docs/architecture/artist-semantic-owner-matrix-v2.schema.json"),
            Path("scripts/check_artist_semantic_owner_matrix.py"),
            Path("scripts/test_artist_semantic_owner_matrix.py"),
            Path(
                "release-artifacts/issue-670-adapter-freeze/"
                "artist-operation-matrix-v1.json"
            ),
            Path("smart-contracts/interfaces/stream/IStreamRoleRegistry.sol"),
            Path("smart-contracts/interfaces/stream/IStreamCore.sol"),
            Path(
                "smart-contracts/interfaces/stream/"
                "IStreamGovernedParameterAuthority.sol"
            ),
            Path(
                "smart-contracts/interfaces/stream/"
                "IStreamArtworkFinalityRegistry.sol"
            ),
            Path("smart-contracts/domains/artist/StreamArtistArchiveV2.sol"),
            Path(
                "smart-contracts/interfaces/stream/IStreamArtistArchiveV2.sol"
            ),
            Path("smart-contracts/domains/artist/StreamArtistRegistryV2.sol"),
            Path(
                "smart-contracts/interfaces/stream/IStreamArtistRegistryV2.sol"
            ),
        }
        self.assertTrue(expected_paths <= set(generator.DEFAULT_COVERED_PATHS))
        self.assert_committed_checksums_cover(expected_paths)

    def test_default_covered_paths_include_release_manifest_source_docs(self) -> None:
        expected_paths = {
            Path("CHANGELOG.md"),
            Path("README.md"),
            Path("docs/release-policy.md"),
            Path("docs/launch-v1-target-architecture.md"),
            Path("docs/public-beta-evidence.md"),
            Path("docs/production-readiness-execution.md"),
            Path("docs/integrations/README.md"),
            Path("docs/integrations/events-and-indexing.md"),
            Path("docs/tooling.md"),
            Path("docs/status.md"),
            Path("docs/adr/0017-raise-only-parameter-governance.md"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_default_covered_paths_bind_release_tail_provenance(self) -> None:
        expected_paths = {
            Path("scripts/generate_release_checksums.py"),
            Path("scripts/test_release_checksums.py"),
            Path("scripts/generate_release_manifest.py"),
            Path("scripts/test_release_manifest.py"),
            Path("scripts/generate_release_candidate_lockfile.py"),
            Path("scripts/test_release_candidate_lockfile.py"),
            Path("scripts/verify_release_artifacts.py"),
            Path("scripts/test_verify_release_artifacts.py"),
            Path("scripts/generate_risk_register.py"),
            Path("scripts/check_risk_register.py"),
            Path("scripts/test_risk_register.py"),
            Path("scripts/check_release_evidence_issue_links.py"),
            Path("scripts/test_release_evidence_issue_links.py"),
            Path("scripts/check_public_beta_evidence.py"),
            Path("scripts/test_public_beta_evidence.py"),
            Path("release-artifacts/README.md"),
            Path("ops/ROADMAP.md"),
            Path("ops/EXECUTION_BACKLOG.md"),
            Path("docs/known-blockers.md"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_default_covered_paths_bind_adr17_supersession_notices(self) -> None:
        expected_paths = {
            Path("docs/adr/README.md"),
            Path("docs/adr/0008-revenue-splits-and-royalty-resolver.md"),
            Path("docs/adr/0010-world-class-spec-pass.md"),
            Path("docs/adr/0011-world-class-pass-round-2.md"),
            Path("docs/adr/0012-world-class-pass-round-3.md"),
            Path("docs/adr/0013-world-class-pass-round-4.md"),
            Path("docs/adr/0014-world-class-pass-round-5.md"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_default_covered_paths_bind_operation_identity_adr(self) -> None:
        path = Path("docs/adr/0018-batch-operation-root-and-token-identity.md")
        self.assertIn(path, generator.DEFAULT_COVERED_PATHS)
        self.assert_committed_checksums_cover({path})

    def test_default_covered_paths_bind_artist_adapter_adr(self) -> None:
        path = Path(
            "docs/adr/0022-immutable-artist-registry-validation-adapter.md"
        )
        self.assertIn(path, generator.DEFAULT_COVERED_PATHS)
        self.assert_committed_checksums_cover({path})

    def test_default_covered_paths_bind_parameter_and_abi_policy(self) -> None:
        expected_paths = {
            Path("Makefile"),
            Path("scripts/check.sh"),
            Path("scripts/check.ps1"),
            Path("ops/EXTERNAL_CALL_GAS_INVENTORY.json"),
            Path("scripts/check_external_call_gas_inventory.py"),
            Path("scripts/test_external_call_gas_inventory.py"),
            Path("scripts/check_abi_compatibility.py"),
            Path("scripts/test_abi_compatibility.py"),
        }
        self.assert_committed_checksums_cover(expected_paths)

    def test_committed_checksums_bind_exact_gitattributes_bytes(
        self,
    ) -> None:
        self.assert_committed_checksums_cover({generator.GIT_ATTRIBUTES_PATH})

    def test_current_canonical_inputs_have_declared_line_endings(
        self,
    ) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        effective_paths, _references = generator.release_checksum_inputs(
            repo_root,
            generator.DEFAULT_COVERED_PATHS,
        )
        files = generator.collect_files(
            repo_root,
            effective_paths,
            repo_root / generator.DEFAULT_OUTPUT_DIR,
        )
        classifications = generator.validate_covered_file_line_endings(
            repo_root,
            files,
        )

        self.assertEqual(len(classifications), 462)
        self.assertEqual(classifications[".gitattributes"].classification, "lf")
        self.assertEqual(classifications["scripts/check.sh"].classification, "lf")
        self.assertEqual(classifications["scripts/check.ps1"].classification, "crlf")
        self.assertEqual(
            {
                snapshot.classification
                for snapshot in classifications.values()
            },
            {"lf", "crlf"},
        )

    def test_line_ending_validator_accepts_declared_canonical_parity(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                (
                    "* text=auto\n"
                    ".gitattributes text eol=lf\n"
                    "*.lf text eol=lf\n"
                    "*.crlf text eol=crlf\n"
                ),
            )
            lf_path = root / "same.lf"
            crlf_path = root / "same.crlf"
            lf_path.write_bytes(b"same\nlogical\ncontent\n")
            crlf_path.write_bytes(b"same\r\nlogical\r\ncontent\r\n")

            classifications = generator.validate_covered_file_line_endings(
                root,
                [attributes, lf_path, crlf_path],
            )

            self.assertEqual(classifications["same.lf"].classification, "lf")
            self.assertEqual(classifications["same.crlf"].classification, "crlf")
            self.assertEqual(
                lf_path.read_bytes(),
                crlf_path.read_bytes().replace(b"\r\n", b"\n"),
            )

    def test_git_checkouts_with_different_autocrlf_build_identical_bundles(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "source"
            checkout_true = root / "checkout-true"
            checkout_false = root / "checkout-false"
            source.mkdir()

            def run_git(*args: str) -> None:
                subprocess.run(
                    ["git", *args],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )

            run_git("init", "--quiet", source.as_posix())
            run_git("-C", source.as_posix(), "config", "user.email", "eol@test.invalid")
            run_git("-C", source.as_posix(), "config", "user.name", "EOL Test")
            run_git("-C", source.as_posix(), "config", "core.autocrlf", "false")
            (source / ".gitattributes").write_bytes(
                (
                    b"* text=auto\n"
                    b".gitattributes text eol=lf\n"
                    b"*.txt text eol=lf\n"
                    b"*.ps1 text eol=crlf\n"
                )
            )
            (source / "payload.txt").write_bytes(b"same\nlogical\ncontent\n")
            (source / "wrapper.ps1").write_bytes(
                b"Write-Output 'same'\r\nWrite-Output 'content'\r\n"
            )
            run_git("-C", source.as_posix(), "add", ".")
            run_git("-C", source.as_posix(), "commit", "--quiet", "-m", "fixture")
            run_git(
                "-c",
                "core.autocrlf=true",
                "clone",
                "--quiet",
                source.as_posix(),
                checkout_true.as_posix(),
            )
            run_git(
                "-c",
                "core.autocrlf=false",
                "clone",
                "--quiet",
                source.as_posix(),
                checkout_false.as_posix(),
            )

            covered = [
                generator.GIT_ATTRIBUTES_PATH,
                Path("payload.txt"),
                Path("wrapper.ps1"),
            ]
            outputs: list[tuple[str, str]] = []
            snapshots_by_checkout: list[
                dict[str, generator.CoveredFileSnapshot]
            ] = []
            for checkout in (checkout_true, checkout_false):
                snapshots_by_checkout.append(
                    generator.validate_covered_file_line_endings(
                        checkout,
                        [checkout / path for path in covered],
                    )
                )
                with mock.patch.object(
                    generator,
                    "release_checksum_inputs",
                    return_value=(covered, []),
                ):
                    outputs.append(
                        generator.build_outputs(
                            checkout,
                            covered,
                            checkout / "custom-checksums",
                            coverage_policy=(
                                generator.CUSTOM_SUBSET_COVERAGE_POLICY
                            ),
                        )
                    )

            self.assertEqual(
                snapshots_by_checkout[0]["payload.txt"].data,
                b"same\nlogical\ncontent\n",
            )
            self.assertEqual(
                snapshots_by_checkout[0]["wrapper.ps1"].classification,
                "crlf",
            )
            self.assertEqual(
                {
                    path: (
                        snapshot.data,
                        snapshot.sha256,
                        snapshot.size_bytes,
                        snapshot.classification,
                    )
                    for path, snapshot in snapshots_by_checkout[0].items()
                },
                {
                    path: (
                        snapshot.data,
                        snapshot.sha256,
                        snapshot.size_bytes,
                        snapshot.classification,
                    )
                    for path, snapshot in snapshots_by_checkout[1].items()
                },
            )
            self.assertEqual(outputs[0], outputs[1])

    def test_line_ending_validator_rejects_noncanonical_text_bytes(
        self,
    ) -> None:
        cases = (
            ("*.txt text eol=lf", b"wrong\r\n", "eol=lf"),
            ("*.ps1 text eol=crlf", b"mixed\r\nbare\n", "eol=crlf"),
            ("*.ps1 text eol=crlf", b"lone\rreturn\r\n", "eol=crlf"),
        )
        for rule, payload, diagnostic in cases:
            with self.subTest(rule=rule, payload=payload):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    attributes = root / ".gitattributes"
                    write_text(
                        attributes,
                        (
                            "* text=auto\n"
                            ".gitattributes text eol=lf\n"
                            f"{rule}\n"
                        ),
                    )
                    suffix = ".ps1" if "*.ps1" in rule else ".txt"
                    target = root / f"payload{suffix}"
                    target.write_bytes(payload)

                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        diagnostic,
                    ):
                        generator.validate_covered_file_line_endings(
                            root,
                            [attributes, target],
                        )

    def test_line_ending_validator_rejects_attribute_unspecified_text(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(attributes, ".gitattributes text eol=lf\n")
            target = root / "payload.txt"
            target.write_bytes(b"text\n")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "no explicit text/binary rule: payload.txt",
            ):
                generator.validate_covered_file_line_endings(
                    root,
                    [attributes, target],
                )

    def test_line_ending_validator_rejects_attributes_omission_or_substitution(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n",
            )
            target = root / "payload.bin"
            target.write_bytes(b"\x00\r\n")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must include exact .gitattributes",
            ):
                generator.validate_covered_file_line_endings(root, [target])
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must use exact .gitattributes",
            ):
                generator.validate_covered_file_line_endings(
                    root,
                    [attributes, target],
                    attributes_path=Path("substitute.attributes"),
                )

    def test_line_ending_validator_rejects_nested_attributes_override(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            nested_attributes = root / "nested" / ".gitattributes"
            write_text(nested_attributes, "*.txt text eol=crlf\n")
            target = root / "nested" / "payload.txt"
            target.write_bytes(b"canonical\n")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "forbids nested .gitattributes: nested/.gitattributes",
            ):
                generator.validate_covered_file_line_endings(
                    root,
                    [attributes, target],
                )

    def test_line_ending_validator_rejects_symlink_or_reparse_components(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            target = root / "target.txt"
            target.write_bytes(b"canonical\n")
            linked = root / "linked.txt"
            try:
                linked.symlink_to(target)
            except OSError as exc:
                self.skipTest(f"symlink creation unavailable: {exc}")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "must not include symlink/reparse components",
            ):
                generator.validate_covered_file_line_endings(
                    root,
                    [attributes, linked],
                )

    def test_line_ending_validator_rejects_symlinked_repo_root(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            parent = Path(temp_dir)
            real_root = parent / "real"
            real_root.mkdir()
            attributes = real_root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n",
            )
            linked_root = parent / "linked"
            try:
                linked_root.symlink_to(real_root, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "repository root must not include symlink/reparse components",
            ):
                generator.validate_covered_file_line_endings(
                    linked_root,
                    [linked_root / ".gitattributes"],
                )

    def test_generator_rejects_redirected_repository_root_parent(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            parent = Path(temp_dir)
            real_parent = parent / "real-parent"
            real_root = real_parent / "repo"
            real_root.mkdir(parents=True)
            write_text(
                real_root / ".gitattributes",
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            (real_root / "payload.txt").write_bytes(b"canonical\n")
            linked_parent = parent / "linked-parent"
            try:
                linked_parent.symlink_to(real_parent, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            linked_root = linked_parent / "repo"
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("payload.txt")]

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "repository root must not include symlink/reparse components",
            ):
                generator.validate_covered_file_line_endings(
                    linked_root,
                    [
                        linked_root / generator.GIT_ATTRIBUTES_PATH,
                        linked_root / "payload.txt",
                    ],
                )
            with self.assertRaisesRegex(
                generator.ChecksumError,
                "repository root must not include symlink/reparse components",
            ):
                generator.build_outputs(
                    linked_root,
                    covered,
                    linked_root / "custom-output",
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )

    def test_canonical_build_rejects_symlinked_covered_directory_root(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            payload = root / "payload.txt"
            payload.write_bytes(b"canonical\n")
            real_empty = root / "real-empty"
            real_empty.mkdir()
            linked_root = root / "covered-link"
            try:
                linked_root.symlink_to(real_empty, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            covered = [
                generator.GIT_ATTRIBUTES_PATH,
                Path("payload.txt"),
                Path("covered-link"),
            ]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "covered path must not include symlink/reparse components",
                ):
                    generator.build_outputs(
                        root,
                        covered,
                        root / generator.DEFAULT_OUTPUT_DIR,
                    )

    def test_canonical_build_rejects_nested_directory_redirect(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            covered_dir = root / "covered"
            covered_dir.mkdir()
            (covered_dir / "good.txt").write_bytes(b"canonical\n")
            target_dir = root / "hidden-target"
            target_dir.mkdir()
            (target_dir / "hidden.txt").write_bytes(b"hidden\n")
            linked_dir = covered_dir / "linked-dir"
            try:
                linked_dir.symlink_to(target_dir, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("covered")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "covered directory must not contain symlink/reparse entries",
                ):
                    generator.build_outputs(
                        root,
                        covered,
                        root / generator.DEFAULT_OUTPUT_DIR,
                    )

    def test_canonical_build_rejects_symlinked_output_directory_and_file(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            payload = root / "payload.txt"
            payload.write_bytes(b"canonical\n")
            real_output = root / "real-output"
            real_output.mkdir()
            output_parent = root / "release-artifacts"
            output_parent.mkdir()
            linked_output = root / generator.DEFAULT_OUTPUT_DIR
            try:
                linked_output.symlink_to(real_output, target_is_directory=True)
            except OSError as exc:
                self.skipTest(f"directory symlink creation unavailable: {exc}")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("payload.txt")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "output directory must not include symlink/reparse components",
                ):
                    generator.build_outputs(root, covered, linked_output)

    def test_write_and_check_reject_redirected_output_files(
        self,
    ) -> None:
        cases = (
            (generator.CHECKSUM_FILE_NAME, "symlink", "must not redirect"),
            (generator.CHECKSUM_MANIFEST_NAME, "symlink", "must not redirect"),
            (generator.CHECKSUM_FILE_NAME, "hardlink", "must have one link"),
            (generator.CHECKSUM_MANIFEST_NAME, "hardlink", "must have one link"),
        )
        for output_name, link_kind, diagnostic in cases:
            with self.subTest(output_name=output_name, link_kind=link_kind):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    output_dir = root / generator.DEFAULT_OUTPUT_DIR
                    output_dir.mkdir(parents=True)
                    victim = root / "victim.txt"
                    victim_bytes = b"must remain unchanged\n"
                    victim.write_bytes(victim_bytes)
                    good = root / "good.txt"
                    good.write_bytes(b"must remain covered\n")
                    redirected = output_dir / output_name
                    try:
                        if link_kind == "symlink":
                            redirected.symlink_to(victim)
                        else:
                            redirected.hardlink_to(victim)
                    except OSError as exc:
                        self.skipTest(f"{link_kind} creation unavailable: {exc}")

                    covered = [Path("victim.txt"), Path("good.txt")]
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        diagnostic,
                    ):
                        generator.build_outputs(
                            root,
                            covered,
                            output_dir,
                            coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                        )
                    self.assertEqual(victim.read_bytes(), victim_bytes)
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        diagnostic,
                    ):
                        generator.write_outputs(
                            root,
                            covered,
                            output_dir,
                            coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                        )
                    self.assertEqual(victim.read_bytes(), victim_bytes)
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        diagnostic,
                    ):
                        generator.check_outputs(
                            root,
                            covered,
                            output_dir,
                            coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                        )
                    self.assertEqual(victim.read_bytes(), victim_bytes)

    def test_build_rechecks_output_redirects_created_after_preflight(
        self,
    ) -> None:
        cases = (
            (generator.CHECKSUM_FILE_NAME, "symlink", "must not redirect"),
            (generator.CHECKSUM_MANIFEST_NAME, "symlink", "must not redirect"),
            (generator.CHECKSUM_FILE_NAME, "hardlink", "must have one link"),
            (generator.CHECKSUM_MANIFEST_NAME, "hardlink", "must have one link"),
        )
        for output_name, link_kind, redirect_diagnostic in cases:
            for victim_is_covered in (True, False):
                with self.subTest(
                    output_name=output_name,
                    link_kind=link_kind,
                    victim_is_covered=victim_is_covered,
                ):
                    with tempfile.TemporaryDirectory() as temp_dir:
                        root = Path(temp_dir)
                        output_dir = root / "custom-output"
                        output_dir.mkdir()
                        victim = root / "victim.txt"
                        victim_bytes = b"must remain unchanged\n"
                        victim.write_bytes(victim_bytes)
                        good = root / "good.txt"
                        good.write_bytes(b"must remain covered\n")
                        redirected = output_dir / output_name
                        covered = [Path("good.txt")]
                        if victim_is_covered:
                            covered.insert(0, Path("victim.txt"))

                        def create_redirect_after_preflight(*_args, **_kwargs):
                            try:
                                if link_kind == "symlink":
                                    redirected.symlink_to(victim)
                                else:
                                    redirected.hardlink_to(victim)
                            except OSError as exc:
                                self.skipTest(
                                    f"{link_kind} creation unavailable: {exc}"
                                )
                            return covered, []

                        diagnostic = (
                            "covered path must not alias generated checksum output"
                            if victim_is_covered
                            else redirect_diagnostic
                        )
                        with mock.patch.object(
                            generator,
                            "release_checksum_inputs",
                            side_effect=create_redirect_after_preflight,
                        ):
                            with self.assertRaisesRegex(
                                generator.ChecksumError,
                                diagnostic,
                            ):
                                generator.build_outputs(
                                    root,
                                    covered,
                                    output_dir,
                                    coverage_policy=(
                                        generator.CUSTOM_SUBSET_COVERAGE_POLICY
                                    ),
                                )
                        self.assertEqual(victim.read_bytes(), victim_bytes)

    def test_write_and_check_reject_output_directory_swap_after_build(
        self,
    ) -> None:
        for operation in ("write", "check"):
            for hostile_is_covered in (True, False):
                with self.subTest(
                    operation=operation,
                    hostile_is_covered=hostile_is_covered,
                ):
                    with tempfile.TemporaryDirectory() as temp_dir:
                        root = Path(temp_dir)
                        output_dir = root / "custom-output"
                        output_dir.mkdir()
                        hostile_dir = root / "hostile-output-target"
                        hostile_dir.mkdir()
                        (hostile_dir / "payload.txt").write_bytes(
                            b"hostile target must remain unchanged\n"
                        )
                        good = root / "good.txt"
                        good.write_bytes(b"must remain covered\n")
                        covered = [Path("good.txt")]
                        if hostile_is_covered:
                            covered.append(Path("hostile-output-target"))

                        if operation == "check":
                            generator.write_outputs(
                                root,
                                covered,
                                output_dir,
                                coverage_policy=(
                                    generator.CUSTOM_SUBSET_COVERAGE_POLICY
                                ),
                            )

                        original_build_outputs = generator.build_outputs
                        original_output_dir = root / "original-output"

                        def swap_output_after_build(*args, **kwargs):
                            result = original_build_outputs(*args, **kwargs)
                            output_dir.rename(original_output_dir)
                            try:
                                output_dir.symlink_to(
                                    hostile_dir,
                                    target_is_directory=True,
                                )
                            except OSError as exc:
                                self.skipTest(
                                    f"directory symlink creation unavailable: {exc}"
                                )
                            return result

                        with mock.patch.object(
                            generator,
                            "build_outputs",
                            side_effect=swap_output_after_build,
                        ):
                            if operation == "write":
                                with self.assertRaisesRegex(
                                    generator.ChecksumError,
                                    (
                                        "output directory must not include "
                                        "symlink/reparse components"
                                    ),
                                ):
                                    generator.write_outputs(
                                        root,
                                        covered,
                                        output_dir,
                                        coverage_policy=(
                                            generator.CUSTOM_SUBSET_COVERAGE_POLICY
                                        ),
                                    )
                            else:
                                stderr = StringIO()
                                with redirect_stdout(StringIO()), redirect_stderr(
                                    stderr
                                ):
                                    result = generator.check_outputs(
                                        root,
                                        covered,
                                        output_dir,
                                        coverage_policy=(
                                            generator.CUSTOM_SUBSET_COVERAGE_POLICY
                                        ),
                                    )
                                self.assertEqual(result, 1)
                                self.assertIn(
                                    "output directory must not include "
                                    "symlink/reparse components",
                                    stderr.getvalue(),
                                )
                        self.assertFalse(
                            (hostile_dir / generator.CHECKSUM_FILE_NAME).exists()
                        )
                        self.assertFalse(
                            (hostile_dir / generator.CHECKSUM_MANIFEST_NAME).exists()
                        )

    def test_write_rejects_output_directory_swap_during_temp_creation(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "custom-output"
            output_dir.mkdir()
            original_output_dir = root / "original-output"
            hostile_dir = root / "hostile-output-target"
            hostile_dir.mkdir()
            sentinel = hostile_dir / "sentinel.txt"
            sentinel_bytes = b"hostile target must remain unchanged\n"
            sentinel.write_bytes(sentinel_bytes)
            good = root / "good.txt"
            good.write_bytes(b"must remain covered\n")

            original_mkstemp = generator.tempfile.mkstemp

            def swap_output_during_mkstemp(*args, **kwargs):
                output_dir.rename(original_output_dir)
                try:
                    output_dir.symlink_to(
                        hostile_dir,
                        target_is_directory=True,
                    )
                except OSError as exc:
                    self.skipTest(
                        f"directory symlink creation unavailable: {exc}"
                    )
                return original_mkstemp(*args, **kwargs)

            with mock.patch.object(
                generator.tempfile,
                "mkstemp",
                side_effect=swap_output_during_mkstemp,
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "output directory must not include symlink/reparse components",
                ):
                    generator.write_outputs(
                        root,
                        [Path("good.txt")],
                        output_dir,
                        coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                    )

            self.assertEqual(sentinel.read_bytes(), sentinel_bytes)
            self.assertFalse(
                (hostile_dir / generator.CHECKSUM_FILE_NAME).exists()
            )
            self.assertFalse(
                (hostile_dir / generator.CHECKSUM_MANIFEST_NAME).exists()
            )
            self.assertEqual(
                sorted(path.name for path in hostile_dir.iterdir()),
                [sentinel.name],
            )

    def test_write_and_check_reject_case_ambiguous_output_files(
        self,
    ) -> None:
        cases = (
            (generator.CHECKSUM_FILE_NAME, "sha256sums"),
            (generator.CHECKSUM_MANIFEST_NAME, "Release-Checksums.json"),
        )
        for canonical_name, alias_name in cases:
            with self.subTest(canonical_name=canonical_name):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    output_dir = root / generator.DEFAULT_OUTPUT_DIR
                    output_dir.mkdir(parents=True)
                    (output_dir / alias_name).write_bytes(b"ambiguous\n")

                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "case-ambiguous path spelling",
                    ):
                        generator.build_outputs(
                            root,
                            [Path("unused")],
                            output_dir,
                            coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                        )
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "case-ambiguous path spelling",
                    ):
                        generator.write_outputs(
                            root,
                            [Path("unused")],
                            output_dir,
                            coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                        )
                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        "case-ambiguous path spelling",
                    ):
                        generator.check_outputs(
                            root,
                            [Path("unused")],
                            output_dir,
                            coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                        )

    def test_canonical_build_rejects_redirect_to_excluded_output(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            output_dir = root / generator.DEFAULT_OUTPUT_DIR
            output_dir.mkdir(parents=True)
            excluded_output = output_dir / generator.CHECKSUM_FILE_NAME
            excluded_output.write_bytes(b"excluded\n")
            covered_dir = root / "covered"
            covered_dir.mkdir()
            (covered_dir / "good.txt").write_bytes(b"canonical\n")
            linked_file = covered_dir / "linked.txt"
            try:
                linked_file.symlink_to(excluded_output)
            except OSError as exc:
                self.skipTest(f"file symlink creation unavailable: {exc}")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("covered")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "covered directory must not contain symlink/reparse entries",
                ):
                    generator.build_outputs(root, covered, output_dir)

    def test_canonical_build_rejects_dangling_symlink_entry(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            covered_dir = root / "covered"
            covered_dir.mkdir()
            (covered_dir / "good.txt").write_bytes(b"canonical\n")
            dangling = covered_dir / "dangling.txt"
            try:
                dangling.symlink_to(root / "missing-target.txt")
            except OSError as exc:
                self.skipTest(f"file symlink creation unavailable: {exc}")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("covered")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "covered directory must not contain symlink/reparse entries",
                ):
                    generator.build_outputs(
                        root,
                        covered,
                        root / generator.DEFAULT_OUTPUT_DIR,
                    )

    def test_canonical_build_rejects_hardlink_to_excluded_output(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            output_dir = root / generator.DEFAULT_OUTPUT_DIR
            output_dir.mkdir(parents=True)
            excluded_output = output_dir / generator.CHECKSUM_FILE_NAME
            excluded_output.write_bytes(b"excluded\n")
            covered_dir = root / "covered"
            covered_dir.mkdir()
            (covered_dir / "good.txt").write_bytes(b"canonical\n")
            hardlink = covered_dir / "hardlink.txt"
            try:
                hardlink.hardlink_to(excluded_output)
            except OSError as exc:
                self.skipTest(f"hardlink creation unavailable: {exc}")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("covered")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "output file must have one link",
                ):
                    generator.build_outputs(root, covered, output_dir)

    def test_line_ending_validator_preserves_binary_and_raw_bytes(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                (
                    "* text=auto\n"
                    ".gitattributes text eol=lf\n"
                    "*.raw -text\n"
                ),
            )
            auto_binary = root / "auto.bin"
            raw_binary = root / "explicit.raw"
            auto_bytes = b"\x00auto\r\nbare\nlone\r"
            raw_bytes = b"raw\r\nbare\nlone\r"
            auto_binary.write_bytes(auto_bytes)
            raw_binary.write_bytes(raw_bytes)

            classifications = generator.validate_covered_file_line_endings(
                root,
                [attributes, auto_binary, raw_binary],
            )

            self.assertEqual(classifications["auto.bin"].classification, "binary")
            self.assertEqual(classifications["explicit.raw"].classification, "binary")
            self.assertEqual(auto_binary.read_bytes(), auto_bytes)
            self.assertEqual(raw_binary.read_bytes(), raw_bytes)

    def test_line_ending_snapshots_bind_validated_bytes_hash_and_size(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            target = root / "payload.txt"
            original = b"canonical\n"
            target.write_bytes(original)

            snapshots = generator.validate_covered_file_line_endings(
                root,
                [attributes, target],
            )
            snapshot = snapshots["payload.txt"]
            target.write_bytes(b"mutated\r\n")

            self.assertEqual(snapshot.data, original)
            self.assertEqual(snapshot.size_bytes, len(original))
            self.assertEqual(snapshot.sha256, generator.sha256_bytes(original))
            self.assertEqual(snapshot.classification, "lf")
            checksum_line = generator.build_checksum_lines([snapshot])[0]
            self.assertEqual(
                checksum_line,
                (
                    f"{generator.sha256_bytes(original).removeprefix('sha256:')}"
                    "  payload.txt"
                ),
            )

    def test_line_ending_validator_rejects_ambiguous_or_unsupported_rules(
        self,
    ) -> None:
        cases = (
            ("*.txt text -text eol=lf\n", "ambiguous.*text mode"),
            ("*.txt text eol=lf eol=crlf\n", "ambiguous.*eol"),
            ("*.txt text working-tree-encoding=UTF-16\n", "unsupported.*attribute"),
            ("src/? text eol=lf\n", "unsupported.*pattern"),
        )
        for rule, diagnostic in cases:
            with self.subTest(rule=rule):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    attributes = root / ".gitattributes"
                    write_text(attributes, rule)

                    with self.assertRaisesRegex(
                        generator.ChecksumError,
                        diagnostic,
                    ):
                        generator.validate_covered_file_line_endings(
                            root,
                            [attributes],
                        )

    def test_canonical_build_and_check_validate_expanded_line_endings(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "custom-checksums"
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                (
                    "* text=auto\n"
                    ".gitattributes text eol=lf\n"
                    "*.txt text eol=lf\n"
                ),
            )
            payload = root / "payload.txt"
            payload.write_bytes(b"wrong\r\n")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("payload.txt")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    "violates declared eol=lf: payload.txt",
                ):
                    generator.build_outputs(root, covered, output_dir)

                stderr = StringIO()
                with redirect_stdout(StringIO()), redirect_stderr(stderr):
                    result = generator.check_outputs(root, covered, output_dir)
                self.assertEqual(result, 1)
                self.assertIn(
                    "violates declared eol=lf: payload.txt",
                    stderr.getvalue(),
                )

    def test_canonical_bundle_binds_gitattributes_hash_size_and_mutation(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / "custom-checksums"
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                (
                    "* text=auto\n"
                    ".gitattributes text eol=lf\n"
                    "*.txt text eol=lf\n"
                ),
            )
            payload = root / "payload.txt"
            payload.write_bytes(b"canonical\n")
            covered = [generator.GIT_ATTRIBUTES_PATH, Path("payload.txt")]

            with mock.patch.object(
                generator,
                "release_checksum_inputs",
                return_value=(covered, []),
            ):
                generator.write_outputs(
                    root,
                    covered,
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )
                checksum_entries = {
                    relative_path: digest
                    for digest, relative_path in generator.parse_checksum_file(
                        (output_dir / generator.CHECKSUM_FILE_NAME).read_text(
                            encoding="utf-8"
                        )
                    )
                }
                manifest = json.loads(
                    (output_dir / generator.CHECKSUM_MANIFEST_NAME).read_text(
                        encoding="utf-8"
                    )
                )
                manifest_entries = {
                    entry["path"]: entry for entry in manifest["files"]
                }
                expected_hash = generator.file_sha256(attributes)
                self.assertEqual(
                    checksum_entries[".gitattributes"],
                    expected_hash.removeprefix("sha256:"),
                )
                self.assertEqual(
                    manifest_entries[".gitattributes"],
                    {
                        "path": ".gitattributes",
                        "sha256": expected_hash,
                        "size_bytes": attributes.stat().st_size,
                    },
                )

                with attributes.open("ab") as handle:
                    handle.write(b"# post-bundle mutation\n")
                stderr = StringIO()
                with redirect_stdout(StringIO()), redirect_stderr(stderr):
                    result = generator.check_outputs(
                        root,
                        covered,
                        output_dir,
                        coverage_policy=(
                            generator.CUSTOM_SUBSET_COVERAGE_POLICY
                        ),
                    )
                self.assertEqual(result, 1)
                self.assertIn(
                    "hash mismatch for .gitattributes",
                    stderr.getvalue(),
                )

    def test_checksum_parser_rejects_noncanonical_path_spellings(self) -> None:
        digest = "0" * 64
        aliases = (
            ("foo//bar.txt", "invalid path"),
            ("foo/./bar.txt", "invalid path"),
            ("foo/../bar.txt", "path traversal"),
            ("foo\\bar.txt", "invalid path"),
            ("/foo/bar.txt", "invalid path"),
        )
        for alias, diagnostic in aliases:
            with self.subTest(alias=alias):
                with self.assertRaisesRegex(
                    generator.ChecksumError,
                    diagnostic,
                ):
                    generator.parse_checksum_file(f"{digest}  {alias}\n")

    def test_checksum_parser_rejects_duplicate_paths(self) -> None:
        digest = "0" * 64
        checksum = (
            f"{digest}  .gitattributes\n"
            f"{digest}  .gitattributes\n"
        )
        with self.assertRaisesRegex(
            generator.ChecksumError,
            "duplicate path .gitattributes",
        ):
            generator.parse_checksum_file(checksum)

    def test_line_ending_validator_rejects_case_alias(self) -> None:
        if Path("CASE").resolve() != Path("case").resolve():
            self.skipTest("case-alias behavior requires a case-insensitive filesystem")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            attributes = root / ".gitattributes"
            write_text(
                attributes,
                "* text=auto\n.gitattributes text eol=lf\n*.txt text eol=lf\n",
            )
            target = root / "Canonical.txt"
            target.write_bytes(b"canonical\n")

            with self.assertRaisesRegex(
                generator.ChecksumError,
                "exact on-disk path spelling",
            ):
                generator.validate_covered_file_line_endings(
                    root,
                    [attributes, root / "canonical.txt"],
                )

    def test_default_covered_paths_close_genesis_normative_anchors(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        profile = json.loads(
            (repo_root / "release-artifacts/genesis-deployment-profile.json").read_text(
                encoding="utf-8"
            )
        )
        normative_paths = {
            Path(anchor.split("#", 1)[0])
            for entry in profile["entries"]
            for anchor in entry["normative_anchors"]
        }
        self.assert_committed_checksums_cover(normative_paths)

    def test_committed_checksums_cover_permanence_package_artifacts(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        expected_paths = {
            "release-artifacts/latest/one-of-one-permanence-manifest.json",
            "release-artifacts/permanence/one-of-one-permanence-template.permanence.json",
            "release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md",
            "release-artifacts/schema/one-of-one-permanence-package.schema.json",
        }

        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            relative_path: digest
            for digest, relative_path in generator.parse_checksum_file(checksum_text)
        }
        self.assertTrue(expected_paths <= set(checksum_entries))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}

        for relative_path in expected_paths:
            path = repo_root / relative_path
            expected_hash = generator.file_sha256(path)
            self.assertEqual(
                checksum_entries[relative_path],
                expected_hash.removeprefix("sha256:"),
            )
            self.assertIn(relative_path, manifest_entries)
            self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
            self.assertEqual(
                manifest_entries[relative_path]["size_bytes"],
                path.stat().st_size,
            )

    def test_committed_checksums_cover_retained_live_audit_reports(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        expected_paths = {
            "release-artifacts/evidence/live-audit-reports/20260614T015000Z-release-evidence-live-audit-dry-run.json",
            "release-artifacts/evidence/live-audit-reports/20260614T015000Z-release-evidence-live-audit-dry-run.md",
            "release-artifacts/latest/release-evidence-live-audit-report-archive.json",
            "release-artifacts/latest/release-evidence-live-audit-report-archive.md",
        }

        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            relative_path: digest
            for digest, relative_path in generator.parse_checksum_file(checksum_text)
        }
        self.assertTrue(expected_paths <= set(checksum_entries))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}

        for relative_path in expected_paths:
            path = repo_root / relative_path
            expected_hash = generator.file_sha256(path)
            self.assertEqual(
                checksum_entries[relative_path],
                expected_hash.removeprefix("sha256:"),
            )
            self.assertIn(relative_path, manifest_entries)
            self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
            self.assertEqual(
                manifest_entries[relative_path]["size_bytes"],
                path.stat().st_size,
            )

    def test_committed_checksums_cover_bytecode_release_proof(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = "release-artifacts/latest/bytecode-release-proof.json"
        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            path: digest for digest, path in generator.parse_checksum_file(checksum_text)
        }
        self.assertIn(relative_path, checksum_entries)

        proof_path = repo_root / relative_path
        expected_hash = generator.file_sha256(proof_path)
        self.assertEqual(checksum_entries[relative_path], expected_hash.removeprefix("sha256:"))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}
        self.assertIn(relative_path, manifest_entries)
        self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
        self.assertEqual(manifest_entries[relative_path]["size_bytes"], proof_path.stat().st_size)

    def test_committed_checksums_cover_release_candidate_lockfile(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = "release-artifacts/latest/release-candidate-lockfile.json"
        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            path: digest for digest, path in generator.parse_checksum_file(checksum_text)
        }
        self.assertIn(relative_path, checksum_entries)

        lockfile_path = repo_root / relative_path
        expected_hash = generator.file_sha256(lockfile_path)
        self.assertEqual(checksum_entries[relative_path], expected_hash.removeprefix("sha256:"))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}
        self.assertIn(relative_path, manifest_entries)
        self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
        self.assertEqual(
            manifest_entries[relative_path]["size_bytes"],
            lockfile_path.stat().st_size,
        )

    def test_committed_checksums_cover_protocol_surface_report(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = "release-artifacts/latest/protocol-surface-report.json"
        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            path: digest for digest, path in generator.parse_checksum_file(checksum_text)
        }
        self.assertIn(relative_path, checksum_entries)

        report_path = repo_root / relative_path
        expected_hash = generator.file_sha256(report_path)
        self.assertEqual(checksum_entries[relative_path], expected_hash.removeprefix("sha256:"))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}
        self.assertIn(relative_path, manifest_entries)
        self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
        self.assertEqual(
            manifest_entries[relative_path]["size_bytes"],
            report_path.stat().st_size,
        )

    def test_committed_checksums_cover_risk_register(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        relative_path = "release-artifacts/latest/risk-register.json"
        checksum_text = (
            repo_root / generator.DEFAULT_OUTPUT_DIR / generator.CHECKSUM_FILE_NAME
        ).read_text(encoding="utf-8")
        checksum_entries = {
            path: digest for digest, path in generator.parse_checksum_file(checksum_text)
        }
        self.assertIn(relative_path, checksum_entries)

        register_path = repo_root / relative_path
        expected_hash = generator.file_sha256(register_path)
        self.assertEqual(checksum_entries[relative_path], expected_hash.removeprefix("sha256:"))

        manifest = json.loads(
            (
                repo_root
                / generator.DEFAULT_OUTPUT_DIR
                / generator.CHECKSUM_MANIFEST_NAME
            ).read_text(encoding="utf-8")
        )
        manifest_entries = {entry["path"]: entry for entry in manifest["files"]}
        self.assertIn(relative_path, manifest_entries)
        self.assertEqual(manifest_entries[relative_path]["sha256"], expected_hash)
        self.assertEqual(
            manifest_entries[relative_path]["size_bytes"],
            register_path.stat().st_size,
        )

    def test_generator_writes_sorted_checksums_and_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR
            latest_dir = root / "release-artifacts" / "latest"
            write_text(latest_dir / "event-topic-catalog.json", '{"events":[]}\n')
            write_text(latest_dir / "abi-checksums.json", '{"abis":[]}\n')
            write_text(latest_dir / "release-manifest.json", '{"release":{}}\n')
            write_text(
                root / "release-artifacts" / "baselines" / "v0.1.0" / "gas-snapshot.snap",
                "StreamGasSnapshotTest:testGasFixedPriceMint() (gas: 1)\n",
            )
            write_text(
                root / "deployments" / "examples" / "anvil.json",
                '{"chain":31337}\n',
            )

            written = generator.write_outputs(
                root,
                [
                    Path("release-artifacts/latest"),
                    Path("release-artifacts/baselines"),
                    Path("deployments/examples"),
                ],
                output_dir,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            self.assertEqual(
                [path.name for path in written],
                ["SHA256SUMS", "release-checksums.json"],
            )

            checksum_lines = (output_dir / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
            covered_paths = [line.split("  ", 1)[1] for line in checksum_lines]
            self.assertEqual(
                covered_paths,
                [
                    "deployments/examples/anvil.json",
                    "release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
                    "release-artifacts/latest/abi-checksums.json",
                    "release-artifacts/latest/event-topic-catalog.json",
                    "release-artifacts/latest/release-manifest.json",
                ],
            )
            self.assertNotIn("release-artifacts/latest/SHA256SUMS", covered_paths)
            self.assertNotIn("release-artifacts/latest/release-checksums.json", covered_paths)

            manifest = json.loads(
                (output_dir / "release-checksums.json").read_text(encoding="utf-8")
            )
            self.assertEqual(manifest["schema_version"], generator.CHECKSUM_SCHEMA)
            self.assertEqual(manifest["algorithm"], "sha256")
            self.assertEqual(
                manifest["source"]["coverage_policy"],
                generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            self.assertEqual(
                manifest["source"]["output_dir"],
                CUSTOM_OUTPUT_DIR.as_posix(),
            )
            self.assertEqual(
                manifest["source"]["covered_paths"],
                [
                    "release-artifacts/latest",
                    "release-artifacts/baselines",
                    "deployments/examples",
                ],
            )
            self.assertEqual(
                manifest["text_checksum_file"]["sha256"],
                generator.sha256_bytes((output_dir / "SHA256SUMS").read_bytes()),
            )
            self.assertEqual(
                [entry["path"] for entry in manifest["files"]],
                covered_paths,
            )

    def test_check_mode_accepts_current_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR
            write_text(
                root / "release-artifacts/latest/abi-checksums.json",
                '{"abis":[]}\n',
            )
            generator.write_outputs(
                root,
                [Path("release-artifacts/latest")],
                output_dir,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )
            self.assertEqual(result, 0)

    def test_check_mode_rejects_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR
            artifact = root / "release-artifacts/latest/abi-checksums.json"
            write_text(artifact, '{"abis":[]}\n')
            generator.write_outputs(
                root,
                [Path("release-artifacts/latest")],
                output_dir,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            write_text(artifact, '{"abis":["changed"]}\n')

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )
            self.assertEqual(result, 1)
            self.assertIn(
                "hash mismatch for release-artifacts/latest/abi-checksums.json",
                stderr.getvalue(),
            )
            self.assertIn(
                f"changed {CUSTOM_OUTPUT_DIR.as_posix()}/SHA256SUMS",
                stderr.getvalue(),
            )

    def test_check_mode_rejects_deleted_covered_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR
            artifact = root / "release-artifacts/latest/abi-checksums.json"
            write_text(artifact, '{"abis":[]}\n')
            generator.write_outputs(
                root,
                [Path("release-artifacts/latest")],
                output_dir,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            artifact.unlink()

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )
            self.assertEqual(result, 1)
            missing_message = (
                "missing covered file listed in SHA256SUMS: "
                "release-artifacts/latest/abi-checksums.json"
            )
            self.assertIn(
                missing_message,
                stderr.getvalue(),
            )

    def test_check_mode_rejects_missing_generated_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR
            write_text(
                root / "release-artifacts/latest/abi-checksums.json",
                '{"abis":[]}\n',
            )
            generator.write_outputs(
                root,
                [Path("release-artifacts/latest")],
                output_dir,
                coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
            )
            (output_dir / "SHA256SUMS").unlink()

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    [Path("release-artifacts/latest")],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )
            self.assertEqual(result, 1)
            self.assertIn(
                f"missing {CUSTOM_OUTPUT_DIR.as_posix()}/SHA256SUMS",
                stderr.getvalue(),
            )

    def test_generator_rejects_missing_covered_root(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR

            with self.assertRaisesRegex(generator.ChecksumError, "covered path does not exist"):
                generator.build_outputs(
                    root,
                    [Path("missing")],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )

    def test_generator_rejects_empty_covered_set(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output_dir = root / CUSTOM_OUTPUT_DIR
            (root / "empty").mkdir()

            with self.assertRaisesRegex(generator.ChecksumError, "did not contain any files"):
                generator.build_outputs(
                    root,
                    [Path("empty")],
                    output_dir,
                    coverage_policy=generator.CUSTOM_SUBSET_COVERAGE_POLICY,
                )

    def test_checksum_parser_rejects_parent_directory_paths(self) -> None:
        checksum = (
            "0" * 64
            + "  release-artifacts/latest/../secrets.json\n"
        )

        with self.assertRaisesRegex(generator.ChecksumError, "path traversal"):
            generator.parse_checksum_file(checksum)


if __name__ == "__main__":
    unittest.main(verbosity=2)
