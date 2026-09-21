// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture
} from "../helpers/StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture.sol";
import { NativeAssemblyVm } from "../helpers/StreamNativeFinalityAssemblyFixture.sol";
import {
    IStreamGasParameterHost as AuthorityGas
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamSchemaRegistry as AuthoritySchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as AuthorityDocuments
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    GovernanceAction,
    GovernanceActionStatus,
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Original sanction-document and gas governance through the genuine current root Safe.
/// @dev The 3m target is only a governance regression input, not a measured-needed cap or
/// transaction acceptance. These cases stop before artwork publication, sanction or finality.
contract StreamCurrentFullPreservationPolicyViewFinalityAuthorityTest is
    StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture
{
    bytes32 private constant ARTIST_READ_GAS = keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS");
    bytes32 private constant FINALITY_ROLE = keccak256("ROLE_COLLECTION_FINALITY_ADMIN");

    function testActualViewCommonDefinitionsAndRootRolePreserveOriginalArtistBudget() public {
        _constructFullPolicyPublication();
        _requireBudget(2000000, 1);
        bytes32 originalBudget = keccak256(abi.encode(_authorityBudget()));
        uint256 safeNonce = assemblyRoot.nonce();
        uint256 governanceNonce = assemblyExecutor.governanceNonce();
        require(!assemblyRoles.hasRole(FINALITY_ROLE, address(assemblyRoot)));

        _viewPrepareCommonCeremonyDefinitions();

        _requireCommonDefinitions();
        require(
            assemblyRoles.hasRole(FINALITY_ROLE, address(assemblyRoot))
                && assemblyRoles.roleHolderCount(FINALITY_ROLE) == 1
                && assemblyRoles.roleHolderAt(FINALITY_ROLE, 0) == address(assemblyRoot),
            "the original root Safe is the sole actual finality-role holder"
        );
        (bytes32 roleChain, uint64 roleRevision) = assemblyRoles.roleMutationState(FINALITY_ROLE);
        require(roleChain != 0 && roleRevision == 1, "one original role admission");
        require(
            assemblyRoot.nonce() >= safeNonce + 5
                && assemblyRoot.nonce() - safeNonce
                    == assemblyExecutor.governanceNonce() - governanceNonce,
            "four document actions and role grant use real Safe scheduling, plus any policy admission"
        );
        require(
            keccak256(abi.encode(_authorityBudget())) == originalBudget,
            "common setup does not silently raise Artist gas"
        );
        _requireBudget(2000000, 1);
        _requireInactiveAuthority();
    }

    function testActualViewExplicitBudgetTestInputUsesOriginalClass1Raise() public {
        _constructFullPolicyPublication();
        _requireBudget(2000000, 1);
        uint256 safeNonce = assemblyRoot.nonce();
        uint256 governanceNonce = assemblyExecutor.governanceNonce();
        uint256 beforeAt = block.timestamp;

        // A test-only partial doubling exercises the original <=2x rule. No measurement is
        // supplied or inferred, and the real ceremony never calls this with a default target.
        _viewRaiseMeasuredSanctionReadBudget(3000000);

        _requireBudget(3000000, 2);
        bytes32 actionId = _requireRaiseEvent(assemblyVm.getRecordedLogs());
        _requireRaiseAction(actionId, beforeAt);
        require(
            assemblyRoot.nonce() > safeNonce
                && assemblyRoot.nonce() - safeNonce
                    == assemblyExecutor.governanceNonce() - governanceNonce,
            "actual root Safe scheduled every admitted action"
        );
        require(
            !assemblyRoles.hasRole(FINALITY_ROLE, address(assemblyRoot)),
            "gas governance does not grant sanction authority"
        );
        _requireInactiveAuthority();
    }

    function testActualViewSameBudgetNoOpAndInvalidTargetsPreserveGovernanceState() public {
        _constructFullPolicyPublication();
        _requireBudget(2000000, 1);
        bytes32 retained = _authorityStateHash();

        this.raiseViewAuthorityBudgetForTest(2000000);
        require(_authorityStateHash() == retained, "same-current target is a true no-op");

        bytes memory expected = abi.encodeWithSignature(
            "Error(string)",
            "measured target cannot lower the original cap or exceed diagnostic ceiling"
        );
        vm.expectRevert(expected);
        this.raiseViewAuthorityBudgetForTest(1999999);
        require(_authorityStateHash() == retained, "decrease rejects before any governance");

        vm.expectRevert(expected);
        this.raiseViewAuthorityBudgetForTest(16777217);
        require(_authorityStateHash() == retained, "above-ceiling rejects before any governance");
        _requireBudget(2000000, 1);
        _requireInactiveAuthority();
    }

    /// @dev Named self-call boundary lets exact pre-governance errors propagate to the test.
    function raiseViewAuthorityBudgetForTest(uint256 target) external {
        require(msg.sender == address(this), "test self-call only");
        _viewRaiseMeasuredSanctionReadBudget(target);
    }

    function _requireCommonDefinitions() private view {
        bytes32[4] memory ids = [
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1")
        ];
        bytes32[4] memory hashes = [
            bytes32(0xd55474e8f3ce5aacaa70ca4a40aee030b39b366143118c9d27ff2547e85efb1a),
            0x4b09880c931db919d35159b9974e21dcf1583bfaa65c18e3636e8721140cc690,
            0xd964c877b4256e4e829aa2630470b85832e4aa1e8a59da32094334550341600a,
            0x0d8a4197d8a294bd36eb4fd400c1ecc88ac8104c7091223b5436892a4797eef4
        ];
        uint256[4] memory sizes = [uint256(2574), 1221, 3687, 1246];
        for (uint256 i; i < ids.length; ++i) {
            AuthorityDocuments.DocumentFacts memory facts = assemblySchemas.documentFacts(ids[i]);
            bytes memory raw = assemblySchemas.documentBytes(ids[i]);
            require(
                facts.exists && facts.status == AuthoritySchema.DocumentStatus.ACTIVE
                    && facts.kind
                        == (i % 2 == 0
                                ? AuthoritySchema.DocumentKind.SCHEMA
                                : AuthoritySchema.DocumentKind.CANONICALIZATION)
                    && facts.canonicalizationId == keccak256("RAW_BYTES") && facts.supersedesId == 0
                    && facts.declarationHash != 0 && facts.contentHash == hashes[i]
                    && facts.totalBytes == sizes[i] && facts.chunkCount == 1
                    && raw.length == sizes[i] && keccak256(raw) == hashes[i]
                    && assemblySchemas.documentChunkHashAt(ids[i], 0) == hashes[i]
                    && keccak256(assemblyStore.readChunk(hashes[i])) == hashes[i],
                "literal original schema/canon hashes, complete payloads and stored pointers"
            );
        }
    }

    function _authorityBudget() private view returns (ViewSanctionBudgetState memory state) {
        AuthorityGas host = AuthorityGas(address(assemblyArtists));
        (state.value, state.floor, state.failureClass, state.revision) =
            host.gasParameterInfo(ARTIST_READ_GAS);
        require(host.gasParameter(ARTIST_READ_GAS) == state.value);
        require(host.governanceAuthority() == address(assemblyExecutor));
    }

    function _requireBudget(uint256 value, uint64 revision) private view {
        ViewSanctionBudgetState memory state = _authorityBudget();
        require(
            state.value == value && state.floor == 500000 && state.failureClass == 2
                && state.revision == revision,
            "exact original parameter state and fixed registration semantics"
        );
    }

    function _requireRaiseEvent(NativeAssemblyVm.Log[] memory logs)
        private
        view
        returns (bytes32 actionId)
    {
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblyArtists) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)"
                        )
            ) continue;
            require(actionId == 0, "one actual Artist parameter update");
            require(
                logs[i].topics[1] == ARTIST_READ_GAS
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(assemblyArtists))))
                    && logs[i].topics[3] != 0
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(2), uint256(2000000), uint256(3000000), uint256(500000)
                            )
                        ),
                "original schema2 event binds exact host, action and partial doubling"
            );
            actionId = logs[i].topics[3];
        }
        require(actionId != 0, "actual original parameter event was emitted");
    }

    function _requireRaiseAction(bytes32 actionId, uint256 beforeAt) private view {
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"),
                block.chainid,
                address(assemblyArtists),
                ARTIST_READ_GAS
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall(
            address(assemblyArtists),
            0,
            AuthorityGas.raiseGasParameter.selector,
            keccak256(abi.encodeCall(AuthorityGas.raiseGasParameter, (ARTIST_READ_GAS, 3000000))),
            scope,
            keccak256(
                abi.encode(domain, scope, uint256(2000000), uint256(500000), uint8(2), uint64(1))
            ),
            keccak256(
                abi.encode(domain, scope, uint256(3000000), uint256(500000), uint8(2), uint64(2))
            )
        );
        bytes32 callsHash =
            keccak256(abi.encode(keccak256("6529STREAM_GOVERNANCE_CALLS_V2"), calls));
        GovernanceAction memory action = assemblyExecutor.governanceAction(actionId);
        require(
            action.status == GovernanceActionStatus.EXECUTED && action.actionClass == 1
                && action.proposer == address(assemblyRoot) && action.executor == address(this)
                && action.target == address(assemblyArtists) && action.value == 0
                && action.selector == AuthorityGas.raiseGasParameter.selector
                && action.callHash == callsHash
                && action.notBefore >= beforeAt + assemblyExecutor.minimumDelay(1)
                && block.timestamp == action.notBefore
                && action.expiresAfter == action.notBefore + 7 days,
            "actual root-Safe class1 action retains exact original call and delay"
        );
        bytes32[] memory values = new bytes32[](1);
        values[0] = calls[0].scopeHash;
        require(
            action.scopeHash
                == keccak256(
                    abi.encode(keccak256("6529STREAM_GOVERNANCE_BATCH_SCOPE_V2"), callsHash, values)
                )
        );
        values[0] = calls[0].oldValueHash;
        require(
            action.oldValueHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GOVERNANCE_BATCH_OLD_STATE_V2"), callsHash, values
                    )
                )
        );
        values[0] = calls[0].newValueHash;
        require(
            action.newValueHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GOVERNANCE_BATCH_NEW_STATE_V2"), callsHash, values
                    )
                )
        );
    }

    function _authorityStateHash() private view returns (bytes32) {
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(FINALITY_ROLE);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 roles = keccak256(abi.encode(chain, revision, globalChain, globalRevision));
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 policyRevision) =
            assemblyExecutor.governanceActionPolicyState();
        bytes32 policy = keccak256(abi.encode(candidate, catalog, count, policyRevision));
        _requireInactiveAuthority();
        return keccak256(
            abi.encode(
                _authorityBudget(),
                assemblyRoot.nonce(),
                assemblyExecutor.governanceNonce(),
                roles,
                policy,
                block.timestamp
            )
        );
    }

    function _requireInactiveAuthority() private view {
        (bool executing, bytes32 action, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next) =
            assemblyExecutor.currentAction();
        require(
            !executing && action == 0 && class_ == 0 && scope == 0 && old_ == 0 && next == 0,
            "original active execution context is fully cleared"
        );
    }
}
