// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistFinalityAdmission.sol";

interface FinalityAdmissionVm {
    function expectRevert(bytes calldata reason) external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Isolated typed constructor boundaries. These do not simulate operative Core selection.
contract AdmissionMetadataBoundary {
    address public immutable core;

    constructor(address core_) {
        core = core_;
    }
}

contract AdmissionArtistBoundary {
    address public immutable governanceAuthority;

    constructor(address governance_) {
        governanceAuthority = governance_;
    }
}

contract AdmissionProviderBoundary {
    address public immutable core;
    address public immutable metadataHost;

    constructor(address core_, address host_) {
        core = core_;
        metadataHost = host_;
    }
}

contract AdmissionArtifactBoundary {
    address public immutable core;
    address public finalityRegistry;

    constructor(address core_) {
        core = core_;
    }

    function setFinality(address finality_) external {
        finalityRegistry = finality_;
    }
}

contract AdmissionFinalityBoundary {
    address public immutable coreReads;
    address public immutable metadataReads;
    address public immutable sanctionReads;
    address public immutable finalityRoleRegistry;
    address public immutable governanceAuthority;
    address public immutable scopeEvidenceProvider;
    address public immutable artifactCoverage;

    constructor(
        T.SuiteConfiguration memory suite,
        address host,
        address provider,
        address artifact
    ) {
        coreReads = suite.core;
        metadataReads = host;
        sanctionReads = suite.registry;
        finalityRoleRegistry = suite.roleRegistry;
        governanceAuthority = AdmissionArtistBoundary(suite.registry).governanceAuthority();
        scopeEvidenceProvider = provider;
        artifactCoverage = artifact;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("ARTWORK_FINALITY_REGISTRY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtworkFinalityRegistry).interfaceId;
    }
}

contract FinalityAdmissionHarness {
    address public immutable provider;
    bytes32 public immutable providerCodeHash;

    constructor(T.SuiteConfiguration memory suite, address finality) {
        (provider, providerCodeHash) = StreamArtistFinalityAdmission.admit(suite, finality);
    }
}

contract StreamArtistFinalityAdmissionTest {
    FinalityAdmissionVm private constant vm =
        FinalityAdmissionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _suite() private returns (T.SuiteConfiguration memory suite) {
        // No contract exists at Core: any attempted constructor pointer selection must fail.
        // Only the existing reciprocal address facts are part of this isolated admission seam.
        suite.core = address(0xC0DE);
        suite.roleRegistry = address(0x1234);
        suite.metadata = address(new AdmissionMetadataBoundary(suite.core));
        suite.registry = address(new AdmissionArtistBoundary(address(0x5678)));
    }

    function _finality(T.SuiteConfiguration memory suite, address host, address provider)
        private
        returns (address)
    {
        AdmissionArtifactBoundary artifact = new AdmissionArtifactBoundary(suite.core);
        AdmissionFinalityBoundary finality =
            new AdmissionFinalityBoundary(suite, host, provider, address(artifact));
        artifact.setFinality(address(finality));
        return address(finality);
    }

    function testFinalityAdmissionDistinctRouterAndGenericHostBeforePointerSelection() external {
        T.SuiteConfiguration memory suite = _suite();
        address generic = address(new AdmissionMetadataBoundary(suite.core));
        address provider = address(new AdmissionProviderBoundary(suite.core, generic));
        require(generic != suite.metadata, "distinct Router and record host");
        require(suite.core.code.length == 0, "no operative Core double");
        address finality = _finality(suite, generic, provider);
        FinalityAdmissionHarness admitted = new FinalityAdmissionHarness(suite, finality);
        require(
            admitted.provider() == provider && admitted.providerCodeHash() == provider.codehash,
            "provider pins"
        );
        require(
            AdmissionFinalityBoundary(finality).metadataReads() == generic, "finality generic pin"
        );
    }

    function testFinalityAdmissionProviderCannotSubstituteRouterForGenericHost() external {
        T.SuiteConfiguration memory suite = _suite();
        address generic = address(new AdmissionMetadataBoundary(suite.core));
        address wrong = address(new AdmissionProviderBoundary(suite.core, suite.metadata));
        address finality = _finality(suite, generic, wrong);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
        new FinalityAdmissionHarness(suite, finality);
        address healthy = address(new AdmissionProviderBoundary(suite.core, generic));
        finality = _finality(suite, generic, healthy);
        require(
            address(new FinalityAdmissionHarness(suite, finality)) != address(0),
            "healthy split pins"
        );
    }

    function testFinalityAdmissionGenericCoreMismatchAndMissingCode() external {
        T.SuiteConfiguration memory suite = _suite();
        address wrong = address(new AdmissionMetadataBoundary(address(0xBAD)));
        address provider = address(new AdmissionProviderBoundary(suite.core, wrong));
        address finality = _finality(suite, wrong, provider);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
        new FinalityAdmissionHarness(suite, finality);
        address missing = address(0xDEAD);
        provider = address(new AdmissionProviderBoundary(suite.core, missing));
        finality = _finality(suite, missing, provider);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
        new FinalityAdmissionHarness(suite, finality);
    }

    function testFinalityAdmissionGenericCoreMalformedReadAndExactRestore() external {
        T.SuiteConfiguration memory suite = _suite();
        address generic = address(new AdmissionMetadataBoundary(suite.core));
        bytes memory original = generic.code;
        address provider = address(new AdmissionProviderBoundary(suite.core, generic));
        address finality = _finality(suite, generic, provider);
        vm.etch(generic, hex"6000600052601f6000f3");
        vm.expectRevert(abi.encodeWithSelector(T.InvalidBinding.selector));
        new FinalityAdmissionHarness(suite, finality);
        vm.etch(generic, original);
        FinalityAdmissionHarness admitted = new FinalityAdmissionHarness(suite, finality);
        require(admitted.provider() == provider, "same fixed configuration restored");
    }
}
