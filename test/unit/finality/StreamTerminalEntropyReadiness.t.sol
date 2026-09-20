// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamTerminalEntropyReadiness
} from "../../../smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol";
import {
    IStreamTerminalEntropyReadiness as Readiness
} from "../../../smart-contracts/interfaces/stream/finality/IStreamTerminalEntropyReadiness.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamStaticMetadataRouter as M
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamTerminalEntropyRenderer as T
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";
import {
    IStreamCurrentCitationRegistry as C
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";

contract TerminalReadinessIdentityFixture {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

contract TerminalReadinessSourceFixture {
    address public immutable core;
    E.TokenReadiness private saved;
    bool public current = true;
    bytes32 public constant SOURCE_SET_PROFILE =
        keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2");
    bytes32 public constant originalPolicyChainHash =
        keccak256("complete retained source chain fixture");

    constructor(address c, address entropy) {
        core = c;
        saved = E.TokenReadiness(
            entropy, entropy.codehash, keccak256("full policy"), 1, 0, 0, 1, true, false, 0
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(E).interfaceId || id == 0x01ffc9a7;
    }

    function requireCurrentSourceSet() external view {
        require(current, "stale inventory");
    }

    function tokenEntropyReadiness(uint256 id) external view returns (E.TokenReadiness memory) {
        require(id == 71);
        return saved;
    }

    function setCurrent(bool v) external {
        current = v;
    }

    function setFinalized(bool v) external {
        saved.finalized = v;
    }
}

contract TerminalReadinessRendererFixture {
    address private immutable c;
    address private immutable e;

    constructor(address core, address entropy) {
        c = core;
        e = entropy;
    }

    function terminalPolicyBinding() external view returns (address, address, bytes32) {
        return (c, e, e.codehash);
    }
}

contract TerminalReadinessRegistryFixture {
    address private immutable renderer;
    bool public admitted = true;
    bytes32 public profile = keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");

    constructor(address r) {
        renderer = r;
    }

    function requireTerminalEntropy(bytes32 version)
        external
        view
        returns (address, bytes32, bytes32, bytes4)
    {
        require(admitted && version == keccak256("version"));
        return (renderer, renderer.codehash, profile, T.renderTerminal.selector);
    }

    function terminalEntropyRecord(bytes32) external view returns (C.CurrentRecord memory r) {
        r.registrationHash = admitted ? keccak256("terminal admission") : bytes32(0);
    }

    function setAdmitted(bool v) external {
        admitted = v;
    }

    function setProfile(bytes32 v) external {
        profile = v;
    }
}

contract TerminalReadinessRouterFixture {
    address public immutable core;
    M.ConfigRecord private saved;

    constructor(address c, address renderer, address registry) {
        core = c;
        saved.recordHash = keccak256("actual selected config fixture");
        saved.config.mode = R.MetadataMode.ONCHAIN;
        saved.config.frozen = true;
        saved.selection.registry = registry;
        saved.selection.registryCodeHash = registry.codehash;
        saved.selection.versionKey = keccak256("version");
        saved.selection.renderer = renderer;
        saved.selection.rendererCodeHash = renderer.codehash;
    }

    function resolvedMetadataConfig(uint256 id) external view returns (M.ConfigRecord memory) {
        require(id == 71);
        return saved;
    }

    function setFrozen(bool v) external {
        saved.config.frozen = v;
    }

    function setMode(R.MetadataMode v) external {
        saved.config.mode = v;
    }
}

/// @notice Isolated adapter joins with explicit typed source/config/admission boundaries. Actual
/// complete source inventories and Registry governance are exercised in their separate suites.
contract StreamTerminalEntropyReadinessTest is CharacterizationTestBase {
    address private core;
    address private entropy;
    TerminalReadinessSourceFixture private source;
    TerminalReadinessRegistryFixture private registry;
    TerminalReadinessRouterFixture private router;
    TerminalReadinessRendererFixture private renderer;
    StreamTerminalEntropyReadiness private adapter;

    function setUp() public {
        core = address(new TerminalReadinessIdentityFixture());
        entropy = address(new TerminalReadinessIdentityFixture());
        source = new TerminalReadinessSourceFixture(core, entropy);
        renderer = new TerminalReadinessRendererFixture(core, entropy);
        registry = new TerminalReadinessRegistryFixture(address(renderer));
        router = new TerminalReadinessRouterFixture(core, address(renderer), address(registry));
        adapter = new StreamTerminalEntropyReadiness(
            core, address(router), address(source), 500000, 2000000
        );
    }

    function testTerminalReadinessLiteralEvidenceCommitsGraphPolicyAndAdmission() public view {
        Readiness.Evidence memory e = adapter.requireTerminalRenderReady(71);
        require(
            e.entropy.terminal && !e.entropy.finalized && e.entropy.seed == 0
                && e.entropy.coordinator == entropy,
            "truthful terminal source"
        );
        require(
            e.configRecordHash == keccak256("actual selected config fixture")
                && e.admissionHash == keccak256("terminal admission")
                && e.policyChainHash == source.originalPolicyChainHash(),
            "exact independent joins"
        );
        bytes32 got = e.evidenceHash;
        e.evidenceHash = 0;
        require(
            got
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_TERMINAL_REFERENCE_READINESS_V1"),
                        block.chainid,
                        address(adapter),
                        core,
                        address(router),
                        address(source),
                        address(source).codehash,
                        uint256(71),
                        e
                    )
                ),
            "literal complete evidence hash"
        );
    }

    function testTerminalReadinessRefusesStaleInventoryOrFinalizedSurrogate() public {
        source.setCurrent(false);
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
        source.setCurrent(true);
        source.setFinalized(true);
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
        source.setFinalized(false);
        adapter.requireTerminalRenderReady(71);
    }

    function testTerminalReadinessRefusesUnfrozenOffchainMissingAndForeignAdmission() public {
        router.setFrozen(false);
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
        router.setFrozen(true);
        router.setMode(R.MetadataMode.OFFCHAIN);
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
        router.setMode(R.MetadataMode.ONCHAIN);
        registry.setAdmitted(false);
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
        registry.setAdmitted(true);
        registry.setProfile(keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"));
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
    }

    function testTerminalReadinessRejectsDependencyRuntimeAndChainDrift() public {
        uint256 original = adapter.deploymentChainId();
        vm.chainId(original + 1);
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
        vm.chainId(original);
        adapter.requireTerminalRenderReady(71);
        vm.etch(address(source), hex"00");
        vm.expectRevert();
        adapter.requireTerminalRenderReady(71);
    }
}
