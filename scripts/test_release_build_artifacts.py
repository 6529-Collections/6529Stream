#!/usr/bin/env python3
"""Focused tests for isolated canonical release builds."""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Any, Iterator
from unittest.mock import patch

import check_contract_size_budget as size_checker
import check_core_bytecode_spend_policy as core_checker


SCRIPT_PATH = Path(__file__).with_name("build_release_artifacts.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
CHANGELOG_PATH = REPO_ROOT / "CHANGELOG.md"
MAKEFILE_PATH = REPO_ROOT / "Makefile"
CHECK_PS1_PATH = REPO_ROOT / "scripts" / "check.ps1"
CHECK_SH_PATH = REPO_ROOT / "scripts" / "check.sh"
CI_PATH = REPO_ROOT / ".github" / "workflows" / "ci.yml"
README_PATH = REPO_ROOT / "README.md"
TEST_README_PATH = REPO_ROOT / "test" / "README.md"
TOOLING_PATH = REPO_ROOT / "docs" / "tooling.md"
DEPLOYMENT_DOC_PATH = REPO_ROOT / "docs" / "deployment.md"
WARNING_DISPOSITIONS_PATH = REPO_ROOT / "docs" / "warning-dispositions.md"
DEPLOYMENT_README_PATH = REPO_ROOT / "deployments" / "README.md"
RELEASE_ARTIFACTS_README_PATH = REPO_ROOT / "release-artifacts" / "README.md"
SIZE_LOG_PATH = REPO_ROOT / "scripts" / "run_forge_size_log.py"
SPEC = importlib.util.spec_from_file_location("build_release_artifacts", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)

GENERATOR_PATH = Path(__file__).with_name("generate_release_artifacts.py")
GENERATOR_SPEC = importlib.util.spec_from_file_location(
    "generate_release_artifacts_for_build_test",
    GENERATOR_PATH,
)
assert GENERATOR_SPEC is not None and GENERATOR_SPEC.loader is not None
release_generator = importlib.util.module_from_spec(GENERATOR_SPEC)
GENERATOR_SPEC.loader.exec_module(release_generator)

FAKE_FORGE_VERSION = (
    "forge Version: 1.7.1\n"
    "Commit SHA: fixture\n"
    "Build Timestamp: fixture\n"
    "Build Profile: fixture"
)


@contextmanager
def working_directory(path: Path) -> Iterator[None]:
    previous = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_tree(root: Path) -> dict[str, Path]:
    config = root / "release-artifacts" / "contracts.json"
    foundry_config = root / "foundry.toml"
    output = root / builder.DEFAULT_OUTPUT_DIR
    write_text(
        foundry_config,
        "\n".join(
            [
                "[profile.default]",
                'src = "smart-contracts"',
                'test = "test"',
                'script = "script"',
                'out = "out"',
                'cache_path = "cache"',
                'solc_version = "0.8.19"',
                "auto_detect_solc = false",
                'evm_version = "paris"',
                "optimizer = true",
                "optimizer_runs = 200",
                'bytecode_hash = "none"',
                "cbor_metadata = false",
                "",
            ]
        ),
    )
    write_text(
        root / "smart-contracts" / "Example.sol",
        (
            "// SPDX-License-Identifier: MIT\n"
            "pragma solidity 0.8.19;\n"
            'import "./Shared.sol";\n'
            "contract Example {}\n"
            "contract ExampleTwo {}\n"
        ),
    )
    write_text(
        root / "smart-contracts" / "Shared.sol",
        "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\nlibrary Shared {}\n",
    )
    write_text(
        root / "smart-contracts" / "IExample.sol",
        "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\ninterface IExample {}\n",
    )
    write_json(
        config,
        {
            "schema_version": "6529stream.release-artifact-contracts.v1",
            "production_contracts": [
                {"name": "Example", "source": "smart-contracts/Example.sol"},
                {"name": "ExampleTwo", "source": "smart-contracts/Example.sol"},
            ],
            "interfaces": [
                {"name": "IExample", "source": "smart-contracts/IExample.sol"}
            ],
            "runtime_size_budget": {
                "schema_version": size_checker.BUDGET_SCHEMA,
                "eip_170_runtime_limit_bytes": 24_576,
                "contracts": {
                    "Example": {
                        "source": "smart-contracts/Example.sol",
                        "minimum_runtime_margin_bytes": 0,
                        "warning_runtime_margin_bytes": 0,
                        "tracking": "https://example.test/release-size-budget",
                    }
                },
            },
        },
    )
    return {
        "config": config,
        "foundry_config": foundry_config,
        "output": output,
        "shared": root / "smart-contracts" / "Shared.sol",
    }


def artifact(
    source: str,
    name: str,
    metadata_sources: dict[str, str],
    *,
    compilation_target: dict[str, str] | None = None,
) -> dict[str, Any]:
    return {
        "abi": [],
        "bytecode": {"object": "0x6000"},
        "deployedBytecode": {"object": "0x6001"},
        "methodIdentifiers": {},
        "metadata": {
            "compiler": {"version": builder.SOLC_LONG_VERSION},
            "language": "Solidity",
            "settings": {
                "compilationTarget": compilation_target or {source: name},
                "evmVersion": builder.EVM_VERSION,
                "metadata": {"bytecodeHash": "none", "appendCBOR": False},
                "optimizer": {"enabled": True, "runs": builder.OPTIMIZER_RUNS},
                "viaIR": True,
            },
            "sources": {
                path: {"keccak256": source_hash}
                for path, source_hash in metadata_sources.items()
            },
            "version": 1,
        },
    }


class FakeForge:
    def __init__(
        self,
        *,
        wrong_target: bool = False,
        compiler_input_extra_source: str | None = None,
        compiler_path_overrides: dict[str, object] | None = None,
    ) -> None:
        self.commands: list[list[str]] = []
        self.cwd_values: list[Path] = []
        self.wrong_target = wrong_target
        self.compiler_input_extra_source = compiler_input_extra_source
        self.compiler_path_overrides = compiler_path_overrides

    def __call__(self, command: list[str], cwd: Path) -> None:
        self.commands.append(command)
        self.cwd_values.append(cwd)
        source = command[2]
        out_dir = Path(command[command.index("--out") + 1])
        names = (
            ["Example", "ExampleTwo"]
            if Path(source).name == "Example.sol"
            else ["IExample"]
        )
        source_paths = [source]
        if Path(source).name == "Example.sol":
            source_paths.append("smart-contracts/Shared.sol")
            if self.compiler_input_extra_source is not None:
                source_paths.append(self.compiler_input_extra_source)
        source_contents = {
            path: (cwd / path).read_bytes().decode("utf-8")
            for path in source_paths
        }
        source_hashes = {
            path: builder.keccak256_hex(content.encode("utf-8"))
            for path, content in source_contents.items()
        }
        for name in names:
            target = {"smart-contracts/Wrong.sol": name} if self.wrong_target else None
            write_json(
                out_dir / Path(source).name / f"{name}.json",
                artifact(
                    source,
                    name,
                    source_hashes,
                    compilation_target=target,
                ),
            )
        build_info_dir = Path(command[command.index("--build-info-path") + 1])
        write_json(
            build_info_dir / "build-info.json",
            {
                "id": "fixture",
                "input": {
                    "language": "Solidity",
                    "sources": {
                        path: {"content": content}
                        for path, content in source_contents.items()
                    },
                    "settings": {
                        "evmVersion": builder.EVM_VERSION,
                        "metadata": {"bytecodeHash": "none", "appendCBOR": False},
                        "optimizer": {
                            "enabled": True,
                            "runs": builder.OPTIMIZER_RUNS,
                        },
                        "outputSelection": {"*": {"*": ["abi"]}},
                        "viaIR": True,
                    },
                    **(
                        self.compiler_path_overrides
                        if self.compiler_path_overrides is not None
                        else {
                            "allowPaths": [
                                cwd.resolve().as_posix(),
                                (cwd.resolve() / "lib").as_posix(),
                            ],
                            "basePath": cwd.resolve().as_posix(),
                            "includePaths": [cwd.resolve().as_posix()],
                        }
                    ),
                },
            },
        )
        write_json(
            out_dir / "Imported.sol" / "Imported.json",
            artifact(
                "smart-contracts/Shared.sol",
                "Imported",
                {
                    "smart-contracts/Shared.sol": source_hashes.get(
                        "smart-contracts/Shared.sol",
                        builder.keccak256_hex(
                            (cwd / "smart-contracts/Shared.sol").read_bytes()
                        ),
                    )
                },
            ),
        )


class ReleaseBuildArtifactTests(unittest.TestCase):
    def test_builds_each_target_in_an_isolated_import_closure(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            fake = FakeForge()

            with redirect_stdout(StringIO()):
                manifest = builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    "fake-forge",
                    fake,
                    FAKE_FORGE_VERSION,
                )

            self.assertEqual(len(fake.commands), 2)
            self.assertEqual(fake.cwd_values, [root.resolve(), root.resolve()])
            self.assertEqual({command[2] for command in fake.commands}, {
                "smart-contracts/Example.sol",
                "smart-contracts/IExample.sol",
            })
            self.assertTrue(all(command[3] == "--root" for command in fake.commands))
            out_dirs = [Path(command[command.index("--out") + 1]) for command in fake.commands]
            cache_dirs = [
                Path(command[command.index("--cache-path") + 1])
                for command in fake.commands
            ]
            self.assertEqual(len(set(out_dirs)), 2)
            self.assertEqual(len(set(cache_dirs)), 2)
            for command in fake.commands:
                self.assertIn("--via-ir", command)
                self.assertIn("--no-metadata", command)
                self.assertIn("--build-info", command)
                self.assertIn("--use-literal-content", command)
                self.assertNotIn("--profile", command)
                self.assertEqual(command[command.index("--use") + 1], "0.8.19")
                self.assertEqual(command[command.index("--optimizer-runs") + 1], "200")

            actual_files = {
                path.relative_to(paths["output"]).as_posix()
                for path in paths["output"].rglob("*")
                if path.is_file()
            }
            self.assertEqual(
                actual_files,
                {
                    "Example.sol/Example.json",
                    "Example.sol/ExampleTwo.json",
                    "IExample.sol/IExample.json",
                    "compiler-inputs/000-Example.json",
                    "compiler-inputs/001-IExample.json",
                    builder.MANIFEST_FILENAME,
                },
            )
            self.assertEqual(manifest["output_dir"], "out-release")
            self.assertEqual(manifest["policy"]["forge_version"], FAKE_FORGE_VERSION)
            self.assertEqual(
                manifest["policy"]["foundry_version"],
                builder.FOUNDRY_VERSION,
            )
            self.assertEqual(manifest["policy"]["forge_profile"], "default")
            self.assertEqual(
                manifest["policy"]["controlled_forge_environment"],
                {"FOUNDRY_PROFILE": "default"},
            )
            self.assertEqual(
                manifest["policy"]["restricted_source_roots"],
                ["script", "test"],
            )
            self.assertEqual(
                manifest["policy"]["sanitized_environment_prefixes"],
                ["DAPP_", "FOUNDRY_"],
            )
            records = {record["name"]: record for record in manifest["targets"]}
            self.assertEqual(
                records["Example"]["artifact_path"],
                "out-release/Example.sol/Example.json",
            )
            self.assertEqual(
                records["Example"]["forge_environment"],
                {"FOUNDRY_PROFILE": "default"},
            )
            self.assertEqual(
                [item["path"] for item in records["Example"]["metadata_sources"]],
                ["smart-contracts/Example.sol", "smart-contracts/Shared.sol"],
            )
            self.assertEqual(
                [item["path"] for item in records["IExample"]["metadata_sources"]],
                ["smart-contracts/IExample.sol"],
            )
            self.assertEqual(
                records["Example"]["canonical_source_universe_sha256"],
                records["ExampleTwo"]["canonical_source_universe_sha256"],
            )
            self.assertEqual(records["Example"]["forge_argv"][2], "smart-contracts/Example.sol")
            self.assertNotEqual(
                records["Example"]["canonical_build_input_sha256"],
                records["ExampleTwo"]["canonical_build_input_sha256"],
            )
            self.assertEqual(
                records["Example"]["compiler_input_ordered_sha256"],
                records["ExampleTwo"]["compiler_input_ordered_sha256"],
            )
            self.assertEqual(
                records["Example"]["compiler_input_path"],
                "out-release/compiler-inputs/000-Example.json",
            )
            retained_input = json.loads(
                (
                    paths["output"]
                    / "compiler-inputs"
                    / "000-Example.json"
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(
                {
                    field: retained_input[field]
                    for field in builder.PORTABLE_COMPILER_PATHS
                },
                builder.PORTABLE_COMPILER_PATHS,
            )
            self.assertEqual(
                manifest["policy"]["portable_compiler_paths"],
                builder.PORTABLE_COMPILER_PATHS,
            )

    def test_release_receipt_is_identical_across_worktree_roots(self) -> None:
        with (
            tempfile.TemporaryDirectory() as first_dir,
            tempfile.TemporaryDirectory() as second_dir,
        ):
            roots = (Path(first_dir), Path(second_dir))
            outputs: list[tuple[dict[str, Any], list[bytes]]] = []
            for root in roots:
                paths = seed_tree(root)
                with redirect_stdout(StringIO()):
                    manifest = builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        "fake-forge",
                        FakeForge(),
                        FAKE_FORGE_VERSION,
                    )
                retained = [
                    path.read_bytes()
                    for path in sorted(
                        (paths["output"] / "compiler-inputs").glob("*.json")
                    )
                ]
                outputs.append((manifest, retained))

            self.assertEqual(outputs[0], outputs[1])
            self.assertEqual(
                builder.file_sha256(
                    roots[0] / builder.DEFAULT_OUTPUT_DIR / builder.MANIFEST_FILENAME
                ),
                builder.file_sha256(
                    roots[1] / builder.DEFAULT_OUTPUT_DIR / builder.MANIFEST_FILENAME
                ),
            )

    def test_rejects_noncanonical_raw_compiler_path_controls(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            raw_root = root.resolve().as_posix()
            raw_lib = (root.resolve() / "lib").as_posix()
            cases = {
                "outside base": {
                    "allowPaths": [raw_root, raw_lib],
                    "basePath": (root.parent / "outside").resolve().as_posix(),
                    "includePaths": [raw_root],
                },
                "extra allow path": {
                    "allowPaths": [raw_root, raw_lib, raw_root],
                    "basePath": raw_root,
                    "includePaths": [raw_root],
                },
                "reordered allow paths": {
                    "allowPaths": [raw_lib, raw_root],
                    "basePath": raw_root,
                    "includePaths": [raw_root],
                },
                "extra include path": {
                    "allowPaths": [raw_root, raw_lib],
                    "basePath": raw_root,
                    "includePaths": [raw_root, raw_lib],
                },
                "relative raw paths": builder.PORTABLE_COMPILER_PATHS,
            }
            for label, controls in cases.items():
                with self.subTest(case=label):
                    paths = seed_tree(root)
                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "before portable retention",
                    ):
                        with redirect_stdout(StringIO()):
                            builder.build_release_output(
                                root,
                                paths["config"],
                                paths["foundry_config"],
                                paths["output"],
                                "fake-forge",
                                FakeForge(compiler_path_overrides=controls),
                                FAKE_FORGE_VERSION,
                            )

    def test_rejects_test_and_script_sources_from_build_info_compiler_input(self) -> None:
        for restricted_source in (
            "test/ReleaseLeak.t.sol",
            "script/ReleaseLeak.s.sol",
        ):
            with self.subTest(source=restricted_source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    write_text(
                        root / restricted_source,
                        (
                            "// SPDX-License-Identifier: MIT\n"
                            "pragma solidity 0.8.19;\n"
                            "contract ReleaseLeak {}\n"
                        ),
                    )
                    fake = FakeForge(
                        compiler_input_extra_source=restricted_source,
                    )

                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "restricted canonical release source root",
                    ):
                        with redirect_stdout(StringIO()):
                            builder.build_release_output(
                                root,
                                paths["config"],
                                paths["foundry_config"],
                                paths["output"],
                                runner=fake,
                                forge_version_output=FAKE_FORGE_VERSION,
                            )

                    self.assertEqual(len(fake.commands), 1)
                    self.assertFalse(paths["output"].exists())

    def test_rejects_restricted_configured_target_before_compiling(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            restricted_source = "test/ConfiguredReleaseTarget.t.sol"
            write_text(
                root / restricted_source,
                (
                    "// SPDX-License-Identifier: MIT\n"
                    "pragma solidity 0.8.19;\n"
                    "contract ConfiguredReleaseTarget {}\n"
                ),
            )
            config = json.loads(paths["config"].read_text(encoding="utf-8"))
            config["production_contracts"][0] = {
                "name": "ConfiguredReleaseTarget",
                "source": restricted_source,
            }
            write_json(paths["config"], config)
            fake = FakeForge()

            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "restricted canonical release source root",
            ):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            self.assertEqual(fake.commands, [])

    def test_rejects_restricted_source_aliases_after_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir).resolve()
            cases = [
                (
                    "dot segment",
                    Path("smart-contracts") / ".." / "test" / "DotAlias.t.sol",
                    root / "test" / "DotAlias.t.sol",
                ),
                (
                    "absolute path",
                    root / "script" / "AbsoluteAlias.s.sol",
                    root / "script" / "AbsoluteAlias.s.sol",
                ),
                (
                    "mixed-case root",
                    Path("TeSt") / "MixedCaseAlias.t.sol",
                    root / "test" / "MixedCaseAlias.t.sol",
                ),
            ]
            if os.name == "nt":
                cases.extend(
                    [
                        (
                            "Windows separator",
                            Path(r"test\WindowsAlias.t.sol"),
                            root / "test" / "WindowsAlias.t.sol",
                        ),
                        (
                            "Windows trailing-dot root",
                            Path("test.") / "TrailingDotAlias.t.sol",
                            root / "test" / "TrailingDotAlias.t.sol",
                        ),
                    ]
                )

            for label, alias, source_path in cases:
                with self.subTest(alias=label):
                    write_text(
                        source_path,
                        (
                            "// SPDX-License-Identifier: MIT\n"
                            "pragma solidity 0.8.19;\n"
                            "contract RestrictedAlias {}\n"
                        ),
                    )
                    resolved = builder.resolve_repo_path(
                        root,
                        alias,
                        f"{label} source",
                    )
                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "restricted canonical release source root",
                    ):
                        builder.reject_restricted_release_source(
                            root,
                            resolved,
                            f"{label} source",
                        )

    @unittest.skipUnless(os.name == "nt", "Windows 8.3 aliases are Windows-only")
    def test_rejects_restricted_windows_short_path_alias(self) -> None:
        import ctypes

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir).resolve()
            source_path = root / "test" / "ShortPathAlias.t.sol"
            write_text(
                source_path,
                (
                    "// SPDX-License-Identifier: MIT\n"
                    "pragma solidity 0.8.19;\n"
                    "contract RestrictedShortPathAlias {}\n"
                ),
            )
            buffer = ctypes.create_unicode_buffer(32_768)
            length = ctypes.windll.kernel32.GetShortPathNameW(  # type: ignore[attr-defined]
                str(source_path),
                buffer,
                len(buffer),
            )
            if length == 0 or length >= len(buffer):
                self.skipTest("Windows did not return an 8.3 alias")
            short_path = Path(buffer.value)
            if str(short_path).casefold() == str(source_path).casefold():
                self.skipTest("8.3 aliases are unavailable for the temporary directory")

            resolved = builder.resolve_repo_path(
                root,
                short_path,
                "Windows 8.3 source",
            )
            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "restricted canonical release source root",
            ):
                builder.reject_restricted_release_source(
                    root,
                    resolved,
                    "Windows 8.3 source",
                )

    def test_rejects_test_and_script_sources_from_artifact_metadata(self) -> None:
        for restricted_source in (
            "test/MetadataLeak.t.sol",
            "script/MetadataLeak.s.sol",
        ):
            with self.subTest(source=restricted_source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_tree(root)
                    source_path = root / restricted_source
                    write_text(
                        source_path,
                        (
                            "// SPDX-License-Identifier: MIT\n"
                            "pragma solidity 0.8.19;\n"
                            "contract MetadataLeak {}\n"
                        ),
                    )
                    metadata = {
                        "sources": {
                            restricted_source: {
                                "keccak256": builder.keccak256_hex(
                                    source_path.read_bytes()
                                )
                            }
                        }
                    }

                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "restricted canonical release source root",
                    ):
                        builder.metadata_source_records(
                            root.resolve(),
                            metadata,
                            "metadata fixture",
                        )

    def test_aggregate_size_build_is_labeled_diagnostic(self) -> None:
        expected_phrases = {
            README_PATH: "aggregate size/warning step is diagnostic only",
            TEST_README_PATH: "warning and whole-tree size diagnostic only",
            TOOLING_PATH: "warning-collection and whole-tree size diagnostic",
            DEPLOYMENT_DOC_PATH: "warning and whole-tree size diagnostic;",
            WARNING_DISPOSITIONS_PATH: (
                "log is therefore warning evidence, not production bytecode"
            ),
            DEPLOYMENT_README_PATH: "command is diagnostic only",
            RELEASE_ARTIFACTS_README_PATH: "warnings and whole-tree size diagnostics",
            SIZE_LOG_PATH: "aggregate size/warning diagnostic",
            CI_PATH: "name: Aggregate size and warning diagnostic",
            MAKEFILE_PATH: (
                "Aggregate diagnostic only; canonical release bytecode is built"
            ),
            CHANGELOG_PATH: "aggregate size/warning diagnostic output is retained",
        }
        for path, phrase in expected_phrases.items():
            with self.subTest(path=path.relative_to(REPO_ROOT).as_posix()):
                self.assertIn(
                    phrase,
                    path.read_text(encoding="utf-8"),
                )

        canonical_commands = [
            "python scripts/test_release_build_artifacts.py",
            builder.CANONICAL_BUILD_COMMAND,
            f"{builder.CANONICAL_BUILD_COMMAND} --check",
            "python scripts/generate_release_artifacts.py",
        ]
        for path in (
            DEPLOYMENT_DOC_PATH,
            DEPLOYMENT_README_PATH,
            RELEASE_ARTIFACTS_README_PATH,
        ):
            with self.subTest(path=path.relative_to(REPO_ROOT).as_posix()):
                text = path.read_text(encoding="utf-8")
                positions = [text.index(command) for command in canonical_commands]
                self.assertEqual(positions, sorted(positions))

        banned_phrases = {
            CHANGELOG_PATH: "production-size forge output",
            README_PATH: "release bytecode and EIP-170/EIP-3860 evidence",
            RELEASE_ARTIFACTS_README_PATH: (
                "not an input to release, verification, or deployment evidence"
            ),
            WARNING_DISPOSITIONS_PATH: (
                "helpers can appear only in aggregate diagnostic warnings"
            ),
        }
        for path, phrase in banned_phrases.items():
            with self.subTest(path=path.relative_to(REPO_ROOT).as_posix()):
                self.assertNotIn(phrase, path.read_text(encoding="utf-8"))

    def test_successful_replacement_is_exact_and_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            write_text(paths["output"] / "stale.txt", "stale output\n")
            write_json(
                paths["output"] / "Old.sol" / "Old.json",
                {"artifact": "must be removed"},
            )
            write_text(root / "out" / "ordinary-forge.txt", "ordinary output\n")

            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            first = {
                path.relative_to(paths["output"]).as_posix(): path.read_bytes()
                for path in paths["output"].rglob("*")
                if path.is_file()
            }
            self.assertNotIn("stale.txt", first)
            self.assertNotIn("Old.sol/Old.json", first)
            self.assertNotIn("Imported.sol/Imported.json", first)
            self.assertEqual(
                (root / "out" / "ordinary-forge.txt").read_text(encoding="utf-8"),
                "ordinary output\n",
            )

            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            second = {
                path.relative_to(paths["output"]).as_posix(): path.read_bytes()
                for path in paths["output"].rglob("*")
                if path.is_file()
            }

            self.assertEqual(second, first)

    def test_check_mode_accepts_current_output_and_rejects_import_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            with (
                patch.object(
                    builder,
                    "read_forge_version",
                    return_value=FAKE_FORGE_VERSION,
                ),
                redirect_stdout(StringIO()),
                redirect_stderr(StringIO()),
            ):
                self.assertEqual(
                    builder.main(
                        [
                            "--repo-root",
                            str(root),
                            "--config",
                            str(paths["config"].relative_to(root)),
                            "--foundry-config",
                            str(paths["foundry_config"].relative_to(root)),
                            "--output-dir",
                            "out-release",
                            "--check",
                        ]
                    ),
                    0,
                )

            with self.assertRaisesRegex(builder.ReleaseBuildError, "different Forge version"):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    expected_forge_version=FAKE_FORGE_VERSION.replace(
                        "Commit SHA: fixture",
                        "Commit SHA: different",
                    ),
                )

            write_text(
                paths["shared"],
                "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\nlibrary Changed {}\n",
            )
            with self.assertRaisesRegex(builder.ReleaseBuildError, "metadata keccak256"):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

    def test_size_checker_rejects_aggregate_output_and_missing_receipt(self) -> None:
        cases = (
            ("aggregate output", "out", "canonical repository out-release"),
            ("missing receipt", "out-release", "missing required file"),
        )
        for label, foundry_out, expected_error in cases:
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    stderr = StringIO()
                    with redirect_stdout(StringIO()), redirect_stderr(stderr):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                foundry_out,
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(
                        "canonical release output validation failed",
                        stderr.getvalue(),
                    )
                    self.assertIn(expected_error, stderr.getvalue())

    def test_size_and_core_checkers_accept_valid_canonical_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            custom_foundry_config = root / "config" / "release-foundry.toml"
            write_text(
                custom_foundry_config,
                paths["foundry_config"].read_text(encoding="utf-8"),
            )
            paths["foundry_config"] = custom_foundry_config
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            common_args = [
                "--repo-root",
                str(root),
                "--config",
                str(paths["config"].relative_to(root)),
                "--foundry-config",
                str(paths["foundry_config"].relative_to(root)),
                "--foundry-out",
                builder.DEFAULT_OUTPUT_DIR.as_posix(),
            ]
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(size_checker.main(common_args), 0)

            with (
                patch.object(core_checker, "check_policy", return_value=0) as policy,
                redirect_stdout(StringIO()),
                redirect_stderr(StringIO()),
            ):
                self.assertEqual(core_checker.main(common_args), 0)
            validated_manifest = policy.call_args.args[3]
            self.assertIsInstance(validated_manifest, dict)
            policy.assert_called_once_with(
                root.resolve(),
                Path(paths["config"].relative_to(root)),
                builder.DEFAULT_OUTPUT_DIR,
                validated_manifest,
            )

            noncanonical_args = [
                *common_args[:-1],
                "out",
            ]
            stderr = StringIO()
            with (
                patch.object(core_checker, "check_policy", return_value=0) as policy,
                redirect_stdout(StringIO()),
                redirect_stderr(stderr),
            ):
                self.assertEqual(core_checker.main(noncanonical_args), 1)
            policy.assert_not_called()
            self.assertIn("canonical repository out-release", stderr.getvalue())

    def test_size_checker_rejects_consumed_file_mutation_after_receipt_validation(
        self,
    ) -> None:
        for mutated_file in ("artifact", "config"):
            with self.subTest(mutated_file=mutated_file):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )

                    mutation_path = (
                        paths["output"] / "Example.sol" / "Example.json"
                        if mutated_file == "artifact"
                        else paths["config"]
                    )
                    original_validate = size_checker.validate_canonical_release_output

                    def validate_then_mutate(*args: Any, **kwargs: Any) -> dict[str, Any]:
                        manifest = original_validate(*args, **kwargs)
                        mutation_path.write_bytes(mutation_path.read_bytes() + b"\n")
                        return manifest

                    stderr = StringIO()
                    with (
                        patch.object(
                            size_checker,
                            "validate_canonical_release_output",
                            side_effect=validate_then_mutate,
                        ),
                        redirect_stdout(StringIO()),
                        redirect_stderr(stderr),
                    ):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                builder.DEFAULT_OUTPUT_DIR.as_posix(),
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(
                        "no longer matches the validated canonical release receipt",
                        stderr.getvalue(),
                    )

    def test_size_checker_rejects_restricted_source_in_retained_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            restricted_source = "test/ReceiptLeak.t.sol"
            restricted_content = (
                "// SPDX-License-Identifier: MIT\n"
                "pragma solidity 0.8.19;\n"
                "contract ReceiptLeak {}\n"
            )
            write_text(root / restricted_source, restricted_content)
            compiler_input_path = (
                paths["output"] / "compiler-inputs" / "000-Example.json"
            )
            compiler_input = json.loads(
                compiler_input_path.read_text(encoding="utf-8")
            )
            compiler_input["sources"][restricted_source] = {
                "content": restricted_content
            }
            compiler_input_path.write_bytes(
                builder.ordered_json_bytes(compiler_input)
            )

            manifest_path = paths["output"] / builder.MANIFEST_FILENAME
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            compiler_input_hash = builder.file_sha256(compiler_input_path)
            for record in manifest["targets"]:
                if (
                    record["compiler_input_relative_path"]
                    == "compiler-inputs/000-Example.json"
                ):
                    record["compiler_input_sha256"] = compiler_input_hash
            write_json(manifest_path, manifest)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = size_checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--config",
                        str(paths["config"].relative_to(root)),
                        "--foundry-config",
                        str(paths["foundry_config"].relative_to(root)),
                        "--foundry-out",
                        builder.DEFAULT_OUTPUT_DIR.as_posix(),
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "restricted canonical release source root",
                stderr.getvalue(),
            )

    def test_size_checker_rejects_stale_receipt_version_and_root_policy(self) -> None:
        cases = (
            ("generator version", "generator identity is invalid"),
            ("restricted-root policy", "compiler policy is stale"),
            ("portable-path policy", "compiler policy is stale"),
        )
        for mutation, expected_error in cases:
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )

                    manifest_path = paths["output"] / builder.MANIFEST_FILENAME
                    manifest = json.loads(
                        manifest_path.read_text(encoding="utf-8")
                    )
                    if mutation == "generator version":
                        manifest["generated_by"] = (
                            "scripts/build_release_artifacts.py:1"
                        )
                    elif mutation == "restricted-root policy":
                        del manifest["policy"]["restricted_source_roots"]
                    else:
                        del manifest["policy"]["portable_compiler_paths"]
                    write_json(manifest_path, manifest)

                    stderr = StringIO()
                    with redirect_stdout(StringIO()), redirect_stderr(stderr):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                builder.DEFAULT_OUTPUT_DIR.as_posix(),
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(expected_error, stderr.getvalue())

    def test_rejects_post_build_compiler_input_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            compiler_input_path = (
                paths["output"] / "compiler-inputs" / "000-Example.json"
            )
            compiler_input_path.write_bytes(
                compiler_input_path.read_bytes().replace(
                    b"contract Example",
                    b"contract Changed",
                )
            )

            with self.assertRaisesRegex(builder.ReleaseBuildError, "compiler input hash is stale"):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

    def test_validator_reads_each_receipt_bound_input_once(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            manifest = json.loads(
                (paths["output"] / builder.MANIFEST_FILENAME).read_text(
                    encoding="utf-8"
                )
            )
            tracked_paths = {
                paths["config"].resolve(),
                paths["foundry_config"].resolve(),
            }
            for record in manifest["targets"]:
                tracked_paths.add(
                    (paths["output"] / record["artifact_relative_path"]).resolve()
                )
                tracked_paths.add(
                    (
                        paths["output"]
                        / record["compiler_input_relative_path"]
                    ).resolve()
                )
            read_counts = {path: 0 for path in tracked_paths}
            original_read_bytes = Path.read_bytes

            def counted_read_bytes(path: Path) -> bytes:
                resolved = path.resolve()
                if resolved in read_counts:
                    read_counts[resolved] += 1
                return original_read_bytes(path)

            with patch.object(Path, "read_bytes", new=counted_read_bytes):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

            self.assertEqual(
                read_counts,
                {path: 1 for path in tracked_paths},
            )

    def test_builder_carries_single_input_snapshots_into_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            config_path = paths["config"].resolve()
            foundry_config_path = paths["foundry_config"].resolve()
            source_artifact_reads = {
                "Example.json": 0,
                "ExampleTwo.json": 0,
                "IExample.json": 0,
            }
            input_reads = {
                config_path: 0,
                foundry_config_path: 0,
            }
            original_read_bytes = Path.read_bytes

            def counted_read_bytes(path: Path) -> bytes:
                resolved = path.resolve()
                if resolved in input_reads:
                    input_reads[resolved] += 1
                if (
                    path.name in source_artifact_reads
                    and path.parent.name.endswith(".sol")
                    and "targets" in path.parts
                ):
                    source_artifact_reads[path.name] += 1
                return original_read_bytes(path)

            with (
                patch.object(Path, "read_bytes", new=counted_read_bytes),
                redirect_stdout(StringIO()),
            ):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            # One initial producer snapshot plus staged and installed validation.
            self.assertEqual(input_reads[config_path], 3)
            self.assertEqual(input_reads[foundry_config_path], 3)
            self.assertEqual(
                source_artifact_reads,
                {name: 1 for name in source_artifact_reads},
            )

    def test_validator_rejects_absolute_path_reintroduced_into_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            relative_input = "compiler-inputs/000-Example.json"
            compiler_input_path = paths["output"] / relative_input
            compiler_input = json.loads(
                compiler_input_path.read_text(encoding="utf-8")
            )
            compiler_input["basePath"] = root.resolve().as_posix()
            compiler_input_path.write_bytes(
                builder.ordered_json_bytes(compiler_input)
            )

            manifest_path = paths["output"] / builder.MANIFEST_FILENAME
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            updated_hash = builder.file_sha256(compiler_input_path)
            for record in manifest["targets"]:
                if record["compiler_input_relative_path"] == relative_input:
                    record["compiler_input_sha256"] = updated_hash
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "retained compiler input basePath must be exactly",
            ):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

    def test_rejects_foundry_profile_drift_before_compiling(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            content = paths["foundry_config"].read_text(encoding="utf-8")
            write_text(paths["foundry_config"], content.replace("optimizer_runs = 200", "optimizer_runs = 1"))
            fake = FakeForge()

            with self.assertRaisesRegex(builder.ReleaseBuildError, "optimizer_runs"):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            self.assertEqual(fake.commands, [])

    def test_rejects_unpinned_forge_and_sanitizes_forge_environment(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            fake = FakeForge()

            with self.assertRaisesRegex(builder.ReleaseBuildError, "expected pinned 1.7.1"):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION.replace("1.7.1", "1.7.2"),
                )
            self.assertEqual(fake.commands, [])

            completed = builder.subprocess.CompletedProcess(
                ["forge", "build", "smart-contracts/Example.sol"],
                0,
                stdout="",
                stderr="",
            )
            with (
                patch.dict(
                    os.environ,
                    {
                        "DAPP_OUT": "attacker-out",
                        "FOUNDRY_PROFILE": "attacker-profile",
                        "RELEASE_BUILD_KEEP": "retained",
                    },
                ),
                patch.object(
                    builder.subprocess,
                    "run",
                    return_value=completed,
                ) as run,
            ):
                builder.run_forge(
                    ["forge", "build", "smart-contracts/Example.sol"],
                    root,
                )
            child_environment = run.call_args.kwargs["env"]
            self.assertEqual(child_environment["RELEASE_BUILD_KEEP"], "retained")
            self.assertEqual(child_environment["FOUNDRY_PROFILE"], "default")
            self.assertFalse(
                any(
                    name.upper().startswith("DAPP_")
                    or (
                        name.upper().startswith("FOUNDRY_")
                        and name.upper() != "FOUNDRY_PROFILE"
                    )
                    for name in child_environment
                )
            )

            version_result = builder.subprocess.CompletedProcess(
                ["forge", "--version"],
                0,
                stdout=FAKE_FORGE_VERSION,
                stderr="",
            )
            with (
                patch.dict(
                    os.environ,
                    {
                        "DAPP_TEST": "remove",
                        "FOUNDRY_TEST": "remove",
                        "RELEASE_BUILD_KEEP": "retained",
                    },
                ),
                patch.object(
                    builder.subprocess,
                    "run",
                    return_value=version_result,
                ) as version_run,
            ):
                self.assertEqual(
                    builder.read_forge_version("forge", root),
                    FAKE_FORGE_VERSION,
                )
            version_environment = version_run.call_args.kwargs["env"]
            self.assertEqual(version_environment["RELEASE_BUILD_KEEP"], "retained")
            self.assertEqual(version_environment["FOUNDRY_PROFILE"], "default")
            self.assertFalse(
                any(
                    name.upper().startswith("DAPP_")
                    or (
                        name.upper().startswith("FOUNDRY_")
                        and name.upper() != "FOUNDRY_PROFILE"
                    )
                    for name in version_environment
                )
            )

    def test_rejects_broad_output_and_linked_inputs_before_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            fake = FakeForge()
            source = root / "smart-contracts" / "Example.sol"
            original_source = source.read_bytes()

            write_text(root / "out" / "ordinary-forge.txt", "ordinary output\n")
            for unsafe_output in (root / "out", root / "smart-contracts"):
                with self.subTest(unsafe_output=unsafe_output.name):
                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "canonical repository out-release",
                    ):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            unsafe_output,
                            runner=fake,
                            forge_version_output=FAKE_FORGE_VERSION,
                        )
            self.assertEqual(source.read_bytes(), original_source)
            self.assertEqual(
                (root / "out" / "ordinary-forge.txt").read_text(encoding="utf-8"),
                "ordinary output\n",
            )
            self.assertEqual(fake.commands, [])

            linked_config = root / "release-artifacts" / "contracts-link.json"
            try:
                linked_config.symlink_to(paths["config"])
            except OSError as exc:
                self.skipTest(f"file symlinks unavailable: {exc}")
            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "symlink, junction, or reparse",
            ):
                builder.build_release_output(
                    root,
                    linked_config,
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            self.assertEqual(fake.commands, [])

            paths["output"].symlink_to(
                root / "smart-contracts",
                target_is_directory=True,
            )
            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "symlink, junction, or reparse",
            ):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            self.assertEqual(source.read_bytes(), original_source)
            self.assertEqual(fake.commands, [])

    def test_validator_rejects_linked_receipt_artifact_and_compiler_input(self) -> None:
        cases = (
            Path(builder.MANIFEST_FILENAME),
            Path("Example.sol") / "Example.json",
            Path("compiler-inputs") / "000-Example.json",
        )
        for index, relative in enumerate(cases):
            with self.subTest(relative=relative.as_posix()):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )
                    linked_path = paths["output"] / relative
                    moved_path = root / f"linked-target-{index}.json"
                    linked_path.replace(moved_path)
                    try:
                        linked_path.symlink_to(moved_path)
                    except OSError as exc:
                        self.skipTest(f"file symlinks unavailable: {exc}")

                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "symlink, junction, or reparse",
                    ):
                        builder.validate_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                        )

    def test_replacement_rolls_back_on_base_exception(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output = root / builder.DEFAULT_OUTPUT_DIR
            staged_root = root / ".release-build-test"
            staged = staged_root / "aggregate"
            write_text(output / "sentinel.txt", "previous canonical output\n")
            write_text(staged / "new.txt", "new canonical output\n")

            real_replace = builder.os.replace
            replace_calls = 0

            def interrupt_second_replace(source: Path, destination: Path) -> None:
                nonlocal replace_calls
                replace_calls += 1
                if replace_calls == 2:
                    raise KeyboardInterrupt("simulated interruption")
                real_replace(source, destination)

            with (
                patch.object(
                    builder.os,
                    "replace",
                    side_effect=interrupt_second_replace,
                ),
                self.assertRaises(KeyboardInterrupt),
            ):
                builder.replace_output_directory(staged, output, staged_root)

            self.assertEqual(replace_calls, 3)
            self.assertEqual(
                (output / "sentinel.txt").read_text(encoding="utf-8"),
                "previous canonical output\n",
            )
            self.assertTrue((staged / "new.txt").is_file())

    def test_makefile_orders_release_output_writer_before_consumers(self) -> None:
        makefile = MAKEFILE_PATH.read_text(encoding="utf-8")
        expected_dependencies = [
            "release-build-check: release-build",
            "contract-size-budget-check: size release-build-check",
            "core-bytecode-spend-policy-check: size release-build-check",
            "release-artifacts: release-build-check",
            "release-artifacts-check: release-build-check",
            "source-verification-inputs: release-artifacts",
            "source-verification-inputs-check: release-artifacts-check",
            "abi-compatibility: release-build-check",
            "abi-compatibility-check: release-build-check",
        ]
        for dependency in expected_dependencies:
            with self.subTest(dependency=dependency):
                self.assertIn(dependency, makefile)
        self.assertNotIn(".NOTPARALLEL", makefile)

    def test_check_wrappers_order_release_builder_before_all_consumers(self) -> None:
        wrapper_commands = {
            "PowerShell": (
                CHECK_PS1_PATH,
                [
                    '& $pythonPath @pythonArgs "scripts\\test_release_build_artifacts.py"',
                    '& $pythonPath @pythonArgs "scripts\\build_release_artifacts.py"',
                    '& $pythonPath @pythonArgs "scripts\\build_release_artifacts.py" "--check"',
                    '& $pythonPath @pythonArgs "scripts\\test_contract_size_budget.py"',
                    '& $pythonPath @pythonArgs "scripts\\check_contract_size_budget.py"',
                    '& $pythonPath @pythonArgs "scripts\\test_core_bytecode_spend_policy.py"',
                    '& $pythonPath @pythonArgs "scripts\\check_core_bytecode_spend_policy.py"',
                    '& $pythonPath @pythonArgs "scripts\\test_release_artifacts.py"',
                    '& $pythonPath @pythonArgs "scripts\\generate_release_artifacts.py" "--check"',
                    '& $pythonPath @pythonArgs "scripts\\test_source_verification_inputs.py"',
                    '& $pythonPath @pythonArgs "scripts\\generate_source_verification_inputs.py" "--check"',
                    '& $pythonPath @pythonArgs "scripts\\test_abi_compatibility.py"',
                    '& $pythonPath @pythonArgs "scripts\\check_abi_compatibility.py" "--check"',
                ],
            ),
            "POSIX shell": (
                CHECK_SH_PATH,
                [
                    '"$python_bin" scripts/test_release_build_artifacts.py',
                    '"$python_bin" scripts/build_release_artifacts.py',
                    '"$python_bin" scripts/build_release_artifacts.py --check',
                    '"$python_bin" scripts/test_contract_size_budget.py',
                    '"$python_bin" scripts/check_contract_size_budget.py',
                    '"$python_bin" scripts/test_core_bytecode_spend_policy.py',
                    '"$python_bin" scripts/check_core_bytecode_spend_policy.py',
                    '"$python_bin" scripts/test_release_artifacts.py',
                    '"$python_bin" scripts/generate_release_artifacts.py --check',
                    '"$python_bin" scripts/test_source_verification_inputs.py',
                    '"$python_bin" scripts/generate_source_verification_inputs.py --check',
                    '"$python_bin" scripts/test_abi_compatibility.py',
                    '"$python_bin" scripts/check_abi_compatibility.py --check',
                ],
            ),
        }

        for wrapper_name, (path, expected_commands) in wrapper_commands.items():
            with self.subTest(wrapper=wrapper_name):
                lines = [
                    line.strip()
                    for line in path.read_text(encoding="utf-8").splitlines()
                ]
                positions: list[int] = []
                for command in expected_commands:
                    self.assertEqual(lines.count(command), 1, command)
                    positions.append(lines.index(command))
                self.assertEqual(positions, sorted(positions))

    def test_release_generator_rejects_post_build_artifact_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            artifact_path = paths["output"] / "Example.sol" / "Example.json"
            value = json.loads(artifact_path.read_text(encoding="utf-8"))
            value["deployedBytecode"]["object"] = "0x6002"
            write_json(artifact_path, value)

            stderr = StringIO()
            with working_directory(root), redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = release_generator.main(
                    [
                        "--config",
                        "release-artifacts/contracts.json",
                        "--foundry-config",
                        "foundry.toml",
                        "--foundry-out",
                        "out-release",
                        "--output-dir",
                        "release-artifacts/latest",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("artifact hash is stale", stderr.getvalue())
            self.assertFalse((root / "release-artifacts" / "latest").exists())

    def test_release_generator_rejects_mutation_after_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            artifact_path = paths["output"] / "Example.sol" / "Example.json"
            original_validate = release_generator.release_build.validate_release_output

            def validate_then_mutate(*args: Any, **kwargs: Any) -> dict[str, Any]:
                receipt = original_validate(*args, **kwargs)
                value = json.loads(artifact_path.read_text(encoding="utf-8"))
                value["deployedBytecode"]["object"] = "0x6002"
                write_json(artifact_path, value)
                return receipt

            stderr = StringIO()
            with (
                patch.object(
                    release_generator.release_build,
                    "validate_release_output",
                    side_effect=validate_then_mutate,
                ),
                working_directory(root),
                redirect_stdout(StringIO()),
                redirect_stderr(stderr),
            ):
                result = release_generator.main(
                    [
                        "--config",
                        "release-artifacts/contracts.json",
                        "--foundry-config",
                        "foundry.toml",
                        "--foundry-out",
                        "out-release",
                        "--output-dir",
                        "release-artifacts/latest",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "validated release receipt artifact hash is stale",
                stderr.getvalue(),
            )
            self.assertFalse((root / "release-artifacts" / "latest").exists())

    def test_rejects_artifact_with_wrong_compilation_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)

            with self.assertRaisesRegex(builder.ReleaseBuildError, "compilation target"):
                with redirect_stdout(StringIO()):
                    builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        runner=FakeForge(wrong_target=True),
                        forge_version_output=FAKE_FORGE_VERSION,
                    )

    def test_failed_build_preserves_previous_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            sentinel = paths["output"] / "sentinel.txt"
            write_text(sentinel, "previous canonical output\n")

            def fail(_command: list[str], _cwd: Path) -> None:
                raise builder.ReleaseBuildError("simulated compiler failure")

            with self.assertRaisesRegex(builder.ReleaseBuildError, "simulated compiler failure"):
                with redirect_stdout(StringIO()):
                    builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        runner=fail,
                        forge_version_output=FAKE_FORGE_VERSION,
                    )
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "previous canonical output\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
