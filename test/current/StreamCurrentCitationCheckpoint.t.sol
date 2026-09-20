// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentStaticTokenRenderingFixture.sol";
import {
    StreamCollectionTokenInventory
} from "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    StreamFinalityScopeMembership
} from "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamStaticContentCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    IStreamStaticContentCheckpoint as CitationCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";

interface CitationCheckpointVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @notice Actual current paid token, Artist freeze, Registry admission and live-output checkpoint.
/// @dev Only the legacy capability=false observation is simulated, explicitly below; no renderer
/// output, Registry proof, checkpoint producer or current admission response is substituted.
/// Inherited synthetic analysis and external entropy-service limitations remain.
contract StreamCurrentCitationCheckpointTest is CurrentStaticTokenRenderingFixture {
    StreamStaticSelectionCheckpoint private selections;
    StreamStaticContentCheckpoint private outputs;

    function setUp() public {
        _constructStaticTokenRendering();
    }

    function _staticTokenImageURI() internal pure override returns (string memory) {
        // Exact absent-image profile, permitted by the original content checkpoint.
        return "";
    }

    function testProfileChangeInvalidatesCurrentnessPreservesHistoryAndFreshAdmissionCapturesCitation()
        public
    {
        _mintToken();
        bytes32 seed = _revealToken();
        StaticRouter.ConfigInput memory frozen = _input();
        frozen.config.frozen = true;
        bytes32 consent = _configConsent(1, frozen);
        _tokenSafe(
            governor, address(router), 0, abi.encodeCall(router.setTokenMetadataConfig, (1, frozen))
        );
        initialRecord = router.resolvedMetadataConfig(1);
        require(
            router.consumedArtistContentConsent(consent) && initialRecord.config.frozen
                && initialRecord.sourceSnapshotHash != 0,
            "actual original Artist-consented frozen source"
        );
        bytes32 selection = _checkpointProducers();
        string memory historical = router.historicalFullTokenMetadataJSON(address(core), 1);
        string memory html = _literalHTML(seed, initialRecord.recordHash);
        require(!_has(historical, '"citation"'), "historical output remains original profile");

        // Explicit capability boundary models old/current dispatch with the same pinned runtime.
        // This is not a claim to have deployed a historical renderer version.
        CitationCheckpointVm(address(vm))
            .mockCall(
                address(rendering.renderer),
                abi.encodeCall(
                    rendering.renderer.supportsInterface, (type(TokenCitationRenderer).interfaceId)
                ),
                abi.encode(false)
            );
        require(
            keccak256(bytes(router.tokenJSON(1))) == keccak256(bytes(historical)),
            "original dispatch output"
        );
        bytes32 oldId = _capture(selection, keccak256("explicit old-capability capture"), html);
        CitationCheckpoint.Output memory old = outputs.outputAt(oldId, 0);
        CitationCheckpoint.Plan memory oldPlan = outputs.requireCurrentCheckpoint(oldId);
        require(
            old.leaf.metadataHash == keccak256(bytes(historical)), "original complete JSON leaf"
        );
        CitationCheckpointVm(address(vm)).clearMockedCalls();
        _refuseCurrent(oldId);
        _unchangedHistory(oldId, old, oldPlan);

        _admitStaticTokenCitation(seed, true);
        string memory current = router.tokenJSON(1);
        require(
            keccak256(bytes(current))
                    == keccak256(
                        bytes(
                            _insertTokenCitation(
                                historical, _literalContext(seed, initialRecord.recordHash, true)
                            )
                        )
                    ) && keccak256(bytes(current)) != old.leaf.metadataHash,
            "genuine newly admitted current output adds precisely literal citation"
        );
        vm.expectRevert(
            abi.encodeWithSelector(CitationCheckpoint.StaticContentChanged.selector, oldId)
        );
        outputs.requireCurrentCheckpoint(oldId);
        _unchangedHistory(oldId, old, oldPlan);
        bytes32 nextId = _capture(selection, keccak256("genuine current-citation capture"), html);
        CitationCheckpoint.Output memory next = outputs.outputAt(nextId, 0);
        require(
            nextId != oldId && next.leaf.metadataHash == keccak256(bytes(current))
                && next.leaf.animationHash == keccak256(bytes(html))
                && next.leaf.tokenDataHash == keccak256(STATIC_TOKEN_DATA)
                && next.leaf.imageHash == 0 && next.leaf.contentHash == 0
                && next.selectionRowHash == old.selectionRowHash
                && next.sourceFactsHash == old.sourceFactsHash && next.htmlHash == old.htmlHash
                && outputs.requireCurrentCheckpoint(nextId).contentRoot != oldPlan.contentRoot,
            "new current leaf preserves original selection, token bytes and executable HTML"
        );
        _unchangedHistory(oldId, old, oldPlan);
        require(
            keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 1)))
                    == keccak256(bytes(historical))
                && keccak256(bytes(router.tokenHTML(1))) == keccak256(bytes(html)),
            "original historical JSON and full executable HTML remain exact"
        );
    }

    function _checkpointProducers() private returns (bytes32 selection) {
        StreamCollectionTokenInventory inventory = new StreamCollectionTokenInventory(
            address(core),
            address(executor),
            _checkpointGas("TOKEN_INVENTORY_CORE_READ_GAS", 100000, 1)
        );
        StreamFinalityScopeMembership membership = new StreamFinalityScopeMembership(
            address(core),
            address(assemblyMetadata),
            address(inventory),
            address(executor),
            _checkpointGas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 1)
        );
        selections = new StreamStaticSelectionCheckpoint(
            address(core),
            address(router),
            address(membership),
            address(executor),
            _checkpointGas("STATIC_CHECKPOINT_READ_GAS", 2000000, 1)
        );
        outputs = new StreamStaticContentCheckpoint(
            address(selections),
            address(executor),
            _checkpointGas("STATIC_CONTENT_READ_GAS", 4000000, 2),
            _checkpointGas("STATIC_CONTENT_RENDER_GAS", 20000000, 2)
        );
        require(
            address(inventory).code.length <= 24576 && address(membership).code.length <= 24576
                && address(selections).code.length <= 24576
                && address(outputs).code.length <= 24576,
            "original production runtime guard"
        );
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        _tokenSafe(
            tokenBuyer,
            address(inventory),
            0,
            abi.encodeCall(inventory.appendCollectionTokens, (2, ids))
        );
        selection = selections.begin(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 2, 1, 0));
        _tokenSafe(
            tokenBuyer, address(selections), 0, abi.encodeCall(selections.append, (selection, 1))
        );
    }

    function _capture(bytes32 selection, bytes32 salt, string memory html)
        private
        returns (bytes32 id)
    {
        id = outputs.begin(selection, salt);
        CitationCheckpoint.Payload[] memory payloads = new CitationCheckpoint.Payload[](1);
        payloads[0] = CitationCheckpoint.Payload(1, "", bytes(html));
        _tokenSafe(tokenBuyer, address(outputs), 0, abi.encodeCall(outputs.append, (id, payloads)));
        require(
            outputs.requireCurrentCheckpoint(id).nextIndex == 1,
            "complete original single-token scope"
        );
    }

    function _refuseCurrent(bytes32 id) private {
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
    }

    function _unchangedHistory(
        bytes32 id,
        CitationCheckpoint.Output memory old,
        CitationCheckpoint.Plan memory oldPlan
    ) private view {
        require(
            keccak256(abi.encode(outputs.outputAt(id, 0))) == keccak256(abi.encode(old))
                && keccak256(abi.encode(outputs.checkpoint(id))) == keccak256(abi.encode(oldPlan)),
            "failed currentness and fresh captures cannot rewrite any old output or root"
        );
    }

    function _checkpointGas(string memory name, uint256 value, uint8 failure)
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, 50000, failure);
    }
}
