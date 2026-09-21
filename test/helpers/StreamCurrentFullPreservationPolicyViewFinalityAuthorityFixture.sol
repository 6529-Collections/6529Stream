// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewCompleteFixture
} from "./StreamCurrentFullPreservationPolicyViewCompleteFixture.sol";
import {
    IStreamSchemaRegistry as SanctionSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as SanctionDocuments
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamGasParameterHost as SanctionGas
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalitySanctionSchemas as SanctionSchemas
} from "../../smart-contracts/domains/finality/StreamFinalitySanctionSchemas.sol";

/// @notice Original common sanction definitions and actual delayed governance authority.
/// @dev VIEW manifest/media interpretation belongs to its explicit producer, not these common
/// documents. No sanction, finalization, confirmation, measurement or automatic gas raise occurs.
abstract contract StreamCurrentFullPreservationPolicyViewFinalityAuthorityFixture is
    StreamCurrentFullPreservationPolicyViewCompleteFixture
{
    struct ViewSanctionBudgetState {
        uint256 value;
        uint256 floor;
        uint8 failureClass;
        uint64 revision;
    }

    function _viewPrepareCommonCeremonyDefinitions() internal {
        string[4] memory names = [
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_V1",
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1"
        ];
        string[4] memory files = [
            "sanction-archive-v1.schema.json",
            "sanction-archive-abi-v1.json",
            "sanction-ceremony-v1.schema.json",
            "sanction-ceremony-jcs-v1.json"
        ];
        for (uint256 i; i < names.length; ++i) {
            bytes memory raw =
                bytes(assemblyVm.readFile(string.concat("docs/schemas/finality/", files[i])));
            SanctionSchema.DocumentKind kind = i % 2 == 0
                ? SanctionSchema.DocumentKind.SCHEMA
                : SanctionSchema.DocumentKind.CANONICALIZATION;
            bytes32 id = _assemblyRegisterDocument(names[i], kind, raw, assemblySchemas.RAW_BYTES());
            SanctionDocuments.DocumentFacts memory facts = assemblySchemas.documentFacts(id);
            require(
                id == keccak256(bytes(names[i])) && facts.exists && facts.kind == kind
                    && facts.status == SanctionSchema.DocumentStatus.ACTIVE
                    && facts.contentHash == keccak256(raw)
                    && facts.canonicalizationId == assemblySchemas.RAW_BYTES()
                    && facts.supersedesId == 0 && facts.chunkCount == 1
                    && facts.totalBytes == raw.length && facts.declarationHash != 0
                    && keccak256(assemblySchemas.documentBytes(id)) == keccak256(raw)
                    && keccak256(assemblyStore.readChunk(keccak256(raw))) == keccak256(raw),
                "actual original sanction definition and complete registered bytes"
            );
        }
        // The original verifier supplies independent fixed hashes and lengths for all four.
        // The old native-captures catalog is COLLECTION-specific; it is not a VIEW profile.
        SanctionSchemas.requireDefinitions(address(assemblyArtifact), 500000);
        _viewGrantFinalityRole();
    }

    function _viewGrantFinalityRole() internal {
        bytes32 role = keccak256("ROLE_COLLECTION_FINALITY_ADMIN");
        address holder = address(assemblyRoot);
        require(!assemblyRoles.hasRole(role, holder), "fresh original finality role grant");
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(assemblyRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(assemblyRoles),
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
                address(assemblyRoles),
                scope,
                false,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyRoles),
            abi.encodeCall(assemblyRoles.grantRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
        (bytes32 savedChain, uint64 savedRevision) = assemblyRoles.roleMutationState(role);
        (bytes32 savedGlobal, uint64 savedGlobalRevision) = assemblyRoles.globalRoleMutationState();
        require(
            assemblyRoles.hasRole(role, holder) && savedChain == nextChain
                && savedRevision == revision + 1 && savedGlobal == nextGlobal
                && savedGlobalRevision == globalRevision + 1,
            "actual root Safe role and both original mutation chains"
        );
    }

    /// @dev Caller supplies a target justified by separate measurements. This helper neither
    /// measures gas nor treats its diagnostic ceiling as a whole-transaction fit proof. It
    /// changes only the original Artist parameter through its original class1 <=2x API.
    function _viewRaiseMeasuredSanctionReadBudget(uint256 measuredNeededTarget) internal {
        SanctionGas host = SanctionGas(address(assemblyArtists));
        bytes32 id = keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS");
        require(
            host.governanceAuthority() == address(assemblyExecutor),
            "original Artist governed parameter authority"
        );
        ViewSanctionBudgetState memory state = _viewSanctionBudgetState(host, id);
        require(
            measuredNeededTarget >= state.value && measuredNeededTarget <= 16777216,
            "measured target cannot lower the original cap or exceed diagnostic ceiling"
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        uint256 steps;
        while (state.value < measuredNeededTarget) {
            require(++steps <= 6, "bounded original monotonic governance steps");
            uint256 next = state.value * 2;
            if (next > measuredNeededTarget) next = measuredNeededTarget;
            bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
            bytes32 oldHash = keccak256(
                abi.encode(
                    domain, scope, state.value, state.floor, state.failureClass, state.revision
                )
            );
            bytes32 newHash = keccak256(
                abi.encode(domain, scope, next, state.floor, state.failureClass, state.revision + 1)
            );
            _assemblyGovernanceCall(
                1,
                address(host),
                abi.encodeCall(host.raiseGasParameter, (id, next)),
                scope,
                oldHash,
                newHash
            );
            ViewSanctionBudgetState memory saved = _viewSanctionBudgetState(host, id);
            require(
                next > state.value && next - state.value <= state.value && saved.value == next
                    && saved.floor == state.floor && saved.failureClass == state.failureClass
                    && saved.revision == state.revision + 1,
                "one original delayed bounded raise with exact value and revision readback"
            );
            state = saved;
        }
        require(host.gasParameter(id) == measuredNeededTarget, "exact caller-selected cap retained");
    }

    function _viewSanctionBudgetState(SanctionGas host, bytes32 id)
        private
        view
        returns (ViewSanctionBudgetState memory state)
    {
        (state.value, state.floor, state.failureClass, state.revision) = host.gasParameterInfo(id);
        require(
            state.value >= 2000000 && state.floor == 500000 && state.failureClass == 2
                && state.revision != 0 && host.gasParameter(id) == state.value,
            "original registered Artist sanction budget and unchanged fixed semantics"
        );
    }
}
