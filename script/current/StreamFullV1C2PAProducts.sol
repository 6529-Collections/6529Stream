// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFullV1StaticRendererPlan.sol";
import {
    StreamC2PAReconciliation
} from "../../smart-contracts/domains/metadata/StreamC2PAReconciliation.sol";
import {
    StreamStaticC2PAAttributionCompanion
} from "../../smart-contracts/domains/metadata/StreamStaticC2PAAttributionCompanion.sol";
import {
    StreamStaticRenderEncoding
} from "../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import {
    StreamArtistStaticDisplay
} from "../../smart-contracts/domains/artist/StreamArtistStaticDisplay.sol";
import {
    IStreamArtistSuiteReads
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamStaticC2PAConflicts
} from "../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";

interface C2PAProductArtist {
    function operationCoordinator() external view returns (address);
}

/// @notice Genuine optional C2PA products attached to the selected original current graph.
/// @dev Construction and retained runtime observations are not STATIC admission, complete
/// analysis, compiler provenance, verifier correctness or deployment-size/gas acceptance.
library StreamFullV1C2PAProducts {
    struct Configuration {
        StreamFullV1StaticRendererPlan.Configuration base;
        address verifier;
        IStreamGasParameterHost.GasParameterConfig reconciliationGas;
        IStreamGasParameterHost.GasParameterConfig wrapperArtistGas;
        IStreamGasParameterHost.GasParameterConfig wrapperReportGas;
    }

    struct Products {
        uint256 chainId;
        bytes32 configurationHash;
        StreamStaticAttributionCompanion original;
        StreamC2PAReconciliation reconciliation;
        StreamStaticC2PAAttributionCompanion wrapper;
        StreamRendererV1 renderer;
        address encoding;
        address artistStaticDisplay;
        bytes32[6] codeHashes;
        address[4] artistTargets; // Coordinator, Identity, Binding, Attribution
        bytes32[4] artistCodeHashes;
    }

    function deploy(Configuration memory c) internal returns (Products memory p) {
        _configuration(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        p.original = new StreamStaticAttributionCompanion(
            c.base.core, c.base.router, c.base.artist, c.base.finality, c.base.executor
        );
        p.reconciliation = new StreamC2PAReconciliation(
            c.base.core,
            c.base.metadata,
            c.base.artist,
            c.base.router,
            c.verifier,
            c.base.executor,
            c.reconciliationGas
        );
        p.wrapper = new StreamStaticC2PAAttributionCompanion(
            address(p.original),
            address(p.reconciliation),
            c.base.executor,
            c.wrapperArtistGas,
            c.wrapperReportGas
        );
        p.renderer = new StreamRendererV1(
            StreamRendererV1.Deployment(
                StreamRendererV1.Sources(
                    c.base.core,
                    c.base.router,
                    c.base.metadata,
                    c.base.entropy,
                    c.base.dependencyRegistry,
                    address(p.wrapper)
                ),
                c.base.executor,
                c.base.readGas,
                c.base.attributionGas,
                c.base.rendererManifest
            )
        );
        (p.encoding,) = p.renderer.encodingBinding();
        p.artistStaticDisplay = address(StreamArtistStaticDisplay);
        address[6] memory own = addresses(p);
        for (uint256 i; i < own.length; ++i) {
            p.codeHashes[i] = own[i].codehash;
        }
        (p.artistTargets, p.artistCodeHashes) = p.reconciliation.artistSourceBindings();
        validate(c, p);
    }

    function addresses(Products memory p) internal pure returns (address[6] memory) {
        return [
            address(p.original),
            address(p.reconciliation),
            address(p.wrapper),
            address(p.renderer),
            p.encoding,
            p.artistStaticDisplay
        ];
    }

    function validate(Configuration memory c, Products memory p) internal view {
        _configuration(c);
        require(
            p.chainId == block.chainid && p.configurationHash == keccak256(abi.encode(c)),
            "retained C2PA construction"
        );
        address[6] memory own = addresses(p);
        for (uint256 i; i < own.length; ++i) {
            _pin(own[i], p.codeHashes[i]);
            for (uint256 j; j < i; ++j) {
                require(own[i] != own[j], "distinct original products and fixed workers");
            }
        }
        require(
            p.original.core() == c.base.core && p.original.router() == c.base.router
                && p.original.artist() == c.base.artist
                && p.original.originalFinality() == c.base.finality
                && p.original.sourceChainId() == block.chainid
                && p.original.artistCodeHash() == c.base.artist.codehash
                && p.original.originalFinalityCodeHash() == c.base.finality.codehash,
            "original attribution bindings"
        );
        require(
            p.reconciliation.core() == c.base.core && p.reconciliation.metadata() == c.base.metadata
                && p.reconciliation.artist() == c.base.artist
                && p.reconciliation.router() == c.base.router
                && p.reconciliation.verifier() == c.verifier
                && p.reconciliation.governanceAuthority() == c.base.executor,
            "actual reconciliation graph"
        );
        require(
            p.wrapper.core() == c.base.core && p.wrapper.router() == c.base.router
                && p.wrapper.original() == address(p.original)
                && p.wrapper.reconciliation() == address(p.reconciliation)
                && p.wrapper.originalCodeHash() == p.codeHashes[0]
                && p.wrapper.reconciliationCodeHash() == p.codeHashes[1]
                && p.wrapper.governanceAuthority() == c.base.executor
                && p.wrapper.sourceChainId() == block.chainid,
            "wrapper original bindings"
        );
        address[5] memory sources = [
            c.base.core,
            c.base.metadata,
            c.base.artist,
            c.base.router,
            S(c.base.schemas).chunkStore()
        ];
        bytes32[5] memory sourceHashes = p.reconciliation.sourceCodeHashes();
        for (uint256 i; i < sources.length; ++i) {
            _pin(sources[i], sourceHashes[i]);
        }
        require(
            p.reconciliation.chunkStore() == sources[4]
                && p.reconciliation.sourceChainId() == block.chainid,
            "original store and chain"
        );
        address coordinator = C2PAProductArtist(c.base.artist).operationCoordinator();
        T.SuiteConfiguration memory suite =
            IStreamArtistSuiteReads(coordinator).suiteConfiguration();
        require(
            suite.core == c.base.core && suite.registry == c.base.artist
                && suite.metadata == c.base.router,
            "original Artist suite"
        );
        address[4] memory expected =
            [coordinator, suite.owners[2], suite.owners[0], suite.owners[4]];
        (address[4] memory actual, bytes32[4] memory hashes) =
            p.reconciliation.artistSourceBindings();
        for (uint256 i; i < expected.length; ++i) {
            require(
                actual[i] == expected[i] && actual[i] == p.artistTargets[i]
                    && hashes[i] == p.artistCodeHashes[i],
                "original fixed Artist source"
            );
            _pin(actual[i], hashes[i]);
        }
        (StreamRendererV1.Sources memory rendererSources, bytes32[6] memory rendererHashes) =
            p.renderer.sourceBindings();
        StreamRendererV1.Sources memory wanted = StreamRendererV1.Sources(
            c.base.core,
            c.base.router,
            c.base.metadata,
            c.base.entropy,
            c.base.dependencyRegistry,
            address(p.wrapper)
        );
        require(
            keccak256(abi.encode(rendererSources)) == keccak256(abi.encode(wanted))
                && p.renderer.c2paAttributionEnabled() && p.renderer.c2paConflictsEnabled()
                && p.wrapper.supportsInterface(type(IStreamStaticC2PAConflicts).interfaceId)
                && p.renderer.governanceAuthority() == c.base.executor
                && keccak256(abi.encode(p.renderer.rendererManifest()))
                    == keccak256(abi.encode(c.base.rendererManifest)),
            "optional Renderer uses actual wrapper"
        );
        address[6] memory rendererTargets = [
            c.base.core,
            c.base.router,
            c.base.metadata,
            c.base.entropy,
            c.base.dependencyRegistry,
            address(p.wrapper)
        ];
        for (uint256 i; i < rendererTargets.length; ++i) {
            if (rendererTargets[i] != address(0)) _pin(rendererTargets[i], rendererHashes[i]);
        }
        (address encoding, bytes32 hash) = p.renderer.encodingBinding();
        require(
            encoding == p.encoding && encoding == address(StreamStaticRenderEncoding)
                && hash == p.codeHashes[4]
                && p.artistStaticDisplay == address(StreamArtistStaticDisplay),
            "matching new Encoding and fixed Artist worker"
        );
    }

    /// @dev Original Renderer row only. The wrapper/reconciliation have no invented module kind.
    function rendererRegistration(Configuration memory c, Products memory p, uint32 readGas)
        internal
        view
        returns (StreamModuleRegistration memory)
    {
        validate(c, p);
        require(readGas != 0, "explicit module read budget");
        return StreamModuleRegistration(
            address(p.renderer),
            keccak256("RENDERER"),
            p.renderer.rendererVersion(),
            type(R).interfaceId,
            readGas,
            p.codeHashes[3],
            c.base.deploymentHash,
            c.base.rendererManifest.manifestHash,
            c.base.rendererManifest.manifestURI
        );
    }

    function operatingPolicies(Configuration memory c, Products memory p)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        validate(c, p);
        rows = new GovernanceActionPolicyEntry[](3);
        address[3] memory hosts =
            [address(p.reconciliation), address(p.wrapper), address(p.renderer)];
        for (uint256 i; i < hosts.length; ++i) {
            rows[i] = GovernanceActionPolicyEntry(
                1,
                hosts[i],
                IStreamGasParameterHost.raiseGasParameter.selector,
                hosts[i].codehash,
                keccak256(abi.encode(c.base.deploymentHash, hosts[i])),
                1,
                0,
                0,
                0
            );
        }
    }

    function _configuration(Configuration memory c) private view {
        require(
            c.verifier != address(0) && c.base.deploymentHash != 0
                && c.base.executor.code.length != 0 && c.base.core.code.length != 0
                && c.base.artist.code.length != 0 && c.base.router.code.length != 0
                && c.base.finality.code.length != 0,
            "actual C2PA dependencies"
        );
        require(
            StreamCollectionMetadataV1(c.base.metadata).core() == c.base.core
                && StreamCollectionMetadataV1(c.base.metadata).schemaRegistry() == c.base.schemas
                && S(c.base.schemas).governanceAuthority() == c.base.executor
                && StreamCollectionMetadataV1(c.base.metadata).governanceAuthority()
                    == c.base.executor,
            "original Metadata and schema authority"
        );
    }

    function _pin(address target, bytes32 hash) private view {
        require(
            target.code.length != 0 && hash != 0 && target.codehash == hash,
            "retained C2PA dependency runtime"
        );
    }
}
