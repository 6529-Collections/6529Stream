// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20CommerceDeployment.sol";
import "./StreamRevenueRuntimePlan.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintAdmin.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

/// @notice Read-only original governance/owner calls for the saved ERC20 product cohort.
/// @dev These plans neither establish Artist consent nor enable token/permit policies. Reobserve
/// after confirmed dependent actions; keep scheduled calldata fixed through normal execution.
library StreamERC20CommerceActivationPlan {
    error InvalidERC20CommerceActivation();
    error IncompatibleERC20CommercePolicy();
    error ERC20CommerceConsentMissing(bytes32 policyHash);

    struct PhaseAdmission {
        address actor;
        address target;
        bytes data;
        bytes32 oldPolicyHash;
        bytes32 newPolicyHash;
        bool governed;
    }

    function admission(StreamERC20CommerceDeployment.Products memory p)
        internal
        view
        returns (GenesisBatch memory batch)
    {
        StreamModuleRegistration[] memory rows = StreamERC20CommerceDeployment.registrations(p);
        StreamModuleRegistry registry =
            StreamModuleRegistry(payable(p.configuration.recorder.moduleRegistry()));
        for (uint256 i; i < 4; ++i) {
            if (uint8(registry.moduleRecord(p.targets[i]).status) != 0) {
                revert InvalidERC20CommerceActivation();
            }
        }
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.registrationCalls(registry, rows);
    }

    /// @notice Only new product gas raises, original registration and Manager executor admission.
    /// @dev No owner-only sale creation/pausing selector is silently granted to the Executor.
    function policies(StreamERC20CommerceDeployment.Products memory p)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        StreamERC20CommerceDeployment.validate(p);
        rows = new GovernanceActionPolicyEntry[](5);
        rows[0] = _policy(
            p,
            p.configuration.recorder.moduleRegistry(),
            StreamModuleRegistry.registerModule.selector
        );
        rows[1] = _policy(
            p, address(p.configuration.manager), IStreamMintAdmin.setPhaseExecutor.selector
        );
        for (uint256 i = 1; i < 4; ++i) {
            rows[i + 1] =
                _policy(p, p.targets[i], IStreamGasParameterHost.raiseGasParameter.selector);
        }
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    /// @notice Subtract exact compatible keys from the operator's verified catalog inventory.
    /// @dev The original Executor authenticates its catalog/history; supplied rows create no authority.
    function catalogAdditions(
        StreamERC20CommerceDeployment.Products memory p,
        GovernanceActionPolicyEntry[] memory known
    ) internal view returns (GovernanceActionPolicyEntry[] memory additions) {
        GovernanceActionPolicyEntry[] memory wanted = policies(p);
        uint256 count;
        for (uint256 i; i < wanted.length; ++i) {
            bool found;
            for (uint256 j; j < known.length; ++j) {
                GovernanceActionPolicyEntry memory row = known[j];
                if (_key(row) != _key(wanted[i])) continue;
                if (
                    found || row.targetCodeHash != wanted[i].targetCodeHash
                        || row.targetProfileHash == 0 || row.callType != 1 || row.valuePolicy != 0
                        || row.valueLimit != 0 || row.valueSemanticsHash != 0
                ) revert IncompatibleERC20CommercePolicy();
                found = true;
            }
            if (!found) wanted[count++] = wanted[i];
        }
        additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = wanted[i];
        }
    }

    /// @notice Derive the exact next hash from all actual phase inputs and executor ordering.
    /// @dev This is available before consent, so the Artist can sign the actual prospective hash.
    function phasePolicy(
        StreamERC20CommerceDeployment.Products memory p,
        uint8 product,
        uint256 collectionId,
        bytes32 phaseId
    ) internal view returns (bytes32 current, bytes32 next) {
        StreamERC20CommerceDeployment.validate(p);
        if (product == 0 || product > 3 || collectionId == 0 || phaseId == 0) {
            revert InvalidERC20CommerceActivation();
        }
        _admitted(p, product);
        _admitted(p, 0);
        _selected(p, keccak256("MINT_MANAGER"), address(p.configuration.manager));
        _selected(p, keccak256("ARTIST_REGISTRY"), address(p.configuration.artists));
        IStreamMintReads m = IStreamMintReads(address(p.configuration.manager));
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) =
            m.phase(collectionId, phaseId);
        if (
            !exists || m.phaseExecutor(collectionId, phaseId, p.targets[product])
                || IStreamMintPhaseFreeze(address(m)).phaseFrozen(collectionId, phaseId)
        ) revert InvalidERC20CommerceActivation();
        bytes32[] memory ids = m.phaseCounterIds(collectionId, phaseId);
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            counters[i] = m.counterConfig(collectionId, phaseId, ids[i]);
        }
        address[] memory oldExecutors =
            IStreamMintPhaseFreeze(address(m)).phaseExecutors(collectionId, phaseId);
        current = m.phasePolicyHash(collectionId, phaseId);
        IStreamMintManager.MintGateConfig memory gate = m.phaseGate(collectionId, phaseId);
        if (
            current == 0
                || m.previewPhasePolicyHash(
                        collectionId, phaseId, config, gate, ids, counters, oldExecutors
                    ) != current
        ) revert InvalidERC20CommerceActivation();
        address[] memory executors = new address[](oldExecutors.length + 1);
        for (uint256 i; i < oldExecutors.length; ++i) {
            executors[i] = oldExecutors[i];
        }
        executors[oldExecutors.length] = p.targets[product];
        next =
            m.previewPhasePolicyHash(collectionId, phaseId, config, gate, ids, counters, executors);
        if (next == 0 || next == current) revert InvalidERC20CommerceActivation();
    }

    function phaseCall(
        StreamERC20CommerceDeployment.Products memory p,
        uint8 product,
        uint256 collectionId,
        bytes32 phaseId
    ) internal view returns (PhaseAdmission memory r) {
        (r.oldPolicyHash, r.newPolicyHash) = phasePolicy(p, product, collectionId, phaseId);
        IStreamArtistMintConsent artists =
            IStreamArtistMintConsent(address(p.configuration.artists));
        (bool consented, bytes32 record) =
            artists.isPolicyConsented(collectionId, phaseId, r.newPolicyHash);
        if (!consented || record == 0) revert ERC20CommerceConsentMissing(r.newPolicyHash);
        artists.requireMintConsent(collectionId, phaseId, r.newPolicyHash);
        r.target = address(p.configuration.manager);
        r.actor = ERC20CommerceOwner(r.target).owner();
        if (r.actor == address(0)) revert InvalidERC20CommerceActivation();
        r.governed = r.actor == p.configuration.authority;
        r.data = abi.encodeCall(
            IStreamMintAdmin.setPhaseExecutor, (collectionId, phaseId, p.targets[product], true)
        );
    }

    /// @notice Used only when the actual Manager owner is the bound governance Executor.
    /// @dev Otherwise the actual owner, including a Safe, makes the ordinary zero-value CALL.
    function governedPhase(
        StreamERC20CommerceDeployment.Products memory p,
        uint8 product,
        uint256 collectionId,
        bytes32 phaseId
    ) internal view returns (GenesisBatch memory batch) {
        PhaseAdmission memory r = phaseCall(p, product, collectionId, phaseId);
        if (!r.governed) revert InvalidERC20CommerceActivation();
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = r.data;
        // Manager's original owner method has no executing-context consumer. These are the
        // original owner-call plan commitments; Manager independently checks the current policy.
        batch.calls[0] = StreamCurrentStackPlan.call(
            r.target,
            r.data,
            keccak256(abi.encode(r.target, r.data)),
            r.oldPolicyHash,
            r.newPolicyHash
        );
    }

    function requireRuntimeActivated(StreamERC20CommerceDeployment.Products memory p)
        internal
        view
    {
        StreamERC20CommerceDeployment.validate(p);
        StreamRevenueRuntimePlan.requireActivated(
            address(p.configuration.recorder.splitFactory()),
            address(p.configuration.recorder.revenueEscrow())
        );
    }

    function _selected(
        StreamERC20CommerceDeployment.Products memory p,
        bytes32 kind,
        address expected
    ) private view {
        (
            address target,
            bytes32 pin,,
            bytes32 role,,
            address registry,
            uint8 status,
            bytes32 moduleHash,
            bytes32 deploymentHash,
            uint64 revision
        ) = IStreamCorePointers(p.configuration.recorder.core()).getSatellitePointer(kind);
        if (
            target != expected || pin != expected.codehash || role != kind
                || registry != p.configuration.recorder.moduleRegistry() || status != 1
                || moduleHash == 0 || deploymentHash == 0 || revision == 0
        ) revert InvalidERC20CommerceActivation();
    }

    function _admitted(StreamERC20CommerceDeployment.Products memory p, uint256 i) private view {
        StreamModuleRegistration memory e = StreamERC20CommerceDeployment.registrations(p)[i];
        StreamModuleRecord memory r = StreamModuleRegistry(
                payable(p.configuration.recorder.moduleRegistry())
            ).moduleRecord(e.module);
        if (
            r.status != ModuleRegistryStatus.ACTIVE || r.moduleType != e.moduleType
                || r.moduleVersion != e.moduleVersion || r.interfaceId != e.interfaceId
                || r.runtimeCodeHash != e.expectedRuntimeCodeHash
                || r.deploymentManifestHash != e.deploymentManifestHash
                || r.moduleManifestHash != e.moduleManifestHash
        ) revert InvalidERC20CommerceActivation();
    }

    function _policy(
        StreamERC20CommerceDeployment.Products memory p,
        address target,
        bytes4 selector
    ) private view returns (GovernanceActionPolicyEntry memory) {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(p.deploymentManifestHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory r) private pure returns (bytes32) {
        return keccak256(abi.encode(r.actionClass, r.target, r.selector));
    }
}
