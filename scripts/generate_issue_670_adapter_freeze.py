#!/usr/bin/env python3
"""Generate deterministic mechanical vectors for the issue #670 adapter packets.

This artifact intentionally covers only facts already specified in the two
Proposed interface packets.  It is not an acceptance freeze, implementation
authorization, gas measurement, size proof, or security review.
"""

from __future__ import annotations

import argparse
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
    constant_values = {
        item["name"]: item["value"]
        for item in hash_constant_records(REVENUE_HASH_CONSTANTS)
    }
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
            "hashes": hash_constant_records(REVENUE_HASH_CONSTANTS),
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


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
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
    try:
        artifact = build_artifact(repo_root)
        rendered = canonical_json_bytes(artifact)
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
            print(f"issue #670 mechanical vectors are current: {output}")
            return 0
        write_artifact(output, artifact)
        print(f"wrote issue #670 mechanical vectors: {output}")
        return 0
    except AdapterFreezeError as exc:
        print(f"issue #670 mechanical vector generation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
