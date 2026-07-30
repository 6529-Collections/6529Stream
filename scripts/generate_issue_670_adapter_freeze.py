#!/usr/bin/env python3
"""Generate deterministic issue #670 adapter vectors and semantic matrix.

The mechanical artifact covers only facts already specified in the two
Proposed interface packets. The generated operation matrix records the accepted
semantic decision and its exact versioned stop overlays. Neither output is
implementation authorization, deployment evidence, or a readiness claim.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = "6529stream.issue-670-adapter-freeze.mechanical-vectors.v1"
PACKET_SOURCE_COMMIT = "8a045029185efc807edeac08d6f76b95c4387dd1"
DEFAULT_OUTPUT = Path(
    "release-artifacts/issue-670-adapter-freeze/mechanical-vectors-v1.json"
)
DEFAULT_MATRIX_OUTPUT = Path(
    "release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json"
)
DEFAULT_FINALITY_SUPPLEMENT = Path(
    "release-artifacts/issue-670-adapter-freeze/"
    "finality-dependency-supplement-v1.json"
)
DEFAULT_SECURITY_EVIDENCE = Path(
    "release-artifacts/issue-670-adapter-freeze/"
    "security-evidence-gates-v1.json"
)

FINALITY_OVERLAY_ID = "artist-finality-dependency-supplement-v1"
FINALITY_STOP_ID = "FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN"
FINALITY_SUPPLEMENT_SCOPE = (
    "proposed_packet_evaluation_and_measurement_only"
)
SECURITY_GATE_IDS = (
    "NORMATIVE_FREEZE",
    "ARTIST_57_WRITE_COMPLETENESS",
    "SIGNATURE_REPLAY",
    "DYNAMIC_ABI",
    "REVENUE_GAS",
    "ARTIST_GGP_AND_GAS",
    "EXTERNAL_CALLGRAPH",
    "CORE_FINALITY_DEPENDENCIES",
    "SLITHER_AND_SECURITY_CHECKS",
    "RUNTIME_SIZE",
    "INITCODE_SIZE",
    "DEPLOYMENT_EVIDENCE",
    "RELEASE_CHAIN",
)

SOURCE_FILES = (
    (
        "revenue_packet",
        Path(
            "docs/adr/"
            "0021-revenue-resolver-validation-adapter-interface-packet.md"
        ),
        "795cbecfbde0b427881c7294a8af170d8409aa80522801e5e5fb69ba304788a6",
    ),
    (
        "artist_packet",
        Path(
            "docs/adr/"
            "0022-artist-registry-validation-adapter-interface-packet.md"
        ),
        "d0d72e64a1f84daad905ea9bcb30f564064754dfb559484ddcf1ef4f4500c36b",
    ),
    (
        "artist_typehash_preimages",
        Path("docs/stream-artist-authority.md"),
        "f279760a6d975e1e5d880f89c085f5e5a70842355ee501e077daae6c5922d514",
    ),
)

MASK_64 = (1 << 64) - 1
KECCAK_ROUNDS = (
    0x0000000000000001,
    0x0000000000008082,
    0x800000000000808A,
    0x8000000080008000,
    0x000000000000808B,
    0x0000000080000001,
    0x8000000080008081,
    0x8000000000008009,
    0x000000000000008A,
    0x0000000000000088,
    0x0000000080008009,
    0x000000008000000A,
    0x000000008000808B,
    0x800000000000008B,
    0x8000000000008089,
    0x8000000000008003,
    0x8000000000008002,
    0x8000000000000080,
    0x000000000000800A,
    0x800000008000000A,
    0x8000000080008081,
    0x8000000000008080,
    0x0000000080000001,
    0x8000000080008008,
)
RHO_OFFSETS = (
    (0, 36, 3, 41, 18),
    (1, 44, 10, 45, 2),
    (62, 6, 43, 15, 61),
    (28, 55, 25, 21, 56),
    (27, 20, 39, 8, 14),
)


class AdapterFreezeError(RuntimeError):
    """Raised when a packet fact or committed artifact is nonconformant."""


def rotl64(value: int, shift: int) -> int:
    if shift == 0:
        return value & MASK_64
    return ((value << shift) | (value >> (64 - shift))) & MASK_64


def keccak_f1600(state: list[int]) -> None:
    """Apply Keccak-f[1600] in place."""
    for round_constant in KECCAK_ROUNDS:
        columns = [
            state[x]
            ^ state[x + 5]
            ^ state[x + 10]
            ^ state[x + 15]
            ^ state[x + 20]
            for x in range(5)
        ]
        deltas = [
            columns[(x - 1) % 5] ^ rotl64(columns[(x + 1) % 5], 1)
            for x in range(5)
        ]
        for x in range(5):
            for y in range(5):
                state[x + 5 * y] ^= deltas[x]

        rotated = [0] * 25
        for x in range(5):
            for y in range(5):
                rotated[y + 5 * ((2 * x + 3 * y) % 5)] = rotl64(
                    state[x + 5 * y], RHO_OFFSETS[x][y]
                )

        for x in range(5):
            for y in range(5):
                state[x + 5 * y] = (
                    rotated[x + 5 * y]
                    ^ (
                        (~rotated[((x + 1) % 5) + 5 * y])
                        & rotated[((x + 2) % 5) + 5 * y]
                    )
                ) & MASK_64
        state[0] ^= round_constant


def keccak256(value: bytes) -> bytes:
    """Return Ethereum Keccak-256, never NIST SHA3-256."""
    rate = 136
    padding_length = rate - (len(value) % rate)
    if padding_length == 1:
        padded = value + b"\x81"
    else:
        padded = (
            value
            + b"\x01"
            + b"\x00" * (padding_length - 2)
            + b"\x80"
        )

    state = [0] * 25
    for offset in range(0, len(padded), rate):
        block = padded[offset : offset + rate]
        for lane in range(rate // 8):
            start = lane * 8
            state[lane] ^= int.from_bytes(block[start : start + 8], "little")
        keccak_f1600(state)

    output = bytearray()
    for lane in range(rate // 8):
        output.extend(state[lane].to_bytes(8, "little"))
        if len(output) >= 32:
            break
    return bytes(output[:32])


def keccak_hex(value: bytes) -> str:
    return "0x" + keccak256(value).hex()


def selector(signature: str) -> str:
    return "0x" + keccak256(signature.encode("ascii"))[:4].hex()


def xor_selectors(selectors: Iterable[str]) -> str:
    value = 0
    count = 0
    for item in selectors:
        if len(item) != 10 or not item.startswith("0x"):
            raise AdapterFreezeError(f"invalid selector for XOR: {item}")
        value ^= int(item[2:], 16)
        count += 1
    if count == 0:
        raise AdapterFreezeError("cannot XOR an empty selector set")
    return f"0x{value:08x}"


def require_equal(actual: Any, expected: Any, label: str) -> None:
    if actual != expected:
        raise AdapterFreezeError(
            f"{label} mismatch: derived {actual!r}, packet pins {expected!r}"
        )


def bytes32_word(value: int) -> str:
    if value < 0 or value >= 1 << 256:
        raise AdapterFreezeError("uint256 word is out of range")
    return "0x" + value.to_bytes(32, "big").hex()


def bytes4_argument_calldata(function_selector: str, argument: str) -> str:
    return function_selector + argument[2:] + ("00" * 28)


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


REVENUE_HASH_CONSTANTS = (
    (
        "ADAPTER_MARKER_V1",
        "6529STREAM_REVENUE_RESOLVER_VALIDATION_ADAPTER_V1",
        "0xc712a93e70e790d800e47a24f6b52711d5b4395ef334c52f9b4abf4dd437415a",
    ),
    (
        "RESULT_MAGIC_V1",
        "6529STREAM_REVENUE_RESOLVER_VALIDATION_RESULT_MAGIC_V1",
        "0x7770c0c5bddd997a2a1f8ff01c213b8e89c2088fa67ccb78fbe9c96b0a7da33e",
    ),
    (
        "DEPENDENCY_DOMAIN_V1",
        "6529STREAM_REVENUE_RESOLVER_VALIDATION_DEPENDENCIES_V1",
        "0xd92182181887d178da7ee1abb2501ab0f688e60ef591ebafbaa3218060956923",
    ),
    (
        "INTENT_DOMAIN_V1",
        "6529STREAM_REVENUE_RESOLVER_VALIDATION_INTENT_V1",
        "0x01314df67d01eb4bb1a15954fc7090d6489ddd26cfb6c297255d1387050bc910",
    ),
    (
        "OBSERVATIONS_DOMAIN_V1",
        "6529STREAM_REVENUE_RESOLVER_VALIDATION_OBSERVATIONS_V1",
        "0x15c7c294be65e05ed6b7e91f04f32c3b15741b6bc8136a89c896ba10565f7f06",
    ),
    (
        "RESULT_DOMAIN_V1",
        "6529STREAM_REVENUE_RESOLVER_VALIDATION_RESULT_V1",
        "0x0b4e09de5081f9799c82b57041daa86221771cfce5affb5ec1acd8a097e7c4d6",
    ),
    (
        "PRIMARY_GOVERNANCE_SCOPE_DOMAIN_V1",
        "6529STREAM_PRIMARY_ASSIGNMENT_GOVERNANCE_SCOPE_V1",
        "0x687c6d8adadba2bc1b8de2358ea03e1130761d5737088a13df4a59b4d39748e2",
    ),
    (
        "PRIMARY_GOVERNANCE_STATE_DOMAIN_V1",
        "6529STREAM_PRIMARY_ASSIGNMENT_GOVERNANCE_STATE_V1",
        "0x25ba62ff5b8b8b88b3baf4831ddfa7d3aa91d21d892b5dd542f3b46961281d00",
    ),
    (
        "PRIMARY_FREEZE_GOVERNANCE_STATE_DOMAIN_V1",
        "6529STREAM_PRIMARY_ASSIGNMENT_FREEZE_GOVERNANCE_STATE_V1",
        "0xa7ae283a0a9e89f333bce42286c8d8c287f49f60fc947a8fccf979f9cf2d44ab",
    ),
    (
        "SNAPSHOT_PROOF_DOMAIN_V1",
        "6529STREAM_REVENUE_SNAPSHOT_PROOF_V1",
        "0x312c37a50a09a644909db1b0571aed097f0285b6305d3eee8e65dcb0b4983fa7",
    ),
    (
        "ROYALTY_POLICY_DOMAIN",
        "6529STREAM_ROYALTY_POLICY_V1",
        "0x672cda40f3f95b129db3b9262cfb581cbe26ea0e95cb09b958ca58ebf62ba54a",
    ),
    (
        "ROYALTY_REVENUE_CLASS",
        "ROYALTY_ERC2981",
        "0x5cb0c76a63239382404dc61f136cb498c99d198325ed6d4148d768d151e0b2f8",
    ),
    (
        "CORE_MARKER_V1",
        "6529STREAM_PERMANENT_CORE_V1",
        "0x81e029b140303578efbc73ea15873907b328621ccb126b647102a661b5d597e9",
    ),
    (
        "FACTORY_MARKER_V1",
        "6529STREAM_SPLIT_FACTORY_V1",
        "0x74ac5c045f6661fc3e2736d16ef223cd6c45f11d8f8fa82184d557b190df220c",
    ),
    (
        "ARTIST_MARKER_V1",
        "STREAM_ARTIST_REGISTRY",
        "0x2a9dd22d7225a4cc60f5a64aa47d28addaea744116b324a22149faadac0b090a",
    ),
    (
        "MINT_MANAGER_POINTER_ID",
        "MINT_MANAGER",
        "0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2",
    ),
)

DEPENDENCIES_V1_TYPE = (
    "(address,bytes32,bytes4,bytes32,uint16,address,bytes32,bytes4,"
    "bytes32,uint16,address,bytes32,bytes4,bytes32,uint16,address,bytes32,"
    "bytes32,bytes32)"
)
INTENT_HEADER_V1_TYPE = (
    "(uint256,address,address,bytes32,bytes4,bytes32,uint16,bytes4,address,"
    "bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)"
)

REVENUE_ENTRY_SPECS = (
    (
        "revenueResolverValidationAdapterMarkerV1",
        "",
        "0xb3573c09",
        None,
        None,
    ),
    (
        "revenueResolverValidationAdapterSchemaV1",
        "",
        "0x94bf44c4",
        None,
        None,
    ),
    ("dependencyBindingHash", "", "0x371b62f3", None, None),
    (
        "computePrimaryAssignmentHashV1",
        "bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bool",
        "0xaa3a3b3e",
        "O1",
        8,
    ),
    (
        "validateSetPrimaryAssignmentV1",
        "bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,"
        "bytes32,uint256,bytes32,bool,bool,uint256,uint256",
        "0x6396e4ca",
        "O2",
        15,
    ),
    (
        "validateClearPrimaryAssignmentV1",
        "bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,"
        "bytes32,bytes32,uint256,bool,uint256,uint256",
        "0xae8de4e2",
        "O3",
        14,
    ),
    (
        "validateFreezePrimaryAssignmentV1",
        "bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,"
        "bytes32,bytes32,bool,bytes32,uint256,bool,uint8,bool,uint8,bool,"
        "uint8,bool,uint8,bool,uint8,bool,uint256,uint256,uint256",
        "0xa76cbd87",
        "O4",
        27,
    ),
    (
        "validateSetRoyaltyAssignmentV1",
        "uint8,uint256,bytes32,uint16,bool,bytes32,uint256,bytes32,uint256,"
        "uint8,uint8,uint256,uint256",
        "0x7e18b9d4",
        "O5",
        13,
    ),
    (
        "validateClearRoyaltyAssignmentV1",
        "uint8,uint256,uint256,bytes32,uint256,uint8,uint8,uint256,uint256",
        "0x02c57ac5",
        "O6",
        9,
    ),
    (
        "validateFreezeRoyaltyAssignmentV1",
        "uint8,uint256,uint8,bool,uint256,bytes32,bytes32,bytes32,uint256,"
        "uint256,uint256,uint256",
        "0x5e1f43f2",
        "O7",
        12,
    ),
    (
        "validateFreezeArtistRoyaltyAssignmentV1",
        "uint256,bytes32,uint256,bytes32,bytes32,uint256,uint256,uint256",
        "0x600e740d",
        "O8",
        8,
    ),
    (
        "validateSnapshotTokenRoyaltyAtMintV1",
        "uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,"
        "uint256,bytes32,address,uint16,bytes32,bytes32,bytes32,bytes32,bool,"
        "bytes32,bytes32,bytes32,uint256,bytes32,bytes32,bytes32,uint256,"
        "uint256,uint8,uint8",
        "0x2664335b",
        "O9",
        28,
    ),
)

REVENUE_READ_INTERFACES = (
    (
        "CORE_READ_INTERFACE_V1",
        "0xb1fc0266",
        (
            ("lastAllocatedCollectionId()", "0x174a3aaf"),
            ("tokenCollectionIdentity(uint256)", "0xa6b638c9"),
        ),
    ),
    (
        "FACTORY_READ_INTERFACE_V1",
        "0x0200c7a8",
        (
            ("profileExists(bytes32)", "0x93e9701b"),
            ("splitWalletExists(bytes32)", "0x33c0a3d3"),
            ("walletFor(bytes32)", "0x7730ab1a"),
            ("profileEntriesHash(bytes32)", "0x472f4153"),
            ("profileMetadataURIHash(bytes32)", "0x9236fe29"),
        ),
    ),
    (
        "ARTIST_READ_INTERFACE_V1",
        "0xed34ed02",
        (
            (
                "requireEconomicsConsent(uint256,bytes32,uint8,uint256,bytes32)",
                "0xeb663bcc",
            ),
            ("isRoyaltyFreezeAuthorized(uint256,bytes32)", "0x0652d6ce"),
        ),
    ),
    (
        "WALLET_READ_INTERFACE_V1",
        "0x08386eba",
        (("profileId()", "0x08386eba"),),
    ),
)

MINT_MANAGER_SIGNATURES = (
    "configurePhase(uint256,bytes32,(bool,uint64,uint64,uint32,bytes32,bytes32),"
    "(address,bytes32,bytes32,bytes32,uint32,uint32),bytes32[],"
    "(bool,uint8,uint8,uint8,uint64,uint64,bytes32)[])",
    "counterConfig(uint256,bytes32,bytes32)",
    "executePreparedMint((uint256,bytes32,address,address,address[],address[],"
    "bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)",
    "executeSingleStepMint((uint256,bytes32,address,address,address[],address[],"
    "bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)",
    "isAuthorizationUsed(bytes32)",
    "isNullifierUsed(bytes32)",
    "isOperationRootUsed(bytes32)",
    "isStreamMintManager()",
    "nextOperationNonce()",
    "phase(uint256,bytes32)",
    "phaseCounterIds(uint256,bytes32)",
    "phaseExecutor(uint256,bytes32,address)",
    "phaseGate(uint256,bytes32)",
    "phasePolicyGrace(uint256,bytes32)",
    "phasePolicyHash(uint256,bytes32)",
    "previewCounterValueKey(uint256,bytes32,bytes32,bytes32)",
    "previewSingleStepMintOperation((uint256,bytes32,address,address,address[],"
    "address[],bytes[],bytes32[],bytes32,bytes32,bytes32,bytes),bytes)",
    "previewSubjectKey(uint8,uint256,bytes32,bytes32,address,address,address,"
    "address,bytes32)",
    "setPhaseExecutor(uint256,bytes32,address,bool)",
    "setPhasePaused(uint256,bytes32,bool)",
)


ARTIST_HASH_CONSTANTS = (
    (
        "ARTIST_REGISTRY_VALIDATION_ADAPTER_MARKER_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_ADAPTER_V1",
        "0xaa8aa162210fdc2e9a4bb1a699c8ca727caa6e32678e485c3ca393ded0b8942f",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_SCHEMA_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_SCHEMA_V1",
        "0x79bb8f9129afd2d202da49e0fd1b7989e53c315752c11c10a5a16414edfb87fc",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_DEPENDENCIES_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_DEPENDENCIES_V1",
        "0x3c8dc77e31156b5173be953d6318b2ed2f7385fed0cc546f97b7c7a6c7554ac1",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_INTENT_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_INTENT_V1",
        "0x9ec5b1e09aed7dfbcea902df5b082256071bd6c98268111c9c3007bf154a16e4",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_OBSERVATIONS_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_OBSERVATIONS_V1",
        "0xd5835935f8ae892842ce8d3bbc7cdbf26454812f2c2abf9a27675d66cd6d8920",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_RESULT_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_RESULT_V1",
        "0x80973b34d65ec99ded29f2d7840b5b1fc129e41912f0298f3241ea368a529416",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_MAGIC_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_MAGIC_V1",
        "0xe04bcf39e2e84f086ebf44b37096beeb7597e2df673b4c97ccfc20f9915ef2b5",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1",
        "0x1eddbd561e9bd9eb26cd6b9e19ebbfcdc94808c742f6a32f56cd702da252d04a",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_V1",
        "0x48477ab2fb17edcff85463270a97705efaba45d72f70e5f37d3d5add0cc05488",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_CHAIN_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_SIGNER_OBSERVATION_CHAIN_V1",
        "0x161c975cc642f7680061b276d2d7a11062ec67ca04c9bad95f2121ee59304f5f",
    ),
    (
        "ARTIST_REGISTRY_VALIDATION_EIP150_RESERVE_V1",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_EIP150_RESERVE_V1",
        "0xf28c4b5041a05e5148691cfe47726e171ba67f114f903d81767b4f869a8551df",
    ),
    (
        "GGP_ARTIST_ERC1271_VERIFY_GAS",
        "6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS",
        "0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5",
    ),
)

VALIDATION_CONTEXT_V1_TYPE = (
    "(address,address,address,bytes32,bytes32,bytes32,bytes32,bytes32,"
    "bytes32,bytes32,bytes32,address,address,bytes32,uint256,uint64,uint64,"
    "uint256,uint64,uint32,uint8,uint8,bytes4)"
)

ARTIST_FAMILY_SUFFIXES = {
    "F": "",
    "Q": ",bytes",
    "U": ",string",
    "QU": ",bytes,string",
    "B": (
        ",(address,bytes32,bytes32)[],(uint32,uint8,uint32)[],bytes,string,"
        "string,string"
    ),
    "CI": ",bytes,string,string,string",
    "IR": ",bytes,string,string,bytes",
    "G": ",address[],bytes",
    "R": ",bytes",
    "L": ",bytes32[],bytes",
    "X": ",bytes32[],bytes",
    "D": ",bytes,bytes",
    "M": ",(uint8,bytes32,uint64,bytes32,bytes32),bytes32[]",
}

ARTIST_OPERATION_SPECS = (
    (1, "proposeArtistBinding", "Present", "B", "0xd413fdec"),
    (2, "acceptArtistBinding", "Present", "Q", "0xbff12590"),
    (3, "refuseArtistBinding", "Absent", "QU", "0x9f94e137"),
    (4, "withdrawArtistBinding", "Absent", "U", "0x55cc8780"),
    (5, "proposeCollaboratorIdentity", "Absent", "CI", "0xfb6d79d5"),
    (6, "acceptCollaboratorIdentity", "Absent", "Q", "0x8dd23f69"),
    (7, "acceptCollaborator", "Absent", "Q", "0x50a122eb"),
    (8, "declarePlatformWorks", "Absent", "F", "0xd483390f"),
    (9, "filePlatformWorksClaim", "Absent", "U", "0x9f2ab3c0"),
    (10, "fileAttributionClaim", "Absent", "U", "0x2b9f95ab"),
    (11, "setPlatformWorksContest", "Absent", "F", "0xc4b983cc"),
    (12, "recordArtistSanction", "Present", "Q", "0xb8cc3b3e"),
    (13, "confirmSanctionFinalized", "Absent", "F", "0x9c32b4f8"),
    (14, "recordPolicyConsent", "Present", "Q", "0xcdaecafe"),
    (15, "recordEconomicsConsent", "Present", "Q", "0x795e4001"),
    (16, "recordSaleConsent", "Present", "Q", "0x417c166a"),
    (17, "recordContentConsent", "Present", "Q", "0x6d52cdea"),
    (18, "recordPayoutDesignation", "Present", "Q", "0x43fd541e"),
    (19, "recordStewardSanctionGrant", "Absent", "Q", "0x8c4a56d2"),
    (20, "authorizeArtistRoyaltyFreeze", "Present", "Q", "0x63633323"),
    (21, "authorizeArtistContentFreeze", "Present", "L", "0x9e07a80c"),
    (22, "recordRecoveryApproval", "Present", "Q", "0x696ed9d5"),
    (23, "recordUnavailabilityFinding", "Present", "F", "0xfedbc352"),
    (24, "recordArtistAttestation", "Absent", "Q", "0x45001de2"),
    (25, "recordIdentityRevision", "Absent", "IR", "0x88ba1b08"),
    (26, "grantArtistDelegation", "Absent", "Q", "0xfd29f33e"),
    (27, "revokeArtistDelegation", "Absent", "Q", "0x37c7ed3b"),
    (28, "setArtistGuardians", "Absent", "G", "0x8857dc0e"),
    (29, "rotateArtistAddress", "Absent", "R", "0x8de2d745"),
    (30, "approveArtistRotation", "Absent", "F", "0x46f527b9"),
    (31, "vetoArtistRotation", "Absent", "F", "0xd143916d"),
    (32, "executeArtistRotation", "Absent", "F", "0x4ff765e7"),
    (33, "contestArtistIdentity", "Absent", "F", "0x46fef903"),
    (34, "vetoIdentityRecovery", "Absent", "F", "0x81ab3e62"),
    (35, "recoverArtistIdentity", "Absent", "X", "0xee2e0831"),
    (36, "designateSuccessor", "Absent", "Q", "0x2e8b0ad5"),
    (37, "recordEstateDirective", "Absent", "D", "0x55c714a4"),
    (38, "requestEstateActivation", "Absent", "Q", "0x219a1989"),
    (39, "cancelEstateActivation", "Absent", "F", "0xdf4208c9"),
    (40, "executeEstateActivation", "Absent", "F", "0x405071c7"),
    (41, "initiateArtistDormancy", "Absent", "U", "0x36857dd3"),
    (42, "cancelArtistDormancy", "Absent", "F", "0xa1d218c5"),
    (43, "completeArtistDormancy", "Absent", "F", "0x414e73ba"),
    (44, "openAttributionDispute", "Absent", "QU", "0xe5faa2a1"),
    (45, "recordCounterStatement", "Absent", "QU", "0xa3c13205"),
    (46, "resolveAttributionDispute", "Absent", "F", "0xd082de90"),
    (47, "revokeAttribution", "Absent", "QU", "0xaeed9215"),
    (48, "vetoAttributionRepudiation", "Absent", "F", "0x252d66bd"),
    (49, "cancelAttributionRepudiation", "Absent", "F", "0xb0f5885f"),
    (50, "executeAttributionRepudiation", "Absent", "F", "0xd61f0e0e"),
    (51, "revokePriorAddressStanding", "Absent", "Q", "0x8381ab55"),
    (52, "recordContentRatification", "Present", "Q", "0x9f5e1872"),
    (53, "approvePlatformWorksCorrection", "Absent", "F", "0x8b1b5cb4"),
    (54, "revokeArtistAuthorization", "Absent", "Q", "0x798ea3ac"),
    (55, "commitArtistHistoryImportRoot", "Absent", "F", "0x1910f961"),
    (56, "verifyImportedLaneTip", "Absent", "M", "0xf53d3e24"),
    (57, "observeRegistryCutover", "Absent", "F", "0x8d630c57"),
)

# Semantic row data accepted by the issue #670 interface-freeze decision.
# The compact row layout is declared by artist_operation_matrix_artifact().
ARTIST_OPERATION_MATRIX_ROWS = (
    [1, "proposeArtistBinding", "B", "0xd413fdec", "0xdd14ebb0", "6529STREAM_ARTIST_REGISTRY_WRITE_PROPOSE_ARTIST_BINDING_V1", "ROLE_ARTIST_REGISTRY_ADMIN; corrective generation also requires terminal arbiter action", "NONE", "NONE", "0x003fff", "collectionId:u256;artistId:b32;artistAddress:addr;bindingGeneration:u64;identityRecordHash:b32;consentMode:u8;saleConsentScope:u8;registryImmutabilityElection:u8;collabPolicyMode:u8;collabThreshold:u32;collaboratorSetHash:b32;capabilityPolicySetHash:b32;reasonHash:b32;registrationNonce:u256", "collection attribution state; next generation; collection identity; prior terminal correction approval", "proposal key; registration allocator nonce", "ARTIST_BINDING_DOMAIN", "ARTIST_ID_DOMAIN", "CORE", "ArtistIdentityRegistered|ArtistBindingProposed|ArtistAttributionStateChanged", []],
    [2, "acceptArtistBinding", "Q", "0xbff12590", "0x139b4368", "6529STREAM_ARTIST_REGISTRY_WRITE_ACCEPT_ARTIST_BINDING_V1", "exact proposed artist; collaborator policy where applicable", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ACCEPTANCE_TYPEHASH", "0x00007f", "collectionId:u256;artistId:b32;bindingGeneration:u64;bindingHash:b32;identityRecordHash:b32;acceptanceKind:u8;currentAttributionState:u8", "live proposal; signer is named artist; required collaborator acceptance set; binding generation", "artist nonce allocator; signed digest revocation; acceptance uniqueness", "ACCEPTANCE_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistBindingAccepted|ArtistAttributionStateChanged", []],
    [3, "refuseArtistBinding", "QU", "0x9f94e137", "0x0ab86b3d", "6529STREAM_ARTIST_REGISTRY_WRITE_REFUSE_ARTIST_BINDING_V1", "exact proposed artist", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_BINDING_REFUSAL_TYPEHASH", "0x00007f", "collectionId:u256;artistId:b32;bindingGeneration:u64;bindingHash:b32;reasonHash:b32;oldState:u8;newState:u8", "live CLAIMED proposal; exact generation and binding hash", "artist nonce allocator; signed digest revocation; refusal uniqueness", "BINDING_REFUSAL_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistAttributionStateChanged", []],
    [4, "withdrawArtistBinding", "U", "0x55cc8780", "0x603232da", "6529STREAM_ARTIST_REGISTRY_WRITE_WITHDRAW_ARTIST_BINDING_V1", "exact stored proposal author", "DIRECT_CALLER", "NONE", "0x00003f", "collectionId:u256;artistId:b32;bindingGeneration:u64;bindingHash:b32;reasonHash:b32;newState:u8", "live CLAIMED proposal; stored proposer; exact generation", "proposal terminal-transition key", "NONE", "EXISTING:ARTIST_BINDING_DOMAIN", "LOCAL", "ArtistAttributionStateChanged", []],
    [5, "proposeCollaboratorIdentity", "CI", "0xfb6d79d5", "0xe761595a", "6529STREAM_ARTIST_REGISTRY_WRITE_PROPOSE_COLLABORATOR_IDENTITY_V1", "ROLE_ARTIST_REGISTRY_ADMIN", "NONE", "NONE", "0x000007", "account:addr;identityRecordHash:b32;reasonHash:b32", "account has no accepted identity; proposal hash absent", "collaborator proposal key", "NONE", "NONE", "LOCAL", "CollaboratorIdentityProposed", []],
    [6, "acceptCollaboratorIdentity", "Q", "0x8dd23f69", "0xb3e22398", "6529STREAM_ARTIST_REGISTRY_WRITE_ACCEPT_COLLABORATOR_IDENTITY_V1", "exact named account", "DIRECT_OR_DEADLINE", "STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH", "0x00000f", "account:addr;artistId:b32;identityRecordHash:b32;registrationNonce:u256", "live collaborator identity proposal; account unregistered; artistId recomputation", "account nonce allocator; signed digest revocation; identity uniqueness", "ARTIST_ID_DOMAIN", "NONE", "SIGNER", "ArtistIdentityRegistered", []],
    [7, "acceptCollaborator", "Q", "0x50a122eb", "0xaf0cc0b9", "6529STREAM_ARTIST_REGISTRY_WRITE_ACCEPT_COLLABORATOR_V1", "exact listed collaborator; binding collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH", "0x00007f", "collectionId:u256;collaborator:addr;collaboratorArtistId:b32;bindingGeneration:u64;bindingHash:b32;role:b32;shareLabelId:b32", "live proposal; immutable collaborator row; acceptance absent", "collaborator nonce allocator; signed digest revocation; row acceptance uniqueness", "ACCEPTANCE_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "CollaboratorAccepted|ArtistAttributionStateChanged", []],
    [8, "declarePlatformWorks", "F", "0xd483390f", "0x8fa131d9", "6529STREAM_ARTIST_REGISTRY_WRITE_DECLARE_PLATFORM_WORKS_V1", "ROLE_ARTIST_REGISTRY_ADMIN before artist policy registration", "NONE", "NONE", "0x00000f", "collectionId:u256;declarationHash:b32;statementHash:b32;declaredAt:u64", "collection exists; no artist binding/policy; declaration absent", "collection declaration key", "PLATFORM_WORKS_DOMAIN", "NONE", "CORE", "PlatformWorksDeclared", []],
    [9, "filePlatformWorksClaim", "U", "0x9f2ab3c0", "0x86086769", "6529STREAM_ARTIST_REGISTRY_WRITE_FILE_PLATFORM_WORKS_CLAIM_V1", "permissionless claimant; caller recorded", "DIRECT_CALLER", "NONE", "0x00001f", "collectionId:u256;claimant:addr;evidenceHash:b32;reasonHash:b32;filedAt:u64", "collection exists; claim tuple not previously filed", "claim record hash uniqueness", "PLATFORM_WORKS_CLAIM_RECORD_DOMAIN", "NONE", "CORE", "PlatformWorksClaimFiled", []],
    [10, "fileAttributionClaim", "U", "0x2b9f95ab", "0x975339ba", "6529STREAM_ARTIST_REGISTRY_WRITE_FILE_ATTRIBUTION_CLAIM_V1", "permissionless claimant; caller recorded", "DIRECT_CALLER", "NONE", "0x00001f", "collectionId:u256;claimant:addr;evidenceHash:b32;reasonHash:b32;filedAt:u64", "collection exists; claim tuple not previously filed", "claim record hash uniqueness", "ATTRIBUTION_CLAIM_RECORD_DOMAIN", "NONE", "CORE", "AttributionClaimFiled", []],
    [11, "setPlatformWorksContest", "F", "0xc4b983cc", "0x71e4552d", "6529STREAM_ARTIST_REGISTRY_WRITE_SET_PLATFORM_WORKS_CONTEST_V1", "ROLE_ATTRIBUTION_ARBITER through exact Governance V2 action", "NONE", "NONE", "0x00007f", "collectionId:u256;contestState:u8;claimRecordHash:b32;evidenceHash:b32;reasonHash:b32;oldContestState:u8;newContestState:u8", "live claim; permitted contest transition; governance old/new state", "governance action id and claim transition key", "NONE", "EXISTING:PLATFORM_WORKS_CLAIM_RECORD_DOMAIN", "CORE|GOVERNANCE", "PlatformWorksContestChanged", []],
    [12, "recordArtistSanction", "Q", "0xb8cc3b3e", "0xb569ac0b", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_ARTIST_SANCTION_V1", "artist/successor/steward/delegate under CAP_SANCTION and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_SANCTION_TYPEHASH", "0x0000ff", "artistId:b32;scopeType:u8;collectionId:u256;tokenId:u256;scopeId:b32;sanctionSubjectHash:b32;statementHash:b32;bindingGeneration:u64", "binding/authority/collaborator policy; steward grant; Core burn cutoff; finality component facts", "all participant nonces; digest revocation; delegation use; sanction uniqueness", "SANCTION_RECORD_DOMAIN", "NONE", "CORE|FINALITY|SIGNER", "ArtistSanctionRecorded", [FINALITY_STOP_ID]],
    [13, "confirmSanctionFinalized", "F", "0x9c32b4f8", "0x20afefab", "6529STREAM_ARTIST_REGISTRY_WRITE_CONFIRM_SANCTION_FINALIZED_V1", "permissionless truth confirmation", "GOVERNANCE_OR_PERMISSIONLESS", "NONE", "0x00003f", "collectionId:u256;artistId:b32;bindingGeneration:u64;sanctionRecordHash:b32;finalityRecordHash:b32;priorAttributionState:u8", "executed current collection finality record includes exact sanction; state transition valid", "sanction-finalization transition key", "NONE", "EXISTING:SANCTION_RECORD_DOMAIN", "CORE|FINALITY", "ArtistAttributionStateChanged", [FINALITY_STOP_ID]],
    [14, "recordPolicyConsent", "Q", "0xcdaecafe", "0x7f25cf67", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_POLICY_CONSENT_V1", "consent-mode authority; delegate only for ARTIST_DELEGATED; collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_POLICY_CONSENT_TYPEHASH", "0x00003f", "artistId:b32;mintManager:addr;collectionId:u256;phaseId:b32;policyHash:b32;bindingGeneration:u64", "binding/consent mode/current phase/policy; authority and collaborator policy", "all participant nonces; digest revocation; delegation use; policy consent key", "POLICY_CONSENT_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistPolicyConsentRecorded", []],
    [15, "recordEconomicsConsent", "Q", "0x795e4001", "0xa388e01a", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_ECONOMICS_CONSENT_V1", "artist economics authority; designation prerequisites; collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH", "0x0000ff", "artistId:b32;resolver:addr;collectionId:u256;revenueClass:b32;scope:u8;scopeId:u256;assignmentHash:b32;payoutDesignationRecordHash:b32", "binding/economics policy; operative payout designation; exact assignment transition", "all participant nonces; digest revocation; delegation use; consent key", "ECONOMICS_CONSENT_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistEconomicsConsentRecorded", []],
    [16, "recordSaleConsent", "Q", "0x417c166a", "0x771f87da", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_SALE_CONSENT_V1", "sale-consent authority; delegate only where permitted; collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_SALE_CONSENT_TYPEHASH", "0x00003f", "artistId:b32;saleAdapter:addr;collectionId:u256;saleId:b32;saleConfigHash:b32;bindingGeneration:u64", "binding/sale consent mode/current sale configuration; authority/collaborator policy", "all participant nonces; digest revocation; delegation use; sale consent key", "SALE_CONSENT_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistSaleConsentRecorded", []],
    [17, "recordContentConsent", "Q", "0x6d52cdea", "0xbac3de7d", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_CONTENT_CONSENT_V1", "content-consent authority and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH", "0x00003f", "artistId:b32;metadataContract:addr;collectionId:u256;familyId:b32;newStateHash:b32;bindingGeneration:u64", "binding/content consent mode/current content family state; collaborator policy", "all participant nonces; digest revocation; delegation use; content consent key", "CONTENT_CONSENT_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistContentConsentRecorded", []],
    [18, "recordPayoutDesignation", "Q", "0x43fd541e", "0xe47d9d33", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_PAYOUT_DESIGNATION_V1", "AUTH_ARTIST or capable AUTH_SUCCESSOR; never delegate/steward", "DIRECT_OR_SIGNED_AT", "STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH", "0x00000f", "artistId:b32;payoutAccount:addr;previousDesignationRecordHash:b32;bindingGeneration:u64", "current authority; previous designation head; account nonzero", "authority nonce; digest revocation; designation chain", "PAYOUT_DESIGNATION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistPayoutDesignationRecorded", []],
    [19, "recordStewardSanctionGrant", "Q", "0x8c4a56d2", "0x25c07cfa", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_STEWARD_SANCTION_GRANT_V1", "AUTH_ARTIST only", "DIRECT_OR_SIGNED_AT", "STREAM_STEWARD_SANCTION_GRANT_TYPEHASH", "0x00000f", "artistId:b32;granted:bool;statementHash:b32;previousGrantRecordHash:b32", "living artist authority; current grant head", "artist nonce; digest revocation; grant chain", "STEWARD_SANCTION_GRANT_RECORD_DOMAIN", "NONE", "SIGNER", "StewardSanctionGrantRecorded", []],
    [20, "authorizeArtistRoyaltyFreeze", "Q", "0x63633323", "0xc6e0e2aa", "6529STREAM_ARTIST_REGISTRY_WRITE_AUTHORIZE_ARTIST_ROYALTY_FREEZE_V1", "defensive royalty-freeze authority and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH", "0x00003f", "artistId:b32;resolver:addr;collectionId:u256;revenueClass:b32;expectedAssignmentHash:b32;bindingGeneration:u64", "binding/authority/collaborator policy; current assignment hash", "all participant nonces; digest revocation; delegation use; freeze key", "ROYALTY_FREEZE_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistRoyaltyFreezeAuthorized", []],
    [21, "authorizeArtistContentFreeze", "L", "0x9e07a80c", "0x90b32c9f", "6529STREAM_ARTIST_REGISTRY_WRITE_AUTHORIZE_ARTIST_CONTENT_FREEZE_V1", "defensive content-freeze authority and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH", "0x00003f", "artistId:b32;metadataContract:addr;collectionId:u256;lockClassesHash:b32;expectedStateHash:b32;bindingGeneration:u64", "binding/authority/collaborator policy; current content state; lock classes not already frozen", "all participant nonces; digest revocation; delegation use; freeze key", "CONTENT_FREEZE_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistContentFreezeAuthorized", []],
    [22, "recordRecoveryApproval", "Q", "0x696ed9d5", "0xd5d802ba", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_RECOVERY_APPROVAL_V1", "sanction-class authority; steward only at collection scope; collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH", "0x00007f", "artistId:b32;finalityRegistry:addr;collectionId:u256;finalityRecordHash:b32;recoveryManifestHash:b32;bindingGeneration:u64;coreBurnBlockedAtBlock:u256", "current executed collection finality; exact recovery manifest; steward appointment/grant/burn cutoff; collaborator policy", "all participant nonces; digest revocation; delegation use; recovery approval key", "RECOVERY_APPROVAL_RECORD_DOMAIN", "NONE", "CORE|FINALITY|SIGNER", "ArtistRecoveryApprovalRecorded", [FINALITY_STOP_ID]],
    [23, "recordUnavailabilityFinding", "F", "0xfedbc352", "0x37b9dba4", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_UNAVAILABILITY_FINDING_V1", "ROLE_ATTRIBUTION_ARBITER through delayed Governance V2", "NONE", "NONE", "0x00003f", "artistId:b32;collectionId:u256;evidenceHash:b32;reasonHash:b32;noticeEndsAt:u64;recordedAt:u64", "identity/binding current; no active contradictory finding; exact governance state", "governance action id; finding key", "UNAVAILABILITY_FINDING_RECORD_DOMAIN", "NONE", "CORE|GOVERNANCE", "ArtistUnavailabilityFindingRecorded", []],
    [24, "recordArtistAttestation", "Q", "0x45001de2", "0xa629f82a", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_ARTIST_ATTESTATION_V1", "artist/successor/steward/delegate under CAP_ATTEST; collaborator policy where applicable", "DIRECT_OR_SIGNED_AT", "STREAM_ARTIST_ATTESTATION_TYPEHASH", "0x0001ff", "artistId:b32;collectionId:u256;subjectKind:u8;subjectId:b32;subjectStateHash:b32;schemaId:b32;statementHash:b32;statementURIHash:b32;bindingGeneration:u64", "current subject state; binding/authority/capability/collaborator policy", "all participant nonces; digest revocation; delegation use; attestation key", "ATTESTATION_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistAttestationRecorded", []],
    [25, "recordIdentityRevision", "IR", "0x88ba1b08", "0x7fede0a4", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_IDENTITY_REVISION_V1", "AUTH_ARTIST or capable AUTH_SUCCESSOR; never delegate/steward", "DIRECT_OR_SIGNED_AT", "STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH", "0x00003f", "artistId:b32;previousRecordHash:b32;revisedRecordHash:b32;identityDocumentHash:b32;displayNameHash:b32;identityURIHash:b32", "current authority; previous identity record head; revised record recomputation", "authority nonce; digest revocation; identity revision chain", "IDENTITY_REVISION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistIdentityRevisionRecorded", []],
    [26, "grantArtistDelegation", "Q", "0xfd29f33e", "0x9595e14b", "6529STREAM_ARTIST_REGISTRY_WRITE_GRANT_ARTIST_DELEGATION_V1", "artist authority only; nondelegable capabilities rejected", "DIRECT_OR_NONCE_ONLY", "STREAM_ARTIST_DELEGATION_TYPEHASH", "0x0000ff", "artistId:b32;delegate:addr;collectionId:u256;capabilities:u32;notBefore:u64;expiresAt:u64;maxUses:u64;constraintsHash:b32", "current artist authority; delegate/capability constraints; no conflicting active delegation", "artist nonce; digest revocation; delegation key", "DELEGATION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistDelegationGranted", []],
    [27, "revokeArtistDelegation", "Q", "0x37c7ed3b", "0x1eba4321", "6529STREAM_ARTIST_REGISTRY_WRITE_REVOKE_ARTIST_DELEGATION_V1", "exact granting artist authority", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_DELEGATION_REVOCATION_TYPEHASH", "0x00000f", "artistId:b32;delegate:addr;delegationRecordHash:b32;reasonHash:b32", "active matching delegation; granting authority lineage", "artist nonce; digest revocation; one-way delegation revocation", "DELEGATION_REVOCATION_RECORD_DOMAIN", "EXISTING:DELEGATION_RECORD_DOMAIN", "SIGNER", "ArtistDelegationRevoked", []],
    [28, "setArtistGuardians", "G", "0x8857dc0e", "0x6cfefddb", "6529STREAM_ARTIST_REGISTRY_WRITE_SET_ARTIST_GUARDIANS_V1", "artist/capable successor/steward; displacement requires capability", "DIRECT_OR_SIGNED_AT", "STREAM_ARTIST_GUARDIAN_SET_TYPEHASH", "0x00001f", "artistId:b32;guardiansHash:b32;approvalThreshold:u32;minContestSeconds:u64;previousGuardianSetRecordHash:b32", "current authority/capability; prior guardian set; threshold consistency", "authority nonce; digest revocation; guardian-set chain", "GUARDIAN_SET_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistGuardianSetUpdated", []],
    [29, "rotateArtistAddress", "R", "0x8de2d745", "0x193e2c5b", "6529STREAM_ARTIST_REGISTRY_WRITE_ROTATE_ARTIST_ADDRESS_V1", "current authority old-side plus exact new-address acceptance", "TWO_SIDED_DEADLINE", "STREAM_ARTIST_KEY_ROTATION_TYPEHASH|STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH", "0x00003f", "artistId:b32;oldAddress:addr;newAddress:addr;reasonHash:b32;contestEndsAt:u64;previousTransitionRecordHash:b32", "current operative authority; no active conflicting transition; guardian set and contest window", "old/new nonce allocators; both digest revocations; rotation key", "ROTATION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistRotationStaged", []],
    [30, "approveArtistRotation", "F", "0x46f527b9", "0x66b0b9e5", "6529STREAM_ARTIST_REGISTRY_WRITE_APPROVE_ARTIST_ROTATION_V1", "direct registered guardian", "DIRECT_CALLER", "NONE", "0x00000f", "artistId:b32;rotationRecordHash:b32;guardian:addr;approvalCount:u32", "active rotation; caller in staged guardian snapshot; approval absent", "guardian approval key", "NONE", "EXISTING:ROTATION_RECORD_DOMAIN", "LOCAL", "ArtistRotationGuardianApproved", []],
    [31, "vetoArtistRotation", "F", "0xd143916d", "0x2d52ca83", "6529STREAM_ARTIST_REGISTRY_WRITE_VETO_ARTIST_ROTATION_V1", "direct guardian/current authority/designated successor/unrevoked prior address", "DIRECT_CALLER", "NONE", "0x00000f", "artistId:b32;rotationRecordHash:b32;vetoer:addr;reasonHash:b32", "active rotation; caller eligible; transition not executed/vetoed", "rotation veto key", "NONE", "EXISTING:ROTATION_RECORD_DOMAIN", "LOCAL", "ArtistRotationVetoed", []],
    [32, "executeArtistRotation", "F", "0x4ff765e7", "0x8d7c18b9", "6529STREAM_ARTIST_REGISTRY_WRITE_EXECUTE_ARTIST_ROTATION_V1", "permissionless after window or guardian quorum", "GOVERNANCE_OR_PERMISSIONLESS", "NONE", "0x00003f", "artistId:b32;oldAddress:addr;newAddress:addr;rotationRecordHash:b32;reasonHash:b32;authorityClass:u8", "active nonvetoed rotation; time/quorum satisfied; identity uncontested", "rotation execution key; old authority retirement", "NONE", "EXISTING:ROTATION_RECORD_DOMAIN", "LOCAL", "ArtistAddressRotated", []],
    [33, "contestArtistIdentity", "F", "0x46fef903", "0x75a52e4c", "6529STREAM_ARTIST_REGISTRY_WRITE_CONTEST_ARTIST_IDENTITY_V1", "guardian/unrevoked prior/designated successor or staged arbiter", "DIRECT_CALLER", "NONE", "0x00003f", "artistId:b32;subjectRecordHash:b32;contester:addr;evidenceHash:b32;reasonHash:b32;contestedAt:u64", "eligible standing; identity/transition current; no duplicate contest", "contest record hash and subject key", "IDENTITY_CONTEST_RECORD_DOMAIN", "NONE", "GOVERNANCE", "ArtistIdentityContested", []],
    [34, "vetoIdentityRecovery", "F", "0x81ab3e62", "0x93b72e53", "6529STREAM_ARTIST_REGISTRY_WRITE_VETO_IDENTITY_RECOVERY_V1", "direct eligible pre-transition guardian", "DIRECT_CALLER", "NONE", "0x00000f", "artistId:b32;recoveryActionId:b32;vetoer:addr;reasonHash:b32", "pending recovery; guardian belongs to pre-transition snapshot; veto absent", "recovery veto key", "NONE", "NONE", "LOCAL", "ArtistIdentityRecoveryVetoed", []],
    [35, "recoverArtistIdentity", "X", "0xee2e0831", "0x951577eb", "6529STREAM_ARTIST_REGISTRY_WRITE_RECOVER_ARTIST_IDENTITY_V1", "terminal-freeze arbiter action plus new-address acceptance", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH", "0x0001ff", "artistId:b32;oldAddress:addr;newAddress:addr;vestedAuthorityClass:u8;evidenceHash:b32;reasonHash:b32;supersededRecordsHash:b32;governanceActionId:b32;recoveredAt:u64", "contested/unavailable identity; terminal governance action; guardian veto checks; exact supersession set", "new authority nonce/digest; governance action; recovery key", "IDENTITY_RECOVERY_RECORD_DOMAIN", "IDENTITY_RECOVERY_SUPERSESSION_DOMAIN", "GOVERNANCE|SIGNER", "ArtistIdentityRecovered", []],
    [36, "designateSuccessor", "Q", "0x2e8b0ad5", "0xd2d688e7", "6529STREAM_ARTIST_REGISTRY_WRITE_DESIGNATE_SUCCESSOR_V1", "AUTH_ARTIST only", "DIRECT_OR_SIGNED_AT", "STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH", "0x00003f", "artistId:b32;successor:addr;successorKind:u8;grantedCapabilities:u32;conditionsHash:b32;directiveHash:b32", "living artist authority; prior designation head; successor constraints", "artist nonce; digest revocation; succession chain", "SUCCESSION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistSuccessorDesignated", []],
    [37, "recordEstateDirective", "D", "0x55c714a4", "0xd47993d7", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_ESTATE_DIRECTIVE_V1", "AUTH_ARTIST only", "DIRECT_OR_SIGNED_AT", "STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH", "0x00000f", "artistId:b32;grantedCapabilities:u32;forbiddenCapabilities:u32;directivePayloadHash:b32", "living artist authority; directive capability masks disjoint/canonical", "artist nonce; digest revocation; directive chain", "DIRECTIVE_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistEstateDirectiveRecorded", []],
    [38, "requestEstateActivation", "Q", "0x219a1989", "0x5696e289", "6529STREAM_ARTIST_REGISTRY_WRITE_REQUEST_ESTATE_ACTIVATION_V1", "exact operative successor", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH", "0x00001f", "artistId:b32;successor:addr;evidenceHash:b32;noticeEndsAt:u64;operativeDesignationRecordHash:b32", "operative successor/designation; no live artist act or active request; evidence canonical", "successor nonce; digest revocation; activation request key", "ESTATE_ACTIVATION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistEstateActivationRequested", []],
    [39, "cancelEstateActivation", "F", "0xdf4208c9", "0x59a9bf3b", "6529STREAM_ARTIST_REGISTRY_WRITE_CANCEL_ESTATE_ACTIVATION_V1", "living artist-side authority", "DIRECT_CALLER", "NONE", "0x000007", "artistId:b32;activationRecordHash:b32;authorityClass:u8", "active request; living authority; activation not executed", "activation cancellation key", "NONE", "EXISTING:ESTATE_ACTIVATION_RECORD_DOMAIN", "LOCAL", "ArtistEstateActivationCancelled", []],
    [40, "executeEstateActivation", "F", "0x405071c7", "0xdbdec972", "6529STREAM_ARTIST_REGISTRY_WRITE_EXECUTE_ESTATE_ACTIVATION_V1", "permissionless after notice or exact delayed-governance accelerator", "GOVERNANCE_OR_PERMISSIONLESS", "NONE", "0x00003f", "artistId:b32;successor:addr;activationRecordHash:b32;evidenceHash:b32;noticeEndsAt:u64;effectiveCapabilities:u32", "request active; successor still operative; no living act/contest; time or exact governance accelerator", "activation execution key; governance action when accelerated", "NONE", "EXISTING:ESTATE_ACTIVATION_RECORD_DOMAIN", "GOVERNANCE", "ArtistSuccessionActivated", []],
    [41, "initiateArtistDormancy", "U", "0x36857dd3", "0x778a4562", "6529STREAM_ARTIST_REGISTRY_WRITE_INITIATE_ARTIST_DORMANCY_V1", "ROLE_ARTIST_DORMANCY_ADMIN through staged Governance V2", "NONE", "NONE", "0x00001f", "artistId:b32;evidenceHash:b32;reasonHash:b32;noticeEndsAt:u64;priorLivenessAt:u64", "dormancy threshold elapsed; no active notice; exact governance old/new state", "governance action; dormancy notice key", "NONE", "NONE", "GOVERNANCE", "ArtistDormancyInitiated", []],
    [42, "cancelArtistDormancy", "F", "0xa1d218c5", "0xeab842f1", "6529STREAM_ARTIST_REGISTRY_WRITE_CANCEL_ARTIST_DORMANCY_V1", "authenticated artist/delegate/designated-successor liveness", "DIRECT_CALLER", "NONE", "0x00000f", "artistId:b32;dormancyNoticeHash:b32;canceller:addr;authorityClass:u8", "active dormancy notice; caller has liveness standing", "dormancy cancellation key", "NONE", "NONE", "LOCAL", "ArtistDormancyCancelled", []],
    [43, "completeArtistDormancy", "F", "0x414e73ba", "0x64d523e9", "6529STREAM_ARTIST_REGISTRY_WRITE_COMPLETE_ARTIST_DORMANCY_V1", "second staged Governance V2 action after notice", "NONE", "NONE", "0x00003f", "artistId:b32;dormancyNoticeHash:b32;noticeEndsAt:u64;vestedAuthority:addr;effectiveCapabilities:u32;contestState:u8", "notice elapsed; no liveness cancellation/contest; successor/steward fallback exact; governance old/new state", "second governance action; dormancy execution key", "NONE", "NONE", "GOVERNANCE", "ArtistDormancyCompleted", []],
    [44, "openAttributionDispute", "QU", "0xe5faa2a1", "0xd33d9fb2", "6529STREAM_ARTIST_REGISTRY_WRITE_OPEN_ATTRIBUTION_DISPUTE_V1", "named standing or staged arbiter branch", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH", "0x0000ff", "collectionId:u256;bindingGeneration:u64;artistId:b32;disputeAction:u8=1;evidenceHash:b32;reasonHash:b32;priorState:u8;existingDisputeHash:b32", "binding generation/state; opener standing; reopen restrictions", "opener nonce/digest or governance action; dispute key", "DISPUTE_RECORD_DOMAIN", "NONE", "CORE|GOVERNANCE|SIGNER", "AttributionDisputeOpened|ArtistAttributionStateChanged", []],
    [45, "recordCounterStatement", "QU", "0xa3c13205", "0x3eb542c3", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_COUNTER_STATEMENT_V1", "disputed binding authority under CAP_DISPUTE and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH", "0x0000ff", "collectionId:u256;bindingGeneration:u64;artistId:b32;disputeAction:u8=3;evidenceHash:b32;reasonHash:b32;disputeRecordHash:b32;counterStatementHead:b32", "live dispute; signer standing/capability/collaborator policy; no conflicting counter statement", "all participant nonces; digest revocation; counter-statement key", "DISPUTE_RECORD_DOMAIN", "EXISTING:DISPUTE_RECORD_DOMAIN", "SIGNER", "AttributionCounterStatementRecorded", []],
    [46, "resolveAttributionDispute", "F", "0xd082de90", "0x3f3a0f2e", "6529STREAM_ARTIST_REGISTRY_WRITE_RESOLVE_ATTRIBUTION_DISPUTE_V1", "staged arbiter Governance V2; terminal where REVOKE", "NONE", "NONE", "0x0000ff", "collectionId:u256;bindingGeneration:u64;disputeRecordHash:b32;resolution:u8;restoredState:u8;evidenceHash:b32;reasonHash:b32;counterStatementRecordHash:b32", "live dispute; resolution class and exact governance old/new state", "governance action; dispute resolution key", "NONE", "EXISTING:DISPUTE_RECORD_DOMAIN", "CORE|GOVERNANCE", "AttributionDisputeResolved|ArtistAttributionStateChanged", []],
    [47, "revokeAttribution", "QU", "0xaeed9215", "0xc00e6811", "6529STREAM_ARTIST_REGISTRY_WRITE_REVOKE_ATTRIBUTION_V1", "bound artist-side repudiation authority and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH", "0x0000ff", "collectionId:u256;bindingGeneration:u64;artistId:b32;disputeAction:u8=4;evidenceHash:b32;reasonHash:b32;executableAt:u64;currentAttributionState:u8", "accepted/sanctioned binding; authority/collaborator policy; no live repudiation", "all participant nonces; digest revocation; repudiation key", "ATTRIBUTION_REPUDIATION_RECORD_DOMAIN", "NONE", "SIGNER", "AttributionRepudiationStaged", []],
    [48, "vetoAttributionRepudiation", "F", "0x252d66bd", "0x4982b5ec", "6529STREAM_ARTIST_REGISTRY_WRITE_VETO_ATTRIBUTION_REPUDIATION_V1", "direct registered guardian", "DIRECT_CALLER", "NONE", "0x00000f", "collectionId:u256;repudiationRecordHash:b32;vetoer:addr;reasonHash:b32", "active repudiation; caller in guardian snapshot; veto absent", "repudiation veto key", "NONE", "EXISTING:ATTRIBUTION_REPUDIATION_RECORD_DOMAIN", "LOCAL", "AttributionRepudiationVetoed", []],
    [49, "cancelAttributionRepudiation", "F", "0xb0f5885f", "0x3e6b08e9", "6529STREAM_ARTIST_REGISTRY_WRITE_CANCEL_ATTRIBUTION_REPUDIATION_V1", "exact authority that staged repudiation", "DIRECT_CALLER", "NONE", "0x00000f", "collectionId:u256;repudiationRecordHash:b32;canceller:addr;authorityClass:u8", "active repudiation; exact staging authority; not executed/vetoed", "repudiation cancellation key", "NONE", "EXISTING:ATTRIBUTION_REPUDIATION_RECORD_DOMAIN", "LOCAL", "AttributionRepudiationCancelled", []],
    [50, "executeAttributionRepudiation", "F", "0xd61f0e0e", "0x0978b3f8", "6529STREAM_ARTIST_REGISTRY_WRITE_EXECUTE_ATTRIBUTION_REPUDIATION_V1", "permissionless after contest window and all rechecks", "GOVERNANCE_OR_PERMISSIONLESS", "NONE", "0x00003f", "collectionId:u256;repudiationRecordHash:b32;executableAt:u64;priorState:u8;newState:u8;reasonHash:b32", "active nonvetoed repudiation; time elapsed; identity uncontested; binding generation unchanged", "repudiation execution key", "NONE", "EXISTING:ATTRIBUTION_REPUDIATION_RECORD_DOMAIN", "LOCAL", "ArtistAttributionStateChanged", []],
    [51, "revokePriorAddressStanding", "Q", "0x8381ab55", "0x3a491762", "6529STREAM_ARTIST_REGISTRY_WRITE_REVOKE_PRIOR_ADDRESS_STANDING_V1", "AUTH_ARTIST or capable AUTH_SUCCESSOR; never steward/delegate", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH", "0x00001f", "artistId:b32;revokedAddress:addr;retiredTransitionRecordHash:b32;reasonHash:b32;standingActive:bool", "current authority; address has revocable prior standing; transition record matches", "authority nonce; digest revocation; standing revocation key", "STANDING_REVOCATION_RECORD_DOMAIN", "NONE", "SIGNER", "PriorAddressStandingRevoked", []],
    [52, "recordContentRatification", "Q", "0x9f5e1872", "0xc9093e90", "6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_CONTENT_RATIFICATION_V1", "content-consent authority and collaborator policy", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH", "0x00001f", "artistId:b32;metadataContract:addr;collectionId:u256;contentStateHash:b32;bindingGeneration:u64", "binding/current content state; authority/collaborator policy; ratification absent", "all participant nonces; digest revocation; ratification key", "CONTENT_RATIFICATION_RECORD_DOMAIN", "NONE", "CORE|SIGNER", "ArtistContentRatificationRecorded", []],
    [53, "approvePlatformWorksCorrection", "F", "0x8b1b5cb4", "0x4d2aac2a", "6529STREAM_ARTIST_REGISTRY_WRITE_APPROVE_PLATFORM_WORKS_CORRECTION_V1", "terminal-freeze ROLE_ATTRIBUTION_ARBITER Governance V2", "NONE", "NONE", "0x0000ff", "collectionId:u256;claimRecordHash:b32;sustainedContestRecordHash:b32;evidenceHash:b32;reasonHash:b32;approvedAt:u64;nextBindingGeneration:u64;correctionRecordHash:b32", "sustained contest current; claim/collection match; no prior correction; governance old/new state", "terminal governance action; correction key", "PLATFORM_WORKS_CORRECTION_RECORD_DOMAIN", "NONE", "CORE|GOVERNANCE", "PlatformWorksCorrectionApproved", []],
    [54, "revokeArtistAuthorization", "Q", "0x798ea3ac", "0x0ecb04fc", "6529STREAM_ARTIST_REGISTRY_WRITE_REVOKE_ARTIST_AUTHORIZATION_V1", "exact identity authority; identity-scoped", "DIRECT_OR_DEADLINE", "STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH", "0x00001f", "artistId:b32;revokedDigest:b32;revokedNonce:u256;reasonHash:b32;revocationScope:u8", "current authority; digest/nonce belongs to artist scope; not already revoked", "authority nonce; digest revocation; target digest/nonce revocation", "AUTH_REVOCATION_RECORD_DOMAIN", "NONE", "SIGNER", "ArtistAuthorizationRevoked", []],
    [55, "commitArtistHistoryImportRoot", "F", "0x1910f961", "0x960f81a8", "6529STREAM_ARTIST_REGISTRY_WRITE_COMMIT_ARTIST_HISTORY_IMPORT_ROOT_V1", "staged Governance V2 on successor registry", "NONE", "NONE", "0x00003f", "predecessorRegistry:addr;importRoot:b32;snapshotBlock:u64;manifestHash:b32;bindingIndex:u256;predecessorCodeHash:b32", "predecessor immutable/readable; root nonzero; binding index next; governance old/new state", "governance action; import binding key", "NONE", "NONE", "GOVERNANCE|IMPORT", "ArtistHistoryImportRootCommitted", []],
    [56, "verifyImportedLaneTip", "M", "0xf53d3e24", "0x1b13ffae", "6529STREAM_ARTIST_REGISTRY_WRITE_VERIFY_IMPORTED_LANE_TIP_V1", "permissionless truth verification", "GOVERNANCE_OR_PERMISSIONLESS", "NONE", "0x0000ff", "bindingIndex:u256;laneKind:u8;laneKey:b32;sequence:u64;recordHash:b32;recordChainHash:b32;proofHash:b32;livePredecessorTip:b32", "binding/root current; Core pointer cut over; proof valid; leaf equals live predecessor tip; lane unverified", "verified lane key; import binding", "NONE", "ARTIST_HISTORY_IMPORT_LEAF_DOMAIN", "CORE|IMPORT", "ArtistHistoryLaneVerified", []],
    [57, "observeRegistryCutover", "F", "0x8d630c57", "0x04a73b23", "6529STREAM_ARTIST_REGISTRY_WRITE_OBSERVE_REGISTRY_CUTOVER_V1", "permissionless one-way truth observation", "GOVERNANCE_OR_PERMISSIONLESS", "NONE", "0x00000f", "successorTarget:addr;observedAt:u64;currentCoreArtistRegistry:addr;cutoverAlreadyObserved:bool", "bound Core pointer no longer names this registry; successor has code; latch false", "one-way cutover latch", "NONE", "NONE", "CORE|IMPORT", "ArtistRegistryCutoverObserved", []],
)

ARTIST_TYPEHASH_SPECS = (
    (
        "STREAM_ARTIST_ACCEPTANCE_TYPEHASH",
        "StreamArtistAcceptance(address core,uint256 collectionId,uint64 "
        "bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,"
        "uint256 nonce,uint64 deadline)",
        "0x863408883ac6994b06f1a735545fd486c6a1a53866fb8851488d56d1b54f92af",
    ),
    (
        "STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH",
        "StreamCollaboratorAcceptance(address core,uint256 collectionId,uint64 "
        "bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,"
        "bytes32 shareLabelId,uint256 nonce,uint64 deadline)",
        "0x636ddaeeea1f3879203e4707eba02a65484041c3869c8a04560af9a57886343b",
    ),
    (
        "STREAM_ARTIST_SANCTION_TYPEHASH",
        "StreamArtistSanction(address core,uint8 scopeType,uint256 collectionId,"
        "uint256 tokenId,bytes32 scopeId,bytes32 sanctionSubjectHash,"
        "bytes32 statementHash,uint256 nonce,uint64 deadline)",
        "0x0651c04c186a25456f0dc9ca0a4a29a5537f2aeb0fe7e69cb2d3d202b41549b3",
    ),
    (
        "STREAM_ARTIST_POLICY_CONSENT_TYPEHASH",
        "StreamArtistPolicyConsent(address core,address mintManager,uint256 "
        "collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,"
        "uint64 deadline)",
        "0xbb408425c14bb658b72c5c6d190446d6d3cce65e6cb127239882bff780982c2b",
    ),
    (
        "STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH",
        "StreamArtistEconomicsConsent(address core,address resolver,bytes32 "
        "revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,"
        "uint256 nonce,uint64 deadline)",
        "0x38c2c794170472cc1bbd6385664d7d8a409ce16455caa0db97392b80fbc4b434",
    ),
    (
        "STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH",
        "StreamArtistRoyaltyFreeze(address core,address resolver,uint256 "
        "collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,"
        "uint256 nonce,uint64 deadline)",
        "0x34f54304a829e6bd32c4bcd8d63f31f7652adf9d1d653b874107a0a93eee73c4",
    ),
    (
        "STREAM_ARTIST_DELEGATION_TYPEHASH",
        "StreamArtistDelegation(address core,address delegate,uint256 "
        "collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,"
        "uint64 maxUses,bytes32 constraintsHash,uint256 nonce)",
        "0x259b01d4bf9aa04d6f900a2f85548eebdbb07661fdf1eac68031895cadae6d0d",
    ),
    (
        "STREAM_ARTIST_ATTESTATION_TYPEHASH",
        "StreamArtistAttestation(address core,uint256 collectionId,uint8 "
        "subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,"
        "bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,"
        "uint64 signedAt)",
        "0x74b9521f5d5caa162fb97b3a7f8e6aa5352156e3a1ff7c8e8103092eaaeaaa08",
    ),
    (
        "STREAM_ARTIST_KEY_ROTATION_TYPEHASH",
        "StreamArtistKeyRotation(bytes32 artistId,address oldAddress,address "
        "newAddress,bytes32 reasonHash,uint256 nonce,uint64 deadline)",
        "0x5b4e68760703787cefafa5c70864d397b1de70e70818739680256a123fe7a184",
    ),
    (
        "STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH",
        "StreamArtistRotationAcceptance(bytes32 artistId,address oldAddress,"
        "address newAddress,uint256 nonce,uint64 deadline)",
        "0x87eea3b0d5e1275bbdc74e691b4e19a12e9e76b634bac03ae439ae584859ecd0",
    ),
    (
        "STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH",
        "StreamArtistSuccessorDesignation(bytes32 artistId,address successor,"
        "uint8 successorKind,uint32 grantedCapabilities,bytes32 conditionsHash,"
        "bytes32 directiveHash,uint256 nonce,uint64 signedAt)",
        "0x978b9dfcca0968239ea043e735357728a9489fe40067fea6673256206c83de15",
    ),
    (
        "STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH",
        "StreamArtistEstateDirective(bytes32 artistId,uint32 grantedCapabilities,"
        "uint32 forbiddenCapabilities,bytes32 directivePayloadHash,uint256 nonce,"
        "uint64 signedAt)",
        "0xa1f146b360069294c6453e91242bb36bb0245545d57b3c89e1cc73c25e953d31",
    ),
    (
        "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH",
        "StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 "
        "bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,"
        "bytes32 reasonHash,uint256 nonce,uint64 deadline)",
        "0x8b535108c442947650eb1dec541e1e10f715f240a1554e488f2d4a51afb31541",
    ),
    (
        "STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH",
        "StreamArtistAuthorizationRevocation(bytes32 artistId,bytes32 "
        "revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline)",
        "0xd1d93f1d81c2c2b5353543093ebfca89c460de55b540dfed4a019c7ac448f214",
    ),
    (
        "STREAM_ARTIST_GUARDIAN_SET_TYPEHASH",
        "StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 "
        "approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)",
        "0x397aa6a887bb93367eab618ebf56732031f29da75f932c71ea556746542ebafe",
    ),
    (
        "STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH",
        "StreamArtistContentConsent(address core,address metadataContract,"
        "uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 "
        "nonce,uint64 deadline)",
        "0x7908964dc70554ffd5c82353690255d1a8c338be77ffc0f8fb925a27d890587d",
    ),
    (
        "STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH",
        "StreamArtistContentFreeze(address core,address metadataContract,"
        "uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,"
        "uint256 nonce,uint64 deadline)",
        "0xfcb15d96b29996a5852bf06058ae82a7e8acaf7d7601b13fe881ada5d30fc63b",
    ),
    (
        "STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH",
        "StreamArtistRecoveryApproval(address core,address finalityRegistry,"
        "uint256 collectionId,bytes32 finalityRecordHash,bytes32 "
        "recoveryManifestHash,uint256 nonce,uint64 deadline)",
        "0x242bffdf15416a6743c57bd362683aa2933edcd42a4ef176f4e983a745eee511",
    ),
    (
        "STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH",
        "StreamArtistEstateActivation(bytes32 artistId,address successor,"
        "bytes32 evidenceHash,uint256 nonce,uint64 deadline)",
        "0x35ad5d0278eb067119334d7d4fddd596cad723598851900a95e6ad9a94e51a8a",
    ),
    (
        "STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH",
        "StreamArtistIdentityRevision(bytes32 artistId,bytes32 "
        "previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,"
        "uint64 signedAt)",
        "0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603",
    ),
    (
        "STREAM_ARTIST_SALE_CONSENT_TYPEHASH",
        "StreamArtistSaleConsent(address core,address saleAdapter,uint256 "
        "collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,"
        "uint64 deadline)",
        "0x5a0d2fee9c2248ad2b0735d54beb28b1decdd1adeb65c63c4016da70ec399045",
    ),
    (
        "STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH",
        "StreamArtistPayoutDesignation(bytes32 artistId,address payoutAccount,"
        "bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt)",
        "0xfd30c946c20c3c9415f06991c291231ff12c255c9cc849164de44f91cb72c213",
    ),
    (
        "STREAM_STEWARD_SANCTION_GRANT_TYPEHASH",
        "StreamStewardSanctionGrant(bytes32 artistId,bool granted,bytes32 "
        "statementHash,uint256 nonce,uint64 signedAt)",
        "0xb48c9f264543966930485ab31e707d91b18c4f9e8644f8dd4a8cbb38c2aea9f2",
    ),
    (
        "STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH",
        "StreamCollaboratorIdentityAcceptance(address account,bytes32 "
        "identityRecordHash,uint256 nonce,uint64 deadline)",
        "0x9a40f74dcb1bb82d3fa4b33ed2dedc82fab75d7dd6c4b04f86cf263a0b867380",
    ),
    (
        "STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH",
        "StreamArtistContentRatification(address core,address metadataContract,"
        "uint256 collectionId,bytes32 contentStateHash,uint256 nonce,"
        "uint64 deadline)",
        "0x56c622946d6da26c6684a8bfd94e3142562ae44e7da904bebe454f049c01b1f5",
    ),
    (
        "STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH",
        "StreamArtistStandingRevocation(bytes32 artistId,address revokedAddress,"
        "bytes32 reasonHash,uint256 nonce,uint64 deadline)",
        "0xc3782eba55027b9bef1f60b09cfbcfa48bbd834194f743ae92029711ae18f936",
    ),
)

ARTIST_TYPEHASH_ASSIGNMENTS = (
    ("acceptArtistBinding", "signed_mode", "STREAM_ARTIST_ACCEPTANCE_TYPEHASH", None),
    ("refuseArtistBinding", "signed_mode", None, "AR-33"),
    (
        "acceptCollaboratorIdentity",
        "signed_mode",
        "STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH",
        None,
    ),
    (
        "acceptCollaborator",
        "signed_mode",
        "STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH",
        None,
    ),
    ("recordArtistSanction", "signed_mode", "STREAM_ARTIST_SANCTION_TYPEHASH", None),
    (
        "recordPolicyConsent",
        "signed_mode",
        "STREAM_ARTIST_POLICY_CONSENT_TYPEHASH",
        None,
    ),
    (
        "recordEconomicsConsent",
        "signed_mode",
        "STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH",
        None,
    ),
    (
        "recordSaleConsent",
        "signed_mode",
        "STREAM_ARTIST_SALE_CONSENT_TYPEHASH",
        None,
    ),
    (
        "recordContentConsent",
        "signed_mode",
        "STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH",
        None,
    ),
    (
        "recordPayoutDesignation",
        "signed_mode",
        "STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH",
        None,
    ),
    (
        "recordStewardSanctionGrant",
        "signed_mode",
        "STREAM_STEWARD_SANCTION_GRANT_TYPEHASH",
        None,
    ),
    (
        "authorizeArtistRoyaltyFreeze",
        "signed_mode",
        "STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH",
        None,
    ),
    (
        "authorizeArtistContentFreeze",
        "signed_mode",
        "STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH",
        None,
    ),
    (
        "recordRecoveryApproval",
        "signed_mode",
        "STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH",
        None,
    ),
    (
        "recordArtistAttestation",
        "signed_mode",
        "STREAM_ARTIST_ATTESTATION_TYPEHASH",
        None,
    ),
    (
        "recordIdentityRevision",
        "signed_mode",
        "STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH",
        None,
    ),
    (
        "grantArtistDelegation",
        "signed_mode",
        "STREAM_ARTIST_DELEGATION_TYPEHASH",
        None,
    ),
    ("revokeArtistDelegation", "signed_mode", None, "AR-14"),
    (
        "setArtistGuardians",
        "signed_mode",
        "STREAM_ARTIST_GUARDIAN_SET_TYPEHASH",
        None,
    ),
    (
        "rotateArtistAddress",
        "old_side",
        "STREAM_ARTIST_KEY_ROTATION_TYPEHASH",
        None,
    ),
    (
        "rotateArtistAddress",
        "new_side",
        "STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH",
        None,
    ),
    (
        "recoverArtistIdentity",
        "new_side",
        "STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH",
        None,
    ),
    (
        "designateSuccessor",
        "signed_mode",
        "STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH",
        None,
    ),
    (
        "recordEstateDirective",
        "signed_mode",
        "STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH",
        None,
    ),
    (
        "requestEstateActivation",
        "signed_mode",
        "STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH",
        None,
    ),
    (
        "openAttributionDispute",
        "signed_path_dispute_action_1",
        "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH",
        None,
    ),
    (
        "recordCounterStatement",
        "signed_mode_dispute_action_3",
        "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH",
        None,
    ),
    (
        "revokeAttribution",
        "signed_mode_dispute_action_4",
        "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH",
        None,
    ),
    (
        "revokePriorAddressStanding",
        "signed_mode",
        "STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH",
        None,
    ),
    (
        "recordContentRatification",
        "signed_mode",
        "STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH",
        None,
    ),
    (
        "revokeArtistAuthorization",
        "signed_mode",
        "STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH",
        None,
    ),
)

ARTIST_MATRIX_ADDITIONAL_TYPEHASH_SPECS = (
    (
        "STREAM_ARTIST_BINDING_REFUSAL_TYPEHASH",
        "StreamArtistBindingRefusal(address core,uint256 collectionId,uint64 "
        "bindingGeneration,bytes32 bindingHash,bytes32 reasonHash,uint256 "
        "nonce,uint64 deadline)",
        "0xc893b08f32a42da1625fa6427599c670031a4718906493412194962b8605a4bc",
    ),
    (
        "STREAM_ARTIST_DELEGATION_REVOCATION_TYPEHASH",
        "StreamArtistDelegationRevocation(bytes32 artistId,address delegate,"
        "bytes32 delegationRecordHash,bytes32 reasonHash,uint256 nonce,"
        "uint64 deadline)",
        "0x014fd1a66a54ed0ac8a6ec104ec6c3a2e593265b3cd018c918b44792cbd51369",
    ),
)

ARTIST_MATRIX_TYPEHASH_ORDER = (
    "STREAM_ARTIST_ACCEPTANCE_TYPEHASH",
    "STREAM_ARTIST_BINDING_REFUSAL_TYPEHASH",
    "STREAM_COLLABORATOR_IDENTITY_ACCEPTANCE_TYPEHASH",
    "STREAM_COLLABORATOR_ACCEPTANCE_TYPEHASH",
    "STREAM_ARTIST_SANCTION_TYPEHASH",
    "STREAM_ARTIST_POLICY_CONSENT_TYPEHASH",
    "STREAM_ARTIST_ECONOMICS_CONSENT_TYPEHASH",
    "STREAM_ARTIST_SALE_CONSENT_TYPEHASH",
    "STREAM_ARTIST_CONTENT_CONSENT_TYPEHASH",
    "STREAM_ARTIST_PAYOUT_DESIGNATION_TYPEHASH",
    "STREAM_STEWARD_SANCTION_GRANT_TYPEHASH",
    "STREAM_ARTIST_ROYALTY_FREEZE_TYPEHASH",
    "STREAM_ARTIST_CONTENT_FREEZE_TYPEHASH",
    "STREAM_ARTIST_RECOVERY_APPROVAL_TYPEHASH",
    "STREAM_ARTIST_ATTESTATION_TYPEHASH",
    "STREAM_ARTIST_IDENTITY_REVISION_TYPEHASH",
    "STREAM_ARTIST_DELEGATION_TYPEHASH",
    "STREAM_ARTIST_DELEGATION_REVOCATION_TYPEHASH",
    "STREAM_ARTIST_GUARDIAN_SET_TYPEHASH",
    "STREAM_ARTIST_KEY_ROTATION_TYPEHASH",
    "STREAM_ARTIST_ROTATION_ACCEPTANCE_TYPEHASH",
    "STREAM_ARTIST_SUCCESSOR_DESIGNATION_TYPEHASH",
    "STREAM_ARTIST_ESTATE_DIRECTIVE_TYPEHASH",
    "STREAM_ARTIST_ESTATE_ACTIVATION_TYPEHASH",
    "STREAM_ARTIST_ATTRIBUTION_DISPUTE_TYPEHASH",
    "STREAM_ARTIST_STANDING_REVOCATION_TYPEHASH",
    "STREAM_ARTIST_CONTENT_RATIFICATION_TYPEHASH",
    "STREAM_ARTIST_AUTHORIZATION_REVOCATION_TYPEHASH",
)

ARTIST_MATRIX_DOMAIN_SPECS = (
    (
        "CURRENT_STATE_DOMAIN",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_CURRENT_STATE_V1",
        "0x608b904cf3adbb53bf0f90c572aa8e10a499172c67714a5ed48d322c6d0767b4",
    ),
    (
        "REPLAY_STATE_DOMAIN",
        "6529STREAM_ARTIST_REGISTRY_VALIDATION_REPLAY_STATE_V1",
        "0xcfb09f927c5a90339fe69e4489ead6ce0817b8ff85d24c9a519a83a989f79008",
    ),
)


def hash_constant_records(
    specifications: Iterable[tuple[str, str, str]]
) -> list[dict[str, str]]:
    records = []
    for name, preimage, expected in specifications:
        value = keccak_hex(preimage.encode("ascii"))
        require_equal(value, expected, name)
        records.append(
            {
                "name": name,
                "preimage_ascii": preimage,
                "value": value,
            }
        )
    return records


def function_records(
    specifications: Iterable[tuple[str, str]]
) -> list[dict[str, str]]:
    records = []
    for signature, expected in specifications:
        derived = selector(signature)
        require_equal(derived, expected, signature)
        records.append({"canonical_signature": signature, "selector": derived})
    return records


def revenue_entries() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    entries: list[dict[str, Any]] = []
    operations: list[dict[str, Any]] = []
    for name, suffix, expected, operation_id, operation_words in REVENUE_ENTRY_SPECS:
        if operation_id is None:
            signature = f"{name}()"
        else:
            signature = (
                f"{name}({DEPENDENCIES_V1_TYPE},{INTENT_HEADER_V1_TYPE},{suffix})"
            )
        derived = selector(signature)
        require_equal(derived, expected, signature)
        entries.append(
            {
                "canonical_signature": signature,
                "name": name,
                "selector": derived,
            }
        )
        if operation_id is not None and operation_words is not None:
            total_words = 19 + 18 + operation_words
            operations.append(
                {
                    "calldata_length_bytes": 4 + 32 * total_words,
                    "entry_selector": derived,
                    "operation_id": operation_id,
                    "operation_words": operation_words,
                    "root_words_after_selector": total_words,
                }
            )
    require_equal(len(entries), 12, "revenue entry count")
    require_equal(len(operations), 9, "revenue operation count")
    return entries, operations


def read_interface_records() -> list[dict[str, Any]]:
    interfaces: list[dict[str, Any]] = []
    for name, expected_interface_id, functions in REVENUE_READ_INTERFACES:
        records = function_records(functions)
        interface_id = xor_selectors(item["selector"] for item in records)
        require_equal(interface_id, expected_interface_id, name)
        interfaces.append(
            {
                "functions": records,
                "interface_id": interface_id,
                "name": name,
            }
        )

    mint_functions = [
        {
            "canonical_signature": signature,
            "selector": selector(signature),
        }
        for signature in MINT_MANAGER_SIGNATURES
    ]
    mint_interface_id = xor_selectors(
        item["selector"] for item in mint_functions
    )
    require_equal(mint_interface_id, "0xb4074ed7", "MINT_MANAGER_INTERFACE_ID")
    interfaces.append(
        {
            "functions": mint_functions,
            "interface_id": mint_interface_id,
            "name": "MINT_MANAGER_INTERFACE_ID",
        }
    )
    return interfaces


def artist_operations() -> list[dict[str, Any]]:
    operations: list[dict[str, Any]] = []
    for number, write_name, checkpoint, family, expected in ARTIST_OPERATION_SPECS:
        validation_name = f"validate{write_name[0].upper()}{write_name[1:]}V1"
        signature = (
            f"{validation_name}({VALIDATION_CONTEXT_V1_TYPE},bytes32[24]"
            f"{ARTIST_FAMILY_SUFFIXES[family]})"
        )
        derived = selector(signature)
        require_equal(derived, expected, signature)
        operations.append(
            {
                "canonical_signature": signature,
                "checkpoint": checkpoint.lower(),
                "family": family,
                "number": number,
                "normative_registry_write_name": write_name,
                "selector": derived,
                "validation_function": validation_name,
            }
        )
    require_equal(len(operations), 57, "artist validation entry count")
    return operations


def artist_family_records() -> list[dict[str, Any]]:
    records = (
        ("F", 47, None, "4 + 47*32 = 1508", ()),
        ("Q", 48, 1536, "4 + 1536 + T(signerBundleBytes)", ("T(bytes)",)),
        ("U", 48, 1536, "4 + 1536 + T(uriBytes)", ("T(string)",)),
        ("R", 48, 1536, "4 + 1536 + T(rotationBundleBytes)", ("T(bytes)",)),
        (
            "QU",
            49,
            1568,
            "4 + 1568 + T(signerBundleBytes) + T(uriBytes)",
            ("T(bytes)", "T(string)"),
        ),
        (
            "G",
            49,
            1568,
            "4 + 1568 + A_1(nGuardians) + T(signerBundleBytes)",
            ("A_1(address[])", "T(bytes)"),
        ),
        (
            "L",
            49,
            1568,
            "4 + 1568 + A_1(nLockClasses) + T(signerBundleBytes)",
            ("A_1(bytes32[])", "T(bytes)"),
        ),
        (
            "X",
            49,
            1568,
            "4 + 1568 + A_1(nRecordHashes) + T(signerBundleBytes)",
            ("A_1(bytes32[])", "T(bytes)"),
        ),
        (
            "D",
            49,
            1568,
            "4 + 1568 + T(directiveBytes) + T(signerBundleBytes)",
            ("T(bytes)", "T(bytes)"),
        ),
        (
            "B",
            53,
            1696,
            "4 + 1696 + A_3(nCollaborators) + A_3(nOverrides) + "
            "T(identityBytes) + T(displayNameBytes) + T(identityURIBytes) + "
            "T(reasonURIBytes)",
            (
                "A_3((address,bytes32,bytes32)[])",
                "A_3((uint32,uint8,uint32)[])",
                "T(bytes)",
                "T(string)",
                "T(string)",
                "T(string)",
            ),
        ),
        (
            "CI",
            51,
            1632,
            "4 + 1632 + T(identityBytes) + T(displayNameBytes) + "
            "T(identityURIBytes) + T(reasonURIBytes)",
            ("T(bytes)", "T(string)", "T(string)", "T(string)"),
        ),
        (
            "IR",
            51,
            1632,
            "4 + 1632 + T(identityBytes) + T(displayNameBytes) + "
            "T(identityURIBytes) + T(signerBundleBytes)",
            ("T(bytes)", "T(string)", "T(string)", "T(bytes)"),
        ),
        (
            "M",
            53,
            1696,
            "4 + 1696 + A_1(nProofWords)",
            ("A_1(bytes32[])",),
        ),
    )
    return [
        {
            "family": family,
            "first_tail_offset_bytes": first_offset,
            "head_words": head_words,
            "root_tail_encodings_in_declared_order": list(tails),
            "total_calldata_length_formula": formula,
        }
        for family, head_words, first_offset, formula, tails in records
    ]


def source_records(repo_root: Path) -> dict[str, Any]:
    records: dict[str, Any] = {}
    for key, relative_path, expected_sha256 in SOURCE_FILES:
        path = repo_root / relative_path
        try:
            content = path.read_bytes()
        except OSError as exc:
            raise AdapterFreezeError(f"cannot read required source {path}") from exc
        actual_sha256 = hashlib.sha256(content).hexdigest()
        require_equal(actual_sha256, expected_sha256, relative_path.as_posix())
        records[key] = {
            "path": relative_path.as_posix(),
            "sha256": f"sha256:{actual_sha256}",
        }
    return records


def revenue_packet_artifact() -> dict[str, Any]:
    entries, operations = revenue_entries()
    adapter_interface_id = xor_selectors(item["selector"] for item in entries)
    require_equal(
        adapter_interface_id,
        "0xb4165b1a",
        "revenue adapter interface ID",
    )
    snapshot_signature = (
        "RevenueRoyaltySnapshotRecorded(uint16,uint256,uint256,bytes32,"
        "bytes32,bytes32,bytes32)"
    )
    snapshot_topic = keccak_hex(snapshot_signature.encode("ascii"))
    require_equal(
        snapshot_topic,
        "0x9759cccc3dc5dfb9a69774dba31ee80379f23bc686a951a46bdfbdb95227ea63",
        "RevenueRoyaltySnapshotRecorded topic",
    )

    supports_selector = selector("supportsInterface(bytes4)")
    require_equal(supports_selector, "0x01ffc9a7", "ERC-165 selector")
    constants = hash_constant_records(REVENUE_HASH_CONSTANTS)
    constant_values = {item["name"]: item["value"] for item in constants}
    probes = (
        (
            "erc165_true",
            bytes4_argument_calldata(supports_selector, supports_selector),
            bytes32_word(1),
        ),
        (
            "versioned_interface_true",
            bytes4_argument_calldata(supports_selector, adapter_interface_id),
            bytes32_word(1),
        ),
        (
            "invalid_interface_false",
            bytes4_argument_calldata(supports_selector, "0xffffffff"),
            bytes32_word(0),
        ),
        (
            "marker",
            selector("revenueResolverValidationAdapterMarkerV1()"),
            constant_values["ADAPTER_MARKER_V1"],
        ),
        (
            "schema",
            selector("revenueResolverValidationAdapterSchemaV1()"),
            bytes32_word(1),
        ),
        (
            "dependency_binding",
            selector("dependencyBindingHash()"),
            "required_external:resolver_computed_dependency_binding",
        ),
    )

    return {
        "abi_schema": {
            "dependencies_v1": {
                "canonical_tuple_type": DEPENDENCIES_V1_TYPE,
                "words": 19,
            },
            "intent_header_v1": {
                "canonical_tuple_type": INTENT_HEADER_V1_TYPE,
                "self_excluded_claim_word": 18,
                "words": 18,
            },
            "result": {
                "abi_type": "bytes32[29]",
                "bytes": 29 * 32,
                "words": 29,
            },
        },
        "adapter_interface": {
            "entries": entries,
            "excluded_inherited_selector": supports_selector,
            "interface_id": adapter_interface_id,
            "xor_rule": "XOR all 12 declared entry selectors in packet order",
        },
        "construction_probes": [
            {
                "calldata_hex": calldata,
                "name": name,
                "required_return": required_return,
            }
            for name, calldata, required_return in probes
        ],
        "constants": {
            "hashes": constants,
            "limits": {
                "adapter_full_initcode_maximum_bytes": 47_152,
                "adapter_runtime_maximum_bytes": 22_576,
                "maximum_royalty_bps": 1_000,
                "resolver_full_initcode_maximum_bytes": 47_152,
                "resolver_runtime_maximum_bytes": 22_576,
            },
            "schema_uint16": {
                "name": "ADAPTER_SCHEMA_V1",
                "value": 1,
                "word": bytes32_word(1),
            },
        },
        "dependency_read_interfaces": read_interface_records(),
        "events": [
            {
                "anonymous": False,
                "data_bytes": 128,
                "data_words": 4,
                "indexed_argument_count": 3,
                "signature": snapshot_signature,
                "topic0": snapshot_topic,
            }
        ],
        "operations": operations,
    }


def artist_packet_artifact() -> dict[str, Any]:
    operations = artist_operations()
    entry_xor = xor_selectors(item["selector"] for item in operations)
    require_equal(entry_xor, "0x2efcc794", "artist validation entry XOR")

    probe_specs = (
        (
            "artistRegistryValidationAdapterMarker()",
            "0x24a325eb",
        ),
        (
            "artistRegistryValidationAdapterSchema()",
            "0x41995c51",
        ),
        ("dependencyBindingHash()", "0x371b62f3"),
    )
    probe_functions = function_records(probe_specs)
    full_interface_id = xor_selectors(
        [item["selector"] for item in operations]
        + [item["selector"] for item in probe_functions]
    )
    require_equal(full_interface_id, "0x7cdddcdd", "artist full interface ID")

    supports_selector = selector("supportsInterface(bytes4)")
    require_equal(supports_selector, "0x01ffc9a7", "ERC-165 selector")
    erc1271_selector = selector("isValidSignature(bytes32,bytes)")
    require_equal(
        erc1271_selector,
        "0x1626ba7e",
        "ERC1271 selector and magic",
    )

    constants = hash_constant_records(ARTIST_HASH_CONSTANTS)
    constant_values = {item["name"]: item["value"] for item in constants}
    probes = (
        (
            1,
            "erc165_true",
            bytes4_argument_calldata(supports_selector, supports_selector),
            bytes32_word(1),
        ),
        (
            2,
            "versioned_interface_true",
            bytes4_argument_calldata(supports_selector, full_interface_id),
            bytes32_word(1),
        ),
        (
            3,
            "invalid_interface_false",
            bytes4_argument_calldata(supports_selector, "0xffffffff"),
            bytes32_word(0),
        ),
        (
            4,
            "marker",
            selector("artistRegistryValidationAdapterMarker()"),
            constant_values["ARTIST_REGISTRY_VALIDATION_ADAPTER_MARKER_V1"],
        ),
        (
            5,
            "schema",
            selector("artistRegistryValidationAdapterSchema()"),
            constant_values["ARTIST_REGISTRY_VALIDATION_SCHEMA_V1"],
        ),
        (
            6,
            "dependency_binding",
            selector("dependencyBindingHash()"),
            "required_external:registry_computed_dependency_binding",
        ),
    )

    domain_specs = (
        (
            "EIP712_DOMAIN_TYPEHASH",
            "EIP712Domain(string name,string version,uint256 chainId,address "
            "verifyingContract)",
            "0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f",
        ),
        (
            "EIP712_NAME_HASH",
            "6529StreamArtistRegistry",
            "0xf598bd397eb1358772013bea6e869e4f30d34b382f011690ecba0449911c2c06",
        ),
        (
            "EIP712_VERSION_HASH",
            "1",
            "0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6",
        ),
    )
    typehash_records = hash_constant_records(ARTIST_TYPEHASH_SPECS)
    typehash_by_name = {item["name"]: item["value"] for item in typehash_records}
    typehash_assignments = []
    for write_name, path, constant_name, blocking_decision in (
        ARTIST_TYPEHASH_ASSIGNMENTS
    ):
        record: dict[str, Any] = {
            "path": path,
            "registry_write": write_name,
        }
        if constant_name is None:
            record.update(
                {
                    "blocking_decision": blocking_decision,
                    "status": "required_external",
                    "typehash_constant": None,
                    "typehash_value": None,
                }
            )
        else:
            record.update(
                {
                    "status": "supplied",
                    "typehash_constant": constant_name,
                    "typehash_value": typehash_by_name[constant_name],
                }
            )
        typehash_assignments.append(record)
    require_equal(len(typehash_assignments), 31, "artist typehash assignment rows")

    return {
        "abi_schema": {
            "field_bank": {
                "abi_type": "bytes32[24]",
                "words": 24,
            },
            "families": artist_family_records(),
            "length_primitives": {
                "A_w(n)": "32 + 32*w*n",
                "P(x)": "32*ceil(x/32)",
                "T(x)": "32 + P(x)",
                "offset_origin": (
                    "first byte after the four-byte function selector"
                ),
            },
            "result": {
                "abi_type": "bytes32[16]",
                "bytes": 16 * 32,
                "words": 16,
            },
            "signer_proof_bundle": {
                "abi_encoding": (
                    "abi.encode(ARTIST_REGISTRY_VALIDATION_SIGNER_BUNDLE_V1,"
                    "SignerProofV1[])"
                ),
                "element_signature_offset_bytes": 288,
                "inner_length_formula": (
                    "96 + 32*n + sum(i=0..n-1, 320 + P(signatureLength_i))"
                ),
                "participant_count_maximum": 33,
                "participant_count_minimum": 1,
                "proof_array_offset_bytes": 64,
                "signer_proof_tuple_type": (
                    "(uint32,address,bytes32,uint8,uint8,uint256,uint64,uint64,"
                    "bytes)"
                ),
            },
            "validation_context_v1": {
                "canonical_tuple_type": VALIDATION_CONTEXT_V1_TYPE,
                "words": 23,
            },
        },
        "adapter_interface": {
            "entry_selector_xor": entry_xor,
            "excluded_inherited_selector": supports_selector,
            "full_interface_id": full_interface_id,
            "included_probe_functions": probe_functions,
            "operations": operations,
            "xor_rule": (
                "XOR all 57 validation entries plus marker, schema, and "
                "dependency-binding getters"
            ),
        },
        "construction_probes": [
            {
                "calldata_hex": calldata,
                "name": name,
                "order": order,
                "required_return": required_return,
            }
            for order, name, calldata, required_return in probes
        ],
        "constants": {
            "erc1271_selector_and_magic": erc1271_selector,
            "hashes": constants,
            "limits": {
                "adapter_full_initcode_maximum_bytes": 47_152,
                "adapter_runtime_maximum_bytes": 22_576,
                "erc1271_gas_planning_floor": 90_000,
                "erc1271_gas_planning_genesis_value": 150_000,
                "ordinary_registry_entries": 37,
                "private_dependency_inventory_id": 39,
                "stored_signature_bytes_maximum": 4_096,
            },
        },
        "eip712": {
            "domain_hashes": hash_constant_records(domain_specs),
            "missing_typehashes": [
                {
                    "blocking_decision": "AR-33",
                    "registry_write": "refuseArtistBinding",
                    "status": "required_external",
                },
                {
                    "blocking_decision": "AR-14",
                    "registry_write": "revokeArtistDelegation",
                    "status": "required_external",
                },
            ],
            "supplied_typehash_assignments": typehash_assignments,
            "supplied_typehashes": typehash_records,
        },
    }


def finality_stop_overlay() -> dict[str, Any]:
    """Return the only reviewed implementation-stop overlay."""
    return {
        "overlay_id": FINALITY_OVERLAY_ID,
        "overlay_schema": (
            "6529stream.artist-validation-finality-dependency-supplement.v1"
        ),
        "artifact": DEFAULT_FINALITY_SUPPLEMENT.as_posix(),
        "precedence": "applied_after_base_operation_implementation_stop",
        "scope": FINALITY_SUPPLEMENT_SCOPE,
        "stop_id": FINALITY_STOP_ID,
        "resolutions": [
            {
                "row_id": 12,
                "write": "recordArtistSanction",
                "remove": [FINALITY_STOP_ID],
                "decision": "GO",
            },
            {
                "row_id": 13,
                "write": "confirmSanctionFinalized",
                "remove": [FINALITY_STOP_ID],
                "decision": "GO",
            },
        ],
        "preserved_rows": [
            {
                "row_id": 22,
                "write": "recordRecoveryApproval",
                "effective_stops": [FINALITY_STOP_ID],
                "decision": "NO_GO",
            }
        ],
        "unlisted_rows": "preserve_base_implementation_stop_exactly",
        "unlisted_stops": "preserve_base_implementation_stop_exactly",
        "implementation_authorized": False,
    }


def apply_implementation_stop_overlays(
    operations: list[list[Any]], overlays: list[dict[str, Any]]
) -> dict[str, list[str]]:
    """Apply reviewed overlays without permitting implicit stop removal."""
    if len(overlays) != 1:
        raise AdapterFreezeError("artist matrix overlay set is not the reviewed v1 set")

    rows = {row[0]: row for row in operations}
    if sorted(rows) != list(range(1, 58)):
        raise AdapterFreezeError("artist matrix rows must be exactly 1 through 57")
    effective = {row_id: list(row[17]) for row_id, row in rows.items()}
    base = copy.deepcopy(effective)

    overlay = overlays[0]
    resolutions = overlay.get("resolutions")
    if not isinstance(resolutions, list):
        raise AdapterFreezeError("finality overlay resolutions must be a list")
    resolution_ids = [
        item.get("row_id") if isinstance(item, dict) else None
        for item in resolutions
    ]
    if resolution_ids != [12, 13]:
        raise AdapterFreezeError("finality overlay may resolve only rows 12 and 13")
    if overlay != finality_stop_overlay():
        raise AdapterFreezeError("artist matrix overlay set is not the reviewed v1 set")
    for resolution in resolutions:
        row_id = resolution["row_id"]
        row = rows[row_id]
        if row[1] != resolution["write"]:
            raise AdapterFreezeError(f"finality overlay row {row_id} write mismatch")
        for stop in resolution["remove"]:
            if stop != FINALITY_STOP_ID or stop not in effective[row_id]:
                raise AdapterFreezeError(
                    f"finality overlay row {row_id} removal is not permitted"
                )
            effective[row_id].remove(stop)

    preserved = overlay["preserved_rows"]
    if len(preserved) != 1 or preserved[0]["row_id"] != 22:
        raise AdapterFreezeError("finality overlay must preserve row 22")
    row_22 = preserved[0]
    if rows[22][1] != row_22["write"]:
        raise AdapterFreezeError("finality overlay row 22 write mismatch")
    if effective[22] != row_22["effective_stops"]:
        raise AdapterFreezeError("finality overlay must preserve the row 22 stop")

    for row_id in rows:
        if row_id not in {12, 13} and effective[row_id] != base[row_id]:
            raise AdapterFreezeError(
                f"finality overlay changed unlisted row {row_id}"
            )
    return {str(row_id): effective[row_id] for row_id in sorted(effective)}


def erc1271_exact_return_shape_evidence() -> dict[str, Any]:
    """Return the accepted shape and still-required implementation evidence."""
    return {
        "semantic_decision": "accepted",
        "return_bytes": 32,
        "accepted_return": (
            "0x1626ba7e000000000000000000000000"
            "00000000000000000000000000000000"
        ),
        "implementation_evidence": (
            "required_positive_and_hostile_executable_vectors"
        ),
    }


def artist_matrix_typehashes() -> dict[str, list[str]]:
    """Derive the accepted matrix typehash catalog in its frozen order."""
    specifications = {
        name: (preimage, expected)
        for name, preimage, expected in (
            ARTIST_TYPEHASH_SPECS + ARTIST_MATRIX_ADDITIONAL_TYPEHASH_SPECS
        )
    }
    if set(specifications) != set(ARTIST_MATRIX_TYPEHASH_ORDER):
        raise AdapterFreezeError("artist matrix typehash catalog is incomplete")
    result: dict[str, list[str]] = {}
    for name in ARTIST_MATRIX_TYPEHASH_ORDER:
        preimage, expected = specifications[name]
        value = keccak_hex(preimage.encode("ascii"))
        require_equal(value, expected, name)
        result[name] = [preimage, value]
    return result


def artist_matrix_signature_rules() -> dict[str, str]:
    """Return the accepted matrix signature-rule vocabulary."""
    return {
        "NONE": (
            "No signer bundle. primarySigner, signerSetHash, nonce/time, "
            "ERC1271 cap/revision and signature-result words are zero."
        ),
        "DIRECT_OR_DEADLINE": (
            "Direct mode uses the registry allocator nonce and "
            "block.timestamp; no structHash or signedDigest. EOA/ERC1271 mode "
            "signs the named deadline typehash; deadline is signed and the "
            "record/event signedAt is registry-observed block.timestamp."
        ),
        "DIRECT_OR_SIGNED_AT": (
            "Direct mode uses the registry allocator nonce and "
            "block.timestamp; no structHash or signedDigest. EOA/ERC1271 mode "
            "signs the named long-lived typehash including signedAt; deadline "
            "is zero."
        ),
        "DIRECT_OR_NONCE_ONLY": (
            "Direct mode uses the registry allocator nonce and "
            "block.timestamp. EOA/ERC1271 mode signs the named nonce-bearing "
            "validity payload; record time is not part of that typehash."
        ),
        "TWO_SIDED_DEADLINE": (
            "Exactly old and new participants. Direct mode is allowed on at "
            "most one side. Signed sides use the row's distinct old/new "
            "deadline typehashes; record stagedAt is registry-observed "
            "block.timestamp."
        ),
        "GOVERNANCE_OR_PERMISSIONLESS": (
            "No signer bundle. Exact Governance V2 context is required only "
            "on the governance branch; otherwise all governance words are "
            "zero."
        ),
        "DIRECT_CALLER": (
            "No signer bundle. authenticatedCaller is proven registry-side; "
            "an allocator nonce and block.timestamp are used only when the "
            "source record/event requires them."
        ),
    }


def artist_operation_matrix_artifact() -> dict[str, Any]:
    """Build the generated semantic matrix plus its effective stop view."""
    operations = copy.deepcopy(list(ARTIST_OPERATION_MATRIX_ROWS))
    signature_rules = artist_matrix_signature_rules()
    typehashes = artist_matrix_typehashes()
    specs = {
        number: (write_name, family, expected)
        for number, write_name, _, family, expected in ARTIST_OPERATION_SPECS
    }
    if len(operations) != 57:
        raise AdapterFreezeError("artist semantic matrix must contain 57 rows")
    for expected_number, row in enumerate(operations, start=1):
        if len(row) != 18 or row[0] != expected_number:
            raise AdapterFreezeError(
                f"artist semantic matrix row {expected_number} shape mismatch"
            )
        write_name, family, validation_selector = specs[expected_number]
        require_equal(row[1], write_name, f"artist matrix row {expected_number} write")
        require_equal(row[2], family, f"artist matrix row {expected_number} family")
        require_equal(
            row[3],
            validation_selector,
            f"artist matrix row {expected_number} validation selector",
        )
        require_equal(
            selector(row[5]),
            row[4],
            f"artist matrix row {expected_number} write selector",
        )
        if row[7] not in signature_rules:
            raise AdapterFreezeError(
                f"artist matrix row {expected_number} signature rule is unknown"
            )
        row_typehashes = row[8].split("|")
        if row_typehashes != ["NONE"] and any(
            name not in typehashes for name in row_typehashes
        ):
            raise AdapterFreezeError(
                f"artist matrix row {expected_number} typehash is unknown"
            )
        field_count = len(row[10].split(";"))
        require_equal(
            int(row[9], 16),
            (1 << field_count) - 1,
            f"artist matrix row {expected_number} field mask",
        )
        if not isinstance(row[17], list):
            raise AdapterFreezeError(
                f"artist semantic matrix row {expected_number} stops are not a list"
            )

    domain_records = {
        item["name"]: {
            "preimage": item["preimage_ascii"],
            "value": item["value"],
        }
        for item in hash_constant_records(ARTIST_MATRIX_DOMAIN_SPECS)
    }
    extra_domains = (
        (
            "BINDING_REFUSAL_RECORD_DOMAIN",
            "6529STREAM_ARTIST_BINDING_REFUSAL_RECORD_V1",
            "0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed",
            (
                "domain,chainId,registry,core,collectionId,bindingGeneration,"
                "bindingHash,artistId,signer,authorityClass,reasonHash,nonce,signedAt"
            ),
        ),
        (
            "DELEGATION_REVOCATION_RECORD_DOMAIN",
            "6529STREAM_ARTIST_DELEGATION_REVOCATION_RECORD_V1",
            "0xa85c3026098222def761aae03562d9fff97010f075911f40d4a27886f49bcef3",
            (
                "domain,chainId,registry,artistId,delegate,delegationRecordHash,"
                "signer,authorityClass,reasonHash,nonce,signedAt"
            ),
        ),
    )
    for name, preimage, expected, fields in extra_domains:
        value = keccak_hex(preimage.encode("ascii"))
        require_equal(value, expected, name)
        domain_records[name] = {
            "preimage": preimage,
            "value": value,
            "fields": fields,
        }

    overlays = [finality_stop_overlay()]
    effective_stops = apply_implementation_stop_overlays(operations, overlays)
    return {
        "schema": "6529stream.artist-validation-operation-matrix.v1",
        "source_commit": PACKET_SOURCE_COMMIT,
        "status": "SEMANTIC_FREEZE_WITH_IMPLEMENTATION_STOPS",
        "authority": {
            "decision": (
                "docs/adr/0021-0022-validation-adapter-interface-freeze.md"
            ),
            "candidate_packet": (
                "docs/adr/0022-artist-registry-validation-adapter-interface-packet.md"
            ),
            "normative_source": "docs/stream-artist-authority.md",
        },
        "interpretation": {
            "field_layout": (
                "Each row's fields array assigns fields[0] upward in exact order. "
                "field_mask is the low-24-bit used-word mask. Every higher or "
                "otherwise unused word MUST be bytes32(0). Narrow values MUST be "
                "canonically zero-extended."
            ),
            "registry_write_selector": (
                "A semantic transition selector, "
                "bytes4(keccak256(write_selector_preimage)). It is not the "
                "implementation's Solidity ABI selector. The final public write "
                "ABI remains implementation-tuned under AA-INTERFACES and MUST "
                "be pinned separately in the release manifest."
            ),
            "current_state_digest": (
                "keccak256(abi.encode(CURRENT_STATE_DOMAIN, block.chainid, "
                "registry, registryWriteSelector, "
                "keccak256(abi.encode(fields[0],...,fields[23])), "
                "keccak256(abi.encode(row.current_state_facts in listed order))))"
            ),
            "replay_state_digest": (
                "keccak256(abi.encode(REPLAY_STATE_DOMAIN, block.chainid, "
                "registry, registryWriteSelector, signerSetHash, "
                "keccak256(abi.encode(row.replay_facts in listed order))))"
            ),
            "record_hash": (
                "A named source domain means the exact domain preimage and field "
                "order in docs/stream-artist-authority.md AA-DOMAINS at "
                "source_commit. NONE means the transition creates no new record "
                "hash. EXISTING:<name> means the event/state transition consumes "
                "the named existing record without rehashing it."
            ),
            "event_binding": (
                "Event names bind the exact declarations and field order in "
                "docs/stream-artist-authority.md AA-EVENTS at source_commit. "
                "Events emit only after transcript acceptance and durable state "
                "writes."
            ),
            "implementation_stop": (
                "Each operation row carries its base stop list. Versioned "
                "implementation_stop_overlays apply afterward in listed order. "
                "Only an exact listed stop removal is permitted; every unlisted "
                "row and stop remains unchanged. A row whose effective stop "
                "list is nonempty MUST NOT be implemented."
            ),
            "overlay_precedence": (
                "base operation implementation_stop, then the exact generated "
                "versioned overlay set, then effective_implementation_stops"
            ),
        },
        "domains": domain_records,
        "limits": {
            "max_participants": 33,
            "max_collaborators": 32,
            "max_capability_policy_overrides": 32,
            "max_guardians": 8,
            "max_lock_classes": 16,
            "max_supersession_hashes": 64,
            "max_history_proof_words": 64,
            "max_aggregate_raw_signature_bytes": 4096,
            "oversized_signature_transport_v1": False,
            "erc1271_return": (
                "exactly 32 bytes: 0x1626ba7e followed by 28 zero bytes"
            ),
        },
        "erc1271_ggp": {
            "parameter_name": "ARTIST_ERC1271_VERIFY_GAS",
            "parameter_id": (
                "0x04bd88d7a1b04a4fc7476b74a962c2fea893f8ad4e6711b1c13e828f151458b5"
            ),
            "host": "StreamArtistRegistry",
            "source_interface": "IStreamGasParameterHost",
            "read_signature": "gasParameterInfo(bytes32)",
            "read_selector": "0xec2ef90a",
            "return_abi": (
                "(uint256 value,uint256 floor,uint8 failureClass,uint64 revision)"
            ),
            "return_bytes": 128,
            "genesis_value": 150000,
            "immutable_floor": 90000,
            "failure_class": {
                "name": "FAIL_CLOSED_PRECHECK",
                "value": 2,
            },
            "genesis_revision": 1,
            "registry_rule": (
                "The registry authenticates the registered parameter id, exact "
                "immutable floor and failure class, nonzero monotonic revision, "
                "and live value at or above the floor before the adapter call. "
                "It commits value and revision in the request and independently "
                "performs the outer EIP-150 reserve check."
            ),
            "adapter_rule": (
                "The adapter has no GGP read or storage. It accepts only the "
                "request-authenticated value and revision and applies that value "
                "independently to each ERC-1271 STATICCALL."
            ),
        },
        "signature_rules": signature_rules,
        "typehashes": typehashes,
        "dynamic_profiles": {
            "F": "none",
            "Q": (
                "signerProofBundle; dynamic1Hash binds ordered raw signature "
                "lengths and hashes"
            ),
            "U": (
                "one bounded UTF-8 URI; dynamic0Hash binds byte length and "
                "keccak256(bytes)"
            ),
            "QU": (
                "signerProofBundle then URI; dynamic0 binds URI, dynamic1 binds "
                "signatures"
            ),
            "B": (
                "collaborators<=32, capabilityOverrides<=32, identityBytes<=8192, "
                "displayName<=256, identityURI<=2048, reasonURI<=2048"
            ),
            "CI": (
                "identityBytes<=8192, displayName<=256, identityURI<=2048, "
                "reasonURI<=2048"
            ),
            "IR": (
                "identityBytes<=8192, displayName<=256, identityURI<=2048, "
                "signerProofBundle"
            ),
            "G": "strictly sorted unique guardians<=8 then signerProofBundle",
            "R": "exact two-participant signerProofBundle",
            "L": "strictly sorted unique lockClasses<=16 then signerProofBundle",
            "X": (
                "strictly sorted unique supersededRecordHashes<=64 then "
                "new-authority signerProofBundle"
            ),
            "D": "directive bytes<=8192 then signerProofBundle",
            "M": "static import leaf then sorted-pair Merkle proof<=64 words",
        },
        "dependency_profiles": {
            "LOCAL": "Registry-local state only; adapter makes no external call.",
            "CORE": (
                "Registry performs exact bound-Core reads and commits/rechecks "
                "observations; adapter does not call Core."
            ),
            "GOVERNANCE": (
                "Registry performs exact Governance V2 currentAction read/recheck; "
                "adapter does not call Governance."
            ),
            "SIGNER": (
                "Adapter may call only ecrecover or exact request-bound ERC1271 "
                "signers; registry authenticates signer identities and GGP "
                "value/revision."
            ),
            "FINALITY": (
                "Registry performs exact Core burn-cutoff and finality-registry "
                "reads and rechecks; adapter does not call either."
            ),
            "IMPORT": (
                "Registry performs exact Core pointer and predecessor-registry "
                "reads and rechecks; adapter does not call either."
            ),
        },
        "operation_columns": [
            "id",
            "write",
            "family",
            "validation_selector",
            "write_selector",
            "write_selector_preimage",
            "authority",
            "signature_rule",
            "typehash",
            "field_mask",
            "fields",
            "current_state_facts",
            "replay_facts",
            "primary_record",
            "secondary_record",
            "dependencies",
            "events",
            "implementation_stop",
        ],
        "implementation_stop_overlays": overlays,
        "effective_implementation_stops": effective_stops,
        "operations": operations,
    }


def operation_matrix_json_bytes(value: dict[str, Any]) -> bytes:
    """Render deterministic JSON while retaining compact semantic rows."""
    before_typehashes: dict[str, Any] = {}
    after_typehashes: dict[str, Any] = {}
    typehashes: dict[str, Any] | None = None
    operations: list[list[Any]] | None = None
    seen_typehashes = False
    for key, item in value.items():
        if key == "typehashes":
            typehashes = item
            seen_typehashes = True
        elif key == "operations":
            operations = item
        elif seen_typehashes:
            after_typehashes[key] = item
        else:
            before_typehashes[key] = item
    if typehashes is None or operations is None:
        raise AdapterFreezeError("operation matrix render inputs are incomplete")

    def object_inner(mapping: dict[str, Any]) -> str:
        if not mapping:
            return ""
        rendered = json.dumps(
            mapping,
            ensure_ascii=False,
            indent=2,
            sort_keys=False,
            allow_nan=False,
        )
        if not rendered.startswith("{\n") or not rendered.endswith("\n}"):
            raise AdapterFreezeError("operation matrix object rendering failed")
        return rendered[2:-2]

    compact_typehashes = ",\n".join(
        "    "
        + json.dumps(name, ensure_ascii=False)
        + ": "
        + json.dumps(
            record,
            ensure_ascii=False,
            separators=(", ", ": "),
            allow_nan=False,
        )
        for name, record in typehashes.items()
    )
    compact_rows = ",\n".join(
        "    "
        + json.dumps(
            row,
            ensure_ascii=False,
            separators=(", ", ": "),
            allow_nan=False,
        )
        for row in operations
    )
    sections = []
    before = object_inner(before_typehashes)
    if before:
        sections.append(before)
    sections.append(
        '  "typehashes": {\n'
        + compact_typehashes
        + "\n  }"
    )
    after = object_inner(after_typehashes)
    if after:
        sections.append(after)
    sections.append(
        '  "operations": [\n'
        + compact_rows
        + "\n  ]"
    )
    rendered = "{\n" + ",\n".join(sections) + "\n}\n"
    return rendered.encode("utf-8")


def required_external_artifacts() -> list[dict[str, Any]]:
    return [
        {
            "blocking_decisions": [f"R{number}" for number in range(1, 11)],
            "id": "revenue-semantic-review-supplement",
            "requirement": (
                "Accepted security and protocol semantics for every unresolved "
                "revenue decision; this mechanical artifact makes no choice."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": ["R12"],
            "id": "revenue-concrete-golden-transcripts",
            "requirement": (
                "Nontrivial per-entry and per-branch calldata, digest, state, "
                "counter, snapshot-proof, result, and event vectors independently "
                "recomputed from accepted semantics."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": ["R11", "AR-24", "AR-25", "AR-26"],
            "id": "measured-gas-and-eip150-evidence",
            "requirement": (
                "Frozen compiler/fork environment and measured cold/warm, "
                "failure, reverse-composed EIP-150, and 1/2/33-participant gas "
                "evidence. No gas value is inferred here."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": ["R13", "AR-27", "AR-28"],
            "id": "final-isolated-build-and-size-evidence",
            "requirement": (
                "Final compiler inputs, runtime/initcode bytes and hashes, exact "
                "constructor encoding, margins, and boundary tests for both "
                "resolver/adapter pairs. Packet ceilings are not measurements."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": ["AR-07", "AR-08", "AR-09", "AR-15"],
            "id": "artist-registry-write-and-state-schema",
            "requirement": (
                "Exact registry-write ABIs/selectors, 57 field masks, "
                "current/replay-state preimages, and timestamp rules."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": [
                "AR-16",
                "AR-17",
                "AR-18",
                "AR-19",
                "AR-20",
                "AR-21",
                "AR-22",
                "AR-23",
                "AR-29",
                "AR-30",
            ],
            "id": "artist-dynamic-result-and-signer-goldens",
            "requirement": (
                "Accepted per-selector bounds/empty rules, exact dynamic hashes, "
                "signer-set codec vectors, 1/2/33-participant results, record "
                "semantics, ERC-1271 return shape, and display-name treatment."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": ["AR-14", "AR-31", "AR-33"],
            "id": "artist-57-row-eip712-record-event-matrix",
            "requirement": (
                "Exact typehash or NONE, typed fields/order, direct/governance "
                "branches, record preimages, signature evidence, and event "
                "topics/data for all 57 writes, including both missing typehashes."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
        {
            "blocking_decisions": ["AR-32"],
            "id": "artist-steward-and-finality-proof-schema",
            "requirement": (
                "Exact Core/finality dependencies, selectors, return shapes, "
                "predicates, proof preimages, state mappings, and events."
            ),
            "satisfied_by_this_artifact": False,
            "status": "required_external",
        },
    ]


def build_artifact(repo_root: Path) -> dict[str, Any]:
    """Build the exact deterministic mechanical artifact."""
    source = source_records(repo_root)
    artifact = {
        "canonicalization": {
            "array_order": "normative packet order",
            "encoding": "UTF-8",
            "hex": "lowercase 0x-prefixed fixed-width",
            "json": (
                "sorted object keys, two-space indentation, no floats or NaN, "
                "one trailing LF"
            ),
        },
        "coverage": {
            "included": [
                "packet and normative typehash-source SHA-256",
                "specified ASCII Keccak constants",
                "specified function selectors and interface XORs",
                "fixed tuple, result, and calldata length arithmetic",
                "specified construction probes",
                "supplied EIP-712 typehashes",
                "specified revenue snapshot event topic and data size",
                "specified bytecode ceilings as limits, not measurements",
            ],
            "not_included": [
                "protocol or security semantic acceptance",
                "missing field masks or registry-write ABIs",
                "missing typehash or event decisions",
                "concrete semantic transcript vectors",
                "gas measurements or gas acceptance thresholds",
                "compiled runtime/initcode measurements",
                "implementation, deployment, audit, or production readiness",
            ],
        },
        "evidence_class": "mechanical_candidate_vectors",
        "artist_registry_packet": artist_packet_artifact(),
        "required_external_artifacts": required_external_artifacts(),
        "revenue_resolver_packet": revenue_packet_artifact(),
        "schema_version": SCHEMA_VERSION,
        "source": {
            "files": source,
            "packet_source_commit": PACKET_SOURCE_COMMIT,
        },
        "status": {
            "acceptance_freeze_satisfied": False,
            "implementation_authorized": False,
            "mechanical_scope_generated": True,
            "packet_maturity": "proposed_pre_audit",
            "production_readiness_evidence": False,
        },
    }
    return artifact


def write_artifact(path: Path, artifact: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_json_bytes(artifact))


def write_operation_matrix(path: Path, artifact: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(operation_matrix_json_bytes(artifact))


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--matrix-output",
        type=Path,
        default=DEFAULT_MATRIX_OUTPUT,
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the output is absent or differs; do not write",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    output = args.output
    if not output.is_absolute():
        output = repo_root / output
    matrix_output = args.matrix_output
    if not matrix_output.is_absolute():
        matrix_output = repo_root / matrix_output
    try:
        artifact = build_artifact(repo_root)
        rendered = canonical_json_bytes(artifact)
        matrix_artifact = artist_operation_matrix_artifact()
        rendered_matrix = operation_matrix_json_bytes(matrix_artifact)
        if args.check:
            try:
                current = output.read_bytes()
            except OSError as exc:
                raise AdapterFreezeError(
                    f"mechanical vector artifact is missing: {output}"
                ) from exc
            if current != rendered:
                raise AdapterFreezeError(
                    f"mechanical vector artifact is stale: {output}"
                )
            try:
                current_matrix = matrix_output.read_bytes()
            except OSError as exc:
                raise AdapterFreezeError(
                    f"artist operation matrix is missing: {matrix_output}"
                ) from exc
            if current_matrix != rendered_matrix:
                raise AdapterFreezeError(
                    f"artist operation matrix is stale: {matrix_output}"
                )
            print(
                "issue #670 mechanical vectors and artist operation matrix "
                f"are current: {output}; {matrix_output}"
            )
            return 0
        write_artifact(output, artifact)
        write_operation_matrix(matrix_output, matrix_artifact)
        print(
            "wrote issue #670 mechanical vectors and artist operation matrix: "
            f"{output}; {matrix_output}"
        )
        return 0
    except AdapterFreezeError as exc:
        print(f"issue #670 adapter artifact generation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
