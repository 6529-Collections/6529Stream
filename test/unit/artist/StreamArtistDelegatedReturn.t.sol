// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";

/// @notice Actual facade/Safe/owners/Archive; original typed unit Core and governance boundaries.
contract StreamArtistDelegatedReturnTest is ArtistOnboardingFixture {
    function _before(uint32 capability) internal returns (bytes32 grant, T.Snapshot memory prior) {
        _accept();
        _payout();
        _delegateSetup();
        grant = _grant(_delegation(1, capability, 1000, 2000, 3));
        prior = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
    }

    function _after(
        T.Snapshot memory prior,
        bytes32 grant,
        bytes32 record,
        bytes32 expected,
        uint16 op,
        bytes memory signature
    ) internal view {
        require(record != 0 && record == expected, "nonzero original computed output");
        T.Snapshot memory next = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            next.revision == prior.revision + 1 && next.stateRoot != prior.stateRoot,
            "one original Identity semantic commit"
        );
        require(
            next.recordChainTip == prior.recordChainTip,
            "delegated Identity commit retains zero record delta"
        );
        require(
            keccak256(StreamArtistIdentityAuthority(suite.owners[2]).signatureBundle(record))
                == keccak256(signature),
            "signature keyed by returned hash"
        );
        require(
            ingress.recordDelegation(record) == grant && ingress.delegationRecord(grant).uses == 1,
            "original actual grant association and one use"
        );
        require(
            _operationPayload(op, address(this), record).length != 0,
            "original Archive operation record"
        );
    }

    function testDelegatedAttestationReturnsRecordWithoutAppendingIdentityRecord() public {
        (bytes32 grant, T.Snapshot memory prior) = _before(1);
        bytes memory statement = bytes("delegated return regression");
        T.Attestation memory p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash,
            keccak256("return regression schema"),
            keccak256(statement),
            "urn:artist:return"
        );
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp), "");
        a.signature = _delegateSignature(ingress.attestationDigest(p, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                p.collectionId,
                p.subjectKind,
                p.subjectId,
                p.subjectStateHash,
                p.schemaId,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                artistId,
                address(delegateSafe),
                uint8(2),
                a.nonce,
                a.time
            )
        );
        bytes32 record = ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        _after(prior, grant, record, expected, 24, a.signature);
    }

    function testDelegatedEconomicsReturnsRecordWithoutAppendingIdentityRecord() public {
        (bytes32 grant, T.Snapshot memory prior) = _before(4);
        T.EconomicsConsent memory p = _currentEconomics(address(primary));
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.economicsConsentDigest(p, a));
        (, bytes32 designation) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.resolver,
                p.revenueClass,
                p.scope,
                p.scopeId,
                p.assignmentHash,
                designation,
                artistId,
                address(delegateSafe),
                uint8(2),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        bytes32 record = ingress.recordDelegatedEconomicsConsent(p, grant, a);
        _after(prior, grant, record, expected, 15, a.signature);
    }

    function testDelegatedFreezeReturnsRecordWithoutAppendingIdentityRecord() public {
        (bytes32 grant, T.Snapshot memory prior) = _before(32);
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.royaltyFreezeDigest(p, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.resolver,
                p.collectionId,
                p.revenueClass,
                p.expectedAssignmentHash,
                artistId,
                address(delegateSafe),
                uint8(2),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        bytes32 record = ingress.authorizeDelegatedRoyaltyFreeze(p, grant, a);
        _after(prior, grant, record, expected, 20, a.signature);
    }
}
