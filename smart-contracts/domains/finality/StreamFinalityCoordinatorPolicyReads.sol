// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "./StreamFinalityRouterEvidence.sol";
import "../metadata/StreamMetadataSubjects.sol";

/// @notice Joins every original coordinator in the actual scope to its native policy.
/// @dev The consuming provider supplies constructor-fixed dependencies. No supplied source list,
/// current-pointer substitution, policy readiness cache or finality authority is introduced.
library StreamFinalityCoordinatorPolicyReads {
    struct Dependencies {
        // Core, generic Metadata, authoritative membership, original-coordinator inventory.
        address[4] targets;
        bytes32[4] codeHashes;
        uint256 chainId;
        uint32 readGas;
        uint32 inventoryGas;
    }

    error PolicyConfiguration();
    error PolicyDependency(address target);
    error PolicyRead(address target, bytes4 selector);
    error PolicyInventory(bytes32 planId);
    error PolicyUnavailable(address coordinator);

    function requireCurrent(Dependencies memory d, StreamFinalityScope memory scope, bytes32 planId)
        public
        view
        returns (StreamFinalityCoordinatorPolicyEvidence memory e)
    {
        _bindings(d);
        IStreamFinalityCoordinatorInventory.Progress memory p = _inventory(d, scope, planId);
        e.planId = planId;
        e.inventoryHash = p.commitment;
        e.policyCount = p.coordinatorCount;
        e.allFrozen = p.coordinatorCount != 0;
        e.policies = new StreamFinalityCoordinatorPolicy[](p.coordinatorCount);
        e.policyChainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ORIGINAL_COORDINATOR_POLICIES_V1"),
                d.chainId,
                d.targets,
                d.codeHashes,
                scope,
                planId,
                p.commitment,
                p.coordinatorCount
            )
        );
        bytes32 sources =
            keccak256(abi.encode(keccak256("6529STREAM_COORDINATOR_SOURCE_CHAIN_V1"), planId));
        for (uint256 i; i < p.coordinatorCount; ++i) {
            IStreamFinalityCoordinatorInventory.Coordinator memory original = abi.decode(
                _read(
                    d.targets[3],
                    abi.encodeCall(
                        IStreamFinalityCoordinatorInventory.requireCoordinator, (planId, i)
                    ),
                    96,
                    d.readGas
                ),
                (IStreamFinalityCoordinatorInventory.Coordinator)
            );
            if (
                original.firstTokenIndex >= p.tokenCount
                    || (i == 0
                            ? original.firstTokenIndex != 0
                            : original.firstTokenIndex <= e.policies[i - 1].firstTokenIndex)
            ) {
                revert PolicyInventory(planId);
            }
            sources = keccak256(
                abi.encode(
                    keccak256("6529STREAM_COORDINATOR_SOURCE_APPEND_V1"), sources, i, original
                )
            );
            StreamFinalityCoordinatorPolicy memory policy = _policy(d, scope, original);
            e.policies[i] = policy;
            e.allFrozen = e.allFrozen && policy.frozen;
            e.policyChainHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ORIGINAL_COORDINATOR_POLICY_APPEND_V1"),
                    e.policyChainHash,
                    i,
                    policy
                )
            );
        }
        if (sources != p.coordinatorChain) revert PolicyInventory(planId);
    }

    function _inventory(Dependencies memory d, StreamFinalityScope memory scope, bytes32 id)
        private
        view
        returns (IStreamFinalityCoordinatorInventory.Progress memory p)
    {
        bytes memory raw = _read(
            d.targets[3],
            abi.encodeCall(IStreamFinalityCoordinatorInventory.requireCompleteInventory, (id)),
            256,
            d.inventoryGas
        );
        p = abi.decode(raw, (IStreamFinalityCoordinatorInventory.Progress));
        if (
            keccak256(raw) != keccak256(abi.encode(p)) || !p.exists || !p.complete
                || p.processedTokens != p.tokenCount || p.coordinatorCount > p.tokenCount
                || (p.tokenCount != 0 && p.coordinatorCount == 0)
        ) revert PolicyInventory(id);
        (StreamFinalityScope memory saved, StreamScopeMembershipFacts memory facts) = abi.decode(
            _read(
                d.targets[3],
                abi.encodeCall(IStreamFinalityCoordinatorInventory.inventoryScope, (id)),
                384,
                d.readGas
            ),
            (StreamFinalityScope, StreamScopeMembershipFacts)
        );
        if (
            keccak256(abi.encode(scope)) != keccak256(abi.encode(saved))
                || facts.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope)
                || facts.membershipHash == 0 || facts.tokenCount != p.tokenCount
                || id
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_COORDINATOR_INVENTORY_PLAN_V1"),
                            d.chainId,
                            d.targets[3],
                            d.targets[0],
                            d.codeHashes[0],
                            d.targets[2],
                            d.codeHashes[2],
                            scope,
                            facts
                        )
                    )
                || p.commitment
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1"),
                            id,
                            p.tokenCount,
                            p.coordinatorCount,
                            p.tokenChain,
                            p.coordinatorChain
                        )
                    )
        ) revert PolicyInventory(id);
        // The original inventory independently revalidates all eight current membership facts.
    }

    function _policy(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        IStreamFinalityCoordinatorInventory.Coordinator memory original
    ) private view returns (StreamFinalityCoordinatorPolicy memory e) {
        address target = original.coordinator;
        if (target.code.length == 0 || target.codehash != original.indexedCodeHash) {
            revert PolicyDependency(target);
        }
        _word(
            target,
            abi.encodeWithSignature("core()"),
            bytes32(uint256(uint160(d.targets[0]))),
            d.readGas
        );
        _supports(target, type(IStreamEntropyCoordinator).interfaceId, d.readGas);
        _supports(target, type(IStreamEntropyFinalityPolicy).interfaceId, d.readGas);
        _supports(target, type(IStreamModule).interfaceId, d.readGas);
        _word(
            target,
            abi.encodeCall(IStreamModule.streamModuleType, ()),
            keccak256("ENTROPY_COORDINATOR"),
            d.readGas
        );
        _word(
            target,
            abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()),
            bytes32(type(IStreamEntropyCoordinator).interfaceId),
            d.readGas
        );
        _word(
            target,
            abi.encodeCall(IStreamModule.streamModuleCodeHash, ()),
            original.indexedCodeHash,
            d.readGas
        );
        e.coordinator = target;
        e.indexedCodeHash = original.indexedCodeHash;
        e.firstTokenIndex = original.firstTokenIndex;
        (e.moduleVersion, e.moduleManifestHash) =
            StreamFinalityRouterEvidence.moduleIdentity(target, d.readGas);
        e.moduleSchemaHash = abi.decode(
            _read(target, abi.encodeCall(IStreamModule.streamModuleSchemaHash, ()), 32, d.readGas),
            (bytes32)
        );
        e.deploymentManifestHash = abi.decode(
            _read(
                target,
                abi.encodeCall(IStreamModule.streamModuleDeploymentManifestHash, ()),
                32,
                d.readGas
            ),
            (bytes32)
        );
        bytes memory raw = _read(
            target,
            abi.encodeCall(IStreamEntropyFinalityPolicy.entropyPolicyFrozen, (scope.collectionId)),
            160,
            d.readGas
        );
        (e.frozen, e.policyHash, e.provider, e.epoch, e.salt) =
            abi.decode(raw, (bool, bytes32, address, uint32, bytes32));
        if (
            e.moduleSchemaHash == 0 || e.deploymentManifestHash == 0 || e.policyHash == 0
                || e.provider == address(0) || e.epoch == 0 || e.salt == 0
                || keccak256(raw)
                    != keccak256(abi.encode(e.frozen, e.policyHash, e.provider, e.epoch, e.salt))
        ) {
            revert PolicyUnavailable(target);
        }
        // Identical per-source preimage to the original single-coordinator evidence provider.
        e.componentDataHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"),
                d.chainId,
                d.targets[0],
                target,
                scope,
                e.policyHash,
                e.provider,
                e.epoch,
                e.salt
            )
        );
    }

    function _bindings(Dependencies memory d) private view {
        if (d.chainId != block.chainid || d.readGas < 50000 || d.inventoryGas < d.readGas) {
            revert PolicyConfiguration();
        }
        for (uint256 i; i < 4; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert PolicyDependency(d.targets[i]);
            }
        }
        _supports(d.targets[0], 0x80ac58cd, d.readGas);
        _supports(d.targets[2], type(IStreamFinalityScopeMembership).interfaceId, d.readGas);
        _supports(d.targets[3], type(IStreamFinalityCoordinatorInventory).interfaceId, d.readGas);
        for (uint256 i = 1; i < 4; ++i) {
            _word(
                d.targets[i],
                abi.encodeWithSignature("core()"),
                bytes32(uint256(uint160(d.targets[0]))),
                d.readGas
            );
        }
        _word(
            d.targets[2],
            abi.encodeWithSignature("metadataHost()"),
            bytes32(uint256(uint160(d.targets[1]))),
            d.readGas
        );
        _word(
            d.targets[3],
            abi.encodeWithSignature("scopeMembershipHost()"),
            bytes32(uint256(uint160(d.targets[2]))),
            d.readGas
        );
        _word(
            d.targets[3],
            abi.encodeWithSignature("deploymentChainId()"),
            bytes32(d.chainId),
            d.readGas
        );
        _word(d.targets[3], abi.encodeWithSignature("coreCodeHash()"), d.codeHashes[0], d.readGas);
        _word(
            d.targets[3],
            abi.encodeWithSignature("scopeMembershipCodeHash()"),
            d.codeHashes[2],
            d.readGas
        );
    }

    function _supports(address target, bytes4 id, uint32 cap) private view {
        _word(target, abi.encodeCall(IERC165.supportsInterface, (id)), bytes32(uint256(1)), cap);
        _word(
            target,
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
            bytes32(uint256(1)),
            cap
        );
        _word(
            target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), bytes32(0), cap
        );
    }

    function _word(address target, bytes memory input, bytes32 expected, uint32 cap) private view {
        if (abi.decode(_read(target, input, 32, cap), (bytes32)) != expected) {
            revert PolicyDependency(target);
        }
    }

    function _read(address target, bytes memory input, uint256 size, uint32 cap)
        private
        view
        returns (bytes memory out)
    {
        out = new bytes(size);
        if (gasleft() <= uint256(cap) + uint256(cap) / 63 + 10000) {
            revert PolicyRead(target, bytes4(input));
        }
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert PolicyRead(target, bytes4(input));
    }
}
