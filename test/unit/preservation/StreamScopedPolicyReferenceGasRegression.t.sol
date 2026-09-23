// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ScopedPolicyReferenceFixtureV2 } from "./StreamScopedPolicyReferencePublicationV2.t.sol";
import {
    StreamScopedPolicyReferencePublicationV2 as ReferenceHost
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as ReferenceTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamStaticContentBytes as StaticBytes
} from "../../../smart-contracts/domains/finality/StreamStaticContentBytes.sol";

/// @dev The reference source read must preserve the same bytes captured from the original Router.
/// A tight parent cap causes the renderer's guarded Artist attribution read to return unavailable.
contract StreamScopedPolicyReferenceGasRegressionTest is ScopedPolicyReferenceFixtureV2 {
    function testOriginalCaptureNeedsParentGasAboveRendererAttributionCap() public {
        _reference(1, 2);

        uint256 token = referenceInput.observation.captures[0].tokenId;
        bytes32 captured = referenceInput.observation.captures[0].metadataJSONHash;
        (bool lowOk, bytes memory lowResult) = address(router).staticcall{gas: 8000000}(
            abi.encodeWithSignature("tokenJSON(uint256)", token)
        );
        (bool highOk, bytes memory highResult) = address(router).staticcall{gas: 16000000}(
            abi.encodeWithSignature("tokenJSON(uint256)", token)
        );
        require(lowOk && highOk, "Router reads must complete");
        bytes memory low = bytes(abi.decode(lowResult, (string)));
        bytes memory high = bytes(abi.decode(highResult, (string)));
        require(_contains(low, bytes("attribution_unavailable")), "8m must omit attribution");
        require(_contains(high, bytes('"state":"disputed"')), "16m must retain attribution");
        require(keccak256(low) != captured, "8m must differ from original capture");
        require(keccak256(high) == captured, "16m must match original capture");
        bytes memory html = referenceInput.observation.captures[0].animationHTML;
        bytes memory tokenData = core.tokenData(token);
        require(StaticBytes.matches(high, html, tokenData), "current STATIC bytes match");
        bytes memory wrongHTML = bytes.concat(html);
        wrongHTML[0] = wrongHTML[0] ^ bytes1(uint8(1));
        require(!StaticBytes.matches(high, wrongHTML, tokenData), "changed HTML rejected");
        bytes memory wrongTokenData = bytes.concat(tokenData);
        wrongTokenData[0] = wrongTokenData[0] ^ bytes1(uint8(1));
        require(!StaticBytes.matches(high, html, wrongTokenData), "changed data rejected");
        referenceInput.observation.captures[0].metadataJSONHash =
            bytes32(uint256(captured) ^ 1);
        vm.expectRevert(abi.encodeWithSelector(ReferenceTypes.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testTightReferenceHostRejectsWithoutHistoryAndHealthyHostPublishes() public {
        _reference(1, 2);

        ReferenceTypes.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(snapshotHost),
            address(externalArchive)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        Gas.GasParameterConfig[4] memory configs = _referenceGas();
        configs[1].genesisValue = 8000000;
        ReferenceHost tight = ReferenceHost(
            _artistArtifactCreate(
                "smart-contracts/domains/preservation/StreamScopedPolicyReferencePublicationV2.sol:StreamScopedPolicyReferencePublicationV2",
                abi.encode(d, address(executor), configs)
            )
        );
        tight.prepareFileInventory(referenceInput.observation.environment.packageFiles, true);
        tight.prepareFileInventory(
            referenceInput.observation.environment.platformPrerequisites, false
        );

        bytes memory original = _referenceBytes(address(this));
        _upload(original, false);
        require(tight.referenceCount(referenceInput.scope) == 0, "tight count before");
        require(
            tight.currentReference(referenceInput.scope).observation.recordHash == 0,
            "tight head before"
        );
        vm.expectRevert(abi.encodeWithSelector(ReferenceTypes.InvalidScopedPolicyReference.selector));
        tight.previewReference(referenceInput, address(this));
        vm.expectRevert(abi.encodeWithSelector(ReferenceTypes.InvalidScopedPolicyReference.selector));
        tight.publishReference(referenceInput);
        require(tight.referenceCount(referenceInput.scope) == 0, "tight count after");
        require(
            tight.currentReference(referenceInput.scope).observation.recordHash == 0,
            "tight head after"
        );

        bytes32 published = _publishReference();
        require(referenceHost.referenceCount(referenceInput.scope) == 1, "healthy count");
        require(
            referenceHost.currentReference(referenceInput.scope).observation.recordHash == published,
            "healthy head"
        );
        require(tight.referenceCount(referenceInput.scope) == 0, "tight history remains empty");
    }

    function _contains(bytes memory value, bytes memory needle) private pure returns (bool) {
        if (value.length < needle.length) return false;
        for (uint256 i; i <= value.length - needle.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < needle.length; ++j) {
                if (value[i + j] != needle[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) return true;
        }
        return false;
    }
}
