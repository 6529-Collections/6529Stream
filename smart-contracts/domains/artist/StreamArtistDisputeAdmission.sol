// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeHashes.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistTimingState.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationOwner.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

library StreamArtistDisputeAdmission {
    function binding(T.SuiteConfiguration memory s, uint256 id, uint64 generation)
        public
        view
        returns (T.Binding memory b, uint8 state, AD.Head memory h)
    {
        b = IStreamArtistBindingOwner(s.owners[0]).binding(id);
        uint64 actual;
        (state, actual) = IStreamArtistAttributionOwner(s.owners[4]).attributionState(id);
        if (
            id == 0 || !IStreamCoreCollectionView(s.core).collectionExists(id) || generation == 0
                || b.generation != generation || actual != generation || b.artistId == 0
                || b.bindingHash == 0 || (b.consentMode != 1 && b.consentMode != 2)
        ) revert AD.InvalidAttributionDispute(id);
        h = IStreamArtistAttributionDisputesOwner(s.owners[4]).attributionDispute(id, generation);
    }

    function openingContext(T.SuiteConfiguration memory s, AD.Filing memory p)
        public
        view
        returns (AD.Context memory c)
    {
        StreamArtistDisputeHashes.validate(p);
        if (p.disputeAction != 1) revert AD.InvalidAttributionDispute(p.collectionId);
        (T.Binding memory b, uint8 state, AD.Head memory h) =
            binding(s, p.collectionId, p.bindingGeneration);
        if (
            h.open || (state != 1 && state != 2 && state != 3 && state != 5)
                || (state == 5 && h.revocationReason != 4)
        ) revert AD.InvalidAttributionDispute(p.collectionId);
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_OPEN_SCOPE_V1"),
                block.chainid,
                s.registry,
                s.core,
                p.collectionId,
                p.bindingGeneration
            )
        );
        c.oldValueHash = keccak256(abi.encode(b, state, h));
        c.newValueHash = keccak256(abi.encode(c.scopeHash, c.oldValueHash, p));
        c.requiredClass = 1;
        c.restoredState = state == 5 ? h.restoreState : state;
    }

    function resolutionContext(T.SuiteConfiguration memory s, AD.ResolutionRequest memory p)
        public
        view
        returns (AD.Context memory c)
    {
        (T.Binding memory b, uint8 state, AD.Head memory h) =
            binding(s, p.collectionId, p.bindingGeneration);
        if (
            state != 4 || !h.open || h.disputeRecordHash == 0
                || h.disputeRecordHash != p.disputeRecordHash
                || h.counterStatementRecordHash != p.counterStatementRecordHash
                || (p.resolution != 1 && p.resolution != 2) || p.evidenceHash == 0
                || p.reasonHash == 0
        ) revert AD.InvalidAttributionDispute(p.collectionId);
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_RESOLUTION_SCOPE_V1"),
                block.chainid,
                s.registry,
                s.core,
                p.collectionId,
                p.bindingGeneration,
                p.disputeRecordHash
            )
        );
        c.oldValueHash = keccak256(abi.encode(b, state, h));
        c.newValueHash = keccak256(abi.encode(c.scopeHash, c.oldValueHash, p));
        c.requiredClass = p.resolution == 2 || h.reopened ? 2 : 1;
        c.restoredState = p.resolution == 2 ? 5 : h.restoreState;
    }

    function standing(
        T.SuiteConfiguration memory s,
        AD.Filing memory p,
        AD.Standing memory supplied
    ) public view returns (AD.Admission memory a) {
        (T.Binding memory b, uint8 state, AD.Head memory h) =
            binding(s, p.collectionId, p.bindingGeneration);
        if (
            supplied.artistId == 0 || supplied.bindingGeneration == 0
                || block.timestamp > type(uint64).max
        ) revert AD.DisputeStandingUnavailable(supplied.artistId);
        if (p.disputeAction == 3) {
            if (
                state != 4 || !h.open || supplied.artistId != b.artistId
                    || supplied.bindingGeneration != b.generation || supplied.collaboratorIndex != 0
            ) revert AD.DisputeStandingUnavailable(supplied.artistId);
            C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(s.owners[0])
                .bindingTerms(p.collectionId, b.generation);
            if (
                terms.mode != 0 || terms.threshold != 0
                    || terms.capabilityPolicySetHash != StreamArtistHashes.emptyCapabilities()
            ) revert T.UnsupportedProfile();
        } else {
            if (p.disputeAction != 1 || (state != 2 && state != 3) || !b.accepted) {
                revert AD.InvalidAttributionDispute(p.collectionId);
            }
            if (supplied.artistId == b.artistId && supplied.bindingGeneration == b.generation) {
                if (supplied.collaboratorIndex != 0) {
                    revert AD.DisputeStandingUnavailable(supplied.artistId);
                }
            } else if (supplied.bindingGeneration < b.generation) {
                T.Binding memory previous = IStreamArtistBindingOwner(s.owners[0])
                    .bindingAt(p.collectionId, supplied.bindingGeneration);
                if (
                    previous.artistId != supplied.artistId || !previous.accepted
                        || previous.bindingHash == 0 || supplied.delegation != 0
                        || supplied.collaboratorIndex != 0
                ) revert AD.DisputeStandingUnavailable(supplied.artistId);
            } else {
                if (supplied.bindingGeneration != b.generation || supplied.delegation != 0) {
                    revert AD.DisputeStandingUnavailable(supplied.artistId);
                }
                C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(s.owners[0])
                    .bindingTerms(p.collectionId, b.generation);
                if (supplied.collaboratorIndex >= terms.count) {
                    revert AD.DisputeStandingUnavailable(supplied.artistId);
                }
                T.CollaboratorRecord memory row = IStreamArtistCollaboratorBindingOwner(s.owners[0])
                    .collaboratorTerm(p.collectionId, b.generation, supplied.collaboratorIndex);
                C.Join memory joined = IStreamArtistCollaboratorRecordsOwner(s.owners[1])
                    .acceptedRow(b.bindingHash, row.account, row.role, row.shareLabelId);
                if (joined.artistId != supplied.artistId || joined.acceptanceRecordHash == 0) {
                    revert AD.DisputeStandingUnavailable(supplied.artistId);
                }
            }
        }
        R.AuthorityFact memory principal =
            StreamArtistCurrentAuthorityFacts.read(s.owners[2], supplied.artistId, true);
        a.binding_ = b;
        a.standing = supplied;
        a.signer = principal.authorityAddress;
        a.authorityClass = principal.authorityClass;
        a.recordedAt = uint64(block.timestamp);
        if (supplied.delegation != 0) {
            if (supplied.artistId != b.artistId || supplied.bindingGeneration != b.generation) {
                revert AD.DisputeStandingUnavailable(supplied.artistId);
            }
            D.Record memory grant =
                IStreamArtistDelegationOwner(s.owners[2]).delegationRecord(supplied.delegation);
            a.signer = grant.grant.delegate;
            a.authorityClass = 2;
        }
    }

    function verify(
        T.SuiteConfiguration memory s,
        address actor,
        address signer,
        bytes32 digest_,
        T.Authorization memory a
    ) public view returns (T.SignerApproval memory proof) {
        if (actor == address(0) || signer == address(0) || a.signature.length > 4096) revert T.InvalidSignature();
        bool direct = actor == signer && a.signature.length == 0;
        if (
            (!direct && (a.time == 0 || block.timestamp > a.time))
                || (direct && a.time != 0 && block.timestamp > a.time)
        ) revert T.InvalidRecord();
        if (!direct) {
            (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(s.registry)
                .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                failure != 2 || revision == 0
                    || !StreamArtistRegistryValidatorBase(s.validator)
                        .validateSignerProof(signer, digest_, a.signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest_, direct);
    }

    function evidence(
        T.SuiteConfiguration memory s,
        T.Binding memory b,
        uint256 id,
        bytes32 parent,
        bytes32 hash
    ) public view returns (bytes32) {
        (address host, bytes32 runtime,,,,,,,,) = IStreamCorePointers(s.core)
            .getSatellitePointer(keccak256("COLLECTION_METADATA"));
        if (
            hash == 0 || host.code.length == 0 || runtime != host.codehash
                || IStreamCollectionMetadataV1(host).core() != s.core
        ) revert AD.InvalidDisputeEvidence(hash);
        address chunks = IStreamCollectionMetadataV1(host).chunkStore();
        bytes memory raw = StreamSchemaDocumentStore(chunks).readChunk(hash);
        if (raw.length != 192 || keccak256(raw) != hash) revert AD.InvalidDisputeEvidence(hash);
        AD.Evidence memory e = abi.decode(raw, (AD.Evidence));
        if (
            e.schemaVersion != 1 || e.collectionId != id || e.bindingGeneration != b.generation
                || e.bindingHash != b.bindingHash || e.disputeRecordHash != parent
                || e.narrativeHash == 0 || keccak256(abi.encode(e)) != hash
        ) revert AD.InvalidDisputeEvidence(hash);
        address coverage = IStreamArtistEstateBinding(s.registry).archivalCoverage();
        if (
            coverage.code.length == 0
                || coverage.codehash
                    != IStreamArtistEstateBinding(s.registry).archivalCoverageCodeHash()
        ) revert AD.InvalidDisputeEvidence(hash);
        A.CoverageFacts memory f =
            IStreamCollectionArchivalCoverage(coverage).requireCollectionEvidence(id, hash);
        if (
            f.artistId != 0 || f.evidenceHash != hash || f.coverageRecordHash == 0
                || f.envelopeHash == 0
        ) {
            revert AD.InvalidDisputeEvidence(hash);
        }
        return keccak256(abi.encode(host, runtime, chunks, chunks.codehash, e, f));
    }

    function requireGrant(T.SuiteConfiguration memory s, D.Grant memory p) public view {
        if (p.collectionId == 0) return;
        T.Binding memory b = IStreamArtistBindingOwner(s.owners[0]).binding(p.collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(s.owners[4]).attributionState(p.collectionId);
        if (
            b.artistId != p.artistId || b.generation != generation || !b.accepted
                || (state != 2 && state != 3)
        ) revert T.InvalidAttribution(p.collectionId);
    }
}
