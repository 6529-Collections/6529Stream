// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFullV1ActivationPlan.sol";

/// @notice Exact original-target catalog intents for the added candidate products and reserves.
/// @dev These rows authorize delayed calls, not direct role-based Artist/metadata operations.
library StreamFullV1ActivationPolicies {
    function desired(StreamFullV1ActivationPlan.Context memory x)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        StreamFullV1ActivationPlan.validate(x);
        GovernanceActionPolicyEntry[] memory work = new GovernanceActionPolicyEntry[](96);
        uint256 n;
        n = _copy(work, n, StreamNativeCommerceGovernancePlan.policies(x.products.commerce.native));
        n = _copy(
            work,
            n,
            StreamFullV1RecordProducts.operatingPolicies(
                x.configuration.records, x.products.records
            )
        );
        n = _copy(
            work,
            n,
            StreamFullV1StaticRendererPlan.operatingPolicies(
                x.configuration.rendering, x.products.rendering
            )
        );
        address[5] memory independent = [
            address(x.products.independent.tickets),
            address(x.products.independent.delegates),
            address(x.products.independent.owners),
            address(x.products.independent.attestations),
            address(x.products.independent.views)
        ];
        for (uint256 i; i < independent.length; ++i) {
            work[n++] =
                _row(x, 1, independent[i], IStreamGasParameterHost.raiseGasParameter.selector);
        }
        address[4] memory commerce = [
            address(x.products.commerce.fixedSale),
            address(x.products.commerce.dutch),
            address(x.products.commerce.privateSale),
            address(x.products.commerce.burn)
        ];
        for (uint256 i; i < commerce.length; ++i) {
            work[n++] = _row(x, 1, commerce[i], IStreamGasParameterHost.raiseGasParameter.selector);
        }
        StreamMintManager backup = x.products.continuity.manager;
        work[n++] = _row(x, 1, address(backup), backup.bindPreparedNativeRecorder.selector);
        work[n++] = _row(x, 1, address(backup), backup.configurePhase.selector);
        work[n++] = _row(x, 1, address(backup), backup.setPhaseExecutor.selector);
        work[n++] = _row(x, 1, address(backup), backup.setPhasePaused.selector);
        work[n++] = _row(x, 1, address(backup), backup.raiseGasParameter.selector);
        work[n++] = _row(x, 1, address(backup), backup.importMintState.selector);
        work[n++] =
            _row(x, 3, address(backup), x.products.continuity.manager.recoverPreparedMint.selector);
        work[n++] = _row(x, 2, address(backup), backup.freezePhase.selector);
        work[n++] = _row(x, 2, address(x.foundation.manager), x.foundation.manager.freezePhase.selector);
        StreamMintLedger ledger = x.foundation.ledger;
        work[n++] = _row(x, 1, address(ledger), ledger.setLedgerWriter.selector);
        work[n++] = _row(x, 0, address(ledger), ledger.retireLedgerWriter.selector);
        work[n++] = _row(x, 1, address(ledger), ledger.commitCounterImportRoot.selector);
        work[n++] = _row(x, 1, address(ledger), ledger.importCounterDefinitions.selector);
        work[n++] = _row(x, 1, address(ledger), ledger.importMintAncestors.selector);
        work[n++] = _row(x, 1, address(ledger), ledger.importPhaseFreezes.selector);
        work[n++] = _row(x, 1, address(ledger), ledger.completeCounterImport.selector);
        work[n++] = _row(
            x, 1, address(x.foundation.executor), x.foundation.executor.setTighteningCall.selector
        );
        work[n++] = _row(
            x,
            3,
            address(x.foundation.executor),
            x.foundation.executor.extendGovernanceActionPolicy.selector
        );
        work[n++] = _row(
            x, 1, address(x.foundation.schemas), x.foundation.schemas.registerDocument.selector
        );
        work[n++] = _row(
            x, 1, address(x.foundation.metadata), x.foundation.metadata.setFamilyWriter.selector
        );
        work[n++] = _row(
            x, 1, address(x.foundation.metadata), x.foundation.metadata.admitRecordType.selector
        );
        for (uint8 i; i < 4; ++i) {
            work[n++] = _row(
                x,
                i,
                address(x.foundation.manifest),
                x.foundation.manifest.publishStreamSystemManifest.selector
            );
        }
        for (uint8 i; i < 2; ++i) {
            StreamEntropyCoordinator e =
                i == 0 ? x.foundation.entropy : x.products.continuity.entropy;
            work[n++] = _row(x, 1, address(e), e.configureCollection.selector);
            work[n++] = _row(x, 1, address(e), e.activateEntropyProvider.selector);
            work[n++] = _row(x, 0, address(e), e.deprecateEntropyProvider.selector);
            work[n++] = _row(x, 0, address(e), e.revokeEntropyProvider.selector);
            work[n++] = _row(x, 1, address(e), e.setRequester.selector);
            work[n++] = _row(x, 1, address(e), e.markRequestStale.selector);
            work[n++] = _row(x, 1, address(e), e.markRequestFailed.selector);
            work[n++] = _row(x, 1, address(e), e.raiseGasParameter.selector);
            work[n++] = _row(x, 1, address(e), e.raiseTimeParameter.selector);
        }
        work[n++] = _row(x, 1, address(x.products.vrf), x.products.vrf.updateSubscription.selector);
        work[n++] = _row(
            x,
            1,
            address(x.products.continuity.provider),
            x.products.continuity.provider.updateSubscription.selector
        );
        work[n++] =
            _row(x, 1, address(x.products.arrng), x.products.arrng.raiseGasParameter.selector);
        rows = new GovernanceActionPolicyEntry[](n);
        for (uint256 i; i < n; ++i) {
            rows[i] = work[i];
        }
        for (uint256 i = 1; i < n; ++i) {
            for (uint256 j = i; j > 0 && key(rows[j - 1]) > key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        for (uint256 i = 1; i < n; ++i) {
            require(key(rows[i - 1]) != key(rows[i]), "unique original policy intents");
        }
    }

    /// @dev knownEntries is retained, independently verified genesis/extension history. There
    /// is no enumerable live-entry getter. Preserve compatible prior profile hashes exactly;
    /// original Executor scheduling/extension remains the authoritative catalog check.
    function additions(
        StreamFullV1ActivationPlan.Context memory x,
        GovernanceActionPolicyEntry[] memory knownEntries
    ) internal view returns (GovernanceActionPolicyEntry[] memory out) {
        GovernanceActionPolicyEntry[] memory wanted = desired(x);
        uint256 n;
        for (uint256 i; i < wanted.length; ++i) {
            bool found;
            for (uint256 j; j < knownEntries.length; ++j) {
                GovernanceActionPolicyEntry memory prior = knownEntries[j];
                if (key(prior) != key(wanted[i])) continue;
                require(
                    !found && prior.targetCodeHash == wanted[i].targetCodeHash
                        && prior.targetProfileHash != 0 && prior.callType == 1
                        && prior.valuePolicy == 0 && prior.valueLimit == 0
                        && prior.valueSemanticsHash == 0,
                    "conflicting retained policy"
                );
                found = true;
            }
            if (!found) wanted[n++] = wanted[i];
        }
        out = new GovernanceActionPolicyEntry[](n);
        for (uint256 i; i < n; ++i) {
            out[i] = wanted[i];
        }
    }

    function catalogInventory(
        StreamFullV1ActivationPlan.Context memory x,
        GovernanceActionPolicyEntry[] memory knownEntries
    ) internal view returns (StreamGovernanceCatalogStagePlan.Inventory memory) {
        return StreamGovernanceCatalogStagePlan.inventory(
            x.foundation.executor, additions(x, knownEntries)
        );
    }

    function key(GovernanceActionPolicyEntry memory row) internal pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _row(
        StreamFullV1ActivationPlan.Context memory x,
        uint8 cls,
        address target,
        bytes4 selector
    ) private view returns (GovernanceActionPolicyEntry memory) {
        return GovernanceActionPolicyEntry(
            cls,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(x.configuration.independent.deploymentHash, target)),
            1,
            0,
            0,
            0
        );
    }

    function _copy(
        GovernanceActionPolicyEntry[] memory dst,
        uint256 offset,
        GovernanceActionPolicyEntry[] memory src
    ) private pure returns (uint256) {
        for (uint256 i; i < src.length; ++i) {
            dst[offset++] = src[i];
        }
        return offset;
    }
}
