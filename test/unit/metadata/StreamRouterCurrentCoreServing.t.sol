// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RecoveryGovernanceIntegrationFixture.sol";
import {
    IStreamMetadataServingFacts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import { RecoveryCoreMintBoundary } from "../../helpers/RecoveryCoreMintBoundaries.sol";
import { RouterCoreEntropyBoundary } from "../../helpers/RouterCoreEntropyBoundary.sol";
import { RouterCoreMintBoundary } from "../../helpers/RouterCoreMintBoundary.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    IStreamArtistAttribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamArtistAttributionState
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import {
    IStreamArtistContentRatification
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import {
    IStreamArtistFinalityBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import {
    IStreamCollectionArtistRegistry
} from "../../../smart-contracts/interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import {
    IStreamMintManager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamEntropyCoordinator
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    StreamMetadataTokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import {
    StreamMetadataRouterCollectionReads
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterCollectionReads.sol";
import {
    StreamMetadataFinalityServing
} from "../../../smart-contracts/domains/metadata/StreamMetadataFinalityServing.sol";
import {
    StreamMetadataRecoveryRoutes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamMetadataRenderPreparation
} from "../../../smart-contracts/domains/metadata/StreamMetadataRenderPreparation.sol";
import {
    StreamMetadataTokenReads
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenReads.sol";

/// @notice Actual selected Core/Router with actual governance installation and a completed Core mint.
/// @dev Artist, original history, mint admission and entropy remain explicit boundaries. This
/// establishes absence classification with a selected companion, not frozen route authority.
contract StreamRouterCurrentCoreServingTest is RecoveryGovernanceIntegrationFixture {
    StreamMetadataRouter private router;
    RecoveryCoreMintBoundary private manager;
    RouterCoreEntropyBoundary private entropy;

    function _artistFacts() private {
        CompanionDependencyBoundary a = CompanionDependencyBoundary(fixture.artistTarget());
        a.answer(
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamArtistAttribution).interfaceId
            ),
            abi.encode(true)
        );
        a.answer(
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamArtistAttributionState).interfaceId
            ),
            abi.encode(true)
        );
        a.answer(
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamArtistContentRatification).interfaceId
            ),
            abi.encode(true)
        );
        a.answer(
            abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistry, ()),
            abi.encode(address(fixture.history()))
        );
        a.answer(
            abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistryCodeHash, ()),
            abi.encode(address(fixture.history()).codehash)
        );
        IStreamCollectionArtistRegistry.Attribution memory attribution;
        attribution.artist = address(0xA11CE);
        attribution.nominatedArtist = address(0xA11CE);
        attribution.nominationHash = keccak256("binding");
        attribution.nominationRevision = 3;
        attribution.identityHash = keccak256("identity");
        attribution.acceptanceHash = keccak256("acceptance");
        a.answer(abi.encodeCall(IStreamArtistAttribution.attribution, (1)), abi.encode(attribution));
        a.answer(
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (1)),
            abi.encode(uint8(2), uint64(3), keccak256("artist"), uint8(1), keccak256("binding"))
        );
        a.answer(
            abi.encodeCall(IStreamArtistContentRatification.firstReleaseRatification, (1)),
            abi.encode(false, bytes32(0), bytes32(0))
        );
    }

    function _installAndMint() private {
        _installAndMint(false);
    }

    function _installAndMint(bool maximum) private {
        _initialize();
        _artistFacts();
        router = new StreamMetadataRouter(
            address(configuration.core),
            address(this),
            configuration.deploymentHash,
            "urn:current:router",
            keccak256("current Router manifest"),
            IStreamArtistAttribution(fixture.artistTarget())
        );
        manager = new RouterCoreMintBoundary();
        entropy = new RouterCoreEntropyBoundary(address(configuration.core));
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](3);
        registrations[0] = StreamModuleRegistration(
            address(router),
            router.streamModuleType(),
            router.streamModuleVersion(),
            router.streamModuleInterfaceId(),
            500000,
            address(router).codehash,
            configuration.deploymentHash,
            keccak256("current Router manifest"),
            "urn:current:router"
        );
        registrations[1] = StreamModuleRegistration(
            address(manager),
            keccak256("MINT_MANAGER"),
            keccak256("mint boundary"),
            type(IStreamMintManager).interfaceId,
            500000,
            address(manager).codehash,
            configuration.deploymentHash,
            keccak256("mint manifest"),
            "urn:current:mint"
        );
        registrations[2] = StreamModuleRegistration(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("entropy boundary"),
            type(IStreamEntropyCoordinator).interfaceId,
            500000,
            address(entropy).codehash,
            configuration.deploymentHash,
            keccak256("entropy manifest"),
            "urn:current:entropy"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, registrations);
        _runBatch(1, calls, data);
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = keccak256("METADATA_ROUTER");
        keys[1] = keccak256("MINT_MANAGER");
        keys[2] = keccak256("ENTROPY_COORDINATOR");
        (GovernanceCall[] memory ptrs, bytes[] memory ptrdata) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, keys, registrations
        );
        calls = new GovernanceCall[](4);
        data = new bytes[](4);
        for (uint256 i; i < 3; ++i) {
            calls[i] = ptrs[i];
            data[i] = ptrdata[i];
        }
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules;
        modules.metadataRouter = address(router);
        modules.mintManager = address(manager);
        modules.entropyCoordinator = address(entropy);
        (calls[3], data[3]) = _publication(modules, keccak256("actual Router installation"));
        _runBatch(3, calls, data);
        calls = new GovernanceCall[](1);
        data = new bytes[](1);
        (calls[0], data[0]) = StreamCurrentStackPlan.createCollectionCall(configuration.core, 1, 2);
        _runBatch(1, calls, data);
        if (maximum) {
            router.setCollectionMetadata(
                1,
                _fill(256),
                _fill(2048),
                string.concat("ipfs://", _fill(2041)),
                string.concat("ipfs://", _fill(2041))
            );
            router.setCollectionScript(1, _fill(8192));
        } else {
            router.setCollectionMetadata(1, "Current Core", "Description", "ipfs://current", "");
            router.setCollectionScript(1, "return 6529;");
        }
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        require(
            (maximum
                        ? RouterCoreMintBoundary(address(manager))
                            .mintMaximum(address(configuration.core), bytes(_fill(16384)))
                        : manager.mint(address(configuration.core), 1, address(0xBEEF))) == 1,
            "actual Core mint"
        );
        require(
            configuration.core.tokenLifecycle(1) == 2
                && configuration.core.ownerOf(1) == address(0xBEEF)
                && configuration.core.lastAllocatedTokenId() == 1 && entropy.callbacks() == 1,
            "actual token lifecycle/owner/callback"
        );
    }

    function _fill(uint256 length) private pure returns (string memory) {
        bytes memory value = new bytes(length);
        for (uint256 i; i < length; ++i) {
            value[i] = 0x61;
        }
        return string(value);
    }

    function testColdMaximumCoreAndRouterReadsRequirePayloadBudget() public {
        _installAndMint(true);
        bytes memory input = abi.encodeCall(configuration.core.tokenData, (1));
        _cold();
        (bool oldOK,) = address(configuration.core).staticcall{ gas: 1000000 }(input);
        require(!oldOK, "old token data budget fails on actual cold16KiB");
        _cold();
        (bool ok, bytes memory raw) = address(configuration.core).staticcall{ gas: 2000000 }(input);
        require(
            ok && raw.length == 16448
                && keccak256(abi.decode(raw, (bytes))) == keccak256(bytes(_fill(16384))),
            "new budget returns exact actual maximum token bytes"
        );
        input = abi.encodeCall(router.collectionServingFacts, (1));
        _cold();
        (oldOK,) = address(router).staticcall{ gas: 150000 }(input);
        require(!oldOK, "old facts budget fails on actual cold Router source");
        _cold();
        (ok, raw) = address(router).staticcall{ gas: 2000000 }(input);
        require(ok && raw.length == 512, "new budget returns exact actual facts tuple");
        input = abi.encodeCall(router.collectionServingSource, (1));
        _cold();
        (ok, raw) = address(router).staticcall{ gas: 2000000 }(input);
        require(ok, "new budget returns complete actual raw source");
        IStreamMetadataServingFacts.ServingSource memory source =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingSource));
        require(
            bytes(source.name).length == 256 && bytes(source.description).length == 2048
                && bytes(source.imageURI).length == 2048
                && bytes(source.animationBaseURI).length == 2048
                && bytes(source.script).length == 8192
                && keccak256(raw) == keccak256(abi.encode(source)),
            "maximum source complete canonical ABI"
        );
    }

    function _cold() private {
        safeVm.cool(address(StreamCoreExternalReads));
        safeVm.cool(address(configuration.core));
        safeVm.cool(address(configuration.registry));
        safeVm.cool(address(router));
        safeVm.cool(address(first));
        safeVm.cool(fixture.artistTarget());
        safeVm.cool(address(fixture.history()));
        safeVm.cool(address(entropy));
        safeVm.cool(address(StreamMetadataTokenRenderer));
        safeVm.cool(address(StreamMetadataRouterCollectionReads));
        safeVm.cool(address(StreamMetadataFinalityServing));
        safeVm.cool(address(StreamMetadataRecoveryRoutes));
        safeVm.cool(address(StreamMetadataRenderPreparation));
        safeVm.cool(address(StreamMetadataTokenReads));
    }

    function testActualColdCoreUsesCurrentCapAndKeepsUnfinalizedServingWithCompanion() public {
        _installAndMint();
        require(
            _selected() == address(first) && fixture.history().finalityComponentCount(1) == 0,
            "selected real companion and no original collection history"
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = configuration.core
            .gasParameterInfo(0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93);
        require(
            value == 12000000 && floor == 250000 && failure == 1 && revision == 1,
            "accepted current metadata gas profile"
        );
        bytes32 expected = keccak256(bytes(router.tokenURI(address(configuration.core), 1)));
        require(
            expected != keccak256(bytes(StreamMetadataRenderer.coreFallbackTokenURI(1, 4))),
            "fixture has real metadata output"
        );
        _cold();
        require(
            keccak256(bytes(configuration.core.tokenURI(1))) == expected,
            "actual cold Core/Router byte parity"
        );
        _cold();
        (bool ok, bytes memory raw) = address(router).staticcall{ gas: 500000 }(
            abi.encodeCall(router.tokenURI, (address(configuration.core), 1))
        );
        require(
            ok && keccak256(bytes(abi.decode(raw, (string)))) == expected,
            "older 500k direct budget still serves unfinalized collection"
        );
        require(
            address(router).code.length <= 24576 && address(configuration.core).code.length <= 24576
                && address(configuration.executor).code.length <= 24576,
            "actual sizes fit"
        );
    }
}
