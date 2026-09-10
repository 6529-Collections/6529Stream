// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/interfaces/stream/core/IStreamCore.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintExecution.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintAdmin.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol";
import "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecution.sol";
import "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceAdmin.sol";
import "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";

/// @notice Preserve deployed discovery vocabulary while reorganizing Solidity caller APIs.
/// @dev Expected IDs are literals from main330ac1d4, not values recomputed from the new API.
contract StreamInterfaceCompatibilityTest {
    function testAggregateDiscoveryIdsRemainPinned() external pure {
        require(type(IStreamMintManager).interfaceId == 0xb4074ed7, "mint manager ID changed");
        require(type(IStreamMintLedger).interfaceId == 0x27d4bae6, "mint ledger ID changed");
        require(type(IStreamGovernanceExecutor).interfaceId == 0x4bc45fd4, "governance ID changed");
        // The inheritance-only Core aggregate has no own selectors and is not a new ERC165 claim.
        require(
            type(IStreamCore).interfaceId == 0x00000000, "Core aggregate acquired own selectors"
        );
    }

    function testCoreCapabilityIdsRemainPinned() external pure {
        require(type(IStreamCoreCollectionView).interfaceId == 0x2487d106, "collection reads ID");
        require(
            type(IStreamCoreCollectionManagement).interfaceId == 0x9a0fdc8f, "collection admin ID"
        );
        require(type(IStreamCoreIdentity).interfaceId == 0xfb4c6d0a, "token identity ID");
        require(type(IStreamCoreEnumeration).interfaceId == 0x2a1715ce, "enumeration ID");
        require(type(IStreamCoreMint).interfaceId == 0xc4f58dce, "mint hooks ID");
        require(type(IStreamCoreBurn).interfaceId == 0x93ec7aee, "burn ID");
        require(type(IStreamCorePointers).interfaceId == 0x54fb352a, "pointers ID");
        require(type(IStreamCoreGasParameters).interfaceId == 0xb0230ed0, "gas ID");
        require(type(IStreamCoreMetadataEmitters).interfaceId == 0x579dc287, "metadata events ID");
    }

    function testMintCallerSelectorsPreserveStructuredRequests() external pure {
        require(
            IStreamMintExecution.executeSingleStepMint.selector
                == IStreamMintManager.executeSingleStepMint.selector,
            "immediate request ABI"
        );
        require(
            IStreamMintExecution.executePreparedMint.selector
                == IStreamMintManager.executePreparedMint.selector,
            "prepared request ABI"
        );
        require(
            IStreamMintAdmin.configurePhase.selector == IStreamMintManager.configurePhase.selector,
            "phase configuration ABI"
        );
        require(
            IStreamMintReads.previewSingleStepMintOperation.selector
                == IStreamMintManager.previewSingleStepMintOperation.selector,
            "operation preview ABI"
        );
        require(
            IStreamMintReads.previewSubjectKey.selector
                == IStreamMintManager.previewSubjectKey.selector,
            "counter subject ABI"
        );
    }

    function testGovernanceCallerSelectorsPreserveStructuredActions() external pure {
        require(
            IStreamGovernanceExecution.scheduleGovernanceBatch.selector
                == IStreamGovernanceExecutor.scheduleGovernanceBatch.selector,
            "batch schedule ABI"
        );
        require(
            IStreamGovernanceExecution.executeGovernanceBatch.selector
                == IStreamGovernanceExecutor.executeGovernanceBatch.selector,
            "batch execution ABI"
        );
        require(
            IStreamGovernanceExecution.scheduleGovernanceAction.selector
                == IStreamGovernanceExecutor.scheduleGovernanceAction.selector,
            "single action ABI"
        );
        require(
            IStreamGovernanceAdmin.bindSystemManifestBootstrap.selector
                == IStreamGovernanceExecutor.bindSystemManifestBootstrap.selector,
            "bootstrap binding ABI"
        );
        require(
            IStreamGovernanceReads.currentAction.selector
                == IStreamGovernanceExecutor.currentAction.selector,
            "execution context ABI"
        );
        require(
            IStreamGovernanceReads.systemManifestBootstrapState.selector
                == IStreamGovernanceExecutor.systemManifestBootstrapState.selector,
            "bootstrap reads ABI"
        );
    }
}
