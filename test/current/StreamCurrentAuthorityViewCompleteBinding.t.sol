// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityViewCompleteBindingFixture,
    AVBasic,
    AVComplete,
    AVBasicTypes,
    AVSources,
    AVCatalogue,
    AVBatch,
    AVActionStatus,
    AVS,
    AVO,
    AVD
} from "../helpers/StreamCurrentAuthorityViewCompleteBindingFixture.sol";
import {
    IStreamArtistArchiveOriginInventory as AVOriginInventory
} from "../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    IStreamCurrentAuthorityInventory as AVAuthorityInventory
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamArtistCurrentAuthorityResolver as AVResolver
} from "../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    StreamArtistCurrentAuthorityTypes as AVC
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamPreservationInventoryTypes as AVInventoryTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { IERC165 as AV165 } from "../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface AuthorityViewBindingFaultVm {
    function etch(address target, bytes calldata code) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @notice Actual A current-authority inventory commitment through real complete binding and VIEW catalogue.
/// @dev Positive construction/action/catalogue are unmocked. Negative cases explicitly inject runtime
/// or typed getter drift on that same real graph, then restore. These are not authorized immutable
/// mutations. Source identity admission is not minted membership, rendering, browser evidence or Finality.
/// Requires the published shared original-anchor commitment helper in both admission and dispatch.
contract StreamCurrentAuthorityViewCompleteBindingTest is
    StreamCurrentAuthorityViewCompleteBindingFixture
{
    AuthorityViewBindingFaultVm private constant avFaultVm =
        AuthorityViewBindingFaultVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testActualAuthorityCompleteBindingAndCatalogueUseCompositeOriginalCommitment() public {
        _authorityConstructViewBindingSources();
        _authorityRequireCompositeAnchor();
        _authorityBindCompleteView();
        bytes32 historical = _authorityViewHistoryHash();
        require(
            _authorityRequireViewCatalogue() != 0, "genuine VIEW catalogue after actual Safe action"
        );
        require(_authorityViewHistoryHash() == historical, "read dispatch preserves both receipts");
        require(
            assemblyCore.collectionMintedEver(1) == 0 && assemblyCore.totalSupply() == 0,
            "identity-only source admission before mint or evidence publication"
        );
    }

    function testActualOriginalInventoryRuntimeDriftRejectsPreviewAndScheduledWriteThenSameRetry()
        public
    {
        _authorityConstructViewBindingSources();
        AVBatch memory batch = _authorityViewBindingBatch();
        _admitAssemblyBatch(batch);
        avAction = _assemblyScheduleGovernance(batch, "urn:fixture:authority:view-runtime-retry");
        uint256 safeNonce = assemblyRoot.nonce();
        bytes32 dataHash = keccak256(abi.encode(batch));
        bytes memory runtime = address(assemblyInventory).code;
        avFaultVm.etch(address(assemblyInventory), hex"00");
        bytes memory reason = abi.encodeWithSelector(
            AVBasicTypes.ViewPreservationBindingDependency.selector, address(assemblyInventory)
        );
        _avRejectPreview(reason);
        assemblyVm.warp(assemblyExecutor.governanceAction(avAction).notBefore);
        (bool ok, bytes memory failure) = address(assemblyExecutor)
            .call(
                abi.encodeCall(
                    assemblyExecutor.executeGovernanceBatch,
                    (avAction, batch.calls, batch.callDatas)
                )
            );
        require(!ok && keccak256(failure) == keccak256(reason), "exact actual governed failure");
        require(
            assemblyExecutor.governanceAction(avAction).status == AVActionStatus.SCHEDULED
                && assemblyRoot.nonce() == safeNonce,
            "failed execution preserves scheduled action and consumed scheduling nonce"
        );
        _authorityRequireViewPending();
        avFaultVm.etch(address(assemblyInventory), runtime);
        require(keccak256(abi.encode(batch)) == dataHash, "identical original action calldata");
        require(
            keccak256(abi.encode(_authorityViewPreview())) == keccak256(abi.encode(avTransition)),
            "same exact proposal after restoration"
        );
        _authorityExecuteCompleteView(batch);
        require(
            assemblyRoot.nonce() == safeNonce,
            "retry executes the same action without another Safe schedule"
        );
        _authorityRequireViewCatalogue();
    }

    function testBoundOriginalInventoryRuntimeDriftRejectsOperativeReadsButRetainsHistory() public {
        _authorityConstructViewBindingSources();
        _authorityBindCompleteView();
        bytes32 history = _authorityViewHistoryHash();
        bytes32 catalogue = _authorityRequireViewCatalogue();
        bytes memory runtime = address(assemblyInventory).code;
        avFaultVm.etch(address(assemblyInventory), hex"00");
        _avRejectProvider(
            abi.encodeCall(AVSources.viewFinalitySources, ()),
            abi.encodeWithSelector(
                AVBasicTypes.ViewPreservationBindingDependency.selector, address(assemblyInventory)
            )
        );
        _avRejectCatalogue(
            abi.encodeWithSelector(
                AVInventoryTypes.InventoryRead.selector, address(assemblyInventory)
            )
        );
        require(
            _authorityViewHistoryHash() == history
                && AVBasic(address(assemblyProvider)).viewPreservationBindingStatus() == 1,
            "historical admission survives source runtime drift"
        );
        avFaultVm.etch(address(assemblyInventory), runtime);
        _authorityRequireCompleteView();
        require(
            _authorityRequireViewCatalogue() == catalogue && _authorityViewHistoryHash() == history,
            "exact restored selection and historical receipts"
        );
    }

    function testTypedOriginAuthorityProfileAndAnchorDriftRefuseThenRestoreOnActualGraph() public {
        _authorityConstructViewBindingSources();
        bytes32 preview = keccak256(abi.encode(_authorityViewPreview()));
        uint256 safeNonce = assemblyRoot.nonce();
        // These mock only one exact getter per negative. No linked validator or positive is mocked.
        for (uint8 fault; fault < 10; ++fault) {
            bytes memory reason = _avInjectGetterFault(fault);
            _avRejectPreview(reason);
            _authorityRequireViewPending();
            require(assemblyRoot.nonce() == safeNonce, "invalid getters do not schedule governance");
            avFaultVm.clearMockedCalls();
            _authorityRequireCompositeAnchor();
            require(
                keccak256(abi.encode(_authorityViewPreview())) == preview,
                "exact restored genuine preview"
            );
        }
        _authorityBindCompleteView();
        bytes32 history = _authorityViewHistoryHash();
        bytes32 catalogue = _authorityRequireViewCatalogue();
        for (uint8 fault; fault < 10; ++fault) {
            bytes memory reason = _avInjectGetterFault(fault);
            _avRejectProvider(abi.encodeCall(AVSources.viewFinalitySources, ()), reason);
            _avRejectCatalogue(reason);
            require(
                _authorityViewHistoryHash() == history,
                "typed getter drift retains historical receipts"
            );
            avFaultVm.clearMockedCalls();
            _authorityRequireCompleteView();
            require(
                _authorityRequireViewCatalogue() == catalogue,
                "genuine catalogue restored without rebinding"
            );
        }
    }

    function _avInjectGetterFault(uint8 fault) private returns (bytes memory expected) {
        address inv = address(assemblyInventory);
        AVD.Dependencies memory authority = assemblyInventory.authorityDependencies();
        address resolver = authority.resolver;
        expected = abi.encodeWithSignature("InvalidViewInventoryAnchor(address)", inv);
        if (fault == 0) {
            avFaultVm.mockCall(
                inv, abi.encodeCall(AVOriginInventory.originProfile, ()), abi.encode(bytes32(0))
            );
        } else if (fault == 1 || fault == 2) {
            AVO.Dependencies memory origin = assemblyInventory.originDependencies();
            if (fault == 1) origin.workerCodeHash ^= bytes32(uint256(1));
            else origin.profile ^= bytes32(uint256(1));
            avFaultVm.mockCall(
                inv, abi.encodeCall(AVOriginInventory.originDependencies, ()), abi.encode(origin)
            );
        } else if (fault == 3 || fault == 4) {
            if (fault == 3) authority.resolverCodeHash ^= bytes32(uint256(1));
            else authority.resolverGas += 1;
            avFaultVm.mockCall(
                inv,
                abi.encodeCall(AVAuthorityInventory.authorityDependencies, ()),
                abi.encode(authority)
            );
        } else if (fault == 5) {
            AVS.Dependencies memory anchor = assemblyInventory.originalAnchor();
            anchor.targets[0] = address(0xBAD);
            avFaultVm.mockCall(
                inv, abi.encodeCall(AVAuthorityInventory.originalAnchor, ()), abi.encode(anchor)
            );
            expected = abi.encodeWithSelector(AVInventoryTypes.InventoryRead.selector, inv);
        } else if (fault == 6) {
            AVC.Anchors memory anchors = AVResolver(resolver).anchors();
            anchors.targets[3] = address(0xBAD);
            avFaultVm.mockCall(
                resolver, abi.encodeCall(AVResolver.anchors, ()), abi.encode(anchors)
            );
            expected = abi.encodeWithSignature("InvalidViewInventoryAnchor(address)", resolver);
        } else if (fault == 7) {
            avFaultVm.mockCall(
                inv,
                abi.encodeWithSignature("dependencyHash()"),
                abi.encode(keccak256(abi.encode(assemblyInventory.dependencies())))
            );
        } else if (fault == 8) {
            avFaultVm.mockCall(
                resolver,
                abi.encodeCall(AVResolver.currentAuthorityProfile, ()),
                abi.encode(bytes32(0))
            );
            expected = abi.encodeWithSignature("InvalidViewInventoryAnchor(address)", resolver);
        } else {
            require(fault == 9, "closed fault table");
            avFaultVm.mockCall(
                resolver,
                abi.encodeCall(AV165.supportsInterface, (type(AVResolver).interfaceId)),
                abi.encode(false)
            );
            expected = abi.encodeWithSignature("InvalidViewInventoryAnchor(address)", resolver);
        }
    }

    function _avRejectPreview(bytes memory reason) private view {
        _avRejectProvider(
            abi.encodeCall(
                AVComplete.completeViewPreservationBindingTransition,
                (avConfiguration, avDeclaration, avSelection)
            ),
            reason
        );
    }

    function _avRejectCatalogue(bytes memory reason) private view {
        _avRejectProvider(
            abi.encodeCall(AVCatalogue.finalitySourcesForScope, (_authorityViewScope())), reason
        );
    }

    function _avRejectProvider(bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory actual) = address(assemblyProvider).staticcall(input);
        require(!ok && keccak256(actual) == keccak256(expected), "exact original source rejection");
    }
}
