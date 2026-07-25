#!/usr/bin/env python3
"""Focused tests for release checksum bundle generation."""

from __future__ import annotations

import importlib.util
import json
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("generate_release_checksums.py")
CUSTOM_OUTPUT_DIR = Path("release-artifacts/custom-checksums")
SPEC = importlib.util.spec_from_file_location("generate_release_checksums", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)

EXPECTED_RELEASE_TOOL_RUNTIME_CLOSURE = (
    Path("scripts/check_admin_ceremony_evidence.py"),
    Path("scripts/check_changelog.py"),
    Path("scripts/check_drop_authorization_signing_evidence.py"),
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
    Path("scripts/release_evidence_paths.py"),
    Path("scripts/verify_release_artifacts.py"),
)
EXPECTED_RELEASE_TOOL_FOCUSED_TESTS = (
    Path("scripts/test_changelog_check.py"),
    Path("scripts/test_release_notes.py"),
    Path("scripts/test_admin_ceremony_evidence.py"),
    Path("scripts/test_drop_authorization_signing_evidence.py"),
    Path("scripts/test_non_local_release_evidence.py"),
    Path("scripts/test_record_family_authorization.py"),
    Path("scripts/test_release_signatures.py"),
    Path("scripts/test_signer_custody_readiness.py"),
    Path("scripts/test_bytecode_release_proof.py"),
)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


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
        self.assertEqual(len(generator.DEFAULT_COVERED_PATHS), 236)
        self.assertEqual(
            len(set(generator.DEFAULT_COVERED_PATHS)),
            len(generator.DEFAULT_COVERED_PATHS),
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
                            re.escape(target.as_posix()),
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
            ):
                generator.validate_release_tool_checksum_closure(
                    root,
                    covered,
                )

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
        for name in ("exec", "eval", "compile"):
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
                "dynamic importer construction via getattr",
            ),
            (
                "nonliteral getattr",
                "import importlib\n"
                "getattr(importlib, ATTRIBUTE)(\"hidden\")\n",
                "nonliteral dynamic importer construction",
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
                '__import__("hidden", globals(), locals(), [], 1)\n',
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
        self.assertEqual(len(manifest["source"]["covered_paths"]), 236)
        self.assertEqual(len(manifest["files"]), 401)
        self.assertEqual(
            len(generator.parse_checksum_file(checksum_text)),
            401,
        )

    def test_committed_checksums_cover_deployment_plan_materializer(self) -> None:
        expected_paths = {
            Path("scripts/materialize_canonical_deployment_plan.py"),
            Path("scripts/test_materialize_canonical_deployment_plan.py"),
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
