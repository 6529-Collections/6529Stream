// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamOwnerPreparedRecoveryNotices.sol";
import "./StreamOwnerRecordBook.sol";
import "./StreamStewardDesignationJson.sol";

/// @notice Immutable publication pieces; an entire preparation is not a recovery notice.
/// @dev Explicit host storage references and the caller's shared guard protect every mutation.
library StreamOwnerRecoveryNoticePreparation {
    struct Configuration {
        address core;
        bytes32 coreCodeHash;
        address store;
        bytes32 storeCodeHash;
        uint256 readGas;
    }

    struct Plan {
        StreamOwnerPreparedNoticeTypes.Snapshot snapshot;
        address basePointer;
        bytes32 baseHash;
        address[] deliveryPointers;
        bytes32[] deliveryHashes;
    }

    struct State {
        mapping(bytes32 => Plan) plans;
        mapping(bytes32 => bytes32) notices;
    }

    event OwnerRecoveryNoticePreparing(
        bytes32 indexed preparationId,
        bytes32 indexed actionId,
        address indexed publisher,
        uint256 tokenId,
        address openingOwner,
        bytes32 stewardRecordHash,
        uint64 deliveryCount,
        uint16 schemaVersion
    );
    event OwnerRecoveryNoticeDeliveryPrepared(
        bytes32 indexed preparationId,
        uint64 indexed deliveryIndex,
        bytes32 claimHash,
        address claimPointer,
        bool complete,
        uint16 schemaVersion
    );

    bytes32 private constant PREPARATION = keccak256("6529STREAM_OWNER_NOTICE_PREPARATION_V1");
    bytes32 private constant ENDPOINTS = keccak256("6529STREAM_OWNER_NOTICE_ENDPOINTS_V1");

    function begin(
        State storage state,
        mapping(uint256 => mapping(address => bytes32)) storage stewards,
        mapping(
            bytes32 => StreamOwnerRecordBook.Stored
        ) storage records,
        Configuration memory c,
        StreamOwnerPreparedNoticeTypes.Input memory input
    ) public returns (bytes32 id) {
        if (input.tokenId == 0 || input.actionId == 0 || block.timestamp > type(uint64).max) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        address owner =
            StreamOwnerRecordReads.owner(c.core, c.coreCodeHash, input.tokenId, c.readGas);
        bytes32 head = stewards[input.tokenId][owner];
        bytes32 payloadHash = records[head].payloadHash;
        if (head == 0) {
            StreamOwnerNoticeTypes.Designation memory empty;
            if (
                payloadHash != 0
                    || keccak256(abi.encode(input.steward)) != keccak256(abi.encode(empty))
            ) {
                revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
            }
        } else if (keccak256(_authenticatedDesignation(input.steward)) != payloadHash) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        _reference(input.runbook);
        _reference(input.publicNotice);
        bytes memory raw = abi.encode(input.runbook, input.publicNotice);
        bytes32 baseHash = keccak256(raw);
        id = keccak256(
            abi.encode(
                PREPARATION,
                block.chainid,
                address(this),
                msg.sender,
                input.nonce,
                input.tokenId,
                input.actionId,
                owner,
                head,
                baseHash
            )
        );
        Plan storage plan = state.plans[id];
        if (plan.snapshot.publisher != address(0)) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        StreamOwnerPreparedNoticeTypes.Snapshot storage p = plan.snapshot;
        p.tokenId = input.tokenId;
        p.actionId = input.actionId;
        p.publisher = msg.sender;
        p.openingOwner = owner;
        p.stewardRecordHash = head;
        p.stewardPayloadHash = payloadHash;
        p.deliveryCount = uint64(input.steward.contactEndpoints.length + 1);
        p.preparedAt = uint64(block.timestamp);
        p.endpointHash = ENDPOINTS;
        StreamOwnerNoticeTypes.Contact memory endpoint = StreamOwnerNoticeTypes.Contact(
            StreamOwnerNoticeTypes.ContactKind.EIP155, "", block.chainid, owner
        );
        // The owner endpoint is additional to the already validated full designation.
        StreamOwnerNoticeFields.contact(endpoint);
        bytes32 expected = _nextEndpoint(ENDPOINTS, 0, endpoint);
        for (uint256 i; i < input.steward.contactEndpoints.length; ++i) {
            expected = _nextEndpoint(expected, i + 1, input.steward.contactEndpoints[i]);
        }
        p.expectedEndpointHash = expected;
        p.publicationHash = baseHash;
        plan.baseHash = baseHash;
        plan.basePointer = _publish(c, raw);
        emit OwnerRecoveryNoticePreparing(
            id, input.actionId, msg.sender, input.tokenId, owner, head, p.deliveryCount, 1
        );
    }

    function append(
        State storage state,
        Configuration memory c,
        bytes32 id,
        StreamOwnerRecoveryNoticeTypes.Delivery memory delivery
    ) public {
        Plan storage plan = _known(state, id);
        StreamOwnerPreparedNoticeTypes.Snapshot storage p = plan.snapshot;
        if (msg.sender != p.publisher) {
            revert IStreamOwnerPreparedRecoveryNotices.OwnerNoticePreparationPublisherRequired(msg.sender);
        }
        if (
            p.complete || p.consumed || p.preparedCount >= p.deliveryCount
                || bytes(delivery.endpoint.uri).length > 2048
        ) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        _reference(delivery.evidence);
        uint64 index = p.preparedCount;
        bytes32 next = _nextEndpoint(p.endpointHash, index, delivery.endpoint);
        bool complete = index + 1 == p.deliveryCount;
        // No endpoint is silently accepted: the completed ordered tuple set must be exact.
        if (complete && next != p.expectedEndpointHash) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        bytes memory raw = abi.encode(delivery);
        bytes32 hash = keccak256(raw);
        address pointer = _publish(c, raw);
        plan.deliveryPointers.push(pointer);
        plan.deliveryHashes.push(hash);
        p.endpointHash = next;
        p.publicationHash = keccak256(abi.encode(p.publicationHash, uint256(index), hash));
        ++p.preparedCount;
        p.complete = complete;
        emit OwnerRecoveryNoticeDeliveryPrepared(id, index, hash, pointer, complete, 1);
    }

    /// @dev Called only inside final opening's atomic frame; any later admission failure rolls back use.
    function consume(
        State storage state,
        mapping(uint256 => mapping(address => bytes32)) storage stewards,
        Configuration memory c,
        bytes32 id
    ) public returns (StreamOwnerPreparedNoticeTypes.Snapshot memory result) {
        StreamOwnerPreparedNoticeTypes.Snapshot storage p = _known(state, id).snapshot;
        if (
            !p.complete || p.consumed || p.preparedCount != p.deliveryCount
                || p.endpointHash != p.expectedEndpointHash || state.notices[p.actionId] != 0
        ) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        address current = StreamOwnerRecordReads.owner(c.core, c.coreCodeHash, p.tokenId, c.readGas);
        if (current != p.openingOwner || stewards[p.tokenId][current] != p.stewardRecordHash) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        p.consumed = true;
        state.notices[p.actionId] = id;
        return p;
    }

    function encodedSnapshot(State storage state, bytes32 id) public view returns (bytes memory) {
        return abi.encode(_known(state, id).snapshot);
    }

    function claim(State storage state, bytes32 id, uint256 index)
        public
        view
        returns (address pointer, bytes memory raw)
    {
        Plan storage p = _known(state, id);
        bytes32 hash;
        if (index == 0) {
            pointer = p.basePointer;
            hash = p.baseHash;
        } else {
            pointer = p.deliveryPointers[index - 1];
            hash = p.deliveryHashes[index - 1];
        }
        if (pointer.code.length == 0 || pointer.code.length > 8193 || pointer.code[0] != 0) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        raw = SSTORE2.read(pointer);
        if (keccak256(raw) != hash) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
    }

    function encodedClaim(State storage state, bytes32 id, uint256 index)
        public
        view
        returns (bytes memory)
    {
        (address pointer, bytes memory raw) = claim(state, id, index);
        return abi.encode(pointer, raw);
    }

    function _known(State storage state, bytes32 id) private view returns (Plan storage plan) {
        plan = state.plans[id];
        if (plan.snapshot.publisher == address(0)) {
            revert IStreamOwnerPreparedRecoveryNotices.OwnerNoticePreparationUnknown(id);
        }
    }

    function _nextEndpoint(
        bytes32 previous,
        uint256 index,
        StreamOwnerNoticeTypes.Contact memory endpoint
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(previous, index, keccak256(abi.encode(endpoint))));
    }

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
        StreamMetadataRenderer.requireValidUtf8ContentUri("NOTICE_REFERENCE", r.uri, 2048, false);
    }

    /// @dev Only used against the complete immutable payload hash of the host's typed steward head.
    /// Original admission already proved endpoint uniqueness. Every tuple field is validated again,
    /// and duplicate/reordered rows cannot match those original canonical bytes.
    function _authenticatedDesignation(StreamOwnerNoticeTypes.Designation memory d)
        private
        pure
        returns (bytes memory)
    {
        if (d.subjectId == 0 || d.profileHash == 0 || d.contactEndpoints.length == 0) {
            revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        }
        string memory contacts = "[";
        for (uint256 i; i < d.contactEndpoints.length; ++i) {
            contacts = string.concat(
                contacts, i == 0 ? "" : ",", StreamOwnerNoticeFields.contact(d.contactEndpoints[i])
            );
            if (bytes(contacts).length > 8192) {
                revert StreamOwnerNoticeFields.InvalidNoticeWitness();
            }
        }
        string memory out = string.concat(
            '{"contactEndpoints":',
            contacts,
            '],"predecessor":',
            d.predecessor == 0 ? "null" : StreamRecordJson.hexValue(d.predecessor),
            ',"profileHash":',
            StreamRecordJson.hexValue(d.profileHash)
        );
        out = string.concat(
            out,
            ',"steward":{"identity":',
            StreamOwnerNoticeFields.referenceJSON(d.identity),
            ',"kind":',
            d.kind == StreamOwnerNoticeTypes.StewardKind.INSTITUTION
                ? '"institution"'
                : '"registrar_contact"',
            ',"name":',
            StreamRecordJson.quote(d.name, 512, false),
            '},"subjectId":',
            StreamRecordJson.hexValue(d.subjectId),
            ',"version":1}'
        );
        if (bytes(out).length > 8192) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        return bytes(out);
    }

    function _publish(Configuration memory c, bytes memory raw) private returns (address pointer) {
        StreamOwnerRecordReads.requireCode(c.store, c.storeCodeHash);
        if (raw.length > 8192) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
        bytes32 hash;
        (hash, pointer) = StreamSchemaDocumentStore(c.store).publishChunk(raw);
        if (hash != keccak256(raw) || pointer.code.length != raw.length + 1) {
            revert IStreamOwnerPreparedRecoveryNotices.InvalidOwnerNoticePreparation();
        }
    }
}
