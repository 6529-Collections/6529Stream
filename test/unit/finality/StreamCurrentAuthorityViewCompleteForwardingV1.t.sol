// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1 as Host
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as NativeScoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as ScopedGraph
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphSelectionV1 as CollectionGraph
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyGraphSelectionV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as ScopedBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationValidationV1 as BasicValidation
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationValidationV1.sol";
import {
    StreamFinalityViewPreservationCompleteValidationV1 as CompleteValidation
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationCompleteValidationV1.sol";
import {
    StreamFinalityViewPolicyFactoryBindingV1 as PolicyFactory
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPolicyFactoryBindingV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as BasicAPI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as CompleteAPI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamViewAdoptionTypes as Declaration
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface CurrentAuthorityViewForwardingVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function etch(address, bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract CurrentAuthorityViewForwardingTable {
    mapping(bytes32 => bytes) private answers;

    function set(bytes memory input, bytes memory output) external {
        answers[keccak256(input)] = output;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        bytes memory output = answers[keccak256(input)];
        require(output.length != 0, "unconfigured topology boundary");
        return output;
    }
}

/// @dev Exact six-word executor transport, not a Governance-V2/Safe ceremony. The production
/// binding worker still verifies msg.sender, this runtime pin, marker, and every action word.
contract CurrentAuthorityViewForwardingAuthority {
    bool private executing;
    bytes32 private actionId;
    uint8 private actionClass;
    Basic.Transition private transition;

    function configure(bool active, bytes32 id, uint8 cls, Basic.Transition memory t) external {
        executing = active;
        actionId = id;
        actionClass = cls;
        transition = t;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (
            executing,
            actionId,
            actionClass,
            transition.scopeHash,
            transition.oldValueHash,
            transition.newValueHash
        );
    }

    function execute(address target, bytes memory input) external returns (bytes memory output) {
        (bool ok, bytes memory result) = target.call(input);
        if (!ok) assembly { revert(add(result, 32), mload(result)) }
        return result;
    }
}

/// @notice Current-authority host forwarding with the real shared one-use binding state machine.
/// @dev Graph initialization and candidate admission are exact-calldata boundaries. No mock
/// replaces ViewBinding, its capability/guard/action checks, receipt writes, or history validation.
/// Synthetic candidate tuples below are not authenticated VIEW publications or source graphs.
/// These tests do not claim a genuine Safe action, full VIEW ceremony, current evidence, or gas fit.
contract StreamCurrentAuthorityViewCompleteForwardingV1Test {
    CurrentAuthorityViewForwardingVm private constant vm =
        CurrentAuthorityViewForwardingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ACTION = keccak256("fixture original complete action");
    Native.Config private original;
    NativeScoped.Config private nativeScoped;
    ScopedGraph.Context private graph;
    CollectionBinding.CollectionFactoryBinding private collectionBinding;
    Host private host;
    CurrentAuthorityViewForwardingAuthority private authority;
    Basic.Configuration private configuration;
    Declaration.Binding private declaration;
    Basic.Receipt private candidate;
    Sources.Receipt private completeCandidate;
    bytes32 private fixedSourceHash;
    bytes32 private fixedCatalogueHash;
    error UnexpectedBoundaryArguments();
    error PolicyBoundaryRejected();
    error SourceBindingsDrifted();

    function setUp() public {
        for (uint256 i; i < 22; ++i) {
            original.targets[i] = address(new CurrentAuthorityViewForwardingTable());
            original.codeHashes[i] = original.targets[i].codehash;
        }
        original.chainId = block.chainid;
        original.readGas = 1000000;
        original.componentSourceGas = 16000000;
        original.sourceGas = 40000000;
        original.inventoryDependencyHash = keccak256("fixed original inventory dependency hash");
        nativeScoped = abi.decode(abi.encode(original), (NativeScoped.Config));
        authority = new CurrentAuthorityViewForwardingAuthority();
        _set(original.targets[1], "core()", abi.encode(original.targets[0]));
        _set(original.targets[1], "governanceAuthority()", abi.encode(address(authority)));
        _set(original.targets[1], "executorCodeHash()", abi.encode(address(authority).codehash));
        _set(original.targets[2], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "metadataHost()", abi.encode(original.targets[1]));
        _support(original.targets[2], type(Serving).interfaceId);
        _support(original.targets[2], type(Router).interfaceId);
        for (uint256 i = 1; i < 3; ++i) {
            _set(original.targets[i], "streamModuleVersion()", abi.encode(keccak256("version")));
            _set(
                original.targets[i],
                "streamModuleManifest()",
                abi.encode("urn:fixture", keccak256("manifest"))
            );
        }
        ScopedBinding.FactoryBinding memory b;
        b.factory = address(new CurrentAuthorityViewForwardingTable());
        b.factoryCodeHash = b.factory.codehash;
        b.recipeHash = keccak256("scoped preservation recipe");
        b.sourceFactoryDependenciesHash = keccak256("fixed scoped source factory configuration");
        b.graphGas = 4000000;
        b.configurationHash = keccak256("scoped graph binding");
        graph.original = original;
        graph.binding = b;
        graph.recipe.targets[2] = address(new CurrentAuthorityViewForwardingTable());
        graph.recipe.codeHashes[2] = graph.recipe.targets[2].codehash;
        // Constructor input has no admitted configuration hash. The typed graph boundary
        // returns its distinct admitted binding, which alone enters the fixed source hash.
        ScopedBinding.FactoryBinding memory inputBinding =
            abi.decode(abi.encode(b), (ScopedBinding.FactoryBinding));
        inputBinding.configurationHash = 0;
        _allow(
            address(ScopedGraph),
            ScopedGraph.initialize.selector,
            abi.encodeWithSelector(ScopedGraph.initialize.selector, original, inputBinding),
            abi.encode(graph)
        );
        collectionBinding.factory = address(new CurrentAuthorityViewForwardingTable());
        collectionBinding.factoryCodeHash = collectionBinding.factory.codehash;
        collectionBinding.recipeHash = keccak256("collection preservation recipe");
        collectionBinding.sourceFactoryDependenciesHash =
            keccak256("collection source factory configuration");
        collectionBinding.graphGas = 4000000;
        collectionBinding.configurationHash = keccak256("collection graph binding");
        CollectionGraph.Context memory collection;
        collection.original = original;
        collection.binding = collectionBinding;
        CollectionBinding.CollectionFactoryBinding memory collectionInput =
            abi.decode(abi.encode(collectionBinding), (CollectionBinding.CollectionFactoryBinding));
        collectionInput.configurationHash = 0;
        _allow(
            address(CollectionGraph),
            CollectionGraph.initialize.selector,
            abi.encodeWithSelector(CollectionGraph.initialize.selector, original, collectionInput),
            abi.encode(collection)
        );
        host = new Host(original, nativeScoped, collectionInput, inputBinding);
        fixedSourceHash = keccak256(
            abi.encode(
                keccak256(
                    "6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"
                ),
                block.chainid,
                address(host),
                original,
                nativeScoped,
                collectionBinding,
                b
            )
        );
        fixedCatalogueHash = _catalogueHash();
        _candidateBoundary();
        _allowPolicy();
        _requireFixedSources();
    }

    function testCompleteInterfacesProfileAndPendingKeepOriginalSourceConfiguration() public view {
        require(host.supportsInterface(type(IERC165).interfaceId));
        require(host.supportsInterface(type(BasicAPI).interfaceId));
        require(host.supportsInterface(type(CompleteAPI).interfaceId));
        require(host.supportsInterface(type(Sources).interfaceId));
        require(!host.supportsInterface(0xffffffff));
        require(
            host.completeViewPreservationBindingProfile()
                == keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1")
        );
        Basic.Capability memory cap = host.viewPreservationBindingCapability();
        require(
            cap.authority == address(authority)
                && cap.authorityCodeHash == address(authority).codehash
        );
        require(cap.originalHash == keccak256(abi.encode(original)));
        require(cap.capabilityHash == Basic.hashCapability(block.chainid, address(host), cap));
        _requirePending();
        _requireFixedSources();
    }

    function testCompletePreviewUsesExactOriginalCandidateAndFactoryJoin() public {
        bytes memory policyFailure = abi.encodeWithSelector(PolicyBoundaryRejected.selector);
        vm.mockCallRevert(address(PolicyFactory), _policyInput(), policyFailure);
        _reverts(address(host), _previewInput(), policyFailure);
        _requirePending();
        _allowPolicy();
        Basic.Transition memory actual = host.completeViewPreservationBindingTransition(
            configuration, declaration, completeCandidate.selection
        );
        Basic.Transition memory expected = _completeTransition();
        require(keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)));
        require(
            actual.newValueHash != Basic.proposalHash(candidate),
            "complete proposal is not basic proposal"
        );
        _requirePending();
        _requireFixedSources();
    }

    function testCompleteBindReturnsAndEmitsBothReceiptsWithOneOriginalAction() public {
        Basic.Transition memory t = _completeTransition();
        authority.configure(true, ACTION, 2, t);
        vm.recordLogs();
        bytes32 returned = abi.decode(authority.execute(address(host), _bindInput()), (bytes32));
        CurrentAuthorityViewForwardingVm.Log[] memory logs = vm.getRecordedLogs();
        (Basic.Receipt memory basic, Sources.Receipt memory complete) = _requireComplete();
        require(returned == complete.recordHash && basic.actionId == ACTION);
        bytes32 signature =
            keccak256("ViewPreservationCompleteBound(bytes32,bytes32,bytes32,bytes32)");
        uint256 matched;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(host) || logs[i].topics.length == 0
                    || logs[i].topics[0] != signature
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == complete.recordHash
                    && logs[i].topics[2] == basic.recordHash && logs[i].topics[3] == ACTION
            );
            require(keccak256(logs[i].data) == keccak256(abi.encode(t.newValueHash)));
            ++matched;
        }
        require(matched == 1, "one exact complete event");
        _requireFixedSources();
    }

    function testCompleteBindingClosesBothWritesAndBothPreviewsBeforeCandidateReads() public {
        _bindComplete();
        bytes32 retained = _historyHash();
        _closeCandidateBoundaries();
        _requireClosed();
        require(_historyHash() == retained);
        _requireFixedSources();
    }

    function testBasicBindingClosesCompleteRouteWithoutInventingCompleteReceipt() public {
        Basic.Transition memory t =
            host.viewPreservationBindingTransition(configuration, declaration);
        authority.configure(true, ACTION, 2, t);
        bytes32 returned = abi.decode(
            authority.execute(
                address(host),
                abi.encodeCall(BasicAPI.bindViewPreservation, (configuration, declaration))
            ),
            (bytes32)
        );
        Basic.Receipt memory saved = host.viewPreservationBindingReceipt();
        require(saved.recordHash == returned && saved.recordHash == Basic.receiptHash(saved));
        require(saved.actionId == ACTION && host.viewPreservationBindingStatus() == 1);
        _closeCandidateBoundaries();
        _requireClosed();
        _requireNoComplete();
        require(
            keccak256(abi.encode(host.viewPreservationBindingReceipt()))
                == keccak256(abi.encode(saved))
        );
        _requireFixedSources();
    }

    function testBasicOnlyGovernanceContextRollsBackCompleteWriteThenExactRetry() public {
        Basic.Transition memory full = host.completeViewPreservationBindingTransition(
            configuration, declaration, completeCandidate.selection
        );
        Basic.Transition memory inner =
            host.viewPreservationBindingTransition(configuration, declaration);
        require(inner.newValueHash != full.newValueHash);
        authority.configure(true, ACTION, 2, inner);
        _callReverts(
            address(authority),
            abi.encodeCall(authority.execute, (address(host), _bindInput())),
            abi.encodeWithSelector(Basic.ViewPreservationBindingGovernance.selector)
        );
        _requirePending();
        Basic.Transition memory afterFailure = host.completeViewPreservationBindingTransition(
            configuration, declaration, completeCandidate.selection
        );
        require(keccak256(abi.encode(afterFailure)) == keccak256(abi.encode(full)));
        _requireFixedSources();
        authority.configure(true, ACTION, 2, full);
        authority.execute(address(host), _bindInput());
        _requireComplete();
        _requireFixedSources();
    }

    function testHistoricalReceiptsSurviveWhileOperativeSelectionRechecksBindings() public {
        _bindComplete();
        (, Sources.Receipt memory saved) = _requireComplete();
        bytes32 retained = _historyHash();
        _allowCurrentBindings();
        require(
            keccak256(abi.encode(host.viewFinalitySources()))
                == keccak256(abi.encode(saved.selection))
        );
        // This is an actual pinned-executor runtime failure in the unmocked shared _capability.
        bytes memory runtime = address(authority).code;
        vm.etch(address(authority), hex"00");
        _reverts(
            address(host),
            abi.encodeCall(Sources.viewFinalitySources, ()),
            abi.encodeWithSelector(
                Basic.ViewPreservationBindingDependency.selector, address(authority)
            )
        );
        require(_historyHash() == retained, "history must not call operative capability validation");
        vm.etch(address(authority), runtime);
        // The identity/reciprocity worker remains a named boundary, not a fabricated current publication.
        bytes memory failure = abi.encodeWithSelector(SourceBindingsDrifted.selector);
        vm.mockCallRevert(address(CompleteValidation), _currentBindingsInput(), failure);
        _reverts(address(host), abi.encodeCall(Sources.viewFinalitySources, ()), failure);
        require(_historyHash() == retained, "history must not call source bindings");
        _allowCurrentBindings();
        require(
            keccak256(abi.encode(host.viewFinalitySources()))
                == keccak256(abi.encode(saved.selection))
        );
        require(_historyHash() == retained);
        _requireFixedSources();
    }

    function _candidateBoundary() private {
        configuration = Basic.Configuration(
            original.targets[8],
            original.codeHashes[8],
            12000000,
            original.targets[9],
            original.codeHashes[9],
            original.targets[10],
            original.codeHashes[10]
        );
        declaration = Declaration.Binding(
            original.targets[6],
            original.codeHashes[6],
            original.targets[3],
            original.codeHashes[3],
            1000000,
            4000000
        );
        candidate.capabilityHash = host.viewPreservationBindingCapability().capabilityHash;
        candidate.configuration = configuration;
        candidate.declaration = declaration;
        for (uint256 i; i < 10; ++i) {
            candidate.dependencies.targets[i] = original.targets[i];
            candidate.dependencies.codeHashes[i] = original.codeHashes[i];
        }
        candidate.dependencies.chainId = block.chainid;
        candidate.dependencies.readGas = original.readGas;
        candidate.dependencies.sourceGas = 4000000;
        candidate.dependencies.inventoryGas = 2000000;
        candidate.dependenciesHash = keccak256(abi.encode(candidate.dependencies));
        candidate.workersHash = keccak256("synthetic admitted worker roster boundary");
        completeCandidate.selection = Sources.Selection(
            original.targets[7],
            original.codeHashes[7],
            original.targets[18],
            original.codeHashes[18],
            original.targets[19],
            original.codeHashes[19]
        );
        completeCandidate.referenceDependenciesHash =
            keccak256("synthetic reference constructor boundary");
        completeCandidate.inventoryDependenciesHash =
            keccak256("synthetic inventory constructor boundary");
        completeCandidate.bundleDependenciesHash =
            keccak256("synthetic bundle constructor boundary");
        _allow(
            address(BasicValidation),
            BasicValidation.read.selector,
            _basicInput(),
            abi.encode(candidate)
        );
        _allow(
            address(CompleteValidation),
            CompleteValidation.read.selector,
            _completeInput(),
            abi.encode(completeCandidate)
        );
    }

    function _basicInput() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            BasicValidation.read.selector,
            original,
            host.viewPreservationBindingCapability(),
            configuration,
            declaration
        );
    }

    function _completeInput() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            CompleteValidation.read.selector, original, candidate, completeCandidate.selection
        );
    }

    function _policyInput() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            PolicyFactory.validate.selector,
            original,
            graph.recipe.targets[2],
            graph.recipe.codeHashes[2],
            graph.binding.sourceFactoryDependenciesHash
        );
    }

    function _allowPolicy() private {
        _allow(address(PolicyFactory), PolicyFactory.validate.selector, _policyInput(), bytes(""));
    }

    function _currentBindingsInput() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            CompleteValidation.requireBindings.selector,
            original,
            host.viewPreservationBindingReceipt(),
            completeCandidate.selection
        );
    }

    function _allowCurrentBindings() private {
        _allow(
            address(CompleteValidation),
            CompleteValidation.requireBindings.selector,
            _currentBindingsInput(),
            bytes("")
        );
    }

    function _allow(address target, bytes4 selector, bytes memory input, bytes memory output)
        private
    {
        vm.mockCallRevert(
            target,
            abi.encodePacked(selector),
            abi.encodeWithSelector(UnexpectedBoundaryArguments.selector)
        );
        vm.mockCall(target, input, output);
    }

    function _previewInput() private view returns (bytes memory) {
        return abi.encodeCall(
            CompleteAPI.completeViewPreservationBindingTransition,
            (configuration, declaration, completeCandidate.selection)
        );
    }

    function _bindInput() private view returns (bytes memory) {
        return abi.encodeCall(
            CompleteAPI.bindCompleteViewPreservation,
            (configuration, declaration, completeCandidate.selection)
        );
    }

    function _completeTransition() private view returns (Basic.Transition memory t) {
        bytes32 profile = keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1");
        t.scopeHash =
            keccak256(abi.encode(profile, block.chainid, address(host), candidate.capabilityHash));
        t.oldValueHash = keccak256(abi.encode(profile, candidate.capabilityHash, false));
        t.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"),
                Basic.proposalHash(candidate),
                completeCandidate.selection,
                completeCandidate.referenceDependenciesHash,
                completeCandidate.inventoryDependenciesHash,
                completeCandidate.bundleDependenciesHash
            )
        );
    }

    function _bindComplete() private {
        authority.configure(true, ACTION, 2, _completeTransition());
        authority.execute(address(host), _bindInput());
        _requireComplete();
    }

    function _requireComplete()
        private
        view
        returns (Basic.Receipt memory b, Sources.Receipt memory c)
    {
        b = host.viewPreservationBindingReceipt();
        c = host.viewFinalitySourcesReceipt();
        require(host.viewPreservationBindingStatus() == 1 && b.recordHash != 0 && c.recordHash != 0);
        require(b.recordHash == Basic.receiptHash(b) && c.basicBindingRecordHash == b.recordHash);
        require(
            Basic.proposalHash(b) == Basic.proposalHash(candidate),
            "complete original candidate retained"
        );
        require(b.actionId == ACTION && c.actionId == ACTION && c.boundAt == b.boundAt);
        require(
            keccak256(abi.encode(c.selection)) == keccak256(abi.encode(completeCandidate.selection))
        );
        require(
            c.referenceDependenciesHash == completeCandidate.referenceDependenciesHash
                && c.inventoryDependenciesHash == completeCandidate.inventoryDependenciesHash
                && c.bundleDependenciesHash == completeCandidate.bundleDependenciesHash
        );
        require(
            c.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                        block.chainid,
                        address(host),
                        c.selection,
                        c.referenceDependenciesHash,
                        c.inventoryDependenciesHash,
                        c.bundleDependenciesHash,
                        c.basicBindingRecordHash,
                        c.actionId,
                        c.boundAt
                    )
                )
        );
    }

    function _historyHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(host.viewPreservationBindingReceipt(), host.viewFinalitySourcesReceipt())
        );
    }

    function _requirePending() private view {
        Basic.Receipt memory empty;
        require(
            keccak256(abi.encode(host.viewPreservationBindingReceipt()))
                == keccak256(abi.encode(empty)),
            "no partial basic receipt after failed action"
        );
        require(
            host.viewPreservationBindingStatus() == 0
                && host.viewPreservationBindingReceipt().recordHash == 0
        );
        _requireNoComplete();
    }

    function _requireNoComplete() private view {
        bytes memory reason =
            abi.encodeWithSelector(Complete.ViewPreservationCompleteBindingUnavailable.selector);
        _reverts(address(host), abi.encodeCall(Sources.viewFinalitySources, ()), reason);
        _reverts(address(host), abi.encodeCall(Sources.viewFinalitySourcesReceipt, ()), reason);
    }

    function _closeCandidateBoundaries() private {
        bytes memory reason = abi.encodeWithSelector(UnexpectedBoundaryArguments.selector);
        vm.mockCallRevert(address(PolicyFactory), _policyInput(), reason);
        vm.mockCallRevert(address(BasicValidation), _basicInput(), reason);
        vm.mockCallRevert(address(CompleteValidation), _completeInput(), reason);
    }

    function _requireClosed() private {
        // Empty malformed candidates and a non-authority caller must still see the same first guard.
        Basic.Configuration memory empty;
        Declaration.Binding memory emptyDeclaration;
        Sources.Selection memory emptySelection;
        bytes memory reason = abi.encodeWithSelector(Basic.ViewPreservationAlreadyBound.selector);
        _reverts(
            address(host),
            abi.encodeCall(BasicAPI.viewPreservationBindingTransition, (empty, emptyDeclaration)),
            reason
        );
        _callReverts(
            address(host),
            abi.encodeCall(BasicAPI.bindViewPreservation, (empty, emptyDeclaration)),
            reason
        );
        _reverts(
            address(host),
            abi.encodeCall(
                CompleteAPI.completeViewPreservationBindingTransition,
                (empty, emptyDeclaration, emptySelection)
            ),
            reason
        );
        _callReverts(
            address(host),
            abi.encodeCall(
                CompleteAPI.bindCompleteViewPreservation, (empty, emptyDeclaration, emptySelection)
            ),
            reason
        );
    }

    function _catalogueHash() private view returns (bytes32) {
        return keccak256(abi.encode(host.finalitySourceProfile(0), host.finalitySourceProfile(1)));
    }

    function _requireFixedSources() private view {
        require(
            host.finalitySourceConfigurationHash() == fixedSourceHash,
            "constructor source hash unchanged"
        );
        require(_catalogueHash() == fixedCatalogueHash, "original static catalogues unchanged");
    }

    function _set(address target, string memory signature, bytes memory output) private {
        CurrentAuthorityViewForwardingTable(target).set(abi.encodeWithSignature(signature), output);
    }

    function _support(address target, bytes4 id) private {
        CurrentAuthorityViewForwardingTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        CurrentAuthorityViewForwardingTable(target)
            .set(
                abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                abi.encode(true)
            );
        CurrentAuthorityViewForwardingTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false));
    }

    function _reverts(address target, bytes memory input, bytes memory reason) private view {
        (bool ok, bytes memory output) = target.staticcall(input);
        require(!ok && keccak256(output) == keccak256(reason), "exact read rejection");
    }

    function _callReverts(address target, bytes memory input, bytes memory reason) private {
        (bool ok, bytes memory output) = target.call(input);
        require(!ok && keccak256(output) == keccak256(reason), "exact mutation rejection");
    }
}
