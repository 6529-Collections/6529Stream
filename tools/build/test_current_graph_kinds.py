"""Pin the dependency-free graph-kind seam to aa2; source tests, never a compiler/EVM.

Frozen baseline: aa2ca4a2764ca981630c668966a665637692842d. Expected values are
stored here so CI does not need Git history. Body hashes normalize CRLF only;
token hashes additionally ignore comments/spacing, never literal/operator bytes.
"""
from pathlib import Path
import hashlib
import json
import unittest

from tools.build.test_creation_catalog_types import TOKEN, block, declaration, imports, tokens


ROOT = Path(__file__).resolve().parents[2]
FULL = ROOT / "script/current/StreamCurrentGraphCreation.sol"
LIGHT = ROOT / "script/current/StreamCurrentGraphKinds.sol"
ORIGINAL_SOURCE_SHA256 = 'a5d6145fe9513531663a8cd1863f293f7388d4fa91aab086c25f4dd397d251f9'
ORIGINAL_TOKENS_SHA256 = 'e61acf05a58cf40ea4fc2d157d3e935a2e41976a5594e55bb22756f23c5e6a74'
ORIGINAL_ENUM_SHA256 = 'cd6c698574092aad6c919bc96a05b912dbd2f857c6389f107559ac31b7ddc384'
ORIGINAL_NAME_BODY_SHA256 = 'ff003708bf175c9f8f58f2002f88482d7bf709715c66d7b98e21a342ab890b18'
ORIGINAL_CREATION_BODY_SHA256 = 'e03f47208fd7904001366e46ce45dc9b9a8e9c20a8488da8bf218365a26ae394'

EXPECTED_KINDS = (
    'StreamArchivalCoverage',
    'StreamArtistAcceptanceLifecycle',
    'StreamArtistArchiveV2',
    'StreamArtistAttributionLifecycle',
    'StreamArtistBindingLifecycle',
    'StreamArtistCollaboratorLifecycle',
    'StreamArtistConsentFinalityLifecycle',
    'StreamArtistIdentityAuthority',
    'StreamArtistOnboardingCoordinator',
    'StreamArtistOnboardingRegistry',
    'StreamArtistPayoutLifecycle',
    'StreamArtistRegistryValidatorBase',
    'StreamArtworkFinalityRegistry',
    'StreamArweaveCheckpointVerifier',
    'StreamArweaveObjectCheckpointVerifier',
    'StreamAssetPolicyRegistry',
    'StreamBundleArchiveCoverage',
    'StreamCollectionMetadataV1',
    'StreamCollectionSnapshots',
    'StreamCollectionTokenInventory',
    'StreamConservationRecordSelection',
    'StreamContentLeafManifest',
    'StreamCore',
    'StreamCoreFinalityAdapter',
    'StreamEntropyCoordinator',
    'StreamExternalArtifactCoverage',
    'StreamFinalityArtifactCoverage',
    'StreamFinalityCoordinatorInventory',
    'StreamFinalityCurrentDiscovery',
    'StreamFinalityEntropySourceFactory',
    'StreamFinalityNativeEvidenceProvider',
    'StreamFinalityScopeMembership',
    'StreamFinalityServingHostAdapter',
    'StreamFixedPriceSaleAdapter',
    'StreamGovernanceExecutor',
    'StreamMetadataRouter',
    'StreamMintLedger',
    'StreamMintManager',
    'StreamModuleRegistry',
    'StreamOnchainContentCheckpoint',
    'StreamReferenceRenderPublication',
    'StreamRenderCriticalInventory',
    'StreamRevenueEscrow',
    'StreamRevenueResolver',
    'StreamRightsRecordSelection',
    'StreamRoleRegistry',
    'StreamRoyaltyResolver',
    'StreamSchemaRegistry',
    'StreamSplitFactory',
    'StreamSystemManifest',
    'StreamWorkRecordSelection',
    'StreamStaticSelectionCheckpoint',
    'StreamStaticContentCheckpoint',
    'StreamStaticOutputManifest',
    'StreamScopedSnapshotPublication',
    'StreamScopedReferencePublication',
    'StreamScopedRenderCriticalInventory',
    'StreamScopedBundleArchiveCoverage',
    'StreamFinalityEntropyPolicySourceFactoryV2',
    'StreamFinalityScopedEntropyPolicySourceFactoryV2',
    'StreamPolicyPublicationFactoryV2',
    'StreamScopedPolicyPublicationFactoryV2',
    'StreamFinalityFullPolicyEvidenceProviderV2',
    'StreamFinalityFullPolicyDiscoveryV2',
)

EXPECTED_CREATED_KINDS = (
    'StreamArtistIdentityAuthority',
    'StreamArtistOnboardingCoordinator',
    'StreamArtistOnboardingRegistry',
    'StreamArtworkFinalityRegistry',
    'StreamArweaveObjectCheckpointVerifier',
    'StreamBundleArchiveCoverage',
    'StreamCollectionMetadataV1',
    'StreamCollectionSnapshots',
    'StreamCollectionTokenInventory',
    'StreamConservationRecordSelection',
    'StreamContentLeafManifest',
    'StreamCoreFinalityAdapter',
    'StreamExternalArtifactCoverage',
    'StreamFinalityArtifactCoverage',
    'StreamFinalityCoordinatorInventory',
    'StreamFinalityCurrentDiscovery',
    'StreamFinalityEntropySourceFactory',
    'StreamFinalityNativeEvidenceProvider',
    'StreamFinalityScopeMembership',
    'StreamFinalityServingHostAdapter',
    'StreamOnchainContentCheckpoint',
    'StreamReferenceRenderPublication',
    'StreamRenderCriticalInventory',
    'StreamRightsRecordSelection',
    'StreamSchemaRegistry',
    'StreamWorkRecordSelection',
    'StreamStaticSelectionCheckpoint',
    'StreamStaticContentCheckpoint',
    'StreamStaticOutputManifest',
    'StreamScopedSnapshotPublication',
    'StreamScopedReferencePublication',
    'StreamScopedRenderCriticalInventory',
    'StreamScopedBundleArchiveCoverage',
    'StreamFinalityEntropyPolicySourceFactoryV2',
    'StreamFinalityScopedEntropyPolicySourceFactoryV2',
    'StreamPolicyPublicationFactoryV2',
    'StreamScopedPolicyPublicationFactoryV2',
    'StreamFinalityFullPolicyEvidenceProviderV2',
    'StreamFinalityFullPolicyDiscoveryV2',
)

EXPECTED_UNSUPPORTED_KINDS = (
    'StreamArchivalCoverage',
    'StreamArtistAcceptanceLifecycle',
    'StreamArtistArchiveV2',
    'StreamArtistAttributionLifecycle',
    'StreamArtistBindingLifecycle',
    'StreamArtistCollaboratorLifecycle',
    'StreamArtistConsentFinalityLifecycle',
    'StreamArtistPayoutLifecycle',
    'StreamArtistRegistryValidatorBase',
    'StreamArweaveCheckpointVerifier',
    'StreamAssetPolicyRegistry',
    'StreamCore',
    'StreamEntropyCoordinator',
    'StreamFixedPriceSaleAdapter',
    'StreamGovernanceExecutor',
    'StreamMetadataRouter',
    'StreamMintLedger',
    'StreamMintManager',
    'StreamModuleRegistry',
    'StreamRevenueEscrow',
    'StreamRevenueResolver',
    'StreamRoleRegistry',
    'StreamRoyaltyResolver',
    'StreamSplitFactory',
    'StreamSystemManifest',
)


def digest(text):
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def source_parts(text, prefix):
    """Return exact body bytes and token extent, keeping braces inside strings inert."""
    matches = [match for match in TOKEN.finditer(text)
               if match.lastgroup not in ("space", "comment")]
    items = tokens(text)  # Fail on unrecognized input, unlike bare finditer.
    assert [match.group() for match in matches] == items
    locations = [i for i in range(len(items)) if items[i:i + len(prefix)] == prefix]
    if len(locations) != 1:
        raise ValueError(f"Expected one declaration: {prefix}")
    start = locations[0]
    opening = items.index("{", start)
    _, end = block(items, opening)
    return text[matches[opening].start():matches[end].end()], (start, end + 1)


def library(text, name):
    return declaration(tokens(text), ["library", name, "{"])[1]


def creation_pairs(body):
    """Read every explicit branch and require the original unconditional fallback."""
    index, found = 0, []
    while index < len(body) and body[index] == "if":
        if body[index:index + 6] != ["if", "(", "kind", "==", "Kind", "."]:
            raise ValueError("Changed creation predicate")
        kind = body[index + 6]
        if body[index + 7] != ")":
            raise ValueError("Changed creation predicate tail")
        index += 8
        braced = body[index] == "{"
        if braced:
            index += 1
        if body[index:index + 3] != ["return", "type", "("]:
            raise ValueError("Creation must retain the actual literal child type")
        child = body[index + 3]
        if body[index + 4:index + 8] != [")", ".", "creationCode", ";"]:
            raise ValueError("Changed creation expression")
        index += 8
        if braced:
            if body[index] != "}":
                raise ValueError("Additional creation branch operations")
            index += 1
        found.append((kind, child))
    if body[index:] != tokens('revert("unknown original product template");'):
        raise ValueError("Changed unsupported-kind fallback")
    return tuple(found)


class CurrentGraphKindsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.full = FULL.read_text(encoding="utf-8")
        cls.light = LIGHT.read_text(encoding="utf-8")

    def test_all_64_ordinals_match_frozen_original(self):
        for source, name in ((self.full, "StreamCurrentGraphCreation"),
                             (self.light, "StreamCurrentGraphKinds")):
            with self.subTest(library=name):
                _, enum, _ = declaration(library(source, name), ["enum", "Kind", "{"])
                self.assertEqual(tuple(enum[::2]), EXPECTED_KINDS)
                self.assertEqual(enum[1::2], [","] * 63)
                raw, _ = source_parts(source, ["enum", "Kind", "{"])
                self.assertEqual(digest(raw), ORIGINAL_ENUM_SHA256)

    def test_name_body_and_all_returned_names_are_original_bytes(self):
        prefix = ["function", "name", "(", "Kind", "kind", ")"]
        for source in (self.full, self.light):
            raw, _ = source_parts(source, prefix)
            self.assertEqual(digest(raw), ORIGINAL_NAME_BODY_SHA256)
            names = [value[1:-1] for value in tokens(raw) if value.startswith('"')]
            self.assertEqual(names, list(EXPECTED_KINDS) + ["unknown original product template"])

    def test_all_39_creation_branches_and_25_unsupported_kinds_remain_original(self):
        prefix = ["function", "creation", "(", "Kind", "kind", ")"]
        raw, _ = source_parts(self.full, prefix)
        self.assertEqual(digest(raw), ORIGINAL_CREATION_BODY_SHA256)
        branches = creation_pairs(tokens(raw)[1:-1])
        self.assertEqual(branches, tuple((name, name) for name in EXPECTED_CREATED_KINDS))
        self.assertEqual(tuple(name for name in EXPECTED_KINDS
                               if name not in {kind for kind, _ in branches}),
                         EXPECTED_UNSUPPORTED_KINDS)
        self.assertEqual(len(EXPECTED_CREATED_KINDS), 39)
        self.assertEqual(len(EXPECTED_UNSUPPORTED_KINDS), 25)

    def test_light_library_contains_only_original_enum_and_name(self):
        items = tokens(self.light)
        self.assertEqual(imports(items), [])
        for forbidden in ("import", "new", "type", "creationCode", "constructor",
                          "delegatecall", "call", "staticcall", "assembly"):
            self.assertNotIn(forbidden, items)
        old = library(self.full, "StreamCurrentGraphCreation")
        enum_header, enum, _ = declaration(old, ["enum", "Kind", "{"])
        name_header, name_body, _ = declaration(old, ["function", "name", "(", "Kind"])
        expected = (tokens("pragma solidity ^0.8.19; library StreamCurrentGraphKinds {")
                    + enum_header + ["{"] + enum + ["}"]
                    + name_header + ["{"] + name_body + ["}", "}"])
        self.assertEqual(items, expected, "Light source acquired a dependency or behavior")

    def test_creation_bridge_is_only_the_exact_ordinal_conversion(self):
        prefix = ["function", "creation", "(", "StreamCurrentGraphKinds", ".", "Kind"]
        header, body, _ = declaration(library(self.full, "StreamCurrentGraphCreation"), prefix)
        self.assertEqual(header, tokens(
            "function creation(StreamCurrentGraphKinds.Kind kind) internal pure returns(bytes memory)"))
        self.assertEqual(body, tokens("return creation(Kind(uint256(kind)));"))

    def test_full_catalog_only_adds_kinds_import_and_bridge(self):
        items = tokens(self.full)
        clauses = imports(items)
        extra = [clause for clause in clauses if '"./StreamCurrentGraphKinds.sol"' in clause]
        self.assertEqual(extra, [tokens(
            'import { StreamCurrentGraphKinds } from "./StreamCurrentGraphKinds.sol";')])
        opening = next(i for i in range(len(items)) if items[i:i + len(extra[0])] == extra[0])
        _, bridge = source_parts(self.full, ["function", "creation", "(",
                                            "StreamCurrentGraphKinds", ".", "Kind"])
        remove = set(range(opening, opening + len(extra[0]))) | set(range(*bridge))
        original = [value for i, value in enumerate(items) if i not in remove]
        self.assertEqual(digest(json.dumps(original, separators=(",", ":"))),
                         ORIGINAL_TOKENS_SHA256,
                         "An original import/declaration/constructor path changed")


if __name__ == "__main__":
    unittest.main()
