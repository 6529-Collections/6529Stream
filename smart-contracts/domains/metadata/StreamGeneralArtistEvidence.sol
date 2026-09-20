// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGeneralAttestationReads.sol";
import "../artist/StreamArtistHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";

interface IGeneralArtistSuite {
    function suiteConfiguration()
        external
        view
        returns (StreamArtistOnboardingTypes.SuiteConfiguration memory);
}

/// @notice Exact original op24 receipts; historical authority never means current authority.
library StreamGeneralArtistEvidence {
    struct Configuration {
        address core;
        address registry;
        address attribution;
        bytes32 registryHash;
        bytes32 attributionHash;
        uint256 readGas;
    }

    struct Proof {
        address registry;
        bytes32 registryCodeHash;
        address attribution;
        bytes32 attributionCodeHash;
        uint256 nativeReceiptIndex;
        StreamArtistHistoryTypes.Receipt nativeReceipt;
        StreamArtistOnboardingTypes.Attestation terms;
        StreamArtistOnboardingTypes.AttestationRecord record;
        StreamArtistAttestationTypes.Association association;
        uint8 authorityClass;
        uint256 nonce;
    }

    function requireBinding(Configuration memory c) public view {
        StreamGeneralAttestationReads.code(c.registry, c.registryHash);
        StreamGeneralAttestationReads.code(c.attribution, c.attributionHash);
        address coordinator = abi.decode(
            StreamGeneralAttestationReads.fixedRead(
                c.registry,
                abi.encodeCall(IStreamArtistIngressBinding.operationCoordinator, ()),
                32,
                c.readGas
            ),
            (address)
        );
        if (coordinator.code.length == 0) revert A.InvalidGeneralConfiguration();
        bytes memory raw = StreamGeneralAttestationReads.fixedRead(
            coordinator, abi.encodeCall(IGeneralArtistSuite.suiteConfiguration, ()), 544, c.readGas
        );
        StreamArtistOnboardingTypes.SuiteConfiguration memory suite =
            abi.decode(raw, (StreamArtistOnboardingTypes.SuiteConfiguration));
        if (
            keccak256(raw) != keccak256(abi.encode(suite)) || suite.registry != c.registry
                || suite.core != c.core || suite.owners[4] != c.attribution
        ) revert A.InvalidGeneralConfiguration();
        if (
            abi.decode(
                        StreamGeneralAttestationReads.fixedRead(
                            c.attribution,
                            abi.encodeCall(IStreamArtistOwner.artistRegistry, ()),
                            32,
                            c.readGas
                        ),
                        (address)
                    ) != c.registry
                || abi.decode(
                        StreamGeneralAttestationReads.fixedRead(
                            c.attribution,
                            abi.encodeCall(IStreamArtistOwner.core, ()),
                            32,
                            c.readGas
                        ),
                        (address)
                    ) != c.core
                || abi.decode(
                        StreamGeneralAttestationReads.fixedRead(
                            c.attribution,
                            abi.encodeCall(IStreamArtistOwner.operationCoordinator, ()),
                            32,
                            c.readGas
                        ),
                        (address)
                    ) != coordinator
        ) revert A.InvalidGeneralConfiguration();
    }

    function evidence(Configuration memory c, A.Request calldata r, A.ArtistWitness calldata w)
        public
        view
        returns (bytes memory encoded, bytes32 artistId, uint8 authorityClass)
    {
        StreamGeneralAttestationReads.code(c.registry, c.registryHash);
        StreamGeneralAttestationReads.code(c.attribution, c.attributionHash);
        Proof memory p;
        p.registry = c.registry;
        p.registryCodeHash = c.registryHash;
        p.attribution = c.attribution;
        p.attributionCodeHash = c.attributionHash;
        p.nativeReceiptIndex = w.nativeReceiptIndex;
        p.nonce = w.nonce;
        p.nativeReceipt = abi.decode(
            StreamGeneralAttestationReads.fixedRead(
                c.attribution,
                abi.encodeCall(
                    IStreamArtistNativeReceipts.artistNativeReceiptAt, (w.nativeReceiptIndex)
                ),
                128,
                c.readGas
            ),
            (StreamArtistHistoryTypes.Receipt)
        );
        p.record = abi.decode(
            StreamGeneralAttestationReads.fixedRead(
                c.attribution,
                abi.encodeCall(
                    IStreamArtistAttributionOwner.attestationRecord,
                    (r.artistAuthorizationRecordHash)
                ),
                224,
                c.readGas
            ),
            (StreamArtistOnboardingTypes.AttestationRecord)
        );
        p.association = abi.decode(
            StreamGeneralAttestationReads.fixedRead(
                c.attribution,
                abi.encodeCall(
                    IStreamArtistAuthenticatedAttestationOwner.attestationAssociation,
                    (r.artistAuthorizationRecordHash)
                ),
                256,
                c.readGas
            ),
            (StreamArtistAttestationTypes.Association)
        );
        p.authorityClass = abi.decode(
            StreamGeneralAttestationReads.fixedRead(
                c.attribution,
                abi.encodeCall(
                    IStreamArtistDisplayFacts.attestationAuthorityClass,
                    (r.artistAuthorizationRecordHash)
                ),
                32,
                c.readGas
            ),
            (uint8)
        );
        p.terms = StreamArtistOnboardingTypes.Attestation(
            r.collectionId,
            w.subjectKind,
            r.subjectId,
            p.record.subjectStateHash,
            r.schemaId,
            keccak256(r.payload),
            r.statementURI
        );
        if (
            p.nativeReceipt.operation != 24
                || p.nativeReceipt.recordHash != r.artistAuthorizationRecordHash
                || p.nativeReceipt.collectionId != r.collectionId || p.nativeReceipt.artistId == 0
                || p.record.recordHash != r.artistAuthorizationRecordHash
                || p.record.signer != r.attester || p.record.schemaId != r.schemaId
                || p.record.statementHash != keccak256(r.payload) || p.record.signedAt == 0
                || p.record.signedAt > block.timestamp || p.record.generation == 0
                || p.association.artistId != p.nativeReceipt.artistId
                || p.association.bindingHash == 0 || p.association.generation != p.record.generation
                || p.association.fact.subjectId != r.subjectId
                || p.association.fact.stateHash != p.record.subjectStateHash
                || p.association.fact.owner == address(0) || p.association.fact.ownerCodeHash == 0
                || p.authorityClass == 0 || p.authorityClass > 4
                || (p.authorityClass == 2) != (p.association.delegation != 0)
        ) revert A.GeneralAuthorityRequired();
        StreamArtistHashes.Environment memory environment =
            StreamArtistHashes.Environment(block.chainid, c.registry, c.core, address(0));
        if (
            StreamArtistHashes.attestationRecordForAuthority(
                    environment,
                    p.terms,
                    p.association.artistId,
                    r.attester,
                    p.authorityClass,
                    w.nonce,
                    p.record.signedAt
                ) != r.artistAuthorizationRecordHash
        ) revert A.GeneralAuthorityRequired();
        bytes memory raw = StreamGeneralAttestationReads.bounded(
            c.attribution,
            abi.encodeCall(IStreamArtistAttributionOwner.statementBytes, (p.record.statementHash)),
            8256,
            c.readGas
        );
        bytes memory original = abi.decode(raw, (bytes));
        if (
            keccak256(raw) != keccak256(abi.encode(original)) || original.length != r.payload.length
                || keccak256(original) != keccak256(r.payload)
        ) revert A.GeneralAuthorityRequired();
        return (abi.encode(p), p.association.artistId, p.authorityClass);
    }
}
