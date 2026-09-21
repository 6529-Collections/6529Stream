// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewRetrievalConfigurationFixture.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationConfigurationV1.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryIO.sol";

import {
    StreamFinalityViewSameHostReadsV1 as SameHost
} from "../../../smart-contracts/domains/finality/StreamFinalityViewSameHostReadsV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamFinalityViewPreservationSourceSelectionV1 as Check
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationSourceSelectionV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationReferencePublicationV1 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationReferencePublicationV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    IStreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as Definitions
} from "../../../smart-contracts/domains/records/StreamViewPreservationReferenceDefinitionsV1.sol";

interface ViewConfigurationBudgetVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @dev Explicit constructor/getter boundary; every unconfigured current-evidence selector refuses.
contract ViewConfigurationBoundary {
    mapping(bytes32 => bytes) internal responses;

    function set(bytes memory input, bytes memory output) external {
        responses[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory output = responses[keccak256(msg.data)];
        require(output.length != 0, "unconfigured current-evidence or selector");
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

contract ViewConfigurationSelectionProbe {
    function check(Selection.Selection memory s, Check.Expected memory e, uint256 cap)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return Check.requireBindings(s, e, cap);
    }
}

/// @notice Typed identity/reciprocity tests only. No governed bind or current evidence is mocked as accepted.
abstract contract ViewFinalityConfigurationFixture is CharacterizationTestBase {
    Check.Expected internal expected;
    Selection.Selection internal selected;
    R.Dependencies internal referenceDeps;
    I.Dependencies internal inventory;
    B.Dependencies internal bundle;
    ViewConfigurationSelectionProbe internal probe;
    uint256 internal originalChain;
    address internal retrievalWitness;

    function _word(address a, string memory selector, bytes32 word) internal {
        ViewConfigurationBoundary(a).set(abi.encodeWithSignature(selector), abi.encode(word));
    }

    function _address(address a, string memory selector, address value) internal {
        _word(a, selector, bytes32(uint256(uint160(value))));
    }

    function _support(address a, bytes4 id, bool yes) internal {
        ViewConfigurationBoundary(a)
            .set(abi.encodeWithSignature("supportsInterface(bytes4)", id), abi.encode(yes));
    }

    function _reference() internal {
        ViewConfigurationBoundary(selected.referencePublication)
            .set(abi.encodeCall(Reference.dependencies, ()), abi.encode(referenceDeps));
    }

    function _inventory() internal {
        ViewConfigurationBoundary(selected.renderCriticalInventory)
            .set(abi.encodeCall(Inventory.dependencies, ()), abi.encode(inventory));
        _word(
            selected.renderCriticalInventory, "dependencyHash()", keccak256(abi.encode(inventory))
        );
    }

    function _bundle() internal {
        ViewConfigurationBoundary(selected.bundleArchiveCoverage)
            .set(abi.encodeWithSignature("dependencies()"), abi.encode(bundle));
        _word(selected.bundleArchiveCoverage, "dependencyHash()", keccak256(abi.encode(bundle)));
    }

    function setUp() public virtual {
        originalChain = block.chainid;
        for (uint256 i; i < 12; ++i) {
            expected.targets[i] = address(new ViewConfigurationBoundary());
            expected.codeHashes[i] = expected.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            expected.artistTargets[i] = address(new ViewConfigurationBoundary());
            expected.artistCodeHashes[i] = expected.artistTargets[i].codehash;
        }
        expected.artistContentOwner = address(new ViewConfigurationBoundary());
        expected.artistContentOwnerCodeHash = expected.artistContentOwner.codehash;
        expected.chainId = originalChain;
        selected = Selection.Selection(
            expected.targets[6],
            expected.codeHashes[6],
            address(new ViewConfigurationBoundary()),
            0,
            address(new ViewConfigurationBoundary()),
            0
        );
        selected.renderCriticalInventoryCodeHash = selected.renderCriticalInventory.codehash;
        selected.bundleArchiveCoverageCodeHash = selected.bundleArchiveCoverage.codehash;
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            referenceDeps.targets[i] = expected.targets[roles[i]];
            referenceDeps.codeHashes[i] = expected.codeHashes[roles[i]];
        }
        referenceDeps.chainId = originalChain;
        referenceDeps.readGas = 2000000;
        referenceDeps.sourceGas = 12000000;
        referenceDeps.snapshotGas = 16000000;
        referenceDeps.archiveGas = 8000000;
        _reference();
        address ref = selected.referencePublication;
        _support(ref, type(Reference).interfaceId, true);
        _support(ref, type(IStreamArtworkScopedFinalityComponent).interfaceId, true);
        _address(ref, "core()", expected.targets[0]);
        _address(ref, "metadataHost()", expected.targets[1]);
        _address(ref, "metadataRouter()", expected.targets[4]);
        _address(ref, "snapshots()", expected.targets[5]);
        _address(ref, "archiveCoverage()", expected.targets[11]);
        _word(ref, "deploymentChainId()", bytes32(originalChain));
        _word(ref, "streamModuleType()", keccak256("REFERENCE_RENDER"));
        _word(
            ref,
            "streamModuleVersion()",
            keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_IMPLEMENTATION_V1")
        );
        _word(ref, "streamModuleSchemaHash()", Definitions.SCHEMA_HASH);
        ViewConfigurationBoundary(ref)
            .set(
                abi.encodeWithSignature("streamModuleManifest()"),
                abi.encode("typed configuration", Definitions.PROFILE_HASH)
            );
        inventory.targets = expected.targets;
        inventory.codeHashes = expected.codeHashes;
        inventory.artistTargets = expected.artistTargets;
        inventory.artistCodeHashes = expected.artistCodeHashes;
        inventory.artistContentOwner = expected.artistContentOwner;
        inventory.artistContentOwnerCodeHash = expected.artistContentOwnerCodeHash;
        inventory.chainId = originalChain;
        inventory.readGas = 2000000;
        inventory.sourceGas = 18000000;
        inventory.selectionGas = 8000000;
        inventory.snapshotGas = 18000000;
        inventory.referenceGas = 24000000;
        _inventory();
        address inv = selected.renderCriticalInventory;
        _support(inv, type(Inventory).interfaceId, true);
        _word(
            inv,
            "inventoryProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1")
        );
        _address(inv, "core()", expected.targets[0]);
        _address(inv, "metadataHost()", expected.targets[1]);
        _address(inv, "metadataRouter()", expected.targets[4]);
        _address(inv, "snapshots()", expected.targets[5]);
        _address(inv, "referencePublisher()", expected.targets[6]);
        _address(inv, "artifactCoverage()", expected.targets[10]);
        _address(inv, "externalCoverage()", expected.targets[11]);
        bundle.targets = [
            expected.targets[0],
            expected.targets[1],
            inv,
            expected.targets[10],
            expected.targets[11],
            expected.artistTargets[4]
        ];
        bundle.codeHashes = [
            expected.codeHashes[0],
            expected.codeHashes[1],
            inv.codehash,
            expected.codeHashes[10],
            expected.codeHashes[11],
            expected.artistCodeHashes[4]
        ];
        bundle.chainId = originalChain;
        bundle.readGas = 2000000;
        bundle.archiveGas = 8000000;
        _bundle();
        address cov = selected.bundleArchiveCoverage;
        _support(cov, type(Bundle).interfaceId, true);
        _word(
            cov,
            "bundleProfile()",
            keccak256("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1")
        );
        _word(cov, "deploymentChainId()", bytes32(originalChain));
        _word(cov, "coreCodeHash()", expected.codeHashes[0]);
        _word(cov, "metadataCodeHash()", expected.codeHashes[1]);
        _word(cov, "inventoryCodeHash()", inv.codehash);
        _address(cov, "core()", expected.targets[0]);
        _address(cov, "metadataHost()", expected.targets[1]);
        _address(cov, "renderCriticalInventory()", inv);
        _address(cov, "artifactCoverage()", expected.targets[10]);
        _address(cov, "externalCoverage()", expected.targets[11]);
        retrievalWitness = ViewRetrievalConfigurationFixture.configure(inventory, true);
        ViewRetrievalConfigurationFixture.bind(selected.renderCriticalInventory, retrievalWitness);
        probe = new ViewConfigurationSelectionProbe();
    }
}

/// @dev The same strict child-read shape as ViewBinding.current is explicit here. Actual
/// ViewBinding/provider governance is tested by its owner, not substituted by this boundary.
contract ViewFinalityConfigurationHost {
    Native.Config private original;
    Selection.Receipt private saved;
    address private snapshot;
    address private factory;

    function configure(
        Native.Config memory c,
        Selection.Selection memory selection,
        address snap,
        address entropy
    ) external {
        original = c;
        snapshot = snap;
        factory = entropy;
        saved.selection = selection;
        saved.referenceDependenciesHash = keccak256("initial reference dependencies");
        saved.inventoryDependenciesHash = keccak256("initial inventory dependencies");
        saved.bundleDependenciesHash = keccak256("initial bundle dependencies");
        saved.basicBindingRecordHash = keccak256("actual basic record fixture");
        saved.actionId = keccak256("class2 action fixture");
        saved.boundAt = uint64(block.timestamp);
        saved.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                c.chainId,
                address(this),
                selection,
                saved.referenceDependenciesHash,
                saved.inventoryDependenciesHash,
                saved.bundleDependenciesHash,
                saved.basicBindingRecordHash,
                saved.actionId,
                saved.boundAt
            )
        );
    }

    function viewFinalitySources() external view returns (Selection.Selection memory) {
        return saved.selection;
    }

    function viewFinalitySourcesReceipt() external view returns (Selection.Receipt memory) {
        return saved;
    }

    function _nested() private view {
        require(
            abi.decode(
                IO.fixedRead(
                    original.targets[0],
                    abi.encodeWithSignature("bindingProbe()"),
                    32,
                    original.readGas
                ),
                (uint256)
            ) == 7
        );
    }

    function viewPreservationSnapshotHost() external view returns (address) {
        _nested();
        return snapshot;
    }

    function viewPreservationSnapshotCodeHash() external view returns (bytes32) {
        _nested();
        return snapshot.codehash;
    }

    function viewPreservationSnapshotValidationGas() external view returns (uint256) {
        _nested();
        return 16000000;
    }

    function viewPolicySourceFactoryV2() external view returns (address) {
        return factory;
    }

    function viewPolicySourceFactoryV2CodeHash() external view returns (bytes32) {
        return factory.codehash;
    }

    function resolveAndInputHashes()
        external
        view
        returns (Configuration.Context memory x, bytes32 beforeHash, bytes32 afterHash)
    {
        Native.Config memory c = original;
        beforeHash = keccak256(abi.encode(c));
        x = Configuration.resolve(c);
        afterHash = keccak256(abi.encode(c));
    }

    function catalogue(StreamFinalityScope memory scope)
        external
        view
        returns (Profiles.Sources memory)
    {
        return Configuration.catalogue(original, scope);
    }

    function closedAt(bytes4 selector, uint256 ceiling) external view returns (bytes memory) {
        return SameHost.read(selector, ceiling);
    }

    function snapshotAt(uint256 cap) external view returns (address) {
        return abi.decode(
            IO.fixedRead(
                address(this), abi.encodeWithSignature("viewPreservationSnapshotHost()"), 32, cap
            ),
            (address)
        );
    }
}

/// @dev One additional real call frame models a component adapter; dependency graph remains typed.
contract ViewConfigurationOuterProbe {
    function resolve(ViewFinalityConfigurationHost target)
        external
        view
        returns (Configuration.Context memory, bytes32, bytes32)
    {
        return target.resolveAndInputHashes();
    }
}

contract StreamFinalityViewPreservationConfigurationV1Test is ViewFinalityConfigurationFixture {
    ViewFinalityConfigurationHost private host;
    Native.Config private config;
    I.Dependencies private originalInventory;
    address private factory;

    function setUp() public override {
        super.setUp();
        vm.warp(100);
        host = new ViewFinalityConfigurationHost();
        for (uint256 i; i < 22; ++i) {
            config.targets[i] = address(new ViewConfigurationBoundary());
            config.codeHashes[i] = config.targets[i].codehash;
        }
        uint256[12] memory roles = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            config.targets[roles[i]] = expected.targets[i];
            config.codeHashes[roles[i]] = expected.codeHashes[i];
        }
        config.targets[8] = address(new ViewConfigurationBoundary());
        config.codeHashes[8] = config.targets[8].codehash;
        config.targets[9] = address(new ViewConfigurationBoundary());
        config.codeHashes[9] = config.targets[9].codehash;
        config.targets[11] = expected.artistTargets[0];
        config.codeHashes[11] = expected.artistCodeHashes[0];
        originalInventory = inventory;
        originalInventory.targets[5] = config.targets[8];
        originalInventory.codeHashes[5] = config.codeHashes[8];
        originalInventory.targets[6] = config.targets[9];
        originalInventory.codeHashes[6] = config.codeHashes[9];
        config.chainId = originalChain;
        config.readGas = 500000;
        config.componentSourceGas = 2000000;
        config.sourceGas = 4000000;
        config.inventoryDependencyHash = keccak256(abi.encode(originalInventory));
        ViewConfigurationBoundary(config.targets[18])
            .set(abi.encodeWithSignature("dependencies()"), abi.encode(originalInventory));
        ViewConfigurationBoundary(config.targets[0])
            .set(abi.encodeWithSignature("bindingProbe()"), abi.encode(uint256(7)));
        _address(config.targets[12], "scopeEvidenceProvider()", address(host));
        _address(config.targets[13], "scopeEvidenceProvider()", address(host));
        _address(config.targets[14], "evidenceProvider()", address(host));
        factory = address(new ViewConfigurationBoundary());
        host.configure(config, selected, expected.targets[5], factory);
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 7, 0, keccak256("full sealed membership")
        );
    }

    function testDeepProjectionAndCatalogueCommitOriginalConstructorConfig() public view {
        (Configuration.Context memory x, bytes32 beforeHash, bytes32 afterHash) =
            host.resolveAndInputHashes();
        bytes32 originalHash = keccak256(abi.encode(config));
        require(beforeHash == originalHash && afterHash == originalHash, "caller memory retained");
        require(
            keccak256(abi.encode(x.effective)) != originalHash
                && x.effective.targets[8] == expected.targets[5]
                && x.effective.targets[18] == selected.renderCriticalInventory,
            "distinct effective projection"
        );
        Profiles.Sources memory p = host.catalogue(_scope());
        Selection.Receipt memory r = host.viewFinalitySourcesReceipt();
        bytes32 literal = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1"),
                originalChain,
                address(host),
                originalHash,
                r.recordHash
            )
        );
        require(
            p.profile.configurationHash == literal,
            "internal resolve must not alias catalogue original hash"
        );
        require(
            p.profile.configurationHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1"),
                        originalChain,
                        address(host),
                        keccak256(abi.encode(x.effective)),
                        r.recordHash
                    )
                ),
            "effective hash cannot replace original"
        );
        require(
            keccak256(abi.encode(p.scope)) == keccak256(abi.encode(_scope()))
                && p.profile.entropyFactory == factory
        );
    }

    function testNestedEqualCapRefusesExistingSourceOuterSucceeds() public {
        (bool ok,) = address(host).call(abi.encodeCall(host.snapshotAt, (config.readGas)));
        require(!ok, "equal outer cap cannot forward full original child cap");
        require(host.snapshotAt(config.sourceGas) == expected.targets[5]);
        host.resolveAndInputHashes();
    }

    function testCurrentReferenceBudgetChangePreservesHistoricalSelectionCommitment() public {
        Profiles.Sources memory before_ = host.catalogue(_scope());
        Selection.Receipt memory originalReceipt = host.viewFinalitySourcesReceipt();
        referenceDeps.sourceGas += 1000000;
        _reference();
        host.resolveAndInputHashes();
        require(
            keccak256(abi.encode(before_)) == keccak256(abi.encode(host.catalogue(_scope()))),
            "current gas is not a replacement historical receipt"
        );
        require(
            keccak256(abi.encode(originalReceipt))
                == keccak256(abi.encode(host.viewFinalitySourcesReceipt()))
        );
    }

    function testSelectedRuntimeAndCompleteScopeRefuseRestore() public {
        host.resolveAndInputHashes();
        bytes memory code = selected.referencePublication.code;
        vm.etch(selected.referencePublication, hex"00");
        (bool ok,) = address(host).call(abi.encodeCall(host.resolveAndInputHashes, ()));
        require(!ok);
        vm.etch(selected.referencePublication, code);
        host.resolveAndInputHashes();
        StreamFinalityScope memory s = _scope();
        s.scopeType = StreamFinalityScopeType.RELEASE;
        vm.expectRevert(
            abi.encodeWithSelector(Configuration.InvalidViewFinalityConfiguration.selector)
        );
        host.catalogue(s);
        host.catalogue(_scope());
    }

    function testLowerComponentEnvelopeDirectAndComposedRetainsFullResult() public {
        ViewConfigurationOuterProbe outer = new ViewConfigurationOuterProbe();
        uint256[2] memory ceilings = [uint256(24000000), 48000000];
        uint256[2] memory envelopes = [uint256(12000000), 44000000];
        for (uint256 i; i < 2; ++i) {
            config.readGas = 2000000;
            config.componentSourceGas = 4000000;
            config.sourceGas = ceilings[i];
            host.configure(config, selected, expected.targets[5], factory);
            (Configuration.Context memory expectedContext, bytes32 beforeHash, bytes32 afterHash) =
                host.resolveAndInputHashes();
            bytes32 expectedHash = keccak256(abi.encode(expectedContext, beforeHash, afterHash));
            bytes memory request = abi.encodeCall(host.resolveAndInputHashes, ());
            (bool ok, bytes memory raw) = address(host).staticcall{ gas: envelopes[i] }(request);
            require(ok && keccak256(raw) == expectedHash, "direct full result below source ceiling");
            (ok, raw) = address(outer).staticcall{ gas: envelopes[i] }(
                abi.encodeCall(outer.resolve, (host))
            );
            require(
                ok && keccak256(raw) == expectedHash,
                "additional component frame retains full result"
            );
            require(beforeHash == keccak256(abi.encode(config)) && afterHash == beforeHash);
        }
    }

    function testClosedSameHostCeilingAndNestedReadRemainStrict() public {
        config.readGas = 2000000;
        config.componentSourceGas = 4000000;
        config.sourceGas = 24000000;
        host.configure(config, selected, expected.targets[5], factory);
        bytes4 selector = bytes4(keccak256("viewPreservationSnapshotHost()"));
        bytes memory request = abi.encodeCall(host.closedAt, (selector, uint256(24000000)));
        (bool ok, bytes memory raw) = address(host).staticcall{ gas: 4000000 }(request);
        require(ok && abi.decode(abi.decode(raw, (bytes)), (address)) == expected.targets[5]);
        (ok, raw) = address(host).staticcall{ gas: 2000000 }(request);
        require(
            !ok
                && keccak256(raw)
                    == keccak256(abi.encodeWithSelector(T.InventoryRead.selector, address(host))),
            "inner full2m cap is never reduced"
        );
        (ok, raw) = address(host).staticcall{ gas: 4000000 }(
            abi.encodeCall(host.closedAt, (selector, uint256(2000000)))
        );
        require(
            !ok
                && keccak256(raw)
                    == keccak256(abi.encodeWithSelector(T.InventoryRead.selector, address(host))),
            "upper ceiling remains binding"
        );
        (ok, raw) = address(host).staticcall{ gas: 140000 }(request);
        require(
            !ok
                && keccak256(raw)
                    == keccak256(abi.encodeWithSelector(T.InventoryRead.selector, address(host))),
            "insufficient local reserve returns exact error"
        );
        (ok, raw) = address(host).staticcall{ gas: 4000000 }(request);
        require(ok, "unchanged request restores at sufficient gas");
    }

    function testClosedSelectorAndExactReturnWidthAreMandatory() public {
        bytes4 selector = bytes4(keccak256("viewPreservationSnapshotHost()"));
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(host)));
        host.closedAt(bytes4(keccak256("viewFinalitySourcesReceipt()")), 4000000);
        for (uint256 i; i < 2; ++i) {
            bytes memory wrong = new bytes(i == 0 ? 31 : 33);
            ViewConfigurationBudgetVm(address(vm))
                .mockCall(address(host), abi.encodeWithSelector(selector), wrong);
            vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(host)));
            host.closedAt(selector, 4000000);
            ViewConfigurationBudgetVm(address(vm)).clearMockedCalls();
            require(abi.decode(host.closedAt(selector, 4000000), (address)) == expected.targets[5]);
        }
    }

    function testCanonicalSnapshotAddressStillRefusesThenRestores() public {
        bytes4 selector = bytes4(keccak256("viewPreservationSnapshotHost()"));
        ViewConfigurationBudgetVm(address(vm))
            .mockCall(
                address(host), abi.encodeWithSelector(selector), abi.encode(uint256(1) << 160)
            );
        vm.expectRevert(
            abi.encodeWithSelector(Configuration.InvalidViewFinalityConfiguration.selector)
        );
        host.resolveAndInputHashes();
        ViewConfigurationBudgetVm(address(vm)).clearMockedCalls();
        host.resolveAndInputHashes();
    }
}
