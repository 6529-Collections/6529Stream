#!/usr/bin/env python3
"""Focused tests for the architecture and threat-model checker."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_architecture_threat_model.py")
SPEC = importlib.util.spec_from_file_location(
    "check_architecture_threat_model", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_bytecode_proof(
    root: Path,
    streamcore_sizes: list[tuple[int, int]] | None = None,
) -> None:
    contract_proofs = [
        {
            "proof_id": "fixture:StreamDrops",
            "contract": {"name": "StreamDrops"},
            "sizes": {
                "runtime_bytecode_bytes": 1000,
                "runtime_margin_bytes": 23576,
            },
        }
    ]
    sizes = [(23159, 1417)] if streamcore_sizes is None else streamcore_sizes
    for index, (runtime, margin) in enumerate(sizes):
        contract_proofs.append(
            {
                "proof_id": f"fixture-{index}:StreamCore",
                "contract": {"name": "StreamCore"},
                "sizes": {
                    "runtime_bytecode_bytes": runtime,
                    "runtime_margin_bytes": margin,
                },
            }
        )
    write_text(
        root / checker.DEFAULT_BYTECODE_PROOF,
        json.dumps({"contract_proofs": contract_proofs}, indent=2) + "\n",
    )


def seed_size_evidence_docs(root: Path, runtime: int = 23159, margin: int = 1417) -> None:
    for relative in [
        checker.DEFAULT_STATUS,
        checker.DEFAULT_RELEASE_POLICY,
        checker.DEFAULT_KNOWN_BLOCKERS,
    ]:
        write_text(
            root / relative,
            (
                f"StreamCore production runtime size is {runtime:,} bytes with "
                f"{margin:,} bytes of EIP-170 headroom.\n"
            ),
        )


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        if Path(relative) == checker.DEFAULT_BYTECODE_PROOF:
            seed_bytecode_proof(root)
        elif Path(relative) in [
            checker.DEFAULT_STATUS,
            checker.DEFAULT_RELEASE_POLICY,
            checker.DEFAULT_KNOWN_BLOCKERS,
        ]:
            seed_size_evidence_docs(root)
        else:
            write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    return "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_architecture_doc(runtime: int = 23159, margin: int = 1417) -> str:
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Architecture

This pre-audit local baseline is not production-ready and not a security claim.
It covers StreamAdmins, StreamCore, StreamDrops, StreamAuctions,
DependencyRegistry, StreamCuratorsPool, NextGenRandomizerVRF, and
NextGenRandomizerRNG. It describes fixed-price minting, auction flows, pull
credits, randomizer behavior, metadata behavior, deployment evidence, and
release evidence.
Future product work is satellite-first, uses satellite contracts, read
adapters, linked libraries, release artifacts, or docs, and any explicit
size-budget exception needs a measured before/after `StreamCore` runtime
bytecode delta. The bytecode release proof is the measured size source of
truth. Current StreamCore runtime is {runtime:,} bytes with {margin:,} bytes of
margin, above the 384-byte minimum and 512-byte warning thresholds. Run
forge build --sizes --via-ir --skip test --skip script --force and
python scripts/check_contract_size_budget.py.

Read the [threat model](threat-model.md).

## Maturity And Scope

This document covers the local baseline.

## System Components

Components are listed above.

## Product Extension And Size-Budget Policy

The satellite-first size-budget policy is listed above.

## Actor And Role Boundaries

Actors are separated by role.

## Protocol Flows

Fixed-price and auction flows are covered.

## Value And Custody Boundaries

Pull credits and custody are covered.

## Randomness And Metadata Boundaries

Randomizer and metadata boundaries are covered.

## Deployment And Release Boundaries

Deployment and release boundaries are covered.

## Invariants And Evidence

{links}

## Known Gaps

Production evidence remains open.

## Maintenance

```sh
{commands}
```
"""


def minimal_threat_model_doc() -> str:
    links = target_links()
    return f"""# Threat Model

This pre-audit local baseline is not production-ready and not a security claim.

Read the [architecture](architecture.md).

## Maturity And Scope

This document covers the local baseline.

## Assets

Assets are listed for review.

## Actors And Trust Boundaries

Actors and trust boundaries are listed for review.

## Assumptions And Non-Goals

Assumptions and non-goals are listed for review.

## Threat Categories

Authorization and replay, auction custody, pull-payment credits, randomizer lifecycle,
metadata rendering, dependency supply chain, deployment ceremony, release signatures,
external integrations, and residual risk are covered.

## Existing Controls

Controls are listed for review.

## Residual Risks And Open Blockers

Residual risks and open blockers are listed for review.

## Evidence Links

{links}

## Maintenance

Refresh when the trust boundary changes.
"""


class ArchitectureThreatModelTests(unittest.TestCase):
    def test_accepts_committed_docs(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_docs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_architecture_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_architecture_doc().replace("## System Components\n", "")
            write_text(root / checker.DEFAULT_ARCHITECTURE, text)
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "missing required headings"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_threat_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            text = minimal_threat_model_doc().replace("## Threat Categories\n", "")
            write_text(root / checker.DEFAULT_THREAT_MODEL, text)

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "missing required headings"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_maturity_language(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_architecture_doc().replace("not production-ready", "draft")
            write_text(root / checker.DEFAULT_ARCHITECTURE, text)
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "missing required maturity language",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_required_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_architecture_doc().replace("- [README.md](../README.md)\n", "")
            write_text(root / checker.DEFAULT_ARCHITECTURE, text)
            threat_text = minimal_threat_model_doc().replace(
                "- [README.md](../README.md)\n", ""
            )
            write_text(root / checker.DEFAULT_THREAT_MODEL, threat_text)

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "missing required links"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_threat_phrase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            text = minimal_threat_model_doc().replace(
                "Authorization and replay", "Auth"
            )
            write_text(root / checker.DEFAULT_THREAT_MODEL, text)

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "missing required content"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_architecture_to_threat_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_architecture_doc()
            text = text.replace("Read the [threat model](threat-model.md).\n", "")
            text = text.replace("- [docs/threat-model.md](../docs/threat-model.md)\n", "")
            write_text(root / checker.DEFAULT_ARCHITECTURE, text)
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "must link to"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_size_policy_phrase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_architecture_doc().replace("satellite-first", "extension")
            write_text(root / checker.DEFAULT_ARCHITECTURE, text)
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "missing required size-budget policy content",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_threat_to_architecture_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            text = minimal_threat_model_doc()
            text = text.replace("Read the [architecture](architecture.md).\n", "")
            text = text.replace("- [docs/architecture.md](../docs/architecture.md)\n", "")
            write_text(root / checker.DEFAULT_THREAT_MODEL, text)

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "must link to"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_linked_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())
            (root / "README.md").unlink()

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "required link target files are missing",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_architecture_size_drift_from_bytecode_proof(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_ARCHITECTURE,
                minimal_architecture_doc(runtime=23661, margin=915),
            )
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "size evidence does not match bytecode release proof",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_status_size_drift_from_bytecode_proof(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            seed_size_evidence_docs(root, runtime=23661, margin=915)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "size evidence does not match bytecode release proof",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_inconsistent_streamcore_size_proof(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            seed_bytecode_proof(root, [(23159, 1417), (23661, 915)])
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "inconsistent StreamCore size evidence",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )

    def test_rejects_missing_streamcore_size_proof(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            seed_bytecode_proof(root, [])
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError,
                "missing StreamCore size evidence",
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
