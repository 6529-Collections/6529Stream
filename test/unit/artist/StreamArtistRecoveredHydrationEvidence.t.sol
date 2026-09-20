// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationEvidence as E
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistArchiveV2
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    IStreamArtistArchiveV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface RecoveredHydrationEvidenceVm {
    function expectPartialRevert(bytes4 selector) external;
}

contract RecoveredHydrationEvidenceHost {
    address public constant REGISTRY = address(0x6529);
    StreamArtistArchiveV2 public immutable archive =
        new StreamArtistArchiveV2(REGISTRY, address(this));
    uint256 public committed;

    error LateFailure();

    function append(bytes32 commitment, bytes memory payload, bool fail)
        external
        returns (E.Descriptor memory descriptor)
    {
        ++committed;
        descriptor = E.append(address(archive), REGISTRY, commitment, payload);
        if (fail) revert LateFailure();
    }
}

/// @notice Actual Archive transport regressions; these do not establish seven-owner hydration.
contract StreamArtistRecoveredHydrationEvidenceTest {
    RecoveredHydrationEvidenceVm private constant vm =
        RecoveredHydrationEvidenceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveredHydrationEvidenceHost private host;
    bytes32 private constant IMPORT = keccak256("actual operation60 commitment");

    function setUp() public {
        host = new RecoveredHydrationEvidenceHost();
    }

    function testExactBoundaryAndPartialFinalPage() public pure {
        for (uint256 size = 20_479; size <= 20_481; ++size) {
            bytes memory payload = _payload(size);
            E.Descriptor memory d = E.describe(payload);
            assertEq(d.payloadHash, keccak256(payload));
            assertEq(d.payloadLength, size);
            assertEq(d.pageHashes.length, size <= 20_480 ? 1 : 2);
        }
    }

    function testRoundTripRetainsExactOrderedBytes() public {
        bytes memory payload = _payload(40_977);
        E.Descriptor memory d = host.append(IMPORT, payload, false);
        assertEq(_read(d), payload);
        assertEq(d.pageHashes.length, 3);
        assertEq(host.committed(), 1);
    }

    function testRejectsEmptyPayloadAndNonCanonicalDescriptor() public {
        vm.expectPartialRevert(E.InvalidRecoveredHydrationEvidence.selector);
        host.append(IMPORT, bytes(""), false);
        E.Descriptor memory d = E.describe(_payload(32));
        d.schema = keccak256("foreign schema");
        vm.expectPartialRevert(E.InvalidRecoveredHydrationEvidence.selector);
        this.read(d);
    }

    function testMissingPageIsNotAnEmptySuffix() public {
        E.Descriptor memory d = E.describe(_payload(20_481));
        vm.expectPartialRevert(IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector);
        this.read(d);
    }

    function testReorderedPageHashesCannotReadOtherOccurrences() public {
        E.Descriptor memory d = host.append(IMPORT, _payload(40_977), false);
        (d.pageHashes[0], d.pageHashes[2]) = (d.pageHashes[2], d.pageHashes[0]);
        vm.expectPartialRevert(IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector);
        this.read(d);
    }

    function testImportCommitmentAndCoordinatorAreBound() public {
        E.Descriptor memory d = host.append(IMPORT, _payload(37), false);
        address archive = address(host.archive());
        address registry = host.REGISTRY();
        vm.expectPartialRevert(IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector);
        E.read(archive, registry, address(host), keccak256("other import"), d);
        vm.expectPartialRevert(E.InvalidRecoveredHydrationEvidence.selector);
        E.read(archive, registry, address(this), IMPORT, d);
    }

    function testChangedPayloadHashOrLengthCannotReusePages() public {
        E.Descriptor memory d = host.append(IMPORT, _payload(37), false);
        bytes32 original = d.payloadHash;
        d.payloadHash = keccak256("substituted complete payload");
        vm.expectPartialRevert(IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector);
        this.read(d);
        d.payloadHash = original;
        --d.payloadLength;
        vm.expectPartialRevert(IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector);
        this.read(d);
    }

    function testDuplicateAppendCannotMasqueradeAsFreshAtomicEvidence() public {
        bytes memory payload = _payload(37);
        E.Descriptor memory d = host.append(IMPORT, payload, false);
        vm.expectPartialRevert(E.InvalidRecoveredHydrationEvidence.selector);
        host.append(IMPORT, payload, false);
        assertEq(host.committed(), 1);
        assertEq(_read(d), payload);
    }

    function testLateFailureRollsBackEveryPageAndAllowsExactRetry() public {
        bytes memory payload = _payload(20_481);
        E.Descriptor memory d = E.describe(payload);
        vm.expectPartialRevert(RecoveredHydrationEvidenceHost.LateFailure.selector);
        host.append(IMPORT, payload, true);
        assertEq(host.committed(), 0);
        StreamArtistArchiveV2 archive = host.archive();
        for (uint256 i; i < d.pageHashes.length; ++i) {
            bytes32 id = E.pageId(host.REGISTRY(), address(host), IMPORT, d, i);
            vm.expectPartialRevert(IStreamArtistArchiveV2.ArtistArchiveEvidenceUnavailable.selector);
            archive.artistEvidenceMetadataV2(id, 1);
        }
        host.append(IMPORT, payload, false);
        assertEq(host.committed(), 1);
        assertEq(_read(d), payload);
    }

    function testMaximumDescriptorHeaderFitsOriginalCarrier() public view {
        E.Descriptor memory d;
        d.schema = E.SCHEMA;
        d.payloadHash = keccak256("maximum bounded envelope");
        d.payloadLength = E.MAX_PAGES * E.PAGE_BYTES;
        d.pageHashes = new bytes32[](E.MAX_PAGES);
        T.Snapshot[7] memory before_;
        T.Snapshot[7] memory after_;
        bytes memory profileBytes = abi.encode(keccak256("recovered profile"), d);
        bytes memory header = abi.encode(
            uint16(1), bytes32(0), uint16(60), address(this), IMPORT, before_, after_, profileBytes
        );
        assertEq(profileBytes.length, 4_320);
        assertEq(header.length, 6_336);
        assertLe(header.length, host.archive().artistArchiveMaxEvidenceBytesV2());
        assertLe(E.PAGE_BYTES, host.archive().artistArchiveMaxEvidenceBytesV2());
    }

    function read(E.Descriptor memory d) external view returns (bytes memory) {
        return _read(d);
    }

    function _read(E.Descriptor memory d) private view returns (bytes memory) {
        return E.read(address(host.archive()), host.REGISTRY(), address(host), IMPORT, d);
    }

    function _payload(uint256 size) private pure returns (bytes memory payload) {
        payload = new bytes(size);
        for (uint256 i; i < size; ++i) {
            payload[i] = bytes1(uint8(i % 251));
        }
    }

    function assertEq(uint256 actual, uint256 expected) private pure {
        require(actual == expected, "integer mismatch");
    }

    function assertEq(bytes32 actual, bytes32 expected) private pure {
        require(actual == expected, "hash mismatch");
    }

    function assertEq(bytes memory actual, bytes memory expected) private pure {
        require(keccak256(actual) == keccak256(expected), "payload mismatch");
    }

    function assertLe(uint256 actual, uint256 expected) private pure {
        require(actual <= expected, "bound exceeded");
    }
}
