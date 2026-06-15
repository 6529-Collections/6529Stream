#!/usr/bin/env python3
"""Focused tests for the royalty policy checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_royalty_policy.py")
SPEC = importlib.util.spec_from_file_location("check_royalty_policy", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required policy link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        if relative == "smart-contracts/StreamCore.sol":
            write_text(
                root / relative,
                """
import "./IERC2981.sol";
contract StreamCore is IERC2981 {
    address private constant _DEFAULT_ROYALTY_RECEIVER = 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377;
    uint256 private constant _DEFAULT_ROYALTY_BPS = 690;
    uint256 private constant _ROYALTY_DENOMINATOR = 10_000;
    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return interfaceId == type(IERC2981).interfaceId;
    }
    function royaltyInfo(uint256, uint256 salePrice) public view returns (address, uint256) {
        return (_DEFAULT_ROYALTY_RECEIVER, salePrice * _DEFAULT_ROYALTY_BPS / _ROYALTY_DENOMINATOR);
    }
}
""",
            )
        elif relative == "test/StreamRoyalty.t.sol":
            write_text(
                root / relative,
                """
contract StreamRoyaltyTest {
    bytes4 private constant ERC2981_INTERFACE_ID = 0x2a55205a;
    address private constant ROYALTY_RECEIVER = 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377;
    uint256 private constant ROYALTY_BPS = 690;
    uint256 private constant ROYALTY_DENOMINATOR = 10_000;
    function testDefaultRoyaltyIsFixedAt690BasisPoints() public {}
}
""",
            )
        else:
            write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_royalty_policy() -> str:
    """Build the smallest royalty policy accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Royalty Policy

This ONE-003 pre-audit local baseline is not production-ready and not a
security claim. It does not replace fork/testnet/live evidence.

## Maturity And Scope

The policy names marketplace support and wallet/indexer risks without claiming
release readiness.

## Source Of Truth

{links}

IERC2981 and ERC-2981 are source inputs.

## Current ERC-2981 Behavior

royaltyInfo(), supportsInterface(0x2a55205a), fixed default royalty, 690 basis
points, 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377, 10,000, no runtime
royalty setters, no per-token override, and no per-collection override are
named.

## Royalty Philosophy

The policy is royalty disclosure, not payment enforcement.
No production-readiness claim depends on marketplaces honoring royalties.
permissionless-transfer composability and StreamCore size-budget exception are
named. A future satellite royalty policy contract is named.

## Governance And Change Policy

Changing the default royalty receiver, Changing `690 basis points`, Adding
per-token override support, Adding per-collection override support, Adding a
satellite royalty policy contract, and Adding royalty enforcement are named.
changed royalty behavior is a breaking change.

## Enforcement Boundary

ERC-2981 exposes royalty information and does not enforce secondary-sale
payment. sale router, transfer validator, operator filter, ERC721C-style,
ERC721C-style transfer restriction, marketplace allowlist or blocklist, royalty
escrow, royalty pull-payment accounting are named.

## Marketplace Display Guidance

OpenSea, Reservoir, Blur, Manifold, Display the returned receiver, and Avoid
wording that implies payment was enforced are named.

## Integration Guidance

Integration guidance is named.

## Evidence And Readiness Boundaries

Public beta requires reviewed retained fork/testnet/live evidence. Production
requires the same evidence. retained fork/testnet/live evidence, ONE-005, event
topic catalog, and not release readiness proof are named.

## Testing Strategy

Testing strategy is named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Maintenance is named.
"""


class RoyaltyPolicyTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed royalty policy satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete policy passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, minimal_royalty_policy())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default royalty policy path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-royalty-policy.md")
            write_text(root / custom_path, minimal_royalty_policy())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--royalty-policy",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace("## Enforcement Boundary\n", "")
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "missing required headings"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing non-enforcement language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace(
                "royalty disclosure, not payment enforcement", "royalty disclosure"
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "missing required content"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_missing_section_scoped_phrase(self) -> None:
        """Section-specific policy requirements must stay in the intended section."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace(
                "Display the returned receiver, and ", ""
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "incomplete sections"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace(
                "No production-readiness claim depends on marketplaces honoring royalties",
                "No production-readiness claim depends on marketplaces\nhonoring royalties",
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_royalty_policy()
            text = original.replace(
                "- [docs/metadata.md](../docs/metadata.md)\n", ""
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "missing required links"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs" / "metadata.md").unlink()
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, minimal_royalty_policy())

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "links to missing files"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace(
                "- [docs/metadata.md](../docs/metadata.md)\n",
                "- [docs/metadata.md](../docs/release-policy.md)\n",
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(checker.RoyaltyPolicyError, "points to"):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the policy."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace(
                "python scripts/check_royalty_policy.py\n", ""
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "missing required commands"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_required_command_as_substring_only(self) -> None:
        """Required commands must appear as exact command lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_royalty_policy().replace(
                "python scripts/check_royalty_policy.py",
                "python scripts/check_royalty_policy.py --help",
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, text)

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "missing required commands"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_source_constant_drift(self) -> None:
        """Documented royalty constants must stay tied to source constants."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            source = root / "smart-contracts" / "StreamCore.sol"
            source.write_text(
                source.read_text(encoding="utf-8").replace(
                    "_DEFAULT_ROYALTY_BPS = 690", "_DEFAULT_ROYALTY_BPS = 700"
                ),
                encoding="utf-8",
                newline="\n",
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, minimal_royalty_policy())

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "source constants drifted"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )

    def test_rejects_test_constant_drift(self) -> None:
        """The Solidity regression constants must stay tied to the policy."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            test_file = root / "test" / "StreamRoyalty.t.sol"
            test_file.write_text(
                test_file.read_text(encoding="utf-8").replace(
                    "ERC2981_INTERFACE_ID = 0x2a55205a",
                    "ERC2981_INTERFACE_ID = 0x00000000",
                ),
                encoding="utf-8",
                newline="\n",
            )
            write_text(root / checker.DEFAULT_ROYALTY_POLICY, minimal_royalty_policy())

            with self.assertRaisesRegex(
                checker.RoyaltyPolicyError, "source constants drifted"
            ):
                checker.validate_royalty_policy(
                    root, root / checker.DEFAULT_ROYALTY_POLICY
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
