// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamEntropyRenderPolicyReads as Explicit
} from "../entropy/StreamEntropyRenderPolicyReads.sol";
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventorySerialLookup.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../metadata/StreamMetadataRecoveryRoutes.sol";

/// @notice Immutable complete source-set adapter and token-aware entropy resolver.
/// @dev Construction admits an actual complete, nonempty inventory with every native policy locked.
/// Every finality read revalidates every retained native policy. Serving never substitutes the
/// current entropy pointer. It preserves one unambiguous ENTROPY_COORDINATOR recovery route.
contract StreamFinalityEntropyPolicySourceSet is IStreamFinalityEntropyPolicySourceSet {
    address public immutable override factory;
    address public immutable override core;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override inventoryPlan;
    bytes32 public immutable override originalInventoryHash;
    bytes32 public immutable override originalPolicyChainHash;
    address public immutable tokenInventory;
    bytes32 public immutable tokenInventoryCodeHash;
    bytes32 public immutable sourceSetManifestHash;
    bytes32 public immutable sourceSetDataHash;
    bytes32 public constant SOURCE_SET_PROFILE =
        keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2");
    StreamFinalityCoordinatorPolicyReadsV2.Dependencies private _dependencies;
    StreamFinalityScope private _scope;
    StreamScopeMembershipFacts private _membership;
    StreamFinalityCoordinatorPolicyV2[] private _policies;
    mapping(address => uint256) private _positions;
    error SourceSetEvidence();
    error SourceSetScope();
    error SourceSetToken(uint256 tokenId);
    error SourceSetDependency(address target);
    error SourceSetIndex(uint256 index);

    constructor(
        StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 plan
    ) {
        StreamFinalityCoordinatorPolicyEvidenceV2 memory e =
            StreamFinalityCoordinatorPolicyReadsV2.requireCurrent(d, scope, plan);
        if (!e.allFrozen || e.policyCount == 0) revert SourceSetEvidence();
        factory = msg.sender;
        core = d.targets[0];
        coreCodeHash = d.codeHashes[0];
        _dependencies = d;
        _scope = scope;
        inventoryPlan = plan;
        originalInventoryHash = e.inventoryHash;
        originalPolicyChainHash = e.policyChainHash;
        (, StreamScopeMembershipFacts memory f) = abi.decode(
            _read(
                d.targets[3],
                abi.encodeCall(IStreamFinalityCoordinatorInventory.inventoryScope, (plan)),
                384,
                d.readGas
            ),
            (StreamFinalityScope, StreamScopeMembershipFacts)
        );
        _membership = f;
        address inventory = abi.decode(
            _read(
                d.targets[2],
                abi.encodeCall(IStreamFinalityScopeMembership.tokenInventory, ()),
                32,
                d.readGas
            ),
            (address)
        );
        if (
            inventory.code.length == 0
                || abi.decode(
                        _read(inventory, abi.encodeWithSignature("core()"), 32, d.readGas),
                        (address)
                    ) != core
        ) {
            revert SourceSetDependency(inventory);
        }
        tokenInventory = inventory;
        tokenInventoryCodeHash = inventory.codehash;
        for (uint256 i; i < e.policyCount; ++i) {
            if (_positions[e.policies[i].coordinator] != 0) revert SourceSetEvidence();
            _positions[e.policies[i].coordinator] = i + 1;
            _policies.push(e.policies[i]);
        }
        sourceSetManifestHash =
            keccak256(abi.encode(SOURCE_SET_PROFILE, d, inventory, inventory.codehash));
        sourceSetDataHash = keccak256(
            abi.encode(
                SOURCE_SET_PROFILE,
                scope,
                plan,
                e.inventoryHash,
                e.policyChainHash,
                f,
                inventory,
                inventory.codehash
            )
        );
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamFinalityHostAdapter).interfaceId
            || id == type(IStreamFinalityEntropyPolicySourceSet).interfaceId
            || id == type(IStreamArtworkFinalityComponent).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId;
    }

    function host() external view override returns (address) {
        return address(this);
    }

    function hostCodeHash() external view override returns (bytes32) {
        return address(this).codehash;
    }

    function componentType() public pure override returns (bytes32) {
        return StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR;
    }

    function hostPointerType() external pure override returns (bytes32) {
        return componentType();
    }

    function sourceScope() external view override returns (StreamFinalityScope memory) {
        return _scope;
    }

    function scopeMembershipFacts()
        external
        view
        override
        returns (StreamScopeMembershipFacts memory)
    {
        return _membership;
    }

    function sourceCount() external view override returns (uint256) {
        return _policies.length;
    }

    function sourcePolicyAt(uint256 index)
        external
        view
        override
        returns (StreamFinalityCoordinatorPolicyV2 memory)
    {
        if (index >= _policies.length) revert SourceSetIndex(index);
        return _policies[index];
    }

    function requireCurrentSourceSet() public view override {
        _pins();
        StreamFinalityCoordinatorPolicyEvidenceV2 memory e =
            StreamFinalityCoordinatorPolicyReadsV2.requireCurrent(
                _dependencies, _scope, inventoryPlan
            );
        if (
            !e.allFrozen || e.inventoryHash != originalInventoryHash
                || e.policyChainHash != originalPolicyChainHash || e.policyCount != _policies.length
        ) {
            revert SourceSetEvidence();
        }
    }

    function requireCurrentSelection() external view override {
        requireCurrentSourceSet();
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("COLLECTION_METADATA"),
            _dependencies.targets[1],
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
    }

    function finalityState(uint256 collectionId)
        external
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        return _state(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0));
    }

    function finalityStateForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        return _state(scope);
    }

    function _state(StreamFinalityScope memory scope)
        private
        view
        returns (StreamFinalityComponentState memory)
    {
        if (keccak256(abi.encode(scope)) != keccak256(abi.encode(_scope))) {
            revert SourceSetScope();
        }
        _pins();
        for (uint256 i; i < _policies.length; ++i) {
            _policy(i);
        }
        return StreamFinalityComponentState(
            true,
            componentType(),
            address(this),
            scope.scopeType == StreamFinalityScopeType.COLLECTION
                ? type(IStreamArtworkFinalityComponent).interfaceId
                : type(IStreamArtworkScopedFinalityComponent).interfaceId,
            address(this).codehash,
            SOURCE_SET_PROFILE,
            sourceSetManifestHash,
            sourceSetDataHash
        );
    }

    /// @dev Terminal != finalized. No compatibility tokenSeedForFinality entry is exposed.
    function tokenEntropyReadiness(uint256 tokenId)
        external
        view
        override
        returns (TokenReadiness memory t)
    {
        _pins();
        _covered(tokenId);
        t.coordinator = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (tokenId)),
                32,
                _dependencies.readGas
            ),
            (address)
        );
        uint256 position = _positions[t.coordinator];
        if (position == 0) revert SourceSetToken(tokenId);
        _policy(position - 1);
        StreamFinalityCoordinatorPolicyV2 storage p = _policies[position - 1];
        t.coordinatorCodeHash = p.indexedCodeHash;
        t.policyHash = p.policyHash;
        t.mode = p.explicitPolicy ? p.collectionPolicy.mode : 2;
        t.securityClass = p.explicitPolicy ? p.collectionPolicy.securityClass : 0;
        t.renderRequirement = p.explicitPolicy ? p.collectionPolicy.renderRequirement : 0;
        t.status = abi.decode(
            _read(
                t.coordinator,
                abi.encodeWithSignature("tokenEntropyStatus(uint256)", tokenId),
                32,
                _dependencies.readGas
            ),
            (uint8)
        );
        if (t.status > 7) revert SourceSetToken(tokenId);
        if (t.status == 1 || t.status == 2) {
            if (!p.explicitPolicy) revert SourceSetToken(tokenId);
            P.Terminal memory actual =
                Explicit.terminal(core, tokenId, _scope.collectionId, _dependencies.readGas);
            if (
                actual.coordinator != t.coordinator || actual.status != t.status
                    || keccak256(abi.encode(actual.policy))
                        != keccak256(abi.encode(p.collectionPolicy))
            ) revert SourceSetToken(tokenId);
            t.terminal = true;
        } else {
            (t.seed, t.finalized) = abi.decode(
                _read(
                    t.coordinator,
                    abi.encodeWithSignature("tokenSeed(uint256)", tokenId),
                    64,
                    _dependencies.readGas
                ),
                (bytes32, bool)
            );
            if (
                t.finalized != (t.status == 5)
                    || (p.explicitPolicy
                        && (p.collectionPolicy.mode != 2
                            || p.collectionPolicy.renderRequirement != 0))
            ) revert SourceSetToken(tokenId);
        }
    }

    function _covered(uint256 tokenId) private view {
        (uint256 exists, uint256 cid, uint256 serial, uint256 burned) = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)),
                128,
                _dependencies.readGas
            ),
            (uint256, uint256, uint256, uint256)
        );
        uint256 life = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)),
                32,
                _dependencies.readGas
            ),
            (uint256)
        );
        if (
            tokenId == 0 || exists != 1 || cid != _scope.collectionId || serial == 0
                || !((life == 2 && burned == 0) || (life == 3 && burned == 1))
        ) revert SourceSetToken(tokenId);
        if (_scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            // Inventory positions are dense; actual serials may have consumed gaps.
            // Keep serving confined to the originally captured ordered token prefix.
            if (
                _membership.inventoryCount == 0
                    || tokenId
                        > abi.decode(
                            _read(
                                tokenInventory,
                                abi.encodeCall(
                                    IStreamCollectionTokenInventory.collectionTokenAt,
                                    (cid, _membership.inventoryCount - 1)
                                ),
                                32,
                                _dependencies.readGas
                            ),
                            (uint256)
                        )
                    || abi.decode(
                            _read(
                                tokenInventory,
                                abi.encodeCall(
                                    IStreamCollectionTokenInventorySerialLookup.collectionTokenBySerial,
                                    (cid, serial)
                                ),
                                32,
                                _dependencies.readGas
                            ),
                            (uint256)
                        ) != tokenId
            ) revert SourceSetToken(tokenId);
        } else if (_scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (tokenId != _scope.tokenId) revert SourceSetToken(tokenId);
        } else {
            bytes memory raw = _read(
                _dependencies.targets[2],
                abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (_scope)),
                256,
                _dependencies.inventoryGas
            );
            if (
                keccak256(raw) != keccak256(abi.encode(_membership))
                    || abi.decode(
                            _read(
                                _dependencies.targets[2],
                                abi.encodeCall(
                                    IStreamFinalityScopeMembership.scopeCoversToken,
                                    (_scope, tokenId)
                                ),
                                32,
                                _dependencies.inventoryGas
                            ),
                            (uint256)
                        ) != 1
            ) revert SourceSetToken(tokenId);
        }
    }

    function _policy(uint256 index) private view {
        StreamFinalityCoordinatorPolicyV2 memory saved = _policies[index];
        StreamFinalityCoordinatorPolicyV2 memory current =
            StreamFinalityCoordinatorPolicyReadsV2.requireRetainedPolicy(
                _dependencies,
                _scope,
                IStreamFinalityCoordinatorInventory.Coordinator(
                    saved.coordinator, saved.indexedCodeHash, saved.firstTokenIndex
                )
            );
        if (!current.frozen || keccak256(abi.encode(current)) != keccak256(abi.encode(saved))) {
            revert SourceSetEvidence();
        }
    }

    function _pins() private view {
        StreamFinalityCoordinatorPolicyReadsV2.validateDependencies(_dependencies);
        if (tokenInventory.code.length == 0 || tokenInventory.codehash != tokenInventoryCodeHash) {
            revert SourceSetDependency(tokenInventory);
        }
    }

    function _read(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, input, length, cap);
    }
}
