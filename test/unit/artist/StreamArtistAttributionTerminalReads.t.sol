// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamArtistAttributionLifecycle as Attribution
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistAttributionClaimTypes as AC
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    IStreamArtistRecordPublicationOwner as Publication
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

interface AttributionReadVm {
    function getCode(string calldata artifact) external view returns (bytes memory);
}

/// @notice Original ABI byte oracles over the actual linked owner, with explicitly seeded read state.
/// @dev These tests neither authorize records nor prove seven-owner integration. Normal CREATE and
/// both deployment limits are retained. The known remaining Attribution overage blocks execution
/// until a separately authorized capacity repair fits; no etch or raised size allowance bypasses it.
contract StreamArtistAttributionTerminalReadsTest is CharacterizationTestBase {
    Attribution private owner;
    bytes32 private constant RECORD = keccak256("read-shape-record");
    uint256 private constant COLLECTION = 71;

    function setUp() public {
        bytes memory init = bytes.concat(
            AttributionReadVm(address(vm))
                .getCode(
                    "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle"
                ),
            abi.encode(
                address(0x101), address(0x102), address(0x103), address(0x104), address(0x105)
            )
        );
        require(init.length <= 49_152, "actual initcode limit");
        address created;
        assembly ("memory-safe") { created := create(0, add(init, 32), mload(init)) }
        require(created != address(0), "actual Attribution CREATE");
        require(created.code.length <= 24_576, "actual runtime limit");
        owner = Attribution(created);
    }

    function testAllFifteenOriginalEmptyReadEncodings() public view {
        Attest.Association memory association;
        PW.Admission memory admission;
        PW.State memory platform;
        PW.Claim memory claim;
        PW.Contest memory contest;
        AC.Claim memory attributionClaim;
        T.AttestationRecord memory attestation;
        Publication.Record memory publication;
        AD.Head memory dispute;
        AD.Record memory disputeRecord;
        AD.Resolution memory resolution;
        RP.Record memory repudiation;
        RP.Terminal memory terminal;
        _same(
            abi.encodeWithSelector(owner.attestationAssociation.selector, RECORD),
            abi.encode(association)
        );
        _same(
            abi.encodeWithSelector(owner.platformWorksAdmission.selector, COLLECTION),
            abi.encode(admission)
        );
        _same(
            abi.encodeWithSelector(owner.platformWorksState.selector, COLLECTION),
            abi.encode(platform)
        );
        _same(
            abi.encodeWithSelector(owner.platformWorksClaimRecord.selector, RECORD),
            abi.encode(claim)
        );
        _same(
            abi.encodeWithSelector(owner.platformWorksContestRecord.selector, RECORD),
            abi.encode(contest)
        );
        _same(
            abi.encodeWithSelector(owner.attributionClaimRecord.selector, RECORD),
            abi.encode(attributionClaim)
        );
        _same(
            abi.encodeWithSelector(owner.attestation.selector, COLLECTION, uint8(7), RECORD),
            abi.encode(attestation)
        );
        _same(
            abi.encodeWithSelector(owner.attestationRecord.selector, RECORD),
            abi.encode(attestation)
        );
        _same(abi.encodeWithSelector(owner.statementBytes.selector, RECORD), abi.encode(bytes("")));
        _same(
            abi.encodeWithSelector(owner.publicationAttestation.selector, RECORD),
            abi.encode(publication)
        );
        _same(
            abi.encodeWithSelector(owner.attributionDispute.selector, COLLECTION, uint64(5)),
            abi.encode(dispute)
        );
        _same(
            abi.encodeWithSelector(owner.attributionDisputeRecord.selector, RECORD),
            abi.encode(disputeRecord)
        );
        _same(
            abi.encodeWithSelector(owner.attributionDisputeResolution.selector, RECORD),
            abi.encode(resolution)
        );
        _same(
            abi.encodeWithSelector(owner.attributionRepudiationRecord.selector, RECORD),
            abi.encode(repudiation)
        );
        _same(
            abi.encodeWithSelector(owner.attributionRepudiationTerminal.selector, RECORD),
            abi.encode(terminal)
        );
    }

    function testPackedOriginalAttestationAndTypedCallerAgree() public {
        T.AttestationRecord memory expected = T.AttestationRecord(
            RECORD,
            keccak256("subject"),
            keccak256("schema"),
            keccak256("statement"),
            type(uint64).max - 1,
            type(uint64).max - 2,
            address(0xABCD)
        );
        // Original ordinary mapping roots are pinned independently by the compiler layout check.
        _attestation(keccak256(abi.encode(RECORD, uint256(6))), expected);
        bytes32 key = keccak256(abi.encode(COLLECTION, uint8(7), RECORD));
        _attestation(keccak256(abi.encode(key, uint256(5))), expected);
        bytes32 stateBefore = keccak256(abi.encode(owner.ownerStateSnapshotV2()));
        _same(
            abi.encodeWithSelector(owner.attestationRecord.selector, RECORD), abi.encode(expected)
        );
        _same(
            abi.encodeWithSelector(owner.attestation.selector, COLLECTION, uint8(7), RECORD),
            abi.encode(expected)
        );
        T.AttestationRecord memory typed = owner.attestationRecord(RECORD);
        require(
            keccak256(abi.encode(typed)) == keccak256(abi.encode(expected)), "typed memory caller"
        );
        require(
            stateBefore == keccak256(abi.encode(owner.ownerStateSnapshotV2())), "read mutated owner"
        );
    }

    function testOriginalAssociationNestedTupleAndNeighborIsolation() public {
        Attest.Association memory expected = Attest.Association(
            keccak256("artist"),
            keccak256("binding"),
            type(uint64).max,
            keccak256("delegation"),
            Attest.Fact(
                address(0xABCD), keccak256("code"), keccak256("subject"), keccak256("state")
            )
        );
        bytes32 root = keccak256(abi.encode(RECORD, uint256(20)));
        _words(root, abi.encode(expected));
        _same(
            abi.encodeWithSelector(owner.attestationAssociation.selector, RECORD),
            abi.encode(expected)
        );
        Attest.Association memory empty;
        _same(
            abi.encodeWithSelector(owner.attestationAssociation.selector, bytes32(uint256(11))),
            abi.encode(empty)
        );
    }

    function testOriginalStatementShortAndLongStorageBoundaries() public {
        uint256[7] memory lengths = [uint256(0), 1, 31, 32, 33, 64, 65];
        for (uint256 n; n < lengths.length; ++n) {
            bytes memory statement = new bytes(lengths[n]);
            for (uint256 j; j < statement.length; ++j) {
                statement[j] = bytes1(uint8(j * 7 + n));
            }
            bytes32 key = keccak256(abi.encode("statement", n));
            _statement(key, statement);
            _same(abi.encodeWithSelector(owner.statementBytes.selector, key), abi.encode(statement));
            bytes memory typed = owner.statementBytes(key);
            require(keccak256(typed) == keccak256(statement), "typed dynamic bytes");
        }
    }

    function testOriginalNamespacedDisputeAndTerminalPackedReads() public {
        AD.Head memory expected =
            AD.Head(RECORD, keccak256("counter"), keccak256("resolution"), 3, 2, true, true);
        bytes32 key = keccak256(abi.encode(COLLECTION, uint64(5)));
        bytes32 head = keccak256(
            abi.encode(key, keccak256("6529STREAM_ARTIST_ATTRIBUTION_DISPUTES_STORAGE_V1"))
        );
        _put(head, 0, expected.disputeRecordHash);
        _put(head, 1, expected.counterStatementRecordHash);
        _put(head, 2, expected.resolutionActionId);
        _put(
            head,
            3,
            bytes32(uint256(3) | (uint256(2) << 8) | (uint256(1) << 16) | (uint256(1) << 24))
        );
        _same(
            abi.encodeWithSelector(owner.attributionDispute.selector, COLLECTION, uint64(5)),
            abi.encode(expected)
        );
        RP.Terminal memory terminal =
            RP.Terminal(3, address(0xABCD), keccak256("reason"), type(uint64).max);
        bytes32 root = keccak256(
            abi.encode(
                RECORD, uint256(keccak256("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATIONS_V1")) + 1
            )
        );
        _put(root, 0, bytes32(uint256(3) | (uint256(uint160(terminal.actor)) << 8)));
        _put(root, 1, terminal.reasonHash);
        _put(root, 2, bytes32(uint256(terminal.recordedAt)));
        _same(
            abi.encodeWithSelector(owner.attributionRepudiationTerminal.selector, RECORD),
            abi.encode(terminal)
        );
    }

    function testMalformedOriginalArgumentsRefuseWithoutOwnerMutation() public view {
        bytes32 before_ = keccak256(abi.encode(owner.ownerStateSnapshotV2()));
        _refuses(abi.encodePacked(owner.statementBytes.selector));
        _refuses(abi.encodePacked(owner.publicationAttestation.selector, bytes31(0)));
        _refuses(
            abi.encodeWithSelector(owner.attestation.selector, COLLECTION, uint256(256), RECORD)
        );
        _refuses(
            abi.encodeWithSelector(owner.attributionDispute.selector, COLLECTION, uint256(1) << 64)
        );
        require(
            before_ == keccak256(abi.encode(owner.ownerStateSnapshotV2())), "refusal mutated owner"
        );
    }

    function _same(bytes memory call_, bytes memory expected) private view {
        (bool ok, bytes memory result) = address(owner).staticcall(call_);
        require(
            ok && result.length == expected.length && keccak256(result) == keccak256(expected),
            "original ABI bytes"
        );
    }

    function _refuses(bytes memory call_) private view {
        (bool ok,) = address(owner).staticcall(call_);
        require(!ok, "malformed original call accepted");
    }

    function _put(bytes32 root, uint256 offset, bytes32 value) private {
        vm.store(address(owner), bytes32(uint256(root) + offset), value);
    }

    function _words(bytes32 root, bytes memory encoded) private {
        for (uint256 i; i < encoded.length / 32; ++i) {
            bytes32 word;
            assembly ("memory-safe") { word := mload(add(add(encoded, 32), mul(i, 32))) }
            _put(root, i, word);
        }
    }

    function _attestation(bytes32 root, T.AttestationRecord memory a) private {
        _put(root, 0, a.recordHash);
        _put(root, 1, a.subjectStateHash);
        _put(root, 2, a.schemaId);
        _put(root, 3, a.statementHash);
        _put(root, 4, bytes32(uint256(a.generation) | (uint256(a.signedAt) << 64)));
        _put(root, 5, bytes32(uint256(uint160(a.signer))));
    }

    function _statement(bytes32 key, bytes memory value) private {
        bytes32 root = keccak256(abi.encode(key, uint256(7)));
        if (value.length < 32) {
            bytes32 word;
            for (uint256 i; i < value.length; ++i) {
                word |= bytes32(uint256(uint8(value[i])) << (248 - i * 8));
            }
            vm.store(address(owner), root, word | bytes32(value.length * 2));
        } else {
            vm.store(address(owner), root, bytes32(value.length * 2 + 1));
            bytes32 dataRoot = keccak256(abi.encode(root));
            for (uint256 i; i < value.length; i += 32) {
                bytes32 word;
                for (uint256 j; j < 32 && i + j < value.length; ++j) {
                    word |= bytes32(uint256(uint8(value[i + j])) << (248 - j * 8));
                }
                _put(dataRoot, i / 32, word);
            }
        }
    }
}
