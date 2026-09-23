// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../entropy/EntropyCollectionPolicyFixtures.sol";
import {
    IStreamEntropyCollectionPolicy as Policy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamRevealFeeEscrow as Fee
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    StreamEntropyRenderPolicyReads as Reads
} from "../../../smart-contracts/domains/entropy/StreamEntropyRenderPolicyReads.sol";
import {
    StreamTerminalEntropyValidation as Validation
} from "../../../smart-contracts/domains/metadata/StreamTerminalEntropyValidation.sol";
import {
    StreamTerminalEntropyEncoding as Encoding
} from "../../../smart-contracts/domains/metadata/StreamTerminalEntropyEncoding.sol";
import {
    StreamTerminalEntropyJSON as Ordinary
} from "../../../smart-contracts/domains/metadata/StreamTerminalEntropyJSON.sol";
import {
    StreamStaticRenderEncoding as Original
} from "../../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import {
    StreamMetadataRenderTypes as Token
} from "../../../smart-contracts/interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamRenderer as Render
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";

interface TerminalConsumerVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function parseJsonString(string calldata, string calldata) external pure returns (string memory);
}

contract TerminalConsumerCore is EntropyCollectionPolicyCoreFixture {
    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 0;
    }

    function collectionStatus(uint256) external pure returns (uint8) {
        return 1;
    }
}

contract TerminalConsumerHarness {
    function terminal(address core, uint256 tokenId, uint256 collectionId)
        external
        view
        returns (P.Terminal memory)
    {
        return Reads.terminal(core, tokenId, collectionId, 600000);
    }

    function validate(Render.RenderRequest memory r, address entropy, bytes32 hash, bool frozen)
        external
        view
        returns (P.Terminal memory)
    {
        // Same explicit STATIC boundary as the renderer, not a delegated library call.
        (bool ok, bytes memory out) = address(Validation)
            .staticcall(
                abi.encodeWithSelector(
                    Validation.validate.selector, r, entropy, hash, frozen, uint256(600000)
                )
            );
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        require(out.length == 480, "exact terminal tuple");
        return abi.decode(out, (P.Terminal));
    }

    function encoded(
        Render.RenderRequest memory r,
        Original.Prepared memory p,
        P.Terminal memory t,
        string memory script,
        uint8 mode
    ) external pure returns (string memory) {
        return Encoding.render(r, p, t, script, address(0x1234), mode);
    }

    function ordinary(
        uint8 mode,
        Token.Token memory t,
        Serving.ServingSource memory source,
        P.Terminal memory p
    ) external pure returns (string memory) {
        return Ordinary.render(mode, t, source, bytes("{}"), true, 1, address(0xAbCd), p);
    }
}

/// @notice Real Coordinator policy/registration and fixed consumer libraries. Core, Artist receipt,
/// governance context and external entropy provider are typed boundaries; no current-stack claim.
contract StreamTerminalEntropyConsumersTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture
{
    using Strings for uint256;
    TerminalConsumerCore private core;
    EntropyCollectionPolicyArtistFixture private artist;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    TerminalConsumerHarness private reader;
    bytes32 private constant H = keccak256("terminal test manifest");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");

    function setUp() public {
        vm.roll(100);
        core = new TerminalConsumerCore();
        artist = new EntropyCollectionPolicyArtistFixture(address(core));
        MockEntropyRoleRegistry roles = new MockEntropyRoleRegistry(address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roles),
                EntropyTimeTestConfigs.parameters(),
                H,
                "urn:terminal-consumer",
                H
            )
        );
        core.wire(entropy, address(artist), address(new MockEntropyModuleRegistry(address(this))));
        provider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(provider));
        reader = new TerminalConsumerHarness();
    }

    function testDisabledFullPolicyAndStatusNeverBecomeFinalizedSeed() public {
        _register(false);
        P.Terminal memory t = reader.terminal(address(core), 71, 1);
        Policy.PolicyRecord memory original = Policy(address(entropy)).collectionEntropyPolicy(1);
        require(
            t.coordinator == address(entropy) && t.coordinatorCodeHash == address(entropy).codehash,
            "original runtime"
        );
        require(
            t.status == 1 && t.policy.mode == 0 && t.policy.renderRequirement == 1,
            "declared disabled"
        );
        require(
            keccak256(abi.encode(t.policy)) == keccak256(abi.encode(original)), "all twelve words"
        );
        require(
            t.policy.contentStateHash == keccak256(abi.encode(FAMILY, original.policyHash, true)),
            "literal original op17 state"
        );
        (bytes32 seed, bool finalized) = entropy.tokenSeed(71);
        require(seed == 0 && !finalized && entropy.pendingRequestCount() == 0, "not fake finality");
        (, bytes32 legacy,,,,) = _legacyFacts();
        require(legacy == 0, "old finality policy unavailable");
    }

    function testAsyncNotRequiredPreservesRealProviderButNoTokenRequest() public {
        _register(true);
        P.Terminal memory t = reader.terminal(address(core), 71, 1);
        require(
            t.status == 2 && t.policy.mode == 2 && t.policy.providerEpoch == 1,
            "declared async terminal"
        );
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address retainedProvider,,,
            bytes32 key,
            uint256 requestId,
            uint16 attempt
        ) = entropy.tokenEntropy(71);
        require(
            status == StreamEntropyStatus.NOT_REQUIRED && retainedProvider == address(provider),
            "real configured provider retained"
        );
        require(seed == 0 && key == 0 && requestId == 0 && attempt == 0, "no synthetic request");
        require(provider.nextRequestId() == 1, "no provider token call");
        bytes32 scope = entropy.registerEntropyScope(1, 0, H);
        entropy.requestScopeEntropy(scope, H);
        require(provider.nextRequestId() == 2, "independent real async scope still requests");
        require(
            reader.terminal(address(core), 71, 1).policy.policyHash == t.policy.policyHash,
            "scope does not replace token policy"
        );
    }

    function testOriginalCoordinatorAtMintSurvivesCurrentPointerReplacement() public {
        _register(false);
        P.Terminal memory before_ = reader.terminal(address(core), 71, 1);
        core.setCoordinator(StreamEntropyCoordinator(address(reader)));
        require(core.coordinatorAtMint(71) == address(entropy), "retained original anchor");
        require(
            keccak256(abi.encode(reader.terminal(address(core), 71, 1)))
                == keccak256(abi.encode(before_)),
            "no current pointer substitution"
        );
    }

    function testMissingTokenWrongCollectionAndUnfrozenDeclarationRefused() public {
        _configure(false);
        vm.expectRevert();
        reader.terminal(address(core), 71, 1);
        core.registerToken(1, 71, H);
        vm.expectRevert();
        reader.terminal(address(core), 71, 2);
        P.Terminal memory t = reader.terminal(address(core), 71, 1);
        t.policy.frozen = false;
        _mockPolicy(t.policy);
        vm.expectRevert();
        reader.terminal(address(core), 71, 1);
    }

    function testFalseFinalizedSeedOrRequestAndMalformedPolicyCannotPass() public {
        _register(false);
        TerminalConsumerVm cheats = TerminalConsumerVm(address(vm));
        cheats.mockCall(
            address(entropy),
            abi.encodeWithSignature("tokenSeed(uint256)", uint256(71)),
            abi.encode(bytes32(uint256(1)), true)
        );
        vm.expectRevert();
        reader.terminal(address(core), 71, 1);
        cheats.clearMockedCalls();
        cheats.mockCall(
            address(entropy),
            abi.encodeWithSignature("tokenEntropy(uint256)", uint256(71)),
            abi.encode(
                uint8(1), bytes32(0), address(0), uint32(0), bytes32(0), H, uint256(1), uint16(1)
            )
        );
        vm.expectRevert();
        reader.terminal(address(core), 71, 1);
        cheats.clearMockedCalls();
        P.Terminal memory t = reader.terminal(address(core), 71, 1);
        t.policy.contentStateHash = H;
        _mockPolicy(t.policy);
        vm.expectRevert();
        reader.terminal(address(core), 71, 1);
        cheats.clearMockedCalls();
        cheats.mockCall(
            address(entropy),
            abi.encodeWithSignature("collectionEntropyPolicy(uint256)", uint256(1)),
            abi.encodePacked(abi.encode(t.policy), bytes32(0))
        );
        vm.expectRevert();
        reader.terminal(address(core), 71, 1);
    }

    function testValidationJoinsActualIdentityRuntimeStateAndZeroHash() public {
        _register(false);
        Render.RenderRequest memory r = _request();
        bytes32 runtime = address(entropy).codehash;
        reader.validate(r, address(entropy), runtime, false);
        r.collectionSerial = 72;
        vm.expectRevert();
        reader.validate(r, address(entropy), runtime, false);
        r = _request();
        r.tokenHash = H;
        vm.expectRevert();
        reader.validate(r, address(entropy), runtime, false);
        r = _request();
        vm.expectRevert();
        reader.validate(r, address(entropy), H, false);
        core.freezeCollection(1);
        vm.expectRevert();
        reader.validate(r, address(entropy), runtime, false);
        r.state = Render.TokenRenderState.FROZEN;
        reader.validate(r, address(entropy), runtime, false);
    }

    function testTerminalStaticDirectFactsDoNotReachOriginalLinkedReadSelectors() public {
        _register(false);
        Render.RenderRequest memory r = _request();
        P.Terminal memory expected = reader.terminal(address(core), 71, 1);
        TerminalConsumerVm cheats = TerminalConsumerVm(address(vm));
        cheats.mockCallRevert(
            address(entropy),
            abi.encodeWithSignature("collectionEntropyPolicy(uint256)", uint256(1)),
            hex"deadbeef"
        );
        cheats.mockCallRevert(
            address(entropy),
            abi.encodeWithSignature("tokenEntropy(uint256)", uint256(71)),
            hex"deadbeef"
        );
        cheats.mockCallRevert(
            address(entropy),
            abi.encodeWithSignature("tokenSeed(uint256)", uint256(71)),
            hex"deadbeef"
        );
        P.Terminal memory actual =
            reader.validate(r, address(entropy), address(entropy).codehash, false);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "same complete native facts through direct storage profile"
        );
    }

    function testOrdinaryMetadataIsTruthfulAndCannotExecuteTerminalProgram() public {
        _register(false);
        P.Terminal memory p = reader.terminal(address(core), 71, 1);
        Token.Token memory t = Token.Token(71, 1, 71, 0, false, "disabled", hex"00ff", true);
        // Original Router supplies JSON-escaped serving strings.
        Serving.ServingSource memory m =
            Serving.ServingSource("Work\\\"", "Description", "image", "offchain", "window.bad=1;");
        string memory json = reader.ordinary(0, t, m, p);
        require(
            _count(json, '"entropy_status":"DISABLED"') == 1
                && _count(json, '"entropy_finalized":false') == 1,
            "explicit truthful terminal"
        );
        require(
            _count(json, '"hash":') == 0 && _count(json, '"seed":') == 0
                && _count(json, '"animation_url"') == 0,
            "no dummy execution inputs"
        );
        require(
            _count(json, '"properties"') == 1 && _count(json, '"citation"') == 1,
            "unique object fields"
        );
        require(
            keccak256(bytes(TerminalConsumerVm(address(vm)).parseJsonString(json, ".name")))
                == keccak256(bytes('Work" #71')),
            "valid escaped JSON"
        );
        require(
            keccak256(bytes(reader.ordinary(1, t, m, p)))
                == keccak256(
                    bytes(
                        string.concat("data:application/json;base64,", Base64.encode(bytes(json)))
                    )
                ),
            "exact URI bytes"
        );
        vm.expectRevert(
            abi.encodeWithSelector(Ordinary.TerminalExecutableAdmissionRequired.selector)
        );
        reader.ordinary(3, t, m, p);
    }

    function testStaticTerminalProfileNoSeedAliasAndOriginalEncodingUnchanged() public {
        _register(true);
        P.Terminal memory t = reader.terminal(address(core), 71, 1);
        (Render.RenderRequest memory r, Original.Prepared memory p) = _prepared();
        string memory oldBefore = Original.render(r, p, "window.art=1;", address(0x1234), 2);
        string memory json = reader.encoded(r, p, t, "window.art=1;", 2);
        require(
            _count(json, '"entropy_status":"NOT_REQUIRED"') == 1
                && _count(json, '"entropy_policy_hash":"') == 1,
            "full status and H"
        );
        require(
            _count(json, '"hash":') == 0 && _count(json, '"seed":') == 0
                && _count(json, '"terminal_executable_admitted"') == 0,
            "pure output makes no fake seed or admission claim"
        );
        require(
            keccak256(
                bytes(
                    TerminalConsumerVm(address(vm))
                        .parseJsonString(json, ".properties.stream.render_profile")
                )
            ) == keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1"),
            "separate profile"
        );
        string memory html = reader.encoded(r, p, t, "window.art=1;", 3);
        require(
            _count(html, "const hash=") == 0 && _count(html, "window.__STREAM_TOKEN__=") == 1,
            "no old random alias"
        );
        require(_count(html, "window.art=1;") == 1, "actual program retained");
        require(
            keccak256(bytes(oldBefore))
                == keccak256(bytes(Original.render(r, p, "window.art=1;", address(0x1234), 2))),
            "old encoder bytes unmodified"
        );
        r.tokenHash = H;
        vm.expectRevert(abi.encodeWithSelector(Encoding.InvalidTerminalRender.selector));
        reader.encoded(r, p, t, "", 0);
    }

    function testTerminalScriptTextEscapesClosingScriptWithoutChangingJSONBytes() public {
        _register(false);
        P.Terminal memory t = reader.terminal(address(core), 71, 1);
        (Render.RenderRequest memory r, Original.Prepared memory p) = _prepared();
        string memory html = reader.encoded(r, p, t, 'window.art="</script>";', 3);
        require(_count(html, "</script>") == 3, "only generated closing tags");
        require(_count(html, "<\\/script>") == 1, "artist text escaped");
        string memory json = reader.encoded(r, p, t, 'window.art="</script>";', 2);
        string memory uri = TerminalConsumerVm(address(vm)).parseJsonString(json, ".animation_url");
        require(
            keccak256(bytes(uri))
                == keccak256(
                    bytes(string.concat("data:text/html;base64,", Base64.encode(bytes(html))))
                ),
            "literal complete executable bytes"
        );
    }

    function _configure(bool notRequired) private {
        Policy.PolicyInput memory input;
        input.renderRequirement = Policy.RenderRequirement.NOT_REQUIRED;
        if (notRequired) {
            input.mode = Policy.Mode.ASYNC;
            input.provider = address(provider);
            input.collectionSalt = H;
            input.publicRequests = true;
            input.timeoutBlocks = 10;
            input.reveal =
                Fee.CollectionRevealPolicy(true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        }
        (bytes32 scope, bytes32 prior, bytes32 next, bytes32 content) =
            Policy(address(entropy)).collectionEntropyPolicyTransition(1, input);
        artist.approve(1, address(entropy), FAMILY, content, H);
        this.setCurrentAction(true, H, 1, scope, prior, next);
        Policy(address(entropy)).configureCollectionEntropyPolicy(1, input);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _register(bool notRequired) private {
        _configure(notRequired);
        core.registerToken(1, 71, H);
    }

    function _mockPolicy(P.Policy memory p) private {
        TerminalConsumerVm(address(vm))
            .mockCall(
                address(entropy),
                abi.encodeWithSignature("collectionEntropyPolicy(uint256)", uint256(1)),
                abi.encode(p)
            );
    }

    function _request() private view returns (Render.RenderRequest memory r) {
        r.core = address(core);
        r.tokenId = 71;
        r.collectionId = 1;
        r.collectionSerial = 71;
        r.collectionStatus = 1;
        r.state = Render.TokenRenderState.ACTIVE;
    }

    function _prepared()
        private
        view
        returns (Render.RenderRequest memory r, Original.Prepared memory p)
    {
        r = _request();
        r.metadataSnapshotHash = H;
        p.source.chainId = 1;
        p.source.name = "Work";
        p.source.description = "Description";
        p.source.imageURI = "image";
        p.config.mode = Render.MetadataMode.ONCHAIN;
        p.facts.chainId = 1;
        p.facts.viewName = "MARKETPLACE";
        p.facts.tokenData = hex"00ff";
        p.facts.scriptHash = keccak256("window.art=1;");
        p.artist = bytes("{}");
    }

    function _legacyFacts() private view returns (bool, bytes32, address, uint32, bytes32, bool) {
        (bool ok, bytes memory out) = address(entropy)
            .staticcall(abi.encodeWithSignature("entropyPolicyFrozen(uint256)", uint256(1)));
        require(ok && out.length == 160, "legacy exact shape");
        (bool frozen, bytes32 hash, address p, uint32 epoch, bytes32 salt) =
            abi.decode(out, (bool, bytes32, address, uint32, bytes32));
        return (frozen, hash, p, epoch, salt, ok);
    }

    function _count(string memory source, string memory needle) private pure returns (uint256 n) {
        bytes memory s = bytes(source);
        bytes memory p = bytes(needle);
        if (p.length > s.length) return 0;
        for (uint256 i; i + p.length <= s.length; ++i) {
            bool same = true;
            for (uint256 j; j < p.length; ++j) {
                if (s[i + j] != p[j]) {
                    same = false;
                    break;
                }
            }
            if (same) ++n;
        }
    }
}
