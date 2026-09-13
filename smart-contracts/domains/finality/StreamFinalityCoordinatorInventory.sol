// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../metadata/StreamMetadataSubjects.sol";

/// @notice Indexes every member's retained Core coordinator and first-occurrence source order.
/// @dev Permissionless transport of actual source facts; no caller token lists or readiness flags.
contract StreamFinalityCoordinatorInventory is IStreamFinalityCoordinatorInventory, IERC165 {
    address public immutable override core;
    address public immutable override scopeMembershipHost;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable scopeMembershipCodeHash;
    uint256 public immutable deploymentChainId;
    uint32 public immutable readGas;
    uint32 public immutable membershipGas;
    uint256 public constant MAX_BATCH = 256;

    struct State {
        StreamFinalityScope scope;
        StreamScopeMembershipFacts facts;
        Progress progress;
        Coordinator[] coordinators;
        mapping(address => uint256) positions;
    }
    mapping(bytes32 => State) private _plans;

    error InventoryConfiguration();
    error InventoryDependency(address target);
    error InventoryRead(address target, bytes4 selector);
    error InventoryParentGas(uint256 required);
    error InventoryUnknown(bytes32 planId);
    error InventoryStale(bytes32 planId);
    error InventoryIncomplete(bytes32 planId);
    error InventoryBatch(uint256 maximumTokens);
    error InventoryToken(uint256 tokenId);
    error InventoryIndex(uint256 index);

    constructor(address core_, address membership_, uint32 readGas_, uint32 membershipGas_) {
        if (
            core_.code.length == 0 || membership_.code.length == 0 || readGas_ < 50000
                || membershipGas_ < readGas_
        ) {
            revert InventoryConfiguration();
        }
        core = core_;
        scopeMembershipHost = membership_;
        coreCodeHash = core_.codehash;
        scopeMembershipCodeHash = membership_.codehash;
        deploymentChainId = block.chainid;
        readGas = readGas_;
        membershipGas = membershipGas_;
        if (
            abi.decode(
                    _read(
                        membership_,
                        abi.encodeCall(IStreamFinalityScopeMembership.core, ()),
                        32,
                        readGas_
                    ),
                    (address)
                ) != core_
        ) {
            revert InventoryConfiguration();
        }
        _supports(core_, 0x80ac58cd);
        _supports(membership_, type(IStreamFinalityScopeMembership).interfaceId);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityCoordinatorInventory).interfaceId;
    }

    function beginInventory(StreamFinalityScope calldata scope)
        external
        override
        returns (bytes32 id)
    {
        _pins();
        StreamScopeMembershipFacts memory facts = _facts(scope);
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_COORDINATOR_INVENTORY_PLAN_V1"),
                deploymentChainId,
                address(this),
                core,
                coreCodeHash,
                scopeMembershipHost,
                scopeMembershipCodeHash,
                scope,
                facts
            )
        );
        State storage s = _plans[id];
        if (s.progress.exists) return id;
        s.scope = scope;
        s.facts = facts;
        s.progress.exists = true;
        s.progress.tokenCount = facts.tokenCount;
        s.progress.tokenChain =
            keccak256(abi.encode(keccak256("6529STREAM_COORDINATOR_TOKEN_CHAIN_V1"), id));
        s.progress.coordinatorChain =
            keccak256(abi.encode(keccak256("6529STREAM_COORDINATOR_SOURCE_CHAIN_V1"), id));
        emit CoordinatorInventoryBegun(id, facts.scopeSubject, facts.tokenCount);
        if (facts.tokenCount == 0) _complete(id, s);
    }

    function appendInventory(bytes32 id, uint256 maximumTokens) external override {
        _pins();
        State storage s = _known(id);
        if (maximumTokens == 0 || maximumTokens > MAX_BATCH || s.progress.complete) {
            revert InventoryBatch(maximumTokens);
        }
        _current(id, s);
        uint256 remaining = s.progress.tokenCount - s.progress.processedTokens;
        uint256 end =
            s.progress.processedTokens + (maximumTokens < remaining ? maximumTokens : remaining);
        for (uint256 i = s.progress.processedTokens; i < end; ++i) {
            _append(id, s, i);
        }
        s.progress.processedTokens = end;
        emit CoordinatorInventoryProgressed(id, end, s.coordinators.length);
        if (end == s.progress.tokenCount) _complete(id, s);
    }

    function inventoryProgress(bytes32 id) external view override returns (Progress memory) {
        return _plans[id].progress;
    }

    function inventoryScope(bytes32 id)
        external
        view
        override
        returns (StreamFinalityScope memory, StreamScopeMembershipFacts memory)
    {
        State storage s = _known(id);
        return (s.scope, s.facts);
    }

    function coordinatorAt(bytes32 id, uint256 index)
        public
        view
        override
        returns (Coordinator memory)
    {
        State storage s = _known(id);
        if (index >= s.coordinators.length) revert InventoryIndex(index);
        return s.coordinators[index];
    }

    function requireCompleteInventory(bytes32 id) external view override returns (Progress memory) {
        _pins();
        State storage s = _known(id);
        _current(id, s);
        if (
            !s.progress.complete || s.progress.processedTokens != s.facts.tokenCount
                || s.progress.commitment == 0
                || s.progress.coordinatorCount != s.coordinators.length
        ) revert InventoryIncomplete(id);
        return s.progress;
    }

    function requireCoordinator(bytes32 id, uint256 index)
        external
        view
        override
        returns (Coordinator memory c)
    {
        _pins();
        c = coordinatorAt(id, index);
        if (c.coordinator.code.length == 0 || c.coordinator.codehash != c.indexedCodeHash) {
            revert InventoryDependency(c.coordinator);
        }
    }

    function _append(bytes32 id, State storage s, uint256 index) private {
        uint256 tokenId = abi.decode(
            _read(
                scopeMembershipHost,
                abi.encodeCall(IStreamFinalityScopeMembership.scopeTokenAt, (s.scope, index)),
                32,
                membershipGas
            ),
            (uint256)
        );
        (uint256 exists, uint256 cid, uint256 serial, uint256 burned) = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)),
                128,
                readGas
            ),
            (uint256, uint256, uint256, uint256)
        );
        uint256 life = abi.decode(
            _read(core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)), 32, readGas),
            (uint256)
        );
        if (
            tokenId == 0 || exists != 1 || cid != s.scope.collectionId || serial == 0
                || !((life == 2 && burned == 0) || (life == 3 && burned == 1))
        ) revert InventoryToken(tokenId);
        address original = abi.decode(
            _read(
                core, abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (tokenId)), 32, readGas
            ),
            (address)
        );
        if (original.code.length == 0) revert InventoryDependency(original);
        uint256 position = s.positions[original];
        if (position == 0) {
            Coordinator memory c = Coordinator(original, original.codehash, index);
            position = s.coordinators.length + 1;
            s.positions[original] = position;
            s.coordinators.push(c);
            s.progress.coordinatorCount = position;
            s.progress.coordinatorChain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_COORDINATOR_SOURCE_APPEND_V1"),
                    s.progress.coordinatorChain,
                    position - 1,
                    c
                )
            );
            emit OriginalCoordinatorIndexed(id, position - 1, original, c.indexedCodeHash, index);
        } else if (s.coordinators[position - 1].indexedCodeHash != original.codehash) {
            revert InventoryDependency(original);
        }
        s.progress.tokenChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_COORDINATOR_TOKEN_APPEND_V1"),
                s.progress.tokenChain,
                index,
                tokenId,
                original,
                position - 1
            )
        );
    }

    function _complete(bytes32 id, State storage s) private {
        s.progress.complete = true;
        s.progress.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1"),
                id,
                s.progress.tokenCount,
                s.coordinators.length,
                s.progress.tokenChain,
                s.progress.coordinatorChain
            )
        );
        emit CoordinatorInventoryCompleted(id, s.progress.commitment);
    }

    function _facts(StreamFinalityScope memory scope)
        private
        view
        returns (StreamScopeMembershipFacts memory facts)
    {
        bytes32 subject = StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
        bytes memory raw = _read(
            scopeMembershipHost,
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
            256,
            membershipGas
        );
        facts = abi.decode(raw, (StreamScopeMembershipFacts));
        if (
            facts.scopeSubject != subject || facts.membershipHash == 0
                || keccak256(raw) != keccak256(abi.encode(facts))
        ) {
            revert InventoryConfiguration();
        }
    }

    function _current(bytes32 id, State storage s) private view {
        if (keccak256(abi.encode(_facts(s.scope))) != keccak256(abi.encode(s.facts))) {
            revert InventoryStale(id);
        }
    }

    function _known(bytes32 id) private view returns (State storage s) {
        s = _plans[id];
        if (!s.progress.exists) revert InventoryUnknown(id);
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) revert InventoryConfiguration();
        if (core.code.length == 0 || core.codehash != coreCodeHash) {
            revert InventoryDependency(core);
        }
        if (
            scopeMembershipHost.code.length == 0
                || scopeMembershipHost.codehash != scopeMembershipCodeHash
        ) revert InventoryDependency(scopeMembershipHost);
    }

    function _supports(address target, bytes4 id) private view {
        if (
            abi.decode(
                        _read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, readGas),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            readGas
                        ),
                        (uint256)
                    ) != 0
        ) {
            revert InventoryDependency(target);
        }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory out)
    {
        out = new bytes(size);
        uint256 required = cap + cap / 63 + 10000;
        if (gasleft() <= required) revert InventoryParentGas(required);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert InventoryRead(target, bytes4(input));
    }
}
