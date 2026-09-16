// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";

/// @dev Actual Artist owners, threshold Safes, Archive and dual-family coverage. Core,
/// metadata-host getters and Executor action/role admission remain explicit unit boundaries.
abstract contract ArtistAttributionDisputeFixture is ArtistOnboardingFixture {
    StreamSchemaDocumentStore internal _deStore;
    bytes32 internal _deFirst;
    bytes32 internal _deSecond;
    uint256 internal _deNonce;
    uint256 internal _governanceNonce;
    error DisputeTestFailure();

    function _head() internal view returns (AD.Head memory) {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        return ingress.attributionDispute(1, b.generation);
    }

    function _standing() internal view returns (AD.Standing memory) {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        return AD.Standing(artistId, b.generation, 0, 0);
    }

    function _filing(uint8 action, bytes32 label) internal returns (AD.Filing memory p) {
        (bytes32 e,) = _deEvidence(_head().disputeRecordHash, label);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        return AD.Filing(1, b.generation, action, e, e);
    }

    function _signed(AD.Filing memory p) internal returns (T.Authorization memory a) {
        a = _authorization(false);
        a.signature = _signature(ingress.attributionDisputeDigest(p, a));
    }

    function _open(bytes32 label) internal returns (bytes32) {
        AD.Filing memory p = _filing(1, label);
        return ingress.openAttributionDispute(p, _standing(), _signed(p));
    }

    function _counter(bytes32 label) internal returns (bytes32) {
        AD.Filing memory p = _filing(3, label);
        return ingress.recordCounterStatement(p, _standing(), _signed(p));
    }

    function _resolution(uint8 choice, bytes32 label)
        internal
        returns (AD.ResolutionRequest memory p)
    {
        AD.Head memory h = _head();
        (bytes32 e,) = _deEvidence(h.disputeRecordHash, label);
        return AD.ResolutionRequest(
            1,
            _standing().bindingGeneration,
            h.disputeRecordHash,
            choice,
            e,
            e,
            h.counterStatementRecordHash
        );
    }

    function _govern(bytes memory data, AD.Context memory c, bytes32 reason, uint8 class_)
        internal
        returns (bytes32 action)
    {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:dispute:governance"
        );
        action = keccak256(
            abi.encode("actual dispute action boundary", ++_governanceNonce, data, c, class_)
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, class_, c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        authority.executeModuleContext(
            address(ingress), data, class_, c.scopeHash, c.oldValueHash, c.newValueHash
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function _resolve(AD.ResolutionRequest memory p, uint8 class_) internal returns (bytes32) {
        return _govern(
            abi.encodeCall(IStreamArtistAttributionDisputes.resolveAttributionDispute, (p)),
            ingress.attributionDisputeResolutionContext(p),
            p.reasonHash,
            class_
        );
    }

    function disputeGoverned(
        bytes calldata data,
        AD.Context calldata c,
        bytes32 reason,
        uint8 class_
    ) external returns (bytes32) {
        require(msg.sender == address(this));
        return _govern(data, c, reason, class_);
    }

    function disputeRelay(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(this));
        (bool ok, bytes memory result) = address(ingress).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return result;
    }

    function _record(AD.Filing memory p, address signer, uint8 class_, uint256 nonce, uint64 at)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.collectionId,
                p.bindingGeneration,
                p.disputeAction,
                signer,
                class_,
                p.evidenceHash,
                p.reasonHash,
                nonce,
                at
            )
        );
    }

    function _digest(AD.Filing memory p, T.Authorization memory a) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(ingress)
            )
        );
        bytes32 payload = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)"
                ),
                address(core),
                p.collectionId,
                p.bindingGeneration,
                p.disputeAction,
                p.evidenceHash,
                p.reasonHash,
                a.nonce,
                a.time
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domain, payload));
    }

    function _state(uint8 expected) internal view {
        (uint8 state,) = IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        require(state == expected, "actual Attribution state");
    }

    function _deMetadata() internal {
        if (address(_deStore) == address(0)) _deStore = new StreamSchemaDocumentStore();
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.core, ()),
            abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()),
            abi.encode(address(_deStore))
        );
    }

    function _deEvidence(bytes32 parent, bytes32 narrative)
        internal
        returns (bytes32 evidence, bytes32 coverage)
    {
        _deMetadata();
        if (_deFirst == 0) {
            _deGrantFixity();
            _deFirst = _deFamily(true);
            _deSecond = _deFamily(false);
        }
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        bytes memory payload = abi.encode(
            AD.Evidence(1, 1, binding_.generation, binding_.bindingHash, parent, narrative)
        );
        (evidence,) = _deStore.publishChunk(payload);
        A.Envelope memory e = A.Envelope(
            0,
            evidence,
            keccak256("6529STREAM_ARTIST_DISPUTE_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            0
        );
        bytes32 env = estateCoverageProvider.recordCollectionEnvelope(1, e, payload);
        A.Checkpoint memory c;
        c.networkId = estateCheckpointVerifier.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        c.dataSize = uint64(payload.length);
        c.blockDataSize = payload.length;
        c.dataRoot = _deLeaf(sha256(payload), payload.length);
        c.transactionRoot = _deLeaf(c.dataRoot, payload.length);
        c.transactionId = keccak256(abi.encode("synthetic dispute transaction", evidence));
        c.transactionEnd = payload.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = estateCheckpointVerifier.configurationHash();
        bytes32 digest = estateCheckpointVerifier.checkpointDigest(c);
        A.ObserverProof[] memory cert = new A.ObserverProof[](2);
        cert[0] = A.ObserverProof(safeVm.addr(0xE5701), _deSign(0xE5701, digest));
        cert[1] = A.ObserverProof(safeVm.addr(0xE5702), _deSign(0xE5702, digest));
        if (cert[0].account > cert[1].account) (cert[0], cert[1]) = (cert[1], cert[0]);
        bytes32 checkpoint = estateCheckpointVerifier.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(payload.length)),
            abi.encodePacked(sha256(payload), uint256(payload.length)),
            payload,
            cert
        );
        bytes32 first =
            _deReceipt(env, _deFirst, checkpoint, abi.encodePacked(c.transactionId), 0xE5703, true);
        bytes32 second = _deReceipt(
            env, _deSecond, 0, abi.encodePacked(bytes4(0x01551220), e.payloadDigest), 0xE5704, false
        );
        _deFixity(first, e, _deNonce++);
        _deFixity(second, e, _deNonce++);
        coverage = estateCoverageProvider.recordCoverage(first, second);
        require(
            estateCoverageProvider.requireCollectionEvidence(1, evidence).coverageRecordHash
                == coverage,
            "actual two independent families and exact native checkpoint"
        );
    }

    function _deLeaf(bytes32 digest, uint256 end) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(abi.encodePacked(digest)), sha256(abi.encode(end))));
    }

    function _deArchive(uint16 op, address actor, bytes32 record) internal view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                op,
                actor,
                record
            )
        );
        (uint16 schema, bytes32 config, uint16 actual, address savedActor, bytes32 saved,,,) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == coordinator.configurationHash() && actual == op
                && savedActor == actor && saved == record,
            "exact original operation archive"
        );
    }

    function _deFamily(bool endowed) internal returns (bytes32 hash) {
        string memory name = endowed ? "estate-arweave" : "estate-ipfs";
        bytes memory salt = bytes(name);
        A.Family memory f = A.Family(
            keccak256(salt),
            endowed ? estateCheckpointVerifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256(bytes.concat(salt, "jurisdiction")),
            endowed ? 1 : 2,
            safeVm.addr(endowed ? 0xE5703 : 0xE5704),
            endowed
                ? estateCheckpointVerifier.profileHash()
                : estateCoverageProvider.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = estateCoverageProvider.familyRegistrationContext(name, f);
        EstateGovernanceFixture(manager.governanceAuthority())
            .executeModuleContext(
                address(estateCoverageProvider),
                abi.encodeCall(estateCoverageProvider.admitFamily, (name, f)),
                1,
                scope,
                oldHash,
                newHash
            );
    }

    function _deReceipt(
        bytes32 envelope,
        bytes32 family,
        bytes32 checkpoint,
        bytes memory identifier,
        uint256 key,
        bool endowed
    ) internal returns (bytes32) {
        A.ReceiptTerms memory r = A.ReceiptTerms(
            envelope,
            family,
            keccak256(identifier),
            keccak256(bytes(endowed ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            endowed
                ? estateCheckpointVerifier.profileHash()
                : estateCoverageProvider.POSSESSION_PROFILE(),
            checkpoint,
            safeVm.addr(key),
            uint64(block.timestamp),
            _deNonce++,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = estateCoverageProvider.possessionHash(
                A.Possession(envelope, family, r.storageIdentifierHash, r.writer, r.observedAt)
            );
        }
        return estateCoverageProvider.recordReceipt(
            r, identifier, _deSign(key, estateCoverageProvider.receiptDigest(r))
        );
    }

    function _deFixity(bytes32 receipt, A.Envelope memory e, uint256 nonce) internal {
        (A.ReceiptTerms memory r,,) = estateCoverageProvider.receipt(receipt);
        A.FixityTerms memory f = A.FixityTerms(
            receipt,
            r.envelopeHash,
            r.familyRecordHash,
            e.payloadDigest,
            e.payloadDigest,
            e.byteSize,
            uint64(block.timestamp),
            1,
            keccak256(abi.encode("estate fixity", receipt)),
            0,
            0,
            safeVm.addr(0xE5705),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        estateCoverageProvider.recordFixity(
            f, _deSign(0xE5705, estateCoverageProvider.fixityDigest(f))
        );
    }

    function _deSign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _deGrantFixity() internal {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        address holder = safeVm.addr(0xE5705);
        (bytes32 chain, uint64 revision) = estateFixityRoles.roleMutationState(role);
        (bytes32 global, uint64 globalRevision) = estateFixityRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(estateFixityRoles),
                role,
                holder
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(estateFixityRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                global,
                block.chainid,
                address(estateFixityRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 oldHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(estateFixityRoles),
                scope,
                false,
                chain,
                revision,
                global,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(estateFixityRoles),
                scope,
                true,
                next,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        EstateGovernanceFixture(manager.governanceAuthority())
            .executeModuleContext(
                address(estateFixityRoles),
                abi.encodeCall(estateFixityRoles.grantRole, (role, holder)),
                1,
                scope,
                oldHash,
                newHash
            );
    }
}
