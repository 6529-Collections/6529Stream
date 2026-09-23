// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as V
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamArtistArchiveOriginProof as Proof } from "./StreamArtistArchiveOriginProof.sol";
import {
    StreamMultiOriginArtistArchiveLoad as Archive
} from "./StreamMultiOriginArtistArchiveLoad.sol";
import "../artist/StreamArtistHashes.sol";
import "../artist/StreamArtistContentHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";

import {
    StreamPolicyRenderCriticalTypesV2 as Context
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    IStreamPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedContentRootPublication as Scoped
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

/// @notice Exact original op17 evidence behind a canonical COLLECTION V2 root.
/// @dev Actor is an untrusted archive locator, distinct from the original signer. No current
/// key, grant, ERC1271 owner set, consumed nonce or deadline is re-applied to historical proof.
library StreamMultiOriginPolicyRootAuthorizationV2 {
    struct Envelope {
        uint16 version;
        bytes32 configurationHash;
        uint16 operationId;
        address actor;
        bytes32 record;
        A.Snapshot[7] before_;
        A.Snapshot[7] after_;
        bytes payload;
    }

    struct Payload {
        A.Binding binding;
        A.Attestation attestation;
        A.Authorization submitted;
        bytes statement;
        A.SignerApproval approval;
        A.Authorization effective;
        R.AuthorityFact authority;
        P.Publication publication;
        bytes32 metadataCodeHash;
    }

    struct Loaded {
        A.SuiteConfiguration suite;
        address coordinator;
        bytes32 id;
        bytes evidence;
    }

    struct ContentPayload {
        A.Binding binding;
        StreamArtistContentTypes.Consent terms;
        A.Authorization authorization;
        A.SignerApproval approval;
        bytes32 priorState;
    }

    function contentItem(
        S.Dependencies memory d,
        Context.Context memory c,
        address actor,
        uint64 observedAt,
        Scoped.Aggregate memory originalAggregate,
        bytes32 sourceContextHash,
        O.ReceiptWitness memory witness
    ) public view returns (V.Item memory result, O.RecordOrigin memory original) {
        if (
            actor == address(0)
                || (originalAggregate.revision == 0) != (originalAggregate.transitionChain == 0)
        ) revert V.InvalidInventoryItem();
        bytes memory raw = IO.read(
            d.targets[4],
            abi.encodeCall(
                IStreamContentRootPublication.contentRootRecord, (c.records.rootRecordHash)
            ),
            8192,
            d.sourceGas
        );
        IStreamContentRootPublication.Record memory root =
            abi.decode(raw, (IStreamContentRootPublication.Record));
        IO.canonical(d.targets[4], raw, abi.encode(root));
        raw = IO.fixedRead(
            d.targets[4],
            abi.encodeCall(RootV2.policyContentRootBinding, (c.records.rootRecordHash)),
            544,
            d.readGas
        );
        RootV2.Binding memory binding = abi.decode(raw, (RootV2.Binding));
        IO.canonical(d.targets[4], raw, abi.encode(binding));
        if (
            keccak256(abi.encode(root, binding))
                    != keccak256(abi.encode(c.source.root, c.source.rootBinding))
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                            d.chainId,
                            d.targets[4],
                            root,
                            binding
                        )
                    ) != c.records.rootRecordHash || root.artistId != c.records.artistId
                || root.publication.collectionId != c.records.collectionId
                || root.artistConsent == 0
        ) revert V.InvalidInventoryItem();
        bytes32 signedFamily = originalAggregate.revision == 0
            ? root.stateHash
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                    d.chainId,
                    d.targets[4],
                    d.targets[0],
                    c.records.collectionId,
                    root.stateHash,
                    originalAggregate
                )
            );
        original = Proof.contentOrigin(
            d,
            c.records.collectionId,
            root.artistId,
            root.artistConsent,
            actor,
            O.ContentRole.POLICY_COLLECTION,
            sourceContextHash,
            witness
        );
        d = Archive.originalDependencies(d, original.producer);
        Loaded memory loaded = _load(d, original);
        _contentOriginal(d, root, signedFamily, actor, observedAt, loaded);
        bytes32 retained = _retained(loaded.suite.archive, loaded.id, loaded.evidence, d.readGas);
        result = Items.bytesItem(
            V.Kind.STATE_BUNDLE,
            keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2"),
            loaded.suite.archive,
            loaded.id,
            1,
            loaded.evidence
        );
        result.provenanceHash = keccak256(
            abi.encode(
                c.records.rootRecordHash,
                originalAggregate,
                signedFamily,
                actor,
                observedAt,
                retained,
                keccak256(abi.encode(d))
            )
        );
        result.provenanceHash = Archive.provenance(result.provenanceHash, original);
    }

    function _contentOriginal(
        S.Dependencies memory d,
        IStreamContentRootPublication.Record memory root,
        bytes32 signedFamily,
        address actor,
        uint64 observedAt,
        Loaded memory loaded
    ) private view {
        IO.pin(d.artistContentOwner, d.artistContentOwnerCodeHash);
        if (loaded.suite.owners[6] != d.artistContentOwner) revert V.InvalidInventoryItem();
        ContentPayload memory p = _decodeContent(d, root.artistConsent, actor, loaded);
        uint8 class_ = _contentSaved(d, root, signedFamily, p);
        if (
            observedAt == 0 || observedAt > root.publishedAt || p.authorization.time < observedAt
                || (p.approval.direct
                        ? (actor != p.approval.signer || p.authorization.signature.length != 0)
                        : p.authorization.signature.length == 0)
        ) revert V.InvalidInventoryItem();
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            d.chainId, loaded.suite.registry, d.targets[0], loaded.suite.mintManager
        );
        if (
            p.approval.digest
                    != StreamArtistContentHashes.consentDigest(e, p.terms, p.authorization)
                || StreamArtistContentHashes.consentRecord(
                        e,
                        p.terms,
                        root.artistId,
                        p.approval.signer,
                        class_,
                        p.authorization.nonce,
                        observedAt
                    ) != root.artistConsent
        ) revert V.InvalidInventoryItem();
    }

    function _decodeContent(
        S.Dependencies memory d,
        bytes32 record,
        address actor,
        Loaded memory loaded
    ) private view returns (ContentPayload memory p) {
        bytes memory wrapped = bytes.concat(bytes32(uint256(32)), loaded.evidence);
        Envelope memory envelope = abi.decode(wrapped, (Envelope));
        IO.canonical(loaded.suite.archive, wrapped, abi.encode(envelope));
        if (
            envelope.version != 1 || envelope.operationId != 17 || envelope.actor != actor
                || envelope.record != record
                || envelope.configurationHash
                    != IO.word(
                        loaded.coordinator,
                        abi.encodeWithSignature("configurationHash()"),
                        d.readGas
                    )
        ) revert V.InvalidInventoryItem();
        wrapped = bytes.concat(bytes32(uint256(32)), envelope.payload);
        p = abi.decode(wrapped, (ContentPayload));
        IO.canonical(loaded.suite.archive, wrapped, abi.encode(p));
    }

    function _contentSaved(
        S.Dependencies memory d,
        IStreamContentRootPublication.Record memory root,
        bytes32 signedFamily,
        ContentPayload memory p
    ) private view returns (uint8) {
        bytes memory raw = IO.fixedRead(
            d.artistContentOwner,
            abi.encodeCall(
                IStreamArtistContentRecordsOwner.contentConsentRecord, (root.artistConsent)
            ),
            256,
            d.readGas
        );
        IStreamArtistContentRecordsOwner.ConsentRecord memory saved =
            abi.decode(raw, (IStreamArtistContentRecordsOwner.ConsentRecord));
        IO.canonical(d.artistContentOwner, raw, abi.encode(saved));
        if (
            saved.recordHash != root.artistConsent || saved.artistId != root.artistId
                || saved.bindingGeneration != root.bindingGeneration
                || (saved.authorityClass != 1 && saved.authorityClass != 3)
                || keccak256(abi.encode(saved.terms)) != keccak256(abi.encode(p.terms))
                || p.terms.collectionId != root.publication.collectionId
                || p.terms.metadataContract != d.targets[4]
                || p.terms.familyId != keccak256("CONTENT_ROOT")
                || p.terms.newStateHash != signedFamily || p.binding.artistId != root.artistId
                || p.binding.bindingHash != root.bindingHash
                || p.binding.generation != root.bindingGeneration || !p.binding.accepted
                || p.approval.signer == address(0) || p.priorState == 0
                || p.priorState == signedFamily
        ) revert V.InvalidInventoryItem();
        return saved.authorityClass;
    }

    function _load(S.Dependencies memory d, O.RecordOrigin memory original)
        private
        view
        returns (Loaded memory loaded)
    {
        (loaded.suite, loaded.coordinator, loaded.id, loaded.evidence) = Archive.load(d, original);
    }

    function _retained(address archive, bytes32 id, bytes memory evidence, uint256 readGas)
        private
        view
        returns (bytes32)
    {
        bytes memory raw = IO.fixedRead(
            archive,
            abi.encodeCall(IStreamArtistArchiveV2.artistEvidenceMetadataV2, (id, 1)),
            128,
            readGas
        );
        (bytes32 hash, address pointer, uint32 size, uint64 appendedAt) =
            abi.decode(raw, (bytes32, address, uint32, uint64));
        IO.canonical(archive, raw, abi.encode(hash, pointer, size, appendedAt));
        if (
            hash != keccak256(evidence) || size != evidence.length || appendedAt == 0
                || pointer.code.length != size + 1
        ) {
            revert V.InvalidInventoryItem();
        }
        bytes memory retained = new bytes(size + 1);
        assembly ("memory-safe") { extcodecopy(pointer, add(retained, 32), 0, add(size, 1)) }
        if (retained[0] != 0 || keccak256(retained) != keccak256(bytes.concat(hex"00", evidence))) {
            revert V.InvalidInventoryItem();
        }
        return keccak256(abi.encode(id, hash, pointer, pointer.codehash, size, appendedAt));
    }
}
