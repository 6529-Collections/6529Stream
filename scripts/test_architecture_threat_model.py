#!/usr/bin/env python3
"""Focused tests for the architecture and threat-model checker."""

from __future__ import annotations

import importlib.util
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


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    return "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_architecture_doc() -> str:
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Architecture

This pre-audit local baseline is not production-ready and not a security claim.
It covers StreamAdmins, StreamCore, StreamDrops, StreamAuctions,
DependencyRegistry, StreamCuratorsPool, NextGenRandomizerVRF, and
NextGenRandomizerRNG. It describes fixed-price minting, auction flows, pull
credits, randomizer behavior, metadata behavior, deployment evidence, and
release evidence.

Read the [threat model](threat-model.md).

## Maturity And Scope

This document covers the local baseline.

## System Components

Components are listed above.

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
        repo_root = Path.cwd()

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

    def test_rejects_missing_linked_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ARCHITECTURE, minimal_architecture_doc())
            write_text(root / checker.DEFAULT_THREAT_MODEL, minimal_threat_model_doc())
            (root / "README.md").unlink()

            with self.assertRaisesRegex(
                checker.ArchitectureThreatModelError, "linked targets are missing"
            ):
                checker.validate_architecture_threat_model(
                    root,
                    root / checker.DEFAULT_ARCHITECTURE,
                    root / checker.DEFAULT_THREAT_MODEL,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
