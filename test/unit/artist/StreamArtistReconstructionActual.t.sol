// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyRecoveryActual.t.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import { SSTORE2 } from "../../../smart-contracts/libraries/SSTORE2.sol";

/// @notice Exact retained-byte reconstruction through actual Artist/Safe/Archive owners.
/// @dev Core/governance facts retain the original aggregate unit fixture boundary.
contract StreamArtistReconstructionActualTest is StreamArtistDormancyRecoveryActualTest {
    error LateCatalog();

    function _catalog() private view returns (IStreamArtistReconstruction) {
        return IStreamArtistReconstruction(address(ingress));
    }

    function _unavailable(bytes32 hash) private {
        IStreamArtistReconstruction c = _catalog();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistReconstruction.ArtistPayloadUnavailable.selector, hash
            )
        );
        c.recordPreimageBytes(hash);
    }

    function _exact(bytes32 hash, bytes memory expected) private view {
        bytes memory actual = _catalog().recordPreimageBytes(hash);
        require(
            actual.length == expected.length && keccak256(actual) == keccak256(expected)
                && keccak256(actual) == hash,
            "exact independent permanent preimage"
        );
        require(
            keccak256(IStreamArtistReconstruction(suite.owners[2]).recordPreimageBytes(hash))
                == hash,
            "actual Identity carrier and fixed Archive agree"
        );
        bool found;
        for (uint256 j; j < _catalog().storedPayloadCount(); ++j) {
            (address pointer, bytes32 kind, bytes32 h) = _catalog().storedPayloadAt(j);
            require(keccak256(SSTORE2.read(pointer)) == h, "every listed carrier self-verifies");
            if (kind == keccak256("ARTIST_RECORD_PREIMAGE") && h == hash) {
                require(!found, "one catalog row per type/content");
                found = true;
            }
        }
        require(found, "permanent preimage discoverable from state");
    }

    function testReconstructionRotationOnlyAfterExecutionUsesOriginalStagePreimage() public {
        _newRotationSafe(9711);
        bytes32 hash = _stageRotation(0);
        R.RotationRecord memory r = ingress.rotationRecord(hash);
        bytes memory expected = abi.encode(
            bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
            block.chainid,
            address(ingress),
            artistId,
            r.terms.oldAddress,
            r.terms.newAddress,
            r.terms.reasonHash,
            r.oldNonce,
            r.transition.stagedAt,
            r.transition.contestEndsAt
        );
        _unavailable(hash);
        _executeTimedRotation(hash);
        _exact(hash, expected);
    }

    function testReconstructionEstateOnlyAfterExecutionKeepsOriginalRequestPreimage() public {
        Estate.Execution memory p = _estatePendingFixture(256);
        (Estate.RequestRecord memory r,,) =
            ingress.estateActivationRecord(p.expectedActivationRecordHash);
        bytes memory expected = abi.encode(
            keccak256("6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1"),
            block.chainid,
            address(ingress),
            artistId,
            r.terms.successor,
            r.terms.evidenceHash,
            r.authorization.nonce,
            r.requestedAt,
            r.noticeEndsAt
        );
        _unavailable(r.recordHash);
        vm.warp(r.noticeEndsAt);
        ingress.executeEstateActivation(p);
        _exact(r.recordHash, expected);
    }

    function testReconstructionDormancyAndRecoveryCatalogRollbackExactRetry() public {
        this.prepareDormancyOrigin(false);
        this.completeDormancyOrigin();
        (,, Dorm.Terminal memory t) = _dorm().dormancyRecord(noticeHash);
        t.recordHash = 0;
        _exact(
            origin,
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                block.chainid,
                address(ingress),
                suite.owners[2],
                t
            )
        );
        this.fileDormancyRecoveryCause(false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("reconstruction actual recovery"));
        this.enterDormancyExecution();
        uint256 count = _catalog().storedPayloadCount();
        uint256 localCount = IStreamArtistReconstruction(suite.owners[2]).storedPayloadCount();
        bytes32 roots = _roots();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistPayloadArchive.registerArtistStoredPayload.selector),
            abi.encodeWithSelector(LateCatalog.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(LateCatalog.selector));
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && _catalog().storedPayloadCount() == count
                && IStreamArtistReconstruction(suite.owners[2]).storedPayloadCount() == localCount
                && ingress.latestIdentityRecovery(artistId) == 0,
            "late catalog failure rolls back every owner/archive/nonce/carrier"
        );
        avm.clearMockedCalls();
        _publish();
        bytes32 recovered = this.executeRegistered(p, a);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(recovered);
        _exact(
            recovered,
            abi.encode(
                bytes32(0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff),
                block.chainid,
                address(ingress),
                r.fields
            )
        );
        _exact(
            origin,
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                block.chainid,
                address(ingress),
                suite.owners[2],
                t
            )
        );
    }

    function testReconstructionDocumentsSignaturesDirectivesHaveStableCatalogIndexes() public {
        uint256 beforeCount = _catalog().storedPayloadCount();
        bytes32[] memory beforeRows = new bytes32[](beforeCount);
        for (uint256 j; j < beforeCount; ++j) {
            (address pointer, bytes32 kind, bytes32 hash) = _catalog().storedPayloadAt(j);
            beforeRows[j] = keccak256(abi.encode(pointer, kind, hash));
        }
        bytes32 directive = _directiveRecord(0);
        bytes32 document = _identity().identity(artistId).identityRecordHash;
        bytes32 signature = keccak256(_identity().signatureBundle(directive));
        bytes32 payload = keccak256(ingress.estateDirectivePayload(directive));
        bool sawDocument;
        bool sawSignature;
        bool sawDirective;
        for (uint256 j; j < _catalog().storedPayloadCount(); ++j) {
            (address pointer, bytes32 kind, bytes32 hash) = _catalog().storedPayloadAt(j);
            require(keccak256(SSTORE2.read(pointer)) == hash, "actual retained content");
            if (j < beforeCount) {
                require(
                    beforeRows[j] == keccak256(abi.encode(pointer, kind, hash)),
                    "stable append-only index"
                );
            }
            if (kind == keccak256("ARTIST_IDENTITY_DOCUMENT") && hash == document) {
                sawDocument = true;
            }
            if (kind == keccak256("ARTIST_SIGNATURE_BUNDLE") && hash == signature) {
                sawSignature = true;
            }
            if (kind == keccak256("ARTIST_DIRECTIVE_PAYLOAD") && hash == payload) {
                sawDirective = true;
            }
        }
        require(
            sawDocument && sawSignature && sawDirective,
            "all original payload families discoverable"
        );
        _unavailable(directive);
    }

    function testReconstructionArchiveWriterAndUnknownIndexStayClosed() public {
        IStreamArtistPayloadArchive archive = IStreamArtistPayloadArchive(suite.archive);
        uint256 count = _catalog().storedPayloadCount();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistArchiveV2.ArtistArchiveUnauthorizedWriter.selector, address(this)
            )
        );
        archive.registerArtistStoredPayload(
            address(0), keccak256("ARTIST_RECORD_PREIMAGE"), bytes32(uint256(1))
        );
        IStreamArtistReconstruction c = _catalog();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistReconstruction.ArtistPayloadIndexOutOfBounds.selector, count, count
            )
        );
        c.storedPayloadAt(count);
        _unavailable(keccak256("never executed"));
        require(c.storedPayloadCount() == count, "failed reads/writes leave catalog unchanged");
    }

    function testReconstructionCorruptCarrierRefusesAndExactRestorationRecovers() public {
        _newRotationSafe(9712);
        bytes32 hash = _stageRotation(0);
        _executeTimedRotation(hash);
        IStreamArtistReconstruction c = _catalog();
        bytes memory expected = c.recordPreimageBytes(hash);
        address pointer;
        uint256 count = c.storedPayloadCount();
        for (uint256 j; j < count; ++j) {
            (address candidate, bytes32 kind, bytes32 h) = c.storedPayloadAt(j);
            if (kind == keccak256("ARTIST_RECORD_PREIMAGE") && h == hash) pointer = candidate;
        }
        require(pointer != address(0), "actual stored preimage pointer");
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00010203");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistReconstruction.ArtistPayloadCorrupted.selector,
                hash,
                keccak256(hex"010203")
            )
        );
        c.recordPreimageBytes(hash);
        vm.etch(pointer, code);
        _exact(hash, expected);
        require(
            c.storedPayloadCount() == count,
            "restoration does not append or replace catalog history"
        );
    }
}
