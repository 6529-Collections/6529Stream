// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    StreamEntropyPolicyConsumerTypes as Policy
} from "../../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    IStreamTerminalEntropyRenderer as Terminal
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";

/// @dev Direct, typed terminal source for serving transport; actual Coordinator behavior is tested
/// separately. The old delegated getter selectors deliberately revert to catch accidental use.
contract TerminalRouteEntropy {
    address public immutable core;
    uint8 public status = 1;
    bytes32 public request;
    bytes32 public seed;

    constructor(address originalCore) {
        core = originalCore;
    }

    function setStatus(uint8 value) external {
        status = value;
    }

    function setInvalid(bytes32 s, bytes32 r) external {
        seed = s;
        request = r;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == 0x40016975;
    }

    function staticTokenRenderFacts(uint256) external view returns (uint8, bytes32, address) {
        return (status, seed, address(0));
    }

    function staticTerminalEntropyFacts(uint256 tokenId)
        external
        view
        returns (uint256, Policy.Policy memory p, uint8, bytes32, bytes32)
    {
        require(tokenId == 91, "original fixture token");
        p = Policy.Policy(
            true,
            true,
            true,
            status == 1 ? uint8(0) : uint8(2),
            0,
            1,
            1,
            0,
            keccak256("exact declared terminal policy"),
            0,
            keccak256("original action"),
            keccak256("original op17")
        );
        p.contentStateHash = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, true)
        );
        return (1, p, status, seed, request);
    }

    fallback() external {
        revert("legacy linked-read selector forbidden in STATIC fixture");
    }
}

/// @dev Explicit admitted-profile boundary for actual routing, not a substitute for the separate
/// real Registry/Schema/governed-evidence/Safe suite or real program analysis.
contract TerminalRouteVersions is StaticRouteVersions {
    address private immutable renderer;
    bool public admitted;
    bytes32 public profile = keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");

    constructor(address executor, address schemas, address target)
        StaticRouteVersions(executor, schemas, target)
    {
        renderer = target;
    }

    function setAdmitted(bool value) external {
        admitted = value;
    }

    function setProfile(bytes32 value) external {
        profile = value;
    }

    function requireTerminalEntropy(bytes32 k)
        external
        view
        returns (address, bytes32, bytes32, bytes4)
    {
        require(admitted && k == key, "separate terminal admission required");
        return (renderer, renderer.codehash, profile, Terminal.renderTerminal.selector);
    }
}

/// @notice Actual Router/Renderer/Metadata/Schema/Store and exact current terminal transport.
/// Core, Artist/attribution, explicit terminal producer and profile admission are typed boundaries.
/// It proves selection/refusal/output behavior, not actual-current mint/governance or conformance.
contract StreamTerminalEntropyRoutingTest is StaticMetadataRoutingFixture {
    TerminalRouteEntropy private terminal;
    TerminalRouteVersions private terminalVersions;

    function setUp() public override {
        super.setUp();
        terminal = new TerminalRouteEntropy(address(core));
        core.setEntropy(address(terminal));
        StreamRendererV1.Deployment memory d;
        (d.sources,) = renderer.sourceBindings();
        d.sources.entropy = address(terminal);
        d.executor = address(executor);
        d.manifest = renderer.rendererManifest();
        d.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        d.attributionGas =
            IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        renderer = new StreamRendererV1(d);
        terminalVersions =
            new TerminalRouteVersions(address(executor), address(schemas), address(renderer));
        versions = terminalVersions;
        modules = new StaticRouteModules(address(metadata), address(versions));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        _activate();
        _mint();
    }

    function testTerminalCurrentFullJSONAndHTMLRequireExactSeparateAdmission() public {
        vm.expectRevert();
        router.tokenJSON(91);
        vm.expectRevert();
        router.tokenHTML(91);
        terminalVersions.setAdmitted(true);
        string memory json = router.tokenJSON(91);
        string memory html = router.tokenHTML(91);
        require(
            _has(json, '"entropy_status":"DISABLED"') && _has(json, '"entropy_finalized":false'),
            "truthful actual current output"
        );
        require(
            _has(json, '"render_profile":"6529STREAM_TERMINAL_ENTROPY_RENDER_V1"')
                && !_has(json, '"hash":') && !_has(json, '"seed":'),
            "separate context no seed"
        );
        require(
            _has(html, "document.body.textContent = tokenId;") && !_has(html, "const hash="),
            "full exact program without fake random alias"
        );
        terminalVersions.setProfile(keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"));
        vm.expectRevert();
        router.tokenJSON(91);
        terminalVersions.setProfile(keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1"));
        require(
            keccak256(bytes(router.tokenJSON(91))) == keccak256(bytes(json)),
            "restored exact profile output"
        );
    }

    function testTerminalHistoricalEntryNeverBorrowsCurrentTerminalAdmission() public {
        vm.expectRevert();
        router.historicalTokenMetadataJSON(address(core), 91);
        vm.expectRevert();
        router.historicalFullTokenMetadataJSON(address(core), 91);
        terminalVersions.setAdmitted(true);
        router.tokenJSON(91);
        vm.expectRevert();
        router.historicalTokenMetadataJSON(address(core), 91);
        vm.expectRevert();
        router.historicalFullTokenMetadataJSON(address(core), 91);
    }

    function testTerminalRequestOrSeedMismatchFailsWithoutOldProfileFallback() public {
        terminalVersions.setAdmitted(true);
        terminal.setInvalid(bytes32(uint256(1)), 0);
        vm.expectRevert();
        router.tokenJSON(91);
        terminal.setInvalid(0, bytes32(uint256(2)));
        vm.expectRevert();
        router.tokenHTML(91);
        terminal.setInvalid(0, 0);
        router.tokenJSON(91);
        terminal.setStatus(2);
        require(
            _has(router.tokenJSON(91), '"entropy_status":"NOT_REQUIRED"'),
            "distinct explicit terminal state"
        );
    }

    function testTerminalOriginalSourceRuntimeDriftIsTerminalAndHistoricalConfigPersists() public {
        terminalVersions.setAdmitted(true);
        bytes32 config = router.resolvedMetadataConfig(91).recordHash;
        router.tokenJSON(91);
        vm.etch(address(terminal), hex"00");
        vm.expectRevert();
        router.tokenJSON(91);
        require(
            router.resolvedMetadataConfig(91).recordHash == config,
            "immutable selected config retained"
        );
    }
}
