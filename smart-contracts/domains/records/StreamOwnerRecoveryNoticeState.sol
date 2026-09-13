// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamOwnerRecoveryNotices.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "./StreamStewardDesignationJson.sol";
import "./StreamOwnerRecoveryNoticePreparation.sol";
import "../metadata/StreamOwnerRecordReads.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Host-owned notice snapshots, complete response queues and original claim bytes.
/// @dev All mutators run under OwnerRecords' shared guard. No current-authority gate protects history.
library StreamOwnerRecoveryNoticeState {
    event OwnerRecoveryNoticeOpened(
        bytes32 indexed actionId,
        uint256 indexed tokenId,
        address indexed openingOwner,
        address publisher,
        bytes32 stewardRecordHash,
        bytes32 publicationHash,
        uint64 openedAt,
        uint64 noticeEndsAt,
        bytes32 evidenceHash,
        uint16 schemaVersion
    );
    event OwnerRecoveryResponseRecorded(
        bytes32 indexed actionId,
        address indexed author,
        bytes32 indexed recordHash,
        uint256 tokenId,
        bool queued,
        bool afterMinimumWindow,
        uint16 schemaVersion
    );
    event OwnerRecoveryResponseProcessed(
        bytes32 indexed actionId,
        address indexed author,
        bytes32 indexed recordHash,
        bytes32 predecessor,
        uint64 revision,
        uint32 acknowledgements,
        uint32 objections,
        bytes32 evidenceHash,
        uint16 schemaVersion
    );

    struct Configuration {
        StreamOwnerRecoveryActionReads.Config action;
        address store;
        bytes32 storeCodeHash;
    }

    struct OriginalOwner {
        address owner;
        bytes32 stewardRecordHash;
        bytes32 stewardPayloadHash;
        uint64 firstResponseIndex;
    }

    struct Notice {
        StreamOwnerRecoveryNoticeTypes.Snapshot snapshot;
        address publicationPointer;
        bytes32 publicationBytesHash;
        address[] deliveryPointers;
        bytes32[] deliveryHashes;
        mapping(address => bytes32) latest;
    }

    struct State {
        mapping(bytes32 => Notice) notices;
        mapping(bytes32 => StreamOwnerRecoveryNoticeTypes.Response) responses;
        mapping(bytes32 => bytes32[]) candidates;
    }

    bytes32 private constant OPEN = keccak256("6529STREAM_OWNER_RECOVERY_NOTICE_V1");
    bytes32 private constant UPDATE = keccak256("6529STREAM_OWNER_RECOVERY_RESPONSE_V1");

    struct OpeningWitness {
        bytes32 actionId;
        GovernanceCall[] calls;
        StreamFinalityRecoveryRequest request;
        OriginalOwner owner;
        StreamOwnerNoticeTypes.Designation steward;
        StreamOwnerRecoveryNoticeTypes.Publication publication;
    }

    function open(State storage s, Configuration memory c, OpeningWitness memory w) public {
        Notice storage n = s.notices[w.actionId];
        if (n.snapshot.openingOwner != address(0)) {
            revert IStreamOwnerRecoveryNotices.OwnerRecoveryNoticeExists(w.actionId);
        }
        if (w.request.scope.scopeType != StreamFinalityScopeType.TOKEN) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        StreamOwnerRecoveryActionReads.Binding memory b =
            StreamOwnerRecoveryActionReads.admit(c.action, w.actionId, w.calls, w.request);
        _token(c.action, w.request.scope);
        if (block.timestamp == 0 || block.timestamp + 72 hours > b.expiresAfter) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        _steward(w.owner, w.steward);
        if (w.publication.deliveries.length != 1 + w.steward.contactEndpoints.length) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        _reference(w.publication.runbook);
        _reference(w.publication.publicNotice);
        bytes memory raw = abi.encode(w.publication.runbook, w.publication.publicNotice);
        n.publicationPointer = _publish(c, raw);
        n.publicationBytesHash = keccak256(raw);
        bytes32 publicationHash = n.publicationBytesHash;
        for (uint256 i; i < w.publication.deliveries.length; ++i) {
            StreamOwnerNoticeTypes.Contact memory expected = i == 0
                ? StreamOwnerNoticeTypes.Contact(
                    StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, w.owner.owner
                )
                : w.steward.contactEndpoints[i - 1];
            StreamOwnerRecoveryNoticeTypes.Delivery memory d = w.publication.deliveries[i];
            if (keccak256(abi.encode(d.endpoint)) != keccak256(abi.encode(expected))) {
                revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
            }
            // The exact steward endpoint was already validated by the full saved witness.
            if (i == 0) StreamOwnerNoticeFields.contact(d.endpoint);
            _reference(d.evidence);
            raw = abi.encode(d);
            bytes32 hash = keccak256(raw);
            n.deliveryPointers.push(_publish(c, raw));
            n.deliveryHashes.push(hash);
            publicationHash = keccak256(abi.encode(publicationHash, i, hash));
        }
        _save(
            s,
            c,
            SavedOpening(
                w.actionId,
                b,
                w.request.scope,
                w.owner,
                msg.sender,
                publicationHash,
                uint64(w.publication.deliveries.length)
            )
        );
    }

    struct SavedOpening {
        bytes32 actionId;
        StreamOwnerRecoveryActionReads.Binding binding;
        StreamFinalityScope scope;
        OriginalOwner owner;
        address publisher;
        bytes32 publicationHash;
        uint64 deliveryCount;
    }

    struct PreparedOpeningWitness {
        bytes32 preparationId;
        GovernanceCall[] calls;
        StreamFinalityRecoveryRequest request;
        uint64 firstResponseIndex;
    }

    event OwnerRecoveryNoticePreparedOpening(
        bytes32 indexed preparationId,
        bytes32 indexed actionId,
        address indexed publisher,
        address finalizer,
        uint16 schemaVersion
    );

    function openPrepared(
        State storage s,
        StreamOwnerRecoveryNoticePreparation.State storage prepared,
        mapping(
            uint256
                => mapping(
                address => bytes32
            )
        ) storage stewards,
        Configuration memory c,
        PreparedOpeningWitness memory w
    ) public {
        StreamOwnerPreparedNoticeTypes.Snapshot memory p =
            StreamOwnerRecoveryNoticePreparation.consume(
                prepared,
                stewards,
                StreamOwnerRecoveryNoticePreparation.Configuration(
                    c.action.core, c.action.coreCodeHash, c.store, c.storeCodeHash, c.action.readGas
                ),
                w.preparationId
            );
        if (
            w.request.scope.scopeType != StreamFinalityScopeType.TOKEN
                || w.request.scope.tokenId != p.tokenId
                || s.notices[p.actionId].snapshot.openingOwner != address(0)
        ) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        StreamOwnerRecoveryActionReads.Binding memory binding =
            StreamOwnerRecoveryActionReads.admit(c.action, p.actionId, w.calls, w.request);
        _token(c.action, w.request.scope);
        if (block.timestamp == 0 || block.timestamp + 72 hours > binding.expiresAfter) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        _save(
            s,
            c,
            SavedOpening(
                p.actionId,
                binding,
                w.request.scope,
                OriginalOwner(
                    p.openingOwner, p.stewardRecordHash, p.stewardPayloadHash, w.firstResponseIndex
                ),
                p.publisher,
                p.publicationHash,
                p.deliveryCount
            )
        );
        emit OwnerRecoveryNoticePreparedOpening(
            w.preparationId, p.actionId, p.publisher, msg.sender, 1
        );
    }

    function _save(State storage s, Configuration memory c, SavedOpening memory o) private {
        StreamOwnerRecoveryNoticeTypes.Snapshot storage v = s.notices[o.actionId].snapshot;
        v.binding = o.binding;
        v.scope = o.scope;
        v.publisher = o.publisher;
        v.openingOwner = o.owner.owner;
        v.stewardRecordHash = o.owner.stewardRecordHash;
        v.stewardPayloadHash = o.owner.stewardPayloadHash;
        v.publicationHash = o.publicationHash;
        v.openedAt = uint64(block.timestamp);
        v.noticeEndsAt = uint64(block.timestamp + 72 hours);
        v.firstResponseIndex = o.owner.firstResponseIndex;
        v.deliveryCount = uint64(o.deliveryCount);
        v.responseTail =
            uint64(s.candidates[_key(o.scope.tokenId, o.actionId, o.binding.manifestHash)].length);
        v.revision = 1;
        v.evidenceHash = keccak256(
            abi.encode(
                OPEN,
                block.chainid,
                address(this),
                c.action.core,
                o.actionId,
                o.binding,
                o.scope,
                o.publisher,
                o.owner,
                o.publicationHash,
                v.openedAt,
                v.noticeEndsAt,
                v.responseTail
            )
        );
        if (
            StreamOwnerRecordReads.owner(
                    c.action.core, c.action.coreCodeHash, o.scope.tokenId, c.action.readGas
                ) != o.owner.owner
        ) revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        emit OwnerRecoveryNoticeOpened(
            o.actionId,
            o.scope.tokenId,
            o.owner.owner,
            o.publisher,
            o.owner.stewardRecordHash,
            o.publicationHash,
            v.openedAt,
            v.noticeEndsAt,
            v.evidenceHash,
            1
        );
    }

    function append(
        State storage s,
        bytes32 hash,
        IStreamOwnerRecords.Receipt memory receipt,
        StreamOwnerNoticeTypes.Response memory response
    ) public {
        if (s.responses[hash].author != address(0)) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        bytes32 key = _key(receipt.tokenId, response.recoveryId, response.recoveryManifestHash);
        bytes32[] storage queue = s.candidates[key];
        if (queue.length == type(uint64).max) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        queue.push(hash);
        StreamOwnerRecoveryNoticeTypes.Snapshot storage n = s.notices[response.recoveryId].snapshot;
        bool queued = n.openingOwner != address(0) && n.scope.tokenId == receipt.tokenId
            && n.binding.manifestHash == response.recoveryManifestHash;
        bool late = queued && receipt.recordedAt >= n.noticeEndsAt;
        s.responses[hash] = StreamOwnerRecoveryNoticeTypes.Response(
            receipt.tokenId,
            receipt.owner,
            response.recoveryId,
            response.recoveryManifestHash,
            receipt.recordedAt,
            receipt.recordIndex,
            response.response,
            queued,
            false,
            late
        );
        if (queued) n.responseTail = uint64(queue.length);
        emit OwnerRecoveryResponseRecorded(
            response.recoveryId, receipt.owner, hash, receipt.tokenId, queued, late, 1
        );
    }

    function process(State storage s, Configuration memory c, bytes32 actionId)
        public
        returns (bool)
    {
        Notice storage n = _known(s, actionId);
        StreamOwnerRecoveryNoticeTypes.Snapshot storage v = n.snapshot;
        if (v.processed == v.responseTail) return false;
        // Writes are possible only while scheduled; EXECUTED is reserved for the exact read callback.
        bytes memory raw = StreamOwnerRecordReads.bounded(
            c.action.executor,
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (actionId)),
            160,
            c.action.readGas
        );
        if (raw.length != 160) revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        IStreamGovernanceActionFacts.ActionFacts memory a =
            abi.decode(raw, (IStreamGovernanceActionFacts.ActionFacts));
        if (keccak256(raw) != keccak256(abi.encode(a))) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        if (
            a.status != GovernanceActionStatus.SCHEDULED
                || !StreamOwnerRecoveryActionReads.eligibility(
                    c.action, v.binding, actionId, v.scope, v.binding.manifestHash
                )
        ) return false;
        bytes32 hash =
            s.candidates[_key(v.scope.tokenId, actionId, v.binding.manifestHash)][v.processed];
        StreamOwnerRecoveryNoticeTypes.Response storage r = s.responses[hash];
        bytes32 predecessor = n.latest[r.author];
        if (predecessor != 0) {
            StreamOwnerRecoveryNoticeTypes.Response storage prior = s.responses[predecessor];
            if (prior.recordIndex >= r.recordIndex) {
                revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
            }
            if (prior.response == StreamOwnerNoticeTypes.ResponseClass.ACKNOWLEDGED) {
                --v.acknowledgements;
            } else {
                --v.objections;
            }
        }
        if (r.response == StreamOwnerNoticeTypes.ResponseClass.ACKNOWLEDGED) ++v.acknowledgements;
        else ++v.objections;
        n.latest[r.author] = hash;
        r.queued = true;
        r.processed = true;
        r.afterMinimumWindow = r.recordedAt >= v.noticeEndsAt;
        ++v.processed;
        ++v.revision;
        v.evidenceHash = keccak256(
            abi.encode(
                UPDATE,
                v.evidenceHash,
                actionId,
                hash,
                predecessor,
                r.author,
                r.response,
                v.processed,
                v.revision,
                v.acknowledgements,
                v.objections
            )
        );
        emit OwnerRecoveryResponseProcessed(
            actionId,
            r.author,
            hash,
            predecessor,
            v.revision,
            v.acknowledgements,
            v.objections,
            v.evidenceHash,
            1
        );
        return true;
    }

    function evidence(
        State storage s,
        Configuration memory c,
        StreamFinalityScope memory scope,
        bytes32 actionId,
        bytes32 manifest
    ) public view returns (bool, bytes32, uint64, uint64, uint32, uint32) {
        StreamOwnerRecoveryNoticeTypes.Snapshot storage v = s.notices[actionId].snapshot;
        if (v.openingOwner == address(0)) return (false, 0, 0, 0, 0, 0);
        bool valid = keccak256(abi.encode(scope)) == keccak256(abi.encode(v.scope))
            && manifest == v.binding.manifestHash && v.processed == v.responseTail
            && block.timestamp >= v.noticeEndsAt
            && StreamOwnerRecoveryActionReads.eligibility(
                c.action, v.binding, actionId, scope, manifest
            );
        return (valid, v.evidenceHash, v.revision, v.noticeEndsAt, v.acknowledgements, v.objections);
    }

    function snapshot(State storage s, bytes32 actionId)
        public
        view
        returns (StreamOwnerRecoveryNoticeTypes.Snapshot memory)
    {
        return _known(s, actionId).snapshot;
    }

    /// @dev Exact typed host return encoding, preserving the same unknown-record guard.
    function encodedSnapshot(State storage s, bytes32 actionId) public view returns (bytes memory) {
        return abi.encode(snapshot(s, actionId));
    }

    function claim(State storage s, bytes32 actionId, uint256 index)
        public
        view
        returns (address pointer, bytes memory originalBytes)
    {
        Notice storage n = _known(s, actionId);
        bytes32 hash;
        if (index == 0) {
            pointer = n.publicationPointer;
            hash = n.publicationBytesHash;
        } else {
            pointer = n.deliveryPointers[index - 1];
            hash = n.deliveryHashes[index - 1];
        }
        return (pointer, _payload(pointer, hash));
    }

    function claimWithPreparation(
        State storage s,
        StreamOwnerRecoveryNoticePreparation.State storage prepared,
        bytes32 actionId,
        uint256 index
    ) public view returns (address pointer, bytes memory originalBytes) {
        bytes32 id = prepared.notices[actionId];
        if (id != 0) return StreamOwnerRecoveryNoticePreparation.claim(prepared, id, index);
        return claim(s, actionId, index);
    }

    function encodedClaim(
        State storage s,
        StreamOwnerRecoveryNoticePreparation.State storage prepared,
        bytes32 actionId,
        uint256 index
    ) public view returns (bytes memory) {
        (address pointer, bytes memory raw) = claimWithPreparation(s, prepared, actionId, index);
        return abi.encode(pointer, raw);
    }

    function encodedResponse(State storage s, bytes32 hash) public view returns (bytes memory) {
        return abi.encode(readResponse(s, hash));
    }

    function readResponse(State storage s, bytes32 hash)
        public
        view
        returns (StreamOwnerRecoveryNoticeTypes.Response memory r)
    {
        r = s.responses[hash];
        if (r.author == address(0)) {
            revert IStreamOwnerRecoveryNotices.OwnerRecoveryResponseUnknown(hash);
        }
        StreamOwnerRecoveryNoticeTypes.Snapshot storage n = s.notices[r.actionId].snapshot;
        r.queued = n.openingOwner != address(0) && n.scope.tokenId == r.tokenId
            && n.binding.manifestHash == r.manifestHash;
        r.afterMinimumWindow = r.queued && r.recordedAt >= n.noticeEndsAt;
    }

    function responseAt(State storage s, bytes32 actionId, uint256 index)
        public
        view
        returns (bytes32)
    {
        StreamOwnerRecoveryNoticeTypes.Snapshot storage n = _known(s, actionId).snapshot;
        return s.candidates[_key(n.scope.tokenId, actionId, n.binding.manifestHash)][index];
    }

    function latest(State storage s, bytes32 actionId, address author)
        public
        view
        returns (bytes32)
    {
        return _known(s, actionId).latest[author];
    }

    function _known(State storage s, bytes32 actionId) private view returns (Notice storage n) {
        n = s.notices[actionId];
        if (n.snapshot.openingOwner == address(0)) {
            revert IStreamOwnerRecoveryNotices.OwnerRecoveryNoticeUnknown(actionId);
        }
    }

    function _key(uint256 token, bytes32 action, bytes32 manifest) private pure returns (bytes32) {
        return keccak256(abi.encode(token, action, manifest));
    }

    function _steward(OriginalOwner memory owner, StreamOwnerNoticeTypes.Designation memory d)
        private
        pure
    {
        if (owner.stewardRecordHash == 0) {
            StreamOwnerNoticeTypes.Designation memory empty;
            if (
                owner.stewardPayloadHash != 0
                    || keccak256(abi.encode(d)) != keccak256(abi.encode(empty))
            ) {
                revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
            }
        } else if (keccak256(StreamStewardDesignationJson.serialize(d)) != owner.stewardPayloadHash)
        {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
    }

    function _token(
        StreamOwnerRecoveryActionReads.Config memory c,
        StreamFinalityScope memory scope
    ) private view {
        bytes memory raw = StreamOwnerRecordReads.bounded(
            c.core,
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (scope.tokenId)),
            128,
            c.readGas
        );
        if (raw.length != 128) revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        if (
            !exists || burned || collection != scope.collectionId || serial == 0
                || keccak256(raw) != keccak256(abi.encode(exists, collection, serial, burned))
        ) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
    }

    /// @dev Same accepted reference shape as referenceJSON, without constructing discarded JSON.
    function _reference(StreamOwnerNoticeTypes.Reference memory r) private pure {
        if (r.canonicalizationId == 0 || r.algorithm == 0 || r.algorithm > 6) {
            revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        }
        if (r.algorithm == 4 || r.algorithm == 5) {
            if (r.digest.length == 0 || r.digest.length > 128) {
                revert StreamOwnerNoticeFields.InvalidNoticeWitness();
            }
        } else if (r.digest.length != 32) {
            revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        }
        // This already checks nonempty, maximum bytes and UTF8; quote adds no admission rule.
        StreamMetadataRenderer.requireValidUtf8ContentUri("NOTICE_REFERENCE", r.uri, 2048, false);
    }

    function _publish(Configuration memory c, bytes memory raw) private returns (address pointer) {
        StreamOwnerRecordReads.requireCode(c.store, c.storeCodeHash);
        if (raw.length > 8192) revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        bytes32 hash;
        (hash, pointer) = StreamSchemaDocumentStore(c.store).publishChunk(raw);
        if (hash != keccak256(raw) || pointer.code.length != raw.length + 1) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
    }

    function _payload(address pointer, bytes32 hash) private view returns (bytes memory raw) {
        if (pointer.code.length == 0 || pointer.code.length > 8193) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
        raw = SSTORE2.read(pointer);
        if (keccak256(raw) != hash) {
            revert IStreamOwnerRecoveryNotices.InvalidOwnerRecoveryNotice();
        }
    }
}
