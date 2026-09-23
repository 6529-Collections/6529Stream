// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamC2PAConflicts as S
} from "../../../smart-contracts/domains/metadata/StreamC2PAConflicts.sol";
import {
    IStreamC2PAConflicts as C
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";
import {
    IStreamC2PAReconciliation as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArchivalTypes as A
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";

interface ConflictStateVm {
    function expectRevert() external;
    function warp(uint256) external;
}

/// @dev Explicit typed source boundary, not an Artist/governance/archival implementation.
contract ConflictDispositionBoundary {
    AD.Resolution private resolution;
    AD.Head private head;
    AD.Record private opening;
    bool public refuse;

    function set(AD.Resolution memory r, AD.Head memory h, AD.Record memory o) external {
        resolution = r;
        head = h;
        opening = o;
    }

    function setRefuse(bool value) external {
        refuse = value;
    }

    function attributionDisputeResolution(bytes32) external view returns (AD.Resolution memory) {
        return resolution;
    }

    function attributionDispute(uint256, uint64) external view returns (AD.Head memory) {
        return head;
    }

    function attributionDisputeRecord(bytes32) external view returns (AD.Record memory) {
        return opening;
    }

    function archivalCoverage() external view returns (address) {
        return address(this);
    }

    function archivalCoverageCodeHash() external view returns (bytes32) {
        return address(this).codehash;
    }

    function requireCollectionEvidence(uint256, bytes32 evidence)
        external
        view
        returns (A.CoverageFacts memory f)
    {
        require(!refuse);
        f.evidenceHash = evidence;
        f.coverageRecordHash = keccak256("typed coverage");
        f.envelopeHash = keccak256("typed envelope");
    }
}

/// @notice Actual fixed-library storage, retained Store bytes and bounded reads with typed authority facts.
/// Does not demonstrate original op46 authority or a genuine archival provider; the Artist suite does that separately.
contract StreamC2PAConflictStateTest {
    ConflictStateVm constant vm =
        ConflictStateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    S.Store private state;
    StreamSchemaDocumentStore private chunks;
    ConflictDispositionBoundary private source;
    S.Environment private environment;
    bytes32 private constant SUBJECT = keccak256("subject");

    function setUp() public {
        vm.warp(100);
        chunks = new StreamSchemaDocumentStore();
        source = new ConflictDispositionBoundary();
        environment = S.Environment(
            block.chainid, address(1), address(source), address(source), address(chunks), 300000
        );
    }

    function acknowledge(bytes32 id, bytes32 action) external {
        require(msg.sender == address(this));
        S.clear(state, environment, id, action);
    }

    function _note(uint256 sequence) private returns (bytes32) {
        R.Selection memory p;
        p.report.collectionId = 1;
        p.report.subjectId = SUBJECT;
        p.report.artistId = keccak256("artist");
        p.report.bindingHash = keccak256("binding");
        p.report.generation = 1;
        p.report.assertsAuthorship = true;
        p.report.authorship = R.AuthorshipStatus.DIVERGENT;
        p.recordHash = keccak256(abi.encode("record", sequence));
        p.selectionHash = keccak256(abi.encode("selection", sequence));
        S.note(state, environment.core, environment.artist, p);
        return state.heads[keccak256(abi.encode(uint256(1), SUBJECT))].latest;
    }

    function _prepare(bytes32 id, bytes memory narrative) private returns (bytes32 action) {
        C.Conflict memory c = state.records[id];
        (bytes32 nh,) = chunks.publishChunk(narrative);
        AD.Record memory o;
        o.recordHash = keccak256(abi.encode("opening", id));
        o.terms.collectionId = 1;
        o.terms.bindingGeneration = 1;
        o.terms.disputeAction = 1;
        o.bindingHash = c.bindingHash;
        o.artistId = c.artistId;
        (bytes32 evidence,) =
            chunks.publishChunk(abi.encode(AD.Evidence(1, 1, 1, c.bindingHash, o.recordHash, nh)));
        action = keccak256(abi.encode("action", id));
        AD.Resolution memory r;
        r.terms = AD.ResolutionRequest(1, 1, o.recordHash, 1, evidence, evidence, 0);
        r.actionId = action;
        r.actor = address(2);
        r.proposer = address(3);
        r.actionClass = 1;
        r.resolvedAt = uint64(block.timestamp);
        r.witnessHash = keccak256("witness");
        AD.Head memory h;
        h.disputeRecordHash = o.recordHash;
        h.resolutionActionId = action;
        source.set(r, h, o);
    }

    function _exact(bytes32 id) private view returns (bytes memory) {
        return S.narrative(environment, state.records[id]);
    }

    function _head() private view returns (S.Head memory) {
        return state.heads[keccak256(abi.encode(uint256(1), SUBJECT))];
    }

    function testInteriorAndTailClearsKeepImmutableHistoryAndRemainingVisibility() public {
        bytes32 first = _note(1);
        bytes32 middle = _note(2);
        bytes32 last = _note(3);
        bytes32 chain = _head().chain;
        this.acknowledge(middle, _prepare(middle, _exact(middle)));
        require(_head().tail == last && _head().openCount == 2);
        require(state.links[first].next == last && state.links[last].previous == first);
        this.acknowledge(last, _prepare(last, _exact(last)));
        require(_head().tail == first && _head().openCount == 1);
        this.acknowledge(first, _prepare(first, _exact(first)));
        require(
            _head().tail == 0 && _head().openCount == 0 && _head().revision == 3
                && _head().chain == chain
        );
        require(
            state.records[last].previousConflict == middle
                && state.records[middle].previousConflict == first
        );
        require(state.history[keccak256(abi.encode(uint256(1), SUBJECT))][2] == middle);
        bytes32 fresh = _note(4);
        require(_head().tail == fresh && _head().openCount == 1 && state.links[fresh].previous == 0);
        require(state.records[fresh].previousConflict == last && state.records[fresh].revision == 4);
    }

    function testLateReadRefusalLeavesEveryConflictCellAndExactRetryIntact() public {
        bytes32 first = _note(1);
        bytes32 last = _note(2);
        bytes32 action = _prepare(last, _exact(last));
        bytes32 beforeHash = keccak256(
            abi.encode(_head(), state.links[first], state.links[last], state.resolutions[last])
        );
        source.setRefuse(true);
        vm.expectRevert();
        this.acknowledge(last, action);
        require(
            beforeHash
                == keccak256(
                    abi.encode(
                        _head(), state.links[first], state.links[last], state.resolutions[last]
                    )
                )
        );
        source.setRefuse(false);
        this.acknowledge(last, action);
        require(
            _head().tail == first && _head().openCount == 1
                && state.resolutions[last].actionId == action
        );
        vm.expectRevert();
        this.acknowledge(last, action);
    }

    function testRehashedNarrativeForForeignChainCannotClearExactConflict() public {
        bytes32 id = _note(1);
        bytes memory wrong = _exact(id);
        uint256 foreignChain = block.chainid + 1;
        assembly ("memory-safe") { mstore(add(wrong, 64), foreignChain) }
        bytes32 action = _prepare(id, wrong);
        vm.expectRevert();
        this.acknowledge(id, action);
        require(_head().tail == id && _head().openCount == 1 && state.resolutions[id].actionId == 0);
        this.acknowledge(id, _prepare(id, _exact(id)));
        require(_head().openCount == 0);
    }
}
